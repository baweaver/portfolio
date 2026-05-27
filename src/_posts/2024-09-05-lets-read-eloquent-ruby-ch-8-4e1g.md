---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 8 – Dynamic Typing"
series: "lets-read-eloquent-ruby"
date: "2024-09-05"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 8. Embrace Dynamic Typing

This chapter, in particular, is very amusing given the more recent zeitgeist around static typing in every language, Ruby included. It leads in with common questions folks ask like how in the world you can write reliable programs without types, and why you even want to try.

I have my own thoughts on that I might expand upon later in another post, but for this one I'll stay closer to the content of the book and the content that it's covering to scope the conversation down.

The short version of my opinion, as well as that of the book, is that there's no such thing as a perfect solution without flaws and that includes static typing. Your job as a programmer is to weigh the bad against the good and make a reasoned decision on the tradeoffs.

### Shorter Programs, But Not the Way You Think

The book starts into this topic by mentioning an often repeated phrase that dynamic typing allows for more compact code. I'm sure those coming from Java might have a few misgivings with how verbose some of their code might be.

Sure, omitting typing can save a bit of time here and there, but the book wants to draw focus instead on all the savings you get from the code you never have to write in the first place.

#### Lazy Documents

The book then gets into the idea of a base document class as a precursor to an implementation of a "lazy" document which won't load content until absolutely necessary:

```ruby
class BaseDocument
  # The book uses the string "Not Implemented", prefer the class
  def title
    raise NotImplementedError
  end
  
  # The book also omits the param here, personally I prefer it to
  # make the "interface" clear on what should be expected in inheriting
  # classes
  def title=(v)
    raise NotImplementedError
  end

  # Repeat for author, author=, content, words, word_count,
  # and other methods
end

# Then we recase Document as a subclass of BaseDocument
class Document < BaseDocument
  attr_accessor :title, :author, :content
  
  def initialize(title, author, content)
    @title = title
    @author = author
    @content = content
  end
  
  def words
    @content.split
  end
  
  def word_count
    words.size
  end
end

# Then we write our lazy class
class LazyDocument < BaseDocument
  attr_writer :title, :author, :content
  
  def initialize(path)
    @path = path
    @document_read = false
  end
  
  def read_document
    return if @document_read
    
    File.open(@path) do |f|
      @title = f.readline.chomp
      @author = f.readline.chomp
      @content = f.readline.chomp
    end
    
    @document_read = true
  end
  
  def title
    read_document
    @title
  end
  
  def title=(new_title)
    read_document
    @title
  end
  
  # and so on and so forth
end 
```

The book mentions that this is an explicitly simple implementation for the sake of example.

> **Note**: While this is a simplified example for the sake of brevity in the book for the sake of more production-oriented code make sure not to conflate IO with state representation as it will be incredibly difficult to test and maintain later. I've written on this before in "[Functional Programming in Ruby - State](/writing/2021/08/01/functional-programming-in-ruby-state-13p2/)."

Namely if these classes keep the same general interface we can make some assumptions in the code that uses them like being able to still call the same document methods:

```ruby
doc = get_some_kind_of_document

puts "Title: #{doc.title}"
puts "Author: #{doc.author}"
puts "Content: #{doc.content}"
```

The book does mention that while these do work they're not really good Ruby. The `BaseDocument` does nothing and takes 30+ lines to do so. The important part here is that it doesn't really matter what `doc` is here as long as it responds to those methods, now does it?

#### Duck Typing

That concept is called "duck typing" in which if it looks like a duck and quacks like one it's probably a duck. Using this idea the book gets rid of the `BaseDocument` class and focuses instead on implementing two distinct types of documents:

```ruby
class Document
  # Body remains unchanged
end

class LazyDocument
  # Body remains unchanged
end
```

As long as the signature is the same you can use them interchangeably.

If you _really_ miss abstract classes in Ruby you can always use them from https://sorbet.org/docs/abstract, but some practitioners of Sorbet can get a tad overzealous with them by which point you've already looped most of the way back to Java.

The difference, for me, is that abstract classes and interfaces here achieve something the duck typing interface does not: programatic compliance. If you're missing methods in your implementation Sorbet will warn you of it, which is much more powerful than what Ruby had back when the book was written with the `NotImplementedError` and base class techniques.

So when do you use one versus another? Well if your interface has several methods required for compliance perhaps it's a better idea, but if it's 1-2 of them? Perhaps the interface is overdoing it.

#### Generic Lazy Document

That all said we could favor duck typing even more here by having our lazy document instead use an [IO](https://ruby-doc.org/core/IO.html) compliant object:

```ruby
class LazyDocument
  attr_writer :title, :author, :content
  
  def initialize(source)
    @source = source
    @source_read = false
  end
  
  def read_source
    return if @source_read
    
    @title, @author, @content = @source.readlines(chomp: true)
    
    @document_read = true
  end
  
  def title
    read_source
    @title
  end
  
  def title=(new_title)
    read_source
    @title
  end
  
  # and so on and so forth
end
```

`IO` is nice in that it supports things like Files, Streams, SDOUT, STDIN, and other common Ruby classes. You could also consider using [StringIO](https://ruby-doc.org/3.3.5/exts/stringio/StringIO.html) here. The point being you can decouple from `File` by using anything that happens to respond to `readlines` instead.

Granted this could be more cleaned up later with potentially a series of parsers for CSVs vs JSON vs YAML vs who knows what type of format the information is in. Maybe you could even have it use a formatter and go further, which is an exercise left to the reader here.

### Extreme Decoupling

The book then gives us an example of a few more classes that might be related to a book system:

```ruby
class Title
  attr_reader :long_name, :short_name
  attr_reader :isbn
  
  def initialize(long_name, short_name, isbn)
    @long_name = long_name
    @short_name = short_name
    @isbn = isbn
  end
end

class Author
  attr_reader :first_name, :last_name
  
  def initialize(first_name, last_name)
    @first_name = first_name
    @last_name = last_name
  end
end

two_cities = Title.new("A Tale of Two Cities", "2 Cities", "0-999-9999-9")
dickens = Author.new("Charles", "Dickens")
doc = Document.new(two_cities, dickens, "It was the best...")
```

#### Aside: Keyword Arguments

But one moment, as there's a particular thing that came to prominence in more recent Ruby versions: Keyword arguments. In these examples we're giving a lot of arguments to these class constructors in a specific order, but what would make more sense is giving them by a specific name such that:

```ruby
class Title
  attr_reader :long_name, :short_name
  attr_reader :isbn
  
  def initialize(long_name:, short_name:, isbn:)
    @long_name = long_name
    @short_name = short_name
    @isbn = isbn
  end
end

class Author
  attr_reader :first_name, :last_name
  
  def initialize(first_name:, last_name:)
    @first_name = first_name
    @last_name = last_name
  end
end

two_cities = Title.new(
  long_name: "A Tale of Two Cities",
  short_name: "2 Cities",
  isbn: "0-999-9999-9"
)

dickens = Author.new(first_name: "Charles", last_name: "Dickens")
doc = Document.new(
  title: two_cities,
  author: dickens,
  content: "It was the best..."
 )
```

...it becomes much clearer to read and understand what each argument is doing, especially if you're far removed from the underlying class or method those arguments belong to. In any case you might notice that I explicitly use keyword arguments from this point on, and I would likewise encourage you to do the same as they're far more intention revealing. The only exceptions are when order matters, or makes sense in a domain, such as `Point.new(x, y)`.

#### Back on Topic

So back to the new classes. The request in the book was to be able to support those new instances in the underlying Document class. This works, as the book mentions, because Ruby doesn't particularly care _what_ type things are as much as they have the methods you want to use later.

The next example highlights what a description might look like with the new `Title` and `Author` objects:

```ruby
class Document
  def description
    "#{@title.long_name} by #{@author.last_name}"
  end
end
```

...but notes that this conflates the classes together, and will be harder to potentially refactor them later. The book doesn't take things this far but personally there's a beautiful example of duck typing right here waiting for us:

```ruby
class Author
  def to_s
    "#{@first_name} #{@last_name}"
  end
end

class Title
  def to_s
    "#{@long_name}"
  end
end

class Document
  def description
    "#{@title} by #{@author}"
  end
end
```

The `to_s` method is our prodigious duck this round, and it allows us to rely on the fact that `Author`, `Title`, and plain old `String` would all work in these slots as they all support a method which lets them be represented as a `String`. To me this is a good example of the flexibility of Ruby's standard idioms.

#### Pseudo Typing

The book then mentions that some newer programmers might try something like this to approximate static typing:

```ruby
class Document
  def initialize(title:, author:, content:)
    raise ArgumentError, "`title` is not a String" unless title.is_a?(String)
    raise ArgumentError, "`author` is not a String" unless author.is_a?(String)
    raise ArgumentError, "`content` is not a String" unless content.is_a?(String)
    
    @title = title
    @author = author
    @content = content
  end
end
```

Granted I used `ArgumentError` here as it's more specific as well as backticks around the argument names to make it a tinge clearer what caused the errors.

The book mentions here that you end up getting the worst of both worlds in that you're now tightly coupled to types and doesn't really improve readability. If you were to do this in a full static typing system like Sorbet it might look more like this instead:

```ruby
class Document
  extend T::Sig
  
  sig { params(title: String, author: String, content: String).void }
  def initialize(title:, author:, content:)
    @title = title
    @author = author
    @content = content
  end
end
```

...but what I really wish it would do is something like interface testing without requiring interfaces like:

```ruby
sig do
  params(
    title: respond_to?(:to_s),
    author: respond_to?(:to_s),
    content: respond_to?(:to_s)
  ).void
}
```

...which goes beyond static typing into declaring explicitly what something needs to support to be used by the method. Granted this is more complicated than it sounds and has a number of drawbacks, as you can see in [this discussion](https://github.com/sorbet/sorbet/issues/983).

#### Required Ceremony versus Programmer-Driven Clarity

The book goes on to give a pseudo-code implementation of what static typing might look like:

```ruby
def initialize(String title, String author, String content)
```

...and says perhaps this gives some clarity, but asks if it would be necessary for more obvious methods like this one:

```ruby
def is_longer_than?(number_of_characters)
  @content.length > number_of_characters
end
```

It argues that even without type declarations you can reason that it might take a `Number` in and return a `Boolean` out the other end. It seeks to be "painfully obvious" and eschews types and documentation. The author uses this to say that we get to pick the level of detail we want, rather than it being a hard and fast requirement, and it's up to us to make that call.

That said I myself am of two minds about it. On one hand it would be nice if everything were reasonable and we could make reasonable guarantees about it, but on the other when dealing with user input and types from a myriad of directions who could make such a guarantee?

#### The Walled Garden

Personally I prefer a hybrid that I tend to call the "Walled Garden" approach. The outside world is scary, so we want to be much harsher with type checking and condition checking on our boundaries to ensure that anything that gets inside of our code cannot represent an invalid state.

That means that boundaries between you and the outside world, or in the case of a large Rails application using packwerk between you and another team's pack, are where you want the most effort expended on type checking. Those are the areas you have the least certainty of, the least domain context, and need the most clarity to be provided to those people on whatever outside you might be considering in this case.

Remember when I mentioned earlier to use `private` liberally? All of your private code can likely omit some amount of typing and documentation, but the more `public` it is the more that's going to become very necessary in progressively larger codebases for your public APIs.

### Staying Out of Trouble

The book mentions some of this by going into what might happen if we were to not update callers of `Document` to know that it now takes something for `title` that responds to `long_name` instead of it being a plain `String`.

Its solution is to relax and write things carefully, as type errors are rare. In some cases I might agree, but in financial and healthcare systems there are certain luxuries not afforded to us, and just being careful might not cut it in some areas. The book does mention it's all about tradeoffs, and if you're in a sensitive domain with tight requirements you really should err on the side of caution.

Compare that to whatever mad science project I have going on the weekend and I can tell you my code is an order of magnitude less rigorous about typing.

The other issue is that when it's one or two developers it's easy to keep things straight, but once you have hundreds it becomes much more challenging. Does that mean we should fully embrace static typing then? Not really, you can do just as much damage that way. I've seen some companies use _thousands_ of Sorbet `T::Struct`s to disastrous result, and that code is nearly impossible to navigate and refactor without a well oiled chainsaw. As with all things it's about balance and Ruby gives you the choice in that matter.

The book also mentions not to be unnecessarily terse and omit information with short names. My general rule here is to make things as readable as possible to where the you in two or three weeks can still understand what and why something was written the way it was because I near guarantee you'll be back in that code.

### In the Wild

Amusingly the book gets to `StringIO` at this bottom section when discussing alternatives to `File`. `StringIO`, `IO`, `File`, all of them have very similar interfaces of methods albeit implicit alignment to that interface rather than explicit.

In another example the book highlights that being too restrictive can make code far less flexible, like the case of `Set` it required something to be `Enumerable` rather than just requiring it to have an `each` method. Eventually that was updated to the latter, and now only requires something which has an `each` method.

### Wrapping Up

Personally I could go on for a while on static versus dynamic typing, but the key point the book mentions is that above all you should be writing tests to verify behavior. Static typing is not some grand panacea, it only verifies the types but not the content inside of them for its behaviors, and far more often the latter is what ends up tripping up code I've worked on. The type is only 20% of the work, the other 80% of the work is deep domain logic and rules engines that need to be understood and well oiled.

The single thing to really keep in mind here is to do what makes sense for you in your codebase with your constraints. I can't pretend to know what you work on, the same as you for me, so we each have very distinct ways of viewing code that very well may be contradictory. Personally I get very worried though if everyone nods along with everything I say, it means I've done something horribly wrong, so please do have opinions and please do consider things no matter who it is saying them, especially if they're of some considerable power and authority.
