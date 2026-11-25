import '../game_config.dart';
import '../models/personal_record.dart';

/// §7.2 PR 판정.
/// - [best] == null: PR 아님 (기준 기록 등록), 단 [target]이 있으면 달성 시 PR.
/// - higher: `value ≥ best × (1 + 1%)`, lower: `value ≤ best × (1 − 1%)`.
bool isPr(double value, double? best, String direction, {double? target}) {
  final lower = direction == 'lower';
  if (best == null) {
    if (target == null) return false;
    return lower ? value <= target : value >= target;
  }
  const r = GameConfig.prMinImprovementRatio;
  return lower ? value <= best * (1 - r) : value >= best * (1 + r);
}

/// 기록값 [value]를 [record]에 추가한 결과. best는 첫 기록이거나 PR일 때만 갱신.
/// [record]가 null이면 [key]·[direction]·[stat]으로 새로 만든다.
({PersonalRecord record, bool isPr}) recordAfter({
  required PersonalRecord? record,
  required String key,
  required double value,
  required DateTime at,
  String direction = 'higher',
  String? stat,
  double? target,
}) {
  final rec =
      record ?? PersonalRecord(key: key, direction: direction, stat: stat);
  final pr = isPr(value, rec.best, rec.direction, target: target);
  final newBest = (rec.best == null || pr) ? value : rec.best;
  return (
    record: rec.copyWith(
      best: newBest,
      stat: rec.stat ?? stat,
      history: [...rec.history, RecordEntry(value: value, at: at, isPr: pr)],
    ),
    isPr: pr,
  );
}
