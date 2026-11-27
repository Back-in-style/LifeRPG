import '../format.dart';
import '../sgcy_config.dart';
import 'json_helpers.dart';
import 'observation.dart';
import 'quest.dart';
import 'skill.dart';
import 'substat.dart';

/// 앱 전체 상태 = Claude와 주고받는 상태 파일(`sgcy-state`)의 본체.
class GameState {
  const GameState({
    required this.substats,
    this.quests = const [],
    this.skills = const [],
    this.observations = const [],
    this.profileNotes = const [],
    this.nextId = 1,
    required this.today,
    this.lastUpdateDate,
    this.lastSummary = '',
  });

  static const String format = 'sgcy-state';
  static const int version = 2;

  /// 세부스탯 13개 (키 → 상태). 항상 전부 있다.
  final Map<String, SubStat> substats;

  /// 진행 중 + 최근 종료 퀘스트 (id 오름차순).
  final List<Quest> quests;
  final List<Skill> skills;

  /// 최근 관찰 기록 (오래된 → 최신).
  final List<Observation> observations;

  /// 대화 에이전트가 알아야 할 나에 대한 사실들 (업데이트 파일이 통째로 교체).
  final List<String> profileNotes;

  /// 퀘스트·스킬 공용 다음 id.
  final int nextId;

  /// 마지막 롤오버 날짜 (`YYYY-MM-DD`).
  final String today;

  /// 마지막 Claude 업데이트 날짜.
  final String? lastUpdateDate;

  /// 마지막 Claude 업데이트의 하루 요약.
  final String lastSummary;

  /// 새 사용자: 세부스탯 전부 1레벨·시작 스탯, 오늘을 활동일로 (자연 감소 유예 시작).
  static GameState initial(DateTime now) {
    final today = dateKey(now);
    return GameState(
      substats: {
        for (final s in SgcyConfig.substats)
          s.key: SubStat(key: s.key, lastActiveDate: today),
      },
      today: today,
    );
  }

  SubStat substat(String key) => substats[key] ?? SubStat(key: key);

  /// 주요 요소 레벨 = Σa² / Σa (소수).
  double elementLevel(String element) {
    final def = SgcyConfig.elementByKey[element];
    if (def == null) return 1;
    var sq = 0.0, sum = 0.0;
    for (final k in def.substats) {
      final l = substat(k).level.toDouble();
      sq += l * l;
      sum += l;
    }
    return sum == 0 ? 1 : sq / sum;
  }

  /// 보상 기준 정수 레벨 (버림).
  int elementRewardLevel(String element) =>
      SgcyConfig.clampLevel(elementLevel(element).floor());

  List<Quest> get activeQuests => [
        for (final q in quests)
          if (q.isActive) q
      ];

  Quest? questById(int id) {
    for (final q in quests) {
      if (q.id == id) return q;
    }
    return null;
  }

  Skill? skillById(int id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  GameState copyWith({
    Map<String, SubStat>? substats,
    List<Quest>? quests,
    List<Skill>? skills,
    List<Observation>? observations,
    List<String>? profileNotes,
    int? nextId,
    String? today,
    Object? lastUpdateDate = unset,
    String? lastSummary,
  }) =>
      GameState(
        substats: substats ?? this.substats,
        quests: quests ?? this.quests,
        skills: skills ?? this.skills,
        observations: observations ?? this.observations,
        profileNotes: profileNotes ?? this.profileNotes,
        nextId: nextId ?? this.nextId,
        today: today ?? this.today,
        lastUpdateDate: identical(lastUpdateDate, unset)
            ? this.lastUpdateDate
            : lastUpdateDate as String?,
        lastSummary: lastSummary ?? this.lastSummary,
      );

  Map<String, Object?> toJson() => {
        'format': format,
        'version': version,
        'today': today,
        if (lastUpdateDate != null) 'last_update_date': lastUpdateDate,
        if (lastSummary.isNotEmpty) 'last_summary': lastSummary,
        'next_id': nextId,
        'substats': {
          for (final s in SgcyConfig.substats) s.key: substat(s.key).toJson(),
        },
        'skills': [for (final s in skills) s.toJson()],
        'quests': [for (final q in quests) q.toJson()],
        'observations': [for (final o in observations) o.toJson()],
        'profile_notes': profileNotes,
      };

  /// v2 상태 JSON만 받는다. 형식이 다르면(v1 등) [FormatException].
  factory GameState.fromJson(Map<String, Object?> json, DateTime now) {
    if (json['format'] != format || jInt(json['version']) != version) {
      throw const FormatException('심기체연 상태 파일(sgcy-state v2)이 아닙니다');
    }
    final subs = jMap(json['substats']);
    final quests = [
      for (final q in jList(json['quests']))
        if (q is Map) Quest.fromJson(jMap(q)),
    ]..sort((a, b) => a.id.compareTo(b.id));
    final skills = [
      for (final s in jList(json['skills']))
        if (s is Map) Skill.fromJson(jMap(s)),
    ];
    var maxId = 0;
    for (final q in quests) {
      if (q.id > maxId) maxId = q.id;
    }
    for (final s in skills) {
      if (s.id > maxId) maxId = s.id;
    }
    final next = jInt(json['next_id'], maxId + 1);
    return GameState(
      substats: {
        for (final s in SgcyConfig.substats)
          s.key: SubStat.fromJson(s.key, jMap(subs[s.key])),
      },
      quests: quests,
      skills: skills,
      observations: [
        for (final o in jList(json['observations']))
          if (o is Map) Observation.fromJson(jMap(o)),
      ],
      profileNotes: [for (final n in jList(json['profile_notes'])) jString(n)],
      nextId: next > maxId ? next : maxId + 1,
      today: jStringOrNull(json['today']) ?? dateKey(now),
      lastUpdateDate: jStringOrNull(json['last_update_date']),
      lastSummary: jString(json['last_summary']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameState && deepEquals(other.toJson(), toJson());

  @override
  int get hashCode => deepHash(toJson());

  @override
  String toString() => 'GameState($today, ${quests.length} quests)';
}
