---
layout: "post"
title: "Future of Ruby – AST Tooling"
date: "2021-11-14"
categories: ["ruby", "rails"]
tags: ["ruby", "rails"]
description: "This is a series meant to explore the potential future of the Ruby programming language by visiting..."
---

This is a series meant to explore the potential future of the Ruby programming language by visiting current technologies and ideas around them, and how those might apply to the future. In this series you'll find some tools which can be used today, some which may be used tomorrow, and a collection of aspirations of what could be.

As this is a look into a potential future, you may or may not see these things come to pass, and that's ok. This is not meant to be prescriptive, but to start conversations on what things could be.

With that being said, let's take a look into the potential future of Ruby.

## AST Tooling

Programs are, at their core, text with special semantic meaning. Using Regex we can certainly treat Ruby as just plain text, but in doing so we lose the semantic meaning of what makes Ruby Ruby.

Enter in ASTs, or Abstract Syntax Trees. ASTs are a data structure that represents a Ruby program as a series of nested nodes, broken into relevant pieces using knowledge of the language.

Ruby has a few different implementations of this, the core implementation being Ripper:

```ruby
pp Ripper.sexp('def hello(world) "Hello, #{world}!"; end')
# [:program,
#   [[:def,
#     [:@ident, "hello", [1, 4]],
#     [:paren,
#      [:params, [[:@ident, "world", [1, 10]]], nil, nil, nil, nil, nil, nil]],
#     [:bodystmt,
#      [[:string_literal,
#        [:string_content,
#         [:@tstring_content, "Hello, ", [1, 18]],
#         [:string_embexpr, [[:var_ref, [:@ident, "world", [1, 27]]]]],
#         [:@tstring_content, "!", [1, 33]]]]],
#      nil,
#      nil,
#      nil]]]]
```

The AST is represented as a series of nested arrays. The problem with this, of course, is that it can be difficult to work on programmatically for tooling developers.

Enter the Whitequark parser, which you can experiment with [here](https://nodepattern.herokuapp.com/):

```ruby
ruby_code  = 'def hello(world) "Hello, #{world}!"; end'
expression = Parser::CurrentRuby.parse(ruby_code)
# s(:def, :hello,
#   s(:args,
#     s(:arg, :world)),
#   s(:dstr,
#     s(:str, "Hello, "),
#     s(:begin,
#       s(:lvar, :world)),
#     s(:str, "!")))
```

There are a few others like Melbourne, JRubyParser, and ruby_parser but we'll focus on the Whitequark parser for the sake of this article.

Put simply, I believe that it's more accessible and easily usable than Ripper, and will be the base of a lot of what could be the future of Ruby tooling. That's what we're going to explore today.

We'll be covering the following topics:

* **Find and Replace** - Regex and literal F&R is limited and prone to accidental replacements. Can we be more precise?
* **EmberJS Style Codemods** - EmberJS uses Codemods to upgrade itself, and ships with them every major version. Think that, but Rails or other major Ruby gems.
* **Babel Transpilation** - JS evolves so quickly because you can fairly easily try out experimental syntax via Babel and get proofs-of-concept out fast.
* **A to B Inferred Transforms** - Given code "A" find the transformations necessary to get to code "B".
* **Macros** - The Whitequark parser has a dual, Unparser. If Parser was standard Ruby, and any live code could be turned into an AST, we could rearrange it for some dramatic effects.

Now that's a lot of ground to cover, so shall we get started?

### Find and Replace

Let's say you wanted to replace every instance of a certain piece of text in your program with another one. Most editors have a find and replace function with added regex support which can be very handy.

For this example let's say you decided that you had named a variable `hash` and want to replace it with something more descriptive, such as `person`:

```ruby
hash = HTTP.get('some_site/people/1.json').then { JSON.parse(_1) }
puts "#{hash['name']} was found!"
```

Sure, it'd work for this case, but say that right below that code was something like this:

```ruby
puts "#{test_object.name} is currently #{test_object.hash}"
```

A global find and replace would be a real bad idea in this case, changing the meaning of your program. This is because the text "hash" has no semantic meaning, but a node related to "hash" definitely does:

```ruby
# HEREDOCs surrounded in single-quotes prevents interpolation, which
# we need here.
Parser::CurrentRuby.parse <<~'RUBY'
  hash = HTTP.get('some_site/people/1.json').then { JSON.parse(_1) }
  puts "#{hash['name']} was found!"
  puts "#{test_object.name} is currently #{test_object.hash}"
RUBY

# This generates the following AST:
s(:begin,
  s(:lvasgn, :hash,
    s(:numblock,
      s(:send,
        s(:send,
          s(:const, nil, :HTTP), :get,
          s(:str, "some_site/people/1.json")), :then), 1,
      s(:send,
        s(:const, nil, :JSON), :parse,
        s(:lvar, :_1)))),
  s(:send, nil, :puts,
    s(:dstr,
      s(:begin,
        s(:send,
          s(:lvar, :hash), :[],
          s(:str, "name"))),
      s(:str, " was found!"))),
  s(:send, nil, :puts,
    s(:dstr,
      s(:begin,
        s(:send,
          s(:send, nil, :test_object), :name)),
      s(:str, " is currently "),
      s(:begin,
        s(:send,
          s(:send, nil, :test_object), :hash)))))

```

Now we have `hash` referring to a node of type `:lvasgn` (local variable assign) and `:lvar` (local variable) as opposed to the later node `s(:send, s(:send, nil, :test_object), :hash)))` which relates to the `hash` method being called on the `test_object`.

ASTs gave distinct meaning to each part of that text, and given that we could more easily do replacements in a much more descriptive way. Think of it, in a way, like static typing for manipulating a program and ensuring your intent is more clearly expressed and executed.

Editors currently have regex support, but who's to say that we couldn't have AST or NodePattern support in the future?

Using [MarcAndre's NodePattern tool](https://nodepattern.herokuapp.com/) we can even use a regular language designed for ASTs known as NodePattern to find any local variable or assignment related to `hash` (borrowing some from [src](https://github.com/marcandre/np/blob/4f45f184d7f4c147e1efe60d7a0fe51aa446ab11/lib/np/debugger.rb#L4)):

```ruby
require "rubocop"
require "parser/current"

def ruby_parser
  builder = ::RuboCop::AST::Builder.new
  parser = ::Parser::CurrentRuby.new(builder)
  parser.diagnostics.all_errors_are_fatal = true
  parser
end

def ast_of(s)
  buffer = ::Parser::Source::Buffer.new('(ruby)', source: s)
  ruby_parser.parse(buffer)
end

def node_pattern(s) = RuboCop::NodePattern.new(s)

hash_match = node_pattern <<~NODE
  { # OR pattern
    ({lvasgn lvar} :hash _) # Either a local var or assignment
    (send nil? :hash)       # ...or a call to that variable
  } # End OR pattern
NODE

hash_match.match(ast_of("hash = {}"))
  # => true
```

In fact this is how RuboCop autocorrect works by searching for a certain node and doing something when it's found.

Some of these tools have even already been wrapped, like [Jonatas's work on FFast](https://github.com/jonatas/fast) which works on top of NodePattern and some of RuboCop's previous work. Really the only things between us and this future is a bit more wrapping and polish, as well as integrations into something like VSCode.

Any takers? I may well wrap some of this in a more minimalist gem that provides an easier-to-use interface to build on, as the current parts are non-intuitive unless you're willing to dig into the code on a non-trivial basis.

###  EmberJS Style Codemods

There are a lot, and I mean a lot, of ideas we can and should be taking from Javascript in the Ruby community. One of them is the idea of code mods for migrating syntaxes, and _especially_ for upgrades from old versions.

When I was working with EmberJS there were [multiple codemods](https://github.com/ember-codemods) designed to make migrating from one version to the next, and it was a very pleasant experience. The idea was that after you upgraded dependencies you ran one command and most if not all of the upgrade was done for your syntax.

Why can't we have that in Ruby? Why not especially for Rails? Turns out the answer is that there are indeed some of these things already:

https://docs.rubocop.org/rubocop-rails/cops_rails.html

Notice that several of those support "autocorrection", meaning that running RuboCop with `-a` will fix them for you:

```sh
rubocop -a
```

Let's take a glance at the `action_filter` cop real quick [here](https://github.com/rubocop/rubocop-rails/blob/master/lib/rubocop/cop/rails/action_filter.rb), but just a quick part of it:

```ruby
def check_method_node(node)
  method_name = node.method_name
  return unless bad_methods.include?(method_name)

  message = format(MSG, prefer: preferred_method(method_name), current: method_name)

  add_offense(node.loc.selector, message: message) do |corrector|
    corrector.replace(node.loc.selector, preferred_method(node.loc.selector.source))
  end
end
```

Notice that after `add_offense` it uses `corrector.replace` to replace with a preferred method source. Not only that, but if we went over to the [specs](https://github.com/rubocop/rubocop-rails/blob/master/spec/rubocop/cop/rails/action_filter_spec.rb):

```ruby
described_class::FILTER_METHODS.each do |method|
  it "registers an offense for #{method}" do
    offenses = inspect_source("#{method} :name")
    expect(offenses.size).to eq(1)
  end
  
  # ...
```

...we can see that there are even tests for it, meaning that we can not only describe and implement transformations, but programmatically test them so we don't have to manually rerun them on our entire codebases.

That's a lot of power. Imagine with me that new versions of Rails were bundled with autocorrectors which got people 90%+ done with a Rails upgrade, just from running one more command or potentially even bundling it in the official Rails upgrade process itself.

We could dramatically reduce the potential for manual errors, and make upgrading a substantially more seamless and painless process.

The secret here is that I do not believe this is far off, and there may well be people already doing this on the Rails core team.

### Babel Transpiler

Another lesson we can and should take from Javascript is the Babel traspiler. Babel allows for the introduction of syntax before it's officially in the language, making it extremely effective for testing and experimentation of new language features. Proof-of-concepts can be more easily verified, and frequently TC-39 uses them in formal proposals.

Not only that, but the language can polyfill older versions with new features and enhancements, allowing developers to use features only present in newer versions more easily. For Javascript that's a huge deal as they have to deal with such variance in web browser support.

As it would happen, the folks behind [Ruby Next](https://github.com/ruby-next/ruby-next) have some ideas here, and have done a significant amount of work in enabling this very vision to become a reality.

They wrote quite a bit on that very topic here:

https://evilmartians.com/chronicles/ruby-next-make-all-rubies-quack-alike

...and a lot of those terms are going to look very familiar to what you've been reading already, and there's a _very_ good reason for that.

### A to B Inferred Transforms

Perhaps the most troublesome part of writing regex, and really any regular language, is getting the syntax right. The same is true of NodePatterns. Why can't we just say that we have code "A" here:

```ruby
[1, 2, 3].select { |v| v.even? }
```

...and have it figure out the syntax to go to code "B" here?:

```ruby
[1, 2, 3].select(&:even?)
```

For us as humans that seems pretty straightforward. If the block argument matches the body, and only one operation is happening directly on it, we can replace that with the shorthand block syntax.

What if we had a way to give code "A" and "B" and have Ruby find the transformations between the two?

For simple cases that algorithm might look like this:

1. Match the original syntax
2. Find similarities with the desired target syntax
3. Find what has changed
4. Identify which parts of the code moved where
5. Create matchers to capture moved parts in the original code
6. Create code to generate the target code
7. Profit

...but those are tree algorithms which are unfortunately beyond me at the moment. The implications, however, are staggering if this is pulled off. Having a meta-language that allows one to quickly generate code migration syntax would lower the barrier to entry of code migrations that can be bundled with upgrades, and also allow whole new methods of refactoring.

Perhaps I'll experiment with this more later, but at the moment it is most certainly beyond my skills. I would venture a guess that algorithms used to solve word ladders, or perhaps levenshtein/word distances, could be used here though.

### Macros

Having a method to express A to B is great even in static files, but what if such things could be done in a running program?

If ASTs were accessible in running Ruby programs, we could potentially create syntax which could rewrite syntax.

Now if you're not familiar with the idea of macros from Crystal or LISP-like languages, you might wonder why you might care. One of the primary advantages is unfolding loops, allowing algorithms to go from `O(n^2)` to `O(n)`, meaning massive performance benefits.

I'd written on this some time ago with `matchable`:

/writing/2021/02/01/matchable-class-level-pattern-matching-macros-explained-32df/

The particularly relevant part is replacing the idea of `public_send` with a directly inlined code-path:

```ruby
valid_keys.each do |key|
  deconstructed_values[key] = ${key}
end

deconstructed_values
```

...as `public_send` is slow compared to directly calling a method. If taken to logical extremes one could not only inline the actual method call, but extract the method code and interpolate it directly into such a method.

There are already some techniques capable of doing just this, by combining Parser with [Unparser](https://github.com/mbj/unparser), but of course such things can only be done on Ruby files read in rather than in a REPL session which is where a lot more fun could happen.

A live AST could really make a very interesting future here.

## Wrapping Up

Now you might have noticed something particularly interesting with this article: Almost all of these items are either not that far off, or are already being used in production by several major players in the Ruby ecosystem.

The truth is the future has already been coming, and perhaps our issues are not as much around tooling, but in making the tooling more accessible and well understood to our community.

If this is combined with more official support from the Ruby core team, especially around the Whitequark and RuboCop parsers, I believe we'll take a great step forward. The challenge now is documentation, education, advocacy, and support.

I believe all of those are very possible.
