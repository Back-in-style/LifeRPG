import '../sgcy_config.dart';
import 'json_helpers.dart';
import 'observation.dart';
import 'quest.dart';
import 'skill.dart';

/// Claude 에이전트가 하루 대화 후 만드는 통합 업데이트 파일 (`sgcy-update` v1).
///
/// 형식은 `claude/UPDATE_FORMAT.md`. 키는 영문 키 또는 한글 라벨 둘 다 받는다.
class UpdateBundle {
  const UpdateBundle({
    required this.date,
    this.summary = '',
    this.observations = const [],
    this.placements = const {},
    this.quests = const [],
    this.profileNotes,
    this.problems = const [],
  });

  static const String format = 'sgcy-update';

  final String? date;
  final String summary;
  final List<Observation> observations;

  /// 초기 판정·보정용 레벨 배치 (세부스탯 → 레벨).
  final Map<String, int> placements;
  final List<QuestDraft> quests;

  /// null이면 기존 유지, 있으면 통째로 교체.
  final List<String>? profileNotes;

  /// 읽다가 버린 항목 설명.
  final List<String> problems;

  /// JSON 객체를 읽는다. 최상위 형식이 틀리면 [FormatException].
  factory UpdateBundle.fromJson(Map<String, Object?> j) {
    if (j['format'] != null && j['format'] != format) {
      throw FormatException('업데이트 파일 형식이 아닙니다 (format: ${j['format']})');
    }
    final problems = <String>[];
    final date = jStringOrNull(j['date']);

    final obs = <Observation>[];
    final analysis = jMap(j['analysis']);
    analysis.forEach((rawEl, v) {
      final el = elementKey(rawEl);
      if (el == null) {
        problems.add('analysis: 알 수 없는 요소 "$rawEl"');
        return;
      }
      final m = jMap(v);
      for (final kind in Observation.kinds) {
        final raw = m[kind] ?? m[_kindPlural[kind]] ?? m[_kindKo[kind]];
        final items = raw is String ? [raw] : jList(raw);
        for (final t in items) {
          final text = jString(t).trim();
          if (text.isNotEmpty) {
            obs.add(Observation(
                date: date ?? '', element: el, kind: kind, text: text));
          }
        }
      }
    });

    final placements = <String, int>{};
    jMap(j['placements']).forEach((raw, v) {
      final k = substatKey(raw);
      final l = jIntOrNull(v);
      if (k == null || l == null || l < 1 || l > SgcyConfig.maxLevel) {
        problems.add('placements: "$raw": $v 무시');
      } else {
        placements[k] = l;
      }
    });

    final quests = <QuestDraft>[];
    final rawQuests = jList(j['quests']);
    for (var i = 0; i < rawQuests.length; i++) {
      final q = jMap(rawQuests[i]);
      final d = _quest(q, problems, 'quests[$i]');
      if (d != null) quests.add(d);
    }

    final notesRaw = j['profile_notes'];
    return UpdateBundle(
      date: date,
      summary: jString(j['summary']).trim(),
      observations: obs,
      placements: placements,
      quests: quests,
      profileNotes: notesRaw is List
          ? [
              for (final n in notesRaw)
                if (jString(n).trim().isNotEmpty) jString(n).trim()
            ]
          : null,
      problems: problems,
    );
  }

  static const Map<String, String> _kindPlural = {
    Observation.strength: 'strengths',
    Observation.weakness: 'weaknesses',
    Observation.improvement: 'improvements',
  };

  static const Map<String, String> _kindKo = {
    Observation.strength: '장점',
    Observation.weakness: '미흡점',
    Observation.improvement: '개선점',
  };

  static String? elementKey(Object? raw) {
    final s = jString(raw).trim();
    if (SgcyConfig.elementByKey.containsKey(s)) return s;
    final k = SgcyConfig.keyByLabel[s];
    return SgcyConfig.elementByKey.containsKey(k) ? k : null;
  }

  static String? substatKey(Object? raw) {
    final s = jString(raw).trim();
    if (SgcyConfig.substatByKey.containsKey(s)) return s;
    final k = SgcyConfig.keyByLabel[s];
    return SgcyConfig.substatByKey.containsKey(k) ? k : null;
  }

  static String? questKind(Object? raw) {
    final s = jString(raw).trim().toLowerCase();
    if (QuestKind.all.contains(s)) return s;
    for (final e in QuestKind.labels.entries) {
      if (e.value == s || '${e.value} 퀘스트' == s) return e.key;
    }
    return null;
  }

  static String? severityKey(Object? raw) {
    final s = jString(raw).trim().toLowerCase();
    if (Severity.all.contains(s)) return s;
    for (final e in Severity.labels.entries) {
      if (e.value == s) return e.key;
    }
    return null;
  }

  static Map<String, double> _substatMap(
      Object? raw, List<String> problems, String where) {
    final out = <String, double>{};
    jMap(raw).forEach((k, v) {
      final key = substatKey(k);
      final d = jDoubleOrNull(v);
      if (key == null || d == null) {
        problems.add('$where: "$k" 무시');
      } else {
        out[key] = (out[key] ?? 0) + d;
      }
    });
    return out;
  }

  static QuestDraft? _quest(
      Map<String, Object?> q, List<String> problems, String where) {
    final kind = questKind(q['kind']);
    final title = jString(q['title']).trim();
    if (kind == null || title.isEmpty) {
      problems.add('$where: kind/title 없음 → 건너뜀');
      return null;
    }
    final weights = _substatMap(q['weights'], problems, '$where.weights');
    final promote = q['promote'] == null ? null : substatKey(q['promote']);
    if (q['promote'] != null && promote == null) {
      problems.add('$where.promote: "${q['promote']}" 무시');
    }
    var element = elementKey(q['element']);
    element ??= promote != null
        ? SgcyConfig.substatByKey[promote]!.element
        : (weights.isNotEmpty
            ? SgcyConfig.substatByKey[weights.keys.first]!.element
            : null);
    if (element == null) {
      problems.add('$where: element 없음 → 건너뜀 ("$title")');
      return null;
    }
    final sev = severityKey(q['severity']);
    return QuestDraft(
      kind: kind,
      title: title,
      desc: jString(q['desc']).trim(),
      element: element,
      weights: weights,
      scale: jDouble(q['scale'], 1),
      statRewards:
          _substatMap(q['stat_rewards'], problems, '$where.stat_rewards'),
      promote: promote,
      grantSkill: SkillGrant.fromJson(q['grant_skill']),
      skillId: jIntOrNull(q['skill_id']),
      skillName: jStringOrNull(q['skill']),
      severity: kind == QuestKind.warning ? (sev ?? Severity.normal) : null,
      requiredDays: jIntOrNull(q['required_days']),
      windowDays: jIntOrNull(q['window_days']),
      deadline: jStringOrNull(q['deadline']),
      source: 'claude',
    );
  }
}
