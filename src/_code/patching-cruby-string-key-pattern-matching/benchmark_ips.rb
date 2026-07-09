# frozen_string_literal: true

# Benchmark (IPS): String-Key Pattern Matching Performance
# Run on patched CRuby (branch: feature/hash-key-type-bitmask)
#
# Usage:
#   ruby benchmark_ips.rb
#
# Requires:
#   gem install benchmark-ips
#   Patched Ruby from: https://github.com/baweaver/ruby/tree/feature/hash-key-type-bitmask

require "benchmark/ips"

native_sym = { a: 1, b: 2, c: 3, d: 4, e: 5 }
str_hash = { "name" => "Alice", "age" => 30, "role" => "admin", "active" => true, "level" => 5 }
mix_hash = { a: 1, "b" => 2, c: 3, "d" => 4, e: 5 }
sym_keys = %i[a b c]
str_keys = %i[name age role]
mix_keys = %i[a b c d e]

puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "=" * 60

puts "\n## End-to-end `in` pattern match\n\n"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report("sym `in` (baseline)") {
    native_sym in { a: Integer, b: Integer, c: Integer }
  }

  x.report("str `in` (patched)") {
    str_hash in { name: String, age: Integer, role: String }
  }

  x.report("mix `in` (patched)") {
    mix_hash in { a: Integer, b: Integer, c: Integer }
  }

  x.compare!
end

puts "\n## deconstruct_keys alone\n\n"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report("sym deconstruct_keys (flag early-return)") {
    native_sym.deconstruct_keys(sym_keys)
  }

  x.report("str deconstruct_keys (resolve + alloc)") {
    str_hash.deconstruct_keys(str_keys)
  }

  x.report("mix deconstruct_keys") {
    mix_hash.deconstruct_keys(mix_keys)
  }

  x.compare!
end
