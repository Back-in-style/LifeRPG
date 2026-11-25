import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 퀘스트 추가 화면. 추가에 성공하면 `true`로 pop한다.
class AddQuestScreen extends ConsumerStatefulWidget {
  const AddQuestScreen({super.key});

  @override
  ConsumerState<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends ConsumerState<AddQuestScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _xp = TextEditingController(text: '${GameConfig.defaultFlatXp}');
  final _capTo = TextEditingController();
  final _recordKey = TextEditingController();
  final _target = TextEditingController();
  final Map<String, TextEditingController> _rewards = {
    for (final k in GameConfig.statKeys) k: TextEditingController(),
  };

  String _type = 'Daily';
  String _category = GameConfig.categoryKeys.first;
  String _difficulty = 'Normal';
  late String _measure = _defaultMeasure(_category);
  String _stat = GameConfig.statKeys.first;
  String _direction = 'higher';
  String? _deadline;
  bool _saving = false;

  bool get _isBt => _type == GameConfig.breakthroughType;

  static String _defaultMeasure(String category) =>
      GameConfig.categoryDefaultMeasure[category] ?? 'flat';

  @override
  void initState() {
    super.initState();
    _capTo.text = _defaultCapTo(_stat);
  }

  String _defaultCapTo(String stat) {
    final cap = ref.read(gameControllerProvider).valueOrNull?.profile.stats[stat]?.cap ??
        GameConfig.defaultStatCap;
    return formatG(cap + GameConfig.breakthroughMinStep);
  }

  double _currentCap(String stat) =>
      ref.read(gameControllerProvider).valueOrNull?.profile.stats[stat]?.cap ??
      GameConfig.defaultStatCap;

  @override
  void dispose() {
    for (final c in [_title, _desc, _xp, _capTo, _recordKey, _target, ..._rewards.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = ref.read(clockProvider)();
    final init = tryParseDateKey(_deadline);
    final picked = await showDatePicker(
      context: context,
      initialDate: init == null
          ? now
          : DateTime(init.year, init.month, init.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) setState(() => _deadline = dateKey(picked));
  }

  /// SPEC_v1 §5.3 검증 문구. 통과하면 null 대신 draft.
  (QuestDraft?, String?) _buildDraft() {
    final title = _title.text.trim();
    if (title.isEmpty) return (null, '퀘스트 제목을 입력해줘');
    final recordKey = _recordKey.text.trim().isEmpty ? null : _recordKey.text.trim();
    double? target;
    if (_target.text.trim().isNotEmpty) {
      target = double.tryParse(_target.text.trim());
      if (target == null) return (null, '목표값은 숫자로 입력해줘');
    }
    if (_isBt) {
      final to = double.tryParse(_capTo.text.trim());
      if (to == null || to <= 0) return (null, '돌파 상한값을 올바르게 입력해줘');
      final cur = _currentCap(_stat);
      if (to <= cur) {
        return (null, '$_stat 상한값은 현재 상한(${formatG(cur)})보다 높아야 해');
      }
      if (recordKey == null) return (null, '돌파는 기록 키가 필요해 (예: 스쿼트 1RM(kg))');
      return (
        QuestDraft(
          title: title,
          desc: _desc.text,
          type: _type,
          category: GameConfig.breakthroughType,
          measureKind: 'flat',
          baseXp: 0,
          unlockStat: _stat,
          unlockTo: to,
          deadline: _deadline,
          recordKey: recordKey,
          recordDirection: _direction,
          target: target,
        ),
        null
      );
    }
    var xp = 0;
    if (_measure == 'flat') {
      final v = int.tryParse(_xp.text.trim());
      if (v == null || v <= 0) return (null, 'XP는 1 이상의 정수로 입력해줘');
      xp = v;
    }
    final rewards = <String, double>{};
    for (final e in _rewards.entries) {
      final t = e.value.text.trim();
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v == null) return (null, '${e.key} 보상은 숫자로 입력해줘');
      if (v != 0) rewards[e.key] = v;
    }
    return (
      QuestDraft(
        title: title,
        desc: _desc.text,
        type: _type,
        category: _category,
        difficulty: _difficulty,
        measureKind: _measure,
        baseXp: xp,
        rewards: rewards,
        deadline: _deadline,
        recordKey: recordKey,
        recordDirection: recordKey == null ? null : _direction,
        target: target,
      ),
      null
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    final (draft, err) = _buildDraft();
    if (draft == null) {
      showSnack(context, err ?? '입력값을 다시 확인해줘');
      return;
    }
    setState(() => _saving = true);
    final EngineResult r;
    try {
      r = await ref.read(gameControllerProvider.notifier).addQuest(draft);
    } catch (e) {
      if (mounted) showSnack(context, '퀘스트 저장 실패: $e');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (!r.ok) {
      showSnack(context, Labels.error(r.error!));
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _dropdown({
    required Key key,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? itemLabel,
  }) =>
      DropdownButtonFormField<String>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final i in items)
            DropdownMenuItem(value: i, child: Text(itemLabel?.call(i) ?? i)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀘스트 추가'),
        actions: [
          TextButton(
            key: const Key('add_submit'),
            onPressed: _saving ? null : _submit,
            child: const Text('추가'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            key: const Key('add_title'),
            controller: _title,
            decoration: const InputDecoration(labelText: '퀘스트 제목 *'),
          ),
          gap,
          SegmentedButton<String>(
            segments: [
              for (final t in GameConfig.questTypes)
                ButtonSegment(value: t, label: Text(t)),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          gap,
          if (_isBt) ..._breakthroughFields(gap) else ..._normalFields(gap),
          gap,
          _recordFields(),
          gap,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_deadline == null ? '마감일 (선택)' : '마감일: $_deadline'),
            trailing: _deadline == null
                ? null
                : IconButton(
                    tooltip: '마감일 지우기',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _deadline = null),
                  ),
            onTap: _pickDeadline,
          ),
          TextField(
            controller: _desc,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '설명 (세부 조건/루틴)'),
          ),
        ],
      ),
    );
  }

  List<Widget> _normalFields(Widget gap) => [
        Row(
          children: [
            Expanded(
              child: _dropdown(
                key: const Key('add_category'),
                label: '카테고리',
                value: _category,
                items: GameConfig.categoryKeys,
                onChanged: (v) => setState(() {
                  _category = v;
                  _measure = _defaultMeasure(v);
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                key: const Key('add_difficulty'),
                label: '난이도',
                value: _difficulty,
                items: GameConfig.difficultyMultiplier.keys.toList(),
                onChanged: (v) => setState(() => _difficulty = v),
              ),
            ),
          ],
        ),
        gap,
        _dropdown(
          key: ValueKey('add_measure_$_category'),
          label: '측정치 종류',
          value: _measure,
          items: GameConfig.measureKinds,
          itemLabel: Labels.measureKind,
          onChanged: (v) => setState(() => _measure = v),
        ),
        if (_measure == 'flat') ...[
          gap,
          TextField(
            key: const Key('add_xp'),
            controller: _xp,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'XP (숫자)', helperText: '난이도 배율이 적용돼요'),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '완료할 때 ${(GameConfig.measureFields[_measure] ?? []).map(Labels.measureField).join(' · ')}'
              '을(를) 입력하면 XP가 계산돼요 (난이도 배율 미적용).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        gap,
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('명시 스탯 보상 (선택)'),
          subtitle: const Text('비우면 카테고리에 따라 자동 분배'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in GameConfig.statKeys)
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _rewards[k],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: InputDecoration(
                          labelText: k, isDense: true, hintText: '0'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ];

  List<Widget> _breakthroughFields(Widget gap) => [
        Row(
          children: [
            Expanded(
              child: _dropdown(
                key: const Key('add_bt_stat'),
                label: '돌파 스탯',
                value: _stat,
                items: GameConfig.statKeys,
                onChanged: (v) => setState(() {
                  _stat = v;
                  _capTo.text = _defaultCapTo(v);
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('add_bt_cap'),
                controller: _capTo,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '목표 상한',
                  helperText: '현재 상한 ${formatG(_currentCap(_stat))}',
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '완료할 때 기록값을 입력해 개인기록(PR)을 세우면 상한이 올라가요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ];

  Widget _recordFields() {
    final fields = Column(
      children: [
        TextField(
          key: const Key('add_record_key'),
          controller: _recordKey,
          decoration: InputDecoration(
            labelText: _isBt ? '기록 키 *' : '기록 키',
            hintText: '예: 스쿼트 1RM(kg)',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'higher', label: Text('높을수록')),
                  ButtonSegment(value: 'lower', label: Text('낮을수록')),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
            ),
            if (_isBt) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                      labelText: '목표값', hintText: '선택', isDense: true),
                ),
              ),
            ],
          ],
        ),
      ],
    );
    if (_isBt) return fields;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('개인기록 연결 (선택)'),
      subtitle: const Text('완료할 때 기록값을 남겨 PR을 추적'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [fields],
    );
  }
}
