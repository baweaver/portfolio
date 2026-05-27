---
layout: "post"
title: "For want of Pattern Matching in Ruby — The Creation of Qo"
date: "2018-04-15"
categories: []
tags: []
description: ""
---

Qo Lemur logo

Qo is a Ruby gem made to emulate pattern matching and fluent querying found in other languages.
[**baweaver/qo**
*qo - Qo - Query Object - Pattern matching and fluent querying in Ruby*github.com](https://github.com/baweaver/qo)

Qo, the name, is short for Query Object.

It employs a collection of various tricks related to === and Proc in Ruby. Don’t know what === can do yet? You might want to start with this article first:
[**Triple Equals Black Magic**
*For the most part, === is either ignored or used in the background of case statements. Now there are several articles…*medium.com](/writing/2017/10/16/triple-equals-black-magic/)

Qo came from a discussion I’d had with a few Rubyists at Fog City Ruby about pattern matching in Ruby and how you could get a vague facsimile of which using a case statement and ===.

Though that raised the question, how far could one take this? Well, spoilers, the answer for me was Qo.

## What does Qo do?

Let’s start with a few examples of Qo:

    **case** ['Foo', 42]
    **when** Qo[:*, 42] **then** 'Truly the one answer'
    **else** nil
    **end**

    # Run a select like an AR query, getting the age attribute
    # against a range
    people.**select**(&Qo[age: 18..30])

    # How about some "right-hand assignment" pattern matching
    name_longer_than_three      = -> person { person.name.size > 3 }
    people_with_truncated_names = people.**map**(&Qo.match_fn(
      Qo.m(name_longer_than_three) { |person|
        Person.new(person.name[0..2], person.age)
      },

      Qo.m(:*) # Identity function, catch-all
    ))

    # And standalone like a case:
    Qo.match(people.first,
      Qo.m(age: 10..19) { |person|
        "#{person.name} is a teen that's #{person.age} years old"
      },

      Qo.m(:*) { |person|
        "#{person.name} is #{person.age} years old"
      }
    )

In this article we’re going to go over how Qo is doing what it’s doing.

## Case Statements — Array matches Array

The first example was what happens when an Array is matched against an Array:

    **case** ['Foo', 42]
    **when** Qo[:*****, 42] **then** 'Truly the one answer'
    **else** **nil**
    **end**

What Qo is doing here is going through each element of the left side and matching it against the right in the following order:

1. Is there a wildcard?

1. Does it match the right side with === ?

1. Is there a predicate method we can call, and does it return true?

Remembering that case uses === behind the scenes, we can use this when making a Qo object to match against it.

Now how would we do that using a Lambda function? The first thing is to remember what a closure is:

    adder = -> x { -> y { x + y } }
    [1, 2, 3].map(&adder[2])

That function would add two to every element in the array, but how does it remember what x was? Because whenever calling the method with adder[2] happens, it returns a new function that remembers the value.

We can use that here to our advantage by making a matcher:

    Qo = -> *matchers {
      -> target {}
    }

Question is, what do we put in there? Well Qo will positionally compare the arguments. That means the first matcher goes against the first value and so forth until it runs out. each_with_index will do nicely here to make sure we’re comparing them in the right order:

    Qo = -> *matchers {
      -> target {
        matchers.each_with_index.all? { |matcher, i|
          matcher === target[i]
        }
      }
    }

This gives us enough for any of the === values, but what about the wildcard? Turns out if branches work just fine:

    Qo = -> *matchers {
      -> target {
        matchers.each_with_index.all? { |matcher, i|
          matcher == :* || matcher === target[i]
        }
      }
    }

Because functions in Ruby will respond to call, .(), ===, and [] we can use them fairly flexibly to make a more Ruby-like API.

In this case, we can use the array bracket notation to return a new function that’s just waiting for a target to match against which is perfect for a case statement!

Keep in mind that functions in Ruby can take arguments much the same as any other method. That means keywords, varargs, blocks, and even default values are completely fair game.

This brings us to the next section.

## Enumerable functions — Hash matches Object

In the next code sample we were using ampersand to let select know we were passing it a function:

    people.**select**(**&**Qo[age: 18**..**30])

Turns out this isn’t much different from the above, we’re just using keyword arguments instead against a series of objects:

    Qo = -> **matchers {
      -> target {
        # ...
      }
    }

Now the question is, how do you take a Hash of arguments and see if they actually apply to an object? This is where we get into a bit of meta Ruby, as the answer is public_send.

What we want to do is see if the target, given a matcher key as a method name, is a case match (===) for the value:

    Qo = -> **matchers {
      -> target {
        matchers.all? { |match_key, match_value|
          match_value === target.public_send(match_key)
        }
      }
    }

Be careful, === is definitely left biased. This is because === is defined on the caller as a method, which allows Ruby to overwrite it with some interesting behavior.

This is why some times I’ll wrap === in another function for clarity:

    def case_match(target, matcher) matcher === target end

It also makes error logs a bit clearer if that’s where it crashes, considering you get a name with it as well.
> **Note**: There’s a bug in Ruby 2.4+ that lambdas won’t destructure args: [https://github.com/baweaver/qo/issues/11](https://github.com/baweaver/qo/issues/11)

A particularly tricksy programmer may also remember that inheritance is a thing, and might be able to be abused. Good! That’s exactly what I did in the next section.

## Pattern Matching

So now that we have a few matchers to play with, how exactly does this syntax work?:

    # How about some "right-hand assignment" pattern matching
    name_longer_than_three      = -> person { person.name.size > 3 }
    people_with_truncated_names = people.map(&Qo.match_fn(
      Qo.m(name_longer_than_three) { |person|
        Person.new(person.name[0..2], person.age)
      },

      Qo.m(:*) # Identity function, catch-all
    ))

We know that normal Qo matchers are going to return a boolean status as to whether or not they pass, but these have a block associated and actually return a value. What gives?

Well as Qo works, every matcher like Qo[] is an instance of Qo::Matcher which responds to to_proc and the various invocations of call for procs.

This means that the to_proc method is the one that determines what gets returned to the outside world. For our base matcher, it looks like this:

    def to_proc
      if [@array_matchers](http://twitter.com/array_matchers).empty?
        match_against_hash([@keyword_matchers](http://twitter.com/keyword_matchers))
      else
        match_against_array([@array_matchers](http://twitter.com/array_matchers))
      end
    end

What it’s doing is deciding if we’re dealing with a hash or an array match based on the presence of varargs. These eventually end up returning procs which are waiting for a match target.

What if we took inheritance and made a new type of matcher based on our old one? Turns out we can, and it works quite well. The problem to consider though, what if the actual result of that block is falsey? Would the matcher dump it?

The answer is that we wrap it. We already know that a matcher will return true or false depending on the match status, so we can steal that and make a new to_proc in [lib/qo/guard_block_matcher.rb](https://github.com/baweaver/qo/commit/814470dfa88fc9ba3d1fac6114805b14cd632ade#diff-dfb669e5e619b2b15bc6aede7482bb20) by leaning on super:

    def to_proc
      -> match_target {
        return [false, false] unless super[match_target]

        [true, [@fn](http://twitter.com/fn).call(match_target)]
      }
    end

Super here refers to the original matcher, which gives us that lovely boolean return value. If it’s false we just return a tuple of (status, result) to be deconstructed by the match function we saw above. Same with the true branch, except its result is based on calling the function we got with the match target.

So what’s the extraction? A simple reduce loop with a break:

    def match(target, *qo_matchers)
      all_are_guards = qo_matchers.all? { |q|
        q.is_a?(Qo::GuardBlockMatcher)
      }

      raise 'Must patch Qo GuardBlockMatchers!' unless all_are_guards

      qo_matchers.reduce(nil) { |_, matcher|
        did_match, match_result = matcher.call(target)
        break match_result if did_match
      }
    end

We first make sure that we only got a hold of GuardBlockMatchers, as a regular one won’t know what to do with any of this. Next we just reduce onto nil.

We don’t care about the return value here unless we find a did_match value in there. If nothing is found, we get back nil.

Why not each? One less step to return nil instead of the collection and the ability to deconstruct it while I’m at it, unlike find.

For now this simply yields the full matched value into the provided block.

The alternative, which would be closer to right-hand assignment, would be fraught with slowdowns and truly black magic. Maybe I find a quick solution for that, but not quite yet.

So what’s with the star matcher?

    Qo.m(:*)

It’s a catch-all. Think of it like else, except it always returns true and always returns the object sent to it. It can take a block as well if you’re so inclined.

## The Origin of Qo

As I mentioned before, Qo came from a discussion at Fog City Ruby on Pattern Matching. What I haven’t mentioned yet is that there was a gist where a lot of these ideas came from. Enjoy some of the original ideas for Qo!

<iframe src="https://medium.com/media/a33952b3866d2e8c2d17688cb5424576" frameborder=0></iframe>

Most of these ideas ended up making it into the main Qo library, and more are yet to come.

## Wrapping Up

Qo has been an interesting experiment so far, and we’re currently working on getting it polished up for a 1.0.0 release to standardize and stabilize the public API.

As is I’ll avoid name changes where possible, but 1.0.0 will be the finalized public API.

It’s wise to remember though, with great power and expressiveness come some performance trade-offs. Qo tries to be smart, so we’re going to have to work on pairing that down into more concrete abstractions to bring it up to cruising speed.

With that said, go give Qo a try, let me know what you think!
[**baweaver/qo**
*qo - Qo - Query Object - Pattern matching and fluent querying in Ruby*github.com](https://github.com/baweaver/qo)

Next up is a post explaining some of the fun tricks you can use Qo for.
