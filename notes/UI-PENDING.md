# Approved UI B — implemented in 0.2.0

The owner selected B. LayerEnemies/UI.lua implements the native frame window,
not an embedded web view. It is hidden immediately after creation; /le toggles
it and /le list preserves the old text output. No minimap button or map pins.

- 360 x 468 UI units, movable, clamped to screen; validated position saved per
  character. Unknown layer remains '?'. Header includes zone and layer source.
- Seen by you, Reported and Friendly tabs retain separate counters/lists;
  Find adds a name field, Track, per-name Clear and eligible spotter asks.
- Own rows use class colours and level strips; reports remain Unknown and
  explicitly unconfirmed. Friendly rows include source/host/layer text.
- Invite buttons call the existing AskInvite function, never send anything.
  Per-name cooldown is rendered as 'Asked · Ns'. Clicking still revalidates
  global cooldown, group state, freshness and zone.
- At most six pooled rows are allocated (two Find cards visible at once).
  Mouse-wheel paging accesses all retained rows. No idle OnUpdate. Only while
  shown, a one-second timer paints ages/data; hiding invalidates its generation
  and the already-queued callback returns without rescheduling.
- Per-character watchlist is capped at five; no observations are persisted.

Preview differences from the approved three-tab concept:

1. Required fourth Find tab, narrower four-tab widths and text '(n)' counters,
   rather than round count badges; all active tabs use the gold underline.
2. Fixed 468-unit height, virtualized whole-row wheel paging, rather than
   content-height HTML cards. No scroll thumb. The bottom hint gives range.
3. Native Friz Quadrata font and flat texture fills, not browser Verdana,
   gradients or CSS shadows. Source/host tags are plain text, not badges.
4. Short amber report notice, no extended explanation occupying the list.
   Long text is constrained to the row; full status is available in text output.
5. No pretend final in-game screenshot. notes/preview-B.html now includes Find
   and explains these differences; the old preview-B.png remains an archived
   three-tab concept, not current verification evidence.

The original A preview is retained as history, not applied.

Still requires a live Forever client: font fit at actual UI scales, dragging,
visibility across reload/combat, native whisper targeting for surname names,
taint behaviour and actual two-client layer transfers. Strict offline mocks
cannot establish any of those. Map canvas integration remains out of scope;
Store.mapCandidates is still only a data selector and creates no pins.
