import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 완료에 입력(측정치·기록값)이 필요한가.
bool completionNeedsInput(Quest q) =>
    !q.isFlat || (q.recordKey != null && !q.isLegacyBreakthrough);

/// 퀘스트 완료 플로우: (필요하면) 입력 → 엔진 → 결과 다이얼로그.
Future<void> runCompleteFlow(
    BuildContext context, WidgetRef ref, Quest quest) async {
  if (quest.isDone) {
    showSnack(context, Labels.error(GameError.alreadyDone));
    return;
  }
  var input = CompletionInput.none;
  if (completionNeedsInput(quest)) {
    final state = ref.read(gameControllerProvider).valueOrNull;
    final got = await showDialog<CompletionInput>(
      context: context,
      builder: (_) => CompletionInputDialog(
          quest: quest, record: state?.records[quest.recordKey]),
    );
    if (got == null || !context.mounted) return;
    input = got;
  }
  final CompletionResult r;
  try {
    r = await ref
        .read(gameControllerProvider.notifier)
        .completeQuest(quest.id, input);
  } catch (e) {
    if (context.mounted) showSnack(context, '완료 저장 실패: $e');
    return;
  }
  if (!context.mounted) return;
  if (!r.ok) {
    showSnack(context, Labels.error(r.error!));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => CompletionResultDialog(quest: quest, result: r),
  );
}

/// 측정치 / 기록값 입력 다이얼로그. 확인 시 [CompletionInput]을 돌려준다.
class CompletionInputDialog extends StatefulWidget {
  const CompletionInputDialog({super.key, required this.quest, this.record});

  final Quest quest;
  final PersonalRecord? record;

  @override
  State<CompletionInputDialog> createState() => _CompletionInputDialogState();
}

class _CompletionInputDialogState extends State<CompletionInputDialog> {
  late final List<String> _fields =
      GameConfig.measureFields[widget.quest.measureKind] ?? const [];
  late final Map<String, TextEditingController> _ctrls = {
    for (final f in _fields) f: TextEditingController(),
  };
  final TextEditingController _recordCtrl = TextEditingController();
  final Map<String, String?> _errors = {};
  String? _recordError;
  bool _zeroWarned = false;
  String? _zeroWarning;

  Quest get q => widget.quest;
  bool get _hasRecord => q.recordKey != null && !q.isLegacyBreakthrough;
  bool get _recordRequired => q.isBreakthrough;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _recordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final values = <String, double>{};
    _errors.clear();
    _recordError = null;
    for (final f in _fields) {
      final v = double.tryParse(_ctrls[f]!.text.trim());
      if (v == null || !v.isFinite || v < 0) {
        _errors[f] = '0 이상의 숫자를 입력해줘';
      } else {
        values[f] = v;
      }
    }
    // 0은 허용(예: 맨몸 무게 0kg). 전부 0이면 XP가 없으므로 한 번 경고한다.
    if (_errors.isEmpty &&
        _fields.isNotEmpty &&
        values.values.every((v) => v == 0) &&
        !_zeroWarned) {
      _zeroWarned = true;
      _zeroWarning = '모든 값이 0이에요. 그대로 완료하려면 한 번 더 눌러줘';
      setState(() {});
      return;
    }
    _zeroWarning = null;
    double? recordValue;
    if (_hasRecord) {
      final t = _recordCtrl.text.trim();
      if (t.isEmpty) {
        if (_recordRequired) _recordError = '돌파는 기록값이 필요해';
      } else {
        recordValue = double.tryParse(t);
        if (recordValue == null || !recordValue.isFinite) {
          _recordError = '숫자를 입력해줘';
        }
      }
    }
    if (_errors.isNotEmpty || _recordError != null) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      CompletionInput(
        measurement: _fields.isEmpty
            ? null
            : Measurement(kind: q.measureKind, values: values),
        recordValue: recordValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = widget.record?.best;
    final dirLabel = (q.recordDirection ?? 'higher') == 'lower' ? '낮을수록 좋음' : '높을수록 좋음';
    return AlertDialog(
      title: Text(q.isBreakthrough ? '💥 돌파 기록 입력' : '측정값 입력'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.title, style: theme.textTheme.titleSmall),
            if (_fields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(Labels.measureKind(q.measureKind),
                  style: theme.textTheme.bodySmall),
            ],
            for (final f in _fields)
              TextField(
                key: Key('measure_$f'),
                controller: _ctrls[f],
                keyboardType: TextInputType.numberWithOptions(
                    decimal: !Labels.integerFields.contains(f)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: Labels.measureField(f),
                  errorText: _errors[f],
                ),
              ),
            if (_zeroWarning != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_zeroWarning!,
                    key: const Key('zero_warning'),
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (_hasRecord) ...[
              const SizedBox(height: 16),
              Text('기록: ${q.recordKey} ($dirLabel)',
                  style: theme.textTheme.bodyMedium),
              Text(
                best == null
                    ? (q.target != null
                        ? '첫 기록 — 목표 ${Labels.num(q.target!)} 달성 시 PR'
                        : '첫 기록 — 기준으로 등록돼요')
                    : '현재 최고: ${Labels.num(best)}',
                style: theme.textTheme.bodySmall,
              ),
              TextField(
                key: const Key('record_value'),
                controller: _recordCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: _recordRequired ? '기록값 *' : '기록값 (선택)',
                  errorText: _recordError,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
            key: const Key('complete_submit'),
            onPressed: _submit,
            child: const Text('완료 ✓')),
      ],
    );
  }
}

/// 완료 결과 다이얼로그 (XP, 레벨업, 스탯 상승, PR, 돌파, 새 업적).
class CompletionResultDialog extends StatelessWidget {
  const CompletionResultDialog(
      {super.key, required this.quest, required this.result});

  final Quest quest;
  final CompletionResult result;

  List<String> _lines() {
    final r = result;
    final treeLabel =
        r.tree == null ? null : (GameConfig.treeLabels[r.tree] ?? r.tree);
    final lines = <String>[
      if (r.xp > 0) '+${r.xp} XP${treeLabel == null ? '' : ' ($treeLabel)'}',
      if (r.leveledUp)
        '🎉 레벨업! ${treeLabel ?? ''} Lv.${r.newTreeLevel ?? ''}'.trim(),
      if (r.statGains.isNotEmpty)
        '스탯 상승: ${r.statGains.entries.map((e) => '${e.key} +${Labels.num(e.value)}').join(', ')}',
      if (r.isPr) '📈 개인기록 갱신!',
    ];
    final bt = r.breakthrough;
    if (bt != null) {
      lines.add(bt.success
          ? '💥 돌파 성공! ${bt.stat} 상한 ${Labels.num(bt.oldCap)} → ${Labels.num(bt.newCap)}'
          : '돌파 실패 (상한 ${Labels.num(bt.oldCap)} 유지) — 기록을 갱신해야 해');
    }
    for (final id in r.newAchievements) {
      final def = GameConfig.achievements.where((a) => a.id == id).firstOrNull;
      if (def != null) lines.add('🏆 업적 달성: ${def.icon} ${def.name}');
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    return AlertDialog(
      title: const Text('퀘스트 완료! ✅'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quest.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (lines.isEmpty) const Text('수고했어요!'),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l),
            ),
        ],
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('확인')),
      ],
    );
  }
}
