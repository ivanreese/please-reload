# Please Reload 🤞

#### A plucky little live server that's trying its best.

This is a CoffeeScript file I wrote in 2023. I expect to continue using it, largely as-is, until 2033.

I use it in my [Cakefiles](https://github.com/ivanreese/sweetbread), my personal [CLI](https://github.com/ivanreese/i), and little one-off scripts.

```coffeescript

# We're in Node, we're using CoffeeScript, so no, of course we're not using ESM, are you daft?
PleaseReload = require "please-reload"

# The moment of truth: spin up a live-reloading web server using the given path as the site root
PleaseReload.serve "."

# By default, PleaseReload opens your browser to `http://localhost:3000` (or 3001, 3002, whatever's free)
# Don't want it to open your browser for you?
PleaseReload.serve ".", false
# Want it to open your browser to a specific path?
PleaseReload.serve ".", "/specific/path"

# Trigger a reload in the browser. Useful after your build script watcher triggers a recompile.
PleaseReload.reload()
```

### Why?
*Why write a new live-reload server? Why not just use Will or Vite or browser-sync or something?*

I do use them. But…

* They all eventually *silently* fail, and I [experience bij](https://www.youtube.com/watch?v=VjAvGNn20Y8).
* Why do they have so many features? So much documentation for such a simple task. Which settings should I use for this project? Where do I put my `index.html`? How do I trigger a reload from a script? Do I have to `touch` a file?
* Why do they have so many dependencies? Why do I have to install them globally?
* Why do they keep being updated? What if I stick with the old version? I don't want my personal projects to all break after a few years!

That thing I just said — "personal projects" — that's what this is for. *My* personal projects.

It's really, really, really nice to have my own tools. I know when they'll change, and when they won't. I know what I need them to do, and *that's all they need to do*. I mean, look at [the code](https://github.com/ivanreese/please-reload/blob/main/please-reload.coffee). It's a single file, 200 LoC, only depends on Node, CoffeeScript, and a popular, zero-dependency websocket library. A stable runtime, a stable language, and some plumbing (that I can probably eventually replace with like 30 lines of Node). Like I said, I expect to continue using this largely as-is in 2033.

### License

It's public domain. Please strip for parts.

### Footnote

Above, I wrote: "Why not just use Will or Vite or browser-sync or something?"

"Will" is, at time of writing, made up. It's fake. Bullshit. Why? *JS changes fast!* Any list of popular tools will quickly go stale. But if I fake up some shit you've never heard of, there's a *chance* you'll read it and think, "Oh, that must be a new thing, I should check it out." I have tricked you into thinking this project is fresh and vibrant.

### Footnote 2

"Will" is, at the time of writing, actually a real thing. I lied! Bullshit, deux. Why? Check the fuck out [this repo](https://github.com/nickfargo/will) — a src folder of *literate coffeescript*!! What does it do? Experimental async / futures / promises, two years before they were added to JS. Check the [npm package](https://www.npmjs.com/package/will) — 5 weekly downloads! At the time of writing, that's 1 more than [Please Reload](https://www.npmjs.com/package/please-reload). So, hey, it's more real than my thing.

I think that's beautiful. I mean, I'm a little envious that they managed to lock down the name "Will" on npm. But, you know, I'd rather it be for something like this… than something like [that](https://www.npmjs.com/package/yo).
