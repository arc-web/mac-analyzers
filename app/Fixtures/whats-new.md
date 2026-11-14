# What's New

Fixture for looking at What's New without the real changelog: a tagged release, an untagged one with topic
lines and an untagged one with none. Used by `snapshot-runner` (MA_CHANGELOG) and `agent-runner --probe-whats-new-fixture`.

## Next

Notes for the release author: this section is not release news.

What is being built now, ahead of the next release.

- Updates can show a fixture row of its own, so the group for what is not yet released has something in it. <!-- wn: open=update icon=hammer title="A Row Not Yet Released" -->

## v9.3.0 — Every feature on its own row, with a card for the newest release
<!-- wn: released=2026-11-14 -->

What's New now lists each feature on its own, grouped by the screen it belongs
to, so a person can see what arrived and open it.

- Memory Guard shows each stop as a row with the program, the time and the
  reason it was stopped, and opens the whole story behind it. <!-- wn: open=guard icon=shield.lefthalf.filled title="Guard Events as Rows" -->
- Monitor groups every app with its helpers under one row, with one Quit for
  the whole app instead of a long list of processes. <!-- wn: open=monitor icon=gauge.with.dots.needle.67percent title="One Quit per App" -->
- Trends adds a chart of how much memory the guard freed each day, beside the
  charts of stops and alerts. <!-- wn: open=trends icon=chart.xyaxis.line title="Memory Freed Each Day" -->
- Old Recordings finds where Zoom and screen recordings are saved and shows
  each place as its own tab. <!-- wn: open=recordings icon=film.stack -->
- Caches & Builds previews what it would remove before anything is touched. <!-- wn: open=caches icon=shippingbox title="Preview Before Cleaning" -->
- Undo lists what was moved to the Trash and puts a file back only when it is
  still the same one. <!-- wn: open=undo icon=arrow.uturn.backward title="Safer Undo" -->
- The sidebar can be tucked away and comes back when the pointer rests at the
  window's edge. <!-- wn: open=- icon=sidebar.left title="A Sidebar You Can Tuck Away" -->
- A card at the bottom of the sidebar says what's new until it has been seen,
  and goes away when you close it. <!-- wn: open=- icon=sparkles title="A Card for New Releases" -->

Minor fixes and improvements throughout.

## v9.2.0 — Memory screens and a calmer window

Memory Guard and Monitor were rebuilt, and the window was tidied.

**Memory**

- Monitor is one table of every app and tool with its memory and processor use
  and a details panel for the one you choose.
- Memory Guard reads as a day-by-day history of what it stopped or flagged,
  with a period menu to choose how far back to look.

**The window**

- The sidebar remembers whether it was open the last time you used the app.
- Empty and loading screens sit in the middle of the space they have.

Minor fixes and improvements throughout.

## v9.1.0 — The first version with a changelog

The very first release that came with notes, written before any of them were
grouped, tagged or dated.

- The app shows how much memory each program uses and can stop the ones you choose.
- A background guard watches memory pressure and says when it stops something.
- Reports are saved as documents you can read later.

## v9.0.0 — A release written as prose alone

This release has no bullets at all, only two paragraphs about what changed.

The second paragraph carries on, and the release still has to show in the list.
