---
layout: "post"
title: "Let's Read - Eloquent Ruby - Ch 10 – Short Methods"
series: "lets-read-eloquent-ruby"
date: "2024-09-07"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 10. Construct Your Classes from Short, Focused Methods

One of the greatest differences for me between a Ruby program and an eloquent one is the ability to name and encapsulate ideas effectively. A program isn't one giant blob of text, it's a series of concepts and ideas stitched together by code, and being able to express those same ideas clearly is what really makes great code.

### Compression Specifications

The book starts with giving us a task: To design a compression algorithm that takes a `String` and produces two arrays. We start with the example `String` we'll be working with:

```ruby
string = "This specification is the specification for a specification"
```

The first `Array` will be a list of all the unique words in the `String`:

```ruby
["This", "specification", "is", "the", "for", "a"]
```

...and the second `Array` will be a list of `Integer` indexes for each word in the original `String` that corresponds to our unique indexes, giving us something like this:

```ruby
[0, 1, 2, 3, 1, 4, 5, 1]
```

Now the book immediately jumps into code here, but I'll take a slightly different tact and start with a high-level spec:

```ruby
require 'rspec/autorun'

class TextCompressor
  # TODO
end

RSpec.describe TextCompressor do
  let(:string) { "This specification is the specification for a specification" }
  
  subject { TextCompressor.new(string) }
  
  it "gets a list of unique words and their indexes" do
    expect(subject.unique).to eq(["This", "specification", "is", "the", "for", "a"])
    expect(subject.index).to eq([0, 1, 2, 3, 1, 4, 5, 1])
  end
end
```

We'll eventually break this down to add more methods in a bit, but for now this will prove that our script works. Try saving this as a file and running it directly, `rspec/autorun` is handy for setting up these short little discrete tests.

Now back to the code itself the book gives us we start with this:

```ruby
class TextCompressor
  attr_reader :unique, :index
  
  def initialize(text)
    @unique = []
    @index = []
    
    words = text.split
    words.each do |word|
      i = @unique.index(word)
      
      if i
        @index << i
      else
        @unique << word
        @index << @unique.size - 1
      end
    end
  end
end
```

If you were to run that with the above spec it would work, but as the book mentions that's a bit hard to read isn't it? It continues to set up a few refactors:

```ruby
class TextCompressor
  attr_reader :unique, :index
  
  def initialize(text)
    @unique = []
    @index = []
    
    words = text.split
    words.each do |word|
      i = unique_index_of(word)
      
      if i
        @index << i
      else
        @index << add_unique_word(word)
      end
    end
  end
  
  def unique_index_of(word)
    @unique.index(word)
  end
  
  def add_unique_word(word)
    @unique << word
    @unique.size - 1
  end
end
```

It pulls out the idea of searching for a word and adding a unique word and gives a name to it. That said, it could go further, and the book does so:

```ruby
class TextCompressor
  attr_reader :unique, :index
  
  def initialize(text)
    @unique = []
    @index = []
    
    add_text(text)
  end
  
  def add_text(text)
    words = text.split
    words.each { |word| add_word(word) }
  end
  
  def add_word(text)
    i = unique_index_of(word) || add_unique_word(word)
    @index << i
  end
  
  def unique_index_of(word)
    @unique.index(word)
  end
  
  def add_unique_word(word)
    @unique << word
    @unique.size - 1
  end
end
```

In this second refactor it pulls the logic further out into `add_text` and `add_word`. The book stops here, but I'm not quite there myself, let's go for another round:

```ruby
class TextCompressor
  def initialize(text)
    @text = text
  end
  
  # Preference to seperate the wrapping of data and the acting on it
  def call
    # We do this to create a mapping of `word => unique index` and
    # to have an `O(1)` lookup time rather than re-searching the
    # entire `String`.
    unique_words = {}
    
    # We replace `index` entirely by using `map` which allows us
    # to encapsulate both ideas at once
    word_positions = @text.split.map do |word|
      # We use that Hash mapping of word to the first index we saw it at
      # plus `||=` to set the unique index if we haven't seen one yet.
      #
      # Even better? This returns that value as well, so this becomes
      # A single line
      unique_words[word] ||= unique_words.size
    end
    
    # And we could probably set those initial instance variables if
    # we wanted, but what we care about are the unique words and
    # their positions. If we were to hit `call` multiple times
    # though it would make more sense to cache these.
    #
    # The value for `word_positions` is omitted, but translates
    # to `word_positions: word_positions` through shorthand Hash
    # syntax
    { unique_words: unique_words.keys, word_positions: }
  end
end

# And without the comments:

class TextCompressor
  def initialize(text)
    @text = text
  end
  
  def call
    unique_words = {}
    
    word_positions = @text.split.map do |word|
      unique_words[word] ||= unique_words.size
    end

    { unique_words: unique_words.keys, word_positions: }
  end
end

TextCompressor.new("This specification is the specification for a specification").call
 => {:unique_words=>["This", "specification", "is", "the", "for", "a"], :word_positions=>[0, 1, 2, 3, 1, 4, 5, 1]}
```

This demonstrates some of the incredible value of Ruby's `Hash`, but definitely veers into a much more functional style. Chalk it up to me having fun more than anything. I might consider making that into a `module` instead and doing away with saving `@text` altogether, but again, different styles for different circumstances.

We could also break this up into a few methods if we really wanted to and go back to some instance variables:

```ruby
class TextCompressor
  def initialize(text)
    @text = text
    @unique_words = {}
    @word_positions = []
  end
  
  # Instead of having a reader we mask the internal implementation
  # here.
  def unique_words = @unique_words.keys
  
  # If someone asks for `word_positions` once we can calculate it
  # at that time, and all subsequent times will return the stored
  # instance variable here.
  def word_positions
    @word_positions ||= @text.split.map { |word| unique_word_index(word) }
  end
  
  def unique_word_index(word)
    @unique_words[word] ||= unique_words.size
  end
end
```

Only marginally longer, but complies to the original spec with a few changed names. If we were cheeky we could also alias to the originals:

```ruby
class TextCompressor
  alias_method :index, :word_positions
  alias_method :unique, :unique_words
end
```

...but I digress.

### Composing Methods for Humans

The book mentions that doing this is the idea of breaking a complex idea into several named methods, each doing one distinct thing.

Some might take this further to say that "doing one thing" implies being a pure function that has no side-effects, which our `call` variant comes fairly close to, and that's called Functional Programming. While Ruby _is_ an Object Oriented language it takes several hints from Functional languages like LISP which is how we got things like `Enumerable`. To me the closer we get to a Functional style the easier it is to test and reason about our applications.

The book goes further to say that code should operate at a single conceptual level. Code doing currency conversion should not get into details about how data for accounts are stored in the DB. This could be called separation of concerns, or in a functional light a [functional core with an imperative shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell).

The final mention it has is that each method needs a name that reflects its purpose clearly. If it's hard to pick a name the method is doing too much, and if you find yourself reaching for `and` or `or` in the method name it's _definitely_ doing more than one thing. Now where we draw the line for "one thing" is a long entrenched debate, so as with the book I'd urge you to use your own judgement but err on the smaller side.

Going back to the final version of the book's code here:

```ruby
class TextCompressor
  attr_reader :unique, :index
  
  def initialize(text)
    @unique = []
    @index = []
    
    add_text(text)
  end
  
  def add_text(text)
    words = text.split
    words.each { |word| add_word(word) }
  end
  
  def add_word(text)
    i = unique_index_of(word) || add_unique_word(word)
    @index << i
  end
  
  def unique_index_of(word)
    @unique.index(word)
  end
  
  def add_unique_word(word)
    @unique << word
    @unique.size - 1
  end
end
```

...the book mentions that it follows the three above concepts. A method to add text, a single word, to find the index of a word, and to add a unique word. Some like adding text wrap a smaller idea of adding a word, and each name reflects what the code is doing with some clarity.

End of the day we write code for other humans, not computers, so the more we break down concepts into readable and understandable chunks the easier it makes our jobs tomorrow.

### Composing Ruby Methods

One of the key distinguishing factors of Ruby, as the book mentions, is that you tend to have a lot of short focused methods which try and do one thing well. That makes them easier to test and to compose into bigger things, which is another distinctly functional concept, and also a lot of the philosophy behind Unix tools. Good ideas are often repeated often in completely different spaces of programming.

Now the book mentions that having this many methods allows us to hook in and test all sorts of things. While true, it also makes our public API substantially wider. Do we _really_ want consumers to have access to all of those details? Probably not, we only want them to know that we give them text in and they get back indexes and unique words on the other end.

For every bit of code that can be accessed publicly we've made an implicit commitment that that code is supported. If you change the name of one of those internal methods that's public all the downstream code is now broken that might have reached into there, and even worse if it's a public gem release. To me every publicly accessible method in a class is a promise to at least follow [semantic versioning](https://semver.org/) paradigms and not break folks.

So back to what I mentioned in an earlier article: Only make public that which you intend to support, and make everything else protected or private, we shouldn't let all our consumers see behind the curtain.

### One Way Out?

The book then goes into some more advantages of short methods. An old adage of programming is to have a single way out of the method, and if we had many more it'd become fairly hard to follow. The book gives us this example code to play with:

```ruby
class Document
  def prose_rating
    if pretentious_density > 0.3
      if informal_density < 0.2
        return :really_pretentious
      else
        return :somewhat_pretentious
      end
    elsif pretentious_density < 0.1
      if informal_density > 0.3
        return :really_informal
      end
      return :somewhat_informal
    else
      return :about_right
    end
  end
  
  def pretentious_density
    # Somehow compute density of pretentious words
  end
  
  def informal_density
    # Somehow compute density of informal words
  end
end 
```

The book posits, fairly, that this is probably fairly dense to read. It then attempts to have a single-return in the next example:

```ruby
def prose_rating
  rating = :about_right
  
  if pretentious_density > 0.3
    if informal_density < 0.2
      rating = :really_pretentious
    else
      rating = :somewhat_pretentious
    end
  elsif pretentious_density < 0.1
    if informal_density > 0.3
      rating = :really_informal
    else
      rating = :somewhat_informal
    end
  end
  
  rating
end
```

...but the book mentions the real issue here is that there's just too much going on in this method and suggests we break it further into sub-methods like so:

```ruby
class Document
  def prose_rating
    return :really_pretentious if really_pretentious?
    return :somewhat_pretentious if somewhat_pretentious?
    return :really_informal if really_informal?
    return :somewhat_informal if somewhat_informal?
    
    :about_right
  end
  
  def really_pretentious?
    pretentious_density > 0.3 && informal_density < 0.2
  end
  
  def somewhat_pretentious?
    pretentious_density > 0.3 && informal_density >= 0.2
  end
  
  def really_informal?
    pretentious_density < 0.1 && informal_density <= 0.3
  end
  
  def somewhat_informal?
    pretentious_density < 0.1 && informal_density <= 0.3
  end
  
  def pretentious_density
    # Somehow compute density of pretentious words
  end
  
  def informal_density
    # Somehow compute density of informal words
  end
end
```

By doing so we now have names for concepts, but again I might take it a step further here:

```ruby
class Document
  HIGH = 0.3
  MEDIUM = 0.2
  LOW = 0.1
  
  def prose_rating
    return :really_pretentious if really_pretentious?
    return :somewhat_pretentious if somewhat_pretentious?
    return :really_informal if really_informal?
    return :somewhat_informal if somewhat_informal?
    
    :about_right
  end
  
  def really_pretentious?
    pretentious_density > HIGH && informal_density < MEDIUM
  end
  
  def somewhat_pretentious?
    pretentious_density > HIGH && informal_density >= MEDIUM
  end
  
  def really_informal?
    pretentious_density < LOW && informal_density <= HIGH
  end
  
  def somewhat_informal?
    pretentious_density < LOW && informal_density <= HIGH
  end
  
  def pretentious_density
    # Somehow compute density of pretentious words
  end
  
  def informal_density
    # Somehow compute density of informal words
  end
end
```

Adding constants here makes it clearer what specific levels we're talking about at a glance. Perhaps we could go further, but that'll be an exercise left to the reader. If you want a challenge look into Enums and how you might implement them for Ruby.

In any case the book mentions that using these predicate methods here gets around the single-return idea fairly effectively. Can you still understand what it's doing at a glance? If the answer is yes I would not worry too much about any rules. The end job of code is to clearly communicate what it does, and if breaking a rule can still produce clear code? Break away. That's Ruby.

### Staying Out of Trouble

The book mentions that composable methods should be short _and_ coherent, but that it's easy to focus too much on short and do something like this:

```ruby
class TextCompressor
  def add_unique_word(word)
    add_word_to_unique_array(word)
    last_index_of_unique_array
  end
  
  def add_word_to_unique_array(word)
    @unique << word
	end

  def last_index_of_unique_array
    @unique.size - 1
  end
end
```

The book says these add clutter, but they also add more surface area to the class for someone to do something unintended to it. That's why I keep harping on making things private unless they make sense for someone to consume: you know your domain and that code better than consumers might, and exposing 100% of it is not particularly a kindness to someone who has to dig through all those methods to find the productive ones.

### In the Wild

The book uses an old method from `ActiveRecord::Base` as its example, except that `find(:all)` has long since been replaced by `where`, and those methods are definitely far more complicated now.

If you want a potentially interesting gem to read through I'd written XF years ago:

https://github.com/baweaver/xf/tree/master

It works off of a similar idea to Haskell lenses in that you describe a path to what you want in a deeply nested structure and you can either get or set using it:

```ruby
people = [{name: "Robert", age: 22}, {name: "Roberta", age: 22}, {name: "Foo", age: 42}, {name: "Bar", age: 18}]

age_scope = Xf.scope(:age)

older_people = people.map(&age_scope.set { |age| age + 1 })
# => [{:name=>"Robert", :age=>23}, {:name=>"Roberta", :age=>23}, {:name=>"Foo", :age=>43}, {:name=>"Bar", :age=>19}]

people
# => [{:name=>"Robert", :age=>22}, {:name=>"Roberta", :age=>22}, {:name=>"Foo", :age=>42}, {:name=>"Bar", :age=>18}]

# set! will mutate, for those tough ground in issues:

older_people = people.map(&age_scope.set! { |age| age + 1 })
# => [{:name=>"Robert", :age=>23}, {:name=>"Roberta", :age=>23}, {:name=>"Foo", :age=>43}, {:name=>"Bar", :age=>19}]

people
# => [{:name=>"Robert", :age=>23}, {:name=>"Roberta", :age=>23}, {:name=>"Foo", :age=>43}, {:name=>"Bar", :age=>19}]
```

If you really want a trip read the `trace.rb` and see if you can figure out how it works. In general I tend to use a style very similar to this book in breaking things down into reasonably readable small methods with distinct purposes. Granted I tend to err a more functional programming style, but that's more a preference than anything.

### Wrap Up

The big lesson in this chapter is to keep ideas encapsulated and well-named. Often times that translates to smaller methods with clear purposes, sometimes that translates to classes with minimal public APIs which do one task well that you can stitch together. The point of it all is to make sure the code is understandable to you and others without a need to spend weeks writing documents about it, because code is read far more often than it's written.
