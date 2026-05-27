---
layout: "post"
title: "Understanding Ruby - Enumerable - Searching and Filtering"
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

## Searching and Filtering

Sometimes you need to find a specific value in a collection. Ruby has methods for that. Sometimes you need to find more than one, and perhaps only ones that match a certain condition, or maybe even ones that don't match the condition at all.

### [`#find`](https://ruby-doc.org/core/Enumerable.html#method-i-find) / [`#detect`](https://ruby-doc.org/core/Enumerable.html#method-i-detect)

`find` is how you find one element in a collection:

```ruby
[1, 2, 3].find { |v| v == 2 }
# => 2

[1, 2, 3].find { |v| v == 5 }
# => nil
```

Oddly it takes a single argument, something that responds to `call`, as a default:

```ruby
[1, 2, 3].find(-> { 1 }) { |v| v == 5 }
# => 1
```

I honestly do not understand this myself as you cannot give it a value like this:

```ruby
[1, 2, 3].find(1) { |v| v == 5 }
# NoMethodError (undefined method `call' for 1:Integer)
```

There is currently a [bug tracker issue open against this](https://bugs.ruby-lang.org/issues/7394), but it hasn't seen updates in a fair amount of time not including my recent question on it.

`find` is useful for finding a single value in a collection and returning it as soon as it finds it, rather than using something like `select.first` which would iterate all elements.

### [`#find_index`](https://ruby-doc.org/core/Enumerable.html#method-i-find_index)

`find_index` is very similar to `find` except that it finds the index of the item rather than returning the actual item:

```ruby
[1, 2, 3].find_index { |v| v == 2 }
# => 1
```

Interestingly it takes an argument rather than a Block Function for a value to search for:

```ruby
[1, 2, 3].find_index(3)
# => 2
```

...which makes a bit more sense than a default argument like in the case of `find`, but to change those would break all types of potential code.

I have not found a direct use for `find_index` at this point, and cases where I would use it I tend to reach for slicing and partitioning methods instead.

### [`#select`](https://ruby-doc.org/core/Enumerable.html#method-i-select) / [`#find_all`](https://ruby-doc.org/core/Enumerable.html#method-i-find_all) / [`#filter`](https://ruby-doc.org/core/Enumerable.html#method-i-filter)

`select` is a method with a lot of aliases in `find_all` and `filter`. If you come from Javascript `filter` might be more comfortable, and with the introduction of `filter_map` it may see more popularity. `select` is more common in general usage.

`select` is used to get all elements in a collection that match a condition:

```ruby
[1, 2, 3, 4, 5].select(&:even?)
# => [2, 4]
```

Currently it uses a Block Function to check each element.

`select` is typically used and great for filtering lists by a positive condition.

### [`#reject`](https://ruby-doc.org/core/Enumerable.html#method-i-reject)

`reject`, however, is great for negative conditions like everything except `Numeric` entries:

```ruby
[1, 'a', 2, :b, 3, []].reject { |v| v.is_a?(Numeric) }
# => ["a", :b, []]
```

Though in this particular case I would likely use `grep_v` instead which we'll cover in a moment. `grep` right below will have some additional insights on this distinction.

Often times Ruby methods will have a dual that does the opposite. `select` and `reject`, `all?` and `none?`, the list goes on. Chances are there's an opposite method out there.

`reject` has many of the same uses as `select` except that it inverts the condition and instead rejects elements which match a condition.

### [`#grep`](https://ruby-doc.org/core/Enumerable.html#method-i-grep)

`grep` is interesting in that it's based on Unix's `grep` command, but in Ruby it takes something that responds to `===` as an argument:

```ruby
[1, :a, 2, :b].grep(Symbol)
# => [:a, :b]
```

It behaves similarly to `select`, and [there are tickets out](https://bugs.ruby-lang.org/issues/17140) to consider adding the `===` behavior to `select`, similarly with `reject` and `grep_v`.

Where it differs is that its block does something different:

```ruby
[1, :a, 2, :b].grep(Numeric) { |v| v + 1 }
# => [2, 3]
```

It acts very much like `map` for any elements which matched the condition.

`grep` behaves mildly similarly to `filter_map` except that every element in the block has already been filtered via `===`. When you need more power for conditional checking if an element belongs in the new list use `filter_map`, otherwise `grep` makes a lot of sense.

### [`#grep_v`](https://ruby-doc.org/core/Enumerable.html#method-i-grep_v)

`grep_v` is the dual of `grep`, similar to `select` and `reject`. `grep_v` behaves similarly to `reject` except it uses `grep`'s style:

```ruby
[1, :a, 2, :b].grep_v(Symbol)
# => [1, 2]

[1, :a, 2, :b].grep_v(Symbol) { |v| v + 1 }
# => [2, 3]
```

Just as with `reject` it makes sense in cases where you want the opposite data from `grep` but still want the same condition.

### [`#uniq`](https://ruby-doc.org/core/Enumerable.html#method-i-uniq)

`uniq` will get all unique items in a collection:

```ruby
[1, 2, 3, 1, 1, 2].uniq
# => [1, 2, 3]
```

It also takes a block to let you decide exactly what criteria you want the new collection to be unique by:

```ruby
(1..10).uniq { |v| v % 5 }
# => [1, 2, 3, 4, 5]
```

Which can be very useful for unique sizes, names, or other criteria. In the above example we're doing something a bit unique in searching for remainders from modulo which can be very useful in certain algorithmic problems.

`uniq` is great when you want to get a unique collection of elements, but if you find yourself using `uniq` a lot you may want to consider using a `Set` instead, which we'll cover in a later article.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. Sorting and Comparing
5. Counting
6. Grouping
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
