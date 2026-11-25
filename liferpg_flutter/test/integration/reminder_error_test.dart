// P3 A6: Daily 리마인더 — 예약 실패 시 UI 피드백.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/app/reminder.dart';

import '../widget/test_app.dart';

class _ThrowingReminder implements ReminderService {
  @override
  Future<ReminderSettings> load() async => const ReminderSettings();

  @override
  Future<bool> apply(ReminderSettings settings) async =>
      throw StateError('plugin missing');
}

void main() {
  testWidgets('예약이 예외로 실패하면 성공 스낵바를 띄우지 않는다', (tester) async {
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
}
