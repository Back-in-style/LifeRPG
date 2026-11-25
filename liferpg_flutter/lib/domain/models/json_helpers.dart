// 모델 내부용 JSON·equality 헬퍼. 배럴(domain.dart)에서 export하지 않는다.
import '../format.dart';

/// copyWith에서 "인자 없음"과 "null로 설정"을 구분하기 위한 표식.
class Unset {
  const Unset();
}

const Object unset = Unset();

int jInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final t = v.trim();
    return int.tryParse(t) ?? double.tryParse(t)?.toInt() ?? fallback;
  }
  return fallback;
}

int? jIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double jDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

double? jDoubleOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

String jString(Object? v, [String fallback = '']) =>
    v == null ? fallback : (v is String ? v : v.toString());

String? jStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v is String ? v : v.toString();
  return s.isEmpty ? null : s;
}

bool jBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return fallback;
}

Map<String, Object?> jMap(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): e.value};
  }
  return const {};
}

List<Object?> jList(Object? v) => v is List ? List<Object?>.of(v) : const [];

/// 숫자 값만 골라 `Map<String,double>`로. [keys]가 있으면 그 키만.
Map<String, double> jDoubleMap(Object? v, {Iterable<String>? keys}) {
  final m = jMap(v);
  final allow = keys?.toSet();
  final out = <String, double>{};
  m.forEach((k, val) {
    if (allow != null && !allow.contains(k)) return;
    final d = jDoubleOrNull(val);
    if (d != null) out[k] = d;
  });
  return out;
}

Map<String, int> jIntMap(Object? v) {
  final out = <String, int>{};
  jMap(v).forEach((k, val) {
    final i = jIntOrNull(val);
    if (i != null) out[k] = i;
  });
  return out;
}

DateTime jTime(Object? v, DateTime fallback) =>
    v is String ? (tryParseTimestamp(v) ?? fallback) : fallback;

DateTime? jTimeOrNull(Object? v) => v is String ? tryParseTimestamp(v) : null;

String? tsOrNull(DateTime? t) => t == null ? null : formatTimestamp(t);

final DateTime epoch = DateTime(1970);

// ---------------------------------------------------------------------------
// 깊은 equality / hash (Map·List·Set 재귀)
// ---------------------------------------------------------------------------

bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return a.length == b.length && a.containsAll(b);
  }
  return a == b;
}

int deepHash(Object? o) {
  if (o is Map) {
    return Object.hashAllUnordered(
        o.entries.map((e) => Object.hash(deepHash(e.key), deepHash(e.value))));
  }
  if (o is List) return Object.hashAll(o.map(deepHash));
  if (o is Set) return Object.hashAllUnordered(o.map(deepHash));
  return o.hashCode;
}
