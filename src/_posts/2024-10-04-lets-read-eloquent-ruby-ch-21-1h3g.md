---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 21 – Method Missing"
series: "lets-read-eloquent-ruby"
date: "2024-10-04"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 21. Use method_missing for Flexible Error Handling

What exactly happens when Ruby doesn't find the method it's looking for? Well it goes hunting for that method of course, but it has to go all the way up its inheritance chain to try and find it first before it then falls back to the current class and starts asking if anyone knows how to handle a missing method using `method_missing`.

If that sounds slow that's because it is, and one must be careful when using this feature in Ruby. There are certainly ways around this which make it less of an issue such as dynamically creating what the method should have been, had it existed, but it's always going to be a bit slower than other implementations. We'll get into some more alternatives later on this one, but `method_missing` is still a useful tool to know.

The number one rule when using it though is to make sure to limit what it will actually work with. Define a narrow set of "valid mistakes" to prevent it from catching too many things.

### Meeting Those Missing Methods

The book starts in with this example in which a user of the `Document` class happens to accidentally call `text` instead of the correct `content` method:

```ruby
# Error: the method is content, not text!

doc = Document.new(title: "Titanic", author: "Cameron", content: "Sail, crash, sink")
puts "The text is #{doc.text}"
```

The book then tells us what actually happens. The short version is we get an error, certainly, but how do we get there? As mentioned earlier Ruby is going to go looking for that method in the entire inheritance chain up to `BasicObject` and once it does that it's going to go for round two looking for anyone who's been kind enough to implement `method_missing` to tell it what to do next. If it doesn't find one? Well then there's your error.

We're given this example class to experiment with that implements `method_missing`:

```ruby
class RepeatBackToMe
  def method_missing(method_name, *args)
    puts "Hey, you just called the #{method_name} method"
    puts "With these arguments: #{args.join(' ')}"
    puts "But there ain't no such method"
  end
end
```

...as well as a few examples of how that might work:

```ruby
repeat = RepeatBackToMe.new

repeat.hello(1, 2, 3)
# STDOUT: Hey, you just called the hello method
# STDOUT: With these arguments: 1, 2, 3
# STDOUT: But there ain't no such method

repeat.good_bye("for", "now")
# STDOUT: Hey, you just called the good_bye method
# STDOUT: With these arguments: "for", "now"
# STDOUT: But there ain't no such method
```

We get access to the method name as well as the arguments, and in this case the book uses those values to output some log messages to `STDOUT`. Do be careful though, because this might be masking errors in production, so we'd likely want to raise a `NotImplementedError` or similar exception after the logs to trigger any monitoring platforms we might have that something is amiss.

> **Note**: As mentioned before the book explicitly uses simple examples for the sake of space and time. I point these out not to say the book isn't covering things, but to further your intuition as a reader of things to watch out for out in the wide world. If you're especially pedantic you could probably pick apart my counter examples as well.

### Handling Document Errors

Now we're back to our classic `Document` class again, and we have another variant of the above `method_missing` but with a minor change of using HEREDOCs instead of `%Q` as that tends to be more common out in the wild these days:

```ruby
class Document
  def method_missing(method_name, *args)
    raise <<~ERROR
    	You tried to call the method #{method_name}
      on an instance of Document. There is no such method
    ERROR
  end
end
```

The book also mentions that we could potentially append (the `a` flag for `File` is append mode) messages to a log file as well in the background:

```ruby
class Document
  def method_missing(method_name, *args)
    raise <<~ERROR
    	You tried to call the method #{method_name}
      on an instance of Document. There is no such method
    ERROR
    
    File.open("document.error", "a") do |f|
      f.puts "Bad method called: #{method_name}"
      f.puts "with #{args.size} arguments"
    end
  end
end
```

...though in the wild you're probably going to use this to send messages to a logger or other service.

What's interesting is that the book mentions something that modern day Rubyists might find eerily familiar:

```ruby
require "text"

class Document
  include Text
  
  def method_missing(missing, *args)
    candidates = methods_that_sound_like(missing.to_s)
    
    message = "You called an undefined method: #{missing}"
    
    unless candidates.empty?
      message += "\nDid you mean #{candidates.join(' or ')}?"
    end
    
    raise NoMethodError.new(message)
  end
  
  def methods_that_sound_like(name)
    missing_soundex = Soundex.soundex(name.to_s)
    
    public_methods.sort.select do |existing|
      existing_soundex = Soundex.soundex(existing.to_s)
      missing_soundex == existing_soundex
    end
  end
end
```

...which you might recognize as an earlier variant of the "[Did You Mean](https://github.com/ruby/did_you_mean)" gem:

```ruby
methosd
# => NameError: undefined local variable or method 'methosd' for main:Object
#    Did you mean?  methods
#                   method
```

The implementation instead uses a "string distance" algorithm called Levenshtein distance and guess where the implementation comes from? ([source](https://github.com/ruby/did_you_mean/blob/94c7e8c169a1be43998d92e91b9c9f2dcd285555/lib/did_you_mean/levenshtein.rb))

```ruby
module DidYouMean
  module Levenshtein # :nodoc:
    # This code is based directly on the Text gem implementation
    # Copyright (c) 2006-2013 Paul Battley, Michael Neumann, Tim Fletcher.
  end
end
```

Yep, the same Text gem that the above code example references. Small world ain't it?

This feature was shipped with Ruby 2.3.x and has been with us for some time now, but also _right after_ this book was published by a few years.

### Coping with Constants

What happens if you're missing a constant instead of a method? Well as the book mentions that's where we get `const_missing`:

```ruby
class Document
  def self.const_missing(const_name)
    raise <<~ERROR
    	You tried to reference the constant #{const_name}
    	There is no such constant in the Document class.
    ERROR
  end
end
```

As the book mentions it needs to be a class method, so do keep that in mind.

What's it used for? Autoloaders pre-Zeitwerk in Rails used it to lazy load constants. If you really want a deep dive into that I would highly recommend [Xavier Noria's talk on Zeitwerk](https://www.youtube.com/watch?v=DzyGdOd_6-Y) where he takes a historical journey to how we got here.

### In the Wild

In the past Rails tended to use `method_missing` heavily, and in some cases it [still does use it](https://github.com/search?q=repo%3Arails%2Frails%20method_missing&type=code), but I want to call attention to a particular pattern I've seen take over a lot of the early usage of `method_missing` and that would be keyword arguments. In older Rails you might see something like this:

```ruby
Model.find_by_name_and_version("Bob", 42.1)
```

...which used `method_missing` to see there was a `find_by` prefix and then use the `name` and `version` afterwards to decide what to search on. Back in the day that was awesome for the type of flexibility it gave us, I remember seeing it back in the late 2000s and thinking it was magic, but since then code has shifted towards something more like this:

```ruby
Model.find_by(name: "Bob", version: 42.1)
```

That simple change to use keywords made finder methods much faster, but also gave us a very consistent and findable (heh) syntax that new programmers would not need to scour docs to find. If there's one big blindspot for dynamically defined methods it's that finding docs or implementations for them can be painful.

The other day, not even a month ago, I had to rifle through a ton of Devise documentation to find out where in the world it was defining some auth methods when I was trying to figure out how to properly stub them in tests.

### Staying Out of Trouble

As mentioned above, and as confirmed by the book, use sparingly. As with any form of powerful magic or tool it's also very dangerous if you use it incorrectly. It intercepts _all_ wrong methods, so you want to be careful only to intercept exactly the type of wrong you want to do something about, or you'll find some rather unpleasant oncall debugging sessions in your future.

It's still useful in a few case, but often times the explicit and slightly longer-to-write ways are better to ensure programs behave predictably. Rails does have some interesting examples here, so if you're curious I would read into those.

### Wrapping Up

The book wraps up by saying that while this chapter covered error handling as a focus the next one focuses on the much more common usage which I was hinting at earlier: Delegation and dynamic definitions.
