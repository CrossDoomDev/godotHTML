#!/usr/bin/env python3
"""Editor-time import of chosen transparent ranger sprites (no runtime rendering).

Place the user's image at art/characters/forest_ranger_source.png (724x2172).
Outputs a fixed-grid atlas, native SpriteFrames (.tres) and patches Player.tscn.
"""
from pathlib import Path
from PIL import Image
import re

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'art/characters/forest_ranger_source.png'
ATLAS=ROOT/'art/characters/forest_ranger.png'
RESOURCE=ROOT/'resources/animations/hero.tres'
PLAYER=ROOT/'scenes/base/player.tscn'
SIZE=96

def patch_visual(block):
    for prop in ('position','scale','texture_filter'):
        block=re.sub(r'^'+prop+r' = [^\n]+\n','',block,flags=re.M)
    return block.replace('\n','\nposition = Vector2(0, -32)\nscale = Vector2(0.68, 0.68)\ntexture_filter = 1\n',1)

def main():
    if not SOURCE.exists():
        raise SystemExit('Upload art/characters/forest_ranger_source.png first.')
    source=Image.open(SOURCE).convert('RGBA')
    if source.size!=(724,2172):
        raise SystemExit('Expected source 724x2172 (4 columns x 12 rows of 181 pixels).')
    atlas=Image.new('RGBA',(SIZE*4,SIZE*12),(0,0,0,0))
    for row in range(12):
        for col in range(4):
            img=source.crop((col*181,row*181,(col+1)*181,(row+1)*181))
            img=img.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
            img.putalpha(img.getchannel('A').point(lambda a:0 if a<24 else a))
            atlas.alpha_composite(img,(col*SIZE,row*SIZE))
    ATLAS.parent.mkdir(parents=True,exist_ok=True)
    atlas.save(ATLAS,optimize=True,compress_level=9)

    lines=['[gd_resource type="SpriteFrames" format=3]','',
           '[ext_resource type="Texture2D" path="res://art/characters/forest_ranger.png" id="1_ranger"]','']
    def frame_id(row,col): return f'AtlasTexture_ranger_{row}_{col}'
    for row in range(12):
        for col in range(4):
            lines.extend((f'[sub_resource type="AtlasTexture" id="{frame_id(row,col)}"]',
                          'atlas = ExtResource("1_ranger")',
                          f'region = Rect2({col*SIZE}, {row*SIZE}, {SIZE}, {SIZE})',''))
    animations=[]
    for action,start in (('idle',0),('walk',4),('attack',8)):
        for delta,direction in enumerate(('down','up','left','right')):
            row=start+delta
            sprites=', '.join('{"duration": 1.0, "texture": SubResource("%s")}' % frame_id(row,c) for c in range(4))
            animations.append('{"frames": ['+sprites+'], "loop": '+
                ('false' if action=='attack' else 'true')+
                ', "name": &"'+action+'_'+direction+'", "speed": '+
                ('6.0' if action=='walk' else '4.5')+'}')
    for action in ('hit','death'):
        for row,direction in enumerate(('down','up','left','right')):
            animations.append('{"frames": [{"duration": 1.0, "texture": SubResource("'+frame_id(row,0)+
                '")}], "loop": false, "name": &"'+action+'_'+direction+'", "speed": 5.0}')
    lines+=['[resource]','animations = ['+',\n'.join(animations)+']','']
    RESOURCE.write_text('\n'.join(lines),encoding='utf-8')

    scene=PLAYER.read_text(encoding='utf-8')
    patched,count=re.subn(r'\[node name="AnimatedSprite2D"[^\n]*\]\n(?:[^\[]*?)(?=\n\[node |\Z)',
                         lambda m:patch_visual(m.group(0)),scene,flags=re.S)
    if count!=1 or 'scale = Vector2(0.68, 0.68)' not in patched:
        raise SystemExit('Player.tscn changed: refusing to overwrite scene.')
    PLAYER.write_text(patched,encoding='utf-8')
    print('[RANGER] 48 frames, 20 native SpriteFrames animations, transparent PNG and updated player scene.')
if __name__=='__main__':
    main()
