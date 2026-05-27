---
layout: "post"
title: "Functional Programming in Ruby — Flow Control"
series: "functional-programming-ruby"
date: "2018-05-13"
categories: []
tags: []
description: ""
---

Flow control in Functional Programming is an idea that is a bit harder to wrap your head around as a primarily Object Oriented and Imperative programmer. The kicker is that exceptions are considered poor form here.

Now how do we reconcile that with what we currently do in Ruby? This one seems especially out there. As it turns out, it’s quite applicable to our current code. Let’s see how!

It should be noted that I’m writing code in a purposely explicit way. More succinct code would leverage yield, reduce, or other such tools. I’d encourage you to read through Reducing Enumerable if you want to expand on that idea:
[**Reducing Enumerable — The Basics**
*One of the lesser understood functions in Enumerable for many Rubyists is reduce . It’s just the thing we can use to…*medium.com](/writing/2017/10/16/reducing-enumerable-the-basics/)

## Truly Exceptional

The first thing to contend with here is what an exception is. The short answer is that it’s exceptional behavior we didn’t really expect.

Consider this variant of a find method:

    def find(array, &fn)
      array.each do |v|
        return v if fn.call(v)
      end

      raise "Didn't find anything!"
    end

If it finds something, we get back a value, but if not? We get an exception and now we have to catch it before it crashes!

    find([1,2,3]) { |v| v == 4 } rescue nil

Do that more than a few times, and you begin to realize this gets cumbersome. It’s not exceptional behavior by any metric, we expect that we may not find anything. It’s even in our code with the rescue nil!

That means we have a sane return we can leverage:

    def find(array, &fn)
      array.each do |v|
        return v if fn.call(v)
      end

      nil
    end

## Sane Defaults

This brings us to a concept of sane defaults. In order to allow data to flow cleanly from input to output, we want to have a consistent type to work with. Imagine we had a select method that did this, like find when it doesn’t have a match:

    def select(array, &fn)
      found_items = []

      array.each do |v|
        found_items << v if fn.call(v)
      end

      return nil if found_items.empty?
      found_items
    end

Granted this is a convoluted example, but if we did something like this and it was the basis of the Enumerable method it’d make it exceptionally difficult to chain things:

    [1, 2, 3]
      .select { |v| v > 3 }
      .map { |v| v * 2 }

With the above, this would crash! By using a sane default, such as select returning an empty array instead, we’re allowed to chain things together freely without the need to keep checking for nils or potentially exceptions.

That’s flow control in Ruby. By combining like types (Arrays) we can let our data flow cleanly from input to output without having to stop to check for edge cases.

Here’s where the fun starts though: If we have a consistent return type and sane default we can chain from, what else could we do with it? This is where we start going off the beaten Ruby path a bit to introduce you to this concept called Option.

## It was always an Option

So what exactly is an Option? An option exists as either something or nothing, and depending on what it is we can control how data flows through it. Think of it as a box you put your data in for now:

    class Option
      attr_reader :value

      def initialize(v)
        @value = v
      end
    end

    Option.new(5)
    # => #<Option:0x00007fb2ae99d0c8 [@value](http://twitter.com/value)=5>

Once we put the value in, we can only change it via the API that Option gives us. Currently there’s not much there, we just put our data in a box so it’s not good for anything yet.

To start, we’re going to want to get a way to transform the value, so let’s give it a map:

    class Option
      attr_reader :value

      def initialize(v)
        @value = v
      end

      def map(&fn)
        Option.new(fn.call(@value))
      end
    end

    Option.new(5).map { |v| v * 2 }
    # => #<Option:0x00007fb2b02748f8 [@value](http://twitter.com/value)=10>

To stay more in line with FP, we return a new Option each time we transform the value. We can keep chaining maps onto this for however long we want, but what happens if we do something like this:

    Option.new(5).map { |v| nil }.map { |v| v * 2 }
    # NoMethodError: undefined method `*' for nil:NilClass

Ack! We’re back at exceptions. What we need to do is find a way to tell our Option that it actually has something to map over, or a way to deal with nothing if it doesn’t.

Past that, let’s say that we legitimately want nothing and to us that constitutes a valid return! We can’t just black hole everything when we get a falsey value either. This makes flow control annoying, but what if there were a way to extract this?

Take a look back at the previous article, and see the “In The Wild” section:
[**Functional Programming in Ruby — Closures**
*One of the most powerful features of Functional Programming that we can leverage in Ruby is the concept of a Closure.*medium.com](/writing/2018/05/13/functional-programming-in-ruby-closures/)

Guard Block matchers deal with a concept of having something or nothing, and even give us a way to deal with legitimately falsey values being returned by adding an additional bit of state. It uses an Array which looks a lot like a box to me.

What if we gave [true, VALUE] and [false, false] actual names? We can call them Some and None respectively, ala Scala and Rust.

## Something for Nothing

So how would our ideas of Some and None look? Well we know Some has a value we want to be able to map over, and we want to probably just ignore None:

    class Option
      attr_reader :value

      def initialize(v = nil)
        @value = v
      end
      
      class << self
        def some(v) Some.new(v) end
        def none()  None.new()  end
      end  
    end

    class Some < Option
      def map(&fn)
        new_value = fn.call(@value)
        
        new_value.nil? ?
          Option.none() :
          Option.some(new_value)
      end

      def otherwise(&fn)
        @value
      end
    end

    class None < Option
      def map(&fn)
        self
      end

      def otherwise(&fn)
        fn.call
      end
    end

Some acts just like an Option in that it’ll map over whatever value it gets in, but none is a bit more interesting. It ignores every attempt to map over it, but will gladly call the otherwise function at the end of our chains:

    Option.some(5)
      .map { |v| v * 2 }
      .map { |v| v * 5 }
      .otherwise { 0 }
    # => 50

    Option.some(5)
      .map { |v| v * 2 }
      .map { |v| nil }
      .otherwise { 0 }
    # => 0

This is a technique that goes by many names, but the one I tend to be fond of is Railway Oriented Programming as coined by this excellent post:
[**Railway Oriented Programming | F# for fun and profit**
*Slides and videos explaining a functional approach to error handling*fsharpforfunandprofit.com](https://fsharpforfunandprofit.com/rop/)

The second we get a bad value we can just switch tracks and let our data train go sailing on happily until it hits the end of the line and the value is pulled out with either otherwise or value explicitly.

## That was an Option?

This seems like a lot of code that could be avoided with some rescue statements, sure, but we’re getting something much more valuable in return for it: explicit flow of state through our application.

We’re now forced to be very explicit and cover every case of our functions and define whether or not they’re returning Something or Nothing which allows us to see very clearly where errors are cropping up in our pipelines.

In languages like Scala, Rust, Haskell, and others you’re expected to be explicit about these things which is ironically liberating. It frees us from concerns over whether or not we covered that one strange case and surfaces a lot of implicit concerns we take for granted.

That said, this is also more than a bit of a stray path from what would be vanilla Ruby, meaning you’d find yourself wrapping a lot of external libraries to play nicely in your sandbox.

## Where does this exist already?

If you want to play with some of these ideas, there are already implementations in the wild. They just tend to use the words Maybe instead of Option, Just instead of Some, Nothing instead of None and this weird word you might have heard before:
[**dry-rb - dry-monads - Introduction**
*dry-monads is a set of common monads for Ruby. Monads provide an elegant way of handling errors, exceptions and…*dry-rb.org](http://dry-rb.org/gems/dry-monads/)
[**pzol/monadic**
*monadic - helps dealing with exceptional situations, it comes from the sphere of functional programming and bringing…*github.com](https://github.com/pzol/monadic)
[**lazebny/ramda-ruby**
*ramda-ruby - Ruby port of http://ramdajs.com*github.com](https://github.com/lazebny/ramda-ruby)

As it turns out, that crazy word is Monad. What we have here isn’t strictly a Monad, nor should you really worry too much about that word for now.

A more familiar analog may be a Builder pattern that happens to act different when given nil. Think of ActiveRecord queries, Promises, Enumerable, and others as some interesting approximations of some of these concepts.

Granted this is glossing over a lot of detail, but there’s still a lot of potential value from learning these concepts even if not in rigorous proof-driven depth.

## Wrapping up

That was a fairly whirlwind tour of flow control, and a lot to digest. If you want to learn more about some of these concepts there are a lot of interesting articles and guides out there in the wild for other languages:
[**Introduction · mostly-adequate-guide**
*That said, typed functional languages will, without a doubt, be the best place to code in the style presented by this…*mostly-adequate.gitbooks.io](https://mostly-adequate.gitbooks.io/mostly-adequate-guide/content/)
[**Functors, Applicatives, And Monads In Pictures**
*updated: May 20, 2013 Here's a simple value: And we know how to apply a function to this value: Simple enough. Lets…*adit.io](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html)
[**Haskell Programming**
*An exercise-driven Haskell book for beginners that works for non-programmers and experienced hackers alike.*haskellbook.com](http://haskellbook.com/)
[**Learn You a Haskell for Great Good!**
*Hey yo! This is Learn You a Haskell, the funkiest way to learn Haskell, which is the best functional programming…*learnyouahaskell.com](http://learnyouahaskell.com/)

There’s a lot to learn out there, especially for me, so on your journey stop and write about it for a second. You never know who your writing might help get started!

Enjoy.
