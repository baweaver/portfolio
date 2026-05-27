---
layout: "post"
title: "Understanding Ruby - Enumerable - Transformations"
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

## Transformations

Our first section will focus on methods which transform collections into new collections, primarily by using Block Functions.

### [`#map`](https://ruby-doc.org/core/Enumerable.html#method-i-map) / [`#collect`](https://ruby-doc.org/core/Enumerable.html#method-i-collect)

`map` expresses the idea of transforming a collection using a function, or by using the english word expressing a way to get from point A to point B. Amusingly in some functional programming languages this is expressed `A -> B`, wherein `->` is the function.

For us it might be used something like this:

```ruby
[1, 2, 3].map { |v| v * 2 }
# => [2, 4, 6]
```

In which the function is to double every element of a collection, giving us back a brand new collection in which all elements are doubles of the original.

Using the syntax for `Symbol#to_proc` we can also use `map` to extract values out of objects:

```ruby
people.map(&:name)
```

If we had an `Array` of people we could use `map` to get all of their names using this shorthand.

`map` is great for transforming collections and pulling things out of a collection.

### [`#flat_map`](https://ruby-doc.org/core/Enumerable.html#method-i-flat_map) / [`#collect_concat`](https://ruby-doc.org/core/Enumerable.html#method-i-collect_concat)

`flat_map` will both `map` a collection and afterwards `flatten` it:

```ruby
hands = [
  Hand.from_str('S2, S3, S4'),
  Hand.from_str('S3, S4, S5'),
  Hand.from_str('S4, S5')
]

hands.flat_map(&:cards).map(&:to_s).join(', ')
# => "S2, S3, S4, S3, S4, S5, S4, S5"
```

`flat_map` is great when you want to extract something like an `Array` from items and combine them all into one `Array`. It's also great for generating products, but remember that Ruby also has the [`Array#product`](https://ruby-doc.org/core/Array.html#method-i-product) method which works better unless you have something more involved to do.

It's for when you want one `Array` rather than `Array`s of `Array`s.

### [`#filter_map`](https://ruby-doc.org/core/Enumerable.html#method-i-filter_map)

`filter_map` is interesting in that it combines the idea of `filter` and the idea of `map`. If the function passed to `filter_map` returns something falsy (`false` or `nil`) it won't be present in the returned collection:

```ruby
[1, 2, 3].filter_map { |v| v * 2 if v.odd? }
# => [2, 6]
```

In this case `2` will be ignored. `filter_map` is great if you find yourself using `map`, returning `nil`, and using `compact` at the end to drop `nil` values.

This method is great when you want to both filter down a collection and do something with those values.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. Predicate Conditions
3. Searching and Filtering
4. Sorting and Comparing
5. Counting
6. Grouping
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
