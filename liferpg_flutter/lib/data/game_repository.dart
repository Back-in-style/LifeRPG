import 'package:liferpg/domain/domain.dart';

/// 저장소 계약 (INTERFACES §4).
///
/// 구현: `DriftGameRepository`(앱), `InMemoryGameRepository`(테스트·UI 개발용).
abstract interface class GameRepository {
  /// 저장된 상태. 아무것도 없으면 `GameState.initial(now)`.
  Future<GameState> load();

  /// 엔진 결과 1건을 원자적으로 저장한다 (상태 스냅샷 + 새 이벤트 + 완료 기록).
  ///
  /// [completion]은 저장 시 id가 부여되고, `state.records`에서 같은 완료를 가리키는
  /// 기록 항목(`completionId == null`, 같은 `recordKey`·시각·값)에 그 id를 채워 저장한다.
  Future<void> commit(GameState state,
      {List<LogEvent> events = const [], Completion? completion});

  /// 최근 이벤트, 최신순.
  Future<List<LogEvent>> recentEvents({int limit = 200});

  /// 로그 이벤트 전체 삭제 (상태·완료 기록은 그대로).
  Future<void> clearEvents();

  /// 완료 기록, 최신순. [category]·[recordKey]가 있으면 그 값만.
  Future<List<Completion>> completions(
      {String? category, String? recordKey, int? limit});

  /// 레거시 JSON 4종을 변환해 **기존 데이터를 모두 대체**한다.
  Future<ImportReport> importLegacy(LegacyBundle bundle, DateTime now);

  /// 전체 백업 JSON (state + events + completions).
  Future<String> exportJson();

  Future<void> close();
}

/// 레거시 JSON 4종 원문 (SPEC_v1 §2). 없는 파일은 null.
class LegacyBundle {
  const LegacyBundle({
    this.profileJson,
    this.questsJson,
    this.logJson,
    this.achievementsJson,
  });

  /// `profile.json`
  final String? profileJson;

  /// `quests.json`
  final String? questsJson;

  /// `log.json` (레거시 파일 이름은 `logs.json`이 아니다)
  final String? logJson;

  /// `achievements.json`
  final String? achievementsJson;

  bool get isEmpty =>
      profileJson == null &&
      questsJson == null &&
      logJson == null &&
      achievementsJson == null;
}

/// 레거시 가져오기 결과 요약.
class ImportReport {
  const ImportReport({
    required this.quests,
    required this.events,
    required this.achievements,
    this.warnings = const [],
  });

  /// 가져온 퀘스트 수.
  final int quests;

  /// 저장된 이벤트 수 (레거시 로그 + import 이벤트).
  final int events;

  /// 해금 업적 수 (레거시 유지분 + 임포트 직후 판정분).
  final int achievements;

  /// 사용자에게 보여 줄 경고 (깨진 파일, 버린 키 등).
  final List<String> warnings;

  @override
  String toString() =>
      'ImportReport(quests: $quests, events: $events, achievements: $achievements, '
      'warnings: ${warnings.length})';
}
