"""Hidden equality/parity guards: private copies, compiling assertion kills only."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua')
# Keep each guard independent; policy plants are dormant functions, never sends.
MUTANTS = [
    ('rules-rejected', 'GuildHost.lua', 'if clauses then body=clauses', 'if clauses then return nil'),
    ('unknown-rules-rejected', 'GuildHost.lua', 'local clauses = body:match("^(.-) r%d+$")', 'local clauses = body:match("^(.-) r2$")'),
    ('zone-only-rejected', 'GuildHost.lua', 'zone=text:match("^inv layer <LS (%d+)>$"); body=""', 'zone=nil; body=""'),
    ('adopt-on-numeric-build', 'Trust.lua', 'if not T.hidden(s) or not S.num(now)', 'if not S.num(now)'),
    ('adopt-wrong-zone', 'Trust.lua', ' or zone~=s.zone then return false end', ' then return false end'),
    ('adopt-invalid-id', 'Trust.lua', 'or not L.key(id) or not host', 'or not host'),
    ('adopt-token-left', 'Trust.lua', 'if source=="host" and id==previous then return false end', 'if false then return false end'),
    ('transfer-retains-old-alias', 'Trust.lua', 'if source=="peer" then alias=', 'if true then alias='),
    ('alias-discarded', 'Trust.lua', 'host=host,alias=alias', 'host=host,alias=nil'),
    ('token-expires', 'Trust.lua', 't.token and t.token.zone==s.zone and "known"', 't.token and now-t.token.at<300 and t.token.zone==s.zone and "known"'),
    ('drop-keeps-token', 'Trust.lua', 'local t=state(s); t.token=nil; t.blind=T.HIDDEN_ID_REASON', 'local t=state(s); t.blind=T.HIDDEN_ID_REASON'),
    ('grouped-token-save', 'Main.lua', 'LayerEnemiesDB.layerToken=A.grouped()==false and N.Trust.save', 'LayerEnemiesDB.layerToken=N.Trust.save'),
    ('grouped-token-restore', 'Main.lua', 'A.reloading(...) and A.grouped()==false', 'A.reloading(...)'),
    ('peer-prejoin-reply', 'Main.lua', 'if r and r.at>g.joinedAt then N.Trust.adopt', 'if r then N.Trust.adopt'),
    ('peer-at-join-reply', 'Main.lua', 'if r and r.at>g.joinedAt then N.Trust.adopt', 'if r and r.at>=g.joinedAt then N.Trust.adopt'),
    ('restore-on-login', 'Trust.lua', 'reload~=true or not S.tab(saved)', 'not S.tab(saved)'),
    ('restore-old', 'Trust.lua', 'wall-at>120', 'wall-at>121'),
    ('restore-rollback', 'Trust.lua', 'wall<at or wall-at>120', 'wall-at>120'),
    ('restore-other-character', 'Trust.lua', ' or S.str(saved.who,100)~=who', ''),
    ('numeric-token-leak', 'Trust.lua', 'if T.hidden(s) then return nil end\n    return T.own(s,now)', 'return T.own(s,now)'),
    ('inequality-as-other-layer', 'Record.lua', '    local server = N.Layer.key(own.store and N.Trust.numeric(own.store,own.now) or own.server)\n    if own.store and not N.Trust.numeric(own.store,own.now) then return "unknown" end', '    local server = N.Layer.key(own.store and N.Trust.own(own.store,own.now) or own.server)\n    if own.store and not N.Trust.own(own.store,own.now) then return "unknown" end'),
    ('who-group-handoff', 'Main.lua', 'if p.any then N.HopAny.close(M.hopAnyState,time) end', ''),
    ('heard-not-retained', 'Hop.lua', 'if r.kind=="heard" then p.reply={layer=r.layer,zone=r.zone,at=now} end', 'if false then p.reply={layer=r.layer,zone=r.zone,at=now} end'),
    ('reply-wrong-zone', 'Main.lua', 'or not zone or r.zone~=zone or zone~=M.store.zone', 'or not zone or zone~=M.store.zone'),
    ('reply-from-future', 'Main.lua', 'or r.at>time or time-r.at>N.Hop.REPLY', 'or time-r.at>N.Hop.REPLY'),
    ('reply-stale', 'Main.lua', 'or r.at<p.at or r.at>time or time-r.at>N.Hop.REPLY', 'or r.at>time'),
    ('adopt-before-join', 'Main.lua', 'or not g.joinedAt or g.wordUsed', 'or g.wordUsed'),
    ('adopt-without-host-leader', 'Main.lua', 'S.call(IsInGroup)~=true or not hostLeads(g) or not party', 'S.call(IsInGroup)~=true or not party'),
    ('adopt-on-stray-transfer', 'Main.lua', 'elseif not M.tokenTransfer(g) then N.Trust.drop(M.store,"transfer") end', 'elseif not M.tokenTransfer(g) then N.Trust.adopt(M.store,now(),"8000-8",A.location(),"peer","Host Cedar") end'),
    ('phase-nil-ignored', 'Adapters.lua', 'if reason==nil then return "same" end', 'if reason==nil then return nil end'),
    ('phase-refusal-ignored', 'Adapters.lua', 'if S.num(reason)==1 then return "refused" end', 'if S.num(reason)==1 then return nil end'),
    ('phase-secret-is-same', 'Adapters.lua', 'if S.secret(reason) then return end', 'if S.secret(reason) then return "same" end'),
    ('phase-other-zone', 'Main.lua', 'and A.unitZone(unit)==zone and mark', 'and mark'),
    ('host-alias-ignored', 'GuildHost.lua', ' or id==own.alias', ''),
    ('host-compares-server-only', 'GuildHost.lua', 'if id==own.id or id==own.alias', 'if N.Layer.key(id)==N.Layer.key(own.id) or id==own.alias'),
    ('host-tagless-refused', 'GuildHost.lua', '(req.blind and not own.hidden)', '(req.blind)'),
    ('eleventh-move', 'Trust.lua', 'T.MOVE_CAP,T.HOUR,T.REFUSAL_HOLD=10,3600,900', 'T.MOVE_CAP,T.HOUR,T.REFUSAL_HOLD=11,3600,900'),
    ('refusal-hold-short', 'Trust.lua', 'T.MOVE_CAP,T.HOUR,T.REFUSAL_HOLD=10,3600,900', 'T.MOVE_CAP,T.HOUR,T.REFUSAL_HOLD=10,3600,899'),
    ('hour-is-sliding', 'Trust.lua', 'p.start=nil\n        p.moves={}', 'p.start=wall\n        p.moves={}'),
    ('hour-back-to-back', 'Trust.lua', 'p.start=nil\n        p.moves={}', 'p.start=p.start+math.floor((wall-p.start)/T.HOUR)*T.HOUR\n        p.moves={}'),
    ('hour-reset-on-move', 'Trust.lua', 'p.start=p.start or wall; p.moves', 'p.start=wall; p.moves'),
    ('pace-identity', 'Trust.lua', 'if S.str(saved.who,100)~=p.who then return true end', 'if false then return true end'),
    ('r2-without-limit', 'Main.lua', 'local wait=N.Trust.paceWait(LayerEnemiesDB.hopLimit,A.wall())', 'local wait=0'),
    ('r2-in-combat', 'Main.lua', 'if A.inCombat() then return "no hop requests in combat." end', 'if false then return "no hop requests in combat." end'),
    ('r2-without-token-exclusion', 'Hop.lua', 'clause="not "..id.." r2"', 'clause="r2"'),
    ('hidden-round-stop', 'Main.lua', 'function M.hopAnyPreview()\n    if M.hopAnyState and M.hopAnyState.round then', 'function M.hopAnyPreview()\n    if not N.Trust.hidden(M.store) and M.hopAnyState and M.hopAnyState.round then'),
    ('hidden-round-status', 'UI.lua', 'local r=st and st.round', 'local r=not N.Trust.hidden(M.store) and st and st.round'),
    ('round-status-behind-hold', 'UI.lua', 'local st=M.hopAnyState\n        local r=st and st.round', 'if M.hopHold() then return M.hopHold() end\n        local st=M.hopAnyState\n        local r=st and st.round'),
    ('hidden-numeric-ui', 'Trust.lua', '"layer: shared with "..token.host', '"layer: shared with "..token.id'),
    ('guild-draft-restored', 'Main.lua', 'function M.openChat(line,kind)', 'function M.removedDraft() return M.openChat("/g inv layer <LS 100 r2>") end\nfunction M.openChat(line,kind)', 'policy'),
    ('guild-kind-restored', 'Main.lua', 'function M.openChat(line,kind)', 'function M.removedDraft() return M.openChat("hello","GUILD") end\nfunction M.openChat(line,kind)', 'policy'),
    ('chat-send-restored', 'Main.lua', 'function M.openChat(line,kind)', 'function M.removedSend() SendChatMessage("hello","GUILD") end\nfunction M.openChat(line,kind)', 'policy'),
    ('phase-outside-adapter', 'Main.lua', 'function M.openChat(line,kind)', 'function M.removedPhase() return UnitPhaseReason("party1") end\nfunction M.openChat(line,kind)', 'policy'),
]


def run(root, policy=False):
    command = (['python3', '-I', 'test/api_policy_test.py'] if policy else
               [str(LUA), 'test/harness.lua', '--only', 'Parity'])
    return subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=120)


def main():
    assert LUA, 'Set LAYERENEMIES_LUA to a Lua 5.1 binary'
    results = []
    with tempfile.TemporaryDirectory(prefix='le-hidden-', dir=os.environ.get('TMPDIR', ROOT)) as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copy2(ROOT / 'README.md', root / 'README.md')
        for policy in (False, True):
            base = run(root, policy)
            assert base.returncode == 0, base.stdout + base.stderr
        for row in MUTANTS:
            label, filename, old, new = row[:4]
            policy = len(row) == 5
            target = root / 'LayerEnemies' / filename
            original = target.read_text()
            assert original.count(old) == 1, (label, original.count(old))
            try:
                target.write_text(original.replace(old, new, 1))
                subprocess.run([str(LUA), '-e', 'assert(loadfile("LayerEnemies/' + filename + '"))'],
                               cwd=root, check=True, capture_output=True)
                result = run(root, policy)
                output = result.stdout + result.stderr
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', line)
                            for line in output.splitlines()
                            if (line.startswith('FAIL ') and 'expected' in line)
                            or (policy and line.startswith('AssertionError:'))]
                complete = 'Ran ' in output if policy else 'RESULT:' in output
                killed = result.returncode != 0 and bool(failures) and complete
                results.append({'rule': label, 'caught': killed, 'assertions': failures})
                print(('CAUGHT ' if killed else 'SURVIVED ') + label, flush=True)
            finally:
                target.write_text(original)
    data = (json.dumps(results, indent=2) + '\n').encode()
    report = ROOT / 'notes/hidden-parity-mutants.json'
    if not report.exists() or report.read_bytes() != data:
        report.write_bytes(data)
    count = sum(item['caught'] for item in results)
    print(f'RESULT: {count}/{len(results)} hidden parity mutants killed', flush=True)
    assert count == len(results), [item['rule'] for item in results if not item['caught']]


if __name__ == '__main__':
    main()
