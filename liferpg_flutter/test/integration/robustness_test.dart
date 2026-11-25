// P3 A6: 견고성 — 잘못된 입력, 큰 값, 엔진 에러 시 상태 불변, Drift commit 원자성, 동시 액션.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/app/providers.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'support.dart';

const engine = GameEngine();
final now = DateTime(2026, 3, 2, 9);

GameState withQuests() {
  var s = GameState.initial(now);
  for (final d in const [
    QuestDraft(title: '스쿼트', type: 'Daily', category: 'Gym', measureKind: 'strength'),
    QuestDraft(title: '기상', type: 'Daily', category: 'Routine'),
    QuestDraft(
        title: '스쿼트 돌파', type: '돌파', category: '돌파', unlockStat: '힘', unlockTo: 50,
        recordKey: '스쿼트 1RM'),
  ]) {
    final r = engine.addQuest(s, d, now);
    if (!r.ok) throw StateError('${d.title}: ${r.error}');
    s = r.state;
  }
  return s;
}

void main() {
  group('잘못된 입력 → 에러, 상태 불변', () {
    late GameState s;
    setUp(() => s = withQuests());

    void expectUnchanged(EngineResult r, GameError e) {
      expect(r.error, e);
      expect(identical(r.state, s), isTrue);
      expect(r.events, isEmpty);
    }

    test('빈/공백 제목, 음수 XP, 알 수 없는 카테고리·측정치·난이도', () {
      for (final d in const [
        QuestDraft(title: '', type: 'Side'),
        QuestDraft(title: '   ', type: 'Side'),
        QuestDraft(title: 'x', type: 'Weekly'),
        QuestDraft(title: 'x', type: 'Side', baseXp: -5),
        QuestDraft(title: 'x', type: 'Side', category: 'Gaming'),
        QuestDraft(title: 'x', type: 'Side', measureKind: 'laps'),
        QuestDraft(title: 'x', type: 'Side', difficulty: 'Insane'),
        QuestDraft(title: 'x', type: 'Side', rewards: {'힘': double.infinity}),
        QuestDraft(title: 'x', type: 'Side', rewards: {'charm': 1}),
        QuestDraft(title: 'x', type: 'Side', recordKey: 'k', recordDirection: 'sideways'),
        // 돌파: 상한 이하, 기록 키 없음, 잘못된 스탯
        QuestDraft(title: 'x', type: '돌파', unlockStat: '힘', unlockTo: 30, recordKey: 'k'),
        QuestDraft(title: 'x', type: '돌파', unlockStat: '힘', unlockTo: 60),
        QuestDraft(title: 'x', type: '돌파', unlockStat: 'STR', unlockTo: 60, recordKey: 'k'),
        QuestDraft(title: 'x', type: '돌파', unlockStat: '힘', unlockTo: double.nan, recordKey: 'k'),
      ]) {
        expectUnchanged(engine.addQuest(s, d, now), GameError.invalidDraft);
      }
    });

    test('마감일 형식이 YYYY-MM-DD가 아니면 invalidDraft, 상태 불변 (N5)', () {
      for (final d in ['2026/13/45', '2026-02-30', '내일', '2026-3-2x']) {
        expectUnchanged(
            engine.addQuest(s, QuestDraft(title: 'x', type: 'Side', deadline: d), now),
            GameError.invalidDraft);
      }
      final ok = engine.addQuest(
          s, const QuestDraft(title: 'x', type: 'Side', deadline: '2026-03-31'), now);
      expect(ok.ok, isTrue);
      expect(ddayLabel(ok.quest!.deadline, '2026-03-02'), 'D-29');
      // 공백은 마감 없음
      expect(engine.addQuest(s, const QuestDraft(title: 'x', type: 'Side', deadline: '  '), now)
          .quest!.deadline, isNull);
    });

    test('측정치: 음수·NaN·무한대·종류 불일치·누락 → invalidMeasurement', () {
      for (final input in [
        const CompletionInput(),
        const CompletionInput(
            measurement: Measurement(kind: 'strength', values: {'sets': -1, 'reps': 5, 'weight_kg': 60})),
        const CompletionInput(
            measurement: Measurement(kind: 'strength', values: {'sets': double.nan})),
        const CompletionInput(
            measurement: Measurement(kind: 'strength', values: {'sets': double.infinity})),
        const CompletionInput(measurement: Measurement(kind: 'reps', values: {'sets': 1, 'reps': 1})),
      ]) {
        final r = engine.completeQuest(s, 1, input, now);
        expect(r.error, GameError.invalidMeasurement, reason: '$input');
        expect(identical(r.state, s), isTrue);
      }
      // 신규 돌파는 기록값 필수
      expect(engine.completeQuest(s, 3, CompletionInput.none, now).error,
          GameError.invalidMeasurement);
      expect(
          engine.completeQuest(s, 3, const CompletionInput(recordValue: double.nan), now).error,
          GameError.invalidMeasurement);
    });

    test('없는 퀘스트 / 이미 완료', () {
      expect(engine.completeQuest(s, 999, CompletionInput.none, now).error,
          GameError.questNotFound);
      expect(engine.deleteQuest(s, 999, now).error, GameError.questNotFound);
      expect(engine.updateProgress(s, 999, 10, now).error, GameError.questNotFound);
      final done = engine.completeQuest(s, 2, CompletionInput.none, now).state;
      final r = engine.completeQuest(done, 2, CompletionInput.none, now);
      expect(r.error, GameError.alreadyDone);
      expect(identical(r.state, done), isTrue);
    });

    test('진행률은 0~100으로 클램프', () {
      expect(engine.updateProgress(s, 1, 250, now).quest!.progress, 100);
      expect(engine.updateProgress(s, 1, -3, now).quest!.progress, 0);
    });
  });

  group('매우 큰 값', () {
    test('측정치 1e300 → raw는 상한 200, 효과 XP는 일일 상한 이내', () {
      final s = withQuests();
      final r = engine.completeQuest(
          s,
          1,
          const CompletionInput(
              measurement: Measurement(
                  kind: 'strength', values: {'sets': 1e300, 'reps': 1e300, 'weight_kg': 1e300})),
          now);
      // sets*reps*weight = Infinity (1e900) → 엔진 검증은 입력값만 isFinite 검사
      expect(r.ok, isTrue, reason: '${r.error}');
      expect(r.completion!.rawXp, GameConfig.maxRawXpPerCompletion);
      expect(r.xp, lessThanOrEqualTo(130));
    });

    test('flat baseXp 아주 큼 → raw 200으로 제한, 오버플로 없음', () {
      final r0 = engine.addQuest(GameState.initial(now),
          const QuestDraft(title: 'big', type: 'Side', category: 'Gym', baseXp: 9007199254740991,
              difficulty: 'Hard'),
          now);
      expect(r0.ok, isTrue);
      final r = engine.completeQuest(r0.state, 1, CompletionInput.none, now);
      expect(r.completion!.rawXp, 200);
    });

    test('명시 보상 1e9 → 상한에서 멈춘다', () {
      final r0 = engine.addQuest(GameState.initial(now),
          const QuestDraft(title: 'r', type: 'Side', rewards: {'힘': 1e9}), now);
      final r = engine.completeQuest(r0.state, 1, CompletionInput.none, now);
      expect(r.state.profile.stats['힘']!.value, GameConfig.defaultStatCap);
    });

    test('레거시 import: |v| > 1e9·비유한 스탯은 예외 없이 경고 + 기본값', () {
      final b = LegacyBundle(
        profileJson: '{"stats": {"힘": 1e306, "민첩": -5, "정신력": "12.5", "지구력": 1e400},'
            ' "stat_caps": {"힘": 1e306, "민첩": 1e20},'
            ' "trees": {"physical": {"xp": 9007199254740991}}}',
      );
      final r = const LegacyImporter().convert(b, now);
      final st = r.state.profile.stats;
      expect(st['힘']!.value, GameConfig.defaultStatValue);
      expect(st['힘']!.cap, GameConfig.defaultStatCap);
      expect(st['민첩']!.cap, GameConfig.defaultStatCap);
      expect(st['민첩']!.value, -5);
      expect(st['정신력']!.value, 12.5);
      expect(st['지구력']!.value, GameConfig.defaultStatValue);
      expect(r.state.profile.trees['physical']!.totalXp, 0);
      expect(r.report.warnings.any((w) => w.contains('범위 밖')), isTrue);
    });

    test('레거시 import: 1e9 이하 큰 값은 보존된다', () {
      final b = LegacyBundle(
          profileJson: jsonEncode({
        'stats': {'힘': 1e9},
        'stat_caps': {'힘': 1e9},
      }));
      final r = const LegacyImporter().convert(b, now);
      expect(r.state.profile.stats['힘']!.value, 1e9);
      expect(r.state.profile.stats['힘']!.cap, 1e9);
      expect(r.report.warnings.where((w) => w.contains('범위 밖')), isEmpty);
    });
  });

  group('Drift commit 원자성', () {
    final skip = sqliteUnavailable();

    test('이벤트 저장 중 예외 → 상태·완료 기록도 롤백', () async {
      final clock = TestClock(now);
      final repo = driftRepo(memoryDb(), clock);
      addTearDown(repo.close);
      final s0 = withQuests();
      await repo.commit(s0);

      final r = engine.completeQuest(s0, 2, CompletionInput.none, now);
      // jsonEncode 불가능한 meta → _insertEvents에서 실패
      final bad = [
        ...r.events,
        LogEvent(ts: now, type: 'system', message: 'bad', meta: {'x': Object()}),
      ];
      await expectLater(
          repo.commit(r.state, events: bad, completion: r.completion), throwsA(anything));

      expect(await repo.load(), s0, reason: '상태 롤백');
      expect(await repo.completions(), isEmpty, reason: '완료 기록 롤백');
      expect(await repo.recentEvents(), isEmpty, reason: '이벤트 롤백');

      // 이후 정상 commit은 성공
      await repo.commit(r.state, events: r.events, completion: r.completion);
      expect((await repo.load()).questById(2)!.isDone, isTrue);
      expect((await repo.completions()).single.id, 1);
    }, skip: skip);

    test('깨진 상태 JSON → load는 initial, 로그는 남는다', () async {
      final clock = TestClock(now);
      final db = memoryDb();
      final repo = driftRepo(db, clock);
      addTearDown(repo.close);
      final r = engine.addQuest(withQuests(), const QuestDraft(title: 'x', type: 'Side'), now);
      await repo.commit(r.state, events: r.events);
      await db.customStatement("UPDATE game_states SET json = '{not json'");
      final s = await repo.load();
      expect(s.quests, isEmpty);
      expect((await repo.recentEvents()).length, 1);
    }, skip: skip);
  });

  group('컨트롤러 동시 액션', () {
    ProviderContainer container(InMemoryGameRepository repo) {
      final c = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => now),
        gameRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('완료 연타(동시 2회) → 한 번만 반영', () async {
      final repo = InMemoryGameRepository(initial: withQuests(), clock: () => now);
      final c = container(repo);
      await c.read(gameControllerProvider.future);
      final ctl = c.read(gameControllerProvider.notifier);
      final rs = await Future.wait([
        ctl.completeQuest(2, CompletionInput.none),
        ctl.completeQuest(2, CompletionInput.none),
      ]);
      expect(rs.where((r) => r.ok).length, 1);
      final s = await repo.load();
      expect(s.profile.totalCompletions, 1);
      expect((await repo.completions()).length, 1);
    });

    test('서로 다른 퀘스트 동시 추가 → 둘 다 남는다', () async {
      final repo = InMemoryGameRepository(initial: GameState.initial(now), clock: () => now);
      final c = container(repo);
      await c.read(gameControllerProvider.future);
      final ctl = c.read(gameControllerProvider.notifier);
      await Future.wait([
        ctl.addQuest(const QuestDraft(title: 'A', type: 'Side')),
        ctl.addQuest(const QuestDraft(title: 'B', type: 'Side')),
      ]);
      final s = await repo.load();
      expect(s.quests.map((q) => q.title).toSet(), {'A', 'B'});
    });

    test('순차 액션은 정상', () async {
      final repo = InMemoryGameRepository(initial: withQuests(), clock: () => now);
      final c = container(repo);
      await c.read(gameControllerProvider.future);
      final ctl = c.read(gameControllerProvider.notifier);
      expect((await ctl.completeQuest(2, CompletionInput.none)).ok, isTrue);
      expect((await ctl.completeQuest(2, CompletionInput.none)).error, GameError.alreadyDone);
      expect((await repo.load()).profile.totalCompletions, 1);
      expect(
          (await repo.recentEvents()).where((e) => e.message == '퀘스트 완료: 기상').length, 1);
    });
  });
}
