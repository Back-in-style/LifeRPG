import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 상태창 — 심·기·체·연 4요소. 누르면 세부스탯.
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('심기체연'),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                for (final e in SgcyConfig.elements)
                  ElementCard(state: s, element: e),
              ],
            ),
            const SizedBox(height: 12),
            _SkillsCard(state: s),
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
            avatar:
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            label: Text('경고 $warnings'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

/// 주요 요소 카드: 큰 글자 + 레벨 + 세부스탯 미니 막대.
class ElementCard extends StatelessWidget {
  const ElementCard({super.key, required this.state, required this.element});

  final GameState state;
  final ElementDef element;

  @override
  Widget build(BuildContext context) {
    final color = Labels.elementColor(element.key);
    final lv = state.elementLevel(element.key);
    final floor = state.elementRewardLevel(element.key);
    final t = Theme.of(context).textTheme;
    return Card(
      key: Key('element_${element.key}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/element/${element.key}'),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.28), Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(element.label,
                      style: t.displaySmall?.copyWith(
                          color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(element.meaning,
                        style: t.bodySmall, overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Labels.elementIcon(element.key), color: color, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text('Lv ${lv.toStringAsFixed(1)}',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(SgcyConfig.levelName(floor),
                  style:
                      t.bodyMedium?.copyWith(color: Labels.levelColor(floor))),
              const Spacer(),
              for (final k in element.substats) _MiniBar(sub: state.substat(k)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.sub});
  final SubStat sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(sub.label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis),
          ),
          Text('${sub.level}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Labels.levelColor(sub.level))),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: sub.gauge,
                minHeight: 4,
                color: Labels.levelColor(sub.level),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsCard extends ConsumerWidget {
  const _SkillsCard({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('스킬', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (state.skills.isEmpty)
              const Text('아직 스킬이 없어요. 특별 퀘스트로 습관을 스킬로 만드세요.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in state.skills)
                    ActionChip(
                      avatar: Icon(Icons.bolt,
                          size: 16, color: Labels.elementColor(k.element)),
                      label: Text(k.failStreak > 0
                          ? '${k.name} ⚠${k.failStreak}'
                          : k.name),
                      onPressed: () => _showSkill(context, ref, k),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSkill(BuildContext context, WidgetRef ref, Skill k) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(k.name),
        content: Text([
          if (k.desc.isNotEmpty) k.desc,
          if (k.element.isNotEmpty) '요소: ${Labels.elementLabel(k.element)}',
          '획득: ${k.acquiredDate}',
          '경고 연속 실패: ${k.failStreak}/${SgcyConfig.skillDeleteAfterFails}',
        ].join('\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('스킬 삭제')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('닫기')),
        ],
      ),
    );
    if (remove == true) {
      await ref.read(gameControllerProvider.notifier).removeSkill(k.id);
    }
  }
}
