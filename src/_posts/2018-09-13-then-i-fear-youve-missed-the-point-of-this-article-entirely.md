---
layout: "post"
title: "Then I fear you’ve missed the point of this article entirely."
date: "2018-09-13"
categories: []
tags: []
description: ""
---

Then I fear you’ve missed the point of this article entirely.
      * {
        font-family: Georgia, Cambria, "Times New Roman", Times, serif;
      }
      html, body {
        margin: 0;
        padding: 0;
      }
      h1 {
        font-size: 50px;
        margin-bottom: 17px;
        color: #333;
      }
      h2 {
        font-size: 24px;
        line-height: 1.6;
        margin: 30px 0 0 0;
        margin-bottom: 18px;
        margin-top: 33px;
        color: #333;
      }
      h3 {
        font-size: 30px;
        margin: 10px 0 20px 0;
        color: #333;
      }
      header {
        width: 640px;
        margin: auto;
      }
      section {
        width: 640px;
        margin: auto;
      }
      section p {
        margin-bottom: 27px;
        font-size: 20px;
        line-height: 1.6;
        color: #333;
      }
      section img {
        max-width: 640px;
      }
      footer {
        padding: 0 20px;
        margin: 50px 0;
        text-align: center;
        font-size: 12px;
      }
      .aspectRatioPlaceholder {
        max-width: auto !important;
        max-height: auto !important;
      }
      .aspectRatioPlaceholder-fill {
        padding-bottom: 0 !important;
      }
      header,
      section[data-field=subtitle],
      section[data-field=description] {
        display: none;
      }
      

# Then I fear you’ve missed the point of this article entirely.

What I really mean

Then I fear you’ve missed the point of this article entirely.

### What I really mean

> “So what you really mean here is lazy evaluation enumerators?”I do not. There is a difference between the two, and there is a performance penalty incurred from laziness. I would recommend watching the original Transducers talk here:

### No Need

> “No need for all of the complicated custom code that is given in this article.”You’ve missed the entire point of the article. Among the assumptions are:

This article was meant to challenge laziness — It’s not, it’s a translation of a Javascript article. That said, I’ll get into this shortly.This article is meant as a recommended pattern — It’s not, it’s meant to explore a concept space.Future articles on this subject were meant to dive more deeply into this, but for now we’ll start with some overview topics.

### Laziness vs Transduction

Now insofar as the assertion that laziness is the same, that’s not accurate.

In Javascript especially we notice a large performance gain while using them:

[Transducers.js Round 2 with BenchmarksA few weeks ago I released my transducers library and explained the algorithm behind it. It's a wonderfully simple…jlongster.com](https://jlongster.com/Transducers.js-Round-2-with-Benchmarks)[](https://jlongster.com/Transducers.js-Round-2-with-Benchmarks)There would have to be further research in Ruby to justify their use, but again, laziness is not the same.

### Complications

> “In ruby, if what you’re doing looks complicated, you’re probably doing it wrong.”While this is accurate, it comes across as incredibly condescending when given as a footer to a comment. I would caution against use of such phrasing as it’s likely to come across as such.

It should be noted that there’s a difference of conceptual exploration and “go do this in your code today” type of articles. If we shy away from the former in service of the latter, we do the language and ourselves a great disservice.

The point of articles like this is to learn and expand knowledge of concepts we may not be immediately familiar with in Ruby.


