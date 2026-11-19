-- Round-two C2 regressions through Main's real timer, Wire and client boundary.
-- No donor execution; fake client offline result is the same 12 Wire handles.
local H=...
local eq,yes=H.eq,H.yes
local function fixture(mode)
    local N=H.load();N.Net.SHIP.overlord=true
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    UnitName=function() return "Alice Vale",GetRealmName() end
    C_AddOns.GetAddOnMetadata=function() return "1.2.5" end
    -- Keep automatic channel discovery out of this directory scheduling probe.
    GetNumDisplayChannels=function() return 0 end
    IsInGuild=function() return true end
    IsInGroup=function() return true end
    IsInRaid=function() return false end
    local members={};for i=1,40 do members[i]="Dir"..H.abc(i).." Scout" end
    N.Directory.members=function(net) return net=="overlord" and members or {} end
    N.BNet.peers=function() return {} end
    local actual,refused={},0
    if mode=="marked" then
        C_ChatInfo.SendAddonMessage=function() return 12 end
        local ok,why,attempted=N.Wire.send("LayerSwap","same","WHISPER",members[1],{prio="own"})
        eq(ok,false);eq(why,"offline");yes(attempted)
        eq(N.Wire.offlineUntil(members[1],H.clock())-H.clock(),3600)
    elseif mode=="qualified" then
        members[1]=members[1].."-"..GetRealmName():gsub("%s","")
        eq(select(3,N.Invite.name(members[1])),"Dira Scout")
    end
    C_ChatInfo.SendAddonMessage=function(prefix,text,route,target)
        local level,info=2,debug.getinfo(2,"S")
        while info and info.what=="C" do level=level+1;info=debug.getinfo(level,"S") end
        yes(info and info.source:find("Wire.lua",1,true),"real client-call frame")
        if prefix=="OverlordF" and route=="WHISPER" then
            local failed=mode=="natural" and target==members[5]
            actual[#actual+1]={at=H.clock(),target=target,text=text,accepted=not failed}
            if failed then refused=refused+1;return 12 end
        end
        return true
    end
    return N,members,actual,function() return refused end
end
local function replay(mode,seconds,expected,distinct)
    local N,members,actual,refusals=fixture(mode)
    local first
    for i=1,seconds do
        H.advance(1)
        if i==1 then first={gap=N.Main.overlordPeer.gaps["hello:dira scout"],actual=N.Main.overlordPeer.actual["hello:dira scout"]} end
    end
    local accepted,seen=0,{}
    for _,v in ipairs(actual) do
        if v.accepted then accepted=accepted+1;seen[v.target]=true end
    end
    print("PROBE rotation "..mode..": accepted="..accepted.." attempted="..#actual..
        " refused="..refusals().." distinct="..N.Safe.count(seen).." seconds="..seconds)
    -- Rate checks include failed client attempts, not just the successful subset.
    local last,prior={}
    for _,v in ipairs(actual) do
        if prior then yes(v.at-prior>=60,"one greeting attempt per 60 seconds") end
        if last[v.target] then yes(v.at-last[v.target]>=600,"same member gap") end
        prior=v.at;last[v.target]=v.at
    end
    eq(#actual,expected,"gate-refused members cannot consume a minute")
    eq(accepted,expected-refusals(),"all other client attempts reach the real transport")
    eq(N.Safe.count(seen),distinct,"every reachable member is greeted")
    if mode=="marked" then
        eq(first.gap,nil,"offline admission spends no per-member gap")
        eq(first.actual,nil,"offline admission spends no actual gap")
    elseif mode=="qualified" then
        eq(actual[1].target,"Dira Scout","own realm stripped before flight matching")
        yes(actual[1].text:find("|Dira Scout|Alice Vale|NH|",1,true),"wire target uses canonical name")
        eq(N.Main.overlordPeer.gaps["hello:dira scout-testrealm"],nil,"one canonical cooldown key")
        yes(N.Main.overlordPeer.gaps["hello:dira scout"])
    end
end
H.test("Overlord peer: rotation skips a member marked offline for one hour",function()
    replay("marked",3600,60,39)
end)
H.test("Overlord peer: rotation survives member five going offline for three hours",function()
    replay("natural",10800,180,39)
end)
H.test("Overlord peer: rotation canonicalizes a home-realm-qualified member",function()
    replay("qualified",3600,60,40)
end)
