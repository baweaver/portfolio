---
layout: "post"
title: "New in Enumerable — Triple Equals Predicates"
date: "2017-12-02"
categories: []
tags: ["ruby", "metaprogramming"]
description: "Exploring a Ruby proposal to add triple-equals predicate methods to Enumerable for more expressive filtering."
---

**Original Issue**: [https://bugs.ruby-lang.org/issues/11286](https://bugs.ruby-lang.org/issues/11286)

Read the docs too, they’re awesome and they help with anything I mention in here you don’t recognize:
[**Module: Enumerable (Ruby 2.4.2)**
*Module : Enumerable - Ruby 2.4.2*ruby-doc.org](https://ruby-doc.org/core-2.4.2/Enumerable.html)

## Triple Equals Black Magic

If you haven’t yet, I would highly suggest you read into my previous post over Triple Equals:
[**Triple Equals Black Magic**
*For the most part, === is either ignored or used in the background of case statements. Now there are several articles…*medium.com](/writing/2017/10/16/triple-equals-black-magic/)

It will fill your mind with all types of bad ideas in the next few paragraphs for what we might be able to do with this new feature.

## The Predicate Methods

First off, what do I mean when I say predicates? I’m referring to the predicate-style methods in Enumerable, the ones that end with a question mark:

```ruby
[1,2,3].all? { |n| n.even? } # => false
[2,4,6].all? { |n| n.even? } # => true

[1,2,3].any? { |n| n.even? } # => true
[1,3,5].any? { |n| n.even? } # => false

[1,2,3].none? { |n| n.even? } # => false
[1,3,5].none? { |n| n.even? } # => true
```

We’ll get back to the short-hand variants later, but for now this will do as a base example.

## Grepping for an Answer

Now there’s another method in Enumerable that’s easy for us to forget about called grep:

```ruby
[1,2,3, 'string'].grep(Numeric) # => [1, 2, 3]
```

Now what does the doc say about how it works?
> Returns an array of every element in *enum* for which Pattern === element.

Y’know, that’s already kinda useful knowing what we can do with triple equals, but one brave Rubyist decided to give that a little extra nudge.

## Triple Equals with Predicate Methods

![](/images/posts/2017-12-02-new-in-enumerable-triple-equals-predicates/img-6727d141.png)

Now we get to the point.

What would happen if our predicate friends up there decided it was right time to take a single arity argument that responds nicely to === like grep?

Magic. Magic would happen.

```ruby
%w(foo bar baz).none?(/foo/) # => false

[1,2,3].all?(Numeric) # => true
```

Interesting, but not quite magic. A bit further?

```ruby
%w(10.0.0.1 10.0.0.5).all?(IPAddr.new('10.0.0.0/8'))
```

Nifty if we’re SysAdmins, but a bit more perhaps.

## Black Magic is Fun

![](/images/posts/2017-12-02-new-in-enumerable-triple-equals-predicates/img-b09851e0.png)

Remember how we can define our own ===? It’s time to jump that rabbit hole.

What if we made a wrapper method that’d let us do things with Arrays and Hashes to have some more fun? Oh lots of fun, lots indeed!

Just note: **THIS IS NOT GOOD RUBY**

Let’s borrow our people data from the Triple Equals Black Magic post:

```ruby
people = [
  {name: 'Bob', age: 20},
  {name: 'Sue', age: 30},
  {name: 'Jack', age: 10},
  {name: 'Jill', age: 4},
  {name: 'Jane', age: 5}
]
```

To start out with we’re going to need to get our wrapper made:

```ruby
class Q
  def initialize(conds = {}) @conds = conds end

  def ===(other)
    @conds.all? { |k, matcher| matcher === other[k] }
  end
end

def Q(conds = {}) Q.new(conds) end
```

Now let’s try this one out:

```ruby
people.any?(Q(age: 1..10)) # => true
```

Nifty! Though you could technically use this trick already with to_proc :

```ruby
class Q
  def initialize(conds = {}) @conds = conds end

  def ===(other)
    @conds.all? { |k, matcher| matcher === other[k] }
  end

  def to_proc
    -> other { self === other }
  end
end

def Q(conds = {}) Q.new(conds) end

people.select(&Q(age: 20))
```

Still fun. Well, I had fun at least.

## When Do We Get the Toys?

Well, that’s the gotcha. We’re not exactly sure yet, but it’s been blessed by good sir Matz:
> OK, I made a decision. I took option 1 above as proposed.
We can do as following:
> [1, 3.14, 2ri].all?(Numeric) # => true
> if should_be_all_symbols.any?(String)
 ...
end
> some_strings.none?(/aeiou/i)
> Matz.

With some luck we may even see it in 2.5 this Christmas, but who knows. I’m still excited for it either way.

## Liked the Lemurs?

Notice the Lemurs floating around? They’re from the book I’m working on:
[**Title · An Illustrated Guide to Ruby**
*Learn Ruby with Lemurs and Puns!*baweaver.gitbooks.io](https://baweaver.gitbooks.io/an-illustrated-guide-to-ruby/content/)

## Finishing Up

I like new features, we all do, but remember to be patient as they make their way through the bug trackers. The core team does an amazing job, people like me just get excited a bit early and peek at our presents before Christmas.
