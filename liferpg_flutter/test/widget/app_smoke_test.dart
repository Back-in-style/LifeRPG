import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/app/app.dart';

void main() {
  testWidgets('앱이 뜨고 하단 탭 3개가 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LifeRpgApp()));
    await tester.pumpAndSettle();

    expect(find.text('상태창'), findsOneWidget);
    expect(find.text('퀘스트'), findsWidgets);
    expect(find.text('로그'), findsWidgets);
  });
}
