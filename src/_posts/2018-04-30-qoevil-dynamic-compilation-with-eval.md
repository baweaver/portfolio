---
layout: "post"
title: "Qo::Evil — Dynamic Compilation with eval"
date: "2018-04-30"
categories: []
tags: []
description: ""
---

One of the biggest arguments against Qo, and rightly so, was that most pattern matching is done in tight loops that get run over thousands of items at a time.

Very clearly a 5 to 10 times slowdown is unacceptable for these types of tasks, expressiveness aside.

Given that, I set out to find a way to make Qo perform at closer parity with vanilla Ruby. As one can imagine, and given the dynamic nature of Qo, the most I could shave off was maybe 2–3 times more optimistically.

This raised the question: If a pattern match is effectively a static condition defined a bit more nicely, what’s to stop us from reducing it back to that?

Enter Qo::Evil, and some of the true black magics of Ruby.
> It should be noted that at the time of writing, this is still an active experiment on the “evil” branch of Qo

## Where we began

Before we start, we should take a look at where Qo was before the Evil project:
[**baweaver/qo**
*Qo Performance Benchmarks](https://github.com/baweaver/qo/blob/10d11ebd1cb67ab7a4a81d1bda6a2ea7c4f1fd23/performance_report.txt)*

The pertinent numbers are:

    Running on Qo v0.3.0 at rev 77eb2544c41b33361a561178b145d33fa2409bde
     - Ruby ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-darwin17]

    Array * Array - Literal
      Vanilla:  8805260.8 i/s
      Qo.and:   987041.0 i/s - 8.92x  slower

    Array * Array - Index pattern match
     Vanilla:   550096.4 i/s
      Qo.and:   226391.4 i/s - 2.43x  slower

    Array * Object - Predicate match
      Vanilla:  2147916.4 i/s
      Qo.and:   303118.1 i/s - 7.09x  slower

    Array * Array - Select index pattern match
      Vanilla:   141336.5 i/s
      Qo.and:    73799.3 i/s - 1.92x  slower

    Hash * Hash - Hash intersection
      Vanilla:   392298.2 i/s
      Qo.and:    48213.1 i/s - 8.14x  slower

    Hash * Object - Property match
      Vanilla:   361140.4 i/s
      Qo.and:    46667.1 i/s - 7.74x  slower

The question is, can we make these numbers the same? Let’s find out.

## What does a Pattern Match reduce to?

Essentially a pattern match is comprised of an and condition applied to several queries. Consider:

    Qo.match(person) do |m|
      m.when(name: /Foo/, age: 20..30) { ... }
      m.else { ... }
    end

We’re matching against a person where their name contains Foo and their age is between 20 and 30. Can that be expressed as an if conditional? Sure:

    if /Foo/.match?(person.name) && (20..30).include?(person.age)
      ...
    else
      ...
    end

Now some may fairly say why not just use the if conditional here. They’re right. In many cases you can, but in ways it lacks some of the succinctness of a pattern match, and in cases where you have a lot of conditions to watch for it can get to be a mess very quickly.

Though remember, if a pattern match can be expressed in terms of if conditions, is there a way to reduce it as such?

The answer is yes, but there’s a price to pay, and is the start of the Evil project: We need eval.

## The Case for Eval

Record screech, everyone stops, turns, and stares. Did he just say eval ? There’s a stunned silence in the room, followed shortly by the angry clacking of a thousand keyboards sent to met justice unto the heathen. Madness!

Truth be told, it is a bit mad, but that’s what makes it fun. eval is used to evaluate code, meaning we’re simply dealing with strings. Transforming one syntax to another becomes a walk in the park, and a matter of specifying how to get from A to B instead of how to fine tune a 3–4 layer deep loop.

We take the need to run a multi-layer loop and turn it into a single boolean expression, decreasing the run time by an order of magnitude or more. The only caveat is it has to be “compiled” the first run.

## Effective Syntax

The question is how exactly do we take a match syntax and convert it into such a thing.

Let’s open with remembering that a match remembers every one of the “matchers” furnished to it in instance variables:

    Qo.and(name: /Foo/, age: 20..30).call(person)

Is effectively saying:

    /Foo/.match?(person.public_send(:name)) &&
    (20..30).include?(person.public_send(:age))

Qo would use public_send to retrieve these values, but that’s also quite a bit slower than just calling the method on the object. We’ll want to remember that.

Normally it would be hard to transform a doubly-sided dynamic construct but we already know what both sides look like on this match. They’re the matcher (Qo.and) and target (person) respectively. That gives us a lot to work with.

For now we know we’re matching a Hash (keyword matchers) with an Object (person) which narrows down the set of steps needed. Let’s go through them.

## Public Send and Security

The first consideration is how can we mitigate the need for public_send without opening ourselves to a massive security risk. Consider:

    eval("target.#{method}")

What happens if your input source is untrusted and sends something like this:

    method = 'nil?; DirTools.rm_rf("/")'

It certainly doesn’t make for a good day now does it. What can we do to mitigate the issue? A good first step might be to sanitize our input:

    method.to_s.gsub(/[^a-zA-Z0-9_?!]/, '')

Anything that doesn’t match a method signature is ripped, though if we have the target we could also test against it as well:

    target.respond_to?(method)

The danger with eval is you always need to trust input going into it. That includes symbols, considering they could also do this:

    :'nil?; `rm -rf /`'

Never trust input from the outside world around eval.

## Unfolding a Loop

Now for a matcher we know we have either array_matchers or keyword_matchers to deal with. In the above case we have keywords:

    Qo.and(name: /Foo/, age: 20..30).call(person)

Under the hood Qo would loop through all the matchers and public send. Why not loop and transform them into the string equivalents we saw above?

    match_strings = keyword_matchers.map { |key, matcher|
      case matcher
      when Regexp then "#{matcher.inspect}.match?(target.#{key})"
      when Range then "(#{matcher.inspect}).include?(target.#{key})"
      else ...
      end
    }

Granted this assumes we’ve sanitized the keys already. We’re effectively taking the string variant of what an optimized bit of Ruby would look like and interpolating the matcher and the key we call on the target. This is mildly different for other type matches, but it all translates to roughly the same case block.

After we get those transformations, it becomes a matter of combining them into a query. Join has just the thing:

    match_query = match_strings.join(' && ')

## Uncoercibles and the Lazy Route

That seems a bit tedious though, especially if a class we use === on doesn’t have a clean inspect representation we can match against. That’s where binding comes in real handy.

Bindings give us the ability to inject state into a local binding and evaluate code in its context. In simpler terms, we can set variables that are accessible when we eval later.

All we need to do is in the else statement set a binding variable instead. For now we can stash those in a hash to play with later:

    variables = {}

    ...

    if uncoercible
      variables[name] = matcher
      "#{name} === target.#{key}"
    end

Question is, where does that name come from? Well the method I’d used was to just make an Enumerator full of letters to pull from:

    letters = ('a'..'zzz').to_enum

    ...

    name = "_qo_evil_#{letters.next}"

So we just keep grabbing a new suffix and prefix it with something recognizable in case we get a crash later.

After we finish mapping the strings we can have some fun with the local binding:

    bind = binding

    variables.each { |name, var|
      bind.local_variable_set(name.to_sym, var)
    }

    bind.eval(match_query)

…but then that just makes for a bigger mess as we’re not storing the compiled version anywhere. This just keeps running the entire rewrite every call which is even worse!

Let’s fix that.

## Proc-sy caller

Let’s take a look at the call method from the evil branch:

    def call(target)
      return [@_proc](http://twitter.com/_proc).call(target) if [@_proc](http://twitter.com/_proc)

      bind = binding

      compiled_matchers, variables = compile(target)
      match_query = merge_compilation(compiled_matchers)

      variables.each { |name, var|
        bind.local_variable_set(name.to_sym, var)
      }

      @_proc = bind.eval(%~
        Proc.new { |target| #{match_query} }
      ~)

      @_proc.call(target)
    end

The only real difference here is that there are multiple ways to combine matchers (and, or, not) so that got accounted for in merge_compilation.

What this is doing is dynamically generating a proc to call afterwards on the given target. It relies on any of the variables we set on the binding and the match query we generated.

This makes it slower on the first call, but after that? Well see for yourself.

## Qo Evil Performance

So does all of this actually pay off?

<iframe src="https://medium.com/media/411d8299af0d45bccd9d043b42a51978" frameborder=0></iframe>

Consistently around 10x faster than Qo across large arrays, and I think there are still ways to further optimize this to get even closer.

Is it evil? Certainly. Is it effective? Well I believe the numbers speak for themselves in this case.

If there’s a way to come close to vanilla Ruby speeds and gain the level of expressiveness a pattern match can provide perhaps we need a bit more black magic.

Currently you can find the branch and the matcher compiler here:
[**baweaver/qo**
*Evil Compiled Matchers*github.com](https://github.com/baweaver/qo/blob/evil/lib/qo/evil/matcher.rb)

Fair warning, it’s a bit messy while I experiment.

## Wrapping Up

Currently this is one big thought experiment, and I’m still weighing the tradeoffs of this technique.

The effectiveness in speed increase is definitely interesting. I’d like to see how this can be leveraged to give us more powerful tools for working with larger data sets in Ruby while giving us a more composable and expressive way of defining queries and transformations against them.

If anyone reading this has C experience and knows of a more effective way to make something like this into an extension, shoot me a message, I’d love to explore a bit more.

Enjoy!
