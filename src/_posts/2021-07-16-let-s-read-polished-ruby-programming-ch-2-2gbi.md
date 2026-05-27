---
layout: "post"
title: "Let's Read – Polished Ruby Programming – Ch 2"
series: "lets-read-polished-ruby"
date: "2021-07-16"
tags: ["ruby", "books"]
---

[Polished Ruby Programming](https://www.packtpub.com/product/polished-ruby-programming/9781801072724) is a recent release by [Jeremy Evans](https://twitter.com/jeremyevans0), a well known Rubyist working on the Ruby core team, Roda, Sequel, and several other projects. Knowing Jeremy and his experience this was an instant buy for me, and I look forward to what we learn in this book.

You can find the book here:

https://www.packtpub.com/product/polished-ruby-programming/9781801072724

This review, like other "Let's Read" series in the past, will go through each of the chapters individually and will add commentary, additional notes, and general thoughts on the content. Do remember books are limited in how much information they can cram on a page, and they can't cover everything.

With that said let's go ahead and get started.

# Chapter 2 – Designing Useful Custom Classes

The second chapter covers the following topics:

* Learning when to create a custom class
* Handling trade-offs in SOLID design
* The single-responsibility principle
* The open-closed principle
* The Liskov substitution principle
* The interface segregation principle
* The dependency inversion principle
* Deciding on larger classes or more classes
* Learning when to use custom data structures

We'll be covering each of those in the following sections.

## Learning when to create a custom class

We start out on a very valuable topic: should you actually create that custom class?

### Types of Programming

Jeremy mentions three (of many) styles of programming:

* Object Oriented - Designed around creating a class for every type of object
* Functional - Functions which operate on immutable data structures
* Procedural - Similar to Functional, except mutable

Ruby has support for each, and Jeremy mentions here that no one of them is necessarily the best. It would also be valuable to keep in mind that they're not exactly fully distinct from eachother either, we can very easily mix and match to get the best from all of those domains, and often times puritanical adherence to one style of programming will work to your detriment.

I would amend the description of functional programming to note that it involves building up a program from small pieces (functions) by gluing them together, rather than a more top-down approach that's more common in object oriented design. There are exceptionally valuable lessons in doing one thing and only one thing well, and combining those pieces to do larger things.

### Custom class tradeoffs

Now back to custom classes. As mentioned in the previous chapter every custom class is extra overhead a programmer has to keep in mind while working with your code, and core classes are more easily intuited about. Jeremy mentions two main benefits to creating one:

1. **Encapsulation of state** - State can be manipulated in a way that makes sense in the context of the object.
2. **Handling of state** - Simplifies creating methods that can handle the internal state in a defined context.

For my interpretation I would agree with both of those, as an object allows you to capture a domain context in code, and reflect the operations which can be carried out on it in a documented and tested way. It's adding structure to reflect the way your data is represented in the real world, and by doing so allows you to put in safety checks, documentation, testing, and other edge checks to make it easier to work with.

### Stack example

Now we get to an example, a stack. It's mentioned that this can be done using core classes:

```ruby
stack = []

# add to top of stack
stack.push(1)
# => [1]

# get top value from stack
stack.pop
# => 1

# ...and the stack is empty
stack
# => []
```

Now Jeremy adds a great example here, what if another part of the program accesses that underlying data structure and goes against our intentions?:

```ruby
# add to bottom to stack!
stack.unshift(2)
```

Then we'd have one part acting like a stack, and the other acting like a queue. The next example provides a way to wrap the state of the stack as such that going outside our designed intentions is prevented:

```ruby
class Stack
  def initialize
    @stack = []
  end

  def push(value)
    @stack.push(value)
  end

  def pop
    @stack.pop
  end
end
```

_(...but this being Ruby a particularly motivated individual still could, we just want to make it harder for those more inclined to behave.)_

It's useful for capturing the distinct idea of a stack, but I enjoy that Jeremy mentions here that it comes with costs:

* If it's only used once you added extra indirection for very little reason
* Slower performance
* Worse garbage collection

One thing I enjoy so far about this book is it demonstrates how little comes for free when making decisions, and tries to make the reader conscious of this.

### Symbol stack

The next example adds to the use case and reflects some additional requirements which justify a new class more than just hiding data from the user:

```ruby
class SymbolStack
  def initialize
    @stack = []
  end

  def push(sym)
    unless sym.is_a?(Symbol)
      raise TypeError, "can only push symbols onto stack"
    end

    @stack.push([sym, clock_time])
  end

  def pop
    sym, pushed_at = @stack.pop
    [sym, clock_time - pushed_at]
  end

  private def clock_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
```

It's doing a few more things here:

1. You can only push `Symbol` types
2. It records when the insertion was done
3. It provides the pop time on removal

So not only is this class encapsulating a stack that's typed, but also the timing of actions occurring against it. This also does a great job at demonstrating a usage of `private` to hide the internal details of `clock_time`, as callers of the class don't need to worry about that.

Jeremy loops back to make a repeated point, and one that bears repeating: If this is being used two or three times it may justify a class, but once? Just inline the code and see if it justifies a class later instead of prematurely designing around it.

There's also mention of making sure to not let users get at the underlying data structure if that's the case, which is a good thing to remember. A good rule to follow is anything that's in the public API of a program (any public method a user can call) will very likely be called, so you want to keep the public footprint of your program minimized as much as possible unless you're particularly keen on lots of breaking changes in the future.

The wider the public API and the more it gives access to, the more brittle your program will be in the future when you want to change anything.

## Handling trade-offs in SOLID design

SOLID, as the book mentions, is an acronym for five principles of OO design:

* The single-responsibility principle
* The open-closed principle
* The Liskov substitution principle
* The interface segregation principle
* The dependency inversion principle

What I particularly enjoy about this section, and really the book in general, is that Jeremy reaffirms that such things should not be used dogmatically. In fact that's one of the key parts of programming: Most things are suggestions, and being able to reason about tradeoffs and nuance are absolutely critical.

### The single-responsibility principle

The book starts with the single responsibility principle, or the idea that each class should really only do one thing, and one thing well. What's interesting here is that it goes on to say that more often this idea is used to justify splitting classes apart that serve many purposes.

#### Dangers

The danger here is that for each class that's broken out you add extra indirection, complexity, and difficulty especially with classes that have a smaller scope of impact in your program. I'm really glad they got into this, as I've seen some linters and other tools in Ruby take this to extremes like five-line methods, one-hundred-line classes, and other items which are more of suggestions than things to be strictly followed.

Where there's a suggestion there's a zealous programmer there to make it into a linter or automated tool to enforce it without the original nuance behind it, and that's one of the biggest flaws of linters and style guides. Be careful what you make into a "rule", because it's very hard to unmake it.

#### Examples

The book goes into the `String` class as the first example:

```ruby
str = String.new

str << "test" << "ing...1...2"
name = ARGV[1]
  .to_s
  .gsub('cool', 'amazing')
  .capitalize

str << ". Found: " << name

puts str
```

...which can be turned into this if one really went for the SRP idea:

```ruby
builder = TextBuilder.new

builder.append("test")
builder.append("ing...1...2")

modifier = TextModifier.new
name = modifier.gsub(ARGV[1].to_s, 'cool', 'amazing')
name = modifier.capitalize(name)

builder.append(". Found: ")
builder.append(name)

puts builder.as_string
```

`String` in Ruby is exceptionally flexible, and in the above case it certainly pares things down, [but at what cost](https://twitter.com/search?q=tenderlove%20at%20what%20cost&src=typed_query)? If you did break things into another focused class would it be used more than once, or only in this one spot? The book discourages breaking it out unless it gets a lot of use, and I would be inclined to agree.

> You might notice I prefer prefix-dot rather than postfix-dot for line-breaked methods like:
>
> ```ruby
> something.
>   other_method.
>   another
> 
> # versus
> something
>   .other_method
>   .another
> ```
>
> Why? Better diffs, harder to miss dots, and Josh Cheek [did a phenomenal job explaining](https://github.com/testdouble/standard/issues/75) for the rest of the reasons.
>
> That said, that same logic could be used for Haskell style commas and that still feels odd to me:
>
> ```ruby
> # Usual way
> h = {
>   a: 1,
>   b: 2,
>   c: 3
> }
> 
> # Haskell-ish way
> h = {a: 1
>     ,b: 2
>     ,c: 3}
> ```
>
> ...which still feels off. Anyways, point being preferences aren't exactly consistent all the time either, mine certainly aren't.

Another point they bring up in the book is whether you want more extensibility in a class, like a report generator with multiple report types (HTML, CSV, etc). In this case it mentions having a `ReportContent` and `ReportFormatter` potentially:

```ruby
# Perhaps start with a single report type that does it all
report = Report.new(data)
puts report.format

# But later we may need several format types:
report_content = ReportContent.new(data)
report_formatter = ReportFormatter.new

puts report_formatter.format(report_content)
```

As has been the case the book advocates for considering how much value breaking these concepts apart might have in the future, such as if you support a significant number of formatters in the future or just a few. Using a separate class in those cases allows one to switch out just one part of the class more easily:

```ruby
report_content = ReportContent.new(data)

report_formatter = ReportFormatter
  .for_type(report_type)
  .new

puts report_formatter.format(report_content)
```

The general principle in the book is to delay adding complexity until you can justify it. One thing I've learned in programming time after time is YAGNI (You Aren't Going To Need It), and to design for the immediate use case rather than a myriad of future unknowns you can't guarantee.

"It is far easier to add complexity later if needed than to remove complexity later if not needed, at least if you care about backward compatibility."

Which is definitely something I would take firmly to heart as a programmer.

### The open-closed principle

The next principle is open-closed, or that a class should be open for extension but not modification. For Ruby the book mentions things like instance variables and methods, and for modification if mentions modifying or removing instance variables and methods.

The original rule was written more for compiled software, and knowing Ruby an adept reader may find this an odd concept: Ruby's pretty big on reopening classes, and we have lots of rules around that to not cause issues down the road.

Ruby 2.x introduced origin classes to allow the use of `prepend`, which changes the order of the call-chain and makes reasoning about the object model much more complex. Granted I think this was useful as `alias_method_chain` was doing some equal if not far more complicated things to the object chain.

The book mentions trying to enforce this principle, and goes into a lot of code examples to do so:

```ruby
class OpenClosed
  # Be careful, `methods` is a real method
  def self.meths(m)
    m.instance_methods + m.private_instance_methods
  end
  
  # Overriding any inclusion that adds methods
  def self.include(*mods)
    mods.each do |mod|
      unless (meths(mod) & meths(self)).empty?
        raise "class closed for modification"
      end
    end

    super
  end
  
  singleton_class.alias_method :prepend, :include

  # Extend acts different so it needs to be overridden
  # for singleton_class rather than self.
  def self.extend(*mods)
    mods.each do |mod|
      unless (meths(mod) & meths(singleton_class)).empty?
        raise "class closed for modification"
      end
    end

    super
  end
end
```

Then gets into preventing methods from being redefined by storing a second copy via aliasing:

```ruby
meths(self).each do |method|
  alias_name = :"__#{method}"
  alias_method alias_name, method
end
```

...and hooking into `method_added` which catches all new method definitions to undo overwriting:

```ruby
check_method = true
define_singleton_method(:method_added) do |method|
  return unless check_method
  if method.start_with?('__')
    unaliased_name = method[2..-1]
    
    # Normally I avoid parens, but it makes it clearer what's
    # the condition and what's the body in cases like this.
    if (
      private_method_defined?(unaliased_name) ||
      method_defined?(unaliased_name)
    )
        check_method = false

        alias_method method, unaliased_name

        check_method = true

        raise "class closed for modification"
      end
    else
      alias_name = :"__#{method}"
      
      if (
        private_method_defined?(alias_name) ||
        method_defined?(alias_name)
      )

        check_method = false

        alias_method method, alias_name

        check_method = true

        raise "class closed for modification"
      end
    end
  end
end
```

Granted as the book mentions a clever and determined user can probably still get around this, and while a fun mental exercise I would likely avoid it in actual code, especially in libraries as there have been many times I've had to hot-patch something to get it to behave while waiting for maintainers to merge a patch upstream and release.

### The Liskov substitution principle

Liskov here is a principle that you can substitute a parent object with a child / subtype. The book mentions that a good general principle is to maintain the same signatures for methods where possible to ensure this works, and doing so certainly does make it much easier to swap out parts of your program.

It gives a few examples here:

```ruby
class Max
  def initialize(max)
    @max = max
  end

  def over?(n) = @max > 5
end

class MaxBy < Max
  def over?(n, by: 0) = @max > n + by
end
```

The signatures are technically different, but the default argument for `by` allows it to be used in place of `Max`.

The book then mentions that with duck typing in Ruby the language won't prevent you from doing any of this, and trusts you to make the right decisions for yourself.

Now a good point, `instance_of?` will break for subclasses:

```ruby
if obj.instance_of?(Max) # MaxBy won't work here
  # do something
else
  # do something else
end
```

It effectively means:

```ruby
obj.class == Max
```

When you probably want the more flexible `kind_of?` instead:

```ruby
if obj.kind_of?(Max)
  # do something
else
  # do something else
end
```

Which brings up a good point: prefer the more flexible approach unless you really need to lock things down. Ruby thrives on its flexibility, especially around interfaces like `===`.

### The interface segregation principle

This principle states that clients should not be forced to depend on methods they don't need. In Ruby that's not really applicable, as the book mentions, because it only uses methods which are called. The looser interpretation is what they chose to focus on here.

Classes with a significant number of methods where most users only use a small part of the methods may justify moving code out into extensions rather than have it all in one place, but the book mentions something interesting: which small part?

Every user is likely to have a subtly different part of the code they use.

Just because something has a lot of methods does not mean it should be broken up, and I agree strongly with that idea. The book advocates for only separating things that make sense and fall into logical groups rather than just because they're large.

### The dependency inversion principle

Dependency Inversion is the idea that high level modules shouldn't depend on lower level ones,  and that abstractions shouldn't depend on concrete implementations but rather the other way around. Bit of a mouthful there, but the examples clear that up:

```ruby
class CurrentDay
  def initialize
    @date = Date.today
    @schedule = MonthlySchedule.new(
      @date.year,
      @date.month
    )
  end

  def work_hours = @schedule.work_hours_for(@date)
  def workday? = !@schedule.holidays.include?(@date)
end
```

How would you go about testing this? It'd get real hard to deal with real fast, and the test example the book uses makes a strong case for that:

```ruby
before do
  Date.singleton_class.class_eval do
    alias_method :_today, :today
    define_method(:today) { Date.new(2020, 12, 16) }
  end
end

after do
  Date.singleton_class.class_eval do
    alias_method :today, :_today
    remove_method :_today
  end
end
```

While the book mentions multi-threaded tests as a prime concern it should be firstly noted that this approach is complicated in its own right even ignoring that. If you have to stub out core classes like this it may be time to reevaluate the underlying code, and the book does mention this:

```ruby
class CurrentDay
  def initialize(date: Date.today)
    @date = date
    @schedule = MonthlySchedule.new(date.year, date.month)
  end
end
```

By passing in the date it becomes much easier to test this, but the book goes on to ask if we should also allow `schedule` to be injected:

```ruby
class CurrentDay

  def initialize(
    date: Date.today,
    schedule: MonthlySchedule.new(date.year, date.month)
  )
    @date = date
    @schedule = schedule
  end

end
```

The book mentions this probably isn't ideal, but takes one step back to consider that perhaps we allow the method of scheduling to be passed in instead:

```ruby
class CurrentDay
  def initialize(
    date: Date.today,
    schedule_class: MonthlySchedule
  )
    @date = date
    @schedule = schedule_class.new(date.year, date.month)
  end
end
```

This starts getting into dependency injection, and as the book mentions it can make code far more complex and should be avoided unless really needed. As someone who's written DI systems I fully agree to not jump that shark unless it intends to jump you first.

Most of the reason you might want to do this is for mocking and making code easier to test and work with outside of its original context, but does make it easier to work with on occasion. As always though don't do it unless you actually need it.

## Deciding on larger classes or more classes

The next example comes into making larger classes or multiple smaller ones. It uses an HTML table to demonstrate this:

```ruby
require 'cgi/escape'

class HTMLTable
  def initialize(rows)
    @rows = rows
  end
  
  def to_s
    html = String.new
    html << "<table><tbody>"

    @rows.each do |row|
      html << "<tr>"
      row.each do |cell|
        html << "<td>" << CGI.escapeHTML(cell.to_s) << "</td>"
      end

      html << "</tr>"
    end

    html << "</tbody></table>"
  end
end
```

All the logic is in a single method, making it harder to test and reason about. It goes on to mention the idea of breaking out separate elements:

```ruby
class HTMLTable

  class Element
    def self.set_type(type)
      define_method(:type) { type }
    end

    def initialize(data)
      @data = data
    end

    def to_s
      "<#{type}>#{@data}</#{type}>"
    end
  end
  
  %i(table tbody tr td).each do |type|
    klass = Class.new(Element)
    klass.set_type(type)
    const_set(type.capitalize, klass)
  end
end
```

...which allows you to do this for a `to_s` method instead:

```ruby
def to_s
  Table.new(
    Tbody.new(
      @rows.map do |row|
        Tr.new(
          row.map do |cell|
            Td.new(CGI.escapeHTML(cell.to_s))
          end.join
        )
      end.join
    )
  ).to_s
end
```

While each `Element` is certainly only doing one thing the book mentions that they're also pretty similar.

It's also fairly slow from all the strings being created rather than having them in one place versus the initial example. The book lists them all off:

- The string containing the large data
- The string created by **CGI.escapeHTML**
- The string created in **HTMLTable::Td#to_s**
- The string created in **HTMLTable#to_s** when joining the array of **Td** instances
- The string created in **HTMLTable::Tr#to_s**
- The string created in **HTMLTable#to_s** when joining the array of **Tr** instances
- The string created in **HTMLTable::Tbody#to_s**
- The string created in **HTMLTable::Table#to_s**

It then goes on to mention a way around this:

```ruby
class HTMLTable

  def wrap(html, type)
    html << "<" << type << ">"
    yield
    html << "</" << type << ">"
  end


  def to_s
    html = String.new

    wrap(html, 'table') do
      wrap(html, 'tbody') do
        @rows.each do |row|
          wrap(html, 'tr') do
            row.each do |cell|
              wrap(html, 'td') do
                html << CGI.escapeHTML(cell.to_s)
              end
            end
          end
        end
      end
    end
  end
end
```

While it does certainly use less memory due to the mutation of the `String` I'm not quite sure I like it for the look, but I'm also a bit frontend-oriented in some cases.

Now for me I prefer flexibility over performance in these cases as it affords a nicer user interface and makes it easier to extend in my own style, so the way I might approach it would be to make a DSL like this:

```ruby
HTML.generate do
  strong 'test'

  br

  ul do
    li 'a'
    li 'b'
  end

  table do
    thead do
      th 'Name'
      th 'Age'
    end

    tbody do
      tr color: '#FF0' do
        td 'Brandon'
        td 30
      end

      tr color: 'yellow' do
        td 'Alice'
        td 42
      end
    end
  end
end
```

Want a challenge? See if you can make that work. [You can find how I did it here](https://gist.github.com/baweaver/53aef0b33a9b4cc12fca631371c0aa06).

## Learning when to use custom data structures

Something folks without lower-level language knowledge (relative to Ruby) might not appreciate what Hash and Array do behind the scenes to keep things optimized without inconveniencing the programmer, and it's a great addition to the book to mention this.

What this particular section is getting at is that most everything you're going to use in Ruby is going to rely on Hash and Array to implement higher level data structures of some type, and if you really need to make your own you're likely going to have to drop down to C to match performance.

The best part of this section? The mention that most likely you won't need to worry about all of this at all, but that it's nice to know just in case.

## Questions

### 1. Does creating a custom class make sense if you need both information hiding and custom behavior?

Sometimes. It'd depend on how significant the scope of that custom behavior is and how important it is to hide that information. If it's a very distinct case that's going to be used multiple times then of course it should. It not? Well perhaps it doesn't make sense quite yet.

### 2. Which SOLID principle is almost impossible to implement in Ruby?

Open-Closed, though there are arguments for the others one could make.

### 3. Is it useful to create classes that the user will not use directly?

Yes. For me there's a public API which the user will see and a more private API that underpins and supports the public API. That includes classes which have distinct concerns and data all their own that build into a larger picture, but perhaps not the one that the user wants to directly use.

After all, how often do you directly use `TSort` in Ruby? Well it underpins the entire dependency chain resolution for Bundler and a lot of other things you're probably using, but chances are you'll rarely if ever use it directly.

### 4. How often does it make sense to use custom data structures in Ruby?

Rarely if at all ever, and only if you're really trying to squeeze out those last bits of performance on larger data sets. Day to day though? Very unlikely.

## Wrap Up

Overall still enjoying the book, though I do think it has a bit of a habit of diving into the weeds on some topics more than others.

### The Concerns

Some of the work around Open-Closed took up a substantial portion of the chapter where it might have been hand-waved to say it's really hard to do as such and left it as an exercise to the reader. Compared to the other SOLID design sections that one outweighed them pretty significantly.

So far both of the chapters have been quite heavy, and take multiple sittings to really parse through. I wonder if they could have been broken up a bit more or shortened a bit for digestibility.

In the HTML table a code nit is that `%i"table tbody tr td"` may be hard to read when compared to `%i(table tbody tr td)` which makes it more distinct as a collection, but that's preference. I was having a lot of React flashbacks reading through that area, which definitely biases me towards certain design considerations, so take things with a grain of salt there.

### The Good

The best part of this book is that it does not assert one solution. It explains tradeoffs, concerns, nuance, and explores why you might make one decision versus another. It advocates for thinking and consideration over dogma and prescriptiveness of one solution. It's an exceptionally valuable trait to teach, and even if I don't agree with all the code decisions necessarily I can always respect where it came from and the reasoning behind it.

That's one of the biggest things about programming: I don't have to agree or even really particularly like someone else's code, but if it's well thought out and considered, and takes into account the concerns of those around them I'd probably approve it anyways.

It's not about me and my opinions as much as it is about finding solutions to problems which address concerns and tradeoffs, and documenting those so future developers can know the context of decisions and be able to read through the code with some clarity.

### Overview

Overall I still very much like the book. Most of my concerns tend to be more nits and formatting, most of which I try and leave out so as to not be petty. Sure, I amend the code to my style sensibilities, call it a bad habit if you will.

The main gripe I tend to have is solely on length and density, especially going through and writing comprehensive notes on each chapter as you might be able to tell from the "reading time" estimates ticking close to 20 minutes, but I also get why they're grouped that way.

In the next chapter we'll be taking a look at variable usage.
