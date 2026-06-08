# frozen_string_literal: true

require_relative "heap"

RSpec.describe "Article claims: Beyond Enumerable Heaps" do
  describe "heapify equivalence" do
    it "heapify produces the same drain order as push-one-at-a-time" do
      items = (1..1_000).to_a.shuffle

      heapified = MinHeap[*items]
      pushed = MinHeap.new
      items.each { |n| pushed.push(n) }

      heapified_drain = []
      heapified_drain << heapified.pop until heapified.empty?

      pushed_drain = []
      pushed_drain << pushed.pop until pushed.empty?

      claim("heapify equivalence") { heapified_drain == pushed_drain ? "same answer" : "different" }.equals("same answer")
    end
  end

  describe "top k size bound" do
    it "heap never exceeds k+1 items during streaming" do
      k = 100
      max_seen = 0
      top = MinHeap.new

      500.times do |score|
        top.push(score)
        max_seen = [max_seen, top.size].max
        top.pop if top.size > k
      end

      claim("top k size bound") { max_seen <= k + 1 ? "a hundred and one" : "more than that" }.equals("a hundred and one")
    end
  end

  describe "heap faster than sort drain" do
    it "heap drain is a lower complexity class than repeated min_by" do
      n = 10_000
      items = (1..n).to_a.shuffle

      # Heap drain: O(n log n)
      heap = MinHeap[*items]
      heap_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      heap.pop until heap.empty?
      heap_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - heap_start

      # min_by drain: O(n²)
      list = items.dup
      sort_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      until list.empty?
        idx = list.each_with_index.min_by { |v, _| v }.last
        list.delete_at(idx)
      end
      sort_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - sort_start

      claim("heap faster than sort drain") { heap_time < sort_time ? "difference in complexity class" : "not faster" }.equals("difference in complexity class")
    end
  end
end
