---
layout: "post"
title: "On Dealing with Deep Hashes in Ruby — XF — Part Two: Traces"
date: "2018-04-25"
categories: []
tags: ["ruby", "functional"]
description: "Part two of the Xf series, exploring Traces for recursively searching and transforming values in deep hashes."
---

Xf is a Ruby gem meant for transforming and searching deep hashes, inspired loosely by Lenses in Haskell.
[**baweaver/xf**
*xf — Xf — Transform Functions*github.com](https://github.com/baweaver/xf)

Xf is short for Transform Functions, or XForm Functions.

This is part two of the series, and this time we’re going to be looking into Traces in Xf.

A Trace is a way to dive down until you find a matching key, value, or both anywhere in a hash. It’s a concept born from trying to navigate large amounts of JSON that tend to stash the same named keys in variable areas, and needing to either get their values or change them all in one fell swoop.

Since map.map.compact.flat_map.compact.argh gets a bit tedious to do, Trace became my way to deal with it in a more succinct way. Let’s dive in to how they work!

## Trace — Recursing Dive

The thing about Trace is it has to dive to every corner of a hash to get the values it cares about. Question is, how can we achieve that in a generic way that can be used for both getting and setting values on that Hash?

Three tools: yield, next, and recursion:

```ruby
**private def recursing_dive(target_hash, &fn)**
  target_hash.each { |k, v|
    yield(target_hash, k, v) if match?(
      target_hash, k, v, @trace_path
    )

    next unless target_hash[k].is_a?(Hash)
    recursing_dive(target_hash[k], &fn)
  }
**end**
```

Now how does this work? First, for reference, @trace_path is a single path:

```ruby
class Trace
  def initialize(trace_path)
    @trace_path = trace_path
  end
```

It takes in a target hash to dive into, and it checks if there’s a match as defined here:

```ruby
private def match?(hash, key, value, matcher)
  **matcher === key**
end
```

So why in the world would I pass in four values if I only need two of them? Well we’ll get to that later, but the short version is inheritance overrides for different types of Trace.

Anyways, if it happens to match (using === because it’s so danged powerful), that value gets yielded to the caller:

```ruby
private def recursing_dive(target_hash, &fn)
  target_hash.each { |k, v|
    **yield(target_hash, k, v)** if match?(
      target_hash, k, v, @trace_path
    )

    next unless target_hash[k].is_a?(Hash)
    recursing_dive(target_hash[k], &fn)
  }
end
```

## Trace — Getter

So what’s the caller? Well we have both the getter and setter using it, but we’ll start with the getter first:

```ruby
def get_value(hash)
  retrieved_values = []
  recursing_dive(hash) { |h, k, **v**| **retrieved_values.push(v)** }
  retrieved_values
end
```

That’s it? Yep. All it does is dive through the hash and push whatever value it finds that matches into an Array we return back at the end.

## Trace — Setter

Remember how we have access to the hash and key though? That comes in real handy for the setter method:

```ruby
def set_value!(hash, value = nil, &fn)
  recursing_dive(hash) { |h, k, v|
    **h[k] = block_given? ? yield(v) : value**
  }
  
  hash
end
```

After it gets down to a matching value, we just overwrite that value with one of two things.

If it was called with a value:

```ruby
**Xf.trace(:deep_value).set(5)**
```

Then every key matching :deep_value will now have its value set to 5.

If it was called with a block:

```ruby
**Xf.trace(:age).set { |v| v + 1 }**
```

Well happy birthday to everyone in that list!

Note that set_value and get_value are the non-proc versions of the method. I would use currying like in more functional languages, but the performance penalties are a bit steep.

If you’re worried about the mutation of the hash remember I have a habit of using mutation methods to do the dirty work and using clone to mask the side-effects:

```ruby
def set_value(hash, value = nil, &fn)
  set_value!(**deep_clone**(hash), value, &fn)
end
```

So if you care about keeping things looking clean you’re set!

Now then, back to our recursing dive

## Trace — Recursing

Now that we’ve seen what calls it, when does it decide to keep going?

```ruby
private def recursing_dive(target_hash, &fn)
  target_hash.each { |k, v|
    yield(target_hash, k, v) if match?(
      target_hash, k, v, @trace_path
    )

    **next unless target_hash[k].is_a?(Hash)**
    recursing_dive(target_hash[k], &fn)
  }
end
```

If the target value happens to be a Hash, we know there’s more to explore out there so grab your snorkel because it’s dive time!

Eventually I plan to refactor this a bit to deal with Arrays as well, but that may well be tempting the recursion stack demons a bit too much. Also target_hash[k] is literally v so there are most certainly other refactors to happen as well.

That’s pretty much all there is to a Trace though, check it out for yourself:
[**baweaver/xf**
*xf - Xf - Transform Functions*github.com](https://github.com/baweaver/xf/blob/master/lib/xf/trace.rb)

## Wrapping Up

That’s it for part two, you now know how to make a recursive descent for hashes to find values! There are lots of fun things you can do with it, but with great power comes great hackery, mayhem, and apparently posts on Medium shortly afterwards to show it off.

Part three will likely cover Evolution from Rambda and how it’s potentially implemented in Ruby, but I kinda need to do it first so it may take a week or two to do properly:
[**Ramda Documentation**
*Makes a shallow clone of an object, setting or overriding the nodes required to create the given path, and placing the…*ramdajs.com](http://ramdajs.com/docs/#evolve)

Either that or more Qo work considering the Pattern Matching Renaissance in the Ruby bug tracker:
[**Feature #14709: Proper pattern matching - Ruby trunk - Ruby Issue Tracking System**
*Redmine*bugs.ruby-lang.org](https://bugs.ruby-lang.org/issues/14709)

I might have written an entire post or two worth of content on pattern matching over there, fascinating stuff, you all should chime in too!

Well, that’s that. Go give Xf a try and let me know what you think.
[**baweaver/xf**
*xf - Xf - Transform Functions*github.com](https://github.com/baweaver/xf)

Enjoy!

baweaver
