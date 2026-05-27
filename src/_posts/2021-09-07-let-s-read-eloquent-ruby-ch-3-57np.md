---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 3 – Smart Collections"
series: "lets-read-eloquent-ruby"
date: "2021-09-07"
tags: ["ruby", "books"]
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2021 — Ruby 3.0.x).

> **Note**: This is an updated version of a previous unfinished Medium series of mine you can [find here](/writing/2018/09/21/lets-read-eloquent-ruby-ch-1/).


## Chapter 3. Take Advantage of Ruby's Smart Collections

This chapter covers some of Ruby's collection classes and how to work with them. In Ruby this is probably going to be one of your most powerful and often used sets of libraries and features to work with, and in my early days I frequently found myself consulting this chapter and all the documentation related to it.

The book mentions here that if you were to look into any well-sized Ruby program you're going to find a ton of `Array`s and `Hash`es scattered throughout, and all of the operations that occur on them. I've found this to be exceptionally true, and as mentioned above it's one of the most powerful parts of the language.

`Enumerable`'s documentation is going to get a lot of reference as you learn Ruby and become more effective in it.

### Literal Shortcuts

The book mentions a few ways of constructing an `Array` to start with:

```ruby
# The normal way
poem_words = ['twinkle', 'little', 'star', 'how', 'I', 'wonder']

# Whitespace delimited words, same as the above
poem_words = %w{twinkle little star how I wonder}
```

Now one qualm I have with the book here is that `{}` can be confused with `Hash` later, and you're more likely to find common usage of either `%w()` or `%w[]` in its place. There are others, but by that point it's becoming a bit ridiculous. Personally I prefer `%w()`, but can see why the other is popular:

```ruby
poem_words = %w(twinkle little star how I wonder)
```

The next bit covers `Hash`es, and the hash rocket (`=>`):

```ruby
freq = { "I" => 1, "don't" => 1, "like" => 1, "spam" => 963 }
```

For `String` keys you'll find that in common use, but `Symbol` keys are a bit different:

```ruby
book_info = { :first_name => 'Russ', :last_name => 'Olsen' }

book_info = { first_name: 'Russ', last_name: 'Olsen' }
```

They produce the same `Hash`, but one uses the `1.9.x` "JSON-style" syntax. Very likely that syntax will look familiar as you find keyword arguments in methods as well, and it's generally preferred.

> **Personal Hill**: Granted I really wish that `Symbol` keys would just be translated to `String` as this causes a lot of confusion for newer programmers for little gain, especially now that `String`s are so commonly frozen. As always when I mention this I acknowledge there's 0% chance this changes, but I still find it a particularly frustrating part of Ruby.

### Instant `Array`s and `Hash`es from Method Calls

The book goes on to mention ways of getting an `Array` or a `Hash` from a method call, in what is called a "splat" (`*`) or "keyword/hash splat" (`**`):

```ruby
def echo_all(*args)
  args.each { |arg| puts arg }
end

def echo_at_least_two(first_arg, *middle_args, last_arg)
  puts "The first argument is #{first_arg}"
  middle_args.each { |arg| puts "A middle argument is #{arg}" }
  puts "The last argument is #{last_arg}"
end
```

Wherein the first is called a "varadic" method taking any number of arguments, and the second is much the same except that splat can be anywhere in the list. You can also do this on assignments:

```ruby
a, *bs = [1, 2, 3]
# a = 1, bs = [2, 3]

a, *bs, c = [1, 2, 3]
# a = 1, bs = [2], c = 3
```

The book then goes on to mention explicit versus implicit `Array`s:

```ruby
class Document
  def add_authors(names)
    @author += " #{names.join(' ')}"
  end
end

class Document
  def add_authors(*names)
    @author += " #{names.join(' ')}"
  end
end
```

In the first case it would need to be called as such:

```ruby
document.add_authors(%w(Jemisin Schwab))
```

...but the second might be:

```ruby
document.add_authors('Le Guin', 'Hobb')
```

(Note that Ursula Le Guin would break that code's space delimiter, how might you fix it?)

The book then goes into a similar section on `Hash`es with `load_font`:

```ruby
def load_font(specification_hash)
  # details omitted
end

load_font({ name: 'Helvetica', size: 12 })
```

If we happened to use the double-splat (or keyword splat, hash splat, or other names):

```ruby
def load_font(**specification_hash)
  # details omitted
end

load_font(name: 'Helvetica', size: 12)
```

> **Warning**: The book mentions that you can omit braces in the first case, but with Ruby 3.x+ this becomes complicated and is not recommended. Prefer to be explicit, and give the [Ruby 2 Keyword Argument conundrum a read](https://eregon.me/blog/2021/02/13/correct-delegation-in-ruby-2-27-3.html).

### Running Through Your Collection

The book starts with a `for` loop example it quickly discourages afterwards:

```ruby
words = %w(Mary had a little lamb)

for i in 0..words.size
  puts words[i]
end

# Though I think this is a more common variant to folks:
for word in words
  puts word
end
```

If you really want to know why you should avoid `for` in detail beyond "just use `each`" give [this post a read](/writing/2021/07/31/understanding-ruby-for-vs-each-47ae/), or just take our word for it on using `each` instead. The `each` variant of that code would be:

```ruby
words.each { |word| puts word }
```

As the book mentions `Hash`es also have an `each` method:

```ruby
movie = {
  title: '2001',
  genre: 'sci fi',
  rating: 10
}

# Single-argument yields the key and value as an Array
movie.each { |entry| pp entry }
# [:title, "2001"]
# [:genre, 'sci fi']
# [:rating, 10]

# This allows access to the key and the value:
movie.each { |name, value| puts "#{name} => #{value}" }
# title => 2001
# genre => sci fi
# rating => 10
```

> **Note**: The book likes to use `pp` without mentioning it. It stands for [Pretty Print](https://ruby-doc.org/stdlib-3.0.2/libdoc/pp/rdoc/PP.html), which is not really useful for most of the cases in this chapter, but can be for larger collections when you want it to be readable rather than a single-line you have to scroll to get through.

Now after this the book starts dropping hints for `Enumerable` and all the handy methods in it. Consider this, a potential method for finding the index of a word in a document:

```ruby
def index_for(word)
  i = 0
  words.each do |this_word|
    return i if word == this_word
    i += 1
  end
  nil
end
```

Ruby has a lovely method which already takes care of this called `find_index`:

```ruby
def index_for(word)
  words.find_index { |this_word| word == this_word }
end
```

Now I do have some slight qualms with the naming here, as `word` would be better as the iterated variable, and `this_word` could be the argument instead and renamed to `target_word` for intent, making this:

```ruby
def index_for(target_word)
  words.find_index { |word| word == target_word }
end
```

...which personally I find a bit easier to read at a glance for a few reasons:

1. `target_word` makes the searched word more distinct than `word`
2. `word` is more suited to the generic word in a collection
3. Shifting `word` to the left gives it proximity to the block argument, making it easier to read left-to-right.

Now that last one is interesting, and will come up again in later sections. Proximity, and left-to-right, are very important in general readability of code and should be kept in mind. Names equally so.

If we had `word` at the end our eye has to go to the right to find where it's used, then back left to find what it's being compared to. Because `word` is more proximate to that scope it reads better when put first in that block.

I find this to be something I tend to do without thinking of it, but it has made code a lot easier to read at a glance and reduce jumping.

Anyways, back to the book, where we take a look into `map` which returns a new `Array` transformed by a block function:

```ruby
[1, 2, 3].map { |v| v * 2 }
# => [2, 4 , 6]
```

The book uses this example of a hypothetical document, which I find a bit less clear for building immediate intuition:

```ruby
doc.words.map { |word| word.size }
# => [3, 5, 2, 3, 4]
```

...and a way to lowercase all of those words:

```ruby
lower_case_words = doc.words.map { |word| word.downcase }
```

It then goes into `inject` which I'll be using `reduce` instead as you'll find it more commonly in other languages (also `foldLeft` which isn't present in Ruby, but _does_ more clearly articulate the function of the method).

The example the book uses is finding the average word length in a document:

```ruby
class Document
  # The initial case, and the way you might approach it
  def average_word_length
    total = 0.0
    words.each { |word| total += word.size }

    total / word_count
  end

  # The same done with reduce
  def average_word_length
    # Yes, I swapped the order here to put result first
    total = words.reduce(0.0) { |result, word| result + word.size }
    total / word_count
  end
end
```

Now that's a bit hard to understand if you've never seen `reduce` before, so try this example real quick:

```ruby
[1, 2, 3].reduce(0) do |accumulator, v|
  p accumulator: accumulator, v: v, new_accumulator: accumulator + v
  accumulator + v
end
# {:accumulator=>0, :v=>1, :new_accumulator=>1}
# {:accumulator=>1, :v=>2, :new_accumulator=>3}
# {:accumulator=>3, :v=>3, :new_accumulator=>6}
#  => 6
```

The idea is that `reduce` is reducing a collection of items into one item, in this case a number `0`. `accumulator` starts as `0`, and each loop becomes the value returned from the block function as we see in `new_accumulator` before the next loop. Whatever the value of the `accumulator` is at the end is the value we get returned.

If you want to read more into `reduce` [take a look at this article](/writing/2021/02/12/understanding-ruby-enumerable-combining-58eo/) where I explain it in more detail, and a [conference talk I did called Reducing Enumerable](https://www.youtube.com/watch?v=x3b9KlzjJNM) which goes into far more detail.

Now that all said Ruby 2.4 introduced a method called `sum` which makes all of this much easier:

```ruby
[1, 2, 3].sum
# => 6
```

...which makes that above document method look more like this:

```ruby
class Document
  def average_word_length = words.sum(&:size).fdiv(word_count)
end
```

How's that for succinct? See [this post](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/) and search for Ampersand (`&`) and `to_proc` for more information on that shorthand.

> **Note**: `fdiv` is float division, which is more explicit than using `0.0` for an accumulator, or converting one of the values to a float.

There are still uses for `reduce`, sure, but I find they're rather rare and normally there are clearer methods to use in `Enumerable` you should consider first. That said, it's also exceptionally powerful and you could quite literally reimplement every other `Enumerable` method with `reduce` as well.

Chainsaws for trimming bonsai trees and such, use the least amount of power you need to get something done, and appearing clever surely isn't a valid reason to reach for a more powerful tool. Readability first, remember that one, it'll save you nightmares later.

### Beware the Bang!

In Ruby a bang (ending with `!`) method is usually a warning sign, often related to a method mutating something or having some other side effect. Let's take a look at the book's example on `reverse`:

```ruby
a = [1, 2, 3]
a.reverse
# => [3, 2, 1]

a
# => [1, 2, 3]
```

This version returns a new `Array` without mutating the old one, but the bang method?

```ruby
a
# => [1, 2, 3]
a.reverse!
# => [3, 2, 1]
a
# => [3, 2, 1]
```

It mutates `a`. As an aside, Javascript's `reverse` totally mutates an `Array`, ask me sometime why I know...

The book mentions that `sort` and `sort!` behave similarly, but makes the lovely followup that methods like `push`, `pop`, `delete`, and `shift` also modify an `Array` too without a bang.

It mentions several methods may mutate things, so there's not always consistency here and it's best to be aware. Bang methods also tend to return `nil` in some cases when something does not change:

```ruby
s = 'string'
s.gsub(/b/, 'c')
# => 'string'
s.gsub!(/b/, 'c')
# => nil
```

...meaning you can't chain things. They're faster, sure, but you trade a lot of what makes Ruby chaining so nice by doing so.

### Rely on the Order of Your `Hash`es

In the next section it mentions something which can be very useful, but very different from other languages:

`Hash`es in Ruby retain insertion order.

That means running this code does this:

```ruby
hey_its_ordered = { first: 'mama', second: 'papa', third: 'baby' }
hey_its_ordered.each { |entry| pp entry }
# [:first, 'mama']
# [:second, 'papa']
# [:third, 'baby']
```

...and adding one more element:

```ruby
hey_its_ordered[:fourth] = 'grandma'
```

...puts it at the end. The book also mentions that changing an existing element does not reorder things.

This section hasn't really changed much if at all from Ruby 1.9, so there's not much to comment on here.

### In the Wild

The book then goes into a few examples. The first examples are mainly covering class-methods which don't return an instance, but rather a collection. A few of those examples:

```ruby
File.readlines('/etc/passwd')
object.public_methods
my_class.ancestors
```

Those types of methods tend to be common where Ruby will return a collection or other appropriate type, but the next example is a little clearer where generic collections really come in handy as a return type.

Let's take this XML:

```xml
<characters>
  <super-hero>
    <name>Spiderman</name>
    <origin>Radioactive Spider</origin>
  </super-hero>

  <super-hero>
    <name>Hulk</name>
    <origin>Gamma Rays</origin>
  </super-hero>

  <super-hero>
    <name>Reed Richards</name>
    <origin>Cosmic Rays</origin>
  </super-hero>
</characters>
```

If we were to parse that into Ruby we'd get something like this:

```ruby
require 'xmlsimple'
data = XmlSimple.xml_in('dc.xml')

# Returns:
{
  "super-hero" => [{
    "name" => ["Spiderman"],
    "origin" => ["Radioactive Spider"]
  }, {
    "name" => ["Hulk"],
    "origin" => ["Gamma Rays"]
  }, {
    "name" => ["Reed"],
    "origin" => ["Cosmic Rays"]
  }]
}
```

It's really something just how much you can express with `Hash`es and `Array`s in Ruby, and very frequently (and admittedly not always a great idea) I tend to avoid classes in favor of them until I get a tangible benefit from abstracting that data into a class wrapper.

`Array`s and `Hash`es are simple to work with, have known interfaces, and don't require additional effort beyond language knowledge to use effectively.

### Staying Out of Trouble

The book warns about manipulating a collection you're currently iterating on. In one case it's not a great idea to mutate state, but mutating the state of something that's currently in use like iteration? That's just asking for problems and errors.

Consider the book's example here:

```ruby
array = [0, -10, -9, 5, 9]
array.each_index { |i| array.delete_at(i) if array[i] < 0 }
pp array
# => [0, -9, 5, 9]
```

It skips `-9` because the element at that index just shifted with the deleted element.

The book then mentions making large `Array`s inadvertently like so:

```ruby
array = []
array[24601] = "Jean Valjean"
```

...being a reference to Les Miserables, but every element up to `24601` is now `nil` and that's not free in terms of memory.

The next example the book gets into is a unique list of words using a few different methods:

```ruby
word_is_there = {}
words.each { |word| word_is_there[word] = true }

unique = []
words.each { |word| unique << word unless unique.include?(word) }
```

The second being much much slower as it has to iterate that `unique` list multiple times to find if a word is unique. `Hash`es have a lookup time of `O(1)`, whereas `Array`s are more of an `O(n)` lookup time.

While one can use the Hash case for this, `Set` is easier:

```ruby
require 'set'
word_set = Set.new(words)
```

...or get into `Enumerable` and find the `uniq` method:

```ruby
words.uniq
```

...which encapsulates the entire idea quite nicely without the extra work.

### Wrapping Up

In Ruby chances are real high you're going to encounter collections, so knowing what they are and how they're used is a massive boost in your early productivity for both reading and writing.

Over the years Ruby has added a lot of `Enumerable`, Pattern Matching, and other features which make dealing with collections much easier. Later chapters will cover this, but that shouldn't stop you from taking a glance at a few in the docs.

The next chapter covers `String`s, which will be the other most likely candidate for things you'll encounter and have to work with in Ruby.
