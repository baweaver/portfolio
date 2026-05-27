---
layout: "post"
title: "Advent of Ruby 3.0 - Day 02 - Password Philosophy"
series: "advent-ruby-3"
date: "2020-12-27"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

[<< Previous](/writing/2020/12/27/advent-of-ruby-3-0-day-01-report-repair-4ib0/) | [Next >>](/writing/2020/12/28/advent-of-ruby-3-0-day-03-toboggan-trajectory-4e9c/)

# [Day 02](https://adventofcode.com/2020/day/2) - Part 01 - Password Philosophy

For this problem we need to validate some passwords by a set of criteria:

```
1-3 a: abcde
```

The two numbers signify the count of the letter to their right that the password on the far right should contain. In the above case, there should be one to three occurrences of `a` in `abcde`, and because there are it's a valid password.

This password, however, is invalid as it has no occurrences of `b`:

```
1-3 b: cdefg
```

Now with those rules down, let's take a look at 

[See the full solution here on Github.](https://github.com/baweaver/advent_of_code_2020/blob/main/02_password_philosophy.rb)

## A Crash Course in Regex

Perhaps the most ideal way to get the data we want is to parse it with Regular Expressions. Before we do that let's give a quick run through some concepts, and make sure you [try these out in Rubular](http://rubular.com/) to see it in action.

This isn't a comprehensive tutorial but a quick reference. If you want a full tutorial [look into this one](http://zetcode.com/lang/rubytutorial/regex/).

### Matching Multiples

You can certainly use literal symbols in Regex, but sometimes you want something like any character (`.`), any digit (`\d`), the lowercase letters (`[a-z]`), or a literal space (`\s`). They help us describe the shape of our input so we can extract what we want from it.

There are also modifiers like `*` and `+` for zero or more occurrences of whatever was before, and one or more respectively.

```ruby
'abc'.match(/[a-z]+/)
# => #<MatchData "abc">

'012'.match(/[a-z]+/)
# => nil
```

### Capture Groups

One of the key features of regex we want to use is the concept of capturing and naming segments of the input. Let's say we wanted to (naively) parse an IP Address:

```ruby
IP_REGEX = /(?<first>\d+)\.(?<second>\d+)\.(?<third>\d+)\.(?<fourth>\d+)/

'192.168.1.1'.match(IP_REGEX)
# => #<MatchData "192.168.1.1"
#   first:"192"
#   second:"168"
#   third:"1"
#   fourth:"1"
# >
```

Rubular will show you these groups in action, but the concept is that we can use `(?<capture_name>captured_regex_value)` to give a name to what we want to extract. We can even use `named_captures` to get those values from our match data, but I'd recommend `&.` in case it returned `nil` from no match:

```ruby
'192.168.1.1'.match(IP_REGEX).named_captures
# => {"first"=>"192", "second"=>"168", "third"=>"1", "fourth"=>"1"}
```

### Whitespace Insensitive

You can add options to the end of a regex to make it act differently, like `x` which makes it whitespace insensitive so you can multi-line and add some comments to make it easier to read what you're up to:

```ruby
IP_REGEX = /
  (?<first>\d+)\.
  (?<second>\d+)\.
  (?<third>\d+)\.
  (?<fourth>\d+)
/x
```

Same idea, but much easier to read what's going on.

## Regex Applied

All that together gives us a Regex that looks like this:

```ruby
PASSWORD_INFO = /
  # Beginning of line
  ^

  # Capture the entire thing as "input"
  (?<input>

    # Get the low count of the letter, capture it with
    # the name low_count
    (?<low_count>\d+)

    # Ignore the dash
    -

    # ...and the high count
    (?<high_count>\d+)

    # literal space
    \s

    # Find our target letter
    (?<target_letter>[a-z]):

    \s

    # ...and the rest of the line is our password
    (?<password>[a-z]+)

  # End the input
  )

  # End of line
  $
/x
```

The trick here is we want both the entire line as well as a few items like the counts, target letter, and the password itself. If we were to use this against both of our examples above we'd get this:

```ruby
'1-3 a: abcde'.match(PASSWORD_INFO)
# => #<MatchData "1-3 a: abcde"
#   input:"1-3 a: abcde"
#   low_count:"1"
#   high_count:"3"
#   target_letter:"a"
#   password:"abcde"
# >

'1-3 b: cdefg'.match(PASSWORD_INFO)
# => #<MatchData "1-3 b: cdefg"
#   input:"1-3 b: cdefg"
#   low_count:"1"
#   high_count:"3"
#   target_letter:"b"
#   password:"cdefg"
# >
```

...and that looks like something we can use to solve this problem. Just be careful that those counts are strings.

## Extracting the Password

Let's make a one-liner to extract the password:

```ruby
def extract_password(line) = 
    line.match(PASSWORD_INFO)&.named_captures&.transform_keys(&:to_sym)
```

So not technically a one-liner, and more Python-y feeling. Rule of thumb is that endless methods should only contain one expression or value, and a chain is an expression. Whitespace is free as well, use it liberally, future you will be glad you did when you have to read back over your code again.

Anyways, the only new part here is `transform_keys` which is turning all the `String` keys to `Symbols`. Why? Well truthfully it's to show some pattern matching potentials in the next section.

## It's the Letter that Counts

One-liners are useful for quick functions, and eventually we're going to need something to count how many of each letter there are in the password.

> Yes, there are more efficient ways to do this, but that's an exercise I leave up to the reader to figure out.

Luckily we have a nifty function named `tally` that can help us do just that:

```ruby
def letter_counts(word) = word.chars.tally
```

`tally` returns the counts of each item in a collection:

```ruby
letter_counts 'aabbccc'
# => {"a"=>2, "b"=>2, "c"=>3}
```

...where we might have used this trick before:

```ruby
def letter_counts(word) =
  word.chars.each_with_object(Hash.new(0)) { |c, counts| counts[c] += 1 }
```

I prefer `tally` myself, and I use it quite a bit. Heck, [me, David, Shannon, and Steph even helped name it](/writing/2019/02/10/ruby-2-7-enumerable-tally-3b02/).

## Valid Passwords

Now we have the tools we need to see if a password is valid, so let's take a look at the function itself:

```ruby
def valid_passwords(input)
  input.filter_map do
    extracted_password = extract_password(_1) or next
    extracted_password => {
      input:, low_count:, high_count:, target_letter:, password:
    }

    low_count, high_count = low_count.to_i, high_count.to_i
    count = letter_counts(password)[target_letter]

    input if (low_count..high_count).include?(count)
  end
end
```

There's a lot in there, so let's start breaking it down.

### Filter Map

`filter_map` is a fun one, it both filters and maps as the name implies. That means only truthy elements are kept in the end result:

```ruby
[1, 2, 3].filter_map { _1 * 2 if _1.even? }
# => 4
```

Granted in the above case we don't strictly need it, we could have used `select`, but if we wanted to both extract the password itself, keep the match data, and filter out invalid inputs it gets real handy real fast.

### `or`? Is that Perl?

Yes. I use english operators on occasion when they make sense. This is one such case. If the extracted password is `nil` we know we can bail out early, and this is a trick from Perl for early returns or exceptions that made its way into Ruby:

```ruby
line = gets or raise 'error!'
```

Then again I put undue emphasis on left-to-right readability, and avoid using `or` and `and` in work code.

### Rocket One-Line Pattern Match (RHA)

This one is fun, and similar to the Javascript destructuring:

```js
{ a, b } = { a: 1, b: 2 }
// => a = 1, b = 2
```

...except it's in reverse, and it's called Right Hand Assignment:

```ruby
extracted_password => {
 input:, low_count:, high_count:, target_letter:, password:
}
```

This is why we mapped those keys to symbols was to demonstrate this feature. I do wish this was implemented with `Object#send` as a default because then I could do something like this:

```ruby
person_object => { name:, age: }
```

...but alas, no such luck. It's fun to note though that these patterns can also have validations in them that respond to `===`, [and we all know how much fun `===` is](/writing/2017/10/16/triple-equals-black-magic/). Let's take a look at an example of that:

```ruby
{ a: 1, b: 2, c: 'foo' } => { a: Integer, b: 2, c: }
```

Be warned, there are some slight bugs and odd issues here as it's experimental, such as only the local variable `c` will be defined unless we do this:

```ruby
{ a: 1, b: 2, c: 'foo' } => {
  a: Integer => a, b: 2 => b, c:
}
```

Which I think is a bug, and I'll get it reported up later.

### The Rest of the Owl

The remainder of the function isn't anything too unique:

```ruby
low_count, high_count = low_count.to_i, high_count.to_i
count = letter_counts(password)[target_letter]

input if (low_count..high_count).include?(count)
```

We want actual numbers to compare to for our counts, we want the counts of each letter in the word, and then we want to see whether or not that count falls within the expected range.

If it does we return the `input`, and if not it gets filtered out of our return.

## Valid Password Counts

Like in the other problem we can just wrap that previous one in another function to get the count of valid passwords:

```ruby
def valid_password_count(...) = valid_passwords(...).size
```

Again, I like the extra debugging potential as well as keeping these two ideas separate from each other.

## Reading the Input

Which brings us to parsing the input from AoC:

```ruby
File.readlines(ARGV[0]).then { puts valid_password_count(_1) }
```

This line will not change too terribly much throughout the rest of the problems.

# Day 02 - Part 02 - A Different Password Philosophy

As with all programming, specifications change, and in the case of this problem the way they parse the passwords as valid has changed!

Now the counts are actually positions in the password. We want to check if the password has the target character in one, but not both, of those positions.

```
# is valid: position 1 contains a and position 3 does not.
1-3 a: abcde

# is invalid: neither position 1 nor position 3 contains b.
1-3 b: cdefg

# is invalid: both position 2 and position 9 contain c.
2-9 c: ccccccccc
```

That means we have a few things to change in our function.

## Changes to the Regex

We need to change our capture group names from `low_count` and `high_count` to `position_one` and `position_two` as the intent has changed:

```ruby
PASSWORD_INFO = /
  # Beginning of line
  ^

  # Capture the entire thing as "input"
  (?<input>

    # Get the first position
    (?<position_one>\d+)

    # Ignore the dash
    -

    # and the second position
    (?<position_two>\d+)

    # literal space
    \s

    # Find our target letter
    (?<target_letter>[a-z]):

    \s

    # and the rest of the line is our password
    (?<password>[a-z]+)

  # End the input
  )

  # End of line
  $
/x
```

Not too terrible a change, but naming matters, so best to change it.

## Valid Passwords

Now let's look into our main function and what needs to change there:

```ruby
def valid_passwords(input)
  input.filter_map do
    extracted_password = extract_password(_1) or next

    extracted_password => {
      input:, position_one:, position_two:, target_letter:, password:
    }

    position_one = position_one.to_i - 1
    position_two = position_two.to_i - 1

    char_one, char_two = password[position_one], password[position_two]

    input if [char_one, char_two].one?(target_letter)
  end
end
```

### Pattern Match Names

We need to change `low_count` and `high_count` here as well to our new position names:

```ruby
extracted_password => {
  input:, position_one:, position_two:, target_letter:, password:
}
```

### Someone's Using Lua for Indexes

In the specification they mentioned that things were `1` indexed instead of `0` so we need to offset the positions to compensate:

```ruby
position_one = position_one.to_i - 1
position_two = position_two.to_i - 1
```

### Retrieving Characters

Then we want to grab the characters at those positions:

```ruby
char_one, char_two = password[position_one], password[position_two]
```

Is one-line multi-assignment frowned upon? Probably. Does it work? Yes.

### Validation

Now instead of checking the count we want to make sure that one, and only one, of the characters is our target:

```ruby
input if [char_one, char_two].one?(target_letter)
```

This is a concept known as exclusive or, or `XOR`, except we're using the nice english variants here instead. Ruby _does_ have an `XOR` in `^` though:

```ruby
true ^ true
# => false

true ^ false
# => true

false ^ true
# => true

false ^ false
# => false
```

Just be careful of the precedence if you use that as this breaks:

```ruby
input if char_one == target_letter ^ char_two == target_letter
```

Personally I feel this is a bug as `||` and `&&` work differently and allow this, but I'm not sure. It can be fixed as so:

```ruby
input if (char_one == target_letter) ^ (char_two == target_letter)
```

...and with that the rest of the function is the same and we've met the requirements!

# Wrapping Up Day 02

That about wraps up day two, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

[<< Previous](/writing/2020/12/27/advent-of-ruby-3-0-day-01-report-repair-4ib0/) | [Next >>](/writing/2020/12/28/advent-of-ruby-3-0-day-03-toboggan-trajectory-4e9c/)
