import '../sgcy_config.dart';
import 'json_helpers.dart';

/// 세부스탯 하나의 상태.
class SubStat {
  const SubStat({
    required this.key,
    this.level = 1,
    this.stat = SgcyConfig.initialStat,
    this.lastActiveDate,
    this.protectedUntil,
  });

  final String key;

  /// 1~9. 특별 퀘스트(승급)·배치로만 오르고, 강등으로 내려간다.
  final int level;

  /// 레벨을 지키는 게이지.
  final double stat;

  /// 마지막으로 이 세부스탯에 퀘스트 보상이 들어온 날 (자연 감소 기준).
  final String? lastActiveDate;

  /// 이 날짜(포함)까지 강등 없음.
  final String? protectedUntil;

  String get label => SgcyConfig.substatByKey[key]?.label ?? key;
  String get element => SgcyConfig.substatByKey[key]?.element ?? '';
  String get levelName => SgcyConfig.levelName(level);
  double get baseStat => SgcyConfig.baseStat(level);
  double? get demotionLine => SgcyConfig.demotionLine(level);

  /// 강등선~기준 스탯 사이 위치 (0~1). 1레벨은 0~10.
  double get gauge {
    final lo = demotionLine ?? 0;
    final hi = baseStat;
    if (hi <= lo) return 1;
    return ((stat - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  bool isProtected(String today) =>
      protectedUntil != null && today.compareTo(protectedUntil!) <= 0;

  SubStat copyWith({
    int? level,
    double? stat,
    Object? lastActiveDate = unset,
    Object? protectedUntil = unset,
  }) =>
      SubStat(
        key: key,
        level: level ?? this.level,
        stat: stat ?? this.stat,
        lastActiveDate: identical(lastActiveDate, unset)
            ? this.lastActiveDate
            : lastActiveDate as String?,
        protectedUntil: identical(protectedUntil, unset)
            ? this.protectedUntil
            : protectedUntil as String?,
      );

  Map<String, Object?> toJson() => {
        'level': level,
        'stat': stat,
        if (lastActiveDate != null) 'last_active_date': lastActiveDate,
        if (protectedUntil != null) 'protected_until': protectedUntil,
      };

  factory SubStat.fromJson(String key, Map<String, Object?> j) => SubStat(
        key: key,
        level: SgcyConfig.clampLevel(jInt(j['level'], 1)),
        stat: jDouble(j['stat'], SgcyConfig.initialStat)
            .clamp(0, double.maxFinite),
        lastActiveDate: jStringOrNull(j['last_active_date']),
        protectedUntil: jStringOrNull(j['protected_until']),
      );

  @override
  bool operator ==(Object other) =>
      other is SubStat &&
      other.key == key &&
      deepEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(key, deepHash(toJson()));

  @override
  String toString() => 'SubStat($key L$level $stat)';
}
