---
layout: "post"
title: "Beyond Enumerable: Testing Membership with Bloom Filters"
date: "2026-07-20"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Checking whether you've seen something before usually means storing everything you've seen. A Bloom filter does it in about ten bits per item and can only be wrong in one direction. This post builds from a single bit to the structure RocksDB and Cassandra use to skip disk reads."
---

Let's say you need to keep track of which URLs you've visited, how might you approach that in Ruby? The most naive answer might be an `Array`, but that costs `O(n)` to search. After that you get a hold of `Set` which gives you an `O(1)` lookup, much better, but what do you suppose happens if you need to track _billions_ of URLs? You end up paying in RAM, approximately 80 GB of it, and that's a pretty steep cost to pay.

What if we didn't have to pay it? What if we could get _close enough_ at a _fraction_ of that cost?

That's where we start to see Bloom filters coming in. Take those same billion URLs we were tracking at 80 GB and a Bloom filter can cut it down to 1.2 GB, but there is a catch: It can tell you with certainty that something is _not_ present, but it _might_ be wrong about whether something _is_ present, and with only a 1% false positive rate when done right.

That means you're trading 1% correctness for substantially cheaper RAM costs, and in today's market that's becoming a very enticing trade to make.

## Quick hashing refresher

How does it work? Similar to the last post we're using hashing, a function that takes any input and produces a fixed-size number without a discernible pattern. The same input always gives the same output, but even a single character's difference produces a wildly different hash. The function we're using:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "hashing") %>

## One bit per item

Imagine with me a wall of light switches, all of them starting as `off`. To record an item in our filter we would hash it, and then flip one switch `on` according to its hash result. If we want to know if something is present we check to see if a switch related to its hash is `on`.

You may recognize this pattern as a bitmap from the previous HyperLogLog post, but in this case we're asking a different question. We're using it to try and figure out if something was there by looking for an `on` switch where it should be:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "one_bit_example") %>

Run it with a 32-bit bitmap and a few names:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "one_bit_output", lang: "text") %>

That said, you might notice a problem here: two items could very well hash to the same bit position. If zoe had happened to land on position 15 or 26 instead of 23, she'd read as present even though she never went in. That's a false positive: the filter says yes about something you never put in. In this case zoe's bit is `off`, meaning she's definitely not present.

The reason that a Bloom filter works is that the filter can be wrong occasionally, but only in one direction, meaning the other direction can be used as a source of truth. A yes means "probably, but you should check" and a no means "it's not there." That "no" can let you skip expensive operations, and the rare wrong yes only costs you a lookup you'd have done anyways.

## Pushing the error down

Much like HyperLogLog a single-hash-per-item bitmap _will_ end up with a lot of collisions, rendering it useless at scale, so we stop using one bit and start using several.

Instead of hashing an item to one position, hash it to several positions using different hash functions. When you add an item, turn all of those positions `on`. When you check if an item is present, require that _every single one_ of its positions is `on`. A false positive now needs all of those positions to be `on` by coincidence from other items, and that's much harder to achieve by accident.

Say half the bits in your bitmap are `on` (a fill fraction of 0.5). With one hash, an absent item has a 50% chance of a false positive. With three hashes it needs three independent coin flips to all come up heads: 0.5 × 0.5 × 0.5 = 0.125, or 12.5%. With seven hashes: 0.5**7 ≈ 0.008, under 1%.

The problem is that more hashes means more bits flipped `on` per item, and that fills a bitmap quickly. Too few hashes wastes the bitmap space, but too many and your false positive rate climbs back up. We're going to need to tune that to find the correct settings.

## Building it

Given we only have the one hashing function we're going to need to figure something out to get several independent positions per item. Remember, though, that a difference of even one character in the _input_ to a hash function will produce a _very different_ hash, and that's a property we can take advantage of. By putting a different number in front of items before hashing we get a far nicer scattering of unrelated positions:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "bloom_filter") %>

That's a Bloom filter, [Burton Bloom's 1970 design](https://doi.org/10.1145/362686.362692). Notice that `add` only ever turns bits `on`, never `off`. That's what makes the "definitely not present" guarantee work: if a bit is `off`, nothing has ever touched it.

> **Note**: As with the HyperLogLog post we are _explicitly_ avoiding bit manipulation for early examples. This is intentional, and that version will be covered later.

## Watching it work

In practice, given a tiny filter with 32 bits and 3 hashes, here's what happens feeding in six names. We'll need a small helper to turn a bitmap into a string of 1s and 0s:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "render_bitmap") %>

Then the experiment itself:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "watch_it_work") %>

Each row shows the three positions that name claimed and the state of all 32 bits afterward:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "watch_output", lang: "text") %>

Watch `dave` land on position 30, which `carol` already turned `on`. Nothing happens, the bit was already 1, and that's why Bloom filters have false positives.

Now query it for the two names that went in, then for the two that never did:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "query_demo", unwrap: true) %>

Which produces:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "query_output", lang: "text") %>

`zoe` never went in, but her three positions (9, 20, and 30) are all on from other items: 9 came from `bob`, 20 from `dave`, 30 from `carol` and `dave`. The filter reports her as present because it has no way to tell whose bits are whose.

`mallory` has two of her three bits `off`. Nothing can turn a bit `off` once it's `on`, so if it reads `off` nobody has ever set it, meaning the item is definitely not in there.

## How big, and how many hashes

Up above we mentioned that we're going to need to fine tune how many bits we need to allocate and how many hashes we need to run to make this efficient. We can derive that like so:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "false_positive_rate") %>

Every added item takes `hash_count` attempts at turning bits `on`, and the odds that any given bit is still `off` shrink as those attempts pile up. For a false positive to happen, an absent item needs _every one_ of its `hash_count` bits to already be `on` by coincidence, and that probability drops fast as `hash_count` grows. The code comments explain why `Math.exp` works as a stand-in for the exact power (it gets more accurate as `bit_count` grows).

By keeping the bitmap size and item count constant and manipulating the value of `hash_count` we notice that the false positive rate drops at first, and then starts climbing. Too few hashes and you're not using the bitmap effectively, too many and you're filling it too fast. There's a sweet spot in the middle where the error is lowest, and that's where we want to land.

The optimal number of hashes works out to `(bit_count / item_count) * log(2)`, where `log(2)` is the natural logarithm of 2, about 0.693 (Ruby: `Math.log(2)`). At 10 bits per item that gives us 10 × 0.693 ≈ 7, so 7 hashes is the best choice.

Let's give that a try by running an experiment at 10 bits per item, varying the hash count, and testing against fifty thousand absent items. First we need a helper that computes the optimal hash count from the formula above:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "optimal_hashes") %>

Then the sweep:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "sweep_hash_count", unwrap: true) %>

Results:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "sweep_output", lang: "text") %>

The measured minimum lands at 7 to 8 hashes, which is close to the predicted 6.93. One hash gives you a useless ~9.7% error rate, and past the optimum the rate climbs as the extra bit-sets fill the bitmap.

The next question is sizing: given how many items you expect and the error rate you can live with, how many bits do you need? The formula is `-item_count * log(target) / (log(2) ** 2)`. Breaking that down:

- `log(target)` is the natural logarithm of your desired false positive rate. For a 1% target that's `Math.log(0.01)` ≈ -4.6. The minus sign in front cancels the negative, giving a positive bit count.
- `log(2) ** 2` is `Math.log(2) ** 2` ≈ 0.48, a constant from the math behind the optimal hash count.

What's handy is that the bits-per-item cost is fixed for a given target regardless of how many items you store:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "sizing_table", unwrap: true) %>

Output:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "sizing_output", lang: "text") %>

The cost is constant per item: 1% costs about 9.6 bits each whether you store a thousand items or ten billion. Tightening from 1% to 0.1% costs you roughly five more bits per item.

## Memory, in numbers

Great, but why do we care about any of this? We care because here's the difference on a million stored URLs with a `Set` versus a Bloom filter at 1%:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "memory_comparison", unwrap: true) %>

Which gives us:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "memory_output", lang: "text") %>

That's a 98.5% improvement on memory for a 1% chance you get a false positive. When you only need to know if something is present or not, that trade is worth taking. The filter doesn't store the URLs themselves, it stores evidence that something was there. You can't ask it to list what it's seen, and you can't get a URL back out of it. You can only ask "have you seen this one."

We can test this by inserting a hundred thousand items and asking about all hundred thousand again:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "accuracy_test", unwrap: true) %>

Running it:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "accuracy_output", lang: "text") %>

Zero false negatives, because bits only ever get turned `on` and never `off`. The ~1% false positive rate only applies to items that were never added.

## Merging filters

Say two machines have each been running their own filter over the URLs they've seen, and you want one filter that answers for both. As long as they're the same size with the same hash count, you combine them by OR-ing the bitmaps position by position: for each position, if _either_ filter has it `on`, the merged filter has it `on`. In Ruby that's `||` across both arrays (or `|` if you're working with packed integers). We added a `merge` method to `BloomFilter` above that does exactly this:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "merge_demo", unwrap: true) %>

Output:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "merge_output", lang: "text") %>

You still get zero false negatives after merging, and at scale this becomes very useful. You don't need to ship the data between machines, you ship an observation of it.

## You can't delete

You can add to a Bloom filter, but you can't remove from one. Turning an item's bits back `off` looks reasonable until you remember that multiple items can share the same bit positions.

For example, two names, `alice` and `bob`, will overlap on a position:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "deletion_demo", unwrap: true) %>

Running it:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "deletion_output", lang: "text") %>

Clearing `alice` turned `off` position 59, which `bob` was also using. Now the filter reports that `bob` isn't there, even though `bob` was never touched. That's a false negative, and false negatives are the one error this structure is supposed to make impossible.

If you need removal, you can store a small counter (say, 4 bits) at each position instead of a single bit. Adding increments the counter, removing decrements it. A position reads as `on` if its counter is above zero. That's called a counting Bloom filter, and it works, but you're paying 4 bits per position instead of 1 which quadruples the memory.

## Where you've already used this

If you've run almost any modern database, Bloom filters have been working under you.

Many storage engines (RocksDB, LevelDB, Cassandra, HBase) use something called log-structured merge trees, or LSM trees. Instead of updating records in place on disk (which requires finding and rewriting them), the engine writes new data into a fresh sorted file. These files are called SSTables. Over time you end up with a lot of them, and when you want to look up a key you might have to check several files to find it.

That's fine for keys that exist, you find them eventually. The expensive case is looking up a key that _doesn't_ exist, because you have to check every file before you can be sure it's not there. Each check means reading from disk, and disk reads are slow.

Each SSTable carries a Bloom filter over the keys it contains. Before touching the disk, the engine asks the filter: "might this key be in this file?" If the filter says no, the file is skipped entirely. If it says yes, the engine reads the file.

RocksDB's filter defaults to 10 bits per key, the same 10-bits-for-1% trade we derived above. Cassandra exposes it directly as a per-table setting called `bloom_filter_fp_chance` where you choose how much memory to spend in exchange for fewer disk reads.

## Making it fast: packed bits and double hashing

The `BloomFilter` class above works correctly but has two performance problems.

By using arrays and booleans for our bitmap we're paying a full 8-byte slot per array element to hold one bit of information, a 64x overhead on the raw data. Great for examples and readability, not so great for memory and efficiency if you wanted to use it in production.

On the hashing side, with 7 hashes we're computing 7 separate SHA-256 digests per `add` and per `include?`. SHA-256 is expensive, and in a hot loop that cost adds up.

The fix for the hashing cost is a trick called double hashing, from [Kirsch and Mitzenmacher (2006)](https://www.eecs.harvard.edu/~michaelm/postscripts/esa2006a.pdf). Instead of computing 7 independent hashes, compute one 64-bit hash and split it into two 32-bit halves: `high` and `low`. Then generate as many positions as you want by stepping:

- Position 0: `(high) % bit_count`
- Position 1: `(high + low) % bit_count`
- Position 2: `(high + 2 * low) % bit_count`
- Position 3: `(high + 3 * low) % bit_count`
- ...and so on

Each position is different because you're adding `low` each time, and the paper shows no measurable loss in false positive rate compared to fully independent hashes.

If you're comfortable with bit manipulation, here's the optimized version combining both fixes. If not, skip this block, the behavior is the same:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "packed_bloom_filter") %>

Breaking down the bit operations:

- `position >> 6` divides by 64 (since 2**6 = 64) to pick which integer in the array holds our bit
- `position & 63` gives the remainder (0-63) to pick which bit within that integer
- `|= (1 << (position & 63))` sets that specific bit to `on` without touching any other bits in the integer
- `integer[position & 63]` in Ruby reads that single bit back as 0 or 1

Running the same hundred-thousand-item test through it:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "packed_output", lang: "text") %>

Same 0 false negatives, same roughly 1% false positive rate. One hash call instead of seven, bits packed into integers instead of individual objects, and a good deal faster:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/bloom.rb", segment: "benchmark") %>

Which results in:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-bloom/output.txt", segment: "benchmark_output", lang: "text") %>

About 2.6x faster on inserts and 3.2x faster on lookups, primarily from avoiding 6 extra SHA-256 calls per operation and packing 64 bits per integer instead of one bit per array slot. Both sides pay the same `queries.sample` overhead so the relative difference is what matters.

## Wrapping up

Bloom filters make it cheap to ask whether or not you've seen something. It's always right when it says something isn't there, but _might be_ wrong when it says something is, at a false positive rate we can tune to an acceptable level. For large datasets this can be a great trade to make, but before we make those trades we should understand what we gain and what we lose, much as we would with any architectural decision.

Probabilistic algorithms are another tool we can use, they have a time and a place, and for a lot of problems I find myself in nowadays that time is now and that place is right here. Perhaps it's different for you, but knowing these ideas exist is valuable too for when you do find such problems.

Where do we go from here? Well, we've covered how to count distinct items with HyperLogLog and membership with Bloom filters, but what if we wanted to figure out how many _times_ we've seen a specific item? That's Count-Min Sketch, and it's next on my list to cover.
