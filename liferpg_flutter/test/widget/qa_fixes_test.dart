import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/app/providers.dart';
import 'package:liferpg/app/reminder.dart';
import 'package:liferpg/data/in_memory_game_repository.dart';
import 'package:liferpg/domain/domain.dart';

import 'test_app.dart';

class _ThrowingReminder implements ReminderService {
  @override
  Future<ReminderSettings> load() async => const ReminderSettings();

  @override
  Future<bool> apply(ReminderSettings settings) async =>
      throw StateError('plugin missing');
}

void main() {
  test('컨트롤러 액션은 직렬화된다 (동시 추가·동시 완료)', () async {
    final repo = newRepo();
    final c = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => fixedNow),
      gameRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    final ctl = c.read(gameControllerProvider.notifier);
    const a = QuestDraft(title: 'A', type: 'Daily', category: 'Routine');
    const b = QuestDraft(title: 'B', type: 'Daily', category: 'Routine');
    final adds = await Future.wait([ctl.addQuest(a), ctl.addQuest(b)]);
    expect(adds.every((r) => r.ok), isTrue);
    var s = await repo.load();
    expect(s.quests.map((q) => q.title), ['A', 'B']);
    expect(s.quests.map((q) => q.id).toSet(), hasLength(2));

    final id = s.quests.first.id;
    final done = await Future.wait([
      ctl.completeQuest(id, CompletionInput.none),
      ctl.completeQuest(id, CompletionInput.none),
    ]);
    expect(done.where((r) => r.ok), hasLength(1));
    expect(done.where((r) => r.error == GameError.alreadyDone), hasLength(1));
    s = await repo.load();
    expect(s.profile.totalCompletions, 1);
  });

  testWidgets('리마인더 예약 실패 시 실패 스낵바만 뜬다', (tester) async {
    await tester.pumpWidget(testApp(newRepo(), reminder: _ThrowingReminder()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder_switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('매일 21:00에 알려 드릴게요.'), findsNothing);
    expect(find.textContaining('알림 설정 실패'), findsOneWidget);
  });

  testWidgets('측정치 0 허용: 일부 0은 통과, 전부 0이면 한 번 경고', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_quest_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add_title')), '턱걸이');
    await tester.tap(find.byKey(const Key('add_submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('[Daily] 턱걸이'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_complete')));
    await tester.pumpAndSettle();

    for (final f in ['sets', 'reps', 'weight_kg']) {
      await tester.enterText(find.byKey(Key('measure_$f')), '0');
    }
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pump();
    expect(find.byKey(const Key('zero_warning')), findsOneWidget);

    // 맨몸(무게 0)은 정상 입력
    await tester.enterText(find.byKey(const Key('measure_sets')), '3');
    await tester.enterText(find.byKey(const Key('measure_reps')), '10');
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 완료! ✅'), findsOneWidget);
    final cs = await repo.completions();
    expect(cs.single.values['weight_kg'], 0);
  });

  testWidgets('상태창 오늘 XP 초기화 (확인 후)', (tester) async {
    final repo = newRepo();
    final s0 = await repo.load();
    await repo.commit(s0.copyWith(profile: s0.profile.copyWith(todayXp: 77)));
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('77'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset_today_xp')));
    await tester.pumpAndSettle();
    expect(find.text('오늘 XP를 0으로 초기화할까요? (되돌리기 어려움)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset_today_xp_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('오늘 XP가 초기화되었습니다.'), findsOneWidget);
    expect((await repo.load()).profile.todayXp, 0);
  });

  testWidgets('로그 삭제 (확인 후) → 빈 로그', (tester) async {
    final repo = InMemoryGameRepository(
      clock: () => fixedNow,
      initial: GameState.initial(fixedNow),
      events: [
        LogEvent(ts: fixedNow, type: LogEvent.system, message: '지울 이벤트'),
      ],
    );
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();
    expect(find.text('지울 이벤트'), findsOneWidget);

    await tester.tap(find.byTooltip('로그 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('모든 로그를 삭제할까요? (되돌리기 어려움)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear_logs_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('로그가 삭제되었습니다.'), findsOneWidget);
    expect(find.text('로그가 없습니다.'), findsOneWidget);
    expect(await repo.recentEvents(), isEmpty);
  });
}
