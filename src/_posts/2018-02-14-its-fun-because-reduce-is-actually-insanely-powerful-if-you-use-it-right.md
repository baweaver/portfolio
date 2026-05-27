---
layout: "post"
title: "It’s fun because reduce is actually insanely powerful if you use it right:"
date: "2018-02-14"
categories: []
tags: []
description: ""
---

It’s fun because reduce is actually insanely powerful if you use it right:
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
      

# It’s fun because reduce is actually insanely powerful if you use it right:

In fact every single Enumerable function can be implemented in terms of reduce. The Functional Programming types might notice that if you…

It’s fun because reduce is actually insanely powerful if you use it right:

[Reducing Enumerable — The BasicsOne of the lesser understood functions in Enumerable for many Rubyists is reduce . It’s just the thing we can use to…medium.com](/writing/2017/10/16/reducing-enumerable-the-basics/)[](/writing/2017/10/16/reducing-enumerable-the-basics/)In fact every single Enumerable function can be implemented in terms of reduce. The Functional Programming types might notice that if you can implement everything in terms of something that means they can be composed as well, which leads to some real fun with Transducers. Then again that’s quite the rabbit hole :)


