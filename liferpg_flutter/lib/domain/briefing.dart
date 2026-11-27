import 'dart:convert';

import 'format.dart';
import 'models/game_state.dart';
import 'models/observation.dart';
import 'models/quest.dart';
import 'rules/progression.dart';
import 'sgcy_config.dart';

/// 현재 상태 브리핑 (Markdown). 사람이 읽고, 대화 에이전트에게도 그대로 붙여 넣는다.
String buildBriefing(GameState s, {int recentObservations = 20}) {
  final b = StringBuffer();
  final today = s.today;
  b.writeln('# 심기체연 브리핑 — $today');
  b.writeln();
  if (s.lastUpdateDate != null) {
    b.writeln('마지막 Claude 업데이트: ${s.lastUpdateDate}'
        '${s.lastSummary.isEmpty ? '' : ' — ${s.lastSummary}'}');
    b.writeln();
  }

  b.writeln('## 주요 요소');
  b.writeln();
  b.writeln('| 요소 | 레벨 | 보상 기준 | 일일 보상 |');
  b.writeln('| --- | --- | --- | --- |');
  for (final e in SgcyConfig.elements) {
    final lv = s.elementLevel(e.key);
    final rl = s.elementRewardLevel(e.key);
    b.writeln('| ${e.label}(${e.meaning}) | ${lv.toStringAsFixed(2)} | '
        '$rl ${SgcyConfig.levelName(rl)} | ${formatStat(SgcyConfig.dailyReward(rl))} |');
  }
  b.writeln();

  b.writeln('## 세부스탯');
  b.writeln();
  b.writeln('| 요소 | 세부스탯 | 레벨 | 스탯 | 강등선 | 기준 | 비고 |');
  b.writeln('| --- | --- | --- | --- | --- | --- | --- |');
  for (final e in SgcyConfig.elements) {
    for (final k in e.substats) {
      final sub = s.substat(k);
      final notes = <String>[];
      if (sub.isProtected(today)) notes.add('보호 ~${sub.protectedUntil}');
      final idle = daysBetween(sub.lastActiveDate, today);
      if (idle != null && idle > SgcyConfig.decayGraceDays) {
        notes.add('자연 감소 중 ($idle일 무퀘스트)');
      } else if (idle != null && idle == SgcyConfig.decayGraceDays) {
        notes.add('내일부터 자연 감소');
      }
      final line = sub.demotionLine;
      if (line != null && !sub.isProtected(today) && sub.stat <= line * 1.1) {
        notes.add('강등 위험');
      }
      b.writeln('| ${e.label} | ${sub.label} | ${sub.level} ${sub.levelName} | '
          '${formatStat(sub.stat)} | ${line == null ? '-' : formatStat(line)} | '
          '${formatStat(sub.baseStat)} | ${notes.join(', ')} |');
    }
  }
  b.writeln();

  b.writeln('## 스킬');
  b.writeln();
  if (s.skills.isEmpty) {
    b.writeln('- 없음');
  } else {
    for (final k in s.skills) {
      final el = SgcyConfig.elementByKey[k.element]?.label;
      b.writeln('- #${k.id} **${k.name}**${el == null ? '' : ' [$el]'} — '
          '${k.desc.isEmpty ? '' : '${k.desc} · '}획득 ${k.acquiredDate}'
          '${k.failStreak > 0 ? ' · 경고 실패 ${k.failStreak}회' : ''}');
    }
  }
  b.writeln();

  b.writeln('## 진행 중인 퀘스트');
  b.writeln();
  final active = s.activeQuests;
  if (active.isEmpty) b.writeln('- 없음');
  for (final kind in QuestKind.all) {
    final qs = active.where((q) => q.kind == kind).toList();
    if (qs.isEmpty) continue;
    b.writeln('### ${QuestKind.labels[kind]}');
    for (final q in qs) {
      b.writeln('- ${questLine(q)}');
    }
    b.writeln();
  }

  final recentClosed = s.quests
      .where((q) =>
          !q.isActive &&
          q.closedDate != null &&
          (daysBetween(q.closedDate, today) ?? 99) <= 7)
      .toList();
  if (recentClosed.isNotEmpty) {
    b.writeln('## 최근 7일 종료된 퀘스트');
    b.writeln();
    for (final q in recentClosed) {
      b.writeln(
          '- ${q.closedDate} [${q.kindLabel}·${q.status.label}] ${q.title}');
    }
    b.writeln();
  }

  final obs = s.observations.length > recentObservations
      ? s.observations.sublist(s.observations.length - recentObservations)
      : s.observations;
  if (obs.isNotEmpty) {
    b.writeln('## 최근 관찰 기록');
    b.writeln();
    for (final o in obs) {
      final el = SgcyConfig.elementByKey[o.element]?.label ?? o.element;
      b.writeln(
          '- ${o.date} [$el·${Observation.labels[o.kind] ?? o.kind}] ${o.text}');
    }
    b.writeln();
  }

  if (s.profileNotes.isNotEmpty) {
    b.writeln('## 나에 대해');
    b.writeln();
    for (final n in s.profileNotes) {
      b.writeln('- $n');
    }
    b.writeln();
  }
  return b.toString().trimRight();
}

/// 퀘스트 한 줄 요약.
String questLine(Quest q) {
  final el = SgcyConfig.elementByKey[q.element]?.label ?? q.element;
  final parts = <String>['#${q.id} [$el·Lv${q.level}] ${q.title}'];
  if (q.rewards.isNotEmpty) {
    final sign = q.isWarning ? '−' : '+';
    parts.add(q.rewards.entries
        .map((e) =>
            '${SgcyConfig.substatByKey[e.key]?.label ?? e.key} $sign${formatStat(e.value)}')
        .join(', '));
  }
  if (q.promote != null) {
    parts.add('${SgcyConfig.substatByKey[q.promote]?.label} 승급');
  }
  if (q.grantSkill != null) parts.add('스킬 「${q.grantSkill!.name}」');
  if (q.severity != null) parts.add('심각도 ${Severity.labels[q.severity]}');
  if (q.hasCheckins) {
    parts.add(
        '체크인 ${q.checkins.length}/${q.requiredDays}일 (${q.windowDays}일 중)');
  }
  if (q.deadline != null) parts.add('기한 ${q.deadline}');
  return parts.join(' · ');
}

/// Claude에게 넘길 상태 파일 (들여쓰기 JSON).
String exportStateJson(GameState s) =>
    const JsonEncoder.withIndent('  ').convert(s.toJson());

/// 오늘 날짜 기준 남은 일수 (기한 없으면 null).
int? daysLeft(Quest q, String today) => daysBetween(today, q.deadline);
