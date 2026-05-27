---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 17 – Block Iterators"
series: "lets-read-eloquent-ruby"
date: "2024-09-24"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 17. Use Blocks to Iterate

Blocks, or as I prefer to call them block functions, are an exceptionally distinct part of Ruby. If you've used Javascript or languages with a more functional bend they're going to look very familiar, but if not they can be a bit of a foreign concept.

As the book mentions they're part syntax, part method, part object, and one part function that it doesn't mention. This chapter kicks into the sections on blocks which we'll be covering for the next few chapters.

### A Quick Review of Code Blocks

The book opens with this code sample in two styles:

```ruby
# Multiline do/end block
do_something do
  puts "Hello from inside the block"
end
# STDOUT: Hello from inside the block

# Single line bracket ({}) block
do_something { puts "Hello from inside the block" }
# STDOUT: Hello from inside the block
```

As the book mentions Ruby treats blocks differently than other method arguments and uses this example to demonstrate:

```ruby
def do_something
  yield if block_given?
end
```

...in which `yield` calls the block and `block_given?` only returns true if the method was given a block. This is the very implicit style of handling blocks in Ruby, and personally I prefer the much more explicit one:

```ruby
def do_something(&block_function)
  block_function.call if block_function
end
```

The next example the book gives makes my preference a bit clearer between the two:

```ruby
# Implicit stype
def do_something_with_an_arg
  yield("Hello world") if block_given?
end

# Explicit style
def do_something(&block_function)
  block_function.call("Hello world") if block_function
end

do_something_with_an_arg do |message|
  puts "The message is #{message}"
end
# STDOUT: The message is Hello world
```

...but as with most things it's a matter of preference in Ruby. Personally though the question which always goes through my head is whether or not a new developer can read my code and have a decent idea of what I'm doing, and if the answer is no it gives me pause unless I have no other reasonable choice.

The book also goes on to remind us that `yield` returns a value like many other Ruby methods:

```ruby
# Implicit style
def print_the_value_returned_by_the_block
  if block_given?
    value = yield
    puts "The block returned #{value}"
  end
end

def print_the_value_returned_by_the_block(&block_function)
  return unless block_function
  
  value = block_function.call
  puts "The block returned #{value}"
end

print_the_value_returned_by_the_block { 3.14159 / 4.0 }
# STDOUT: The block returned 0.7853975
```

Granted the explicit version also demos guard functions, which is another preference, but my goal here is to demonstrate different ways of thinking about things because chances are you'll run into code that's stylistically very different than the book or what you or I might like out there.

### One Word after Another

The book mentions that the difference between the above methods and an iterator is simple: An iterator is used to iterate a collection, which means calling a function on each element of that function in sequence:

```ruby
class Document
  # Implicit
  def each_word
    word_array = words
    index = 0
    
    while index < words.size
      yield word_array[index]
      index += 1
    end
  end
  
  # Explicit
  def each_word(&block_function)
    word_array = words
    index = 0
    
    while index < words.size
      block_function.call(word_array[index])
      index += 1
    end
  end
  
  # Using each instead
  def each_word(&block_function)
    # Longer version
    words.each do |word|
      block_function.call(word)
    end
    
    # Shorthand
    words.each(&block_function)
  end
end
```

Then it gives us an example of using this method:

```ruby
d = Document.new(title: "Truth", author: "Gump", content: "Life is like a box of...")
d.each_word { |word| puts word }
# STDOUT: Life
# STDOUT: is
# STDOUT: like
# STDOUT: a
# STDOUT: box
# STDOUT: of
# STDOUT: ...
```

...ah, and then the book goes back to say you should use `each` explicitly like the "Using each instead" variant above. Sometimes I get ahead of myself.

### As Many Iterators as You Like

As the book mentions there's no technical limit to how many iterator methods you might have. Perhaps one for words, lines, characters, or whatever else makes sense. You can name them whatever, but as the book mentions naming them something descriptive is a good idea:

```ruby
class Document
  def each_character(&block_function)
    @content.chars.each(&block_function)
  end
end
```

Though this does raise a very amusing point in that Ruby's `String` does not have an `each` method as the matter of what to iterate over is not always clear, hence the `chars.each` invocation above.

### Iterating over the Ethereal

The thing about iterating, as the book mentions, is that you don't need the thing you're iterating to be a collection or even to exist really. It just needs to be able to express the idea of iteration in its own unique way. The example the book uses here is `times`:

```ruby
12.times { |x| puts "The number is #{x}" }
```

We're not iterating over a collection, and a number certainly doesn't have items in it, but the concept of `times` is that the number tells us how many times to do something so it still matches the idea of iteration.

There's also no real restriction on how you choose to iterate. The book mentions an example of iterating every consecutive two words like so:

```ruby
class Document
  def each_word_pair
    word_array = words
    index = 0
    
    while index < (word_array.size - 1)
      yield word_array[index], word_array[index + 1]
      index += 1
    end
  end
  
  # Or the shorter Enumerable version:
  def each_word_pair(&block_function)
    words.each_cons(2).each(&block_function)
  end
end
```

At no point have we built out all of those pairs, but we do while we're iterating. `each_cons` with `Enumerable` gives us even more power here to express the same idea more succinctly.

### Enumerable: Your Iterator on Steroids

So why `each`? Because one of the most powerful tools in Ruby, `Enumerable`, uses it as a foundation. If you can define `each` you can do a _lot_ of other things. Let's start with `each` though:

```ruby
class Document
  include Enumerable
  
  def each
    words.each { |word| yield(word) }
  end
end
```

...and a few examples of some `Enumerable` magic:

```ruby
doc = Document.new(title: "Advice", author: "Harry", content: "Go ahead and make my day")

doc.include?("day")
# => true

doc.select { |word| word.start_with?("a") }
# => ["ahead", "and"]
```

It also gives us a few methods like `each_cons`, like the above code example in the previous section:

```ruby
def each_word_pair
  # The book prefixes this with `words` but...
  words.each_cons(2) { |array| yield(array[0], array[1]) }
  
  # ...you could also do this instead if it's an Enumerable:
  each_cons(2) { |array| yield(array[0], array[1]) }
end
```

The sort methods, however, rely on another method called `<=>`, or the "rocket ship" operator and its associated `Comparable` module. Often times folks will implement both, but in this case if the elements returned by `each` have `<=>` defined (and `String` does) you get it for free.

Enumerable, as the book mentions, gives you 40+ methods for free based on a single method, `each`. Maybe you want to get all the `Enumerable` methods off of another iterator method instead? Well the book mentions that you can use `Enumerator` here:

```ruby
doc = Document.new(title: "example", author: "russ", content: "We are all characters")
enum = Enumerator.new(doc, :each_character)

puts enum.count
pp enum.sort
# => [" ", " ", " ", "W", "a", "a", "a", "a", "c", ...]
```

...but you could also use `enum_for` instead in each of those methods:

```ruby
class Document
  def each_character
    # `to_enum` is also a synonym here
    return enum_for(:each_character) unless block_given?
    
    chars.each { |c| yield c }
  end
end
```

...which lets us do this:

```ruby
doc = Document.new(title: "example", author: "russ", content: "We are all characters")

doc.each_character.count
doc.each_character.sort
```

Personally I prefer the `enum_for` as a return for methods that take a block but were not given one, particularly for iterators.

### Staying Out of Trouble

The book mentions the primary danger here is trusting the block passed into a method too much, as it's potentially trusting someone else's code. Perhaps they change the underlying collection or do something else bad, or as the book mentions perhaps it could even throw an exception:

```ruby
doc.each_word do |word|
  raise "boom" if word == "now"
end
```

The book then mentions that if an exception were raised in a sensitive method like so it could do some damage:

```ruby
def each_name
  name_server = open_name_server
  
  while name_server.has_more?
    yield name_server.read_name
  end
  
  name_server.close
end
```

So it encourages wrapping the code such that it can handle those exceptions:

```ruby
def each_name
  # Get some expensive resource
  name_server = open_name_server
  
  while name_server.has_more?
    yield name_server.read_name
  end
# Ensure works like rescue, we can have it at the top level too
ensure
  # Close the expensive resource
  name_server.close
end
```

Granted this should be a general concern in programming: Assume everything could potentially fail and make your code resilient to potential failures, especially ones that could cause damage to systems.

The other example the book gives is if someone uses `break` in the middle, but that'll still trigger `ensure`:

```ruby
def count_til_tuesday(doc)
  count = 0
  
  doc.each_word do |word|
    count += 1
    break if word == "Tuesday"
  end
  
  count
end
```

Speaking of async resources though: Use ActiveJob for those, don't do it inline, and if you don't know about idempotency, retries, exponential backoffs, or state machines those would be very good topics to read up on in general.

### In the Wild

The book then goes into a few more examples in the core of Ruby that use block iterators. `Dir` can iterate over directories of files for instance:

```ruby
puts "Contents of /etc directory:"
etc_dir = Dir.new("/etc")
etc_dir.each { |entry| puts entry }
```

...or the case of a DNS resolver looking up each address associated to a domain name (the IPs have _probably_ changed by now):

```ruby
require "resolv"
Resolv.each("www.google.com") { |x| puts x }
# STDOUT: 72.14.204.104
# STDOUT: 72.14.204.147
# STDOUT: 72.14.204.99
# STDOUT: 72.14.204.103
```

...or `ObjectSpace` which is a particularly powerful little tool for introspecting every live object in Ruby:

```ruby
ObjectSpace.each_object(String) { |the_string| puts the_string }
```

Careful though, because things like "every ruby object" or even a lot of them are _expensive_ and best left to either test or development environments. Same thing with `TracePoint` which is arguably more dangerous (and potentially more fun.)

Some even have infinite series:

```ruby
require "prime" # mathn doesn't exist anymore

# You want to limit it, otherwise it'll keep going for a while
Prime.first(20).each { |x| puts "The next prime is #{x}" }
```

Point being that you're going to find iterators in a _lot_ of places in Ruby, both in core and in any library you happen to use.

### Wrapping Up

Understanding blocks, or at least being able to read them and understand what's going on, are critical to working effectively with Ruby. They're just as important as understanding functions in Javascript or other functional languages. 

One thing the book tends to gloss over a bit is that blocks are indeed functions, which is why I insist on calling them block functions in several places in this chapter. If you think of them as functions you can take intuition from other languages as well as learn a lot of useful techniques from functional programming in general.

Ruby borrows a lot and learned a lot from other languages, it's well worth doing the same.
