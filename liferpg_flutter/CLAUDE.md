# CLAUDE.md — LifeRPG (Flutter)

사용자와는 **한국어**로 소통한다.

## 프로젝트
**심기체연 인생 게임** — 심·기·체·연 4요소, 세부스탯 13개를 Claude와의 매일 대화로 키우는 Flutter 앱.
- **기준 문서 (v2)**: `../구상/심기체연 인생 게임 규칙서.md`(규칙), `../구상/구상.md`(구상), `docs/PLAN_v2.md`(구현 계획·미정 항목 기본안)
- Claude 에이전트 키트: `../claude/` (프로젝트 지침, 업데이트 파일 형식 `sgcy-update`, 레벨 기준 초안)
- v1 문서(`docs/PLAN.md`, `GAME_DESIGN.md`, `INTERFACES.md`, `SPEC_v1.md`, `QA_P3.md`)는 이전 XP·스킬트리 체계 기록 — 참고용, 코드와 맞지 않음
- 레거시 바이너리: `../assets/private/main.pyc` (Python 3.11). 디컴파일 결과 `legacy/main_decompiled.py`(부분), 디스어셈블리 `legacy/main_disasm.txt`(pycdas)
- Flutter 3.50 / Dart 3.14: `package:flutter/material.dart`는 deprecated → `package:material_ui/material_ui.dart` 사용 (Cupertino는 `cupertino_ui`)

## 진행 상황 · 결정
**`../PROGRESS.md`** 에서 관리한다 (현재 상태·다음 할 일·결정 기록·세션 로그). 여기에는 적지 않는다.

## 작업 방식
- `lib/domain/`은 순수 Dart (`package:flutter` import 금지). 규칙 수치는 `lib/domain/sgcy_config.dart` 한 곳.
- 업데이트 파일 형식을 바꾸면 `../claude/UPDATE_FORMAT.md`도 같이 고친다 (`test/domain/update_format_doc_test.dart`가 문서 예시를 실제로 적용해 본다).
- 상태 파일(`GameState.toJson`)·브리핑 형식을 바꾸면 `../claude/STATE_FORMAT.md`도 같이 고친다 (`test/domain/state_format_doc_test.dart`가 예시·키 대응표·상태값을 검사).
- 코드 변경 후 `flutter analyze`와 `flutter test` 통과를 확인한다.

## 명령어
```bash
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs --build-filter="lib/data/db/app_database.g.dart"   # drift 코드 생성 (전체 빌드는 멈춤)
flutter build apk --debug                                   # 결과: build/app/outputs/flutter-apk/
```
Codespace에는 에뮬레이터가 없다. APK는 빌드 후 다운로드해서 실기기에 설치한다.

## 웹 미리보기 (이 환경에서 테스트)
- `tool/serve_web.sh [포트]` — 웹 릴리스 빌드 후 `build/web`을 **포트 8080**으로 서빙. 실행하면 접속 주소를 출력한다. 코드를 바꾸면 다시 실행하고 브라우저를 새로고침한다.
- Codespace 주소: `https://<CODESPACE_NAME>-8080.app.github.dev` (VS Code **포트** 탭에도 "LifeRPG 웹 미리보기"로 보임. `.devcontainer/devcontainer.json`의 `forwardPorts`로 자동 전달)
- Claude는 백그라운드로 실행해 둔다. 핫 리로드가 필요하면 대신 `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`
- 웹은 메모리 저장소·알림 없음(`open_repository_web.dart`, `reminder_service_web.dart`), 새로고침하면 데이터 초기화.
- 메인화면 궤도는 OS "애니메이션 줄이기"가 켜져 있으면 멈춘다. 위젯 테스트는 그 설정을 켜 두고 돈다(`test/widget/app_test.dart` setUp).
