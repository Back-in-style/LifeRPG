import '../game_config.dart';
import '../models/game_state.dart';
import 'leveling.dart';

/// §9 아직 해금되지 않았고 지금 조건을 만족하는 업적 id (`GameConfig.achievements` 순서).
List<String> newlyUnlocked(GameState state) {
  final p = state.profile;
  final treeLevels = [
    for (final t in GameConfig.treeKeys) p.treeLevel(t).level,
  ];
  final main = mainLevel(treeLevels);
  final out = <String>[];
  for (final a in GameConfig.achievements) {
    if (state.unlockedAchievements.contains(a.id)) continue;
    final t = a.threshold;
    final ok = switch (a.kind) {
      'completions' => p.totalCompletions >= t,
      'main_level' => main >= t,
      'breakthrough_success' => p.breakthroughSuccesses >= t,
      'stat_at_cap' => p.stats.values.any((s) => s.value >= s.cap),
      'grade' => p.stats.values
          .any((s) => GameConfig.gradeOrder.indexOf(gradeFromCap(s.cap)) >= t),
      'streak' => p.streakDays >= t,
      'tree_level' => treeLevels.any((l) => l >= t),
      'all_trees_level' => treeLevels.every((l) => l >= t),
      'pr_count' => p.prCount >= t,
      _ => false,
    };
    if (ok) out.add(a.id);
  }
  return out;
}

/// 업적 정의 조회. 없으면 null.
AchievementDef? achievementDef(String id) {
  for (final a in GameConfig.achievements) {
    if (a.id == id) return a;
  }
  return null;
}
