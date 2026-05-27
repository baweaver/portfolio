---
layout: "post"
title: "Advent of Ruby 3.0 - Day 05 - Binary Boarding"
series: "advent-ruby-3"
date: "2020-12-29"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

[<< Previous](/writing/2020/12/29/advent-of-ruby-3-0-day-04-passport-processing-389o/) | [Next >>](/writing/2020/12/30/advent-of-ruby-3-0-day-06-custom-customs-4djc/)

# [Day 05](https://adventofcode.com/2020/day/5) - Part 01 - Binary Boarding

Today chose an interesting title. Binary boarding. We should probably pay attention to that, and also the fact that there are `128`, or `2**7`, rows of seats.

Wait wait, they also want to use the first `7` characters of the boarding pass to determine which row we're in? Can't be a coincidence.

It'd be even more of a coincidence if the last three, `2^3`, somehow came up to `8`. Too bad we can't combine them or...

```
Every seat also has a unique seat ID: multiply the row by 8, then add the column. In this example, the seat has ID 44 * 8 + 5 = 357.
```

Well what do you know, it _is_ a front for a binary string!

Let's start with the solution:

```ruby
FRONT = 'F'.freeze
BACK  = 'B'.freeze
LEFT  = 'L'.freeze
RIGHT = 'R'.freeze

def find_position(pass) = pass.gsub(/./, {
  FRONT => 0,
  LEFT  => 0,
  BACK  => 1,
  RIGHT => 1
}).to_i(2)

def positions(passes) = passes.map { find_position(_1) }
def max_position(...) = positions(...).max

File.readlines(ARGV[0]).then { puts max_position(_1) }

```

## Binary? What?

The problem text mentions something interesting:

```
For example, consider just the first seven characters of FBFBBFFRLR:

Start by considering the whole range, rows 0 through 127.
F means to take the lower half, keeping rows 0 through 63.
B means to take the upper half, keeping rows 32 through 63.
F means to take the lower half, keeping rows 32 through 47.
B means to take the upper half, keeping rows 40 through 47.
B keeps rows 44 through 47.
F keeps rows 44 through 45.
The final F keeps the lower of the two, row 44.
```

Lower half and upper half, or in otherwords, on and off, `0` and `1`:

```
FBFBBFF
0101100
```

What's that translate to as a number?:

```ruby
'0101100'.to_i(2)
# => 44
```

...and back at the text:

```
The final F keeps the lower of the two, row 44.
```

Bingo. Let's take a look at the last three, `RLR`, or `'101'`:

```ruby
'101'.to_i(2)
# => 5
```

...and back to the text:

```
So, decoding FBFBBFFRLR reveals that it is the seat at row 44, column 5.
```

Another hit! So what's the multiply by `8` then? It's an offset for if you shifted the array:

```
Dec: 512  256  128  64  32  16  8  4  2  1
Bin:  0    1    0   1   1   0   0  1  0  1
Str:  F    B    F   B   B   F   F  R  L  R

256 + 64 + 32 + 4 + 1 = 357
```

So that pretty well seals it, "binary boarding" indeed!

## `gsub` takes a `Hash`?

Now we need to translate our passes into binary strings, and `gsub` has a nifty tool to make that very easy for us:

```ruby
FRONT = 'F'.freeze
BACK  = 'B'.freeze
LEFT  = 'L'.freeze
RIGHT = 'R'.freeze

def find_position(pass) = pass.gsub(/./, {
  FRONT => 0,
  LEFT  => 0,
  BACK  => 1,
  RIGHT => 1
}).to_i(2)
```

We're matching against every character with `/./`, and the `Hash` we pass to it is our translation table. We're using constants to make it a bit more readable, but otherwise we just want to translate front and left to `0` and back and right to `1`.

Once we're done with that we can use `to_i(2)` to turn it into an integer. The `2` is the radix, or base, we're translating to. Defaultly it's `10`, or decimal. You could use some other common ones too like octal or hex, but binary is what's relevant for this one.

## Positions Everyone

Now we just need to get the counts and we're good to go:

```ruby
def positions(passes) = passes.map { find_position(_1) }
def max_position(...) = positions(...).max

File.readlines(ARGV[0]).then { puts max_position(_1) }
```

The first function extracts the positions of each pass, and the second wraps that with the concept of getting the highest numbered ticket. After that we're done and we have our solution.

# Day 05 - Part 02 - This is Exhaustive

Part two isn't that bad, we just have to find out where the empty spot is within a certain range of spots. Since the first and last rows are gone we need to find the upper and lower bounds before locating our seat.

Let's start with the solution:

```ruby
FRONT = 'F'.freeze
BACK  = 'B'.freeze
LEFT  = 'L'.freeze
RIGHT = 'R'.freeze

def find_position(pass) = pass.gsub(/./, {
  FRONT => 0,
  LEFT  => 0,
  BACK  => 1,
  RIGHT => 1
}).to_i(2)

def positions(passes) = passes.map { find_position(_1) }

def minmax_position(passes)
  all_positions    = positions(passes)
  min_pos, max_pos = all_positions.minmax

  (min_pos..max_pos).to_a - all_positions
end

File.readlines(ARGV[0]).then { puts minmax_position(_1) }

```

## `minmax`ing to Find Rows

The rest of the function leading up to `minimal_position` remains the same, but now we need to find the upper and lower bounds of possible seats. Last time we only needed the max, but now we need both.

Ruby has `minmax` for this which returns an array pair of the minimum and maximum value in a collection.

From there we can enumerate all the possible seats, `(min_pos..max_pos).to_a`, subtract the known positions, and get our seat:

```ruby
(min_pos..max_pos).to_a - all_positions
```

Now is there a more efficient way to do this? Probably, using `Set` or `Range#contain?`, but we'll leave that up to the reader as an exercise to experiment with.

# Wrapping Up Day 05

That about wraps up day five, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

[<< Previous](/writing/2020/12/29/advent-of-ruby-3-0-day-04-passport-processing-389o/) | [Next >>](/writing/2020/12/30/advent-of-ruby-3-0-day-06-custom-customs-4djc/)
