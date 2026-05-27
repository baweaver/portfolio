---
layout: "post"
title: "Decorating Ruby - Part Two - Method Added Decoration"
series: "decorating-ruby"
date: "2019-08-18"
categories: ["ruby"]
tags: ["ruby"]
description: "How various forms of method decoration work in Ruby"
---

One precursor of me writing an article is if I keep forgetting how something's done, causing me to write a reference to look back on for later. This is one such article.

# What's in Store for Today?

We'll be looking at the next type of decoration, which involves intercepting `method_added` to make a more fluent interface.

![The "Dark Lord" Crimson with Metaprogramming magic](/images/posts/decorating-ruby/img-26ace945.png)

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[<< Previous](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/) | [Next >>](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

# What Does Method Added Decoration Look Like?

You've seen the Symbol Method variant:

```ruby
private def something; end
```

Readers that were paying very close attention in the last article may have noticed when I said that I preferred that style of declaring `private` methods in Ruby, but this was _after_ the way that can be debatably considered more popular and widely used in the community:

```ruby
private

def something; end
def something_else; end
```

Using `private` like this means that _every_ method defined after will be considered private. We know how the first one works, but what about the second? There's no way it's using method names because it catches both of those methods and doesn't change the definition syntax.

That's what we'll be looking into and learning today, and let me tell you it's a metaprogramming trip.

# Making Our Own Method Added Decoration

As with the last article we're going to need to learn about a few tools before we'll be ready to implement this one.

## Module Inclusion

Ruby uses Module inclusion as a way to extend classes with additional behavior, sometimes requiring an interface to be met before it can do so. `Enumerable` is one of the most common, and requires an `each` implementation to work:

```ruby
class Collection
  include Enumerable

  def initialize(*items)
    @items = items
  end

  def each(&fn)
    return @items.to_enum unless block_given?
    @items.each { |item| fn.call(item) }
  end
end
```

(`yield` could be used here instead, but is less explicit and can be confusing to teach.)

By defining that one method we've given our class the ability to do all types of amazing things like `map`, `select`, and more.

Through those few lines we've added a lot of functionality to a class. Here's the interesting part about Ruby: it also provides hooks to let `Enumerable` know it was included, including what included it.

## Feeling Included

Let's say we have our own module, [`Affable`](https://www.merriam-webster.com/dictionary/affable), which gives us a method to say "hi":

```ruby
module Affable
  def greeting
    "It's so very lovely to see you today!"
  end
end
```

My, it _is_ quite an [`Affable`](https://www.merriam-webster.com/dictionary/affable) module, now isn't it?

We could even go as far as to make a particularly `Affable` lemur:

```ruby
class Lemur
  include Affable
  def initialize(name) @name = name; end
end

Lemur.new("Indigo").greeting
=> "It's so very lovely to see you today!"
```

What a classy lemur, yes.

## Hook, Line, and Sinker

Let's say that we wanted to tell what particular animal was `Affable`. We can use `included` to see just that:

```ruby
module Affable
  def self.included(klass)
    puts "#{klass.name} has become extra Affable!"
  end
end
```

If we were to re-`include` that module:

```ruby
class Lemur
  include Affable
  def initialize(name) @name = name; end
end

# STDOUT: Lemur has become extra Affable!
# => :initialize
```

Right classy. Oh, right, speaking of classy...

## Extra Classy Indeed

So we can hook inclusion of a module, great! Why do we care?

What if we wanted to both include methods into a class _as well as_ extend its behavior?

With just `include` it will apply all the behavior to _instances_ of a class. With just `extend` it will apply all the behavior to _the class itself_. We can't do both.

...ok ok, it's Ruby, you caught me, we can totally do both.

As it turns out, `include` and `extend` are just methods on a class. We could just `Lemur.extend(ExtraBehavior)` if we wanted to, or we could use our fun little hooks from earlier.

A common convention for using this technique is a sub-module called `ClassMethods`, like so:

```ruby
module Affable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def affable?
      true
    end
  end
end
```

This allows us to inject behavior directly into the class as well as other behavior we want to include in instances.

Part of me thinks this is so I don't have to remember the difference between `include` and `extend`, but I always remember that and don't have to spend 20 minutes flipping between the two and `prepend` to see which one actually works, absolutely not.

Now remember the title about Method Added being the technique for today? Oh yes, there's a hook for that as well, but first we need to indicate that something needs to be hooked in the first place.

## Raise Your Flag

We can intercept a method being added, but how do we know which method _should_ be intercepted? We'd need to add a flag to let that hook know it's time to start intercepting in full force.

```ruby
module Affable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def extra_affable
      @extra_affable = true
    end
  end
end
```

If you remember `private`, this could be the flag to indicate that every method afterwards should be private:

```ruby
private

def something; end
def something_else; end
```

Same idea here, and once a flag is raised it can also be taken down to make sure later methods aren't impacted as well. We keep hinting at hooking method added, so let's go ahead and do just that.

## Method Added

Now that we have our flag, we have enough to hook into `method_added`:

```ruby
module Affable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def extra_affable
      @extra_affable = true
    end

    def method_added(method_name)
      return unless @extra_affable

      @extra_affable = false
      # ...
    end
  end
end
```

We can use our flag to ignore `method_added` unless said flag is set. After we check that, we can take down the flag to make sure additional methods defined after aren't affected as well. For `private` this doesn't happen, but we want to be polite. It _is_ and `Affable` module after all.

## Politely Aliasing

Speaking of politeness, it's not precisely kind to just overwrite a method without giving a way to call it as it was. We can use `alias_method` to get a new name to the method before we overwrite it:

```ruby
def method_added(method_name)
  return unless @extra_affable

  @extra_affable = false

  original_method_name = "#{method_name}_without_affability".to_sym
  alias_method original_method_name, method_name
end
```

This means that we can access the original method through this name.

## Wrap Battle

So we have the original method aliased, our hook in place, let's get to overwriting that method then! As with the last tutorial we can use `define_method` to do this:

```ruby
module Affable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def extra_affable
      @extra_affable = true
    end

    def method_added(method_name)
      return unless @extra_affable

      @extra_affable = false

      original_method_name = "#{method_name}_without_affability".to_sym
      alias_method original_method_name, method_name

      define_method(method_name) do |*args, &fn|
        original_result = send(original_method_name, *args, &fn)

        "#{original_result} Very lovely indeed!"
      end
    end
  end
end
```

Overwriting our original class again:

```ruby
class Lemur
  include Affable

  def initialize(name) @name = name; end

  extra_affable

  def farewell
    "Farewell! It was lovely to chat."
  end
end
```

We can give it a try:

```ruby
Lemur.new("Indigo").farewell
=> "Farewell! It was lovely to chat. Very lovely indeed!"
```

## `send` Help!

Wait wait wait wait, `send`? Didn't we use `method` last time?

We did, but remember that `method_added` is a class method that does not have the context of an instance of the class, or in other words it has no idea where the `farewell` method is located.

`send` lets us treat this as an instance again by sending the method name directly. Now we _could_ use `method` inside of here as well, but that can be a bit more expensive.

Only the contents inside `define_method`'s block are executed in the context of the instance.

## `exec`utive Functions

If we wanted to, we could have our special method take blocks which execute in the context of an instance as well, and this is an extra special bonus trick for this post.

Say that we made `extra_affable` also take a block that allows us to manipulate the original value and still execute in the context of the instance:

```ruby
class Lemur
  include Affable

  def initialize(name) @name = name; end

  extra_affable { |original|
    "#{@name}: #{original} Very lovely indeed!"
  }

  def farewell
    "Farewell! It was lovely to chat."
  end
end
```

With normal blocks, this will evaluate in the context of the class, but we want it to evaluate in the context of the instance instead. That's what we have `instance_exec` for:

```ruby
module Affable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def extra_affable(&fn)
      @extra_affable    = true
      @extra_affable_fn = fn
    end

    def method_added(method_name)
      return unless @extra_affable

      @extra_affable   = false
      extra_affable_fn = @extra_affable_fn

      original_method_name = "#{method_name}_without_affability".to_sym
      alias_method original_method_name, method_name

      define_method(method_name) do |*args, &fn|
        original_result = send(original_method_name, *args, &fn)
        instance_exec(original_result, &extra_affable_fn)
      end
    end
  end
end
```

Running that gives us this:

```ruby
Lemur.new("Indigo").farewell
# => "Indigo: Farewell! It was lovely to chat. Very lovely indeed!"
```

Now pay very close attention to this line:

```ruby
extra_affable_fn = @extra_affable_fn
```

We need to use this because inside `define_method`'s block is inside the instance, which has no clue what `@extra_affable_fn` is. That said, it can still see outside to the context where the block was called, meaning it can see that local version of `extra_affable_fn` sitting right there, allowing us to call it:

```ruby
instance_exec(original_result, &extra_affable_fn)
```

## `instance_eval` vs `instance_exec`?

Why not use `instance_eval`? `instance_exec` allows us to pass along arguments as well, otherwise `instance_eval` would make a lot of sense to evaluate something in an instance. Instead, we need to execute something in the context of an instance, so we use `instance_exec` here.

# Wrapping Up

So that was quite a lot of magic, and it took me a fair bit to really understand what some of it was doing and why. That's perfectly ok, if I understood everything the first time I'd be worried because that means I'm not really learning anything!

One issue I think this will have later is I wonder how poorly having multiple hooks to `method_added` will work. If it turns out it makes things go boom in a spectacularly pretty and confounding way there'll be a part three. If not, this paragraph will disappear and I'll pretend to not know what you're talking about if you ask me about it.

There's a lot of potential here for some really interesting things, but there's also a lot of potential for abuse. Be sure to not abuse such magic, because for every layer of redefinition code can become increasingly harder to reason about and test later.

In most cases I would instead advocate for `SimpleDelegate`, `Forwardable`, or simple inheritance with `super` to extend behavior of classes. Don't use a chainsaw where hedge trimmers will do, but on occasion it's nice to know a chainsaw is there for those particularly gnarly problems.

Discretion is the name of the game.

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[<< Previous](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/) | [Next >>](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)
