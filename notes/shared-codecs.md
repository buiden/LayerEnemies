# Shared codecs (PR 0 codec slice)

Base: d9f0a71262d35cc59f1292757ed266ca08680eb9. Local branch only; push remote disabled.
Authority: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md section 4.2 and the Wanted/WarBoard audits.

## Scope and decisions

- New pure Lua codec under N.Codec; no Main, registry, queue, sends or library registration.
- Raw DEFLATE and the addon-channel escape codec are the network formats in both audits. Zlib wrappers and EncodeForPrint are not needed: WarBoard's printable format is manual campaign import/export, outside this slice.
- Planner steering: one new LayerEnemies/Codec.lua exposes exactly the section 4.2 functions plus aceCommSplit(bytes). Helpers remain file-local.
- Binary/text input and output ceiling 262144 bytes; DEFLATE stored output may include at most 25 bytes framing overhead at this ceiling. Serializer table nesting 8, entries/table 2048, total logical values 4097 including the root (4096 key/value slots). Finite numbers only; one root table. Reject cycles and metatables; allow acyclic LibSerialize references and table keys. This deliberate bounded subset suits the network envelopes, not every arbitrary graph supported by LibSerialize.
- AceComm caller supplies monotonic time explicitly in state.now; join keeps the exact three-argument planned signature. No client clock calls. Key must include full sender, prefix and distribution; no realm stripping. 16 streams, 32768 bytes/stream, 256 fragments, 15 seconds idle since the last accepted fragment and 120 seconds total lifetime from the first frame, physical frame <=255 bytes. Both timeout boundaries are inclusive (`>=`); expiry is pruned on later calls, not by a timer. A replacement first frame starts a new stream.
- Reference sources are read as format documentation only. No donor or library code is executed, copied, vendored, or loaded into tests. Python stdlib zlib plus independently written format reference code generate vectors.
- Existing test/verify.py and its send gate stay byte-for-byte unchanged. Codec tests run standalone and through `test/src_codec.lua` in the generic harness selector; TOC inclusion lets the existing harness load the module.

## Progress

- Source discovery complete: upstream LibSerialize v1.1.3 pinned to 3587abd411888ab19b9e4d53fe6091e53a491fbc; bundled AceSerializer r1284 and AceComm r1333 inspected as text.
- Implementation complete in one new `LayerEnemies/Codec.lua`, TOC-loaded immediately after Safe.lua. README documents every signature, return value, stricter-than-upstream behavior and ceiling. THIRD_PARTY.md credits format facts only.

## Owner-ruling follow-up on the integrated branch

Starting head: `67953cfe6ef436c2df20b536f6cca5f0114ec773` (`feat/source-registry`).
Ruling source: reviewer `parent-verdict-codec.txt`, S1/N1/N2, plus the owner's
explicit 15-second idle / 120-second total decision. Only codec code/tests and
these notes change; no send, registry, client-clock or timer changes.

- The 2048-entry contract is **kept**, not reduced to 2047. The old 4096-value
  budget counted the root, so 2048 key/value pairs needed one extra slot.
  `MAX_VALUES` is now **4097 including the root**; table depth and per-table
  entry limits are unchanged. Readers and writers accept 2048 and refuse 2049.
  Nested logical graphs and LibSerialize's encoded nil slots remain bounded.
- Each stream keeps its first-frame and last-accepted-fragment timestamps.
  Continuations refresh only that stream's idle clock, never its total lifetime.
  Unrelated streams, standalone/escaped messages and rejected frames do not
  keep a stalled assembly alive. Expiry releases admission slots on the next
  valid call. The existing 16-stream, 32768-byte and 256-frame ceilings remain.
- Tests were written and observed failing before each implementation slice.
  The final tests replayed against the detached starting head give **18 passed,
  12 failed**; candidate gives **30 passed, 0 failed, 34567 assertions**. See
  `notes/codec-ruling-red-base.txt`. The +29-second one-frame/second case and
  the +121-second refusal already passed the old implementation; they are
  retained controls, not claimed as new RED cases. New positives at +78 and
  +119.999 seconds prevent the old 30-second expiry from masquerading as a
  successful total-cap test.
- `python3 test/codec_check.py`: **PASS**; **30 tests, 34567 assertions**,
  **50000 fuzz inputs**, **257 inflate + 257 stored-writer comparisons**
  (one expected input-cap refusal), **526 Python/Lua serializer comparisons**,
  and **1000 bit-mutated streams** (850 accepted and equal to zlib).
- `python3 test/codec_mutants.py`: **56/56 killed**, syntax-valid and without
  counting timeouts as kills. Seven new mutants cover the root slot, total-cap
  retention, idle boundary, idle refresh, fixed first-frame origin, per-stream
  isolation and accepted-fragments-only refresh; the existing total-lifetime
  mutant now tests the exact 120-second boundary. All were killed on their first
  run; no surviving mutant required a later test repair. The existing small
  `maxOut` mutant also remains killed.
- Full foreground `python3 test/verify.py`: exit **0**;
  **RESULT: 1310 tests passed, 0 failed, 200327 assertions**. Syntax **75 files
  PASS**, API policy **10 tests PASS**, package/source parity **PASS**.
  `test/verify.py`, `test/harness.lua`, `Main.lua` and `Wire.lua` are byte-identical
  to the integrated starting head. Current `test/verify.py` SHA256:
  `1496ce7423f7d176d9c857b0fb480e1218948d09e5585391b3baa2be2baf153e`.
- Deterministic archive SHA256:
  `38cb270e8544a7cceb6b4741c298f4afa1f958a39b526e7ba1c4c14188c958ff`.
  Generated verification/mutant/RED notes are committed separately from the
  code, tests and this hand-written note. Self-review found no further blocker;
  parent independent review remains separate. Native checks not run (alpha,
  owner's decision). No push.

### Practical AceComm ceiling: pacing, not just allocated bytes

WarBoard's bundled ChatThrottleLib 31 sets `MAX_CPS=800`, `BURST=4000` and
`MSG_OVERHEAD=40` (`Libs/AceComm-3.0/ChatThrottleLib.lua:60-65`). Its addon send
path charges `#text + MSG_OVERHEAD` (line 591); startup/low-FPS throttling and
other traffic can lower throughput (lines 319-328). These are source facts,
not a live delivery measurement, and no library code was executed here.

A full AceComm multipart frame carries **254 payload bytes + 1 control byte**,
so it costs **295 throttle bytes** including that 40-byte overhead. Under ideal
exclusive use, steady payload throughput is `800 * 254 / 295`, about **689
bytes/s**. With all 4000 burst bytes initially available, the former 30-second
limit allowed only about **24.1 KB** of payload, not 32768 bytes. For the full
32768-byte message, `ceil(32768/254) = 130` frames cost
`32768 + 130 * (1 + 40) = 38098` throttle bytes. The ideal full-burst transmission
time is `(38098 - 4000) / 800`, about **42.6 seconds**, now inside the 120-second
cap. These are arithmetic envelopes, not latency guarantees.

With a busy sender delivering just one full 255-byte frame each second,
**20000 bytes take 79 frames, last at +78 seconds**, which the tests now join.
At that cadence only **30480 bytes** (120 full payload fragments at times
0 through 119) fit before the total deadline; a 32768-byte message still cannot
finish. Every gap must also be **less than 15 seconds**. Thus the practical
ceiling depends on available pacing and stalls, capped at 32768 assembled
bytes and 256 frames; it is not a promise that every admitted size arrives.
Consumers must choose and document their real maximum network payloads rather
than using the generic codec cap as a network-size guarantee.

### Inflate caller budget and measured worst cases

Call `inflate(input, maxOut)` with a **small explicit `maxOut`: the largest
legitimate decoded payload for that network**. The 262144-byte default/hard
ceiling bounds memory/work but does **not** promise a frame-safe decode.
The original 4000-byte benchmark below does not characterize large input.
The independent review measured:

| Decoded workload | Reviewer CPU time |
|---|---:|
| 240000 bytes of 7-bit random data | 397 ms |
| 262144 text-like bytes | 253 ms |
| 120000 text-like bytes from a 72778-byte stream | 95 ms |
| Expansion bomb refused with `maxOut=4096` | 0.3 ms |

These are reported offline measurements, not rerun timings or in-game results.
The 72778-byte compressed example cannot fit in one AceComm assembly. The API
comments carry the same warning and timings. No inflate algorithm or default
is changed by this ruling; the existing caller-limit mutant/tests remain.

## Original slice verification evidence (historical)

The following records the earlier standalone codec slice, not the integrated
follow-up above. Current regenerated full-suite evidence lives in
`notes/test-results.txt`, `notes/verification.json` and `notes/codec-mutants.json`.

- Per-feature RED->GREEN runs preceded addon escaping, inflate/stored writing, AceSerializer, LibSerialize and AceComm implementation. Final frozen-base negative control: detached `d9f0a71262d35cc59f1292757ed266ca08680eb9` with the candidate tests through `CODEC_ROOT`: **0 passed, 16 failed** (codec absent). This is the actual run, not an estimated baseline count.
- `python3 test/codec_check.py`: **PASS**. Unit gate: **16 tests, 9359 assertions**. Fuzz: **5000 random inputs for each of 10 public functions = 50000**, with no escaping errors, instruction-budget trips, output/depth/count overruns or unexpected globals/client API access. Secret/hostile-object boundaries also passed.
- Python zlib comparisons: **257 inflate cases** (256 decoded correctly, one valid stream refused at the documented compressed-input limit), **257 stored-writer outputs decoded by zlib**, **524 independent serializer Python->Lua->Python comparisons**. Differential mutation: **1000 bit-mutated compressed streams**, 850 accepted and matched zlib byte-for-byte; the rest refused.
- `python3 test/codec_mutants.py`: **49/49 killed**, all syntax-valid; no timeout/syntax failure counted as a kill. The first full run caught 48/49; the reserved-control mutant survived orphan-only tests. Added an active-stream + reserved-control + terminal-frame case with an unaffected second sender; it passed on production and killed that exact mutant. No production change was needed. `notes/codec-mutants.json` names each rule and its failure evidence.
- Known answers include 30 zlib level-0/3/5/7/9 vectors, an explicit fixed-Huffman vector, valid degenerate dynamic alphabets, independently bit-packed invalid trees/repeats/reserved symbols (checked against zlib), 64-KB and empty data, a 1-MB expansion bomb, all byte values, all LibSerialize type families, 6 Python serializer goldens, 10 Wanted section-11 payloads and WarBoard's SHRD/AceComm examples. Audit examples are constructed, not live captures.
- Reproduce fixtures: `python3 test/codec_vectors.py`; optionally re-import the audit data with `--audit-dir /opt/data/handoffs/2026-11-17-le-1.2.0`. Fixture regeneration was byte-identical with Python zlib **1.3.2**, SHA256 `95d826a93159ba6ec4da212f776cf89b5b821d7758feda7db32be195f954b75e`.
- Offline 4000-byte benchmarks (100 iterations/case): repeated text **0.465620 ms**, incompressible/stored **0.365540 ms**, dynamic Huffman **7.223120 ms**; all below the **16.667 ms** check. These are Linux/Lua 5.1 CPU timings, not in-game measurements.
- `python3 test/verify.py`: exit **0**; **RESULT: 1119 tests passed, 0 failed, 118447 assertions**. Syntax **59 files PASS**, API-policy **6 tests PASS**, package/source parity **PASS**. Existing send gate is unchanged: `test/verify.py` SHA256 is `a6c4e07bfbaeaed3492f411e0dff44382fe1208f2d13e2d3dacfe2ade80ec67a` on both base and candidate. No Main/Wire/registry/BNet changes.
- Existing deterministic package remains named `LayerEnemies-1.1.0.zip` because this is a foundation commit, not a version-bump/release task. It contains Codec.lua; SHA256 `89c29884139cc39278022d433db5f8252fc68b33aa3b6f82bd1786b4e7e6deda`. Generated normal verification notes are retained.
- Final review: **self-review**, no separate reviewer tool in this subagent lane. Checked decoder progress, bounded allocation/work, graph-reference expansion, signed/finite numeric handling, raw framing alignment, state lifetime/isolation and unchanged send policy; no remaining blocker found. Parent review remains independent. No native-client tests (alpha, owner's decision).

## Integration cautions / findings

- `aceCommJoin` needs a plain state with `st.now` supplied on every call; nil means either pending or refused. Reuse the state across calls and include full sender/prefix/distribution in the key. There are no client clock calls.
- Limits are deliberate admission policy, not universal library compatibility: graph cycles/metatables, non-finite values, duplicate keys and trailing root values are refused; compressed input can hit its ceiling before decoded output does. The cross-language test originally assumed every maximum-size zlib stream fit; measurement found 262224 compressed bytes for 262144 random bytes, correctly exceeding the 262169 cap. The test now explicitly verifies this refusal rather than silently raising the bound.
- A hand-written inexact-integer negative vector initially had an extra byte, which tested trailing-byte rejection instead. Corrected it to the exact 7-byte integer and paired it with the adjacent exactly representable value before mutation verification.
- Binary mutant diagnostics initially caused Python UTF-8 decoding to fail. The runner now captures them with replacement decoding; this runner error was not counted as a kill.
- All work and commits are local. The push URL remains `DISABLED`; no GitHub writes or donor execution occurred.
