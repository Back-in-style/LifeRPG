import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/theme.dart';
import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 퀘스트 — 경고 / 특별 / 주간 / 일일 (진행 중) + 최근 종료.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('퀘스트')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_quest'),
        onPressed: () => context.push('/add-quest'),
        icon: const Icon(Icons.add),
        label: const Text('퀘스트 추가'),
      ),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) {
          final active = s.activeQuests;
          final closed = s.quests
              .where((q) => !q.isActive)
              .toList()
              .reversed
              .take(30)
              .toList();
          final t = Theme.of(context).textTheme;
          final dailyLine = SgcyConfig.elements
              .map((e) =>
                  '${e.label} ${GameEngine.dailyCount(s.quests, e.key, s.today)}/${SgcyConfig.dailyCapPerElement}')
              .join('  ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              Text('오늘 일일 퀘스트  $dailyLine', style: t.bodySmall),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                        '진행 중인 퀘스트가 없어요.\n'
                        '연동 탭에서 Claude 업데이트를 붙여 넣거나 직접 추가하세요.',
                        textAlign: TextAlign.center),
                  ),
                ),
              for (final kind in QuestKind.all)
                if (active.any((q) => q.kind == kind)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                    child: Row(children: [
                      Icon(Labels.kindIcon(kind), size: 18),
                      const SizedBox(width: 6),
                      Text('${QuestKind.labels[kind]} 퀘스트',
                          style: t.titleMedium),
                    ]),
                  ),
                  for (final q in active.where((q) => q.kind == kind))
                    QuestCard(quest: q, today: s.today),
                ],
              if (closed.isNotEmpty)
                ExpansionTile(
                  title: Text('최근 종료 (${closed.length})'),
                  children: [
                    for (final q in closed)
                      ListTile(
                        dense: true,
                        leading: Icon(Labels.kindIcon(q.kind)),
                        title: Text(q.title),
                        subtitle: Text(
                            '${q.closedDate ?? ''} · ${q.kindLabel} · ${q.status.label}'),
                        trailing: IconButton(
                          tooltip: '기록 삭제',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(gameControllerProvider.notifier)
                              .deleteQuest(q.id),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class QuestCard extends ConsumerWidget {
  const QuestCard({super.key, required this.quest, required this.today});

  final Quest quest;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quest;
    final t = Theme.of(context).textTheme;
    final color = SgcyPalette.of(context).element(q.element);
    final dl = Labels.deadlineText(q, today);
    final checkedToday = q.checkins.contains(today);
    final ctrl = ref.read(gameControllerProvider.notifier);

    Future<void> act(Future<EngineResult> Function() f, String done) async {
      final r = await f();
      if (!context.mounted) return;
      showSnack(context, r.error ?? done);
    }

    final details = <String>[
      if (q.rewards.isNotEmpty) Labels.rewardsText(q),
      if (q.promote != null)
        '${Labels.substatLabel(q.promote!)} 승급 → Lv${q.level}',
      if (q.grantSkill != null) '스킬 「${q.grantSkill!.name}」',
      if (q.severity != null) '심각도 ${Severity.labels[q.severity]}',
    ];

    return Card(
      key: Key('quest_${q.id}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: q.isWarning
            ? BorderSide(color: SgcyPalette.of(context).warn)
            : BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: color.withValues(alpha: 0.25),
                  child: Text(Labels.elementHanja(q.element),
                      semanticsLabel: Labels.elementLabel(q.element),
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontFamily: SgcyPalette.of(context).wuxia
                              ? AppTheme.serif
                              : null,
                          fontFamilyFallback: const [AppTheme.sans])),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(q.title, style: t.titleSmall)),
                Text('Lv${q.level}', style: t.labelSmall),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'giveup') act(() => ctrl.giveUp(q.id), '포기했어요');
                    if (v == 'delete') {
                      act(() => ctrl.deleteQuest(q.id), '삭제했어요');
                    }
                  },
                  itemBuilder: (_) => [
                    if (!q.isWarning)
                      const PopupMenuItem(value: 'giveup', child: Text('포기')),
                    if (!q.isWarning)
                      const PopupMenuItem(value: 'delete', child: Text('삭제')),
                    if (q.isWarning)
                      const PopupMenuItem(
                          enabled: false, child: Text('경고 퀘스트는 체크인으로만 해제')),
                  ],
                ),
              ],
            ),
            if (q.desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(q.desc, style: t.bodySmall),
              ),
            if (details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(details.join(' · '),
                    style: t.bodySmall?.copyWith(
                        color: q.isWarning
                            ? SgcyPalette.of(context).warn
                            : SgcyPalette.of(context).reward)),
              ),
            if (q.hasCheckins) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LinearProgressIndicator(
                    value: q.checkins.length / q.requiredDays!, minHeight: 5),
              ),
              Text(
                  '체크인 ${q.checkins.length}/${q.requiredDays}일 (${q.windowDays}일 중)',
                  style: t.labelSmall),
            ],
            Row(
              children: [
                if (dl != null) Text(dl, style: t.labelSmall),
                const Spacer(),
                if (q.hasCheckins)
                  TextButton.icon(
                    key: Key('checkin_${q.id}'),
                    onPressed: () => act(() => ctrl.toggleCheckin(q.id),
                        checkedToday ? '체크인 취소' : '오늘 체크인!'),
                    icon: Icon(checkedToday
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
                    label: const Text('오늘 지킴'),
                  ),
                if (!q.isWarning)
                  FilledButton.tonal(
                    key: Key('complete_${q.id}'),
                    onPressed: () => act(() => ctrl.completeQuest(q.id),
                        '완료! ${details.join(' · ')}'),
                    child: const Text('완료'),
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
