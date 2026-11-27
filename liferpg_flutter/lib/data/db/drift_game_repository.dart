import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:liferpg/domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../game_repository.dart';
import 'app_database.dart';

/// 앱 문서 디렉터리의 `liferpg.sqlite`를 연 저장소.
Future<GameRepository> openGameRepository() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'liferpg.sqlite'));
  return DriftGameRepository(
      AppDatabase(NativeDatabase.createInBackground(file)));
}

/// Drift(SQLite) 저장소. 테스트: `DriftGameRepository(AppDatabase(NativeDatabase.memory()))`.
class DriftGameRepository implements GameRepository {
  DriftGameRepository(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  static const int _stateId = 1;

  @override
  Future<GameState> load() async {
    final row = await (db.select(db.gameStates)
          ..where((t) => t.id.equals(_stateId)))
        .getSingleOrNull();
    if (row != null) {
      try {
        return GameState.fromJson(_decodeMap(row.json), _clock());
      } on FormatException {
        // 깨졌거나 v1 형식 → 새로 시작
      }
    }
    return GameState.initial(_clock());
  }

  @override
  Future<void> commit(GameState state, {List<LogEvent> events = const []}) =>
      db.transaction(() async {
        await db
            .into(db.gameStates)
            .insertOnConflictUpdate(GameStatesCompanion.insert(
              id: const Value(_stateId),
              json: jsonEncode(state.toJson()),
              updatedAt: formatTimestamp(_clock()),
            ));
        if (events.isEmpty) return;
        await db.batch((b) => b.insertAll(db.events, [
              for (final e in events)
                EventsCompanion.insert(
                  ts: formatTimestamp(e.ts),
                  type: e.type,
                  message: e.message,
                  meta: Value(jsonEncode(e.meta)),
                ),
            ]));
      });

  @override
  Future<List<LogEvent>> recentEvents({int limit = 200}) async {
    if (limit <= 0) return const [];
    final rows = await (db.select(db.events)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        LogEvent(
          ts: tryParseTimestamp(r.ts) ?? DateTime(1970),
          type: r.type,
          message: r.message,
          meta: _tryDecodeMap(r.meta),
        ),
    ];
  }

  @override
  Future<void> clearEvents() => db.transaction(() async {
        await db.delete(db.events).go();
        await db.customStatement(
            "DELETE FROM sqlite_sequence WHERE name = 'events'");
      });

  @override
  Future<void> close() => db.close();

  static Map<String, Object?> _tryDecodeMap(String src) {
    try {
      return _decodeMap(src);
    } on FormatException {
      return const {};
    }
  }

  static Map<String, Object?> _decodeMap(String src) {
    final v = jsonDecode(src);
    if (v is! Map) throw const FormatException('JSON 객체가 아님');
    return {for (final e in v.entries) e.key.toString(): e.value as Object?};
  }
}
