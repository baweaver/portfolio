# frozen_string_literal: true

require_relative "rivulet"

RSpec.describe "Beyond Enumerable: Windows" do
  describe "#imperative_sum" do
    it "sums even numbers over 4, doubled" do
      expect(imperative_sum).to eq(5088)
    end
  end

  describe "#enumerable_sum" do
    it "produces the same result as the imperative version" do
      expect(enumerable_sum).to eq(imperative_sum)
    end
  end

  describe "#moving_average" do
    it "computes 3-element moving averages" do
      averages = moving_average([120, 130, 125, 140, 135, 128, 145, 132])

      expect(averages.size).to eq(6)
      expect(averages.first).to be_within(0.01).of(125.0)
    end
  end

  describe Window do
    describe "#push" do
      it "adds items and updates the running sum" do
        w = Window.new
        w.push(10).push(20).push(30)

        expect(w.sum).to eq(60)
        expect(w.size).to eq(3)
      end
    end

    describe "#shift" do
      it "removes the oldest item and decrements the sum" do
        w = Window.new
        w.push(10).push(20).push(30)
        w.shift

        expect(w.sum).to eq(50)
        expect(w.size).to eq(2)
      end

      it "returns nil on an empty window" do
        expect(Window.new.shift).to be_nil
      end
    end
  end

  describe "#pack_batches" do
    it "groups records under the byte limit" do
      records = "hello world this is a test".split
      batches = pack_batches(records, 12)

      batches.each { |b| expect(b.sum(&:bytesize)).to be <= 12 }
      expect(batches.flatten).to eq(records)
    end

    it "returns empty when given no records" do
      expect(pack_batches([], 10)).to be_empty
    end
  end

  describe "#pack_batches_window" do
    it "batches numbers under the limit" do
      records = [5, 3, 8, 2, 7, 4, 6, 1, 9, 3]
      batches = pack_batches_window(records, 10)

      batches.each { |b| expect(b.sum).to be <= 10 }
      expect(batches.flatten).to eq(records)
    end

    it "returns empty when given no records" do
      expect(pack_batches_window([], 10)).to be_empty
    end
  end

  describe "#slide_while" do
    it "yields windows satisfying the rule" do
      results = slide_while([5, 3, 8, 2, 7, 4, 6, 1, 9, 3], Window.new) { |w| w.sum <= 10 }
      results.each { |w| expect(w.sum).to be <= 10 }
    end

    it "returns empty when rule always fails" do
      results = slide_while([100, 200], Window.new) { |w| w.sum <= 0 }
      expect(results).to be_empty
    end
  end

  describe Rivulet do
    describe ".sum" do
      describe "#max_window" do
        it "finds the largest window size under budget" do
          result = Rivulet.sum([5, 3, 8, 2, 7, 4, 6, 1, 9, 3])
            .max_window { |w| w.sum <= 10 }
            .max_by { |w| w.size }

          expect(result).to be >= 2
        end

        it "returns nil when rule always fails" do
          result = Rivulet.sum([100, 200])
            .max_window { |w| w.sum <= 0 }
            .max_by { |w| w.size }

          expect(result).to be_nil
        end

        it "finds the first window exceeding a threshold" do
          result = Rivulet.sum([1, 2, 3, 4, 5])
            .max_window { |w| w.sum <= 20 }
            .first { |w| w.sum > 5 ? w.size : nil }

          expect(result).to eq(3)
        end
      end

      describe "#windows with block" do
        it "computes moving averages" do
          averages = Rivulet.sum([120, 130, 125, 140, 135, 128, 145, 132]).windows(3) { |w| w.average }

          expect(averages.size).to eq(6)
          expect(averages.first).to be_within(0.01).of(125.0)
        end

        it "skips nil return values" do
          results = Rivulet.sum([1, 2, 3, 4, 5]).windows(2) { |w| w.sum > 5 ? w.sum : nil }
          expect(results).to eq([7, 9])
        end
      end

      describe "#windows without block" do
        it "computes max sum across fixed windows" do
          sums = Rivulet.sum([10, 20, 30, 40]).windows(2) { |w| w.sum }
          expect(sums.max).to eq(70)
        end

        it "computes first average" do
          averages = Rivulet.sum([10, 20, 30]).windows(2) { |w| w.average }
          expect(averages.first).to eq(15.0)
        end

        it "skips nil values" do
          results = Rivulet.sum([1, 2, 3, 4]).windows(2) { |w| w.sum > 5 ? w.sum : nil }
          expect(results).to eq([7])
        end
      end

      describe Rivulet::SumWindow do
        describe "#evict" do
          it "returns nil on empty" do
            expect(Rivulet::SumWindow.new.evict).to be_nil
          end
        end

        describe "#average" do
          it "returns nil when empty" do
            expect(Rivulet::SumWindow.new.average).to be_nil
          end
        end
      end
    end

    describe ".count" do
      describe "#max_window" do
        it "finds the longest non-repeating window" do
          result = Rivulet.count([:a, :b, :c, :a, :d, :b, :e])
            .max_window { |w| !w.repeats? }
            .max_by { |w| w.size }

          expect(result).to be >= 3
        end

        it "handles all-repeating input" do
          result = Rivulet.count([:a, :a, :a])
            .max_window { |w| !w.repeats? }
            .max_by { |w| w.size }

          expect(result).to eq(1)
        end
      end

      describe Rivulet::CountWindow do
        describe "#evict" do
          it "returns nil on empty" do
            expect(Rivulet::CountWindow.new.evict).to be_nil
          end

          it "deletes count at zero" do
            w = Rivulet::CountWindow.new
            w.add(:a)
            w.evict
            expect(w.distinct).to eq(0)
          end

          it "preserves count when occurrences remain" do
            w = Rivulet::CountWindow.new
            w.add(:a)
            w.add(:a)
            w.evict
            expect(w.repeats?).to be false
            expect(w.distinct).to eq(1)
          end
        end
      end
    end
  end

  describe "#slide_while_batching" do
    it "returns the largest batch under budget" do
      result = slide_while_batching([5, 3, 8, 2, 7, 4, 6, 1, 9, 3], 10)
      expect(result.sum).to be <= 10
      expect(result.size).to be >= 2
    end
  end

  describe "#rivulet_batching" do
    it "returns the largest window size under budget" do
      result = rivulet_batching([5, 3, 8, 2, 7, 4, 6, 1, 9, 3], 10)
      expect(result).to be >= 2
    end
  end

  describe "#rivulet_moving_avg" do
    it "computes 3-element moving averages" do
      result = rivulet_moving_avg([120, 130, 125, 140, 135, 128, 145, 132])
      expect(result.size).to eq(6)
      expect(result.first).to be_within(0.01).of(125.0)
    end
  end

  describe "#rivulet_longest_unique" do
    it "finds the longest non-repeating run" do
      result = rivulet_longest_unique([:a, :b, :c, :a, :d, :b, :e])
      expect(result).to be >= 3
    end
  end

  describe "#length_of_longest_substring" do
    it "solves LeetCode 3" do
      expect(length_of_longest_substring("abcabcbb")).to eq(3)
      expect(length_of_longest_substring("bbbbb")).to eq(1)
      expect(length_of_longest_substring("")).to eq(0)
    end
  end

  describe "#longest_ones" do
    it "solves LeetCode 1004" do
      expect(longest_ones([1,1,1,0,0,0,1,1,1,1,0], 2)).to eq(6)
      expect(longest_ones([0,0,1,1,0,0,1,1,1,0,1,1,0,0,0,1,1,1,1], 3)).to eq(10)
    end
  end
end
