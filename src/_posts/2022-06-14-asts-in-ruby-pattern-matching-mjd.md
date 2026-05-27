---
layout: "post"
title: "ASTs in Ruby - Pattern Matching"
series: "asts-in-ruby"
date: "2022-06-14"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "Have you ever wanted to edit Ruby code programmatically? Perhaps change one bit of text to another,..."
---

Have you ever wanted to edit Ruby code programmatically? Perhaps change one bit of text to another, use a bit of regex and all good to go. The problem is Ruby code isn't text, strictly speaking, it's a series of tokens that all have distinct meaning which makes it very hard to change non-trivial codepaths with regex without committing horrible atrocities that would make a Perl programmer proud.

(* Multiple Perl programmers were asked for their opinions on aforementioned regexen, and were indeed proud, horrified, and impressed all at once. It was a good day.)

## What is an AST?

Jokes aside, if regex isn't going to cut it we need another way to work with Ruby code programmatically, and that way is with ASTs. An AST is an Abstract Syntax Tree, a nested lisp-like representation of a Ruby program:

```ruby
require "rubocop"

def ast_from(string)
  RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f).ast
end

ast_from <<~RUBY
  def my_method(a: 1, b:)
    a + b
  end
RUBY

# returns
s(:def, :my_method,
  s(:args,
    s(:kwoptarg, :a,
      s(:int, 1)),
    s(:kwarg, :b)),
  s(:send,
    s(:lvar, :a), :+,
    s(:lvar, :b)))
```

Now this in and of itself does not make a particularly compelling case for why you might want to work with ASTs, no, so let's take a look at something a bit more pragmatic.

## Our Task - Shorthanding Blocks

If I were to give you the following code:

```ruby
[1, 2, 3].select { |v| v.even? }
```

...how might you go about detecting it and replacing it with its shorthand equivalent?

```ruby
[1, 2, 3].select(&:even?)
```

Well there are a few things that we can immediately identify are similar here:

1. The `Array` of `[1, 2, 3]`
2. `select` is called on that `Array`
3. The block has one argument, and that argument has one method called on it

From a glance this might not be too bad to solve with regex, but what if I said you had to do it across an entire codebase that's accumulated a significant amount of code? You might run into examples like:

```ruby
[1, 2, 3].map { |v| v.to_s(2) } # An argument
[1, 2, 3].select { |v| v.next.even? } # Many methods
[1, 2, 3].map { |v| v.next + 1 } # Perhaps both
x = 4; [1, 2, 3].select { |v| x.even? } # Why though?
```

You can begin to see how the number of variants might stack up here and become difficult to express. People do unusual and creative things in Ruby.

## Enter the AST

Let's start by taking a look at the AST of one of those examples:

```ruby
ast_from <<~RUBY
  [1, 2, 3].select { |v| v.even? }
RUBY

# returns

s(:block,
  s(:send,
    s(:array,
      s(:int, 1),
      s(:int, 2),
      s(:int, 3)), :select),
  s(:args,
    s(:arg, :v)),
  s(:send,
    s(:lvar, :v), :even?))
```

The first step we want to do when considering any AST, and any query we might run against it, is what we're working with and how we might manually transform that code if we saw it.

In this case we would see a few things:

1. `select` has a `block` (or the other way around, not a fan of `block` wrapping `select`)
2. That block has one argument, `v`
3. `v` then receives one method, `even?`
4. There is nothing else in the body of the block

If we were to abstract this to a more general term for a rule, we might say:

1. A method receives a `block`
2. That block has one argument, which we can call `a` for now
3. The body of the block has that argument, `a`
4. `a` receives a single method with no arguments

So we could have `map`, `select`, or really any other method called and the more general rule would still work.

In every case of writing matches against AST I've followed a similar frame of thinking, and generalizing is a very powerful tool here.

Given that we know what we're generally looking for, how might we express that in code? Let's start with something else first.

## Pattern Matching Quickstart

We're going to take a quick whirlwind tour of pattern matching against `Array`-like structures. If you're ever curious to learn more I would recommend reading [Definitive Pattern Matching - Array-like Structures](/writing/2021/02/07/definitive-pattern-matching-array-like-structures-1298/) as it goes into far more detail.

### What is Pattern Matching?

To start out with, pattern matching is the idea that you can describe a pattern you expect data to match:

```ruby
case [1, 2, :a, "b"]
in [Integer, Integer, Symbol, String]
  true
else
  false
end
# => true
```

In Ruby this works with the `case` and `in` branch, rather than the `when` branch you might have seen before. In both cases having a working knowledge of triple equals in Ruby will be invaluable, which you can read into more with [Understanding Ruby - Triple Equals](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/).

With a `when` branch each value separated by `,` is compared against the value with `===`:

```ruby
case 5
when ..-1  then "really small"
when 0..10 then "small"
when 10..  then "large"
end
# => "small"
```

Which is great if you have one value, but how might you match against other types of data? We're focusing on `Array`-like structures for now, and in the above example each value is compared via `===` to each element of the pattern we define.

## Variables, Pinning, and Rightward Assignment

If that were all it would be useful, but not very powerful. That's where we get into variables and pinning. What if I wanted to say I have a nested `Array` with three elements, each starting with the same number? Well it might look something like this:

```ruby
case [[1, 2], [1, 3], [1, 4]]
in [[a, _], [^a, _], [^a, _]]
  true
else
  false
end
# => true
```

In this case we're saying that we expect a value `a` in a nested `Array` with any element (`_`) afterwards, and that same element in the first spot of the next two sub-`Array`s using `^a`, or "pin `a`." What's interesting is this is even more powerful than that last example, like if we also want `a` to be an `Integer`:

```ruby
case [[1, 2], [1, 3], [1, 4]]
in [[Integer => a, _], [^a, _], [^a, _]]
  true
else
  false
end
# => true
```

The value on the left of the rightward-assignment is the match, and the value on the right is what we dump that value into afterwards if it does match. Nifty, no?

You could even do it in a one-liner if you really wanted to:

```ruby
[[1, 2], [1, 3], [1, 4]] in [[Integer => a, _], [^a, _], [^a, _]]
```

...which I tend to prefer, but introducing `case` first is more familiar to start with. Same with rightward assignment, but that's a whole other thing to cover.

### Deconstruct

How does it work behind the scenes? The short version is a method called `deconstruct` which returns an `Array` representation of the code:

```ruby
class Array
  def deconstruct = self
end
```

Now this is just an example, but it would function something like that as an `Array` is already in the needed format. What if we did an AST instead, how would that look when deconstructed? Remember, tree-like structure, so we have to be a bit more clever to get a look outside of pattern matching contexts:

```ruby
# Useful for debugging and seeing how the nodes deconstruct
def deep_deconstruct(node)
  return node unless node.respond_to?(:deconstruct)
  
  node.deconstruct.map { deep_deconstruct(_1) }
end

deep_deconstruct ast_from <<~RUBY
  [].select { |v| v.even? }
RUBY
# => [:block, [:send, [:array], :select],
#      [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

...and trust me when I say that little tool is incredibly valuable for creating patterns.

## Matching ASTs

Taking a look back at our AST and its deconstructed representation:

```ruby
deep_deconstruct ast_from <<~RUBY
  [].select { |v| v.even? }
RUBY
# => [:block, [:send, [:array], :select],
#      [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

...we can start to play directly with that `Array` deconstruction to make our pattern:

```ruby
[:block, [:send, [:array], :select],
  [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

The questions we had above will again be very useful here:

1. A method receives a `block`
2. That block has one argument, which we can call `a` for now
3. The body of the block has that argument, `a`
4. `a` receives a single method with no arguments

Let's break down that `Array` deconstruction question by question then.

### A method receives a block

We have our representation:

```ruby
[:block, [:send, [:array], :select],
  [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

...and all we care about is that it has a block, we don't really care from where, just that the block is there. That means we can drop the entire second piece with `select`:

```ruby
[:block, _, [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

That's great, but seeing is believing, and each step of generalization I would highly encourage testing against at least one example to make sure it still works:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, :v]], [:send, [:lvar, :v], :even?]
]
# => true
```

Oh, right, one-liner may not quite be taken literally, and I've been known to break things across a few lines for readability when it makes sense. In any case this proves the `_` works to stand in for that `Array` receiving `select` just fine, which brings us to the next step.

### The block has one argument, `a`

Starting from last step:

```ruby
[:block, _, [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

The current `arg` is `:v`, but we want it to be generic so we can express a pattern based on it, so let's switch it out with `a` and see what happens:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, a]], [:send, [:lvar, :v], :even?]
]
# => true
```

Still good, but seeing is believing, so let's switch that `in` to `=>` for rightward assignment to see what `a` is now:

```ruby
ast_from(%([].select { |v| v.even? })) => [:block, _,
  [[:arg, a]], [:send, [:lvar, :v], :even?]
]
# => nil (Careful, raises an exception on no match)

a
# => :v
```

Great, next step then.

### The body of the block has that argument

Back to the last step:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, a]], [:send, [:lvar, :v], :even?]
]
# => true
```

What do you think we should do next here? Think about it for a moment before moving on.

This is where pinning becomes exceptionally useful:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, a]], [:send, [:lvar, ^a], :even?]
]
# => true
```

Which leaves us with one last item to address.

### `a` receives a single method with no arguments

Back to the last step:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, a]], [:send, [:lvar, ^a], :even?]
]
# => true
```

All we would need to do here is replace `:even?` with an underscore and:

```ruby
ast_from(%([].select { |v| v.even? })) in [:block, _,
  [[:arg, a]], [:send, [:lvar, ^a], _]
]
# => true
```

...we now have a very general pattern. Let's prove it though:

```ruby
def shorthandable?(ast)
  ast in [:block, _,
    [[:arg, a]], [:send, [:lvar, ^a], _]
  ]
end

shorthandable? ast_from("[1, 2, 3].map { |v| v.to_s }")
# => true
shorthandable? ast_from("[1, 2, 3].map { |v| v.to_s(2) }")
# => false
shorthandable? ast_from("[1, 2, 3].select { |v| v.next.even? }")
# => false
shorthandable? ast_from("[1, 2, 3].map { |v| v.next + 1 }")
# => false
shorthandable? ast_from("x = 4; [1, 2, 3].select { |v| x.even? }")
# => false
```

Neat, but let's take that one step further. I'm lazy, and I want Ruby to rewrite that code for me.

### Rewriting and `source`

Remember assignment in matches? It's about to get very useful:

```ruby
def to_shorthand(ast)
  case ast
  in [:block, receiver, [[:arg, a]], [:send, [:lvar, ^a], method_name]]
    "#{receiver.source}(&:#{method_name})"
  else
    false
  end
end

to_shorthand ast_from("[1, 2, 3].map { |v| v.to_s }")
# => "[1, 2, 3].map(&:to_s)"

to_shorthand ast_from("[1, 2, 3].select { |v| v.even? }")
# => "[1, 2, 3].select(&:even?)"
```

Those underscores we didn't care about before are a bit more important now. We need to know what received the block, so we put that in `receiver`, and then we want to know which method name was called which is put into `method_name`.

The fun one, which is a bit of a jump, is you can convert back to source with the `source` method on an AST node:

```ruby
ast_from("[1, 2, 3].select { |v| v.even? }").source
# => "[1, 2, 3].select { |v| v.even? }"
```

From there it's a quick jump to string interpolation and we have our shiny new shorthand code out the other side.

## But how do I use that?

Great question! It's also one I'll answer in the next few posts on this, but the very short answer is RuboCop for both matching a node and for rewriting it using autocorrection which is really handy.

That said, this post veers a bit long, so I'll wrap it up.

## Wrapping Up

Pattern matching is exceptionally powerful in Ruby, and this post barely scratched the surface of what it can do when used correctly. Combined with ASTs which are essentially nested lists and it's a very useful combination indeed.

That said, there's a matter for next time, which is `NodePattern`. Think of it like regex for ASTs and you won't be far off. It's more succinct than pattern matching, but a bit harder to reason about because of it. Still very useful though, and very common in RuboCop code so definitely worth learning if only for knowing how it works.

With that we'll call this one, and I'll get on with writing the next few.
