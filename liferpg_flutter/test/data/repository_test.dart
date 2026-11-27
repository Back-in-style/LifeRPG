import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/data/db/app_database.dart';
import 'package:liferpg/data/db/drift_game_repository.dart';
import 'package:liferpg/domain/domain.dart';

final DateTime now = DateTime(2026, 11, 26, 9);

void contract(String name, Future<GameRepository> Function() open) {
  group(name, () {
    late GameRepository repo;
    setUp(() async => repo = await open());
    tearDown(() => repo.close());

    test('비어 있으면 초기 상태', () async {
      final s = await repo.load();
      expect(s, GameState.initial(now));
    });

    test('commit → load 왕복, 이벤트 최신순', () async {
      const engine = GameEngine();
      var s = await repo.load();
      final r = engine.addQuest(
          s,
          const QuestDraft(kind: QuestKind.weekly, title: 'w', element: 'gi'),
          now);
      await repo.commit(r.state, events: r.events);
      s = r.state;
      final r2 = engine.placeLevel(s, 'focus', 4, now);
      await repo.commit(r2.state, events: r2.events);
      expect(await repo.load(), r2.state);
      final ev = await repo.recentEvents();
      expect(ev.length, 2);
      expect(ev.first.type, LogEvent.level);
      expect(await repo.recentEvents(limit: 1), hasLength(1));
      await repo.clearEvents();
      expect(await repo.recentEvents(), isEmpty);
      expect(await repo.load(), r2.state);
    });
  });
}

void main() {
  contract('InMemory', () async => InMemoryGameRepository(clock: () => now));
  contract(
      'Drift',
      () async => DriftGameRepository(AppDatabase(NativeDatabase.memory()),
          clock: () => now));

  test('Drift: v1 상태 JSON은 무시하고 새로 시작', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.gameStates).insert(GameStatesCompanion.insert(
        id: const Value(1), json: '{"profile":{"stats":{}}}', updatedAt: 'x'));
    final repo = DriftGameRepository(db, clock: () => now);
    expect(await repo.load(), GameState.initial(now));
    await repo.close();
  });
}
