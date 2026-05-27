---
layout: "post"
title: "On Dealing with Deep Hashes in Ruby — XF — Part One: Scopes"
date: "2018-04-24"
categories: []
tags: ["ruby", "functional"]
description: "Introducing Xf, a Ruby gem for transforming deep hashes using functional scopes inspired by Haskell lenses."
---

Xf is a Ruby gem meant for transforming and searching deep hashes, inspired loosely by Lenses in Haskell.
[**baweaver/xf**
*xf - Xf - Transform Functions*github.com](https://github.com/baweaver/xf)

Xf is short for Transform Functions, or XForm Functions. (Ok ok, fine, tf was taken)

This round of article we're going to take a look at how to utilize yield, blocks, and some other foundational functional elements in Ruby to make a flexible and extensible transformation library.

As to where this idea came from, typically dealing with too much JSON data in one form or another can get incredibly tedious, especially if you have to modify it. Compound that issue when you introduce arbitrarily deep keys you care about, notably if they're never quite in the same place. It's quite vexing, really.

Shall we dive in then?

## Scopes — Getters

A scope is a very light version of a Haskell Lense. Its purpose is entirely to define a static path that we care about and allow us to either extract or modify the value of what we find down that path.

In some cases we may even want to just mutate in place in the case of having to transform a good deal of JSON.

Let's take a look at the public api from Xf and how it looks:

```ruby
people = [{name: "Robert", age: 22}, {name: "Roberta", age: 22}]
age_scope = Xf.scope(:age)

people.map(&age_scope.get)
# => [22, 22]
```

So we can get a value, what's so different from the Vanilla variant? It's shorter too:

```ruby
people.map { |x| x[:age] }
```

True, but what if you want to go a bit deeper? get actually uses dig under the hood, meaning anything there is fair game. Let's take a look at how one might do that with a function:

```ruby
getter = -> *paths { -> object { object.dig(*paths) } }
people.map(&getter[:age])
```

Same result, we're essentially just closing over the value paths. Now the thing about Ruby is, it's Object Oriented, and classes are actually a good solution here:

```ruby
class Scope
  def initialize(*paths)
    @paths = paths
  end

  def get
    Proc.new { |object| object.dig(*@paths) }
  end
end
```

What we're doing is using the class to keep a hold of our paths, and using the get method to simply return us a proc so we can throw it straight to a block with an `&` prefix.

Turns out the actual implementation isn't that far different, Xf does give another variant though for more normal use:

```ruby
class Scope
  def initialize(*paths)
    @paths = paths
  end

  def get
    Proc.new { |o| get_value(o) }
  end

  def get_value(object)
    object.dig(*@paths)
  end
end
```

If you're just wrapping a straight series of arguments, you might be tempted to use method. Turns out Proc is actually a hair faster:

```ruby
task :proc_vs_method do
  class Scope
    def initialize(*ps) @ps = ps                       end
    def get_m;          method(:get_value)             end
    def get_p;          Proc.new { |o| get_value(o) }  end
    def get_value(o)    o.dig(*@ps)                    end
  end

  age_scope = Scope.new(:age)
  people    = [{name: "Robert", age: 22}, {name: "Roberta", age: 22}]

  run_benchmark('Proc vs Method',
    'method': -> { people.map(&age_scope.get_m) },
    'Proc':   -> { people.map(&age_scope.get_p) }
  )
end
```

```
➜  xf git:(master) ✗ rake proc_vs_method

Proc vs Method
==============

method result: [22, 22]
Proc result: [22, 22]

Warming up --------------------------------------
              method    60.748k i/100ms
                Proc    76.871k i/100ms
Calculating -------------------------------------
              method    736.226k (± 3.2%) i/s -      3.706M in   5.038518s
                Proc    938.803k (± 7.1%) i/s -      4.689M in   5.020202s

Comparison:
                Proc:   938802.6 i/s
              method:   736226.4 i/s - 1.28x  slower
```

Odd, can't say I knew that one before, but here we are eh? Just for kicks though, looks like the gap is even wider with TruffleRuby:

```
Warming up --------------------------------------
              method   323.163k i/100ms
                Proc   522.297k i/100ms
Calculating -------------------------------------
              method      4.265M (±24.3%) i/s -     18.743M in   4.999134s
                Proc      7.301M (±20.9%) i/s -     32.905M in   4.999996s

Comparison:
                Proc:  7300546.9 i/s
              method:  4265477.9 i/s - 1.71x  slower
```

Now what about those setters? That's where we get into some fun!

## Scopes — Setters

Now the nifty part about that class is we already have access to where we need to go with the path, we just need to go and set something on it!

Well, I'm here to tell you a dirty little secret about some of my functional style in Ruby: I mutate things, a lot. I just stick a clone on top of them for safe-keeping.

Often times one can implement a clean version of the function with a combination of a mutating function and clone, and in Ruby a clone is fairly straightforward:

```ruby
def deep_clone(hash) Marshal.load(Marshal.dump(hash)) end
```

If you want an exhaustive look at Marshalling, give this a look:
[**Ruby Marshalling from A to Z • Ilya Bylich**
*Marshalling is a serialization process when you convert an object to a binary string. Ruby has a standard class Marshal…*ilyabylich.svbtle.com](https://ilyabylich.svbtle.com/ruby-marshalling-from-a-to-z)

Anyways, we know we can effectively clone, so let's get to our [dirty mutating function](https://github.com/baweaver/xf/blob/master/lib/xf/scope.rb#L82) then.

```ruby
def set_value!(hash, value = nil, &fn)
  lead_in    = @paths[0..-2]
  target_key = @paths[-1]

  new_hash = hash
  lead_in.each { |s| new_hash = new_hash[s] }

  new_value = block_given? ?
    yield(new_hash[target_key]) :
    value

  new_hash[target_key] = new_value

  hash
end

# Hehehehehehe
def set_value(hash, value = nil, &fn)
  set_value!(deep_clone(hash), value, @fn)
end
```

Now that's a bit dense. What are we doing here?

The idea for setting, or burying, a value in a hash is that we must first dive down to the point where we want to leave the value. What we're doing is using all the segments of our path except the last to dig down, redefining our target hash as we go.

Once that target is hit, we want to set the value at that target key equal to our new value. When a block is passed we first give that old value to a block to do whatever with it, otherwise we just take a static value.

Now this could also be done with reduce, but there's a nibble of a speed hit I tend to avoid in libraries:

```ruby
def set_value!
  *lead_in, target_key = @paths

  dive_hash = lead_in.reduce(hash) { |h, s| h[s] }
  dive_value = block_given? ?
    yield(dive_hash[target_key]) : value

  dive_hash[target_key] = new_value
  hash
end
```

More succinct, yes, but also a hair slower:

```
Reduce vs Each
==============

reduce result: {:a=>{:b=>{:c=>{:d=>{:e=>{:f=>5}}}}}}
each result: {:a=>{:b=>{:c=>{:d=>{:e=>{:f=>5}}}}}}

Warming up --------------------------------------
              reduce    91.033k i/100ms
                each   113.241k i/100ms
Calculating -------------------------------------
              reduce      1.172M (± 3.4%) i/s -      5.917M in   5.055598s
                each      1.557M (± 3.2%) i/s -      7.814M in   5.025450s

Comparison:
                each:  1556526.1 i/s
              reduce:  1171768.9 i/s - 1.33x  slower
```

Oddly TruffleRuby has them roughly the same, but margin of error is a bit touchy:

```
Reduce vs Each
==============

reduce result: {:a=>{:b=>{:c=>{:d=>{:e=>{:f=>5}}}}}}
each result: {:a=>{:b=>{:c=>{:d=>{:e=>{:f=>5}}}}}}

Warming up --------------------------------------
              reduce   657.298k i/100ms
                each   820.712k i/100ms
Calculating -------------------------------------
              reduce     13.626M (±11.9%) i/s -     65.073M in   5.018597s
                each     14.576M (±13.1%) i/s -     69.761M in   5.031806s

Comparison:
                each: 14575975.3 i/s
              reduce: 13626106.1 i/s - same-ish: difference falls within error
```

It's interesting to me, though, that some of the more functional type techniques are within closer distance on average in TruffleRuby, but that's a subject for another day perhaps.

> Note these aren't exactly scientific benchmarks as I'm running in a fairly browser heavy environment at the moment looking through references. I'll likely start porting a lot of these stats through on CI later.

## Lessons Learned from Scopes

According to a few Haskell programmers there's a lot more to Lenses to shamelessly rip off for Ruby, so I'll have to look into that for later. They're composable among a few other things, so it's back to reading for me.

Now, Scopes are all well and good, but what about those really pesky values you don't remember where they got hidden at? Ah, that's what Traces are for!

We'll be covering those next article, and it'll be a treat. Scopes were relatively tame compared to some of the fun you can have with a Trace.

Go give Xf a try:
[**baweaver/xf**
*xf - Xf - Transform Functions*github.com](https://github.com/baweaver/xf)

Enjoy!

Part Two is now live:
[**On Dealing with Deep Hashes in Ruby — XF — Part Two: Traces**
*Xf is a Ruby gem meant for transforming and searching deep hashes, inspired loosely by Lenses in Haskell.*medium.com](/writing/2018/04/25/on-dealing-with-deep-hashes-in-ruby-xf-part-two-traces/)
