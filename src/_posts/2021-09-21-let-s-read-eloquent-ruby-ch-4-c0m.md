---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 4 – Smart Strings"
series: "lets-read-eloquent-ruby"
date: "2021-09-21"
tags: ["ruby", "rails", "books"]
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2021 — Ruby 3.0.x).

> **Note**: This is an updated version of a previous unfinished Medium series of mine you can [find here](/writing/2018/09/21/lets-read-eloquent-ruby-ch-1/).

## Chapter 4. Take Advantage of Ruby’s Smart Strings

This chapter starts into `String`s, and the intro mentions something that I've found to be very true. Most folks would assume that programmers deal primarily in numbers, which sure we do, but far more often we're doing some form of text manipulation.

Parsing data, serializing it back, user input, really so much of programming centers around text and `String`s, where a lot of the rest of it ends up around collections. For me numbers are almost a distant third to those two, but that's a personal opinion.

### Coming Up with a String

So Ruby is Ruby, and the book mentions that there are several ways to make a `String`, much like so many other things in Ruby. Generally the easy rule to follow for me has been to use double-quotes for everything, despite the (completely insignificant) performance difference with single quotes.

Anyways, the book mentions a few examples of backslashes with single quotes:

```ruby
# Escaping a single quote mark
a_string_with_a_quote = 'Say it ain\'t so!'

# Escaping a backslash
a_string_with_a_backslash = 'This is a backslash: \\'
```

Now the reason I say double quotes are going to be easier in general is that single quoted strings also treat things literally rather than evaluate special syntaxes:

```ruby
single_quoted = 'I have a tab: \t and a newline: \n'
double_quoted = "I have a tab: \t and a newline: \n"
```

Same applies to interpolation, as the book mentions:

```ruby
author = "Ben Bova"
title = "Mars"

puts "#{title} is written by #{author}"
# Mars is written by Ben Bova
#
puts '#{title} is written by #{author}'
# #{title} is written by #{author}
```

One weakness of quotes in general is when you get them mixed in each other, as the books next few examples mentioned:

```ruby
str = "\"Stop\", she said, \"I cannot deal with the backslashes.\""

# versus using single quotes to wrap
str = '"Stop", she said, "I cannot deal with the backslashes."'
```

...but as with the book, I also agree that this is where the `%q` syntax is more useful:

```ruby
str = %q("Stop", she said, "I can't live without 's and "s.")
```

It also gets into the fact you could have used `%q[]` or `%q$$` or... anyways, probably best to prefer `%q()` in general as it's easier to deal with.

Now the next one to remember with `%q` is it's the same as single quotes, where `%Q` is double. As with my previous mention I would in general prefer double quotes unless you have a specific reason not to, or `%Q` in these cases.

The book then goes into Heredocs:

```ruby
multi_line = <<EOF
Here's a lot of text. Some
of it goes on multiple lines!
EOF
```

The weakness here the book does not mention is that `<<TAG` syntax is space-sensitive:

```ruby
m1 = <<EOF
Here's a lot of text. Some
of it goes on multiple lines!
EOF

m2 = <<EOF
    Here's a lot of text. Some
    of it goes on multiple lines!
EOF
```

So if you had some code like this:

```ruby
module Container
  class Something
    def a_method
      puts <<EOF
        Text here that is slightly long
        because why not?
      EOF
    end
  end
end
```

...all that indent to the left? That's now in the `String`. You probably want the more recent "squiggly" heredoc syntax instead in general:

```ruby
module Container
  class Something
    def a_method
      puts <<~EOF
        Text here that is slightly long
        because why not?
      EOF
    end
  end
end
```

There aren't very many good reasons to use `<<` versus `<<~`, as the squiggly syntax auto-trims to the least indented line on the left, which is very very useful for long text.

### Another API to Master

#### Stripping and Chomping

As with `Array` and so many other of Ruby's classes the real fun starts when you get into the methods they come with, and Ruby's `String` class has several. The book starts off with `lstrip` for one:

```ruby
' hello'.lstrip
# => 'hello'
```

...and as intuition might serve, there's also an `rstrip`, and a `strip` which will take off of both ends. The more common one I use, and the book mentions, is `chomp` which gets rid of newline and carriage return characters at the end of a `String`:

```ruby
"It was a dark and stormy night\n".chomp
# => "It was a dark and stormy night"

# ...but only one newline
"hello\n\n\n".chomp
# => "hello\n\n"
```

Now a method I always forget about, and haven't found much of a use for, `chop`:

```ruby
"hello".chop
# => "hell"
```

...will knock off the last character no matter what it is. Personally I really haven't seen much of a use for this one, but that's me.

#### Case Manipulation

Next the book gets into working with string cases:

```ruby
"hello".upcase
# => "HELLO"

"HELLO".downcase
# => "hello"

"Hello"
# => "hELLO"
```

More recent versions have also added `capitalize`:

```ruby
"hello".capitalize
# => "Hello"
```

...which was formerly a Rails exclusive, but in common enough usage it makes sense.

#### Substitution

Next up is substitution, allowing you to replace part of a string with another:

```ruby
"It is warm outside".sub("warm", "cold")
# => "It is cold outside"
```

...but that only works with one substitution. You'd want `gsub` for multiple:

```ruby
"yes yes".sub("yes", "no")
# => "no yes"

"yes yes".gsub("yes", "no")
# => "no no"
```

Now be aware, the book doesn't mention this and leaves the bang (`sub!`, `gsub!`) variants of these methods to a bit later, but they have a dangerous difference.

So as a reminder bang methods do something worthy of caution, typically mutating the underlying object. In many cases they'll return `nil` if they make no modifications for optimization reasons, and the object if it does. That means chaining will throw you for a loop:

```ruby
"abcd".sub!("ab", "ba").sub!("cd", "dc")
# => "badc"

"abcd".sub!("ac", "ba").sub!("cd", "dc")
# NoMethodError (undefined method `sub!' for nil:NilClass)
```

Catch that? Most won't while coding with these methods, and it can be a real pesky source of bugs. In general avoid bang methods unless you really need the performance increase. Most of the time you won't.

#### Splitting

Next up we have `split`, which allows us to split `String`s on a character, or whitespace if unspecified:

```ruby
"It was a dark and stormy night".split
# => ["It", "was", "a", "dark", "and", "stormy", "night"]
```

The book then gives an example of a character-based split:

```ruby
"Bill:Shakespeare:Playwright:Globe".split(":")
# => ["Bill", "Shakespeare", "Playwright", "Globe"]
```

...but one thing is `split` actually takes _two_ arguments, the delimiter (what separates items) and a count of how many items to max out on:

```ruby
%Q(data: { "a": 1, "b": 2 }).split(":")
# => ["data", " { \"a\"", " 1, \"b\"", " 2 }"]

%Q(data: { "a": 1, "b": 2 }).split(":", 2)
# => ["data", " { \"a\": 1, \"b\": 2 }"]
```

Notice it? It's subtle, but because the `String` here is more of a key-value with the value being a JSON-like format it's not a good idea to split on `:` globally, but once, where the key and value are separated. Granted you should probably also do `split(/: */, 2)` to account for spaces between the two as well.

#### Lines, Characters, and Bytes

One topic that's come up a few times is why a `String` doesn't have an `each` method. Well, it does and it doesn't. What'd be the iterated item? `String`s are a collection of a lot of different concepts. Bytes, characters, codepoints, lines, and probably a lot more I'm forgetting. Point being there's not one clear iterable here.

That's why Ruby lets you decide for yourself:

```ruby
"some\nlines\nof\ntext".lines
# => ["some\n", "lines\n", "of\n", "text"]

"some\nlines\nof\ntext".each_line { |line| puts line }
# some
# lines
# of
# text
#  => "some\nlines\nof\ntext"

"abc".chars
# => ["a", "b", "c"]

"abc".each_char { |c| puts c }
# a
# b
# c
#  => "abc"

"abc".bytes
# => [97, 98, 99]

"abc".each_byte { |b| puts b }
# 97
# 98
# 99
#  => "abc"

"😅🎉✨".codepoints
# => [128517, 127881, 10024]

"😅🎉✨".each_codepoint { |c| puts c }
# 128517
# 127881
# 10024
#  => "😅🎉✨"
```

The book does mention that Ruby does allow `String`s to be indexed against with `[]` like so:

```ruby
"abc"[0]
# => "a"
```

...which implies it iterates on characters, but once you get into emoji and unicode and all the fun magics of non-ASCII `String`s it starts getting a bit harder to work with.

Do also remember, as the book puts at the end of the chapter, that `[-1]` will get the last character and ranges are valid (`[3..5]`):

```ruby
"some text"[-1]
# => "t"

"some text"[3..5]
# => "e t"
```

### In the Wild

The book then goes into a few real-world examples of `String` manipulation, starting with `html_escape` from the standard library in the RSS library:

```ruby
def html_escape(s)
  s
    .to_s
    .gsub(/&/, "&amp;")
    .gsub(/\"/, "&quot;")
    .gsub(/>/, "&gt;")
    .gsub(/</, "&lt;")
end
```

...though the `Hash` form may be a bit easier to work with later:

```ruby
ESCAPED_ENTITIES_MAP = {
  "&"  => "&amp;",
  "\"" => "&quot;",
  ">"  => "&gt;",
  "<"  => "&lt;",
}

ESCAPED_ENTITIES = Regexp.union(ESCAPED_ENTITIES_MAP.keys)

def html_escape(s)
  s.to_s.gsub(ESCAPED_ENTITIES, ESCAPED_ENTITIES_MAP)
end

html_escape(%Q(<a href="link.html?a&b">text</a>))
# => "&lt;a href=&quot;link.html?a&amp;b&quot;&gt;text&lt;/a&gt;"
```

Useful to know that exists, anyways, back on topic.

The book then mentions a few Rails concepts, the inflector and the pluralizer. It's used to determine that the class inside `current_employee.rb` should be `CurrentEmployee`, and the associated DB table should be `current_employee`. As the book mentions this is done with `String` processing.

It works via a set of rules, especially around pluralization, like irregular pluralization cases like `person` pluralizing into `people`:

```ruby
inflect.irregular("person", "people")
inflect.irregular("man", "men")
inflect.irregular("child", "children")
inflect.irregular("sex", "sexes")
```

...which are applied via `gsub!`, which uses that behavior of returning `nil` mentioned above:

```ruby
inflections.plurals.each do |(rule, replacement)|
  break if result.gsub!(rule, replacement)
end
```

Now one could probably do this with `find` instead and avoid mutations, but knowing Rails and some of the optimization cases there there's probably a reason for it.

### Staying Out of Trouble

Ruby `String`s are mutable. There are ways around this with `freeze` and the frozen string literal:

```ruby
# frozen_string_literal: true

"string".freeze
```

That means that any of those bang methods from above will mutate the underlying `String`:

```ruby
first_name = "Susan"
given_name = first_name

first_name[-2..-1] = "ie"
# => "ie"

first_name
# => "Susie"

given_name
# => "Susie"

first_name.downcase!
# => "susie"

first_name
# => "susie"

given_name
# => "susie"
```

So be careful when mutating things unless you really really need it, but most of the time? You won't.

### Wrapping Up

This wraps up chapter 4, which covers a lot of `String`s in Ruby, but leaves some of the real interesting parts for chapter 5 where we get into Regex.

In the mean time? The book is correct, `String`s are exceptionally common in Ruby, and dealing with them is going to be a substantial part of what you do in Ruby. Getting comfortable with those docs is certainly a wise investment.
