-- Replayed from the independent round-1 queue probes; synthetic names only.
local H=...
local function step(n) for _=1,n do H.advance(1) end end
local function state(N) return N.Trust and N.Trust.state(N.Main.store,H.clock()) or (N.Main.store.bulo and "known-base" or "unknown-base") end
for _,origin in ipairs({"own","remote"}) do for _,mode in ipairs({"known","unknown","blind"}) do
 H.test("Trust round2: negotiated embassy queued "..origin.." C "..mode,function()
    local N=H.load(); N.Net.SHIP.we=true; N.Net.setConsent("public")
    C_Club={GetGuildClubId=function() return 789 end}
    H.channelMembers("WarEfforttestrealmA",{"Ann Lee"})
    H.roster({{"Wes-TestRealm",true}}); H.establish(N); H.deliver("GUILD_ROSTER_UPDATE"); H.drain()
    H.units().target=nil; H.units().mouseover=nil
    step(13)
    H.deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); H.drain(); step(25)
    H.yes(N.WeEmb.partner(N.Main.emb,"Ann Lee",H.clock()),"partner negotiated over P")
    H.eq(N.Main.emb.mine[1],"g456","seat announced")
    H.clock(300)
    for i=1,4 do H.yes(N.Wire.send("WEFF1","K|"..i.."|2|5","WHISPER","Ann Lee",{net="we",prio="owed"})) end
    H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|9000|1|19|0|0|100|789|H|60|1","GUILD","Wes")
    if origin=="own" then
      for i,name in ipairs({"Cedar Vale","Birch Vale"}) do
        H.units().target=H.player(name,"Horde","Player-1-"..i)
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
      end
      H.units().target=nil; step(4); N.Main.shareTick()
    else H.deliver("CHAT_MSG_ADDON","WEFF1","C|4242|100|0.4|0.5|9000|2|100","GUILD","Wes"); H.drain() end
    local expectedOrigin=origin=="own" and "Me" or "Wes"
    local nBefore=0
    for _,s in ipairs(H.sent()) do if s.prefix=="WEFF1" and s.text:sub(1,2)=="W|" then
      local d=N.Protocol.decode(s.text); if d and d.origin==expectedOrigin and d.inner.type=="C" then nBefore=nBefore+1 end
    end end
    H.eq(nBefore,0,"C is still unsent"); H.yes(N.Wire.queued()>0,"owed queue exists")
    if mode=="blind" and N.Trust then SlashCmdList.LAYERENEMIES("blind on")
    elseif mode=="unknown" or mode=="blind" then H.clock(311); N.Main.poll()
    else H.readLayer(N,7); H.units().target=nil end
    step(90)
    local sent=0; local bad=0
    for _,s in ipairs(H.sent()) do if s.prefix=="WEFF1" and s.text:sub(1,2)=="W|" then
      local d=N.Protocol.decode(s.text)
      if d and d.origin==expectedOrigin and d.inner.type=="C" then
        sent=sent+1
        if (origin=="own" and mode~="known" and d.inner.layer~=0) or (origin=="remote" and d.inner.layer~=9000) then bad=bad+1 end
      end
    end end
    H.eq(sent,1,"positive: C eventually sent"); H.eq(bad,0,"own masked; remote claim preserved"); H.no(N.Main.error)
 end)
end end

do
local H=...
local function state(N) return N.Trust and N.Trust.state(N.Main.store,H.clock()) or (N.Main.store.bulo and "known-base" or "unknown-base") end
local function untrust(N,mode)
    if mode=="known" then return end
    if N.Trust and mode=="blind" then SlashCmdList.LAYERENEMIES("blind on")
    else H.clock(311); N.Main.poll() end
end
for _,mode in ipairs({"known","unknown","blind"}) do
 H.test("Trust round2: queued own embassy H "..mode,function()
    local N=H.load(); H.establish(N); H.clock(300)
    H.units().target=nil; H.units().mouseover=nil
    N.Net.SHIP.we=true; N.Net.setConsent("public")
    C_Club={GetGuildClubId=function() return 789 end}
    N.Main.emb.rows["ann lee"]={name="Ann Lee",guild="456",minor=19,heardAt=300,presenceAt=300}
    N.Main.emb.mine={"g456"}; N.Main.emb.announced="D|g456"; N.Main.emb.announcedAt=300
    H.eq(N.Main.embassyWhy(),nil,"embassy active")
    H.yes(N.WeEmb.partner(N.Main.emb,"Ann Lee",300),"live partner control")
    for i=1,4 do H.yes(N.Wire.send("WEFF1","K|"..i.."|2|5","WHISPER","Ann Lee",{net="we",prio="owed"})) end
    H.yes(N.Main.weHello("request"),"real own H builder sent to guild")
    H.yes(N.Wire.queued()>0,"own W actually queued")
    local before=#H.sent()
    untrust(N,mode)
    -- The known control refreshes the same key, not the sighting or the queue.
    if mode=="known" then H.readLayer(N,7); H.units().target=nil end
    for _=1,70 do H.advance(1) end
    local n,leaks=0,0
    for i=before+1,#H.sent() do local s=H.sent()[i]
      if s.prefix=="WEFF1" and s.text:sub(1,2)=="W|" then
        local d=assert(N.Protocol.decode(s.text))
        if d.origin=="Me" and d.inner.type=="H" then
          n=n+1; if d.inner.layer~=0 then leaks=leaks+1 end
        end
      end
    end
    H.no(N.Main.error)
    if mode=="known" then H.eq(n,1); H.eq(leaks,1)
    else H.eq(n,1,"own H still delivered"); H.eq(leaks,0,"no queued own layer after loss of trust") end
 end)
end
end
