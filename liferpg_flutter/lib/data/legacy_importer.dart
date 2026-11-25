import 'dart:convert';

import 'package:liferpg/domain/domain.dart';

import 'game_repository.dart';

/// 레거시 KivyMD JSON 4종 → 새 [GameState] 순수 변환기 (Flutter 의존 없음).
///
/// 규칙: GAME_DESIGN §5.3·§9·§13, SPEC_v1 §2.
/// - 레거시 4스탯(힘·민첩·정신력·지구력)의 값·상한은 그대로, 신규 3스탯은 기본값(10/30).
/// - 옛 영문 스탯 키(charm/focus/communication 등)의 값은 버린다 (경고).
/// - 트리 XP는 `convertLegacyTreeXp` (레벨·XP 줄지 않음). `GameConfig.treeKeys`에 없는
///   트리 키는 버리고 경고 (저장된 level은 믿지 않는다).
/// - 퀘스트는 measureKind='flat', id·next_id 보존. ACTIVE 돌파는 recordKey 없이 그대로
///   (엔진이 레거시 규칙으로 완료).
/// - 업적 id 유지 + 임포트 직후 1회 판정 (GAME_DESIGN §9.1).
/// - totalCompletions = max(DONE 수, 로그의 '퀘스트 완료:' 수),
///   breakthroughSuccesses = 로그의 '돌파 성공:' 수.
/// - 로그 이벤트는 보존하고 import 이벤트 1건을 덧붙인다.
/// - today_date가 오늘과 달라도 그대로 둔다 (엔진 dailyRollover가 처리).
/// - 깨진 JSON·잘못된 타입은 경고로 보고하고 기본값을 쓴다 (예외를 던지지 않는다).
class LegacyImporter {
  const LegacyImporter();

  /// 가져올 수 있는 숫자의 최대 절댓값. 넘으면 없는 값으로 본다 (경고 + 기본값).
  /// 스탯·XP·id 모두 이 범위면 반올림·레벨 계산에서 넘침이 없다.
  static const double maxAbsNumber = 1e9;

  static const String completedPrefix = '퀘스트 완료:';
  static const String breakthroughPrefix = '돌파 성공:';

  /// 옛 영문 7스탯 스키마의 판정 키 (SPEC_v1 §2.2).
  static const Set<String> _oldEnglishMarker = {
    'charm',
    'focus',
    'communication'
  };

  ({GameState state, List<LogEvent> events, ImportReport report}) convert(
      LegacyBundle b, DateTime now) {
    final warnings = <String>[];
    if (b.isEmpty) warnings.add('가져올 파일이 없어 새 프로필로 시작한다');

    final profileJson = _decodeObject(b.profileJson, 'profile.json', warnings);
    final questsRaw = _decode(b.questsJson, 'quests.json', warnings);
    final logJson = _decodeObject(b.logJson, 'log.json', warnings);
    final achJson =
        _decodeObject(b.achievementsJson, 'achievements.json', warnings);

    // ---- 로그 ----
    final events = <LogEvent>[];
    final rawEvents = logJson == null ? const <Object?>[] : logJson['events'];
    if (logJson != null && rawEvents is! List) {
      warnings.add('log.json: events 목록이 없어 로그를 비운다');
    }
    var badEvents = 0;
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is! Map) {
          badEvents++;
          continue;
        }
        final m = _strMap(e);
        final ts =
            m['ts'] is String ? tryParseTimestamp(m['ts']! as String) : null;
        if (ts == null) badEvents++;
        events.add(LogEvent(
          ts: ts ?? DateTime(1970),
          type: _str(m['type'], LogEvent.system),
          message: _str(m['message']),
          meta: m['meta'] is Map ? _strMap(m['meta']! as Map) : const {},
        ));
      }
    }
    if (badEvents > 0) {
      warnings.add('log.json: 형식이 잘못된 이벤트 $badEvents건 (시각 없음은 1970-01-01로 보존)');
    }
    final completedInLog =
        events.where((e) => e.message.startsWith(completedPrefix)).length;
    final breakthroughInLog =
        events.where((e) => e.message.startsWith(breakthroughPrefix)).length;

    // ---- 퀘스트 ----
    final quests = <Quest>[];
    var nextId = 1;
    {
      Object? list;
      Object? nextRaw;
      if (questsRaw is Map) {
        list = questsRaw['quests'];
        nextRaw = questsRaw['next_id'];
      } else if (questsRaw is List) {
        list = questsRaw; // 목록만 저장된 경우도 허용
      } else if (questsRaw != null) {
        warnings.add('quests.json: 객체가 아니어서 퀘스트를 비운다');
      }
      if (questsRaw is Map && list is! List) {
        warnings.add('quests.json: quests 목록이 없어 퀘스트를 비운다');
      }
      final seen = <int>{};
      final pending = <Quest>[]; // id가 없거나 중복이라 새로 매길 퀘스트
      if (list is List) {
        for (final item in list) {
          if (item is! Map) {
            warnings.add('quests.json: 객체가 아닌 항목을 건너뛴다');
            continue;
          }
          final q = _tryConvertQuest(_strMap(item), now, warnings);
          if (q == null) continue;
          if (q.id <= 0 || seen.contains(q.id)) {
            pending.add(q);
          } else {
            seen.add(q.id);
            quests.add(q);
          }
        }
      }
      final maxId = seen.fold(0, (m, id) => id > m ? id : m);
      nextId = _int(nextRaw, 0);
      if (nextId <= maxId) nextId = maxId + 1;
      for (final q in pending) {
        warnings.add('퀘스트 "${q.title}": id가 없거나 중복이라 #$nextId로 바꾼다');
        quests.add(q.copyWith(id: nextId++));
      }
      quests.sort((a, b) => a.id.compareTo(b.id));
    }
    final doneCount = quests.where((q) => q.isDone).length;

    // ---- 프로필 ----
    var profile = _convertProfile(profileJson, now, warnings);
    profile = profile.copyWith(
      totalCompletions: doneCount > completedInLog ? doneCount : completedInLog,
      breakthroughSuccesses: breakthroughInLog,
    );

    // ---- 업적 ----
    final unlocked = <String>{};
    if (achJson != null) {
      final raw = achJson['unlocked'];
      if (raw is List) {
        for (final a in raw) {
          final id = a?.toString() ?? '';
          if (achievementDef(id) != null) {
            unlocked.add(id);
          } else {
            warnings.add('achievements.json: 알 수 없는 업적 id "$id"는 버린다');
          }
        }
      } else {
        warnings.add('achievements.json: unlocked 목록이 없어 업적을 비운다');
      }
    }
    final legacyUnlocked = unlocked.length;

    var state = GameState(
      profile: profile,
      quests: List.unmodifiable(quests),
      nextQuestId: nextId,
      unlockedAchievements: Set.unmodifiable(unlocked),
    );

    // 임포트 이벤트 + 직후 업적 판정 (GAME_DESIGN §9.1).
    final newIds = newlyUnlocked(state);
    final importEvents = <LogEvent>[
      LogEvent(
        ts: now,
        type: LogEvent.import,
        message: '레거시 데이터 가져오기: 퀘스트 ${quests.length}개, '
            '로그 ${events.length}건, 업적 $legacyUnlocked개'
            '${warnings.isEmpty ? '' : ' (경고 ${warnings.length}건)'}',
        meta: {
          'quests': quests.length,
          'events': events.length,
          'achievements': legacyUnlocked,
          'total_completions': profile.totalCompletions,
          'breakthrough_successes': profile.breakthroughSuccesses,
          'main_level': profile.mainLevel,
          'warnings': List<Object?>.of(warnings),
        },
      ),
      for (final a in newIds.map(achievementDef).whereType<AchievementDef>())
        LogEvent(
          ts: now,
          type: LogEvent.achievement,
          message: '업적 달성: ${a.icon} ${a.name} — ${a.desc}',
          meta: {'achievement_id': a.id},
        ),
    ];
    if (newIds.isNotEmpty) {
      state = state.copyWith(
          unlockedAchievements:
              Set.unmodifiable({...state.unlockedAchievements, ...newIds}));
    }
    final allEvents = List<LogEvent>.unmodifiable([...events, ...importEvents]);

    return (
      state: state,
      events: allEvents,
      report: ImportReport(
        quests: quests.length,
        events: allEvents.length,
        achievements: state.unlockedAchievements.length,
        warnings: List.unmodifiable(warnings),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 프로필
  // ---------------------------------------------------------------------------

  Profile _convertProfile(
      Map<String, Object?>? json, DateTime now, List<String> warnings) {
    final base = Profile.initial(dateKey(now));
    if (json == null) return base;

    // 스탯 (SPEC_v1 §2.2 _migrate_profile 규칙 + §13 #4)
    final stats = Map<String, StatState>.of(base.stats);
    final rawStats = json['stats'];
    final rawCaps = json['stat_caps'];
    final statMap = rawStats is Map ? _strMap(rawStats) : null;
    final capMap =
        rawCaps is Map ? _strMap(rawCaps) : const <String, Object?>{};
    if (rawStats != null && statMap == null) {
      warnings.add('profile.json: stats가 객체가 아니어서 기본값을 쓴다');
    }
    if (rawCaps != null && rawCaps is! Map) {
      warnings.add('profile.json: stat_caps가 객체가 아니어서 기본 상한을 쓴다');
    }
    final keys = statMap?.keys.toSet() ?? const <String>{};
    final oldEnglish = keys.containsAll(_oldEnglishMarker) &&
        keys.intersection(GameConfig.legacyStatKeys.toSet()).isEmpty;
    if (oldEnglish) {
      warnings.add('profile.json: 옛 영문 스탯 스키마라 스탯 값을 버리고 기본값(10)으로 시작한다');
    }
    for (final k in GameConfig.legacyStatKeys) {
      final v = oldEnglish ? null : _numOrNull(statMap?[k]);
      final c = _numOrNull(capMap[k]);
      final value =
          roundTo(v ?? GameConfig.defaultStatValue, GameConfig.statDecimals);
      final cap = c ?? GameConfig.defaultStatCap;
      stats[k] = StatState(key: k, value: value, cap: cap, peak: value);
    }
    final dropped = {
      ...keys,
      ...capMap.keys,
    }.difference(GameConfig.legacyStatKeys.toSet());
    if (dropped.isNotEmpty && !oldEnglish) {
      warnings.add('profile.json: 레거시 4종이 아닌 스탯 키를 버린다: '
          '${(dropped.toList()..sort()).join(', ')}');
    } else if (oldEnglish) {
      final extraCaps =
          capMap.keys.toSet().difference(GameConfig.legacyStatKeys.toSet());
      if (extraCaps.isNotEmpty) {
        warnings.add('profile.json: 영문 스탯 상한 키를 버린다: '
            '${(extraCaps.toList()..sort()).join(', ')}');
      }
    }

    // 트리 (§5.3)
    final trees = Map<String, TreeState>.of(base.trees);
    final rawTrees = json['trees'];
    if (rawTrees != null && rawTrees is! Map) {
      warnings.add('profile.json: trees가 객체가 아니어서 트리 XP를 0으로 둔다');
    } else if (rawTrees is Map) {
      for (final e in _strMap(rawTrees).entries) {
        final t = e.value is Map ? _strMap(e.value! as Map) : null;
        final legacyXp = _int(t?['xp'], 0);
        if (!GameConfig.treeKeys.contains(e.key)) {
          final lvl = _int(t?['level'], 1);
          warnings.add(
              'profile.json: 알 수 없는 트리 "${e.key}"(Lv.$lvl, XP $legacyXp)는 버린다'
              ' — 메인 레벨이 레거시보다 낮아질 수 있다');
          continue;
        }
        if (t == null) {
          warnings.add('profile.json: 트리 "${e.key}"가 객체가 아니어서 0 XP로 둔다');
          continue;
        }
        trees[e.key] = TreeState(
            key: e.key,
            totalXp: convertLegacyTreeXp(legacyXp < 0 ? 0 : legacyXp));
      }
    }

    // 날짜·오늘 XP: 그대로 둔다 (날짜가 다르면 엔진 rollover가 0으로 만든다)
    final today = json['today_date'];
    final todayDate =
        today is String && tryParseDateKey(today) != null ? today.trim() : null;
    if (today != null && todayDate == null) {
      warnings.add('profile.json: today_date 형식이 잘못돼 오늘 날짜를 쓴다');
    }
    final todayXp = _int(json['today_xp'], 0);

    return base.copyWith(
      stats: Map.unmodifiable(stats),
      trees: Map.unmodifiable(trees),
      todayDate: todayDate ?? base.todayDate,
      todayXp: todayXp < 0 ? 0 : todayXp,
      // 레거시 streak_days/last_active_date는 쓰이지 않던 필드라 버린다 (SPEC_v1 §4.9).
    );
  }

  // ---------------------------------------------------------------------------
  // 퀘스트
  // ---------------------------------------------------------------------------

  Quest? _tryConvertQuest(
      Map<String, Object?> json, DateTime now, List<String> warnings) {
    try {
      return _convertQuest(json, now, warnings);
    } on Object catch (e) {
      warnings.add(
          'quests.json: 읽을 수 없는 퀘스트 "${json['title'] ?? json['id']}"를 건너뛴다 ($e)');
      return null;
    }
  }

  Quest _convertQuest(
      Map<String, Object?> json, DateTime now, List<String> warnings) {
    var q = Quest.fromJson(json);
    final title = q.title.isEmpty ? '#${q.id}' : q.title;

    var type = q.type;
    if (!GameConfig.questTypes.contains(type)) {
      warnings.add('퀘스트 "$title": 알 수 없는 종류 "$type" → Side');
      type = 'Side';
    }
    final isBt = type == GameConfig.breakthroughType;
    var category = isBt ? GameConfig.breakthroughType : q.category;
    if (!isBt && !GameConfig.categoryKeys.contains(category)) {
      warnings.add('퀘스트 "$title": 알 수 없는 카테고리 "$category" → Other');
      category = 'Other';
    }
    var difficulty = q.difficulty;
    if (!GameConfig.difficultyMultiplier.containsKey(difficulty)) {
      warnings.add('퀘스트 "$title": 알 수 없는 난이도 "$difficulty" → Normal');
      difficulty = 'Normal';
    }

    // base_xp가 없고 xp(배율 적용값)만 있으면 배율을 되돌린다.
    var baseXp = q.baseXp;
    if (!isBt && json['base_xp'] == null && json['xp'] != null) {
      final mult = GameConfig.difficultyMultiplier[difficulty] ??
          GameConfig.defaultDifficultyMultiplier;
      baseXp = (_int(json['xp'], 0) / mult).round();
    }
    if (isBt) baseXp = 0;
    if (baseXp < 0) baseXp = 0;

    if (isBt &&
        (q.unlockStat == null ||
            !GameConfig.statKeys.contains(q.unlockStat) ||
            q.unlockTo == null)) {
      warnings.add('돌파 퀘스트 "$title": 대상 스탯/목표 상한이 잘못돼 완료해도 효과가 없을 수 있다');
    }

    bool ok(double? v) => v != null && v.isFinite && v.abs() <= maxAbsNumber;
    final rewards = {
      for (final e in q.rewards.entries)
        if (ok(e.value)) e.key: e.value,
    };
    if (rewards.length != q.rewards.length ||
        (q.unlockTo != null && !ok(q.unlockTo))) {
      warnings.add('퀘스트 "$title": 잘못된 숫자 값을 버린다');
    }
    if (baseXp > maxAbsNumber) baseXp = GameConfig.defaultFlatXp;

    q = q.copyWith(
      type: type,
      category: category,
      difficulty: difficulty,
      measureKind: 'flat',
      baseXp: baseXp,
      rewards: Map.unmodifiable(rewards),
      unlockTo: ok(q.unlockTo) ? q.unlockTo : null,
      recordKey: null,
      recordDirection: null,
      target: null,
      createdAt: q.createdAt == DateTime(1970) ? now : q.createdAt,
    );
    if (!isBt) q = q.copyWith(unlockStat: null, unlockTo: null);
    return q;
  }

  // ---------------------------------------------------------------------------
  // JSON 헬퍼 (domain의 json_helpers는 배럴 밖이라 여기서 최소한만 둔다)
  // ---------------------------------------------------------------------------

  /// 없으면 null(경고 없음), 깨졌으면 경고 + null.
  Object? _decode(String? src, String name, List<String> warnings) {
    if (src == null) return null;
    if (src.trim().isEmpty) {
      warnings.add('$name: 비어 있어 기본값을 쓴다');
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(src);
    } on FormatException catch (e) {
      warnings.add('$name: JSON이 깨져 기본값을 쓴다 (${e.message})');
      return null;
    }
    var bad = 0;
    final clean = _sanitize(decoded, () => bad++);
    if (bad > 0) {
      warnings.add(
          '$name: 비유한·범위 밖 숫자 $bad개(절댓값 > ${maxAbsNumber.toStringAsExponential(0)})는 '
          '없는 값으로 보고 기본값을 쓴다');
    }
    return clean;
  }

  /// 숫자 중 비유한(1e400 → Infinity)이거나 |v| > [maxAbsNumber]인 값을 null로 바꾼다.
  static Object? _sanitize(Object? v, void Function() onBad) {
    if (v is num) {
      if (!v.isFinite || v.abs() > maxAbsNumber) {
        onBad();
        return null;
      }
      return v;
    }
    if (v is Map) {
      return {
        for (final e in v.entries) e.key.toString(): _sanitize(e.value, onBad)
      };
    }
    if (v is List) return [for (final e in v) _sanitize(e, onBad)];
    return v;
  }

  Map<String, Object?>? _decodeObject(
      String? src, String name, List<String> warnings) {
    final v = _decode(src, name, warnings);
    if (v == null) return null;
    if (v is Map) return _strMap(v);
    warnings.add('$name: 최상위가 객체가 아니어서 기본값을 쓴다');
    return null;
  }

  static Map<String, Object?> _strMap(Map<dynamic, dynamic> m) =>
      {for (final e in m.entries) e.key.toString(): e.value as Object?};

  static String _str(Object? v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static double? _numOrNull(Object? v) {
    final d = v is num
        ? v.toDouble()
        : (v is String ? double.tryParse(v.trim()) : null);
    return d != null && d.isFinite && d.abs() <= maxAbsNumber ? d : null;
  }

  static int _int(Object? v, int fallback) {
    final d = _numOrNull(v);
    return d == null ? fallback : d.toInt();
  }
}
