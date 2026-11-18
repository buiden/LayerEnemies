# C2 follow-up: never address our own character

Reviewed base: `b39fbedf7bfa5901333160d9b8bfe51d15bab776`.
Implementation: `0094df7`. Local commits only; no push or donor execution.

- Added `OverlordPeer.key`: Invite's own-realm canonical target plus Find's Unicode fold. Directory, route and recipient comparisons reuse it.
- Refuse own-character WHISPER and Battle.net sends at admission and queued dispatch. The directory scan skips the refusal without spending either cooldown or blocking the next member.
- `src_overlord_self.lua` first ran on the untouched base: **0 passed, 4 failed, 168 assertions**. Alice Vale, Élan Scout, Ølaf Scout and Борис Скаут each received one self-greeting with case/own-realm variants.
- GREEN: each now receives **0**; Birch Scout still receives **1**. All three outgoing kinds and dispatch revalidation remain silent to self. Focused peer suite: **40 passed, 0 failed, 13531 assertions**.
- Full `python3 test/verify.py`: **RESULT: 1490 tests passed, 0 failed, 270362 assertions**; syntax 87 files, static/API/TOC and archive parity PASS. Archive SHA-256 `53091752d28b143fe8a60c9777e89f6968831afaaaabcecb64ee8d86a937ca21`.
- Peer mutants **57/57**, including admission, dispatch and canonical-self mutations; receiver mutants **54/54**. Behavioral kills only.
- Logs: `/opt/data/cache/scratch/le-c2-self-{red,green}.log`, `le-c2-final-verify.log`, `le-c2-{peer,receiver}-mutants.log`.
- Long commands ran foreground with subprocess timeout 1800 s and tool timeout 1800 s, one command per call.
- Native checks: not run (alpha, owner's decision).

This separate evidence commit is the C2 tag target. C3 scope now follows PLAN 6.5.1 and the owner's Battle.net-friends-only override; that does not change this C2 checkpoint.
