# 통합 업데이트 파일 형식 (`sgcy-update` v1)

대화가 끝나면 Claude가 이 JSON **하나**를 코드블록으로 낸다. 앱 **연동 탭 → ② 붙여넣기 → 적용**.
키는 영문 키와 한글 라벨을 둘 다 받는다 (`"che"` = `"체"`, `"strength"` = `"근력"`).

```json
{
  "format": "sgcy-update",
  "version": 1,
  "date": "2026-11-26",
  "summary": "알람에 바로 일어났고 러닝은 했지만 야식을 먹음",

  "analysis": {
    "심": { "strengths": ["알람에 바로 기상"], "weaknesses": ["23시 이후 야식"], "improvements": ["22시 이후 주방 출입 금지"] },
    "기": { "strengths": [], "weaknesses": ["공부 중 휴대폰 확인 6회"], "improvements": ["뽀모도로 중 폰은 다른 방"] },
    "체": { "strengths": ["러닝 3km"], "weaknesses": [], "improvements": ["상체 운동 추가"] },
    "연": { "strengths": [], "weaknesses": ["발표 때 말 더듬음"], "improvements": ["발표 전 3번 소리 내어 연습"] }
  },

  "quests": [
    { "kind": "daily",   "element": "체", "title": "가슴 운동 + 러닝 3km", "weights": { "근력": 0.7, "체력": 0.3 }, "scale": 1.0 },
    { "kind": "daily",   "element": "기", "title": "뽀모도로 4회 (폰 다른 방)", "weights": { "집중력": 1 } },
    { "kind": "weekly",  "element": "연", "title": "새로운 사람과 대화 3번", "weights": { "친화력": 0.6, "인맥": 0.4 } },
    { "kind": "special", "element": "체", "title": "5km 30분 안에 완주", "promote": "체력", "deadline": "2026-12-20" },
    { "kind": "special", "element": "심", "title": "퀵 슬립 습관 만들기 (23시 전 취침)",
      "grant_skill": { "name": "퀵 슬립", "desc": "23시 전에 잠든다" }, "required_days": 24, "window_days": 30 },
    { "kind": "warning", "element": "심", "title": "야식 끊기", "weights": { "절제": 1 },
      "severity": "normal", "required_days": 4, "window_days": 5 },
    { "kind": "warning", "element": "연", "title": "발표 전 소리 내어 연습", "weights": { "친화력": 1 }, "severity": "minor" }
  ],

  "placements": { "근력": 3 },
  "profile_notes": ["대학생, 아침 7시 기상 목표", "수영·러닝을 좋아함", "발표 불안이 있음"]
}
```

## 필드

| 필드 | 필수 | 설명 |
|---|---|---|
| `format`, `version` | ○ | `"sgcy-update"`, `1` |
| `date` | ○ | 대화한 날 `YYYY-MM-DD` |
| `summary` | | 하루 한두 문장 요약 (상태창에 표시) |
| `analysis` | | 요소별 `strengths`/`weaknesses`/`improvements` (또는 `장점`/`미흡점`/`개선점`). 관찰 기록으로 쌓여 다음 대화에 다시 넘어온다 |
| `quests` | | 아래 표 |
| `placements` | | **초기 판정·보정에만**. 세부스탯 → 레벨(1~9). 그 레벨의 승급 직후 상태(강등선×1.1, 보호 3일)가 된다. 평소 승급은 특별 퀘스트로만 |
| `profile_notes` | | 나에 대한 메모 **전체 목록** (보내면 통째로 교체, 빼면 유지) |

### 퀘스트

| 필드 | 일일 | 주간 | 특별 | 경고 |
|---|---|---|---|---|
| `kind` | `daily` | `weekly` | `special` | `warning` |
| `element` | ○ | ○ | (promote가 있으면 생략 가능) | ○ |
| `title`, `desc` | ○ | ○ | ○ | ○ |
| `weights` | 세부스탯 비율 | 〃 | – | 벌칙을 나눌 비율 |
| `scale` | 난이도 보정 0.6~1.4 (기본 1) | 〃 | – | 〃 |
| `promote` | – | – | 승급할 세부스탯 | – |
| `stat_rewards` | – | – | 세부스탯 → 스탯 (다량 스탯 보상) | – |
| `grant_skill` | – | – | `{name, desc}` | – |
| `severity` | – | – | – | `minor`(1배)/`normal`(3배)/`severe`(5배, 연결 스킬 즉시 삭제) |
| `skill` / `skill_id` | – | – | – | 연결할 스킬 이름 또는 id |
| `required_days`, `window_days` | – | – | 습관형: n일 중 m일 체크인 | 기본 5일 중 4일 |
| `deadline` | (당일 고정) | 기본 7일 | 선택 | 기본 생성일+기간−1 |

**보상 수치는 앱이 계산한다.** 일일 = 주요 요소 레벨(버림)의 기준 스탯 × 5% × scale, 주간 = ×3, 경고 벌칙 = 일일 × 심각도 배율.
그래서 Claude는 "어느 세부스탯에 얼마 비율로"(`weights`)와 "평소보다 쉬운지 어려운지"(`scale`)만 정하면 된다.

## 앱이 거절하는 것 (적용 결과에 "건너뜀"으로 나옴)

- 주요 요소당 하루 일일 퀘스트 2개 초과 (이미 앱에 있는 오늘 일일 퀘스트도 센다)
- 알 수 없는 요소·세부스탯 키, 9레벨에서 승급, 보상이 하나도 없는 특별 퀘스트
