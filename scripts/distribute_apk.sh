#!/usr/bin/env bash
set -euo pipefail

# Script to build and distribute Chef&Cost APK to Firebase App Distribution
APP_ID="1:194514517992:android:e049ba4d67978ff89bae5d"
PROJECT_ID="chefycost"
RELEASE_NOTES="${1:-"New testing release"}"
TESTERS="${2:-"kbradevp@gmail.com"}"

echo "==> Building Flutter Release APK..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
ROOT_APK="ChefAndCost-release.apk"

if [[ -f "$APK_PATH" ]]; then
    cp "$APK_PATH" "$ROOT_APK"
    echo "==> Copied APK to $ROOT_APK"
else
    echo "Error: $APK_PATH not found" >&2
    exit 1
fi

echo "==> Uploading and distributing to Firebase App Distribution..."
CMD=(firebase appdistribution:distribute "$ROOT_APK" \
    --project "$PROJECT_ID" \
    --app "$APP_ID" \
    --groups "beta-testers" \
    --release-notes "$RELEASE_NOTES")

if [[ -n "$TESTERS" ]]; then
    CMD+=(--testers "$TESTERS")
fi

"${CMD[@]}"

echo "==> Distribution complete!"
