---
layout: "post"
title: "Beyond Enumerable: Counting Distinct with HyperLogLog"
date: "2026-06-15"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Counting distinct values exactly means remembering all of them. HyperLogLog does it in 16 kilobytes. This post builds from coin flips to bitmaps to the algorithm Redis uses behind PFCOUNT."
---

How do you count distinct values when you can't afford to remember them? Counting distinct _requires_ remembering what you've already seen, and that memory grows with the data. A `Set` of a billion user IDs is gigabytes. The streaming tricks from the last post don't help because there's no way to combine "is this new?" into a running total without holding onto what you've already seen.

In the last post we made a trade to offload batches to files to avoid maxing out RAM, and in this post we're going to make another trade which will make developers uncomfortable: we're trading exactness for space savings at scale.

## We called heads

Humor me for a moment. Say that you were flipping coins and someone happened to get four heads in a row, not exactly uncommon but it's much less likely than say one or two heads in a row. How about twenty? Each flip is 50/50, so twenty in a row is ½ multiplied twenty times, which is 1 in `2**20`, or <%= claim("twenty heads odds", "one in about a million") %>. That's a couple of weeks of non-stop flipping, give or take. If someone managed to land that you'd think it's either a rigged coin or they've been at it for a while. Either that or they're really lucky, but hold onto that thought, we'll get back to it.

There's an interesting insight in there though: We know _immediately_ how likely that is, _without_ ever flipping those coins.

What does that have to do with this article though? Coin flips are, in essence, binary: two outcomes, heads or tails, ones or zeros. If you convert something into a stream of bits (where each position can only be 0 or 1) you have a collection of those exact coin flips. As it happens it's also pretty rare to have a bunch of zeroes at the start of a binary string.

In programming we have hashing functions which can transform something into an evenly-spread series of ones and zeroes, where each bit is equally likely to be 0 or 1. Why not look at the data directly? Because real data isn't evenly spread. User IDs are sequential, names cluster, timestamps are monotonic. Leading-zero runs on raw data would be biased. Hashing scrambles any input into uniform bits, which is the only reason the coin-flip math applies.

> **What's a hash function?** It takes any input (a string, a number, an object) and produces a fixed-size number. The same input always gives the same output, but different inputs give wildly different outputs with no discernible pattern. Think of it like a fingerprint: deterministic, fixed size, and scrambled enough that similar inputs don't produce similar outputs.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hashing") %>

We're using SHA-256 truncated to 64 bits. The specific algorithm doesn't matter, what matters is that its output bits are evenly spread. Each hex character packs 4 bits, so the first 16 hex characters give us 64 bits, sixty-four coin flips to judge rarity by.

## Step one: a filling bitmap

What if we allocated a big chunk of bits, all starting at zero, and used each hashed value to pick one of them to flip on?

That's a bitmap: a fixed-size array where each position is a single bit, either 0 (never seen) or 1 (something hashed here). It doesn't store the items themselves, it stores _evidence that something landed in this spot_. Two items hashing to the same position flip the same bit, so we lose the ability to tell them apart, but we don't care about identity. We care about how many _distinct_ things have left marks.

The simplest version is a boolean array:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting_string") %>

As more distinct items arrive, more positions flip to `true`. Duplicates land on positions that are already `true` and leave no trace. So the number of positions still `false` tells us how many distinct items have passed through.

How do we turn that into a number? Here's the math:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting_formula") %>

That's [Linear Counting](https://doi.org/10.1145/78922.78925) (Whang, Vander-Zanden, Taylor, 1990). A <%= claim("million bit map size", "128 KB") %> map estimates fifty thousand distinct items to within a few percent, and a thousand copies of one value still read as one.

The problem happens when the entire thing fills and you end up dividing by zero, breaking the estimate. That's called _saturation_, the point at which the structure can't tell the difference between "a lot" and "a lot plus one." To count billions of items you'd need a bitmap _so large_ that it defeats the point, so we're going to need something which _doesn't_ fill up.

## Step two: the leading-zeros insight

If bitmaps count by how full it got, is there a different signal we could use? One that _doesn't_ fill?

Remember the coin flips? Each bit of a hash value is an independent flip. A run of leading zeros is like a run of consecutive heads, and the longer the run the rarer it is:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "leading_zeros_string") %>

A hash value with no leading zeros (first bit is 1) shows up about half the time. Ten leading zeros shows up about once in `2**10` distinct values. Twenty shows up once in about a million.

Why does that matter? Flip the logic around: if the longest run you've ever seen happens about once in a million, you've probably had about a million chances at it. A maximum run of 30 means you've likely seen around `2**30` distinct values. Unlike the bitmap, this never saturates because longer runs keep appearing as more distinct values arrive. The problem is that a single really lucky streak can throw the whole guess off.

## Step three: taming the noise

One unlucky (or really lucky, depending on your POV) series of flips and this entire idea goes out a window. Does that make this algorithm invalid? No, not really, we handle it much the same as we handle other noisy signals: We take a lot of them and average.

But what kind of average? A regular (arithmetic) average lets one outlier drag everything up, so we're going to need something else. The harmonic mean weights toward smaller values, so a single large number barely registers:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "harmonic_mean") %>

The code comments walk through a worked example, but the short version: if three buckets say "1" and one bucket says "100" because it got lucky, the arithmetic mean gives you 25.75 (dominated by the outlier). The harmonic mean gives you 1.33 (the lucky one barely moves the needle). That's the property we want when one bucket's measurement might be really danged lucky.

## Step four: many registers, one estimate

We need many independent measurements from a single stream. Use part of the hash value to pick a bucket, and the rest to do the leading-zero measurement. Each bucket runs its own coin-flip experiment independently, so no single lucky hash value can corrupt more than one.

Here's the whole thing, using string operations so every step is visible:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_string_add") %>

More buckets means less noise, same reason polling more people gives a better survey. With 16,384 buckets the error is about <%= claim("hll standard error", "0.8%") %>, meaning if the true count is a million the estimate will land between roughly 992,000 and 1,008,000.

That's [HyperLogLog](http://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf) (Flajolet, Fusy, Gandouet, Meunier, 2007).

## Watching it work

The algorithm is easier to believe when you can see it filling up. Here's a tiny version with 16 buckets processing ten names:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_trace") %>

Notice how `eve` lands in bucket <%= claim("eve bucket is 8", 8) %> with rank <%= claim("eve rank is 2", 2) %>, but bucket 8 already has rank <%= claim("bob rank is 4", 4) %> from `bob`, so the register doesn't change. That's the "keep the max" rule doing its job.

The estimate after 10 distinct items is <%= claim("trace estimate", 11) %>. Off by one. With only 16 buckets the noise is high, but bump to 16,384 and it tightens to under 1%.

## Merge: combining counters across servers

Say you have ten servers, each counting distinct users independently. You want the total across all of them. With a `Set` you'd have to ship every set to one machine and union them. With HyperLogLog you ship a few kilobytes from each and combine in one pass.

How? Each bucket stores "the longest run I've ever seen." To combine two counters, take the bigger number from each bucket.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_merge") %>

Redis exposes this as `PFMERGE`. This is the property that makes HLL worth reaching for over a simple counter: you get composability for free.

## Where you've already used this

If you use Redis, you've used this. `PFADD` adds an item, `PFCOUNT` returns the estimated distinct count, `PFMERGE` combines two counters. The "PF" stands for Philippe Flajolet, one of the paper's authors.

Redis uses 16,384 buckets, 6 bits per bucket, <%= claim("hll size", "twelve kilobytes") %> total, 0.81% error. Same structure we built. Twelve kilobytes whether the count is a thousand or five billion.

## Making it fast: the bit-packed version

For teaching purposes the string version is more accessible. The problem is that it's slow. Converting to a 64-character string on every `add` is expensive in a hot loop. The production version does the same operations with bit shifts and masks.

If you're comfortable with bit manipulation, here's the optimized version. If not, skip this section. The algorithm is identical:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_add") %>

Each operation maps to the string version:
- `hash >> (64 - precision)` grabs which bucket
- `hash & ((1 << remaining) - 1)` grabs the remainder
- `remainder.bit_length` finds the first 1-bit

The bit-packed Linear Counting packs 64 switches per integer instead of using a boolean array:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting") %>

Both produce <%= claim("string and bit match", "identical") %> results to the string versions. The difference is speed. At precision 14 the implementation lands within 0.1% at a million distinct, 0.4% at 100k, and 0.65% at 5M, all inside the 0.81% error the math predicts.

## Wrapping Up

Twelve kilobytes of memory, sub-1% error, works the same at a thousand items or five billion, and two counters merge by taking the max of each bucket. That's the trade you're making when you give up exactness: a structure that never fills up and never needs to remember what it's seen.

Next up we apply the same ideas to a different question: not "how many distinct" but "have I seen this one before." That's Bloom filters.
