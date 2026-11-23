# 도트 프롬프트: map_v6 (3순위 맵 확장, 14장)

> [도트_요구사항.md](도트_요구사항.md)의 17 ~ 22번을 ChatGPT 웹 채팅창에서 그리기 위한 프롬프트 모음이다.
> 그림마다 **파일 이름 / 크기 / 첨부할 그림 / 프롬프트** 순서로 적었다. 프롬프트는 코드 블록을 통째로 붙여 넣는다.

> 2026-11-22: 14장 모두 이 방식으로 만들었다. 실제로는 **한 채팅 안에서** 첫 그림에만 마을 배경을 첨부하고, 뒤 그림은 "앞 그림과 같은 규칙"이라고 줄여서 이어 요청했다. 그림 한 장에 1분 30초쯤 걸린다.

## 쓰는 법

1. 그림 한 장마다 **새 채팅**을 열고, "첨부"에 적힌 참고 그림을 올린 뒤 프롬프트를 붙여 넣는다.
2. 받은 그림을 아래 **파일 이름 그대로** `assets/generated_pixel_art/map_v6_raw/`에 저장한다 (확장자는 png, webp, jpg 모두 된다).
3. 크기나 비율이 조금 달라도 그대로 저장한다. 맞추는 일은 후처리가 한다.
4. 투명 배경이 필요한 시트는 **진한 분홍(마젠타 #FF00FF) 바탕**으로 그리게 한다. ChatGPT가 투명 배경으로 주었다면 그것도 그대로 쓸 수 있다.
5. 후처리를 돌린다. 결과는 `assets/generated_pixel_art/map_v6/`에, 검수용 그림은 `map_v6_raw/_preview/`에 생긴다.

```
python tools/map_v6_post.py
```

파일이 일부만 있어도 있는 것만 처리하고, 없는 것은 끝에 목록으로 알려 준다. 특정 그림만 다시 하려면 `python tools/map_v6_post.py 19 21a`처럼 번호를 적는다.

## 받은 그림에서 볼 것

- 배경: 문이 그 변의 정가운데에 있는가, 가운데가 비어 있는가, 캐릭터나 글자가 없는가.
- 바닥 질감: `_preview/`의 2×2 이어 붙인 그림에서 경계선이 보이지 않는가.
- 시트: `_preview/`의 파란 바탕 그림에서 칸마다 하나씩, 노란 칸 선에 닿지 않고 들어 있는가. 분홍 테두리가 남지 않았는가.
- 맞지 않으면 같은 채팅에서 고칠 점만 한 줄로 다시 요청한다 (예: "the gate must be at the exact center of the right edge").


---

## 배경 5장 (17)

### `17a_ch1_village.png`

- 파일 이름: `17a_ch1_village.png`
- 크기: 1672 × 941, 불투명 (가로 16:9)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png` **(필수: 이 그림을 고치는 요청이다)**

```text
Edit the attached image with image generation (not code). Output ONE image.

EDIT INSTRUCTIONS: Keep the attached top-down pixel-art village map EXACTLY as it is - same size and 16:9 aspect, same two houses (red roof, purple roof) in the same places, same blue river in the same place, same dotted bridge outline, same red door on the right (east) side, same paths, same grass tufts, same trees, same crayon pixel-art style and graph-paper base. Make ONE change only: in the row of trees along the BOTTOM edge, remove the trees at the horizontal center of the image so there is a clear opening about 13% of the image width wide, centered exactly at the horizontal middle of the bottom edge (just to the left of where the river reaches the bottom). Add a sandy-apricot dirt path, same colour and pencil outline as the existing paths, that branches off the existing main horizontal path and runs straight down through that opening and off the bottom edge of the image. Fill the opening with grass and the path only. No characters, no text. Change nothing else.
```

### `17b_ch1_meadow.png`

- 파일 이름: `17b_ch1_meadow.png`
- 크기: 1672 × 941, 불투명 (가로 16:9)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a top-down RPG map background, wide 16:9 landscape (target 1672x941). Same camera angle, same graph-paper (cream paper with faint grid) base, same light yellow-green crayon grass, same sandy-apricot dirt paths with pencil outline, and the same round pixel trees as the attached village reference. NO characters, NO monsters, NO animals, NO people - only ground, terrain, trees, bushes and objects. The whole map is enclosed by a single row of round trees/bushes along all four edges, exactly like the reference, EXCEPT at each GATE listed below. A GATE is a clear opening in the tree border about 13% of the image width wide (for left/right gates: about 23% of the image height tall), located at the EXACT CENTER of that edge, with a sandy dirt path running through the opening all the way off the edge of the image. There must be no trees, bushes or objects inside a gate opening. Edges without a gate are fully closed by trees. The middle of the map is wide open, uncluttered walkable ground (monsters will roam there).

SCENE - 'Meadow': a wide open grassy meadow. Many small grass tufts scattered around, a few tiny flowers, and ONE small light-blue pond (with a few white wave strokes, like the river in the reference) in the upper-left quarter. No buildings.
GATES: exactly ONE gate - at the center of the RIGHT edge. A dirt path enters from the right-edge gate and fades out into the meadow toward the middle. Top, bottom and left edges are completely closed by trees.
```

### `17c_ch1_crossroad.png`

- 파일 이름: `17c_ch1_crossroad.png`
- 크기: 1672 × 941, 불투명 (가로 16:9)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a top-down RPG map background, wide 16:9 landscape (target 1672x941). Same camera angle, same graph-paper (cream paper with faint grid) base, same light yellow-green crayon grass, same sandy-apricot dirt paths with pencil outline, and the same round pixel trees as the attached village reference. NO characters, NO monsters, NO animals, NO people - only ground, terrain, trees, bushes and objects. The whole map is enclosed by a single row of round trees/bushes along all four edges, exactly like the reference, EXCEPT at each GATE listed below. A GATE is a clear opening in the tree border about 13% of the image width wide (for left/right gates: about 23% of the image height tall), located at the EXACT CENTER of that edge, with a sandy dirt path running through the opening all the way off the edge of the image. There must be no trees, bushes or objects inside a gate opening. Edges without a gate are fully closed by trees. The middle of the map is wide open, uncluttered walkable ground (monsters will roam there).

SCENE - 'Crossroad': four dirt paths meet in the middle of the map forming a plus-shaped crossroad. Near the center (just beside the crossing, not blocking the paths) stand an old weathered wooden signpost with blank arrow boards (NO writing) and a small round stone well with a little wooden roof. Two empty round clearings of bare pale ground (one in the upper-left quadrant, one in the lower-right quadrant) are left empty for placing things later.
GATES: FOUR gates - one at the exact center of EACH edge (top, bottom, left, right). The four paths run straight from the central crossing out through the four gates.
```

### `17d_ch1_gridwoods.png`

- 파일 이름: `17d_ch1_gridwoods.png`
- 크기: 1672 × 941, 불투명 (가로 16:9)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a top-down RPG map background, wide 16:9 landscape (target 1672x941). Same camera angle, same graph-paper (cream paper with faint grid) base, same light yellow-green crayon grass, same sandy-apricot dirt paths with pencil outline, and the same round pixel trees as the attached village reference. NO characters, NO monsters, NO animals, NO people - only ground, terrain, trees, bushes and objects. The whole map is enclosed by a single row of round trees/bushes along all four edges, exactly like the reference, EXCEPT at each GATE listed below. A GATE is a clear opening in the tree border about 13% of the image width wide (for left/right gates: about 23% of the image height tall), located at the EXACT CENTER of that edge, with a sandy dirt path running through the opening all the way off the edge of the image. There must be no trees, bushes or objects inside a gate opening. Edges without a gate are fully closed by trees. The middle of the map is wide open, uncluttered walkable ground (monsters will roam there).

SCENE - 'Grid Woods': a tidy forest where round trees stand in neat straight rows and columns, aligned to the graph-paper grid like a planted orchard, in the upper third and lower third of the map. Narrow dirt paths run between the tree rows. The central horizontal band of the map stays open ground. A few faint pencil squiggle doodles and thin pencil cobweb lines between some trees. No buildings.
GATES: exactly ONE gate - at the center of the LEFT edge. A dirt path enters from the left-edge gate and runs toward the middle. Top, bottom and right edges are completely closed by trees.
```

### `17e_ch1_erasedroad.png`

- 파일 이름: `17e_ch1_erasedroad.png`
- 크기: 1672 × 941, 불투명 (가로 16:9)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a top-down RPG map background, wide 16:9 landscape (target 1672x941). Same camera angle, same graph-paper (cream paper with faint grid) base, same light yellow-green crayon grass, same sandy-apricot dirt paths with pencil outline, and the same round pixel trees as the attached village reference. NO characters, NO monsters, NO animals, NO people - only ground, terrain, trees, bushes and objects. The whole map is enclosed by a single row of round trees/bushes along all four edges, exactly like the reference, EXCEPT at each GATE listed below. A GATE is a clear opening in the tree border about 13% of the image width wide (for left/right gates: about 23% of the image height tall), located at the EXACT CENTER of that edge, with a sandy dirt path running through the opening all the way off the edge of the image. There must be no trees, bushes or objects inside a gate opening. Edges without a gate are fully closed by trees. The middle of the map is wide open, uncluttered walkable ground (monsters will roam there).

SCENE - 'Erased Road': a dirt road runs from the top gate down the middle of the map. All over the ground there are patches that look rubbed out with an eraser: pale, whitish, smudgy blurred spots where the grass and path colour has faded to almost blank paper, with a few light-grey diagonal eraser streaks and tiny grey eraser crumbs. Some border trees are partly faded too. At the lower end of the road is a wide, round, empty clearing of pale bare ground (a boss arena) taking up much of the lower half. It should feel quiet and empty, not scary: no black, no red, no cracks, no wounds.
GATES: exactly ONE gate - at the center of the TOP edge. The road passes through it. Bottom, left and right edges are completely closed by trees/bushes.
```


---

## 바닥 질감 3장 (18)

### `18a_ground_grass.png`

- 파일 이름: `18a_ground_grass.png`
- 크기: 512 × 512, 불투명 (정사각형)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a square (1:1) SEAMLESS TILEABLE ground texture seen from directly above, filling the entire image edge to edge. It must tile invisibly in both directions: completely uniform density and brightness, no vignette, no border, no frame, no darker or lighter edges, no large distinctive features (no grass tufts, flowers, stones, cracks, objects). Keep the faint graph-paper grid of the reference only if it is very subtle. Use the same colour as the corresponding area in the attached village reference.

TEXTURE: crayon-coloured grass - light yellow-green with soft, short, evenly spread diagonal crayon hatching strokes, exactly the colour of the lawn in the reference.
```

### `18b_ground_path.png`

- 파일 이름: `18b_ground_path.png`
- 크기: 512 × 512, 불투명 (정사각형)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a square (1:1) SEAMLESS TILEABLE ground texture seen from directly above, filling the entire image edge to edge. It must tile invisibly in both directions: completely uniform density and brightness, no vignette, no border, no frame, no darker or lighter edges, no large distinctive features (no grass tufts, flowers, stones, cracks, objects). Keep the faint graph-paper grid of the reference only if it is very subtle. Use the same colour as the corresponding area in the attached village reference.

TEXTURE: crayon-coloured dirt path - light sandy apricot / peach, with soft even crayon grain, exactly the colour of the dirt path in the reference. No outline.
```

### `18c_ground_water.png`

- 파일 이름: `18c_ground_water.png`
- 크기: 512 × 512, 불투명 (정사각형)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a square (1:1) SEAMLESS TILEABLE ground texture seen from directly above, filling the entire image edge to edge. It must tile invisibly in both directions: completely uniform density and brightness, no vignette, no border, no frame, no darker or lighter edges, no large distinctive features (no grass tufts, flowers, stones, cracks, objects). Keep the faint graph-paper grid of the reference only if it is very subtle. Use the same colour as the corresponding area in the attached village reference.

TEXTURE: crayon-coloured water - sky blue crayon hatching, with a handful of small short white wavy strokes spread evenly, exactly like the river in the reference. No banks.
```


---

## 투명 시트 6장 (19 ~ 22)

### `19_portal.png`

- 파일 이름: `19_portal.png`
- 크기: 2172 × 724, 가로 3칸, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: very wide 3:1 image (target 2172x724), ONE row of 3 equal cells. The same 'bookmark door' portal drawn three times at identical size and position in each cell. The door is an arched standing door shaped like a red ribbon bookmark tucked between notebook pages: a tall red bookmark-shaped door frame with a notched (V-cut) ribbon tail detail at the top, a small round knob, standing upright, front view.
Cell 1 - OPEN door: red bookmark door, the inside of the doorway is a soft pale warm cream-yellow (softly bright).
Cell 2 - LOCKED door: exactly the same shape but only an uncoloured grey pencil sketch outline - no colour fill at all, a small keyhole.
Cell 3 - JUST OPENED door: same as cell 1 plus a few short sparkle lines and small four-point stars around it (kept well inside the cell).
```

### `20a_buildings.png`

- 파일 이름: `20a_buildings.png`
- 크기: 2172 × 724, 가로 4칸, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: very wide 3:1 image (target 2172x724), ONE row of 4 equal cells, one small village building per cell. Same size, same front-and-slightly-from-above view, same cream walls / wooden arched doors / wobbly crayon roofs as the two houses in the attached village reference. No ground patch, no grass base, no shadow under them.
Cell 1 - 'My house': a small cottage with a red roof and a chimney.
Cell 2 - Stationery shop: a small shop with a sign shaped like a big yellow pencil (no letters), a striped awning.
Cell 3 - Crafting station: an open work desk under a small roof on four posts, with paper, scissors and a pencil cup on the desk.
Cell 4 - Fishing spot: a small wooden plank pier/deck with a fishing rod resting on a rod stand and a small bucket (no water drawn).
```

### `20b_buildings.png`

- 파일 이름: `20b_buildings.png`
- 크기: 2172 × 724, 가로 4칸, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: very wide 3:1 image (target 2172x724), ONE row of 4 equal cells, one small village building per cell. Same size, same front-and-slightly-from-above view, same cream walls / wooden arched doors / wobbly crayon roofs as the two houses in the attached village reference. No ground patch, no grass base, no shadow under them.
Cell 1 - Villager house 1: a cottage with a purple roof.
Cell 2 - Villager house 2: a cottage with a green roof.
Cell 3 - Storehouse: a small wooden shed with a door and a pile of wooden crates beside it.
Cell 4 - Notice board: a wooden quest bulletin board on two posts with a tiny roof, several blank paper notes pinned on it (no writing).
```

### `21a_props.png`

- 파일 이름: `21a_props.png`
- 크기: 1280 × 512, 5칸 × 2줄, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: 5:2 wide image (target 1280x512), a grid of 5 columns x 2 rows = 10 equal square cells, one small map prop per cell, drawn in the same view and style as the trees and bushes of the attached village reference.
Row 1 (left to right): round leafy tree; pointed conifer tree; green bush; clump of red flowers; clump of yellow flowers.
Row 2 (left to right): wooden fence segment running horizontally; wooden fence segment running vertically (seen as a vertical run of posts); grey rock; tree stump; tuft of grass.
```

### `21b_props.png`

- 파일 이름: `21b_props.png`
- 크기: 1280 × 512, 5칸 × 2줄, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/early/pixel-v4-empty-village-background.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: 5:2 wide image (target 1280x512), a grid of 5 columns x 2 rows = 10 equal square cells, one small map prop per cell, drawn in the same view and style as the trees and bushes of the attached village reference.
Row 1 (left to right): wooden park bench; street lamp post; red-orange mailbox on a post; round stone well with small roof; wooden signpost with blank boards (no writing).
Row 2 (left to right): clothesline between two poles with a few clothes; potted plant in a clay pot; short wooden plank bridge piece; a few flat stepping stones; scarecrow with straw hat.
```

### `22_skill_icons_pencil.png`

- 파일 이름: `22_skill_icons_pencil.png`
- 크기: 1024 × 768, 4칸 × 3줄, 투명 (마젠타 바탕으로 받아 후처리)
- 첨부: `assets/generated_pixel_art/ch1_v5/11_stat_icons.png`

```text
Generate exactly ONE image as described below (use image generation, not code or SVG).

ART STYLE (must match the attached reference image(s)): chunky pixel art coloured with crayon / coloured-pencil texture, each pixel block clearly visible; thick, slightly wobbly dark-grey pencil outlines; soft pastel colours; no saturated primaries, no gloss, no smooth gradients, no drop shadows, no glow, NO text, NO letters, NO numbers.
This is a game sprite sheet. BACKGROUND: one perfectly flat, uniform, solid pure magenta colour (#FF00FF) everywhere - no paper, no grid, no texture, no shading, no vignette (it will be chroma-keyed to transparent). Do not use magenta or hot pink anywhere in the objects themselves. No cell borders, no divider lines, no frames, no labels, no ground line and no shadows under objects. Each object sits in the CENTER of its own equal-sized invisible cell, with clear empty margin (at least 12% of the cell) on every side; nothing may touch or cross into a neighbouring cell.

SHEET: 4:3 image (target 1024x768), a grid of 4 columns x 3 rows = 12 equal square cells, one game skill/item ICON per cell. Same line weight, colours and chunky crayon pixel look as the attached icon sheet reference (yellow pencils with pink erasers, dark graphite strokes).
Row 1 (left to right): (1) a long pencil line drawn left-to-right ending in an arrowhead; (2) a circle drawn in one loop of pencil with a small pencil at its end; (3) three small flying pencil-lead shards; (4) five short parallel diagonal hatch strokes.
Row 2: (5) a pencil tip pressing down hard on a thick dark dot dented into paper; (6) an eraser sweeping across a pencil line that disappears behind it; (7) a small pencil sharpener with curly pencil shavings coming out; (8) a hand holding a pencil with a small sparkle.
Row 3: (9) a star shape drawn in dashed/dotted blueprint lines; (10) a pile of three gold coins each stamped with a star; (11) a single white sheet of drawing paper with one corner slightly curled (dark-grey outline so it reads on any background); (12) a thick stack of paper with a golden border.
```
