---
layout: "post"
title: "Understanding Ruby - Enumerable - Predicate Conditions"
series: "understanding-ruby"
date: "2021-02-11"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Introduction   Enumerable. Debatably one of, if not the, most powerful features in Ruby. As..."
---

# Introduction

`Enumerable`. Debatably one of, if not the, most powerful features in Ruby. As a majority of your time in programming is dealing with collections of items it's no surprise how frequently you'll see it used.

## Difficulty

**Foundational**

Some knowledge required of functions in Ruby. This post focuses on foundational and fundamental knowledge for Ruby programmers.

Prerequisite Reading:

* [Understanding Ruby - Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/)
* [Understanding Ruby - to_proc and Function Interfaces](/writing/2021/02/08/understanding-ruby-toproc-and-function-interfaces-2o1d/)
* [Understanding Ruby - Triple Equals](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/)
* [Understanding Ruby - Comparable](/writing/2021/02/09/understanding-ruby-comparable-34ki/)

# Enumerable

`Enumerable` is an interface module that contains several methods for working with collections. Many Ruby classes implement the `Enumerable` interface that look like collections. Chances are if it has an `each` method it supports `Enumerable`, and because of that it's quite ubiquitous in Ruby.

> **Note**: This idea was partially inspired by [Lamar Burdette](https://github.com/BurdetteLamar)'s recent work on Ruby documentation, but takes its own direction.

## Predicate Conditions

Predicate conditions are `Enumerable` methods which allow us to ask a question of a collection. Are all of the elements matching a condition? Perhaps just one of them? Maybe any? ...or does it even include it at all?

### [`#all?`](https://ruby-doc.org/core/Enumerable.html#method-i-all-3F)

`all?` is a predicate method, meaning it's boolean or truthy in nature. For `all?` it checks all items in a collection meet a certain condition:

```ruby
[1, 2, 3].all? { |v| v.even? }
# => false
```

We can also use shorthand here:

```ruby
[1, 2, 3].all?(&:even?)
```

...and interestingly it also accepts a pattern, or rather something that responds to `===`:

```ruby
[1, 2, 3].all?(Numeric)
# => true
```

`all?` will also stop searching if it finds any element which does not match the condition.

An interesting behavior is that it will return `true` on empty collections:

```ruby
[].all?
# => true
```

`all?` is great when you want to check if all of a collections items meet a condition, or perhaps many.

### [`#any?`](https://ruby-doc.org/core/Enumerable.html#method-i-any-3F)

`any?` is very similar to `all?` except in that it checks if any of the items in a collection match the condition:

```ruby
[1, 'a', :b].any?(Numeric)
```

Interestingly as soon as it finds a value that matches it will stop searching. After all, why bother? It found what it wanted, and it's way more efficient to say return `true` rather than go through the rest.

With an empty collection `any?` will return `false` as there are no elements in it:

```ruby
[].any?
# => false
```

`any?` is great for checking if anything in a collection matches a condition.

### [`#none?`](https://ruby-doc.org/core/Enumerable.html#method-i-none-3F)

`none?` can be thought of as the opposite of `all?`, or maybe even as not `any?`. It checks that none of the elements in a collection match a certain condition:

```ruby
[1, 'a', :b].none?(Float)
# => true
```

`none?` will return `true` on an empty collection:

```ruby
[].none?
# => true
```

Be careful, as this behavior is very similar to `all?` which also returns `true`.

`none?` can be great for ensuring that nothing in a collection matches a negative set of rules, like simple validations.

### [`#one?`](https://ruby-doc.org/core/Enumerable.html#method-i-one-3F)

`one?` is very much like `any?` except in it will search the entire collection to make sure there's one and only one element that matches the condition:

```ruby
[1, :a, 2].one?(Symbol)
# => true

[1, :a, 2].one?(Numeric)
# => false
```

It has some interesting behavior when used without an argument on empty or single element collections:

```ruby
[].one?
# => false

[1].one?
# => true
```

`one?` is great when you want to ensure one and only one element of a collection matches a condition. I have not quite had a chance to use this myself, but can see how it would be handy.

### [`#include?`](https://ruby-doc.org/core/Enumerable.html#method-i-include-3F) / [`#member?`](https://ruby-doc.org/core/Enumerable.html#method-i-member-3F)

`include?` checks if a collection includes a value:

```ruby
[1, 2, 3].include?(2)
# => true
```

It has an alias in `member?`.

`include?` will compare all elements via `==`  to see if any match the one we're looking for.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. Searching and Filtering
4. Sorting and Comparing
5. Counting
6. Grouping
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
