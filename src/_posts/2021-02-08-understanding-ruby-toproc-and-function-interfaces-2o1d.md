---
layout: "post"
title: "Understanding Ruby - to_proc and Function Interfaces"
series: "understanding-ruby"
date: "2021-02-08"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional", "patternmatching"]
description: "Introduction   We've just covered the idea of Block Functions, Proc Functions, and Lambda Fu..."
---

# Introduction

We've just covered the idea of Block Functions, Proc Functions, and Lambda Functions in the last post, as well as a brief mention of `to_proc` and how exactly we can call functions. This post is going to pursue those concepts in a bit more depth

## Difficulty

**Foundational**

Some prerequisite knowledge needed of functions. This post focuses on foundational and fundamental knowledge for Ruby programmers.

Prerequisite Reading:

* [Understanding Ruby - Triple Equals](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/)
* [Understanding Ruby - Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/)

# `to_proc` and Function Interfaces

What makes a function in Ruby a function? What interface, or rather methods, lead Ruby to think it's dealing with something like a function?

In Ruby we have a concept of duck typing: If it quacks like a duck, walks like a duck, and looks like a duck it must be a duck.

That is to say if two classes in Ruby each implement the same interface we can use them interchangeably with each other.

For functions in Ruby that interface includes:

* `to_proc` - How to present itself as a function
* `call` - How to call the underlying function
* `[]`, `===`, `.()` - Other methods of calling the function

So to get back to the point at hand: What makes a function a function?

That's what we're going to explore in this.

## Standard Library Implementations of `to_proc`

We can start out by asking Ruby precisely which classes have an instance method `to_proc` to find out how it's currently implemented:

```ruby
ObjectSpace.each_object(Class).select { |klass| klass.instance_methods.include?(:to_proc) }
# => [#<Class:#<Hash:0x1234>>, Enumerator::Yielder, Method, Proc, Hash, Symbol]
```

We'll focus on the last four for now: `Method`, `Proc`, `Hash`, and `Symbol`. We'll get into `Enumerator` later.

> **Note**: I do not currently know what the first `#<Class:#<Hash:0x1234>>` is, but will look into this more at a later date. If you happen to know, leave a comment!

### Method

I had mentioned in the previous post that Methods can act as functions as well. This occurs through `method(:name)` and `instance_method(:name)` respectively:

```ruby
raw_json.then(&JSON.method(:parse))
# => parsed_json
```

`to_proc` in this case is telling Ruby to treat a method as a Block Function. It should be noted, however, that this syntax has fallen out of favor in lieu of the introduction of numbered params:

```ruby
raw_json.then { JSON.parse(_1) }
```

...in which `_1` is the implied first argument to the function.

### Proc Function

A Proc Function uses `to_proc` much like a Method does: to tell Ruby it's a Block Function, and to treat it accordingly:

```ruby
add_one = proc { |a| a + 1 }
add_two = -> b { b + 2 }

[1, 2, 3].map(&add_one)
# => [2, 3, 4]
  
[1, 2, 3].map(&add_two)
# => [3, 4, 5]
```

Do note that Lambda Functions (`-> {}` or `lambda {}`) are a subset of more restrictive Proc Functions, as mentioned in the last post.

### Hash

This one is interesting, and one I learned fairly recently even myself. Hashes in Ruby support `to_proc`:

```ruby
hash = { a: 1, b: 2, c: 3, d: 4 }
%i(a b c).map(&hash)
# => [1, 2, 3]
```

Its implementation might look something like this:

```ruby
class Hash
  def to_proc() = -> key { self[key] }
end
```

...in which each value passed in to the new function generated from `Hash#to_proc` retrieves the value at a certain key. I'm not quite sure where I would use this at the moment, as `Hash#values_at` seems to fit a similar role and is arguably clearer in its intent:

```ruby
hash = { a: 1, b: 2, c: 3, d: 4 }
hash.values_at(*%i(a b c))
# => [1, 2, 3]
```

> **Note**: The Splat Operator (`*`) takes a list and treats it as a flat list of arguments to a function, so `values_at` above receives `:a, :b, :c` instead of a single `Array` argument containing all of those values.

### Symbol

This can be a more confusing one for newer Rubyists as it's ubiquitous in Ruby code, and finding the meaning of `&` can be complicated:

```ruby
[1, 2, 3].select(&:even?)
```

It's a lovely shorthand for a very powerful concept, and its implementation might look a bit like this:

```ruby
class Symbol
  def to_proc() = -> v { v.send(self) }
end
```

Where `self` is the `Symbol` `:even?` in the above case. We're treating the `Symbol` as a method to be called on every item in the list. For `select` this could be predicates, for `map` it could be a transformation, but the power in this little syntax drives a lot of Ruby code so it's good to know how it works.

## Custom Interfaces

Where this gets interesting is when you define your own interfaces which act like functions. For this example we'll consider an older library of mine, [Qo](https://github.com/baweaver/qo), which was one of the predecessors of Ruby Pattern Matching.

We'll call this `Where` for the sake of this example.

> **Note**: The actual gem [`Where`](https://rubygems.org/gems/where) does something entirely different (geolocation), so don't expect this gem to actually exist.

### Creating `Where`

To start out with we want to express the idea of our new `Where` class:

```ruby
class Where
  def initialize(*array_matches, **keyword_matches)
    @array_matches = array_matches
    @keyword_matches = keyword_matches
  end
end
```

We want to express the idea of matching against a series of values, either array or keyword style, and have that work like a function. To start out with we need to make a `match?` method to capture the idea of matching:

```ruby
class Where
  def match?(value)
   	@array_matches.all? { |matcher| matcher === value } &&
    @keyword_matches.all? { |method_name, matcher|
      matcher === value.send(method_name)
    }
  end
end
```

This allows us to do something like this:

```ruby
Where.new(1..10, odd?: true).match?(3)
# => true
```

Each array-like match is compared with `===` and each keyword-like match uses the keyword as a method call to send to the matched against object, and it uses `===` to compare the value it extracts from there.

Turns out you can do a lot in a few lines of code in Ruby.

### Constructor Shorthands

Personally I prefer this syntax:

```ruby
Where[1..10, odd?: true].match?(3)
# => true
```

To get this we need to add one more method:

```ruby
class Where
  def self.[](...) = new(...)
end
```

Brackets can be defined as a method on classes as well.

> **Note**: If you ever see something like `Integer('1')` in Ruby these are methods with the same name as a class [defined in Kernel](https://ruby-doc.org/core-3.0.0/Kernel.html#method-i-Integer).

### `to_proc`

Implementing `to_proc` for `Where` will look like wrapping the `match?` function:

```ruby
class Where
  def to_proc() = -> v { match?(v) }
end
```

`match?` is more clear of a name for intentions, but exposing this interface allows us to do this:

```ruby
(1..10).select(&Where[1..10, odd?: true])
# => [1, 3, 5, 7, 9]
```

How's that for interesting?

### `call`, `===`, and `[]`

These two methods often times are aliases of eachother, starting from the implementation of `call`. In this case `call` itself is effectively an alias for `match?`:

```ruby
class Where
  alias_method :call, :match?
  alias_method :===, :match?
  alias_method :[], :match?
end
```

...which we can test directly as so:

```ruby
Where[1..10, odd?: true].call 3
# => true
Where[1..10, odd?: true] === 3
# => true
Where[1..10, odd?: true].(3)
# => true
Where[1..10, odd?: true][3]
# => true
```

> **Note**: `Where.(v)` is syntactic sugar for `Where.call(v)`. Defining `call` gives us this syntax for free.

...but you likely won't be using those in favor of `match?` when calling this explicitly, so let's take a look at when you would use it:

```ruby
(1..10).map do |n|
  case n
	when Where[odd?: true] then n / 2
  when Where[even?: true] then n * 2
  else 0
  end
end
# => [0, 4, 1, 8, 2, 12, 3, 16, 4, 20]
```

Remember, `case` uses `===` for conditions, allowing us to do this.

# Wrapping Up

In very few lines of Ruby we've made our own variant of Pattern Matching by leveraging the functional interfaces provided to us. Ruby interfaces and implicits have a great deal of power behind them, and knowing about them will allow you to write exceptionally succinct and powerful code.

It should be mentioned that you should not actually use `Where` in your actual code as Pattern Matching has taken over many of the things that it would be used for.

Some of the next few articles will cover other interfaces in Ruby that may be of interest, such as `Enumerable` and `Comparable`.

Remember, with great quacking comes great responsibility, enjoy your newfound knowledge of the functional interface in Ruby!

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
