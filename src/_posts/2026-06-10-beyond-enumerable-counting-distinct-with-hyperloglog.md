---
layout: "post"
title: "Beyond Enumerable: Counting Distinct with HyperLogLog"
date: "2026-06-10"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Counting distinct values exactly means remembering all of them. HyperLogLog does it in 16 kilobytes. This post builds from bits to bitmaps to the algorithm Redis uses behind PFCOUNT."
---

With many of the articles in this series they were grounded in concepts that I have actively used for years, but during all of my research around these posts I started to discover a lot of whitepapers and materials that went beyond what I knew, so I decided to look more into them. From that comes the next few articles on topics beyond my current understanding, and as always the most effective way that I learn is to teach and really dig into something.

We're still covering topics beyond `Enumerable`, but these next articles take a step even beyond that to where the tensions and trade-offs we're exploring add correctness to the negotiation table. When data becomes so big that even external sorts, MapReduce, and other techniques start to buckle we're entering some rarefied territory where we're out of traditional options but the spice must flow.

The first question that kept coming up: how do you count distinct values when you can't afford to remember them? Counting distinct _requires_ remembering what you've already seen, and that memory grows with the data. A `Set` of a billion user IDs is gigabytes. The streaming tricks from the last post don't help because there's no way to fold "is this new?" into a running total without holding onto what you've already seen. Something has to give, and the thing that gives is exactness itself.

## We called heads

Humor me for a moment. Say that you were flipping coins and someone happened to get four heads in a row, not exactly uncommon but it's much less likely than say one or two heads in a row. How about twenty? If someone managed to land that you'd think it's either a rigged coin or they've been flipping for a while to get to that number. Point being the more consecutive heads someone gets the less likely that was to happen.

Why does that matter? Because that rate is predictable, and if someone managed to land twenty heads you can reasonably assume that they've been at the coin flipping game for a number of days or weeks by that point considering the odds of that happening are <%= claim("twenty heads odds", "one in about a million") %>, or roughly two weeks of non-stop flipping. Either that or they're really lucky, hold onto that thought, we'll get back to it.

It might take the person doing the flipping a few weeks, but we know how likely it is to happen in fractions of a second. If we see that result we have a pretty danged good guess as to how often they'd flipped to get it.

What does that have to do with this article though? Coin flips are, in essence, a binary. Heads or tails, ones or zeros, and if you happen to convert something into a binary stream you have a collection of those exact ones and zeros. As it happens it's also pretty rare to have a bunch of zeroes at the start of a binary string, getting us right back to that probability.

In programming we have hashing functions which can transform something into a uniform shape, like our ones and zeroes, and the chances there are a ton of zeroes? It turns out that's a really useful property:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hashing") %>

This is the hashing function we're going to be using, the first 16 hex characters of a SHA-256 digest, and converting that to an integer. That gives us sixty-four effective coin flips to judge rarity by, or `2**64` which is a really danged big number of about 18.4 quintillion which is a lot of headroom to play with that we can reason about probabilistically.

## Thinking in bits

Look, unless you're deep in core, or were a C programmer, chances are you're not making a habit of bit manipulation in Ruby. Most Ruby developers are going to get lost the second we start looking at bit twiddling, myself included, but the usefulness of them warrants some discomfort to understand the underlying mechanics and how they can serve us.

For the sake of this article we're going to need to read _portions_ of a number's binary representation, like individual bits or series of bits, and that's going to involve learning a few small tools to do so effectively.

**Right shift (`>>`)** drops the bottom bits, keeping the top:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_right_shift") %>

**Masking (`&`)** keeps specific bits and zeros the rest:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_mask") %>

**OR-assignment (`|=`)** sets a specific bit without touching any others:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_set") %>

**Checking a bit** reverses the process:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_check") %>

One pattern shows up repeatedly in the code below: `position >> 6` and `position & 63`. Since we pack bits into 64-bit words, dividing the position by 64 tells you which word, and the remainder tells you which slot within it.

## Step one: a filling bitmap

So we have hashes and we know how to flip individual bits. What if we allocated a big chunk of bits, all starting at zero, and used each hash to pick one of them to flip on?

That chunk is a bitmap: a fixed-size array where each position is a single bit that's either 0 (never seen) or 1 (something hashed here). It doesn't store the items themselves, it stores _evidence that something landed in this spot_. If two different items hash to the same position they both flip the same bit, which means we lose the ability to tell them apart, but that's fine because we don't care about identity. We care about how many _distinct_ things have left marks.

As more distinct items arrive, more bits flip from 0 to 1. Duplicates land on bits that are already 1 and leave no trace. So the number of bits still at zero tells us something about how many distinct items have passed through. More zeros remaining means fewer distinct items. Fewer zeros means more.

The math to turn that into an estimate: with `total_bits` bits and `zeros` of them still clear, the distinct count is approximately `-total_bits * Math.log(zeros.to_f / total_bits)`.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting") %>

That's [Linear Counting](https://doi.org/10.1145/78922.78925) (Whang, Vander-Zanden, Taylor, 1990). A <%= claim("million bit map size", "128 KB") %> map estimates fifty thousand distinct items to within a few percent, and a thousand copies of one value still read as one.

Once every bit is set though the formula divides by zero and the estimate breaks. To count billions you'd need a bitmap so large it defeats the whole point of not storing the items. We need something that doesn't saturate.

## Step two: the leading-zeros insight

Remember the coin flips from earlier? A hash with no leading zeros (top bit is 1) shows up about half the time. Ten leading zeros shows up about once in `2**10` distinct values. Twenty shows up once in about a million. The longest leading-zero run you've ever seen is a rough proxy for how many distinct items have passed through.

A maximum run of 30 suggests around `2**30` distinct items. The number never saturates because longer runs keep appearing as more distinct values arrive.

One number is noisy though. A single item that happens to hash to thirty leading zeros doubles your estimate. We need more than one measurement.

## Step three: many registers, one estimate

Split each hash into two parts. The top `precision` bits pick one of `2**precision` registers. The remaining bits give the leading-zero count. Each register keeps only the _maximum_ run it has ever seen.

Now instead of one noisy estimate you have thousands of independent ones. Average them and the noise cancels. The standard error drops like `1 / sqrt(register_count)`, so 16,384 registers gives about <%= claim("hll standard error", "0.8%") %> error.

The specific average matters. An arithmetic mean lets a few unlucky registers dominate. A _harmonic_ mean weights them so outliers can't blow things up. That refinement is [HyperLogLog](http://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf) (Flajolet, Fusy, Gandouet, Meunier, 2007):

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog") %>

The code comments walk through every bit operation in detail. At precision 14, the 64-bit hash splits into a 14-bit register index and a 50-bit remainder. The register stores the longest leading-zero run seen in that remainder. The whole structure is 16,384 small numbers.

## Merge: the property that earns its place

Two HyperLogLog sketches over different data combine by taking the element-wise maximum of their registers. A register holds "longest run seen," and the longest run across the union is the larger of the two.

Count distinct users on each of a thousand servers, ship sixteen kilobytes from each, take the maximums, and you have the distinct count across all of them without any server needing the others' data.

This is what Redis exposes as `PFMERGE`.

## Where you've already used this

`PFADD` and `PFCOUNT` in Redis are HyperLogLog with exactly the parameters we built: 16,384 registers (precision 14), 6 bits per register, about 12 KB total, standard error of 0.81%. The 64-bit hash that lets it count past 2^32 distinct values came from a [2013 Google paper](https://research.google.com/pubs/archive/40671.pdf) (Heule, Nunkesser, Hall).

If you've ever called `PFCOUNT` on a Redis key, that number came from the harmonic mean of 16,384 register maxima. <%= claim("hll size", "Twelve kilobytes") %>, whether the count is a thousand or five billion.

## Measuring it

At precision 14, this implementation estimated 1,002,986 distinct values against a true million (0.3% error), and held similar accuracy at 100k and 5M distinct.

The next post takes the same bit-packing toolkit and applies it to a different question: not "how many distinct" but "have I seen this specific one before." That's Bloom filters.
