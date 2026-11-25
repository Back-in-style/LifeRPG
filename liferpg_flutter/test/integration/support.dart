// P3 통합 테스트 공용 헬퍼 (A6).
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/data/db/app_database.dart';

/// 시스템 libsqlite3이 없으면 Drift 테스트를 건너뛸 사유 문자열.
String? sqliteUnavailable() {
  if (!Platform.isLinux) return null;
  for (final name in ['libsqlite3.so', 'libsqlite3.so.0']) {
    try {
      DynamicLibrary.open(name);
      return null;
    } on ArgumentError {
      continue;
    }
  }
  return '시스템 libsqlite3.so가 없어 Drift 테스트를 건너뛴다';
}

/// 테스트 시각을 바꿀 수 있는 시계.
class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

DriftGameRepository driftRepo(AppDatabase db, TestClock clock) =>
    DriftGameRepository(db, clock: clock.call);

/// 레거시 로그 이벤트 1건 (SPEC_v1 §2.4).
Map<String, Object?> legacyEvent(String ts, String type, String message) =>
    {'ts': ts, 'type': type, 'message': message, 'meta': <String, Object?>{}};

/// 현실적인 레거시 JSON 4종 (SPEC_v1 §2).
///
/// - profile: physical xp 4680(레거시 Lv10, 0/920), 유령 트리 "mental"(Lv3),
///   float 스탯, 힘 상한 50.0(돌파 성공 이력), today_date = 2026-03-01
/// - quests: Daily(Gym DONE, Recovery ACTIVE, 공부 키워드 Other DONE),
///   Side(Other, 명시 보상), Main(Mobility, base_xp 없음 → xp만), 돌파 DONE(힘), 돌파 ACTIVE(민첩→70.0),
///   문자열 id "9", next_id 12
/// - log: [completedLog]개의 '퀘스트 완료:' 포함 총 [totalLog]건
/// - achievements: first_quest, quest_10, first_breakthrough, stat_max_d, level_5
LegacyBundle realisticLegacyBundle({int totalLog = 360, int completedLog = 45}) {
  final profile = {
    'app': 'LifeRPG',
    'trees': {
      'physical': {'xp': 4680, 'level': 10, 'xp_in_level': 0, 'xp_next': 920},
      'mental': {'xp': 500, 'level': 3, 'xp_in_level': 20, 'xp_next': 360},
    },
    'main_level': 13,
    'today_date': '2026-03-01',
    'today_xp': 75,
    'stats': {'힘': 17.35, '민첩': 12.4, '정신력': 30, '지구력': 11.007},
    'stat_caps': {'힘': 50.0, '민첩': 30, '정신력': 30, '지구력': 30},
    'traits': <String, Object?>{},
    'streak_days': 0,
    'last_active_date': null,
  };
  Map<String, Object?> quest(Map<String, Object?> m) => {
        'xp': 0,
        'rewards': <String, Object?>{},
        'difficulty': 'Normal',
        'deadline': null,
        'progress': 0,
        'status': 'ACTIVE',
        'created_at': '2026-01-10 08:00:00',
        'completed_at': null,
        'desc': '',
        ...m,
      };
  final r0 = {'힘': 0.0, '민첩': 0.0, '정신력': 0.0, '지구력': 0.0};
  final quests = {
    'quests': [
      quest({
        'id': 1, 'category': 'Gym', 'type': 'Daily', 'title': '[Day A] 스쿼트',
        'xp': 45, 'difficulty': 'Hard', 'rewards': {...r0, '힘': 0.5},
        'desc': '[Day A] 5x5', 'status': 'DONE',
        'completed_at': '2026-03-01 07:30:00', 'base_xp': 30,
      }),
      quest({
        'id': 2, 'category': 'Recovery', 'type': 'Daily', 'title': '수면 7시간',
        'xp': 21, 'difficulty': 'Easy', 'rewards': r0, 'base_xp': 30,
      }),
      quest({
        'id': 3, 'category': 'Other', 'type': 'Daily', 'title': '영어 공부 30분',
        'xp': 30, 'rewards': {...r0, '정신력': 0.3}, 'status': 'DONE',
        'completed_at': '2026-03-01 21:00:00', 'base_xp': 30,
      }),
      quest({
        'id': 4, 'category': 'Other', 'type': 'Side', 'title': '책 한 권 읽기',
        'xp': 100, 'rewards': {...r0, '정신력': 1.0, '지구력': -0.2},
        'deadline': '2026-03-31', 'progress': 40, 'base_xp': 100,
      }),
      // base_xp 없음 (xp만): 임포터가 배율을 되돌린다
      quest({
        'id': 5, 'category': 'Mobility', 'type': 'Main', 'title': '다리 찢기',
        'xp': 70, 'difficulty': 'Easy', 'rewards': {...r0, '민첩': 2.0},
        'deadline': '', 'progress': 10,
      }),
      quest({
        'id': 6, 'category': '돌파', 'type': '돌파', 'title': '힘 한계 돌파',
        'rewards': {'unlock_stat': '힘', 'unlock_to': 50.0},
        'status': 'DONE', 'completed_at': '2026-02-01 10:00:00',
        'unlock_stat': '힘', 'unlock_to': 50.0,
      }),
      quest({
        'id': 8, 'category': '돌파', 'type': '돌파', 'title': '민첩 한계 돌파',
        'rewards': {'unlock_stat': '민첩', 'unlock_to': 70.0},
        'unlock_stat': '민첩', 'unlock_to': 70.0,
      }),
      quest({
        'id': '9', 'category': 'Swim', 'type': 'Side', 'title': '수영 1km',
        'xp': 30, 'rewards': {...r0, '지구력': 0.5}, 'base_xp': 30,
        'deadline': '2026-02-20',
      }),
    ],
    'next_id': 12,
  };

  final events = <Map<String, Object?>>[];
  final start = DateTime(2026, 1, 10, 8);
  var completed = 0;
  for (var i = 0; i < totalLog; i++) {
    final t = start.add(Duration(minutes: 230 * i));
    final ts = '${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}:00';
    switch (i % 8) {
      case 0 || 3 when completed < completedLog:
        completed++;
        events.add(legacyEvent(ts, 'quest', '퀘스트 완료: 스쿼트 #$i'));
      case 1:
        events.add(legacyEvent(ts, 'xp', 'PHYSICAL XP +45: 퀘스트: 스쿼트'));
      case 2:
        events.add(legacyEvent(ts, 'stat', '스탯 상승: 힘 +0.5'));
      case 4:
        events.add(legacyEvent(ts, 'system', '일일 퀘스트 초기화: ${ts.substring(0, 10)}'));
      default:
        events.add(legacyEvent(ts, 'quest', '퀘스트 추가: [Daily] 테스트 #$i (+30XP, Normal)'));
    }
  }
  // 나머지 완료 이벤트를 채운다
  while (completed < completedLog) {
    completed++;
    events.add(legacyEvent('2026-03-01 07:30:00', 'quest', '퀘스트 완료: 보충 #$completed'));
  }
  events.add(legacyEvent('2026-02-01 10:00:00', 'breakthrough', '돌파 성공: 힘 상한 30.0 → 50.0'));

  return LegacyBundle(
    profileJson: const JsonEncoder.withIndent('  ').convert(profile),
    questsJson: const JsonEncoder.withIndent('  ').convert(quests),
    logJson: jsonEncode({'events': events}),
    achievementsJson: jsonEncode({
      'unlocked': ['quest_10', 'first_quest', 'first_breakthrough', 'stat_max_d', 'level_5'],
    }),
  );
}

String _two(int v) => v.toString().padLeft(2, '0');
