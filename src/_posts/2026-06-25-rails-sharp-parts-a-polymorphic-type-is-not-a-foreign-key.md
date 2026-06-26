---
layout: "post"
title: "Rails: The Sharp Parts. A Polymorphic Type Is Not a Foreign Key"
date: "2026-06-25"
categories: []
tags: ["ruby", "rails", "activerecord", "architecture", "packwerk", "rails-sharp-parts"]
series: "rails-sharp-parts"
description: "Polymorphic associations store a relationship as a class name in a string with no foreign key. That has unintended consequences which may not be obvious, and this article covers five of them."
---

[Last time](https://baweaver.com/writing/2026/06/14/rails-sharp-parts-queries-read-models-and-batching/) we made a `T::Struct` the only thing allowed to cross a pack boundary: typed, inert, and reviewable in five seconds.

This article is about polymorphic associations, and sharp edges I've had to contend with, especially around delegators when trying a strangler fig refactoring pattern. I still have [an open Rails issue](https://github.com/rails/rails/issues/54799) on the delegator bug I need to find a way to land.

To not bury the lede, at scale my personal answer to polymorphic associations? Don't.

> **Note**: [GitLab bans them](https://docs.gitlab.com/development/database/polymorphic_associations/) in their developer docs, and Bill Karwin's [_SQL Antipatterns_](https://pragprog.com/titles/bksqla/sql-antipatterns-volume-1/) named them an antipattern back in 2010. This isn't a novel position.

The rest of this article is going to go into why I have that opinion, what sharp edges there are, and what you're trading when you use one.

> **Aside**: The patterns in this series come from my time working in large Rails monoliths (1M+ lines of code, 10+ years of history, hundreds to thousands of engineers). The failures below happen at any size, but in a small app they're fixable in an afternoon. At scale, with thirty teams writing to the same polymorphic table, you lose the ability to even find all the places that need fixing.

## Two Columns and No Constraint

Let's go back to our theater app, which has events, orders, and seats. Say that we wanted the ability to leave notes on all three. The textbook answer is one polymorphic `Note` that can belong to any of them.

We'd add one using `t.references :notable, polymorphic: true`, but note that it doesn't give you one column, it gives you two:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "schema_columns") %>

It also builds you a composite index, and the order of the columns in that index is going to matter:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "schema_index") %>

Now ask the database what foreign keys protect that table:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "schema_foreign_keys") %>

Nothing. `notable_id` references nothing the database can enforce, because it can't. A foreign key points at one table, and `notable_id` points at `events` or `orders` or `seats` depending on a string sitting in the `type` column right next to it.

## A Find Is Two Clauses

Now suppose we have three notes, one for each of the owning tables (events, orders, and seats.) Each table has its own ID sequence, so all three parent rows end up with `id` of `1`, and all three notes end up with `notable_id` of `1`:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "notes_share_id") %>

The only way to tell these notes apart is the `type` string, meaning it's load bearing. ActiveRecord will do this automatically for us:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "well_formed_find") %>

This works when the `type` and `id` are both present, but let's say we forgot the `type`, what happens? Well the query stops meaning "the notes for this event" and starts meaning one of three or more possible rows with an id of `1`.

## The Type Comes From Asking an Object Its Class

How does ActiveRecord know the type? In the case of an event where does `"Event"` come from? It's not from the column, ActiveRecord derives it when the query is built by looking at the value and asking what class it is. You can find the relevant code in [`PolymorphicArrayValue#klass`](https://github.com/rails/rails/blob/v8.0.2/activerecord/lib/active_record/relation/predicate_builder/polymorphic_array_value.rb):

```ruby
def klass(value)
  if value.is_a?(Base)
    value.class
  elsif value.is_a?(Relation)
    value.model
  end
end
```

If `klass(value)` returns `nil`, the type is `nil`, and the predicate builder emits a query _missing the `notable_type` clause entirely_. This happens for a value that isn't an `ActiveRecord::Base` or an `ActiveRecord::Relation`. That's not an issue, until it is.

## Failure One: The Delegator Drops the Type

When does this become an issue? Well let's say you're refactoring `Event` and using a delegator to override some methods while everything else passes through:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/setup.rb", segment: "event_proxy") %>

It's an easy way to override a few methods, but there's a problem here: a [`SimpleDelegator`](https://docs.ruby-lang.org/en/4.0/SimpleDelegator.html) doesn't forward `class`, `is_a?`, or `kind_of?`. Those answers come from the wrapper, not the wrapped object:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "proxy_identity") %>

`proxy.is_a?(ActiveRecord::Base)` is `false`, the same check [`PolymorphicArrayValue#klass`](https://github.com/rails/rails/blob/v8.0.2/activerecord/lib/active_record/relation/predicate_builder/polymorphic_array_value.rb) performs. Feed the proxy to the same `find` that worked a section ago and you'll find a surprising result:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "proxy_find") %>

The `type` clause is gone! And since all three notes share `notable_id`, the query for this one event's notes hands you every note in the table:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "proxy_leak") %>

That means you're getting back notes from three different parents when you asked for one.

What makes this especially pesky is that writes through the proxy work fine:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "proxy_writes_fine") %>

So our proxy creates notes as expected, counts them through the association, and passes every test that builds data through the owning record. The only thing which breaks is a `where(notable: proxy)`, which probably lives in a consumers pack in a query you never wrote in a reporting job you've never heard of.

The local stopgap is to unwrap before you query:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "fix_unwrap") %>

But stopgaps rely on people knowing they're necessary, and that's not a solution, that's at best a wish and a prayer.

There's also a performance cost here. The index was built on `["notable_type", "notable_id"]`, type first. A composite index can only be used from its [leading column inward](https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html). The well-formed query has both columns and uses that index:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/output.txt", segment: "explain_with_type_output", lang: "text") %>

The broken query has only `notable_id`, the second column, which will cause a table scan:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/output.txt", segment: "explain_without_type_output", lang: "text") %>

So the delegator costs you correctness _and_ the index in a single move.

## Failure Two: The Type Is Whatever the Request Says

What happens when the `notable_type` column comes from user input? A polymorphic association is often submitted as two params (a `_type` and an `_id`), and that string gets resolved back into a class via [`polymorphic_class_for`](https://github.com/rails/rails/blob/v8.0.2/activerecord/lib/active_record/inheritance.rb) which calls `.constantize` on whatever's stored in the column. Set it to something that isn't a class and Rails tries anyway:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "injected_type") %>

A value that _does_ resolve is worse. All our notes have `notable_id` of 1, so changing `notable_type` to `"Order"` makes Rails look up id 1 in the orders table instead:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "type_confusion") %>

You could even change the `type` on an existing note to repoint it at a different model entirely:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "repoint") %>

This requires `notable_type` to be permitted in strong params (or for the write to bypass them, which backfills and console sessions do). The constantize/NameError issue above fires regardless.

A `belongs_to` cannot be manipulated like this because the foreign key points at one table and the database checks it. With a polymorphic association there are no built-in guards here. Rails has no `belongs_to :notable, polymorphic: true, types: [...]` ([the `belongs_to` API](https://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html#method-i-belongs_to) accepts no `types` option).

## Failure Three: The Join You Can't Write

What if you need to filter or sort notes by a column on the parent record? You can find by a polymorphic association, but you [cannot join through one](https://api.rubyonrails.org/classes/ActiveRecord/EagerLoadPolymorphicError.html):

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "join_through_notable") %>

There's no single table to join to. `notable` is `events` or `orders` or `seats` depending on the row, and SQL needs the table named up front. Your fallback is `preload`, which fires a separate query per distinct type:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "preload_fanout") %>

## Failure Four: The Strings That Went Stale

What happens when you rename or namespace a model? The `notable_type` is written once, at insert time, and changing a class's name will not magically update them:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "stale_after_namespace") %>

Every note written before the change will still point to `"Event"` while the new ones point at `"Calendar::Event"`, and you won't know until someone tries to reference an old row.

Regular `belongs_to` associations aren't free from this either, you still need to update the table name (or set `self.table_name`) and potentially rename the foreign key column. But the stored data doesn't need a migration because it's an integer pointing at a row, not a string pointing at a class name.

## Failure Five: The Orphans Nothing Cleans Up

What happens when you delete the parent record? [`dependent: :destroy`](https://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html#module-ActiveRecord::Associations::ClassMethods-label-Delete+or+destroy+associations) handles this in the normal Rails path, so if you're going through the model the children get cleaned up.

The gap is when you bypass Rails: a raw `DELETE`, a bulk migration, or a concurrent request that deletes the parent between another request's read and write. With a foreign key the database rejects the orphan or cascades the delete regardless of how the row was removed ([`ON DELETE CASCADE`](https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html)). Without one, you're relying on every code path going through ActiveRecord callbacks:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "orphaned_note") %>

In practice this means periodic cleanup jobs to find notes whose `notable_id` points at nothing, because the database can't tell you.

## What To Reach For Instead

The problem with a shared polymorphic table is that it's _over_-centralization: several teams writing their identity into one table, making it impossible to extract any of them independently.

The simplest fix is the one [GitLab recommends](https://docs.gitlab.com/development/database/polymorphic_associations/): each parent gets its own child table with a foreign key. Events get `event_notes`, Orders get `order_notes`. Yes, it's duplication. The payoff is that each table has a foreign key the database enforces, and when Events becomes its own service the `event_notes` table goes with it because nobody else was writing to it.

For a small, fixed set of parents on one shared table, use an exclusive `belongs_to` with a `CHECK` constraint. One nullable foreign key per parent, and a `CHECK` that exactly one is populated:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "exclusive_notes_schema") %>

With this schema in place, the database enforces the rules for us. One parent is accepted, two or zero fail the CHECK, and a non-existent parent fails the foreign key:

<%= render Shared::CodeBlock.new(file: "rails-sharp-parts-polymorphic/polymorphic.rb", segment: "exclusive_belongs_to") %>

A word on [`delegated_type`](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html), since it will come up. It improves the Ruby ergonomics over a bare polymorphic `belongs_to`, but underneath it's the same `belongs_to ..., polymorphic: true` with a `*_type` string column and no foreign key. It does accept a `types:` list, which looks like the allowlist Failure Two said doesn't exist, but that list only generates scopes and predicate helpers (`message?`, `comment?`). It's never checked on assignment or write, so the column still accepts whatever string you put in it. Reach for `delegated_type` for ergonomics, not for safety.

If you need a unified feed across packs (all notes regardless of parent type), compose it at the read layer the way the [queries article](https://baweaver.com/writing/2026/06/14/rails-sharp-parts-queries-read-models-and-batching/) built the reservation view: each pack exposes a by-ids query, a coordinator assembles the feed.

## Further Reading

- [GitLab development docs: Polymorphic Associations](https://docs.gitlab.com/development/database/polymorphic_associations/) — GitLab bans them outright, recommending separate tables per type
- Bill Karwin, [_SQL Antipatterns_](https://pragprog.com/titles/bksqla/sql-antipatterns-volume-1/), Chapter 7 — the original naming of polymorphic associations as a database antipattern
- [Why can you not have a foreign key in a polymorphic association?](https://stackoverflow.com/a/922341) — Bill Karwin's StackOverflow explanation of the structural impossibility
- Felipe Vogel, [Reimplementing polymorphic associations in the database](https://fpsvogel.com/posts/2025/rails-polymorphic-associations-reimplemented-in-postgresql) — a 2025 PostgreSQL supertype-table approach
- The [open Rails issue](https://github.com/rails/rails/issues/54799) this article reproduces (type clause dropping through a `SimpleDelegator`)
- [`EagerLoadPolymorphicError`](https://github.com/rails/rails/issues/54981) firing on a join
- [Constant injection](https://github.com/rails/rails/issues/33101) and [type confusion](https://github.com/rails/rails/issues/8265) through a request-supplied `_type`
- [`PredicateBuilder::PolymorphicArrayValue`](https://github.com/rails/rails/blob/v8.0.2/activerecord/lib/active_record/relation/predicate_builder/polymorphic_array_value.rb) source
- [Ruby `Delegator` and `SimpleDelegator`](https://docs.ruby-lang.org/en/4.0/SimpleDelegator.html)
- [Rails `delegated_type`](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
- The [queries](https://baweaver.com/writing/2026/06/14/rails-sharp-parts-queries-read-models-and-batching/) and [index](https://baweaver.com/writing/2026/06/12/rails-sharp-parts-an-index-is-not-a-plan/) articles earlier in this series

## Wrapping Up

Rails makes polymorphic associations _easy_, and easy wins early. The cost shows up in five distinct ways: a delegator drops the type clause and ships wrong rows, user input steers the type wherever it likes, joins don't work, renames leave stored strings stale, and deleted parents leave orphans the database can't see.

A foreign key doesn't care what Ruby thinks an object's class is, it doesn't care what string someone put in a column, and it doesn't go stale when you rename things. It's a constraint the database checks on every write regardless of what code path got you there, and that's what makes the difference between a relationship you can trust and one you have to constantly audit.
