---
layout: "post"
title: "Rails: The Sharp Parts. lock Is Not a Mutex"
date: "2026-06-05"
categories: []
tags: ["ruby", "rails", "concurrency", "mysql", "rails-sharp-parts"]
series: "rails-sharp-parts"
description: "lock looks like a one-line fix for concurrency bugs. It isn't. This article walks through eight failure modes, proves each one with forking tests, and shows what actually holds an invariant."
---

Rails is great for a lot of things, but as your app gets bigger you're going to start running into issues which require you to go deeper for solutions, and some of them? Well they have a few sharp and pointy edges that it's best to be aware of.

This is a series where we dive into a few of those sharp edges, the documentation around them (they _do_ warn you for a lot of these), and when and why they go from good solution to production incidents.

We're going to start with `lock`. Most of us have written something that looks roughly like this:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "opening_example", unwrap: true) %>

At a glance it looks fine: lock the seat, check the state, update, and on we go. Not too hard to understand, reasonably clear, what's wrong with that?

The trap we fall into with ActiveRecord is that it abstracts a lot of details from us, in some cases database behavior which is unique to each implementation, and in others from the way the underlying concept works if we're not careful.

Looking at `lock` you might think, reasonably, that it's effectively a database mutex that _just works_, but that's not quite the case. More accurately ActiveRecord is asking the underlying database for a pessimistic lock ([Rails: `ActiveRecord::Locking::Pessimistic`](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html)), and how it goes about that depends on transaction boundaries, isolation levels, the database, the query, and _every other code path_ that happens to touch the same rows.

Rails gives you `lock`, `lock!`, and `with_lock` but at the end of the day the database makes the rules, and it may not be fully aligned with your mental model.

Now to be clear, there is a time and a place for locks. A well scoped `SELECT ... FOR UPDATE` in a real transaction _is_ a synchronization primitive, and it _really does_ fix a single-row lost-update race. What it _does not_ do is protect an invariant that spans multiple rows, rows that don't exist, or anything which lives above a single record. Lucky for you that's the category of bugs that will absolutely ding PagerDuty.

They're sneaky little things too. They tend to go by a few other names like latency, retries, deadlocks, stale data, or duplicate work. Race conditions are always such delightful fun to figure out because they're so difficult to simulate locally in tests.

(I should know, it took me way too long while writing this article to do so)

## Start With the Invariant, Not the Lock

Locks are an implementation detail. The invariant is the architecture, and if you get those two backwards you'll spend a lot of time tuning the wrong thing.

> **Quick aside on "invariant,"** since I'm going to lean on the word a lot. An invariant is just a rule about your data that's supposed to be true no matter what, before and after every operation, forever. "An account balance is never negative." "Every order belongs to exactly one customer." "A seat is reserved at most once." The whole game in this article is making the database hold those rules for you instead of hoping every piece of code politely remembers to.

I'm going to use seat reservations for the whole article, because the invariant is straightforward to say out loud:

> A seat may be reserved at most once.

Now picture two requests landing at almost the same instant:

```text
A reads status -> available
B reads status -> available
A reserves
B reserves
```

Each request looks fine in isolation, they both did what we'd want, but the second you remove isolation you have an issue. Neither of those two requests knows about each other, and correctness was never a property of a single request. Together? They run into each other.

So before you reach for a `lock` remember to ask a few questions:

* What invariant am I protecting?
* Who is even allowed to write this resource?
* Can the database express this rule directly with a constraint, a unique index, a `CHECK`?
* Is the contention surface one row, a pile of rows, or a *predicate* over a set of rows that might not all exist yet?
* Which resources participate, in what order?

Most locking failures I've seen trace straight back to an invariant nobody ever wrote down, or one that turned out to be a lot bigger than the single row people were locking.

## What `lock` Actually Does

When people read `Seat.lock.find(id)`, the mental model is "only one thing can touch this now." What Rails actually emits is closer to:

```sql
SELECT * FROM seats WHERE id = ? FOR UPDATE
```

`Account.lock.find(1)` produces exactly that `SELECT … FOR UPDATE`, and you can pass your own database-specific clause like `lock("FOR UPDATE NOWAIT")` or `lock("FOR UPDATE SKIP LOCKED")` when you need it ([Rails: `ActiveRecord::Locking::Pessimistic`](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html)).

There are three things that mental model leaves out, and all three of them have certainly caused issues.

**One**: The lock lives exactly as long as the surrounding transaction, and not one millisecond longer. A bare `Seat.lock.find(id)` with no transaction around it runs inside an implicit single-statement transaction that commits the instant the `SELECT` returns, so you acquire the lock and release it in the same breath. It protects nothing. We'll come back to this one because it's sneaky.

**Two**: Behavior is adapter-dependent in ways the shared Rails API abstracts. MySQL on InnoDB gives you real row-level locking with gap and next-key locks, `FOR UPDATE`, `FOR SHARE`, `NOWAIT`, and `SKIP LOCKED` since 8.0 ([MySQL: InnoDB Locking](https://dev.mysql.com/doc/refman/en/innodb-locking.html)). PostgreSQL gives you similar row-level locking with SSI for `SERIALIZABLE`. SQLite uses a single-writer, database-level model where `SELECT … FOR UPDATE` is a polite fiction ([SQLite: File Locking](https://sqlite.org/lockingv3.html)). Same Ruby, wildly different guarantees.

**Three**: The lock only protects the rows it actually returned. Not the rows that should have matched. Not the rows someone is about to insert. The ones it locked, and that's it. Hold onto that, because it's the root of half the rest of this article.

## `lock` vs `lock!` vs `with_lock`

These three are not interchangeable.

`Model.lock.find(id)` is a relation method. It bolts the locking clause onto a `SELECT`. On its own, outside a transaction, it acquires nothing you can use.

`record.lock!` reloads an *already-loaded* record with a lock. Worth knowing: as of Rails 5.2, calling `lock!` on a record that has unsaved changes will straight-up raise, with `"Locking a record with unpersisted changes is not supported"`, and tell you to `save` or `reload` first ([Rails API source](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html)). It'll also raise `ActiveRecord::ReadOnlyError` if writes are currently prevented. This is a good change; the old behavior silently did something you almost never wanted.

`record.with_lock { ... }` is the one I reach for most. It wraps your block in a transaction, reloads the record with a lock, and then yields. Since Rails 7 it also takes transaction options, so `with_lock(isolation: :serializable) { ... }` and `with_lock("FOR UPDATE NOWAIT") { ... }` both work ([Saeloun: Rails 7 with_lock options](https://blog.saeloun.com/2022/03/23/rails-7-adds-lock-with/)). The implementation is impressively small:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "with_lock_implementation", unwrap: true) %>

If you only need one record by id, use `with_lock`. It makes the transaction boundary impossible to forget, and forgetting the transaction boundary is the next thing we're going to talk about.

## Failure One: Lost Updates

This is the classic, and it's where everyone starts:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lost_update_broken", unwrap: true) %>

Under any real concurrency, both callers read `reserved == false`, both sail past the guard clause, and both write. Invariant violated, and it'll pass every test you write on your laptop because your laptop never runs the two requests at the genuinely-same time.

> **Note**: Proving this in a test harness is harder than you'd think. Threads share a connection pool and tend to accidentally serialize against each other, so you end up needing `fork` to get genuinely concurrent database sessions. It took me longer than I would care to admit to get that working reliably.

One fix is a pessimistic lock, and it's a correct fix for the single-row case. ("Pessimistic" because it assumes a conflict is likely and grabs the row up front so nobody else can touch it. Its opposite, optimistic locking, assumes conflicts are rare and only checks at save time whether someone beat you to it. We'll get to that one near the end; for now, pessimistic.)

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lost_update_fixed_lock") %>

That said, when possible, don't do in Ruby what could instead be done by the database:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "reservation_migration", unwrap: true) %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lost_update_fixed_constraint") %>

There are two things people get wrong about this when they see it:

**One**: `create!` *raises* `ActiveRecord::RecordNotUnique` on a conflict (it does not return `false`), so you have to rescue it, or that uncaught raise rolls back whatever transaction it was sitting inside.

**Two**: you've now got two places that claim to know whether a seat is taken: the `seats.reserved` column and the existence of a `reservations` row.

Pick one as canonical. If you keep the column, treat it as a denormalized cache you update in the same transaction, not as a second independent source of truth that can drift.

Constraints are preferred because they're enforced on _every_ write path, including the one that someone may unwittingly add to a background job years later in code outside of your domain. Application-level protections can only stop paths that play by the rules and coordinate.

> **Aside**: Single-ingress writes are worth their weight in gold, especially ones that are enforced via something like Packwerk and RuboCop rules. They eliminate callbacks, allow for easier instrumentation, clearer optimization paths, and much easier debugging. ActiveRecord objects are _hot_ no matter where they are in the app, including outside of your domain area, and those folks are real unlikely to know about your constraints unless they're explicitly enforced.

## Failure Two: Locking Too Little, Which Is To Say, Forgetting the Transaction

This one seems safe, right?

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lock_no_transaction", unwrap: true) %>

Unfortunately, no. A lock's lifetime is as long as its transaction, not by indentation level or how long the object is visible. With no transaction that `FOR UPDATE` lock expires the moment the `SELECT` completes, effectively <%= claim("bare lock releases immediately", "immediately") %>. So `do_work` and `update!` both run with exactly zero protection. You wrote `lock` right there in the code, you can see it, and it's doing nothing.

The fix is to make the boundary explicit:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lost_update_fixed_lock") %>

or to let `with_lock` own the boundary so you can't forget it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "with_lock_usage", unwrap: true) %>

## Failure Three: Locking Too Much (and the tool nobody mentions, `SKIP LOCKED`)

This category causes more incidents in big systems than people expect, mostly because it looks responsible. Here's the shape of it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lock_too_much", unwrap: true) %>

The intent in someone's head was "lock the seat I need." The effect is "lock every seat this query returns," which means every concurrent reserver now lines up single file behind the same pile of rows. You built a queue and didn't mean to.

If you need one specific seat, lock one row:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "single_row_lock") %>

Problem is what people might also want is to claim _any available seat_ instead, and for that blocking on rows another transaction is already holding won't work. MySQL 8.0's `SKIP LOCKED` does the right thing (it steps over locked rows instead of waiting on them), and it's the idiomatic way to claim a row out of a pool ([MySQL: SELECT … FOR UPDATE](https://dev.mysql.com/doc/refman/en/innodb-locking-reads.html)):

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lock_skip_locked") %>

Lock the smallest set of records that protects the invariant, and when in a pool skip what's already claimed.

## Failure Four: Long Transactions

Lock *duration* matters every bit as much as lock *scope*, and this is the pattern that quietly turns a fast endpoint into a contention issue:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "long_transaction", unwrap: true) %>

Your lock is now held for as long as it happens to take a third party to retry, maybe timeout, maybe who knows what but your fate is now coupled to theirs. Everyone who wants a seat waits that entire time. Locks are for protecting database work, not the entire business workflow.

Extract the external calls out of the locked area: reserve in a transaction, charge afterwards, and reconcile if that charge fails.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "short_transaction") %>

And when you genuinely do have to contend, don't queue forever. There are two different knobs here and people constantly mix them up, so let me separate them clearly.

`NOWAIT` means *fail immediately* if any row you want is already locked. (One subtlety: it only declines to wait for *row-level* locks; it can still block on a table-level lock, per the MySQL docs ([InnoDB Locking Reads](https://dev.mysql.com/doc/refman/en/innodb-locking-reads.html)).)

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "nowait_example", unwrap: true) %>

([Saeloun: Rails 7 with_lock options](https://blog.saeloun.com/2022/03/23/rails-7-adds-lock-with/))

`lock_timeout`, on the other hand, is the one that actually *bounds* the wait. Wait up to N milliseconds, then error. This is your "degrade gracefully instead of hanging forever" control:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lock_timeout_example", unwrap: true) %>

(`SET innodb_lock_wait_timeout` is session-scoped on MySQL. Use `with_connection` in Rails 8 to lease a connection for the block and hand it back when done. Bare `Model.connection` has been soft-deprecated since Rails 7.2 in favour of `with_connection` / `lease_connection` ([Rails: Connection Handling](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionHandling.html)).)

That `innodb_lock_wait_timeout` syntax is MySQL-specific (in whole seconds). PostgreSQL spells it `SET LOCAL lock_timeout = 'Ns'` (scoped to the transaction), and SQLite's nearest equivalent is `PRAGMA busy_timeout = N` (in milliseconds, database-level). Same idea, three different spellings, and only one of them is right for the database you actually run.

Either way, pair it with a retry-and-backoff policy so the caller has somewhere sane to land.

## Failure Five: Deadlocks

Back to our theater example let's say you're booking a group of seats, maybe for your family. If person A tries to book 5 seats and then person B tries to book 5 seats what do you suppose happens if they try and lock those seats in a different order and try and lock another seat that the other one has a lock on? Take this example, for instance:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "deadlock_broken", unwrap: true) %>

Now we have person A holding row 1 and waiting on row 2, but if person B is holding row 2 waiting on row 1 they're at an impasse. Neither will give up, and they will stubbornly sit there until either you kill it or hopefully the database does something clever and makes them stop arguing. MySQL / InnoDB detects the cycle automatically and rolls back one transaction to break it; the docs recommend acquiring locks in a consistent order to avoid the situation entirely ([MySQL: Deadlocks](https://dev.mysql.com/doc/refman/en/innodb-deadlocks.html)).

So impose an order:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "deadlock_fixed") %>

Using a consistent order guarantees in what order those transactions are locked, preventing the potential for a cycle so that someone is always going to make some forward progress. ([MySQL: InnoDB Locking](https://dev.mysql.com/doc/refman/en/innodb-locking.html)).

Now some of these deadlocks and lock-wait timeouts are going to happen anyways, so you want to make sure you have a method for retrying things in those cases. The problem is if you haven't considered idempotency (TL;DR: prevent doing things that already happened) you're going to end up duplicating a lot of events in the process:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "retry_with_backoff") %>

## Failure Six: Write Skew, or Why Row Locks Aren't Enough

Consider the case in which we have a rule that we need _at minimum_ one admin on call at any given time:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "write_skew_broken") %>

If we have two transactions hit that at the same time they're both going to see `2` admins and decide to proceed, leaving you with no one on call even though both transactions were _technically_ correct. Since the invariant exists _above_ any single row any lock on rows will never catch those edge cases.

`SELECT ... FOR UPDATE` only guarantees no concurrent modifications for the rows it actually locked. That means if someone else creates a new row that matches those same rules, or updates a row we didn't lock, they can walk right on past our locks ([MySQL: Consistent Nonlocking Reads](https://dev.mysql.com/doc/refman/en/innodb-consistent-read.html)). Locks are great, but they're not a catch-all, and sometimes in these types of cases called write skews we're going to need something bigger, and that can look like one of three things:

**One**: `SERIALIZABLE` isolation. MySQL's `SERIALIZABLE` implicitly converts all reads to `SELECT ... LOCK IN SHARE MODE`, so the count query takes shared locks on the matching rows. The second transaction blocks until the first commits, then re-reads and sees the updated state ([MySQL: Transaction Isolation Levels](https://dev.mysql.com/doc/refman/en/innodb-transaction-isolation-levels.html)). In Rails:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "write_skew_fixed_serializable") %>

`SERIALIZABLE` is the only level that _guarantees_ write skew can't happen, but it isn't free. On MySQL it moves the cost onto blocking: every read takes a shared lock, so concurrent transactions serialize on the same rows and throughput drops under contention. In practice this often surfaces as a deadlock (both hold shared locks, both try to upgrade to exclusive) rather than clean blocking, so you'll still need retry logic ([MySQL: Transaction Isolation Levels](https://dev.mysql.com/doc/refman/en/innodb-transaction-isolation-levels.html)).

**Two**: Materialize the invariant as a row you _can_ lock. Find a single parent or counter row (a `teams` row, say) that every participating transaction has to lock first, and suddenly skewing transactions serialize on that one row even at `READ COMMITTED`.

**Three**: An advisory lock over the logical resource, which is the next section, because it's the right tool when there's no row to point at in the first place.

## Failure Seven: Predicate Problems and Phantom Reads

Similar to the above point some invariants aren't really about rows at all, they're about a _set_ or rows and that's a different problem. Take this case for example:

> No more than 100 reservations per event.

Locking one seat does nothing for this:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "phantom_broken") %>

Concurrent transactions can easily create new records that match this rule that locks never saw and never could have seen because they _did not exist_ before. That gives us a few options:

**One**: lock the aggregate (take a `FOR UPDATE` on the `events` row first in every reservation path, so all the inserts for that event serialize behind it):

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "phantom_fixed_aggregate_lock") %>

**Two**: `SERIALIZABLE`.

**Three**: Express the limit as a constraint, like a counter column with a `CHECK` maintained in the same transaction.

What you don't get to do is wave at "stronger isolation or a redesign" and call it a day: pick the mechanism.

## Failure Eight: Hidden Writes Make Hidden Locks

Admittedly one of my chief complaints about Rails: Good luck tracking down every caller who writes to a given table, and good luck keeping control of all the callbacks and other observing magics.

A single `save` could fire callbacks, `touch` a parent association, autosave another association, persist nested records, or even bump a counter cache.

That means that single action quietly touches far more than that single row you're currently looking at, and every one of them may have their own locks, widening the blast radius. More locks means more risk for contention, and that means more incidents. A single well timed `touch: true` on a hot parent row is a real good way to figure this out quickly.

There are a few options here, and personally? I think the latter is the better one long term:

**One**: Know every single downstream effect from `save` by heart and make sure all of those locks are understood and are not conflicting.

**Two**: Isolate your writes into a single ingress, a Command object or something of the like, and ensure that any "callbacks" are explicit code inline that can be reasonably understood at a glance rather than across 10+ files.

The second is more expensive, sure, but in a large Rails app it quickly becomes necessary to isolate when and where things are written to your domain's tables. The first, if we're being honest, is a wish and a prayer. Prefer the explicit and clear route, versus the implicit and hard to follow one.

## The One That Quietly Undoes All the Others: Callers You Don't Control

There's a reason I keep on harping on single-ingress for writes and commands: Callers you do not control can _very easily_ invalidate all of your careful locking with one badly timed `update` outside of a transaction and locking. A convention is only as strong as a programmer who didn't know it existed, and in a large enough code base that is the rule, not the exception.

So you write the careful version:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "careful_lock_example", unwrap: true) %>

It's reasonable code, it does what we mentioned, but time goes by you start to see some things:

* Someone wrote a background job that backfills reservations via CSV
* Another made an admin rake task to fix stuck events
* There's a new webhook handler an away team wrote
* To your horror there's someone with a console open at 2AM who just wrote `seat.update!(reserved: true)` directly to unstick a customer. (Why is that still on!?)

Not a single one touched the lock, heck, they probably didn't even know there was one. They merrily drive right over the top of it, none the wiser, because you do not control who can write to your data.

If correctness relies on the caller behaving themselves (remember to wrap in a transaction, take a lock, and order things!) then you do not have a hard and fast rule, you have a ticking time bomb. It's a matter of when, and not if, someone does this and probably without knowing anything about the underlying side effects at play.

The test you need to apply is: Can a caller who knows nothing about my rules violate my data? If the answer is yes then your invariant is not secured, it's at best politely respected while people remember it exists.

There are two ways to fix this, and they're complementary:

**Enforce a single ingress for writes.** If every write to `seats` goes through one service object, one command, one entry point, then your locking logic lives in exactly one place and cannot be bypassed by a careless caller. Packwerk's `enforce_privacy` and RuboCop rules make this enforceable. A privacy violation on a direct model reference stops the rake task author before they even commit. Some application layer constraints can and should be enforced.

**Push constraints into the database.** A unique index does not care which code path tried to violate it. A `CHECK` constraint, a foreign key, a `NOT NULL`: these are enforced on *every* write, including the writes that don't exist yet, written by people who will never read your code.

Together they give you defense in depth: the single ingress keeps callers honest at development time, and the constraint catches anything that slips through at runtime. One without the other leaves a gap.

Pessimistic locks, advisory locks, the careful ordering, all of it is still useful. The difference is whether you're relying on convention or enforcement. If your single ingress is enforced by tooling and your constraints are in the schema, locks become an optimization detail inside the one path that's allowed to write.

## Advisory Locks: For Locking Things That Aren't Rows

Going back to what we mentioned in sections six and seven: Sometimes there's no row to lock, and we have to get clever. That's what advisory locks are for, they let us lock a _logical_ resource (e.g. does not exist yet but follows some rules) by everyone agreeing on a named key. MySQL provides `GET_LOCK(name, timeout)` for this ([MySQL: Locking Functions](https://dev.mysql.com/doc/refman/en/locking-functions.html)).

There are a few rules to know when using them though:

MySQL's `GET_LOCK` is session-scoped and released explicitly with `RELEASE_LOCK` or when the session ends. MySQL only supports one named lock per session (prior to 5.7) though 5.7+ supports multiple, which should be the case for most readers considering it's EOL'd as of late 2023 (* though there are always apps which are difficult to upgrade for which this _might not_ be true quite yet.) For Rails, `with_advisory_lock` ([repo](https://github.com/ClosureTree/with_advisory_lock)) wraps the MySQL variant cleanly.

Remember though that advisory locks are _voluntary_. The database is not going to check whether or not you used them unless you tell it to, so one bad code path and we're right back to the races, further highlighting the need to keep tight control over ingress points to SQL. Be consistent and rigorous, same as any other lock, or you'll be right back to the above problems.

Rails itself uses advisory locks to ensure migrations only run one process at a time, raising `ActiveRecord::ConcurrentMigrationError` if two try at once ([Rails: ActiveRecord::Migration](https://api.rubyonrails.org/classes/ActiveRecord/Migration.html)).

## Optimistic Locking: The Right Default When Conflicts Are Rare

Let's say we choose to look at the brighter side of things, maybe collision is rare and we _can_ in fact have nice things (we can't) but just pretend for a moment. Everything above is paying a tax for coordination, and that can be expensive, and perhaps sometimes there's a better trade to be made, a more _optimistic_ one if you will. If conflicts are rare you're making a bad trade paying those taxes, and that's exactly what optimistic locking does: don't lock, just flag it at save time when someone else got there first and action based off of that.

How does that work? Well we add an integer `lock_version` column defaulting to `0`. Rails increments this row on every update and quietly sneaks a `WHERE lock_version = ?` onto the `UPDATE`. If a row moves under you zero rows match and you get an `ActiveRecord::StaleObjectError` you can catch to retry on your own terms ([Rails: `ActiveRecord::Locking::Optimistic`](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html)).

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "lock_version_migration", unwrap: true) %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "optimistic_locking") %>

For the low low price of one column you can potentially have zero lock-wait time, but the price is having to manually deal with whatever conflict emerges from that. It makes sense when collisions are genuinely rare, but if you have it or you have some nastier invariants that are more structural in nature perhaps that pessimistic tax isn't such a bad idea.

## So Which One Do I Use?

If you want the whole thing on one screen:

| Situation | Reach for |
|---|---|
| Single-row lost update | `SELECT … FOR UPDATE` in a transaction, or a unique constraint |
| "Reserve once" uniqueness | unique index + rescue `RecordNotUnique` |
| Claim any row from a pool | `FOR UPDATE SKIP LOCKED` |
| Fail instantly on contention | `FOR UPDATE NOWAIT` + retry on `LockWaitTimeout` |
| Bound how long you'll wait | `SET innodb_lock_wait_timeout` + retry |
| Rare conflicts, hot read path | optimistic `lock_version` |
| Multi-row invariant / write skew | `SERIALIZABLE` (shared locks on reads), or lock an aggregate row |
| Predicate / phantom invariant | lock the aggregate, `SERIALIZABLE`, or a constraint |
| Lock a non-row / logical resource / worker | transaction-scoped advisory lock |
| Writers you don't control / can't enumerate | database constraint + enforced single ingress (Packwerk, RuboCop) |

## Instrumentation, or: Seeing the Waiting

A friend once said that if you can't measure it you shouldn't be trying to optimize it. If you can't observe it you can't reason about it, and if you can't reason about it you're guessing. You're going to want eyes on deadlocks, transaction durations, retries, lock-wait time, blocked queries, and queue times.

The most basic version of this is a notification subscriber that flags slow queries:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-lock/lock.rb", segment: "slow_sql_subscriber", unwrap: true) %>

But this only shows you slow _statements_, not lock _waits_. A query that took 3 seconds might have spent 2.9 of those seconds waiting on a lock and 0.1 actually executing. From the subscriber's perspective it just looks slow.

For tracing queries back to the code that generated them, Rails 7+ ships `ActiveRecord::QueryLogs` ([Rails: QueryLogs](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html)). Enable it and every query gets a comment appended with the app name, controller action, job name, or even `source_location` (the exact file and line):

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags = [:application, :controller, :action, :source_location]
```

That means when you see a locked query in `SHOW PROCESSLIST` or `performance_schema` you can trace it straight back to the line that generated it without guessing.

For the actual lock picture you need the database itself:

* `SHOW ENGINE INNODB STATUS` gives you the most recent deadlock, current lock waits, and transaction state
* `information_schema.INNODB_TRX` shows running transactions and what they're waiting on
* `performance_schema.data_locks` and `performance_schema.data_lock_waits` show who holds what and who's blocked

([MySQL: InnoDB Monitors](https://dev.mysql.com/doc/refman/en/innodb-monitors.html))

Beyond that if you want continuous monitoring rather than ad-hoc queries, Percona Toolkit's `pt-deadlock-logger` polls InnoDB status and logs every deadlock it finds to a table or file. If you're running any APM (Datadog, Scout, Skylight, etc.) make sure it's capturing lock-wait time as a distinct span, not just total query duration. "This query is slow" and "this query is waiting on a lock" look identical in a latency graph but have completely different fixes.

## Further Reading

On the Rails side, the [`ActiveRecord::Locking::Pessimistic`](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html), [`ActiveRecord::Locking::Optimistic`](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html), and [`ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html) docs are the source of truth. On the database side, MySQL's [InnoDB Locking](https://dev.mysql.com/doc/refman/en/innodb-locking.html) and [Transaction Isolation Levels](https://dev.mysql.com/doc/refman/en/innodb-transaction-isolation-levels.html) chapters are worth reading end to end at least once. For the adapter, [Trilogy](https://github.com/trilogy-libraries/trilogy) is the modern MySQL client for Ruby, fork-safe by design. And for the theory underneath, Martin Kleppmann's *Designing Data-Intensive Applications* (the write-skew and isolation material in particular) and Alex Petrov's *Database Internals*.

## Wrapping Up

The hard part of `lock` was never typing `Seat.lock.find(id)`. The hard part is everything else around it.

Large enough apps rarely fall over because someone forgot a lock, they fall over because of all of the things around that lock. The write paths that drifted, the lock scope which crept outward with each code change, the transaction that outlived the database work, or that the real behavior of the database is different than you might think looking at ActiveRecord.

You want to name the invariants first, and then pick the smallest mechanism you can that the database will enforce for you, that your linter will catch, and that your CI system will fail on. Despite best intentions someone will always manage to run afoul of implicit rules and expectations, so make them clear, explicit, and above all as enforced as you can to make sure it's caught before production.
