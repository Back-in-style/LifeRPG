# QA_P3 — 통합·마이그레이션 검증 (A6)

> 작성: A6 (QA/통합), 2026-11-25. 기준: PLAN §5 MVP, INTERFACES, GAME_DESIGN, SPEC_v1.
> 결과: `flutter analyze` 0건, `flutter test` **134 통과 / 6 skip** (기존 110 + 신규 24 통과, skip 6개는 아래 버그 재현).
> 제품 코드는 수정하지 않았다. skip을 풀면 실패를 재현할 수 있다.

## 1. 체크리스트

### 1.1 레거시 마이그레이션 E2E — 통과
`test/integration/legacy_migration_e2e_test.dart` (Drift `NativeDatabase.memory()`), 픽스처는 `support.dart`의 `realisticLegacyBundle()`
(Daily 3·Side 2·Main 1·돌파 DONE/ACTIVE, float 스탯, 힘 상한 50.0, base_xp 없는 퀘스트, 문자열 id `"9"`, 유령 트리 `mental`, 로그 361건, 업적 5개).

| 항목 | 결과 |
|---|---|
| 4스탯 값·상한 그대로 (17.35, 50.0 등), 신규 3스탯 10/30 | ✅ |
| physical XP 4680 → 4680 이상, Lv10 → Lv10 이상 / 유령 트리 경고 | ✅ |
| 퀘스트 id·next_id(12) 보존, 새 퀘스트 #12부터 | ✅ |
| base_xp 없는 퀘스트 xp(70 Easy) 복원, `deadline: ""` → null | ✅ |
| 업적 5개 유지(+ 직후 판정분), totalCompletions = 45(로그 기준), 돌파 성공 1 | ✅ |
| 로그 361건 + import 이벤트 보존, 순서 유지, 기본 limit 200 | ✅ |
| rollover → 레거시 ACTIVE 돌파 완료(민첩 30→요청 70→maxStep으로 50) → Daily 완료 → load == commit 상태 | ✅ |
| 스탯·상한·트리 XP·메인 레벨·업적이 줄지 않음, 이벤트 중복 없음 | ✅ |
| DONE 돌파 재완료 → alreadyDone, 같은 날 import 시 todayXp/Daily DONE 유지, 재import 시 완전 대체 | ✅ |
| UI: import된 저장소로 앱 시작 → 돌파 필터 → 입력 없이 완료 → 결과·로그 표시 (`app_legacy_flow_test.dart`) | ✅ |

### 1.2 날짜 경계 — 통과
`test/integration/date_boundary_test.dart`
- 23:59:59 완료 → 00:00:00 rollover: Daily ACTIVE, completedAt null, todayXp/rawToday/countToday 초기화, 스트릭 유지 → 다음 완료 스트릭 2 ✅
- 같은 날 반복 rollover는 무변화(identical) ✅ / completeQuest 내부 rollover로 전날 DONE Daily 완료 가능 ✅
- 하루 건너뛰면 표시 스트릭 0 → 다음 완료 1 ✅ / 10일 공백 후: 초기화 로그 1건, 스탯·트리 그대로 ✅ / 연말·2월 말 경계 ✅
- **재시작 연속성**: 같은 날 1회 완료 → commit → 새 repo 객체로 load → rawToday/countToday 유지 → 2회차 XP가 재시작 없는 경우와 같음(반복 감쇠 0.7) ✅
- 컨트롤러 build()에서 rollover 1회 저장, 포그라운드 복귀(같은 날) 중복 저장 없음, 자정 후 복귀 시 다시 1회 ✅

### 1.3 MVP 기능 (PLAN §5)
| 기능 | 상태 | 비고 |
|---|---|---|
| 상태창 (메인Lv, 오늘 XP, 스트릭, 누적 완료, 스탯 7종·등급·상한, 트리 7종 진행 바, 업적 다이얼로그) | 구현됨 | |
| 퀘스트 (필터 칩, Daily 그룹 헤더·ACTIVE 수, 정렬, D-day, 상세, 진행률, 삭제 확인, 추가 폼 검증 문구) | 구현됨 | 진행률은 드래그 끝에 저장(레거시보다 개선). 삭제 후 상태창 미갱신 원본 버그는 Riverpod로 해소 |
| 로그 (최근 200개 최신순) | 부분 | **로그 삭제 버튼 누락** (SPEC §5.4). `GameRepository`에 삭제 API도 없음 |
| 상태창 "오늘 XP 초기화" | 누락 | SPEC §4.6·§5.2. R2 rawToday와 의미가 겹치므로 의도적 제외라면 GAME_DESIGN에 명시 필요 |
| 측정치 입력 완료 (R1) | 구현됨 | 입력 다이얼로그가 0을 거부(`v <= 0`) → 맨몸 운동 weight_kg 0 입력 불가 (낮음, 메모 N2) |
| 체감 감소 (R2) | 구현됨 | 누적 구간 + 반복 감쇠, 영속·재시작 연속성 확인 |
| 돌파 = PR (R5) | 구현됨 | 신규 돌파 기록값 필수, 레거시 ACTIVE 돌파 예외 + maxStep |
| 레거시 가져오기 UI | 부분 | 설정 → JSON 4종 붙여넣기. 파일 선택·SPEC §1.6 import 폴더 자동 감지 없음. 기존 앱 내부 저장소에서 JSON을 꺼내는 방법 안내 필요 |
| Daily 리마인더 | 부분 | 설정 스위치·시각 선택, zonedSchedule(매일), POST_NOTIFICATIONS·부팅 리시버 등록. 실기기 미검증, DST 지역은 시각이 1시간 밀림(한국은 무관). 예외 시 UI 버그 #4 |

### 1.4 견고성 — `test/integration/robustness_test.dart`
- 빈/공백 제목, 알 수 없는 종류·카테고리·측정치·난이도, 음수 XP, 무한대 보상, 영문 스탯 키, 돌파(상한 이하·기록 키 없음·NaN) → invalidDraft, **state identical·events 빈 리스트** ✅
- 측정치 음수·NaN·무한대·종류 불일치·누락, 돌파 기록값 없음/NaN → invalidMeasurement, 상태 불변 ✅
- 없는 퀘스트·이미 완료 → 에러, 상태 불변 / 진행률 0~100 클램프 ✅
- 마감일 형식 오류: 엔진은 문자열을 그대로 받고 D-day는 `''` (UI는 DatePicker만 허용하므로 실사용 문제 없음) ✅
- 큰 값: flat baseXp 2^53 → raw 200 ✅, 명시 보상 1e9 → 상한에서 정지 ✅, **곱이 Infinity가 되는 측정치 → 예외 (버그 #2)**, **1e16 이상 스탯 import → 값 손상/예외 (버그 #3)**
- Drift commit 원자성: 이벤트 저장 중 예외 → 상태·완료 기록·이벤트 전부 롤백, 이후 정상 commit의 completion id 1 ✅ / 깨진 상태 JSON → initial, 로그 유지 ✅
- 컨트롤러 순차 액션 정상 ✅, **동시 액션은 갱신 유실 (버그 #1)**

## 2. 버그 목록

| # | 심각도 | 소유 | 위치 | 요약 |
|---|---|---|---|---|
| 1 | 높음 | A5 | `lib/app/providers.dart:57-69` (`_run`), `:72-80` (`dailyRollover`) | 컨트롤러 액션 직렬화 없음 → 갱신 유실·이중 완료 |
| 2 | 낮음 | A3 | `lib/domain/rules/xp_formula.dart:45` | 측정치 곱이 Infinity면 `truncate()` 예외 |
| 3 | 낮음 | A3 (호출: A4) | `lib/domain/format.dart:92-98` (`roundTo`), `lib/data/legacy_importer.dart:235` | 큰 값에서 int 포화로 값 손상, Infinity면 예외 |
| 4 | 낮음 | A5 | `lib/features/settings/settings_screen.dart:19-35` | 알림 예약 예외 후 성공 스낵바가 실패 스낵바를 덮음 |

### 버그 #1 (높음, A5) 컨트롤러 동시 액션 갱신 유실
- 재현: `robustness_test.dart` '완료 연타(동시 2회)', '서로 다른 퀘스트 동시 추가' (skip 해제).
- 기대: 같은 퀘스트 동시 완료 2회 → 1회 성공·1회 alreadyDone / 동시 추가 A·B → 둘 다 저장.
- 실제: 두 호출이 같은 `await future` 스냅샷으로 엔진을 돌림 → 완료가 2번 반영(totalCompletions 2, XP·이벤트·completion 중복), 동시 추가는 둘 다 id 1이고 A가 사라짐.
- 실제 앱 경로: Drift commit은 비동기라 그 사이에 시트를 다시 열어 완료, 슬라이더 `onChangeEnd`(updateProgress)와 완료가 겹칠 때, `AppLifecycleListener.onResume` → `dailyRollover()`가 진행 중인 완료와 겹칠 때(완료가 rollover 스냅샷에 덮여 사라질 수 있음).
- 수정 제안: `GameController`에 `Future<void> _queue = Future.value();`를 두고 `_run`·`dailyRollover`·`importLegacy`를 `_queue = _queue.then(...)`로 직렬화하고, 각 작업은 `state.requireValue`(최신)를 읽는다. UI는 보조로 완료 진행 중 버튼을 비활성화한다.

### 버그 #2 (낮음, A3) 측정치 Infinity → 예외
- 재현: `robustness_test.dart` '측정치 1e300' — strength `{sets, reps, weight_kg: 1e300}`.
- 기대: raw = 200(상한). 실제: `UnsupportedError: Infinity or NaN toInt`가 컨트롤러 밖으로 던져짐 (UI 피드백 없음). 입력 필터가 숫자·점만 허용하므로 아주 긴 숫자를 입력해야 생긴다.
- 수정 제안: `rawXp`에서 `final b = measureBaseXp(kind, m); if (!b.isFinite) return maxRawXpPerCompletion;`(NaN은 1), 또는 `_validateInput`에서 `measureBaseXp`가 유한한지 검사.

### 버그 #3 (낮음, A3/A4) `roundTo` 큰 값
- 재현: `robustness_test.dart` '레거시 import: 스탯 1e306…', '스탯 1e20은 값이 보존된다'.
- 기대: 값 보존·예외 없음 (LegacyImporter는 예외를 던지지 않는다고 명시). 실제: 1e20 → 9.22e15로 깎임, 1e306 → `(v*1000)`=Infinity → `round()` 예외.
- 수정 제안: `roundTo`에서 `if (!v.isFinite || v.abs() >= 1e15) return v;`. 임포터는 비정상적으로 큰 값(예: > 1e6)을 경고 후 클램프하는 것도 고려.

### 버그 #4 (낮음, A5) 리마인더 예외 처리
- 재현: `reminder_error_test.dart` (skip: true). `ReminderService.apply`가 예외를 던지면.
- 기대: '알림 설정 실패' 스낵바만. 실제: catch 뒤 `granted`가 true라 '매일 21:00에 알려 드릴게요.'가 바로 뒤에 떠서 실패를 덮는다.
- 수정 제안: catch 블록에서 `granted = false` 대신 별도 플래그로 return하거나, 성공 스낵바를 try 안으로 옮긴다.

### 메모 (버그는 아니고 개선 권장)
- N1 (A5) `completion_flow.dart:33`, `add_quest_screen.dart:157`: `repo.commit` 예외를 잡지 않음 → 완료는 피드백 없이 실패, 추가 화면은 `_saving`이 true로 남아 '추가' 버튼이 영구 비활성. try/finally와 오류 스낵바 권장.
- N2 (A5) `completion_flow.dart:85`: 측정치 0 거부. 엔진은 0 허용. 근력 weight_kg 0(맨몸) 등을 위해 `< 0`만 거부하고 전체가 0일 때만 경고 권장.
- N3 (A3) `streak.dart` `markActive`: 시계가 거꾸로 가서 lastActiveDate가 미래면 gap < 0 → 스트릭 1로 리셋. 레거시처럼 날짜가 다르면 리셋하는 동작이라 허용 범위지만 `gap < 0`은 유지가 더 안전.
- N4 (A5) `completion_flow.dart:24-33`: 입력 다이얼로그 `await` 뒤 `context.mounted` 확인 없이 `ref.read` (모달이라 실제로 문제될 가능성은 낮음).
- N5 (A3) 엔진 `addQuest`는 deadline 형식을 검증하지 않음 (UI가 DatePicker라 실사용 영향 없음). 필요하면 `tryParseDateKey`로 검증.

## 3. 추가 테스트 (A6 소유)

| 파일 | 내용 | 개수 |
|---|---|---|
| `test/integration/support.dart` | sqlite 감지, TestClock, Drift memory repo, 현실적 레거시 번들 생성기 | – |
| `test/integration/legacy_migration_e2e_test.dart` | import→load 보존, rollover→레거시 돌파·Daily 완료→재load, DONE 돌파, 같은 날 import, 재import 대체, export | 6 |
| `test/integration/date_boundary_test.dart` | 자정 넘김, 내부 rollover, 스트릭 끊김, 10일 공백, 월·연 경계, 재시작 연속성(Drift), 컨트롤러 시작/복귀 rollover | 7 |
| `test/integration/robustness_test.dart` | 잘못된 draft/측정치, 상태 불변, 클램프, 큰 값, commit 원자성, 깨진 JSON, 동시/순차 액션 | 10 + skip 5 |
| `test/integration/app_legacy_flow_test.dart` | UI: 레거시 데이터 시작 → 돌파 완료 → 상태창·로그 | 1 |
| `test/integration/reminder_error_test.dart` | 리마인더 예약 예외 UI | skip 1 |
