---
layout: "post"
title: "Understanding Transducers in Ruby"
date: "2018-09-10"
categories: []
tags: ["ruby", "functional"]
description: "An introduction to transducers in Ruby — composable algorithmic transformations decoupled from their input sources."
---

Understanding Transducers in Ruby
      * {
```ruby
    font-family: Georgia, Cambria, "Times New Roman", Times, serif;
  }
  html, body {
    margin: 0;
    padding: 0;
  }
  h1 {
    font-size: 50px;
    margin-bottom: 17px;
    color: #333;
  }
  h2 {
    font-size: 24px;
    line-height: 1.6;
    margin: 30px 0 0 0;
    margin-bottom: 18px;
    margin-top: 33px;
    color: #333;
  }
  h3 {
    font-size: 30px;
    margin: 10px 0 20px 0;
    color: #333;
  }
  header {
    width: 640px;
    margin: auto;
  }
  section {
    width: 640px;
    margin: auto;
  }
  section p {
    margin-bottom: 27px;
    font-size: 20px;
    line-height: 1.6;
    color: #333;
  }
  section img {
    max-width: 640px;
  }
  footer {
    padding: 0 20px;
    margin: 50px 0;
    text-align: center;
    font-size: 12px;
  }
  .aspectRatioPlaceholder {
    max-width: auto !important;
    max-height: auto !important;
  }
  .aspectRatioPlaceholder-fill {
    padding-bottom: 0 !important;
  }
  header,
  section[data-field=subtitle],
  section[data-field=description] {
    display: none;
  }
  
```

# Understanding Transducers in Ruby

This article is a translation of the article “Understanding Transducers in Javascript”, with permission granted by the original author…

### Understanding Transducers in Ruby

This article is a translation of the article “Understanding Transducers in Javascript”, with permission granted by the original author, [@roman01la](http://twitter.com/roman01la):

[Understanding Transducers in JavaScriptI’ve found a very good article explaining Transducers. If you are familiar with Clojure, go and read it: “Understanding…medium.com](https://medium.com/@roman01la/understanding-transducers-in-javascript-3500d3bd9624)[](https://medium.com/@roman01la/understanding-transducers-in-javascript-3500d3bd9624)Content below here is a translation of the above article, with some asides added using quote blocks such as this:

> Extra information that is not a direct translationWe’ll be using the Ruby variant of Rambda to get composition and other FP tricks required by this article:

[lazebny/ramda-rubyRuby port of http://ramdajs.com. Contribute to lazebny/ramda-ruby development by creating an account on GitHub.github.com](https://github.com/lazebny/ramda-ruby)[](https://github.com/lazebny/ramda-ruby)If you have not read my article on using Reduce in Ruby and how it works, I would suggest reading it as this article can be a bit hard to follow without that base knowledge:

[Reducing Enumerable — The BasicsOne of the lesser understood functions in Enumerable for many Rubyists is reduce . It’s just the thing we can use to…medium.com](/writing/2017/10/16/reducing-enumerable-the-basics/)[](/writing/2017/10/16/reducing-enumerable-the-basics/)If you aren’t familiar with closures and lambdas in Ruby, I would suggest reading up on them first as well:

[Functional Programming in Ruby — ClosuresOne of the most powerful features of Functional Programming that we can leverage in Ruby is the concept of a Closure.medium.com](/writing/2018/05/13/functional-programming-in-ruby-closures/)[](/writing/2018/05/13/functional-programming-in-ruby-closures/)Shall we get started?

I’ve found a very good article explaining Transducers. If you are familiar with Clojure, go and read it: [“Understanding Transducers”](http://elbenshira.com/blog/understanding-transducers/). But if you are Ruby developer and not used to read lisp code, I’ve translated code examples from that articles into Ruby. So you can still read the article and check code examples here.

#### What are Transducers?

A quick noob intro: transducers are composable and efficient data transformation functions which doesn’t create intermediate collections.

Here’s a visualisation to show the difference between array built-ins and transducers.

chained built-in transformations create intermediate arraystransduced transformations process items one by one into output array#### Why use them?

The above visualisation means that given transformations like map, select and reduce we want to compose them together to pipe every piece of data through them step by step. But the following is not this kind of composition:

array  .map(&fn1)  .select(&fn2)  .reduce(&fn3)Instead we want something like this:

transformation = compose(map(&fn1), select(&fn2), reduce(&fn3));transformation(array)This way we can reuse the transformation and compose it with others. But the problem is that map, select and reduce functions have different signatures. This is why all of them need to be generalised and it can be done in terms of reduce.

> Note that I’ll be using select instead of filter throughout this article, as filter is only present in 2.6+ as an alias of select.#### Code examples from the article

map and select, and how they can be combined together:

[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map { |x| x + 1 }# => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10][1, 2, 3, 4, 5, 6, 7, 8, 9, 10].select { |x| x.even? }# => [2, 4, 6, 8, 10][0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .map    { |x| x + 1   }  .select { |x| x.even? }# => [2, 4, 6, 8, 10]> While we could use the&:even?shorthand here instead, we’ll tend more verbose to make it easier to read for newer Rubyists.map and select can be implemented using reduce. Here’s map implementation:

map_inc_reducer = -> result, input {  result.push(input + 1)}[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce([], &map_inc_reducer)# => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]Let’s extract incrementing function to allow it to be passed into reducer:

def map_reducer(&fn)  -> result, input {    result.push(fn.call(input))  }end[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &map_reducer { |x| x + 1 })# => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]More usage examples of map reducer:

[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &map_reducer { |x| x - 1 })# => [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8][0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &map_reducer { |x| x * x })# => [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]select implementation using reduce:

select_even_reducer = -> result, input {  result.push(input) if input.even?  result};[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].reduce([], &select_even_reducer)# => [2, 4, 6, 8, 10]Again, extract predicate function, so it can be passed from the outside:

def select_reducer(&predicate_fn)  -> result, input {    result.push(input) if predicate_fn.call(input)    result  }end[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  .reduce([] &select_reducer { |x| x.even? })# => [2, 4, 6, 8, 10]Combine both reducers together:

[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &map_reducer    { |x| x + 1   })  .reduce([], &select_reducer { |x| x.even? })# => [2, 4, 6, 8, 10]Similar to what you usually do with built-in array methods:

[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .map    { |x| x + 1   }  .select { |x| x.even? }# => [2, 4, 6, 8, 10]Here are both reducers again and both of them are using array push as a reducing function:

def map_reducer(&fn)  -> result, input {    result.push(fn.call(input))  }enddef select_reducer(&predicate_fn)  -> result, input {    result.push(input) if predicate_fn.call(input)    result  }endpush and + are both reducing functions, they take initial value and input, and reduce them to a single output value:

array = [1, 2, 3]array.push(4)# => [1, 2, 3, 4]10 + 1# => 11Let’s extract reducing function, so it can be also passed from the outside:

def mapping(&fn)  -> &reducing_fn {    -> result, input {      reducing_fn.call(result, fn.call(input))    }  }enddef selecting(&predicate_fn)  -> &reducing_fn {    -> result, input {      if predicate_fn.call(input)        reducing_fn.call(result, input)      else        result      end    }  }endHere’s how reducers can be used now:

pushes = -> list, item { list.push(item) }[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &mapping   { |x| x + 1   }.call(&pushes))  .reduce([], &selecting { |x| x.even? }.call(&pushes))# => [2, 4, 6, 8, 10]The type of reducers is result, input -> result:

pushes = -> list, item { list.push(item) }mapping { |x| x + 1 }  .call(&pushes)  .call([], 1);# => [2]mapping { |x| x + 1 }  .call(&pushes)  .call([2], 2)# => [2, 3]mapping { |x| x + 1 }  .call(&pushes)  .call([2, 3], 3)# => [2, 3, 4]selecting { |x| x % 2 === 0 }  .call(&pushes)  .call([2, 4], 5)# => [2, 4]selecting { |x| x % 2 === 0 }  .call(&pushes)  .call([2, 4], 6)# => [2, 4, 6]Composition of reducers has the exact same type:

plus_one_even = mapping { |x| x + 1 }  .call(&selecting { |x| x.even? })  .call(&pushes)So it also can be used as a reducer:

[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &plus_one_even)# => [2, 4, 6, 8, 10]Let’s use Ramda.compose from Ramda library for better readability:

require 'ramda'transform = Ramda.compose(  mapping { |x| x + 1 },  filtering { |x| x.even? },  pushes)[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &transform)More complex example:

require 'ramda'square = -> x { x * x }transform = Ramda.compose(  filtering { |x| x.even? },  filtering { |x| x < 10 },  mapping(&square),  mapping { |x| x + 1 },  pushes)[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]  .reduce([], &transform)# => [1, 5, 17, 37, 65]Finally let’s wrap it into transduce helper function:

def transduce(transformation, reducing_fn, initial, input)  input.reduce(initial, &transformation.call(&reducing_fn))endUsage example:

transformation = Ramda.compose(  mapping   { |x| x + 1   },  selecting { |x| x.even? })plus_one_evens = transduce(  transformation,  pushes,  [],  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])# => [2, 4, 6, 8, 10]adds = -> a, b { a + b }sum_of_plus_one_evens = transduce(  transformation,  adds,  0,  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])# => 30Check out [transducers-js](https://github.com/cognitect-labs/transducers-js) library for a complete and performant transducers implementation in JavaScript. Read about [Transducer protocol](https://github.com/cognitect-labs/transducers-js#the-transducer-protocol) which allows different libraries to connect together (like Lodash, Underscore and Immutable.js).

> Leaving the above alone as there are not many great transducing libraries or implementations in Ruby. Feel free to comment below if you know of some I’ve missed :)Thanks again to [@roman01la](http://twitter.com/roman01la) for permission in translating this article!

We’ll be taking a more in-depth view of transducers in the next few months in some additional articles. This one in particular was a throw-back to the article which really helped me get the gist of transducers, so hopefully it helps a few of you out as well!

To give you a hint, did you happen to notice how there’s an empty value and a way to join values into it? Keep that in mind :)

Look forward to the next articles, there’s some fun stuff in the pipeline.


