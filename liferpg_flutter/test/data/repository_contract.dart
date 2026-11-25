import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'fixture_loader.dart';

/// 두 구현(InMemory·Drift)이 같은 계약을 지키는지 확인하는 공용 테스트.
///
/// [create]는 빈 저장소를 만든다 (시계 주입).
void runRepositoryContract(String name,
    Future<GameRepository> Function(DateTime Function() clock) create) {
  const engine = GameEngine();
  final t0 = DateTime(2026, 3, 2, 9, 0, 0);
  var clockNow = t0;
  DateTime clock() => clockNow;

  group('$name 계약', () {
    late GameRepository repo;

    setUp(() async {
      clockNow = t0;
      repo = await create(clock);
    });
    tearDown(() => repo.close());

    test('빈 저장소 load → initial', () async {
      expect(await repo.load(), GameState.initial(t0));
      expect(await repo.recentEvents(), isEmpty);
      expect(await repo.completions(), isEmpty);
    });

    test('엔진 → commit → load 왕복, 이벤트 최신순', () async {
      var s = await repo.load();
      final add = engine.addQuest(s,
          const QuestDraft(title: '푸시업', type: 'Daily', category: 'Gym'), t0);
      expect(add.error, isNull);
      await repo.commit(add.state, events: add.events);
      s = add.state;

      final add2 = engine.addQuest(
          s,
          const QuestDraft(title: '독서', type: 'Side', category: 'Study'),
          t0.add(const Duration(minutes: 1)));
      await repo.commit(add2.state, events: add2.events);
      s = add2.state;

      final done = engine.completeQuest(s, add.quest!.id, CompletionInput.none,
          t0.add(const Duration(minutes: 5)));
      expect(done.error, isNull);
      expect(done.completion, isNotNull);
      await repo.commit(done.state,
          events: done.events, completion: done.completion);

      final loaded = await repo.load();
      expect(loaded, done.state);

      final all = [...add.events, ...add2.events, ...done.events];
      final recent = await repo.recentEvents();
      expect(recent, all.reversed.toList());
      expect(await repo.recentEvents(limit: 2), all.reversed.take(2).toList());
      expect(await repo.recentEvents(limit: 0), isEmpty);

      final comps = await repo.completions();
      expect(comps.single.id, isNotNull);
      expect(comps.single.copyWith(id: null), done.completion);
    });

    test('completions 필터·최신순·limit, 기록 항목에 completionId 연결', () async {
      var s = await repo.load();
      final a = engine.addQuest(
          s,
          const QuestDraft(
              title: '스쿼트',
              type: 'Daily',
              category: 'Gym',
              recordKey: 'squat_kg',
              recordDirection: 'higher'),
          t0);
      expect(a.error, isNull);
      s = a.state;
      final b = engine.addQuest(s,
          const QuestDraft(title: '독서', type: 'Daily', category: 'Study'), t0);
      s = b.state;
      await repo.commit(s, events: [...a.events, ...b.events]);

      for (var day = 0; day < 3; day++) {
        final at = t0.add(Duration(days: day, hours: 1));
        final r1 = engine.completeQuest(
            s, a.quest!.id, CompletionInput(recordValue: 60.0 + day * 5), at);
        expect(r1.error, isNull);
        await repo.commit(r1.state,
            events: r1.events, completion: r1.completion);
        s = r1.state;
        final r2 = engine.completeQuest(s, b.quest!.id, CompletionInput.none,
            at.add(const Duration(minutes: 1)));
        expect(r2.error, isNull);
        await repo.commit(r2.state,
            events: r2.events, completion: r2.completion);
        s = r2.state;
      }

      final all = await repo.completions();
      expect(all.length, 6);
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].at.isAfter(all[i].at) || all[i - 1].at == all[i].at,
            isTrue);
      }
      expect(all.first.questTitle, '독서');
      final gym = await repo.completions(category: 'Gym');
      expect(gym.length, 3);
      expect(gym.every((c) => c.category == 'Gym'), isTrue);
      final rec = await repo.completions(recordKey: 'squat_kg', limit: 2);
      expect(rec.map((c) => c.recordValue), [70.0, 65.0]);
      expect((await repo.completions(limit: 1)).length, 1);
      expect(all.map((c) => c.id).toSet().length, 6);

      final loaded = await repo.load();
      final history = loaded.records['squat_kg']!.history;
      expect(history.length, 3);
      final ids = {for (final c in gym) c.at: c.id};
      for (final h in history) {
        expect(h.completionId, isNotNull);
        expect(h.completionId, ids[h.at]);
      }
    });

    test('importLegacy는 기존 데이터를 대체', () async {
      final s = await repo.load();
      final add =
          engine.addQuest(s, const QuestDraft(title: '임시', type: 'Side'), t0);
      final done = engine.completeQuest(
          add.state, add.quest!.id, CompletionInput.none, t0);
      await repo.commit(done.state,
          events: [...add.events, ...done.events], completion: done.completion);

      final report = await repo.importLegacy(loadBundle('basic'), t0);
      final expected = const LegacyImporter().convert(loadBundle('basic'), t0);
      expect(report.quests, 3);
      expect(await repo.load(), expected.state);
      expect(await repo.completions(), isEmpty);
      expect(await repo.recentEvents(limit: 1000),
          expected.events.reversed.toList());
      expect(report.events, expected.events.length);

      // 이후 completion id는 1부터
      final st = await repo.load();
      final r = engine.completeQuest(st, 2, CompletionInput.none, t0);
      expect(r.error, isNull);
      await repo.commit(r.state, events: r.events, completion: r.completion);
      expect((await repo.completions()).single.id, 1);
    });

    test('clearEvents는 로그만 지운다', () async {
      final s = await repo.load();
      final add =
          engine.addQuest(s, const QuestDraft(title: '산책', type: 'Daily'), t0);
      final done = engine.completeQuest(
          add.state, add.quest!.id, CompletionInput.none, t0);
      await repo.commit(done.state,
          events: [...add.events, ...done.events], completion: done.completion);
      expect(await repo.recentEvents(), isNotEmpty);

      await repo.clearEvents();
      expect(await repo.recentEvents(), isEmpty);
      expect(await repo.load(), done.state);
      expect((await repo.completions()).length, 1);

      // 지운 뒤에도 새 이벤트는 정상 append
      final ev = LogEvent(ts: t0, type: LogEvent.system, message: '새 로그');
      await repo.commit(done.state, events: [ev]);
      expect(await repo.recentEvents(), [ev]);
      await repo.clearEvents(); // 빈 상태에서 다시 호출해도 OK
      expect(await repo.recentEvents(), isEmpty);
    });

    test('exportJson은 전체 백업', () async {
      await repo.importLegacy(loadBundle('breakthrough'), t0);
      final st = await repo.load();
      final r = engine.completeQuest(st, 7, CompletionInput.none, t0);
      await repo.commit(r.state, events: r.events, completion: r.completion);

      final json = jsonDecode(await repo.exportJson()) as Map<String, Object?>;
      expect(json['app'], 'LifeRPG');
      expect(json['format'], 1);
      expect(
          GameState.fromJson(json['state']! as Map<String, Object?>), r.state);
      final events = json['events']! as List<Object?>;
      expect(events.length, (await repo.recentEvents(limit: 10000)).length);
      expect((json['completions']! as List<Object?>).length, 1);
    });
  });
}
