---
layout: "post"
title: "Patching CRuby: String-Key Pattern Matching"
date: "2026-07-04"
categories: []
tags: ["ruby", "pattern-matching", "cruby", "performance"]
description: "Pattern matching breaks on String-keyed hashes. We prototyped five strategies as C extensions, hit the method-dispatch wall, then patched CRuby itself. Here's the investigation, the patch, and the numbers."
---

One of my greatest frustrations in Ruby has always been Symbols versus Strings when it comes to Hashes, a problem that compounds itself with one of my more favorite features in Ruby, pattern matching. Why is that a problem? Well if you try and parse some JSON and try and pattern match against it you'll find nothing is working like you might expect:

<%= render Shared::CodeBlock.new(file: "patching-cruby-string-key-pattern-matching/examples.rb", segment: "the_problem", unwrap: true) %>

For someone familiar with Ruby you'll spot the problem immediately, but for people coming from another language this can be a pitfall. Ruby will return `nil` here because the hash has `"name"` (a String) and the pattern is asking for `:name` (a Symbol), which are _not_ equivalent. Pattern matching only checks Symbol keys, a limitation that traces back to a parser conflict rather than a deliberate design choice (more on that in a moment). It's been listed as "future work" since Kazuki Tsujimoto's original RubyKaigi talk introducing the feature in 2019.

So what is one to do instead? Both `JSON.parse` and `CSV.parse` have built-in Symbol conversion flags (`symbolize_names: true` for JSON, `header_converters: :symbol` paired with `headers: true` for CSV), and if you control the parse site and remember to pass them those two cases are handled.

The trouble is everything you don't control the parse site for. Webhook payloads parsed with bare `Net::HTTP` + `JSON.parse` (where the caller didn't pass `symbolize_names`). Faraday responses parsed through JSON middleware (which yields String-keyed hashes). Rack env headers that arrive as `"HTTP_ACCEPT"` and `"CONTENT_TYPE"`. In all of these cases the workaround is a manual recursive walk:

<%= render Shared::CodeBlock.new(file: "patching-cruby-string-key-pattern-matching/examples.rb", segment: "workaround_symbolize") %>

You end up paying a massive tax on hash allocations at every nesting level just to ask a simple question, and even with conversion flags the burden lies on you to _remember to use them_ consistently. Personally I think the responsibility is in the wrong place, and the language itself needs to treat pattern matching keys not as Symbol keys, but as query parameters.

That's the case I made in [The Case for Pattern Matching Key Irreverence in Ruby](https://baweaver.com/writing/2022/06/11/the-case-for-pattern-matching-key-irreverence-in-ruby-1oll/) years ago, but back then the argument was philosophical at best. Today we're going to see what we can do to make that argument more concrete.

## Why This Happens

One argument you might consider is using hashrockets for String keys via `{ "key_name" => expected_value }`, but there's a problem that came along with pattern matching itself in Ruby 2.7: inside a pattern expression, `=>` means "capture this value into a variable":

```ruby
case data
in { name: String => captured_name }
  #                ^^^ pattern capture, NOT a hash rocket
end
```

Because `=>` is claimed by pattern capture within `case/in`, you can't write `{ "name" => pattern }` inside a pattern expression. This isn't a design decision about String keys being excluded from pattern matching, it's a parser conflict that cemented into a limitation. Tsujimoto listed "non-Symbol keys for hash patterns" as explicit future work, and Petr Chalupa noted in [#14912](https://bugs.ruby-lang.org/issues/14912) that this was always a known gap.

## What `deconstruct_keys` Actually Does

Before we dive into writing code, we must first start by reading, and hopefully understanding, code. We need to start with what Ruby is doing when it sees `hash in { key: pattern }`:

1. Check that the object responds to `deconstruct_keys`
2. Call `hash.deconstruct_keys([:key])` to get a hash back
3. Verify the return value passes `Hash ===` (this is why custom objects can be matched against as long as they return a Hash)
4. For each pattern key, call `key?` on the returned hash to check existence
5. For each existing key, call `[]` on the returned hash to get the value
6. Call `pattern === value` to check if the value matches

That `key?` step in the middle is easy to miss. The VM doesn't call `[]` and check for nil, it explicitly asks `key?` first. This means any approach that overrides `[]` but not `key?` won't work, and that both overrides need the `sym-to-str` fallback logic.

For a Symbol-keyed hash, `deconstruct_keys` does something surprising:

<%= render Shared::CodeBlock.new(file: "patching-cruby-string-key-pattern-matching/examples.rb", segment: "deconstruct_keys_returns_self", unwrap: true) %>

It returns _self_ without creating a new hash or copying anything. The VM then calls `self.key?(:a)` (which succeeds) followed by `self[:a]` (which returns the value). This is why native pattern matching is fast: zero allocation on the hot path. That's hard to beat, but we're going to try anyways.

## At the C Level

Now I'm going to preface what is going to come next: I do not know C. I can read it, sure, I can also make reasonable interpretations and facsimiles of it as well, but I am most certainly not a C programmer. What you see below is going to be fairly heavily guided by AI as an experiment, albeit very heavily influenced by my own ideas around bitmasking, write-tracking, and similar algorithmic ideas.

I'm more interested in seeing what's possible, what type of parity guarantees we may be able to get to, and how performance measures up against native options. In previous explorations into pattern matching this was at the Ruby level with gems like [Qo](https://github.com/baweaver/qo) and [Dio](https://github.com/baweaver/dio) over the years. The problem is that they would _never_ reach performance parity no matter how well I optimized, and with the advent of AI as a tool it allows me to get _close enough_ to explore, which has been a substantial help.

You're also going to see me meander through some ideas which are obviously not optimized as I want to see _how this works_ and what each potential change might cost. I can't skip to the end when I don't know how to [draw the rest of the owl](https://knowyourmeme.com/memes/how-to-draw-an-owl), so I'm not going to pretend to, especially for these types of articles.

> **As an aside**: Yes, I use AI in my writing. No, it does not write my articles for me. Something like 95% are my own words, though I do use it to workshop ideas, outlines, catch phrasing and grammatical errors, and in general bounce ideas.

## Tracking Key Types on Write

My first idea was seeing if we could pay the cost up front to know that a Hash contains String keys. We could achieve this by tracking on inserts, and see how much that might cost.

In CRuby, every object has a `flags` word on its header (`RBasic`). Hashes already use bits 1 through 11 and 13 through 19 for things like "is this using the array-backed small-hash optimization" and "how deeply nested are we in iteration." Bit 12 was free, something we'll come back to when we get to patching CRuby directly.

I started by trying to write this as a C extension, but quickly discovered that while extensions _can_ technically set `FL_USER` bits (the macros are in the public headers), claiming Hash's internal bits from outside the VM is unsupported and unsafe since nothing reserves them for third parties. So I started with instance variables instead. To start we'd watch every `[]=` call, check if the key is a String, and if so set the flag:

```c
// `static` means this function is only visible within this file.
//
// `VALUE` is CRuby's universal type. Every Ruby object, whether it's
// a String, Integer, Hash, or nil, is represented as a VALUE at the C
// level. It's either a tagged pointer to a heap object or an immediate
// value packed into the pointer itself (Symbols and small Integers
// use this trick to avoid heap allocation entirely).
//
// This function signature mirrors Ruby's `Hash#[]=` method. `self` is
// the hash being written to, `key` and `value` are the arguments.
static VALUE flagged_hash_aset(VALUE self, VALUE key, VALUE value) {

    // `rb_ivar_get` reads an instance variable from a Ruby object.
    // `id_mask` is a pre-interned ID (think: a Symbol that's been
    // converted to an integer for fast lookup). We interned "@_m"
    // once at extension load time so we don't pay string comparison
    // costs on every access.
    //
    // The return value is a `VALUE`: either a Ruby Fixnum holding our
    // bitmask, or nil if the ivar hasn't been set yet.
    VALUE current = rb_ivar_get(self, id_mask);

    // `NIL_P` is a macro that checks if a `VALUE` is Ruby's `nil`.
    // `FIX2INT` converts a Ruby Fixnum (a tagged integer that lives
    // inside the `VALUE` pointer, no heap allocation) into a plain C int.
    //
    // The ternary gives us 0 if the ivar hasn't been set yet,
    // or the stored bitmask if it has.
    int mask = NIL_P(current) ? 0 : FIX2INT(current);

    // `SYMBOL_P` checks if a `VALUE` is a Symbol. Static symbols (the
    // common case, like `:name` or `:age`) are immediate values stored
    // directly in the pointer with a tag bit, making this check a
    // fast bitwise operation. Dynamic symbols (created at runtime
    // via `to_sym` on arbitrary strings) are heap-allocated `T_SYMBOL`
    // objects, which `SYMBOL_P` also catches via a type check.
    //
    // We use the mask as a 2-bit field:
    //   bit 0 set = at least one Symbol key has been inserted
    //   bit 1 set = at least one String key has been inserted
    //   both set  = mixed hash
    //
    // The `|=` operator is bitwise OR-assign. It turns a bit on
    // without affecting the other bits.
    if (SYMBOL_P(key)) {
        mask |= 1;
    } else if (RB_TYPE_P(key, T_STRING)) {
        // `RB_TYPE_P` checks the type flag stored in an object's header.
        // Every heap-allocated Ruby object has a flags word that includes
        // its type. `T_STRING` is the internal tag for String objects.
        mask |= 2;
    }

    // Only write back if the mask actually changed. ivar writes are
    // expensive (they go through a table lookup to find the ivar's
    // storage slot in the object), so we avoid them when possible.
    if (NIL_P(current) || FIX2INT(current) != mask) {
        // rb_ivar_set writes an instance variable on the object.
        // INT2FIX converts a C int back to a Ruby Fixnum VALUE.
        rb_ivar_set(self, id_mask, INT2FIX(mask));
    }

    // `rb_call_super` calls the parent class's version of this method,
    // which in our case is `Hash#[]=`. The first argument is the number
    // of arguments to pass (2: key and value), and the second is a
    // C array holding those arguments. This is how we delegate to the
    // real insertion logic after our bookkeeping is done.
    return rb_call_super(2, (VALUE[]){key, value});
}
```

Granted, as mentioned above, I knew this was probably going to be expensive. It ends up costing about **37% overhead per insert** compared to a Hash that calls `super`, and that ain't going to fly. It's not the bitmap logic, those are cheap, it's the instance variables via `rb_ivar_get` and `rb_ivar_set` calls. For a Hash (which is a `T_HASH` object), instance variables live in a generic-fields table keyed by object rather than in a fixed slot, which means every ivar access goes through a global table lookup. For something called that often that gets expensive fast, so this idea was out.

The lesson here? The flag _idea_ maybe has potential, but storing it as an instance variable is far too expensive on a per-write basis. In CRuby proper, `FL_SET_RAW(hash, RHASH_HAS_STRING_KEY)` is a single bitwise OR on a pointer that's already in a register, which is effectively free.

## Deferring the Work

Perhaps write-ahead was a bad idea. What if we instead deferred the work until someone actually asks for a pattern match? The hash gets built from wherever it comes from, and the first time `deconstruct_keys` is called we scan the keys once to figure out what types are present, cache the answer, and use it from then on.

The write side becomes almost free. On `[]=`, the only work is checking whether a previously-cached flag needs to be invalidated:

```c
static VALUE lazy_hash_aset(VALUE self, VALUE key, VALUE value) {

    // Read the cached flag. If it's nil, we've never computed it,
    // so there's nothing to invalidate. If it equals FLAG_DIRTY
    // (our sentinel value for "needs recomputation"), same deal.
    //
    // Only if the flag was previously computed AND is still valid
    // do we need to mark it dirty, because adding a new key might
    // change the hash's key composition.
    VALUE cached_flag = rb_ivar_get(self, id_flag);
    if (!NIL_P(cached_flag) && FIX2INT(cached_flag) != FLAG_DIRTY) {
        rb_ivar_set(self, id_flag, INT2FIX(FLAG_DIRTY));
    }

    // Delegate to Hash#[]= for the actual insertion.
    return rb_call_super(2, (VALUE[]){key, value});
}
```

Bulk construction via `merge!` bypasses the subclass `[]=` entirely (CRuby's `rb_hash_update_i` calls `rb_hash_aset` at the C level, never dispatching to our override), which means the flag tracking is skipped for that path. Worse: a `merge!` _after_ the flag has been computed leaves a stale cached value, producing wrong match results. This unsoundness is a reason the approach dies as an extension strategy independent of the read-side allocation cost. On the read side, `deconstruct_keys` computes the flag once and caches it:

```c
static VALUE lazy_hash_deconstruct_keys(VALUE self, VALUE keys) {

    // NIL_P(keys) means the pattern used `**rest` or similar,
    // asking for all keys. Return self, same as stock Ruby.
    if (NIL_P(keys)) return self;

    // get_flag reads our cached ivar and returns a C int.
    int flag = get_flag(self);

    // FLAG_DIRTY means we haven't computed the key composition yet
    // (or a write invalidated it). Scan all keys once to figure out
    // whether this hash has Symbol keys, String keys, or both.
    // compute_flag iterates the hash's keys in O(n), checks each
    // type, and returns one of FLAG_SYMBOL, FLAG_STRING, or FLAG_MIXED.
    if (flag == FLAG_DIRTY) {
        flag = compute_flag(self);
        set_flag(self, flag);
    }

    // Now we know the key composition without scanning again.
    // If all Symbol: return self, zero allocation.
    // If String or mixed: build a resolved result hash.
    // ...
}
```

For pure-Symbol hashes this returns `self` with zero allocation, the same as native implementations. For String-keyed hashes it builds a result hash with Symbol keys mapped to their string-key values, which is where the cost shows up.

That result hash is the bottleneck. Allocating it costs ~135ns (one `rb_hash_new_with_size` plus three lookups, three `rb_hash_aset` calls, and three `rb_sym2str` conversions for a three-key pattern). Native `deconstruct_keys` costs ~30ns because it returns `self` and allocates nothing. No matter how clever the flag logic gets, the allocation on the read path dominates everything else.

The lesson from this attempt is that lazy invalidation from an extension is unsound (bulk operations bypass the override silently), and even if it were sound the read-side allocation dominates.

## Eliminating the Allocation

Then let's get rid of the allocation. Return `self` from `deconstruct_keys` and make `[]` itself key-irreverent, so when the VM calls `self[:name]` on a String-keyed hash our override converts `:name` to `"name"` and looks that up instead.

```c
static VALUE za_hash_aref(VALUE self, VALUE key) {

    // Read the 2-bit mask we've been maintaining on writes.
    // This tells us whether the hash contains Symbol keys, String
    // keys, or both, without scanning.
    int mask = za_get_mask(self);

    // MASK_SYM is 1 (bit 0 only). If mask <= 1, the hash is either
    // empty or contains only Symbol keys. No conversion needed,
    // just look up the key directly.
    if (mask <= MASK_SYM) {
        // rb_hash_aref is CRuby's implementation of Hash#[].
        // It does a hash table probe: compute the key's hash value,
        // find the bucket, compare keys, return the value or nil.
        return rb_hash_aref(self, key);
    }

    // If we get here, the hash has String keys (maybe also Symbol).
    // We only need to do conversion if the caller passed a Symbol.
    if (SYMBOL_P(key)) {

        // MASK_STR is 2 (bit 1 only). This means the hash has
        // ONLY String keys, no Symbols at all. We know for certain
        // the Symbol won't match directly, so skip straight to
        // converting it.
        if (mask == MASK_STR) {

            // rb_sym2str converts a Symbol to its String representation.
            // Crucially, this is NOT String allocation. Symbols in CRuby
            // already store a pointer to their string content internally.
            // rb_sym2str just returns that existing frozen String.
            // Cost: one pointer dereference. Effectively free.
            VALUE str_key = rb_sym2str(key);
            return rb_hash_aref(self, str_key);

        } else {

            // mask == 3 means mixed (both Symbol and String keys exist).
            // Try the Symbol directly first since that's cheaper (no
            // conversion). Only fall back to String if the Symbol misses.
            //
            // rb_hash_lookup2 is like rb_hash_aref but returns a custom
            // default instead of calling Ruby's #default method. We use
            // Qundef (a special internal "undefined" sentinel that can
            // never appear as a real Ruby value) to distinguish "key not
            // found" from "key found with value nil".
            VALUE val = rb_hash_lookup2(self, key, Qundef);
            if (val != Qundef) {
                return val;
            }

            // Symbol missed. Try the String form.
            VALUE str_key = rb_sym2str(key);
            return rb_hash_aref(self, str_key);
        }
    }

    // Non-Symbol key (Integer, String, etc): look up directly.
    // No conversion makes sense here.
    return rb_hash_aref(self, key);
}
```

The `deconstruct_keys` for this version is one line: `return self;`. That alone benchmarked at 33M ops/sec, about 95% of native's 34.7M, killing the allocation bottleneck.

There's a catch though. The VM doesn't just call `[]` after `deconstruct_keys`, it calls `key?` first to check existence. So this extension also needed to override `key?` with the same sym-to-str fallback logic (not shown above for brevity). That doubles the dispatch overhead per key.

Killing one bottleneck exposed the next. When the VM calls our `[]` and `key?` overrides for each pattern key, it goes through Ruby's method lookup table to reach them. That dispatch costs ~12ns per method call per key compared to native's inlined fast path which costs zero because the VM recognizes `Hash#[]` and `Hash#key?` and skips method dispatch entirely. With both `key?` and `[]` dispatched per key, that's ~24ns of overhead per pattern key.

Three keys at 24ns each is 72ns of overhead that cannot be eliminated from outside the VM. End-to-end through a full `in` expression, the best this approach achieves is **55% for String-keyed hashes**. The remaining gap is entirely "you are not the class the VM expects, so you pay the dispatch tax."

The wall is that CRuby's pattern matching has a fast path for `Hash` specifically, and no subclass can participate in it. This needs to live inside CRuby itself.

## The Patch

Writing this in Ruby wasn't going to work, writing it in an extension still incurs taxes, so we're left with one option here: patch CRuby itself and see what we can figure out. We're going to look into patching `Hash#deconstruct_keys` directly in `hash.c` using what we've discovered so far, and now that we have access to flags that seems like a good place to start.

In `internal/hash.h`, I added `RHASH_HAS_STRING_KEY` to the existing flags enum using the free bit 12:

```c
// Every Ruby object has a "flags" word in its header (RBasic).
// CRuby uses individual bits in this word to store metadata about
// the object without allocating extra memory. For Hash objects,
// bits 1-11 and 13-19 are already spoken for (iteration depth,
// whether it's using the small-hash array optimization, etc).
//
// Bit 12 was unused. We claim it.
//
// FL_USER12 is a macro that expands to the bitmask for bit 12.
// Naming it RHASH_HAS_STRING_KEY gives it semantic meaning in code.
enum ruby_rhash_flags {
    RHASH_PASS_AS_KEYWORDS = FL_USER1,        /* FL 1  */
    RHASH_PROC_DEFAULT = FL_USER2,            /* FL 2  */
    RHASH_ST_TABLE_FLAG = FL_USER3,           /* FL 3  */
    RHASH_AR_TABLE_SIZE_MASK = (FL_USER4|FL_USER5|FL_USER6|FL_USER7),
    //                                        /* FL 4..7  */
    RHASH_AR_TABLE_BOUND_MASK = (FL_USER8|FL_USER9|FL_USER10|FL_USER11),
    //                                        /* FL 8..11 */
    RHASH_HAS_STRING_KEY = FL_USER12,         /* FL 12, NEW */
    // ...
};
```

Setting this flag costs nothing because `rb_hash_aset` _already_ branches on whether the key is a String (it needs to know this to freeze/dup String keys on insertion). The existing code:

```c
VALUE
rb_hash_aset(VALUE hash, VALUE key, VALUE val)
{
    // hash_iterating_p checks if something is currently iterating
    // over this hash (like .each). If so, modifications need special
    // handling to avoid corrupting the iterator.
    bool iter_p = hash_iterating_p(hash);

    // rb_hash_modify is a guard that raises FrozenError if the hash
    // is frozen, and does internal bookkeeping for copy-on-write.
    rb_hash_modify(hash);

    // RHASH_STRING_KEY_P is a macro that already existed before our
    // patch. It checks two things:
    //   1. Is this hash NOT using identity comparison (object_id-based)?
    //   2. Is the key's class exactly rb_cString?
    //
    // CRuby needs to know this because String keys get special
    // treatment: they're frozen and duplicated on insertion so that
    // mutating the original string later doesn't corrupt the hash.
    //
    // This branch ALREADY EXISTS in Ruby. We are not adding a new
    // check. We are adding one instruction to the branch that
    // already fires for String keys.
    if (!RHASH_STRING_KEY_P(hash, key)) {
        RHASH_UPDATE_ITER(hash, iter_p, key, hash_aset, val);
    }
    else {
        // FL_SET_RAW performs a bitwise OR on the object's flags word.
        // `hash` is a VALUE (pointer to the object). The flags word
        // is the first field in the object's header struct (RBasic).
        // So this is: object->flags |= RHASH_HAS_STRING_KEY
        //
        // One CPU instruction. No function call. No allocation.
        // No branch. The flag is set unconditionally because we
        // already know the key is a String from the if-check above.
        FL_SET_RAW(hash, RHASH_HAS_STRING_KEY);

        RHASH_UPDATE_ITER(hash, iter_p, key, hash_aset_str, val);
    }
    return val;
}
```

`FL_SET_RAW` is a bitwise OR on a pointer that's already loaded. That means no branching, function calls, or allocations. The flag also gets set in `rb_hash_bulk_insert` (used by hash literals) by scanning keys once before insertion, and propagates through `hash_copy` (the internal function that merge, select, reject, dup, and every other derived-hash operation flows through) so that any hash born from a String-keyed parent inherits the flag automatically.

Now for `deconstruct_keys`. The original implementation is a single line:

```c
// The original implementation before our patch.
// `static` makes it file-scoped. Returns a VALUE (a Ruby object).
// The function receives the hash itself and the array of keys the
// pattern is asking about.
//
// It literally just returns the hash unchanged. The VM handles
// everything else by calling [] on it for each pattern key.
static VALUE
rb_hash_deconstruct_keys(VALUE hash, VALUE keys)
{
    return hash;
}
```

The patched version:

```c
static VALUE
rb_hash_deconstruct_keys(VALUE hash, VALUE keys)
{
    // When keys is nil, the pattern used `**rest` syntax, meaning
    // "give me everything." Return self unchanged. Same as before.
    if (NIL_P(keys)) return hash;

    // The VM always passes nil or an Array here, but Ruby's spec suite
    // tests degenerate inputs like integers and empty strings. If keys
    // isn't an Array, return self to match the original behavior.
    //
    // RB_TYPE_P checks the type tag in the object's flags word.
    // T_ARRAY is the internal type for Array objects.
    if (!RB_TYPE_P(keys, T_ARRAY)) return hash;

    // Fast exit: check the flag we set during rb_hash_aset.
    // If RHASH_HAS_STRING_KEY was never set, this hash has only ever
    // had Symbol keys inserted. Return self immediately with zero
    // additional work, identical to the original implementation.
    //
    // FL_TEST_RAW is a bitwise AND on the object's flags word.
    // One CPU instruction, always in L1 cache since we just touched
    // the object to call this method.
    if (!FL_TEST_RAW(hash, RHASH_HAS_STRING_KEY)) return hash;

    // RARRAY_LEN gets the length of a Ruby Array. The `keys` argument
    // is an Array of Symbols representing the keys the pattern is
    // asking about (e.g. [:name, :age, :role] for `in { name:, age:, role: }`).
    long len = RARRAY_LEN(keys);
    int all_found = 1;

    // Fast path: check if every requested key exists directly in the
    // hash as-is. For pure-Symbol hashes (the common case, and all
    // existing Ruby code), every key hits on the first try and we
    // return self with zero allocation. Identical to the old behavior.
    //
    // RARRAY_AREF reads an element from a Ruby Array by index.
    //
    // hash_stlike_lookup probes the hash table for a key.
    // `st_data_t val` is where the found value gets stored.
    // Returns true (nonzero) if the key exists, false (0) if not.
    for (long i = 0; i < len; i++) {
        VALUE key = RARRAY_AREF(keys, i);
        st_data_t val;
        if (!hash_stlike_lookup(hash, key, &val)) {
            all_found = 0;
            break;
        }
    }
    if (all_found) return hash;

    // Slow path: at least one key wasn't found directly.
    // Try resolving Symbol keys to their String equivalents.
    //
    // rb_hash_new_with_size pre-allocates a hash with room for
    // `len` entries. This avoids repeated resizing as we insert.
    VALUE result = rb_hash_new_with_size(len);
    st_data_t val;
    int any_resolved_via_string = 0;

    for (long i = 0; i < len; i++) {
        VALUE key = RARRAY_AREF(keys, i);

        // First try: does the key exist directly? This handles Symbol
        // keys in mixed hashes (where some keys are Symbols and some
        // are Strings).
        if (hash_stlike_lookup(hash, key, &val)) {
            // rb_hash_aset inserts into our result hash.
            // We use the original Symbol as the key so the VM can
            // find it via its normal [] path later.
            rb_hash_aset(result, key, (VALUE)val);
        }

        // Second try: if the key is a Symbol and the direct lookup
        // missed, convert it to a String and try again.
        else if (SYMBOL_P(key)) {
            // rb_sym2str returns the Symbol's internal frozen String.
            // Symbols in CRuby store their string content as a pointer
            // inside the Symbol struct. This function returns that
            // existing String without allocating a new one.
            VALUE str_key = rb_sym2str(key);

            if (hash_stlike_lookup(hash, str_key, &val)) {
                rb_hash_aset(result, key, (VALUE)val);
                any_resolved_via_string = 1;
            }
        }
    }

    // If no String fallback actually helped, return self.
    // This preserves the original hash in NoMatchingPatternKeyError
    // messages. Without this guard, failed matches would show an
    // empty hash in the error instead of the actual data, which
    // makes debugging pattern match failures much harder.
    if (!any_resolved_via_string) return hash;

    return result;
}
```
This gives us four exit paths:

1. `nil` keys or non-Array input → return `self` (same as stock).
2. Flag unset (no String keys ever inserted) → return `self` immediately, zero work.
3. All requested keys hit directly → return `self`, zero allocation.
4. String fallback resolves at least one key → return a new Symbol-keyed result hash. If no fallback helped, return `self` for correct error messages.

## What's Safe, What's Not

I'd initially considered patching `Hash#[]` as well to make this more global behavior for the sake of curiosity, but that's far too broad of a change and puts a tax on every single Hash across every Ruby program out there, so that was out. Changing `[]` means every hash access in every Ruby program pays for a branch it doesn't need, and more critically it changes semantics: `{ "name" => "Alice" }[:name]` would start returning `"Alice"` instead of `nil`. Code that relies on Symbol and String keys being distinct namespaces would break silently, authorization logic that distinguishes `params[:admin]` from `params["admin"]` could develop holes, and Rails' `HashWithIndifferentAccess` would interact in unpredictable ways with a core Hash that's partially indifferent on its own.

The patch is scoped to `deconstruct_keys`:

<%= render Shared::CodeBlock.new(file: "patching-cruby-string-key-pattern-matching/examples.rb", segment: "safety_guarantees", unwrap: true) %>

Pattern matching is a query, and queries should be flexible about how they find data. `Hash#[]` is a lookup, and lookups should be precise. That distinction is the reason `deconstruct_keys` is the right place for this behavior and `[]` is not.

There are a few things to know about how the flag works:

**The safety invariant:** a hash containing a String key must never carry an unset flag. A stale _set_ flag costs one unnecessary scan in `deconstruct_keys` (it checks all keys, finds them directly, returns self). A stale _unset_ flag silently breaks pattern matching. The flag propagates through `hash_copy`, which is the single choke point for all derived-hash operations (merge, select, reject, transform_values, compact, to_h, dup). The only place the flag gets _cleared_ is `rb_hash_replace`, when a String-keyed hash is replaced with a Symbol-only hash.

**Precedence:** if a hash contains both `:name` (Symbol) and `"name"` (String), the Symbol key wins. The direct lookup hits first and the String fallback is never tried.

**`**rest` patterns do not get String-key resolution.** The VM passes `nil` for the keys argument when `**rest` is present (it needs all keys to build the rest hash), our function returns `self`, and the VM's subsequent `key?(:name)` calls fail against String keys. `{ "name" => "Alice" } in { name:, **rest }` does not match. This would require changes to the pattern matching compilation in `compile.c` to resolve.

**Partial resolution and error messages:** if a pattern has three keys and only two resolve via String fallback, the returned hash contains those two. The third key's absence causes the match to fail, and the error message shows the partially-resolved hash rather than the original. The original contains more information (all the String keys), but in a form the pattern can't reference. This is an accepted implementation side effect of returning the resolved subset: the guard only returns `self` when _no_ String fallback helped at all (the complete-miss case), since in that case the hash was never meant to match and the original data is the correct thing to surface.

## The Numbers

On patched CRuby (Ruby 4.1.0dev, arm64-darwin25, Apple M-series):

```
sym `in`:  ~6.4M ops/sec  (~155 ns/op)
str `in`:  ~3.6M ops/sec  (~279 ns/op)
mix `in`:  ~4.0M ops/sec  (~249 ns/op)
```

String-key matching runs at roughly 55% of the patched Symbol baseline. Mixed hashes land around 63%. The Symbol path itself (flag check + immediate return) is not measurably different from stock `deconstruct_keys` (which does `return hash` unconditionally), because both are dominated by method dispatch overhead rather than the function body. I don't have a same-binary unpatched control to prove zero regression rigorously, but the three added checks (`NIL_P`, `RB_TYPE_P`, `FL_TEST_RAW`) are all single-instruction operations on data already in cache.

The ~125ns overhead on the String path is dominated by allocating and populating the result hash (`rb_hash_new_with_size` plus three `rb_hash_aset` calls). The `rb_sym2str` conversions contribute almost nothing since Symbols store their String form internally as an already-frozen String.

Running `make test-all TESTS="test/ruby/test_hash.rb test/ruby/test_pattern_matching.rb test/ruby/test_hash_deconstruct_string_keys.rb"` passes clean.

## What This Unlocks

<%= render Shared::CodeBlock.new(file: "patching-cruby-string-key-pattern-matching/examples.rb", segment: "nested_json_match", unwrap: true) %>

Pattern matching against external data without `deep_symbolize_keys`, `transform_keys`, or `header_converters: :symbol` standing between you and the question you're trying to ask.

## Connecting to Feature #22111

There are two [related](https://bugs.ruby-lang.org/issues/22108) [proposals](https://bugs.ruby-lang.org/issues/22111) on the Ruby bug tracker for non-Symbol keys in hash literals and patterns. [Feature #22108](https://bugs.ruby-lang.org/issues/22108) proposes `(expr): value` "capsule" syntax, and [Feature #22111](https://bugs.ruby-lang.org/issues/22111) proposes a broader `expr : value` "hash colon" syntax (which the community has pushed back on for whitespace ambiguity). Both solve the problem at the parser layer by letting you write the String key directly in the pattern.

This patch works at the runtime layer instead. It lets you write `in { name: String => name }` with the existing Symbol-key syntax and have `deconstruct_keys` resolve the mismatch transparently. The two approaches are orthogonal. The syntax proposals give explicit control when you want it. The runtime approach handles the common case where you don't want to think about key types at all.

Both could land independently and complement each other.

## Where This Goes

The patch is on a branch at [github.com/baweaver/ruby](https://github.com/baweaver/ruby/tree/feature/hash-key-type-bitmask), including the [implementation](https://github.com/baweaver/ruby/blob/feature/hash-key-type-bitmask/hash.c) and a [test suite](https://github.com/baweaver/ruby/blob/feature/hash-key-type-bitmask/test/ruby/test_hash_deconstruct_string_keys.rb). The benchmark used in this article is available at <%= repo_link "benchmark.rb", "src/_code/patching-cruby-string-key-pattern-matching/benchmark.rb" %>.

Currently it hits roughly 55% of Symbol-path speed for String-keyed hashes, which is certainly better than not working at all, and there are ways to go faster. Hash patterns compile to generic `respond_to?`/`deconstruct_keys`/`key?`/`[]` send sequences in `compile.c`, and a specialized instruction or opt_send fast path for the `key?` + `[]` pair could inline the `rb_sym2str` fallback without allocating an intermediate hash. That's a deeper change to the compilation pipeline that's beyond the scope of proving the concept works.
