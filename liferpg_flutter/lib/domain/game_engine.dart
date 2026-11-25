/// 게임 엔진 (INTERFACES §3). 부수효과 없는 순수 함수 모음.
///
/// 모든 메서드는 `(GameState, 입력, now) → 결과`이며 [DateTime.now]를 호출하지 않는다.
/// 실패하면 `result.error`가 채워지고 `result.state`는 입력 그대로, events는 비어 있다.
library;

import 'format.dart';
import 'game_config.dart';
import 'models/completion.dart';
import 'models/game_state.dart';
import 'models/log_event.dart';
import 'models/measurement.dart';
import 'models/personal_record.dart';
import 'models/quest.dart';
import 'models/skill_tree.dart';
import 'models/stat.dart';
import 'rules/achievements.dart';
import 'rules/breakthrough.dart';
import 'rules/diminishing.dart';
import 'rules/leveling.dart';
import 'rules/records.dart';
import 'rules/stats.dart';
import 'rules/streak.dart';
import 'rules/xp_formula.dart';

export 'rules/breakthrough.dart' show BreakthroughResult;

enum GameError { questNotFound, alreadyDone, invalidMeasurement, invalidDraft }

class EngineResult {
  const EngineResult({
    required this.state,
    this.events = const [],
    this.quest,
    this.error,
  });

  final GameState state;

  /// data 계층이 append 저장 (시간순).
  final List<LogEvent> events;

  /// addQuest: 생성된 퀘스트 / 그 밖: 대상 퀘스트의 결과 상태.
  final Quest? quest;

  /// 실패 시 원인. 이때 [state]는 입력 그대로.
  final GameError? error;

  bool get ok => error == null;
}

class CompletionResult extends EngineResult {
  const CompletionResult({
    required super.state,
    super.events,
    super.quest,
    super.error,
    this.completion,
    this.xp = 0,
    this.tree,
    this.leveledUp = false,
    this.newTreeLevel,
    this.statGains = const {},
    this.breakthrough,
    this.isPr = false,
    this.newAchievements = const [],
  });

  /// data 계층이 저장 (id는 null).
  final Completion? completion;
  final int xp;
  final String? tree;

  /// 트리 레벨업 여부.
  final bool leveledUp;

  /// 레벨업했을 때 새 트리 레벨.
  final int? newTreeLevel;

  /// 실제 적용분 (applied > 0).
  final Map<String, double> statGains;
  final BreakthroughResult? breakthrough;
  final bool isPr;

  /// 업적 id (`GameConfig.achievements` 순서).
  final List<String> newAchievements;
}

class GameEngine {
  const GameEngine();

  // ---------------------------------------------------------------------------
  // 일일 리셋
  // ---------------------------------------------------------------------------

  /// 날짜가 바뀌었으면 Daily 퀘스트 ACTIVE 복귀, todayXp/rawToday/countToday 초기화,
  /// 스트릭 표시값 갱신(마지막 활동이 어제보다 전이면 0).
  /// 같은 날이면 state 그대로, events 빈 리스트.
  EngineResult dailyRollover(GameState state, DateTime now) {
    final today = dateKey(now);
    final p = state.profile;
    if (p.todayDate == today) return EngineResult(state: state);

    final quests = [
      for (final q in state.quests)
        q.type == 'Daily'
            ? q.copyWith(status: QuestStatus.active, completedAt: null)
            : q,
    ];
    var next = state.copyWith(
      quests: quests,
      profile: p.copyWith(
        todayDate: today,
        todayXp: 0,
        rawToday: const {},
        countToday: const {},
        streakDays: streakOnRollover(
            streakDays: p.streakDays,
            lastActiveDate: p.lastActiveDate,
            today: today),
      ),
    );
    final events = <LogEvent>[
      LogEvent(
          ts: now,
          type: LogEvent.system,
          message: '일일 퀘스트 초기화: $today',
          meta: {'date': today}),
    ];
    final (s, _) = _unlockAchievements(next, now, events);
    next = s;
    return EngineResult(state: next, events: List.unmodifiable(events));
  }

  /// 상태창 "오늘 XP 초기화" (SPEC_v1 §4.6). todayXp만 0으로 만든다 —
  /// rawToday/countToday는 유지해 체감 감소 우회를 막는다. 먼저 일일 리셋을 적용한다.
  EngineResult resetTodayXp(GameState state, DateTime now) {
    final rolled = dailyRollover(state, now);
    final s = rolled.state;
    return EngineResult(
      state: s.copyWith(profile: s.profile.copyWith(todayXp: 0)),
      events: List.unmodifiable([
        ...rolled.events,
        LogEvent(ts: now, type: LogEvent.system, message: '오늘 XP 초기화'),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // 퀘스트 추가 / 삭제 / 진행률
  // ---------------------------------------------------------------------------

  /// 퀘스트 추가. 검증 실패 시 [GameError.invalidDraft].
  /// 돌파: `unlockStat`은 스탯 키, `unlockTo > 현재 상한`, `recordKey` 필수(R5).
  /// recordKey가 있고 기록이 없으면 빈 [PersonalRecord]를 만든다.
  EngineResult addQuest(GameState state, QuestDraft draft, DateTime now) {
    final title = draft.title.trim();
    final desc = draft.desc.trim();
    final deadline = _blankToNull(draft.deadline);
    final recordKey = _blankToNull(draft.recordKey);
    final direction = draft.recordDirection ?? 'higher';
    EngineResult fail() =>
        EngineResult(state: state, error: GameError.invalidDraft);

    if (title.isEmpty) return fail();
    if (deadline != null && tryParseDateKey(deadline) == null) return fail();
    if (!GameConfig.questTypes.contains(draft.type)) return fail();
    if (direction != 'higher' && direction != 'lower') return fail();
    if (draft.target != null && !draft.target!.isFinite) return fail();

    final id = state.nextQuestId;
    final Quest quest;
    final String message;
    if (draft.isBreakthrough) {
      final stat = draft.unlockStat;
      final unlockTo = draft.unlockTo;
      final cur = stat == null ? null : state.profile.stats[stat];
      if (stat == null ||
          !GameConfig.statKeys.contains(stat) ||
          cur == null ||
          unlockTo == null ||
          !unlockTo.isFinite ||
          unlockTo <= cur.cap ||
          recordKey == null) {
        return fail();
      }
      quest = Quest(
        id: id,
        title: title,
        desc: desc,
        type: GameConfig.breakthroughType,
        category: GameConfig.breakthroughType,
        difficulty: 'Normal',
        measureKind: 'flat',
        baseXp: 0,
        unlockStat: stat,
        unlockTo: unlockTo,
        deadline: deadline,
        recordKey: recordKey,
        recordDirection: direction,
        target: draft.target,
        createdAt: now,
      );
      message = '돌파 퀘스트 추가: $title';
    } else {
      if (!GameConfig.categoryKeys.contains(draft.category) ||
          !GameConfig.difficultyMultiplier.containsKey(draft.difficulty) ||
          !GameConfig.measureKinds.contains(draft.measureKind) ||
          draft.baseXp < 0 ||
          draft.rewards.values.any((v) => !v.isFinite) ||
          draft.rewards.keys.any((k) => !GameConfig.statKeys.contains(k))) {
        return fail();
      }
      quest = Quest(
        id: id,
        title: title,
        desc: desc,
        type: draft.type,
        category: draft.category,
        difficulty: draft.difficulty,
        measureKind: draft.measureKind,
        baseXp: draft.baseXp,
        rewards: Map.unmodifiable({
          for (final e in draft.rewards.entries)
            if (e.value != 0) e.key: e.value,
        }),
        deadline: deadline,
        recordKey: recordKey,
        recordDirection: recordKey == null ? null : direction,
        target: draft.target,
        createdAt: now,
      );
      message = quest.isFlat
          ? '퀘스트 추가: [${quest.type}] $title (+${quest.xp}XP, ${quest.difficulty})'
          : '퀘스트 추가: [${quest.type}] $title (${quest.measureKind}, ${quest.difficulty})';
    }

    var records = state.records;
    if (recordKey != null && !records.containsKey(recordKey)) {
      records = Map.unmodifiable({
        ...records,
        recordKey: PersonalRecord(
            key: recordKey, direction: direction, stat: quest.unlockStat),
      });
    }
    final next = state.copyWith(
      quests: List.unmodifiable([...state.quests, quest]),
      nextQuestId: id + 1,
      records: records,
    );
    return EngineResult(
      state: next,
      quest: quest,
      events: List.unmodifiable([
        LogEvent(
            ts: now,
            type: LogEvent.quest,
            message: message,
            meta: {'quest_id': id}),
      ]),
    );
  }

  /// 퀘스트 삭제. 받은 XP·스탯·업적은 되돌리지 않는다 (레거시 동일).
  EngineResult deleteQuest(GameState state, int questId, DateTime now) {
    final q = state.questById(questId);
    if (q == null) {
      return EngineResult(state: state, error: GameError.questNotFound);
    }
    return EngineResult(
      state: state.copyWith(
          quests: List.unmodifiable(
              state.quests.where((x) => x.id != questId).toList())),
      quest: q,
      events: List.unmodifiable([
        LogEvent(
            ts: now,
            type: LogEvent.quest,
            message: '퀘스트 삭제: ${q.title}',
            meta: {'quest_id': questId}),
      ]),
    );
  }

  /// 진행률 설정 (0~100으로 클램프). 로그 없음 (레거시 동일).
  EngineResult updateProgress(
      GameState state, int questId, int progress, DateTime now) {
    final q = state.questById(questId);
    if (q == null) {
      return EngineResult(state: state, error: GameError.questNotFound);
    }
    final updated = q.copyWith(progress: progress.clamp(0, 100).toInt());
    return EngineResult(
      state: state.copyWith(quests: _replaceQuest(state.quests, updated)),
      quest: updated,
    );
  }

  // ---------------------------------------------------------------------------
  // 완료
  // ---------------------------------------------------------------------------

  /// 완료 (GAME_DESIGN §3.4 순서). 내부에서 [dailyRollover]를 먼저 적용한다.
  ///
  /// 로그 순서: (일일 초기화) → 퀘스트 완료 → (PR) → (돌파 성공/실패) → XP → (레벨업)
  /// → 스탯 상승×n → 업적×n.
  CompletionResult completeQuest(
      GameState state, int questId, CompletionInput input, DateTime now) {
    CompletionResult fail(GameError e) =>
        CompletionResult(state: state, error: e);

    final rolled = dailyRollover(state, now);
    var s = rolled.state;
    final q = s.questById(questId);
    if (q == null) return fail(GameError.questNotFound);
    if (q.isDone) return fail(GameError.alreadyDone);
    final err = _validateInput(q, input);
    if (err != null) return fail(err);

    final today = dateKey(now);
    final events = <LogEvent>[...rolled.events];

    // 상태 DONE, 카운터, 스트릭 (§8: 첫 완료 시점에 갱신 → 이번 XP에 반영).
    final done = q.copyWith(status: QuestStatus.done, completedAt: now);
    events.add(LogEvent(
        ts: now,
        type: LogEvent.quest,
        message: '퀘스트 완료: ${q.title}',
        meta: {'quest_id': q.id}));
    final streak = markActive(
        streakDays: s.profile.streakDays,
        lastActiveDate: s.profile.lastActiveDate,
        today: today);
    var p = s.profile.copyWith(
      totalCompletions: s.profile.totalCompletions + 1,
      streakDays: streak.streakDays,
      lastActiveDate: streak.lastActiveDate,
    );
    var records = s.records;

    // 기록 / PR.
    var pr = false;
    final recordValue = input.recordValue;
    if (q.recordKey != null && recordValue != null) {
      final r = recordAfter(
        record: records[q.recordKey],
        key: q.recordKey!,
        value: recordValue,
        at: now,
        direction: q.recordDirection ?? 'higher',
        stat: q.unlockStat,
        target: q.isBreakthrough ? q.target : null,
      );
      pr = r.isPr;
      records = Map.unmodifiable({...records, q.recordKey!: r.record});
      if (pr) {
        p = p.copyWith(prCount: p.prCount + 1);
        events.add(LogEvent(
            ts: now,
            type: LogEvent.pr,
            message: '개인기록 갱신: ${q.recordKey} ${formatG(recordValue)}',
            meta: {
              'quest_id': q.id,
              'record_key': q.recordKey,
              'value': recordValue,
            }));
      }
    }

    BreakthroughResult? bt;
    String? tree;
    var raw = 0;
    var xp = 0;
    var leveledUp = false;
    int? newTreeLevel;
    final applied = <String, double>{};

    if (q.isBreakthrough) {
      // §7.3 돌파: 트리 XP·스탯 보상 없음.
      final stat = q.unlockStat;
      final unlockTo = q.unlockTo;
      final cur = stat == null ? null : p.stats[stat];
      if (stat != null &&
          GameConfig.statKeys.contains(stat) &&
          cur != null &&
          unlockTo != null) {
        bt = resolveBreakthrough(
          stat: stat,
          cap: cur.cap,
          requestedCap: unlockTo,
          prAchieved: q.isLegacyBreakthrough || pr,
        );
        if (bt.success) {
          p = p.copyWith(
            stats: _put(p.stats, stat, cur.copyWith(cap: bt.newCap)),
            breakthroughSuccesses: p.breakthroughSuccesses + 1,
          );
          events.add(LogEvent(
              ts: now,
              type: LogEvent.breakthrough,
              message:
                  '돌파 성공: $stat 상한 ${pyFloat(bt.oldCap)} → ${pyFloat(bt.newCap)}',
              meta: {
                'quest_id': q.id,
                'stat': stat,
                'old_cap': bt.oldCap,
                'new_cap': bt.newCap,
                'success': true,
              }));
        } else {
          events.add(LogEvent(
              ts: now,
              type: LogEvent.breakthrough,
              message: '돌파 실패: $stat 상한 ${pyFloat(bt.oldCap)} 유지',
              meta: {
                'quest_id': q.id,
                'stat': stat,
                'old_cap': bt.oldCap,
                'new_cap': bt.newCap,
                'success': false,
              }));
        }
      }
    } else {
      // §3.4 1~2단계.
      final values = input.measurement?.values ?? const <String, double>{};
      raw = rawXp(q.measureKind, values, q.difficulty, flatXp: q.xp);
      if (pr) raw += GameConfig.prBonusXp;

      tree = GameConfig.categoryToTree[q.category];
      var rewardRatio = 1.0;
      if (tree != null) {
        final before = p.rawToday[tree] ?? 0;
        final n = (p.countToday[tree] ?? 0) + 1;
        // 3~4단계.
        final eff4 = diminish(tree, before, raw) * repeatMultiplier(n);
        rewardRatio = raw > 0 ? eff4 / raw : 1.0;
        // 6~7단계 (5단계 R4는 MVP 이후).
        xp = (eff4 * (1 + streakBonus(p.streakDays))).round();
        // 8단계.
        final t = p.trees[tree] ?? TreeState(key: tree);
        final lvBefore = levelFromXp(t.totalXp).level;
        final lvAfter = levelFromXp(t.totalXp + xp).level;
        p = p.copyWith(
          trees: _put(p.trees, tree, t.copyWith(totalXp: t.totalXp + xp)),
          todayXp: p.todayXp + xp,
          rawToday: _put(p.rawToday, tree, before + raw),
          countToday: _put(p.countToday, tree, n),
        );
        final label = (GameConfig.treeLabels[tree] ?? tree).toUpperCase();
        if (xp > 0) {
          events.add(LogEvent(
              ts: now,
              type: LogEvent.xp,
              message: '$label XP +$xp: 퀘스트: ${q.title}',
              meta: {'quest_id': q.id, 'tree': tree, 'xp': xp, 'raw': raw}));
        }
        if (lvAfter > lvBefore) {
          leveledUp = true;
          newTreeLevel = lvAfter;
          events.add(LogEvent(
              ts: now,
              type: LogEvent.system,
              message: '$label 레벨업! Lv.$lvBefore → Lv.$lvAfter',
              meta: {'tree': tree, 'from': lvBefore, 'to': lvAfter}));
        }
      }

      // 9단계 스탯 (§6).
      final deltas = statGainsFor(
          quest: q, xp: xp, stats: p.stats, rewardRatio: rewardRatio);
      var stats = p.stats;
      for (final e in deltas.entries) {
        final cur = stats[e.key] ?? StatState.initial(e.key);
        final r = applyStatDelta(cur.value, e.value, cur.cap);
        final nv = roundTo(r.value, GameConfig.statDecimals);
        final realApplied = nv - cur.value;
        var ns = cur.copyWith(value: nv);
        if (r.applied > 0) {
          ns = ns.copyWith(
              peak: nv > cur.peak ? nv : cur.peak, lastGainDate: today);
        }
        stats = _put(stats, e.key, ns);
        if (realApplied != 0) {
          applied[e.key] = roundTo(realApplied, GameConfig.statDecimals);
        }
        if (r.applied > 0) {
          events.add(LogEvent(
              ts: now,
              type: LogEvent.stat,
              message: '스탯 상승: ${e.key} +${formatG(r.applied)}',
              meta: {'quest_id': q.id, 'stat': e.key, 'applied': r.applied}));
        }
      }
      p = p.copyWith(stats: stats);
    }

    s = s.copyWith(
      profile: p,
      quests: _replaceQuest(s.quests, done),
      records: records,
    );
    final (s2, newAch) = _unlockAchievements(s, now, events);
    s = s2;

    final completion = Completion(
      questId: q.id,
      questTitle: q.title,
      category: q.category,
      tree: tree,
      measureKind: q.measureKind,
      values: Map.unmodifiable(
          input.measurement?.values ?? const <String, double>{}),
      rawXp: raw,
      xp: xp,
      statGains: Map.unmodifiable(applied),
      recordKey: q.recordKey,
      recordValue: q.recordKey == null ? null : recordValue,
      isPr: pr,
      at: now,
    );

    return CompletionResult(
      state: s,
      events: List.unmodifiable(events),
      quest: done,
      completion: completion,
      xp: xp,
      tree: tree,
      leveledUp: leveledUp,
      newTreeLevel: newTreeLevel,
      statGains: Map.unmodifiable({
        for (final e in applied.entries)
          if (e.value > 0) e.key: e.value
      }),
      breakthrough: bt,
      isPr: pr,
      newAchievements: List.unmodifiable(newAch),
    );
  }

  // ---------------------------------------------------------------------------
  // 내부
  // ---------------------------------------------------------------------------

  GameError? _validateInput(Quest q, CompletionInput input) {
    final rv = input.recordValue;
    if (rv != null && !rv.isFinite) return GameError.invalidMeasurement;
    if (q.isBreakthrough) {
      if (!q.isLegacyBreakthrough && rv == null) {
        return GameError.invalidMeasurement;
      }
      return null;
    }
    final m = input.measurement;
    if (q.isFlat) {
      if (m != null && m.kind != 'flat') return GameError.invalidMeasurement;
      return null;
    }
    if (m == null || m.kind != q.measureKind) {
      return GameError.invalidMeasurement;
    }
    if (m.values.values.any((v) => !v.isFinite || v < 0)) {
      return GameError.invalidMeasurement;
    }
    return null;
  }

  /// 업적 판정 → 해금 + 로그 추가. (새 상태, 새 id 목록).
  (GameState, List<String>) _unlockAchievements(
      GameState s, DateTime now, List<LogEvent> events) {
    final ids = newlyUnlocked(s);
    if (ids.isEmpty) return (s, const []);
    for (final id in ids) {
      final a = achievementDef(id)!;
      events.add(LogEvent(
          ts: now,
          type: LogEvent.achievement,
          message: '업적 달성: ${a.icon} ${a.name} — ${a.desc}',
          meta: {'achievement_id': id}));
    }
    return (
      s.copyWith(
          unlockedAchievements:
              Set.unmodifiable({...s.unlockedAchievements, ...ids})),
      ids,
    );
  }

  static List<Quest> _replaceQuest(List<Quest> quests, Quest q) =>
      List.unmodifiable([for (final x in quests) x.id == q.id ? q : x]);

  static Map<String, V> _put<V>(Map<String, V> m, String k, V v) =>
      Map.unmodifiable({...m, k: v});

  static String? _blankToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
