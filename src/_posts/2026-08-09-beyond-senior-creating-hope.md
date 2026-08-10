---
layout: "post"
title: "Beyond Senior - Creating Hope"
series: "beyond-senior"
date: "2026-08-09"
categories: ["staff", "leadership", "career"]
tags: ["staff", "leadership", "career"]
description: "Organizations teach themselves helplessness through reinforcing loops of scarcity, cynicism, and declining trust. This article is about breaking that cycle."
---

This is part of the Beyond Senior series, which explores what changes when engineers move past the senior level into staff and principal roles.

## Creating Hope

Tell me if you've heard this one before. At your company everything seems on fire all the time, and you're in a constant state of emergency response trying to deal with it. Priorities are changing every week if not every day, planning beyond the end of the month feels like a polite fiction, and every team is so underwater that the merest mention of more work makes everyone revolt. Every project is critical, every dependency blocking, and every request comes from someone with a very good reason why theirs needs to happen first.

After enough time operating like this every collaboration starts to feel transactional, because helping someone else means falling further and further behind on your own projects and whatever you're already failing to finish.

People are exhausted, and the system has conditioned them to believe that any generosity carries a cost they cannot afford. Teams turtle up, leaders ask for plans that no one believes in, and engineers make commitments that everyone fully expects to slip. The planning horizon has gotten so short that next week is concrete, next month is questionable, and anything beyond that is fantasy.

If this goes on for long enough something much more dangerous begins to happen: people stop believing things can _ever_ get better.

This is a subject I've spent a lot of time thinking about over the past 15 years, having now seen it at several companies, including how I've likely contributed to this problem myself. So what do we do then, when hope feels lost? That's what I want to explore with this article, as I increasingly believe the most important responsibility we have as engineering leaders is creating hope.

## When Everything Had an Answer

When we're early in our careers everything has a clear answer, and some (myself included) take that to mean that being a good engineer is about being right. Early in my career that was true enough to work well for me, but it had a severe cost that took me years to realize.

The systems and projects I was working on were small enough to fit inside my head and finish within a week. I could read all of the relevant code, understand requirements, trace dependencies, reproduce problems, and deliver a reasonably complete answer to all of them. In most of these cases there indeed _was_ a correct answer, or at least one that was substantially more correct than the alternatives, and I was rewarded for finding it.

That was part of the beauty of technology. The test passes or it doesn't, the algorithm is faster or slower, the race condition definitely exists, and things were so concretely provable if you were only stubborn enough to do so.

The problem is that as my scope grew the systems and projects I was working on stopped being so clear cut, because the system expanded beyond software. It now included engineers, customers, deadlines, budgets, hiring, history, personalities, incentives, contracts, politics, org boundaries, and decisions made years ago by people I could no longer ask, based on information that I could never know. The scope of work explodes far past what a single person can hold, and what got me success at that level was not remotely scalable.

Try as I might it was effectively impossible to fit the entire context in my head. It didn't stop me from trying, and the problem I found at the end of that road was always that I had overlooked something, missed some factor, or otherwise made a significant mistake due to presuming that I did indeed know everything.

Something that looks obviously stupid? Well it must have been done by someone stupid. An inconvenient decision was made? Well whoever did it must not care. The project failed? It was doomed from the beginning. The architecture is difficult to work with? It should have been designed differently then, the person who wrote it didn't know what they were doing.

For the longest time I became very good at seeing everything that was wrong, and worse, I had an awful habit of telling everyone about it.

## The Certainty Trap

There's a quote from [Will Larson](https://lethain.com/setting-engineering-org-values/) I'm reminded of, "most professional conflict between reasonable people is driven by asymmetric information," with a follow-up advising people to approach conflict with curiosity. It's the correct sentiment, as it turns out people are wonderfully complex beings with their own priorities, hopes, beliefs, and most importantly contextual information. What is clear to me may be horridly opaque to another team, and vice versa.

When otherwise smart people make irrational decisions I do not assume they're irrational. I try to figure out what they might have seen that I didn't, what constraints were present, and what the problem is they thought they were solving. Absent that information I'm trying to make a judgement call on an incomplete picture, which will lead to bad assumptions.

Sometimes yes, the answer is that it was a bad decision, that happens all the time and I've made enough of them myself. Far more often though? I was missing part of that picture. Perhaps a deadline, a customer, an incident, regulatory requirements, executive commitments, or a litany of other concerns.

Unsurprisingly imperfect humans make imperfect decisions with imperfect information inside of imperfect systems, which describes effectively all of engineering. Perfection does not exist, and you can never be 100% certain of anything.

That doesn't mean we should abdicate responsibility and excuse bad decisions, or that every decision is defensible. It means that understanding something is a prerequisite to changing it, and that self-righteous indignation has a bad habit of ending those investigations where reasonable curiosity would have dug in deeper to find better answers.

It's one of the reasons why I have [Chesterton's Fence](https://fs.blog/chestertons-fence/) bookmarked to share at every job I take:

> Do not remove a fence until you know why it was put up in the first place.

## Evolution, Not Perfection

Years ago at one company we were looking at how we might change the annual review process, and some of the staff were asking how a previous company I'd been at used to run these processes. My answer was that this was the wrong question to ask.

That company's process had evolved organically to meet its own needs. It reflected their scale, culture, people, compensation philosophy, management structure, history, and whatever other problems the company had been trying to solve at the time. Taking a finished evolutionary answer and grafting it onto another company which has not earned that conclusion won't give you the same outcomes any more than copying Google or Amazon's architecture and internal tooling and pretending you're them.

In stepping back and understanding the context of how they got to their solution and what conditions made it successful we could more clearly learn from them and apply what made sense for us at the stage we were at.

That's true of any organization, and by extension the software it produces. A solution that works for fifty engineers can fail at five hundred, and what works for an organization of five hundred likely does not apply to fifty without drowning it in bureaucratic process it does not need yet. Companies change, they grow, and solutions which worked at one historical point are now the very thing holding it back.

There's an idea of "[sacrificial architecture](https://martinfowler.com/bliki/SacrificialArchitecture.html)" that Martin Fowler has written on, where systems that are appropriate at one stage of a company can and probably should be replaced as it grows. Architecture is not eternal. The conditions change, and what we were optimizing and building towards may no longer hold true. Treating architecture as sacred and immutable, therefore, does more harm than good.

There is no such thing as perfection, because there is no destination, only a journey that we eternally pursue. The wisest thing we can do is favor optionality and adaptability, rather than designing increasingly elaborate solutions that attempt to fully quantify an ephemeral future which may or may not come to pass.

## The Monolith

In my career I have spent a substantial amount of time around large Rails monoliths spanning from hundreds of thousands to millions of lines of code. I've watched companies go from enthusiastic to dejected to deeply fatalistic about monoliths as they evolve.

The monolith is too big, Rails is slow, the tests take forever, everything is hopelessly coupled, deployments are dangerous, and no one can hope to understand the entire thing any more. All of those complaints have some truth to them, but there's also something subtle changing in the language used around this time: The monolith stops being a system containing thousands of tractable problems and itself becomes **THE** problem.

Once things hit that stage people stop asking questions about what endpoints are slow, what dependencies caused the latest incidents, where engineers are losing time, or what boundaries are creating the most friction to the organization. The problem has become so large that people begin to believe that no individual intervention has any meaning, and so the organization defaults to survival mode.

Well-meaning engineers say we need to keep the lights on, and then keep them on some more, until eventually that's all they want to invest in and the costs continue to grow, demanding more and more resources. Don't get me wrong, keeping the lights on (KTLO) is valuable and necessary in every system, but it is not and cannot be your entire engineering strategy. An organization that only works on KTLO has surrendered their mission for fatalism, and in doing so has made itself increasingly irrelevant.

Google's [SRE book](https://sre.google/sre-book/eliminating-toil/) frames this well: at least 50% of an SRE's time should be spent on work that reduces toil or adds features. Toil is explicitly capped because a team completely consumed by KTLO cannot invest in reducing that KTLO expense, creating a doom loop. That principle applies well beyond SRE.

At one company I had encoded it in our three year plan that we would _not_ be breaking services out of the monolith without a _substantial_ business case backed by production data and customer needs. For a parent company that favored microservices this was a very provocative position to take, contradictory to how they normally build, but contextually it made much more sense. We were an acquired subsidiary on a Rails monolith, and the problems facing us were very rarely scale as much as business cases, so the inclination to break out services would have become a multi-year distraction that did not materially move the business forward.

Frequently in these larger companies people follow established patterns, but every pattern and solution has exceptions, and we must be careful to remember nuance when making decisions. What made sense for the broader company would have been a bad idea for this subsidiary, and vice versa what worked for us would have been a poor idea for the wider company.

The incentive structure at the parent company was that teams owned their stacks back to front and could hold the context in their heads at any given time. It's fine as an end goal, but without exploring the journey to get there and the cost it becomes an irresponsible decision steeped in the familiar rather than the necessary.

For us that meant prioritizing things that were explicitly contradictory for the wider company. Investing in the monolith provided us more immediate unlocks and started to set the stage for breaking more things down as ownership was more clearly defined. That also meant that teams needed to pay the monolith toll and invest in a mutual system, rather than isolated local areas they were more directly funded and incentivized to pursue.

When all of the teams are underwater on projects this mutualism can feel like an indulgence, but if that underlying system is what's slowing teams down it's reasonable to invest as the same local decisions are going to lead to the exact same conversation next month as yet another team wants to build something like a unified event bus or other shared service.

Scarcity mindset prevents investment in things that would reduce scarcity, and over time an organization will manufacture the very conditions it believes itself to be helpless against.

## Salvation

There's a version of this story I was hinting at in the previous section, when an engineer walks into the room and says we're going to full microservices.

People are excited, there's finally a direction. The monolith is the problem, microservices are the answer, and every extraction is a win against the mire we find ourselves bogged down in. The problem is that as a solution it has as much subtlety and nuance as a chainsaw being used to trim a bonsai tree. Extraction becomes the goal, rather than a tool, warping priorities around it to where people skip important details around demonstrable customer use cases and production data to justify these decisions.

Two years after the grand declaration there are dozens of new services, but little has changed. Now you have a distributed systems problem with failure modes and data synchronization problems where transactions used to be, half the migrations are partially finished, and people have to maintain both sides of it. Meanwhile the monolith is still there, almost in defiance of all the effort.

Ironically it's probably _even harder_ to get rid of now.

At one company there was a particular table that would consistently brown out the entire database every few weeks, and teams had invested substantial time in extracting it as a service to reduce these issues. The problem wasn't the monolith, the problem was the thrashing behavior of the database queries being run in one giant unbatched job with significant write contention on mutually locked rows. What should have been a localized optimization became a two year project that failed to deliver on its promises, and in fact made the problem worse, because the team was more fixated on the end-state they wanted rather than the next most logical improvement that would have lightened the load and given them more optionality.

The tragedy of these cases isn't just that engineering time was wasted, but that the organization has effectively spent two years teaching its engineers that improvements don't work. The next person with an idea isn't starting from zero. They're starting from everyone remembering the last grand transformation that consumed years and never noticeably improved their lives.

This salvation mindset of one big bang solution that will fix everything is poison to organizations. We must distinguish between a salvation mindset and a hope mindset wherein hope is the belief that _we can make this better_ while salvation is the belief that _something else will make this better for us_. Salvation may present itself as microservices, rewrites, a new language, a re-org, new leadership, consultants, or whatever other technology is in vogue this year. By themselves they're not necessarily bad ideas, but we've conflated the solution itself with agency we stopped believing we possessed.

It reminds me of a quote I heard at a previous company:

> "No one is coming to save you. You have to save yourselves."

It's a statement about agency, not abandonment or an excuse for leadership to refuse to help. No architecture, executive, process, or re-org can ever be a substitute for an organization rediscovering that they can produce meaningful outcomes and regain their own agency. Universal solutions applied without discretion fail precisely because they skip the understanding that makes local decisions good. The answer is never "monoliths good, microservices bad" or the reverse. The answer is that context determines which tool fits, and context requires the curiosity to look.

## The Doom Loop

How do organizations end up like this? I've come to think of them as self-reinforcing systems, rather than a collection of individually bad decisions. Peter Senge wrote extensively about feedback loops like these in _[The Fifth Discipline](https://www.penguinrandomhouse.com/books/163984/the-fifth-discipline-by-peter-m-senge/)_, where the behavior of a system produces conditions that reinforce the same behavior.

When real problems repeatedly fail to improve people start to believe that their work does not matter. That loss of agency calcifies into cynicism and bitterness, where curiosity and drive are met with a litany of reasons why it will never work. Trust erodes, teams turtle up, collaboration becomes transactional, and any plan more than a few weeks in length will be seen as doomed to failure. Everything becomes urgent, every fire worse than the last, making any long-term investment increasingly impossible as the underlying problems become worse as they continue to be deferred. Every step feeds into the last as evidence that the system can never change, which ironically guarantees exactly that outcome.

There are no villains required for this to happen, no Machiavellian plotter or dastardly figure twirling cartoonish mustaches, none of it.

Normal people can make perfectly rational local decisions while setting the stage for a miserable global outcome. The team refusing to help may not have capacity. The manager demanding immediate commitment may indeed have enormous pressure coming down. The engineer avoiding architectural fixes may have watched the last three get abandoned part-way through for more features.

When systems teach people helplessness like this, people will adapt accordingly.

## When Everything Becomes Zero Sum

As hope fades everything becomes a zero sum game. If your team gets extra headcount mine won't, if I help with that migration my roadmap slips, and if your project is prioritized it's at the expense of mine. People become territorial, hoarding knowledge, headcount, roadmaps, and even technical decisions.

The people aren't necessarily selfish, but the system has taught them a scarcity mindset, and in that mindset generosity becomes irrational and disincentivized.

Ron Westrum described the opposite as a _generative_ culture where cooperation is high, risks are shared, people bridge organizational boundaries, and failures lead to curiosity rather than blame. [DORA](https://dora.dev/research/) later found those cultural characteristics correlated with stronger software delivery and organizational performance.

Engineers can make the mistake of treating culture as a soft ephemeral vagueness surrounding the "real" engineering work, but that very culture determines what engineering work is even possible in the first place. Teams that don't trust each other will never make durable boundaries between them. An organization that punishes failed experiments will kill experimentation regardless of what's in the stated values.

[W. Edwards Deming](https://deming.org/explore/fourteen-points/) said to drive out fear so that everyone may work effectively. He argued for tearing down silos and getting departments to work together, which sounds like a motivational slogan until you watch it play out in practice. When people are working in a scarcity mindset information stops flowing, decision quality drops, and cooperation becomes impossible.

## Bitterness

At a dinner with a group of more junior employees at a conference I'd told them I was leaving the company, and there was one piece of advice I gave them which I said was more important than anything else:

I told them not to become bitter people.

We see something wrong and we point it out, a few more people agree, and that agreement feeds into momentum and assurance that you're not the only one to see these problems. Slowly a community grows from this of like-minded people who share those viewpoints around all the things you think are broken in the company or even in your area.

Up to this point there's nothing necessarily bad about that.

Where it takes a turn for the worse is when these communities become larger-scale venting groups where everything is broken and hopeless, and over time that bitterness starts to feed back on itself until the group becomes caustic and toxic to everyone around them. Sure, people disagree at first and are willing to engage, but over time they stop bothering because conversations become exhausting and that group begins to distill itself into a cesspool of misery.

Every failure becomes a confirmation that they're in the right, mistakes become pieces in a growing narrative, and every attempt at changing anything ends up explained away as pointless before it ever begins. At some point this group becomes less about the problem itself as much as why these problems can _never_ be solved and why everyone who doesn't see it is part of the problem.

At its most extreme (and I've seen this escalate to fireable offenses and permanently burnt bridges) an in-group forms around those who know the truth of increasingly loyalist factions, and an out-group who are secretly evil and are out to get the in-group.

Across every job I've had I can count on one hand the number of people who were malicious, and the number of times the company had it out for someone. These are exceptional cases, but as these groups descend everything becomes a conspiracy to which any new information is a further confirmation that everyone has it out for them, and only they can keep each other safe.

I won't lie, I know what the lesser versions of this feel like, because I've been that person in the past and I'm not proud of it. I never got to the conspiracy stage, but the venting, the community of shared grievance, the exhausting certainty that everything was broken? I've done that.

There were points in my career where I mistook being loudly right for having influence. Sure, I often found a lot of real problems, but that's what makes this so insidious. What I thought was creating urgency through awareness was more often a cause for confusion, exhaustion, and ironically loss of trust from leadership that fed back into that persecution narrative playing on loop in my head.

When people walked away from a conversation with me when I was like this they didn't walk away thinking about how things could change, they walked away never wanting to talk to me again. Do that enough and people get sick of you, not because you're wrong, but because you are emotionally and professionally exhausting to be around for any duration of time.

The only thing you end up doing complaining like this is ironically killing any amount of agency people might have had to solve these problems.

You haven't _won_ arguments as much as people fold and walk away from the table and let you go about your merry way, preferably _away_ from them. It's diplomacy via bludgeoning and fatalism dumping, which wins no hearts and minds.

Where this becomes exceptionally dangerous is when you behave like this as a leader. If the most experienced engineer declares everything hopelessly on fire, do you think the junior engineers will walk away feeling empowered to do anything about it? If any enthusiasm or drive is met with a deluge of negativity on why it will fail people will start treating enthusiasm as naivety, that you don't know how the systems _really_ work or you'd never say that.

Left alone for long enough this cynicism and bitterness becomes your culture, and it will sap the life out of both you and anyone around you.

## Evidence of Agency

I have very little patience for pretending things are fine when they're clearly on fire. Hope does not require us to ignore reality and soften criticism. Some systems are terrible, decisions can be bad, and there are certainly organizations which need drastic change.

The difference is what people believe they can do about it.

I define hope as **accumulated evidence that effort matters**.

That evidence is hard won. You can't put that down as a company value and all-hands it into existence. You have to earn it every day, and prove that it's real.

That means addressing issues directly, starting where you have leverage and knowledge, and snowballing that into progressively harder problems until the culture reinforces the practice when you're not in the room. If a deploy takes forty minutes get it to twenty. If DB queries in your code are taxing the system try to find an optimization. If engineers are losing hours a week to CI times make it faster. If no one owns a critical part of the system take ownership. If eight engineers are working on eight different unrelated priorities, figure out which ones matter and drop the rest.

Every success here feeds another success, showing people that their effort matters and that change is possible.

At one company I inherited a Rails monolith that hadn't been upgraded in over two years. The previous upgrade had taken over a year to perform and consumed enormous resources, and the general consensus was that doing it again was somewhere between impractical and impossible. Nobody wanted to touch it, and the longer it sat the worse the security posture became.

I started not with the upgrade but with coffee. The company had a coffee bar, and I made a habit of finding other Ruby engineers there, learning what they were working on, what frustrated them, what they were interested in. Over months and years those conversations turned into small collaborations on Ruby infrastructure projects. I'd get permission from their managers, scope the work to defined time blocks, make the cost known up front so saying yes was easy. When engineers on those teams were close to promotion I'd offer projects that helped both them and the broader Ruby ecosystem at the company, then write the promo feedback to back it up. Win for them, win for their manager, win for the infrastructure.

By the time I proposed the upgrade I had a network of engineers across 27 teams who trusted me, had worked with me, and believed that cross-team collaboration could produce results. I'd earned enough credibility with leadership to negotiate resources onto roadmaps that weren't mine. The upgrade that nobody believed was feasible delivered in four months, two full months ahead of schedule. It was also the project that got me promoted to principal engineer. Promotions compound hope. When the system visibly rewards someone for building trust and empowering others, people notice, and more of them start doing the same thing.

What happened after I left proved more than the upgrade itself did. I'd built the tools, documentation, and frameworks so that the _next_ upgrade could happen without me. It did. The engineers I'd invested in carried it forward on their own, and the one after that was already in progress when I left.

That's what the compounding looks like in practice. You start by proving that small things can change, you build trust through repeated follow-through, and eventually the organization discovers it has capabilities it didn't believe it possessed and can begin to execute autonomously without you in the room.

## The Hope Loop

Those successes become the foundation for their own reinforcing loop. Problems are met with curiosity, which leads to better understanding and more actionable ownership. Progress increases agency, making people more willing to contribute to the next improvement. Successful cross-team or org collaboration increases trust, making future collaboration cheaper and eventually making long-term planning increasingly credible and likely to land.

People invest in tomorrow once they've seen today's effort pay off. That evidence is what makes longer-term planning credible.

Your ability to execute and plan goes from next week to next month to next quarter. Teams gain confidence in committing their engineers because they expect cooperation will be reciprocated and rewarded. Larger projects become tractable because smaller successes lead to larger ones, and proof that cooperation can work.

This is why I believe in evolutionary approaches to culture and technology. If a giant Rails monolith is struggling I do not need to solve for whether it should live forever or become microservices. I need to understand the customer pain, solve for what I find, observe its impact, and let that drive the next decisions.

Maybe we make cleaner boundaries between areas of code. Maybe we fix a gnarly query, improve observability, make deployments faster, or fix a series of papercuts our customers have complained about. Perhaps there is a case for extraction and independent scaling, but that should always be a high bar rather than a default posture. Extraction as a default answer skips past dozens of cheaper, more immediate fixes that would have provided evidence about where the boundaries need to be.

## Pick Up a Shovel

Back at that dinner table, I told them not to become bitter, but I also told them what to do instead:

Be known for solving things rather than complaining about them. Complaining is cheap and easy. Fixing things is hard. Be the person who picks up a shovel and does the work.

There will always be things that happen which make bitterness tempting. You're going to watch projects fail, migrations stall, leaders fail, technical debt accumulate, and organizations repeat the same mistakes over and over again. Over time this becomes cynicism under the guise of wisdom and experience, because a cynic can always tell you why something won't work. With enough experience you can find a story proving any idea is doomed if you wanted to, but that's a miserable place to be.

Don't confuse that with wisdom.

You cannot fix everything, so don't. Doing so will destroy you. Some problems are not worth fixing, some aren't even yours to fix, and some require resources you won't have. Part of growing is learning to tell the difference and not letting those limits turn into fatalism.

What you can do is grab a shovel, do the work, and through doing so give others permission to do the same.

I don't believe there are perfect answers in this industry. Everything changes. Conditions, organizations, customers, people, reality itself has a habit of disagreeing with even our best assumptions given enough time.

What matters is whether what we built can match that moment when it happens. We do the best we can with the information available, understand the tradeoffs, preserve optionality against an uncertain future, and remain willing to change our minds when evidence contradicts us.

Moving beyond senior and becoming a leader means creating hope through both our words and our actions. Our example defines culture over time, and what others believe is even possible.

The industry fixates on force multiplication, but rarely asks what it is we're multiplying. Are we multiplying bitterness, fear, scarcity, or helplessness? Or are we multiplying trust, generosity, curiosity, agency, and hope?

It's easy to feed the first loop. I spent a lot of my early career doing so, but these days I'd rather pick up the shovel and do something about it.

## Wrapping Up

Our most important responsibility beyond senior levels isn't only solving larger problems, it's making sure people around us continue to believe those problems can be solved.

Hope compounds, but so does despair. Be careful which one you choose to feed.
