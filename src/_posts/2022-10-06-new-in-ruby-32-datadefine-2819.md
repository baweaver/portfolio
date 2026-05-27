---
layout: "post"
title: "New in Ruby 3.2 - Data.define"
date: "2022-10-06"
categories: []
tags: []
description: "Victor Shepelev (Zverok) has just landed an extremely useful feature in Ruby, Data.define. You can..."
---

Victor Shepelev (Zverok) has just landed an extremely useful feature in Ruby, `Data.define`. You can find the merge here:

https://github.com/ruby/ruby/pull/6353

...and the Ruby discussion here:

https://bugs.ruby-lang.org/issues/16122

So what is it and what does it do? Well that's what we're going to take a look into.

## What it Does

Succinctly put `Data.define` creates an immutable `Struct`-like type which can be initialized with either positional or keyword arguments:

```ruby
Point = Data.define(:x, :y)
origin = Point.new(0, 0)
north_of_origin = Point.new(x: 0, y: 10)
```

> **Note:** This does not inherit from `Struct`

...and because the API supports pattern matching you can very much do things like this still:

```ruby
case origin
in Point[x: 0 => x, y] # rightward assignment, pattern matching
  Point.new(x:, y: y + 5) # shorthand hash syntax
else
  origin
end
```

It can also take a block for creating additional methods if you'd like, much like `Struct`:

```ruby
Point = Data.define(:x, :y) do
  def +(other) = new(self.x + other.x, self.y + other.y)
end
```

## Then Why Not Struct?

You can absolutely use `Struct` still. Given that why should you use `Data` instead?

Because it's stricter, and the values it produces are immutable. With the advent of more functional patterns in Ruby this can be a very useful thing.

Consider data passing in Ractors which requires immutable state, this becomes incredibly useful for value objects and message passing for what may inevitably be our next generation of Puma and other web servers.

## Why not dry-rb?

Interestingly the `dry-rb` folks are _very_ pragmatic about things like this. In fact some of their core folks are already talking about how to wrap this new feature into their immutable structs to build on top of it, rather than in parallel:

https://twitter.com/solnic29a/status/1577683251086376963

They did the same with pattern matching, and it's great to see how we build on top of what the language formally adopts.

## What Do You Think of It?

Personally? I like it. I plan to use it a lot in the REPL whenever I need a quick data type I can match against without pulling out a full `Struct` for it as often times I don't intend to mutate it and the `keyword_init` flag can be a bit pesky to remember.

It reminds me a lot of [case classes from Scala](https://docs.scala-lang.org/tour/case-classes.html):

```scala
case class Book(isbn: String)

val frankenstein = Book("978-0486282114")
```

...and of [data classes from Kotlin](https://kotlinlang.org/docs/data-classes.html):

```kotlin
data class User(val name: String = "", val age: Int = 0)
```

So this is not a novel concept, but a useful one for Ruby to adopt.

## Closing Thoughts

While the new language features have certainly slowed, in accordance with Matz's focus on tooling, we're still seeing some interesting movement in the language core. Of course there's a lot of fascinating tooling too, and I'm thrilled to see those coming to fruition, and perhaps soon I'll write about them as well.

In the mean time thanks to Zverok for seeing this through, and everyone who participated!
