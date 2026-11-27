import 'package:liferpg/domain/domain.dart';

import 'game_repository.dart';

/// 메모리 저장소 — 위젯 테스트·UI 개발용. 앱을 끄면 사라진다.
class InMemoryGameRepository implements GameRepository {
  /// [initial]이 없으면 첫 [load] 때 `GameState.initial(clock())`.
  InMemoryGameRepository({
    GameState? initial,
    DateTime Function()? clock,
    List<LogEvent> events = const [],
  })  : _state = initial,
        _clock = clock ?? DateTime.now,
        _events = List.of(events);

  final DateTime Function() _clock;
  GameState? _state;

  /// 오래된 것 → 최신.
  final List<LogEvent> _events;
  bool _closed = false;

  /// 테스트 확인용: commit 횟수.
  int commitCount = 0;

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
      {List<LogEvent> events = const []}) async {
    _checkOpen();
    _state = state;
    _events.addAll(events);
    commitCount++;
  }

  @override
  Future<List<LogEvent>> recentEvents({int limit = 200}) async {
    _checkOpen();
    return _events.reversed.take(limit < 0 ? 0 : limit).toList();
  }

  @override
  Future<void> clearEvents() async {
    _checkOpen();
    _events.clear();
  }

  @override
  Future<void> close() async => _closed = true;
}
