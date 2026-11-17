# Shared codecs (PR 0 codec slice)

Base: d9f0a71262d35cc59f1292757ed266ca08680eb9. Local branch only; push remote disabled.
Authority: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md section 4.2 and the Wanted/WarBoard audits.

## Scope and decisions

- New pure Lua codec under N.Codec; no Main, registry, queue, sends or library registration.
- Raw DEFLATE and the addon-channel escape codec are the network formats in both audits. Zlib wrappers and EncodeForPrint are not needed: WarBoard's printable format is manual campaign import/export, outside this slice.
- Planner steering: one new LayerEnemies/Codec.lua exposes exactly the section 4.2 functions plus aceCommSplit(bytes). Helpers remain file-local.
- Binary/text input and output ceiling 262144 bytes; DEFLATE stored output may include at most 25 bytes framing overhead at this ceiling. Serializer table nesting 8, entries/table 2048, total logical values 4096. Finite numbers only; one root table. Reject cycles and metatables; allow acyclic LibSerialize references and table keys. This deliberate bounded subset suits the network envelopes, not every arbitrary graph supported by LibSerialize.
- AceComm caller supplies monotonic time explicitly in state.now; join keeps the exact three-argument planned signature. No client clock calls. Key must include full sender, prefix and distribution; no realm stripping. 16 streams, 32768 bytes/stream, 256 fragments, 30 seconds total lifetime, physical frame <=255 bytes.
- Reference sources are read as format documentation only. No donor or library code is executed, copied, vendored, or loaded into tests. Python stdlib zlib plus independently written format reference code generate vectors.
- Existing test/verify.py and its send gate stay byte-for-byte unchanged. New tests run separately; TOC inclusion lets the existing harness load the new modules.

## Progress

- Source discovery complete: upstream LibSerialize v1.1.3 pinned to 3587abd411888ab19b9e4d53fe6091e53a491fbc; bundled AceSerializer r1284 and AceComm r1333 inspected as text.
- Implementation complete in one new `LayerEnemies/Codec.lua`, TOC-loaded immediately after Safe.lua. README documents every signature, return value, stricter-than-upstream behavior and ceiling. THIRD_PARTY.md credits format facts only.

## Verification evidence

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
