"""모자 맞춤 미리보기: 모자 10종 × 앞·옆·뒤를 주인공 그림 위에 게임과 같은 계산으로 얹어 본다.

scripts/player.gd 의 HAT_FIT (크기 배율, 머리 꼭대기에서 모자 아랫단까지 길이) 를 고칠 때 쓴다.

  python3 tools/hat_preview.py            # artifacts/hat_preview.png 를 만든다
"""
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, "assets", "sprites")


def read_table(name):
    src = open(os.path.join(ROOT, "scripts", "player_anchors.gd"), encoding="utf-8").read()
    return eval(re.search(r"const %s := (\[.*\])" % name, src).group(1))


def read_fit():
    src = open(os.path.join(ROOT, "scripts", "player.gd"), encoding="utf-8").read()
    body = re.search(r"const HAT_FIT := (\[.*?\]\])", src, re.S).group(1)
    return eval(body)


def main():
    walk = read_table("WALK")
    fit = read_fit()
    sheet = Image.open(os.path.join(SP, "player_walk.png")).convert("RGBA")
    fw, fh = sheet.width // 4, sheet.height // 4
    pad = 40
    out = Image.new("RGBA", ((fw + pad) * 10, (fh + pad) * 3), (120, 150, 190, 255))
    for shape in range(10):
        k, drop = fit[shape]
        for view, row in enumerate([0, 1, 3]):      # 앞, 옆(왼쪽을 봄), 뒤
            frame = sheet.crop((fw, row * fh, fw * 2, row * fh + fh))
            cell = Image.new("RGBA", (fw + pad, fh + pad), (0, 0, 0, 0))
            cell.alpha_composite(frame, (pad // 2, pad))
            path = os.path.join(SP, "hat_%d_%d.png" % (shape, view))
            if os.path.isfile(path):
                hat = Image.open(path).convert("RGBA")
                hat = hat.resize((max(1, round(hat.width * k)), max(1, round(hat.height * k))), Image.LANCZOS)
                cx, top, _w = walk[row * 4 + 1]
                x = round(pad // 2 + cx - hat.width / 2)
                y = round(pad + top + drop - hat.height)
                cell.alpha_composite(hat, (x, y))
            out.alpha_composite(cell, (shape * (fw + pad), view * (fh + pad)))
    os.makedirs(os.path.join(ROOT, "artifacts"), exist_ok=True)
    out.save(os.path.join(ROOT, "artifacts", "hat_preview.png"))


if __name__ == "__main__":
    main()
