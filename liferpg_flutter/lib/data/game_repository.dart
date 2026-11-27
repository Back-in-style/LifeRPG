import 'package:liferpg/domain/domain.dart';

/// 저장소 계약.
///
/// 구현: `DriftGameRepository`(앱), `InMemoryGameRepository`(테스트·UI 개발용).
abstract interface class GameRepository {
  /// 저장된 상태. 없거나 v2 형식이 아니면(v1 데이터 포함) `GameState.initial(now)`.
  Future<GameState> load();

  /// 엔진 결과 1건을 원자적으로 저장한다 (상태 스냅샷 + 새 이벤트).
  Future<void> commit(GameState state, {List<LogEvent> events = const []});

  /// 최근 이벤트, 최신순.
  Future<List<LogEvent>> recentEvents({int limit = 200});

  /// 로그 이벤트 전체 삭제 (상태는 그대로).
  Future<void> clearEvents();

  Future<void> close();
}
