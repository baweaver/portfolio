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


# segment: linear_counting_formula
def linear_counting_estimate(total_bits, zeros)
  # With total_bits bits and zeros of them still clear:
  -total_bits * Math.log(zeros.to_f / total_bits)
  # => approximate distinct count
end
# end: linear_counting_formula

# segment: linear_counting
class LinearCounting
  def initialize(bits: 1 << 20)
    @bit_count = bits
    # Pack bits into 64-bit words.
    # 1,048,576 bits / 64 = 16,384 words.
    @words = Array.new((bits + 63) / 64, 0)
  end

  def add(item)
    # Hash the item and pick one bit position out of @bit_count.
    position = Hashing.to_64_bits(item) % @bit_count

    # Set that bit using the same pattern from the primer:
    #   position >> 6   = which word   (position / 64)
    #   position & 63   = which slot   (position % 64)
    #   1 << slot       = mask with only that bit set
    #   |=              = turn it on, leave others alone
    @words[position >> 6] |= (1 << (position & 63))
  end

  def estimate
    # Count how many bits are set across all words.
    set_bits = @words.sum { |word| word.to_s(2).count("1") }
    zero_bits = @bit_count - set_bits

    # If every bit is set, the formula breaks (log of zero).
    return @bit_count if zero_bits.zero?

    # The estimate: -m * ln(zeros / m)
    (-@bit_count * Math.log(zero_bits.to_f / @bit_count)).round
  end
end
# end: linear_counting

# segment: leading_zeros
def leading_zeros(hash_value, total_bits:)
  # How many zeros before the first 1?
  #
  # bit_length tells us where the highest 1-bit is (counting from 1, not 0).
  # Everything above that is zeros.
  #
  # Example with total_bits = 8:
  #   0b00000101  bit_length = 3  (highest 1 is in position 3)
  #   leading zeros = 8 - 3 = 5
  #
  #   0b10000000  bit_length = 8
  #   leading zeros = 8 - 8 = 0
  #
  #   0b00000000  bit_length = 0  (no bits set at all)
  #   leading zeros = 8 - 0 = 8   (all zeros, maximum rarity)

  total_bits - hash_value.bit_length
end
# end: leading_zeros

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
  # a single measurement that got "lucky" (saw a long run of zeros)
  # can't drag the entire estimate up the way arithmetic would.

  values.size.to_f / values.sum { |value| 1.0 / value }
end
# end: harmonic_mean

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

    # Split the 64-bit hash into two parts using the right shift
    # and mask from the primer:
    #
    # Example with precision=14 and a 64-bit hash:
    #   [  14 bits  |          50 bits              ]
    #   [ register  |  remainder (count zeros here) ]
    #
    # Top 14 bits: which register (0..16383)
    #   hash >> (64 - 14) = hash >> 50
    #   This drops the bottom 50 bits, leaving the top 14.
    register_index = hash >> (HASH_BITS - @precision)

    # Bottom 50 bits: the remainder we count leading zeros in.
    #   (1 << 50) - 1 builds a mask of 50 ones.
    #   hash & that mask zeros the top 14 bits, keeps the bottom 50.
    remainder = hash & ((1 << (HASH_BITS - @precision)) - 1)

    # How many leading zeros in the remainder?
    #   Same idea as the leading_zeros helper from earlier, plus one.
    #   rank = leading zeros + 1 = position of the first 1-bit.
    #   (The +1 is a convention from the paper; it avoids rank=0 meaning
    #   "saw something" vs "never saw anything.")
    #
    #   bit_length tells us where the highest 1-bit is (counting from 1).
    #   A 50-bit remainder with bit_length 47 has 3 leading zeros, rank 4.
    #   All-zero remainder: bit_length 0, rank 51 (maximum rarity).
    rank = (HASH_BITS - @precision) - remainder.bit_length + 1

    # Keep the largest rank this register has ever seen.
    @registers[register_index] = [@registers[register_index], rank].max
  end
end
# end: hyperloglog_add

# segment: hyperloglog_estimate
class HyperLogLog
  def estimate
    # Harmonic mean of 2^(-rank) across all registers.
    # Each register contributes 2^(-rank):
    #   rank 0 (never seen anything) contributes 2^0 = 1
    #   rank 5 (saw 5 leading zeros)  contributes 2^-5 = 0.03125
    #   Higher ranks contribute less, pulling the harmonic down less.
    harmonic = @registers.sum { |rank| 2.0**-rank }

    # Raw estimate: alpha * m^2 / harmonic_sum
    #   alpha is a bias correction constant from the paper.
    #   m^2 / harmonic is the harmonic mean inverted into a count.
    raw = alpha * @register_count * @register_count / harmonic
    empty = @registers.count(&:zero?)

    # Small-range correction:
    #   When many registers are still 0 (small cardinality), the raw
    #   HLL estimate is noisy. Fall back to Linear Counting over the
    #   empty registers, same formula as LinearCounting above.
    if raw <= 2.5 * @register_count && empty.positive?
      (@register_count * Math.log(@register_count.to_f / empty)).round
    else
      raw.round
    end
  end

  private

  def alpha = 0.7213 / (1.0 + (1.079 / @register_count))
end
# end: hyperloglog_estimate

# segment: hyperloglog_merge
class HyperLogLog
  def merge(other)
    raise ArgumentError, "precision mismatch" unless @precision == other.precision

    # Merge = elementwise maximum of registers.
    #   Each register holds "longest leading-zero run seen."
    #   The longest run across the union is the larger of the two.
    merged = HyperLogLog.new(precision: @precision)
    new_registers = @registers.zip(other.registers).map { |mine, theirs| [mine, theirs].max }
    merged.send(:replace_registers, new_registers)
    merged
  end

  attr_reader :precision, :registers

  private

  def replace_registers(new_registers)
    @registers = new_registers
  end
end
# end: hyperloglog_merge
