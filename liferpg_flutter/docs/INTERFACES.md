# INTERFACES — 도메인 모델 · 엔진 · Repository 계약

> P2 병렬 구현(A3 domain · A4 data · A5 UI)의 공용 계약. **메인 세션 소유.**
> 시그니처 변경이 필요하면 직접 바꾸지 말고 메인 세션에 요청한다.
> 공식·수치는 `docs/GAME_DESIGN.md`, 상수는 `lib/domain/game_config.dart`(A2), 레거시 스키마는 `docs/SPEC_v1.md`.

## 0. 공통 규칙

- `lib/domain/`은 순수 Dart. `package:flutter`, drift, riverpod 등 외부 패키지 import 금지 (`dart:core`/`dart:math`/`dart:collection`만).
- 도메인 모델은 **손으로 쓴 불변 클래스** (freezed 미사용 → domain은 코드 생성 없이 컴파일). 각 모델은 `const` 생성자, `copyWith`, `==`/`hashCode`, `toJson()`/`fromJson()`을 가진다. JSON 키는 snake_case.
- 스탯·트리·카테고리·측정치·퀘스트 종류·난이도는 **문자열 키** (`GameConfig`의 값과 동일). 도메인에는 상태(`QuestStatus`)처럼 닫힌 집합만 enum으로 둔다.
- 엔진은 **부수효과 없음**: `(GameState, 입력, DateTime now) → 결과` 형태. 현재 시각은 항상 인자로 받는다 (`DateTime.now()` 호출 금지 — 테스트 가능성).
- 날짜 문자열은 `YYYY-MM-DD`(로컬), 시각은 `DateTime`(로컬). JSON 직렬화 시 시각은 `YYYY-MM-DD HH:MM:SS`(레거시와 동일 형식).
- 숫자: 스탯 값/상한은 `double`, XP는 `int`.

## 1. 도메인 모델 (`lib/domain/models/`, A3)

```dart
// stat.dart
class StatState {
  final String key;          // GameConfig.statKeys
  final double value;        // 현재 값 (소수 3자리 반올림 저장)
  final double cap;          // 상한. 돌파로만 상승 (R5)
  final double peak;         // 역대 최고값 (R3 디트레이닝 바닥 계산용)
  final String? lastGainDate; // 마지막 상승 날짜 (R3)
}

// skill_tree.dart
class TreeState {
  final String key;          // GameConfig.treeKeys
  final int totalXp;         // 누적 효과 XP. 레벨은 저장하지 않고 rules/leveling으로 계산
}

class LevelInfo { final int level; final int xpInLevel; final int xpForNext; double get progress; }

// quest.dart
enum QuestStatus { active, done }   // JSON: "ACTIVE" / "DONE" (레거시 문자열)

class Quest {
  final int id;
  final String title;
  final String desc;
  final String type;          // 'Daily'|'Side'|'Main'|'돌파'
  final String category;      // GameConfig.categoryKeys, 돌파는 '돌파'
  final String difficulty;    // 'Easy'|'Normal'|'Hard'
  final String measureKind;   // GameConfig.measureKinds. 레거시 퀘스트는 'flat'
  final int baseXp;           // flat 퀘스트 입력 XP (배율 전)
  final Map<String, double> rewards; // 명시 스탯 보상 (레거시). 비면 categoryStatWeights 자동 분배
  final String? unlockStat;   // 돌파 전용
  final double? unlockTo;     // 돌파 전용: 목표 상한
  final String? deadline;     // 'YYYY-MM-DD'
  final String? recordKey;    // 연결된 개인기록 키 (돌파 필수·신규, 일반 퀘스트 선택) — GAME_DESIGN §7
  final String? recordDirection; // 'higher'|'lower'
  final double? target;       // 돌파 선택: 첫 기록일 때 이 값 달성 시 PR
  final int progress;         // 0~100
  final QuestStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  bool get isBreakthrough => type == GameConfig.breakthroughType;
}

/// 퀘스트 추가 폼 입력 (id·시각·상태는 엔진이 채움)
class QuestDraft {
  final String title, desc, type, category, difficulty, measureKind;
  final int baseXp;
  final Map<String, double> rewards;
  final String? unlockStat; final double? unlockTo; final String? deadline;
  final String? recordKey; final String? recordDirection; final double? target;
}

// measurement.dart
/// 완료 시 사용자가 입력한 실측치 (R1). fields는 GameConfig.measureFields[kind]의 키.
class Measurement {
  final String kind;
  final Map<String, double> values;   // 예: {'sets':5,'reps':5,'weight_kg':60}
}

/// 완료 입력: 측정치 + (기록 연결 퀘스트면) 기록값.
class CompletionInput {
  final Measurement? measurement;  // null이면 flat (baseXp)
  final double? recordValue;       // quest.recordKey가 있으면 입력. 돌파(신규)는 필수
}

// completion.dart
/// 완료 1회 기록 — 로그·통계·되돌리기 근거 (GAME_DESIGN §12 Completion).
class Completion {
  final int? id;              // 저장 후 부여 (data 계층)
  final int questId;
  final String questTitle;
  final String category;
  final String? tree;         // 매핑 없으면 null ('Other'·돌파)
  final String measureKind;
  final Map<String, double> values;
  final int rawXp;            // §3.4 1~2단계 (난이도·상한·PR 보너스 포함, 감쇠 전)
  final int xp;               // §3.4 7단계 실제 지급
  final Map<String, double> statGains;
  final String? recordKey;
  final double? recordValue;
  final bool isPr;
  final DateTime at;
}

// personal_record.dart
/// 개인기록 (GAME_DESIGN §7.1). key는 사용자 정의 문자열.
class PersonalRecord {
  final String key;
  final String direction;     // 'higher'|'lower'
  final String? stat;         // 연결 스탯 (돌파 대상)
  final double? best;
  final List<RecordEntry> history;
}
class RecordEntry { final double value; final DateTime at; final int? completionId; final bool isPr; }

// log_event.dart
class LogEvent {
  final DateTime ts;
  final String type;          // 'system'|'xp'|'quest'|'breakthrough'|'stat'|'achievement'|'pr'|'import'
  final String message;       // 레거시 메시지 형식 유지 (SPEC_v1 §2.4)
  final Map<String, Object?> meta;
}

// profile.dart
class Profile {
  final Map<String, StatState> stats;  // 7종 모두 존재
  final Map<String, TreeState> trees;  // 7종 모두 존재
  final String todayDate;              // 일일 리셋 기준
  final Map<String, int> rawToday;     // R2 트리별 오늘 누적 원시 XP (영속, 날짜 바뀌면 0)
  final Map<String, int> countToday;   // R2 트리별 오늘 완료 횟수 (반복 감쇠)
  final int todayXp;                   // 오늘 지급된 XP 합
  final int streakDays;
  final String? lastActiveDate;
  final int totalCompletions;          // 누적 완료 수 (업적: 레거시와 달리 누적 기준)
  final int breakthroughSuccesses;
  final int prCount;
  final double fatigue;                // R4 (MVP에선 0 고정, 필드만)
  final bool graceWeekUsed;            // R6 (MVP에선 미사용, 필드만)
  int get mainLevel;                   // 1 + Σ(트리Lv − 1) (GAME_DESIGN §5.2)
}

// game_state.dart
/// 앱 전체 상태 스냅샷. 엔진 입력/출력 단위.
class GameState {
  final Profile profile;
  final List<Quest> quests;
  final int nextQuestId;
  final Set<String> unlockedAchievements;
  final Map<String, PersonalRecord> records; // key = recordKey
  static GameState initial(DateTime now);
}
```

## 2. 규칙 함수 (`lib/domain/rules/`, A3) — 전부 top-level 순수 함수

**이름·결과는 `tool/sim/sim_engine.dart`와 일치시킨다** (시뮬을 회귀 테스트 기준으로 사용). 공식은 GAME_DESIGN 절 번호 참조.

| 파일 | 시그니처 | 근거 |
|---|---|---|
| `xp_formula.dart` | `double measureBaseXp(String kind, Map<String,double> m, {int flatXp})`, `int rawXp(String kind, Map<String,double> m, String difficulty, {int flatXp})` | §3, R1 |
| `diminishing.dart` | `double diminish(String tree, int rawToday, int raw)`, `double repeatMultiplier(int n)` | §4, R2 |
| `leveling.dart` | `int xpToNext(int level)`, `int cumulativeXpForLevel(int level)`, `LevelInfo levelFromXp(int totalXp)`, `int mainLevel(Iterable<int> treeLevels)`, `String gradeFromCap(double cap)` | §5, R7 |
| `legacy_convert.dart` | `int convertLegacyTreeXp(int legacyXp)` (+ 레거시 레벨 공식 `200+(L−1)·80`) | §5.3 |
| `stats.dart` | `double statSoftFactor(double cur)`, `({double value, double applied}) clampToCap(double cur, double delta, double cap)`, `Map<String,double> statGainsFor({required Quest quest, required int xp, required Map<String,StatState> stats})` | §6 |
| `records.dart` | `bool isPr(double value, double? best, String direction, {double? target})` | §7.2 |
| `breakthrough.dart` | `double breakthroughNewCap(double cap, double requestedCap)`, `BreakthroughResult resolveBreakthrough(...)` | §7.3, R5 |
| `streak.dart` | `({int streakDays, String lastActiveDate}) markActive(...)`, `int streakOnRollover(...)`, `double streakBonus(int streak)` | §8 |
| `achievements.dart` | `List<String> newlyUnlocked(GameState state)` | §9 |
| `daily_group.dart` | `String dailyGroupOf(Quest q)` → `GameConfig.dailyGroups` 키 | §2.3, SPEC_v1 §4.8 |
| `dday.dart` | `String ddayLabel(String? deadline, String today)` | SPEC_v1 §4.10 |
| (후속) `detraining.dart`, `fatigue.dart` | `fatigueMultiplier(double f)` 등 | §10 |

## 3. 엔진 (`lib/domain/game_engine.dart`, A3)

```dart
class GameEngine {
  const GameEngine();

  /// 날짜가 바뀌었으면 Daily 퀘스트 ACTIVE 복귀, todayXp/rawToday/countToday 초기화.
  /// 같은 날이면 state 그대로, events 빈 리스트.
  EngineResult dailyRollover(GameState state, DateTime now);

  EngineResult addQuest(GameState state, QuestDraft draft, DateTime now);   // result.quest = 생성된 퀘스트
  EngineResult deleteQuest(GameState state, int questId, DateTime now);
  EngineResult updateProgress(GameState state, int questId, int progress, DateTime now);

  /// 완료 (GAME_DESIGN §3.4 순서). 내부에서 dailyRollover를 먼저 적용한다.
  /// 이미 DONE이면 GameError.alreadyDone. 신규 돌파에 recordValue 없으면 invalidMeasurement.
  CompletionResult completeQuest(GameState state, int questId, CompletionInput input, DateTime now);
}

class EngineResult {
  final GameState state;
  final List<LogEvent> events;     // data 계층이 append 저장
  final Quest? quest;
  final GameError? error;          // 실패 시 state는 입력 그대로
}

enum GameError { questNotFound, alreadyDone, invalidMeasurement, invalidDraft }

class CompletionResult extends EngineResult {
  final Completion? completion;    // data 계층이 저장
  final int xp;
  final String? tree;
  final bool leveledUp;            // 트리 레벨업 여부
  final int? newTreeLevel;
  final Map<String, double> statGains;  // 실제 적용분 (applied > 0)
  final BreakthroughResult? breakthrough;
  final bool isPr;
  final List<String> newAchievements;   // 업적 id
}

class BreakthroughResult { final String stat; final double oldCap; final double newCap; final bool success; }
```

## 4. 데이터 계층 (`lib/data/`, A4)

```dart
/// 저장소 계약. 구현: DriftGameRepository(앱), InMemoryGameRepository(테스트·UI 개발용).
abstract interface class GameRepository {
  Future<GameState> load();                       // 없으면 GameState.initial(now)
  /// 엔진 결과 1건을 원자적으로 저장 (트랜잭션): 상태 스냅샷 + 새 이벤트 + (있으면) 기록.
  /// (records는 GameState 안에 있으므로 state와 함께 저장)
  Future<void> commit(GameState state, {List<LogEvent> events = const [], Completion? completion});
  Future<List<LogEvent>> recentEvents({int limit = 200});   // 최신순
  Future<List<Completion>> completions({String? category, String? recordKey, int? limit}); // 최신순
  Future<ImportReport> importLegacy(LegacyBundle bundle, DateTime now); // 기존 데이터 대체
  Future<String> exportJson();                    // 전체 백업 (MVP 이후 UI)
  Future<void> close();
}

/// 레거시 JSON 4종 원문 (SPEC_v1 §2). 없는 파일은 null.
class LegacyBundle { final String? profileJson, questsJson, logJson, achievementsJson; }

class ImportReport { final int quests; final int events; final int achievements; final List<String> warnings; }

/// 순수 변환기 (Flutter 의존 없음, test/data에서 단위 테스트).
class LegacyImporter {
  ({GameState state, List<LogEvent> events, ImportReport report}) convert(LegacyBundle b, DateTime now);
}

Future<GameRepository> openGameRepository();   // 앱 문서 디렉터리의 liferpg.sqlite
```

- 레거시 변환 규칙: GAME_DESIGN §5.3·§9·§13을 따른다 (4스탯 값·상한 유지, 신규 3스탯 기본값, physical XP는 `convertLegacyTreeXp`, 퀘스트 measureKind='flat', 업적 id 유지, `totalCompletions` = max(DONE 수, 로그의 완료 이벤트 수)). 변환 수식은 domain의 `legacy_convert.dart`를 호출한다.
- Drift 테이블은 A4 재량. 단 `GameState`는 정규화해도 되고 profile을 JSON 컬럼으로 둬도 된다 — 외부에는 위 계약만 노출.

## 5. UI 연결 (`lib/app/providers.dart`, A5)

```dart
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final gameEngineProvider = Provider((_) => const GameEngine());
final gameRepositoryProvider = FutureProvider<GameRepository>((ref) => openGameRepository()); // 테스트에서 override
/// 상태 + 액션. 각 액션: engine 호출 → repository.commit → state 갱신 → 결과 반환(스낵바/다이얼로그용).
final gameControllerProvider = AsyncNotifierProvider<GameController, GameState>(GameController.new);
final recentEventsProvider = FutureProvider<List<LogEvent>>(...);
final completionsProvider = FutureProvider.family<List<Completion>, String?>(...);
```

- 앱 시작·포그라운드 복귀 시 `dailyRollover` 호출.
- 위젯 테스트는 `gameRepositoryProvider`를 `InMemoryGameRepository`로, `clockProvider`를 고정 시각으로 override.

## 6. 병렬 구현 순서 의존

- A3는 §1~3을 먼저 모델부터 커밋 → A4·A5가 import. A4·A5는 그 전까지 위 시그니처대로 stub에 의존해도 된다.
- A4는 `InMemoryGameRepository`를 가장 먼저 제공 (A5 개발용).
- 모든 에이전트: `flutter analyze` 무경고, 자기 테스트 통과.

## 7. 변경 이력 (메인 승인)

- 2026-11-25 (A3 구현 반영)
  - `statGainsFor(..., {double rewardRatio = 1.0})` 선택 인자 추가 (명시 보상의 R2 비율, GAME_DESIGN §6.2).
  - `resolveBreakthrough({stat, cap, requestedCap, prAchieved})`, `markActive({streakDays, lastActiveDate, today})`, `streakOnRollover({streakDays, lastActiveDate, today})` named 인자로 확정.
  - `BreakthroughResult`는 `rules/breakthrough.dart` 정의, 엔진에서 re-export. 실패 시 `newCap == oldCap`.
  - 추가 API: `Quest.xp`(flat 난이도 적용 XP, 레거시 `xp` 키 저장), `GameState.questById`, `EngineResult.ok`, `lib/domain/format.dart`(dateKey·formatTimestamp 등).
  - import 경로: `package:liferpg/domain/domain.dart` 하나. 엔진은 `Completion.id`·`RecordEntry.completionId`를 null로 두며 data 계층이 부여.
  - PR 판정: best가 null이면 PR 아님(기준 등록). `≥ best×1.01`이면 PR (80→80.8은 PR).
- 2026-11-25 (P3 QA 반영, 레거시 기능 동등성)
  - `GameEngine.resetTodayXp(GameState state, DateTime now) → EngineResult`: `todayXp = 0`만 초기화(rawToday/countToday는 유지 — 체감 감소 우회 방지), 이벤트 `system` "오늘 XP 초기화" (SPEC_v1 §2.4).
  - `GameRepository.clearEvents() → Future<void>`: 로그 전체 삭제 (레거시 로그 화면 '삭제').
