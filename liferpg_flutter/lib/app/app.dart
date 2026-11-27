import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class LifeRpgApp extends ConsumerStatefulWidget {
  const LifeRpgApp({super.key});

  @override
  ConsumerState<LifeRpgApp> createState() => _LifeRpgAppState();
}

class _LifeRpgAppState extends ConsumerState<LifeRpgApp> {
  late final GoRouter _router = createAppRouter();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 포그라운드 복귀 시 날짜가 바뀌었으면 일일 리셋.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    final c = ref.read(gameControllerProvider);
    if (c.hasValue) {
      ref.read(gameControllerProvider.notifier).rollover();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(ref.watch(appStyleProvider));
    return MaterialApp.router(
      title: 'LifeRPG',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: _router,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
