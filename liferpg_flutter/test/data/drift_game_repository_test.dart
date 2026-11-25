import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/data/db/app_database.dart';
import 'package:liferpg/domain/domain.dart';

import 'repository_contract.dart';

/// 데스크톱 sqlite(libsqlite3) 사용 가능 여부. 없으면 Drift 테스트를 건너뛴다.
/// (Linux의 sqlite3 패키지는 시스템 `libsqlite3.so`를 연다.)
String? _sqliteUnavailable() {
  if (!Platform.isLinux) return null;
  for (final name in ['libsqlite3.so', 'libsqlite3.so.0']) {
    try {
      DynamicLibrary.open(name);
      return null;
    } on ArgumentError {
      continue;
    }
  }
  return '시스템 libsqlite3.so가 없어 Drift 테스트를 건너뛴다 (apt install libsqlite3-dev)';
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final skip = _sqliteUnavailable();

  group('Drift', () {
    runRepositoryContract(
        'Drift(memory)',
        (clock) async => DriftGameRepository(
            AppDatabase(NativeDatabase.memory()),
            clock: clock));

    test('파일 DB: 닫았다 다시 열어도 유지', () async {
      final dir = await Directory.systemTemp.createTemp('liferpg_drift_');
      final file = File('${dir.path}/liferpg.sqlite');
      final now = DateTime(2026, 3, 2, 9);
      const engine = GameEngine();
      try {
        var repo = DriftGameRepository(AppDatabase(NativeDatabase(file)),
            clock: () => now);
        final add = engine.addQuest(
            await repo.load(),
            const QuestDraft(title: '수영', type: 'Daily', category: 'Swim'),
            now);
        final done = engine.completeQuest(
            add.state, add.quest!.id, CompletionInput.none, now);
        await repo.commit(done.state,
            events: [...add.events, ...done.events],
            completion: done.completion);
        await repo.close();

        repo = DriftGameRepository(AppDatabase(NativeDatabase(file)),
            clock: () => now);
        expect(await repo.load(), done.state);
        expect((await repo.recentEvents()).length,
            add.events.length + done.events.length);
        expect((await repo.completions(category: 'Swim')).single.tree, 'swim');
        await repo.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('commit은 트랜잭션: 중간 실패 시 아무것도 저장 안 됨', () async {
      final now = DateTime(2026, 3, 2, 9);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftGameRepository(db, clock: () => now);
      final s = GameState.initial(now);
      // meta에 JSON으로 바꿀 수 없는 값 → 이벤트 삽입 중 예외
      final bad = LogEvent(
          ts: now, type: LogEvent.system, message: 'x', meta: {'o': Object()});
      await expectLater(
          repo.commit(s.copyWith(nextQuestId: 99),
              events: [bad],
              completion: Completion(
                  questId: 1, questTitle: 'q', category: 'Gym', at: now)),
          throwsA(anything));
      expect((await repo.load()).nextQuestId, 1);
      expect(await repo.completions(), isEmpty);
      expect(await repo.recentEvents(), isEmpty);
      await repo.close();
    });
  }, skip: skip);
}
