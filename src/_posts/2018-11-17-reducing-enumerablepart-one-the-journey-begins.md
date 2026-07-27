---
layout: "post"
title: "Reducing Enumerable — Part One: The Journey Begins"
series: "reducing-enumerable"
date: "2018-11-17"
categories: []
tags: ["ruby", "functional", "beginners"]
description: "Part one of Reducing Enumerable — Red the lemur begins his journey to learn the deeper secrets of reduce from the masters of Enumerable."
---

This brings us to part one of Reducing Enumerable where we meet Red and begin the journey.

**Table of Contents**

1. [The Journey Begins](/writing/2018/11/17/reducing-enumerablepart-one-the-journey-begins/)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[Next >>](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

## Meet Red

![Title slide for Reducing Enumerable](/images/posts/reducing-enumerable/img-miaXhvAsdjb_9Q7kwrisbg.png)

Behold! The lemurs have chosen to appear on a text-based medium, bringing with them the entirety of the illustrated content from "Reducing Enumerable — An Illustrated Adventure".

If you wish to see the full RubyConf version of the talk, you can find it here:

<iframe width="560" height="315" src="https://www.youtube.com/embed/x3b9KlzjJNM" frameborder="0" allowfullscreen></iframe>

As this was a very image intensive and story driven presentation, we'll be splitting this up into multiple articles for the sake of digestibility.

![Red waving hi](/images/posts/reducing-enumerable/img-VJ0bJnTTE3wbzmyDIMQihQ.png)

Meet Red, the lemur. He's a student of the great Master Scarlet, learning the ways of reduce.

He's been practicing for quite some time now on summing numbers and learning the ways of functional programming.

By this point he believes himself to be quite adept at it, if not ready to attempt the mastership trials himself.

![Red with a hammer, thinking about reducing things](/images/posts/reducing-enumerable/img-7GGEKQ6084ungrcsT0uKFg.png)

Now Red absolutely adores reduce, and especially reducing large stacks of numbers into simple sums. He's gotten quite good at it in fact.

![Red dreaming about reducing big stacks of numbers](/images/posts/reducing-enumerable/img-yU8026k-RCmCkk-4QdJ4Hw.png)

So good in fact that he's become rather obsessed with it, and he'd like to show us the basics of how reduce works. Shall we take a look?

## A Look into Reduce

Now reduce is a very interesting function in Enumerable, and very frequently it's hard to understand what it's doing.

Let's take a bit of a look into how it works.

![list of 1, 2, and 3 sums to 6](/images/posts/reducing-enumerable/img-UVj292D50Kygv8NOyd_w5A.png)

Reduce, in the case of a sum, takes in a list of numbers and returns back the sum of those numbers.

![reduce code example](/images/posts/reducing-enumerable/img-XUozGLSdTQ35iAdoJZws9w.png)

The code for this might look something like this, but that's a bit hard to understand, so let's break it down a bit, shall we?

**Accumulators**

![Looking at the accumulator](/images/posts/reducing-enumerable/img-9MtmDrUn2gNTdi_YdCE7jg.png)

We start with an accumulator. An accumulator starts as the first argument to reduce, and in this case it's `0`. Why `0`? If we add anything to `0` we get back that number. That makes it a good "empty" element.

When the list is empty we get back our empty element!

We'll see our accumulator show up as `a` throughout this article.

**Lists and Values**

![Looking at the list](/images/posts/reducing-enumerable/img-fuXv9ePmeou3_LBfdBzaLA.png)

Next up is our list, which will show up as `v` throughout this article. Every element of our list will be iterated over while reducing, going into the function as `v`.

**Joining Values and Accumulators**

![Looking at the plus operator](/images/posts/reducing-enumerable/img-i4v74fCJgxzme1Pjs5yIeQ.png)

Last, and perhaps most importantly is how we join our value and our accumulator together to make a new accumulator. In this case, `+`.

Now the interesting thing here is that how we join things together impacts our empty value as well. It would make very little sense to join any number with multiplication if our supposedly empty value is `0`, no?:

```ruby
[1, 2, 3].reduce(0) { |a, v| a * v }
# => 0
```

It would always return `0`! Instead we'd want to use `1` for this particular pairing.

**All Together Now**

![0 + 1, 2, 3](/images/posts/reducing-enumerable/img-9mBywmY8popWA9RvTiywBQ.png)

So all together we might have something that looks a bit like this. Reducing the list of `1, 2, 3` into the starting value `0` using `+` to join values together.

More commonly that might look something like this:

![0 + 1 + 2 + 3](/images/posts/reducing-enumerable/img-YqHblM9gE4AgvYSTyxRHtA.png)

But how exactly does it work? How do we trace that flow of data? Let's take a look into that.

**How Reduce Reduces**

![Each step of reduce](/images/posts/reducing-enumerable/img-4ggdMjlAOfL5ZGdXFEXpQQ.png)

For every loop of reduce, we pass into the function our accumulator and our next value. Whatever is returned from that function becomes the new accumulator on the next run of reduce.

1. We start out with an initial value of `0` and add `1` to it, giving us a new accumulator of 1.
2. That means next loop we start with `1` and add to it the next value in our list, `2`, giving us `3`.
3. On our last loop we have an accumulator of `3` and a last value of `3`.
4. Now that reduce has run out of numbers to, well, reduce, it returns the final accumulator it had. In this case, our answer is `6`.

**What is Reduce?**

![Explaining the core elements of reduce](/images/posts/reducing-enumerable/img-xP_-4F190TjnAQW5uqfV1g.png)

Reduce is a way to take a list of many things and reduce it into one thing using an initial value, and a way to join values together to make a new accumulator.

## Masters of Functional Programming

![Red dreaming of himself as a wise master](/images/posts/reducing-enumerable/img-8dK1iEDL3luPB2SzbQL8ww.png)

Surely now this makes us masters of Functional Programming, drinkers of the fount of knowledge, wise beyond our years and powerful beyond mortal reckoning! The full powers of Ruby are at our fingertips, and nothing can stop us!

Well, except for one thing…

## Enumerable#sum

![sum example](/images/posts/reducing-enumerable/img-GKdCxcEjwx3ou2q9YTPSqA.png)

Ruby 2.4+ introduced a new function, `sum`, which does about the same thing.

Realizing this, Red is noticeably distraught. Everything he had learned from before now seemed to be completely irrelevant in the face of this new function, which made him ask a very hard question:

![Is reduce unnecessary?](/images/posts/reducing-enumerable/img-UjMp6dtNA4PCS94LiDWGXg.png)

Was reduce unnecessary? He decided to go to the one source he knew would have an answer to his question, his master Scarlet.

**Asking for Help**

Red wrote a letter, asking her quite simply:

![Red writing letter to master](/images/posts/reducing-enumerable/img-eom6stDy9LUoGLjv7Vb3PA.png)

Does sum kill reduce? With the letter sent, Red began to pace, waiting eagerly for a reply. Finally, it came, his master had replied to his letter!

![Red receiving sealed envelope](/images/posts/reducing-enumerable/img-jagkY5UzOyd9Xyd51-zGJw.png)

…and inside the letter it said simply: "Come to me if you wish to learn".

With that, Red decided it was time to go on an adventure.

## Journey to Master Scarlet

![Red journeying to see his master](/images/posts/reducing-enumerable/img-z1NoFH9uO6iZW633_VbvHw.png)

So Red ventured through the plains and across the hills, into the mountains past the forests and creeks, and there before him was a sign. The sign pointed to the castle of his master, tucked away behind the clouds, high above the mountain peeks.

Around it giant balls of light circled, as if to invite those who had ventured to find her.

With that Red pressed on, and entered the castle.

## Master Scarlet

![Red explaining his predicament to his master](/images/posts/reducing-enumerable/img-8nPnCl0UhwbJmbOOG3uzZA.png)

So Red met master Scarlet in her castle, and began to tell her of all the things he had learned and done in his time since leaving. He had learned much and grown, but still he felt as if something were missing, something only she could show him, so Red asked:

"Wise master, does sum make reduce useless?" asked Red.

![Scarlet enlightening Red](/images/posts/reducing-enumerable/img-JzmgF9N3nzT53Ik5XzY16Q.png)

"Ah Red. Consider, for a moment perhaps, that you can do more than just summing with reduce. What if we used subtraction? Multiplication? Division? What if we don't use numbers at all?" replied Scarlet.

![Scarlet showing Red an empty array and push](/images/posts/reducing-enumerable/img-oCaRc9uKkAjEs4YjTGpPMg.png)

"Perhaps instead we have an empty array, and `push` to add elements to it. What could one do with this?" asked Scarlet.

![Scarlet sending Red off on an adventure](/images/posts/reducing-enumerable/img-khBxjHxLNmoSBi5fHBzXwg.png)

"I know just the thing. You'll find three masters in the land of Enumerable. Go out and learn from them about their functions, and see if you can figure out how you may use reduce to do the same."

With that, Scarlett left Red with much to think on, and a map to help him on his way.

## Into the Land of Enumerable

![Red looking at map](/images/posts/reducing-enumerable/img-Hv2fs0uRgPYBfxyq0jv2mA.png)

With that he was off to the corners of the map, to learn from the masters he would find there. The land of Enumerable was a vast place, full of surprises and curiosities, but with the help of his master and his trusty map, Red would find exactly what he needed.

[Next >>](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)
