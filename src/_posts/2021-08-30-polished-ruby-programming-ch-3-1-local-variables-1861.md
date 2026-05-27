---
layout: "post"
title: "Let's Read – Polished Ruby Programming – Ch 3.1 – Local Variables"
series: "lets-read-polished-ruby"
date: "2021-08-30"
tags: ["ruby", "books"]
---

[Polished Ruby Programming](https://www.packtpub.com/product/polished-ruby-programming/9781801072724) is a recent release by [Jeremy Evans](https://twitter.com/jeremyevans0), a well known Rubyist working on the Ruby core team, Roda, Sequel, and several other projects. Knowing Jeremy and his experience this was an instant buy for me, and I look forward to what we learn in this book.

You can find the book here:

https://www.packtpub.com/product/polished-ruby-programming/9781801072724

This review, like other "Let's Read" series in the past, will go through each of the chapters individually and will add commentary, additional notes, and general thoughts on the content. Do remember books are limited in how much information they can cram on a page, and they can't cover everything.

With that said let's go ahead and get started.

## Chapter 3 – Proper Variable Usage – Local Variables

The third chapter covers the following topics:

* Using Ruby's favorite variable type – the local variable
  * Increasing performance by adding local variables
  * Avoiding unsafe optimizations
  * Handling scope gate issues
  * Naming considerations with local variables
* Learning how best to use instance variables
  * Increasing performance with instance variables
  * Handling scope issues with instance variables
  * Naming considerations for instance variables
* Understanding how constants are just a type of variable
  * Handling scope issues with constants
  * Visibility differences between constants and class instance variables
  * Naming considerations with constants
* Replacing class variables
  * Replacing class variables with constants
  * Replacing class variables with class instance variables using the superclass lookup approach
  * Replacing class variables with class instance variables using the copy to subclass approach
* Avoiding global variables, most of the time

We'll be covering the first section on local variables to make this chapter's post more digestible.

### Using Ruby's favorite variable type – the local variable

The chapter starts in by explaining local variables in Ruby, and mentions they're the only type without a sigil. For a quick list here are a few you might find later:

* `@variable` - Instance variable
* `@@variable` - Class variable (generally avoid)
* `$variable` - Global variable (generally avoid)

We'll get into some of the issues with the latter two, as does the book, but for now we'll focus on local variables along with the book.

#### Increasing performance by adding local variables

Local variables are fast. The book mentions this, and most of the reason behind it comes from less indirection as previous chapters have mentioned. On the low level that means they're also more likely to be in the CPU cache.

The book opens with this code example:

```ruby
time_filter = TimeFilter.new(
  Time.local(2020, 10),
  Time.local(2020, 11)
)

array_of_times.filter!(&time_filter)
```

> *Note* - I dislike hanging indent, so I avoid it. You can read more into that [here](https://github.com/rubocop/ruby-style-guide/issues/359), but the short version is harder to maintain, longer diffs, and far harder to read with long-lines. Whitespace is free, use it.

Now the stated purpose of `TimeFilter` here is to return whether or not a `Time` is within the start and end of a range, but later sections here mention that if a beginning or ending is missing we'd likely want to treat it more like a begin-less range or an endless range.

> *Note* - That's a partial hint that ranges can also be used to solve this problem, give it a try and see if you can figure that out as a challenge.

Speaking of unidirectional filtering, the book continues with this example:

```ruby
after_now = TimeFilter.new(Time.now, nil)
in_future, in_past = array_of_times.partition(&after_now)
```

The idea being that `partition` can divide a list of times into ones occurring either in the future or in the past. Noted this is one reason so many harp on good variable names, as the ones used here make the intention more immediately clear for this code.

> *Editing Complaint*: Now the next bit confuses me, and feels poorly edited in context with the rest of the text. It mentions that we could implement this as a method on `Enumerable` and goes into a bit about using a class as a `Proc`. I feel like a paragraph was cut out here, making it very confusing.
>
> What I assume this was meaning to say was that one _could_ patch a method into `Enumerable` to achieve a similar effect with time ranges, but a class that can be coerced into a `Proc` is more flexible and does not patch Ruby.

##### The TimeFilter Class

Moving past that, the book then goes on to show an implementation of the class:

```ruby
class TimeFilter
  attr_reader :start, :finish

  def initialize(start, finish)
    @start = start
    @finish = finish
  end

  def to_proc
    proc do |value|
      next false if start && value < start
      next false if finish && value > finish

      true
    end
  end
end
```

The purpose of this section was to focus on optimizations that can be made to this implementation.

> *Note* - Before we get into this, and the book does mention it later, these are micro optimizations. More often than not this is completely overkill for optimizing a program, and the actual issues are going to be much higher level. Prefer code that is first working, readable, and understandable before pursuing these and make sure you have evidence before optimizing at this small of a scale.

The first optimization is around the `attr_reader` methods getting called repeatedly in the `to_proc` method. To get around that the book mentions binding these to local variables instead to only hit those methods once:

```ruby
def to_proc
  proc do |value|
    start = self.start
    finish = self.finish

    next false if start && value < start
    next false if finish && value > finish

    true
  end
end
```

The second optimization mentioned is variable hoisting, or moving those local variable bindings up above the `Proc` itself:

```ruby
def to_proc
  start = self.start
  finish = self.finish

  proc do |value|
    next false if start && value < start
    next false if finish && value > finish

    true
  end
end
```

This particular technique works because of closures, as the book mentions, which you can [read about more here](/writing/2021/02/07/understanding-ruby-blocks-procs-and-lambdas-24o0/). The short version is that functions in Ruby (`Proc`, block, lambda, etc) are closures, they remember the context they're created in, meaning they can access those variables.

The third optimizations mentioned are around limiting the scope of the function generated in the cases of a start or end date not being present:

```ruby
def to_proc
  start = self.start
  finish = self.finish

  if start && finish
    proc { |value| value >= start && value <= finish }
  elsif start
    proc { |value| value >= start }
  elsif finish
    proc { |value| value <= finish }
  else
    proc { |value| true }
  end
end
```

Just for the sake of curiosity though let's [run this through its paces](https://gist.github.com/baweaver/c35262cdd31f583e014b7e47e8848664):

```
Warming up --------------------------------------
          Original    66.000  i/100ms
             Local    72.000  i/100ms
     Hoisted Local    88.000  i/100ms
     Filtered Proc    98.000  i/100ms
    Filtered Range    83.000  i/100ms
Calculating -------------------------------------
          Original    655.049  (± 2.6%) i/s - 3.300k in 5.041153s
             Local    709.828  (± 3.9%) i/s - 3.600k in 5.080284s
     Hoisted Local    902.202  (± 2.9%) i/s - 4.576k in 5.076483s
     Filtered Proc    951.916  (± 3.0%) i/s - 4.802k in 5.049386s
    Filtered Range    825.598  (± 2.1%) i/s - 4.150k in 5.028796s
```

You can [find the code here](https://gist.github.com/baweaver/c35262cdd31f583e014b7e47e8848664), but note that I've also added a range just to see what'd happen.

##### Constants Example

This section has one more example on replacing constants with locals, but as mentioned in the previous section this is the type of thing you only need if you're really grinding things down to exceptionally small optimizations:

```ruby
num_arrays = 0
large_array.each do |value|
  if value.is_a?(Array)
    num_arrays += 1
  end
end
```

The first optimization is to hoist the `Array` constant:

```ruby
num_arrays = 0
array_class = Array

large_array.each do |value|
  if value.is_a?(array_class)
    num_arrays += 1
  end
end
```

Which doesn't seem very common, but the book puts another more interesting example here:

```ruby
large_array.reject! do |value|
  value / 2.0 >= ARGV[0].to_f
end

# Optimized
max = ARGV[0].to_f
large_array.reject! do |value|
  value / 2.0 >= max
end
```

...but then reminds us there are some mathematical optimizations:

```ruby
max = ARGV[0].to_f * 2
large_array.reject! do |value|
  value >= max
end
```

Now personally, for me, unless I really really need to optimize things I'm going to avoid bang (`!`) methods and mutation in general sections, as very very rarely have I had performance intensive enough sections to justify this level of optimization, but it can be handy to know if you ever find yourself in such a situation.

Really though, so much of my Ruby knowledge ends up being "just in case" rather than immediately applicable, and quite often I question the necessity of memorizing all of it. That said, if you're maintaining OSS like Jeremy does this type of thing can have multiplicative benefits across a significant number of Ruby applications in the wild.

Context matters more than strong opinions on how things should be done.

#### Avoiding unsafe optimizations

What I really appreciate here on the book is it mentions some of the cases where you can have issues. It mentions idempotency, or avoiding side-effects with those local variables, and uses this example:

```ruby
hash = some_value.to_hash

large_array.each do |value|
  hash[value] = true unless hash[:a]
end
```

...and the potential optimization:

```ruby
hash = some_value.to_hash
a_value = hash[:a]

large_array.each do |value|
  hash[value] = true unless a_value
end
```

...and then the trap implementation which will fail:

```ruby
hash = some_value.to_hash

unless a_value = hash[:a]
  large_array.each do |value|
    hash[value] = true
  end
end
```

The book mentions this as potentially dangerous as it assumes that the `large_array` does not contain an `:a` element or a default proc that deals with it. Personally I like the followup example with times a bit better:

```ruby
enumerable_of_times.reject! do |time|
  time > Time.now
end
```

...and the flawed optimization:

```ruby
now = Time.now

enumerable_of_times.reject! do |time|
  time > now
end
```

This one is quite a bit more complicated. `Time.now` is going to return a different time when called, introducing variance in the program. Perhaps you want that variance, perhaps not, so one does need to be aware of that. The book mentions cases in which the block yields at an interval slow enough to introduce substantial drift from the first call of `Time.now`, but even small drift can introduce all types of difficult bugs to track down.

The really concrete example which demonstrates the point of this area is if you have a `proc` checking whether a time is greater than now:

```ruby
greater_than_now = proc do |time|
  time > Time.now
end
```

In this case the definition of `now` is very important to be immediately at calling time, rather than having an older reference, meaning optimizing like this will break things:

```ruby
now = Time.now

greater_than_now = proc do |time|
  time > now
end
```

I really do appreciate that this book takes time to cover these cases instead of just going into optimizations directly.

#### Handling scope gate issues

Now this section can get a bit dense, and covers the visibility scope of local variables:

```ruby
defined?(a) # nil

a = 1

defined?(a) # 'local-variable'

module M
  defined?(a) # nil

  a = 2

  defined?(a) # 'local-variable'

  class C
    defined?(a) # nil

    a = 3

    defined?(a) # 'local-variable'

    def m
      defined?(a) # nil

      a = 4

      defined?(a) # 'local-variable'
    end

    a # 3
  end

  a # 2
end

a # 1
```

That was one of the reasons they'd used a lambda function in the first chapter.

> *Editing Note* - The book tends to switch between preferring Proc and Lambda, whereas it might be nicer to have some consistency there. Personally I prefer Lambda, but understand why `proc` might be preferred when referencing procs frequently. I still think that's a confusing choice in Ruby to have so many function types.

#### Naming considerations with local variables

The next section covers conventions in naming variables. The short version of what the book recommends is:

* Use `lower_case_ascii_snake_case` for local variables, preferably in ASCII
* Just because you _can_ use emojis does not mean you should
* Non-english languages can justify skipping ASCII, but may make it more difficult to work with
* Careful on how long your names are

Jeremy is right on length, there's a fine line between `is_a_long_phrase_like_this` versus something like `long_phrase`. Personally if a variable is that long it may be a hint that the variable is doing too much contextually and needs to be factored out.

There are three examples used on name length:

```ruby
# Using `a`, which is short for `album`
@albums.each do |a|
  puts a.name
end

# Using numbered params
@albums.each do
  puts _1.name
end

# Spelling out the full word
@albums.each do |album|
  puts album.name
end
```

As the book mentions `a` can be reasonably inferred from context, but that may be vague here:

```ruby
array.each do |a|
  puts a.name
end
```

Spelling out `album` isn't that long, and may be justifiable, but the next example makes a point against spelling things out every time:

```ruby
TransactionProcessingSystemReport.each do |transaction_processing_system_report|
  puts transaction_processing_system_report.name
end
```

Sure, it's accurate, but that's exhausting to read as the book mentions. It mentions a few abbreviations as alternatives here:

```ruby
TransactionProcessingSystemReport.each do |tps_report|
  puts tps_report.name
end

TransactionProcessingSystemReport.each do |report|
  puts report.name
end
```

Neither of which, to me, lose much value by abbreviating the name in terms of clarity.

Now the book mentions something interesting: the longer the method or block the more names matter. Using a single-letter name in a long method means the original context is harder to see at a glance, adding a lot more value to longer names.

There are, however, some common conventions in Ruby and most programming languages at that on single-letter names like:

```ruby
3.times do |i|
  type = AlbumType[i]
  puts type.name

  type.albums.each do |album|
    puts album.name
  end

  puts
end
```

`i`, `j`, `k`, and other such single-letters are going to be very familiar to a lot of C and Java programmers used to `for` loops. For integers this can make sense, especially as the book mentions for methods like `Integer#times`.

It also mentions `Hash` cases for key and value being `k` and `v` respectively:

```ruby
options.each do |k, v|
  puts "#{k}: #{v.length}"
end
```

...but quickly follows with a common case which would be nested hashes and conventions around `k2` and such:

```ruby
options.each do |k, v|
  k.each do |k2|
    v.each do |v2|
      p [k2, v2]
    end
  end
end
```

For this particular case, as the book mentions, `options` isn't really a `Hash`, it's a collection of keys and values. That means that the typical `Hash` convention doesn't really make sense any more no? It suggests this instead:

```ruby
options.each do |key_list, value_list|
  key_list.each do |key|
    value_list.each do |value|
      p [key, value]
    end
  end
end
```

Now this next part confuses me context wise, which involves gateless systems like `define_method` out of the blue. It mentions overwriting local variables unintentionally, but I believe this would have been better as its own section with a mention on the nuances of scoping, closures, shadowing, and related materials to give a broader overview. Scope gate does not feel as common a term to me, but I also come from a more functional background, so terms like closure are more familiar to me. Take with a grain of salt.

With that we're finished up the section on local variables.

The next section will cover instance variables.
