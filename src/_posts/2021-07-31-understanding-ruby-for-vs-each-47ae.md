---
layout: "post"
title: "Understanding Ruby - For vs Each"
series: "understanding-ruby"
date: "2021-07-31"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional"]
description: "Introduction   For those coming from other languages with for loops the concept of each,..."
---

## Introduction

For those coming from other languages with `for` loops the concept of `each`, anonymous functions, blocks, and all of those new terms feels very foreign.

Why is it that Ruby doesn't use `for` loops? Well we're going to cover that one today.

### Difficulty

Foundational

Some knowledge required of functions in Ruby. This post focuses on foundational and fundamental knowledge for Ruby programmers.

### Prerequisite Reading:

None

Suggested to read [Understanding Ruby - Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/) after this article if you haven't already.

## For vs Each – High Level Overview

### Ruby does have a `for` loop

Let's start with an acknowledgement: Ruby _does_ have a `for` loop:

```ruby
for item in [1, 2, 3]
  puts item + 1
end
# 2
# 3
# 4
```

...but you're not going to see it in common use. You're going to see `each` far more frequently.

### Introducing `each`

`each` in Ruby is the de facto way of iterating through a collection:

```ruby
[1, 2, 3].each do |item|
  puts item + 1
end
# 2
# 3
# 4
```

There are a few things here which may not be familiar, which are covered in more detail in [that article mentioned above](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/), but for now the important parts:

`do ... end` starts what we call a block function, or anonymous function in other languages, and `|item|` represents the arguments to that function. For each iteration of the loop each item will be fed into that function as an argument.

Ruby uses blocks _heavily_, and you'll find them commonly both in reading and writing code in the language. Their usage goes far beyond `each`, and we'll mention that in a bit, but first let's cover a few concerns about `for` in Ruby.

## Concerns with For

There are more than a few legitimate issues with `for` loops in Ruby, and we'll quickly cover a few of them.

### They're Implemented with Each

Yep. The `for` loop in Ruby is using `each` behind the scenes, so even if you're not using it you're still using it. That also means that it's slower:

```ruby
require 'benchmark/ips'
# => true

collection = (1..100).to_a
# => [1, 2, 3, 4, 5, 6, 7, 8, 9, ...

Benchmark.ips do |bench|
  bench.report("for loop") do
    sum = 0
    for item in collection
      sum += item
    end
    sum
  end

  bench.report("each loop") do
    sum = 0
    collection.each do |item|
      sum += item
    end
    sum
  end
end

# Warming up --------------------------------------
#             for loop    22.017k i/100ms
#            each loop    23.543k i/100ms
# Calculating -------------------------------------
#             for loop    218.466k (± 2.6%) i/s - 1.101M in 5.042495s
#            each loop    231.274k (± 2.1%) i/s - 1.177M in 5.092110s
```

Granted this is not a _significant_ difference, but it is something to keep in mind.

### Shadowing and Scoping

`for` loops leak variables into their outer scope:

```ruby
for item in collection
  sum ||= 0
  sum += item
end

item
# => 100

sum
# => 5050
```

That means if the code around it has an `item` it'll be overwritten. Same with `sum`. Contrast with `each` here:

```ruby
collection.each do |item2|
  sum2 ||= 0
  sum2 += item2
end

item2
# => nil

sum2
# NameError (undefined local variable or method `sum2' for main:Object)
```

We'll get into that in a moment, but for this moment know that block functions are isolated in that outside code cannot see inside of them, but they can certainly see outside code around them.

## The Case for Each

So why would one want to use anonymous functions, `each`, and related methods in Ruby rather than a `for` loop? This section will look into that.

### Closures

Going back to the above section, let's clarify what we mean by what the function can "see" or "not see".

A block function is what's called a closure, meaning it captures the outside context (think variables) inside the function, but the outside code cannot see inside, hence `sum2` being undefined here. Believe it or not that's quite useful later on, but has been known as a stumbling block to some.

Consider this code:

```ruby
sum = 0
[1, 2, 3].each do |item|
  sum += item
end

sum
# => 6
```

We can "see" `sum` as it's in the context of the block function, or what's immediately around it when it runs. This can be really useful for more advanced code, as that means functions effectively have memory, and in Ruby you can even redefine where it finds its memory by changing its context, but that's considerably more advanced.

The outside code, however, cannot see `item` as it's only visible inside the block function. This can present some headaches, and early on in my Ruby career this confused me to no end:

```ruby
require 'net/ssh'

# Don't actually use passwords if you do this, use keys
Net::SSH.start('hostname', 'username', password: 'password') do |ssh|
  config = ssh.exec! "cat /tmp/running.cfg"
end

defined?(config)
# => nil
```

For those cases I used global variables back then, which I would not recommend, instead prefer this pattern:

```ruby
config = nil

# Don't actually use passwords if you do this, use keys
Net::SSH.start('hostname', 'username', password: 'password') do |ssh|
  config = ssh.exec! "cat /tmp/running.cfg"
end

defined?(config)
# => local-variable
```

...or if you read the `Net::SSH` docs you might find that the block isn't even entirely necessary for this and get around the issue entirely. Anyways, point being there are some traps there potentially for the unaware, so be careful on what isolated block function scopes mean.

### Enumerable

Ruby has a collections library called `Enumerable` which is one of the most powerful features of the language.

Let's say I wanted to get the sum of every even number greater than 4 in a collection, but double them as well. With a for loop that might look like this:

```ruby
sum = 0
for item in 1..100
  sum += item * 2 if item > 4 && item.even?
end

sum
# => 5088
```

Using `Enumerable` we can express each one of those conditions as a distinct transformation or filtering of the list:

```ruby
(1..100).select { |v| v.even? && v > 4 }.map { |v| v * 2 }.sum
# => 5088
```

It gives us more flexibility in expressing multiple actions we want to take against a collection as distinct pieces rather than combining them all as one.

Some of those, you'll find, can be exceptionally useful beyond the trivial, like a count of what letters words start with in some text:

```ruby
words = %w(the rain in spain stays mainly on the plane)
words.map { |w| w[0] }.tally
# => {"t"=>2, "r"=>1, "i"=>1, "s"=>2, "m"=>1, "o"=>1, "p"=>1}
```

...or grouping a collection:

```ruby
words.group_by { |w| w.size }
# => {3=>["the", "the"], 4=>["rain"], 2=>["in", "on"], 5=>["spain", "stays", "plane"], 6=>["mainly"]}
```

The flexibility there is really something, and because these can all be chained together you can easily break them out into separate functions and refactor out entire parts of the chain altogether if you need to.

### Down the Rabbit Hole

Now there are a lot of things I could get into on where this can go and the implications, but as this is a more beginner friendly article that would not be very kind, so we'll instead hint at a few of them:

* Block functions can have their entire context changed
* A lot of Enumerable-like functions can be parallelizeable as they're functionally pure
* Closures keep context, meaning you have memory to do some real fun things
* Many Ruby classes, including your own, can be coerced into functions
* A significant number of programming patterns are made much easier by the presence of functions

...and a lot more than I have time for in this particular article, but I would highly encourage you to read into the more advanced article on the types of functions in Ruby:

[Understanding Ruby - Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/)

## Wrapping Up

This article is a very high level overview, and does definitely wave over some details I could get into. Be sure to read other parts of the series if you want to get more into the weeds on this, as there's a lot of fascinating detail there.

The intent of this article is for those coming from languages which primarily use `for` loops rather than iterables or enumerable, depending on the way you describe them. That said, most all languages including Java have a Streaming type library which does something very close to this.

If you really want to get into the power of block functions and why that's significant be sure to watch out for future posts on functional programming, but until then that's all I have for today.
