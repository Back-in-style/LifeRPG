import '../format.dart';
import '../game_config.dart';
import '../rules/xp_formula.dart';
import 'json_helpers.dart';

/// 퀘스트 상태. JSON은 레거시 문자열 `"ACTIVE"` / `"DONE"`.
enum QuestStatus {
  active('ACTIVE'),
  done('DONE');

  const QuestStatus(this.json);

  /// 저장 문자열.
  final String json;

  /// 모르는 값은 레거시 기본값 `ACTIVE`.
  static QuestStatus fromJson(Object? v) =>
      v == 'DONE' ? QuestStatus.done : QuestStatus.active;
}

/// 퀘스트 (SPEC_v1 §2.3 + GAME_DESIGN §3·§7 신규 필드).
class Quest {
  const Quest({
    required this.id,
    required this.title,
    this.desc = '',
    required this.type,
    this.category = 'Other',
    this.difficulty = 'Normal',
    this.measureKind = 'flat',
    this.baseXp = 0,
    this.rewards = const {},
    this.unlockStat,
    this.unlockTo,
    this.deadline,
    this.recordKey,
    this.recordDirection,
    this.target,
    this.progress = 0,
    this.status = QuestStatus.active,
    required this.createdAt,
    this.completedAt,
  });

  final int id;
  final String title;
  final String desc;

  /// `'Daily'|'Side'|'Main'|'돌파'`.
  final String type;

  /// `GameConfig.categoryKeys`, 돌파는 `'돌파'`.
  final String category;

  /// `'Easy'|'Normal'|'Hard'`.
  final String difficulty;

  /// `GameConfig.measureKinds`. 레거시 퀘스트는 `'flat'`.
  final String measureKind;

  /// flat 퀘스트 입력 XP (난이도 배율 전, 레거시 `base_xp`).
  final int baseXp;

  /// 명시 스탯 보상 (레거시). 비면 `categoryStatWeights` 자동 분배.
  final Map<String, double> rewards;

  /// 돌파 전용: 대상 스탯.
  final String? unlockStat;

  /// 돌파 전용: 요청 상한.
  final double? unlockTo;

  /// `YYYY-MM-DD`.
  final String? deadline;

  /// 연결된 개인기록 키 (돌파 신규는 필수, 일반 퀘스트는 선택).
  final String? recordKey;

  /// `'higher'|'lower'`.
  final String? recordDirection;

  /// 돌파 선택: 첫 기록일 때 이 값을 달성하면 PR.
  final double? target;

  /// 0~100.
  final int progress;
  final QuestStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isBreakthrough => type == GameConfig.breakthroughType;

  bool get isDone => status == QuestStatus.done;

  bool get isFlat => measureKind == 'flat';

  /// 레거시에서 가져온 돌파 퀘스트 (기록 연결 없음) — 레거시 규칙으로 완료 (§7.3).
  bool get isLegacyBreakthrough => isBreakthrough && recordKey == null;

  /// flat 퀘스트가 완료 시 받는 원시 XP (난이도 배율 적용, 레거시 `xp` 필드).
  /// 돌파·측정형은 0.
  int get xp =>
      (isBreakthrough || !isFlat) ? 0 : adjustedFlatXp(baseXp, difficulty);

  Quest copyWith({
    int? id,
    String? title,
    String? desc,
    String? type,
    String? category,
    String? difficulty,
    String? measureKind,
    int? baseXp,
    Map<String, double>? rewards,
    Object? unlockStat = unset,
    Object? unlockTo = unset,
    Object? deadline = unset,
    Object? recordKey = unset,
    Object? recordDirection = unset,
    Object? target = unset,
    int? progress,
    QuestStatus? status,
    DateTime? createdAt,
    Object? completedAt = unset,
  }) =>
      Quest(
        id: id ?? this.id,
        title: title ?? this.title,
        desc: desc ?? this.desc,
        type: type ?? this.type,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        measureKind: measureKind ?? this.measureKind,
        baseXp: baseXp ?? this.baseXp,
        rewards: rewards ?? this.rewards,
        unlockStat: identical(unlockStat, unset)
            ? this.unlockStat
            : unlockStat as String?,
        unlockTo: identical(unlockTo, unset)
            ? this.unlockTo
            : (unlockTo as num?)?.toDouble(),
        deadline:
            identical(deadline, unset) ? this.deadline : deadline as String?,
        recordKey:
            identical(recordKey, unset) ? this.recordKey : recordKey as String?,
        recordDirection: identical(recordDirection, unset)
            ? this.recordDirection
            : recordDirection as String?,
        target: identical(target, unset)
            ? this.target
            : (target as num?)?.toDouble(),
        progress: progress ?? this.progress,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        completedAt: identical(completedAt, unset)
            ? this.completedAt
            : completedAt as DateTime?,
      );

  /// 레거시 키 이름을 그대로 쓴다. `xp`는 파생값(읽을 때 무시)이지만 레거시 호환을 위해 쓴다.
  Map<String, Object?> toJson() => {
        'id': id,
        'category': category,
        'type': type,
        'title': title,
        'xp': xp,
        'rewards': rewards,
        'difficulty': difficulty,
        'deadline': deadline,
        'progress': progress,
        'status': status.json,
        'created_at': formatTimestamp(createdAt),
        'completed_at': tsOrNull(completedAt),
        'desc': desc,
        'base_xp': baseXp,
        'measure_kind': measureKind,
        'unlock_stat': unlockStat,
        'unlock_to': unlockTo,
        'record_key': recordKey,
        'record_direction': recordDirection,
        'target': target,
      };

  /// 레거시 quests.json 항목도 읽는다 (없는 키는 레거시 `.get` 기본값).
  /// `base_xp`가 없으면 `xp`를 대신 쓴다. 돌파의 `rewards`(unlock_stat/unlock_to)는
  /// 스탯 키가 아니므로 버린다.
  factory Quest.fromJson(Map<String, Object?> json) {
    final rewardsRaw = jMap(json['rewards']);
    return Quest(
      id: jInt(json['id']),
      title: jString(json['title']),
      desc: jString(json['desc']),
      type: jString(json['type']),
      category: jString(json['category'], 'Other'),
      difficulty: jString(json['difficulty'], 'Normal'),
      measureKind: jStringOrNull(json['measure_kind']) ?? 'flat',
      baseXp: jInt(json['base_xp'] ?? json['xp']),
      rewards: jDoubleMap(rewardsRaw, keys: GameConfig.statKeys),
      unlockStat:
          jStringOrNull(json['unlock_stat'] ?? rewardsRaw['unlock_stat']),
      unlockTo: jDoubleOrNull(json['unlock_to'] ?? rewardsRaw['unlock_to']),
      deadline: jStringOrNull(jStringOrNull(json['deadline'])?.trim()),
      recordKey: jStringOrNull(json['record_key']),
      recordDirection: jStringOrNull(json['record_direction']),
      target: jDoubleOrNull(json['target']),
      progress: jInt(json['progress']).clamp(0, 100).toInt(),
      status: QuestStatus.fromJson(json['status']),
      createdAt: jTime(json['created_at'], epoch),
      completedAt: jTimeOrNull(json['completed_at']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Quest &&
      other.id == id &&
      other.title == title &&
      other.desc == desc &&
      other.type == type &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.measureKind == measureKind &&
      other.baseXp == baseXp &&
      deepEquals(other.rewards, rewards) &&
      other.unlockStat == unlockStat &&
      other.unlockTo == unlockTo &&
      other.deadline == deadline &&
      other.recordKey == recordKey &&
      other.recordDirection == recordDirection &&
      other.target == target &&
      other.progress == progress &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        desc,
        type,
        category,
        difficulty,
        measureKind,
        baseXp,
        deepHash(rewards),
        unlockStat,
        unlockTo,
        deadline,
        recordKey,
        recordDirection,
        target,
        progress,
        status,
        createdAt,
        completedAt,
      ]);

  @override
  String toString() => 'Quest(#$id [$type] $title ${status.json})';
}

/// 퀘스트 추가 폼 입력. id·시각·상태는 엔진이 채운다.
class QuestDraft {
  const QuestDraft({
    required this.title,
    this.desc = '',
    required this.type,
    this.category = 'Other',
    this.difficulty = 'Normal',
    this.measureKind = 'flat',
    this.baseXp = GameConfig.defaultFlatXp,
    this.rewards = const {},
    this.unlockStat,
    this.unlockTo,
    this.deadline,
    this.recordKey,
    this.recordDirection,
    this.target,
  });

  final String title, desc, type, category, difficulty, measureKind;
  final int baseXp;
  final Map<String, double> rewards;
  final String? unlockStat;
  final double? unlockTo;
  final String? deadline;
  final String? recordKey;
  final String? recordDirection;
  final double? target;

  bool get isBreakthrough => type == GameConfig.breakthroughType;

  QuestDraft copyWith({
    String? title,
    String? desc,
    String? type,
    String? category,
    String? difficulty,
    String? measureKind,
    int? baseXp,
    Map<String, double>? rewards,
    Object? unlockStat = unset,
    Object? unlockTo = unset,
    Object? deadline = unset,
    Object? recordKey = unset,
    Object? recordDirection = unset,
    Object? target = unset,
  }) =>
      QuestDraft(
        title: title ?? this.title,
        desc: desc ?? this.desc,
        type: type ?? this.type,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        measureKind: measureKind ?? this.measureKind,
        baseXp: baseXp ?? this.baseXp,
        rewards: rewards ?? this.rewards,
        unlockStat: identical(unlockStat, unset)
            ? this.unlockStat
            : unlockStat as String?,
        unlockTo: identical(unlockTo, unset)
            ? this.unlockTo
            : (unlockTo as num?)?.toDouble(),
        deadline:
            identical(deadline, unset) ? this.deadline : deadline as String?,
        recordKey:
            identical(recordKey, unset) ? this.recordKey : recordKey as String?,
        recordDirection: identical(recordDirection, unset)
            ? this.recordDirection
            : recordDirection as String?,
        target: identical(target, unset)
            ? this.target
            : (target as num?)?.toDouble(),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'desc': desc,
        'type': type,
        'category': category,
        'difficulty': difficulty,
        'measure_kind': measureKind,
        'base_xp': baseXp,
        'rewards': rewards,
        'unlock_stat': unlockStat,
        'unlock_to': unlockTo,
        'deadline': deadline,
        'record_key': recordKey,
        'record_direction': recordDirection,
        'target': target,
      };

  factory QuestDraft.fromJson(Map<String, Object?> json) => QuestDraft(
        title: jString(json['title']),
        desc: jString(json['desc']),
        type: jString(json['type']),
        category: jString(json['category'], 'Other'),
        difficulty: jString(json['difficulty'], 'Normal'),
        measureKind: jStringOrNull(json['measure_kind']) ?? 'flat',
        baseXp: jInt(json['base_xp'], GameConfig.defaultFlatXp),
        rewards: jDoubleMap(json['rewards'], keys: GameConfig.statKeys),
        unlockStat: jStringOrNull(json['unlock_stat']),
        unlockTo: jDoubleOrNull(json['unlock_to']),
        deadline: jStringOrNull(json['deadline']),
        recordKey: jStringOrNull(json['record_key']),
        recordDirection: jStringOrNull(json['record_direction']),
        target: jDoubleOrNull(json['target']),
      );

  @override
  bool operator ==(Object other) =>
      other is QuestDraft &&
      other.title == title &&
      other.desc == desc &&
      other.type == type &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.measureKind == measureKind &&
      other.baseXp == baseXp &&
      deepEquals(other.rewards, rewards) &&
      other.unlockStat == unlockStat &&
      other.unlockTo == unlockTo &&
      other.deadline == deadline &&
      other.recordKey == recordKey &&
      other.recordDirection == recordDirection &&
      other.target == target;

  @override
  int get hashCode => Object.hash(
        title,
        desc,
        type,
        category,
        difficulty,
        measureKind,
        baseXp,
        deepHash(rewards),
        unlockStat,
        unlockTo,
        deadline,
        recordKey,
        recordDirection,
        target,
      );
}
