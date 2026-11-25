// 밸런스 시뮬레이터용 임시 규칙 구현 (A2).
//
// docs/GAME_DESIGN.md의 공식을 그대로 옮긴 참고 구현이다. 실제 엔진은 A3가
// lib/domain/rules/에 만든다. 두 구현의 결과가 다르면 GAME_DESIGN.md가 기준이다.
import 'dart:math' as math;

import 'package:liferpg/domain/game_config.dart';

typedef C = GameConfig;

// ---------------------------------------------------------------------------
// 순수 공식 (GAME_DESIGN.md §3~§7)
// ---------------------------------------------------------------------------

/// §3.2 측정치 → 기본 XP (난이도 배율 전, 실수).
double measureBaseXp(String kind, Map<String, double> m, {int flatXp = 30}) {
  double v(String k) => m[k] ?? 0;
  switch (kind) {
    case 'flat':
      return flatXp.toDouble();
    case 'sleep_h':
      final h = v('hours').clamp(0, C.sleepMaxH).toDouble();
      if (h < C.sleepTargetMinH) return C.sleepXpFull * h / C.sleepTargetMinH;
      if (h <= C.sleepTargetMaxH) return C.sleepXpFull;
      return math.max(
          0, C.sleepXpFull - (h - C.sleepTargetMaxH) * C.sleepOverPenaltyPerH);
    case 'strength':
      return v('sets') *
          v('reps') *
          v('weight_kg') *
          C.measureXpPerUnit['strength']!;
    case 'reps':
      return v('sets') * v('reps') * C.measureXpPerUnit['reps']!;
    default:
      final field = C.measureFields[kind]!.first;
      return v(field) * C.measureXpPerUnit[kind]!;
  }
}

/// §3.3 원시 XP.
/// - flat: 레거시처럼 저장된 xp(추가할 때 이미 난이도 배율 적용)를 그대로 쓴다.
/// - 측정형(kind != flat): 난이도 배율을 적용하지 않는다 (항상 1.0).
///   [difficulty]는 시그니처 호환용으로 받지만 측정형에서는 무시한다.
int rawXp(String kind, Map<String, double> m, String difficulty,
    {int flatXp = 30}) {
  if (kind == 'flat') {
    return math.min(C.maxRawXpPerCompletion, math.max(1, flatXp));
  }
  final x = math.max(1, measureBaseXp(kind, m).truncate());
  return math.min(C.maxRawXpPerCompletion, x);
}

/// §4 체감 감소: 오늘 누적 원시 XP [rawToday]에서 [raw]만큼 더할 때의 효과 XP.
double diminish(String tree, int rawToday, int raw) {
  final bands = C.treeDiminishingBands[tree] ?? C.defaultDiminishingBands;
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

/// §4.2 같은 날 같은 트리 n번째(1부터) 완료의 반복 감쇠 배율.
double repeatMultiplier(int n) =>
    math.max(C.repeatDecayFloor, math.pow(C.repeatDecay, n - 1).toDouble());

/// §5 레벨 L→L+1 필요 XP.
int xpToNext(int level) =>
    (C.treeLevelBaseXp * math.pow(C.treeLevelGrowth, level - 1)).round();

/// §5 누적 XP → (레벨, 레벨 내 XP, 다음까지 필요 XP).
(int, int, int) levelFromXp(int totalXp) {
  var level = 1, left = totalXp;
  while (level < C.treeLevelMax && left >= xpToNext(level)) {
    left -= xpToNext(level);
    level++;
  }
  return (level, left, xpToNext(level));
}

/// §5 레벨 L에 도달하는 누적 XP.
int cumulativeXpForLevel(int level) {
  var s = 0;
  for (var l = 1; l < level; l++) {
    s += xpToNext(l);
  }
  return s;
}

/// §5 메인 레벨 = 1 + Σ(트리 레벨 − 1).
int mainLevel(Iterable<int> treeLevels) =>
    1 + treeLevels.fold(0, (s, l) => s + (l - 1));

/// §5.3 레거시 레벨 공식 (SPEC_v1 §3.3).
(int, int, int) legacyLevelFromXp(int totalXp) {
  var level = 1, left = totalXp;
  while (left >= 200 + (level - 1) * 80) {
    left -= 200 + (level - 1) * 80;
    level++;
  }
  return (level, left, 200 + (level - 1) * 80);
}

/// §5.3 레거시 트리 XP → 새 트리 XP (레벨·진행률 보존, XP 감소 없음).
int convertLegacyTreeXp(int legacyXp) {
  final (lv, inLv, next) = legacyLevelFromXp(legacyXp);
  final preserved =
      cumulativeXpForLevel(lv) + (inLv / next * xpToNext(lv)).floor();
  return math.max(legacyXp, preserved);
}

/// §6 스탯 성장 배율.
double statSoftFactor(double cur) =>
    C.statSoftK / (C.statSoftK + math.max(0, cur - C.defaultStatValue));

/// §6 레거시 clamp_to_cap.
(double, double) clampToCap(double cur, double delta, double cap) {
  if (delta == 0) return (cur, 0);
  final target = cur + delta;
  if (target <= cap) return (target, delta);
  return (cap, math.max(0, cap - cur));
}

/// §6.2 등급.
String gradeFromCap(double cap) {
  for (final b in C.gradeBands) {
    if (cap <= b.maxCap) return b.grade;
  }
  return C.topGrade;
}

/// §7 돌파 성공 시 새 상한.
double breakthroughNewCap(double cap, double requestedCap) {
  final maxStep =
      math.max(C.breakthroughMinStep, cap * C.breakthroughMaxStepRatio);
  return math.min(requestedCap, cap + maxStep);
}

/// §7.2 PR 판정 (높을수록 좋은 기록). [best]가 null이면 기준 기록 등록일 뿐
/// PR이 아니다. 단 돌파 퀘스트에 [target]이 있으면 그 달성 여부로 판정한다.
bool isPr(double value, double? best, {double? target}) {
  if (best == null) return target != null && value >= target;
  return value >= best * (1 + C.prMinImprovementRatio);
}

/// §8 스트릭 보너스 비율.
double streakBonus(int streak) =>
    math.min(C.streakBonusMax, streak * C.streakBonusPerDay);

/// §10.2 피로도 → XP 효율 배율.
double fatigueMultiplier(double f) {
  final t = ((f - C.fatigueThreshold) / (C.fatigueMax - C.fatigueThreshold))
      .clamp(0.0, 1.0);
  return 1 - C.fatigueMaxPenalty * t;
}

double _round3(double v) => (v * 1000).round() / 1000;

// ---------------------------------------------------------------------------
// 시뮬레이션 상태
// ---------------------------------------------------------------------------

/// 하루 활동 하나 (퀘스트 완료 1회).
class Activity {
  const Activity(this.category, this.kind, this.measure,
      {this.difficulty = 'Normal', this.flatXp = 30});
  final String category;
  final String kind;
  final Map<String, double> measure;
  final String difficulty;
  final int flatXp;
}

class SimOptions {
  const SimOptions({this.postMvp = false});

  /// R3 디트레이닝·R4 피로도·R6 유예 스트릭까지 켠다.
  final bool postMvp;
}

class SimState {
  SimState(this.opts) {
    for (final s in C.statKeys) {
      stats[s] = C.defaultStatValue;
      caps[s] = C.defaultStatCap;
      peak[s] = C.defaultStatValue;
      lastGainDay[s] = 0;
      ability[s] = 100;
      bestRecord[s] = 100;
    }
    for (final t in C.treeKeys) {
      treeXp[t] = 0;
    }
  }

  final SimOptions opts;
  final Map<String, double> stats = {}, caps = {}, peak = {};
  final Map<String, int> lastGainDay = {};
  final Map<String, int> treeXp = {};

  /// 시뮬 전용: 스탯별 실제 능력(PR 기록 대용). 해당 스탯이 오른 날마다 성장.
  final Map<String, double> ability = {}, bestRecord = {};
  final Map<String, int> lastBreakthroughDay = {};

  int day = 0;
  Map<String, int> rawToday = {};
  Map<String, int> countToday = {};
  bool activeToday = false, highIntensityToday = false;
  int streak = 0, maxStreak = 0, lastActiveDay = -100;
  int graceUsedWeek = -1;
  double fatigue = 0;

  int completions = 0, breakthroughs = 0, breakthroughFails = 0, prs = 0;
  int totalRaw = 0, totalEff = 0;
  double totalDim = 0;
  final Set<String> unlocked = {};
  final Set<String> _statTrainedToday = {};

  int treeLevel(String t) => levelFromXp(treeXp[t]!).$1;
  int get main => mainLevel(C.treeKeys.map(treeLevel));
  int get totalXp => treeXp.values.fold(0, (a, b) => a + b);

  /// §9 날짜 변경 처리 (dailyRollover).
  void startDay(int d) {
    // 어제 훈련한 스탯의 시뮬 능력치 성장 (하루 1회만 → 몰아치기 불리).
    for (final s in _statTrainedToday) {
      ability[s] = ability[s]! * 1.006;
    }
    _statTrainedToday.clear();
    day = d;
    rawToday = {};
    countToday = {};
    activeToday = false;
    highIntensityToday = false;
    if (opts.postMvp) {
      fatigue *= C.fatigueDailyRetain;
      for (final s in C.statKeys) {
        if (day - lastGainDay[s]! > C.detrainGraceDays) {
          final floor =
              math.max(C.defaultStatValue, peak[s]! * C.detrainFloorRatio);
          final cur = stats[s]!;
          if (cur > floor) {
            stats[s] = _round3(cur - C.detrainDailyRate * (cur - floor));
          }
        }
      }
    }
  }

  void _markActive() {
    if (activeToday) return;
    activeToday = true;
    final gap = day - lastActiveDay;
    if (gap == 1) {
      streak++;
    } else if (opts.postMvp &&
        gap == 2 &&
        graceUsedWeek != (day - 1) ~/ 7 &&
        C.streakGraceDaysPerWeek > 0) {
      graceUsedWeek = (day - 1) ~/ 7;
      streak++;
    } else if (opts.postMvp && streak > 0) {
      streak = (streak * C.streakBreakRetainRatio).floor() + 1;
    } else {
      streak = 1;
    }
    lastActiveDay = day;
    maxStreak = math.max(maxStreak, streak);
  }

  /// §9 퀘스트 완료 (일반).
  void complete(Activity a) {
    completions++;
    _markActive();
    final tree = C.categoryToTree[a.category];
    if (tree == null) return;
    final raw = rawXp(a.kind, a.measure, a.difficulty, flatXp: a.flatXp);
    final before = rawToday[tree] ?? 0;
    final n = (countToday[tree] ?? 0) + 1;
    countToday[tree] = n;
    var eff = diminish(tree, before, raw) * repeatMultiplier(n);
    rawToday[tree] = before + raw;
    totalDim += eff;
    if (opts.postMvp) {
      eff *= fatigueMultiplier(fatigue);
      final isRecovery = tree == 'recovery' || tree == 'mobility';
      if (isRecovery && !highIntensityToday) eff *= C.restDayRecoveryBonus;
    }
    eff *= 1 + streakBonus(streak);
    final xp = eff.round();
    totalRaw += raw;
    totalEff += xp;
    treeXp[tree] = treeXp[tree]! + xp;

    if (opts.postMvp) {
      if (C.highIntensityCategories.contains(a.category)) {
        highIntensityToday = true;
      }
      fatigue += xp * (C.fatigueLoadPerXp[tree] ?? 0);
      if (a.kind == 'sleep_h') {
        final h = a.measure['hours'] ?? 0;
        if (h >= C.sleepTargetMinH && h <= C.sleepTargetMaxH) {
          fatigue -= C.fatigueSleepRelief;
        }
      } else if (tree == 'recovery') {
        fatigue -= xp * C.fatigueRecoveryReliefPerXp;
      }
      fatigue = fatigue.clamp(0, C.fatigueMax).toDouble();
    }

    final weights = C.categoryStatWeights[a.category] ?? const {};
    weights.forEach((s, w) {
      final cur = stats[s]!;
      final delta = xp * C.statGainPerXp * w * statSoftFactor(cur);
      final (nv, applied) = clampToCap(cur, delta, caps[s]!);
      stats[s] = _round3(nv);
      if (applied > 0) {
        lastGainDay[s] = day;
        peak[s] = math.max(peak[s]!, stats[s]!);
        _statTrainedToday.add(s);
      }
    });
    _checkAchievements();
  }

  /// §7 돌파 시도: 상한에 닿은 스탯에 대해 주 1회. 레거시 폼처럼 cap+20을 요청한다.
  void tryBreakthroughs() {
    for (final s in C.statKeys) {
      if (stats[s]! < caps[s]!) continue;
      if (day - (lastBreakthroughDay[s] ?? -100) < 7) continue;
      lastBreakthroughDay[s] = day;
      completions++;
      _markActive();
      final value = ability[s]!;
      if (isPr(value, bestRecord[s])) {
        bestRecord[s] = value;
        prs++;
        breakthroughs++;
        caps[s] = breakthroughNewCap(caps[s]!, caps[s]! + 20);
      } else {
        breakthroughFails++;
      }
      _checkAchievements();
    }
  }

  void _checkAchievements() {
    for (final a in C.achievements) {
      if (unlocked.contains(a.id)) continue;
      final t = a.threshold;
      final ok = switch (a.kind) {
        'completions' => completions >= t,
        'main_level' => main >= t,
        'breakthrough_success' => breakthroughs >= t,
        'stat_at_cap' => C.statKeys.any((s) => stats[s]! >= caps[s]!),
        'grade' => C.statKeys
            .any((s) => C.gradeOrder.indexOf(gradeFromCap(caps[s]!)) >= t),
        'streak' => streak >= t,
        'tree_level' => C.treeKeys.any((x) => treeLevel(x) >= t),
        'all_trees_level' => C.treeKeys.every((x) => treeLevel(x) >= t),
        'pr_count' => prs >= t,
        _ => false,
      };
      if (ok) unlocked.add(a.id);
    }
  }
}
