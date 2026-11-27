import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 퀘스트 직접 추가. 보상은 규칙으로 자동 계산된다.
class AddQuestScreen extends ConsumerStatefulWidget {
  const AddQuestScreen({super.key, this.initialKind});

  final String? initialKind;

  @override
  ConsumerState<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends ConsumerState<AddQuestScreen> {
  late String _kind = QuestKind.all.contains(widget.initialKind)
      ? widget.initialKind!
      : QuestKind.daily;
  String _element = 'che';
  final Set<String> _subs = {};
  double _scale = 1;
  String _severity = Severity.normal;
  String? _promote;
  int? _skillId;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _skillName = TextEditingController();
  final _statAmount = TextEditingController();
  final _required = TextEditingController();
  final _window = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _desc,
      _skillName,
      _statAmount,
      _required,
      _window
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _elementSubs => SgcyConfig.elementByKey[_element]!.substats;

  QuestDraft _draft() {
    final weights = {for (final k in _subs) k: 1.0};
    final amount = double.tryParse(_statAmount.text.trim()) ?? 0;
    final special = _kind == QuestKind.special;
    return QuestDraft(
      kind: _kind,
      title: _title.text,
      desc: _desc.text,
      element: _element,
      weights: weights,
      scale: _scale,
      statRewards: special && amount > 0
          ? distribute(amount, weights, _element)
          : const {},
      promote: special ? _promote : null,
      grantSkill: special && _skillName.text.trim().isNotEmpty
          ? SkillGrant(name: _skillName.text.trim(), element: _element)
          : null,
      skillId: _kind == QuestKind.warning ? _skillId : null,
      severity: _kind == QuestKind.warning ? _severity : null,
      requiredDays: int.tryParse(_required.text.trim()),
      windowDays: int.tryParse(_window.text.trim()),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r =
        await ref.read(gameControllerProvider.notifier).addQuest(_draft());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      context.pop();
    } else {
      showSnack(context, r.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('퀘스트 추가')),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                for (final k in [
                  QuestKind.daily,
                  QuestKind.weekly,
                  QuestKind.special,
                  QuestKind.warning
                ])
                  ButtonSegment(value: k, label: Text(QuestKind.labels[k]!)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final e in SgcyConfig.elements)
                  ButtonSegment(value: e.key, label: Text(e.label)),
              ],
              selected: {_element},
              onSelectionChanged: (v) => setState(() {
                _element = v.first;
                _subs.clear();
                _promote = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quest_title'),
              controller: _title,
              decoration: const InputDecoration(
                  labelText: '제목', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: '설명 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text('관련 세부스탯 (고르지 않으면 균등 분배)',
                style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                for (final k in _elementSubs)
                  FilterChip(
                    label: Text(Labels.substatLabel(k)),
                    selected: _subs.contains(k),
                    onSelected: (v) =>
                        setState(() => v ? _subs.add(k) : _subs.remove(k)),
                  ),
              ],
            ),
            if (_kind != QuestKind.special) ...[
              const SizedBox(height: 8),
              Text('난이도 보정 ×${_scale.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _scale,
                min: SgcyConfig.minScale,
                max: SgcyConfig.maxScale,
                divisions: 8,
                label: _scale.toStringAsFixed(1),
                onChanged: (v) => setState(() => _scale = v),
              ),
            ],
            ..._kindFields(s),
            const SizedBox(height: 12),
            _Preview(state: s, draft: _draft()),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save_quest'),
              onPressed: _busy ? null : _save,
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindFields(GameState s) {
    Widget days(String hintReq, String hintWin) => Row(
          children: [
            Expanded(
              child: TextField(
                controller: _required,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: '지킬 일수', hintText: hintReq),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _window,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: '기간(일)', hintText: hintWin),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        );
    switch (_kind) {
      case QuestKind.special:
        return [
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _promote,
            decoration: const InputDecoration(labelText: '승급 보상 (선택)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('없음')),
              for (final k in _elementSubs)
                DropdownMenuItem(
                  value: k,
                  child: Text('${Labels.substatLabel(k)} '
                      '${s.substat(k).level} → ${s.substat(k).level + 1}레벨'),
                ),
            ],
            onChanged: (v) => setState(() => _promote = v),
          ),
          TextField(
            controller: _statAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '스탯 보상 총량 (선택)'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _skillName,
            decoration:
                const InputDecoration(labelText: '스킬 보상 이름 (선택, 예: 퀵 슬립)'),
            onChanged: (_) => setState(() {}),
          ),
          days('예: 24', '예: 30 (습관형일 때)'),
        ];
      case QuestKind.warning:
        return [
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final k in Severity.all)
                ButtonSegment(value: k, label: Text(Severity.labels[k]!)),
            ],
            selected: {_severity},
            onSelectionChanged: (v) => setState(() => _severity = v.first),
          ),
          DropdownButtonFormField<int?>(
            initialValue: _skillId,
            decoration: const InputDecoration(labelText: '연결 스킬 (선택)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('없음')),
              for (final k in s.skills)
                DropdownMenuItem(value: k.id, child: Text(k.name)),
            ],
            onChanged: (v) => setState(() => _skillId = v),
          ),
          days('${SgcyConfig.warningRequiredDays}',
              '${SgcyConfig.warningWindowDays}'),
        ];
      default:
        return const [];
    }
  }
}

/// 엔진으로 미리 계산한 보상.
class _Preview extends StatelessWidget {
  const _Preview({required this.state, required this.draft});
  final GameState state;
  final QuestDraft draft;

  @override
  Widget build(BuildContext context) {
    final d = QuestDraft(
      kind: draft.kind,
      title: draft.title.trim().isEmpty ? '미리보기' : draft.title,
      element: draft.element,
      weights: draft.weights,
      scale: draft.scale,
      statRewards: draft.statRewards,
      promote: draft.promote,
      grantSkill: draft.grantSkill,
      severity: draft.severity,
      requiredDays: draft.requiredDays,
      windowDays: draft.windowDays,
    );
    final r = const GameEngine().addQuest(state, d, DateTime.now());
    final text = r.ok
        ? questLine(r.state.quests.last).replaceFirst(RegExp(r'^#\d+ '), '')
        : r.error!;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${r.ok ? '보상: ' : '⚠ '}$text',
          style: TextStyle(color: r.ok ? null : Colors.orange),
        ),
      ),
    );
  }
}
