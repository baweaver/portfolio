---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 19 – Block Actions"
series: "lets-read-eloquent-ruby"
date: "2024-09-27"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 19. Save Blocks to Execute Later

This chapter wraps up the book's tour into block functions with the idea that we can save blocks to be used later. That may sound abstract, as the previous concepts also did, but you'll find that it's very common to see around Ruby especially for things like hooks.

### Explicit Blocks

The book starts by mentioning that we can also have explicit blocks by using an argument prefixed with an `&`:

```ruby
def run_that_block(&block_function)
  puts "About to run the block"
  block_function.call
  puts "Done running the block"
end
```

This may feel familiar to other `&` prefixes in Ruby like `array.select(&:even?)` because it's a similar concept meaning "convert whatever is after me to a proc/function."

As mentioned in earlier chapter reviews the idea of `block_given?` is an implicit check for the presence of a block, but you can just as easily check whether or not one was given in the explicit context like so:

```ruby
block_function.call if block_function
```

The book mentions that some Ruby programmers, myself and the author included, have a very strong preference towards this explicit style of block functions. While they're most certainly clearer for non-Ruby programmers to understand, and also for folks who've been around the Gemfile a few times, they also have a feature that implicit blocks don't really have*, and that's the ability to save a reference to the block.

> **Note**: You used to be able to capture implicit blocks in a very confusing way using `Proc.new` but that was rightfully removed in Ruby 3.x ([bug tracker ticket](https://bugs.ruby-lang.org/issues/10499)), so this is more of a "technically" depending on the version of Ruby, but since 2.x has been end of life for a while it's reasonable to say you can't do it.

So why would you want to save a block function? Because you don't always want to do something right away, but you might know what you want to do right away.

### The Call Back Problem

Consider the type of code you might write in a language like Java to add listeners for things like saving or loading files for our `Document` class. We'd probably make more classes for it, no? After all if you have a hammer everything starts looking like an `AbstractSingletonProxyFactoryNailMapper` ([you think I'm joking?](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/aop/framework/AbstractSingletonProxyFactoryBean.html)):

```ruby
class DocumentSaveListener
  def on_save(doc, path)
    puts "Hey, I've been saved!"
  end
end

class DocumentLoadListener
  def on_load(doc, path)
    puts "Hey, I've been loaded!"
  end
end
```

...and if we were to implement that in our `Document` class it might look like this:

```ruby
class Document
  attr_accessor :load_listener
  attr_Accessor :save_listener
  
  def load(path)
    @content = File.read(path)
    load_listener.on_load(self, path) if load_listener
  end
  
  def save(path)
    File.open(path, 'w') { |f| f.print(@contents) }
    save_listener.on_save(self, path) if save_listener
  end
end
```

...and the call itself might look something like this:

```ruby
doc = Document.new(title: "Example", author: "Russ", content: "It was a dark...")
doc.load_listener = DocumentLoadListener.new
doc.save_listener = DocumentSaveListener.new

doc.load("example.txt")
# STDOUT: Hey, I've been loaded!
doc.save("example.txt")
# STDOUT: Hey, I've been saved!
```

It all feels pretty excessive for what should be a pretty simple action, no? We don't care about objects in these cases, we care about actions, and thankfully Ruby has inherited some ideas from Functional programming that allow us to work with actions (or rather functions) instead of just objects.

Now granted, as the book mentions, maybe you _want_ some of the extra weight an object provides, or the separation it affords. Remember everything is about tradeoffs and making the right decisions for your code where it's currently at.

### Banking Blocks

If, instead, we used block functions to capture what we want to do as a result of saving or loading a file it might look a little bit like this:

```ruby
class Document
  def on_save(&block_function)
    @save_listener = block_function
  end
  
  def on_load(&block_function)
    @load_listener = block_function
  end
  
  def load(path)
    @content = File.read(path)
    @load_listener.call(self, path) if @load_listener
  end
  
  def save(path)
    File.open(path, 'w') { |f| f.print(@contents) }
    @save_listener.call(self, path) if @save_listener
  end
end
```

We capture two functions for what we want to do on a file being saved and on a file being loaded in instance variables, and when we actually save or load we call those functions we saved earlier.

The way we use it might look like this:

```ruby
my_doc = Document.new(title: "Block based example", author: "Russ", content: "...")

my_doc.on_load do |doc|
  puts "Hey, I've been loaded!"
end

my_doc.on_save do |doc|
  puts "Hey, I've been saved!"
end
```

By doing so we no longer need extra objects, just a few functions and a lightweight way to save them. This allows us to describe actions we want to take eventually, rather than right now, and to do so in a minimal way that can be right in line with our code. It's also a good deal more flexible as we can change what we put in those functions wherever it happens to be without changing an underlying class or any other implementations.

### Saving Code Blocks for Lazy Initialization

The book goes into another example. Let's say we wanted to lazily load the content of a document, only when we actually need it. Perhaps we could use caching like we've seen in the past:

```ruby
class ArchivalDocument
  attr_reader :title, :author
  
  def initialize(title:, author:, path:)
    @title = title
    @author = author
    @path = path
  end
  
  def content
    @content ||= File.read(@path)
  end
end
```

...or maybe we could use block functions instead to make it more generic. Suppose that we wanted to get that content from HTTP, a socket, FTP, SSH, or who knows what else. We could make a bunch of subclasses to handle each of them, or we could use block functions:

```ruby
class BlockBasedArchivalDocument
  attr_reader :title, :author
  
  def initialize(title:, author:, &block_function)
    @title = title
    @author = author
    @initializer_block = block_function
  end
  
  def content
    if @initializer_block
      @content = @initializer_block.call
      @initializer_block = nil
    end
    
    @content
  end
end
```

We've now abstracted out the idea of how we load content, and instead of the class defining it the class lets us define it at call-time to be whatever in the world we want. The book even gives us a few examples of this:

```ruby
file_doc = BlockBasedArchivalDocument.new(title: "File", author: "Russ") do
  File.read("some_text.txt")
end

google_doc = BlockBasedArchivalDocument.new(title: "HTTP", author: "Russ") do
  Net::HTTP.get_response("www.google.com", "/index.html").body
end

boring_doc = BlockBasedArchivalDocument.new(title: "Silly", author: "Russ") do
  "Ya" * 100
end
```

Unlike the previous chapters where we used a block function in the initializer this time we're saving it for later. That's the nice thing about a proc is we can run them whenever we want to, on our own terms.

### Instant Block Objects

Remember, everything in Ruby is an object, and functions are no exception. That means we can save them to a variable even without using blocks. In the book we're given this example of some default listeners which define a few lambda functions inline:

```ruby
class Document
  DEFAULT_LOAD_LISTENER = -> doc, path do
    puts "Loaded: #{path}"
  end
  
  DEFAULT_SAVE_LISTENER = -> doc, path do
    puts "Saved: #{path}"
  end
  
  attr_accessor :title, :author, :content
  
  def initialize(title:, author:, content: "")
    @title = title
    @author = author
    @content = content
    
    @load_listener = DEFAULT_LOAD_LISTENER
    @save_listener = DEFAULT_SAVE_LISTENER
  end
end
```

The book stops here, but the code you're likely to see more in the wild might look a bit more like this:

```ruby
class Document
  DEFAULT_LOAD_LISTENER = -> doc, path do
    puts "Loaded: #{path}"
  end
  
  DEFAULT_SAVE_LISTENER = -> doc, path do
    puts "Saved: #{path}"
  end
  
  attr_accessor :title, :author, :content
  
  def initialize(
    title:,
    author:,
    content: "",
    load_listener: DEFAULT_LOAD_LISTENR,
    save_listener: DEFAULT_SAVE_LISTENER
  )
    @title = title
    @author = author
    @content = content
    
    @load_listener = load_listener
    @save_listener = save_listener
  end
  
  def on_save(&save_action)
    @save_listener = save_action
  end
  
  def on_load(&load_action)
    @load_listener = load_action
  end
end
```

It's a very common idiom nowadays to save a default initialization value in a constant, and that doesn't just apply to functions either. Personally I've done it a lot with other types of arguments too. This gives us the option of flexibility, but the nicety of having something to fall back on that's a reasonable default.

### Staying Out of Trouble

The book mentions that Proc and lambda functions are slightly different:

```ruby
from_proc_new = Proc.new { puts "hello from a block" }
```

The short version is that lambdas are very strict about their argument arity (how many arguments they take) and Procs are not. In most every case I'm going to prefer a lambda because I prefer explicit. If you'd like a more thorough dive into this I have a post on "[Understanding Ruby: Blocks, Procs, and Lambdas](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/)" that might be an interesting read.

The other problem we might find is that blocks _remember_ the context around wherever they happened to be created:

```ruby
def some_method(doc)
  big_array = Array.new(10_000_000)
  
  # Do something with big array
  
  doc.on_load do |d|
    puts "Hey, I've been loaded!"
  end
end
```

...which means that that ten million item `Array` will remain in memory because of that block function, which may not be what we want at all.

We can fix this by clearing the object first if we don't want that behavior:

```ruby
def some_method(doc)
  big_array = Array.new(10_000_000)
  
  # Do something with big array
  
  # And then get rid of it:
  big_array = nil
  
  doc.on_load do |d|
    puts "Hey, I've been loaded!"
  end
end
```

That said, closures (remembering context) are really useful in general as a concept, but that's beyond the scope of this chapter and this book.

### In the Wild

RSpec uses saved blocks frequently. If you've ever worked in RSpec you've used a ton of them already:

```ruby
it "knows how many words it contains" do
  doc = Document.new(title: "Example", author: "Russ", content: "Hello world")
  expect(doc.word_count).to eq(2)
end
```

...or perhaps in Rails you want to store an action to be taken before any controller action:

```ruby
class DocumentController < ActionController::Base
  before_filter do |controller|
    # Do something before each action
  end
end
```

...or perhaps also in Rails you want something to happen after you destroy a record:

```ruby
class DocumentVersion < ActiveRecord::Base
  after_destroy do |doc_version|
    # My Document is gone!
  end
end
```

But the most common one that's not mentioned in the book? ActiveRecord scopes are lambdas:

```ruby
class Document < ActiveRecord::Base
  scope :archived, -> { where(status: "archived") }
  scope :published, -> { where(status: "published") }
end
```

Really a lot of "macro methods" (methods called at the top level of a class) use block functions heavily. The book has a few more examples, but you can find them everywhere in any active Ruby codebase, especially a Rails one.

### Wrapping Up

That wraps up the chapters on block functions, and up next we start diving into the magical world of metaprogramming.

If you really want to get into what block functions can do I would definitely encourage giving Haskell or another functional language a test drive to get a feel for how they work with functions. Some of those ideas translate well to Ruby, others not so much, but they're still interesting to learn.
