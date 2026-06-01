---
layout: "post"
title: "Beyond Enumerable: For Want of Better Windows"
date: "2026-05-31"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Enumerable taught us a better path for iteration, what if we applied those lessons to other forms of iteration? This article covers windows and pointers."
---

`Enumerable` is probably one of, if not the most, powerful features of Ruby. It condenses several useful iteration patterns into more common language and allows us to focus on the problem at hand directly rather than by its component pieces like we might in a more imperative language.

The problem is that while it is indeed powerful, there's only so much it can do, so where do we find ourselves with problems that lie beyond `Enumerable`? This series explores some of those shapes, and how the lessons we learned from `Enumerable` are still very much applicable once we step beyond it.

Our first step is into windows.

## The bar Enumerable set

`Enumerable` is the standard by which many other Ruby libraries are judged for their fluency, legibility, and composability. It also represents a stark departure from what we might have found in languages like Java at a similar time before streams became popular.

Consider how you might sum every number over four that happens to be even and double each one in another language. You'd write a loop, an accumulator, and you'd have three distinct ideas inside the body of that loop doing the work of filtering, transforming, and summation:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "imperative_sum", unwrap: true) %>

Certainly it works, but every one of those concerns is in the same place. Filtering, doubling, totaling, all of them are jammed into one body and changing any of them feels like you have to understand multiple components at once to do so. We're dealing with primitives rather than problems in a way that does not quite feel expressive.

`Enumerable` lets you say the <%= claim("imperative enumerable equivalence", "same thing") %> as a sequence of named intentions:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "enumerable_sum", unwrap: true) %>

Each method call is one distinct idea. Keep the even numbers greater than four, and double them before adding them all up to get a final result. The loop, of course, is still there but you're not thinking of the loop any more. You're thinking of a series of steps describing the result rather than the pieces. You can pull any part our of that chain, rename it, test it independently, or swap it out. It's not just a small convenience, it's a different way of thinking about collections.

That's the gift of `Enumerable`, if gives a name to common ways of moving through data:

* `map` is a way to transform every element into another
* `select` allows us to keep elements which match a condition
* `reduce` and `sum` allow us to combine them all into a final result

You even have methods like `group_by`, `tally`, `chunk_while`, and `partition` among a series of others where each one is a name for a traversal you'd otherwise have to hand-roll with a series of loops and temporary variables. Once the name and the abstraction exist, the loop disappears and with it a whole category of bugs that came with it for what amount to fairly common implementations.

This is great, until you manage to find one of the problems that `Enumerable` _doesn't_ have a name for. The temptation might be to go back to manual loops, index variables, and accumulating by hand. Maybe we end up crawling with two-pointers or sliding windows along an array and juggle all the bookkeeping ourselves. Sometimes that's the right call, certainly, but it just does not _feel like Ruby_ now does it?

When we find enough of these common shapes we start noticing patterns, and patterns invite names and abstractions. Ruby taught us that naming and abstracting traversals allows us to say what we mean, clearly, and focus on problems. This doesn't stop being true just because there's no current name for it, if anything it's an invitation to us to find those names and write abstractions which _feel like Ruby_.

Windows are one such shape, and that's what this article intends to explore.

## A problem you've actually had

Say you're staring at a list of response times from a service, and you want a moving average to smooth out the noise. Three samples at a time, slide along, average each group.

You reach for `each_cons`, because that's exactly what it's for:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "each_cons", unwrap: true) %>

This is a Ruby-like answer that reads cleanly, says what it means, and lets you go on to solve other problems. `each_cons` presents us with a sliding window of a fixed size and for many problems that's all we'll need. Adjacent comparisons, n-grams, neighbors, all of it can be handled by `each_cons`

The problem you start to notice, though, is that every window that `each_cons` presents is a plain array. You end up adding all those numbers every time, and the window doesn't remember anything about its current context. It's just a slice.

For three elements that's not an issue, but for larger windows it matters. `each_cons` itself is `O(1)` per slide, but it gives you a plain array with no memory of what came before, leaving the caller doing `O(k)` work per window (re-summing, re-scanning) because there's no incremental state carried between steps.

## Where the floor drops out

Let's say that we change the problem slightly, the way that so many problems tend to change on us too.

We're batching records to send to a third-party API, and that API has a hard cap on request payloads beyond a certain size. Not a fixed count, no, a fixed number of bytes. Given this you want to grab as many records as you can for each batch without going over that limit.

Maybe that means 2 elements, maybe 10, maybe another number altogether! The window size is no longer fixed so `each_cons` suddenly is no longer able to help us. Rails gives us `find_in_batches` but that's also a fixed count, it doesn't know or care how large those records are.

Methods like `chunk_while` and `slice_when` get closer in that they can split a collection into groups, but they have no running context across windows meaning they can't answer the current running sum without recomputing it from scratch every time.

So you write it by hand, the way we all do:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "pack_batches") %>

It works, but look what's actually inside of that. A `current` array, a running `size`, resets for both, and a series of conditions with a guard for empty batches. The line you care about that states that you want groups under a certain bytesize is in there, sure, but it's going to take a bit to find it surrounded by all these more primitive details.

Maybe this happens once, sure, but then you see it again. And again. AND AGAIN. These patterns keep emerging and every implementation you write is subtly different but that shape is right there and your instincts as a Rubyist keep flashing saying "surely there is a better way to do this!"

## The same shape, three more times

When you start looking you'll notice these patterns show up fairly frequently.

**Rate limiting.** You want to know if any user fired more than N requests inside any 60-second window. You walk the timestamps, keep a window of "requests in the last 60 seconds", drop the ones that fell off the back, and check the count.

**Spike detection in logs.** You want the shortest stretch of log lines that contains, say, five errors, so you can find where things went sideways. You walk the lines, grow a window until it has five errors, then shrink from the front to find the tightest one.

**Deduping nearby events.** You're collapsing a noisy event stream and want the longest run where no event ID repeats. Walk the events, grow the window, and the moment you see a duplicate, shrink from the front until it's gone.

Three different domains, now look at what they share:

- You move through a collection one item at a time.
- You keep a *region* of recent items, not the whole thing.
- That region **grows** as you take items in.
- That region **shrinks** when it breaks some rule.
- The region tracks a little state as it moves: a sum, a count, a set of seen IDs.
- You emit something (a length, a batch, a yes-or-no) as it goes.

Every one of them can be described as "keep a window, grow it, shrink it when it breaks a rule." That's not just a convenient descriptor, it's an operation, and one we can abstract over and give a name to.

## It was never about the pointers

If you've seen LeetCode problems or done interview prep you're probably familiar with the idea of "two pointers" and "sliding windows" that have a `left` and a `right` pointers traversing an array. That framing has always bothered me because the pointers always felt like implementation details rather than a whole idea.

Say the batching algorithm out loud, in plain words:

> Start with an empty region. Take in each record. While the region is too big, drop the oldest record. Whatever's left is a batch.

There are no pointers in that sentence. There's a region, it takes things in, it lets things go when it has to, and it knows its own size. The `left` and `right` indices are just one way to make that happen in code.

That's the missing abstraction. Not pointer tricks, but a window that happens to carry some state, and knows when it should grow and shrink. Put that way the shape of our abstraction starts to become clearer.

## Let the window own its state

Pulling on that thread, the thing that always bothered me about these problems is that we lose track of the actual details in bookkeeping rules. We have a `current` array and a running `size` and the one line we care about for this problem (are we within budget) is buried in the middle of all of it. The window is doing two jobs (holding items and tracking their total) and neither one of those are things that I particularly want to manually do every time this class of problem comes up.

Perhaps the first step we need is to create an idea of a window that can keep a track of its own running totals and context about itself:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "window_class") %>

The payoff is that the window maintains its sum incrementally, and getting it is an `O(1)` operation that doesn't involve re-adding each group. The earlier `each_cons` version recomputed the sum for every group, this one doesn't.

Now the batching loop stops tracking a sum by hand and just asks the window:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "pack_with_window") %>

We've taken one step, now we're not manually tracking the `sum`, but look what's still there. We're still writing a loop and managing when to start a new window and when to push a result. Sure, the window is smarter, but the sliding operation still needs work.

## Pull the slide out into a function

Looking at it again the slide starts looking similar across implementations: Take an item in, shrink while some rule holds, look at what's left afterwards. The only thing that changes between problems is what the rule is that decides this, so we extract it as a block function instead:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "slide_while") %>

And now batching is almost nothing:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "slide_while_usage", unwrap: true) %>

The rule is a single function, one line, and the explicit loop is gone. The slide we would otherwise rewrite now lives in one place, making each new problem a matter of passing a different block function.

That said, notice that `records` is being passed _into_ something rather than being the thing we act on, and that we're still hand-building the `Window` that we pass along. We're starting to see a clearer shape here, but we can do better.

## Whose job is the slide, really?

To really feel like `Enumerable` and be more Ruby-like we need the idea of sliding to _belong_ to the collection itself, or some wrapper around it, so let's stop passing data into a function and instead make that wrapper to handle all of the details for us.

There's a trap here though, and it's worth seeing clearly before we step around it.

The first thing you might reach for is to have the stream emit window objects into an `Enumerator` so you can chain `max_by`, `select`, and friends on the result. Sounds great until you remember that the window is mutable. It's still sliding. If you emit it directly, every value in the stream is the _same object_, and by the time `max_by` gets around to comparing them that one window has finished sliding and reports its final state for all of them. Nothing raises, you just quietly get the wrong answer.

The next thing you might try is a snapshot: copy the window's state at each step, freeze it, emit the frozen copy. That works! But now you're allocating an object per step. On two hundred thousand items that's six hundred thousand objects, almost all of them immediately discarded. You've traded the manual loop's bookkeeping for a garbage collector bill, which is not exactly the trade we were looking for.

So the real question becomes: why does the window need to leave at all?

Think about what the consumer actually does with those windows. In the batching problem it calls `max_by(&:size)`. In the moving average it calls `map(&:average)`. In both cases the consumer reads _one number_ off each window and throws the rest away. We're copying an entire array so someone can ask its length, which feels wasteful.

One approach: don't let the window leave. Yield it into a block, let the consumer read what it needs, and move on. Let's build this up piece by piece.

## The stream owns the slide

First, wrap the collection in a stream that knows how to slide a window across it. The stream owns `iterate_windows`, which does the add-evict-yield loop we've been writing by hand this whole time. It yields the _live window_ into a block at each valid position:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_stream_variable") %>

This is our `slide_while` from earlier, but now it lives on the object that owns the data. The stream creates the window, manages the slide, and yields. The caller provides the block. An empty source yields nothing, and a rule that never holds simply produces no valid windows.

But we still have a problem: what does the caller _do_ with those yields? We can't just use `map` or `select` here because those methods would need to hold onto the window between iterations, and we just established that the window is mutable and can't be retained. We need something that consumes each yield immediately and folds it into a result without holding references.

## The builder defers the question

That's where the builder comes in. Instead of running the traversal immediately, `max_window` returns a builder object that _remembers_ the rule but hasn't iterated yet. The terminal method (`max_by`, `first`, `each_window`) is what actually kicks off the traversal, and it does so by passing your block into `iterate_windows`:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_builder") %>

`max_by` folds the window down to the best score as it goes. `each_window` collects non-nil results (filter-map semantics). `first` stops the moment it gets an answer. None of them retain the window after the block returns. They only keep the _score_ your block extracted from it, which is an immutable number. The window can keep mutating because nobody is holding it.

This is a conscious trade. Under the hood we're _not_ using `Enumerable` or `Enumerator`. We're not chaining methods on a lazy stream of objects. That's a deliberate decision: the internals are less "Ruby-like" so that the surface the caller actually touches can _feel_ more Ruby-like. The user writes `max_window { rule }.max_by { question }` and gets the same separation of concerns that `Enumerable` taught us (what to traverse, what to do with each element) without paying for intermediate objects that exist only to satisfy a protocol nobody asked for.

## Window subclasses carry the state

The last piece is specialization. A `SumWindow` maintains a running total. A `CountWindow` maintains a frequency hash. Each stream subclass picks which window to use:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_windows") %>

Adding a new window type is one class with `add`, `evict`, and whatever query methods make sense for that kind of state. The stream and builder don't change at all.

## Putting a name on it

Hide the machinery behind entry points that name the kind of state you care about:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_entry_points") %>

`SumStream` tracks a running total. `CountStream` tracks item frequencies. The caller never sees the window class, never constructs one, never holds one. All of that is internal machinery.

So the batching problem that started this whole thread, "what's the largest batch that fits under budget?":

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_batching", unwrap: true) %>

The moving average?

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_moving_avg", unwrap: true) %>

The longest non-repeating run?

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "rivulet_longest_unique", unwrap: true) %>

Read any of those out loud. The rule is the only thing you write. The window type decides what state to keep, the rule decides what makes a window valid, and the terminal decides what to do with each valid window as it passes. All three concerns are separated, all three are named, and the loop is gone. To me, that starts to feel like Ruby again.

To give a sense of how far this stretches, here's the longest substring without repeating characters (LeetCode 3):

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-windows/rivulet.rb", segment: "example_longest_substring", unwrap: true) %>


Same shape, different rules.

The rate limiting and spike detection examples from earlier need features beyond what we derived here (time-based eviction, `min_window` for finding the smallest satisfying window). The gem handles both, but the core insight is the same: once you have the grow-shrink-yield loop, each new problem is a different rule on a different window type.

## Counting the cost

On a list of two hundred thousand numbers, the snapshot-emitting approach allocates north of six hundred thousand objects to answer "what's the biggest window under budget." The builder approach allocates <%= claim("reducer allocation order", "around 670") %>. The gem optimizes further to under 40 by eliminating the items array entirely. <%= claim("emit reduce equivalence", "Same answer as the hand-rolled loop") %>. The builder ran a bit over twice as fast, and the memory story is the part that holds regardless: this is the difference between `O(n)` extra space and `O(1)`, which is the difference between our version and the hand-rolled pointers we started from.

The window never leaves the traversal. It mutates in place, the block reads what it needs, and the next step overwrites it. That's the same shape as the two-pointer loop, just with the bookkeeping hidden and the rule pulled out where you can see it. We got the lean loop back, and we kept the sentence.


There's a broader lesson here worth naming. Sometimes the most Ruby-like thing you can give your users requires un-Ruby-like things underneath. Mutable state, manual iteration, yielding into blocks instead of returning composable objects. That's not necessarily a compromise. The 600k-object version was "more Ruby" in its internals (Enumerators! Enumerable! Snapshots!) but it cost more in every dimension the caller cares about: memory, speed, and cognitive overhead of understanding what gets allocated where. The version that _feels_ like Ruby to use is the one that made deliberate, pragmatic choices about what happens inside. Good abstractions aren't obligated to be built from the same patterns they present. The standard library makes this same tradeoff everywhere: `Array#sort` is C, `each_cons` is C, `Hash` is C. They present a Ruby-like surface backed by whatever implementation serves the caller best, and nobody objects.

## Where I'd take this next

I've been calling this [`Rivulet`](https://github.com/baweaver/rivulet), since "a small stream with a bit of state flowing through it" is about right, but the name was the last thing to arrive, not the first, and that's the point. We didn't start with it. We started with an ugly loop, got annoyed at the right things in the right order, and the name showed up only once there was finally a thing worth naming.

The gem already goes further than what we derived here. `Rivulet.sum(records, &:bytesize)` sums a property of each object rather than the object itself, which is what the batching problem actually needs in production. `min_window` finds the _smallest_ window meeting a goal (the "shortest stretch containing five errors" from earlier). A `MinMaxWindow` tracks rolling min/max without rescanning via monotonic deques. A `CountWindow` with `covers?` handles substring matching problems. None of those required new traversal logic. They're the same grow-shrink loop with different state riding along, different terminals asking different questions.

What I'd keep resisting is the pull to make it a general stream-processing engine that does graphs and async and everything else. The value was always in staying small. Small enough to understand in one sitting, small enough to trust without reading the source, small enough that the abstraction costs less than the code it replaces.

That's the whole itch, really. We reached for a manual loop the second the standard library ran out of methods, and it turned out the mess in front of us wasn't one problem, it was a shape we'd been rebuilding by hand for years without naming it. Once you name it, and let it be a proper object with the loop tucked away inside, the fiddly version disappears and what's left is the rule you cared about. That's the same trade `map` and `select` made for us a long time ago, and I don't see a reason to stop making it now.

Windows were the first shape I wanted to name. The next post in the series goes after another one.
