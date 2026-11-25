import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('설정'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('리마인더 스위치를 켜면 설정이 저장된다', (tester) async {
    final reminder = FakeReminderService();
    await tester.pumpWidget(testApp(newRepo(), reminder: reminder));
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('Daily 리마인더'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder_switch')));
    await tester.pumpAndSettle();
    expect(reminder.saved.enabled, isTrue);
    expect(find.text('매일 21:00에 알려 드릴게요.'), findsOneWidget);
  });

  testWidgets('레거시 가져오기: 대체 확인 → 결과 표시 → 퀘스트 반영', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('open_import')));
    await tester.pumpAndSettle();

    // 비어 있으면 안내
    await tester.tap(find.byKey(const Key('import_run')));
    await tester.pump();
    expect(find.text('JSON을 하나 이상 붙여 넣어줘'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('import_quests.json')),
      '{"quests": [{"id": 1, "category": "Gym", "type": "Daily", '
          '"title": "레거시 스쿼트", "xp": 30, "rewards": {}, '
          '"difficulty": "Normal", "deadline": null, "progress": 0, '
          '"status": "ACTIVE", "created_at": "2026-01-01 09:00:00", '
          '"completed_at": null, "desc": "", "base_xp": 30}], "next_id": 2}',
    );
    await tester.tap(find.byKey(const Key('import_run')));
    await tester.pumpAndSettle();
    expect(find.text('기존 데이터 대체'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('가져오기 완료!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('가져오기 결과'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('가져오기 결과'), findsOneWidget);
    expect(find.textContaining('퀘스트 1개'), findsOneWidget);
    final s = await repo.load();
    expect(s.quests.single.title, '레거시 스쿼트');
  });
}
