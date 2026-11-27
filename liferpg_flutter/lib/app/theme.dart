import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 디자인 안. 무협 느낌은 10% 정도만:
/// 제목·한자에 명조(세리프), 낙관(도장) 한 점, 궤도의 눈금, 오방색 계열의 차분한 요소 색, 각진 카드.
/// 본문은 고딕 그대로 두어 깔끔함을 유지한다.
enum AppStyle {
  muk('묵향 墨香', '먹빛 바탕 · 주홍 낙관 · 금빛 눈금'),
  hanji('한지 韓紙', '밝은 한지 바탕 · 먹 글씨 · 주홍 낙관'),
  cheongja('청자 靑磁', '청자빛 바탕 · 비취 강조 · 금 테두리'),
  classic('기본', '지금까지의 보라색 다크 테마');

  const AppStyle(this.label, this.desc);
  final String label;
  final String desc;

  bool get wuxia => this != classic;
}

/// 지금 고른 디자인 안 (비교용 — 저장하지 않음. 하나로 정하면 기본값을 바꾼다).
final appStyleProvider = StateProvider<AppStyle>((_) => AppStyle.muk);

/// 테마에 딸린 게임 색. `SgcyPalette.of(context)`.
@immutable
class SgcyPalette extends ThemeExtension<SgcyPalette> {
  const SgcyPalette({
    required this.elements,
    required this.levels,
    required this.ring,
    required this.rim,
    required this.seal,
    required this.wuxia,
    required this.warn,
    required this.reward,
    required this.protect,
    required this.danger,
  });

  /// sim·gi·che·yeon
  final Map<String, Color> elements;

  /// 레벨 1~9
  final List<Color> levels;

  /// 궤도 선
  final Color ring;

  /// 구 테두리 (null이면 요소 색을 어둡게)
  final Color? rim;

  /// 낙관(도장) 색
  final Color seal;

  /// 무협 장식(눈금·낙관·각진 배지) 사용 여부
  final bool wuxia;

  /// 경고·벌칙 / 보상 / 보호 / 감소·위험
  final Color warn;
  final Color reward;
  final Color protect;
  final Color danger;

  Color element(String key) => elements[key] ?? Colors.grey;
  Color level(int l) => levels[(l.clamp(1, levels.length)) - 1];

  static SgcyPalette of(BuildContext context) =>
      Theme.of(context).extension<SgcyPalette>() ?? AppTheme._classicPalette;

  @override
  SgcyPalette copyWith() => this;

  @override
  SgcyPalette lerp(SgcyPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

class AppTheme {
  AppTheme._();

  /// 제목·한자용 명조 (Noto Serif KR SemiBold, 상용 한글 2,350자 + 앱 한자만 담은 부분집합).
  static const String serif = 'SgcySerif';
  static const String sans = 'NanumGothic';

  static const SgcyPalette _classicPalette = SgcyPalette(
    elements: {
      'sim': Color(0xFFE57373),
      'gi': Color(0xFF64B5F6),
      'che': Color(0xFF81C784),
      'yeon': Color(0xFFFFB74D),
    },
    levels: [
      Color(0xFF9E9E9E),
      Color(0xFFA1887F),
      Color(0xFF8D9E6B),
      Color(0xFF4DB6AC),
      Color(0xFF4FC3F7),
      Color(0xFF7986CB),
      Color(0xFFBA68C8),
      Color(0xFFFF8A65),
      Color(0xFFFFD700),
    ],
    ring: Color(0xFF938F99),
    rim: null,
    seal: Color(0xFFB3261E),
    wuxia: false,
    warn: Colors.orange,
    reward: Colors.amber,
    protect: Colors.lightBlue,
    danger: Colors.redAccent,
  );

  /// 차분한 레벨 색: 먹 회색 → 흙 → 이끼 → 청록 → 쪽빛 → 남보라 → 자주 → 주홍 → 금
  static const List<Color> _inkLevels = [
    Color(0xFF7D776C),
    Color(0xFF9A8268),
    Color(0xFF808E68),
    Color(0xFF5E9088),
    Color(0xFF5A86AD),
    Color(0xFF6F72AB),
    Color(0xFF946C9D),
    Color(0xFFC0634A),
    Color(0xFFD4AF37),
  ];

  static ThemeData of(AppStyle style) => switch (style) {
        AppStyle.classic => _classic(),
        AppStyle.muk => _build(
            brightness: Brightness.dark,
            bg: const Color(0xFF131210),
            surface: const Color(0xFF1C1A17),
            surfaceHigh: const Color(0xFF26231F),
            text: const Color(0xFFE9E2D3),
            muted: const Color(0xFFA59D8E),
            primary: const Color(0xFFC4553C),
            secondary: const Color(0xFFC9A45C),
            outline: const Color(0xFF3D3830),
            palette: const SgcyPalette(
              elements: {
                'sim': Color(0xFFC8553D), // 朱
                'gi': Color(0xFF4F7CAC), // 靑
                'che': Color(0xFF5E8C61), // 綠
                'yeon': Color(0xFFC99A3E), // 黃
              },
              levels: _inkLevels,
              ring: Color(0x99C9A45C),
              rim: Color(0xCCC9A45C),
              seal: Color(0xFFB8432F),
              wuxia: true,
              warn: Color(0xFFD08A3E),
              reward: Color(0xFFC9A45C),
              protect: Color(0xFF6F9FC4),
              danger: Color(0xFFD0654E),
            ),
          ),
        AppStyle.hanji => _build(
            brightness: Brightness.light,
            bg: const Color(0xFFF3EEE3),
            surface: const Color(0xFFFAF7F0),
            surfaceHigh: const Color(0xFFEDE6D8),
            text: const Color(0xFF231F1A),
            muted: const Color(0xFF6E665A),
            primary: const Color(0xFFA8402C),
            secondary: const Color(0xFF7A5C2E),
            outline: const Color(0xFFD3C9B6),
            palette: const SgcyPalette(
              elements: {
                'sim': Color(0xFFB5452F),
                'gi': Color(0xFF2F5F8F),
                'che': Color(0xFF4A7350),
                'yeon': Color(0xFFB07F24),
              },
              levels: _inkLevels,
              ring: Color(0x99231F1A),
              rim: Color(0xFF231F1A),
              seal: Color(0xFFB0392A),
              wuxia: true,
              warn: Color(0xFFA85E16),
              reward: Color(0xFF7A5C2E),
              protect: Color(0xFF2F5F8F),
              danger: Color(0xFFB0392A),
            ),
          ),
        AppStyle.cheongja => _build(
            brightness: Brightness.dark,
            bg: const Color(0xFF0F1716),
            surface: const Color(0xFF16211F),
            surfaceHigh: const Color(0xFF1F2D2A),
            text: const Color(0xFFDDE8E3),
            muted: const Color(0xFF93A9A2),
            primary: const Color(0xFF7FB8A4),
            secondary: const Color(0xFFCDB06A),
            outline: const Color(0xFF2E4440),
            palette: const SgcyPalette(
              elements: {
                'sim': Color(0xFFCF6F59),
                'gi': Color(0xFF6A9FC4),
                'che': Color(0xFF7FB383),
                'yeon': Color(0xFFD5AD5C),
              },
              levels: _inkLevels,
              ring: Color(0x997FB8A4),
              rim: Color(0xCCCDB06A),
              seal: Color(0xFFB8432F),
              wuxia: true,
              warn: Color(0xFFD5A04E),
              reward: Color(0xFFCDB06A),
              protect: Color(0xFF7FB8A4),
              danger: Color(0xFFCF6F59),
            ),
          ),
      };

  static ThemeData _classic() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      secondary: Colors.amber,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: sans,
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      extensions: const [_classicPalette],
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceHigh,
    required Color text,
    required Color muted,
    required Color primary,
    required Color secondary,
    required Color outline,
    required SgcyPalette palette,
  }) {
    final light = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: light ? Colors.white : const Color(0xFF1A1410),
      primaryContainer:
          Color.alphaBlend(primary.withValues(alpha: 0.22), surface),
      onPrimaryContainer: text,
      secondary: secondary,
      secondaryContainer:
          Color.alphaBlend(primary.withValues(alpha: 0.16), surfaceHigh),
      onSecondaryContainer: text,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: bg,
      surfaceContainerLow: bg,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: outline,
      outlineVariant: outline,
    );
    const sharp = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)));
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: sans,
      scaffoldBackgroundColor: bg,
    );
    TextStyle? serifed(TextStyle? s) => s?.copyWith(
        fontFamily: serif,
        fontFamilyFallback: const [sans],
        letterSpacing: 0.5);
    final tt = base.textTheme;
    return base.copyWith(
      textTheme: tt.copyWith(
        displayLarge: serifed(tt.displayLarge),
        displayMedium: serifed(tt.displayMedium),
        displaySmall: serifed(tt.displaySmall),
        headlineLarge: serifed(tt.headlineLarge),
        headlineMedium: serifed(tt.headlineMedium),
        headlineSmall: serifed(tt.headlineSmall),
        titleLarge: serifed(tt.titleLarge),
        titleMedium: serifed(tt.titleMedium),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        // ThemeData.textTheme엔 크기가 없어서(로캘 적용 때 합쳐짐) 직접 준다.
        titleTextStyle: TextStyle(
            fontFamily: serif,
            fontFamilyFallback: const [sans],
            fontSize: 21,
            letterSpacing: 1,
            color: text),
        shape: Border(bottom: BorderSide(color: outline, width: 0.5)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: sharp.copyWith(side: BorderSide(color: outline)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: sharp.copyWith(side: BorderSide(color: outline)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.18),
        indicatorShape: sharp,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? primary : muted)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? text : muted)),
      ),
      chipTheme: base.chipTheme.copyWith(shape: sharp),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:
            Color.alphaBlend(primary.withValues(alpha: 0.2), surfaceHigh),
        foregroundColor: text,
        elevation: 1,
        highlightElevation: 2,
        shape: sharp.copyWith(
            side: BorderSide(color: primary.withValues(alpha: 0.5))),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: primary, linearTrackColor: surfaceHigh),
      extensions: [palette],
    );
  }
}

/// 낙관(도장): 주홍 네모 안에 한자. [text]가 4자면 2×2로 찍는다.
class Seal extends StatelessWidget {
  const Seal(this.text, {super.key, this.size = 30});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = SgcyPalette.of(context).seal;
    final chars = text.characters.toList();
    final grid = chars.length == 4;
    const style = TextStyle(
        fontFamily: AppTheme.serif,
        fontFamilyFallback: [AppTheme.sans],
        color: Color(0xFFFFF6EA),
        height: 1);
    Widget ch(String c) =>
        Text(c, style: style.copyWith(fontSize: size * (grid ? 0.36 : 0.62)));
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.12),
      ),
      child: grid
          // 도장은 오른쪽 세로줄부터 읽는다: 오른쪽 心·氣, 왼쪽 體·緣
          ? Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [ch(chars[2]), ch(chars[0])]),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [ch(chars[3]), ch(chars[1])]),
              ],
            )
          : Center(child: ch(text)),
    );
  }
}
