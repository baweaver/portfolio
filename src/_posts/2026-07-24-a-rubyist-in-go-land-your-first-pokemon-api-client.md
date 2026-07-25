---
layout: "post"
title: "A Rubyist in Go Land: Your First Pokémon API Client"
date: "2026-07-24"
categories: []
tags: ["ruby", "go", "rubyist-in-go-land"]
series: "rubyist-in-go-land"
description: "I need to level up on Go, and Pokémon data felt like a good excuse. This post builds the same API client in Ruby and Go, comparing how I think about the problem in each."
---

When I was growing up there was one game that I played to death: Pokémon Blue. Of course, that was after I figured out the carpet was the exit for the house, which took longer than I'd care to admit. It was my start into technology, along with Legend of Zelda, that made me want to try my own hand at making games and RPGs. Not long after I stumbled upon RPG Maker, and when the XP version came out it had this lovely scripting engine called RGSS where you could modify _anything_, and to kid me that was a wondrous playground. Oh, and RGSS? That was Ruby Game Script System, which means I've been doing Ruby for north of 20 years now if we count that at the time of writing this article.

Why am I mentioning that? Last fall I was in the audience for Tess Griffin's [Learning Empathy from Pokémon Blue](https://www.youtube.com/watch?v=rUDVsDJG088) at Rocky Mountain Ruby. It covered the infamous MissingNo glitch, how it functioned, how well-intentioned developers may have ended up writing it. It reminded me of those times. Fast forward and she gave the same talk again at RubyConf this year, and it gave me a few ideas of how I'd approach another adventure I find myself on.

A lot of folks know me as the "Ruby guy" but I _do_ know other languages like Scala, Javascript, Python, and a smidge of Go from previous roles. Granted not as deeply, but part of how you get there is _building things_ and experimenting, and as of recently I need to get back up to speed on Go so here we are.

Given that, I'm looking back at Pokémon again, and more directly [PokéAPI](https://pokeapi.co/), the open Pokémon data API. We're going to go through API clients, how I might write things in Ruby, and what that translates to in Go while trying to behave myself and not rewriting Ruby in Go.

To be clear this series isn't going to teach you Go syntax, and it's not going to rank the two against each other. I'm evaluating which of my Ruby instincts translate and which don't, and experimenting with tooling I'm not immediately familiar with. That means to be fair, as mentioned above, I will be _attempting_ to write Go like a Go programmer (correct me if I miss here) instead of like a Rubyist.

Shall we get started then?

## A local Pokédex first

While PokéAPI is a great resource and API, it would be bad manners to point readers directly at it, so before writing a client we're going to stand up a local copy to experiment against instead of hammering the live server.

The project publishes its entire dataset as static JSON in [PokeAPI/api-data](https://github.com/PokeAPI/api-data), which makes "run PokéAPI locally" less adventurous than it sounds. We pull the handful of Pokémon this post needs into a fixtures directory:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/fetch_fixtures.rb", segment: "fetch-fixtures") %>

Giving us back files we can serve directly from our own lightweight server:

```
$ ruby fetch_fixtures.rb
fetched bulbasaur  (537794 bytes)
fetched charmander (599737 bytes)
fetched squirtle   (605737 bytes)
fetched pikachu    (572204 bytes)
```

And we can write that server with a quick Go script:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/cmd/serve-fixtures/main.go", segment: "server", lang: "go") %>

Which we can run:

```
$ go run ./cmd/serve-fixtures
2026/07/18 05:02:10 Serving fixtures/data on http://localhost:9595/api/v2
```

> **Wait, why not just clone the repo?** The full api-data dataset is around 3GB for four Pokémon we actually need. The fetch script grabs only what this post uses, the Go server doubles as our first piece of Go to read, and the fixtures stay small enough to commit alongside the article code.

## The Ruby baseline

The task for this first post is deliberately small, because we want to focus on which instincts transfer and which do not. For the sake of this article we want to fetch one pokémon and print its number, name, types, abilities, and base stats.

We would start by fetching the data we need and converting that to JSON:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/pokemon.rb", segment: "setup") %>

Then we can extract the data we need using pattern matching, and more specifically right-hand assignment, by leveraging the `symbolize_names` option above to make all keys Symbols:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/pokemon.rb", segment: "shape") %>

And finally we can get to some basic display logic:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/pokemon.rb", segment: "display") %>

Which results in:

```
$ POKEAPI_URL=http://localhost:9595/api/v2 ruby pokemon.rb bulbasaur
#0001 Bulbasaur
Types:     grass / poison
Abilities: overgrow, chlorophyll

special-defense   65 █████████████
special-attack    65 █████████████
defense           49 █████████
attack            49 █████████
speed             45 █████████
hp                45 █████████
```

The whole script is <%= claim("ruby script line count", 33) %> lines, and it reads like the task description. You'll already notice a few habits I have in writing this:

* `fetch` - For Hashes I tend to prefer `fetch` with a reasonable default.
* `or` - Some Rubyists avoid the english operators, but I tend to like them for things like this, even if it's Perl-y.
* `abort` - Early guards to bail out, and postfix conditionals to gate them. Admittedly I'm almost inclined to write `response.is_a?(Net::HTTPSuccess) or abort("No Pokémon named #{query.inspect}")` but then I'm being deliberately dense lexically.
* `symbolize_names` - Hash pattern matching in Ruby only works on Symbol keys, so I tend to have this option on more often than not.
* Pattern matching - I use it, I like it. Scala, Rust, Elixir, Javascript, and other languages spoiled me so yes I'm using it with some regularity in Ruby
* `Enumerable` - I use a _ton_ of Enumerable methods for sorting, transforming, and other operations
* Shorthand - `_1` and `it` are common in my code when it makes sense, though less so if I want to aim for readability as a primary focus.
* `dig` - Traversing nested hashes is a lot quicker with `dig` around, and I use it liberally.


The most unusual habit in that list is the pattern matching, and more specifically rightward assignment:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/pokemon.rb", segment: "shape") %>

It's doing more than just destructuring values, it's also verifying the shape of the JSON. If a key is missing it will raise a `NoMatchingPatternKeyError`, giving us a pretty clear warning sign that something in the API changed or we might have assumed something was there that frankly wasn't.

Granted I'm being a bit clever here in showing off various Ruby tools and tricks, but it's close to how I might write Ruby at home. At work I do try and be just a tinge more readable, unless it's a one-off script. Now let's see what the same task looks like in Go.

## Starting over in Go

To reiterate: I do not know Go deeply, so if anything you read here is deeply offensive to your Go sensibilities feel free to comment, I have a lot to learn still in this language and am always welcoming new ideas.

That said, the start for this program is something I took for granted in Ruby: Types on inbound JSON:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/cmd/pokemon-quick/main.go", segment: "structs", lang: "go") %>

The `Name` and `URL` pair repeats across types, abilities, and stats, and extracting it reproduces a concept PokéAPI's docs already define as [NamedAPIResource](https://pokeapi.co/docs/v2#namedapiresource). In Go it feels apt to start with the shape of the data we're working with, much as I might with F# from my time reading [Domain Modeling Made Functional](https://pragprog.com/titles/swdddf/domain-modeling-made-functional/).

The rest of the draft is plain: `http.Get` in `main`, decode into `Pokemon`, print:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/cmd/pokemon-quick/main.go", segment: "main", lang: "go") %>

And the display:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/cmd/pokemon-quick/main.go", segment: "display", lang: "go") %>

Which gives us this:

```
$ POKEAPI_URL=http://localhost:9595/api/v2 go run ./cmd/pokemon-quick bulbasaur
#0001 Bulbasaur
Types:     grass / poison
Abilities: overgrow, chlorophyll

special-attack    65 █████████████
special-defense   65 █████████████
attack            49 █████████
defense           49 █████████
hp                45 █████████
speed             45 █████████
```

The quick draft works, but it has no timeout. If the server hangs, so does the script, which was something I definitely found surprising coming from Ruby.

## Where the quick draft breaks

Let's deliberately make a server that accepts a connection and never responds to prove this:

```
$ ruby -e '
  require "socket"
  server = TCPServer.new("127.0.0.1", 9999)
  conn = server.accept
  sleep 120
' &

$ POKEAPI_URL=http://127.0.0.1:9999/api/v2 timeout 15 go run ./cmd/pokemon-quick bulbasaur
$ echo $?
124
```

Exit code 124 means `timeout` killed the process at the fifteen second cap; left alone, it waits forever. Ruby is more defensive here. `Net::HTTP` ships with <%= claim("net http open timeout", 60) %> second open and <%= claim("net http read timeout", 60) %> second read timeouts by default:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/net_http_defaults.rb", segment: "net-http-defaults") %>

Running it:

```
$ ruby net_http_defaults.rb
open_timeout: 60
read_timeout: 60
```

So the Ruby baseline gives up after a minute, and the Go draft hangs until you kill it. The fix is to create a client with an explicit deadline:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/internal/pokeapi/client.go", segment: "client", lang: "go") %>

The client moves into `internal/pokeapi`. Go's toolchain rejects imports of `internal/` packages from outside this module, which gives the repo a private core without access-modifiers like you might find in Ruby:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/internal/pokeapi/pokemon.go", segment: "fetch", lang: "go") %>

One thing that I actually like about Go from the start is that every operation that can fail canonically returns an `err` (error) value that has to be handled upon calling. It mirrors a strong preference I have in Ruby to _never_ use exceptions for flow control and instead return either reasonable defaults, or some type of significant error value that can be handled. What I don't like about it is it feels like a partial implementation of a `Result` type from something like Scala or Haskell, and composing or piping them together can be... involved. The Go community has [known this for years](https://www.innoq.com/de/blog/golang-errors-monads/), and the Go team recently [decided not to fix it at the syntax level](https://go.dev/blog/error-syntax). I think that's an oversight that should have been corrected, but it's what we have to work with.

You'll notice `fmt.Errorf("fetching %s: %w", name, err)` throughout. The `%w` verb wraps the original error inside a new one with added context, similar to Ruby's `Exception#cause` chain. Each caller can add its own layer of "what was I doing when this failed" without losing the original error underneath. When you want to check what went wrong later, `errors.Is` can unwrap the chain and match against a specific error type.

The other new concept is `context.Context`, that `ctx` parameter on the method. A context carries deadlines and cancellation signals through the call stack. When our client's 10-second timeout fires, the context is cancelled and the in-flight HTTP request aborts. In Ruby you'd set `Net::HTTP#read_timeout` on the client object itself; Go threads the deadline through every function call via this parameter. It's verbose, but it means any function in the chain can tighten the deadline further or cancel the work early without reaching back into the client.

With the client extracted, `main` gets simple. All it does is call `run`, and `run` returns errors instead of calling `os.Exit` directly:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/cmd/pokemon/main.go", segment: "run", lang: "go") %>

Point the finished version at the same unresponsive server and the hang becomes a bounded failure at the configured <%= claim("client timeout seconds", 10) %> seconds:

```
$ POKEAPI_URL=http://127.0.0.1:9999/api/v2 go run ./cmd/pokemon bulbasaur
fetching bulbasaur: Get "http://127.0.0.1:9999/api/v2/pokemon/bulbasaur": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

Against the local mirror it prints the same profile as the quick draft.

Unsurprisingly the Ruby script is shorter than the Go one, but Go is also putting a lot of structure around data and failure shapes, which a lot of Ruby programs start progressing towards as they mature. Whether that's a good trade depends on how long the program lives and how many hands touch it, as well as if there are any speed constraints.

> **On Performance**: YAGNI (you aren't going to need it) applies here. If I can write a Ruby script in 1-2 minutes and it runs in 1-2 seconds versus writing the same thing in Go in probably 10+ minutes for a runtime of fractions of a second it's not a good trade. Most things do not need performance as a first-class consideration, they need to be done. Focus on value propositions first, and if performance is part of that proposition then have at it. Granted I've written Ruby for 20+ years now, and only minor contributions in Go, maybe I get faster in Go over time too which shifts that equation a bit. 

## Shape first

Let's go back to how both languages are handling the shapes of data:

<%= render Shared::CodeBlock.new(file: "rubyist-in-go-land-01/pokemon.rb", segment: "shape") %>

And in Go:

```go
var pokemon Pokemon
```

If a key is missing from the JSON, `=>` raises `NoMatchingPatternKeyError` at runtime. If you try to access `pokemon.Nonexistent` in Go, the compiler rejects it at build time. My tendency to verify shapes carries over from Ruby, the difference is that in Ruby it's a preference I opt into and in Go it's a requirement the compiler enforces. On one hand having free and easy JSON deserialization in Ruby is nice, but on the other getting a very clear compiler level warning that something changed becomes very useful as applications grow.

## My stance on Go so far

I'm still not entirely sure what I think of Go. There are things I like about it like simplicity, minimalism, and making errors explicit and top level flow control rather than throw-catch patterns. The contradiction is that's also the reason I find Go a bit frustrating as all that minimalism ends up inflicting application complexity on the programmer, and no two programmers ever agree on how to solve those types of problems. Personally I have a preference towards having clear, obvious ways to do things that are base-level ergonomics like Enumerable in Ruby, Result types in Scala, or Promises in JS. Go still hasn't convinced me on that front, but it doesn't need to for me to get to a productive level in it either.

As programmers we're allowed to not like things and disagree with them, if anything it's in our very nature to be somewhat argumentative, but what's more important is collectively being on the same page as teams and organizations about what and why we do things. As long as the bikeshed can store bikes I personally don't care if it's painted red, blue, or some other random color. I focus on the value proposition, not the edge dressing.

## What's next

I'm keeping these posts small so I've elided a decent amount of concepts. I haven't given contexts, error handling, servers, or goroutines much time yet. I'll have to look into which one to explore next.
