/// 레벨·스탯 규칙 (규칙서 "레벨", "스탯").
library;

import '../format.dart';
import '../models/substat.dart';
import '../sgcy_config.dart';

/// 스탯에 맞는 레벨: 스탯 ≤ 기준 스탯(L)인 가장 낮은 L.
/// 예: 10 이하 → 1, 10 초과 20 이하 → 2.
int levelForStat(double stat) {
  for (var l = SgcyConfig.minLevel; l < SgcyConfig.maxLevel; l++) {
    if (stat <= SgcyConfig.baseStat(l)) return l;
  }
  return SgcyConfig.maxLevel;
}

/// 스탯 저장 반올림 (소수 3자리).
double roundStat(double v) => roundTo(v < 0 ? 0 : v, 3);

/// 스탯 변화 결과.
class StatChange {
  const StatChange(this.after, {this.demotedFrom});
  final SubStat after;

  /// 강등됐으면 이전 레벨.
  final int? demotedFrom;
  bool get demoted => demotedFrom != null;
}

/// 강등 판정: 보호 기간이 아니고 스탯이 강등선 이하면 스탯에 맞는 레벨로.
StatChange checkDemotion(SubStat s, String today) {
  final line = s.demotionLine;
  if (line == null || s.isProtected(today) || s.stat > line) {
    return StatChange(s);
  }
  final to = levelForStat(s.stat);
  if (to >= s.level) return StatChange(s);
  return StatChange(s.copyWith(level: to), demotedFrom: s.level);
}

/// 스탯 증감. 보상(+)이면 [today]를 활동일로 기록하고, 감소(−)면 강등 판정.
StatChange changeStat(SubStat s, double delta, String today) {
  final next = s.copyWith(
    stat: roundStat(s.stat + delta),
    lastActiveDate: delta > 0 ? today : s.lastActiveDate,
  );
  return delta < 0 ? checkDemotion(next, today) : StatChange(next);
}

/// 승급: +1레벨, 스탯 = max(현재, 새 강등선 × 1.1), 보호 3일.
SubStat promote(SubStat s, String today) {
  if (s.level >= SgcyConfig.maxLevel) return s;
  final level = s.level + 1;
  final floor =
      SgcyConfig.demotionLine(level)! * SgcyConfig.promotionStatFactor;
  return s.copyWith(
    level: level,
    stat: roundStat(s.stat > floor ? s.stat : floor),
    protectedUntil: addDays(today, SgcyConfig.protectionDays),
    lastActiveDate: today,
  );
}

/// 배치(초기 판정·보정): 그 레벨의 승급 직후 상태로 둔다. 1레벨은 시작 스탯.
SubStat place(SubStat s, int level, String today) {
  final l = SgcyConfig.clampLevel(level);
  final line = SgcyConfig.demotionLine(l);
  return s.copyWith(
    level: l,
    stat: line == null
        ? SgcyConfig.initialStat
        : roundStat(line * SgcyConfig.promotionStatFactor),
    protectedUntil:
        line == null ? null : addDays(today, SgcyConfig.protectionDays),
    lastActiveDate: today,
  );
}

/// 자연 감소 대상인지: 마지막 활동일로부터 유예 일수를 넘긴 날.
/// 3일 동안 퀘스트가 없으면 4일째부터 감소.
bool decaysOn(SubStat s, String day) {
  final since = daysBetween(s.lastActiveDate, day);
  return since != null && since > SgcyConfig.decayGraceDays;
}

/// 하루 자연 감소량 = 자기 레벨 기준 스탯 × 1%.
double decayAmount(SubStat s) => s.baseStat * SgcyConfig.decayRate;

/// [total]을 [weights] 비율로 세부스탯에 나눈다.
/// 알 수 없는 키·0 이하 비율은 버리고, 남는 게 없으면 [element]의 세부스탯에 균등 분배.
Map<String, double> distribute(
    double total, Map<String, double> weights, String element) {
  final valid = <String, double>{
    for (final e in weights.entries)
      if (SgcyConfig.substatByKey.containsKey(e.key) && e.value > 0)
        e.key: e.value,
  };
  if (valid.isEmpty) {
    final subs = SgcyConfig.elementByKey[element]?.substats ?? const <String>[];
    for (final k in subs) {
      valid[k] = 1;
    }
  }
  final sum = valid.values.fold(0.0, (a, b) => a + b);
  if (sum <= 0) return const {};
  return {
    for (final e in valid.entries) e.key: roundStat(total * e.value / sum)
  };
}

/// 숫자 표시: 정수면 정수, 아니면 소수 최대 2자리 (천 단위 콤마).
String formatStat(double v) {
  final r = roundTo(v, 2);
  final neg = r < 0;
  final abs = r.abs();
  final intPart = abs.truncate();
  final frac = roundTo(abs - intPart, 2);
  final digits = intPart.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  var out = buf.toString();
  if (frac > 0) {
    final f =
        frac.toStringAsFixed(2).substring(1).replaceFirst(RegExp(r'0+$'), '');
    out += f;
  }
  return neg ? '-$out' : out;
}
