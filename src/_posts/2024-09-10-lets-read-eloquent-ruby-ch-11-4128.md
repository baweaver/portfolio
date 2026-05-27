---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 11 – Operators"
series: "lets-read-eloquent-ruby"
date: "2024-09-10"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 11. Define Operators Respectfully

Ruby, like some other languages, allows you to overload operators and a lot of them at that. Remember that every operator in Ruby is a method, meaning `1 + 2 == 1.+(2)`, and that includes certain prefix operators as well.

The book mentions that it's something that falls in and out of vogue. At the current time I think it's tapered off a bit and found a good niche of "use when reasonable" rather than "use whenever and wherever all the time because we can." Honestly that's probably a good policy for a lot of programming in general.

### Defining Operators in Ruby

The book mentions that Ruby allows you to do a lot of things to the language, up to and including making your own idea of a `Float` class and all the operators that come along with it. You can do much much worse if you're particularly inclined, especially when things like `TracePoint` are involved, but that's a subject for a much longer article.

The book immediately jumps into a similar example to the I'd listed above:

```ruby
sum = first + second

# What you are really saying is:
sum = first.+(second)

result = first + second * (third - fourth)

# Will smoothly translate into:
result = first.+(second.*(third.-(fourth)))
```

Yep, operators are methods, and in Ruby we can define methods even for our own classes which the book then gets into here:

```ruby
class Document
  def +(other)
    Document.new(
      title: title,
      author: author,
      content: "#{content} #{other.content}"
    )
  end
end

doc1 = Document.new(title: "Tag Line1", author: "Kirk", content: "These are the voyages")
doc2 = Document.new(title: "Tag Line2", author: "Kirk", content: "of the starship ...")

total_document = doc1 + doc2
puts total_document.content
# STDOUT: These are the voyages of the starship ..."
```

The only problem here might be that for classes we should make sure they're "combine-able" such that the author and maybe the title line up, otherwise merging them loses "Tag Line2" and makes it to where the left-side document always wins out. If that's a non-issue proceed away, but it's something to watch out for, and when it _is_ an issue typically I'd do something like this:

```ruby
class Document
  def +(other)
    raise ArgumentError, "Must be same title" unless title == other.title
    raise ArgumentError, "Must be same author" unless author == other.author
    
    Document.new(
      title: title,
      author: author,
      content: "#{content} #{other.content}"
    )
  end
end
```

...which would error out the example case, so this really all comes down to your discretion.

> **Note**: A book only has so much space. The things I might be pedantic over or expand upon are very likely outside the scope of the book and of the basic examples meant to convey a point. It doesn't mean the book is wrong and I'm right, it just means that I enjoy expanding upon content otherwise I would not be writing this series.

### A Sampling of Operators

The book mentions that you can define more than 20 operators for classes in Ruby, a number which has not moved much in recent days. The ones you're probably familiar with like arithmetic (+, -, *, /, %), less familiar with like bitwise (&, |, ^), and shifts (>> and <<.) Of course there are a few unary operators as well we'll get into for a moment.

Of course, as the book mentions, unless you're really into C and low-level chances are you're probably not doing bitwise operations in Ruby. You probably know `<<` for a very different reason:

```ruby
names = []
names << "Rob"
names << "Denise"

names
# => ["Rob", "Denise"]
```

That's because in different contexts operators have different meanings. Take the same applied to functions and you have a composition operator:

```ruby
add_5 = -> a { a + 5 }
mult_2 = -> a { a * 2 }
bold = -> a { "<strong>#{a}</strong>" }

# Forward composition, aka "pipe"
(add_5 >> mult_2 >> bold).call(4)
# => "<strong>18</strong>"
```

Reverse composition also works with `<<` which may be more familiar to our functionally oriented friends.

#### Unary Operators

Operators like `+` are binary, meaning they require two values, like `1.+(2)` or in a prefix notation language something like `+ 1 2` which might make the distinction clearer. Unary operators apply to only one argument, like `!`:

```ruby
!true
# => false
```

If it were applied to a class, like `Document`, maybe it would do something like this that the book mentions:

```ruby
class Document
  def !
    Document.new(title:, author:, content: "It is not true: #{content}")
  end
end
```

Wait wait wait, what happened to the values? Why are `title` and `author` key only? Well that's called shorthand Hash syntax which is great for highlighting which values are changing and focusing on those syntactically. That, and a bit less typing, which is always welcome.

Anyways, we run that and we might get something like this:

```ruby
favorite = Document.new(title: "Favorite", author: "Russ", content: "Chocolate is best")
!favorite
# Document(..., content: "It is not true: Chocolate is best")
```

Now the book mentions there are operators you can't overwrite like the english operators (not, and, or) and the logical booleans (&&, ||) as their behaviors are fixed. Now there are other reasons to avoid the english operators, but that's something for another article.

Notice how it didn't mention things like `-4`, which is also an operator. Now how does that work if subtraction already takes this?:

```ruby
def -(other)
  # implementation
end
```

Well in a slightly sneaky way:

```ruby
# Please don't actually do this:
class Numeric
  def +@ = abs
  def -@ = self * -1
end
```

...though if I'm being very honest the number of times that I've needed to or wanted to use these prefix operators has been _exceptionally_ rare, probably because of how confusing they might be. In the case of numbers you already have `abs` for absolute value and `* -1` for making something negative. You could probably even justify a `positive` or `negative` method to do it too if you really wanted to. Point being those names are clearer, especially for types where seeing a `+` or `-` in front of them may be odd.

Anyways, those prefix operators are rare because they're likely to be confusing, and I have yet to see them outside of very rare financial libraries.

#### Array Brackets?

Yep, those are methods too:

```ruby
class Document
  def [](index)
    words[index]
  end
end
```

The book suggests probably adding a `size` method as well, but there was an interesting paradigm which evolved since then in which it's used as a constructor alternative:

```ruby
class Point
  attr_reader :x, :y
  
  def initialize(x, y)
    @x = x
    @y = y
  end
  
  def self.[](x, y)
    new(x, y)
  end
end

Point[1, 2]
# => #<Point:0x0000000106f50198 @x=1, @y=2>
```

...which has a _lot_ of precedence around pattern matching, `Struct`, `Data`, and general constructors considering folks became wary of monkey-patching `Kernel` for every top-level initializer shorthand.

### Operating Across Classes

The book mentions that it's nice as long as both the classes line up, but once they're different... Well, what do you figure would happen if someone did this?:

```ruby
doc = Document.new(title: "hi", author: "russ", content: "hello")
new_doc = doc + "out there!"
```

Well with the current method we have it'd break:

```ruby
class Document
  def +(other)
    Document.new(title:, author:, content: "#{content} #{other.content}")
  end
end

# String does not respond to content!
```

...but we could also fix it, like the book mentions:

```ruby
class Document
  def +(other)
    if other.kind_of?(String)
      Document.new(title:, author:, content: "#{content} #{other}")
    else
      Document.new(title:, author:, content: "#{content} #{other.content}")
    end
  end
end
```

Though I would almost use a case statement for this:

```ruby
class Document
  def +(other)
    case other
    when String
      Document.new(title:, author:, content: "#{content} #{other}")
    when Document
      Document.new(title:, author:, content: "#{content} #{other.content}")
    else
      raise ArgumentError, "Can't combine Document and #{other.class}"
    end
  end
end
```

...just to be explicit about what we do and do not support.

### Staying Out of Trouble

The book then asks when you should define your own operators, and answers very similarly to what I would say of most things in programming: "It depends."

Types like Matrix, Vector, Set, and other similar concepts have a very clear defined usecase for each operator but others are likely not as clear. Really the further you are away from concrete idioms the more I would likely push for using a named method instead. Speaking of `push`:

```ruby
items = []
items.push("Something")
```

...if you came from a different language would `push` or `<<` be more immediately clear to you? Food for thought.

Even given this simple example in the book:

```ruby
a + b
```

You could probably think of several things that could be doing. One benefit we have are boundaries, or rules, that some of these operators tend to follow. In the case of addition we have a few properties which are interesting rules:

```ruby
# Any order: Order does not matter, same result
a + b == b + a

# Grouping execution: Group however you want if the order stays the same
a + b + c == (a + b) + c
(a + b) + c == a + (b + c)

# Same Types: Combine two of the same type, get back the same type
1.is_a?(Integer) # true
2.is_a?(Integer) # true
(1 + 2).is_a?(Integer) # true

# Empty: There's an element in the type, which when combined with any other
# returns the same thing
1 + 0 == 1
0 + 1 == 1

# Empty is different if you change the operator
1 * 1 == 1
1 * 10 == 10
```

Ah right, sorry, that was category theory. Congrats, you accidentally learned the basics of what are called Monoids there (mono - one, oid - in the manner of = in the manner of one thing, or combinable.) Have fun with that!

> **Note**: Yes yes, fine, I can hear you Haskell types typing away in my comments. Commutative is not a requirement for Monoids, it forms an Abelian Group instead if you add inversion as well. This was a basic offhand quippy example. Also any order is the commutative property, grouping is associativity, same types are closure, and empty is identity.

### In the Wild

Now a lot of those above are left-associative, sure, but there are some types that are not. Consider `Time` like the book does:

```ruby
now = Time.now
one_minute_from_now = now + 60
```

You can add time to the right, sure, but if you added it to the left?

```ruby
60 + now # Error! Time can't be coerced into Integer
```

That's because `+` on `Time` knows how to deal with `Integers` but not the other way around.

### Wrap Up

As with all things the name of the game here is discretion. You _could_ have an operator for everything, but would it add clarity to your program or take away from it? If the latter you should put it down and make a clearer named method. Just because you can do something in Ruby does not mean you should, unless of course you're in a code golfing competition in which case all bets are off, go wild.

You might notice the book deliberately avoids `==` and inequalities, and that's because that's the next chapter!
