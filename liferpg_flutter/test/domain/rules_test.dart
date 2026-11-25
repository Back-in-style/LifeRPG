import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

Quest _q({
  String type = 'Daily',
  String category = 'Other',
  String title = 't',
  String desc = '',
  Map<String, double> rewards = const {},
}) =>
    Quest(
      id: 1,
      title: title,
      desc: desc,
      type: type,
      category: category,
      rewards: rewards,
      createdAt: DateTime(2026),
    );

void main() {
  group('xp_formula', () {
    test('measureBaseXp 예시 (GAME_DESIGN §3.1)', () {
      expect(measureBaseXp('duration_min', {'minutes': 30}), 30);
      expect(measureBaseXp('distance_km', {'km': 5}), 50);
      expect(measureBaseXp('swim_m', {'meters': 1500}), closeTo(60, 1e-9));
      expect(
          measureBaseXp('strength', {'sets': 16, 'reps': 10, 'weight_kg': 40}),
          closeTo(96, 1e-9));
      expect(measureBaseXp('reps', {'sets': 5, 'reps': 20}), closeTo(30, 1e-9));
      expect(measureBaseXp('pomodoro', {'count': 4}), 48);
      expect(measureBaseXp('steps', {'steps': 10000}), closeTo(30, 1e-9));
      expect(measureBaseXp('count', {'count': 3}), 30);
      expect(measureBaseXp('flat', {}, flatXp: 45), 45);
    });

    test('수면 XP (§3.2)', () {
      expect(measureBaseXp('sleep_h', {'hours': 6}), closeTo(34.2857, 1e-3));
      expect(measureBaseXp('sleep_h', {'hours': 8}), 40);
      expect(measureBaseXp('sleep_h', {'hours': 10}), 30);
      expect(measureBaseXp('sleep_h', {'hours': 13}), 0);
      expect(measureBaseXp('sleep_h', {'hours': 20}), 0);
    });

    test('rawXp: 상한 200, 최소 1, 측정형 난이도 무시', () {
      expect(rawXp('swim_m', {'meters': 6000}, 'Normal'), 200);
      expect(rawXp('duration_min', {'minutes': 0}, 'Normal'), 1);
      final v = {'sets': 16.0, 'reps': 10.0, 'weight_kg': 40.0};
      expect(rawXp('strength', v, 'Easy'), 96);
      expect(rawXp('strength', v, 'Hard'), 96);
      expect(rawXp('flat', {}, 'Hard', flatXp: 45), 45);
      expect(rawXp('flat', {}, 'Hard', flatXp: 500), 200);
      // QA 버그 #2: 곱이 Infinity/NaN이어도 예외 없음
      expect(
          rawXp('strength', {'sets': 1e300, 'reps': 1e300, 'weight_kg': 1e300},
              'Normal'),
          200);
      expect(
          rawXp('strength', {'sets': 1e300, 'reps': 1e300, 'weight_kg': 0},
              'Normal'),
          1);
    });

    test('adjustedFlatXp (레거시 adj_xp)', () {
      expect(adjustedFlatXp(30, 'Easy'), 21);
      expect(adjustedFlatXp(30, 'Hard'), 45);
      expect(adjustedFlatXp(3, 'Easy'), 2);
      expect(adjustedFlatXp(10, 'Easy'), 7);
      expect(adjustedFlatXp(0, 'Normal'), 1);
      expect(adjustedFlatXp(30, '??'), 30);
    });
  });

  group('diminishing', () {
    test('구간 감쇠 (§4.1, §4.3)', () {
      expect(diminish('physical', 0, 96), 96);
      expect(diminish('physical', 0, 120), 105);
      expect(diminish('physical', 120, 120), 20);
      expect(diminish('swim', 0, 80), 80);
      expect(diminish('swim', 80, 80), 20);
      expect(diminish('recovery', 40, 40), 30);
      expect(diminish('study', 300, 50), 0);
    });

    test('일일 최대치', () {
      expect(diminish('study', 0, 1000), 110);
      expect(diminish('physical', 0, 1000), 125);
      expect(diminish('routine', 0, 1000), 80);
    });

    test('repeatMultiplier', () {
      expect(repeatMultiplier(1), 1.0);
      expect(repeatMultiplier(2), closeTo(0.7, 1e-12));
      expect(repeatMultiplier(3), closeTo(0.49, 1e-12));
      expect(repeatMultiplier(4), 0.4);
      expect(repeatMultiplier(10), 0.4);
    });
  });

  group('leveling', () {
    test('need / 누적 표 (§5.1)', () {
      expect(xpToNext(1), 200);
      expect(xpToNext(2), 230);
      expect(xpToNext(3), 264);
      expect(xpToNext(5), 350);
      expect(cumulativeXpForLevel(1), 0);
      expect(cumulativeXpForLevel(2), 200);
      expect(cumulativeXpForLevel(5), 998);
      expect(cumulativeXpForLevel(10), 3357);
      expect(cumulativeXpForLevel(30), 75432);
    });

    test('levelFromXp', () {
      expect(levelFromXp(0),
          const LevelInfo(level: 1, xpInLevel: 0, xpForNext: 200));
      expect(levelFromXp(199).level, 1);
      expect(levelFromXp(200),
          const LevelInfo(level: 2, xpInLevel: 0, xpForNext: 230));
      expect(levelFromXp(1280),
          const LevelInfo(level: 5, xpInLevel: 282, xpForNext: 350));
      expect(levelFromXp(1 << 40).level, GameConfig.treeLevelMax);
      expect(levelFromXp(100).progress, 0.5);
    });

    test('mainLevel / gradeFromCap', () {
      expect(mainLevel([1, 1, 1, 1, 1, 1, 1]), 1);
      expect(mainLevel([11, 6, 6, 10, 9, 3, 9]), 48);
      expect(gradeFromCap(30), 'D');
      expect(gradeFromCap(30.5), 'C');
      expect(gradeFromCap(50), 'C');
      expect(gradeFromCap(100), 'B');
      expect(gradeFromCap(200), 'A');
      expect(gradeFromCap(201), 'S');
    });
  });

  group('legacy_convert (§5.3 표)', () {
    test('레거시 레벨', () {
      expect(legacyLevelFromXp(1280),
          const LevelInfo(level: 5, xpInLevel: 0, xpForNext: 520));
      expect(legacyLevelFromXp(4680).level, 10);
    });
    test('변환', () {
      expect(convertLegacyTreeXp(0), 0);
      expect(convertLegacyTreeXp(200), 200);
      expect(convertLegacyTreeXp(1280), 1280);
      expect(convertLegacyTreeXp(4680), 4680);
      expect(convertLegacyTreeXp(10000), 10000);
      expect(convertLegacyTreeXp(30000), 45549);
      expect(levelFromXp(45549).level, 26);
    });
  });

  group('stats', () {
    test('statSoftFactor', () {
      expect(statSoftFactor(10), 1.0);
      expect(statSoftFactor(5), 1.0);
      expect(statSoftFactor(30), closeTo(40 / 60, 1e-12));
      expect(statSoftFactor(50), 0.5);
    });

    test('clampToCap (레거시)', () {
      expect(clampToCap(10, 0, 30), (value: 10.0, applied: 0.0));
      expect(clampToCap(10, 5, 30), (value: 15.0, applied: 5.0));
      expect(clampToCap(28, 5, 30), (value: 30.0, applied: 2.0));
      expect(clampToCap(35, 1, 30), (value: 30.0, applied: 0.0));
      expect(clampToCap(10, -2, 30), (value: 8.0, applied: -2.0));
    });

    test('applyStatDelta: cur ≥ cap이면 양수 무시 (§6.2)', () {
      expect(applyStatDelta(35, 1, 30), (value: 35.0, applied: 0.0));
      expect(applyStatDelta(30, 1, 30), (value: 30.0, applied: 0.0));
      expect(applyStatDelta(35, -1, 30), (value: 30.0, applied: 0.0));
    });

    test('statGainsFor 자동 성장 / 명시 보상 / 돌파', () {
      final stats = {
        for (final k in GameConfig.statKeys) k: StatState.initial(k),
      };
      final auto =
          statGainsFor(quest: _q(category: 'Gym'), xp: 101, stats: stats);
      expect(auto['힘'], closeTo(0.606, 1e-9));
      expect(auto['지구력'], closeTo(0.303, 1e-9));
      expect(auto['정신력'], closeTo(0.101, 1e-9));
      expect(auto.containsKey('민첩'), isFalse);

      final at30 = {...stats, '힘': const StatState(key: '힘', value: 30)};
      expect(
          statGainsFor(quest: _q(category: 'Gym'), xp: 101, stats: at30)['힘'],
          closeTo(0.404, 1e-9));

      final explicit = statGainsFor(
          quest: _q(category: 'Gym', rewards: {'힘': 2, '민첩': -1, '정신력': 0}),
          xp: 50,
          stats: stats,
          rewardRatio: 0.5);
      expect(explicit, {'힘': 1.0, '민첩': -1.0});

      expect(statGainsFor(quest: _q(category: 'Other'), xp: 30, stats: stats),
          isEmpty);
      expect(
          statGainsFor(
              quest: _q(type: '돌파', category: '돌파'), xp: 30, stats: stats),
          isEmpty);
    });
  });

  group('records', () {
    test('isPr (§7.2)', () {
      expect(isPr(80, null, 'higher'), isFalse);
      expect(isPr(80, null, 'higher', target: 80), isTrue);
      expect(isPr(79, null, 'higher', target: 80), isFalse);
      // 정확히 1%는 공식(≥)상 PR. GAME_DESIGN 예시 '80.8 ✗'와 다름 (sim과 일치).
      expect(isPr(80.7, 80, 'higher'), isFalse);
      expect(isPr(80.8, 80, 'higher'), isTrue);
      expect(isPr(81, 80, 'higher'), isTrue);
      expect(isPr(594, 600, 'lower'), isTrue);
      expect(isPr(595, 600, 'lower'), isFalse);
      expect(isPr(590, null, 'lower', target: 600), isTrue);
    });

    test('recordAfter: 첫 기록은 best 등록, PR일 때만 best 갱신', () {
      final t = DateTime(2026, 1, 1);
      final r1 =
          recordAfter(record: null, key: 'sq', value: 80, at: t, stat: '힘');
      expect(r1.isPr, isFalse);
      expect(r1.record.best, 80);
      expect(r1.record.stat, '힘');
      final r2 = recordAfter(record: r1.record, key: 'sq', value: 80.5, at: t);
      expect(r2.isPr, isFalse);
      expect(r2.record.best, 80);
      final r3 = recordAfter(record: r2.record, key: 'sq', value: 81, at: t);
      expect(r3.isPr, isTrue);
      expect(r3.record.best, 81);
      expect(r3.record.history.map((e) => e.isPr), [false, false, true]);
    });
  });

  group('breakthrough', () {
    test('breakthroughNewCap (§7.3 예시)', () {
      expect(breakthroughNewCap(30, 50), 50);
      expect(breakthroughNewCap(50, 100), 75);
      expect(breakthroughNewCap(200, 300), 300);
      expect(breakthroughNewCap(30, 100), 50);
    });

    test('resolveBreakthrough', () {
      expect(
          resolveBreakthrough(
              stat: '힘', cap: 30, requestedCap: 50, prAchieved: true),
          const BreakthroughResult(
              stat: '힘', oldCap: 30, newCap: 50, success: true));
      expect(
          resolveBreakthrough(
                  stat: '힘', cap: 30, requestedCap: 50, prAchieved: false)
              .newCap,
          30);
      expect(
          resolveBreakthrough(
                  stat: '힘', cap: 50, requestedCap: 50, prAchieved: true)
              .success,
          isFalse);
    });
  });

  group('streak', () {
    test('markActive', () {
      expect(
          markActive(streakDays: 0, lastActiveDate: null, today: '2026-01-05'),
          (streakDays: 1, lastActiveDate: '2026-01-05'));
      expect(
          markActive(
              streakDays: 3, lastActiveDate: '2026-01-04', today: '2026-01-05'),
          (streakDays: 4, lastActiveDate: '2026-01-05'));
      expect(
          markActive(
              streakDays: 3, lastActiveDate: '2026-01-05', today: '2026-01-05'),
          (streakDays: 3, lastActiveDate: '2026-01-05'));
      expect(
          markActive(
                  streakDays: 3,
                  lastActiveDate: '2026-01-02',
                  today: '2026-01-05')
              .streakDays,
          1);
      // QA N3: 시계 역행 (마지막 활동이 미래) → 유지
      expect(
          markActive(
              streakDays: 3, lastActiveDate: '2026-01-07', today: '2026-01-05'),
          (streakDays: 3, lastActiveDate: '2026-01-07'));
      // 월 경계
      expect(
          markActive(
                  streakDays: 3,
                  lastActiveDate: '2026-02-28',
                  today: '2026-03-01')
              .streakDays,
          4);
    });

    test('streakOnRollover', () {
      expect(
          streakOnRollover(
              streakDays: 5, lastActiveDate: '2026-01-04', today: '2026-01-05'),
          5);
      expect(
          streakOnRollover(
              streakDays: 5, lastActiveDate: '2026-01-03', today: '2026-01-05'),
          0);
      expect(
          streakOnRollover(
              streakDays: 0, lastActiveDate: null, today: '2026-01-05'),
          0);
    });

    test('streakBonus', () {
      expect(streakBonus(0), 0);
      expect(streakBonus(5), closeTo(0.05, 1e-12));
      expect(streakBonus(30), 0.10);
    });
  });

  group('daily_group (§2.3)', () {
    test('우선순위', () {
      expect(dailyGroupOf(_q(desc: '[Day A] 등', category: 'Swim')), 'grp_dayA');
      expect(dailyGroupOf(_q(desc: '[Day B] 가슴')), 'grp_dayB');
      expect(dailyGroupOf(_q(desc: '[수영 데이]')), 'grp_swim');
      expect(dailyGroupOf(_q(category: 'Swim')), 'grp_swim');
      expect(dailyGroupOf(_q(category: 'Gym', title: '공부')), 'grp_core');
      expect(dailyGroupOf(_q(category: 'Study')), 'grp_study');
      expect(dailyGroupOf(_q(category: 'Routine')), 'grp_routine');
      expect(dailyGroupOf(_q(category: 'Social', title: '기상')), 'grp_social');
      expect(
          dailyGroupOf(_q(category: 'Mobility', title: '강의 복습')), 'grp_study');
      expect(dailyGroupOf(_q(category: 'Recovery', title: '취침 11시')),
          'grp_routine');
      expect(dailyGroupOf(_q(category: 'Other', title: '산책')), 'grp_etc');
      expect(dailyGroupOf(_q(desc: ' [Day A]')), 'grp_etc');
    });
  });

  group('dday (SPEC §4.10)', () {
    test('라벨', () {
      expect(ddayLabel(null, '2026-01-05'), '');
      expect(ddayLabel('', '2026-01-05'), '');
      expect(ddayLabel('2026-01-08', '2026-01-05'), 'D-3');
      expect(ddayLabel('2026-01-05', '2026-01-05'), 'D-Day!');
      expect(ddayLabel('2026-01-03', '2026-01-05'), 'D+2');
      expect(ddayLabel('2026/01/03', '2026-01-05'), '');
      expect(ddayLabel('2026-02-30', '2026-01-05'), '');
    });
  });

  group('fatigue / detraining (MVP 이후)', () {
    test('fatigueMultiplier', () {
      expect(fatigueMultiplier(0), 1);
      expect(fatigueMultiplier(40), 1);
      expect(fatigueMultiplier(100), closeTo(0.6, 1e-12));
      expect(fatigueMultiplier(48.5), closeTo(1 - 0.4 * 8.5 / 60, 1e-12));
    });
    test('detrainStep', () {
      expect(detrainFloor(40), 34);
      expect(detrainStep(40, 40, 7), 40);
      expect(detrainStep(40, 40, 8), 39.88);
      expect(detrainStep(34, 40, 30), 34);
    });
  });

  group('format', () {
    test('formatG / pyFloat / 날짜', () {
      expect(formatG(0.606), '0.606');
      expect(formatG(1.0), '1');
      expect(formatG(0.1 + 0.2), '0.3');
      expect(formatG(1234567), '1.23457e+06');
      expect(formatG(0.00001234), '1.234e-05');
      expect(formatG(-2), '-2');
      expect(pyFloat(30), '30.0');
      expect(pyFloat(37.5), '37.5');
      expect(dateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(formatTimestamp(DateTime(2026, 3, 7, 9, 5, 1, 500)),
          '2026-03-07 09:05:01');
      expect(
          parseTimestamp('2026-03-07 09:05:01'), DateTime(2026, 3, 7, 9, 5, 1));
      expect(daysBetween('2026-12-31', '2027-01-01'), 1);
      expect(addDays('2026-03-01', -1), '2026-02-28');
      // QA 버그 #3: 큰 값·비유한값은 그대로
      expect(roundTo(10.12345), 10.123);
      expect(roundTo(1e20), 1e20);
      expect(roundTo(1e306), 1e306);
      expect(roundTo(-1e306), -1e306);
      expect(roundTo(double.infinity), double.infinity);
      expect(roundTo(double.nan).isNaN, isTrue);
    });
  });
}
