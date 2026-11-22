"""튜토리얼 장 "연습 페이지" 의 배경 13장을 게임용 그림으로 바꾼다.

원본: assets/generated_pixel_art/ui_v7_raw/50_tut_<번호>.png  (ChatGPT 에서 받은 16:9 그림)
결과: assets/sprites/bg_tut_<번호>.png  (1672×941, 사냥터 배경과 같은 크기)

몬스터와 선생 그림은 tools/import_ui_v7.py 의 51, 52 번 시트로 가져온다.
선생의 얼굴(대화 창)은 여기서 선생 시트의 윗부분을 잘라 만든다: assets/sprites/portrait_tnpc_<번호>.png

  python3 tools/import_tut.py
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_v6_post as post  # noqa: E402
import import_ui_v7 as ui  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
OUT = os.path.join(ROOT, "assets", "sprites")
BG_W, BG_H = 1672, 941


def cover(im, w, h):
    s = max(w / im.width, h / im.height)
    im2 = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    x = (im2.width - w) // 2
    y = (im2.height - h) // 2
    return im2.crop((x, y, x + w, y + h))


def main():
    done = 0
    for n in range(1, 14):
        src = os.path.join(RAW, "50_tut_%d.png" % n)
        if not os.path.isfile(src):
            print("[없음] 50_tut_%d" % n)
            continue
        cover(Image.open(src).convert("RGB"), BG_W, BG_H).save(os.path.join(OUT, "bg_tut_%d.png" % n))
        done += 1
    print("완료: 배경 %d장" % done)
    faces()


FACE_PART = 0.6          # 선생 그림의 위쪽 이만큼이 얼굴과 어깨
FACE_H = 168             # 다른 얼굴 그림(portrait_*)과 같은 높이


def faces():
    """선생 시트에서 머리와 어깨를 잘라 대화 창의 얼굴 그림으로 쓴다."""
    done = 0
    for name, cols, rows, first in [("52_tut_npc_a", 4, 2, 1), ("52_tut_npc_b", 3, 2, 9)]:
        src = os.path.join(RAW, name + ".png")
        if not os.path.isfile(src):
            print("[없음] %s" % name)
            continue
        rgba, _kc = post.chroma_key(Image.open(src))
        rgba = post.drop_specks(rgba, min_area=30)
        a = rgba.astype(np.int16)
        spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
        a[..., 0] -= spill
        a[..., 2] -= spill
        cells = ui.cell_images(a.clip(0, 255).astype(np.uint8), cols, rows)
        for (r, c), im in cells.items():
            n = first + r * cols + c
            if n > 13:
                continue
            top = im.crop((0, 0, im.width, round(im.height * FACE_PART)))
            k = FACE_H / top.height
            top = top.resize((max(1, round(top.width * k)), FACE_H), Image.LANCZOS)
            top.save(os.path.join(OUT, "portrait_tnpc_%d.png" % n))
            done += 1
    print("완료: 얼굴 %d장" % done)


if __name__ == "__main__":
    main()
