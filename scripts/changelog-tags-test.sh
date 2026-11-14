#!/usr/bin/env bash
# changelog-tags-test.sh — proves the What's New tag rules of changelog-check.sh on entries made here:
# a fully tagged entry passes; a missing tag, a tag in the middle of a bullet, two tags, a bad screen or
# icon, a lowercase title and a stray comment each fail; --print removes every tag and nothing else; --stamp
# writes the date once; an entry from before tags is never re-judged. Run by scripts/check.sh changelog.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
gate="$root/scripts/changelog-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

entry() {   # entry <bullet-1-tag> <bullet-2-tag> [extra paragraph line]
  cat <<EOT
# What's New

## v2.99.0 — Features that show up as rows

Mac Analyzers lists each new feature on its own now, grouped by the screen it
belongs to, so a person can see what changed and open it.

- Memory Guard shows each stop as a row with the program, the time and the
  reason it was stopped. $1
- The window remembers where you left it and the sidebar keeps its width. $2
${3:-}
Minor fixes and improvements throughout.

## v2.50.0 — An entry from before tags existed

Nothing in this older entry carries a tag, and the check never asks for one,
because it was written before What's New had rows to show.

- Old entries keep reading as they always did, whatever the rules are now.
EOT
}
good1='<!-- wn: open=guard icon=shield.lefthalf.filled title="Guard Events as Rows" -->'
good2='<!-- wn: open=- icon=macwindow -->'

expect() {  # expect pass|fail "<name>" <changelog file> [version]
  local want="$1" name="$2" file="$3" version="${4:-2.99.0}" got=pass
  MA_CHANGELOG="$file" "$gate" "$version" >"$work/out" 2>&1 || got=fail
  if [[ "$got" == "$want" ]]; then echo "  ok   $name"; else echo "  FAIL $name: wanted $want, got $got"; sed 's/^/       /' "$work/out"; failures=$((failures + 1)); fi
}

entry "$good1" "$good2" > "$work/good.md";                                   expect pass "a fully tagged entry passes" "$work/good.md"
entry "" "$good2" > "$work/m.md";                                            expect fail "a bullet with no tag fails" "$work/m.md"
entry "$good1 $good2" "$good2" > "$work/two.md";                             expect fail "two tags on one bullet fail" "$work/two.md"
entry "${good1/open=guard/open=guard} " "$good2" > "$work/space.md";         expect pass "a space after the tag is allowed" "$work/space.md"
entry "open=guard icon=x" "$good2" > "$work/plain.md";                       expect fail "tag text without the comment marks fails" "$work/plain.md"
entry '<!-- wn: open=guard icon=Shield -->' "$good2" > "$work/icon.md";      expect fail "an icon that is not a symbol name fails" "$work/icon.md"
entry '<!-- wn: open=gu ard icon=shield -->' "$good2" > "$work/open.md";     expect fail "an open that is not one word fails" "$work/open.md"
entry '<!-- wn: icon=shield -->' "$good2" > "$work/noopen.md";               expect fail "a tag with no open fails" "$work/noopen.md"
entry '<!-- wn: open=guard icon=shield title="lowercase title" -->' "$good2" > "$work/title.md"; expect fail "a lowercase title fails" "$work/title.md"
entry '<!-- wn: open=guard icon=shield title="'"$(printf 'Very %.0s' {1..14})"'Long" -->' "$good2" > "$work/long.md"; expect fail "a title over 60 characters fails" "$work/long.md"
entry "$good1" "$good2" '<!-- wn: open=guard icon=shield -->' > "$work/stray.md"; expect fail "a tag outside a bullet fails" "$work/stray.md"
entry '<!-- wn: open=guard icon=shield title="Stop > Quit" -->' "$good2" > "$work/angle.md"; expect fail "a title with a > fails" "$work/angle.md"
  grep -q 'contains a ">"' "$work/out" && echo "  ok   and says why" || { echo "  FAIL the > message"; failures=$((failures + 1)); }
# a tag in the middle of a bullet: the comment, then more words on the last line
sed 's/Guard Events as Rows" -->/Guard Events as Rows" --> and more words/' "$work/good.md" > "$work/mid.md"; expect fail "a tag that is not at the end fails" "$work/mid.md"
# prose rules still judge the prose: a code name is refused, a screen name inside a tag is not
sed 's/The window remembers/The window remembers a setting_name/' "$work/good.md" > "$work/code.md"; expect fail "code names in the prose still fail" "$work/code.md"
# an older entry is never re-judged
if MA_CHANGELOG="$work/good.md" "$gate" 2.50.0 >/dev/null 2>&1; then echo "  ok   an entry from before tags needs none"
else echo "  FAIL an entry from before tags needs none"; failures=$((failures + 1)); fi

# --print: no tag, and otherwise the same prose
MA_CHANGELOG="$work/good.md" "$gate" --print 2.99.0 > "$work/printed"
entry "" "" | sed -e 's/ $//' > "$work/untagged.md"
MA_CHANGELOG="$work/untagged.md" "$gate" --print 2.99.0 > "$work/plainprint" 2>/dev/null || true
if ! grep -q 'wn:' "$work/printed" && cmp -s "$work/printed" "$work/plainprint"; then echo "  ok   --print removes every tag and nothing else"
else echo "  FAIL --print: tags left, or the prose changed"; diff "$work/printed" "$work/plainprint" | head -5; failures=$((failures + 1)); fi

# --stamp: written once under the heading, the same again, and invisible to --print
cp "$work/good.md" "$work/stamp.md"
MA_CHANGELOG="$work/stamp.md" "$gate" --stamp 2.99.0 2026-11-14 >/dev/null
cp "$work/stamp.md" "$work/stamp-once.md"
MA_CHANGELOG="$work/stamp.md" "$gate" --stamp 2.99.0 2026-11-14 >/dev/null
MA_CHANGELOG="$work/stamp.md" "$gate" --print 2.99.0 > "$work/stamped-print"
if cmp -s "$work/stamp.md" "$work/stamp-once.md" && [[ "$(grep -c 'released=2026-11-14' "$work/stamp.md")" == 1 ]] \
   && [[ "$(sed -n '/^## v2.99.0/{n;p;}' "$work/stamp.md")" == '<!-- wn: released=2026-11-14 -->' ]] \
   && cmp -s "$work/stamped-print" "$work/printed"; then echo "  ok   --stamp writes the date once under the heading and --print does not show it"
else echo "  FAIL --stamp"; failures=$((failures + 1)); fi
if MA_CHANGELOG="$work/stamp.md" "$gate" 2.99.0 >/dev/null 2>&1; then echo "  ok   a stamped entry still passes"
else echo "  FAIL a stamped entry fails"; failures=$((failures + 1)); fi
cp "$work/stamp.md" "$work/restamp.md"
MA_CHANGELOG="$work/restamp.md" "$gate" --stamp 2.99.0 2026-12-01 >/dev/null
if [[ "$(grep -c 'released=' "$work/restamp.md")" == 1 ]] && grep -q 'released=2026-12-01' "$work/restamp.md"; then echo "  ok   a new date replaces the old one"
else echo "  FAIL restamp"; failures=$((failures + 1)); fi
# --tags
if [[ "$(MA_CHANGELOG="$work/good.md" "$gate" --tags 2.99.0 | head -1)" == $'guard\tshield.lefthalf.filled\tGuard Events as Rows' ]]; then echo "  ok   --tags prints screen, icon and summary"
else echo "  FAIL --tags"; failures=$((failures + 1)); fi

# the app's own reading (--on-mac asks the parser the app uses): a tag on a line of its own under its bullet still
# belongs to that bullet, and a bullet the app would read as untagged fails even where the text rules let it by.
# Runs only on a Mac with Swift (exit 2 = not run).
onmac() {  # onmac pass|fail "<name>" <changelog file>
  local want="$1" name="$2" file="$3" got=pass rc=0
  MA_CHANGELOG="$file" "$gate" --on-mac 2.99.0 >"$work/out" 2>&1 || rc=$?
  if (( rc == 2 )); then echo "  skip $name (no Mac with Swift)"; return; fi
  (( rc == 0 )) || got=fail
  if [[ "$got" == "$want" ]]; then echo "  ok   $name"; else echo "  FAIL $name: wanted $want, got $got"; sed 's/^/       /' "$work/out"; failures=$((failures + 1)); fi
}
entry "$good1" "$good2" > "$work/own-ok.md"
onmac pass "a fully tagged entry passes the app's reading" "$work/own-ok.md"
awk -v t="$good1" '{ if (index($0, t)) { sub(/ *<!-- wn:.*$/, ""); print; print "  " t } else print }' "$work/own-ok.md" > "$work/ownline.md"
expect pass "a tag on its own line under its bullet passes the text rules" "$work/ownline.md"
onmac pass "that tag still belongs to its bullet in the app" "$work/ownline.md"
entry "" "$good2" > "$work/untagged-app.md"
onmac fail "a bullet with no tag fails the app's reading" "$work/untagged-app.md"

if (( failures > 0 )); then echo "changelog-tags-test: $failures check(s) failed" >&2; exit 1; fi
echo "changelog-tags-test: every tag rule holds"
