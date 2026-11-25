import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/domain/domain.dart';

import 'test_app.dart';

void main() {
  testWidgets('앱이 뜨고 하단 탭 3개와 상태창이 보인다', (tester) async {
    await tester.pumpWidget(testApp(newRepo()));
    await tester.pumpAndSettle();

    expect(find.text('상태창'), findsOneWidget);
    expect(find.text('퀘스트'), findsOneWidget);
    expect(find.text('로그'), findsOneWidget);
    expect(find.text('Main Lv. 1'), findsOneWidget);
    expect(find.text('오늘: ${dateKey(fixedNow)}'), findsOneWidget);
    // 스탯 7종 중 첫 카드
    expect(find.text('${GameConfig.statIcons['힘']} 힘'), findsOneWidget);
  });
}
