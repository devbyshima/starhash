#!/bin/bash
# Builds, installs and launches StarHash on a simulator, then saves a
# screenshot. Launch arguments pick the screen (see App/DebugLaunch.swift).
#
#   ./scripts/screenshot.sh <name> [launch args...]
#   ./scripts/screenshot.sh pay-empty -inMemory -skipOnboarding -tab pay
#   SIM="StarHash B" DERIVED=.build/b APPEARANCE=light ./scripts/screenshot.sh ...
#   NOBUILD=1 ...   # reuse the last build
#   WAIT=3 ...      # seconds to wait after launch (default 3)
#
# Screenshots land in screenshots/<appearance>/<name>.png (1206x2622 on an
# iPhone 17 Pro). Runs side by side each need their own SIM and DERIVED.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
NAME="$1"; shift
SIM="${SIM:-StarHash}"
APPEARANCE="${APPEARANCE:-dark}"
export DERIVED="${DERIVED:-$ROOT/.build/main}"
case "$DERIVED" in /*) ;; *) DERIVED="$ROOT/$DERIVED";; esac

if [ "${NOBUILD:-0}" != "1" ]; then
  ./scripts/build.sh >/tmp/starhash-build-$$.log 2>&1 || { cat /tmp/starhash-build-$$.log; exit 1; }
fi

# One simulator session at a time, however many runs are queued.
SHOTLOCK="$ROOT/.build/shot.lock"
mkdir -p "$ROOT/.build"
until mkdir "$SHOTLOCK" 2>/dev/null; do sleep 2; done
trap 'rmdir "$SHOTLOCK"' EXIT

UDID=$(xcrun simctl list devices available | grep -F "$SIM (" | head -1 | grep -oE '[0-9A-F-]{36}')
if [ -z "$UDID" ]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-27-[0-9]+' | head -1)
  UDID=$(xcrun simctl create "$SIM" "iPhone 17 Pro" "$RUNTIME")
fi
# (simctl bootstatus can hang while other simulators boot, so poll instead.)
if ! xcrun simctl list devices | grep -F "$UDID" | grep -q Booted; then
  xcrun simctl boot "$UDID" 2>/dev/null
  until xcrun simctl list devices | grep -F "$UDID" | grep -q Booted; do sleep 2; done
  sleep 20
fi
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 >/dev/null 2>&1

APP="$DERIVED/Build/Products/Debug-iphonesimulator/StarHash.app"
xcrun simctl terminate "$UDID" com.fulltimestudio.starhash 2>/dev/null
xcrun simctl install "$UDID" "$APP" || exit 1
xcrun simctl launch "$UDID" com.fulltimestudio.starhash "$@" >/dev/null || exit 1
sleep "${WAIT:-3}"
mkdir -p "screenshots/$APPEARANCE"
xcrun simctl io "$UDID" screenshot "screenshots/$APPEARANCE/$NAME.png" >/dev/null 2>&1
echo "screenshots/$APPEARANCE/$NAME.png"
