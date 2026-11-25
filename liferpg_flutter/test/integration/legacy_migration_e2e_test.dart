// P3 A6: 레거시 마이그레이션 E2E — LegacyImporter → Drift commit → load → 엔진 완료 → 다시 load.
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'support.dart';

void main() {
  final skip = sqliteUnavailable();
  const engine = GameEngine();
  final bundle = realisticLegacyBundle();
  const legacyEventCount = 360 + 1; // 생성 로그 + 돌파 성공 1건

  group('레거시 E2E (Drift memory)', () {
    late TestClock clock;
    late DriftGameRepository repo;

    setUp(() {
      clock = TestClock(DateTime(2026, 3, 2, 8, 30));
      repo = driftRepo(memoryDb(), clock);
    });
    tearDown(() => repo.close());

    test('import → load: 스탯·상한·레벨·업적·로그·next_id 보존', () async {
      final report = await repo.importLegacy(bundle, clock.now);
      final s = await repo.load();
      final p = s.profile;

      // 스탯 값·상한 (레거시 4종 그대로, float 유지)
      expect(p.stats['힘']!.value, 17.35);
      expect(p.stats['힘']!.cap, 50.0);
      expect(p.stats['민첩']!.value, 12.4);
      expect(p.stats['정신력']!.value, 30.0);
      expect(p.stats['지구력']!.value, 11.007);
      for (final k in ['매력', '집중', '커뮤니케이션']) {
        expect(p.stats[k]!.value, GameConfig.defaultStatValue);
        expect(p.stats[k]!.cap, GameConfig.defaultStatCap);
      }
      expect(p.stats.length, 7);
      expect(p.trees.length, 7);

      // 트리: XP·레벨 줄지 않음 (레거시 physical Lv10)
      expect(p.trees['physical']!.totalXp, greaterThanOrEqualTo(4680));
      expect(p.treeLevel('physical').level, greaterThanOrEqualTo(10));
      // 유령 트리 mental은 버려지고 경고
      expect(report.warnings.any((w) => w.contains('mental')), isTrue);
      expect(p.mainLevel, greaterThanOrEqualTo(10));

      // 퀘스트·next_id
      expect(s.quests.map((q) => q.id), [1, 2, 3, 4, 5, 6, 8, 9]);
      expect(s.nextQuestId, 12);
      expect(s.quests.every((q) => q.measureKind == 'flat'), isTrue);
      final main5 = s.questById(5)!;
      expect(main5.xp, 70, reason: 'base_xp 없는 퀘스트도 레거시 xp 그대로');
      expect(main5.deadline, isNull, reason: "deadline '' → null");
      expect(s.questById(1)!.xp, 45);
      expect(s.questById(2)!.xp, 21);
      expect(s.questById(8)!.isLegacyBreakthrough, isTrue);
      expect(s.questById(4)!.progress, 40);

      // 업적: 레거시 해금 유지 (+ 직후 판정분)
      expect(s.unlockedAchievements,
          containsAll(['quest_10', 'first_quest', 'first_breakthrough', 'stat_max_d', 'level_5']));
      expect(report.achievements, s.unlockedAchievements.length);

      // 누적 카운터
      expect(p.totalCompletions, 45);
      expect(p.breakthroughSuccesses, 1);

      // 로그 보존: 레거시 361 + import 1 + 새 업적
      final ev = await repo.recentEvents(limit: 10000);
      expect(ev.length, report.events);
      expect(ev.length, greaterThanOrEqualTo(legacyEventCount + 1));
      final chronological = ev.reversed.toList();
      expect(chronological.first.message, startsWith('퀘스트 완료: 스쿼트 #0'));
      expect(chronological.where((e) => e.type == LogEvent.import).length, 1);
      // 기본 limit 200 = 최신 200건
      expect((await repo.recentEvents()).length, 200);
    });

    test('import → rollover → 레거시 ACTIVE 돌파 + Daily 완료 → 다시 load', () async {
      await repo.importLegacy(bundle, clock.now);
      var s = await repo.load();
      final before = s;

      // 날짜 변경: Daily DONE → ACTIVE, todayXp 0
      final roll = engine.dailyRollover(s, clock.now);
      expect(roll.events.first.message, '일일 퀘스트 초기화: 2026-03-02');
      await repo.commit(roll.state, events: roll.events);
      s = await repo.load();
      expect(s.profile.todayDate, '2026-03-02');
      expect(s.profile.todayXp, 0);
      expect(s.questById(1)!.isDone, isFalse);
      expect(s.questById(3)!.isDone, isFalse);
      expect(s.questById(6)!.isDone, isTrue, reason: '돌파 상태는 리셋 안 됨');

      // 레거시 ACTIVE 돌파 (민첩 30 → 요청 70, maxStep 20 → 50)
      clock.now = DateTime(2026, 3, 2, 9);
      final bt = engine.completeQuest(s, 8, CompletionInput.none, clock.now);
      expect(bt.ok, isTrue, reason: '${bt.error}');
      expect(bt.breakthrough!.success, isTrue);
      expect(bt.breakthrough!.newCap, 50.0);
      await repo.commit(bt.state, events: bt.events, completion: bt.completion);
      s = await repo.load();
      expect(s.profile.stats['민첩']!.cap, 50.0);
      expect(s.profile.breakthroughSuccesses, 2);

      // Daily Gym (flat, 명시 보상 힘 +0.5)
      clock.now = DateTime(2026, 3, 2, 10);
      final gym = engine.completeQuest(s, 1, CompletionInput.none, clock.now);
      expect(gym.ok, isTrue);
      expect(gym.tree, 'physical');
      expect(gym.xp, greaterThan(0));
      await repo.commit(gym.state, events: gym.events, completion: gym.completion);

      // 새 퀘스트 id는 next_id(12)부터
      final add = engine.addQuest(
          gym.state, const QuestDraft(title: '새 퀘스트', type: 'Side'), clock.now);
      expect(add.quest!.id, 12);
      await repo.commit(add.state, events: add.events);

      final after = await repo.load();
      expect(after, add.state, reason: 'commit한 상태 그대로 load');
      expect(after.nextQuestId, 13);
      // 줄어든 것 없음
      for (final k in GameConfig.statKeys) {
        expect(after.profile.stats[k]!.cap,
            greaterThanOrEqualTo(before.profile.stats[k]!.cap), reason: k);
        expect(after.profile.stats[k]!.value,
            greaterThanOrEqualTo(before.profile.stats[k]!.value), reason: k);
      }
      for (final k in GameConfig.treeKeys) {
        expect(after.profile.trees[k]!.totalXp,
            greaterThanOrEqualTo(before.profile.trees[k]!.totalXp), reason: k);
      }
      expect(after.profile.mainLevel, greaterThanOrEqualTo(before.profile.mainLevel));
      expect(after.unlockedAchievements, containsAll(before.unlockedAchievements));
      expect(after.profile.totalCompletions, before.profile.totalCompletions + 2);

      // 로그: 레거시 전부 + 새 이벤트가 뒤에 순서대로
      final ev = (await repo.recentEvents(limit: 10000)).reversed.toList();
      expect(ev.take(legacyEventCount).last.message, startsWith('돌파 성공: 힘'));
      final tail = ev.map((e) => e.message).toList();
      expect(tail.indexOf('일일 퀘스트 초기화: 2026-03-02'),
          lessThan(tail.indexOf('퀘스트 완료: 민첩 한계 돌파')));
      expect(tail.last, startsWith('퀘스트 추가: [Side] 새 퀘스트'));
      expect(tail.where((m) => m == '퀘스트 완료: [Day A] 스쿼트').length, 1,
          reason: '이벤트 중복 저장 없음');

      // 완료 기록 2건
      final comps = await repo.completions();
      expect(comps.map((c) => c.questId), [1, 8]);
    });

    test('레거시 DONE 돌파는 다시 완료할 수 없다 (alreadyDone)', () async {
      await repo.importLegacy(bundle, clock.now);
      final s = engine.dailyRollover(await repo.load(), clock.now).state;
      final r = engine.completeQuest(s, 6, CompletionInput.none, clock.now);
      expect(r.error, GameError.alreadyDone);
      expect(identical(r.state, s), isTrue);
    });

    test('같은 날 import (today_date == 오늘)면 todayXp 유지, Daily DONE 유지', () async {
      clock.now = DateTime(2026, 3, 1, 22);
      await repo.importLegacy(bundle, clock.now);
      final s = await repo.load();
      final roll = engine.dailyRollover(s, clock.now);
      expect(roll.events, isEmpty);
      expect(s.profile.todayXp, 75);
      expect(s.questById(1)!.isDone, isTrue);
    });

    test('import를 두 번 하면 이전 데이터를 대체한다 (로그 누적 없음)', () async {
      await repo.importLegacy(bundle, clock.now);
      final add = engine.addQuest(await repo.load(),
          const QuestDraft(title: 'x', type: 'Side'), clock.now);
      await repo.commit(add.state, events: add.events);
      final r2 = await repo.importLegacy(bundle, clock.now);
      final s = await repo.load();
      expect(s.questById(12), isNull);
      expect((await repo.recentEvents(limit: 10000)).length, r2.events);
    });

    test('exportJson은 import 후 상태를 담는다', () async {
      await repo.importLegacy(bundle, clock.now);
      final json = await repo.exportJson();
      expect(json, contains('"next_quest_id"'));
      expect(json, contains('민첩 한계 돌파'));
    });

    test('같은 날 import → resetTodayXp: todayXp만 0, R2 누적·스탯은 유지, 로그 1건', () async {
      clock.now = DateTime(2026, 3, 1, 22);
      await repo.importLegacy(bundle, clock.now);
      var s = await repo.load();
      expect(s.profile.todayXp, 75);
      final gym = engine.completeQuest(
          s.copyWith(quests: [
            for (final q in s.quests)
              q.id == 1 ? q.copyWith(status: QuestStatus.active) : q
          ]),
          1,
          CompletionInput.none,
          clock.now);
      await repo.commit(gym.state, events: gym.events, completion: gym.completion);
      s = await repo.load();
      final raw = s.profile.rawToday['physical'];
      expect(raw, greaterThan(0));

      final r = engine.resetTodayXp(s, clock.now);
      expect(r.ok, isTrue);
      expect(r.events.single.message, '오늘 XP 초기화');
      await repo.commit(r.state, events: r.events);
      final after = await repo.load();
      expect(after.profile.todayXp, 0);
      expect(after.profile.todayDate, '2026-03-01');
      expect(after.profile.rawToday['physical'], raw, reason: '체감 감소 우회 불가');
      expect(after.profile.trees, s.profile.trees);
      expect(after.profile.stats, s.profile.stats);

      // 날짜가 바뀐 뒤 reset하면 rollover 이벤트가 먼저
      final r2 = engine.resetTodayXp(after, DateTime(2026, 3, 2, 8));
      expect(r2.events.map((e) => e.message),
          ['일일 퀘스트 초기화: 2026-03-02', '오늘 XP 초기화']);
    });

    test('import → clearEvents: 로그만 비우고 상태·완료 기록 유지, 이후 이벤트 정상 append', () async {
      await repo.importLegacy(bundle, clock.now);
      final roll = engine.dailyRollover(await repo.load(), clock.now);
      await repo.commit(roll.state, events: roll.events);
      final bt = engine.completeQuest(roll.state, 8, CompletionInput.none, clock.now);
      await repo.commit(bt.state, events: bt.events, completion: bt.completion);
      final before = await repo.load();

      await repo.clearEvents();
      expect(await repo.recentEvents(), isEmpty);
      expect(await repo.load(), before);
      expect((await repo.completions()).single.questId, 8);

      final add = engine.addQuest(
          before, const QuestDraft(title: '로그 후', type: 'Side'), clock.now);
      await repo.commit(add.state, events: add.events);
      final ev = await repo.recentEvents();
      expect(ev.single.message, startsWith('퀘스트 추가: [Side] 로그 후'));
      expect(add.quest!.id, 12);
      final json = await repo.exportJson();
      expect(json, contains('로그 후'));
    });
  }, skip: skip);
}
