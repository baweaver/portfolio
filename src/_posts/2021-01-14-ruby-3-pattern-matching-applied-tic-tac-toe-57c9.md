---
layout: "post"
title: "Ruby 3 Pattern Matching Applied: Tic-Tac-Toe"
date: "2021-01-14"
categories: ["ruby", "ruby3"]
tags: ["ruby", "ruby3", "patternmatching"]
description: "Pattern Matching in Ruby 2.7 and 3.0 can be an odd concept to read about, and an even stranger one to know how to use. This is another use case, this time to solve a Tic-Tac-Toe game"
---

Ruby 3.0 introduced Pattern Matching as a key feature, but if you're like a lot of folks you may not entirely be sure what it's used for or why you might want it.

This article is going to go over just that and show you how to use Pattern Matching to check for a winning Tic-Tac-Toe board!

# The Program

Let's start out by looking at the entirety of the script. We'll be walking through each part of it here in a moment, but make sure to note parts that are confusing as you give it a read, and see if you can figure out what it's doing:

```ruby
MOVE = /[XO]/.freeze

def board(*rows) = rows.map(&:chars)

def winner(board)
  case board
  in [
    [MOVE => move, ^move, ^move],
    [_, _, _],
    [_, _, _]
  ]
    [:horizontal, move]
  in [
    [_, _, _],
    [MOVE => move, ^move, ^move],
    [_, _, _]
  ]
    [:horizontal, move]
  in [
    [_, _, _],
    [_, _, _],
    [MOVE => move, ^move, ^move]
  ]
    [:horizontal, move]
  in [
    [MOVE => move, _, _],
    [^move, _, _],
    [^move, _, _]
  ]
    [:vertical, move]
  in [
    [_, MOVE => move, _],
    [_, ^move, _],
    [_, ^move, _]
  ]
    [:vertical, move]
  in [
    [_, _, MOVE => move],
    [_, _, ^move],
    [_, _, ^move]
  ]
    [:vertical, move]
  in [
    [MOVE => move, _, _],
    [_, ^move, _],
    [_, _, ^move]
  ]
    [:diagonal, move]
  in [
    [_, _, MOVE => move],
    [_, ^move, _],
    [^move, _, _]
  ]
    [:diagonal, move]
  else
    [:none, false]
  end
end

EXAMPLES = {
  straights: [
    # Win
    board('XXX', '   ', '   '),
    board('   ', 'OOO', '   '),
    board('   ', '   ', 'XXX'),

    # No Win
    board('X X', '   ', '   '),
    board('   ', 'O O', '   '),
    board('   ', '   ', 'X X'),
  ],

  verticals: [
    # Win
    board('X  ', 'X  ', 'X  '),
    board(' O ', ' O ', ' O '),
    board('  X', '  X', '  X'),

    # No Win
    board('   ', 'X  ', 'X  '),
    board(' O ', '   ', ' O '),
    board('  X', '  X', '   '),
  ],

  diagonals: [
    # Win
    board('O  ', ' O ', '  O'),
    board('  X', ' X ', 'X  '),

    # No Win
    board('O  ', ' O ', '   '),
    board('  X', ' X ', '   '),
  ]
}

EXAMPLES.each do |type, boards|
  boards.each do |board|
    puts "type: #{type}, win: #{winner(board)}"
  end
end
```

It's a lot to take in at once, and if you don't understand all of it that's perfectly ok: that's what the rest of this article is for.

Shall we start digging in then?

# The Explanation

## Regex for Moves

The first part of the program is giving us a Regex that matches either an `X` or an `O`, the two possible moves:

```ruby
MOVE = /[XO]/.freeze
```

`freeze` because Constants should be frozen, otherwise they're not really constant now are they?

## Board

We're going to use a bit of a simplified way to derive a board:

```ruby
def board(*rows) = rows.map(&:chars)
```

Using this each row is a string of moves:

```ruby
board('XXX', '   ', 'OO ')
```

> While we could make this into a nice class with a `to_s` for display and all the trimmings that's not the point of this article. If you want a fun challenge send me your idea for a `Board` class on Twitter to [@keystonelemur](https://twitter.com/keystonelemur).

This code will give us back a 2D array:

```ruby
[
  ['X', 'X', 'X'],
  [' ', ' ', ' '],
  ['O', 'O', ' ']
]
```

...which looks like a much more compelling board, but with my habit of testing things in a REPL (Read-Eval-Print-Loop) like IRB or Pry this is much faster to experiment with.

## Finding a Winner

This is where we get into the interesting part of the program. There are a ton of ways to solve for Tic-Tac-Toe, but Pattern Matching gives us a new and novel way to look at the problem.

### Horizontal Wins

Let's start with the series of horizontal wins:

```ruby
case board
in [
  [MOVE => move, ^move, ^move],
  [_, _, _],
  [_, _, _]
]
  [:horizontal, move]
in [
  [_, _, _],
  [MOVE => move, ^move, ^move],
  [_, _, _]
]
  [:horizontal, move]
in [
  [_, _, _],
  [_, _, _],
  [MOVE => move, ^move, ^move]
]
  [:horizontal, move]
```

There are two distinct styles of lines here. The first serves to say any value could be here:

```ruby
[_, _, _]
```

The second is more interesting:

```ruby
[MOVE => move, ^move, ^move]
```

It's using our Regex above to see if the move (or lack thereof) in that position is a valid move. If it is, it assigns that value to `move` using `=>` (rightward assign) which is common in Pattern Matching.

> You might also be wondering why Regex works here. That's because _every value in a Pattern Match is compared with `===`_. That's a big deal, and I would suggest reading into just [how much power is behind the triple equal operator here](/writing/2017/10/16/triple-equals-black-magic/). It'll come handy later, trust me on that one.

After this we use `^move` to recall that value and say the next two values on that same horizontal row should be the same value. If the first value we saw was `X` then this would expect the next two to be the same.

With those set, if it matches we get to our return value:

```ruby
[:horizontal, move]
```

Since `move` was put into the pattern we have access to it inside the branch, so we can return the winning player. In this particular case I also want to know how they won, hence returning a tuple-like `Array` pair with the winning strategy as the first element.

### Vertical Wins

Vertical wins look quite the same as horizontal ones, except we're going by vertical columns now:

```ruby
in [
  [MOVE => move, _, _],
  [^move, _, _],
  [^move, _, _]
]
  [:vertical, move]
in [
  [_, MOVE => move, _],
  [_, ^move, _],
  [_, ^move, _]
]
  [:vertical, move]
in [
  [_, _, MOVE => move],
  [_, _, ^move],
  [_, _, ^move]
]
  [:vertical, move]
```

As with the first example we want the first capture of a valid move to assign `move`, and then we want to use the pinned move `^move` to make sure the next two column values are the same.

The only other difference here is we're now returning `[:vertical, move]` to signify this was a vertical move.

### Diagonal Wins

These are a bit stranger, but still the same concepts apply:

```ruby
in [
  [MOVE => move, _, _],
  [_, ^move, _],
  [_, _, ^move]
]
  [:diagonal, move]
in [
  [_, _, MOVE => move],
  [_, ^move, _],
  [^move, _, _]
]
  [:diagonal, move]
```

We want to see if there are diagonal values with the same move, and in this case we return `:diagonal` as the winning strategy. Granted these are hard to read, and I'm always torn on extra spacing in these arrays, but we'll leave it be for this one.

### No Wins

Pattern Matching in Ruby is expected to be exhaustive, that means we need an `else` case to capture anything else. In this case, any non-winning boards:

```ruby
else
  [:none, false]
end
```

Now we're returning `:none` to signify no winning strategy was found, and `false` for the move.

If we left this `else` off we would get exceptions on any non-winning board which would not be ideal.

## Examples

The examples, in this article, are much simpler than the Poker ones to read:

```ruby
EXAMPLES = {
  straights: [
    # Win
    board('XXX', '   ', '   '),
    board('   ', 'OOO', '   '),
    board('   ', '   ', 'XXX'),

    # No Win
    board('X X', '   ', '   '),
    board('   ', 'O O', '   '),
    board('   ', '   ', 'X X'),
  ],

  verticals: [
    # Win
    board('X  ', 'X  ', 'X  '),
    board(' O ', ' O ', ' O '),
    board('  X', '  X', '  X'),

    # No Win
    board('   ', 'X  ', 'X  '),
    board(' O ', '   ', ' O '),
    board('  X', '  X', '   '),
  ],

  diagonals: [
    # Win
    board('O  ', ' O ', '  O'),
    board('  X', ' X ', 'X  '),

    # No Win
    board('O  ', ' O ', '   '),
    board('  X', ' X ', '   '),
  ]
}
```

We want to enumerate a few winning and losing conditions to vet our code. Now normally you might want to use RSpec or another testing tool for this, but the point is to show Pattern Matching, not go on a deep dive on testing.

> ...but if that's of interest, leave a comment and I can walk through how we'd test code like this with tools like RSpec.

The big thing here is we want some negative cases to ensure we're not missing a few edge-cases.

After that we run all of our examples and see what we got:

```ruby
EXAMPLES.each do |type, boards|
  boards.each do |board|
    puts "type: #{type}, win: #{winner(board)}"
  end
end
```

...which brings us right up to the end.

# Wrapping Up

Tic-Tac-Toe is a substantially easier to solve for problem than Poker, and demonstrates some of the range of Pattern Matching in Ruby 3. Hopefully this has been a fun and educational read, let me know if there are any other subjects you'd like to see covered.

There are a lot of fun things in Ruby 3, take some time to explore and enjoy!
