---
layout: "post"
title: "Deeper Magics: Monoids in Ruby and Rails"
date: "2019-11-01"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional", "endofunctors"]
description: "There exist some deeper magics and patterns in Ruby, this series will take a look at ideas from FP and how they can be applied."
---

## What are we Looking at Today?

There are patterns in Ruby that don't come from more Object Oriented programming, ones that come from a more Functional land, and ones that amusingly enough you're probably already using without realizing it.

So why learn them? Names are powerful things, and recognizing the concept allows us to build even greater and more powerful abstractions on top of it.

For this particular one you'll start seeing it everywhere in Ruby, and I've found it immensely useful in even not 100% pure sacred blessed functional code from the lands of Haskell and Idris.

That's the thing about ideas and abstractions: they transcend languages, and they help us express ideas we haven't quite put to words yet.

## Prerequisites

Before reading this article, I would highly encourage you to look into "Reducing Enumerable" if you're not comfortable with `reduce` and reimplementing `Enumerable` methods in Ruby.

You can view the conference talk from last year's Ruby Conf here:

https://www.youtube.com/watch?v=x3b9KlzjJNM

...or you can read the text version here:

/writing

## The Secret of "Reducing Enumerable"

Now there's a fun secret, and one I never really mentioned during the talk. You see dearest reader, I was teaching another concept in its entirety and building up intuition around it.

Let's take a look into those core concepts before we move on for a brief review.

### Reviewing Reduce

For reduce we're reducing a collection of items into one item using:

* A collection (`[1, 2, 3]`)
* A way to join them together that returns the same type (`+`)
* An initial value, often that's "empty" (`0`)

So if we were to get the sum of a list (ignoring that `sum` is a thing now) it would look like this in long-form:

```ruby
[1, 2, 3].reduce(0) { |acc, v| acc + v }
```

Why the `0`? Well adding anything to `0` gives back that number, making it a suitable empty value to "start" with.

### The Start of a Pattern

Here's the fun part: that looks an _awful lot_ like a repeatable pattern and set of rules. What if we did that for multiplication instead?

```ruby
[1, 2, 3].reduce(1) { |acc, v| acc * v }
```

With multiplication `0` would make no sense as an "empty" because multiplying anything by `0` is `0`. That's why we use `1` here instead.

This gives us a list of numbers with joining function of `*`, and an empty value of `1`.

The thing about patterns is they have to have more than a few cases, and oh do we have more.

Consider with me for a moment a list of strings. An empty string would be `""` and a way to join two together would be `+`.

```ruby
list_of_strings.reduce('') { |acc, v| acc + v }
```

Does that look familiar? What if we did arrays with `[]` and `+`? Hashes with `{}` and `merge`? `Proc`, `-> v { v }`, and `compose`?

All of these have a way to express an empty item of that type and a way to combine two items to get another of the same type. It almost looks like a set of rules.

That, my friends, is the secret:

**"Reducing Enumerable" is a thinly veiled tutorial for Monoids**

## The Rules of our New Friend: The Monoid

These rules make a concept called a Monoid, or loosely translated to "In the manner of a single item":

1. Join (Closure) - A way to combine two items to get back an item of the same type
2. Empty (Identity) - An empty item, that when joined with any other item of the same type, returns that same item.
3. Order (Associativity) - As long as the items retain their order you can group them however you want and get the same result back.

Associativity is new, but means that we can say:

```ruby
1 + 2 + 3 + 4 == 1 + (2 + 3) + 4 == 1 + 2 + (3 + 4) == ....
```

They would all give us back the same result. Now addition has a few more properties that make it something more like Inversion and Commutativity:

4. Inversion - For every operation there's an inverse (`+ 1` vs `+ -1`)
5. Commutativity - Order doesn't matter, you'll get the same result

Adding Inversion makes a Monoid into a Group, and adding Commutativity makes it into an Abelian Group. We won't worry about these too much for now except to say addition of numbers is an Abelian Group.

This is all well and good, but why precisely should we care about this novel abstract concept? Well something you're very familiar with happens to behave an awful lot like a Monoid if you've done any Rails.

## Active Record Queries

Have you seen this code in a controller?:

```ruby
class PeopleController
  def index
    @people = Person.where(name: params[:name]) if params[:name]
    @people = @people.where(birthday: params[:birthday_start]..params[:birthday_end]) if params[:birthday_start] && params[:birthday_end]
    @people = @people.where(gender: params[:gender]) if params[:gender]
  end
end
```

Does it feel slightly off? It did for me, and I could never figure out how to fix it before until I realized a few things:

1. Scopes are "just plain old Ruby code"
2. ActiveRecord queries have a concept of empty
3. They look a whole lot like a Monoid

### A Scope

A scope in Rails is a way to give a "name" to a query:

```ruby
class Person
  # Macro helper
  scope :me, -> { where(name: 'Brandon') }

  # Same idea
  def self.me
    where(name: 'Brandon')
  end
end
```

Remembering that they're just Ruby code we could add whatever arguments we want, no?:

```ruby
class Person
  def self.born_between(start_date, end_date)
    where(birthday: start_date..end_date)
  end
end
```

### Some Conditions Apply

Look back at that initial controller code, remember we'd gated querying a birthday on whether or not dates were provided?:

```ruby
@people = @people.where(birthday: params[:birthday_start]..params[:birthday_end]) if params[:birthday_start] && params[:birthday_end]
```

Nothing says we can't use a condition in a scope, and remember that a Monoid can join anything with an "empty" value to get back the same thing. That means if the condition doesn't apply we can ignore the scope effectively:

```ruby
class Person
  def self.born_between(start_date, end_date)
    if start_date && end_date
      where(birthday: start_date..end_date)
    else
      all
    end
  end
end
```

So what's the join? `.`, the method call. ActiveRecord queries act like a builder and don't execute until we ask for their values, so we can keep adding to them.

`all` is considered "empty" in that if you put it anywhere in a chain it means `all` of everything already applied so the current queries will still work:

```ruby
Model.where(a: 1).all.where(b: 2) ==
Model.where(a: 1, b: 2).all ==
Model.all.where(a: 1, b: 2) ==
...
```

This is really handy and allows us to create much more powerful scopes simply from being able to express a conditional as a no-op.

### Associativity

Scopes are great because you can keep adding them, or you could combine them, and the entirety of ActiveRecord is available so things like `join` and `includes` work too. Because they work associatively we can group them pretty freely:

```ruby
class Model
  def self.a; where(a: 1) end
  def self.b; where(b: 2) end
  def self.c; a.b.where(c: 3) end
end
```

Once you combine this with `join`, `include`, `or`, and other concepts this starts getting really powerful. Combined with the idea of conditional scoping you could even drive the inclusion of child-types based on parameters to make your controllers that much more flexible.

Be warned: methods like `pluck`, `select`, and `to_a` don't work like that and need to be at the end of a chain. They're not query methods, and force a query to evaluate itself.

### Bringing it Together

Let's take that original controller code:

```ruby
class PeopleController
  def index
    @people = Person.where(name: params[:name]) if params[:name]
    @people = @people.where(birthday: params[:birthday_start]..params[:birthday_end]) if params[:birthday_start] && params[:birthday_end]
    @people = @people.where(gender: params[:gender]) if params[:gender]
  end
end
```

Factoring with scopes would give us something like this:

```ruby
class Person
  def self.born_between(start_date, end_date)
    if start_date && end_date
      where(birthday: start_date..end_date)
    else
      all
    end
  end

  def self.with_name(name)
    name ? where(name: params[:name]) : all
  end

  def self.with_gender(gender)
    gender ? where(gender: params[:gender]) : all
  end
end

class PeopleController
  def index
    @people = Person
      .with_name(params[:name])
      .born_between(params[:birthday_start], params[:birthday_end])
      .with_gender(params[:gender])
  end
end 
```

If we were to make that more advanced with something like this Post controller:

```ruby
class PostsController
  def index
    @posts = Post.where(params.permit(:name))
    @posts = @posts.join(:users).where(users: {id: params[:user_id]}) if params[:user_id]
    @posts = @posts.includes(:comments) if params[:show_comments]
    @posts = @posts.includes(:tags).where(tag: {name: JSON.parse(params[:tags])}) if params[:tags]
  end
end
```

We could even use those ideas to wrap inclusions too:

```ruby
class Post
  def self.by_user(user)
    return all unless user
    join(:users).where(users: {id: user})
  end

  def self.with_comments(comments)
    return all unless comments
    includes(:comments)
  end

  def self.with_tags(tags)
    return all unless tags
    includes(:tags).where(tag: { name: JSON.parse(tags) })
  end
end
```

Which makes that controller look something like this instead:

```ruby
class PostsController
  def index
    @posts =
      Post
        .where(params.permit(:name))
        .by_user(params[:user_id])
        .with_comments(params[:show_comments])
        .with_tags(params[:tags])
  end
end
```

...and hey, you could even group a few of those too and just pass the params along. There's a lot of possibility.

## Wrapping Up: The Realm of Possibility

Why write about abstract concepts? Why give names to things like this? Because it broadens our viewpoints, allowing us to see new solutions to common problems that may be even more clear.

That's the fun of programming, it's like a puzzle, flipping pieces around until it feels like it finally fits and things slide into place. Reverse it, flip it, rotate it, look at it from every angle you can think of.

In programming there are more angles to approach things from than you or I have time for and that's exciting: it means there's always something more to learn, and a new novel concept just waiting to be discovered.
