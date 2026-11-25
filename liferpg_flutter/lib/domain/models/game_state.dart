import '../format.dart';
import 'json_helpers.dart';
import 'personal_record.dart';
import 'profile.dart';
import 'quest.dart';

/// 앱 전체 상태 스냅샷. 엔진 입력/출력 단위.
class GameState {
  const GameState({
    required this.profile,
    this.quests = const [],
    this.nextQuestId = 1,
    this.unlockedAchievements = const {},
    this.records = const {},
  });

  final Profile profile;

  /// 추가 순서 (id 오름차순).
  final List<Quest> quests;

  /// 다음 퀘스트 id (삭제해도 줄지 않음, 레거시 `next_id`).
  final int nextQuestId;

  /// 해금된 업적 id.
  final Set<String> unlockedAchievements;

  /// key = recordKey.
  final Map<String, PersonalRecord> records;

  /// 새 사용자 초기 상태: 스탯 7종 10/30, 트리 7종 0 XP, todayDate = [now]의 날짜.
  static GameState initial(DateTime now) =>
      GameState(profile: Profile.initial(dateKey(now)));

  /// id로 퀘스트 찾기. 없으면 null.
  Quest? questById(int id) {
    for (final q in quests) {
      if (q.id == id) return q;
    }
    return null;
  }

  GameState copyWith({
    Profile? profile,
    List<Quest>? quests,
    int? nextQuestId,
    Set<String>? unlockedAchievements,
    Map<String, PersonalRecord>? records,
  }) =>
      GameState(
        profile: profile ?? this.profile,
        quests: quests ?? this.quests,
        nextQuestId: nextQuestId ?? this.nextQuestId,
        unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
        records: records ?? this.records,
      );

  Map<String, Object?> toJson() => {
        'profile': profile.toJson(),
        'quests': [for (final q in quests) q.toJson()],
        'next_quest_id': nextQuestId,
        'unlocked_achievements': unlockedAchievements.toList()..sort(),
        'records': {for (final e in records.entries) e.key: e.value.toJson()},
      };

  factory GameState.fromJson(Map<String, Object?> json) {
    final quests = [
      for (final q in jList(json['quests']))
        if (q is Map) Quest.fromJson(jMap(q)),
    ];
    final maxId = quests.fold(0, (m, q) => q.id > m ? q.id : m);
    final next = jInt(json['next_quest_id'] ?? json['next_id'], maxId + 1);
    return GameState(
      profile: Profile.fromJson(jMap(json['profile'])),
      quests: quests,
      nextQuestId: next > maxId ? next : maxId + 1,
      unlockedAchievements: {
        for (final a in jList(json['unlocked_achievements'])) jString(a),
      },
      records: {
        for (final e in jMap(json['records']).entries)
          if (e.value is Map)
            e.key: PersonalRecord.fromJson({...jMap(e.value), 'key': e.key}),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.profile == profile &&
      deepEquals(other.quests, quests) &&
      other.nextQuestId == nextQuestId &&
      deepEquals(other.unlockedAchievements, unlockedAchievements) &&
      deepEquals(other.records, records);

  @override
  int get hashCode => Object.hash(
        profile,
        Object.hashAll(quests),
        nextQuestId,
        deepHash(unlockedAchievements),
        deepHash(records),
      );

  @override
  String toString() =>
      'GameState(${quests.length} quests, next=$nextQuestId, $profile)';
}
