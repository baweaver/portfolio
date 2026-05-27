---
layout: "post"
title: "Ruby 2.7 — Pattern Matching — First Impressions"
date: "2019-04-17"
categories: ["ruby", "functional"]
tags: ["ruby", "functional"]
description: "Ruby 2.7 — Pattern Matching — First Impressions   Shall we grab a sneak peak at what Pattern..."
---

### Ruby 2.7 — Pattern Matching — First Impressions

Shall we grab a sneak peak at what Pattern Matching looks like in Ruby 2.7? The code’s merged, nightly build is on the way, and I’m a rather impatient writer who wants to check out the new presents.

<!-- ![](https://cdn-images-1.medium.com/proxy/1*p0Ad_zpGIOEFOTX4Yft1Fw.png) -->

This is my first pass over pattern matching, and there will be more detailed articles coming out as I have more time to experiment with the features.

To be clear: This article will meander as it’s a first impression. I’ll be running more tests on it tomorrow, but wanted to write something on it tonight to see how well first impressions matched up.

### The Short Version

This is going to be a long article, and the short version isn’t going to cover even a small portion of it. Each major section will have a single style it covers.

The test file covers a good portion of this if you want an at-a-glance read:

[ruby/ruby](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb)

### Literal Matches

Much like a regular `case` statement, you [can perform literal matches](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L64):

```ruby
case 0
in 0 then true
else false
end
# => true
```

In these cases it would probably be best to use when instead.

The difference is that if there’s no match it’s going to [raise a](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L83)[`NoMatchingPattern`](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L83) error rather than returning `nil` like `case` / `when` statements would.

### Multiple Matchers

In typical `case` statements, a comma would be used, but with some of the new syntax this would break some of the destructuring that will be mentioned later:

```ruby
case 0
in 0 | 1
  true
end
# => true
```

In the case of captured variables below, they can’t be mixed:

```ruby
case 0
in a | 0
end
# Error: illegal variable in alternative pattern
```

### Captured Variables

One of the more interesting additions is [captured variable](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L104)s:

```ruby
case true
in a
  a
end
# => true
```

**In Guard Clauses**

These can also be used in [suffix conditionals or rather guard type clauses](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L125) in what’s reminiscent of Haskell:

```ruby
case 0
in a if a == 0
  true
end
# => true
```

**In Assignment Mappings**

They can even be assigned with a Hash-like syntax:

```ruby
case 0
in 0 => a
  a == 0
end
```

**With Placeholders**

Most interesting in this section is that they appear to treat underscores as a special placeholder:

```ruby
case 0
in _ | _a
  true
end
```

Though this could also be seen as a literal variable assignment, it’s an interesting riff on Scala’s pattern matching wildcards.

### **Destructuring**

Interestingly you can shadow the variables as well while destructuring an array:

```ruby
case [0, 1]
in a, a
  a == 1
end
# => true
```

It appears that the last assignment will be a in this case, and that commas are now used for destructuring rather than for denoting a separate pattern to match against as is the case for when.

**Deconstruct**

In the top of the file there’s a class defined:

```ruby
class C
  class << self
    attr_accessor :keys
  end

  def initialize(obj)
    @obj = obj
  end

  def deconstruct
    @obj
  end

  def deconstruct_keys(keys)
    C.keys = keys
    @obj
  end
end
```

It appears to indicate a way to define how an object should be destructured by pattern matching:

```ruby
[[0, 1], C.new([0, 1])].all? do |i|
  case i
  in 0, 1
    true
  end
end
```

including accounting for unbalanced matches:

```ruby
[[0], C.new([0])].all? do |i|
  case i
  in 0, 1
  else
    true
  end
end
```

I don’t understand how `deconstruct_keys` is working, but it feels really odd to me from first glance.

**With Splats**

It also will capture multiple arguments like destructuring currently works on Ruby arrays:

```ruby
case []
in *a
  a == []
end

case [0, 1, 2]
in *a, 1, 2
  a == [0]
end
```

Meaning that `*` could also be used as a bit of a wildcard:

```ruby
case 0
in *
 true
end
```

**On Hashes**

These appear to work a lot like keyword arguments:

```ruby
case {a: 0}
in a: 0
  true
end
```

That also means that kwsplats could be used here:

```ruby
case {}
in **a
  a == {}
end
```

…and with the keywords bit above, that means that classes could define their own destructuring using keywords, but I’m not clear on that.

I’m really hoping that this also uses `===` on each param, but the tests don’t indicate this. I’ll be experimenting with this later.

### Triple Equals

Like our current case statements, it appears that the new method of pattern [matching uses](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L255)[`===`](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L255) for comparisons:

```ruby
case 'abc'
in /a/
  true
end

case 0
in -> i { i == 0 }
  true
end
```

**Combined with Destructuring**

One thing I enjoyed in `Qo` was the ability to match against another array using `===` to write queries. It looks like the new syntax will compare each element and give us something very similar:

```ruby
case [0, 1, 2, 3, 4, 5]
in [0..1, 0...2, 0.., 0..., (...5), (..5)]
  true
end
```

It’s amusing that they’ve included beginningless and endless ranges in the example, as that could be _very_ useful later on. I certainly hope these work with hashes, as I _really really really_ want this to work:

```ruby
case object
in method_a: 0..10, method_b: String
 true
end
```

…because if we can define our own deconstructors just imagine the possibilities there. The class attr for keys is odd though, not sure what to think of that one.

### Pin Operator

I’m going to have to come back to this one as I do not understand it. I assume it means not to assign and to “pin” a variable so it [doesn’t get overwritten](https://github.com/ruby/ruby/blob/9738f96fcfe50b2a605e350bdd40bd7a85665f54/test/ruby/test_pattern_matching.rb#L306):

```ruby
a = /a/
case 'abc'
in ^a
  true
end

case [0, 0]
in a, ^a
  a == 0
end
```

I believe this can be used to capture one element in a variable and also reference it later like a back-reference of sorts.

### Thoughts?

This hasn’t built with Nightly yet, so I intend to make a second pass on this after it clears to verify some behavior I have suspicions about. Mostly I want to see about the hash matchers, as there’s some amazing potential there.

Going to be digging through and playing with this over the next few weeks, here’s the next post in the series:

[Ruby 2.7 — Pattern Matching — Destructuring on Point](/writing/2019/04/18/ruby-2-7-pattern-matching-destructuring-on-point-3hdb/)
