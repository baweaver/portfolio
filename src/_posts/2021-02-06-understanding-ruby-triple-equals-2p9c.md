---
layout: "post"
title: "Understanding Ruby - Triple Equals"
series: "understanding-ruby"
date: "2021-02-06"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional"]
description: "Introduction   Triple Equals (===) in Ruby is one of the most powerful features in the entir..."
---

# Introduction

Triple Equals (`===`) in Ruby is one of the most powerful features in the entire language, but also one you may not know you're using either. In fact, it's one of the best kept secrets!

We're going to learn a bit about those secrets today and explore `===`, how it's defined, what it does, and where it's hiding in your Ruby code today.

> **Note**: This is a rewrite and expansion on an older post of mine from 2017, [Triple Equals Black Magic](/writing/2017/10/16/triple-equals-black-magic/), and includes updated syntax including Pattern Matching to examples.

## Difficulty

**Foundational**

No prerequisite knowledge needed. This post focuses on foundational and fundamental knowledge for Ruby programmers.

# Triple Equals

So what is it? How is it defined?

Some coming from Javascript might have the notion that `===` is a stricter equality operator than `==`, but in Ruby it does something quite different. Defaultly it's an alias for `==`, but some classes do something much more interesting.

It goes by a few names: Case equality operator, membership operator, triple equals.

Its function is very much akin to checking to see if the value on the right is a member of whatever is on the left. 

## How it's Implemented in Ruby

What do I mean by that? Well let's take a look at a few classes real quick to see how it works.

> **WARNING**: Do not use `===` explicitly like this in code, prefer methods with clearer names. We'll see soon when it's acutally used, and often times in an implicit manner rather than explicitly using it.

### Ranges

A range in Ruby has a starting point and an ending point, like `1..10` is a range from `1` to `10`. For it `===` works like `include?` which checks if the value on the right happens to be included within the range, or a member of the range:

```ruby
(1..10) === 1
# => true

(1..10).include?(1)
# => true
```

Ranges are interesting in that they're not limited to numbers. Strings also work, and that makes range inclusion even more interesting:

```ruby
SUPPORTS_PATTERN_MATCH_VERSIONS = '2.7.0'..'3.0.0'
SUPPORTS_PATTERN_MATCH_VERSIONS === '2.7.5'
# => true
```

Granted that example breaks once Ruby goes beyond `3.0.0`, but the point is range also recognizes types beyond Integer, and sometimes in interesting ways, but that's the subject for another post.

### Regular Expressions

Regular Expressions are a language for matching against patterns in text, and for `===` it happens to work very much like `match?`:

```ruby
/abc/ === 'abcdef'
# => true

/abc/.match?('abcdef')
# => true
```

`===` in this case is saying that there's a match, or that our string is a member of the set of matches this Regex refers to. Noticing a pattern?

### Classes

Ruby has classes like `Integer`, `String`, and others. Normally you can check to see if something happens to be of a certain type using `is_a?`. Not surprisingly `===` works much the same way here:

```ruby
String === 'foo'
# => true

'foo'.is_a?(String)
# => true
```

`===` here is saying that `'foo'` is a member of the `String` class, or it's included in what we'd call Strings.

It should be noted that this works for about every Ruby core class in the standard library, but as it requires custom implementation there may be some more exotic cases which don't.

### Functions (Proc and Lambda)

Ruby has a few ways to express anonymous functions, procs and lambdas. There's also block, but we'll focus on those two for the moment. They can be expressed as such:

```ruby
add_one_lambda = -> x { x + 1 }
add_one_proc   = proc { |x| x + 1 }
```

We won't get into differences between all of them in this round, but note that I tend to prefer lambdas in general over procs.

To use these functions you'd need to use `.call` (or `[]` or `.()`), which you might not be surprised to find out is `===` as well:

```ruby
add_one_lambda = -> x { x + 1 }

add_one_lambda === 1
# => 2
add_one_lambda.call(1)
# => 2
add_one_lambda.(1)
# => 2
add_one_lambda[1]
# => 2
```

This one is a head scratcher. How is `1` a member of a function? That doesn't make much sense, it's not really any type of collection or set is it? Well in Mathematics it's called the [domain of a function](https://en.wikipedia.org/wiki/Domain_of_a_function), or the set of which all valid inputs fall into, so that sounds a lot like membership too!

### IP Addresses

Ruby also has this lovely feature for all of us Operations and Networking types, `IPAddr`:

```ruby
require 'ipaddr'

IPAddr.new('10.0.0.1')
```

You can even express subnets using it:

```ruby
local_network = IPAddr.new('192.168.1.0/24')
local_network.include?('192.168.1.1')
# => true
```

Is your intuition dinging a bit? Because we have another case for `===` here:

```ruby
local_network === '192.168.1.1'
# => true
```

For this one we're checking if an IP Address is a member of a given subnet, further rounding out this interesting pattern. Ruby loves patterns, and math and programming in general have a certain affinity for them.

## A Case for `===`

Now this is all well and good, but the above warning said not to use `===` explicitly, so why spend all that time describing how it works? Because we're about to see the implicit through `case` statements.

You see, every `when` branch in a `case` statement compares via `===`:

```ruby
case 1990
when ..1899     then :too_early
when 1900..1924 then :gi
when 1925..1945 then :silent
when 1946..1964 then :baby_boomers
when 1965..1979 then :generation_x
when 1980..2000 then :millenials
when 2000..2010 then :generation_z
when 2010..     then :generation_alpha
else
  :who_knows
end
# => :millenials
```

You can even use commas to check against multiple possibilities:

```ruby
case 'foobar'
when String, Integer then :one
when Float, NilClass then :two
else
  :three
end
```

There's a lot of potential to check against whether a value is within an expected set, and with functions that gets even more interesting:

```ruby
divisible_by = -> divisor { -> n { n % divisor == 0 } }

(1..15).map do |n|
  case n
  when divisible_by[15] then :fizzbuzz
  when divisible_by[5]  then :buzz
  when divisible_by[3]  then :fizz
  else
    n
  end
end
# => [
#   1, 2, :fizz, 4, :buzz, :fizz, 7, 8, :fizz, :buzz,
#   11, :fizz, 13, 14, :fizzbuzz
# ]
```

Interesting no?

There is one trick in there called a closure, which is a function which returns another function. That returned function remembers what the value of `divisor` was, allowing us to check if somthing is divisible by it. It's a really useful trick from functional programming, and really shows the power of functions in Ruby, especially with things like `case` statements.

## Enumerating All the Fun We Can Have

`Enumerable` also has a number of methods which take values that respond to `===`. Let's take a look at some examples.

### Predicate Methods

The predicate methods (`any?`, `all?`, `none?`, `one?`) all play well with `===`:

```ruby
['1', 2, :a].any?(Integer)
# => true

```

### The Search is On

Searching methods like `grep` (find all that match pattern) and `grep_v` (find all that do **not** match pattern) also implement a `===` interface:

```ruby
%w(The rain in spain falls mainly on the plain).grep(/the/i)
# => ["The", "the"]
```

### Slice of Life

There are also Slice methods that allow us to group elements by a pattern like `slice_before` and `slice_after`:

```ruby
array = [7, 9, 4, 1, 14, 5, 13, 8, 2, 6, 3, 12, 15, 11, 10]

array.slice_before(10..).to_a
# => [[7, 9, 4, 1], [14, 5], [13, 8, 2, 6, 3], [12], [15], [11], [10]]

array.slice_after(..5).to_a
# => [[7, 9, 4], [1], [14, 5], [13, 8, 2], [6, 3], [12, 15, 11, 10]]
```

## Pattern Matching

Now if you were excited about `case` statements let me tell you Pattern Matching is like a `case` statement with a lot of extra fun built in. We won't get into all the nuances of it, but every value is matched against using `===`. It uses `in` rather than `when`, which unlocks some additional features.

### Array-Like

It supports two types of syntaxes, an Array-like match and a Hash-like match. Let's start with Array-like:

```ruby
case [0, 1]
in [..10, ..10] then :close_to_base
in [..100, ..100] then :venturing_out
in [..1000, ..1000] then :pretty_far_out
else :way_out_there
end
# => :close_to_base
```

If we want we could even capture those values by name or a few other fun items, but we'll save that for another post.

### Hash-like

The next is Hash-like, and this is where things get interesting. Let's say we have a JSON API with some data and we got back that data and that data was in a variable called `raw_json`:

```ruby
raw_json = <<~JSON
  [{
    "age": 22,
    "eyeColor": "blue",
    "name": { "first": "Trina", "last": "Chang" },
    "friends": ["Browning Marsh", "Keisha Abbott", "Shawn Callahan"]
  }, {
    "age": 32,
    "eyeColor": "brown",
    "name": { "first": "Irma", "last": "Petersen" },
    "friends": ["Koch Ballard", "Chandra Rodriquez", "Carmen Avery"]
  }, {
    "age": 27,
    "eyeColor": "hazel",
    "name": { "first": "Madeleine", "last": "Blake" },
    "friends": ["Tina Massey", "Annette Yates", "Zelma Brennan"]
  }, {
    "age": 20,
    "eyeColor": "green",
    "name": { "first": "Horton", "last": "Haynes" },
    "friends": ["Sophia Oconnor", "Sheila Wilkins", "Mia Molina"]
  }, {
    "age": 12,
    "eyeColor": "brown",
    "name": { "first": "Hull", "last": "Benson" },
    "friends": ["Teresa Mack", "Mcfadden Conley", "Juanita Rollins"]
  }]
JSON
```

We'd start by parsing it, but we want to _ensure_ those keys are `Symbols` using this syntax for `JSON.parse`:

```ruby
require 'json'

json_data = JSON.parse(raw_json, symbolize_names: true)
```

Now we can do something really interesting with Pattern Matching:

```ruby
selected_people = json_data.select do |person|
  case person
  in age: 20.., eyeColor: /^b/, name: { first: /^[TI]/ }
    person
  else
    false
  end
end

selected_people.map do |person|
  person => { name: { first:, last: } }
  "#{first} #{last}"
end
# => ["Trina Chang", "Irma Petersen"]
```

That's a lot. What's it doing exactly?

First we want to select all people older than `20` with an eye color that starts with the letter `b`, and a first name that starts with either `T` or `I`. How's that for expressive?

Next we're using something called right-hand-assignment (`=>`) to pull the first and last names out of the person to just return back their names. In Pattern Matching if a key doesn't have a value it gets put into a local variable, hence `first` and `last` being accessible in the line right below it.

Again, we won't get into all the nuance of Pattern Matching in this post, but you can see how it gets very interesting very quickly. I intend to write a more thorough introduction to Pattern Matching concepts fairly soon, so stay tuned for that one.

# Wrapping Up

So that was a lot. `===` is hiding everywhere in Ruby, and once you build up an intuition to it you'll notice it pretty frequently. Even better, that intuition means you now know how to create your own `===` if you should find yourself in such a need one day.

Spoilers though, it's an operator defined as a method:

```ruby
# Example implementation
class String
  def self.===(other)
    other.is_a?(self)
  end
end
```

Ruby has a lot of interesting facets, and with them a substantial amount of power. This series will continue to cover some of the foundations of Ruby and some of its most useful tools and features.

Until then enjoy your newfound knowledge of `===`!

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
