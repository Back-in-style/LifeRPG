import 'json_helpers.dart';

/// 스킬 트리 하나의 상태. 레벨은 저장하지 않고 `levelFromXp(totalXp)`로 계산한다.
class TreeState {
  const TreeState({required this.key, this.totalXp = 0});

  /// `GameConfig.treeKeys` 중 하나.
  final String key;

  /// 누적 효과 XP.
  final int totalXp;

  TreeState copyWith({String? key, int? totalXp}) =>
      TreeState(key: key ?? this.key, totalXp: totalXp ?? this.totalXp);

  Map<String, Object?> toJson() => {'key': key, 'total_xp': totalXp};

  factory TreeState.fromJson(Map<String, Object?> json) => TreeState(
        key: jString(json['key']),
        totalXp: jInt(json['total_xp'] ?? json['xp']),
      );

  @override
  bool operator ==(Object other) =>
      other is TreeState && other.key == key && other.totalXp == totalXp;

  @override
  int get hashCode => Object.hash(key, totalXp);

  @override
  String toString() => 'TreeState($key $totalXp)';
}

/// 누적 XP에서 계산한 레벨 정보 (레거시 `level / xp_in_level / xp_next`).
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.xpInLevel,
    required this.xpForNext,
  });

  final int level;
  final int xpInLevel;
  final int xpForNext;

  /// 0.0~1.0 레벨 진행률.
  double get progress =>
      xpForNext <= 0 ? 0 : (xpInLevel / xpForNext).clamp(0.0, 1.0).toDouble();

  LevelInfo copyWith({int? level, int? xpInLevel, int? xpForNext}) => LevelInfo(
        level: level ?? this.level,
        xpInLevel: xpInLevel ?? this.xpInLevel,
        xpForNext: xpForNext ?? this.xpForNext,
      );

  Map<String, Object?> toJson() =>
      {'level': level, 'xp_in_level': xpInLevel, 'xp_next': xpForNext};

  factory LevelInfo.fromJson(Map<String, Object?> json) => LevelInfo(
        level: jInt(json['level'], 1),
        xpInLevel: jInt(json['xp_in_level']),
        xpForNext: jInt(json['xp_next'] ?? json['xp_for_next']),
      );

  @override
  bool operator ==(Object other) =>
      other is LevelInfo &&
      other.level == level &&
      other.xpInLevel == xpInLevel &&
      other.xpForNext == xpForNext;

  @override
  int get hashCode => Object.hash(level, xpInLevel, xpForNext);

  @override
  String toString() => 'LevelInfo(Lv.$level $xpInLevel/$xpForNext)';
}
