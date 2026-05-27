---
layout: "post"
title: "Abusing Hash Constructors"
date: "2017-10-16"
categories: []
tags: ["ruby", "metaprogramming"]
description: "Exploring the lesser-known features of Hash constructors in Ruby, from default values to block-based initialization."
---

Hash constructors are one of those features a lot of Rubyists never really think of. Normally you just initialize a hash as `{}` and done. Well that's just no fun, so let's take a look at some of the things you can do with Hash constructors!

## Argument Constructors

The simplest of constructors just takes a single argument:

```ruby
Hash.new(0)
```

All this does is ensure that any new key will be initialized with a value of 0. So what's this good for? How about a basic word count:

```ruby
'foo bar baz foo'
  .split
  .each_with_object(Hash.new(0)) { |w, h| h[w] += 1 }

# => {"foo"=>2, "bar"=>1, "baz"=>1}
```

> For those of you who haven't read my other posts, I have a slight thing for reduce. That being said, each_with_object is nicer in these cases because it implies the return value without having to be explicit about it. It also reverses the arguments from reduce, so be careful!

Note though you're going to have a really bad day if you try this with an array constructor:

```ruby
'foo bar baz foo'
  .split
  .each_with_object(Hash.new([])) { |w, h| h[w[0]] << w }
# => {}
# Wait, what?

array = []

'foo bar baz foo'
  .split
  .each_with_object(Hash.new(array)) { |w, h| h[w[0]] << w }
# => {}

array
# => ["foo", "bar", "baz", "foo"]
```

That array is the same object, so it's not going to work like that.

## Block Constructors

Maybe we want a bit more power, or maybe we found out that arrays aren't pass-by-value. In any case, let's take a look at the block constructor and a few scenarios it can be used in.

**Array Block**

So that array issue from last section is kinda annoying. We just wanted to get words grouped by their first letter! Well that's what block constructors are for, it's a function that gets called on each non-existant key which returns us a magical new value:

```ruby
Hash.new { |hash, key| hash[key] = [] }
```

Now we get a fresh array for every key:

```ruby
'foo bar baz foo'
  .split
  .each_with_object(array_hash) { |w, h| h[w[0]] << w }

# => {"f"=>["foo", "foo"], "b"=>["bar", "baz"]}
```

**Functional Block**

Maybe we want a function hash?

```ruby
factorials = Hash.new { |hash, key|
  hash[key] = (1..key).reduce(:*)
}
# => {}

factorials[5]
# => 120

factorials
# => {5=>120}
```

But our comp-sci professor taught us the recursive method! Let's use it!

```ruby
factorials = Hash.new { |hash, key|
  hash[key] = [0, 1].include?(key) ? key : hash[key - 1] * key
}
# => {}

factorials[5]
# => 120

factorials
# => {1=>1, 2=>2, 3=>6, 4=>24, 5=>120}
```

Mmm, that's some good Ruby, but what if we had more fun? I know! Dispatching!

```ruby
person_dispatcher = Hash.new { |hash, key| person.public_send(key) }
```

Of course we're polite Ruby citizens so we use `public_send`.

As to why, I have no honest clue, but it's fun and that's what one should expect from a post labeled black magic.

**Auto Vivification**

How many times have you wanted a nested hash just to have to do this nonsense:

```ruby
h[k] ||= {}
```

That's just no fun, but thankfully Ruby lets us play with the default_proc of Hash to do some fun stuff!

```ruby
vivified_hash = Hash.new { |hash, key|
  hash[key] = Hash.new(&hash.default_proc)
}

# => {}

vivified_hash[:a][:b][:c] = 5
# => 5

vivified_hash
# => {:a=>{:b=>{:c=>5}}}
```

So how deep down that rabbit hole do you want to go? As far as you want really. Hash has a concept of a `default_proc`, which is to say that it points to the block that it's in there making a sub-hash with that same block that can vivify as deep as you want.

## Black Magic

Now I believe I said black magic there in the title. This is all fairly tame Ruby so far, so what say you we change that?

Here's a fun question: What do Array, Hash, and Proc have in common?

*They all have `[]` as an accessor / caller*.

If you're worried about magic, now would be a very good time to run because we're going to look at some very abusive things you can do to Ruby.

**Path Explosion Hash**

So let's break this one down a bit:

```ruby
if path == :*
  # ...
else
  hash[path] = Hash.new(&hash.default_proc)
end
```

That part is sane, we just vivify the hash if we get a key that's not a `:*`.

```ruby
-> {
  prev_paths = [:*]

  recurse = -> { #...
```

So now we're setting a path to traverse on, and defining a recurse function we can call later. This also has the effect of creating a closure on prev_paths.

```ruby
if next_path == :*
  prev_paths.push(:*)
  recurse
```

If we get another `:*` we want to keep on pushing things onto that load path for later. We know there are two keys we can "ignore" now.

```ruby
[*prev_paths, next_path].reduce(hash) { |target, path|
```

So we're reducing onto the original hash. This is what I tend to call diving into a hash.

```ruby
if path == :*
  target.is_a?(Array) ? target.flat_map(&:values) : target.values
```

If we have a star path we're going to pull the values out of it. flat_map to pull them if it's an array. Effectively we're ignoring that it's an array.

```ruby
else
  if target.is_a?(Array)
    # ...
  else
    target[path]
  end
end
```

In this section, if it's not an array we just keep diving away into the next path available.

```ruby
if target.is_a?(Array)
  target.reduce([]) { |a,t|
    t[path] == {} ? a : a.push(t[path])
  }
else # ...
```

This is where it gets to be a bit fun. If it's an array we want to collect all the values at that path from the target, or ignore it if it's empty (one of our vivified nodes)

Which in the end gives us the example:

```ruby
path_explode_hash[:a][:b][:c] = 5
path_explode_hash[:a][:b][:d] = 6
path_explode_hash[:a][:g][:d] = 7
path_explode_hash[:a][:g][:c] = 8
path_explode_hash[:a][:m][:d] = 9
path_explode_hash[:a][:m][:x] = 10

p path_explode_hash[:*][:*][:d] # => [6, 7, 9]
p path_explode_hash[:*][:*][:x] # => [10]
p path_explode_hash[:a][:*][:x] # => [10]
```

## Wrapping Up

There are a lot of interesting things you can do with Hash constructors, but few you should honestly ever do in production. That said, it's no fun if you can't enjoy what all you can get away with in a language either, so enjoy!
