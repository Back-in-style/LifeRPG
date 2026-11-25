import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

const engine = GameEngine();
final day1 = DateTime(2026, 3, 2, 9, 0, 0);
DateTime day(int n, [int hour = 9]) => DateTime(2026, 3, 2 + n - 1, hour);

/// 퀘스트 추가 후 (state, id).
(GameState, int) addQ(GameState s, QuestDraft d, [DateTime? now]) {
  final r = engine.addQuest(s, d, now ?? day1);
  expect(r.error, isNull, reason: 'addQuest 실패: ${d.title}');
  return (r.state, r.quest!.id);
}

CompletionResult done(GameState s, int id,
    {CompletionInput input = CompletionInput.none, DateTime? now}) {
  final r = engine.completeQuest(s, id, input, now ?? day1);
  expect(r.error, isNull, reason: 'completeQuest 실패: $id');
  return r;
}

CompletionInput strength(double sets, double reps, double kg,
        {double? record}) =>
    CompletionInput(
      measurement: Measurement(
          kind: 'strength',
          values: {'sets': sets, 'reps': reps, 'weight_kg': kg}),
      recordValue: record,
    );

const gymFlat = QuestDraft(title: '푸시업', type: 'Daily', category: 'Gym');
const gymStrength = QuestDraft(
    title: '스쿼트', type: 'Side', category: 'Gym', measureKind: 'strength');

void main() {
  group('초기 상태', () {
    test('GameState.initial', () {
      final s = GameState.initial(day1);
      expect(s.profile.stats.keys, GameConfig.statKeys);
      expect(s.profile.trees.keys, GameConfig.treeKeys);
      expect(s.profile.stats['힘'], const StatState.initial('힘'));
      expect(s.profile.todayDate, '2026-03-02');
      expect(s.profile.mainLevel, 1);
      expect(s.nextQuestId, 1);
      expect(s.quests, isEmpty);
    });
  });

  group('addQuest', () {
    test('flat 퀘스트: id 증가, 레거시 로그 형식', () {
      final s0 = GameState.initial(day1);
      final r = engine.addQuest(
          s0,
          const QuestDraft(
              title: '  러닝 ',
              type: 'Side',
              category: 'Gym',
              difficulty: 'Easy',
              baseXp: 30,
              deadline: ' '),
          day1);
      expect(r.quest!.id, 1);
      expect(r.quest!.title, '러닝');
      expect(r.quest!.xp, 21);
      expect(r.quest!.deadline, isNull);
      expect(r.quest!.status, QuestStatus.active);
      expect(r.quest!.createdAt, day1);
      expect(r.state.nextQuestId, 2);
      expect(r.events.single.message, '퀘스트 추가: [Side] 러닝 (+21XP, Easy)');
      expect(r.events.single.type, 'quest');
    });

    test('돌파 퀘스트: 검증과 기록 생성', () {
      final s0 = GameState.initial(day1);
      const bt = QuestDraft(
          title: '스쿼트 돌파',
          type: '돌파',
          unlockStat: '힘',
          unlockTo: 50,
          recordKey: '스쿼트 1RM');
      final r = engine.addQuest(s0, bt, day1);
      expect(r.error, isNull);
      expect(r.quest!.category, '돌파');
      expect(r.quest!.isBreakthrough, isTrue);
      expect(r.events.single.message, '돌파 퀘스트 추가: 스쿼트 돌파');
      expect(r.state.records['스쿼트 1RM'],
          const PersonalRecord(key: '스쿼트 1RM', direction: 'higher', stat: '힘'));

      for (final bad in [
        bt.copyWith(recordKey: null),
        bt.copyWith(unlockTo: 30),
        bt.copyWith(unlockStat: 'str'),
        bt.copyWith(title: '  '),
      ]) {
        final rr = engine.addQuest(s0, bad, day1);
        expect(rr.error, GameError.invalidDraft);
        expect(identical(rr.state, s0), isTrue);
        expect(rr.events, isEmpty);
      }
      expect(engine.addQuest(s0, gymFlat.copyWith(category: 'X'), day1).error,
          GameError.invalidDraft);
      expect(engine.addQuest(s0, gymFlat.copyWith(type: 'Weekly'), day1).error,
          GameError.invalidDraft);
    });
  });

  group('completeQuest 기본', () {
    test('flat 완료 → XP·스탯·로그 순서·업적', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      final r = done(s, id);
      s = r.state;
      // raw 30, 스트릭 1 → ×1.01 = 30.3 → 30
      expect(r.xp, 30);
      expect(r.tree, 'physical');
      expect(r.completion!.rawXp, 30);
      expect(s.profile.trees['physical']!.totalXp, 30);
      expect(s.profile.todayXp, 30);
      expect(s.profile.rawToday, {'physical': 30});
      expect(s.profile.countToday, {'physical': 1});
      expect(s.profile.streakDays, 1);
      expect(s.profile.totalCompletions, 1);
      expect(r.statGains, {'힘': 0.18, '정신력': 0.03, '지구력': 0.09});
      expect(s.profile.stats['힘']!.value, 10.18);
      expect(s.profile.stats['힘']!.lastGainDate, '2026-03-02');
      expect(s.profile.stats['힘']!.peak, 10.18);
      expect(s.questById(id)!.status, QuestStatus.done);
      expect(s.questById(id)!.completedAt, day1);
      expect(r.newAchievements, ['first_quest']);
      expect(s.unlockedAchievements, {'first_quest'});
      expect(r.events.map((e) => e.message).toList(), [
        '퀘스트 완료: 푸시업',
        'PHYSICAL XP +30: 퀘스트: 푸시업',
        '스탯 상승: 힘 +0.18',
        '스탯 상승: 정신력 +0.03',
        '스탯 상승: 지구력 +0.09',
        '업적 달성: 🏁 첫 발걸음 — 첫 번째 퀘스트를 완료했다!',
      ]);
      expect(r.completion!.questId, id);
      expect(r.completion!.id, isNull);
      expect(r.completion!.at, day1);
    });

    test('레벨업 → leveledUp, 레벨업 로그, first_levelup', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = s.copyWith(
          profile: s.profile.copyWith(trees: {
        ...s.profile.trees,
        'physical': const TreeState(key: 'physical', totalXp: 190),
      }));
      final r = done(s, id);
      expect(r.leveledUp, isTrue);
      expect(r.newTreeLevel, 2);
      expect(r.state.profile.mainLevel, 2);
      expect(r.events.map((e) => e.message),
          contains('PHYSICAL 레벨업! Lv.1 → Lv.2'));
      expect(r.newAchievements, ['first_quest', 'first_levelup']);
    });

    test('이미 완료 / 없는 퀘스트 → 에러, state 그대로', () {
      final (s, id) = addQ(GameState.initial(day1), gymFlat);
      final s1 = done(s, id).state;
      final r = engine.completeQuest(s1, id, CompletionInput.none, day1);
      expect(r.error, GameError.alreadyDone);
      expect(identical(r.state, s1), isTrue);
      expect(r.events, isEmpty);
      expect(engine.completeQuest(s1, 99, CompletionInput.none, day1).error,
          GameError.questNotFound);
      expect(engine.deleteQuest(s1, 99, day1).error, GameError.questNotFound);
      expect(engine.updateProgress(s1, 99, 5, day1).error,
          GameError.questNotFound);
    });

    test('측정형인데 측정치 없음/종류 불일치/음수 → invalidMeasurement', () {
      final (s, id) = addQ(GameState.initial(day1), gymStrength);
      for (final input in [
        CompletionInput.none,
        const CompletionInput(
            measurement: Measurement(kind: 'reps', values: {'sets': 1})),
        strength(-1, 10, 10),
      ]) {
        expect(engine.completeQuest(s, id, input, day1).error,
            GameError.invalidMeasurement);
      }
    });

    test('Other 카테고리: 트리 XP 없음, 명시 보상만', () {
      final (s, id) = addQ(
          GameState.initial(day1),
          const QuestDraft(
              title: '독서',
              type: 'Side',
              category: 'Other',
              rewards: {'정신력': 1.5, '힘': 0}));
      final r = done(s, id);
      expect(r.xp, 0);
      expect(r.tree, isNull);
      expect(r.state.profile.todayXp, 0);
      expect(r.statGains, {'정신력': 1.5});
      expect(r.state.profile.stats['정신력']!.value, 11.5);
    });

    test('명시 보상에 R2 비율 적용, 음수 보상은 그대로', () {
      var s = GameState.initial(day1);
      // 오늘 physical raw 100 이미 쌓임 → 다음 raw 30은 [100,130] × 0.25, 반복 2회차 × 0.7
      s = s.copyWith(
          profile: s.profile.copyWith(
              rawToday: {'physical': 100}, countToday: {'physical': 1}));
      final (s1, id) = addQ(
          s,
          const QuestDraft(
              title: '보상',
              type: 'Side',
              category: 'Gym',
              rewards: {'힘': 2, '민첩': -1}));
      final r = done(s1, id);
      // eff4 = 30×0.25×0.7 = 5.25 → ratio 0.175 → 힘 +0.35
      expect(r.state.profile.stats['힘']!.value, 10.35);
      expect(r.state.profile.stats['민첩']!.value, 9.0);
      expect(r.statGains, {'힘': 0.35});
      expect(r.completion!.statGains, {'힘': 0.35, '민첩': -1.0});
      expect(r.xp, (5.25 * 1.01).round());
    });

    test('상한 도달 → 더 오르지 않음, stat_max_d', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = s.copyWith(
          profile: s.profile.copyWith(stats: {
        ...s.profile.stats,
        '힘': const StatState(key: '힘', value: 29.9, peak: 29.9),
      }));
      final r = done(s, id);
      expect(r.state.profile.stats['힘']!.value, 30);
      expect(r.statGains['힘'], closeTo(0.1, 1e-9));
      expect(r.newAchievements, contains('stat_max_d'));
      // 다시 하루 뒤 완료해도 힘은 30
      final r2 = done(r.state, id, now: day(2));
      expect(r2.state.profile.stats['힘']!.value, 30);
      expect(r2.statGains.containsKey('힘'), isFalse);
    });
  });

  group('체감 감소 (R2)', () {
    test('같은 날 근력 2세션: 105, 14 (+스트릭 1%)', () {
      var s = GameState.initial(day1);
      late int a, b;
      (s, a) = addQ(s, gymStrength);
      (s, b) = addQ(s, gymStrength.copyWith(title: '데드'));
      final r1 = done(s, a, input: strength(8, 10, 100)); // raw 120
      expect(r1.completion!.rawXp, 120);
      expect(r1.xp, (105 * 1.01).round()); // 106
      final r2 = done(r1.state, b, input: strength(8, 10, 100));
      expect(r2.xp, (20 * 0.7 * 1.01).round()); // 14
      expect(r2.state.profile.rawToday['physical'], 240);
      expect(r2.state.profile.countToday['physical'], 2);
      expect(r2.state.profile.trees['physical']!.totalXp, 120);
    });

    test('측정형은 난이도 무관', () {
      var s = GameState.initial(day1);
      late int a;
      (s, a) = addQ(s, gymStrength.copyWith(difficulty: 'Hard'));
      expect(done(s, a, input: strength(16, 10, 40)).completion!.rawXp, 96);
    });
  });

  group('일일 리셋', () {
    test('같은 날이면 그대로', () {
      final s = GameState.initial(day1);
      final r = engine.dailyRollover(s, day(1, 23));
      expect(identical(r.state, s), isTrue);
      expect(r.events, isEmpty);
    });

    test('다음 날: Daily 복귀·rawToday 초기화, Side는 그대로', () {
      var s = GameState.initial(day1);
      late int daily, side;
      (s, daily) = addQ(s, gymFlat);
      (s, side) = addQ(s, gymFlat.copyWith(type: 'Side', title: '사이드'));
      s = done(s, daily).state;
      s = done(s, side).state;
      expect(s.profile.rawToday['physical'], 60);

      final r = engine.dailyRollover(s, day(2, 0));
      final p = r.state.profile;
      expect(p.todayDate, '2026-03-03');
      expect(p.todayXp, 0);
      expect(p.rawToday, isEmpty);
      expect(p.countToday, isEmpty);
      expect(p.streakDays, 1); // 어제 활동 → 유지
      expect(r.state.questById(daily)!.status, QuestStatus.active);
      expect(r.state.questById(daily)!.completedAt, isNull);
      expect(r.state.questById(side)!.status, QuestStatus.done);
      expect(r.events.single.message, '일일 퀘스트 초기화: 2026-03-03');
      expect(
          p.trees['physical']!.totalXp, s.profile.trees['physical']!.totalXp);
    });

    test('completeQuest가 내부에서 리셋 → 어제 끝낸 Daily를 다시 완료', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = done(s, id).state;
      final r = done(s, id, now: day(2));
      expect(r.events.first.message, '일일 퀘스트 초기화: 2026-03-03');
      expect(r.state.profile.totalCompletions, 2);
      expect(r.state.profile.countToday['physical'], 1);
      expect(r.state.profile.streakDays, 2);
      // 스트릭 2 → 30×1.02 = 30.6 → 31
      expect(r.xp, 31);
    });
  });

  group('스트릭', () {
    test('연속 증가와 끊김', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      for (var d = 1; d <= 7; d++) {
        s = done(s, id, now: day(d)).state;
        expect(s.profile.streakDays, d);
      }
      expect(s.unlockedAchievements, contains('streak_7'));
      // 2일 쉼 → 리셋 시 0 표시, 완료 시 1
      final rolled = engine.dailyRollover(s, day(10));
      expect(rolled.state.profile.streakDays, 0);
      s = done(s, id, now: day(10)).state;
      expect(s.profile.streakDays, 1);
      expect(s.profile.lastActiveDate, '2026-03-11');
    });

    test('스트릭 보너스 최대 10%', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat.copyWith(baseXp: 50));
      s = s.copyWith(
          profile:
              s.profile.copyWith(streakDays: 30, lastActiveDate: '2026-03-01'));
      final r = done(s, id);
      expect(r.state.profile.streakDays, 31);
      expect(r.xp, 55);
    });
  });

  group('돌파 (R5)', () {
    const bt = QuestDraft(
        title: '스쿼트 돌파',
        type: '돌파',
        unlockStat: '힘',
        unlockTo: 50,
        recordKey: '스쿼트 1RM');

    test('기록값 없으면 invalidMeasurement', () {
      final (s, id) = addQ(GameState.initial(day1), bt);
      expect(engine.completeQuest(s, id, CompletionInput.none, day1).error,
          GameError.invalidMeasurement);
    });

    test('첫 기록은 실패(기준 등록), 1% 개선 시 성공', () {
      var s = GameState.initial(day1);
      late int a, b, c;
      (s, a) = addQ(s, bt);
      (s, b) = addQ(s, bt);
      (s, c) = addQ(s, bt);
      final r1 = done(s, a, input: const CompletionInput(recordValue: 80));
      expect(r1.breakthrough!.success, isFalse);
      expect(r1.breakthrough!.newCap, 30);
      expect(r1.isPr, isFalse);
      expect(r1.xp, 0);
      expect(r1.tree, isNull);
      expect(r1.state.questById(a)!.status, QuestStatus.done);
      expect(r1.state.records['스쿼트 1RM']!.best, 80);
      expect(r1.state.profile.trees['physical']!.totalXp, 0);
      expect(r1.events.map((e) => e.message), contains('돌파 실패: 힘 상한 30.0 유지'));
      expect(r1.newAchievements, isNot(contains('first_breakthrough')));

      final r2 =
          done(r1.state, b, input: const CompletionInput(recordValue: 80.5));
      expect(r2.breakthrough!.success, isFalse);
      expect(r2.state.records['스쿼트 1RM']!.best, 80);

      final r3 =
          done(r2.state, c, input: const CompletionInput(recordValue: 81));
      expect(r3.isPr, isTrue);
      expect(
          r3.breakthrough,
          const BreakthroughResult(
              stat: '힘', oldCap: 30, newCap: 50, success: true));
      final p = r3.state.profile;
      expect(p.stats['힘']!.cap, 50);
      expect(p.breakthroughSuccesses, 1);
      expect(p.prCount, 1);
      expect(p.totalCompletions, 3);
      expect(r3.state.records['스쿼트 1RM']!.best, 81);
      expect(r3.state.records['스쿼트 1RM']!.history.length, 3);
      expect(r3.events.map((e) => e.message).toList(), [
        '퀘스트 완료: 스쿼트 돌파',
        '개인기록 갱신: 스쿼트 1RM 81',
        '돌파 성공: 힘 상한 30.0 → 50.0',
        '업적 달성: 💥 한계 돌파 — 첫 돌파에 성공했다!',
        '업적 달성: 🟢 C랭크 달성 — 스탯 하나의 등급이 C가 되었다!',
        '업적 달성: 📈 신기록 — 첫 개인기록(PR)을 세웠다!',
      ]);
      expect(r3.newAchievements, ['first_breakthrough', 'rank_c', 'pr_1']);
    });

    test('target이 있으면 첫 기록으로도 성공, maxStep 제한', () {
      final (s, id) = addQ(GameState.initial(day1),
          bt.copyWith(unlockTo: 100, target: 100, recordKey: '벤치'));
      final r = done(s, id, input: const CompletionInput(recordValue: 100));
      expect(r.breakthrough!.success, isTrue);
      expect(r.breakthrough!.newCap, 50); // min(100, 30 + 20)
    });

    test('lower 방향 기록', () {
      final (s, id) = addQ(
          GameState.initial(day1),
          bt.copyWith(
              unlockStat: '지구력', recordKey: '1500m', recordDirection: 'lower'));
      var st = s.copyWith(records: {
        '1500m': const PersonalRecord(
            key: '1500m', direction: 'lower', stat: '지구력', best: 600),
      });
      final r = done(st, id, input: const CompletionInput(recordValue: 594));
      expect(r.breakthrough!.success, isTrue);
      st = r.state;
      expect(st.profile.stats['지구력']!.cap, 50);
      expect(st.records['1500m']!.best, 594);
    });

    test('레거시 ACTIVE 돌파 (record_key 없음): 값 없이 완료, maxStep 적용', () {
      var s = GameState.initial(day1);
      s = s.copyWith(quests: [
        Quest(
            id: 7,
            title: '옛 돌파',
            type: '돌파',
            category: '돌파',
            unlockStat: '민첩',
            unlockTo: 100,
            createdAt: day1),
      ], nextQuestId: 8);
      final r = done(s, 7);
      expect(
          r.breakthrough,
          const BreakthroughResult(
              stat: '민첩', oldCap: 30, newCap: 50, success: true));
      expect(r.state.profile.stats['민첩']!.cap, 50);
      expect(
          r.events.map((e) => e.message), contains('돌파 성공: 민첩 상한 30.0 → 50.0'));

      // unlock_to ≤ cap 이면 실패
      final s2 = s.copyWith(quests: [
        Quest(
            id: 7,
            title: '옛 돌파',
            type: '돌파',
            category: '돌파',
            unlockStat: '민첩',
            unlockTo: 30,
            createdAt: day1),
      ]);
      expect(done(s2, 7).breakthrough!.success, isFalse);
    });
  });

  group('일반 퀘스트 PR', () {
    test('기록 연결 → 첫 기록은 기준, 1% 개선 시 PR 보너스 +20 원시 XP', () {
      var s = GameState.initial(day1);
      late int a, b;
      final d = gymStrength.copyWith(recordKey: '벤치 1RM');
      (s, a) = addQ(s, d);
      (s, b) = addQ(s, d);
      expect(s.records['벤치 1RM']!.stat, isNull);
      final r1 = done(s, a, input: strength(5, 5, 60, record: 60)); // raw 22
      expect(r1.isPr, isFalse);
      expect(r1.completion!.rawXp, 22);
      expect(r1.completion!.recordValue, 60);
      final r2 = done(r1.state, b, input: strength(5, 5, 60, record: 61));
      expect(r2.isPr, isTrue);
      expect(r2.completion!.rawXp, 42);
      expect(r2.completion!.isPr, isTrue);
      expect(r2.state.profile.prCount, 1);
      // 반복 2회차: 42 × 0.7 × 1.01 = 29.69 → 30
      expect(r2.xp, 30);
      expect(r2.events[1].type, 'pr');
      expect(r2.newAchievements, contains('pr_1'));
    });

    test('기록값을 안 넣으면 PR 판정 없음', () {
      final (s, id) =
          addQ(GameState.initial(day1), gymStrength.copyWith(recordKey: 'k'));
      final r = done(s, id, input: strength(5, 5, 60));
      expect(r.isPr, isFalse);
      expect(r.state.records['k']!.history, isEmpty);
    });
  });

  group('QA P3', () {
    test('측정치 곱 Infinity → raw 200, 일일 상한 이내 (버그 #2)', () {
      final (s, id) = addQ(GameState.initial(day1), gymStrength);
      final r = done(s, id, input: strength(1e300, 1e300, 1e300));
      expect(r.completion!.rawXp, 200);
      expect(r.xp, lessThanOrEqualTo(130));
    });

    test('deadline 형식 검증 (N5)', () {
      final s0 = GameState.initial(day1);
      for (final bad in ['2026/04/01', '내일', '2026-02-30', '20260401']) {
        final r = engine.addQuest(s0, gymFlat.copyWith(deadline: bad), day1);
        expect(r.error, GameError.invalidDraft, reason: bad);
        expect(identical(r.state, s0), isTrue);
      }
      expect(
          engine
              .addQuest(s0, gymFlat.copyWith(deadline: ''), day1)
              .quest!
              .deadline,
          isNull);
      expect(
          engine
              .addQuest(s0, gymFlat.copyWith(deadline: ' 2026-04-01 '), day1)
              .quest!
              .deadline,
          '2026-04-01');
    });

    test('resetTodayXp: todayXp만 0, rawToday/countToday 유지', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = done(s, id).state;
      expect(s.profile.todayXp, 30);
      final r = engine.resetTodayXp(s, day(1, 12));
      expect(r.ok, isTrue);
      expect(r.state.profile.todayXp, 0);
      expect(r.state.profile.rawToday, {'physical': 30});
      expect(r.state.profile.countToday, {'physical': 1});
      expect(r.events.single.type, 'system');
      expect(r.events.single.message, '오늘 XP 초기화');
      expect(
          r.state.copyWith(profile: r.state.profile.copyWith(todayXp: 30)), s);
    });

    test('resetTodayXp: 날짜가 바뀌었으면 일일 리셋 먼저', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = done(s, id).state;
      final r = engine.resetTodayXp(s, day(2));
      expect(r.events.map((e) => e.message).toList(),
          ['일일 퀘스트 초기화: 2026-03-03', '오늘 XP 초기화']);
      expect(r.state.profile.todayDate, '2026-03-03');
      expect(r.state.profile.rawToday, isEmpty);
    });

    test('시계 역행 완료 시 스트릭 유지 (N3)', () {
      var (s, id) =
          addQ(GameState.initial(day1), gymFlat.copyWith(type: 'Side'));
      s = s.copyWith(
          profile:
              s.profile.copyWith(streakDays: 5, lastActiveDate: '2026-03-05'));
      expect(done(s, id).state.profile.streakDays, 5);
    });
  });

  group('삭제 / 진행률', () {
    test('삭제해도 누적 완료 수·XP 유지', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      s = done(s, id).state;
      final r = engine.deleteQuest(s, id, day1);
      expect(r.state.quests, isEmpty);
      expect(r.state.nextQuestId, 2);
      expect(r.state.profile.totalCompletions, 1);
      expect(r.events.single.message, '퀘스트 삭제: 푸시업');
    });

    test('진행률 클램프, 로그 없음', () {
      final (s, id) = addQ(GameState.initial(day1), gymFlat);
      final r = engine.updateProgress(s, id, 150, day1);
      expect(r.state.questById(id)!.progress, 100);
      expect(r.events, isEmpty);
      expect(engine.updateProgress(s, id, -5, day1).quest!.progress, 0);
    });
  });

  group('업적 누적 기준', () {
    test('같은 Daily를 10일 → quest_10 (누적 완료 수)', () {
      var (s, id) = addQ(GameState.initial(day1), gymFlat);
      for (var d = 1; d <= 10; d++) {
        s = done(s, id, now: day(d)).state;
      }
      expect(s.profile.totalCompletions, 10);
      expect(s.unlockedAchievements, containsAll(['first_quest', 'quest_10']));
      expect(s.unlockedAchievements, isNot(contains('quest_50')));
    });
  });

  group('순수성', () {
    test('입력 state를 바꾸지 않는다', () {
      final (s, id) = addQ(GameState.initial(day1), gymFlat);
      final before = GameState.fromJson(s.toJson());
      done(s, id);
      expect(s, before);
    });
  });
}
