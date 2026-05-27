---
layout: "post"
title: "On On-Call, Operations, and Holidays"
date: "2018-12-28"
categories: []
tags: []
description: ""
---

Operations can be a challenging job, especially around the holidays. Recently there’s been a lot of talk around on-call, so here are my two cents on the matter.

![](/images/posts/2018-12-28-on-on-call-operations-and-holidays/img-422c8d78.png)

If you’d like a more humorous operations story, you might enjoy this article instead:
[**Scaling Christmas — An Illustrated Adventure**
*The lemurs are back! This time they’ve come for a special Christmas-themed adventure about how Christmas scales, using…*medium.com](https://medium.com/square-corner-blog/scaling-christmas-an-illustrated-adventure-a2ea739f5451)

## Threads Abound

Now before we get into this, there have been several interesting threads on Twitter on this matter from people far more experienced than myself.

They have a lot of wisdom in the area, and I would highly suggest reading a few of these:

<iframe src="https://medium.com/media/d9a10a30394b50465b61fc45edc6d300" frameborder=0></iframe>

<iframe src="https://medium.com/media/d7aa91115f9f0bc812ec4a1169b3e4ba" frameborder=0></iframe>

<iframe src="https://medium.com/media/1b9093ec6f8546aedbd7b95d848954db" frameborder=0></iframe>

<iframe src="https://medium.com/media/72f42b96214e21be4d688ba7eb5e76f4" frameborder=0></iframe>

## Shall We Get Started?

So with that mentioned, shall we get started?

I worked operations at Playstation for about 3 years, and we saw some real fun during holiday seasons.

I’ve also worked as an application developer for several years prior and after.

Now this all to say I’ve seen both sides of the proverbial Ops fence, and what I’ve seen is not particularly pretty.

If you take nothing else from this article, remember this:

**Your on-call practices reflect the health of your organization and cross-team collaborations**. It can either be an indictment against, or a testament to for how your teams work together.

Lean towards the latter, because the former will eventually destroy your engineers.

## Operations Folks are Engineers

<iframe src="https://medium.com/media/0e97d6416317d6c493c26353cbea5081" frameborder=0></iframe>

With the recent movement towards DevOps and SRE type roles, there’s an assumption that operations folks are writing automation tools and infrastructure components.

In the past there was an assumption of SysAdmins fighting fires and troubleshooting as a full time job. That’s not accurate in todays organizations as they’re expected to know a truly massive amount of infrastructure automation tools.

Kubernetes, AWS, GCS, Jenkins, Databases, and a whole lot more are under the purview of operations. Everything that keeps your application running seamlessly falls on them.

Trying to set all this up and keeping details straight is a hard job. Quite frankly if I never had to worry about the details of that again I’d be thrilled, which is probably why AWS is so prevalent now.

Back at Playstation I worked on the deployment pipeline on top of AWS before a lot of the nicer tools came out around that. We had to support and maintain that application, add features, and fire fight around some other operations issues.

It wasn’t hacked together perl scripts, it was an entire Rails application on top of a lot of other tools and features in the cloud ecosystem. We were full time developers dealing with an ops workload as well. If that tool went down, everything else was screwed, so being on call for it was absolutely essential to fix issues.

That said, there were some issues other departments in operations faced.

## Urgent! Urgent!

Now remember how Ops engineers are building full applications? That’s a full time job by itself.

There were cases in the past where application engineers needed databases created or other operations resources allocated. Not all of this was automated yet, so we had systems to submit requests.

The problem is that some application teams would wait until the last minute before major deployments before announcing their needs.

This is the first litmus test of your organization.

Do you kick back to the application teams for irresponsibility? …or do you derail the database teams to immediately respond to fires?

The first is what should happen, and is an indictment of poor cross-team communication. Ops teams have schedules too, and unplanned work derails that.

The second is what normally happens. The Ops team is put on fire fighting and emergency responses while still being expected to develop their own applications on time.

If your management does not stick up for Ops folks in this position, *run*.

**Management who will not stick up for their Ops engineers and treat them as magical fire fighters are what leads to severe burnout and people hating Ops.**

## Ops is not Glamorous

Speaking of management, it needs to be said that Ops is not a glamorous field. Very rarely is there recognition for work done as there might be in application development where there’s a direct line to the bottom line.

This, despite potential cost savings and other efficiencies that can be delivered by a good Ops team, is why many will not take the job. There’s no recognition in it, you can only inevitably fail in a bad organization.

It’s admittedly why I didn’t want to do Ops again, and why I’m very cautious before taking another role in that field. In fact that’s one of the first questions I tend to ask in interviews is how are on-calls and ops teams leveraged.

**Your Ops engineers keep everything running behind the scenes, don’t take them for granted.**

## On Call Proxies and App Owners

Ops teams are typically the first line of defense against issues, and are typically the ones to get paged for anything and everything.

**If your Ops folks are getting paged for application failures, there’s an issue**.

You’ve essentially relegated them to be very highly paid proxies for Jira tickets against application teams instead of focusing on infrastructure work.

The duty of application maintenance and ensuring that it runs correctly in production are application engineers.

Without investment in the production on-call schedule application engineers will naturally be more lax about catching errors in their applications which could be signs of substantial issues.

By putting Ops folks in charge of this, you’ve positioned them as a single-point-of-failure for potentially tens to hundreds of applications. Such an assignment is not sustainable in the least, and will lead to constantly being paged at all hours of the day.

**Application engineers should own their code through its full lifecycle, and that includes logging, monitoring, and on-call rotations in the production environment.**

## On Call is Extra Work

Now that being said, on call is its own job. Expecting an engineer on call to deliver at a normal rate is just as bad.

Expecting that engineer to be on 24/7/(weeks oncall, typically 1–2) is extra work for them, and should be rewarded as such.

**Treating it as another part of the job destroys work-life balance**.

That applies to everyone, single or married or whatever else. People have lives outside of work, and continually dipping into that time leads to burn out and hatred of on-call rotations.

Ask your engineers how many of them enjoy being on call. That number is going to be low, and disgruntled engineers are more likely to cut corners and make mistakes, compounding issues and potentially missing severe outages before they happen.

Now extra work may involve extra pay or other incentives. There were times when holidays rolled around that overtime was offered for people willing to work, and we were much more likely to do so.

Fast forward to mandatory holidays and all you got were a bunch of disgruntled engineers who would ignore anything that wasn’t going to cause an existential crisis for the company.

## So What Do You Do?

As mentioned earlier, your on-call and ops teams reflect the health of your organization.

By sharing the load and ensuring equitable time is being given to pay down debt and reduce junk alerts you can start to create a more enjoyable on-call experience.

Respect your Ops teams, because they’re every bit the engineering org as application engineers.

## Further Reading

That said, I believe there are those who are far more skilled at explaining solutions to these issues. Here are a few potential reads this holiday season on the topic (I won’t use referral links on principle):

The Google SRE book is a gold mine of best practices and ways to run an SRE team, and is available free online:
[**Google - Site Reliability Engineering**
*The Site Reliability Workbook is the hands-on companion to the bestselling Site Reliability Engineering book and uses…*landing.google.com](https://landing.google.com/sre/books/)

[DHH](undefined) and [Jason Fried](undefined) wrote a book on work-life balance that I’ve enjoyed reading lately quite a bit:
[**It doesn't have to be crazy at work**
*Trusted by millions, Basecamp puts everything you need to get work done in one place. It's the calm, organized way to…*basecamp.com](https://basecamp.com/books/calm)

[Tom Limoncelli](undefined)’s Time Management for System Administrators is a classic I’ve kept a copy of around for years:
[**Our books - Tom Limoncelli's EverythingSysadmin Blog**
*Time Management for System Administrators Time is a precious commodity, especially if you're a system administrator. No…*everythingsysadmin.com](https://everythingsysadmin.com/books.html#tm4sa)

Now there are certainly others, and I would love to hear about them in the comments section!

## Wrapping Up

As I’ve mentioned before, and will continue to do so: **Your on-call and ops teams reflect the health of your organization**.

Do right by your Ops folks this holiday season.

I can’t say I’m a particular expert in operations, these were just some of my personal experiences and observations while working in the field. I hope you’ve found this valuable.

Hoping everyone has a great new years, see you all in 2019!

![](/images/posts/2018-12-28-on-on-call-operations-and-holidays/img-937e487b.png)

**Join our community Slack and read our weekly Faun topics ⬇**

![](/images/posts/2018-12-28-on-on-call-operations-and-holidays/img-f48cfc42.png)

### If this post was helpful, please click the clap 👏 button below a few times to show your support for the author! ⬇
