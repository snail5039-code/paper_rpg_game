"""ch1_v5 원본 시트 → 게임용 스프라이트(assets/sprites) 변환기.

실행:  python3 tools/import_ch1.py            (프로젝트 폴더에서)
그다음: godot --headless --path . --import

규칙
  - 스프라이트는 1텍셀 = 1/3 월드. 목표 크기는 월드 단위로 적고 TEX 배를 곱한다.
  - 칸 경계를 넘는 그림이 있어서, 칸이 아니라 "그림 덩어리"를 찾아 중심이 든 칸에 배정한다.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "assets/generated_pixel_art/ch1_v5/"
OUT = "assets/sprites/"
TEX = 3.0


PART_NAMES = {
    "ui": ["window", "note", "button", "button_on", "tab", "tab_on", "slot", "slot_on", "cursor",
           "stamp_0", "stamp_1", "stamp_2", "divider"],
    "hud": ["hp_frame", "hp_fill", "exp_frame", "exp_fill", "pencil_0", "slot_skill", "slot_erased",
            "pencil_1", "pencil_2", "slot_item", "pencil_3", "slot_torn", "pencil_4", "pencil_5"],
}


def to_h(im, h):
    s = h / im.height
    return im.resize((max(1, round(im.width * s)), h), Image.LANCZOS)


def load(name):
    im = Image.open(SRC + name + ".png").convert("RGBA")
    a = np.array(im)
    a[a[:, :, 3] < 40] = 0  # 옅은 얼룩 제거
    return Image.fromarray(a)


def cell_pieces(im, cols, rows, min_area=150):
    """덩어리를 칸에 배정해 칸별 (크롭 이미지, 칸 안에서의 bbox) 를 돌려준다."""
    a = np.array(im)
    mask = a[:, :, 3] > 0
    # 가까운 조각(점박이의 점, 끊긴 선)은 한 덩어리로 묶이지 않아도 된다: 중심 기준으로 배정
    lab, n = ndimage.label(mask)
    h, w = mask.shape
    cw, ch = w / cols, h / rows
    boxes = [[None for _ in range(cols)] for _ in range(rows)]
    keep = np.zeros((rows, cols, h, w), dtype=bool) if rows * cols <= 24 and h * w < 3_000_000 else None
    objs = ndimage.find_objects(lab)
    cell_masks = {}
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        comp = lab[sl] == (i + 1)
        if comp.sum() < min_area:
            continue
        ys, xs = np.nonzero(comp)
        cy = sl[0].start + ys.mean()
        cx = sl[1].start + xs.mean()
        c = min(cols - 1, int(cx / cw))
        r = min(rows - 1, int(cy / ch))
        m = cell_masks.setdefault((r, c), np.zeros((h, w), dtype=bool))
        m[sl] |= comp
    out = {}
    for (r, c), m in cell_masks.items():
        ys, xs = np.nonzero(m)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        piece = a[y0:y1, x0:x1].copy()
        piece[~m[y0:y1, x0:x1]] = 0
        out[(r, c)] = (Image.fromarray(piece), (x0, y0, x1, y1))
    return out


def save(im, name):
    im.save(OUT + name + ".png")


def fit(im, w, h):
    """비율을 지키며 w×h 안에 맞춰 가운데 놓는다."""
    s = min(w / im.width, h / im.height)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    r = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(r, ((w - nw) // 2, (h - nh) // 2))
    return canvas


def strip(name, cols, rows, out_name, target_world, by="w", pad=4):
    """움직임 시트 → 같은 크기 칸의 격자 시트. 모든 프레임에 같은 배율을 쓰고 발(아래 가운데)을 맞춘다.
    칸 안에서의 원래 위치(통통 튀는 높이)는 버리고 아래쪽에 붙인다."""
    im = load(name)
    pcs = cell_pieces(im, cols, rows)
    mw = max(p.width for p, _ in pcs.values())
    mh = max(p.height for p, _ in pcs.values())
    ref = pcs[(0, 0)][0]
    base = ref.width if by == "w" else ref.height
    s = target_world * TEX / base
    cw = int(np.ceil(mw * s)) + pad * 2
    ch = int(np.ceil(mh * s)) + pad * 2
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (0, 0, 0, 0))
    for (r, c), (p, _) in pcs.items():
        nw, nh = max(1, round(p.width * s)), max(1, round(p.height * s))
        q = p.resize((nw, nh), Image.LANCZOS)
        sheet.paste(q, (c * cw + (cw - nw) // 2, r * ch + ch - pad - nh))
    save(sheet, out_name)
    return cw, ch


def singles(name, cols, rows, names, size=None, target_h_world=None, target_w_world=None):
    im = load(name)
    pcs = cell_pieces(im, cols, rows)
    for idx, nm in enumerate(names):
        key = (idx // cols, idx % cols)
        if key not in pcs:
            print("  ! 빈 칸:", name, key)
            continue
        p = pcs[key][0]
        if size:
            p = fit(p, size, size)
        elif target_h_world:
            s = target_h_world * TEX / p.height
            p = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
        elif target_w_world:
            s = target_w_world * TEX / p.width
            p = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
        save(p, nm)


def components(name, min_area=400):
    """시트의 덩어리들을 (bbox, 이미지) 목록으로. 위→아래, 왼→오 순서."""
    im = load(name)
    a = np.array(im)
    mask = a[:, :, 3] > 0
    mask2 = ndimage.binary_dilation(mask, iterations=6)  # 가까운 조각은 한 물건으로
    lab, n = ndimage.label(mask2)
    res = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        comp = (lab[sl] == (i + 1)) & mask[sl]
        if comp.sum() < min_area:
            continue
        ys, xs = np.nonzero(comp)
        x0, y0 = sl[1].start + xs.min(), sl[0].start + ys.min()
        x1, y1 = sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1
        piece = a[y0:y1, x0:x1].copy()
        sub = lab[y0:y1, x0:x1] == (i + 1)
        piece[~sub] = 0
        res.append(((x0, y0, x1, y1), Image.fromarray(piece)))
    return res


def scaled(im, s):
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)

    # 01 흰 자국: 마을 배경의 집 크기에 맞춘다 (배경 1672px = 640 월드)
    singles("01_white_marks", 4, 1, ["mark_house_big"], target_w_world=110)
    im = load("01_white_marks")
    pcs = cell_pieces(im, 4, 1)
    for key, nm, w in [((0, 1), "mark_house_small", 88), ((0, 2), "mark_tree", 46), ((0, 3), "mark_person", 22)]:
        p = pcs[key][0]
        save(scaled(p, w * TEX / p.width), nm)

    # 02, 03 지워진 슬라임 (4자세: 기본, 납작, 점프, 맞음)
    for src, pre, w in [("02_slime_faded", "slimef", 15.0), ("03_slime_erased", "slimee", 24.0)]:
        im = load(src)
        pcs = cell_pieces(im, 4, 1)
        s = w * TEX / pcs[(0, 0)][0].width
        for i, f in enumerate(["idle", "squash", "jump", "hurt"]):
            save(scaled(pcs[(0, i)][0], s), "%s_%s" % (pre, f))

    # 04 말랑이
    print("mallang cell", strip("04_mallang_walk", 4, 4, "mallang_walk", 22.0))
    p = load("04_mallang_portrait")
    bb = p.getbbox()
    save(to_h(p.crop(bb), 150), "portrait_mallang")

    # 05 몬스터 5종 × 2모습 (6칸: 기본, 움직임1, 움직임2, 예고, 공격, 맞음)
    for src, mid, w in [("05a_squiggle", "squiggle", 30.0), ("05b_dots", "dots", 28.0), ("05c_grass", "grass", 22.0),
                        ("05d_gridspider", "spider", 26.0), ("05e_dustbug", "bug", 30.0)]:
        for form in ["faded", "erased"]:
            print(mid, form, strip("%s_%s" % (src, form), 6, 1, "mon_%s_%s" % (mid, form), w))

    # 06 프롤로그 컷
    for i, n in enumerate(["06a_prologue_phone", "06b_prologue_room", "06c_prologue_drawer"]):
        Image.open(SRC + n + ".png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT + "prologue_%d.png" % i)

    # 07 초상화 (기존 초상화와 같은 124×151)
    im = load("07_portraits_ch1")
    pcs = cell_pieces(im, 4, 1, min_area=2000)
    for i, nm in enumerate(["haru_blank", "haru_sad", "player_surprised", "player_sad"]):
        save(to_h(pcs[(0, i)][0], 168), "portrait_" + nm)

    # 08 주민
    singles("08_villagers_ch1", 3, 1, ["villager_0", "villager_1", "villager_2"], target_h_world=38)

    # 09 공용 UI, 10 HUD: 덩어리 순서대로 저장 (이름은 ui_parts 로 매긴다)
    for src, pre, s in [("09_ui_common", "ui", 0.3), ("10_hud", "hud", 0.3)]:
        comps = components(src)
        comps.sort(key=lambda c: (c[0][1] // 60, c[0][0]))
        if len(comps) != len(PART_NAMES[pre]):
            print("  ! %s 덩어리 수가 다름: %d" % (src, len(comps)))
        for (bb, p), nm in zip(comps, PART_NAMES[pre]):
            save(scaled(p, 0.6 if nm == "window" else s), "%s_%s" % (pre, nm))

    # 11~15 아이콘 (64×64)
    singles("11_stat_icons", 4, 4, ["stat_%d" % i for i in range(16)], size=64)
    for src, slot in [("12a_tools", "tool"), ("12b_hats", "hat"), ("12c_clothes", "cloth"),
                      ("12d_shoes", "shoe"), ("12e_bags", "bag"), ("12f_accessories", "acc")]:
        singles(src, 5, 2, ["equip_%s_%d" % (slot, i) for i in range(10)], size=64)
    singles("13_materials_ch1", 4, 3, ["mat_%d" % i for i in range(12)], size=64)
    singles("14_consumables", 5, 2, ["item_%d" % i for i in range(10)], size=64)
    singles("15_misc_icons", 4, 2, ["misc_%d" % i for i in range(8)], size=64)

    # 16 문방구
    im = load("16a_shopkeeper")
    pcs = cell_pieces(im, 3, 1, min_area=2000)
    p = pcs[(0, 0)][0]
    save(scaled(p, 42 * TEX / p.height), "shopkeeper")
    save(to_h(pcs[(0, 1)][0], 168), "portrait_shop_smile")
    save(to_h(pcs[(0, 2)][0], 168), "portrait_shop_think")
    Image.open(SRC + "16b_shop_shelf.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT + "shop_bg.png")
    print("완료")


if __name__ == "__main__":
    main()
