---
layout: "post"
title: "Ruby 2.7 — Pattern Matching — Destructuring on Point"
date: "2019-04-18"
categories: ["ruby", "functional"]
tags: ["ruby", "functional", "rails"]
description: "Ruby 2.7 — Pattern Matching — Destructuring on Point   Now that pattern matching has hit..."
---

### Ruby 2.7 — Pattern Matching — Destructuring on Point

Now that pattern matching has hit Ruby Nightly as an experimental feature, let’s take a look into some potential usecases for it starting with Destructuring.

<!-- ![](https://cdn-images-1.medium.com/proxy/1*p0Ad_zpGIOEFOTX4Yft1Fw.png) -->

If you haven’t seen the first article going over a lot of the spec, you can find it here:

[Ruby 2.7 — Pattern Matching — First Impressions](https://dev.to/keystonelemur/ruby-2-7-pattern-matching-first-impressions-2dnm-temp-slug-4930565)

This article will be a bit more structured.

### Testing Warning!

Be sure to remember that variable assignment destructuring assigns local variables. This _will_ mess with your testing unless you do it in methods instead of in a direct `Pry` or `IRB` session. We’ll dig into this more later in the article.

If something doesn’t match, it’s going to raise an error, so be sure to use else to handle default cases.

### On Point!

One of the interesting things I’d noted was the ability to destructure from an object. Let’s say we have a `Point` that has an `x` and `y` coordinate:

```ruby
Point = Struct.new(:x, :y) do
  def deconstruct
    self.to_a
  end

  def deconstruct_keys(keys)
    self.to_h
  end
end
```

We’ll use this as our base example for now.

### Array Destructuring

Destructuring is a means of extracting values from an object in Ruby. You may be familiar with the left-hand style from assignment:

```ruby
x, y = Point.new(0, 1).to_a
x # => 0
y # => 1

*coords = Point.new(2, 3).to_a
coords # => [2, 3]
```

These are all valid in in expressions in a pattern matching context. That includes splatting values.

**Direct Value**

We can destructure to match directly against values:

```ruby
case Point.new(0, 1)
in 0, 1 then Point.new(0, 2)
end
=> #<struct Point x=0, y=2>
```

These items all respond to `===` as we’ll see later in this article.

**Triple Equals Destructuring**

Anything that responds to `===` is perfectly fair game here:

```ruby
case Point.new(0, 1)
in 0.., 1.. then Point.new(0, 2)
end
```

**Direct Variable**

If we wanted to just move north, we can use pattern matching to pull out our `x` and `y` values by position:

```ruby
case Point.new(0, 1)
in x, y then Point.new(x, y + 1)
end
=> #<struct Point x=0, y=2>
```

So it looks like the `then` keyword is still valid here. Good to know.

Now something interesting is also happening here. It’s assigning local variables, meaning after that statement this works:

```ruby
[x, y]
=> [0, 1]
```

This works with any of the variable assignment styles, and caught me a bit by surprise though it does make sense.

**Triple Equals Destructuring into Variables**

How about if we have some ranges?

```ruby
case Point.new(0, 1)
in 0..5 => x, 0..5 => y
  Point.new(x, y + 1)
end

#<struct Point x=0, y=2>
```

What’s important to note here is that the format is:

```ruby
value or matcher => destructured variable
```

These will respond to anything implementing `===`, which is what makes case statements so powerful in Ruby. Read this for more information on `===`:

[Triple Equals Black Magic](/writing/2017/10/16/triple-equals-black-magic/)

### **Keyword Destructuring**

What about keywords?

What we don’t necessarily get in Ruby is the ability to natively destructure on keywords, but with pattern matching we can _if and only if_ `deconstruct_keys` is defined and returns a hash-like object like above:

```ruby
def deconstruct_keys(keys)
  self.to_h
end
```

> I’m not sure what keys are doing here, I’ll have to take a `TracePoint` at this to try and find out what’s going on later. If you have ideas let me know!

Considering `Struct`s kind-of already do some of this, that’s an interesting technicality but not one we’ll worry about for now.

**Keywords are not Variable Assignments**

The thing to be careful of here is that the keys are used for destructuring, but not assignment:

```ruby
case Point.new(0, 1)
in x: 0, y: 1..5 then Point.new(x, y + 1)
end

NameError: undefined local variable or method `x' for main:Object
```

**Arrows are still used for Assignment**

So that doesn’t work. We have to use => here to bind them to a local variable:

```ruby
case Point.new(0, 1)
in x: 0 => x, y: 1..5 => y then Point.new(x, y + 1)
end
=> #<struct Point x=0, y=2>
```

This means we get full access to === here as well, which can be very useful.

### Emulating Qo — Preview

Now I’d written a pattern matching library a while back, and I kinda want to see how it stacks up:

[baweaver/qo](https://github.com/baweaver/qo)

This is a preview of some of the next article.

Let’s start with a `Person`:

```ruby
Person = Struct.new(:name, :age) do
  def deconstruct
    self.to_a
  end

  def deconstruct_keys(keys)
    self.to_h
  end
end
```

We’ll also be using the `Any` gem for a wildcard:

[baweaver/any](https://github.com/baweaver/any)

**Name is Longer than 3 Characters**

The `Qo` way:

```ruby
name_longer_than_three = -> person { person.name.size > 3 }

people_with_truncated_names = people.map(&Qo.match { |m|
  m.when(name_longer_than_three) { |person|
    Person.new(person.name[0..2], person.age)
  }

  m.else
})
```

The Pattern Matching way:

```ruby
person = Person.new('Edward', 20)

case person
in name: -> n { n.size > 3 } => name, age: Any => age
  Person.new(name[0..1], age)
else
  person
end

=> #<struct Person name="Ed", age=20>
```

### Wrap Up

This was my first chance to play with some of pattern matching in Ruby, and I’m rather fond of it so far. There are some definite gotchas and a lot of syntax to take in, but there’s definitely a lot of power there.

There are also some very odd things like keys I don’t understand, and what happens if you try and do anything fancy in a pattern match like this:

```ruby
case Point.new(0, 1)
in x: :even?.to_proc => x then Point.new(0, 0)
end

endSyntaxError: unexpected '.', expecting `then' or ';' or '\n'
 in x: :even?.to_proc => x then Point.new(0...
```

I believe this is likely a bug in the parser, but as this is experimental that’s to be expected.

My next few dives into pattern matching will likely follow trying to emulate various features I’d used `Qo` for:

[baweaver/qo](https://github.com/baweaver/qo)

2.7 is shaping up to be a very interesting release. Let’s see where it goes from here!
