"""옷마다 새로 받은 캐릭터 그림(걷기 4×4 + 공격 3×4, 연필 없는 맨손)을 게임용 그림으로 바꾼다.

원본: assets/generated_pixel_art/ui_v7_raw/40_cloth_<옷 번호>.png  (tools/cloth_ref.py 의 배치 그대로)
결과: assets/sprites/player_walk_c<번호>.png, player_attack_c<번호>.png  (원래 그림과 같은 크기, 같은 칸)

받은 그림은 자리가 조금씩 어긋나므로, 프레임마다 머리(머리카락)를 원래 그림의 머리 자리에 맞춰 놓는다.
그래서 모자 자리 표(scripts/player_anchors.gd)를 옷마다 따로 만들 필요가 없다.

  python3 tools/import_cloth.py            # 있는 것 전부
  python3 tools/import_cloth.py 3          # 3번 옷만
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_v6_post as post  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
OUT = os.path.join(ROOT, "assets", "sprites")
W, H = 608, 912                      # cloth_ref.py 의 배치 (게임 그림 크기 기준)
WALK = (4, 4, 95, 114, (W - 380) // 2, 0)        # 칸 수, 줄 수, 칸 너비, 칸 높이, 왼쪽, 위
ATTACK = (3, 4, 162, 114, (W - 486) // 2, H // 2)
HEAD_ROWS = 28


def read_table(name):
    src = open(os.path.join(ROOT, "scripts", "player_anchors.gd"), encoding="utf-8").read()
    return eval(re.search(r"const %s := (\[.*\])" % name, src).group(1))


def head_of(a):
    """그림(RGBA 배열)의 머리 가운데 x 와 꼭대기 y"""
    mask = a[..., 3] > 128
    counts = mask.sum(axis=1)
    top = int(np.argmax(counts >= 6))
    xs = np.where(mask[top:top + HEAD_ROWS].any(axis=0))[0]
    return (xs.min() + xs.max()) / 2.0, top


def one(num):
    src = os.path.join(RAW, "40_cloth_%d.png" % num)
    if not os.path.isfile(src):
        return False
    rgba, kc = post.chroma_key(Image.open(src))
    if rgba is None:
        print("[실패] %d: 바탕이 마젠타가 아님" % num)
        return False
    rgba = post.drop_specks(rgba, min_area=30)
    # 가장자리에 남은 마젠타 물을 뺀다
    a = rgba.astype(np.int16)
    spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
    a[..., 0] -= spill
    a[..., 2] -= spill
    rgba = a.clip(0, 255).astype(np.uint8)
    k = rgba.shape[1] / float(W)       # 받은 그림 / 게임 그림 배율
    lab, _n = ndimage.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    report = []
    for name, (cols, rows, fw, fh, left, top), table in [("walk", WALK, read_table("WALK")), ("attack", ATTACK, read_table("ATTACK"))]:
        sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
        for r in range(rows):
            for c in range(cols):
                # 이 칸에 가운데가 들어 있는 조각을 모두 합친다
                x0, y0 = (left + c * fw) * k, (top + r * fh) * k
                box = None
                for sl in objs:
                    cy, cx = (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2
                    if x0 <= cx < x0 + fw * k and y0 <= cy < y0 + fh * k:
                        b = [sl[1].start, sl[0].start, sl[1].stop, sl[0].stop]
                        box = b if box is None else [min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3])]
                if box is None:
                    print("[빈 칸] %d %s %d,%d" % (num, name, r, c))
                    continue
                im = Image.fromarray(rgba[box[1]:box[3], box[0]:box[2]], "RGBA")
                im = im.resize((max(1, round(im.width / k)), max(1, round(im.height / k))), Image.LANCZOS)
                hx, hy = head_of(np.asarray(im))
                want = table[r * cols + c]
                px, py = round(want[0] - hx), round(want[1] - hy)
                cell = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
                cell.alpha_composite(im, (px, py)) if (px >= 0 and py >= 0) else cell.paste(im, (px, py), im)
                sheet.alpha_composite(cell, (c * fw, r * fh))
                report.append(im.height)
        sheet.save(os.path.join(OUT, "player_%s_c%d.png" % (name, num)))
    print("옷 %d: 배율 %.3f, 키 %d~%d" % (num, k, min(report), max(report)))
    return True


def main():
    nums = [int(x) for x in sys.argv[1:]] or range(10)
    done = sum(1 for n in nums if one(n))
    print("완료: %d벌" % done)


if __name__ == "__main__":
    main()
