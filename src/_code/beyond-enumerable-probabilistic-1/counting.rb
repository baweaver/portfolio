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

# segment: linear_counting_string
class LinearCountingString
  def initialize(bits: 1 << 20)
    # Picture a row of a million light switches, all starting OFF.
    @bit_count = bits
    @bitmap = Array.new(bits, false)
  end

  def add(item)
    # Hash the item to get a number.
    # Use that number to pick one switch and flip it ON.
    # If two different items pick the same switch, oh well,
    # they share it. We're counting approximately, not exactly.
    position = Hashing.to_64_bits(item) % @bit_count
    @bitmap[position] = true
  end

  def estimate
    # How many switches are still OFF?
    zeros = @bitmap.count(false)

    # If every switch is ON, we've run out of room to count.
    return @bit_count if zeros.zero?

    # Fewer OFF switches means more distinct items passed through.
    # This formula turns that ratio into an approximate count.
    (-@bit_count * Math.log(zeros.to_f / @bit_count)).round
  end
end
# end: linear_counting_string

# segment: linear_counting_formula
def linear_counting_estimate(total_bits, zeros)
  # We have a bitmap with `total_bits` switches.
  # `zeros` of them are still OFF (never been hit).
  #
  # The ratio zeros/total_bits tells us "what fraction is still empty?"
  #   - If 90% are still OFF, not much has come through yet.
  #   - If only 1% are still OFF, a LOT of distinct items have passed through.
  #
  # Math.log (natural logarithm) converts that fraction into a rate.
  # Think of it as answering: "how many times did we have to throw darts
  # at this board to leave only this many empty spots?"
  #
  # The result of Math.log(zeros / total_bits) is always negative
  # (because zeros/total_bits is less than 1, and log of a fraction is negative).
  # Multiplying by -total_bits flips it positive and scales it up
  # to give us the estimated count.
  #
  # .to_f ensures we get decimal division, not integer division.
  # Without it, 900000 / 1000000 would give 0 instead of 0.9.

  -total_bits * Math.log(zeros.to_f / total_bits)
  # => approximate distinct count
end
# end: linear_counting_formula

# segment: leading_zeros_string
def leading_zeros_string_examples
  # Take a hash value and look at it as a string of zeros and ones.
  # Count how many zeros come before the first one.
  # That count is our "coin flip run length."

  bits_a = "10110100"  # starts with 1, so zero leading zeros
  bits_a.index("1")    # => 0

  bits_b = "00010110"  # three zeros before the first 1
  bits_b.index("1")    # => 3

  bits_c = "00000001"  # seven zeros before the first 1 (very rare!)
  bits_c.index("1")    # => 7
end
# end: leading_zeros_string

# segment: harmonic_mean
def harmonic_mean(values)
  # Arithmetic mean: sum all values, divide by count.
  #   [1, 1, 1, 100] => (1+1+1+100) / 4 = 25.75
  #   One outlier dominates.
  #
  # Harmonic mean: count divided by the sum of reciprocals.
  #   A reciprocal is 1 divided by a number (the "flip" of it).
  #   [1, 1, 1, 100] => 4 / (1/1 + 1/1 + 1/1 + 1/100)
  #                    = 4 / (1 + 1 + 1 + 0.01)
  #                    = 4 / 3.01
  #                    ≈ 1.33
  #   The outlier barely registers.
  #
  # This is why HyperLogLog uses harmonic mean:
  #
  # A single measurement that got "lucky" (saw a long run of zeros)
  # can't drag the entire estimate up the way arithmetic would.

  values.size.to_f / values.sum { |value| 1.0 / value }
end
# end: harmonic_mean

# segment: hyperloglog_string_add
class HyperLogLogString
  HASH_BITS = 64

  def initialize(precision: 14)
    @precision = precision

    # How many buckets? 2^precision of them.
    # More buckets = more accurate = more memory.
    # 2^14 = 16,384 buckets. That's what Redis uses.
    @register_count = 2**precision

    # Each bucket remembers one number: the longest run of
    # leading zeros it has ever seen. Starts at 0 ("nothing yet").
    @registers = Array.new(@register_count, 0)
  end

  def add(item)
    # Step 1: Turn the hash value into a string of 64 zeros and ones.
    # "%064b" means: format as binary, padded to 64 characters.
    # Example result: "0010110100001011..." (always 64 chars)
    bits = format("%064b", Hashing.to_64_bits(item))

    # Step 2: The first few characters decide which bucket.
    # .to_i(2) reads the string as a base-2 (binary) number.
    # With precision 14, this gives a number from 0 to 16,383.
    # Think of it as: "which table does this person sit at?"
    index = bits[0, @precision].to_i(2)

    # Step 3: Everything after that is what we measure.
    rest = bits[@precision..]

    # Step 4: Count how many zeros appear before the first one.
    # This is our "coin flip run." More zeros = rarer = more distinct items.
    # .index("1") finds the position of the first "1" character.
    # If there's no "1" at all, every character is a zero (maximum rarity).
    zeros = rest.index("1") || rest.length

    # Step 5: Add 1 so that "no leading zeros" is 1, not 0.
    # That keeps 0 meaning "bucket has never been used."
    rank = zeros + 1

    # Step 6: Only keep it if it's bigger than what we had.
    # We want the rarest thing this bucket has ever seen.
    @registers[index] = [@registers[index], rank].max
  end

  def estimate
    # Combine all the buckets using harmonic mean.
    # This averages them in a way that ignores lucky outliers.
    harmonic = @registers.sum { |rank| 2.0**-rank }
    raw = alpha * @register_count * @register_count / harmonic
    empty = @registers.count(&:zero?)

    # If most buckets are still empty, use a simpler formula
    # that's more accurate at small counts.
    if raw <= 2.5 * @register_count && empty.positive?
      (@register_count * Math.log(@register_count.to_f / empty)).round
    else
      raw.round
    end
  end

  def merge(other)
    # To combine two counters: take the bigger number from each bucket.
    # If counter A saw a run of 5 in bucket 7, and counter B saw 9,
    # then across both of them, someone saw 9. Keep 9.
    raise ArgumentError, "precision mismatch" unless @precision == other.precision
    merged = HyperLogLogString.new(precision: @precision)
    new_regs = @registers.zip(other.registers).map { |a, b| [a, b].max }
    merged.instance_variable_set(:@registers, new_regs)
    merged
  end

  attr_reader :precision, :registers

  private

  # Without correction, the estimate runs about 40% too high.
  # This happens because some items inevitably land in the same bucket,
  # inflating the harmonic mean. Alpha scales the result back down.
  # The specific numbers (0.7213, 1.079) come from the paper's math
  # and work for any bucket count above 128.
  def alpha = 0.7213 / (1.0 + (1.079 / @register_count))
end
# end: hyperloglog_string_add

# segment: hyperloglog_trace
def hyperloglog_trace
  # Small example: 16 buckets so we can see everything.
  hll = HyperLogLogString.new(precision: 4)
  names = %w[alice bob carol dave eve frank grace heidi ivan judy]

  names.each do |name|
    hll.add(name)

    # Show what happened for this name:
    # - Which bucket did it land in?
    # - How many leading zeros did it have (rank)?
    # - What do all 16 buckets look like now?
    bits = format("%064b", Hashing.to_64_bits(name))
    index = bits[0, 4].to_i(2)
    rest = bits[4..]
    zeros = rest.index("1") || rest.length
    rank = zeros + 1
    puts format("add %-6s -> bucket %2d, rank %2d   registers: %s",
      name, index, rank, hll.registers.inspect)
  end

  puts "\nestimate after #{names.size} distinct: #{hll.estimate}"
end
# Output:
#   add alice  -> bucket  2, rank  1   registers: [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
#   add bob    -> bucket  8, rank  4   registers: [0, 0, 1, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0]
#   add carol  -> bucket  4, rank  1   registers: [0, 0, 1, 0, 1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0]
#   add dave   -> bucket  6, rank  4   registers: [0, 0, 1, 0, 1, 0, 4, 0, 4, 0, 0, 0, 0, 0, 0, 0]
#   add eve    -> bucket  8, rank  2   registers: [0, 0, 1, 0, 1, 0, 4, 0, 4, 0, 0, 0, 0, 0, 0, 0]
#   add frank  -> bucket  7, rank  2   registers: [0, 0, 1, 0, 1, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0]
#   add grace  -> bucket 14, rank  8   registers: [0, 0, 1, 0, 1, 0, 4, 2, 4, 0, 0, 0, 0, 0, 8, 0]
#   add heidi  -> bucket  0, rank  2   registers: [2, 0, 1, 0, 1, 0, 4, 2, 4, 0, 0, 0, 0, 0, 8, 0]
#   add ivan   -> bucket 12, rank  1   registers: [2, 0, 1, 0, 1, 0, 4, 2, 4, 0, 0, 0, 1, 0, 8, 0]
#   add judy   -> bucket  7, rank  4   registers: [2, 0, 1, 0, 1, 0, 4, 4, 4, 0, 0, 0, 1, 0, 8, 0]
#
#   estimate after 10 distinct: 11
# end: hyperloglog_trace

# segment: hyperloglog_merge
def hyperloglog_merge_example
  a = HyperLogLogString.new(precision: 14)
  b = HyperLogLogString.new(precision: 14)

  5_000.times { |i| a.add("server_a_user_#{i}") }
  5_000.times { |i| b.add("server_b_user_#{i}") }

  merged = a.merge(b)
  merged.estimate
  # => ~10000 (combined distinct count from both servers)
end
# end: hyperloglog_merge

# segment: leading_zeros
def leading_zeros(hash_value, total_bits:)
  # The bit-packed equivalent of rest.index("1") from the string version.
  # .bit_length tells us where the highest 1 is (counting from 1).
  # Subtract from total to get how many zeros sit above it.
  #
  # Example: value 5 is 0b101, bit_length is 3.
  #   In an 8-bit space: 8 - 3 = 5 leading zeros.

  total_bits - hash_value.bit_length
end
# end: leading_zeros

# --- Bit-packed versions (the fast path) ---

# segment: bit_left_shift
def bit_left_shift_example
  # INPUT:      0  0  0  0  0  0  0  1    (1)
  # OPERATION:  << 3 (slide the 1 up three positions)
  #
  #   BEFORE:   0  0  0  0  0  0  0  1    (1)
  #   AFTER:    0  0  0  0  1  0  0  0    (8)
  #
  # Shifting left by n multiplies by 2**n.
  # 1 << 3 = 1 * 2 * 2 * 2 = 8

  1 << 3
  # => 8
end
# end: bit_left_shift

# segment: bit_right_shift
def bit_right_shift_example
  # >> 5 means: drop the bottom 5 bits, keep the top 3.
  #
  #   bit:      7  6  5  4  3  2  1  0
  #   BEFORE:   1  0  1  1  0  1  1  0  (182)
  #             ^  ^  ^  .  .  .  .  .
  #             keep     drop
  #
  #   AFTER:    0  0  0  0  0  1  0  1  (5)
  #

  0b10110110 >> 5
  # => 5
end
# end: bit_right_shift

# segment: bit_mask
def bit_mask_example
  # & mask means: keep ONLY bits where the mask has a 1.
  #
  # Building the mask: (1 << 3) - 1
  #   1 << 3 = 0b1000 (8)
  #   8 - 1  = 0b0111 (7)  -- subtracting 1 flips all zeros below the 1
  #
  #   bit:      7  6  5  4  3  2  1  0
  #   INPUT:    1  0  1  1  0  1  1  0  (182)
  #   MASK:     0  0  0  0  0  1  1  1  (7)
  #   (& keeps 1 ONLY where BOTH are 1)
  #   ========================================
  #   RESULT:   0  0  0  0  0  1  1  0  (6)

  mask = (1 << 3) - 1
  0b10110110 & mask
  # => 6
end
# end: bit_mask

# segment: bit_set_single
def bit_set_single_example
  # Turn on bit 3 of a number.
  #
  # 1 << 3 builds a number with ONLY bit 3 set:
  #   0  0  0  0  1  0  0  0    (8)
  #
  # |= (OR-assign) turns on that bit without touching others:
  #   BEFORE:   0  0  1  0  0  0  0  0    (32)
  #   OR:       0  0  0  0  1  0  0  0    (8)
  #   (| keeps 1 wherever EITHER has 1)
  #   -----------------------------------------
  #   AFTER:    0  0  1  0  1  0  0  0    (40)

  number = 0b00100000  # 32
  number |= (1 << 3)
  number
  # => 40
end
# end: bit_set_single

# segment: bit_set
def bit_set_example
  words = [0, 0]
  position = 70

  # Turn bit 70 ON in a word array.
  #
  # Which word?  70 >> 6 = 1   (70 / 64 = 1, its in words[1])
  # Which slot?  70 & 63 = 6   (70 % 64 = 6, bit 6 of that word)
  #
  # |= means: turn ON wherever EITHER side has a 1.
  # 1 << 6 builds a number with ONLY bit 6 set (= 64).
  #
  #   bit:      7  6  5  4  3  2  1  0
  #   BEFORE:   0  0  0  0  0  0  0  0  (words[1] = 0)
  #   MASK:     0  1  0  0  0  0  0  0  (1 << 6 = 64)
  #   (|= keeps 1 wherever EITHER is 1)
  #   ========================================
  #   AFTER:    0  1  0  0  0  0  0  0  (words[1] = 64)

  words[position >> 6] |= (1 << (position & 63))
  words
  # => [0, 64]
end
# end: bit_set

# segment: bit_check
def bit_check_example
  words = [0, 64]
  position = 70

  # Is bit 70 set?
  #
  # Same split: word = 70 >> 6 = 1, slot = 70 & 63 = 6
  #
  # Shift right by 6 to move bit 6 into position 0,
  # then & 1 to isolate it.
  #
  #   bit:      7  6  5  4  3  2  1  0
  #   BEFORE:   0  1  0  0  0  0  0  0  (words[1] = 64)
  #   >> 6:     0  0  0  0  0  0  0  1  (bit 6 moved to position 0)
  #   & 1:      0  0  0  0  0  0  0  1
  #   ========================================
  #   RESULT:   0  0  0  0  0  0  0  1  (1 = true, its set)

  ((words[position >> 6] >> (position & 63)) & 1) == 1
  # => true
end
# end: bit_check

# segment: hyperloglog_add
class HyperLogLog
  HASH_BITS = 64

  def initialize(precision: 14)
    @precision = precision
    @register_count = 1 << precision
    @registers = Array.new(@register_count, 0)
  end

  def add(item)
    hash = Hashing.to_64_bits(item)

    # Split the 64-bit hash value into two parts:
    #   [  14 bits  |          50 bits              ]
    #   [ register  |  remainder (count zeros here) ]
    #
    # Top 14 bits: which register (0..16383)
    register_index = hash >> (HASH_BITS - @precision)

    # Bottom 50 bits: the remainder we count leading zeros in.
    remainder = hash & ((1 << (HASH_BITS - @precision)) - 1)

    # rank = leading zeros + 1
    rank = (HASH_BITS - @precision) - remainder.bit_length + 1

    # Keep the largest rank this register has ever seen.
    @registers[register_index] = [@registers[register_index], rank].max
  end

  def estimate
    harmonic = @registers.sum { |rank| 2.0**-rank }
    raw = alpha * @register_count * @register_count / harmonic
    empty = @registers.count(&:zero?)

    if raw <= 2.5 * @register_count && empty.positive?
      (@register_count * Math.log(@register_count.to_f / empty)).round
    else
      raw.round
    end
  end

  def merge(other)
    raise ArgumentError, "precision mismatch" unless @precision == other.precision
    merged = HyperLogLog.new(precision: @precision)
    new_regs = @registers.zip(other.registers).map { |a, b| [a, b].max }
    merged.instance_variable_set(:@registers, new_regs)
    merged
  end

  attr_reader :precision, :registers

  private

  # Same bias correction as the string version (see comments there).
  def alpha = 0.7213 / (1.0 + (1.079 / @register_count))
end
# end: hyperloglog_add

# segment: linear_counting
class LinearCounting
  def initialize(bits: 1 << 20)
    @bit_count = bits
    @words = Array.new((bits + 63) / 64, 0)
  end

  def add(item)
    position = Hashing.to_64_bits(item) % @bit_count
    @words[position >> 6] |= (1 << (position & 63))
  end

  def estimate
    set_bits = @words.sum { |word| word.to_s(2).count("1") }
    zero_bits = @bit_count - set_bits
    return @bit_count if zero_bits.zero?
    (-@bit_count * Math.log(zero_bits.to_f / @bit_count)).round
  end
end
# end: linear_counting
