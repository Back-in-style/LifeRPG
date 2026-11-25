// MVP 이후 (R4 피로도, GAME_DESIGN §10.2). 엔진은 아직 호출하지 않는다.
import '../game_config.dart';

/// §10.2 피로도 → XP 효율 배율.
double fatigueMultiplier(double f) {
  final t = ((f - GameConfig.fatigueThreshold) /
          (GameConfig.fatigueMax - GameConfig.fatigueThreshold))
      .clamp(0.0, 1.0);
  return 1 - GameConfig.fatigueMaxPenalty * t;
}

/// §10.2 하루가 지날 때 피로도 자연 회복.
double fatigueOnRollover(double f) => f * GameConfig.fatigueDailyRetain;
