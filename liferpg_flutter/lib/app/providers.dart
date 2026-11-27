import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

/// 현재 시각. 테스트에서 고정 시각으로 override.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final gameEngineProvider = Provider<GameEngine>((_) => const GameEngine());

/// 저장소. 앱은 Drift(SQLite), 테스트는 InMemory로 override.
final gameRepositoryProvider = FutureProvider<GameRepository>((ref) async {
  final repo = await openGameRepository();
  ref.onDispose(repo.close);
  return repo;
});

final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(GameController.new);

/// 최근 이벤트 200개, 최신순. 게임 상태가 바뀔 때마다 다시 읽는다.
final recentEventsProvider = FutureProvider<List<LogEvent>>((ref) async {
  await ref.watch(gameControllerProvider.future);
  final repo = await ref.watch(gameRepositoryProvider.future);
  return repo.recentEvents(limit: 200);
});

/// 붙여 넣은 글에서 JSON 객체를 꺼낸다 (```json 코드블록 또는 첫 `{` ~ 마지막 `}`).
Map<String, Object?> extractJsonObject(String text) {
  var src = text.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(src);
  if (fence != null) src = fence.group(1)!.trim();
  final a = src.indexOf('{'), b = src.lastIndexOf('}');
  if (a < 0 || b <= a) throw const FormatException('JSON 객체를 찾지 못했습니다');
  final v = jsonDecode(src.substring(a, b + 1));
  if (v is! Map) throw const FormatException('JSON 객체가 아닙니다');
  return {for (final e in v.entries) e.key.toString(): e.value as Object?};
}

/// 게임 컨트롤러. 각 액션: 엔진 호출 → 성공 시 저장 → 상태 갱신 → 결과 반환.
/// 실패(`result.error != null`)면 저장하지 않는다.
class GameController extends AsyncNotifier<GameState> {
  GameEngine get _engine => ref.read(gameEngineProvider);
  DateTime _now() => ref.read(clockProvider)();
  Future<GameRepository> get _repo => ref.read(gameRepositoryProvider.future);

  @override
  Future<GameState> build() async {
    final repo = await ref.watch(gameRepositoryProvider.future);
    final loaded = await repo.load();
    final r = ref.read(gameEngineProvider).rollover(loaded, _now());
    if (!identical(r.state, loaded)) {
      await repo.commit(r.state, events: r.events);
    }
    return r.state;
  }

  /// 액션 직렬화 큐 (동시 액션 시 갱신 유실 방지).
  Future<void> _queue = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<GameState> _latest() async {
    await future;
    return state.requireValue;
  }

  /// 액션 전에 항상 롤오버(날짜가 바뀌었으면)를 먼저 적용한다.
  Future<T> _run<T extends EngineResult>(
          T Function(GameState s, DateTime now) op) =>
      _serial(() async {
        final now = _now();
        final roll = _engine.rollover(await _latest(), now);
        final r = op(roll.state, now);
        final repo = await _repo;
        if (!r.ok) {
          if (!identical(roll.state, state.requireValue)) {
            await repo.commit(roll.state, events: roll.events);
            state = AsyncData(roll.state);
          }
          return r;
        }
        final events = [...roll.events, ...r.events];
        if (events.isEmpty && identical(r.state, state.requireValue)) return r;
        await repo.commit(r.state, events: events);
        state = AsyncData(r.state);
        return r;
      });

  Future<EngineResult> rollover() =>
      _run((s, now) => EngineResult(s)); // _run이 롤오버를 처리한다

  Future<EngineResult> addQuest(QuestDraft d) =>
      _run((s, now) => _engine.addQuest(s, d, now));

  Future<EngineResult> completeQuest(int id) =>
      _run((s, now) => _engine.completeQuest(s, id, now));

  Future<EngineResult> toggleCheckin(int id) =>
      _run((s, now) => _engine.toggleCheckin(s, id, now));

  Future<EngineResult> giveUp(int id) =>
      _run((s, now) => _engine.giveUp(s, id, now));

  Future<EngineResult> deleteQuest(int id) =>
      _run((s, now) => _engine.deleteQuest(s, id, now));

  Future<EngineResult> placeLevel(String substat, int level) =>
      _run((s, now) => _engine.placeLevel(s, substat, level, now));

  Future<EngineResult> removeSkill(int id) =>
      _run((s, now) => _engine.removeSkill(s, id, now));

  /// Claude 업데이트 파일 적용. 형식 오류는 [FormatException].
  Future<UpdateResult> applyUpdate(UpdateBundle u) =>
      _run((s, now) => _engine.applyUpdate(s, u, now));

  /// 상태 파일로 전체 복원 (백업 되돌리기).
  Future<void> restoreState(GameState restored) => _serial(() async {
        final now = _now();
        final r = _engine.rollover(restored, now);
        final repo = await _repo;
        await repo.commit(r.state, events: [
          LogEvent(
              ts: now,
              type: LogEvent.system,
              message: '상태 파일로 복원 (${restored.today})'),
          ...r.events,
        ]);
        state = AsyncData(r.state);
      });

  /// 로그 전체 삭제. 호출 쪽이 `recentEventsProvider`를 invalidate한다.
  Future<void> clearEvents() => _serial(() async {
        await _latest();
        await (await _repo).clearEvents();
      });
}
