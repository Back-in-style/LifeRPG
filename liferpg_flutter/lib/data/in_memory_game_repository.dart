import 'package:liferpg/domain/domain.dart';

import 'game_repository.dart';
import 'legacy_importer.dart';
import 'repository_support.dart';

/// 메모리 저장소 — 위젯 테스트·UI 개발용. 앱을 끄면 사라진다.
///
/// ```dart
/// final repo = InMemoryGameRepository(
///   initial: GameState.initial(DateTime(2026, 3, 2)),
///   clock: () => DateTime(2026, 3, 2, 9),
/// );
/// ```
class InMemoryGameRepository implements GameRepository {
  /// [initial]이 없으면 첫 [load] 때 `GameState.initial(clock())`.
  /// [clock]이 없으면 `DateTime.now` (UI 개발용; 테스트에서는 고정 시각 주입).
  InMemoryGameRepository({
    GameState? initial,
    DateTime Function()? clock,
    List<LogEvent> events = const [],
    List<Completion> completions = const [],
    LegacyImporter importer = const LegacyImporter(),
  })  : _state = initial,
        _clock = clock ?? DateTime.now,
        _importer = importer,
        _events = List.of(events) {
    for (final c in completions) {
      _addCompletion(c);
    }
  }

  final DateTime Function() _clock;
  final LegacyImporter _importer;
  GameState? _state;

  /// 오래된 것 → 최신 (append 순서).
  final List<LogEvent> _events;
  final List<Completion> _completions = [];
  int _nextCompletionId = 1;
  bool _closed = false;

  /// 테스트 확인용: 저장된 commit 횟수.
  int commitCount = 0;

  Completion _addCompletion(Completion c) {
    final saved = c.id == null ? c.copyWith(id: _nextCompletionId) : c;
    if (saved.id! >= _nextCompletionId) _nextCompletionId = saved.id! + 1;
    _completions.add(saved);
    return saved;
  }

  void _checkOpen() {
    if (_closed) throw StateError('InMemoryGameRepository가 이미 닫혔다');
  }

  @override
  Future<GameState> load() async {
    _checkOpen();
    return _state ??= GameState.initial(_clock());
  }

  @override
  Future<void> commit(GameState state,
      {List<LogEvent> events = const [], Completion? completion}) async {
    _checkOpen();
    var s = carryCompletionIds(state, _state);
    if (completion != null) {
      s = linkCompletionToRecords(s, _addCompletion(completion));
    }
    _state = s;
    _events.addAll(events);
    commitCount++;
  }

  @override
  Future<List<LogEvent>> recentEvents({int limit = 200}) async {
    _checkOpen();
    final n = limit < 0 ? 0 : limit;
    return _events.reversed.take(n).toList();
  }

  @override
  Future<void> clearEvents() async {
    _checkOpen();
    _events.clear();
  }

  @override
  Future<List<Completion>> completions(
      {String? category, String? recordKey, int? limit}) async {
    _checkOpen();
    return filterCompletions(_completions,
        category: category, recordKey: recordKey, limit: limit);
  }

  @override
  Future<ImportReport> importLegacy(LegacyBundle bundle, DateTime now) async {
    _checkOpen();
    final r = _importer.convert(bundle, now);
    _state = r.state;
    _events
      ..clear()
      ..addAll(r.events);
    _completions.clear();
    _nextCompletionId = 1;
    return r.report;
  }

  @override
  Future<String> exportJson() async {
    _checkOpen();
    return encodeBackup(
      state: await load(),
      events: List.of(_events),
      completions: List.of(_completions),
      exportedAt: _clock(),
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
