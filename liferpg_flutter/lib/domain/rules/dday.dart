import '../format.dart';

/// SPEC_v1 §4.10 D-day 라벨. [today]는 `YYYY-MM-DD`.
/// 남음 → `D-3`, 당일 → `D-Day!`, 지남 → `D+2`, 없음·형식 오류 → `''`.
String ddayLabel(String? deadline, String today) {
  if (deadline == null || deadline.isEmpty) return '';
  final diff = daysBetween(today, deadline);
  if (diff == null) return '';
  if (diff > 0) return 'D-$diff';
  if (diff == 0) return 'D-Day!';
  return 'D+${diff.abs()}';
}
