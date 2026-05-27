---
layout: "post"
title: "Understanding Ruby - Enumerable - Grouping"
series: "understanding-ruby"
date: "2021-02-12"
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

## Grouping

Ruby is an interesting group of folks and code, so interesting that they even have methods to group collections as well.

### [`#partition`](https://ruby-doc.org/core/Enumerable.html#method-i-partition)

`partition` will split elements into two distinct groups depending on a condition:

```ruby
[1, 2, 3, 4].partition(&:even?)
# => [[2, 4], [1, 3]]
```

It's very useful to use when `group_by` doesn't quite make sense and you only have two distinct groups to group elements against. Combined with destructuring assignments and that can be really useful:

```ruby
evens, odds = [1, 2, 3, 4].partition(&:even?)

{ evens: evens, odds: odds }
# => {:evens=>[2, 4], :odds=>[1, 3]}
```

Remember, in Ruby use the method with the least power to get the result you want. `partition` is a good example of that.

### [`#chunk`](https://ruby-doc.org/core/Enumerable.html#method-i-chunk)

`chunk` is somewhat like `group_by` or `partition` except in that it returns back chunked groups of elements:

```ruby
[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5].chunk(&:even?).to_a
# => [[false, [3, 1]], [true, [4]], [false, [1, 5, 9]], [true, [2, 6]], [false, [5, 3, 5]]]
```

It's more useful in the context of a sorted list, but in that case `partition` makes much more sense for `Boolean` like conditions, and `group_by` more for multiple.

`chunk` is a method that I do not encounter frequently in my programming, but has exceptional use when dealing with output logs like Subversion produces, or other unix-like formats.

> **Note**: You might notice `to_a` on a few of these methods, that's because they return an `Enumerator` rather than an `Array`, and tend to be used by chaining together methods rather than by themselves.

### [`#chunk_while`](https://ruby-doc.org/core/Enumerable.html#method-i-chunk_while)

`chunk_while`, on the other hand, I do find uses for, especially in interviews:

```ruby
[1,2,4,9,10,11,12,15,16,19,20,21].chunk_while { |i, j| i+1 == j }.to_a
# => [[1, 2], [4], [9, 10, 11, 12], [15, 16], [19, 20, 21]]
```

In the case of the example it can find contiguous chunks of numbers. The Block Function it takes will expose the element before and after the current element, giving it more power than `chunk` to decide on how to chunk elements together.

Problems like greatest ascending chain of numbers, contiguous groups, and others can be very easy to solve if you remember `chunk_while`.

### [`#each_cons`](https://ruby-doc.org/core/Enumerable.html#method-i-each_cons)

`each_cons` is short for each consecutive:

```ruby
(1..10).each_cons(3).to_a
# => [[1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6], [5, 6, 7], [6, 7, 8], [7, 8, 9], [8, 9, 10]]
```

This is exceptionally useful for sliding window type algorithms, and very frequently I find myself using it in interviews so I practice a lot with `Enumerable` before I have to go back on the hunt.

It can take a block, but like some others it returns `nil` afterwards. If you want to immediately print it, sure, but otherwise it doesn't make too much sense to use without chaining to another `Enumerable` method.

### [`#each_slice`](https://ruby-doc.org/core/Enumerable.html#method-i-each_slice)

`each_slice` is similar to `each_cons` except in that it will return back distinct slices rather than a sliding window of elements like `each_cons`:

```ruby
(1..10).each_slice(3).to_a
# => [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
```

It's useful for getting elements in groups of a certain size to work with. Sometimes you can even pair it with `to_h` or `zip` to do interesting things:

```ruby
(1..10).each_slice(3).to_h { |k, *vs| [k, vs] }
# => {1=>[2, 3], 4=>[5, 6], 7=>[8, 9], 10=>[]}
```

After all, `Enumerable` is very much about how you combine the methods together to make something greater.

### [`#slice_before`](https://ruby-doc.org/core/Enumerable.html#method-i-slice_before)

`slice_before` will slice a collection right before a condition that returns `true` is met:

```ruby
gemfile = <<~GEMFILE
  # frozen_string_literal: true

  source "https://rubygems.org"

  # Specify your gem's dependencies in matchable.gemspec
  gemspec

  # Other gems
  gem "rake", "~> 13.0"

  # Testing
  gem "rspec", "~> 3.0"
  gem "guard-rspec"
  gem "benchmark-ips"
GEMFILE

gemfile
  .lines
  .slice_before { |v| v.start_with?('#') }
  .map(&:first)
# => ["# frozen_string_literal: true\n", "# Specify your gem's dependencies in matchable.gemspec\n", "# Other gems\n", "# Testing\n"]
```

In this case we're looking at a `Gemfile` for Ruby and trying to split right before each comment line, and then just grabbing the commend line that started it off. Sometimes text files don't quite have a nice format like `JSON`, and this is a good way to break it into something you can use.

It also takes a pattern (responds to `===`), which might make the above code more concise:

```ruby
gemfile.lines.slice_before(/^#/).map(&:first)
```

### [`#slice_after`](https://ruby-doc.org/core/Enumerable.html#method-i-slice_after)

`slice_after` is like `slice_before`, except it slices after a condition is true:

```ruby
text = <<~TEXT
  Some paragraphs and content here.

	...and then a few more after that
TEXT
    
text.lines.slice_after(/^\n$/).to_a
=> [["  Some paragraphs and content here.\n", "\n"], ["...and then a few more after that\n"]]
```

Like `slice_before` you can use a pattern or a Block Function:

```ruby
(1..10).slice_after { |e| e.even? }.to_a
# => [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]
```

### [`#slice_when`](https://ruby-doc.org/core/Enumerable.html#method-i-slice_when)

`slice_when` is effectively the opposite of `chunk_while` in that it will slice when the Block Function returns `true` rather than when it returns `false`:

```ruby
[1,2,4,9,10,11,12,15,16,19,20,21].slice_when { |i, j| i+1 == j }.to_a
# => [[1], [2, 4, 9], [10], [11], [12, 15], [16, 19], [20], [21]]

[1,2,4,9,10,11,12,15,16,19,20,21].chunk_while { |i, j| i+1 == j }.to_a
# => [[1, 2], [4], [9, 10, 11, 12], [15, 16], [19, 20, 21]]
```

In the case of `slice_when` it will slice when a condition is met rather than right after. Like `chunk_while` it takes a before and after element.

### [`#group_by`](https://ruby-doc.org/core/Enumerable.html#method-i-group_by)

`group_by` allows you to group elements by a Block Function, and that function defines the key. Consider our text from earlier:

```ruby
%w(a fresh lively lemur jumps over a tea kettle).group_by { |w| w[0] }
# => {"a"=>["a", "a"], "f"=>["fresh"], "l"=>["lively", "lemur"], "j"=>["jumps"], "o"=>["over"], "t"=>["tea"], "k"=>["kettle"]}
```

We can group by the first character of every word, getting the groups back as `Array`s. This is a method I use very frequently when I'm not after the count with `tally`.

# Wrapping Up

The next few articles will be getting into the various parts of `Enumerable`, grouped by functionality:

1. ~~Transforming~~
2. ~~Predicate Conditions~~
3. ~~Searching and Filtering~~
4. ~~Sorting and Comparing~~
5. ~~Counting~~
6. ~~Grouping~~
7. Combining
8. Iterating and Taking
9. Coercion

While `lazy` is part of `Enumerable` that deserves a post all its own, and we'll be getting to that one soon too.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
