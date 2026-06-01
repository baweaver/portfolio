# frozen_string_literal: true

require_relative "rivulet"

RSpec.describe "Article claims: Beyond Enumerable Windows" do
  describe "imperative enumerable equivalence" do
    it "both produce the same result" do
      claim("imperative enumerable equivalence") { imperative_sum }.equals(enumerable_sum)
    end
  end

  describe "reducer allocation order" do
    it "builder allocates around 670 objects" do
      data = (1..200_000).map { rand(1..100) }
      allocs = count_allocations do
        Rivulet.sum(data).max_window { |w| w.sum <= 500 }.max_by { |w| w.size }
      end

      claim("reducer allocation order") { allocs }.is_less_than { 1_000 }
    end
  end

  describe "emit reduce equivalence" do
    it "builder produces the same answer as a hand-rolled loop" do
      data = (1..200_000).map { rand(1..100) }

      # Hand-rolled two-pointer version
      best = 0
      left = 0
      sum = 0
      data.each_with_index do |item, right|
        sum += item
        while sum > 500
          sum -= data[left]
          left += 1
        end
        best = [best, right - left + 1].max
      end

      builder = Rivulet.sum(data).max_window { |w| w.sum <= 500 }.max_by { |w| w.size }

      claim("emit reduce equivalence") { builder }.equals(best)
    end
  end
end
