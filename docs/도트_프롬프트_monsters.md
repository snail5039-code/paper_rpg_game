# 도트 프롬프트: 몬스터 84종 (7~90번)

> ChatGPT 웹에서 한 대화 안에서 차례로 받는다. 첫 메시지에 `assets/generated_pixel_art/ch1_v5/05a_squiggle_faded.png`, `05a_squiggle_erased.png` 를 첨부한다.
> 받은 그림: `assets/generated_pixel_art/ui_v7_raw/84_mon_m<번호>.png` → `python3 tools/import_monsters.py` → `godot --headless --path . --import`

## 첫 메시지 (7번)

```text
I will ask you for many monster sheets in a row, always in exactly this format. Make ONE image: a monster animation sheet with 2 rows x 6 equal cells on a perfectly flat solid magenta (#FF00FF) background (no paper, no grid, no shadows, no cell borders, no ground). Do not use magenta in the monster. TOP ROW = the monster "slightly erased" (like the first attached sheet: full colours, a few faint eraser smudges). BOTTOM ROW = the SAME monster "heavily erased" (like the second attached sheet: washed-out greyish colours, parts of the outline rubbed away, eraser crumbs). Both rows: same 6 frames in this order: 1 idle, 2 move pose A, 3 move pose B, 4 wind-up (crouch before attacking), 5 attack, 6 hurt (squinting). Every frame the same size, facing the same direction (left), centered in its cell, nothing touching another cell. STYLE: chunky pixel art coloured with crayon / coloured-pencil texture, pixel blocks clearly visible; thick slightly wobbly dark-grey pencil outlines; soft pastel colours; cute notebook-doodle monster; no gloss, no gradients, no drop shadows, no glow, NO text. Monster #7: <설명>
```

## 다음부터

```text
Next sheet, exactly the same format (2 rows x 6 cells, top row slightly erased, bottom row heavily erased, flat magenta #FF00FF background, facing left, same style and size, NO text). Monster #<번호>: <설명>.
```

설명(영어)은 `tools/monster_list.py` 의 다섯째 칸.
