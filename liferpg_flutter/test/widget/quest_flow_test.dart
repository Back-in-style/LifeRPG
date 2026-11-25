import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/in_memory_game_repository.dart';
import 'package:liferpg/domain/domain.dart';

import 'test_app.dart';

Future<void> _goQuests(WidgetTester tester) async {
  await tester.tap(find.text('퀘스트'));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(
    WidgetTester tester, Key key, String item) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> _addQuest(WidgetTester tester,
    {required String title, String? category}) async {
  await tester.tap(find.byKey(const Key('add_quest_fab')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('add_title')), title);
  if (category != null) {
    await _selectDropdown(tester, const Key('add_category'), category);
  }
  await tester.tap(find.byKey(const Key('add_submit')));
  await tester.pumpAndSettle();
}

Future<void> _completeFromList(WidgetTester tester, String title) async {
  await tester.tap(find.text('[Daily] $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('detail_complete')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('제목 없이 추가하면 검증 문구가 뜬다', (tester) async {
    await tester.pumpWidget(testApp(newRepo()));
    await tester.pumpAndSettle();
    await _goQuests(tester);
    expect(find.text('퀘스트가 없습니다. + 버튼으로 추가하세요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_quest_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_submit')));
    await tester.pump();
    expect(find.text('퀘스트 제목을 입력해줘'), findsOneWidget);
  });

  testWidgets('flat 퀘스트 추가 → 완료 → 상태창·로그 반영', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await _goQuests(tester);

    await _addQuest(tester, title: '기상 6시', category: 'Routine');
    expect(find.text('퀘스트가 추가되었습니다!'), findsOneWidget);
    expect(find.text('[Daily] 기상 6시'), findsOneWidget);
    expect(find.textContaining('🌙 루틴'), findsOneWidget); // Daily 그룹 헤더

    await _completeFromList(tester, '기상 6시');
    // flat이라 입력 없이 바로 결과
    expect(find.text('퀘스트 완료! ✅'), findsOneWidget);
    final s = await repo.load();
    expect(s.profile.todayXp, greaterThan(0));
    expect(find.text('+${s.profile.todayXp} XP (Routine)'), findsOneWidget);
    expect(find.textContaining('첫 발걸음'), findsOneWidget); // 새 업적
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 완료 필터
    await tester.tap(find.byKey(const Key('filter_done')));
    await tester.pumpAndSettle();
    expect(find.text('[Daily] 기상 6시'), findsOneWidget);

    // 상태창: Today XP, 스트릭
    await tester.tap(find.text('상태창'));
    await tester.pumpAndSettle();
    expect(find.text('${s.profile.todayXp}'), findsOneWidget);
    expect(find.text('1일'), findsOneWidget);

    // 로그: 최신순
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 완료: 기상 6시'), findsOneWidget);
    expect(find.text('퀘스트 추가: [Daily] 기상 6시 (+30XP, Normal)'),
        findsOneWidget);
  });

  testWidgets('측정형(근력) 퀘스트는 측정치 입력 후 완료', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await _goQuests(tester);

    // 기본 카테고리 Gym → 측정치 기본값 strength
    await _addQuest(tester, title: '스쿼트');
    expect(find.textContaining('측정: 근력'), findsOneWidget);

    await _completeFromList(tester, '스쿼트');
    expect(find.text('측정값 입력'), findsOneWidget);

    // 비우고 제출 → 오류
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pump();
    expect(find.text('0 이상의 숫자를 입력해줘'), findsNWidgets(3));

    await tester.enterText(find.byKey(const Key('measure_sets')), '5');
    await tester.enterText(find.byKey(const Key('measure_reps')), '5');
    await tester.enterText(find.byKey(const Key('measure_weight_kg')), '60');
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pumpAndSettle();

    expect(find.text('퀘스트 완료! ✅'), findsOneWidget);
    final s = await repo.load();
    expect(s.quests.single.isDone, isTrue);
    expect(s.profile.trees['physical']!.totalXp, greaterThan(0));
    expect(find.textContaining('스탯 상승: 힘'), findsOneWidget);

    final cs = await repo.completions();
    expect(cs.single.values, {'sets': 5.0, 'reps': 5.0, 'weight_kg': 60.0});
  });

  testWidgets('돌파 퀘스트: 기록값 입력 필수, 첫 기록은 기준 등록', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await _goQuests(tester);

    await tester.tap(find.byKey(const Key('add_quest_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add_title')), '스쿼트 돌파');
    await tester.tap(find.text('돌파').last);
    await tester.pumpAndSettle();
    // 기본 목표 상한 = cap + 20
    expect(find.text('50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add_submit')));
    await tester.pump();
    expect(find.textContaining('기록 키가 필요해'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('add_record_key')), '스쿼트 1RM(kg)');
    await tester.tap(find.byKey(const Key('add_submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('[돌파] 스쿼트 돌파'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_complete')));
    await tester.pumpAndSettle();
    expect(find.text('💥 돌파 기록 입력'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pump();
    expect(find.text('돌파는 기록값이 필요해'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('record_value')), '80');
    await tester.tap(find.byKey(const Key('complete_submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('돌파 실패'), findsOneWidget);
    final s = await repo.load();
    expect(s.records['스쿼트 1RM(kg)']!.history, hasLength(1));
  });

  testWidgets('삭제 확인 후 퀘스트가 사라진다', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await _goQuests(tester);
    await _addQuest(tester, title: '복습', category: 'Study');

    await tester.tap(find.text('[Daily] 복습'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text("'복습' 퀘스트를 삭제할까요?"), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트가 삭제되었습니다.'), findsOneWidget);
    expect((await repo.load()).quests, isEmpty);
  });

  testWidgets('로그 탭은 저장된 이벤트를 최신순으로 보여 준다', (tester) async {
    final repo = InMemoryGameRepository(
      clock: () => fixedNow,
      initial: GameState.initial(fixedNow),
      events: [
        LogEvent(
            ts: DateTime(2026, 3, 1, 8), type: LogEvent.system, message: '옛 이벤트'),
        LogEvent(
            ts: DateTime(2026, 3, 2, 8), type: LogEvent.pr, message: '새 이벤트'),
      ],
    );
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();

    final newer = tester.getTopLeft(find.text('새 이벤트'));
    final older = tester.getTopLeft(find.text('옛 이벤트'));
    expect(newer.dy, lessThan(older.dy));
    expect(find.text('2026-03-02 08:00:00'), findsOneWidget);
  });
}
