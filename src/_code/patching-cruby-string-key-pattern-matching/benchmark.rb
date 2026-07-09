# frozen_string_literal: true

# Benchmark: String-Key Pattern Matching Performance
# Run on patched CRuby (branch: feature/hash-key-type-bitmask)
#
# Usage:
#   ruby benchmark.rb
#
# Requires the patched Ruby from:
#   https://github.com/baweaver/ruby/tree/feature/hash-key-type-bitmask

# segment: benchmark_core
def benchmark_pattern_matching(iterations: 5_000_000)
  native_sym = { a: 1, b: 2, c: 3, d: 4, e: 5 }
  str_hash = { "name" => "Alice", "age" => 30, "role" => "admin", "active" => true, "level" => 5 }
  mix_hash = { a: 1, "b" => 2, c: 3, "d" => 4, e: 5 }

  # Warmup
  200_000.times { native_sym in { a: Integer, b: Integer, c: Integer } }
  200_000.times { str_hash in { name: String, age: Integer, role: String } }
  200_000.times { mix_hash in { a: Integer, b: Integer, c: Integer } }

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { native_sym in { a: Integer, b: Integer, c: Integer } }
  sym_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { str_hash in { name: String, age: Integer, role: String } }
  str_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { mix_hash in { a: Integer, b: Integer, c: Integer } }
  mix_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t

  {
    iterations: iterations,
    sym_ops_sec: (iterations / sym_time).to_i,
    str_ops_sec: (iterations / str_time).to_i,
    mix_ops_sec: (iterations / mix_time).to_i,
    sym_ns: (sym_time / iterations * 1e9).round(1),
    str_ns: (str_time / iterations * 1e9).round(1),
    mix_ns: (mix_time / iterations * 1e9).round(1),
    str_pct_of_native: ((iterations / str_time) * 100.0 / (iterations / sym_time)).round(1),
    mix_pct_of_native: ((iterations / mix_time) * 100.0 / (iterations / sym_time)).round(1)
  }
end
# end: benchmark_core

if __FILE__ == $0
  puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
  puts "=" * 60

  results = benchmark_pattern_matching

  puts "Performance (#{results[:iterations]} iterations):"
  puts "  sym `in` (baseline): #{results[:sym_ops_sec]} ops/sec (#{results[:sym_ns]} ns/op)"
  puts "  str `in` (patched):  #{results[:str_ops_sec]} ops/sec (#{results[:str_ns]} ns/op)"
  puts "  mix `in` (patched):  #{results[:mix_ops_sec]} ops/sec (#{results[:mix_ns]} ns/op)"
  puts
  puts "  str as % of native sym: #{results[:str_pct_of_native]}%"
  puts "  mix as % of native sym: #{results[:mix_pct_of_native]}%"
end
