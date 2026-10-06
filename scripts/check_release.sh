#!/bin/bash
# Names the channel a git ref builds for and checks the ref agrees with the
# code (RELEASING.md). Prints key=value lines, which CI appends to
# $GITHUB_OUTPUT; exits non-zero when something does not match.
#
#   ./scripts/check_release.sh refs/heads/release/1.0
#   ./scripts/check_release.sh refs/tags/v1.0.0-beta.1
#   ./scripts/check_release.sh            # the current branch or tag
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ref="${1:-}"
if [ -z "$ref" ]; then
  if tag=$(git describe --exact-match --tags HEAD 2>/dev/null); then
    ref="refs/tags/$tag"
  else
    ref="refs/heads/$(git rev-parse --abbrev-ref HEAD)"
  fi
fi

# A file as the ref has it: from git when the ref is another commit here
# (a release branch checked from main), from the working tree when it is
# what is checked out or does not exist yet (a tag about to be made).
show() {
  local commit
  commit=$(git rev-parse --verify -q "$ref^{commit}" 2>/dev/null || true)
  if [ -n "$commit" ] && [ "$commit" != "$(git rev-parse HEAD)" ]; then
    git show "$commit:$1"
  else
    cat "$1"
  fi
}

version=$(show project.yml | sed -nE 's/^ *MARKETING_VERSION: "([^"]+)"/\1/p')
build=$(show project.yml | sed -nE 's/^ *CURRENT_PROJECT_VERSION: "([^"]+)"/\1/p')
whats_new=$(show Packages/StarHashKit/Sources/StarHashKit/ReleaseHistory.swift | sed -nE 's/^ *version: "([^"]+)",$/\1/p' | head -1)
changelog=$(show CHANGELOG.md)

fail() { echo "::error::$1" >&2; exit 1; }

case "$ref" in
  refs/tags/*)
    tag="${ref#refs/tags/}"
    [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-(beta|rc)\.[0-9]+)?$ ]] \
      || fail "tag $tag is not vMAJOR.MINOR.PATCH, -beta.N or -rc.N"
    tag_version="${BASH_REMATCH[1]}"
    stage="${BASH_REMATCH[3]:-final}"
    [ "$version" = "$tag_version" ] \
      || fail "tag $tag is for $tag_version, but project.yml says MARKETING_VERSION $version"
    grep -qE "^## \[$tag_version\]" <<<"$changelog" \
      || fail "CHANGELOG.md has no section for $tag_version"
    case "$stage" in
      beta)
        channel=beta; configuration=Beta; scheme="StarHash Beta" ;;
      rc|final)
        # A release candidate is the App Store build, tried on TestFlight
        # first, so a new MAJOR.MINOR must already say what it brings. A
        # patch may add its own What's New, or not.
        if [[ "$tag_version" == *.0 ]] && [ "$whats_new" != "$tag_version" ]; then
          fail "What's New (ReleaseHistory.releases) starts at $whats_new, not $tag_version"
        fi
        channel=production; configuration=Release; scheme="StarHash" ;;
    esac
    if [ "$stage" = final ]; then
      grep -qE "^## \[$tag_version\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" <<<"$changelog" \
        || fail "CHANGELOG.md's $tag_version section has no release date"
    fi
    ;;
  refs/heads/release/*)
    line="${ref#refs/heads/release/}"
    [[ "$line" =~ ^[0-9]+\.[0-9]+$ ]] || fail "release branch $line is not release/MAJOR.MINOR"
    [[ "$version" == "$line".* ]] \
      || fail "release/$line builds $line.x, but project.yml says MARKETING_VERSION $version"
    channel=beta; configuration=Beta; scheme="StarHash Beta"
    ;;
  *)
    channel=dev; configuration=Debug; scheme="StarHash"
    ;;
esac

echo "channel=$channel"
echo "configuration=$configuration"
echo "scheme=$scheme"
echo "version=$version"
echo "build=$build"
