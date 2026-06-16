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
  end

  describe "#bit_left_shift_example" do
    it "shifts 1 left by 3 positions" do
      expect(bit_left_shift_example).to eq(8)
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

  describe "#bit_set_single_example" do
    it "turns on bit 3 of 32" do
      expect(bit_set_single_example).to eq(40)
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

  describe "#leading_zeros" do
    it "counts zeros before the first 1" do
      expect(leading_zeros(0b00000101, total_bits: 8)).to eq(5)
      expect(leading_zeros(0b10000000, total_bits: 8)).to eq(0)
      expect(leading_zeros(0b00000000, total_bits: 8)).to eq(8)
    end

    it "works on 64-bit values" do
      value = (1 << 49)
      expect(leading_zeros(value, total_bits: 64)).to eq(14)
    end
  end

  describe "#leading_zeros_string_examples" do
    it "runs without error" do
      expect(leading_zeros_string_examples).to eq(7)
    end
  end

  describe "#harmonic_mean" do
    it "resists outliers better than arithmetic mean" do
      values = [1, 1, 1, 100]
      arithmetic = values.sum.to_f / values.size  # 25.75

      h_mean = harmonic_mean(values)  # ≈ 1.33

      expect(h_mean).to be_within(0.1).of(1.33)
      expect(h_mean).to be < arithmetic
    end

    it "equals the value for uniform inputs" do
      values = [5, 5, 5, 5]
      expect(harmonic_mean(values)).to be_within(0.01).of(5.0)
    end
  end

  describe "#linear_counting_estimate" do
    it "estimates distinct count from total bits and zeros remaining" do
      # 1 million bits, 900k still zero => not many distinct items yet
      estimate = linear_counting_estimate(1_000_000, 900_000)
      expect(estimate).to be_within(1000).of(105_361)

      # 1 million bits, 100k still zero => many distinct items
      estimate = linear_counting_estimate(1_000_000, 100_000)
      expect(estimate).to be_within(1000).of(2_302_585)
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

    describe "small-range correction" do
      it "uses linear counting fallback for small cardinalities" do
        hll = HyperLogLog.new(precision: 14)
        100.times { |i| hll.add("small_#{i}") }
        expect(hll.estimate).to be_within(10).of(100)
      end
    end
  end

  describe HyperLogLogString do
    it "produces the same estimate as the bit-based version" do
      string_hll = HyperLogLogString.new(precision: 14)
      bit_hll = HyperLogLog.new(precision: 14)

      10_000.times { |i| string_hll.add(i); bit_hll.add(i) }
      expect(string_hll.estimate).to eq(bit_hll.estimate)
    end

    it "handles merge" do
      a = HyperLogLogString.new(precision: 14)
      b = HyperLogLogString.new(precision: 14)

      5_000.times { |i| a.add("a_#{i}") }
      5_000.times { |i| b.add("b_#{i}") }

      merged = a.merge(b)
      expect(merged.estimate).to be_within(500).of(10_000)
    end

    it "takes the large-estimate path when cardinality is high" do
      hll = HyperLogLogString.new(precision: 14)
      100_000.times { |i| hll.add("big_#{i}") }
      expect(hll.estimate).to be_within(2_000).of(100_000)
    end
  end

  describe LinearCountingString do
    it "estimates distinct count" do
      counter = LinearCountingString.new(bits: 1 << 16)
      5_000.times { |i| counter.add("item_#{i}") }
      expect(counter.estimate).to be_within(500).of(5_000)
    end

    it "returns bit count when saturated" do
      counter = LinearCountingString.new(bits: 64)
      1_000.times { |i| counter.add("item_#{i}") }
      expect(counter.estimate).to eq(64)
    end
  end

  describe "#hyperloglog_trace" do
    it "runs without error" do
      expect { hyperloglog_trace }.to output(/estimate after 10 distinct/).to_stdout
    end
  end

  describe "#hyperloglog_merge_example" do
    it "returns an estimate near 10000" do
      expect(hyperloglog_merge_example).to be_within(500).of(10_000)
    end
  end
end
