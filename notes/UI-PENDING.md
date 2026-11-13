# Intended UI - previews made, none approved, none implemented

The addon has no window, minimap affordance or map pin. The only frame is a
hidden nonvisual event dispatcher, and `/le` prints text. Two static previews
of the planned window await a choice:

- A, stacked sections: notes/preview-A.html, notes/preview-A.png. One
  scrolling window in a classic gold-bordered panel; all three sections
  visible at once; reported rows carry the reporter and button on a second
  line.
- B, tabs: notes/preview-B.html, notes/preview-B.png. Flat compact panel with
  a layer chip and three tabs with counters (Seen by you, Reported, Friendly);
  one section visible at a time. The picture shows the window on each tab.

Both use sample data and are about 360 px wide. Nothing from either preview
is applied to the addon. Build the window only after one is chosen.

Semantics either design must keep:

- Header: Your layer, the layer key or full ID with its source. Unknown stays
  unknown.
- Source statuses: installed/unavailable/no data/last heard. A received packet
  is not evidence of a confirmed sighting.
- Three separate sections: "Seen by you" (name, class colour, level, zone,
  age), "Reported, not confirmed" (Unknown, class, level, reporter, age since
  receipt, "Ask <reporter> for invite"), "Friendly players on other layers"
  (name, source tag Bulo/LayerSwap/War Effort, layer or "not known", host
  flag, age, "Ask for invite"). Reports are never mixed into the first list.
  Local unclassified sightings stay out of the enemy list.
- Hash candidates appear only as possible identity annotations.
- An ask button calls LE.AskInvite(name): it prefills the chat box and the
  user presses Enter. Buttons show the remaining cooldown while one applies.
  No button sends, invites, accepts or leaves.
- Movable, minimap-free window; hidden after construction. Persist only
  validated window position and approved options per character.
- Footer: Only players seen by you or reported by War Effort users.
- WorldMapFrame plain canvas pins, only if the map APIs exist and the exact
  displayed zone matches. Observer-position and reported-cluster markers need
  distinct semantics; no marker may pretend to give an exact enemy position.
  A reported-cluster marker must look unconfirmed.
- Never present zoneUID equality as proven layer membership.
- No idle OnUpdate. Reuse bounded pin objects and coalesce map refresh events.

Store.mapCandidates is only a tested data selector for eligible local
observer-position entries in a supplied zone. It does not inspect the real
map canvas and does not create, position, pool or hide actual pins. Real
canvas behaviour and map integration remain unimplemented.

The PNGs were captured from the HTML files with the local Chromium in
headless mode at 2x scale. Re-capture after any edit to the HTML.
