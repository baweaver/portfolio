---
layout: "post"
title: "AI Didn't Create These Problems. It Just Stopped Routing Around Them."
date: "2026-05-27"
categories: []
tags: ["ai", "leadership", "ruby"]
description: "Every guardrail we need for AI is a good practice we should have already been doing. AI exposes the systemic gaps that experienced developers have been quietly routing around for years."
---

I've spent the better part of the last few years using AI heavily at work, and there's one very interesting thing that I have observed in all of this time:

Every single guardrail I've had to put in front of AI to keep it on track, make it more productive, more predictable, and less risky? They're all things we should have been doing all along.

Testing, clear ownership, up to date documentation, deterministic validations? None of them are new, none of them are particularly controversial, and yet the moment that you let AI take the wheel you find out exactly how much of it was missing.

## The Routing Problem

If there's one thing AI is _exceptionally_ good at it is finding the shortest path to achieve what it wants, often times right through the flower bed and over the vegetables.

Sure, to you it's obvious, but to AI? Not at all.

As we become more experienced as developers a lot of problems become background noise we route around or ignore entirely. It happens so naturally that we don't even notice when we do it, as much as we observe that there's something which is a distraction, and an actual problem to be solved behind it.

Remember that callback hook from 3-5 years ago that validates a child model's ordering? The one that starts slowing down if you happen to update more than say 30 records at a time? It was never documented, never really commented, no linter was going to catch it, and quite honestly you don't even remember who wrote it. Maybe it was you? I've done that one a few times.

Point being that thing blows up in production once and you're going to remember from that point on not to do that again. If you're lucky you learned that lesson from someone else instead of running into it yourself, but either way it's in your head and now you route around it every time you see it in the future.

That works great for humans, but AI doesn't have that type of memory. It will walk straight into that hook or even write a new one, trigger a deadlock, and now you're getting paged at 3AM trying to figure out what in the world went on.

If it were a human we would not blame them, we would (and should) ask how our existing systems failed them to allow an outage like that to make it to production. We don't call them stupid or mock them or any such thing. We learn, we adapt, and we move on. Hopefully we also make sure there's a "never again" guardrail in place as well, because "don't do that again" is a hope and a prayer with a shelf life as long as that person and the people around stay at the company.

That's the pattern. The stale documentation that only three people know how to update, and the other three left two years ago. The test suite full of stubs that tests a non-existent system that was refactored away three years ago. The implicit knowledge about which 3P services can and cannot handle above a certain amount of load and require aggressive caching. All of these were fine when experienced humans were the only ones navigating the codebase, but the moment that something without that institutional memory starts committing bets are off and every gap is now a live wire.

## AI as Chaos Engineering

There's a certain irony in all of this that I can't help but find amusing. Years ago Netflix invented this novel concept called the [Chaos Monkey](https://netflix.github.io/chaosmonkey/), a tool that would randomly nuke a server from orbit. It wouldn't tell you what, where, when, or even why as much as something would die and you had better hope that you designed things well enough to self-heal or it's going to be a long day.

Why bring this up? Because AI is the best chaos engineer we've ever had. It finds gaps and holes that you would have never considered. It squeezes through cracks in the side of a building where the paint chipped at a certain angle at a particular hour of night when the moon hits it in a way that leaves everyone involved doubting their sanity and asking how in the world this happened.

AI is stress-testing our assumptions about how code should be written, what documentation needs to exist, and whether our systems are actually as robust as we think they are (they're not.)

The important part is how we choose to respond to that. Do we behave like systems thinkers who consider how systems failed, or do we point fingers and blame? When production blows up a good engineer will ask what failed in this system that allowed this particular category of error to happen. We do not lecture about how a developer must not have been paying attention or how bad they are at their jobs. The same frame applies to AI: It's going to make mistakes. We know it, so what are we building around it to make those mistakes identifiable and survivable?

## Our Tools Weren't Built for This

One problem we run up against is that our tools were not built with AI in mind, by and large. They were designed for a different time with a human reading the output and figuring out how to respond to it.

Take RSpec, for instance. AI runs your test suite, gets failures, and needs to figure out what is wrong from that information. How does it do that? It runs the suite, tails/heads/greps the output to condense it, and then proceeds to run it 5-6 more times with different incantations of those commands to get the correct output it wants, with every run taking multiple minutes in some of the worst cases.

The problem isn't RSpec or how it was written. It was designed for humans who scan output, pattern match visually, and can tell what failures might be related. AI can't do that, at least not efficiently, so it tries to limit and focus information. What it needs is structured output: JSON that lists failures, where they are, what the error was, the error message, maybe even some groupings of common patterns. It can read from that like a cache and diagnose issues in one pass instead of several while you're trying to get the agent to knock it off and re-focus.

Same with Rubocop, same with Minitest, same with pretty well every developer tool that outputs human readable text with the expectation that a human is on the other end to interpret it. They work great for humans, but they're not built for an agent that needs a focused and clear view of exactly what failed to help it to figure out what to do about it.

I've started telling all of my AI tools to output JSON, and then re-parse that for any new information, and then started systematically disallowing raw commands from being run without clear wrappers that guarantee that structured output. That single change has made me substantially more effective at getting AI to actually diagnose issues instead of repeatedly saying "let me try again." Is it perfect? No, but it's a definite step, and perhaps the foundation for a new way of thinking about these tools.

Now I'm not criticizing these tools, not at all. They were built for their moment, and they're great at what they do, but that moment has shifted. In this new world we need to start asking what agentic modes might look like for RSpec, for RuboCop, and for our entire developer toolchain. How do we give AI the context it needs, at the right time, to (hopefully) do the right thing with that information.

## The 80/20 Split

When developing tooling with AI, _especially_ for anything spanning more than 10 files, I like to use an 80/20 rule: 80% deterministic code, 20% AI glue for the finnicky details that would take hours to get right.

The deterministic part is everything we can reasonably validate, type check, lint, and test without ambiguity. Contracts, schemas, static typing, feature flags, staged rollouts. All the boring infrastructure that makes systems substantially more predictable, and more tolerant to failure, and things will _always_ fail somehow, some way.

> **Static Typing in Ruby**: As an aside, the static typing debate in Ruby while valid does not hold well in the era of AI when any additional guardrail may be the layer that stops it from doing something particularly naughty. I've gotten substantial leverage out of Sorbet, and would certainly encourage its use in any large codebase which has AI running about.

The remaining 20% is where I find that AI really shines, the parts where you need flexibility and judgement rather than firm rules. Summarization, routing, classification, the stuff which would be incredibly difficult to implement deterministically but where a probabilistic answer is close enough to provide tangible value.

When viewed from this angle AI becomes another tool with a very specific failure mode that we can put guardrails around, and progressively enhance them over time as we learn more. The really nasty failures happen when people try and make it 100% AI with no deterministic backbone. That's when you see user data leaking, tokens committed, bank accounts emptied, or other catastrophic failures.

## The Gift in the Mess

Now I'm not going to tell you that you can 100% guarantee AI will produce good output if you only write just a _few more_ guardrails. That world does not exist, and we should not pretend it does. There are things it can't fix for like when engineers leave with context they never wrote down or shared, architectural decisions which were never written down which are no longer relevant because something finally got upgraded downstream, implicit contracts between services that no one ever wrote down because someone always knew what they were and was available on Slack almost immediately whenever something went wrong.

Does that mean that we should not try? No, quite the contrary. A lot can be fixed, and AI is forcing us to fix these things faster than we would have otherwise. Documentation that gets written because agents need it, tests that are made meaningful because stubs subtly lie and diverge from the truth over time, ownership that gets clarified because "ask Steve" does not work when Steve is an LLM.

But here's the fascinating part: Every gap you fix for AI is also a gap that a human may very well have fallen through as well. That new grad who doesn't know any better, the senior who transfers and has never so much as written a single line of Ruby, the contractor that has a deadline to meet. These problems were always here, AI just made it _substantially_ harder to ignore them.

One thing we used to do at Square when we had a new team member on the API and SDK team was that we'd ask them to build something with our product, and during that time we encouraged them to write down anything and everything that made them go "WTF!" in what was then dubbed a "wtf doc." The results after every new hire did this is we'd find new gaps, new surface areas that were nowhere near as clear as we had thought, and potentially several new ideas we could iterate from.

AI is, in a way, our collective WTF doc that forces us to reconcile with the gaps in our systems at a speed and scale that we never thought possible.

## Where This Goes

Just as teams thrive when they treat failures as systemic issues rather than personal or moral ones, so too will AI systems thrive. Those that ask "what was missing from our system that allowed this to happen?" rather than "AI is bad and we should not use it" will get far better results from it.

Not every problem is going to have a nice clean answer, and we certainly can never close every gap, but the practice of looking at systems honestly? That's just good engineering, and that does not change with AI. If anything, the need is now greater than ever to focus on creating operationally excellent systems that are resilient to failure, or failing that really danged quick to roll back from it.

The need was always there, the difference is that AI is making it a problem we cannot ignore.
