---
layout: "post"
title: "Mf — Abusing Ruby’s Operator Precedence"
date: "2018-12-26"
categories: []
tags: ["ruby", "metaprogramming", "functional"]
description: "Abusing Ruby's proc coercion and operator precedence to create expressive functional combinators."
---

You may have seen Ruby 2.6’s Proc composition, but did you know there are far more operators you can abuse using Ruby’s proc coercion ( & )? Get ready for another wild ride!

<!-- ![](/images/posts/2018-12-26-mfabusing-rubys-operator-precedence/img-3a81a566.png) -->

## Proc Coercion

The first step to understanding what we’re about to get into is what Ruby is doing with the ampersand ( & ). In short, it’s called proc coercion, or rather coercing an object into a proc / function.

You may have seen this in the shorthand syntax for map, but never really understood what it was doing:

```ruby
[1, 2, 3].select(&:even?)
```

The above code selects all even numbers, and expands to be effectively the same as this code:

```ruby
[1, 2, 3].select { |n| n.even? }
```

The question becomes how does that work? Well the ampersand in Ruby coerces an object into a proc, effectively the same as saying this:

```ruby
is_even = :even?.to_proc
=> #<Proc:0x00007ff8cd0c1570(&:even?)>
```

…which can be called much the same as any other proc:

```ruby
is_even.call(2)
=> true
```

That brings us to the next subject, composition.

## Proc Composition

Proc composition is the art of joining two procs or functions together to make a new function that executes both:

```ruby
add_one = -> x { x + 1 }
multiply_by_five = -> x { x * 5 }

do_both = add_one << multiply_by_five

do_both.call(6)
=> 31

[1, 2, 3].map(&do_both)
=> [6, 11, 16]
```

Though here’s the interesting thing, operators happen to apply *before* the ampersand coerces something to a proc for Ruby. This means you can do the following:

```ruby
[1, 2, 3].map(&add_one << multiply_by_five)
=> [6, 11, 16]
```
> Note that you can use either << or >> for composition, the other just changes the “direction” it gets composed in.

Now that’s interesting. If it works with the shovel operator, who’s to say it doesn’t work with *other* operators as well.

Before we get into that though, let’s take a quick look into closures as a refresher.

## Closures

A closure is a proc remembering the context it was defined in. That’s a bit wordy though, so let’s take a quick look at what that means.

```ruby
adds = -> x { -> y { x + y } }
=> #<Proc:0x00007fca97980df0@(pry):9 (lambda)>

adds_one = adds.call(1)
=> #<Proc:0x00007fca979f26d0@(pry):9 (lambda)>

adds_one.call(2)
=> 3
```

Our adds function is returning another function, and that function remembers the context it was defined in. In simpler terms, it still remembers what x was from when it was created which was 1.

We could use it inline as well if we wanted to:

```ruby
[1, 2, 3].map(&adds.call(5))
=> [6,7,8]
```

What does that have to do with anything though? Well operators have a fun little property to them in Ruby, and remember that shovel<< is an operator.

## Operators are Methods

Now remember how operators are essentially just methods? If not, they work like this:

```ruby
1.+(3)
=> 4
```

Ruby just makes that go away magically at run time using some magic to make it nicer to type out. Granted that’s a gross simplification, but it will do for the purposes of this article.

Given that they’re methods, that means we can define our own classes with operators:

```ruby
class Foo
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def +(other)
    self.class.new(other.value + self.value)
  end
end

Foo.new(5) + Foo.new(10)
=> #<Foo:0x00007fca978ffe30 @value=15>
```

Now that’s interesting, but what if we took it one step further? Remember closures from earlier? Oh yes.

## The Emergence of Mf

You see, I’d spent some time in Scala and I’d rather liked this bit of shorthand syntax:

```ruby
List(1, 2, 3).map(_ + 5)
```

Nice, succinct, and really danged handy to have. In other words I really wanted it in Ruby, and as one does I decided to use some of the tools above to make a new idea: Mf (Modifier Functions).

Let’s take a look into a basic variant of it:

```ruby
module Mf
  def self.+(value)
    -> other_value { value + other_value }
  end
end

add_one = Mf + 1
=> #<Proc:0x00007fca979b2800@(pry):52 (lambda)>

add_one.call(2)
=> 3
```

Remembering from earlier, that means we can inline it like so:

```ruby
[1, 2, 3].map(&Mf + 5)
=> [6, 7, 8]
```

Fast forward to defining all the operators and you can imagine where it went from here.

Do remember though that [] is also a method, which means for all those pesky JSON blobs you can hash out one level like so:

```ruby
json_data.map(&Mf['name'])
```

## Wrapping Up

If you want to check out Mf for single-level operators, take a look:
[**baweaver/mf**
*Mf - Modifier functions. Contribute to baweaver/mf development by creating an account on GitHub.*github.com](https://github.com/baweaver/mf)

But what if you wanted to do multiple levels? Well that’s a story for another day and a good deal of madness that would make this a very long article indeed.

In the mean time, meditate on the fact that & coerces things into procs, and one could intercept any operator called on an object and keep track of all of them, waiting for that eventual proc coercion.

Sound confusing? Great! That means it’ll be an especially fun article to read later.

We call those Sf, or Stack Functions, and they’re all types of extra fun. Give it a read!
[**Sf — Abusing Operators and Method Missing**
*Now if you thought Mf was bad, that’s just the tip of the proverbial iceberg. Sf is oh so much worse, and that’s what…*medium.com](/writing/2018/12/27/sfabusing-operators-and-method-missing/)

In the mean time, happy holidays and happy hacking!
