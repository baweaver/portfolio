---
layout: "post"
title: "Advent of Ruby 3.0 - Day 01 - Report Repair"
series: "advent-ruby-3"
date: "2020-12-27"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

~~<< Previous~~ | [Next >>](/writing/2020/12/27/advent-of-ruby-3-0-day-02-password-philosophy-3hg/)

# Day 00 - Runner Script

Didn't think you'd see Bash in a Ruby post, now did you? Well here we are.

[I'm using this script](https://github.com/baweaver/advent_of_code_2020/blob/main/run) to quickly run every days code, and like all good Bash it's a bit hacky and scary:

```bash
#!/bin/bash

# Ha, here we are using Bash.

# Find something which starts with the number. I name the actual
# scripts decently, this not so much
matching=`find . -type f -name "$1_*.rb" | head -n 1`

# Then peel the extension off of it
name=`basename $matching .rb`

# ...and throw it to Ruby, with the input from the inputs dir with the same
# name, except a txt extension
ruby ./"$name".rb ./inputs/"$name".txt
```

Inputs are in `./inputs` and are `txt` files, named the same as the Ruby output. Granted I could clean that up, but the point of this is to see Ruby, so let's get back to that.

# [Day 01](https://adventofcode.com/2020/day/1) - Report Repair

For our first problem we're going to need to find two numbers in an input file that sum up to `2020`.

[See the full solution here on Github.](https://github.com/baweaver/advent_of_code_2020/blob/main/01_report_repair.rb)

## Dual Numbers Mapping

The most common solution to this type of problem is to create a mapping (`Hash`) of values where each value is paired with the one it needs to hit `2020`:

```ruby
TARGET = 2020

n = 1500

duals = {}
duals[TARGET - n] = n
# => { 520 => 1500 }
```

Why in that order? Because whenever the next number comes around we can ask something like this:

```ruby
n = 520
duals[n]
# => 1500
```

Since it has a dual number we know we have our answer and can break out early. The full implementation of this idea looks a bit like this:

```ruby
# Give a name to the idea of not finding a number,
# but make it compatible with the output functions
# to not crash on error
NOT_FOUND = [-1, -1]

def duals(input, target: 2020)
  # Transform our input into ints, and bring along a hash for the ride
  input.map(&:to_i).each_with_object({}) do |v, duals|
    # If we find a dual number, return it and `v`, we have
    # our answer
    return [v, duals[v]] if duals[v]

    # Otherwise set the target so we can find it next
    # time around
    duals[target - v] = v
  end

  # Otherwise we return back our idea of "not found"
  NOT_FOUND
end
```

## Endless Methods as a Wrapper

The problem is we also need to get the product of those two numbers. While we _could_ do this in the `duals` function it conflates it with additional functionality. We might also want to actually see the two numbers or get them directly instead of the product, so that function should stand on its own.

What if we wrapped it in another function to give us the product? Ruby 3.0 introduced **endless methods** which work great for just this type of thing:

```ruby
def dual_product(input) = duals(input).reduce(1, :*)
```

> Why the `1` with `reduce`? Well if we have an empty array we want a sane return value. For addition that value is `0` as you can add any number to it and get back that same number. Same idea with `1` and multiplication here.
>
> Granted this concept has a name, identity or empty, but that's the subject of another post.

This allows us to quickly wrap the idea of multiplying the two inputs together without compromising on the clarity of the `duals` function. That said, I don't like typing that argument twice, and Ruby 3.0 has a feature for that.

## Argument Forwarding

Ruby 3.0 introduced argument forwarding, `...`, to do something just like this:

```ruby
def product_duals(...) = duals(...).reduce(1, :*)
```

It means to forward all arguments to the next function. Granted I have some qualms with this as this is invalid:

```ruby
def product_duals(input) = duals(...).reduce(1, :*)
# SyntaxError ((irb):22: unexpected ...)
```

...and I think it should be, otherwise you can't specify what arguments the function takes explicitly and it can only serve as a pass-through. This is likely a bug report for later, I'll see about linking to it once I find or create one.

That brings us to our next section, we need to get the input.

## Then we had Numbered Parameters

In my scripts I'm using `ARGV[0]` for the name of a text file with input from Advent of Code:

```ruby
File.readlines(ARGV[0]).then { puts product_duals(_1) }
```

The first thing this is doing is taking a command line argument, `ARGV[0]`, which will be our input file. We use `File.readlines` to get an `Array` of all the lines in the file, and we pipe it to an interesting function called `then`.

`then` was introduced in Ruby 2.6 as an alias for `yield_self`, and can be thought of as the inverse of `tap`:

```ruby
1.tap { |v| v + 1 }
# => 1

1.then { |v| v + 1 }
# => 2
```

`tap` returns the original object while `then` returns the result of the block. While we _could_ just wrap the `File.readlines` with `product_duals` it doesn't read as cleanly left-to-right. Granted we could also use `tap` and `then` interchangeably here as we don't care about the output.

You'll also notice `_1` here. This is a numbered parameter, and is the implied first argument to the block. It then follows you could use `_2` and `_3` and so on for more, but you'll rarely get much past that.

In this case we're just pipelining the file input into our function:

```ruby
then { puts product_duals(_1) }
```

...and outputting it back to `STDOUT`, command-line script and all, it kinda needs that to give us an answer.

# Wrapping Up Day 01

That about wraps up day one, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

~~<< Previous~~ | [Next >>](/writing/2020/12/27/advent-of-ruby-3-0-day-02-password-philosophy-3hg/)
