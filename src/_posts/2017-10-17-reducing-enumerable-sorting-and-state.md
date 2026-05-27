---
layout: "post"
title: "Reducing Enumerable — Sorting and State"
series: "reducing-enumerable"
date: "2017-10-17"
categories: []
tags: []
description: ""
---

Some Enumerable functions are going to require we keep a bit more context as we’re reducing. Remember that hint from the first post about reducing with Hashes or Objects? We’re going to be putting that to use.

## **Sorting**

This is where the fun comes in. By default, Ruby uses a variant of the Quick Sort algorithm so we’ll try and stay true to that in spirit with our comparator functions.
> It should be noted that the difference between sortand sort_by is significant at around 10x for trivial keys as sort_by will generate a set of tuples to have a unary function sort instead of a comparator: [https://ruby-doc.org/core-2.4.2/Enumerable.html#method-i-sort_by](https://ruby-doc.org/core-2.4.2/Enumerable.html#method-i-sort_by)

To start out with, let’s get a simple quick sort going:

    def sort(list)
      return [] if list.empty?
      
      head, *tail = list
      
      left  = select(tail) { |i| i < head }
      right = select(tail) { |i| i >= head }

      [*sort(left), head, *sort(right)]
    end

    sort([5,4,2,3,1])
    # => [1, 2, 3, 4, 5]
> Note: * in Ruby is also known as the splat operator in the context of lists. Check out this article if you want to learn more about them:
[**Using splats to build up and tear apart arrays in Ruby**
*One of the things that I love about Ruby is the depth of its features. You may use an operator, but do a little digging…*blog.honeybadger.io](http://blog.honeybadger.io/ruby-splat-array-manipulation-destructuring/)

The idea of a quick sort is to pick a pivot element and partition the elements into those less than and those greater than or equal to the head element. After we get that, we continue to break the lists down until eventually we get a sorted list back.

That said, this implementation doesn’t feel quite right. For one thing, we’re not getting to use a function as a comparator, and for another this is just using straight recursion. How can we start to break this down a bit?

The first part is in the word I used earlier: partition.

    def sort(list, &fn)
      fn ||= -> (a, b) { a <=> b }

      return [] if list.empty?
      
      head = list[0]

      left, center, right = list.reduce(
        Array.new(3) { [] }
      ) { |state, i|
        state[fn[i, head] + 1] << i
        state
      }

      [*sort(left, &fn), *center, *sort(right, &fn)]
    end

    sort([5,4,2,3,1])
    # => [1, 2, 3, 4, 5]
> Why the fn ||= -> {} ? Ruby isn’t too fond of default block params, so we have to cheat a bit.

Now there are a few concepts in there you may not be familiar with. The first is the Spaceship operator <=> which works as a comparator:
[**Ruby Spaceship Operator**
*The Ruby Spaceship Operator can be used to sort elements of an array and also when sorting custom classes. This…*jakeyesbeck.com](http://jakeyesbeck.com/2016/02/28/ruby-spaceship-operator/)

The second, we have a deconstruction of left, center, right which ties into the spaceship operator to give us values that are lesser than, equal to, and greater than the head element. The head element works as a pivot with our comparator function. We’re adding 1 to it because <=> starts with -1, so it’d be nice to 0 it out for a clean destructure.

Next we have Array’s block creation. This is just telling us we want a new Array with 3 elements that happen to be new Arrays.

    Array.new(3) { [] }

Past this we’re just partitioning things out to 0, 1, and 2 for that left, center, and right we mentioned above. After we have the partitions, we sort the left and right and flatten it all into a single array using splat.

**Unary Sort**

As mentioned above, the single arity sort_by function is slow. What if we cheat a bit though? As Enumerable can be implemented with reduce , would it not stand to reason that we could implement sort_by in terms of sort?

    def sort_by(list, &fn)
      sort(list) { |a, b| fn[a] <=> fn[b] }
    end

    sort_by(%w[foo foobar baz bazzy]) { |w| w.length }
    # => ["foo", "baz", "bazzy", "foobar"]

    sort_by(%w[foo foobar baz bazzy]) { |w| -w.length }
    # => ["foobar", "bazzy", "foo", "baz"]

Turns out we can!

## Min and Max

Let’s take a look at a few methods that would implement sorting to find a result. As that’s a fair amount of code, we’ll be using sort and sort_by as we defined them above.

**Min and first**

Min has a few variants on it like a count and a comparator:

    def min(list, n = 1, &fn)
      fn ||= -> (a, b) { a <=> b }
      
      sorted = sort(list, &fn)
      n > 1 ? sorted.first(n) : sorted.first
    end

    min([5,6,1, -10])
    # => -10

    min([5,6,1, -10], 2)
    # => [-10, 1]

In the first case we only want back one value. In the second, an array of them. Granted, first is cheating a bit, so here you go:

    def first(list, n = nil)
      return list[0] unless n

      list.reduce([]) { |a,i|
        break a if a.size == n
        a.push(i)
      }
    end

    first([1,2,3])
    # => 1

    first([1,2,3], 2)
    # => [1, 2]

    first([1,2,3], 4)
    # => [1, 2, 3]

Min_by is basically the same concept as sort_by :

    def min_by(list, n = 1, &fn)
      min(list, n) { |a, b| fn[a] <=> fn[b] }
    end

    min_by([5,6,1, -10]) { |a| a**2 }
    # => 1

    min_by([5,6,1, -10], 2) { |a| a**2 }
    # => [1, 5]

**Max and last**

Max is about the same, except we’re doing it in reverse:

    def max(list, n = 1, &fn)
      fn ||= -> (a, b) { a <=> b }
      
      sorted = sort(list, &fn)
      n > 1 ? sorted.last(n) : sorted.last
    end

    max([5,6,1, -10])
    # => 6

    max([5,6,1, -10], 2)
    # => [5, 6]

Last though, that’s a bit trickier to get. Nice thing about Ruby though, it’s not fully FP so we can still cheat a bit:

    def last(list, n = nil)
      return list[-1] unless n

      lasts = []

      list.reduce(0) { |i, _|
        break lasts if lasts.size == n
        lasts.push(list[-1 - i])
        i + 1
      }

      lasts
    end

Same deal with max_by :

    def max_by(list, n = 1, &fn)
      max(list, n) { |a, b| fn[a] <=> fn[b] }
    end

    max_by([5,6,1, -10]) { |a| a**2 }
    # => -10

    max_by([5,6,1, -10], 2) { |a| a**2 }
    # => [6, -10]

## MinMax and State

Some functions though we’re not going to have such an easy time with. We’re going to need to pass some context along with them if we want to capture values.

We could use the trick from above with the external array, but that’s dirty.

To start with, let’s give this a try with hashes:

    def minmax(list, &fn)
      fn ||= -> (a, b) { a <=> b }

      head, *tail = list
      result = tail.reduce({
        min: head,
        max: head
      }) { |state, i|
        min = fn[state[:min], i] > 0 ? i : state[:min]
        max = fn[state[:max], i] < 0 ? i : state[:max]

        {min: min, max: max}
      }

      [result[:min], result[:max]]
    end

    minmax([5,6,1, -10])
    # => [-10, 6]

Now remember we said earlier that reduce doesn’t particularly care what it reduces onto? What if we reduce onto objects?

    MinMax = Struct.new(:min, :max)

    def minmax(list, &fn)
      fn ||= -> (a, b) { a <=> b }

      head, *tail = list
      result = tail.reduce(MinMax.new(head, head)) { |state, i|
        min = fn[state.min, i] > 0 ? i : state.min
        max = fn[state.max, i] < 0 ? i : state.max

        MinMax.new(min, max)
      }

      [result.min, result.max]
    end

    minmax([5,6,1, -10])
    # => [-10, 6]

    def minmax_by(list, &fn)
      minmax(list) { |a, b| fn[a] <=> fn[b] }
    end

    minmax_by([5,6,1, -10]) { |a| a**2 }
    # => [1, -10]

Granted, we could have used an array in these cases, but imagine the possibilities this unlocks. Also note the fact that I started using the word state instead of accumulator. There’s a reason, though we’re not *quite* ready to get into it yet.

## What If?

Wrapping this one up, consider the point from the first post: what if we could define what we meant by nothing or something? How would that effect concepts like map_select and other combinations or series of actions?
