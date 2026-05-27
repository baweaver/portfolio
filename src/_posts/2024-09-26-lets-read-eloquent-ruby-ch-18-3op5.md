---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 18 – Block Wrapping"
series: "lets-read-eloquent-ruby"
date: "2024-09-26"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 18. Execute Around with a Block

The focus of this chapter is how we start using block functions to wrap our code and transport around values. Sound abstract? Don't worry, we'll get into the examples soon which will make it a lot clearer, and once you see it you'll see it fairly frequently in Ruby programs.

It's no exaggeration to say you'll find block functions everywhere in Ruby, and this is just another way they're used.

### Add a Little Logging

Suppose that, as the book mentions, we had a way to store and perform actions against a document like so:

```ruby
class SomeApplication
  def do_something
    doc = Document.load("resume.txt")
    
    # Do something interesting with the document
    
    doc.save
  end
end
```

Chances are in a production app we'd want some sort of logging so we'd be able to tell what's happening, as well as debugger information for development. It might look something like this, which may look familiar to you from other languages:

```ruby
class SomeApplication
  def initialize(logger)
    @logger = logger
  end
  
  def do_something
    begin
      @logger.debug "Starting Document load"
      @doc = Document.load("resume.txt")
      @logger.debug "Completed Document load"
    rescue
      @logger.error "Load failed!"
    end
    
    # Do something interesting with the document
    
    begin
      @logger.debug "Starting Document save"
      @doc.save
      @logger.debug "Completed Document save"
    rescue
      @logger.error "Save failed!"
      raise
    end
  end
end
```

But as the book mentions we're only really doing two things with a lot of logging around them. Every action is going to add more and more, and it could become difficult to manage. Going with previous parts of the book we might be tempted to pull things out into named methods to simplify a bit:

```ruby
class SomeApplication
  def initialize(logger)
    @logger = logger
  end
  
  def do_something
    @doc = load_with_logging("resume.txt")
    
    # Do something interesting with the document
    
    save_with_logging(@doc)
  end
  
  def load_with_logging(file)
    @logger.debug "Starting Document load"
    doc = Document.load(file)
    @logger.debug "Completed Document load"
    
    doc
  rescue
    @logger.debug "Load failed!"
  end
  
  def save_with_logging(doc)
    @logger.debug "Starting Document save"
    doc.save
    @logger.debug "Completed Document save"
  rescue
    @logger.error "Save failed!"
    raise
  end
end
```

...but even that has its drawbacks and only really moves things around. What if there were a better way? Well in Ruby blocks give us a great way to clearly and concisely perform a series of actions around another one, like so:

```ruby
class SomeApplication
  def initialize(logger)
    @logger = logger
  end
  
  def do_something
    with_logging "load" do
      @doc = Document.load("resume.txt")
    end
    
    # Do something interesting with the document
    
    with_logging "save" do
      @doc.save
    end
  end
  
  def with_logging(description)
    @logger.debug "Starting #{description}"
    yield
    @logger.debug "Complete #{description}"
  rescue
    @logger.error "#{description} failed!"
  end
end
```

The new `with_logging` function allows us to call the original code within the block function, but also wraps the idea of logging around it. That lets us get rid of all the logging lines and cleans up our code quite a bit in the process. Even better is that we're only adding a few lines to get all that logging.

As the book mentions this isn't limited to the above code. Because we wrote it in a generic way we could very easily use it for something completely different:

```ruby
class SomeApplication
  def do_something_silly
    with_logging "Compute miles in a light year" do
      186_000 * 60 * 60 * 24 * 365
    end
  end
end
```

That's a lot of the power of block functions, and really functions in general, is we can express the idea of actions more succinctly and more generically than we might with classes. Can you imagine a `Loggable` module that you'd have to include and conform to an interface to work with? Perhaps in Java, but in Ruby we have a few more tricks to play

### When It Absolutely Must Happen

Are we limited to doing actions around something? Not really, we could even get before and after:

```ruby
def log_before(description)
  @logger.debug "Starting #{description}"
  yield
end

def log_after(description)
  yield
  @logger.debug "Done #{description}"
end
```

The general idea, as the book mentions, is that using blocks allows us to call back to the original code from anywhere inside the method. If you want a quick challenge try and create a method to time something that uses a block function and see where you get. Later in the book it does have an example of this.

### Setting Up Objects with an Initialization Block

One idiom in Ruby that can be interesting to see for the first few times is initialization blocks:

```ruby
class Document
  attr_accessor :title, :author, :content
  
  def initialize(title:, author:, content: "")
    @title = title
    @author = author
    @content = content
    
    yield self if block_given?
  end
end
```

Since we're yielding the original class using `self` we have full access to it inside the block:

```ruby
new_doc = Document.new(title: "US Constitution", author: "Madison") do |doc|
  doc.content << "We the people"
  doc.content << "In order to form a more perfect union"
  doc.content << "provide for the common defense"
end
```

Often times people will do this to allow more dynamic configuration of a class on initialization, but it also has a lovely side effect of wrapping it so anything happening inside the block stays in the block unless you happen to manipulate something outside of it.

### Dragging Your Scope along with the Block

The book has this habit of progressively explaining a concept through a series of logical steps, of which looking at any step in isolation may yield some weird code. If you find that happening keep reading and see where the book is going with it, as more often than not it _is_ going somewhere with this.

In this particular case the book introduces us to the idea of passing an object into a block function and yielding it back to the block:

```ruby
class SomeApplication
  def initialize(logger)
    @logger = logger
  end
  
  def do_something
    with_logging "load", nil do
      @doc = Document.load("resume.txt")
    end
    
    # Do something interesting with the document
    
    with_logging "save", @doc do |the_object|
      the_object.save
    end
  end
  
  def with_logging(description, the_object)
    @logger.debug "Starting #{description}"
    yield(the_object)
    @logger.debug "Complete #{description}"
  rescue
    @logger.error "#{description} failed!"
  end
end
```

As the book mentions it misses the point as any code outside the block is still visible inside the block, which is called closure. The opposite way? Outside can't see inside unless you mutate something on the outside.

The book goes on to mention there's nothing wrong with yielding an argument back to the block, in fact it's rather common as it demonstrates in this code example:

```ruby
def with_database_connection(connection_info)
  connection = Database.new(connection_info)
  yield connection
ensure
  connection.close
end
```

In these cases inside of the block function we're in a specific context, the context of a database connection. There are others in Ruby, like the context of an open file, web connection, or several other things.

### Carrying the Answers Back

Where blocks really get useful is when you start saving the return value of a block. Take this example code from the book:

```ruby
def do_something_silly
  with_logging "Compute miles in a light year" do
    186_000 * 60 * 60 * 24 * 365
  end
end
```

In this case not only are we executing around, but we're also returning the original value:

```ruby
def with_logging(description)
  @logger.debug "Starting #{description}"
  return_value = yield
  @logger.debug "Completed #{description}"
  
  return_value
rescue
  @logger.error "#{description} failed!"
  raise
end
```

The book itself doesn't go here, but a common usecase for this I have handy is timing:

```ruby
def timed(&block_function)
  start_time = Time.now
  return_value = block_function.call
	end_time = Time.now
  
  puts "Took #{end_time - start_time} to execute"
  return_value
end
```

...and I've gotten a lot of mileage out of it while doing rudimentary debugging. Granted flame graphs and profilers are more useful for heavy lifting, but sometimes I want something drop-dead simple instead and this scratches that itch very well.

### Staying Out of Trouble

The book mentions, as it often correctly does, that naming is important. Consider the following:

```ruby
execute_between_logging_statements "update" do
  employee.load
  employee.status = :retired
  employee.save
end
```

...as compared to a more generic version:

```ruby
with_logging "update" do
  employee.load
  employee.status = :retired
  employee.save
end
```

The latter is clearer and more immediately communicates the intent.

### In the Wild

Remember when the `yield self` bit and the database connection were mentioned earlier as one of a large number of examples in Ruby? `File` is one of those examples:

```ruby
# No access to the file

File.open("/etc/passwd") do |f|
  # Able to access the file
end

# File is closed
```

...as are CSV and several other core classes. It's a common idiom, and one to be familiar with.

Speaking of `yield self` a lot of gem files do the same:

```ruby
require_relative "lib/rake/version"

Gem::Specification.new do |s|
  s.name = "rake"
  s.version = Rake::VERSION
  s.authors = ["Hiroshi SHIBATA", "Eric Hodel", "Jim Weirich"]
  s.email = ["hsbt@ruby-lang.org", "drbrain@segment7.net", ""]

  s.summary = "Rake is a Make-like program implemented in Ruby"
  s.description = <<~DESCRIPTION
    Rake is a Make-like program implemented in Ruby. Tasks and dependencies are
    specified in standard Ruby syntax.
    # ...
  DESCRIPTION
  
  # More below
end
```

Do note this is an updated version from the one the book mentioned from Rake as it was at the time this article was written.

The other example the book uses is going to look very familiar to the above timing function:

```ruby
module ActiveRecord
  class Migration
    # Takes a message argument and outputs it as is.
    # A second boolean argument can be passed to specify whether to indent or not.
    def say(message, subitem = false)
      write "#{subitem ? "   ->" : "--"} #{message}"
    end

    # Outputs text along with how long it took to run its block.
    # If the block returns an integer it assumes it is the number of rows affected.
    def say_with_time(message)
      say(message)
      result = nil
      time_elapsed = ActiveSupport::Benchmark.realtime { result = yield }
      say "%.4fs" % time_elapsed, :subitem
      say("#{result} rows", :subitem) if result.is_a?(Integer)
      result
    end
  end
end
```

The `ActiveSupport::Benchmark.realtime { result = yield }` is doing just the same thing.

### Wrapping Up

Once you see it you can't unsee it. A lot of Ruby uses the idea of wrapping behavior using block functions, and frequently when writing libraries and utilities I'm going to be writing several of these types of methods myself. Whether that's timing, wrapping contexts, doing things before or after, or any number of other tasks this is going to be a frequent tool you use in Ruby.
