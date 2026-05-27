---
layout: "post"
title: "Advent of Ruby 3.0 - Day 06 - Custom Customs"
series: "advent-ruby-3"
date: "2020-12-30"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

[<< Previous](/writing/2020/12/29/advent-of-ruby-3-0-day-05-binary-boarding-2m8f/) | Next >>

# [Day 06](https://adventofcode.com/2020/day/6) - Part 01 - Custom Customs

Day six was another fairly easy one. For part one we're not using anything particularly new. Our task this time is to find "yes" answers and count them, where "yes" is signified by a letter. Records are separated by a blank line, but there may be one or more response in each record separated by newlines:

```
abcx
abcy
abcz
```

In this case we have `6` unique yes answers from three people, `abcxyz`. The first part of the problem focuses on this, so let's take a look at the solution:

```ruby
puts File
  .read(ARGV[0])
  .split(/\n\n/)
  .map { _1.gsub(/\W/, '').chars.uniq.size }
  .sum
```

## `gsub` on Whitespace

The first new line we see is in the `map` function:

```ruby
.map { _1.gsub(/\W/, '').chars.uniq.size }
```

`\W` stands for any whitespace, newline or space, meaning that input above goes from this:

```
abcx
abcy
abcz
```

...to this:

```
abcxabcyabcz
```

## `uniq` Characters

The next part of this solution uses `chars`, which I believe was introduced in 2.6, to divide the String into its individual characters:

```ruby
'abcxabcyabcz'.chars
# => ["a", "b", "c", "x", "a", "b", "c", "y", "a", "b", "c", "z"]
```

After this, we want to know how many unique yes answers we have, so `uniq` is quite useful here:

```ruby
'abcxabcyabcz'.chars.uniq
# => ["a", "b", "c", "x", "y", "z"]
```

...and then all that is left is to find out how many of them there were with `size`:

```ruby
'abcxabcyabcz'.chars.uniq.size
# => 6
```

## `sum`thing to Finish

Then the last part is to get the sum of all yes answers from all of the reports, which we can do with `sum`:

```ruby
.map { _1.gsub(/\W/, '').chars.uniq.size }
.sum
```

...and the first part of our problem is done.

# Day 06 - Part 02 - This is Exhaustive

The second part makes things a bit harder: It's no longer that anyone answered yes to a question, but that _everyone_ has. That means for every person who answered we need to find answers they all answered yes to, and that means an `intersection`.

Let's take a look at the solution:

```ruby
def answer_intersection(answers) =
  answers
    .lines
    .map { _1.chomp.chars }
    .reduce(&:intersection)
    .size

puts File
  .read(ARGV[0])
  .split(/\n\n/)
  .map { answer_intersection(_1) }
  .sum
```

## `chomp` the `chars`

The first thing we want to do in our intersecting answers is to clean up the lines into a format we can use. Normally one would think just `chars` would work great, but that now means there's a newline in every single answer that counts as a definitive yes, so we want to `chomp` that off the end so it doesn't throw our count.

## `reduce` Quick Lesson

Now this, this is an incredibly succinct line doing a _lot_ of stuff. For those who don't understand `reduce` this is a trip, so let's start with a quick lesson on how it works.

Addition is the easiest reference, and before `sum` we used to do this:

```ruby
[1, 2, 3].reduce(0, :+)
# => 6
```

...which expands to this if we use the more explicit form:

```ruby
[1, 2, 3].reduce(0) { |sum, v| sum + v }
# => 6
```

`reduce` is often also called `foldLeft` in other languages, in that we're folding values to the left starting with an initial value. In this case, `0`.

Why `0`? Because it's a nice default for sums, if you add it to any number you get back that same number, and if there are no numbers you get back `0` which seems perfectly reasonable to me.

Now on to the block function, which takes two arguments `sum` and `v`.  `sum` is often called an accumulator (`a`) or memo (`m`) depending on which tutorial.

`sum`, in this case, starts with an initial value of `0` given to `reduce(0)`. `v` is an iterator, or every value in the collection we're reducing.

This particular code goes from this:

```ruby
[1, 2, 3].reduce(0) { |sum, v| sum + v }
# => 6
```

...to this if we got the effective representation:

```ruby
0 + 1 + 2 + 3
# => 6
```

Let's take a quick look at how values go through `reduce`. You see, `sum` is the result of the last iteration, and the values flowing through it would look like this:

```ruby
[1, 2, 3].reduce(0) { |sum, v|
  p(sum: sum, v: v)
  sum + v
}

# {:sum=>0, :v=>1}
# {:sum=>1, :v=>2}
# {:sum=>3, :v=>3}
# => 6
```

In the first iteration the new sum becomes `1` (`0 + 1`), the second `3` (`1 + 2`), and the last it becomes `6` (`3 + 3`) which is our final result. If we used parens it'd look something like this too:

```ruby
(((0 + 1) + 2) + 3)
```

If you want a more detailed explanation of `reduce` you should check out [Reducing Enumerable](/writing) to learn more.

## So, `intersection` then?

Let's take a look back at that code for `reduce` then:

```ruby
.reduce(&:intersection)
```

There's no initial value, which means that it'll use the first item of the collection it's reducing:

```ruby
record = [
  ['a', 'b', 'c', 'x'],
  ['a', 'b', 'c', 'y'],
  ['a', 'b', 'c', 'z']
]
```

If `reduce` intersperses `+` when done with `+` it'd do the same with `intersect`. Consider:

```ruby
a, b, c = record
a.intersection(b).intersection(c)
# => ["a", "b", "c"]
```

Granted we can use `&` which does the same thing, but I prefer more readable methods when possible.

## That's about the `size` of things

Now that we have all the intersecting answers where everyone said yes we can get how many of them there are with `size`, and in our main function we can get the `sum` of all of them to get our final answer.

# Wrapping Up Day 06

That about wraps up day six, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

[<< Previous](/writing/2020/12/29/advent-of-ruby-3-0-day-05-binary-boarding-2m8f/) | Next >>
