import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

/// `../claude/STATE_FORMAT.md`의 예시와 설명이 실제 앱 동작과 맞는지 (문서-코드 일치).
void main() {
  final md = File('../claude/STATE_FORMAT.md').readAsStringSync();
  final block = RegExp(r'```json\n([\s\S]*?)```').firstMatch(md)!.group(1)!;
  final now = DateTime(2026, 11, 26, 9);
  final s = GameState.fromJson(
      (jsonDecode(block) as Map).cast<String, Object?>(), now);

  test('예시 상태 파일을 앱이 읽는다', () {
    expect(s.quests, hasLength(4));
    expect(s.skills.single.failStreak, 1);
    expect(s.observations, hasLength(3));
    expect(s.profileNotes, hasLength(2));
  });

  test('문서의 해석: 기본값·요소 레벨·보호·감소·강등선', () {
    // 파일에 없는 세부스탯 = 1레벨·스탯 5
    expect(s.substat('execution').level, 1);
    expect(s.substat('execution').stat, 5);
    // 체 = (3²+4²+1²)/(3+4+1) = 3.25 → 보상 기준 3
    expect(s.elementLevel('che'), closeTo(3.25, 1e-9));
    expect(s.elementRewardLevel('che'), 3);
    expect(s.substat('strength').isProtected(s.today), isTrue);
    expect(s.substat('temperance').demotionLine, 10);
    // 절제: 11/20 이후 안 올라 자연 감소 중 (브리핑 비고)
    expect(buildBriefing(s).split('\n').firstWhere((l) => l.contains('| 절제 |')),
        contains('자연 감소'));
  });

  test('문서의 키 대응표가 설정과 같다', () {
    for (final sub in SgcyConfig.substats) {
      expect(md, contains('`${sub.key}` ${sub.label}'), reason: sub.key);
    }
    for (final e in SgcyConfig.elements) {
      expect(md, contains('| `${e.key}` | ${e.label} ${e.hanja}'),
          reason: e.key);
    }
    for (var l = 1; l <= SgcyConfig.maxLevel; l++) {
      expect(md, contains(SgcyConfig.levelName(l)));
    }
  });

  test('문서에 적은 퀘스트 상태값이 앱과 같다', () {
    for (final st in QuestStatus.values) {
      expect(md, contains('`${st.name}`'), reason: st.name);
    }
  });
}
