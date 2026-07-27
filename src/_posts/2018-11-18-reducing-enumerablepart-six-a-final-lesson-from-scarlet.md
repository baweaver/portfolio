---
layout: "post"
title: "Reducing Enumerable — Part Six: A Final Lesson from Scarlet"
series: "reducing-enumerable"
date: "2018-11-18"
categories: []
tags: ["ruby", "functional", "beginners"]
description: "The finale of Reducing Enumerable — Scarlet reveals the true nature of reduce and Red's journey comes full circle."
---

This brings us to part six of Reducing Enumerable where we return to Scarlet for Red’s final lesson.

**Table of Contents**

1. [The Journey Begins](/writing/2018/11/17/reducing-enumerablepart-one-the-journey-begins/)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[<< Previous](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

## On the Road Back

![](/images/posts/reducing-enumerable/img-dc9dbd3e.png)

After saying farewell to Cerulean, and wishing him luck on his meeting with the council of 2.6, Red found himself back where it all started.

There again in the distance was the castle of his master, Scarlet. He had much to tell, and he was quite excited.

![](/images/posts/reducing-enumerable/img-df6d79dd.png)

So Red told Scarlett of all the things he had learned and seen over the time he had spent in the land of Enumerable, and all the adventures he’d had.

![](/images/posts/reducing-enumerable/img-c3d36910.png)

He showed her all the functions he had learned, and told her of all the friends he had met along the way. It was truly an adventure of a life time, and he was glad to have taken it, but still he had a lingering question.

![](/images/posts/reducing-enumerable/img-df6d79dd.png)

All he had done was implement functions which already existed. Was this all to say reduce should be used for everything, or…

![](/images/posts/reducing-enumerable/img-a3aea2c7.png)

Is reduce completely unnecessary?

## A Lesson from Scarlet

![](/images/posts/reducing-enumerable/img-040a73f6.png)

“Ah Red, you’ve learned much, and of that I am quite proud. There is another lesson I must teach you though. Consider with me for a moment…” started Scarlet.

![](/images/posts/reducing-enumerable/img-6919326f.png)

“…would you use an axe to trim a bonsai?” asked Scarlet.

“Well, no, that would be rather silly wouldn’t it?” questioned Red.

“Another thought…” she started.

![](/images/posts/reducing-enumerable/img-049b5801.png)

“Would you use trimmers to cut down a mighty redwood?” she asked.

“Oh! Oh! Does this mean I get a git pruning?” asked Master Branch.

“Hush, you.” replied Scarlet under her breath.

“Well that wouldn’t make much sense either.” answered Red.

![](/images/posts/reducing-enumerable/img-040a73f6.png)

“So too are the ways of reduce! It has its uses when simple functions won’t do, but that doesn’t quite answer your question. Let us see some of the true powers of reduce.” answered Scarlet.

## The Powers of Reduce

![](/images/posts/reducing-enumerable/img-b9e7b687.png)

“There is true power here, young one, but power we must learn to use properly before we are able to use it correctly.” said Scarlet.

![](/images/posts/reducing-enumerable/img-2cef65eb.png)

“There are arts of composition, currying, [closures](/writing/2018/05/13/functional-programming-in-ruby-closures/), [transducers](/writing/2018/09/10/understanding-transducers-in-ruby/), category theories, and more beyond your wildest imaginations. That’s precisely what makes reduce so much fun to use and learn!” exclaimed Scarlet.

## Select Map

![](/images/posts/reducing-enumerable/img-233e623d.png)

Consider that we could combine the ideas of selecting and mapping into one using reduce. So too we can take this idea further by combining any of the functions which can be implemented in terms of reduce.

![](/images/posts/reducing-enumerable/img-b9e7b687.png)

The true power of reduce is in its flexibility to perform any Enumerable task, whether one or many. This leads into much more advanced arts.

![](/images/posts/reducing-enumerable/img-040a73f6.png)

“But you have journeyed far, and learned much. These are lessons for another day, for our time here is coming to a close dear Red. We shall talk again soon, and when that day comes I look forward to seeing everything you’ve done with what you’ve learned out there in the world.”

## Reflection

![](/images/posts/reducing-enumerable/img-560bba97.png)

…and with that Red journeyed back home.

Red had much to think on from this, realizing how much there was yet to learn out in the world, and how amazing it was that even learning all he did today there was still so much more! It was a grand adventure, and he was glad that he took it.

For you see, my esteemed audience, that is the beauty of programming, there are always more mysteries to solve, lessons to learn, people to laugh with, friends to make, and journeys that need to be experienced.

Perhaps this is the end of Red’s story, or perhaps just the beginning of an even grander one in the land of Enumerable.

## Credits

![](/images/posts/reducing-enumerable/img-599a2ea2.png)

Credit where credit is due, you may have noticed a few easter eggs hiding around the presentation.

The first on our list are the foxes from Why the Lucky Stiff. His book was my first experience to Ruby, and in many ways shaped my love for whimsy. It would be rude not to give a tip of the hat to our dear old friend, no matter where life may have taken him now, let him know we are grateful for his presence no matter how brief.

Matz and DHH had given me permission in the original talk to use their likenesses as a bit of extra fun, so I’d like to thank them for being incredibly good sports about it.

I’d also snuck a bundler tape gun in, and a bit of thanks goes to Andre for allowing me to use it.

There are many more references and tricks I’ve hidden about, see if you can find them all!

## On Reducing Enumerable

“Reducing Enumerable” is the culmination of half a years work, over 200 hours, 50 illustrations, 5000 lemur stickers, 1 5'5" lemur cutout, and a whole lot of love from an amazing community.

I couldn’t have pulled it off without all of your support, so know I’m thankful to every one of you who encouraged me along the way in preparing this material.

I’ve published an article exploring the Southeast Ruby version of the talk and some of the work that went into it:
[**Creating “Reducing Enumerable — An Illustrated Adventure”**
*How I created and illustrated my conference talk for Southeast Ruby 2018 (Video coming soon)*medium.com](/writing/2018/08/04/creating-reducing-enumerable-an-illustrated-adventure/)

Both the Southeast Ruby and RubyConf versions of this talk should have their videos published within the next month, look forward to seeing them when they come out! I’ll post updates on twitter @keystonelemur and update these articles and the source repo once I see them:
[**baweaver/reducing_enumerable**
*Talk examples, articles, and other useful tidbits. Contribute to baweaver/reducing_enumerable development by creating…*github.com](https://github.com/baweaver/reducing_enumerable)

## Wrapping Up

![](/images/posts/reducing-enumerable/img-5bfab0b9.png)

It’s been a blast, and thank you again to everyone involved in this crazy project. Look forward to my next projects which I’ll be officially announcing soon!

Stay awesome!

[<< Previous](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)
