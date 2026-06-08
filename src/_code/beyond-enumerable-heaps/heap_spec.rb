# frozen_string_literal: true

require_relative "heap"

RSpec.describe "Beyond Enumerable: Heaps" do
  describe "#next_job_min_by" do
    it "returns the job with the earliest run_at" do
      Job = Struct.new(:name, :run_at) unless defined?(Job)
      jobs = [Job.new("late", 100), Job.new("soon", 10), Job.new("mid", 50)]

      expect(next_job_min_by(jobs).name).to eq("soon")
    end
  end

  describe "#next_job_sorted" do
    it "mutates the array and shifts the earliest job" do
      SortJob = Struct.new(:name, :run_at) unless defined?(SortJob)
      jobs = [SortJob.new("late", 100), SortJob.new("soon", 10), SortJob.new("mid", 50)]
      result = next_job_sorted(jobs)

      expect(result.name).to eq("soon")
      expect(jobs.size).to eq(2)
    end
  end

  describe MinHeap do
    describe "#push and #peek" do
      it "keeps the smallest item at the top" do
        heap = MinHeap.new
        [5, 1, 8, 3].each { |n| heap.push(n) }

        expect(heap.peek).to eq(1)
      end
    end

    describe "#pop" do
      it "removes and returns items in sorted order" do
        heap = MinHeap.new
        [5, 1, 8, 3].each { |n| heap.push(n) }

        expect(heap.pop).to eq(1)
        expect(heap.pop).to eq(3)
        expect(heap.pop).to eq(5)
        expect(heap.pop).to eq(8)
      end

      it "returns nil when empty" do
        expect(MinHeap.new.pop).to be_nil
      end

      it "handles a single-element heap" do
        heap = MinHeap.new
        heap.push(42)

        expect(heap.pop).to eq(42)
        expect(heap).to be_empty
      end
    end

    describe "duplicate values" do
      it "handles equal items without corruption" do
        heap = MinHeap.new
        [3, 1, 3, 1, 2, 2].each { |n| heap.push(n) }

        results = []
        results << heap.pop until heap.empty?
        expect(results).to eq([1, 1, 2, 2, 3, 3])
      end
    end

    describe "#size and #empty?" do
      it "tracks the count" do
        heap = MinHeap.new
        expect(heap).to be_empty

        heap.push(1)
        expect(heap.size).to eq(1)
        expect(heap).not_to be_empty
      end
    end

    describe ".[]" do
      it "builds a heap from items in O(n)" do
        heap = MinHeap[5, 1, 8, 3, 2, 9, 4]

        results = []
        results << heap.pop until heap.empty?
        expect(results).to eq([1, 2, 3, 4, 5, 8, 9])
      end

      it "produces the same result as pushing items one at a time" do
        items = [17, 3, 25, 1, 8, 42, 5, 12, 9, 2, 33, 7]

        heapified = MinHeap[*items]
        pushed = MinHeap.new
        items.each { |n| pushed.push(n) }

        heapified_drain = []
        heapified_drain << heapified.pop until heapified.empty?

        pushed_drain = []
        pushed_drain << pushed.pop until pushed.empty?

        expect(heapified_drain).to eq(pushed_drain)
      end
    end

    describe "<< alias" do
      it "works like push" do
        heap = MinHeap.new
        heap << 3 << 1 << 2

        expect(heap.peek).to eq(1)
      end
    end

    describe "#replace" do
      it "replaces the heap contents and re-heapifies" do
        heap = MinHeap.new
        heap.push(99)
        heap.replace([7, 2, 5])

        expect(heap.pop).to eq(2)
        expect(heap.pop).to eq(5)
        expect(heap.pop).to eq(7)
      end
    end
  end

  describe PriorityQueue do
    PQJob = Struct.new(:name, :run_at)

    describe "ordering by block" do
      it "pops items by priority, not insertion order" do
        queue = PriorityQueue.new { |job| job.run_at }
        queue.push(PQJob.new("late", 100))
        queue.push(PQJob.new("soon", 10))
        queue.push(PQJob.new("mid", 50))

        expect(queue.pop.name).to eq("soon")
        expect(queue.pop.name).to eq("mid")
        expect(queue.pop.name).to eq("late")
      end
    end

    describe "default priority" do
      it "uses the item itself when no block given" do
        queue = PriorityQueue.new
        [5, 1, 8].each { |n| queue.push(n) }

        expect(queue.pop).to eq(1)
      end
    end

    describe "inherited methods use overridden sift" do
      it "self.[] works correctly with a priority block via replace/heapify" do
        queue = PriorityQueue.new { |job| job.run_at }
        queue.replace([PQJob.new("late", 100), PQJob.new("soon", 10), PQJob.new("mid", 50)])

        expect(queue.pop.name).to eq("soon")
        expect(queue.pop.name).to eq("mid")
        expect(queue.pop.name).to eq("late")
      end
    end
  end

  describe "#min_heap_demo" do
    it "returns expected values matching prose claims" do
      peek, first_pop, second_pop, size = min_heap_demo

      expect(peek).to eq(1)
      expect(first_pop).to eq(1)
      expect(second_pop).to eq(3)
      expect(size).to eq(2)
    end
  end

  describe "#top_k" do
    it "keeps only the k largest items" do
      scores = [10, 90, 30, 80, 50, 70, 20, 60, 40, 100]
      heap = top_k(scores, 3)

      results = []
      results << heap.pop until heap.empty?
      expect(results.sort).to eq([80, 90, 100])
    end

    it "handles k larger than the input" do
      heap = top_k([3, 1, 2], 10)

      results = []
      results << heap.pop until heap.empty?
      expect(results.sort).to eq([1, 2, 3])
    end
  end
end
