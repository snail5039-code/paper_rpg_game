"""보스 움직임 그림(ChatGPT, 자홍 바탕, 1줄 × 6칸) → 게임용 띠 assets/sprites/monsters/<보스 그림>_anim.png

  python tools/import_boss_anim.py              # 원본이 있는 것 전부
  python tools/import_boss_anim.py boss_3 tm_13 # 그것만
원본: assets/generated_pixel_art/ui_v7_raw/104_boss_anim_<보스 그림>.png
칸 순서는 띠 몬스터와 같다: 기본, 걷기 둘, 예고, 공격, 맞음.
첫 칸의 가로를 지금 한 장짜리 보스 그림의 가로에 맞추고(게임 속 크기가 그대로), 여섯 칸 모두 같은 배율로 줄여 발(아래 가운데)을 맞춘다.
프롬프트는 docs/도트_프롬프트_stage1.md §104.
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
BOSSES = ["tm_13", "boss_0", "boss_1", "boss_2", "boss_3", "boss_4", "boss_5"]


def import_one(name):
    src = os.path.join(RAW, "104_boss_anim_%s.png" % name)
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
    im.save(os.path.join(MID, "104_boss_anim_%s.png" % name))
    pcs = ch1.cell_pieces(im, 6, 1, min_area=300)
    if len(pcs) < 6:
        return "칸이 모자람 (%d/6)" % len(pcs)
    single = Image.open(sprite_path(name))
    sb = single.getbbox()
    s = (sb[2] - sb[0]) / pcs[(0, 0)][0].width
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
    out = sprite_path(name + "_anim")
    sheet.save(out)
    return "ok %dx%d (한 칸 %d, 원래 그림 가로 %d)" % (cw * 6, chh, cw, single.width)


def main():
    only = set(sys.argv[1:])
    for n in BOSSES:
        if only and n not in only:
            continue
        r = import_one(n)
        if r != "없음":
            print(n, r)


if __name__ == "__main__":
    main()
