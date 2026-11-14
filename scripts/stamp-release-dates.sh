#!/usr/bin/env bash
# stamp-release-dates.sh — run once: writes "<!-- wn: released=YYYY-MM-DD -->" under each "## vX" heading of
# CHANGELOG.md from the date of that version's tag, so What's New can show when each release arrived. A version
# with no tag yet (one that is not released) is left alone: scripts/cut-release.sh dates it when it is cut.
# Idempotent: running it again changes nothing. It adds no tags to old bullets; those releases are grouped by
# their topic lines on screen.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
count=0
while IFS= read -r version; do
  tag="v$version"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "skipped v$version (no tag)"; continue; }
  day="$(git log -1 --format=%cs "$tag")"
  scripts/changelog-check.sh --stamp "$version" "$day" >/dev/null
  count=$((count + 1))
done < <(grep -E '^## v[0-9]+\.[0-9]+\.[0-9]+( |$)' CHANGELOG.md | sed -E 's/^## v([0-9.]+).*/\1/')
echo "stamped $count release(s)"
