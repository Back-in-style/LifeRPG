import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

const engine = GameEngine();
final t0 = DateTime(2026, 3, 2, 9, 30, 15);

Map<String, Object?> rt(Map<String, Object?> j) =>
    (jsonDecode(jsonEncode(j)) as Map).cast<String, Object?>();

void main() {
  test('GameState JSON 왕복 (여러 액션 후)', () {
    var s = GameState.initial(t0);
    s = engine
        .addQuest(
            s,
            const QuestDraft(
                title: '스쿼트',
                type: 'Side',
                category: 'Gym',
                measureKind: 'strength',
                recordKey: 'sq',
                deadline: '2026-04-01'),
            t0)
        .state;
    s = engine
        .addQuest(
            s,
            const QuestDraft(
                title: '돌파',
                type: '돌파',
                unlockStat: '힘',
                unlockTo: 50,
                recordKey: 'sq',
                target: 100),
            t0)
        .state;
    s = engine
        .completeQuest(
            s,
            1,
            const CompletionInput(
                measurement: Measurement(
                    kind: 'strength',
                    values: {'sets': 5, 'reps': 5, 'weight_kg': 60}),
                recordValue: 60),
            t0)
        .state;
    final back = GameState.fromJson(rt(s.toJson()));
    expect(back, s);
    expect(back.hashCode, s.hashCode);
    expect(back.toJson(), s.toJson());
    expect(s.toJson()['quests'], isA<List<Object?>>());
    final q = (s.toJson()['quests'] as List).first as Map;
    expect(q['status'], 'DONE');
    expect(q['created_at'], '2026-03-02 09:30:15');
  });

  test('모든 모델 왕복', () {
    final models = <Object>[
      const StatState(
          key: '힘', value: 12.5, cap: 50, peak: 13, lastGainDate: '2026-03-01'),
      const TreeState(key: 'swim', totalXp: 321),
      const LevelInfo(level: 3, xpInLevel: 10, xpForNext: 264),
      Quest(
          id: 3,
          title: 'a',
          type: 'Main',
          category: 'Study',
          difficulty: 'Hard',
          measureKind: 'pomodoro',
          baseXp: 10,
          rewards: const {'집중': 1.5},
          deadline: '2026-05-05',
          recordKey: 'k',
          recordDirection: 'lower',
          target: 3,
          progress: 40,
          status: QuestStatus.done,
          createdAt: t0,
          completedAt: t0),
      const QuestDraft(
          title: 'd',
          type: '돌파',
          unlockStat: '힘',
          unlockTo: 50,
          recordKey: 'r'),
      const Measurement(kind: 'reps', values: {'sets': 3, 'reps': 12}),
      const CompletionInput(
          measurement: Measurement(kind: 'count', values: {'count': 2}),
          recordValue: 5),
      Completion(
          id: 9,
          questId: 3,
          questTitle: 'a',
          category: 'Gym',
          tree: 'physical',
          measureKind: 'strength',
          values: const {'sets': 1},
          rawXp: 22,
          xp: 20,
          statGains: const {'힘': 0.12},
          recordKey: 'k',
          recordValue: 61,
          isPr: true,
          at: t0),
      PersonalRecord(
          key: 'k',
          direction: 'lower',
          stat: '지구력',
          best: 590,
          history: [
            RecordEntry(value: 590, at: t0, completionId: 4, isPr: true)
          ]),
      LogEvent(ts: t0, type: 'xp', message: 'm', meta: const {
        'a': 1,
        'b': [1, 2],
        'c': {'d': 'e'}
      }),
      Profile.initial('2026-03-02').copyWith(
          rawToday: {'swim': 40},
          countToday: {'swim': 1},
          todayXp: 40,
          streakDays: 3,
          lastActiveDate: '2026-03-02',
          totalCompletions: 5,
          breakthroughSuccesses: 1,
          prCount: 2,
          fatigue: 12.5,
          graceWeekUsed: true),
    ];
    for (final m in models) {
      final json = (m as dynamic).toJson() as Map<String, Object?>;
      final Object back = switch (m) {
        StatState() => StatState.fromJson(rt(json)),
        TreeState() => TreeState.fromJson(rt(json)),
        LevelInfo() => LevelInfo.fromJson(rt(json)),
        Quest() => Quest.fromJson(rt(json)),
        QuestDraft() => QuestDraft.fromJson(rt(json)),
        Measurement() => Measurement.fromJson(rt(json)),
        CompletionInput() => CompletionInput.fromJson(rt(json)),
        Completion() => Completion.fromJson(rt(json)),
        PersonalRecord() => PersonalRecord.fromJson(rt(json)),
        LogEvent() => LogEvent.fromJson(rt(json)),
        Profile() => Profile.fromJson(rt(json)),
        _ => throw StateError('$m'),
      };
      expect(back, m, reason: m.runtimeType.toString());
      expect(back.hashCode, m.hashCode, reason: m.runtimeType.toString());
    }
  });

  test('copyWith로 nullable 필드를 null로 되돌림', () {
    final q = Quest(
        id: 1,
        title: 'a',
        type: 'Daily',
        status: QuestStatus.done,
        createdAt: t0,
        completedAt: t0,
        deadline: '2026-01-01');
    final r = q.copyWith(status: QuestStatus.active, completedAt: null);
    expect(r.completedAt, isNull);
    expect(r.deadline, '2026-01-01');
    expect(q.copyWith().completedAt, t0);
    expect(q.copyWith(deadline: null).deadline, isNull);
    expect(q.copyWith(unlockTo: 50).unlockTo, 50.0);
    const s = StatState(key: '힘', lastGainDate: 'x');
    expect(s.copyWith(lastGainDate: null).lastGainDate, isNull);
  });

  test('레거시 quests.json 항목 읽기', () {
    final normal = Quest.fromJson({
      'id': '5',
      'category': 'Gym',
      'type': 'Daily',
      'title': '스쿼트',
      'xp': 21,
      'rewards': {'힘': 1.0, '민첩': 0.0, '정신력': 0.0, '지구력': 0.5},
      'difficulty': 'Easy',
      'deadline': '',
      'progress': 0,
      'status': 'DONE',
      'created_at': '2025-01-01 10:00:00',
      'completed_at': '2025-01-02 11:00:00',
      'desc': '[Day A] 하체',
      'base_xp': 30,
    });
    expect(normal.id, 5);
    expect(normal.baseXp, 30);
    expect(normal.xp, 21);
    expect(normal.measureKind, 'flat');
    expect(normal.deadline, isNull);
    expect(normal.status, QuestStatus.done);
    expect(normal.rewards['힘'], 1.0);
    expect(normal.completedAt, DateTime(2025, 1, 2, 11));
    expect(dailyGroupOf(normal), 'grp_dayA');

    final bt = Quest.fromJson({
      'id': 6,
      'category': '돌파',
      'type': '돌파',
      'title': '돌파!',
      'xp': 0,
      'rewards': {'unlock_stat': '힘', 'unlock_to': 50.0},
      'difficulty': 'Normal',
      'deadline': null,
      'progress': 0,
      'status': 'ACTIVE',
      'created_at': '2025-01-01 10:00:00',
      'completed_at': null,
      'desc': '',
      'unlock_stat': '힘',
      'unlock_to': 50,
    });
    expect(bt.isBreakthrough, isTrue);
    expect(bt.isLegacyBreakthrough, isTrue);
    expect(bt.unlockTo, 50.0);
    expect(bt.rewards, isEmpty);
    expect(bt.xp, 0);
  });

  test('Profile.fromJson: 빠진 스탯·트리는 기본값', () {
    final p = Profile.fromJson({
      'stats': {
        '힘': {'value': 20, 'cap': 50}
      },
      'trees': {
        'physical': {'xp': 500}
      },
      'today_date': '2026-03-02',
    });
    expect(p.stats.length, 7);
    expect(p.stats['힘']!.value, 20);
    expect(p.stats['힘']!.peak, 20);
    expect(p.stats['매력'], const StatState.initial('매력'));
    expect(p.trees['physical']!.totalXp, 500);
    expect(p.trees.length, 7);
    expect(p.mainLevel, 3);
  });
}
