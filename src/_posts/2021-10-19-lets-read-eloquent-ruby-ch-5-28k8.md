---
layout: "post"
title: "Let's Read – Eloquent Ruby – Ch 5 – Regular Expressions"
series: "lets-read-eloquent-ruby"
date: "2021-10-19"
tags: ["ruby", "rails", "books"]
---

Perhaps my personal favorite recommendation for learning to program Ruby like a Rubyist, [Eloquent Ruby](http://eloquentruby.com/) is a book I recommend frequently to this day. That said, it was released in 2011 and things have changed a bit since then.

This series will focus on reading over Eloquent Ruby, noting things that may have changed or been updated since 2011 (around Ruby 1.9.2) to today (2021 — Ruby 3.0.x).

> **Note**: This is an updated version of a previous unfinished Medium series of mine you can [find here](/writing/2018/09/21/lets-read-eloquent-ruby-ch-1/).

## Chapter 5. Find the Right String with Regular Expressions

This chapter focuses on Regular Expressions, or Regex for short. It's one of the most powerful concepts in programming around text manipulation, but also probably one of the most confusing.

If you haven't already heard of these two I would highly suggest using them while exploring Regex:

* [Rubular](https://rubular.com/) - Basic Ruby-centric Regex tester
* [Regexr](https://regexr.com/) - More advanced, explains each segment of a Regex

Personally I tend to use Rubular more, but mostly because the extra info Regexr presents is a bit too noisy for me. In either case I would highly suggest running examples from this chapter and experimenting with them in either tool.

With that said, let's get into it.

### Introductory Examples

The chapter opens with a few examples, like to start with why do you want Regex? The book uses the `String` `"09:24 AM"` as an example. How can you tell it's a time? AM or PM? 24H or 12H? Maybe even ambiguous. These are a lot of questions that can be a bit difficult to answer with just `String` methods, requiring something a bit more powerful.

Think of Regex like a method of describing the shape of text. `"09:24 AM"` is composed of two digits, a colon, two digits, a space, and AM or PM. Regex is a language that lets us say exactly that:

```ruby
# Regex starts and ends with a `/`, or surrounded by %r{}
time_match = /\d{2}:\d{2} (AM|PM)/
# time_match = %r{\d{2}:\d{2} (AM|PM)}

time_match.match? "09:24 AM"
# => true
```

Now that's all a bit dense to start out with, so let's step back along with the book to get into a few more examples.

### Matching One Character at a Time

The book lists a few examples, but let's turn those into code real quick:

```ruby
# The regular expression x will match x.
/x/.match? "x"
# => true

# The regular expression aaa will match three a’s all in a row.
/aaa/.match? "aaa"
# => true

# The regular expression 123 will match the first three numbers.
/123/.match? "123"
# => true

# The regular expression R2D2 will match the name of a certain sci-fi robot.
/R2D2/.match? "R2D2"
# => true
/R2D2/.match? "r2d2"
# => false (case sensitive)
```

#### Special Characters

Now those could all have been `==` compares instead, so let's look at a few more interesting characters:

* `.` - Matches any one character.
* `*` - Matches zero or more of whatever comes before it.
* `+` - Matches one or more of whatever comes before it.

Going back to examples:

```ruby
# The regular expression . will match any single-character
# string including r and % and ~.
dot_match = /./

dot_match.match? "r"
# => true
dot_match.match? "%"
# => true
dot_match.match? "~"
# => true

# In the same way, two periods ( .. ) will match any two characters,
# perhaps xx or 4F or even [!, but won’t match Q since it’s one,
# not two, characters long.
double_dot_match = /../

double_dot_match.match? "xx"
# => true
double_dot_match.match? "4F"
# => true
double_dot_match.match? "[!"
# => true
double_dot_match.match? "Q"
# => false (one character)
```

#### Literal Characters

There are some characters you want to match an actual dot, so how does one get Regex to do that? With a backslash:

```ruby
# \. will match a literal dot.
/\./.match? "."
# => true

# 3\.14 will match the string version of PI to two decimal places,
# complete with the decimal point: 3.14
/3\.14/.match? "3.14"
# => true

# Mr\. Olsen will match exactly one thing: Mr. Olsen
/Mr\. Olsen/.match? "Mr. Olsen"
# => true
```

#### Combining Effects

The book then goes into a few combos, let's turn those into examples:

```ruby
# The regular expression A. will match any two-character string that
# starts with a capital A, including AM, An, At, and even A=.
a_dot = /A./

a_dot.match? "AM"
# => true
a_dot.match? "An"
# => true
a_dot.match? "At"
# => true
a_dot.match? "A="
# => true

# Similarly, ...X will match any four-character string that ends
# with an X, including UVWX and XOOX.
x_match = /...X/

x_match.match? "UVWX"
# => true
x_match.match? "XOOX"
# => true

# The regular expression .r\. Smith will match both Dr. Smith as
# well as Mr. Smith but not Mrs. Smith.
smith_match = /.r\. Smith/

smith_match.match? "Dr. Smith"
# => true
smith_match.match? "Mr. Smith"
# => true
smith_match.match? "Mrs. Smith"
# => false
```

### Sets, Ranges, and Alternatives

Say you wanted a character out of a set of them, Regex enables this with `[]`:

```ruby
vowel_match = /[aeiou]/
digit_match = /[0123456789]/
hex_match = /[0123456789abdef]/
```

Think of them as inclusion in a set of characters. The book then goes on into a few more examples here:

```ruby
# The regular expression [Rr]uss [Oo]lsen will match my name, with or without
# leading capitals.
/[Rr]uss [Oo]lsen/.match?("Russ Olsen")
# => true

# More practically, you could use [0123456789abcdef][0123456789abcdef] to
# pick out a two-digit hexadecimal number like 3e or ff.
two_digit_hex_match = /[0123456789abcdef][0123456789abcdef]/
two_digit_hex_match.match?("3e")
# => true
two_digit_hex_match.match?("ff")
# => true

# You can also use [aApP][mM] to match am or PM and anything in between,
# like aM or Pm.
meridiem_match = /[aApP][mM]/
meridiem_match.match?("am")
# => true
meridiem_match.match?("AM")
# => true
meridiem_match.match?("aM")
# => true
meridiem_match.match?("pm")
# => true
meridiem_match.match?("pM")
# => true
```

#### Ranges

Now if that all seems a bit tedious there's the concept of a range in Regex:

```ruby
/[a-z]/.match?("x")
# => true

/[0-9]/.match?("4")
# => true
```

#### Common Set Shortcuts

...and the even more useful common set shortcuts:

```ruby
# Any number
/\d/.match?("0")
# => true

# Any letter, number, or underscore
/\w/.match?("c")
# => true

# Any whitespace like space, tab, and newline
/\s/.match?(" ")
# => true
```

#### Alternatives

The last in this section is the alternative, which you can think more of as "OR":

```ruby
# A|B will match either A or B.
/A|B/.match?("A")
# => true
/A|B/.match?("B")
# => true

# AM|PM will match either AM or PM.
/AM|PM/.match?("AM")
# => true
/AM|PM/.match?("PM")
# => true

# Batman|Spiderman will match the name of one of the two superheros.
/Batman|Spiderman/.match?("Batman")
# => true
/Batman|Spiderman/.match?("Spiderman")
# => true
```

The book goes on to mention that you can use as many alternatives as you would like, but also sneaks in group captures (`()`) here which I don't believe it gets into later, but trust me when I say that's one of the most useful parts of Regex.

### The Regular Expression Star

Interestingly we mentioned this above in special characters, the star (`*`) stands for zero or more of whatever is before it, and the plus (`+`) stands for one or more. There's one more idea here with specifying count, but that's an item for later.

The book mentions the following examples:

```ruby
# AB* will match AB—that’s an A followed by one B.
/AB*/.match?("AB")
# => true

# AB* will also match ABB as well as ABBBBBBBB—remember, it’s an A followed
# by any number of B’s.
/AB*/.match?("ABB")
# => true
/AB*/.match?("ABBBBBBBB")
# => true

# Don’t forget that AB* will also match plain old A—any number of B’s
# includes no B’s at all.
/AB*/.match?("A")
# => true
```

If we were to switch to `+` that last case wouldn't work. The book then goes on to mention that sets, ranges, and common sets work with `*` as well. Really, anything does:

```ruby
# Zero or more vowels
/[aeiou]*/

# Zero or more numbers
/[0–9]*/
/\d*/

# Zero or more hex digits, lowercase
/[0-9a-f]*/

# Zero or more of any character
/.*/
```

That last one the book mentions can be extremely useful, and is frequently used to make more flexible patterns:

```ruby
/George.*/.match?("George Smith")
# => true

/.*George/.match?("Sally George")
# => true

/.*George.*/.match?("Jimmy George Joeseph")
# => true
```

Personally I would advocate for being more explicit about what you expect, lest you match more than you intended. Perhaps you do want to match a lot more, that's fine too, but make sure that's the case.

#### Regular Expression Counts

The book does not mention this, but it's an important subject to bring up: counts. Star is used for zero or more, plus for one or more, question for optional, but what about if I wanted something like 4 to 5 instances?

There are four count matches you'll want to be aware of:

```ruby
# Exactly 3 of a
/a{3}/.match?("aaa")
# => true

# 3 or more of a
/a{3,}/.match?("aaaa")
# => true

# Between 3 and 6 of a
/a{3,6}/.match?("aaaaa")
# => true

# Up to 6 of a
/a{,6}/.match?("aaaaa")
# => true
```

Do note though that unless used in conjunction with the section "Beginnings and Ends" coming up it won't work as intended, so be sure to give that a look and see if you can spot the flaws in the above matches.

### Regular Expressions in Ruby

Up to this point the book is just mentioning the Regex language without really getting into the Ruby implementation. For me and this article, however, I used Ruby implementations to show how it would work, so a lot of this will seem familiar.

I'll give an overview instead of what it mentions.

#### Equal Squiggly (`=~`)

The equal squiggly sign is used for matching in Ruby, though it's not the clearest syntax:

```ruby
/\d\d:\d\d (AM|PM)/ =~ '10:24 PM'
# => 0
```

Why zero? That's the position in the string it found the match at. If there was nothing in there we'd get `nil` back instead.

Personally I prefer `match?` as it returns back an explicit true or false, is faster, and very rarely do I need to know the direct index of something.

#### Regex Flags

The book does sneak a fast one in here with Regex flags like `i` which makes things case-insensitive:

```ruby
merediem_match = /AM|PM/i

merediem_match.match?("am")
# => true
merediem_match.match?("pm")
# => true
```

There are several more you can find at the bottom of rubular, but the common ones I use are `i` for case-insensitive and `x` for whitespace-insensitive.

#### Methods Taking Regex

There are also methods like `sub`, `gsub`, `scan`, and others which take in a Regex, like this example the book provides:

```ruby
class Document
  # ...

  def obscure_times!
    @content.gsub!(/\d\d:\d\d (AM|PM)/i, "**:** **")
  end
end
```

> **Note**: I did add the `i` there, where the book omits it. Case-insensitive would be more flexible here.

#### Beginnings and Ends

The book then mentions that the Regex we've used so far are unbounded, meaning they match anywhere in a string. There are a few more special expressions that allow us to specify beginning and end of line, and beginning and end of strings:

```ruby
# Matches beginning of String
/\ASome text/.match?("Some text starts this")
# => true

# Matches end of String
/Some text\z/.match?("ends with Some text")
# => true

# Matches beginning of any line in a string
/^Some text/.match?("Other text\nSome text")
# => true

# Matches end of any line in a String
/Some text$/.match?("Some text\nOther text")
# => true
```

Especially when dealing with user input you want to be exceptionally strict about this, and most Rails security tools are going to give you grief over omitting explicit beginning and ending of String signifiers in your Regex.

### In the Wild

The book mentions a real-world usecase as timezone offsets in `time.rb`, notedly numeric ones like `-07:00` or `+08:00`, with this line:

```ruby
if /\A([+-])(\d\d):?(\d\d)\z/ =~ zone
```

The book mentions question mark (`?`) as being an optional character, meaning there could be a colon there, or there could not be.

Now the interesting part, and what the book wants to highlight, is that if the Regex isn't matched it's compared against a set of values like `UTC`:

```ruby
elsif ZoneOffset.include?(zone)
```

...which mixes the usefulness of Regex with the usefulness of set inclusion. That said, one could also do this:

```ruby
zome_offset_matches = Regexp.union(*ZoneOffset)
```

...which I've gotten a good deal of mileage out of in the past

### Staying Out of Trouble

The book mentions watching out for using `==` accidentally in place of `=~`, though to avoid that I would still actively recommend using `match?` instead as clear naming means a lot when reading your code later.

The second it mentions is `0` being falsy in C-like languages, despite being truthy in Ruby and representing something was found at the 0th index of a String.

### Wrapping Up

There's a ton to cover any time Regex comes up, and the book gives a solid start, though I do really wish they had spent a bit of time on capture groups and counts.

I may do a writeup or addendum to this chapter later on capture groups if there's interest, let me know!

Next up we'll have Symbols, one of the more confusing aspects of Ruby.
