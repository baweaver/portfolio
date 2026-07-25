# Proves every claim in "A Rubyist in Go Land: A First API Client in Go".
#
# Requires: go 1.22+, ruby 3.1+, fixtures fetched (ruby fetch_fixtures.rb).
# The timeout examples take about 25 seconds combined; they earn it.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rspec"
end

require "net/http"
require "rspec/autorun"
require "socket"

REPO_ROOT = File.expand_path(__dir__)
FIXTURE_PORT = 9797
BLACKHOLE_PORT = 9798

def marker_free_lines(relative_path)
  File.readlines(File.join(REPO_ROOT, relative_path), encoding: "UTF-8")
      .reject { _1.match?(%r{(#|//) (segment|end):}) }
      .size
end

def run_command(*command, env: {})
  reader, writer = IO.pipe
  pid = Process.spawn(env, *command, chdir: REPO_ROOT, out: writer, err: writer)
  writer.close
  output = reader.read.force_encoding("UTF-8")
  Process.wait(pid)
  [output, $?.exitstatus]
end

RSpec.describe "post 1 claims" do
  before(:all) do
    _output, status = run_command("go", "build", "-o", "bin/", "./...")
    raise "go build failed" unless status.zero?
  end

  describe "line counts, excluding segment markers to match what CodeBlock renders" do
    it("ruby script line count") { expect(marker_free_lines("pokemon.rb")).to eq(33) }
    it("client.go line count") { expect(marker_free_lines("internal/pokeapi/client.go")).to eq(35) }
    it("pokemon.go line count") { expect(marker_free_lines("internal/pokeapi/pokemon.go")).to eq(66) }
    it("cmd main line count") { expect(marker_free_lines("cmd/pokemon/main.go")).to eq(72) }

    it "go total line count" do
      total = %w[internal/pokeapi/client.go internal/pokeapi/pokemon.go cmd/pokemon/main.go]
        .sum { marker_free_lines(_1) }
      expect(total).to eq(173)
    end
  end

  describe "Ruby behavior the article states" do
    it "raises NoMatchingPatternKeyError when the shape disagrees" do
      expect { { name: "missingno" } => { id: } }.to raise_error(NoMatchingPatternKeyError)
    end

    it "net http open timeout and read timeout default to 60" do
      require_relative "net_http_defaults"
      defaults = net_http_defaults
      expect(defaults[:open_timeout]).to eq(60)
      expect(defaults[:read_timeout]).to eq(60)
    end
  end

  describe "the clients against the local mirror" do
    before(:all) do
      unless File.exist?(File.join(REPO_ROOT, "fixtures/data/api/v2/pokemon/bulbasaur"))
        skip "fixtures missing; run: ruby fetch_fixtures.rb"
      end

      @server_pid = Process.spawn(
        File.join(REPO_ROOT, "bin/serve-fixtures"),
        chdir: REPO_ROOT, out: File::NULL, err: File::NULL
      )
      @mirror_env = { "POKEAPI_URL" => "http://localhost:9595/api/v2" }
      sleep 0.5
    end

    after(:all) do
      Process.kill("TERM", @server_pid) if @server_pid
      Process.wait(@server_pid) if @server_pid
    rescue Errno::ESRCH, Errno::ECHILD
    end

    it "both Go versions print the bulbasaur profile" do
      %w[bin/pokemon bin/pokemon-quick].each do |binary|
        output, status = run_command(File.join(REPO_ROOT, binary), "bulbasaur", env: @mirror_env)
        expect(status).to eq(0)
        expect(output.lines.first).to eq("#0001 Bulbasaur\n")
        expect(output).to include("Types:     grass / poison")
      end
    end

    it "the Ruby baseline prints the same header" do
      output, status = run_command("ruby", "pokemon.rb", "bulbasaur", env: @mirror_env)
      expect(status).to eq(0)
      expect(output.lines.first).to eq("#0001 Bulbasaur\n")
    end

    it "missingno fails with the 404 message and exit 1" do
      output, status = run_command(File.join(REPO_ROOT, "bin/pokemon"), "missingno", env: @mirror_env)
      expect(status).to eq(1)
      expect(output).to include(%(no Pokémon named "missingno" (404 Not Found)))
    end
  end

  describe "against a server that accepts and never responds" do
    before(:all) do
      @blackhole = TCPServer.new("127.0.0.1", BLACKHOLE_PORT)
      @held_connections = []
      @acceptor = Thread.new { loop { @held_connections << @blackhole.accept } }
      @blackhole_env = { "POKEAPI_URL" => "http://127.0.0.1:#{BLACKHOLE_PORT}/api/v2" }
    end

    after(:all) do
      @acceptor&.kill
      @held_connections&.each { _1.close rescue nil }
      @blackhole&.close
    end

    it "client timeout seconds: the package client fails at the configured 10" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      output, status = run_command(File.join(REPO_ROOT, "bin/pokemon"), "bulbasaur", env: @blackhole_env)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(status).to eq(1)
      expect(output).to include("Client.Timeout exceeded")
      expect(elapsed).to be_between(9, 12)
    end

    it "the quick draft outlives the package client's deadline" do
      pid = Process.spawn(
        @blackhole_env, File.join(REPO_ROOT, "bin/pokemon-quick"), "bulbasaur",
        chdir: REPO_ROOT, out: File::NULL, err: File::NULL
      )
      sleep 12
      alive = Process.kill(0, pid) && true
      Process.kill("KILL", pid)
      Process.wait(pid)

      expect(alive).to be(true)
    end
  end
end
