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

- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`
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
- `77_villager_parts.png` 4칸 × 4줄 "종이 인형": 1줄 몸 4(얼굴 없음), 2줄과 3줄 앞 두 칸 옷 6, 나머지 얼굴 6. 첨부: `ch1_v5/08_villagers_ch1.png`. 겹치는 자리는 `scripts/ui/villager_maker.gd` 의 CLOTH_*, FACE_*

## 80. HUD 메뉴 단추 (`80_menu_btns.png`)

- 첨부: `74_set_icons.png` (아이콘 그림체)
- 결과: `menu_bag`, `menu_stats`, `menu_skills`, `menu_map`, `menu_friends`, `menu_dex`, `menu_settings` (화면 오른쪽 아래, 누르면 창이 열림)

```text
Make ONE image: a wide sprite sheet, one row of 7 equal square cells on a perfectly flat solid magenta (#FF00FF) background (no paper, no grid, no shadows, no cell borders). Do not use magenta in the objects. Each icon centered in its cell with clear empty margin, nothing touching another cell. These are game MENU BUTTON icons, each one a single bold simple object readable at very small size (about 22 pixels), same style as the attached icons. Left to right: 1 a school backpack (inventory), 2 a little paper-doll person bust with a small star badge (character stats), 3 an open spell book with a sparkle above it (skills), 4 a folded paper treasure map with a red dot (map), 5 a cute round doodle blob monster face smiling (friends), 6 a thick closed collection book with a ribbon bookmark (encyclopedia), 7 a cog gear (settings). STYLE: ...(공통 그림체)
```

## 81. 합치기 친구 3종 (`81_friend_<종>.png`)

- 결과: `mon_friend_linespider`, `mon_friend_snowflake`, `mon_friend_grassmallang` (6칸 띠, 1장 몬스터와 같은 순서). 가져오기: `python3 tools/import_friends.py`
- 칸: 기본, 움직임 A, 움직임 B, 예고(웅크림), 공격, 맞음. 첨부는 섞이는 두 몬스터의 `ch1_v5` 원본 시트.

```text
(줄거미, 첨부 05d_gridspider_faded + 05a_squiggle_faded)
Make ONE image: a monster animation sheet, one row of 6 equal cells on a perfectly flat solid magenta (#FF00FF) background (no paper, no grid, no shadows, no cell borders, no ground). Do not use magenta in the character. Each frame centered in its cell, all frames the SAME size and facing the SAME direction as the attached sheets, nothing touching another cell. Character: "Line Spider" — a friendly crayon doodle creature born from merging the two attached monsters: the round body of the grid spider with its thin legs, but its legs are long wavy squiggle lines like the squiggle monster, a warm orange-cream body (light pastel orange, not purple), cute dot eyes, a little ruled-line stripe pattern on its back. Same 6 frames in the same order as the attached sheets: 1 idle, 2 move pose A, 3 move pose B, 4 wind-up (crouch before attacking), 5 attack (leaping, legs stretched), 6 hurt (squinting, flinching). STYLE: ...(공통 그림체)

(눈송이, 첨부 05b_dots_faded + 05e_dustbug_faded, 같은 대화에서 이어서)
... Character: "Snowflake" — a fluffy round puff made of a cluster of soft pale-blue and white dots like falling snow, with tiny six-point snowflake crystals floating around it, two little bug antennae, cute dot eyes and a small smile. Pale icy blue and white pastel colours (not grey). In the attack frame it puffs out a burst of snow dots; in the hurt frame it squints and some dots scatter.

(풀말랑, 첨부 02_slime_faded + 05c_grass_faded, 같은 대화에서 이어서)
... Character: "Grass Mallang" — a soft squishy round slime blob in fresh pastel leaf-green, with a little tuft of grass blades and a tiny clover sprouting on top of its head, cute dot eyes and rosy cheeks. Movement like the slime: squash and stretch hopping. In the attack frame it bounces forward and grass blades fly out; in the hurt frame it squints and flattens.
```

## 82~83. 물고기 42종·채집 46종 아이콘 (`82_fish_a~c.png`, `83_forage_a~d.png`)

- 첨부: `26_food.png` (물고기 아이콘 그림체). 한 대화 안에서 차례로.
- 결과: `fish_0`~`fish_41`, `forage_4`~`forage_49`, 잠자리채 `life_net` (83_forage_d 의 11번째 칸, 가져올 때 세운다). 이름 순서는 `scripts/data/items.gd` 의 `fish_*`, `fg_*` (fg_N 의 그림은 forage_N+4).
- 물고기 시트: 5×3, 옆모습 왼쪽 보기. 채집 시트: 4×3. 칸마다 어떤 것인지 영어로 하나씩 적는다 (예: "1 an origami paper goldfish (orange folded paper), 2 a round pufferfish covered in thumbtack spikes, …"). 그림체 문장은 공통 그림체.

## 85~86. 박물관 (`85_bg_museum.png`, `86_museum_props.png`)

- 85: 첨부 `61_room_shop.png`. "the EMPTY interior of a small village MUSEUM hall … back wall across the top (cream paper wallpaper with a soft ruled-line pattern, two tall arched windows, a few small hanging lamps), a warm light wooden plank floor …, an open double doorway at the bottom centre. The floor must be COMPLETELY EMPTY" → `bg_room_museum`
- 86: 4×2, 자홍 바탕, 전부 비어 있게: 수조, 곤충 표본장, 꽃 화단, 진열 탁자, 코르크 판 이젤, 유리 진열장, 안내 데스크, 부엉이 관장 → `prop_tank`, `prop_bugcase`, `prop_planter`, `prop_table`, `prop_board`, `prop_showcase`, `prop_desk`, `npc_curator`. 전시물은 `scripts/maps/museum_display.gd` 가 그 위에 그린다.

## 87. 사냥터 팻말 (`87_gate_sign.png`)

- 첨부: `assets/sprites/buildings/deco_signpost.png`
- 결과: `deco_sign_hunt` (가운데가 빈 나무 팻말, 글자 "사냥터" 는 게임에서 얹는다), `ui_arrow_down` (아래를 가리키는 크레용 화살표). 공책 마을 아래쪽 문 (`scripts/maps/village.gd` 의 `_build_gate_sign`)
- 2칸, 자홍 바탕: 1 판자 오른쪽 끝이 화살표 모양인 나무 팻말 (왼쪽 끝에 칼과 잎 무늬, 가운데는 비움), 2 연두 크레용으로 그린 굵은 아래 화살표. STYLE: ...(공통 그림체)
