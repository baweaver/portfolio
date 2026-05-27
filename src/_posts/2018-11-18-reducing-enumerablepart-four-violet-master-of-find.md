---
layout: "post"
title: "Reducing Enumerable — Part Four: Violet, Master of Find"
series: "reducing-enumerable"
date: "2018-11-18"
categories: []
tags: ["ruby", "functional", "beginners"]
description: "Part four of Reducing Enumerable — Violet teaches Red how to implement find using reduce."
---

This brings us to part four of Reducing Enumerable where we meet Violet, the master of Find.

**Table of Contents**

1. [The Journey Begins](/writing)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[<< Previous](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/) | [Next >>](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

## The Ruby on Rails

![](/images/posts/reducing-enumerable/img-30b3ada9.png)

But it was quite a distance to get to the city where Master Violet lived, so Red decided to take the train to cut down on time. For some strange reason it had called itself the “Ruby on Rails”, and everything in it was prefixed with “Active”.

Active Conductor, Active Trolly, Active Engine, it was a very odd thing but a very beautiful train. Red occasionally heard the engineers muttering rails g train_car or other such magical incantations just before another fully serviced car appeared, as if by magic!

It was a strange train.

## Entering the City

![](/images/posts/reducing-enumerable/img-d3e86ce9.png)

The train approached the city of Violet, master of Find. It was a truly massive city, filled with all forms of technological innovations and advancements of science. A wonder to behold, and all thanks to the tireless research of Violet.

Red watched out the window, sipping from his 418 internet enabled tea set the train service had brought in. Active tea?

Outside he saw cars flying through some new system of traffic, lights dancing in the sky, changing directions as the cars flowed along them. Warnings danced across merging lanes, stopping traffic as Sherlemur flew behind the notorious Arsene Lemur.

The train finally arrived at the station, and Red ventured into the city.

## The Library

![](/images/posts/reducing-enumerable/img-49b91d67.png)

In the city he found a massive library nestled in the center of a vast academy that stretched for what seemed like miles with bookshelves reaching to the heavens.

There, in the deepest alcoves, he found a room, and in that room he found Violet.

## Master Violet

![](/images/posts/reducing-enumerable/img-e21ddfc2.png)

Inside he found Violet, master of Find. She was looking for a very specific book as he entered.

“So you must be Red, oh I’ve heard so much about you. Come in come in. I’m just looking for a particular book at the moment.” said Violet

“So you look through your entire collection to find just one book?” asked Red

“Why no, how silly would it be to keep looking for a book I’ve already found. I would much rather stop and enjoy my reading.” said Violet

“Would you be willing to teach me how find works?” asked Red

“Of course!” exclaimed Violet.

**How Find Works**

So Violet had begun to show Red how find worked.

![](/images/posts/reducing-enumerable/img-e5ba5407.png)

“Find works much like select, but once we find what we’re looking for we stop looking. If we don’t find anything, we’ve found nothing. Now there are ways to have a default here, but we won’t worry about them today.” said Violet.

![](/images/posts/reducing-enumerable/img-bd68dbb7.png)

“Find uses a function, much like select, to find if an element matches our fancy. If it does, we return that one in particular. If we find no such thing, why, we just return nothing at all!” exclaimed Violet. “Such that we have a list of one two and three, and we wish to find the first even number. That is our function.”

![](/images/posts/reducing-enumerable/img-482abdca.png)

“So for each element of the list, we check whether or not it’s even. If it is, we’re done, that’s it. We’ve found what we came for, so it’s time to take a break!” exclaimed Violet.

“One is not even, so we keep looking. Two is, so we’re done. Our function returns two and does not bother to check three after it.” said Violet.

**Find with Reduce**

Now how would that apply to reduce, Red wondered. Breaks were a novel concept indeed, how would they work to stop searching once he found what he was looking for?

Really, we don’t even care about joining or accumulating anything! What an odd function to implement in reduce!

![](/images/posts/reducing-enumerable/img-a4c2d107.png)

We break out of our reduce, effectively returning a value.

![](/images/posts/reducing-enumerable/img-e1bd8ea9.png)

But much like Select, we only do so if our function returns a truthy value when called on our value.

![](/images/posts/reducing-enumerable/img-8710c5fa.png)

Together it would look like this, but what an odd function! We’re reducing into nil!

![](/images/posts/reducing-enumerable/img-9e707640.png)

We don’t even care about the accumulator! If it gets a new accumulator of nil we just keep on going and continue to ignore it.

![](/images/posts/reducing-enumerable/img-277baee6.png)

We can, however, use break to break out of our reduce and return a value. If that never happens we just get back nil.

![](/images/posts/reducing-enumerable/img-cbbb3699.png)

But we can only break out if our function happens to return truthy, otherwise as mentioned above we just get back nothing at all. We didn’t find anything, so we end up with nothing.

![](/images/posts/reducing-enumerable/img-eff59460.png)

Such a function would be called like this. Let’s take a look how the data might flow through this function.

![](/images/posts/reducing-enumerable/img-2db7f142.png)

1. We break out and return 1 if it’s even. Since it’s not we continue

1. We break out and return 2 if it’s even. Since it is, we return that value and stop looking. We’ve found what we were looking for so 3 doesn’t even get asked.

## What is Find?

![](/images/posts/reducing-enumerable/img-8d84fa42.png)

To find is to use a function to locate a single element in a list, then stop looking.

To find with reduce is to reduce into nothing until an element matches a function, then to break out and return that value.

## Onwards!

![](/images/posts/reducing-enumerable/img-5a6de6fe.png)

Now that Red had learned from Violet, it was time to return to his master and tell of everything he had learned.

[<< Previous](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/) | [Next >>](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)
