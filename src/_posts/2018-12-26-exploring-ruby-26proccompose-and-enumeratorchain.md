---
layout: "post"
title: "Exploring Ruby 2.6 — Proc#compose and Enumerator#chain"
date: "2018-12-26"
categories: []
tags: []
description: ""
---

New features abound in Ruby 2.6. This time around we have two fun new items for Ruby 2.6 to look into: Proccompose and Enumerator#chain.

<!-- ![](/images/posts/2018-12-26-exploring-ruby-26proccompose-and-enumeratorchain/img-e570e8bd.png) -->

## Enumerator#chain

There are times when you have an Enumerator, and you’d like to combine it with another Enumerator. Wouldn’t it be nice if you could just add them together? Well in 2.6 you can:

    [1, 2, 3].to_enum + [3, 4, 5].to_enum

Now why would we want to do that instead of just adding arrays? Because Enumerators don’t have to iterate elements to do this.

Consider something that’s hard-bound on IO or another slower resource like file reads. By using an Enumerator instead of slurping the entire files into memory we could effectively chain multiple file’s contents together without ever having to take a look inside of them.

Could this be done in previous versions? Yes, but you would have to get slightly more clever to do this:

    class Enumerator
      def chain(other)
        Enumerator.new { |y|
          self.each { |v| y.yield(v) }
          other.each { |v| y.yield(v) }
        }
      end
      
      alias_method :+, :chain
    end

    [1,2,3].to_enum.chain([2,3,4].to_enum).to_a

2.6 methods offer more convenient and “blessed” ways to do tasks that one had to work around in the past.

Now this also works with infinite ranges if you happen to be careful with them:

    ((1..).to_enum + ('a'..).to_enum).take(10)
    => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

Though not if you try and get a lazy zip going. Be careful to use laziness for those:

    ((1..).to_enum.zip ('a'..).to_enum).take(10)
    => INFINITE CRASH

    ((1..).lazy.zip ('a'..)).take(10).to_a
    => [[1, "a"], [2, "b"], [3, "c"], [4, "d"], [5, "e"], [6, "f"], [7, "g"], [8, "h"], [9, "i"], [10, "j"]]

## Proc#compose

One of my personal favorite new features, composition, is an extra bit of functional magic in Ruby.

It’s the idea that you can combine two Proc functions:

    add1 = -> v { v + 1 }
    mult5 = -> v { v * 5 }

    add1_mult5 = add1 << mult5
    add1mult5.call(5)
    # => 30

Though that’s rather tame. Let’s try something a bit more interesting.

I’d suggest giving this article a read first if you don’t already understand closures:
[**Functional Programming in Ruby — Closures**
*One of the most powerful features of Functional Programming that we can leverage in Ruby is the concept of a Closure.*medium.com](/writing/2018/05/13/functional-programming-in-ruby-closures/)

We have a lot of JSON, and we want to be able to work with that a bit more succinctly. In characteristic fashion, let’s create a contrived example to (ab)use some of Ruby 2.6’s new syntax:

    users_url = URI('[https://jsonplaceholder.typicode.com/users](https://jsonplaceholder.typicode.com/users)')

    calls = -> method_name, *args {
      -> object {
        object.public_send(method_name, *args)
      }
    }

    gets_value = -> key_name { calls[:[], key_name] }

    email_ends_with = -> what {
      gets_value['email'] >> calls[:end_with?, what]
    }

    extracts = -> *keys {
      -> object { object.slice(*keys) }
    }

    Net::HTTP.get(users_url)
      .then(&JSON.method(:parse))
      .select(&email_ends_with['biz'])
      .map(&extracts['name', 'email'])

    => [{"name"=>"Leanne Graham", "email"=>"[Sincere@april.biz](mailto:Sincere@april.biz)"},
     {"name"=>"Kurtis Weissnat", "email"=>"[Telly.Hoeger@billy.biz](mailto:Telly.Hoeger@billy.biz)"},
     {"name"=>"Clementina DuBuque", "email"=>"[Rey.Padberg@karina.biz](mailto:Rey.Padberg@karina.biz)"}]

Now there’s a lot of potential there for some interesting things, but be aware that the above code is unnecessarily clever for the sole sake of demonstrating a feature.

As always the name of the game is discretion.

The above pattern may see some more common use after the method shorthand syntax is confirmed:
[**Feature #13581: Syntax sugar for method reference - CommonRuby - Ruby Issue Tracking System**
*Redmine*bugs.ruby-lang.org](https://bugs.ruby-lang.org/issues/13581)

…which would mean I’d be very likely to do something like this:

    Net::HTTP.get(users_url).then(&JSON.:parse)

Though hashes will always be a good bit of fun to rip through.

## Wrapping up

What are some of your favorite 2.6+ features? Personally I’m looking forward to using proc composition more and coming up with some less contrived examples down the road, but we’ll see where that goes.

Until next time!
