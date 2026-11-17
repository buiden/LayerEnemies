-- R3 batch-hop regressions at the real Wire/client boundary, no donor code.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function receive(text,sender)
    H.deliver("CHAT_MSG_ADDON","FLHNET2",text,"WHISPER",sender or "Host a")
end
local function member()
    local N=H.load(); H.establish(N); H.clock(math.ceil(H.clock()))
    C_AddOns.GetAddOnMetadata=function() return "1.2.0" end
    N.Net.SHIP.flh=true; N.Net.SHIP.hh=true
    return N
end
local function hosts(N)
    for i=1,10 do receive("HI|100|"..(10+i).."|1|0.1.3|1234","Host "..H.abc(i)) end
    eq(#N.Main.candidates(),10,"host fixtures admitted")
end
local function lines(cmd)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix=="FLHNET2" and s.text:match("^(%u+)")==cmd then out[#out+1]=s end
    end
    return out
end
local function ordinary(N,n)
    for i=1,n do
        yes(N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER","Other "..H.abc(i),{net="hh",prio="own"}))
    end
end
local function offer(N,q)
    local m=N.FLH.decode(q.text)
    receive("LO|"..m.id.."|100|"..m.wantedKey.."|0|0",q.target)
end
local function ceilings()
    -- Replay every actual attempt, including client refusals. No mirroring of
    -- Wire internals: independently enforce capacity 8/refill 1 per 1.5 s,
    -- at most 8 at one timestamp and at most 40 in any rolling 60 seconds.
    local tokens,last,same,stamp=8,nil,0,nil
    local sent=H.sent()
    for i,s in ipairs(sent) do
        if last and s.at>last then tokens=math.min(8,tokens+(s.at-last)/1.5) end
        last=math.max(last or s.at,s.at)
        yes(tokens>=1-1e-8,"shared burst/refill ceiling at attempt "..i)
        tokens=tokens-1
        if stamp==s.at then same=same+1 else stamp,same=s.at,1 end
        yes(same<=8,"eight at once")
        local n=0
        for j=1,i do if s.at-sent[j].at<60 then n=n+1 end end
        yes(n<=40,"forty in every rolling minute")
    end
end

test("FLH batch: ordinary whisper then offer at half a second accepts",function()
    local N=member(); hosts(N); ordinary(N,1)
    SlashCmdList.LAYERENEMIES("hop flh")
    eq(#lines("LQ"),6,"one shared token must remain for LR")
    local q=lines("LQ")[1]; H.advance(.5); offer(N,q)
    eq(#lines("LR"),1); eq(lines("LR")[1].target,q.target)
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),1)
    ceilings(); no(N.Main.error)
end)

test("FLH batch: unsent queries pace without spending the reserved token",function()
    local N=member(); hosts(N); ordinary(N,2)
    SlashCmdList.LAYERENEMIES("hop flh"); eq(#lines("LQ"),5)
    H.advance(1); eq(#lines("LQ"),5)
    H.advance(1); eq(#lines("LQ"),6)
    H.advance(1.01); eq(#lines("LQ"),7) -- just beyond the fractional refill boundary
    offer(N,lines("LQ")[7]); eq(#lines("LR"),1)
    H.deliver("PARTY_INVITE_REQUEST",lines("LQ")[7].target); eq(H.accepts(),1)
    ceilings(); no(N.Main.error)
end)

test("FLH batch: ordinary and owed traffic cannot steal the reserved LR",function()
    local N=member(); hosts(N); ordinary(N,1)
    SlashCmdList.LAYERENEMIES("hop flh")
    no(N.Wire.send("LayerSwap","same","WHISPER","Normal Peer",{prio="own"}))
    receive("WP|42|1234|0.1.3|100|8|1","Stranger Alder")
    eq(#lines("WR"),0); eq(#lines("LQ"),6)
    offer(N,lines("LQ")[1]); eq(#lines("LR"),1)
    ceilings()
end)

test("FLH batch: reserve expires at the original window without a tick",function()
    local N=member(); hosts(N); local at=H.clock()
    SlashCmdList.LAYERENEMIES("hop flh"); eq(#lines("LQ"),7)
    H.clock(at+90)
    local sent=0
    for i=1,5 do if N.Wire.send("HeadHunter","1AH:own","WHISPER","Normal "..H.abc(i),{net="hh",prio="own"}) then sent=sent+1 end end
    for i=1,5 do if N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Later "..H.abc(i),{prio="click"}) then sent=sent+1 end end
    eq(sent,8,"expiry releases the reserve even before the guest tick")
    offer(N,lines("LQ")[1]); eq(#lines("LR"),0)
    ceilings()
end)
