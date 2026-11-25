/// 날짜·시각·숫자 표기 유틸 (순수 Dart).
///
/// - 날짜 키: `YYYY-MM-DD` (로컬)
/// - 시각: `YYYY-MM-DD HH:MM:SS` (레거시 `now_str()`와 같은 형식)
/// - 숫자: 레거시 로그 메시지 호환용 Python `repr(float)` / `:g` 흉내
library;

String _two(int v) => v.toString().padLeft(2, '0');

/// `DateTime` → `YYYY-MM-DD`.
String dateKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

/// `DateTime` → `YYYY-MM-DD HH:MM:SS` (초 미만 버림).
String formatTimestamp(DateTime t) =>
    '${dateKey(t)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// `YYYY-MM-DD HH:MM:SS`(또는 ISO 8601) → 로컬 `DateTime`. 형식이 틀리면 null.
DateTime? tryParseTimestamp(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s.trim());
}

/// [tryParseTimestamp]와 같지만 실패하면 [FormatException].
DateTime parseTimestamp(String s) =>
    tryParseTimestamp(s) ?? (throw FormatException('잘못된 시각 형식', s));

final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

/// `YYYY-MM-DD` → 그 날짜의 UTC 자정 (일수 계산용). 형식·날짜가 틀리면 null.
DateTime? tryParseDateKey(String? s) {
  if (s == null) return null;
  final m = _dateRe.firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null; // 2월 30일 등
  return dt;
}

/// 날짜 키 [from] → [to]까지 일수 (to − from). 둘 중 하나라도 형식이 틀리면 null.
int? daysBetween(String? from, String? to) {
  final a = tryParseDateKey(from), b = tryParseDateKey(to);
  if (a == null || b == null) return null;
  return b.difference(a).inDays;
}

/// 날짜 키에 [days]일을 더한 날짜 키.
String addDays(String key, int days) {
  final d = tryParseDateKey(key);
  if (d == null) throw FormatException('잘못된 날짜 형식', key);
  return dateKey(d.add(Duration(days: days)));
}

/// Python `repr(float)` 흉내: 정수값이면 `30.0`, 아니면 최단 표기.
/// 레거시 메시지 `"돌파 성공: 힘 상한 30.0 → 50.0"` 호환.
String pyFloat(double v) {
  if (v.isFinite && v == v.truncateToDouble() && v.abs() < 1e16) {
    return '${v.truncate()}.0';
  }
  return v.toString();
}

/// Python `format(v, 'g')` 흉내 (유효숫자 6자리, 끝의 0 제거).
/// 레거시 메시지 `"스탯 상승: 힘 +0.606"` 호환.
String formatG(double v) {
  if (v.isNaN) return 'nan';
  if (v.isInfinite) return v > 0 ? 'inf' : '-inf';
  if (v == 0) return '0';
  final exp = (v.abs()).toStringAsExponential(5);
  final e = int.parse(exp.substring(exp.indexOf('e') + 1));
  if (e < -4 || e >= 6) {
    final sign = v < 0 ? '-' : '';
    var mant = exp.substring(0, exp.indexOf('e'));
    mant = _stripZeros(mant);
    final es = e < 0 ? '-' : '+';
    return '$sign${mant}e$es${e.abs().toString().padLeft(2, '0')}';
  }
  return _stripZeros(v.toStringAsFixed(5 - e < 0 ? 0 : 5 - e));
}

String _stripZeros(String s) {
  if (!s.contains('.')) return s;
  var r = s.replaceFirst(RegExp(r'0+$'), '');
  if (r.endsWith('.')) r = r.substring(0, r.length - 1);
  return r;
}

/// 소수 [digits]자리 반올림 (스탯 저장용, 기본 3자리).
/// 비유한값이나 |v| ≥ 1e15(int 변환 포화·오차 구간)는 그대로 돌려준다.
double roundTo(double v, [int digits = 3]) {
  if (!v.isFinite || v.abs() >= 1e15) return v;
  var p = 1.0;
  for (var i = 0; i < digits; i++) {
    p *= 10;
  }
  return (v * p).round() / p;
}
