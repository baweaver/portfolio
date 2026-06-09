---
layout: "post"
title: "Beyond Enumerable: Graphs and Traversal"
date: "2026-06-08"
categories: []
tags: ["ruby", "enumerable", "beyond-enumerable"]
series: "beyond-enumerable"
description: "Enumerable named the ways we walk a line, but some data is not a line. This article builds graphs up from a plain Hash, covering dependency ordering, tsort, friend lists, and a few pathfinding algorithms."
---

When we consider `Enumerable` methods as they apply to `Array` they all have a single direction. Front to back, back to front, maybe skip a few here and there, but they're all linear in nature. What do you suppose happens when we apply them to shapes that _aren't_ linear?

Earlier posts danced this line. A window is still a sequence even if it slides, a heap is a pile even if it looks like a different structure. The heap was a tree, and a tree is the tamest graph there is: no cycles, one way down. Take those restrictions off and you get the general shape.

This one, especially, is a fun subject for me and the cause of more than a few interview failures over my career as I could never reliably write up implementations on the spot and before then I didn't even really know what they were or why they were important. For me the best way to learn is to teach, so teach we shall, as it's time to traverse some graphs.

## A problem you've actually had

You're now the proud owner of a build system, lucky you. The problem is that the entire process is very manual and the full version spans more than a few wiki pages that have questionable freshness. Thankfully there are still some folks around who were there when the deep magics were written and have kindly furnished you with the following list (simplified):

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "tasks_hash") %>

Each key is a task, and each value is what that task depends on finishing first. In order for the full process to succeed these tasks need to run in the correct order, but how precisely does someone approach that problem?

## The wrong sort of problem

The most immediate answer is `sort`, but `sort` by what and how? You can't really compare or order `:build` versus `:test` as they exist here, so where do we start looking? The problem here is that we're looking at the individual values when what we really need to care about are the lines between them that tell us how they relate to each other.

But we start with the familiar, and endeavor to write something by hand. Said aloud what we're aiming for is to take any task where all of its dependencies are done, mark it as done, and rinse-wash-repeat until we hopefully have a functional production artifact sailing out the door.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "order_tasks") %>

Sure, it works, but at what cost? You get back `[:install, :build, :test, :deploy]` as expected, but as this problem grows this is going to get _very_ expensive. You're maintaining a `done` list, duplicating the entire `tasks` Hash, and repeatedly re-scanning the entire thing until done. Underneath all of that is the single line that matters, the `select`, which gives us a valuable hint for where we need to go next.

## It was never a list

As mentioned earlier we're treating this like a list and that shape does not fit. Take a step backwards with me and let's draw this out, and a different shape starts to emerge instead:

```
        ┌──▶ build ──┐
deploy ─┤            ├──▶ install
        └──▶ test ───┘
```

We're able to see not just the tasks, but the arrows between them that tell us how they relate. The original `TASKS` Hash? That key-to-value relationship already tells us the arrows. The next step is figuring out how to use them.

## Naming the parts

The problem with never really having a structured algorithms class is that you're always at a loss for what something is called. Sure, the underlying concepts make sense at a high level, but without the names you're fumbling in the dark. Once you know what to search for, everything opens up.

For this particular case the items we see here are called **nodes** or **vertices**, and the relationships between them are called **edges**. When those edges have only one direction, or rather the arrows all point one way, we have a **directed graph** and conversely we have an **undirected graph** if they go both ways.

Our `TASKS` Hash up there is the most common way to express a graph, called an **adjacency list**. In it every node points to the list of nodes it has an edge to.

```ruby
graph = {
  node => [neighbor, neighbor, ...],
}
```

## The same shape, somewhere friendlier

So maybe the build system didn't work out, I get it, it's not for everyone. Perhaps you might have better luck around social networks, and what better way to start than to figure out how friends lists might work:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "friends_hash") %>

Looks similar, right? Nodes and edges, and something different: friendship can run both ways.

Getting started you can already leverage some of your knowledge of `Enumerable` for things like mutual friends:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "mutual_friends") %>

Or perhaps for friends-of-friends you might want to get to know:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "people_you_might_know") %>

So far we're doing great, right? Well yes, right until you remember there's 30 minutes left in the interview and the interviewer says "ok, time for part two" and manages to mangle your `Enumerable` approach in one fell swoop that makes it abundantly clear:

This approach only works for 1-2 hops, best case, and now you have a problem.

One hop is `Enumerable`. Two hops is a `flat_map`. Past that you need a different approach entirely, and that's where traversal comes in.

## Walking a shape that branches

So you go for a walk, a traversal if you will, but on that path you're going to find paths that lead to more paths. Perhaps three, maybe thirty, maybe thousands and it becomes a _very enthusiastic walk_. How is one to choose where to go next?

One approach is to pick one path, let's say the leftmost one, and keep picking left until you get to the end. Once you do? Back up to the previous intersection and pick the next most left path you can find, and continue until you run out of places to go.

This is called **depth-first search** and the first implementations of this you might see are going to likely involve recursion like so:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "reachable_dfs_recursive") %>

Note the `visited` set there, because it's not optional. Think of it like marking an "X" on every path you've already visited, maybe you're forgetful like me and you end up back down the same path again, and if that happens enough you're who knows where and _very very_ lost. In recursion that'll land you in infinite loop hell, so best to avoid it.

Past that, `fetch(node, [])` over `graph[node]` is worth the extra characters. A node can show up as someone's neighbor without having its own key in the Hash, and `nil.each` is not the error message you want to debug at midnight.

The problem with recursion here though is that Ruby's call stack will blow up rather spectacularly if it goes deep enough (* unless you enable Tail Call Optimization, but that's an article and a half.) Given that we need to step backwards and handle the stack ourselves instead:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "reachable_dfs_iterative") %>

Each descent checks the top-most node using `pop`, starting with the `start`, and then starts pushing all of the immediate children onto that stack to process next. You're effectively visiting the left-most path repeatedly until you run out of lefts, then you go one less.

Now change `pop` to `shift`, pull from the front instead of the back, and the entire behavior flips. Instead of diving deep it fans out in rings, visiting everything one hop away, then two hops, then three. That's **breadth-first**:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "reachable_bfs") %>

The one change that matters is `pop` to `shift`. The stack became a queue and the traversal changed completely.

The difference matters because it changes what you can answer. DFS tells you _whether_ you can reach something, and it tends to use less memory since it explores one branch at a time. BFS tells you the _shortest_ way to reach something, because it visits in order of distance: everything one hop out, then two, then three. The first time BFS touches a node, it got there by the fewest possible steps. DFS makes no such guarantee. It might find a node by the longest path first.

## Can I get there from here

You've probably played a version of this before, even if you didn't call it graph traversal. [Six Degrees of Kevin Bacon](https://en.wikipedia.org/wiki/Six_Degrees_of_Kevin_Bacon): pick any actor, find the chain of co-stars that connects them back to Kevin Bacon. Or the Wikipedia game: start on one article, click links until you reach another. Both are the same question: can I get from here to there, and how many hops does it take?

Reachability is what the traversal already gives you. `reachable_bfs(FRIENDS, "Ana")` hands back everyone Ana connects to through any chain. Add `.include?("Eli")` and you have your answer.

The more fun question: what's the shortest chain? Since BFS visits in distance order, we already know the first arrival is the shortest. Record which node brought you there at each step, then trace backward from the goal:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "shortest_path") %>

`came_from` is doing two jobs: it's the "have I been here" guard and the breadcrumb trail home. Ana to Eli comes back as `["Ana", "Ben", "Dee", "Eli"]`, three hops, three degrees of separation.

## Back to the order we wanted

Remember the build system from the start? Traversal handles it more cleanly than what we hand-rolled. The trick: run depth-first, but record each node _after_ you've finished visiting everything it depends on.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "topological_sort") %>

Because dependencies get visited and recorded before the things that need them, everything lands in a valid execution order. This is called a **topological sort**, a term I definitely did not know the first three times I needed one. The last time I reinvented it through sheer force of will and coffee was for a service container's dependency loader at Square, before someone finally had mercy and told me it had a name.

There's usually more than one valid ordering. `[:install, :build, :test, :deploy]` and `[:install, :test, :build, :deploy]` both respect the arrows. Different implementations will produce different valid results, and that's fine as long as every dependency lands before the thing that needs it.

One sharp edge, though: if two tasks depend on each other there is _no valid order_. The hand-rolled version from earlier caught that (nothing was ever _ready_, so it raised). This DFS version does not. The `visited` guard skips the cycle and gives you an order that can't actually run. Cycles in dependency graphs are a special kind of miserable to debug because everything _looks_ fine until you try to execute the result.

Detecting a cycle means tracking not just where you've _been_, but where you _currently are_ on the way down. Keep a second set, `in_progress`, that holds every node on the current path. Add a node when you start visiting it, remove it when you're done with all its children. If you ever try to visit a node that's already in `in_progress`, you've followed a loop back to something you haven't finished yet:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "topological_sort_cycle_recursive") %>

Three lines of difference from the version without cycle detection: add to `in_progress` on entry, raise if we see it again, remove on exit. Recursion is fine here because dependency graphs tend to be shallow (dozens of levels, not thousands), so the call stack isn't a realistic concern the way it was for a general graph walk.

If you do need a stack-safe version, the same idea converts to an explicit stack. It's denser to read but handles arbitrarily deep graphs:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "topological_sort_with_cycle_detection") %>

The loop peeks with `stack.last` instead of popping because the node needs to stay on the stack while its children are processed. When we come back to it and find it in `in_progress`, that's the signal that all children are done. `in_progress.delete?` both removes it and tells us whether it was there, which doubles as the finalize trigger.

Ruby ships [`TSort`](https://docs.ruby-lang.org/en/master/TSort.html) in the standard library, and has for decades. Almost nobody reaches for it because you have to already know the word "topological" to go looking, which is a shame because it handles all of the above for you:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "tsort_lambda") %>

Feed it a loop and it raises `TSort::Cyclic` instead of handing you a broken order.

## When the edges have a price

BFS finds the shortest path by hop count, but not every hop costs the same. Driving from Seattle to Boise you could go through Portland or through Spokane, and the mileage is different even though both are two hops.

A plain neighbor list doesn't capture that. Each connection needs a weight, and a `Data.define` makes that readable:

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "roads_hash") %>

Seattle to Boise through Spokane: 280 + 305 = 585 miles. Through Portland: 174 + 430 = 604 miles. Same number of hops, different cost. BFS would pick whichever it finds first, which might be the longer drive.

So what do we change? Same frontier loop as BFS, but instead of pulling the _oldest_ node off the list we pull the _cheapest_. Always explore whatever we can currently reach for the least total miles, and the first time we settle on a node we know that's the cheapest way there. This is [Dijkstra's algorithm](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm), and it's really BFS with a different sort order on the queue. One assumption it makes: all edge weights are non-negative. If a road can have negative miles (refunds, discounts, whatever your domain calls them) this breaks, and you need a different algorithm entirely.

<%= render Shared::CodeBlock.new(file: "beyond-enumerable-graphs/graph.rb", segment: "cheapest_cost") %>

`next if cost > best[node]` handles stale entries. A node can end up in the frontier more than once as we discover cheaper routes to it. When an older, pricier entry for that node finally comes off the pile, this line tosses it. Without it we'd waste time re-exploring places we've already found the best route to.

The `sort_by!` on every pass is the brute-force way to always grab the cheapest. It re-sorts the entire frontier every single time, which is wasteful. A heap (from the previous post) would do the same job in `O(log n)` per extraction, and you already know how to build one. Give it a try if you're feeling ambitious.

## Counting the cost

DFS and BFS both visit each node once and examine each edge once: `O(V + E)` time, `O(V)` space for `visited`. That's linear in the size of the graph, which is about as good as "look at everything" can get. Dijkstra adds a log factor for the frontier ordering, landing at `O((V + E) log V)` with a heap.

## Where this belongs

For production graphs, reach for [RGL](https://github.com/monora/rgl) or `TSort`. They handle cycle detection, strongly connected components, and a catalog of algorithms that would take a while to get right on your own. Once a graph outgrows a single machine's memory, that's where something like Neo4j starts earning its keep.

I derived everything by hand here because that's how the names stuck for me. "Breadth-first search" stopped being intimidating the day I wrote a bad version of it and watched it actually work. Same for topological sort, same for Dijkstra. They're loops with names, and once you know that the docs stop reading like incantations.

Everything in this series so far has fit comfortably in memory. The next post explores what happens when it doesn't.
