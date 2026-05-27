---
layout: "post"
title: "Tales of the Ruby Grimoire - Part Four - The Lemurs of Haskell"
series: "tales-ruby-grimoire"
date: "2019-08-04"
categories: ["ruby", "haskell"]
tags: ["ruby", "haskell"]
description: "Dark tales of Ruby magics from beyond what any sane Rubyist would teach in a book of legends, opened by a particularly curious young lemur named Red."
---

This is a text version of a talk given at Southeast Ruby 2019, and the first of many tales of the legendary Ruby Grimoire, a great and terrible book of Ruby dark magics.

I've broken it into sectional parts so as to not overwhelm, as the original talk was very image heavy. If you wish to skip to other parts, the table of contents is here:

**Table of Contents**

1. [Part One - The Grimoire](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-one-the-grimoire-2712/)
2. [Part Two - The Lemurs of Scala](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-two-the-lemurs-of-scala-3d1e/)
3. [Part Three - The Lemurs of Javascript](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-three-the-lemurs-of-javascript-5ac9/)
4. [Part Four - The Lemurs of Haskell](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-four-the-lemurs-of-haskell-3p4f/)
5. [Part Five - On the Nature of Magic](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-five-on-the-nature-of-magic-g63/)

# Tales of the Ruby Grimoire - Part Four - The Lemurs of Haskell

Wherein Red learns from the Lemurs of Haskell about arts of lenses.

## Introducing the Lemurs of Haskell

![Crimson introduces the lemurs of Haskell](/images/posts/tales-ruby-grimoire/img-68e58bcb.png)

Now I have one last lesson for you, from the wise sages of the realms of Haskell.

![The Lemurs of Haskell](/images/posts/tales-ruby-grimoire/img-1bf57c16.png)

Descended from their ivory towers, they bring knowledges far beyond even me, but knowledges of fascinating implications that shake the very foundations of the way we think about programming!

They bring with them the art of lenses, an ability to focus on something and either see or change its value. I cannot say I fully comprehend them, but find them fascinating.

## On Lenses

![Orchid showing lenses](/images/posts/tales-ruby-grimoire/img-f437d7a9.png)

Lenses allow the lemurs of Haskell to look deeply into a nested data structure and perform magics on those datas without mutating them.

The examples they told me from the books of Hackage were confusing at first, so I took some liberties in trying to make it understandable for myself.

I cannot say I understand how `makeLenses` beyond that they fill in a lot of code that makes lenses work but I may be able to explain the rest:

```haskell
import Control.Lens hiding (element)
import Control.Lens.TH
{-# LANGUAGE TemplateHaskell #-}

data Atom =
  Atom { _element :: String, _point :: Point }

data Point =
  Point { _x :: Double, _y :: Double }

$(makeLenses ''Atom)
$(makeLenses ''Point)

moveNorth :: Atom -> Atom
moveNorth = over (point . y) (+ 1)
```

We have datas of `Atom` and `Point`, with an `Atom` containing a `Point`. We make lenses for both of them:

```haskell
-- Atom  = [ element, point ]
-- Point = [ x, y ]

$(makeLenses ''Atom)
$(makeLenses ''Point)

moveNorth :: Atom -> Atom
moveNorth = over (point . y) (+ 1)
```

...and we create a function that moves an `Atom` to the North that returns a new atom, presumably moved to the north.

Now the point has an `x` and `y` coordinate, but what is that function doing?

Let’s simplify that a bit more to my understanding:

```haskell
-- Atom  = [ element, point ]
-- Point = [ x, y ]

moveNorth = over (point . y) (+ 1)
```

`over` is a function that allows us to execute a function `over` something which looks like or behaves like a `lense`. We’re doing something over the `Atom`’s point, specifically its’ `y` point, and `over` that `y` point we add one.

The lense allows us to specify a path to something, and run functions `over` them or to get values out of those structures.

## Lenses in Ruby? `dig`!

![Red trying lenses](/images/posts/tales-ruby-grimoire/img-1c35aa32.png)

This all seems rather abstract, but you may already know of the Ruby method `dig`, which is one half of the idea of a lense, the `get`.

```ruby
hash = { a: { b: { c: 1 } } }
hash.dig(:a, :b, :c)
=> 1
```

It allows us to dig to find a value that’s deeply nested in a Hash or an Array, or even a mix of both. The thing to pay attention to here though is that path:

```ruby
:a, :b, :c
```

So if we wanted to try and apply such a thing to Ruby, it may be a bit difficult, but we can come close. Remember, Red, a Haskell lemur I am not.

## Making a "Lense"

![Red and Orchid trying to make a lense](/images/posts/tales-ruby-grimoire/img-15e8d4fe.png)

For the sake of this exercise we can assume we have a set of hashes with a nested `a, b, c` with the values being `1` up to `5`:

```ruby
hashes = (1..5).map { |n|
  { a: { b: { c: n } } }
}
=> [{:a=>{:b=>{:c=>1}}}, …]
```

We’ll be using these to demonstrate.

We can start with the idea of capturing a path in a class which we can call Scope. See? It sounds like Lense!

```ruby
class Scope
  def initialize(*paths)
    @paths = paths
  end
end
```

In it we want to capture the idea of our path from earlier.

### `Scope#get`

The first thing we would need to do is have a way to get values. We can wrap `dig` in a function to do just this.

```ruby
class Scope
  def get
    -> collection {
     collection.dig(*@paths)
    }
  end
end
```

Because it returns a function we can use it much the same way as our placeholder class.


```ruby
scope = Scope.new(:a, :b, :c)
hashes.map(&scope.get)
=> [1, 2, 3, 4, 5]
```

Now setting? Setting is much harder.

### `Scope#deep_clone`

The first thing we need to do to set is to clone the object to make sure we’re not mutating something we don’t want to. This is a quick way to deep clone a hash that I found on _Lemur Lemur Go_ a few years back. I don’t entirely know what it’s doing but it works and it clones deeply!

```ruby
class Scope
  def deep_clone(hash)
    Marshal.load(Marshal.dump(hash))
  end
end
```

_ (The author does know what this does) _

### `Scope#set`

We start by wrapping it in a function which takes either a `value` or a `function` to transform the value it finds, and inside that function…

```ruby
class Scope
  def set(value = nil, &fn)
    -> collection { … }
  end
end
```

We clone the initial collection to make it "mutation-free". The Lemurs of Haskell are not particularly amused with my notion of statelessness, but close enough for now.

```ruby
cloned_collection = deep_clone(collection)
```

Then we get the path we need to take to set our new value:

```ruby
*lead_in, target_key = @paths
```

In our initial get example we used `a, b, c`, so let’s say it’s the same here. That would make our path to where we want to set a value:

```ruby
*lead_in, target_key = [:a, :b, :c]
# lead_in = [:a, :b], target_key = :c
```

Now that we know where we're looking we can get to our target:

```ruby
target_location = cloned_collection
  .dig(*lead_in)
```

Personally I find it quite amusing and a tinge ironic that you have to `dig` to `bury` something. We don't `dig` all the way to the bottom, because setting `1 = 1` won't work too well.

We need to override the value at one level above to make sure it sticks, but what value do we use?

```ruby
new_value = block_given? ?
  yield(target_location[target_key]) :
  value
```

If we're given a block we yield that target value to it, but if not we fall back to that value above.

Say we did get a function though and our first hash, it'd look like this:

```ruby
# block:           -> x { x + 1 }
# target_location: { c: 1 }
# target_key:      :c
new_value = yield(target_location[target_key])
=> 2
```

It would yield to a function that adds one, and the target value would be one itself.

The question now is how to make it stick! Why by overwriting the key where the value exists, which is why we need the `lead_in` too:

```ruby
target_location[target_key] = new_value
```

Now whatever we get from that new value we overwrite the target location at the target key to point it to that new value instead!

The Haskell lemurs were very put off with me for this, but again, it works, so I don’t tend to pay them too much mind.

If we were to use it on a group of hashes it could deeply set a value according to a path:

```ruby
class Scope
  def set(value, &fn) …
end

scope = Scope.new(:a, :b, :c)
hashes.map(&scope.set { |v| v + 1 })
=> [{:a=>{:b=>{:c=>2}}}, {:a=>{:b=>{:c=>3}}}, {:a=>{:b=>{:c=>4}}}, {:a=>{:b=>{:c=>5}}}, {:a=>{:b=>{:c=>6}}}]
```

If we were to use it on a group of hashes it could deeply set a value according to a path.

Now imagine the possibilities if these paths used `===` to traverse instead, or kept searching until they found the first path, it could be very interesting indeed! I can’t say I’ve written too much more on the lemurs of Haskell, I believe they don’t like me for some reason.

_It should also be noted that the author does not necessarily agree with the Dark Lord Crimson, and likes to poke fun_

## Going Beyond Magics

![Crimson explaining to Red](/images/posts/tales-ruby-grimoire/img-b6f5ecc5.png)

Red was fascinated by all the implications of Crimson’s tales, the possibilities, and what else may lay in the Grimoire.

"How many more tales are there?" asked Red

"Oh many many more, from tribes and societies far and wide beyond all things. From the curmudgeonly Java lemurs to the mystic Lisp lemurs, all the way to the orderly Python lemurs and beyond! These were but a few of the many tales." said Crimson in reply.

![Crimson in swirling magics of the cosmos](/images/posts/tales-ruby-grimoire/img-6b0b6f27.png)

"There’s an entire universe out there, powers beyond imagination, and so many more chapters of the Grimoire to learn from! Imagine the potential if we learned from all the lemurs out there, of all their tricks and magics! We would be unstopa…"

![The Grimoire snaps shut](/images/posts/tales-ruby-grimoire/img-b72276c6.png)

…then there was a sharp snap, and a crackle as the Grimoire closed behind them, the magic disappearing.

![Scarlet is not amused with Red](/images/posts/tales-ruby-grimoire/img-8b1e0612.png)

So Red turned around slowly, and what he saw behind him scared him much more than the Dark Lord Crimson ever had. Scarlet was back, and she was not amused.

## End of Part Four

This ends Part Four, and with it comes even more resources. `dig` is indeed in Ruby core, but `bury` or a `set` type method is a hotly contested subject. There are so many ways to do it, but no consensus quite yet.

Resources though, enjoy! I'd definitely look at adit.io before the other Haskell sections as it's a bit more accessible.

* [Xf - Transform Functions](https://github.com/baweaver/xf)
* [On Dealing with Deep Hashes in Ruby Pt 1](/writing/2018/04/24/on-dealing-with-deep-hashes-in-ruby-xf-part-one-scopes/)
* [On Dealing with Deep Hashes in Ruby Pt 2](/writing/2018/04/25/on-dealing-with-deep-hashes-in-ruby-xf-part-two-traces/)
* [adit.io's illustrated Lense tutorial](http://adit.io/posts/2013-07-22-lenses-in-pictures.html)
* [Hackage - Lenses](http://hackage.haskell.org/package/lens)
* [Hackage - Lense Examples](https://github.com/ekmett/lens/wiki/Examples)

**Table of Contents**

1. [Part One - The Grimoire](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-one-the-grimoire-2712/)
2. [Part Two - The Lemurs of Scala](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-two-the-lemurs-of-scala-3d1e/)
3. [Part Three - The Lemurs of Javascript](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-three-the-lemurs-of-javascript-5ac9/)
4. [Part Four - The Lemurs of Haskell](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-four-the-lemurs-of-haskell-3p4f/)
5. [Part Five - On the Nature of Magic](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-five-on-the-nature-of-magic-g63/)
