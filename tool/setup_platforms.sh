#!/usr/bin/env bash
# Creates the rest of the android/ folder with `flutter create`.
# The repo keeps only AndroidManifest.xml (internet permission, app name,
# link/phone queries); `flutter create` never overwrites existing files.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.payra --project-name payra_society .

# flutter_secure_storage needs minSdk 23.
GRADLE_KTS="android/app/build.gradle.kts"
if [ -f "$GRADLE_KTS" ]; then
  sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(23, flutter.minSdkVersion)/' "$GRADLE_KTS"
fi

rm -f test/widget_test.dart
echo "Platform folders are ready. Next: flutter pub get && flutter run"
