---
layout: "post"
title: "Understanding Ruby - Enumerable - Combining"
series: "understanding-ruby"
date: "2021-02-12"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Introduction   Enumerable. Debatably one of, if not the, most powerful features in Ruby. As..."
---

# Introduction

`Enumerable`. Debatably one of, if not the, most powerful features in Ruby. As a majority of your time in programming is dealing with collections of items it's no surprise how frequently you'll see it used.

## Difficulty

**Foundational**

Some knowledge required of functions in Ruby. This post focuses on foundational and fundamental knowledge for Ruby programmers.

Prerequisite Reading:

* [Understanding Ruby - Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/)
* [Understanding Ruby - to_proc and Function Interfaces](/writing/2021/02/08/understanding-ruby-toproc-and-function-interfaces-2o1d/)
* [Understanding Ruby - Triple Equals](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/)
* [Understanding Ruby - Comparable](/writing/2021/02/09/understanding-ruby-comparable-34ki/)

# Enumerable

`Enumerable` is an interface module that contains several methods for working with collections. Many Ruby classes implement the `Enumerable` interface that look like collections. Chances are if it has an `each` method it supports `Enumerable`, and because of that it's quite ubiquitous in Ruby.

> **Note**: This idea was partially inspired by [Lamar Burdette](https://github.com/BurdetteLamar)'s recent work on Ruby documentation, but takes its own direction.

## Combining

When grouping and counting won't quite do it's time to start combining us some elements. Ruby provides various methods for combining `Enumerable`s together, or perhaps even combining them all down into one element. Either way, some of my favorite methods are in here.

### [`#chain`](https://ruby-doc.org/core/Enumerable.html#method-i-chain)

`chain` allows you to combine two `Enumerator`s, which can be useful if you want to combine two `Enumerable`s, like say we had our range above for card ranks:

```ruby
RANKS = %w(2 3 4 5 6 7 8 9 10 J Q K A).freeze
```

Instead of typing that all out we could do this:

```ruby
('2'..'10').chain(%w(J Q K A))
```

This can also take multiple `Enumerable`s as arguments.

I haven't often used `chain`, but have found a few minor usages of it on occasion when dealing with a lot of `Enumerator`s.

### [`#cycle`](https://ruby-doc.org/core/Enumerable.html#method-i-cycle)

`cycle` lets you take a single collection and make it loop infinitely:

```ruby
[1, 2, 3].cycle.first(20)
# => [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2]
```

If given an argument it will only cycle that many times:

```ruby
[1, 2, 3].cycle(3).to_a
# => [1, 2, 3, 1, 2, 3, 1, 2, 3]
```

If you don't give it a Block Function it'll return an `Enumerator` so you won't _actually_ be allocating infinite cycles. We'll be getting more into `Enumerator` in another post.

`cycle` is another function I don't frequently use, but can be useful for `zip`.

### [`#reduce`](https://ruby-doc.org/core/Enumerable.html#method-i-reduce) / [`#inject`](https://ruby-doc.org/core/Enumerable.html#method-i-inject)

`reduce` is interesting in that it's so powerful you could literally write any other `Enumerable` method using it. [I even did a conference talk on this once](https://www.youtube.com/watch?v=x3b9KlzjJNM). We won't get into that for now, but the idea is that it allows you to reduce a collection into one element. It's also called `fold` or `foldLeft` in other programming languages.

Its usual example is a sum or product:

```ruby
[1, 2, 3].reduce(0) { |a, i| a + i }
# => 6

[1, 2, 3].reduce(1) { |a, i| a * i }
# => 6
```

`reduce` takes an optional argument as an initial accumulator, and if one isn't given it uses the first item of the collection. It then takes a Block Function which takes two arguments, the accumulator and the item. The result of each call to `reduce` becomes the new accumulator the next loop. Sound like a mouthful? It is, let's look at an example:

```ruby
[1, 2, 3].reduce(0) do |a, i|
  puts(a: a, i: i, new_a: a + i)
  a + i
end
# STDOUT: {:a=>0, :i=>1, :new_a=>1}
# STDOUT: {:a=>1, :i=>2, :new_a=>3}
# STDOUT: {:a=>3, :i=>3, :new_a=>6}
# => 6
```

> **Note**: `puts(k: value)` is one of my favorite debugging and example tricks. The `Hash` braces are implied, and it gives extra information to help finding issues.

So we can see that when the `reduce` function starts it has an accumulator of `0`, a first item of `1`, and that function returns `1` which becomes the next accumulator for the next loop. Eventually it runs out of items and `6` was the last value of the accumulator.

An interesting observation is that empty value doesn't need to be a number. What if it were a `String`? `Hash`? `Boolean`, `Array`, etc etc. Then it gets real interesting. Consider `map` reimplemented in terms of `reduce`:

```ruby
def map(collection, &fn)
  collection.reduce([]) { |a, v| a << fn.call(v) }
end
```

`reduce` is insanely powerful, but at the same time there are less powerful methods which do the same job with less effort. Prefer methods which are more tailored for your task, like `sum` or `tally`.

### [`#each_with_object`](https://ruby-doc.org/core/Enumerable.html#method-i-each_with_object)

`each_with_object` is like a reversed `reduce`, except that the return value of each call to the Block Function is ignored and it only cares about the object it was iterating with:

```ruby
[1, 2, 3].each_with_object({}) { |i, a| a[i.to_s] = i }
# => {"1"=>1, "2"=>2, "3"=>3}
```

Oh, and make sure to mutate `a` because otherwise nothing will happen. Notice as well that the arguments are reversed. The way I remember this is the `with_object` after `each`, implying the object is the second argument. I still get that backwards more often than I'd care to admit.

### [`#zip`](https://ruby-doc.org/core/Enumerable.html#method-i-zip)

`zip` allows us to combine two or more collections into one:

```ruby
a = [1, 2, 3]
b = [2, 3, 4]
c = [3, 4, 5]

a.zip(b, c)
# => [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
```

`zip` can be useful for merging multiple collections into one, especially when you have things like keys and values as separate variables you need to put together.

It can also take a Block Function which specifies how to zip values:

```ruby
a = [1, 2, 3]
b = [2, 3, 4]
c = [3, 4, 5]

a.zip(b, c) { |x, y, z| [z, y - x] }
# => nil
```

Oddly this returns `nil` and you have to use an outside array to capture these values. I cannot say I understand this as I might have expected this to behave like `map`, but it is as it is. Given that I would suggest avoiding this syntax, as it may be confusing.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. ~~Sorting and Comparing~~
5. ~~Counting~~
6. ~~Grouping~~
7. ~~Combining~~
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
