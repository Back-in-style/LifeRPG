// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GameStatesTable extends GameStates
    with TableInfo<$GameStatesTable, StateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_states';
  @override
  VerificationContext validateIntegrity(Insertable<StateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StateRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GameStatesTable createAlias(String alias) {
    return $GameStatesTable(attachedDatabase, alias);
  }
}

class StateRow extends DataClass implements Insertable<StateRow> {
  final int id;
  final String json;

  /// `YYYY-MM-DD HH:MM:SS`
  final String updatedAt;
  const StateRow(
      {required this.id, required this.json, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  GameStatesCompanion toCompanion(bool nullToAbsent) {
    return GameStatesCompanion(
      id: Value(id),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory StateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StateRow(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  StateRow copyWith({int? id, String? json, String? updatedAt}) => StateRow(
        id: id ?? this.id,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  StateRow copyWithCompanion(GameStatesCompanion data) {
    return StateRow(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StateRow(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StateRow &&
          other.id == this.id &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class GameStatesCompanion extends UpdateCompanion<StateRow> {
  final Value<int> id;
  final Value<String> json;
  final Value<String> updatedAt;
  const GameStatesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GameStatesCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required String updatedAt,
  })  : json = Value(json),
        updatedAt = Value(updatedAt);
  static Insertable<StateRow> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GameStatesCompanion copyWith(
      {Value<int>? id, Value<String>? json, Value<String>? updatedAt}) {
    return GameStatesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameStatesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
      'ts', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
      'meta', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [id, ts, type, message, meta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(Insertable<EventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ts'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      meta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta'])!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;

  /// `YYYY-MM-DD HH:MM:SS`
  final String ts;
  final String type;
  final String message;

  /// JSON 객체
  final String meta;
  const EventRow(
      {required this.id,
      required this.ts,
      required this.type,
      required this.message,
      required this.meta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<String>(ts);
    map['type'] = Variable<String>(type);
    map['message'] = Variable<String>(message);
    map['meta'] = Variable<String>(meta);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      ts: Value(ts),
      type: Value(type),
      message: Value(message),
      meta: Value(meta),
    );
  }

  factory EventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<String>(json['ts']),
      type: serializer.fromJson<String>(json['type']),
      message: serializer.fromJson<String>(json['message']),
      meta: serializer.fromJson<String>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<String>(ts),
      'type': serializer.toJson<String>(type),
      'message': serializer.toJson<String>(message),
      'meta': serializer.toJson<String>(meta),
    };
  }

  EventRow copyWith(
          {int? id, String? ts, String? type, String? message, String? meta}) =>
      EventRow(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        type: type ?? this.type,
        message: message ?? this.message,
        meta: meta ?? this.meta,
      );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      type: data.type.present ? data.type.value : this.type,
      message: data.message.present ? data.message.value : this.message,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('message: $message, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, type, message, meta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.type == this.type &&
          other.message == this.message &&
          other.meta == this.meta);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<String> ts;
  final Value<String> type;
  final Value<String> message;
  final Value<String> meta;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.type = const Value.absent(),
    this.message = const Value.absent(),
    this.meta = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String ts,
    required String type,
    required String message,
    this.meta = const Value.absent(),
  })  : ts = Value(ts),
        type = Value(type),
        message = Value(message);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<String>? ts,
    Expression<String>? type,
    Expression<String>? message,
    Expression<String>? meta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (type != null) 'type': type,
      if (message != null) 'message': message,
      if (meta != null) 'meta': meta,
    });
  }

  EventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? ts,
      Value<String>? type,
      Value<String>? message,
      Value<String>? meta}) {
    return EventsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      type: type ?? this.type,
      message: message ?? this.message,
      meta: meta ?? this.meta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('message: $message, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, CompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _questIdMeta =
      const VerificationMeta('questId');
  @override
  late final GeneratedColumn<int> questId = GeneratedColumn<int>(
      'quest_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordKeyMeta =
      const VerificationMeta('recordKey');
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
      'record_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
      'at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, questId, category, recordKey, at, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(Insertable<CompletionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('quest_id')) {
      context.handle(_questIdMeta,
          questId.isAcceptableOrUnknown(data['quest_id']!, _questIdMeta));
    } else if (isInserting) {
      context.missing(_questIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('record_key')) {
      context.handle(_recordKeyMeta,
          recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      questId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quest_id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      recordKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_key']),
      at: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}at'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }
}

class CompletionRow extends DataClass implements Insertable<CompletionRow> {
  final int id;
  final int questId;
  final String category;
  final String? recordKey;

  /// `YYYY-MM-DD HH:MM:SS` (문자열 정렬 = 시간 정렬)
  final String at;

  /// `Completion.toJson()` (id 제외 — id 컬럼이 정본)
  final String json;
  const CompletionRow(
      {required this.id,
      required this.questId,
      required this.category,
      this.recordKey,
      required this.at,
      required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['quest_id'] = Variable<int>(questId);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || recordKey != null) {
      map['record_key'] = Variable<String>(recordKey);
    }
    map['at'] = Variable<String>(at);
    map['json'] = Variable<String>(json);
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      id: Value(id),
      questId: Value(questId),
      category: Value(category),
      recordKey: recordKey == null && nullToAbsent
          ? const Value.absent()
          : Value(recordKey),
      at: Value(at),
      json: Value(json),
    );
  }

  factory CompletionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionRow(
      id: serializer.fromJson<int>(json['id']),
      questId: serializer.fromJson<int>(json['questId']),
      category: serializer.fromJson<String>(json['category']),
      recordKey: serializer.fromJson<String?>(json['recordKey']),
      at: serializer.fromJson<String>(json['at']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questId': serializer.toJson<int>(questId),
      'category': serializer.toJson<String>(category),
      'recordKey': serializer.toJson<String?>(recordKey),
      'at': serializer.toJson<String>(at),
      'json': serializer.toJson<String>(json),
    };
  }

  CompletionRow copyWith(
          {int? id,
          int? questId,
          String? category,
          Value<String?> recordKey = const Value.absent(),
          String? at,
          String? json}) =>
      CompletionRow(
        id: id ?? this.id,
        questId: questId ?? this.questId,
        category: category ?? this.category,
        recordKey: recordKey.present ? recordKey.value : this.recordKey,
        at: at ?? this.at,
        json: json ?? this.json,
      );
  CompletionRow copyWithCompanion(CompletionsCompanion data) {
    return CompletionRow(
      id: data.id.present ? data.id.value : this.id,
      questId: data.questId.present ? data.questId.value : this.questId,
      category: data.category.present ? data.category.value : this.category,
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      at: data.at.present ? data.at.value : this.at,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletionRow(')
          ..write('id: $id, ')
          ..write('questId: $questId, ')
          ..write('category: $category, ')
          ..write('recordKey: $recordKey, ')
          ..write('at: $at, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, questId, category, recordKey, at, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionRow &&
          other.id == this.id &&
          other.questId == this.questId &&
          other.category == this.category &&
          other.recordKey == this.recordKey &&
          other.at == this.at &&
          other.json == this.json);
}

class CompletionsCompanion extends UpdateCompanion<CompletionRow> {
  final Value<int> id;
  final Value<int> questId;
  final Value<String> category;
  final Value<String?> recordKey;
  final Value<String> at;
  final Value<String> json;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.questId = const Value.absent(),
    this.category = const Value.absent(),
    this.recordKey = const Value.absent(),
    this.at = const Value.absent(),
    this.json = const Value.absent(),
  });
  CompletionsCompanion.insert({
    this.id = const Value.absent(),
    required int questId,
    required String category,
    this.recordKey = const Value.absent(),
    required String at,
    required String json,
  })  : questId = Value(questId),
        category = Value(category),
        at = Value(at),
        json = Value(json);
  static Insertable<CompletionRow> custom({
    Expression<int>? id,
    Expression<int>? questId,
    Expression<String>? category,
    Expression<String>? recordKey,
    Expression<String>? at,
    Expression<String>? json,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questId != null) 'quest_id': questId,
      if (category != null) 'category': category,
      if (recordKey != null) 'record_key': recordKey,
      if (at != null) 'at': at,
      if (json != null) 'json': json,
    });
  }

  CompletionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? questId,
      Value<String>? category,
      Value<String?>? recordKey,
      Value<String>? at,
      Value<String>? json}) {
    return CompletionsCompanion(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      category: category ?? this.category,
      recordKey: recordKey ?? this.recordKey,
      at: at ?? this.at,
      json: json ?? this.json,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questId.present) {
      map['quest_id'] = Variable<int>(questId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('id: $id, ')
          ..write('questId: $questId, ')
          ..write('category: $category, ')
          ..write('recordKey: $recordKey, ')
          ..write('at: $at, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GameStatesTable gameStates = $GameStatesTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $CompletionsTable completions = $CompletionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [gameStates, events, completions];
}

typedef $$GameStatesTableCreateCompanionBuilder = GameStatesCompanion Function({
  Value<int> id,
  required String json,
  required String updatedAt,
});
typedef $$GameStatesTableUpdateCompanionBuilder = GameStatesCompanion Function({
  Value<int> id,
  Value<String> json,
  Value<String> updatedAt,
});

class $$GameStatesTableFilterComposer
    extends Composer<_$AppDatabase, $GameStatesTable> {
  $$GameStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GameStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $GameStatesTable> {
  $$GameStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GameStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameStatesTable> {
  $$GameStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GameStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GameStatesTable,
    StateRow,
    $$GameStatesTableFilterComposer,
    $$GameStatesTableOrderingComposer,
    $$GameStatesTableAnnotationComposer,
    $$GameStatesTableCreateCompanionBuilder,
    $$GameStatesTableUpdateCompanionBuilder,
    (StateRow, BaseReferences<_$AppDatabase, $GameStatesTable, StateRow>),
    StateRow,
    PrefetchHooks Function()> {
  $$GameStatesTableTableManager(_$AppDatabase db, $GameStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
          }) =>
              GameStatesCompanion(
            id: id,
            json: json,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required String updatedAt,
          }) =>
              GameStatesCompanion.insert(
            id: id,
            json: json,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GameStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GameStatesTable,
    StateRow,
    $$GameStatesTableFilterComposer,
    $$GameStatesTableOrderingComposer,
    $$GameStatesTableAnnotationComposer,
    $$GameStatesTableCreateCompanionBuilder,
    $$GameStatesTableUpdateCompanionBuilder,
    (StateRow, BaseReferences<_$AppDatabase, $GameStatesTable, StateRow>),
    StateRow,
    PrefetchHooks Function()>;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  required String ts,
  required String type,
  required String message,
  Value<String> meta,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  Value<String> ts,
  Value<String> type,
  Value<String> message,
  Value<String> meta,
});

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnFilters(column));
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnOrderings(column));
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);
}

class $$EventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EventsTable,
    EventRow,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
    EventRow,
    PrefetchHooks Function()> {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> ts = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<String> meta = const Value.absent(),
          }) =>
              EventsCompanion(
            id: id,
            ts: ts,
            type: type,
            message: message,
            meta: meta,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String ts,
            required String type,
            required String message,
            Value<String> meta = const Value.absent(),
          }) =>
              EventsCompanion.insert(
            id: id,
            ts: ts,
            type: type,
            message: message,
            meta: meta,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EventsTable,
    EventRow,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
    EventRow,
    PrefetchHooks Function()>;
typedef $$CompletionsTableCreateCompanionBuilder = CompletionsCompanion
    Function({
  Value<int> id,
  required int questId,
  required String category,
  Value<String?> recordKey,
  required String at,
  required String json,
});
typedef $$CompletionsTableUpdateCompanionBuilder = CompletionsCompanion
    Function({
  Value<int> id,
  Value<int> questId,
  Value<String> category,
  Value<String?> recordKey,
  Value<String> at,
  Value<String> json,
});

class $$CompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get questId => $composableBuilder(
      column: $table.questId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordKey => $composableBuilder(
      column: $table.recordKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get questId => $composableBuilder(
      column: $table.questId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordKey => $composableBuilder(
      column: $table.recordKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get questId =>
      $composableBuilder(column: $table.questId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$CompletionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CompletionsTable,
    CompletionRow,
    $$CompletionsTableFilterComposer,
    $$CompletionsTableOrderingComposer,
    $$CompletionsTableAnnotationComposer,
    $$CompletionsTableCreateCompanionBuilder,
    $$CompletionsTableUpdateCompanionBuilder,
    (
      CompletionRow,
      BaseReferences<_$AppDatabase, $CompletionsTable, CompletionRow>
    ),
    CompletionRow,
    PrefetchHooks Function()> {
  $$CompletionsTableTableManager(_$AppDatabase db, $CompletionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> questId = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String?> recordKey = const Value.absent(),
            Value<String> at = const Value.absent(),
            Value<String> json = const Value.absent(),
          }) =>
              CompletionsCompanion(
            id: id,
            questId: questId,
            category: category,
            recordKey: recordKey,
            at: at,
            json: json,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int questId,
            required String category,
            Value<String?> recordKey = const Value.absent(),
            required String at,
            required String json,
          }) =>
              CompletionsCompanion.insert(
            id: id,
            questId: questId,
            category: category,
            recordKey: recordKey,
            at: at,
            json: json,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CompletionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CompletionsTable,
    CompletionRow,
    $$CompletionsTableFilterComposer,
    $$CompletionsTableOrderingComposer,
    $$CompletionsTableAnnotationComposer,
    $$CompletionsTableCreateCompanionBuilder,
    $$CompletionsTableUpdateCompanionBuilder,
    (
      CompletionRow,
      BaseReferences<_$AppDatabase, $CompletionsTable, CompletionRow>
    ),
    CompletionRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GameStatesTableTableManager get gameStates =>
      $$GameStatesTableTableManager(_db, _db.gameStates);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
}
