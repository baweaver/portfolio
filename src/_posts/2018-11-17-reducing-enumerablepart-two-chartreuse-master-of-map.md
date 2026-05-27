---
layout: "post"
title: "Reducing Enumerable — Part Two: Chartreuse, Master of Map"
series: "reducing-enumerable"
date: "2018-11-17"
categories: []
tags: []
description: ""
---

This brings us to part two of Reducing Enumerable where we meet Chartreuse, the master of Map.

**Table of Contents**

1. [The Journey Begins](/writing)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[<< Previous](/writing) | [Next >>](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

## Chartreuse — Master of Map

![](/images/posts/reducing-enumerable/img-9b7183c6.png)

So Red journeyed through the forests of transformation, deep into the groves where the mushrooms bloomed and the creeks ran a sparkling blue. There he found a path, and at the end was a house, and outside of it was the first master he was to meet.

![](/images/posts/reducing-enumerable/img-a4f6bb32.png)

Inside the house was Chartreuse, the master of Map.

“Welcome, Red. I’ve heard much about your journey from Master Scarlett.” said Chartreuse.

Red peered into the potion that Chartreuse was making, trying to make sense of what form of wizardry arts she was performing, so he asked: “What amazing thing are you crafting?”

“Mmm? Oh! This. It’s just food for my kitties, you see it’s time for their supper so I have to set to transform a list of ingredients into something they might find a bit more enjoyable.” said Chartreuse.

“And the scroll?” asked Red.

“Just a recipe, the kitties helped me make it. They’re quite talented at cooking when given some incentive.” answered Chartreuse.

“Wise master, can you tell me how map works so I can implement it with reduce?” asked Red

“Let me show you, young one, the ways of mapping” said Chartreuse

![](/images/posts/reducing-enumerable/img-5608875a.png)

“To map is to apply a function to every element of a list, getting back a new list.” said Chartreuse.

**How to Map**

So then Chartreuse began to explain map. Shall we take a look?

![](/images/posts/reducing-enumerable/img-8c69b678.png)

“Such that we have a list of one two and three, and we wish to multiply every element by two. That is our function.” said Chartreuse.

![](/images/posts/reducing-enumerable/img-c7c77cd7.png)

“So each element of the list is doubled, and added to a new list! This means that the original list is left intact, unchanged!” exclaimed Chartreuse.

**Map with Reduce**

With that, Red decided to attempt mapping himself.

![](/images/posts/reducing-enumerable/img-92ca7b7d.png)

Given that Red now had an array instead of a number to work with, he would have to use push to join an element to the accumulator, a.

![](/images/posts/reducing-enumerable/img-4c221178.png)

But before he could push a new element onto an array, he would need to apply a function to it. Applying a function was essentially using call to call a block function in Ruby.

![](/images/posts/reducing-enumerable/img-6f0e7304.png)

All together it might look a little something like this, but let’s break it down a bit and see what we’re doing here.

![](/images/posts/reducing-enumerable/img-38140bbf.png)

First we have our list, much like our original reduce, except we’re taking it as an argument to our new method version of map. Each value in our list goes into our reduce as v.

![](/images/posts/reducing-enumerable/img-6a6fccd0.png)

Next we have our accumulator, which is now an array. In our reduce, it’s seen as a.

![](/images/posts/reducing-enumerable/img-dbfc9b37.png)

To add elements, or rather join them to our accumulator array, we use push which adds them to the end of the list.

![](/images/posts/reducing-enumerable/img-3dcb1d5d.png)

…but not before we apply, or call, our block function we receive from calling the method on the value.

![](/images/posts/reducing-enumerable/img-28abe345.png)

Which all together means that we push onto our new list the result of calling a function on each element of our list.

![](/images/posts/reducing-enumerable/img-6f0e7304.png)

Seen together, this makes a bit more sense now what’s going on, but how does the data flow through this function? How do we call it? Let’s take a look.

![](/images/posts/reducing-enumerable/img-e088b118.png)

Unlike Enumerable#map, our new map function takes a list as an argument. After that, much like Enumerable#map we take a block function and end up returning the result of doubling every number in our original list without mutating it.

![](/images/posts/reducing-enumerable/img-27164057.png)

Meaning that the data would flow through our function a bit like this:

1. We start with an empty array, and we push onto it the result of our first element, 1, applied to our function v * 2, which means the value 2 gets pushed onto our accumulator.

1. We start with an accumulator [2], and we push onto it the result of doubling 2, giving us a new accumulator of [2, 4].

1. We start with an accumulator [2, 4], and we push onto it the result of doubling 3, giving us a final accumulator of [2, 4, 6].

1. Now that we’ve run out of elements, our final accumulator is returned.

## What is Map?

![](/images/posts/reducing-enumerable/img-ae760011.png)

To use map is to apply a function to every element of a list to get a new list.

To implement map with reduce, you need to apply a function to each element of a list before adding it to a new list.

## Onwards!

![](/images/posts/reducing-enumerable/img-76ec5e8c.png)

Now that Red had learned from Chartreuse, it was time to visit Master Indigo of Select.

[<< Previous](/writing) | [Next >>](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)
