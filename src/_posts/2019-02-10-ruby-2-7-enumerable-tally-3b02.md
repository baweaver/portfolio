---
layout: "post"
title: "Ruby 2.7 — Enumerable#tally"
date: "2019-02-10"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Ruby 2.7 — Enumerable#tally   Christmas has come and passed, 2.6 has been released, and now..."
---

### Ruby 2.7 — Enumerable#tally

Christmas has come and passed, 2.6 has been released, and now it’s time to mercilessly hawk the releases page for 2.7 features so we can start our fun little annual tradition of blogging about upcoming features.

Typically this means another December release, but there have been cases of methods making it in earlier if they’re merged to trunk this early in the year.

<!-- ![](/images/posts/2019-02-10-ruby-2-7-enumerable-tally-3b02/img-75366d84.png) -->

This round? We have the new method Enumerable#tally!

### The Short Version

`tally` counts things:

```ruby
[1, 1, 2].tally
# => { 1 => 2, 2 => 1 }

[1, 1, 2].map(&:even?).tally
# => { false => 2, true => 1 }
```

### Examples

The example used in Ruby’s official test code is:

```ruby
[1, 2, 2, 3].tally
# => { 1 => 1, 2 => 2, 3 => 1 }
```

Without a block, tally works by counting the occurrences of each element in an `Enumerable` type. If we apply that to a list of another type it might be a bit clearer:

```ruby
%w(foo foo bar foo baz foo).tally
=> {"foo" => 4, "bar" => 1, "baz" => 1}
```

Currently `tally_by` has not been accepted into core, so to `tally` by a function you would instead use `map` first:

```ruby
%w(foo foo bar foo baz foo).map { |s| s[0] }.tally
=> {“f” => 4, “b” => 2}
```

[There’s discussion happening at the moment](https://bugs.ruby-lang.org/issues/11076#note-22) on accepting this feature, which would make the above syntax:

```ruby
%w(foo foo bar foo baz foo).tally\_by { |s| s[0] }
=> {“f” => 4, “b” => 2}
```

### Why Use It?

If you’ve been using Ruby, chances are you’ve used code something like one of these lines to do the same thing `tally` is doing above:

```ruby
list.group_by { |v| v.something }.transform_values(&:size)

list.group_by { |v| v.something }.map { |k, vs| [k, vs.size] }.to_h

list.group_by { |v| v.something }.to_h { |k, vs| [k, vs.size] }

list.each_with_object(Hash.new(0)) { |v, h| h[v.something] += 1 }
```

There are likely several more variants of this, but those are a few of the more common ones you might see around. This is a nicety method to abbreviate a very common idiom in the Ruby language, and a very welcome one.

### Vanilla Ruby Equivalent

What does this method do? Well if we were to implement it in plain Ruby it might look a bit like this:

```ruby
module Enumerable
  def tally_by(&function)
    function ||= -> v { v }
   
    each_with_object(Hash.new(0)) do |value, hash|
      hash[function.call(value)] += 1
    end
  end

  def tally
    tally_by(&:itself)
  end
end
```

In the case of no provided function, it would effectively be tallying by itself, or rather an identity function.

> An identity function is a function that returns what it was given. If you give it 1, it returns 1. If you give it true, it returns true. Ruby also uses this concept in a method called itself.

This article will not go into great depth on what the above code does. Part Five of “Reducing Enumerable” covers this code in more detail:

[Reducing Enumerable — Part Five: Cerulean, Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

### The Source Code

Nobu recently committed a patch to Ruby core to add this method:

[enum.c: Enumerable#tally · ruby/ruby@673dc51](https://github.com/ruby/ruby/commit/673dc51c251588be3c9f4b5b5486cd80d46dfeee)

It was accepted by the Ruby core team under the name `tally`:

[Feature #11076: Enumerable method `count_by` - Ruby trunk - Ruby Issue Tracking System](https://bugs.ruby-lang.org/issues/11076#change-75622)

### Tally?

Let’s start with what the word means:

> A **tally** is a record of amounts or numbers which you keep changing and adding to as the activity which affects it progresses.

> - [https://www.collinsdictionary.com/us/dictionary/english/tally](https://www.collinsdictionary.com/us/dictionary/english/tally)

Now where did this name come from? Originally the name `count_by` was proposed, but the name was rejected as it differed from count which has a different return type and behavior.

On a car ride back from the Tahoe area and [RailsCamp West](https://west.railscamp.us/) we (myself, [David](https://twitter.com/d_jones), [Stephanie](https://twitter.com/stephanieblack), and [Shannon](https://twitter.com/_havenn)) were discussing potentially alternate names to try and propose to see if the feature could get in under a different name.

[David](https://twitter.com/d_jones) had proposed `tally`, and formally suggested it. It looks like the name stuck, and the code’s been merged into trunk.

Now I’d presented a talk at a few conferences, and decided to mention `tally_by` instead of `count_by` in my RubyConf talk in one section. The written version is over here:

[Reducing Enumerable — Part Five: Cerulean, Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

Just a bit of interesting backstory.

### Wrapping Up

2.7 is on its way, let’s see what it’ll bring! I’m looking forward to seeing where Ruby goes from here.
