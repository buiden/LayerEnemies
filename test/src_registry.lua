local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function register(N,name,prefix,extra)
    yes(N.Sources,"source registry exists")
    local r=extra or {}; r.name=name or "probe"; r.prefixes=prefix and {prefix} or {}; r.counters=r.counters or {}
    yes(N.Sources.register(r)); return r
end

test("Sources: registry routes addon and Battle.net with unchanged arguments",function()
    local N=h.load(); local a,b={},{ }
    local r=register(N,"probe","ProbeSrc",{onAddon=function(...) a={...} end,onBNet=function(...) b={...} end})
    h.deliver("CHAT_MSG_ADDON","ProbeSrc","A|B","PARTY","Other Peer")
    eq(table.concat(a,","),"ProbeSrc,A|B,PARTY,Other Peer")
    h.deliver("BN_CHAT_MSG_ADDON","ProbeSrc","B|C","WHISPER",71)
    eq(b[1],"ProbeSrc"); eq(b[2],"B|C"); eq(b[3],71); eq(r.counters.heard,2)
    h.deliver("CHAT_MSG_ADDON","UnknownSrc","x","PARTY","Other Peer"); eq(r.counters.heard,2)
    no(N.Main.error)
end)

test("Sources: every legacy prefix is refused atomically and counted",function()
    local N=h.load(); yes(N.Sources)
    local before=N.Sources.stats.refused
    for _,p in ipairs({"WEFF1","HeadHunter","LayerSwap","LFSw","LEGW1","FLHNET2","OverlordF","OpenMapLoc",
        "[Spy]","ForeverSpy1","FSENT03","GBOUNTY","WALLOFSHAME","FTold1"}) do
        no(N.Sources.register{name="bad",prefixes={"AvailableSrc",p},counters={}})
        no(N.Sources.owns("AvailableSrc")); no(N.Sources.owns(p))
    end
    eq(N.Sources.stats.refused,before+14)
    register(N,"probe","ProbeSrc")
    no(N.Sources.register{name="other",prefixes={"OtherSrc","ProbeSrc"}}); no(N.Sources.owns("OtherSrc"))
    no(N.Sources.register{name="probe",prefixes={"OtherSrc"}})
end)

test("Sources: registration is once and callbacks cannot be replaced by mutating a descriptor",function()
    local N=h.load(); local count,called=0,0; local original=C_ChatInfo.RegisterAddonMessagePrefix
    C_ChatInfo.RegisterAddonMessagePrefix=function(p) count=count+1; return original(p) end
    local r=register(N,"probe","ProbeSrc",{onAddon=function() called=called+1 end})
    N.Sources.start(); N.Sources.start(); eq(count,1); yes(h.registered().ProbeSrc)
    r.prefixes[1]="OtherSrc"; r.onAddon=function() error("mutated") end
    h.deliver("CHAT_MSG_ADDON","ProbeSrc","x","GUILD","Other Peer"); eq(called,1); no(N.Main.error)
end)

test("Sources: OpenMap Battle.net keeps its original event path and values",function()
    local N=h.load(); yes(N.Sources); local a,b=0,0
    N.Main.openmapBn=function(...) a=a+1; local v={...}; eq(v[1],"OpenMapLoc"); eq(v[4],71); eq(v[3],"WHISPER") end
    N.Sources.bnet=function() b=b+1 end
    h.deliver("BN_CHAT_MSG_ADDON","OpenMapLoc","L0","WHISPER",71); eq(a,1); eq(b,0)
    h.deliver("BN_CHAT_MSG_ADDON","OtherSrc","x","WHISPER",71); eq(a,1); eq(b,1)
end)

test("Sources: guarded callbacks secrets and switches fail silent",function()
    local N=h.load(); local n=0
    local r=register(N,"probe","ProbeSrc",{onAddon=function() n=n+1; error("bad source") end,onBNet=function() n=n+1 end})
    h.deliver("CHAT_MSG_ADDON","ProbeSrc","x","GUILD","Other Peer"); eq(n,1); no(N.Main.error); eq(r.counters.refused,1)
    for _,v in ipairs({{h.secret,"x","GUILD","Other Peer"},{"ProbeSrc",h.secret,"GUILD","Other Peer"},
        {"ProbeSrc","x",h.secret,"Other Peer"},{"ProbeSrc","x","GUILD",h.secret}}) do h.deliver("CHAT_MSG_ADDON",unpack(v)) end
    h.deliver("BN_CHAT_MSG_ADDON","ProbeSrc",h.secret,"WHISPER",71)
    h.deliver("BN_CHAT_MSG_ADDON","ProbeSrc","x","WHISPER",h.secret); eq(n,1)
    N.Main.net("net probe off"); h.deliver("BN_CHAT_MSG_ADDON","ProbeSrc","x","WHISPER",71); eq(n,1)
    N.Main.net("net probe on"); h.deliver("BN_CHAT_MSG_ADDON","ProbeSrc","x","WHISPER",71); eq(n,2)
end)

test("Sources: unavailable optional timer and registration APIs fail silent",function()
    local N=h.load()
    C_Timer=setmetatable({},{__index=function() error("unreadable timer") end})
    C_ChatInfo=setmetatable({},{__index=function() error("unreadable registration") end})
    local r=register(N,"probe","ProbeSrc",{tick=function() end})
    yes(N.Sources.owns("ProbeSrc")); eq(r.counters.refused,1); no(N.Main.error)
    local ok=pcall(N.Sources.start); yes(ok); eq(r.counters.refused,1)
end)

test("Sources: tick-only source runs at one second cadence and net counters append",function()
    local N=h.load(); local ticks={}
    local r=register(N,"probe",nil,{tick=function(t) ticks[#ticks+1]=t end})
    h.advance(1); eq(#ticks,1); eq(ticks[1],h.clock()); h.advance(1); eq(#ticks,2)
    N.Main.net("net"); local text=table.concat(h.log(),"\n")
    yes(text:find("Overlord session:",1,true)); yes(text:find("probe: heard=0 accepted=0 sent=0 refused=0",1,true))
    eq(r.counters.sent,0); eq(#h.sent(),0)
end)
