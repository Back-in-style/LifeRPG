import '../format.dart';
import 'json_helpers.dart';

/// 로그 이벤트 (SPEC_v1 §2.4 형식).
class LogEvent {
  const LogEvent({
    required this.ts,
    required this.type,
    required this.message,
    this.meta = const {},
  });

  static const String system = 'system';
  static const String xp = 'xp';
  static const String quest = 'quest';
  static const String breakthrough = 'breakthrough';
  static const String stat = 'stat';
  static const String achievement = 'achievement';
  static const String pr = 'pr';
  static const String import = 'import';

  final DateTime ts;

  /// `'system'|'xp'|'quest'|'breakthrough'|'stat'|'achievement'|'pr'|'import'`.
  final String type;

  /// 레거시 메시지 형식 유지.
  final String message;

  /// JSON으로 직렬화 가능한 값만 (num/String/bool/null/List/Map).
  final Map<String, Object?> meta;

  LogEvent copyWith({
    DateTime? ts,
    String? type,
    String? message,
    Map<String, Object?>? meta,
  }) =>
      LogEvent(
        ts: ts ?? this.ts,
        type: type ?? this.type,
        message: message ?? this.message,
        meta: meta ?? this.meta,
      );

  Map<String, Object?> toJson() => {
        'ts': formatTimestamp(ts),
        'type': type,
        'message': message,
        'meta': meta,
      };

  factory LogEvent.fromJson(Map<String, Object?> json) => LogEvent(
        ts: jTime(json['ts'], epoch),
        type: jString(json['type'], system),
        message: jString(json['message']),
        meta: jMap(json['meta']),
      );

  @override
  bool operator ==(Object other) =>
      other is LogEvent &&
      other.ts == ts &&
      other.type == type &&
      other.message == message &&
      deepEquals(other.meta, meta);

  @override
  int get hashCode => Object.hash(ts, type, message, deepHash(meta));

  @override
  String toString() => 'LogEvent($type: $message)';
}
