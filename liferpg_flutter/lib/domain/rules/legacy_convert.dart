import 'dart:math' as math;

import '../models/skill_tree.dart';
import 'leveling.dart';

/// 레거시 레벨 L → L+1 필요 XP = 200 + (L−1)·80 (SPEC_v1 §3.3).
int legacyXpToNext(int level) => 200 + (level - 1) * 80;

/// 레거시 레벨 공식으로 누적 XP → 레벨 정보.
LevelInfo legacyLevelFromXp(int totalXp) {
  var level = 1, left = totalXp < 0 ? 0 : totalXp;
  while (left >= legacyXpToNext(level)) {
    left -= legacyXpToNext(level);
    level++;
  }
  return LevelInfo(
      level: level, xpInLevel: left, xpForNext: legacyXpToNext(level));
}

/// §5.3 레거시 트리 XP → 새 트리 XP (레벨·진행률 보존, XP 감소 없음).
int convertLegacyTreeXp(int legacyXp) {
  final old = legacyLevelFromXp(legacyXp);
  final preserved = cumulativeXpForLevel(old.level) +
      (old.xpInLevel / old.xpForNext * xpToNext(old.level)).floor();
  return math.max(legacyXp, preserved);
}
