---
layout: "post"
title: "My Development Setup in 2026"
date: "2026-08-04"
categories: []
tags: ["tools", "workflow", "macos"]
description: "A walkthrough of my current development environment: Ghostty, MonoLisa, mise, ZSH without a framework, and why I automated the whole thing into a single script."
---

As I start to step into another new adventure I took a long hard look at my development setup on my work laptop as well as my home laptop and realized I haven't really cleaned it up in what, a decade now? It was time for some spring (or summer I guess) cleaning to get it under control and start asking hard questions about what added value and what had somehow smuggled its way across migrations over the past decade. This post explores some of my setup, why I made certain decisions, and how I'm different now than I was back then.

The tagline I had a decade ago was:

> Motto: Automate and Alias all the things! If it takes more than 5 keystrokes and you do it more than
> five times in a day, script it. No exceptions, document it and fix it.

Nowadays? I found that to be a giant waste of time, and my motto might be something more along the line of:

> Simplify: Every tool does one simple thing well, is immediately understandable by _anyone_ who uses it,
> and _just works_ without hours of setup and debugging.

I mention it later, but 10 years ago is what I would call my "smug era" whereas I would position this current era as the "just works" era. I've grown and learned a lot over the past decade, and probably by the next time I write one of these I'll have learned a lot more.

The whole thing lives in [a dotfiles repo](https://github.com/baweaver/dotfiles) and provisions a new Mac with `bin/setup`. Everything below is what that script produces.

## Terminal: Ghostty

I switched to [Ghostty](https://ghostty.org/) from iTerm2 recently, and the jury is still out on what I think of it. One thing I do like is that the config is a flat file I can check into version control:

```
theme = Catppuccin Macchiato

font-family = MonoLisa Nerd Font
font-family = FiraCode Nerd Font
font-size = 16

window-padding-x = 8
window-padding-y = 4

cursor-style = bar
cursor-style-blink = false

copy-on-select = clipboard
confirm-close-surface = false
bell = none

macos-titlebar-style = tabs
macos-option-as-alt = true
```

The `font-family` fallback chain means if MonoLisa isn't installed (it's a paid font), Ghostty falls back to FiraCode which the setup script installs automatically. Tabs as the titlebar style gives me the native macOS tab behavior without wasting vertical space on a separate tab bar. Between native tabs and splits I also don't use tmux anymore, which is one less thing to configure and maintain.

## Font: MonoLisa

I use [MonoLisa](https://www.monolisa.dev/), though I do have to warn folks it _is_ a paid font ($149 for the developer license) which raises some eyebrows. The reason why I paid it is that it is a legitimately easier to read font for me, and quite a bit better than free alternatives. I have ADHD and Autism so the letter spacing and character differentiation (especially between `0O`, `1lI`, `{}()`) makes a material difference in how quickly I can parse code, and since a vast majority of my job is _reading_ code that's pretty important.

For me, in my life, if I spend significant portions of my time on/using/wearing something I'm willing to pay very well for it. Things like my bed, shoes, chairs, coats, computers, and yes fonts. The font I read every day to do my job definitely qualifies if it makes a material difference, and to me this one does. Your mileage may vary.

The catch is it doesn't ship with Nerd Font glyphs (the icons that Spaceship prompt and various CLI tools use). My setup script handles this by patching MonoLisa with Nerd Font glyphs using Docker and the official Nerd Font patcher. If MonoLisa isn't installed, everything falls back to FiraCode Nerd Font which is free and already patched.

## Shell: ZSH without a framework

No hate towards Robby or Oh My ZSH, I'd used it for a decade or more, but with this iteration I wanted to get back to basics as much as possible so I wanted to explore outside of that world and see how things had changed over the years. Here's what I landed on so far:

- **Spaceship** for the prompt, configured to show only what I care about: directory, git, active language version, docker status, and execution time for slow commands.
- **zsh-syntax-highlighting** with the Catppuccin Macchiato theme so commands light up as I type them.
- **zsh-autosuggestions** for history-based completion in gray text.
- **fzf** with `fd` as the backend for fuzzy file/directory search.
- Three utility functions: `mkcd`, `cdl`, and `most_used`.

The shell starts near instantly and gets me the info I need.

## Version Management: mise

[mise](https://mise.jdx.dev/) replaced asdf, rbenv, nvm, and jEnv for me. One tool manages Ruby, Go, Node, Java, and Rust. The global config is four lines:

```toml
[tools]
ruby = "4.0.6"
go = "latest"
node = "latest"
java = "openjdk-21"
rust = "latest"
```

Per-project overrides live in `mise.toml` or `.ruby-version` files and mise picks them up automatically on `cd`. The activation is one line in `.zshrc`: `eval "$(mise activate zsh)"`.

Why not asdf? mise is faster (written in Rust), has better error messages, and doesn't require plugins for core languages. It does everything asdf does with less set-up, and so far it hasn't given me a 1H+ debugging session which is always a plus for me.

I notice more and more these days how little patience I have for fighting with things for hours to get them functional, so "just works" is a major value proposition for me. It's probably also why I'm using Macs now over Linux machines, but that's a whole firestorm waiting to happen.

## Editor: VS Code

Years ago I used Vim when I was in the deepest parts of my smug era, until I tried pairing with a more junior engineer who wasn't able to get anything done in it. I decided right about then to keep my editor accessible and more common to whatever job I happen to be in, back then that was Sublime and nowadays it's VSCode. I prefer my editors not invoke eternal rage in others who happen to have to use them.

The plugin support has been great, most Ruby tools function in it, and extending has been fairly straightforward.

Extensions I use heavily:

- **Ruby LSP** (Shopify) for go-to-definition, hover docs, and inline diagnostics
- **GitLens** for blame annotations and history
- **Error Lens** for inline error display
- **Cline** for AI, though I tend to use **Kiro** in CLI more often than not
- **Catppuccin** theme and icons to match everything else

The editor font is also MonoLisa. The `EDITOR` env var is set to `code --wait` so git commit messages and other tools that open an editor use VS Code.

## Git config

My git config does a few non-default things worth mentioning:

- **delta** as the pager for diffs. Side-by-side, line numbers, syntax highlighting with the same Catppuccin Macchiato theme. My goal is to be able to quickly read and understand things, this helps.
- **histogram** diff algorithm, which produces better diffs than the default Myers algorithm for most code changes.
- **rerere** (reuse recorded resolution) so git remembers how I resolved merge conflicts and applies the same resolution next time.
- **autosquash** and **autostash** on rebase so I can `git commit --fixup` freely and never have to stash manually before pulling.

Aliases are minimal: `lg` for a compact log graph, `uncommit` to soft-reset the last commit, `amend` for quick no-edit amends, `wip` to save everything with a throwaway message, and `sync` to fetch + rebase on main.

I also have SSH commit signing configured locally, but excluded it from the upstream dotfiles repo since signing keys are machine-specific. If you want it, it's a few lines in your gitconfig pointing at your SSH key.

## Launcher: Raycast

To be honest I have not used [Raycast](https://www.raycast.com/) heavily yet, but the configurability and other options make it a compelling tool for me, especially versus Alfred which can be cumbersome to extend and automate. I'll be giving it a try for a few months and may report back later on how it worked out, but so far it seems to be a good replacement.

Like every other tool it has its own AI upsell, but especially at work I'm not keen on putting anything in any non-sanctioned tool and I already have other AI utilities I use. I'm also not keen on incurring more monthly bills unless something gives me a real good reason to, and basic AI integration isn't it, I could likely wire my own in an hour or two.

For window management I use [Swish](https://highlyopinionated.co/swish/) which handles tiling with trackpad gestures. Raycast has its own window management but I haven't felt the need to switch.

## CLI Tools

The Brewfile installs a handful of tools I use daily:

- **ripgrep** (`rg`) over grep
- **fd** over find
- **bat** over cat for syntax-highlighted file viewing
- **jq** and **yq** for JSON/YAML wrangling
- **hyperfine** for benchmarking shell commands
- **tokei** for code line counts by language
- **lazygit** for when I want a TUI for complex git operations
- **gh** for GitHub CLI (PRs, issues, API calls)
- **act** for running GitHub Actions locally

## AI Tools

Certainly a new section, and not in the dotfiles, but my current AI stack tends towards CLI versions of Kiro (Amazon) and Claude (Anthropic). I occasionally try out OpenAI tools, have not really bothered with Gemini models or Copilot yet, and have an OpenLlama setup for a few local models I experiment with on occasion.

There are probably several more tools and editors out there, and maybe I start using them eventually, but this has worked well for me so far.

## The Theme: Catppuccin Macchiato

Previously I was using [Nord](https://www.nordtheme.com/ports/visual-studio-code) which worked fine, but I wanted to try something new, and Solarized wasn't quite doing it for me. [Catppuccin](https://catppuccin.com/) happened to hit well for me: A dark theme that wasn't loud and obnoxious, that was easy to read, and had ports across about everything I use.

Reducing visual strain is high on my list, and this scratched that itch.

I use the Macchiato sub-theme which is a mid-dark scheme. I may experiment with the others later and see how I feel about them.

## On the Desk

Keyboard is a RAMA U80-A in the Port colorway with [IFK Port](https://prototypist.net/products/in-sotck-infinikey-port) keycaps and [Gazzew Boba U4](https://ringerkeys.com/products/gazzew-boba-u4-silent-tactile-switches) silent tactiles at 68g. Personally I prefer silent switches as I do not like to announce my presence and every utterance with a thunderous clap of plastic on metal to everyone in my proximity, though if you do Kailh Box Navies are a good way to do so. I also like a heavier keyboard, because like above, I'm willing to spend on something that I'm going to use to death every day.

Mouse is a [Logitech MX Master 3S](https://www.logitech.com/en-us/products/mice/mx-master-3s.html). It's been a gold standard for a reason, but I always found that it deteriorates over time with the rubber coating, so when this one fails I may finally make a jump to the 4 series which claims not to have this problem. That said if Logitech does something foolish like a monthly fee I may just straight abandon it and fall back on something from [Keychron](https://www.keychron.com/collections/keychron-mice) instead.

Monitors are 2x 32" [Dell Ultrasharp 4Ks](https://www.dell.com/en-us/shop/monitors-monitor-accessories/ar/4009?appliedRefinements=38561) which have been pretty bulletproof over the years. There is an annoying bug where Macbooks on a TB dock will occasionally short with more than one monitor attached, so I may consolidate to 1x and get an ultrawide instead to free up some desk space. The dock itself is a [Kensington TB5](https://www.kensington.com/p/docking-stations/thunderbolt-docking-stations/) dock, but that's been happening with any dock I try, and apparently it's a flaw with Macs in general.

I also have a few [El Gato keylights](https://www.elgato.com/us/en/p/key-light) and a [stream deck](https://www.elgato.com/us/en/p/stream-deck-mk2-black) which have been handy when recording or streaming things, though I really dislike how the keylights only function on 2GHz for any automation and if I had to do that again I'd get much cheaper lights with a straightforward remote instead of something trying to be clever.

My other lamp is a [Dyson tasklight](https://www.dyson.com/task-lighting) I got because admittedly I had a lot of spare points on Bestbuy that paid for it, and it's fun to play with.

Mic wise I really should bother to re-wire everything as I have a [Rode Caster](https://rode.com/en/interfaces-mixers/rodecaster-series) and a [Scarlett 2i2](https://focusrite.com/products/scarlett-2i2) which are functional, but I've been falling back to my headphone mic on my [Bose Ultras](https://www.bose.com/p/headphones/bose-quietcomfort-ultra-headphones/QCUH-HEADPHONEARN.html). Noise cancelling is worth its weight in gold, and Bose has mostly worked for me. I do really dislike the app for switching between 2+ devices fighting for connections, but I've found it's just as bad if not worse on other device manufacturers.

The desk itself is an Ikea one I've had for way too long and should probably replace. I have a [Balolo](https://www.balolo.com/) riser and laptop stand which have worked great and a felt desk mat in a darker gray. There's a series of fountain pens, pencils, alcohol markers, and other art supplies littered about that I could get into later if that's of interest, but I'll keep it to vague allusions for now here.

## Provisioning

The whole environment installs from scratch with:

```sh
mkdir ~/dev
git clone https://github.com/baweaver/dotfiles ~/dev/dotfiles
cd ~/dev/dotfiles
bin/setup
```

The script is idempotent, so I can re-run it whenever I add a few things here and there. Thankfully I do not find myself _frequently_ provisioning new machines, but having a one-stop-shop for the next time I do will be handy.

The dotfiles repo also has `bin/doctor` which validates that everything is healthy (correct versions, symlinks in place, tools available) and `bin/update` which bumps all managed tools to latest.

## From special-sauce to dotfiles

My previous dotfiles repo, [special-sauce](https://github.com/baweaver/special-sauce), hasn't been updated in about 11 years. Looking at it now is like reading a time capsule from that same smug era. RVM for Ruby versions. Oh My Zsh with the agnoster theme. Vim as the editor. Tmux with Powerline sourced from a Python 2.7 path. A `.zprofile` with 150+ lines of aliases for Rails generators, Pry, Teaspoon (remember Teaspoon?), and a `new_alias` function that appended to the profile and re-sourced it.

The motto at the top was "Automate and Alias all the things! If it takes more than 5 keystrokes and you do it more than five times in a day, script it." I thought the most efficient thing I could do was alias everything and be the fastest typer in the room. `ber` for `bundle exec rspec`, `gin` for `gem install`, `bins` for `bundle install`, `rcon` for `rails console`. I had hundreds of these.

Nowadays I think 95% of that was useless. Typing `bundle exec rspec` takes what, two seconds? I was micro-optimizing for things that didn't take long in the first place and building a private shorthand only I could read. The real time sinks were never keystrokes, they were setting up machines, debugging environment drift between projects, and figuring out why something that worked yesterday stopped working today. That's what the new repo automates. `mkcd`, `cdl`, and `most_used` survived the decade because they do something I genuinely can't do in one command otherwise. The other 140 aliases didn't make the cut.

If you're curious about any of this, the repo is public. Steal what's useful, ignore what isn't.
