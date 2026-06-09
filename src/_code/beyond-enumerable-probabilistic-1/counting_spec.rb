# frozen_string_literal: true

require_relative "counting"

RSpec.describe "Beyond Enumerable: Counting Distinct" do
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

    describe ".salted" do
      it "produces different hashes for different salts" do
        expect(Hashing.salted("item", 0)).not_to eq(Hashing.salted("item", 1))
      end
    end
  end

  describe "#bit_right_shift_example" do
    it "keeps the top 3 bits" do
      expect(bit_right_shift_example).to eq(5)
    end
  end

  describe "#bit_mask_example" do
    it "keeps the bottom 3 bits" do
      expect(bit_mask_example).to eq(6)
    end
  end

  describe "#bit_set_example" do
    it "sets bit 6 of word 1" do
      expect(bit_set_example).to eq([0, 64])
    end
  end

  describe "#bit_check_example" do
    it "confirms the bit is set" do
      expect(bit_check_example).to eq(true)
    end
  end

  describe LinearCounting do
    it "estimates distinct count within 5% for 10k items" do
      counter = LinearCounting.new(bits: 1 << 20)
      10_000.times { |i| counter.add("user_#{i}") }

      estimate = counter.estimate
      expect(estimate).to be_within(500).of(10_000)
    end

    it "handles duplicates without inflating the count" do
      counter = LinearCounting.new(bits: 1 << 20)
      1_000.times { counter.add("same_item") }
      5_000.times { |i| counter.add("unique_#{i}") }

      estimate = counter.estimate
      expect(estimate).to be_within(300).of(5_000)
    end

    it "returns the bit count when saturated" do
      counter = LinearCounting.new(bits: 64)
      1_000.times { |i| counter.add("item_#{i}") }

      expect(counter.estimate).to eq(64)
    end
  end

  describe HyperLogLog do
    describe "#add and #estimate" do
      it "estimates 100k distinct within 2%" do
        hll = HyperLogLog.new(precision: 14)
        100_000.times { |i| hll.add("user_#{i}") }

        estimate = hll.estimate
        expect(estimate).to be_within(2_000).of(100_000)
      end

      it "estimates 1M distinct within 2%" do
        hll = HyperLogLog.new(precision: 14)
        1_000_000.times { |i| hll.add("visitor_#{i}") }

        estimate = hll.estimate
        expect(estimate).to be_within(20_000).of(1_000_000)
      end

      it "handles duplicates" do
        hll = HyperLogLog.new(precision: 14)
        50_000.times { |i| hll.add("real_#{i}") }
        100_000.times { hll.add("duplicate") }

        estimate = hll.estimate
        expect(estimate).to be_within(1_000).of(50_001)
      end
    end

    describe "#merge" do
      it "combines two sketches correctly" do
        a = HyperLogLog.new(precision: 14)
        b = HyperLogLog.new(precision: 14)

        50_000.times { |i| a.add("shard_a_#{i}") }
        50_000.times { |i| b.add("shard_b_#{i}") }

        merged = a.merge(b)
        expect(merged.estimate).to be_within(2_000).of(100_000)
      end

      it "handles overlapping items" do
        a = HyperLogLog.new(precision: 14)
        b = HyperLogLog.new(precision: 14)

        # A has items 0..74999, B has items 50000..124999
        # overlap is 50000..74999 (25k), union is 0..124999 (125k)
        75_000.times { |i| a.add("item_#{i}") }
        75_000.times { |i| b.add("item_#{i + 50_000}") }

        merged = a.merge(b)
        expect(merged.estimate).to be_within(2_500).of(125_000)
      end

      it "raises on precision mismatch" do
        a = HyperLogLog.new(precision: 10)
        b = HyperLogLog.new(precision: 14)

        expect { a.merge(b) }.to raise_error(ArgumentError, /precision mismatch/)
      end
    end
  end
end
