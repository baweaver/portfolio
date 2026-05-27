---
layout: "post"
title: "Understanding Ruby - Comparable"
series: "understanding-ruby"
date: "2021-02-09"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Introduction   Before we get into larger modules like Enumerable there are some very interes..."
---

# Introduction

Before we get into larger modules like `Enumerable` there are some very interesting ones that don't get quite as much attention. One of them is `Comparable`, which allows you to compare and sort items of a similar type.

## Difficulty

**Foundational**

Little to no prerequisite knowledge required. This post focuses on foundational and fundamental knowledge for Ruby programmers.

# Comparable

`Comparable` is a type of module in Ruby, or in this case a group of methods, that requires you to define one method to get all types of other methods based on it. Some would call this an interface in other languages, and that's a fairly reasonable descriptor of what `Comparable` is.

As to what it does? It allows you to compare things, much like the name implies.

## What're We Comparing?

To start out with, what are we comparing? Let's work with a card from a [Standard 52-Card Hand](https://en.wikipedia.org/wiki/Standard_52-card_deck):

```ruby
class Card
  SUITS        = %w(S H D C).freeze
  RANKS        = %w(2 3 4 5 6 7 8 9 10 J Q K A).freeze
  RANKS_SCORES = RANKS.each_with_index.to_h
  
  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end
  
  def to_s() = "#{@suit}#{@rank}"
end
```

For me I like to define what type of data goes into our class in constants before actually building out the rest of the class.

In this case we have suits of S H D C, meaning Spades, Hearts, Diamonds, and Clubs. We also have ranks from 2 up through Ace, and since those ranks aren't all numbers we want to know what order they're in and we want a mapping of their relative ranks to eachother. We can check that with `Card::RANKS_SCORES`:

```ruby
Card::RANKS_SCORES
# => {
#   "2"=>0, "3"=>1, "4"=>2, "5"=>3, "6"=>4, "7"=>5, "8"=>6,
#   "9"=>7, "10"=>8, "J"=>9, "Q"=>10, "K"=>11, "A"=>12
# }
```

This means `A` has a much higher rank, or precedence, than say `2` does.

We also have a quick "To String" method (`to_s`) to tell Ruby how to present a Card as a string.

## Precedence

Before we compare things, we're going to want to define a method for precedence to encapsulate the idea of an integer-like score for each card:

```ruby
class Card
  def precedence() = RANKS_SCORES[@rank]
end
```

In this case we can say a card's precedence is based solely on its rank. For some card games though we might also want to include the suit. If that was the case we'd want to add a few things:

```ruby
class Card
  SUITS_RANKS = SUITS.each_with_index.to_h
  
  def precedence
    [SUITS_SCORES[@suit], RANKS_SCORES[@rank]]
  end
end
```

Why the `Array`? Because it lets us compare on sequential conditions later. First by suit, and then by rank.

## The Rocketship Operator

In order to be able to compare things in Ruby we first need to know how to tell if something is larger, smaller, or equivalent to something else of the same type. Ruby encapsulates this idea in the Rocketship Operator (`<=>`):

```ruby
def <=>(other)
  # ...
end
```

If we were to implement it for our card it would look a bit like this:

```ruby
class Card
  def <=>(other) = precedence <=> other.precedence
end
```

Because we defined a `precedence` method earlier our implementation is pretty easy. We're comparing the precedence of the two cards.

How is this useful? Well let's take a look at the return value:

```ruby
two_of_spades = Card.new('S', '2')
three_of_spades = Card.new('S', '3')
four_of_spades = Card.new('S', '4')

two_of_spades <=> three_of_spades
# => -1 - Greater right side
four_of_spades <=> four_of_spades
# => 0 - Equal values
three_of_spades <=> two_of_spades
# => 1 - Greater left side
```

It gives us back three integers ranging from -1 to 1, which really doesn't seem that handy, until you remember that some operators like `===` are more useful for what they enable rather than being used explicitly themselves.

## Introducing Comparable

So where does `Comparable` fit in to all of this? Right here:

```ruby
class Card
  include Comparable
end
```

Adding that one line along with a Rocketship Operator (`<=>`) lets us do a whole bunch of things like:

```ruby
def show_hand(cards) = cards.map(&:to_s).join(', ')
  
cards = ('2'..'8').map { Card.new('S', _1) }.shuffle

show_hand cards
# => "S6, S2, S5, S7, S3, S4, S8"

show_hand cards.sort
# => "S2, S3, S4, S5, S6, S7, S8"

show_hand cards.max(2)
# => "S8, S7"

show_hand cards.minmax
# => "S2, S8"

cards.min.to_s
# => "S2"
```

...and quite a few more you can find in the [Comparable docs](https://ruby-doc.org/core-3.0.0/Comparable.html). One module included and one method defined for all of that seems like a pretty good deal to me!

# Wrapping Up

`Comparable` is one of several useful interface modules in Ruby, and knowing how it and the Rocketship Operator (`<=>`) work can be very useful indeed.

Next round we'll be taking a look at one of the largest interface modules, and likely the biggest center of power for most of what makes Ruby Ruby: `Enumerable`.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
