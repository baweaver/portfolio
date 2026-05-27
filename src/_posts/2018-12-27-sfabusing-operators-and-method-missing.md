---
layout: "post"
title: "Sf — Abusing Operators and Method Missing"
date: "2018-12-27"
categories: []
tags: ["ruby", "metaprogramming", "functional"]
description: "Taking operator abuse further with method_missing and custom proc coercion to build expressive DSLs."
---

Now if you thought Mf was bad, that’s just the tip of the proverbial iceberg. Sf is oh so much worse, and that’s what makes this article all the more fun.

<!-- ![](/images/posts/2018-12-27-sfabusing-operators-and-method-missing/img-90a4d52a.png) -->

You see, Sf is a special type of Ruby madness, but before we dive into that type of madness I must insist that you read through how Mf works first:
[**Mf — Abusing Ruby’s Operator Precedence**
*You may have seen Ruby 2.6’s Proc composition, but did you know there are more operators you can abuse using Ruby’s…*medium.com](/writing/2018/12/26/mfabusing-rubys-operator-precedence/)

In it I mentioned a very fun idea: Objects with their own idea of what to_proc means.

## Custom Proc Coercion

Ampersand coerces an object to a proc, and that means that it calls the to_proc method. The trick is, we can totally define our own. I do this in Qo for pattern matching:

```ruby
class Qo
  def initialize(**kw_matchers)
    @matchers = kw_matchers
  end

  def match(obj)
    @matchers.all? { |k,v| v === obj.send(k) }
  end

  def to_proc
    -> obj { call(obj) }
  end
end
```

Read this article to find out what exactly that’s doing:
[**For want of Pattern Matching in Ruby — The Creation of Qo**
*Qo is a Ruby gem made to emulate pattern matching and fluent querying found in other languages.*medium.com](/writing/2018/04/15/for-want-of-pattern-matching-in-ruby-the-creation-of-qo/)

The short version is we can define and use === and to_proc to achieve a great amount of power in Ruby. Most of my gems use this in some way or another for flexible interfaces.

That brings us to our next fun topic, method_missing.

## Method Missing

Now, as always, method_missing is a powerful and dangerous tool. Use it with discretion.

We can use method_missing to intercept methods called on an object that it doesn’t know how to respond to. That applies to the singleton class as well:

```ruby
def method_missing(method_name, *args, **kwargs, &fn)
  ...
end

def self.method_missing(method_name, *args, **kwargs, &fn)
  ...
end
```

Normally you only want to intercept a small subset of method names, and call out to super in the case that it’s not what we’re looking for. This isn’t one of those cases.

We’re going to be doing things to any and all methods coming in.

Next up we have an idea from Java.

## The Builder Pattern

A Builder pattern was a way to “build” an object by returning self at the end of a static method call. In Ruby that might look like this:

```ruby
class Person
  def add_name(name)
    @name = name
    self
  end

  def add_age(age)
    @age = age
    self
  end
end

Person.new
  .add_name('Test')
  .add_age(42)
```

Now I would not recommend actually doing that in Ruby, but it leads us to some other ideas around laziness.

## Laziness

There’s no given rule that we *have *to do something whenever method_missing is called. We can just lazily hoard operations until it’s time to do something with them:

```ruby
class Sf
  def initialize
    @operations = []
  end

  def method_missing(method_name, *args, **kwargs, &fn)
    @operations.push(
      method_name: method_name,
      args: args,
      kwargs: kwargs,
      fn: fn
    )

    self
  end
end
```

Which means we have an interface which looks quite a bit like a builder pattern:

```ruby
Sf.new + 5 + 6
=> #<Sf:0x00007ff6c7222e30
 @operations=
  [{:method_name=>:+, :args=>[5], :kwargs=>{}, :fn=>nil}, {:method_name=>:+, :args=>[6], :kwargs=>{}, :fn=>nil}]>
```

Be careful, order of operations *will *bite you here:

```ruby
Sf.new + 5 * 6
=> #<Sf:0x00007ff6c842c860 @operations=[{:method_name=>:+, :args=>[30], :kwargs=>{}, :fn=>nil}]>
```

Notice how the args is 30, or rather 5 * 6 because of precedence. Point in case that being too clever can do perfectly normal things that are quite annoying to debug considering you’re looking for some extravagant parser bug.

## Back to Coercion

So now that we have those pieces, what are we doing with Sf and coercion? Effectively we’re making a stack of operations to apply to an object we get at a later time, meaning our trusty old reduce method is really handy here:

```ruby
def call(object)
  @operations
    .reduce(object) { |obj, method_name:, args:, kwargs:, fn:|
      if kwargs.empty? 
        obj.public_send(method_name, *args, &fn)
      else
        obj.public_send(method_name, *args, **kwargs, &fn)
      end
    }
end
```

Now we can apply each one of those stacked lazy methods to an object one by one until we get back an object at the end of our transformation!

Not sure how reduce works? Give this a read:
[**Reducing Enumerable — Part One: The Journey Begins**
*The first part of the Reducing Enumerable story, where Red begins his journey of knowledge.*medium.com](/writing)

Why the branch on kwargs ? Well splatting them gives an empty hash which breaks certain methods with public_send so we don’t really want to do that.

## All Together Now!

I’ve added a few things along the way, like defining common operators instead of relying too much on method_missing (because *slow*). The code will need some later cleaning, but gives a fun little show into some of the construction:

<iframe src="https://medium.com/media/edf9be77cff9847150cb9d30b6716a23" frameborder=0></iframe>

…which means I can totally get away with code like this:

```ruby
Sf.dig(:a, :b).gsub('a') { '1' }.to_i.call(a: {b: 'a'})
=> 1
```

Since those can be dropped anywhere, you could theoretically use it on any large JSON or structure you need to map over:

```ruby
users_json.map(&Sf.dig(:address, :street, :number))

# or
users_json.map(&Sf.slice(:name, :email))
```

There’s a lot of possibility out there! Really I’m not even entirely sure what all this type of thing can do, but that’s what makes it so fun to play with.

## Wrapping Up

The Sf gem isn’t *technically* out yet, as I have more than a few kinks to hammer out. I’d just figured that the process of making something like this would be interesting to everyone, and decided to share.

Enjoy, and happy hacking!
