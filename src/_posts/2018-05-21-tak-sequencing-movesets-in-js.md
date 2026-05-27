---
layout: "post"
title: "Tak — Sequencing Movesets in JS"
date: "2018-05-21"
categories: []
tags: []
description: ""
---

One of my more favorite pastimes over the last few years has been Tak, from the folks over at Cheapass Games and Elodin Enterprises. It really is a beautiful game, and it presents several fun problems in programming variants of it as well.

I will warn you that it may be dense to non-Tak players, but the rules are mentioned below. This focuses less on the “how” and more on the “what” and how it can be leveraged to create Tak clients.

In this post we’re going to go over what constitutes a move in-game, and how to represent it as a series of functional transformations to a board state.

Most of the code represented is already available in OpenTak/PTN:
[**OpenTak/ptn**
*ptn - PlayTak PTN Utility*github.com](https://github.com/OpenTak/ptn)

## What are the rules of Tak?

We’ll leave that one to the game maker himself, James Earnest:

<center><iframe width="560" height="315" src="https://www.youtube.com/embed/iEXkpS-Q9dI" frameborder="0" allowfullscreen></iframe></center>

The rules themselves are available in PDF form here:

<iframe src="https://medium.com/media/1e7de4af5cf0f9f22b6e79c02bed92ad" frameborder=0></iframe>

**If you do not understand the game of Tak, this article will be very difficult to follow.**

## What are we focusing on today?

So given the game rules, what exactly are we focusing on? We’re going to define what it means to make a move.

The constraints we have to deal with are that moves should be applied as a sequence of actions that can be undone as individual actions as well.

What does that mean?

If we were to place a piece at A1, we should be able to undo it by picking it back up.

## Expressing a move

There are currently two major ways to represent a move in Tak, Kakaburra Tak Notation (TSN or KTN) and PlayTak Notation (PTN). For this, we’ll be focusing on PTN.

In Tak there are two types of moves, a placement and a movement. Only one can be done in a turn.

**Placement**

Let’s take a look at a placement first:

    a2

This literally means place a single flat piece at a2.

A wall being placed will have a prefix of S for Standing Stone. A capstone being placed will have a prefix of C for capstone, like such:

    Sa2
    Ca2

**Movement**

Movement is represented as a number of pieces, a location to move from, a direction, and a series of “drops”:

    3a3>12

This would indicate that we pick up three pieces from the square a3 and move them to the right (>) leaving one piece on b3 and two pieces on c3.

The directions are + (up), - (down), < (left), > (right).

In an enhanced version of PTN, there’s also the splat (*) which is used to indicate a capstone smashing a wall. This is to make a move easier to undo:

    2a2>11*

Without that extra notation it becomes difficult to represent moves as a transformation on the current board, as we’d have to tie ourselves to its current state to know when a wall was smashed or replay up to that same point.

## OpenTak Move Sequences

Now the fun part of this problem is expressing it as a series of transformations to the current state of the board without tying it down to board mutations.

Why would we care about that? Well a move is, strictly speaking, a series of sub-moves that comprise an entire move. When a stack is moved, we’re distributing pieces and have an intermediate state to contend with.

If a player misclicks and wants to step backwards that becomes exceedingly difficult in a more imperative mutation strategy. It also makes move validation a royal pain that gets tightly coupled to the board state.

This spawned the idea for the OpenTak Move Sequence. It takes a series of actions done by the player and represents them as a series of pushes and pops from board positions:

    const ptn = Ptn.parse('3c3>111');
    ptn.toMoveset();
    
    // [{
    //   action: 'pop', count: 3, x: 2, y: 2
    // }, {
    //   action: 'push', count: 1, x: 3, y: 2
    // }, {
    //   action: 'push', count: 1, x: 4, y: 2
    // }, {
    //   action: 'push', count: 1, x: 5, y: 2
    // }]

In this we can represent a movement as popping three pieces from c3, and the following stack drops as increments on the position with push actions. Here’s the kicker though: It’s reversable.

## Reversing a Move

By taking a moveset, reversing it and swapping pop and push, we’ve undone the move:

    // [{
    //   action: 'pop', count: 1, x: 5, y: 2
    // }, {
    //   action: 'pop', count: 1, x: 4, y: 2
    // }, {
    //   action: 'pop', count: 1, x: 3, y: 2
    // }, {
    //   action: 'push', count: 3, x: 2, y: 2 
    // }]

It also means that we can get rid of the end of a moveset to “undo” an action as well.

## Timing and Meta Information

If we wanted, we could also inject timing information into the notation:

    {move: "start", player: "white", time: (timestamp)},
    ...
    {move: "end", time: (timestamp)},

…or even potentially some meta-information like undos:

    {move: "undo", time: (timestamp)}

and treat them as a series of macros that expand into both an undo moveset and a marker to indicate an undo was done. This allows us to capture more information about the game as it progresses, as well as being able to replay it true to time.

Since these are transformations and not necessarily absolute mutations, we could treat the timestamps instead as milliseconds since last check. That’d allow us to play the game back faster or slower, capturing moments of indecision or decisive killing blows.

## Creating a Move

That works fine for move sequences already made, but it also affords us some nice options for making a move in the first place.

We can indicate through OTMS the implied direction of a move given the first stack distribution:

    [{
      action: 'pop', count: 3, x: 2, y: 2
    }, {
      action: 'push', count: 1, x: 3, y: 2
    }]

In this case we know that we have two remaining pieces to play. If the player clicked on (3, 3) we’d also be able to tell that it’s no longer “going right” and counts as an invalid move.

We can also tell that this move isn’t completed yet because not all of the pieces present have been distributed.

Given that, if we had a board function that took in the action we wanted to take and it told us there was a wall in the way, we could definitively say whether or not it’s a valid move without the moveset even really needing to know of the board.

## Smashing!

As far as smashing, we can also add a bit of meta to the notation again:

    action: "push", count: 1, smash: true

Now when we undo a move we can put the wall back where it was as well.

## Server Interop

Movesets can also be represented in PTN (KTN coming soon), which means we can compress the actions into something we can send to a Tak server and have it recognize what was done.

This also means that the client can receive PTN or KTN from the server and be able to break it apart into component actions to do to the board.

## Client Interop

Movesets represent counts, locations, and other transformations to the actual board itself. This means that by tying into this implementation you’ve effectively got a series of keyframes by which to animate against, as well as undo against should you need to.

It’s agnostic to UI layer, meaning that React, Vue, or whatever else could easily leverage it.

## The TODOs

Currently OpenTak does not support all of this behavior. KTN and creating movesets from actions are not currently supported, but will be within the next few months.

This article is entirely musing on the nature of what it means to make a move, and how it can be completely agnostic to both backend and frontend technologies.

## Wrapping Up

If you don’t know Tak, you’re probably quite confused. This was a more advanced article on implementation details. There will be articles in the future on tokenization of PTN, creating movesets from it, and other tasks that led into this.

If you’re curious about this type of thinking, definitely read more into Functional Game Programming:
[**Purely Functional Retrogames, Part 1**
*That was a long time ago, and I've spent enough time with functional languages to have figured out how to implement…*prog21.dadgum.com](http://prog21.dadgum.com/23.html)
