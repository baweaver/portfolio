---
layout: "post"
title: "Reducing Enumerable — No-Op and Boolean"
series: "reducing-enumerable"
date: "2017-10-16"
categories: []
tags: ["ruby", "functional"]
description: "Continuing the reduce series with no-op and boolean Enumerable functions implemented in terms of reduce."
---

## Recap

So in the previous post, we took a look at a few basic Enumerable functions made in terms of reduce
[**Reducing Enumerable — The Basics**
*One of the lesser understood functions in Enumerable for many Rubyists is reduce . It's just the thing we can use to…*medium.com](/writing/2017/10/16/reducing-enumerable-the-basics/)

For reference, those were:

**Map**

```ruby
def map(list, &fn)
  list.reduce([]) { |a, i| a.push(fn[i]) }
end

map([1,2,3]) { |i| i * 2 }
# => [2, 4, 6]
```

**Select**

```ruby
def select(list, &fn)
  list.reduce([]) { |a, i| fn[i] ? a.push(i) : a }
end

select([1,2,3]) { |i| i > 1 }
# => [2, 3]
```

**Find**

```ruby
def find(list, &fn)
  list.reduce(nil) { |_, i| break i if fn[i] }
end

find([1,2,3]) { |i| i == 2 }
# => 2

find([1,2,3]) { |i| i == 4 }
# => nil
```

In these cases we've been reducing onto arrays or just flat out ignoring the reducing value.

One should pay special attention to the fact that we're ignoring the accumulator, because this yields a very interesting observation about the behavior of reduce.

## What are we covering this time?

This round will cover no-op and boolean functions of Enumerable.

## No-Op Functions

Find only happened to do something with no accumulator because of break, but reduce can be used for no-op functions as well, like each:

```ruby
def each(list, &fn)
  list.reduce(nil) { |_, i| fn[i] }
  list
end
```

While not technically an Enumerable function, it's the base of everything else under it. That said, our implementation doesn't satisfy that constraint.

## Boolean Functions

One of the fun things you can do is reduce into a boolean or even bitwise operation.

Functions that do this are ones like: any?, all?, none?, one?, include?, member?

Let's take a look at a few of them:

**any?**

```ruby
def any?(list, &fn)
  list.reduce(false) { |_, i|
    break true if fn[i]
    false
  }
end

any?([1,2,3]) { |i| i > 5 }
# => false

any?([1,2,3]) { |i| i > 1 }
# => true
```

The caveat here is that break does not play nicely with ternaries, and `if x then` just doesn't feel quite right.

Like find, any? will break early if it finds something.

Granted this could be simplified with a `!!` to a one-liner, but I'm going to err on the side of verbosity for these posts:

```ruby
def any?(list, &fn)
  !!list.reduce(nil) { |_, i| break true if fn[i] }
end
```

**all?**

```ruby
def all?(list, &fn)
  list.reduce(true) { |a, i| a && fn[i] }
end

all?([1,2,3]) { |i| i > 0 }
# => true

all?([1,2,3]) { |i| i > 2 }
# => false
```

all? introduces us to folding using `&&` and a boolean value. The idea here is to see if all elements match the predicate function. That said, this first implementation doesn't quite get there. Can you see what's wrong with it?

What happens if any one of the elements is false? It should probably break out early like our other functions:

```ruby
def all?(list, &fn)
  list.reduce(true) { |a, i|
    break false unless fn[i]
    true
  }
end

all?([1,2,3]) { |i| i > 0 }
# => true

all?([1,2,3]) { |i| i > 2 }
# => false
```

**none?**

none? is basically the inverse of any?. If we really wanted to we could define it in terms of any?:

```ruby
def none?(list, &fn)
  !any?(list, &fn)
end

none?([1,2,3]) { |i| i > 2 }
# => false

none?([1,2,3]) { |i| i > 5 }
# => true
```

Ideally we should reuse what we already have, but the point of this series is to go through how you'd implement things in terms of reduce:

```ruby
def none?(list, &fn)
  list.reduce(false) { |_, i|
    break false if fn[i]
    true
  }
end

none?([1,2,3]) { |i| i > 2 }
# => false

none?([1,2,3]) { |i| i > 5 }
# => true
```

Basically you just end up with the conditions switches and voilá!

**one?**

```ruby
def one?(list, &fn)
  list.reduce(false) { |a, i|
    if fn[i]
      break false if a
      true
    else
      a
    end
  }
end

one?([1,2,3]) { |i| i == 2 }
# => true

one?([1,2,3]) { |i| i > 1 }
# => false

one?([1,2,3]) { |i| i > 5 }
# => false
```

one? has the added bonus of having to make sure we get, well, one match. Now we not only have to check if the functional predicate was true, but also that it wasn't true before now.

Because of the way this works, we can't break out in all cases, only those in which we had more than one occurrence. Now we could have reduced onto an integer and ran a count of occurrences, but we already have a boolean status we may as well use!

**include? and member?**

```ruby
def include?(list, item)
  list.reduce(false) { |a, i|
    break true if i == item
    false
  }
end

include?([1,2,3], 1)
# => true

include?([1,2,3], 5)
# => false
```

include? and member? are the same, so we'll just group them both under this branch.

Much like find, it only has to find one item or return false otherwise.

## Wrapping Up

Next time we're going to start covering functions deal with Integer state like min and max and sorting.
