import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/data/game_repository.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';

/// 레거시 JSON 가져오기 — 4개 파일 내용을 붙여 넣는다 (파일 선택 패키지 없이).
class LegacyImportScreen extends ConsumerStatefulWidget {
  const LegacyImportScreen({super.key});

  @override
  ConsumerState<LegacyImportScreen> createState() => _LegacyImportScreenState();
}

class _LegacyImportScreenState extends ConsumerState<LegacyImportScreen> {
  static const _files = ['profile.json', 'quests.json', 'log.json', 'achievements.json'];
  final Map<String, TextEditingController> _ctrls = {
    for (final f in _files) f: TextEditingController(),
  };
  bool _busy = false;
  ImportReport? _report;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(String f) {
    final t = _ctrls[f]!.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _import() async {
    final bundle = LegacyBundle(
      profileJson: _text('profile.json'),
      questsJson: _text('quests.json'),
      logJson: _text('log.json'),
      achievementsJson: _text('achievements.json'),
    );
    if (bundle.isEmpty) {
      showSnack(context, 'JSON을 하나 이상 붙여 넣어줘');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기존 데이터 대체'),
        content: const Text('현재 데이터(퀘스트·스탯·로그·업적)를 모두 지우고 '
            '레거시 데이터로 대체할까요? (되돌리기 어려움)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              key: const Key('import_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('대체')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final report =
          await ref.read(gameControllerProvider.notifier).importLegacy(bundle);
      if (!mounted) return;
      setState(() => _report = report);
      showSnack(context, '가져오기 완료!');
    } catch (e) {
      if (mounted) showSnack(context, '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('레거시 데이터 가져오기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '기존 앱 데이터 폴더의 파일 내용을 각 칸에 붙여 넣으세요. '
            '없는 파일은 비워 두면 됩니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final f in _files) ...[
            TextField(
              key: Key('import_$f'),
              controller: _ctrls[f],
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: f,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const Key('import_run'),
            onPressed: _busy ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download),
            label: const Text('가져오기'),
          ),
          if (report != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가져오기 결과', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('퀘스트 ${report.quests}개 · 이벤트 ${report.events}개 · '
                        '업적 ${report.achievements}개'),
                    if (report.warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('경고', style: theme.textTheme.titleSmall),
                      for (final w in report.warnings)
                        Text('• $w', style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
