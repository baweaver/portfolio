---
layout: "post"
title: "Ozymandias on Rails. The Pedestal Inscription"
date: "2026-06-28"
categories: []
tags: ["ruby", "rails", "architecture", "legacy", "ozymandias-on-rails"]
series: "ozymandias-on-rails"
description: "Every successful Rails monolith becomes a ruin if it survives long enough. This post is about why, and what a recovery looks like from the inside."
---

> "Look on my Works, ye Mighty, and despair."
>
> Percy Bysshe Shelley, ["Ozymandias"](https://www.poetryfoundation.org/poems/46565/ozymandias) (1818)

Legacy. It's an interesting word, isn't it? What is a legacy, and what does it mean to us as developers? In Shelley's poem, a traveller finds a ruined statue in an empty desert. Two legs, a shattered face, and a pedestal upon which there is an inscription: _My name is Ozymandias, King of Kings; Look on my Works, ye Mighty, and despair._ Nothing remains of the works. The empire is gone, faded to time and the desert sands. The mighty should indeed despair, because even a King of Kings is nothing to time.

Why is this relevant to us today, as Ruby engineers? What lessons can we learn from Ozymandias?

For those who do not know me well I have spent close to 15 years now inside Rails monoliths that look a lot like this. The ones that succeeded, and because of that grew and hired hundreds to thousands of engineers who continued to build into the next decade or more. One day you look around, and you realize that large swaths of these systems belong to nobody, error channels have been red for months now and the problem seems intractable, and not a single person can hope to hold the shape of it in their head anymore.

The monument still stands, the legacy that got us here, but all things crumble and fade over time. The people who built it are likely long gone, and piece by piece the knowledge fades with them, until what is left feels like a ruin and no one quite knows what to do about it.

This series is about what you do when you find yourself in such a situation.

## Vanilla Rails is plenty (until it isn't)

But how is it we get to such a state and such a legacy? Because Rails is designed that way.

There's a long-standing argument in the Rails world that vanilla Rails is plenty. Callbacks, concerns, fat models, the usual omakase experience Rails gives you. The argument is that disciplined use of the defaults scales further than most people credit, and that reaching for architectural abstractions is usually a way to import complexity you don't need. [37signals states it plainly](https://dev.37signals.com/vanilla-rails-is-plenty/).

It's the through-line of a decade of Rails leadership. DHH argued for [the monolith over microservices](https://signalvnoise.com/svn3/the-majestic-monolith/) in 2016, [allowed pulling a single service out](https://signalvnoise.com/svn3/the-majestic-monolith-can-become-the-citadel/) when the monolith strains in 2020, built the framework on a [doctrine](https://rubyonrails.org/doctrine) whose purpose is to equip a generalist to build a whole system rather than require teams of specialists, and doubled down at RailsWorld 2025 with his framing of ["merchants of complexity"](https://world.hey.com/dhh/they-re-rebuilding-the-death-star-of-complexity-4fb5d08d) (a term from a 2023 post that became the keynote's central theme) selling solutions to problems the monolith was supposed to solve on its own.

To be fair though, it's also more careful than its reputation implies, as these opinions _are_ scoped. Microservices are for companies of thousands, while the monolith is for small teams, and copying patterns from those large companies is a good way to hurt small ones. The 37signals post qualifies itself the same way, closing on an admission that they don't know whether the approach holds at Shopify's scale.

This series is not an argument for microservices. It's about how someone in the middle can chart a path forward without the framework helping them get there. The qualifications are there. They just answer the wrong question, and they don't travel.

Every argument is about a team at a single point in time. The problem is that teams grow, and a monolith rots when that team of twelve becomes hundreds over a decade and institutional memory thins with every departure. How long before that company is no longer the same people? Before everyone who wrote the initial version is long gone? Each departure is another piece of context and knowledge leaving, some of it written down, but a lot of it isn't.

They also don't stick like headlines do, because readers remember bold titles, not footnote disclaimers. People remember "majestic monolith" and "vanilla Rails is plenty." They don't remember "for a team our size, at our tenure, under our load."

There we find Ozymandias. The pedestal doesn't read _these works are impressive for a kingdom of a certain size_. It reads _look on my Works, ye Mighty, and despair_, as if the conditions that produced them would hold forever. The systems I keep inheriting were built by people who carried the headline without the footnote, and by the time the conditions changed nobody remembered there was a footnote to go back to.

## What actually goes wrong

I've been writing about the mechanical side of this all month in <%= post_link "Rails: The Sharp Parts", slug: "rails-sharp-parts-callbacks-are-not-invariants" %>. These are failure modes in the abstractions themselves, and they break regardless of how good your team is or how well-owned the code is. This is only a partial list, and yet it contains so much of what makes Rails Rails:

**Callbacks become invisible control flow.** A model with thirty callbacks has sixteen possible execution paths on a single `save`. The person who added callback number twelve can't tell you which of the others fire before or after it. The person reading the controller has no idea any of them exist. The [Rails guides document bypass paths](https://guides.rubyonrails.org/active_record_callbacks.html#skipping-callbacks), and every bulk operation uses them.

**ActiveRecord leaks across boundaries.** A relation returned from one part of the system is a live database handle. The caller can write through it, fire N+1 queries on it, and depend on columns that were never part of any contract. Every returned ActiveRecord object is an implicit coupling between the code that produced it and everything that touches it afterward.

**Polymorphic associations store relationships as strings.** A `notable_type` column holds a Ruby class name and `notable_id` holds an integer that could point at any table. The database can't enforce that with a foreign key, since it would need to know which table to point at, and the string is the only thing that tells it. A delegator can make the type clause vanish from a query. A class rename strands every stored string. You can't join through them. The convenience shows up on day one, and the cost shows up the day you try to extract a service and find three teams all writing their identity into the same unenforceable table.

**Indexes get built for queries nobody controls.** When any code anywhere can run `Seat.where(column: value)` against your table, there's no finite set of query shapes to tune for. You end up indexing every column anyone might filter on, paying the write overhead on all of them, and still missing the queries you haven't seen yet. A single read path per shape, owned by the pack that holds the table, closes the set to something you can actually optimize.

These are four examples. The Sharp Parts series covers more, and even that doesn't exhaust the list. The problem runs through the framework's core abstractions, and more discipline won't fix what the abstractions themselves make possible.

## Ownership compounds it

While I will caveat that there is an argument for "Vanilla Rails" at smaller scales, the above problems still exist even there. The problem is that as a company scales, what can be reasonably contained and managed with diligence becomes an intractable problem that no one learned to deal with. Diligence can only work with knowledge and ownership, and when code belongs to everyone it belongs to _no one_.

We should also be clear on what we mean by ownership in this context, because DHH's recent work is about ownership too, and he means something different by it. His version is vertical. Own your whole stack, from the framework down to the operating system, so no vendor and no merchant of complexity sits between you and the machine.

The kind that decays inside a large monolith is horizontal. It's the question of which team is accountable for a given model or table once thirty teams touch the same code. He's named this axis too, in passing, talking about how slicing one web developer into fifteen narrow roles injected complexity that didn't need to exist. His answer is to refuse the slicing and stay a generalist, which is a fine answer for a company that still can. It isn't available to one that already has several hundred engineers and a decade of code.

A callback with sixteen paths is a hazard. A callback with sixteen paths that no team owns is a hazard nobody is responsible for fixing. A polymorphic table is structurally unsound. A polymorphic table that three teams write to and none maintain is structurally unsound _and_ politically difficult to change.

When a team is small, ownership is implicit. Everyone knows who owns what because everyone talks to everyone. That stops holding somewhere around the third or fourth team, and implicit ownership decays into no ownership at all. The code that grows fastest, breaks most often, and resists change most stubbornly is the code in the gaps between teams.

[GitLab figured this out](https://docs.gitlab.com/development/database/polymorphic_associations/) and banned polymorphic associations. [Shopify figured this out](https://github.com/Shopify/packwerk) and built Packwerk. [Gusto adopted it](https://engineering.gusto.com/building-toward-a-modular-monolith/) and built an entire ecosystem of modularity tooling on top. [GitHub runs a nearly two-million-line Rails monolith](https://github.blog/engineering/architecture-optimization/building-github-with-ruby-and-rails/) with over a thousand engineers and invests continuously in architecture and boundaries to keep it workable. All of them reached the same conclusion: structural problems with no owner degrade faster than the same problems with one, because nobody is accountable for the fix.

The thing to notice is that each of these companies was able to invest enough engineers to build these tools when the defaults stopped holding. Those guardrails are not in the box, they're not omakase, and to be frank having written some similar tooling they're _expensive_ to build. For small companies you very well may need none of that, but that luxury can quickly fade at scale.

The gap is the middle. Most companies running a large Rails monolith aren't 37signals and aren't Shopify. They're somewhere between the two, past the point where shared context holds and short of the point where they can staff a team to build boundary tooling of their own. Rails gave them the fastest start possible, the defaults that turn an empty directory into a working product faster than anything else, and then left them there. There's no paved path from the majestic monolith to whatever comes after it, and the doctrine treats needing one as a failure of discipline rather than a stage of growth. So the company in the middle improvises the transition under load and gets it wrong, or never makes it at all.

## What recovery looks like

Oftentimes when I see someone inside these systems, the first instinct is to rewrite everything. We can do it better this time, and it'll be faster. The problem is that we have yet to learn from history. Joel Spolsky [explained why that fails in 2000](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/), and Fred Brooks named the pattern even earlier as the [second-system effect](https://en.wikipedia.org/wiki/Second-system_effect): the second version of a successful system is almost always over-engineered, because the team tries to include everything they wished they'd done the first time. Netscape learned this when they rewrote Navigator from scratch and lost the browser war while the rewrite shipped nothing for three years.

With the advent of AI it becomes even more tempting, because it makes rewrites _look_ cheap. If a model can generate a thousand lines in seconds, why not regenerate the whole thing in Rust or Go? [Gartner's 2026 assessment](https://www.ciodive.com/news/mainframe-exit-plan-risk-leaders-overestimate-ai-gartner/823437/) says more than two-thirds of enterprise efforts to transform legacy implementations with AI _will fail_. The hard part is understanding why the existing code does what it does, and an AI can reproduce the shape of a system in hours while missing the decade of fixes and context that made it correct.

Don't get me wrong though. None of this means you can never extract anything. A distinct piece of the system with clear ownership, a well-understood interface, and measurable pain that the monolith's structure prevents you from fixing is a valid candidate, but the bar is high, the evidence has to be specific (which requests, which teams, what's unfixable in place), and the broad mandate to extract _everything_ is a different animal entirely. I have watched that stall organizations for years.

So what does work? Incremental recovery. You start by understanding what's broken, measured by what it costs rather than how it looks. Most of what looks broken is ugly but functional, and what's costing you the most is invisible.

From there you trace each fire back to where it lives in the code, and you find the fires cluster in the same places: the unowned code, the shared models, the tables everyone writes to. You draw boundaries around those places, you assign ownership, and you make the implicit explicit one piece at a time, without stopping the system.

The work is ownership, boundaries, and the patience to apply them to something that's still serving traffic. That's years of effort, done alongside features and incidents and hiring. It doesn't make for a dramatic story, but it's the only version of this I've seen work.

## This series

I'm calling this series "Ozymandias on Rails" because the poem is about permanence being an illusion. We don't know what happened to the king and it doesn't matter. The works didn't survive, the inscription did, and the traveller found them in a desert with no context for what any of it used to mean.

Rails got us here fast. The systems we built with it succeeded, grew, hired, shipped, and kept going for a decade or more. That's not a failure of the framework or the people who used it. The monolith worked, and then it kept working past the point where anyone remembered why it was shaped the way it was, and that's where we find ourselves.

This series is about what comes next for those of us inside these systems. The work is making a ten-year-old system livable for the next ten years, and it starts with learning to see what's on fire versus what only looks alarming.

The next post will cover that distinction.
