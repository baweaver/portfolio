---
layout: "post"
title: "Exploring Ruby 2.6 — Enumerator, Hash, and Enumerable Changes"
date: "2018-11-14"
categories: []
tags: []
description: ""
---

New features to try in the upcoming ruby-2.6.0-preview3

![](/images/posts/2018-11-14-exploring-ruby-26enumerator-hash-and-enumerable-changes/img-a80347d9.png)
> Heads up, we’ve moved! If you’d like to continue keeping up with the latest technical content from Square please visit us at our new home [https://developer.squareup.com/blog](https://developer.squareup.com/blog)

As we get closer to Christmas, we’re going to see more and more features for Ruby 2.6. Some of them haven’t been discussed much, including Enumerable and Enumerator, and I’ve found those changes particularly interesting. Let’s take a look.

![Christmas is coming, and with it some fun new presents in Ruby!](/images/posts/2018-11-14-exploring-ruby-26enumerator-hash-and-enumerable-changes/img-b1c69b2d.png)*Christmas is coming, and with it some fun new presents in Ruby!*

## Enumerable#to_h

If you started Ruby in the earlier days, you’re probably familiar with Hash[] and its usage like this:

    hash = { a: 1, b: 2 }
    Hash[hash.map { |k, v| [k, v + 1] }]
    => { a: 2, b: 3 }

In the 2.x days, we started to see Enumerable#to_h :

    hash = { a: 1, b: 2 }
    hash.map { |k, v| [k, v + 1] }.to_h
    => { a: 2, b: 3 }

This was certainly a more palatable option, but what if it went one step further? In Ruby 2.6+ to_h will take a block that works quite a bit like map:

    hash = { a: 1, b: 2 }
    hash.to_h { |k, v| [k, v + 1] }
    => { a: 2, b: 3 }

Since this is a method on Enumerable, we can use it on other things like Ranges and Arrays as well:

    (1..5).to_h { |n| [n, n**2] }
    => {1=>1, 2=>4, 3=>9, 4=>16, 5=>25}

Admittedly it’s not as explicit as the combination of map and to_h, but it does give us one more step to cut down on hash conversion code.

## Hash#merge

In previous versions of Ruby, in order to merge multiple hashes together you’d have to do them one at a time:

    h1.merge(h2).merge(h3).merge(h4)

…or potentially use the double-splat to treat them all as one big inline hash:

    h1.merge(**h2, **h3, **h4)

…or for those of us with a particular love for reduce, there’s even a flavor of Ruby for that!

    [h1, h2, h3, h4].reduce(&:merge)

Now those all work, but variadic, that’s where it’s at. Ruby 2.6 introduces variadic arguments for Hash#merge :

    h1.merge(h2, h3, h4)

Note that this works with Hash#merge! and Hash#update as well.

## Enumerator::ArithmeticSequence

That’s quite a mouthful — try saying that one five times fast. Go ahead and get your REPL open if you haven’t already. We’re going to try a few things.

Before 2.6, if you try this:

    (1..100).step(3) == (1..100).step(3)

You were going to get a nice ol’ false right back out. They look the same though, right? Why aren’t they equal?

Turns out that the core team agreed, so they created the concept of an ArithmeticSequence to take care of exactly this:
[**Feature #13904: getter for original information of Enumerator - Ruby trunk - Ruby Issue Tracking…**
*Redmine*bugs.ruby-lang.org](https://bugs.ruby-lang.org/issues/13904)

Most of the issue was that Enumerators didn’t really have introspective information about themselves, meaning that they didn’t quite know how to compare themselves to each other.

As an added benefit, we got a few more things to play with. Mostly keywords to make our intent more explicit in creating stepped enumerators:

    (1..10).step(3) == 1.step(by: 3, to: 10)

    1.step(by: 2, to: 10)
    => [1, 3, 5, 7, 9]

    (1..10).step(3)
    => [1, 4, 7]

We also got a new use for the modulo operator:

    (1..100).step(3) == (1..100) % 3

…though to be fair I would bet that this one is going to be used far more frequently for code golf than actual production code.

## All Together Now!

Now it wouldn’t be an article without an incredibly contrived, and quite frankly horrifying, code example. Well, fear not! We’ve got just the thing, and it’s our old friend FizzBuzz:

    def fizzbuzz(rules, range)
      mappings = rules.map { |step, value|
        (range % step).to_h { |n| [n, value || n] }
      }

      fizzbuzz_map = {}.merge(*mappings) { |_, old_value, new_value|
        is_numeric = [old_value, new_value].any?(Numeric)
        is_numeric ? new_value : old_value + new_value
      }

      fizzbuzz_map.values
    end

    rules = {1 => nil, 3 => 'Fizz', 5 => 'Buzz'}
    range = (1..100)

    puts fizzbuzz(rules, range)

What we’re doing here is defining a rule set using a hash indicating the step rate (how many numbers to skip since the last number in the range) and a value.

Since multiples of 3 and 5 have special mappings, we say so in our rules. This means that when we get to creating our step values, it’s not going to pass through for the actual number in the statement value || n.

The first step we have is translating each one of those rule sets over the given range, only selecting numbers divisible by the given step rate as we go.

One of the interesting things about merge is that it can take a block which exposes the key, and the intersecting values at that key in the two different hashes as the old and new values. Using that we can decide which value to “keep”, as it were.

We always assume that string rules have precedence over number-based ones, and if there’s already a string we must have hit a number divisible by 15 somewhere in there.

Now this is most certainly inefficient, but a fun exploration of some new features nonetheless.

## Wrapping up

There are a lot of fun new features coming in 2.6, many of which haven’t even come out yet. This is just a small peek, and we’re looking forward to seeing the rest.

Thanks to my fellow Square Shannon “havenwood” Skipper for exploring the latest Ruby commits slated for ruby-2.6.0-preview3 with me. We use lots of Ruby here at Square — in our Square Connect Ruby SDKs, many of the open source projects we maintain, and much more. We’re eagerly awaiting the release of Ruby 2.6!
