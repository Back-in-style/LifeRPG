import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:liferpg/domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../game_repository.dart';
import '../legacy_importer.dart';
import '../repository_support.dart';
import 'app_database.dart';

/// 앱 문서 디렉터리의 `liferpg.sqlite`를 연 저장소.
Future<GameRepository> openGameRepository() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'liferpg.sqlite'));
  return DriftGameRepository(
      AppDatabase(NativeDatabase.createInBackground(file)));
}

/// Drift(SQLite) 저장소. 스키마는 [AppDatabase] 참고.
///
/// 테스트: `DriftGameRepository(AppDatabase(NativeDatabase.memory()))`.
class DriftGameRepository implements GameRepository {
  DriftGameRepository(this.db,
      {DateTime Function()? clock,
      LegacyImporter importer = const LegacyImporter()})
      : _clock = clock ?? DateTime.now,
        _importer = importer;

  final AppDatabase db;
  final DateTime Function() _clock;
  final LegacyImporter _importer;

  static const int _stateId = 1;

  @override
  Future<GameState> load() async =>
      // 저장 JSON이 없거나 깨졌으면 새 상태로 (이벤트·완료 기록은 남는다).
      await _storedState() ?? GameState.initial(_clock());

  Future<GameState?> _storedState() async {
    final row = await (db.select(db.gameStates)
          ..where((t) => t.id.equals(_stateId)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return GameState.fromJson(_decodeMap(row.json));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> commit(GameState state,
      {List<LogEvent> events = const [], Completion? completion}) {
    return db.transaction(() async {
      var s = carryCompletionIds(state, await _storedState());
      if (completion != null) {
        final id = await db
            .into(db.completions)
            .insert(_completionCompanion(completion));
        s = linkCompletionToRecords(s, completion.copyWith(id: id));
      }
      await _writeState(s);
      await _insertEvents(events);
    });
  }

  @override
  Future<List<LogEvent>> recentEvents({int limit = 200}) async {
    if (limit <= 0) return const [];
    final rows = await (db.select(db.events)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
    return [for (final r in rows) _eventFromRow(r)];
  }

  @override
  Future<void> clearEvents() => db.transaction(() async {
        await db.delete(db.events).go();
        await db.customStatement(
            "DELETE FROM sqlite_sequence WHERE name = 'events'");
      });

  @override
  Future<List<Completion>> completions(
      {String? category, String? recordKey, int? limit}) async {
    final q = db.select(db.completions);
    if (category != null) q.where((t) => t.category.equals(category));
    if (recordKey != null) q.where((t) => t.recordKey.equals(recordKey));
    q.orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.id)]);
    if (limit != null) q.limit(limit < 0 ? 0 : limit);
    final rows = await q.get();
    return [for (final r in rows) _completionFromRow(r)];
  }

  @override
  Future<ImportReport> importLegacy(LegacyBundle bundle, DateTime now) async {
    final r = _importer.convert(bundle, now);
    await db.transaction(() async {
      await db.delete(db.completions).go();
      await db.delete(db.events).go();
      await db.delete(db.gameStates).go();
      // autoincrement 번호도 처음부터
      await db.customStatement(
          "DELETE FROM sqlite_sequence WHERE name IN ('events','completions')");
      await _writeState(r.state);
      await _insertEvents(r.events);
    });
    return r.report;
  }

  @override
  Future<String> exportJson() async {
    final state = await load();
    final eventRows = await (db.select(db.events)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final compRows = await (db.select(db.completions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return encodeBackup(
      state: state,
      events: [for (final r in eventRows) _eventFromRow(r)],
      completions: [for (final r in compRows) _completionFromRow(r)],
      exportedAt: _clock(),
    );
  }

  @override
  Future<void> close() => db.close();

  // ---------------------------------------------------------------------------

  Future<void> _writeState(GameState s) =>
      db.into(db.gameStates).insertOnConflictUpdate(GameStatesCompanion.insert(
            id: const Value(_stateId),
            json: jsonEncode(s.toJson()),
            updatedAt: formatTimestamp(_clock()),
          ));

  Future<void> _insertEvents(List<LogEvent> events) async {
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
  }

  CompletionsCompanion _completionCompanion(Completion c) {
    final json = c.toJson()..remove('id');
    return CompletionsCompanion.insert(
      questId: c.questId,
      category: c.category,
      recordKey: Value(c.recordKey),
      at: formatTimestamp(c.at),
      json: jsonEncode(json),
    );
  }

  static LogEvent _eventFromRow(EventRow r) {
    Map<String, Object?> meta;
    try {
      meta = _decodeMap(r.meta);
    } on FormatException {
      meta = const {};
    }
    return LogEvent(
      ts: tryParseTimestamp(r.ts) ?? DateTime(1970),
      type: r.type,
      message: r.message,
      meta: meta,
    );
  }

  static Completion _completionFromRow(CompletionRow r) {
    Map<String, Object?> json;
    try {
      json = _decodeMap(r.json);
    } on FormatException {
      json = {
        'quest_id': r.questId,
        'category': r.category,
        'record_key': r.recordKey,
        'at': r.at,
      };
    }
    return Completion.fromJson({...json, 'id': r.id});
  }

  static Map<String, Object?> _decodeMap(String src) {
    final v = jsonDecode(src);
    if (v is! Map) throw const FormatException('JSON 객체가 아님');
    return {for (final e in v.entries) e.key.toString(): e.value as Object?};
  }
}
