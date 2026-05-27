---
layout: "post"
title: "Pattern Matching Interfaces in Ruby"
date: "2023-01-24"
categories: ["cybersecurity", "discuss"]
tags: ["cybersecurity", "discuss", "productivity"]
description: "Defining a standard for implementing pattern matching interfaces in Ruby, originally from the 2021..."
---

Defining a standard for implementing pattern matching interfaces in Ruby, originally from the 2021 document ["Pattern Matching Interfaces in Ruby"](https://docs.google.com/document/d/1spnuQTKy5i7Lx-sDCsORKN981Iam1IuNdOsYkhh9Yi0/edit#)

**Author**: Brandon Weaver ([@baweaver](https://ruby.social/@baweaver))

**Last Updated:** January 20, 2021

**Status**: RFC

**Contributors**:

* Vlad Dementyev ([@palkan_tula](https://twitter.com/palkan_tula))
* Kazuki Tsujimoto ([@k_tsj](https://twitter.com/k_tsj))

## Overview

_What does this document intend to achieve?_

Pattern Matching is a powerful new syntax in Ruby that allows us more flexibility in retrieving data from nested structures and more power in making assertions about the structure of that data.

This document intends to define a set of best practices for defining pattern matching interfaces in Ruby code.

As it is very easy to add methods to Ruby, but very hard to remove them, it would be in the best interest of the community to agree on a set of best practices in adding these methods to popular gems and standard library features.

### Prerequisite Reading

_If you are not familiar with Pattern Matching in Ruby, start here_

* [RubyLang Docs - Pattern Matching](https://docs.ruby-lang.org/en/3.0.0/doc/syntax/pattern_matching_rdoc.html)
* [Toptal - Ruby Pattern Matching Tutorial](https://www.toptal.com/ruby/ruby-pattern-matching-tutorial)
* [Pattern Matching First Impressions](/writing/2019/04/17/ruby-2-7-pattern-matching-first-impressions-13j9/)

### Tools and Utilities

_Pattern Matching tools and utilities to make working with the interface easier_

* [Dio](https://github.com/baweaver/dio) - Fakes pattern matching interfaces on any class via a wrapper
* [Matchable](https://github.com/baweaver/matchable) - Class-method porcelain methods for deconstruct and keys
* [Deconstructable](https://gitlab.com/alexkalderimis/deconstructable) - Simpler version of Matchable, same idea behind it

## Pattern Matching Interfaces

_Proposed common interfaces and considerations for pattern matching interfaces_

While there are some significant commonalities and ideas for common pattern matching interfaces there can be a lot of variance and nuance depending on the class that the interfaces are being applied to. This section seeks to explore some of these concerns.

### Array-Like Structures

_Matching against Array-like structures_

#### Implementations


##### Array-like Types and Tuples

The `deconstruct` method is the established interface for matching against Array-like structures that respond to methods like `to_a`,` to_ary`, `each`, or other collection-like methods. It allows for the following syntax:

```ruby
class Cons
  attr_reader :value, :children

  def initialize(value, *children)
    @value = value
    @children = children
  end

  def self.[](...) = new(...)

  def to_a() = [@value, @children]

  alias_method :deconstruct, :to_a
end

list = Cons[1, Cons[2], Cons[3, Cons[4]]]
list in [1, children]
# => true
```

Given the overlap with common array coercion methods it is recommended to default to `to_a` for implementations of `deconstruct`.

##### Alternate Types

There are cases which exist, such as s-expressions, where this recommendation does not necessarily hold true. Marc-Andre had noted this in a [pull request to the Whitequark AST gem](https://github.com/whitequark/ast/pull/31/files), using the following implementation instead:

```ruby
def deconstruct() = [type, *children]
```

In this representation the structure is flattened to allow for easier access to the child nodes, which could also be applied to our above `Cons` class.

##### Paralleling Constructors

Official documentation also mentions the existence of the class-match syntax:

```ruby
case person
in Person[/^B/, 20..]
  true
else
  false
end
```

This makes a case for implementing deconstruct in terms of object constructors properties:

```ruby
class Person
  def initialize(name, age)
    @name = name
    @age  = age
  end

  def deconstruct() = [@name, @age]
end
```

But it should be noted that this syntax may be confusing for constructors with an arity greater than 3 unless the order is given special value like in the case of a 3D Point (x, y, z)

#### Considerations


##### When Order is Important

Array-like entities rely on order for potential matches meaning that deconstructed entities may require sorting before being matched against.

This is a [form of connascence](https://connascence.io/position.html) in which the data is coupled to its order, meaning that array-like matches do not make sense unless order is irrelevant or the data can be safely sorted before comparison.

Array-like data types are recommended for this type of matching to be effective. Notable exceptions to this rule would be Tuple-like types and paralleling class constructors with positional arguments.

##### When Order is Not Important

Arrays themselves do not require consistent order, and as such can be very expensive to match against with find patterns. Larger arrays compound this problem.

### Hash-Like Structures

_Matching against Hash-like structures_

While array-like matches have minimal potential variance, hash-like matches introduce substantial possibilities, and with them substantial considerations that must be accounted for in defining what an interface should look like.

The `deconstruct_keys` method for pattern matching against a hash-like structure also introduces arguments into the mix, further complicating potential solutions.

```
⚠️ Warning: Pattern matching with no arguments or
**rest supplied will have nil passed for the keys
argument. In this case all keys should be returned.
```

#### Implementations

##### Hash-like Type

If a type can be coerced to a `Hash` through either `to_h` or `to_hash` it can use this as a method to match against:

```ruby
class Person
  attr_reader :name, :age

  def initialize(name, age)
    @name = name
    @age = age
  end

  def to_h() = { name: @name, age: @age }
end
```

This provides a viable hook to add the `deconstruct_keys` method as we already have a hash-like interface exposed for the class.

The simple solution would be to use `alias` to point `deconstruct_keys` at `to_h`, but this would not account for the keys passed in. Instead, we should extract the keys from the `to_h` method result:

```ruby
class Person
  def deconstruct_keys(keys) = keys ? to_h.slice(*keys) : to_h
end
```

```
ℹ️ Note: There is a check for the presence of
keys here, as keys can be nil. Passing
**rest or no arguments to a match will result
in keys being nil, causing potential issues.
The intended behavior here should be to return
all possible keys rather than nothing.
```

As the hash-like interface already exposes all properties at once we can potentially avoid some of the performance considerations mentioned below in loading expensive methods.

##### Public Interfaces

The next implementation would rely on styling `deconstruct_keys` after the public interface of a class. This could be defined as the `attr_*` methods, or potentially all public zero-arity (or n-arity with defaults) methods defined on the class itself:

```ruby
class Person
  attr_reader :name, :age

  def initialize(name, age)
    @name = name
    @age = age
  end

  def adult?() = @age >= 18
  def me?()    = @name == 'Brandon'

  def deconstruct_keys(keys)
    deconstruction = {}
    
    deconstruction[:name]   = @name  if keys.nil? || keys.include?(:name)
    deconstruction[:age]    = @age   if keys.nil? || keys.include?(:age)
    deconstruction[:adult?] = adult? if keys.nil? || keys.include?(:adult?)
    deconstruction[:me?]    = me?    if keys.nil? || keys.include?(:me?)

    deconstruction
  end
end
```

As with the above case, if `keys` is `nil` we want to return all possible keys, making this interface potentially very cumbersome.

The below Constant Guard may help to alleviate some of this while also being more explicit.

##### Instance Variables

The next potential is to rely on instance variables to define the interface:

```ruby
def deconstruct_keys(keys)
  ivars = instance_variables.to_h { [_1.to_s.delete('@').to_sym, _1] }
  valid_keys = keys.intersection(ivars.keys)

  valid_keys.to_h { [_1, instance_variable_get(ivars[_1])] }
end
```

This may, however, expose parts of a classes API which may not make sense.

##### Constant Guard

Using a constant to define valid keys to guard against loading the entirety of the deconstructable keys is recommended when working with very large APIs with many keys:

```ruby
class Time
  VALID_KEYS = %i(year month day wday)

  def deconstruct_keys(keys)
    # If `keys` is `nil` return back all valid keys
    valid_keys = keys ? VALID_KEYS & keys : VALID_KEYS
    valid_keys.to_h { [_1, public_send(_1)] }
  end
end
```

This prevents loading keys that are not required by the match, but requires each key to be tied to a method. In the case of an instance variable with a corresponding `attr_reader` or `attr_accessor` method this is a non-issue, but should be considered.

In the case of most applications the performance implication of using `public_send` should not be enough to cause concern, but [there are tricks to dynamically compile](https://github.com/baweaver/matchable) against this using `eval` in case performance becomes an issue.

##### Manual

The most likely correct case for more complicated classes is to manually decide between a combination of the above three. While the public interface of a class may be the best base, some methods may not make sense for pattern matching due to their arity, requiring more discretion.

#### Considerations

##### Keys can be `nil`

The `deconstruct_keys` method can receive `keys` as a `nil` rather than an `Array`. This is done in cases of no arguments being passed or `**rest` being passed, and should result in all potential keys being returned rather than no keys.

##### Expensive Methods

As `keys` are passed into the `deconstruct_keys` method it gives a unique chance to not calculate unnecessary and potentially expensive keys. Consider the retrieval of a `body` from an `HTTP` request that has not been realized. Calculating this on each match would be expensive, and should be avoided unless the key is explicitly required.

##### Arity

As mentioned above, zero-arity of n-arity with defaulted arguments is required to add a method as a potential value to match against.

##### Boolean / Predicate Methods

Boolean methods introduce an interesting conundrum. They are within the public interface and have the correct arity, however do we want to allow matching against them? I would say yes as this could be a very useful signal to capture:

```ruby
http_response in { ok?: true, body?: true, text?: true }
```

Though we could also match directly against the underlying attributes as well.

##### String Keys

There are some cases in which a hash with `String` keys is returned, introducing another conundrum: Do we conflate `Symbol` and `String` keys to be able to match against this? Rely on things like `symbolize_names` or `with_indifferent_access`?

This will require much thought, as the act of letting Rubyists see these as interchangeable in a more official capacity will lead to problems down the road with confusion.

##### Missing Keys and Key Validation

There are current implementations in which missing keys will result in no match, but there could be an argument for raising an exception on unknown keys for matching. Some cases of matching will use constants for known keys, which can be useful for finding expected versus unexpected values.


## Testing in Older Versions

_How to test Pattern Matching in gems and applications below Ruby 2.7_

Pattern Matching introduces a new syntax to Ruby, and with it a break in syntax for all previous versions. This means that testing it in any gem or application that can still plausibly run on earlier versions of Ruby will cause issues.

### Eval Guards

_Using eval and rescue to avoid syntax errors_

The `eval` method can be used to avoid the parser finding syntax errors in code. It is recommended to also `rescue SyntaxError` afterwards to avoid the need for version locks which can be error-prone. Consider:

```ruby
begin
  instance_eval <<~RUBY, __FILE__, __LINE__ + 1
    response in [200, *]
  RUBY
rescue SyntaxError
  # Not Ruby 2.7+
end
```

While not the most elegant code it serves the purpose of preventing execution in older Ruby versions from crashing. It is also the least invasive method to a gem or application's testing structure.

### Versioned Requires

_Loading version specific testing files to prevent syntax errors_

The more invasive technique would be to add all pattern matching tests to a separate file that is locked behind version checks and not loaded unless the current Ruby version is MRI-equivalent of 2.7+.

## Proposed Best Practices

_Best Practices in implementing pattern matching interfaces_

As there is a significant amount of variance in Ruby code and how it is written, this document also proposes a set of best practices addressing both array and hash-like pattern matches as separate entities.

### General Best Practices

_Best Practices for matching against any type_

#### Least Needed Power

Avoid using items like expressions when another check can be used first. Consider first using the Ruby concept with the least power that still solves the same problem.

#### Nest Patterns Sparingly

While you can indeed nest pattern matches several layers deep, do so sparingly as it decreases the readability of code very quickly after more than 3 layers. If nesting cannot be avoided, use multiple lines to express the pattern:

```ruby
data = { a: { b: 1, c: { d: { e: 6, f: 7} } } }

# Bad
data => { a: { b: Integer, c: { d: _ => last_node } } }
# => true

# Good
data => {
  a: {
    b: Integer,
    c: {
      d: _ => last_node
    }
  }
}
# => true
```

#### Avoid Mutation

Pattern matching should not mutate the data under the match via method, as this will lead to very confusing results. As such `bang!` methods should be avoided in interfaces as well as ones that mutate the underlying data in any manner:

```ruby
class Person
  def birthday!
    @age += 1
  end

  # AVOID - Do not add `birthday!` as it causes mutation
  def to_h() = { name: @name, age: @age, birthday!: birthday! }

  def deconstruct_keys(keys) = keys ? to_h.slice(*keys) : to_h
end
```

#### Avoid Shadowing Variables

Shadowing an outer variable with a pattern match will result in it being overwritten, leading to potentially confusing results:

```ruby
v = 1        # => 1
h = { v: 3 } # => {:v=>3}
h in { v: }  # => true
v            # => 3
```

#### Name Captures Well

Captured variables should be named well to reflect their intention. Pattern matching syntax may be difficult to read with single-letter capture names or abbreviations, which will lead to greater confusion by those reading the code.

This is especially true in the case of right-hand assignment using the rocket operator:

```ruby
Card = Struct.new(:suit, :rank)

# Bad
Card['S', 'A'] => Card['S' => s, r]

# Good
Card['S', 'A'] => Card['S' => suit, rank]
```

#### Prefer Underscore to Asterisk

Underscores (`_`) serve the purpose of matching any one value. While asterisk (`*`) can do this, it constitutes a find pattern and is substantially more expensive. Only use it if you intend to have a relative position you're matching against:

```ruby
# Bad
Card['S', 'A'] in Card[*, r]

# Good
Card['S', 'A'] in Card[_, r]
```

#### Prefer One-Line Matches for Boolean Queries

If your match is meant to return `true` or `false` based on a single branch consider using a one-line pattern match instead:

```ruby
data = { a: 1, b: 2, c: 3 }

# Bad
case data
in a: 1..3, b: 2..5
  true
else
  false
end

# Good
data in { a: 1..3, b: 2..5 }

# Good
case data
in a: 1..3, b: 2..5
  true
in a: 1..3, c:, 3..10
  true
else
  false
end

# Bad

return true if data in { a: 1..3, b: 2..5 }
return true if data in { a: 1..3, c:, 3..10 }

false
```

#### Whitespace is Free - Use It

Avoid dense pattern match stanzas that push the limits of how much code you can put on one line. Prefer to break up patterns, especially nested ones, into multiple lines:

```ruby
# Bad
response in { status:  200, body: /Hello/, version: /^1\.\d/, headers: [] }

# Good
response in {
  status:  200,
  body:    /Hello/,
  version: /^1\.\d/,
  headers: []
}
```

### Array-Like Best Practices

_Best Practices for matching against Array-like data_

#### Avoid Types Without Array Interfaces

Array-like pattern matching should not be added to classes which cannot be cleanly represented as an array first. Consider using Hash-like matching instead in these cases. There is one exception, the next item.

#### Constructor Parallels Work for Non-Array-like Classes

The exception to the above rule is that paralleling class constructors is a valid use for deconstruction, as the following is an array-like match:

```ruby
class Person
  def initialize(name, age)
    @name = name
    @age  = age
  end

  def deconstruct() = [@name, @age]
end

case Person.new("Brandon", 30)
in Person[/^B/, 20..]
  true
else
  false
end
```

It should be noted that constructors with several positional arguments are not recommended, either for pattern matching or in general, as positionality of arguments with no relevance to position are confusing.

#### Be Conscious of Order Dependency

Be conscious and aware of any order dependencies in your matches to reduce the number of necessary matches to work with the data under match. Consider sorting before matching, or on insertion or creation of the instance:

```ruby
class Hand
  def deconstruct() = @cards.sort
end
```

#### Use Find-Pattern Sparingly

While find-pattern is indeed powerful, consider the above point on order dependency and whether doing so may solve the same problem. While it is powerful it comes at a speed cost. It should be noted that this is the find pattern:

```ruby
value in [*, match_we_want, *]
```

...and this is not:

```ruby
value in [match_we_want, *]
```

### Hash-Like Best Practices

_Best Practices for matching against Hash-like data_

#### Use Constants for Valid Keys

Constants can help to clarify which keys are valid to be passed to the pattern matching method `deconstruct_keys`:

```ruby
class Person
  attr_reader :name, :age

  VALID_KEYS = %i(name age)

  def initialize(name, age)
    @name = name
    @age = age
  end

  def to_h() = { name: @name, age: @age }

  def deconstruct_keys(keys)
    # If `keys` is nil, return all valid keys here, otherwise intersect
    # provided keys with valid ones
    valid_keys = keys ? VALID_KEYS & keys : VALID_KEYS

    to_h.slice(*valid_keys)
  end
end
```

#### Return All Possible Keys when `keys` is `nil`

`keys` can be `nil` in the case of no arguments being passed as well as a `**rest` style argument being present. In both cases all possible keys should be returned to the interface rather than raising an error or returning nothing:

```ruby
def deconstruct_keys(keys) = keys ? to_h.slice(*keys) : to_h
```

#### Maintain Public Interfaces

Pattern matching should not violate or break encapsulation for the sake of matching against data.


```ruby
def deconstruct_keys(keys)
  return {} unless keys

  # Avoid `send`, as it breaks public interface
  keys.to_h { [_1, send(_1)] }
end
```

#### Add Slowly, Avoid Removal

More potential keys can always be added, but removing them will become very difficult once someone uses them in their code. Consider slowly adding the most obvious keys to match against until a reasonable case has been made to add more.

#### Minimize Exposed Key Hooks

As with the above item about adding slowly, avoid over encumbering your pattern matching interface with every possible key, instead preferring a minimal subset needed to be effective to match against that are well tested and documented.

#### Be Cautious of Expensive Keys

Evaluation of some requested key values may be expensive, such as an unevaluated HTTP response body, and as such should not be generated unless that key is specifically requested.

#### Use Expressions Sparingly

While expressions are powerful and open up substantial flexibility in pattern matching they should be used infrequently as they can slow down matches substantially. This is especially true when done in tight loops.

#### Avoid Complicated Expressions

Expressions should be kept short and concise. If you've added more than a few method calls the expression should be broken out into a variable or a method instead to minimize the complexity of the match.

#### Be Explicit About Keys

As much as possible be explicit about what keys are allowed to match against for documentation and validation reasons of the match itself. Implicit keys are hard to quantify, cache, and error-check against. They can also lead to confusing behavior.

#### Right-Hand Assign to Clarify Names

When a Hash key does not properly reflect the intention of a capture, rename it using the rocket (`=>`) to clarify the intended purpose of the capture in relation to the key name:

```ruby
case response
in status: 400.., body: => error
  Failure(error)
else
  Failure('Unknown')
end
```

### One-Liner Best Practices

_Best Practices for One-Line Pattern Matching_

#### Rocket for Assignment, in for Truthiness

While `in` will expose captures from a pattern match it should only be used for boolean expressions. Prefer the rocket (`=>`) for assignments in which you need to access these values later:

```ruby
data = { a: 1, b: 2, c: 3 }

# Bad
data in { a: 1..3 => a, b: 2..10 => b }
[a, b]

# Good
data => { a: 1..3 => a, b: 2..10 => b }
[a, b]
```

#### Whitespace is Free

Despite the one-liner name these cases can be broken into multiple lines, and should be preferred for readability. The name may be better served as "one-branch" pattern match instead to reflect this:

```ruby
# Bad
response in { status:  200, body: /Hello/, version: /^1\.\d/, headers: [] }

# Good
response in {
  status:  200,
  body:    /Hello/,
  version: /^1\.\d/,
  headers: []
}
```

#### Names Still Matter

Just because this is a one-liner you should still consider naming things appropriately and expressing intent clearly.

## Implementations of Interface

_What would these interfaces look like applied to popular gems and STDLIB?_

More examples will be added over the next few days to demonstrate the potential of this interface. Currently planned gems and techniques to evaluate are:

* ActiveRecord
* ActionController Params
* ActiveSupport Duration
* Nokogiri / Oga
* GraphQL
* Protobuf
* Date / Time / DateTime
* Ripper / RubyVM::AbstractSyntaxTree
* Set
* CSV
* TracePoint
* File / Dir / IO
* Net::HTTP and other HTTP clients / servers

Pattern matching interfaces can be simulated using gems such as [Dio](https://github.com/baweaver/dio) for testing purposes. It does not act as a replacement, but rather a stand-in to test interfaces without full implementations.

### HTTP.rb

_Popular HTTP client_

I [had submitted a PR](https://github.com/httprb/http/pull/643) against this repo, but I believe the two most interesting types to match against are responses and requests:

```ruby
# Response

def to_h
  {
    version:       @version,
    request:       @request,
    status:        @status,
    headers:       @headers,
    proxy_headers: @proxy_headers,
    body:          @body
  }
end

def deconstruct_keys(keys) = to_h.slice(*keys)

response in {
  status:  200,
  body:    /Hello/,
  version: /^1\.\d/
}
```

They fit the spirit of pattern matching, especially from an Elixir point of view.

### Rack

_Standard Ruby Server_

Much like HTTP.rb I believe classes such as `response` make ideal candidates for matching:

```ruby
def to_h
  { status: @status, body: @body }
end

# Hash Pattern Matching interface:
#
#     case response
#     in status: 200..299, body:
#       Success(body)
#     in status: 400.., body: => error
#       Failure(error)
#     else
#       Failure('Unhandled code')
#     end
def deconstruct_keys(keys)
  to_h.slice(*keys)
end
```

### Regexp MatchData

_Core Ruby Regular Expressions Implementation_

**Note**: This was merged into Ruby: https://github.com/ruby/ruby/pull/6216

`MatchData` from regular expressions, especially those with named captures, have an interface very similar to both arrays and hashes, making it an ideal type to target:

```ruby
class MatchData
  alias_method :deconstruct, :to_a

  def deconstruct_keys(keys)
    named_captures.transform_keys(&:to_sym).slice(*keys)
  end
end

IP_REGEX = /
  (?<first_octet>\d{1,3})\.
  (?<second_octet>\d{1,3})\.
  (?<third_octet>\d{1,3})\.
  (?<fourth_octet>\d{1,3})
/x

'192.168.1.1'.match(IP_REGEX) in {
  first_octet: '198',
  fourth_octet: '1'
}
# => true
```

Allowing for skipping intermediate variables in checking capture groups for relevant data.

### OpenStruct

_Quick Struct-like class initializer_

`OpenStruct` has a very similar interface to `Struct`, meaning that it can implement a similar pattern matching interface:

```ruby
class OpenStruct
  def deconstruct_keys(keys) = keys ? to_h.slice(*keys) : to_h
end

me = OpenStruct.new(name: 'Brandon', age: 30)
me in { name: /^B/ }
# => true
```

### Matrix

_Ruby implementation of mathematical matrices_

`Matrix` is an inherently array-like interface, making it an ideal candidate for aliasing `to_a`:

```ruby
class Matrix
  alias_method :deconstruct, :to_a
end
# => :deconstruct

Matrix[[25, 93], [-1, 66]] in [[20..30, _], [..0, _]]
# => true
```

This allows for very powerful queries against matrices.

## Final Thoughts

As mentioned above, this is a (mostly 1-1) transcription of [Pattern Matching Interfaces in Ruby](https://docs.google.com/document/d/1spnuQTKy5i7Lx-sDCsORKN981Iam1IuNdOsYkhh9Yi0/edit#) from 2021, but the content is still valuable today for those wanting to learn new pattern matching ideas, and find ways to implement interfaces in their own programs.

Some of these things have even been merged into the language since the doc, such as regexp, and some may still be at a later date.
