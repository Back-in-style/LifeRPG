#!/usr/bin/env bash
# Codespace 최초 생성 시 1회 실행: Flutter SDK + Android SDK + Claude Code 설치
set -euo pipefail

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
CMDLINE_TOOLS_ZIP="commandlinetools-linux-11076708_latest.zip"

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config

# Flutter
if [ ! -d "$FLUTTER_HOME" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$PATH:$FLUTTER_HOME/bin"

# Android SDK (cmdline-tools)
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -fsSL -o /tmp/cmdtools.zip "https://dl.google.com/android/repository/$CMDLINE_TOOLS_ZIP"
  unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools
  mv /tmp/cmdtools/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf /tmp/cmdtools /tmp/cmdtools.zip
fi
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

flutter config --no-analytics --android-sdk "$ANDROID_HOME"
yes | flutter doctor --android-licenses >/dev/null || true
flutter precache --android

# 플랫폼 폴더가 아직 없으면 생성 (lib/, pubspec.yaml은 덮어쓰지 않음)
if [ ! -d android ]; then
  flutter create --project-name liferpg --org com.liferpg --platforms android .
  rm -f test/widget_test.dart
fi

# 한글 폰트
if [ ! -f assets/fonts/NanumGothic.ttf ] && [ -f legacy/apk/assets/private/NanumGothic.ttf ]; then
  mkdir -p assets/fonts
  cp legacy/apk/assets/private/NanumGothic.ttf assets/fonts/
fi

flutter pub get

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 레거시 pyc(Python 3.11) 디컴파일 도구 pycdc (A1 보조용, 실패해도 계속)
if ! command -v pycdc >/dev/null 2>&1; then
  ( git clone --depth 1 https://github.com/zrax/pycdc.git /tmp/pycdc \
    && cmake -S /tmp/pycdc -B /tmp/pycdc/build -G Ninja \
    && cmake --build /tmp/pycdc/build \
    && sudo cp /tmp/pycdc/build/pycdc /usr/local/bin/ ) || echo "pycdc 설치 실패 (무시)"
fi

flutter doctor
