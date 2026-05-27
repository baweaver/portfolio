---
layout: "post"
title: "Triple Equals Black Magic"
date: "2017-10-16"
categories: []
tags: []
description: ""
---

For the most part, === is either ignored or used in the background of case statements. Now there are several articles detailing this, but the question is what all *can *we use it for?

## What is Triple Equal?

In the default case, triple equal is just an alias for double equal. The brilliance comes in when other classes override it for their own behavior. A few examples of this:

**Ranges**

    (1..10) === 1

For a range, triple equal is an alias for includes?.

Now, a note on ranges, they do a lot of black magic themselves. That’s the subject of a whole new post, but for now a few fun ones that you can try out:

    'a'..'z'
    '1.0.0'..'2.0.0'

**Regex**

    /abc/ === 'abcdef'

For regex, it’s match .

**Classes**

    String === 'foo'

For a class, we get is_a?

**Procs**

    -> a { a > 5 } === 6

For a proc, we get call. This one is especially interesting for later.

**IPAddr**

    IPAddr.new('10.0.0.0/8') === '10.0.0.1'

Yep, you read that right. IPAddr overrides triple equal to be subnet inclusion, and is even kind enough to coerce whatever you give it into an IPAddr for comparison. SysAdmins will particularly love this one.

## Just in Case

Now that we have a few cases of what it does, the prime usage is the case statement in Ruby:

    case '10.0.0.1'
    when IPAddr.new('10.0.0.0/8') then 'wired connection'
    when IPAddr.new('192.168.1.0/8') then 'wireless connection'
    else 'unknown connection'
    end

But that’s boring. Surely we can do more with this magical device can’t we? We get duck typing for a reason, why not put it to some use!

## Querying

Most of you have seen ActiveRecord before, like how we’d query against a Person model:

    Person.where(name: 'Bob', age: 10..20)

You know what’d be nice is if we could do something similar to just plain old arrays. Remember how triple equals does things with ranges and regexes and all that? Time to have some fun with it.

Let’s start our experiment with an array of hashes:

    people = [
      {name: 'Bob', age: 20},
      {name: 'Sue', age: 30},
      {name: 'Jack', age: 10},
      {name: 'Jill', age: 4},
      {name: 'Jane', age: 5}
    ]

Say we wanted to get everyone that was 20 or older. In regular Ruby we might do something like this:

    people.select { |person| person[:age] >= 20 }

Though if that had a few more conditions it starts getting a bit hairy, no? This gets to be quite annoying if we’re going through a lot of JSON, so why not borrow from ActiveRecord a bit?

    def where(list, conditions = {})
      return list if conditions.empty?

      list.select { |item|
        conditions.all? { |key, matcher| matcher === item[key] }
      }
    end

Notice how triple equal snuck in there. That means not only can we do exact equality, but we get every single one of those nice matches above as well.

## JSON Packet Dump

Say we ended up with some type of packet dump in JSON, we could query against it:

    where(packets,
      source_ip: IPAddr.new('10.0.0.0/8'),
      dest_ip:   IPAddr.new('192.168.0.0/16')
      ttl:       -> v { v > 30 }
    )
> Note though that JSON is going to give you String keys unless you tell it otherwise on parsing, so be careful there.

Not quite enough power? Remember that we have access to Proc as well, which means you could totally use composition to get some really interesting compound queries using something like Ramda in Ruby:
[**lazebny/ramda-ruby**
*ramda-ruby - Ruby port of http://ramdajs.com*github.com](https://github.com/lazebny/ramda-ruby)

Now we could get away with something nicer like this:

    where(packets,
      source_ip: IPAddr.new('10.0.0.0/8'),
      dest_ip:   IPAddr.new('192.168.0.0/16')
      ttl:       R.gt(30)
    )

There’s a lot more power there to use, but a subject for another post. Sufficient to say though, Ruby giving us a === on Proc enables some real black magic with a curried framework like Ramda.

## Objects

That’s well and good, but say that we have objects instead. Well, simple enough. We just switch out item[key] with item.public_send(key) :

    def where(list, conditions = {})
      return list if conditions.empty?

      list.select { |item|
        conditions.all? { |key, matcher|
          matcher === item.public_send(key)
        }
      }
    end

If one is feeling particularly magical, you can abuse the fact that a Ruby Hash key can be *anything* to do even worse things:

    def where(list, conditions = {})
      return list if conditions.empty?

      list.select { |item|
        conditions.all? { |key, matcher|
          matcher === item.public_send(*key)
        }
      }
    end

By exploding the key, we could get away with something like this:

    where([[1,2,3], [20,30,40]],
      [:reduce, 0, :+] => R.gt(20)
    )

Not sure how I’d practically apply that one quite yet, but it’s sure a fun thought in the mean time.

## Finishing Up

There are a lot more things you can pull off with triple equals, this is only the tip of that magic iceberg. Combined with functional composition there’s a *ton* of magic just waiting to be discovered.

Perhaps magic isn’t your thing though, case statements are still useful if not a bit more tame
