/// LifeRPG 밸런스 상수 (A2 소유).
///
/// 모든 계수·상한·감쇠율은 이 파일 한 곳에만 둔다. 공식의 정의와 예시 계산은
/// `docs/GAME_DESIGN.md`에 있고, 값은 `dart run tool/sim/main.dart`
/// 90일 시뮬레이션으로 검증했다.
///
/// 규칙:
/// - 순수 Dart. `package:flutter`나 외부 패키지를 import하지 않는다.
/// - 스탯·트리·카테고리·측정치 종류는 enum이 아니라 **문자열 키**로 둔다.
///   모델 enum은 도메인(A3)이 만들고, 키 문자열은 여기 값과 일치해야 한다.
/// - 레거시(SPEC_v1)와 같은 이름·값을 쓰는 키는 저장 데이터 호환 때문에 바꾸지 않는다.
library;

/// 체감 감소 구간 하나. 오늘 해당 트리에 쌓인 원시 XP가 [upTo] 미만인 부분에
/// [rate] 배율을 적용한다. 마지막 구간을 넘는 원시 XP는 0배(일일 상한)다.
typedef DiminishingBand = ({double upTo, double rate});

/// 등급 구간 하나. 상한(cap)이 [maxCap] 이하이면 [grade]. 어느 구간에도
/// 속하지 않으면 [GameConfig.topGrade].
typedef GradeBand = ({String grade, double maxCap});

/// 업적 정의. [kind]는 판정 종류 키, [threshold]는 그 기준값.
typedef AchievementDef = ({
  String id,
  String name,
  String desc,
  String icon,
  String kind,
  double threshold,
  bool legacy,
});

/// 모든 밸런스 상수. 인스턴스를 만들지 않는다.
final class GameConfig {
  GameConfig._();

  // ---------------------------------------------------------------------------
  // 스탯
  // ---------------------------------------------------------------------------

  /// 스탯 키 7종 (표시 순서). 레거시 4종이 앞에 오고 신규 3종이 뒤에 온다.
  static const List<String> statKeys = [
    '힘',
    '민첩',
    '정신력',
    '지구력',
    '매력',
    '집중',
    '커뮤니케이션',
  ];

  /// 레거시 앱(SPEC_v1 §3)의 스탯 키 4종. 임포트 시 값·상한을 그대로 가져온다.
  static const List<String> legacyStatKeys = ['힘', '민첩', '정신력', '지구력'];

  /// **미사용 (참고용).** 레거시보다 더 옛 스키마의 영문 스탯 키 → 새 키.
  /// 사용자 결정(2026-11-25): 옛 영문 스탯 값은 버리고 신규 3스탯은 기본값 10으로
  /// 시작한다. 임포터는 이 맵으로 값을 살리지 않는다 (키 감지·로그 용도로만 쓸 수 있음).
  static const Map<String, String> legacyEnglishStatAliases = {
    'charm': '매력',
    'focus': '집중',
    'communication': '커뮤니케이션',
  };

  /// 스탯 표시 아이콘. 레거시 4종은 SPEC_v1 §3 그대로.
  static const Map<String, String> statIcons = {
    '힘': '💪',
    '민첩': '⚡',
    '정신력': '🧠',
    '지구력': '❤️',
    '매력': '✨',
    '집중': '🎯',
    '커뮤니케이션': '💬',
  };

  /// 신규 스탯 기본값 (레거시와 같다).
  static const double defaultStatValue = 10;

  /// 신규 스탯 기본 상한 (레거시와 같다, 등급 D).
  static const double defaultStatCap = 30;

  /// 스탯 값 저장 소수 자릿수 (레거시 `round(v, 3)`).
  static const int statDecimals = 3;

  /// 효과 XP 1당 스탯 상승량 (가중치 1.0 기준). 100 XP → +1.0.
  static const double statGainPerXp = 0.01;

  /// 스탯 성장 완화 상수 K. 성장 배율 = K / (K + max(0, 현재값 − 기본값)).
  /// 값 10에서 1.0, 30에서 0.67, 50에서 0.5.
  static const double statSoftK = 40;

  // ---------------------------------------------------------------------------
  // 등급 (상한 기준, SPEC_v1 §3.2)
  // ---------------------------------------------------------------------------

  /// 등급 구간. cap ≤ 30 → D, ≤ 50 → C, ≤ 100 → B, ≤ 200 → A, 그 위는 S.
  static const List<GradeBand> gradeBands = [
    (grade: 'D', maxCap: 30),
    (grade: 'C', maxCap: 50),
    (grade: 'B', maxCap: 100),
    (grade: 'A', maxCap: 200),
  ];

  /// 모든 구간을 넘었을 때 등급.
  static const String topGrade = 'S';

  /// 등급 색 (레거시 GRADE_COLORS_HEX).
  static const Map<String, String> gradeColorsHex = {
    'S': '#FFD700',
    'A': '#8A2BE2',
    'B': '#1E90FF',
    'C': '#32CD32',
    'D': '#808080',
  };

  /// 등급 순서 (낮음 → 높음). 업적 판정에 쓴다.
  static const List<String> gradeOrder = ['D', 'C', 'B', 'A', 'S'];

  // ---------------------------------------------------------------------------
  // 스킬 트리 / 카테고리
  // ---------------------------------------------------------------------------

  /// 스킬 트리 키 7종 (표시 순서). `physical`은 레거시 트리 키와 같다.
  static const List<String> treeKeys = [
    'physical',
    'swim',
    'mobility',
    'recovery',
    'study',
    'social',
    'routine',
  ];

  /// 트리 표시 이름.
  static const Map<String, String> treeLabels = {
    'physical': 'Physical',
    'swim': 'Swim',
    'mobility': 'Mobility',
    'recovery': 'Recovery',
    'study': 'Study',
    'social': 'Social',
    'routine': 'Routine',
  };

  /// 트리 아이콘.
  static const Map<String, String> treeIcons = {
    'physical': '🏋️',
    'swim': '🌊',
    'mobility': '🤸',
    'recovery': '🛌',
    'study': '📚',
    'social': '🤝',
    'routine': '🌙',
  };

  /// 퀘스트 카테고리 키 (UI 선택 순서). 앞 4개 + `Other`는 레거시와 같다.
  static const List<String> categoryKeys = [
    'Gym',
    'Swim',
    'Mobility',
    'Recovery',
    'Study',
    'Social',
    'Routine',
    'Other',
  ];

  /// 레거시 카테고리 키 (SPEC_v1 §3).
  static const List<String> legacyCategoryKeys = [
    'Gym',
    'Swim',
    'Mobility',
    'Recovery',
    'Other',
  ];

  /// 카테고리 → 트리. 여기 없는 카테고리(`Other`)는 트리 XP가 없다(레거시 동일).
  /// 레거시는 Swim/Mobility/Recovery도 physical로 보냈지만 새 앱은 각자 트리로 보낸다.
  static const Map<String, String> categoryToTree = {
    'Gym': 'physical',
    'Swim': 'swim',
    'Mobility': 'mobility',
    'Recovery': 'recovery',
    'Study': 'study',
    'Social': 'social',
    'Routine': 'routine',
  };

  /// 카테고리 → 스탯 가중치 (합 1.0). 명시 보상(rewards)이 없는 퀘스트의 자동 스탯
  /// 상승에 쓴다. 스탯 상승 = 효과XP × [statGainPerXp] × 가중치 × 성장 배율.
  static const Map<String, Map<String, double>> categoryStatWeights = {
    'Gym': {'힘': 0.6, '지구력': 0.3, '정신력': 0.1},
    'Swim': {'지구력': 0.6, '민첩': 0.2, '정신력': 0.2},
    'Mobility': {'민첩': 0.7, '지구력': 0.1, '정신력': 0.2},
    'Recovery': {'정신력': 0.5, '지구력': 0.3, '집중': 0.2},
    'Study': {'집중': 0.7, '정신력': 0.3},
    'Social': {'커뮤니케이션': 0.6, '매력': 0.4},
    'Routine': {'정신력': 0.4, '집중': 0.3, '매력': 0.3},
    'Other': {},
  };

  /// 고강도 카테고리 (R4 피로도 부하, 휴식일 판정에 쓴다).
  static const List<String> highIntensityCategories = ['Gym', 'Swim'];

  // ---------------------------------------------------------------------------
  // 퀘스트 종류 / 난이도
  // ---------------------------------------------------------------------------

  /// 퀘스트 종류 키 (레거시 문자열 그대로).
  static const List<String> questTypes = ['Daily', 'Side', 'Main', '돌파'];

  /// 돌파 퀘스트의 type/category 문자열 (레거시).
  static const String breakthroughType = '돌파';

  /// 난이도 배율 (레거시 0.7 / 1 / 1.5). **flat 퀘스트에만** 적용한다: 퀘스트를 추가할 때
  /// `xp = max(1, trunc(base_xp × 배율))`로 저장한다 (레거시 동일). 측정형 퀘스트
  /// (measure_kind != 'flat')는 난이도와 무관하게 배율 1.0이다 (2026-11-25 사용자 결정).
  static const Map<String, double> difficultyMultiplier = {
    'Easy': 0.7,
    'Normal': 1.0,
    'Hard': 1.5,
  };

  /// 알 수 없는 난이도의 배율 (레거시 `.get(difficulty, 1)`).
  static const double defaultDifficultyMultiplier = 1.0;

  /// flat 퀘스트의 기본 XP 입력값 (레거시 폼 기본값 "30").
  static const int defaultFlatXp = 30;

  // ---------------------------------------------------------------------------
  // 측정치 (R1)
  // ---------------------------------------------------------------------------

  /// 측정치 종류 키.
  /// - `flat`: 측정치 없음. 퀘스트에 저장된 xp를 그대로 쓴다 (레거시 퀘스트 전부).
  /// - `duration_min`: 분.
  /// - `distance_km`: 달리기·걷기·자전거 거리(km).
  /// - `swim_m`: 수영 거리(m).
  /// - `strength`: 세트 × 횟수 × 무게(kg) = 볼륨.
  /// - `reps`: 맨몸 운동 세트 × 횟수.
  /// - `pomodoro`: 뽀모도로(25분) 개수.
  /// - `sleep_h`: 수면 시간.
  /// - `steps`: 걸음 수.
  /// - `count`: 횟수형 (연락한 사람 수, 발표 횟수 등).
  static const List<String> measureKinds = [
    'flat',
    'duration_min',
    'distance_km',
    'swim_m',
    'strength',
    'reps',
    'pomodoro',
    'sleep_h',
    'steps',
    'count',
  ];

  /// 측정치 종류별 입력 필드 키 (입력 UI와 Record 저장 키).
  static const Map<String, List<String>> measureFields = {
    'flat': [],
    'duration_min': ['minutes'],
    'distance_km': ['km'],
    'swim_m': ['meters'],
    'strength': ['sets', 'reps', 'weight_kg'],
    'reps': ['sets', 'reps'],
    'pomodoro': ['count'],
    'sleep_h': ['hours'],
    'steps': ['steps'],
    'count': ['count'],
  };

  /// 측정치 단위량당 원시 XP.
  /// duration_min 1/분, distance_km 10/km, swim_m 0.04/m (1000m=40),
  /// strength 0.015/kg볼륨 (5×5×60=1500 → 22.5), reps 0.3/회, pomodoro 12/개,
  /// steps 0.003/걸음 (10000=30), count 10/회. sleep_h는 [sleepXp*] 상수로 따로 계산.
  static const Map<String, double> measureXpPerUnit = {
    'duration_min': 1.0,
    'distance_km': 10.0,
    'swim_m': 0.04,
    'strength': 0.015,
    'reps': 0.3,
    'pomodoro': 12.0,
    'steps': 0.003,
    'count': 10.0,
  };

  /// 수면: 목표 구간 하한(시간). 이 이상이면 만점.
  static const double sleepTargetMinH = 7;

  /// 수면: 목표 구간 상한(시간). 이 초과분은 감점.
  static const double sleepTargetMaxH = 9;

  /// 수면: 목표 구간 안에서 받는 원시 XP.
  static const double sleepXpFull = 40;

  /// 수면: 상한 초과 1시간당 감점 XP.
  static const double sleepOverPenaltyPerH = 10;

  /// 수면: 하루 인정 최대 시간 (입력 오류 방지).
  static const double sleepMaxH = 14;

  /// 카테고리별 기본 측정치 종류 (퀘스트 추가 폼의 기본 선택).
  static const Map<String, String> categoryDefaultMeasure = {
    'Gym': 'strength',
    'Swim': 'swim_m',
    'Mobility': 'duration_min',
    'Recovery': 'sleep_h',
    'Study': 'pomodoro',
    'Social': 'count',
    'Routine': 'flat',
    'Other': 'flat',
  };

  /// 완료 1회의 원시 XP 상한 (난이도 배율 적용 후). 입력 실수·과장 방지.
  static const int maxRawXpPerCompletion = 200;

  // ---------------------------------------------------------------------------
  // 체감 감소 / 일일 상한 (R2)
  // ---------------------------------------------------------------------------

  /// 기본 체감 감소 구간. 오늘 트리 누적 원시 XP 0~80은 1.0배, 80~200은 0.25배,
  /// 200 이상은 0배. → 트리별 하루 효과 XP 최대 80 + 120×0.25 = 110.
  static const List<DiminishingBand> defaultDiminishingBands = [
    (upTo: 80, rate: 1.0),
    (upTo: 200, rate: 0.25),
  ];

  /// 같은 날 같은 트리 n번째 완료의 반복 감쇠 배율 = max(floor, decay^(n−1)).
  /// 첫 완료 1.0, 두 번째 0.7, 세 번째 0.49, 네 번째부터 0.4.
  static const double repeatDecay = 0.7;

  /// 반복 감쇠 배율의 하한.
  static const double repeatDecayFloor = 0.4;

  /// 트리별 체감 감소 구간 재정의. 없으면 [defaultDiminishingBands].
  /// recovery·routine은 수면·체크만으로 쌓이지 않게 낮다 (최대 60 + 40×0.5 = 80).
  /// physical은 근력 1세션(≈100)이 온전히 들어가도록 넓다 (최대 100 + 100×0.25 = 125).
  static const Map<String, List<DiminishingBand>> treeDiminishingBands = {
    'physical': [
      (upTo: 100, rate: 1.0),
      (upTo: 200, rate: 0.25),
    ],
    'recovery': [
      (upTo: 60, rate: 1.0),
      (upTo: 100, rate: 0.5),
    ],
    'routine': [
      (upTo: 60, rate: 1.0),
      (upTo: 100, rate: 0.5),
    ],
  };

  // ---------------------------------------------------------------------------
  // 레벨 (R7)
  // ---------------------------------------------------------------------------

  /// 트리 Lv1 → Lv2에 필요한 XP.
  static const double treeLevelBaseXp = 200;

  /// 트리 레벨당 필요 XP 증가율. need(L) = round(base × growth^(L−1)).
  /// 누적 XP가 지수로 늘어 레벨은 XP의 로그에 비례한다.
  static const double treeLevelGrowth = 1.15;

  /// 트리 레벨 상한 (표시·계산 보호용, 사실상 도달 불가).
  static const int treeLevelMax = 99;

  // ---------------------------------------------------------------------------
  // 돌파 = PR (R5)
  // ---------------------------------------------------------------------------

  /// PR로 인정하는 최소 개선 비율 (이전 최고 대비). 0.01 = 1%.
  static const double prMinImprovementRatio = 0.01;

  /// 돌파 1회로 올릴 수 있는 상한 증가 최대치 = max([breakthroughMinStep], cap × 이 값).
  static const double breakthroughMaxStepRatio = 0.5;

  /// 돌파 1회 상한 증가 최대치의 하한. 레거시 폼 기본값(cap + 20)과 같다.
  static const double breakthroughMinStep = 20;

  /// 일반 퀘스트에서 PR을 세웠을 때 받는 보너스 원시 XP (체감 감소 적용).
  static const int prBonusXp = 20;

  // ---------------------------------------------------------------------------
  // 스트릭 (MVP: 단순 스트릭)
  // ---------------------------------------------------------------------------

  /// 스트릭 1일당 XP 보너스 비율.
  static const double streakBonusPerDay = 0.01;

  /// 스트릭 XP 보너스 최대 비율 (10일 이상이면 +10%).
  static const double streakBonusMax = 0.10;

  // ---------------------------------------------------------------------------
  // Daily 그룹 (레거시 분류 + 신규 카테고리)
  // ---------------------------------------------------------------------------

  /// Daily 그룹 (키, 표시 이름). 레거시 DAILY_GROUPS와 같다.
  static const List<(String, String)> dailyGroups = [
    ('grp_dayA', '🅰️ Day A — 등·하체·삼두'),
    ('grp_dayB', '🅱️ Day B — 가슴·어깨·이두'),
    ('grp_core', '🔄 코어'),
    ('grp_swim', '🌊 수영 데이'),
    ('grp_study', '📚 학업'),
    ('grp_routine', '🌙 루틴'),
    ('grp_social', '🤝 소셜'),
    ('grp_etc', '📦 기타 Daily'),
  ];

  /// 학업 그룹 제목 키워드 (레거시).
  static const List<String> studyKeywords = ['강의', '복습', '과제', '집중', '공부'];

  /// 루틴 그룹 제목 키워드 (레거시).
  static const List<String> routineKeywords = ['기상', '취침', '식단'];

  // ---------------------------------------------------------------------------
  // 업적
  // ---------------------------------------------------------------------------

  /// 업적 판정 종류 키:
  /// `completions`(누적 완료 수), `main_level`, `breakthrough_success`(돌파 성공 수),
  /// `stat_at_cap`(스탯 하나가 상한 도달), `grade`(threshold = gradeOrder 인덱스, 스탯
  /// 하나라도 그 등급 이상), `streak`(현재 스트릭), `tree_level`(트리 하나의 레벨),
  /// `all_trees_level`(모든 트리가 그 레벨 이상), `pr_count`(누적 PR 수).
  static const List<String> achievementKinds = [
    'completions',
    'main_level',
    'breakthrough_success',
    'stat_at_cap',
    'grade',
    'streak',
    'tree_level',
    'all_trees_level',
    'pr_count',
  ];

  /// 업적 정의 (표시 순서). `legacy: true`는 레거시 8종 (id 유지).
  static const List<AchievementDef> achievements = [
    (
      id: 'first_quest',
      name: '첫 발걸음',
      desc: '첫 번째 퀘스트를 완료했다!',
      icon: '🏁',
      kind: 'completions',
      threshold: 1,
      legacy: true
    ),
    (
      id: 'first_levelup',
      name: '각성',
      desc: '첫 레벨업을 달성했다!',
      icon: '⚡',
      kind: 'main_level',
      threshold: 2,
      legacy: true
    ),
    (
      id: 'quest_10',
      name: '모험가',
      desc: '퀘스트를 10개 완료했다!',
      icon: '⚔',
      kind: 'completions',
      threshold: 10,
      legacy: true
    ),
    (
      id: 'quest_50',
      name: '영웅',
      desc: '퀘스트를 50개 완료했다!',
      icon: '🛡',
      kind: 'completions',
      threshold: 50,
      legacy: true
    ),
    (
      id: 'first_breakthrough',
      name: '한계 돌파',
      desc: '첫 돌파에 성공했다!',
      icon: '💥',
      kind: 'breakthrough_success',
      threshold: 1,
      legacy: true
    ),
    (
      id: 'stat_max_d',
      name: '한계 도달',
      desc: '스탯 하나가 상한에 도달했다!',
      icon: '📊',
      kind: 'stat_at_cap',
      threshold: 1,
      legacy: true
    ),
    (
      id: 'level_5',
      name: '숙련자',
      desc: '메인 레벨 5를 달성했다!',
      icon: '🌟',
      kind: 'main_level',
      threshold: 5,
      legacy: true
    ),
    (
      id: 'level_10',
      name: '전문가',
      desc: '메인 레벨 10을 달성했다!',
      icon: '✨',
      kind: 'main_level',
      threshold: 10,
      legacy: true
    ),
    (
      id: 'quest_100',
      name: '베테랑',
      desc: '퀘스트를 100번 완료했다!',
      icon: '🎖',
      kind: 'completions',
      threshold: 100,
      legacy: false
    ),
    (
      id: 'quest_500',
      name: '전설',
      desc: '퀘스트를 500번 완료했다!',
      icon: '👑',
      kind: 'completions',
      threshold: 500,
      legacy: false
    ),
    (
      id: 'level_25',
      name: '달인',
      desc: '메인 레벨 25를 달성했다!',
      icon: '💫',
      kind: 'main_level',
      threshold: 25,
      legacy: false
    ),
    (
      id: 'level_50',
      name: '그랜드마스터',
      desc: '메인 레벨 50을 달성했다!',
      icon: '🌠',
      kind: 'main_level',
      threshold: 50,
      legacy: false
    ),
    (
      id: 'rank_c',
      name: 'C랭크 달성',
      desc: '스탯 하나의 등급이 C가 되었다!',
      icon: '🟢',
      kind: 'grade',
      threshold: 1,
      legacy: false
    ),
    (
      id: 'rank_b',
      name: 'B랭크 달성',
      desc: '스탯 하나의 등급이 B가 되었다!',
      icon: '🔵',
      kind: 'grade',
      threshold: 2,
      legacy: false
    ),
    (
      id: 'rank_a',
      name: 'A랭크 달성',
      desc: '스탯 하나의 등급이 A가 되었다!',
      icon: '🟣',
      kind: 'grade',
      threshold: 3,
      legacy: false
    ),
    (
      id: 'rank_s',
      name: 'S랭크 달성',
      desc: '스탯 하나의 등급이 S가 되었다!',
      icon: '🟡',
      kind: 'grade',
      threshold: 4,
      legacy: false
    ),
    (
      id: 'breakthrough_5',
      name: '벽 깨기',
      desc: '돌파에 5번 성공했다!',
      icon: '🧱',
      kind: 'breakthrough_success',
      threshold: 5,
      legacy: false
    ),
    (
      id: 'streak_7',
      name: '일주일 연속',
      desc: '7일 연속으로 활동했다!',
      icon: '🔥',
      kind: 'streak',
      threshold: 7,
      legacy: false
    ),
    (
      id: 'streak_30',
      name: '한 달 연속',
      desc: '30일 연속으로 활동했다!',
      icon: '☄️',
      kind: 'streak',
      threshold: 30,
      legacy: false
    ),
    (
      id: 'streak_100',
      name: '백일',
      desc: '100일 연속으로 활동했다!',
      icon: '💯',
      kind: 'streak',
      threshold: 100,
      legacy: false
    ),
    (
      id: 'tree_10',
      name: '한 우물',
      desc: '스킬 트리 하나가 Lv.10이 되었다!',
      icon: '🌳',
      kind: 'tree_level',
      threshold: 10,
      legacy: false
    ),
    (
      id: 'all_rounder',
      name: '만능',
      desc: '모든 스킬 트리가 Lv.5 이상이 되었다!',
      icon: '🧭',
      kind: 'all_trees_level',
      threshold: 5,
      legacy: false
    ),
    (
      id: 'pr_1',
      name: '신기록',
      desc: '첫 개인기록(PR)을 세웠다!',
      icon: '📈',
      kind: 'pr_count',
      threshold: 1,
      legacy: false
    ),
    (
      id: 'pr_20',
      name: '기록 사냥꾼',
      desc: '개인기록을 20번 갱신했다!',
      icon: '🏅',
      kind: 'pr_count',
      threshold: 20,
      legacy: false
    ),
  ];

  // ---------------------------------------------------------------------------
  // MVP 이후: R3 디트레이닝 (초안)
  // ---------------------------------------------------------------------------

  /// 스탯이 이 일수 동안 오르지 않으면 디트레이닝이 시작된다.
  static const int detrainGraceDays = 7;

  /// 유예 이후 하루 감소율: 현재값 −= rate × (현재값 − 바닥).
  static const double detrainDailyRate = 0.02;

  /// 디트레이닝 바닥 = max(기본값, 역대 최고값 × 이 비율).
  static const double detrainFloorRatio = 0.85;

  // ---------------------------------------------------------------------------
  // MVP 이후: R4 피로도 / 회복 (초안)
  // ---------------------------------------------------------------------------

  /// 피로도 최대치.
  static const double fatigueMax = 100;

  /// 하루가 지날 때 피로도에 곱하는 값 (자연 회복).
  static const double fatigueDailyRetain = 0.6;

  /// 트리별 효과 XP 1당 피로도 증가량.
  static const Map<String, double> fatigueLoadPerXp = {
    'physical': 0.25,
    'swim': 0.2,
    'mobility': 0.02,
  };

  /// 목표 수면(7~9h) 기록 시 피로도 감소량.
  static const double fatigueSleepRelief = 15;

  /// recovery 트리 효과 XP 1당 피로도 감소량 (수면 외 회복 활동).
  static const double fatigueRecoveryReliefPerXp = 0.3;

  /// 이 피로도부터 XP 효율이 떨어진다.
  static const double fatigueThreshold = 40;

  /// 피로도 최대일 때 XP 효율 감소폭. 배율 = 1 − 이 값 × (F−임계)/(최대−임계).
  static const double fatigueMaxPenalty = 0.4;

  /// 고강도 활동이 없는 날(휴식일) recovery·mobility XP 배율.
  static const double restDayRecoveryBonus = 1.2;

  // ---------------------------------------------------------------------------
  // MVP 이후: R6 관대한 스트릭 (초안)
  // ---------------------------------------------------------------------------

  /// 주(월~일)마다 자동으로 쓰이는 유예일 수.
  static const int streakGraceDaysPerWeek = 1;

  /// 유예 없이 끊겼을 때 남기는 스트릭 비율 (내림).
  static const double streakBreakRetainRatio = 0.5;
}
