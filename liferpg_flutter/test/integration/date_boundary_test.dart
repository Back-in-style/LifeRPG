// P3 A6: 날짜 경계 — 자정 rollover, 앱 재시작(같은 날), 며칠 공백 후 복귀.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/app/providers.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'support.dart';

const engine = GameEngine();

/// Daily Gym(strength) + Daily Routine(flat) 두 개를 가진 상태.
GameState seeded(DateTime now) {
  var s = GameState.initial(now);
  s = engine
      .addQuest(
          s,
          const QuestDraft(
              title: '스쿼트', type: 'Daily', category: 'Gym', measureKind: 'strength'),
          now)
      .state;
  s = engine
      .addQuest(s, const QuestDraft(title: '기상', type: 'Daily', category: 'Routine'), now)
      .state;
  return s;
}

const strength = CompletionInput(
    measurement: Measurement(
        kind: 'strength', values: {'sets': 5, 'reps': 5, 'weight_kg': 100})); // 2500 → 37

void main() {
  group('엔진: 자정 넘김', () {
    test('23:59:59 완료 → 00:00:00 rollover: Daily 복귀, 오늘 누적 초기화, 스트릭 유지', () {
      final d1 = DateTime(2026, 3, 1, 23, 59, 59);
      var s = seeded(d1);
      final r1 = engine.completeQuest(s, 1, strength, d1);
      expect(r1.ok, isTrue);
      s = r1.state;
      expect(s.profile.rawToday['physical'], 37);
      expect(s.profile.countToday['physical'], 1);
      expect(s.profile.streakDays, 1);

      final d2 = DateTime(2026, 3, 2);
      final roll = engine.dailyRollover(s, d2);
      final p = roll.state.profile;
      expect(p.todayDate, '2026-03-02');
      expect(p.todayXp, 0);
      expect(p.rawToday, isEmpty);
      expect(p.countToday, isEmpty);
      expect(p.streakDays, 1, reason: '어제 활동 → 표시 스트릭 유지');
      expect(roll.state.questById(1)!.isDone, isFalse);
      expect(roll.state.questById(1)!.completedAt, isNull);

      // 같은 날 다시 rollover → 변화 없음
      final again = engine.dailyRollover(roll.state, DateTime(2026, 3, 2, 12));
      expect(again.events, isEmpty);
      expect(identical(again.state, roll.state), isTrue);

      // 둘째 날 완료 → 스트릭 2, 체감 감소 없이 전액
      final r2 = engine.completeQuest(roll.state, 1, strength, DateTime(2026, 3, 2, 7));
      expect(r2.state.profile.streakDays, 2);
      expect(r2.xp, (37 * 1.02).round());
    });

    test('rollover 없이 completeQuest만 호출해도 내부 rollover가 적용된다', () {
      final d1 = DateTime(2026, 3, 1, 22);
      final s = engine.completeQuest(seeded(d1), 1, strength, d1).state;
      final r = engine.completeQuest(s, 1, strength, DateTime(2026, 3, 2, 0, 0, 1));
      expect(r.ok, isTrue, reason: '전날 DONE이던 Daily도 다음 날 완료 가능');
      expect(r.events.first.message, '일일 퀘스트 초기화: 2026-03-02');
      expect(r.state.profile.countToday['physical'], 1);
    });

    test('하루 건너뛰면 rollover에서 표시 스트릭 0, 다음 완료 시 1부터', () {
      final d1 = DateTime(2026, 3, 1, 9);
      var s = seeded(d1);
      s = engine.completeQuest(s, 2, CompletionInput.none, d1).state;
      s = engine.completeQuest(s, 1, strength, DateTime(2026, 3, 2, 9)).state;
      expect(s.profile.streakDays, 2);

      final roll = engine.dailyRollover(s, DateTime(2026, 3, 4, 9));
      expect(roll.state.profile.streakDays, 0);
      final r = engine.completeQuest(roll.state, 2, CompletionInput.none, DateTime(2026, 3, 4, 9));
      expect(r.state.profile.streakDays, 1);
      expect(r.state.profile.lastActiveDate, '2026-03-04');
    });

    test('며칠 공백(10일) 후 복귀: rollover 1회, 로그 1건, Daily 전부 ACTIVE', () {
      final d1 = DateTime(2026, 3, 1, 9);
      var s = seeded(d1);
      s = engine.completeQuest(s, 1, strength, d1).state;
      s = engine.completeQuest(s, 2, CompletionInput.none, d1).state;
      final roll = engine.dailyRollover(s, DateTime(2026, 3, 11, 9));
      expect(roll.events.where((e) => e.type == LogEvent.system).length, 1);
      expect(roll.state.quests.every((q) => !q.isDone), isTrue);
      expect(roll.state.profile.streakDays, 0);
      // 스탯·트리 XP는 그대로 (R3 디트레이닝은 MVP 이후)
      expect(roll.state.profile.stats, s.profile.stats);
      expect(roll.state.profile.trees, s.profile.trees);
    });

    test('월·연 경계 (12-31 → 01-01, 02-28 → 03-01)', () {
      for (final (a, b) in [
        (DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1, 1)),
        (DateTime(2027, 2, 28, 23), DateTime(2027, 3, 1, 1)),
      ]) {
        var s = seeded(a);
        s = engine.completeQuest(s, 2, CompletionInput.none, a).state;
        final r = engine.completeQuest(s, 2, CompletionInput.none, b);
        expect(r.state.profile.streakDays, 2, reason: '$a → $b');
      }
    });
  });

  group('Drift: 앱 재시작(같은 날) 체감 감소 연속성', () {
    final skip = sqliteUnavailable();

    test('같은 날 두 번째 완료 XP = 재시작 없이 연속 완료한 XP', () async {
      final clock = TestClock(DateTime(2026, 3, 2, 8));
      final db = memoryDb();
      var repo = driftRepo(db, clock);
      final base = seeded(clock.now);
      await repo.commit(base);

      // 재시작 없는 기준
      final a1 = engine.completeQuest(base, 1, strength, clock.now);
      final a2 = engine.completeQuest(
          a1.state.copyWith(
              quests: [
                for (final q in a1.state.quests)
                  q.id == 1 ? q.copyWith(status: QuestStatus.active) : q
              ]),
          1,
          strength,
          clock.now);

      // 1회 완료 → commit → "재시작"(새 repo 객체로 load)
      final r1 = engine.completeQuest(await repo.load(), 1, strength, clock.now);
      await repo.commit(r1.state, events: r1.events, completion: r1.completion);
      repo = driftRepo(db, clock);
      final loaded = await repo.load();
      expect(loaded.profile.rawToday['physical'], 37);
      expect(loaded.profile.countToday['physical'], 1);
      expect(engine.dailyRollover(loaded, clock.now).events, isEmpty);

      // 같은 퀘스트를 ACTIVE로 되돌린 동일 조건에서 두 번째 완료
      final reopened = loaded.copyWith(quests: [
        for (final q in loaded.quests)
          q.id == 1 ? q.copyWith(status: QuestStatus.active) : q
      ]);
      final r2 = engine.completeQuest(reopened, 1, strength, clock.now);
      expect(r2.xp, a2.xp);
      expect(r2.xp, lessThan(r1.xp), reason: '반복 감쇠 0.7');
      expect(r2.state.profile.countToday['physical'], 2);
      await repo.close();
    }, skip: skip);
  });

  group('컨트롤러: 앱 시작 시 rollover', () {
    test('전날 상태로 시작하면 build()에서 rollover가 1회 저장된다', () async {
      final clock = TestClock(DateTime(2026, 3, 1, 22));
      final repo = InMemoryGameRepository(clock: clock.call);
      var s = seeded(clock.now);
      s = engine.completeQuest(s, 2, CompletionInput.none, clock.now).state;
      await repo.commit(s);

      clock.now = DateTime(2026, 3, 2, 7);
      final c = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(clock.call),
        gameRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      addTearDown(c.dispose);
      final st = await c.read(gameControllerProvider.future);
      expect(st.profile.todayDate, '2026-03-02');
      expect(st.questById(2)!.isDone, isFalse);
      expect((await repo.load()).profile.todayDate, '2026-03-02', reason: '저장까지');

      // 포그라운드 복귀(같은 날) → 이벤트 없음, 중복 저장 없음
      final r = await c.read(gameControllerProvider.notifier).dailyRollover();
      expect(r.events, isEmpty);
      final resets = (await repo.recentEvents())
          .where((e) => e.message.startsWith('일일 퀘스트 초기화'))
          .length;
      expect(resets, 1);

      // 자정 넘어 복귀 → 다시 1회
      clock.now = DateTime(2026, 3, 3, 0, 5);
      await c.read(gameControllerProvider.notifier).dailyRollover();
      expect(c.read(gameControllerProvider).requireValue.profile.todayDate, '2026-03-03');
    });
  });
}
