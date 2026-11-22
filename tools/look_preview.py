"""옷·도구 맞춤 미리보기: 게임(scripts/player.gd 의 _place_tool)과 같은 계산으로 도구를 주먹에 놓아 본다.

줄 = 옷과 도구 번호 (같은 번호끼리), 칸 = 걷기 네 방향과 공격 장면들. → artifacts/look_preview.png
TOOL_TUCK 이나 자리 표(tools/player_anchors.py)를 고칠 때 쓴다.

  python3 tools/look_preview.py
"""
import math
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, "assets", "sprites")
K = 3                    # 보기 좋게 키우는 배율
TOOL_K = 0.5
TUCK = 6.0
PAD = 30


def read_table(name):
    src = open(os.path.join(ROOT, "scripts", "player_anchors.gd"), encoding="utf-8").read()
    return eval(re.search(r"const %s := (\[.*\])" % name, src).group(1))


def compose(sheet, cols, fw, fh, r, c, spot, tool, swinging):
    frame = sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)).resize((fw * K, fh * K), Image.LANCZOS)
    cell = Image.new("RGBA", ((fw + PAD * 2) * K, (fh + PAD * 2) * K), (0, 0, 0, 0))
    x, y, dx, dy, ln, front = spot
    full = tool.height * TOOL_K
    tuck = 0.0 if front else min(TUCK, full * 0.25)
    length = full if swinging else min(full, ln + tuck)
    part = tool.crop((0, 0, tool.width, max(1, round(length / TOOL_K))))
    part = part.resize((max(1, round(part.width * TOOL_K * K)), max(1, round(part.height * TOOL_K * K))), Image.LANCZOS)
    ang = math.degrees(math.atan2(dy, dx)) + 90.0
    part = part.rotate(-ang, expand=True, resample=Image.BICUBIC)
    cx = (PAD + x - dx * tuck + dx * length * 0.5) * K
    cy = (PAD + y - dy * tuck + dy * length * 0.5) * K
    pos = (round(cx - part.width / 2), round(cy - part.height / 2))
    if front:
        cell.alpha_composite(frame, (PAD * K, PAD * K))
        cell.alpha_composite(part, pos)
    else:
        cell.alpha_composite(part, pos)
        cell.alpha_composite(frame, (PAD * K, PAD * K))
    return cell


def main():
    wt, at = read_table("WALK_TOOL"), read_table("ATTACK_TOOL")
    shots = [("walk", 0, 1), ("walk", 1, 1), ("walk", 2, 0), ("walk", 3, 1),
             ("attack", 0, 0), ("attack", 0, 1), ("attack", 1, 1), ("attack", 2, 1), ("attack", 3, 2)]
    rows = []
    for n in range(10):
        walk = Image.open(os.path.join(SP, "player_walk_c%d.png" % n)).convert("RGBA")
        attack = Image.open(os.path.join(SP, "player_attack_c%d.png" % n)).convert("RGBA")
        tool = Image.open(os.path.join(SP, "tool_%d.png" % n)).convert("RGBA")
        cells = []
        for kind, r, c in shots:
            if kind == "walk":
                cells.append(compose(walk, 4, 95, 114, r, c, wt[r * 4 + c], tool, False))
            else:
                cells.append(compose(attack, 3, 162, 114, r, c, at[r * 3 + c], tool, True))
        row = Image.new("RGBA", (sum(c.width for c in cells), cells[0].height), (120, 150, 190, 255))
        x = 0
        for c in cells:
            row.alpha_composite(c, (x, 0))
            x += c.width
        rows.append(row)
    out = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)), (120, 150, 190, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    os.makedirs(os.path.join(ROOT, "artifacts"), exist_ok=True)
    out.save(os.path.join(ROOT, "artifacts", "look_preview.png"))
    out.crop((0, 0, out.width, rows[0].height * 5)).resize((out.width // 2, rows[0].height * 5 // 2), Image.LANCZOS).save(os.path.join(ROOT, "artifacts", "_lp_a.png"))
    out.crop((0, rows[0].height * 5, out.width, out.height)).resize((out.width // 2, rows[0].height * 5 // 2), Image.LANCZOS).save(os.path.join(ROOT, "artifacts", "_lp_b.png"))


if __name__ == "__main__":
    main()
