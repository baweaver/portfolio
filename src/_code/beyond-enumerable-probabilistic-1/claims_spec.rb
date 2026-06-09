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
      claim("hll size") { bytes == 12 ? "Twelve kilobytes" : "#{bytes} KB" }.equals("Twelve kilobytes")
    end
  end
end
