# CLAUDE.md — LifeRPG (Flutter)

사용자와는 **한국어**로 소통한다.

## 프로젝트
기존 KivyMD(Python) 인생RPG 앱을 **Flutter로 재작성**하고, **현실성 기반 자기계발 RPG**로 확장한다.
- 기준 문서: `docs/PLAN.md` (원칙 R1~R7, 스택, 폴더 구조, 에이전트 역할, 단계)
- 기존 앱 명세: `docs/SPEC_v1.md` (A1 작성 완료. PLAN.md §0과 다르면 SPEC이 우선)
- 레거시 바이너리: `../assets/private/main.pyc` (Python 3.11). 디컴파일 결과 `legacy/main_decompiled.py`(부분), 디스어셈블리 `legacy/main_disasm.txt`(pycdas)
- Flutter 3.50 / Dart 3.14: `package:flutter/material.dart`는 deprecated → `package:material_ui/material_ui.dart` 사용 (Cupertino는 `cupertino_ui`)

## 확정된 결정
- (2026-11-25) 새 앱은 PLAN대로 **스탯 7종·다중 스킬 트리**. 레거시 4스탯(힘·민첩·정신력·지구력)은 값 그대로 가져오고 매력·집중·커뮤니케이션은 기본값으로 시작
- (2026-11-25) GAME_DESIGN §13 결정: 측정형 퀘스트는 난이도 배율 미적용(flat만 적용) / 스트릭 XP 보너스 MVP 포함 / 레거시 ACTIVE 돌파는 레거시 규칙으로 완료 허용 / 나머지(트리 재배치, 레벨 max 변환, 영문 스탯 버림, 업적 개선)는 A2 기본안

## 작업 방식
- **서브에이전트 기반**. 역할 A1~A6과 파일 소유 범위는 `docs/PLAN.md` §4. 에이전트는 자기 소유 파일만 수정한다.
- P2 병렬 구현 전에 `docs/INTERFACES.md`(모델·엔진·Repository API)를 먼저 확정한다.
- `lib/domain/`은 순수 Dart (`package:flutter` import 금지). 밸런스 상수는 `lib/domain/game_config.dart` 한 곳.
- 코드 변경 후 `flutter analyze`와 `flutter test` 통과를 확인한다.

## 진행 상황
- [x] 계획 수립 (PLAN.md)
- [x] Flutter 뼈대: pubspec, 하단 탭 3개 라우터(go_router), 다크 테마(DeepPurple/Amber, NanumGothic), 화면 placeholder, 스모크 테스트
- [x] A1: `docs/SPEC_v1.md` 작성 (pycdc 디컴파일 + pycdas 디스어셈블리 기반). 실제 앱은 스탯 4종·트리 physical 1개·스트릭 미구현
- [x] P0 마무리: `liferpg_flutter/`에서 `flutter create`(android), NanumGothic 복사, material_ui 마이그레이션, `flutter analyze`/`flutter test` 통과
- [x] P1: A2 → `docs/GAME_DESIGN.md`, `game_config.dart`, `tool/sim/`(`dart run tool/sim/main.dart`) / 메인 → `docs/INTERFACES.md`
- [x] P2: A3(domain: 모델·규칙·엔진, sim 회귀 테스트) · A4(data: Drift 3테이블·InMemory·LegacyImporter) · A5(UI: 상태창·퀘스트·로그·설정·리마인더) — 테스트 110개 통과
- [~] P3: A6 QA 완료(`docs/QA_P3.md`), 버그 #1~#4·N1~N5는 A3/A4/A5가 수정. **남음**: A6 테스트 갱신 마무리(robustness_test.dart:153 const info 1건, skip 해제·기대값 수정 확인, QA_P3.md 갱신)
- [ ] P4: 최종 APK 재빌드 + 실기기 테스트 (debug APK 빌드는 동작 확인됨)

## 명령어
```bash
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs --build-filter="lib/data/db/app_database.g.dart"   # drift 코드 생성 (전체 빌드는 analyzer가 dot-shorthand를 못 읽어 멈춤)
flutter build apk --debug                                   # 결과: build/app/outputs/flutter-apk/
```
Codespace에는 에뮬레이터가 없다. APK는 빌드 후 다운로드해서 실기기에 설치한다.
