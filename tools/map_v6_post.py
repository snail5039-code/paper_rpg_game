"""map_v6 그림 후처리.

ChatGPT에서 받은 원본(assets/generated_pixel_art/map_v6_raw/)을 게임에 쓸 크기와 형식으로
맞춰 assets/generated_pixel_art/map_v6/ 에 저장한다. 프롬프트는 docs/도트_프롬프트_map_v6.md.

  python tools/map_v6_post.py            # 원본 폴더에 있는 것 전부
  python tools/map_v6_post.py 19 21a     # 이름이 이 글자로 시작하는 것만
  python tools/map_v6_post.py --raw <폴더> --out <폴더>

하는 일
  배경 (17a~17e)   : 1672x941 RGB로 가운데 기준 잘라 맞춤. 미리보기에 문 자리(변 가운데 220px)를 표시.
  바닥 질감 (18a~c): 512x512 RGB. 밝기 얼룩을 고르게 하고 가장자리를 겹쳐 섞어 이음매를 없앤다.
  시트 (19~22)     : 마젠타 바탕을 투명하게 바꾸고, 칸마다 그림을 찾아 칸 가운데에 다시 놓는다
                     (가장자리 여백 10% 이상). 원본이 이미 투명하면 그대로 쓴다.
  미리보기          : <원본 폴더>/_preview/ 에 저장. 시트는 파란 바탕 + 노란 칸 선, 질감은 2x2 이어 붙임.

필요한 것: Pillow, numpy, scipy
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, "assets", "generated_pixel_art", "map_v6_raw")
OUT_DIR = os.path.join(ROOT, "assets", "generated_pixel_art", "map_v6")
EXTS = (".png", ".webp", ".jpg", ".jpeg")

BG_W, BG_H, GATE = 1672, 941, 220

# 이름: (종류, 설정)
#   bg    -> 문이 있는 변 목록
#   tex   -> 없음
#   sheet -> (가로, 세로, 칸 수 가로, 칸 수 세로, 크기 맞춤, 세로 정렬)
#            크기 맞춤 "uniform": 모든 칸을 같은 배율로 (서로의 크기 비율 유지)
#                      "percell": 칸마다 따로 (칸에 넘칠 때만 줄임)
SPECS = {
    "17a_ch1_village": ("bg", ["bottom"]),
    "17b_ch1_meadow": ("bg", ["right"]),
    "17c_ch1_crossroad": ("bg", ["top", "bottom", "left", "right"]),
    "17d_ch1_gridwoods": ("bg", ["left"]),
    "17e_ch1_erasedroad": ("bg", ["top"]),
    "18a_ground_grass": ("tex", None),
    "18b_ground_path": ("tex", None),
    "18c_ground_water": ("tex", None),
    "19_portal": ("sheet", (2172, 724, 3, 1, "uniform", "bottom")),
    "20a_buildings": ("sheet", (2172, 724, 4, 1, "uniform", "bottom")),
    "20b_buildings": ("sheet", (2172, 724, 4, 1, "uniform", "bottom")),
    "21a_props": ("sheet", (1280, 512, 5, 2, "uniform", "center")),
    "21b_props": ("sheet", (1280, 512, 5, 2, "uniform", "center")),
    "22_skill_icons_pencil": ("sheet", (1024, 768, 4, 3, "percell", "center")),
}


# ---------------------------------------------------------------- 배경

def cover(im, w, h):
    s = max(w / im.width, h / im.height)
    im2 = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    x = (im2.width - w) // 2
    y = (im2.height - h) // 2
    return im2.crop((x, y, x + w, y + h))


def do_bg(src, dst, prev, gates):
    im = Image.open(src).convert("RGB")
    notes = []
    ratio = im.width / im.height
    if abs(ratio - BG_W / BG_H) > 0.03:
        cut = 1 - min(ratio, BG_W / BG_H) / max(ratio, BG_W / BG_H)
        notes.append("원본 비율 %.2f (목표 1.78) → 가장자리 %.0f%% 잘림, 문 자리 확인" % (ratio, cut * 100))
    out = cover(im, BG_W, BG_H)
    out.save(dst)
    p = out.copy()
    d = ImageDraw.Draw(p)
    cx, cy, g = BG_W // 2, BG_H // 2, GATE // 2
    red = (255, 0, 0)
    for side in gates:
        if side == "top":
            d.rectangle([cx - g, 0, cx + g, 14], outline=red, width=3)
        elif side == "bottom":
            d.rectangle([cx - g, BG_H - 15, cx + g, BG_H - 1], outline=red, width=3)
        elif side == "left":
            d.rectangle([0, cy - g, 14, cy + g], outline=red, width=3)
        elif side == "right":
            d.rectangle([BG_W - 15, cy - g, BG_W - 1, cy + g], outline=red, width=3)
    p.save(prev)
    return notes


# ---------------------------------------------------------------- 바닥 질감

def seam_ratio(a):
    """이음매 양쪽의 차이 / 그림 안쪽 이웃 픽셀의 차이. 1에 가까우면 이음매가 안 보인다."""
    a = a.astype(np.float32)
    sx = np.abs(a[:, 0] - a[:, -1]).mean() / max(np.abs(a[:, 1:] - a[:, :-1]).mean(), 1e-3)
    sy = np.abs(a[0] - a[-1]).mean() / max(np.abs(a[1:] - a[:-1]).mean(), 1e-3)
    return sx, sy


def do_tex(src, dst, prev, n=512, band=96):
    im = Image.open(src).convert("RGB")
    m = n + band
    s = max(m / min(im.size), 0.5)  # 결이 뭉개지지 않게 절반까지만 줄인다
    im2 = im.resize((max(m, round(im.width * s)), max(m, round(im.height * s))), Image.LANCZOS)
    x = (im2.width - m) // 2
    y = (im2.height - m) // 2
    a = np.asarray(im2.crop((x, y, x + m, y + m))).astype(np.float32)
    # 넓게 퍼진 밝기 얼룩을 없애 반복될 때 티가 덜 나게 한다
    low = np.stack([ndimage.gaussian_filter(a[..., c], 60, mode="reflect") for c in range(3)], -1)
    a = a - low + low.mean(axis=(0, 1), keepdims=True)
    # 남는 띠(band)를 반대쪽 가장자리에 겹쳐 섞는다
    t = np.linspace(0, 1, band, dtype=np.float32)
    t = t * t * (3 - 2 * t)
    o = a[:, :n].copy()
    o[:, :band] = a[:, n:n + band] * (1 - t)[None, :, None] + a[:, :band] * t[None, :, None]
    a = o
    o = a[:n].copy()
    o[:band] = a[n:n + band] * (1 - t)[:, None, None] + a[:band] * t[:, None, None]
    out = np.clip(o, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(dst)
    tile = Image.new("RGB", (n * 2, n * 2))
    for i in range(2):
        for j in range(2):
            tile.paste(Image.fromarray(out, "RGB"), (i * n, j * n))
    tile.save(prev)
    sx, sy = seam_ratio(out)
    notes = []
    if max(sx, sy) > 1.6:
        notes.append("이음매가 남았을 수 있음 (가로 %.2f, 세로 %.2f, 1에 가까울수록 좋음)" % (sx, sy))
    return notes


# ---------------------------------------------------------------- 시트

def chroma_key(im):
    """테두리 색(마젠타)을 바탕으로 보고 투명하게 바꾼다."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    edge = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3),
                           a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    kc = np.median(edge, axis=0)
    km = min(kc[0], kc[2]) - kc[1]
    if km < 80:
        return None, kc
    m = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
    lo, hi = 0.30 * km, 0.80 * km
    alpha = 1 - np.clip((m - lo) / (hi - lo), 0, 1)
    # 반투명 가장자리에서 바탕색을 빼 낸다
    al = np.clip(alpha, 0.05, 1)[..., None]
    fg = np.clip((a - (1 - al) * kc) / al, 0, 255)
    lim = fg[..., 1] + 40
    edge_px = alpha < 0.999
    for c in (0, 2):
        ch = fg[..., c]
        ch[edge_px] = np.minimum(ch[edge_px], lim[edge_px])
    rgba = np.dstack([fg, alpha * 255]).astype(np.uint8)
    rgba[rgba[..., 3] < 12, 3] = 0
    return rgba, kc


def drop_specks(rgba, min_area=40):
    lab, n = ndimage.label(rgba[..., 3] > 40, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(np.ones(lab.shape), lab, np.arange(1, n + 1))
        keep = np.isin(lab, np.where(sizes >= min_area)[0] + 1)
        # 큰 덩어리 둘레의 반투명 가장자리는 남긴다
        keep = ndimage.binary_dilation(keep, iterations=2)
        rgba[~keep, 3] = 0
    return rgba


def resize_rgba(arr, w, h):
    f = arr.astype(np.float32)
    al = f[..., 3:4] / 255
    pm = np.dstack([f[..., :3] * al, f[..., 3:4]])
    pm = np.dstack([np.asarray(Image.fromarray(pm[..., c]).resize((w, h), Image.LANCZOS)) for c in range(4)])
    al = np.clip(pm[..., 3:4], 0, 255)
    rgb = np.where(al > 0.5, pm[..., :3] / np.maximum(al / 255, 1e-3), 0)
    return np.dstack([np.clip(rgb, 0, 255), al]).astype(np.uint8)


def do_sheet(src, dst, prev, spec, margin=0.10):
    W, H, cols, rows, mode, valign = spec
    im = Image.open(src)
    notes = []
    rgba = None
    if im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info:
        cand = np.asarray(im.convert("RGBA")).copy()
        if (cand[..., 3] < 10).mean() > 0.2:
            rgba = cand
    if rgba is None:
        rgba, kc = chroma_key(im)
        if rgba is None:
            return ["바탕이 마젠타도 투명도 아님 (테두리 색 %s) → 처리하지 않음. 다시 받아야 함"
                    % (tuple(int(v) for v in kc),)], False
    rgba = drop_specks(rgba)
    sh, sw = rgba.shape[:2]
    scw, sch = sw / cols, sh / rows
    cw, ch = W / cols, H / rows

    lab, n = ndimage.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    cells = {}
    crossing = 0
    for i, sl in enumerate(ndimage.find_objects(lab)):
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        c = min(cols - 1, int(cx // scw))
        r = min(rows - 1, int(cy // sch))
        cells.setdefault((r, c), []).append(i + 1)
        big = (sl[1].stop - sl[1].start) * (sl[0].stop - sl[0].start) > 0.02 * scw * sch
        if big and (sl[1].start < c * scw - 2 or sl[1].stop > (c + 1) * scw + 2
                    or sl[0].start < r * sch - 2 or sl[0].stop > (r + 1) * sch + 2):
            crossing += 1
    if crossing:
        notes.append("원본에서 칸 경계를 넘는 그림 %d개 (칸이 고르지 않거나 서로 붙었을 수 있음, 미리보기 확인)" % crossing)
    missing = [(r + 1, c + 1) for r in range(rows) for c in range(cols) if (r, c) not in cells]
    if missing:
        notes.append("빈 칸 (줄, 칸): %s" % missing)
    if not cells:
        return notes + ["그림을 찾지 못함"], False

    boxes = {}
    for k, ids in cells.items():
        mask = np.isin(lab, ids)
        ys, xs = np.where(mask)
        boxes[k] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, mask)
    fit = {k: min(cw * (1 - 2 * margin) / (b[2] - b[0]), ch * (1 - 2 * margin) / (b[3] - b[1]))
           for k, b in boxes.items()}
    natural = min(cw / scw, ch / sch)
    if mode == "uniform":
        s_all = min(natural, min(fit.values()))
        scale = {k: s_all for k in boxes}
    else:
        scale = {k: min(natural, fit[k]) for k in boxes}

    out = np.zeros((H, W, 4), np.uint8)
    row_h = {}
    for (r, c), b in boxes.items():
        row_h[r] = max(row_h.get(r, 0), round((b[3] - b[1]) * scale[(r, c)]))
    for (r, c), (x0, y0, x1, y1, mask) in boxes.items():
        crop = rgba[y0:y1, x0:x1].copy()
        crop[~mask[y0:y1, x0:x1], 3] = 0
        s = scale[(r, c)]
        nw, nh = max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s))
        px = round(c * cw + (cw - nw) / 2)
        if valign == "bottom":  # 같은 줄의 그림은 바닥 높이를 맞춘다
            py = round(r * ch + (ch + row_h[r]) / 2 - nh)
        else:
            py = round(r * ch + (ch - nh) / 2)
        out[py:py + nh, px:px + nw] = resize_rgba(crop, nw, nh)
    Image.fromarray(out, "RGBA").save(dst)

    p = Image.new("RGBA", (W, H), (70, 110, 190, 255))
    p.alpha_composite(Image.fromarray(out, "RGBA"))
    d = ImageDraw.Draw(p)
    for c in range(1, cols):
        d.line([(W * c / cols, 0), (W * c / cols, H)], fill=(255, 255, 0, 255), width=2)
    for r in range(1, rows):
        d.line([(0, H * r / rows), (W, H * r / rows)], fill=(255, 255, 0, 255), width=2)
    p.convert("RGB").save(prev)
    return notes, True


# ---------------------------------------------------------------- 실행

def find_raw(raw_dir, name):
    for ext in EXTS:
        for cand in (name + ext, name + ext.upper()):
            p = os.path.join(raw_dir, cand)
            if os.path.isfile(p):
                return p
    return None


def main():
    ap = argparse.ArgumentParser(description="map_v6 그림 후처리")
    ap.add_argument("names", nargs="*", help="처리할 그림 이름의 앞부분 (예: 19 21a). 비우면 전부")
    ap.add_argument("--raw", default=RAW_DIR, help="원본 폴더")
    ap.add_argument("--out", default=OUT_DIR, help="결과 폴더")
    args = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    targets = [n for n in SPECS if not args.names or any(n.startswith(p) for p in args.names)]
    if not targets:
        print("맞는 이름이 없습니다:", " ".join(args.names))
        return 2
    if not os.path.isdir(args.raw):
        print("원본 폴더가 없습니다: %s\n이 폴더를 만들고 ChatGPT에서 받은 그림을 넣어 주세요." % args.raw)
        return 2
    prev_dir = os.path.join(args.raw, "_preview")
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)

    done, warned, failed, missing = [], [], [], []
    for name in targets:
        kind, spec = SPECS[name]
        src = find_raw(args.raw, name)
        if not src:
            missing.append(name)
            continue
        dst = os.path.join(args.out, name + ".png")
        prev = os.path.join(prev_dir, name + ".png")
        try:
            ok = True
            if kind == "bg":
                notes = do_bg(src, dst, prev, spec)
            elif kind == "tex":
                notes = do_tex(src, dst, prev)
            else:
                notes, ok = do_sheet(src, dst, prev, spec)
        except Exception as e:  # 한 장이 깨져도 나머지는 계속한다
            notes, ok = ["오류: %r" % (e,)], False
        if not ok:
            failed.append(name)
            print("[실패] %s" % name)
        else:
            with Image.open(dst) as o:
                info = "%dx%d %s" % (o.width, o.height, o.mode)
            (warned if notes else done).append(name)
            print("[%s] %s.png  %s" % ("확인" if notes else "완료", name, info))
        for n_ in notes:
            print("       - " + n_)

    print()
    print("완료 %d, 확인 필요 %d, 실패 %d, 원본 없음 %d (대상 %d개)"
          % (len(done), len(warned), len(failed), len(missing), len(targets)))
    if missing:
        print("원본이 없는 그림 (%s 에 이 이름으로 저장):" % args.raw)
        for n_ in missing:
            print("  - %s.png" % n_)
    print("결과: %s" % args.out)
    print("미리보기: %s" % prev_dir)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
