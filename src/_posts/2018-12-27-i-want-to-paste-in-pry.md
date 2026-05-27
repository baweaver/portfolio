---
layout: "post"
title: "I want to paste in Pry!"
date: "2018-12-27"
categories: []
tags: ["ruby", "programming"]
description: "Tips for pasting multi-line code into Pry, including using edit and pbpaste on Mac."
---

If you’ve used Pry before, you know that pasting things into it may not quite work as expected with long segments of code.

For a while, this was the commonly accepted solution:

```ruby
> edit
```

That would drop you into your editor (set in $EDITOR), and allow you to code to your hearts content. Anything you save before closing gets thrown into Pry line-by-line.

Now that’s really quite handy, but it brings up an interesting thought: How does it evaluate each line of that file sequentially? Can we perhaps reuse this functionality elsewhere?

Why yes, yes we can.

## **Mac OSX**

Granted that I’m currently on a Mac, I was mostly concerned with getting this to work on there first. I may well bring it to other platforms later, but be aware this is partially mac focused.

Combine that with being on TMUX which adds a layer of potential complexity to this.

## Copying and Pasting in TMUX

Most of the information in this section was originally from the following article:
[**Making the clipboard work between iTerm2, tmux, vim and OS X.**
*Getting copying and pasting to behave sanely when working with the terminal has been a constant struggle, probably ever…*evertpot.com](https://evertpot.com/osx-tmux-vim-copy-paste-clipboard/)

Though there have been a number of changes to TMUX configurations since then, so consider this an amended version for more modern configurations.

bind-key has changed a bit:
[**invalid or unknown command: `bind-key -t vi-copy ....` · Issue #754 · tmux/tmux**
*It looks like my attempts to bind keys in my .tmux.conf with vi-copy are now failing: /Users/kevin/.tmux.conf:25…*github.com](https://github.com/tmux/tmux/issues/754)

Particularly pay attention to this comment:
[**invalid or unknown command: `bind-key -t vi-copy ....` · Issue #754 · tmux/tmux**
*It looks like my attempts to bind keys in my .tmux.conf with vi-copy are now failing: /Users/kevin/.tmux.conf:25…*github.com](https://github.com/tmux/tmux/issues/754#issuecomment-297452143)

That means that everything in the above article works except for the final TMUX configuration, which becomes something more like this:

```ruby
# Copy-paste integration
set-option -g default-command "reattach-to-user-namespace -l bash"

# Use vim keybindings in copy mode
setw -g mode-keys vi

# Setup 'v' to begin selection as in Vim
bind-key -T copy-mode-vim v begin-selection
bind-key -T copy-mode-vim y copy-pipe "reattach-to-user-namespace pbcopy"

# Update default binding of `Enter` to also use copy-pipe
unbind -T copy-mode-vim Enter
bind-key -T copy-mode-vim Enter copy-pipe "reattach-to-user-namespace pbcopy"

# Bind ']' to use pbpaste
bind ] run "reattach-to-user-namespace pbpaste | tmux load-buffer - && tmux paste-buffer"
```

This allows TMUX to be able to interface with pbcopy and pbpaste to access the system clipboard.

## Pry Configuration

To make this more accessible in Pry, we’re going to want to add a few things to our .pryrc file:
[**Ruby pbcopy and pbpaste (Example)**
*A protip by weppos about shell, clipboard, irb, pbcopy, pbpaste, and ruby.*coderwall.com](https://coderwall.com/p/qp2aha/ruby-pbcopy-and-pbpaste)

```ruby
def pbcopy(input)
  str = input.to_s
  IO.popen('pbcopy', 'w') { |f| f << str }
  str
end

def pbpaste
  `pbpaste`
end

Pry::Commands.block_command 'paste_eval', "Pastes from the clipboard then evals it in the context of Pry" do
  _pry_.input = StringIO.new(pbpaste)
end
```

The last line gives us a command to be able to use in pry called paste_eval.

Now all you have to do is copy a piece of code, type in paste_eval, and it’ll execute in a new IO buffer line by line for you.

## Wrapup

Granted this is more of a workaround than anything. Ideally I get something running in VSCode or another editor to have a live REPL running like with Javascript or like Light Table and Clojure.

At the moment it doesn’t quite annoy me enough to bother, so here we are.

Hopefully someone out there finds this handy!
