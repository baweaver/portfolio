---
layout: "post"
title: "Beyond Enumerable: Streaming and External Sort"
date: "2026-06-09"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Enumerable assumes the whole collection fits in memory. This post is about what happens when it doesn't, built up one step at a time from lazy streams to external merge sort."
---

`Enumerable` is great for processing data right up until you find out what an OOM is and watch your swap space start to eat itself alive. The algorithm might be perfectly correct, but once a file is large enough you have to fundamentally change the way you approach it.

Back at Playstation we were processing near-petabyte scale logs across PSN with Spark, Kafka, and OpenTSDB. Ruby isn't the production tool for that scale, and it doesn't need to be. But most of the materials on streaming and external sort live in Scala or Python, and learning these ideas in a language you already think in builds the intuition that transfers when you step into those frameworks. So let's see what it looks like in Ruby.

## A file bigger than the laptop

You're looking through access logs. On your local machine it's what, a few thousand lines? Counting 500s is straightforward enough to express:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "readlines_count", unwrap: true) %>

Then you try and ship that same code, and find out the hard way that the real file is forty gigabytes, if not worse. It's not going to fit into ram and `File.readlines` is going to try and load the entire thing at once, causing the OS to kill the process. So how do we handle this?

The answer is to stop holding the whole file.

## Streaming what you can

When dealing with giant files we often only need a single line at a time. `File.foreach` does exactly this by reading in one line at a time, allowing the previous one to get collected:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "foreach_count", unwrap: true) %>

With that one change the memory usage goes from 40gb to 23mb (Ruby's baseline), and that applies whether the file is three million or three _billion_ lines long. It'll still take a while though.

The same works for anything that condenses the stream to a single result. Sums, minimums, maximums, "does any line match":

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "streaming_sum", unwrap: true) %>

Do be careful though as `map` and `select` only _look_ like they should stream, but in reality they run the complete collection bringing us right back to the initial issue. That's what we have `lazy` for, to process elements one at a time rather than as one whole go at once, until a terminal method is called to start the processing:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "lazy_first", unwrap: true) %>

On a million-line file the eager version touches all million lines. The lazy version touches five.

> **Note:** `lazy` isn't free. Each element pays a small per-step cost, so for data that fits in memory the eager versions are faster. The win is bounded memory and short-circuiting, not speed. Reach for it when the collection is large or infinite, not as a default.

## Where streaming hits the wall

That works great, up until you need more than the next element to make a decision. `sort` and `uniq`, for example, will break our current techniques because they require _the entire_ context. How does one `sort` something you can't hold?

## Cut it into pieces that fit

If you can't hold all of it, hold what you can instead. By breaking this problem into smaller workable chunks we're able to take on much larger files:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "write_sorted_runs") %>

> **Note:** `each_slice` takes a block here on purpose. If you chain it lazily with `.map { ... }`, the runs are never written, you get back a lazy enumerator instead of your array of files. The block form forces the iteration while still holding only one chunk at a time.

Great, but now we have a bunch of 1gb files to deal with, how do we approach merging them back together without managing to approach the full file size again?

## Merging sorted things

Remember back to earlier where we were able to leverage reading only one line at a time? If we have a bunch of files which are already sorted, let's say two, then we only ever need to deal with comparing two numbers at a time:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "merge_sorted_pair") %>

We only need to deal with the current front of whatever sorted files we're dealing with, allowing us to offload a lot of these concerns to disk. Now we feel clever, riiiight up until we remember there were actually forty of those files, not two.

Saying it out loud though, remember back to earlier articles: We want the next smallest number, and after each one we're going to add the next number from whatever file we just grabbed from. Sounds a lot like a Heap right?:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "heap") %>

We hold exactly one element per source. From there we pop the smallest, emit it, then grab the next element from the source we got it from. When a source is out of elements it stops contributing them, and we can wrap the whole thing into an `Enumerator` to provide a Ruby-like abstraction over the whole thing:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "kway_merge") %>

Now finding the minimum went from scanning forty streams to an `O(log k)` per element. With k runs and N total records, the merge is `O(N log k)` time holding only k elements at once. The data pours through a fixed-size heap regardless of how large it is.

Heaps become exceedingly useful for tasks like this, so if you've not read the [previous article on heaps and priority queues](/writing/2026/06/06/beyond-enumerable-heaps-and-priority-queues/) definitely give it a read.

## Spill to disk, then merge it back

Now let's put them back together:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-streaming/streaming.rb", segment: "external_sort") %>

That's an [external merge sort](https://en.wikipedia.org/wiki/External_sorting#External_merge_sort). Unix `sort` does the same thing when a file exceeds RAM, and so do databases when sorting more rows than fit in their buffers.

One caveat: the caller has to keep the run file array alive until the stream is drained. If those `Tempfile` objects get reaped the files vanish out from under the merge. Easiest fix is to return both the stream and the array, and let the caller close the files explicitly when it's done consuming.

## Counting the cost

The external sort produces the same result as `Array#sort` at every size tested. The difference is memory:

| records | in-memory sort | external sort | runs |
|--------:|---------------:|--------------:|-----:|
| 2M | 55 MB | 39 MB | 4 |
| 5M | 117 MB | 51 MB | 10 |
| 10M | 184 MB | 62 MB | 20 |
| 20M | 365 MB | 79 MB | 40 |

In-memory climbs at roughly 17 MB per million records. External sort stays nearly flat because its working set is one chunk plus the heap, regardless of total input size.

Great, so we use external sorting instead, especially if it's that much more efficient! Except it _does_ incur a cost: time. On twenty million numbers the in-memory sort took about fifteen seconds, the external version closer to three minutes.

Most of that gap is the pure-Ruby heap comparing through a lambda hundreds of millions of times, plus parsing every integer twice (once to disk, once back). The algorithm is the same one [`sort(1)` uses](https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html) (an [external R-way merge](https://unix.stackexchange.com/questions/279096/scalability-of-sort-u-for-gigantic-files)), `sort(1)` runs it in C. You trade wall-clock time for bounded memory. When the input is larger than memory you don't have a choice.

At that scale Ruby stops being the right tool and you reach for Spark, Flink, or Kafka Streams. But the underlying ideas, chunking, streaming, merge via heap, don't change when you switch languages. They show up in Scala's `sortMerge` joins, in Python's `heapq.merge`, in every database's query planner.

When even streaming with bounded memory isn't enough, when the data is so large that exact answers become impractical, you start making different trades entirely. Approximate counts instead of exact ones. Probabilistic membership checks instead of full sets. Fixed-size sketches that merge across machines. That's the next post.
