"""ui_v7 그림(창 부품, 스킬 효과, 필살기 일러스트) → 게임용 스프라이트(assets/sprites).

ChatGPT에서 받은 원본을 assets/generated_pixel_art/ui_v7_raw/ 에 넣고 실행한다.
프롬프트는 docs/도트_프롬프트_ui_v7.md.

  python3 tools/import_ui_v7.py
  godot --headless --path . --import

하는 일: 마젠타 바탕을 투명하게 → 칸마다 그림을 잘라 냄 → 크기를 줄여 저장.
          처리한 시트는 assets/generated_pixel_art/ui_v7/ 에도 남긴다 (투명 바탕).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import map_v6_post as post  # noqa: E402  (chroma_key, drop_specks 를 같이 쓴다)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
MID = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7")
OUT = os.path.join(ROOT, "assets", "sprites")

# 시트 이름: (칸 수 가로, 세로, [(저장 이름, 긴 변 크기)] 왼쪽 위부터)
SHEETS = {
    "23_ui_kit": (4, 3, [
        ("ui_row", 300), ("ui_btn_sq", 72), ("ui_btn_sq_on", 72), ("ui_close", 60),
        ("ui_scroll_track", 240), ("ui_scroll_knob", 72), ("ui_arrow_l", 66), ("ui_arrow_r", 66),
        ("ui_board", 240), ("icon_dust", 64), ("ui_tag", 120), ("ui_plaque", 240)]),
    "24_skill_fx": (4, 2, [
        ("fx_slash", 240), ("fx_circle", 288), ("fx_dot", 96), ("fx_hatch", 150),
        ("fx_press", 192), ("fx_erase", 150), ("fx_hit", 96), ("fx_star", 240)]),
}
# 통짜 그림: (저장 이름, 가로, 가운데에서 남길 세로 비율)
FULL = {"25_ult_cutin": ("ult_cutin", 1280, 0.62)}


def cell_images(rgba, cols, rows):
    """칸마다, 그 칸에 가운데가 들어 있는 조각을 모두 합쳐 잘라 낸다."""
    h, w = rgba.shape[:2]
    lab, n = ndimage.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    boxes = {}
    for i, sl in enumerate(ndimage.find_objects(lab)):
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        k = (min(rows - 1, int(cy // (h / rows))), min(cols - 1, int(cx // (w / cols))))
        b = boxes.get(k)
        box = [sl[1].start, sl[0].start, sl[1].stop, sl[0].stop]
        boxes[k] = box if b is None else [min(b[0], box[0]), min(b[1], box[1]), max(b[2], box[2]), max(b[3], box[3])]
    return {k: Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]], "RGBA") for k, b in boxes.items()}


def main():
    os.makedirs(MID, exist_ok=True)
    count = 0
    for name, (cols, rows, parts) in SHEETS.items():
        src = os.path.join(RAW, name + ".png")
        if not os.path.isfile(src):
            print("[없음] %s" % name)
            continue
        rgba, kc = post.chroma_key(Image.open(src))
        if rgba is None:
            print("[실패] %s: 바탕이 마젠타가 아님 %s" % (name, kc))
            continue
        rgba = post.drop_specks(rgba, min_area=30)
        Image.fromarray(rgba, "RGBA").save(os.path.join(MID, name + ".png"))
        cells = cell_images(rgba, cols, rows)
        for i, (out_name, size) in enumerate(parts):
            k = (i // cols, i % cols)
            if k not in cells:
                print("[빈 칸] %s %s" % (name, out_name))
                continue
            im = cells[k]
            if out_name != "fx_erase":   # 가장자리에 남은 마젠타 물을 뺀다 (분홍 지우개 가루는 그대로 둔다)
                a = np.asarray(im).astype(np.int16)
                spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
                a[..., 0] -= spill
                a[..., 2] -= spill
                im = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
            s = size / max(im.size)
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            im.save(os.path.join(OUT, out_name + ".png"))
            count += 1
    for name, (out_name, width, band) in FULL.items():
        src = os.path.join(RAW, name + ".png")
        if not os.path.isfile(src):
            print("[없음] %s" % name)
            continue
        im = Image.open(src).convert("RGB")
        im.save(os.path.join(MID, name + ".png"))
        bh = round(im.height * band)
        y0 = (im.height - bh) // 2
        im = im.crop((0, y0, im.width, y0 + bh))
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        im.save(os.path.join(OUT, out_name + ".png"))
        count += 1
    print("완료: %d장" % count)


if __name__ == "__main__":
    main()
