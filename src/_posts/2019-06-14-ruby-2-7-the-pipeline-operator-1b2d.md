---
layout: "post"
title: "Ruby 2.7: The Pipeline Operator"
date: "2019-06-14"
categories: ["ruby"]
tags: ["ruby"]
description: "A pipeline operator has been added to Ruby, but not quite the one we'd expected"
---

Ruby 2.7 has added the pipeline operator ( `|>` ), but not in the way many Rubyists had expected.

[The merge can be found here](https://github.com/ruby/ruby/commit/f169043d81524b5b529f2c1e9c35437ba5bc3a7a).

**Update**:

[Matz has expressed that he is looking for opinions on this feature on Twitter](https://twitter.com/yukihiro_matz/status/1139419951444271104)

Please keep feedback constructive and civil (MINASWAN), and focus on his mention of the [LISP-1/LISP-2 namespacing](http://ergoemacs.org/emacs/lisp1_vs_lisp2.html) issues as they are a real issue for implementing real Elixir-like pipes.

Discussion is happening on the [Ruby Bugtracker](https://bugs.ruby-lang.org/issues/15799)

**Update 2**

This article is historical. There is no pipeline operator in Ruby, and it was rejected after discussion [here](https://bugs.ruby-lang.org/issues/15799#note-46):

> After experiments, |> have caused more confusion and controversy far more than I expected. I still value the chaining operator, but drawbacks are bigger than the benefit. So I just give up the idea now. Maybe we would revisit the idea in the future (with different operator appearance).

> During the discussion, we introduced the comment in the method chain allowed. It will not be removed.

> Matz.

## What it does

The pipeline operator is effectively an alias for dot-chaining, and from the source:

```ruby
# This code equals to the next code.

foo()
  |> bar 1, 2
  |> display

foo()
  .bar(1, 2)
  .display
```

...and from the test code:

```ruby
def test_pipeline_operator
  assert_valid_syntax('x |> y')
  x = nil
  assert_equal("121", eval('x = 12 |> pow(2) |> to_s(11)'))
  assert_equal(12, x)
end
```

This, as it is written, is the current implementation of the pipeline operator as has been discussed in the [Ruby bug tracker](https://bugs.ruby-lang.org/issues/15799).

Chris Salzberg [mentioned](https://bugs.ruby-lang.org/issues/15799#note-21) in the issue that the reason might have been its lower precedence than the dot operator:

> The operator has lower precedence than `.`, so you can do this:
> 
> ```ruby
> a .. b |> each do
> end
> ```
> 
> With `.`, because of its higher precedence, you'd have to do use braces:
> 
> ```ruby
> (a..b).each do
> end
> ```

...in which he closes:

> The bigger point IMHO though is that major controversial decisions are
> made based on this kind of very brief, mostly closed discussion.
> [I don't think that's a good thing for our community.](https://twitter.com/shioyama/status/1139168800794791936)

I am inclined to agree with him and several others discussing this change, and will lay out my reasoning for this below, including points in favor and counterpoints to the contrary.

## Points in Favor

Of the points in favor, I have seen a few:

### Ruby already has multiple syntaxes for blocks

[One of the points](https://github.com/ruby/ruby/commit/f169043d81524b5b529f2c1e9c35437ba5bc3a7a#commitcomment-33926904) raised is that Ruby already has multiple syntaxes for creating blocks, such as `do ... end` versus `{ ... }`.

Pipelining is seen as a way to multi-line methods and make it clearer that that is being done:

```ruby
# Original
foo.bar.baz

# Current
foo
  .bar
  .baz

# Alternate Current:
foo.
  bar.
  baz

# Pipelined:
foo
|> bar
|> baz
```

#### Counterpoint

My objection to this would be that Ruby blocks are already confusing for newer developers, and are frequently a subject of contention when learning Ruby.

Adding a new language construct that does not have a clear differentiating factor will only exacerbate this and make the language harder to learn.

### Precedence

Another point [raised](https://bugs.ruby-lang.org/issues/15799#note-21) was that the pipeline operator has a lower precedence than the `.`, allowing for paren-free programming as mentioned above:

```ruby
# Current
(a..b).each do
end

# Pipelined
a .. b |> each do
end
```

#### Counterpoint

We also have precedence arguments over the english operators `and` and `or`, which are generally agreed upon to not be in common usage in the language because of the confusion they might cause.

As with the above issue of multiple syntaxes for the same task with different precedences, this will also confuse newer programmers.

## Main Objections

With recent controversial features like [Pattern Matching](/writing/2019/04/17/ruby-2-7-pattern-matching-first-impressions-13j9/) and [Numbered Parameters](/writing/2019/03/18/ruby-2-7-numbered-parameters-1a79/) there have been debates about the exact syntax, but the discussion had several come to the support of the feature as it added something distinctly new to the language.

In this case I do not believe this is so. The new pipeline operator feels like an alias of `.`, a syntactic sugar when it could have been substantially more for the language.

The main points in favor relate to a difference in precedence evaluation, an issue that has caused great confusion in newer Ruby programmers in the past, and still continues to this day.

Introducing a new symbol in a language should add a new and more expressive way to do things in that language. I do not believe this achieves that goal.

## What Could It Have Been?

The main points to the contrary are that the pipeline in other languages is a powerful and expressive feature for code. I would like to show you some of those implementations and let you judge for yourself their merits.

### In Javascript

TC39 has [discussed a pipeline operator](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Pipeline_operator) which is currently under careful evaluation. As Javascript is a very similar language to Ruby, many ideas have been shared between the two languages, and many more are very possible.

In their example:

```javascript
const double = (n) => n * 2;
const increment = (n) => n + 1;

// without pipeline operator
double(increment(double(double(5)))); // 42

// with pipeline operator
5 |> double |> double |> increment |> double; // 42
```

The pipeline operator is used to provide the output of the left side to the input of the right side. It explicitly requires that this be the sole argument to the function, of which can be circumvented with currying techniques in both languages to partially apply functions.

#### Javascript Pipeline Applied to Ruby

This is very similar to the Ruby convention of `then`:

```ruby
double = -> n { n * 2 }
increment = -> n { n + 1 }

double[increment[double[double[5]]]]
# => 42

5.then(&double).then(&double).then(&increment).then(&double)
```

If the pipeline operator were to be an alias of `then` that can reasonably infer `to_proc` / `&` and method calls, it would look quite the same as Javascript:

```ruby
5 |> double |> double |> increment |> double
# => 42
```

This achieves a few major items:

1. It removes the need for explicit block-tagging with `&`
2. It simplifies the `then` variant of the code
3. It (ideally) can intelligently deal with both methods and procs

By dealing with methods and procs, I mean that this would not change the output of the above code:

```ruby
def double(n)
  n * 2
end

increment = -> n { n + 1 }

5 |> double |> double |> increment |> double
# => 42
```

This, I believe, is a more true-to-ruby implementation that is expressive and elegant, allowing for simpler syntax to carry a more complicated idea seamlessly.

It uses the idea of duck-typing with operators to say that these two should behave the same to achieve a syntax which is very powerful.

### In OCaml and F#

The [example](https://fsharpforfunandprofit.com/posts/function-composition/#composition-vs-pipeline) from OCaml and F# look very similar, so we'll focus on the F# variant which also highlights the difference between this and composition (which I won't cover here, but worth a read):

```fsharp
let (|>) x f = f x
```

It works by piping the last parameter into the function:

```fsharp
let doSomething x y z = x+y+z
doSomething 1 2 3       // all parameters after function
3 |> doSomething 1 2    // last parameter piped in
```

I am not immediately familiar with F#, but this appears to be a currying implementation which achieves some of what was mentioned in the Javascript example

#### F# Pipeline Applied to Ruby

This introduces an interesting idea of currying, which is applying arguments to a function and waiting for a final argument to call through to get a value. We already have this in Ruby with `curry`:

```ruby
adds = -> a, b { a + b }.curry

adds[2, 3]
# => 5

adds[2]
# => #<Proc:0x00007fe8ab6996a0 (lambda)>
adds[2][3]
# => 5
```

While I don't think auto-currying would match Ruby well, it would make an interesting addition to the pipeline operator:

```ruby
adds = -> a, b { a + b }.curry

def double(n)
  n * 2
end

increment = -> n { n + 1 }

5 |> adds[2] |> double |> increment
# => 15
```

### In Elixir

[Elixir works much the same way](https://elixirschool.com/en/lessons/basics/pipe-operator/) as the Javascript implementation, except in that it can also "soft-curry" functions that are waiting for an additional input if they're in a pipeline.

Again, I'm not familiar with Elixir to a deep level, and would welcome corrections on this:

```elixir
"Elixir rocks" |> String.upcase() |> String.split()
["ELIXIR", "ROCKS"]

"elixir" |> String.ends_with?("ixir")
true
```

Interestingly it contends with one of the issues Ruby would have with some of this, being ambiguous syntax around parentheses:

```elixir
iex> "elixir" |> String.ends_with? "ixir"
warning: parentheses are required when piping into a function call.
For example:

  foo 1 |> bar 2 |> baz 3

is ambiguous and should be written as

  foo(1) |> bar(2) |> baz(3)

true
```

## Combining Worlds

Now here's a shocking revelation: I like the idea of using it as an alias for `.`, _but_....

...it should be a combination of both that and the above ideas from other languages:

```ruby
5
|> double
|> increment
|> to_s(2)
|> reverse
|> to_i
```

This gives us a substantial increase in expressive power while unifying the current implementation with established ideas from other languages. I would be very excited if such an implementation were to come into use as it would combine the best of the functional world with Ruby's natural Object Orientation to achieve something entirely new.

To me, that's what Ruby is, achieving something new with ideas from around the world and from different languages. We bring together the novel and exciting and make it our own, and I believe with the pipeline operator we have an amazing chance to do this!

I just do not believe that the current implementation fully realizes this potential, and that makes me sad.
