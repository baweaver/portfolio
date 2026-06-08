#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark Array#shift vs Array#delete_at(0) to determine actual complexity.
# If shift is O(1), time per element should stay flat as n grows.
# If shift is O(n), time per element should grow linearly with n.

require "benchmark"

sizes = [10_000, 50_000, 100_000, 200_000, 400_000]

puts "Ruby #{RUBY_VERSION} (#{RUBY_ENGINE})"
puts
puts "Array#shift - drain entire array:"
puts "-" * 60

sizes.each do |n|
  arr = (1..n).to_a
  time = Benchmark.realtime { arr.shift until arr.empty? }
  per_elem = (time / n * 1_000_000).round(4)
  puts "  n=#{n.to_s.ljust(8)} total=#{time.round(4)}s  per_elem=#{per_elem}µs"
end

puts
puts "Array#delete_at(0) - drain entire array:"
puts "-" * 60

sizes.each do |n|
  arr = (1..n).to_a
  time = Benchmark.realtime { arr.delete_at(0) until arr.empty? }
  per_elem = (time / n * 1_000_000).round(4)
  puts "  n=#{n.to_s.ljust(8)} total=#{time.round(4)}s  per_elem=#{per_elem}µs"
end

puts
puts "If shift is O(1): per_elem stays flat as n grows."
puts "If delete_at(0) is O(n): per_elem grows linearly with n."
