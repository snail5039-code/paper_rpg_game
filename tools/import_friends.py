"""합치기로만 나오는 친구의 그림(ChatGPT, 자홍 바탕 6칸) → 게임용 띠 assets/sprites/monsters/mon_friend_<종>.png

  python3 tools/import_friends.py
원본: assets/generated_pixel_art/ui_v7_raw/81_friend_<종>.png (자홍 바탕)
자홍을 지운 시트는 assets/generated_pixel_art/ui_v7/81_friend_<종>.png 에도 남긴다.
칸 순서는 1장 몬스터와 같다: 기본, 움직임 둘, 예고, 공격, 맞음. 발(아래 가운데)을 맞춘다.
프롬프트는 docs/도트_프롬프트_stage1.md 의 81번.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_ch1 as ch1  # noqa: E402  (strip: 칸 나누기와 발 맞추기)
import map_v6_post as post  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
MID = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7")

# 종 → 한 칸의 가로 크기(월드). 원래 몬스터와 비슷하게.
FRIENDS = {"linespider": 27.0, "snowflake": 28.0, "grassmallang": 24.0}


def main():
    os.chdir(ROOT)
    for sp, w in FRIENDS.items():
        src = os.path.join(RAW, "81_friend_%s.png" % sp)
        if not os.path.isfile(src):
            print("[없음]", sp)
            continue
        rgba, kc = post.chroma_key(Image.open(src))
        if rgba is None:
            print("[실패] 바탕이 자홍이 아님", sp, kc)
            continue
        rgba = post.drop_specks(rgba, min_area=30)
        mid = os.path.join(MID, "81_friend_%s.png" % sp)
        Image.fromarray(rgba, "RGBA").save(mid)
        old = ch1.SRC
        ch1.SRC = MID.replace("\\", "/") + "/"
        try:
            print(sp, ch1.strip("81_friend_%s" % sp, 6, 1, "mon_friend_%s" % sp, w))
        finally:
            ch1.SRC = old


if __name__ == "__main__":
    main()
