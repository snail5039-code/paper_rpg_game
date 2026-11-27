"""주인공 쓰러짐·일어남 그림(ChatGPT, 자홍 바탕, 1줄 × 6칸) → 게임용 띠 assets/sprites/characters/player_down.png, player_wake.png

  python tools/import_player_fall.py           # 원본이 있는 것 전부
  python tools/import_player_fall.py wake      # 그것만
원본: assets/generated_pixel_art/ui_v7_raw/106_player_down.png, 106_player_wake.png
배율은 걷기 시트의 서 있는 모습(정면 가운데 칸)의 키에 맞춘다. 일어남은 마지막(서 있는) 칸, 쓰러짐은 첫(휘청) 칸이 기준이다.
여섯 칸 모두 같은 배율로 줄여 발(아래 가운데)을 맞춘다. 프롬프트는 docs/도트_프롬프트_stage1.md §106.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_ch1 as ch1  # noqa: E402
import map_v6_post as post  # noqa: E402
from sprites import sprite_path  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
MID = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7")
# 이름: (원본 이름, 기준 칸)
JOBS = {"down": ("106_player_down", 0), "wake": ("106_player_wake", 5)}


def stand_height():
    walk = Image.open(sprite_path("player_walk")).convert("RGBA")
    cw, ch = walk.width // 4, walk.height // 4
    bb = walk.crop((cw, 0, cw * 2, ch)).getbbox()
    return bb[3] - bb[1]


def import_one(key):
    raw, ref = JOBS[key]
    src = os.path.join(RAW, raw + ".png")
    if not os.path.isfile(src):
        return "없음"
    rgba, kc = post.chroma_key(Image.open(src))
    if rgba is None:
        return "바탕이 자홍이 아님 %s" % (kc,)
    rgba = post.drop_specks(rgba, min_area=40)
    a = rgba.astype(np.int16)
    spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
    a[..., 0] -= spill
    a[..., 2] -= spill
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    im.save(os.path.join(MID, raw + ".png"))
    pcs = ch1.cell_pieces(im, 6, 1, min_area=300)
    if len(pcs) < 6:
        return "칸이 모자람 (%d/6)" % len(pcs)
    s = stand_height() / pcs[(0, ref)][0].height
    mw = max(p.width for p, _ in pcs.values())
    mh = max(p.height for p, _ in pcs.values())
    pad = 4
    cw = int(np.ceil(mw * s)) + pad * 2
    chh = int(np.ceil(mh * s)) + pad * 2
    sheet = Image.new("RGBA", (cw * 6, chh), (0, 0, 0, 0))
    for c in range(6):
        p = pcs[(0, c)][0]
        nw, nh = max(1, round(p.width * s)), max(1, round(p.height * s))
        q = p.resize((nw, nh), Image.LANCZOS)
        sheet.paste(q, (c * cw + (cw - nw) // 2, chh - pad - nh))
    sheet.save(sprite_path("player_" + key))
    return "ok %dx%d (한 칸 %d, 서 있는 키 %d)" % (cw * 6, chh, cw, stand_height())


def main():
    only = set(sys.argv[1:])
    for k in JOBS:
        if only and k not in only:
            continue
        r = import_one(k)
        if r != "없음":
            print(k, r)


if __name__ == "__main__":
    main()
