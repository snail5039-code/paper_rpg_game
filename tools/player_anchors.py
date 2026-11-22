"""주인공 그림(걷기 4×4, 공격 3×4)의 프레임마다 머리 자리를 재서 scripts/player_anchors.gd 로 적는다.

모자를 프레임마다 머리 위에 정확히 얹기 위한 표다. 주인공 그림이 바뀌면 다시 돌린다.

  python3 tools/player_anchors.py

재는 것 (프레임 왼쪽 위 기준, 텍셀): 머리(머리카락 포함)의 가운데 x, 꼭대기 y, 너비.
노란 연필은 머리 위로 올라갈 수 있어서 빼고 잰다.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEAD_ROWS = 28          # 꼭대기에서 이만큼 아래까지를 머리(머리카락)로 본다 (텍셀). 팔이 들어가지 않게 짧게 잡는다


def frames(name, cols, rows):
    im = np.asarray(Image.open(os.path.join(ROOT, "assets", "sprites", name + ".png")).convert("RGBA")).astype(np.int32)
    fh, fw = im.shape[0] // rows, im.shape[1] // cols
    out = []
    for r in range(rows):
        for c in range(cols):
            f = im[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw]
            solid = f[..., 3] > 128
            yellow = (f[..., 0] > 190) & (f[..., 1] > 140) & (f[..., 2] < 120)
            # 연필 둘레의 테두리까지 빼려고 노란 곳을 조금 넓힌다
            near = yellow.copy()
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    near |= np.roll(np.roll(yellow, dy, 0), dx, 1)
            mask = solid & ~near
            # 가장 큰 가로 덩어리가 시작되는 줄을 꼭대기로 본다 (삐죽 나온 한두 점은 무시)
            counts = mask.sum(axis=1)
            top = int(np.argmax(counts >= 6))
            head = mask[top:top + HEAD_ROWS]
            xs = np.where(head.any(axis=0))[0]
            out.append([round(float(xs.min() + xs.max()) / 2, 1), top, int(xs.max() - xs.min() + 1)])
    return out, fw, fh


def main():
    walk, ww, wh = frames("player_walk", 4, 4)
    attack, aw, ah = frames("player_attack", 3, 4)
    lines = [
        "extends RefCounted",
        "## 주인공 그림의 프레임마다 머리 자리 (tools/player_anchors.py 가 만든다. 직접 고치지 않는다)",
        "##  [가운데 x, 꼭대기 y, 너비] 텍셀, 프레임 왼쪽 위 기준. 순서는 줄 × 칸 (줄 = 방향: 정면, 왼쪽, 오른쪽, 뒷면)",
        "",
        "const WALK_FRAME := Vector2(%d, %d)" % (ww, wh),
        "const ATTACK_FRAME := Vector2(%d, %d)" % (aw, ah),
        "const WALK := %s" % walk,
        "const ATTACK := %s" % attack,
        "",
    ]
    with open(os.path.join(ROOT, "scripts", "player_anchors.gd"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("walk", walk)
    print("attack", attack)


if __name__ == "__main__":
    main()
