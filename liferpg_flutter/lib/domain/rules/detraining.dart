// MVP 이후 (R3 디트레이닝, GAME_DESIGN §10.1). 엔진은 아직 호출하지 않는다.
import 'dart:math' as math;

import '../format.dart';
import '../game_config.dart';

/// §10.1 디트레이닝 바닥 = max(기본값, peak × 0.85).
double detrainFloor(double peak) =>
    math.max(GameConfig.defaultStatValue, peak * GameConfig.detrainFloorRatio);

/// §10.1 하루치 디트레이닝 적용 후 값. [daysSinceGain] > 유예일이고 cur > 바닥일 때만 감소.
double detrainStep(double cur, double peak, int daysSinceGain) {
  if (daysSinceGain <= GameConfig.detrainGraceDays) return cur;
  final floor = detrainFloor(peak);
  if (cur <= floor) return cur;
  return roundTo(cur - GameConfig.detrainDailyRate * (cur - floor),
      GameConfig.statDecimals);
}
