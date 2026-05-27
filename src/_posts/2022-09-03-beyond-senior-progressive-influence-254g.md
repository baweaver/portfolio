---
layout: "post"
title: "Beyond Senior – Progressive Influence"
series: "beyond-senior"
date: "2022-09-03"
categories: ["influence", "staff"]
tags: ["influence", "staff", "politics"]
description: "After a number of conversations over the past few years with several other engineers who have moved..."
---

After a number of conversations over the past few years with several other engineers who have moved beyond senior levels into staff and principal positions I've come away with a lot of insights, many of which have seen their way to Twitter or other conversations first, but now it's time to start collecting some of those stories into this new series: Beyond Senior.

What does it mean to go beyond the senior level in an engineering organization?

That's the question we're going to be looking at throughout this series.

## Progressive Influence

You find yourself leading a change that's going to impact a substantial portion of the company, either through your own origination and discovery, or other means.

Take a moment to think with me as to how you would approach such a change. What steps might be involved? How do you intend to land that change? Write it down, I really want you to give this a moment here.

For high-level engineers this process is going to give you a lot of pause.

Company-scale is significant, and the implications of those changes are enough to scare many more seasoned folks. Perhaps ironically the more senior the more deference you pay such changes, and the less senior the more you find yourself saying "well that sounds easy" only to have a very unpleasant time later.

If it's so hard then how does one approach such problems to make them viable? What questions should you be asking? That's what we'll be looking at today, which is a concept I've taken to calling "Progressive Influence."

### Phase One - Qualification and Observation

The first question one should ask when looking at any change of this scale is whether or not the change is even necessary. Are we solving the right problem?

In this phase we take the old adage of "Measure twice, cut once" very much to heart. Before any change we should measure, and in the context of software engineering that means asking a lot of questions and getting as much detail about the problem as is reasonable before making decisions based on it.

That reasonable part is where it gets a bit more interesting, but we'll circle back to that soon enough.

What types of questions should we be asking when qualifying a problem? Well for me a few of my standards might be things like:

* **Why Now?** - Was this a problem before, is it new, why the urgency to get it done now? Priority is key in planning larger changes, and if we don't know relative importance it hinders our ability to roadmap it.
* **Who's Impacted?** - What teams/orgs/etc are in scope? Why? How necessary is this for each of them, or can some defer until later?
* **Who Knows?** - It's impossible to be an expert in every domain and tech, find who knows the most about this surface area and start asking questions, especially the other ones in this list, to make sure you understand what you're getting into.
* **Business Value?** - How does this help the company? Are we saving money, time, both? Does this actually make things safer, or are we justifying? Selling to executives is _impossible_ without this.
* **Resistance?** - Who might object to this? Why? What would it take to negotiate with them? What can we learn from them?

All of this really comes down to who the players are, what their concerns are, how you intend to get people to buy in, and whether or not this is even a problem to be solved. You'd be surprised how often that last one comes up, which is why I put qualification first.

### Phase Two - Documentation and Understanding

So now we get started coding, right? Not quite. In this second phase you collect your findings and write them down. Frequently these end up in something like a design document, architectural design, or whatever form they take at your company.

Your job now that you've measured is to provide as much clarity as you can about the situation as it exists today, and capture that in written format somewhere, so that anyone onboarding to the problem can get a good idea of what's going on.

It's also pivotal for generating consensus on problems, because a significant failure mode is when no one agrees on what a problem is or what terms mean. You don't need to agree on the solutions quite yet, but agreeing on what the problem even is is a substantial value add for these projects and should not be overlooked.

You're distilling knowledge from around the company into a single source, and making that the root of your consensus. As mentioned above in "Who Knows" you're not going to be the expert in all of this, so when writing any of these it is exceptionally valuable to get known experts to aid in writing these documents to make sure it represents them well.

If the owner of a domain or an expert in your company would disagree with how you've presented them that can lead to a lot of friction, so it's best to involve them early at this phase to ensure mutual understanding before you find yourself building something that doesn't actually solve their problems and have to rewrite it anyways. This applies especially to the folks who will be known detractors.

### Phase Three - Agreement and Commitment

Now that things are written down and people acknowledge the problem it's time to start getting agreement from leaders at the necessary level to start work. Tasks at these levels, to be very clear, are impossible to successfully manage by yourself. That means that you fundamentally need others to be willing to participate to move forward.

This does not mean all teams need to agree to immediately start on this work, or even fully agree, and very likely you won't see that happen either. The goal here is to get alignment with at least a few major teams, and if you can't that's a sign that you need to reevaluate and make sure this is actually a problem that needs solved this moment, either way this is valuable information and should be recorded as such.

The larger the scope of a project the less likely it is that it will start right after this step, but rather will be planned in advance to accommodate scheduling and engineer time. This is especially true with non-existential problems, hence the "why now" question qualifying the severity of a problem.

Remember that importance is also very relative. For some teams something may warrant immediate consideration, and for others they can fairly delay for months at a time. Your goal here is to find and qualify teams with immediate concerns and work directly with them, and moving into the next phase together.

### Phase Four - Protection and Warning

Measurement does not only mean understanding a problem, but the scope and impact of that problem as well. When making this large of a change you want to have tools created that help your engineers measure the problem themselves in their domain to assist in planning their teams work.

Assuming you've come to a mutual understanding of the problem above you can take this step to formalize when something happens to be a problem and create systems to warn and measure just how much work may be necessary to solve it.

At a previous company I had worked on a large scale upgrade across 27 teams and 60+ engineers, and if my instructions were limited to "upgrade your part" I would have a lot of lost engineers. Instead I'd created tools to qualify what work was necessary, where, how hard those issues happened to be, and who the experts were that could help them solve particularly difficult ones.

Using that information I could generate full reports on progress for executives to detail what work was left along with previous information on the relative risk to each team versus their progress. It should be noted to be exceptionally careful here not to "name and shame" as much as tell the full story of why certain teams are active and certain ones are waiting, as failure to do so will set people at odds and cause hostility.

In this phase especially I want to start honing in on what it means to be "done" and work with involved teams on getting there and setting up a full roadmap on what time is necessary to solve the problem.

If there are vulnerabilities and SLAs (service level agreements) involved and that roadmap doesn't align with the projected timetable for completion? Well that may mean it's time to escalate to the leaders of teams that may not clear and find out what an appropriate response is.

Managing risk is crucial here, and being able to measure when that risk qualifies as concern is invaluable.

### Phase Five - Mandate and Fiat

What I mean by progressive influence is that each step should progress into the next, and that you use as little power as needed to establish consensus to move to the next phase. Your goals by the end of phase four are to have a majority of teams (~80%+) in scope on a time table, not necessarily done.

Inevitably though there will always be holdouts to every change. It's the nature of engineering, any job really, that there will be blockers that prevent people from participating. It would be unwise to attribute this to malice or negligence, as many times these may be product teams with deadlines. Many times this information should already be clear on who will fall outside the time table in the previous phase, especially when qualifying risk to teams.

The hard cases are the ones which are high risk, but low time. That's where we go to the last step, and the one I try and actively avoid for as long as possible. That would be the company mandate.

This is when I get Directors, Heads of Engineering, VPs, or whoever else involved to start clearing roadblocks on team roadmaps to get something done. Again, only as much power as is needed, as each step up you go when doing this is a much larger disruption and much harder to convince.

The more danger is posed by the problem the sooner I will reach for this lever, but each time you use it and especially the times you use it improperly and too early, the more you erode trust and set teams up against you for any future decisions.

For the above problem I did not use this option until I had 70% of teams in compliance, but falling out of SLA for this problem involved a massive risk to the business, giving more credence to this choice.

For some teams this meant getting onto long term support versions of the software to come into compliance, which makes an interesting point on viable alternatives during high-risk issues.

The more you need this to get work done the more teams will resent you for it and for disrupting their workflows. That's not a badge of honor, that means that somewhere in the above four phases you missed something which should have informed decisions before now, and that's what it means to progressively influence teams to make changes.

### As Much as Necessary

The big point of all of this is that influence is very much about using only as much power as is necessary to solve the problem at hand. Using too much too soon will fracture team relationships and make it far harder to solve future problems, but using just enough gives teams time to plan, delegate, and manage.

These are not problems to be solved by one person or team, they are problems that involve an entire company, and because of that you must be very conscious of conflicting incentives and being as fair to every team as you can.

Just because something is important to you does not mean it is important to every team, and sometimes that means that going to phase five with mandates is completely off the table except in the most necessary of situations.

In fact most of the first two phases are critical to opening your eyes to the concerns of others, understanding their struggles, and creating empathetic plans that work with them rather than against them. In a future post I intend to cover more on consent of teams, as force should be the last possible option, and I believe strongly in soft influence first and foremost.

## Wrapping Up

This is, of course, a very high level overview for a very complicated subject. It's a reflection on how I tend to approach large scale problems, how much influence is necessary at each phase, and how I work to avoid using force except as a last option.

Others may have different approaches, and I would be fascinated to hear yours.

My guiding philosophy for engineering is to understand and work with others, rather than against them, to achieve more and do so in a sustainable manner. As we continue on this series I will be exploring personal stories, observations, conversations, and other bits on my own journey but do remember I am but one voice among so many brilliant ones in our industry.

I look forward to exploring more with you all.
