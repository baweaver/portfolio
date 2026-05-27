---
layout: "post"
title: "Beyond Senior - Metric Obsessions"
series: "beyond-senior"
date: "2023-09-28"
categories: ["career", "staff"]
tags: ["career", "staff"]
description: "After a number of conversations over the past few years with several other engineers who have moved..."
---

After a number of conversations over the past few years with several other engineers who have moved beyond senior levels into staff and principal positions I've come away with a lot of insights, many of which have seen their way to Twitter or other conversations first, but now it's time to start collecting some of those stories into this new series: Beyond Senior.

What does it mean to go beyond the senior level in an engineering organization?

That's the question we're going to be looking at throughout this series.

## Metric Obsessions

Metrics, simply put, are measurements meant to provide insight. By themselves they present no issue, but at scale and at companies they can become something far worse.

A metric instrumented without an equal measure of discretion and wisdom will yield chaos and lead to number chasing over sound decisions.

This particular post is going to focus on metrics provided by tools like Code Climate Velocity, and how they are actively harmful to companies.

### The Dreyfus Model

So how do we go from metrics being harmless to becoming actively harmful? The metric is not the issue, how it's used and regulated certainly is.

Let's take a page from the [Dreyfus Model of Skill Acquisition](https://www.kaizenko.com/the-dreyfus-model-of-skills-acquisition/) to describe this phenomenon. While not perfect, it gives us a framework we can use to consider the impact of things like metrics.

It defines five levels on the path to mastery of a skill: Novice, Advanced Beginner, Competent, Proficient, and Expert. Each one of those levels additionally comes with a description of how people at that stage might behave:

* Novice
  * Rigid adherence to rules
  * No exercise of discretionary judgement
* Advanced Beginner
  * Limited situational perception
  * All aspects treated separately with equal importance
* Competent
  * Coping with crowdedness
  * Some perception of actions in relation to goals
  * Deliberate planning
  * Formulates routines
* Proficient
  * Holistic view
  * Prioritizes importance of aspects
  * Perceives deviations from normal patterns
* Expert
  * Transcends reliance on rules
  * Intuitive grasp of situations based on deep knowledge
  * Vision of possibilities
  * Analytical approach to new situations

Now a very important point in this model is that where one might be an expert in one field that _does not_ make them an expert in any other. Some might call me a Ruby expert (I disagree) but I would certainly be a rank novice in something like machine learning or AI.

### The Novice Problem

So why does that matter? Well by definition a vast majority of your engineers are likely to be concentrated more towards the novice end of the spectrum, and will frequently over rate themselves on this scale.

If folks in the novice to advanced beginner stages are known for a rigid adherence to rules and almost legalistic approach to them what do you think might happen if you give them a giant list of metrics?

Will they exercise discretion and nuance? Will they have the ability to prioritize based on that information? Will they make appropriate tradeoffs?

More likely, and what I've frequently seen in my own career, is that it becomes a numbers game very quickly. It becomes a target to be hit, a bar for promotion discussions, and a recognition system that rewards that very literal sense of rule following.

### Culture via Rule

What this results in is an approximation and proxy for culture building via rule and regulation. It's a fundamental mistrust of your engineers and their maturity, and even if potentially warranted it presents a very bleak view and incentivizes behaviors which will exacerbate the issue much further.

In the case of Code Climate it incentivizes engineers to push multiple PRs, to focus on explicit attribution and crediting, and to drive towards deliverables as quickly as possible to increase their numbers.

While this may help to get up towards senior levels it will be destructive for anything beyond when engineers should start focusing on planning, scaling, cross-organizational work, alignment, and overall systems thinking. You end up creating a wall that prevents the emergence of Staff+ engineers and actively punish those who think in those ways.

### Culture via Growth

So what might we do instead? Well if you're worried that your engineers aren't mature enough or aren't delivering, don't think in the right ways, or are otherwise not up to the task there's a very simple thing which should be done:

Grow them into it.

Get them mentorship, encourage your senior-most engineers to teach, get them into tasks designed to push their boundaries with a known support network, and provide them systems and frameworks to help them get there.

You can still use metrics, policies, and other such tools but the moment they become a goal to reach rather than a tool they become dangerous.

### Growth by  Growing

I have _rarely_ met an engineer incapable of growth, but I've certainly met several which refuse to do the growing. The irony is without growing other engineers you can never truly level beyond a certain point and be effective. Instead you become a liability and a knowledge silo.

To be blunt you cannot create a Staff+ engineer without mentorship. By definition these roles require you to work through others, to design systems larger than an individual, and that means you have to be understandable to others and have to be able to onboard them onto projects.

## Wrapping Up

The hallmark of truly senior engineers is autonomy and discretion. Metrics, when used in such a way as described above, disincentivize this growth and often times actively punish it.

I will not say that Code Climate Velocity itself is a bad tool, but I've certainly seen it used irresponsibly to the detriment of companies, and in many cases would caution against its use by folks who are not at a level of discretion to use it responsibly.

Growing engineers is hard work, and is not reducible to numbers on a screen. We have a responsibility to those we mentor and grow to do better than that, and that means not letting metrics become games to be played.
