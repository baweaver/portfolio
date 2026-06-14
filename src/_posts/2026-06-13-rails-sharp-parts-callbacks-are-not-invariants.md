---
layout: "post"
title: "Rails: The Sharp Parts. Callbacks Are Not Invariants"
date: "2026-06-13"
categories: []
tags: ["ruby", "rails", "activerecord", "architecture", "packwerk", "rails-sharp-parts"]
series: "rails-sharp-parts"
description: "Callbacks promise that something always happens when a record changes. They can't keep that promise, and Rails documents the ways out. Every failure mode here ran against ActiveRecord 8.1 before it went in, and the replacement is a command with one door."
---

[Last time](https://baweaver.com/writing/2026/06/12/rails-sharp-parts-an-index-is-not-a-plan/) we pulled apart indexes and found that `add_index` writes the suggestion, not the plan, and confusing the two leads to production surprises. Buried in the article before that, on locks, was an aside:

> Single-ingress writes are worth their weight in gold... They eliminate callbacks, allow for easier instrumentation, clearer optimization paths, and much easier debugging.

That's a bold assertion, but for me a very warranted one: model callbacks with domain behavior should be removed, and replaced with explicit objects that have _exactly one_ ingress.

Why do I have that opinion? Of all the sharp parts in Rails, callbacks have led to the most entanglement of otherwise unrelated code in surprising ways that _frequently_ cause outages at scale. Magic has a cost, and while it feels good to write in the moment and _seems_ clear, that cost _will_ come due whether weeks, months, or even years later.

## The Same Model, Two Directions

Consider two scenarios on the same model.

**Example one** starts with a backfill task:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "backfill_example", unwrap: true) %>

The model had an `after_commit` that synced any changed order to the CRM, so forty thousand orders re-synced, the webhook queue backed up for half an hour, and whatever unfortunate partners we're working with probably rate-limited us. Nobody wrote "sync to the CRM" in that backfill task; the model did, implicitly, whether or not we knew it.

**Example two.** A different engineer runs the same backfill with `update_all`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "backfill_update_all", unwrap: true) %>

It's reasonably fast and because of the `update_all` it's not going to trigger a sync storm like the last one, so we've avoided the callback cost here, right?

Well that same `Order` model was also maintaining an OpenSearch search index using a callback, and now thousands of orders are silently falling out of searches for the next few weeks until a customer asks why they can't find their orders.

Both examples made the same mistake, albeit from opposite directions. The first didn't consider what callbacks might run on an update, and the second didn't consider what callbacks _won't_ run if you skip them. In code review that shared belief sounds like "put it in a callback so it _always_ happens, no matter who writes the record." That sentence is wrong twice: it doesn't always happen, and you can't see when it does.

## What `save` Actually Runs

`save` reads like a verb, an atomic action, but it's a program. When you call it, ActiveRecord runs the compiled callback chain for `:save` (and `:create` or `:update`, and `:validation`, and later `:commit`) with your record threaded through every entry ([Rails: `ActiveRecord::Callbacks`](https://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html)). Your `before_save` blocks are entries in that chain, and so are entries you never wrote and may not even know about, because association macros register callbacks too.

Two models, zero user callbacks:

> **Note**: Code samples in this article run against a shared test schema. The `self.table_name` lines map models to those tables; in a real app these would be separate migrations.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "census_example") %>

That lone save entry is autosave, the feature where saving a record also saves any loaded associated records, and `belongs_to` registered it on your behalf. Two lines of associations and zero callbacks of your own still leave eleven registered, and a typical model adds five to ten more with domain behavior.

> **Aside**: run that same census on ActiveRecord 7.2 and you get 6 and 8. The framework's own contribution to your chain changes across upgrades, which means the program behind `save` shifts under you even when your model's file doesn't.

A callback is control flow attached to persistence that the call site can't see, written by an author who can't see the call sites: two blind spots pointed at each other, and everything below is a consequence of that.

## Failure One: The Paths That Skip the Chain

So how does the assumption break? The assumption developers carry is "always happens." **Rails never said that**, and the API surface shows exactly where it doesn't:

| Method | Callbacks | Validations |
| --- | --- | --- |
| `save` / `save!` / `update` / `update!` | yes | yes |
| `destroy` / `destroy!` | yes | **no** (destroy never validates) |
| `save(validate: false)` | yes | **no** |
| `update_attribute` | yes | **no** |
| `touch` | `after_touch` / `after_commit` only | **no** |
| `update_column` / `update_columns` | **no** | **no** |
| `update_all` / `delete` / `delete_all` | **no** | **no** |
| `insert_all` / `upsert_all` / `touch_all` | **no** | **no** |

It's [documented behavior](https://guides.rubyonrails.org/active_record_callbacks.html#skipping-callbacks), and the skip methods exist _because_ callbacks exist: they're the pressure-release valve Rails ships for when the chain is too slow, too loud, or too dangerous to run. Your coworkers use them, Rails uses them internally, and the Example Two engineer used one on purpose.

The unassuming `update_attribute` (singular) runs the callbacks but skips validations:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "update_attribute_demo") %>

Now we have the forbidden value in the database despite the exclusion validation and every callback having fired.

The next are the bulk operations that not only _skip_ callbacks, but _all_ callbacks. That includes things like `counter_cache`, which if a delete or insert action hits is going to be _real_ confusing for a while:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "counter_cache_example", unwrap: true) %>

That means you now have a counter cache that is <%= claim("counter cache isn't healed on next update", "_irreconcilable_") %>. If you want another fun one that means that things like PaperTrail are also broken, meaning your audit logs are going to be missing some pretty significant events.

In the index article I said constraints are preferred because they're enforced on every write path, and this is the other half of that argument: a unique index has no `insert_all`-shaped hole in it, and a callback is an invariant with a published bypass list, which is a convention with good marketing. That's the half where callbacks silently _don't_ run. The next failure is worse: callbacks that silently _do_.

## Failure Two: Firing When Nobody Asked

Failure One was about callbacks that don't fire when you expect them to. This failure is the opposite: callbacks that fire when nobody asked them to, taking locks on rows you never touched:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "touch_models_display") %>

Creating a seat fires in this order:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/output.txt", segment: "touch_trace_output", lang: "text") %>

The `Event` row was written, and its row lock taken, inside a transaction the `Event` author never sees and the `Seat` caller never asked about. That's `touch: true` doing its job (bumping `updated_at` so view caches expire), but the side effect is a hidden write to a parent row on every child save.

When we have hidden writes that means we also have hidden locks to go with them. The trace appends a write to `events` at the end of _every_ seat save, meaning every seat locks its parent event. That means that anything that updates an event and then its seats acquires an event-to-seat lock, and under any load? Well there's a fun deadlock to debug. You can't order the execution of locks you can't see, and callbacks make them effectively invisible.

The chain also fires on reads. `after_find` fires once per row loaded and `after_initialize` fires on every instantiation, so a default assigned there (`self.priority = true`) marks a freshly loaded record dirty: `changed?` returns true, and any code holding a polite `save if changed?` starts writing during what should be a read.

The folk fix for accidental re-entry and cycles is `update_column` _inside_ the callback to break the chain, which works by skipping the rest of it. The cure for Failure Two is a fresh case of Failure One.

## Failure Three: Validations Are Callbacks Too

Validations read like declarations, but they execute as entries in the same chain (the census counted a `:validation` kind for a reason), they run on every `save`, every `create`, and every call to `valid?`, and `before_validation` gets to rewrite what they see which means more hidden side-effects.

When a validation is put early in a class, and a `before_save` runs afterwards, it means they execute _in that order_ making a path for invalid values to sneak through:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "mutation_past_validation") %>

Validations _do not_ guard writes, they guard a moment before several other callbacks run before the write, with no way to control it.

Beyond ordering, validations have a query cost. A uniqueness validation is a `SELECT` asking "does this exist yet" before every `INSERT`, and a transitive validation (one that reads _other_ records to validate this one) is another query on top:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "validation_query_fanout") %>

Running fifty creates through that model against fifty through a bare one, with a subscriber counting every statement:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/output.txt", segment: "validation_fanout_output", lang: "text") %>

That means two extra reads per row on your hottest table. Scale that to fifty thousand rows and you're paying a hundred thousand extra `SELECT`s, and the capacity `COUNT` scans more rows for every successful insert.

But there's one more surprise: uniqueness checks are vulnerable to race conditions. Two concurrent `SELECT`s run into each other so they _both_ `INSERT` which the [Rails guides say outright](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) when they tell you to back the validation with a unique index. The validation produces the friendly error message, the index enforces the rule. And all of this runs at a specific point in the transaction lifecycle, which brings us to the next failure.

## Failure Four: The Transaction Cuts the Chain in Half

The previous failures were about _which_ callbacks fire. This one is about _when_. Every callback lives on one side or the other of `COMMIT`, and each side breaks differently:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "transaction_open_demo") %>

`after_save` runs inside the transaction, so anything you do there which the database can't undo won't be undone:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "after_save_email_demo") %>

The email went out, `after_commit` never fired, and the seat doesn't exist. Your customer is now confirmed for a reservation the database has no record of. The callback didn't lie, exactly: it ran when the _Ruby_ succeeded, and nobody told it the _write_ didn't.

Being inside the transaction also means IO in a callback holds your row locks open for the duration of that IO. The geocoder gem suggests `after_validation :geocode`, which turns every save into an HTTP call mid-transaction. It also led to one of the [oldest job-queue bugs in Rails](https://github.com/sidekiq/sidekiq/wiki/FAQ): enqueue from `after_save`, and a fast worker looks up the row before your `COMMIT` lands.

"Fine, `after_commit` for everything." Is it? Now you're holding the other set of edges.

It fires at the _outermost_ commit, once, no matter how nested you are. It coalesces: `create` and `update` in one transaction fires only `after_create_commit`, and the update's observers never hear about it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "lifecycle_coalescing_demo") %>

It can't object to anything (the data is already committed), and for most of Rails history multiple `after_commit` callbacks ran in _reverse_ declaration order, a behavior that only flipped when you opted into the 7.1 framework defaults.

One good primitive came out of this: since Rails 7.2, `ActiveRecord.after_all_transactions_commit { ... }` lets _any_ code defer work until the real outermost commit ([7.2 release notes](https://guides.rubyonrails.org/7_2_release_notes.html)), and it's the piece the fix below is built on.

## Failure Five: The Chain Is a State Machine Nobody Wrote Down

None of the above is fatal at one callback, and nobody has one callback. Here's a model that looks reasonable until you count the paths through it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "composite_order_model") %>

Conditionals present a real headache: there are two paths for every condition, and with four that means sixteen different paths a single `save` could result in depending on what attributes changed. The `after_commit` conditions specifically (`saved_change_to_status?`) evaluate against `ActiveModel::Dirty` state that reflects the coalesced view of the transaction, not the individual save, which means intermediate transitions are invisible to them. The execution order is also in declaration order, or rather _file load_ order when `Concerns` are involved, and `prepend: true` is happy to cut in line. The framework forces that option in one documented spot: `dependent: :destroy` registers its own `before_destroy` the moment the association is declared, so a guard written below it runs after the children are gone:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "destroy_guard_display") %>

Add `prepend: true` and the same `destroy` aborts with the seat intact. We've inadvertently created an ad-hoc state machine, and any `before_` callback in it can silently veto the whole write:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "blocked_save_display") %>

The caller gets `false` back and probably doesn't check how it got there. You can see this in test suites full of `skip_callback` and stubbed mailers, because the chain is too expensive to run on every factory create. Commands don't have this problem, they test like any other class.

## What Gets to Stay

With all that said, not every callback needs to go. A callback that's a pure function of the record's own attributes, no IO, no clock, no other rows, no other processes, can't race, can't outlive a rollback incorrectly, and can't lock a parent row, and skipping it via `update_column` produces a formatting bug rather than a consistency hole. Downcasing an email qualifies; so does deriving a slug. As of Rails 7.1 both can be done via `normalizes`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "normalizes_example") %>

([Rails: `ActiveRecord::Normalization`](https://api.rubyonrails.org/classes/ActiveRecord/Normalization.html))

The rule to verify this is by checking if a callback reads or writes anything beyond its own attributes.

## One Door In

A mutation should be visible, positioned relative to the commit, bulk-capable, and announce that it ran. `ActiveSupport::Notifications` gives us the announcement half, and a base class gives us the single door:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/setup.rb", segment: "application_command") %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "private_constructor_demo") %>

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "forgetful_demo") %>

When you later want logging, metrics, or tracing around every mutation in the app, they attach to the published events as subscribers. Here's what a real command looks like built on this base:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/setup.rb", segment: "reserve_seat_command", lang: "ruby") %>

`instrument` publishes on every invocation, including when the block raises, with the exception in the payload:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "instrumentation_output") %>

Even the writes that _didn't_ happen leave a trace.

One fair objection is that `announce` still isn't transactional. If the process dies between the commit and the mailer call, the side effect is lost. That's true, and at scale the answer is a [transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html) that writes the event _inside_ the transaction and delivers it asynchronously. For most apps the visibility alone (the side effect is in one file, not scattered across a chain) is the win; the outbox is there when you need guaranteed delivery.

Bulk gets the same shape with a different verb, condensed to its differences:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/setup.rb", segment: "import_seats_command", lang: "ruby") %>

One class per verb, one way in, and everything else that touches seats reads.

### Making It Enforced, Not Polite

The `packs/seats/app/public/` path in the comment above was deliberate. Packwerk splits a Rails app into packs, folders with declared dependency boundaries enforced at CI, and treats each pack's `app/public` directory as that pack's API: reference anything outside it from another pack and CI fails with a privacy violation. So commands are the API and the model isn't in it:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/output.txt", segment: "packwerk_tree", lang: "text") %>

Every write announces itself through the base's instrumentation, including refused ones:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "notification_subscriber") %>

Logging, metrics, and APM tracing attach as subscribers rather than edits to three hundred command files. This is event-driven architecture at the application level, and it trades one kind of coupling for another. Callbacks couple implicitly (the subscriber is invisible to the publisher and to static tools). Events couple explicitly (the subscriber is a constant reference Packwerk can check, and the event name is a grep-able string), but Pack B still reacts to Pack A's writes without Pack A knowing.

- You gain discoverability (subscribers are declared, not hidden in association macros)
- You gain replaceability (swap a subscriber without touching the publisher)
- You pay in indirection (following a notification to its subscriber takes a search, not a stack trace)
- You pay in ordering uncertainty (subscribers fire in registration order, which is load order)

For most apps the discoverability wins outright. If indirection becomes painful, the boundary is in the wrong place rather than the mechanism.

None of this holds without enforcement. A convention is only as strong as the mechanisms that guarantee it, and without guardrails standards become requests that get summarily ignored.

**One**: Packwerk privacy. The commands already live in `app/public`, so `enforce_privacy: true` makes the model unreachable from outside the pack. A direct `seat.update!` from another pack fails CI with a privacy violation before it merges ([Packwerk](https://github.com/Shopify/packwerk)).

**Two**: RuboCop, a linter, accepts custom rules called cops, and this pattern earns two of them. If you haven't written a cop before, [ASTs in Ruby: Pattern Matching](https://baweaver.com/writing/2022/06/14/asts-in-ruby-pattern-matching-mjd/) covers how to work with Ruby's syntax tree programmatically. The first cop: no mutations outside command files.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "write_outside_command_cop") %>

The second cop guarantees the one-entrant rule. A command defines a private `execute` method, and no public methods outside of the base `call`.

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "command_single_entrant_cop") %>

The first cop only flags calls on constants, ivars, and self, so `set.delete` passes through cleanly. The second misses `class << self` tricks. Both catch the common mistakes and a `rubocop:disable` handles the rest.

**Three**: database constraints under everything, because commands are still application code. Unique indexes, `CHECK`s, foreign keys, `NOT NULL`. When someone bypasses the commands anyway, and someone will, the constraint converts silent corruption into an exception.

What's left in the model after all this? Schema, associations, scopes, `normalizes`, and validations for caller convenience. The database holds the invariants, the commands hold the behavior.

## Strangling the Chain in an Existing App

The problem with these patterns is by the time you consider them your app has a lot of legacy to contend with, meaning this isn't a clean greenfield project we can change however we want. The name of the game in these scenarios is progressive enhancement, or from another vantage the strangler fig pattern: grow a replacement around the old system, hollow it out, and replace it over time ([Fowler, 2004](https://martinfowler.com/bliki/StranglerFigApplication.html)). The goal with large migrations on old codebases is to make them obvious, mechanical, isolatable, rollback-able (because you're going to need it), and progressive so a team currently underwater has time to adapt.

Start by making the invisible visible:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "census_strangler") %>

The top of that list is your starting point.

Take the callbacks from your worst models and divide them into three buckets: pure-self (keep, or convert to `normalizes`), cross-model writes (into a command, inside the transaction), and IO (into a command, below the transaction). From there build commands around the _current_ behavior first, copying the bodies inline in the same order the current chain runs. Avoid the instinct to refactor or improve, as a refactor and a behavior change in one PR is a regression waiting to happen.

Seriously: Minimal, surgical, copy-paste changes when doing this. That one-liner is not nearly as obvious or non-impacting as you think and it won't be worth it. Ask me how I know, I've learned that one the hard way more times than I'd care to admit.

From there route the call sites and turn the cop on for those files. Deletion only comes afterwards, with a safety net underneath it.

Thankfully routing is the safe part, because the command itself's `update!` is still going to fire those callbacks, resulting in no behavioral changes. Deletion, on the other hand, is more complicated and involves a deploy which are categorically not known to be fast in most applications. That's where feature flagging comes in, and there are several options here to help us make these cutovers more clean. [Flipper](https://github.com/flippercloud/flipper) is a common Ruby implementation, with gates for a single actor, a group, or a percentage of actors, and with it the legacy callback gets a guard and the command gets its mirror:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "flipper_cutover") %>

The guard and the command check the same flag on the same actor, so each order syncs exactly once regardless of which path it takes. If something goes wrong, `Flipper.disable(:orders_capture_via_command)` moves everyone back to the callback path instantly with no deploy.

The rollout itself is one line:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-callbacks-are-not-invariants/callbacks.rb", segment: "flipper_rollout_line", unwrap: true) %>

Walk the percentage up over a week, compare the outputs between cohorts, and once it's at a hundred for a while delete the callback, the guard, and the flag in one commit. One important ordering note: turn the cop on for a model's call sites _before_ enabling the flag, otherwise flag-on orders hitting un-routed paths skip both syncs.

A model with thirty callbacks won't convert in one pass. Carve it verb by verb, one flag per verb, and the census count ticks down with each extraction.

## Counting the Cost

None of this is free. A command is a class per verb where a callback was a line, and on a small app with one team it's ceremony. Callbacks are fine until the second write path or the second team shows up. The 37signals school will tell you disciplined callbacks scale further than I'm giving them credit for ([Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/), [Globals, Callbacks and Other Sacrileges](https://dev.37signals.com/globals-callbacks-and-other-sacrileges/)), and inside one cohesive team they're not wrong. The weakness of that position is that it assumes every developer has read the lore guide and understood the sharp parts. In a 15+ year old monolith with 500+ engineers across 30+ teams, with varying skill levels, language familiarity, incentives, and deadlines, guidance on a page doesn't hold. Enforcement that relies on developers reading docs is soft at best. We need mechanisms that make the wrong thing hard, not docs that ask nicely.

The pattern also requires enforcement to survive (that's what the cops and Packwerk are for), and it doesn't cover Rails' own callbacks. `counter_cache`, `touch`, autosave, and `dependent:` stay, those are framework bookkeeping. The rule applies to your domain behavior: emails, webhooks, ledger writes, cross-model consistency.

## So Where Does the Logic Go?

For quick reference, here's where each kind of callback behavior lands in the new world:

| The callback was doing | Put it |
| --- | --- |
| Normalizing the record's own attributes | `normalizes` (7.1+), or keep the pure `before_validation` |
| Defaulting a column | Database default, or the command |
| Maintaining a counter / timestamp | `counter_cache` / `touch` are fine; they're framework bookkeeping |
| Writing to another model | A command, inside the transaction |
| Email / job / webhook / HTTP | A command, after the transaction block |
| Search index / cache invalidation | A command, after the transaction block, with a bulk verb |
| Audit / version history | A command, or database-level capture; callback gems sample, they don't record |
| Reacting to another pack's write | Subscribe to its command's notification, or be called by it explicitly |
| Cross-record checks (uniqueness, capacity) | A unique index or `CHECK` for the truth; a guard in the command for the friendly error |
| Enforcing "this must always be true" | Database constraint, with commands as the only door |
| Vetoing a save (`throw :abort`) | A guard at the top of the command, where it raises something with a name |
| Cascade cleanup | Foreign key `ON DELETE`, or a command |

## Further Reading

- [Active Record Callbacks guide](https://guides.rubyonrails.org/active_record_callbacks.html), especially the skipping section
- [`ActiveRecord::Transactions::ClassMethods`](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html) for the `after_commit` caveats
- [`ActiveSupport::Notifications`](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) for the instrumentation backbone
- [Sidekiq FAQ](https://github.com/sidekiq/sidekiq/wiki/FAQ) on the enqueue-before-commit race
- [Rails 7.2 release notes](https://guides.rubyonrails.org/7_2_release_notes.html) for `after_all_transactions_commit`
- [Packwerk](https://github.com/Shopify/packwerk) and [Flipper](https://github.com/flippercloud/flipper) for enforcement and cutover
- [Media at Scale: Callbacks vs pipelines](https://shopify.engineering/media-at-scale-callbacks-vs-pipelines) (Shopify Engineering) for the same migration at Shopify's scale
- [ASTs in Ruby: Pattern Matching](https://baweaver.com/writing/2022/06/14/asts-in-ruby-pattern-matching-mjd/) for writing your own cops
- [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/) and [Globals, Callbacks and Other Sacrileges](https://dev.37signals.com/globals-callbacks-and-other-sacrileges/) for the steelman of the other side
- [Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html) (Fowler, 2004)

## Wrapping Up

Callbacks attach behavior to persistence in a place the caller can't see and the author can't control. The fix is to move that behavior into explicit commands with one door, enforce the boundary with tooling, and let the database hold the real invariants.

Next time we're going to name the pattern we just built half of: [CQRS](https://martinfowler.com/bliki/CQRS.html) (Command Query Responsibility Segregation), the idea that reads and writes should flow through separate interfaces. We don't need separate databases for that, just separate objects in the same app. Commands already own the writes; next we add `Queries` to own the reads, and ActiveRecord stops leaking out of packs entirely.
