---
layout: "post"
title: "Rails: The Sharp Parts. An Index Is Not a Plan"
date: "2026-06-12"
categories: []
tags: ["ruby", "rails", "mysql", "performance", "rails-sharp-parts"]
series: "rails-sharp-parts"
description: "add_index looks like a one-line fix for slow queries. It isn't. This article walks through the failure modes, proves each one with EXPLAIN on half a million rows, and shows how to build an index the optimizer will actually use."
---

Rails is great for a lot of things, but as your app gets bigger you're going to start running into issues which require you to go deeper for solutions, and some of them? Well they have a few sharp and pointy edges that it's best to be aware of.

This is a series where we dive into a few of those sharp edges, the documentation around them (they *do* warn you for a lot of these), and when and why they go from good solution to production incidents.

Last time we looked at `lock`. This time we're looking at what people reach for when a page gets slow. The query's crawling, you open the logs, you find the offender, and you do what we've all done:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "opening_example", unwrap: true) %>

> **Note**: The code samples in this article use `ActiveRecord::Base.connection.add_index` inline for demonstration. In a real app these belong in migrations.

Ship it, page's fast, close the ticket. A lot of the time that _is_ the fix. `add_index` is one of the highest-leverage one-liners Rails gives you.

It's also hiding a _lot_ of complexity under ActiveRecord, and as you scale that complexity is going to come back, and when it does you're going to need to understand the fundamentals underneath it. The intuition we start with is that _an index makes things fast_ but nothing is free, and all magic comes with a cost.

More realistically an index is a sorted data structure you're _suggesting_ to a query optimizer, a suggestion it _usually_ follows depending on costs and database-implementation-specific factors. Or it may ignore it and do a table scan anyways and spike your P95 into the lower stratosphere after a supposed minor version upgrade of MySQL.

Look, the fact of the matter is that `add_index` writes the suggestion, not the plan, and confusing the two has caused me more than a few migraines in the past. The plan is what `EXPLAIN` shows you, and the gap between the suggestion and what actually runs is the basis of this entire article.

> **Note**: To be fair MySQL at least _usually_ does the right thing, but _usually_ is load-bearing and pager-inducing. Approach with caution.

As far as examples I'll use the `bookings` table throughout, staying in the theater universe from last time:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/seed.rb", segment: "schema") %>

Half a million rows, a spread of cardinalities, and one deliberately skewed column (`status`) because skew has all types of fun surprises to contend with.

## Start With the Query, Not the Index

The query is the thing you're optimizing, not the index, and getting those two backwards will lead to a lot of unused, unloved, or frankly incorrect indexes in your database.

> **Quick aside on "selectivity,"** which I use a lot in this article. Selectivity is the fraction of a table a predicate matches; the smaller, the better. `confirmation = 'QIKF…'` matches one row in five hundred thousand, so it's highly selective. `status = 'confirmed'` matches ninety percent of the table, so it's barely selective at all. An index is a way to _skip_ rows you don't want, so the more rows a predicate lets you skip, the more an index can do for you. A predicate that skips almost nothing gives an index almost nothing to work with.

Ask these at design time, not while triaging an outage:

- What query, exactly, am I trying to make fast? (Not "searches on bookings." The literal `WHERE`, `ORDER BY`, and `SELECT` list.)
- How selective is each predicate? Which one eliminates the most rows?
- Is there an `ORDER BY` or a `LIMIT` the index could satisfy for free?
- Which columns does the query _read_? Could the index answer it without touching the table?
- And the easiest one to skip: how often does this table get _written_, and how many indexes is it already carrying?

The optimizer answers "which index, if any" by estimating the cost of each option and picking the cheapest ([MySQL: How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html)). You _can_ force its hand with `FORCE INDEX`, but that's a last resort that opts you out of future optimizer improvements; your job is to make sure the index it _wants_ exists, and to recognize when it's about to make a poor choice.

## What `add_index` Actually Does

When people read `add_index :bookings, :customer_id`, the mental model is "lookups on `customer_id` are fast now." What MySQL actually builds is a **B-tree**: a separate, sorted structure holding the values of `customer_id`, each paired with a pointer back to the row ([MySQL: Column Indexes](https://dev.mysql.com/doc/refman/8.0/en/column-indexes.html)). Because it's sorted, the database can binary-search to a value or walk a contiguous range instead of reading every row.

That mental model leaves out three things, and all three show up later as failure modes.

**One**: it builds a _sorted copy of those columns_, not a "fast" flag on the column ([MySQL: How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html)). Everything an index can do for you follows from that sorting: find a value, walk a range, read rows already in order. Everything it _can't_ do follows from the same fact. The moment your query needs something that isn't a prefix of that sorted order, the structure stops helping.

**Two**: the optimizer decides whether to use it, and it's allowed to say no. It's cost-based ([MySQL: How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html)). If it estimates that using your index would mean visiting most of the table anyway, it can reasonably conclude that a sequential scan is cheaper and ignore the index. The optimizer isn't broken; it priced the scan lower than the index and took it, and most of the time it's right to. (_Most_ of the time.)

**Three**: for a composite index, *order is everything*, because it's still just one sorted list. An index on `(customer_id, created_at)` is sorted by `customer_id` first, and only by `created_at` within a single `customer_id`. It's a phone book sorted by last name, then first name. You can find "everyone named Weaver," and "Weaver, Brandon," instantly. You can't use that same book to find "everyone named Brandon." This is the **leftmost prefix rule** ([MySQL: Multiple-Column Indexes](https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html)), and it causes more useless-index confusion than anything else on this list.

InnoDB tables are _clustered_ on the primary key, so the table itself is physically a B-tree keyed by `id`. Every secondary index you add carries the primary key with it as the row pointer ([MySQL: Clustered and Secondary Indexes](https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html)). An index on `(customer_id, created_at)` actually stores `(customer_id, created_at, id)`, and that free `id` matters when we get to covering indexes.

For a baseline, `Booking.where(customer_id: 38368)` becomes `WHERE customer_id = 38368`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_baseline", lang: "text") %>

`type: ALL` is a full table scan: the optimizer expects to examine all ~500k rows. `type: ref` with `key: idx_customer` is an index lookup that expects to touch <%= claim("baseline lookup touches few rows", "28") %>.

## The Three-Star Index

Years ago at Square I had the good fortune to work alongside Bill Karwin, and I'll have to send this article his way to make sure I'm representing this well. You see, Bill was one of those people who _wrote the book_ on SQL, and one of his favorite references was the concept of a "three-star" index.

The "three-star" index comes from Tapio Lahdenmäki and Michael Leach's _Relational Database Index Design and the Optimizers_. An index earns up to three stars for a given query:

**★ First star: the rows it needs are next to each other.** The index narrows the search to a thin, contiguous slice instead of scattering matches across the whole structure. In practice this is what equality predicates buy you.

**★★ Second star: the rows come out in the order you asked for.** If the index order matches your `ORDER BY`, the database skips the sort entirely and reads directly.

**★★★ Third star: the index has every column the query touches.** If the index already contains all the columns in your `SELECT`, the database answers from the index alone and never visits the table, which makes it a _covering_ index.

A three-star index narrows to a tight slice, reads it already sorted, and never touches the table; we'll build one by the end. Most of the failures below are some version of _losing a star you thought you had_, and a couple are the harder lesson that the three stars are sometimes contradictory and can't all be had at once.

## Failure One: The Index You Added, the Optimizer Ignored

You add the obvious index, the query doesn't get faster, and sometimes it gets _slower_.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_status", unwrap: true) %>

`status` is skewed: about 90% `confirmed`, 8% `cancelled`, 2% `pending`. The same index does very different things for different values:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_status_selectivity", lang: "text") %>

For `pending` it touches a limited number of rows, and it's fast, so we're good to ship, right? Well, `confirmed` over there is a different story: the optimizer estimates `rows=248131` but that's a sampled undercount; the real match is ~450k rows, roughly 90% of the table. Looking at `EXPLAIN ANALYZE`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_status_timing", lang: "text") %>

The optimizer _chose_ the index for `confirmed`, and that choice was a net loss: roughly <%= claim("low selectivity index slower than scan", "2.6× slower") %> than the full scan I had to force with `IGNORE INDEX`. Using a secondary index isn't free. For every match it reads the index entry, then jumps back to the clustered table for the rest of the row.

Do that for a thin slice and the jumps are cheap; do it for half the table and you've turned one sequential read into a few hundred thousand scattered ones, slower than a table scan.

> **Note**: The exact multiplier will vary with your buffer pool, cost constants, and MySQL version. The point isn't "2.6×"; a low-selectivity index gives the optimizer almost nothing, and it will sometimes use one anyway. Measuring is the only way to know whether `add_index` helped.

This isn't something you can fix with an index, nor should you. When an index is going to hit 90% of your rows it's not worth it, which is why knowing the _distribution_ of your data matters rather than guessing. Production sets the standard, and if you're not comparing to its data when making indexing decisions they'll be wrong. If you _really_ need it, make it a trailing column in a composite that filters on something selective first.

This is also where "put the most selective column first" goes wrong. Winand [calls it a myth](https://use-the-index-luke.com/sql/myth-directory/most-selective-first): column order should serve the query's shape (equality, then sort, then range), not a cardinality ranking, and Failure Three shows why.

**Selectivity is the currency you're spending.** An index on a column that barely narrows anything is, at best, dead weight you're paying for on every write, and at worst a slower plan the optimizer talks itself into.

## Failure Two: The Leftmost Prefix You Can't Reach Past

You've got a composite index and a query that filters on one of its columns, so it should be covered, right?

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_composite_esc", unwrap: true) %>

Run three queries against it, each using a different subset of the columns:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_leftmost_prefix", lang: "text") %>

The third, filtering on `status` alone, gets a <%= claim("leftmost prefix skip causes scan", "full table scan") %>, because `status` is the _second_ column in the index. With no `event_id` in the `WHERE` there's no entry point, so there's no index. The phone book is sorted by `(event_id, status, created_at)`, and asking for a `status` without an `event_id` is like asking for everyone named Brandon in a book sorted by last name.

This is the leftmost prefix rule ([MySQL: Multiple-Column Indexes](https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html)): "we have an index that mentions that column" isn't the same as "that query is indexed." The index serves any leftmost prefix (`event_id`, or `(event_id, status)`, or all three), but nothing for `status` alone or `created_at` alone.

You fix this by leading with the columns every query supplies as equalities. If you need `status` alone that's a different index, but remember Failure One before you do so.

## Failure Three: Same Columns, Wrong Order (the First Star)

Same two columns, same query, and the *only* difference is the order of the columns in the index.

`Booking.where(customer_id: 38368).where("created_at >= ?", "2024-06-01")` has one equality predicate and one range predicate. Swap the index column order and the plans diverge:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_column_order", lang: "text") %>

Identical columns, and reversing the order takes the plan from a full scan of half a million rows to an index range scan of <%= claim("equality first narrows to small slice", "twenty-seven") %>. On my laptop that was the difference between roughly 300 ms and a fraction of a millisecond.

Why does order matter this much? With `(created_at, customer_id)`, `created_at >= '2024-06-01'` is a range that smears across most of the index, and `customer_id` after the range column isn't usefully ordered within that span. The optimizer prices it as a near-full crawl and scans the table instead. With `(customer_id, created_at)`, it jumps straight to one `customer_id`, and within that customer the rows are already sorted by `created_at`: a contiguous read of a tiny slice.

So you've earned the first star: **equality predicates before range predicates** ([Winand: concatenated keys](https://use-the-index-luke.com/sql/where-clause/the-equals-operator/concatenated-keys)). Lead with the columns you pin to a single value, and only then the column you scan across. This is also why "most selective first" is sneaky: `created_at` here might be more selective in the abstract, but putting the range column first throws the index away; shape beats cardinality.

> **Aside**: This is the failure I see most in real codebases, and it's nearly invisible in code review. `add_index :bookings, [:created_at, :customer_id]` and `add_index :bookings, [:customer_id, :created_at]` look like the same migration with the words in a different order. One is a scalpel and the other is decorative, and the diff tells you little; only `EXPLAIN` gives you the full story.

## Failure Four: The Range That Eats Your Sort (First Star vs Second)

So you internalize "equality, then range" and build an index that also satisfies an `ORDER BY`. The stars aren't always available at once.

Say you want bookings for one event, over some amount, newest first: `WHERE event_id = 215 AND amount_cents >= 2000 ORDER BY created_at`. Two candidate indexes:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_range_eats_sort", lang: "text") %>

The first index puts the range column (`amount_cents`) _before_ the sort column (`created_at`). When the index does a range on `amount_cents`, the rows within that range are ordered by `amount_cents`, **not** by `created_at`, so the index can't hand back sorted output and MySQL has to run a <%= claim("range before sort causes filesort", "`Using filesort`") %> to reorder everything ([MySQL: ORDER BY Optimization](https://dev.mysql.com/doc/refman/8.0/en/order-by-optimization.html)). You got your first star (the range narrowed rows) but lost your second (the sort).

The second index puts `created_at` right after the equality column and drops `amount_cents` from the index. Now the rows for `event_id = 215` are already in `created_at` order, so there's no filesort. But `amount_cents` isn't in the index anymore, so that predicate gets applied after the fact instead of narrowing the index read.

**A range predicate uses up the index's ordering** ([Winand: greater, less, BETWEEN](https://use-the-index-luke.com/sql/where-clause/searching-for-ranges/greater-less-between-and-like), [MySQL: ORDER BY Optimization](https://dev.mysql.com/doc/refman/8.0/en/order-by-optimization.html)). Once a column takes part in a range, no column after it can be relied on for sorting. You often have to choose: narrow on the range, or read in sorted order, but not both. If the range is selective, take the first star and eat the filesort on a small set. If you're paginating a large result, the second star is usually the bigger win: append the sort column after your equality columns and the index-ordered read stops at your `LIMIT` without examining every match first.

## Failure Five: Functions Make the Index Disappear

Say you've got an index on `created_at` and you want bookings from a specific day:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_created_at", unwrap: true) %>

Seems reasonable to reach for `DATE(created_at)`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "date_function_query", unwrap: true) %>

Wrapping it in `DATE()` drops the index:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_function_date", lang: "text") %>

The index is on `created_at`, the raw column value. Wrapping it in `DATE(...)` means you're asking about the _result of a function_, and the B-tree is sorted by the input, not the output, so the index is useless and you end up with a <%= claim("function on column causes scan", "scan") %>.

Keep the column bare and express the day as a half-open range (`created_at >= '2024-06-15' AND created_at < '2024-06-16'`). That gives you an index range of ~690 rows. A predicate written so the indexed column stands alone on one side of the comparison is called *sargable* (Search ARGument ABLE, meaning the optimizer can use it as an index lookup; [Winand: functions](https://use-the-index-luke.com/sql/where-clause/functions)). Wrapping the column in a function breaks sargability.

> **Aside**: "Sargable" comes from IBM's System R project in the late 1970s, the research prototype that gave us most of modern SQL. The original paper ([Selinger et al., 1979](https://people.eecs.berkeley.edu/~brewer/cs262/3-selinger79.pdf)) used "SARG" (Search ARGument) for predicates the access-path optimizer could push into an index scan. The term outlived the research lab and became standard DBA vocabulary. It's also the kind of term that sends me down etymological rabbit holes asking "_why_, though?"

Sometimes you need the transformed value though. Case-insensitive email is the usual example:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_email", unwrap: true) %>

You index `email`, but the query asks about `LOWER(email)`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "lower_email_query", unwrap: true) %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_lower_email", lang: "text") %>

The indexed thing and the queried thing don't match. MySQL 8.0.13+ gives you a **functional index** for this, where you index the expression itself ([MySQL: CREATE INDEX, functional key parts](https://dev.mysql.com/doc/refman/8.0/en/create-index.html)):

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "functional_index", unwrap: true) %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_functional_index", lang: "text") %>

The indexed expression and the queried expression have to match exactly. Either rewrite the predicate so the column stays bare, or create a functional index on the expression you're comparing against. If they don't match, the optimizer can't use the index, regardless of how obvious the equivalence looks to you.

## Failure Six: The Problem That Isn't an Index Problem

Most of the failures so far have the same shape: you built the wrong index, or built the right index in the wrong order, and the fix is building a better one. This failure is different: the fix isn't a better index, because B-trees structurally can't do what you're asking.

Picture a support tool that looks up bookings by confirmation code. You've indexed the column:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_confirmation", unwrap: true) %>

And you're searching with a `LIKE`. The only difference between these two queries is which side of the string the wildcard lands on:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "like_queries") %>

Same column, same index, same data, and the plans diverge:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_like", lang: "text") %>

`'QIKF%'` is anchored on the left: "all confirmations starting with QIKF," which is a contiguous range the B-tree returns instantly. `'%GDNS'` is anchored on the right, and the index is sorted from the left, so there's no contiguous span to walk. The only way to find rows ending in `GDNS` is to look at every one ([Winand: LIKE performance](https://use-the-index-luke.com/sql/where-clause/searching-for-ranges/like-performance-tuning), [MySQL: Range Optimization](https://dev.mysql.com/doc/refman/8.0/en/range-optimization.html)).

This matters because none of the fixes from earlier apply. Reordering columns doesn't help when the data structure itself can't answer the question. A B-tree is sorted left-to-right, and "ends with" doesn't have a contiguous representation in that ordering, period. The moment you see `%` on the left side of a LIKE, you're past what indexing can do for you and into architecture decisions: full-text indexes ([MySQL: Full-Text Search](https://dev.mysql.com/doc/refman/8.0/en/fulltext-search.html); the ngram parser extends them to CJK and substring matching), trigram indexes (`pg_trgm` if you're on Postgres), or a dedicated search engine like Elasticsearch or Meilisearch.

Recognizing early that this isn't an indexing problem saves real time.

## Failure Seven: The Invisible Divergence

The other failures in this article are all visible if you look hard enough: wrong column order, low selectivity, a function wrapping the column. You can find them in the migration or the query. This one hides behind a schema, index, and query that are all correct while the optimizer silently does something else entirely.

Take a `phone` column stored as `VARCHAR` with an index on it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_phone", unwrap: true) %>

The string path is ordinary ActiveRecord; the numeric path has to drop below it to a raw `EXPLAIN`, which is itself the first clue:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "phone_queries") %>

The plans tell two different stories:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_type_mismatch", lang: "text") %>

Compare `phone` (a `VARCHAR`) against a string and it's an indexed lookup. Compare it against a _number_ and MySQL has to reconcile the types. Its rules say that when you compare a string column to a number, the _string_ gets converted to a number, once per row, which means it <%= claim("type mismatch drops index", "can't use the index") %> on that column ([MySQL: Type Conversion in Expression Evaluation](https://dev.mysql.com/doc/refman/8.0/en/type-conversion.html)).

The suggestion was correct and the optimizer ignored it anyway, because of an implicit type conversion rule buried in MySQL's comparison semantics that nothing in your migration, application code, or logs will surface. You find it in `EXPLAIN` or you find it in production.

In Rails you're _mostly_ protected. ActiveRecord typecasts bind parameters to match the column ([Rails: Attribute API](https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html)), so both `where(phone: value)` and `where("phone = ?", value)` will quote an integer as a string for a VARCHAR column. The "mostly" is load-bearing. It surfaces in hand-written SQL in reporting tools, `execute` calls that bypass the adapter, joins across tables where the same logical column has different types (one team's `user_id` is a BIGINT, another's is a VARCHAR, and nobody noticed until the join went sideways), or the one Metabase query a PM wrote two years ago that nobody owns.

The fix for this specific case is dull: make the types match. The larger lesson is that **the plan can diverge from your intent in ways that no amount of code review or schema inspection will catch**, which is why `EXPLAIN` is the only place the actual plan lives.

## Covering Indexes: Answering Without the Table (the Third Star)

A secondary-index lookup happens in two steps: find the entry in the index, then jump back to the clustered table for the columns the index doesn't have. If the index _already contains every column the query touches_, the jump never happens. MySQL calls this a **covering index** and flags it as `Using index` ([MySQL: How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html)).

Take the `(customer_id, created_at)` index we've been using:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "add_index_covering", unwrap: true) %>

Run two queries against it that differ only in what they `SELECT`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_covering", lang: "text") %>

The first one is covered: <%= claim("covering index no table access", "`Using index`") %>, no table access. We never put `id` in the index, yet selecting it costs nothing, because every InnoDB secondary index carries the primary key as its row pointer (whatever your PK column is, not just integer `id`; [MySQL: Clustered and Secondary Indexes](https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html)). The second query asks for `amount_cents`, which _isn't_ in the index, so the plan drops to `Using index condition` and has to visit the table for that column.

> **Note**: `Using index` (covering) and `Using index condition` are one word apart and mean very different things ([MySQL: EXPLAIN Extra](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html#explain-extra-information)). `Using index` = answered from the index, no table access. `Using index condition` = the engine pushed part of the `WHERE` down into the index scan to discard rows early, but still visited the table for the row. Both are good compared to a scan, but only the first one is the third star.

Every column you add to cover a query raises the index's write cost, so cover hot queries, not hypothetical ones.

## Assembling All Three Stars

Here's what all three stars look like on one query: a customer's recent bookings, newest first, selecting only what we'll render in the UI:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "three_star_query", unwrap: true) %>

The `(customer_id, created_at)` index from the covering section already earns all three stars for this query, and the plan confirms it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_three_star", lang: "text") %>

- ★ `type: range`, `rows: 27`: the equality on `customer_id` dove to one customer and the range on `created_at` read a contiguous slice.
- ★★ no `Using filesort`: `created_at` comes right after `customer_id` in the index, so the slice is already in the requested order.
- ★★★ `Using index`: the query reads only `id` and `created_at`, both in the index (`id` for free, courtesy of InnoDB), so it never touches the table.

Two columns in the right order turned a half-million-row scan into a sub-millisecond read that never touches the table. Build the index that earns every star a query can give, instead of reflexively adding one.

## The Other Direction: Every Index Taxes Writes

Everything so far has been about reads, but an index is a second sorted structure the database has to keep in sync, which means **every `INSERT`, `UPDATE`, and `DELETE` has to update every affected index too** ([MySQL: InnoDB Index Types](https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html), [Winand: insert performance](https://use-the-index-luke.com/sql/dml/insert)). Indexes aren't free; they're a tax on writes that you pay in exchange for faster reads.

To measure the cost, I ran 60,000 batched inserts into two identical tables, one bare and one carrying five secondary indexes:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "explain_write_tax", lang: "text") %>

Five indexes made writes roughly <%= claim("write tax with 5 indexes", "2.4× to 2.6× slower") %>. On the cost side that slowdown is why "add an index for every column someone might filter on" is a named antipattern. Karwin calls it the **Index Shotgun** in *SQL Antipatterns* ([Pragmatic Bookshelf](https://pragprog.com/titles/bksap1/sql-antipatterns-volume-1/)): indexing by buckshot, hoping you hit the useful ones and paying for all the misses on every write.

Karwin's counter to guessing is the **MENTOR** method ([Karwin, *SQL Antipatterns*](https://pragprog.com/titles/bksap1/sql-antipatterns-volume-1/), the Index Shotgun chapter): **M**easure to find the queries that are actually slow, **E**xplain them, **N**ominate candidate indexes from what the plan actually needs, **T**est the change, **O**ptimize by keeping what helped, and **R**ebuild or maintain over time. Index in response to a measured query, never in anticipation of an imagined one.

## Redundant Indexes

If a composite index _leads_ with a column, a separate single-column index on that same column is redundant, because the composite already serves it via the leftmost prefix.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "redundant_indexes") %>

MySQL's `sys` schema will flag these for you:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/output.txt", segment: "redundant_sys_query", lang: "sql") %>

Drop `idx_cust`, keep only `(customer_id, created_at)`, and `WHERE customer_id = 38368` still uses the composite. Run `sys.schema_redundant_indexes` periodically; redundant indexes pile up as different people add what they need without checking what's already there.

## So Which Index Do I Build?

| Situation | Reach for |
|---|---|
| Equality lookup on a selective column | single-column index on that column |
| Equality + range (e.g. `customer_id` + date range) | composite, **equality column first**, then the range column |
| Filter + `ORDER BY` | composite: equality columns, then the sort column (matching direction) |
| Read only a few columns, hot query | covering index; add the selected columns so it's `Using index` |
| Low-selectivity column (`status`, booleans) | usually *no* index alone; only as a trailing part of a composite |
| Day/truncated match on a timestamp | keep the column bare, use a half-open range; never `DATE(col)` |
| Case-insensitive / computed match | functional index on the expression (`LOWER(email)`), 8.0.13+ |
| Prefix search (`'foo%'`) | plain B-tree handles it |
| Infix / suffix search (`'%foo'`, `'%foo%'`) | full-text index or a search engine, **not** a B-tree |
| Composite that leads with an existing single index | drop the redundant single-column index |
| Rolling out a new index safely | add as `INVISIBLE`, verify the plan with `EXPLAIN`, then `ALTER ... VISIBLE` |

## Instrumentation, or: Seeing the Plan

If you can't measure it you shouldn't be optimizing it, and if you can't see the plan you're guessing.

`EXPLAIN` is the core tool. It shows you the plan the optimizer chose: the `type` (`ALL` is a full scan, `ref`/`range`/`eq_ref` use an index), the `key` it picked, the `rows` it estimates, and the `Extra` column where `Using filesort`, `Using index`, and `Using index condition` live ([MySQL: EXPLAIN Output Format](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html)). From Rails:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "explain_example") %>

Sometimes the estimate lies: `EXPLAIN ANALYZE` runs the query and reports real timings per step ([MySQL: EXPLAIN ANALYZE](https://dev.mysql.com/doc/refman/8.0/en/explain.html#explain-analyze)), which is how I caught Failure One, where plain `EXPLAIN` said the index would be used and only `ANALYZE` revealed it was slower than the scan.

To find the queries that need `EXPLAIN`-ing in the first place, turn on the slow query log ([MySQL: The Slow Query Log](https://dev.mysql.com/doc/refman/8.0/en/slow-query-log.html)) with a sane `long_query_time`, enable `log_queries_not_using_indexes` to surface full scans hiding under the threshold, and run the output through Percona's `pt-query-digest` to rank by total time.

The `sys` schema ([MySQL: sys Schema](https://dev.mysql.com/doc/refman/8.0/en/sys-schema.html)) surfaces problems you didn't know to look for:

- `sys.schema_tables_with_full_table_scans`: tables getting scanned, your index to-do list.
- `sys.statements_with_full_table_scans`: the statements doing the scanning.
- `sys.schema_redundant_indexes`: the duplicates from the last section.
- `sys.schema_unused_indexes`: indexes nothing has touched since the last restart, strong candidates to drop.

Once you've found a slow query you still need to trace it back to the code that generated it, and once you've built the fix you need to roll it out safely. Rails 7+ ships `ActiveRecord::QueryLogs` ([Rails: QueryLogs](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html)) for the first part:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "query_log_tags", unwrap: true) %>

And MySQL 8.0's invisible indexes ([MySQL: Invisible Indexes](https://dev.mysql.com/doc/refman/8.0/en/invisible-indexes.html)) handle the second: add the index without the optimizer using it, then flip it visible once you've confirmed the plan improves:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-an-index-is-not-a-plan/indexes.rb", segment: "invisible_indexes") %>

## Further Reading

Winand's [*Use The Index, Luke!*](https://use-the-index-luke.com/) is free, web-native, and where I'd send someone who wanted one resource on this topic. The three-star model comes from Lahdenmäki and Leach's *Relational Database Index Design and the Optimizers*, which is dense and academic but repays the effort if you want to understand _why_ optimizers make the choices they do. Karwin's [*SQL Antipatterns, Volume 1*](https://pragprog.com/titles/bksap1/sql-antipatterns-volume-1/) is where the Index Shotgun and MENTOR come from; his [*More SQL Antipatterns*](https://pragprog.com/titles/bksap2/more-sql-antipatterns/) (Volume 2) covers non-sargable queries and pagination directly and is the more relevant volume for this article's territory (examples are PostgreSQL and Python, but the principles transfer). Baron Schwartz's *High Performance MySQL* is the InnoDB deep-dive if you need to understand buffer pools and page splits.

MySQL's own docs are underrated: the chapters on [How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html), [Multiple-Column Indexes](https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html), [ORDER BY Optimization](https://dev.mysql.com/doc/refman/8.0/en/order-by-optimization.html), and [EXPLAIN Output Format](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html) repay an end-to-end read rather than skimming for the one answer you need in the moment.

## Wrapping Up

Run `EXPLAIN` before you deploy your next index: `add_index` writes the suggestion, and the plan is the only place you learn whether the database took it. Every production index bug I've debugged lived in that gap.

Next time we're going to leave SQL for a moment and focus on callbacks in Rails, which have caused more outages than I would care to count or really even admit to over my career. (Hint: implicit magic at scale, run by teams who don't know the underlying mechanics, is a ticking time bomb, and almost anything in that category is _definitely_ a "Sharp Part" of Rails.)
