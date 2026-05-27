---
layout: "post"
title: "Ruby in FantasyLand: SumsUp"
date: "2022-05-24"
categories: []
tags: []
description: "Javascript comes with this lovely little spec called Fantasy Land that defines certain type classes..."
---

Javascript comes with this lovely little spec called [Fantasy Land](https://github.com/fantasyland/fantasy-land) that defines certain type classes in Category Theory and how they interact.

Years ago, when I was particularly interested in learning about Category Theory, Algebraic Types, and the lot of it I had stumbled upon a lovely series from [Tom Harding](https://twitter.com/am_i_tom) called [Fantas, Eel, and Specification](http://www.tomharding.me/fantasy-land/) which I got quite a bit of enjoyment from.

This series, with the permission of [Tom](https://twitter.com/am_i_tom), is a reinterpretation of those posts in Ruby along with some of my own thoughts.

With that said, let's get into it.

## SumsUp

The initial post that we're working from is the introduction into both data classes and sum types using [Daggy](https://github.com/fantasyland/daggy), and you can read the original post here:

http://www.tomharding.me/2017/03/03/fantas-eel-and-specification/

Now with Ruby we have a few different ideas we want to express. Whereas Daggy has `tagged` and `taggedSum` we have `Struct` and `SumsUp.define` instead. You can find more info on SumsUp [here](https://github.com/nahiluhmot/sums_up), but we'll be covering the general details in this post.

## Struct vs Tagged

The idea of Daggy's `tagged` method is to create a succinct inline type. In Ruby we have `Struct` which matches this use case, which you can compare:

```javascript
//- A coordinate in 3D space.
//+ Coord :: (Int, Int, Int) -> Coord
const Coord = daggy.tagged('Coord', ['x', 'y', 'z'])

//- A line between two coordinates.
//+ Line :: (Coord, Coord) -> Line
const Line = daggy.tagged('Line', ['from', 'to'])
```

To the Ruby equivalent:

```ruby
Coord = Struct.new(:x, :y, :z)
Line = Struct.new(:from, :to)
```

If we really wanted to be precise we could even look into [Sorbet Typed Structs](https://sorbet.org/docs/tstruct) for the sake of explicitness:

```ruby
require "sorbet-runtime"

class Coord < T::Struct
  extend T::Sig
  
  prop :x, Integer
  prop :y, Integer
  prop :z, Integer
  
  sig { params(x: Integer, y: Integer, z: Integer).returns(Coord) }
  def translate(x:, y:, z:)
    Coord.new(x: @x + x, y: @y + y, z: @z + z)
  end
end

class Line < T::Struct
  prop :from, Coord
  prop :to, Coord
end

a = Coord.new(x: 1, y: 2, z: 3)
b = Coord.new(x: 0, y: 2, z: 3)

path = Line.new(from: a, to: b)

Coord.new(x: 1, y: 2, z: 3).translate(x: 1, y: 1, z: 1)
# => <Coord x=2, y=3, z=4>
```

...but that may be a matter for a later day, and an exercise left to the reader, though I would still recommend explicit classes if you find yourself writing methods on data objects like this.

Anyways, that aside, we also need to know how to put basic methods on a `Struct` as well, and there are two ways to do that:

```ruby
Coord = Struct.new(:x, :y, :z) do
  def translate(x, y, z)
    self.class.new(self.x + x, self.y + y, self.z + z)
  end
end

Coord.new(1, 2, 3).translate(1, 1, 1)
# => #<struct Coord x=2, y=3, z=4>

Coord.define_method(:move_north) do |y = 1|
  self.class.new(self.x, self.y + y, self.z)
end

Coord.new(1, 2, 3).move_north(2)
# => #<struct Coord x=1, y=4, z=3>
```

Though honestly by that rate I would likely consider creating a class instead as this can get a bit complicated.

Oh, and you can do this with `Struct`, same as `new`:

```ruby
Coord[1, 2, 3]
# => #<struct Coord x=1, y=2, z=3>
```

As another aside I tend to prefer `keyword_init` as it makes things clearer:

```ruby
Coord = Struct.new(:x, :y, :z, keyword_init: true)
Coord.new(x: 1, y: 2, z: 3)
# => #<struct Coord x=1, y=2, z=3>
```

The intention of `tagged` and `Struct` are to give a name to a piece of data, and then give names to the fields or properties in that data, making them a handy quick utility for simpler cases. If you find yourself going beyond the simple, however, perhaps a class will make more sense.

## taggedSum vs SumsUp define

Now this one will be a bit more foreign. Starting with the example provided, `Bool`, which can be true or false. That means a type with multiple constructors, or a "sum" type:

```javascript
const Bool = daggy.taggedSum('Bool', {
  True: [], False: []
})
```

...and in Ruby:

```ruby
Bool = SumsUp.define(:true, :false)
```

As neither have arguments the `define` method accepts a list of variants without arguments. Where this gets more interesting is around ones that do:

```javascript
const Shape = daggy.taggedSum('Shape', {
  // Square :: (Coord, Coord) -> Shape
  Square: ['topleft', 'bottomright'],

  // Circle :: (Coord, Number) -> Shape
  Circle: ['centre', 'radius']
})
```

...and in Ruby:

```ruby
Shape = SumsUp.define(
  # Square :: (Coord, Coord) -> Shape
  square: ["top_left", "bottom_right"],
  
  # Circle :: (Coord, Number) -> Shape
  circle: ["center", "radius"]
)
```

This gives us something quite foreign to work with, as now we're not working with inheritance but rather describing the shapes of data and how we interact with them:

```javascript
Shape.prototype.translate =
  function (x, y, z) {
    return this.cata({
      Square: (topleft, bottomright) =>
        Shape.Square(
          topleft.translate(x, y, z),
          bottomright.translate(x, y, z)
        ),

      Circle: (centre, radius) =>
        Shape.Circle(
          centre.translate(x, y, z),
          radius
        )
    })
  }

Shape.Square(Coord(2, 2, 0), Coord(3, 3, 0))
    .translate(3, 3, 3)
// Square(Coord(5, 5, 3), Coord(6, 6, 3))

Shape.Circle(Coord(1, 2, 3), 8)
    .translate(6, 5, 4)
// Circle(Coord(7, 7, 7), 8)
```

...and in Ruby this would be:

```ruby
Coord = Struct.new(:x, :y, :z) do
  def translate(x, y, z)
    self.class.new(self.x + x, self.y + y, self.z + z)
  end
end

Shape = SumsUp.define(
  # Square :: (Coord, Coord) -> Shape
  square: [:top_left, :bottom_right],
  
  # Circle :: (Coord, Number) -> Shape
  circle: [:center, :radius]
) do
  def translate(x, y, z)
    match do |m|
      m.square do |top_left, bottom_right|
        Shape.square(
          top_left.translate(x, y, z),
          bottom_right.translate(x, y, z)
        )
      end
      
      m.circle do |center, radius|
        Shape.circle(center.translate(x, y, z), radius)
      end
    end
  end
end

Shape
	.square(Coord[2, 2, 0], Coord[3, 3, 0])
	.translate(1, 1, 1)
# => #<variant Shape::Square
#	  top_left=#<struct Coord x=3, y=3, z=1>,
#   bottom_right=#<struct Coord x=4, y=4, z=1>
# >

Shape.circle(Coord[1, 2, 3], 8).translate(6, 5, 4)
# => #<variant Shape::Circle
#   center=#<struct Coord x=7, y=7, z=7>,
#   radius=8
# >
```

>  **Note:** As types stack up here though I do become more convinced that Sorbet may be a good addition to the following parts of this tutorial, and may see about working around `SumsUp` or make a similar interface later. Feedback welcome.

Now the tutorial mentions Catamorphisms, as Daggy uses `cata`, but to me this is very similar to pattern matching of which `SumsUp` provides their own interface for. There may be an additional case for introducing pattern matching from Ruby 2.7+ into these interfaces later, but I digress again.

The original article sums (ha) it up nicely by saying that sum types are types with multiple constructors.

## Lists with Sums

Now let's take a look at the final example mentioned here:

```javascript
const List = daggy.taggedSum('List', {
  Cons: ['head', 'tail'], Nil: []
})

List.prototype.map = function (f) {
  return this.cata({
    Cons: (head, tail) => List.Cons(
      f(head), tail.map(f)
    ),

    Nil: () => List.Nil
  })
}

// A "static" method for convenience.
List.from = function (xs) {
  return xs.reduceRight(
    (acc, x) => List.Cons(x, acc),
    List.Nil
  )
}

// And a conversion back for convenience!
List.prototype.toArray = function () {
  return this.cata({
    Cons: (x, acc) => [
      x, ... acc.toArray()
    ],

    Nil: () => []
  })
}

// [3, 4, 5]
console.log(
  List.from([1, 2, 3])
  .map(x => x + 2)
  .toArray())
```

...and the Ruby variant:

```ruby
List = SumsUp.define(cons: [:head, :tail], nil: []) do
  def map(&fn)
    match do |m|
      m.cons do |head, tail|
        List.cons(fn.call(head), tail.map(&fn))
      end
      
      m.nil {}
    end
  end
  
  def to_a
    match do |m|
      m.cons { |head, tail| [head, *tail.to_a] }
      m.nil {}
    end
  end
    
  def self.from(plain_list)
    # Approximation of "reduce_right"
    plain_list.reverse.reduce(List.nil) do |acc, v|
      List.cons(v, acc)
    end
  end
end

List.from([1, 2, 3])
# <variant List::Cons head=1, tail=
#   <variant List::Cons head=2, tail=
#     <variant List::Cons head=3, tail=#<variant List::Nil>>>>

List.from([1, 2, 3]).map { |x| x + 2 }
# <variant List::Cons head=3, tail=
#   <variant List::Cons head=4, tail=
#     <variant List::Cons head=5, tail=#<variant List::Nil>>>>

List.from([1, 2, 3]).map { |x| x + 2 }.to_a
# => [3, 4, 5]
```

Which gives us an interesting brief look into linked lists and some old lisp naming with [cons](https://en.wikipedia.org/wiki/CAR_and_CDR), though others might recognize `car` and `car` more readily.

## Wrap Up

That about wraps us up on the first post. You can find the rest of [Tom Harding](https://twitter.com/am_i_tom)'s lovely series [here](http://www.tomharding.me/fantasy-land/) if you want spoilers, otherwise it may be prudent to convince me on Twitter not to try and hack together an algebraic datatype library with Sorbet-aware classes as I find myself quite tempted at the moment.

The next post goes into type signatures, and from there we start a very interesting journey. While you may recognize some patterns and have your own intuition around them (cata/pattern matching looks like inheritance) keep an open mind for the moment and see where it takes us from here.

Oh, and yes, this is a Monad tutorial in the end.
