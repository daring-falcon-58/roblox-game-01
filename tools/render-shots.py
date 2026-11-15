#!/usr/bin/env python3
"""Render the three screenshots for Ember Ascent from the actual game data.

No Roblox Studio runs on this Linux machine, so the screenshots are drawn
from the same default.project.json the place is built from: every platform,
checkpoint, coin, spinner, gate and cloud in the picture is a part the
generator placed, at its real position, size and colour. The HUD text is the
same text src/client/Hud.client.luau draws (start screen, live HUD, win
screen). The blocky figure is a generic Roblox avatar stand-in, drawn for
scale on the platform the player stands on.

Run:  python3 tools/render-shots.py
Writes: screenshots/1-start.jpg, 2-play.jpg, 3-end.jpg (1280x706, <=256 KiB).
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(REPO, "default.project.json")
OUT = os.path.join(REPO, "screenshots")

W, H = 1280, 706
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


# ---------------------------------------------------------------------------
# World: read the parts out of default.project.json
# ---------------------------------------------------------------------------

def collect_parts(node, out, name="?"):
    props = node.get("$properties", {})
    cls = node.get("$className")
    if cls == "Part":
        pos = props.get("Position", [0, 0, 0])
        size = props.get("Size", [1, 1, 1])
        colour = props.get("Color", [1, 1, 1])
        out.append({
            "name": name,
            "pos": pos,
            "size": size,
            "colour": tuple(int(round(c * 255)) for c in colour),
            "shape": props.get("Shape", "Block"),
            "material": props.get("Material", "SmoothPlastic"),
            "transparency": props.get("Transparency", 0),
        })
    for key, child in node.items():
        if isinstance(child, dict) and key not in ("$properties",):
            collect_parts(child, out, name=key)


def load_parts():
    with open(PROJECT) as f:
        project = json.load(f)
    parts = []
    collect_parts(project["tree"]["Workspace"], parts)
    return parts


# ---------------------------------------------------------------------------
# Isometric projection
# ---------------------------------------------------------------------------

COS30 = math.cos(math.radians(30))
SIN30 = 0.5


class Camera:
    def __init__(self, cx, cy, cz, scale):
        self.cx, self.cy, self.cz = cx, cy, cz
        self.s = scale

    def project(self, x, y, z):
        dx, dy, dz = x - self.cx, y - self.cy, z - self.cz
        sx = (dx - dz) * COS30 * self.s + W / 2
        sy = (dx + dz) * SIN30 * self.s * 0.62 - dy * self.s + H * 0.58
        return sx, sy


def shade(colour, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in colour)


def draw_box(draw, cam, part):
    x, y, z = part["pos"]
    sx, sy, sz = (d / 2 for d in part["size"])
    corners = {}
    for ix in (-1, 1):
        for iy in (-1, 1):
            for iz in (-1, 1):
                corners[(ix, iy, iz)] = cam.project(x + ix * sx, y + iy * sy, z + iz * sz)
    top = [corners[(-1, 1, -1)], corners[(1, 1, -1)], corners[(1, 1, 1)], corners[(-1, 1, 1)]]
    left = [corners[(-1, -1, 1)], corners[(-1, 1, 1)], corners[(-1, 1, -1)], corners[(-1, -1, -1)]]
    right = [corners[(1, -1, -1)], corners[(1, 1, -1)], corners[(1, 1, 1)], corners[(1, -1, 1)]]
    alpha = part["transparency"]
    if alpha >= 1:
        return
    c = part["colour"]
    neon = part["material"] == "Neon"
    if neon:
        # A soft glow behind a neon part, then the part itself at full colour.
        glow = [tuple(v + 30 for v in p) for p in top]
        draw.polygon(glow, fill=shade(c, 0.55))
    draw.polygon(right, fill=shade(c, 0.55))
    draw.polygon(left, fill=shade(c, 0.75))
    draw.polygon(top, fill=shade(c, 1.0 if not neon else 1.15))
    draw.line(top + [top[0]], fill=shade(c, 0.4), width=1)


def draw_ball(draw, cam, part):
    x, y, z = part["pos"]
    px, py = cam.project(x, y, z)
    r = part["size"][0] / 2 * cam.s * 0.9
    if r < 1:
        return
    c = part["colour"]
    alpha = part["transparency"]
    if alpha >= 1:
        return
    # Clouds are drawn flat and faint, so they read as sky, not as blobs.
    if part["name"].startswith("Cloud"):
        w, h = r * 1.4, r * 0.55
        draw.ellipse([px - w, py - h, px + w, py + h],
                     fill=(255, 255, 255, 90))
        return
    draw.ellipse([px - r, py - r, px + r, py + r], fill=shade(c, 1.0))
    draw.ellipse([px - r * 0.45, py - r * 0.55, px + r * 0.1, py - r * 0.05],
                 fill=shade(c, 1.4))


def draw_avatar(draw, cam, x, y, z):
    """A generic blocky Roblox avatar, for scale, standing on a platform."""
    # Legs (green), torso (blue), arms + head (yellow), drawn as small boxes.
    pieces = [
        ([x - 0.7, y + 0.5, z], [1.2, 1, 1.2], (60, 160, 60)),
        ([x + 0.7, y + 0.5, z], [1.2, 1, 1.2], (60, 160, 60)),
        ([x, y + 1.5, z], [2.6, 2, 1.4], (40, 90, 200)),
        ([x - 1.9, y + 1.5, z], [1, 2, 1.2], (255, 220, 60)),
        ([x + 1.9, y + 1.5, z], [1, 2, 1.2], (255, 220, 60)),
        ([x, y + 3.1, z], [2, 1.8, 2], (255, 220, 60)),
    ]
    for (px, py, pz), size, colour in pieces:
        fake = {"pos": [px, py, pz], "size": size, "colour": colour,
                "shape": "Block", "material": "SmoothPlastic", "transparency": 0}
        draw_box(draw, cam, fake)


def sky(draw):
    # Dusk: dark purple up top, warm ember low down — but kept darker than
    # the lava, so the lava sea reads as lava, not as sky.
    top = (24, 17, 44)
    mid = (74, 44, 84)
    bot = (118, 60, 52)
    for yy in range(H):
        t = yy / H
        if t < 0.55:
            f = t / 0.55
            c = tuple(int(top[i] + (mid[i] - top[i]) * f) for i in range(3))
        else:
            f = (t - 0.55) / 0.45
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * f) for i in range(3))
        draw.line([(0, yy), (W, yy)], fill=c)


def render_scene(parts, cam, avatar):
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img, "RGBA")
    sky(draw)
    # Far parts first. Depth is the smallest x+z over the part's corners:
    # a huge part like the lava sea is ordered by its nearest edge, not its
    # centre, or it would paint over the platforms floating above it.
    visible = []
    for p in parts:
        xs, ys = [], []
        depths = []
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    cx = p["pos"][0] + ix * p["size"][0] / 2
                    cz = p["pos"][2] + iz * p["size"][2] / 2
                    px, py = cam.project(
                        cx,
                        p["pos"][1] + iy * p["size"][1] / 2,
                        cz,
                    )
                    xs.append(px)
                    ys.append(py)
                    depths.append(cx + cz)
        if min(xs) < W + 150 and max(xs) > -150 and min(ys) < H + 150 and max(ys) > -150:
            p["depth"] = min(depths)
            visible.append(p)
    visible.sort(key=lambda p: p["depth"])
    # Balls (coins, clouds) go on a translucent layer above the boxes.
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    for p in visible:
        if p["shape"] == "Ball":
            draw_ball(odraw, cam, p)
        else:
            draw_box(draw, cam, p)
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)
    if avatar:
        draw_avatar(draw, cam, *avatar)
    return img, draw


# ---------------------------------------------------------------------------
# HUD overlays — the same words and layout as src/client/Hud.client.luau.
# Each overlay is drawn on its own RGBA layer and composited over the scene,
# so the translucent dimming stays translucent.
# ---------------------------------------------------------------------------

def layer(img):
    return Image.new("RGBA", (W, H), (0, 0, 0, 0)), img.convert("RGBA")


def composite(overlay, base):
    return Image.alpha_composite(base, overlay).convert("RGB")


def panel(draw, box, fill=(24, 18, 40, 190)):
    draw.rounded_rectangle(box, radius=14, fill=fill)


def centred(draw, cx, y, text, fnt, fill=(255, 255, 255)):
    w = draw.textlength(text, font=fnt)
    draw.text((cx - w / 2, y), text, font=fnt, fill=fill)


def overlay_start(img):
    ov, base = layer(img)
    draw = ImageDraw.Draw(ov)
    draw.rectangle([0, 0, W, H], fill=(24, 18, 40, 70))
    centred(draw, W / 2, 130, "EMBER ASCENT", font(FONT_BOLD, 72), (255, 196, 90))
    centred(draw, W / 2, 228, "Climb the tower. Dodge the lava. Reach the summit.",
            font(FONT_BOLD, 28), (240, 235, 255))
    centred(draw, W / 2, 288, "Move with WASD or the arrow keys  •  Jump with Space",
            font(FONT, 22), (220, 225, 240))
    centred(draw, W / 2, 318, "Touch a green pad to save your checkpoint  •  Grab all 12 coins",
            font(FONT, 22), (220, 225, 240))
    panel(draw, [W / 2 - 130, 500, W / 2 + 130, 572], fill=(72, 160, 72, 235))
    centred(draw, W / 2, 516, "▶  PLAY", font(FONT_BOLD, 32))
    return composite(ov, base)


def overlay_hud(img, stage_text, time_text, coins_text):
    ov, base = layer(img)
    draw = ImageDraw.Draw(ov)
    centred(draw, W / 2, 14, time_text, font(FONT_BOLD, 30))
    w = draw.textlength(coins_text, font=font(FONT_BOLD, 26))
    draw.text((W - 16 - w, 16), coins_text, font=font(FONT_BOLD, 26), fill=(255, 214, 90))
    centred(draw, W / 2, 54, stage_text, font(FONT_BOLD, 22), (230, 240, 255))
    return composite(ov, base)


def overlay_win(img):
    ov, base = layer(img)
    draw = ImageDraw.Draw(ov)
    draw.rectangle([0, 0, W, H], fill=(24, 18, 40, 70))
    centred(draw, W / 2, 150, "SUMMIT REACHED!", font(FONT_BOLD, 60), (255, 214, 90))
    centred(draw, W / 2, 250, "Your time:  1:47.3", font(FONT_BOLD, 30), (240, 235, 255))
    centred(draw, W / 2, 292, "Coins:  12 / 12", font(FONT_BOLD, 30), (240, 235, 255))
    centred(draw, W / 2, 334, "Best time:  1:47.3  (par 2:30.0)", font(FONT_BOLD, 30), (240, 235, 255))
    centred(draw, W / 2, 376, "★ NEW BEST TIME! ★", font(FONT_BOLD, 26), (255, 214, 90))
    panel(draw, [W / 2 - 150, 450, W / 2 + 150, 518], fill=(72, 160, 72, 235))
    centred(draw, W / 2, 466, "↻  CLIMB AGAIN", font(FONT_BOLD, 30))
    return composite(ov, base)


# ---------------------------------------------------------------------------
# Shots
# ---------------------------------------------------------------------------

def save(img, name):
    path = os.path.join(OUT, name)
    for quality in (88, 80, 72, 62):
        img.save(path, "JPEG", quality=quality)
        if os.path.getsize(path) <= 262144:
            break
    size = os.path.getsize(path)
    print(f"wrote {name}: {size} bytes ({W}x{H})")
    if size > 262144:
        print(f"WARNING: {name} is over the 256 KiB cap", file=sys.stderr)


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = load_parts()
    print(f"loaded {len(parts)} parts from default.project.json")

    # 1 — start: the start pad and the first stage, with the start screen.
    # The avatar stands on the first platform, clear of the PLAY button.
    cam1 = Camera(0, 5, 32, 9)
    img, draw = render_scene(parts, cam1, avatar=(0, 0.5, 20))
    img = overlay_start(img)
    save(img, "1-start.jpg")

    # 2 — play: mid-climb on the Ember stage, mover + spinner + coins in view.
    cam2 = Camera(0, 27, 165, 9)
    img, draw = render_scene(parts, cam2, avatar=(7, 27.5, 154))
    img = overlay_hud(img, "STAGE 2  •  EMBER", "TIME  0:47.3", "COINS  4/12")
    save(img, "2-play.jpg")

    # 3 — end: the summit, win pad and beacon, with the win screen. The
    # avatar stands front-left of the pad so the beacon does not hide it.
    cam3 = Camera(0, 79, 438, 9)
    img, draw = render_scene(parts, cam3, avatar=(-2, 80.5, 444))
    img = overlay_win(img)
    save(img, "3-end.jpg")


if __name__ == "__main__":
    main()
