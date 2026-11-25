# LifeRPG (Flutter) 개발 계획

> 기존 KivyMD 앱(`liferpg-1.0.0` debug APK)을 Flutter로 재작성하고, "현실성 기반 자기계발 RPG"로 확장한다.
> 이 문서는 모든 서브에이전트가 공유하는 기준 문서다. 범위/인터페이스 변경은 이 문서를 먼저 고친다.

---

## 0. 기존 앱 요약 (마이그레이션 기준)

- 저장: JSON 4종 — `profile.json`, `quests.json`, `logs.json`(events), `achievements.json`(unlocked)
- 스탯 7종: 힘·민첩·정신력·지구력·매력·집중·커뮤니케이션 (스탯별 값 + 상한 cap + 등급)
- 스킬 트리: Physical, Swim, Mobility, Recovery, Study … (트리별 total_xp → level, 합산 메인 레벨)
- 퀘스트: Daily / Main / Side / 돌파(Breakthrough), 난이도 Easy·Normal·Hard 배율, 마감일(D-day), 진행률, 보상(스탯 증가)
- Daily 그룹: Day A(등·하체·삼두), Day B(가슴·어깨·이두), 코어, 수영 데이, 학업, 루틴, 기타 (제목 키워드 자동 분류)
- 날짜 바뀌면 Daily 리셋, 스트릭(streak_days, last_active_date), 오늘 XP
- 업적 8종: 첫 발걸음, 각성, 모험가(10), 영웅(50), 한계 돌파, 랭크 달성, 숙련자(Lv5), 전문가(Lv10)
- 화면: 상태창 / 퀘스트 / 로그 (다크, DeepPurple + Amber)

## 1. 현실성 설계 원칙

| # | 원칙 | 구현 포인트 |
|---|------|-------------|
| R1 | 측정치 기반 보상 | 퀘스트 완료 시 실제 수치(거리·시간·세트×횟수×무게·뽀모도로 수) 입력 → XP 공식 |
| R2 | 체감 수익 감소 | 같은 날 같은 트리 반복 시 XP 감쇠, 트리별 일일 XP 상한 |
| R3 | 디트레이닝 | N일 미활동 스탯은 완만히 감소, 최고치의 일정 비율 아래로는 안 떨어짐 |
| R4 | 회복도 성장 | 수면·휴식일·가동성에 보상. 연속 고강도 시 피로도 ↑ → XP 효율 ↓ |
| R5 | 돌파 = PR 갱신 | 상한(cap)은 개인기록 갱신 시에만 상승 |
| R6 | 관대한 스트릭 | 주 1회 유예일, 끊겨도 완전 리셋 대신 감소 |
| R7 | 로그형 성장 곡선 | 초반 빠르고 후반 완만 |

모든 수치(계수·상한·감쇠율)는 `game_config` 한 곳에 모으고, 밸런스 시뮬레이션으로 검증 후 확정한다.

## 2. 기술 스택

- Flutter (stable) / Dart 3, Android 우선 (iOS는 이후)
- 상태관리: Riverpod
- 로컬 DB: Drift (SQLite)
- 라우팅: go_router
- 모델: freezed + json_serializable
- 차트: fl_chart
- 알림: flutter_local_notifications (Daily 리마인더)
- (후속) health 패키지 → Health Connect 연동 (걸음·수면·운동 자동 기록)
- 폰트: NanumGothic (기존 자산 재사용)

## 3. 아키텍처 / 폴더 구조

```
liferpg_flutter/
  lib/
    domain/            # 순수 Dart. Flutter import 금지. 게임 규칙 엔진
      models/          # Stat, SkillTree, Quest, Record, Achievement, Profile
      rules/           # xp_formula, diminishing, detraining, fatigue, breakthrough, streak, leveling
      game_config.dart # 모든 밸런스 상수
      game_engine.dart # completeQuest(), dailyRollover(), ... (입력→결과, 부수효과 없음)
    data/              # Drift DB, Repository, 레거시 JSON 임포터
    app/               # 라우터, 테마, DI(Riverpod providers)
    features/
      status/          # 상태창: 레벨, 스탯 카드, 스킬트리, 피로도
      quests/          # 목록·필터·추가·상세·완료(측정치 입력)
      records/         # 기록/PR 히스토리
      stats/           # 그래프 (주간 XP, 스탯 추이)
      logs/            # 이벤트 로그
      settings/        # 데이터 가져오기/내보내기, 알림
  test/                # domain 단위 테스트, data 테스트, widget 테스트
  tool/sim/            # 밸런스 시뮬레이터 (dart run)
  docs/                # PLAN.md, SPEC_v1.md, GAME_DESIGN.md, INTERFACES.md
```

핵심 규칙: **domain은 UI·DB와 무관**하게 테스트 가능해야 한다. features는 domain을 provider로만 호출한다.

## 4. 서브에이전트 역할

| ID | 역할 | 소유 파일(이외 수정 금지) | 산출물 |
|----|------|-------------------------|--------|
| A1 | 기존 앱 분석 | `docs/SPEC_v1.md` | 기존 동작·데이터 스키마·업적 조건 명세 |
| A2 | 게임 디자인/밸런스 | `docs/GAME_DESIGN.md`, `lib/domain/game_config.dart`, `tool/sim/` | 공식, 상수, 90일 시뮬(성실/게으름/몰아치기 유저) 리포트 |
| A3 | 도메인 엔진 | `lib/domain/` (config 제외), `test/domain/` | 규칙 엔진 + 단위 테스트 |
| A4 | 데이터 계층 | `lib/data/`, `test/data/` | Drift 스키마, Repository, 레거시 JSON 임포터 |
| A5 | UI | `lib/app/`, `lib/features/` | 화면 전부 |
| A6 | QA/빌드 | `test/widget/`, `android/`, CI 설정 | 통합 테스트, APK 빌드 |

공용 계약: `docs/INTERFACES.md` (도메인 모델·엔진 API·Repository API 시그니처). P1에서 확정 후 변경은 메인 세션이 승인.

## 5. 단계

| 단계 | 내용 | 담당 | 병렬 |
|------|------|------|------|
| P0 | 원본 소스/데이터 확보, Flutter 프로젝트 생성, SPEC_v1 | 메인, A1 | – |
| P1 | GAME_DESIGN + INTERFACES 확정, 시뮬레이터 | A2 (+메인) | – |
| P2 | 구현 | A3 · A4 · A5 | 3개 병렬 (파일 소유 분리) |
| P3 | 통합·마이그레이션 검증·밸런스 재조정 | A6, A2 | – |
| P4 | APK 빌드, 실기기 테스트 | A6 | – |

### MVP 범위 (P2)
1. 상태창 / 퀘스트 / 로그 — 기존 기능 동등
2. 측정치 입력 완료 플로우 (R1) + 체감 감소 (R2) + 돌파=PR (R5)
3. 레거시 JSON 가져오기
4. Daily 리마인더 알림

### MVP 이후
- R3 디트레이닝, R4 피로도/회복, R6 유예 스트릭
- 통계 그래프, Health Connect 연동, 백업(내보내기)

## 6. 레거시 데이터 이전

기존 앱은 debug 빌드라 `adb shell run-as <기존 패키지명>`으로 앱 내부 JSON을 꺼낼 수 있다.
→ 꺼낸 JSON을 새 앱 설정 화면의 "가져오기"로 불러온다 (A4 임포터, 스키마는 SPEC_v1 기준).

## 7. 사전 조건 / 미결 사항

- [ ] 원본 `main.py` 확보 여부 (`/home/marco/liferpg`?) — 있으면 A1 작업 대폭 축소
- [ ] 이 PC에 Flutter SDK / Android SDK 설치 여부
- [ ] 셸 실행 권한 (현재 세션 PowerShell EPERM) — 빌드·테스트에 필요
- [ ] 기존 앱 데이터 이전 필요 여부
