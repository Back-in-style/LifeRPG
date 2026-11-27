import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/domain/domain.dart';

import '../../app/providers.dart';
import '../common/async_view.dart';
import '../common/labels.dart';

/// 주요 요소 상세 — 세부스탯 레벨·스탯 게이지·강등선·보호·자연 감소.
class ElementScreen extends ConsumerWidget {
  const ElementScreen({super.key, required this.elementKey});

  final String elementKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = SgcyConfig.elementByKey[elementKey];
    final game = ref.watch(gameControllerProvider);
    if (def == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('없는 요소')));
    }
    final color = Labels.elementColor(def.key);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${def.label}${def.hanja.isEmpty ? '' : ' ${def.hanja}'} · ${def.meaning}'),
      ),
      body: AsyncView<GameState>(
        value: game,
        builder: (context, s) {
          final lv = s.elementLevel(def.key);
          final rl = s.elementRewardLevel(def.key);
          final t = Theme.of(context).textTheme;
          final obs =
              s.observations.where((o) => o.element == def.key).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lv ${lv.toStringAsFixed(2)}',
                          style: t.headlineMedium?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                      Text('보상 기준 $rl레벨 ${SgcyConfig.levelName(rl)} · '
                          '일일 보상 ${formatStat(SgcyConfig.dailyReward(rl))} · '
                          '주간 ${formatStat(SgcyConfig.dailyReward(rl) * SgcyConfig.weeklyMultiplier)}'),
                      const SizedBox(height: 4),
                      Text('레벨 = Σ(세부 레벨²) / Σ(세부 레벨)', style: t.bodySmall),
                    ],
                  ),
                ),
              ),
              for (final k in def.substats)
                SubStatCard(sub: s.substat(k), today: s.today),
              if (obs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text('관찰 기록', style: t.titleMedium),
                ),
                for (final o in obs.reversed.take(30))
                  ListTile(
                    dense: true,
                    leading: Icon(switch (o.kind) {
                      Observation.strength => Icons.thumb_up,
                      Observation.weakness => Icons.report,
                      _ => Icons.lightbulb,
                    }),
                    title: Text(o.text),
                    subtitle: Text(
                        '${o.date} · ${Observation.labels[o.kind] ?? o.kind}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SubStatCard extends ConsumerWidget {
  const SubStatCard({super.key, required this.sub, required this.today});

  final SubStat sub;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final lc = Labels.levelColor(sub.level);
    final idle = daysBetween(sub.lastActiveDate, today);
    final line = sub.demotionLine;
    final notes = <Widget>[
      if (sub.isProtected(today))
        _tag(Icons.shield, '보호 ~${sub.protectedUntil}', Colors.lightBlue),
      if (idle != null && idle > SgcyConfig.decayGraceDays)
        _tag(Icons.trending_down, '자연 감소 중 ($idle일)', Colors.redAccent)
      else if (idle != null && idle == SgcyConfig.decayGraceDays)
        _tag(Icons.schedule, '내일부터 감소', Colors.orange),
      if (line != null && !sub.isProtected(today) && sub.stat <= line * 1.1)
        _tag(Icons.warning_amber, '강등 위험', Colors.orange),
    ];
    return Card(
      key: Key('substat_${sub.key}'),
      child: InkWell(
        onLongPress: () => _place(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(sub.label, style: t.titleMedium),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: lc.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: lc),
                      ),
                      child: Text(
                          'Lv${sub.level} ${sub.levelName} ${SgcyConfig.levelHanja[sub.level - 1]}',
                          overflow: TextOverflow.ellipsis,
                          style: t.labelMedium?.copyWith(color: lc)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '레벨 배치',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.tune, size: 18),
                    onPressed: () => _place(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: sub.gauge, minHeight: 10, color: lc),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _fit(
                        Text(line == null ? '0' : '강등선 ${formatStat(line)}',
                            style: t.bodySmall),
                        Alignment.centerLeft),
                  ),
                  Expanded(
                    child: _fit(
                        Text('스탯 ${formatStat(sub.stat)}',
                            style: t.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Alignment.center),
                  ),
                  Expanded(
                    child: _fit(
                        Text('기준 ${formatStat(sub.baseStat)}',
                            style: t.bodySmall),
                        Alignment.centerRight),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: notes),
              ],
              const SizedBox(height: 2),
              Text(SgcyConfig.levelDistribution[sub.level - 1],
                  style: t.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fit(Widget child, Alignment a) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: a, child: child);

  Widget _tag(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      );

  /// 레벨 배치 (초기 판정·보정). 승급은 원래 특별 퀘스트로만 하므로 확인을 받는다.
  Future<void> _place(BuildContext context, WidgetRef ref) async {
    final level = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${sub.label} 레벨 배치'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('초기 판정이나 보정용이에요. 평소 승급은 특별 퀘스트로 합니다.\n'
                '배치하면 그 레벨의 승급 직후 스탯이 되고 3일간 보호됩니다.'),
          ),
          for (var l = 1; l <= SgcyConfig.maxLevel; l++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l),
              child: Text(
                  '$l ${SgcyConfig.levelName(l)} — ${SgcyConfig.levelDistribution[l - 1]}'
                  '${l == sub.level ? '  (현재)' : ''}'),
            ),
        ],
      ),
    );
    if (level == null || level == sub.level) return;
    await ref.read(gameControllerProvider.notifier).placeLevel(sub.key, level);
  }
}
