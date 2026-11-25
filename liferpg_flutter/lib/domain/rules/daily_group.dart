import '../game_config.dart';
import '../models/quest.dart';

/// §2.3 Daily 그룹 키 (`GameConfig.dailyGroups`). 레거시 우선순위 + 신규 카테고리.
String dailyGroupOf(Quest q) {
  final desc = q.desc, title = q.title, cat = q.category;
  if (desc.startsWith('[Day A]')) return 'grp_dayA';
  if (desc.startsWith('[Day B]')) return 'grp_dayB';
  if (desc.startsWith('[수영 데이]') || cat == 'Swim') return 'grp_swim';
  if (cat == 'Gym') return 'grp_core';
  if (cat == 'Study') return 'grp_study';
  if (cat == 'Routine') return 'grp_routine';
  if (cat == 'Social') return 'grp_social';
  if (GameConfig.studyKeywords.any(title.contains)) return 'grp_study';
  if (GameConfig.routineKeywords.any(title.contains)) return 'grp_routine';
  return 'grp_etc';
}
