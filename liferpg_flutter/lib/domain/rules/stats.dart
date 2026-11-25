import 'dart:math' as math;

import '../game_config.dart';
import '../models/quest.dart';
import '../models/stat.dart';

/// §6.1 스탯 성장 완화 배율 = K / (K + max(0, cur − 기본값)).
double statSoftFactor(double cur) =>
    GameConfig.statSoftK /
    (GameConfig.statSoftK + math.max(0, cur - GameConfig.defaultStatValue));

/// §6 레거시 `clamp_to_cap` 그대로.
/// `cur > cap`에서 양수 delta면 cap으로 내려가는 레거시 동작도 그대로다 —
/// 새 앱 규칙(§6.2)은 [applyStatDelta]를 쓴다.
({double value, double applied}) clampToCap(
    double cur, double delta, double cap) {
  if (delta == 0) return (value: cur, applied: 0);
  final target = cur + delta;
  if (target <= cap) return (value: target, applied: delta);
  return (value: cap, applied: math.max(0, cap - cur));
}

/// 새 앱의 스탯 적용 (§6.2): `cur ≥ cap`이면 양수 delta를 무시하고 값을 유지,
/// 그 밖에는 [clampToCap].
({double value, double applied}) applyStatDelta(
    double cur, double delta, double cap) {
  if (delta > 0 && cur >= cap) return (value: cur, applied: 0);
  return clampToCap(cur, delta, cap);
}

/// §6 완료 1회의 스탯 변화량(클램프 전 delta). 키는 `GameConfig.statKeys` 순서.
///
/// - 명시 보상(rewards에 0이 아닌 값)이 있으면 그것만: 양수는 `× rewardRatio`
///   (= §3.4 4단계 eff / raw, 트리 없으면 1), 음수는 그대로.
/// - 없으면 자동 성장: `xp × statGainPerXp × weight × statSoftFactor(cur)`.
/// - 돌파 퀘스트는 빈 맵.
///
/// [rewardRatio]는 INTERFACES 시그니처에 추가한 선택 인자 (기본 1.0).
Map<String, double> statGainsFor({
  required Quest quest,
  required int xp,
  required Map<String, StatState> stats,
  double rewardRatio = 1.0,
}) {
  if (quest.isBreakthrough) return const {};
  final out = <String, double>{};
  final explicit = quest.rewards.entries.where((e) => e.value != 0).toList();
  if (explicit.isNotEmpty) {
    for (final k in GameConfig.statKeys) {
      final r = quest.rewards[k] ?? 0;
      if (r == 0) continue;
      out[k] = r > 0 ? r * rewardRatio : r;
    }
    return out;
  }
  final weights = GameConfig.categoryStatWeights[quest.category] ?? const {};
  for (final k in GameConfig.statKeys) {
    final w = weights[k];
    if (w == null || w == 0) continue;
    final cur = stats[k]?.value ?? GameConfig.defaultStatValue;
    final d = xp * GameConfig.statGainPerXp * w * statSoftFactor(cur);
    if (d != 0) out[k] = d;
  }
  return out;
}
