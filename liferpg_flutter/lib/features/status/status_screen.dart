import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 상태창 — 메인 레벨, 오늘 XP, 스트릭, 스탯 7종, 스킬 트리 7종, 업적.
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔ LifeRPG'),
        actions: [
          IconButton(
            tooltip: '업적',
            icon: const Icon(Icons.emoji_events),
            onPressed: game.hasValue
                ? () => showAchievementsDialog(context, game.requireValue)
                : null,
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _LevelCard(state: s),
            const _SectionTitle('스탯'),
            for (final k in GameConfig.statKeys)
              if (s.profile.stats[k] != null) _StatTile(stat: s.profile.stats[k]!),
            const _SectionTitle('스킬 트리'),
            for (final k in GameConfig.treeKeys)
              _TreeTile(treeKey: k, info: s.profile.treeLevel(k),
                  totalXp: s.profile.trees[k]?.totalXp ?? 0),
            const _SectionTitle('업적'),
            _AchievementSummary(state: s),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _LevelCard extends ConsumerWidget {
  const _LevelCard({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = state.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Main Lv. ${p.mainLevel}',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: scheme.secondary)),
            const SizedBox(height: 4),
            Text('오늘: ${p.todayDate}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _Metric(
                        icon: Icons.auto_awesome,
                        label: 'Today XP',
                        value: '${p.todayXp}')),
                Expanded(
                    child: _Metric(
                        icon: Icons.local_fire_department,
                        label: '스트릭',
                        value: '${p.streakDays}일')),
                Expanded(
                    child: _Metric(
                        icon: Icons.task_alt,
                        label: '누적 완료',
                        value: '${p.totalCompletions}')),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('reset_today_xp'),
                onPressed: () => _confirmResetTodayXp(context, ref),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('오늘 XP 초기화'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.secondary),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final StatState stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = gradeFromCap(stat.cap);
    final color = Labels.gradeColor(grade);
    final ratio = stat.cap <= 0 ? 0.0 : (stat.value / stat.cap).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${GameConfig.statIcons[stat.key] ?? ''} ${stat.key}',
                      style: theme.textTheme.titleSmall),
                ),
                Text(stat.value.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(' / ${Labels.num(stat.cap)}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(grade,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile(
      {required this.treeKey, required this.info, required this.totalXp});
  final String treeKey;
  final LevelInfo info;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${GameConfig.treeIcons[treeKey] ?? ''} '
                    '${GameConfig.treeLabels[treeKey] ?? treeKey}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('Lv. ${info.level}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.secondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '총 XP: $totalXp   |   다음 레벨까지: '
              '${info.xpForNext - info.xpInLevel} XP',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: info.progress.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final unlocked = state.unlockedAchievements;
    return Card(
      child: Column(
        children: [
          for (final a in GameConfig.achievements) _AchievementTile(a, unlocked.contains(a.id)),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(this.def, this.unlocked);
  final AchievementDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Text(unlocked ? def.icon : '🔒',
          style: const TextStyle(fontSize: 22)),
      title: Text(def.name,
          style: unlocked
              ? const TextStyle(fontWeight: FontWeight.bold)
              : TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(unlocked ? def.desc : '???'),
    );
  }
}

/// 업적 다이얼로그 (해금 수 / 전체).
Future<void> showAchievementsDialog(BuildContext context, GameState s) {
  final unlocked = s.unlockedAchievements;
  final count =
      GameConfig.achievements.where((a) => unlocked.contains(a.id)).length;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('🏆 업적 ($count/${GameConfig.achievements.length})'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in GameConfig.achievements)
              _AchievementTile(a, unlocked.contains(a.id)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
      ],
    ),
  );
}

/// 오늘 XP 초기화 확인 (SPEC_v1 §5.2).
Future<void> _confirmResetTodayXp(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('오늘 XP 초기화'),
      content: const Text('오늘 XP를 0으로 초기화할까요? (되돌리기 어려움)'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
            key: const Key('reset_today_xp_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final r = await ref.read(gameControllerProvider.notifier).resetTodayXp();
    if (!context.mounted) return;
    showSnack(context, r.ok ? '오늘 XP가 초기화되었습니다.' : Labels.error(r.error!));
  } catch (e) {
    if (context.mounted) showSnack(context, '초기화 실패: $e');
  }
}
