import 'package:liferpg/domain/domain.dart';

import '../common/labels.dart';

/// 퀘스트 목록/상세의 보상 요약 ("XP: 30", "측정: 근력 …", "돌파: 힘 상한 → 50").
String questRewardText(Quest q) {
  if (q.isBreakthrough) {
    final to = q.unlockTo == null ? '?' : formatG(q.unlockTo!);
    return '돌파: ${q.unlockStat ?? '?'} 상한 → $to';
  }
  if (q.isFlat) return 'XP: ${q.xp}';
  return '측정: ${Labels.measureKind(q.measureKind)}';
}
