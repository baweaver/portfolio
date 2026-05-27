---
layout: "post"
title: "Understanding Ruby - Enumerable - Coercion"
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

## Coercion

Perhaps you don't even want an `Enumerable` at all, there are even methods for changing it over to another type, or methods to coerce them rather.

### [`#to_a`](https://ruby-doc.org/core/Enumerable.html#method-i-to_a) / [`#entries`](https://ruby-doc.org/core/Enumerable.html#method-i-entries)

`to_a` will coerce a collection into an `Array`. This isn't very useful for an `Array`, sure, but remember that other collection types have `Enumerable` like `Hash` and `Set`:

```ruby
require 'set'

Set[1, 2, 3].to_a
# => [1, 2, 3]

{ a: 1, b: 2, c: 3 }.to_a
# => [[:a, 1], [:b, 2], [:c, 3]]
```

Its use is very much "what's on the box". If you need something to be an `Array` use `to_a`

### [`#to_h`](https://ruby-doc.org/core/Enumerable.html#method-i-to_h)

`to_h` is very similar, it coerces a collection to a `Hash`:

```ruby
[[:a, 1], [:b, 2], [:c, 3]].to_h
# => [[:a, 1], [:b, 2], [:c, 3]]
```

One interesting thing you can do is to use something like `each_with` methods to do nifty things:

```ruby
%i(a b c).each_with_index.to_h
# => {:a=>0, :b=>1, :c=>2}

%i(a b c).each_with_object(:default).to_h
# => {:a=>:default, :b=>:default, :c=>:default}
```

While that alone is interesting, there's a pattern you may recognize from Ruby in days past:

```ruby
%i(a b c).map { |v| [v, 0] }.to_h
# => {:a=>0, :b=>0, :c=>0}

# Remember, `map` returns an `Array`
{ a: 1, b: 2, c: 3 }.map { |k, v| [k, v + 1] }.to_h
# => {:a=>2, :b=>3, :c=>4}
```

Guess what else `to_h` does? It takes a Block Function:

```ruby
%i(a b c).to_h { |v| [v, 0] }
# => {:a=>0, :b=>0, :c=>0}

{ a: 1, b: 2, c: 3 }.to_h { |k, v| [k, v + 1] }
# => {:a=>2, :b=>3, :c=>4}
```

...which is pretty nifty. Granted `Hash` has `transform_values` now as well, which is probably a better idea for that specific transformation, but it gets the point across.

`to_h` is great, much like `to_a`, when you need a `Hash`. It has some more power behind it for getting there, and a lot of neat things you can do with it as a result.

# Wrapping Up

With that we're done with our section on `Enumerable`, and we'll be moving on to new subjects!

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
