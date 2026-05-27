---
layout: "post"
title: "Of a Higher Order - Map, Filter, Reduce"
date: "2019-08-19"
categories: ["javascript", "functional"]
tags: ["javascript", "functional"]
description: "So you've seen map, filter, reduce, and other functions, but how do they work behind the scenes? Let's take a look"
---

Knowing of `map`, `filter`, and `reduce` is of great value in Javascript. Knowing how they're made? Well that brings a whole new category of value.

![Marigold, the Javascript lemur](/images/posts/2019-08-19-of-a-higher-order-map-filter-reduce-49f6/img-122e349b.png)

Before we get into that though, we're going to need to pick up a few techniques from Functional Programming.

# The Toolkit

Most concepts in programming build upon others, and this is no exception. Functional Programming is the art of building concepts upon each other to express other concepts, so it makes sense that to learn how to make such things involves learning those base concepts.

You'll find that these tools come in a lot of handy later as well.

## Recursion

Recursion is a cornerstone of most functional thinking, the ability to break a larger problem into smaller ones we know how to solve.

A classic example would be Factorial, a number followed by an exclamation mark ( `5!` ) that's used as a shorthand to say "the product of all numbers from this number down to one", or:

```js
5 * 4 * 3 * 2 * 1
```

Here's the trick: `5!` could be written as the above, or could also be written as `5 * 4!`. It would follow that `4!` could be expressed `4 * 3!` and so on.

More generally speaking, we could say that `n!` is equivalent to `n * (n - 1)!` until we hit `1!`, which is `1`. Since we don't have the answer to what `n!` is, we can keep asking until we hit `1` where we _know_ what the answer is. This is called a base case, a known value.

A function that could do this may be written as:

```js
function factorial(n) {
  if (n < 2) return n;

  return n * factorial(n - 1);
}
```

We won't guard negative numbers for now, we just need to see that this function will keep on asking for the next number in the sequence until it hits `1`.

Taking a look back at out original multiplication this would mean:

```js
5 * (4 * (3 * (2 * (1))))
```

...with each of those parens indicating another call down the stack until it hits `1` and now we know what we need to multiply out.

Now recursion can be used for other things than math problems. It can also be used to iterate lists. 

## Destructuring

Before we get into recursive iteration, we need to take a glance at destructuring, but just a bit.

What we'll need for this is to be able to get the first item of a list, and the rest of the items as separate values. In Javascript that'd look something like this:

```js
const [head, ...tail] = [1, 2, 3, 4, 5];

// head: 1
// tail: [2, 3, 4, 5]
```

`...` allows us to scoop up the remaining items of the list, and leaves us with the first item separate from it. This will be important here in a second.

## Recursive Iteration

Let's start with our own `forEach` like function that we'll call `each`:

```js
function each(list, fn) {
  const [head, ...tail] = list;

  fn(head);

  if (!tail.length) return;

  each(tail, fn);
}
```

We use destructuring to pick the first item off of the list, and store the rest in the `tail`. After that we call the given function argument with the value of `head`.

If there are no more items, we're done, so `return` out. If there _are_ more items we want to recurse with the `tail` as the new list, passing along that same function.

It can be called by passing a list and a function to `each`:

```js
each([1, 2, 3], console.log);
// 1
// 2
// 3
```

Knowing how `forEach` works, we can build any of the other functions either on-top of it or through recursion directly. This gives us enough tools to make those three functions above, so let's get to it.

# The Functions Three

We have our tools ready, so it's time to look into implementing these higher order functions. What's higher order? A function that takes another function as an argument, and with `each` we've already made one, so the rest aren't that bad.

What's even better is that each of these introduce a new concept that let us build even more fun things in the future!

## Map - Use a Function to Transform a List

`map` is a higher order function used to transform a list, returning a new list:

```js
[1, 2, 3].map(x => x * 2);
// => [2, 4, 6]
```

If we were to implement it using the techniques above, it would look something like this:

```js
function map(list, fn) {
  if (!list.length) return [];

  const [head, ...tail] = list;

  return [fn(head), ...map(tail, fn)];
}
```

We start by defining a base case, when the list is empty we just return back an empty list. If that's not the case, we want to seperate the `head` from the `tail` of the list.

Once we have that, we can return a new array with the function `fn` called with the `head` value, and then we can flatten out the result of calling `map` on the `tail` with the same function.

The function we passed in is used as a way to transform each element in a list, its return value being the new value in the new list that `map` will return.

Giving it a try, we can see it does much the same thing as the native implementation:

```js
map([1, 2, 3], x => x * 2);
// => [ 2, 4, 6 ]
```

## Filter - Use a Function to Filter Down a List

`filter` is a higher order function that's used to filter down a list into a new list with elements matching a condition:

```js
[1, 2, 3].filter(x => x % 2 === 0);
// => [2]
```

The implementation, amusingly, is very similar to map:

```js
function filter(list, fn) {
  if (!list.length) return [];

  const [head, ...tail] = list;

  return fn(head) ? [head, ...filter(tail, fn)] : filter(tail, fn);
}
```

The only difference is that we're using the function to decide whether or not a certain item in the list should be in the new list. If it returns a truthy value, we add it and keep going, if not we just filter the rest of the list down and ignore it.

This type of function is sometimes called a predicate.

Giving this a try, we'll find that it works much the same as its native counterpart:

```js
filter([1, 2, 3], x => x % 2 === 0);
// => [2]
```

## Reduce - Use a Function to Reduce a List into One Item

Now `reduce`, `reduce` is all types of fun and a bit difficult to understand. It's also the most powerful of the three by a landslide for reasons we'll get into in a second.

Let's start by explaining what it actually does, because it can be a bit of a task:

```js
[1, 2, 3].reduce(function (accumulator, v) {
  console.log({ accumulator, v });
  return accumulator + v;
}, 0);
// { accumulator: 0, v: 1 }
// { accumulator: 1, v: 2 }
// { accumulator: 3, v: 3 }
// => 6
```

> `console.log({ a, b })` is one of my favorite debugging tricks, using "punning" to give a name to debugged values to see how data flows.

Reduce starts with an initial accumulator value (`0`) which is often times an "empty" element. For adding numbers, `0` is considered "empty" because you can add anything to it and get back the same number.

For each step of that reduction the return value becomes the next accumulator. In the first step we have the first value of the list added to that initial accumulator, which gives us back `1`, which is the new accumulator, and so forth.

Once it runs out of values it returns the accumulator as the new value.

So what would a recursive implementation look like? Let's take a look:

```js
function reduce(list, fn, accumulator) {
  if (!list.length) return accumulator;

  const [head, ...tail] = list;
  return reduce(tail, fn, fn(head, accumulator));
}
```

...that's it? The only real differences here between this and the `map` and `filter` functions is that the base case returns this new `accumulator`, and the recursion makes a new `accumulator` by running the function with the `head` of the list and the current `accumulator`.

If we were to call it we'd get back the same result:

```js
reduce([1, 2, 3], (a, v) => a + v, 0);
// => 6
```

Let's throw some console logs in there just to be sure though, because that still looks tricky:

```js
function reduce(list, fn, accumulator) {
  if (!list.length) {
    console.log({ accumulator });
    return accumulator;
  }

  const [head, ...tail] = list;

  console.log({
    head, tail, accumulator, newAccumulator: fn(head, accumulator)
  });

  return reduce(tail, fn, fn(head, accumulator));
}
```

...and run it one more time:

```js
reduce([1, 2, 3], (a, v) => a + v, 0);
// { head: 1, tail: [ 2, 3 ], accumulator: 0, newAccumulator: 1 }
// { head: 2, tail: [ 3 ], accumulator: 1, newAccumulator: 3 }
// { head: 3, tail: [], accumulator: 3, newAccumulator: 6 }
// { accumulator: 6 }
// => 6
```

So very similar indeed.

## Reduce the Mighty

Now what was that about it being the most powerful? Well the trick to reduce is that it works on structures which follow three rules:

1. It has an empty element (like `0`)
2. It has a way to combine elements into something of the same type (`Int + Int === Int`)
3. When the elements are combined, they can be grouped as long as they retain that same order (`a + b + c === a + (b + c)`)

So for Integers that could be `+` and `0`. It could also be `*` and `1`.

Here's the mind-blowing part: a lot more classes act like this:

* Strings with `+` and `""`
* Arrays with `concat` and `[]`
* Objects with `Object.assign` and `{}`
* ...and a whole lot more.

That means that we could technically implement any of those above functions, including `forEach`, with `reduce`.

It also means we've discovered an interesting property.

## The Power of a Name

Those rules from above? They have names:

1. Identity / Empty - An element that, when combined with another, results in that element
2. Closure / Combine - An operation which can combine two elements of one type into another of the same type
3. Associativity / Grouping - Free grouping as long as elements retain their order

Those rules, when combined and applied to something, also have a name: [Monoid](https://en.wikipedia.org/wiki/Monoid).

It's a fancy way of saying "In the manner of one" or "like one thing", or something reducible. There's a lot more there, granted, but it's a fun little discovery.

# Wrapping Up

Functional Programming is built piece by piece, and as it happens some patterns emerge out of it sometimes. You've just learned a few of those patterns, ones that will be very useful in programming in much of any language. Thinking a bit differently yields all types of exciting possibilities, and perhaps an endless Wikipedia dive or two in the process.

In the future I may translate my talk from RubyConf, ["Reducing Enumerable - An Illustrated Adventure"](https://www.youtube.com/watch?v=x3b9KlzjJNM) into Javascript and even post a Storybook Edition on here like some of my other talks. Who knows, perhaps you may see the lemurs show up at a Javascript event or two in the future.
