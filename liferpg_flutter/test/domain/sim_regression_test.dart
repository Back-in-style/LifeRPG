// tool/sim/sim_engine.dart(참조 구현)과 같은 입력 → 같은 출력인지 확인.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

import '../../tool/sim/personas.dart' as sim;
import '../../tool/sim/sim_engine.dart' as sim;

void main() {
  group('규칙 함수 = sim', () {
    test('measureBaseXp / rawXp', () {
      final cases = <(String, Map<String, double>)>[
        ('duration_min', {'minutes': 37}),
        ('distance_km', {'km': 5.3}),
        ('swim_m', {'meters': 1750}),
        ('swim_m', {'meters': 9000}),
        ('strength', {'sets': 16, 'reps': 10, 'weight_kg': 43.7}),
        ('reps', {'sets': 4, 'reps': 13}),
        ('pomodoro', {'count': 5}),
        ('sleep_h', {'hours': 5.5}),
        ('sleep_h', {'hours': 7.8}),
        ('sleep_h', {'hours': 11.2}),
        ('steps', {'steps': 12345}),
        ('count', {'count': 2}),
        ('duration_min', {}),
      ];
      for (final (k, m) in cases) {
        expect(measureBaseXp(k, m), sim.measureBaseXp(k, m), reason: '$k $m');
        for (final d in ['Easy', 'Normal', 'Hard']) {
          expect(rawXp(k, m, d), sim.rawXp(k, m, d), reason: '$k $m $d');
        }
      }
      for (final f in [0, 1, 21, 45, 199, 250]) {
        expect(rawXp('flat', {}, 'Normal', flatXp: f),
            sim.rawXp('flat', {}, 'Normal', flatXp: f));
      }
    });

    test('diminish / repeatMultiplier', () {
      for (final t in GameConfig.treeKeys) {
        for (final a in [0, 30, 59, 60, 79, 80, 99, 100, 150, 199, 200, 260]) {
          for (final r in [1, 20, 45, 96, 120, 200]) {
            expect(diminish(t, a, r), sim.diminish(t, a, r),
                reason: '$t $a $r');
          }
        }
      }
      for (var n = 1; n <= 8; n++) {
        expect(repeatMultiplier(n), sim.repeatMultiplier(n));
      }
    });

    test('레벨·레거시 변환', () {
      for (var l = 1; l <= 40; l++) {
        expect(xpToNext(l), sim.xpToNext(l));
        expect(cumulativeXpForLevel(l), sim.cumulativeXpForLevel(l));
      }
      for (final x in [0, 1, 199, 200, 999, 1280, 4680, 10000, 30000, 77777]) {
        final (lv, inLv, next) = sim.levelFromXp(x);
        expect(levelFromXp(x),
            LevelInfo(level: lv, xpInLevel: inLv, xpForNext: next));
        final (llv, lin, lnext) = sim.legacyLevelFromXp(x);
        expect(legacyLevelFromXp(x),
            LevelInfo(level: llv, xpInLevel: lin, xpForNext: lnext));
        expect(convertLegacyTreeXp(x), sim.convertLegacyTreeXp(x));
      }
      expect(mainLevel([3, 1, 4, 1, 5, 9, 2]),
          sim.mainLevel([3, 1, 4, 1, 5, 9, 2]));
    });

    test('스탯·등급·돌파·PR·스트릭·피로도', () {
      for (final v in [5.0, 10, 17.3, 30, 49.9, 120]) {
        expect(statSoftFactor(v.toDouble()), sim.statSoftFactor(v.toDouble()));
        expect(gradeFromCap(v.toDouble()), sim.gradeFromCap(v.toDouble()));
        expect(fatigueMultiplier(v.toDouble()),
            sim.fatigueMultiplier(v.toDouble()));
      }
      for (final (c, d, cap) in [
        (10.0, 0.0, 30.0),
        (10.0, 0.5, 30.0),
        (29.8, 0.5, 30.0),
        (12.0, -1.0, 30.0),
      ]) {
        final (v, a) = sim.clampToCap(c, d, cap);
        expect(clampToCap(c, d, cap), (value: v, applied: a));
      }
      for (final (c, r) in [
        (30.0, 50.0),
        (50.0, 100.0),
        (200.0, 300.0),
        (30.0, 40.0)
      ]) {
        expect(breakthroughNewCap(c, r), sim.breakthroughNewCap(c, r));
      }
      // sim.isPr은 higher 전용이고 best == null을 PR로 본다 (GAME_DESIGN §7.2와 다름)
      // → best가 있는 경우만 비교.
      for (final (v, b) in [
        (100.0, 100.0),
        (100.9, 100.0),
        (101.0, 100.0),
        (99.0, 100.0)
      ]) {
        expect(isPr(v, b, 'higher'), sim.isPr(v, b));
      }
      for (var k = 0; k <= 15; k++) {
        expect(streakBonus(k), sim.streakBonus(k));
      }
    });
  });

  group('엔진 90일 = SimState (MVP, 돌파 제외)', () {
    for (final persona in <sim.Persona>[
      sim.Diligent(),
      sim.Lazy(),
      sim.Burst()
    ]) {
      test(persona.name, () {
        const engine = GameEngine();
        final simState = sim.SimState(const sim.SimOptions());
        final rng = math.Random(42);
        final start = DateTime(2026, 1, 1, 8);
        var g = GameState.initial(start);
        for (var d = 1; d <= 90; d++) {
          simState.startDay(d);
          final now = start.add(Duration(days: d - 1));
          for (final a in persona.plan(d, rng, simState)) {
            simState.complete(a);
            final add = engine.addQuest(
                g,
                QuestDraft(
                    title: '${a.category}-${a.kind}',
                    type: 'Side',
                    category: a.category,
                    difficulty: a.kind == 'flat' ? 'Normal' : a.difficulty,
                    measureKind: a.kind,
                    baseXp: a.flatXp),
                now);
            expect(add.error, isNull);
            final r = engine.completeQuest(
                add.state,
                add.quest!.id,
                a.kind == 'flat'
                    ? CompletionInput.none
                    : CompletionInput(
                        measurement:
                            Measurement(kind: a.kind, values: a.measure)),
                now);
            expect(r.error, isNull);
            g = r.state;
          }
          for (final t in GameConfig.treeKeys) {
            expect(g.profile.trees[t]!.totalXp, simState.treeXp[t],
                reason: 'day $d tree $t');
          }
          for (final k in GameConfig.statKeys) {
            expect(g.profile.stats[k]!.value, simState.stats[k],
                reason: 'day $d stat $k');
          }
          expect(g.profile.streakDays, simState.streak,
              reason: 'day $d streak');
        }
        expect(g.profile.totalCompletions, simState.completions);
        expect(g.profile.mainLevel, simState.main);
        expect(g.unlockedAchievements, simState.unlocked);
      });
    }
  });
}
