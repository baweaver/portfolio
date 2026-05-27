---
layout: "post"
title: "Ruby 2.7 — Numbered Parameters"
date: "2019-03-18"
categories: ["rails", "programming"]
tags: ["rails", "programming", "ruby"]
description: "Ruby 2.7 — Numbered Parameters   Ruby 2.7 is coming out this December, as with all modern..."
---

### Ruby 2.7 — Numbered Parameters

Ruby 2.7 is coming out this December, as with all modern releases, but that doesn’t stop us from looking for and writing about all the fun things we find in the mean time! No no no.

<!-- ![](https://cdn-images-1.medium.com/proxy/1*p0Ad_zpGIOEFOTX4Yft1Fw.png) -->

For this article, we have something that’s very reminiscent of Bash, Perl, and Scala: Numbered parameters.

> **NOTE**: This syntax was updated from `_1` to `_1`, the article will be updated to account for this.

### The Short Version

If you have a simple block with positional arguments, especially single positional, you can do the following:

```ruby
[1, 2, 3].map { _1 + 3 }
=> [4, 5, 6]
```

…where `_1` is the first parameter to the block function.

### The Discussion

If you’d like to see the discussion behind this feature, it can be found here:

[Feature #4475: default variable name for parameter - Ruby trunk - Ruby Issue Tracking System](https://bugs.ruby-lang.org/issues/4475)

### Examples

As this exposes the object directly, a majority of the examples are just slight adjustments to what you might be familiar to already. Let’s take a look at some of the examples in the test code:

[Numbered parameters [Feature #4475] · ruby/ruby_12acc75](https://github.com/ruby/ruby/commit/12acc751e3e7fd6f8aec33abf661724ad76c862a#diff-4216bbf6387c50d56b418c67768dcccb)

#### **Valid Only In Blocks**

Numbered parameters are only valid when referenced inside of a block:

```ruby
assert_syntax_error('_1', /outside block/)
assert_valid_syntax('proc {_1}')
```

That means this is valid:

```ruby
proc { _1 }
=> #<Proc:0x0000000111d42990@(pry):6>
```

…and this will cause a syntax error:

```ruby
_1
SyntaxError: (eval):2: numbered parameter outside block
```

Now the error is slightly modified from older Ruby versions in that it recognizes the second-use of the instance variable-like syntax and lets us know we used it outside of a block.

#### **Naming Rules**

A numbered param has to follow a few rules, namely there are only numbers in it and 0 along with leading 0s are errors:

```ruby
assert_syntax_error('proc {_01}', /leading zero/) assert_syntax_error('proc {_1_}', /unexpected/)
```

That also means it’s going to do bad things if you try and use underscores for longer numbers:

```ruby
(1..1_000_000).each_slice(1_000).map { _1 + _1_000 + _2 + _3 }
SyntaxError: unexpected local variable or method, expecting '}'
..._slice(1_000).map { _1 + _1_000 + _2 + _3 }
... ^~~~
(eval):2: numbered parameter outside block
...e(1_000).map { _1 + _1_000 + _2 + _3 }
...
```

#### **Multiple Numbered Parameters**

Say we have collections or even hashes, we can use _2 and further if we need them to get at the specific values:

```ruby
assert_equal(3, eval('[1,2].then {_1+_2}'))
assert_equal("12", eval('[1,2].then {"#_1#_2"}'))
```

For hashes this means you can access the key and the value:

```ruby
{name: 'foo', age: 42}.map { [_1, _2] }
=> [[:name, "foo"], [:age, 42]]
```

If you had groups of three you could even start using more:

```ruby
(1..9).each_slice(3).map { _1 + _2 + _3 }
=> [6, 15, 24]
```

…though it may be ill-advised to start getting into too many of these numbered params, as eventually you run out.

#### **Too Large of a Number**

There _is_ a limit, but it’s rather high:

```ruby
assert_syntax_error('proc {_9999999999999999}', /too large/)
```

Defined here in this constant:

```c
#define NUMPARAM_MAX 100 /* INT_MAX */
```

Though there should be warning signs that you’re doing something odd before you get anywhere close to this number.

Currently Pry will just give up if you try, and expect more input:

```ruby
[13] pry(main)> (1..1_000_000).each_slice(1_000).map { _101 }
[13] pry(main)*
```

#### Ordinary Parameters

Ruby doesn’t like mix-and-match with our current way of doing block parameters:

```ruby
assert_syntax_error('proc {|| _1}', /ordinary parameter is defined/) assert_syntax_error('proc {|x| _1}', /ordinary parameter is defined/)
```

If you decide to use this, know that it’s one or the other, not both.

#### Hashes and Objects

It would be good to remember that _1 and friends are just Ruby objects, meaning we can call anything on them that we would a parameter:

```ruby
[{name: 'foo'}, {name: 'bar'}].map { _1[:name] }
=> ["foo", "bar"]

[{name: 'foo'}, {name: 'bar'}]
  .map { OpenStruct.new(_1) }
  .map { _1.name }
=> ["foo", "bar"]
```

Though in the last example, it would be good to remember the current shorthand syntax of `map(&:name)` instead.

### Wrapping Up

This is definitely a very interesting feature, though I certainly feel Matz when he says the following:

> I still feel weird when I see @ and @1 etc. Maybe I will get used to it after a while.  
> I need time.

> - Matz.

> **NOTE**: The syntax was updated from `@1` to `_1`, the above comment was updated to reflect this.

I wonder what new things it will lead to, but I’m excited nonetheless to see what else people can use it for.

2.7 is already off to an interesting start, let’s see where it goes from here.
