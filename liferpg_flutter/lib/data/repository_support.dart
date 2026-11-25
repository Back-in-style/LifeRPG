// 저장소 구현 공용 헬퍼 (배럴에서 export하지 않는다).
import 'dart:convert';

import 'package:liferpg/domain/domain.dart';

/// 백업 JSON 형식 버전.
const int backupFormatVersion = 1;

/// [completion](id 부여됨)을 가리키는 기록 항목에 completionId를 채운다.
///
/// 엔진은 `RecordEntry.completionId`를 null로 둔다 (INTERFACES §7). 같은 recordKey의
/// history 중 completionId가 null이고 시각·값이 같은 항목을 찾는다.
GameState linkCompletionToRecords(GameState state, Completion completion) {
  final key = completion.recordKey;
  final id = completion.id;
  if (key == null || id == null) return state;
  final rec = state.records[key];
  if (rec == null) return state;
  var changed = false;
  final history = <RecordEntry>[];
  for (final e in rec.history) {
    if (!changed &&
        e.completionId == null &&
        e.at == completion.at &&
        (completion.recordValue == null || e.value == completion.recordValue)) {
      changed = true;
      history.add(e.copyWith(completionId: id));
    } else {
      history.add(e);
    }
  }
  if (!changed) return state;
  return state.copyWith(
      records: {...state.records, key: rec.copyWith(history: history)});
}

/// 호출자가 가진 상태는 이전 commit에서 채운 completionId를 모른다 (commit은 void).
/// 저장돼 있던 [prev]의 기록 항목 중 시각·값이 같은 것의 completionId를 [next]로 옮긴다.
GameState carryCompletionIds(GameState next, GameState? prev) {
  if (prev == null || prev.records.isEmpty || next.records.isEmpty) return next;
  var changed = false;
  final records = <String, PersonalRecord>{};
  for (final e in next.records.entries) {
    final old = prev.records[e.key];
    if (old == null || e.value.history.every((h) => h.completionId != null)) {
      records[e.key] = e.value;
      continue;
    }
    final ids = <(DateTime, double), int>{
      for (final h in old.history)
        if (h.completionId != null) (h.at, h.value): h.completionId!,
    };
    var recChanged = false;
    final history = [
      for (final h in e.value.history)
        if (h.completionId == null && ids.containsKey((h.at, h.value)))
          h.copyWith(completionId: ids[(h.at, h.value)])
        else
          h,
    ];
    for (var i = 0; i < history.length; i++) {
      if (!identical(history[i], e.value.history[i])) recChanged = true;
    }
    records[e.key] = recChanged ? e.value.copyWith(history: history) : e.value;
    changed |= recChanged;
  }
  return changed ? next.copyWith(records: records) : next;
}

/// 완료 목록 필터 (최신순 정렬 후 limit).
List<Completion> filterCompletions(Iterable<Completion> all,
    {String? category, String? recordKey, int? limit}) {
  final list = [
    for (final c in all)
      if ((category == null || c.category == category) &&
          (recordKey == null || c.recordKey == recordKey))
        c,
  ]..sort((a, b) {
      final t = b.at.compareTo(a.at);
      return t != 0 ? t : (b.id ?? 0).compareTo(a.id ?? 0);
    });
  return limit == null || list.length <= limit ? list : list.sublist(0, limit);
}

/// 전체 백업 JSON 문자열.
String encodeBackup({
  required GameState state,
  required List<LogEvent> events,
  required List<Completion> completions,
  required DateTime exportedAt,
}) =>
    const JsonEncoder.withIndent('  ').convert({
      'app': 'LifeRPG',
      'format': backupFormatVersion,
      'exported_at': formatTimestamp(exportedAt),
      'state': state.toJson(),
      'events': [for (final e in events) e.toJson()],
      'completions': [for (final c in completions) c.toJson()],
    });
