---
layout: "post"
title: "ASTs in Ruby - Node Pattern and Introducing RuboCop"
series: "asts-in-ruby"
date: "2022-06-15"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "In the last article I was not being quite honest when I said that regex would not work when trying to..."
---

In the last article I was not being quite honest when I said that regex would not work when trying to manipulate Ruby files. Strictly speaking, no, regex is not a good idea for working with tree-like structures and tokens but there is something there we need to take a look at.

Regexp stands for Regular Expressions, or in the way I tend to define it a set of expressions that can describe the shape of text in such a way you can match against anything with a similar shape. We could be pedantic and go into [regular languages](https://en.wikipedia.org/wiki/Regular_language), but let's instead focus on this part:

**describe the shape of text**

Who's to say we couldn't have an expression language of some sort that would match against other shapes, like say... ASTs? That, my friends, is where NodePattern comes in and is the start of what we'll be covering in this article.

## Tools of the Trade

To start out with though, you'll want a few methods and helpers to work with here:

```ruby
require "rubocop"

# Turn a string into a RuboCop AST (based on WhiteQuark's AST)
def ast_from(string)
  RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f).ast
end

# Useful for debugging and seeing how the nodes deconstruct
def deep_deconstruct(node)
  return node unless node.respond_to?(:deconstruct)

  node.deconstruct.map { deep_deconstruct(_1) }
end

# Create a NodePattern from a string
def node_pattern_from(string)
  RuboCop::NodePattern.new(string)
end
```

With these three we'll have most of what we need to get started working with NodePatterns. Eventually I may wrap these in a gem later, and if I do I'll update this article to reflect that.

Naturally the best source of information is [the official documentation for NodePattern](https://docs.rubocop.org/rubocop-ast/node_pattern.html), and you'll find it to be quite comprehensive.

Oh, and that regex bit? Remember how we have [Rubular](https://rubular.com/) for regex? We have the [NodePattern Debugger](https://nodepattern.herokuapp.com/) for ASTs which you will find incredibly helpful, in fact you might open it now and try out some of these examples to make sure I'm not pulling a [Fast](https://github.com/jonatas/fast) one. (No, I'm not apologizing for that one.)

## Quickstart on NodePattern

Before we get too deep, let's start with a basic example of NodePattern and what that might look like with this code example:

```ruby
code = "a = 1 + 1"
ast_from(code)

# returns

s(:lvasgn, :a,
  s(:send,
    s(:int, 1), :+,
    s(:int, 1)))
```

After reading the previous article on pattern matching this is going to look very familiar, but an exact match in NodePattern might look something like this:

```ruby
node_pattern = node_pattern_from <<~PATTERN
  (lvasgn :a
    (send (int 1) :+ (int 1)))
PATTERN

node_pattern.match(ast_from("a = 1 + 1"))
# => true
```

If we were to use pattern matching for this it might instead look like this:

```ruby
ast_from("a = 1 + 1") in [:lvasgn, :a,
  [:send, [:int, 1], :+, [:int, 1]]
]
# true
```

We could certainly say the NodePattern is more succinct, and you might notice that you can omit the `Symbol`s for keywords in Ruby versus things like values, variables, and method names (`+` is a method, fun fact.)

But we said regexen, which means that's the start of what NodePattern can do. Let's say we wanted to make sure that both of those values being added were the same, like with pinning in pattern matching:

```ruby
node_pattern = node_pattern_from <<~PATTERN
  (lvasgn :a
    (send _value :+ _value))
PATTERN

node_pattern.match(ast_from("a = 1 + 1"))
# => true
```

So unlike pinning similar underscore variables have to be the same, without requiring `^` like in pattern matching:

```ruby
ast_from("a = 1 + 1") in [:lvasgn, :a, [:send, v, :+, ^v]]
# => true
```

Ah, and before we get too much into it? You can use both of them somewhat interchangeably though NodePattern does have a slight edge in power but readability tends to be a preference thing. ASTs are _hard_ in general to work with, especially for larger tasks, so I'm not going to say easy.

### Back to Shorthand

Let's take a look back at the code examples from the previous article:

```ruby
[1, 2, 3].select { |v| v.even? } # What we expect
[1, 2, 3].map { |v| v.to_s(2) } # An argument
[1, 2, 3].select { |v| v.next.even? } # Many methods
[1, 2, 3].map { |v| v.next + 1 } # Perhaps both
x = 4; [1, 2, 3].select { |v| x.even? } # Why though?
```

...or, more specifically, let's focus back in on the first one for now:

```ruby
code = "[1, 2, 3].select { |v| v.even? }"
ast = ast_from(code)

deep_deconstruct(ast)
# => [:block,
#      [:send, [:array, [:int, 1], [:int, 2], [:int, 3]], :select],
#      [[:arg, :v]], [:send, [:lvar, :v], :even?]]
```

You'll see in a moment, much like with the pattern matching variants, why the `Array` representation can make this much easier to reason about. In fact, let's recall how we solved this with pattern matching before:

```ruby
def shorthandable?(ast)
  ast in [:block, _,
    [[:arg, a]], [:send, [:lvar, ^a], _]
  ]
end
```

If we were to convert that to NodePattern it might look like this instead:

```ruby
SHORTHAND_PATTERN = node_pattern_from <<~PATTERN
  (block $_receiver
    (args (arg _a)) (send (lvar _a) $_method_name))
PATTERN

def shorthandable_np?(ast)
  !!SHORTHAND_PATTERN.match(ast)
end

shorthandable_np?(ast_from("[1, 2, 3].select { |v| v.even? }"))
# => true

SHORTHAND_PATTERN.match(ast_from("[1, 2, 3].select { |v| v.even? }"))

# returns

[s(:send,
  s(:array,
    s(:int, 1),
    s(:int, 2),
    s(:int, 3)), :select), :even?]
```

One insidious little trick you might notice is that `args` is conspicuously absent from the deconstructed `Array` representation, so you do need to be careful with some edges on interpretations.

The other interesting thing here is the `$`, which is NodePattern for "capture". While you could certainly capture with `$_` I prefer to name those captures so I know what they were. Out the other side of `match` you'll notice that both of those AST nodes were returned as well, which were the receiver and the method name.

### That's More Code Though?

You are absolutely correct there my clever clever reader, that it is. NodePattern on its own isn't quite as powerful as it might be when it's used in conjunction with RuboCop. Granted sometimes for testing I'll still use something very similar to the above, but the true power starts showing up here in the next section.

#### What About the Rest of NodePattern?

The documentation will go into much more comprehensive detail, but we've barely looked into some of the power of NodePattern and what's possible with it. Given that, we still took a look at some of the most commonly used parts of it, which serves as a decent introduction for the moment.

## Introducing RuboCop

So where are we going with this? We've shown how to match against and rewrite code, sure, but how do we actually apply that? That's where [RuboCop](https://rubocop.org/) comes in. The unfortunate part is that so many only think of RuboCop as a tool to nag you on stylistic items, but it's far more than that.

RuboCop is also a set of tools for identifying and potentially even replacing code that matches a certain pattern using custom cops. There's even an entire section of the docs which covers this in [Development](https://docs.rubocop.org/rubocop/1.29/development.html). 

You'll notice much of what we've covered so far is going to get you pretty far down that page, but let's take a detour into our shorthand syntax again and focus on that.

### Custom Shorthand Cop

A RuboCop cop will look something like this:

```ruby
module RuboCop
  module Cop
    module Style # Namespace
      class UseShorthandBlockSyntax < Base # Our name
        # If we only want to see if something matches, excluding captures
        def_node_matcher :shorthand?, <<~PATTERN
          (block _receiver
            (args (arg _a)) (send (lvar _a) _method_name))
        PATTERN
        
        # If we still want those captures, we'll get to this next article
        SHORTHAND_PATTERN = RuboCop::NodePattern.new <<~PATTERN
          (block $_receiver
            (args (arg _a)) (send (lvar _a) $_method_name))
        PATTERN
        
        # On any block node RuboCop encounters, send it to this method
        def on_block(node)
          # Using that helper method above, it it's not shorthand bail out
          return false unless shorthand?(node)
          
          # If it is, mark the node as an offense
          add_offense(node)
        end
      end
    end
  end
end
```

The items which will look particularly strange to you are `def_node_matcher`, `on_block`, and `add_offense`.

#### Node Matcher

`def_node_matcher` creates a predicate method from a NodePattern which we called with `return false unless shorthand?(node)` and takes care of all the `match` handling for us. If we used a constant we'd still have to manually create the NodePattern from a String and call `match` on it later.

#### On Methods

`on_block` is interesting in that any block node that RuboCop catches will be sent to any `on_block` method to check if it's a match. The `on_` methods exist for every type of block, and are typically the entry point to your checks. Frequently this will be `on_send` instead.

#### Add Offense

This is where we tell RuboCop that the node is a match for our rule, and that we want to flag it for reporting. Interestingly there are more options here around formatting the violation message, choosing where the violation occurred (entire node, part of it, where?), and a few more options.

###  Testing

Now what makes this really powerful is the suite of testing tools to verify that various types of code are or are not matches for your new rule, and when we get to automatic correction? You can even test that it happened to replace it correctly.

You can see why this might be _real_ handy indeed.

Ah, and RSpec has an inline outrun mode, so let's sneak that into our script right quick:

```ruby
require "rubocop"
require "rspec/autorun"
require "rubocop/rspec/support"

module RuboCop
  module Cop
    module Style
      class UseShorthandBlockSyntax < Base
        def_node_matcher :shorthand?, <<~PATTERN
          (block _receiver
            (args (arg _a)) (send (lvar _a) _method_name))
        PATTERN

        # Make a custom message, if you want. `add_offense` also accepts one
        MSG = "BAD!"

        def on_block(node)
          return false unless shorthand?(node)

          add_offense(node)
        end
      end
    end
  end
end

# Quick config - This gives us the helpers like `expect_offense`
RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
end

# Make SURE to include the `:config` here, or `cop` will be undefined on run
RSpec.describe RuboCop::Cop::Style::UseShorthandBlockSyntax, :config do
  it "catches a match" do
    # Specify which code meets the rule, and what the error should look like
    expect_offense(<<~RUBY)
      [1, 2, 3].select { |v| v.even? }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BAD!
    RUBY
  end

  it "does not catch a non-match" do
    # Or that there are no offenses from something
    expect_no_offenses(<<~RUBY)
      [1, 2, 3].map { |v| v.to_s(2) }
    RUBY
  end
end
```

Granted you should probably nest that in your spec folder somewhere, but you can see how that could become very useful for quick tests.

The major point here is that you can test against multiple variations of code you might expect, and define whether or not they should match your rule, and that's exceptionally powerful in large code bases.

Now that all said, we'll save the really fun stuff for next time.

## Wrap Up

The point of this article was to introduce you to NodePattern, some of the tooling around it, and how that might look when integrated into RuboCop. It's very much meant as an introduction rather than a de-facto guide. The documentation will do a better job of that, but it's nice to know these things exist.

Next time, however, we're going to take a look into the single most powerful secret that very few know of:

Autocorrection.

If we're just talking lint and style sure, that's interesting but not highly useful beyond prettying things up. No no, we're talking something far more incredible, and that would be code migrations. If you have, say, a giant monorepo and you want to migrate a pattern of code everywhere with the added benefit of testability you'll be real fond of the next piece in this series.
