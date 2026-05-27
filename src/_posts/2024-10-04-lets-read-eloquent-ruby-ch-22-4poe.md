---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 22 – Method Missing Delegation"
series: "lets-read-eloquent-ruby"
date: "2024-10-04"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 22. Use method_missing for Delegation

Y'know after reading that intro paragraph in the book I'm questioning whether or not I want to pursue management again, but then again a lot of my job nowadays is writing `Document`s (heh) and delegating work to others and trying to distill context into where in the world we're going next and why we should be doing it.

The book uses that aside to lead into the idea of delegation in programming, which is to give a task to another object to either do the entire task or a part of it for you. Frequently you'll find this used for wrappers in Ruby that change maybe a few things about an original object but otherwise send everything along as-is.

### The Promise and Pain of Delegation

We're back with the idea of our `Document` class, except this time we want to wrap it with an idea that the content should be locked down after a certain time limit as the contents are especially sensitive:

```ruby
class SuperSecretDocument
  def initialize(original_document:, time_limit_seconds:)
    @original_document = original_document
    @time_limit_seconds = time_limit_seconds
    @create_time = Time.now
  end
  
  def time_expired?
    Time.now - @create_time >= @time_limit_in_seconds
  end
  
  def check_for_expiration
    raise "Document no longer available" if time_expired?
  end
  
  def content
    check_for_expiration
    @original_document.content
  end
  
  def title
    check_for_expiration
    @original_document.title
  end
  
  def author
    check_for_expiration
    @original_document.author
  end
  
  # and so on...
end

original_instructions = get_instructions
instructions = SuperSecretDocument.new(
  original_document: original_instructions,
  time_limit_in_seconds: 5
)
```

We keep a reference to the original document, but for a lot of you your DRY sense is going to be going off right about now. It seems like we're doing the same thing fairly frequently no?

That's where delegation comes in.

### The Trouble with Old-Fashioned Delegation

Right now this doesn't seem so bad, but what if we added a few more methods?:

```ruby
class SuperSecretDocument
  def initialize(original_document:, time_limit_seconds:)
    @original_document = original_document
    @time_limit_seconds = time_limit_seconds
    @create_time = Time.now
  end
  
  def time_expired?
    Time.now - @create_time >= @time_limit_in_seconds
  end
  
  def check_for_expiration
    raise "Document no longer available" if time_expired?
  end
  
  # content, title, and author methods omitted
  # to keep from adding more scrolling...
  
  # And some new methods...
  
  def page_layout
    check_for_expiration
    @original_document.page_layout
  end
  
  def page_size
    check_for_expiration
    @original_document.page_size
  end
  
  # and so on...
end
```

...or maybe 10 or 20 more? At what point does this start becoming unmaintainable? Sure, we're forwarding things to the original document, but in a fairly cumbersome way.

### The method_missing Method to the Rescue

This is where `method_missing` can come in handy:

```ruby
class SuperSecretDocument
  def initialize(original_document:, time_limit_seconds:)
    @original_document = original_document
    @time_limit_seconds = time_limit_seconds
    @create_time = Time.now
  end
  
  def time_expired?
    Time.now - @create_time >= @time_limit_in_seconds
  end
  
  def check_for_expiration
    raise "Document no longer available" if time_expired?
  end
  
  def method_missing(name, *args)
    check_for_expiration
    @original_document.send(name, *args)
  end
end
```

Now any method which we don't know about automatically goes right on to the base object. We can even test it like so:

```ruby
string = "Good morning, Mr. Phelps"
secret_string = SuperSecretDocument.new(
  original_document: string,
  time_limit_in_seconds: 5
)

puts secret_string.length # Works fine
sleep 6
puts secret_string.length # Raises exception
```

### More Discriminating Delegation

But sending everything, like mentioned in previous chapters, can be dangerous so we probably want a limiter around that. Frequently, as the book mentions, `method_missing` will have a list or allowed methods or perhaps a pattern they need to follow to be considered valid:

```ruby
class SuperSecretDocument
  DELEGATED_METHODS = %i[content words]
  
  def method_missing(name, *args)
    check_for_exipration
    
    return super unless DELEGATED_METHODS.include?(name)
    
    @original_document.send(name, *args)
  end
end
```

The nice thing in this case about forwarding to the original document is that if we happen to have a method get through that we _did not_ intend it's going to fail as that method doesn't exist on the underlying object either.

That said allow lists are the way to go. You want to limit how much `method_missing` actually catches and deals with as the more limited it is the more you can guarantee it's not going to surprise you down the line. Really that's a good rule for a lot of programming: limit things to predictable outcomes whenever possible, and if not test and monitor the heck out of the thing.

### Staying Out of Trouble

The problem here is that while some classes do have the method somewhere up the chain, like `to_s` is present all the way up in `BasicObject`:

```ruby
original_instructions = get_instructions
instructions = SuperSecretDocument.new(
  original_document: original_instructions,
  time_limit_in_seconds: 5
)

puts instructions.to_s
#<SuperSecretDocument:0x123456789>
```

If we wanted to get around that we'd have to inherit from `BasicObject` to hack around it, or define our own `to_s` method closer to home:

```ruby
class SuperSecretDocument < BasicObject
  # ...
end
```

The book mentions you have to patch Ruby 1.8 to get this behavior, but nowadays 1.8 is (hopefully) long gone and has been for years. If you're still on it you have my condolences.

### In the Wild

As with a lot of things in Ruby there's always a built in tool or gem to do something that seems really handy. In this case we have `SimpleDelegator` which does exactly that:

```ruby
require 'delegate'

class DocumentWrapper < SimpleDelegator
  def initialize(real_doc)
    super(real_doc)
  end
end

text = "The Hare was once boasting of his speed..."
real_doc = Document.new(title: "Hare & Tortise", author: "Aesop", content: text)

wrapper_doc = DocumentWrapper.new(real_doc)

puts wrapper_doc.title
# STDOUT: Hare & Tortise
puts wrapper_doc.author
# STDOUT: Aesop
puts wrapper_doc.content
# STDOUT: The Hare was once boasting of his speed...
```

Any method we don't explicitly overwrite is going right to the underlying object. This has been very useful for me in the past when refactoring where I need to emulate a new contract with old code and change only a few methods on a base object before removing it completely later. Bonus points when using it with feature flagging too.

The other example the book gives us is Rails where it would previously lazy load attributes for objects using `method_missing`, but that's changed a while ago to where the methods are defined immediately, albeit still dynamically based on the columns of the class.

### Wrapping Up

Seriously, delegation is fantastic for refactoring things. Go and read the docs for [Forwardable](https://ruby-doc.org/stdlib-2.7.1/libdoc/forwardable/rdoc/Forwardable.html) and [SimpleDelegator](https://ruby-doc.org/stdlib-2.5.1/libdoc/delegate/rdoc/SimpleDelegator.html) some time. I've gotten a ton of mileage out of them, and they're perhaps the single most useful way to use `method_missing` directly in Ruby.

The next chapter continues on the exploration of `method_missing` with building flexible APIs.
