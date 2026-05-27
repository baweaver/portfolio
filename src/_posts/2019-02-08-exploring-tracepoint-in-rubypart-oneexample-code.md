---
layout: "post"
title: "Exploring TracePoint in Ruby — Part One — Example Code"
date: "2019-02-08"
categories: []
tags: ["ruby", "metaprogramming"]
description: "An introduction to TracePoint in Ruby — what it does, how it works, and practical examples of tracing code execution."
---

TracePoint is an extremely powerful feature of Ruby, but it can be a bit difficult to use and wrap your head around. Let’s take a look at what it does and how we can use it to do some awesome things in Ruby!

<!-- ![](/images/posts/2019-02-08-exploring-tracepoint-in-rubypart-oneexample-code/img-0f32f1f5.png) -->

This article is rated at a **difficulty of 3 out of 5**, and requires some prerequisite knowledge in Ruby:

* [Block Functions](https://mixandgo.com/learn/mastering-ruby-blocks-in-less-than-5-minutes)

* [Binding](https://medium.com/rubycademy/context-binding-in-ruby-fa118ea62269)

* [Enumerable](/writing) ([map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/))

[Next >>](/writing/2019/02/18/exploring-tracepoint-in-rubypart-twoevents/)

## What is TracePoint?

To start out with, what is TracePoint exactly? Well if we take a look into the Ruby documentation, it tells us:
> “A class that provides the functionality of [Kernel#set_trace_func](https://ruby-doc.org/core-2.6.1/Kernel.html#method-i-set_trace_func) in a nice Object-Oriented API.”
> - [https://ruby-doc.org/core-2.6.1/TracePoint.html](https://ruby-doc.org/core-2.6.1/TracePoint.html)

…ok then, what’s Kernel#set_trace_func then?
> “Establishes *proc* as the handler for tracing, or disables tracing if the parameter is nil.”
> - [https://ruby-doc.org/core-2.6.1/Kernel.html#method-i-set_trace_func](https://ruby-doc.org/core-2.6.1/Kernel.html#method-i-set_trace_func)

Now what exactly is tracing, and how is that useful to us as Ruby developers?

## **TracePoint Example**

Let’s start instead with some of the example code:

```ruby
trace = TracePoint.new(:raise) do |tp|
  p [tp.lineno, tp.event, tp.raised_exception]
end
**#=> #<TracePoint:disabled>**

trace.enable
**#=> false**

0 / 0
**#=> [5, :raise, #<ZeroDivisionError: divided by 0>]**
```

**Initializing**

In this specific example we’re starting by defining a new instance of TracePoint:

```ruby
TracePoint.new(:raise)
```

We’re giving that instance a specific type of event to watch out for, namely raise, which means exception events. We’ll get into the [rest of the events](https://ruby-doc.org/core-2.6.1/TracePoint.html#class-TracePoint-label-Events) in a moment, but know for now that this means we’re only looking at Ruby code that has to do with exceptions being raised.

**Disabled on Initialization**

Notice that TracePoint was disabled on creation:

```ruby
trace = TracePoint.new(:raise) do |tp|
  p [tp.lineno, tp.event, tp.raised_exception]
end
**#=> #<TracePoint:disabled>**
```

We can explicitly call enable to activate this TracePoint like the code right below it does:

```ruby
trace.enable
**#=> false**
```

This returns false if the trace was previously disabled, and true if it was previously enabled. We would have to call disable to turn it back off.

One trick to remember is that enable can take a block function for performing an isolated run of the TracePoint:

```ruby
trace.enable do
  # Code to be traced - TracePoint is active in here!
end

# TracePoint is off outside of the block
```

This can be handy for running a TracePoint in a more isolated section of your code. Remember though, you can’t access the trace itself inside of this block:

```ruby
trace.enable { p tp.lineno }
**#=> RuntimeError: access from outside**
```

**Block Function with Initialization**

In addition to that we’re giving the initializer a block function:

```ruby
trace = TracePoint.new(:raise) do |tp|
  p [tp.lineno, tp.event, tp.raised_exception]
end
**#=> #<TracePoint:disabled>**
```

This function will be run for every exception that’s hit in our program, yielding a value that’s named tp here. tp is the TracePoint instance itself, the equivalent of doing this in plain Ruby:

```ruby
def initialize(&block)
  yield(self)
end
```

That means that all the methods on TracePoint are available on that block variable.

**Available Methods on TracePoint**

These methods are all documented in TracePoint’s docs page, but for now let’s take a look at the example and what it’s doing. In this specific example we’re using lineno, event, and raised_exception.

We can see the result of this expression on the last line of the example:

```ruby
0 / 0
**#=> [5, :raise, #<ZeroDivisionError: divided by 0>]**
```

lineno stands for line number, the event is the type of event our trace received, and raised_exception is the exception that was raised.

Some of the other methods I’ve found particularly useful are:

* path — Path of the file that’s currently running

* return_value — Return value of the function (only available on return events)

* defined_class — What class we’re executing in

* method_id — The name of the method we’re currently in

* parameters — The arguments of the current method or block ([not available in exceptions](https://bugs.ruby-lang.org/issues/15568))

* binding — The full binding context where the trace activated

Now those last two, that’s where you get some interesting stuff, and we’ll be covering that shortly.

## **Binding**

First off, what’s a binding in Ruby? It’s the current context of what we’re running in. You might have seen binding.pry before to use Pry, or binding.irb in more recent versions of Ruby:
> Objects of class Binding encapsulate the execution context at some particular place in the code and retain this context for future use. The variables, methods, value of self, and possibly an iterator block that can be accessed in this context are all retained. [Binding](https://ruby-doc.org/core-2.6.1/Binding.html) objects can be created usingKernel#binding, **and are made available to the callback ofKernel#set_trace_func.**
> - [https://ruby-doc.org/core-2.6.1/Binding.html](https://ruby-doc.org/core-2.6.1/Binding.html)

That means [it applies to TracePoint as well](https://github.com/ruby/ruby/pull/2079). Now I won’t go too much into what bindings are, that’s the subject of another tutorial entirely. Know for now that these are a few of the interesting methods you might want to look into:

* eval — Evaluate code in the current binding

* local_variables — Names of the local variables

Give the binding documentation a quick read, as there’s a lot of fun you can have there.

## Parameters and Local Variables

If the name parameters sounds familiar, you may remember an article I’d written earlier on destructuring:
[**Destructuring in Ruby**
*What if I told you destructuring in method calls was possible in Ruby? Join me in my exploration in destructuring!*medium.com](/writing/2018/10/05/destructuring-in-ruby/)

Specifically this part of the code:

```ruby
-> a, *b, c: 1, **d, &fn {}.parameters
=> [[:req, :a], [:rest, :b], [:key, :c], [:keyrest, :d], [:block, :fn]]
```

Block functions and methods both know their parameters. Now if we know the *names* of the parameters, it’s not that far of a stretch to say we can get the *values* of them as well, especially considering they’re kind enough to let us play with the local binding.

**Extracting Arguments**

```ruby
def extract_arguments(trace)
  param_names = trace.parameters.map(&:last)
  param_names.map { |n| [n, trace.binding.eval(n.to_s)] }.to_h
end
```

Using the binding and binding.eval we can get the values of all of our arguments which can be incredibly useful for the sake of debugging.

The catch? This doesn’t work so well with raise type events for some reason. There’s currently a bug out against this behavior:
[**Misc #15568: TracePoint(:raise)#parameters raises RuntimeError - Ruby trunk - Ruby Issue Tracking…**
*Redmine*bugs.ruby-lang.org](https://bugs.ruby-lang.org/issues/15568)

**Extracting Local Variables**

We can somewhat cheat by getting the local variables instead:

```ruby
def extract_locals(trace)
  local_names = trace.binding.local_variables
  local_names.map { |n|
    [n, trace.binding.local_variable_get(n)]
  }.to_h
end
```

Not quite the same, but both are insanely useful for the sake of debugging. Knowing your way around binding can give you a lot of leverage to find out what your Ruby program is doing.

## Wrapping Up

TracePoint can be a dense subject, so we’re going to break this up into a few articles to make it easier to follow. Part One was meant to cover the example code given. The next parts are:

[**Part Two — Events](/writing/2019/02/18/exploring-tracepoint-in-rubypart-twoevents/)**

TracePoint can be triggered on multiple types of events. What are they and why might we want to use each one with TracePoint?

**Part Three — Aphyr’s Black Magic**

Covering an old classic Ruby post abusing set_trace_func to do bad things to Ruby. We’re going to modernize some of it to play with some of the more out there features of TracePoint.

**Part Four — Advent of TraceSpy**

TracePoint is powerful, but it can be hard to use. Trace Spy is a gem that was written to make it a bit easier to use in the wild with a fluent interface based on Pattern Matching from Qo.

We’ll explore writing fluent wrappers, documentation, and making meta-tools to help us do our jobs as developers more effectively.

**Part Five — Giving TraceSpy some Color**

Now that we have a fluent wrapper to use, how about some pretty output to make debugging even easier? Let’s take a look into providing utilities to see our local contexts more clearly and make debugging even easier!

We’re going to be going through some deeper parts of Ruby in these next few series in 2019, so buckle up because we’re going to have some fun.

[Next >>](/writing/2019/02/18/exploring-tracepoint-in-rubypart-twoevents/)
