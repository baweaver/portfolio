---
layout: "post"
title: "Let's Read – Polished Ruby Programming – Ch 1"
series: "lets-read-polished-ruby"
date: "2021-07-08"
categories: ["ruby", "books"]
tags: ["ruby", "books"]
description: "Polished Ruby Programming is a recent release by Jeremy Evans, a well known Rubyist working on the..."
---

[Polished Ruby Programming](https://www.packtpub.com/product/polished-ruby-programming/9781801072724) is a recent release by [Jeremy Evans](https://twitter.com/jeremyevans0), a well known Rubyist working on the Ruby core team, Roda, Sequel, and several other projects. Knowing Jeremy and his experience this was an instant buy for me, and I look forward to what we learn in this book.

You can find the book here:

https://www.packtpub.com/product/polished-ruby-programming/9781801072724

This review, like other "Let's Read" series in the past, will go through each of the chapters individually and will add commentary, additional notes, and general thoughts on the content. Do remember books are limited in how much information they can cram on a page, and they can't cover everything.

With that said let's go ahead and get started.

# Chapter 1 – Getting the Most out of Core Classes

The book starts in with an overview of core classes, and the following topics:

* Learning when to use core classes
* Best uses for true, false, and nil objects
* Different numeric types for different needs
* Understanding how symbols differ from strings
* Learning how best to use arrays, hashes, and sets
* Working with Struct – one of the underappreciated core classes

We'll be covering each of those. From a glance this is a good overview of common confusing topics in Ruby.

## Learning when to use core classes

We start out with two examples, one which uses `Array` and one which uses a custom class `ThingList`:

```ruby
things = ["foo", "bar", "baz"]
things.each do |thing|
  puts thing
end

things = ThingList.new("foo", "bar", " baz")
things.each do |thing|
  puts thing
end
```

The point made here is that the first is much clearer than the second. Using `ThingList` introduces a lot of uncertainty versus the more known `Array`, especially because as mentioned why else would someone use that instead of an `Array`?

There are a lot of talks around this topic of extending core classes and some of the bad things that can happen around there, one in particular is ["Let's Subclass Hash - What's the worst that could happen?" by Michael Herold](https://www.youtube.com/watch?v=KzdSxgVPhXU). The short version is the `Hashie` gem tried to implement dot-access (`hash[:a]` can be called as `hash.a`) and there were all types of issues around that.

Jeremy's point here is a good one: Only go custom when you know the risks and the benefits you gain outweigh them.

Risks like performance, intuitive understanding, maintainability, and more come up frequently and should most certainly be taken into account.

## Best uses for `true`, `false`, and `nil` objects

### True and False

`true` and `false` are fairly universal concepts, and as mentioned if they meet your needs you should use them. One thing, however, to watch out for is that they're instances of `TrueClass` and `FalseClass`, Ruby doesn't really have a concept of `Boolean` unless you're using something like Steep or Sorbet.

The first case of when to use them is a predicate method, or one that ends with `?` in Ruby:

```ruby
1.kind_of?(Integer)
# => true
```

Other examples given are around equalities and inequalities:

```ruby
1 > 2
# => false

1 == 1
# => true
```

> **Note:**`===` behaves _very_ differently in Ruby, but that's a topic for a later discussion

For me it's a matter of whether you're answering a question. For predicate methods that's clear, for equalities and inequalities maybe a bit less so. Another common use tends to be around status updates, did something succeed or fail? Granted these tend to be more in tuple type pairs like `[true, response]` or `[false, error]`, but another subject for later.

### Nil

Next up he gets into `nil` and some of the common usages:

```ruby
[].first
# => nil

{1=>2}[3]
# => nil
```

`nil` should be understood as nothing, we return it when there's nothing to return. In the first case there's no first element of the `Array`, and in the second there's no key for `3`.

> **Note:** `Hash` can have a default value assigned through either `Hash.new(0)` or `Hash.new { |h, k| h[k] = [] }` which overrides the idea that "nothing" was there, but that's beyond the point being made here.

The tricky part, and one that was mentioned, is that `!nil` is `true` and `!1` is `false`:

```ruby
!nil
# => true

!1
# => false
```

That gets us patterns like this to "coerce" `Boolean`-like values:

```ruby
!!nil
```

In general `nil` should be avoided unless it's genuinely the case that there's "nothing" there. Consider this case:

```ruby
[1, 2, 3].select { |v| v > 4 }
# => []
```

Sure, we found "nothing", but a better response is an empty `Array` which is the "nothing" of this particular case. If we returned `nil` instead and tried to do this what do you think might happen?:

```ruby
[1, 2, 3].select { |v| v > 4 }.map { |v| v * 2 }
```

You would get some errors on it. In this particular case with `[1, 2, 3]` there's "nothing" there but in other cases like `[4, 5, 6]`? That's valid. One might notice some patterns here with "empty" or "nothing" values, but that strafes hard into Functional Programming territory and a very fun idea you could [read more about here](/writing/2021/01/08/introducing-patterns-in-parallelism-for-ruby-2f4a/) if you're particularly adventurous.

Point being, return sane defaults rather than `nil` when it makes sense.

### Bang (`!`) methods and Nil

Next up are some more confusing parts of Ruby, especially around bang (`!`) methods:

```ruby
"a".gsub!('b', '')
# => nil

[2, 4, 6].select!(&:even?)
# => nil

["a", "b", "c"].reject!(&:empty?)
# => nil
```

Jeremy mentions that this is done for optimization purposes to make sure that the receiver didn't make a modification. For me it's a reason I avoid `!` methods with some frequency as I've been caught by that more than once, and often times you really don't need them. General rule for me is to avoid mutation and mutating methods unless absolutely necessary as it breaks chaining and a lot of intuition about how Ruby works.

### Caching with false and nil

In both of the examples provided:

```ruby
@cached_value ||= some_expression

# or

cache[:key] ||= some_expression
```

If `some_expression` is `false` or `nil` it'll reevaluate instead of being "cached" for later use. The suggested alternative is to use `defined?` instead:

```ruby
if defined?(@cached_value)
  @cached_value
else
  @cached_value = some_expression
end
```

Personally I lean towards guard-style statements for method-based caches, but that's a matter of preference:

```ruby
def another_expression
  return @cached_value if defined?(@cached_value)
  @cached_value = some_expression
end
```

### Hash cache

He also mentions `Hash`es for caching using `fetch` which has some additional fun behavior:

```ruby
cache.fetch(:key) { cache[:key] = some_expression }
```

There are a few ways that `fetch` does things which may be important to mention here:

```ruby
hash = { a: 1 }
# => {:a=>1}

hash.fetch(:a)
# => 1

hash.fetch(:b, 1)
# => 1
hash.fetch(:b) { 1 }
# => 1

hash.fetch(:b)
# KeyError (key not found: :b)
```

If you `fetch` on a value which is not present without either a default or provided block it'll raise a `KeyError`, which can be _very_ useful for ensuring things are present.

### Memory Advantages

A good point to close on is that `true`, `false`, and `nil` are going to be faster than most other Ruby objects due to being immediate object types. That means there's no requirement for memory allocation on create or indirection on accessing them later, making them faster than non-immediate objects.

## Different numeric types for different needs

Next up we have different numeric types. Jeremy opens with a good point that in more cases than not you're probably just going to want an `Integer` type rather than fractional ones. Ruby also offers floats, rationals, and BigDecimal among a few others if you count non-base-10 variants. They're all under the `Numeric` class.

> **Note:** - As mentioned, `BigDecimal` is not required by default: `require 'big_decimal'`. It also has a particularly pesky compatibility break in which `BigDecimal.new` will break versus `BigDecimal()`. I still don't get why they didn't leave it and just alias it, but alas here we are.

He opens with an example using `times`:

```ruby
10.times do
  # executed 10 times
end
```

It may have been a good idea here to include the block variable as well and indicate that it receives each value:

```ruby
3.times do |i|
  puts i
end
# 0
# 1
# 2
```

...as the example referenced a `for` loop equivalency and this may lead to some confusion and introduction of counter variables where one is already built in to cover that case.

### Integer division and truncation

A common confusion point with `Integer`s and one that he brings up here is what happens with truncation:

```ruby
5 / 10
# => 0

7 / 3
# => 2
```

Chances are that's not exactly what was intended, so be careful when dividing to convert one of the digits to a different numeric type like `Rational` (because `Float` has its own bit of fun we cover later.)

It returns only the quotient and not the remainder or fractional parts thereafter. That's similar to C, and somewhat amusingly an interview question at some companies.

### Floats

Noted workarounds in the book use `Rational` or `Float` here:

```ruby
# or Rational(5, 10) or 5 / 10.to_r
5 / 10r
# => (1/2)

# Float
7.0 / 3
# => 2.3333333333333335
```

`Float` is noted as the fastest, but they're not precisely exact. [This site has a good explanation as to why](https://floating-point-gui.de/errors/rounding/#:~:text=Because%20floating%2Dpoint%20numbers%20have,omitted%20%2D%20the%20number%20is%20rounded.), but the short version is not enough digits to represent all numbers, and the more things you do to a `Float` the more apparent it becomes as in this example:

```ruby
f = 1.1
v = 0.0

1000.times do
  v += f
end

v
# => 1100.0000000000086
```

### Rationals

`Rational` can get around this with more precision, but is slower in general. If you're dealing with any type of money or things which require precision though `Float` is a _bad_ idea to use.

If we were to do that same code using `Rational` instead the book shows this:

```ruby
f = 1.1r
v = 0.0r

1000.times do
  v += f
end

v
# => (1100/1)
```

Now as far as speed Jeremy makes an excellent point which harkens back to YAGNI (You Aren't Going To Need It). They're maybe 2-6x slower, and micro-optimizations _rarely_ are the bottle neck for your code.

As he mentioned in the book rationals are great for when you need exact answers, and as mentioned earlier money is definitely one of those cases. In cases where you're just comparing numbers and not doing calculations? Yeah, `Float` is probably fine.

### BigDecimal

So where does that leave `BigDecimal` in this equation? Let's take a look at the examples provided:

```ruby
v = BigDecimal(1) / 3
v * 3
# => 0.999999999999999999e0

f = BigDecimal(1.1, 2)
v = BigDecimal(0)

1000.times do
  v += f
end

v
# => 0.11e4

v.to_s('F')
# => "1100.0"
```

`BigDecimal` uses scientific notation, as the name implies, so it can deal with very large numbers. The book doesn't go into a lot of detail here, and quite frankly I've rarely had to use them in Ruby myself.

Personally I like [this post](https://www.honeybadger.io/blog/ruby-currency/) by HoneyBadger on the subject of currency and when `BigDecimal` or `Rational` might be used.

## Understanding how symbols differ from strings

If there were a single issue in Ruby that's more confusing than most of the rest combined it would be `Symbol` vs `String` and when both are used. I have my personal opinions on this, but will save those for later.

Rails, as the book mentions, treats them indiscriminately as a solution to this annoyance with `Hash#with_indifferent_access` to bypass needing to care about the difference. In the background a lot of Ruby, as the book mentions, will also do this conversion.

So what are the two?

### Strings

> "A string in Ruby is a series of characters or bytes, useful for storing text or binary data. Unless the string is frozen, you append to it, modify existing characters in it, or replace it with a different string."

In most all cases I would advocate for freezing `String`s, Ruby even has the frozen string literal comment to do this that goes at the top of a file:

```ruby
# frozen_string_literal: true
```

This has been shown to improve application performance, and is often easier to work with as mutation (especially on receivers) can have all types of unintended consequences. We won't get into functional purity wars on this, but in general mutating methods in Ruby can make it harder to reason about code, so use sparingly.

I'll mention this later, but if frozen string literals were the default a lot of the use case for `Symbol` would become more difficult to justify, though there would still be some marginal performance gains from their implementation.

### Symbol

> "A symbol in Ruby is a number with an attached identifier that is a series of characters or bytes. Symbols in Ruby are an object wrapper for an internal type that Ruby calls **ID**, which is an integer type. When you use a symbol in Ruby code, Ruby looks up the number associated with that identifier. The reason for having an **ID** type internally is that it is much faster for computers to deal with integers instead of a series of characters or bytes. Ruby uses **ID** values to reference local variables, instance variables, class variables, constants, and method names."

This may be a bit of a complicated way to explain a `Symbol`, though does get into some important implementation details. More simply a `Symbol` is an identifying text to describe a part of your Ruby code.

Methods, for instance, can be identified by a `Symbol` representing their name like `def add` could be represented as `:add` elsewhere in the program, and passed to `send` to retrieve the method code:

```ruby
method = :add
foo.send(method, bar)
```

> **Caveat:** Personally I would prefer `method_name` here as `method` itself is a Method that can be used to get a `method` by name, which can be confusing.

Confusingly though this works as well, as mentioned by the book:

```ruby
method = "add"
foo.send(method, bar)
```

As the book mentions this is because Ruby is trying to be nice to the programmer, and honestly feels a bit self-aware to me that it knows this is confusing. Many `String` methods will work on a `Symbol`, compounding this.

The book mentions the following few examples:

```ruby
def switch(value)
  case value
  when :foo
    # foo
  when :bar
    # bar
  when :baz
    # baz
  end
end
```

In this one we're using `Symbol`s as identifying text rather than as text itself. If we were to want to _do_ something with `value`, however, `Symbol` would not make much sense:

```ruby
def append2(value)
  value.gsub(/foo/, "bar")
end
```

In this case `value` works as a `String`, so we should ensure a `String` is passed to it.

### Personal Opinions

Personally I believe that frozen strings, if optimized, could be used as more of an alternative to `Symbol`. Whatever performance gains there are from this are not worth the confusion it incurs on the users, and should be avoided.

Javascript, for instance, has the same JSON-like syntax as Ruby but treats the keys as `String` values instead:

```js
const map = { a: 1, b: 2, c: 3 };
map['a'] // => 1
map.a // => 1
```

Granted that later dot-syntax is a _really bad_ idea in Ruby as mentioned in that above `Hashie` talk from RubyConf, but that's another matter.

My main gripe is that for as much as Ruby gives value to the use of `Symbol` it sure likes to pretend they don't exist and coerce things to prevent users from getting errors in a lot of cases.

Anyways, personal rant over, I don't really see this changing in future versions of the language either as it would be far too large of a breaking change and not worth the migration pains on the community to do.

## Learning how best to use arrays, hashes, and sets

That's a lot to cover, and honestly one chapter isn't enough to cover a substantial portion of what makes even `Array` interesting in Ruby, but that's not the point of this book so I digress. At the least I would highly recommend reading into `Enumerable` on the [official docs](https://ruby-doc.org/core-3.0.1/Enumerable.html) after this chapter to get an idea of what all is possible.

### Array

```ruby
[[:foo, 1], [:bar, 3], [:baz, 7]].each do |sym, i|
  # ...
end
```

The example provided is a set of two-item tuples to represent data, not much to show here except that blocks can deconstruct values using arguments like `sym` and `i` here. Note that there's a real subtle thing to keep in mind on this versus a `Hash` though: You can have multiple instances of `:foo` here, but only one in a `Hash` which wants unique keys.

### Hash

The Hash example is very similar:

```ruby
{ foo: 1, bar: 3, baz: 7 }.each do |sym, i|
  # ...
end
```

The book mentions that the `Array` solution is likely more correct from a design perspective, but that the `Hash` is easier to implement. I would be inclined to agree with that, except in the case mentioned above where things could get complicated.

Consider if you had a set of tags coming in from AWS under `Array` tuples, representing that as a `Hash` would be a bad idea. Keep in mind your underlying data when deciding on how to express it in Ruby.

### Implementing an in-memory database

Now this is a more unique application of the two in a book that I've seen, and I really like that he's going for something with a bit more substance here. He starts out with generating some mock data to play with here:

```ruby
album_infos = 100.times.flat_map do |i|
  10.times.map do |j|
    ["Album #{i}", j, "Track #{j}"]
  end
end
```

It should be noted that `flat_map` flattens after mapping (transforming) a collection, but this book does assume intermediate Ruby knowledge to be fair.

#### Creating Indexes - Array Tuples

The first part of this involves indexing data, or giving a clear way to look up the data from multiple angles. If we were to make a simple index function for `Array` it might look like this (and Rails does something similar):

```ruby
class Array
  def index_by(&block)
    indexes = {}
    self.each { |v| indexes[block.call(v)] = v }
    indexes
  end
end
```

Remember that bit about unique keys though, as that does make things complicated. What if it indexes by a person's name but two people are named the same thing? Anyways, back to the problem solution they provide:

```ruby
album_artists = {}
album_track_artists = {}

album_infos.each do |album, track, artist|
  (album_artists[album] ||= []) << artist
  (album_track_artists[[album, track]] ||= []) << artist
end

album_artists.each_value(&:uniq!)
```

Granted for me I might have done something a bit more like this:

```ruby
album_artists = Hash.new { |h, k| h[k] = Set.new }
album_track_artists = Hash.new { |h, k| h[k] = Set.new }

album_infos.each do |album, track, artist|
  album_artists[album].add artist
  album_track_artists[[album, track]].add artist
end
```

...which prevents the need to conflate default assignment and later uniqueness constraints, as `Set` can only have unique values, but that also makes the solution more complicated and harder to explain in the first chapter so I can understand why it was written that way.

The lookup function is amusing:

```ruby
lookup = -> (album, track = nil) do
  if track
    album_track_artists[[album, track]]
  else
    album_artists[album]
  end
end
```

Why? Well ones first instinct might be to create a method like so:

```ruby
def lookup(album, track = nil)
  # ...
end
```

...but where exactly does it get the `album_artists` and `album_track_artists` then? This solution avoids that by using lambda functions, which capture the local context they're defined in through what's called a closure.

Granted I think this is a bit unusual in Ruby and not quite common use, but prevents the need for wrapping all of this in a class and substantially lengthening the chapter. Not sure I'd advocate for it elsewhere though.

(You'll also note I make a point not to implement it as such myself for the length of the article)

#### Creating Indexes - Nested Hashes

The second solution uses nested hashes instead:

```ruby
albums = {}

album_infos.each do |album, track, artist|
  ((albums[album] ||= {})[track] ||= []) << artist
end
```

...and as with the previous case it may be worthwhile to decouple assignment and default values by promoting that code to the initial object instantiation:

```ruby
albums = Hash.new do |h, k|
  h[k] = Hash.new { |h2, k2| h2[k2] = [] }
end
```

Is it less succinct? Sure, but it's also explicit about the shape of our data which I believe to be a good tradeoff.

The lookup code, as the book does mention, becomes far more complex for this:

```ruby
lookup = -> (album, track = nil) do
  if track
    albums.dig(album, track)
  else
    a = albums[album].each_value.to_a
    a.flatten!
    a.uniq!
    a
  end
end
```

What I like about this book is that Jeremy mentions the tradeoffs of each of these approaches. The `Array`-tuple approach takes a lot more memory, but has much faster lookup for a large number of records. The second is far more inefficient on just `album` lookups, but excels in nested queries.

### Creating Indexes - Known Data

What he does in the next section though is an interesting insight on knowing the underlying data and what that affords us.

```ruby
albums = {}

album_infos.each do |album, track, artist|
   album_array = albums[album] ||= [[]]
   album_array[0] << artist
   (album_array[track] ||= []) << artist  
end

albums.each_value do |array|
  array[0].uniq!
end
```

Unlike previous sections this assumes that the first item will be the artists, and `1` to `99` will be the tracks. We _could_ explicitly model the data but that gets pretty messy:

```ruby
TRACK_COUNT = 99

albums = Hash.new { |h, k| h[k] = [Set.new, *([] * TRACK_COUNT)]}
```

...which I don't particularly like, but does expose that this data structure is a bit perilous.

One trick here is that Ruby's `dig` function works with both `Hash` and `Array`, meaning numbered indexes work here, making the lookup function much simpler:

```ruby
lookup = -> (album, track = 0) do
  albums.dig(album, track)
end
```

...but the code can be brittle when it comes to changing requirements unlike the other two as it's very tightly bound to the shape of the data. You can eek out some extra performance here, but it may not be worth it if you ever need to revisit and refactor it later.

#### Known Artist Names - Array

The next section wants to develop a feature for finding known artists names in albums versus a list of user-provided ones:

```ruby
album_artists = album_infos.flat_map(&:last)
album_artists.uniq!

lookup = -> (artists) do
  album_artists & artists
end
```

#### Known Artist Names - Hash

...but mentions that this can be slow with large counts of artists. A proposed counter-solution uses a `Hash` to key known artists:

```ruby
album_artists = {}

album_infos.each do |_, _, artist|
  album_artists[artist] ||= true
end

lookup = -> (artists) do
  artists.select do |artist|
    album_artists[artist]
  end
end
```

Though this may be easier with `values_at`:

```ruby
lookup = -> (artists) do
  album_artists.values_at(*artists)
end
```

#### Known Artist Names - Set

...but the point of this exercise is to lead us to `Set`, so let's get to that instead:

```ruby
require 'set'

album_artists = Set.new(album_infos.flat_map(&:last))

lookup = -> (artists) do
  album_artists & artists
end
```

The difference here is that `Set` is much faster than the `Array` approach, but not quite as fast as the `Hash` one. The book recommends the former for the nicer API, and the latter if you need the performance gain.

## Working with Struct – one of the underappreciated core classes

See, I really like `Struct`, especially when I'm in a REPL. Glad to see it here. Jeremy starts with an example here of a normal class:

```ruby
class Artist
  attr_accessor :name, :albums

  def initialize(name, albums)
    @name = name
    @albums = albums
  end
end
```

If you've ever felt like a lot of that was redundant you'll really love `Struct`:

```ruby
Artist = Struct.new(:name, :albums)
```

...though personally I like kwargs for classes to be clear about what exactly you're passing to it, and `Struct` also covers that case:

```ruby
Artist = Struct.new(:name, :albums, keyword_init: true)
Artist.new(name: 'Brandon', albums: [])
```

Clearer to me. Anyways, the book mentions the tradeoffs that `Struct` is lighter than a `class` but takes longer to look up attributes.

He does mention an interesting property of `Struct`, a new instance is actually a `Class`:

```ruby
Struct.new(:a, :b).class
# => Class
```

### Subclassing Struct

Though that's not the case with subclasses as mentioned:

```ruby
Struct.new('A', :a, :b).new(1, 2).class
# => Struct::A
```

...and he also notes an implementation of what the `Struct.new` method might look like:

```ruby
def Struct.new(name, *fields)
  unless name.is_a?(String)
    fields.unshift(name)
    name = nil
  end
  
  subclass = Class.new(self)

  if name
    const_set(name, subclass)
  end
  
  # Internal magic to setup fields/storage for subclass
  def subclass.new(*values)
    obj = allocate
    obj.initialize(*values)
    obj
  end

  # Similar for allocate, [], members, inspect
  # Internal magic to setup accessor instance methods
  subclass
end
```

If you happen to pass a name like `'A'` to it it'll define a constant on the current namespace with that subclass attached to it. There's a bit of hand-waving on underlying details here, which would definitely take a bit, then the final section on actually making a new instance.

Personally I would almost rather avoid this in favor of the later mentioned subclassing:

```ruby
class SubStruct < Struct
end
```

...and the above code may be a bit much for what you need to know about `Struct` for most cases.

### Frozen Structs

There is mention in the next section about automatically freezing structs:

```ruby
A = Struct.new(:a, :b) do
  def initialize(...)
    super
    freeze
  end
end
```

...which makes values immutable. Jeremy also mentions that there were several Ruby tracker issues filed to make this a more mature feature, but none made it into Ruby 3, and this is the most viable workaround.

Personally I like the idea of immutable small data types ala Haskell and Scala case classes for quick usage as containers of data rather than domain objects.

## Summary and Questions

The chapter ends off with a summary and some questions. Let's take a look at the questions real quick.

### 1. How are **nil** and **false** different from all other objects?

`nil` is literally nothing, and quite frequently errors you see in Ruby are due to one getting in somewhere where the application does not expect it.

`false` is an instance of `FalseClass`, so not sure I get the intent of this particular question when juxtaposed with `nil`. Perhaps this would be phrased better on what the intentions of these data types are instead?

### 2. Are all standard arithmetic operations using two BigDecimal objects exact?

On two `BigDecimal` types yes, but if a `Float` gets on one side not as much.

### 3. Would it make sense for Ruby to combine symbols and strings?

Philosophically? I want `Symbol` to go away because it makes things far more complicated for new Rubyists for very very little real gains, and even trips me up on a semi-frequent basis. I dislike them for the complexity they introduce to the language.

Pragmatically? No. It should be left as is, as the fallout of changing that would break untold amounts of Ruby code and start one heck of a war in the community. It's not worth the cost, as much as I dislike it.

### 4. Which uses less memory for the same data - hash, or **Set**?

Probably `Hash`, but not by much. I seem to recall that `Set` is implemented in terms of a `Hash` anyways so it can't be that far off.

### 5. What are the only two core methods that return a new instance of **Class**?

`Struct.new` and `Class.new` I'd think.

## Wrap Up

### The Good

In general? Pragmatism. Jeremy excels in making tradeoffs and explaining why certain things are done a certain way, and that shows in a lot of his work. Is it the best solution? Maybe not, but it accounts for edge cases, and that's where he really excels: digging into those very details.

The book takes a pragmatic stance on addressing performance implications of different data structures and their usages. Not many do that.

It took time to address one of the elephants in the Ruby community around `Symbol` and `String` and had a fairly reasoned response to it. I might have liked to see the implications of removing one, but understand that that'd ballon the size of this chapter real quick.

It took a bolder stance in introductory problem with `album`, which gave a lot more of a chance to explore interesting code. Too many examples feel really basic and don't really show a lot of potential concerns, and I think this book gets that right.

### The Bad

Safari Books Online has an early access version with all the code line-breaked and in serif font, no highlighting. I wish Packt would fix this as that's near impossible to read as-is. I do hope the physical book fixes this.

As far as the book itself I feel like the first chapter tries to put a _lot_ of content into one chapter, and may have been better served by breaking it up into more sections.

I do wish that the section on `true`, `false`, and `nil` went more into reasoned default values rather than dive into bang methods as much as it did, as those will find more use in a lot of Ruby programs to prevent errors.

Some of the examples tended to conflate assignment and concatenation behavior, and may have been better served by explicitly defining data structures above the code over `||=` use.

The section on `Struct` veered from a very useful overview to a bit into the weeds and lost me.

### Overview

I intend to keep reading and writing similar read-alongs for other chapters, and look forward to what's next.

Do I have objections with some of the content? Sure, but I have objections with my own code from last month, I just make sure to understand why decisions were made and note factors around it as I can. That's what makes these reviews fun is giving additional context and exploring why certain subjects are covered.

See you all in chapter 2!
