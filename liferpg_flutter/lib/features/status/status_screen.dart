import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../../app/theme.dart';
import 'element_orbit.dart';

/// 상태창 — 심·기·체·연 4요소가 궤도를 도는 구. 누르면 세부스탯.
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('심기체연'),
            if (SgcyPalette.of(context).wuxia) ...[
              const SizedBox(width: 10),
              const Seal('心氣體緣', size: 28),
            ],
          ],
        ),
        actions: [
          IconButton(
            key: const Key('open_settings'),
            tooltip: '설정',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _Header(state: s),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ElementOrbit(state: s),
                ),
              ),
            ),
            if (s.lastSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.forum),
                  title: Text('최근 대화 요약 (${s.lastUpdateDate ?? ''})'),
                  subtitle: Text(s.lastSummary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final active = state.activeQuests;
    final warnings = active.where((q) => q.isWarning).length;
    final daily = active.where((q) => q.kind == QuestKind.daily).length;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(state.today, style: t.titleMedium),
        const Spacer(),
        Chip(
          avatar: const Icon(Icons.today, size: 16),
          label: Text('일일 $daily'),
          visualDensity: VisualDensity.compact,
        ),
        if (warnings > 0) ...[
          const SizedBox(width: 6),
          Chip(
            avatar: Icon(Icons.warning_amber,
                size: 16, color: SgcyPalette.of(context).warn),
            label: Text('경고 $warnings'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}
