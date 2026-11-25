import 'dart:math' as math;

import '../game_config.dart';
import '../models/skill_tree.dart';

/// §5.1 레벨 L → L+1 필요 XP.
int xpToNext(int level) => (GameConfig.treeLevelBaseXp *
        math.pow(GameConfig.treeLevelGrowth, level - 1))
    .round();

/// §5.1 레벨 [level]에 도달하는 누적 XP.
int cumulativeXpForLevel(int level) {
  var s = 0;
  for (var l = 1; l < level; l++) {
    s += xpToNext(l);
  }
  return s;
}

/// §5.1 누적 XP → 레벨 정보 (최대 [GameConfig.treeLevelMax]).
LevelInfo levelFromXp(int totalXp) {
  var level = 1, left = totalXp < 0 ? 0 : totalXp;
  while (level < GameConfig.treeLevelMax && left >= xpToNext(level)) {
    left -= xpToNext(level);
    level++;
  }
  return LevelInfo(level: level, xpInLevel: left, xpForNext: xpToNext(level));
}

/// §5.2 메인 레벨 = 1 + Σ(트리 레벨 − 1).
int mainLevel(Iterable<int> treeLevels) =>
    1 + treeLevels.fold(0, (s, l) => s + (l - 1));

/// §1.2 등급 (상한 기준).
String gradeFromCap(double cap) {
  for (final b in GameConfig.gradeBands) {
    if (cap <= b.maxCap) return b.grade;
  }
  return GameConfig.topGrade;
}
