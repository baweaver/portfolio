# frozen_string_literal: true

# segment: imperative_sum
def imperative_sum
  sum = 0
  for item in 1..100
    sum += item * 2 if item > 4 && item.even?
  end
  sum
end
# end: imperative_sum

# segment: enumerable_sum
def enumerable_sum
  (1..100).select { |v| v.even? && v > 4 }.map { |v| v * 2 }.sum
end
# end: enumerable_sum

# segment: each_cons
def moving_average(latencies)
  latencies.each_cons(3).map { |window| window.sum.fdiv(3) }
end
# end: each_cons

# segment: pack_batches
def pack_batches(records, max_bytes)
  batches = []
  current = []
  size = 0

  records.each do |record|
    bytes = record.bytesize

    if size + bytes > max_bytes && current.any?
      batches << current
      current = []
      size = 0
    end

    current << record
    size += bytes
  end

  batches << current if current.any?
  batches
end
# end: pack_batches

# segment: window_class
class Window
  attr_reader :sum

  def initialize
    @items = []
    @sum = 0
  end

  def size  = @items.size
  def empty? = @items.empty?
  def to_a  = @items.dup

  def push(item)
    @items << item
    @sum += item
    self
  end

  def shift
    item = @items.shift
    @sum -= item if item
    item
  end
end
# end: window_class

# segment: pack_with_window
def pack_batches_window(records, max_bytes)
  batches = []
  window = Window.new

  records.each do |record|
    if window.sum + record > max_bytes && !window.empty?
      batches << window.to_a
      window = Window.new
    end
    window.push(record)
  end

  batches << window.to_a unless window.empty?
  batches
end
# end: pack_with_window

# segment: slide_while
def slide_while(items, window, &rule_function)
  results = []

  items.each do |item|
    window.push(item)
    window.shift until window.empty? || rule_function.call(window)
    results << window.to_a unless window.empty?
  end

  results
end
# end: slide_while

# segment: slide_while_usage
def slide_while_batching(records, max_bytes)
  slide_while(records, Window.new) { |w| w.sum <= max_bytes }.max_by(&:size)
end
# end: slide_while_usage

# --- Final implementation, built in steps ---

# Step 1: The stream wraps a collection and knows how to slide a window across it.
# segment: rivulet_stream_variable
module Rivulet
  class BaseWindow
    def initialize = (@items = [])
    def size = @items.size
    def empty? = @items.empty?
    def add(item) = (@items.push(item); self)
    def evict = @items.shift
  end

  class Stream
    def initialize(source) = (@source = source)

    # The core loop: grow the window, shrink when the rule breaks,
    # yield the live window at each valid position.
    def iterate_windows(rule:)
      window = new_window
      @source.each do |item|
        window.add(item)
        window.evict until window.empty? || rule.call(window)
        yield window unless window.empty?
      end
    end

    private def new_window = BaseWindow.new
  end
end
# end: rivulet_stream_variable


# Step 2: The builder defers the traversal. Terminal methods run it with your block.
# segment: rivulet_builder
module Rivulet
  class WindowBuilder
    def initialize(stream, rule:)
      @stream, @rule = stream, rule
    end

    # Fold the window down to the single best score.
    # Only the score is retained, never the window itself.
    def max_by(&block)
      best = nil
      @stream.iterate_windows(rule: @rule) do |w|
        score = block.call(w)
        best = score if best.nil? || score > best
      end
      best
    end

    # Collect non-nil results from each valid window position.
    def each_window(&block)
      results = []
      @stream.iterate_windows(rule: @rule) do |w|
        v = block.call(w)
        results << v if v
      end
      results
    end

    # Return the first non-nil result and stop traversing.
    def first(&block)
      result = nil
      @stream.iterate_windows(rule: @rule) do |w|
        result = block.call(w)
        break if result
      end
      result
    end
  end

  class Stream
    # max_window returns a builder, not results.
    # The traversal happens when you call a terminal method.
    def max_window(&rule) = WindowBuilder.new(self, rule: rule)


    # Fixed windows run immediately with a block (filter-map semantics).
    def windows(size, &block)
      results = []
      window = new_window
      @source.each do |item|
        window.add(item)
        window.evict while window.size > size
        next unless window.size == size
        v = block.call(window)
        results << v if v
      end
      results
    end
  end
end
# end: rivulet_builder

# Step 3: Window subclasses carry different state. Each stream picks its own.
# segment: rivulet_windows
module Rivulet
  # Tracks a running sum. O(1) to ask for sum or average at any point.
  class SumWindow < BaseWindow
    def initialize = (super; @sum = 0)
    def add(item) = (@sum += item; super)
    def evict = (item = super; @sum -= item if item; item)
    def sum = @sum
    def average = empty? ? nil : @sum.fdiv(size)
  end

  # Tracks item frequencies. O(1) to check for repeats or distinct count.
  class CountWindow < BaseWindow
    def initialize = (super; @counts = Hash.new(0))
    def add(item) = (@counts[item] += 1; super)

    def evict
      item = super
      if item
        @counts[item] -= 1
        @counts.delete(item) if @counts[item].zero?
      end
      item
    end

    def repeats? = @counts.any? { |_, n| n > 1 }
    def distinct = @counts.size
  end

  class SumStream < Stream
    private def new_window = SumWindow.new
  end

  class CountStream < Stream
    private def new_window = CountWindow.new
  end
end
# end: rivulet_windows

# Step 4: Entry points hide everything behind a name.
# segment: rivulet_entry_points
module Rivulet
  def self.sum(source) = SumStream.new(source)
  def self.count(source) = CountStream.new(source)
end
# end: rivulet_entry_points

# segment: rivulet_batching
def rivulet_batching(records, max_bytes)
  Rivulet.sum(records).max_window { |w| w.sum <= max_bytes }.max_by { |w| w.size }
end
# end: rivulet_batching

# segment: rivulet_moving_avg
def rivulet_moving_avg(latencies)
  Rivulet.sum(latencies).windows(3) { |w| w.average }
end
# end: rivulet_moving_avg

# segment: rivulet_longest_unique
def rivulet_longest_unique(events)
  Rivulet.count(events).max_window { |w| !w.repeats? }.max_by { |w| w.size }
end
# end: rivulet_longest_unique

# segment: example_longest_substring
# LeetCode 3: Longest Substring Without Repeating Characters
def length_of_longest_substring(s)
  Rivulet.count(s.chars).max_window { |w| !w.repeats? }.max_by { |w| w.size } || 0
end
# end: example_longest_substring

# segment: example_max_ones
# LeetCode 1004: Max Consecutive Ones III
# Longest subarray of 1s if you can flip at most k zeros.
def longest_ones(nums, k)
  Rivulet.sum(nums).max_window { |w| w.size - w.sum <= k }.max_by { |w| w.size }
end
# end: example_max_ones
