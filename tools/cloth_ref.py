"""옷마다 캐릭터 그림을 새로 받을 때 ChatGPT 에 붙여 줄 기준 그림을 만든다.

걷기(4×4) 를 위에, 공격(3×4) 을 아래에 놓고 자홍 바탕에 두 배로 키운다. → artifacts/cloth_ref.png
받은 그림은 tools/import_cloth.py 가 같은 배치로 잘라 낸다.

  python3 tools/cloth_ref.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprites import sprite_path
W, H = 608, 912          # 2:3 (ChatGPT 의 세로 그림 비율). 걷기와 공격을 가운데에 놓는다


def main():
    walk = Image.open(sprite_path("player_walk")).convert("RGBA")
    attack = Image.open(sprite_path("player_attack")).convert("RGBA")
    out = Image.new("RGBA", (W, H), (255, 0, 255, 255))
    out.alpha_composite(walk, ((W - walk.width) // 2, 0))
    out.alpha_composite(attack, ((W - attack.width) // 2, H // 2))
    out = out.resize((W * 2, H * 2), Image.NEAREST).convert("RGB")
    os.makedirs(os.path.join(ROOT, "artifacts"), exist_ok=True)
    out.save(os.path.join(ROOT, "artifacts", "cloth_ref.png"))


if __name__ == "__main__":
    main()
