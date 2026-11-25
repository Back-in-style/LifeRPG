import '../format.dart';
import 'json_helpers.dart';

/// 개인기록 (GAME_DESIGN §7.1). [key]는 사용자 정의 문자열.
class PersonalRecord {
  const PersonalRecord({
    required this.key,
    this.direction = 'higher',
    this.stat,
    this.best,
    this.history = const [],
  });

  final String key;

  /// `'higher'|'lower'`.
  final String direction;

  /// 연결 스탯 (돌파 대상).
  final String? stat;

  /// 방향에 맞는 역대 최고값. 기록이 없으면 null.
  final double? best;

  /// 오래된 것부터.
  final List<RecordEntry> history;

  bool get lowerIsBetter => direction == 'lower';

  PersonalRecord copyWith({
    String? key,
    String? direction,
    Object? stat = unset,
    Object? best = unset,
    List<RecordEntry>? history,
  }) =>
      PersonalRecord(
        key: key ?? this.key,
        direction: direction ?? this.direction,
        stat: identical(stat, unset) ? this.stat : stat as String?,
        best: identical(best, unset) ? this.best : (best as num?)?.toDouble(),
        history: history ?? this.history,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'direction': direction,
        'stat': stat,
        'best': best,
        'history': [for (final e in history) e.toJson()],
      };

  factory PersonalRecord.fromJson(Map<String, Object?> json) => PersonalRecord(
        key: jString(json['key']),
        direction: json['direction'] == 'lower' ? 'lower' : 'higher',
        stat: jStringOrNull(json['stat']),
        best: jDoubleOrNull(json['best']),
        history: [
          for (final e in jList(json['history']))
            if (e is Map) RecordEntry.fromJson(jMap(e)),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is PersonalRecord &&
      other.key == key &&
      other.direction == direction &&
      other.stat == stat &&
      other.best == best &&
      deepEquals(other.history, history);

  @override
  int get hashCode =>
      Object.hash(key, direction, stat, best, Object.hashAll(history));

  @override
  String toString() => 'PersonalRecord($key best=$best ${history.length}건)';
}

/// 기록 이력 1건.
class RecordEntry {
  const RecordEntry({
    required this.value,
    required this.at,
    this.completionId,
    this.isPr = false,
  });

  final double value;
  final DateTime at;

  /// 엔진은 null로 만든다 (Completion id는 data 계층이 저장 후 부여).
  final int? completionId;
  final bool isPr;

  RecordEntry copyWith({
    double? value,
    DateTime? at,
    Object? completionId = unset,
    bool? isPr,
  }) =>
      RecordEntry(
        value: value ?? this.value,
        at: at ?? this.at,
        completionId: identical(completionId, unset)
            ? this.completionId
            : completionId as int?,
        isPr: isPr ?? this.isPr,
      );

  Map<String, Object?> toJson() => {
        'value': value,
        'at': formatTimestamp(at),
        'completion_id': completionId,
        'is_pr': isPr,
      };

  factory RecordEntry.fromJson(Map<String, Object?> json) => RecordEntry(
        value: jDouble(json['value']),
        at: jTime(json['at'], epoch),
        completionId: jIntOrNull(json['completion_id']),
        isPr: jBool(json['is_pr']),
      );

  @override
  bool operator ==(Object other) =>
      other is RecordEntry &&
      other.value == value &&
      other.at == at &&
      other.completionId == completionId &&
      other.isPr == isPr;

  @override
  int get hashCode => Object.hash(value, at, completionId, isPr);
}
