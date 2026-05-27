---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 7 – Objects"
series: "lets-read-eloquent-ruby"
date: "2024-09-03"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 7. Treat Everything Like an Object—Because Everything Is

Something that is easy to forget, given all the talk of every different paradigm Ruby supports, is that at its core it's a deeply Object Oriented language. This chapter explores a lot of those themes, along with the common tools Ruby uses across all objects.

### A Quick Review of Classes, Instances, and Methods

Russ starts in with the `Document` class mentioned in the first chapter:

```ruby
class Document
  # Most of the class omitted...
  
  # A method
  def words
    @content.split
  end
  
  # And another one
  def word_count
    words.size
  end
end
```

...and how we make a new instance of that class:

```ruby
doc = Document.new( 'Ethics', 'Spinoza', 'By that which is...' )
```

As a refresher you might see the syntax `ClassName.method_name` for class methods and `ClassName#method_name` for instance methods. This originated in Smalltalk and was carried over to a lot of Ruby's documentation, and it's good to know what it means.

I bring this up to say you might see `Document#word_count` to represent what would happen if we called `doc.word_count` on the _instance_ of a `Document` we've just created in the above example. Later chapters will get more into it, but knowing how those two tend to be annotated will be extremely useful even at this point in the book if you were to go off and read other Ruby code.

#### On `self`

Russ gives an example of what `self` is in the following code:

```ruby
class Document
  # Most of the class on holiday...
  
  def about_me
    puts "I am #{self}"
    puts "My title is #{self.title}"
    puts "I have #{self.word_count}"
  end
end

doc = Document.new('Ethics', 'Spinoza', 'By that which is...')
doc.about_me
# STDOUT: I am #<Document:0x1234567>
# STDOUT: My title is Ethics
# STDOUT: I have 4 words
```

`self` represents, in this case, the current instance which would be `doc` . There are ways to manipulate this and change that, but at this point in the book we can reasonably assume such until later on.

One thing he does here is show the usage of `self` in the explicit sense in front of `title` as `self.title` and `word_count` as `self.word_count`. You can omit both, but it does serve as an example that `self` is implied in these cases. There are some further complexities with namespace scoping and variables vs method calls, but that will also come up later in the book.

Russ does mention this though:

> Don’t write `self.word_count` when a plain `word_count` will do.

#### Superclasses

Russ mentions in the book that every class, except one, has a superclass. The book doesn't mention it, but that class is `BasicObject`. Try it yourself:

```ruby
class Test; end

Test.superclass # Object
Object.superclass # BasicObject
BasicObject.superclass # nil
```

In that you'll notice that our quick `Test` class inherits from `Object` as its superclass. If we don't specify a class our objects inherit from `Object` by default. Russ uses the following example of explicitly defining a superclass here:

```ruby
# RomanceNovel is a subclass of Document, which is a subclass of Object
class RomanceNovel < Document
end
```

He then goes on to mention that when trying to find a method Ruby will go through every superclass until it finds it, like so:

```ruby
class Grandparent
  def one = 1
end

class Parent < Grandparent; end
class Child < Parent; end

Child.new.one
# => 1
```

For now this is mostly correct, but later we'll get into `method_missing` which will expand upon this a good deal. The basic intuition here will still be handy to know.

### Objects All the Way Down

The book then gets into how Ruby's OO philosophy shapes the ways methods work. The first example is `Numeric#abs` which can be used to get an absolute value:

```ruby
-3.abs
# => 3
```

The book mentions in other languages you might have `abs(-3)` instead, but for Ruby the method _belongs_ to the object it's being called on, and in fact it belonging to that object is what gives it enough information to work.

The book then gets into a few more examples:

```ruby
# Call some methods on some objects

"abc".upcase
# => "ABC"
:abc.length
# => 3
/abc/.class
# => Regexp
```

...just to drive the point that pretty much everything in Ruby is an object.

#### Wait, Pretty Much?

Yes, sneaky words those. If I had to clarify I would say that everything that can have a value is an object whereas keywords and control flows are not like `if` and `case`. In Smalltalk some of those are still object methods, but in Ruby they're expressions and keywords.

There are some other gray areas like blocks, and entire threads of arguments on the subject, but the general statement that pretty much everything is an object is true enough to still hold a lot of value in your intuition of Ruby.

Russ even gets to this in the next section with an equally apt description:

> In Ruby, if you can reference it with a variable, it’s an object.

...though some pedants might still go on about blocks being assigned to variables.

#### Back on Topic

The book continues on into `true` and `false`, which surprise, are also objects:

```ruby
true.class
# => TrueClass

false.class
# => FalseClass
```

But what might be surprising here is there's _no_ `Boolean` class to wrap the two. On one hand they're both very similar in that they represent predicate states, but on the other they're the exact opposite of each other. To quote Matz, the creator of Ruby:

> ...There's nothing true and false commonly share, thus no Boolean class. Besides that, in Ruby, everything behave as Boolean value....

Which makes sense given the implicit nature of a lot of Ruby you might read:

```ruby
document.do_something if document
```

...in which we do something with a document if it's neither `nil` nor `false`. One thing to keep in mind with Ruby is that it heavily uses implicit expressions, and Rails does even more so. That doesn't always make it correct or necessarily the most understandable, but once you know what and why Ruby is doing something it allows you to skip a lot of boilerplate code.

The danger here, of course, is it's the "[Rest of the Owl](https://knowyourmeme.com/memes/how-to-draw-an-owl)" meme for some folks so personally I prefer to edge a bit more explicit even if not strictly necessary to make sure someone with even a few days of Ruby experience can reasonably understand what I'm up to with a particular piece of code.

### The Importance of Being an Object

Going back to Russ's quote here:

> In Ruby, if you can reference it with a variable, it’s an object.

He continues on to say that if this holds you can also probably assume it's an instance of `Object` somewhere down the tree as well, meaning they all share a common core of methods which are very useful to familiarize yourself with. In fact I would advocate for [reading the Object docs directly](https://ruby-doc.org/core/Object.html) at least a few times.

Going through some of the methods the book mentions we get methods like `class` and `instance_of?` from `Object`, and a lot of default implementations of things like `to_s` (to string). For `to_s` the default implementation will return back the object and its object id:

```ruby
doc = Document.new('Emma', 'Austin', 'Emma Woodhouse, ...')
puts doc
# STDOUT: #<Document:0x1234567>
```

...which is the same thing we saw from earlier with outputting `self` above. That also means we can write our own `to_s` method, as mentioned in the book:

```ruby
class Document
  def to_s
   "Document: #{title} by #{author}" 
  end
end

doc = Document.new('Emma', 'Austin', 'Emma Woodhouse, ...')
puts doc
# STDOUT: Ethics by Spinoza
```

He also briefly touches on `eval` to create our very own IRB-like REPL using nothing but a few simple methods from `Object`:

```ruby
while true
  print "Cmd> "
  cmd = gets
  puts eval(cmd)
end
```

> **Note**: Eval is very powerful, as the book mentions, but also _very_ dangerous. _Never_ use it in contexts where raw user input can get into it, lest some clever individual manages to send your Ruby program some variant of `system("rm -rf /")`.

#### Reflections

The book then gets into some of the reflection methods Ruby supplies to introspect into an object, like:

```ruby
doc.public_methods
# => (all methods of the object, including parents)

doc.public_methods(false)
# => (only methods defined in the Document class)

doc.instance_variables
# => [:@title. :@author, :@content]
```

Now there are some variants here such as `methods`, `instance_methods`, and others which is why reading through the `Object` docs can be handy. Often times I find if a method sounds reasonable Ruby _probably_ has it.

### Public, Private, and Protected

The book then goes into some visibility controls, namely:

* `public` - Available to everyone
* `protected` - Available only to this class and sub-classes
* `private` - Available to only this class

...and provides the following two methods of making something private:

```ruby
class Document
  private # Methods below here are private
  
  def word_count
    words.size
  end
end

class Document
  def word_count
    words.size
  end
  
  private :word_count # Only one method made private
end
```

...but the second case is more modernly written as:

```ruby
private def word_count
  words.size
end
```

Why? Because defining a method returns its name as a `Symbol`:

```ruby
def testing = 1
# => :testing
```

In general with privacy you should expose as little information as necessary as public methods. Focus on a clear, minimal interface that cleanly encapsulates the data in the class otherwise you end up with everyone reaching into every facet of every `Object`. While the book mentions that these access controls are not common in Ruby core I would personally encourage liberal use of them as untangling object dependencies down the road in a 1M+ lines of code app becomes a daunting task.

Back to the book it then goes into what happens when we call private methods. Simply put they raise exceptions:

```ruby
class PrivateThings
  private def private_method = 1
end
# => :private_method

PrivateThings.new.private_method
(irb):25:in `<main>': private method `private_method' called for #<PrivateThings:0x000000010692b128> (NoMethodError)

PrivateThings.new.private_method
                 ^^^^^^^^^^^^^^^
```

...but it's also mentioned that you _could_ get around this with `send`:

```ruby
PrivateThings.new.send(:private_method)
# => 1
```

In general you should avoid using `send` unless you have no other options, as things are generally private for a reason. That includes in your tests, because private methods should be exercised and tested via public interfaces instead.

### In the Wild

The book mentions, rightly so, that so much of Ruby is about methods and how they're called. If everything is an `Object` it stands to reason the actions you can take upon them are also rather important. It also mentions that most everything, even some surprising things, are methods. Even most operators are:

```ruby
1.+(2) == 1 + 2
# => 2
```

The things that aren't are things like control flow (`if`, `unless`, `case`, etc), assignments (`a = 1`), loops (`while`, `loop`, `until`), and more. While not a comprehensive list the full one isn't much larger than that.

Even `require`, used for loading other code, is a method.

The book then mentions the `attr_*` methods as another example:

```ruby
class Person
  # All of these are methods
  attr_accessor :salary
  attr_reader :name
  attr_writer :password
end
```

...and by chapter 26 the book will go over implementing your own.

### Staying Out of Trouble

Remember earlier when `public_methods` was said to return some 50+ methods? That means there's a lot of room to accidentally use the same name like in the example the book provides:

```ruby
class Document
  # Send this document via email
  def send(recipient)
    # Do some interesting SMTP stuff
  end
end
```

Another example they provide of things going wrong are if you have an error in your `to_s` method:

```ruby
class Document
  def to_s
    "#{title} by #{aothor}" # oops!
  end
end
```

...which will ensure you can't use `puts` for your documents, though I would argue the exceptions will still be informative here.

The last is mentioning how often there are multiple ways to do something in Ruby and sometimes they all converge into a much simpler solution if you know how the language works:

```ruby
if the_object.nil?
  puts "The object is nil"
elsif the_object.instance_of?(Numeric)
  puts "The object is a number"
else
  puts "The object is an instance of #{the_object.class}"
end
```

...when it could be written more simply as:

```ruby
puts "The object is an instance of #{the_object.class}"
```

There's a lot of power in a unified interface, and hey, it's why `Interface` is such a popular term in programming in general. With Ruby there are more than a few of these "interfaces", normally suffixed with `able` like `Enumerable`, `Comparable`, and others. Learning them, and how to leverage them, can be very powerful.

### Wrapping Up

The book closes this chapter by reiterating the main point that almost everything in Ruby is an `Object`. I would add that unified interfaces are also exceptionally good to consider in Ruby, as a lot of code can be dramatically simplified when one knows of them.

While privacy was a narrower section of this chapter I would heavily encourage making as few methods public as possible on any class you write. Reduce its public interface as much as possible, and in doing so you make the boundaries of your program much clearer. If we made everything public then anyone can do anything with any data anywhere, and take it from me when I say that can get messy very quickly, especially at scale.
