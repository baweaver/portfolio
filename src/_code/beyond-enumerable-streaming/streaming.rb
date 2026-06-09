# frozen_string_literal: true

require "tempfile"

# segment: readlines_count
def count_500s_eager(path)
  File.readlines(path).count { |line| line.include?(" 500 ") }
end
# end: readlines_count

# segment: foreach_count
def count_500s_streaming(path)
  File.foreach(path).count { |line| line.include?(" 500 ") }
end
# end: foreach_count

# segment: streaming_sum
def sum_column(path, column:)
  File.foreach(path).sum { |line| line.split(",").fetch(column).to_f }
end
# end: streaming_sum

# segment: lazy_first
def first_five_upcased(path)
  File.foreach(path).lazy.map { |line| line.upcase }.first(5)
end
# end: lazy_first

# segment: write_sorted_runs
def write_sorted_runs(input, chunk_size)
  runs = []

  input.each_slice(chunk_size) do |chunk|
    run = Tempfile.new("run")
    chunk.sort.each { |number| run.puts(number) }
    run.flush
    runs << run
  end

  runs
end
# end: write_sorted_runs

# segment: merge_sorted_pair
def merge_sorted_pair(left, right)
  merged = []
  left_index = 0
  right_index = 0

  while left_index < left.size && right_index < right.size
    if left[left_index] <= right[right_index]
      merged << left[left_index]
      left_index += 1
    else
      merged << right[right_index]
      right_index += 1
    end
  end

  merged.concat(left[left_index..])
  merged.concat(right[right_index..])
end
# end: merge_sorted_pair

# segment: heap
class Heap
  def initialize(by: ->(item) { item })
    @items = []
    @key = by
  end

  def size = @items.size
  def empty? = @items.empty?
  def peek = @items.first

  def push(item)
    @items << item
    sift_up(@items.size - 1)
    self
  end

  def pop
    return nil if @items.empty?

    root = @items.first
    last = @items.pop
    unless @items.empty?
      @items[0] = last
      sift_down(0)
    end
    root
  end

  private

  def compare(a, b) = @key.call(a) <=> @key.call(b)

  def sift_up(pos)
    while pos.positive?
      parent = (pos - 1) / 2
      break if compare(@items[pos], @items[parent]) >= 0
      @items[pos], @items[parent] = @items[parent], @items[pos]
      pos = parent
    end
  end

  def sift_down(pos)
    count = @items.size
    loop do
      left = (2 * pos) + 1
      right = (2 * pos) + 2
      smallest = pos
      smallest = left if left < count && compare(@items[left], @items[smallest]).negative?
      smallest = right if right < count && compare(@items[right], @items[smallest]).negative?
      break if smallest == pos
      @items[pos], @items[smallest] = @items[smallest], @items[pos]
      pos = smallest
    end
  end
end
# end: heap

# segment: kway_merge
class KWayMerge
  Front = Struct.new(:value, :source)

  def self.merge(sorted_sources)
    Enumerator.new do |yielder|
      cursors = sorted_sources.map(&:each)
      frontier = Heap.new(by: ->(front) { front.value })

      cursors.each_with_index do |cursor, index|
        pull_next(cursor) { |value| frontier.push(Front.new(value, index)) }
      end

      until frontier.empty?
        smallest = frontier.pop
        yielder << smallest.value
        pull_next(cursors.fetch(smallest.source)) do |value|
          frontier.push(Front.new(value, smallest.source))
        end
      end
    end.lazy
  end

  def self.pull_next(cursor)
    yield cursor.next
  rescue StopIteration
    # source exhausted
  end
end
# end: kway_merge

# segment: external_sort
class ExternalSort
  def self.sort(input, chunk_size:)
    run_files = write_sorted_runs(input, chunk_size)
    sources = run_files.map { |file| read_integers(file.path) }
    [KWayMerge.merge(sources), run_files]
  end

  def self.write_sorted_runs(input, chunk_size)
    runs = []

    input.each_slice(chunk_size) do |chunk|
      run = Tempfile.new("run")
      chunk.sort.each { |number| run.puts(number) }
      run.flush
      runs << run
    end

    runs
  end

  def self.read_integers(path)
    File.foreach(path).lazy.map { |line| Integer(line) }
  end
end
# end: external_sort
