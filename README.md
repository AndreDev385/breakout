# Breakout

A Breakout clone written in [Odin](https://odin-lang.org/) using [raylib](https://www.raylib.com/) via `vendor:raylib`.

Levels are designed with [Tiled](https://www.mapeditor.org/) and loaded from JSON.

## Features

- 3 levels with different brick layouts loaded from Tiled JSON files
- Paddle controlled with `A`/`D` keys
- Ball physics with variable bounce angle based on paddle hit position
- Brick collision with multiple hit points (colored by remaining lives)
- 3 power-ups: Wide Paddle, Extra Life, Slow Ball
- Sound effects: brick hit, life lost, power-up collected
- Persistent top-5 high scores saved to `~/.local/share/breakout/highscores.txt`
- Game states: Start Screen, Serving, Playing, Paused, Game Over, Game Won
- Pause with `P` key

## Requirements

- [Odin](https://odin-lang.org/docs/install/) (compiler)
- `vendor:raylib` (included with Odin — binaries downloaded automatically on first build)

## Build & Run

```bash
odin run .
```

## Controls

| Key                | Action                       |
|--------------------|------------------------------|
| `A`                | Move paddle left             |
| `D`                | Move paddle right            |
| `Space`            | Serve ball / start game      |
| `P`                | Pause / resume               |

## Project Structure

```
.
├── main.odin          # Core game logic, rendering, state machine
├── sound.odin         # Sound system (decoupled via event flags)
├── assets/
│   ├── *.png          # Sprites (ball, paddle, bricks, power-ups, tileset)
│   ├── *.wav          # Sound effects
│   ├── level_*.json   # Tiled level data
│   └── tileset.json   # Tileset definition
└── README.md
```
