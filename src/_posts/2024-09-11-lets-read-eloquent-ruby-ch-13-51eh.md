---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 13 – Singleton and Class Methods"
series: "lets-read-eloquent-ruby"
date: "2024-09-11"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 13. Get the Behavior you Need with Singleton and Class Methods

Not everything fits inside a nice box. For every rule there's counterexample, for every model of thinking there's a weakness, and the same can be said about Object Oriented programming. Some have gone to much more colorful lengths to describe this problem like in the old classic [Execution in the Kingdom of Nouns](https://steve-yegge.blogspot.com/2006/03/execution-in-kingdom-of-nouns.html).

Sometimes you need an alternative, and Ruby? It's awash with alternatives for about everything you could think of. Sometimes that's just what you need, other times it makes things incomprehensible, but the core of it is Ruby lets you choose where that line is with more fidelity than a lot of other languages.

In this case we're talking about singleton methods, a way to have a distinct set of behaviors specific to a single object.

### A Stubby Puzzle

The book looks back at chapter 9 and `stub`, but in our example we used `instance_double` instead as it verifies the underlying methods exist first:

```ruby
class Printer
  def available? = false
  def render(content) = "something"
end

class Document
  def words = []
end

# Warning: Will only work in the context of an RSpec test
printer_double = instance_double(Printer, available?: true, render: nil)
document_double = instance_double(Document, words: %w(Hi there))
```

...and as the book mentions you could have one double, two, maybe ten! But if you took a look at them you'd find out they look very similar:

```ruby
[printer_double.class, document_double.class]
 => [RSpec::Mocks::InstanceVerifyingDouble, RSpec::Mocks::InstanceVerifyingDouble]
```

So how does that work? The answer, as the book mentions, is that each of those instances of `RSpec::Mocks::InstanceVerifyingDouble` has distinct singleton methods defined on them. In the case of an `instance_double` those do have to be methods the underlying class you're mocking uses, but think of these as interceptors which say "Hey, I heard you were looking for `available?`! I have it over here closer to you.":

```ruby
# Only methods defined directly on this instance
printer_double.methods(false)
# => [:available?, :render]
```

#### Our Own Stubs

If we wanted to we could even make our own stubs like so:

```ruby
hand_built_stub_printer = Object.new

def hand_built_stub_printer.available? = true
def hand_built_stub_printer.render(content) = nil

hand_built_stub_printer.methods(false)
# => [:available?, :render]
```

...or we could even make something a bit more obstinate that, as the book mentions, we won't see in real code:

```ruby
uncooperative = "Don't ask my class"

def uncooperative.class = "I'm not telling"

puts uncooperative.class
# STDOUT: I'm not telling
```

The book also suggests an alternative syntax for our little stub variant:

```ruby
hand_built_stub_printer = Object.new

class << hand_built_stub_printer
  def available? = true
  def render(content) = nil
end
```

Either way you end up with something similar, though honestly I've done this trick a decent amount of times as well:

```ruby
fake_class = Class.new(OriginalObject) do
  def method_i_want_to_overwrite = true
end
```

...which uses inheritance rather than singleton methods, but that can be a matter of preference in implementation.

### A Hidden, but Real Class

How's that work in Ruby? Well as the book mentions every class has its own singleton class that sits between an instance and the underlying class itself. Usually you won't notice it unless you add things to it. You can even see it by doing something like this:

```ruby
hand_built_stub_printer = Object.new
singleton_class = class << hand_built_stub_printer
  self
end

puts singleton_class
# STDOUT: #<Class:#<Object:0x000000010dc5db78>>
```

How did we get the singleton class there? Remember everything in Ruby is an expression, including class definitions. Oddly though classes don't return their own names like methods do:

```ruby
class Testing
  def a = true
end
# => :a
```

### Class Methods: Singletons in Plain Sight

The book mentions that most programmers tend to dismiss singleton methods as interesting, but mostly useless. It highlights one particular counterexample that, as it says, "is practically impossible to build a Ruby program without." What is it? Class methods.

Consider this example from the book:

```ruby
my_object = Document.new(title: "War and Peace", author: "Tolstoy", content: "All happy families...")

def my_object.explain
  puts "self is #{self}"
  puts "and its class is #{self.class}"
end

my_object.explain
# STDOUT: self is #<Document:object_id>
# STDOUT: and its class is Document
```

Just a refresher from before, but what if you defined a method on the class itself?:

```ruby
my_object = Document

def my_object.explain
  puts "self is #{self}"
  puts "and its class is #{self.class}"
end

my_object.explain
# STDOUT: self is Document
# STDOUT: and its class is Class
```

But the book mentions a few more variants of this style, some of which might be familiar:

```ruby
# Inline method style
def Document.explain
  puts "self is #{self}"
  puts "and its class is #{self.class}"
end

# Class Self style
class Document
  class << self
    def find_by_name(name)
      # Find a document by name
    end
    
    def find_by_id(id)
      # Find a document by id
    end
  end
end
```

`class << self` is the exact same idea as the above `class << some_object` syntax we were playing with up above. You might have also seen it in this format as well:

```ruby
class Document
  def self.find_by_name(name)
    # Find a document by name
  end

  def self.find_by_id(id)
    # Find a document by id
  end
end
```

So which one do you use? Well for me if I have a few class methods I use `self.method_name` and if I have several I'd probably use `class << self` or another variant the book doesn't mention here for containing several functions:

```ruby
module Functions
  extend self
  
  def map(array, &block_function)
    new_array = []
    array.each { |item| new_array << block_function.call(item) }
    new_array
  end
end
```

Personally I don't care for mixing and matching class and instance methods for those types of containers, so that above solution works great for many of my personal use cases.

### In the Wild

As the book mentions there are class methods all over the place in Ruby, and especially in Rails. If you had this model class for instance:

```ruby
class Author < ActiveRecord::Base; end
```

...and you wanted to know what table it was associated with in the database, you could find out by asking the class directly:

```ruby
Author.table_name
```

....and if you've ever used scopes:

```ruby
class Document < ActiveRecord::Base
  scope :content_includes, -> phrase { where("content LIKE ?", "%#{phrase}%") }
end
```

Those are class methods too (albeit they have slightly different behaviors):

```ruby
class Document < ActiveRecord::Base
  def self.content_includes(phrase)
    where("content LIKE ?", "%#{phrase}%")
  end
end
```

Speaking of, `where` is a class method as well, among a myriad of other fun Rails methods.

The book goes into a few more examples of alternate constructors but we'll leave it there for now.

### Staying Out of Trouble

One of the most common issues, as the book mentions, with class methods is getting them and instance methods confused:

```ruby
class Document
  def self.create_test_document(length)
    Document.new(title: "test", author: "test", content: "test" * length) 
  end
end
```

If you called that method on the class you'd get what you expect:

```ruby
Document.create_test_document(10_000)
```

But if you happened to instead call it on an instance of a document:

```ruby
doc = Document.new(title: "test", author: "test", content: "test")
doc.create_test_document(10_000)
# NoMethodError!
```

...you'd find that you'll get an exception.

The other example it uses is what happens with `self` and inheritance:

```ruby
class Parent
  def self.who_am_i = "The value of self is #{self}"
end

class Child < Parent; end
  
Parent.who_am_i
# => "The value of self is Parent"

Child.who_am_i
# => "The value of self is Child"  
```

That's because `Child` is _receiving_ the method in this case, not a `Parent`.

### Wrap Up

As with everything, balance is needed. Singleton methods have a lot of use, but they can also be overused. If you find yourself reaching for instance variables and starting to reinvent instances it's time to make an instance. Keep them simple, to the point, and be wary of adding too much state to them.

Speaking of, next up we have class instance variables, which admittedly I am very much not a fan of for the same reasons I just mentioned, so we'll see how that article goes.
