# LifeRPG (Flutter)

현실성 기반 자기계발 인생 RPG. 계획은 [docs/PLAN.md](docs/PLAN.md).

## 처음 세팅 (1회)

이 폴더에는 `lib/`, `test/`, `pubspec.yaml`만 있고 플랫폼 폴더(`android/` 등)는 아직 없다.
Flutter SDK 설치 후 이 폴더에서:

```powershell
flutter create --project-name liferpg --org com.liferpg --platforms android .
```

`flutter create .`는 기존 `lib/`, `pubspec.yaml`을 덮어쓰지 않는다. 대신 `test/widget_test.dart`를 만들 수 있는데, 이 파일은 지운다 (스모크 테스트는 `test/widget/`에 있음).

한글 폰트 복사 (기존 APK에서):

```powershell
New-Item -ItemType Directory -Force assets\fonts; Copy-Item ..\liferpg-1.0.0-arm64-v8a_armeabi-v7a-debug\assets\private\NanumGothic.ttf assets\fonts\
```

```powershell
flutter pub get
```

```powershell
flutter test
```

```powershell
flutter run
```

## 기존 앱 데이터 꺼내기 (선택)

기존 앱이 debug 빌드라 `run-as`로 접근 가능하다. 패키지명은 `adb shell pm list packages | findstr liferpg`로 확인.
꺼낸 파일은 `legacy_data/`에 두면 git에서 제외된다.
