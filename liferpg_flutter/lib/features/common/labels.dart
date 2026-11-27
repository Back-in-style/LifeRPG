import 'package:material_ui/material_ui.dart';
import 'package:liferpg/domain/domain.dart';

/// 화면 공용 라벨·아이콘. (요소·레벨 색은 테마의 `SgcyPalette`)
abstract final class Labels {
  static IconData elementIcon(String key) => switch (key) {
        'sim' => Icons.favorite,
        'gi' => Icons.menu_book,
        'che' => Icons.fitness_center,
        'yeon' => Icons.people,
        _ => Icons.circle,
      };

  static IconData kindIcon(String kind) => switch (kind) {
        QuestKind.daily => Icons.today,
        QuestKind.weekly => Icons.date_range,
        QuestKind.special => Icons.auto_awesome,
        QuestKind.warning => Icons.warning_amber,
        _ => Icons.flag,
      };

  static IconData logIcon(String type) => switch (type) {
        LogEvent.quest => Icons.flag,
        LogEvent.stat => Icons.trending_up,
        LogEvent.level => Icons.military_tech,
        LogEvent.skill => Icons.bolt,
        LogEvent.warning => Icons.warning_amber,
        LogEvent.update => Icons.cloud_download,
        _ => Icons.info_outline,
      };

  static String elementLabel(String key) =>
      SgcyConfig.elementByKey[key]?.label ?? key;

  static String substatLabel(String key) =>
      SgcyConfig.substatByKey[key]?.label ?? key;

  static String rewardsText(Quest q) {
    final sign = q.isWarning ? '-' : '+';
    return q.rewards.entries
        .map((e) => '${substatLabel(e.key)} $sign${formatStat(e.value)}')
        .join('  ');
  }

  /// 기한 표시: 오늘 / D-n / 지남.
  static String? deadlineText(Quest q, String today) {
    final left = daysLeft(q, today);
    if (left == null) return null;
    if (left == 0) return '오늘까지';
    if (left < 0) return '기한 지남';
    return 'D-$left';
  }
}
