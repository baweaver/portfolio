# frozen_string_literal: true

require_relative "bloom"

RSpec.describe "Beyond Enumerable: Bloom Filters" do
  describe Hashing do
    describe ".to_64_bits" do
      it "returns a consistent integer for the same input" do
        expect(Hashing.to_64_bits("hello")).to eq(Hashing.to_64_bits("hello"))
      end

      it "returns different values for different inputs" do
        expect(Hashing.to_64_bits("hello")).not_to eq(Hashing.to_64_bits("world"))
      end

      it "fits in 64 bits" do
        expect(Hashing.to_64_bits("test")).to be < (2**64)
      end
    end
  end

  describe BloomFilter do
    let(:filter) { BloomFilter.new(bit_count: 1000, hash_count: 7) }

    it "reports added items as present" do
      filter.add("alice")
      expect(filter.include?("alice")).to be true
    end

    it "reports items never added as absent (most of the time)" do
      100.times { |i| filter.add("item-#{i}") }
      # With 1000 bits and 100 items, false positives should be rare
      absent_count = 100
      false_positives = (0...absent_count).count { |i| filter.include?("absent-#{i}") }
      expect(false_positives).to be < (absent_count * 0.1) # less than 10%
    end

    it "never produces false negatives" do
      items = (0...500).map { |i| "item-#{i}" }
      items.each { |item| filter.add(item) }
      items.each { |item| expect(filter.include?(item)).to be(true), "false negative for #{item}" }
    end

    it "returns hash_count positions per item" do
      expect(filter.positions("alice").size).to eq(7)
    end

    it "returns positions within bit_count" do
      filter.positions("alice").each do |pos|
        expect(pos).to be >= 0
        expect(pos).to be < 1000
      end
    end
  end

  describe PackedBloomFilter do
    let(:filter) { PackedBloomFilter.new(bit_count: 1000, hash_count: 7) }

    it "reports added items as present" do
      filter.add("alice")
      expect(filter.include?("alice")).to be true
    end

    it "never produces false negatives" do
      items = (0...500).map { |i| "item-#{i}" }
      items.each { |item| filter.add(item) }
      items.each { |item| expect(filter.include?(item)).to be(true), "false negative for #{item}" }
    end

    it "has a similar false positive rate to the readable version" do
      item_count = 10_000
      bits_per_item = 9.59
      bit_count = (bits_per_item * item_count).ceil

      packed = PackedBloomFilter.new(bit_count: bit_count, hash_count: 7)
      item_count.times { |i| packed.add("item-#{i}") }

      fp = (0...10_000).count { |i| packed.include?("absent-#{i}") }
      rate = fp.to_f / 10_000
      expect(rate).to be < 0.02 # under 2%, target is ~1%
    end
  end

  describe "#one_bit_example" do
    it "shows hash positions and membership checks" do
      output = one_bit_example
      expect(output).to include("hash(alice)")
      expect(output).to include("hash(bob)")
      expect(output).to include("was added")
      expect(output).to include("was never added")
    end
  end

  describe "#watch_it_work" do
    it "produces output showing the bitmap filling" do
      output = watch_it_work
      expect(output).to include("start")
      expect(output).to include("add alice")
      expect(output).to include("add frank")
      expect(output.lines.first).to include("00000000000000000000000000000000")
    end
  end

  describe "#query_demo" do
    it "shows members and non-members" do
      output = query_demo
      expect(output).to include("members (each was added)")
      expect(output).to include("non-members (never added)")
      expect(output).to include("include?(alice")
    end
  end

  describe "#false_positive_rate" do
    it "returns a value between 0 and 1" do
      rate = false_positive_rate(10_000, 1_000, 7)
      expect(rate).to be > 0
      expect(rate).to be < 1
    end

    it "decreases as bit_count grows" do
      small = false_positive_rate(1_000, 100, 7)
      large = false_positive_rate(10_000, 100, 7)
      expect(large).to be < small
    end

    it "approximates 1% at 10 bits/item with 7 hashes" do
      rate = false_positive_rate(10_000, 1_000, 7)
      expect(rate).to be_within(0.005).of(0.008) # theoretical is ~0.82%
    end
  end

  describe "#optimal_hashes" do
    it "returns 7 for 10 bits per item" do
      expect(optimal_hashes(10)).to eq(7)
    end

    it "returns 3 for ~4.8 bits per item" do
      expect(optimal_hashes(4.79)).to eq(3)
    end
  end

  describe "#sweep_hash_count" do
    it "produces output with minimum near predicted optimum" do
      output = sweep_hash_count
      expect(output).to include("predicted best hash count")
      expect(output).to include("<- predicted optimum")
    end
  end

  describe "#sizing_table" do
    it "shows targets and measured rates" do
      output = sizing_table
      expect(output).to include("target  10.0%")
      expect(output).to include("target   1.0%")
      expect(output).to include("target   0.1%")
    end
  end

  describe "#memory_comparison" do
    it "shows the size ratio" do
      output = memory_comparison
      expect(output).to include("Set of 1,000,000 URLs")
      expect(output).to include("Bloom filter")
      expect(output).to include("ratio")
    end
  end

  describe "#accuracy_test" do
    it "shows zero false negatives and ~1% FP" do
      output = accuracy_test
      expect(output).to include("false negatives: 0")
      expect(output).to match(/measured FP: [01]\.\d+%/)
    end
  end

  describe "#merge_demo" do
    it "shows merged filter containing both sides" do
      output = merge_demo
      expect(output).to include("east-user-42")
      expect(output).to include("west-user-99")
      expect(output).to include("all east members present in union? true")
      expect(output).to include("all west members present in union? true")
    end
  end

  describe "#merge_operation" do
    it "OR-combines two bitmaps" do
      east = BloomFilter.new(bit_count: 1000, hash_count: 7)
      west = BloomFilter.new(bit_count: 1000, hash_count: 7)
      east.add("alice")
      west.add("bob")

      merged = merge_operation(east, west)

      # Both items' positions should be on in the merged result
      east.positions("alice").each { |pos| expect(merged[pos]).to be true }
      west.positions("bob").each { |pos| expect(merged[pos]).to be true }
    end
  end

  describe "#deletion_demo" do
    it "shows deletion creating a false negative" do
      output = deletion_demo
      expect(output).to include("Before deleting alice: include?(bob) -> true")
      expect(output).to include("After  deleting alice: include?(bob) -> false")
    end
  end

  describe "#packed_accuracy_test" do
    it "shows zero false negatives and ~1% FP" do
      output = packed_accuracy_test
      expect(output).to include("false negatives: 0")
      expect(output).to match(/measured FP: [01]\.\d+%/)
    end
  end

  describe "#benchmark_filters" do
    it "runs without error" do
      expect { benchmark_filters }.to output(/Comparison/).to_stdout
    end
  end
end
