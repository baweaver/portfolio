---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 15 – Module Namespaces"
series: "lets-read-eloquent-ruby"
date: "2024-09-12"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 15. Use Modules as Name Spaces

Eventually you're going to need to organize your Ruby code. Sure, we have classes that represent objects, but how are they grouped? What do they belong to? Which team owns them? That's part of the reason why namespaces are such a popular concept, and in Ruby we have modules for that.

### A Place for Your Stuff, with a Name

A module is a container, or a namespace, for Ruby code. The book demonstrates this with an example:

```ruby
module Rendering
  class Font
    attr_accessor :name, :weight, :size
    
    def initialize(name:, weight: :normal, size: 10)
      @name = name
      @weight = weight
      @size = size
    end
  end
  
  class PaperSize
    attr_accessor :name, :width, :height
    
    def initialize(name: "US Letter", width: 8.5, height: 11.0)
      @name = name
      @width = width
      @height = height
    end
  end
end
```

To access them we might use `Rendering::Font` or `Rendering::PaperSize`. Perhaps we even have some constants in there too:

```ruby
module Rendering
  # Classes above here
  
  DEFAULT_FONT = Font.new(name: 'default')
  DEFAULT_PAPER_SIZE = PaperSize.new
end

Rendering::DEFAULT_FONT
```

...though personally I might do this to prevent the need for worrying about load ordering:

```ruby
module Rendering
  def self.default_font = Font.new(name: 'default')
  def self.default_paper_size = PaperSize.new
end
```

...otherwise the classes need to exist first. In this case they just need to be defined before those methods are called, probably at runtime.

You can nest them as deeply as you want:

```ruby
module WordProcessor
  module Rendering
    class Font; end
  end
end
```

...and sometimes that can go on for quite a while for particularly large programs. Personally though if I find that I need to have a long prefix like `OrgName::TeamName::ConceptName::ClassName` littered all over that means that I'm using code I probably shouldn't and creating dependencies which are going to be real annoying to pay down later.

### A Home for Those Utility Methods

Pretty frequently you'll also see modules used as wrappers for several little utility methods:

```ruby
module WordProcessor
  def self.points_to_inches(points) = points / 72.0
  def self.inches_to_points(inches) = inches * 72.0
end
    
an_inch_full_of_points = WordProcessor.inches_to_points(1.0)
```

...though if I end up with enough of those I tend to use this little shortcut:

```ruby
module WordProcessor
  extend self
  
  def points_to_inches(points) = points / 72.0
  def inches_to_points(inches) = inches * 72.0
end
    
an_inch_full_of_points = WordProcessor.inches_to_points(1.0)
  
```

Handy eh? Just don't mix and match `self` methods in there unless you want a bad time.

### Building Modules a Little at a Time

Nothing in Ruby is ever really finished. Every class and module is open, even more so for a particularly determined programmer, and that's not always a good thing like when people monkey patch MySQL drivers.

Anyways, what that means in a more practical sense like the book mentions is that we can have things in different files like so:

```ruby
# rendering/font.rb
module Rendering
  class Font; end
  
  DEFAULT_FONT = Font.new('default')
end

# rendering/paper_size.rb
module Rendering
  class PaperSize; end
  
  DEFAULT_PAPER_SIZE = PaperSize.new
end
```

...and then require the both of them later:

```ruby
require 'rendering/font'
require 'rendering/paper_size'
```

Or, in the more modern days of Ruby, just use Zeitwerk:

https://github.com/fxn/zeitwerk?tab=readme-ov-file#synopsis

### Treat Modules Like the Objects That They Are

Remember how everything was an object? Modules are no different, we can assign them to variables just the same as anything else:

```ruby
the_module = Rendering
times_new_roman_font = the_module::Font.new("times-new-roman")
```

Let's take these examples from the book of four classes with two very similar groups of behavior. One to handle a printer queue and one to handle the printer itself:

```ruby
class TonsOTonerPrintQueue
  def submit(print_job)
    # Send the job off for printing to this laser printer
  end
  
  def cancel(print_job)
    # Stop the print job on this laser printer
  end
end

class TonsOTonerAdministration
  def power_off
    # Turn this laser printer off
  end
  
  def start_self_test
    # Test this laser printer
  end
end

class OceansOfInkPrintQueue
  def submit(print_job)
    # Send the job off for printing to this ink jet printer
  end
  
  def cancel(print_job)
    # Stop the print job on this ink jet printer
  end
end

class OceansOfInkAdministration
  def power_off
    # Turn this ink jet printer off
  end
  
  def start_self_test
    # Test this ink jet printer
  end
end
```

Modules would allow us to group these two concepts into a similar interface we could easily switch between:

```ruby
module TonsOToner
  class PrintQueue
    def submit(print_job)
      # Send the job off for printing to this laser printer
    end

    def cancel(print_job)
      # Stop the print job on this laser printer
    end
  end

  class Administration
    def power_off
      # Turn this laser printer off
    end

    def start_self_test
      # Test this laser printer
    end
  end
end

module OceansOfInk
	class PrintQueue
    def submit(print_job)
      # Send the job off for printing to this ink jet printer
    end

    def cancel(print_job)
      # Stop the print job on this ink jet printer
    end
  end

  class Administration
    def power_off
      # Turn this ink jet printer off
    end

    def start_self_test
      # Test this ink jet printer
    end
  end
end
```

...and then just like that, as the book mentions, you could switch between the two implementations:

```ruby
print_module = if use_laser_printer
	TonsOToner
else
  OceansOfInk
end

admin = print_module::Administration.new
```

### Staying Out of Trouble

One of the most common errors I see in Ruby, personally, is mixing up class and instance behaviors. In the book it mentions wrappers for methods like so:

```ruby
module WordProcessor
  def self.points_to_inches(points) = points / 72.0
end
```

...but if you did this instead it would not work because it's an instance method:

```ruby
module WordProcessor
  def points_to_inches(points) = points / 72.0
end
```

We'll cover those cases more in the next chapter, because they do have a use, but you should be aware of the difference.

The other danger is nesting. Sure, we have two, it's not that bad:

```ruby
module Rendering
  class Font
```

Then another comes along as a sub-categorization that makes sense:

```ruby
module Rendering
  module GlyphSet
    class Font
```

...and eventually you could even end up with something like this:

```ruby
module Subsystem
  module Output
    module Rendering
      module GlyphSet
        class Font
```

So now every implementer gets to do this:

```ruby
Subsystem::Output::Rendering::GlyphSet::Font
```

...which is fairly excessive. For each nesting ask if it's really actually necessary, and if it provides clarity.

Personally I find that if the nesting exceeds 3-4 levels it means that I probably have a few applications hiding in the same repository and some breaking up needs to happen, assuming those modules all make sense and people aren't getting carried away.

### In the Wild

The book goes into DataMapper, but I might instead go into some of the larger Rails apps I've worked with in the past (10M+ LoC, 1M+ LoC, and 3M+ LoC respectively.) Two of them implement [Packwerk](https://github.com/Shopify/packwerk) to namespace things, and frequently something to the order of:

```ruby
Layer::Owner::DomainArea::SubArea
```

Where:

* **Layer**: What layer of the app it functions at, like Platform or Application or Library.
* **Owner**: Who owns this area, typically an organization instead of a team because team is too granular and teams shift a lot more often than orgs do.
* **Domain Area**: What functionality is in here? Is it for Payroll? Patients? Something else?
* **Sub Area**: Classes or any other grouping. If it goes deeper than this chances are it needs to be broken down more.

But the thing to remember about modules is you can omit leading segments if you're in the context of that module. Let's say we had `A::B::C::D::F` that wanted to talk to `A::B::C::D::E.special_method`. Calling it with the full namespace is a mouthful, but look at this:

```ruby
module A
  module B
    module C
      module D
        module E
          def self.special_method = 42
        end
        
        module F
          def self.other_method = "#{E.special_method} is the answer"
        end
      end
    end
  end
end
    
A::B::C::D::F.other_method
# => "42 is the answer"
```

Doesn't `E.special_method` seem pretty reasonable? The further you are away from a module the less likely you should be to ever interact with it, and if calling it is a pain of 5-6 layers in a larger application chances are you should not even know about that internal detail anyways.

### Wrap Up

This chapter introduces modules as a concept of containing things, and the next chapter will show us how we use them to go even further in making shareable behaviors.
