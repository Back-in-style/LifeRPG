import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 로그 — 최근 200개 이벤트, 최신순.
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(recentEventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('📜 로그'),
        actions: [
          IconButton(
            tooltip: '로그 삭제',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: AsyncView<List<LogEvent>>(
        value: events,
        builder: (context, list) {
          if (list.isEmpty) {
            return const Center(child: Text('로그가 없습니다.'));
          }
          final scheme = Theme.of(context).colorScheme;
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = list[i];
              return ListTile(
                dense: true,
                leading: Icon(Labels.logIcon(e.type), color: scheme.secondary),
                title: Text(e.message),
                subtitle: Text(formatTimestamp(e.ts)),
              );
            },
          );
        },
      ),
    );
  }
}

/// 로그 삭제 확인 (SPEC_v1 §5.4).
Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('로그 삭제'),
      content: const Text('모든 로그를 삭제할까요? (되돌리기 어려움)'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
            key: const Key('clear_logs_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(gameControllerProvider.notifier).clearEvents();
    if (!context.mounted) return;
    ref.invalidate(recentEventsProvider);
    showSnack(context, '로그가 삭제되었습니다.');
  } catch (e) {
    if (context.mounted) showSnack(context, '로그 삭제 실패: $e');
  }
}
