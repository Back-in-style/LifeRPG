// 시뮬레이션 페르소나 3종 (A2). day는 1부터, (day-1) % 7 == 0 이 월요일.
import 'dart:math' as math;

import 'sim_engine.dart';

abstract class Persona {
  String get name;
  String get summary;

  /// [day]에 완료할 활동 목록. [s]의 현재 상태(능력치)를 참고해 무게를 늘린다.
  List<Activity> plan(int day, math.Random rng, SimState s);
}

/// 근력 세션: 4종목 × 4세트 × 10회 × 무게. 무게는 시뮬 능력치(힘)에 비례.
Activity gym(SimState s, {double scale = 1, String difficulty = 'Normal'}) {
  final w = 40 * s.ability['힘']! / 100 * scale;
  return Activity('Gym', 'strength', {'sets': 16, 'reps': 10, 'weight_kg': w},
      difficulty: difficulty);
}

Activity swim(double meters) => Activity('Swim', 'swim_m', {'meters': meters});
Activity mobility(double minutes) =>
    Activity('Mobility', 'duration_min', {'minutes': minutes});
Activity sleep(double hours) =>
    Activity('Recovery', 'sleep_h', {'hours': hours});
Activity study(double pomodoros) =>
    Activity('Study', 'pomodoro', {'count': pomodoros});
Activity social(double count) => Activity('Social', 'count', {'count': count});
const Activity routine = Activity('Routine', 'flat', {}, flatXp: 30);

/// 성실: 주 6~7일, 하루 1~1.5시간 분산. 근력 월수금, 수영 화토, 학업 평일.
class Diligent extends Persona {
  @override
  String get name => '성실';
  @override
  String get summary => '매일 분산 (근력 주3·수영 주2·학업 평일 4뽀모·수면 7.5h·가동성 15분)';

  @override
  List<Activity> plan(int day, math.Random rng, SimState s) {
    if (rng.nextDouble() < 0.08) return const []; // 가끔 빠짐
    final dow = (day - 1) % 7; // 0=월
    return [
      sleep(7 + rng.nextDouble()),
      routine,
      mobility(15),
      if (dow == 0 || dow == 2 || dow == 4) gym(s),
      if (dow == 1 || dow == 5) swim(1500),
      if (dow < 5) study(4),
      if (dow == 2 || dow == 5) social(2),
    ];
  }
}

/// 게으름: 하루 30% 확률로 가볍게 1~2개.
class Lazy extends Persona {
  @override
  String get name => '게으름';
  @override
  String get summary => '하루 30% 확률로 가벼운 활동 1~2개 (수면 6h, 근력 절반, 2뽀모)';

  @override
  List<Activity> plan(int day, math.Random rng, SimState s) {
    if (rng.nextDouble() >= 0.3) return const [];
    final pool = [
      sleep(6),
      gym(s, scale: 0.5),
      study(2),
      mobility(10),
      routine
    ];
    pool.shuffle(rng);
    return pool.take(1 + rng.nextInt(2)).toList();
  }
}

/// 몰아치기: 평일 0, 주말 이틀에 성실과 비슷한 주간 총량을 몰아서.
class Burst extends Persona {
  @override
  String get name => '몰아치기';
  @override
  String get summary => '토·일만 (근력 2세션×1.25볼륨·수영 2000m×2·학업 10뽀모·가동성 60분·수면 9h)';

  @override
  List<Activity> plan(int day, math.Random rng, SimState s) {
    final dow = (day - 1) % 7;
    if (dow < 5) return const [];
    return [
      sleep(9),
      routine,
      gym(s, scale: 1.25),
      gym(s, scale: 1.25),
      swim(2000),
      swim(2000),
      study(5),
      study(5),
      mobility(60),
      social(5),
    ];
  }
}
