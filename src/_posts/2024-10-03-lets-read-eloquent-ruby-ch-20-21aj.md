---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 20 – Block Hooks"
series: "lets-read-eloquent-ruby"
date: "2024-10-03"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 20. Use Hooks to Keep Your Program Informed

So we're now into the metaprogramming chapters. The very short version of my opinion on it is that it's very powerful potentially, yes, but it's also capable of making your programs substantially harder to reason about for very little gain. When it's needed it's really useful, but as always use your discretion here.

### Waking Up to a New Subclass

The chapter starts in on the subject of hooks. What's a hook? Well a way to respond to something happening in your program like an event. One example the book leads with is `inherited` which is called whenever something inherits the class that defines it:

```ruby
class SimpleBaseClass
  def self.inherited(new_subclass)
    puts "Hey #{new_subclass} is now a subclass of #{self}!"
  end
end

class ChildClassOne < SimpleBaseClass
end
# STDOUT: Hey ChildClassOne is now a subclass of SimpleBaseClass!
```

The book brings up a good point here of what one might do with such a feature. The example case it gives is a registry of subclasses like multiple document file types (txt, yaml, xml, etc.)

To demonstrate this it gives us a few examples of subclasses before it gets into the implementation of the base class:

```ruby
class PlainTextReader < DocumentReader
  def self.can_read?(path)
    # Book - Regex and a potentially unclear operator. `#match?` tends
    # to be a clearer method here.
    /.*\.txt/ =~ path
    
    # Suggested - File provides the extname method which does a lot of
    # this work for us. Prefer to use this instead.
    File.extname(path) == '.txt'
  end
  
  def initialize(path)
    @path = path
  end
  
  def read(path)
    File.open(path) do |f|
      title = f.readline.chomp
      author = f.readline.chomp
      content = f.read.chomp
      
      Document.new(title:, author:, content:)
    end
  end
end
```

Looking at this code the book starts by pointing out the `can_read?` method which is used to determine if this class can handle a certain type of file. Personally I'd also be inclined to turn `.txt` into a constant and add a few more introspection methods about file types it supports, but that's a preference.

The book goes on to show us a few more example classes for YAML and XML:

```ruby
class YAMLReader < DocumentReader
  def self.can_read?(path)
    File.extname(path) == '.yaml'
  end
  
  def initialize(path)
    @path = path
  end
  
  def read(path)
    # Omitted
  end
end

class XMLReader < DocumentReader
  def self.can_read?(path)
    File.extname(path) == '.xml'
  end
  
  def initialize(path)
    @path = path
  end
  
  def read(path)
    # Omitted
  end
end
```

...and then gets into the underlying base class:

```ruby
class DocumentReader
  # When something inherits from this we want to "register" it
  def self.inherited(subclass)
    DocumentReader.reader_classes << subclass
  end
  
  class << self
    attr_reader :reader_class
  end
  
  @reader_classes = []
  
  def self.read(path)
    reader = reader_for(path)
    return nil unless reader
    
    reader.read(path)
  end
  
  def self.reader_for(path)
    reader_class = DocumentReader.reader_classes.find do |klass|
      klass.can_read?(path)
    end
    
    return reader_class.new(path) if reader_class
    nil
  end
  
  # One critical bit omitted, but stay tuned...
end
```

Notedly it's using a class instance variable to store all of these and uses that registry to determine how to load a file. Personally there are a few things in here that I'd look at doing:

```ruby
class DocumentReader
  # This allows us to key a Hash against the supported file
  # formats instead of having to use the `can_read?` method
  # which can get slow as we add more file types.
  def self.inherited(subclass)
    subclass::SUPPORTED_EXTENTIONS.each do |ext|
      @reader_classes[ext] = subclass
    end
  end
  
	@reader_classes = {}
  
  class << self
    attr_reader :reader_classes
  end
  
  # ...
  
  def self.reader_for(path)
    # By using a Hash key we can get rid of a full search here
    extension = File.extname(path)[1..-1] # trim the dot
    reader_class = DocumentReader.reader_classes[extension]
    
    return unless reader_class
    
    reader_class.new(path)
  end
end

class XMLReader < DocumentReader
  SUPPORTED_EXTENSIONS = ['xml']
end

class YAMLReader < DocumentReader
  SUPPORTED_EXTENSIONS = ['yaml', 'yml']
end

class PlainTextReader < DocumentReader
  SUPPORTED_EXTENSIONS = ['txt']
end
```

Of course this is only a start and a very brief one. More likely I'd look to leverage module nesting and asking the top-level module what its constants are (classes and modules are constants too.)

I'm always a bit wary on making these types of registries, but at the same time I'm also wary of having a manual list I have to remember to update in several places too. It all comes down to making a tactical investment in metaprogramming to make your program (perhaps paradoxically) more maintainable.

### Modules Want to be Heard Too

Modules also have hooks like `included` and `extended` for whenever a class does `include ModuleName`. The book gives us an example here:

```ruby
module WritingQuality
  def self.included(klass)
    puts "Hey, I've included in #{klass}"
  end
  
  def number_of_cliches
    # Body of method omitted
  end
end
```

The book points out that the most common use of the `included` hook is to additionally extend class methods into whatever includes a module. The book gives us this hypothetical example of having to do both:

```ruby
module UsefulInstanceMethods
  def an_instance_method; end
end

module UsefulClassMethods
  def a_class_method; end
end

class Host
  include UsefulInstanceMethods
  extend UsefulClassMethods
end
```

...but quickly follows with an example of what it meant here:

```ruby
module UsefulMethods
  module ClassMethods
    def a_class_method; end
  end
  
  def self.included(host_class)
    host_class.extend(ClassMethods)
  end
  
  def an_instance_method; end
end

class Host
  include UsefulMethods
end
```

While this is certainly useful use it sparingly because it can really make a mess if you're not careful trying to hunt down where certain behavior is coming from. Very frequently you'll see this for class-level macro methods like you might find in Rails:

```ruby
class SomeController < ApplicationController
  before_filter :something
end
```

...or for decorating methods like you might see with Sorbet:

```ruby
class SomethingElse
  extend T::Sig
  
  sig { params(a: Numeric, b: Numeric).returns(Numeric) }
  def adds(a:, b:)
    a + b
  end
end
```

How do those work? Well that's a subject for a much much longer post, but one I've already written elsewhere in [Decorating Ruby](/writing/2019/08/17/decorating-ruby-part-1-symbol-method-decoration-4po2/).

### Knowing When Your Time Is Up

Anyways, back to the book. Ruby has a hook for running things at the end of a program, `at_exit`:

```ruby
at_exit do
  puts "Have a nice day."
end
```

In fact we can have multiple:

```ruby
at_exit do
  puts "Goodbye"
end
```

Why use it? A lot of times you want to clean up loose connections or other running processes to make sure you're shutting down the application safely. If you want an example try hitting `ctrl + c` or `cmd + c` when RSpec is running and notice what it does. It doesn't immediately end, it tries to wrap things up instead, and only really exits if you try to end it again.

### ...And a Cast of Thousands

Ah yes, the old and infamous `set_trace_func`. The book mentions this variant:

```ruby
proc_object = proc do |event, file, line, id, binding, klass|
  puts "#{event} in #{file}/#{line} #{id} #{klass}"
end

set_trace_func(proc_object)

require 'date'
```

...but it has since been deprecated in favor of an OO version here:

```ruby
trace = TracePoint.new do |tp|
  puts "#{tp.event} in #{tp.path}/#{tp.lineno} #{tp.method_id} #{tp.defined_class}"
end

trace.enable do
  require 'date'
end
```

If you were to run this code you would see something like this (and a loooot more) pip up.

```ruby
b_call in (irb)/5
line in (irb)/6
call in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/36 require Kernel
line in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/37 require Kernel
c_call in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/37 discover_gems_on_require #<Class:Gem>
c_return in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/37 discover_gems_on_require #<Class:Gem>
line in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/39 require Kernel
c_call in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/39 synchronize Monitor
b_call in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/39 require Kernel
line in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/40 require Kernel
c_call in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/40 path #<Class:File>
c_return in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/40 path #<Class:File>
line in <internal:RUBY/GEMS/core_ext/kernel_require.rb>/42 require Kernel
```

`TracePoint` is far more useful when used in a limited context, and for debugging it can be unmatched in finding where particularly hard to trace metaprogramming has gone awry. There was even one case where I had used `TracePoint` recently to listen to every instance of opening a file with a certain path to see what part of an application was loading what I thought were dead fixture files somehow magically within the last month.

If you want to learn more about TracePoint there are some articles, including one I wrote a while back and should probably finish later: [Exploring TracePoint](/writing/2019/02/08/exploring-tracepoint-in-rubypart-oneexample-code/).

### Staying Out of Trouble

The book mentions that the key factor in using hooks safely is knowing how they work and whether or not they will be called. In the simple cases it's probably fine:

```ruby
class DocumentReader; end

class PlainTextReader < DocumentReader; end
class YAMLReader < DocumentReader; end
```

...but then more files might get involved:

```ruby
require "document_reader"

require "plaintext_reader"
require "xml_reader"
require "yaml_reader"
```

...and then subclasses of those, which you might or might not want to happen:

```ruby
class AsianDocumentReader < DocumentReader; end
class JapaneseDocumentReader < AsianDocumentReader; end
class ChineseDocumentReader < AsianDocumentReader; end
```

The book suggests fixing this by having that class never be able to read anything:

```ruby
class AsianDocumentReader < DocumentReader
  def self.can_read?(path)
    false
  end
end
```

The other issue is around `at_exit` if the program crashes, there's no guarantee that it happens to run. It's best effort, same with how RSpec warns us before it actually exits on an `at_exit` but we can still kill the program.

### In the Wild

The book uses the example of `Test::Unit` :

```ruby
require "test/unit"

class SimpleTest < Test::Unit::TestCase
  def test_addition
    assert_equal 2, 1 + 1
  end
end
```

How is it that given we run that script:

```ruby
ruby simple_test.rb
```

...that we get back a full test run?

```ruby
Loaded suite simple_test
Started
.
Finished in 0.000247 seconds.
  
1 tests, 1 assertions, 0 failures, 0 errors
```

That's because it (and RSpec and other similar tools) use `at_exit` to kick things off:

```ruby
at_exit do
  unless $! || Test::Unit.run?
    exit Test::Unit::AutoRunner.run
  end
end
```

It starts by checking if there are any errors using `$!`, though you should really use the english variant `$ERROR_INFO` instead as it more clearly describes what's going on ([and read about other globals here](https://idiosyncratic-ruby.com/9-globalization.html).)

### Wrapping Up

This chapter covered a lot of hooks in Ruby, and there are even more still out there to explore. The trick is to use them sparingly and where it makes sense, rather than using them for everything. Chances are high you do not need a class registry early on, and a lot of times you can use block wrappers instead of decoration to get the effects you're after.

That said, when it's needed it's really useful. Knowing where that line is is an art form, and not one I am particularly well versed in either. Just remember the golden rule: Make sure your code is understandable.
