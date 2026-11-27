# domain

순수 Dart 심기체연 규칙 엔진 (`package:flutter` import 금지).

- `sgcy_config.dart` — 요소·세부스탯·레벨·기준 스탯·모든 수치 상수
- `models/` — `GameState`(상태 파일 sgcy-state v2), `SubStat`, `Quest`/`QuestDraft`, `Skill`, `Observation`, `UpdateBundle`(sgcy-update)
- `rules/progression.dart` — 강등·승급·배치·자연 감소·보상 분배
- `game_engine.dart` — rollover / addQuest / completeQuest / toggleCheckin / giveUp / deleteQuest / placeLevel / removeSkill / applyUpdate (부수효과 없음, 시각은 인자)
- `briefing.dart` — 브리핑 Markdown, 상태 JSON 내보내기
