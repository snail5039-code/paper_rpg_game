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

## MVP 플레이 흐름

하루(NPC)와 대화 → 슬라임을 잡아 연필심 3개 모으기 → 강가에서 Tab → 빨간 점선을 따라 다리 그리기 → Enter → 다리를 건너 도리이 도착

## 테스트

```
godot --headless --path . res://tests/test_mvp.tscn
```
이동·충돌, 회피, 대화, 전투, 드롭, 그리기·지우개·판정, 다리 생성·통행, 저장/불러오기를 자동으로 확인한다. 화면 캡처는 `res://tests/screenshot.tscn -- <출력폴더>` 로 저장한다.

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/game_state.gd` | Autoload. 퀘스트·재료·저장·일시정지 |
| `scripts/village.gd` | 첫 페이지 맵(MAP 문자열), 배치, 다리 설계도 처리 |
| `scripts/player.gd` | 이동·회피·공격·피격 |
| `scripts/enemy_slime.gd` | 몬스터 1종 |
| `scripts/npc.gd` | NPC 대화·퀘스트 |
| `scripts/drawing_manager.gd` | 연필 모드 (선·지우개·안내선) |
| `scripts/blueprint_validator.gd` | 설계도 판정 (따라 그리기 80% + 정확도 60%) |
| `scripts/hud.gd` | HP·퀘스트·알림·대화창 |
| `scripts/placeholder_tiles.gd` | 임시 타일 생성기 |

## 도트 교체 방법

지금 그래픽은 모두 **코드로 그린 임시 그림**이다.

- **타일:** 16×16 타일을 가로로 `풀, 흙길, 나무, 집벽, 입구, 강, 다리, 지붕` 순서로 이어 붙인 PNG를 만든다. 그다음 `village.gd`의 `Tiles.build(TILE)`가 그 PNG로 만든 TileSet을 쓰도록 바꾸면 된다.
- **캐릭터·몬스터·NPC:** 각 씬(`player.tscn` 등)에 `AnimatedSprite2D`를 추가하고, 인스펙터에서 `use_placeholder_art`를 끄면 된다.

## 문서

- [기획안 v2](docs/기획안_v2.md)
- [개발 계획](docs/개발계획.md)
- [MVP 체크리스트](docs/MVP_체크리스트.md)
