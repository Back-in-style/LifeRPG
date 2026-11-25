import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// 게임 상태 스냅샷 (1행, id = 1). `GameState.toJson()` 전체를 JSON으로 저장한다.
///
/// 상태는 엔진 결과 단위로 통째로 바뀌므로 정규화하지 않는다. 모델 필드가 늘어도
/// `fromJson`이 기본값을 채우므로 스키마 마이그레이션이 필요 없다.
@DataClassName('StateRow')
class GameStates extends Table {
  IntColumn get id => integer()();
  TextColumn get json => text()();

  /// `YYYY-MM-DD HH:MM:SS`
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 로그 이벤트 (append-only). 순서 = id.
@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `YYYY-MM-DD HH:MM:SS`
  TextColumn get ts => text()();
  TextColumn get type => text()();
  TextColumn get message => text()();

  /// JSON 객체
  TextColumn get meta => text().withDefault(const Constant('{}'))();
}

/// 완료 기록. 필터용 컬럼 + 전체 JSON.
@DataClassName('CompletionRow')
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questId => integer()();
  TextColumn get category => text()();
  TextColumn get recordKey => text().nullable()();

  /// `YYYY-MM-DD HH:MM:SS` (문자열 정렬 = 시간 정렬)
  TextColumn get at => text()();

  /// `Completion.toJson()` (id 제외 — id 컬럼이 정본)
  TextColumn get json => text()();
}

@DriftDatabase(tables: [GameStates, Events, Completions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_completions_category ON completions (category, at)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_completions_record ON completions (record_key, at)');
        },
      );
}
