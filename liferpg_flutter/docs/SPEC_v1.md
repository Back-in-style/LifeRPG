# SPEC_v1 — 기존 KivyMD LifeRPG 앱 동작 명세

> 작성: A1 (기존 앱 분석). 대상: `liferpg-1.0.0` debug APK의 `assets/private/main.pyc` (Python 3.11, 원본 경로 `/home/marco/liferpg/.buildozer/android/app/main.py`).
> 근거: `legacy/main_decompiled.py`(pycdc, 부분) + `legacy/main_disasm.txt`(pycdas 바이트코드). 디컴파일이 깨진 함수는 전부 바이트코드로 재구성했다.
> **바이너리가 진실의 원천**이다. PLAN.md §0과 다른 점은 §6에 모았다. 바이트코드로도 확정 못 한 것은 §7에만 적었다.
> 표기: `"..."`는 원본 문자열 그대로(공백 포함), Python 의사코드는 바이트코드를 그대로 옮긴 것이다.

---

## 1. 개요 / 파일 구조 / 저장 위치

### 1.1 구성
단일 파일 앱(`main.py`). 구성 요소:

| 구성 | 역할 |
|---|---|
| 모듈 상수 | `APP_NAME`, `STAT_KEYS`, `CATEGORY_TO_TREE`, `DAILY_GROUPS`, `STUDY_KEYWORDS`, `ROUTINE_KEYWORDS`, `DIFFICULTY_MULTIPLIER`, `GRADE_COLORS_HEX`, `ACHIEVEMENT_DEFS` |
| 순수 함수 | `get_daily_group`, `rewards_to_text`, `grade_from_cap`, `clamp_to_cap`, `tree_xp_to_next_level`, `compute_tree_level`, `now_str`, `today_str`, `calc_dday` |
| `GameStore` | JSON 4개 로드/저장, 게임 규칙 전부 (퀘스트 CRUD, XP, 스탯, 돌파, 업적, 일일 리셋, 로그) |
| 화면 | `StatusScreen`, `QuestsScreen`, `LogsScreen` + 다이얼로그 내용 `AddQuestContent`, `QuestDetailContent` |
| `LifeRPGApp(MDApp)` | 폰트 등록, 테마, `GameStore` 생성, 레거시 가져오기, 하단 탭 |

KV 문자열에 `StatCard@MDCard`, `QuestListItem@TwoLineListItem`, `SectionHeader@MDBoxLayout` 템플릿이 정의돼 있지만 **코드에서 쓰지 않는다** (화면은 전부 Python으로 위젯을 만든다).

### 1.2 저장 위치
- `data_dir = os.path.join(App.user_data_dir, "data")`
- 파일: `data_dir/profile.json`, `data_dir/quests.json`, `data_dir/log.json`, `data_dir/achievements.json`
- `GameStore.__init__`이 `os.makedirs(data_dir, exist_ok=True)` 실행.
- Android에서 `user_data_dir`의 실제 경로는 Kivy 버전에 따라 다르다 (§7 참고).

### 1.3 로드 (`_load(path, default)`)
```python
try:
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
except Exception:
    pass
return default
```
- 파일이 없거나 JSON이 깨졌으면 **조용히 기본값**을 쓴다 (오류 표시 없음, 백업 없음). 다음 저장 때 기본값으로 덮어쓴다.
- 로드한 값의 타입은 검사하지 않는다 (`profile`만 `_migrate_profile`에서 부분 보정).

### 1.4 저장
- `save_all()`: (profile, quests, log, achievements) 4개 파일을 순서대로 `path + ".tmp"`에 `json.dump(obj, f, ensure_ascii=False, indent=2)`로 쓴 뒤 `os.replace(tmp, path)`. 파일마다 원자적이지만 4개 전체가 하나의 트랜잭션은 아니다.
- `log()`는 이벤트를 추가한 뒤 **log.json만** 같은 방식(tmp→replace)으로 즉시 저장한다.

### 1.5 GameStore 초기화 순서
```
__init__(data_dir):
  makedirs
  profile      = _load(profile.json, _default_profile())
  quests_data  = _load(quests.json, {"quests": [], "next_id": 1})
  logs_data    = _load(log.json, {"events": []})
  achievements = _load(achievements.json, {"unlocked": []})
  _migrate_profile()
  _rollover_daily_if_needed()   # 날짜가 바뀌었으면 log + save_all
  _recompute_levels()           # 메모리에서만 계산 (여기서는 저장 안 함)
```

### 1.6 레거시 import 폴더 (`LifeRPGApp._import_legacy_json`)
`build()`에서 `self.store = GameStore(data_dir)` **바로 다음**, 화면을 만들기 **전**에 호출된다.
```python
import_dir = os.path.join(self.user_data_dir, "import")
if not os.path.isdir(import_dir): return
mapping = {"profile.json": data_dir/"profile.json", "quests.json": ..., "log.json": ..., "achievements.json": ...}
imported = []
for src_name, dst_path in mapping.items():
    src_path = os.path.join(import_dir, src_name)
    if os.path.exists(src_path):
        try:
            shutil.copy2(src_path, dst_path)
            imported.append(src_name)
            logging.info(f"[Import] {src_name} → {dst_path}")
        except Exception as e:
            logging.error(f"[Import] {src_name} 복사 실패: {e}")
if imported:
    try: shutil.rmtree(import_dir)
    except Exception: pass
    self.store = GameStore(os.path.join(self.user_data_dir, "data"))
    logging.info(f"[Import] 이전 완료: {imported}")
```
- 파일 단위 **덮어쓰기 복사**이고 병합하지 않는다. 있는 파일만 바꾼다.
- 하나라도 복사되면 import 폴더 전체를 지우고 `GameStore`를 다시 만든다 (그래서 마이그레이션/리셋/레벨 재계산이 다시 돈다).
- 파일 이름은 `log.json`이다 (`logs.json` 아님).

### 1.7 폰트
`NanumGothic.ttf`를 `dirname(__file__)/NanumGothic.ttf` → `dirname(__file__)/fonts/NanumGothic.ttf` → `user_data_dir/NanumGothic.ttf` 순서로 찾아서 `LabelBase.register(name="Roboto", fn_regular=...)`로 기본 폰트를 바꾼다 (Regular만 등록하고 Bold는 없음). APK에는 `assets/private/NanumGothic.ttf`가 들어 있다.

---

## 2. 데이터 스키마

모든 JSON은 UTF-8, `ensure_ascii=False`(한글 키/값을 그대로 저장), `indent=2`. Python 값이라 int와 float를 구분해 저장한다 (예: `30`과 `30.0`). **임포터는 숫자를 모두 `num`으로 받아야 한다.**

### 2.1 profile.json

기본값(`_default_profile()`), 키 순서 그대로:
```json
{
  "app": "LifeRPG",
  "trees": { "physical": { "xp": 0, "level": 1, "xp_in_level": 0, "xp_next": 200 } },
  "main_level": 1,
  "today_date": "<today_str()>",
  "today_xp": 0,
  "stats":     { "힘": 10, "민첩": 10, "정신력": 10, "지구력": 10 },
  "stat_caps": { "힘": 30, "민첩": 30, "정신력": 30, "지구력": 30 },
  "traits": {},
  "streak_days": 0,
  "last_active_date": null
}
```

| 필드 | 타입 | 기본값 | 의미 / 갱신 |
|---|---|---|---|
| `app` | str | `"LifeRPG"` | 고정. 읽지 않음 |
| `trees` | dict[str, Tree] | `{"physical": {...}}` | 스킬 트리. 실제로 XP를 받는 트리는 `physical`뿐 |
| `trees.<t>.xp` | int | 0 | 누적 총 XP. `grant_tree_xp`에서 `int(xp) + int(amount)` |
| `trees.<t>.level` | int | 1 | **physical만** `_recompute_levels`가 다시 계산. 다른 트리는 저장된 값 그대로 |
| `trees.<t>.xp_in_level` | int | 0 | 현재 레벨 안에서 쌓은 XP (physical만 재계산) |
| `trees.<t>.xp_next` | int | 200 | 현재 레벨에서 필요한 XP (physical만 재계산) |
| `main_level` | int | 1 | `max(1, sum(int(tree.get("level",1)) for tree in trees.values()))` |
| `today_date` | str `YYYY-MM-DD` | 오늘 | 일일 리셋 기준 날짜 |
| `today_xp` | int | 0 | 오늘 받은 트리 XP 합계 |
| `stats` | dict[str, num] | 각 10 | 현재 스탯. 보상을 받으면 `round(v, 3)`로 저장돼 float가 된다 |
| `stat_caps` | dict[str, num] | 각 30 | 스탯 상한. 돌파에 성공하면 float(예: `50.0`)로 저장 |
| `traits` | dict | `{}` | **사용 안 함** |
| `streak_days` | int | 0 | **사용 안 함** (어디서도 읽거나 쓰지 않음, §4.9) |
| `last_active_date` | str\|null | null | **사용 안 함** |

### 2.2 `_migrate_profile()` 규칙 (바이트코드로 확인)
로드 직후 실행되고 순서는 다음과 같다:
1. `profile["stats"]`가 dict가 아니면 → `_default_profile()["stats"]`로 바꾼다.
2. `old_keys = set(stats.keys())`
   - **`old_keys ⊇ {"charm","focus","communication"}` 이고 `old_keys ∩ set(STAT_KEYS) == ∅`** 이면 → `stats = {"힘":10,"민첩":10,"정신력":10,"지구력":10}`로 **통째로 바꾼다** (옛 7종 영문 스탯 스키마에서 넘어온 경우로 보인다. 옛 값은 버려진다).
   - 그 밖에는 → `for k in STAT_KEYS: stats.setdefault(k, 10)` (다른 키는 남겨 둔다).
   - (디컴파일본의 `if not ... and ...`는 틀렸다. 실제 조건은 위와 같다.)
3. `stat_caps`가 dict가 아니면 `{}`로 둔 뒤 `for k in STAT_KEYS: stat_caps.setdefault(k, 30)`. 옛 키(영문 등)는 **지우지 않는다**.
4. `"trees"`가 없으면 `{}`.
5. `trees`에 `"physical"`이 없으면 `{"xp":0,"level":1,"xp_in_level":0,"xp_next":200}` 추가. **다른 트리는 지우지 않는다** → 옛 트리가 남아 있으면 그 `level`이 `main_level` 합계에 계속 들어간다.
6. `profile.setdefault("main_level", 1)`.
- 마이그레이션 자체는 저장하지 않는다. 다음 `save_all`(같은 날이어도 리셋/완료/추가 때) 때 디스크에 반영된다.
- `today_date`, `today_xp`, `traits`, `streak_days`, `last_active_date`, `app`은 채워 넣지 않는다 (없으면 `.get` 기본값을 쓴다).

### 2.3 quests.json
```json
{ "quests": [Quest, ...], "next_id": 1 }
```
- `next_id`: int. `add_quest`가 `qid = next_id`(없으면 1)를 쓰고 `next_id = qid + 1`. 지워도 줄어들지 않는다.

**Quest 객체** (`add_quest`가 만드는 순서 그대로):

| 필드 | 타입 | 일반(Daily/Side/Main) | 돌파 |
|---|---|---|---|
| `id` | int | next_id | next_id |
| `category` | str | `"Gym"`\|`"Swim"`\|`"Mobility"`\|`"Recovery"`\|`"Other"` | **`"돌파"`** (UI가 고정 전달) |
| `type` | str | `"Daily"`\|`"Side"`\|`"Main"` | `"돌파"` |
| `title` | str | 입력값 `.strip()` | 동일 |
| `xp` | int | `max(1, int(base_xp * DIFFICULTY_MULTIPLIER.get(difficulty, 1)))` | `0` |
| `rewards` | dict | `{"힘": f, "민첩": f, "정신력": f, "지구력": f}` (4개 키 모두 float, 기본 `0.0`) | `{"unlock_stat": str, "unlock_to": float}` |
| `difficulty` | str | `"Easy"`\|`"Normal"`\|`"Hard"` | `"Normal"` (고정) |
| `deadline` | str\|null | 입력값 `.strip() or None` (형식 검증 없음) | 동일 |
| `progress` | int | 0 | 0 |
| `status` | str | `"ACTIVE"`\|`"DONE"` | 동일 |
| `created_at` | str | `now_str()` = `"%Y-%m-%d %H:%M:%S"` 로컬 시각 | 동일 |
| `completed_at` | str\|null | null → 완료 시 `now_str()`, Daily 리셋 때 null | 동일 |
| `desc` | str | 입력값 `.strip()` (빈 문자열 가능) | 동일 |
| `base_xp` | int | 입력 XP (배율 전). **일반 퀘스트에만 있다**, 맨 뒤 키 | 없음 |
| `unlock_stat` | str | 없음 | STAT_KEYS 중 하나 |
| `unlock_to` | float | 없음 | 새 상한값 |

- `status` 값은 `"ACTIVE"`/`"DONE"` 두 가지뿐이다.
- 읽을 때는 `.get` 기본값을 쓴다: `type ""`, `status "ACTIVE"`, `xp 0`, `difficulty "Normal"`, `category "Other"`, `deadline ""`, `rewards {}`, `desc ""`, `progress 0`, `title ""`.
- id는 `str(q.get("id")) == str(qid)`로 비교한다 (문자열·정수 둘 다 받는다). 정렬할 때는 `int(q.get("id", 0))`.

### 2.4 log.json
```json
{ "events": [Event, ...] }
```
**Event 객체**:
```json
{ "ts": "YYYY-MM-DD HH:MM:SS", "type": "<event_type>", "message": "<str>", "meta": {} }
```
- `meta`: 시그니처는 `log(event_type, message, meta=None)`이고 None이면 `{}`. **호출하는 쪽에서 meta를 넘기지 않으므로 항상 `{}`**.
- 저장할 때 개수 제한이 없다 (계속 늘어난다). UI는 마지막 200개만 보여 준다.

**event_type 종류와 메시지 형식** (모든 생성 지점):

| type | message | 발생 지점 |
|---|---|---|
| `system` | `f"일일 퀘스트 초기화: {today}"` | 날짜가 바뀐 뒤 리셋 |
| `system` | `f"{tree_name.upper()} 레벨업! Lv.{before} → Lv.{after}"` → 실제로는 `"PHYSICAL 레벨업! Lv.1 → Lv.2"` | 트리 레벨업 |
| `system` | `"오늘 XP 초기화"` | 상태창 수동 초기화 |
| `xp` | `f"{tree_name.upper()} XP +{amount}: {reason}"` → `"PHYSICAL XP +30: 퀘스트: {title}"` | 트리 XP 지급 |
| `quest` | `f"퀘스트 추가: [{qtype}] {title} (+{adj_xp}XP, {difficulty})"` | 일반 퀘스트 추가 |
| `quest` | `f"돌파 퀘스트 추가: {title}"` | 돌파 퀘스트 추가 |
| `quest` | `f"퀘스트 완료: {title}"` | 완료 |
| `quest` | `f"퀘스트 삭제: {title}"` | 삭제 |
| `breakthrough` | `f"돌파 성공: {stat} 상한 {old_cap} → {new_cap}"` (float 그대로, 예: `"돌파 성공: 힘 상한 30.0 → 50.0"`) | 돌파 성공 때만 |
| `stat` | `f"스탯 상승: {sk} +{applied:g}"` | 스탯 상승분이 0보다 클 때 |
| `achievement` | `f"업적 달성: {icon} {name} — {desc}"` (구분자는 em dash `—`) | 업적 해금 |

### 2.5 achievements.json
```json
{ "unlocked": ["first_quest", "quest_10", ...] }
```
- `set`에서 `list(...)`로 바꿔 저장하므로 **순서는 보장되지 않는다**.
- 해금하면 되돌리지 않는다 (해금 취소 로직 없음).

---

## 3. 상수

```python
APP_NAME = "LifeRPG"
STAT_KEYS = ["힘", "민첩", "정신력", "지구력"]
CATEGORY_TO_TREE = {"Gym": "physical", "Swim": "physical", "Mobility": "physical", "Recovery": "physical"}
# "Other"는 매핑이 없다 → 트리 XP 없음
DAILY_GROUPS = [
  ("grp_dayA",    "🅰️ Day A — 등·하체·삼두"),
  ("grp_dayB",    "🅱️ Day B — 가슴·어깨·이두"),
  ("grp_core",    "🔄 코어"),
  ("grp_swim",    "🌊 수영 데이"),
  ("grp_study",   "📚 학업"),
  ("grp_routine", "🌙 루틴"),
  ("grp_etc",     "📦 기타 Daily"),
]
STUDY_KEYWORDS   = ("강의", "복습", "과제", "집중", "공부")
ROUTINE_KEYWORDS = ("기상", "취침", "식단")
DIFFICULTY_MULTIPLIER = {"Easy": 0.7, "Normal": 1, "Hard": 1.5}   # Normal은 int 1
GRADE_COLORS_HEX = {"S": "#FFD700", "A": "#8A2BE2", "B": "#1E90FF", "C": "#32CD32", "D": "#808080"}
```

UI 선택지 (AddQuestContent):
- 종류: `("Daily", "Side", "Main", "돌파")`
- 카테고리: `["Gym", "Swim", "Mobility", "Recovery", "Other"]`
- 난이도: `["Easy", "Normal", "Hard"]`
- 필터 칩: `("All", "Daily", "Side", "Main", "돌파")`
- 스탯 아이콘: `{"힘": "💪", "민첩": "⚡", "정신력": "🧠", "지구력": "❤️"}`
- 퀘스트 종류 배지: `{"Daily": "🔁", "Side": "📌", "Main": "⭐", "돌파": "💥"}` (그 외 `""`)
- 로그 아이콘: `{"xp": "⚡", "quest": "📋", "stat": "📊", "system": "🔧", "achievement": "🏆", "breakthrough": "💥"}` (그 외 `"📝"`)

### 3.1 ACHIEVEMENT_DEFS (순서 그대로)
| id | name | desc | icon |
|---|---|---|---|
| `first_quest` | 첫 발걸음 | 첫 번째 퀘스트를 완료했다! | 🏁 |
| `first_levelup` | 각성 | 첫 레벨업을 달성했다! | ⚡ |
| `quest_10` | 모험가 | 퀘스트를 10개 완료했다! | ⚔ |
| `quest_50` | 영웅 | 퀘스트를 50개 완료했다! | 🛡 |
| `first_breakthrough` | 한계 돌파 | 첫 돌파 퀘스트를 완료했다! | 💥 |
| `stat_max_d` | D랭크 달성 | 스탯 하나가 상한에 도달했다! | 📊 |
| `level_5` | 숙련자 | 메인 레벨 5를 달성했다! | 🌟 |
| `level_10` | 전문가 | 메인 레벨 10을 달성했다! | ✨ |

### 3.2 등급 (`grade_from_cap(cap_value)`) — **현재 값이 아니라 상한(cap)으로 매긴다**
```python
try: cap = float(cap_value)
except: cap = 30
if cap <= 30:  return "D"
if cap <= 50:  return "C"
if cap <= 100: return "B"
if cap <= 200: return "A"
return "S"            # cap > 200
```

### 3.3 레벨 공식
```python
tree_xp_to_next_level(tree, level) = 200 + (level - 1) * 80      # tree 인자는 무시

compute_tree_level(tree, total_xp):
    level, xp_left = 1, total_xp
    while True:
        need = tree_xp_to_next_level(tree, level)
        if xp_left >= need: xp_left -= need; level += 1
        else: break
    return (level, xp_left, tree_xp_to_next_level(tree, level))
```
- 레벨 L에 도달하는 누적 XP = `200(L-1) + 40(L-1)(L-2)`. Lv2=200, Lv3=480, Lv4=840, Lv5=1280, Lv10=4680.
- 레벨 상한 없음.
- `main_level = max(1, Σ int(tree.get("level", 1)))`. 기본 데이터(트리 1개)에서는 Physical 레벨과 같다.

### 3.4 기본 스탯 / 상한
기본 스탯은 각 `10`, 기본 상한은 각 `30`(등급 D). 코드 곳곳의 `.get(sk, 0)`(스탯)과 `.get(sk, 30)`(상한) 기본값도 같다.

---

## 4. 게임 규칙

### 4.1 퀘스트 추가 `add_quest(title, qtype, desc, category, xp, difficulty, deadline, rewards, unlock_stat=None, unlock_to=None)`
1. id 할당(§2.3), 공통 필드로 quest dict를 만든다 (`xp: 0`, `rewards: {}`, `deadline: deadline or None`, `progress: 0`, `status: "ACTIVE"`, `created_at: now_str()`, `completed_at: None`).
2. `qtype == "돌파"`이면: `unlock_stat`, `unlock_to` 필드를 넣고 `rewards = {"unlock_stat":..., "unlock_to":...}`, log `quest` `"돌파 퀘스트 추가: {title}"`.
3. 그 밖에는:
   - `mult = DIFFICULTY_MULTIPLIER.get(difficulty, 1)`
   - `adj_xp = max(1, int(xp * mult))` — **소수점 이하 버림(truncate)**, 최소 1. IEEE 부동소수 곱셈 그대로다 (예: 10×0.7 = 7.000000000000001 → 7, 3×0.7 = 2.0999… → 2, 30×0.7 → 21, 30×1.5 → 45). Dart에서는 `max(1, (xp * mult).truncate())`로 같은 결과가 나온다.
   - `quest.xp = adj_xp`, `quest.base_xp = xp`, `quest.rewards = rewards`
   - log `quest` `"퀘스트 추가: [{qtype}] {title} (+{adj_xp}XP, {difficulty})"`
4. `quests.append`, `save_all()`, quest를 돌려준다.

UI가 넘기는 인자 (`AddQuestContent.submit`):
- 돌파: `add_quest(title, "돌파", desc, "돌파", 0, "Normal", deadline, {}, self._unlock_stat, float(bt_cap_field.text.strip()))`
- 일반: `add_quest(title, self._quest_type, desc, self._category, int(xp_field.text.strip()), self._difficulty, deadline, rewards)`, 여기서 `rewards = {sk: float(rwd_fields[sk].text or 0) for sk in STAT_KEYS}`.

### 4.2 퀘스트 완료 `complete_quest(qid) -> (result, err)`
```
q = find_quest(qid)
if not q:                       return (None, "퀘스트를 찾지 못했음")
if q.status == "DONE":          return (None, "이미 완료된 퀘스트임")
q.status = "DONE"; q.completed_at = now_str()
log("quest", f"퀘스트 완료: {title}")
result = {"leveled_up": False, "breakthrough": None, "stat_gains": []}

if q.type == "돌파":
    stat = q.get("unlock_stat"); unlock_to = q.get("unlock_to")
    if stat in STAT_KEYS and isinstance(unlock_to, (int, float)):
        old_cap = float(stat_caps.get(stat, 30)); new_cap = float(unlock_to)
        if new_cap > old_cap:                         # 엄격히 클 때만
            stat_caps[stat] = new_cap
            log("breakthrough", f"돌파 성공: {stat} 상한 {old_cap} → {new_cap}")
            result.breakthrough = {stat, old_cap, new_cap, success: True}
        else:
            result.breakthrough = {stat, old_cap, new_cap, success: False}   # 상한 변화 없음
    # 조건을 못 맞추면 breakthrough = None
    # 돌파 퀘스트는 트리 XP도 스탯 보상도 없다
else:
    tree = CATEGORY_TO_TREE.get(q.get("category", "Other"))
    if tree:
        result.leveled_up = grant_tree_xp(tree, int(q.get("xp", 0)), f"퀘스트: {title}")
    rewards = q.get("rewards", {})
    if isinstance(rewards, dict):
        for sk in STAT_KEYS:
            delta = float(rewards.get(sk, 0) or 0)
            if delta == 0: continue
            cur = float(stats.get(sk, 0)); cap = float(stat_caps.get(sk, 30))
            new_v, applied = clamp_to_cap(cur, delta, cap)
            stats[sk] = round(new_v, 3)
            if applied > 0:
                result.stat_gains.append(f"+{applied:g} {sk}")
                log("stat", f"스탯 상승: {sk} +{applied:g}")

_recompute_levels(); save_all()
result["new_achievements"] = _check_achievements()   # ACHIEVEMENT_DEFS 항목(dict) 리스트
return (result, None)
```
`clamp_to_cap(cur, delta, cap_value)`:
```python
if delta == 0: return (cur, 0)
cap = float(cap_value); target = cur + delta
if target <= cap: return (target, delta)
applied = max(0, cap - cur)
return (cap, applied)
```
엣지 케이스 (원본 동작 그대로):
- **음수 보상**도 허용된다. `target <= cap`이면 스탯이 줄고, `applied < 0`이라 로그나 메시지에는 남지 않는다.
- `cur > cap`인 상태에서 양수 보상을 받으면 → 스탯이 **cap으로 내려간다** (`applied = 0`).
- 카테고리 `Other`는 트리 XP와 `today_xp`가 없고 스탯 보상만 적용된다.
- `round(x, 3)`은 Python의 banker's rounding(이진 부동소수 기준)이다.
- 완료해도 `progress`를 100으로 바꾸지 않는다.

`grant_tree_xp(tree_name, amount, reason)`:
```
if amount <= 0: return False
tree = profile["trees"].get(tree_name); if not tree: return False
before = int(tree.get("level", 1))
tree.xp = int(tree.get("xp",0)) + int(amount)
profile.today_xp = int(profile.get("today_xp",0)) + int(amount)
_recompute_levels()
after = int(trees[tree_name].get("level",1))
log("xp", f"{tree_name.upper()} XP +{amount}: {reason}")
if after > before: log("system", f"{tree_name.upper()} 레벨업! Lv.{before} → Lv.{after}")
save_all()
return after > before
```
- `leveled_up`은 트리 레벨 기준이다 (메인 레벨 기준 아님).
- 완료 한 번에 생기는 로그 순서: `quest 완료` → `xp` → (`system 레벨업`) → `stat`×n → `achievement`×n.

### 4.3 삭제 `delete_quest(qid) -> bool`
```
q = find_quest(qid); if not q: return False
qid_str = str(qid)
quests = [x for x in quests if str(x.get("id", "")) != qid_str]
log("quest", f"퀘스트 삭제: {q.get('title','')}")
save_all(); return True
```
- 이미 받은 XP, 스탯, 상한, 업적은 **되돌리지 않는다**.

### 4.4 진행률 `update_progress(qid, progress)`
- `q["progress"] = int(progress)` (슬라이더 float 값을 버림), `save_all()`.
- **완료 버튼을 누를 때만** 호출된다 (`_do_complete`에서 type이 `Side`/`Main`이고 상세 내용에 slider가 있을 때). 슬라이더를 움직이기만 하고 닫으면 **저장되지 않는다**. 결국 진행률은 완료 시점의 값이 한 번 기록될 뿐이고 표시 외에는 쓰이지 않는다.
- 슬라이더는 `Side`/`Main`이면서 `ACTIVE`일 때만 보인다. `Daily`/`돌파`에는 진행률 UI가 없다.

### 4.5 일일 리셋 `_rollover_daily_if_needed()`
```
today = date.today().isoformat()
if profile.get("today_date") == today: return
profile.today_date = today; profile.today_xp = 0
for q in quests: if q.get("type") == "Daily": q.status = "ACTIVE"; q.completed_at = None
log("system", f"일일 퀘스트 초기화: {today}")
save_all()
```
- 호출 시점은 `GameStore.__init__`(앱 시작), `StatusScreen.refresh()`, `QuestsScreen.refresh()` 세 곳이다. 백그라운드 타이머나 on_resume 훅은 없다 → 앱을 켜 둔 채 자정을 넘기면 다음 refresh 때 반영된다.
- 날짜가 **같지 않으면** 무조건 리셋한다 (날짜를 거꾸로 돌려도 리셋).
- `Side`/`Main`/`돌파`의 상태는 건드리지 않는다.
- `progress`는 리셋하지 않는다.

### 4.6 today_xp
- `grant_tree_xp`에서만 늘어난다 (= 매핑된 카테고리의 일반 퀘스트 XP).
- 리셋 때와 상태창 "오늘 XP 초기화" 버튼(`_do_reset`: `today_xp = 0`, `today_date = today_str()`, log `system "오늘 XP 초기화"`, save_all)에서 0이 된다.
- 표시 외에는 쓰이지 않는다 (게임 규칙에 영향 없음).

### 4.7 업적 `_check_achievements() -> list[adef]`
`complete_quest`의 마지막에서만 호출된다 (시작, 추가, 삭제 때는 검사하지 않음).
```
unlocked = set(achievements.get("unlocked", []))
done_quests = [q for q in quests if q.get("status") == "DONE"]
done_count = len(done_quests)
main_level = int(profile.get("main_level", 1))
checks = [
  ("first_quest",        done_count >= 1),
  ("quest_10",           done_count >= 10),
  ("quest_50",           done_count >= 50),
  ("first_levelup",      main_level >= 2),
  ("level_5",            main_level >= 5),
  ("level_10",           main_level >= 10),
  ("first_breakthrough", any(q.get("type") == "돌파" for q in done_quests)),
]
newly = [aid for aid, cond in checks if aid not in unlocked and cond]
if "stat_max_d" not in unlocked:
    stats = profile.get("stats", {}); caps = profile.get("stat_caps", {})
    if any(float(stats.get(k, 0)) >= float(caps.get(k, 30)) for k in STAT_KEYS):
        newly.append("stat_max_d")
new_defs = []
for aid in newly:
    unlocked.add(aid)
    adef = next((a for a in ACHIEVEMENT_DEFS if a["id"] == aid), None)
    if adef:
        log("achievement", f"업적 달성: {adef['icon']} {adef['name']} — {adef['desc']}")
        new_defs.append(adef)
if newly:
    achievements["unlocked"] = list(unlocked); save_all()
return new_defs
```
**정확한 해금 조건 요약:**
| id | 조건 (완료 직후 판정) |
|---|---|
| first_quest | 현재 `status=="DONE"`인 퀘스트 수 ≥ 1 |
| quest_10 | 현재 DONE 퀘스트 수 ≥ 10 |
| quest_50 | 현재 DONE 퀘스트 수 ≥ 50 |
| first_levelup | `main_level` ≥ 2 |
| level_5 | `main_level` ≥ 5 |
| level_10 | `main_level` ≥ 10 |
| first_breakthrough | DONE인 `type=="돌파"` 퀘스트가 하나라도 있음 (**돌파 실패여도 해금**) |
| stat_max_d | STAT_KEYS 중 하나라도 `stats[k] >= stat_caps[k]` (등급과 무관, 이름만 "D랭크") |

- 주의: 완료 수는 **누적 완료 횟수가 아니라 지금 DONE 상태인 퀘스트 개수**다. Daily는 매일 ACTIVE로 돌아가고 삭제하면 목록에서 빠지므로 개수가 줄 수 있다. 같은 Daily를 50일 동안 완료해도 quest_50은 해금되지 않는다.
- 반환 순서는 위 표의 checks 순서 다음에 stat_max_d가 온다. UI는 업적마다 `Clock.schedule_once(..., 0.5)`로 팝업을 띄우므로 여러 개면 0.5초 뒤 한꺼번에 겹쳐 열린다.

### 4.8 Daily 그룹 분류 `get_daily_group(quest)` (우선순위 순)
```python
desc  = quest.get("desc", "")
title = quest.get("title", "")
cat   = quest.get("category", "Other")
if desc.startswith("[Day A]"):                         return "grp_dayA"
if desc.startswith("[Day B]"):                         return "grp_dayB"
if desc.startswith("[수영 데이]") or cat == "Swim":     return "grp_swim"
if cat == "Gym":                                       return "grp_core"
if any(kw in title for kw in STUDY_KEYWORDS):          return "grp_study"
if any(kw in title for kw in ROUTINE_KEYWORDS):        return "grp_routine"
return "grp_etc"
```
- Day A/B는 **설명(desc)의 접두어**로만 판정한다 (제목 키워드 아님, 대소문자·공백까지 정확히 일치해야 함).
- desc 접두어가 없는 `Gym` 퀘스트는 전부 "🔄 코어"로 간다.
- 학업/루틴은 **제목(title)** 부분 문자열로 판정한다. Mobility/Recovery/Other 카테고리만 여기까지 내려온다.
- `type == "Daily"`인 퀘스트에만 적용한다 (QuestsScreen에서).

### 4.9 스트릭
- `streak_days`, `last_active_date`는 `_default_profile`의 키 목록에만 있다. 바이트코드 전체에서 이 이름은 **`_default_profile` 상수 튜플에만 나온다**. 갱신, 표시, 판정 로직은 **없다** (미구현). 마이그레이션에서도 채우지 않는다.

### 4.10 D-day `calc_dday(deadline_str)`
```python
if not deadline_str: return ""
try:
    dl = datetime.strptime(deadline_str, "%Y-%m-%d").date()
    diff = (dl - date.today()).days
    if diff > 0:  return f"D-{diff}"
    if diff == 0: return "D-Day!"
    return f"D+{abs(diff)}"
except: return ""          # 형식이 틀리면 빈 문자열
```

### 4.11 보상 텍스트 `rewards_to_text(rewards)`
```python
if not isinstance(rewards, dict): return "-"
parts = []
for k in ("힘", "민첩", "정신력", "지구력"):
    v = float(rewards.get(k, 0) or 0)
    if v != 0:
        sign = "+" if v > 0 else ""          # 음수는 '-'가 숫자에 붙어 있다
        parts.append(f"{k}{sign}{v:g}")       # 예: "힘+1", "지구력+0.5", "민첩-2"
if "unlock_stat" in rewards and "unlock_to" in rewards:
    parts.append(f"돌파({rewards['unlock_stat']} 상한 {rewards['unlock_to']:g})")   # 예: "돌파(힘 상한 50)"
return " / ".join(parts) if parts else "-"
```
(`:g`는 Python general format이다. 유효숫자 6자리, 끝의 0과 소수점을 뗀다. 예: `50.0→"50"`, `0.5→"0.5"`, `1234567→"1.23457e+06"`)

---

## 5. UI 명세

### 5.1 앱 / 테마
- `theme_style = "Dark"`, `primary_palette = "DeepPurple"`, `accent_palette = "Amber"` (KivyMD Material 팔레트).
- 루트는 `MDBottomNavigation`, 탭 3개 (순서대로):

| name | text | icon (Material Design Icons) |
|---|---|---|
| `status` | `상태창` | `account-circle` |
| `quests` | `퀘스트` | `sword-cross` |
| `logs` | `로그` | `history` |

- 탭을 바꿔도 refresh하지 않는다. 화면 갱신 규칙:
  - 퀘스트 추가/완료 후: QuestsScreen.refresh + `app.refresh_status()` (= StatusScreen.refresh + LogsScreen.refresh)
  - 퀘스트 삭제 후: **QuestsScreen.refresh만** (상태창과 로그는 갱신 안 됨, 원본 버그)
  - 오늘 XP 초기화 후: StatusScreen.refresh만 / 로그 삭제 후: LogsScreen.refresh만
- Snackbar는 `Snackbar(text=...).open()`이고, 완료 요약에만 `duration=3`을 준다.

### 5.2 상태창 (StatusScreen)
레이아웃: 세로 박스 → `MDTopAppBar(title="⚔ LifeRPG", elevation=4)` → `MDScrollView` → 내용 박스(vertical, padding `[16,16,16,80]`dp, spacing 12dp).
refresh 때마다 `_rollover_daily_if_needed()`와 `_recompute_levels()`를 부른 뒤 다시 그린다.

1. **레벨 카드** (MDCard vertical, padding 16, spacing 8, radius 16, elevation 3, 높이 200dp)
   - `f"[b]Main Lv. {main_level}[/b]   |   Physical Lv. {phys_level}"` (markup, H6, 36dp)
   - `f"오늘: {today_date}   |   Today XP: {today_xp}"` (Secondary, Body2, 24dp). `today_date` 기본값은 `today_str()`
   - `f"Physical XP: {xp_in_level} / {xp_next}"` (Secondary, Body2, 20dp)
   - `MDProgressBar(value = min(xp_in / max(xp_next, 1), 1) * 100, max=100)` (12dp)
   - 버튼 행(horizontal, spacing 8, 40dp): `MDFlatButton("오늘 XP 초기화")` · 빈 Widget(spacer) · `MDRaisedButton("🏆 업적")`
2. `"[b]스탯[/b]"` 라벨 (markup, H6, 32dp)
3. **스탯 카드** × 4 (STAT_KEYS 순서; MDCard horizontal, padding `[16,10,16,10]`, radius 12, elevation 1, 높이 60dp)
   - 이름: `f"{icon} {sk}"` (Subtitle1, size_hint_x 0.35)
   - 값: `f"{val:.1f}"` (H6, bold, 0.3, center), 예: `10.0`
   - 등급: `f"[color={GRADE_COLORS_HEX[grade]}][b]{grade}[/b][/color]  (상한 {cap:g})"` (markup, Body2, 0.35, right). grade = `grade_from_cap(cap)`, 색 기본값은 `#808080`
4. `"[b]스킬 트리[/b]"` 라벨 (H6, 32dp)
5. **트리 카드** (physical만; vertical, padding 16, spacing 6, radius 12, elevation 2, 120dp)
   - `f"[b]🏋️ Physical Tree[/b]  Lv. {phys_level}"` (Subtitle1, 28dp)
   - `f"총 XP: {int(xp)}   |   다음 레벨까지: {xp_next - xp_in} XP"` (Secondary, Body2, 22dp)
   - `MDProgressBar`(위와 같은 값, 10dp)

**오늘 XP 초기화 다이얼로그**: title `"오늘 XP 초기화"`, text `"오늘 XP를 0으로 초기화할까요? (되돌리기 어려움)"`, 버튼 `MDFlatButton("취소")`(닫기), `MDRaisedButton("초기화")` → §4.6 처리 → refresh → Snackbar `"오늘 XP가 초기화되었습니다."`

**업적 다이얼로그**: `MDDialog(title="🏆 업적", type="custom")`, 내용은 높이 300dp 스크롤(vertical, padding 8, spacing 4, Body2 markup 라벨), 버튼 `MDFlatButton("닫기")`. ACHIEVEMENT_DEFS 순서로 한 줄씩:
- 해금: `f"{icon} [b]{name}[/b]: {desc}"`
- 잠김: `f"🔒 {name}: ???"`

### 5.3 퀘스트 (QuestsScreen)
레이아웃: 상단 박스(100dp) = `MDTopAppBar(title="📋 퀘스트", elevation=4)` + 가로 스크롤 필터 행(48dp, 칩 간격 8, padding 4) → `MDScrollView` + `MDList` → `FloatLayout`에 `MDFloatingActionButton(icon="plus", pos_hint={"right":0.97,"y":0.02}, md_bg_color=primary_color)` → 추가 다이얼로그.
(코드에 쓰이지 않는 fab_container도 하나 만들지만 화면에 붙이지 않는다.)

**필터 칩**: `All`, `Daily`, `Side`, `Main`, `돌파` (초기값 `All`). 선택된 칩은 `md_bg_color = primary_color`. 누르면 `_current_filter`를 바꾸고 칩을 다시 만든 뒤 refresh.

**refresh** (먼저 `_rollover_daily_if_needed()`):
1. `filtered = [q for q in quests if flt == "All" or q.type == flt]`
2. 정렬 키는 `(q.get("status") != "ACTIVE", int(q.get("id", 0)))` → **ACTIVE가 먼저, 그 안에서 id 오름차순**(오래된 순).
3. `flt in ("All", "Daily")`이면:
   - Daily는 `get_daily_group`으로 묶고, 나머지는 non_daily로 둔다.
   - `DAILY_GROUPS` 순서대로, 퀘스트가 있는 그룹만 헤더 `OneLineListItem(text=f"[b]{label}  ({active_cnt}개)[/b]", _no_ripple_effect=True, bg_color=[0.1,0.5,0.9,0.08])`를 붙인 뒤 해당 퀘스트를 나열. `active_cnt`는 그룹 안 ACTIVE 개수.
   - `non_daily`가 있고 `flt == "All"`이면 헤더 `"[b]── Side / Main / 돌파 ──[/b]"`(bg `[0.9,0.5,0.1,0.08]`)와 그 퀘스트들.
4. 다른 필터(Side/Main/돌파)는 정렬된 목록을 헤더 없이 나열.
5. `filtered`가 비면 `OneLineListItem("퀘스트가 없습니다. + 버튼으로 추가하세요.", _no_ripple_effect=True)`.

**퀘스트 항목** (`TwoLineListItem`, 탭하면 상세 다이얼로그):
- text: `f"{status_icon} {type_badge} {title}"`. status_icon은 DONE이면 `✅`, 아니면 `⬜`
- secondary: `f"XP: {xp}  난이도: {difficulty}  카테고리: {category}{dday_text}"`, `dday_text = f"  {dday}"`(dday가 비면 `""`)
  - 돌파는 `XP: 0  난이도: Normal  카테고리: 돌파`로 보인다.

**퀘스트 추가 다이얼로그**: `MDDialog(title="퀘스트 추가", type="custom", content_cls=AddQuestContent)`, 버튼 `MDFlatButton("취소")`, `MDRaisedButton("추가")`.

AddQuestContent 폼 (위에서 아래로, 기본 상태 = Daily):
| 위젯 | 내용 / 기본값 |
|---|---|
| `title_field` MDTextField | hint `"퀘스트 제목 *"` |
| 종류 행 | `MDRaisedButton("종류: Daily")` → 드롭다운 `Daily/Side/Main/돌파` |
| `xp_field` MDTextField | hint `"XP (숫자)"`, text `"30"` |
| 카테고리/난이도 행 | `MDRaisedButton("카테고리: Gym")` → `Gym/Swim/Mobility/Recovery/Other`; `MDRaisedButton("난이도: Normal")` → `Easy/Normal/Hard` |
| 보상 행 (`reward_row`) | STAT_KEYS마다 MDTextField(hint=스탯명, text `"0"`, size_hint_x 0.25) |
| 돌파 행 (`bt_row`, 처음엔 숨김) | `MDRaisedButton("돌파 스탯: 힘")` → STAT_KEYS 드롭다운; MDTextField hint `"상한값 (예: 50)"`, text `"50"` |
| `deadline_field` | hint `"마감일 YYYY-MM-DD (선택)"` |
| `desc_field` | hint `"설명 (세부 조건/루틴)"`, multiline, 100dp |

드롭다운은 `MDDropdownMenu(caller=button, items=[{"text": t, "viewclass": "OneLineListItem", "on_release": ...}], width_mult=3)`.

종류 변경 `_set_type(t)`: 버튼 텍스트를 `"종류: {t}"`로 바꾼다.
- `t == "돌파"`: 종류 행 바로 아래에 `bt_row`를 넣고, `reward_row`를 빼고, `xp_field.text = "0"`, `xp_field.disabled = True`.
- 그 밖: `bt_row`를 빼고, `reward_row`를 다시 넣는다(종류 행 바로 아래로 위치가 바뀜), `xp_field.disabled = False`. **xp 텍스트는 "0"으로 남는다** → 돌파였다가 돌아오면 XP를 다시 입력해야 검증을 통과한다.

돌파 스탯 선택 `_set_bt_stat(sk)`: 버튼을 `"돌파 스탯: {sk}"`로 바꾸고 상한 필드를 `str(int(float(stat_caps.get(sk, 30))) + 20)`로 채운다. (처음 값 `"50"`은 현재 상한과 상관없는 고정값이다.)

**검증 `validate()`** (첫 오류를 Snackbar로 보여 주고 다이얼로그는 그대로 둔다):
1. `title.strip()`이 비면 → `"퀘스트 제목을 입력해줘"`
2. 돌파:
   - `unlock_to = float(bt_cap_field.text.strip())`, 실패하거나 `<= 0`이면 → `"돌파 상한값을 올바르게 입력해줘"`
   - `unlock_to <= float(stat_caps.get(_unlock_stat, 30))`이면 → `f"{_unlock_stat} 상한값은 현재 상한({cur_cap})보다 높아야 해"` (cur_cap은 float 그대로, 예: `"힘 상한값은 현재 상한(30.0)보다 높아야 해"`)
3. 일반: `int(xp_field.text.strip())`, 실패하거나 `<= 0`이면 → `"XP는 1 이상의 정수로 입력해줘"` (`"30.5"`도 실패)
- 마감일 형식과 보상 필드는 **검증하지 않는다**. 보상 필드에 숫자가 아닌 값이 들어가면 `submit`의 `float()`가 예외를 던진다 (§7).
- 통과하면 `submit()` → 다이얼로그 닫기 → QuestsScreen.refresh → `refresh_status()` → Snackbar `"퀘스트가 추가되었습니다!"`.

**상세 다이얼로그**: `MDDialog(title=f"[{type}] {title}", type="custom", content_cls=QuestDetailContent)`, 버튼 3개:
`MDFlatButton("닫기")`, `MDFlatButton("삭제", theme_text_color="Error")`, `MDRaisedButton("완료 ✓")`. 상태와 상관없이 항상 같은 버튼이 나온다.

QuestDetailContent (vertical, spacing 8, padding 4/8):
- Body2 라벨들:
  - `f"종류: {type}  |  카테고리: {category}"`
  - `f"XP: {xp}  |  난이도: {difficulty}"`
  - `f"상태: {'완료됨 ✅' if DONE else '진행중 ⬜'}"`
  - (deadline이 있으면) `f"마감: {deadline}  {dday}"`
  - `f"보상: {rewards_to_text(rewards)}"`
- desc가 있으면 `"[b]설명[/b]"`(Body1, 28dp)와 desc 본문(Body2).
- type이 `Side`/`Main`이고 `ACTIVE`이면 `f"[b]진행률: {progress}%[/b]"`(Body1, 28dp)와 `MDSlider(min=0, max=100, value=progress, 40dp)`. 라벨은 슬라이더를 따라 바뀌지 않는다.

**완료 `_do_complete(qid, content)`**:
1. Side/Main이고 slider가 있으면 `update_progress(qid, slider.value)`.
2. `complete_quest(qid)`. err면 Snackbar(err) → 상세 닫기 → 끝. (예: `"이미 완료된 퀘스트임"`)
3. 상세 닫기 → QuestsScreen.refresh → `refresh_status()`.
4. 메시지 조각:
   - `leveled_up` → `"🎉 레벨업!"`
   - `stat_gains`가 있으면 → `", ".join(stat_gains)` (예: `"+1 힘, +0.5 지구력"`)
   - breakthrough가 성공이면 `f"💥 돌파 성공! {stat} 상한 {old_cap} → {new_cap}"`, 실패면 `f"돌파 실패 (상한이 이미 {old_cap})"` (float, 예: `30.0`)
   - 조각이 있으면 `Snackbar(text="완료! " + " | ".join(parts), duration=3)`, 없으면 `Snackbar("퀘스트 완료! ✅")`.
5. `new_achievements`마다 0.5초 뒤 `MDDialog(title="🏆 업적 달성!", text=f"{icon} [b]{name}[/b]\n{desc}", buttons=[MDFlatButton("확인")])`.

**삭제**: 상세의 "삭제"를 누르면 상세를 닫고 확인 다이얼로그 `MDDialog(title="퀘스트 삭제", text=f"'{title}' 퀘스트를 삭제할까요?")`, 버튼 `MDFlatButton("취소")`, `MDRaisedButton("삭제")` → `delete_quest` → QuestsScreen.refresh → Snackbar `"퀘스트가 삭제되었습니다."`.

### 5.4 로그 (LogsScreen)
- `MDTopAppBar(title="📜 로그", elevation=4, right_action_items=[["delete-sweep", 로그삭제]])` + `MDScrollView` + `MDList`.
- refresh: `for e in reversed(events[-200:])` → **최근 200개를 최신순**으로 `TwoLineListItem(text=f"{type_icon} {message}", secondary_text=ts)`. 이벤트가 하나도 없으면 `OneLineListItem("로그가 없습니다.")`.
- 로그 삭제 다이얼로그: title `"로그 삭제"`, text `"모든 로그를 삭제할까요? (되돌리기 어려움)"`, `MDFlatButton("취소")`, `MDRaisedButton("삭제")` → `logs_data = {"events": []}`, save_all, refresh, Snackbar `"로그가 삭제되었습니다."`.

### 5.5 Flutter 대응 메모 (참고)
- KivyMD markup `[b]`, `[color=#hex]`는 RichText/TextSpan으로 옮긴다.
- 다크 테마, DeepPurple primary, Amber accent, 등급 색 5종(§3)을 유지한다.

---

## 6. PLAN.md §0과의 차이

| 항목 | PLAN.md §0 | 실제 바이너리 |
|---|---|---|
| 로그 파일명 | `logs.json` | **`log.json`** (`{"events": [...]}`) |
| 스탯 | 7종 (힘·민첩·정신력·지구력·매력·집중·커뮤니케이션) | **4종** `["힘","민첩","정신력","지구력"]`. `_migrate_profile`에 `{"charm","focus","communication"}` 영문 키 감지 로직이 있다 → 7종은 **예전 버전(영문 키)** 스키마이고, 감지하면 4종 기본값(10)으로 **초기화**한다 |
| 스킬 트리 | Physical, Swim, Mobility, Recovery, Study … 여러 개 | **`physical` 하나**. `CATEGORY_TO_TREE`는 Gym/Swim/Mobility/Recovery를 전부 `physical`로 보낸다. `Other`는 트리 XP 없음. Study 트리 없음 |
| 메인 레벨 | 트리별 level 합산 | 식은 합산(`max(1, Σ level)`)이지만 기본 트리가 1개라 Physical 레벨과 같다. 마이그레이션이 옛 트리를 지우지 않으므로 레거시 데이터에 다른 트리가 있으면 그 (갱신 안 되는) 레벨도 더해진다 |
| Daily 그룹 분류 | 제목 키워드 자동 분류 | Day A/B/수영은 **desc 접두어** `"[Day A]"`, `"[Day B]"`, `"[수영 데이]"`, 수영은 category `Swim`도 해당; **category `Gym`이면 "코어"**; 학업/루틴만 **제목** 키워드 (§4.8) |
| 스트릭 | streak_days, last_active_date 운용 | 필드만 있고 **로직 없음** (갱신·표시 안 함) |
| 업적 "랭크 달성" | — | 정식 이름은 `"D랭크 달성"`(id `stat_max_d`). 조건은 아무 스탯이나 `현재값 >= 상한` |
| 업적 퀘스트 수 | 10/50개 완료 | 누적이 아니라 **지금 DONE 상태인 퀘스트 개수** (Daily 리셋·삭제로 줄어든다) |
| 돌파 | 종류 중 하나 | type `"돌파"`, category `"돌파"`, xp 0, difficulty `"Normal"` 고정. XP와 스탯 보상 없이 상한만 바꾼다. 실패해도 DONE이 되고 `first_breakthrough`가 해금된다 |
| 진행률 | 퀘스트 진행률 | Side/Main만. 완료 버튼을 누를 때만 저장. 규칙에 영향 없음 |
| 등급 | 스탯별 등급 | **상한(cap)** 기준 D≤30<C≤50<B≤100<A≤200<S |
| 레거시 이전 방법 | adb run-as로 꺼내 새 앱에서 가져오기 | 원본 앱에는 `user_data_dir/import/`에 4개 파일을 두면 시작할 때 덮어쓰는 기능이 있다 (§1.6). 새 앱의 임포터도 같은 4개 파일을 받으면 된다 |
| 화면/테마 | 상태창/퀘스트/로그, 다크 DeepPurple+Amber | 일치 |
| 난이도 배율 | Easy·Normal·Hard | 0.7 / 1 / 1.5, `int()` 버림, 최소 1 |

---

## 7. 미확인 항목 (추측하지 않음)

1. **Android `user_data_dir` 실제 경로와 패키지명**: APK의 AndroidManifest/버전 정보가 저장소에 없다 (`assets/private/`에는 `main.pyc`, `sitecustomize.pyc`, `NanumGothic.ttf`, `p4a_env_vars.txt`만 있음). Kivy 버전에 따라 `getFilesDir()`(`/data/data/<pkg>/files`)일 수도 있고 외부 저장소일 수도 있다. 데이터는 그 아래 `data/`에 있다. `adb shell run-as <pkg>`로 확인해야 한다.
2. **Kivy/KivyMD 버전**: 바이트코드만으로는 알 수 없다. `Snackbar(text=...)`, `MDTopAppBar`, `MDChip(text=, on_release=)`를 쓰는 것으로 보아 KivyMD 1.x로 보이지만 확정은 아니다. 따라서 Snackbar 기본 표시 시간, MDChip 비선택 색, 위젯 기본 크기 같은 **라이브러리 기본값은 확인하지 못했다**.
3. **옛(7스탯) 스키마의 전체 키 이름**: 마이그레이션 코드에는 `charm`, `focus`, `communication` 세 키만 나온다. 나머지 영문 키 이름, 옛 `trees` 구성, 옛 로그 파일명은 이 바이너리에 없다. 실제 레거시 JSON을 확보해 확인해야 한다.
4. **보상 필드에 숫자가 아닌 값을 넣었을 때**: `validate`가 검사하지 않고 `submit`의 `float()`가 ValueError를 던진다. Kivy 이벤트 콜백에서 처리되지 않은 예외라 앱이 죽을 가능성이 높지만 실제 런타임 동작(크래시 여부)은 확인하지 않았다.
5. **디스크에 있는 데이터의 실제 값 분포**: 예를 들어 사용자가 실제로 desc에 `[Day A]` 접두어를 썼는지, 음수 보상이 있는지, `id`가 문자열로 저장된 적이 있는지 같은 것은 실제 JSON 없이는 알 수 없다. 임포터는 §2의 `.get` 기본값 규칙대로 관대하게 읽는 것을 권장한다.
6. **KV 템플릿(StatCard 등)이 쓰이지 않는 이유**: 바이트코드상 쓰는 곳이 없다는 것까지만 확인했다. 의도는 알 수 없다.
7. **UI 세부 수치**: 일부 dp/size_hint 인자는 키워드 이름 튜플과 값의 대응을 디스어셈블리에서 눈으로 맞춘 것이다 (주요 값은 맞췄지만 픽셀 단위 레이아웃 재현은 보장하지 않는다). 문자열, 규칙, 수치 상수는 전부 확정이다.
