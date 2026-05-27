---
layout: "post"
title: "Functional Programming in Ruby — Closures"
series: "functional-programming-ruby"
date: "2018-05-13"
categories: []
tags: ["ruby", "functional"]
description: "Understanding closures in Ruby — how functions can capture and remember their surrounding context."
---

One of the most powerful features of Functional Programming that we can leverage in Ruby is the concept of a Closure.

That said, what in the world is a closure and what does it do?

## An Example to Start

Let's say we have a function that returns another function:

```ruby
adder = proc { |a|
  proc { |b| a + b }
}
```

If we were to call this function, we would get back another function. Let's call it add3:

```ruby
add3 = adder.call(3)
```

Now why is that useful? Well we could pass it to a function like map to start:

```ruby
[1, 2, 3].map(&add3)
# => [4, 5, 6]
```

## Hold on, how did it remember that?

The function remembered that a was 3. How exactly was that?

A closure is a function which remembers the context it was created in.

That means that inside that returned function, anything around it is absolutely fair game to get a hold of.

## It counts for something

Consider the idea of a counter. In Ruby we might make a class for this:

```ruby
class Counter
  attr_reader :count

  def initialize(count = 0)
    @count = count
  end

  def increment(n = 1)
    @count += 1
  end
end

c = Counter.new
# => #<Counter:0x00007fb9353179f0 @count=0>
c.increment
# => 1
c.increment
# => 2
```

You could also use a closure for the same idea:

```ruby
counter = proc {
  count = 0

  {
    increment: proc { |n = 1| count += n }
  }
}

c = counter.call
# => {:increment=>#<Proc:0x00007fb9352d3b10@(pry):19>}
c[:increment].call
# => 1
c[:increment].call
# => 2
```

> Wait, proc arguments can take defaults!? Yep. Anything you can put in a method signature is fair game in a block's argument list. There are some interesting things you can do with this, but that's beyond the scope of this particular article. Spoilers for the fun one though: they can take a block as an argument too.

Now granted that's not incredibly practical in Ruby. Even the class has a shorter variant:

```ruby
counter = (1..Float::INFINITY).to_enum
# => #<Enumerator: ...>
counter.next
# => 1
counter.next
# => 2
```

You can even get it to count by multiples too:

```ruby
counter = (1..Float::INFINITY).step(5).to_enum
# => #<Enumerator: ...>
counter.next
# => 1.0
counter.next
# => 6.0
counter.next
# => 11.0
```

Though this quickly gets into a discussion on Enumerators and Lazyness, which we'll save for another post. Try it with letters too, they're loads of fun!

## Wait, didn't that class "remember" too?

Now that's a fun point. Classes are, in ways, an approximation for closures. They encapsulate a bit of state and allow you to modify it through a defined API (fancy talk for methods you can call on it.)

A fair argument to make would be that they're not really functions and can't act li…

```ruby
class Adder
  def initialize(n)
    @n = n
  end

  def to_proc
    proc { |v| @n + v }
  end
end

[1, 2, 3].map(&Adder.new(5))
# => [6, 7, 8]
```

Well that may be, but new is cumbersome, we want to be able to use some of our Proc-like methods kinda like…

```ruby
class Adder
  def initialize(n)
    @n = n
  end

  def to_proc
    proc { |v| @n + v }
  end

  def call(v)
    self.to_proc.call(v)
  end

  alias_method :===, :call

  class << self
    def call(n)
      new(n)
    end

    alias_method :[], :call
  end
end

[1, 2, 3].map(&Adder[15])
# => [16, 17, 18]
[1, 2, 3].map(&Adder.(7))
# => [8, 9, 10]
```

As it turns out, classes can make some very fair approximations of some closure-like behavior by either implementing the methods themselves or just straight inheriting from a Proc.

## In the Wild

Personally I use this trick a lot for libraries like [Qo](https://github.com/baweaver/qo) and [Xf](https://github.com/baweaver/xf), mostly because it allows for inheritance to stack on top of it, redefining what it means to express them as functions. A particularly fun example of this is in the [Guard Block matcher from Qo](https://github.com/baweaver/qo/blob/83577f80a47015e60d833da62a1220a08c00482d/lib/qo/matchers/guard_block_matcher.rb):

```ruby
require 'qo'
# => true
matcher = Qo.m('baweaver', :*) { |(name, _)| "It's the creator" }
# => #<Qo::Matchers::GuardBlockMatcher:0x00007fb2ae983d08
#  @array_matchers=["baweaver", :*],
#  @fn=#<Proc:0x00007fb2ae983c18@(pry):2>,
#  @keyword_matchers={},
#  @type="and"
# >
matcher.call(['baweaver', 'something'])
# => [true, "It's the creator"]
matcher.call(['havenwood', 'something'])
# => [false, false]
```

We'll get to the array return in a second, but let's take a look at how it's different from a regular matcher which just returns true or false:

```ruby
# Overrides the base matcher's #to_proc to wrap the value in
# a status and potentially call through to the associated block
# if a base matcher would have passed
#
# @return [Proc[Any] - (Bool, Any)]
#   (status, result) tuple
def to_proc
  Proc.new { |target|
    super[target] ? [true, @fn.call(target)] : NON_MATCH
  }
end
```

The Guard Block inherits from a regular matcher, meaning if it would have matched before it knows it can call the guarded function.

So why the Array return? What if the guarded block returns false? How do we know that was a match? The secret there is it returns an additional piece of state with it to let us know that it did indeed match, and that the value that guard block returned was indeed falsy.

This is similar to a concept I'll cover in a future article about Some and None types to wrap that concept. The only reason I don't use that in Qo is to keep it lightweight and not impose any additional ideas on someone's applications.

## Wrapping Up

As mentioned before, Functional Programming and Object Oriented programming are not such different concepts as much as different ways to express some of the same ideas.

Given that Ruby does both, we can leverage ideas from both domains to get even more expressive code.

If you haven't yet, I would highly recommend taking a brief stint in Scala to see another OO / FP language that leans more heavily towards FP. This book does a great job of building into those concepts:
[**Functional Programming in Scala**
*Leads to deep insights into the nature of computation.*www.manning.com](https://www.manning.com/books/functional-programming-in-scala)

If Javascript is more your thing, there are also a few good reads in that domain:
[**Functional Programming in JavaScript**
*This book transformed the way that I think about and write JavaScript.*www.manning.com](https://www.manning.com/books/functional-programming-in-javascript)
[**Functional JavaScript**
*How can you overcome JavaScript language oddities and unsafe features? With this book, you'll learn how to create code…*shop.oreilly.com](http://shop.oreilly.com/product/0636920028857.do)

There's an abundance of good ideas in other languages, so don't be afraid to journey out and learn from them. If there's enough demand for it, I could be convinced to write up a FP reading list as well so let me know in the comments or on Twitter @keystonelemur!

Enjoy!

The next article is on Flow Control:
[**Functional Programming in Ruby — Flow Control**
*Flow control in Functional Programming is an idea that is a bit harder to wrap your head around as a primarily Object…*medium.com](/writing/2018/05/13/functional-programming-in-ruby-flow-control/)
