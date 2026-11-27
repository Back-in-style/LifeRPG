import 'package:liferpg/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime d0 = DateTime(2026, 11, 26, 9);
DateTime day(int n) => d0.add(Duration(days: n));
const engine = GameEngine();

GameState placed(Map<String, int> levels, [DateTime? at]) {
  var s = GameState.initial(at ?? d0);
  levels.forEach((k, l) {
    s = engine.placeLevel(s, k, l, at ?? d0).state;
  });
  return s;
}

GameState ok(EngineResult r) {
  expect(r.error, isNull);
  return r.state;
}

void main() {
  group('규칙: 레벨·스탯', () {
    test('주요 요소 레벨 = Σa²/Σa (9,1,1 → 약 7.5)', () {
      final s = placed({'knowledge': 9, 'thinking': 1, 'focus': 1});
      expect(s.elementLevel('gi'), closeTo(83 / 11, 1e-9));
      expect(s.elementRewardLevel('gi'), 7);
      expect(GameState.initial(d0).elementLevel('sim'), 1);
    });

    test('levelForStat: 강등선 경계', () {
      expect(levelForStat(10), 1);
      expect(levelForStat(10.01), 2);
      expect(levelForStat(20), 2);
      expect(levelForStat(40), 3);
      expect(levelForStat(1000), 5);
      expect(levelForStat(1e9), 9);
    });

    test('승급: +1레벨, 스탯 = 새 강등선×1.1, 보호 3일', () {
      const s = SubStat(key: 'strength', level: 3, stat: 25);
      final p = promote(s, '2026-11-26');
      expect(p.level, 4);
      expect(p.stat, closeTo(44, 1e-9));
      expect(p.protectedUntil, '2026-11-29');
      // 이미 스탯이 높으면 유지
      expect(promote(s.copyWith(stat: 90), '2026-11-26').stat, 90);
    });

    test('감소로 강등선 이하 → 스탯에 맞는 레벨, 보호 중엔 강등 없음', () {
      const s = SubStat(key: 'strength', level: 5, stat: 150);
      final ch = changeStat(s, -135, '2026-11-26'); // 15
      expect(ch.after.level, 2);
      expect(ch.demotedFrom, 5);
      final prot = s.copyWith(protectedUntil: '2026-11-27');
      expect(changeStat(prot, -135, '2026-11-26').demoted, isFalse);
    });

    test('distribute: 비율 정규화, 비면 균등', () {
      expect(distribute(2, {'strength': 0.7, 'stamina': 0.3}, 'che'),
          {'strength': 1.4, 'stamina': 0.6});
      final eq = distribute(3, {}, 'che');
      expect(eq.keys, ['strength', 'agility', 'stamina']);
      expect(eq.values.every((v) => v == 1), isTrue);
      expect(distribute(2, {'nope': 1}, 'gi').length, 3);
    });

    test('formatStat', () {
      expect(formatStat(1100), '1,100');
      expect(formatStat(1.4), '1.4');
      expect(formatStat(0.5), '0.5');
      expect(formatStat(-2), '-2');
    });
  });

  group('퀘스트', () {
    test('일일 보상 = 주요 요소 레벨(버림) 기준 스탯 5% (체 3레벨 → 2)', () {
      final s = placed({'strength': 3, 'agility': 3, 'stamina': 3});
      final r = engine.addQuest(
          s,
          const QuestDraft(
              kind: QuestKind.daily,
              title: '가슴 운동 + 러닝',
              element: 'che',
              weights: {'strength': 0.7, 'stamina': 0.3}),
          d0);
      final q = ok(r).activeQuests.single;
      expect(q.rewards, {'strength': 1.4, 'stamina': 0.6});
      expect(q.deadline, '2026-11-26');
      expect(q.level, 3);
    });

    test('주간 = 일일 × 3, 기한 7일', () {
      final s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(kind: QuestKind.weekly, title: 'w', element: 'gi'),
          d0));
      final q = s.activeQuests.single;
      expect(q.rewardTotal, closeTo(1.5, 1e-9));
      expect(q.deadline, '2026-12-02');
    });

    test('일일 상한: 주요 요소당 하루 2개, 주간은 제외', () {
      var s = GameState.initial(d0);
      for (var i = 0; i < 2; i++) {
        s = ok(engine.addQuest(
            s,
            QuestDraft(kind: QuestKind.daily, title: 'd$i', element: 'sim'),
            d0));
      }
      final r = engine.addQuest(
          s,
          const QuestDraft(kind: QuestKind.daily, title: 'd3', element: 'sim'),
          d0);
      expect(r.error, contains('2개'));
      expect(
          engine
              .addQuest(
                  s,
                  const QuestDraft(
                      kind: QuestKind.daily, title: 'x', element: 'gi'),
                  d0)
              .ok,
          isTrue);
      expect(
          engine
              .addQuest(
                  s,
                  const QuestDraft(
                      kind: QuestKind.weekly, title: 'w', element: 'sim'),
                  d0)
              .ok,
          isTrue);
    });

    test('완료 → 스탯 상승, 레벨은 그대로', () {
      var s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(
              kind: QuestKind.daily,
              title: 'd',
              element: 'che',
              weights: {'strength': 1}),
          d0));
      s = ok(engine.completeQuest(s, s.activeQuests.single.id, d0));
      expect(s.substat('strength').stat, 5.5);
      expect(s.substat('strength').level, 1);
      expect(engine.completeQuest(s, s.quests.single.id, d0).ok, isFalse);
    });

    test('특별: 승급 + 스킬 획득, 난이도 레벨 = 보상 레벨', () {
      var s = placed({'stamina': 3});
      s = ok(engine.addQuest(
          s,
          const QuestDraft(
              kind: QuestKind.special,
              title: '10km 완주',
              element: 'che',
              promote: 'stamina',
              grantSkill: SkillGrant(name: '러너')),
          d0));
      final q = s.activeQuests.single;
      expect(q.level, 4);
      s = ok(engine.completeQuest(s, q.id, d0));
      expect(s.substat('stamina').level, 4);
      expect(s.substat('stamina').stat, closeTo(44, 1e-9));
      expect(s.skills.single.name, '러너');
      expect(s.skills.single.element, 'che');
    });

    test('특별 체크인형(30일 중 24일): 조건 전엔 완료 불가', () {
      var s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(
              kind: QuestKind.special,
              title: '퀵 슬립 습관',
              element: 'sim',
              grantSkill: SkillGrant(name: '퀵 슬립'),
              requiredDays: 24,
              windowDays: 30),
          d0));
      final id = s.activeQuests.single.id;
      expect(s.activeQuests.single.deadline, '2026-12-25');
      expect(engine.completeQuest(s, id, d0).error, contains('체크인'));
      for (var i = 0; i < 24; i++) {
        s = ok(engine.rollover(s, day(i)));
        s = ok(engine.toggleCheckin(s, id, day(i)));
      }
      s = ok(engine.completeQuest(s, id, day(23)));
      expect(s.skills.single.name, '퀵 슬립');
    });
  });

  group('경고 퀘스트', () {
    GameState withSkill() {
      final s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(
              kind: QuestKind.special,
              title: 's',
              element: 'sim',
              grantSkill: SkillGrant(name: '퀵 슬립')),
          d0));
      return ok(engine.completeQuest(s, s.activeQuests.single.id, d0));
    }

    test('기본 5일 중 4일, 체크인으로 즉시 해제', () {
      var s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(
              kind: QuestKind.warning, title: '늦게 잠', element: 'sim'),
          d0));
      final q = s.activeQuests.single;
      expect(q.requiredDays, 4);
      expect(q.windowDays, 5);
      expect(q.deadline, '2026-11-30');
      expect(q.rewardTotal, closeTo(1.5, 1e-9)); // 보통 = 일일 0.5 × 3
      for (var i = 0; i < 4; i++) {
        s = ok(engine.rollover(s, day(i)));
        s = ok(engine.toggleCheckin(s, q.id, day(i)));
      }
      expect(s.questById(q.id)!.status, QuestStatus.cleared);
      expect(s.substat('execution').stat, 5);
    });

    test('기한까지 못 채우면 벌칙 + 스킬 실패 누적, 2연속 실패 시 스킬 삭제', () {
      var s = withSkill();
      final skillId = s.skills.single.id;
      for (var round = 0; round < 2; round++) {
        s = ok(engine.addQuest(
            s,
            QuestDraft(
                kind: QuestKind.warning,
                title: '늦게 잠 $round',
                element: 'sim',
                severity: Severity.minor,
                skillName: '퀵 슬립'),
            day(round * 5)));
        expect(s.activeQuests.single.skillId, skillId);
        s = ok(engine.rollover(s, day(round * 5 + 5)));
        expect(s.quests.last.status, QuestStatus.failed);
      }
      expect(s.skills, isEmpty);
    });

    test('심각 실패 → 연결 스킬 즉시 삭제', () {
      var s = withSkill();
      s = ok(engine.addQuest(
          s,
          QuestDraft(
              kind: QuestKind.warning,
              title: 'x',
              element: 'sim',
              severity: Severity.severe,
              skillId: s.skills.single.id),
          d0));
      s = ok(engine.rollover(s, day(5)));
      expect(s.skills, isEmpty);
    });

    test('경고 퀘스트는 완료·포기·삭제 불가', () {
      final s = ok(engine.addQuest(
          GameState.initial(d0),
          const QuestDraft(kind: QuestKind.warning, title: 'x', element: 'che'),
          d0));
      final id = s.activeQuests.single.id;
      expect(engine.completeQuest(s, id, d0).ok, isFalse);
      expect(engine.giveUp(s, id, d0).ok, isFalse);
      expect(engine.deleteQuest(s, id, d0).ok, isFalse);
    });
  });

  group('롤오버', () {
    test('일일 만료, 주간은 기한까지 유지', () {
      var s = GameState.initial(d0);
      s = ok(engine.addQuest(
          s,
          const QuestDraft(kind: QuestKind.daily, title: 'd', element: 'che'),
          d0));
      s = ok(engine.addQuest(
          s,
          const QuestDraft(kind: QuestKind.weekly, title: 'w', element: 'che'),
          d0));
      s = ok(engine.rollover(s, day(1)));
      expect(s.quests[0].status, QuestStatus.expired);
      expect(s.quests[1].isActive, isTrue);
      s = ok(engine.rollover(s, day(7)));
      expect(s.quests[1].status, QuestStatus.expired);
    });

    test('자연 감소: 3일 유예, 4일째부터 기준 스탯 1%/일', () {
      var s = placed({'strength': 4}); // 스탯 44, 보호 ~11/29
      s = ok(engine.rollover(s, day(3)));
      expect(s.substat('strength').stat, 44);
      s = ok(engine.rollover(s, day(4)));
      expect(s.substat('strength').stat, closeTo(43, 1e-9));
      s = ok(engine.rollover(s, day(7)));
      expect(s.substat('strength').stat, closeTo(40, 1e-9));
      expect(s.substat('strength').level, 3); // 40 이하 → 강등
      s = ok(engine.rollover(s, day(8)));
      expect(
          s.substat('strength').stat, closeTo(39.6, 1e-9)); // 이제 3레벨 기준 40의 1%
    });

    test('같은 날 롤오버는 변화 없음', () {
      final s = GameState.initial(d0);
      expect(identical(engine.rollover(s, d0).state, s), isTrue);
    });
  });

  group('Claude 업데이트', () {
    test('한글 라벨·배치·관찰·퀘스트·상한 초과 건너뜀', () {
      final u = UpdateBundle.fromJson({
        'format': 'sgcy-update',
        'version': 1,
        'date': '2026-11-26',
        'summary': '알람 듣고 바로 일어남',
        'placements': {'근력': 3, '민첩성': 3, 'stamina': 3, '외모': 12},
        'analysis': {
          '체': {
            '장점': ['바로 기상'],
            'weaknesses': '스트레칭 안 함'
          },
          'zzz': {
            'strengths': ['x']
          },
        },
        'profile_notes': ['대학생', '아침형 목표'],
        'quests': [
          {
            'kind': '일일',
            'element': '체',
            'title': '가슴 운동 + 러닝',
            'weights': {'근력': 0.7, '체력': 0.3}
          },
          {'kind': 'daily', 'element': 'che', 'title': '스트레칭'},
          {'kind': 'daily', 'element': 'che', 'title': '세 번째'},
          {'kind': 'special', 'title': '스쿼트 100kg', 'promote': '근력'},
          {
            'kind': 'warning',
            'title': '말 더듬기',
            'element': '연',
            'severity': '경미'
          },
          {'title': '종류 없음'},
        ],
      });
      expect(u.placements, {'strength': 3, 'agility': 3, 'stamina': 3});
      expect(u.observations.length, 2);
      final r = engine.applyUpdate(GameState.initial(d0), u, d0);
      expect(r.ok, isTrue);
      expect(r.added.length, 4);
      expect(r.added.first.rewards, {'strength': 1.4, 'stamina': 0.6});
      expect(r.added[2].element, 'che'); // promote에서 추론
      expect(r.added[2].level, 4);
      expect(r.added[3].severity, Severity.minor);
      expect(r.skipped.any((x) => x.contains('세 번째')), isTrue);
      expect(r.skipped.any((x) => x.contains('외모')), isTrue);
      expect(r.state.profileNotes, ['대학생', '아침형 목표']);
      expect(r.state.lastSummary, '알람 듣고 바로 일어남');
      expect(r.added.every((q) => q.source == 'claude'), isTrue);
    });

    test('다른 형식은 거부', () {
      expect(() => UpdateBundle.fromJson({'format': 'other'}),
          throwsA(isA<FormatException>()));
    });
  });

  group('직렬화·브리핑', () {
    test('상태 JSON 왕복', () {
      var s = placed({'focus': 5});
      s = ok(engine.addQuest(
          s,
          const QuestDraft(
              kind: QuestKind.special,
              title: 'sp',
              element: 'gi',
              promote: 'focus',
              grantSkill: SkillGrant(name: '딥워크', desc: 'd'),
              requiredDays: 3,
              windowDays: 5),
          d0));
      s = ok(engine.toggleCheckin(s, s.activeQuests.single.id, d0));
      final back = GameState.fromJson(s.toJson(), d0);
      expect(back, s);
      expect(back.nextId, s.nextId);
    });

    test('v1 상태는 거부', () {
      expect(() => GameState.fromJson({'profile': {}}, d0),
          throwsA(isA<FormatException>()));
    });

    test('브리핑에 요소·세부스탯·퀘스트가 들어간다', () {
      var s = placed({'strength': 4});
      s = ok(engine.addQuest(
          s,
          const QuestDraft(kind: QuestKind.daily, title: '러닝', element: 'che'),
          d0));
      final md = buildBriefing(s);
      expect(md, contains('# 심기체연 브리핑 — 2026-11-26'));
      expect(md, contains('| 체 | 근력 | 4 정위 | 44 | 40 | 100 | 보호 ~2026-11-29'));
      expect(md, contains('러닝'));
      expect(exportStateJson(s), contains('"format": "sgcy-state"'));
    });
  });
}
