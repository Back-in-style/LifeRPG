import 'json_helpers.dart';

/// 분석 에이전트의 관찰 기록 (장점·미흡점·개선점).
class Observation {
  const Observation({
    required this.date,
    required this.element,
    required this.kind,
    required this.text,
  });

  static const String strength = 'strength';
  static const String weakness = 'weakness';
  static const String improvement = 'improvement';
  static const List<String> kinds = [strength, weakness, improvement];
  static const Map<String, String> labels = {
    strength: '장점',
    weakness: '미흡점',
    improvement: '개선점',
  };

  final String date;

  /// 주요 요소 키.
  final String element;

  /// [strength] | [weakness] | [improvement]
  final String kind;
  final String text;

  Map<String, Object?> toJson() =>
      {'date': date, 'element': element, 'kind': kind, 'text': text};

  factory Observation.fromJson(Map<String, Object?> j) => Observation(
        date: jString(j['date']),
        element: jString(j['element']),
        kind: jString(j['kind'], improvement),
        text: jString(j['text']),
      );

  @override
  bool operator ==(Object other) =>
      other is Observation && deepEquals(other.toJson(), toJson());

  @override
  int get hashCode => deepHash(toJson());
}
