import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/theme.dart';

/// 메인화면 궤도: 심·기·체·연 구 4개가 하나의 궤도를 따라 천천히 공전한다.
///
/// 기본 배치(`구상/메인화면 대략적 개요.pdf`): 심 위 · 체 오른쪽 · 연 아래 · 기 왼쪽.
/// 시스템 "애니메이션 줄이기"가 켜져 있으면 이 배치로 멈춰 있다.
class ElementOrbit extends StatefulWidget {
  const ElementOrbit({super.key, required this.state});

  final GameState state;

  /// 한 바퀴 도는 시간.
  static const Duration period = Duration(seconds: 60);

  /// 시계 방향, 위에서 시작하는 순서.
  static const List<String> order = ['sim', 'che', 'yeon', 'gi'];

  @override
  State<ElementOrbit> createState() => _ElementOrbitState();
}

class _ElementOrbitState extends State<ElementOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: ElementOrbit.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (still && _spin.isAnimating) {
      _spin.stop();
    } else if (!still && !_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = SgcyPalette.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final side = box.maxWidth;
        // 스케치 비율: 구 반지름 = 궤도 반지름 / 2, 구가 정사각형 가장자리에 닿음.
        final orbitR = side / 3;
        final sphereR = side / 6;
        final center = Offset(side / 2, side / 2);
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _spin,
            builder: (context, _) {
              final base = -math.pi / 2 + _spin.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RingPainter(
                          radius: orbitR,
                          color: pal.ring,
                          stroke: pal.wuxia ? 1.5 : 3,
                          ticks: pal.wuxia),
                    ),
                  ),
                  for (var i = 0; i < ElementOrbit.order.length; i++)
                    () {
                      final a = base + i * math.pi / 2;
                      final c =
                          center + Offset(math.cos(a), math.sin(a)) * orbitR;
                      return Positioned(
                        left: c.dx - sphereR,
                        top: c.dy - sphereR,
                        width: sphereR * 2,
                        height: sphereR * 2,
                        child: ElementSphere(
                          state: widget.state,
                          element: SgcyConfig.elements.firstWhere(
                              (e) => e.key == ElementOrbit.order[i]),
                        ),
                      );
                    }(),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

/// 궤도. 무협 안에서는 가는 이중선 + 24눈금(나침반·절기처럼), 8방위는 조금 길게.
class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.radius,
      required this.color,
      required this.stroke,
      this.ticks = false});
  final double radius;
  final Color color;
  final double stroke;
  final bool ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawCircle(c, radius, p);
    if (!ticks) return;
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.6
      ..color = color.withValues(alpha: color.a * 0.45);
    canvas.drawCircle(c, radius * 0.9, faint);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      final long = i % 3 == 0;
      canvas.drawLine(c + dir * (radius * (long ? 0.86 : 0.88)),
          c + dir * (radius * 0.9), long ? p : faint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.stroke != stroke ||
      old.ticks != ticks;
}

/// 주요 요소 구: `심 心` / `4Lv` / `정위 正位`. [tappable]이면 누를 때 요소 상세.
class ElementSphere extends StatelessWidget {
  const ElementSphere(
      {super.key,
      required this.state,
      required this.element,
      this.tappable = true});

  final GameState state;
  final ElementDef element;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final pal = SgcyPalette.of(context);
    final color = pal.element(element.key);
    final deep = Color.lerp(color, Colors.black, 0.35)!;
    final serif = pal.wuxia ? AppTheme.serif : null;
    final level = state.elementRewardLevel(element.key);
    final levelText =
        '${SgcyConfig.levelName(level)} ${SgcyConfig.levelHanja[level - 1]}';
    const shadow = [Shadow(blurRadius: 3, color: Color(0x99000000))];
    return LayoutBuilder(builder: (context, box) {
      final d = box.maxWidth;
      return Semantics(
        button: tappable,
        label: '${element.label} ${element.meaning}, '
            '레벨 $level, $levelText',
        excludeSemantics: true,
        child: GestureDetector(
          key: tappable ? Key('element_${element.key}') : null,
          onTap:
              tappable ? () => context.push('/element/${element.key}') : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 왼쪽 위에서 빛을 받는 구.
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                radius: 0.95,
                colors: [Color.lerp(color, Colors.white, 0.45)!, color, deep],
                stops: const [0, 0.5, 1],
              ),
              // 무협 안: 금·먹 테두리 한 줄 (구슬 테 느낌)
              border: Border.all(
                  color: pal.rim ?? deep, width: pal.wuxia ? 1.5 : 2.5),
              boxShadow: [
                BoxShadow(
                  color: deep.withValues(alpha: 0.45),
                  blurRadius: d * 0.12,
                  offset: Offset(0, d * 0.05),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(d * 0.2),
              child: FittedBox(
                child: DefaultTextStyle(
                  // 테마 글꼴(NanumGothic)을 유지한 채 색만 바꾼다.
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Colors.white, height: 1.25, shadows: shadow),
                  textAlign: TextAlign.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${element.label} ${element.hanja}',
                          style: TextStyle(
                              fontFamily: serif,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('${level}Lv',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      Text(levelText,
                          style: TextStyle(fontFamily: serif, fontSize: 17)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
