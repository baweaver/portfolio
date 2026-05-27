---
layout: "post"
title: "Tales of the Ruby Grimoire - Part Two - The Lemurs of Scala"
series: "tales-ruby-grimoire"
date: "2019-08-04"
categories: ["ruby", "scala"]
tags: ["ruby", "scala"]
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

# Tales of the Ruby Grimoire - Part Two - The Lemurs of Scala

Wherein Red learns from the Lemurs of Scala the arts of closure and placeholder arguments.

## Introducing the Lemurs of Scala

![Crimson holding Scala book](/images/posts/tales-ruby-grimoire/img-76f05887.png)

"We shall first learn from the lemurs of Scala" said Crimson

![Lemurs of Scala](/images/posts/tales-ruby-grimoire/img-a0a9db0b.png)

"The lemurs of Scala wear their conical hats, spires to the heavens, cloaked in robes that change color as often as they change their styles of presentation. Where Ruby has flexibility Scala has much more, and the lessons they bring give us insight into these flexibilities." said Crimson, "They bring with them arts of closures, and a spell known as placeholder arguments."

## Placeholder Arguments

![Rose showing Scala](/images/posts/tales-ruby-grimoire/img-10bbad11.png)

Placeholder arguments are when an underscore can act as a shorthand for arguments to a function, like so:

```scala
// Scala

List(1, 2, 3).map(_ + 1)
=> List(2, 3, 4)
```

Now in Ruby you may well write something like this:

```ruby
# Ruby

[1, 2, 3].map { |x| x + 1 }
=> [2, 3, 4]
```

...but what if I told you that it was quite possible to do something which works quite a bit like Scala in Ruby too?

## Closures

![Rose showing Closures](/images/posts/tales-ruby-grimoire/img-ae33f689.png)

...but first we need to know of an art called closure.

```ruby
# Ruby

adds = -> a {
  -> b { a + b }
}
```

Consider a function that takes an argument, `a`, and returns a function which takes an argument `b`. The outer function takes in a value, `a` and returns a new function that takes an argument, `b`.

But notice! `a` is currently visible to the returned function, so the function “remembers” the value of `a`. This is a closure, it remembers the context where it was created, or rather it remembers whatever it can see around it.

```ruby
# Ruby

add_one = adds.call(1)
add_one.call(2)
=> 3
```

So when we call `adds` with `1` we get back a new function that remembers that `a` is `1`. The function returned from `adds` is called with the value `2` it returns `3`, remembering that `1` from above!

```ruby
# Ruby

add_one = adds.call(1)
[1, 2, 3].map(&add_one)
=> [2, 3, 4]
```

We can also provide this function to map using `&` (`to_proc`)


```ruby
# Ruby

[1, 2, 3].map(&adds.call(1))
=> [2, 3, 4]
```

We could also just inline this code!

Now how does this help us? Well we'll need a few more tricks to see that.

## Operators in Ruby

![Red using Ruby Operators](/images/posts/tales-ruby-grimoire/img-0d700ff4.png)

Let's take a look into how operators work in Ruby.

How does it know what this code is doing?:

```ruby
1 + 2
```

As it turns out, an operator like that is just syntactic sugar for this:

```ruby
1.+(2)
```

Operators are no more than methods! If we were to look, the implementation of that might look something like this:

```ruby
class Integer
  def +(b)
    fix_plus(self, b)
  end
end
```

...if you squint hard enough and pretend C code is Ruby and leave out a few more details. Those aren't important for now. Just remember that's all there is to an operator.

## Making our own placeholder arguments

![Red and Rose working together to make Placeholder arguments](/images/posts/tales-ruby-grimoire/img-60a2db90.png)

With these two tricks we know enough to make our own placeholder arguments, we just need a bit more Ruby magic and we’ll be able to dance a fine Scala dance!

What if we made our own class, `PArg`?:

```ruby
class PArg

end
```

...and defined an addition operator on it, but not as an instance method, no, a singleton!

```ruby
class PArg
  def self.+(a)
  end
end
```

Why would we want to do such a thing? Because it allows us to do this:

```ruby
PArg + 1
```

There's no real rule on what operators have to return, why, we could do anything we well pleased and that's exactly what we're going to do!

Remember back to closures, where we made an adder. Placeholder arguments are also waiting for a value, no?

What if we made our addition operation return back a function waiting for the number that should be on the "left" side of the equation?

```ruby
class PArg
  def self.+(a)
    -> b { a + b }
  end
end
```

That means that our addition operator now works quite a bit like our closure from above. What happens if we stick it in an equation?

```ruby
[1, 2, 3].map(&PArg + 1)
=> [2, 3, 4]
```

It turns out that that sugar extends to precedence as well, meaning that `+` will happen _before_ `&` (`to_proc`) does!

If we're feeling particularly naughty we could always do something like this as well:

```ruby
_ = PArg

[1, 2, 3].map(&_ + 1)
=> [2, 3, 4]
```

Now that looks a lot like Scala! ...it also has a bit of a nasty habit of doing bad things to REPLs and some other Ruby code, so be careful doing something to underscore.

Imagine with me that we write the rest of the possible operators, use `method_missing`, or `respond_to` to do more here! We could even make it into something that could say `_ + 1 == 2` and use it with `select` if we’re clever with stack builders! …but that’s a tale for another day, a later chapter in the Grimoire.

## Of Dark Magics

![Crimson and Red talking](/images/posts/tales-ruby-grimoire/img-e4f2041c.png)

Red stopped as they walked, and had to ask.

"But aren’t these dark magics? It feels like we’re doing bad things to the language for the sake of doing bad things to it!" exclaimed Red

"Well you're not wrong, in a way we're doing just that! Some would call these dark magics, where I would simply say they’re exploring the possibilities of the language! Imagine the use of such a thing, and how much more powerful your Ruby might be with it!" retorted Crimson.

Red nodded, so they continued on.

# End of Part Two

This ends Part Two, and with it comes a particularly dark revelation. This code exists both in Ruby core itself as of 2.7 and also in a gem. You can read more about them in the following resources:

* [Ruby 2.7 - Numbered Params](/writing/2019/03/18/ruby-2-7-numbered-parameters-1a79/)
* [Mf - Modifier Functions](https://github.com/baweaver/mf)
* [Mf - Abusing Ruby Operator Precedence](/writing/2018/12/26/mfabusing-rubys-operator-precedence/)
* [Sf - Abusing Operators and Method Missing](/writing/2018/12/27/sfabusing-operators-and-method-missing/)

Be warned though, these are quite certainly experimental except for the official Ruby 2.7 release of numbered params which will likely put these ideas into core with the December release.

**Table of Contents**

1. [Part One - The Grimoire](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-one-the-grimoire-2712/)
2. [Part Two - The Lemurs of Scala](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-two-the-lemurs-of-scala-3d1e/)
3. [Part Three - The Lemurs of Javascript](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-three-the-lemurs-of-javascript-5ac9/)
4. [Part Four - The Lemurs of Haskell](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-four-the-lemurs-of-haskell-3p4f/)
5. [Part Five - On the Nature of Magic](/writing/2019/08/04/tales-of-the-ruby-grimoire-part-five-on-the-nature-of-magic-g63/)
