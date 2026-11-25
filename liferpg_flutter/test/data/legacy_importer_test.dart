import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'fixture_loader.dart';

final now = DateTime(2026, 3, 2, 9, 0, 0);
const importer = LegacyImporter();

void main() {
  group('기본 프로필 (basic)', () {
    final r = importer.convert(loadBundle('basic'), now);
    final s = r.state;
    final p = s.profile;

    test('레거시 4스탯 값·상한 유지, 신규 3스탯 기본값', () {
      expect(p.stats.keys.toSet(), GameConfig.statKeys.toSet());
      expect(p.stats['힘']!.value, 10.606);
      expect(p.stats['정신력']!.value, 10.2);
      expect(p.stats['힘']!.cap, 30);
      expect(p.stats['힘']!.peak, 10.606);
      for (final k in ['매력', '집중', '커뮤니케이션']) {
        expect(p.stats[k], StatState.initial(k));
      }
    });

    test('트리: physical은 convertLegacyTreeXp, 나머지 0', () {
      expect(p.trees.keys.toSet(), GameConfig.treeKeys.toSet());
      expect(p.trees['physical']!.totalXp, convertLegacyTreeXp(200));
      expect(p.treeLevel('physical').level, 2);
      for (final t in GameConfig.treeKeys.where((t) => t != 'physical')) {
        expect(p.trees[t]!.totalXp, 0);
      }
    });

    test('today_date는 그대로 두고 rollover에 맡긴다', () {
      expect(p.todayDate, '2026-03-01');
      expect(p.todayXp, 60);
      final rolled = const GameEngine().dailyRollover(s, now);
      expect(rolled.state.profile.todayDate, '2026-03-02');
      expect(rolled.state.profile.todayXp, 0);
      expect(rolled.state.questById(1)!.status, QuestStatus.active);
    });

    test('퀘스트: id·next_id 보존, flat, deadline 빈 문자열은 null', () {
      expect(s.quests.map((q) => q.id), [1, 2, 4]);
      expect(s.nextQuestId, 6);
      expect(s.quests.every((q) => q.measureKind == 'flat'), isTrue);
      final swim = s.questById(2)!;
      expect(swim.baseXp, 30);
      expect(swim.xp, 45);
      expect(swim.rewards['지구력'], 0.5);
      expect(swim.deadline, '2026-03-10');
      expect(swim.progress, 40);
      expect(s.questById(4)!.deadline, isNull);
      // base_xp 없는 퀘스트는 xp에서 배율을 되돌린다 (Easy 0.7: 21 → 30)
      expect(s.questById(4)!.baseXp, 30);
      expect(s.questById(4)!.xp, 21);
    });

    test('totalCompletions = max(DONE 수, 로그 완료 수)', () {
      expect(p.totalCompletions, 3); // DONE 1개, 로그 3건
      expect(p.breakthroughSuccesses, 0);
    });

    test('로그 보존 + import 이벤트, 업적 유지', () {
      expect(r.events.length, 8);
      expect(r.events.first.message, startsWith('퀘스트 추가:'));
      expect(r.events.first.ts, DateTime(2026, 2, 27, 8));
      final imp = r.events.firstWhere((e) => e.type == LogEvent.import);
      expect(imp.ts, now);
      expect(imp.meta['quests'], 3);
      expect(s.unlockedAchievements, {'first_quest', 'first_levelup'});
      expect(r.report.quests, 3);
      expect(r.report.events, r.events.length);
      expect(r.report.achievements, 2);
      expect(r.report.warnings, isEmpty);
    });

    test('변환 결과는 JSON 왕복해도 같다', () {
      final back = GameState.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back, s);
    });
  });

  group('돌파 성공 이력 (breakthrough)', () {
    final r = importer.convert(loadBundle('breakthrough'), now);
    final s = r.state;
    final p = s.profile;

    test('상한·카운터', () {
      expect(p.stats['힘']!.cap, 50);
      expect(p.stats['힘']!.value, 30);
      expect(p.stats['지구력']!.value, 14.75);
      expect(p.breakthroughSuccesses, 1);
      expect(p.totalCompletions, 1);
    });

    test('physical 1280 XP → 새 곡선 Lv5 이상', () {
      expect(p.trees['physical']!.totalXp, 1280);
      expect(p.treeLevel('physical').level, greaterThanOrEqualTo(5));
    });

    test('알 수 없는 트리·업적은 버리고 경고', () {
      expect(r.report.warnings.any((w) => w.contains('"mind"')), isTrue);
      expect(r.report.warnings.any((w) => w.contains('unknown_legacy_badge')),
          isTrue);
      expect(s.unlockedAchievements.contains('unknown_legacy_badge'), isFalse);
      expect(s.unlockedAchievements,
          containsAll(['first_quest', 'first_breakthrough', 'level_5']));
    });

    test('ACTIVE 돌파는 recordKey 없이 → 엔진이 레거시 규칙으로 완료', () {
      final q = s.questById(7)!;
      expect(q.isLegacyBreakthrough, isTrue);
      expect(q.unlockStat, '지구력');
      expect(q.unlockTo, 45);
      expect(q.category, GameConfig.breakthroughType);
      final res =
          const GameEngine().completeQuest(s, 7, CompletionInput.none, now);
      expect(res.error, isNull);
      expect(res.breakthrough?.success, isTrue);
      expect(res.state.profile.stats['지구력']!.cap, greaterThan(30));
      expect(res.state.profile.breakthroughSuccesses, 2);
    });

    test('임포트 직후 업적 판정 (§9.1): stat_max_d', () {
      // 힘 30 / 상한 50 → 아님. 다른 스탯도 상한 미만.
      expect(s.unlockedAchievements.contains('stat_max_d'), isFalse);
    });
  });

  group('int/float 혼재·누락 키 (mixed_numbers)', () {
    final r = importer.convert(loadBundle('mixed_numbers'), now);
    final s = r.state;
    final p = s.profile;

    test('숫자 형식 정규화', () {
      expect(p.stats['힘']!.value, 12.346);
      expect(p.stats['정신력']!.value, 11.5);
      expect(p.stats['정신력']!.cap, 35.5);
      expect(p.stats['지구력']!.value, 10); // 누락 → 기본값
      expect(p.stats['지구력']!.cap, 30);
      expect(p.todayXp, 15);
      expect(p.trees['physical']!.totalXp, convertLegacyTreeXp(450));
      expect(p.stats.containsKey('extra_stat'), isFalse);
      expect(r.report.warnings.any((w) => w.contains('extra_stat')), isTrue);
    });

    test('문자열 id·중복 id·비객체 항목', () {
      expect(s.quests.length, 2);
      expect(s.questById(5)!.title, '스트레칭');
      expect(s.questById(5)!.progress, 50);
      expect(s.questById(5)!.rewards['민첩'], 0.3);
      // next_id(2)가 최대 id보다 작으면 최대+1 → 중복 퀘스트가 6, next 7
      expect(s.questById(6)!.title, '중복 id');
      expect(s.questById(6)!.baseXp, 28); // 42 / 1.5
      expect(s.nextQuestId, 7);
      expect(r.report.warnings.any((w) => w.contains('중복')), isTrue);
      expect(r.report.warnings.any((w) => w.contains('객체가 아닌')), isTrue);
    });

    test('로그 파일 없음 → DONE 수로 totalCompletions', () {
      expect(p.totalCompletions, 1);
      // 로그 없음 → import 이벤트 1건 + 임포트 직후 판정된 업적 이벤트
      expect(r.events.where((e) => e.type == LogEvent.import).length, 1);
      expect(
          r.events.where((e) =>
              e.type != LogEvent.import && e.type != LogEvent.achievement),
          isEmpty);
      expect(r.state.unlockedAchievements, contains('first_quest'));
    });
  });

  group('옛 영문 7스탯 스키마 (old_english)', () {
    final r = importer.convert(loadBundle('old_english'), now);
    final p = r.state.profile;

    test('영문 스탯 값은 버리고 7종 모두 기본값', () {
      for (final k in GameConfig.statKeys) {
        expect(p.stats[k], StatState.initial(k), reason: k);
      }
      expect(r.report.warnings.any((w) => w.contains('영문 스탯')), isTrue);
    });
  });

  group('깨진 JSON (broken)', () {
    final r = importer.convert(loadBundle('broken'), now);

    test('예외 없이 기본값 + 파일마다 경고', () {
      final s = r.state;
      expect(s.profile, Profile.initial('2026-03-02'));
      expect(s.quests, isEmpty);
      expect(s.nextQuestId, 1);
      expect(s.unlockedAchievements, isEmpty);
      final w = r.report.warnings.join('\n');
      expect(w, contains('profile.json'));
      expect(w, contains('quests.json'));
      expect(w, contains('log.json'));
      expect(w, contains('achievements.json'));
      expect(r.events.single.type, LogEvent.import);
    });

    test('빈 번들', () {
      final e = importer.convert(const LegacyBundle(), now);
      expect(e.state, GameState.initial(now));
      expect(e.report.warnings, isNotEmpty);
    });

    test('타입이 이상한 필드', () {
      final e = importer.convert(
          const LegacyBundle(
            profileJson: '{"stats": [1,2], "stat_caps": "x", "trees": 3, '
                '"today_date": "어제", "today_xp": null}',
            questsJson: '{"quests": {"a": 1}, "next_id": "abc"}',
            logJson: '{"events": [{"ts": 5, "message": "퀘스트 완료: x"}, 7]}',
            achievementsJson: '{"unlocked": "first_quest"}',
          ),
          now);
      expect(e.state.profile.todayDate, '2026-03-02');
      expect(e.state.profile.stats['힘'], const StatState.initial('힘'));
      expect(e.state.quests, isEmpty);
      expect(e.state.profile.totalCompletions, 1);
      // 누적 완료 1 → 임포트 직후 판정으로 first_quest 해금 + 업적 이벤트
      expect(e.state.unlockedAchievements, contains('first_quest'));
      expect(e.events.any((x) => x.type == LogEvent.achievement), isTrue);
      expect(e.report.warnings.length, greaterThanOrEqualTo(5));
    });
  });

  group('비유한·극단 숫자 (QA 버그 #3)', () {
    const extremeProfile = '{"stats": {"힘": 1e306, "민첩": 1e400, "정신력": -1e400, '
        '"지구력": "NaN"}, "stat_caps": {"힘": 1e306, "민첩": "Infinity", '
        '"정신력": 9e15, "지구력": 40}, "trees": {"physical": {"xp": 1e306}}, '
        '"today_xp": 1e400, "today_date": "2026-03-02"}';
    const extremeQuests = '{"quests": ['
        '{"id": 1e400, "title": "무한 id", "type": "Side", "status": "ACTIVE"},'
        '{"id": 2, "title": "큰 XP", "type": "Side", "xp": 1e306, "base_xp": 1e306,'
        ' "rewards": {"힘": "NaN", "민첩": 1e306, "지구력": 0.5}, "progress": 1e306},'
        '{"id": 3, "title": "돌파", "type": "돌파", "category": "돌파",'
        ' "unlock_stat": "힘", "unlock_to": "Infinity"},'
        '{"id": "Infinity", "title": "문자열 무한 id", "type": "Side"}'
        '], "next_id": 1e306}';

    test('예외 없이 경고 + 기본값', () {
      final r = importer.convert(
          const LegacyBundle(
            profileJson: extremeProfile,
            questsJson: extremeQuests,
            logJson: '{"events": [{"ts": "2026-03-01 10:00:00", "type": "xp", '
                '"message": "x", "meta": {"n": 1e400}}]}',
            achievementsJson: '{"unlocked": [1e400, "first_quest"]}',
          ),
          now);
      final p = r.state.profile;
      for (final k in GameConfig.legacyStatKeys) {
        final st = p.stats[k]!;
        expect(st.value.isFinite && st.cap.isFinite, isTrue, reason: k);
        expect(st.value.abs() <= LegacyImporter.maxAbsNumber, isTrue);
        expect(st.cap.abs() <= LegacyImporter.maxAbsNumber, isTrue);
      }
      expect(p.stats['힘']!.value, GameConfig.defaultStatValue);
      expect(p.stats['지구력']!.value, GameConfig.defaultStatValue);
      expect(p.stats['지구력']!.cap, 40);
      expect(p.stats['민첩']!.cap, GameConfig.defaultStatCap);
      expect(p.trees['physical']!.totalXp, 0);
      expect(p.todayXp, 0);
      expect(p.mainLevel, greaterThanOrEqualTo(1));

      final quests = r.state.quests;
      expect(quests.every((q) => q.id > 0), isTrue);
      expect(quests.map((q) => q.id).toSet().length, quests.length);
      expect(r.state.nextQuestId,
          greaterThan(quests.map((q) => q.id).reduce((a, b) => a > b ? a : b)));
      expect(r.state.nextQuestId <= LegacyImporter.maxAbsNumber, isTrue);
      final big = quests.firstWhere((q) => q.title == '큰 XP');
      expect(big.baseXp <= LegacyImporter.maxAbsNumber, isTrue);
      expect(big.rewards, {'지구력': 0.5});
      expect(big.progress, inInclusiveRange(0, 100));
      final bt = quests.firstWhere((q) => q.title == '돌파');
      expect(bt.unlockTo, isNull);
      for (final q in quests) {
        expect(q.rewards.values.every((v) => v.isFinite), isTrue);
      }
      expect(r.events.first.meta['n'], isNull);
      expect(r.state.unlockedAchievements, contains('first_quest'));
      expect(r.report.warnings.any((w) => w.contains('범위 밖 숫자')), isTrue);

      // 변환 결과는 JSON 직렬화·엔진 사용이 가능해야 한다
      final json = jsonEncode(r.state.toJson());
      expect(GameState.fromJson(jsonDecode(json) as Map<String, Object?>),
          r.state);
      final res = const GameEngine()
          .completeQuest(r.state, big.id, CompletionInput.none, now);
      expect(res.error, isNull);
    });

    test('한계값(1e9) 이하 큰 수는 그대로 받아도 계산이 넘치지 않는다', () {
      final r = importer.convert(
          const LegacyBundle(
              profileJson: '{"stats": {"힘": 1e9}, "stat_caps": {"힘": 1e9}, '
                  '"trees": {"physical": {"xp": 1e9}}}'),
          now);
      final p = r.state.profile;
      expect(p.stats['힘']!.value, 1e9);
      expect(p.trees['physical']!.totalXp, greaterThanOrEqualTo(1000000000));
      expect(p.treeLevel('physical').level, greaterThan(1));
      jsonEncode(r.state.toJson());
    });
  });

  test('픽스처 디렉터리 존재', () {
    expect(Directory(fixtureDir).existsSync(), isTrue);
  });
}
