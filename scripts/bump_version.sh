#!/bin/bash
# Sets the version and build number in project.yml (RELEASING.md).
#
#   ./scripts/bump_version.sh 1.1.0   # a new version, its build number back to 1
#   ./scripts/bump_version.sh build   # the same version, the build number up by one
#
# Run xcodegen generate (or ./scripts/build.sh) afterwards so Xcode sees it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC="$ROOT/project.yml"

current_version=$(sed -nE 's/^ *MARKETING_VERSION: "([^"]+)"/\1/p' "$SPEC")
current_build=$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: "([^"]+)"/\1/p' "$SPEC")
[ -n "$current_version" ] && [ -n "$current_build" ] || { echo "project.yml has no MARKETING_VERSION or CURRENT_PROJECT_VERSION" >&2; exit 1; }

case "${1:-}" in
  "")
    echo "usage: $0 <MAJOR.MINOR.PATCH> | build" >&2
    exit 2
    ;;
  build)
    version="$current_version"
    build=$((current_build + 1))
    ;;
  *)
    version="$1"
    # The App Store takes three numbers and nothing after them: a beta or
    # release candidate is told apart by its tag and build, not its version.
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $version (MAJOR.MINOR.PATCH, no suffix)" >&2; exit 2; }
    [ "$version" != "$current_version" ] || { echo "already $version; use '$0 build' to raise the build number" >&2; exit 2; }
    build=1
    ;;
esac

perl -pi -e "s/^( *MARKETING_VERSION: )\"[^\"]+\"/\${1}\"$version\"/; s/^( *CURRENT_PROJECT_VERSION: )\"[^\"]+\"/\${1}\"$build\"/" "$SPEC"
echo "$current_version ($current_build) -> $version ($build)"
