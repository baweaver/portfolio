# frozen_string_literal: true

require "json"
require "csv"

# segment: the_problem
def pattern_match_string_keys
  str_hash = { "name" => "Alice", "age" => 30, "role" => "admin" }

  case str_hash
  in { name: String => name, role: "admin" }
    name
  else
    nil
  end
end
# end: the_problem

# segment: json_without_symbolize
def match_parsed_json
  response = JSON.parse('{"status": 200, "body": {"id": 42, "type": "user"}}')

  case response
  in { status: 200, body: { id: Integer => id, type: "user" } }
    id
  else
    nil
  end
end
# end: json_without_symbolize

# segment: workaround_symbolize
def deep_symbolize(obj)
  case obj
  when Hash
    obj.to_h { |key, val| [key.to_sym, deep_symbolize(val)] }
  when Array
    obj.map { |element| deep_symbolize(element) }
  else
    obj
  end
end

def match_json_with_symbolize
  response = JSON.parse('{"status": 200, "body": {"id": 42, "type": "user"}}')
  symbolized = deep_symbolize(response)

  case symbolized
  in { status: 200, body: { id: Integer => id, type: "user" } }
    id
  else
    nil
  end
end
# end: workaround_symbolize

# segment: deconstruct_keys_returns_self
def sym_hash_returns_self
  sym_hash = { a: 1, b: 2, c: 3 }
  result = sym_hash.deconstruct_keys([:a, :b])
  result.equal?(sym_hash)
end
# end: deconstruct_keys_returns_self

# segment: deconstruct_keys_resolves_strings
def str_hash_resolves_to_symbols
  h = { "name" => "Alice", "age" => 30 }
  result = h.deconstruct_keys([:name, :age])
  [result[:name], result[:age]]
end
# end: deconstruct_keys_resolves_strings

# segment: mixed_hash_resolves
def mixed_hash_resolves_both
  h = { a: 1, "b" => 2, c: 3 }
  result = h.deconstruct_keys([:a, :b, :c])
  [result[:a], result[:b], result[:c]]
end
# end: mixed_hash_resolves

# segment: nested_json_match
def match_nested_api_response
  api_response = JSON.parse(<<~JSON)
    {
      "users": [
        {"name": "Alice", "role": "admin", "active": true},
        {"name": "Bob", "role": "viewer", "active": false}
      ],
      "meta": {"total": 2, "page": 1}
    }
  JSON

  api_response["users"].select do |user|
    user in { name: String, role: "admin", active: true }
  end.map { |user| user["name"] }
end
# end: nested_json_match

# segment: csv_without_converters
def match_csv_rows
  data = CSV.parse(<<~ROWS, headers: true)
    Name,Department,Salary
    Alice,Engineering,150000
    Bob,Sales,90000
    Jane,Engineering,140000
  ROWS

  data.select { |row| row.to_h in { Department: "Engineering" } }
      .map { |row| row["Name"] }
end
# end: csv_without_converters

# segment: hash_bracket_unchanged
def bracket_still_returns_nil
  h = { "name" => "Alice" }
  h[:name]
end
# end: hash_bracket_unchanged

# segment: safety_guarantees
def safety_demonstration
  str_hash = { "name" => "Alice", "role" => "admin" }

  str_hash[:name]                      # => nil
  str_hash.deconstruct_keys([:name])   # => { name: "Alice" }
  str_hash.key?(:name)                 # => false
  str_hash.dig(:name)                  # => nil
end
# end: safety_guarantees

# segment: key_question_unchanged
def key_question_still_false
  h = { "name" => "Alice" }
  h.key?(:name)
end
# end: key_question_unchanged

# segment: no_match_returns_self
def failed_match_preserves_hash_for_errors
  h = { a: 1 }
  result = h.deconstruct_keys([:missing])
  result.equal?(h)
end
# end: no_match_returns_self

# segment: fast_path_no_alloc
def fast_path_returns_self_when_all_keys_hit
  sym_hash = { a: 1, b: 2, c: 3 }
  before = GC.stat(:total_allocated_objects)
  100.times { sym_hash.deconstruct_keys([:a, :b]) }
  after = GC.stat(:total_allocated_objects)
  (after - before) < 5  # effectively zero alloc (some GC bookkeeping noise)
end
# end: fast_path_no_alloc

# segment: benchmark_comparison
def benchmark_three_paths(iterations: 2_000_000)
  sym_hash = { a: 1, b: 2, c: 3, d: 4, e: 5 }
  str_hash = { "name" => "Alice", "age" => 30, "role" => "admin", "active" => true, "level" => 5 }
  mix_hash = { a: 1, "b" => 2, c: 3, "d" => 4, e: 5 }

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { sym_hash in { a: Integer, b: Integer, c: Integer } }
  sym_ns = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / iterations * 1e9).round(1)

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { str_hash in { name: String, age: Integer, role: String } }
  str_ns = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / iterations * 1e9).round(1)

  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { mix_hash in { a: Integer, b: Integer, c: Integer } }
  mix_ns = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / iterations * 1e9).round(1)

  { sym_ns: sym_ns, str_ns: str_ns, mix_ns: mix_ns,
    str_pct: (sym_ns / str_ns * 100).round(1),
    mix_pct: (sym_ns / mix_ns * 100).round(1) }
end
# end: benchmark_comparison
