---
layout: "post"
title: "Ozymandias on Rails. Cartography of a Ruin"
date: "2026-06-27"
categories: []
tags: ["ruby", "rails", "architecture", "legacy", "observability", "ozymandias-on-rails"]
series: "ozymandias-on-rails"
description: "You inherited a monolith with no map. This is how you start drawing one."
---

[Last time](https://baweaver.com/writing/2026/06/27/ozymandias-on-rails-the-pedestal-inscription/) we talked about why monoliths become ruins and what recovery looks like at a high level. This post is where the work starts.

You have a system with a thousand things wrong with it, and the question is which one to fix first. The mistake is believing you have to understand the whole system before you can act. You don't. You need to understand what's hurting, and you can figure that out with three things you already have access to.

But first, a discipline that decides whether you help or do harm in your first month.

## Don't fix what you don't understand

The instinct, walking into code this old, is to start cleaning up the parts that look worst. You open the god model and it is full of things that look indefensible. A column that stores a total the database could compute on demand. A callback that fires three writes on every save. A query with six joins and a comment that only says _do not remove_. Every instinct says to tidy this up, and tidying it up is how new people cause outages.

We look at code from the outside, beyond the original context it was written in, and see only the artifact. We do not know why they made the choices they made, the constraints they operated under, or the compromises they had to make to deliver. Joel Spolsky [wrote about this in 2000](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/): the reason old code looks messy is not that it was written poorly, it's that it has been _fixed_ over years, and those fixes are knowledge you will lose if you throw it away.

[Chesterton's Fence](https://www.chesterton.org/taking-a-fence-down/) applies here. A reformer finds a fence across a road, sees no use for it, and wants it gone. The wiser answer is that if you cannot see the use of it, you are exactly the person who should not remove it. Come back when you can explain _why_ the fence exists, and then you may have earned the right to take it down.

Our first job is not to fix, but to _understand_, and only through understanding can we discern the difference between something which only appears to be on fire, and something which requires more immediate intervention.

## The loudest fire is rarely the worst

So you open your error tracker, and start working from the top, but that raises a critical question: What are we sorting by?

The top of the list is frequently whatever generates the most noise, the loudest issue, but being loud does not necessarily equate with being urgent. Our job is to distinguish between what is signal and what is noise, and I have seen many cases in which the 100th item down the list reflects a business critical outage costing real money while the top item is cosmetic.

When we sort by count we lose nuance on what each failure actually costs the people it hits.

## Most fires never reach the error tracker

The error tracker shows you code that throws, but the most expensive problems in an old system are often silent there. A slow checkout throws no exception, it works eventually, but it loses the people who give up waiting and not one of them files a bug. Latency is a fire that throws nothing, and the people on the slow path are often the ones in the middle of paying you.

Saturation grows slowly enough to miss. A heavy query ties up database connections at night, finishes before morning traffic, and nobody notices until the system grows enough that one night the connections run out while people are still trying to use the site. The warning was in the logs the whole time, a small cluster of timeouts at the same hour getting wider each week.

The worst category surfaces nowhere at all: a total comes out wrong, a row is missing, a balance drifts. No exception, no alert, and the first you hear of it is a customer who noticed before you did.

Three instruments are already in front of you: the error tracker for things that throw, the logs for the slow and the starved, and the support queue for damage that shows up nowhere else. Widen what counts as a fire to anything measurably hurting the system or the people using it, whether it throws or not.

## You cannot rank a signal you do not trust

The wider list brings its own problem: most of what is on it is noise, and noise does more than waste your time, it teaches you to stop looking.

Most alerts on an old system fire on causes rather than on harm. Processor over eighty percent, free memory under ten, a queue past some threshold drawn years ago. A processor spike might be a nightly backup, garbage collection, or a circuit breaker doing its job. The alert cannot tell which, so it fires every time, and by the third week you have learned to wave it away. That habit is the danger, because once waving off alerts is normal, the one alert that matters arrives to the same shrug as all the rest.

Before ranking, cut the list down to signal you would act on. An alert earns its place if it points at something a user feels, if there is something you would do in response, and if it is telling you something you did not already know. Group the duplicates, silence the things that recover by themselves, and keep cutting until what remains is pain worth a human's attention.

## The same fire burns different people

Now you have a list of fires worth ranking, and the temptation is to rank it with a single number. But "hurts" is not one quantity, and one number blends different kinds of pain into something that describes none of them.

Take a nightly Sidekiq job that builds finance's revenue export. To a customer it is close to invisible, a few slow pages in the small hours. To on-call it is a familiar 2 a.m. page. To finance it is the reason the monthly close slips a day whenever the job dies halfway through. One job, three different sizes depending on who you ask.

So keep the kinds of harm apart. Four cover most of what matters: what the customer feels, what it does to revenue, what it costs the engineers who carry it, and what it does to the business beyond that. The first two are pressure you feel now. The second two build over time. Holding them apart is what lets you tell a customer emergency from an engineering one, instead of averaging them into a score that names neither.

## Start with a list

Step zero is getting access to the three places fires show up: the error tracker, the application logs, and wherever support collects complaints. If you do not have all three yet, ask. Being new is the best reason there is to ask for access.

Then open a document and begin a list, one row for each fire you can name. Walk the three places one at a time. From the error tracker, take the handful of error groups that show up the most and skip the ones you know heal on their own. From the logs, note anything slow or anything that times out in clusters. From support, pull the complaints that repeat. Eight rows is enough to start.

Now put rough numbers next to each row and let go of the idea that they have to be right. For reach, a guess from what you can see is fine. For severity, ask: if this happened to you as a customer, would you shrug, grumble, leave, or call your bank? Those four reactions are your tiers. Do the same for the other three kinds of harm. An estimate you can revise beats a number you never wrote down.

## A model you can run

This is one shape for doing that weighing, not the shape. It's a starting point you can copy and fill in with your own fires. The numbers that come out are not answers, they're a way to make the argument visible so your team can disagree about the weights instead of the priorities.

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/triage.rb", segment: "triage_model") %>

The tiers jump by about a factor of ten at each step on purpose. Harm is not linear, and a flat one-to-ten scale would let a stack of harmless blips outweigh a single corrupted payment, which is the mistake the whole exercise exists to avoid.

Here's what it looks like filled in with a hypothetical month:

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/triage.rb", segment: "triage_example") %>

Run it on a month from a ticketing system and rank it both ways:

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/output.txt", segment: "triage_output", lang: "text") %>

Neither of the two worst fires is an exception. The slow checkout and seat map lead because they cost customers the most, and both are absent from the error tracker. The double-booking lands fourth on raw arithmetic but carries the escalate flag because it cannot be undone. The loud filter error that owned the top of the error tracker comes sixth.

The two rankings disagree about reporting saturation: seventh on what customers feel, second on what engineers carry. That disagreement is the reason to score both.

## Where this points

You came in with no map. Now you have one: a ranked list of fires, scored by who they hurt and how badly, with the noise cut away.

Run this exercise a few times and something shows up that the ranking never names directly: the fires that keep landing near the top tend to live in code that everything touches, that changes constantly, and that no single person or team owns. Part two follows each fire from the symptom you can see down to the line you cannot, and the trail keeps ending in the same place: unowned code.

## Further Reading

- ["Ozymandias"](https://www.poetryfoundation.org/poems/46565/ozymandias), Percy Bysshe Shelley (1818)
- [Chesterton's Fence](https://www.chesterton.org/taking-a-fence-down/), G. K. Chesterton (1929)
- [Things You Should Never Do, Part I](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/), Joel Spolsky (2000), on why old code looks bad and what you lose by throwing it away
- [Working Effectively with Legacy Code](https://www.informit.com/store/working-effectively-with-legacy-code-9780131177055), Michael Feathers, the argument that code without tests is what makes a system legacy
- [Your Code as a Crime Scene](https://pragprog.com/titles/atcrime2/your-code-as-a-crime-scene-second-edition/), Adam Tornhill, mining version-control history for hotspots where change frequency and thin ownership overlap
- [Observability Engineering](https://www.honeycomb.io/observability-engineering-oreilly-book), Charity Majors, Liz Fong-Jones, and George Miranda, the distinction between monitoring and observability and the core analysis loop
- [Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/), Google SRE, the four golden signals (latency, traffic, errors, saturation)
- [The RED Method](https://grafana.com/blog/the-red-method-how-to-instrument-your-services/), Tom Wilkie, rate/errors/duration for request-driven services
- [The USE Method](https://www.brendangregg.com/usemethod.html), Brendan Gregg, utilization/saturation/errors for the resources underneath
- [DORA metrics](https://dora.dev/guides/dora-metrics/), the research connecting delivery performance to clear ownership
