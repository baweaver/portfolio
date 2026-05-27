---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 16 – Module Mixins"
series: "lets-read-eloquent-ruby"
date: "2024-09-13"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 16. Use Modules as Mixins

Modules are good for a _lot_ more than just namespacing in Ruby. They're containers for behaviors, certainly, but what if we could also use that to share behavior across different classes? Well that's exactly what a mixin is in Ruby, and it's how we create reusable chunks of code.

### Quick Aside: Hanging Indentation

The book tends to use this hanging style for some multi-line constructs:

```ruby
class Document
  CLICHES = [ /play fast and loose/,
              /make no mistake/,
              /does the trick/,
              /off and running/,
              /my way or the highway/ ]
end
```

While this is a personal preference I tend to really dislike hanging indentation for a few reasons:

* **Diffs** - If that variable name changes or you move the construct you now have to reindent the entire construct relative to wherever it ends up.
* **Left to Right** - The more distance my eye has to travel to follow code the more my ADHD self loses track of things. 
* **Two Space** - Consistent indentation makes it far easier to visually group code and not lose track of `end`s and other bounds

Instead I prefer line-breaked normally indented constructs:

```ruby
class Document
  CLICHES = [
    /play fast and loose/,
    /make no mistake/,
    /does the trick/,
    /off and running/,
    /my way or the highway/
  ]
end
```

To me it's just easier to read and work with later, and the only reason I know why some default to this is JetBrains IDEs like RubyMine suggesting it for some strange reason because Java is notorious for it. Anyways, one of my personal biggest annoyances in reading Ruby code, however petty it might be.

### Better Books with Modules

The book starts with an example of improving the `Document` class further with the ability to judge the quality of the content's writing. As the book mentions cliches can generally be frowned upon, so it suggests we create a way of counting how many of them there are in a document's content:

```ruby
class Document
  CLICHES = [
    /play fast and loose/,
    /make no mistake/,
    /does the trick/,
    /off and running/,
    /my way or the highway/
  ]
  
  def number_of_cliches
    # Rather than the `inject(0)` the `count` method would
    # make more sense here. Also `match?` is clearer than
    # `=~` is.
    #
    # If you wanted to speed this up `Regexp.union(CLICHES)`
    # as a new constant would be a fair bit faster and remove
    # an entire loop.
    CLICHES.count { |phrase| phrase.match?(content) }
  end
end
```

Now I do deviate from the book a bit here in using `count` and `match?`, but I believe that demonstrates that there can be methods that more clearly indicate intent while also making the code more succinct. Typically nowadays `count` and `sum` have replaced most usages of `reduce` and its alias `inject`, and are more clear to readers  in general. If there's a more specific named method available you can use in general prefer that.

The book continues by suggesting that there may be an extended ebook system we need to support:

```ruby
class ElectronicBok < ElectronicText
end
```

Do we copy and paste the behavior from `Document`, even if it would mostly be duplicated? The book mentions most folks first instinct is to create a base class, but in Ruby we also have a way to group similar behaviors outside of inheritance using mixins.

### Mixin Modules to the Rescue

We can take that bit of potentially shared code and wrap it in a module like so:

```ruby
module WritingQuality
  CLICHES = [
    /play fast and loose/,
    /make no mistake/,
    /does the trick/,
    /off and running/,
    /my way or the highway/
  ]
  
  def number_of_cliches
    # Rather than the `inject(0)` the `count` method would
    # make more sense here. Also `match?` is clearer than
    # `=~` is.
    CLICHES.count { |phrase| phrase.match?(content) }
  end
end
```

...and elsewhere in the code we can directly include it in our classes using `include`:

```ruby
class Document
  include WritingQuality
end

class ElectronicBook < ElectronicText
  include WritingQuality
end
```

Giving it a test you can see we get the same results:

```ruby
my_tome = Document.new(
  title: "Hackneyed",
  author: "Russ",
  content: "my way or the highway does the trick"
)

my_time.number_of_cliches
# => 2

my_ebook = ElectronicBook.new(
  title: "Hackneyed",
  author: "Russ",
  content: "my way or the highway does the trick"
)

my_ebook.number_of_cliches
# => 2
```

One of the reasons a lot of folks use mixins is because you can only inherit from one class, but there's no real limit on how many modules you can mixin until your RAM catches fire.

The book suggests maybe there are a few more shared behaviors that we could add:

```ruby
module ProjectManagement; end
module AuthorAccountTracking; end

class ElectronicBook < ElectronicText
  include WritingQuality
  include ProjectManagement
  include AuthorAccountTracking
end
```

The danger, of course, is that too many modules and it can be very hard to follow what's going on in the code without opening up 5+ files on the biggest widescreen you can fit on your desk or monitor arm. Generally if you need a 48" monstrosity of an ultra wide just to read your code chances are some things might need to be simplified a bit.

### Extending a Module

In all of those above cases we're mixing behavior into the instance of a class, does that mean we could also mixin behavior at a class level? We can certainly give it a try:

```ruby
module Finders
  def find_by_name(name); end
  def find_by_id(doc_id); end
end
```

Perhaps your first instinct, if you only know `include`, is to do something like this:

```ruby
class Document
  class << self
    include Finders
  end
end
```

...but as with most things Ruby also has a keyword for that idea which is a bit more succinct:

```ruby
class Document
  extend Finders
end
```

Both of which could be called like so:

```ruby
Document.find_by_name("War and Peace")
```

...though a lot of `find_by` and `where` style methods tend to accept several keyword arguments, very similarly to what ActiveRecord does.

So what's the difference between `include` and `extend`? You use `include` for internals or instances, and `extend` for externals, or at least that's the pneumonic I tend to use in my head to remember. Either that or I swap the two if I really blank out on it.

There's also `prepend`, but that's a subject for another article.

### Staying Out of Trouble

For every module we mixin we're also changing the hierarchy of the inheritance chain behind it. The book uses an illustration here, but in essence it says:

```ruby
Document -> WritingQuality -> Object
```

In a lot of cases this is transparent, but you can tell what modules a class has loaded either through `ancestors` or by asking it using `kind_of?(ModuleNameHere)`. For `Document` the ancestry chain looks something like this:

```ruby
[Document, WritingQuality, Object, Kernel, BasicObject]
```

`include` inserts modules between a class and its superclass, so if `Document` defined its own variant of a method it would win. `prepend`, conversely, puts it _before_ the class and any methods on it come first. The book gives an example of this overriding for `include` here:

```ruby
class Document
  include WritingQuality
end

class PoliticalBook < Document
  def number_of_cliches = 0
end
```

Since `PoliticalBook` comes first in the ancestry chain it'll return `0` any time we call that method. Whatever's higher up the chain wins, unless it doesn't respond to that  method. If you happened to include multiple modules with the same behavior that contradict each other that'd mean whichever one loads first will "win" and the other will be ignored if they share method names.

In general you want to keep mixin modules short and focused, because the larger they become the more risk you run of running into each other while coding.

### Wrap Up

Mixins are extremely common in Ruby, as are `include` and `extend`, with `prepend` being a bit rarer. `Enumerable` especially is a great example if you want to read and explore.
