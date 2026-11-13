# Intended UI — not approved, not implemented

No layout, styling, A/B preview, window, minimap affordance, or actual map pin
has been implemented. The only frame is a hidden nonvisual event dispatcher.
The current `/le` command prints text. This document records requirements,
not a selected visual design.

Before implementation, provide two distinct window/map layout previews for
approval. Both must preserve the following semantics:

- Header: Your layer: full Bulo ID or independently inferred local server ID,
  with explicit source. Unknown remains unknown.
- Source statuses: installed/unavailable/no data/last heard. A received packet
  is not evidence of a fresh sighting. War Effort freshness/privacy blockers
  must remain visible, not be hidden behind an empty list.
- Separate local opposite-faction observations, local unclassified sightings,
  and reported zoneUID matches. Never mix unverified reports into a confirmed
  same-layer enemy list.
- Name or Unknown, class colour, level, zone, source and age, newest first.
  Hash candidates appear only as possible identity annotations.
- Movable, minimap-free window; Hide immediately after construction. Persist
  only validated window position and approved options per character.
- Footer: Only players seen by you or reported by War Effort users.
- WorldMapFrame plain canvas pins, only if the map APIs exist and the exact
  displayed zone matches. Observer-position and reported-cluster markers need
  distinct semantics; no marker should pretend to give an exact enemy position.
- No War Effort report marker while freshness is unavailable. Never equate
  zoneUID equality with proven membership.
- No idle OnUpdate. Reuse bounded pin objects and coalesce map refresh events.

Store.mapCandidates is only a tested data selector for eligible local
observer-position entries in a supplied zone. It does not inspect the real
map canvas and does not create, position, pool or hide actual pins. Real
canvas behavior and map integration remain unimplemented.
