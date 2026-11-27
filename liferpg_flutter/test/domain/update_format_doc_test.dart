import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

/// `../claude/UPDATE_FORMAT.md`의 예시 JSON이 실제로 적용되는지 (문서-코드 일치).
void main() {
  test('UPDATE_FORMAT.md 예시가 그대로 적용된다', () {
    final md = File('../claude/UPDATE_FORMAT.md').readAsStringSync();
    final block = RegExp(r'```json\n([\s\S]*?)```').firstMatch(md)!.group(1)!;
    final u = UpdateBundle.fromJson(
        (jsonDecode(block) as Map).cast<String, Object?>());
    expect(u.problems, isEmpty);
    expect(u.quests.length, 7);
    expect(u.observations.length, 9);

    // 퀵 슬립 스킬이 있어야 경고 연결이 의미 있지만, 없어도 적용은 된다.
    final r = const GameEngine()
        .applyUpdate(GameState.initial(DateTime(2026, 11, 26, 22)), u,
            DateTime(2026, 11, 26, 22));
    expect(r.skipped, isEmpty);
    expect(r.added.length, 7);
    expect(r.state.substat('strength').level, 3);
    final habit = r.added.firstWhere((q) => q.grantSkill != null);
    expect(habit.requiredDays, 24);
    expect(habit.deadline, '2026-12-25');
  });
}
