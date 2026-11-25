import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';
import 'add_quest_screen.dart';
import 'completion_flow.dart';
import 'quest_detail_sheet.dart';
import 'quest_format.dart';

/// 필터 (키, 표시 이름). SPEC_v1 §5.3의 All/Daily/Side/Main/돌파 + 진행중/완료.
const List<(String, String)> questFilters = [
  ('All', '전체'),
  ('Daily', 'Daily'),
  ('Main', 'Main'),
  ('Side', 'Side'),
  ('돌파', '돌파'),
  ('active', '진행중'),
  ('done', '완료'),
];

/// 퀘스트 — 필터 칩, Daily 그룹, 추가/상세/완료(측정치 입력).
class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  String _filter = 'All';

  bool _match(Quest q) => switch (_filter) {
        'All' => true,
        'active' => !q.isDone,
        'done' => q.isDone,
        final t => q.type == t,
      };

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AddQuestScreen(),
    ));
    if (added == true && mounted) showSnack(context, '퀘스트가 추가되었습니다!');
  }

  Future<void> _openDetail(Quest q, String today) async {
    // 스낵바가 시트의 버튼을 가리지 않게 닫는다.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final action = await showModalBottomSheet<QuestDetailAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuestDetailSheet(quest: q, today: today),
    );
    if (!mounted || action == null) return;
    // 슬라이더로 바뀐 진행률 등을 반영한 최신 퀘스트.
    final latest =
        ref.read(gameControllerProvider).valueOrNull?.questById(q.id) ?? q;
    switch (action) {
      case QuestDetailAction.complete:
        await runCompleteFlow(context, ref, latest);
      case QuestDetailAction.delete:
        await _confirmDelete(latest);
    }
  }

  Future<void> _confirmDelete(Quest q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('퀘스트 삭제'),
        content: Text("'${q.title}' 퀘스트를 삭제할까요?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              key: const Key('delete_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r =
          await ref.read(gameControllerProvider.notifier).deleteQuest(q.id);
      if (!mounted) return;
      showSnack(context, r.ok ? '퀘스트가 삭제되었습니다.' : Labels.error(r.error!));
    } catch (e) {
      if (mounted) showSnack(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 퀘스트'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                for (final (key, label) in questFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filter_$key'),
                      label: Text(label),
                      selected: _filter == key,
                      onSelected: (_) => setState(() => _filter = key),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) => _buildList(context, s),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_quest_fab'),
        tooltip: '퀘스트 추가',
        onPressed: game.hasValue ? _openAdd : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(BuildContext context, GameState s) {
    final today = s.profile.todayDate;
    final filtered = s.quests.where(_match).toList()
      ..sort((a, b) {
        final d = (a.isDone ? 1 : 0).compareTo(b.isDone ? 1 : 0);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('퀘스트가 없습니다. + 버튼으로 추가하세요.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final children = <Widget>[];
    Widget tile(Quest q) =>
        _QuestTile(quest: q, today: today, onTap: () => _openDetail(q, today));

    final grouped = _filter == 'All' || _filter == 'Daily';
    if (grouped) {
      final daily = filtered.where((q) => q.type == 'Daily').toList();
      final others = filtered.where((q) => q.type != 'Daily').toList();
      for (final (key, label) in GameConfig.dailyGroups) {
        final g = daily.where((q) => dailyGroupOf(q) == key).toList();
        if (g.isEmpty) continue;
        final active = g.where((q) => !q.isDone).length;
        children.add(_GroupHeader('$label  ($active개)'));
        children.addAll(g.map(tile));
      }
      if (others.isNotEmpty) {
        children.add(const _GroupHeader('── Side / Main / 돌파 ──', accent: true));
        children.addAll(others.map(tile));
      }
    } else {
      children.addAll(filtered.map(tile));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: children,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text, {this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: (accent ? scheme.secondary : scheme.primary).withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile(
      {required this.quest, required this.today, required this.onTap});
  final Quest quest;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final theme = Theme.of(context);
    final dday = ddayLabel(q.deadline, today);
    final overdue = dday.startsWith('D+');
    final sub = [
      questRewardText(q),
      if (!q.isBreakthrough) '난이도: ${q.difficulty}',
      '카테고리: ${q.category}',
      if ((q.type == 'Side' || q.type == 'Main') && q.progress > 0 && !q.isDone)
        '진행률 ${q.progress}%',
    ].join('  ');
    return ListTile(
      onTap: onTap,
      leading: Icon(
        q.isDone ? Icons.check_box : Icons.check_box_outline_blank,
        color: q.isDone ? theme.colorScheme.secondary : null,
      ),
      title: Text(
        '[${q.type}] ${q.title}',
        style: q.isDone
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(sub),
      trailing: dday.isEmpty
          ? null
          : Text(dday,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: overdue ? theme.colorScheme.error : theme.colorScheme.secondary,
              )),
    );
  }
}
