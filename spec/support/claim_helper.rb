# frozen_string_literal: true

# Helper for verifying claims made in article prose.
# Usage:
#   claim("the sum is 5088") { imperative_sum }.equals(5088)
#   claim("reducer is faster") { bench_reduce }.is_less_than { bench_emit }

module ClaimHelper
  class Claim
    def initialize(description, context, &block)
      @description = description
      @context = context
      @value = context.instance_eval(&block)
    end

    def equals(expected)
      @context.expect(@value).to @context.eq(expected),
        "Claim failed: #{@description}\n  expected: #{expected.inspect}\n       got: #{@value.inspect}"
    end

    def is_within(delta, of:)
      @context.expect(@value).to @context.be_within(delta).of(of),
        "Claim failed: #{@description}\n  expected: within #{delta} of #{of}\n       got: #{@value.inspect}"
    end

    def is_less_than(&other_block)
      other = @context.instance_eval(&other_block)
      @context.expect(@value).to @context.be < other,
        "Claim failed: #{@description}\n  expected: < #{other.inspect}\n       got: #{@value.inspect}"
    end

    def is_greater_than(n)
      @context.expect(@value).to @context.be > n,
        "Claim failed: #{@description}\n  expected: > #{n.inspect}\n       got: #{@value.inspect}"
    end

    def is_at_most(n)
      @context.expect(@value).to @context.be <= n,
        "Claim failed: #{@description}\n  expected: <= #{n.inspect}\n       got: #{@value.inspect}"
    end
  end

  def claim(description, &block)
    Claim.new(description, self, &block)
  end

  def count_allocations
    before = GC.stat[:total_allocated_objects]
    yield
    GC.stat[:total_allocated_objects] - before
  end
end

RSpec.configure do |config|
  config.include ClaimHelper
end
