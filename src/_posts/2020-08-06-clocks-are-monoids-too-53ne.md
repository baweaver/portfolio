---
layout: "post"
title: "Clocks are Monoids Too!"
date: "2020-08-06"
categories: ["functional", "ruby"]
tags: ["functional", "ruby", "monoid", "endofunctors"]
description: "Along the theme of exploring FP concepts and interesting ideas we're taking another look at monoids in a specific sense: with clocks!"
---

![Playing with Time](/images/posts/2020-08-06-clocks-are-monoids-too-53ne/img-e40a6d6f.png)

In the spirit of watching a few challenging videos I happened upon another Monoid / Monad tutorial which mentioned that clocks were Monoids too! Me being me, this seemed a delightful topic to share on, so here we are.

*Disclaimer*: This article will veer a bit more advanced, especially if you haven't read the article mentioned in the next section.

## Wait wait, what's a Monoid?

If you want a more general overview you might want to give this previous article of mine a read:

/writing/2019/11/01/deeper-magics-monoids-in-ruby-and-rails-324o/

It will cover them in a more general sense, while this article will cover them in a more specific sense but will still cover the general rules and why that's so amusing.

### Ok, Fast Version Then?

So a Monoid is something which follows three rules:

1. Join (Closure) - A way to combine two items to get back an item of the same type
2. Empty (Identity) - An empty item, that when joined with any other item of the same type, returns that same item.
3. Order (Associativity) - As long as the items retain their order you can group them however you want and get the same result back.

This sounds a bit complicated, but has an implementation you're already very familiar with: summing an array.

This gives us all three of those rules:

```ruby
# Join (Closure) - A way to combine items
1 + 1

# Empty (Identity) - An empty item, when joined, returns the same item
1 + 0 == 1

# Order (Associativity) - Retain the order and you can group freely
1 + 2 + 3 == 1 + (2 + 3) == (1 + 2) + 3
```

As it turns out a lot of things happen to follow this nifty little pattern, and one of those nifty little things are clocks.

## Our Clock

We'll assume for the duration of this post that our clock is a simple 12 hour clock. We won't worry about dates or anything beyond that.

To do that we'll start with a simple class we'll build on:

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end
end
```

We'll put a modulo 12 in there just to make sure someone's not being naughty and making us use 24H clocks.

### Joining Clocks

Now here's the interesting thing about joining functions: they don't have to necessarily be an operator. They can be an entire function.

So to join clocks we start with an interesting predicament: what happens when the clock crosses twelve?

It goes right back around.

In programming we can implement that behavior using modulo to ensure that once we hit a limit we start right back over again. In this case modulo 12:

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end

  def join(other_clock)
    new_time = (time + other_clock.time) % 12
    Clock.new(new_time)
  end
end
```

Trying this out we might get something like this:

```ruby
clock_one = Clock.new(12)
clock_two = Clock.new(5)
clock_three = Clock.new(6)

clock_one.join(clock_two)
# => #<Clock:0x00007f88faa8d998 @time=5>

clock_two.join(clock_three)
# => #<Clock:0x00007f88fa11b9a0 @time=11>
```

Really it's just addition with some extra steps, the only difference is we now have a clock type we need to return as well. Have to make sure we're consistent.

#### The Rules

So do we get a new clock if we smash clocks together?:

```ruby
clock_one = Clock.new(12)
clock_two = Clock.new(5)

clock_one.join(clock_two).is_a?(Clock)
# => true
```

Yep! One down.

#### Extra Steps

Noted that we _could_ rely on the initializer doing the modulo here, but for the sake of the exercise we want to be a bit explicit about this. You could also make `join` into `+` but that's an exercise I'll leave up to the reader.

### An Empty Clock

So if it's just addition with some extra steps, that means that 0 should still work right? Right!

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end

  def join(other_clock)
    new_time = (time + other_clock.time) % 12
    Clock.new(new_time)
  end

  def self.empty
    Clock.new(0)
  end
end
```

If we were to try that out we might get something like this:

```ruby
clock_two = Clock.new(5)

clock_two.join(Clock.empty)
# => #<Clock:0x00007f88fa1242a8 @time=5>
```

#### The Rules

Does that hold up to our rules?:

```ruby
clock_two = Clock.new(5)

clock_two.join(Clock.empty) == clock_two
# => false
```

Oi! That's not right. Well, it is if we define equality based on the time like so:

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end

  def join(other_clock)
    new_time = (time + other_clock.time) % 12
    Clock.new(new_time)
  end

  def ==(other)
    time == other.time
  end

  def self.empty
    Clock.new(0)
  end
end
```

Now if we try it:

```ruby
clock_two = Clock.new(5)

clock_two.join(Clock.empty) == clock_two
# => true
```

...much better.

### Associativity

Now that we have those two down, what happens if we start adding together multiple clocks? Our class is already ready to go here:

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end

  def join(other_clock)
    new_time = (time + other_clock.time) % 12
    Clock.new(new_time)
  end

  def ==(other)
    time == other.time
  end

  def self.empty
    Clock.new(0)
  end
end
```

All we need to do is test it.

#### The Rules

Remember, `a + b + c == a + (b + c) == (a + b) + c`.

If we're being exceptionally cheeky we can just name our clocks along the same lines:

```ruby
a = Clock.new(12)
b = Clock.new(5)
c = Clock.new(6)
```

...and speaking of cheeky, I rather don't want to write that with join so let's add that plus from above to the class as an alias for join:

```ruby
class Clock
  attr_reader :time

  def initialize(current_time)
    @time = current_time % 12
  end

  def join(other_clock)
    new_time = (time + other_clock.time) % 12
    Clock.new(new_time)
  end

  alias_method :+, :join

  def ==(other)
    time == other.time
  end

  def self.empty
    Clock.new(0)
  end
end
```

So if we were to try that now we'd get:

```ruby
a = Clock.new(12)
b = Clock.new(5)
c = Clock.new(6)

a + b + c == a + (b + c)
# => true

a + (b + c) == (a + b) + c
# => true
```

Aha! That means we've gotten all our rules. Great, why do we care?

### What does it reduce to?

Well now that means we can do all types of fun things with items like reduce:

```ruby
[a, b, c].reduce(Clock.empty) { |clock, next_clock| clock + next_clock }
# => #<Clock:0x00007f88f86112b8 @time=11>

# or condense it:
[a, b, c].reduce(Clock.empty, :+)
# => #<Clock:0x00007f88f8640090 @time=11>

# one more time!
[a, b, c].sum(Clock.empty)
```

Monoids come with some fun little behaviors, because Monoid means "Like One" if you squint hard enough and ignore exact etymology a bit. Really I've taken to calling them reducible, foldable, or any other number of things.

They're nifty, and once you see them you see them everywhere. Strings, Hashes, Arrays, Integers, Floats, ActiveRecord Queries, and a whole lot more.

## Wrapping Up

This was a bit more of an advanced writeup for funsies as I saw something amusing in a video and wanted to share some of my ramblings for the day. Consider it a fun little thought experiment, and thank you for joining me on this ride.
