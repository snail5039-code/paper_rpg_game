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
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprites import sprite_path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7_raw")
MID = os.path.join(ROOT, "assets", "generated_pixel_art", "ui_v7")

# 시트 이름: (칸 수 가로, 세로, [(저장 이름, 긴 변 크기)] 왼쪽 위부터)
HAT_SCALE = 0.26     # 원본(가로 약 1620) 의 모자가 주인공 머리(약 64 텍셀)에 맞는 배율
TOOL_SCALE = 0.17    # 원본(가로 1536) 의 긴 연필이 주인공 그림 텍셀의 두 배 크기(약 72)가 되는 배율. 게임에서 절반으로 줄여 그린다
BLD_SCALE = -0.5     # 음수: 가로 1774 인 원본을 기준으로 한 배율 (원본 크기가 달라도 같은 크기가 된다)
BLD_SCALE_2ROW = -0.66   # 두 줄로 받은 시트는 건물이 작게 그려져 있어서 조금 덜 줄인다
SHEETS = {
    "23_ui_kit": (4, 3, [
        ("ui_row", 300), ("ui_btn_sq", 72), ("ui_btn_sq_on", 72), ("ui_close", 60),
        ("ui_scroll_track", 240), ("ui_scroll_knob", 72), ("ui_arrow_l", 66), ("ui_arrow_r", 66),
        ("ui_board", 240), ("icon_dust", 64), ("ui_tag", 120), ("ui_plaque", 240)]),
    "24_skill_fx": (4, 2, [
        ("fx_slash", 240), ("fx_circle", 288), ("fx_dot", 96), ("fx_hatch", 150),
        ("fx_press", 192), ("fx_erase", 150), ("fx_hit", 96), ("fx_star", 240)]),
    "26_food": (4, 3, [("food_%d" % i, 64) for i in range(12)]),
    "27_crops": (4, 4, [("crop_%d" % i, 64) for i in range(8)] + [("icon_seed", 64), ("forage_0", 64), ("forage_1", 64), ("forage_2", 64),
                         ("forage_3", 64), ("icon_bread", 64), ("icon_water", 64), ("icon_heart", 64)]),
    "28_dishes": (4, 3, [("dish_%d" % i, 64) for i in range(8)] + [("bld_farm", 210), ("bld_diner", 210), ("crop_sprout", 48), ("deco_balloon", 72)]),
    "29_furniture": (4, 3, [("furn_%d" % i, 120) for i in range(12)]),
    "30_bosses": (3, 1, [("boss_%d" % i, 300) for i in range(3)]),
    # 모자: 줄 = 보는 쪽 (앞, 옆, 뒤), 칸 = 모자. 크기가 1 보다 작으면 "긴 변" 이 아니라 줄이는 배율이다.
    "33_hats_a": (5, 3, [("hat_%d_%d" % (c, v), HAT_SCALE) for v in range(3) for c in range(5)]),
    "34_hats_b": (5, 3, [("hat_%d_%d" % (c + 5, v), HAT_SCALE) for v in range(3) for c in range(5)]),
    # 손에 드는 도구 10종 (촉이 위, 쥐는 쪽이 아래). 모두 같은 배율로 줄여야 서로의 길이가 맞는다.
    "41_tools": (5, 2, [("tool_%d" % i, TOOL_SCALE) for i in range(10)]),
    # 생활 도구: 낚싯대, 갈퀴, 낫 (쥐는 쪽이 아래), 물뿌리개 (주둥이가 왼쪽), 찌, 물보라
    "43_life_tools": (3, 2, [("life_rod", 124), ("life_rake", 104), ("life_sickle", 64), ("life_can", 60), ("life_bobber", 48), ("life_splash", 48)]),
    # 수업을 끝낼 때 찍히는 "참 잘했어요" 도장, 축하 별가루
    "44_stamp": (2, 1, [("ui_stamp", 160), ("ui_confetti", 200)]),
    # 튜토리얼 장 "연습 페이지": 맵마다 몬스터 한 종, 선생 한 명 (선생의 얼굴은 tools/import_tut.py 가 이 그림에서 잘라 만든다)
    "51_tut_mon_a": (4, 2, [("tm_%d" % i, 96) for i in range(1, 9)]),
    "51_tut_mon_b": (3, 2, [("tm_9", 96), ("tm_10", 96), ("tm_11", 96), ("tm_12", 96), ("tm_13", 180), ("tm_spare", 96)]),
    "52_tut_npc_a": (4, 2, [("tnpc_%d" % i, 130) for i in range(1, 9)]),
    "52_tut_npc_b": (3, 2, [("tnpc_%d" % i, 130) for i in range(9, 14)] + [("tnpc_spare", 130)]),
    # 건물 단계 그림: 1·2·4·5단계 (3단계는 원래 그림 bld_<이름>.png). 크기가 서로 맞게 모두 같은 배율로 줄인다.
    "60_bld_house": (4, 1, [("bld_house_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    "60_bld_shop": (4, 1, [("bld_shop_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    "60_bld_craft": (4, 1, [("bld_craft_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    "60_bld_storage": (4, 1, [("bld_storage_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    "60_bld_board": (4, 1, [("bld_board_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    "60_bld_fishing": (4, 1, [("bld_fishing_l%d" % lv, BLD_SCALE) for lv in (1, 2, 4, 5)]),
    # 두 건물을 한 장에 받은 것: 윗줄과 아랫줄
    "60_bld_villager": (4, 2, [("bld_villager_%s_l%d" % (ab, lv), BLD_SCALE_2ROW) for ab in ("a", "b") for lv in (1, 2, 4, 5)]),
    "60_bld_farmdiner": (4, 2, [("bld_%s_l%d" % (nm, lv), BLD_SCALE_2ROW) for nm in ("farm", "diner") for lv in (1, 2, 4, 5)]),
    # 유일 장비: 구겨진 별 아이콘, 만년필 아이콘, 손에 드는 만년필 (긴 도구와 같은 길이)
    "42_uniques": (3, 1, [("unique_star", 64), ("unique_pen", 64), ("tool_unique_pen", 74)]),
    # 1단계 마무리 (docs/도트_프롬프트_stage1.md). 5단계를 한 줄로 받은 건물은 3단계가 기본 그림이다.
    "60_bld_pen": (5, 1, [("bld_pen_l1", BLD_SCALE), ("bld_pen_l2", BLD_SCALE), ("bld_pen", BLD_SCALE), ("bld_pen_l4", BLD_SCALE), ("bld_pen_l5", BLD_SCALE)]),
    "60_bld_museum": (5, 1, [("bld_museum_l1", BLD_SCALE), ("bld_museum_l2", BLD_SCALE), ("bld_museum", BLD_SCALE), ("bld_museum_l4", BLD_SCALE), ("bld_museum_l5", BLD_SCALE)]),
    "73_vgift": (3, 2, [("vgift_%d" % i, 64) for i in range(6)]),
    # 세트 모자: 줄은 앞·옆·뒤, 칸은 지우개·구김·낙서. 같은 모양의 원래 모자(야구 모자 2, 종이 왕관 5, 털모자 3)와 같은 폭으로 맞춘다
    "75_set_hats": (3, 3, [("hat_set_%s_%d" % (s, v), "match:hat_%d_%d" % (sh, v)) for v in range(3) for s, sh in (("eraser", 2), ("crumple", 5), ("scribble", 3))]),
    # 세트 도구 (손에 드는 그림): 같은 모양의 원래 도구와 같은 긴 변으로 맞춘다
    "76_set_tools": (3, 1, [("tool_set_eraser", "match:tool_6"), ("tool_set_crumple", "match:tool_2"), ("tool_set_scribble", "match:tool_9")]),
    # 직접 만드는 주민의 부품 (종이 인형): 몸 4, 옷 6, 얼굴 6. 겹치는 자리는 scripts/ui/villager_maker.gd 가 몸 크기를 기준으로 정한다
    "77_villager_parts": (4, 4, [("cv_body_%d" % i, 96) for i in range(4)] + [("cv_cloth_%d" % i, 96) for i in range(6)]
        + [("cv_face_%d" % i, 96) for i in range(6)]),
    "60_bld_forge": (5, 1, [("bld_forge_l1", BLD_SCALE), ("bld_forge_l2", BLD_SCALE), ("bld_forge", BLD_SCALE), ("bld_forge_l4", BLD_SCALE), ("bld_forge_l5", BLD_SCALE)]),
    # 강화 연출: 모루, 든 망치, 내려치는 망치, 불꽃 / 성공, 실패, 파괴, 코팅지
    "78_forge_fx": (4, 2, [("forge_anvil", 160), ("forge_hammer_up", 160), ("forge_hammer_hit", 160), ("forge_spark", 160),
        ("forge_ok", 200), ("forge_fail", 160), ("forge_broken", 180), ("forge_saved", 160)]),
    # 물고기 50종 중 새 42종 (5×3 시트 셋), 채집 50종 중 새 46종 (4×3 시트 넷). 이름 순서는 scripts/data/items.gd 의 fish_*, fg_*
    "82_fish_a": (5, 3, [("fish_%d" % i, 64) for i in range(0, 15)]),
    "82_fish_b": (5, 3, [("fish_%d" % i, 64) for i in range(15, 30)]),
    "82_fish_c": (5, 3, [("fish_%d" % i, 64) for i in range(30, 42)]),
    "83_forage_a": (4, 3, [("forage_%d" % i, 64) for i in range(4, 16)]),
    "83_forage_b": (4, 3, [("forage_%d" % i, 64) for i in range(16, 28)]),
    "83_forage_c": (4, 3, [("forage_%d" % i, 64) for i in range(28, 40)]),
    "83_forage_d": (4, 3, [("forage_%d" % i, 64) for i in range(40, 50)] + [("life_net", 124)]),
    # 박물관 가구 (비어 있음, 전시물은 게임이 넣는다): 수조, 곤충 표본장, 꽃 화단, 진열 탁자, 코르크 판, 유리 진열장, 안내 데스크, 부엉이 관장
    # 공책 마을 아래쪽 문: 사냥터 팻말(가운데가 비어 있어 글자를 얹는다), 아래를 가리키는 크레용 화살표
    "87_gate_sign": (2, 1, [("deco_sign_hunt", 150), ("ui_arrow_down", 72)]),
    # 몬스터 공격 효과: 예고 느낌표, 할퀴기, 맞힘 별, 먼지, 땅 충격파, 보스 내리치기 자리, 돌진 속도선, 낙서 뭉치
    "88_mon_fx": (4, 2, [("fx_mon_alert", 96), ("fx_mon_claw", 120), ("fx_mon_impact", 120), ("fx_mon_dust", 110),
                         ("fx_mon_shock", 200), ("fx_mon_target", 200), ("fx_mon_speed", 120), ("fx_mon_scribble", 110)]),
    # 몬스터마다 다른 맞힘 효과 (scripts/data/mon_fx_data.gd 가 몬스터에 하나씩 정한다)
    "89_mon_hit_a": (4, 2, [("fx_hit_%s" % n, 120) for n in ["lead", "shavings", "sticky", "band", "thorn", "spore", "crayon", "petal"]]),
    "89_mon_hit_b": (4, 2, [("fx_hit_%s" % n, 120) for n in ["paint", "ink", "water", "bubble", "zap", "tack", "clip", "note"]]),
    "89_mon_hit_c": (4, 2, [("fx_hit_%s" % n, 120) for n in ["popcorn", "confetti", "marks", "stamp", "tape", "paper", "chalk", "fade"]]),
    # 몬스터 전용 맞힘 효과 72종 (90_mon_hit_d~l)
    "90_mon_hit_d": (4, 2, [("fx_hit_%s" % n, 120) for n in ["goo", "dotspray", "blades", "web", "acorn", "spiral", "feather", "chips"]]),
    "90_mon_hit_e": (4, 2, [("fx_hit_%s" % n, 120) for n in ["moss", "lily", "pincer", "squid", "rainbow", "palette", "wash", "clang"]]),
    "90_mon_hit_f": (4, 2, [("fx_hit_%s" % n, 120) for n in ["smear", "ruler", "glow", "signal", "rail", "marker", "rain", "pop"]]),
    "90_mon_hit_g": (4, 2, [("fx_hit_%s" % n, 120) for n in ["horseshoe", "ticket", "candy", "cymbal", "bulb", "capsule", "mirror", "strike"]]),
    "90_mon_hit_h": (4, 2, [("fx_hit_%s" % n, 120) for n in ["hooks", "ellipsis", "spacebar", "underline", "bang", "bracket", "lint", "staple"]]),
    "90_mon_hit_i": (4, 2, [("fx_hit_%s" % n, 120) for n in ["bite", "crane", "corner", "glue", "ribbon", "bunny", "crumbs", "clap"]]),
    "90_mon_hit_j": (4, 2, [("fx_hit_%s" % n, 120) for n in ["scrape", "broken", "crow", "slipper", "clock", "grade", "sting", "whiteclaw"]]),
    "90_mon_hit_k": (4, 2, [("fx_hit_%s" % n, 120) for n in ["balloon", "spout", "dotwing", "pierce", "paperslash", "fog", "rainbowscribble", "eraserbig"]]),
    "90_mon_hit_l": (4, 2, [("fx_hit_%s" % n, 120) for n in ["crumple", "storm", "typo", "question", "stub", "strand", "cross", "check"]]),
    # 2장 색연필 숲 보스: 큰나무 할아범(대장), 색 빠진 왕버섯(중간), 색 먹는 애벌레(필드)와 맞힘 효과
    "91_ch2_bosses": (3, 1, [("boss_3", 300), ("boss_4", 300), ("boss_5", 300)]),
    "91_ch2_boss_fx": (3, 1, [("fx_hit_roots", 120), ("fx_hit_greyspore", 120), ("fx_hit_colorbite", 120)]),
    # 2장 사람들: 귀퉁이, 숲 마을 주민 셋(화가 곰, 덩굴 할머니, 되풀이 주민), 얼굴 그림, 재료 10종
    "94_ch2_people": (4, 1, [("npc_gutungi", 124), ("villager_3", 120), ("villager_4", 118), ("villager_5", 118)]),
    "94_ch2_portraits": (3, 1, [("portrait_gutungi_smirk", 168), ("portrait_gutungi_quiet", 168), ("portrait_oak", 168)]),
    "95_ch2_mats": (5, 2, [("mat_%d" % i, 64) for i in range(12, 22)]),
    # 생활 도구 등급 아이콘: 칸 = 낚싯대·잠자리채·낫·갈퀴·물뿌리개, 줄 = 나무·쇠·금
    "96_life_icons": (5, 3, [("life_icon_%s_%d" % (k, g), 64) for g in range(3) for k in ["rod", "net", "sickle", "rake", "can"]]),
    "86_museum_props": (4, 2, [("prop_tank", 260), ("prop_bugcase", 150), ("prop_planter", 220), ("prop_table", 220),
                               ("prop_board", 170), ("prop_showcase", 170), ("prop_desk", 200), ("npc_curator", 120)]),
    # HUD 메뉴 단추 (가방, 능력치, 스킬, 지도, 친구, 도감, 설정)
    "80_menu_btns": (7, 1, [("menu_%s" % n, 48) for n in ("bag", "stats", "skills", "map", "friends", "dex", "settings")]),
    "74_set_icons": (6, 3, [("set_%s_%s" % (s, sl), 64) for s in ("eraser", "crumple", "scribble") for sl in ("tool", "hat", "cloth", "shoe", "bag", "acc")]),
}
# 비스듬히 그려져 와서 세워야 하는 도구: 이름 → 돌릴 각도(반시계). 크기는 세운 뒤의 높이
UPRIGHT = {"life_net": 45}
# 칸을 자르지 않고 그대로 이어 붙이는 애니메이션 띠: (칸 수, 저장 이름, 한 칸의 가로)
STRIPS = {"79_aura": (4, "fx_aura", 120)}
# 사냥터 배경처럼 1672 × 941 로 가운데를 잘라 맞추는 그림 (끝없는 탑)
COVER = {"72_bg_tower_0": "bg_tower_0", "72_bg_tower_1": "bg_tower_1", "72_bg_tower_boss": "bg_tower_boss"}
# 통짜 그림: (저장 이름, 가로, 가운데에서 남길 세로 비율)
FULL = {"25_ult_cutin": ("ult_cutin", 1280, 0.62), "31_room_bg": ("bg_room", 1280, 1.0), "32_title": ("bg_title", 1280, 1.0),
        # 건물 안 방 배경 (내 집의 방과 같은 크기와 배치)
        "61_room_shop": ("bg_room_shop", 1280, 1.0), "61_room_craft": ("bg_room_craft", 1280, 1.0),
        "61_room_storage": ("bg_room_storage", 1280, 1.0), "61_room_diner": ("bg_room_diner", 1280, 1.0),
        "61_room_villager": ("bg_room_villager", 1280, 1.0), "85_bg_museum": ("bg_room_museum", 1280, 1.0)}


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


def gap_images(rgba, cols, rows):
    """칸 크기가 고르지 않은 시트용: 줄마다 조각을 왼쪽부터 늘어놓고, 가장 넓은 틈에서 끊어 cols 개로 나눈다."""
    h, w = rgba.shape[:2]
    lab, _n = ndimage.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    out = {}
    for r in range(rows):
        parts = []
        for sl in ndimage.find_objects(lab):
            cy = (sl[0].start + sl[0].stop) / 2
            if min(rows - 1, int(cy // (h / rows))) == r:
                parts.append([sl[1].start, sl[0].start, sl[1].stop, sl[0].stop])
        parts.sort()
        if not parts:
            continue
        # 겹치거나 붙은 조각을 먼저 합친다
        groups = [parts[0][:]]
        for b in parts[1:]:
            g = groups[-1]
            if b[0] <= g[2]:
                g[0], g[1], g[2], g[3] = min(g[0], b[0]), min(g[1], b[1]), max(g[2], b[2]), max(g[3], b[3])
            else:
                groups.append(b[:])
        # 묶음이 cols 개가 될 때까지 가장 좁은 틈부터 합친다
        while len(groups) > cols:
            gaps = [groups[i + 1][0] - groups[i][2] for i in range(len(groups) - 1)]
            i = int(np.argmin(gaps))
            a, b = groups[i], groups.pop(i + 1)
            a[0], a[1], a[2], a[3] = min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])
        for c, g in enumerate(groups):
            out[(r, c)] = Image.fromarray(rgba[g[1]:g[3], g[0]:g[2]], "RGBA")
    return out


def main():
    os.makedirs(MID, exist_ok=True)
    count = 0
    only = sys.argv[1:]      # 이름 앞부분을 주면 그 시트만 (예: python3 tools/import_ui_v7.py 60_bld_pen 72_)

    def wanted(name):
        return not only or any(name.startswith(p) for p in only)

    for name, (cols, rows, parts) in SHEETS.items():
        if not wanted(name):
            continue
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
        cells = gap_images(rgba, cols, rows) if name.startswith("60_bld_") else cell_images(rgba, cols, rows)
        for i, (out_name, size) in enumerate(parts):
            k = (i // cols, i % cols)
            if k not in cells:
                print("[빈 칸] %s %s" % (name, out_name))
                continue
            im = cells[k]
            if out_name != "fx_erase":   # 가장자리에 남은 마젠타 물을 뺀다 (분홍 지우개 가루는 그대로 둔다)
                a = np.asarray(im).astype(np.int16)
                # 회색 쇠붙이(강화 연출)는 분홍 물이 잘 보여서 더 세게 뺀다
                spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + (4 if out_name.startswith("forge_") else 25))).clip(0)
                a[..., 0] -= spill
                a[..., 2] -= spill
                im = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
            if isinstance(size, str):      # "match:<그림 이름>": 그 그림과 같은 긴 변으로
                ref = Image.open(sprite_path(size.split(":", 1)[1]))
                s = max(ref.size) / max(im.size)
            else:
                s = size if size <= 1.0 else size / max(im.size)
            if not isinstance(size, str) and size < 0:
                s = -size * 1774.0 / rgba.shape[1]
            if out_name in UPRIGHT:        # 비스듬히 그려진 도구를 세운다 (손잡이 아래, 끝이 위)
                im = im.rotate(UPRIGHT[out_name], resample=Image.BICUBIC, expand=True)
                im = im.crop(im.getbbox())
                s = size / im.height
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            im.save(sprite_path(out_name))
            count += 1
    for name, (out_name, width, band) in FULL.items():
        if not wanted(name):
            continue
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
        im.save(sprite_path(out_name))
        count += 1
    for name, out_name in COVER.items():
        if not wanted(name):
            continue
        src = os.path.join(RAW, name + ".png")
        if not os.path.isfile(src):
            print("[없음] %s" % name)
            continue
        im = Image.open(src).convert("RGB")
        im.save(os.path.join(MID, name + ".png"))
        post.cover(im, 1672, 941).save(sprite_path(out_name))
        count += 1
    for name, (n, out_name, cw) in STRIPS.items():
        if not wanted(name):
            continue
        src = os.path.join(RAW, name + ".png")
        if not os.path.isfile(src):
            print("[없음] %s" % name)
            continue
        rgba, kc = post.chroma_key(Image.open(src))
        if rgba is None:
            print("[실패] %s" % name)
            continue
        rgba = post.drop_specks(rgba, min_area=30)
        a = rgba.astype(np.int16)
        spill = (np.minimum(a[..., 0], a[..., 2]) - (a[..., 1] + 25)).clip(0)
        a[..., 0] -= spill
        a[..., 2] -= spill
        rgba = a.clip(0, 255).astype(np.uint8)
        # 모든 칸에서 그림이 있는 세로 범위를 합쳐 자른다 (칸끼리 자리가 맞게)
        ys = np.where(rgba[..., 3].max(axis=1) > 0)[0]
        im = Image.fromarray(rgba[ys.min():ys.max() + 1], "RGBA")
        im = im.resize((cw * n, round(im.height * cw * n / im.width)), Image.LANCZOS)
        im.save(sprite_path(out_name))
        count += 1
    print("완료: %d장" % count)


if __name__ == "__main__":
    main()
