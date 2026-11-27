import 'format.dart';
import 'models/game_state.dart';
import 'models/log_event.dart';
import 'models/observation.dart';
import 'models/quest.dart';
import 'models/skill.dart';
import 'models/substat.dart';
import 'models/update_bundle.dart';
import 'rules/progression.dart';
import 'rules/progression.dart' as prog show changeStat;
import 'sgcy_config.dart';

/// 엔진 결과. [error]가 있으면 상태는 바뀌지 않은 것이다.
class EngineResult {
  const EngineResult(this.state, {this.events = const [], this.error});

  final GameState state;
  final List<LogEvent> events;
  final String? error;
  bool get ok => error == null;
}

/// 업데이트 파일 적용 결과.
class UpdateResult extends EngineResult {
  const UpdateResult(
    super.state, {
    super.events,
    super.error,
    this.added = const [],
    this.skipped = const [],
  });

  final List<Quest> added;

  /// 적용하지 못한 항목 (상한 초과·형식 오류 등).
  final List<String> skipped;
}

/// 규칙 엔진. 부수효과 없음 — 현재 시각은 항상 인자로 받는다.
class GameEngine {
  const GameEngine();

  // ---------------------------------------------------------------------------
  // 롤오버
  // ---------------------------------------------------------------------------

  /// 날짜가 바뀌었으면: 지난 날마다 자연 감소·강등, 기한 지난 퀘스트 정리.
  EngineResult rollover(GameState s, DateTime now) {
    final today = dateKey(now);
    final gap = daysBetween(s.today, today);
    if (gap == null || gap <= 0) {
      return gap == null
          ? EngineResult(s.copyWith(today: today))
          : EngineResult(s);
    }
    final b = _Builder(s, now);
    // 너무 오래 비웠으면 최근 400일만 계산 (감소는 어차피 0에서 멈춘다).
    final days = gap > 400 ? 400 : gap;
    for (var i = days - 1; i >= 0; i--) {
      final day = addDays(today, -i);
      _decayDay(b, day);
      _closeExpired(b, day);
    }
    b.today = today;
    b.log(LogEvent.system, '날짜 변경: ${s.today} → $today');
    return b.result();
  }

  void _decayDay(_Builder b, String day) {
    for (final k in SgcyConfig.substats.map((d) => d.key)) {
      final sub = b.subs[k]!;
      if (!decaysOn(sub, day) || sub.stat <= 0) continue;
      final ch = changeStat(sub, -decayAmount(sub), day);
      b.subs[k] = ch.after;
      if (ch.demoted) {
        b.log(
            LogEvent.level,
            '강등(자연 감소): ${sub.label} ${ch.demotedFrom} → ${ch.after.level}레벨',
            {'substat': k, 'from': ch.demotedFrom, 'to': ch.after.level});
      }
    }
  }

  /// [day]가 시작될 때, 그 전날까지가 기한인 퀘스트를 닫는다.
  void _closeExpired(_Builder b, String day) {
    for (var i = 0; i < b.quests.length; i++) {
      final q = b.quests[i];
      if (!q.isActive || q.deadline == null) continue;
      if (q.deadline!.compareTo(day) >= 0) continue;
      final closed = addDays(day, -1);
      switch (q.kind) {
        case QuestKind.warning:
          _resolveWarning(b, i, closed);
        case QuestKind.special:
          if (q.hasCheckins && q.checkinsMet) {
            _complete(b, i, closed);
          } else {
            b.quests[i] =
                q.copyWith(status: QuestStatus.failed, closedDate: closed);
            b.log(
                LogEvent.quest, '특별 퀘스트 기한 초과: ${q.title}', {'quest_id': q.id});
          }
        default:
          b.quests[i] =
              q.copyWith(status: QuestStatus.expired, closedDate: closed);
      }
    }
  }

  /// 경고 퀘스트 기한 판정: 조건 충족 → 해제, 아니면 벌칙.
  void _resolveWarning(_Builder b, int i, String day) {
    final q = b.quests[i];
    if (q.checkinsMet) {
      _clearWarning(b, i, day);
      return;
    }
    b.quests[i] = q.copyWith(status: QuestStatus.failed, closedDate: day);
    b.log(LogEvent.warning, '경고 퀘스트 실패: ${q.title}', {'quest_id': q.id});
    q.rewards
        .forEach((k, amount) => b.changeStat(k, -amount, day, why: '경고 벌칙'));
    final skill = q.skillId == null ? null : b.skillById(q.skillId!);
    if (skill == null) return;
    final streak = skill.failStreak + 1;
    if (q.severity == Severity.severe ||
        streak >= SgcyConfig.skillDeleteAfterFails) {
      b.skills.removeWhere((x) => x.id == skill.id);
      b.log(LogEvent.skill, '스킬 삭제: ${skill.name}', {'skill_id': skill.id});
    } else {
      b.replaceSkill(skill.copyWith(failStreak: streak));
      b.log(LogEvent.skill,
          '스킬 경고 누적: ${skill.name} ($streak/${SgcyConfig.skillDeleteAfterFails})');
    }
  }

  void _clearWarning(_Builder b, int i, String day) {
    final q = b.quests[i];
    b.quests[i] = q.copyWith(status: QuestStatus.cleared, closedDate: day);
    b.log(LogEvent.warning, '경고 해제: ${q.title}', {'quest_id': q.id});
    final skill = q.skillId == null ? null : b.skillById(q.skillId!);
    if (skill != null && skill.failStreak != 0) {
      b.replaceSkill(skill.copyWith(failStreak: 0));
    }
  }

  // ---------------------------------------------------------------------------
  // 퀘스트
  // ---------------------------------------------------------------------------

  /// 퀘스트 추가. 보상은 규칙으로 계산한다 ([QuestDraft] 참고).
  EngineResult addQuest(GameState s, QuestDraft d, DateTime now) {
    final b = _Builder(s, now);
    final err = _add(b, d);
    if (err != null) return EngineResult(s, error: err);
    return b.result();
  }

  /// [today]에 [element]로 만든 일일 퀘스트 수 (상한 검사용).
  static int dailyCount(Iterable<Quest> quests, String element, String today) =>
      quests
          .where((q) =>
              q.kind == QuestKind.daily &&
              q.element == element &&
              q.createdDate == today)
          .length;

  String? _add(_Builder b, QuestDraft d) {
    final today = b.today;
    if (d.title.trim().isEmpty) return '제목이 비었습니다';
    if (!QuestKind.all.contains(d.kind)) return '알 수 없는 퀘스트 종류: ${d.kind}';
    if (!SgcyConfig.elementByKey.containsKey(d.element)) {
      return '알 수 없는 주요 요소: ${d.element}';
    }
    final elLabel = SgcyConfig.elementByKey[d.element]!.label;
    final elLevel = b.elementRewardLevel(d.element);
    final scale = d.scale.isFinite
        ? d.scale.clamp(SgcyConfig.minScale, SgcyConfig.maxScale).toDouble()
        : 1.0;
    final daily = SgcyConfig.dailyReward(elLevel);

    var level = elLevel;
    var rewards = const <String, double>{};
    String? deadline = d.deadline;
    int? required = d.requiredDays, window = d.windowDays;
    int? skillId = d.skillId;

    switch (d.kind) {
      case QuestKind.daily:
        if (dailyCount(b.quests, d.element, today) >=
            SgcyConfig.dailyCapPerElement) {
          return '오늘 $elLabel 일일 퀘스트는 이미 ${SgcyConfig.dailyCapPerElement}개입니다';
        }
        rewards = distribute(daily * scale, d.weights, d.element);
        deadline = today;
      case QuestKind.weekly:
        rewards = distribute(
            daily * SgcyConfig.weeklyMultiplier * scale, d.weights, d.element);
        deadline ??= addDays(today, SgcyConfig.weeklyDays - 1);
      case QuestKind.warning:
        final sev = d.severity ?? Severity.normal;
        final mult = SgcyConfig.severityMultiplier[sev] ?? 3;
        rewards = distribute(daily * mult * scale, d.weights, d.element);
        window ??= SgcyConfig.warningWindowDays;
        required ??= SgcyConfig.warningRequiredDays;
        deadline ??= addDays(today, window - 1);
        if (skillId != null && b.skillById(skillId) == null) skillId = null;
        if (skillId == null && d.skillName != null) {
          final name = d.skillName!.trim();
          for (final k in b.skills) {
            if (k.name == name) skillId = k.id;
          }
        }
      case QuestKind.special:
        rewards = {
          for (final e in d.statRewards.entries)
            if (e.value > 0) e.key: roundStat(e.value),
        };
        if (d.promote != null) {
          final sub = b.subs[d.promote];
          if (sub == null) return '알 수 없는 세부스탯: ${d.promote}';
          if (sub.level >= SgcyConfig.maxLevel) {
            return '${sub.label}은(는) 이미 최고 레벨입니다';
          }
          level = sub.level + 1;
        } else {
          level = elLevel;
        }
        if (rewards.isEmpty && d.promote == null && d.grantSkill == null) {
          return '특별 퀘스트에는 승급·스탯·스킬 보상 중 하나가 필요합니다';
        }
        if (window != null && required == null) required = window;
        if (required != null) {
          window ??= required;
          deadline ??= addDays(today, window - 1);
        }
    }
    if (required != null && window != null) {
      if (window < 1) window = 1;
      if (required < 1) required = 1;
      if (required > window) required = window;
    } else {
      required = null;
      window = null;
    }
    if (deadline != null && tryParseDateKey(deadline) == null) deadline = null;

    final q = Quest(
      id: b.nextId++,
      kind: d.kind,
      title: d.title.trim(),
      desc: d.desc.trim(),
      element: d.element,
      level: level,
      rewards: rewards,
      promote: d.kind == QuestKind.special ? d.promote : null,
      grantSkill: d.kind == QuestKind.special ? d.grantSkill : null,
      skillId: d.kind == QuestKind.warning ? skillId : null,
      severity:
          d.kind == QuestKind.warning ? (d.severity ?? Severity.normal) : null,
      requiredDays: required,
      windowDays: window,
      createdDate: today,
      deadline: deadline,
      source: d.source,
    );
    b.quests.add(q);
    b.added.add(q);
    b.log(LogEvent.quest, '${q.kindLabel} 퀘스트 추가: ${q.title}',
        {'quest_id': q.id, 'kind': q.kind});
    return null;
  }

  /// 일일·주간·특별 퀘스트 완료 → 보상.
  EngineResult completeQuest(GameState s, int id, DateTime now) {
    final b = _Builder(s, now);
    final i = b.quests.indexWhere((q) => q.id == id);
    if (i < 0) return EngineResult(s, error: '퀘스트가 없습니다');
    final q = b.quests[i];
    if (!q.isActive) return EngineResult(s, error: '이미 끝난 퀘스트입니다');
    if (q.isWarning) {
      return EngineResult(s, error: '경고 퀘스트는 체크인으로 해제합니다');
    }
    if (q.hasCheckins && !q.checkinsMet) {
      return EngineResult(s,
          error: '체크인 ${q.checkins.length}/${q.requiredDays}일 — 조건을 먼저 채우세요');
    }
    _complete(b, i, b.today);
    return b.result();
  }

  void _complete(_Builder b, int i, String day) {
    final q = b.quests[i];
    b.quests[i] = q.copyWith(status: QuestStatus.done, closedDate: day);
    b.log(LogEvent.quest, '${q.kindLabel} 퀘스트 완료: ${q.title}',
        {'quest_id': q.id});
    q.rewards.forEach((k, v) => b.changeStat(k, v, day, why: q.title));
    if (q.promote != null) {
      final before = b.subs[q.promote]!;
      final after = promote(before, day);
      b.subs[q.promote!] = after;
      if (after.level != before.level) {
        b.log(
            LogEvent.level,
            '승급: ${before.label} ${before.level} → ${after.level}레벨 (${after.levelName})',
            {'substat': q.promote, 'from': before.level, 'to': after.level});
      }
    }
    final g = q.grantSkill;
    if (g != null) {
      final skill = Skill(
        id: b.nextId++,
        name: g.name,
        desc: g.desc,
        element: g.element.isEmpty ? q.element : g.element,
        acquiredDate: day,
      );
      b.skills.add(skill);
      b.log(LogEvent.skill, '스킬 획득: ${skill.name}', {'skill_id': skill.id});
    }
  }

  /// 오늘 체크인 토글 (경고·체크인 조건이 있는 특별 퀘스트).
  /// 경고 퀘스트는 조건을 채우는 순간 해제된다.
  EngineResult toggleCheckin(GameState s, int id, DateTime now) {
    final b = _Builder(s, now);
    final i = b.quests.indexWhere((q) => q.id == id);
    if (i < 0) return EngineResult(s, error: '퀘스트가 없습니다');
    final q = b.quests[i];
    if (!q.isActive) return EngineResult(s, error: '이미 끝난 퀘스트입니다');
    if (!q.hasCheckins) return EngineResult(s, error: '체크인이 없는 퀘스트입니다');
    final today = b.today;
    final list = List.of(q.checkins);
    if (list.contains(today)) {
      list.remove(today);
    } else {
      list
        ..add(today)
        ..sort();
    }
    b.quests[i] = q.copyWith(checkins: list);
    b.log(
        LogEvent.quest,
        '체크인 ${list.contains(today) ? '' : '취소 '}(${list.length}/${q.requiredDays}): ${q.title}',
        {'quest_id': q.id});
    if (q.isWarning && b.quests[i].checkinsMet) _clearWarning(b, i, today);
    return b.result();
  }

  /// 특별·주간 퀘스트 포기 (벌칙 없음). 경고 퀘스트는 포기할 수 없다.
  EngineResult giveUp(GameState s, int id, DateTime now) {
    final b = _Builder(s, now);
    final i = b.quests.indexWhere((q) => q.id == id);
    if (i < 0) return EngineResult(s, error: '퀘스트가 없습니다');
    final q = b.quests[i];
    if (!q.isActive) return EngineResult(s, error: '이미 끝난 퀘스트입니다');
    if (q.isWarning) return EngineResult(s, error: '경고 퀘스트는 포기할 수 없습니다');
    b.quests[i] = q.copyWith(status: QuestStatus.failed, closedDate: b.today);
    b.log(LogEvent.quest, '퀘스트 포기: ${q.title}', {'quest_id': q.id});
    return b.result();
  }

  /// 퀘스트 삭제 (잘못 만든 것 정리용). 경고 퀘스트는 삭제할 수 없다.
  EngineResult deleteQuest(GameState s, int id, DateTime now) {
    final q = s.questById(id);
    if (q == null) return EngineResult(s, error: '퀘스트가 없습니다');
    if (q.isWarning && q.isActive) {
      return EngineResult(s, error: '진행 중인 경고 퀘스트는 삭제할 수 없습니다');
    }
    final b = _Builder(s, now);
    b.quests.removeWhere((x) => x.id == id);
    b.log(LogEvent.quest, '퀘스트 삭제: ${q.title}', {'quest_id': id});
    return b.result();
  }

  /// 레벨 배치 (초기 판정·보정). 그 레벨의 승급 직후 상태로 둔다.
  EngineResult placeLevel(
      GameState s, String substat, int level, DateTime now) {
    final sub = s.substats[substat];
    if (sub == null) return EngineResult(s, error: '알 수 없는 세부스탯: $substat');
    final b = _Builder(s, now);
    final after = place(sub, level, b.today);
    b.subs[substat] = after;
    b.log(LogEvent.level, '배치: ${sub.label} ${sub.level} → ${after.level}레벨',
        {'substat': substat, 'from': sub.level, 'to': after.level});
    return b.result();
  }

  /// 스킬 직접 삭제.
  EngineResult removeSkill(GameState s, int id, DateTime now) {
    final skill = s.skillById(id);
    if (skill == null) return EngineResult(s, error: '스킬이 없습니다');
    final b = _Builder(s, now);
    b.skills.removeWhere((x) => x.id == id);
    b.log(LogEvent.skill, '스킬 삭제: ${skill.name}', {'skill_id': id});
    return b.result();
  }

  // ---------------------------------------------------------------------------
  // Claude 업데이트 파일
  // ---------------------------------------------------------------------------

  /// 통합 업데이트 파일 적용: 배치 → 관찰 기록 → 프로필 → 퀘스트(상한 검사).
  UpdateResult applyUpdate(GameState s, UpdateBundle u, DateTime now) {
    final r = rollover(s, now);
    final b = _Builder(r.state, now)..events.addAll(r.events);
    final skipped = List.of(u.problems);

    u.placements.forEach((k, l) {
      final sub = b.subs[k]!;
      if (sub.level == l) return;
      b.subs[k] = place(sub, l, b.today);
      b.log(LogEvent.level, '배치: ${sub.label} ${sub.level} → $l레벨',
          {'substat': k, 'from': sub.level, 'to': l});
    });

    if (u.observations.isNotEmpty) {
      final day = u.date ?? b.today;
      b.observations.addAll([
        for (final o in u.observations)
          o.date.isEmpty
              ? Observation(
                  date: day, element: o.element, kind: o.kind, text: o.text)
              : o,
      ]);
      final over = b.observations.length - SgcyConfig.maxObservations;
      if (over > 0) b.observations.removeRange(0, over);
    }
    if (u.profileNotes != null) b.profileNotes = u.profileNotes!;

    for (final d in u.quests) {
      final err = _add(b, d);
      if (err != null) skipped.add('"${d.title}": $err');
    }

    b.lastUpdateDate = u.date ?? b.today;
    if (u.summary.isNotEmpty) b.lastSummary = u.summary;
    b.log(
        LogEvent.update,
        'Claude 업데이트 적용: 퀘스트 ${b.added.length}개, 관찰 ${u.observations.length}개'
        '${skipped.isEmpty ? '' : ', 건너뜀 ${skipped.length}개'}');
    final res = b.result();
    return UpdateResult(res.state,
        events: res.events, added: List.of(b.added), skipped: skipped);
  }
}

/// 엔진 내부 가변 작업본.
class _Builder {
  _Builder(this.state, this.now)
      : subs = Map.of(state.substats),
        quests = List.of(state.quests),
        skills = List.of(state.skills),
        observations = List.of(state.observations),
        profileNotes = state.profileNotes,
        nextId = state.nextId,
        today = state.today,
        lastUpdateDate = state.lastUpdateDate,
        lastSummary = state.lastSummary;

  final GameState state;
  final DateTime now;
  final Map<String, SubStat> subs;
  final List<Quest> quests;
  final List<Skill> skills;
  final List<Observation> observations;
  List<String> profileNotes;
  int nextId;
  String today;
  String? lastUpdateDate;
  String lastSummary;
  final List<LogEvent> events = [];
  final List<Quest> added = [];

  void log(String type, String message,
          [Map<String, Object?> meta = const {}]) =>
      events.add(LogEvent(ts: now, type: type, message: message, meta: meta));

  /// 작업 중인 세부스탯 기준 주요 요소 보상 레벨.
  int elementRewardLevel(String element) =>
      GameState(substats: subs, today: today).elementRewardLevel(element);

  Skill? skillById(int id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  void replaceSkill(Skill s) {
    final i = skills.indexWhere((x) => x.id == s.id);
    if (i >= 0) skills[i] = s;
  }

  void changeStat(String key, double delta, String day, {String why = ''}) {
    final sub = subs[key];
    if (sub == null || delta == 0) return;
    final ch = prog.changeStat(sub, delta, day);
    subs[key] = ch.after;
    log(
        LogEvent.stat,
        '${sub.label} ${delta > 0 ? '+' : ''}${formatStat(delta)}${why.isEmpty ? '' : ' ($why)'}',
        {'substat': key, 'delta': delta});
    if (ch.demoted) {
      log(
          LogEvent.level,
          '강등: ${sub.label} ${ch.demotedFrom} → ${ch.after.level}레벨',
          {'substat': key, 'from': ch.demotedFrom, 'to': ch.after.level});
    }
  }

  EngineResult result() {
    // 오래된 종료 퀘스트 정리.
    final closed = quests.where((q) => !q.isActive).length;
    var drop = closed - SgcyConfig.maxClosedQuests;
    if (drop > 0) {
      quests.removeWhere((q) => !q.isActive && drop-- > 0);
    }
    return EngineResult(
      state.copyWith(
        substats: subs,
        quests: quests,
        skills: skills,
        observations: observations,
        profileNotes: profileNotes,
        nextId: nextId,
        today: today,
        lastUpdateDate: lastUpdateDate,
        lastSummary: lastSummary,
      ),
      events: events,
    );
  }
}
