// LifeRPG 90일 밸런스 시뮬레이터 (A2).
//
// 실행: dart run tool/sim/main.dart [--md] [--post-mvp] [--days=90] [--seed=42]
//   --md        결과를 Markdown 표로 출력 (GAME_DESIGN.md 리포트용)
//   --post-mvp  R3 디트레이닝·R4 피로도·R6 유예 스트릭까지 켠다
import 'dart:io';
import 'dart:math' as math;

import 'package:liferpg/domain/game_config.dart';

import 'personas.dart';
import 'sim_engine.dart';

class Snapshot {
  Snapshot(this.day, SimState s)
      : main = s.main,
        totalXp = s.totalXp,
        efficiency = s.totalRaw == 0 ? 0 : s.totalDim / s.totalRaw,
        totalRaw = s.totalRaw,
        statSum = GameConfig.statKeys.fold(0.0, (a, k) => a + s.stats[k]!),
        topStat = GameConfig.statKeys
            .map((k) => (k, s.stats[k]!))
            .reduce((a, b) => a.$2 >= b.$2 ? a : b),
        maxCap = GameConfig.statKeys.map((k) => s.caps[k]!).reduce(math.max),
        breakthroughs = s.breakthroughs,
        streak = s.streak,
        maxStreak = s.maxStreak,
        achievements = s.unlocked.length,
        treeLevels = {for (final t in GameConfig.treeKeys) t: s.treeLevel(t)},
        stats = Map.of(s.stats),
        caps = Map.of(s.caps),
        fatigue = s.fatigue;

  final int day,
      main,
      totalXp,
      totalRaw,
      breakthroughs,
      streak,
      maxStreak,
      achievements;
  final double efficiency, statSum, maxCap, fatigue;
  final (String, double) topStat;
  final Map<String, int> treeLevels;
  final Map<String, double> stats, caps;
}

class Result {
  Result(this.persona, this.snaps, this.daily, this.final_);
  final Persona persona;
  final List<Snapshot> snaps;
  final List<int> daily; // 일별 메인 레벨
  final SimState final_;
}

Result run(Persona p, int days, int seed, SimOptions opts) {
  final rng = math.Random(seed);
  final s = SimState(opts);
  final snaps = <Snapshot>[];
  final daily = <int>[];
  const marks = {7, 14, 30, 60, 90};
  for (var d = 1; d <= days; d++) {
    s.startDay(d);
    for (final a in p.plan(d, rng, s)) {
      s.complete(a);
    }
    if (s.activeToday) s.tryBreakthroughs();
    daily.add(s.main);
    if (marks.contains(d) || d == days) snaps.add(Snapshot(d, s));
  }
  return Result(p, snaps, daily, s);
}

String f1(double v) => v.toStringAsFixed(1);
String pct(double v) => '${(v * 100).round()}%';

void main(List<String> args) {
  final md = args.contains('--md');
  final postMvp = args.contains('--post-mvp');
  int argInt(String k, int def) {
    final a = args.where((x) => x.startsWith('--$k='));
    return a.isEmpty ? def : int.parse(a.first.split('=').last);
  }

  final days = argInt('days', 90);
  final seed = argInt('seed', 42);
  final opts = SimOptions(postMvp: postMvp);
  final personas = <Persona>[Diligent(), Lazy(), Burst()];
  final results = [for (final p in personas) run(p, days, seed, opts)];
  final out = StringBuffer();
  void w([String l = '']) => out.writeln(l);

  w(md ? '#### 시뮬레이션 설정' : '=== LifeRPG 밸런스 시뮬레이션 ===');
  w('${md ? '- ' : ''}기간 $days일, seed $seed, 모드: ${postMvp ? 'MVP + R3/R4/R6' : 'MVP (R1·R2·R5·단순 스트릭)'}');
  for (final r in results) {
    w('${md ? '- ' : '  '}${r.persona.name}: ${r.persona.summary}');
  }
  w();

  // 1) 시점별 요약
  w(md ? '#### 시점별 요약' : '--- 시점별 요약 ---');
  final head = [
    '페르소나',
    '일',
    '메인Lv',
    '총XP',
    '원시XP',
    'R2효율',
    '스탯합',
    '최고 스탯',
    '최대 상한',
    '돌파',
    '스트릭(최대)',
    '업적'
  ];
  final rows = <List<String>>[];
  for (final r in results) {
    for (final sn in r.snaps) {
      rows.add([
        r.persona.name,
        '${sn.day}',
        '${sn.main}',
        '${sn.totalXp}',
        '${sn.totalRaw}',
        pct(sn.efficiency),
        f1(sn.statSum),
        '${sn.topStat.$1} ${f1(sn.topStat.$2)}',
        f1(sn.maxCap),
        '${sn.breakthroughs}',
        '${sn.streak}(${sn.maxStreak})',
        '${sn.achievements}',
      ]);
    }
  }
  _table(w, head, rows, md);
  w();

  // 2) 최종 트리 레벨 / 스탯
  w(md ? '#### $days일차 트리 레벨' : '--- $days일차 트리 레벨 ---');
  _table(
    w,
    ['페르소나', ...GameConfig.treeKeys.map((t) => GameConfig.treeLabels[t]!)],
    [
      for (final r in results)
        [
          r.persona.name,
          ...GameConfig.treeKeys.map((t) => '${r.snaps.last.treeLevels[t]}')
        ],
    ],
    md,
  );
  w();
  w(md ? '#### $days일차 스탯 (값/상한)' : '--- $days일차 스탯 (값/상한) ---');
  _table(
    w,
    ['페르소나', ...GameConfig.statKeys],
    [
      for (final r in results)
        [
          r.persona.name,
          ...GameConfig.statKeys.map((k) =>
              '${f1(r.snaps.last.stats[k]!)}/${r.snaps.last.caps[k]!.toStringAsFixed(0)}'),
        ],
    ],
    md,
  );
  w();

  // 3) 일별 메인 레벨 추이 (10일 간격)
  w(md ? '#### 메인 레벨 추이 (10일 간격)' : '--- 메인 레벨 추이 (10일 간격) ---');
  final ticks = [for (var d = 10; d <= days; d += 10) d];
  _table(
    w,
    ['페르소나', ...ticks.map((d) => 'D$d')],
    [
      for (final r in results)
        [r.persona.name, ...ticks.map((d) => '${r.daily[d - 1]}')],
    ],
    md,
  );
  w();

  // 4) 목표 판정
  final dil = results[0].snaps.last,
      lazy = results[1].snaps.last,
      burst = results[2].snaps.last;
  final goals = <(String, bool)>[
    ('G1 성실 메인Lv 40~55 (실제 ${dil.main})', dil.main >= 40 && dil.main <= 55),
    (
      'G2 몰아치기: 원시XP ≥ 성실인데 총XP ≤ 성실×0.7, 메인Lv ≤ 성실×0.8 '
          '(원시 ${burst.totalRaw} vs ${dil.totalRaw}, XP ${pct(burst.totalXp / dil.totalXp)}, '
          'Lv ${burst.main} vs ${dil.main})',
      burst.totalRaw >= dil.totalRaw &&
          burst.totalXp <= dil.totalXp * 0.7 &&
          burst.main <= dil.main * 0.8
    ),
    (
      'G3 R2효율 몰아치기 ≤ 70% (실제 ${pct(burst.efficiency)}), 성실 ≥ 95% (실제 ${pct(dil.efficiency)})',
      burst.efficiency <= 0.7 && dil.efficiency >= 0.95
    ),
    (
      'G4 게으름 메인Lv 3~12, 총XP ≤ 성실×0.15 (실제 Lv ${lazy.main}, XP ${pct(lazy.totalXp / dil.totalXp)})',
      lazy.main >= 3 && lazy.main <= 12 && lazy.totalXp <= dil.totalXp * 0.15
    ),
    (
      'G5 성실 돌파 ≥ 1, 최대 상한 C등급 이상 (실제 돌파 ${dil.breakthroughs}, 상한 ${f1(dil.maxCap)})',
      dil.breakthroughs >= 1 && dil.maxCap > 30
    ),
    (
      'G6 성실 트리 최고 Lv ≤ 15 (실제 ${dil.treeLevels.values.reduce(math.max)})',
      dil.treeLevels.values.reduce(math.max) <= 15
    ),
  ];
  w(md ? '#### 목표 판정' : '--- 목표 판정 ---');
  for (final g in goals) {
    w('${md ? '- ' : '  '}[${g.$2 ? 'PASS' : 'FAIL'}] ${g.$1}');
  }
  w();

  // 5) 레거시 변환 예시
  w(md ? '#### 레거시 Physical XP 변환 예시' : '--- 레거시 Physical XP 변환 예시 ---');
  final legacyRows = <List<String>>[];
  for (final x in [0, 199, 200, 1000, 1280, 2500, 4680, 10000, 30000]) {
    final (ol, oi, on) = legacyLevelFromXp(x);
    final nx = convertLegacyTreeXp(x);
    final (nl, ni, nn) = levelFromXp(nx);
    legacyRows.add(['$x', 'Lv$ol ($oi/$on)', '$nx', 'Lv$nl ($ni/$nn)']);
  }
  _table(w, ['레거시 XP', '레거시 레벨', '새 XP', '새 레벨'], legacyRows, md);
  w();

  // 6) 레벨 곡선
  w(md ? '#### 트리 레벨 곡선' : '--- 트리 레벨 곡선 ---');
  _table(
    w,
    ['Lv', '필요 XP(→다음)', '누적 XP'],
    [
      for (final l in [1, 2, 3, 5, 8, 10, 12, 15, 20, 25, 30])
        ['$l', '${xpToNext(l)}', '${cumulativeXpForLevel(l)}'],
    ],
    md,
  );

  stdout.write(out);
}

void _table(void Function([String]) w, List<String> head,
    List<List<String>> rows, bool md) {
  if (md) {
    w('| ${head.join(' | ')} |');
    w('|${head.map((_) => '---').join('|')}|');
    for (final r in rows) {
      w('| ${r.join(' | ')} |');
    }
    return;
  }
  int width(String s) => s.runes.fold(0, (a, r) => a + (r > 0x1100 ? 2 : 1));
  final widths = List.generate(head.length,
      (i) => [head[i], ...rows.map((r) => r[i])].map(width).reduce(math.max));
  String line(List<String> cells) => [
        for (var i = 0; i < cells.length; i++)
          cells[i] + ' ' * (widths[i] - width(cells[i]))
      ].join('  ');
  w('  ${line(head)}');
  for (final r in rows) {
    w('  ${line(r)}');
  }
}
