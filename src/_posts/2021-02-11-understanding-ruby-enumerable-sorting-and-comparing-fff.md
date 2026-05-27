---
layout: "post"
title: "Understanding Ruby - Enumerable - Sorting and Comparing"
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

## Sorting

Perhaps you're the sort that likes everything to be in a certain order, but how are you going to sort it? Will it be by default, length, or what? Ruby gives you a lot of power to figure all of that out.

All of these methods require that the underlying class implements `<=>`, or you will see errors.

### [`#sort`](https://ruby-doc.org/core/Enumerable.html#method-i-sort)

`sort` will sort collections:

```ruby
[4, 2, 1].sort
# => [1, 2, 4]
```

Remembering back to `Comparable` it can also take a Block Function with a comparator Rocketship Operator (`<=>`):

```ruby
[1, 2, 4].sort { |a, b| b <=> a }
# => [4, 2, 1]
```

It follows the same rules of deciding precedence by the return of the comparator, and that has to be an `Integer` of one of `-1, 0, 1` in value.

### [`#sort_by`](https://ruby-doc.org/core/Enumerable.html#method-i-sort_by)

`sort_by` is interesting in that it implements the comparator behind the scenes and uses a single attribute instead:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).sort_by(&:length)
# => ["a", "a", "tea", "over", "jumps", "fresh", "lemur", "lively", "kettle"]
```

The docs do note that this is much slower, because nothing nice ever comes for free, and why knowing what `Comparable` is is quite useful to define how `sort` behaves by default.

## Comparing

All of these methods require that the underlying class implements `<=>`, or you will see errors.

### [`#max`](https://ruby-doc.org/core/Enumerable.html#method-i-max)

`max` gets the item with the maximum value in a collection:

```ruby
[1, 2, 3].max
# => 3
```

When provided a Block Function it works much like `sort` and its comparator:

```ruby
[1, 2, 3].max { |a, b| b <=> a }
# => 1
```

Though if you want to do something like that it probably makes more sense to use `min`.

It can also take a number to get multiple max numbers:

```ruby
[1, 2, 3, 4, 5].max(3)
# => [5, 4, 3]
```

Those numbers will be in order of maximum to least so, and this can also take a Block Function the same as above.

### [`#max_by`](https://ruby-doc.org/core/Enumerable.html#method-i-max_by)

`max_by` is very much like `sort_by` except in that it will give the maximum elements rather than sorting:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).max_by(&:length)
# => "lively"
```

This can also take a number:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).max_by(2, &:length)
# => => ["kettle", "lively"]
```

`sort` mentions this, but elements that are both `0` when compared may come back in unexpected order, but in this case the order that they were found in reverse.

### [`#min`](https://ruby-doc.org/core/Enumerable.html#method-i-min)

`min` is the inverse of `max`, and works much the same way:

```ruby
[1, 2, 3].min
# => 1
```

See `max` for accepting a number and a Block Function

### [`#min_by`](https://ruby-doc.org/core/Enumerable.html#method-i-min_by)

The same can be said of `min_by` versus `max_by`:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).min_by(&:length)
# => "a"
```

See `max_by` for more options.

### [`#minmax`](https://ruby-doc.org/core/Enumerable.html#method-i-minmax)

`minmax`, however, is a bit different. It returns both the minimum and maximum element in a list as a pair:

```ruby
[1, 2, 3, 4, 5].minmax
# => [1, 5]
```

As with the `min` methods these behave the same.

### [`#minmax_by`](https://ruby-doc.org/core/Enumerable.html#method-i-minmax_by)

`minmax_by` follows the same conventions as well:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).minmax_by(&:length)
# => ["a", "lively"]
```

See `max_by` for more options.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. ~~Sorting and Comparing~~
5. Counting
6. Grouping
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
