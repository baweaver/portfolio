---
layout: "post"
title: "Exploring TracePoint in Ruby — Part Two — Events"
date: "2019-02-18"
categories: []
tags: ["ruby", "metaprogramming"]
description: "A comprehensive guide to every TracePoint event in Ruby — line, class, call, return, raise, block, thread, and fiber events with practical examples."
---

Now that we have a brief overview of the basics of TracePoint, let's take a look at all of the events we can monitor and what we might do with them.

This article is rated at a **difficulty of 3 out of 5**, and requires some prerequisite knowledge in Ruby:

* [Block Functions](https://mixandgo.com/learn/mastering-ruby-blocks-in-less-than-5-minutes)

* [Binding](https://medium.com/rubycademy/context-binding-in-ruby-fa118ea62269)

* [Enumerable](/writing) ([map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/))

* [Destructuring Arguments](/writing/2018/10/05/destructuring-in-ruby/)

[<< Previous](/writing/2019/02/08/exploring-tracepoint-in-rubypart-oneexample-code/) | Next >>

## The Helpers

We'll be using a few helper methods from last time, extract_arguments and extract_locals:

```ruby
def extract_arguments(trace)
  param_names = trace.parameters.map(&:last)
  param_names.map { |n| [n, trace.binding.eval(n.to_s)] }.to_h
end

def extract_locals(trace)
  local_names = trace.binding.local_variables
  local_names.map { |n|
    [n, trace.binding.local_variable_get(n)]
  }.to_h
end
```

This will allow us to see a bit more context for each event by allowing us to see the current local variables and current arguments in the context of the event.

If you happen to be using Pry, extracting locals may be incredibly noisy. To avoid this, use this version of the method instead:

```ruby
def extract_locals(trace)
  local_names = trace.binding.local_variables.reject { |v|
    v.to_s[0] == '_'
  }

  local_names.map { |n|
    value = trace.binding.local_variable_get(n)
    [n, value.is_a?(TracePoint) ? :trace_point : value]
  }.to_h
end
```

It will get rid of Pry variables starting with underscores, and avoid capturing the tracepoint we just defined.

I'll be refreshing my REPL after each event section to keep the output clear, and the above functions are defined in my ~/.pryrc so they're present when I start up Pry.

## The Events

TracePoint allows us to monitor specific events in Ruby's execution lifecycle. To start with, what are those events? [The official documentation is available](https://ruby-doc.org/core-2.6.1/TracePoint.html#class-TracePoint-label-Events), but let's define them in our own words for the sake of this tutorial.

We'll look at each in turn later in the article, but a short list is a good place to start:

* line: Each literal line of code in the program.
* class: A class or module is defined.
* end: A class or module definition ends.
* call: The invocation of a Ruby method.
* c_call: The invocation of a function defined in C, like puts and other core methods.
* return: The return of a Ruby method.
* c_return: The return of a function defined in C, much like c_call above.
* raise: An exception occurrence.
* b_call: When a block function is called.
* b_return: The return of a block function.
* thread_begin: When a thread starts.
* thread_end: When a thread ends, or rather joins.
* fiber_switch: When a fiber switches.

With that out of the way, shall we begin?

## Line Event

`:line`

This event triggers on every line of a Ruby program, so be careful with it or you're going to have quite the noisy trace!

We can start by defining a TracePoint that responds to a line event:

```ruby
line_event = TracePoint.new(:line) do |t|
  p [t.lineno, t.method_id, extract_locals(t)]
end
```

Using the fact that an instance of a TracePoint can call enable with a block for scoped execution, we can give that a try:

```ruby
line_event.enable do
  a = 1
  a + 2
end
```

```
[26, :__pry__, {:a => nil, :line_event => :trace_point}]
[27, :__pry__, {:a => 1, :line_event => :trace_point}]
=> 3
```

Now note that your line numbers are probably going to be different than mine depending on when and where you execute this code.

**Watching for a Variable**

What might be interesting here is that a isn't able to be extracted until the line event directly after it was assigned. Using this we might even be able to set watchers using TracePoint on a specific value either being present or being set:

```ruby
a_is_5_trace = TracePoint.new(:line) do |t|
  local_variables = extract_locals(t)

  next false unless local_variables[:a] == 5

  puts <<~MESSAGE
    Here's the context when 'a' became 5 on line #{t.lineno}:

    #{local_variables}
  MESSAGE
end

a_is_5_trace.enable do
  b = 3
  c = 4
  a = 5
  d = 6
end
```

```
Here's the context when 'a' became 5 on line 29:
{:b=>3, :c=>4, :a=>5, :d=>nil, :a_is_5_trace=>:trace_point}
=> 6
```

This can be really handy for finding when a particularly naughty code branch is setting variables it's not supposed to know about, especially when used in conjunction with some of the other TracePoint instance methods we learned about in the last article.

> **Note:** TracePoint *parameters* are not accessible in `:line` events. You can only get locals. On occasion you'll see errors about a certain type of method not being supported for a certain event. At the moment these are not documented well, but will be in the future.

Now there are several interesting things one could do by watching for variable changes, but that's outside the scope of this article. Let me know if you're interested in an extended part with some extra fun!

## Class Event

`:class`

This event triggers on the creation of a class.

Let's start by creating a TracePoint to watch for one:

```ruby
class_tracer = TracePoint.new(:class) do |t|
  puts <<~MESSAGE
    Class or Module '#{t.self}' was defined at
      `#{t.path}:#{t.lineno}`
  MESSAGE
end
```

Say we wanted to know where a class got defined, we can use the above trace to get a pretty good idea:

```ruby
class_tracer.enable do
  class FooBar
    def a; end
  end

  module BazBat
    def b; end
  end
end
```

```
Class or Module 'FooBar' was defined at
  `(pry):6`
Class or Module 'BazBat' was defined at
  `(pry):7`
```

Personally I find this mildly confusing that TracePoint#self happens to contain the class or module name instead of TracePoint#defined_class which instead returns nil.

This can be handy for when you want to find out where a particular class or module was defined without having to hunt through source code to get it.

## Class End Event

`:end`

This event triggers on the end of a class or module definition.

Let's start by creating a TracePoint:

```ruby
class_tracer = TracePoint.new(:end) do |t|
  puts <<~MESSAGE
    Class or Module '#{t.self}' was ended at
      `#{t.path}:#{t.lineno}`
  MESSAGE
end
```

and call it like so:

```ruby
class_tracer.enable do
  class FooBar
    def a; end
  end

  module BazBat
    def b; end
  end
end
```

```
Class or Module 'FooBar' was ended at
  `(pry):6`
Class or Module 'BazBat' was ended at
  `(pry):7`
```

Admittedly I can't think of a use for this event at the moment, but would be interested to find out from others what they've found.

## Call Event

`:call`

Call events trigger on any method call, and are one of the most useful events to monitor. They have access to arguments and a whole slew of other interesting data we can use for debugging.

Let's say we wanted to watch for calls of a method called testing:

```ruby
def testing(a, b, c)
  d = 5
  a + b + c + d
end

testing_call_trace = TracePoint.new(:call) do |t|
  # We only want to monitor our testing method
  next unless t.method_id == :testing

  p args: extract_arguments(t), locals: extract_locals(t)
end
```

and call it like so:

```ruby
testing_call_trace.enable do
  testing(1, 2, 3)
end
```

```
{:args=>{:a=>1, :b=>2, :c=>3}, :locals=>{:a=>1, :b=>2, :c=>3, :d=>nil}}
```

Being able to get ahold of arguments is really useful, so much so that one could potentially do very bad things with it. For now though, consider what one might be able to do by getting the arguments of this function:

```ruby
def deep_defaults(a: {b: [:c, :d]})
  a + b + c + d
end
```

It'll crash (for now), but that could be interesting…

> It should be noted the directly above is a really black magic experiment, the author would simply like you to enjoy a similar rabbit hole

## C Call Event

`:c_call`

The first, and fairest question here is what's the difference between this and a `:call` event? `:c_call` is an event that's in a C-extension or base Ruby code, like puts. Let's try and capture a puts with `:call` to see this in action:

```ruby
puts_call_trace = TracePoint.new(:call) do |t|
  if t.method_id == :puts
    p [t.lineno, t.method_id, extract_locals(t)]
  end
end

puts_call_trace.enable do
  puts "OHAI!"
end
```

```
OHAI!
=> nil
```

So we didn't see our event register, but if we instead use `:c_call`:

```ruby
puts_c_call_trace = TracePoint.new(:c_call) do |t|
  if t.method_id == :puts
    p [t.lineno, t.method_id, extract_locals(t)]
  end
end

puts_c_call_trace.enable do
  puts "OHAI!"
end
```

```
[49, :puts, {:puts_c_call_trace=>:trace_point, :puts_call_trace=>:trace_point, :e=>nil}]
[49, :puts, {:puts_c_call_trace=>:trace_point, :puts_call_trace=>:trace_point, :e=>nil}]
OHAI!
=> nil
```

Now if you wanted to just get both, it's of benefit to know that TracePoint.new takes multiple arguments:

```ruby
TracePoint.new(:call, :c_call)
```

So if you're trying to capture multiple event types you can specify them just like that. You can also give *no* arguments and have it send every event.

It should be noted that arguments can't be fetched from `:c_call` events.

## Return Event

`:return`

Return events come in a lot of handy when we want to see exactly where a specific value was returned. Much like its counterpart `:c_return`, it only gets part of the picture, so you'll frequently see both put into a TracePoint declaration.

It comes with an especially handy TracePoint method called return_value that's not accessible in non-return events.

Let's take a look at a way to catch nil returns:

```ruby
def nil_on_odd(n)
  d = 10
  n.odd? ? nil : n + d
end

nil_return_trace = TracePoint.new(:return) do |t|
  next unless t.return_value == nil

  p({
    locals: extract_locals(t),
    args: extract_arguments(t),
    ret_val: t.return_value
  })
end

nil_return_trace.enable do
  nil_on_odd(2)
  nil_on_odd(3)
end
```

```
{:locals=>{:n=>3, :d=>10}, :args=>{:n=>3}, :ret_val=>nil}
=> nil
```

We can get our local values and arguments too while we're at it, and perhaps even the method_id too if we needed it. Return events are particularly useful when you want to see the full context of a method at the point a value is returned.

## C Return Event

`:c_return`

Much like its sibling event, `:c_call`, `:c_return` will only activate on the return event of a c method returning. As such we won't get too much into it, except to say that your life will be substantially easier by specifying both the return event types when creating a new TracePoint:

```ruby
trace_returns = TracePoint.new(:return, :c_return) { ... }
```

## Raise Event

`:raise`

A `:raise` event is one triggered on an exception, and will allow us to see the full context around an exception happening. This includes stuffing a binding.pry or binding.irb in there too. You could probably even emulate parts of pry-rescue with it.

Let's take a look at a quick example using that:

```ruby
def raise_on_odd(n)
  d = 20
  raise 'a ruckus' if n.odd?
  n + d
end

exception_trace = TracePoint.new(:raise) do |t|
  p locals: extract_locals(t), exception: t.raised_exception
end

exception_trace.enable do
  raise_on_odd(2)
  raise_on_odd(3)
end
```

```
{:locals=>{:n=>3, :d=>20}, :exception=>#<RuntimeError: a ruckus>}
RuntimeError: a ruckus
from (pry):81:in `raise_on_odd'
```

It should be noted that arguments are not available in this context, so we would have to rely on locals to see what might be going on in this area.

## Block Call Event

`:b_call`

A `:b_call` event will trigger whenever a block is called. Now what precisely qualifies as a block? Let's take a look:

```ruby
def maps(list, &fn)
  list.reduce([]) { |a, v| a << yield(v) }
end

block_trace = TracePoint.new(:b_call) do |t|
  p({
    line: t.lineno,
    method_name: t.method_id,
    locals: extract_locals(t),
    args: extract_arguments(t)
  })
end

block_trace.enable do
  maps([1,2,3], &:even?)
end
```

```
{
  line: 12,
  method_name: :__pry__,
  locals: { block_trace: :trace_point },
  args: {},
}

{
  line: 2,
  method_name: :maps,
  locals: {
    a: [],
    v: 1,
    list: [1, 2, 3],
    fn: #<Proc:X(&:even?)>
  },
  args: { a: [], v: 1 },
}

{
  line: 2,
  method_name: :maps,
  locals: {
    a: [false],
    v: 2,
    list: [1, 2, 3],
    fn: #<Proc:X(&:even?)>
  },
  args: { a: [false], v: 2 },
}

{
  line: 2,
  method_name: :maps,
  locals: {
    a: [false, true],
    v: 3,
    list: [1, 2, 3],
    fn: #<Proc:X(&:even?)>
  },
  args: { a: [false, true], v: 3 },
}
```

Remember that reduce call up above in our maps function? That counts as a block too, meaning we just got a nice little look into each step of map implemented in reduce while we were at it!

It's imperative to remember that when TracePoint captures something, it really does mean everything, which is why we try and limit its scope with early returns and using the block form of enable.

## Block Return Event

`:b_return`

Like its counterpart return events, `:b_return` captures the return event of a block. Let's take a look back at our map example, except this time we'll make it into flat_map instead just for the novelty of it. We'll also be using cleaned up pp output instead as this output is getting a bit hairy otherwise:

```ruby
def flat_maps(list, &fn)
  list.reduce([]) { |a, v| a.push *yield(v) }
end

block_trace = TracePoint.new(:b_return) do |t|
  pp({
    line: t.lineno,
    method_name: t.method_id,
    locals: extract_locals(t),
    args: extract_arguments(t),
    ret_value: t.return_value
  })
end

block_trace.enable do
  flat_maps([1,2]) { |v| [v - 1, v + 1] }
end
```

```
{
  line: 14,
  method_name: :__pry__,
  locals: {v: 1, block_trace: :trace_point},
  args: {v: 1},
  ret_value: [0, 2]
}

{
  line: 2,
  method_name: :flat_maps,
  locals: {
    a: [0, 2],
    v: 1,
    list: [1, 2],
    fn: #<Proc:0x00007fe70425f510@(pry):14>
  },
  args: {a: [0, 2], v: 1},
  ret_value: [0, 2]
}

{
  line: 14,
  method_name: :__pry__,
  locals: {v: 2, block_trace: :trace_point},
  args: {v: 2},
  ret_value: [1, 3]
}

{
  line: 2,
  method_name: :flat_maps,
  locals: {
    a: [0, 2, 1, 3],
    v: 2,
    list: [1, 2],
    fn: #<Proc:0x00007fe70425f510@(pry):14>
  },
  args: {a: [0, 2, 1, 3], v: 2},
  ret_value: [0, 2, 1, 3]
}

{
  line: 15,
  method_name: :__pry__,
  locals: {block_trace: :trace_point},
  args: {},
  ret_value: [0, 2, 1, 3]
}

=> [0, 2, 1, 3]
```

This is especially useful if you have a particularly hairy function block you need to debug step by step to see what it's doing, especially if it's a larger reduce function you want to see inside of.

## Thread Begin and End Event

`:thread_begin` / `:thread_end`

These events trigger on the beginning and ending of a thread. As I don't do an incredible amount with threads this won't be a very detailed section. They don't appear to have access to a local binding or most of the other things we've seen in above sections except for basic location information.

We'll save this section for later, as I have a feeling it'll require a good amount of research on my part to figure out. Suggestions and ideas welcome!

## Fiber Switch Event

`:fiber_switch`

As with threads, we'll save this for a later section about parallel tracing.

## Wrapping Up

TracePoint can be a dense subject, so we're going to break this up into a few articles to make it easier to follow. Part Two was meant to cover each event TracePoint can watch. The next parts are:

**Part Three — Aphyr's Black Magic**

Covering an old classic Ruby post abusing set_trace_func to do bad things to Ruby. We're going to modernize some of it to play with some of the more out there features of TracePoint.

**Part Four — Advent of TraceSpy**

TracePoint is powerful, but it can be hard to use. Trace Spy is a gem that was written to make it a bit easier to use in the wild with a fluent interface based on Pattern Matching from Qo.

We'll explore writing fluent wrappers, documentation, and making meta-tools to help us do our jobs as developers more effectively.

**Part Five — Giving TraceSpy some Color**

Now that we have a fluent wrapper to use, how about some pretty output to make debugging even easier? Let's take a look into providing utilities to see our local contexts more clearly and make debugging even easier!

We're going to be going through some deeper parts of Ruby in these next few series in 2019, so buckle up because we're going to have some fun.

[<< Previous](/writing/2019/02/08/exploring-tracepoint-in-rubypart-oneexample-code/) | Next >>
