#!/usr/bin/env ruby
# frozen_string_literal: true

# Lints markdown posts for hardcoded links that should use helpers instead.
# Usage: ruby scripts/lint_links.rb [files...]
# If no files given, checks all posts.

BANNED_PATTERNS = [
  {
    pattern: %r{https?://github\.com/baweaver/portfolio/blob/},
    message: "Use <%= repo_link \"text\", \"path\" %> or <%= repo_url \"path\" %>",
  },
  {
    pattern: %r{\(https?://baweaver\.com/writing/},
    message: "Use <%= post_link \"text\", slug: \"the-slug\" %> or <%= post_url slug: \"the-slug\" %>",
  },
  {
    pattern: %r{\(https?://baweaver\.com/(?!writing/)},
    message: "Use <%= site_link \"text\", \"/path\" %>",
  },
].freeze

files = if ARGV.any?
  ARGV.select { |f| f.end_with?(".md") }
else
  Dir.glob("src/_posts/**/*.md")
end

violations = []

files.each do |file|
  File.readlines(file).each_with_index do |line, index|
    BANNED_PATTERNS.each do |rule|
      if line.match?(rule[:pattern])
        violations << { file: file, line: index + 1, message: rule[:message], content: line.strip }
      end
    end
  end
end

if violations.empty?
  puts "✓ No hardcoded links found in #{files.size} file(s)"
  exit 0
else
  puts "✗ #{violations.size} hardcoded link(s) found:"
  violations.each do |v|
    puts "  #{v[:file]}:#{v[:line]}: #{v[:message]}"
    puts "    #{v[:content][0, 120]}"
  end
  exit 1
end
