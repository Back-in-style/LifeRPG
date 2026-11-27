import '../sgcy_config.dart';
import 'json_helpers.dart';
import 'skill.dart';

enum QuestStatus {
  /// 진행 중.
  active,

  /// 완료 (보상 지급).
  done,

  /// 경고 퀘스트: 조건 충족으로 벌칙 없이 해제.
  cleared,

  /// 실패 (경고 퀘스트는 벌칙 적용, 특별 퀘스트는 기한 초과).
  failed,

  /// 기한이 지나 사라짐 (일일·주간, 벌칙 없음).
  expired;

  static QuestStatus parse(Object? v) {
    final s = jString(v).toLowerCase();
    for (final x in values) {
      if (x.name == s) return x;
    }
    return active;
  }

  String get label => switch (this) {
        active => '진행 중',
        done => '완료',
        cleared => '해제',
        failed => '실패',
        expired => '만료',
      };
}

/// 퀘스트.
///
/// - 일일·주간: [rewards]를 완료 시 지급.
/// - 특별: [rewards](다량 스탯) + [promote](세부스탯 1레벨 승급) + [grantSkill].
/// - 경고: 기한([deadline]) 안에 [windowDays] 중 [requiredDays]일 체크인하면 해제,
///   못 하면 [rewards]만큼 **감소**하고 [skillId] 스킬의 실패 횟수가 오른다.
class Quest {
  const Quest({
    required this.id,
    required this.kind,
    required this.title,
    this.desc = '',
    required this.element,
    required this.level,
    this.rewards = const {},
    this.promote,
    this.grantSkill,
    this.skillId,
    this.severity,
    this.requiredDays,
    this.windowDays,
    this.checkins = const [],
    required this.createdDate,
    this.deadline,
    this.status = QuestStatus.active,
    this.closedDate,
    this.source = 'manual',
  });

  final int id;

  /// [QuestKind] 값.
  final String kind;
  final String title;
  final String desc;

  /// 주요 요소 키.
  final String element;

  /// 퀘스트 레벨 (난이도). 일일·주간·경고는 생성 시 주요 요소 레벨(버림),
  /// 특별은 보상 레벨 (3→4 승급이면 4).
  final int level;

  /// 세부스탯별 보상 (경고는 실패 시 감소량). 생성 시 확정.
  final Map<String, double> rewards;

  /// 특별: 승급할 세부스탯 키.
  final String? promote;

  /// 특별: 완료 시 얻는 스킬.
  final SkillGrant? grantSkill;

  /// 경고: 연결된 스킬 id.
  final int? skillId;

  /// 경고: [Severity] 값.
  final String? severity;

  /// 체크인 조건 (경고 필수, 특별 선택): [windowDays]일 중 [requiredDays]일.
  final int? requiredDays;
  final int? windowDays;

  /// 체크인한 날짜들 (`YYYY-MM-DD`, 중복 없음).
  final List<String> checkins;

  final String createdDate;

  /// 마지막 날 (포함). 일일은 생성일.
  final String? deadline;

  final QuestStatus status;
  final String? closedDate;

  /// 'manual' | 'claude'
  final String source;

  bool get isActive => status == QuestStatus.active;
  bool get isWarning => kind == QuestKind.warning;
  bool get isSpecial => kind == QuestKind.special;
  bool get hasCheckins => requiredDays != null && requiredDays! > 0;
  bool get checkinsMet => hasCheckins && checkins.length >= requiredDays!;
  double get rewardTotal => rewards.values.fold(0.0, (a, b) => a + b);
  String get kindLabel => QuestKind.labels[kind] ?? kind;

  Quest copyWith({
    String? title,
    String? desc,
    Map<String, double>? rewards,
    List<String>? checkins,
    Object? deadline = unset,
    QuestStatus? status,
    Object? closedDate = unset,
  }) =>
      Quest(
        id: id,
        kind: kind,
        title: title ?? this.title,
        desc: desc ?? this.desc,
        element: element,
        level: level,
        rewards: rewards ?? this.rewards,
        promote: promote,
        grantSkill: grantSkill,
        skillId: skillId,
        severity: severity,
        requiredDays: requiredDays,
        windowDays: windowDays,
        checkins: checkins ?? this.checkins,
        createdDate: createdDate,
        deadline:
            identical(deadline, unset) ? this.deadline : deadline as String?,
        status: status ?? this.status,
        closedDate: identical(closedDate, unset)
            ? this.closedDate
            : closedDate as String?,
        source: source,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        if (desc.isNotEmpty) 'desc': desc,
        'element': element,
        'level': level,
        'rewards': rewards,
        if (promote != null) 'promote': promote,
        if (grantSkill != null) 'grant_skill': grantSkill!.toJson(),
        if (skillId != null) 'skill_id': skillId,
        if (severity != null) 'severity': severity,
        if (requiredDays != null) 'required_days': requiredDays,
        if (windowDays != null) 'window_days': windowDays,
        if (checkins.isNotEmpty) 'checkins': checkins,
        'created_date': createdDate,
        if (deadline != null) 'deadline': deadline,
        'status': status.name,
        if (closedDate != null) 'closed_date': closedDate,
        'source': source,
      };

  factory Quest.fromJson(Map<String, Object?> j) => Quest(
        id: jInt(j['id']),
        kind: jString(j['kind'], QuestKind.daily),
        title: jString(j['title']),
        desc: jString(j['desc']),
        element: jString(j['element']),
        level: SgcyConfig.clampLevel(jInt(j['level'], 1)),
        rewards: jDoubleMap(j['rewards']),
        promote: jStringOrNull(j['promote']),
        grantSkill: SkillGrant.fromJson(j['grant_skill']),
        skillId: jIntOrNull(j['skill_id']),
        severity: jStringOrNull(j['severity']),
        requiredDays: jIntOrNull(j['required_days']),
        windowDays: jIntOrNull(j['window_days']),
        checkins: [for (final c in jList(j['checkins'])) jString(c)],
        createdDate: jString(j['created_date']),
        deadline: jStringOrNull(j['deadline']),
        status: QuestStatus.parse(j['status']),
        closedDate: jStringOrNull(j['closed_date']),
        source: jString(j['source'], 'manual'),
      );

  @override
  bool operator ==(Object other) =>
      other is Quest && deepEquals(other.toJson(), toJson());

  @override
  int get hashCode => deepHash(toJson());

  @override
  String toString() => 'Quest#$id($kind $title ${status.name})';
}

/// 퀘스트 생성 입력 (수동 추가 · Claude 업데이트 공통).
///
/// 보상은 엔진이 규칙으로 계산한다:
/// - 일일: 주요 요소 레벨(버림) 일일 보상 × [scale]을 [weights] 비율로 분배
/// - 주간: 일일 × 3
/// - 경고: 일일 × 심각도 배율 (실패 시 감소량)
/// - 특별: [statRewards] 그대로 (+ [promote], [grantSkill])
class QuestDraft {
  const QuestDraft({
    required this.kind,
    required this.title,
    this.desc = '',
    required this.element,
    this.weights = const {},
    this.scale = 1,
    this.statRewards = const {},
    this.promote,
    this.grantSkill,
    this.skillId,
    this.skillName,
    this.severity,
    this.requiredDays,
    this.windowDays,
    this.deadline,
    this.source = 'manual',
  });

  final String kind;
  final String title;
  final String desc;
  final String element;

  /// 세부스탯 → 비율 (합이 1이 아니어도 정규화). 비면 주요 요소 세부스탯에 균등.
  final Map<String, double> weights;

  /// 난이도 보정 (0.6~1.4로 자름).
  final double scale;
  final Map<String, double> statRewards;
  final String? promote;
  final SkillGrant? grantSkill;
  final int? skillId;

  /// 경고: [skillId] 대신 스킬 이름으로 연결.
  final String? skillName;
  final String? severity;
  final int? requiredDays;
  final int? windowDays;
  final String? deadline;
  final String source;
}
