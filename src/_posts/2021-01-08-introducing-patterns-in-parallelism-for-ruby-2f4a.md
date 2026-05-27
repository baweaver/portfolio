---
layout: "post"
title: "Introducing Patterns in Parallelism for Ruby"
date: "2021-01-08"
categories: ["ruby", "functional"]
tags: ["ruby", "functional", "monoids", "endofunctors"]
description: "With the advent of Ractor and Fibers we've hit the limits of mutable types. We're going to need some new patterns, and with that comes some interesting observations on the nature of parallel structures."
---

There was an interesting quote the other day by Kir:

> "We’ll need to push the Ruby ecosystem to have less shared
> state to fully leverage the Ractor pattern"
> via [@kirshatrov](https://twitter.com/kirshatrov)

...and another interesting thread from Piotr:

> ...is a message I've been trying to convey too (-
> the ractor part of course) for the past ~6 years or so,
> but people would mostly look at me with confusion
>
> via [@_solnic_](https://twitter.com/_solnic_/status/1347424492352581639)

Now for those of you who don't know Piotr, he's one of the people behind [DryRB](https://dry-rb.org/). I won't be directly covering DryRB in this article, but I want to set some foundations to get you thinking in that direction.

We're going to take a look into the nature of parallelism, and with it some patterns that will come in a lot of handy.

If you want a more whimsical introduction to the ideas in this article I would suggest ["Reducing Enumerable - An Illustrated Adventure"](https://www.youtube.com/watch?v=x3b9KlzjJNM).

# Consider Adding Numbers

I want you to, for a moment, consider the nature of adding numbers together:

```ruby
1 + 1
# => 2
```

As fundamental as addition is, it's hiding a few very interesting patterns you may know intuitively but don't know that they have names all their own. Let's take a look at the patterns real quick.

## Patterns in the Numbers

### Pattern 1. Adding Numbers Returns a Number

Let's start with this: If you add two integers together, you're going to get back another integer.

```ruby
(1 + 1).class
# => Integer
```

Doesn't matter what the integer is. If you combine them with `+` you're getting an integer back.

### Pattern 2. Adding Zero to a Number Returns that Number

If you add zero to any other number you'll get back that same number:

```ruby
1 + 0
# => 1
```

### Pattern 3. Grouping Numbers with Parens Doesn't Change Results

If you drop some parens in there you're going to get the same result:

```ruby
1 + 2 + 3 == (1 + 2) + 3
(1 + 2) + 3 == 1 + (2 + 3)
```

### Pattern 4. Adding the Negative of a Number Returns Zero

If we add the negative version of any number to itself we're going to get back zero:

```ruby
1 + -1 == 0
```

### Pattern 5. Actually, Order Doesn't Matter

Sure, we can group numbers with parens and get the same thing, but we don't really need to care about order either:

```ruby
1 + 2 + 3 == 3 + 2 + 1
3 + 2 + 1 == 1 + 3 + 2
```

## Patterns Become Rules

So why exactly does any of this matter? Some if not all of that may seem like intuitive sense we'd picked up years back in math class.

You see, those patterns are the basis of a few rules. Let's take another look at them and give them names.

### Rule 1. Closure

You may know about *closures* from functions that return functions, but that's not quite what we're going over (yet, give me a moment.)

Remember that adding two numbers gives back a number, or integers in our case above.

Integers, in math, are a *set* of values. If you combine two values in a *set* and it gives you back an item in that same *set* it's considered to be "closed over the *set*", or a *closure*.

That's fancy talk for it returns something of the same type.

For this rule to work we need a few things:

1. A *set* of values (integers)
2. A way to join them together (`+`)
3. Joining them gives back something in that same set of values (integer)

### Rule 2. Identity

Identity is a value you can combine with any other value in a set to get back that exact same value.

It's the "empty" value. In the case of addition, zero:

```ruby
1 + 0 == 0 + 1
0 + 1 == 1
```

But this value is dependent on the fact that we're adding two numbers together. If we were to multiply them instead and use that as our joining method we'd have issues because:

```ruby
1 * 0
# => 0
```

When you change the operator you may also change what the identity element is. For multiplication it's one instead:

```ruby
1 * 1
# => 1
```

### Rule 3. Associativity

Associativity is our grouping property. It means that we can, with three or more numbers, group them with parens wherever we want and still get back the same value:

```ruby
1 + 2 + 3 == (1 + 2) + 3
(1 + 2) + 3 == 1 + (2 + 3)
```

### Rule 4. Inversion

Inversion means for every value you join you can join an inverted version of it to get back to empty, or identity. In addition that means `n` can be negated by `-n` for integers:

```ruby
1 + -1 == 0
5 + -5 == 0
```

That doesn't work so well for multiplying integers, as to invert multiplying by `n` you would have to multiply by `1/n` which isn't an integer. Looks like multiplication doesn't work with this rule.

### Rule 5. Commutitivity

Commutitivity means that the order doesn't matter, if the values are all still joined by the same method you'll get back the same result:

```ruby
1 + 2 + 3 == 3 + 2 + 1
```

The same works for multiplication if you try it:

```ruby
1 * 2 * 3 == 3 * 2 * 1
```

# Patterns are Everywhere

So why is any of that relevant you might ask?

Let's try a few more types real quick:

## String Addition

1. **Closure**: `+`
2. **Identity**: `""`
3. **Associativity**: `"a" + "b" + "c" == ("a" + "b") + "c"`

## Array Addition

1. **Closure**: `+`
2. **Identity**: `[]`
3. **Associativity**: `[1] + [2] + [3] == [1, 2] + 3`

## Hash Merge

1. **Closure**: `merge`
2. **Identity**: `{}`
3. **Associativity**: `{ a: 1 }.merge({ b: 1 }).merge({ c: 1 }) == { a: 1, b: 1 }).merge({ c: 1 }) `

## Functions

1. **Closure**: `<<`
2. **Identity**: `-> v { v }`
3. **Associativity**: `a << b << c == (a << b) << c`

## ActiveRecord Queries

1. **Closure**: `.`
2. **Identity**: `all`
3. **Associativity**: `Model.where(**a).where(**b).where(**c) == Model.where(**a, **b).where(**c)`

# Frequent Patterns tend to be Named

Wait wait, that seems like it happens a lot! Well when something happens a lot we tend to give a name to that concept.

If that pattern happens to match the rules of Closure, Identity, and Associativity we call it a Monoid (like one thing).

If we add inversion, it becomes a Group, and if we also add Commutitivity it becomes an Abelian Group. ([This listing of Group-like structures may be useful](https://en.wikipedia.org/wiki/Monoid#Relation_to_category_theory))

In Ruby we also tend to call these patterns "reducible":

```ruby
# values           identity       joining
#    V                 V             V
[1, 2, 3, 4, 5].reduce(0) { |a, i| a + i }

%w(some words here to join).reduce('') { |a, s| a + s }

[[1], [2], [3]].reduce([]) { |a, v| a + v }
```

Which is great and all, but why does any of this relate to parallelism?

Because none of those concepts rely on mutable state to function.

# Going Parallel

Let's say you had billions of numbers in a batch system. Since we know that numbers, when joined with addition, have the properties of an Abelian Group that gives us some really nice benefits:

1. We can shard them into whatever chunks we want across thousands of computers, irreverant of the order.
2. We can filter out to only even numbers. If that filters all the numbers we just return back zero instead.
3. If we know a batch was bad and we want to undo it we can resend the inverted version of those numbers `ns.map { |v| -v }` to undo it.

Knowing these patterns gives an intuition for how to work with asyncronous or parallel systems, and they can be really danged handy especially for an Actor model.

# We Want Results

Great, but your job needs more than adding numbers, and I agree. That's a nice trick great for parties but we have serious programmer work to do no?

DryRB has a concept that's interesting, [Result](https://dry-rb.org/gems/dry-monads/1.3/result/) (wait to click for a moment), which is the sum of two types, `Success` and `Failure`:

```ruby
def greater_result(a, b)
	a > b ? Success(a) : Failure('Error!')
end

greater_result(1, 2).fmap { |v| v + 10 }
# => Failure('Error!')

greater_result(3, 2).fmap { |v| v + 10 }
# => Success(13)
```

It allows us to represent distinct ideas of success or failure and wraps them into some nifty classes for us. The trick? `fmap` looks a whole lot like `join` or `+`, and returns something in the set of `Result`. Not exactly because these go a few steps beyond our frieldly little Monoid above.

If we call `fmap` on a `Success` the value keeps passing through to the function, if on a `Failure` it just ignores us. That means we have a safe way of handling errors in a parallel world.

You might notice that the link mentions Monads. You may also have heard the rather quipish "Monads are just **Monoids** in the Category of EndoFunctors" before as well.

Ignoring Monads for a second as a whole concept to learn they follow the same patterns as a Monoid plus a few extras. That means we get the same benefits, meaning `Result` is safe to use in a parallel system.

DryRB introduces a lot of these types, and of course it's a stretch from what we're used to, but so are Ractors so we're in fair game territory. It's time to change the way we play.

# Wrapping Up

For additional resources I would strongly suggest looking into [Railway Oriented Programming](https://fsharpforfunandprofit.com/rop/) from here to continue building some ideas of what's possible in a parallel world with Ruby through Result-like types.

That video above? ["Reducing Enumerable"](https://www.youtube.com/watch?v=x3b9KlzjJNM)? It's also a talk that's entirely about Monoids without ever mentioning Monoid, that was a fun trick. See if you can spot the patterns now watching it!

There's a lot here, and I may make a much more detailed post on this later, but a lot of fun things to consider nonetheless.

One day I may just write a Monad tutorial, but not quite today I reckon.
