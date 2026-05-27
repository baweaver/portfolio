---
layout: "post"
title: "Let's Read! — Eloquent Ruby (Ch 1)"
series: "lets-read-eloquent-ruby"
date: "2018-09-21"
categories: []
tags: ["ruby", "books", "beginners"]
description: "Reading through Eloquent Ruby Chapter 1 — writing code that looks like Ruby, with notes on what has changed since 2011."
---

Eloquent Ruby (Addison-Wesley Professional Ruby Series)
It's easy to write correct Ruby code, but to gain the fluency needed to write great Ruby code, you must go beyond…www.amazon.com

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent Ruby is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

| [Next Chapter (2) >](/writing/2018/09/24/lets-read-eloquent-ruby-ch-2/)

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2018 — Ruby 2.5.1 to 2.6-pre).

Without further ado, let's get started!

## Chapter 1 — Write Code That Looks Like Ruby

We start in with an introduction on writing code that looks and feels like Ruby.

**THE VERY BASIC BASICS**

The first example in practice is the following class:

```ruby
class Document
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
```

Now this code will look the much the same today, and Russ mentions right afterwards a style rule:
> "The thing to note about the code above is that it follows the Ruby indentation convention: In Ruby you indent your code with two spaces per level" — Eloquent Ruby Ch 1

This style is still prevalent in the community, as mentioned in both the [Ruby Style Guide](https://github.com/rubocop-hq/ruby-style-guide) and in the lint tool [Rubocop](https://github.com/rubocop-hq/rubocop). Note, that means spaces, not tabs, as Russ also mentioned:
> "…so idiomatic Ruby should be serenely tab free" — Eloquent Ruby Ch 1

**Go Easy on the Comments**
> "The real questions regarding comments are when and how much" — Eloquent Ruby Ch 1

This is always a fun issue in code, the idea of self-documenting code versus explicit comments.

Russ encourages practical examples and how-to guides which are especially useful for people trying to figure out how to use your code later:

```ruby
# Class that models a plain text document, complete with title
# and author:
#
# doc = Document.new('Hamlet', 'Shakespeare', 'To be or...')
# puts doc.title
# puts doc.author
# puts doc.content
#
# Document instances know how to parse their content into words:
#
# puts doc.words
# puts doc.word_count
```

> As an aside, it's rare to see spaces before or after parens in Ruby code in the wild, as [mentioned in the Ruby Style Guide](https://github.com/rubocop-hq/ruby-style-guide#spaces-braces)

```ruby
Document.new( 'Hamlet', 'Shakespeare', 'To be or...' )

Document.new('Hamlet', 'Shakespeare', 'To be or...')
```

With more modern versions, I would highly encourage the use of [YARDoc](https://yardoc.org/) as a standard way of documenting your code. This establishes a formalism in your comments as well as a method of generating an entire documentation set for your users with a few commands.

I use YARDoc for [Qo](https://github.com/baweaver/qo) to document my code both [inline](https://github.com/baweaver/qo/blob/cc0690a711abfaf9ddcfe1d74db065248f238499/lib/qo/public_api.rb#L87-L112) and in a [full documentation site](https://baweaver.github.io/qo/) that can be hosted on Github pages along with the repository.

So instead of the comment provided in the chapter, we might use YARDoc to produce something like this:

```ruby
# Class that models a plain text document, complete with title
# and author.
#
# @example
#
# ```ruby
# doc = Document.new('Hamlet', 'Shakespeare', 'To be or...')
# puts doc.title
# puts doc.author
# puts doc.content
# ```
#
# @author Russ
#
class Document
  # Title of the document
  attr_accessor :title

  # Author of the document
  attr_accessor :author

  # Content of the document
  attr_accessor :content

  # Creates a new instance of a Document
  #
  # @param title [String]
  #   Title of the Document
  #
  # @param author [String]
  #   Author of the Document
  #
  # @param content [String]
  #   The content of the Document
  #
  # @return [Document]
  def initialize(title, author, content)
    @title = title
    @author = author
    @content = content
  end

  # Gets the individual words from our content
  #
  # @return [Array[String]]
  def words
    @content.split
  end

  # Gets the count of words in the document
  #
  # @return [Integer]
  def word_count
    words.size
  end
end
```

Now it may be overkill to comment on the individual attribute accessors for a class like this, but in some cases that may well help the developer using your code to understand what each attribute is used for.

How to comments are mentioned next as a method of explaining particularly complicated bits of code:

```ruby
# Using ngram analysis, compute the probability
# that this document and the one passed in were
# written by the same person, This algorithm is
# known to be valid for American English and will
# probably work for British and Canadian English.
#
def same_author_probability(other_document)
  # Implementation left as an exercise for the reader...
end
```

Personally I like these explanations for more complex bits of code, as is mentioned in the book. With YARDoc we can also add some nifty little external references using the [@see tag](https://www.rubydoc.info/gems/yard/file/docs/Tags.md#see) to point to something like Wikipedia or another resource for further reading:

```ruby
# @see https://en.wikipedia.org/wiki/N-gram N-Grams on Wikipedia
```

Now there are cases of inline comments, and when that might be appropriate or not:

```ruby
return 0 if divisor == 0 # Avoid division by zero
count += 1 # Add one to count
```

The first one makes some sense, as it addresses a potential edge case. We could also note this in the documentation of such a method using a second return:

```ruby
# Divides two numbers
#
# @param a [Number]
# @param b [Number]
#
# @return [Number]
#   Result of dividing two numbers
#
# @return [0]
#   Zero is returned if the divisor is zero, to prevent divide
#   by zero errors.
```

This can be seen as a matter of preference, but in this case it's also exposed in later generated documentation as a top-level edge case that's addressed by an early return.

The second, as is mentioned in the book, is rather silly. Russ addresses this:
> "The danger in comments that explain how the code works is that they can easily slide off into the worst reason for adding comments: to make a badly written program somewhat comprehensible." — Eloquent Ruby Ch 1

Ideally the names of classes, variables, and methods can be used to give clarity to the intent of the code so such comments are unnecessary.

That said, even the clearest of code benefits from a level of discoverability through good documentation in a standard format. Self-explanatory code is great, and I agree that it needs to be written in such a manner, but empowering new users through documentation is what separates an accessible library from a confounding one.

The challenge then becomes updating the documentation in sync with the actual code, because the only thing worse than no comments are misleading ones.

**Camels for classes, snakes everywhere else**

This section has stayed fairly consistent over the years in that…

Classes are camel-cased:

```ruby
class FunDocument
```

Constants are screaming-snake-cased:

```ruby
ANTLERS_PER_MALE_MOOSE = 2
```

Variables are snake-cased:

```ruby
lowercase_words_separated_by_underscore
```

There was some contention noted on constant names between CamelCase and SCREAMING_SNAKE_CASE, but over the past few years Rubyists have moved towards the latter as was Russ's preference in the book.

**Parentheses are optional but are occasionally forbidden**

This one, amusingly, has become a bit of a regional issue. In Seattle parentheses are near universally avoided in a style called Seattle Ruby, unless absolutely necessary to not break the syntax parser.

The more commonly agreed upon items by Rubyists are:

Method arguments should be surrounded by parentheses:

```ruby
def find_document(title, author)
```

Methods with no arguments should omit parens on both definition and calling:

```ruby
def words
  @content.split
end

words
```

Conditionals should not use parens:

```ruby
if (condition) # Bad

if condition # Good
```

Parens are also typically avoided in single arity methods, or block style single arity methods:

```ruby
puts "text"

describe "An RSpec test" do
  # ...
end
```

Though granted that puts isn't single arity:

```ruby
puts "Some", "words"
```

I've seen that one go both ways, it's a matter of preference by that point.

**Folding up those lines**

Ruby allows you to use semicolons `;` to put quite a few things on one line. Absent code golfing and shell one-liners, this should be avoided except in a few cases as mentioned by the book:

```ruby
class DocumentException < Exception; end

def method_to_be_overridden; end
```

Note though that in the second case if parens are present Ruby can tell the difference:

```ruby
def add(a, b) a + b end
```

Though whitespace is free, so use what makes sense and doesn't give you lines that are ridiculously long just to avoid pressing return.

**Folding up those code blocks**

There are two ways to specify a block function in Ruby, either with `{}` or `do .. end`. As far as which one to use, that's still quite the argument.

```ruby
10.times { |n| puts "The number is #{n}" }
```

Typically it's said that brace syntax should be used for one-liners

```ruby
10.times do |n|
  puts "The number is #{n}"
  puts "Twice the number is #{n * 2}"
end
```

and do syntax should be used with multi-liners.

Personally I have a habit of almost always using brace syntax for chaining reasons, but I'm also known to have some bad habits so take that with a grain of salt.

**Staying out of trouble**
> "More than anything else, code that looks like Ruby looks *readable*." — Eloquent Ruby Ch 1

If anything, that quote should be framed above every Rubyist's desk, but that's a bit of a tangent.

We start with code like this:

```ruby
doc.words.each do |word|
  puts word
end
```

which could be written instead like this:

```ruby
doc.words.each { |word| puts word }
```

Now, as mentioned earlier, puts is variadic, so it'd be more succinct to say:

```ruby
puts *doc.words
```

It's mentioned that when these expressions start getting a bit long, we should line break and go back to the do notation:

```ruby
doc.words.each { |word| some_really_really_long_expression( ... with
lots of args ... ) }
```

As far as how long is too long, the book mentions this is left to discretion. Typically it's around 100 to 120 characters. Rubocop and the Ruby Style Guide reference 80 characters, but with modern 4k monitors and environments this can be a bit confining. To quote a certain pirate:
> "And thirdly, the code is more what you'd call "guidelines" than actual rules." — Barbossa

The book mentions two methods, which, individually make a lot of sense to omit parens from:

```ruby
puts doc.author
doc.instance_of?(Document)
```

but might not make much sense when chained together:

```ruby
puts doc.instance_of? self.class.superclass.class
```

Noted that recent versions of Ruby introduced `is_a?` to be used as a shorter version of `instance_of?`.

**In the wild**

The book goes into looking at code in the wild for examples of how things like comments and examples are written. The example used is Set in the book. A more recent set of libraries with good documentation I'd take a look into are ones like:

* [Typhoeus](https://github.com/typhoeus/typhoeus) — Ruby HTTP client

* [Nokogiri](https://github.com/sparklemotion/nokogiri) — (X)HTML parser

* [Slop](https://github.com/leejarvis/slop) — Ruby Option Parser

Now there are others out there, and definitely take a gander at the Ruby Standard Library for examples, but this should give you some more ideas.

Notice that not all of them use YARDoc or other formatters. It comes down to a choice of exactly how detailed you want to be on documentation for your code. Rails doesn't have very much in the way of inline documentation, but has a massive amount of documents written in markdown with examples everywhere.

Do what makes sense for your libraries.

Back to the chapter itself, they mention question mark and exclamation mark methods. Convention still follows that question mark methods return boolean responses, and exclamation marks typically indicate either mutation or surprising behavior.

There are some Kernel methods like `Float` which break the rules, but are used as stand-ins for class names:

```ruby
pi = Float('3.14159')
```

There have been some cases in more modern Ruby of abusing bracket notation to avoid the necessity of a kernel method:

```ruby
origin = Point[0, 0]
```

which is defined like this:

```ruby
class Point
  def self.[](x, y)
    new(x, y)
  end

  def initialize(x, y)
    @x = x
    @y = y
  end
end
```

Though this again is a matter of preference, as some would strongly prefer not to define methods on the top level namespace for their own gems and libraries.

**Wrapping up**
> "Above all else, pragmatism: You cannot make readable code by blindly following some rules." — Eloquent Ruby Ch 1

Ruby is a language of flexibility and choice, following all the rules would quite simply be no fun and would lead to very rigid code. Do what makes sense and makes your code more readable, and if you're confused feel free to reach out and ask.

That about covers chapter 1 of Eloquent Ruby, I hope you've enjoyed! I'll be working through the other chapters as I prepare a class on the book to teach newly minted Rubyists at work.

Next up is control flow in Ruby!

| [Next Chapter (2) >](/writing/2018/09/24/lets-read-eloquent-ruby-ch-2/)
