# frozen_string_literal: true

require_relative "examples"

RSpec.describe "Article claims" do
  it "pattern_match_string_keys returns Alice" do
    expect(pattern_match_string_keys).to eq("Alice")
  end

  it "match_parsed_json returns 42" do
    expect(match_parsed_json).to eq(42)
  end

  it "sym hash deconstruct_keys returns self" do
    expect(sym_hash_returns_self).to be true
  end

  it "str hash resolves to symbol keys with correct values" do
    expect(str_hash_resolves_to_symbols).to eq(["Alice", 30])
  end

  it "mixed hash resolves all keys" do
    expect(mixed_hash_resolves_both).to eq([1, 2, 3])
  end

  it "nested JSON match finds Alice" do
    expect(match_nested_api_response).to eq(["Alice"])
  end

  it "CSV match finds engineers without header_converters" do
    expect(match_csv_rows).to eq(["Alice", "Jane"])
  end

  it "Hash#[] is unchanged" do
    expect(bracket_still_returns_nil).to be_nil
  end

  it "Hash#key? is unchanged" do
    expect(key_question_still_false).to be false
  end

  it "failed match returns self for error messages" do
    expect(failed_match_preserves_hash_for_errors).to be true
  end
end
