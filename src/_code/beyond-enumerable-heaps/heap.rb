# frozen_string_literal: true

# segment: min_by_example
def next_job_min_by(jobs)
  jobs.min_by { |job| job.run_at }
end
# end: min_by_example

# segment: sort_then_shift
def next_job_sorted(jobs)
  jobs.sort_by!(&:run_at)
  jobs.shift
end
# end: sort_then_shift

# segment: min_heap_push
class MinHeap
  def initialize = (@items = [])

  def peek   = @items.first
  def size   = @items.size
  def empty? = @items.empty?

  def push(item)
    # drop it at the end
    @items.push(item)
    # bubble it up to restore the heap rule
    sift_up(@items.size - 1)
    self
  end
  alias << push

  private

  def sift_up(index)
    while index > 0
      # find the parent
      parent = (index - 1) / 2
      # parent is already smaller, done
      break if @items[parent] <= @items[index]
      # swap with parent and keep climbing
      @items[parent], @items[index] = @items[index], @items[parent]
      index = parent
    end
  end
end
# end: min_heap_push

# segment: min_heap_pop
class MinHeap
  def pop
    return nil if @items.empty?

    # save the root (the answer)
    smallest = @items.first
    # remove the last item
    last = @items.pop
    unless @items.empty?
      # put it in the now-vacant root
      @items[0] = last
      # sink it down to restore the heap rule
      sift_down(0)
    end
    smallest
  end

  private

  def sift_down(index)
    last = @items.size - 1
    loop do
      # find both children
      left  = (2 * index) + 1
      right = (2 * index) + 2
      # which of the three (self, left, right) is smallest?
      smallest = index
      smallest = left  if left  <= last && @items[left]  < @items[smallest]
      smallest = right if right <= last && @items[right] < @items[smallest]
      # if self is already smallest, we're done
      break if smallest == index
      # otherwise swap down and continue
      @items[index], @items[smallest] = @items[smallest], @items[index]
      index = smallest
    end
  end
end
# end: min_heap_pop

# segment: min_heap_usage
def min_heap_demo
  heap = MinHeap.new
  [5, 1, 8, 3].each { |number| heap.push(number) }
  [heap.peek, heap.pop, heap.pop, heap.size]
  # => [1, 1, 3, 2]
end
# end: min_heap_usage

# segment: min_heap_from
class MinHeap
  def self.[](*items)
    heap = new
    heap.replace(items)
    heap
  end

  def replace(items)
    @items = items.dup
    reorder
    self
  end

  private

  def reorder
    # start from the last node that has children and sift each one down
    last_parent = (@items.size / 2) - 1
    last_parent.downto(0) { |index| sift_down(index) }
  end
end
# end: min_heap_from

# segment: priority_queue
class PriorityQueue < MinHeap
  def initialize(&priority)
    @items = []
    @priority = priority || ->(item) { item }
  end

  private

  def priority_of(item) = @priority.call(item)

  def sift_up(index)
    while index > 0
      parent = (index - 1) / 2
      break if priority_of(@items[parent]) <= priority_of(@items[index])
      @items[parent], @items[index] = @items[index], @items[parent]
      index = parent
    end
  end

  def sift_down(index)
    last = @items.size - 1
    loop do
      left  = (2 * index) + 1
      right = (2 * index) + 2
      best = index
      best = left  if left  <= last && priority_of(@items[left])  < priority_of(@items[best])
      best = right if right <= last && priority_of(@items[right]) < priority_of(@items[best])
      break if best == index
      @items[index], @items[best] = @items[best], @items[index]
      index = best
    end
  end
end
# end: priority_queue

# segment: scheduler_loop
def drain_scheduler(jobs)
  queue = PriorityQueue.new { |job| job.run_at }

  jobs.each { |job| queue.push(job) }

  while (job = queue.peek) && job.run_at <= Time.now
    queue.pop.perform
  end
end
# end: scheduler_loop

# segment: top_k
def top_k(scores, k = 100)
  top = MinHeap.new

  scores.each do |score|
    top.push(score)
    top.pop if top.size > k
  end

  top
end
# end: top_k
