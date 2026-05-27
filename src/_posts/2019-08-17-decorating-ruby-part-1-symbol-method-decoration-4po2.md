---
layout: "post"
title: "Decorating Ruby - Part One - Symbol Method Decoration"
series: "decorating-ruby"
date: "2019-08-17"
categories: ["ruby"]
tags: ["ruby"]
description: "How various forms of method decoration work in Ruby"
---

One precursor of me writing an article is if I keep forgetting how something's done, causing me to write a reference to look back on for later. This is one such article.

# What's in Store for Today?

In this particular article we'll be taking a look at various methods of method decoration and some lovely metaprogramming to go along with it to give Ruby that extra little bend.

![The "Dark Lord" Crimson with Metaprogramming magic](/images/posts/decorating-ruby/img-26ace945.png)

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[Next >>](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)

# What's Decoration?

Decoration is the idea of "decorating" a method with a little something extra. A little spice, flavor, what have you.

Have you ever written code like this?

```ruby
def something
  @something ||= expensive_call_here
end
```

That starts becoming real common real quickly, no? Litter that throughout a codebase and it's become almost a pattern of its own for memoization. Wouldn't it be nice if we could say one word instead of having to repeatedly type out those instance variables?

Decoration would allow us to do something like this:

```ruby
memoized def something
  expensive_call_here
end
```

It would do effectively the same thing, but how it does it is something entirely different, something we'll be exploring in this article.

# Symbol Method Decoration

Referring to decoration that takes a Symbol of a methods name to redefine it to add extra behavior. This is what we'll be looking at for part one, as there's quite a bit to cover here.

## Method Definition returns Symbols

The first example we used relies on a fact introduced in Ruby 2.1+: When a method is defined, it's an expression which returns a Symbol containing the name of the method.

Give it a try in a REPL real quick:

```ruby
def testing; end
# => :testing
```

This allows us to prefix the method definition with another method that does something with that fact. You may have commonly seen this pattern in Ruby for private methods:

```ruby
private

def private_a; end
def private_b; end
```

Both of those methods will be considered private, but there's another way of using `private` in Ruby, one I personally prefer for clarity:

```ruby
private def private_a; end
private def private_b; end
```

It allows us to explicitly prefix a method as being private, making it easier to move around and tell from a glance what's actually private.

(Well, as private as one gets in Ruby, we _are_ using metaprogramming after all...)

Given that, how does a method that takes a symbol redefine that method? We'll need a few more tools to do that.

## The `method` Method

So we have a Symbol of the method name, great, but how do we do something with that? One way is using the `method` method:

```ruby
def testing; 1 end

original_method = method(:testing)
# => #<Method: main.testing>

original_method.call
# => 1
```

This creates a Proc-like object, an instance of [Method](https://ruby-doc.org/core-2.6.3/Method.html) that can be invoked just like a Proc with arguments and whatever else you'd normally pass.

There are other very useful things you can do with this little fact, but that's out of the scope for this article, perhaps another day there.

What's important is we have a callable representation of a method via the methods name.

## A Method that Eats Methods and `define_method`

Let's start with something light, a method which will eat whatever method you pass it. We can call it something cute like `quiet`:

```ruby
def quiet(method_name)
  define_method(method_name) { nil }
end
```

This introduces another concept, `define_method`, which can define a method in place. This includes methods which are already defined, letting us overwrite something that's in place.

If we were to call this on our previous testing method:

```ruby
quiet def testing; 1 end

testing
# => nil
```

The `1` is gone, we've just run straight over the old method. Now this isn't particularly useful, we could just use `remove_method` instead for the same effect.

Effectiveness aside, we know we can redefine a method via its name and use it as a prefix.

## What's in Store?

Back to our original cache idea, how would we pull something like that off? Looking back, we have all the tools we need already, we just need to put them together to make something useful.

Consider `define_method` as a way to "wrap" a method with some additional behavior. All we have to do is capture to original arguments and pass them merrily along and we can do whatever we want with what the original method returns inside of it:

```ruby
define_method(name) { |*args, &fn| original_method.call(*args, &fn) }
```

Now it's just a matter of adding that extra little spice to the wrapping. Remember that a cache, at least a basic one, looks like this:

```ruby
def something
  @something ||= expensive_call
end
```

The idea is to use `||=` to store the value and not make another expensive call. This is precisely what we want to emulate to make a caching prefix:

```ruby
def cache(method_name)
  original_method = method(method_name)

  define_method(method_name) do |*args, &fn|
    ivar = :"@#{method_name}"
    cached_value = instance_variable_get(ivar)

    return cached_value if cached_value

    value = original_method.call(*args, &fn)
    instance_variable_set(ivar, value)
  end
end
```

## Break Down!

Breaking that down, we have a few other novel concepts here, mostly to do with instance variables and dynamically handling them.

The first line we remember from above, we want the original method:

```ruby
original_method = method(method_name)
```

Next we're redefining the original method by name and proxying the arguments on through:

```ruby
define_method(method_name) do |*args, &fn|
```

Where we get a bit interesting is when we get to the next line, we're naming an instance variable by prefixing the method name with an `@`:

```ruby
ivar = :"@#{method_name}"
```

This allows us to see if a value already exists:

```ruby
cached_value = instance_variable_get(ivar)
```

Now be careful here, because the next line does something subtle you might not like:

```ruby
return cached_value if cached_value
```

If that value is falsy, it's going to skip that and redefine the value. This is the same issue with `||=`, and can be solved by changing that line to this instead:

```ruby
return cached_value if instance_variable_defined?(ivar)
```

That'll use the fact of whether or not the variable was defined instead of the truthiness of its value.

The next few lines are where we make sure to remember the value:

```ruby
value = original_method.call(*args, &fn)
instance_variable_set(ivar, value)
```

We pull the value out of the method, and we set an instance variable to remember it for us later.

## The Run Around

Let's give it a try:


```ruby
cache def excruciatingly_long_method_call
  (1..1_000_000).to_a.sample(10)
end

excruciatingly_long_method_call
# => [116266, 583871, 537296, 296408, 563441, 92172, 511762, 597596, 681279, 951614]

excruciatingly_long_method_call
# => [116266, 583871, 537296, 296408, 563441, 92172, 511762, 597596, 681279, 951614]

excruciatingly_long_method_call
# => [116266, 583871, 537296, 296408, 563441, 92172, 511762, 597596, 681279, 951614]


excruciatingly_long_method_call
# => [116266, 583871, 537296, 296408, 563441, 92172, 511762, 597596, 681279, 951614]
```

Now unless you're really lucky, you'll get some different numbers there. Add 3 to 6 extra 0s to make it actually take a while, but I'm impatient, so a million or so should do just fine.

(With `srand` seeds you _could_ reproduce it but that gets us a bit off track)

With that we have a cached method, and we only had to put `cache` in front of it to do all that. Nifty, no?

# Wrapping Up

Next time around we'll be taking a look into a bit more advanced of a method of decorating, involving `method_added`, `alias_method`, and `instance_exec` among some other nifty tricks.

**Table of Contents**

- [Part One - Symbol Method Decoration](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/)
- [Part Two - Method Added Decoration](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
- [Part Three - Prepending Decoration](/writing/2019/08/20/decorating-ruby-part-three-prepending-decoration-1ehc/)

[Next >>](/writing/2019/08/18/decorating-ruby-part-two-method-added-decoration-48mj/)
