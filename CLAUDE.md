# CLAUDE.md — LifeRPG 저장소

사용자와는 **한국어**로 소통한다.

## 작업 시작·종료 절차 (매 세션 필수)
1. **시작**: `PROGRESS.md`를 읽고 현재 상태·진행 중 작업·다음 할 일을 파악한다. (SessionStart 훅이 내용을 자동으로 넣어 준다. 안 보이면 직접 읽는다)
2. **작업**: 여러 단계 작업은 시작할 때 `PROGRESS.md`「진행 중」에 적어 두고, 단계가 끝날 때마다 갱신한다.
3. **종료**: 파일을 바꿨다면 응답을 마치기 전에 `PROGRESS.md`를 갱신한다 (규칙은 그 파일 맨 아래). 안 하면 Stop 훅이 한 번 알려 준다.

## 저장소 구조
| 경로 | 내용 |
|---|---|
| `PROGRESS.md` | 진행판 — 현재 상태·다음 할 일·결정·세션 로그 |
| `liferpg_flutter/` | Flutter 앱 본체. 코드 작업 규칙·명령어는 `liferpg_flutter/CLAUDE.md` |
| `구상/` | 기준 문서: `심기체연 인생 게임 규칙서.md`, `구상.md`, `메인화면 대략적 개요.pdf` |
| `claude/` | claude.ai 프로젝트용 에이전트 키트 (지침·업데이트 형식·레벨 기준) |
| `assets/private/` | 레거시 Python 앱 바이너리 (`main.pyc`) |
| `.claude/` | 훅 설정 (`settings.json`, `hooks/`) |
