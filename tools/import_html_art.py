#!/usr/bin/env python3
"""One-time transfer of the ACTUAL MyGameHTML art and map to native Godot.

This is an editor asset pipeline, not a runtime map renderer. It creates PNG
textures and JSON authoring data consumed by tools/build_scenes.gd. Godot then
saves real TileMapLayer scene cells and reusable SpriteFrames resources.
"""
from __future__ import annotations
import json
import math
import random
import shutil
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE_URL = "https://github.com/CrossDoomDev/MyGameHTML.git"
TILE = 32
SPECS = {
    "inn": ((0, 0, 402, 355), (192, 160)),
    "cottage": ((402, 0, 267, 355), (144, 152)),
    "forge": ((669, 0, 337, 355), (144, 144)),
    "cabin": ((1006, 0, 248, 355), (112, 144)),
    "oak": ((0, 355, 389, 352), (112, 112)),
    "pine": ((389, 355, 281, 352), (80, 112)),
    "birch": ((670, 355, 334, 352), (104, 104)),
    "bush": ((1004, 466, 250, 242), (44, 40)),
    "market": ((0, 708, 389, 294), (128, 96)),
    "lamp": ((422, 707, 187, 295), (36, 76)),
    "barrel": ((710, 745, 197, 257), (23, 30)),
    "crates": ((960, 729, 294, 273), (38, 35)),
    "anvil": ((0, 1004, 363, 250), (44, 32)),
    "logs": ((364, 1004, 305, 250), (44, 36)),
    "fence": ((670, 1004, 285, 250), (36, 28)),
    "crops": ((955, 1004, 299, 250), (48, 44)),
}
NPCS = [
    {"name": "Староста Ольгерд", "id": "elder", "sprite": "elder", "x": 11, "y": 15, "role": "elder"},
    {"name": "Кузнец Бран", "id": "smith", "sprite": "smith", "x": 21, "y": 16, "role": "smith"},
    {"name": "Торговка Мира", "id": "merchant", "sprite": "merchant", "x": 28, "y": 15, "role": "merchant"},
    {"name": "Травница Лина", "id": "villager", "sprite": "villager", "x": 12, "y": 22, "role": "herbalist"},
    {"name": "Рыбак Финн", "id": "fisher", "sprite": "merchant", "x": 27, "y": 20, "role": "fisher"},
]
ENEMIES = [
    {"name": "Моховик", "sprite": "mossling", "x": 30, "y": 18, "hp": 32, "damage": 8, "xp": 18},
    {"name": "Моховик", "sprite": "mossling", "x": 33, "y": 21, "hp": 32, "damage": 8, "xp": 18},
    {"name": "Лесной гоблин", "sprite": "goblin", "x": 31, "y": 9, "hp": 42, "damage": 11, "xp": 30},
    {"name": "Моховик", "sprite": "mossling", "x": 19, "y": 25, "hp": 32, "damage": 8, "xp": 18},
    {"name": "Лесной страж", "sprite": "guardian", "x": 33, "y": 5, "hp": 130, "damage": 18, "xp": 120, "boss": True},
]
HERBS = [[16, 16], [18, 19], [29, 18], [30, 8], [12, 23], [19, 26]]

def mkdir(path: str) -> Path:
    dest = ROOT / path
    dest.mkdir(parents=True, exist_ok=True)
    return dest

def rect_draw(img: Image.Image, xy, color):
    ImageDraw.Draw(img).rectangle(xy, fill=color)

def terrain_sheet() -> Image.Image:
    atlas = Image.new("RGBA", (TILE * 16, TILE * 5), (0, 0, 0, 0))
    green = (88, 121, 62, 255)
    dirt = (179, 140, 91, 255)
    water = (28, 94, 111, 255)
    for row in range(5):
        for variant in range(16):
            im = Image.new("RGBA", (TILE, TILE), [green, dirt, water, (133, 134, 115, 255), (77, 109, 57, 255)][row])
            draw = ImageDraw.Draw(im)
            rng = random.Random((row + 1) * 13007 + variant * 79)
            if row == 0:
                for i in range(38):
                    x = rng.randrange(1, 31)
                    y = rng.randrange(1, 31)
                    col = [(116, 151, 75, 255), (70, 104, 52, 255),
                           (104, 135, 65, 255), (128, 154, 78, 255)][i % 4]
                    draw.rectangle((x, y, x + (i % 9 == 0), y + (i % 5 == 0)), fill=col)
            elif row == 1:
                # Four-bit mask: 1 north, 2 east, 4 south, 8 west.
                # Each mask has NO square outline: connected roads join perfectly.
                for i in range(12):
                    x = rng.randrange(2, 30)
                    y = rng.randrange(2, 30)
                    draw.rectangle((x, y, x + (i % 3 == 0), y), fill=(
                        (201, 159, 105, 255) if i % 2 else (164, 127, 81, 255)))
                for i in range(0, TILE, 4):
                    grain = random.Random(83 + variant * 193 + i)
                    depth = grain.randrange(1, 4)
                    if variant & 1: draw.rectangle((i, 0, min(31, i + 3), depth - 1), fill=green)
                    if variant & 2: draw.rectangle((32 - depth, i, 31, min(31, i + 3)), fill=green)
                    if variant & 4: draw.rectangle((i, 32 - depth, min(31, i + 3), 31), fill=green)
                    if variant & 8: draw.rectangle((0, i, depth - 1, min(31, i + 3)), fill=green)
            elif row == 2:
                for i in range(5):
                    x, y = rng.randrange(3, 26), rng.randrange(3, 29)
                    draw.rectangle((x, y, x + (i % 2) + 3, y), fill=(45, 119, 130, 255))
            elif row == 4:
                # Forest undergrowth is a genuine native TileMap layer:
                # grass, moss, scattered leaves and tiny plants.
                for i in range(43):
                    x, y = rng.randrange(1, 31), rng.randrange(1, 31)
                    c = [(60,93,46,255), (101,132,64,255),
                         (69,104,51,255), (124,145,68,255)][i % 4]
                    draw.rectangle((x,y,x+(i % 7 == 0),y+(i % 5 == 0)),fill=c)
            else:
                # Stone paving; grout forms a brick pattern, not a grass/path grid.
                for y in range(0, 32, 12):
                    draw.line((0, y, 31, y), fill=(91, 99, 89, 255), width=2)
                    shift = 0 if y % 24 == 0 else 8
                    for x in range(shift, 32, 16):
                        draw.line((x, y, x, min(31, y + 11)), fill=(91, 99, 89, 255), width=2)
                for i in range(8):
                    x, y = rng.randrange(1, 30), rng.randrange(1, 30)
                    draw.point((x, y), fill=(165, 162, 142, 255))
            atlas.paste(im, (variant * TILE, row * TILE))
    return atlas

def main() -> None:
    for folder in ("assets/original", "art/terrain", "art/environment", "art/characters",
                   "resources/animations", "resources/tilesets", "scenes/world",
                   "scenes/base", "data", "docs"):
        mkdir(folder)
    with tempfile.TemporaryDirectory(prefix="tiholesye-source-") as tmp:
        src = Path(tmp) / "MyGameHTML"
        subprocess.run(["git", "clone", "--quiet", "--depth", "1", SOURCE_URL, str(src)], check=True)
        original = src / "assets"
        for asset in original.iterdir():
            # Only 2D image/metadata assets belong in the Godot 2D project.
            # Never import GLB/GLTF meshes, even if the HTML source adds them later.
            # The old HTML hero is retired. Do not restore any 2D or 3D hero source.
            if asset.suffix.lower() in (".png", ".json") and "hero" not in asset.stem.lower():
                shutil.copy2(asset, ROOT / "assets/original" / asset.name)
        source = Image.open(original / "village-source.png").convert("RGBA")
        for name, (rect, size) in SPECS.items():
            x, y, w, h = rect
            asset = source.crop((x, y, x + w, y + h)).resize(size, Image.Resampling.NEAREST)
            # Remove exactly the stray left-border fragments diagnosed in HTML.
            if name in ("cottage", "forge"):
                count = 3 if name == "cottage" else 2
                asset.paste((0, 0, 0, 0), (0, 0, count, size[1]))
            asset.save(ROOT / "art/environment" / f"{name}.png")
        for name in ("elder", "smith", "merchant", "villager", "goblin",
                     "mossling", "guardian", "icons"):
            shutil.copy2(original / (name + ".png"), ROOT / "art/characters" / (name + ".png"))
        map_js = "import { createMap } from './src/map.js';process.stdout.write(JSON.stringify(createMap()));"
        proc = subprocess.run(["node", "--input-type=module", "-e", map_js],
                              cwd=src, check=True, text=True, capture_output=True)
        data = json.loads(proc.stdout)
        data["npcs"] = NPCS
        data["enemies"] = ENEMIES
        data["herbs"] = HERBS
        data["source_git_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=src, text=True).strip()
        with open(ROOT / "data/world_layout.json", "w", encoding="utf-8") as file:
            json.dump(data, file, ensure_ascii=False, separators=(",", ":"))
    terrain_sheet().save(ROOT / "art/terrain/tileset.png")
    # Editor-visible native TextureRect minimap, derived from the original map.
    preview = Image.new("RGBA", (40 * 4, 30 * 4), "#58793e")
    painter = ImageDraw.Draw(preview)
    hues = {"grass": "#58793e", "path": "#b38c5b",
            "water": "#1c5e6f", "bridge": "#969582"}
    for y, row in enumerate(data["terrain"]):
        for x, cell in enumerate(row):
            painter.rectangle((x*4,y*4,x*4+3,y*4+3),fill=hues[cell])
    for item in data["objects"]:
        if item.get("tree"):
            x,y=int(item["x"]),int(item["y"])
            painter.rectangle((x*4,y*4,x*4+3,y*4+3),fill="#2a5540")
    for building in data["buildings"]:
        x,y,w,h=(int(building[k]) for k in ("x","y","w","h"))
        painter.rectangle((x*4,y*4,(x+w)*4-1,(y+h)*4-1),fill="#6c5540")
    preview.save(ROOT / "art/terrain/minimap.png")
    print("Imported HTML git commit", data["source_git_sha"])
    print("Paintable world:", len(data["terrain"][0]), "x", len(data["terrain"]),
          "map cells;", len(data["objects"]), "prop instances;",
          len(data["buildings"]), "buildings")
    print("The generated scenes (NOT this JSON) are the authoritative editable map.")

if __name__ == "__main__":
    main()
