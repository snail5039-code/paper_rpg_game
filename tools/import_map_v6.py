"""map_v6 그림(후처리가 끝난 것) → 게임용 스프라이트(assets/sprites).

순서:  python3 tools/map_v6_post.py      (map_v6_raw → map_v6: 크기 맞춤, 투명화)
       python3 tools/import_map_v6.py    (map_v6 → assets/sprites)
       godot --headless --path . --import
"""
import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import import_ch1 as base  # noqa: E402  (cell_pieces, fit, scaled, save 를 같이 쓴다)
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprites import sprite_path

SRC = "assets/generated_pixel_art/map_v6/"
TEX = 3.0

BACKGROUNDS = {"17a_ch1_village": "bg_ch1_village", "17b_ch1_meadow": "bg_ch1_meadow",
               "17c_ch1_crossroad": "bg_ch1_crossroad", "17d_ch1_gridwoods": "bg_ch1_gridwoods",
               "17e_ch1_erasedroad": "bg_ch1_erasedroad"}
GROUNDS = {"18a_ground_grass": "ground_grass", "18b_ground_path": "ground_path", "18c_ground_water": "ground_water"}
BUILDINGS = ["house", "shop", "craft", "fishing", "villager_a", "villager_b", "storage", "board"]
PROPS = ["tree_round", "tree_pine", "bush", "flower_red", "flower_yellow",
         "fence_h", "fence_v", "rock", "stump", "grass",
         "bench", "lamp", "mailbox", "well", "signpost",
         "clothesline", "pot", "bridge", "stones", "scarecrow"]
# 소품의 가로 크기 (월드)
PROP_W = {"tree_round": 30, "tree_pine": 28, "bush": 24, "flower_red": 16, "flower_yellow": 16,
          "fence_h": 26, "fence_v": 9, "rock": 20, "stump": 20, "grass": 16,
          "bench": 28, "lamp": 12, "mailbox": 16, "well": 26, "signpost": 20,
          "clothesline": 36, "pot": 16, "bridge": 34, "stones": 28, "scarecrow": 24}
SKILLS = ["skill_slash", "skill_circle", "skill_dot", "skill_hatch", "skill_press", "skill_erase",
          "skill_sharpen", "skill_warmup", "skill_ult", "icon_coins", "icon_paper", "icon_paper_thick"]


def pieces(name, cols, rows, min_area=300):
    base.SRC = SRC
    im = base.load(name)
    return base.cell_pieces(im, cols, rows, min_area=min_area)


def by_width(img, world_w):
    return base.scaled(img, world_w * TEX / img.width)


def open_village_south_gate():
    """마을 충돌 마스크(mask_walk/mask_solid, 배경의 1/4 크기)에서 아래쪽 문 자리를 걸을 수 있게 뚫는다."""
    x0, x1, y0, y1 = 765 // 4, 850 // 4, 780 // 4, 941 // 4
    walk = Image.open(sprite_path("mask_walk")).convert("RGBA")
    ref = None
    for y in range(walk.height):   # 걸을 수 있는 칸의 색을 하나 찾는다
        for x in range(walk.width):
            if walk.getpixel((x, y))[3] > 128:
                ref = walk.getpixel((x, y))
                break
        if ref:
            break
    for y in range(y0, min(y1 + 1, walk.height)):
        for x in range(x0, x1):
            walk.putpixel((x, y), ref)
    walk.save(sprite_path("mask_walk"))
    solid = Image.open(sprite_path("mask_solid")).convert("RGBA")
    for y in range(y0, min(y1 + 1, solid.height)):
        for x in range(x0, x1):
            solid.putpixel((x, y), (0, 0, 0, 0))
    solid.save(sprite_path("mask_solid"))


## 2장 색연필 숲 배경 (python3 tools/import_map_v6.py ch2 로 이것만 옮긴다)
CH2_BACKGROUNDS = {"93a_ch2_village": "bg_ch2_village", "93b_ch2_path": "bg_ch2_path", "93c_ch2_grove": "bg_ch2_grove",
                   "93d_ch2_cliff": "bg_ch2_cliff", "93e_ch2_gray": "bg_ch2_gray", "93f_ch2_mushroom": "bg_ch2_mushroom",
                   "93g_ch2_bigtree": "bg_ch2_bigtree", "93h_ch2_bossroom": "bg_ch2_bossroom"}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "ch2":
        for src, dst in CH2_BACKGROUNDS.items():
            if os.path.isfile(SRC + src + ".png"):
                shutil.copyfile(SRC + src + ".png", sprite_path(dst))
                print("옮김:", dst)
        return
    for src, dst in BACKGROUNDS.items():
        shutil.copyfile(SRC + src + ".png", sprite_path(dst))
    for src, dst in GROUNDS.items():
        Image.open(SRC + src + ".png").convert("RGB").save(sprite_path(dst))

    open_village_south_gate()

    # 포탈 3칸: 열린 문, 잠긴 문, 방금 열린 문 (가로 30 월드)
    pcs = pieces("19_portal", 3, 1)
    s = 30 * TEX / pcs[(0, 0)][0].width
    for i, nm in enumerate(["portal_open", "portal_locked", "portal_new"]):
        base.save(base.scaled(pcs[(0, i)][0], s), nm)

    # 건물 8개 (가로 70 월드 안팎: 1장 마을의 집과 비슷한 크기)
    n = 0
    for sheet in ["20a_buildings", "20b_buildings"]:
        pcs = pieces(sheet, 4, 1)
        for c in range(4):
            base.save(by_width(pcs[(0, c)][0], 70), "bld_" + BUILDINGS[n])
            n += 1

    # 소품 20개
    n = 0
    for sheet in ["21a_props", "21b_props"]:
        pcs = pieces(sheet, 5, 2)
        for r in range(2):
            for c in range(5):
                nm = PROPS[n]
                base.save(by_width(pcs[(r, c)][0], PROP_W[nm]), "deco_" + nm)
                n += 1

    # 스킬 아이콘과 상점 물건 (64×64)
    pcs = pieces("22_skill_icons_pencil", 4, 3, min_area=30)   # 점선 별처럼 잘게 끊긴 그림이 있다
    for i, nm in enumerate(SKILLS):
        base.save(base.fit(pcs[(i // 4, i % 4)][0], 64, 64), nm)
    print("완료:", len(BACKGROUNDS) + len(GROUNDS) + 3 + 8 + 20 + len(SKILLS), "장")


if __name__ == "__main__":
    main()
