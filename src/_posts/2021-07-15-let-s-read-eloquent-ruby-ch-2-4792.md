---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 2 – Control Structures"
series: "lets-read-eloquent-ruby"
date: "2021-07-15"
tags: ["ruby", "books"]
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2021 — Ruby 3.0.x).

> **Note**: This is an updated version of a previous unfinished Medium series of mine you can [find here](/writing/2018/09/21/lets-read-eloquent-ruby-ch-1/).


## Chapter 2. Chose the Right Control Structure

This chapter covers the use of control structures in Ruby like `if`, `unless`, and other branch type methods.

### If, Unless, While, and Until

`if` statements look pretty well the same as you’d expect, except for the lack of parens:

```ruby
class Document
  attr_accessor :writeable
  attr_reader :title. :author, :content
  
  # Much of the class omitted...
  
  def title=(new_title)
    if @writeable
      @title = new_title
    end
  end
  
  # Similar author= and content= methods omitted...
end
```

Now the interesting part in Ruby is if we inverted that logic to say something quite the opposite, as the book mentions:

```ruby
def title=(new_title)
  if !@read_ony
    @title = new_title
  end
end
```

*(Note that I’d switched* `*not*` *with* `*!*` *as english operators aren’t often used. Granted I abuse this, but again, grain of salt)*

The book mentions inverse operators, essentially saying:

```ruby
if !    == unless
while ! == until
```

They’re just more concise ways to say the opposite.

It should be noted that in the case of `unless` , it’s typically considered bad form to use an `else` branch in the [Ruby Style Guide](https://github.com/rubocop-hq/ruby-style-guide#no-else-with-unless):

```ruby
unless condition
  # ...
else
  # ...
end
```

This is done to assert the positive part of the condition first and foremost, as `else` is essentially the inverse of an `unless` condition.

### Use the modifier forms where appropriate

If you’re wondering why I didn’t mention the post conditional form earlier, it’s because the book brings it up in this section.

Essentially the post conditional, or modifier form is taking this:

```ruby
unless @read_only
  @title = new_title
end
```

and writing it with the condition as a suffix:

```ruby
@title = new_title unless @read_only
```

This can be done with `while` and `until` as well

```ruby
document.print_next_page until document.printed?
```

These are very widely used, but be careful when lines start getting long and blocks get involved:

```ruby
data.each do |datum|
  # ...
end if condition
```

...because that becomes less readable and more a battle of remembering to check the end of the block for surprises.

This is one of the few cases where I’d argue against 80+ characters on a line: If you cannot see the intent of a line at a glance while reading down the page it’s too long. Doubly so for modifiers at the end of them.

### Use each, not for

Ruby *does* have a for loop, but it’s also slower and implemented in terms of each:

```ruby
for font in fonts
  puts font
end
```

`each` is preferred, especially once you get into Enumerable methods which build off of it:

```ruby
fonts.each do |font|
  puts font
end
```

There are additional advantages to using block style methods, primarily around block functions themselves and symbol’s fun little `to_proc` coercion:

```ruby
fonts.each(&:register)

# ...is the same as:
fonts.each { |font| font.register }
```

If you end up into composition and other things, the fact that all these methods take blocks becomes an insane advantage for more advanced Ruby.

Put bluntly there are no advantages to using a `for` loop in Ruby except that it feels more like another language.

### A case of programming logic

The case statement is one of my personal favorites:

```ruby
case title
when 'War And Peace'
  puts 'Tolstoy'
when 'Romeo And Juliet'
  puts 'Shakespeare'
else
  puts "Don't know"
end
```

As it’s an expression, much like if, we can use it to assign a variable:

```ruby
author =
  case title
  when 'War And Peace'
    'Tolstoy'
  when 'Romeo And Juliet'
    'Shakespeare'
  else
    "Don't know"
  end
```

#### A Note on Indentation

You might notice my style of indentation is different here. The original looks like this:

```ruby
author = case title
         when 'War And Peace'
           'Tolstoy'
         when 'Romeo And Juliet'
           'Shakespeare'
         else
           "Don't know"
         end
```

The problem with this style of indentation is that it will be subject to the variable name. What if I changed it to `author_name` ? Now I have to indent every other branch in the statement to match it:

```ruby
author_name = case title
         when 'War And Peace'
           'Tolstoy'
         when 'Romeo And Juliet'
           'Shakespeare'
         else
           "Don't know"
         end
```

Instead, I would advocate for using a line-break and two space indentation as mentioned above:

```ruby
author =
  case title
  when 'War And Peace'
    'Tolstoy'
  when 'Romeo And Juliet'
    'Shakespeare'
  else
    "Don't know"
  end
```

Now I could call the variable whatever, and I don’t have any additional work. It also shortens the length of the expression line, making it easier to read at a glance.

The biggest reason? Code diffs will be much easier to parse through and reconcile later.

#### Triple Equals

Case statements use `===` behind the scenes, and that’s precisely why I like them so much. If you haven't yet I would encourage [reading an article on `===`](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/).

It’ll be mentioned more in chapter 12, but if you want to explore a bit it’s quite a ride.

Also remember that case statements can use commas to separate multiple conditions like an `OR` of sorts:

```ruby
type_name =
  case 1
  when Integer, Float
    "Number!"
  when String
    "String!"
  else
    "Dunno, too lazy"
  end
```

Really it gets a bit close to pattern matching after a fashion. I'll mention that a bit more in a moment.

The chapter mentions the use of Regex as well to match against titles. That’s because regex use `===` too. I’m telling you, it’s Ruby’s best magic, especially once you figure out you can implement your own.

#### Pattern Matching

Where this gets very powerful is from Ruby 2.7 onwards, which introduced an additional pattern matching syntax to `case` statements:

```ruby
Point = Struct.new(:x, :y)

case Point[1, 2]
in Point[0.., 0..] then :positive
in Point[..0, ..0] then :negative
else :unsure
end
# => :positive

big_point = Point[10, 10]
case big_point
in Point[x: 10.. => x, y: 10.. => y] then Point[x + 1, y + 1]
else big_point
end
# > #<struct Point x=11, y=11>
```

I would suggest reading through the [Pattern Matching Applied](/writing) series I've written if you really want to dig into this.

## Staying out of trouble

The chapter mentions that `0` is truthy in Ruby. That’s still the case, much to the annoyance of other language programmers. If it’s not `false` or `nil` it’s truthy.

```ruby
puts 'Sorry Dennis Ritchie, but 0 is true!' if 0
```

( [Dennis Ritchie](https://en.wikipedia.org/wiki/Dennis_Ritchie) created the C programming language among other things. He’ll be missed. )

Now it’s mentioned that the string `"false"` isn’t false. When it was said earlier that everything is truthy except `nil` and `false` that includes things which “look” like them. It’s certainly given lots of extra fun to Rails programmers with stringy booleans. Well, nightmares.

```ruby
puts 'Sorry but "false" is not false' if 'false'
```

Explicit truthy comparisons are rare in Ruby, even today:

```ruby
if flag == true
  # do something
end
```

One of the main reasons that comes up is duck typing. We only really care if something is an approximation of truthyness. That, and it involves extra typing.

`defined?` is used as an example of where this can go wrong:

```ruby
doc = Document.new('A Question', 'Shakespeare', 'To be...')
flag = defined?(doc)
```

`defined?` is an odd one, it returns a string for what type the variable is, but not as in data types:

```ruby
defined? a
# => nil

a = 5
# => 5

defined? a
# => "local-variable"
```

So to compare that explicitly to true would break the intent of what we’re probably checking for if we were to do this:

```ruby
if defined?(a)
  # ...
end
```

It’s mentioned as being in a Boolean context. Granted it’s this Rubyist's opinion that methods ending with a question mark should return a straightforward Boolean answer, but such it is.

The next issue that’s brought up is by not paying close attention to `nil`:

```ruby
# Broken in a subtle way...
while next_object = get_next_object
  # Do something with the object
end
```

Remember how `false` and `nil` are both falsy? If you’re expecting `nil` explicitly, you should say so to prevent Ruby from breaking out of that loop early:

```ruby
until (next_object = get_next_object).nil?
  # Do something with the object
end
```

Likewise this does horrid things to `||=` , but that’s mentioned in the next section so we’ll defer until then.

### In the wild

The example used for a bit of a larger `if` block is from Ruby’s X509 certificate validation (with some cleaning):

```ruby
ret =
  if @not_before && @not_before > time
    [false, :expired, "not valid before '#{@not_before}"]
  elsif @not_after && @not_after < time
    [false, :expired, "not valid after '#{@not_after}'"]
  elsif issuer_cert && !verify(issuer_cert.public_key)
    [false, :issuer, "#{issuer_cert.subject} is not an issuer"]
  else
    [true, :ok, 'Valid certificate']
  end
```

Now one of the fun things to change in Ruby since 2011 is the null coercion, or lonely operator (`&.`), which lets us do this (assuming `verify` deals well with `nil`):

```ruby
ret =
  if @not_before&.> time
    [false, :expired, "not valid before '#{@not_before}"]
  elsif @not_after&.< time
    [false, :expired, "not valid after '#{@not_after}'"]
  elsif !verify(issuer_cert&.public_key)
    [false, :issuer, "#{issuer_cert.subject} is not an issuer"]
  else
    [true, :ok, 'Valid certificate']
  end
```

> Note that I’m not using the instance variable interpolation syntax, `"#@var"`, as it’s exceptionally rare to see out in the wild. It's only real benefit is being a character shorter while making code a bit more confusing for newer programmers. When possible stick with common over clever.

Another example used is the classic ternary operator:

```ruby
file = all ? 'specs' : 'latest_specs'
```

It’s still very much in use, and the reason why sometimes I tend to use parens around methods ending in question marks for clarity like `defined?(a)`. Visual cues go a long way for understandability some times.

I’ve seen this done before, but at this point just use an `if` statement instead:

```ruby
file =
  all ?
    'specs' :
    'latest_specs'
```

…and please don’t use multiple nested ternaries, that’s just right unpleasant to read.

Next up postfix expressions!

```ruby
@first_name = '' unless @first_name
```

Though more commonly, and noted in the book, this is used:

```ruby
@first_name ||= ''
```

which is to say essentially:

```ruby
@first_name = @first_name || ''
```

Same rules of truthyness apply here, and remember, only `false` and `nil`. Is an empty string one of those? No? Then it’s still truthy, be very careful to remember this.

The book goes on to compare this to `+=` from the example:

```ruby
count += 1
```

The same idea applies. If we were to go into a bit more depth, Ruby literally uses the operators for this type of syntax sugar. If you were to define your own `+` or `||` it’d override the `+=` and `||=` respectively to potentially do very bad things.

### Wrapping Up

Most everything you’re going to see for control structures like `if` and friends has not changed much, and the warnings are still very relevant. Take heed as there’s some advice in programming which ages quite well.

Next up we get the fun of Arrays and Hashes to play with, and oh my do they have some lovely new features.
