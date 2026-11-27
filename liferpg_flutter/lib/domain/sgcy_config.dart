/// 심기체연 규칙 상수 — 모든 수치는 여기 한 곳에 둔다.
///
/// 근거: `심기체연 인생 게임 규칙서.md`. "아직 정할 것" 기본안은 `docs/PLAN_v2.md` §1.
library;

/// 주요 요소.
class ElementDef {
  const ElementDef(
      this.key, this.label, this.hanja, this.meaning, this.substats);

  final String key;
  final String label;

  /// 한자 (규칙서에 없는 것은 빈 문자열).
  final String hanja;
  final String meaning;

  /// 세부스탯 키 (순서 = 표시 순서).
  final List<String> substats;
}

/// 세부스탯 정의.
class SubStatDef {
  const SubStatDef(this.key, this.label, this.element);
  final String key;
  final String label;
  final String element;
}

/// 퀘스트 종류.
abstract final class QuestKind {
  static const String daily = 'daily';
  static const String weekly = 'weekly';
  static const String special = 'special';
  static const String warning = 'warning';
  static const List<String> all = [warning, special, weekly, daily];
  static const Map<String, String> labels = {
    daily: '일일',
    weekly: '주간',
    special: '특별',
    warning: '경고',
  };
}

/// 경고 퀘스트 심각도.
abstract final class Severity {
  static const String minor = 'minor';
  static const String normal = 'normal';
  static const String severe = 'severe';
  static const List<String> all = [minor, normal, severe];
  static const Map<String, String> labels = {
    minor: '경미',
    normal: '보통',
    severe: '심각',
  };
}

abstract final class SgcyConfig {
  static const List<ElementDef> elements = [
    ElementDef('sim', '심', '心', '마음',
        ['execution', 'patience', 'temperance', 'composure']),
    ElementDef('gi', '기', '氣', '지식·기타', ['knowledge', 'thinking', 'focus']),
    ElementDef('che', '체', '體', '육체', ['strength', 'agility', 'stamina']),
    ElementDef(
        'yeon', '연', '緣', '매력', ['appearance', 'sociability', 'network']),
  ];

  static const List<SubStatDef> substats = [
    SubStatDef('execution', '실행력', 'sim'),
    SubStatDef('patience', '인내', 'sim'),
    SubStatDef('temperance', '절제', 'sim'),
    SubStatDef('composure', '평정심', 'sim'),
    SubStatDef('knowledge', '지식', 'gi'),
    SubStatDef('thinking', '사고력', 'gi'),
    SubStatDef('focus', '집중력', 'gi'),
    SubStatDef('strength', '근력', 'che'),
    SubStatDef('agility', '민첩성', 'che'),
    SubStatDef('stamina', '체력', 'che'),
    SubStatDef('appearance', '외모', 'yeon'),
    SubStatDef('sociability', '친화력', 'yeon'),
    SubStatDef('network', '인맥', 'yeon'),
  ];

  static final Map<String, ElementDef> elementByKey = {
    for (final e in elements) e.key: e,
  };
  static final Map<String, SubStatDef> substatByKey = {
    for (final s in substats) s.key: s,
  };

  /// 한글 라벨 → 키 (가져오기 시 "근력"처럼 한글로 와도 받는다).
  static final Map<String, String> keyByLabel = {
    for (final e in elements) e.label: e.key,
    for (final s in substats) s.label: s.key,
  };

  static const int minLevel = 1;
  static const int maxLevel = 9;

  /// 레벨 이름 (index = level − 1).
  static const List<String> levelNames = [
    '탈위',
    '반위',
    '축위',
    '정위',
    '진위',
    '군위',
    '성위',
    '극위',
    '초월',
  ];
  static const List<String> levelHanja = [
    '脫位',
    '半位',
    '築位',
    '正位',
    '進位',
    '君位',
    '成位',
    '極位',
    '超越',
  ];
  static const List<String> levelDistribution = [
    '하위 10%',
    '상위 90~75%',
    '상위 75~50%',
    '상위 50~35%',
    '상위 35~20%',
    '상위 20~10%',
    '상위 10~4%',
    '상위 4~1%',
    '상위 1% 이하',
  ];

  /// 레벨별 기준 스탯 (index = level − 1). 9레벨은 기본안(10배 규칙 연장).
  static const List<double> baseStats = [
    10,
    20,
    40,
    100,
    1000,
    10000,
    100000,
    1000000,
    10000000,
  ];

  /// 일일 퀘스트 총 보상 = 주요 요소 레벨 기준 스탯 × 5%.
  static const double dailyRewardRate = 0.05;

  /// 주간 = 일일 × 3.
  static const double weeklyMultiplier = 3;

  /// 생성 시 난이도 보정 (`scale`) 허용 범위 — "5% 언저리".
  static const double minScale = 0.6;
  static const double maxScale = 1.4;

  /// 일일 퀘스트 상한: 주요 요소당 하루 2개.
  static const int dailyCapPerElement = 2;

  /// 주간 퀘스트 기본 기한 (생성일 포함 7일).
  static const int weeklyDays = 7;

  /// 승급 직후 스탯 = 새 강등선 × 1.1.
  static const double promotionStatFactor = 1.1;

  /// 승급 후 강등 보호 일수.
  static const int protectionDays = 3;

  /// 1레벨 시작 스탯.
  static const double initialStat = 5;

  /// 자연 감소: 이 일수 동안 퀘스트가 없으면 다음 날부터 감소.
  static const int decayGraceDays = 3;

  /// 하루 감소량 = (자기 레벨) 기준 스탯 × 1%.
  static const double decayRate = 0.01;

  /// 경고 벌칙 배율 (일일 보상 대비).
  static const Map<String, double> severityMultiplier = {
    Severity.minor: 1,
    Severity.normal: 3,
    Severity.severe: 5,
  };

  /// 경고 해제 기본 조건: windowDays 중 requiredDays 체크인.
  static const int warningWindowDays = 5;
  static const int warningRequiredDays = 4;

  /// 습관형 스킬 획득 조건 (특별 퀘스트 체크인 기본값).
  static const int skillWindowDays = 30;
  static const int skillRequiredDays = 24;

  /// 연결 스킬 삭제: 경고 퀘스트 연속 실패 횟수.
  static const int skillDeleteAfterFails = 2;

  /// 상태 파일에 보관하는 관찰 기록 수.
  static const int maxObservations = 120;

  /// 완료·만료된 퀘스트 보관 수 (오래된 것부터 지움).
  static const int maxClosedQuests = 300;

  // ---- 파생 함수 --------------------------------------------------------

  static int clampLevel(int l) =>
      l < minLevel ? minLevel : (l > maxLevel ? maxLevel : l);

  static String levelName(int level) => levelNames[clampLevel(level) - 1];

  static double baseStat(int level) => baseStats[clampLevel(level) - 1];

  /// 강등선 = 바로 아래 레벨의 기준 스탯. 1레벨은 없음(null).
  static double? demotionLine(int level) =>
      level <= minLevel ? null : baseStats[clampLevel(level) - 2];

  /// 일일 보상 총량 (레벨 기준).
  static double dailyReward(int level) => baseStat(level) * dailyRewardRate;
}
