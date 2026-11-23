"""몬스터 84종 그림(ChatGPT, 자홍 바탕, 2줄 × 6칸) → 게임용 띠 assets/sprites/monsters/mon_m<번호>_faded.png, _erased.png

  python3 tools/import_monsters.py            # 원본이 있는 것 전부
  python3 tools/import_monsters.py 7 8 12     # 그 번호만
원본: assets/generated_pixel_art/ui_v7_raw/84_mon_m<번호>.png  (위 줄: 조금 지워진 모습, 아래 줄: 많이 지워진 모습)
자홍을 지운 시트는 assets/generated_pixel_art/ui_v7/84_mon_m<번호>.png 에도 남긴다.
칸 순서는 1장 몬스터와 같다: 기본, 움직임 둘, 예고, 공격, 맞음. 두 줄 모두 같은 배율로 줄이고 발(아래 가운데)을 맞춘다.
몬스터 표는 tools/monster_list.py, 프롬프트는 docs/도트_프롬프트_monsters.md.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_ch1 as ch1  # noqa: E402  (cell_pieces)
import map_v6_post as post  # noqa: E402
from monster_list import NEW  # noqa: E402
from sprites import sprite_path  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
MID = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7")
TEX = 3.0
WIDTH = {"hop": 26.0, "dash": 28.0, "swarm": 24.0, "ambush": 24.0, "grid": 26.0, "roll": 30.0}   # 한 칸 첫 그림의 가로(월드)


# "희미하게" 그려져 게임에서 안 보이는 것: 불투명도를 올리고 선을 진하게 한다
FAINT = {81: 2.6, 85: 3.0, 86: 2.6}


def bolden(im, k):
    a = np.asarray(im).astype(np.float32)
    a[..., 3] = (a[..., 3] * k).clip(0, 255)
    a[..., :3] *= 0.82
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def grey_out(im, keep=0.25):
    """많이 지워진 모습: 원본은 옅은 칠이 자홍 바탕과 섞여 분홍빛이 돈다. 1장 몬스터처럼 회색에 가깝게 뺀다 (색은 keep 만큼만 남긴다)."""
    a = np.asarray(im).astype(np.float32)
    rgb = a[..., :3]
    lum = (rgb * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(-1, keepdims=True)
    grey = np.concatenate([lum * 1.0, lum * 0.985, lum * 0.975], -1)    # 아주 살짝 따뜻한 회색
    a[..., :3] = grey * (1.0 - keep) + rgb * keep
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def import_one(num, arch):
    src = os.path.join(RAW, "84_mon_m%02d.png" % num)
    if not os.path.isfile(src):
        return "없음"
    rgba, kc = post.chroma_key(Image.open(src))
    if rgba is None:
        return "바탕이 자홍이 아님 %s" % (kc,)
    rgba = post.drop_specks(rgba, min_area=30)
    a = rgba.astype(np.int16)
    spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
    a[..., 0] -= spill
    a[..., 2] -= spill
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    im.save(os.path.join(MID, "84_mon_m%02d.png" % num))
    pcs = ch1.cell_pieces(im, 6, 2)
    if len(pcs) < 12:
        return "칸이 모자람 (%d/12)" % len(pcs)
    ref = pcs[(0, 0)][0]
    s = WIDTH[arch] * TEX / ref.width
    mw = max(p.width for p, _ in pcs.values())
    mh = max(p.height for p, _ in pcs.values())
    pad = 4
    cw = int(np.ceil(mw * s)) + pad * 2
    chh = int(np.ceil(mh * s)) + pad * 2
    for r, form in enumerate(["faded", "erased"]):
        sheet = Image.new("RGBA", (cw * 6, chh), (0, 0, 0, 0))
        for c in range(6):
            p = pcs[(r, c)][0]
            nw, nh = max(1, round(p.width * s)), max(1, round(p.height * s))
            q = p.resize((nw, nh), Image.LANCZOS)
            sheet.paste(q, (c * cw + (cw - nw) // 2, chh - pad - nh))
        if num in FAINT:
            sheet = bolden(sheet, FAINT[num])
        if form == "erased":
            sheet = grey_out(sheet)
        sheet.save(sprite_path("mon_m%02d_%s" % (num, form)))
    return "ok %dx%d" % (cw, chh)


def main():
    only = {int(x) for x in sys.argv[1:]}
    done = 0
    for num, name, ch, arch, _ in NEW:
        if only and num not in only:
            continue
        r = import_one(num, arch)
        if r != "없음":
            print(num, name, r)
            done += 1 if r.startswith("ok") else 0
    print("완료:", done)


if __name__ == "__main__":
    main()
