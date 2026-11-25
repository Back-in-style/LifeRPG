import 'dart:io';

import 'package:liferpg/data/data.dart';

/// `flutter test`는 패키지 루트에서 실행된다.
const String fixtureDir = 'test/data/fixtures';

/// `test/data/fixtures/<name>/`의 레거시 JSON 4종 (없는 파일은 null).
LegacyBundle loadBundle(String name) {
  String? read(String file) {
    final f = File('$fixtureDir/$name/$file');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  return LegacyBundle(
    profileJson: read('profile.json'),
    questsJson: read('quests.json'),
    logJson: read('log.json'),
    achievementsJson: read('achievements.json'),
  );
}
