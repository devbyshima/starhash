#!/bin/bash
# StarHashKit tests on the Mac (Swift Testing), no simulator needed.
set -uo pipefail
cd "$(dirname "$0")/../Packages/StarHashKit"
swift test --scratch-path "${SCRATCH:-.build}" 2>&1 | grep -E "(error|✘|passed|failed|Test run)" | tail -40
