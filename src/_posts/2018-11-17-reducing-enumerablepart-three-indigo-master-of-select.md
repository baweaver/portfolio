---
layout: "post"
title: "Reducing Enumerable — Part Three: Indigo, Master of Select"
series: "reducing-enumerable"
date: "2018-11-17"
categories: []
tags: ["ruby", "functional", "beginners"]
description: "Part three of Reducing Enumerable — Indigo teaches Red how to implement select using reduce."
---

This brings us to part three of Reducing Enumerable where we meet Indigo, the master of Select.

**Table of Contents**

1. [The Journey Begins](/writing/2018/11/17/reducing-enumerablepart-one-the-journey-begins/)

1. [Chartreuse — The Master of Map](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)

1. [Indigo — The Master of Select](/writing/2018/11/17/reducing-enumerablepart-three-indigo-master-of-select/)

1. [Violet — The Master of Find](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

1. [Cerulean — The Master of Tally By](/writing/2018/11/18/reducing-enumerablepart-five-cerulean-master-of-tally-by/)

1. [A Final Lesson from Scarlet](/writing/2018/11/18/reducing-enumerablepart-six-a-final-lesson-from-scarlet/)

[<< Previous ](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)| [Next >>](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)

## The Intercession of a Certain Tree

![](/images/posts/reducing-enumerable/img-2dcf0342.png)

After leaving the forests of Master Chartreuse, Red found himself getting more and more lost until eventually he had no idea where he was going any more.

There in the grove he found a hat on the ground, a hat that looked suspiciously like that of a Master, so he wondered out loud:

“Which master dropped their hat in this strange forest?” asked Red.

Just then several branches reached down from a gigantic tree, next to a scrawled out sign. One branch held a smiling face on a sticky note, and the other reached towards the hat. Then something peculiar happened: The tree spoke!

“Why yes! Yes it is! It’s my hat, and I’m so poor at keeping track of it” said the tree.

“Are you a Master?” asked Red.

“Indeed I am! I’m Master Branch!” the tree exclaimed merrily, “Y’see, I git blame that pesky cat for mixing everything up. It was probably up there cherry picking away, and couldn’t commit to anything! Now I have to git pull my hat back!”

Red started to back away slowly, pretending to pay attention to the tree, now noticing the wording read “Beware Tree”, that had been marked out with pencil. Now or never, Red decided to bolt.

“Wait wait wait, come back! I wasn’t finished!” he heard the tree cry out in the distance behind him.

## Stranger and Stranger Still

![](/images/posts/reducing-enumerable/img-e0dd7bba.png)

Red had managed to escape the tree, but as he went further into the cities things got much stranger. Up was down, left was right, the night sky had a brilliant sun shining and there was that cat again!

Was it a Cheshire? Everything was absolute chaos and not a bit of it made any sense!

There at the end of the twisting roads and warped villages he found the house of Master Indigo of Select. Inside he heard a mad cackling and ricketing, like the entire house was creaking under insanity.

![](/images/posts/reducing-enumerable/img-a68244b0.png)

“Ahahahaha!” screamed Indigo, as he went flying by on a train set that seemed to go nowhere and everywhere at the same time. “That blasted cat is at it again! Look what they’ve gone and done now!”

“Is… Is everything alright master” asked Red.

“Of course! It’s brilliant! They’ve really outdone themselves this time, I almost got lost but they didn’t get me this time! No no no.” said Indigo, still disappearing and reappearing through various train tunnels laced throughout his supposed house.

“Is it a cheshire cat?” asked Red.

“No no, it’s not wonderland here, it calls itself the Escher cat here. Brilliant creature that it is, I have to keep trying to find where it hid everything.” said Indigo, coming out of a tunnel backwards now, sipping a glass of tea.

“How in the world can you find anything in this chaos?” asked Red.

“Why with select of course! Look! I can even find all the rubies in the entire room with just one function!” exclaimed Indigo.

By now the train had started spinning on the tracks, and Indigo had begun singing a strange song “Come with me and you’ll see a world of pure… insanity? I can never remember that song, but that was a fine top hat! Right fine.”

**How Select Works**

So Indigo had begun to show Red how select worked.

![](/images/posts/reducing-enumerable/img-bbae31a9.png)

“You see, we can start with a magic trick! I love those!” exclaimed Indigo.

“If I take a number in, and apply a function to it, if it’s truthy I get to keep it, but otherwise?” prodded Indigo.

Red leaned in, as Indigo had gotten quiet.

“POOF!” shouted Indigo, disappearing out of his train.

Red jumped, looking around wildly, until Indigo appeared behind him in a puff of smoke.

“It’s gone! Never to be seen again. Beautiful, is it not?” asked Indigo.

![](/images/posts/reducing-enumerable/img-54f6827a.png)

“Say that we had the numbers one, two, and three and we wished to find which ones were even. One isn’t, so we throw it away. Two is, that’s exactly what I was looking for! Three? No no no, that won’t do at all, so we just get back an array containing two.” explained Indigo.

**Select with Reduce**

By this point Indigo had taken to singing another song (“You spin me round round round round round…”) so Red decided to try his hand at implementing a select function using reduce.

![](/images/posts/reducing-enumerable/img-34046a7c.png)

This one was a bit different. You would push an element onto a list without transforming it, but…

![](/images/posts/reducing-enumerable/img-49471de5.png)

Only if the function passed in happened to return true when applied to the element!

![](/images/posts/reducing-enumerable/img-fcb7a4c1.png)

That would mean that Red would need to make sure to return the accumulator either way, lest a sneaky nil get into his program from the condition being false!

![](/images/posts/reducing-enumerable/img-afd3ca15.png)

So the body of the function would be such that a new element was only added to the new list if the function returned true when applied to the value. If it wasn’t, the accumulator would be returned anyways.

![](/images/posts/reducing-enumerable/img-a0f2c1aa.png)

This would mean the entire function looks quite a bit like map, with only the middle lines changed.

![](/images/posts/reducing-enumerable/img-251a1de7.png)

That function would be called much like our map function from earlier, taking an array in as an argument.

The flow of data through that function might look a bit like this:

![](/images/posts/reducing-enumerable/img-73f7a546.png)

1. We start with an empty list and we push one into it only if it’s even. It’s not so we get back an empty list.

1. We start with an empty list, and we push two into it only if it’s even. Since it is we get back a new list containing two.

1. We start with a list containing two, and push the value three into it only if it’s even. It’s not, so we get back a list containing two.

1. We’ve run out of values and now a list containing two is returned.

## What is Select?

![](/images/posts/reducing-enumerable/img-1358976d.png)

To select is to use a function to decide what elements belong in a new list.

To select with reduce is to decide which elements to add to a new list.

## Onwards!

![](/images/posts/reducing-enumerable/img-94a1578a.png)

Now that Red had learned from Indigo, it was time to visit Violet, the master of Find.

[<< Previous ](/writing/2018/11/17/reducing-enumerablepart-two-chartreuse-master-of-map/)| [Next >>](/writing/2018/11/18/reducing-enumerablepart-four-violet-master-of-find/)
