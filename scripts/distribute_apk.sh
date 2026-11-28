#!/usr/bin/env bash
set -euo pipefail

APP_ID="1:194514517992:android:e049ba4d67978ff89bae5d"
PROJECT_ID="chefycost"
RELEASE_NOTES="${1:-"New testing release"}"
TESTERS="${2:-"kbradevp@gmail.com"}"
SPLIT_PER_ABI="${SPLIT_PER_ABI:-false}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_VERSION="$(grep -E '^\s*version:' pubspec.yaml | head -n 1 | sed -E 's/^\s*version:\s*//' | tr -d '[:space:]')"
if [[ -z "$APP_VERSION" ]]; then
  echo "Error: Could not parse version from pubspec.yaml" >&2
  exit 1
fi

echo "==> Running flutter analyze..."
flutter analyze

echo "==> Running flutter test..."
flutter test

echo "==> Building obfuscated Flutter Release APK ($APP_VERSION)..."
SYMBOLS_DIR="build/app/outputs/apk-symbols"
rm -rf "$SYMBOLS_DIR"

BUILD_ARGS=(
  build apk --release
  --obfuscate
  "--split-debug-info=$SYMBOLS_DIR"
  "--dart-define=APP_VERSION=$APP_VERSION"
)
if [[ "$SPLIT_PER_ABI" == "true" ]]; then
  BUILD_ARGS+=(--split-per-abi)
fi

flutter "${BUILD_ARGS[@]}"

ARTIFACT_DIR="build/release-artifacts/$APP_VERSION"
mkdir -p "$ARTIFACT_DIR"

if [[ "$SPLIT_PER_ABI" == "true" ]]; then
  APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  cp build/app/outputs/flutter-apk/app-*-release.apk "$ARTIFACT_DIR/"
else
  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
  cp "$APK_PATH" "$ARTIFACT_DIR/ChefAndCost-$APP_VERSION-release.apk"
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "Error: $APK_PATH not found" >&2
  exit 1
fi

echo "==> Uploading and distributing to Firebase App Distribution..."
CMD=(firebase appdistribution:distribute "$APK_PATH"
    --project "$PROJECT_ID"
    --app "$APP_ID"
    --groups "beta-testers"
    --release-notes "$RELEASE_NOTES")

if [[ -n "$TESTERS" ]]; then
    CMD+=(--testers "$TESTERS")
fi

"${CMD[@]}"

echo "==> Distribution complete! Artifacts archived in $ARTIFACT_DIR"
