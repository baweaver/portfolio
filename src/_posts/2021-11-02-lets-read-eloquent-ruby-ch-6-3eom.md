---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 6 – Symbols"
series: "lets-read-eloquent-ruby"
date: "2021-11-02"
tags: ["ruby", "rails", "books"]
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2021 — Ruby 3.0.x).

> **Note**: This is an updated version of a previous unfinished Medium series of mine you can [find here](/writing/2018/09/21/lets-read-eloquent-ruby-ch-1/).

## Chapter 6. Use Symbols to Stand for Something

This chapter covers one of the admittedly more confusing aspects of Ruby, Symbols. Still a bit confused about them yourself? Nothing to feel bad about on that, it took me a while before it clicked, and I can't say it's the most intuitive part of the language.

That said, we'll take a look at Russ's thoughts here in the book and add some new context that we've seen in later versions of Ruby that have further blurred the line, as well as some of the arguments on why Symbol and String will never be merged (and should not be).

The simplest description, however, you could use is that Strings are text meant for a human, and Symbols are labels meant for your program.

### The Two Faces of Strings

The book starts in with an example that it deliberately simplifies by saying Symbols are really just Strings:

```ruby
string = "dog"
symbol = :dog
```

In many senses and at first glance, as the book mentions, they're the same three characters referring to the same idea: a dog. In many cases in Ruby they could even be used interchangeably (though they shouldn't be), further confounding folks trying to understand what the differences are.

Take these two (old) Rails examples the book mentions:

```ruby
book = Book.find(:all)
book = Book.find("all")

# Modern versions do this instead:
books = Book.all
```

The point is as a human we can tell we mean the same thing, and that's an important thing to realize about Ruby: It legitimately tries to not be surprising. If you could reasonably think a method could take a String or a Symbol chances are it will:

```ruby
def testing; 1 end

method(:testing)
# => #<Method: main.testing() (irb):1>
method("testing")
# => #<Method: main.testing() (irb):1>
method(:testing) == method("testing")
# => true
```

That's certainly not the only time Ruby does this, but a good general rule is to use Symbols in these types of cases. We'll get into that more in a moment along with the book.

### Not Quite a String

The book then goes on to ask why we need both, and presents an answer: Strings hold data that we're processing.

In the Rails example `Book.all` would return several records with String data in them. Data that could be changed, read, or acted upon by humans.

For Symbols in the (outdated) example of `Book.find(:all)` we're using `:all` as a flag for what records to retrieve, or in the case of `method` which method in the program we're retrieving. Those Symbols stand for an idea, and serve as a named label for the concept.

The book then mentions Symbols could also be thought of as a very pared down String. Symbols don't particularly need manipulation, so all the methods for transforming and working with Strings don't make sense in the context of labeling something internal to the program.

Because of those assumptions Symbols can be optimized. Granted in more recent versions of Ruby with frozen Strings this difference is not nearly as pronounced.

### Optimized to Stand for Something

Next up the book gets into the optimization implications we'd started to mention. Strings are optimized for data processing, and symbols are optimized for equality checks.

In its example we have a few variables assigned to Symbols:

```ruby
a = :all
b = a
c = :all

[a, b, c].map(&:object_id)
#  => [784988, 784988, 784988]

a == c
# => true
a === c
# => true
a.eql?(c)
# => true
a.equal?(c)
# => true
```

They're all the exact same entity. The book then goes on to say that this isn't the case for Strings:

```ruby
x = "all"
y = "all"
```

That's not strictly true any more with the frozen string literal comment:

```ruby
# frozen_string_literal: true

x = "all"
y = "all"
```

...but we'll leave that alone for now and get back to the book. In the case where this is not enabled both of these Strings are in fact different objects, whereas there can only ever be one instance of any given Symbol.

Symbols are also immutable (Strings can be frozen, or use the `frozen_string_literal` comment above). That's why they tend to be used for Hash keys.

Hash implements a few things behind the scenes to make sure that mutated keys don't crash programs, and as the book mentions this is most certainly a patch against Strings being mutable and potentially causing issues.

### In the Wild

The book then goes on to mention that yes, they're confusing, and lists a few more examples.

In one you can convert between the two using `to_sym` and `to_s`, and in a significant amount of Ruby methods they'll even do this behind the scenes if they think you might reasonably use them interchangeably. Does that make it correct? Perhaps not, but it's such a common issue that we're probably pretty far beyond that by now.

In older versions of Ruby (older than 1.9) asking for the public methods of an object used to return a String Array, but now returns Symbols, so even Ruby itself has some issue keeping track. Then again 1.8 to 1.9 was a pretty big gap, whereas 1.9 to 2.0 and 2.7 to 3.0 were far more minor.

### Staying Out of Trouble

One of the most common issues is going to come back to Hashes using Symbol and String interchangeably. If you did, they would break. `person[:name]` is not the same as `person["name"]` unless you have a `HashWithIndifferentAccess` from Rails which hacks around this.

Personally, and there are going to be a number of people who consider this heretical, I believe that most Hash keys should be Strings unless that Hash is being used internal to the program. That said, enforcing semantic style that requires any type of human interpretation is perilous, so I would never try and make that happen.

Some have even tried to add JS object style where `person.name` is the same as `person[:name]` or `person["name"]` using `Hashie`, but the author and several other Rubyists came to the conclusion that this wasn't a great idea.

Schneems wrote on this years ago, and it would be a good article to read into:

https://www.schneems.com/2014/12/15/hashie-considered-harmful.html

### Wrapping Up

Symbols and Strings aren't getting merged. [That ship has sailed many times](https://bugs.ruby-lang.org/issues/7792) and has been rejected every single time. You can read more into it, but by now it's one of those features for better or worse that's part of the language.

Deprecating features is not easy, and there are a number of them even Matz has said he regrets adding. That said, knowing that when writing something requires insight beyond what any programmer can reasonably be expected to have, and years of development on the feature to prove the point.

Compatibility and non-breaking changes are critically important to a programming community, and I believe Matz and crew have made the correct decision on this, even though I may protest on principal.
