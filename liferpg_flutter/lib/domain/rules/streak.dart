import 'dart:math' as math;

import '../format.dart';
import '../game_config.dart';

/// §8 오늘 첫 완료 시 스트릭 갱신.
/// 오늘 이미 활동 → 그대로, 어제 활동 → +1, 그 밖(null 포함) → 1.
/// 시계가 거꾸로 가서 마지막 활동이 미래(gap < 0)면 스트릭·날짜를 그대로 둔다.
({int streakDays, String lastActiveDate}) markActive({
  required int streakDays,
  required String? lastActiveDate,
  required String today,
}) {
  final gap = daysBetween(lastActiveDate, today);
  if (gap == 0) return (streakDays: streakDays, lastActiveDate: today);
  if (gap != null && gap < 0) {
    return (streakDays: streakDays, lastActiveDate: lastActiveDate!);
  }
  if (gap == 1) return (streakDays: streakDays + 1, lastActiveDate: today);
  return (streakDays: 1, lastActiveDate: today);
}

/// §8 날짜 변경 시 표시용 스트릭: 마지막 활동이 어제보다 전(또는 없음)이면 0.
int streakOnRollover({
  required int streakDays,
  required String? lastActiveDate,
  required String today,
}) {
  final gap = daysBetween(lastActiveDate, today);
  if (gap == null || gap > 1) return 0;
  return streakDays;
}

/// §8 스트릭 XP 보너스 비율 = min(10%, streak × 1%).
double streakBonus(int streak) => math.min(GameConfig.streakBonusMax,
    math.max(0, streak) * GameConfig.streakBonusPerDay);
