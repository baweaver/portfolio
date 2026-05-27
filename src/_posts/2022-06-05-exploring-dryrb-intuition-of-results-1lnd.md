---
layout: "post"
title: "Exploring dry-rb - Intuition of Results"
date: "2022-06-05"
categories: ["ruby", "rails"]
tags: ["ruby", "rails", "functional", "endofunctors"]
description: "dry-rb is a fascinating set of tools and libraries, but their usage may not be readily apparent. Why..."
---

`dry-rb` is a fascinating set of tools and libraries, but their usage may not be readily apparent. Why might one add these libraries when there are perhaps much simpler techniques that will suffice? What is the reasoning behind the abstractions, and what gains might they afford us that could make a case for their inclusion?

Well that's what this series is. We're going to take a look at a few more non-trivial examples and explain the reasoning behind why one might want these tools, because there are most certainly cases where the incurred complexity becomes very cost-positive indeed.

In order to build the intuition there though, we first need to explore a bit of theory.

## Shapes and HTTP Responses

Perhaps one of the most powerful single concepts in programming, and one we so often take for granted, is the HTTP Response and HTTP response codes. With REST/JSON endpoints we can be (reasonably) sure we're going to get back a response which looks something like this:

```ruby
HTTP::Response(body: "<json content>", code: 200)
```

Name 100 different APIs that use REST and JSON and you can name 100 that very closely follow a similar convention to this. These responses come with a very clear "shape" that allows us to make reasonable assumptions on how we might act on them, such as with a [Rack Response](https://www.rubydoc.info/gems/rack/Rack/Response):

```ruby
response = get_data # Rack::Response returned
response_body = JSON.parse(response.body)

if response.successful? # Rack::Response::Helpers
  process(response_body)
else
  handle_errors(response_body)
end
```

This is exceptionally powerful, underlies so much of our modern web, yet is so frequently taken for granted. Encapsulated in this single idea of a response we have both data, as well as the context for the data such as whether the request was a success, an error, maybe a bad form, who knows _but it's consistent_ (as long as we play by its rules.)

### Rule Breaker

Now there is indeed a danger, alluded to above, that this presumes reason and playing by a set of rules that allow us to make those assumptions. There are some APIs which might do something like this:

```ruby
HTTP::Response(body: "ERROR! IT BLEW UP!", code: 200)
```

By doing that we've violated reasonable expectations and have lost trust in the interface, so it's up to us to be vigilant in compliance to those rules as the power of that interface is well worth the extra overhead of adopting it.

### Without Context

Let's say that we did away with codes for the moment, and a response only contained a body. Take a moment, before continuing, to muse on why that may make things substantially more complicated to use.

Got it? Well let's take a look into a few implications of removing that additional context to the data.

How do you define success? An error? Is it somewhere in the body? What if the response is empty, nil, falsy, or any other number of shapes? The JSON could very well take any number of these shapes:

```ruby
# Inline status
{ content: "<data>", status: "success" }

# Empty response
{  }

# No response
""

# String error
"Error: Something went boom"

# Number code
123456
```

Now take that potential inconsistency of how we define success and stratify it across every API in the world that plays (mostly) nicely by REST and JSON standards (oh yes, JSON has rules too) and you can see how this quickly becomes a headache.

Every single API from here on out that you consume plays by its own unique rules, and as a result inflicts the cost of implementing error and success handling on the user rather than on the service. What a painful world that would be to work in, especially if you find yourself consuming several APIs at once and creating wrappers around each to make them play nicely in your own domain.

Oh, and those wrappers that you'd have to write? You'll very likely end up with some vaguely standardized response type all your own, perhaps or probably still inconsistently, within your own application.

### Cross-Company Coupling

The more systems are coupled together, and the more they require intimate knowledge of the underlying technologies to work with them, the more difficult you will likely find it to interface.

If a company were to create a new pseudo-standard on top of HTTP like that above `200 Error` bit they have now directly coupled all of your code with their own system for processing errors.

You're now required to write a wrapper with knowledge of their own strange implementation to get it to reasonably work within your application, as mentioned above, which heavily couples you to their definition of success.

I'll give you a hint to the next major section: Imagine that internally in your own application / service mesh and how pesky that might be.

### Consistency

While there is indeed a cost associated with adopting the HTTP Response standard there is undeniably a benefit we derive from playing by its rules. That's why web servers, Rack included, use it.

It doesn't matter what the underlying data looks like, but it does matter that we can expect a consistent response from any reasonable API adhering to the standard with the same shape and agreeing to the same language of what it means when we say success.

You go to any company, work on any API, consume any API, or otherwise in this arena and you'll very likely find things very familiar. That's powerful, so incredibly so, and yet we take that for granted.

## APIs aren't Only External

That's all well and good, but how does that apply to our applications? Why is it relevant and why should we care about this consistency of shapes and HTTP responses?

Quite simply because API means public interface, and that's not necessarily talking about external interfaces either. Every public method is an API to your application, class, library, or what have you.

Consider the above for a moment, and think of all the ways you might reflect failure inside of your application, then continue along.

### What Does it Mean to Fail?

What did you come up with? Probably several different ways, each with a myriad of assumptions and requirements for working with them. Let's look at a few real quick:

```ruby
# Exceptions - String based
raise "It failed!"

# Exceptions - Class based
raise MyCustomSpecificUsefulError, "Something went wrong"

# Returning false or nil (what if falsy is valid? That's fun)
false
nil

# Reasonable empty defaults
""
[]
{}

# ...and probably many more
```

Even worse is when you realize this same headache applies to what it means to succeed, but we'll skip that one for now.

You can see how each of these likely has very interesting implications on code that relies on that interface. Now you have to know about all the underlying exceptions, or perhaps whether or not falsy returns are valid, or in the more useful case like with `Enumerable` methods you get back a reasonable empty result like so:

```ruby
[2, 4, 6].select { |v| v.odd? } # => []
```

That last one is particularly interesting as we can continue chaining things on the end of that select, and if it actually had data it'd continue down that pipeline. Sounds useful, no? We'll get back to why that's critically important here in a moment, but first...

### Exception Handling

What if `select` instead raised an exception like this:

```ruby
# Please don't actually do this to `select`:
module Enumerable
  def select(&block)
    found_elements = []
    self.each do |element|
      # If calling the block on the element is truthy, add it
      found_elements.push(element) if block.call(element)
    end
    
    raise NoResultsHere, "No data!" if found_elements.empty?
    found_elements
  end
end
```

Can you imagine working with that? You'd probably have to do something like this:

```ruby
begin
	[1, 2, 3, 4].select { |v| v > 5 }
rescue NoResultsHere
  []
end
```

Now make every Enumerable method do that instead, and we've inflicted that error handling on consumers making it a much more unpleasant interface to work with.

### The Power of Enumerable

The fact that `select` and other `Enumerable` methods continue to return `Enumerable` shaped objects is really something quite useful. It even lets us do something like this:

```ruby
(1..100)
  .select { |v| v.even? }
  .map { |v| v * 5 }
  .group_by { |v| v > 50 }
  .transform_values { |vs| vs.sum }
# => {false=>150, true=>12600}
```

You get all of that because `Enumerable` agrees on what shape of object to return, allowing you to chain as you will, and allowing you to even route around failure in a way to achieve results.

This entire concept of reasonable defaults has a name, and that name is "Identity". It's even a law, fancy that, of something much more interesting when joined with two other laws.

If you haven't yet, stop and read [Introducing Patterns for Parallelism for Ruby](/writing/2021/01/08/introducing-patterns-in-parallelism-for-ruby-2f4a/). I promise you will find it quite interesting with where your intuition might currently be going with these shapes I've been on about.

Those shapes have a name, and that name is "Monoid". Honestly though the name doesn't matter as much as the intuition that these like-typed things can be combined and chained together however we wish. Once you have that, well there are some very interesting possibilities which open up.

And that? That my friends is where `dry-rb` enters the stage with the `Result` type.

## Introducing Our Friend Result

I've spent a good bit of time leading into this, and I do apologize for that, but as a friend once said it's far easier to show the value of painkillers rather than vitamins. In a way you have to experience the absence of something to appreciate what value it might bring, rather than being immediately extolled on its inherit virtues.

### Setting the Stage

Let's set the stage right quick. You happen to be in a large Rails application that follows along with something like [Packwerk](https://github.com/Shopify/packwerk) to clearly delineate different packages in your Rails monolith. Let's say you have 100 packs, which is not particularly unusual with larger applications.

Now take all 100 of those packs, and give them public interfaces with minimal coupling. We'll say those happen in the pack in a file like `public_api.rb` or something similar, go wild really. What matters is there's a single entry point to each package.

Opening one of those public APIs we might find something like this:

```ruby
# packs/app/public/service_name.rb
class ServiceName
  class << self
    def offering_a; end
    def offering_b; end
    def offering_c; end
    def offering_d; end
    def offering_e; end
  end
end
```

All of which reach into the internals of the pack to do very important businessy things, probably some ActiveRecord, and return back a result.

Remember that bit about defining failure, and the hint on defining success as well? Oh yes:

```ruby
# packs/app/public/service_name.rb
class ServiceName
  class << self
    # Exception
    def offering_a(id)
      ServiceModel.find(id)
    end

    # Nil
    def offering_b(id)
      ServiceModel.find_by(id: id)
    end

    # False
    def offering_c(id)
      ServiceModel.find_by(id: id) || false
    end

    # Empty Collection
    def offering_d(*ids)
      ServiceModel.where(id: ids)
    end

    # Invalid Object
    def offering_e(**model_info)
      ServiceModel.create!(**model_info)
    end
  end
end
```

Every single one of them has both an idea of what constitutes success and failure. Now multiply that by 100, where every service takes their own unique and probably very valid approach to this problem and you can imagine it becoming very difficult to reason about. Doubly so when you rely on multiple services input to produce your own output, that means you get all of those services downstream too.

Now every bit of that error handling or failure handling has now been imposed on the consumer, and you're right back to square one with coupling despite having packages and very firm lines between them. Even returning direct ActiveRecord objects or collections introduces coupling, but that's another matter we won't touch for the moment.

What if, instead, they agreed on a singular definition and shape of what it means to succeed or fail? Well that's where `Result` comes in.

### The Result Type

`dry-rb` presents a very interesting solution called Result to this problem, along with very lovely documentation I suggest you wait a moment before reading that you can find [here](https://dry-rb.org/gems/dry-monads/1.3/result/). Ah, and don't mind that "Monad" word, it's not important for the moment.

It gives us the idea of `Success` and `Failure`, the two parts that comprise the larger `Result` type:

```ruby
require "dry/monads"

extend Dry::Monads[:result]

result = if foo > bar
  Success(10)
else
  Failure("wrong")
end
```

Think of `Success` and `Failure` almost like that additional context provided by HTTP Responses status code. It's a wrapper that clearly indicates to us whether something is considered successful, or if it had failed somewhere.

Like Enumerable, we can chain `Result` types together because their reasonable default is still a `Result` type:

```ruby
require "dry/monads"

extend Dry::Monads[:result]

# Pretend it's a DB of some sort
IDS = { "a" => "Red", "b" => "Blue" }

def offering_a(id)
  return Failure("ID not found: #{id}") unless IDS.key?(id)
  
  Success(IDS[id])
end

offering_a("a")
# => Success("Red")

offering_a("nope")
# => Failure("ID not found: nope")

# Remember Enumerable? What happens if we chain each of these?

offering_a("a").fmap { |name| "We found #{name}!" }
# => Success("We found Red!")

offering_a("nope").fmap { |name| "We found #{name}!" }
# => Failure("ID not found: nope")
```

For `Result` types we can call a special method called `fmap` on them to do things to the value inside, but if it's a failure? It does nothing, the failure persists through and we get it out at the end.

It can be far more interesting, though, when applied to pattern matching in Ruby 2.7+:

```ruby
result = offering_a("a")

case result
in Success("Red" | "Blue") then "Found who we were looking for"
in Success then "Not who we expected, but still ok"
in Failure(/_why/) then "He's still in our hearts though"
in Failure then "I give, you win"
end
```

We can reach inside each of those values based on the fact it's a `Result` type, or really we don't even need to reach at all:

```ruby
result = offering_a("a")
result.value_or("Yellow")
```

Though perhaps you want the more familiar `if` branch:

```ruby
if offering_a.success?
```

There's quite a bit you can do with this type of concept, but as with an HTTP Response because we've agreed on that shape and if all of our services play nice with it all of the consumer code can make those same assumptions and handle them the same way.

Hey, if the shapes all line up, that even means we could combine them or do all types of other interesting tricks like say how `Promise` or `Future` works with async in Javascript, or how `Task` could have a transactional execution list, or maybe `Validated` combining multiple errors when trying to create something that's not quite right.

The collective mental burden that alleviates when navigating a codebase pays dividends over time, just as you very likely never spend much time thinking about HTTP Responses either.

Good code is useful, but great code is transparent. HTTP Responses are transparent, and I would say that Result types very may well be too.

### Yeah, but the Underlying Data

_Record screech_

Yeah, about that one. You have the same shape, sure, but that doesn't necessarily absolve you from worrying about the data within it. The container may be great and make sense, but that doesn't mean the content is too.

If you're trying to keep clear boundaries across packs it's probably not wise to directly hand them an ActiveRecord object that can still directly access the database, or that cannot be serialized, or maybe even validated beyond the context of the database. That's only the success branch.

The failure branch is even more fun. Are we doing String errors now? What about the context, the backtrace, what params it was called with, or any of that other lovely meta information? Granted `Result` comes with [Tracing Failures](https://dry-rb.org/gems/dry-monads/1.3/tracing-failures/), but not the point. 

### Standards

The larger the application the more that standards start to become force multipliers rather than annoying rules that someone in infrastructure told you to follow. The part left unsaid there is that defining and creating those standards, especially for something like errors, is really really danged hard.

There are hundreds if not thousands of possible approaches to these problems, but overall what I've found? Pick one, build on it, and as long as you can agree on what the edges look like you can work from there.

For me things like `Promise`, HTTP Response (and even Request), Result, and other such types make great edges to start from.

## Wrapping Up

Rails wasn't built in a day, and neither will your application. It's a continual and evolving process where we learn and grow, and with our understanding so to changes our opinions. If anything the best advice is to make it easy to change, easy to recover when you fail, and minimize how much systems know about each other.

Perhaps my opinions will change one day too, they have several times already, but that's about where I'm currently at.

`dry-rb`, to me, presents a set of tools which define edges capable of bearing the weight of larger applications and reducing coupling and complexity. Are they free? No, but nothing ever is. Are they worth it? Well that'll be for you to decide, but I would say they are.

I'll be taking a look into the `dry-rb` libraries more in this series and taking a similar approach of building a case rather than telling you why things are so great or amazing. We're not here for shiny, we're here to solve problems, and perhaps this will solve yours.
