"""몬스터 90종 표 (본편 1~9장 × 10종). docs/세부설정.md 15, docs/몬스터.md.

번호 1~6 은 1장의 원래 몬스터(그림·수치가 이미 게임에 있다)라 여기서는 이름만 적는다.
나머지 84종: (번호, 이름, 장, 움직임 종류, 그림 설명(영어, ChatGPT 프롬프트에 쓴다))
움직임 종류: hop 통통 튀다 박치기 / dash 다가와 몸을 날림 / swarm 멀리서도 알아채고 달려듦 /
             ambush 숨어 있다 가까이 오면 튀어나옴 / grid 직각으로만 움직임 / roll 굴러서 길게 돌진
그림: tools/import_monsters.py, 프롬프트 docs/도트_프롬프트_monsters.md
"""

OLD = [(1, "낙서 슬라임"), (2, "삐뚤선"), (3, "점박이"), (4, "풀낙서"), (5, "모눈 거미"), (6, "지우개똥 벌레")]

NEW = [
    # 1장 공책 마을 (+4)
    (7, "연필심 두더지", 1, "ambush", "a little mole with a sharp pencil-lead nose that pops out of the ground"),
    (8, "포스트잇 나비", 1, "swarm", "a moth-like creature made of yellow sticky notes, flapping paper wings"),
    (9, "낙서 고양이", 1, "dash", "a scribbly doodle cat with a messy pencil-line body and a curly tail"),
    (10, "고무줄 뱀", 1, "dash", "a snake made of a stretchy coloured rubber band"),
    # 2장 색연필 숲
    (11, "회색 다람쥐", 2, "swarm", "a grey squirrel with a big fluffy tail holding an acorn"),
    (12, "연필밥 벌레", 2, "roll", "a curled bug made of pencil shavings that rolls like a wheel"),
    (13, "가시 덩굴", 2, "ambush", "a thorny vine creature with green coloured-pencil leaves and grabbing tendrils"),
    (14, "색 빠진 버섯", 2, "hop", "a faded colourless mushroom creature with a droopy cap puffing grey spores"),
    (15, "나이테 달팽이", 2, "roll", "a snail whose shell is a cut log showing tree rings"),
    (16, "깎다 만 부엉이", 2, "dash", "an owl only half-carved from a pencil, with wood-grain feathers"),
    (17, "크레용 여우", 2, "dash", "a fox coloured with orange crayon, long scribbled tail"),
    (18, "꽃잎 요정", 2, "swarm", "a tiny flower-petal fairy with petal wings and a leaf hat"),
    (19, "색연필 딱따구리", 2, "dash", "a woodpecker whose beak is a sharpened coloured pencil"),
    (20, "이끼 곰", 2, "hop", "a round little bear covered in green moss, sleepy eyes"),
    # 3장 물감 호수
    (21, "번진 개구리", 3, "hop", "a frog drawn in runny blue watercolour, its edges bleeding"),
    (22, "물감 방울", 3, "hop", "a blob of wet paint, glossy and drippy, cute face"),
    (23, "붓털 게", 3, "grid", "a crab whose claws are paintbrush tips"),
    (24, "먹물 오징어", 3, "swarm", "a small squid made of black ink, squirting ink"),
    (25, "물결 뱀장어", 3, "dash", "an eel made of a wavy blue paint stroke"),
    (26, "얼룩 해파리", 3, "swarm", "a jellyfish made of a translucent watercolour stain"),
    (27, "물감 거북", 3, "roll", "a turtle whose shell is a paint palette with colour blobs"),
    (28, "팔레트 가오리", 3, "dash", "a stingray shaped like a paint palette"),
    (29, "붓 두루미", 3, "dash", "a crane bird whose legs and neck are paintbrushes"),
    (30, "물방울 요정", 3, "swarm", "a tiny water droplet sprite with a sparkle"),
    # 4장 사인펜 도시
    (31, "순찰 깡통", 4, "dash", "a tin-can robot on little wheels with a siren light"),
    (32, "덧칠 붓", 4, "ambush", "a thick paintbrush creature dripping black ink, covering things"),
    (33, "자 병정", 4, "dash", "a toy soldier made of a wooden ruler holding a spear"),
    (34, "형광 반딧불", 4, "swarm", "a firefly glowing in neon highlighter yellow"),
    (35, "압정 고슴도치", 4, "roll", "a hedgehog whose spines are thumbtacks"),
    (36, "클립 박쥐", 4, "swarm", "a bat made of bent paperclips"),
    (37, "신호등 로봇", 4, "grid", "a small robot shaped like a traffic light with three coloured lamps"),
    (38, "지하철 지렁이", 4, "roll", "a long worm that looks like a subway train with windows"),
    (39, "사인펜 비둘기", 4, "dash", "a pigeon drawn with felt-tip marker lines"),
    (40, "우산 도깨비", 4, "hop", "a mischievous umbrella goblin hopping on one handle leg"),
    # 5장 검은 크레파스 놀이동산
    (41, "검은 풍선", 5, "swarm", "a black balloon creature with a creepy grin, floating string"),
    (42, "긁힌 목마", 5, "dash", "a carousel horse scratched out of black crayon, rainbow colours peeking through"),
    (43, "티켓 나방", 5, "swarm", "a moth whose wings are torn amusement park tickets"),
    (44, "솜사탕 유령", 5, "swarm", "a ghost made of pink cotton candy fluff"),
    (45, "태엽 원숭이", 5, "hop", "a wind-up toy monkey with cymbals and a key on its back"),
    (46, "꼬마전구 벌", 5, "swarm", "a bee whose body is a tiny glowing light bulb"),
    (47, "범퍼카 꼬마", 5, "roll", "a tiny bumper car with angry eyes"),
    (48, "팝콘 정령", 5, "hop", "a popcorn spirit made of fluffy popped kernels"),
    (49, "뽑기 집게", 5, "ambush", "a claw-machine claw creature with dangling cable"),
    (50, "거울 광대", 5, "dash", "a small clown made of funhouse mirror shards"),
    # 6장 줄 그은 일기
    (51, "취소선 뱀", 6, "dash", "a snake that is a thick strikethrough line"),
    (52, "받침 벌레", 6, "ambush", "a little bug shaped like a Korean consonant stroke hiding under letters"),
    (53, "잉크 얼룩", 6, "hop", "a spreading ink blot with eyes"),
    (54, "날짜 도장", 6, "hop", "a date stamp creature that jumps and stamps down"),
    (55, "물음표 갈고리", 6, "ambush", "a creature shaped like a question mark with a hook"),
    (56, "말줄임표", 6, "swarm", "three round dots moving together like an ellipsis creature"),
    (57, "띄어쓰기 거북", 6, "roll", "a slow turtle with a blank space bar for a shell"),
    (58, "밑줄 지렁이", 6, "dash", "a worm that is a wavy underline"),
    (59, "느낌표 토끼", 6, "hop", "a rabbit whose ears form an exclamation mark"),
    (60, "괄호 게", 6, "grid", "a crab whose two claws are round brackets"),
    # 7장 찢어진 페이지
    (61, "종이 뭉치", 7, "roll", "a crumpled yellowed paper ball with a grumpy face"),
    (62, "테이프 지네", 7, "dash", "a centipede made of sticky tape segments"),
    (63, "종이 보풀", 7, "swarm", "a small fuzzy paper lint puff"),
    (64, "스테이플러 집게", 7, "ambush", "a stapler creature that snaps its jaw"),
    (65, "좀벌레", 7, "grid", "a silverfish bug that eats holes in paper"),
    (66, "접힌 종이학", 7, "swarm", "an origami paper crane flying with sharp wings"),
    (67, "찢긴 귀퉁이 박쥐", 7, "swarm", "a bat made of a torn page corner"),
    (68, "풀칠 달팽이", 7, "roll", "a snail leaving a trail of white glue, glue-bottle shell"),
    (69, "책갈피 뱀", 7, "dash", "a snake shaped like a ribbon bookmark"),
    (70, "먼지 토끼", 7, "hop", "a dust bunny, a fluffy grey dust ball with ears"),
    # 8장 그날의 교실
    (71, "분필 유령", 8, "swarm", "a ghost drawn in white chalk dust"),
    (72, "지우개 가루 정령", 8, "swarm", "a spirit made of swirling eraser crumbs"),
    (73, "칠판 지우개", 8, "roll", "a felt blackboard eraser creature with chalk dust puffs"),
    (74, "의자 다리 거미", 8, "grid", "a spider whose legs are school chair legs"),
    (75, "크레파스 병정", 8, "dash", "a toy soldier made of a crayon stick"),
    (76, "출석부 까마귀", 8, "dash", "a crow whose wings are pages of an attendance book"),
    (77, "실내화 쥐", 8, "hop", "a mouse hiding in a white school indoor slipper"),
    (78, "시간표 뱀", 8, "dash", "a snake with a class timetable grid pattern"),
    (79, "받아쓰기 시험지", 8, "ambush", "a spelling-test paper creature with red marks and a frown"),
    (80, "리코더 새", 8, "swarm", "a bird shaped like a school recorder flute"),
    # 9장 빈 페이지
    (81, "흰 그림자", 9, "dash", "a pale white shadow figure, barely visible outline"),
    (82, "여백 해파리", 9, "swarm", "a jellyfish made of blank page margins, faint dotted outline"),
    (83, "지운 자국 늑대", 9, "dash", "a wolf made of eraser smudge marks"),
    (84, "빈 말풍선", 9, "hop", "an empty speech bubble creature"),
    (85, "투명 고래", 9, "roll", "a small transparent whale drawn only with a faint outline"),
    (86, "점선 나비", 9, "swarm", "a butterfly drawn only in dotted lines"),
    (87, "연필 끝 송곳", 9, "ambush", "a sharp pencil-tip creature that stabs up from below"),
    (88, "백지 기사", 9, "dash", "a knight made of folded blank paper with a paper sword"),
    (89, "망각 안개", 9, "swarm", "a pale fog cloud creature with sleepy eyes"),
    (90, "마지막 낙서", 9, "hop", "a tiny last doodle, a simple smiling scribble, slightly glowing"),
]

assert len(OLD) + len(NEW) == 90
