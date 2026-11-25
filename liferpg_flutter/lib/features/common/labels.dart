import 'package:material_ui/material_ui.dart';
import 'package:liferpg/domain/domain.dart';

/// UI 표시 문구 모음. 키(정본)는 [GameConfig]에 있고, 여기는 사람이 읽는 이름만 둔다.
abstract final class Labels {
  /// 측정치 종류 표시 이름.
  static const Map<String, String> measureKinds = {
    'flat': '체크형 (고정 XP)',
    'duration_min': '시간 (분)',
    'distance_km': '거리 (km)',
    'swim_m': '수영 거리 (m)',
    'strength': '근력 (세트×횟수×무게)',
    'reps': '맨몸 (세트×횟수)',
    'pomodoro': '뽀모도로 (개)',
    'sleep_h': '수면 (시간)',
    'steps': '걸음 수',
    'count': '횟수',
  };

  /// 측정치 입력 필드 표시 이름.
  static const Map<String, String> measureFields = {
    'minutes': '시간 (분)',
    'km': '거리 (km)',
    'meters': '거리 (m)',
    'sets': '세트',
    'reps': '횟수',
    'weight_kg': '무게 (kg)',
    'count': '개수',
    'hours': '수면 시간 (h)',
    'steps': '걸음 수',
  };

  /// 정수만 받는 측정치 필드.
  static const Set<String> integerFields = {'sets', 'reps', 'count', 'steps'};

  static String measureKind(String k) => measureKinds[k] ?? k;
  static String measureField(String k) => measureFields[k] ?? k;

  /// 로그 type별 아이콘.
  static IconData logIcon(String type) => switch (type) {
        LogEvent.system => Icons.settings_suggest,
        LogEvent.xp => Icons.auto_awesome,
        LogEvent.quest => Icons.shield,
        LogEvent.breakthrough => Icons.bolt,
        LogEvent.stat => Icons.trending_up,
        LogEvent.achievement => Icons.emoji_events,
        LogEvent.pr => Icons.military_tech,
        LogEvent.import => Icons.file_download,
        _ => Icons.circle_outlined,
      };

  /// 엔진 오류 메시지.
  static String error(GameError e) => switch (e) {
        GameError.questNotFound => '퀘스트를 찾을 수 없음',
        GameError.alreadyDone => '이미 완료된 퀘스트임',
        GameError.invalidMeasurement => '측정값을 올바르게 입력해줘',
        GameError.invalidDraft => '입력값을 다시 확인해줘',
      };

  /// 퀘스트 종류 배지 문자.
  static String typeBadge(String type) => '[$type]';

  /// `'#RRGGBB'` → [Color].
  static Color hexColor(String? hex, {Color fallback = const Color(0xFF808080)}) {
    if (hex == null) return fallback;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  static Color gradeColor(String grade) =>
      hexColor(GameConfig.gradeColorsHex[grade]);

  /// 숫자 표기: 정수면 소수점 없이.
  static String num(double v) => formatG(v);
}
