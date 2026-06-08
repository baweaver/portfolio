---
layout: "post"
title: "Beyond Enumerable: Heaps and Priority Queues"
date: "2026-06-06"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Enumerable named our traversals, but some collections live past it. This post goes after ordered retrieval: heaps, priority queues, their real uses, and why they belong in Ruby itself."
---

Our last post named windows: moving through a collection while maintaining running state. This one goes after a different shape, one that shows up the moment a collection won't sit still long enough for `sort_by` to help.

`Enumerable` gives you `min_by`, `max_by`, `sort_by`, and they're enough when the collection is static. You ask once, they walk everything, and you get your answer, but they keep nothing between calls. Ask again after an insert or a delete and they redo all that work from scratch. On a collection that changes on every read, you're re-scanning every time, and if you never had an algorithms class that told you there's a name for the structure that fixes this, you end up rebuilding it by hand without knowing what you're building. I did that for years. These articles exist so the path is shorter for other people.

## A problem you've actually had

Say you're draining a queue of jobs. Each one has a time it's meant to run, and you want the soonest one next.

You reach for `min_by`:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "min_by_example", unwrap: true) %>

The intent is clear enough, and for a few jobs it's more than fine. The problem is that `min_by` walks the entire list every time, and eventually that queue grows and those numbers stop being small.

## Where the floor drops out

Every call to `min_by` is `O(n)`. Call it once per job across a queue of n jobs and you're at `O(n²)` just to drain it, and that's before you count the new jobs landing in the middle of the run.

So you try to get ahead of it and keep the list sorted:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "sort_then_shift", unwrap: true) %>

> **Note on `shift`:** You'll occasionally see `Array#shift` described as `O(n)`. MRI uses a shared buffer with a pointer offset, making it amortized `O(1)` ([benchmark](https://github.com/baweaver/portfolio/blob/main/site/src/_code/beyond-enumerable-heaps/bench_shift.rb) shows flat ~0.014µs/elem from n=10k to n=400k on Ruby 3.4). The cost in this snippet is the re-sort on every arrival, not the `shift`.

Reading the next job is now `O(1)`, but every arrival pays `O(n log n)` to re-sort or `O(n)` to insert in place. You've moved the cost from reading to writing and it's still linear or worse per operation.

Maybe this happens once and you shrug it off, then it happens again somewhere that looks nothing like a job queue.

## The same shape, three more times

**Keeping the top results.** Scores keep arriving and you want the best hundred so far. You can't wait for them to stop, so every time a new one shows up you need to know whether it beats your current worst.

**Best-first search.** You have a set of options, each with a cost. You always try the cheapest one first. Trying it reveals new options you didn't have before, so the set keeps growing and you keep needing the new cheapest.

**Merging sorted lists.** You have a dozen lists, each already in order. You want one combined list in order. At each step you need to know which list has the smallest next item, take it, and move on.

All three want the same thing: a changing collection where you only ever need the extreme value, and finding it has to stay cheap.

## Keeping only enough order to find the top

Let's go back to the job queue idea from earlier. We sort 100 jobs only to read from the front of that list, and 99 comparisons aren't going to matter until the next time we need something, leading to what seems like a lot of wasted effort to get the next job.

What if instead of trying to keep the entire list sorted we only worry about the parts we need to immediately read? What would that look like? Perhaps we have a rule: each item must be no larger than the items directly below it. We don't compare items at the same depth, or items in different branches, only the downward parent-to-child relationship.

```
        1
       / \
      3   8
     / \
    5   9
```

That's a much weaker (and cheaper) constraint than sorting, but it's still strong enough: if nothing is ever smaller than its parent, the smallest sits at the top and reading it costs nothing.

## From a tree to an array

The natural way to hold that tree is the way you'd draw it, each item in a node that points at its children:

```ruby
Node = Struct.new(:value, :left, :right)
```

That works, but it's more than the heap needs. The two operations we care about, adding and removing, both need to know where the next empty spot is and which item is last. Child pointers don't answer either question.

Since the rule only constrains values and says nothing about shape, we get to choose. Fill the tree level by level, left to right, leaving no gaps. A tree packed like that is called _complete_, and the next empty spot is always the end of the bottom row.

Once there are no gaps you can number every position. Start at `0`, count left to right, drop to the next level:

```
         0
       /   \
      1     2
     / \   / \
    3   4 5   6
```

Those numbers are dense starting from zero, which means they're array indices. Drop each value into its numbered position and the nodes disappear entirely:

```ruby
#        0  1  2  3  4
pile = [ 1, 3, 8, 5, 9 ]
# the 1 is the top; 3 and 8 are the row below it; 5 and 9 sit below the 3
```

That array _is_ the tree. The structure didn't go away, we stopped writing it down explicitly and started computing it from position.

Go back to the numbered tree:

```
         0
       /   \
      1     2
     / \   / \
    3   4 5   6
```

The root at index 0 has its children at 1 and 2. The item at index 1 has its children at 3 and 4. Index 2's children are at 5 and 6. Each item's left child is at double its own index plus one, and the right child is one further.

Going back up works the same way. The items at 3 and 4 both have index 1 as their parent. Items at 5 and 6 both have index 2. Subtract one, divide by two (integer division), and you land on the parent every time.

```
index     0    1    2    3
children  1,2  3,4  5,6  7,8
parent    -    0    0    1
```

So the formulas emerge from the numbering: children of `i` are at `2i + 1` and `2i + 2`, and the parent of `i` is at `(i - 1) / 2`.

There's a performance reason to prefer the array too. A node-based tree allocates an object per item and chases a pointer every time you move from parent to child. The array is one contiguous block, so parent-to-child is arithmetic and a lookup into memory you've probably already touched. Growing it is `Array#push`.

## Putting items in, and taking the top out

To add an item, drop it at the end of the array and let it climb: while it's smaller than the item above it, the two trade places. It stops the moment the item above is no larger, or it hits the top. One swap per level, never the whole array.

```ruby
# push 2 onto a heap that already holds [1, 3, 8]
[1, 3, 8]       # start, the rule holds
[1, 3, 8, 2]    # 2 dropped at the end, lands beneath the 3
[1, 2, 8, 3]    # 2 < 3 so they trade; 2 is now beneath the 1, and 2 < 1 is false, so it stops
```

To remove the top, take the first item out, move the last item into the now-empty first slot, and let it sink: trade it with the smaller of its two children, again and again, until both children are larger or it reaches the bottom.

```ruby
# pop the smallest from [1, 2, 8, 3]
[1, 2, 8, 3]    # start
[3, 2, 8]       # take the 1 off the top; move the last item (3) up into the empty slot
[2, 3, 8]       # 3 > 2 so they trade; 3 settles at the bottom with nothing smaller below
# => 1
```

## So this is a heap

That shape is a **heap**. The climb is called `sift_up`, the sink is called `sift_down`, and each one walks a single path from top to bottom, which makes both `O(log n)`.

Here's `push`. It appends the item, then bubbles it up until the parent constraint holds:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "min_heap_push") %>

And `pop`. It saves the root, moves the last item into the vacant top slot, then sinks it down:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "min_heap_pop") %>

Together they give you a working min-heap:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "min_heap_usage", unwrap: true) %>

`peek` is `O(1)`, the smallest item is always at index 0.

Building a heap by pushing items one at a time costs `O(n log n)`, because each push might climb the full height of the tree.

If you already have all the items, there's a faster way. Dump them into an array unsorted, then walk backwards from the last item that has children and sift each one down. Most items live near the bottom where there's barely any distance to sift, so the total work comes out to `O(n)`:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "min_heap_from") %>

That lets `MinHeap[5, 1, 8, 3]` read like `Set[...]`. But `MinHeap` compares items directly with `<`, and that's not always what you want.

## When the priority isn't the value

The heap compares items with `<`, but the scheduler doesn't want to compare jobs against each other; it wants to compare their `run_at` times. A job isn't less than another job, its deadline is earlier.

You could give the objects a `<=>`, but a block that reads each item's priority is more flexible and leaves the items untouched. A `PriorityQueue` is a `MinHeap` that runs every comparison through that block, only changing the constructor and the two sift methods:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "priority_queue") %>

The block runs on every comparison, so a job's `run_at` gets read many times over the queue's life. Reading an attribute is nothing, but if the key were expensive you'd cache it on the way in and compare the cached value.

And the scheduler collapses to one loop:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "scheduler_loop", unwrap: true) %>

Order jobs by when they run, put them in, take each one as it comes due.

## The family resemblance

**A max-heap** flips the comparison. Negate the key, or reverse the operator, and the largest item sits at the root instead. It's the same machinery with one sign flipped.

**A bounded "top-k" heap** keeps only the best k items from a stream that may never end. To keep the _largest_ hundred scores, use a _min_-heap of size 100. The root is the smallest of your current best, the one to evict when something bigger arrives.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-heaps/heap.rb", segment: "top_k") %>

When the stream ends, the heap holds the hundred largest, and you never sorted the stream or held more than <%= claim("top k size bound", "a hundred and one") %> things at once.

**Merging sorted streams** is a heap whose items are the current heads of each stream: pop the smallest, emit it, advance that stream, push its new head. The heap never grows past the number of streams, and the merged output comes out in order without ever sorting the whole thing.

All of these depend on the heap staying valid between operations, which raises a question about how to put this in front of callers without letting them break it.

## Encapsulation over exposure

You could implement a heap as functions over a plain array: push into it, pop from it, let the caller hold the array directly. The problem is nothing stops that caller from doing `array.sort!` or `array.delete_at(3)` between heap operations, and either one silently breaks the invariant. The next pop hands back the wrong item and nothing raises. Correctness depends on everyone politely not touching the thing, which isn't a guarantee, it's a wish.

An object that owns its array and only exposes push, pop, and peek can't be corrupted from outside. No method leaves it in a broken state, no method hands you the internals.

## Putting a name on it

The API looks like this:

```ruby
MinHeap[5, 1, 8, 3]                       # smallest out first
MaxHeap[5, 1, 8, 3]                       # largest out first
PriorityQueue.new { |job| job.run_at }    # ordered by an arbitrary key
```

The surface stays small, the same shape as `Set`:

```ruby
push   # or  <<
pop
peek
size
empty?
self.[]
```

The caller doesn't know about sifting or index math. They push, they pop, and the structure keeps the ordering cheap. How cheap, exactly?

## Counting the cost

The naive approaches from earlier (`min_by` on every drain, or re-sort on every change) are both `O(n²)` across a full drain. The heap pays `O(log n)` per push and per pop, so draining the whole queue is `O(n log n)` total. On a few hundred thousand jobs that's a <%= claim("heap faster than sort drain", "difference in complexity class") %>, not a constant factor.

`MinHeap[]` builds in `O(n)` rather than the `O(n log n)` you'd pay pushing one at a time. It produces the <%= claim("heapify equivalence", "same answer") %> either way, with less code and fewer ways to get it wrong.

## Where this belongs

Ruby doesn't ship a heap. Your options today are hand-rolling the sift logic, pulling in a gem, or leaning on `sort_by` and eating the cost. Every other major language has one in its standard library: Python has `heapq`, C++ has `priority_queue`, Java has `PriorityQueue`, Go has `container/heap`, Rust has `BinaryHeap`. Ruby has people quietly reimplementing the same structure in application code, each version a little different, a few of them wrong.

There's an open feature request, [#21720](https://bugs.ruby-lang.org/issues/21720), proposing a native heap for the standard library. The thread is working through the design, and the discussion has been moving toward an encapsulated, class-based API. I weighed in there too. My preference: behave like `Set`. A small mutable collection, not thread-safe by default, built with `MinHeap[*items]`, exposing `push`, `pop`, `peek`, `size`, and `empty?`. Thread-safe coordination stays in `Queue` and friends where it already lives.

`Set` earned its place in the standard library because membership testing is common enough that reaching for `Hash` with `true` values is a bad answer everyone kept writing. `Thread::Queue` earned its place the same way. Ordered retrieval from a changing collection is that kind of problem. The structure is decades old and well understood. What's missing is the decision to ship it.
