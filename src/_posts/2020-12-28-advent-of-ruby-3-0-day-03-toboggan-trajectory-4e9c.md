---
layout: "post"
title: "Advent of Ruby 3.0 - Day 03 - Toboggan Trajectory"
series: "advent-ruby-3"
date: "2020-12-28"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

[<< Previous](/writing/2020/12/27/advent-of-ruby-3-0-day-02-password-philosophy-3hg/) | [Next >>](/writing/2020/12/29/advent-of-ruby-3-0-day-04-passport-processing-389o/)

# [Day 03](https://adventofcode.com/2020/day/3) - Part 01 - Toboggan Trajectory

This one took a bit to understand for me. There are trees (`#`) and empty spaces (`.`) on our map:

```
..#..#
..#..#
.#..#.
```

Our toboggan is to start in the top left, and for the first part it has a slope of `1` over `3`, or `1` in the `y` direction and `3` in the `x` direction. Given `X` as a tree collision and `O` as an empty space we can see our sled going down the slope:

```
O.#..#
..X..#
.#..#O
```

In this case we hit one tree, but what if we go out of bounds? It looks like their maps repeat infinitely, so if a line was `..#` for instance it would repeat, so something like `..#..#..#..#` and so forth.

Let's start with the solution and dive in from there:

```ruby
SLOPE = [3, 1]
SLOPE_X, SLOPE_Y = SLOPE

TREE = '#'

def collision_count(map, slope_x: SLOPE_X, slope_y: SLOPE_Y)
  map_modulo = map.first.strip.size
  pos_x, pos_y = 0, 0

  map[1..-1].reduce(0) do |trees_hit, line|
    pos_x, pos_y = pos_x + slope_x, pos_y + slope_y
    relative_x   = pos_x % map_modulo

    line[relative_x] == TREE ? trees_hit + 1 : trees_hit
  end
end

File.readlines(ARGV[0]).then { puts collision_count(_1) }
```

## Constants

The first few lines are just setting up some constants for defaults and giving names to values we're going to be using later:

```ruby
SLOPE = [3, 1]
SLOPE_X, SLOPE_Y = SLOPE

TREE = '#'
```

This line in-particular is a slight habit of mine, using constants with kwargs for well named defaults:

```ruby
def collision_count(map, slope_x: SLOPE_X, slope_y: SLOPE_Y)
```

Making it to where you _can_ configure them, but they have sane named defaults otherwise. In this case the slope is constant, but may not be in the future, leaving us able to adapt if needed.

## Modulo

Math is definitely our friend for this one with the modulo function. For those unfamiliar modulo gives you the remainder after division, so:

```ruby
10 % 10 == 0
10 % 15 == 5
10 % 25 == 5
```

Why isn't `25` giving us `15`? Because `10` can divide into it cleanly twice, leaving `5` left over just like `15`.

This is very useful for looping back around and cycling a series, in this case a map that extends infinitely to the right. That's why this line comes in real handy to tell us where that break is:

```ruby
map_modulo = map.first.strip.size
```

## Reducto ad Toboggan

Let's take a look at this reduction, it'll have some interesting insights for us later:

```ruby
pos_x, pos_y = 0, 0

map[1..-1].reduce(0) do |trees_hit, line|
  pos_x, pos_y = pos_x + slope_x, pos_y + slope_y
  relative_x   = pos_x % map_modulo

  line[relative_x] == TREE ? trees_hit + 1 : trees_hit
end
```

The first thing is you'll notice `map[1..-1]`, and this is because the first line is irrelevant to us as the toboggan is always starting on a clean spot according to the problem.

We're using `reduce` here with an initial value of `0` to accumulate the total count of trees we've had an unfortunate encounter with:

```ruby
map[1..-1].reduce(0) do |trees_hit, line|
```

The first thing we need to know is what our position is. On line one above we set `x` and `y` to `0` as our starting position. This line updates them according to the slope:

```ruby
pos_x, pos_y = pos_x + slope_x, pos_y + slope_y
```

We're not really using the `y` position, but I'd be willing to bet it comes up later so we may as well update it as well according to the scope.

Now the real question for this part is where we are on the infinite map. Remember modulo? We can use that to get our relative position on the known map in front of us:

```ruby
relative_x = pos_x % map_modulo
```

So if we're off at `x` of `30` and the map is only `12` units long we know our relative `x` is `6`, or `30 % 12`.

Once we know where we are relative to the map, we can ask if there's a tree there:

```ruby
line[relative_x] == TREE
```

If there is, we add one to our counts, or we return the current counts and check the next line:

```ruby
line[relative_x] == TREE ? trees_hit + 1 : trees_hit
```

## Our Old Friend

That just leaves a very similar line left:

```ruby
File.readlines(ARGV[0]).then { puts collision_count(_1) }
```

...and we have our solution.

# Day 03 - Part 02 - What's Your Angle?

Like we were worried about above, the slope can change, including the slope of `y` which means simply iterating isn't going to work any more. Never fear though, because Ruby has some interesting tricks to make this a fairly easy problem.

## Step by Step

Since we can't iterate cleanly we have to find another solution.

...or do we? What if Ruby had a special tool just for this type of case? It's called `step`, or the newer `%` operator for ranges:

```ruby
(1..10).step(3).to_a
# => [1, 4, 7, 10]

((1..10) % 3).to_a
# => [1, 4, 7, 10]
```

Just be careful not to do this, because `%`'s precedence beats `..` for ranges:

```ruby
(1..10 % 3).to_a
# => [1]
```

...because `10 % 3` is `1`, making the range now `1..1`.

Anyways, I tend to prefer `step` because it's clearer, but it's nice to know that exists.

Given all this we can change our `map` range to this and we can account for `y` being greater than `1`:

```ruby
map[(slope_y..map.size) % slope_y]
```

## Put Together

Ruby made this one fairly easy, the only real change to our main function made it look like this instead:

```ruby
def collision_count(map, slope_x: SLOPE_X, slope_y: SLOPE_Y)
  map_modulo   = map.first.strip.size
  pos_x, pos_y = 0, 0

  map[(slope_y..map.size) % slope_y].reduce(0) do |trees_hit, line|
    pos_x, pos_y = pos_x + slope_x, pos_y + slope_y
    relative_x   = pos_x % map_modulo

    line[relative_x] == TREE ? trees_hit + 1 : trees_hit
  end
end
```

Only the fifth line ended up being changed, that's pretty awesome!

## Feeding the Input

The only other difference is that we changed our readline a bit:

```ruby
POSITIONS = [
  { slope_x: 1, slope_y: 1 },
  { slope_x: 3, slope_y: 1 },
  { slope_x: 5, slope_y: 1 },
  { slope_x: 7, slope_y: 1 },
  { slope_x: 1, slope_y: 2 }
]

File.readlines(ARGV[0]).then do |map|
  puts POSITIONS
    .map { |pos| collision_count(map, **pos) }
    .reduce(1, :*)
end
```

We just give the list of position adjustments, map over them to get how many trees we've managed to hit, and multiply them all together as per the program specifications on AoC.

Now we have part one and two done!

# Day 03 - Bonus Musings on Parallelism and Monoids

But there's an interesting pattern here. Consider addition:

1. If you add two numbers, you get a number
2. If you add `0` to any number you get that number
3. You can freely group numbers to add  and get the same result: `a + b + c == (a + b) + c == a + (b + c)`
4. You can undo any operation with an inversion, like `1 + -1` would undo adding `1`
5. Heck, you can add them in _any_ order and they still work: `1 + 2 + 3 == 2 + 3 + 1 == 3 + 2 + 1`

Those properties are known as rules. Anything that adheres to the first three rules is called a Monoid (or a reducible, or in the manner of one thing), if you add the fourth you get a Group, and if you add the fifth you get an Abelian Group.

[Wikipedia covers some of this](https://en.wikipedia.org/wiki/Abelian_group), but for now we'll delight in the fact that addition is an Abelian or Commutative group because that means parallelism is _really_ easy to implement.

## `x` can be derived from `y` and `slope_x`

We can get the relative `x` position with just our `y` position and the slope:

```ruby
map_boundary = map_line.size - 1
position = (y * slope_x) % map_boundary
```

That means we don't have to iterate them strictly in order to find what we need.

### Finding Total Tree Hits is Integer Addition

You either hit a tree, which gives `+ 1`, or you didn't which gives you back an empty `0`. That means that each parallel thread running can find out if a line gives back `1` or `0` and add that to the running total on the main thread.

So why care about that Abelian Group thing? Since tree hits follows that pattern that means that we could potentially do something like this (psuedo code):

```ruby
CPU_COUNT = 16
TREE = '#'.freeze

workers = 16.times.map do
  # This is NOT valid syntax inside the ractor, will test
  # later once I can talk to some folks
  Ractor.new do
    loop do
      # For instance this will work, but...
      Ractor.receive => { y:, slope_x:, map_line: }
      
      # This will complain about non-local references
      # even though they're local variables
      map_boundary = map_line.size - 1
      position = (y * slope_x) % map_boundary
      
      # Then this will be annoyed at `TREE` being
      # non-local despite freezing
      Ractor.yield map_line[position] == TREE ? 1 : 0
    end
  end
end

# Ractor pipe, need to figure out syntax, reading
# through articles but rather hard to follow
worker_queue = nil

# The idea is to send lines to whatever worker, wait
# for eventual return, and sum those all up once all
# lines are processed.
map.lines.map { |line| worker_queue.send(line) }.sum
```

You could even shuffle the lines, it wouldn't matter as long as we know the slope and positions. Part two would complicate this a bit, sure, but not much.

Heck, with `Ractor` you could theoretically just keep supplying infinite lines to it and it'd keep going.

There's a lot of potential here, but potential that's currently a bit over my head to interpret, so I'll keep playing with that and let you all know how it hopefully works out.

Have an idea or know what'd make it work? Shoot me a DM on Twitter @keystonelemur, I'd love to chat.

# Wrapping Up Day 03

That about wraps up day three, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

[<< Previous](/writing/2020/12/27/advent-of-ruby-3-0-day-02-password-philosophy-3hg/) | [Next >>](/writing/2020/12/29/advent-of-ruby-3-0-day-04-passport-processing-389o/)
