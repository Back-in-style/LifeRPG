import 'json_helpers.dart';

/// 완료 시 사용자가 입력한 실측치 (R1). [values]의 키는
/// `GameConfig.measureFields[kind]`.
class Measurement {
  const Measurement({required this.kind, this.values = const {}});

  final String kind;

  /// 예: `{'sets': 5, 'reps': 5, 'weight_kg': 60}`.
  final Map<String, double> values;

  Measurement copyWith({String? kind, Map<String, double>? values}) =>
      Measurement(kind: kind ?? this.kind, values: values ?? this.values);

  Map<String, Object?> toJson() => {'kind': kind, 'values': values};

  factory Measurement.fromJson(Map<String, Object?> json) => Measurement(
        kind: jString(json['kind'], 'flat'),
        values: jDoubleMap(json['values']),
      );

  @override
  bool operator ==(Object other) =>
      other is Measurement &&
      other.kind == kind &&
      deepEquals(other.values, values);

  @override
  int get hashCode => Object.hash(kind, deepHash(values));

  @override
  String toString() => 'Measurement($kind $values)';
}

/// 완료 입력: 측정치 + (기록 연결 퀘스트면) 기록값.
class CompletionInput {
  const CompletionInput({this.measurement, this.recordValue});

  /// flat 퀘스트(측정치 없음) 완료 입력.
  static const CompletionInput none = CompletionInput();

  /// null이면 flat (baseXp). 측정형 퀘스트는 필수.
  final Measurement? measurement;

  /// quest.recordKey가 있으면 입력. 돌파(신규)는 필수.
  final double? recordValue;

  CompletionInput copyWith({
    Object? measurement = unset,
    Object? recordValue = unset,
  }) =>
      CompletionInput(
        measurement: identical(measurement, unset)
            ? this.measurement
            : measurement as Measurement?,
        recordValue: identical(recordValue, unset)
            ? this.recordValue
            : (recordValue as num?)?.toDouble(),
      );

  Map<String, Object?> toJson() => {
        'measurement': measurement?.toJson(),
        'record_value': recordValue,
      };

  factory CompletionInput.fromJson(Map<String, Object?> json) =>
      CompletionInput(
        measurement: json['measurement'] is Map
            ? Measurement.fromJson(jMap(json['measurement']))
            : null,
        recordValue: jDoubleOrNull(json['record_value']),
      );

  @override
  bool operator ==(Object other) =>
      other is CompletionInput &&
      other.measurement == measurement &&
      other.recordValue == recordValue;

  @override
  int get hashCode => Object.hash(measurement, recordValue);
}
