import '../game_config.dart';
import '../rules/leveling.dart' as lv;
import 'json_helpers.dart';
import 'skill_tree.dart';
import 'stat.dart';

/// 플레이어 프로필 (스탯·트리·오늘 누적치·카운터).
class Profile {
  const Profile({
    required this.stats,
    required this.trees,
    required this.todayDate,
    this.rawToday = const {},
    this.countToday = const {},
    this.todayXp = 0,
    this.streakDays = 0,
    this.lastActiveDate,
    this.totalCompletions = 0,
    this.breakthroughSuccesses = 0,
    this.prCount = 0,
    this.fatigue = 0,
    this.graceWeekUsed = false,
  });

  /// 기본 스탯 7종(10/30)·트리 7종(0 XP)으로 시작하는 프로필.
  factory Profile.initial(String todayDate) => Profile(
        stats: {for (final k in GameConfig.statKeys) k: StatState.initial(k)},
        trees: {for (final k in GameConfig.treeKeys) k: TreeState(key: k)},
        todayDate: todayDate,
      );

  /// 7종 모두 존재 (`GameConfig.statKeys`).
  final Map<String, StatState> stats;

  /// 7종 모두 존재 (`GameConfig.treeKeys`).
  final Map<String, TreeState> trees;

  /// 일일 리셋 기준 날짜 `YYYY-MM-DD`.
  final String todayDate;

  /// R2 트리별 오늘 누적 원시 XP (없는 키 = 0).
  final Map<String, int> rawToday;

  /// R2 트리별 오늘 완료 횟수 (없는 키 = 0).
  final Map<String, int> countToday;

  /// 오늘 지급된 XP 합.
  final int todayXp;
  final int streakDays;
  final String? lastActiveDate;

  /// 누적 완료 수 (삭제해도 줄지 않음).
  final int totalCompletions;
  final int breakthroughSuccesses;
  final int prCount;

  /// R4 (MVP에선 0 고정).
  final double fatigue;

  /// R6 (MVP에선 미사용).
  final bool graceWeekUsed;

  /// 트리 레벨 정보 (없는 트리는 0 XP).
  LevelInfo treeLevel(String tree) => lv.levelFromXp(trees[tree]?.totalXp ?? 0);

  /// 1 + Σ(트리Lv − 1) (GAME_DESIGN §5.2).
  int get mainLevel => lv.mainLevel(GameConfig.treeKeys
      .map((t) => lv.levelFromXp(trees[t]?.totalXp ?? 0).level));

  /// 모든 트리 누적 XP 합.
  int get totalXp => trees.values.fold(0, (s, t) => s + t.totalXp);

  Profile copyWith({
    Map<String, StatState>? stats,
    Map<String, TreeState>? trees,
    String? todayDate,
    Map<String, int>? rawToday,
    Map<String, int>? countToday,
    int? todayXp,
    int? streakDays,
    Object? lastActiveDate = unset,
    int? totalCompletions,
    int? breakthroughSuccesses,
    int? prCount,
    double? fatigue,
    bool? graceWeekUsed,
  }) =>
      Profile(
        stats: stats ?? this.stats,
        trees: trees ?? this.trees,
        todayDate: todayDate ?? this.todayDate,
        rawToday: rawToday ?? this.rawToday,
        countToday: countToday ?? this.countToday,
        todayXp: todayXp ?? this.todayXp,
        streakDays: streakDays ?? this.streakDays,
        lastActiveDate: identical(lastActiveDate, unset)
            ? this.lastActiveDate
            : lastActiveDate as String?,
        totalCompletions: totalCompletions ?? this.totalCompletions,
        breakthroughSuccesses:
            breakthroughSuccesses ?? this.breakthroughSuccesses,
        prCount: prCount ?? this.prCount,
        fatigue: fatigue ?? this.fatigue,
        graceWeekUsed: graceWeekUsed ?? this.graceWeekUsed,
      );

  Map<String, Object?> toJson() => {
        'stats': {for (final e in stats.entries) e.key: e.value.toJson()},
        'trees': {for (final e in trees.entries) e.key: e.value.toJson()},
        'today_date': todayDate,
        'raw_today': rawToday,
        'count_today': countToday,
        'today_xp': todayXp,
        'streak_days': streakDays,
        'last_active_date': lastActiveDate,
        'total_completions': totalCompletions,
        'breakthrough_successes': breakthroughSuccesses,
        'pr_count': prCount,
        'fatigue': fatigue,
        'grace_week_used': graceWeekUsed,
      };

  /// 빠진 스탯·트리 키는 기본값으로 채운다.
  factory Profile.fromJson(Map<String, Object?> json) {
    final statsJson = jMap(json['stats']);
    final treesJson = jMap(json['trees']);
    final stats = <String, StatState>{};
    for (final e in statsJson.entries) {
      if (e.value is Map) {
        stats[e.key] = StatState.fromJson({...jMap(e.value), 'key': e.key});
      }
    }
    for (final k in GameConfig.statKeys) {
      stats.putIfAbsent(k, () => StatState.initial(k));
    }
    final trees = <String, TreeState>{};
    for (final e in treesJson.entries) {
      if (e.value is Map) {
        trees[e.key] = TreeState.fromJson({...jMap(e.value), 'key': e.key});
      }
    }
    for (final k in GameConfig.treeKeys) {
      trees.putIfAbsent(k, () => TreeState(key: k));
    }
    return Profile(
      stats: stats,
      trees: trees,
      todayDate: jString(json['today_date']),
      rawToday: jIntMap(json['raw_today']),
      countToday: jIntMap(json['count_today']),
      todayXp: jInt(json['today_xp']),
      streakDays: jInt(json['streak_days']),
      lastActiveDate: jStringOrNull(json['last_active_date']),
      totalCompletions: jInt(json['total_completions']),
      breakthroughSuccesses: jInt(
          json['breakthrough_successes'] ?? json['breakthrough_success_count']),
      prCount: jInt(json['pr_count']),
      fatigue: jDouble(json['fatigue']),
      graceWeekUsed: jBool(json['grace_week_used']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      deepEquals(other.stats, stats) &&
      deepEquals(other.trees, trees) &&
      other.todayDate == todayDate &&
      deepEquals(other.rawToday, rawToday) &&
      deepEquals(other.countToday, countToday) &&
      other.todayXp == todayXp &&
      other.streakDays == streakDays &&
      other.lastActiveDate == lastActiveDate &&
      other.totalCompletions == totalCompletions &&
      other.breakthroughSuccesses == breakthroughSuccesses &&
      other.prCount == prCount &&
      other.fatigue == fatigue &&
      other.graceWeekUsed == graceWeekUsed;

  @override
  int get hashCode => Object.hash(
        deepHash(stats),
        deepHash(trees),
        todayDate,
        deepHash(rawToday),
        deepHash(countToday),
        todayXp,
        streakDays,
        lastActiveDate,
        totalCompletions,
        breakthroughSuccesses,
        prCount,
        fatigue,
        graceWeekUsed,
      );

  @override
  String toString() =>
      'Profile(main Lv.$mainLevel, today=$todayDate, streak=$streakDays)';
}
