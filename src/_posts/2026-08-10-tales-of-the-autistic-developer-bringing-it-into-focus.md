---
layout: "post"
title: "Tales of the Autistic Developer - Bringing It Into Focus"
series: "tales-autistic-developer"
date: "2026-08-10"
categories: ["autism", "mentalhealth"]
tags: ["autism", "mentalhealth", "adhd"]
description: "How I process problems: hyperphantasia, rotation, the click moment, and using AI as a variance accelerator for a brain that generates more ideas than it can hold."
---

For those who don't know me, I'm autistic. I've been a developer for north of two decades now.

I didn't find out I was ASD until 19, and didn't reconcile with that until years later. These posts will be a combination of advice I've given to those who are like me, as well as a letter of sorts to my past self who could have used a lot of it.

I write these posts in the hopes that someone like me will find value in knowing a very simple and very important truth about ASD:

_You are not alone, and you are loved._

## Bringing It Into Focus

If you've seen me at work you might have seen this play out, and I fully agree it probably looks ridiculous.

I have music blasting, headphones on, I'm pacing around the room or wandering through my home, hands conducting some symphony only I can hear, and if you're trying to talk to me I will not register a single word of it. I'm somewhere else entirely, and what I'm doing there is trying to find a solution to something I'm particularly stuck on today.

This post is about how I process those problems, because it took me forever to understand that the way I think and process isn't remotely like how other people do it, and longer still to stop apologizing for it. End of the day I am who I am, and I've come to accept that.

## The Image Is There

Something I learned recently was that there was a name for how I visually process information. I don't remember where but I saw this test about visualizing an apple and how some people have no ability to form that image in their minds. I've since seen it all over the place, sure, but it always confused me because I'm able to fully model an apple in front of my face right now. Really, several apples, different types, maybe a few bites out of them or some dirt or dings. I can rotate it, send it flying, almost physically _feel_ it in my hands, I can smell it and I can tell you what it tastes like too.

You see I have hyperphantasia, which when connected with autism gets interesting. My senses are already turned up to 11 at any given time, and hyperphantasia means I can freely manipulate them to project visions into reality. If you've never heard the term it means that my mental imagery is so vivid it can be indistinguishable from the thing being present right in front of me. If I wanted to I could even project myself back to my childhood home with the exact carpet, paint, smells, furniture, all of it like it was back in the 1990s. It's not _quite_ photographic memory as much as snapshots of particularly strong experiences through my life I can summon on demand.

I never knew there was a name for this until very recently, and I definitely didn't know it wasn't something everyone could do. For years I assumed when people asked me to picture something they meant in full high-definition right in front of my face. Turns out that wasn't the case.

Why does this matter? Well when I'm working on a hard problem doing everything above? I am quite literally looking at it in front of my face.

I remember back when I was in school I had seen the first Iron Man movie with all the screens whizzing around and rearranged with a gesture. Everyone else saw a cool sci-fi UI/UX. Me? That's how I process information. I construct representations of systems in my head from components to relationships, through to the data flow, constraints, all of it flying around in my head where I look at it from different angles until something hits me.

So why the music and theatrics? They're not distractions, in a way they're grounding mechanisms while I keep rotating things in my head.

## Rotation

I do not process things linearly. It's not a step-by-step process I could talk someone through as much as it's like looking for the perfect angle, focus, lighting, and composition for a picture.

I know the image is there, hiding. I can see the general shape, some more blurry than others, but I know it's there and I don't quite have the right settings to capture that photo yet. The pieces haven't clicked so I keep making adjustments, rotating things, changing my angle of approach, zooming or panning around to see how it relates to the bigger whole.

Some solutions come to me immediately, I can see it at a glance, and the more experienced I become the more frequently that tends to happen. Other times? Well that can take days or weeks, sometimes months, and I'll be background processing that problem while the rest of my life continues on top of it.

When that solution comes it's like a bucket of ice water to the face. You might see me go wide-eyed and start grinning like an idiot, because I now know with almost complete certainty what my next move is. I go from 0 to 100 and finish at paces that look inhuman from the outside because I've already pathfound my way through the hard parts, I know the solution, I just need to capture that final picture and execute.

Granted, sometimes that click is wrong, and I end up hitting a brick wall at mach speed. It happens, though I may find it annoying enough to hang up for the day and go on a walk to get coffee and let it simmer in the background for a bit longer. It's still an iterative process and honestly it's no fun if I get it right the first time, a good problem is one that's going to force me completely reorient my thinking.

## The Packwerk Inversion

At one company we had a tool called Packwerk that drew boundaries around areas of code and assigned ownership to teams. Part of that ownership meant curating a public API, a front door if you will, that consumers of your code should enter through. When they fail to do that? That's what we call a privacy violation, a place where another team reached into your private code that they should have no business touching.

The problem is that the tool focused, by default, on blaming consuming teams for reaching into code that they didn't own and told them to go find the front door instead. Well that's great, but if the team _has no front door_ how do you suppose they might do that? They aren't empowered to make one, and whatever front door they might make may not be what the producing team wants.

That doesn't exactly create good incentives to write clean code, it creates incentives for very localized changes that become a mess in aggregate.

The tool became a prescriptive annoyance that either resulted in bad APIs or teams fully ignoring it. The counts weren't going down, the teams hated it, and everyone felt stuck.

I sat with this one for weeks, thinking that something was fundamentally wrong here. The metric was flawed and leading to bad outcomes, but how might I approach fixing it? I took a step back, looked at the problem, and started to ask questions from different directions. If the metric is flawed what one might be better? If consuming teams have no empowerment to fix things and when they did it led to bad outcomes who should own it? What do producing teams actually want from this tool? What would produce the best code that has full ownership and understanding?

Eventually it clicked: the tool was fundamentally backwards on a codebase with little to no public APIs, so we flip it upside down instead.

By flipping from consumer-orientation to producer-orientation everything fell into place for me. Producing teams could now clearly see what other teams were calling into their private code, how, what shapes they were using, how those grouped together, and in some cases got a clear understanding of what public APIs were missing. They had the context necessary to understand, the ownership to make the changes, and the empowerment to land them. Instead of a prescriptive linter leaving code review comments that no one could act on it became a holistic view of ownership that empowered owning teams to curate better public APIs.

It was eventually open sourced as [QueryPackwerk](https://github.com/rubyatscale/query_packwerk).

That solution came from rotating the problem in my head until the frame shifted a full 180. I wasn't looking for a better answer on how to stop consumers from violating code boundaries, I was looking for why the entire question just felt fundamentally wrong to me, and eventually the image snapped into focus and I developed QueryPackwerk to codify that into a tool others could use to see the same thing I did.

## Background Processing

Not all of this is a synchronous process I can run on demand, and even if it is it doesn't mean I can find a solution in the moment. Some of these ideas even sit in the back of my head for weeks or months at a time, running in the background, until some new piece of information provides just the right hint to make it all snap together.

I'll be dead asleep, on a walk, in the shower, or lord knows where else and it hits me like a freight train. In that moment I can see the entire solution in front of my face, and I need to get it out of my head _right now_ and onto paper, a screen, anything, before it flits away into the aether not to be found for another month. That's part of the reason I tend to have a pen and notebook on me at any given time, and why my corpus of writing at work tends to exceed thousands of pages a year, and that was measured _before_ AI came into the picture.

While I lead with the fact that I am autistic I am also ADHD, which means my brain generates ideas at a rate that vastly exceeds my ability to evaluate them in real time. Hundreds a day, flying out at random intervals, most half-formed and most of which are probably awful, and they decay every second I don't capture them. For years my bottleneck was having enough time to evaluate all of them. Sure, I could generate hundreds of angles around problems, but I could only seriously look into five or so before my attention span clocked out for the day to focus on something like what neighborhood I might wander around sketching this weekend.

## AI as a Variance Accelerator

AI is complicated. I don't intend to litigate that here, but for me it has dramatically changed my process.

If you knew me professionally before AI I'd grab anyone I could get to listen for more than five minutes to play ideas by. I'd grab engineers for coffee, find them in hallways, dump weeks worth of context and ask them to poke holes. It worked occasionally but it was heavily gated by people's time and patience, and by the sheer amount of context I'd drop on the unfortunate soul who I found first. Unsurprisingly the friends that were the most keen to listen happened to _also_ be autistic, but that's another matter.

Now? Now I can give all of those half-baked ideas to an AI to farm them out, I can ask for citations, proofs, disproofs, alternative angles, evidence, and more. Is this idea viable? What breaks it? What am I not seeing? I can drill into all types of different angles, and even if the AI is only 60-80% correct that's more than enough because I _do not need correctness_, I need variance. I need that one last piece, that last rotation, the focus settings that are going to unlock the puzzle and lead me to the real solution.

My entire thinking process is heavily dependent on spark or "AHA!" moments. AI is a spark generator, it's not particularly surprising that we tend to get along even if those sparks sometimes light my beard on fire.

It maps to the way I think, to my ADHD, in a way that almost feels custom-built. When you have hundreds of ideas with no way to contain them and a brain that wants to evaluate them all at once with an attention span on the order of seconds to minutes having a place to context dump is incredibly useful. In 30 seconds it can provide me answers to 100 questions by the time I might have managed to get through 4-5 of them and help me see which ones are actually worth further direct attention, and which ones I should throw out without wasting hours on them.

Mind, that does not mean that I agree with AI or take everything it says at face value, I still do my own homework on anything it produces. Remember I am not after finished solutions, I am after variance, and AI is _really good_ at that part of the equation. The rest? Well... it has some work to do there.

## What This Looks Like From Inside

By now you might imagine this is a pristine choreographed savant-grade process like that [card counting scene in The Hangover](https://www.youtube.com/watch?v=DeazgPwP3D0), but I assure you I'm not a gambler (though I have been called Rainman in the past), and it's definitely not as clean as that. It's messy, exhausting, and I probably look like I've lost my mind to anyone watching. I pace, mutter, conduct, stare holes through walls, and am near completely oblivious to anything happening around me at the time. The music is there to make sure I don't pick up on conversations across the way, and the pacing is because I am near incapable of sitting still while my brain is moving as fast as it does during one of those sessions.

For years I tried to be "normal" and think the way other people did. Sit still, write it all down, make a diagram, break it into steps, and pay attention in class. Works fine for small problems, but for anything bigger that model breaks down quickly for me. I'm not a linear thinker, nor a linear learner, which probably explains my GPA back in school and why most teachers and I did not particularly get along.

It took me a long time to stop apologizing for this. It's how my brain works, and it works well when I give it what it needs.

## Wrapping Up

This is a view into my head. Perhaps it represents you, or someone you know, but each experience is unique as the person who has them. Even earlier this evening I was talking with someone about this phenomenon who was also autistic, and I'm always surprised by how much some of us have in common.

If you process problems by holding them in your head and rotating them until they resolve, if you need movement and sound to stabilize the workspace, if your ideas come faster than you can evaluate them and decay if you don't catch them in time, you're not broken and you're not weird. Or maybe you are weird, but it works, and that's what matters.

I know I'm weird and I'm pretty ok with that.
