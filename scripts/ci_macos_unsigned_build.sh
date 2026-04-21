#!/bin/bash
set -euo pipefail

CONFIGURATION="${XTOOL_CONFIGURATION:-release}"
ARTIFACTS_DIR="${CI_PROJECT_DIR:-$PWD}/artifacts"

mkdir -p "$ARTIFACTS_DIR"

if ! command -v xtool >/dev/null 2>&1; then
  echo "xtool not found; installing with Homebrew tap"
  brew install xtool-org/tap/xtool
fi

echo "xtool version:"
xtool --version

echo "Building unsigned app bundle with xtool (${CONFIGURATION})"
xtool dev build --configuration "$CONFIGURATION"

echo "Auditing App Intents metadata"
python3 scripts/appintents_audit.py xtool/iMoonshine.app | tee "${ARTIFACTS_DIR}/appintents-audit-${CONFIGURATION}.txt"

echo "Recording bundle manifest"
find xtool/iMoonshine.app -type f | sort | tee "${ARTIFACTS_DIR}/bundle-manifest-${CONFIGURATION}.txt"

echo "Packing unsigned app for download"
ditto -c -k --sequesterRsrc --keepParent xtool/iMoonshine.app "${ARTIFACTS_DIR}/iMoonshine-${CONFIGURATION}.app.zip"
