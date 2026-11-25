// P3 A6: 앱 UI 통합 — 레거시 데이터로 시작 → rollover → 레거시 돌파 완료 → 상태창·로그 반영.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

import '../widget/test_app.dart';
import 'support.dart';

void main() {
  testWidgets('레거시 import된 저장소로 시작 → 돌파 완료 → 상태창·로그 반영', (tester) async {
    final repo = newRepo();
    await repo.importLegacy(realisticLegacyBundle(), fixedNow);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    // 상태창: 앱 시작 rollover로 오늘 날짜, 누적 완료 45
    expect(find.text('오늘: 2026-03-02'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);

    await tester.tap(find.text('퀘스트'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_돌파')));
    await tester.pumpAndSettle();
    expect(find.text('[돌파] 힘 한계 돌파'), findsOneWidget);

    // 레거시 ACTIVE 돌파: 입력 없이 완료 → 성공 다이얼로그
    await tester.tap(find.text('[돌파] 민첩 한계 돌파'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_complete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('돌파 성공! 민첩 상한 30 → 50'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    final s = await repo.load();
    expect(s.profile.stats['민첩']!.cap, 50);
    expect(s.questById(8)!.isDone, isTrue);

    // 로그: 최신이 돌파 관련, 최대 200개
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();
    expect(find.textContaining('돌파 성공: 민첩 상한 30.0 → 50.0'), findsOneWidget);
    final events = await repo.recentEvents();
    expect(events.length, 200);
    expect(events.where((e) => e.type == LogEvent.system &&
        e.message == '일일 퀘스트 초기화: 2026-03-02').length, 1);
  });
}
