#!/bin/bash
# Generates the Xcode project and builds the app for the simulator. Prints
# only errors, warnings from our own sources, and the result.
#
#   ./scripts/build.sh
#   DERIVED=.build/mine ./scripts/build.sh   # a separate build folder, for parallel builds
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p .build

DEST="${DEST:-generic/platform=iOS Simulator}"
DERIVED="${DERIVED:-$ROOT/.build/main}"
mkdir -p "$DERIVED"
LOG="$DERIVED/build.log"

# One build at a time in this checkout: generating the project while another
# xcodebuild reads it breaks that build.
LOCK="$ROOT/.build/build.lock"
until mkdir "$LOCK" 2>/dev/null; do sleep 2; done
trap 'rmdir "$LOCK"' EXIT

# New source files only reach the project when it is generated again.
xcodegen generate --quiet || exit 1

xcodebuild -project StarHash.xcodeproj -scheme StarHash -configuration Debug \
  -destination "$DEST" -derivedDataPath "$DERIVED" \
  -jobs "${JOBS:-4}" build >"$LOG" 2>&1
STATUS=$?

grep -E "^$ROOT/.*(error|warning):" "$LOG" | sort -u
grep -E "^(error|fatal error):" "$LOG" | sort -u
if [ $STATUS -eq 0 ]; then echo "BUILD SUCCEEDED"; else echo "BUILD FAILED (full log: $LOG)"; fi
exit $STATUS
