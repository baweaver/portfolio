---
layout: "post"
title: "Understanding Ruby - Enumerable - Intro and Interfaces"
series: "understanding-ruby"
date: "2021-02-11"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Introduction   Enumerable. Debatably one of, if not the, most powerful features in Ruby. As..."
---

# Introduction

`Enumerable`. Debatably one of, if not the, most powerful features in Ruby. As a majority of your time in programming is dealing with collections of items it's no surprise how frequently you'll see it used.

This first article will cover implementing the interface for `Enumerable`.

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

So how are we going to cover such a large piece of the language? Categorically, and of course after we show how you can implement one of your own

> **Note**: This idea was partially inspired by [Lamar Burdette](https://github.com/BurdetteLamar)'s recent work on Ruby documentation, but takes its own direction.

## Cards in a Hand

To start with, how do we implement `Enumerable` ourselves? Via an `each` method and including the module, much like `Comparable` from the last post. We'll be re-exploring our `Card` class from that article as well as making a `Hand` to contain those cards.

### Remembering our Card

Let's start with our `Card` class from last time:

```ruby
class Card
  SUITS        = %w(S H D C).freeze
  RANKS        = %w(2 3 4 5 6 7 8 9 10 J Q K A).freeze
  RANKS_SCORES = RANKS.each_with_index.to_h

  include Comparable

  attr_reader :suit, :rank

  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end

  def self.from_str(s) = new(s[0], s[1..])

  def to_s() = "#{@suit}#{@rank}"
    
  def <=>(other) = precedence <=> other.precedence
end
```

There's one new method here for convenience that gives us a `Card` from a `String`, letting us do this:

```ruby
Card.from_str('SA')
```

That gets to be handy when we want an entire hand in a second.

### Creating a Hand

Now let's take a look at a Hand class that might contain these cards:

```ruby
class Hand
  include Enumerable
  
  attr_reader :cards
  
  def initialize(*cards)
    @cards = cards.sort
  end

  def self.from_str(s) = new(*s.split(/[ ,]+/).map { Card.from_str(_1) })

  def to_s() = @cards.map(&:to_s).join(', ')
  
  def each(&fn) = @cards.each { |card| fn.call(card) }
end
```

Starting with `Enumerable` features, we define an `each` method at the bottom which takes a Block Function and calls it with each card from the cards in our `Hand`.

Next we have a utility function like `Card` had which allows us to make a `Hand` from a `String`, because otherwise that's a lot of typing:

```ruby
royal_flush = Hand.from_str('S10, SJ, SQ, SK, SA')
```

With the above Enumerable code we can now use any of the `Enumerable` methods against it:

```ruby
royal_flush.reject { |c| c <= Card.from_str('SQ') }.join(', ')
# => "SK, SA"
```

Nifty! Now with that down let's take a look at all of the shiny fun things in `Enumerable`. We'll be using more generic examples from here on out.

In the next few articles we'll really be digging into `Enumerable`. This was broken up into multiple quickly published articles to make it a bit more readable, otherwise it's 30+ minutes to get through. 

## Note on Aliases

Ruby has many aliases, like `collect` is an alias for `map`. As I prefer `map` I will be using that for examples. When you see a `/` in the header in other sections, the first item will be the preference I will draw from, but you _could_ use the other name to the same effect.

## Note on Syntax

You might see `#method_name` or `.method_name` mentioned in Ruby on occasion. This means Instance Method and Class Method respectively. You might also see it like `Enumerable#map`, which means `map` is an Instance Method of `Enumerable`.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. Transforming
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
