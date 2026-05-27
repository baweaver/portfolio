---
layout: "post"
title: "Ruby 3.1 – Shorthand Hash Syntax – First Impressions"
date: "2021-09-12"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "It's the time of year again, and with it comes a bundle of new Ruby 3.1 features getting approved and..."
---

It's the time of year again, and with it comes a bundle of new Ruby 3.1 features getting approved and merged ahead of the December release.

This series will be covering a few of the interesting ones I see going across the bug tracker. Have one you think is interesting? Send it my way on Twitter @keystonelemur or comment here.

## Shorthand Hash Syntax - First Impressions

Now this, this is something I've wanted for a very long time. Shorthand Hash Syntax, also known as Punning in Javascript, is an incredibly useful feature that allows you to omit values where the variable name is the same as the key:

```ruby
a = 1
b = 2

{ a:, b: }
# => { a: 1, b: 2 }
```

In Javascript this would like like so:

```js
const a = 1
const b = 2

{ a, b }
```

So you can see some of the resemblance between the two.

### Commits and Tracker

You can find the [relevant diff here](https://github.com/ruby/ruby/commit/c60dbcd1c55cd77a24c41d5e1a9555622be8b2b8#diff-f43e8aa2106104930c9b21126ca95cd572e25630b0e5d0bffe720a21da34771aR2182) and the [bugtracker issue here](https://bugs.ruby-lang.org/issues/14579).

## Exploring the Testcases

Let's take a look into the specs from that diff (slightly abbreviated):

```ruby
def test_value_omission
  x = 1
  y = 2

  assert_equal({x: 1, y: 2}, {x:, y:})
  assert_equal({one: 1, two: 2}, {one:, two:})
end

private def one = 1
private def two = 2
```

Now as mentioned before, this allows value omission as specified in the first assertion:

```ruby
x = 1
y = 2

assert_equal({x: 1, y: 2}, {x:, y:})
```

This is what I would expect the feature to do, and already opens up a lot of potential which I'll get into in a moment, but there's something else here in the second:

```ruby
assert_equal({one: 1, two: 2}, {one:, two:})

# ...

private def one = 1
private def two = 2
```

...it's also working on methods, which opens up a whole new realm of interesting potential. I'll be breaking these into two sections to address what I think the implications of each are.

## Implications of Punning

Let's start with general implications, as I believe those alone are interesting enough to write on. 

### Pattern Matching

Consider with me pattern matching:

```ruby
case { x: 1, y: 2 }
# I do still wish `y` was captured here without right-hand assignment
in x:, y: ..10 => y then { x:, y: y + 1 }
# ...
end
```

This allows us to abbreviate the idea of leaving one value unchanged, and working with another value explicitly. In another case with a JSON response we might want to extract a few fields while changing one:

```ruby
case response
in code: 200, body: { messages:, people: }
  { messages:, people: people.map { Person.new(_1) } }
in code: 400.., body: { error:, stacktrace: }
  { error:, stacktrace: stacktrace.first(5) }
# ...
end
```

It allows us to be more succinct in what we're simply extracting and what we're transforming.

> **Note:** I have not tried combining this with regular `Hash` syntax, but I assume this will work given the `parse.y` code. More experimentation needed.

### Keyword Arguments

Keyword arguments in general are a huge value-add to Ruby for understandability and errors:

```ruby
# (A tinge contrived, yes)
def json_logger(level:, message:, limit: nil)
  new_message = limit ? message.first(limit) : message
  Logger.log({ level: level, message: new_message }.to_json)
end
```

With one argument that's not too bad, but the biggest annoyance of keyword arguments is constantly doing this:

```ruby
some_method(a: a, b: b, c: c, d: d + 4)
```

It feels repetitive and doesn't add extra value. Punning in JS elided this information into arguments which should be forwarded without transformation, and Ruby shorthand hash syntax does the same. The benefits of keyword arguments without all of the extra code:

```ruby
some_method(a:, b:, c:, d: d + 4)
```

Now we can quickly see only `d` is being modified, allowing us to more clearly see the intent of the code, while also getting all of the benefits of keyword arguments around name checks, value checks, and more easily understood methods.

I see this being the highest value add.

## Implications of Including Methods

This one is a bit more unusual, but I like the idea.

### Configuration Hashes

There are a lot of cases where I have to assemble larger hashes of configuration. By putting parts of it into methods I've made it easier to manage:

```ruby
def configuration
  { a:, b:, c: }
end

private def a = {}
private def b = {}
private def c = {}
```

Those could be things like say logger configs, AWS keys, library configuration, and very interestingly (and I don't know if this would work) optional configuration cascades:

```ruby
def configuration
  {
    **({ logger:, stack_limit:, tracing: } if logging.enabled?),
    **({ shards:, rw:, clusters: } if db.sharded?),
    # ...
  }
end
```

Of course those are theoretical and I would need to spend substantial time with this feature after nightly builds are out to be sure on this, but if it does work it opens the door for some very interesting cascading configuration styles in the future.

## Wrap Up

This is a first impressions article on the shorthand hash syntax, and I expect as I have time to play with it I'll come up with some new ideas. Until then, I'll be watching the bug tracker for fun new features coming up soon.
