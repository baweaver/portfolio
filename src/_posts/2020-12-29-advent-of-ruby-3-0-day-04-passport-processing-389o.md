---
layout: "post"
title: "Advent of Ruby 3.0 - Day 04 - Passport Processing"
series: "advent-ruby-3"
date: "2020-12-29"
categories: ["ruby", "adventofcode"]
tags: ["ruby", "adventofcode"]
description: "An exploration into Ruby 2.7 and 3.0 features applied to Advent of Code Problems"
---

Ruby 3.0 was just released, so it's that merry time of year where we take time to experiment and see what all fun new features are out there.

This series of posts will take a look into several Ruby 2.7 and 3.0 features and how one might use them to [solve Advent of Code problems](https://adventofcode.com/). The solutions themselves are not meant to be the most efficient as much as to demonstrate novel uses of features.

I'll be breaking these up by individual days as each of these posts will get progressively longer and more involved, and I'm not keen on giving 10+ minute posts very often.

With that said, let's get into it!

[<< Previous](/writing/2020/12/28/advent-of-ruby-3-0-day-03-toboggan-trajectory-4e9c/) | [Next >>](/writing/2020/12/29/advent-of-ruby-3-0-day-05-binary-boarding-2m8f/)

# [Day 04](https://adventofcode.com/2020/day/4) - Part 01 - Passport Processing

This one was quite a bit easier than the last one. We have some inconsistently formatted data in the form of `key:value` pairs, and the validation is to check that all the necessary keys are present.

Let's take a look into the solution to start off with, and then dig in from there:

```ruby
require 'any'

VALID_KEYS = %i(byr iyr eyr hgt hcl ecl pid cid)
VALID_KEYS_MAP = VALID_KEYS.to_h { |k| [k, Any] }
VALID_NORTH_POLE_MAP = VALID_KEYS_MAP.except(:cid)

def valid_passports(passports)
  passports.filter_map do |passport|
    parsed_passport = passport
      .split
      .to_h { _1.split(':') }
      .transform_keys(&:to_sym)

    parsed_passport if parsed_passport in VALID_NORTH_POLE_MAP
  end
end

def valid_passport_count(...) = valid_passports(...).size

File.read(ARGV[0]).split(/\n\n/).then { puts valid_passport_count(_1) }
```

## Any?

`any` is a gem of my own making that will respond true when compared to just about anything, but especially `===`. Pattern matching uses `===` which means this works:

```ruby
{ a: 1 } in a: Any
```

Why? Because we want something that's always true, which will make more sense in a bit. From experimentation this is the only clean way to get patterns that are dynamic to work.

## Valid Keys and Mapping

The first thing we want to do is make sure we have a list of all the valid passport keys:

```ruby
VALID_KEYS = %i(byr iyr eyr hgt hcl ecl pid cid)
```

...and after that, we want to use our `Any` trick to demonstrate something fun about pattern matching against an arbitrary set of keys:

```ruby
VALID_KEYS_MAP = VALID_KEYS.to_h { |k| [k, Any] }
```

That allows us to do something like this:

```ruby
some_hash in VALID_KEYS_MAP
```

...or in the case of this validation, we want to drop `:cid`, and Ruby 3 gives us a fresh function from Rails land: `except`:

```ruby
VALID_NORTH_POLE_MAP = VALID_KEYS_MAP.except(:cid)
```

Which does just what you might think, all keys except that one or a list of ones.

Now that brings us to `valid_passports`.

## `to_h` on keypairs

`to_h` takes a function as of Ruby 2.7, meaning no more `map.to_h`:

```ruby
def valid_passports(passports)
  passports.filter_map do |passport|
    parsed_passport = passport
      .split
      .to_h { _1.split(':') }
    # ...
```

So all those arbitrary keypairs in that file? `split` goes by whitespace, meaning it can handle the format disparity, and we can feed it straight to `to_h` to make it into the hash we want.

You might notice we also transform them to Symbol keys, again, for pattern matching reasons:

```ruby
.transform_keys(&:to_sym)
```

## Woven into the Pattern

So now we can do this:

```ruby
parsed_passport if parsed_passport in VALID_NORTH_POLE_MAP
```

...which checks that the `parsed_passport` has all the valid north pole keys present. Granted we could do a comparison on keys, but again, Ruby 3.0 demos take precedence for now.

Why the `parsed_passport if` ? We're using `filter_map` above, which allows us to only keep passports that are valid, but also keep them in the newly deserialized (made into a hash) format.

While we don't directly need those values they can be very useful to look at for debugging, or in case requirements change later as they're wont to do.

## It Counts

Then we're down to our old endless function trick for wrapping the above function to get the count:

```ruby
def valid_passport_count(...) = valid_passports(...).size
```

## Splitting on Something Different

You might notice that I didn't use `readlines` here:

```ruby
File.read(ARGV[0]).split(/\n\n/).then { puts valid_passport_count(_1) }
```

That's because each record has a blank line, or `\n\n`, between them. If we split on newline we'd get fragments of records which makes a mess. With this we can feed records straight into our function and away we go.

...and with that we have our solution for part one of day four.

# Day 04 - Part 02 - Validations for Passports

Part two adds a significant number of validations, and gives us a chance to try out all types of interesting features of Ruby. Let's start by taking a look at the solution, and this one will be a trip:

```ruby
require 'any'

str_int_within = -> range { -> v { range.cover? v.to_i } }

HEIGHT_REGEX          = /(?<n>\d+) ?(?<units>cm|in)/
HAIR_COLOR_REGEX      = /^\#[0-9a-z]{6}$/
PASSPORT_ID_REGEX     = /^[0-9]{9}$/
EYE_COLOR_REGEX       = Regexp.union(*%w(amb blu brn gry grn hzl oth))
VALID_BIRTH_YEAR      = str_int_within[1920..2002]
VALID_ISSUED_YEAR     = str_int_within[2010..2020]
VALID_EXPIRATION_YEAR = str_int_within[2020..2030]
VALID_CM_HEIGHT       = str_int_within[150..193]
VALID_IN_HEIGHT       = str_int_within[59..76]

VALID_HEIGHT =
  -> { HEIGHT_REGEX.match(_1) } >>
  -> { _1&.named_captures } >>
  -> { _1&.transform_keys(&:to_sym) } >>
  -> {
    case _1
    in units: 'cm', n: VALID_CM_HEIGHT
      Any
    in units: 'in', n: VALID_IN_HEIGHT
      Any
    else
      nil
    end
  }

def valid_passports(passports)
  passports.filter_map do |passport|
    parsed_passport =
      passport
    		.split
    		.to_h { _1.split(':') }
    		.transform_keys(&:to_sym)

    parsed_passport if parsed_passport in {
      byr: VALID_BIRTH_YEAR,
      iyr: VALID_ISSUED_YEAR,
      eyr: VALID_EXPIRATION_YEAR,
      hgt: VALID_HEIGHT,
      hcl: HAIR_COLOR_REGEX,
      ecl: EYE_COLOR_REGEX,
      pid: PASSPORT_ID_REGEX
    }
  end
end

def valid_passport_count(...) = valid_passports(...).size

File.read(ARGV[0]).split(/\n\n/).then { puts valid_passport_count(_1) }
```

Now there's a lot going on here, and a lot of fun things to explore, so let's get to it.

## Closures Quickly

This line has what's called a closure:

```ruby
str_int_within = -> range { -> v { range.covers? v.to_i } }
```

Why is a function returning a function? Because it's very useful! Let's start with something a bit simpler, an adder:

```ruby
adds = -> a { -> b { a + b } }
```

If we call it, it returns back a function that remembers what it was called with, or rather it remembers `a`:

```ruby
adds_3 = adds[3]
adds_3[3]
# => 6
```

We can even pass it to other functions:

```ruby
[1, 2, 3].map(&adds[3])
# => [4, 5, 6]
```

So back to `str_int_within`, we want a function that can check if a number represented as a string is within a range of years, or numbers:

```ruby
str_int_within = -> range { -> v { range.covers? v.to_i } }
```

Let's take a look at the first constant which references it:

```ruby
VALID_BIRTH_YEAR = str_int_within[1920..2002]
```

We can test this with:

```ruby
VALID_BIRTH_YEAR['1800']
# => false

VALID_BIRTH_YEAR['2000']
# => true

array_of_birth_years.select(&VALID_BIRTH_YEAR)
```

So this concept is real flexible, and can even be used in pattern matching below. If you want to learn more about closures [give this article a read](/writing/2018/05/13/functional-programming-in-ruby-closures/).

We use this idea for this set of constants for validation:

```ruby
VALID_BIRTH_YEAR      = str_int_within[1920..2002]
VALID_ISSUED_YEAR     = str_int_within[2010..2020]
VALID_EXPIRATION_YEAR = str_int_within[2020..2030]
VALID_CM_HEIGHT       = str_int_within[150..193]
VALID_IN_HEIGHT       = str_int_within[59..76]
```

## Some Quick Regex

Let's take a look at our first set of validation constants:

```ruby
HEIGHT_REGEX          = /(?<n>\d+) ?(?<units>cm|in)/
HAIR_COLOR_REGEX      = /^\#[0-9a-z]{6}$/
PASSPORT_ID_REGEX     = /^[0-9]{9}$/
EYE_COLOR_REGEX       = Regexp.union(*%w(amb blu brn gry grn hzl oth))
```

Why constants? Because we can give these validations names to explain what they do.

The interesting one here is `Regexp.union` which allows us to join multiple regular expressions, or strings, into one that matches any of the inputs. Granted we _could_ have used `include?`, but `Array` doesn't respond to `===` making it non-ideal for pattern matching. Regex does:

```ruby
/abc/ === 'abc'
# => true

case something
when /abc/ then true
else false
end
```

That's how `case / when` and `case / in` work to match values, `===`. Nifty stuff, and a shame that `Array` and `Hash` don't implement it.

## Composing Something Fun

Now this one is admittedly going more than a bit overkill, but is fun nonetheless to demonstrate concepts:

```ruby
VALID_HEIGHT =
  -> { HEIGHT_REGEX.match(_1) } >>
  -> { _1&.named_captures } >>
  -> { _1&.transform_keys(&:to_sym) } >>
  -> {
    case _1
    in units: 'cm', n: VALID_CM_HEIGHT
      Any
    in units: 'in', n: VALID_IN_HEIGHT
      Any
    else
      nil
    end
  }
```

The first line is a function which uses the `HEIGHT_REGEX` from above to check if it's a valid height, and if so it gives us back some lovely `MatchData` with the `unit` and how many there are.

The symbol after it composes the functions, or puts them together. It goes through the first, then the output of the first goes through the second, and so on and so forth.

The second line is guarding against the fact that the first might return `nil` by using the lonely operator (`&.`) which will return `nil` as well if called on `nil`, or call through to the actual function if we have some valid `MatchData` to work with.

The third line is back to our tricks of symbolizing keys for pattern matching.

The fourth is where it gets a bit more interesting in the full `case / in` pattern match:

```ruby
case _1
in units: 'cm', n: VALID_CM_HEIGHT
  Any
in units: 'in', n: VALID_IN_HEIGHT
  Any
else
  nil
end
```

By this point `_1` are our capture groups, or it's `nil`. If it's `nil` or doesn't match the above conditions we just return back `nil` to represent an invalid height. The valid cases are the more interesting ones. It can pull the `units` and `n` from our match, and will compare the values using `===`. In this case those Regexes from above.

Bringing this all together, if we fed in a `String` containing a height it'd go through all those functions in sequence until it's in a format we can match against and say whether or not it's valid.

## Bringing it Together

Now this brings us to the distinct line in this solution, the pattern match. Nothing else has changed much, but this? This brings me some joy:

```ruby
parsed_passport if parsed_passport in {
  byr: VALID_BIRTH_YEAR,
  iyr: VALID_ISSUED_YEAR,
  eyr: VALID_EXPIRATION_YEAR,
  hgt: VALID_HEIGHT,
  hcl: HAIR_COLOR_REGEX,
  ecl: EYE_COLOR_REGEX,
  pid: PASSPORT_ID_REGEX
}
```

We can express a validation in a format like this. It opens up a whole world of possibilities in validating JSON or other data, and my do I have some ideas for the future.

Do note we can't use expressions inline, or I'd consider doing more of this inline. There are bug reports to make that possible with pin and parens: `^(expr)`, but some concerns on speed come with it.

That about wraps up part two, and that was a trip experimenting, and something I quite enjoyed.

# Wrapping Up Day 04

That about wraps up day four, we'll be continuing to work through each of these problems and exploring their solutions and methodology over the next few days and weeks.

If you want to find all of the original solutions, check out [the Github repo](https://github.com/baweaver/advent_of_code_2020) with fully commented solutions.

[<< Previous](/writing/2020/12/28/advent-of-ruby-3-0-day-03-toboggan-trajectory-4e9c/) | [Next >>](/writing/2020/12/29/advent-of-ruby-3-0-day-05-binary-boarding-2m8f/)
