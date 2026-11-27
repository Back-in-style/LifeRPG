import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/theme.dart';
import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 스킬 — 자리잡은 습관 목록. 누르면 상세·삭제.
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('스킬')),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) {
          if (s.skills.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '아직 스킬이 없어요.\n특별 퀘스트로 습관을 스킬로 만드세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: s.skills.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _SkillTile(skill: s.skills[i]),
          );
        },
      ),
    );
  }
}

class _SkillTile extends ConsumerWidget {
  const _SkillTile({required this.skill});
  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = skill;
    final color =
        k.element.isEmpty ? null : SgcyPalette.of(context).element(k.element);
    return ListTile(
      key: Key('skill_${k.id}'),
      leading: CircleAvatar(
        backgroundColor: color?.withValues(alpha: 0.25),
        child: Icon(Icons.bolt, color: color),
      ),
      title: Text(k.name),
      subtitle: Text([
        if (k.element.isNotEmpty) Labels.elementLabel(k.element),
        '획득 ${k.acquiredDate}',
        if (k.desc.isNotEmpty) k.desc,
      ].join(' · ')),
      trailing: k.failStreak > 0
          ? Chip(
              avatar: Icon(Icons.warning_amber,
                  size: 16, color: SgcyPalette.of(context).warn),
              label:
                  Text('${k.failStreak}/${SgcyConfig.skillDeleteAfterFails}'),
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: () => _showSkill(context, ref, k),
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
