# CLAUDE.md — LifeRPG (Flutter)

사용자와는 **한국어**로 소통한다.

## 프로젝트
기존 KivyMD(Python) 인생RPG 앱을 **Flutter로 재작성**하고, **현실성 기반 자기계발 RPG**로 확장한다.
- 기준 문서: `docs/PLAN.md` (원칙 R1~R7, 스택, 폴더 구조, 에이전트 역할, 단계)
- 기존 앱 명세: `docs/SPEC_v1.md` (A1이 작성 예정, 아직 없음)
- 레거시 바이너리: `legacy/apk/assets/private/main.pyc` (Python 3.11). Codespace에서 `pycdc legacy/apk/assets/private/main.pyc > legacy/main_decompiled.py`로 디컴파일 시도 가능

## 작업 방식
- **서브에이전트 기반**. 역할 A1~A6과 파일 소유 범위는 `docs/PLAN.md` §4. 에이전트는 자기 소유 파일만 수정한다.
- P2 병렬 구현 전에 `docs/INTERFACES.md`(모델·엔진·Repository API)를 먼저 확정한다.
- `lib/domain/`은 순수 Dart (`package:flutter` import 금지). 밸런스 상수는 `lib/domain/game_config.dart` 한 곳.
- 코드 변경 후 `flutter analyze`와 `flutter test` 통과를 확인한다.

## 진행 상황
- [x] 계획 수립 (PLAN.md)
- [x] Flutter 뼈대: pubspec, 하단 탭 3개 라우터(go_router), 다크 테마(DeepPurple/Amber, NanumGothic), 화면 placeholder, 스모크 테스트
- [ ] A1: `docs/SPEC_v1.md` 작성 — **아직 안 함**. Codespace에서 pycdc로 main.pyc 디컴파일 후 작성 (스키마·상수·규칙·UI·미확인 항목). 원본 main.py가 있으면 그것을 우선 사용
- [ ] P0 마무리: Codespace에서 `flutter create`(setup.sh가 자동 수행) → `flutter analyze`/`flutter test` 통과 확인
- [ ] P1: A2 → `docs/GAME_DESIGN.md`, `game_config.dart`, `tool/sim/` / 메인 → `docs/INTERFACES.md`
- [ ] P2: A3(domain) · A4(data) · A5(UI) 병렬
- [ ] P3: 통합·마이그레이션 검증 / P4: APK 빌드

## 명령어
```bash
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # drift/freezed 코드 생성
flutter build apk --debug                                   # 결과: build/app/outputs/flutter-apk/
```
Codespace에는 에뮬레이터가 없다. APK는 빌드 후 다운로드해서 실기기에 설치한다.
