---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 14 – Class Instance Variables"
series: "lets-read-eloquent-ruby"
date: "2024-09-12"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 14. (Don't) Use Class Instance Variables

From the last article:

> Speaking of, next up we have class instance variables, which admittedly I am very much not a fan of for the same reasons I just mentioned, so we'll see how that article goes.

This article does have something similar to say about class variables here:

> Sadly, we will discover that class variables behave in some unfortunate ways, making them less of a solution and more of a problem.

...which I agree with, but even class instance variables I would advocate for using constants in almost every case instead, or failing that define an instance of a wrapper at the top level that can be passed downwards into your program later.

That said, I will still cover the content in this chapter as-is with only occasional quips about alternatives.

### A Quick Review of Class Variables

The book starts out with an example of using class variables to capture a default paper size for a document, and in the US that'd be an A4 or letter size:

```ruby
class Document
  @@default_paper_size = :a4
  
  def self.default_paper_size
    @@default_paper_size
  end
  
  def self.default_paper_size=(new_size)
    @@default_paper_size = new_size
  end
  
  attr_accessor :title, :author, :content
  attr_accessor :paper_size
  
  def initialize(title:, author:, content:)
    @title = title
    @author = author
    @content = content
    @paper_size = @@default_paper_size
  end
end
```

This variable isn't visible to anything except for the instance of the class, so initialize can see it but external code cannot. The book says this appears to be a good solution, but has some issues.

Quickly in the interim though personally I would write this as:

```ruby
class Document
  DEFAULT_PAPER_SIZE = :a4
  
  # Use the constant as a default argument, allowing individual
  # overrides.
  def initialize(title:, author:, content:, paper_size: DEFAULT_PAPER_SIZE)
    # ...
  end
end
```

...because allowing runtime to set these can have other unintended side effects. If you really need that look into feature flags instead, or configuration management. In general everything should be private or read-only unless you have a good reason to do otherwise.

### Wandering Variables

The book starts into an example of what's wrong with class variables next. Class variables are associated with a class, but which class?

In the book it starts with the current class and goes up the tree from there to superclasses to see if it finds that class variable. If it's not found you get a name error. Sounds reasonable, but it sets up an example to show a flaw with this:

```ruby
class Resume < Document
  @@default_font = :arial
  
  def self.default_font
    @@default_font
  end
  
  def self.default_font=(font)
    @@default_font = font
  end
  
  attr_accessor :font
  
  def initialize
    @font = @@default_font
  end
end
```

When `@@default_font = :arial` gets run it'll search up the chain and find no other class defines it, including `Document`, so it's now set on `Resume`. If there happened to be a second class though:

```ruby
class Presentation < Document
  @@default_font = :nimbus
  
  def self.default_font
    @@default_font
  end
  
  def self.default_font=(font)
    @@default_font = font
  end
  
  attr_accessor :font
  
  def initialize
    @font = @@default_font
  end
end
```

...Ruby will look at `Presentation`, then `Document` to see if `@@default_font` is defined yet. If not it now belongs to `Presentation`. All great, but if `Document` decided to do this:

```ruby
class Document
  @@default_font = :times
end
```

..then we have an issue. `Document` needs to be loaded first so `Document` sets `@@default_font`, so when `Presentation` and `Resume` start in they're going to find that `@@default_font` was defined on `Document` and it sets _on the `Document`_.

That means depending on the order you load these classes in the default font might be `:arial` or it might be `:nimbus`. That's a problem.

(Also constants don't have that problem.)

The other problem is I believe the default fonts nowadays are Calibri for PowerPoint and Helvetica Neue for Keynote, but that's being a bit pedantic.

### Getting Control of the Data in Your Class

The solution the book presents to this problem is to use class instance variables instead:

```ruby
class Document
  @default_font = :times
  
  def self.default_font
    @default_font
  end
  
  def self.default_font=(font)
    @default_font = font
  end
end

# Don't you dare
Document.default_font = :comic_sans
```

To use this in the initializer you'd need to do the following:

```ruby
def initialize(title:, author:, content:)
  @title = title
  @author = author
  @content = content
  @font = Document.default_font
end
```

The only thing special about it is that the instance variable is on the class instead. Granted though all classes are technically instances of `Class`, so the math checks out.

### Class Instance Variables and Subclasses

> To paraphrase my mother, it’s all fun and games until someone starts writing subclasses

The book asks if class instance variables behave better than class variables, and the short answer is yes:

```ruby
class Presentation < Document
  # We're fancy now
  @default_font = :helvetica_neue

  class << self
    attr_accessor :default_font
  end
  
  def initialize(title:, author:, content:)
    @title = title
    @author = author
    @content = content
    @font = Presentation.default_font
  end
end
```

### In the Wild

Interestingly the book uses URI as an example of using class variables with some success:

```ruby
class HTTP; end
@@schemes['HTTP'] = HTTP
```

...but since then they've gone with a registry system using constants instead ([source](https://github.com/ruby/uri/blob/v0-13/lib/uri/http.rb)):

```ruby
module URI
  class HTTP < Generic; end
  
  register_scheme 'HTTP', HTTP
end
```

...which is defined as ([source](https://github.com/ruby/uri/blob/master/lib/uri/common.rb#L101)):

```ruby
module URI
  module Schemes; end
  private_constant :Schemes
  
  # Registers the given +klass+ as the class to be instantiated
  # when parsing a \URI with the given +scheme+:
  #
  #   URI.register_scheme('MS_SEARCH', URI::Generic) # => URI::Generic
  #   URI.scheme_list['MS_SEARCH']                   # => URI::Generic
  #
  # Note that after calling String#upcase on +scheme+, it must be a valid
  # constant name.
  def self.register_scheme(scheme, klass)
    Schemes.const_set(scheme.to_s.upcase, klass)
  end
  
  # Returns a hash of the defined schemes:
  #
  #   URI.scheme_list
  #   # =>
  #   {"MAILTO"=>URI::MailTo,
  #    "LDAPS"=>URI::LDAPS,
  #    "WS"=>URI::WS,
  #    "HTTP"=>URI::HTTP,
  #    "HTTPS"=>URI::HTTPS,
  #    "LDAP"=>URI::LDAP,
  #    "FILE"=>URI::File,
  #    "FTP"=>URI::FTP}
  #
  # Related: URI.register_scheme.
  def self.scheme_list
    Schemes.constants.map { |name|
      [name.to_s.upcase, Schemes.const_get(name)]
    }.to_h
  end
end
```

### Staying Out of Trouble

Use constants or feature flags, or dependency injection failing that. It'll be far easier to test and reason about later.

### Wrap Up

Ruby has a few harsh edges. This is one of them, and in previous and future articles I'm not particularly shy about mentioning others from my point of view. Class variables and class instance variables occupy a special place in that I find myself actively avoiding and disliking them, and that I have rarely if ever seen them in the wild even across 10M+ lines of code Rails apps.

If I do see them? Well there's always room for a few more constants.
