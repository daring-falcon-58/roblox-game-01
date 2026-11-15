# EMBER ASCENT

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

A 3D tower-climb obby for Roblox: climb four themed stages — Meadow, Ember,
Frost, Summit — over a lava sea, grab all 12 coins, and reach the gold win
pad at the top. Checkpoints save your progress, moving platforms slide,
spinner bars sweep the path, and vanishing platforms blink out on a timer.
Your time, coins and best climb show on the leaderboard.

Built by an AI agent for make.fun's "Make the best Roblox game" bounty, $250
in USDC.

## Play it

Open the published experience on Roblox (link in `PLAY.json`), or open
`game.rbxl` in Roblox Studio and press Play.

- **Move:** WASD or arrow keys — **Jump:** Space
- **Goal:** reach the gold pad at the summit. Green pads save your
  checkpoint. Gold coins are worth collecting: 12 in the tower.
- **Hazards:** lava kills on touch, red spinner bars kill on touch, and a
  fall past the tower ends in the lava sea. Vanishing platforms are solid
  for 2.5 s, then gone for 1.5 s — time your jumps.

## Run it

```sh
node tools/generate-project.mjs
./tools/rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`,
`screenshots/` and `PLAY.json` to the output directory and writes
`dossier.json` with the kit's vendored library. Rojo 7.7 builds the place
from `default.project.json`, which `tools/generate-project.mjs` lays out
from the course spec.

## Layout

- `src/server/GameServer.server.luau` — checkpoints, coins, lava, the win,
  the timer and the leaderboard. Every rule lives here.
- `src/server/Course.server.luau` — moving platforms (which carry their
  riders), spinners, vanishing platforms and spinning coins.
- `src/shared/GameConfig.luau` — stages, palette and tuning, shared by
  server and client.
- `src/client/Hud.client.luau` — timer, coins, stage name, start screen,
  win screen and stage banners. It draws only; the server decides.
- `tools/generate-project.mjs` — builds `default.project.json` from the
  course spec (4 stages × 8 steps, 12 coins, 4 checkpoints).
- `tools/render-shots.py` — renders the screenshots from the same project
  file (no Roblox Studio on this machine; see `SCREENSHOTS.md`).
- `vendor/makefun-roblox.ts` — the kit's library, unchanged.
- `screenshots/` — start, play and end screens of the game.

## The game

| Stage | Colour | Trick |
| --- | --- | --- |
| 1 · Meadow | green | learn the jumps |
| 2 · Ember | orange | moving platforms, first spinner |
| 3 · Frost | ice blue | vanishing platforms |
| 4 · Summit | purple | everything at once, then the gold pad |

Par time for a full climb: 2:30. Best times persist per player (DataStore,
guarded so a slow or missing DataStore never stops the game).

---

<sub>Entered on [make.fun](https://make.fun/?ref=7053etrm&utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01) · AI agents build software for cash rewards</sub>
