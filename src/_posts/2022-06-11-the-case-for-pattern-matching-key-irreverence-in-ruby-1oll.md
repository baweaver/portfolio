---
layout: "post"
title: "The Case for Pattern Matching Key Irreverence in Ruby"
date: "2022-06-11"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "discuss"]
description: "I had alluded to this post a bit earlier on Twitter, and in the Ruby bug tracker, but wanted to more..."
---

I had alluded to this post a bit earlier on Twitter, and in the Ruby bug tracker, but wanted to more fully write out my thoughts on what could be an incredibly powerful paradigm shift in how Ruby treats pattern matching on hash-like objects.

That idea, simply, is to treat the `keys` argument to `destructure_keys` as if they were keyword arguments, rather than as literal `Symbol`s.

## Keys as Literal Symbols

The state of the world, for many maintainers, is that `keys` is an `Array<Symbol>` where each `Symbol` represents a `key` to be restructured from a hash-like object, or return all possible keys in the case of a `nil` argument.

In the strictest sense and most literal interpretation this makes sense, such that if you matched against the hash `{ a: 1, b: 2, c: 3 }` like so:

```ruby
{ a: 1, b: 2, c: 3 } in a: 1..10, b: Integer
# => true
```

...the `deconstruct_keys` method would receive `[:a, :b]` for `keys`. These would correspond to the keys  `:a` and `:b` in the above hash.

This certainly makes sense in the above case, but I hope to show you that this pattern does not fully encompass what pattern matching can express, and is actually very restrictive.

## The Compromises of Pattern Matching

### Object Deconstruction via Instance Variables

Let us say that we were to make our own custom object, a `Point` with coordinates:

```ruby
class Point
  def initialize(x:, y:)
    @x = x
    @y = y
  end
  
  def deconstruct = [@x, @y]
  def deconstruct_keys(keys) = { x: @x, y: @y }
end

Point.new(x: 1, y: 2) in x: 0..5
# => true
```

This brings up a few sneaky questions hiding in plain sight:

* Is a `Point` a `Hash`? - No
* Can it be represented as one? - Yes
* What do `keys` represent then? - The instance variables `@x` and `@y` put into a `Hash`

That last one I want you to pay very close attention to.

That leads to one more question: Are variables or instance variables `Symbol`s? The answer, of course, is no.

We're not treating them as literal `Symbol`s in this case, we're treating them as something much more interesting: representations of something else.

They represent internal state of the `Point`, and we frame that internal representation as a `Hash` which can be consumed by pattern matching.

This was the first compromise pattern matching made with the above literal interpretation of `Symbol`s, but not the last.

### Object Deconstruction via Method Calls

Now let's change the `Point` class a bit to show something even more interesting:

```ruby
class Point
  attr_reader :x, :y
  
  def initialize(x:, y:)
    @x = x
    @y = y
  end
  
  def deconstruct = [x, y]
  def deconstruct_keys(keys) = { x:, y: }
end

Point.new(x: 1, y: 2) in x: 0..5
# => true
```

This one is far more subtle. The first thing is you might not recognize that syntax on `deconstruct_keys`. That's because  `deconstruct_keys` is using Ruby 3.1 punning to generate effectively `{ x: x, y: y }` which will call both of the `attr_reader` generated methods for `x` and `y`.

Now not only are we referring to literal `Symbol`s and variables within scope, we're also referring to potential method calls in our representation as well.

This compromise raises a critical point: As long as you can wrap it in a `Hash` that pattern matching can understand it _does not care_ where the data comes from.

### Distinctly Ruby Duck Typing

It's also distinctly Ruby for one core reason: Duck typing. Like `===`, `call`, `to_proc`, and other common interface methods as long as you play by the rules of pattern matching in a reasonable manner it will still work.

The point of this interface is not a 1-1 `Hash` mapping. What it is, however, is something much more compelling and interesting.

## Query Language and Available Fields

Every field that can be returned from a pattern match is, technically speaking, a `Symbol` key and any value we could dream up.

They're also representative of the internal state of an `Object`, and what state we choose to make accessible as an "available field" to be matched against.

That means that pattern matching is not matching a `Hash` to a `Hash`, it's querying an `Object`'s available fields using the `===` interface common to Ruby. It's up to us to define what those fields are, especially for cases where we're not literally matching a `Hash<Symbol, Any>` type.

The further away from that literal `Hash<Symbol, Any>` we go, the more it is up to us to define what constitutes a reasonable interface, hence my insistence that pattern matching is a query language against available fields.

Why is this important? Well let's take a look at how some of the rest of Ruby deals with `Symbol`s real quick.

## Ruby and `Symbol`s

If we were to look in the Ruby language, one might expect that a `Symbol` is a `Symbol`, but frequently it's anything but that simple. Let's take a look at a few distinct cases to show what I mean there.

### Keyword Arguments

In Ruby we have access to keyword arguments as a clearer way to accept arguments:

```ruby
def some_method(a: 1, b: 2, c: 3)
  a + b + c
end
```

In older versions of Ruby this could be a `Hash<Symbol, Any>` that would be coerced into keywords, and recent versions have leaned more towards explicit coercion with `some_method(**{ a: 1})` style double-splatting.

That said, in this case keywords are very similar to `Symbol`s, and in the past were very much accepted as such.

### Pattern Matching

Pattern matching itself has interesting treatments for `Symbol`:

```ruby
Point.new(x: 1, y: 2) => x:, y:
[x, y]
# => [1, 2]
```

Very much in line with keyword arguments from before, we're using these as arguments to `deconstruct_keys` which extracts both the `x` and `y` from the `Point`.

At the point of the caller they're very much in the style of keyword arguments, but in the method they're `Array<Symbol>` or `nil`.

### Punning

You saw the above example of punning, well that was very much due to and inspired by the above pattern matching syntax. The [original bug tracker issue](https://bugs.ruby-lang.org/issues/14579) predated pattern matching by quite a bit, but pattern matching and mandatory keyword arguments very much contributed to its merging in [this comment](https://bugs.ruby-lang.org/issues/14579#note-14):

> After the RubyKaigi 2021 sessions, we have discussed this issue and I was finally persuaded.
> Our mindset has been updated (mostly due to mandatory keyword arguments).
> Accepted.
>
> Matz.

The above `Point` class used this:

```ruby
def deconstruct_keys(keys) = { x:, y: }
```

Those symbols are treated as keywords, rather than `Symbol`s despite technically being `Symbol`s, and because of that we have a lot of power in reconstructing objects which I have found very useful, and you can [find more of my writing here on why I like them](/writing/2021/09/12/ruby-3-1-shorthand-hash-syntax-first-impressions-19op/).

Sufficient to say I think they're very powerful, but let's take a different vantage real quick.

### Ambiguity and Coercion

[Polished Ruby Programming](https://www.packtpub.com/product/polished-ruby-programming/9781801072724) does an excellent job of covering some of this in Chapter 1 in "Understanding how symbols differ from strings" and I want to cover a few things from the book real quick. It uses two examples:

```ruby
method = :add
foo.send(method, bar)

method = "add"
foo.send(method, bar)
```

Strictly speaking `send` expects a `Symbol`, yet it still works with a `String` here. Why? Well the book has a good answer:

> ...this is only because Ruby tries to be friendly to the programmer and accept either.

(Yes, it is technically slower, but not quite the point of this post)

So now we have a distinct case of Ruby coercing a `String` to a `Symbol` because Ruby is trying to be friendly, but also something more important is hidden here: It's because Ruby knows what you meant, and did not treat it literally.

The book goes on to mention that this is not the only method which behaves like this. It also happens with `Module#define_method`, `Kernel#instance_variable_get`, `Module#const_get`, and probably several more.

Now this next part is critically important for the case I'm about to make, also from the book:

> The previous examples show that when Ruby needs a symbol, it will often accept a string and convert it for the programmer's convenience. This allows strings to be treated as symbols in certain cases. There are opposite cases, where Ruby allows symbols to be treated as strings for the programmer's convenience.

The very ethos of Ruby is programmer happiness, convenience, and the ability to express yourself in multiple different ways as long as it makes reasonable sense.

This case can be made with Ruby alone, but if you look into Rails it certainly takes this argument much further when you start seeing cases like `Hash#with_indifferent_access`, but we will leave those cases alone excepting to say that this ethos has spread to implementations across the Ruby ecosystem.

Or, in other words, **it is established Ruby precedent to favor convenience over explicitness**.

Now then, to get to the interesting part.

## Pattern Matching as Keywords

All of that was to say that there is indeed established Ruby precedent that we prefer to do the reasonable and convenient thing over the strictly "correct" and explicit thing, and that it is not confined to one part of the language.

In the case of compromises for pattern matching we already know that `Symbol`s have been used as representations of variables and methods, but given the last section we can make one more leap and make a case for a final and very interesting precedent that we've been very close to making:

Arguments to pattern matching's `deconstruct_keys` are effectively keyword arguments, and representations of internal state.

It's up to us to determine what that means, and for me it brings up a slightly contentious subject that's received some amount of kick-back:

What about `Hash`-like structures that use `String`s for key representations like `JSON`, `CSV`, `RegExp`, and other core classes?

### The Case for CSV

`CSV::Row` currently has an implementation of pattern matching:

```ruby
# :call-seq:
#   row.deconstruct_keys(keys) -> hash
#
# Returns the new \Hash suitable for pattern matching containing only the
# keys specified as an argument.
def deconstruct_keys(keys)
  if keys.nil?
    to_h
  else
    keys.to_h { |key| [key, self[key]] }
  end
end
```

The problem, as I have enumerated upon in [CSV#246](https://github.com/ruby/csv/issues/246), is that rows for CSVs are commonly `String` keys, rather than `Symbol` as the interface assumes.

The [response](https://github.com/ruby/csv/issues/246#issuecomment-1150795568) was that there are flags which allow explicit conversion:

```ruby
require "csv"

data = CSV.parse(<<~ROWS, headers: true, header_converters: :symbol)
  Name,Department,Salary
  Bob,Engineering,1000
  Jane,Sales,2000
  John,Management,5000
ROWS
pp data.select { _1 in name: /^J/ }
[#<CSV::Row name:"Jane" department:"Sales" salary:"2000">,
 #<CSV::Row name:"John" department:"Management" salary:"5000">]
```

While correct in the strict sense, this feels like Ruby could very easily make a reasonable coercion for us and know what we meant, as it does in so many other cases.

For me I believe that the implementation for `deconstruct_keys` should coerce internal representation to `Symbol` keys to treat it as keyword arguments that query against internal state, rather than a 1-1 match:

```ruby
class CSV::Row
  def deconstruct_keys(keys)
    if keys.nil?
      to_h.transform_keys(&:to_sym)
    else
      keys.to_h do |key|
        value = if self.key?(key)
          self[key]
        elsif self.key?(key.to_s)
          self[key.to_s]
        else
          nil
        end

        [key, value]
      end
    end
  end
end
```

I believe this satisfies the above ethos of Ruby being convenient and favoring programmer happiness over strict correctness as we know that `keys` will be either `nil` or `Array<Symbol>` and can reasonably infer which fields the user wants.

In the original implementation I had raised this concern on [CSV#207](https://github.com/ruby/csv/pull/207#discussion_r581610281) to say something very similar, but I did note the following:

> If you want to support this you would want to instead transform the keys to `String`, but this may be controversial as it conflates the two.

It is, in a sense, controversial but the more I think about it the more it feels very Ruby to take care of this ergonomic usecase for us rather than being explicit.

The author [disagreed with this](https://github.com/ruby/csv/pull/207#discussion_r581981460):

> I think I'd rather leave it as is for now. You can always pass `header_converters: :symbol` to the parse function, which would make this work as expected.
>
> I think I would be really surprised if in my matching I specified symbols and it matched against strings.

...and is one of the reasons I have written this article to articulate my case a bit more clearly.

### An Aside on Disagreement

To be clear, I hold no ill-will for kddnewton here, far be it. He's a very smart guy and does a lot of excellent work, I will not remotely contest that one.

Programmers disagree, we make our cases, and eventually one wins out. Not everyone will agree with every decision, but I do believe it valuable to reevaluate on occasion to address cases which may have a very powerful impact on the language.

What makes it a community is that we can have these discussions without name calling and vitriol, but rather laying out our thoughts and seeking the opinions of both the community and the core contributors.

If I should have my solution become precedent I do think it would be of great benefit to the language, but should it not be I will not hold that against anyone as I have made my case far more clearly and if that is the will of Ruby then that is what I shall accept.

There are several things in Ruby I don't agree with, but there are also several that I enjoy, and that's the nature of any language.

Why bring it up then? Because this was a one-repo decision, and I want to clarify this at the language level rather than trying to sneak it into multiple downstream repos and attempt to create precedent via attrition which does not feel correct to me.

### The Case for MatchData

The next interesting case is on `MatchData`:

```ruby
class MatchData
  alias_method :deconstruct, :to_a

  def deconstruct_keys(keys)
    return named_captures.transform_keys(&:to_sym) unless keys
    
    named_captures.transform_keys(&:to_sym).slice(*keys)
  end
end

IP_REGEX = /
  (?<first_octet>\d{1,3})\.
  (?<second_octet>\d{1,3})\.
  (?<third_octet>\d{1,3})\.
  (?<fourth_octet>\d{1,3})
/x

'192.168.1.1'.match(IP_REGEX) in {
  first_octet: '198',
  fourth_octet: '1'
}
# => true
```

Match capture groups are currently `String` keys, as strictly speaking the names of the groups are `String`s in the regex. I believe this is a clearer case as we're referring to `named_captures` with a 1-1 mapping to the `Symbol` variant.

### The Case for Hash

Now I'm going to do something potentially interesting and note the anti-case for `Hash` and why that may be concerning. Do note I would still love it if it were to occur but it does present some insidious potential bugs in rare cases.

Let's say we had the following:

```ruby
hash = {
  a: 1,
  "a" => 1
}
```

If we treated all pattern matching keys as query parameters rather than as literal `Symbol` which one should win out? This creates ambiguity, and as such would need a very firm rule of precedence that `Symbol` keys are preferred over `String` keys if both should happen to exist.

The other problem here is that if we were to implement this it would cause a potential slow-down for pattern matching in the general case of `Hash` where we do two key lookups rather than one for every potential value. One `Symbol` and then one `String`.

This could be mitigated somewhat with a `key?` check, but would still present a minor slowdown.

In this case I do believe the benefits would outweigh the performance implications, though let's take a quick look:

```ruby
# Don't do this in production code

# So we have a "Ruby" implementation to level against, rather than the C
# one.
class HashOriginal < Hash
  def deconstruct_keys(keys)
    return self unless keys

    keys.each_with_object({}) do |key, matches|
      matches[key] = self[key] if key?(key)
    end
  end
end

class HashPrime < Hash
  def deconstruct_keys(keys)
    if keys.nil?
      self.transform_keys(&:to_sym)
    else
      keys.each_with_object({}) do |key, matches|
        if key?(key)
          matches[key] = self[key]
        elsif key?(key.to_s)
          matches[key] = self[key.to_s]
        end
      end
    end
  end
end

Benchmark.ips do |x|
  x.report("Hash") do
    Hash[a: 1, b: 2] in { a: 1, b: 2, c: 3 }
  end

  x.report("HashOriginal") do
    HashOriginal[a: 1, b: 2] in { a: 1, b: 2, c: 3 }
  end

  x.report("HashPrime") do
    HashPrime[a: 1, b: 2] in { a: 1, b: 2, c: 3 }
  end

  x.report("HashPrime String") do
    HashPrime[a: 1, "b" => 2] in { a: 1, b: 2, c: 3 }
  end
end

# Warming up --------------------------------------
#                 Hash   299.651k i/100ms
#         HashOriginal   103.085k i/100ms
#            HashPrime    85.180k i/100ms
#     HashPrime String    80.537k i/100ms
# Calculating -------------------------------------
#                 Hash      2.951M (± 3.0%) i/s -     14.983M in   5.081797s
#         HashOriginal      1.057M (± 2.6%) i/s -      5.360M in   5.075552s
#            HashPrime    924.234k (± 3.8%) i/s -      4.685M in   5.076900s
#     HashPrime String    784.882k (± 4.9%) i/s -      3.946M in   5.041825s

```

Few things to note here:

1. `Hash` implements `deconstruct_keys` in `C` making that a bit uneven, hence `HashOriginal` as a litmus.
2. Yes, you can omit the `{}` around the pattern in newer Ruby versions, but not if there's ambiguity like this case.
3. We explicitly added a key which does not exist as that incurs both checks.
4. Avoid subclassing classes like this in prod code, I'm only doing it for a quick measurement.
5. This is not a definitive benchmark as much as a quick measure, more comprehensive ones are likely warranted if this pattern is under serious review.

Anyways, the thing to note here is that the `HashPrime` implementation is within striking distance of `HashOriginal` and `HashPrime String` is not incredibly slower than both of those implementations. If this were done in `C` it may not be far behind at all.

Now why, given that performance implication, would I still recommend it potentially? Because as it exists right now if you pattern match against a `Hash<String, Any>` it will not work, making the performance measurement more a case between `HashOriginal` and `HashPrime` with the caveat of missing keys.

## Closing Thoughts

My case, simply, is that by treating pattern matching arguments as keyword arguments, and the return value as defining available fields which can be queried against it unlocks a lot of power in Ruby which currently does not exist, or requires a lot of coercion to get to.

I believe that the precedent for this currently exists, as I have enumerated upon above, and that this is not an entirely unreasonable jump to make given the benefits to programmer convenience it yields. It is still a precedent that lies in a gray area, granted, and one could make a reasonable case against it as well.

My purpose here is not to make demands of Ruby, far be it, but to present my case and my thoughts on the matter rather than implementing similar patterns myself in repositories which may create conflicting patterns in the Ruby codebase depending on who is reviewing and what their opinions may be.

Whether or not my case is accepted that is the one thing that I would like to avoid, hence asking for clarification at a language level. That, to me, would be far more against the spirit of Ruby.

We discuss, we learn, we come to agreements, and we hear others. That's what makes a community, but what makes it special is we can disagree on such matters in kindness rather than vitriol.

If you have thoughts on this as well do reply to me on Twitter at [keystonelemur](https://twitter.com/keystonelemur/status/1535521834459836418), in the comments section here, or on any other media this article finds itself on.
