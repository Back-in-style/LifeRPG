import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';

/// Claude 연동 — ① 대화 전에 상태를 복사해 넘기고 ② 대화 후 업데이트 파일을 붙여 넣는다.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, '$what 복사했어요. Claude 대화창에 붙여 넣으세요.');
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => _input.text = d!.text!);
  }

  Future<void> _apply() async {
    UpdateBundle u;
    try {
      u = UpdateBundle.fromJson(extractJsonObject(_input.text));
    } on FormatException catch (e) {
      showSnack(context, '읽을 수 없어요: ${e.message}',
          duration: const Duration(seconds: 4));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('업데이트 적용 (${u.date ?? '날짜 없음'})'),
        content: SingleChildScrollView(
          child: Text([
            if (u.summary.isNotEmpty) '요약: ${u.summary}',
            '퀘스트 ${u.quests.length}개',
            for (final q in u.quests)
              '  · [${QuestKind.labels[q.kind]}] ${q.title}',
            '관찰 기록 ${u.observations.length}개',
            if (u.placements.isNotEmpty)
              '레벨 배치: ${u.placements.entries.map((e) => '${SgcyConfig.substatByKey[e.key]!.label} ${e.value}').join(', ')}',
            if (u.profileNotes != null)
              '나에 대한 메모 ${u.profileNotes!.length}줄로 교체',
            if (u.problems.isNotEmpty) '⚠ 무시되는 항목 ${u.problems.length}개',
          ].join('\n')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              key: const Key('confirm_update'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('적용')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(gameControllerProvider.notifier).applyUpdate(u);
    if (!mounted) return;
    setState(() => _busy = false);
    _input.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('적용 완료'),
        content: SingleChildScrollView(
          child: Text([
            '추가된 퀘스트 ${r.added.length}개',
            for (final q in r.added) '  · ${questLine(q)}',
            if (r.skipped.isNotEmpty) '\n건너뛴 항목 ${r.skipped.length}개',
            for (final x in r.skipped) '  · $x',
          ].join('\n')),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('상태 파일로 복원'),
        content: TextField(
          controller: c,
          maxLines: 8,
          decoration: const InputDecoration(
              hintText: '"format": "sgcy-state" JSON을 붙여 넣으세요',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('현재 상태 덮어쓰기')),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      final s = GameState.fromJson(
          extractJsonObject(text), ref.read(clockProvider)());
      await ref.read(gameControllerProvider.notifier).restoreState(s);
      if (mounted) showSnack(context, '복원했어요.');
    } on FormatException catch (e) {
      if (mounted) showSnack(context, '복원 실패: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Claude 연동')),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) {
          final briefing = buildBriefing(s);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('① 대화 시작 전', style: t.titleMedium),
                      const SizedBox(height: 4),
                      const Text('현재 상태를 복사해 Claude 대화창에 붙여 넣으세요. '
                          '대화 에이전트가 이걸 읽고 하루를 자세히 물어봅니다.'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const Key('copy_handoff'),
                            onPressed: () => _copy(
                                '$briefing\n\n## 상태 파일\n\n```json\n${exportStateJson(s)}\n```',
                                '브리핑 + 상태 파일을'),
                            icon: const Icon(Icons.copy),
                            label: const Text('브리핑+상태 복사'),
                          ),
                          OutlinedButton(
                            onPressed: () => _copy(briefing, '브리핑을'),
                            child: const Text('브리핑만'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _copy(exportStateJson(s), '상태 JSON을'),
                            child: const Text('상태 JSON만'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('② 대화가 끝나면', style: t.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                          'Claude가 준 통합 업데이트 파일(sgcy-update JSON)을 붙여 넣고 적용하세요. '
                          '코드블록째 붙여 넣어도 됩니다.'),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('update_input'),
                        controller: _input,
                        maxLines: 6,
                        minLines: 3,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: '{"format": "sgcy-update", ...}',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _paste,
                            icon: const Icon(Icons.content_paste),
                            label: const Text('붙여넣기'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            key: const Key('apply_update'),
                            onPressed: _busy || _input.text.trim().isEmpty
                                ? null
                                : _apply,
                            icon: const Icon(Icons.download_done),
                            label: const Text('적용'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ExpansionTile(
                title: const Text('브리핑 미리보기'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(briefing,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('상태 파일로 복원'),
                subtitle: const Text('백업해 둔 상태 JSON으로 되돌리기'),
                onTap: _restore,
              ),
            ],
          );
        },
      ),
    );
  }
}
