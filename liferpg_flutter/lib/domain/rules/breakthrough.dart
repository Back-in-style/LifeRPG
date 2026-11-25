import 'dart:math' as math;

import '../game_config.dart';

/// 돌파 결과.
class BreakthroughResult {
  const BreakthroughResult({
    required this.stat,
    required this.oldCap,
    required this.newCap,
    required this.success,
  });

  final String stat;
  final double oldCap;

  /// 적용 후 상한. 실패면 [oldCap]과 같다.
  final double newCap;
  final bool success;

  @override
  bool operator ==(Object other) =>
      other is BreakthroughResult &&
      other.stat == stat &&
      other.oldCap == oldCap &&
      other.newCap == newCap &&
      other.success == success;

  @override
  int get hashCode => Object.hash(stat, oldCap, newCap, success);

  @override
  String toString() =>
      'BreakthroughResult($stat $oldCap → $newCap, success=$success)';
}

/// §7.3 돌파 성공 시 새 상한 = min(requested, cap + max(20, cap × 0.5)).
double breakthroughNewCap(double cap, double requestedCap) {
  final maxStep = math.max(GameConfig.breakthroughMinStep,
      cap * GameConfig.breakthroughMaxStepRatio);
  return math.min(requestedCap, cap + maxStep);
}

/// §7.3 돌파 판정. 성공 = [prAchieved] && `requestedCap > cap`.
/// 레거시 ACTIVE 돌파는 `prAchieved: true`로 호출한다 (레거시 규칙 + maxStep 제한).
BreakthroughResult resolveBreakthrough({
  required String stat,
  required double cap,
  required double requestedCap,
  required bool prAchieved,
}) {
  final success = prAchieved && requestedCap > cap;
  return BreakthroughResult(
    stat: stat,
    oldCap: cap,
    newCap: success ? breakthroughNewCap(cap, requestedCap) : cap,
    success: success,
  );
}
