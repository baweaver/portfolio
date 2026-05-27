---
layout: "post"
title: "Understanding Ruby – Recursion"
series: "understanding-ruby"
date: "2022-08-26"
categories: ["ruby", "recursion"]
tags: ["ruby", "recursion", "functional"]
description: "To understand recursion, you must first understand recursion. Cute, but perhaps not the most useful..."
---

To understand recursion, you must first understand recursion. Cute, but perhaps not the most useful explanation, though there is some truth to that statement that we might get into later.

What precisely is recursion, and why should we choose to care about it versus other methods in Ruby? Well in a lot of cases you're probably right, but there are a few cases where it'll come in real handy, and we'll be taking a look at both.

## Fundamental Recursion

To start with, let's define recursion as a method (or function) which calls itself. This definition approaches it from the top down, but if we put it in reverse we find a potentially more useful definition to start with:

Recursive problems are ones which can be broken down into easier solvable problems, which then in turn can be used to solve more complicated ones.

### Iterative Factorial

The classic example for this is factorial, which is the product of all numbers before `n`, such that `5!` (read as "5 factorial") is equal to `5 * 4 * 3 * 2 * 1`.

In more traditional Ruby you would probably do something like this:

```ruby
def factorial(n)
  product = 1
  
  (1..n).each { |v| product *= v }
  
  product
end
```

We won't get into `reduce` too much here except to mention that most folks would probably write that function like this instead:

```ruby
def factorial(n) = (1..n).reduce(1, :*)
```

...and I'll post more links to `reduce` later in the footer, but I will give you a hint in saying `reduce` is _very_ similar to recursion.

> **Note:** In tutorials I will very much seek to be verbose rather than concise, making a code example concise is left as an exercise to the reader.

Going back to that first example though we have a few distinct steps that we should remember:

1. We have a base number, `1`, which we can use to "accumulate" results onto
2. We iterate every number from 1 to `n`
3. With each of those numbers we multiply the current product by that value, and save it
4. Then we return the end product

### Recursive Factorial

If we were to take a look at a recursive version of factorial, it would look more like this:

```ruby
def factorial(n)
  return 1 if n <= 1
  
  n * factorial(n - 1)
end
```

...which very interestingly has some of the same properties as above. We still have the base number of `1` which we accumulate onto as our "base" case, because `factorial(1)` is `1` and we know the solution to that smaller problem.

What we don't know, however, is what `factorial(5)` might be. Since we don't have that answer we ask another question: What's the factorial of `4`? We know that `factorial(5)` is equal to `5 * factorial(4)`, but to answer that we also need to know the factorial of `4`.

This repeats until we go all the way down to `1` and we go right back up the chain. If we were to take a look at each step we would get something like this happening behind the scenes:

```ruby
factorial(5)
5 * factorial(4)
5 * 4 * factorial(3)
5 * 4 * 3 * factorial(2)
5 * 4 * 3 * 2 * factorial(1) # Base case, we know this one!
5 * 4 * 3 * (2 * 1) # So replace `factorial(1)` with `1` and back up we go.
5 * 4 * (3 * 2)
5 * (4 * 6)
5 * 24
120 # Final return value
```

### A Different Point of View

Of course as mentioned before you're much more likely to use `reduce` in your actual Ruby code, but this does present a very interesting new way of viewing this problem. Is one necessarily superior to the other? Yes and no, depending on the circumstance of the recursive problem in question, but the value in recognizing these patterns is _having that option because you know about it_.

There are numerous different ways to approach any problem, and sometimes a different point of view provides a new and novel insight that allows you to solve otherwise difficult and blocking problems.

That being said, let's continue into building our intuition on the ways recursion might be used to solve other problems.

## An Alternative to Iteration

In Ruby when you want to go through a list of items you're going to use `each`:

```ruby
[1, 2, 3].each do |v|
  puts v * 2
end
# STDOUT: 2
# STDOUT: 4
# STDOUT: 6
# => [1, 2, 3]
```

We could also iterate a list recursively, which brings us an interesting pattern of `head` and `tail` (or `car` and `cdr` if you're LISP-inclined):

```ruby
def each(list, &function)
  return if list.empty?
  
  head, *tail = list
  function.call(head)
  
  each(tail, &function)
  
  list # To emulate `each` which returns the original list
end

each([1, 2, 3]) { |v| puts v * 2 }
# STDOUT: 2
# STDOUT: 4
# STDOUT: 6
# => [1, 2, 3]
```

Looking at our above recursive example we can see some familiar elements in this method:

1. A base case (`return if list.empty?`)
2. Finding a question we can answer (`function.call(head)`)
3. Continuing with the rest of the items (`each(tail, &function)`)

What's different is the order shifted and our base case is now no longer the question we know an answer to. With `each` in Ruby we use a block function on every element of a list, and with this implementation we pull the first item off of the list, run the `function` on it, and continue to dive into the rest of the list.

To take a look at what it's doing behind the scenes, let's go to this example:

```ruby
each([1, 2, 3]) { |v| puts v * 2 } # head: 1, tail: [2, 3], STDOUT: 2
each([2, 3]) { |v| puts v * 2 }    # head: 2, tail: [3], STDOUT: 4
each([3]) { |v| puts v * 2 }       # head: 3, tail: [], STDOUT: 6
each([]) { |v| puts v * 2 }        # head: nil, tail: [], hits `return`
```

Each line is a subsequent call to `each` with the `tail`, and you can trace those values as they go through. Sometimes I even cheat and make my methods look like this while testing, which you might enjoy experimenting with:

```ruby
def each(list, &function)
  return if list.empty?
  
  head, *tail = list
  puts(head: head, tail: tail) # Debugging at its' finest
  function.call(head)
  
  each(tail, &function)
  
  list # To emulate `each` which returns the original list
end

# STDOUT: {:head=>1, :tail=>[2, 3]}
# STDOUT: 2
# STDOUT: {:head=>2, :tail=>[3]}
# STDOUT: 4
# STDOUT: {:head=>3, :tail=>[]}
# STDOUT: 6
# => [1, 2, 3]
```

Personally I really like using keywords here because simply logging out the `head` and `tail` leaves me to remember what exactly I was outputting and where, and I do not have a very exceptional memory. Oh, side lesson, Ruby 3.1 lets you do this instead:

```ruby
puts(head:, tail:) # Same thing with "punning"
```

You can read on that more in [Ruby 3.1 - Shorthand Hash Syntax - First Impressions](/writing/2021/09/12/ruby-3-1-shorthand-hash-syntax-first-impressions-19op/), but know that I really love that feature for things like this. Anyways, back to the article.

For `each` this isn't particularly exciting, but we could do this for pretty much _any_ Enumerable method.

### Mapping

For a more interesting example we can take a look at `Enumerable#map` which transforms every element of a list using a block function:

```ruby
[1, 2, 3].map { |v| v * 2 }
# => [2, 4, 6]
```

Before I dive into an implementation how about you give it a shot? Can you come up with an implementation for the `map` method based on the above `each` method? Take a minute, this article will still be here, but you might find some very interesting things out in experimenting.

If we were to make a `map` method in a similar way to the above `each` it would look very similar indeed:

```ruby
def map(list, &function)
  return [] if list.empty?
  
  head, *tail = list
  [function.call(head), *map(tail, &function)]
end

map([1, 2, 3]) { |v| v * 2 }
# => [2, 4, 6]
```

In this case the question we know how to answer is what happens to each element that is "mapped" to another element, or in the case of this code `function.call(head)`. We can answer that one immediately, but then we have to continue through the rest of the list to figure out how those values map over.

Notice the splat (`*`) though on the next call to `map`. That's because each step of this recursion will return an `Array`, and at the end an empty one. Nifty, but seeing is believing, shall we go back to our tricks?:

```ruby
def map(list, &function)
  return [] if list.empty?
  
  head, *tail = list
  new_value = function.call(head)
  
  puts(head:, tail:, new_value:)
  
  [new_value, *map(tail, &function)].tap { puts(current_list: _1) }
end

map([1, 2, 3]) { |v| v * 2 }
# STDOUT: {:head=>1, :tail=>[2, 3], :new_value=>2}
# STDOUT: {:head=>2, :tail=>[3], :new_value=>4}
# STDOUT: {:head=>3, :tail=>[], :new_value=>6}
# STDOUT: {:current_list=>[6]} # Bottom of recursion, start collecting values!
# STDOUT: {:current_list=>[4, 6]}
# STDOUT: {:current_list=>[2, 4, 6]} # Back at the top, return it
# => [2, 4, 6]
```

I cannot recommend doing this highly enough while building intuition on how data flows through your methods as it really helps ground you to what's happening inside of it. I'd also really really recommend starting with simple examples rather than running this on something huge from the get-go, it's much easier to debug.

You might notice I also used `tap` on the end of the returned list. `tap` lets you access the value, but returns it as-is, which is great for debugging. You might also notice `_`1 which is a [numbered parameter](/writing/2019/03/18/ruby-2-7-numbered-parameters-1a79/).

Now if you want something to experiment with I would try and reimplement `select` and `reject` and see if you can figure out how to use the `function` in these cases. Bonus points if you figure out how to implement `filter_map` because there are some _real interesting_ implications there of combining these functions.

That said, we'll keep this one higher level, and look at something a bit different.

### Reversing

This one doesn't use a function at all, it only reverses a list:

```ruby
[1, 2, 3].reverse
# => [3, 2, 1]
```

Now you know how this goes, and I'm one of _those_ writers, so before you keep reading give this a try yourself and see what you come up with. Most of the fun really is in trying things yourself and getting into the code, so take those chances to explore.

Back to it, if we were to implement a `reverse` function recursively it might look a bit like this:

```ruby
def reverse(list)
  return [] if list.empty?
  
  head, *tail = list
  [*reverse(tail), head]
end

reverse([1, 2, 3])
# => [3, 2, 1]
```

There are no particular rules around what you need to return from a recursion, or what order it needs to be in. Really though, if order is your game you might enjoy reimplementing `sort` while you're at it. Point being the idea of `reverse` is that we continuously put the head before the tail until we run out of items.

If we were to tap into this we might see something like this:

```ruby
def reverse(list)
  return [] if list.empty?
  
  head, *tail = list
  puts(head:, tail:)
  [*reverse(tail), head].tap { puts(current_list: _1) }
end

reverse([1, 2, 3])
# STDOUT: {:head=>1, :tail=>[2, 3]}
# STDOUT: {:head=>2, :tail=>[3]}
# STDOUT: {:head=>3, :tail=>[]}
# STDOUT: {:current_list=>[3]}
# STDOUT: {:current_list=>[3, 2]}
# STDOUT: {:current_list=>[3, 2, 1]}
# => [3, 2, 1]
```

You might notice that recursive methods have a very distinct "<" shape. That's because we keep digging down until we run out of questions and hit our "base" case, then come back up with what we found out. If you go too deep though you'll quickly find out what [SystemStackError](https://ruby-doc.org/core-3.1.2/SystemStackError.html) is, which is very common when you get a base case wrong and you recurse out into the sunset.

But seriously though? Try out `sort`, bonus points if you can work `<=>` (rocket ship operator) into it too.

## Going Deep

Now that's all well and good, but when would we hit something which was legitimately hard to do with iteration? Whenever we're not quite sure the shape of something, but we know how to ask questions to find what's next.

Consider with me this JSON:

```ruby
require "json"

# Using https://json-generator.com/
data = JSON.parse <<~RAW
  [{
    "name": "Mercedes Chandler",
    "gender": "female",
    "age": 33,
    "eyeColor": "blue",
    "tags": ["in", "exercitation", "ad"],
    "friends": [
      { "id": 0, "name": "Latasha Kent" },
      { "id": 1, "name": "Douglas Craig" },
      { "id": 2, "name": "Parsons Davenport" }
    ]
  }, {
    "name": "Conrad Maxwell",
    "gender": "male",
    "age": 30,
    "eyeColor": "green",
    "tags": ["proident", "non", "proident"],
    "friends": [
      { "id": 0, "name": "Dena Vasquez" },
      { "id": 1, "name": "Sherrie Marsh" },
      { "id": 2, "name": "Christina Petty" }
    ]
  }, {
    "name": "Ellen Cote",
    "gender": "female",
    "age": 27,
    "eyeColor": "brown",
    "tags": ["laboris", "ullamco", "nulla"],
    "friends": [
      { "id": 0, "name": "Brady Wolf" },
      { "id": 1, "name": "Tisha Duffy" },
      { "id": 2, "name": "Gibbs Payne" }
    ]
  }]
RAW
```

It's easy enough to iterate each JSON object, or Ruby hash, inside of that array sure. What if I told you I wanted to get all the values?

Not just first level, no no, _all_ the values, including inside of the arrays for tags and sub-objects in friends too! All of the sudden that's a really hard problem to do iteratively, but recursively? This is where it really shines.

Now if you really want to know something trippy this entire thing can be done in five lines of code:

```ruby
def all_values(collection)
  return collection.values.flat_map { |v| all_values(v) } if collection.is_a?(Hash)
  return collection.flat_map { |v| all_values(v) } if collection.is_a?(Array)
  
  collection
end

all_values(data)
#  =>
# ["Mercedes Chandler",
#  "female",
#  33,
#  "blue",
#  "in",
#  "exercitation",
#  "ad",
#  0,
#  "Latasha Kent",
#  1,
#  "Douglas Craig",
#  2,
#  "Parsons Davenport",
# ...
```

More if you're behaving and using a `case` statement, sure, but it makes a fun point no?

You might notice that this _combines_ iteration for what it's best at and recursion for what it's best at. Nothing says they can't be used together, and in fact it's frequently much easier to approach problems like this. Take the best from each domain, whether functional, object oriented, imperative, or whatever.

You'll also notice we're using `flat_map` instead of `map` here. For fun I suggest you change that to `map` and see what you find out about nested data structures.

Now this is really powerful, but we can take it further. So much further.

### The Select Cases

What if we wanted `select`, except _any_ value that matched at _any_ depth? That type of problem is fiendishly hard and requires a firm grasp on the structure of the data and all of its facets, which makes this a...

```ruby
def deep_select(collection, &function)
  case collection
  when Hash
    collection.values.flat_map { |v| deep_select(v, &function) }
  when Array
    collection.flat_map { |v| deep_select(v, &function) }
  else
    function.call(collection) ? [collection] : []
  end
end

deep_select(data) { |v| v.to_s.match?(/^L/i) }
# => ["Latasha Kent", "laboris"]
deep_select(data) { |v| v.is_a?(Integer) }
# => [33, 0, 1, 2, 30, 0, 1, 2, 27, 0, 1, 2]
```

...strangely easy problem when solving recursively.

The base case is at the bottom. We don't know how to answer whether or not an array or hash matches, but we _can_ answer if a value does so we break the problem down into values. At the end we use the function to decide whether to return the value, or an empty array which will be squashed in the `flat_map`.

Why an empty array? Why `1` with multiplication? `0` with addition? If you noticed that pattern then extra bonus points to you, you're about to go on a [wild trip into parallelism patterns](/writing/2021/01/08/introducing-patterns-in-parallelism-for-ruby-2f4a/).

Some other interesting directions you can take this are [looking into lenses](/writing/2018/04/24/on-dealing-with-deep-hashes-in-ruby-xf-part-one-scopes/), reading into [query languages like jq](https://github.com/winebarrel/ruby-jq), or going into [pattern matching for Ruby](/writing/2019/04/17/ruby-2-7-pattern-matching-first-impressions-13j9/). The beauty of all of this is how many directions you can go from here.

## Wrapping Up

Now this is a very brief and high level introduction to recursion, and some concepts of functional programming. There's a lot more out there to explore, and if you want practice see how many Enumerable methods you can write recursively, and how many more of them you can write to work on arbitrarily deep data structures.

As with all parts of the language it has its uses, but most of the time you really probably want to use Enumerable methods instead. Knowing the difference is when things get interesting, and having that extra tool in your box can make a world of difference.
