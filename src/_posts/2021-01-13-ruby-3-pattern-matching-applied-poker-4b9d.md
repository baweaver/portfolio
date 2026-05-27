---
layout: "post"
title: "Ruby 3 Pattern Matching Applied: Poker"
date: "2021-01-13"
categories: ["ruby", "ruby3"]
tags: ["ruby", "ruby3", "patternmatching"]
description: "Pattern Matching in Ruby 2.7 and 3.0 can be an odd concept to read about, and an even stranger one to know how to use. This is a detailed example of a more complicated use-case of pattern matching to solve for scoring poker hands"
---

Ruby 3.0 introduced Pattern Matching as a key feature, but if you're like a lot of folks you may not entirely be sure what it's used for or why you might want it.

This article is going to go over just that and show you how to use Pattern Matching to score a poker hand!

![Arsene Lemur on a playing card](/images/posts/2021-01-13-ruby-3-pattern-matching-applied-poker-4b9d/img-2b26357e.png)

# The Program

Let's start out by looking at the entirety of the script. We'll be walking through each part of it here in a moment, but make sure to note parts that are confusing as you give it a read, and see if you can figure out what it's doing:

```ruby
Card = Struct.new(:suit, :rank) do
  include Comparable

  def precedence()      = [SUITS_SCORES[self.suit], RANKS_SCORES[self.rank]]
  def rank_precedence() = RANKS_SCORES[self.rank]
  def suit_precedence() = SUITS_SCORES[self.rank]

  def <=>(other) = self.precedence <=> other.precedence

  def to_s() = "#{self.suit}#{self.rank}"
end

Hand = Struct.new(:cards) do
  def sort()         = Hand[self.cards.sort]
  def sort_by_rank() = Hand[self.cards.sort_by(&:rank_precedence)]

  def to_s() = self.cards.map(&:to_s).join(', ')
end

SUITS        = %w(S H D C).freeze
SUITS_SCORES = SUITS.each_with_index.to_h
RANKS        = [*2..10, *%w(J Q K A)].map(&:to_s).freeze
RANKS_SCORES = RANKS.each_with_index.to_h

SCORES = %i(
  royal_flush
  straight_flush
  four_of_a_kind
  full_house
  flush
  straight
  three_of_a_kind
  two_pair
  one_pair
  high_card
).reverse_each.with_index(1).to_h.freeze

CARDS = SUITS.flat_map { |s| RANKS.map { |r| Card[s, r] } }.freeze

def hand_score(unsorted_hand)
  hand = Hand[unsorted_hand].sort_by_rank.cards

  is_straight = -> hand {
    hand
      .map { RANKS_SCORES[_1.rank] }
      .sort
      .each_cons(2)
      .all? { |a, b| b - a == 1 }
  }

  return SCORES[:royal_flush] if hand in [
    Card[s, '10'], Card[^s, 'J'], Card[^s, 'Q'], Card[^s, 'K'], Card[^s, 'A']
  ]

  return SCORES[:straight_flush] if is_straight[hand] && hand in [
    Card[s, *], Card[^s, *], Card[^s, *], Card[^s, *], Card[^s, *]
  ]

  return SCORES[:four_of_a_kind] if hand in [
    *, Card[*, r], Card[*, ^r], Card[*, ^r], Card[*, ^r], *
  ]

  return SCORES[:full_house] if hand in [
    Card[*, r1], Card[*, ^r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2]
  ]

  return SCORES[:full_house] if hand in [
    Card[*, r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2], Card[*, ^r2]
  ]

  return SCORES[:flush] if hand in [
    Card[s, *], Card[^s, *], Card[^s, *], Card[^s, *], Card[^s, *]
  ]

  return SCORES[:straight] if is_straight[hand]

  return SCORES[:three_of_a_kind] if hand in [
    *, Card[*, r], Card[*, ^r], Card[*, ^r], *
  ]

  return SCORES[:two_pair] if hand in [
    *, Card[*, r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2], *
  ]

  return SCORES[:two_pair] if hand in [
    Card[*, r1], Card[*, ^r1], *, Card[*, r2], Card[*, ^r2]
  ]

  return SCORES[:one_pair] if hand in [
    *, Card[*, r], Card[*, ^r], *
  ]

  SCORES[:high_card]
end

# --- Testing ------

EXAMPLES = {
  royal_flush:
    RANKS.last(5).map { Card['S', _1] },

  straight_flush:
    RANKS.first(5).map { Card['S', _1] },

  four_of_a_kind:
    [CARDS[0], *SUITS.map { Card[_1, 'A'] }],

  full_house:
    SUITS.first(3).map { Card[_1, 'A'] } +
    SUITS.first(2).map { Card[_1, 'K'] },

  flush:
    (0..RANKS.size).step(2).first(5).map { Card['S', RANKS[_1]] },

  straight:
    [Card['H', RANKS.first], *RANKS[1..4].map { Card['S', _1] }],

  three_of_a_kind:
    CARDS.first(2) +
    SUITS.first(3).map { Card[_1, 'A'] },

  two_pair:
    CARDS.first(1) +
    SUITS.first(2).flat_map { [Card[_1, 'A'], Card[_1, 'K']] },

  one_pair:
    [CARDS[10], CARDS[15], CARDS[20], *SUITS.first(2).map { Card[_1, 'A'] }],

  high_card:
    [CARDS[10], CARDS[15], CARDS[20], CARDS[5], Card['S', 'A']]
}.freeze

SCORE_MAP = SCORES.invert

EXAMPLES.each do |hand_type, hand|
  score = hand_score(hand)
  correct_text = hand_type == SCORE_MAP[score] ? 'correct' : 'incorrect'

  puts <<~OUT
    Hand:  #{Hand[hand]} (#{hand_type})
    Score: #{score} (#{correct_text})
  OUT

  puts
end

```

It's a lot to take in at once, and if you don't understand all of it that's perfectly ok: that's what the rest of this article is for.

Shall we start digging in then?

# The Explanation

## A Constant Factor

Let's start by looking at our constants:

```ruby
SUITS         = %w(S H D C).freeze
SUITS_SCORES  = SUITS.each_with_index.to_h
RANKS         = [*2..10, *%w(J Q K A)].map(&:to_s).freeze
RANKS_SCORES  = RANKS.each_with_index.to_h

SCORES = %i(
  royal_flush
  straight_flush
  four_of_a_kind
  full_house
  flush
  straight
  three_of_a_kind
  two_pair
  one_pair
  high_card
).reverse_each.with_index(1).to_h.freeze

CARDS = SUITS.flat_map { |s| RANKS.map { |r| Card[s, r] } }.freeze
```

### Suits

We start with our suits: Spades, Hearts, Diamonds, and Clubs. They're shortened to their first letters:

```ruby
SUITS        = %w(S H D C).freeze
SUITS_SCORES = SUITS.each_with_index.to_h
```

We also want to score them so we have a quick index of priority to reference elsewhere without iterating the entire array everywhere.

### Ranks

Next we have our ranks, the cards from Two all the way up to Ace, represented by a number or their first letter:

```ruby
RANKS         = [*2..10, *%w(J Q K A)].map(&:to_s).freeze
RANKS_SCORES  = RANKS.each_with_index.to_h
```

The `map(&:to_s)` is to make sure it's in a consistent type, and as with the last one we want to create a mapping of rank to its priority. If it were just numbers that'd be silly, but face cards make this a tinge harder, so here we are.

### Scores

After that we have the ranking of hands all the way from a Royal Flush down to a High Card:

```ruby
SCORES = %i(
  royal_flush
  straight_flush
  four_of_a_kind
  full_house
  flush
  straight
  three_of_a_kind
  two_pair
  one_pair
  high_card
).reverse_each.with_index(1).to_h.freeze
```

We reverse it to make sure the Royal Flush has the highest score, but we want to read it in an order that makes sense to us. Remember to optimize for readability first (I say before the pattern matching monstrosity below, but I digress).

`with_index(1)` starts indexes at `1` instead of `0` and `to_h` gives us a mapping of hand type to the score we get for it.

### Cards

Last up we need to create all of our cards:

```ruby
CARDS = SUITS.flat_map { |s| RANKS.map { |r| Card[s, r] } }.freeze
```

We'll get to `Card` (including the bracket syntax) in a second in the next section, but what we're doing here is getting the product of all the `SUITS` applied to all of the card `RANKS`, or in other words every possible card ignoring jokers.

## Adding `Struct`ure

Structs in Ruby are very handy when you don't quite want a full class. I tend to use them when I don't want to type out `initialize` and they're south of 10 lines of code:

```ruby
Card = Struct.new(:suit, :rank) do
  include Comparable

  def precedence()      = [SUITS_SCORES[self.suit], RANKS_SCORES[self.rank]]
  def rank_precedence() = RANKS_SCORES[self.rank]
  def suit_precedence() = SUITS_SCORES[self.rank]

  def <=>(other) = self.precedence <=> other.precedence

  def to_s() = "#{self.suit}#{self.rank}"
end

Hand = Struct.new(:cards) do
  def sort()         = Hand[self.cards.sort]
  def sort_by_rank() = Hand[self.cards.sort_by(&:rank_precedence)]

  def to_s() = self.cards.map(&:to_s).join(', ')
end
```

### New Structs

How do Structs work then? They take a list of attributes, and act as a simple data container:

```ruby
Card = Struct.new(:suit, :rank)
```

This is equivalent to the following class, roughly speaking:

```ruby
class Card
  attr_accessor :suit, :rank
  
  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end
end
```

...but that takes one line, hence my proclivity towards them for demonstration purposes.

### Structs take Blocks

Struct constructors can also take blocks to define methods on them. Once you get here it _might_ be time to consider a class, but in this case it makes for a more fun explanation to keep using Structs, and also I didn't want to type more than I had to there:

```ruby
Card = Struct.new do
  def method_on_card
    'foo!'
  end
end

Card.new.method_on_card
# => 'foo!'

# Just an alias for new:
Card[].method_on_card
# => 'foo!'
```

### Comparable

We want to be able to compare cards, and since they're not cleanly mapped to numbers we need to give Ruby some help with how to sort them:

```ruby
Card = Struct.new(:suit, :rank) do
  include Comparable

  def precedence()      = [SUITS_SCORES[self.suit], RANKS_SCORES[self.rank]]
  def rank_precedence() = RANKS_SCORES[self.rank]
  def suit_precedence() = SUITS_SCORES[self.rank]

  def <=>(other) = self.precedence <=> other.precedence

  def to_s() = "#{self.suit}#{self.rank}"
end
```

`Comparable` allows us to use all types of sorting methods by implementing `<=>` (rocket-ship operator, or comparator) on a class, much the same as `Enumerable` and `each`. Our `<=>` looks like this:

```ruby
def <=>(other) = self.precedence <=> other.precedence
```

It's using Ruby 3's one-line methods, and we're comparing the precedence of one card to the other. In this case we're using this for precedence in ordering:

```ruby
def precedence() = [SUITS_SCORES[self.suit], RANKS_SCORES[self.rank]]
```

Why an `Array`? Because we want to defaultly sort by suit first, and then by rank. Spades outrank Hearts, and Aces outrank other ranks. Granted below we end up relying primarily on `rank_precedence` as pattern matching expects things to be in a coherent order, and normal precedence here isn't useful, merely for demonstration purposes.

### `to_s`

String representations are real handy when debugging, and in this case our `Card` is represented by its' suit and rank. Nothing too fancy here:

```ruby
def to_s() = "#{self.suit}#{self.rank}"
```

### Hands

Now we want a concept of a hand so we know what we're dealing with:

```ruby
Hand = Struct.new(:cards) do
  def sort()         = Hand[self.cards.sort]
  def sort_by_rank() = Hand[self.cards.sort_by(&:rank_precedence)]

  def to_s() = self.cards.map(&:to_s).join(', ')
end
```

You might notice I tend to return new objects rather than mutate in place for `sort` type methods. That's mostly for functional-style and not messing with my test data repeatedly.

A class or struct doesn't have to be complicated, it just has to provide some value over repeating array sorts and string prints everywhere.

## Scoring a Hand

Now we get into the really fun part of this program, and it's quite a lot to take in.

### Sorting the Hand

In order to score a hand it needs to be in an order Pattern Matching can work with:

```ruby
hand = Hand[unsorted_hand].sort_by_rank.cards
```

Granted we could probably add `Array`-like methods to the `Hand`, make it `Enumerable`, and add Pattern Matching hooks in it, but we just want it for sorting in this case.

### Straight and Ordered

Pattern Matching, unless I put a whole lot of cases, will not work well with checking for hands containing a straight. When you have a hammer not everything is a nail, and this is one such case, so we make a lambda function we can reuse a few times below for straight-like hands:

```ruby
is_straight = -> hand {
  hand
    .map { RANKS_SCORES[_1.rank] }
    .sort
    .each_cons(2)
    .all? { |a, b| b - a == 1 }
}
```

We want to `map` our hand into what each card's scores are for rank, we don't care about suit here. After that we want to make sure it's ordered, and get them in each consecutive group of two cards (`each_cons(2)`).

The point of doing this is we want to make sure that every pair is only one rank apart, or in other words, part of a straight.

### The Royal Flush

This gets us to the real interesting parts of this post, starting with one-liner pattern matching:

```ruby
return SCORES[:royal_flush] if hand in [
  Card[s, '10'], Card[^s, 'J'], Card[^s, 'Q'], Card[^s, 'K'], Card[^s, 'A']
]
```

A Royal Flush is the same suit with cards ascending from `10` to `A`. In this pattern match we're using `s` to capture the first suit we see, and `^s` (pin `s`) to say that we expect all the following suits to be the same.

If the first suit was a Spade, we would expect all the others to be Spades, otherwise go to the next pattern.

You might notice `Card[...]` being used here. This syntax works on **all** classes, not just Structs, to get at attributes in a pattern match. I need to experiment more with this to explain all the nuance here, but it works great for Structs in the mean time.

Stylistically I like left-to-right, hence the `return score if match` type syntax. I _could_ use multi-line pattern matching but that would get messy with this as Straight checks won't play nicely.

### The Straight Flush

The next is a bit more interesting, and represents one case where exhaustively Pattern Matching would lead to much more code than it'd save, and quite a mess. So we're using that straight check from above instead:

```ruby
return SCORES[:straight_flush] if is_straight[hand] && hand in [
  Card[s, *], Card[^s, *], Card[^s, *], Card[^s, *], Card[^s, *]
]
```

If the hand is a straight and all the suits are the same we have a winner! Same idea as above with `s` and `^s` on all the following matches to signify all the suits are the same. `*` here, on the other hand, is new. It means we don't really care about that value, leave it be.

### The Four of a Kind

For Four of a Kind we want four of the same rank of card with different suits:

```ruby
return SCORES[:four_of_a_kind] if hand in [
  *, Card[*, r], Card[*, ^r], Card[*, ^r], Card[*, ^r], *
]
```

The `r` is the same idea as `s` above, and we pin the rest to make sure it's the same rank. We don't really care about the suits because if we have four of the same card we know it'll capture all four suits as well.

You might notice `*` here is in a different spot. In this case it's a search, saying the Four of a Kind could be anywhere in the middle of our hand, or in this specific case at the front or back of the hand. That means `AAAAK` and `KAAAA` patterns are both valid.

### The Full House

This one is interesting, and presents a strange bit of code:

```ruby
return SCORES[:full_house] if hand in [
  Card[*, r1], Card[*, ^r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2]
]

return SCORES[:full_house] if hand in [
  Card[*, r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2], Card[*, ^r2]
]
```

Why two? Well first reason is we can't use named captures and pins if we use `|` for an "OR" pattern, so we have to break it into two matches.

A Full House is where there's a Three of a Kind and a Two of a Kind together. That could be `AAABB` or `AABBB`, making it two distinct patterns. In the first case we want the first three cards to be `r1` and the last two cards to be `r2`. In the next case we reverse that.

### The Flush

For a Flush we want to make sure all the cards are of the same suit:

```ruby
return SCORES[:flush] if hand in [
  Card[s, *], Card[^s, *], Card[^s, *], Card[^s, *], Card[^s, *]
]
```

Same idea as before, capture `s` and make sure the remaining card suits are all the same suit with `^s`.

### The Straight

For a Straight we want to make sure all the cards are one apart, but unlike Straight Flush and Royal Flush they're not the same suit. This is why we made that lambda function above:

```ruby
return SCORES[:straight] if is_straight[hand]
```

### The Three of a Kind

Three of a Kind is a lot like Four of a Kind, except we have three of the same rank:

```ruby
return SCORES[:three_of_a_kind] if hand in [
  *, Card[*, r], Card[*, ^r], Card[*, ^r], *
]
```

Capture and pin the rank, and use `*` to let it know that our match could be anywhere in the hand. `*` on the front and back of a pattern means "anywhere in here" as long as the defined segments are still contiguous. This means, for this hand, that `KAAAQ`, `KQAAA`, and `AAAKQ` are all valid as the Aces are all still contiguous.

### The Two Pair

The Two Pair presents a similar issue to the Full House, except there's no Three of a Kind:

```ruby
return SCORES[:two_pair] if hand in [
  *, Card[*, r1], Card[*, ^r1], Card[*, r2], Card[*, ^r2], *
]

return SCORES[:two_pair] if hand in [
  Card[*, r1], Card[*, ^r1], *, Card[*, r2], Card[*, ^r2]
]
```

We want to start by making sure we have two distinct pairs with `r1` and `r2` and their associated pins. The next trick is the second match. Who says the pairs can't be at the front and back with something else in the middle?

Granted our cards are sorted so this is a non-issue, but a fun feature to point out if you need it.

### The One Pair

That leaves us with our last check:

```ruby
return SCORES[:one_pair] if hand in [
  *, Card[*, r], Card[*, ^r], *
]
```

Same ideas as above but we only one two of the same card, and like above we don't need to know the suits of those cards.

### The High Card

Now we get to the end. If nothing else we return back High Card and let another method eventually sort out who had the highest card between players:

```ruby
SCORES[:high_card]
```

...and with that we have our scores!

## Testing and Examples

Now we just need to make sure it all works with some testing code:

```ruby
EXAMPLES = {
  royal_flush:
    RANKS.last(5).map { Card['S', _1] },

  straight_flush:
    RANKS.first(5).map { Card['S', _1] },

  four_of_a_kind:
    [CARDS[0], *SUITS.map { Card[_1, 'A'] }],

  full_house:
    SUITS.first(3).map { Card[_1, 'A'] } +
    SUITS.first(2).map { Card[_1, 'K'] },

  flush:
    (0..RANKS.size).step(2).first(5).map { Card['S', RANKS[_1]] },

  straight:
    [Card['H', RANKS.first], *RANKS[1..4].map { Card['S', _1] }],

  three_of_a_kind:
    CARDS.first(2) +
    SUITS.first(3).map { Card[_1, 'A'] },

  two_pair:
    CARDS.first(1) +
    SUITS.first(2).flat_map { [Card[_1, 'A'], Card[_1, 'K']] },

  one_pair:
    [CARDS[10], CARDS[15], CARDS[20], *SUITS.first(2).map { Card[_1, 'A'] }],

  high_card:
    [CARDS[10], CARDS[15], CARDS[20], CARDS[5], Card['S', 'A']]
}.freeze

SCORE_MAP = SCORES.invert

EXAMPLES.each do |hand_type, hand|
  score = hand_score(hand)
  correct_text = hand_type == SCORE_MAP[score] ? 'correct' : 'incorrect'

  puts <<~OUT
    Hand:  #{Hand[hand]} (#{hand_type})
    Score: #{score} (#{correct_text})
  OUT

  puts
end
```

We assemble some hands which match conditions, and in some cases fill the rest with arbitrary deterministic cards selected by which numbers I kinda liked the sound of that didn't cause the hand to match another rule.

We'll do a quick run through of the more unique parts of this.

### Numbered Params

Ruby 3 introduced numbered params:

```ruby
RANKS.last(5).map { Card['S', _1] }
```

In this case the five highest cards, all Spades. `_1` is the implied first parameter to the function.

### Splat

Splats unfold an array into a function or another collection. In this case it gives us one flat array. Sometimes I switch between this and joining arrays, and I'm not exceptionally consistent in this example area.

```ruby
[CARDS[0], *SUITS.map { Card[_1, 'A'] }]
```

### First One

`first` returns the first element, `first(n)` returns the first `n` elements in an array. There's no rule that can't be `1` to return an array of just the first element. Granted I can use this in place of splat, but again, slightly inconsistent in this code:

```ruby
CARDS.first(1) +
SUITS.first(2).flat_map { [Card[_1, 'A'], Card[_1, 'K']] }
```

### Step

I used `step` to prevent a `flush` from being a straight as well by skipping every other card:

```ruby
(0..RANKS.size).step(2).first(5).map { Card['S', RANKS[_1]] }
```

In this case by using indexes.

# Wrapping Up

This has been a pretty wild trip of a post to write, and especially in getting this code to run properly. I hope you enjoy some of the work that went into this, and that you learned a few things about pattern matching.

There are a lot of fun things in Ruby 3, take some time to explore and enjoy!
