# frozen_string_literal: true

require_relative "examples"

RSpec.describe "Patching CRuby: String-Key Pattern Matching" do
  describe "the core feature" do
    it "matches symbol patterns against string-keyed hashes" do
      expect(pattern_match_string_keys).to eq("Alice")
    end

    it "matches parsed JSON without symbolize_keys" do
      expect(match_parsed_json).to eq(42)
    end

    it "matches nested API responses" do
      expect(match_nested_api_response).to eq(["Alice"])
    end

    it "matches CSV rows without header_converters" do
      expect(match_csv_rows).to eq(["Alice", "Jane"])
    end
  end

  describe "deconstruct_keys behavior" do
    it "returns self for symbol-only hashes (zero alloc)" do
      expect(sym_hash_returns_self).to be true
    end

    it "resolves symbol keys against string-keyed hashes" do
      expect(str_hash_resolves_to_symbols).to eq(["Alice", 30])
    end

    it "resolves both symbol and string keys in mixed hashes" do
      expect(mixed_hash_resolves_both).to eq([1, 2, 3])
    end

    it "returns self when no string fallback helped (preserves error messages)" do
      expect(failed_match_preserves_hash_for_errors).to be true
    end

    it "allocates nothing on the symbol fast path" do
      expect(fast_path_returns_self_when_all_keys_hit).to be true
    end
  end

  describe "safety: rest of Hash API unchanged" do
    it "Hash#[] still returns nil for symbol key on string hash" do
      expect(bracket_still_returns_nil).to be_nil
    end

    it "Hash#key? still returns false for symbol on string hash" do
      expect(key_question_still_false).to be false
    end
  end

  describe "the workaround this replaces" do
    it "deep_symbolize + pattern match works (but requires ceremony)" do
      expect(match_json_with_symbolize).to eq(42)
    end
  end

  describe "performance", :benchmark do
    it "string-key matching is within 2x of native symbol matching" do
      results = benchmark_three_paths(iterations: 500_000)
      ratio = results[:str_ns] / results[:sym_ns]
      expect(ratio).to be < 2.0
    end

    it "symbol-key matching has no measurable regression" do
      results = benchmark_three_paths(iterations: 500_000)
      # Symbol path should be under 200ns (typical: ~170ns)
      expect(results[:sym_ns]).to be < 250
    end
  end
end
