#!/usr/bin/env ruby
# frozen_string_literal: true

# Fails if any of the given files have uncovered lines.
# Usage: ruby scripts/check_coverage.rb src/_code/foo/bar.rb

require "json"

resultset = File.join(__dir__, "..", "coverage", ".resultset.json")
unless File.exist?(resultset)
  $stderr.puts "No coverage data found. Run specs with COVERAGE=PartialSummary first."
  exit 2
end

data = JSON.parse(File.read(resultset))
failed = false

ARGV.each do |file|
  abs = File.expand_path(file)
  data.each do |_, run|
    run["coverage"].each do |path, info|
      next unless path == abs || path.end_with?(file)
      missed = info["lines"].count { |h| h == 0 }
      if missed > 0
        $stderr.puts "FAIL: #{file} has #{missed} uncovered lines."
        failed = true
      end
    end
  end
end

exit(failed ? 2 : 0)
