---
layout: "post"
title: "Let's Read – Polished Ruby Programming – Ch 3.2 Instance Variables"
series: "lets-read-polished-ruby"
date: "2021-09-28"
tags: ["ruby", "rails", "books"]
---

[Polished Ruby Programming](https://www.packtpub.com/product/polished-ruby-programming/9781801072724) is a recent release by [Jeremy Evans](https://twitter.com/jeremyevans0), a well known Rubyist working on the Ruby core team, Roda, Sequel, and several other projects. Knowing Jeremy and his experience this was an instant buy for me, and I look forward to what we learn in this book.

You can find the book here:

https://www.packtpub.com/product/polished-ruby-programming/9781801072724

This review, like other "Let's Read" series in the past, will go through each of the chapters individually and will add commentary, additional notes, and general thoughts on the content. Do remember books are limited in how much information they can cram on a page, and they can't cover everything.

With that said let's go ahead and get started.

## Chapter 3 – Proper Variable Usage – Instance Variables

The third chapter covers the following topics:

* Using Ruby's favorite variable type – the local variable
  * Increasing performance by adding local variables
  * Avoiding unsafe optimizations
  * Handling scope gate issues
  * Naming considerations with local variables
* Learning how best to use instance variables
  * Increasing performance with instance variables
  * Handling scope issues with instance variables
  * Naming considerations for instance variables
* Understanding how constants are just a type of variable
  * Handling scope issues with constants
  * Visibility differences between constants and class instance variables
  * Naming considerations with constants
* Replacing class variables
  * Replacing class variables with constants
  * Replacing class variables with class instance variables using the superclass lookup approach
  * Replacing class variables with class instance variables using the copy to subclass approach
* Avoiding global variables, most of the time

We'll be covering instance variables in this section.

#### Increasing performance with instance variables

As with the section on local variables you can also increase performance using instance variables, but primarily through caching techniques. The book mentions this in terms of idempotency and storing the results of calculations, but personally I prefer cache as a more approachable term.

It then goes to this example:

```ruby
LineItem = Struct.new(:name, :price, :quantity)

class Invoice
  def initialize(line_items, tax_rate)
    @line_items = line_items
    @tax_rate = tax_rate
  end

  def total_tax
    @tax_rate * @line_items.sum do |item|
      item.price * item.quantity
    end
  end
end
```

It mentions that if `total_tax` is only called once then there's not much value in caching, but if it gets called multiple times it could be worthwhile as the next example shows:

```ruby
def total_tax
  @total_tax ||= @tax_rate * @line_items.sum do |item|
    item.price * item.quantity
  end
end
```

Before we continue with the book you'll notice common convention here is to use the name of the method as the name of the instance variable. I've also seen `@_total_tax` as an indication that it's a "private" instance variable rather than one that should be freely accessed, but that comes down to preference.

The book goes on to mention cases where `||=` won't work, which is a very useful topic as I've seen that trip people a lot in production code. Those cases are around `false` and `nil`, and cases where those are legitimate return values you want to remember versus ones you want to override. The book mentions `defined?` as a way around this with a guard statement:

```ruby
def total_tax
  return @total_tax if defined?(@total_tax)

  @total_tax = @tax_rate * @line_items.sum do |item|
    item.price * item.quantity
  end
end
```

Now for that particular case it won't make sense for that above concern, but it does prevent that `false` or `nil` issue when it comes up for other caching concerns.

The book also mentions here that `defined?` is more easily optimized by Ruby over `instance_variable_defined?`, as the former is a keyword rather than a Ruby method.

The other case where that caching technique will break is around frozen classes, which may be rarer. The books solution is as follows:

```ruby
LineItem = Struct.new(:name, :price, :quantity)

class Invoice
  def initialize(line_items, tax_rate)
    @line_items = line_items
    @tax_rate = tax_rate
    @cache = {}

    freeze
  end

  def total_tax
    @cache[:total_tax] ||= @tax_rate * @line_items.sum do |item|
      item.price * item.quantity
    end
  end
end
```

Personally I find this against the spirit of freezing as you're modifying the internal `Hash`. If someone was going for purity here they'd likely return a new frozen instance with that variable pre-populated.

As with the previous example set this one is also weak to `false` or `nil` values which can be combated as such with `key?` in the place of `defined?`:

```ruby
def total_tax
  return @cache[:total_tax] if @cache.key?(:total_tax)

  @cache[:total_tax] = @tax_rate * @line_items.sum do |item|
    item.price * item.quantity
  end
end
```

The book goes on to mention that when dealing with instance variables you do not have control over them as completely as you might with a local. What's to stop someone from modifying `@tax_rate` somewhere else? Not much in Ruby.

It also mentions that data being passed in could also be changed which can cause issues with caching:

```ruby
line_items = [LineItem.new('Foo', 3.5r, 10)]

invoice = Invoice.new(line_items, 0.095r)

tax_was = invoice.total_tax

line_items << LineItem.new('Bar', 4.2r, 10)

tax_is = invoice.total_tax
```

...which is a great point to make, as some get too eager in caching and don't consider potential legitimate cases where values can change. In this particular one it's not the intent of the program, so it's more a negative thing.

The book mentions getting around this by getting a cleanly duplicated copy of the line items:

```ruby
def initialize(line_items, tax_rate)
  @line_items = line_items.dup
  @tax_rate = tax_rate
  @cache = {}

  freeze
end
```

...or using `line_items.freeze` instead. Or even just using the best of both by using `line_items.dup.freeze` to more completely guard against shenanigans.

Ah, speaking of shenanigans, someone could modify the line items themselves as the book mentions:

```ruby
line_items = [LineItem.new('Foo', 3.5r, 10)]
invoice = Invoice.new(line_items, 0.095r)
tax_was = invoice.total_tax

line_items.first.quantity = 100

tax_is = invoice.total_tax
```

...in which the solution is to make sure line items are also frozen:

```ruby
LineItem = Struct.new(:name, :price, :quantity) do
  def initialize(...)
    super

    freeze
  end
end
```

...or to freeze them in the `Invoice#initialize` method:

```ruby
def initialize(line_items, tax_rate)
  @line_items = line_items.map do |item|
    item.dup.freeze
  end.freeze

  @tax_rate = tax_rate
  @cache = {}

  freeze
end
```

Turns out caching is hard, frozen objects can make it somewhat easier, but a particularly determined person can find a way either explicitly or inadvertently. It's definitely good to cover the myriad of concerns that can go wrong in terms of caching, as it's a very hard problem in all of programming in general.

#### Handling scope issues with instance variables

Unlike local variables instance variables are scoped to the receiver, or self, as the book mentions. For me that's always meant that an instance variable is fetched from the context it's evaluated in, but for most folks the concern stops that it's seen in the scope of the current instance of a class they're working with.

Why the extra complexity there? Well there are some parts of Ruby that can change the context being evaluated like `define_method`, `Class.new`, `Module.new`, and a few others the book doesn't get into like `instance_eval` and friends where you can play with the `binding`.

The book mentions that instance variables can be in a different context, and the example it gives is a block passed to something you don't own:

```ruby
class Invoice
  def line_item_taxes
    @line_items.map do |item|
      @tax_rate * item.price * item.quantity
    end
  end
end
```

Now for this one `map` isn't doing anything particularly odd, but that's assuming as the book says that `@line_items` is an `Array` containing `LineItem` objects which happen to respond to certain methods. Usually, a fairly safe assumption, but the book goes into when it might not be:

```ruby
class LineItemList < Array
  def initialize(*line_items)
    super(line_items.map do |name, price, quantity|
      LineItem.new(name, price, quantity)
    end)
  end

  def map(&block)
    super do |item|
      item.instance_eval(&block)
    end
  end
end

Invoice.new(LineItemList.new(['Foo', 3.5r, 10]), 0.095r)
```

The book goes into the reasoning you might want to do this, but breaking down the code for a moment first:

```ruby
super(line_items.map do |name, price, quantity|
  LineItem.new(name, price, quantity)
end)

# Potential variations:
line_items.map { |*args| LineItem.new(*args) }
line_items.map(&LineItem.method(:new))
```

This will convert any item passed in into a `LineItem` and forward it on to the `Array` constructor.

The next part on `map` is a bit more interesting:

```ruby
def map(&block)
  super do |item|
    item.instance_eval(&block)
  end
end
```

It'll forward to the underlying `map`, but evaluates the block not in the context of the class, but in the context of the item itself. Why? Well the book gets into that.

The reasons provided are:

1. **Ease of Initialization** - Faster to create items via `Array` than manually constructing each one.
2. **Ease of Access** - Provides direct access to methods in the instance
3. **Less Verbosity** - Allows omission of `item`

For point 3 the following code is provided:

```ruby
line_item_list.map do
  price * quantity
end

# Versus the more verbose:
line_item_list.map do |item|
  item.price * item.quantity
end
```

The book goes on to mention that this breaks the above example:

```ruby
class Invoice
  def line_item_taxes
    @line_items.map do |item|
      @tax_rate * item.price * item.quantity
    end
  end
end
```

`@tax_rate` is no longer visible. There are workarounds with local variables like so:

```ruby
class Invoice
  def line_item_taxes
    tax_rate = @tax_rate
    @line_items.map do |item|
      tax_rate * item.price * item.quantity
    end
  end
end
```

But as the book mentions, and I would agree, you're deviating far enough from common-use Ruby to be obtuse. The brevity you gain comes at the loss of intuitive clarity in your code, and should give a developer pause before trying such solutions.

A small amount of verbosity is a very fair trade for making code easier to understand, work with, and intuitively grasp its underlying structures. A good rule to keep in mind is to do the least surprising thing possible, because one day you may very well be the one surprised by your own code.

#### Naming considerations for instance variables

As with the previous section there really aren't too many differences in naming conventions between instance and local variables. They should be `@snake_cased`, and prefer ASCII characters. The book mentions some potential exceptions around mirroring `@ClassNames` and `@ModuleNames`, but I would almost discourage that myself in favor of remaining consistent with `@snake_case`.

The benefit of instance variables, as mentioned, is that they come with inherent context. That means you can name them a bit more loosely than you might a local variable. A few examples are provided:

```ruby
# Too long
@transaction_processing_system_report = TransactionProcessingSystemReport.new

# Better
@tps_report = TransactionProcessingSystemReport.new

# Best, if only one report is present
@report = TransactionProcessingSystemReport.new
```

### Wrap Up

With that we're finished up the section on instance variables.

The next section will cover constants.
