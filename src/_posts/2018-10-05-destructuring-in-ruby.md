---
layout: "post"
title: "Destructuring in Ruby"
date: "2018-10-05"
categories: []
tags: ["ruby", "functional", "metaprogramming"]
description: "Implementing destructuring in Ruby using blocks, allowing methods to accept both keyword arguments and objects."
---

It’s blocks all the way down!

What if I told you there was a way to do this in Ruby?:

```ruby
destructure def adds(a: 1, b: 2)
  a + b
end

adds(a: 1, b: 2)
# => 3

adds(OpenStruct.new(a: 1, b: 2))
# => 3

Foo = Struct.new(:a, :b)

adds(Foo.new(1,2))
# => 3
```

Well there is, and it’s quite the trip down the ol’ black magic rabbit hole. Shall we take a look?

## Destructure

Here’s the code in its entirety we’re looking at today:

```ruby
def destructure(method_name)
  meta_klass  = class << self; self end
  method_proc = method(method_name)

  unless method_proc.parameters.all? { |t, _| t == :key }
    raise "Only works with keyword arguments"
  end

  arguments = method_proc.parameters.map(&:last)

  destructure_proc = -> object {
    values = if object.is_a?(Hash)
      object
    else
      arguments.map { |a| [a, object.public_send(a)] }.to_h
    end

    method_proc.call(values)
  }

  meta_klass.send(:define_method, method_name, destructure_proc)

  method_name
end
```

Now I purposely left comments out of this one, unlike the earlier tweet where I initially mentioned this (SPOILERS):

<iframe src="https://medium.com/media/5bed709c4ef07e68901780d41c21df1c" frameborder=0></iframe>

Now what in the world is that actually doing? Let’s step through it!

## Definition of a Method

The first trick involved actually defining the method, as seen in the first part of the article:

```ruby
destructure def adds(a: 1, b: 2)
  a + b
end
```

In newer versions of Ruby, the defining of a method returns the method name as a Symbol:

```ruby
def foo; end
=> :foo
```

destructure is merely a method which takes in a Symbol:

```ruby
def destructure(method_name)
```

But what exactly it’s doing with that name, now that’s another matter entirely.

## Meta Klass

So if we wanted to overwrite a method dynamically in Ruby in place, how would we go about doing it? How about creating a meta reference to the class?:

```ruby
meta_klass  = class << self; self end
```

This allows us to, at the end of the method, redefine the given method with a totally new body:

```ruby
meta_klass.send(:define_method, method_name, destructure_proc)
```

How do we get the original method’s body though?

## The Method method

Ruby comes with a method called quite literally method for converting a symbol representing a method name into a proc:

```ruby
def add(a, b) a + b end
=> :add

method(:add)
=> #<Method: Object#add>

method(:add).call(1, 2)
=> 3
```

That means we can make a reference to what the method used to do that we can call whenever we want. Sometimes if I’m in a particularly block-averse mood I may even do something like this:

```ruby
`curl json_source.com/users.json`.yield_self(&JSON.method(:parse))
```

Not that I advocate that, no no no, just that it does have some use in enabling my particularly hacky REPL Ruby habits which should never see the light of production, amen.

That’s great and all, but how do we know about the arguments?

## Parameters!

Procs and Proc-like objects have this nifty little method called parameters :

```ruby
-> a, *b, c: 1, **d, &fn {}.parameters
=> [[:req, :a], [:rest, :b], [:key, :c], [:keyrest, :d], [:block, :fn]]
```

Each value is an array of type, name . That name? Oh that’s where we can have some fun. First though, we want to only do this with keyword arguments for now:

```ruby
unless method_proc.parameters.all? { |t, _| t == :key }
  raise "Only works with keyword arguments"
end
```

It unfortunately won’t tell us the default values of said parameters, but I would love it forever if we could do something like this later (name pending):

```ruby
-> a: 1 {}.default_values
=> [[:a, 1]]
```

Mostly because I can imagine what one could do with that if nested hashes were a thing, but I digress. What about the arguments? Let’s save them for later:

```ruby
arguments = method_proc.parameters.map(&:last)
```

Now we’ll have an array of all the original method’s argument names as Symbols. Why is that useful? Well what does send take? Oh yes.

## Ze Wrap

Next up we have our new method body, which we define as a lambda which takes in a single object as an argument:

```ruby
destructure_proc = -> object { ... }
```

Why one? Won’t that wreck keyword params? Na, Ruby is clever like that, try this:

```ruby
puts a: 1
{:a=>1}
```

With methods Ruby can imply that it’s a hash, and keywords work much the same way, which brings us to the next bit of fun:

## Hashing things out

We’re setting values equal to the result of a conditional:

```ruby
values = if object.is_a?(Hash)
  object
else
  ...
end
```

We won’t worry about that second branch quite yet. The first one, however, is saying that if what we got in was a Hash (keywords or a literal hash) we probably are calling the method as Matz intended:

```ruby
adds(a: 1, b: 2)

# or
adds({a: 1, b: 2})
```

So simply put it requires no destructuring because Ruby will do that automatically for us.

Well what about the other side? Not so much, we have to explain a bit to Ruby.

## Mappy Map Map

Remember that our arguments for adds were an array, [:a, :b]. If we were to pass something like an OpenStruct to that:

```ruby
data = OpenStruct.new(a: 1, b: 2)
```

we could call a or b on it to get out those values:

```ruby
data.a # => 1
data.b # => 2
```
> Noted that OpenStruct can act like a Hash, but not the point of this segment.

So if we have an array of methods we want to call on it, we could just use map to pull them out!

```ruby
[:a, :b].map { |method_name| data.public_send(method_name) }
```

But in this case, we need to get our data into a Hash of some sorts so Ruby knows how to parse it as a keywords list, giving us our else branch:

```ruby
values = if object.is_a?(Hash)
  ...
else
  arguments.map { |a| [a, object.public_send(a)] }.to_h
end
```

We’re extracting the value, and giving it a label for the keyword, leaving us with:

```ruby
{ a: 1, b: 2 }
```

## Your Call!

Now that we have those values extracted, we can call the original method with whatever we pulled out! That means if we gave anything like a Hash, we’re calling it with a Hash, and if not we make it into one.

```ruby
method_proc.call(values)
```

…and that gives us our return value.

## Housekeeping Items

Notedly the first version just used the meta_klass.send at the very end. If we’re being nice we could return the same method name to allow for even more chaining fun.

If you check out the tweet above you’ll find a thread which references a fully commented Gist of the code as well.

## Would you use this in actual code?

Y’see, that’s always the nit. It’s fun but when would we *ever *use things like this in actual code?

When it’s well tested, commented, documented, and becomes an understood idiom of your code base.

We focus so much on black magic and avoiding it that we rarely have a chance to enjoy any of the benefits. When used responsibly and when necessary, it gives a lot of power and expressiveness.

When used poorly? Well that can get sketchy right quick.

Discretion is the name of the game.

<!-- ![](/images/posts/2018-10-05-destructuring-in-ruby/img-d1c60724.jpeg) -->

## Wrapping Up

This has been another fun adventure in me doing interesting things to Ruby because it can be done. I hope you’ve enjoyed this fun little dive!
