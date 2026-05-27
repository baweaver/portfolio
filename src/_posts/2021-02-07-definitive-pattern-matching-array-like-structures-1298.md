---
layout: "post"
title: "Definitive Pattern Matching - Array-like Structures"
date: "2021-02-07"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "patternmatching", "functional"]
description: "Introduction   This is the start of a series on Ruby Pattern Matching, the goal of which is..."
---

# Introduction

This is the start of a series on Ruby Pattern Matching, the goal of which is to provide a definitive reference on the nuances, best practices, and common usages of Pattern Matching, a new feature introduced in Ruby 2.7.

For this post we'll be taking a look into Array-like structures and how they can be matched against.

This series is derived from a proposal for [Pattern Matching Interfaces in Ruby](https://docs.google.com/document/d/1spnuQTKy5i7Lx-sDCsORKN981Iam1IuNdOsYkhh9Yi0/edit#heading=h.vmv48c5zz9sr), and expands significantly upon the content mentioned in the document. Notedly this is also an attempt to expose more of these ideas to the community at large as a 22-page Google Doc is rather terrifying.

## Difficulty

**Pragmatics**

Some familiarity with Ruby is recommended. This post focuses on pragmatic knowledge and usage of Pattern Matching for Ruby programmers.

It is suggested that you read into the following concepts first:

* [Triple Equals and Case Statements](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/)
* [Deconstruction of Method Parameters](/writing/2018/10/05/destructuring-in-ruby/)
* [Arrays in Ruby](https://ruby-doc.org/core/Array.html)

# Definitive Pattern Matching - Array-like Structures

The first section of this series will focus on Arrays and Array-like structures, the underlying methods which enable these matches, and the syntax around them to leverage Pattern Matching to its fullest extent.

## Vanilla Start: Array

To start with let's consider an `Array`. With a regular `case` statement before Pattern Matching was introduced we could only compare literally:

```ruby
case [1,2,3]
when [1,2,3] then true
else false
end
# => true
```

This doesn't have much of a point, but with the introduction of the `in` syntax we see something very very different start to happen:

```ruby
case [1,2,3]
in [Integer, Integer, Integer] then true
else false
end
# => true
```

Every single item is compared via `===` to the others at the same index, allowing us much more flexibility and expressiveness, but this is just the start of what's possible through Pattern Matching.

## Syntax

With Pattern Matching came a whole lot of new syntax. Let's take a look into some of this syntax and walk through where and how you might use it.

### Case in

```ruby
case [1, :a, 'b']
in Integer, Symbol, String then true
else false
end
# => true
```

The first change is the new `in` branch of a case statement.

It's different than `when` in that it compares via a Pattern Match rather than strictly using `===` on the top level object.

`in` compares the values it pulls out of the object it's matching against rather than against the whole object, and considering the power of `===` in Ruby this is very handy indeed.

In the original `when` branch a comma (`,`) was a signifier for an "OR" condition. With `in` it's a signifier for matching against the next value that has been deconstructed from the original object by position for `Array`-like classes.

It should be noted that `Array` brackets (`[]`) are not strictly required around `Array`-like matches here.

> **WARNING**: You cannot mix `when` and `in` branches.

### "OR" Conditions

If the comma (`,`) has been overridden to accomodate positional matches, is it still possible to have multiple conditions? Pattern Matching introduces the pipe (`|`) as a ways of doing this:

```ruby
case [1.0, :a, 'b']
in Integer | Float, Symbol, String then true
else false
end
# => true
```

This syntax states that the first item in the `Array` should be either an `Integer` or a `Float`.

> **WARNING**: This will not work with any named captures in the same pattern, and will result in a syntax error.

### Deconstructed Constant

```ruby
Point = Struct.new(:x, :y)

case Point[0, 1]
in Point[0..10, 0..10] then :close_to_origin
else :far_away
end
# => :close_to_origin
```

While `Struct` has a `[]` method it's interestingly not used in the `in` branch. Every value inside of `[]` in the branch itself is a pattern, as seen with the ranges here. This only works with classes which implement Pattern Matching interfaces though.

The other interesting thing is that if we were to use an `Array` here:

```ruby
case [0, 1]
in Point[0..10, 0..10] then :close_to_origin
else :far_away
end
```

...it would fail, as this also compares on type, making this a very useful feature. Then again, that also means less flexibility and a more explicit type check, so make sure to weigh benefits here.

It should be noted that it also supports `Constant(patterns)` as well:

```ruby
case Point[0, 1]
in Point(0..10, 0..10) then :close_to_origin
else :far_away
end
# => :close_to_origin
```

...which I almost prefer as it doesn't confuse with `[]` being a constructor for `Struct`.

### Any Value

If there's a particular value you only want to test for the presence of you can use an underscore (`_`) as a placeholder for any value:

```ruby
case [1.0, :a, 'b']
in _, Symbol, _ then true
else false
end
# => true
```

### Positional Variable Capture

```ruby
case [1.0, :a, 'b']
in first, Symbol, last then [first, last]
else false
end
# => [1.0, "b"]
```

Using variable names in a Pattern Match will cause them to be assigned as long as the rest of the pattern holds true.

> **WARNING**: This means that if you have a variable named `first` above it will not match against that value, it will overwrite it.

### Pinned Variable Comparison

```ruby
value = 'b'

case [1.0, :a, 'b']
in first, Symbol, ^value then first
else false
end
# => 1.0
```

If, however, you do want to match against a current variable you would need to use the pin (`^`) operator to compare against its value. This is derived very much from Elixir Pattern Matching.

### Rest

As with an `Array` deconstruction:

```ruby
first, *rest = [1, 2, 3]
# first: 1, rest: [2, 3]
```

You can do the same with a Pattern Match:

```ruby
case [1, 2, 3]
in Integer, *rest
  rest
else
  false
end
# => [2, 3]
```

Interestingly this also assigns a variable by the same name, much like the above variable capture.

### Anonymous Rest

```ruby
case [1, 2, 3]
in Integer, *
  true
else
  false
end
```

If you don't care about the values you can also use `*` to anonymously match against the remaining values instead of saving them to a variable.

### Experimental: Find Pattern

```ruby
case [1, 2, 3, 4, 5, 6, 7]
in *, Integer, *
  true
else
  false
end
```

If you were to use two asterisks (`*`) this would represent a find pattern which will try and locate this pattern anywhere inside the `Array`. Unsurprisingly this can be a bit slower than the others, but is a very useful syntax for checking the existence of a certain condition at an unknown place in an `Array`.

This becomes even more interesting when paired with names:

```ruby
case [:a, :b, 3, :c, :d]
in *lead, Integer, *tail then [lead, tail]
else false
end
# => [[:a, :b], [:c, :d]]
```

> **Note**: This syntax is considered experimental, and may change in future versions.

### Condition and Variable Capture

With some of the above you might notice it seems like you can only match a condition or capture through a variable. Using Right Hand Assignment (`=>`) you can do both:

```ruby
case [:a, :b, 3, :c, :d]
in *lead, Integer => target_number, *tail
  [[*lead, *tail], target_number]
else false
end
# => => [[:a, :b, :c, :d], 3]
```

### Guard Clauses

If you wish to immediately check a value against a condition you can do so using postfix `if` and `unless` as guard clauses. This is especially useful with variable captures:

```ruby
case [3, 4, 5]
in Numeric => a, Numeric => b, Numeric => c if a**2 + b**2 == c**2
  :triangle
else
  :not_triangle
end
# => :triangle
```

In the above case we can check that all items are numerical, assign them to variables, and check that they happen to match the [Pythagorean Theorem](https://en.wikipedia.org/wiki/Pythagorean_theorem) as a post-check guard condition.

### Experimental: Expression Pinning

A new, and very recently merged feature, that's not currently documented is the expression pinning syntax (`^()`). With current pattern matching you may notice that calling functions is a syntax error:

```ruby
case [1,2,3]
in *, :even?.to_proc, * then true
else false
end
# SyntaxError ((irb):302: syntax error, unexpected '.', expecting `then' or ';' or '\n')
# in *, :even?.to_proc, * then true
```

Expression pinning allows us to do this inline, but comes at the cost of speed:

```ruby
case [1,2,3]
in *, ^(:even?.to_proc), * then true
else false
end
# => true
```

Granted I would love for this to work:

```ruby
case [1,2,3]
# WARNING: Will syntax error!
in *, &:even?, * then true
else false
end
# => true
```

...but that may be a very hard sell.

>  **Note**: This syntax is considered experimental, and may change in future versions. It is only available on nightly builds.

### Experimental: One-Line In

```ruby
[1.0, :a, 'b'] in [0.., Symbol, /^b/]
# => true
```

There's also the one-line syntax. In this one `Array` brackets (`[]`) are required, as the syntax may be ambiguous otherwise.

For the `in` variant of one-line Pattern matching the assumed reason for using it is to get a boolean result rather than capture variables. 

>  **Note**: This syntax is considered experimental, and may change in future versions.

### Experimental: One-Line Right Hand Assignment

```ruby
[1.0, :a, 'b'] => [0.. => a, Symbol => b, /^b/ => c]
# => nil

[a, b, c]
# => [1.0, :a, "b"]
```

If you do happen to care about capturing variables on a one-liner it's suggested to instead use Right Hand Assignment (`=>`) to clarify intent.

>  **Note**: This syntax is considered experimental, and may change in future versions.

## Implementation

Now that we have Syntax down let's take a look into how to implement hooks for `Array`-like Pattern Matching.

`Array`-like matches come from the `deconstruct` method, which returns an `Array` of values to match against, and in many ways acts like another `Array`-like interface for classes.

### `to_a` or `Array`-like Interfaces

The simplest variant of a pattern matching hook is to alias against the `to_a` method:

```ruby
class Point
  def initialize(x, y)
    @x = x
    @y = y
  end
  
  def to_a() = [@x, @y]
  alias_method :deconstruct, :to_a
end
```

This would expose `x` and `y` to be matched against any time we have `Point.new(0, 1) in [0, 1]` or a similar matching branch.

### Alternative Array Implementations

Some classes, like S-Expressions, may make more sense to define a custom implementation:

```ruby
class SExpression
  def initialize(name, *children)
    @name = name
    @children = children
  end
  
  def deconstruct() = [@name, *@children]
```

...in which we want to flatten the children to provide a flatter interface to match against. `to_a` may not always make sense, and some discretion is needed here.

### Constructor-like Interfaces

The other interesting variant is to leverage positional constructor arguments, meaning to match against the initial properties used to define a class:

```ruby
class Person
  attr_reader :name, :age
  
  def initialize(name, age)
    @name = name
    @age  = age
  end
  
  def deconstruct
    arg_names =
      instance_method(:initialize).parameters.map(&:last)
    
    arg_names.map { public_send(_1) }
  end
end
```

This can be more easily achieved using [Matchable](https://github.com/baweaver/matchable), like so:

```ruby
class Person
  include Matchable
  
  deconstruct :new
  attr_reader :name, :age
  
  def initialize(name, age)
    @name = name
    @age  = age
  end
end
```

...which does the same thing at a class level.

## Best Practices

Now that we have all of that information, what are some things to make sure to avoid? Some things to make sure to do? These are a few best practices I've seen from working with Array-like matches.

### Avoid Implementing on Non-Array-Like Classes

If a class cannot be cleanly represented as an `Array` it may not make sense to implement `deconstruct` on it. Consider using `Hash`-like matches instead. There is one exception to this, the next item.

### Constructor Parallels Can Work for Non-Array-Like Classes

If a class has a reasonable number of parameters to its constructor, all of which being positional rather than keyword, it may make sense to implement `deconstruct` in terms of the initializer's parameters.

A good rule of thumb is when there are more than `3` params where the order matters you should likely avoid implementing on the constructor.

### Be Conscious of Order

`Array`-like matches can be very order dependent, which means that some items may need to be `sort`ed before being compared, or will need to retain order in their internal storage.

Lack of order may well turn into needing multiple matches where just one would do if order could be assumed.

### Use Find-Pattern Sparingly

The Find pattern (`[*, v, *]`) can be expensive in terms of speed. Make sure that you're not trying to account for an order dependency when using it.

### Names Still Matter

While you can most certainly name your captures single-letter variable names prefer to use descriptive names. You can save a few characters, but as a result may make your code illegible.

### White Space is Free

Along with the last point white space is free, use it liberally to make your code more readable, especially with pattern matches.

### `in` for Conditions, `=>` for Assignment

For one-line matches use `in` to check against a Boolean condition, and `=>` for when you want to access the underlying values.

### Avoid Shadowing Variables

Pattern Matching will assign over variables if you let it, which can lead to interesting results:

```ruby
v = 1

[1, 2, 3] => [*lead, v]

[lead, v]
# => [[1, 2], 3]
```

This applies to full pattern matches as well.

### Nest Patterns Sparingly

Just because you can infinitely nest patterns does not mean you should. Aim for readability first, and if you're diving through more than 3-4 layers to get at a value your code may become very hard to read and understand later.

### Avoid Mutation

Pattern Matching interface methods should avoid mutating the underlying class, and should act as read-only to follow the principle of least surprise.

### Prefer Underscore to Asterisk

If you only need to match against one explicit value use an underscore (`_`) over an asterisk (`*`) for a rest-type capture when it isn't needed.

### Prefer One-Line Match for Boolean Queries

If you have a single boolean query to make prefer to use a one-liner. If you need to check multiple conditions default to the full Pattern Match.

# Wrapping Up

There's a lot to go through here, and a lot more still to write. Pattern Matching is a fundamental part of Ruby going forward, and with that comes a lot of interesting things to explore and consider.

Next session we'll take a look at Hash-like matches, and following that an overarching best practices guide.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
