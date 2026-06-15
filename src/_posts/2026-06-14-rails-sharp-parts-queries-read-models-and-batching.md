---
layout: "post"
title: "Rails: The Sharp Parts. Queries, Read Models, and Batching"
date: "2026-06-14"
categories: []
tags: ["ruby", "rails", "activerecord", "architecture", "packwerk", "rails-sharp-parts", "cqrs", "sorbet"]
series: "rails-sharp-parts"
description: "Queries own the reads the way commands own the writes, and a T::Struct is the only thing that crosses between them. Every read here ran against ActiveRecord 8.1 before it went in."
---

[Last time](https://baweaver.com/writing/2026/06/13/rails-sharp-parts-callbacks-are-not-invariants/) we moved domain behavior out of callbacks and into commands with one door.

> **Aside**: The patterns in this series come from my time working in large Rails monoliths (1M+ lines of code, 10+ years of history, hundreds to thousands of engineers). What I see from that vantage point may not be relevant yet to greenfield or early-stage apps. These problems show up at a certain scale and not before.

We did so because that one door controls who gets to define what it means to "write" to our data, rather than hoping that our consumers do not make up their own definitions (they will.) The problem we face is that _anyone_ can call `save` or another mutation method from _anywhere_ in the application. Every controller, job, rake task, and more is now an active liability in which you do not have control over your own data. A single command ingress is designed to take back that control and put it behind a single interface: Writes go through your door, and no one else's, every other path is closed and all your rules live in one clear place.

Great, so we have a reasonable lock down on commands, but what about reads? As we reflected on in the earlier indexing article each distinct query has a distinct index that maps to it and optimizes it, so if you don't happen to control the shapes of those queries and instead give complete and total access to your query interface to _every single consumer_ how likely do you suppose it is that you end up with an optimized application? It won't be, and trying to optimize external callers is a losing proposition.

Going back to our last post we had `Seats::ReserveSeat.call` returning `Seat`, an ActiveRecord object. The caller can _very easily_ call `update!` on the object returned, or chain further queries off it, or read associations that fire new SELECTs on every access. The single door we spent time installing has a window cut into the wall beside it, and every reader who takes advantage of that fact makes that gap wider and wider until that door becomes more a polite suggestion than a solid gate. We need rules that cover both directions: Anything that crosses a pack boundary needs to be an inert shape with no behavior, and a live relation will _never_ satisfy that requirement.

## The Leak

Here is a reader that returns a relation:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "open_seats") %>

It reads, the name says read, and nothing about it looks dangerous. A caller picks it up and writes straight through it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "the_leak") %>

A relation is a query the caller can keep extending, and `update_all` is one of the extensions, which makes the reader's return value a writable handle to the seats table presented as a list.

A single record carries the same problem. The object you fetch to show a seat (`Seat.find(1)`) answers to `update!` as willingly as it answers to `reserved`, because it is the same object either way. And if that record belongs to something, reading the association bills the caller one query per row leading to N+1 problems.

Let's use this small counter method to see what's happening:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/setup.rb", segment: "count_statements") %>

And we can see what happens directly for that fanout:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "lazy_fanout") %>

That means we have a fanout happening in a consuming pack, all to get an attribute, that scales to the size of the collection and chances are you as the producer has _no idea_ this is happening either.

Since the returned object can write, it will fire queries for every touched association, and it will expose every column, scope, and association the model carries while it's at it. That means the entire surface area of your model has now inadvertently become the public API by which all other consumers will interface with your data, making any boundary effectively useless.

## What a Value Is

ActiveRecord objects are live. What we need are inert objects that only expose the data we want them to have. Value objects are an answer to this, and Sorbet's `T::Struct` is one compelling option.

> **Aside on Static Typing in Ruby**: This has been a long-contentious subject in Ruby-land around static versus dynamic typing, but in the age of AI additional guardrails make a significant difference, and over the past two years I have leaned in heavily to Sorbet for this very reason, and have had a lot of good success with it.

Let's consider the following data shape:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/setup.rb", segment: "event_detail_struct") %>

These are much safer to hand across boundaries as they're enforced at construction time:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "struct_type_check") %>

And they're immutable everywhere else when using `const` fields:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "struct_immutability") %>

Nothing can ride this object back to the database to make unexpected changes, which is exactly where we want to be at scale.

There _are_ a few other options for how you can do this in Ruby like `Struct` (mutable) and `Data.define` (immutable) which can cover some of the same ground, but neither carry typing information that can be used to statically verify correctness.

For read models I personally like to store them under a `Data` namespace inside their pack, to make it clear how they're distinct from ActiveRecord values. They also become the public-facing identity of the pack and what data it might return, and makes it explicit what data from what pack you're operating on downstream.

## ApplicationQuery

So what might a shape look like for Queries then? Perhaps something similar to `ApplicationCommand`, minus transactions, plus a few declared return types:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/setup.rb", segment: "application_query") %>

But that does have one problem: ActiveRecord queries return ActiveRecord objects, meaning an extra object construction, and that can become expensive. You _could_ pull columns straight from `pluck` but then you end up juggling positional arrays, so instead we can introduce a helper method on `ApplicationRecord` to make this easier:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/setup.rb", segment: "application_record") %>

There are two, mirroring `pluck` and `pick`. `pluck_hash` reads a set into an array of hashes, for the batched queries below that consume every row. `pick_hash` reads a single row, and because it leans on `pick` it puts a `LIMIT` in the query, so a one-record lookup fetches one record instead of dragging the whole matching set into Ruby and keeping only the first.

The struct's `const` names line up with the columns, so the query reads the names it wants and builds the value by splatting them in:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "seat_details_query") %>

> **Note**: `pluck_hash` and `pick_hash` read columns from one table. They raise if the relation carries an `includes`, `eager_load`, or `preload`, because honoring an association means loading related records as models, which is the allocation we're trying to avoid. If you need data from another pack, call that pack's batched query and assemble the results into a composite struct. The composite read section below shows exactly that.

The caller receives a `SeatDetail` and nothing it can write to:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "seat_details_demo") %>

Sorbet enforces that return type at runtime, not as decoration, so a query that forgets the rule and hands back the record fails at its own door. Here's one that tries:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "leaky_query") %>

Call it and Sorbet's runtime check rejects the return value before the caller ever sees it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "leaky_query_demo") %>

The leak from the previous section becomes a type error raised by the query that caused it, instead of a mystery surfacing three packs away.

> **Note**: `self.call(...)` is opaque to Sorbet, so the static return type at the call site is untyped. The runtime `sig` on `execute` is what catches the leak above. If you want static checking at the call site too, define an explicit `self.call` per query with its own signature and pay one line of duplication.

## One Type System, Both Doors

That closes the read side. Now go back to the command from the last article, `ReserveSeat`, which returned a raw `Seat`. Give it a return type and a struct to satisfy it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reserve_seat_command") %>

The caller gets back an inert value:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reserve_seat_demo") %>

The command still loads the `Seat` internally, because you can only lock and update an actual record, but that record never leaves the method. Every `call` in the application, write or read, now returns a `T::Struct`. ActiveRecord stops escaping with the return value, closing the potential for callers to act arbitrarily on it.

## The N+1 You Can't See

Abstractions do not come for free. Our current queries answer one question about one record. The moment we want more and reach for a loop we're firing potentially hundreds of queries. A simple query like this is vulnerable to that issue:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "event_details_single") %>

As demonstrated by this loop, we very quickly end up with N+1s everywhere like this:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "n_plus_one_demo") %>

The abstraction hid N+1s, and the current callsite tells you nothing about this expense unless you're looking for it and monitoring.

## The Batched Query

That's why we also need the concept of a batched query which can fetch multiple records at once:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "event_details_by_ids") %>

The caller gathers its keys and asks once:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "batched_demo") %>

Which means the N+1 problem is collapsed into a single query, indexed by IDs, and usable by downstream packs for efficient batch-fetches.

## The Composite Read

Where this gets messy is when a single page needs three packs at once. A reservation view wants the seat from Seating, the event it is for from Events, and the order that paid for it from Orders, and each of those models is private to its own pack. The shape the view needs is only relevant to `Fulfillment` so it stays inline rather than in a `Data` namespace:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_view_struct") %>

The composite calls a single-key query per pack per row:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_views_naive") %>

Which gives us this count:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_views_naive_demo") %>

The batched version is a coordinator. It collects the keys each pack needs, calls that pack's by-ids query once, and assembles the result from the maps:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_views_batched") %>

The batched version produces the same data at a fraction of the cost:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_views_batched_demo") %>

Thirty-six queries become three, the same number of packs you touched, not how many rows you returned. What comes back is a tree of values:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "reservation_view_output") %>

Nothing in that result can lazy-load or be written through. The difference is you're manually writing the joins that `includes` used to write for you, but the trade is that the query count is more immediately legible: One batched call per pack in the coordination layer.

## When You Can't Collect the Keys

What happens when you _don't_ know every key you need at query time? Perhaps we're dealing with GraphQL, or we're deep inside a serializer, or we end up with multiple disparate fetches of the same data. The `batch-loader` gem exists for this case. Each call site gets a lazy placeholder instead of a value, and the first time you read from it the whole accumulated batch resolves in a single query:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "batch_loader") %>

Building the placeholders fires nothing. The first access drains the batch:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "batch_loader_demo") %>

The query underneath is the same `EventDetailsByIds`, so the loader moves the work around without copying the logic.

A word of caution: the placeholder lies about its type until forced, and the resolved values are [cached by default](https://github.com/exAspArk/batch-loader#caching) for the life of the process. In a long-running server you have to clear that cache between requests or you'll serve stale data. `batch-loader` ships a Rack middleware (`BatchLoader::Middleware`) for this, and forgetting it is the kind of bug that passes every test and fails in production.

Prefer the explicit coordinator when you can see the whole set. Reach for a loader only when the call site genuinely cannot.

## Making It Enforced

Unenforced boundaries, as we have said more than a few times by now, do not survive run-ins with large-scale production apps. Either there are hard and fast rules, or there are a litany of cases ignoring those rules that grows the moment you stop paying attention. The callbacks article shipped a cop that kept writes inside commands; reads get its mirror, a cop that keeps writes out of queries:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/queries.rb", segment: "query_must_not_mutate_cop") %>

Drop it in your project and run RuboCop. A query that writes is flagged, and a query that only reads passes:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/output.txt", segment: "cop_bad_output", lang: "text") %>

The return-type rule is harder to enforce with a cop. You can flag the obvious leaks (a method ending in `.all` or `.find`), but a query that builds its struct through a helper slips past any shallow AST check.

That's where Sorbet picks up the slack. A method signed to return a struct that hands back a relation fails at runtime, the same way `Broken::LeakyQuery` did above. The cop handles writes; Sorbet handles returns.

Packwerk holds the rest. The model lives outside `app/public` while the commands and queries live inside it, so a `Seat.where` from another pack fails CI as a privacy violation before it merges:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-queries-read-models-and-batching/output.txt", segment: "packwerk_tree", lang: "text") %>

Just as with REST APIs the point is to not ship your data model, but the actions and operations on top of it.

## Start With a Query You Own

The indexing article opened with one rule: start with the query, not the index. That rule assumes you know the query. When `Seat.where(...)` can be written anywhere by anyone, you don't.

Once reads go through query objects, you have a finite list of shapes to index against. `SeatDetailsByIds` reads five named columns, so covering it is straightforward. `EXPLAIN` runs against a query you can name, and the `ActiveSupport::Notifications` event the base emits gives you per-shape timing for free.

## Counting the Cost

A struct is a second file to update when the schema changes. The coordinator is a hand-written join. You lose ad-hoc `.where` chaining, so new filters mean new parameters or new query objects.

On a small app with one team, this is overhead you don't need. The case for paying it is the second, third, and fourth teams. In a monolith with 500+ engineers across 30+ teams, a struct is a contract a reviewer can read in five seconds, and that matters more than the boilerplate.

What's left in the model: schema, internal associations and scopes, `normalizes`, and validations. Everyone else meets it through a public API.

## Further Reading

- [Sorbet `T::Struct` documentation](https://sorbet.org/docs/tstruct), for `const`, `prop`, and serialization
- [Sorbet runtime checks and `sig`](https://sorbet.org/docs/sigs), for how signatures are enforced without the static checker
- [`Data.define`](https://docs.ruby-lang.org/en/3.2/Data.html), the Ruby 3.2 immutable value type, for when you are not running Sorbet
- The [`batch-loader` gem](https://github.com/exAspArk/batch-loader), and its Rack middleware for clearing the per-request cache
- [`GraphQL::Dataloader`](https://graphql-ruby.org/dataloader/overview.html), the fiber-based batching alternative
- [Packwerk](https://github.com/Shopify/packwerk), for `enforce_privacy` and pack boundaries
- The [callbacks](https://baweaver.com/writing/2026/06/13/rails-sharp-parts-callbacks-are-not-invariants/) and [index](https://baweaver.com/writing/2026/06/12/rails-sharp-parts-an-index-is-not-a-plan/) articles earlier in this series
- [Martin Fowler on CQRS](https://martinfowler.com/bliki/CQRS.html), for the pattern's original framing

## Wrapping Up

CQRS in a single application is two kinds of object sharing one typed boundary. Commands hold the writes, queries hold the reads, and a `T::Struct` is the only thing that crosses between them, which is what makes the seam something a tool can check.

The last article said we did not need separate databases for this, and we still don't. What changed is that the read path has collapsed into a handful of query objects with a single entry point, so pointing queries at a read replica becomes a connection-config change rather than a refactor. The sharp part is what happens when the replica is a few seconds behind, and that's where we're going next.
