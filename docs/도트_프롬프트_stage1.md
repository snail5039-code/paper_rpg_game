# 도트 프롬프트: 1단계 마무리 그림 (70번대)

> 1단계 마무리 기능(친구 우리, 박물관, 끝없는 탑, 주민 전용 물건, 세트 장비)의 그림. ChatGPT 웹에서 받는다.
> 받은 그림은 `assets/generated_pixel_art/ui_v7_raw/<파일 이름>` 에 넣고 `python3 tools/import_ui_v7.py` → `godot --headless --path . --import`.
> 투명 바탕이 필요한 시트는 진한 분홍(#FF00FF) 바탕으로 받는다 (도구가 투명하게 바꾼다).

## 공통 그림체 (모든 프롬프트 앞에 붙는다)

```text
STYLE: chunky pixel art coloured with crayon / coloured-pencil texture, pixel blocks clearly visible; thick slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no gradients, no drop shadows, no glow, NO text, NO letters, NO numbers. Match the attached reference image's style exactly.
```

## 70. 친구 우리 5단계 (`60_bld_pen.png`)

- 첨부: `assets/generated_pixel_art/ui_v7_raw/60_bld_house.png` (건물 단계 그림체)
- 결과: `bld_pen_l1`, `bld_pen_l2`, `bld_pen`(3단계), `bld_pen_l4`, `bld_pen_l5`

```text
Make ONE image: a wide sprite sheet, one row of 5 equal cells on a perfectly flat solid magenta (#FF00FF) background (no paper, no grid, no shadows, no cell borders). Do not use magenta in the objects. Each object centered in its cell with clear empty margin, nothing touching another cell.
Subject: a "friend pen" — a small fenced yard where cute doodle monsters live, seen from the front and slightly above like the attached buildings. Same 5 upgrade stages as the attached sheet, left to right getting bigger and nicer:
1 thatch: a ring of rough stick fence with a little straw shelter,
2 mud: a low mud-brick wall yard with a small mud hut,
3 wood: a neat wooden picket fence yard with a wooden doghouse-like hut and a water bowl,
4 brick: a brick-wall yard with a tiled-roof hut and a gate,
5 mansion: a grand fenced garden pen with a pretty little cottage, flower pots and a swing.
Leave the middle of each yard open (no animals drawn). STYLE: ...(공통 그림체)
```

## 71. 박물관 5단계 (`60_bld_museum.png`)

- 첨부: `60_bld_house.png`
- 결과: `bld_museum_l1`, `bld_museum_l2`, `bld_museum`, `bld_museum_l4`, `bld_museum_l5`

```text
Make ONE image: a wide sprite sheet, one row of 5 equal cells on a perfectly flat solid magenta (#FF00FF) background (no paper, no grid, no shadows, no cell borders). Do not use magenta in the objects. Each object centered in its cell with clear empty margin.
Subject: a small village MUSEUM building that displays a collection book, seen from the front and slightly above like the attached buildings. Same 5 upgrade stages, left to right bigger and nicer:
1 thatch hut with a display table outside, 2 mud house with a small window showing a framed picture, 3 wooden hall with two columns and a big open book sign (blank pages), 4 brick hall with a dome and banners (no text), 5 grand white stone museum with columns, steps and a golden book emblem (no text).
STYLE: ...(공통 그림체)
```

## 72. 끝없는 탑 배경 3장 (`72_bg_tower_0.png`, `72_bg_tower_1.png`, `72_bg_tower_boss.png`)

- 첨부: `assets/generated_pixel_art/pixel-v4-empty-village-background.png`
- 결과: `bg_tower_0`, `bg_tower_1`, `bg_tower_boss` (1672 × 941)

```text
Make ONE image, wide 16:9, a top-down RPG map background in exactly the attached village's style (cream graph paper, crayon pixel art, round pixel trees). NO characters, NO monsters, NO text.
Scene: one floor of "the Blank Page Tower": an almost empty, pale, white-ish graph-paper floor where the colour has been erased, framed by a border of faded grey-green pencil trees and torn paper edges on all four sides. There are exactly TWO openings: one at the exact CENTER of the TOP edge and one at the exact CENTER of the BOTTOM edge (each about 13% of the image width), with a faint pencil-dotted path running straight between them. The middle is wide open floor.
VARIANT A (72_bg_tower_0): a few faint eraser smudges and scattered pencil shavings.
VARIANT B (72_bg_tower_1): a few torn paper scraps and faint ruler lines on the floor.
VARIANT BOSS (72_bg_tower_boss): a large faint dashed circle (arena) in the middle, darker grey-violet tint, crumpled paper balls at the corners.
```

## 73. 주민 전용 물건 6개 (`73_vgift.png`)

- 첨부: `assets/generated_pixel_art/ch1_v5/11_stat_icons.png`
- 결과: `vgift_0`(단팥빵) `vgift_1`(지팡이 차) `vgift_2`(풍선껌) / `vgift_3`(밀가루 브로치) `vgift_4`(회중시계) `vgift_5`(풍선 배지)

```text
Make ONE image: an icon sheet, 3 columns x 2 rows of equal square cells on a perfectly flat solid magenta (#FF00FF) background (no borders, no shadows). Do not use magenta in the icons. One icon centered per cell with clear margin, same line weight and colours as the attached icon sheet.
Row 1: (1) a round red-bean bun with a sesame dot on top, (2) a small teacup of warm tea with a wooden walking-cane shaped handle, (3) a pink bubble-gum bubble with a wrapper.
Row 2: (4) a cute brooch shaped like a little flour sack with a wheat sprig, (5) an old round silver pocket watch on a short chain, (6) a round badge with three small balloons on it.
STYLE: ...(공통 그림체)
```

## 74. 세트 장비 아이콘 18개 (`74_set_icons.png`)

- 첨부: `11_stat_icons.png` 와 `assets/generated_pixel_art/ch1_v5/12a_tools.png`
- 결과: 줄마다 세트 하나, 칸은 도구·모자·옷·신발·가방·장신구 → `set_<세트>_<부위>` (eraser, crumple, scribble)

```text
Make ONE image: an icon sheet, 6 columns x 3 rows of equal square cells on a perfectly flat solid magenta (#FF00FF) background (no borders, no shadows). One equipment icon centered per cell, same style as the attached icons. Columns left to right: tool (a drawing tool to hold), hat, clothes, shoes, bag, accessory.
Row 1 "ERASER set", pink and white eraser theme: an eraser-tipped wand, a soft eraser-shaped cap, a pink smock with eraser pockets, pink rubber shoes, a pencil-case bag shaped like an eraser, an eraser charm necklace.
Row 2 "CRUMPLE set", crumpled paper theme in pale blue-grey: a crumpled-paper sword, a crumpled paper crown, a crumpled paper armour coat, crumpled paper boots, a paper-bag backpack, a crumpled paper star pin.
Row 3 "SCRIBBLE set", lively scribble theme in light green with black squiggle lines: a scribble-wrapped marker, a scribble beanie, a scribble-patterned hoodie, scribble sneakers, a scribble satchel, a scribble ring.
STYLE: ...(공통 그림체)
```

## 75~77. 세트 겉모습, 주민 부품 (받음)

- `75_set_hats.png` 3칸 × 3줄: 칸은 지우개·구김·낙서, 줄은 앞·옆(왼쪽을 봄)·뒤. 첨부: `artifacts/hat_ref.png`, `33_hats_a.png`, `74_set_icons.png` → `hat_set_<세트>_<0~2>`
- `76_set_tools.png` 3칸: 손에 드는 도구 (촉이 위). 첨부: `41_tools.png` → `tool_set_<세트>`
- `40_cloth_set_<세트>.png`: `artifacts/cloth_ref.png`(tools/cloth_ref.py)와 세트 아이콘을 붙여 "같은 배치, 같은 자세, 맨손, 옷만 바꿔서". 가져오기: `python3 tools/import_cloth.py set_eraser set_crumple set_scribble`
- `77_villager_parts.png` 4칸 × 4줄 "종이 인형": 1줄 몸 4(얼굴 없음), 2줄과 3줄 앞 두 칸 옷 6, 나머지 얼굴 6. 첨부: `ch1_v5/08_villagers_ch1.png`. 겹치는 자리는 `scripts/villager_maker.gd` 의 CLOTH_*, FACE_*
