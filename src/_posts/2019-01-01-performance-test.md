---
layout: "post"
title: "Performance Test"
date: "2019-01-01"
categories: []
tags: []
description: ""
---

Test code:

    def select_mutate_push(list, &fn)
      list.reduce([]) { |a, v| yield(v) ? a.push(v) : a }
    end

    def select_mutate_shovel(list, &fn)
      list.reduce([]) { |a, v| yield(v) ? a.<<(v) : a }
    end

    def select_pure_plus(list, &fn)
      list.reduce([]) { |a, v| yield(v) ? a + [v] : a }
    end

    require 'benchmark/ips'

    numbers = (1..10_000).to_a.shuffle

    Benchmark.ips do |x|
      x.report('Mutation with Push') { select_mutate_push(numbers, &:even?) }
      x.report('Mutation with Shovel') { select_mutate_shovel(numbers, &:even?) }
      x.report('Pure with Plus') { select_pure_plus(numbers, &:even?) }
    end

**Test result**:

    ➜  performance_tests ruby 01_01_19_select_mutation.rb
    Warming up --------------------------------------
      Mutation with Push   113.000  i/100ms
    Mutation with Shovel   123.000  i/100ms
          Pure with Plus     4.000  i/100ms
    Calculating -------------------------------------
      Mutation with Push      1.136k (± 3.1%) i/s -      5.763k in   5.078764s
    Mutation with Shovel      1.233k (± 1.9%) i/s -      6.273k in   5.089585s
          Pure with Plus     50.548  (± 5.9%) i/s -    256.000  in   5.081988s

## Speed Differences

As seen above, the pure solution is several times slower than the mutating ones.

The two factors that contribute to this are that + requires an array on the right-hand, and + itself returns a new array. That means for every value you end up with two arrays being initialized which is a pretty big performance hit.

In Ruby, it’s not a pure functional language. It’s not optimized for this type of thing, and as a result you have a several times difference in speed between the two styles.

That’s why in most examples I tend to use “isolate state mutation”

## Isolate State Mutation

The idea of isolate state mutation is that state is only mutated in an isolated environment.

In the case of these functions, only the accumulator / memo element of reduce is mutated. This array is also exclusive to the specific function, it’s not passed in and it gets created when the function is called.

By scoping mutation to be a private or isolate state we can gain the benefits of immutable code without some of the performance overheads. I’d detailed this more in this post:
[**Functional Programming in Ruby — State**
*Ruby is, by nature, an Object Oriented language. It also takes a lot of hints from Functional languages like Lisp.*medium.com](/writing/2021/08/01/functional-programming-in-ruby-state-13p2/)

So by the strictest definition of immutability we fail to pass muster, but to our users? They can’t tell the difference.

Be careful not to sacrifice too much in terms of speed for minor wins on philosophical points of functional purity.
