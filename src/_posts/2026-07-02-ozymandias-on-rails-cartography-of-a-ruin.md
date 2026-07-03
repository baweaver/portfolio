---
layout: "post"
title: "Ozymandias on Rails. Cartography of a Ruin"
date: "2026-07-02"
categories: []
tags: ["ruby", "rails", "architecture", "legacy", "observability", "ozymandias-on-rails"]
series: "ozymandias-on-rails"
description: "You inherited a monolith with no map. This is how you start drawing one."
---

[Last time](https://baweaver.com/writing/2026/06/28/ozymandias-on-rails-the-pedestal-inscription/) we covered why monoliths decay and what the Rails ecosystem specifically gets wrong at scale. This post is where the practical work starts.

One of my favorite quotes at work is "when everything is on fire, nothing is on fire." At a distance everything looks urgent, everything looks on fire, and the mistake I see made is that people try and take on the entire thing at once. Your job, at leadership levels in engineering, is to triangulate on the five problems that matter today and make them go away.

More specifically your job is that of a cartographer, the map maker. You draw a map and chart the course for engineering and where people should go to most effectively reach their destination of a more stable system. In that job you're fortunate to have several tools and resources at your disposal, and if you don't quite know what those are yet that's what this post is going to cover.

Richard Cook's [How Complex Systems Fail](https://www.researchgate.net/publication/228797158_How_complex_systems_fail) features a provocative statement: complex systems run in degraded mode. At any time there are a series of ticking time bombs and latent failures just waiting to go up, and the only reason they don't are a series of redundancies and workarounds which patch over that fact. That means figuring out which one of those time bombs is most likely to go off, how big the blast radius might be if it does, and what that means to the customer and the business respectively so you can drive necessary investment to contain it.

One lesson from the last article that bears repeating: do not fix what you do not understand. Repeat that, live that, memorize that, because it will pay dividends. [Chesterton's Fence](https://www.chesterton.org/taking-a-fence-down/) should be printed, framed, and featured on every desk. That column you think wasn't being used? Turns out it was holding up an executive team financial report that runs monthly. That callback that you're deleting? It was the only thing keeping your search index functional.

Static analysis may give you ideas about what to change, but production data is what tells you which fences are doing a job and which ones are in the way. Error rates, latency distributions, support tickets, on-call pages, and the complaints people make in Slack when they think nobody with power is listening: those are the signals that separate a fence worth keeping from one worth tearing down.

## The loudest fire is rarely the worst

How do you figure out which fires to focus on? Not everything is worth your attention, nor will it necessarily improve anything if you fix it. The question is how to separate what's costing you money or trust from what's costing you nothing but noise.

[Nate Berkopec](https://www.nateberkopec.com/) and the folks at [Honeycomb](https://www.honeycomb.io/) have shaped how I think about this: any optimization that isn't driven by observed production measurement is premature. You cannot rank what you have not measured, and you cannot prove a fix worked without a before and after.

The problem with most observability tools is that the top of the list is whatever happens to generate the most noise, and the more noise the more likely you are to ignore it until you're in a retro admitting that one buried signal would have prevented the last outage. Not everything is urgent, so how do you pan the gold from the dirt?

Sorting solely by count loses us critical nuance on what the cost of each failure is for our users. The [Google SRE book](https://sre.google/sre-book/monitoring-distributed-systems/) draws a distinction here between symptoms and causes. "What's broken" is a symptom; "why" is a cause. Error trackers sort by cause (this code had an exception) rather than by symptom (this user gave up because our cart was slow). A single cause can generate thousands of alerts with no real harm, and a single symptom can destroy user trust without generating a single alert. What you want is to sort by severity of symptoms, not loudness.

At one company, years ago, there was a justified and well-funded campaign to fix a very visible category of bugs. It had executive sponsorship, a dashboard, weekly reviews, mandate, the whole show. At the same time I'd stumbled upon a silent issue after joining a new organization that I believed was costing us a significant amount of money, and no one was looking at it because it wasn't throwing errors and didn't have a champion. I ended up raising this concern to multiple executive sponsors and arguing that we needed a strike team to investigate. When the numbers came back they confirmed losses that had been accumulating for years that were effectively invisible to our existing systems.

Even further back in my career we were one of the earlier shops on AWS, and our bill was starting to become a frequent topic of concern. Most of the focus for initiatives targeting this cost were around reserved instances and capacity planning, but it missed a more crucial measure: utilization. If a team is using the most high-powered GPU machine and consuming, say, 20-30% of its capacity, they could scale down to an appropriately-sized instance type, and at the scale of this company that added up to millions of dollars a year. That waste never appeared in an error tracker or a dashboard because nobody had framed instance sizing as a reliability problem, and it took someone looking at the bill through a different lens to surface it.

## Most fires never reach the error tracker

Error trackers show what code is raising exceptions, but the most expensive problems in your systems are often silent. A slow checkout raises no exceptions, it works eventually, but during that time it loses customers who give up and go elsewhere. Those customers aren't likely to submit bugs either. The best case is they complain somewhere you can find it, but even that signal may be hard to capture. Greg Linden, [describing A/B tests from his time at Amazon](https://glinden.blogspot.com/2006/11/marissa-mayer-at-web-20.html), reported that every 100 milliseconds of added latency cost roughly 1% in sales, meaning that silent latency has a measurable cost.

The [four golden signals](https://sre.google/sre-book/monitoring-distributed-systems/) from Google SRE (latency, traffic, errors, saturation) exist because errors alone miss three-quarters of what can hurt a service. Tom Wilkie's [RED method](https://grafana.com/blog/the-red-method-how-to-instrument-your-services/) and Brendan Gregg's [USE method](https://www.brendangregg.com/usemethod.html) cover the same ground from the customer and infrastructure angles, but the golden signals are the version I come back to: they name the four ways a service degrades, and only one of them shows up in your error tracker.

The problem with load is that it can be a boiling kettle. By the time it becomes hot enough to cause damage you might not have noticed, because it grew slowly enough to fly under the radar. One ill-timed query that's sufficiently large can either go unnoticed at night, or brick all traffic during the day if it runs at the wrong time. That small cluster of timeouts is steadily growing until the pager goes off with it.

Even worse are the categories of errors that are near-silent: a wrong total, a missing row, balance drifts, or other logical errors. You won't get exceptions or alerts, but your customers sure noticed it, and hopefully they tell you, but maybe they don't even notice it for a few months.

Error trackers can give us a false sense of confidence. _Observability Engineering_ describes this as partial feedback: when your observability covers some paths well and others not at all, the visible paths create false confidence while risk grows in the gaps you can't see. You deploy a new feature, the errors don't spike, so it works right? Except the latency is creeping upwards for a specific customer segment, and another code path is silently swallowing errors. Inconsistent coverage is worse than poor coverage because it conditions you to trust a partial picture, and the failures that take you down live in the uncovered paths.

There's also a fourth category I'd posit: the developer experience. CI that takes 20-30 minutes to run or slow release cadences. It's implicitly accepted because it's always been that way, and the annoyance builds slowly enough that it's already been a year of people paying taxes on it. I've seen this at multiple companies now, and at one of my earliest jobs the CI suite took 10+ minutes locally and 30+ on CI, which meant time-to-fix for any incident kept a floor with that CI time. Post investigation we got that down to about 30-45 seconds locally, and about 3 minutes on CI. At another company a flaky test suite took 20 minutes to run, if it even passed without a rebuild, and addressing it got it down to 1 minute without flakes. At the same company the entire CI system was lagging out for a month, and the signals were everywhere if you were talking to people, but dashboards took a while to catch up. It turns out SQL forced a bad index post-upgrade and fixing it gave a 100x improvement on all builds across the entire company impacting hundreds of engineers.

Dashboards did not catch those issues, but the customers (engineers in this case) sure did if you were listening.

At that same company I found the same pattern playing out continuously. I spent a lot of time at the coffee bar, at incident reviews, and at lunch. As the Ruby architect my customers were internal engineers, and because I talked to so many of them I kept hearing problems that never made it into a ticket or a dashboard. Friction they'd accepted as permanent, patterns they didn't know other teams were also hitting, pain they assumed nobody could fix. That listening gave me two things: insight into what was hurting, and the ability to convince people to work with me on fixing it. We kept lining up engineers with hard problems that matched their growth edges, and those collaborations led to several promotions across my network of Ruby engineers as we shipped fixes together. The problems surfaced at the coffee bar, and the solutions shipped because someone turned that informal signal into a shared agenda.

Your error tracker, your logs, your support queue, and whatever channel people complain in when they think nobody with power is listening: those are the instruments. Widen what counts as a fire to anything measurably hurting the system or the people using it, whether it throws or not.

## You cannot rank a signal you do not trust

So we measure everything then, right? Not quite. Most of that is still noise, and noise does more than waste your time, it trains everyone hearing it to stop listening.

If there's one thing I hate it's being paged for something that's not actionable. The moment I join a team I make it my personal mission to kill those alerts. At one company the on-call rotation was getting so many pages on non-actionable issues that they became background noise, acknowledged and forgotten. No one could tell what a real fire was because the signal-to-noise ratio had been skewed for so long that shrugging was the default response.

Diane Vaughan coined the term _normalization of deviance_ in [The Challenger Launch Decision](https://press.uchicago.edu/ucp/books/book/chicago/C/bo22781921.html) after studying why NASA engineers launched Challenger despite a known flaw: when an organization gets away with dismissing a warning, the dismissal becomes the norm and stops registering as a decision at all. _Observability Engineering_ applies this directly to software teams: the shrugging is learned behavior, and when ignoring alerts becomes the norm the one alert that matters has to battle through a wall of distrust to reach a human who can act on it.

Think about the types of alerts you've seen on an old system: CPU > 80%, RAM < 10%, or a queue over a threshold defined years ago. Those alerts can't tell you when they were caused by a backup, GC, or a circuit breaker doing its job, so you learn to ignore them.

Here's a test: if you got woken up at 2AM by this alert, would it be urgent enough to have you bolting out of bed and into an incident call? An alert earns its right to attention when it correlates to user pain, has a defined response or runbook, and isn't telling you something you already know. Keep cutting until what remains demands a human's attention.

What do we measure and alert on then? The [Google SRE Workbook](https://sre.google/workbook/alerting-on-slos/) gives a mechanism for this: instead of alerting on "CPU > 80%" or "queue depth over 1000," you define a service level objective like "checkout succeeds within four seconds, 99.9% of the time." That 0.1% gap between perfection and your target is your error budget, the amount of failure you've decided is acceptable over a rolling window. You alert when you're consuming that budget faster than the window allows, and because the budget only burns when real requests are failing or slow the alert correlates directly to user pain rather than infrastructure noise.

## The same fire burns different people

Once you have a list of fires the temptation is to reduce it to a single ranking number you can burn down. On a scale of one to ten, how bad is this? The problem is that "bad" is a relative term and depends heavily on who you ask.

At one company I worked on an infrastructure initiative tied to a partnership in the nine figures range. The existing system worked, but lacked a critical feature that the partnership required, and adding it meant fundamentally changing the backbone of how the company operated on data models that were 10+ years old and entrenched across every team.

When investigating this initiative I'd discovered that a previous team had built a large abstraction on top of one branch of this system, and that abstraction cemented the exact assumptions I needed to remove, making it exceptionally difficult to change without breaking their work. For customers a single wrong number meant an inaccurate paycheck, for the compliance team it was regulatory exposure, for the partner team it was a blocked launch, and for on-call it was getting paged into a part of the system that actively resisted change. Four groups, four definitions of what failure means.

Keep the types of harm separate. Four cover most of what matters: what a customer feels, what happens to revenue, what an engineer would have to deal with, and any other impacts to the business beyond that. The first two are pressure you feel today, the second two build over time. Averaging them together loses the nuance you need to prioritize.

Given the sensitive nature of these changes we had significant guardrails up and down the stack. Active-passive runs using shadow queries, metrics on deviation from the known-path runs, feature flags at every decision point, and an existing auditing engine which ran through the entire process reliably. Having each of these dimensions of harm in a measurable state allowed this initiative to have substantially fewer outages than similar efforts at the company.

## Start with a list

I like lists, but to make a list I need information, so step zero is getting access to the information we need: the error tracker, application logs, wherever support collects complaints, and wherever developers happen to talk. Don't have access yet? Ask. Being new is a great reason to ask for access, and an even better reason to ask supposedly stupid questions. (There are no stupid questions, just things we don't know yet.)

Once you have this information it's time to start making a list, starting with a row for each fire you can name. Walk down the sources one at a time looking for them. Find frequent errors in the error tracker that aren't self-healing, find slow pages and timeouts in the app logs, find repeated complaints from customers, and find what developers are complaining about the most. Focus on getting to five to ten rows, less is more, focus on strong signals rather than trying to boil the ocean.

From there put rough numbers next to each row. They don't have to be right, they have to exist so you can compare them. For reach, use whatever you can see: request counts, user counts, even a guess based on support volume. For severity, imagine you're the customer hitting this bug. Would you shrug it off, grumble about it, leave for a competitor, or call your bank? Those four reactions are the tiers in the model below (minor, moderate, major, severe), and a fifth tier (none) covers dimensions a fire doesn't touch at all. Score each fire on all four kinds of harm: customer, revenue, engineer, business. An estimate you can revise next week beats a number you never wrote down.

## A model you can run

I'm a programmer, which means I have a severe affliction of putting things into code and spreadsheets, so let's turn this into code, play with levers, and see what we come up with. We're concerned with how these weights interact and how to use that as a starting point for ranking fires. The results are not direct answers, they're a base for an argument that you can make visible.

As an aside I find that [Cunningham's Law](https://meta.wikimedia.org/wiki/Cunningham's_Law) is _very effective_ with engineers: "the best way to get the right answer on the internet is not to ask a question; it's to post the wrong answer." I've also heard this called the [McDonald's theory](https://jonbell.medium.com/mcdonalds-theory-9216e1c9da7d), in which the fastest way to get to a good option is to propose a bad or flawed one to compel better suggestions, because no one wants McDonald's for lunch (at least I don't).

The goal is to start a conversation, not end one, so by all means please do critique this model.

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/triage.rb", segment: "triage_model") %>

The tiers jump by about a factor of ten at each step, and that's by design because harm is not linear. A flat one-to-ten scale lets a stack of harmless blips outweigh a single corrupted payment, which is the mistake this whole exercise exists to avoid.

Here's what it looks like filled in with a hypothetical month:

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/triage.rb", segment: "triage_example") %>

Run it on a month from a ticketing system and rank it both ways:

<%= render Shared::CodeBlock.new(file: "ozymandias-triage/output.txt", segment: "triage_output", lang: "text") %>

The two worst fires aren't exceptions, they're the slow checkout and the seat map costing customers the most, neither of which shows up on an error tracker. Double-booking lands fourth on raw numbers but gets bumped up because it's not reversible, and that loud filter error dominating the error tracker lands in sixth.

The two rankings also disagree about reporting saturation, which is seventh based on customers but second based on engineers. That's why you want to score both, because ranking only one would miss the fact that this particular issue is drowning your on-call rotation with alerts while customers don't notice.

This does have a limitation though: it only covers fires you can name.

_Observability Engineering_ draws a distinction between known-unknowns (failure modes you can enumerate and write checks for) and unknown-unknowns (emergent, combinatorial failures you haven't imagined yet). You can write alerts for the first, but you cannot for the second. In a system with hundreds of code paths, flags, and data shapes the unknown-unknowns become the default tax you pay at scale and age. Our ranked list handles what we've surfaced so far, but fires we don't know about yet are going to require us to be more creative. We're going to need to ask arbitrary questions of production after the fact and drill into what we find there.

Monitoring answers questions we can predict, while observability answers those we can't. A triage model is going to need both, and later posts focus on the second.

## The fires cluster in unowned code

After running this exercise a few times you're going to notice patterns forming. The fires that are always showing up at the top are going to cluster around code that everyone touches, changes constantly, and no single person or team owns.

At another role I found a fascinating number: ~80% of code changes were happening in well-owned areas, but the remaining ~20% with poor to no ownership accounted for close to _half_ of the outages in the system. The god models, the areas that people feared working in, but that everyone had to change to land features.

Adam Tornhill's [Your Code as a Crime Scene](https://pragprog.com/titles/atcrime2/your-code-as-a-crime-scene-second-edition/) gives a method for finding these hotspots: analyze version control history, intersect changes with what fails the most, and you're going to locate a lot of them without needing to read the entire codebase. The approach borrows geographic profiling from forensic psychology, the same technique used to narrow down where a serial offender lives based on where crimes cluster. Applied to code: the files everybody touches and nobody owns are the geographic center of the mess.

_Observability Engineering_ gives this a systems perspective: it's a reinforcing feedback loop going in the wrong direction. Nobody owns the code, so nobody instruments it. Nobody instruments it, so nobody sees the failures. Nobody sees the failures, so nobody prioritizes fixing them. The code decays, and ownership becomes even less attractive. The difference between a virtuous cycle and a death spiral like this one is whether the system can see clearly enough to self-correct, and these systems can't.

Donella Meadows describes this in [Thinking in Systems](https://www.chelseagreen.com/product/thinking-in-systems/): a system can look stable for years while pressure builds invisibly, and then one small change tips it over and the collapse looks sudden from the outside even though it was coming for a long time. In a monolith this looks like a senior engineer leaving, the one person who understood the payment retry logic, and within three months the retry queue is the top page because nobody else knows how to fix it.

Meadows ranks interventions by leverage, and among the most powerful are changes to who can see what. The [DORA research](https://dora.dev/guides/dora-metrics/) and [Accelerate](https://itrevolution.com/product/accelerate/) confirm this across thousands of teams: the common factor separating top performers from everyone else is tight feedback loops, which I read as ownership and observability working together. The ranked list we just built is that kind of intervention, making invisible harm visible so the system has a chance to self-correct.

I'd observed this in one role when working on modularity tooling using Packwerk. There was substantial investment in tooling, metrics, and information but at the end of the day teams were ignoring it completely. They saw it as a distraction, something that hounded them with violations and unactionable PR feedback, while they were trying to get _real_ work done. The problem was that Packwerk's axis was fundamentally backwards and disempowering: Packwerk showed _consumers_ of code what they were violating, rather than showing _producers_ of that code and those interfaces how others were depending on them and violating their internal code. The consuming team can't do anything about it except complain to the producing team, and that's not their job. The producing team is the one able to make changes, making those alerts actionable rather than noise everyone ignores.

When the axis was flipped the ownership gaps and shapes became obvious. The places with the most violations weren't where consumers were being careless, they were in the gaps where no one understood the needs of the customer, and ActiveRecord made it _very_ easy just to reach inside the private APIs to get what they wanted without an unpleasant conversation and waiting period for that team to prioritize the work.

It's a [desire path](https://en.wikipedia.org/wiki/Desire_path) in action: teams are, unsurprisingly, going to take the most expedient route to get the information they need to finish their work. AI agents? Oh they're _much_ worse about this and will absolutely plow right through a building if they think it'll get something done faster. Your job, as an API producer, is to get ahead of this and cultivate good interfaces early and then _lock down every other path in_.

## Where this points

From here we're going to need a way to go from a fire on the list to the line of code responsible for it, and static analysis alone won't get us there. The next post is about using production evidence to follow that trail, asking the right questions of the right sources until a symptom becomes a coordinate in your codebase.

## Further Reading

- [Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/), Google SRE, the full chapter on the four golden signals
- [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/), Google SRE Workbook, the math behind error budget burn rates
- [Observability Engineering, 2nd Edition](https://www.honeycomb.io/observability-engineering-oreilly-book), Charity Majors, Liz Fong-Jones, George Miranda, and Austin Parker
- [How Complex Systems Fail](https://www.researchgate.net/publication/228797158_How_complex_systems_fail), Richard Cook, all eighteen points in three pages
- [Thinking in Systems: A Primer](https://www.chelseagreen.com/product/thinking-in-systems/), Donella Meadows
- [The Challenger Launch Decision](https://press.uchicago.edu/ucp/books/book/chicago/C/bo22781921.html), Diane Vaughan
- [Accelerate](https://itrevolution.com/product/accelerate/), Nicole Forsgren, Jez Humble, and Gene Kim
- [Your Code as a Crime Scene](https://pragprog.com/titles/atcrime2/your-code-as-a-crime-scene-second-edition/), Adam Tornhill
- [DORA metrics](https://dora.dev/guides/dora-metrics/), the five delivery performance metrics and their relationship to ownership
