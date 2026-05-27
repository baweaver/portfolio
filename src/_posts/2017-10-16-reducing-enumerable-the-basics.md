---
layout: "post"
title: "Reducing Enumerable — The Basics"
series: "reducing-enumerable"
date: "2017-10-16"
categories: []
tags: []
description: ""
---

One of the lesser understood functions in Enumerable for many Rubyists is reduce . It’s just the thing we can use to get sums right? Well, sum does that in Ruby 2.4.x and above. Does that make it useless now?

The secret of reduce is that *every other Enumerable function can be implemented in terms of reduce. *Yes, every last one of them.

Before we get into that though, let’s take a look at a few other higher order functions in Ruby and what they do.

## Map

Let’s start off with map . Map is used to apply a function to an Enumerable collection. In more common terms, every item goes through the function individually and you get a new Array at the end:

    [1,2,3].map { |i| i * 2 }
    # => [2,4,6]

Now an important thing to keep in mind is that map does not mutate the original array, it returns a new one.

## Select

Select is like map, except it uses the function as a predicate. If it happens to be true, we keep the element for the new list, otherwise get rid of it:

    [1,2,3].select { |i| i > 1 }
    # => [2, 3]

## Reduce

So before we get too far into it, we need to cover the base case for reduce . What does it do and how does it do it? We’ll start with a basic sum:

    [1,2,3].reduce(0) { |accumulator, i| accumulator + i }
    # => 6

For a first time reader, that’s dense. Let’s break it down:

    [1,2,3].reduce(0)

We’re reducing our list with an initial value of 0 .

    { |accumulator, i| accumulator + i }

and we’re passing it a block which takes an accumulator, and i . The first value of the accumulator is either our initial value (0) or the first element of our list.

For every cycle of reduce, accumulator is set to the return value of the last cycle. For our current list, that might look like this:

     a | i | reducer
    ---+---+-----------
     0 | **1** | 0 + **1 **: 1
     1 | **2** | 1 + **2 **: 3
     3 | **3** | 3 + **3 **: 6
     6 | - |     -
    ---+---+-----------

    **Returns: 6**

As soon as it gets to the end of the list, it gives us back our accumulator. A name that may help understand what reduce is doing is a name it has in other languages: foldLeft . Basically we’re folding our list to the left with a + , giving us something that looks like this:

    ((((0) + 1) + 2) + 3)

Now we can get rid of the parens, but for the sake of delineation of the new value of accumulator we’ll leave them there for now.

For amusements sakes though, one could certainly compare this to LISP as well:

    (+ (+ (+ (0) 1) 2) 3)

## Map with Reduce

Now given that information, how would we implement it in terms of reduce?

Well there’s one big secret to reduce: *It doesn’t care what that initial value’s type is.*

What if you passed it something like an empty array instead? It’d keep on going! A value is a value, and reduce takes a value.

    def map(list, &fn)
      list.reduce([]) { |a, i| a.push(fn[i]) }
    end

    map([1,2,3]) { |i| i * 2 }
    # => [2, 4, 6]

Remember how we said that map was just applying a function to a list and returning a new list? With this reduce we’re just pushing the result of calling the function onto our new list, and returning the accumulator at the end. That accumulator happens to be the new list.

Let’s look at how this works step by step like with reduce above:

        a   | i | fn[i]     | reduction         
    --------+---+-----------+---------------
     []     | 1 | 1 * 2 : **2** | [].push(**2**)    
     [2]    | 2 | 2 * 2 : **4** | [2].push(**4**)   
     [2,4]  | 3 | 3 * 2 : **6** | [2,4].push(**6**) 
     [2,4,6]| - |     -     |       -          
    --------+---+-----------+----------------

    **Returns: [2, 4, 6]**

## Select with Reduce

Given that, select becomes pretty easy to do as well:

    def select(list, &fn)
      list.reduce([]) { |a, i| fn[i] ? a.push(i) : a }
    end

    select([1,2,3]) { |i| i > 1 }
    # => [2, 3]

All we need to do is check if the function is true for i and either push it to the list or just return the list without it for the next cycle.

Let’s take a look at that step by step:

        a  | i | fn[i]         | reduction                 
    -------+---+---------------+---------------------------
     []    | 1 | 1 > 1 : **false** | **false** ? [].push(i)  : []  
     []    | 2 | 2 > 1 : **true**  | **true**  ? [].push(i)  : []  
     [2]   | 3 | 3 > 1 : **true**  | **true**  ? [2].push(i) : [2] 
     [2,3] | - |       -       |             -             
    -------+---+---------------+---------------------------

    **Returns: [2, 3]**

## Find with Reduce

But that doesn’t quite account for the fact that methods like find will break early if they find what they’re looking for. It seems rather silly to keep going, doesn’t it? Well then let’s just give it a break:

    def find(list, &fn)
      list.reduce(nil) { |_, i| break i if fn[i] }
    end

    find([1,2,3]) { |i| i == 2 }
    # => 2

    find([1,2,3]) { |i| i == 4 }
    # => nil

In this case we’re reducing into nil because we don’t really care about the accumulated value, we just want nil if nothing is found. If we wanted to fully emulate Ruby’s find method we’d have to pass another function to it, but that’s a matter for later.

So what’s with the break ? Well we’re just telling reduce to break out of its loop. The nifty thing about break is that it will return a value as well, allowing us to break out early with a given value if we want to.

      a  | i | fn[i]          | reduction        
    -----+---+----------------+------------------
     nil | 1 | 1 == 2 : **false** | break i if **false** 
     nil | 2 | 2 == 2 : **true**  | break i if **true**  
    -----+---+----------------+------------------

    **Break: 2**

      a  | i | fn[i]          | reduction        
    -----+---+----------------+------------------
     nil | 1 | 1 == 4 : **false** | break i if **false** 
     nil | 2 | 2 == 4 : **false** | break i if **false** 
     nil | 3 | 3 == 4 : **false** | break i if **false** 
     nil | - |        -       |         -        
    -----+---+----------------+------------------

    **Returns: nil**

## Combining Functions

One thing you might have wanted to do is to combine those functions. What if we could do something like map_compact or map_select or any other number of functions?

Well we have access to the reducer’s function, meaning we have leverage over all of Ruby to make that decision.
> If you’ve done some functional programming before and you’re whispering composition to yourself, we’ll get to that later.

Let’s look at how to do a map_compact :

    def map_compact(list, &fn)
      list.reduce([]) { |a, i|
        value = fn[i]
        value.nil? ? a : a.push(value)
      }
    end

    map_compact([1,2,3]) { |i| i > 1 ? i * 2 : nil }
    # => [4, 6]

Does that look slightly familiar to select ?

        a  | i | fn[i]               | reduction                     
    -------+---+---------------------+-------------------------------
     []    | 1 | 1 > 1 : **nil**         | **nil**.nil? ? []  : [].push(1)   
     []    | 2 | 2 > 1 : 2 * 2 : **4**   | **4**.nil?   ? []  : [].push(**4**)   
     [4]   | 3 | 3 > 1 : 3 * 2 : **6**   | **6**.nil?   ? [4] : [4].push(**6**)  
     [4,6] | - |          -          |               -                 
    -------+---+---------------------+-------------------------------

    **Returns: [4, 6]**

We’ve just, in effect, combined the reducing properties of two functions. Now what if we did something fun and abstracted that behavior out?

We’d end up with something particularly fun called a Transducer:
[**Understanding Transducers in JavaScript**
*I’ve found a very good article explaining Transducers. If you are familiar with Clojure, go and read it: “Understanding…*medium.com](https://medium.com/@roman01la/understanding-transducers-in-javascript-3500d3bd9624)

That’s beyond the scope of this first post though, so that’ll be a topic for later.

What we’re getting close to is how to deal with something versus how to deal with nothing. When you combine functions, how do you define what constitutes nothing? Maybe it’s an empty list or 0 instead of nil or false, who knows.

## Wrapping Up

This is the first of a few different posts. The next one in line covers Boolean and No-Op functions:
[**Reducing Enumerable — No-Op and Boolean**
*Recap*medium.com](/writing/2017/10/16/reducing-enumerable-no-op-and-boolean/)

## Caveat

Composition and other such topics will be covered in later posts. For those who know what I’m up to or have a pretty good guess, to quote the wise words of Dr. River Song:
> Spoilers
