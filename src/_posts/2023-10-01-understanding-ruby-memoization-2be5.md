---
layout: "post"
title: "Understanding Ruby - Memoization"
series: "understanding-ruby"
date: "2023-10-01"
categories: ["ruby", "beginners"]
tags: ["ruby", "beginners"]
description: "Introduction   Memoization is a common technique in Ruby, but alas it's one with a few..."
---

# Introduction

Memoization is a common technique in Ruby, but alas it's one with a few potential gotchas we need to be aware of to use it effectively. This post gives a short introduction to things that you probably want to watch out for when memoizing, or rather remembering, values that methods compute.

## Difficulty

**Foundational**

Little to no prerequisite knowledge required. This post focuses on foundational and fundamental knowledge for Ruby programmers.

# Memoization

First off, what do we mean when we say memoization? Shortly put it's a way to "remember" a value a method might produce, especially whenever that method happens to be expensive. If it happens to take a few seconds to run a method it'd probably be a good idea to store what the result was just to make sure we don't have to run the entire thing over again.

This, in essence, is memoization. We memorize, memoize, remember, or otherwise keep a record of what happened last time we did something.

That all said rarely is something quite so straightforward, and this post does elide a few concerns in favor of being a more introductory text. Shall we get into it then?

## Instance Variables and `||=`

The first method, and the one you're most likely to see, is that an instance method of a class happens to use `||=` and an instance variable to remember a value:

```ruby
class MyClass
  def some_method
  	@some_method ||= some_expensive_computation_or_api_call
  end
end
```

If we happen to say this:

```ruby
our_thing = MyClass.new
out_thing.some_method
out_thing.some_method
```

...the second run will not run the code on the right side, the `some_expensive_computation_or_api_call`, which might be something more along the lines of say:

```ruby
@some_method ||= Net::HTTP
	.get(URI("url_goes_here"))
	.then { |http_response| JSON.parse(http_response) }
```

### `||=` and What it Does

Why does that work though? Well let's take a quick detour to look at `||=` and what it does. The short version is that these two lines are roughly equivalent:

```ruby
a = a || "new value"
a ||= "new value"
```

The second only elides the `= a ||` part in favor of `||=`. This works great in most cases, but it has one glaring weakness: legitimate falsy values.

### Legitimate Falsy Values

In Ruby only `nil` and `false` are considered to be falsy. The problem is if `false` or `nil` happen to be an expected return of an expensive method. Let's say we had this:

```ruby
class MyClass
  def some_question?
    @some_question ||= api_response.include?("expected value")
  end
  
  def api_response
    Net::HTTP.get(URI("url_goes_here"))
  end
end
```

Chances are if the response of `some_question?` is `false` that's a valid return, and we don't want to go calling the API repeatedly until it happens to be true, meaning that `||=` would cause it to get called repeatedly.

That's not great, so what do we do about it instead?

## The `defined?` method

We can check whether an instance variable was even defined in the first place using `defined?`. It works on any type of variable, so let's start with a local variable here:

```ruby
defined? a
# => nil
```

Now you might expect this to give a Boolean result, but in actuality it does something a bit odd:

```ruby
defined? a
# => nil

a = 5
defined? a
# => "local-variable"
```

Considering a `String` is truthy this doesn't really present an issue, but it's good to know that this does not return `true` or `false`, but rather the type of variable or `nil`.

Why is this important? Well if we took that same method from above where `||=` fails to "remember" legitimately false values we could make it into something like this instead:

```ruby
class MyClass
  def some_question?
    return @some_question if defined? @some_question
    
    @some_question = api_response.include?("expected value")
  end
  
  def api_response
    Net::HTTP.get(URI("url_goes_here"))
  end
end
```

Now if that instance variable happens to be set the value will be remembered despite being falsy in nature.

## So Which Do I Use?

If a method is Boolean (it returns `true` or `false`) in nature use `defined?`. If it returns any other type, or you want to recompute in the cases of `false` or `nil` you're safe to use `||=` instead.

## You Said It's More Complicated?

Yep. Left as an exercise to the reader what do you reckon happens if we start introducing method arguments into the equation, or other inputs from other parts of the application? In those cases the responses are only valid in the same context, like being called with the same arguments.

You can still do this with a `Hash`, yes, but we won't get too far into that in this article as that would be more advanced. If you want a more detailed explanation of this feel free to leave a comment and I can look into it.

There's also the entire `&&=` operator which very few people use, which is more of a "yes, and..." concept, but that's also another article. I may write that one regardless as I very rarely see it in production code, but it definitely has a place there.

## Wrapping Up

This, again, is more of an introduction to memoization in Ruby. There are more detailed guides out there including this RubyConf talk called "[Achieving Fast Method Metaprogramming: Lessons from Memowize](https://www.youtube.com/watch?v=c2Pa6W_O8oo)"

I will be looking to expand this series as I get back into mentorship more at work with common questions I happen to see come up. If you happen to have questions about any part of Ruby feel free to reach out or comment on this post and I can take a look into covering them as well.
