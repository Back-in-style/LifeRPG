import 'dart:math' as math;

import '../game_config.dart';

/// §4.1 체감 감소: 오늘 누적 원시 XP [rawToday]에서 [raw]만큼 더할 때의 효과 XP.
double diminish(String tree, int rawToday, int raw) {
  final bands = GameConfig.treeDiminishingBands[tree] ??
      GameConfig.defaultDiminishingBands;
  final a = rawToday.toDouble(), b = (rawToday + raw).toDouble();
  var lo = 0.0, eff = 0.0;
  for (final band in bands) {
    final hi = band.upTo;
    final overlap = math.min(b, hi) - math.max(a, lo);
    if (overlap > 0) eff += overlap * band.rate;
    lo = hi;
  }
  return eff;
}

/// §4.2 같은 날 같은 트리 [n]번째(1부터) 완료의 반복 감쇠 배율.
double repeatMultiplier(int n) => math.max(GameConfig.repeatDecayFloor,
    math.pow(GameConfig.repeatDecay, math.max(0, n - 1)).toDouble());
