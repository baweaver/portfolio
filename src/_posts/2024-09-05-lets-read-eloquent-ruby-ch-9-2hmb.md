---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 9 – Tests"
series: "lets-read-eloquent-ruby"
date: "2024-09-05"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "books"]
description: "Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, Eloquent..."
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2024 — Ruby 3.3.x).

## Chapter 9. Write Specs!

**Warning:** This chapter has had a _significant_ amount of changes since the original writing as the syntax for RSpec especially has evolved dramatically since then, so be sure to compare how things have evolved but be careful not to use some of the older syntax as it will break.

Ah specs. One of the things I really appreciated about Ruby early on is that nothing was considered done until it was also tested, a sentiment the book reflects. Now there are many different ways to test in Ruby, all of them correct in their own ways, but my correct is RSpec and that's what I'll be focusing on when going through this chapter.

That also means that I'm going to be skipping the sections on `Test::Unit` and apologizing to my Seattle friends about the omission of `MiniTest`.

Why RSpec? Because every major Rails shop I have worked at uses it all the way up to north of 5 million lines of code. Some say its slow, personally I say folks use `FactoryBot.create` too liberally and create hundreds of thousands of database records instead of decoupling from persistence layers, but that's an argument for a much longer and much different article than this one.

Anyways, we'll be starting with "Don't Test It, Spec It!"

### Don't Test It, Spec It!

As the book mentions RSpec focuses more on testing the behaviors of our code, and currently it might look something like this (with some improvements throughout the chapter as per usual):

```ruby
# What we're testing
class Document
  attr_reader :title, :author, :content
  
  # Yes, I'm going to use keyword arguments here too
  def initialize(author:, title:, content:)
    @author = author
    @title = title
    @content = content
  end
  
  def words
    content.split
  end
  
  def word_count
    words.size
  end
end

# The first difference is the first `describe` is always prefixed with
# `RSpec` now while everything inside of the block is evaluated in its
# context.
RSpec.describe Document do
  # The next is that it tends to segment tests based on the method name
  # for Unit level tests (individual units of code) using that Smalltalk
  # .class_method versus #instance_method idiom.
  describe ".new" do
    it "can create an instance of a Document" do
      # While we could use `Document` here we can also use
      # `described_class` just in case we happen to
      # move things around later.
      document = described_class.new(
        author: "Author",
        title: "Title",
        content: "A bunch of words"
      )
      
      # The third is that assertions are now no longer monkeypatched into
      # every object, they're wrappers now.
      #
      # In this case it's a fairly simple check that we can even
      # initialize a Document and it doesn't break.
      expect(subject).to be_a(described_class)
    end
  end
  
  describe "#words" do
    it "contains all the words in the document" do
      document = described_class.new(
        author: "Author",
        title: "Title",
        content: "A bunch of words"
      )
      
      expect(subject.words).to include("A", "bunch", "of", "words")
    end
  end
  
  describe "#word_count" do
    it "can get a count of the words in a document" do
      document = described_class.new(
        author: "Author",
        title: "Title",
        content: "A bunch of words"
      )
      
      expect(subject.word_count).to eq(4)
    end
  end
end
```

The key difference is that `something.should == something_else` is now deprecated syntax which has been gone for years. Why? Because the prior relied on monkey patching which could have adverse effects on the underlying code being tested.

The other difference is that I tend towards wrapping each distinct method in its own `describe` block. For much larger spec files this becomes very common for unit tests, though integration tests which describe less behavior and exercise wider ranges of code may still follow a more behavioral syntax. In the next sections we'll stick slightly closer to the book.

### A Tidy Spec is a Readable Spec

The book here mentions using `before :each` with instance variables like so:

```ruby
RSpec.describe Document do
	before :each do
    @text = "A bunch of words"
    @doc = Document.new(title: "Test", author: "Nobody", text: @text)
  end
  
  # Personal preference: "should" versus active voice
  it "holds the contents" do
    expect(@doc.content).to eq(@text)
  end
  
  it "knows which words it has" do
    expect(@doc.words).to include("A", "bunch", "of", "words")
  end
  
  it "knows how many words it contain" do
    expect(@doc.word_count).to eq(4)
  end
end
```

**Note**: Instance variables are generally not a good idea in tests, prefer to use `let` and `subject` instead to prevent state from being shared across tests and potentially getting test pollution. They're recreated between each test (`it` block):

```ruby
RSpec.describe Document do
  let(:text) { "A bunch of words" }
  subject { described_class.new(title: "Test", author: "Nobody", text: text) }

  it "holds the contents" do
    expect(subject.content).to eq(text)
  end
  
  it "knows which words it has" do
    expect(subject.words).to include("A", "bunch", "of", "words")
  end
  
  it "knows how many words it contain" do
    expect(subject.word_count).to eq(4)
  end
end
```

There are still cases for `before` and its sibling `after` for set-up, mocking, and tear-down logic. The book also mentions the presence of `before :all` and `after :all` for running code before and after all of your specs. RSpec configuration even has a `:suite` level for things you want for every spec, but use it sparingly.

### Easy Stubs

Stub syntax has certainly changed a lot since the book as well, so do be careful here. In some cases you have network calls, expensive operations, or things you just do not want to run inline along with a test. If you want to test something in isolation you're likely to need at least a few stubs unless you're writing things in an extremely functional style.

The example the book uses is of a `PrintableDocument` that uses a physical printer:

```ruby
class PrintableDocument
  def print(printer)
    return "Printer unavailable" unless printer.available?
    
    printer.render("#{title}\n")
    printer.render("By #{author}\n")
    printer.render(content)
    
    "Done"
  end
end
```

So how do we test it? In the book's era we used a stub, but now they tend to be called `double`s:

```ruby
class Printer
  def available?
    true
  end
  
  # Assume this is an actual printer spool call of some sort
  def render(message)
    print message
  end
end

describe PrintableDocument do
  let(:text) { "A bunch of words" }
  subject { described_class.new(title: "Test", author: "Nobody", text: text) }
  
  # Not only mock it, but _require_ it to behave like an actual Printer
  let(:printer_double) { instance_double(Printer) }
  let(:printer_status) { true }
  
  before do
    allow(printer_double).to receive(:available).and_return(printer_status)
    allow(printer_double).to receive(:render).and_return(nil)
  end
  
  it "knows how to print itself" do
    expect(subject.print(printer_double)).to eq("Done")
  end
  
  # More modern variants would use a `context` to wrap when a variable
  # or detail has changed
  context "When the printer is off" do
    let(:printer_status) { false }
    
    it "shows that the printer is unavailable" do
      expect(subject.print(printer_double)).to eq("Printer unavailable")
    end
  end
end
```

One of the major benefits of `instance_double` here is that if I forgot to add an `allow` here it would complain that it's not allowed to receive certain messages, failing the test. This forces us to account for all of its behaviors, not just the ones under the current test.

You could even put it inline as an `expect(X).to receive(Y).at_least_once.and_return(5)`, there's a lot of flexibility here. In fact it's so powerful it accidentally skipped the next section of this chapter.

### Staying Out of Trouble

As the book mentions tests will prevent a _lot_ of bugs and catch a lot of cases you might not have ever considered, but the law of diminishing returns is real.

If you were to start from zero, for instance, I would focus on describing your most important functionality in end to end tests first. Start from the outside and work inside. When you're focusing on your user first you want to make sure their expectations are reflected. They don't care if `adds` will add two numbers somewhere deep in your code, they care whether or not they can run Payroll. Perhaps `adds` is part of that code, but they care about end results, and that's always a good thing to keep in mind.

#### The Opposite

One thing a lot of folks forget is for every positive assertion you should have a negative one. If you only test one half of the code it should come as no surprise when the other half isn't actually working like you think it is.

### Not Catch Fire Spec

Amusingly Russ also mentions the simple "make a new instance" test similar to the `.new` test above. Perhaps I'm also heretical here.

### Wrapping Up

The big takeaway here, and I agree with the book, is to write tests. However they look, doesn't matter, just write some. Take it from me who spent years rerunning console applications in school just to figure out the computer could have done the entire thing for me and far more accurately. Be lazy, write tests.

If you want to read more on testing I would highly recommend [Effective RSpec](https://pragprog.com/titles/rspec3/effective-testing-with-rspec-3/).
