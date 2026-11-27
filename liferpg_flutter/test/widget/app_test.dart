import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

import 'test_app.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(420, 1400);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('상태창: 심기체연 4요소 → 눌러서 세부스탯', (tester) async {
    await tester.pumpWidget(testApp(newRepo()));
    await tester.pumpAndSettle();
    for (final e in ['sim', 'gi', 'che', 'yeon']) {
      expect(find.byKey(Key('element_$e')), findsOneWidget);
    }
    expect(find.text('Lv 1.0'), findsNWidgets(4));

    await tester.tap(find.byKey(const Key('element_che')));
    await tester.pumpAndSettle();
    expect(find.text('근력'), findsOneWidget);
    expect(find.text('민첩성'), findsOneWidget);
    expect(find.text('체력'), findsOneWidget);
    expect(find.text('Lv1 탈위 脫位'), findsNWidgets(3));
  });

  testWidgets('레벨 배치 → 주요 요소 레벨 갱신', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('element_gi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('레벨 배치').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('9 초월'));
    await tester.pumpAndSettle();
    expect(find.text('Lv 7.55'), findsOneWidget);
    expect((await repo.load()).substat('knowledge').level, 9);
  });

  testWidgets('퀘스트 추가 → 완료 → 스탯 상승', (tester) async {
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_quest')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quest_title')), '러닝 3km');
    await tester.tap(find.widgetWithText(FilterChip, '체력'));
    await tester.pumpAndSettle();
    expect(find.textContaining('체력 +0.5'), findsOneWidget); // 미리보기
    await tester.ensureVisible(find.byKey(const Key('save_quest')));
    await tester.tap(find.byKey(const Key('save_quest')));
    await tester.pumpAndSettle();
    expect(find.text('러닝 3km'), findsOneWidget);

    final id = (await repo.load()).activeQuests.single.id;
    await tester.tap(find.byKey(Key('complete_$id')));
    await tester.pumpAndSettle();
    expect((await repo.load()).substat('stamina').stat, 5.5);
    expect(find.text('러닝 3km'), findsNothing);
  });

  testWidgets('연동: 업데이트 붙여넣기 → 적용, 상태 복사', (tester) async {
    final clip = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clip.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    final repo = newRepo();
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연동'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy_handoff')));
    await tester.pumpAndSettle();
    expect(clip.single, contains('# 심기체연 브리핑'));
    expect(clip.single, contains('"format": "sgcy-state"'));

    await tester.enterText(find.byKey(const Key('update_input')), '''
여기 오늘 업데이트야
```json
{"format":"sgcy-update","version":1,"date":"2026-11-26","summary":"바로 기상",
 "analysis":{"심":{"strengths":["알람에 바로 일어남"]}},
 "quests":[{"kind":"daily","element":"sim","title":"23시 취침","weights":{"절제":1}},
           {"kind":"warning","element":"연","title":"말 천천히 하기","severity":"minor"}]}
```''');
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply_update')));
    await tester.pumpAndSettle();
    expect(find.textContaining('퀘스트 2개'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_update')));
    await tester.pumpAndSettle();
    expect(find.textContaining('추가된 퀘스트 2개'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    final s = await repo.load();
    expect(s.activeQuests.map((q) => q.kind),
        [QuestKind.daily, QuestKind.warning]);
    expect(s.observations.single.text, '알람에 바로 일어남');
    expect(s.lastSummary, '바로 기상');
  });

  testWidgets('경고 퀘스트: 체크인 버튼, 완료 버튼 없음', (tester) async {
    final s0 = const GameEngine()
        .addQuest(
            GameState.initial(fixedNow),
            const QuestDraft(
                kind: QuestKind.warning, title: '야식', element: 'sim'),
            fixedNow)
        .state;
    final repo = newRepo(s0);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트'));
    await tester.pumpAndSettle();
    final id = s0.activeQuests.single.id;
    expect(find.byKey(Key('complete_$id')), findsNothing);
    await tester.tap(find.byKey(Key('checkin_$id')));
    await tester.pumpAndSettle();
    expect((await repo.load()).questById(id)!.checkins, ['2026-11-26']);
    expect(find.text('체크인 1/4일 (5일 중)'), findsOneWidget);
  });
}
