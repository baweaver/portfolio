#!/usr/bin/env ruby
# frozen_string_literal: true

# Verifies that every claim() used in articles has a matching claim() in a spec file.
# Usage: ruby scripts/verify_claims.rb

require "find"

article_claims = []
spec_claims = []

# Find claims in article source files (ERB calls to claim helper)
Dir.glob("src/_posts/**/*.md").each do |file|
  File.read(file).scan(/<%=\s*claim\(\s*"([^"]+)"/).each do |match|
    article_claims << { name: match[0], file: file }
  end
end

# Find claims in spec files
Dir.glob("src/_code/**/*_spec.rb").each do |file|
  File.read(file).scan(/claim\(\s*"([^"]+)"\s*\)/).each do |match|
    spec_claims << match[0]
  end
end

spec_claims.uniq!
missing = article_claims.reject { |c| spec_claims.include?(c[:name]) }

if missing.empty?
  puts "✓ All #{article_claims.size} claims have corresponding specs"
  exit 0
else
  puts "✗ #{missing.size} claim(s) missing specs:"
  missing.each { |c| puts "  - \"#{c[:name]}\" in #{c[:file]}" }
  exit 1
end
