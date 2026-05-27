---
layout: "post"
title: "Understanding Ruby - Enumerable - Iterating and Taking"
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

## Iterating and Taking

Sometimes you just want to go through your collection, or perhaps even just take a few of them, just a sampling for now.

### [`#first`](https://ruby-doc.org/core/Enumerable.html#method-i-first) / [`#take`](https://ruby-doc.org/core/Enumerable.html#method-i-take)

`first` allows you to get the first few items of a collection:

```ruby
[1, 2, 3, 4, 5].first(3)
# => [1, 2, 3]
```

...or if you use it with one argument it returns the first element:

```ruby
[1, 2, 3, 4, 5].first
# => 1
```

Interestingly if you want the first element but still want an `Array` returned there's no rule against using `1` for the number of elements:

```ruby
[1, 2, 3, 4, 5].first(1)
# => [1]
```

This has been handy for me in the past.

`first` is used, as the name suggests, to get the first elements out of a collection. `Array` itself also implements `last`, being `first`s dual method, but that's not `Enumerable` specifically.

### [`#take_while`](https://ruby-doc.org/core/Enumerable.html#method-i-take_while)

`take_while` works a lot like `take` except it takes a conditional Block Function rather than a number:

```ruby
[1, 2, 3, 4, 5].take_while { |v| v < 3 }
# => [1, 2]
```

It can be useful for when you want to get the first few elements of a list, but up to a certain point. This is much more useful when the collection is sorted.

### [`#drop`](https://ruby-doc.org/core/Enumerable.html#method-i-drop)

`drop` is an interesting inversion of `first` in that it gives you back a new `Array` without the first few elements:

```ruby
[1, 2, 3, 4, 5].drop(3)
# => [4, 5]
```

`drop` can be handy if you want to ignore the first few elements of a collection.

### [`#drop_while`](https://ruby-doc.org/core/Enumerable.html#method-i-drop_while)

`drop_while` works a lot like `drop`, just the same as `take_while` and `take`, except it drops elements up to that point:

```ruby
[1, 2, 3, 4, 5].drop_while { |v| v < 3 }
# => [3, 4, 5]
```

As with `take_while` this can be much more useful with a sorted collection.

### [`#each_entry`](https://ruby-doc.org/core/Enumerable.html#method-i-each_entry)

On the surface `each_entry` looks like an alias for `each`. Almost, but not quite:

```ruby
class Foo
  include Enumerable
  
  def each
    yield 1
    yield 1, 2
    yield
  end
end

Foo.new.each_entry { |o| p o }
# STDOUT: 1
# STDOUT: [1, 2]
# STDOUT: nil
# => Foo<>
```

Looking at the example on the doc site it's doing a few different things:

```ruby
Foo.new.each { |o| p o }
# STDOUT: 1
# STDOUT: 1
# STDOUT: nil
# => nil
```

Notice two things. The second yield only has one element now, and the return value is `nil` rather than the calling object `Foo`. `nil` because the original implementation of `each` for `Array` returns the base object.

I have not found a use for `each_entry`, but will endeavor to find what it might be used for. In the mean time I would encourage the use of `each` instead.

### [`#each_with_index`](https://ruby-doc.org/core/Enumerable.html#method-i-each_with_index)

`each_with_index`, as the name implies, is `each` with an index along for the ride:

```ruby
[1, 2, 3].each_with_index { |v, i| p v + i }
# STDOUT: 1
# STDOUT: 3
# STDOUT: 5
# => [1, 2, 3]
```

While that can be useful on its own it returns an `Enumerator` when not given a Block Function, meaning we can chain onto it:

```ruby
[1, 2, 3].each_with_index.map { |v, i| v + i }
# => [1, 3, 5]
```

`each_with_index` is useful when we want to iterate along with the index, especially if we need that index for something.

### [`#reverse_each`](https://ruby-doc.org/core/Enumerable.html#method-i-reverse_each)

`reverse_each` iterates in the reverse order:

```ruby
[1, 2, 3].reverse_each { |v| p v }
# STDOUT: 3
# STDOUT: 2
# STDOUT: 1
# => [1, 2, 3]
```

Since it returns an `Enumerator` like most of these methods do should you not pass a Block Function, you can also chain it:

```ruby
[1, 2, 3].reverse_each.map { |v| v * 2 }
# => [6, 4, 2]
```

`reverse_each` is useful when you want to go backwards, and there will be cases where you want to do that.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. ~~Sorting and Comparing~~
5. ~~Counting~~
6. ~~Grouping~~
7. ~~Combining~~
8. ~~Iterating and Taking~~
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
