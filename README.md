# 공책 RPG (가제)

어린 시절 공책에 그려서 놀던 게임을 실제로 플레이한다.

공책 속 일본풍 도트 세계를 모험하고, 연필로 그려서 성장시키는 **2D 탑다운 실시간 액션 RPG**.

- 플랫폼: PC (Windows 우선)
- 엔진: Godot 4.7 / GDScript
- 조작: 키보드 + 마우스 (그리기는 마우스 드래그)
- 그래픽: 도트 그래픽, 필살기 연출만 일러스트 컷인

## 실행

Godot 4.7로 이 폴더를 열고 F5를 누른다. 시작 씬은 `scenes/title.tscn`이다.

## 조작

| 키 | 동작 |
|---|---|
| WASD | 이동 |
| 마우스 왼쪽 | 공격 (마우스 방향) |
| Space | 회피 (무적) |
| F | 대화 / 상호작용 |
| Tab | 연필 모드 켜기/끄기 |
| 연필 모드: 좌드래그 / 우드래그 또는 X | 그리기 / 지우개 |
| 연필 모드: Enter / Backspace / Esc | 완성 판정 / 전체 지우기 / 닫기 |
| F5 / F9 | 저장 / 저장 삭제 후 처음부터 |

## 1페이지 흐름 (튜토리얼)

오프닝(공책 펼치기) → 하루와 대화 → 슬라임을 잡아 연필심 3개 모으기 → 강가에서 Tab, 빨간 점선을 따라 다리 그리기, Enter → 다리를 건너 빨간 문 → 연필 모드에서 지우개로 문의 자국 닦기 → 지우개 괴물 등장 → 문으로 들어가면 페이지 넘김

지금 해야 할 조작은 화면 아래에 키 그림으로 나온다. 이야기 설정은 [docs/스토리.md](docs/스토리.md)에 있다.

## 테스트

```
godot --headless --path . res://tests/test_mvp.tscn
```
이동·충돌, 회피, 대화, 전투, 슬라임 AI, 그리기·지우개·판정, 다리, 문 닦기, 페이지 넘김, 저장/불러오기를 자동으로 확인한다. 화면 캡처는 `res://tests/shots/screenshot.tscn -- <출력폴더>` 로 저장한다.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `scenes/` | 장면 (시작 화면, 마을, 사냥터, 내 마을, 방, 탑, 연습 페이지 등) |
| `scripts/core/` | 전역 상태(`game_state.gd`, Autoload), 소리, 스프라이트 로더(`art.gd`), 시작 |
| `scripts/data/` | 데이터 표: 재료·몬스터·건물(`game_data.gd`), 아이템(`items.gd`), 연습 페이지 맵, 수업 |
| `scripts/maps/` | 맵 한 장씩: 1장 마을, 사냥터, 탑, 내 마을, 방, 연습 페이지, 시작 화면 |
| `scripts/actors/` | 맵 위에 서는 것: 주인공, 몬스터, 친구, 주민, 줍는 것, 포탈, 내 마을 건물 |
| `scripts/ui/` | 화면 위 창: HUD, 창(가방·스킬·문방구…), 강화소, 낚시, 지도, 그림판 |
| `scripts/drawing/` | 연필 모드, 설계도 판정, 그린 그림 → 도트 |
| `assets/sprites/<종류>/` | 게임이 쓰는 그림. 종류: backgrounds, buildings, characters, monsters, items, ui, effects |
| `assets/generated_pixel_art/` | ChatGPT 에서 받은 원본 시트 (`*_raw` 는 저장소에 넣지 않음), `early/` 는 초기 시안 |
| `tests/` | 자동 테스트 (`test_*.tscn`), `tests/shots/` 는 화면 캡처 도구 |
| `tools/` | 그림 변환 도구. 스프라이트를 어느 종류 폴더에 넣을지는 `tools/sprite_folders.json` |
| `docs/` | 기획 문서, 도트 프롬프트 |
| `artifacts/` | 미리보기·캡처 출력 (저장소에 넣지 않음) |

게임은 스프라이트를 이름만으로 찾는다 (`Art.tex("bld_forge")`). 그림을 새로 넣을 때는 변환 도구가 `tools/sprites.py` 의 `sprite_path()` 로 알맞은 종류 폴더에 저장한다.

## 문서

- [결정 사항](docs/결정사항.md) — 지금 기준이 되는 문서
- [세부 설정](docs/세부설정.md)
- [개발 순서](docs/개발순서.md)
- [스토리](docs/스토리.md)
- [몬스터](docs/몬스터.md)
- [도트 요구사항](docs/도트_요구사항.md)
