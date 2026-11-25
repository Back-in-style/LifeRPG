import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import 'quest_format.dart';

/// 상세 시트에서 고른 동작.
enum QuestDetailAction { complete, delete }

/// 퀘스트 상세 (정보, 진행률 슬라이더). 완료/삭제는 호출 쪽에서 처리한다.
class QuestDetailSheet extends ConsumerStatefulWidget {
  const QuestDetailSheet({super.key, required this.quest, required this.today});

  final Quest quest;
  final String today;

  @override
  ConsumerState<QuestDetailSheet> createState() => _QuestDetailSheetState();
}

class _QuestDetailSheetState extends ConsumerState<QuestDetailSheet> {
  late double _progress = widget.quest.progress.toDouble();

  Quest get q => widget.quest;
  bool get _showProgress =>
      (q.type == 'Side' || q.type == 'Main') && !q.isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dday = ddayLabel(q.deadline, widget.today);
    final infos = <String>[
      '종류: ${q.type}  |  카테고리: ${q.category}',
      if (!q.isBreakthrough) '보상: ${questRewardText(q)}  |  난이도: ${q.difficulty}',
      if (q.isBreakthrough) '돌파: ${q.unlockStat} 상한 → ${q.unlockTo == null ? '?' : formatG(q.unlockTo!)}',
      if (q.recordKey != null)
        '기록: ${q.recordKey} (${q.recordDirection == 'lower' ? '낮을수록 좋음' : '높을수록 좋음'})'
            '${q.target == null ? '' : '  목표 ${formatG(q.target!)}'}',
      '상태: ${q.isDone ? '완료됨 ✅' : '진행중 ⬜'}',
      if (q.deadline != null) '마감: ${q.deadline}  $dday',
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('[${q.type}] ${q.title}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final t in infos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(t, style: theme.textTheme.bodyMedium),
              ),
            if (q.desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('설명', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(q.desc, style: theme.textTheme.bodyMedium),
            ],
            if (_showProgress) ...[
              const SizedBox(height: 12),
              Text('진행률: ${_progress.round()}%',
                  style: theme.textTheme.titleSmall),
              Slider(
                key: const Key('progress_slider'),
                value: _progress,
                max: 100,
                divisions: 20,
                label: '${_progress.round()}%',
                onChanged: (v) => setState(() => _progress = v),
                onChangeEnd: (v) => ref
                    .read(gameControllerProvider.notifier)
                    .updateProgress(q.id, v.round()),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  onPressed: () =>
                      Navigator.pop(context, QuestDetailAction.delete),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                ),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기')),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('detail_complete'),
                  onPressed: q.isDone
                      ? null
                      : () => Navigator.pop(context, QuestDetailAction.complete),
                  child: const Text('완료 ✓'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
