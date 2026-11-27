import 'json_helpers.dart';

/// 스킬 = 자리잡은 습관 (예: 퀵 슬립).
class Skill {
  const Skill({
    required this.id,
    required this.name,
    this.desc = '',
    this.element = '',
    required this.acquiredDate,
    this.failStreak = 0,
  });

  final int id;
  final String name;
  final String desc;

  /// 관련 주요 요소 키 (없으면 빈 문자열).
  final String element;
  final String acquiredDate;

  /// 이 스킬에 연결된 경고 퀘스트의 연속 실패 횟수.
  final int failStreak;

  Skill copyWith(
          {String? name, String? desc, String? element, int? failStreak}) =>
      Skill(
        id: id,
        name: name ?? this.name,
        desc: desc ?? this.desc,
        element: element ?? this.element,
        acquiredDate: acquiredDate,
        failStreak: failStreak ?? this.failStreak,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (desc.isNotEmpty) 'desc': desc,
        if (element.isNotEmpty) 'element': element,
        'acquired_date': acquiredDate,
        if (failStreak != 0) 'fail_streak': failStreak,
      };

  factory Skill.fromJson(Map<String, Object?> j) => Skill(
        id: jInt(j['id']),
        name: jString(j['name']),
        desc: jString(j['desc']),
        element: jString(j['element']),
        acquiredDate: jString(j['acquired_date']),
        failStreak: jInt(j['fail_streak']),
      );

  @override
  bool operator ==(Object other) =>
      other is Skill && deepEquals(other.toJson(), toJson());

  @override
  int get hashCode => deepHash(toJson());

  @override
  String toString() => 'Skill#$id($name)';
}

/// 특별 퀘스트 보상으로 줄 스킬 (아직 id 없음).
class SkillGrant {
  const SkillGrant({required this.name, this.desc = '', this.element = ''});

  final String name;
  final String desc;
  final String element;

  Map<String, Object?> toJson() => {
        'name': name,
        if (desc.isNotEmpty) 'desc': desc,
        if (element.isNotEmpty) 'element': element,
      };

  static SkillGrant? fromJson(Object? v) {
    if (v is String && v.trim().isNotEmpty) return SkillGrant(name: v.trim());
    final m = jMap(v);
    final name = jString(m['name']).trim();
    if (name.isEmpty) return null;
    return SkillGrant(
      name: name,
      desc: jString(m['desc']),
      element: jString(m['element']),
    );
  }
}
