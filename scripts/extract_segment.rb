#!/usr/bin/env ruby
# frozen_string_literal: true

# Extracts named segments from _code files, stripping inline specs and meta-syntax.
# Usage: ruby scripts/extract_segment.rb <file> [segment_name]
#
# Without segment_name: prints all segments concatenated (specs stripped).
# With segment_name: prints only that segment.

file = ARGV[0]
segment = ARGV[1]

abort "Usage: #{$0} <file> [segment]" unless file
abort "File not found: #{file}" unless File.exist?(file)

content = File.read(file)
lines = content.lines

def deindent(lines)
  non_blank = lines.reject { |l| l.strip.empty? }
  return lines if non_blank.empty?

  min_indent = non_blank.map { |l| l[/^ */].size }.min
  lines.map { |l| l.sub(/^ {0,#{min_indent}}/, "") }
end

if segment
  capturing = false
  captured = []

  lines.each do |line|
    if line.match?(/^\s*# segment:\s*#{Regexp.escape(segment)}\s*$/)
      capturing = true
    elsif line.match?(/^\s*# end:\s*#{Regexp.escape(segment)}\s*$/)
      break
    elsif capturing
      captured << line
    end
  end

  puts deindent(captured).join
else
  in_segment = false
  captured = []

  lines.each do |line|
    if line.match?(/^\s*# segment:\s*\S/)
      in_segment = true
      next
    elsif line.match?(/^\s*# end:\s*\S/)
      captured << "\n"
      next
    elsif in_segment
      captured << line
    end
  end

  puts deindent(captured).join.strip
end
