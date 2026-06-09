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

We're still covering topics beyond `Enumerable`, but these next articles take a step even beyond that to where the tensions and trade-offs we're exploring add correctness to the negotiation table. When data becomes so big that even external sorts, MapReduce (distributed batch processing across clusters), and other techniques start to buckle we're entering some rarefied territory where we're out of traditional options but the spice must flow.

The first question that kept coming up: how do you count distinct values when you can't afford to remember them? Counting distinct _requires_ remembering what you've already seen, and that memory grows with the data. A `Set` of a billion user IDs is gigabytes. The streaming tricks from the last post don't help because there's no way to combine "is this new?" into a running total without holding onto what you've already seen. Something has to give, and the thing that gives is exactness itself.

## We called heads

Humor me for a moment. Say that you were flipping coins and someone happened to get four heads in a row, not exactly uncommon but it's much less likely than say one or two heads in a row. How about twenty? Each flip is 50/50, so twenty in a row is ½ multiplied twenty times, which is 1 in `2**20`, or <%= claim("twenty heads odds", "one in about a million") %>. That's a couple of weeks of non-stop flipping, give or take. If someone managed to land that you'd think it's either a rigged coin or they've been at it for a while. Either that or they're really lucky, hold onto that thought, we'll get back to it.

It might take the person doing the flipping a few weeks, but we know how likely it is to happen in fractions of a second. If we see that result we have a pretty danged good guess as to how often they'd flipped to get it.

What does that have to do with this article though? Coin flips are, in essence, binary: two outcomes, heads or tails, ones or zeros. If you convert something into a stream of bits (where each position can only be 0 or 1) you have a collection of those exact coin flips. As it happens it's also pretty rare to have a bunch of zeroes at the start of a binary string, getting us right back to that probability.

In programming we have hashing functions which can transform something into an evenly-spread series of ones and zeroes, where each bit is equally likely to be 0 or 1, and the chances there are a ton of zeroes at the start? It turns out that's a really useful property.

> **What's a hash function?** It takes any input (a string, a number, an object) and produces a fixed-size number. The same input always gives the same output, but different inputs give wildly different outputs with no discernible pattern. Think of it like a fingerprint: deterministic, fixed size, and scrambled enough that similar inputs don't produce similar outputs.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hashing") %>

This is the hashing function we're going to be using. SHA-256 is a specific hash algorithm (the name doesn't matter, what matters is that its output bits are evenly spread). The "digest" is the number it spits out, and "hex characters" are the digits 0-9 and letters a-f, a compact way to write binary. Each hex character packs 4 bits, so the first 16 of them give us 64 bits, sixty-four coin flips to judge rarity by. `2**64` is about 18.4 quintillion which is a lot of headroom to reason about probabilistically.

## Thinking in bits

Look, unless you're deep in core, or were a C programmer, chances are you're not making a habit of bit manipulation in Ruby. Most Ruby developers are going to get lost the second we start looking at bit twiddling, myself included, but the usefulness of them warrants some discomfort to understand the underlying mechanics and how they can serve us.

For the sake of this article we're going to need to pull a hash apart (some bits pick a bucket, the rest get measured) and flip individual bits on and off. There are only a few moves, and here's each one on a small number.

### What binary is

A number in binary is a row of 0s and 1s, where each slot is worth twice the one to its right: 1, 2, 4, 8, 16, 32, 64, 128 and so on. Ruby writes binary with a `0b` prefix, so `0b10110110` is 128 + 32 + 16 + 4 + 2 = 182. We number the slots from the right starting at 0, so bit 0 is the rightmost.

### Three shortcuts to keep in your pocket

Everything ahead is one of these three in disguise:

- Shifting left by n (`<< n`) is multiplying by `2**n`
- Shifting right by n (`>> n`) is dividing by `2**n`
- Masking off the bottom n bits (`& (2**n - 1)`) is the remainder of that division

If you remember those three, every bit trick below is legible.

### Left shift (`<<`) slides bits up

This is multiplication by a power of two. Slide a `1` up three positions and you get 8, because each position doubles the value:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_left_shift") %>

We'll use this constantly for building masks. A `1` shifted into a specific position gives us a number with only that bit set.

### Right shift (`>>`) slides bits down

The inverse: division by a power of two. Slide everything down five positions and whatever was at the top is all that's left:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_right_shift") %>

Later, when we split a 64-bit hash into "which bucket" and "the rest," right shift is how we grab the top portion.

### Masking (`&`) keeps specific bits

AND compares two numbers bit by bit and keeps a 1 only where both have one. If one side is all zeros except the bottom few bits, only those survive. That's how we grab the bottom portion of a hash:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_mask") %>

### Setting a single bit with `|=`

OR is the opposite of AND: it keeps a 1 wherever _either_ side has one. OR-assign (`|=`) lets us turn on one specific bit without disturbing anything else in the number:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_set_single") %>

### Packing bits into words

A single Ruby integer can hold 64 bits. When we need more (like a million-bit bitmap), we use an array of these integers, where each one holds 64 bits. To find which integer (which "word") holds a given bit position, and which slot within that word:

- Word index: `position >> 6` (divide by 64)
- Slot within the word: `position & 63` (remainder after dividing by 64)

Setting and checking a bit in a word array uses the same `|=` and `>> & 1` from above, applied to the right word:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_set") %>

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "bit_check") %>

## Step one: a filling bitmap

So we have hashes and we know how to flip individual bits. What if we allocated a big chunk of bits, all starting at zero, and used each hash to pick one of them to flip on?

That chunk is a bitmap: a fixed-size array where each position is a single bit that's either 0 (never seen) or 1 (something hashed here). It doesn't store the items themselves, it stores _evidence that something landed in this spot_. If two different items hash to the same position they both flip the same bit, which means we lose the ability to tell them apart, but that's fine because we don't care about identity. We care about how many _distinct_ things have left marks.

As more distinct items arrive, more bits flip from 0 to 1. Duplicates land on bits that are already 1 and leave no trace. So the number of bits still at zero tells us something about how many distinct items have passed through. More zeros remaining means fewer distinct items. Fewer zeros means more.

The math to turn that into an estimate:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting_formula") %>

> `Math.log` is the natural logarithm (there are different kinds, this one uses the number `e` ≈ 2.718 as its base, but the kind doesn't matter here). It shows up because the more items you add, the faster the remaining zeros disappear. Logarithms are the inverse of that kind of accelerating growth.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "linear_counting") %>

That's [Linear Counting](https://doi.org/10.1145/78922.78925) (Whang, Vander-Zanden, Taylor, 1990). A <%= claim("million bit map size", "128 KB") %> map estimates fifty thousand distinct items to within a few percent (beyond that too many bits are set and collisions (multiple items landing on the same bit) make the estimate noisy), and a thousand copies of one value still read as one.

Once every bit is set though the formula divides by zero and the estimate breaks. This is called _saturation_: the structure is full and can't tell the difference between "a lot" and "even more." To count billions you'd need a bitmap so large it defeats the whole point of not storing the items. We need something that doesn't hit this ceiling.

## Step two: the leading-zeros insight

The bitmap counted by how _full_ it got. There's a different reading we can take from a hash that doesn't have a ceiling.

Remember the coin flips from earlier? Each bit of a hash is an independent flip. A run of leading zeros is like a run of consecutive heads, and the longer the run the rarer it is. We can measure that directly:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "leading_zeros") %>

A hash with no leading zeros (top bit is 1) shows up about half the time. Ten leading zeros shows up about once in `2**10` distinct values. Twenty shows up once in about a million. The longest leading-zero run you've ever seen is a rough indicator of how many distinct items have passed through.

Flip the logic around: if the rarest thing you've witnessed happens about once in a million, you've probably had about a million chances at it. So a maximum run of 30 means you've likely seen around `2**30` distinct values. Unlike the bitmap, this number never hits a ceiling because longer runs keep appearing as more distinct values arrive. The catch hides in that word _suggests_: a single leading-zero count is noisy, and one lucky hash throws the whole guess off.

## Step three: taming the noise

Remember the "or they're really lucky" caveat from the coin flip section? That's exactly the problem with a single leading-zero count. One unlucky hash and your estimate is wildly off. The fix is the same fix you'd use for any noisy measurement: take a lot of them and average.

But what kind of average? If one measurement is an outlier (a value far from the others), a regular (arithmetic) average lets it drag everything up. We need an average that resists outliers:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "harmonic_mean") %>

When we take many measurements, some _will_ get lucky. The harmonic mean keeps those from distorting our answer. Now we need the measurements themselves.

## Step four: many registers, one estimate

We have one stream of items but we need many independent leading-zero counts to average. How do you get multiple measurements from a single stream?

Use part of the hash to _route_ each item to one of many buckets (called registers), and use the rest of the hash to do the leading-zero measurement within that bucket.

Think of it like running the coin-flip experiment at many tables simultaneously. Each item gets assigned to a table based on part of its hash, and each table independently tracks the longest run it has seen. No single lucky hash can corrupt more than one table.

Split each hash into two parts. The top `precision` bits pick one of `2**precision` registers. The remaining bits give the leading-zero count. Each register keeps only the _maximum_ run it has ever seen.

Now instead of one noisy estimate you have thousands of independent ones. Combine them with the harmonic mean from above and the noise cancels. More measurements means less noise (the same reason polling more people gives a better survey), and the math works out to error (the typical amount you'll be off by) shrinking proportionally to `1 / sqrt(register_count)`. With 16,384 registers that gives about <%= claim("hll standard error", "0.8%") %> error, meaning if the true count is a million the estimate will typically land between 992,000 and 1,008,000.

That's [HyperLogLog](http://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf) (Flajolet, Fusy, Gandouet, Meunier, 2007). The `precision` parameter controls how many registers you use (`2**precision` of them), so higher precision means more registers, less noise, and more memory.

First, the structure and adding items. This is where the hash split and rank calculation happen:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_add") %>

Next, reading an estimate back out. This is where the harmonic mean does its work:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_estimate") %>

At precision 14, the 64-bit hash splits into a 14-bit register index and a 50-bit remainder. The register stores the longest leading-zero run seen in that remainder. The whole structure is 16,384 small numbers.

## Merge: the property that earns its place

Say you have ten servers, each counting distinct users on their own shard (a shard is one piece of your data, split across machines so no single server has to hold everything). You want the total distinct count across all of them. With a `Set` you'd have to ship every set to one place and union them, which is enormous. With HyperLogLog you ship sixteen kilobytes from each server and combine them in one pass.

Why does this work? Each register stores "the longest leading-zero run I've ever seen." If server A saw a run of 12 in register 47, and server B saw a run of 15 in the same register, then across both servers combined someone saw 15. The maximum is always correct because a longer run can only come from more distinct values passing through that register.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-probabilistic-1/counting.rb", segment: "hyperloglog_merge") %>

Redis exposes this as `PFMERGE`.

## Where you've already used this

`PFADD` and `PFCOUNT` in Redis are HyperLogLog with exactly the parameters we built. (If you don't use Redis: `PFADD` adds an item, `PFCOUNT` returns the estimated distinct count, `PFMERGE` combines two counters. The "PF" stands for Philippe Flajolet, one of the paper's authors.) 16,384 registers (precision 14), 6 bits per register (because the longest possible leading-zero run on a 50-bit remainder is 50, and 50 fits in 6 bits), about 12 KB total, standard error of 0.81%. The 64-bit hash that lets it count past `2**32` distinct values came from a [2013 Google paper](https://research.google.com/pubs/archive/40671.pdf) (Heule, Nunkesser, Hall). The wider hash is also why there's no high-end correction in the code above: the original 32-bit version needed one near `2**32`, but 64 bits pushes that limit out of practical reach.

If you've ever called `PFCOUNT` on a Redis key, that number came from the harmonic mean of 16,384 register maxima. It's <%= claim("hll size", "Twelve kilobytes") %> whether the count is a thousand or five billion.

## Measuring it

At precision 14, this implementation estimates sequential integers to within about 0.1% at a million distinct, 0.4% at 100k, and 0.65% at 5M, all inside the 0.81% the math predicts.

The next post takes the same bit-packing toolkit and applies it to a different question: not "how many distinct" but "have I seen this specific one before." That's Bloom filters.
