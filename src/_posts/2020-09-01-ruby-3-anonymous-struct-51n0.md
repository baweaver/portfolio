---
layout: "post"
title: "Ruby 3 - Anonymous Struct"
date: "2020-09-01"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "ruby3"]
description: "In our series on new Ruby 3.0 features we start with the anonymous Struct, ${}."
---

> **NOTE**: This change was not implemented in Ruby 3

Starting off the first of many posts on [new features in Ruby 3](https://dev.to/t/ruby3) we'll be looking at the Anonymous Struct syntax which was recently [discussed on the bug tracker](https://bugs.ruby-lang.org/issues/16986)

# Quick Reference

So what does it do? It allows you to make Structs inline, almost like an OpenStruct:

```ruby
bob = ${ name: 'Bob', age: 42 }
sue = ${ name: 'Sue', age: 42 }
```

Which might look like this with OpenStruct instead:

```ruby
bob = OpenStruct.new(name: 'Bob', age: 42)
sue = OpenStruct.new(name: 'Sue', age: 42)
```

# Details

That said, let's take a look.

## What Can We Use It For?

Let's start with the fun section before we take a look into the rest of it. Some of this I will caveat with not knowing if it'll quite work as I can't experiment with this immediately.

### Pattern Matching

If this works I will be a very happy programmer:

```ruby
bob = Person.new(name: 'Bob', age: 42)

case bob
in ${ name: /^B/, age: 20..50 }
  true
else
  false
end
```

While one could fairly say:

```ruby
case bob
in Person[name: /^B/, age: 20..50]
  true
else
  false
end
```

...I like the potential for duck-typing on a set of attributes instead.

If we start getting into nested object types you can see where this could get real interesting real fast.

### Destructuring

With pattern matching that means we also get the very nifty [Struct#deconstruct_keys](https://ruby-doc.org/core-2.7.1/Struct.html#method-i-deconstruct_keys) which can be used to deconstruct keys out of objects.

Since `Object` itself doesn't have this behavior we can't quite get away with some of the same fun we can here like this:

```ruby
case ${ name: 'Bob', age: 42 }
in name: /^B/
end
```

...which allows us to skip some of the intermediary syntax.

### Debugging / Testing

How many times do you need to use something like `double` or make a fake object to respond to certain methods? With this new syntax you have a real quick way to have an inline mock object to feed to methods:

```ruby
def some_expecting_method(object)
  Rails.logger.info "#{object.name}: #{object.value} is interesting"
end

some_expecting_method(${ name: 'something', value: 'interesting' })
```

That'd be great for all types of spelunking and debugging adventures, as I've definitely used `OpenStruct` and my own quick `Struct` hacks for this in the past.

## So Why Not OpenStruct?

Because it turns out to be a bit slow. From the bugtracker:

> BTW, OpenStruct (os.a) is slow.

```
Comparison:
              hs[:a]:  92835317.7 i/s
                ob.a:  85865849.5 i/s - 1.08x  slower
                st.a:  53480417.5 i/s - 1.74x  slower
                os.a:  12541267.7 i/s - 7.40x  slower
```

## Splatting

This feature explicitly forbids Hash splatting:

```ruby
# Works
a = { a: 1, b: 2 }
b = { **a, c: 3 }

# Does not work
c = ${ **b, d: 4 }
```

The reasoning given is that a user could potentially input a faulty Hash causing a security problem.

**Caveat**

I cannot say I agree with this necessarily as there could be value in such a feature, and the language should not seek to prevent users from doing such things. If this were the case we would have locked down `eval` and other constructs long ago.

I would agree with formatters warning that it's not a great idea in some cases, but preventing the feature I don't quite agree with.

## Block KWArg Syntax and other alternatives

It was mentioned that Matz thought about the following syntax:

```ruby
{ |a: 1, b: 2| }
```

This may cause confusion with blocks as was [noted by another commenter](https://bugs.ruby-lang.org/issues/16986#note-2).

The other debated syntaxes were:

```ruby
# 1. Original
${a:1, b:2}

# 2. Matz's idea, conflicts with blocks
{|a:1, b:2|}

# 3. New Struct keyword, could introduce incompatibilities
struct a: 1, b: 2

# 4. %o for Object
%o{a:1, b:2}

# 5. Use parens
(a:1, b:2)

# 6. Methods on Struct or references to other class behavior
Struct.anonymous(a:1, b:2)

# 6.2 Kernel Struct method
Struct(a:1, b:2)

# 6.3 Struct#[] method, like Hash[a: 1]
Struct[a:1, b:2]
```

Personally I really like 6.3 as it follows along with a lot of behaviors from other classes in Ruby, but I have a bias towards `${}` for brevity.

# Parting Thoughts

I really like this feature idea, and will very likely be using it a lot in my own code for some of the above reasons. I would caution against using it too freely in production code outside of debugging as named classes are more easily documented and explained.

Looking forward to what Ruby 3.0 brings, and I'll be writing on new features as I see them.

Notice one that I haven't? Feel free to DM me on Twitter [@keystonelemur](https://twitter.com/keystonelemur) and I'll take a look into it.

*Note:* Currently working on a Ractor post but want to do more research on it first.

Until next time!
