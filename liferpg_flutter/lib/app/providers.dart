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

/// 상태 + 액션 (INTERFACES §5).
final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(GameController.new);

/// 최근 이벤트 200개, 최신순. 게임 상태가 바뀔 때마다 다시 읽는다.
final recentEventsProvider = FutureProvider<List<LogEvent>>((ref) async {
  await ref.watch(gameControllerProvider.future);
  final repo = await ref.watch(gameRepositoryProvider.future);
  return repo.recentEvents(limit: 200);
});

/// 완료 기록, 최신순. 인자는 카테고리 필터 (null이면 전체).
final completionsProvider =
    FutureProvider.family<List<Completion>, String?>((ref, category) async {
  await ref.watch(gameControllerProvider.future);
  final repo = await ref.watch(gameRepositoryProvider.future);
  return repo.completions(category: category);
});

/// 게임 컨트롤러. 각 액션: 엔진 호출 → 성공 시 repository.commit → 상태 갱신 → 결과 반환.
/// 실패(`result.error != null`)면 저장하지 않고 결과만 돌려준다.
class GameController extends AsyncNotifier<GameState> {
  GameEngine get _engine => ref.read(gameEngineProvider);
  DateTime _now() => ref.read(clockProvider)();
  Future<GameRepository> get _repo => ref.read(gameRepositoryProvider.future);

  @override
  Future<GameState> build() async {
    final repo = await ref.watch(gameRepositoryProvider.future);
    final loaded = await repo.load();
    final r = ref.read(gameEngineProvider).dailyRollover(loaded, _now());
    if (r.events.isNotEmpty || !identical(r.state, loaded)) {
      await repo.commit(r.state, events: r.events);
    }
    return r.state;
  }

  /// 액션 직렬화 큐. 모든 상태 변경(액션·rollover·import)은 한 번에 하나씩 실행되고,
  /// 각 작업은 자기 차례에서 최신 상태를 읽는다 (동시 완료·추가 시 갱신 유실 방지).
  Future<void> _queue = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  /// 큐 차례에서의 최신 상태 (첫 로딩 중이면 기다린다).
  Future<GameState> _latest() async {
    await future;
    return state.requireValue;
  }

  Future<T> _run<T extends EngineResult>(
    T Function(GameState s, DateTime now) op, {
    Completion? Function(T r)? completion,
  }) =>
      _serial(() async {
        final s = await _latest();
        final r = op(s, _now());
        if (!r.ok) return r;
        final repo = await _repo;
        await repo.commit(r.state,
            events: r.events, completion: completion?.call(r));
        state = AsyncData(r.state);
        return r;
      });

  /// 날짜가 바뀌었으면 일일 리셋 (앱 포그라운드 복귀 시).
  Future<EngineResult> dailyRollover() => _serial(() async {
        final s = await _latest();
        final r = _engine.dailyRollover(s, _now());
        if (r.events.isEmpty && identical(r.state, s)) return r;
        final repo = await _repo;
        await repo.commit(r.state, events: r.events);
        state = AsyncData(r.state);
        return r;
      });

  Future<EngineResult> addQuest(QuestDraft draft) =>
      _run((s, now) => _engine.addQuest(s, draft, now));

  /// 로그 전체 삭제 (레거시 '로그 삭제'). 상태·완료 기록은 그대로.
  /// 호출 쪽이 `recentEventsProvider`를 invalidate한다 (컨트롤러에서 하면 순환 의존).
  Future<void> clearEvents() => _serial(() async {
        await _latest();
        final repo = await _repo;
        await repo.clearEvents();
      });

  /// 오늘 XP를 0으로 (레거시 '오늘 XP 초기화').
  Future<EngineResult> resetTodayXp() =>
      _run((s, now) => _engine.resetTodayXp(s, now));

  Future<EngineResult> deleteQuest(int questId) =>
      _run((s, now) => _engine.deleteQuest(s, questId, now));

  Future<EngineResult> updateProgress(int questId, int progress) =>
      _run((s, now) => _engine.updateProgress(s, questId, progress, now));

  Future<CompletionResult> completeQuest(int questId, CompletionInput input) =>
      _run<CompletionResult>(
        (s, now) => _engine.completeQuest(s, questId, input, now),
        completion: (r) => r.completion,
      );

  /// 레거시 JSON 가져오기. 기존 데이터를 모두 대체한다.
  Future<ImportReport> importLegacy(LegacyBundle bundle) =>
      _serial(() async {
        await _latest();
        final repo = await _repo;
        final report = await repo.importLegacy(bundle, _now());
        final loaded = await repo.load();
        final r = _engine.dailyRollover(loaded, _now());
        if (r.events.isNotEmpty) await repo.commit(r.state, events: r.events);
        state = AsyncData(r.state);
        return report;
      });
}
