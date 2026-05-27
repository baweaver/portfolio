---
layout: "post"
title: "Reducing Enumerable — Part Five: Cerulean, Master of Tally By"
series: "reducing-enumerable"
date: "2018-11-18"
categories: []
tags: []
description: ""
---

This brings us to part five of Reducing Enumerable where we meet Cerulean, the soon to be master of Tally By.

**Table of Contents**

1. [The Journey Begins](/writing)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[<< Previous](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/) | [Next >>](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

## A Master in the Making

On Red’s journey back home, he met someone entirely new, someone he hadn’t known he would learn from, the soon to be Master Cerulean.

![](/images/posts/reducing-enumerable/img-8bcfc3c7.png)

Cerulean was clapping on his tambourine as behind him, two other lemurs, Saffron and Vermilion, were singing along merrily. Red was naturally curious about this, and decided to ask.

“Who are those two in the other car?” asked Red

“They’re Saffron and Vermillion, my C extensions. They make trips go by so much faster, but they’re quite difficult to talk to. They only like to listen if I agree to play fiddle for some strange reason.” said Cerulean.

“So why journey to Master Scarlet?” asked Red

“Why, to start a new school of [tally_by](https://bugs.ruby-lang.org/issues/11076). I’ve heard from [Grand Master Nobu that it may well be coming to these lands of Enumerable soon](https://github.com/ruby/ruby/compare/trunk...nobu:feature/11076-Enumerable%23count_by). [It has yet to be decided in the council of 2.6](https://bugs.ruby-lang.org/issues/11076#note-7)” stated Cerulean

“Really? What does it do?” asked Red

“It tallies the elements of a list using a function to decide what exactly to tally on. Would you like me to show you? I would love to practice teaching.” asked Cerulean

“Yes! Please!” said Red, excitedly.

## How Tally By Works

![](/images/posts/reducing-enumerable/img-f3dd1c1a.png)

“Tally by works like map in that it applies a function to a value, but different in that it uses that value returned as the key to keep a tally of. In this case, true and false. In other cases, perhaps the first letter of a word or something else entirely.” said Cerulean.

![](/images/posts/reducing-enumerable/img-fbbb878f.png)

Such that we tally the elements one, two, and three by whether or not they’re even

![](/images/posts/reducing-enumerable/img-7a97a4d3.png)

One and three are not even, while two is. That means we have a count of two for which our function is false, and one for which our function is true.

## Tally By with Reduce

Find was already an odd function for reduce, but this was something new entirely! Red would need a different tool than an Array to solve this problem, much like find.

![](/images/posts/reducing-enumerable/img-4f76a7ee.png)

He would need a Hash, and not just any old hash. He would want a hash that had a default value of 0 so that he could freely count without having to use priming magics like a[:key] ||= 0 before using it to count anything.

![](/images/posts/reducing-enumerable/img-e9a787ef.png)

If Red were to emulate the style of his previous learnings in Functional Programming, his solution may have looked a bit like this. Given that Red is familiar in the arts of Ruby, there exists a simpler way to do this:

![](/images/posts/reducing-enumerable/img-0a7dc2d9.png)

Red would use a function to get an idea of what to count on. Much like map transforms an element, tally by would transform it and use that to decide what exactly to count on.

After deciding the key, it would add a count of one to the list of tallies.

![](/images/posts/reducing-enumerable/img-3f2a2b76.png)

Overall the function might look something like this.

![](/images/posts/reducing-enumerable/img-6230e308.png)

Where the key is derived from applying a function to a value to know what to count on.

![](/images/posts/reducing-enumerable/img-52a4514b.png)

…and that key is used to decide what count to increase in our Hash.

![](/images/posts/reducing-enumerable/img-c6a9a342.png)

It would be called much like our previous functions, but the results of how data would flow through it are starkly different.

![](/images/posts/reducing-enumerable/img-3d73517f.png)

1. There are no counts to start with. The first element is not even, so we add one count to false, giving us a new count of one false element.

1. There is a false count of one to start with. The second element is even, so we add one count to true, giving us a new count of one false and one true element.

1. There is one count of true and false to start with. The third element is not even, so we add one final count to false, giving us a final count of two false elements and one true element.

## What is Tally By?

![](/images/posts/reducing-enumerable/img-9b20b3cf.png)

To tally by is to count elements of a list after a function has been applied to them.

To tally by with reduce is to use a hash to keep counts of the result of applying a function to each element in a list.

## Onwards!

With that, it was truly time to return to his master. Red wished Cerulean luck in his trials as he exited the wagon and went on his way.

[<< Previous](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/) | [Next >>](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)
