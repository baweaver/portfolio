---
layout: "post"
title: "Understanding Ruby - Blocks, Procs, and Lambdas"
series: "understanding-ruby"
date: "2021-02-07"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional"]
description: "Introduction   Ruby is a language that uses multiple paradigms of programming, most usually..."
---

# Introduction

Ruby is a language that uses multiple paradigms of programming, most usually Object Oriented and Functional, and with its functional nature comes the idea of functions.

Ruby has three main types of functions it uses: Blocks, Procs, and Lambdas.

This post will take a look at all of them, where you might find them, and things to watch out for when using each of them.

The more you've used languages like Java and C++ the less likely you are to have encountered some of these ideas, but if you've spent time around Javascript a lot of this is going to look very familiar.

## Difficulty

**Foundational**

No prerequisite knowledge needed. This post focuses on foundational and fundamental knowledge for Ruby programmers.

# Blocks, Procs, and Lambdas

To start out with it should be noted that each of these three concepts are anonymous functions. In fact I've tended to call them _Block Functions_, _Proc Functions_, and _Lambda Functions_ to remind myself there's not really anything special about them beyond just being functions which act slightly different.

That all said, what exactly is a function, and why do we care about them in Ruby? 

## The Idea of Functions

### What is an Anonymous Function?

Why anonymous? In Javascript the difference is that one has a name and the other doesn't:

```js
const anonymousAdder = function (a, b) { return a + b; }
function adder(a, b) { return a + b; }

anonymousAdder(1, 2)
// => 3

adder(1, 2)
// => 3
```

In Ruby we don't really have an idea of named functions as much as methods:

```ruby
def adder(a, b) = a + b

adder(1, 2)
# => 3
```

> **Note**: The above is the one-line method syntax introduced in Ruby 3.0, which is great for short methods which focus on returning results and are on the shorter side.

...and for anonymous functions we have things like lambdas:

```ruby
adder = -> a, b { a + b }

adder.call(1, 2)
# => 3
```

> **Note**: This syntax, for reference, is known as "stabby lambda". The arguments are to the right of the arrow and the body of the function is between the braces. Return values are implied from the last expression evaluated, `a + b` in this case.

When does this come up in Ruby? Well it turns out a lot, because _Block Functions_ are also anonymous. Consider `map`, the idea of applying a function to every item in a list and returning a new list:

```ruby
[1, 2, 3].map { |v| v * 2 }
# => [2, 4, 6]
```

This allows us to express the idea of doubling every element in a list in a concise way. If we were to write that in the same way as Java or C might before modern versions introduced `map` and other functional concepts were introduced, it'd look more like this:

```ruby
def double_items(list)
  new_list = []
  
  for item in list
    new_list << item * 2
  end
  
  new_list
end
```

> **Warning**: Avoid using `for ... in` in Ruby, prefer `each` which we will mention in a moment.

The above anonymous function allows us to abstract the entire idea of transforming elements into one line, and with that comes a substantial amount of power.

We won't get into all the fun things we can do with functions in this article, but rest assured we'll be covering it soon.

### Where Are Functions Used?

In Ruby all over the place. Consider `each`, the way Ruby prefers to go over each element of a list:

```ruby
[1, 2, 3].each { |v| puts v }

# STDOUT: 1
# STDOUT: 2
# STDOUT: 3
# => [1, 2, 3]
```

> **Note**: `STDOUT` represents the standard output, or typically your console screen. `=>` represents a return value, and `each` returns the original `Array`. I comment these out (`#` for comment) just in case you copy that while trying out code.

That right there? Well that's a _Block Function_. It goes over every element of a list and gives that value to the function with the name of `v`. Function arguments are put in pipes (`|`) and separated by commas (`,`) if there are many of them. The function itself is surrounded in brackets (`{}`).

In this particular function we're outputting the value of `v` to `STDOUT`.

You might also see a _Block Function_ look like this:

```ruby
[1, 2, 3].each do |v|
  puts v
end

# STDOUT: 1
# STDOUT: 2
# STDOUT: 3
# => [1, 2, 3]
```

They both do the same thing.

#### Nuances of Braces vs Do / End

Typically in Ruby people prefer to use `{}` for one-line functions and `do ... end` for multi-line functions. Myself? I tend to prefer the [Weirich method](https://github.com/rubocop-hq/ruby-style-guide/issues/162) instead which signifies that `{}` is used for functions whose primary role is to return a value, and `do ... end` is to execute side effects.

Either is fine, but be sure to stay consistent in whichever one you choose in your codebase, and even more-so follow the semantics and rules of established codebases rather than impose your own opinions on them.

#### Functional Differences and Syntax Issues

There _are_ some differences with parenthesis and how each evaluates them which you may run into. Consider RSpec code here:

```ruby
describe 'something fun' do
  # ...
end

describe 'something fun' {
  # ...
}
# SyntaxError (1337: syntax error, unexpected '{', expecting end-of-input)
# describe 'something fun' {
```

The second will syntax error while the first will work just fine. That's because to the second it's ambiguous whether that's a `Hash` argument or a function, causing Ruby to throw an error. If you put parens around `'something fun'` it'll work just fine:

```ruby
describe('something fun') {
  # ...
}
```

...but most prefer `do ... end` for RSpec code, as do I.

### Calling a Function

So how does one call a function versus a method? Well there are a few ways, and we'll focus again on _Lambda Functions_ here:

```ruby
adder = -> a, b { a + b }

adder.call(1, 2)
# => 3

adder.(1, 2)
# => 3

adder[1, 2]
# => 3
```

There are a few others like `===` that only work with one-argument functions unless you do some really nasty things like this:

```ruby
adder === [1, 2]
# ArgumentError (wrong number of arguments (given 1, expected 2))

adder === 1, 2
# SyntaxError ((irb):157: syntax error, unexpected ',', expecting `end')

adder.===(*[1, 2])
=> 3
```

I would not suggest using that, nor would I suggest explicitly using `===` like this either. If you want more information on `===` consider giving [Understanding Ruby - Triple Equals](/writing/2021/02/06/understanding-ruby-triple-equals-2p9c/) a read.

There's one last way to call a function, `yield`, but we'll save that for the moment and explain it along with the next section on blocks.

#### Function Arguments

Now here's an interesting one that isn't mentioned very often: All valid method arguments are also valid function arguments:

```ruby
def all_types_of_args(a, b = 1, *cs, d:, e: 2, **fs, &fn)
end
```

That means you can very validly do this:

```ruby
lambda_map = -> list, &fn {
  new_list = []
  list.each { |v| new_list << fn.call(v) }
  new_list
}

lambda_map.call([1, 2, 3]) { |x| x * 2 }
# => [2, 4, 6]
```

Think how that might be fun with default arguments, and especially keyword arguments, as a fun little experiment potential for later.

### Ampersand (`&`) and `to_proc`

You may well see code like this in Ruby:

```ruby
[1, 2, 3].select(&:even?)
# => [2]
```

Searching for `&` can be difficult, so let's explain it here. `&` calls `to_proc` on whatever is after it. In the case of a `Symbol` here it calls `Symbol#to_proc` (the `to_proc` method on an instance of the `Symbol` class.)

It effectively generates code like this:

```ruby
[1, 2, 3].select { |v| v.even? }
# => [2]
```

...where the `Symbol` that's coerced into a _Proc Function_ acts like a method to be called on whatever is passed into the function. For `select` that would be the numbers `1, 2, 3`.

This also tells Ruby to treat this argument as a _Block Function_ for the sake of passing it to the underlying method, which we'll get to in a moment in our section on _Block Functions_.

> **Note**: `&` is syntactic sugar for `to_proc`, but does not work outside of this context. You can't do this for instance: `age_function = &:age`. It will result in a Syntax Error.

## Types of Functions

Now that we have some groundwork laid, let's take a look at the three types of functions: Block functions, _Proc Functions_, and Lambda functions.

> **Note**: _Technically_ `method` is another type of function, but we'll skip that section for this article and save it for a more detailed writeup later on Ruby methods.

### _Block Functions_

The first is likely the most familiar, and most likely to show up in your day to day Ruby code: The _Block Function_.

As you saw earlier with `each` it takes a _Block Function_:

```ruby
[1, 2, 3].each do |v|
  puts v
end
# STDOUT: 1
# STDOUT: 2
# STDOUT: 3
# => [1, 2, 3]
```

How do we define a function which takes a _Block Function_ like this? Well let's take a look at a few ways.

#### Explicit _Block Functions_

The first way is to explicitly tell Ruby we are passing a function to a method:

```ruby
def map(list, &function)
  new_list = []
  list.each { |v| new_list << function.call(v) }
  new_list
end

map([1, 2, 3]) { |v| v * 2 }
# => [2, 4, 6]
```

Functions are prefixed by `&`. Frequently you will see this called `&block`, but for me I tend to prefer `&function` to clarify the intent that this is a function I intend to use. Frequently I abbreviate it as `&fn`, but that's just my preference.

For this new `map` method we're iterating over each item in the list and putting those items into the `new_list` after we call `function` on each of them to transform the values. After that's done we return back the `new_list` at the end.

My preference is for explicit functions because they let me know from the arguments of the method that it takes a function.

#### Implicit _Block Functions_

The next way is implied, and uses the `yield` keyword:

```ruby
def map_implied(list)
  new_list = []
  list.each { |v| new_list << yield(v) }
  new_list
end

map_implied([1, 2, 3]) { |v| v * 2 }
# => [2, 4, 6]
```

`yield` is interesting here as it can be present any number of times in a method. In this case we only want it mentioned once in our iteration of the original list. We could technically do this too:

```ruby
def one_two_three
  yield 1
  yield 2
  yield 3
end

one_two_three { |v| puts v + 1 }
# STDOUT: 2
# STDOUT: 3
# STDOUT: 4
# => nil
```

Though I have not found a use for this myself in my code.

`yield` is a keyword that yields a value to the implied function the method was called with. Once it runs out of `yield`s it stops calling the function.

Personally I do not like this as it's more confusing to me than the above, but you may well see this pattern in other Ruby code, so it's good to know it exists.

#### Ampersand (`&`) and _Block Functions_

So how does Ruby know this is a function to pass to a method? In this case it's implied:

```ruby
map([1, 2, 3]) { |v| v * 2 }
# => [2, 4, 6]
```

...but in this case with a lambda not quite so much:

```ruby
add_one = -> a { a + 1 }

map([1, 2, 3], add_one)
# ArgumentError (wrong number of arguments (given 2, expected 1))
```

It's treated as an additional argument unless we prefix it with `&` to tell the method that this is a _Block Function_ it needs to treat as such:

```ruby
add_one = -> a { a + 1 }

map([1, 2, 3], &add_one)
# => [2, 3, 4]
```

#### Block Given and the Missing Block

So what happens if we forget the _Block Function_ then? In the case of our explicit style:

```ruby
map([1, 2, 3])
# NoMethodError (undefined method `call' for nil:NilClass)
```

For our implicit one:

```ruby
map_implied([1, 2, 3])
# LocalJumpError (no block given (yield))
```

We can guard against this by checking if a _Block Function_ has been given to the method:

```ruby
def map(list, &fn)
  return list unless block_given?
  
  # ...rest of implementation
end
```

In this case if we forget the _Block Function_ it returns the initial list. For Ruby itself it returns an `Enumerator` instead:

```ruby
[1, 2, 3].map
# => #<Enumerator: [1, 2, 3]:map>
```

We'll get into `Enumerator`s another day though.

### _Proc Functions_

The next type of function we'll look into are _Proc Functions_. You may have noticed `to_proc` before, but perhaps amusingly you could return a _Lambda Function_ from that.

It should be noted that _Proc Functions_ are the base for _Lambda Functions_, and why I'm covering them first.

A _Proc Function_ can be defined in a few ways:

```ruby
adds_two = Proc.new { |x| x + 2 }
adds_two.call(3)
# => 5

adds_three = proc { |y| y + 3 }
adds_three.call(2)
  # => 5
```

#### Behavior with Arguments

What's interesting about a _Proc Function_ is that they don't care about the arguments passed to them:

```ruby
adds_two = Proc.new { |x| x + 2 }
adds_two.call(3, 4, 5)
# => 5
```

The only reason it would is if the first argument is missing, and only because that causes an error inside the function itself. They can be quite lazy like that. This is one crucial reason why I tend to prefer _Lambda Functions_, but we'll get into that in a moment.

#### Behavior with Return

This is another interesting case. If we use `return` inside of a _Proc Function_ it can do some bad things:

```ruby
adds_two = Proc.new { |x| return x + 2 }
adds_two.call(3, 4, 5)
# LocalJumpError (unexpected return)
```

...but if we did that inside of a method instead:

```ruby
def some_method(a, b)
  adds_three_unless_gt_three = proc { |v|
    return v if v > 3
    v + 3
  }
    
  adds_three_unless_gt_three.call(a) +
  adds_three_unless_gt_three.call(b)
end
  
some_method(1, 1)
# => 8, or 4 + 4, or (1 + 3) + (1 + 3)

some_method(5, 5)
# => 5
```

`return` actually broke out of the method itself instead of returning a value from the function. If we wanted behavior like `return` without this we could use `next` instead, but this is another reason I tend to prefer _Lambda Functions_.

### _Lambda Functions_

The next type of function we'll look into are _Lambda Functions_. To start with remember a _Lambda Function_ looks something like this:

```ruby
adds_one = -> a { a + 1 }
adds_one.call(1)
# => 2
```

...but it can also look like this, though it's much rarer syntax to see:

```ruby
adds_three = lambda { |z| z + 3 }
adds_three.call(4)
# => 7
```

Interestingly _Lambda Functions_ are a type of _Proc Function_, try it yourself:

```ruby
-> ruby {}
# => #<Proc:0x00007ff3d88c30d8 (irb):231 (lambda)>
```

> **Note**: I keep using different argument names as a reminder that the names are arbitrary and could be anything as long as it's a valid variable name. If you want another interesting fact any valid method argument is also a valid argument to any function.

#### Behavior with Arguments

_Lambda Functions_, unlike _Proc Functions_, are very strict about their arguments:

```ruby
adds_four = -> v { v + 4 }
adds_four.call(4, 5, 6)
# ArgumentError (wrong number of arguments (given 3, expected 1))
```

They behave much more like methods in this, and can lead to less confusing errors later.

#### Behavior with Return

_Lambda Functions_ will treat `return` as a local `return` rather than trying to return from the outer context of the method:

```ruby
def some_method(a, b)
  adds_three_unless_gt_three = -> v {
    return v if v > 3
    v + 3
  }
    
  adds_three_unless_gt_three.call(a) +
  adds_three_unless_gt_three.call(b)
end

some_method(1,1)
# => 8
some_method(5,5)
# => 10
```

That means both executions of the function will `return` the value `5` instead of returning `5` for the entire function.

# Wrapping Up

This was a fairly broad overview of the types of functions in Ruby, but does not get too much into why you'd want to use them. Rest assured there will be future posts covering this as well.

In Ruby there are several ways to do one thing, and because of that it's useful to know what syntax does what, especially early on. Personally I prefer to pare down the syntax in certain areas, like I tend to use _Lambda Functions_ almost exclusively over _Proc Functions_, and can't think of a case where I would need to use them instead.

The real fun of functions starts when you start seeing what you can do with them. The following posts on `Enumerable` and Functional Programming will be very interesting on that note, but until then that's all I have for today.

Want to keep up to date on what I'm writing and working on? [Take a look at my new newsletter: The Lapidary Lemur](https://buttondown.email/baweaver/)
