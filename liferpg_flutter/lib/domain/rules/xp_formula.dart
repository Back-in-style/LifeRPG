import 'dart:math' as math;

import '../game_config.dart';

typedef _C = GameConfig;

/// §3.2 측정치 → 기본 XP (난이도 배율 전, 실수).
double measureBaseXp(String kind, Map<String, double> m,
    {int flatXp = GameConfig.defaultFlatXp}) {
  double v(String k) => m[k] ?? 0;
  switch (kind) {
    case 'flat':
      return flatXp.toDouble();
    case 'sleep_h':
      final h = v('hours').clamp(0, _C.sleepMaxH).toDouble();
      if (h < _C.sleepTargetMinH) {
        return _C.sleepXpFull * h / _C.sleepTargetMinH;
      }
      if (h <= _C.sleepTargetMaxH) return _C.sleepXpFull;
      return math.max(0,
          _C.sleepXpFull - (h - _C.sleepTargetMaxH) * _C.sleepOverPenaltyPerH);
    case 'strength':
      return v('sets') *
          v('reps') *
          v('weight_kg') *
          _C.measureXpPerUnit['strength']!;
    case 'reps':
      return v('sets') * v('reps') * _C.measureXpPerUnit['reps']!;
    default:
      final fields = _C.measureFields[kind];
      final perUnit = _C.measureXpPerUnit[kind];
      if (fields == null || fields.isEmpty || perUnit == null) return 0;
      return v(fields.first) * perUnit;
  }
}

/// §3.3 원시 XP (완료 1회, 최대 [GameConfig.maxRawXpPerCompletion]).
/// - flat: [flatXp](= `Quest.xp`, 추가할 때 난이도 배율 적용됨)를 그대로.
/// - 측정형: 난이도 무시 (항상 1.0).
int rawXp(String kind, Map<String, double> m, String difficulty,
    {int flatXp = GameConfig.defaultFlatXp}) {
  if (kind == 'flat') {
    return math.min(_C.maxRawXpPerCompletion, math.max(1, flatXp));
  }
  final base = measureBaseXp(kind, m);
  // 곱이 Infinity/NaN이면 truncate()가 예외 → 상한(무한대) 또는 최소 1(NaN)로.
  if (base.isNaN) return 1;
  if (!base.isFinite || base >= _C.maxRawXpPerCompletion) {
    return _C.maxRawXpPerCompletion;
  }
  final x = math.max(1, base.truncate());
  return math.min(_C.maxRawXpPerCompletion, x);
}

/// flat 퀘스트 추가 시 저장 XP = `max(1, trunc(base × 난이도 배율))` (레거시 adj_xp).
int adjustedFlatXp(int baseXp, String difficulty) {
  final mult =
      _C.difficultyMultiplier[difficulty] ?? _C.defaultDifficultyMultiplier;
  return math.max(1, (baseXp * mult).truncate());
}
