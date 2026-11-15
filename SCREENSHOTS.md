# How these screenshots were made

No Roblox Studio runs on the Linux machine that built this game, so there
was no Studio viewport to capture. Instead, `tools/render-shots.py` draws
each screenshot from the same `default.project.json` the place is built
from: every platform, checkpoint, coin, spinner bar, gate, cloud and the
lava sea is a part the generator placed, drawn at its real position, size
and colour in an isometric view. The HUD text is the same text
`src/client/Hud.client.luau` draws — the start screen, the live HUD
(timer / coins / stage) and the win screen — laid out as that script lays
it out. The small blocky figure is a generic Roblox avatar stand-in, drawn
for scale on the platform the player stands on.

Nothing in the pictures is gameplay the code does not have: the platforms
are the course, the coins are the 12 coins, the red bar is a spinner, the
green pads are checkpoints, and the gold pad in `3-end.jpg` is the win pad.
Re-run the renderer any time with `python3 tools/render-shots.py`.
