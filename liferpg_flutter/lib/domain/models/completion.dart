import '../format.dart';
import 'json_helpers.dart';

/// 완료 1회 기록 — 로그·통계·되돌리기 근거 (GAME_DESIGN §12 Completion).
class Completion {
  const Completion({
    this.id,
    required this.questId,
    required this.questTitle,
    required this.category,
    this.tree,
    this.measureKind = 'flat',
    this.values = const {},
    this.rawXp = 0,
    this.xp = 0,
    this.statGains = const {},
    this.recordKey,
    this.recordValue,
    this.isPr = false,
    required this.at,
  });

  /// 저장 후 부여 (data 계층).
  final int? id;
  final int questId;
  final String questTitle;
  final String category;

  /// 매핑 없으면 null (`Other`·돌파).
  final String? tree;
  final String measureKind;
  final Map<String, double> values;

  /// §3.4 1~2단계 (난이도·상한·PR 보너스 포함, 감쇠 전).
  final int rawXp;

  /// §3.4 7단계 실제 지급.
  final int xp;

  /// 실제 적용된 스탯 변화 (0이 아닌 것만, 음수 보상 포함).
  final Map<String, double> statGains;
  final String? recordKey;
  final double? recordValue;
  final bool isPr;
  final DateTime at;

  Completion copyWith({
    Object? id = unset,
    int? questId,
    String? questTitle,
    String? category,
    Object? tree = unset,
    String? measureKind,
    Map<String, double>? values,
    int? rawXp,
    int? xp,
    Map<String, double>? statGains,
    Object? recordKey = unset,
    Object? recordValue = unset,
    bool? isPr,
    DateTime? at,
  }) =>
      Completion(
        id: identical(id, unset) ? this.id : id as int?,
        questId: questId ?? this.questId,
        questTitle: questTitle ?? this.questTitle,
        category: category ?? this.category,
        tree: identical(tree, unset) ? this.tree : tree as String?,
        measureKind: measureKind ?? this.measureKind,
        values: values ?? this.values,
        rawXp: rawXp ?? this.rawXp,
        xp: xp ?? this.xp,
        statGains: statGains ?? this.statGains,
        recordKey:
            identical(recordKey, unset) ? this.recordKey : recordKey as String?,
        recordValue: identical(recordValue, unset)
            ? this.recordValue
            : (recordValue as num?)?.toDouble(),
        isPr: isPr ?? this.isPr,
        at: at ?? this.at,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'quest_id': questId,
        'quest_title': questTitle,
        'category': category,
        'tree': tree,
        'measure_kind': measureKind,
        'values': values,
        'raw_xp': rawXp,
        'xp': xp,
        'stat_gains': statGains,
        'record_key': recordKey,
        'record_value': recordValue,
        'is_pr': isPr,
        'at': formatTimestamp(at),
      };

  factory Completion.fromJson(Map<String, Object?> json) => Completion(
        id: jIntOrNull(json['id']),
        questId: jInt(json['quest_id']),
        questTitle: jString(json['quest_title']),
        category: jString(json['category'], 'Other'),
        tree: jStringOrNull(json['tree']),
        measureKind: jStringOrNull(json['measure_kind']) ?? 'flat',
        values: jDoubleMap(json['values']),
        rawXp: jInt(json['raw_xp']),
        xp: jInt(json['xp']),
        statGains: jDoubleMap(json['stat_gains']),
        recordKey: jStringOrNull(json['record_key']),
        recordValue: jDoubleOrNull(json['record_value']),
        isPr: jBool(json['is_pr']),
        at: jTime(json['at'], epoch),
      );

  @override
  bool operator ==(Object other) =>
      other is Completion &&
      other.id == id &&
      other.questId == questId &&
      other.questTitle == questTitle &&
      other.category == category &&
      other.tree == tree &&
      other.measureKind == measureKind &&
      deepEquals(other.values, values) &&
      other.rawXp == rawXp &&
      other.xp == xp &&
      deepEquals(other.statGains, statGains) &&
      other.recordKey == recordKey &&
      other.recordValue == recordValue &&
      other.isPr == isPr &&
      other.at == at;

  @override
  int get hashCode => Object.hash(
        id,
        questId,
        questTitle,
        category,
        tree,
        measureKind,
        deepHash(values),
        rawXp,
        xp,
        deepHash(statGains),
        recordKey,
        recordValue,
        isPr,
        at,
      );

  @override
  String toString() => 'Completion(q$questId $questTitle xp=$xp raw=$rawXp)';
}
