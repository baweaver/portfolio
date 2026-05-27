---
layout: "post"
title: "Functional Programming in Ruby – State"
series: "functional-programming-ruby"
date: "2021-08-01"
categories: ["ruby", "functional"]
tags: ["ruby", "functional"]
description: "Ruby is, by nature, an Object Oriented language. It also takes a lot of hints from Functional..."
---

Ruby is, by nature, an Object Oriented language. It also takes a lot of hints from Functional languages like Lisp.

Contrary to popular opinion, Functional Programming is not an opposite pole on the spectrum. It’s another way of thinking about the same problems that can be very beneficial to Ruby programmers.

Truth be told, you’re probably already using a lot of Functional concepts. You don’t have to get all the way to Haskell, Scala, or other languages to get the benefits either.

The purpose of this series is to cover Functional Programming in a more pragmatic light as it pertains to Ruby programmers. That means that some concepts will not be rigorous proofs or truly pure ivory FP, and that’s fine.

We’ll focus on examples you can use to make your programs better today.

With that, let’s take a look at our first subject: State.

> This series is a partial rewrite and update of [my own series on Medium on Functional Programming](/writing/2021/08/01/functional-programming-in-ruby-state-13p2/). It has been modernized and updated a bit.

## Functional Programming and State

One of the prime concepts of Functional Programming is immutable state. In Ruby it may not be entirely practical to forego it altogether, but the concept is still exceptionally valuable to us.

By foregoing state, we make our applications easier to reason about and test. The secret is that you don’t entirely need to forego it to get some of these benefits, and that's what we need to keep in mind with Ruby: there are always tradeoffs.

### Defining State

So what is state exactly? State is the data that flows through your program, and the concept of immutable state means that once it’s set it’s set. No changing it.

```ruby
x = 5
x += 2 # Mutation of state!
```

That especially applies to methods:

```ruby
def remove(array, item)
  array.reject! { |v| v == item }
end

array = [1,2,3]
remove(array, 1)
# => [2, 3]

array
# => [2, 3]
```

By performing that action, we’ve mutated the array we passed in. Now imagine we have two or three more functions which also mutate the array and we get into a bit of an issue. In general it's not great to mutate data that's passed into your function.

A pure function is one that does not mutate its inputs:

```ruby
def remove(array, item)
  array.reject { |v| v == item }
end

array = [1,2,3]
remove(array, 1)
# => [2, 3]

array
# => [1, 2, 3]
```

It’s slower, but it’s much easier to predict that this is going to return us a new array. Every time I give it input A, it gives me back result B.

### Has That Ever Really Happened?

Problem is, one can preach all day on the merits of pure functions, but until you find yourself in a situation where it bites you the benefits may not be readily apparent.

There was one time in Javascript where I’d used `reverse` to test the output of a game board. It would look fine, but when I added one more `reverse` to it all of my tests broke!

What gives?

Well, as it turned out the `reverse` function was mutating my board.

It took me longer than I want to admit here how long it took me to realize this was happening, but mutation can have subtle cascading effects on your program unless you keep it under control.

That’s the secret though, you don’t have to exclusively avoid it, you just need to manage it in such a way that it’s very clear when and where mutations happen.

> In Ruby, frequently state mutations are indicated with `!` as a suffix. Not always, though, because methods like `concat` break those rules so keep an eye out.

### Isolate State

One method of dealing with state is to keep it in the box. A pure function might look something like this:

```ruby
def add(a, b)
  a + b
end
```

When given the same inputs, it will *always* give us back the same outputs. That’s handy, but there are ways to hide tricks from it.

```ruby
def count_by(array, &fn)
  array.each_with_object(Hash.new(0)) { |v, h|
    h[fn.call(v)] += 1
  }
end

count_by([1,2,3], &:even?)
# => {false=>2, true=>1}
```

> **Note**: Newer versions of Ruby have the `tally` function which would be used like this to get a similar result: `[1, 2, 3].map(&:even?).tally`

Strictly speaking, we’re mutating that hash for each and every value in the array. Not so strictly speaking, when given the same input we get back the exact same output.

Does that make it functionally pure? No. What we’ve done here is created isolated state that’s only present inside our function. Nothing on the outside knows about what we’re doing to the hash inside the function, and in Ruby this is an acceptable compromise.

The problem is though, isolate state still requires that functions do one and only one thing.

### Single Responsibility and IO State

Functions should do one and only one thing.

I’ve seen this type of pattern very commonly in newer programmers code:

```ruby
class RubyClub
  attr_reader :members
  
  def initialize
    @members = []
  end
  
  def add_member
    print "Member name: "
    member = gets.chomp
    @members << member
    puts "Added member!"
  end
end
```

The problem here is that we’re conflating a lot of things in one function:

* Asking a user for a member name
* Getting that name
* Adding a member
* Notifying the user we added a member

That’s not the concern of our class, it only needs to know how to add a member, anything else is outside the scope of that method.

At first this seems harmless, as you’re only really getting input and outputting at the end. The problems we run into are that `gets` is going to pause the test, waiting for input, and `puts` is going to return `nil` afterwards.

How would we test such a thing?

```ruby
describe '#add_member' do
  before do
    $stdin = StringIO.new("Havenwood\n")
  end
  
  after do
    $stdin = STDIN
  end
  
  it 'adds a member' do
    ruby_club = RubyClub.new
    ruby_club.add_member
    expect(ruby_club.members).to eq(['Havenwood'])
  end
end
```

That’s a lot of code. We have to intercept `STDIN` (standard input) to make it work which makes our test code a lot harder to read as well.

Take a look at a more focused implementation, the only concern it has is that it gets a new member as input and returns all the members as output.

```ruby
class RubyClub
  attr_reader :members
  
  def initialize
    @members = []
  end
  
  def add_member(member)
    @members << member
  end
end
```

All we need to test now is this:

```ruby
describe '#add_member' do
  it 'adds a member' do
    ruby_club = RubyClub.new
    expect(ruby_club.add_member('Havenwood')).to eq(['Havenwood'])
  end
end
```

It’s abstracted from the concern of dealing with `IO` (`puts`, `gets`), another form of state.

Now let’s say that your Ruby Club has to also run with a CLI, or maybe load results from a file. How do you refactor it to work? Your current class is conflated with the idea that it has to get input and deal with output.

This adds up to very brittle tests and code that are going to give you problems over time.

### Static State

Another common pattern is to abstract data into constants. This alone isn’t a bad idea, but can result in your classes and methods being effectively hardcoded to work in one way.

Consider the following:

```ruby
class SampleLoader
  SAMPLES_DIR = '/samples/ruby_samples'
  
  def initialize
    @loaded_samples = {}
  end
  
  def load_sample(name)
    @loaded_samples[name] ||= File.read("#{SAMPLES_DIR}/#{name}")
  end
end
```

It’s great as long as you’re only concerned with that specific directory, but what if we need to make a sample loader for `elixir_samples` or `rust_samples`? We have a problem. Our constant has become a piece of static state we cannot change.

The solution is to use an idea called injection. We inject the prerequisite knowledge into the class instead of hardcoding the value in a constant:

```ruby
class SampleLoader
  def initialize(base_path)
    @base_path = base_path
    @loaded_samples = {}
  end
  
  def load_sample(name)
    @loaded_samples[name] ||= File.read("#{@base_path}/#{name}")
  end
end
```

Now our sample loader really doesn’t care where it gets samples from, as long as that file exists somewhere on the disk. Granted there are potential risks with caching as well, but that’s an exercise left to the reader.

A way to cheat this is by using default values, set to a constant, but for some this may be a bit to implicit. Use wisely:

```ruby
class SampleLoader
  SAMPLES_DIR = '/samples/ruby_samples'
  
  def initialize(base_path: SAMPLES_DIR)
    @base_path = base_path
    @loaded_samples = {}
  end
  
  def load_sample(name)
    @loaded_samples[name] ||= File.read("#{@base_path}/#{name}")
  end
end
```

### IO State — Reading Files

Let’s say your Ruby Club has an idea of loading members. We remembered to not statically code paths this time:

```ruby
class RubyClub
  def initialize
    @members = []
  end
  
  def add_member(member)
    @members << member
  end
  
  def load_members(path)
    JSON.parse(File.read(path)).each do |m|
      @members << m
    end
  end
end
```

The problem this round is that we’re relying on the fact that the members file is not only a file, but also in a `JSON` format. It makes our loader very inflexible.

We’ve become entangled in another type of IO state: we’re too concerned with how we load data into our club.

Say you wanted to switch it out with a database like `SQLite`, or maybe even just use `YAML ` instead. That’s a very hard task with the code like it is.

Some solutions to this problem I see from newer developers are to make multiple “loaders” to deal with different types of inputs. What if it’s none of the concern of our club in the first place?

If we extract the entire concept of loading members, we could have code like this instead:

```ruby
class RubyClub
  attr_reader :members
  
  def initialize(members = [])
    @members = members
  end
  
  def add_members(*members)
    @members.concat(members)
  end
end

new_members = YAML.load(File.read('data.yml'))
RubyClub.new(new_members)
```

### Wait, isn’t this just Separation of Concerns?

The fun thing about OO and FP is that a lot of the same concepts can apply, they just tend to have different names. They may not be exact overlaps, but a lot of what you learn from a Functional language may feel very familiar from best practices in a more Imperative style language.

In a lot of ways, keeping state under control is an exercise in separation of concerns. Pure functions coupled with this can make exceptionally flexible and robust code that is easier to test, reason about, and extend.

A common point of confusion is that Functional Programming is an entirely new and independent paradigm from Object Oriented Programming, when in fact they share quite a few ideas, and often times are more complimentary than some would like to admit.

## Wrapping Up

State in Ruby may not be entirely pure, but by keeping it under control your programs will be substantially easier to work with later. In programming, that’s everything.

You’ll be reading and upgrading code far more than you’re outright writing it, so the more you do to write it flexibly from the start the easier it will be to read and work with later on.

As I mentioned earlier, this course will be more focused on pragmatic usages of Functional Programming as they relate to Ruby. We could focus on an entire derived Lambda Calculus scheme and make a truly pure program, but it would be slow and incredibly tedious.

That said, it’s also fun to play with on occasion just to see how it works. If that’s of interest this is a great book on the subject:

[Understanding Computation](http://shop.oreilly.com/product/0636920025481.do)

If you want to keep exploring that rabbit hole, Raganwald does a lot to delight here:

[Kestrels, Quirky Birds, and Hopeless Egocentricity](https://leanpub.com/combinators)

As always, enjoy!
