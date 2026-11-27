# 입력 형식 — 브리핑 + 상태 파일 (`sgcy-state` v2)

대화를 시작할 때 사용자가 앱 **연동 탭 → ① 브리핑+상태 복사**로 붙여 넣는 내용이다. 한 덩어리 안에 두 부분이 있다.

```
# 심기체연 브리핑 — 2026-11-26        ← ① 브리핑 (Markdown, 사람이 읽기 좋은 요약)
...
## 상태 파일

```json                                ← ② 상태 파일 (JSON, 게임 상태 전체)
{ "format": "sgcy-state", "version": 2, ... }
```
```

- **브리핑**: 먼저 훑어볼 것. 레벨·강등 위험·진행 중 퀘스트·최근 관찰이 정리되어 있다.
- **상태 파일**: 판단의 근거. 브리핑과 다르면 **상태 파일이 맞다**.
- 이 파일은 **읽기 전용**이다. Claude는 상태 파일을 고쳐서 돌려주지 않는다. 바꾸고 싶은 것은 전부 업데이트 파일(`UPDATE_FORMAT.md`)로 낸다.

---

## ① 브리핑 (Markdown)

순서대로 이런 절이 나온다. 해당 내용이 없으면 절이 빠지기도 한다.

| 절 | 내용 | 볼 것 |
|---|---|---|
| 제목 | `# 심기체연 브리핑 — 오늘 날짜` | 오늘 날짜 |
| (첫 줄) | 마지막 Claude 업데이트 날짜와 요약 | 어제 무슨 얘기를 했는지 |
| `## 주요 요소` | 심·기·체·연 레벨(소수), 보상 기준 레벨(버림), 일일 보상 | **퀘스트 난이도 기준 = 보상 기준 레벨** |
| `## 세부스탯` | 13개: 레벨·스탯·강등선·기준·비고 | 비고의 **강등 위험 / 자연 감소 중 / 보호** |
| `## 스킬` | 보유 스킬, 경고 연속 실패 수 | 지켰는지 대화에서 확인 |
| `## 진행 중인 퀘스트` | 경고 → 특별 → 주간 → 일일 | 경고 체크인 현황, 기한 임박 |
| `## 최근 7일 종료된 퀘스트` | 완료·해제·실패·만료 | 반복 실패 패턴 |
| `## 최근 관찰 기록` | 최근 20개 `[요소·장점/미흡점/개선점]` | 1주 2회 이상 반복 → 경고 발동 근거 |
| `## 나에 대해` | `profile_notes` | 대화 톤·질문 소재 |

---

## ② 상태 파일 (JSON)

### 최상위

| 필드 | 타입 | 설명 |
|---|---|---|
| `format` | `"sgcy-state"` | 고정 |
| `version` | `2` | 고정 |
| `today` | `YYYY-MM-DD` | 앱 기준 오늘 |
| `last_update_date` | 날짜 \| 없음 | 마지막으로 Claude 업데이트를 적용한 날 |
| `last_summary` | 문자열 | 그때의 요약 |
| `next_id` | 정수 | 앱 내부용 (무시) |
| `substats` | 객체 | 세부스탯 13개, 키는 아래 표의 영문 키 |
| `skills` | 목록 | 보유 스킬 |
| `quests` | 목록 | 진행 중 + 종료된 퀘스트 (최근 300개) |
| `observations` | 목록 | 관찰 기록 (최근 120개, 오래된 것부터) |
| `profile_notes` | 문자열 목록 | 나에 대한 메모 |

### 키 대응표

JSON 안에서는 **영문 키**를 쓴다. 업데이트 파일에는 영문 키와 한글 라벨 중 아무거나 써도 된다.

| 요소 키 | 요소 | 세부스탯 키 → 라벨 |
|---|---|---|
| `sim` | 심 心 (마음) | `execution` 실행력 · `patience` 인내 · `temperance` 절제 · `composure` 평정심 |
| `gi` | 기 氣 (지식·기타) | `knowledge` 지식 · `thinking` 사고력 · `focus` 집중력 |
| `che` | 체 體 (육체) | `strength` 근력 · `agility` 민첩성 · `stamina` 체력 |
| `yeon` | 연 緣 (매력) | `appearance` 외모 · `sociability` 친화력 · `network` 인맥 |

| 레벨 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| 이름 | 탈위 | 반위 | 축위 | 정위 | 진위 | 군위 | 성위 | 극위 | 초월 |
| 기준 스탯 | 10 | 20 | 40 | 100 | 1,000 | 1만 | 10만 | 100만 | 1000만 |

### `substats.<키>`

| 필드 | 설명 |
|---|---|
| `level` | 1~9 |
| `stat` | 현재 스탯. **강등선(= 한 단계 아래 레벨의 기준 스탯) 이하로 떨어지면 강등** |
| `last_active_date` | 마지막으로 이 세부스탯이 오른 날. 3일 넘게 비면 4일째부터 하루 1%씩 자연 감소 |
| `protected_until` | 이 날까지 강등·감소 없음 (승급·배치 직후 3일) |

주요 요소 레벨은 파일에 없다. 직접 계산한다: **Σ(세부 레벨²) / Σ(세부 레벨)**, 퀘스트 난이도는 그 값을 **버림**한 레벨에 맞춘다.

### `quests[]`

| 필드 | 설명 |
|---|---|
| `id` | 정수. 경고 퀘스트를 스킬에 연결하거나 언급할 때 쓴다 |
| `kind` | `daily` 일일 / `weekly` 주간 / `special` 특별 / `warning` 경고 |
| `title`, `desc` | 제목, 설명(없을 수 있음) |
| `element` | 요소 키 |
| `level` | 만들 때의 보상 기준 레벨 |
| `rewards` | 세부스탯 → 스탯. 경고는 **실패 시 깎이는 양** |
| `promote` | 특별: 완료 시 승급할 세부스탯 |
| `grant_skill` | 특별: 완료 시 얻을 스킬 `{name, desc}` |
| `skill_id` | 경고: 연결된 스킬 id |
| `severity` | 경고: `minor` / `normal` / `severe` |
| `required_days`, `window_days` | 체크인형: `window_days`일 중 `required_days`일 |
| `checkins` | 체크인한 날짜 목록 |
| `created_date`, `deadline` | 만든 날, 기한 |
| `status` | `active` 진행 중 / `done` 완료 / `cleared` 경고 해제 / `failed` 실패 / `expired` 만료 |
| `closed_date` | 종료된 날 |
| `source` | `claude` (업데이트로 생김) / `manual` (사용자가 앱에서 직접) |

### `skills[]`

| 필드 | 설명 |
|---|---|
| `id`, `name`, `desc` | |
| `element` | 관련 요소 키 (없을 수 있음) |
| `acquired_date` | 얻은 날 |
| `fail_streak` | 연결된 경고 퀘스트 연속 실패 수. **2가 되면 스킬 삭제** |

### `observations[]`

| 필드 | 설명 |
|---|---|
| `date` | 관찰한 날 |
| `element` | 요소 키 |
| `kind` | `strength` 장점 / `weakness` 미흡점 / `improvement` 개선점 |
| `text` | 내용 |

---

## 예시

```json
{
  "format": "sgcy-state",
  "version": 2,
  "today": "2026-11-26",
  "last_update_date": "2026-11-25",
  "last_summary": "알람에 바로 일어났고 러닝 3km. 밤에 야식.",
  "next_id": 6,
  "substats": {
    "temperance": { "level": 2, "stat": 11.0, "last_active_date": "2026-11-20" },
    "strength": { "level": 3, "stat": 22.0, "last_active_date": "2026-11-25", "protected_until": "2026-11-27" },
    "stamina": { "level": 4, "stat": 44.0, "last_active_date": "2026-11-25" }
  },
  "skills": [
    { "id": 1, "name": "퀵 슬립", "desc": "23시 전에 잠든다", "element": "sim", "acquired_date": "2026-11-01", "fail_streak": 1 }
  ],
  "quests": [
    { "id": 3, "kind": "daily", "title": "가슴 운동 + 러닝 3km", "element": "che", "level": 3,
      "rewards": { "strength": 1.4, "stamina": 0.6 },
      "created_date": "2026-11-26", "deadline": "2026-11-26", "status": "active", "source": "claude" },
    { "id": 4, "kind": "warning", "title": "야식 끊기", "element": "sim", "level": 1,
      "rewards": { "temperance": 1.5 }, "skill_id": 1, "severity": "normal",
      "required_days": 4, "window_days": 5, "checkins": ["2026-11-25"],
      "created_date": "2026-11-24", "deadline": "2026-11-28", "status": "active", "source": "claude" },
    { "id": 5, "kind": "special", "title": "5km 30분 안에 완주", "element": "che", "level": 4,
      "rewards": {}, "promote": "stamina",
      "created_date": "2026-11-20", "deadline": "2026-12-20", "status": "active", "source": "claude" },
    { "id": 2, "kind": "daily", "title": "뽀모도로 4회", "element": "gi", "level": 1,
      "rewards": { "focus": 0.5 },
      "created_date": "2026-11-24", "deadline": "2026-11-24", "status": "expired", "closed_date": "2026-11-25", "source": "claude" }
  ],
  "observations": [
    { "date": "2026-11-24", "element": "sim", "kind": "weakness", "text": "23시 이후 야식" },
    { "date": "2026-11-25", "element": "sim", "kind": "weakness", "text": "23시 이후 야식" },
    { "date": "2026-11-25", "element": "che", "kind": "strength", "text": "러닝 3km" }
  ],
  "profile_notes": ["대학생, 아침 7시 기상 목표", "러닝을 좋아함"]
}
```

이 예시에서 읽어 낼 것:
- 파일에 없는 세부스탯(실행력 등)은 **1레벨·스탯 5**로 본다.
- 체 레벨 = (3² + 4² + 1²) / (3 + 4 + 1) = 3.25 → 일일 퀘스트 난이도는 **3레벨(축위)**.
- 근력은 11/27까지 보호 중이다. 절제는 11/20 이후 오르지 않아 자연 감소 중이고, 강등선(10)에 가깝다.
- 야식 미흡점이 1주에 2번 나왔고 경고 퀘스트 #4가 이미 진행 중이다(체크인 1/4). 연결된 스킬 「퀵 슬립」은 한 번 더 실패하면 삭제된다. → 대화에서 **오늘 야식을 참았는지 꼭 확인**한다.
- 어제 뽀모도로 퀘스트가 만료됐다. → 이유를 묻고 난이도를 조정한다.
