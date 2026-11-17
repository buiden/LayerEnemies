# Window text layout correction (1.1.0)

## Scope and causes

Base: `d9f0a71` (`main`, version 1.1.0), Forever interface 16001, Lua 5.1.
Implement the requested spacing corrections directly in the existing approved B
appearance; no redesign, release/version bump, installation or remote writes.
Only `LayerEnemies/UI.lua` changes in the shipped addon. `Wire.lua`,
`test/verify.py`, message content/dispatch, action targets and saved data are unchanged.

Source locations below refer to that base revision:

- `UI.lua:299,347`: status begins at y=50 with width 264; hosting begins at
  y=64 independently, without a bounded width. A second status line collides
  with hosting. Tabs at y=76 and body at y=114 also ignore text height.
- `UI.lua:26,359-360`: the 86-wide HeadHunter button gives its wrapping label
  only 78 units. The four-button first row leaves no room for its on/off labels.
- `UI.lua:162-176,314,321`: the tab note, Find input and first row use fixed
  offsets. Reported's two-line note meets the first card; Friendly's unknown-
  layer hint shares the toolbar's space; a wrapped Find hint meets its input.
- `UI.lua:47-50,165-174,220,242`: titles can wrap over subtitles, while details
  and OpenMap positions have estimated fixed heights/offsets. Several retained
  evidence lines or long zone/reporter names can exceed those boxes.
- `UI.lua:348-362`: hint/settings have fixed offsets; the bottom-anchored footer
  can grow upward into the second settings row.

## Changes

- Measure status and bounded hosting text, anchor hosting below status, and move
  tabs/body/window height with their complete contents. Hidden hosting consumes
  no height; shorter content shrinks again.
- Disable wrapping on button labels. Widen Guild only and War Effort to 100 and
  HeadHunter to 112; put HeadHunter beside Call on the existing second row.
- Measure tab notes and place controls/cards below them. Give the unknown-layer
  Friendly hint its own full-width space above the toolbar.
- Measure each row's actual details/place strings with one reusable hidden
  FontString before pagination. Retain compact minimum heights, grow cards/list
  enough for a complete row, and keep action controls below details. Titles,
  levels and ages stay single-line; excessively long titles/action labels use
  native horizontal truncation rather than painting over a second line.
- Flow the hint, two settings rows and footer downward, including wrapped footer
  height in the window. Preserve colors, fonts, width and control actions.

## Tests and evidence

`test/harness.lua` now records parents/FontStrings, word-wrap settings and
approximate width-aware text metrics (including explicit newlines). This is a
geometry test double, not a FRIZQT font renderer.

`test/ui_layout.lua` adds six regression tests:

1. Known/unknown layer, short/long zone (three or more lines), active/inactive/
   off hosting on all four tabs, with header/body/settings containment.
2. Every option's on/off/n/a text, single-line policy, horizontal fit and
   nonintersecting button rectangles.
3. Reported, Find and Friendly notes before controls/rows, including larger
   test font metrics.
4. Footer/hint wrapping, containment and shrink back to normal metrics.
5. Find current + own + guild first-hand + reported + OpenMap text, scrolling
   to the final name, then recycling the tall row into a compact row.
6. Long local, Reported and Friendly row details, title and action separation.

Each defect family was run red before its production change. The final test
file plus updated harness were also copied into a detached worktree of the
unchanged base: `RESULT: 0 tests passed, 6 failed, 274 assertions`.
The candidate focused run returned:
`RESULT: 6 tests passed, 0 failed, 993 assertions`.

The first full gate found two old hardcoded `frame.height == 514` expectations
in `test/round1.lua:227` and `test/round2.lua:163`. They now capture the normal
local-tab height before opening Find and require returning to exactly that
height afterward. Their body-height, data, actions and containment assertions
are retained; a wrapped header/footer legitimately changes the normal height.

Final foreground command: `python3 test/verify.py` (exit 0).
`RESULT: 1125 tests passed, 0 failed, 119421 assertions`.
Lua syntax, static/send-policy checks, TOC parity, assets, archive integrity
and packaged-source parity passed. Generated results are committed separately.

## API and visual limits

Read-only Forever source lookup resolved to
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, version `1.60.1.70938`.
`SimpleFontStringAPIDocumentation.lua:325-350,720-727` declares
`GetStringHeight`, `GetStringWidth` and `SetWordWrap(bool)`.
Source declarations do not prove native glyph metrics or runtime appearance.

Inspected both provided screenshots and crops of their addon windows.
UIForever startup at `https://uiforever.com/app?flavor=forever` reported
Forever `1.60.1.70450`, 2560x1440, UI scale 0.64. Candidate visual checks were
not completed: the browser session became stale/about:blank; screenshot
capture timed out and a retry's file import hit a browser-harness broken pipe.
No simulator visual pass is claimed.

Real client: not run (alpha, owner's decision). Native FRIZQT wrapping,
actual UI-scale pixel rounding and exceptionally tall-card screen fit remain
unverified. No native test or screenshot is requested from the owner.
