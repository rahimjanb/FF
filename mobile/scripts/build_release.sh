#!/usr/bin/env bash
# Builds the store binaries with the production API address:
#   Google Play: build/app/outputs/bundle/release/app-release.aab
#   App Store:   build/ios/ipa/*.ipa (upload with the Transporter app or Xcode → Organizer)
#
# Usage: scripts/build_release.sh https://api.example.uz [all|android|ios]
# Every upload to a store needs a new build number: BUILD_NUMBER=2 scripts/build_release.sh …
# (the version shown to users is `version:` in pubspec.yaml).
set -euo pipefail
cd "$(dirname "$0")/.."

API_URL=${1:-}
TARGET=${2:-all}
if [[ ! $API_URL =~ ^https://[^/]+$ && ! $API_URL =~ ^https://[^/]+/$ ]]; then
  echo "Usage: $0 https://api.<domain> [all|android|ios]" >&2
  echo "Only an HTTPS address without a path: release builds refuse plain HTTP." >&2
  exit 1
fi
API_URL=${API_URL%/}
case $TARGET in all|android|ios) ;; *) echo "Target must be all, android or ios." >&2; exit 1 ;; esac

# Store reviewers sign in and open the legal pages, so the server must be up before submitting.
for path in /health /legal/privacy /legal/delete-account; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API_URL$path" || true)
  if [[ $code != 200 ]]; then
    echo "Warning: $API_URL$path answered ${code:-nothing}. Fix it before submitting to the stores." >&2
  fi
done

ARGS=(--release "--dart-define=API_URL=$API_URL")
[[ -n ${BUILD_NUMBER:-} ]] && ARGS+=("--build-number=$BUILD_NUMBER")

flutter pub get

if [[ $TARGET != ios ]]; then
  if [[ ! -f android/key.properties ]]; then
    echo "android/key.properties is missing: run scripts/create_upload_key.sh first (Google Play rejects debug-signed bundles)." >&2
    exit 1
  fi
  flutter build appbundle "${ARGS[@]}"
  echo "Google Play: $(pwd)/build/app/outputs/bundle/release/app-release.aab"
fi

if [[ $TARGET != android ]]; then
  # Needs Xcode signed in to the Apple Developer account (Xcode → Settings → Accounts).
  flutter build ipa "${ARGS[@]}"
  echo "App Store: $(ls "$(pwd)"/build/ios/ipa/*.ipa)"
fi
