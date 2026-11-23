"""tools/monster_list.py → scripts/data/monster_book.gd (몬스터 84종의 수치·친구 표). 표를 고치면 다시 돌린다.

  python3 tools/gen_monsters.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monster_list import NEW  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "data", "monster_book.gd")

# 움직임 종류별 기본 수치 (1장 기준). 장이 오를수록 커진다.
ARCH = {
    "hop": {"hp": 12, "speed": 40.0, "damage": 4, "radius": 10.0, "extra": {"windup": 0.45, "lunge_speed": 200.0}},
    "dash": {"hp": 10, "speed": 52.0, "damage": 5, "radius": 11.0, "extra": {"windup": 0.4, "lunge_speed": 210.0}},
    "swarm": {"hp": 8, "speed": 46.0, "damage": 4, "radius": 10.0, "extra": {"aggro": 80.0}},
    "ambush": {"hp": 10, "speed": 20.0, "damage": 6, "radius": 9.0, "extra": {"aggro": 46.0, "windup": 0.3, "lunge_speed": 240.0}},
    "grid": {"hp": 12, "speed": 58.0, "damage": 4, "radius": 10.0, "extra": {"grid": True}},
    "roll": {"hp": 18, "speed": 34.0, "damage": 4, "radius": 12.0, "extra": {"lunge_time": 0.45, "lunge_speed": 150.0}, "def": 1},
}
SKILL = {"hop": "통통 박치기", "dash": "몸날리기", "swarm": "떼 지어 달려들기", "ambush": "숨었다 덮치기", "grid": "직각 돌진", "roll": "굴러 돌진"}


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    return str(v)


def main():
    lines = [
        "extends RefCounted",
        "## 몬스터 90종 중 새로 더한 84종 (번호 7~90)의 수치와 친구 표. tools/gen_monsters.py 가 tools/monster_list.py 에서 만든다. 손으로 고치지 않는다.",
        "## 종 id 는 \"m<번호>\" (예: m07), 모습은 m07_faded(조금 지워진), m07_erased(많이 지워진). 그림은 mon_m07_faded.png, mon_m07_erased.png (6칸 띠).",
        "",
        "## 종 id → [이름, 장, 움직임 종류]",
        "const SPECIES := {",
    ]
    for num, name, ch, arch, _ in NEW:
        lines.append('\t"m%02d": ["%s", %d, "%s"],' % (num, name, ch, arch))
    lines.append("}")
    lines.append("")
    lines.append("## Data.MONSTERS 와 같은 꼴")
    lines.append("const MONSTERS := {")
    for num, name, ch, arch, _ in NEW:
        a = ARCH[arch]
        k = 1.0 + 0.7 * (ch - 1)          # 장마다 체력·경험치
        kd = 1.0 + 0.5 * (ch - 1)         # 장마다 공격
        for form, hm, dm, em, sp, drop in [("faded", 1.0, 1.0, 1.0, 1.0, 0.1), ("erased", 1.6, 1.25, 1.8, 1.15, 0.25)]:
            d = {
                "name": '"%s %s"' % ("조금 지워진" if form == "faded" else "많이 지워진", name),
                "art": '"strip"', "sprite": '"m%02d_%s"' % (num, form),
                "hp": round(a["hp"] * k * hm), "speed": round(a["speed"] * sp, 1), "damage": round(a["damage"] * kd * dm),
                "radius": a["radius"], "exp": round((5 + ch) * k * em), "def": a.get("def", 0) + (ch - 1) // 3,
                "drops": "[]", "chapter": ch,
            }
            for ek, ev in a["extra"].items():
                d[ek] = ev
            body = ", ".join('"%s": %s' % (key, gd(val)) for key, val in d.items())
            lines.append('\t"m%02d_%s": {%s},' % (num, form, body))
    lines.append("}")
    lines.append("")
    lines.append("## Data.FRIENDS 와 같은 꼴 (다시 그려 친구로)")
    lines.append("const FRIENDS := {")
    for num, name, ch, arch, _ in NEW:
        lines.append('\t"m%02d": {"name": "%s", "kind": "m%02d_faded", "power": %s, "skill": "%s"},' % (num, name, num, round(1.0 + 0.12 * (ch - 1), 2), SKILL[arch]))
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", OUT, len(NEW), "species")


if __name__ == "__main__":
    main()
