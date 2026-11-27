# data

Drift(SQLite) 저장소. 상태는 `GameState.toJson()`(sgcy-state v2) 1행, 로그는 append-only 이벤트 테이블.
v1(XP·스킬 트리) 상태 JSON은 읽지 않고 새 상태로 시작한다 (스키마 v2 마이그레이션에서 삭제).
