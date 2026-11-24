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

## 88. 몬스터 공격 공통 효과 (`88_mon_fx.png`)

- 첨부: `ui_v7/24_skill_fx.png` (주인공 스킬 효과 그림체)
- 결과 (4×2): `fx_mon_alert` 예고 느낌표, `fx_mon_claw` 할퀴기, `fx_mon_impact` 맞힘 별, `fx_mon_dust` 먼지, `fx_mon_shock` 땅 충격파, `fx_mon_target` 보스 내리치기 자리, `fx_mon_speed` 돌진 속도선, `fx_mon_scribble` 낙서 뭉치
- 쓰는 곳: `scripts/actors/enemy_slime.gd` (`_lunge_fx`, `_hit_fx`, `_show_target`, `_slam_fx`), `scripts/actors/mon_fx.gd`

## 89. 몬스터마다 다른 맞힘 효과 (`89_mon_hit_a~c.png`, 같은 대화에서 이어서)

- 결과 (각 4×2, `fx_hit_<이름>`): a lead shavings sticky band thorn spore crayon petal / b paint ink water bubble zap tack clip note / c popcorn confetti marks stamp tape paper chalk fade
- 몬스터마다 [그림, 색, 크기] 는 `scripts/data/mon_fx_data.gd` 의 `HIT`
- 프롬프트: "ONE more image, exactly the same style and layout (4 across, 2 rows, magenta background, each a themed HIT IMPACT burst exploding from the centre). Row 1: 1 … 8 …" 칸마다 영어로 하나씩 (예: "a big violet paint splat with round droplets flying out")

## 90. 몬스터 전용 맞힘 효과 72종 (`90_mon_hit_d~l.png`, 같은 대화에서 이어서)

- 첨부: `ui_v7/89_mon_hit_b.png`. 칸 이름과 몬스터는 `tools/import_ui_v7.py` 의 `90_mon_hit_*`, 배정은 `scripts/data/mon_fx_data.gd`
- 이것으로 본편 몬스터(1~9장 기본, 보스 포함 93종)가 모두 자기 그림을 하나씩 갖는다. 연습 페이지 몬스터만 색을 바꿔 같이 쓴다.
- 프롬프트는 §89 와 같은 틀에 칸마다 영어 한 줄 (예: d = slime goo, polka dots, grass blades, spider web, acorns, snail spiral, owl feathers, wood chips)


## 91. 2장 보스 3종과 맞힘 효과 (`91_ch2_bosses.png`, `91_ch2_boss_fx.png`)

- 첨부: 1장 보스 3종을 마젠타 바탕에 늘어놓은 그림 (boss_0~2). 같은 대화에서 효과 시트를 이어서 요청.
- 결과: `boss_3` 큰나무 할아범(대장), `boss_4` 색 빠진 왕버섯(중간 보스), `boss_5` 색 먹는 애벌레(필드 보스), `fx_hit_roots`·`fx_hit_greyspore`·`fx_hit_colorbite`.

```text
Make ONE image: a wide sprite sheet on a solid flat MAGENTA (#FF00FF) background, ONE row of 3 equal cells, one character per cell, each centered with generous empty magenta margin, characters not touching each other or the edges. Same art style as the attached reference bosses (chunky crayon / coloured-pencil pixel art, thick wobbly dark pencil outlines, soft pastel colours, cute but a little sad), similar size per cell. Front 3/4 view, standing, no shadow on the ground, NO text. Cell 1: 'Great Tree Grandpa' - an old tree spirit boss: thick trunk body with a kind wrinkled bark face, droopy moss eyebrows and moss beard, two branch arms with a few coloured-pencil leaves, a leafy crown; his ROOTS at the bottom are half erased - missing pieces shown as faint dotted outlines and white eraser marks. Cell 2: 'Colourless King Mushroom' - a big round mushroom boss with a wide cap that has lost most of its colour (grey sketch with only a few red spots left), a tiny paper crown on top, stubby legs, small grumpy face, puffs of grey spores around it. Cell 3: 'Colour-eating Caterpillar' - a long fat caterpillar boss curled in an S shape, each body segment a different crayon colour (red, orange, yellow, green, blue) but the segments nearest its big open hungry mouth have turned grey, little crayon-stub feet.
```


## 93. 2장 색연필 숲 배경 8장 (`93a~h_ch2_*.png`, map_v6_raw)

- 한 대화에서 첫 장에만 1장 들판 배경(bg_ch1_meadow)을 첨부하고 공통 규칙 + 장면을 보냈다. 뒤 장은 "앞 그림과 같은 규칙" + 장면만.
- 처리: `python tools/map_v6_post.py 93` → `python tools/import_map_v6.py ch2`.

공통 규칙:

```text
Generate exactly ONE image (use image generation, not code). ART STYLE must match the attached reference map exactly: chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block visible, thick slightly wobbly dark-grey pencil outlines, soft pastel colours, cream graph-paper base with a faint grid, NO text, NO letters, NO numbers, no gloss, no smooth gradients, no drop shadows. Top-down RPG map background, wide 16:9 landscape (target 1672x941), same camera angle and same scale of trees and paths as the reference. NO characters, NO monsters, NO animals, NO people. This is chapter 2, the 'Coloured-Pencil Forest': trees are round forest trees whose leaves are hatched with coloured pencil in several colours (greens, teal, a little orange and violet) with visible pencil-stroke texture; dirt paths are sandy-apricot with pencil outline like the reference. In this forest the colour is draining away: some trees and ground are drawn only as uncoloured grey pencil sketch lines. The whole map is enclosed by a thick row of these forest trees along all four edges, EXCEPT at each GATE listed below. A GATE is a clear opening in the tree border about 13% of the image width wide (for left/right gates: about 23% of the image height tall), located at the EXACT CENTER of that edge, with a dirt path running through the opening all the way off the edge of the image. No trees, rocks or objects inside a gate opening. Edges without a gate are fully closed by trees. The middle of the map is wide open, uncluttered walkable ground (monsters will roam there).
```

### `93a_ch2_village.png` (문: bottom)

```text
SCENE - 'Forest-edge village': a small hamlet in a forest clearing. Three small cottages made from hollow tree stumps with leaf-shingle roofs and round doors stand along the top edge and the upper-left and upper-right corners (not in the middle). A small round plaza of packed dirt in the centre with one little round stone well at its upper edge, a few flower beds and a short coloured-pencil picket fence. The right third of the village has lost its colour: the cottage, grass and flowers there are only grey pencil sketch lines on the paper. GATES: exactly ONE gate at the center of the BOTTOM edge; a dirt path runs from the plaza down through it. Top, left and right edges fully closed by trees.
```

### `93b_ch2_path.png` (문: top, bottom, left, right)

```text
SCENE - 'Forest path': four dirt paths meet in the middle forming a plus-shaped crossing in a forest. Beside the paths (never on them, never in the middle): two fallen mossy logs, a few short coloured-pencil stubs stuck upright in the ground like little stakes, small ferns and mushrooms. A few of the trees near the bottom-right are uncoloured grey sketches. GATES: four gates, one at the exact center of EACH edge (top, bottom, left, right), each with its dirt path running off the edge.
```

### `93c_ch2_grove.png` (문: right)

```text
SCENE - 'Acorn grove': a grove of big round oak trees around the edges, acorns and acorn caps scattered on the grass, two small piles of curly pencil shavings, one hollow tree stump in the upper-left area. Wide open grassy middle. GATES: exactly ONE gate at the center of the RIGHT edge; a dirt path enters from it and fades out toward the middle. Top, bottom and left edges fully closed by trees.
```

### `93d_ch2_cliff.png` (문: left)

```text
SCENE - 'Cliff and vines': along the TOP quarter of the map (just inside the top tree row) runs a low rocky cliff wall drawn in coloured pencil, with long green vines hanging down from it; some vines are uncoloured grey and look snapped. A few loose rocks and small ledges near the cliff foot. The rest of the map is open grassy ground. GATES: exactly ONE gate at the center of the LEFT edge; a dirt path enters from it toward the middle. Top, bottom and right edges fully closed (the cliff sits inside the top tree row).
```

### `93e_ch2_gray.png` (문: top, left, bottom)

```text
SCENE - 'Colourless forest': here most of the colour is gone. The left third of the map is still softly coloured (green grass, coloured trees); a clear wavy boundary line runs top-to-bottom at about one third of the width, and everything to the right of it - trees, grass tufts, bushes - is drawn only in grey pencil sketch lines on the cream graph paper, like an unfinished drawing. A few tiny colour flecks remain in the grey part. GATES: THREE gates - at the exact center of the TOP edge, the LEFT edge and the BOTTOM edge, with dirt paths joining in the middle. The right edge is fully closed by (grey sketch) trees.
```

### `93f_ch2_mushroom.png` (문: right)

```text
SCENE - 'Mushroom hollow': clusters of giant mushrooms (red, orange, violet caps with dots) grow around the edges of a round sunken clearing; several of the mushrooms have lost their colour and are grey sketches. Small mushrooms and spore puffs dotted on the ground. The round clearing in the middle is wide open. GATES: exactly ONE gate at the center of the RIGHT edge with a dirt path into the clearing. Top, bottom and left edges fully closed by trees and mushrooms.
```

### `93g_ch2_bigtree.png` (문: top, bottom)

```text
SCENE - 'Before the Great Tree': a dirt path runs straight from the top gate down to the bottom gate. In the lower part of the map the enormous gnarled roots of a giant ancient tree spread across the ground on both sides of the path (the giant trunk itself is just beyond the bottom edge, not visible); the roots are coloured brown near the path and fade to grey sketch lines further out. Fallen big leaves in many pencil colours. The upper middle is wide open ground. GATES: TWO gates, at the exact center of the TOP edge and the BOTTOM edge. Left and right edges fully closed by trees.
```

### `93h_ch2_bossroom.png` (문: top)

```text
SCENE - 'Roots of the Great Tree': a large round clearing completely ringed by enormous twisting tree roots instead of a tree row (roots form the border on all sides except the gate). The roots in the lower half are partly erased: white eraser-rubbed gaps, missing segments, dotted outlines where root used to be, grey and uncoloured. Fallen leaves on the ground. The clearing in the middle is wide open and empty. GATES: exactly ONE gate at the center of the TOP edge with a dirt path entering. No other openings.
```


## 94~95. 2장 사람·얼굴·친구·재료 (`94_ch2_people`, `94_ch2_portraits`, `95_ch2_mats`, `81_friend_<종>`)

- 한 대화에서 차례로 요청했다. 그림마다 참고 그림을 새로 첨부: 사람은 1장 주민·선생 그림, 얼굴은 하루·선생·할아버지 얼굴, 재료는 1장 재료 아이콘 12개, 친구는 `81_friend_grassmallang` 시트(자홍 바탕).
- `94_ch2_people` (4칸): `npc_gutungi` 귀퉁이(접힌 페이지 귀퉁이 머리, 낙서 머리카락, 줄무늬 목도리, 뺨에 반창고), `villager_3` 색칠 곰 아저씨(앞치마 반쪽이 회색), `villager_4` 덩굴 할머니(덩굴 숄, 바구니), `villager_5` 되풀이 주민(버섯 모자, 입이 흐릿함).
- `94_ch2_portraits` (3칸): `portrait_gutungi_smirk`, `portrait_gutungi_quiet`, `portrait_oak` (가슴까지, 정면).
- `95_ch2_mats` (5×2): `mat_12`~`mat_21` 회색 털, 도토리 깍지, 연필밥, 초록 색연필심, 덩굴 선, 가시, 색 빠진 갓, 나무 진, 깃 선, 노란 색연필심.
- `81_friend_<종>` (6칸, 기본·움직임 둘·예고·공격·맞음): `kongkong` 콩콩이(살짝 큰 도토리 모자), `vine` 덩굴이(색 빠진 잎 + 새 잎 하나), `acornfox` 도토리 여우, `mossvine` 덩굴 이끼곰, `petalshroom` 꽃잎 버섯. 가져오기 `python3 tools/import_friends.py`.
- 공통 그림체 문장: "chunky pixel art coloured with crayon / coloured-pencil texture, pixel blocks clearly visible; thick slightly wobbly dark-grey pencil outlines; soft pastel colours; no gloss, no gradients, no drop shadows, no glow, NO text. Match the attached reference image's style and proportions exactly."

## 97. 사냥터 나무와 도끼 (`97_trees_axe`, 5×2, 마젠타 바탕)
첫 줄: 1장 크레용 나무, 2장 색연필(가을 밤나무) 나무, 그 둘의 그루터기, 통나무 아이콘. 둘째 줄: 손에 든 도끼(세로, 날이 위), 도끼 아이콘 나무·쇠·금(96_life_icons 와 같은 대각선), 빈 칸. 참고 그림으로 96_life_icons 와 17b_ch1_meadow 를 붙였다.

## 98. 불러오기 화면 (`98_loading_flat`, 16:9 통짜)
책상 위에 펼친 모눈 공책(가운데 고리), 왼쪽 위 스탠드 불빛, 둘레에 색연필·지우개·스티커. 오른쪽 장은 납작하게 (게임이 그 장을 잘라 넘긴다). 아래 1/4 은 책상만 (막대와 팁 자리). 글씨 없음. 참고 그림 32_title.

## 99. 보스 쓰러짐 (`99_boss_burst`, 6×2, 마젠타 바탕)
첫 줄: 종이와 잉크로 터지는 6장 (작은 번쩍 → 터짐 → 가장 큰 구름 → 흩어짐 → 조각 → 반짝이 몇 개), 같은 크기·같은 가운데로 (칸을 고르게 잘라 쓴다). 둘째 줄: 구겨진 종이 공, 줄 공책 조각, 모눈 조각, 잉크 얼룩, 잉크 방울, 노란 반짝이.

### 보스마다 다른 쓰러짐 (`99_boss_burst_<테마>`, 같은 6×2 배치)
보스 그림과 99_boss_burst 를 붙이고 같은 배치로. 첫 줄 터짐 6장, 둘째 줄 조각 6개.
- `x` 큰 가위표: 빨간 크레용 획·잉크 → 마지막에 초록 체크(✓). 조각: 크레용 획, 작은 X, 크레용 토막, 빨간 잉크, 주먹 연기, 체크
- `eraser` 왕 지우개똥 벌레: 지우개 가루 구름, 굴러가는 지우개똥, 왕관. 조각: 지우개똥, 지우개 조각, 왕관, 가루 둘, 반짝이
- `crumple` 구깃이: 구겨진 종이가 펼쳐지며 터짐. 조각: 종이 공, 줄 공책 조각, 종이비행기, 접힌 모서리, 파란 줄, 반짝이
- `scribble` 떠돌이 큰 낙서: 엉킨 연필선이 풀리며 터짐. 조각: 꼬불 선, 작은 매듭, 연필심, 흑연 얼룩, 흑연 가루, 반짝이
- `oak` 큰나무 할아범: 알록달록 잎·도토리·나무껍질. 조각: 초록 잎, 단풍잎, 도토리, 껍질, 새싹, 반짝이
- `mush` 색 빠진 왕버섯: 회색 포자 구름 속에서 색이 돌아옴. 조각: 갓 조각, 왕관, 회색 포자, 알록달록 포자, 줄기, 반짝이
- `worm` 색 먹는 애벌레: 먹은 색이 무지개 물감으로 터져 나옴. 조각: 빨강·파랑·노랑 물감, 초록 마디, 주황 방울, 반짝이
첫 줄은 칸을 고르게 잘라 쓰고(같은 크기·가운데), 마젠타 물은 세게 뺀다 (가는 선 사이에 분홍이 남는다).

## 100~101. 1장 뒷이야기 "흰 집"
- `100_ch1_people` (4×3, 마젠타): 첫 줄 허수(종이 허수아비, 한쪽 소매가 지워짐), 이정표 아저씨(팻말 하나가 하얗게 지워짐), 빈 우편함(빨간 옛 우체통, 작은 발), 노란 우편 가방(한쪽이 갉아 먹힘). 둘째 줄 얼굴 넷(허수, 이정표, 우편함, 구깃이). 셋째 줄 편지 조각, 집 그림 우표, 구겨진 편지, 하트 스티커 편지. 참고: villager_1, portrait_haru_smile, 94_ch2_people
- `101_ch1_page_0~3` (16:9 통짜, 글씨 없음, 그림책 장면): 0 흰 집 자국 앞의 하루와 주인공(뒷모습, 해 질 녘) / 1 기억: 이정표 앞의 우편배달부 뒷모습(모자로 얼굴이 가려짐, 노란 가방, 날리는 편지, 바랜 사진 느낌) / 2 펴진 편지: 크레용 낙서 글씨(읽히지 않게), 나란히 앉아 그리는 두 아이, 서명 대신 작은 해 / 3 흰 집 자리에 새로 그린 우편함에 편지를 넣는 장면. 참고: bg_ch1_village, portrait_haru_smile, 앞 장면
