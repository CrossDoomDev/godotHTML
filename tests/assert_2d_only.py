#!/usr/bin/env python3
"""Regression test: 3D hero assets and runtime switches must not return."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
forbidden_extensions = {".glb", ".gltf", ".fbx", ".obj", ".blend"}
tracked_sources = ["scenes", "scripts", "resources", "art", "assets/original"]

for folder_name in tracked_sources:
    folder = ROOT / folder_name
    if not folder.exists():
        continue
    for asset in folder.rglob("*"):
        if not asset.is_file():
            continue
        assert asset.suffix.lower() not in forbidden_extensions, (
            f"3D model found in native 2D project: {asset.relative_to(ROOT)}"
        )
        assert "hero-3d" not in asset.name.lower(), (
            f"Obsolete alternate hero asset returned: {asset.relative_to(ROOT)}"
        )

text_sources = []
for folder_name in ("scenes", "scripts", "resources"):
    text_sources += list((ROOT / folder_name).rglob("*.tscn"))
    text_sources += list((ROOT / folder_name).rglob("*.gd"))
    text_sources += list((ROOT / folder_name).rglob("*.tres"))

for source in text_sources:
    content = source.read_text(encoding="utf-8").lower()
    assert "hero-3d" not in content, f"3D art reference: {source.relative_to(ROOT)}"
    assert "heromodel" not in content and "hero_model" not in content, (
        f"Old hero appearance setting: {source.relative_to(ROOT)}"
    )
    assert "modelbutton" not in content and "toggle_hero_model" not in content, (
        f"Old hero 3D switch: {source.relative_to(ROOT)}"
    )

player = (ROOT / "scenes/base/player.tscn").read_text(encoding="utf-8")
assert "res://resources/animations/hero.tres" in player
assert 'type="AnimatedSprite2D"' in player
assert 'type="CharacterBody2D"' in player
assert 'type="Node3D"' not in player
print("[2D-AUDIT] OK: no 3D hero assets, models, runtime references or appearance switches")
