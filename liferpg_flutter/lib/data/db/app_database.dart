import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// 게임 상태 스냅샷 (1행, id = 1). `GameState.toJson()`(sgcy-state v2) 전체를 JSON으로 저장한다.
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

@DriftDatabase(tables: [GameStates, Events])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1(XP·스킬 트리) → v2(심기체연): 체계가 달라 상태를 새로 시작한다. 로그는 남긴다.
            await customStatement('DROP TABLE IF EXISTS completions');
            await delete(gameStates).go();
          }
        },
      );
}
