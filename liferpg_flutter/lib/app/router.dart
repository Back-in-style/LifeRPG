import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/logs/logs_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/status/status_screen.dart';

/// 하단 탭 3개 (상태창 / 퀘스트 / 로그). 이후 기록·통계·설정 탭 추가 예정.
final GoRouter appRouter = GoRouter(
  initialLocation: '/status',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/status', builder: (_, __) => const StatusScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/quests', builder: (_, __) => const QuestsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/logs', builder: (_, __) => const LogsScreen()),
        ]),
      ],
    ),
  ],
);

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_circle), label: '상태창'),
          NavigationDestination(icon: Icon(Icons.shield), label: '퀘스트'),
          NavigationDestination(icon: Icon(Icons.history), label: '로그'),
        ],
      ),
    );
  }
}
