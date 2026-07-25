#!/usr/bin/env ruby
# frozen_string_literal: true

# Pulls a pocketful of Pokemon from PokeAPI's static data mirror
# (https://github.com/PokeAPI/api-data) into local fixtures, so the
# examples in this series never hammer the live API.
#
# Files are written without extensions, keyed by both name and National
# Dex number, so any static file server can answer the same paths the
# live API does:
#
#   GET /api/v2/pokemon/bulbasaur
#   GET /api/v2/pokemon/1

# segment: fetch-fixtures
require "fileutils"
require "net/http"

MIRROR = "https://raw.githubusercontent.com/PokeAPI/api-data/master/data"
FIXTURE_DIR = File.expand_path("fixtures/data/api/v2/pokemon", __dir__)

# api-data stores records by id, so we keep a small name lookup here.
# Add to this map as the series grows.
POKEMON = {
  "bulbasaur"  => 1,
  "charmander" => 4,
  "squirtle"   => 7,
  "pikachu"    => 25
}.freeze

FileUtils.mkdir_p(FIXTURE_DIR)

POKEMON.each do |poke_name, national_id|
  response = Net::HTTP.get_response(URI("#{MIRROR}/api/v2/pokemon/#{national_id}/index.json"))

  unless response.is_a?(Net::HTTPSuccess)
    abort("Mirror returned #{response.code} for #{poke_name}, giving up")
  end

  File.write(File.join(FIXTURE_DIR, poke_name), response.body)
  File.write(File.join(FIXTURE_DIR, national_id.to_s), response.body)

  puts format("fetched %-10s (%6d bytes)", poke_name, response.body.bytesize)
end
# end: fetch-fixtures

puts "\nServe them with: go run ./cmd/serve-fixtures"
