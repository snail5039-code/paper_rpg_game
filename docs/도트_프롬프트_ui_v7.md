# 도트 프롬프트 ui_v7 (창 부품, 스킬 효과, 필살기 일러스트)

ChatGPT 한 대화에서 차례로 받았다. 첫 메시지에 `ch1_v5/09_ui_common.png`(창 그림)과 `ch1_v5/07_portraits_ch1.png`(주인공 초상)을 붙였다.
받은 원본은 `assets/generated_pixel_art/ui_v7_raw/` (깃에 올리지 않음), 가져오기는 `python3 tools/import_ui_v7.py`.

공통 규칙: 크레용 질감의 굵은 도트, 흔들리는 짙은 연필 테두리, 파스텔 색, 글자 없음. 시트는 순수 마젠타(#FF00FF) 바탕, 칸마다 그림 하나, 칸 경계선 없음.

| 파일 | 크기 | 내용 (왼쪽 위부터) | 게임에서 쓰는 이름 |
|---|---|---|---|
| `23_ui_kit.png` | 4칸 × 3줄 | 목록 줄 띠, 네모 단추, 눌린 네모 단추, 닫기 단추 / 스크롤 홈, 지우개 모양 스크롤 손잡이, 왼쪽 화살표, 오른쪽 화살표 / 모눈종이 그림판, 지우개 가루, 가격표, 제목 판 | `ui_row`, `ui_btn_sq`, `ui_btn_sq_on`, `ui_close`, `ui_scroll_track`, `ui_scroll_knob`, `ui_arrow_l`, `ui_arrow_r`, `ui_board`, `icon_dust`, `ui_tag`, `ui_plaque` |
| `24_skill_fx.png` | 4칸 × 2줄 | 길게 긋기, 동그라미, 점 찍기(연필심 조각), 빗금 / 꾹 눌러 쓰기(충격), 쓱 지우기(지우개 가루 구름), 맞은 자리 불꽃, 필살기 별 | `fx_slash`, `fx_circle`, `fx_dot`, `fx_hatch`, `fx_press`, `fx_erase`, `fx_hit`, `fx_star` |
| `25_ult_cutin.png` | 3:2 일러스트 | 주인공이 큰 연필로 점선 별을 그리는 필살기 컷인. 가운데 62% 띠만 잘라 쓴다 | `ult_cutin` |

스킬 효과는 한 장짜리 그림이고, 움직임(돌기, 커지기, 사라지기)은 코드(`scripts/player.gd` 의 `_draw_skill_fx`)가 만든다.

## 생활·보스 그림 (같은 대화에서 이어 받음)

| 파일 | 크기 | 내용 | 게임에서 쓰는 이름 |
|---|---|---|---|
| `26_food.png` | 4칸 × 3줄 | 물고기 8종과 잡동사니 4종 | `food_0` ~ `food_11` |
| `27_crops.png` | 4칸 × 4줄 | 작물 8종, 씨앗 봉투, 풀·돌·나뭇가지·열매, 빵, 물뿌리개, 하트 | `crop_0` ~ `crop_7`, `icon_seed`, `forage_0` ~ `forage_3`, `icon_bread`, `icon_water`, `icon_heart` |
| `28_dishes.png` | 4칸 × 3줄 | 요리 8종, 밭, 식당, 새싹, 풍선 | `dish_0` ~ `dish_7`, `bld_farm`, `bld_diner`, `crop_sprout`, `deco_balloon` |
| `29_furniture.png` | 4칸 × 3줄 | 가구 12종 | `furn_0` ~ `furn_11` |
| `30_bosses.png` | 3칸 × 1줄 | 왕 지우개똥 벌레, 구겨진 종이 구깃이, 떠돌이 큰 낙서 | `boss_0` ~ `boss_2` |
| `31_room_bg.png` | 16:9 배경 | 빈 방 (벽지와 나무 바닥) | `bg_room` |
| `32_title.png` | 16:9 일러스트 | 시작 화면: 책상 위에 펼친 공책, 왼쪽 쪽의 마을과 주인공, 비어 있는 오른쪽 쪽 | `bg_title` |
| `33_hats_a.png`, `34_hats_b.png` | 5칸 × 3줄씩 | 주인공 머리에 맞춰 그린 모자 10종. 줄은 앞, 옆(왼쪽을 봄), 뒤. 주인공의 앞·옆·뒤 그림(artifacts/hat_ref.png)을 붙여서 요청 | `hat_<모양>_<0 앞, 1 옆, 2 뒤>` |
