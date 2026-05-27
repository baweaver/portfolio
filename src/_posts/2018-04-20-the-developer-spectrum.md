---
layout: "post"
title: "The Developer Spectrum"
date: "2018-04-20"
categories: []
tags: ["ruby", "community", "programming"]
description: "A playful taxonomy of developer archetypes represented by different colored lemurs and their programming philosophies."
---

What started with a “Black Magic” Lemur I frequently dressed in a red starry wizard robe ended up expanding a bit after a joke from a good friend and coworker:
> What about the other colors of Lemurs?

What indeed. So that left the task of deciding what the other colors would even look like, and if Red were considered very “Ruby-esque” what did that make the others?

We ended up coming to a list of themes aligned with each of the colors, and the notion that most developers fall under somewhere between two and four colors:

<iframe src="https://medium.com/media/62bba96b1c993eab98c9fe8bca2f7ac7" frameborder=0></iframe>

Originally this started with just Ruby, but ended up spanning a few languages and eventually ended up becoming a bit of a game to see where people and languages would fall on this little Lemur spectrum.
> As is inevitable to happen, as someone who aligns Red / Blue / Indigo, I don’t really grok some of the other ideals fully. This list is made in fun, best not to take things too seriously.

## Red — Implicit and Dynamicism

Red, of course, being related to Ruby heavily favored the idea of being very dynamic and loving the idea of being implicit rather than explicit in your code.

Very often this can be confused with black magic and hackery, especially when used without caution.

A particularly new Red would favor ideas like heavy metaprogramming, monkey patching, and anything they deem to be sufficiently clever. Everything is about learning new language tricks and looking smarter while doing it.

A more advanced and seasoned Red tends to leverage the flexibility of their tools to create more expressive languages and tools that are easily understandable, appreciating the potential pitfalls of implicitness.

A zealot Red would claim that explicit language and staticness are barriers to actually getting things done and will abhor any language or tool which enforce them. Their code can be confusing, littered with clever tricks and domain specific languages that only make sense to them and how dare you not recognize their brilliance. No one can understand their code after it’s written, often times including the zealot. They can destroy teamwork by siloing knowledge behind clever tricks.

## Orange — Freeform and Pick-your-own

Oranges love freedom. They want their own everything, the ability to pick and choose what they work with and how it all works together. Frequently this comes up in React and Javascript where a lot of the community thrives upon extreme flexibility and modularity.

A newer Orange will always be experimenting and upgrading everything, frequently to the detriment of actually getting real work done. They can get in a fantasy land apart from reality, and projects that should take two weeks end up taking two months because they ended up rewriting all of it in (insert new framework here).

A more advanced and seasoned Orange knows how to make flexible software that can adapt to a variety of circumstances, easily interchangeable and reasoned about.

A zealot Orange will insist on customizing absolutely everything, tuning things to death when they have little to no real impact. They can waste days, weeks, and even months spinning their wheels on micro-optimizations and switching out every library the second something “better” comes along.

## Yellow — Cutting Edge and Moving Fast

Yellows love speed. They want the latest, the greatest, and the fastest of everything. This can be seen very frequently with developers who tend to upgrade to alpha versions and test brand new tools and languages, especially in production.

A newer Yellow would frequently upgrade at will, wanting a new feature, and very well may end up tanking production because of some obscure bug that would have been caught with some more testing and planning.

A more advanced and seasoned Yellow is a trail blazer. They test, document, and herald new tools. Frequently Yellows are the types that write books and really evangelize the new thing, giving valuable insight to other developers as to what to try next.

A zealot Yellow will break everything in the way of them getting the next new toy. They care little for testing, stability, or anything else as long as they ship the new feature they want to production. They can wreck a production database faster than you can say Robert'); DROP TABLE STUDENTS; --.

## Green — Balance and Pragmatism

Greens love balance. They thrive on well defined standards and trying to bring balance to teams. Frequently Greens will be found in management, product, or tech lead roles as they try and juggle a myriad of concerns to get to a reasonable solution.

A newer Green will be obsessed with finding the middle ground, even though there’s likely not one in all cases. A true moderate at heart, but lacking the pragmatism that grounds a Green in productivity.

A more advanced and seasoned Green is an equalizer. They can take strong opinions from all sides and reconcile them into more pragmatic solutions that are tailored to each team and problem they face. A good Green can make order from a chaotic team.

A zealot Green will insist on a neutral solution that may make no sense, but will pathologically push it as an absolute. Their sole purpose is to find the absolute middle ground, even if that middle ground is the completely wrong solution and sacrifices any advantages to be gained from either of the opposing views.

## Blue — Stable and Tested

Blues love software that’s been battle tested, stable to its core. They thrive on consistency and reproducibility. Frequently you can find them as System Administrators and core maintainers of common tools.

A newer Blue will insist on things staying the same as much as possible, frequently butting heads with a Yellow and getting into arguments. They can be hesitant and sometimes hold back teams from good upgrades for relatively minor concerns.

A more advanced and seasoned Blue can smell a segfault a mile away. They’ve seen some stuff, and they version check pretty much everything. Meticulous to almost a fault, a good Blue is the backbone of your organization, making sure you’re stable for years to come.

A zealot Blue will lock down any upgrades whatsoever. There are no other languages than RPG and COBOL, and they work just fine. We don’t need none of that fancy new C++ stuff, that’s what the reckless newbies use.

## Indigo — Order and Patterns

Indigos love order. They thrive upon established order and repeatable patterns. Frequently you can find them using “batteries included” frameworks and loudly saying that something “just works” in any argument. It’s not surprising to find a few architects here.

A newer Indigo can become obsessed with shoehorning every new pattern they learn to every problem they can find. They’re a hammer after everything that remotely looks implements CylindricalWithRoundHead. Doesn’t matter if it makes sense, it needs a pattern and it’s getting applied.

A more advanced and seasoned Indigo can create frameworks and tools that are well documented and follow a very specific order. Patterns become a way of making complicated decisions into obvious choices to speed up work and build truly massive systems. A good Indigo can take a complicated problem and break it into pieces, making it look simple and obvious to any onlooker.

A zealot Indigo will be a card carrying Gang of Four member, creating such monstrosities as AbstractSingletonProxyFactoryMapperBean that would even scare a more chaotic Red. They take patterns to an extreme, abstracting sense away along with any duplication they might have fixed.

## Violet — Explicit and Static

Violets love explicitness. They thrive on clear and present language and established formalisms. Frequently you can find them as Data Scientists, Functional Programmers, and anyone who perks up when hearing the phrase Kleisli Composition.

A newer Violet can struggle to express their thoughts in true formalism, making solutions more complicated than they need to be. They can also be explicit to an extreme fault, using 100 lines when 10 would do.

A more advanced and seasoned Violet can make even the most complicated and abstract of concepts into clear, explicit writings. They can bring order from chaos, forming reality from terrifyingly abstract concepts. A good Violet can quantify and express much of anything, weaving together the most stubborn sources to get answers.

A zealotous Violet will never, ever, touch a dynamic language. If you were to lock them in a room with a particularly fervent Red it would end exceptionally poorly. They refuse to see the value in anything that’s not explicitly written, and can end up making quick problems into veritable nightmares.
> We had joked that a Violet Rubyist is a Java developer who got tricked into a Rails job when coming up with parts of this list. The thought is still amusing to me at least.

## Wrapping Up

So is this a be-all-to-end-all list that absolutely categorizes you forever and bounds your fate, amen? Is this the next Facebook sorting quiz? No no, it’s just a Rubyist drawing Lemur cartoons sharing a few of his crazy ideas, and if you found them entertaining then all the better!

The question is though, what colors are you?

Personally (and not surprisingly) I’m a Red, Blue, and Indigo. A Ruby / Rails / JS dev who used to be a System Administrator.

Enjoy!
