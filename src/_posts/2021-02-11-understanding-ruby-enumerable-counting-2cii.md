---
layout: "post"
title: "Understanding Ruby - Enumerable - Counting"
series: "understanding-ruby"
date: "2021-02-11"
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

## Counting

It's the thought that counts, or is it your code? Well Ruby gives various methods for counting, tallying, or otherwise summing up your collections.

### [`#count`](https://ruby-doc.org/core/Enumerable.html#method-i-count)

`count` counts the number of elements in a collection that match a condition. When supplied no arguments it returns how many elements are in the collection:

```ruby
[1, 2, 3, 4, 5].count
# => 5
```

When given a number it searches for that number and gives a count of how many occurrences it found:

```ruby
[1, 1, 2, 2, 3, 3, 3].count(3)
# => 3
```

...and finally when given a Block Function it returns back how many elements matched a condition inside of it:

```ruby
[1, 1, 2, 2, 3, 3, 3].count(&:odd?)
# => 5
```

`count` is one of those methods which comes in handy all the time, and I frequently use it along with the other two methods in this section.

### [`#sum`](https://ruby-doc.org/core/Enumerable.html#method-i-sum)

`sum` gets the sum of the elements in a collection:

```ruby
[1, 2, 3].sum
# => 6
```

It also takes an initial value to start summing from:

```ruby
[1, 2, 3].sum(1)
# => 7
```

It can also take a Block Function to define how to sum each element:

```ruby
[1, 2, 3].sum { |v| v * 2 }
# => 12
```

Do note that's not a product, we'd need `reduce` in a moment for that.

### [`#tally`](https://ruby-doc.org/core/Enumerable.html#method-i-tally)

`tally` is admittedly a point of pride for me as me and a group of friends at RailsCamp [had a hand in naming it](/writing/2019/02/10/ruby-2-7-enumerable-tally-3b02/).

It used to be that you had to do this to get counts indexed by a key:

```ruby
%w(a fresh lively lemur jumps over a tea kettle)
  .group_by(&:itself)
  .map { |k, vs| [k, vs.size] }
  .to_h
# => {"a"=>2, "fresh"=>1, "lively"=>1, "lemur"=>1, "jumps"=>1, "over"=>1, "tea"=>1, "kettle"=>1}

# or
%w(a fresh lively lemur jumps over a tea kettle)
  .each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }
# => {"a"=>2, "fresh"=>1, "lively"=>1, "lemur"=>1, "jumps"=>1, "over"=>1, "tea"=>1, "kettle"=>1}
```

Now with `tally` you can do this:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).tally
# => {"a"=>2, "fresh"=>1, "lively"=>1, "lemur"=>1, "jumps"=>1, "over"=>1, "tea"=>1, "kettle"=>1}
```

That's much more pleasant. Consider combining it with `map` to do even more interesting things:

```ruby
%w(a fresh lively lemur jumps over a tea kettle)
  .map(&:size)
  .tally
# => {1=>2, 5=>3, 6=>2, 4=>1, 3=>1}
```

`tally` is one of my most used functions next to `map`, `filter`, and `reduce`. It's really handy to get a quick look at an overview of the data you're looking at in a concise way.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. ~~Sorting and Comparing~~
5. ~~Counting~~
6. Grouping
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
