---
layout: "post"
title: "Rails: The Sharp Parts. The Block Is Not the Transaction"
date: "2026-08-22"
categories: []
tags: ["ruby", "rails", "transactions", "mysql", "rails-sharp-parts"]
series: "rails-sharp-parts"
description: "Transactions are more complicated than an easy-to-use block, and treating them as such will come back to bite you. This article will cover a few of them."
---

In the [lock article](https://baweaver.com/writing/2026/06/05/rails-sharp-parts-lock-is-not-a-mutex/) we broke down how the mental model of a "database mutex" is fundamentally broken, and will come to surprise you over time. This article is going to do the same with transactions, which many of us early on may think of `transaction do ... end` as a magic incantation to save us from database woes when we write something like this:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "opening_example", unwrap: true) %>

This reads a lot like a promise that everything will either succeed together, or fail and clean up for us like magic. If there's any lesson you should learn with Rails it's that magic always comes with a cost, and "obvious" things have failure modes that tend to show up at the most inopportune moments.

One might expect that this transaction safely wraps the act of charging, ledgering, dispatching a job, sending an email, and if any part fails it'll be undone no harm no foul. It's the mental model you might expect with `transaction`, but it's wrong in several dangerous ways.

Just because a transaction and a block share a Ruby construct does not mean they are the same, and failing to understand the underlying database behavior will cause surprises. A transaction is a database-side construct that covers SQL statements within a single connection, whereas the Ruby block covers whatever you typed in it. As you'll see in the rest of this article there are a lot of failures that can hide in the gap between those two, and it's wider than you might think.

We're going to walk through six specific examples with sample code and tests, and most importantly how to find and eliminate them in a production codebase.

## What the Transaction Covers

Let's step through what happens inside that `Order.transaction` block. ActiveRecord is going to start by checking out a connection, sending `BEGIN`, running the block, and sending `COMMIT` if the block finishes or `ROLLBACK` if it raises. It encompasses the SQL statements that occur between that `BEGIN` and `COMMIT`, but nothing else.

There are three properties doing a lot of structural work here:

**One**: The transaction is per connection, not per model. Calling `Order.transaction` will not scope anything to `Order`, it will apply to any model that participates during the _same connection_. The documentation's own example saves a `balance` record inside of an `Account.transaction` block ([Rails: `ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html)). It's useful, but keep in mind that _same connection_ point, because it's going to come up later as a failure mode.

**Two**: Isolation is defined by the session, which can vary between different types of databases. InnoDB defaults to `REPEATABLE READ` ([MySQL: Transaction Isolation Levels](https://dev.mysql.com/doc/refman/en/innodb-transaction-isolation-levels.html)); PostgreSQL defaults to `READ COMMITTED` ([PostgreSQL: Client Connection Defaults](https://www.postgresql.org/docs/current/runtime-config-client.html)). That means the same Ruby may have different concurrency semantics, and you're not getting a warning from Rails about these differences. You can ask for a level explicitly with `transaction(isolation: :serializable)`, but only on the outermost transaction. Asking on a nested transaction raises `ActiveRecord::TransactionIsolationError` ([Rails: `DatabaseStatements#transaction`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction)).

**Three**: A transaction is not a lock, the same as a `lock` is not a database mutex. It makes writes atomic, but it does not stop a concurrent transaction from reading the same rows and potentially beating you to the commit. A check-then-act pattern inside of a transaction is a race condition unless you use a `FOR UPDATE` lock or explicitly raise the isolation level, which was mentioned in [the locking article](https://baweaver.com/writing/2026/06/05/rails-sharp-parts-lock-is-not-a-mutex/).

Past that? Well that's where the danger lies. It doesn't cover Ruby side effects nor does it span connections, databases, shards, or services. 

## Failure One: Side Effects Don't Roll Back

Everything that happens inside of that transaction block that is not explicitly SQL will _not_ roll back if the transaction fails. That means HTTP calls, job enqueues, cache writes, file writes, emails sent, or anything else you can do in Ruby will _not_ be undone because the database has no idea any of that happened.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "side_effect_escape", unwrap: true) %>

That `ROLLBACK` from `raise ActiveRecord::Rollback` will undo the `order.update!`, but the HTTP call to the `PaymentGateway` has already happened. Undoing that means sending another request, but it's not going to automatically happen for you, because again the database has no clue what in the world a `PaymentGateway` is.

A transaction is not a unit of work boundary, it's a hybrid mixture of a Ruby block scope and a database scope, and those side effects happen in pure Ruby.

### The Fix: `after_commit`

Move side effects to `after_commit` callbacks or `current_transaction.after_commit` (Rails 7.2+, originating from Evil Martians' [after_commit_everywhere](https://evilmartians.com/chronicles/rails-after_commit-everywhere) gem):

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "after_commit_fix", unwrap: true) %>

We charge first because if something fails afterward, a charge with a stored `charge_id` is refundable. If we'd marked the order "paid" first and then failed to charge, the order says paid but no money moved.

If you prefer class-level callbacks over the inline form:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "after_commit_model_callback") %>

The callback fires only after `COMMIT` succeeds. If the transaction rolls back, it never runs. For job enqueues specifically, Rails 8.2 makes `enqueue_after_transaction_commit` the default ([Rails API: `ActiveJob::Enqueuing`](https://api.rubyonrails.org/v8.1/classes/ActiveJob/Enqueuing.html)): jobs enqueued inside a transaction are automatically deferred until commit and dropped on rollback. If a job needs to enqueue immediately regardless of the surrounding transaction, the per-job opt-out is `self.enqueue_after_transaction_commit = false`. This is Rails papering over a known failure case with more implicit magic, which creates categorically more confusing edges you're likely to hit when behavior changes between versions.

To be fair `after_commit` has its own failure window, as I mentioned in a previous article. It runs _after_ the lock releases, so other transactions can see and modify the row before your callback executes. If the process is killed between `COMMIT` and the callback firing, the side effect is lost entirely while the data remains durable. Karol Galanciak documents this in [The Inherent Unreliability of after_commit Callbacks](https://karolgalanciak.com/blog/2022/11/12/the-inherent-unreliability-of-after_commit-callback-and-most-service-objects-implementation/). For critical effects (payments, webhooks, audit trails), an outbox row committed alongside the business write is a much more durable alternative.

The longer-term fix is pulling effects out of model callbacks entirely and into explicit command objects that state their ordering explicitly, which is [the argument from the callbacks article](https://baweaver.com/writing/2026/06/13/rails-sharp-parts-callbacks-are-not-invariants/). The larger an application becomes the more you stand to gain by removing implicit knowledge and magic in favor of very explicit and clear interfaces which make accidental failures harder.

> **Aside**: There are contingents which would argue it is up to you to know the framework well. I disagree. An organization of any meaningful size will have hundreds of engineers at varying levels of framework knowledge, and the ones who write the next production incident are likely not the ones reading this article. Relying on universal expertise is not a strategy, it's a prayer. The systems thinker asks what happens when the next new hire, the contractor under a tight deadline, or the senior engineer who's never written a line of Ruby before encounters this trap. The answer is they walk straight into it, and your customers pay that price. Guardrails, linters, runtime detection, and explicit APIs exist to make correctness the path of least resistance rather than a reward for memorizing documentation. Anything less is leaving your production stability up to the weakest link in a chain you do not control, which is a fundamentally irresponsible proposition at scale.

## Failure Two: Unnecessary Work Extends Lock Lifetime

Transactions should be tight and focused, doing a limited set of work. Failing to do so will lead to our next failure case:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "broad_transaction", unwrap: true) %>

The writes in this transaction take row locks that persist until the final `COMMIT`. The reads and computation don't take locks themselves, but they extend the transaction's duration, meaning actions that do not require the database can block all other requests.

While the duration problem is bad, there are other cascading failures which emerge from this. On MySQL, a long-running transaction prevents InnoDB from cleaning up old row versions. Every other query touching those rows has to scan through increasingly stale history to find the current data, and the longer your transaction sits open the slower _everyone else_ gets. Percona documents cases where a single idle transaction degraded SELECT performance across the entire database until a restart ([Percona: Chasing a Hung MySQL Transaction](https://www.percona.com/blog/chasing-a-hung-transaction-in-mysql-innodb-history-length-strikes-back/)). On PostgreSQL the equivalent is vacuum blocking: a long transaction prevents dead row cleanup, and the table bloats until the transaction closes.

Both databases also take up a pooled connection for the entire duration of the block. Rails maintains a limited pool of database connections (typically 5-20 depending on configuration), and each open transaction holds one of those connections exclusively until it commits or rolls back. If your transaction is waiting on a report to compute, that's one fewer connection available for every other request in the application. Under enough load, the pool empties and new requests start queuing with `ActiveRecord::ConnectionTimeoutError` even though the database itself is idle.

There's also a more subtle cost in that long transactions can block database migrations. Migrations run DDL (Data Definition Language) statements like `CREATE TABLE`, `ALTER TABLE`, and `ADD INDEX`, and those statements need exclusive locks that can't be acquired while your transaction holds its own locks on the same tables. Your deploy sits there waiting for your transaction to finish ([GitLab: Merge Request Performance Guidelines](https://docs.gitlab.com/development/merge_request_concepts/performance/)).

The same applies to external HTTP calls, except you don't control how long they take:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "connection_held", unwrap: true) %>

If `PaymentGateway.charge!` takes 2 seconds, you've held a connection for 2 seconds doing zero database work. If it times out at 30 seconds, you've held the connection and its locks for 30 seconds. Retry logic inside the transaction makes this multiplicative: three retries with a 30-second timeout is 90 seconds of lock hold time on a single row, blocking every other request that touches it. [GitLab's transaction guidelines](https://docs.gitlab.com/development/database/transaction_guidelines/) put it plainly: "Ideally, a transaction should only contain database statements." Their avoid-list is Sidekiq jobs, emails, HTTP API calls, database statements on a different connection, file system operations, heavy computation, and `sleep`.

### The Fix: Narrow the Transaction, Retry Outside It

Do your reads before opening a transaction, compute outside of it, and wrap only the writes:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "broad_transaction_fix", unwrap: true) %>

If you need retry logic, wrap the transaction rather than putting retries inside it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "retry_outside_fix", unwrap: true) %>

Each attempt gets its own short transaction. If the external call fails, the lock is already released and the retry starts fresh.

We've traded one giant atomic unit for many smaller ones, meaning a mid-way crash leaves some orders settled and some not. That has the consequence of requiring our jobs to be idempotent, that is, safe to re-run. The benefit we derive from that trade is that each transaction lock takes milliseconds, rather than waiting for the larger unit of work to complete.

At scale that's a good trade to make, and it's a lesson that Erlang learned decades ago: Design for failure and recovery, rather than trying to prevent failure entirely ([Armstrong: Making Reliable Distributed Systems in the Presence of Software Errors](https://erlang.org/download/armstrong_thesis_2003.pdf)). A job that can crash and resume from where it left off is more durable than one that tries to move the world around it, because retrying that type of job is an on-call nightmare waiting to happen.

> **Aside**: It's a good idea in general to assume things can and will fail, especially external systems, and design fault tolerance around that. You'll save yourself hundreds if not thousands of on-call hours collectively by doing so.

## Failure Three: Nested Rollbacks Get Swallowed

If you nest `transaction` blocks you might expect them to cascade, but in reality they're _not_ true nested transactions. They join the parent transaction by default, and the outermost block is what controls the commits and rollbacks, leading to this failure mode:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "nested_rollback_swallowed", unwrap: true) %>

Without `requires_new`, the inner `transaction` call is a no-op that joins the outer one. `ActiveRecord::Rollback` is special-cased to be rescued without re-raising, so the outer transaction _never sees it_ meaning both writes commit. Tobias Pfeiffer documented this exact case in [Surprises with Nested Transactions, Rollbacks and ActiveRecord](https://pragtob.wordpress.com/2017/12/12/surprises-with-nested-transactions-rollbacks-and-activerecord/), and it remains one of the most common sources of confusion in the framework.

This problem gets worse when you remember that Rails implicitly creates transactions around every `save`, `destroy`, and its callback chains ([Rails: `ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html)). If your explicit `transaction` block calls a method that internally calls `save` on another model? You're nesting transactions which means the swallowed-rollback trap shows up in code that doesn't _look_ nested.

### Savepoints via `requires_new: true`

Passing `requires_new: true` creates a savepoint, which is a bookmark inside the transaction that the database can rewind to without rolling back everything before it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "nested_requires_new", unwrap: true) %>

This is the behavior most people expect from nested blocks, but it requires an explicit opt-in. Any exception other than `ActiveRecord::Rollback` will still bubble up and roll back the entire outer transaction, so domain errors in the inner block need an explicit rescue.

What `requires_new` emits on the wire depends on whether the outer transaction has written yet:

```text
-- Outer has written: savepoint
BEGIN
INSERT INTO orders (total_cents) VALUES (100)
SAVEPOINT active_record_1
INSERT INTO orders (total_cents) VALUES (3000)
RELEASE SAVEPOINT active_record_1
COMMIT

-- Outer is clean: Rails 7.1+ restarts the transaction instead
BEGIN
INSERT INTO orders (total_cents) VALUES (2000)
ROLLBACK AND CHAIN
INSERT INTO orders (total_cents) VALUES (9000)
COMMIT
```

The writes inside a savepoint only land when the outer `COMMIT` fires, and locks acquired inside the savepoint are held until that outer `COMMIT` too. The `ROLLBACK AND CHAIN` optimization is documented in [rails/rails#44526](https://github.com/rails/rails/pull/44526).

### MySQL and PostgreSQL Caveats

On MySQL, DDL (Data Definition Language) statements like `CREATE TABLE`, `ALTER TABLE`, and `TRUNCATE` implicitly commit the current transaction and discard all savepoints. If a `TRUNCATE` runs inside a `requires_new` block, MySQL releases the savepoint out from under Rails. When the block finishes and Rails tries to `RELEASE SAVEPOINT`, it gets a database error because the savepoint no longer exists. `TRUNCATE` is easy to forget here because it feels like a data operation, but in MySQL it's DDL ([Rails: Caveats](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Caveats)).

On PostgreSQL, a database error inside a transaction poisons the entire transaction. Every subsequent statement fails with "current transaction is aborted, commands ignored until end of transaction block" until you issue a full `ROLLBACK`. Rescuing `ActiveRecord::StatementInvalid` inside the block and continuing will appear to work on MySQL but explode on PostgreSQL ([Rails: Exception Handling](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Exception+handling+and+rolling+back)). Evil Martians wrote up [the production version](https://evilmartians.com/chronicles/the-silence-of-the-ruby-exceptions-a-rails-postgresql-database-transaction-thriller) in detail.

### The Fix: Flatten, or Use `requires_new` With Rescue

If you need a sub-operation that can fail without taking out the outer transaction, wrap it in `requires_new: true` and rescue the error explicitly:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "nested_fix", unwrap: true) %>

Or better yet don't nest `transaction` blocks at all and flatten the logic. If you can't flatten it, extract a service object that owns its own transaction boundary.

## Failure Four: A Single Write Doesn't Need a Wrapper

Sometimes you don't even need a transaction:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "wrapper_guards_nothing", unwrap: true) %>

A single `update!` already wraps itself and its callbacks in a transaction ([Rails: `ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html)), and a single SQL statement is atomic on its own. Adding another transaction around it only adds indirection, and leads us right back to Failure Three.

### The Fix: Delete It

Does a transaction group two or more statements whose partial successes are unacceptable within a single connection? Great, add a transaction. If not, delete it.

## Failure Five: Non-Local Exits Commit the Transaction

Using `return`, `break`, or `throw` inside a transaction block has meant different things across different Rails versions:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "return_inside", unwrap: true) %>

What happens with the `return`? Through Rails 6.0, it committed the transaction. Rails 6.1 deprecated it because `Timeout.timeout` used Ruby's `throw` internally (a control flow mechanism similar to `return` that exits a block from the outside), which was committing half-finished transactions when a timeout fired. Rails 7.0 made `return`, `break`, and `throw` roll back instead. Then the `timeout` gem (0.4.0) switched to raising an exception instead of using `throw`, and Rails 7.1 restored the original commit behavior.

On Rails 8, `return` inside a transaction block **commits**. The transaction completes with whatever writes happened before the `return`. In the example above, the order gets status "paid" with no ledger entry. The `return` looked like an early abort but acted as a partial commit.

This is common enough that RuboCop (a popular Ruby linter) ships `Rails/TransactionExitStatement` to flag it on the affected versions ([rubocop-rails docs](https://www.rubydoc.info/gems/rubocop-rails/RuboCop/Cop/Rails/TransactionExitStatement)). On Rails 8 the cop stops flagging because the behavior is defined (commit), but "defined" and "intentional" are different things. A `return` committing a partial write is rarely what the author meant.

The exact same five lines of code mean something _dramatically_ different across different versions of Rails without the developer changing anything. Some will commit without warning, some rollback, and then all of a sudden they commit again all depending on what Rails version you're on. When a framework solves problems by altering the implicit semantics of existing syntax rather than introducing new explicit API, it teaches engineers that they cannot trust what their code means by reading it. You end up needing a version-specific mental model to predict behavior, which is the opposite of readable software.

### The Fix: Don't Use `return` Inside Transaction Blocks

Use conditional logic instead:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "return_fix_conditional", unwrap: true) %>

Or better yet extract the decision outside:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "return_fix_extract", unwrap: true) %>

## Failure Six: Transactions Cannot Span Connections

If your application uses multiple databases (a separate database for a different part of the business, or multiple copies of the same database split by region or customer), a single `transaction` block cannot coordinate writes across them:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "cross_connection", unwrap: true) %>

If `Order` and `WarehouseItem` use different database connections (configured via `connects_to` in Rails), this does _not_ give you a cross-database transaction. Each connection has its own transaction. If the warehouse write fails after the order write succeeds, you get a committed order with no inventory deduction. The transaction only applies to `Order`, not `WarehouseItem`.

GitLab's guidelines are explicit about this: statements against a different database connection inside your transaction block "are not part of the transaction and are not rolled back in case something goes wrong. They act as third-party calls" ([GitLab: Transaction Guidelines](https://docs.gitlab.com/development/database/transaction_guidelines/)).

There is no mechanism in Active Record that coordinates commits across connections. Writing to two databases inside the same `transaction` block means each connection commits independently. A crash between the two leaves you inconsistent with no recovery path, because the framework has no coordination protocol between them.

### The Fix: Eventual Consistency or Sagas

For cross-database operations, you need to acknowledge that the two writes will _not_ be atomic, and handle that inconsistency explicitly.

An _outbox pattern_ writes a message row in the same transaction as your business data. The message commits or rolls back with the write, guaranteeing they're in sync. A separate process reads the outbox and delivers the messages afterward.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "outbox_pattern", unwrap: true) %>

A _saga_ is a sequence of independent transactions where each step knows how to undo itself if a later step fails. If the payment goes through but inventory reservation fails, the payment step issues a refund. Each step is its own transaction on its own database or service, and the undo logic is explicit rather than relying on a `ROLLBACK` that can't reach across connections.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "saga_pattern", unwrap: true) %>

Neither of those are pretty, and they bring coordination problems that only exist once you split your data across databases. It's part of why breaking things into services isn't nearly as easy as it sounds. Pat Helland's [Life Beyond Distributed Transactions](https://queue.acm.org/detail.cfm?id=3025012) covers why transparent multi-database atomicity is impractical at scale: the coordination overhead, the failure modes when participants disagree, and the latency costs outweigh the convenience, and the industry moved toward these explicit-failure patterns instead.

## Finding These in Your App

Knowing about these failures is one thing. Finding the ones already living in your codebase is another, and I guarantee you have a few if you've been around Rails long enough.

Start with what's happening right now. On MySQL you can query `information_schema.innodb_trx` to see every open transaction, how long it's been running, and how many rows it's locking:

```sql
SELECT trx_id, trx_state, trx_started,
       TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_seconds,
       trx_rows_locked, trx_mysql_thread_id
FROM information_schema.innodb_trx
WHERE trx_started < NOW() - INTERVAL 5 SECOND
ORDER BY trx_started;
```

On PostgreSQL the telltale sign is `idle in transaction`. It means a session opened a transaction, ran some SQL, and then stopped issuing statements while keeping the transaction open. That's what happens when your code is inside a `transaction` block doing something slow like an HTTP call. The [rails-pg-extras](https://github.com/pawurb/rails-pg-extras) gem wraps this and other diagnostics into rake tasks (`rake pg_extras:long_running_queries`, `rake pg_extras:bloat`), or you can query `pg_stat_activity` directly:

```sql
SELECT pid, now() - xact_start AS txn_age, state, left(query, 80) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < now() - interval '5 seconds'
ORDER BY xact_start;
```

PostgreSQL considers this dangerous enough to ship `idle_in_transaction_session_timeout`, a setting that will kill sessions stuck in this state beyond a configured duration. If you turn on `query_log_tags` (a Rails feature that annotates every SQL statement with the controller, job, or source file that generated it) your query results come pre-annotated so you can trace them directly back to the offending code ([Rails: `ActiveRecord::QueryLogs`](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html)).

For catching these before they hit production, a custom RuboCop cop (a "cop" is a single rule) can flag side effects inside transaction blocks during code review:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-transaction/illustrations.rb", segment: "rubocop_cop") %>

If you want runtime enforcement, [palkan/isolator](https://github.com/palkan/isolator) instruments Active Record transactions and raises the moment foreign work happens inside one. It'll catch HTTP calls, Sidekiq enqueues, mailer deliveries, and it works on the implicit transactions from callbacks too. Run it raising in test, logging on staging, and you'll find things you didn't know were there.

At the database layer you can set guardrails that prevent any single transaction from doing too much damage regardless of what the application code does. MySQL's `innodb_lock_wait_timeout` controls how long a blocked transaction waits for a lock before giving up. PostgreSQL's `statement_timeout` caps query execution time, and `idle_in_transaction_session_timeout` kills sessions that sit open without issuing statements. The `innodb_trx` query above returns `trx_mysql_thread_id` so you can `KILL` the specific session that's been holding things up. These won't fix the root cause, but they prevent one bad transaction from cascading into a full outage while you track it down.

## How Other Ecosystems Handle This

I'm hard on Rails because I've spent over 15 years using it by now, so naturally I'm going to know about how _Rails_ handles (or fails to) these types of issues. What happens when we take a look at other languages? Do they have similar problems, or have they found ways to prevent these issues? As it turns out it's a mixed bag.

### Java/Spring

Spring in Java forces you to name the nesting behavior. When one `@Transactional` method calls another, you declare propagation: `REQUIRES_NEW` gets its own independent transaction, `NESTED` gets a savepoint, and `MANDATORY` refuses to run without an existing transaction. The framework won't guess for you, it can still make HTTP calls inside a transactional method (Spring doesn't prevent side effects), but at least the composition question has an explicit answer:

```java
@Transactional
public void processOrder(Order order) {
    order.setStatus("paid");
    orderRepository.save(order);
}
// Side effects in a separate, non-transactional method
```

### Elixir/Ecto

Ecto in Elixir makes the transaction a data structure you build before executing it. The default `Multi` operations must return Ecto operations, so side effects have to show up as explicit named `Multi.run` steps. You can still put an HTTP call in there, but it's visible in the pipeline as a deliberate choice:

```elixir
Multi.new()
|> Multi.update(:order, Order.changeset(order, %{status: "paid"}))
|> Multi.insert(:ledger, LedgerEntry.changeset(%{order_id: order.id, amount: total}))
|> Repo.transaction()
```

### Rust/Diesel

Diesel passes your transaction block a `&mut PgConnection` reference, and the block must return a `Result<T, E>`. The compiler enforces that the failure path exists in the type signature, so you can't forget to handle it. That said, the block body is arbitrary Rust and you can make HTTP calls, write files, or do anything else inside it with no complaint from the compiler. Diesel solves the rollback-path problem (you can't forget to handle failure) but does nothing about side effects inside the block, same as Rails:

```rust
conn.transaction(|conn| {
    diesel::update(orders.find(id))
        .set(status.eq("paid"))
        .execute(conn)?;
    Ok(())
})
```

### .NET/TransactionScope

.NET's `TransactionScope` is more implicit still. It provides an ambient transaction that automatically escalates to a distributed two-phase commit the moment a second database connection enlists ([Microsoft: Transaction Management Escalation](https://learn.microsoft.com/en-us/dotnet/framework/data/transactions/transaction-management-escalation)). The `using` block looks as innocent as Rails' `transaction do`, except it will promote your local transaction into a coordinated distributed transaction with all the overhead and failure modes that entails. Rails stops at one connection and leaves the other uncoordinated. TransactionScope coordinates both, but the coordination overhead (MSDTC, network round trips, blocking participants) made it a production liability that .NET teams spent years learning to avoid.

### The Takeaway

Every one of these has sharp edges. Spring doesn't prevent side effects inside `@Transactional` methods. Ecto's `Multi.run` lets you put arbitrary side effects in there. Diesel doesn't constrain side effects at all. TransactionScope's implicit coordination was expensive enough that teams actively worked to prevent it from triggering. The spectrum runs from "declare everything explicitly" (Spring propagation, Ecto's pipeline) to "we'll handle it implicitly" (TransactionScope). Rails sits in the middle: a flexible block that handles rollback for SQL and leaves everything else up to you.

The universal truth underneath all of them is that unless you know what the database is doing underneath the abstractions you _will_ end up getting surprised by each and every one of them eventually. As software engineers we have an obligation to understand our tools, but we should also have an expectation that _most_ people _won't_ and design against those cases as much as we can by making the correct choices easy. That's harder than one might think, but investing early and often in golden paths pays off in the long run.

## Quick Reference

For anyone who skips straight to the end, here's the decision table from the opening example:

| Line of code | Inside transaction? | Why |
|---|---|---|
| `order.update!(status: "paid")` | ✅ Yes | Database write, needs atomicity |
| `LedgerEntry.create!(...)` | ✅ Yes | Database write, must be atomic with order |
| `PaymentGateway.charge!(order)` | ❌ No | HTTP side effect, not rollback-safe |
| `FulfillmentJob.perform_async(...)` | ❌ No | Side effect, use `after_commit` |
| `ReceiptMailer.receipt(...).deliver_later` | ❌ No | Side effect, use `after_commit` |
| `order.lock!` | ✅ Yes | Lock only meaningful inside transaction |
| `AuditLog.create!(...)` | ✅ Maybe | If it must be atomic with the write, yes |
| `Rails.cache.write(...)` | ❌ No | Not rollback-safe, use `after_commit` |
| `Webhook.notify!(...)` | ❌ No | HTTP side effect |

If `ROLLBACK` can't undo it, it doesn't belong inside the block.

## Further Reading

- [Rails API: `ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/Transactions/ClassMethods.html), the primary documentation, including the nested transaction behavior
- [Rails API: `DatabaseStatements#transaction`](https://api.rubyonrails.org/v8.1/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction), connection-level transaction method with isolation options
- [Evil Martians: The Silence of the Ruby Exceptions](https://evilmartians.com/chronicles/the-silence-of-the-ruby-exceptions-a-rails-postgresql-database-transaction-thriller), a production thriller on rescuing errors inside PostgreSQL transactions and why it poisons the entire transaction
- [Evil Martians: Rails' after_commit Everywhere](https://evilmartians.com/chronicles/rails-after_commit-everywhere), the gem and rationale for using transactional callbacks outside model classes
- [Karol Galanciak: The Inherent Unreliability of after_commit Callbacks](https://karolgalanciak.com/blog/2022/11/12/the-inherent-unreliability-of-after_commit-callback-and-most-service-objects-implementation/), on the gap between commit and side-effect execution that most service objects ignore
- [Tobias Pfeiffer: Surprises with Nested Transactions](https://pragtob.wordpress.com/2017/12/12/surprises-with-nested-transactions-rollbacks-and-activerecord/), independent documentation of the fused-nesting surprise
- [GitLab: Transaction Guidelines](https://docs.gitlab.com/development/database/transaction_guidelines/), operational rules from a team running one of the largest Rails-adjacent codebases
- [palkan/isolator](https://github.com/palkan/isolator), runtime detection of non-atomic interactions (HTTP, job enqueues, cache writes) inside database transactions
- [Rails 8.2: `enqueue_after_transaction_commit`](https://codewithrails.com/blog/rails-enqueue-after-transaction-commit/), how Rails 8.2 makes job deferral the default rather than opt-in
- [Pat Helland: Life Beyond Distributed Transactions](https://queue.acm.org/detail.cfm?id=3025012), the seminal paper on why distributed transactions are impractical at scale and what to do instead
- [Jimmy Bogard: Life Beyond Distributed Transactions (Implementation)](https://www.jimmybogard.com/life-beyond-distributed-transactions-sagas/), practical saga implementation built on Helland's paper
- [Microsoft: Transaction Management Escalation](https://learn.microsoft.com/en-us/dotnet/framework/data/transactions/transaction-management-escalation), how .NET's TransactionScope promotes to distributed 2PC without warning when a second resource enlists
- [MySQL: START TRANSACTION](https://dev.mysql.com/doc/refman/en/commit.html), what `BEGIN`/`COMMIT`/`ROLLBACK` do at the wire level
- [PostgreSQL: Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html), the four levels and what each prevents
- [Ecto.Multi documentation](https://hexdocs.pm/ecto/Ecto.Multi.html), Elixir's "transaction as data structure" approach
- [microservices.io: Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html), pattern reference for the outbox approach described in Failure Six

## Wrapping Up

It is my strongly held opinion that while software engineers _should_ know their tools, frameworks, and languages, coverage will inevitably end up _wildly inconsistent_. The larger the company, the worse this becomes, to where assuming a unified basis of knowledge can actively be dangerous. Our frameworks and tools should reflect this fact by building guardrails, making failures obvious and easy to recover from, and making the correct thing the easy thing. That extends beyond transactions, but it is a frequent theme in Rails for me that the framework succeeds in 0 to 1 moments but begins to fail developers beyond that point as their companies and products grow.

You cannot change how `transaction` works, but you _can_ change how your codebase uses it. Linters that catch side effects at review time, runtime detection that raises in test, database-level timeouts that kill runaway sessions, and explicit patterns like outbox tables and `after_commit` hooks that make the ordering visible. Some of that should be the framework's job, and to be fair most frameworks haven't gotten it right either. Until they do, it's on us. The earlier you invest in making the wrong thing hard the less time you spend figuring out why production is on fire.

So much of making large Rails applications workable comes down to making the implicit explicit. Rails' greatest strength at small scale is that it hides decisions from you, which ironically becomes its greatest weakness at scale. Callbacks are hiding side effects from you, transactions are merging without you knowing, behaviors vary wildly between versions and databases, and every one is implicit knowledge that you either carry in your head or learn the hard way. The value of explicit code is that a stranger can read and understand it without memorizing a framework's edge cases, and the larger the company the more you're going to find a lot of folks you don't know changing code you can never possibly review all of.

Make the correct thing easy and clear, it's expensive, but it's worth it.
