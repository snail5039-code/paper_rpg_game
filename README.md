# 공책 RPG (가제)

어린 시절 공책에 그려서 놀던 게임을 실제로 플레이한다.

공책 속 일본풍 도트 세계를 모험하고, 연필로 그려서 성장시키는 **2D 탑다운 실시간 액션 RPG**.

- 플랫폼: PC (Windows 우선)
- 엔진: Godot 4.7 / GDScript
- 조작: 키보드 + 마우스 (그리기는 마우스 드래그)
- 그래픽: 도트 그래픽, 필살기 연출만 일러스트 컷인

## 실행

Godot 4.7로 이 폴더를 열고 F5를 누른다. 시작 씬은 `scenes/main.tscn`이다.

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
이동·충돌, 회피, 대화, 전투, 슬라임 AI, 그리기·지우개·판정, 다리, 문 닦기, 페이지 넘김, 저장/불러오기를 자동으로 확인한다. 화면 캡처는 `res://tests/screenshot.tscn -- <출력폴더>` 로 저장한다.

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/game_state.gd` | Autoload. 퀘스트·재료·저장·일시정지 |
| `scripts/village.gd` | 첫 페이지: 배경 그림, 마스크 충돌, 배치, 다리 설계도 처리 |
| `scripts/player.gd` | 이동·회피·공격·피격 |
| `scripts/enemy_slime.gd` | 몬스터 1종 |
| `scripts/npc.gd` | 하루: 대화·퀘스트·감정 표시 |
| `scripts/goal.gd` | 빨간 문: 지우개 자국 닦기, 열림 |
| `scripts/tutorial.gd` | 오프닝, 단계별 조작 안내, 괴물 등장, 페이지 넘김 |
| `scripts/drawing_manager.gd` | 연필 모드 (선·지우개·안내선) |
| `scripts/blueprint_validator.gd` | 설계도 판정 (따라 그리기 80% + 정확도 60%) |
| `scripts/hud.gd` | HP·할 일·조작 안내·알림·대화창(초상화) |
| `scripts/art.gd` | 스프라이트 로더 |
| `tools/import_art.gd` | 원본 시트 → 게임용 스프라이트·충돌 마스크 변환 |

## 그래픽 (v4: 도트 + 크레용 질감)

원본 시트는 `assets/generated_pixel_art/pixel-v4-*`, 게임이 실제로 쓰는 파일은 `assets/sprites/`에 있다.

| 파일 | 내용 |
|---|---|
| `bg.png` | 마을 배경 한 장 (타일 없음) |
| `mask_walk.png`, `mask_solid.png` | 충돌 마스크. 흰 칸이 각각 "걸을 수 있는 곳", "막힌 곳" |
| `player_walk.png`, `npc_walk.png` | 4방향 × 걷기 4프레임 (행: 정면, 왼쪽, 오른쪽, 뒷면) |
| `slime_*.png` | 기본, 납작, 점프, 맞음 |
| `prop_bridge.png`, `prop_lead.png`, `prop_door.png` | 다리, 연필심, 빨간 문 |

원본 시트나 충돌 영역을 바꿨으면 아래 두 줄로 다시 만든다.

```
godot --headless --path . --script tools/import_art.gd
godot --headless --path . --import
```

튜토리얼 그림(`tutorial_v4` 폴더)만 다시 만들려면 첫 줄 끝에 `-- tutorial`을 붙인다.

```
godot --headless --path . --script tools/import_art.gd -- tutorial
```

- **충돌:** 강은 배경의 파란색을 읽어 자동으로 막는다. 나무 테두리와 집·덤불은 `tools/import_art.gd`의 `PLAY_RECT`, `SOLID_RECTS`에 배경 픽셀 좌표로 적는다.
- **배치:** 시작 위치, 하루, 슬라임, 문, 다리 자리는 `scripts/village.gd` 위쪽 상수에 배경 픽셀 좌표로 적는다.
- 스프라이트 파일이 없으면 캐릭터는 코드로 그린 임시 도형으로 나온다.

## 문서

- [결정 사항](docs/결정사항.md) — 지금 기준이 되는 문서
- [세부 설정](docs/세부설정.md)
- [개발 순서](docs/개발순서.md)
- [기획안 v2](docs/기획안_v2.md)
- [스토리](docs/스토리.md)
- [개발 계획](docs/개발계획.md)
- [MVP 체크리스트](docs/MVP_체크리스트.md)
