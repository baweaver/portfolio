# frozen_string_literal: true

require_relative "counting"

RSpec.describe "Article claims: Counting Distinct" do
  describe "twenty heads odds" do
    it "20 consecutive heads is approximately one in a million" do
      odds = 2**20
      claim("twenty heads odds") { odds >= 1_000_000 && odds <= 1_100_000 ? "one in about a million" : "wrong" }.equals("one in about a million")
    end
  end

  describe "million bit map size" do
    it "1,048,576 bits is 128 KB" do
      kb = (1 << 20) / 8 / 1024
      claim("million bit map size") { kb == 128 ? "128 KB" : "#{kb} KB" }.equals("128 KB")
    end
  end

  describe "hll standard error" do
    it "1.04 / sqrt(16384) is about 0.8%" do
      error = (1.04 / Math.sqrt(16_384) * 100).round(1)
      claim("hll standard error") { error <= 0.9 && error >= 0.7 ? "0.8%" : "#{error}%" }.equals("0.8%")
    end
  end

  describe "hll size" do
    it "16384 registers at 6 bits each is about 12 KB" do
      bytes = (16_384 * 6.0 / 8 / 1024).round
      claim("hll size") { bytes == 12 ? "twelve kilobytes" : "#{bytes} KB" }.equals("twelve kilobytes")
    end
  end

  describe "trace observations" do
    let(:hll) do
      h = HyperLogLogString.new(precision: 4)
      %w[alice bob carol dave eve frank grace heidi ivan judy].each { |n| h.add(n) }
      h
    end

    it "eve lands in bucket 8 with rank 2 but bob already set it to 4" do
      # bob's rank in bucket 8
      bob_bits = format("%064b", Hashing.to_64_bits("bob"))
      bob_index = bob_bits[0, 4].to_i(2)
      bob_rank = (bob_bits[4..].index("1") || 60) + 1

      # eve's rank in bucket 8
      eve_bits = format("%064b", Hashing.to_64_bits("eve"))
      eve_index = eve_bits[0, 4].to_i(2)
      eve_rank = (eve_bits[4..].index("1") || 60) + 1

      claim("eve bucket is 8") { eve_index }.equals(8)
      claim("eve rank is 2") { eve_rank }.equals(2)
      claim("bob bucket is 8") { bob_index }.equals(8)
      claim("bob rank is 4") { bob_rank }.equals(4)
      claim("bucket 8 keeps bob's rank") { hll.registers[8] }.equals(4)
    end

    it "estimate after 10 distinct is 11" do
      claim("trace estimate") { hll.estimate }.equals(11)
    end
  end

  describe "string and bit versions match" do
    it "produces the same estimate for 10k items" do
      string_hll = HyperLogLogString.new(precision: 14)
      bit_hll = HyperLogLog.new(precision: 14)
      10_000.times { |i| string_hll.add(i); bit_hll.add(i) }

      claim("string and bit match") {
        string_hll.estimate == bit_hll.estimate ? "identical" : "different"
      }.equals("identical")
    end
  end
end
