"""assets/sprites 아래 종류별 폴더를 다루는 공용 도구.

어느 폴더에 넣을지는 tools/sprite_folders.json 이 정한다 (게임은 이름만으로 찾으므로 폴더를 몰라도 된다).
  from sprites import sprite_path
  im.save(sprite_path("bld_forge"))     # → assets/sprites/buildings/bld_forge.png (폴더가 없으면 만든다)
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
_RULES = json.load(open(os.path.join(ROOT, "tools", "sprite_folders.json"), encoding="utf-8"))["rules"]


def folder_of(name):
    for folder, prefixes in _RULES:
        for p in prefixes:
            if name == p or name.startswith(p + "_"):
                return folder
    return "etc"


def sprite_path(name):
    """그 이름의 스프라이트가 들어갈 (또는 들어 있는) 파일 경로. 이름에 .png 는 붙이지 않는다."""
    if name.endswith(".png"):
        name = name[:-4]
    d = os.path.join(SPRITES, folder_of(name))
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name + ".png")
