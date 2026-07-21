# frozen_string_literal: true

require "digest"

# segment: hashing
module Hashing
  module_function

  # A stable 64-bit integer for any item.
  def to_64_bits(item)
    Digest::SHA256.hexdigest(item.to_s)[0, 16].to_i(16)
  end
end
# end: hashing

# segment: one_bit_example
def one_bit_example
  bit_count = 32
  bitmap = Array.new(bit_count, false)

  lines = []

  # Record "alice"
  alice_pos = Hashing.to_64_bits("alice") % bit_count
  bitmap[alice_pos] = true
  lines << "hash(alice) % #{bit_count} = #{alice_pos}  -> bitmap[#{alice_pos}] = true"

  # Record "bob"
  bob_pos = Hashing.to_64_bits("bob") % bit_count
  bitmap[bob_pos] = true
  lines << "hash(bob)   % #{bit_count} = #{bob_pos}  -> bitmap[#{bob_pos}] = true"

  lines << ""

  # Check membership
  lines << "bitmap[#{alice_pos}] -> #{bitmap[alice_pos]}  (alice was added)"
  lines << "bitmap[#{bob_pos}] -> #{bitmap[bob_pos]}  (bob was added)"

  # Check something not added
  zoe_pos = Hashing.to_64_bits("zoe") % bit_count
  lines << "bitmap[#{zoe_pos}] -> #{bitmap[zoe_pos]}  (zoe was never added, #{bitmap[zoe_pos] ? "FALSE POSITIVE" : "correctly absent"})"

  mallory_pos = Hashing.to_64_bits("mallory") % bit_count
  lines << "bitmap[#{mallory_pos}] -> #{bitmap[mallory_pos]}  (mallory was never added, #{bitmap[mallory_pos] ? "FALSE POSITIVE" : "correctly absent"})"

  lines.join("\n")
end
# end: one_bit_example

# segment: bloom_filter
class BloomFilter
  attr_reader :bit_count, :hash_count, :bitmap

  def initialize(bit_count:, hash_count:)
    @bit_count = bit_count
    @hash_count = hash_count
    # A row of switches, all off.
    @bitmap = Array.new(bit_count, false)
  end

  # The positions one item is responsible for.
  #
  # Prepending the seed (0, 1, 2, ...) changes the input, so each hash
  # scatters somewhere unrelated. "alice" becomes hash_count positions.
  def positions(item)
    Array.new(@hash_count) do |seed|
      Hashing.to_64_bits("#{seed}:#{item}") % @bit_count
    end
  end

  # Record an item: turn on every bit it is responsible for.
  def add(item)
    positions(item).each { |position| @bitmap[position] = true }
    self
  end

  # Check an item: present only if every one of its bits is on.
  # A single off bit proves it was never added.
  def include?(item)
    positions(item).all? { |position| @bitmap[position] }
  end

  # Combine two filters by OR-ing their bitmaps.
  def merge(other)
    merged = BloomFilter.new(bit_count: @bit_count, hash_count: @hash_count)
    merged.bitmap.each_index { |index| merged.bitmap[index] = @bitmap[index] || other.bitmap[index] }
    merged
  end
end
# end: bloom_filter

# segment: render_bitmap
def render(bitmap)
  bitmap.map { |bit| bit ? "1" : "0" }.join
end
# end: render_bitmap

# segment: watch_it_work
def watch_it_work
  filter = BloomFilter.new(bit_count: 32, hash_count: 3)
  lines = []
  lines << "start                          #{render(filter.bitmap)}"

  %w[alice bob carol dave eve frank].each do |name|
    filter.add(name)
    spots = filter.positions(name).sort
    lines << format("add %-6s spots %-12s  %s", name, spots.inspect, render(filter.bitmap))
  end

  lines.join("\n")
end
# end: watch_it_work

# segment: query_demo
def query_demo
  filter = BloomFilter.new(bit_count: 32, hash_count: 3)
  %w[alice bob carol dave eve frank].each { |name| filter.add(name) }

  lines = []
  lines << "members (each was added):"
  %w[alice frank].each do |name|
    result = filter.include?(name)
    positions = filter.positions(name).sort
    lines << format("  include?(%-7s) -> %-5s  bits at %s all on", name, result, positions.inspect)
  end

  lines << ""
  lines << "non-members (never added):"
  %w[zoe mallory].each do |name|
    positions = filter.positions(name).sort
    bits_state = positions.map { |pos| filter.bitmap[pos] ? "on" : "off" }
    result = filter.include?(name)
    if result
      lines << format("  include?(%-7s) -> %-5s  bits at %s are %s (all on -> FALSE POSITIVE)", name, result, positions.inspect, bits_state.inspect)
    else
      lines << format("  include?(%-7s) -> %-5s  bits at %s are %s (one off -> absent, for certain)", name, result, positions.inspect, bits_state.inspect)
    end
  end

  lines.join("\n")
end
# end: query_demo

# segment: false_positive_rate
def false_positive_rate(bit_count, item_count, hash_count)
  # Step 1: How many times do we try to turn on a bit?
  #
  # Each item we add flips `hash_count` bits. After adding `item_count`
  # items, we've made this many total attempts to flip bits:
  #
  #   total_flips = hash_count * item_count
  #
  # Step 2: What's the chance a specific bit is still `off`?
  #
  # Each flip picks one of `bit_count` positions. The chance that a
  # single flip MISSES a specific bit is:
  #
  #   miss_one = 1 - (1.0 / bit_count)
  #
  # After `total_flips` independent misses, the chance that specific
  # bit has never been touched is:
  #
  #   still_off = miss_one ** total_flips
  #
  # For large `bit_count` values that simplifies to an exponential decay.
  # Exponential decay means the value shrinks by the same proportion at
  # each step, like how a half-life works: each round of flips has the
  # same chance of missing our bit, and those chances multiply together.
  #
  # Ruby spells this as `Math.exp(x)` which computes e (~2.718) raised
  # to `x`. The approximation gets more accurate as `bit_count` grows.
  # More on exponential decay: https://en.wikipedia.org/wiki/Exponential_decay
  #
  #   still_off ≈ Math.exp(-hash_count * item_count / bit_count)
  #
  # Step 3: What fraction of bits are `on`?
  #
  #   fraction_on = 1 - still_off
  #
  # Step 4: What's the false positive rate?
  #
  # An item we never added gets `hash_count` random positions checked.
  # For a false positive, ALL of them need to be `on`. Each one is `on`
  # with probability `fraction_on`, so:
  #
  #   false_positive_rate ≈ fraction_on ** hash_count

  still_off = Math.exp(-hash_count.to_f * item_count / bit_count)
  (1 - still_off)**hash_count
end
# end: false_positive_rate

# segment: optimal_hashes
def optimal_hashes(bits_per_item)
  (bits_per_item * Math.log(2)).round
end
# end: optimal_hashes

# segment: sweep_hash_count
def sweep_hash_count
  item_count = 50_000
  bits_per_item = 10
  bit_count = bits_per_item * item_count
  predicted = optimal_hashes(bits_per_item)

  lines = []
  lines << "bits/item = #{bits_per_item}, items = #{item_count}"
  lines << "predicted best hash count = #{bits_per_item} * ln(2) = #{"%.2f" % (bits_per_item * Math.log(2))} -> #{predicted}"
  lines << ""
  lines << " hashes  measured FP"

  (1..12).each do |hash_count|
    filter = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)
    item_count.times { |index| filter.add("item-#{index}") }

    false_positives = 0
    test_count = 50_000
    test_count.times { |index| false_positives += 1 if filter.include?("absent-#{index}") }
    rate = false_positives.to_f / test_count * 100

    marker = hash_count == predicted ? "  <- predicted optimum" : ""
    lines << format("   %2d     %6.3f%%%s", hash_count, rate, marker)
  end

  lines.join("\n")
end
# end: sweep_hash_count

# segment: sizing_table
def sizing_table
  item_count = 50_000
  targets = [0.10, 0.01, 0.001]
  lines = []

  targets.each do |target|
    bits_per_item = -Math.log(target) / (Math.log(2)**2)
    hash_count = optimal_hashes(bits_per_item)
    bit_count = (bits_per_item * item_count).ceil

    filter = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)
    item_count.times { |index| filter.add("item-#{index}") }

    false_positives = 0
    test_count = 50_000
    test_count.times { |index| false_positives += 1 if filter.include?("absent-#{index}") }
    measured = false_positives.to_f / test_count * 100

    lines << format("target %5.1f%%  -> %5.2f bits/item, %d hashes, measured %6.3f%%",
      target * 100, bits_per_item, hash_count, measured)
  end

  lines.join("\n")
end
# end: sizing_table

# segment: memory_comparison
def memory_comparison
  item_count = 1_000_000
  avg_url_bytes = 80
  bits_per_item = 9.59
  bloom_bytes = (bits_per_item * item_count / 8.0).ceil

  set_mb = (avg_url_bytes * item_count) / 1_000_000.0
  bloom_mb = bloom_bytes / 1_000_000.0
  ratio = (set_mb / bloom_mb).round

  lines = []
  lines << "average URL string size: #{avg_url_bytes} bytes"
  lines << format("Set of %s URLs:   ~%.1f MB (strings alone, before Set overhead)", "1,000,000", set_mb)
  lines << format("Bloom filter (1%%):       ~%.2f MB (%.2f bits/item)", bloom_mb, bits_per_item)
  lines << "ratio: Set is ~#{ratio}x larger"
  lines.join("\n")
end
# end: memory_comparison

# segment: accuracy_test
def accuracy_test
  item_count = 100_000
  bits_per_item = 9.59
  bit_count = (bits_per_item * item_count).ceil
  hash_count = 7

  filter = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)
  item_count.times { |index| filter.add("url-#{index}") }

  # Check all members are present
  false_negatives = 0
  item_count.times { |index| false_negatives += 1 unless filter.include?("url-#{index}") }

  # Check false positive rate on non-members
  test_count = 100_000
  false_positives = 0
  test_count.times { |index| false_positives += 1 if filter.include?("absent-#{index}") }
  measured = false_positives.to_f / test_count * 100

  lines = []
  lines << "false negatives: #{false_negatives}"
  lines << format("measured FP: %.2f%%   predicted: 1.0%%", measured)
  lines.join("\n")
end
# end: accuracy_test

# segment: merge_operation
def merge_operation(east, west)
  east.bitmap.zip(west.bitmap).map { |left, right| left || right }
end
# end: merge_operation

# segment: merge_demo
def merge_demo
  bit_count = 10_000
  hash_count = 7

  east = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)
  west = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)

  100.times { |index| east.add("east-user-#{index}") }
  100.times { |index| west.add("west-user-#{index}") }

  both = east.merge(west)

  lines = []
  lines << "both.include?('east-user-42')  -> #{both.include?("east-user-42")}"
  lines << "both.include?('west-user-99')  -> #{both.include?("west-user-99")}"
  lines << "both.include?('nobody-here')   -> #{both.include?("nobody-here")}"

  east_all = (0...100).all? { |index| both.include?("east-user-#{index}") }
  west_all = (0...100).all? { |index| both.include?("west-user-#{index}") }
  lines << "all east members present in union? #{east_all}"
  lines << "all west members present in union? #{west_all}"
  lines.join("\n")
end
# end: merge_demo

# segment: deletion_demo
def deletion_demo
  filter = BloomFilter.new(bit_count: 64, hash_count: 3)
  filter.add("alice")
  filter.add("bob")

  alice_pos = filter.positions("alice").sort
  bob_pos = filter.positions("bob").sort
  shared = alice_pos & bob_pos

  lines = []
  lines << "alice sits at #{alice_pos}"
  lines << "bob sits at #{bob_pos}"
  lines << "they share position #{shared.first}"
  lines << ""
  lines << "Before deleting alice: include?(bob) -> #{filter.include?("bob")}"

  # Simulate deletion by turning off alice's bits
  filter.positions("alice").each { |position| filter.bitmap[position] = false }
  lines << "After  deleting alice: include?(bob) -> #{filter.include?("bob")}  (bob was never removed)"
  lines.join("\n")
end
# end: deletion_demo

# segment: packed_bloom_filter
class PackedBloomFilter
  attr_reader :bit_count, :hash_count

  def initialize(bit_count:, hash_count:)
    @bit_count = bit_count
    @hash_count = hash_count
    @words = Array.new((bit_count + 63) / 64, 0)
  end

  def positions(item)
    hash = Hashing.to_64_bits(item)
    high = hash >> 32                 # top 32 bits
    low  = (hash & 0xFFFFFFFF) | 1    # bottom 32 bits, forced odd to spread well
    Array.new(@hash_count) { |nth| (high + nth * low) % @bit_count }
  end

  def add(item)
    positions(item).each do |position|
      @words[position >> 6] |= (1 << (position & 63))
    end
    self
  end

  def include?(item)
    positions(item).all? do |position|
      @words[position >> 6][position & 63] == 1
    end
  end
end
# end: packed_bloom_filter

# segment: packed_accuracy_test
def packed_accuracy_test
  item_count = 100_000
  bits_per_item = 9.59
  bit_count = (bits_per_item * item_count).ceil
  hash_count = 7

  filter = PackedBloomFilter.new(bit_count: bit_count, hash_count: hash_count)
  item_count.times { |index| filter.add("url-#{index}") }

  false_negatives = 0
  item_count.times { |index| false_negatives += 1 unless filter.include?("url-#{index}") }

  test_count = 100_000
  false_positives = 0
  test_count.times { |index| false_positives += 1 if filter.include?("absent-#{index}") }
  measured = false_positives.to_f / test_count * 100

  lines = []
  lines << "PackedBloomFilter (double hashing), same settings:"
  lines << "  false negatives: #{false_negatives}"
  lines << format("  measured FP: %.2f%%   predicted: 1.0%%", measured)
  lines.join("\n")
end
# end: packed_accuracy_test

# segment: benchmark
def benchmark_filters
  require "benchmark/ips"

  item_count = 100_000
  bits_per_item = 9.59
  bit_count = (bits_per_item * item_count).ceil
  hash_count = 7

  readable = BloomFilter.new(bit_count: bit_count, hash_count: hash_count)
  packed = PackedBloomFilter.new(bit_count: bit_count, hash_count: hash_count)

  items = Array.new(item_count) { |index| "item-#{index}" }
  items.each { |item| readable.add(item); packed.add(item) }

  queries = Array.new(item_count) { |index| "query-#{index}" }

  Benchmark.ips do |bench|
    bench.report("BloomFilter#add") { readable.add(queries.sample) }
    bench.report("PackedBloomFilter#add") { packed.add(queries.sample) }
    bench.compare!
  end

  Benchmark.ips do |bench|
    bench.report("BloomFilter#include?") { readable.include?(queries.sample) }
    bench.report("PackedBloomFilter#include?") { packed.include?(queries.sample) }
    bench.compare!
  end
end
# end: benchmark
