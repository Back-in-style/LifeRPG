import 'package:material_ui/material_ui.dart';

/// 기존 앱 테마(Dark / DeepPurple / Amber)를 Material 3로 이식.
class AppTheme {
  AppTheme._();

  static const Color primary = Colors.deepPurple;
  static const Color accent = Colors.amber;

  /// 스탯 등급 색상 — 실제 등급 구간은 docs/SPEC_v1.md 확정 후 domain 쪽으로 이동.
  static const Color gradeGold = Color(0xFFFFD700);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NanumGothic',
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
