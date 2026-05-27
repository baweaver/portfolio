---
layout: "post"
title: "Matchable - Class-level Pattern Matching Macros Explained"
date: "2021-02-01"
categories: ["ruby", "functional"]
tags: ["ruby", "functional", "metaprogramming"]
description: "Introduction   Recently I've released a new gem, Matchable, which introduces class-level mac..."
---

## Introduction

Recently I've released a new gem, [Matchable](https://github.com/baweaver/matchable), which introduces class-level macro methods for Pattern Matching interfaces:

```ruby
class Person
  include Matchable

  deconstruct :new
  deconstruct_keys :name, :age

  attr_reader :name, :age

  def initialize(name, age)
    @name = name
    @age  = age
  end
end
```

This post will explain the thinking behind Matchable and how it works.

## Difficulty and Prerequisite Reading

**Difficulty**: Progressives - Requires some advanced knowledge, explores metaprogramming deeply.

This post will require prerequisite knowledge of the following:

* Ruby Method Decoration and Prepend ([Decorating Ruby Series](/writing))
  * `method_added` hooks
  * `prepend`ing modules for attaching methods
* Pattern Matching ([Pattern Matching Interfaces in Ruby](https://docs.google.com/document/d/1spnuQTKy5i7Lx-sDCsORKN981Iam1IuNdOsYkhh9Yi0/edit#))
* Destructuring ([Destructuring Methods in Ruby](/writing/2018/10/05/destructuring-in-ruby/))
* Class Eval ([Idiosyncratic Eval](https://idiosyncratic-ruby.com/63-instance-eval.html))

I may later write a post on `eval` after this, but the above resources should be useful in the mean time for understanding the foundations of this post. While I will explain some of these concepts I will not go into great depth on them in this article.

# Introducing Matchable

The idea behind Matchable was to create a nice porcelain interface for Pattern Matching hooks at the top level of a Ruby class:

```ruby
class Person
  include Matchable

  deconstruct :new
  deconstruct_keys :name, :age

  attr_reader :name, :age

  def initialize(name, age)
    @name = name
    @age  = age
  end
end
```

## Generated Code Results

This would generate the following effective code:

```ruby
class Person
  MATCHABLE_KEYS = %i(name age)
  MATCHABLE_LAZY_VALUES = {
    name: -> o { o.name },
    age:  -> o { o.age },
  }

  def deconstruct
    to_a
  rescue NameError => e
    raise Matchable::UnmatchedName, e
  end

  def deconstruct_keys(keys)
    return { name: name, age: age } if keys.nil?

    deconstructed_values = {}
    valid_keys           = MATCHABLE_KEYS & keys

    valid_keys.each do |key|
      deconstructed_values[key] = MATCHABLE_LAZY_VALUES[key].call(self)
    end

    deconstructed_values
  rescue NameError => e
    raise Matchable::UnmatchedName, e
  end
end
```

Whereas other implementations would take a more dynamic approach like so:

```ruby
class Person
  VALID_KEYS = %i(name age).freeze
  
  def deconstruct() = VALID_KEYS.map { public_send(_1) }
  
  def deconstruct_keys(keys)
    valid_keys = keys ? VALID_KEYS & keys : VALID_KEYS
    valid_keys.to_h { [_1, public_send(_1)] }    
  end
end
```

Why prefer the generated result? [See for yourself](https://github.com/baweaver/matchable/blob/main/benchmarks/dynamic_vs_generated_benchmark_results.txt). For objects with a substantial number of valid keys the performance difference is potentially 40-50% faster. The goal of this gem is not to produce 100% elegant code as much as produce code that will work quickly out of the box for a feature that may get very heavy use.

This all said, there's a lot behind that code, so let's start exploring shall we?

## Prepended Modules

The first trick to getting macro-style methods like `attr_` methods to work is including a module to make it work. In this case we're prepending so we can attach all of these methods to a distinctly named entity to make the backtrace a bit more readable later:

```ruby
module Matchable
  MODULE_NAME = "MatchableDeconstructors".freeze
  
  def self.included(klass) = klass.extend(ClassMethods)
    
  module ClassMethods
    def deconstruct() = nil # TODO
    def deconstruct_keys(keys) = nil # TODO

    private def matchable_module
      if const_defined?(MODULE_NAME)
        const_get(MODULE_NAME)
      else
        const_set(MODULE_NAME, Module.new).tap(&method(:prepend))
      end
    end
  end
end
```

Make _sure_ to read the [Decorating Ruby Series](/writing) first if this code does not look familiar.

We'll get to defining the other interface methods here in a bit, but we want to start with getting our initial module ready to tie-in the `deconstruct` and `deconstruct_keys` methods.

The `matchable_module` here is where we're going to be attaching all of our new methods for pattern matching. Think of it as a new module container for everything we want to inject put right before the class in terms of calling order:

```
MatchableDeconstructors > Object > ...
```

We could potentially use `include` here instead, but `prepend` opens us up to being able to hook on top of any deconstruction methods the user might make later, and leaves more API options open.

The idea is to have `deconstruct` define a `deconstruct` method on the module, and the same with `deconstruct_keys`. Now that we have our hook, let's look into the actual methods themselves.

# Deconstruct ([src](https://github.com/baweaver/matchable/blob/8a9d69361067f7f65917b7450c274e8884e02377/lib/matchable.rb#L51))

Note that the source code is heavily commented and documented, you can find it in the header above.

`deconstruct` corresponds to Array-like matches in Ruby, and it's also the easier of the two to implement, so let's start here:

```ruby
module Matchable
  module ClassMethods
    def deconstruct(method_name)
      return if matchable_module.const_defined?("MATCHABLE_METHOD")

      method_name = :initialize if method_name == :new
      matchable_module.const_set("MATCHABLE_METHOD", method_name)

      if method_defined?(method_name)
        attach_deconstructor(method_name)
        return [true, method_name]
      end

      @_awaited_deconstruction_method = method_name
      [false, method_name]
    end
  end
end
```

## Constants and Reassignments

To start with you'll notice we're binding to the constant `MATCHABLE_METHOD` to say that we already have `deconstruct` defined. If it's not defined we set it shortly afterwards to gate this from being called more than once.

We're also making sure to reassign `:new` to `:initialize`, as `:new` is likely a more common interpretation. There's special behavior for htat methor we'll get to shortly.

## Method Defined?

This is an interesting call:

```ruby
if method_defined?(method_name)
```

Why do we need to check if the method is defined? Give it a second to consider before you keep reading, it made me scratch my head for a few minutes.

That's because macro-style methods are defined at the top of the class, _before_ those same methods are initialized, and we need those methods to exist first as `Symbol`s like `attr_` methods won't work for us as you'll see in a moment.

So this for instance will break without that check:

```ruby
class Person
  include Matchable
  
  deconstruct :new
  attr_reader :name, :age
  
  def initialize(name, age)
  end
end
```

...because `initialize` isn't defined yet. We'll get into why that's important for this code in a moment, but first we'll go over how we get around that issue.

## Method Added

Right under that code you'll see a flag being set:

```ruby
@_awaited_deconstruction_method = method_name
```

As you've either read from the prereads or seen before, there's a hook for `method_added` which will be called for every newly defined method. If it doesn't exist now, it will eventually, so we hook that:

```ruby
def method_added(method_name)
  return unless defined?(@_awaited_deconstruction_method)
  return unless @_awaited_deconstruction_method == method_name

  attach_deconstructor(method_name)
  remove_instance_variable(:@_awaited_deconstruction_method)

  nil
end
```

If it's the method we're looking for we attach our deconstructor, otherwise we keep going. The `nil` return is because we don't care about the return and don't want people using that later.

Now that we have a way to intercept the methods when they finally get around to being created, we want to take a look at `attach_deconstructor` and how that works, and why this dance is even necessary.

## Attach Deconstructor

To start with, if you haven't yet, be _sure_ to read [Destructuring Methods in Ruby](/writing/2018/10/05/destructuring-in-ruby/) unless you already know what `parameters` does and how that might be useful here in a second.

Now then, let's take a look at the `attach_deconstructor` method:

```ruby
private def attach_deconstructor(method_name)
  deconstruction_code =
    if method_name == :initialize
      i_method    = instance_method(method_name)
      param_names = i_method.parameters.map(&:last)
      "[#{param_names.join(', ')}]"
    else
      method_name
    end

  matchable_module.class_eval <<~RUBY, __FILE__ , __LINE__ + 1
    def deconstruct
      #{deconstruction_code}
    rescue NameError => e
      raise Matchable::UnmatchedName, e
    end
  RUBY

  nil
end
```

### Forking Initialize Behavior

We start by checking whether or not this is an `initialize` call, if it is we want to do something special. We want to take all the param names, wrap them in an `Array`, and return that instead of directly calling a method.

In the case of `Person` that'd return this:

```ruby
def deconstruct() = [name, age]
```

Just make sure those `attr_` methods are in there or you'll have issues.

### Regular Method Behavior

If it's not `initialize` we return the method name to call.

That makes this work a lot like `alias`, except we want to wrap it in a custom exception, so it'd end up looking more like this for `to_a`:

```ruby
def deconstruct
  to_a
rescue NameError => e
  raise Matchable::UnmatchedName, e
end
```

This is done to wrap `NameError` with an extra message to indicate a few methods are missing to make this thing work.

### Class Eval

This comes to the interesting part: `class_eval`.

We're using this to evaluate the code we've assembled a bit more manually inside of the module we defined above, which is then prepended before the class to give it our pattern matching methods:

```ruby
matchable_module.class_eval <<~RUBY, __FILE__ , __LINE__ + 1
  def deconstruct
    #{deconstruction_code}
  rescue NameError => e
    raise Matchable::UnmatchedName, e
  end
RUBY
```

Why not use a block? Why a `String`? Because we want to do some things we can't do unless we make Ruby write its own Ruby, and for that we need `eval` methods to "compile" things for us to give us a more optimized method.

The mentions of `__FILE__` and `__LINE__ + 1` here are to make sure that this evaluated code is put in the proper flow of our Ruby program for debuggers, backtraces, and other tools to find it later.

[Read more into why this is here](https://olabini.com/blog/2008/01/ruby-antipattern-using-eval-without-positioning-information/), but the short version is that it's much easier to troubleshoot and work with later.

That brings us to the end of `deconstruct`, which means our next section on `deconstruct_keys` is coming up, and it's a trip.

# Deconstruct Keys ([src](https://github.com/baweaver/matchable/blob/8a9d69361067f7f65917b7450c274e8884e02377/lib/matchable.rb#L99))

Note that the source code is heavily commented and documented, you can find it in the header above.

Now this is a fair bit more complicated than `deconstruct` as we have a few considerations to work with:

1. We have a list of `keys` to deal with for optimization purposes
2. Those `keys` mean different responses
3. If `keys` are `nil` we need to return every possible key

That can make this a bit harder to reason about and dynamically compile against, but there are still tricks for making this work.

Let's start with a look at the code:

```ruby
def deconstruct_keys(*keys)
  return if matchable_module.const_defined?('MATCHABLE_KEYS')

  sym_keys = keys.map(&:to_sym)

  matchable_module.const_set('MATCHABLE_KEYS', sym_keys)
  matchable_module.const_set('MATCHABLE_LAZY_VALUES', lazy_match_values(sym_keys))

  matchable_module.class_eval <<~RUBY, __FILE__ , __LINE__ + 1
    def deconstruct_keys(keys)
      if keys.nil?
        return {
          #{nil_guard_values(sym_keys)}
        }
      end

      deconstructed_values = {}
      valid_keys           = MATCHABLE_KEYS & keys

      valid_keys.each do |key|
        deconstructed_values[key] = MATCHABLE_LAZY_VALUES[key].call(self)
      end

      deconstructed_values
    rescue NameError => e
      raise Matchable::UnmatchedName, e
    end
  RUBY

  nil
end
```

## Constants and Keys

To start out with we have a few constants being defined, and our keys are getting mapped to `Symbol`s just to be sure:

```ruby
return if matchable_module.const_defined?('MATCHABLE_KEYS')

sym_keys = keys.map(&:to_sym)

matchable_module.const_set('MATCHABLE_KEYS', sym_keys)
matchable_module.const_set('MATCHABLE_LAZY_VALUES', lazy_match_values(sym_keys))
```

We're using `MATCHABLE_KEYS` here as our `VALID_KEYS` to guard against unknown values. If it's defined we know we're already done with this method and can return early.

If it's not defined we get our `Symbol` keys and set it.

Afterwards we have something interesting, `MATCHABLE_LAZY_VALUES`. Let's take a look into that.

## Matchable Lazy Values

What exactly is this constant doing? It's providing a mapping of `method_name` to a lazy way to fetch its value:

```ruby
def lazy_match_values(method_names)
  method_names
    .map { |method_name| "  #{method_name}: -> o { o.#{method_name} }," }
    .join("\n")
    .then { |kv_pairs| "{\n#{kv_pairs}\n}"}
    .then { |ruby_code| eval ruby_code }
end
```

`keys` are synonymous to `method_names` in this gem, as we use methods to fetch values. With each of those names we want to create a `Hash` key-value pair, the `method_name` pointing to a `lambda` that takes an `Object` and calls the method directly on it. For `name` it would look like this:

```ruby
name: -> o { o.name }
```

This is faster than `public_send` by a decent amount, and provides us a way to get at individual values without calculating them directly at match time.

The original method to do this was:

```ruby
<<~RUBY
  if keys.nil? || keys.include?(:#{method_name})
    deconstructed_values[:#{method_name}] = method_name
  end
RUBY
```

...which incurred the unfortunate inner-loop, slowing down the code substantially.

Anyways, after we have those key-value pairs we join them together, wrap them in `Hash` brackets, and `eval` it into a Ruby `Hash` and we're off to the races again. We'll get into what this is used for here in a moment.

## If keys are `nil`

Back to our `class_eval`, we'll see this code:

```ruby
matchable_module.class_eval <<~RUBY, __FILE__ , __LINE__ + 1
  def deconstruct_keys(keys)
    if keys.nil?
      return {
        #{nil_guard_values(sym_keys)}
      }
    end
    
    # ...
```

Remembering back a bit, if `keys` are `nil` we need to return every value. The above code removed the necessity of the `if keys.nil? || keys.include?` check, but didn't do anything about the `nil` case.

That's where this comes into play with `nil_guard_value`.

### `nil` Guard Values

This method is actually rather boring:

```ruby
def nil_guard_values(method_names)
  method_names
    .map { |method_name| "#{method_name}: #{method_name}" }
    .join(",\n")
end
```

It transforms all the method names into key-value pairs without the added need for laziness in a partial match, joins them together, and leaves it up to the code above to wrap it in `Hash` brackets to give us our branch for all keys being required.

## Deconstructed Values and Valid Keys

After we deal with the all keys branch we need to filter things down. To start with we want a place to store our new values, and a set of keys we should be returning:

```ruby
deconstructed_values = {}
valid_keys           = MATCHABLE_KEYS & keys
```

The `Hash` is self-explanatory for adding more values to, but `valid_keys` is a bit more interesting. What we're doing here is finding the intersection between the valid matchable keys we know, and the keys we were provided. This is to make sure we don't get any strange keys that we don't know how to handle.

## Getting Lazy Values

Next up we want to actually get the values based on those valid keys:

```ruby
valid_keys.each do |key|
  deconstructed_values[key] = MATCHABLE_LAZY_VALUES[key].call(self)
end

deconstructed_values
```

We iterate over every one of the valid keys and set a value in `deconstructed_values` by referencing our lazy value fetcher we mentioned above. We call this with `self` to get the value out of the object, and after we're done here we return back all the values we've extracted.

### Musing on Macros

**WARNING**: The below musing is not valid Ruby, just me dreaming

There is part of me that wishes I could do somthing like this instead of hacking around `public_send` being slower:

```ruby
valid_keys.each do |key|
  deconstructed_values[key] = ${key}
end

deconstructed_values
```

...where `${}` would be a macro system that could directly inline the associated code rather than need to send the value. Matz mentioned we may one day get macros, but today is not that day, so we continue to dream a bit while we add new and interesting patches to get around it.

That gets us to the end of `deconstruct_keys`, so let's wrap this up.

# Benchmarking

So is this all worth it? Feel free to [take a look at the benchmarks](https://github.com/baweaver/matchable/tree/8a9d69361067f7f65917b7450c274e8884e02377/benchmarks) to find out, but I'll summarize here.

We have two types of objects being tested, one with two attributes and one with twenty six. Here's what we came up with, with Dynamic being the normal way and Macro being the way mentioned above:

```yaml
Person (2 attributes):
  Full Hash:
    Dynamic: 5.027M
    Macro:   5.542M
    Gain:    9.3%
  Partial Hash:
    Dynamic: 7.551M
    Macro:   8.436M
    Gain:    10.5%
  Array:
    Dynamic: 7.105M
    Macro:   10.689M
    Gain:    33.5%

BigAttr (26 attributes):
  Full Hash:
    Dynamic: 984.300k
    Macro:   3.248M
    Gain:    69.7%
  Partial Hash:
    Dynamic: 2.594M
    Macro:   2.956M
    Gain:    12.3%
  Array:
    Dynamic: 1.488M
    Macro:   7.957M
    Gain:    81.3%
```

The more attributes you have the more gains this starts to see, especially around Arrays, though I would suggest against having that many attributes to match against in an Array.

So was it worth it? Honestly most of this was a test to see how it would work, the performance gains on things were a convenient side effect. I do not think the gains are substantial enough to justify implementing this all yourself, but if you want to use this gem to get those benefits you're more than welcome to.

# Wrapping Up

That was quite a ride through a lot of metaprogramming, and a lot of interesting things in Ruby. Some of it I had to spend a bit researching and musing on before I came to decent solutions, but that's most of the fun of it.

If I entirely know what I'm doing what's the fun in that? It's fun to go and explore, to try new things, and to test the boundaries of what's possible in programming. Go out and give it a try yourself sometime, it's great fun!

Anyways, that's all I have for this one, I hope you've enjoyed this little dive into using `eval` for compiling dynamic code.
