---
layout: "post"
title: "Decorating Ruby - Part Three - Prepending Decoration"
series: "decorating-ruby"
date: "2019-08-20"
categories: ["ruby"]
tags: ["ruby"]
description: "How various forms of method decoration work in Ruby"
---

One precursor of me writing an article is if I keep forgetting how something's done, causing me to write a reference to look back on for later. This is one such article.

# What's in Store for Today?

We'll be looking at the next type of decoration, which involves prepending a module in the call chain.

![The "Dark Lord" Crimson with Metaprogramming magic](/images/posts/decorating-ruby/img-26ace945.png)

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[<< Previous](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/) | ~~Next >>~~

# What Does Prepending Look Like?

Prepending is when we take a bit of code and we put it in front of the original:

```
Prepended -> Original -> Call Chain
```

It's different than `include`, which inserts _after_ the original:

```
Original -> Included -> Call Chain
```
## Included in the Mix

To demonstrate, let's make a `talk` function in a module, `Talkable`, and `include` it in a `Lemur` class:

```ruby
module Talkable
  def talk; "Hi there!" end
end

class Lemur
  include Talkable
end

Lemur.new.talk
# => "Hi there!"
```

What happens if `Lemur` has its own talk method though?:

```ruby
module Talkable
  def talk; "Hi there!" end
end

class Lemur
  include Talkable

  def talk; "I wasn't expecting you today" end
end

Lemur.new.talk
# => "I wasn't expecting you today"
```

Because `Lemur` has a method for `talk`, it gets called first in the call chain.

## Prepended Instead?

What if we switch `include` to `prepend` instead?

```ruby
module Talkable
  def talk; "Hi there!" end
end

class Lemur
  prepend Talkable

  def talk; "I wasn't expecting you today" end
end

Lemur.new.talk
# => "Hi there!"
```

> Oh, if you're in `pry` or `irb`, remember that that `include` from earlier will still be there. Ruby's open classes can make for some fun debugging problems.

`prepend` puts `Talkable#talk` _in front of_ `Lemur#talk`, causing it to get called first.

This has an interesting side effect as well: We can use `super` to refer to the original class:

```ruby
module Talkable
  def talk; "Hi there! #{super}" end
end

class Lemur
  prepend Talkable

  def talk; "I wasn't expecting you today" end
end

Lemur.new.talk
# => "Hi there! I wasn't expecting you today"
```

Remember this one, because there are all types of fun implications there.

## Extend the Conversation

Then what's `extend`? It does neither of those two, it `extend`s a class with the modules methods, making them class methods instead.

Confused? Oh that's no problem whatsoever, I frequently end up switching between the two (`include` and `extend`) until my code works some times. I should probably write a full article on call chains some time later with picture references to remind me. Pictures make everything more fun.

Ah, right, `prepend` for decoration, right right. Let's get back to that.

# Decorating with Prepend

Once again, we're going to need to know a few things, and venture down the metaprogramming rabbit-hole a few more meters.

## Modules on the Fly

You've seen modules created like this:

```ruby
module Talkable
  def talk; "Hi there!" end
end
```

In Ruby, we can define a module dynamically:

```ruby
Module.new do
  def talk; "Hi there!" end
end
```

Like most expressions in Ruby, this is a value, which means we can do all types of fun things with it.

## A Constant Experience

We could assign this to a variable, or if we really wanted to we could make a constant out of it:

```ruby
mod = Module.new do
  def talk; "Hi there!" end
end

Lemur.const_set("Talkable", mod)
# => Lemur::Talkable
```

After that's done, we can check whether or not that constant exists:

```ruby
Lemur.const_defined?("Talkable")
# => true
```

Then we can get it:

```ruby
Lemur.const_get("Talkable")
# => Lemur::Talkable
```

Mind, you can't do this at top level (TIL, that's no fun...), but you can do it on any defined class like `Object` or `Kernel` even! (though that would be particularly naughty.)

Point being, these constants give a nice name to a potentially dynamically defined value, and allow us to do some fun things.

## The Classy Metaprogramming Extraordinaire

What if we want to dynamically define a few methods? We remember `define_method` from some of the previous articles, but what if we wanted to define a method inside of a module?

Ruby lets us do that too with `class_eval`:

```ruby
mod = Module.new

phrases = {
  hello: "Why hello there!",
  goodbye: "Fare thee well!"
}

mod.class_eval do
  phrases.each do |name, phrase|
    define_method(name) { phrase }
  end
end

mod.instance_methods
=> [:hello, :goodbye]
```

But this is a module! We should have used `module_eval`! Well, we could, but they're the same thing:

```ruby
[2] pry(main)> $ mod.class_eval

From: vm_eval.c (C Method):
Owner: Module
Visibility: public
Number of lines: 5

VALUE
rb_mod_module_eval(int argc, const VALUE *argv, VALUE mod)
{
    return specific_eval(argc, argv, mod, mod);
}
[3] pry(main)> $ mod.module_eval

From: vm_eval.c (C Method):
Owner: Module
Visibility: public
Number of lines: 5

VALUE
rb_mod_module_eval(int argc, const VALUE *argv, VALUE mod)
{
    return specific_eval(argc, argv, mod, mod);
}
```

> `$` is a shortcut for showing the source of something in `pry`. I use it quite a bit. `?` does the same but for its documentation.

# Prepending at Last!

Now that we know all that, it's time to tie it all together in a grand metaprogramming bit of magic!

The fun part is that most of the techniques from the previous two sections are still very much relevant here. For this one though, I always want to know how long something took.

Let's make a prepended decorator to tell us just that! We'll call it `Timeable`:

```ruby
module Timeable
end
```

Inside of it we're going to need a method to wrap another, which you may remember from the `Symbol` method:

```ruby
module Timeable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def measure(method_name)
    end
  end
end
```

Now we're going to need to use that knowledge of constants to give ourselves a hook point to add things into. It'd be rather impolite to prepend several modules to a class, so we keep it in one place. This also helps with tracing things down later if we need to debug:

```ruby
module Timeable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def measure(method_name)
      timing_module =
        if const_defined?("Timing")
          const_get("Timing")
        else
          const_set("Timing", Module.new).tap(&method(:prepend))
        end

      p timing_module
    end
  end
end

class Lemur
  include Timeable

  measure "Something"
end
# => Lemur::Timing
```

We're using `tap` here as `prepend` returns back the constant that something was prepended to. `Lemur`, in this case, but we want the `Timing` constant instead. The `p` at the end is to prove that it works.

Either the constant exists, or we create it and `prepend` it to the class that includes `Timeable`

## A Time and a Place

Let's implement this thing:

```ruby
module Timeable
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def measure(method_name)
      timing_module =
        if const_defined?("Timing")
          const_get("Timing")
        else
          const_set("Timing", Module.new).tap(&method(:prepend))
        end

      timing_module.class_eval do
        define_method(method_name) do |*args, &fn|
          start_time = Time.now
          result = super(*args, &fn)
          puts "Time taken: #{Time.now - start_time}"
          result
        end
      end
    end
  end
end

class Lemur
  include Timeable

  measure def super_cached_array_sample
    @super_cached_array_sample ||= (1..100_000_000).to_a.sample(10)
  end
end
```

Running that gets us this:

```ruby
indigo = Lemur.new

indigo.super_cached_array_sample
# Time taken: 3.165698
# => [30125753, 40206899, 23039117, 35232027, 60498349, 60359828, 24456489, 58646248, 96152882, 69191217]
indigo.super_cached_array_sample
# Time taken: 2.0e-06
# => [30125753, 40206899, 23039117, 35232027, 60498349, 60359828, 24456489, 58646248, 96152882, 69191217]
```

If we take a look at the ancestors of our dear Lemur class, we find something fun:

```ruby
Lemur.ancestors
# => [Lemur::Timing, Lemur, Timeable, Object
```

The only thing we're doing here is using the time from before the original method runs and the time after, and using `puts` to log that out to the screen for us.

## But What About Method Added?

We could, we certainly could at that. It's also more code, so I leave that as an exercise to the reader to combine these two techniques into something fun!

Learning Ruby is a process of learning several small things that help us come up with answers to bigger problems. Once you develop an intuition for what things go where with a veritable toolbelt you'll be ready for almost anything.

Do mind one of those tools is using a search engine and asking for help every now and then. I certainly still do.

# Wrapping Up

Magic upon magic, and this has been quite the series to write. Who knows, I may even sneak another part into here somewhere, though the only remaining ideas I have are far darker magics involving `TracePoint` and [I've already written a few articles on that](/writing/2019/02/08/exploring-tracepoint-in-rubypart-oneexample-code/).

I may well translate them over to dev.to and finish up the last few parts. Decoration is certainly magic, but `TracePoint` is straight up arcane level fun and shenanigans.

As with all magic, discretion is wise, but avoiding it entirely? Sometimes you need the chainsaw to trim a tree, and by golly we're going to get you a bright shiny magical metaphorical chainsaw to go trim the most epic of trees you can imagine.

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[<< Previous](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/) | ~~Next >>~~
