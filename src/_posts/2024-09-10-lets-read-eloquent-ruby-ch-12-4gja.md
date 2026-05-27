---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 12 – Equality"
series: "lets-read-eloquent-ruby"
date: "2024-09-10"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 12. Create Classes that Understand Equality

So equality. How does it even work in Ruby? What makes two things equal? Not equal? Maybe kinda sorta equal, those cases are real fun. Well this chapter is going to take a look at a lot of those

### An Identifier for your Documents

The book leads in with saying this can be a slippery slope, which is how you know we'll have a fair bit of fun with this chapter. It starts in with an example of how you might identify your documents and manage an ever-growing horde of them, and an initial solution of a `DocumentIdentifier`:

```ruby
class DocumentIdentifier
  attr_reader :folder, :name
  
  def initialize(folder:, name:)
    @folder = folder
    @name = name
  end
end
```

It presumes a management system of unique names and folders they're contained in. So how do we use that to determine if two documents are equal then?

### An Embarrassment of Equality

Ruby has a lot of methods, which one are we using today? `eql?`, `equal?`, `==`? Maybe even `===`, you remember that one from Javascript so it should probably be that! (It's not.)

What do each of them do? ([docs are great by the way](https://ruby-doc.org/3.3.5/Object.html#method-i-eql-3F)):

* `equal?` - Compares object identity (literally same object), so we don't want that
* `eql?` - Compare hash keys, `==` defaultly uses this
* `==` - What we want to override, general equality
* `===` - Case equality, or inclusion operator, _definitely_ not the same as JS

Most every time you're going to want `==`, but `===` has a lot of fun uses we may end up covering later too.

### Double Equals for Everyday Use

The current implementation coming from `Object` is the same as `eql?` meaning what we probably want to happen won't work:

```ruby
first_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")
second_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")

first_id == second_id
# => false
```

...so we'll make our own then:

```ruby
class DocumentIdentifier
  def ==(other)
    # We want them to be the same type
    return false unless other.instance_of?(self.class)
    
    folder == other.folder && name == other.name
  end
end
```

Handily `nil` responds to `instance_of?` so we don't need to check for that. We could, as the book mentions, do an `equal?` check for speed reasons but it likely won't happen enough to matter.

Trying it again we notice:

```ruby
first_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")
second_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")

first_id == second_id
# => true
```

...that it works.

### Broadening the Appeal of the `==` Method

The book complains that this is a very narrow definition of equality considering this line:

```ruby
return false unless other.instance_of?(self.class)
```

Should they not be equal if they have the same properties? We could do this in a new class like `DocumentPointer` just to keep it separate like the book:

```ruby
class DocumentPointer
  attr_reader :folder, :name
  
  def initialize(folder:, name:)
    @folder = folder
    @name = name
  end
  
  def ==(other)
    # We check the interface instead, ensuring we have the methods
    # we need.
    return false unless other.respond_to?(:folder)
    return false unless other.respond_to?(:name)
    
    folder == other.folder && name == other.name
  end
end
```

That means we could do something like this:

```ruby
first_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")
first_pointer = DocumentPointer.new(folder: "secret/plans", name: "raygun.txt")

first_pointer == first_id
# => true
```

...as long as the pointer is on the left.

### Well Behaved Equality

Speaking of which, the book leads with exactly that in this next section:

```ruby
first_id = DocumentIdentifier.new(folder: "secret/plans", name: "raygun.txt")
first_pointer = DocumentPointer.new(folder: "secret/plans", name: "raygun.txt")

first_id == first_pointer
# => true
```

Remember that the `==` operator that worked is defined on a `DocumentPointer` and not a `DocumentIdentifier`, and in the opposite case we're using `==` from `DocumentIdentifier` which uses `instance_of?` instead of interface checks.

The general concept for this is "symmetry" in that if `a == b` then `b == a` should also be true. In the above case unless we change both operators we are left with an asymmetric relationship.

The book goes further in saying that with equality we also assume that if `a == b` and `b == c` then `a == c` should also be true which represents the transitive property.

> **Note**: And now we've also basically covered Setoids from Category Theory and Set Theory. Didn't think you'd get an FP patterns tie-in in all of these did you? The only missing property here is reflexivity in which `a == a`.

The book goes further by introducing subclasses to really drive in the point here:

```ruby
class VersionedIdentifier < DocumentIdentifier
  attr_reader :version
  
  def initialize(folder:, name:, version:)
    @folder = folder
    @name = name
    @version = version
  end
  
  def ==(other)
    case other
    when VersionedIdentifier
      other.folder == folder &&
      other.name == name &&
      other.version == version
    when DocumentIdentifier
      other.folder == folder && other.name == name
    else
      false
    end
  end
end

versioned1 = VersionedIdentifier.new(folder: "specs", name: "bfg9k", version: "V1")
versioned2 = VersionedIdentifier.new(folder: "specs", name: "bfg9k", version: "V2")
unversioned = DocumentIdentifier.new(folder: "specs", name: "bfg9k")

versioned1 == unversioned # true
unversioned == versioned2 # true
versioned1 == versioned2 # false
```

It laments that somehow we have `a == b` and `b == c` but alas we have `a != c`. It provides a few solutions such as coercion to the lesser `DocumentIdentifier` for our `VersionedIdentifier` or maybe a newly named `is_same_document?` method to deal with the discrepancy.

Now this all not to say a word of inequality operators and how you might order these!

> **Note**: If you _did_ happen to go that far you might find out what an [Ord](https://github.com/i-am-tom/i-am-tom.github.io/blob/master/_posts/2017-04-09-fantas-eel-and-specification-3.5.md) is, which is even more functional pattern goodness (or badness, up to you really.)

### Triple Equals for Case Statements

For those of you coming from Javascript who think `===` in Ruby is a more strict equality? Well it's actually quite the opposite, it's less. It's frequently called the case equality operator, but personally I prefer the inclusion operator for reasons I'll get into in a moment.

You're already using it with those case statements above too:

```ruby
case 1
when Integer # === used right here!
  true
else
  false
end
# => true

Integer === 1
# => true
```

You could say that `1` is _included_ in `Integer` in this case. It works with _any_ Ruby type.

But no, we're not done yet, there's a lot more here with `===`. What about regex?

```ruby
location = "area 51"

case location
when /area.*/
  # ...
when /roswell.*/
  # ...
else
  # ...
end
```

In this case you could say that a match is an inclusion, in that the string `area 51` is included in what the regex is targeting.

The book stops here, but I won't, no no no. It also works with `Proc`:

```ruby
add_5 = -> a { a + 5 }
add_5 === 5
# => 10
```

Oh yes, you saw that right. How do I call that inclusion? Well back to maths we go, because that'd be an inclusion in the _domain_ of a function. I have a yarn board somewhere here.

That said please never use `===` directly unless you're wrapping it or putting it in a library for a very good reason. It's hidden behind enough corners that you can still get a lot of use out of it even without explicit references.

Hey, even things like `grep(_v)`, `any?/all?/none?`, and a lot of pattern matching uses them too. Once you know where to look they have a habit of showing up semi-frequently.

### Hash Tables and the `eql?` Method

As the book mentions earlier you're probably not going to use `eql?` directly much in the same manner as `===` was, but it sure hides behind a lot of corners just the same. In this case it's the method we use for determining Hash key equality:

```ruby
hash = {}

document = Document.new(title: "cia", author: "Roswell", content: "story")
first_id = DocumentIdentifier.new(folder: "public", name: "CoverStory")

hash[first_id] = document
```

That works fine, but what if we have a `==` equivalent id? Well something like this:

```ruby
second_id = DocumentIdentifier.new(folder: "public", name: "CoverStory")

the_doc_again = hash[second_id]
# => nil
```

Why? Well Hashes, as the book mentions, are wholly different than Arrays which index by numbers. It breaks apart all the keys it stores into buckets based on those key values based on a hash value. Usually it's a random number generated for each object, and the calculation to get it is something like:

```ruby
hash_code % number_of_buckets
```

...to get to the right match. That means whatever those keys are had better be stable over time or we'll end up looking in the wrong place for our values. If two keys are even they should be returning the same value, no? Well that's why we have `eql?`.

### Building a Well-Behaved Hash Key

How's that translate to Ruby? As the book mentions we have a corresponding `hash` method for the key and an `eql?` method for equality of those keys. Usually that means they have the same `hash` value, but it's Ruby so we can overwrite that!

Just be careful, as the book mentions, not to deviate from the idea that `a.eql?(b)` should behave similarly to `a.hash == b.hash`. How do we implement that? Well something like this:

```ruby
class DocumentIdentifier
  def hash
    folder.hash ^ name.hash
  end
  
  def eql?(other)
    return false unless other.instance_of?(self.class)
    
    folder == other.folder && name == other.name
  end
end
```

In that example, as the book mentions, the `hash` method combines the two fields we want to key on in what it describes as thorough mismatching of the two numbers via XOR (`^`) (see, we do _rarely_ use bitwise tricks here) and then taking a very strict view of equality otherwise by using a type check.

### Staying Out of Trouble

The first rule of adding things to your code is don't. The second rule is don't write, borrow from existing code you have. The third rule is if you _must_ break the first rule and the second be sure you actually need and use it. Same applies for equality. The more surface area of a program the more complexity can sneak in.

But the cardinal rule the book mentions? As simple as possible, no more and no less. Don't overdo it.

### In the Wild

Ruby's numeric types do a ton of conversion behind the scenes in a classic "Ruby probably knows what you meant" style of things. That said do be careful to be precise where it counts because things like this do work:

```ruby
1 == 1.0
# => true
```

The book also goes a bit off into Comparable which you can read more about here:

/writing/2021/02/09/understanding-ruby-comparable-34ki/

### Wrap Up

The book wraps up by again encouraging discretion. It's possible to make equality work, but be sure it's worth the effort and that you're not over-engineering the solutions.
