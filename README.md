<h1 align="center">The Old Man's Table</h1>

<p align="center">
 A virtual tabletop for tabletop RPGs, built with Lua and [LÖVE](https://love2d.org).
Game systems are plain Lua files that I wrote myself and loaded locally; the engine runs them inside a sandbox, so the rules live in data and the interface just reads them.
</p>

<p align="center">
  <img alt="Lua 5.5" src="https://img.shields.io/badge/Lua-5.5-2C2D72?logo=lua&logoColor=white">
  <img width="50" height="50" alt="image" src="https://github.com/user-attachments/assets/770a7560-5b8d-4c93-a5a7-cbbcfc04c754" />
  <img alt="Platforms: Linux and Windows" src="https://img.shields.io/badge/platforms-Linux%20%7C%20Windows-1F3B32">
  <img alt="Status: early development" src="https://img.shields.io/badge/status-early%20development-B8892B">
</p>



> **Status:** just started (1 Lua file). Study and portfolio project.

## Why

Commercial virtual tabletops depend on official modules. The Old Man's Table takes the opposite route: the table is generic, and each game system is a small Lua file describing attributes, dice and actions. That makes it possible to:

- play systems that other tabletops don't cover;
- publish original systems as portfolio pieces, with original numbers and formulas only (no rulebook text).

  Yeah, I know I do a lot of RPG stuff. But I guess things are becoming more complex with time. I played TableTop RPGs for about 29 years now, and I'm still playing,
  but I'm developing the skills and I'm all in to do company management stuff and whatnot!

## Features

- [x] Dice expression parser (`2d6+3`, `1d20`, ...)
- [x] Sandboxed rules engine: systems can't touch files, the OS or the network
- [x] Character sheet generated from the system's attributes and actions
- [ ] Grid map with camera, zoom and draggable tokens
- [ ] Console with chat-style log and slash commands
- [ ] Save and load campaigns
- [ ] Unit tests for the core (no LÖVE required)

## Requirements

| Tool | Version | Used for |
|---|---|---|
| LÖVE | 11.5 | Running the app |
| LuaJIT | 2.1 | Running the core tests outside LÖVE |

**About the Lua version:** LÖVE embeds LuaJIT, which follows Lua 5.1 syntax. The Lua installed on my system (5.4, 5.5) is not the one LÖVE uses. So I gotta be careful with the new features.

## Getting started

### Arch Linux

```bash
sudo pacman -S love luajit
git clone https://github.com/velhotolo/VTT.git
cd VTT
love .
```

### Windows

Download LÖVE from [love2d.org](https://love2d.org), then drag the project folder onto `love.exe`, or run `lovec.exe path\to\mesa` to get a console that 
shows `print` output.

### Running the tests (to be implemented)

From the project root:

```bash
luajit tests/run.lua
```

## Project layout

```
VTT/
  conf.lua                  window settings (loaded first)
  main.lua                  wires the modules and dispatches LÖVE callbacks
  src/
    dice.lua                dice parser and roller             (pure Lua)
    sandbox.lua             restricted environment for rules   (pure Lua)
    rules.lua               loads, validates and runs systems  (pure Lua)
    serialize.lua           table <-> text for saves           (pure Lua)
    campaign.lua            table state: tokens and log        (pure Lua)
    ui.lua                  buttons and text                   (LÖVE)
    map.lua                 grid, camera and tokens            (LÖVE)
    sheet.lua               character sheet                    (LÖVE)
    console.lua             log and command line               (LÖVE)
  systems/
    trail_d6/system.lua    complete example system
    empty_system/system.lua empty template
  tests/
    run.lua                 core tests
```

The `src/` modules marked *pure Lua* don't depend on LÖVE. That split is what allows testing the core with plain LuaJIT and, later, running a multiplayer server without a window.

## Save data

LÖVE only writes to its save directory:

| OS | Path |
|---|---|
| Linux | `~/.local/share/love/<identity>/` |
| Windows | `%APPDATA%\LOVE\<identity>\` |
| macOS | `~/Library/Application Support/LOVE/<identity>/` |

`<identity>` is the value set in `conf.lua`.

## Known limits

- An infinite loop inside a rule freezes the app. LuaJIT can't reliably interrupt JIT-compiled code from inside the same thread, so only load systems you trust.
- The sandbox doesn't cap memory.
- Fixed-size square grid.

## Roadmap

- [ ] Bigger fonts and buttons, with a UI scale setting
- [ ] Animated dice and dice icons (sprite sheets)
- [ ] Map background images
- [ ] Initiative tracker
- [ ] Notes on the character sheet
- [ ] Multiplayer chat over the network (`lua-enet`, bundled with LÖVE)

## Credits

- I started messing around with Lua about a year ago. Used these courses to start: https://www.udemy.com/course/cursos-ttech-lua/learn/lecture/34972320#overview
  and https://www.udemy.com/course/programar-lua-do-zero/learn/lecture/24372736?start=0#overview.
- I tried one LÖVE course but didn't like it very much. The DOCs are good, there are plenty of game structures for you to try, but for a noob like me, sometimes
  things get way too hard. https://www.udemy.com/course/programming-for-beginners-with-lua-and-love2d/learn/lecture/50832807#overview This course, on the other
  hand, was amazing. It made me believe I can do the Old Man's Table project.

## Author

Lucas, a.k.a. **Velho Tolo**. 3D artist turned programmer.
Art portfolio: [artstation.com/lucasbezerra](https://www.artstation.com/lucasbezerra)

## License
MIT
