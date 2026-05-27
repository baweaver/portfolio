---
layout: "post"
title: "Ruby 3 - Set Literal"
date: "2020-09-02"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "ruby3"]
description: "In our series on new Ruby 3.0 features we continue with the new Set literal syntax."
---

> **NOTE**: This change was not implemented in Ruby 3

Next in our series on [new features in Ruby 3](https://dev.to/t/ruby3) we'll be looking at the new Set syntax recently [discussed on the bug tracker](https://bugs.ruby-lang.org/issues/16989)

# Quick Reference

What's it look like?

```ruby
set = { 1, 2, 3 }
set.include?(3) # => true
```

Originally this might have looked like this:

```ruby
set = Set[1, 2, 3]
set.include?(3) # => true
```

# Details

Now `Set` has some interesting usecases, so consider this a quick rundown of `Set` as well as an introduction of the new syntax.

It should be noted that `Set` inclusion is `O(1)` rather than `O(n)` for  an `Array`. That means these examples can be pretty quick compared to searching an entire array.

## What Can We Use It For?

### Triple Equals - `===`

`===` is real fun, and for `Set` it's implemented as `include?` or `member?`. In the core docs it uses this example:

```ruby
case :apple
when Set[:potato, :carrot]
  "vegetable"
when Set[:apple, :banana]
  "fruit"
end
# => "fruit"
```

With the new syntax we can change it to this:

```ruby
case :apple
when { :potato, :carrot }
  "vegetable"
when { :apple, :banana }
  "fruit"
end
# => "fruit"
```

Remembering that some methods in Ruby now leverage `===` for matches:

```ruby
text = "The rain in spain falls mainly on the plane"
words = text.split
fillers = Set['The', 'the', 'in', 'on']
fillers = { 'The', 'the', 'in', 'on' }

new_words = words.grep_v(fillers)
# => ["rain", "spain", "falls", "mainly", "plane"]

words.any?(fillers)
# => true

words.slice_after(fillers).to_a
# => => [["The"], ["rain", "in"], ["spain", "falls", "mainly", "on"], ["the"], ["plane"]]
```

That means you get methods like `any?`, `all?`, `none?`, `one?`, `grep`, `slice_before`, `slice_after`, and `grep_v` to work with.

Granted I have opinions about `find` taking `===` patterns instead of an `ifnone` and `select` / `reject` / `filter` also using patterns, but that's a matter for another issue on the bug tracker like [this one I submitted recently](https://bugs.ruby-lang.org/issues/17140).

### Duplicate Prevention

`Set` cannot have repeated elements, and that can be real useful for inline definition:

```ruby
def example_method(a, b, c)
  { a, b, c }
end

example_method(1, 1, 1)
# => { 1 }
```

I do wonder if one can splat inside these:

```ruby
def example_method(*args)
  { *args }
end

example_method(1, 1, 1, 1, 1)
# => { 1 }
```

...but that migth get confusing after a while, no? Especially with ambiguity with Hashes and keyword splatting:

```ruby
a = { a: 1 }
b = { **a, b: 2 }
```

We'll get more into overloaded syntax issues in  a bit though.

## Compromises and Issues

### New Syntax

I like expressive new syntax, but this does add another layer of concern as far as `Hash` vs `Set` by overloading some symbols. This could be the same as some of the `class.[]` confusion as well for cases like `Hash[]` and how those work.

That said, I like this syntax and think it in general makes sense. It's just a balancing act whenever you add new syntax to not break intuitiveness.

I do wonder what would happen if we had `%s{ 1, 2, 3 }` instead. While two more characters this does fit into the convention of `%w`, `%i`, and others.

### Punning

Now the bad part about this syntax is that it overrides the potential for a very very powerful feature in Javascript called object punning:

```javascript
const a = 1;
const b = { b: 1, c: 2 };

const c = { a, ...b }
// {a: 1, b: 1, c: 2}
```

I could see that being extremely useful for Ruby if it were to do something along the lines of this:

```ruby
def move_north(x:, y:)
  { x, y + 1 }
end

move_north(x: 1, y: 2)
# => { x: 1, y: 3 }
```

There's probably some way to shim that behavior in, sure, but with the new `Set` literal that appears to be unlikely. That said I don't disagree with the syntax either, and actually quite like it, so I'm a bit torn on this one.

### Block Ambiguity

This could provide some fun with Block ambiguity as well. How so? Consider the trick of `{}` vs `do ... end` for blocks and what that does to parens:

```ruby
describe  'something' do
  # This works
end

describe 'something' {
  # This won't  
}
```

Most of these are already inherit issues with Hashes, sure, but will need to be watched out for in `Set` as well. I do wonder about one-arg blocks like `any?` and how they might respond:

```ruby
[1, 2, 3].any? { 1, 2 }
```

There could be some ambiguity here, especially without parens, and exceptionally so like this:

```ruby
[1, 2, 3].any? { 1 }
```

Is that a block or a `Set`? I could see it being interpreted as a block very easily, which may create issues. It may be a fair compromise to just call this one an invalid case.

# Final Thoughts?

I like it, I think it's succinct and it makes sense, I just have a few concerns over some of the above ambiguity issues as noted.

I can see some good uses for a few things I've used day-to-day as far as querying data and de-duping lists of items, but will probably need to write a `Set` tutorial later to refresh myself on what the rest of them might be and give it a bit more of a pragmatic edge.

Looking forward to what Ruby 3.0 brings, and I'll be writing on new features as I see them.

Notice one that I haven't? Feel free to DM me on Twitter [@keystonelemur](https://twitter.com/keystonelemur) and I'll take a look into it.
