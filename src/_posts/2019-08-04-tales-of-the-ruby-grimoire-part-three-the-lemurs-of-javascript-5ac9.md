---
layout: "post"
title: "Tales of the Ruby Grimoire - Part Three - The Lemurs of Javascript"
series: "tales-ruby-grimoire"
date: "2019-08-04"
categories: ["ruby", "javascript"]
tags: ["ruby", "javascript"]
description: "Dark tales of Ruby magics from beyond what any sane Rubyist would teach in a book of legends, opened by a particularly curious young lemur named Red."
---

This is a text version of a talk given at Southeast Ruby 2019, and the first of many tales of the legendary Ruby Grimoire, a great and terrible book of Ruby dark magics.

I've broken it into sectional parts so as to not overwhelm, as the original talk was very image heavy. If you wish to skip to other parts, the table of contents is here:

**Table of Contents**

1. [Part One - The Grimoire](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-one-the-grimoire-2712/)
2. [Part Two - The Lemurs of Scala](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-two-the-lemurs-of-scala-3d1e/)
3. [Part Three - The Lemurs of Javascript](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-three-the-lemurs-of-javascript-5ac9/)
4. [Part Four - The Lemurs of Haskell](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-four-the-lemurs-of-haskell-3p4f/)
5. [Part Five - On the Nature of Magic](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-five-on-the-nature-of-magic-g63/)


# Tales of the Ruby Grimoire - Part Three - The Lemurs of Javascript

Wherein Red learns from the Lemurs of Javascript about arts of destructuring and secrets of Ruby proc functions.

## Introducing the Lemurs of Javascript

![Crimson showing the book of Javascript](/images/posts/tales-ruby-grimoire/img-9320e475.png)

In my journeys, in a land not far from this one, I found the lemurs of Javascript, fascinating masters with lessons even more fascinating indeed!

![The Lemurs of Javascript](/images/posts/tales-ruby-grimoire/img-29b5a82b.png)

The lemurs of Javascript were fashionable masters with all form of accessories, colors, designs, and decorations. Why, they even change the very language by which they communicate through their accessories in a most wondrous of systems through an art of Babel.

They bring with them arts of destructuring beyond that which we know in Ruby.

## Of Destructuring

![Marigold extracting arguments out of an object](/images/posts/tales-ruby-grimoire/img-71e45e7f.png)

It allows them to pull values out of objects by their names!

```js
function moveNorth({ x, y }) {
  return { x: x, y: y + 1 };
}

moveNorth({ x: 1, y: 2 })
=> { x: 1, y: 3 }
```

The `moveNorth` function can extract the `x` and `y` values from the object passed to it in an art known as destructuring. Inside of this function, the value of `x` is `1` and the value of `y` is `2`, so we can use those values to add `1` to `y` to make it move “north”.

```js
function moveNorth({ x, y }) {
  return { x, y: y + 1 };
}

moveNorth({ x: 1, y: 2 })
=> { x: 1, y: 3 }
```

There’s another magic in Javascript, one I have not found the way to emulate, called punning. Of course we like punning in Ruby, yes yes, several famous Rubyists love punning, but this type of punning is different and beyond us.

It allows us to make a new object with `x` unchanged and `y` with one added, but this is an art for another day. Namely after I can figure out how to make it work, and at what cost *grumbles*

Anyways, not the point, we need a few tricks to make this work.

## Extracting Arguments

![Crimson extracting arguments from a function](/images/posts/tales-ruby-grimoire/img-fd4b3aab.png)

We can do destructuring in Ruby, but first we must learn an art of extracting arguments from a Proc, or rather a function.

Say we had a function, `fn`. Empty for now because we only need to look at its arguments:

```ruby
-> x, y {}
```

There exists a method on Proc, or functions, known as parameters. It returns back an array of pairs, the first item being the type of parameter and the second being the actual name of it:

```ruby
fn = -> x, y {}
fn.parameters
=> [[:req, :x], [:req, :y]]
```

If we were to get the last item of each of those, we have the names of the function arguments:

```ruby
fn = -> x, y {}
fn.parameters.map(&:last)
=> [:x, :y]
```

## Destructuring in Ruby

![Red and Marigold work together to make Destructuring in Ruby](/images/posts/tales-ruby-grimoire/img-18ae70ca.png)

This is all we need to create a destructuring of our own. If we know the names of arguments, we can use them.

Let’s say we had a Point, a simple struct:

```ruby
Point = Struct.new(:x, :y)
```

For those not familiar, it’s equivalently this, but I’d much rather write the above:

```ruby
class Point
  attr_accessor :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end
end
```

For simplicities sakes, we’ll start with a point called origin at `x` of `0` and `y` of `0`:

```ruby
Point = Struct.new(:x, :y)
origin = Point.new(0, 0)
```

Let’s make our own method called destructure which takes in an object and a block function. We can assume for now that the object is our origin point, and our function will have the arguments `x` and `y`

```ruby
def destructure(obj, &fn)
end
```

The first step is to get the names of the arguments from the block function that was passed in:

```ruby
def destructure(object, &fn)
  argument_names = fn.parameters.map(&:last)
end
```

If the function happened to have `x` and `y` as arguments like above, it would be the same as saying this:

```ruby
argument_names = [:x, :y]
```

It allows us to get the argument names of any function though, which can be very handy.

Next, we're going to need to do some actual destructuring by pulling values out of the object:

```ruby
def destructure(object, &fn)
  argument_names = fn.parameters.map(&:last)
  values = argument_names.map { |a| object.send(a) }
end
```

We use `map` to transform the argument names to the value of the object at that name using `send`. In the case of our origin point and `x/y` function, that would mean the line ends up doing this:

```ruby
values = [object.x, object.y]
```

Now that we have the values, all that's left is to call the original function with it:

```ruby
def destructure(object, &fn)
  argument_names = fn.parameters.map(&:last)
  values = argument_names.map { |a| object.send(a) }

  fn.call(*values)
end
```

Assuming again origin and that function, we get something like this happening:

```ruby
-> x, y {}.call(*[0, 0])
```

If we were to use this destructuring method on our origin point we could even move it north:

```ruby
Point = Struct.new(:x, :y)
origin = Point.new(0, 0)

destructure(origin) { |x, y|
  Point.new(x, y + 1)
}
=> Point(0, 1)
```

The `x` and `y` values of that function are now effectively bound to the `x` and the `y` of our origin point.

We could even do something quite silly like use `to_s` as a name which would give us back the string representation. Not sure why, but it's amusing to think on!

Now a clever lemur might be able to redefine methods using these same tricks to add a `destructure` decorator that can tell the difference between an object and the expected arguments, but another chapter I’m afraid is beyond us for the moment.

## Considerations

By this point Red was worried, and had to say something.

"But surely this is evil, `send` is metaprogramming! Metaprogramming is the root of all evils in Ruby, isn’t it?" objected Red

"Metaprogramming has its uses, a vast and seldom well understood and explored territory. Naturally there are dangers, but must one discard such power simply for the dangers? Perhaps and perhaps not, it depends on the context and the wisdom of the wielder. Evil is far too strong a word for what is merely misunderstood and abused by those not ready for it." answered Crimson.

Red nodded, considering himself obviously ready for such an art, and they walked on.

# End of Part Three

This ends Part Three, and with it comes even more resources. I cannot say Ruby has officially adopted this type of code yet, but perhaps one day.

* [Ruby Tapas - Param Destructuring](https://www.rubytapas.com/2019/02/25/parameter-destructuring/)
* [Destructuring in Ruby](/writing/2018/10/05/destructuring-in-ruby/)
* [Qo - Destructuring Branch matchers](https://github.com/baweaver/qo/blob/bdd92b56cd7cc7f71f978d6b3cbb035c95b4b707/lib/qo/destructurers/destructurer.rb)

**Table of Contents**

1. [Part One - The Grimoire](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-one-the-grimoire-2712/)
2. [Part Two - The Lemurs of Scala](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-two-the-lemurs-of-scala-3d1e/)
3. [Part Three - The Lemurs of Javascript](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-three-the-lemurs-of-javascript-5ac9/)
4. [Part Four - The Lemurs of Haskell](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-four-the-lemurs-of-haskell-3p4f/)
5. [Part Five - On the Nature of Magic](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-five-on-the-nature-of-magic-g63/)
