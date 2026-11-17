-- Run from the project root with Lua 5.1. No external addons loaded by this test.
local passed,failed,checks=0,0,0
local function eq(a,b,msg)
    checks=checks+1
    if a~=b then error((msg or "not equal")..": expected "..tostring(b)..", got "..tostring(a),2) end
end
local function yes(v,msg) eq(not not v,true,msg) end
local function no(v,msg) eq(not not v,false,msg) end
local forbidden
local function test(name,fn)
    if arg and arg[1]=="--ui-layout-only" and not name:find("UI layout:",1,true) then return end
    if arg and arg[1]=="--hop-fanout-only" and not name:find("Hop fanout:",1,true) then return end
    if arg and arg[1]=="--hop-any-only" and not name:find("hop-any",1,true) and not name:find("Hop fanout:",1,true) then return end
    if arg and arg[1]=="--presence-only" and not name:find("Presence:",1,true) then return end
    if arg and arg[1]=="--flh-only" and not name:find("FLH:",1,true) then return end
    if arg and arg[1]=="--overlord-only" and not name:find("Overlord:",1,true) then return end
    if arg and arg[1]=="--stack-only" and not name:find("Stack:",1,true) then return end
    if arg and arg[1]=="--spy-relay-only" and not name:find("Spy relay",1,true) then return end
    if arg and arg[1]=="--relay-policy-only" and not name:find("Guild relay policy:",1,true) then return end
    if arg and arg[1]=="--kills-only" and not name:find("Kills",1,true) then return end
    if arg and arg[1]=="--kills-round2-only" and not name:find("Kills R2",1,true) then return end
    local ok,err=pcall(fn)
    -- No test may reach an API that sends, invites, accepts or leaves.
    if ok and (forbidden or 0)>0 then ok,err=false,"forbidden API reached "..forbidden.." time(s)" end
    if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
-- letters-only suffix for generated player names (names never carry digits; 1.0 T2 name rule)
local function abc(i) local s=""; repeat local r=(i-1)%26; s=string.char(97+r)..s; i=math.floor((i-1)/26) until i==0; return s end
local secret=setmetatable({}, {__tostring=function() error("secret stringify") end,__concat=function() error("secret concatenate") end,__lt=function() error("secret compare") end,__index=function() error("secret index") end})
function issecretvalue(v) return rawequal(v,secret) end
local frames,timers,log,units,loaded,metadata
local clock,map,server,channels,inGuild,clientIgnored,inInstance
local guildName="Test Guild"
local wall,grouped,opened
local sent,sendResult,registered,bnInfo,bnCalls
local whoCalls,whoRows,whoRead,clickStack,whoHooks,manualWho
-- File-local policy: exposing an addon table must not let another file widen it.
local WHO_CALLERS={["@LayerEnemies/Adapters.lua"]=true}
local ANY_CALLERS={["@LayerEnemies/Main.lua"]=true}
local function firstLuaCaller()
    local level=3
    while true do
        local info=debug.getinfo(level,"Sf")
        if not info then return {} end
        if info.what=="Lua" or info.what=="main" then return info end
        level=level+1
    end
end
local roster,rosterCalls,combat,raid,leader,invites,accepts,leaves,popupHidden,popup
-- 1.0 T3: chat channels (display list, members), joins, leaves and roster selections; channel calls only from Directory.lua
local joined,leftCh,selected,chanList,chanMembers,joinNotice,joinReturn
-- The routes the addon may send on (Wire.lua); anything else counts as forbidden. LFSw/GUILD carries only "Q".
-- the routes the mock accepts without counting a forbidden send; WEFF1 and HeadHunter are open from 1.0 T1 (behind
-- Net: ship constant, switch, consent, stand-down)
local ROUTES={LayerSwap={WHISPER=true},LEGW1={GUILD=true},LFSw={GUILD=true},
    WEFF1={GUILD=true,PARTY=true,RAID=true,WHISPER=true},HeadHunter={WHISPER=true}}
-- Prefixes the addon may register.
local PREFIXES={FLHNET2=true,OverlordF=true,OpenMapLoc=true,WEFF1=true,HeadHunter=true,LayerSwap=true,LFSw=true,LEGW1=true,["[Spy]"]=true,ForeverSpy1=true,FSENT03=true,GBOUNTY=true,WALLOFSHAME=true,FTold1=true}
-- The addon's source files, in load order, as the TOC lists them.
local function addonFiles()
    local out={}
    for line in io.lines("LayerEnemies/LayerEnemies.toc") do
        -- Load every Lua entry, including names with underscores or punctuation.
        local name=line:match("^(.*)%.lua%s*$")
        if name then out[#out+1]=name end
    end
    assert(#out>0,"no files in the TOC")
    return out
end
local methods={}
function methods:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:Show() local old=self.shown; self.shown=true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() local p=self.point or {}; return p[1],p[2],p[3],p[4],p[5] end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints() end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetFont(...) self.font={...} end
function methods:SetWordWrap(value) self.wordWrap=value end
function methods:SetJustifyH(value) self.justifyH=value end
function methods:SetJustifyV() end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetText(text)
    if debug.getinfo(2,"S").source=="@LayerEnemies/CallUI.lua" then
        local i=1
        while i<=#text do
            local a,b=text:byte(i,i+1)
            if a<128 then i=i+1
            else
                yes(b and b>=128 and b<=191 and a>=194 and a<=201 and (a<201 or b<=143),"Call SetText above U+024F or malformed")
                i=i+2
            end
        end
    end
    self.text=text
end
function methods:SetTexture(path) self.texture=path; return true end
function methods:GetText() return self.text or "" end
-- Approximate metrics, not a native-font renderer: respect width, word wrap and
-- explicit newlines so a fixed-height box can no longer hide an overflow test.
local function textWidth(text,size)
    local _,chars=text:gsub("[^\128-\191]","")
    return chars*size*.6
end
function methods:GetStringWidth()
    local widest=0; local size=(rawget(self,"font") or {})[2] or 10
    for line in (self:GetText().."\n"):gmatch("(.-)\n") do widest=math.max(widest,textWidth(line,size)) end
    return widest
end
function methods:GetStringHeight()
    if self:GetText()=="" then return 0 end
    local size=(rawget(self,"font") or {})[2] or 10
    local width=rawget(self,"width") or math.huge
    local lines=0
    for line in (self:GetText().."\n"):gmatch("(.-)\n") do
        local count,used=1,0
        if rawget(self,"wordWrap")~=false and width>0 then
            for word in line:gmatch("%S+") do
                local w=textWidth(word,size)
                local space=used>0 and textWidth(" ",size) or 0
                if used>0 and used+space+w>width then count=count+1; used=0; space=0 end
                local extra=math.max(0,math.ceil(w/width)-1)
                count=count+extra; used=used+space+w-extra*width
            end
        end
        lines=lines+count
    end
    return lines*(size+2)
end
function methods:GetWidth() return rawget(self,"width") or self:GetStringWidth() end
function methods:GetHeight()
    local height=rawget(self,"height")
    return height and height>0 and height or self:GetStringHeight()
end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetMovable() end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:EnableMouse() end
function methods:EnableMouseWheel() end
function methods:RegisterForDrag() end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAutoFocus() end
function methods:SetMaxLetters() end
function methods:ClearFocus() self.focused=false end
function methods:Disable() self.disabled=true end
function methods:Enable() self.disabled=false end
function methods:Click() if not self.disabled and self.scripts.OnClick then self.scripts.OnClick(self) end end
local function object(kind)
    return setmetatable({kind=kind,shown=true,disabled=false,events={},scripts={}}, {__index=function(_,key) if methods[key] then return methods[key] end; error("unknown frame method: "..key) end})
end
function methods:CreateTexture() local t=object("Texture"); t.parent=self; return t end
function methods:CreateFontString()
    local f=object("FontString"); f.parent=self
    self.regions=rawget(self,"regions") or {}; self.regions[#self.regions+1]=f
    return f
end
function methods:RegisterEvent(event)
    if event=="COMBAT_LOG_EVENT_UNFILTERED" then forbidden=(forbidden or 0)+1 end
    self.events[event]=true
end
function methods:SetScript(key,fn)
    local allowed={OnEvent=true,OnUpdate=true,OnClick=true,OnDragStart=true,OnDragStop=true,OnMouseWheel=true,OnEnterPressed=true,OnEscapePressed=true,OnShow=true,OnHide=true,OnEnter=true,OnLeave=true}
    if not allowed[key] then error("unknown script: "..key) end
    self.scripts[key]=fn
end
function CreateFrame(kind,name,parent,template)
    no(template,"no secure or other templates")
    yes(kind=="Frame" or kind=="Button" or kind=="EditBox","supported frame type")
    local f=object(kind)
    f.name,f.parent,f.template=name,parent,template
    if name then _G[name]=f end
    frames[#frames+1]=f; return f
end
local function deliver(event,...)
    for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
local function drain()
    for _=1,20 do
        local todo={}
        for i=#timers,1,-1 do if timers[i].at<=clock then todo[#todo+1]=table.remove(timers,i) end end
        if #todo==0 then return end
        for i=#todo,1,-1 do todo[i].fn() end
    end
    error("timer loop")
end
local function advance(n) clock=clock+n; server=server+n; wall=wall+n; drain() end
local function loadAddon(savedCallTest)
    frames,timers,log,units,loaded,metadata={},{},{},{},{},{}
    clock,map,server,channels,inGuild,clientIgnored,inInstance=10,100,720100,{WarEffortPubA=7},true,false,false; guildName="Test Guild"
    wall,grouped,opened,forbidden=1800000000,false,{},0
    sent,sendResult,registered,bnInfo,bnCalls={},0,{},nil,0
    _G.BNSendGameData=function() forbidden=forbidden+1; error("must never send BN data") end
    _G.C_BattleNet={SendGameData=BNSendGameData,GetGameAccountInfoByID=function(id)
        bnCalls=bnCalls+1
        if type(bnInfo)=="function" then return bnInfo(id) end
        return bnInfo
    end}
    -- guild roster: {name, online}; combat, party and raid state for the guild host
    roster,rosterCalls,combat,raid,leader={},0,false,false,false
    _G.GetNumGuildMembers=function() return #roster end
    _G.GetGuildRosterInfo=function(i) local e=roster[i]; if e then return e[1],nil,nil,nil,nil,nil,nil,nil,e[2] end end
    _G.C_GuildInfo={GuildRoster=function() rosterCalls=rosterCalls+1 end}
    _G.InCombatLockdown=function() return combat end
    _G.UnitAffectingCombat=function(u) return u=="player" and combat or false end
    _G.IsInRaid=function() return raid end
    _G.UnitIsGroupLeader=function(u) if u=="player" then return leader end; return units[u]~=nil and units[u].leader==true end
    _G.GetNumGroupMembers=function() local n=0; for i=1,4 do if units["party"..i] then n=n+1 end end; return n>0 and n+1 or 0 end
    _G.BuloLayerForever=nil; _G.WarEffortScoutDB=nil; _G.LayerEnemiesDB=savedCallTest
    _G.LayerSwapDB=nil; _G.LE=nil; _G.ChatFrameUtil=nil; _G.ChatFrame_OpenChat=nil
    _G.time=function() return wall end
    _G.IsInGroup=function() return grouped end
    -- Anything that would act for the user counts as a failure, even under pcall.
    for _,name in ipairs({"SendChatMessage","InviteUnit","LeaveParty","DeclineGroup","RunMacroText"}) do
        _G[name]=function() forbidden=forbidden+1; error("must never call "..name) end
    end
    -- the caller of a party call must be Wire.lua (C frames such as pcall are skipped)
    local function fromWire()
        local level=3
        while true do
            local info=debug.getinfo(level,"S")
            if not info then return false end
            if info.what~="C" then return info.source=="@LayerEnemies/Wire.lua" end
            level=level+1
        end
    end
    -- AcceptGroup (0.4.0 auto-accept): allowed from Wire.lua only; the PARTY_INVITE popup is modelled with Blizzard's
    -- OnHide rule (hiding it without inviteAccepted declines)
    accepts,leaves,popupHidden={},{},0
    popup={which="PARTY_INVITE",shown=false,inviteAccepted=nil}
    _G.AcceptGroup=function() accepts[#accepts+1]=clock; if not fromWire() then forbidden=forbidden+1 end end
    _G.StaticPopup_FindVisible=function(which) if which=="PARTY_INVITE" and popup.shown then return popup end end
    _G.StaticPopup_Hide=function(which)
        if which~="PARTY_INVITE" or not popup.shown then return end
        popup.shown=false; popupHidden=popupHidden+1
        if not popup.inviteAccepted then forbidden=forbidden+1 end   -- Blizzard would call DeclineGroup here
    end
    -- the one allowed party call: C_PartyInfo.InviteUnit, from Wire.lua only (0.4.0 guild host); every other member
    -- counts as forbidden
    invites={}
    _G.C_PartyInfo=setmetatable({LeaveParty=function(category)
            leaves[#leaves+1]=clock; if category~=nil then forbidden=forbidden+1 end
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
            grouped=false
        end,
        InviteUnit=function(name)
            invites[#invites+1]=name
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
        end},
        {__index=function(_,key) forbidden=forbidden+1; error("must never use C_PartyInfo."..tostring(key)) end})
    _G.C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn} end}
    _G.C_Map={
        GetBestMapForUnit=function() return map end,
        GetMapInfo=function(id)
            if id==100 then return {mapType=3,parentMapID=1,name="Ashenvale"} end
            if id==200 then return {mapType=3,parentMapID=1,name="Durotar"} end
            if id==101 then return {mapType=4,parentMapID=100,name="Astranaar"} end
            if id==1 then return {mapType=2,parentMapID=0,name="Kalimdor"} end
        end,
        GetMapChildrenInfo=function(id,kind,all)
            if (id==1 or id==947) and kind==3 then return {{mapID=100,name="Ashenvale",mapType=3},{mapID=200,name="Durotar",mapType=3}} end
            return {}
        end,
        GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end,
    }
    _G.C_AddOns={IsAddOnLoaded=function(name) return loaded[name]==true end,GetAddOnMetadata=function(name,key) return metadata[name] end}
    whoCalls,whoRows,whoRead,clickStack,whoHooks,manualWho={},{},{},false,{},false
    _G.FriendsFrame=nil; _G.LFGWhoListFrame=nil; _G.WhoFrame=nil
    _G.hooksecurefunc=function(tbl,key,fn)
        if tbl==C_FriendList and key=="SendWho" then whoHooks[#whoHooks+1]=fn else error("unexpected hook") end
    end
    _G.WHO_TAG_ZONE="z-"; _G.Enum={SocialWhoOrigin={Social=1}}
    _G.C_FriendList={IsIgnored=function() return clientIgnored end,
        SendWho=function(term,origin)
            local caller=firstLuaCaller()
            if not manualWho and (not WHO_CALLERS[caller.source] or not clickStack) then forbidden=forbidden+1 end
            whoCalls[#whoCalls+1]={term=term,origin=origin,at=clock}
            for _,fn in ipairs(whoHooks) do fn(term,origin) end
        end,
        GetNumWhoResults=function()
            if not WHO_CALLERS[firstLuaCaller().source] then forbidden=forbidden+1 end
            return #whoRows,#whoRows
        end,
        GetWhoInfo=function(i)
            if not WHO_CALLERS[firstLuaCaller().source] then forbidden=forbidden+1 end
            whoRead[#whoRead+1]=i; return whoRows[i]
        end}

    _G.C_ChatInfo=setmetatable({
        GetChannelRosterInfo=function(index,r) local n=chanList[index]; local m=n and chanMembers[n] and chanMembers[n][r]; if m then return m,false,false,"Player-1-"..r end end,
        RegisterAddonMessagePrefix=function(prefix)
            registered[prefix]=true
            if not PREFIXES[prefix] then forbidden=forbidden+1 end
            return true
        end,
        -- records every call; a route outside the allowlist counts as forbidden
        SendAddonMessage=function(prefix,text,kind,target)
            sent[#sent+1]={prefix=prefix,text=text,kind=kind,target=target,at=clock}
            if not (ROUTES[prefix] and ROUTES[prefix][kind]) then forbidden=forbidden+1 end
            -- the caller: the first Lua frame above this one (C frames such as pcall are skipped) must be Wire.lua
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
            -- K1 is the only new send: exact version/shape and LEGW1/GUILD, still through Wire's caller frame.
            if prefix=="LEGW1" and text:sub(1,2)=="K|" then
                local zone,x,y,layer,age,conf,item=text:match("^K|1|(%d+)|([^|]*)|([^|]*)|(%d*)|(%d+)|([eh])|([^|]*)$")
                local function coord(v) return v and v:match("^[01]%.%d%d%d$") and tonumber(v)<=1 end
                local valid=zone and tonumber(zone)>=1 and tonumber(zone)<=999999 and tonumber(age)<=120 and #layer<=15
                    and ((x=="" and y=="") or (coord(x) and coord(y)))
                    and (item=="" or item:match("^%x+:%u*:%-?%d*:[fp]$")) and #text<=255
                if kind~="GUILD" or not valid then forbidden=forbidden+1 end
            end
            if type(sendResult)=="function" then return sendResult() end
            return sendResult
        end},
        {__index=function(_,key) forbidden=forbidden+1; error("must never use C_ChatInfo."..tostring(key)) end})
    _G.GetTime=function() return clock end
    _G.GetServerTime=function() return server end
    _G.GetRealmName=function() return "Test Realm" end
    _G.ERR_CHAT_PLAYER_NOT_FOUND_S=nil
    _G.IsInGuild=function() return inGuild end
    _G.IsInInstance=function() return inInstance end
    _G.GetGuildInfo=function() if inGuild then return guildName end end
    _G.GetChannelName=function(name) return channels[name] or 0 end
    _G.Ambiguate=function(name) return name:match("^([^%-]+)") end
    _G.UnitIsVisible=function(u) return units[u]~=nil and units[u].visible==true end
    _G.UnitExists=function(u) return u=="player" or units[u]~=nil end
    _G.UnitGUID=function(u) return units[u] and units[u].guid end
    _G.UnitIsPlayer=function(u) return units[u] and units[u].player or false end
    _G.UnitIsUnit=function(u,v) return u==v end
    _G.UnitPlayerControlled=function(u) return units[u] and units[u].controlled or false end
    _G.UnitName=function(u) if u=="player" then return "Me","Test Realm" end; local e=units[u]; if e then return e.name,e.realm end end
    _G.UnitClass=function(u) local e=units[u]; return e and e.class,e and e.class end
    _G.UnitLevel=function(u) return units[u] and units[u].level end
    _G.UnitFactionGroup=function(u) if u=="player" then return "Alliance" end; return units[u] and units[u].faction end
    _G.GetPlayerInfoByGUID=nil; _G.C_DeathRecap=nil
    _G.DEFAULT_CHAT_FRAME={AddMessage=function(_,s) log[#log+1]=s end}
    _G.SlashCmdList={}; _G.WorldMapFrame=nil
    _G.UIParent={}; _G.Minimap=nil; _G.MinimapCluster=nil; _G.UISpecialFrames={}
    _G.UiMapPoint=nil; _G.CreateVector2D=nil; _G.C_SuperTrack=nil; _G.PlaySound=nil
    _G.SendAddonMessage=function() forbidden=forbidden+1; error("must never send") end
    local function fromDirectory()
        local level=3
        while true do
            local info=debug.getinfo(level,"S")
            if not info then return false end
            if info.what~="C" then return info.source=="@LayerEnemies/Directory.lua" end
            level=level+1
        end
    end
    joined,leftCh,selected,chanList,chanMembers,joinNotice,joinReturn={},{},{},{"General"},{},true,nil
    local function notice(what,name) for i,c in ipairs(chanList) do if c==name or what=="YOU_LEFT" then
        deliver("CHAT_MSG_CHANNEL_NOTICE",what,"","",(i..". "..name),"",0,0,i,name); return end end end
    _G.JoinChannelByName=function(name) if not fromDirectory() then forbidden=forbidden+1 end; joined[#joined+1]=name
        local found=false; for _,c in ipairs(chanList) do if c==name then found=true end end; if not found then chanList[#chanList+1]=name end
        if joinNotice then notice("YOU_JOINED",name) end
        if joinReturn~=nil then return joinReturn end
        return 1,name end
    _G.LeaveChannelByName=function(name) if not fromDirectory() then forbidden=forbidden+1 end; leftCh[#leftCh+1]=name
        for i,c in ipairs(chanList) do if c==name then table.remove(chanList,i); break end end; notice("YOU_LEFT",name) end
    _G.SetSelectedDisplayChannel=function(i) if not fromDirectory() then forbidden=forbidden+1 end; selected[#selected+1]=chanList[i] or i end
    _G.GetNumDisplayChannels=function() return #chanList end
    _G.GetChannelDisplayInfo=function(i) local n=chanList[i]; if n then return i..". "..n,false,nil,i,#(chanMembers[n] or {}),true end end
    _G.ChannelFrame=nil
    local N={}
    for _,file in ipairs(addonFiles()) do
        assert(loadfile("LayerEnemies/"..file..".lua"))("LayerEnemies",N)
    end
    local send=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if prefix=="LayerSwap" and type(text)=="string" and text:match("^inv layer <LS %d+ not %d+%-0 ") then
            local c=firstLuaCaller()
            if not ANY_CALLERS[c.source] or c.func~=N.Main.hopAnyPump then forbidden=forbidden+1 end
        end
        local ok,why,attempted=send(prefix,text,kind,target,opts)
        return ok,why,attempted
    end
    -- 1.0.0 ships both networks on; the harness records the shipped constants and starts every test with them off,
    -- so a test opts in with netOn (the tests written before the flip keep their world)
    N.shipped={}; for k,v in pairs(N.Net.SHIP) do N.shipped[k]=v; N.Net.SHIP[k]=false end
    deliver("ADDON_LOADED","LayerEnemies"); drain()
    no(N.Main.error,"startup error")
    return N
end
local function fakeBulo(id)
    local callbacks={}
    local b={current=id,Radar={seen={}}}
    function b:On(event,fn) callbacks[event]=callbacks[event] or {}; table.insert(callbacks[event],fn) end
    function b:Fire(event,...) for _,fn in ipairs(callbacks[event] or {}) do fn(...) end end
    BuloLayerForever=b
    return b,callbacks
end
local function warSettings()
    loaded.WarEffortScout=true; metadata.WarEffortScout="0.2.13"
    WarEffortScoutDB={silent=false,guildOnly=false,ignored={}}
end
local function player(name,faction,guid)
    return {guid=guid or "Player-1-123",player=true,name=name,realm="Test Realm",class="MAGE",level=60,faction=faction}
end
local function npc(n,zone,sv) return "Creature-0-"..(sv or "7086").."-0-"..(zone or 7).."-"..n.."-ABCDEF" end
local function establish(N)
    units.target={guid=npc(1),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"7086-7"); eq(N.Main.store.zoneUID,7)
end
-- War Effort 1.6.6 vectors (study/wareffort-vectors.json, copied as literals). Server time 720100 -> stamp 100.
local VH="H|1.6.6|100|7086|1|19|0|123|100|456|H|60|1|42|1"
local VC="C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
local VE="E|42|1|1|Zzm:H:60,AbC:A:-1,def:?:?,xyz:D:59|100|aaaa"
local SCOUT="53636f7574204f6e65"   -- "Scout One"
local VX="X|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
local VG="G|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
-- Reports.receive over decoded text; zone 100 for maps 100/101, unknown otherwise.
local function reportFixture(N)
    local t,peers=N.Reports.new(),N.Peers.new()
    local function feed(text,sender,at,route,serverNow)
        local msg,why=N.Protocol.decode(text)
        if not msg then return nil,why end
        return N.Reports.receive(t,msg,{sender=sender or "Reporter",route=route or "GUILD",now=at or 200,serverNow=serverNow or 720100,
            zoneFn=function(id) return (id==100 or id==101) and 100 or nil end,peers=peers})
    end
    return t,feed,peers
end

test("strict frames start shown, dispatcher hidden, no UI or OnUpdate",function()
    local N=loadAddon()
    eq(#frames,20); no(frames[1]:IsShown()); eq(frames[1].scripts.OnUpdate,nil) -- 20: the dispatcher, hidden window and controls, including the Call toggle and Hop to another layer; popup is lazy
    local f=CreateFrame("Frame"); yes(f:IsShown()); no(pcall(function() f:InventedMethod() end))
    eq(N.Main.statusBulo,"not installed"); eq(N.Main.statusWE,"not installed / listening on guild, party and raid (reported, not confirmed)")
end)
test("neither source: own observation works after local NPC confirmation",function()
    local N=loadAddon(); establish(N)
    units.target=player("Enemy","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].name,"Enemy"); eq(rows[1].confidence,"seen by you"); eq(rows[1].x,.25)
    SlashCmdList.LAYERENEMIES("list"); yes(table.concat(log,"\n"):find("Enemy",1,true)); no(N.Main.error)
end)
test("Bulo present subscribes and copies timestamps without position",function()
    local N=loadAddon(); local b,cb=fakeBulo("7086-7")
    advance(1); N.Main.poll(); yes(cb.LFS_LAYER); yes(cb.LFS_RAW); yes(cb.LFS_TRANSFER)
    advance(1); b.Radar.seen["Player-2-1"]={at=clock,hostile=true,src="target"}
    N.Main.poll(); b.Radar.seen={}
    local row=N.Main.store.localSeen["Player-2-1"]
    yes(row); eq(row.at,clock); eq(row.x,nil); eq(row.faction,"unknown")
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    eq(#N.Store.rows(N.Main.store,clock,"unclassified"),1)
    advance(46); yes(N.Main.store.localSeen["Player-2-1"])
    advance(555); eq(N.Main.store.localSeen["Player-2-1"],nil)
end)
test("Bulo shape changes and throwing fields cannot crash",function()
    local N=loadAddon(); BuloLayerForever={current="7086-7",Radar="changed"}; N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable")
    BuloLayerForever=setmetatable({},{__index=function() error("foreign") end}); N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable"); no(N.Main.error)
    BuloLayerForever=secret; N.Main.poll(); eq(N.Main.statusBulo,"Bulo data unavailable")
end)
test("Bulo unsafe/no event bus uses polling",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); b.On=function() error("changed bus") end
    advance(5); no(N.Main.bus); eq(N.Main.store.bulo,"7086-7")
    b.current="7087-9"; advance(5); eq(N.Main.store.bulo,"7087-9"); no(N.Main.error)
end)
test("Bulo layer and raw changes wipe all previous sightings",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    b.Radar.seen.a={at=clock,hostile=true,src="target"}; N.Main.poll(); yes(N.Main.store.localSeen.a)
    advance(1); b.current="7086-8"; b:Fire("LFS_RAW",b.current); drain()
    eq(N.Main.store.localSeen.a,nil); eq(N.Main.store.bulo,"7086-8")
    advance(1); b.current="8000-2"; b:Fire("LFS_LAYER",b.current); drain()
    eq(N.Main.store.bulo,"8000-2"); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("transfer epoch rejects old Bulo and carried unit observations",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    units.target=player("OldEnemy","Horde"); deliver("PLAYER_TARGET_CHANGED"); drain()
    b.Radar.seen[units.target.guid]={at=clock,hostile=true,src="target"}
    advance(1); deliver("SHARD_TRANSFER"); drain()
    eq(N.Safe.count(N.Main.store.localSeen),0); eq(N.Main.store.bulo,nil)
    advance(1); deliver("PLAYER_TARGET_CHANGED"); drain(); eq(N.Safe.count(N.Main.store.localSeen),0)
    advance(1); b.current="9000-8"; b:Fire("LFS_LAYER",b.current); drain()
    eq(N.Main.store.bulo,"9000-8"); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("zone and child-map handling reset only real zones",function()
    local N=loadAddon(); establish(N); local epoch=N.Main.store.serial
    map=101; deliver("ZONE_CHANGED"); drain(); eq(N.Main.store.serial,epoch)
    local z,x=N.Adapters.location(); eq(z,100); eq(x,nil)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.store.zone,200); eq(N.Main.store.bulo,nil); eq(N.Main.store.zoneUID,nil)
end)
test("missing map API safely disables zone-dependent output",function()
    local N=loadAddon(); C_Map=nil; deliver("ZONE_CHANGED"); drain()
    eq(N.Main.store.zone,nil); eq(#N.Store.mapCandidates(N.Main.store,clock,100),0); no(N.Main.error)
end)
test("hostility does not override same faction or unknown faction",function()
    local N=loadAddon(); establish(N)
    units.target=player("Duelist","Alliance"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    eq(#N.Store.rows(N.Main.store,clock,"unclassified"),1)
    units.mouseover=player("Hidden","Horde","Player-1-456"); units.mouseover.faction=secret
    advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0); eq(#N.Store.rows(N.Main.store,clock,"unclassified"),2)
end)
test("secret names/classes/levels/GUIDs remain unreadable",function()
    local N=loadAddon(); establish(N)
    units.target=player(secret,"Horde"); units.target.class=secret; units.target.level=secret
    advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    local row=N.Store.rows(N.Main.store,clock,"local")[1]; yes(row); eq(row.name,nil); eq(row.class,nil); eq(row.level,nil)
    SlashCmdList.LAYERENEMIES("list"); yes(table.concat(log,"\n"):find("Unknown",1,true))
    units.target.guid=secret; deliver("PLAYER_TARGET_CHANGED"); drain(); no(N.Main.error)
    eq(N.Safe.str(secret),nil); eq(N.Safe.num(secret),nil)
end)
test("optional GUID enrichment checks each return and missing API",function()
    local N=loadAddon(); eq(N.Adapters.enrich("Player-1-2"),nil)
    GetPlayerInfoByGUID=function() return secret,secret,secret,secret,2,secret,secret end
    local n,r,c,race=N.Adapters.enrich("Player-1-2"); eq(n,nil); eq(r,nil); eq(c,nil); eq(race,nil)
    GetPlayerInfoByGUID=function() return "Mage","MAGE","Human","Human",2,"Named","Realm",60 end
    local level
    n,r,c,race,level=N.Adapters.enrich("Player-1-2"); eq(n,"Named"); eq(r,"Realm"); eq(c,"MAGE"); eq(race,"Human"); eq(level,60)
    eq(N.Adapters.enrich("target:Name"),nil)
end)
test("NPC GUID parsing keeps namespaces and requires distinct NPC kinds",function()
    local N=loadAddon(); local t=N.Layer.new()
    eq(N.Layer.npc("Player-1-2"),nil); eq(N.Layer.npc(npc(1,0)),nil)
    eq(N.Layer.observe(t,npc(1),1),nil); eq(N.Layer.observe(t,npc(1),2),nil)
    eq(N.Layer.observe(t,npc(2),3),7)
    local zone,kind,raw=N.Layer.npc(npc(42,13,"8000")); eq(zone,13); eq(kind,42); eq(raw,"8000-13")
    eq(N.Layer.bulo("8000-13"),"8000"); eq(N.Layer.bulo("garbage"),nil)
    N.Layer.reset(t); eq(t.current,nil); eq(N.Safe.count(t.votes),0)
end)
test("mixed servers sharing zoneUID do not confirm a server id",function()
    local N=loadAddon(); local t=N.Layer.new()
    N.Layer.observe(t,npc(1,7,"8000"),1)
    local z,_,raw=N.Layer.observe(t,npc(2,7,"9000"),2)
    eq(z,7); eq(raw,nil)
end)
test("NPC vote memory, TTL, pets, and coalescing bounded",function()
    local N=loadAddon()
    for i=1,500 do N.Layer.observe(N.Main.npcs,npc(i,i),i/100) end
    yes(#N.Main.npcs.votes<=5)
    N.Layer.observe(N.Main.npcs,npc(600),1000); eq(N.Main.npcs.current,nil)
    units.target={guid=npc(1),controlled=true}; deliver("PLAYER_TARGET_CHANGED"); drain(); eq(N.Main.store.zoneUID,nil)
    units.target=player("One","Horde")
    for _=1,100 do deliver("PLAYER_TARGET_CHANGED") end
    eq(N.Safe.count(N.Main.pendingUnits),1); drain(); no(N.Main.error)
end)
test("hash vectors and normalization",function()
    local N=loadAddon()
    eq(N.Hash.nameKey("Name","Test-Re alm"),"name-testrealm")
    eq(N.Hash.hash3("abc"),"LXq") -- independent integer reference: djb2 = 193485963
    eq(N.Hash.player("NAME","Test Realm"),N.Hash.player("name","test-realm"))
    eq(N.Hash.player(secret,"Realm"),nil)
end)
test("we decodes C/E/H 1.6.6 vectors",function()
    local N=loadAddon(); local P=N.Protocol
    local c=P.decode(VC)
    yes(c); eq(c.type,"C"); eq(c.rid,42); eq(c.map,100); eq(c.x,.4); eq(c.y,.5); eq(c.layer,7086); eq(c.count,4)
    eq(c.stamp,100); eq(c.spread,12); eq(c.sync,false)
    local e=P.decode(VE)
    yes(e); eq(e.type,"E"); eq(e.rid,42); eq(e.part,1); eq(e.total,1); eq(#e.enemies,4); eq(e.stamp,100)
    eq(e.enemies[1].hash,"Zzm"); eq(e.enemies[1].class,"MAGE"); eq(e.enemies[1].level,60)
    eq(e.enemies[2].class,"WARRIOR"); eq(e.enemies[2].level,-1); eq(e.enemies[3].class,nil); eq(e.enemies[3].level,nil)
    eq(e.enemies[4].class,"ROGUE"); eq(e.enemies[4].level,59)
    local h=P.decode(VH)
    yes(h); eq(h.type,"H"); eq(h.version,"1.6.6"); eq(h.layer,7086); eq(h.minor,19); eq(h.stamp,100)
    eq(P.decode("H|1.6.6|100|7086|1").minor,0)                    -- absent minor is 0
    eq(P.decode("H|1.6.6|100|7086|1|x9").minor,nil)               -- unreadable minor is unknown
    -- other well-formed types are ignored, not errors
    -- (Q, Y and J are read since lane A2; P, D and W since A3)
    eq(P.decode("Q").type,"Q"); eq(P.decode("J|7|100|7086|0.400|0.500|100").type,"J"); eq(P.decode("Y|12|100|a:480").maxAge,480)
    eq(P.decode("P|19|456|0|a").type,"P"); eq(P.decode("D|g789").type,"D"); eq(P.decode("W|"..SCOUT.."|123|"..VC:sub(1)).type,"W")
    for _,text in ipairs({"T|100|0.400|0.500|100","K|7|3|100|4","S|1234|20|100|2|1|0|4|3|100",
        "R|anything","L|1|100"}) do
        local m,why=P.decode(text); eq(m,nil,text); eq(why,"ignored",text)
    end
end)
test("decoder rejects hostile malformed and oversized messages",function()
    local N=loadAddon()
    local many={}; for i=1,19 do many[i]="abc:H:60" end
    local bad={"",string.rep("A",256),"C|1|100|nan|0|7|1|100","C|1|100|1.01|0|7|1|100","C|0|100|0|0|7|1|100","C|1|100|0|0|7|201|100",
        "C|1|0|0|0|7|1|100","C|1|100|0|0|-1|1|100","C|1|100|0|0|7","E|1|2|1|abc:H:60|100","E|1|1|1|abcd:H:60|100","E|1|1|1|abc:Z:60|100",
        "E|1|1|1|abc:H:0|100","E|1|1|1|abc:H:60,|100","E|1|1|1||100","E|1|1|1","E|1|1|1|"..table.concat(many,",").."|100",
        "H|bad|100|7|1","H|1.6.6|100|7","C|1|100|0|0|7|1|100\n","C|1|100|0|0|7|1|100 ","C|1|100|0|0|7|1|1\0001"}
    for _,text in ipairs(bad) do local m,why=N.Protocol.decode(text); eq(m,nil,text); eq(why,"invalid",text) end
    eq(N.Protocol.decode(secret),nil); eq(N.Protocol.decode({}),nil)
    -- optional fields that are unreadable become unknown instead of failing the message
    local c=N.Protocol.decode("C|1|100|0|0|7|1|3600|46|4:2"); yes(c); eq(c.stamp,nil); eq(c.spread,nil); eq(c.sync,false)
end)
test("we accepts trailing unknown fields",function()
    local N=loadAddon(); local P=N.Protocol
    local c=P.decode("C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4|x|y|z|1|2|3|4|5|6"); yes(c); eq(c.count,4); eq(c.stamp,100)
    local e=P.decode(VE.."|more|fields"); yes(e); eq(#e.enemies,4)
    local h=P.decode(VH.."|extra|9"); yes(h); eq(h.minor,19)
    yes(P.decode("C|42|100|0.400|0.500|7086|4"))                    -- minimum 7 fields, no stamp
end)
test("we G and X unwrap one level and reject nesting",function()
    local N=loadAddon(); local P=N.Protocol
    for _,text in ipairs({VX,VG}) do
        local m=P.decode(text); yes(m); eq(m.origin,"Scout One"); eq(m.realm,123); eq(m.inner.type,"C"); eq(m.inner.rid,42); eq(m.inner.stamp,100)
    end
    eq(P.decode(VX).type,"X"); eq(P.decode(VG).type,"G")
    local g=P.decode("G|"..SCOUT.."||"..VH); yes(g); eq(g.realm,nil); eq(g.inner.minor,19)
    yes(P.decode("X|"..SCOUT.."|123|"..VE))
    local bad={"G|"..SCOUT.."|123|"..VG,"X|"..SCOUT.."|123|"..VX,"G|"..SCOUT.."|123|X|"..SCOUT.."|123|"..VC,
        "X|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|0|12|1:2",   -- sync C never travels wrapped
        "G|"..SCOUT.."|123|Q","G|"..SCOUT.."|123|"..VC:sub(1,8),"G|536|123|"..VC,"G|41|123|"..VC,"G|0a41|123|"..VC,"G|7c41|123|"..VC,
        "G|"..SCOUT.."|0|"..VC,"G|"..SCOUT.."|x|"..VC,"G|"..SCOUT.."|123","G|zz41|123|"..VC}
    for _,text in ipairs(bad) do local m,why=P.decode(text); eq(m,nil,text); eq(why,"invalid",text) end
end)
test("we stamp ages",function()
    local N=loadAddon(); local P=N.Protocol
    for _,v in ipairs({{100,720100,0},{99,720100,1},{101,720100,0},{3599,720001,2},{1900,720100,1800},{1899,720100,0}}) do
        eq(P.age(v[1],v[2]),v[3],v[1].."@"..v[2])
    end
    eq(P.age(nil,720100),0); eq(P.age(100,secret),nil); eq(P.age(100,nil),nil)
    -- C and E older than 900 s are dropped; 900 is kept
    local _,feed=reportFixture(N)
    local r,why=feed("C|1|100|0|0|7|1|"..(100-901)%3600); eq(r,nil); eq(why,"stale")
    r=feed("C|2|100|0|0|7|1|"..(100-900)%3600); yes(r); eq(r.age,900)
    r,why=feed("E|3|1|1|abc:H:60|"..(100-901)%3600); eq(r,nil); eq(why,"stale")
    r,why=feed("C|4|100|0|0|7|1|100",nil,nil,nil,secret); eq(r,nil); eq(why,"clock unavailable")
end)
test("we C alone is a record",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r,why=feed(VC,"Scout-Realm",200)
    yes(r); eq(why,"new"); eq(r.src,"we"); eq(r.kind,"group"); eq(r.origin,"Scout-Realm"); eq(r.via,"Scout-Realm"); eq(r.route,"GUILD")
    eq(r.rid,"42"); eq(r.zone,100); eq(r.count,4); eq(#r.enemies,0); eq(r.heard,200); eq(r.age,0); eq(r.share,"guild"); eq(r.x,.4)
    eq(r.layer.ns,"unknown"); eq(r.layer.value,7086)
    -- the E list enriches the same record without changing when it was heard
    local r2,why2=feed(VE,"Scout-Realm",205); eq(r2,r); eq(why2,"enriched"); eq(#r.enemies,4); eq(r.heard,200)
    local _,why3=feed(VE,"Scout-Realm",206); eq(why3,"duplicate list")
    -- a zone we cannot resolve makes no record
    local _,why4=feed("C|43|555|0|0|7|1|100","Scout-Realm"); eq(why4,"zone unknown")
    -- in the store the record shows with its count while no list has arrived
    local s=N.Store.new(0); s.zone=100; s.bulo="7086-7"
    local c=feed("C|50|100|0|0|7|3|100","Other",300); yes(N.Store.report(s,c,300))
    local rows=N.Store.rows(s,300,"reported"); eq(#rows,1); eq(rows[1].name,"3 not listed"); eq(rows[1].reporter,"Other")
end)
test("we E before C attaches within 15 s and expires after",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r,why=feed("E|1|1|1|abc:H:60|100","Scout",200); eq(r,nil); eq(why,"held")
    r=feed("C|1|100|0|0|7|2|100","Scout",215); yes(r); eq(#r.enemies,1); eq(r.enemies[1].hash,"abc"); eq(r.heard,215)
    eq(N.Safe.count(t.held),0); eq(t.heldBy.scout,nil)
    feed("E|2|1|1|abc:H:60|100","Scout",300)
    r=feed("C|2|100|0|0|7|2|100","Scout",316); yes(r); eq(#r.enemies,0)
    eq(N.Safe.count(t.held),0)
    -- at most 200 held entries per reporter
    for i=1,11 do local list={}; for j=1,18 do list[j]=string.char(64+i)..string.format("%02d",j)..":H:60" end
        eq(select(2,feed("E|"..(10+i).."|1|1|"..table.concat(list,",").."|100","Flood",400)),"held") end
    eq(t.heldBy.flood,198); eq(select(2,feed("E|30|1|1|abc:H:60,abd:H:60,abe:H:60|100","Flood",400)),"held list cap")
    eq(select(2,feed("E|30|1|1|abc:H:60|100","Other",400)),"held")
end)
test("we lost middle E still shows count",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r=feed("C|7|100|0.1|0.2|7|5|100","Scout",200)
    feed("E|7|1|3|aaa:H:60,bbb:A:40|100","Scout",201)
    feed("E|7|3|3|ccc:D:60,ddd:E:40|100","Scout",202)
    eq(#r.enemies,4); eq(r.count,5); eq(r.heard,200)
    -- a list whose new entries would exceed the count is rejected whole
    local _,why=feed("E|7|2|3|eee:H:60,fff:H:60|100","Scout",203); eq(why,"more enemies than counted"); eq(#r.enemies,4)
    _,why=feed("E|7|2|3|aaa:H:60,eee:H:60|100","Scout",204); eq(why,"enriched"); eq(#r.enemies,5)
    local s=N.Store.new(0); s.zone=100; s.bulo="7086-7"
    feed("C|8|100|0|0|7|3|100","Scout",205); local r8=feed("E|8|1|2|aaa:H:60|100","Scout",205)
    yes(N.Store.report(s,r8,206)); yes(N.Store.report(s,r,206))
    local rows=N.Store.rows(s,206,"reported"); eq(#rows,7)
    local names={}; for _,row in ipairs(rows) do names[row.name]=(names[row.name] or 0)+1 end
    eq(names["2 more not listed"],1); eq(names.Unknown,6)
end)
test("we report ids: newer only, caps",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    yes(feed("C|10|100|0|0|7|1|100","Scout",200))
    eq(select(2,feed("C|10|100|0|0|7|1|100","Scout",201)),"duplicate report")
    eq(select(2,feed("C|9|100|0|0|7|1|100","Scout",202)),"old report")
    yes(feed("C|11|100|0|0|7|1|100","Scout",203))
    -- wrap-around: 65535 then 1 is newer
    yes(feed("C|65535|100|0|0|7|1|100","Wrap",200)); yes(feed("C|1|100|0|0|7|1|100","Wrap",201))
    eq(select(2,feed("C|65534|100|0|0|7|1|100","Wrap",202)),"old report")
    -- after the 600 s TTL the record is gone, but the id order holds for an hour
    N.Reports.prune(t,900); eq(t.reports["scout:10"],nil)
    eq(select(2,feed("C|11|100|0|0|7|1|100","Scout",900)),"old report")
    -- names compare whole and without case: another realm is another reporter (مانع T3 F1)
    eq(select(2,feed("C|11|100|0|0|7|1|100","SCOUT",901)),"old report")
    eq(select(2,feed("C|11|100|0|0|7|1|100","scout-OtherRealm",901)),"new")
    -- 64 live reports at most
    local u,feed2=reportFixture(N)
    for i=1,64 do yes(feed2("C|1|100|0|0|7|1|100","Ess"..abc(i),200)) end
    eq(select(2,feed2("C|1|100|0|0|7|1|100","Ess"..abc(65),200)),"report cap"); eq(u.n,64)
    -- 512 reporters' id order at most: the oldest is forgotten
    local v,feed3=reportFixture(N)
    for i=1,600 do feed3("C|1|100|0|0|7|1|100","Arr"..abc(i),200+i); N.Reports.prune(v,200+i); v.reports={}; v.n=0 end
    eq(N.Safe.count(v.latest),512)
end)
test("reported reducer output stays separate with possible hash identities",function()
    local N=loadAddon(); local t=N.Store.new(0); t.zone=100; t.bulo="7086-7"; t.zoneUID=7
    yes(N.Store.observe(t,{key="Player-1-1",at=100,name="Enemy",realm="Test Realm",class="MAGE",faction="opposite",source="own target"},100))
    local hash=N.Hash.player("Enemy","Test Realm")
    local report=N.Record.new({src="we",kind="group",origin="Reporter",via="Reporter",route="GUILD",rid="1",zone=100,x=.4,y=.5,count=1,
        enemies={{hash=hash,class="MAGE",level=60}},layer={ns="server",value="7086"},heard=101,age=0,share="guild"})
    yes(N.Store.report(t,report,101))
    local rows=N.Store.rows(t,101,"reported"); eq(#rows,1); eq(rows[1].name,"Unknown"); yes(rows[1].possible:find("possible identity:",1,true))
    eq(rows[1].confidence,"reported, not confirmed"); eq(rows[1].namespace,"server"); eq(rows[1].relation,"same"); eq(rows[1].record,report)
    eq(#N.Store.rows(t,101,"local"),1)
    t.identities[hash]["Collision-Realm"]=101
    rows=N.Store.rows(t,101,"reported"); yes(rows[1].possible:find("Collision-Realm",1,true))
    -- every record of our zone is kept and labelled with its relation; another zone or the boundary instant is not
    yes(N.Store.report(t,N.Record.new({src="we",kind="group",origin="Other",route="GUILD",rid="2",zone=100,count=1,layer={ns="server",value="7087"},heard=101,age=0,share="guild"}),101))
    yes(N.Store.report(t,N.Record.new({src="we",kind="group",origin="Third",route="GUILD",rid="3",zone=100,count=1,layer={ns="zoneuid",value=7},heard=101,age=0,share="guild"}),101))
    local rel={}; for _,row in ipairs(N.Store.rows(t,101,"reported")) do rel[row.reporter]=row.relation end
    eq(rel.Other,"other"); eq(rel.Third,"unknown"); eq(rel.Reporter,"same")
    local ok,why=N.Store.report(t,N.Record.new({src="we",kind="group",origin="Far",route="GUILD",rid="4",zone=200,layer={ns="server",value="7086"},heard=101,share="guild"}),101)
    no(ok); eq(why,"another zone")
    ok,why=N.Store.report(t,N.Record.new({src="we",kind="group",origin="Early",route="GUILD",rid="5",zone=100,layer={ns="server",value="7086"},heard=0,share="guild"}),101)
    no(ok); eq(why,"before observation epoch")
    no(N.Store.report(t,{id="x"},101))
end)
test("store expiration, epoch, caps and deterministic newest ordering",function()
    local N=loadAddon(); local t=N.Store.new(100); t.zone=100; t.bulo="7086-7"
    no(N.Store.observe(t,{key="old",at=99},200)); no(N.Store.observe(t,{key="equal",at=100},200)); no(N.Store.observe(t,{key="future",at=201},200))
    for i=1,300 do N.Store.observe(t,{key=tostring(i),at=101+i/10,faction="opposite",source="own target"},200) end
    eq(N.Safe.count(t.localSeen),256)
    local rows=N.Store.rows(t,200,"local"); eq(rows[1].key,"256"); eq(rows[#rows].key,"1")
    N.Store.prune(t,800); eq(N.Safe.count(t.localSeen),0)
    N.Store.reset(t,801,200,"8000-9",9); eq(t.zone,200); eq(N.Safe.count(t.identities),0)
end)
test("headless map candidates only for shown zone, never fake enemy coordinates",function()
    local N=loadAddon(); establish(N)
    units.target=player("Enemy","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(#N.Store.mapCandidates(N.Main.store,clock,200),0)
    local candidates=N.Store.mapCandidates(N.Main.store,clock,100)
    eq(#candidates,1); eq(candidates[1].x,.25); eq(candidates[1].positionKind,"approximate observer position")
    eq(#frames,20)
end)
test("SavedVariables contain options only; no sightings survive reload",function()
    local N=loadAddon(); establish(N)
    units.target=player("PrivateName","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(LayerEnemiesDB.sightings,nil); eq(LayerEnemiesDB.localSeen,nil); yes(LayerEnemiesDB.options)
    N.Main.start(); eq(#frames,20)
    N=loadAddon(); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("heartbeat is five seconds idle, two while map shown",function()
    local N=loadAddon()
    local function nextDelay() local d=math.huge; for _,v in ipairs(timers) do d=math.min(d,v.at-clock) end; return d end
    eq(nextDelay(),5)
    WorldMapFrame=CreateFrame("Frame"); advance(5); eq(nextDelay(),2)
    WorldMapFrame:Hide(); advance(2); eq(nextDelay(),5); no(N.Main.error)
end)
test("missing timer and message-registration APIs degrade safely",function()
    local N=loadAddon(); C_Timer=nil; C_ChatInfo=nil
    N.Main.queueUnit("target"); N.Main.queuePoll(); no(N.Main.error)
    advance(5); eq(N.Main.error,"timer unavailable; event-only mode")
end)
test("old units must disappear before reacquisition after a transfer",function()
    local N=loadAddon(); establish(N)
    units.nameplate1=player("Returning","Horde")
    advance(1); deliver("NAME_PLATE_UNIT_ADDED","nameplate1"); drain()
    deliver("SHARD_TRANSFER"); drain(); eq(N.Safe.count(N.Main.store.localSeen),0)
    units.nameplate1=nil; deliver("NAME_PLATE_UNIT_REMOVED","nameplate1"); drain()
    units.target=nil; deliver("PLAYER_TARGET_CHANGED"); drain()
    units.mouseover=nil; deliver("UPDATE_MOUSEOVER_UNIT"); drain()
    establish(N)
    units.nameplate1=player("Returning","Horde")
    advance(1); deliver("NAME_PLATE_UNIT_ADDED","nameplate1"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),1); no(N.Main.error)
end)
test("a zone boundary drops held lists and reports, not the report order",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    feed("E|1|1|2|abc:H:60|100","Scout",200); feed("C|2|100|0|0|7|1|100","Scout",200)
    N.Reports.clearPending(t); eq(N.Safe.count(t.held),0); eq(N.Safe.count(t.reports),0); eq(t.n,0)
    local r=feed("C|1|100|0|0|7|2|100","Scout",201); eq(r,nil)          -- older than 2: not a new sighting
    r=feed("C|3|100|0|0|7|2|100","Scout",201); yes(r); eq(#r.enemies,0)
end)
test("foreign field getter failures do not escape game event dispatch",function()
    local N=loadAddon()
    C_Map=setmetatable({},{__index=function() error("API shape changed") end})
    yes(pcall(deliver,"ZONE_CHANGED")); eq(N.Main.error,"data unavailable (API error)")
end)
test("unchanged Bulo timestamps allocate no duplicate observations",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    b.Radar.seen.a={at=clock,hostile=true,src="target"}; N.Main.poll()
    local first=N.Main.store.localSeen.a
    local snap=N.Adapters.bulo(N.Main.store.epoch,clock,N.Main.store.localSeen)
    eq(#snap.observations,0); N.Main.poll(); eq(N.Main.store.localSeen.a,first)
    advance(1); b.Radar.seen.a.at=clock; N.Main.poll()
    yes(N.Main.store.localSeen.a~=first); eq(first.at,clock-1)
end)
test("deterministic decoder fuzz never crashes or accepts oversized input",function()
    local N=loadAddon(); math.randomseed(1337)
    local alphabet="CEH|0123456789abcdef:?-,. \n"
    for _=1,5000 do
        local n=math.random(0,300); local s={}
        for i=1,n do local pos=math.random(#alphabet); s[i]=alphabet:sub(pos,pos) end
        local ok,msg=pcall(N.Protocol.decode,table.concat(s))
        yes(ok); if n>255 then eq(msg,nil) end
    end
end)
test("same-frame own unit data can classify a Bulo copy without restamping",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    units.target=player("Verified","Horde")
    b.Radar.seen[units.target.guid]={at=clock,hostile=true,src="target"}; N.Main.poll()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    deliver("PLAYER_TARGET_CHANGED"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].at,clock); eq(rows[1].source,"own target"); eq(rows[1].x,.25)
end)
test("loaded Bulo with missing namespace reports unavailable rather than absent",function()
    local N=loadAddon(); loaded.BuloLayerForever=true; N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable"); no(N.Main.error)
end)
-- ---------------------------------------------------------------------------
-- War Effort reports dated by time of receipt, and the ask-for-invite flow.
local ASK="Hi! Could you invite me to your layer please?"
local function logged(text) return table.concat(log,"\n"):find(text,1,true)~=nil end
local function lines(text) local n=0; for _,l in ipairs(log) do if l:find(text,1,true) then n=n+1 end end; return n end
local function names(list) local out={}; for i,c in ipairs(list) do out[i]=c.name end; return table.concat(out,",") end
local function chatBox() ChatFrameUtil={OpenChat=function(text,frame) opened[#opened+1]={text=text,frame=frame} end} end
local function friends(N,list,book)
    local b=fakeBulo("7086-7"); b.Guild={list=list or {}}
    if book then LayerSwapDB={book=book} end
    N.Main.poll(); eq(N.Main.store.bulo,"7086-7")
    return b
end
local function there(extra)
    local e={key="8000",zone="100",host=false,at=wall}
    for k,v in pairs(extra or {}) do e[k]=v end
    return e
end
local function page(extra)
    local e={layer="8000-13",zone="100",at=wall}
    for k,v in pairs(extra or {}) do e[k]=v end
    return e
end
local function report(id,layer,sender,map,route)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|"..(map or 100).."|0.4|0.5|"..layer.."|1|"..stamp,route or "GUILD",sender or "Other")
    deliver("CHAT_MSG_ADDON","WEFF1","E|"..id.."|1|1|abc:H:40|"..stamp,route or "GUILD",sender or "Other")
end
local function hello(sender,minor,route)
    deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|"..minor.."|0|123|"..math.floor(server)%3600,route or "GUILD",sender)
end
test("one layer key helper compares the server part only",function()
    local N=loadAddon(); local L=N.Layer
    eq(L.key("7086-7"),"7086"); eq(L.key("7086"),"7086"); eq(L.key(7086),"7086")
    for _,bad in ipairs({"","x","7086-","-7","7086-7-1","70 86",0,-1,1.5,1e15,0/0,{},true,string.rep("1",33)}) do eq(L.key(bad),nil) end
    eq(L.key(secret),nil); eq(L.key(nil),nil)
    yes(L.same("7086-7","7086-99")); yes(L.same("7086","7086-1")); yes(L.same(7086,"7086"))
    no(L.same("7086-7","7087-7")); no(L.same(nil,nil)); no(L.same(secret,secret)); no(L.same("7086",nil))
end)
test("a War Effort report shows as reported, not confirmed",function()
    local N=loadAddon(); establish(N)
    advance(1); local at=clock; report(1,7)
    eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].at,at); eq(rows[1].name,"Unknown"); eq(rows[1].class,"MAGE"); eq(rows[1].level,40)
    eq(rows[1].confidence,"reported, not confirmed"); eq(rows[1].reporter,"Other"); eq(rows[1].relation,"unknown")
    eq(rows[1].namespace,"unknown"); eq(rows[1].age,0)
    eq(#N.Store.rows(N.Main.store,clock,"local"),0); eq(#N.Store.rows(N.Main.store,clock,"unclassified"),0)
    eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    SlashCmdList.LAYERENEMIES("list")
    yes(logged("Reported, not confirmed: 1 more in /le reports")); no(logged("Unknown | MAGE"))
    SlashCmdList.LAYERENEMIES("reports")
    yes(logged("Reported, not confirmed (War Effort; age as the reporter's clock gives it):"))
    yes(logged("Unknown | MAGE | 40 | zone 100 | received 0 s ago | reported (War Effort) | reported, not confirmed | reported by Other | reported cluster position | layer unknown"))
    yes(logged("Only players seen by you or reported by other players' addons.")); no(N.Main.error)
    -- a claimed age is shown
    local stamp=(math.floor(server)-120)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|2|100|0.4|0.5|7|1|"..stamp,"GUILD","Older")
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("1 not listed | Unknown class | ? | zone 100 | received 0 s ago | reported (War Effort) | reported, not confirmed | reported by Older | reported cluster position | claimed 120 s old | layer unknown"))
end)
test("receipt-time reports expire ten minutes after receipt",function()
    local N=loadAddon(); establish(N); advance(1); report(1,7)
    advance(598); eq(#N.Store.rows(N.Main.store,clock,"reported"),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    advance(3); eq(#N.Store.rows(N.Main.store,clock,"reported"),0); eq(N.Safe.count(N.Main.store.reports),0)
    eq(#N.Store.reporters(N.Main.store,clock),0)
end)
test("a repeated report id is not a new sighting; an hour later it is (documented limit)",function()
    local N=loadAddon(); establish(N); advance(1); report(1,7)
    report(1,7); eq(N.Main.lastDrop,"duplicate list"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(20); deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"duplicate report")
    advance(600); eq(N.Safe.count(N.Main.store.reports),0)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"old report")
    -- KNOWN LIMIT: the stamp has no hour and the id order is kept for an hour, so an old packet replayed later is
    -- shown again as a fresh unconfirmed report.
    advance(3600); report(1,7); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].confidence,"reported, not confirmed")
end)
test("we drops whisper and channel, and types a route does not carry",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600; local c="C|1|100|0|0|7|1|"..stamp
    deliver("CHAT_MSG_ADDON","WEFF1",c,"WHISPER","Other"); eq(N.Main.lastDrop,"C is not read on WHISPER","(only J by whisper, lane A2)")
    deliver("CHAT_MSG_ADDON","WEFF1",c,"CHANNEL","Other",nil,nil,7,"WarEffortPubA"); eq(N.Main.lastDrop,"route")
    deliver("CHAT_MSG_ADDON","WEFF1",VX,"GUILD","Relay"); eq(N.Main.lastDrop,"X is not read on GUILD")
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"PARTY","Relay"); eq(N.Main.lastDrop,"G is not read on PARTY")
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"RAID","Relay"); eq(N.Main.lastDrop,"G is not read on RAID")
    eq(N.Safe.count(N.Main.store.reports),0)
    deliver("CHAT_MSG_ADDON","WEFF1",c,"PARTY","Friend"); eq(N.Main.lastDrop,"new")
    deliver("CHAT_MSG_ADDON","WEFF1","C|2|100|0|0|7|1|"..stamp,"RAID","Friend"); eq(N.Main.lastDrop,"new")
    local r=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(r.share,"public"); eq(r.route=="PARTY" or r.route=="RAID",true)
    -- nothing about another addon's prefix, and an ignored type leaves no note
    N.Main.lastDrop=nil; deliver("CHAT_MSG_ADDON","WEFF1","Q","GUILD","Other"); eq(N.Main.lastDrop,nil)
    deliver("CHAT_MSG_ADDON","ZRAD1",c,"GUILD","Other"); eq(N.Main.lastDrop,nil)
    eq(N.Safe.count(N.Main.store.reports),2); no(N.Main.error); eq(forbidden,0)
end)
test("we own echo, ignore list for sender and origin, guild membership",function()
    local N=loadAddon(); establish(N); advance(1)
    local c="C|1|100|0|0|7|1|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Me-TestRealm"); eq(N.Main.lastDrop,"own echo")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..("Me"):gsub(".",function(ch) return string.format("%02x",ch:byte()) end).."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    clientIgnored=true; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"ignored sender")
    -- the ignore list also applies to a wrapper's origin
    local old=C_FriendList.IsIgnored
    C_FriendList.IsIgnored=function(name) return name=="Scout One" end
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); eq(N.Main.lastDrop,"ignored sender")
    C_FriendList.IsIgnored=function() return nil end
    deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"client ignore policy unavailable")
    C_FriendList=nil; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"client ignore policy unavailable")
    C_FriendList={IsIgnored=function() return false end}; clientIgnored=false
    inGuild=false; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"guild unavailable")
    eq(N.Safe.count(N.Main.store.reports),0)
    inGuild=true; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"new")
    eq(N.Safe.count(N.Main.store.reports),1); no(N.Main.error)
end)
test("we rate limit 6 per 10 s",function()
    local N=loadAddon(); establish(N); advance(1)
    local function c(id,who,route) deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|100|0|0|7|1|"..math.floor(server)%3600,route or "GUILD",who) end
    for i=1,7 do c(i,"Busy") end
    eq(N.Safe.count(N.Main.store.reports),6); eq(N.Main.lastDrop,"new")       -- the 7th leaves no note
    c(20,"Calm"); eq(N.Safe.count(N.Main.store.reports),7)                    -- per sender
    advance(10); c(8,"Busy"); eq(N.Safe.count(N.Main.store.reports),8)
    -- G wrappers: 20 per relayer per 10 s, counted apart from its own messages
    local function hex(name) return (name:gsub(".",function(ch) return string.format("%02x",ch:byte()) end)) end
    for i=1,21 do deliver("CHAT_MSG_ADDON","WEFF1","G|"..hex("Origin"..abc(i)).."||C|1|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Relay") end
    eq(N.Safe.count(N.Main.store.reports),28)
    c(1,"Relay"); eq(N.Safe.count(N.Main.store.reports),29)
end)
test("we works with no War Effort installed",function()
    local N=loadAddon(); establish(N); advance(1)
    loaded.WarEffortScout=false; WarEffortScoutDB=nil
    hello("Scout",19); report(1,7086,"Scout")
    eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),1)
    N.Main.poll(); eq(N.Main.statusWE:sub(1,48),"not installed / listening on guild, party and ra")
    -- an installed War Effort changes nothing: its settings are not read
    loaded.WarEffortScout=true; WarEffortScoutDB={silent=true,guildOnly=true,ignored={scout=true}}
    report(2,7086,"Scout"); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),2)
    no(N.Main.error); eq(forbidden,0)
end)
test("we layer is unknown without a hello, below 13 and above 19",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Low",12); hello("High",20)
    report(1,7086,"None"); report(1,7086,"Low"); report(1,7086,"High")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,3)
    for _,row in ipairs(rows) do eq(row.relation,"unknown",row.reporter); eq(row.namespace,"unknown"); eq(row.reportLayer,7086) end
    -- a hello expires after 900 s
    hello("Late",19); advance(901); report(1,7086,"Late")
    local late; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.reporter=="Late" then late=row end end
    eq(late.namespace,"unknown")
end)
test("we layer is server after hello minor 19",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Here",19); hello("There",19); hello("Lowest",13)
    report(1,7086,"Here"); report(1,9000,"There"); report(1,7086,"Lowest")
    local rel={}; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do rel[row.reporter]=row.relation.."/"..row.namespace end
    eq(rel.Here,"same/server"); eq(rel.There,"other/server"); eq(rel.Lowest,"same/server")
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("| other server key 9000")); yes(logged("| same server key as yours"))
    -- the relayer's hello does not count for the origin of a G
    hello("Relay",19)
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay")
    local g; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.reporter=="Scout One" then g=row end end
    eq(g.namespace,"unknown"); eq(g.record.via,"Relay"); eq(g.record.share,"public"); eq(g.name,"4 not listed")
    -- the origin's own hello, wrapped, does
    local h="H|1.6.6|100|7086|1|19|0|123|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|"..h,"GUILD","Relay")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|C|43|100|0.4|0.5|7086|1|"..math.floor(server)%3600,"GUILD","Relay")
    local found=false
    for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do
        if row.reporter=="Scout One" and row.record.rid=="43" then found=true; eq(row.relation,"same"); eq(row.namespace,"server") end
    end
    yes(found)
end)
test("we repeated G of one report is one record",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local g="G|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|"..stamp
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayOne"); eq(N.Main.lastDrop,"new")
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayTwo"); eq(N.Main.lastDrop,"duplicate report")
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayOne"); eq(N.Main.lastDrop,"duplicate report")
    eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    -- the E list relayed by another guildmate enriches the same record
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|E|42|1|1|Zzm:H:60,AbC:A:-1|"..stamp,"GUILD","RelayTwo"); eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,3); eq(N.Safe.count(N.Main.store.reports),1)
end)
test("we zone, layer zero and clock",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local function send(text,who) deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD",who or "Other") end
    send("C|1|100|0|0|7|1|"..(stamp-901)%3600); eq(N.Main.lastDrop,"stale")
    send("C|2|100|0|0|7|1|"..(stamp+1800)%3600); eq(N.Main.lastDrop,"stale")      -- age 1800 is not "now"
    send("C|3|100|0|0|7|1|"..(stamp+5)%3600); eq(N.Main.lastDrop,"new")          -- ahead of our clock: age 0
    send("C|4|200|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"another zone")
    send("C|5|100|0|0|0|1|"..stamp,"Zero"); eq(N.Main.lastDrop,"new")
    hello("Zero",19); send("C|6|100|0|0|0|1|"..stamp,"Zero")
    local z; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.rid=="6" then z=row end end
    eq(z.namespace,"unknown")                                                    -- layer 0 is unknown even at minor 19
    GetServerTime=function() return secret end
    send("C|8|100|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"clock unavailable"); no(N.Main.error)
end)
test("we caps hold under a flood",function()
    local N=loadAddon(); establish(N); advance(1)
    for i=1,400 do advance(.2); report(i%7+1,9,"Sender"..abc(i)) end
    yes(N.Safe.count(N.Main.store.reports)<=64); yes(N.Safe.count(N.Main.store.reports)>0)
    yes(N.Main.receiver.n<=64); yes(N.Safe.count(N.Main.receiver.latest)<=512); yes(N.Main.receiver.nrates<=512)
    yes(#N.Main.candidates()<=40); no(N.Main.error)
end)
test("reports from another server key in our zone are kept apart and labelled",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout-TestRealm",19); report(1,9000,"Scout-TestRealm"); eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].relation,"other"); eq(rows[1].reportLayer,"9000"); eq(rows[1].confidence,"reported, not confirmed")
    report(2,9,"Elsewhere",200); eq(N.Main.lastDrop,"another zone"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(#N.Store.reporters(N.Main.store,clock),1)
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("| other server key 9000")); no(logged("zoneUID")); yes(logged("ask a reporter for an invite: /le hosts"))
    -- before our own server key is known the relation is unknown, never "same"
    N=loadAddon(); advance(1); hello("Other",19); report(1,7086)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].relation,"unknown")
    -- a transfer wipes reports and reporters
    deliver("SHARD_TRANSFER"); drain(); eq(N.Safe.count(N.Main.store.reports),0); eq(#N.Store.reporters(N.Main.store,clock),0)
    -- same instant as the boundary: nothing is stored; later the id is not new any more
    report(2,7); eq(N.Main.lastDrop,"before observation epoch")
    advance(10); report(2,7); eq(N.Main.lastDrop,"duplicate list"); eq(N.Safe.count(N.Main.store.reports),0)
end)
local function hexOf(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
test("we a hello from one realm never vouches for a namesake on another (مانع T3 F1)",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local function wrapped(origin,rid) return "G|"..hexOf(origin).."||C|"..rid.."|100|0.4|0.5|7086|4|"..stamp end
    -- Astra's RELAYER_REALM_COLLISION: Scout-RealmA says hello 19, then relays a C whose origin is Scout-RealmB
    hello("Scout-RealmA",19); deliver("CHAT_MSG_ADDON","WEFF1",wrapped("Scout-RealmB",42),"GUILD","Scout-RealmA")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1)
    eq(rows[1].reporter,"Scout-RealmB"); eq(rows[1].namespace,"unknown"); eq(rows[1].relation,"unknown")
    eq(N.Peers.minor(N.Main.peers,"Scout-RealmB",clock),nil); eq(N.Peers.minor(N.Main.peers,"Scout-RealmA",clock),19)
    -- and the same id from the namesake on realm A is its own report: two rows
    hello("Scout-RealmA",19); report(42,7086,"Scout-RealmA")
    rows=N.Store.rows(N.Main.store,clock,"reported"); local seen={}
    for _,row in ipairs(rows) do seen[row.reporter]=(row.relation) end
    eq(seen["Scout-RealmB"],"unknown"); eq(seen["Scout-RealmA"],"same"); eq(N.Safe.count(N.Main.store.reports),2)
    -- case does not split a reporter
    eq(N.Peers.key("SCOUT-RealmA"),N.Peers.key("scout-realma"))
end)
test("we a wrapper naming its own sender, or us, is refused",function()
    local N=loadAddon(); establish(N); advance(1)
    local c="C|1|100|0.4|0.5|7086|1|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||"..c,"GUILD","Scout"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||"..c,"GUILD","Scout-TestRealm"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","X|"..hexOf("Pal").."|1|"..c,"PARTY","pal"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me-TestRealm").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    eq(N.Safe.count(N.Main.store.reports),0)
    -- a namesake on another realm is not us
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me-FarRealm").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"new")
end)
test("we E, then a boundary, then C of the same id is a new report (مانع T3 S1, accepted)",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    eq(select(2,feed("E|5|1|1|abc:H:60|100","Scout",200)),"held")
    N.Reports.clearPending(t)
    local r,why=feed("C|5|100|0|0|7|1|100","Scout",201); eq(why,"new"); eq(#r.enemies,0); eq(r.heard,201)
    -- through the addon: the E heard before a same-zone transfer does not attach; the C after it is a new row
    N=loadAddon(); establish(N); advance(1); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","E|9|1|1|abc:H:60|"..stamp,"GUILD","Scout"); eq(N.Main.lastDrop,"held")
    deliver("SHARD_TRANSFER"); drain(); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Scout"); eq(N.Main.lastDrop,"new")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].name,"1 not listed")
end)
test("we secret values in any message argument stop the message (مانع T3 S2)",function()
    local stamp
    for i=1,4 do
        local N=loadAddon(); establish(N); advance(1); stamp=math.floor(server)%3600
        local args={"WEFF1","C|1|100|0|0|7|1|"..stamp,"GUILD","Other"}
        args[i]=secret
        N.Main.lastDrop="untouched"; N.Main.lastHeard=nil
        deliver("CHAT_MSG_ADDON",args[1],args[2],args[3],args[4])
        eq(N.Main.lastDrop,"untouched",i); eq(N.Main.lastHeard,nil,i); eq(N.Safe.count(N.Main.store.reports),0,i); no(N.Main.error,i)
        eq(N.Main.receiver.nrates,0,i)
    end
    -- the same message without a secret is read
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"new")
end)
test("we held lists are capped across origins, rate table too (مانع T3 S3)",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local function list(tag,n) local out={}; for j=1,n do out[j]=tag..string.format("%02d",j)..":H:60" end; return table.concat(out,",") end
    -- 18 origins x 18 entries = 324 > 256: the oldest lists make room
    for i=1,18 do eq(select(2,feed("E|1|1|1|"..list(string.char(64+i),18).."|100","Origin"..abc(i),200+i/100)),"held") end
    yes(t.heldAll<=256); eq(t.heldAll,252)
    eq(t.held["origina:1"],nil); eq(t.held["origind:1"],nil); yes(t.held["origine:1"]); yes(t.held["originr:1"])
    local sum=0; for _,h in pairs(t.held) do sum=sum+h.entries end; eq(sum,t.heldAll)
    -- a kept list still attaches; a dropped one does not
    local r=feed("C|1|100|0|0|7|18|100","Originr",202); eq(#r.enemies,18)
    r=feed("C|1|100|0|0|7|18|100","Origina",202); eq(#r.enemies,0)
    eq(t.heldAll,234)
    N.Reports.prune(t,300); eq(t.heldAll,0); eq(next(t.held),nil)
    -- the receive-rate table holds 512 senders at most; the 513th is refused until the window passes
    local u=N.Reports.new()
    for i=1,512 do yes(N.Reports.allow(u,"S"..i,false,0)) end
    no(N.Reports.allow(u,"S513",false,1)); eq(u.nrates,512)
    yes(N.Reports.allow(u,"S513",false,10)); yes(u.nrates<=512)
end)
test("we reports never enter LayerEnemiesDB (مانع T3 S4)",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); report(1,7086,"Scout"); report(2,9000,"Scout"); hello("Relay",19)
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); deliver("CHAT_MSG_ADDON","WEFF1","E|9|1|1|abc:H:60|100","GUILD","Late")
    SlashCmdList.LAYERENEMIES("find Alice"); SlashCmdList.LAYERENEMIES("reports")
    yes(N.Safe.count(N.Main.store.reports)>=2)
    local bad={rid=1,origin=1,via=1,enemies=1,layer=1,heard=1,hash=1,reports=1,peers=1,zone=1,count=1,record=1}
    local function scan(v,path,depth)
        if type(v)=="table" then
            for k,x in pairs(v) do
                no(bad[k],path.."."..tostring(k))
                scan(x,path.."."..tostring(k),depth+1)
            end
        elseif type(v)=="string" then
            no(v:find("Scout",1,true),path); no(v:find("Relay",1,true),path); no(v:find("7086",1,true),path); no(v=="abc",path)
        end
    end
    scan(LayerEnemiesDB,"LayerEnemiesDB",0)
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="call" or k=="callArt" or k=="netNotice" or k=="findShare" or k=="findNotice",k) end; eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("candidates: every source absent",function()
    local N=loadAddon(); establish(N)
    local list,status=N.Main.candidates()
    eq(#list,0); eq(status.bulo,"not installed"); eq(status.book,"not installed"); eq(status.reports,"0 not on your server key")
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("No one to ask right now.")); yes(logged("Your layer: 7086"))
    no(LE.AskInvite("Alice")); yes(logged("not a known friendly player")); eq(#opened,0); no(N.Main.error)
end)
test("candidates: Bulo guild list in wrong shapes is ignored whole",function()
    local N=loadAddon(); local b=friends(N)
    local function status() local list,st=N.Main.candidates(); eq(#list,0); return st.bulo end
    eq(status(),"0 fresh in this zone")
    b.Guild=nil; eq(status(),"data unavailable")
    b.Guild="changed"; eq(status(),"data unavailable")
    b.Guild={}; eq(status(),"data unavailable")
    b.Guild={list="changed"}; eq(status(),"data unavailable")
    b.Guild={list=secret}; eq(status(),"data unavailable")
    b.Guild=secret; eq(status(),"data unavailable")
    b.Guild=setmetatable({},{__index=function() error("foreign") end}); eq(status(),"data unavailable")
    b.Guild={list={Alice=there(),Broken=setmetatable({},{__index=function() error("foreign field") end})}}
    eq(status(),"data unavailable")
    b.Guild={list={Alice="8000",Bob=42,Carl=true,Dora=secret,[7]=there(),[true]=there(),[{}]=there()}}
    eq(status(),"0 fresh in this zone")
    b.Guild={list={Alice={},Bob={key="8000"},Carl={key="8000",zone="100"},Dora={zone="100",at=wall},Erin={key="x",zone="100",at=wall},
        Finn={key="8000",zone="100",at="now"},Gwen={key={},zone={},at={}},Hugo={key="8000-1-2",zone="100",at=wall},Ivan={key="8000",zone="",at=wall}}}
    eq(status(),"0 fresh in this zone")
    BuloLayerForever=secret; local _,st=N.Main.candidates(); eq(st.bulo,"data unavailable")
    BuloLayerForever="changed"; _,st=N.Main.candidates(); eq(st.bulo,"data unavailable"); no(N.Main.error)
end)
test("candidates: Bulo secret, stale, other zone, same layer and self excluded",function()
    local N=loadAddon()
    friends(N,{
        Good=there({at=wall-60}), Edge=there({at=wall-719}), Other=there({other=true,at=wall-30}),
        Stale=there({at=wall-720}), Older=there({at=wall-86400}), Future=there({at=wall+60}),
        Away=there({zone="200"}), ZoneName=there({zone="Elwynn Forest"}), NoZone=there({zone=false}),
        Same=there({key="7086"}), SameFull=there({key="7086-99"}),
        Me=there(), me=there(),
        [secret]=there(), SecretKey=there({key=secret}), SecretZone=there({zone=secret}), SecretAt=there({at=secret}),
        ["Bad  Name"]=there(), ["Bad|Name"]=there(), ["Bad\nName"]=there(), ["/g"]=there(), Digit7=there(), X=there(),
        [string.rep("a",61)]=there(), ["Name-Realm-Extra"]=there(), ["Name-"]=there(),
    })
    local list,status=N.Main.candidates()
    eq(names(list),"Other,Good,Edge"); eq(status.bulo,"5 fresh in this zone")
    eq(list[1].layer,"8000"); eq(list[1].age,30); eq(list[1].sources[1],"Bulo"); eq(#list[1].sources,1); no(list[1].host)
    eq(list[3].age,719); no(N.Main.error)
    -- Without a known own layer (0.3.1): the host is listed, marked, so a player without a layer addon sees it;
    -- no hop or ask goes through such a row (the 0.3.1 T3 tests).
    N=loadAddon(); local b=fakeBulo(nil); b.Guild={list={Good=there()}}; N.Main.poll()
    list,status=N.Main.candidates(); eq(names(list),"Good"); yes(list[1].unknownOwn); eq(status.bulo,"1 fresh in this zone (your layer is not known yet)")
    -- Unknown own zone or own name: same.
    N=loadAddon(); friends(N,{Good=there()}); eq(#N.Main.candidates(),1)
    UnitName=function() return secret end; list,status=N.Main.candidates(); eq(#list,0); eq(status.bulo,"own name unreadable")
    UnitName=function() return "Me","Test Realm" end; time=function() return secret end
    list,status=N.Main.candidates(); eq(#list,0); eq(status.bulo,"clock or zone unavailable")
    time=nil; eq(#N.Main.candidates(),0); no(N.Main.error)
end)
test("candidates: LayerSwap book absent, wrong shape, stale, gone, zone, same layer",function()
    local N=loadAddon(); establish(N)
    local function status() local list,st=N.Main.candidates(); eq(#list,0); return st.book end
    eq(status(),"not installed")
    LayerSwapDB="changed"; eq(status(),"data unavailable")
    LayerSwapDB=secret; eq(status(),"data unavailable")
    LayerSwapDB={}; eq(status(),"0 fresh in this zone")
    LayerSwapDB={book="changed"}; eq(status(),"data unavailable")
    LayerSwapDB={book=secret}; eq(status(),"data unavailable")
    LayerSwapDB=setmetatable({},{__index=function() error("foreign") end}); eq(status(),"data unavailable")
    LayerSwapDB={book={Alice=page(),Broken=setmetatable({},{__index=function() error("foreign field") end})}}
    eq(status(),"data unavailable")
    LayerSwapDB={book={Alice="8000-13",Bob=1,[1]=page(),Carl={},Dora={layer="8000-13"},Erin={layer="8000-13",zone="100"},Finn={layer="garbage",zone="100",at=wall}}}
    eq(status(),"0 fresh in this zone")
    LayerSwapDB={book={
        Fresh=page({at=wall-100}), Host=page({host=true,at=wall-600}), Edge=page({at=wall-899}), Numeric=page({zone=100,layer="9000-4",at=wall-200}),
        Stale=page({at=wall-900}), Week=page({at=wall-6*86400,host=true}), Future=page({at=wall+30}),
        Gone=page({gone=wall-5}), GoneSecret=page({gone=secret}), Away=page({zone="200"}), NoZone=page({zone=false}),
        Same=page({layer="7086-7"}), SameOtherZone=page({layer="7086-55"}), Me=page(),
        [secret]=page(), SecretLayer=page({layer=secret}), SecretAt=page({at=secret}), SecretZone=page({zone=secret}),
        ["Bad  Name"]=page(), ["Bad|Name"]=page(),
    }}
    local list,st=N.Main.candidates()
    -- hosts first, then newest
    eq(names(list),"Host,Fresh,Numeric,Edge"); eq(st.book,"6 fresh in this zone")
    yes(list[1].host); eq(list[1].layer,"8000"); eq(list[1].sources[1],"LayerSwap"); eq(list[3].layer,"9000"); eq(list[4].age,899)
    -- nothing was written to the foreign table
    eq(N.Safe.count(LayerSwapDB.book),20); eq(LayerSwapDB.book.Stale.at,wall-900); eq(LayerSwapDB.book.Gone.gone,wall-5); no(N.Main.error)
end)
test("candidates: host preference and one row per name across sources",function()
    local N=loadAddon(); warSettings()
    friends(N,{
        Alice=there({at=wall-100}),                 -- same claim in both lists
        Bob=there({at=wall-300}),                   -- LayerSwap has a fresher, different claim
        Carl=there({at=wall-300}),                  -- LayerSwap says: now on our layer
        Dora=there({key="7086",at=wall-10}),        -- Bulo says: on our layer, fresher than the book
        Erin=there({host=true,at=wall-500}),
        Finn=there({at=wall-5}),
    },{
        Alice=page({layer="8000-3",host=true,at=wall-50}),
        Bob=page({layer="9000-1",at=wall-20}),
        Carl=page({layer="7086-7",at=wall-10}),
        Dora=page({layer="8000-3",at=wall-300}),
        alice=page({layer="8000-3",at=wall-700}),   -- same player, other capitalisation
    })
    local list=N.Main.candidates()
    eq(names(list),"Alice,Erin,Finn,Bob")
    -- freshest source first
    eq(list[1].age,50); yes(list[1].host); eq(table.concat(list[1].sources,"+"),"LayerSwap+Bulo")
    eq(list[4].layer,"9000"); eq(table.concat(list[4].sources,"+"),"LayerSwap"); eq(list[4].age,20)
    -- A War Effort reporter on another server key goes first and merges by name.
    units.target={guid=npc(1),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.zoneUID,7)
    for _,who in ipairs({"Bob-TestRealm","Zed-TestRealm","Sam","Carl"}) do hello(who,19) end
    report(1,9,"Bob-TestRealm"); report(2,9,"Zed-TestRealm"); report(3,7086,"Sam"); report(4,9,"Carl"); report(5,9,"Me-TestRealm")
    advance(2); report(6,9,"Zed-TestRealm")
    list=N.Main.candidates()
    eq(names(list),"Zed-TestRealm,Bob,Alice,Erin,Finn")
    yes(list[1].reporter); eq(list[1].layer,nil); eq(table.concat(list[1].sources,"+"),"War Effort"); eq(list[1].age,0)
    yes(list[2].reporter); eq(list[2].layer,"9000"); eq(table.concat(list[2].sources,"+"),"LayerSwap+War Effort")
    no(list[3].reporter)
end)
test("candidates: huge foreign lists stay bounded",function()
    local N=loadAddon(); local list={}
    local letters="abcdefghijklmnopqrstuvwxyz"
    for i=1,3000 do
        local a,b,c=i%26+1,math.floor(i/26)%26+1,math.floor(i/676)%26+1
        list["P"..letters:sub(a,a)..letters:sub(b,b)..letters:sub(c,c)]=there({at=wall-(i%700)})
    end
    friends(N,list)
    local out=N.Main.candidates(); yes(#out<=40); yes(#out>0); no(N.Main.error)
end)
test("ask: chat box opened one frame later with the exact line, never sent",function()
    local N=loadAddon(); friends(N,{Alice=there({host=true})}); chatBox()
    yes(LE==N); yes(LE.AskInvite("Alice")); eq(#opened,0)
    drain(); eq(#opened,1)
    eq(opened[1].text,"/w Alice Hi! Could you invite me to your layer please?")
    eq(opened[1].text,"/w Alice "..ASK); eq(opened[1].frame,DEFAULT_CHAT_FRAME)
    yes(logged("a whisper to Alice is in your chat box - press Enter to send it.")); eq(forbidden,0)
    -- case-insensitive lookup still whispers the listed spelling
    advance(60); yes(LE.AskInvite("alice")); drain(); eq(opened[2].text,"/w Alice "..ASK)
end)
test("ask: ChatFrame_OpenChat route and every print fallback",function()
    local N=loadAddon(); friends(N,{Alice=there(),Bob=there(),Carl=there(),Dora=there(),Erin=there()})
    ChatFrame_OpenChat=function(text,frame) opened[#opened+1]={text=text,frame=frame,legacy=true} end
    yes(LE.AskInvite("Alice")); drain(); eq(#opened,1); yes(opened[1].legacy); eq(opened[1].text,"/w Alice "..ASK)
    -- unusable ChatFrameUtil falls through to the legacy global
    advance(10); ChatFrameUtil=setmetatable({},{__index=function() error("changed") end})
    yes(LE.AskInvite("Bob")); drain(); eq(#opened,2); eq(opened[2].text,"/w Bob "..ASK)
    advance(10); ChatFrameUtil={OpenChat=secret}
    yes(LE.AskInvite("Carl")); drain(); eq(#opened,3)
    -- neither function: the line is printed to copy
    advance(10); ChatFrameUtil=nil; ChatFrame_OpenChat=nil
    yes(LE.AskInvite("Dora")); drain(); eq(#opened,3)
    yes(logged("type or copy this line to ask Dora:")); eq(log[#log],"/w Dora "..ASK)
    -- the open call throws: printed afterwards
    advance(10); ChatFrameUtil={OpenChat=function() error("blocked") end}
    yes(LE.AskInvite("Erin")); drain(); yes(logged("the chat box did not open")); eq(log[#log],"/w Erin "..ASK)
    -- no timer: printed at once
    advance(60); C_Timer=nil; chatBox()
    yes(LE.AskInvite("Alice")); eq(#opened,3); eq(log[#log],"/w Alice "..ASK); eq(forbidden,0)
end)
test("ask: 60 s per name and one ask per 10 s overall",function()
    local N=loadAddon(); friends(N,{Alice=there(),Bob=there(),Carl=there()}); chatBox()
    yes(LE.AskInvite("Alice")); drain(); eq(#opened,1)
    no(LE.AskInvite("Alice")); yes(logged("Alice was asked 0 s ago; wait 60 s."))
    no(LE.AskInvite("Bob")); yes(logged("one ask every 10 s; wait 10 s."))
    advance(9.5); no(LE.AskInvite("Bob")); drain(); eq(#opened,1)
    advance(.5); yes(LE.AskInvite("Bob")); drain(); eq(#opened,2)
    advance(49.5); no(LE.AskInvite("Alice")); yes(logged("Alice was asked 59 s ago; wait 1 s."))
    advance(.5); yes(LE.AskInvite("Alice")); drain(); eq(#opened,3)
    no(LE.AskInvite("Bob")); yes(logged("Bob was asked 50 s ago; wait 10 s."))
    no(LE.AskInvite("Carl")); eq(lines("one ask every 10 s"),3)
    advance(10); yes(LE.AskInvite("Carl")); drain(); eq(#opened,4)
    -- a refused ask reserves nothing, and expired names are dropped
    eq(N.Safe.count(N.Main.invite.asked),2); eq(N.Main.invite.asked.bob,nil); eq(forbidden,0)
end)
test("ask: only listed, readable, ungrouped targets",function()
    local N=loadAddon(); friends(N,{Alice=there(),Same=there({key="7086"}),Away=there({zone="200"})}); chatBox()
    for _,bad in ipairs({"Nobody","Same","Away","Me","","Alice Smith","Alice|r","Alice\n/g hi","/g hi",42,{},true}) do no(LE.AskInvite(bad)) end
    no(LE.AskInvite(secret)); no(LE.AskInvite(nil)); yes(logged("that player name is not readable."))
    grouped=true; no(LE.AskInvite("Alice")); yes(logged("leave your current group first"))
    -- an unreadable group state counts as grouped (مانع T5 S1)
    IsInGroup=function() return secret end; no(LE.AskInvite("Alice")); yes(logged("leave your current group first"))
    drain(); eq(#opened,0); eq(N.Safe.count(N.Main.invite.asked),0); no(N.Main.error); eq(forbidden,0)
end)
test("/le hosts numbers the candidates and /le ask <n> asks one",function()
    local N=loadAddon(); warSettings()
    friends(N,{Alice=there({at=wall-90}),Bob=there({host=true,at=wall-200})},{Cora=page({layer="9000-2",at=wall-30})})
    chatBox()
    SlashCmdList.LAYERENEMIES("ask 1"); yes(logged("run /le hosts first")); eq(#opened,0)
    advance(1); report(1,9,"Scout")
    SlashCmdList.LAYERENEMIES("hosts")
    yes(logged("1. Scout | layer unknown - saw reported enemies | War Effort | 0 s ago"))
    yes(logged("2. Bob | layer 8000 | Bulo | host | 3 min ago"))
    yes(logged("3. Cora | layer 9000 | LayerSwap | 31 s ago"))
    yes(logged("4. Alice | layer 8000 | Bulo | 1 min ago"))
    yes(logged("Bulo: 2 fresh in this zone / LayerSwap: 1 fresh in this zone / War Effort reporters: 1 not on your server key"))
    SlashCmdList.LAYERENEMIES("ask 9"); yes(logged("no such number")); SlashCmdList.LAYERENEMIES("ask"); SlashCmdList.LAYERENEMIES("ask x")
    drain(); eq(#opened,0)
    SlashCmdList.LAYERENEMIES(" ASK 2 "); drain(); eq(#opened,1); eq(opened[1].text,"/w Bob "..ASK)
    advance(10); SlashCmdList.LAYERENEMIES("ask 1"); drain(); eq(opened[2].text,"/w Scout "..ASK)
    advance(121); SlashCmdList.LAYERENEMIES("ask 3"); drain(); eq(#opened,2); eq(lines("run /le hosts first"),2)
    no(N.Main.error); eq(forbidden,0)
end)
test("after join: confirmed layer change is announced once (Bulo)",function()
    local N=loadAddon(); local b=friends(N,{Alice=there({host=true})}); chatBox()
    yes(LE.AskInvite("Alice")); drain()
    deliver("GROUP_ROSTER_UPDATE"); eq(N.Main.invite.watch,nil)       -- not grouped yet
    advance(20); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    yes(logged("you joined a group after asking - checking your layer for 60 s.")); yes(N.Main.invite.watch)
    advance(5); no(logged("Moved to layer"))
    b.current="8000-7"; b:Fire("LFS_LAYER",b.current); drain()
    yes(logged("LayerEnemies: Moved to layer 8000. Whether leaving the group keeps you there is not confirmed - stay grouped if unsure.")); eq(N.Main.invite.watch,nil)
    eq(lines("safe to leave"),0)
    advance(120); deliver("GROUP_ROSTER_UPDATE")
    eq(lines("Moved to layer"),1); eq(lines("Still on your layer"),0); no(logged("was listed on layer"))
    yes(grouped); eq(forbidden,0); no(N.Main.error)
end)
test("after join: change confirmed by two NPC kinds; other layer than listed is said",function()
    local N=loadAddon(); establish(N); LayerSwapDB={book={Alice=page({host=true})}}; chatBox()
    yes(LE.AskInvite("Alice")); drain(); grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    deliver("SHARD_TRANSFER"); drain(); eq(N.Main.store.bulo,nil)
    units.target={guid=npc(3,9,"9000"),player=false}; advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    no(logged("Moved to layer"))                                      -- one NPC is not confirmation
    units.mouseover={guid=npc(4,9,"9000"),player=false}; advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"9000-9")
    yes(logged("LayerEnemies: Moved to layer 9000. Whether leaving the group keeps you there is not confirmed - stay grouped if unsure."))
    yes(logged("LayerEnemies: Alice was listed on layer 8000, not 9000.")); eq(forbidden,0)
end)
test("after join: unchanged after 60 s says so once; nothing is left for the user",function()
    local N=loadAddon(); friends(N,{Alice=there()}); chatBox()
    yes(LE.AskInvite("Alice")); drain(); advance(3); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    advance(59); eq(lines("Still on your layer"),0)
    advance(2); yes(logged("LayerEnemies: Still on your layer - leave, wait a minute, try again."))
    advance(300); deliver("GROUP_ROSTER_UPDATE"); eq(lines("Still on your layer"),1); eq(lines("Moved to layer"),0)
    yes(grouped); eq(forbidden,0); eq(N.Main.invite.watch,nil)
    -- same key with another zone suffix is still the same layer
    N=loadAddon(); local b=friends(N,{Alice=there()}); yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    b.current="7086-55"; b:Fire("LFS_RAW",b.current); drain(); advance(61)
    eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),1)
end)
test("after join: no ask, late join, unknown layer and zone change",function()
    local N=loadAddon(); friends(N,{Alice=there()}); chatBox()
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(70); eq(N.Main.invite.watch,nil); eq(lines("Still on your layer"),0)
    grouped=false; deliver("GROUP_ROSTER_UPDATE")
    yes(LE.AskInvite("Alice")); advance(301); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    eq(N.Main.invite.watch,nil); eq(N.Main.invite.pending,nil); advance(70); eq(lines("Still on your layer"),0)
    -- layer never confirmed again: one hint, then the check ends without a claim
    N=loadAddon(); establish(N); LayerSwapDB={book={Alice=page()}}
    yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); deliver("SHARD_TRANSFER"); drain()
    advance(61); eq(lines("Layer not confirmed yet - target or mouse over two different kinds of NPC."),1)
    advance(60); eq(lines("Layer not confirmed yet"),1); advance(65); eq(lines("Layer check ended - your layer could not be confirmed."),1)
    eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); eq(N.Main.invite.watch,nil)
    -- zone change cancels
    N=loadAddon(); friends(N,{Alice=there()}); yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); advance(61)
    eq(lines("Zone changed - layer check cancelled."),1); eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); eq(forbidden,0)
end)
test("ask from a War Effort report: reporter is the target, own layer unknown",function()
    local N=loadAddon(); warSettings(); chatBox(); advance(1)
    report(1,9,"Scout-TestRealm")
    local list=N.Main.candidates(); eq(names(list),"Scout-TestRealm"); yes(list[1].reporter)
    yes(LE.AskInvite("Scout-TestRealm")); drain(); eq(opened[1].text,"/w Scout-TestRealm "..ASK)
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    units.target={guid=npc(1,9,"8000"),player=false}; advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    units.mouseover={guid=npc(2,9,"8000"),player=false}; advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    yes(logged("Now on layer 8000 - your earlier layer was not known, so a move is not confirmed."))
    eq(lines("Moved to layer"),0); eq(forbidden,0)
    -- an ignored reporter is never offered
    N=loadAddon(); clientIgnored=true; advance(1); report(1,9,"Scout-TestRealm")
    eq(#N.Main.candidates(),0)
end)
test("addon never chats, invites, accepts, leaves or joins; sends only through Wire",function()
    local N=loadAddon(); warSettings(); local b=friends(N,{Alice=there(),Bob=there({key="9000"})},{Cora=page()}); chatBox()
    advance(1); report(1,9,"Scout")
    SlashCmdList.LAYERENEMIES("hosts"); SlashCmdList.LAYERENEMIES("ask 1"); drain()
    advance(10); LE.AskInvite("Alice"); drain(); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    b.current="8000-7"; b:Fire("LFS_LAYER",b.current); drain(); advance(70)
    grouped=false; deliver("GROUP_ROSTER_UPDATE"); advance(10); LE.AskInvite("Bob"); drain()
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(70)
    eq(forbidden,0); eq(#opened,3); yes(grouped); no(N.Main.error)
    for _,file in ipairs(addonFiles()) do
        local f=assert(io.open("LayerEnemies/"..file..".lua")); local text=f:read("*a"); f:close()
        for _,word in ipairs({"SendChatMessage","RunMacroText","JoinChannel","UninviteUnit","ConfirmInviteUnit","ConvertToRaid","DeclineGroup","RequestInviteFromUnit","ConfirmLeaveParty"}) do
            -- 1.0 T3: Directory.lua joins its two channels (checked in the T3 tests)
            if not (file=="Directory" and word=="JoinChannel") then eq(text:find(word,1,true),nil,file.." mentions "..word) end
        end
        -- InviteUnit and C_PartyInfo: exactly once each, in Wire.lua only
        local function count(word) local n=0; for _ in text:gmatch("%f[%w_]"..word.."%f[^%w_]") do n=n+1 end; return n end
        eq(count("InviteUnit"),file=="Wire" and 1 or 0,file.." InviteUnit count"); eq(count("AcceptGroup"),file=="Wire" and 1 or 0,file.." AcceptGroup count"); eq(count("LeaveParty"),file=="Wire" and 1 or 0,file.." LeaveParty count"); eq(count("C_PartyInfo"),file=="Wire" and 1 or 0,file.." C_PartyInfo count")
        -- SendAddonMessage only in Wire.lua
        if file=="Wire" then yes(text:find("SendAddonMessage",1,true),"Wire sends")
        else eq(text:find("SendAddonMessage",1,true),nil,file.." mentions SendAddonMessage") end
    end
    eq(#sent,0)
    -- the only registered events are passive
    -- 0.4.0 Task 8: PARTY_INVITE_REQUEST is read (auto-accept of the asked host only); no other invite event
    for event in pairs(frames[1].events) do no(event:find("PARTY_INVITE",1,true) and event~="PARTY_INVITE_REQUEST",event) end
    yes(frames[1].events.GROUP_ROSTER_UPDATE); eq(frames[1].scripts.OnUpdate,nil); eq(#frames,20)
    eq(LayerEnemiesDB.asked,nil); eq(LayerEnemiesDB.invite,nil)
end)
test("Find fold: Latin and Cyrillic tables, exclusions and unchanged UTF-8",function()
    local N=loadAddon(); local F=N.Find
    eq(type(F.fold),"function","Find has a pure folding helper")
    local vectors={
        {"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"},
        {"ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ","àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ"},
        {"ĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮĲĴĶ","āăąćĉċčďđēĕėęěĝğġģĥħĩīĭįĳĵķ"},
        {"ĹĻĽĿŁŃŅŇ","ĺļľŀłńņň"},
        {"ŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶ","ŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷ"},
        {"ŸŹŻŽ","ÿźżž"},
        {"АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ","абвгдежзийклмнопрстуфхцчшщъыьэюя"},
        {"ЀЁЂЃЄЅІЇЈЉЊЋЌЍЎЏ","ѐёђѓєѕіїјљњћќѝўџ"},
        {"×÷İıĸŉſßµ","×÷İıĸŉſßµ"},
        {"ΑΩαωԱա Georgian Ⴀა 漢字 Ａａ","ΑΩαωԱա georgian Ⴀა 漢字 Ａａ"},
        {"A-é Élodie Łukasz Ёлка","a-é élodie łukasz ёлка"},
    }
    for _,v in ipairs(vectors) do
        eq(F.fold(v[1]),v[2],v[1]); eq(F.fold(v[2]),v[2],"idempotent "..v[2])
    end
    eq(F.fold(""),""); eq(select("#",F.fold("Élodie")),1,"one return, not gsub's count")
end)
test("Find fold: lone continuation and truncated UTF-8 tails are byte-preserved",function()
    local F=loadAddon().Find
    for _,v in ipairs({{string.char(128),string.char(128)},
        {"ÉA"..string.char(195),"éa"..string.char(195)},
        {"ŁZ"..string.char(226,130),"łz"..string.char(226,130)}}) do
        eq(F.fold(v[1]),v[2],"fold complete letters without consuming an incomplete sequence")
        eq(F.fold(v[2]),v[2],"malformed bytes remain stable on another fold")
    end
end)

-- Synthetic Find fixtures, shared across sighting and wire paths.
do
    local cases={
        {"élodie","Élodie"},{"ÉLODIE","Élodie"},{"Élodie","Élodie"},
        {"ZOÉ","Zoé"},{"zoé","Zoé"},
        {"ялора","Ялора"},{"ЯЛОРА","Ялора"},{"ёлва","Ёлва"},
        {"łukasz","Łukasz"},{"ŁUKASZ","Łukasz"},
        {"ÿlune","Ÿlune"},{"ĺava","Ĺava"},{"źora","Źora"},
        {"mira élune","Mira Élune"},{"MIRA ÉLUNE","Mira Élune"},{"élodie łava","Élodie Łava"},
        {"cedar vale","Cedar Vale"},{"CEDAR VALE","Cedar Vale"},
        {"élodie-TestRealm","Élodie"},
    }
    for _,v in ipairs(cases) do
        test("Find casefold own: "..v[1],function()
            local N=loadAddon(); local F=N.Find; local st=F.new(); yes(F.add(st,v[1]))
            local given,surname=v[2]:match("^([^ ]+) (.+)$")
            F.own(st,{name=given or v[2],displayName=given and v[2],realm=surname or "Test Realm",
                faction="opposite",source="own target",class="MAGE",level=39,layer="7086-7"},100,50)
            local row=F.rows(st,50,100)[1]
            yes(row.own,"own sighting matched"); yes(row.same); no(row.possible); no(row.canAsk)
            eq(row.name,v[1],"keep typed spelling"); eq(row.zone,100); eq(row.at,50)
            eq(row.class,"MAGE"); eq(row.level,39); eq(#sent,0)
        end)
        test("Find casefold named: "..v[1],function()
            local N=loadAddon(); local F=N.Find
            for _,relayed in ipairs({false,true}) do
                local st=F.new(); yes(F.add(st,v[1]))
                F.report(st,{sender="Scout",zone=100,at=50,relayed=relayed,
                    enemies={{name=v[2],class="MAGE",level=39}}},"Test Realm")
                local row=F.rows(st,50,100)[1]
                yes(row.possible,"named report matched"); no(row.own); no(row.same)
                eq(row.canAsk,not relayed); eq(row.relayed,relayed); eq(row.name,v[1]); eq(row.spotter,"Scout")
                eq(row.zone,100); eq(row.at,50); eq(row.class,"MAGE"); eq(row.level,39)
            end
            eq(#sent,0)
        end)
        test("Find casefold hash: "..v[1],function()
            local N=loadAddon(); local F,H=N.Find,N.Hash
            local hashes={H.player(v[2],"Test Realm"),H.player(v[2],"")}
            local given,surname=v[2]:match("^([^ ]+) (.+)$")
            if given then hashes[#hashes+1]=H.player(given,surname) end
            for _,hash in ipairs(hashes) do
                local st=F.new(); yes(F.add(st,v[1]))
                F.report(st,{sender="Scout",zone=100,at=50,enemies={{hash=hash,class="MAGE",level=39}}},"Test Realm")
                local row=F.rows(st,50,100)[1]
                yes(row.possible,"hash-only report matched "..hash); no(row.own); no(row.same); yes(row.canAsk)
                eq(row.name,v[1]); eq(row.spotter,"Scout"); eq(row.zone,100); eq(row.at,50)
                eq(row.class,"MAGE"); eq(row.level,39)
            end
            eq(#sent,0)
        end)
    end
end

test("Find casefold key: trim display, fold single and full names, keep validation",function()
    local N=loadAddon(); local F=N.Find
    local name,key=F.name("  ÉLODIE  "); eq(name,"ÉLODIE"); eq(key,"élodie")
    name,key=F.name("  ÉLODIE ŁAVA  "); eq(name,"ÉLODIE ŁAVA"); eq(key,"élodie łava")
    name,key=F.name("ÉLODIE-ÉLUNE"); eq(name,"ÉLODIE-ÉLUNE"); eq(key,"élodie-élune")
    for _,bad in ipairs({false,secret,42,"/g Élodie","Élodie|r","Élodie2","One Two Three"}) do no(F.name(bad)) end
end)
test("Find casefold add: duplicate spelling preserves one entry and session state",function()
    local N=loadAddon(); local F=N.Find
    for _,v in ipairs({{"Élodie","élodie"},{"Zoé","ZOÉ"},{"Łukasz","łukasz"},{"Ялора","ялора"},{"Mira Élune","MIRA ÉLUNE"}}) do
        local st=F.new(); yes(F.add(st,v[1]))
        local loc,alert={at=50,zone=100},{at=50,zone=100}; st.locations[v[1]]=loc; st.alerts[v[1]]=alert
        yes(F.add(st,v[2])); eq(#st.names,1); eq(st.names[1],v[1]); eq(st.locations[v[1]],loc); eq(st.alerts[v[1]],alert)
        local saved=F.new({v[1],v[2]}); eq(#saved.names,1); eq(saved.names[1],v[1])
    end
    local st=F.new({"Élodie","Cedar","Birch","Linden","Rowan"})
    for i=6,F.MAX do yes(F.add(st,"Seeker "..abc(i))) end
    yes(F.add(st,"élodie")); eq(#st.names,F.MAX)
end)

test("Find casefold hash candidates: given, folded and Titlecase spellings per part, bounded and wire unchanged",function()
    local N=loadAddon(); local F,H=N.Find,N.Hash
    eq(H.nameKey("ÉLODIE","ŁAVA"),"Élodie-Łava","wire still lowers ASCII only")
    local function exact(name,home,parts)
        local want,got={},F.hashes(name,home)
        for _,v in ipairs(parts) do want[H.player(v[1],v[2])]=true end
        for h in pairs(want) do yes(got[h],"missing candidate "..h) end
        for h in pairs(got) do yes(want[h],"unexpected candidate "..h) end
    end
    exact("ÉLODIE ŁAVA","ÉLUNE ŁAND",{
        {"ÉLODIE ŁAVA","ÉLUNE ŁAND"},{"ÉLODIE ŁAVA",""},{"ÉLODIE","ŁAVA"},
        {"élodie łava","élune łand"},{"Élodie Łava","Élune Łand"},
        {"élodie łava",""},{"Élodie Łava",""},{"élodie","łava"},{"Élodie","Łava"},
    })
    exact("ÉLODIE-ŁAVA","Other Realm",{
        {"ÉLODIE","ŁAVA"},{"ÉLODIE",""},
        {"élodie","łava"},{"Élodie","Łava"},{"élodie",""},{"Élodie",""},
    })
    exact("ÉLODIE",nil,{{"ÉLODIE",""},{"élodie",""},{"Élodie",""}})
    exact("ALICE","Test Realm",{{"Alice","Test Realm"},{"Alice",""}})
    -- No global folding of hash inputs, and no titlecasing of unsupported three-byte letters.
    exact("Ⴀlune",nil,{{"Ⴀlune",""}})
end)

test("Find casefold keeps the spelling as given: mixed-case realm from the game or typed exactly still matches",function()
    local N=loadAddon(); local F,H=N.Find,N.Hash
    -- neither all lower nor per-word Titlecase: the folded and Titlecase candidates alone both miss it
    local realm="Ревущий фьорд"
    local h=H.player("Alice",realm)
    no(H.player("Alice",F.fold(realm))==h and true or nil,"fixture: folded spelling hashes differently")
    yes(F.hashes("Alice",realm)[h],"home realm as the game supplies it")
    local st=F.new({"Alice"})
    F.report(st,{sender="Scout",at=10,zone=100,enemies={{hash=h}}},realm)
    yes(st.locations.Alice,"report matched through the home realm")
    yes(F.hashes("Alice-"..realm,"Other")[h],"Name-Realm typed exactly")
    h=H.player("Ana","MacRealm")
    yes(F.hashes("Ana-MacRealm",nil)[h],"interior capital typed exactly")
    -- a home that is not a string is treated as no realm, as on the base commit
    local ok,out=pcall(F.hashes,"Alice",{})
    yes(ok,"non-string home does not throw"); yes(out and out[H.player("Alice","")],"falls back to the realm-less key")
end)
test("Find casefold remove: other case clears stored location and alert, not a neighbour",function()
    local N=loadAddon(); local F=N.Find
    for _,v in ipairs({{"Élodie","élodie"},{"Zoé","ZOÉ"},{"Łukasz","łukasz"},{"Ялора","ялора"},
        {"Mira Élune","MIRA ÉLUNE"},{"Cedar","CEDAR"}}) do
        for i=1,2 do
            local stored,typed=v[i],v[3-i]
            local st=F.new({stored,"Linden"})
            local loc,alert={at=50,zone=100},{at=50,zone=100}
            st.locations[stored]=loc; st.alerts[stored]=alert
            st.locations.Linden=loc; st.alerts.Linden=alert
            F.remove(st,"Unknown"); eq(#st.names,2); eq(st.locations[stored],loc); eq(st.alerts[stored],alert)
            F.remove(st,typed)
            eq(#st.names,1); eq(st.names[1],"Linden"); eq(st.locations[stored],nil); eq(st.alerts[stored],nil)
            eq(st.locations.Linden,loc); eq(st.alerts.Linden,alert)
            F.remove(st,nil); eq(#st.names,0); eq(next(st.locations),nil); eq(next(st.alerts),nil)
        end
    end
    -- Backward iteration also clears duplicate spellings left in an old session.
    local st=F.new(); st.names={"Élodie","élodie"}
    for _,name in ipairs(st.names) do st.locations[name]={}; st.alerts[name]={} end
    F.remove(st,"ÉLODIE"); eq(#st.names,0); eq(next(st.locations),nil); eq(next(st.alerts),nil)
end)

test("Find hashes mirror upstream realm, realm-less and Forever surname keys",function()
    local N=loadAddon(); local H=N.Hash
    eq(H.nameKey("Alice","Test Realm"),"alice-testrealm"); eq(H.nameKey("Alice",""),"alice-")
    eq(H.hash3("alice-testrealm"),"Zzm"); eq(H.hash3("alice-"),"YNz")
    local hashes=N.Find.hashes("Alice", "Test Realm")
    yes(hashes[H.player("Alice","Test Realm")]); yes(hashes[H.player("Alice","")])
    hashes=N.Find.hashes("First Surname", "Forever")
    yes(hashes[H.player("First","Surname")]); yes(hashes[H.player("First Surname","")])
end)
test("Find match, no match, collisions, expiry, own sighting and alerts",function()
    local N=loadAddon(); local F=N.Find; local st=F.new({"Alice","Bob"})
    local function feed(hash,at,zone) F.report(st,{sender="Scout",zone=zone or 100,at=at,enemies={{hash=hash,class="MAGE",level=40}}},"Test Realm") end
    feed("xxx",10); no(F.rows(st,10,100)[1].at)
    feed(N.Hash.player("Alice",""),11)
    local r=F.rows(st,11,100)[1]; yes(r.possible); yes(r.canAsk); eq(r.spotter,"Scout"); eq(r.class,"MAGE"); eq(r.level,40)
    yes(F.alert(st,r,11)); no(F.alert(st,r,310)); yes(F.alert(st,r,311))
    feed(N.Hash.player("Alice",""),312,200); r=F.rows(st,312,100)[1]; yes(r.travel); no(r.canAsk); yes(F.alert(st,r,312))
    no(F.rows(st,912,100)[1].at)
    F.own(st,{name="Alice",faction="same",source="own target"},100,913); no(st.locations.Alice)
    F.own(st,{name="Alice",faction="opposite",source="own target"},100,913)
    r=F.rows(st,913,100)[1]; yes(r.own); no(r.same); no(r.canAsk); eq(r.status,"seen by you, layer unknown")
    F.own(st,{name="Alice",faction="opposite",source="own target",layer="7086-7"},100,913)
    r=F.rows(st,913,100)[1]; yes(r.own); yes(r.same); no(r.canAsk); eq(r.status,"is on YOUR layer")
    F.boundary(st); yes(st.locations.Alice); no(F.rows(st,913,100)[1].same); eq(#st.names,2)
    -- A genuine three-character collision must remain possible, never confirmed.
    local a,b="PFKMEclrzj","CuhFVPbgzA"
    eq(N.Hash.player(a,""),"Y8Y"); eq(N.Hash.player(b,""),"Y8Y")
    st=F.new({a,b})
    feed(N.Hash.player(a,""),1000)
    local rows=F.rows(st,1000,100); yes(rows[1].possible); yes(rows[2].possible)
end)
test("Find integration: cross-zone privacy gate, same layer and persistence",function()
    local N=loadAddon(); warSettings(); establish(N); chatBox()
    SlashCmdList.LAYERENEMIES("find Alice")
    local hash=N.Hash.player("Alice","")
    advance(1)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|61|200|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|61|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    local row=N.Main.findRows()[1]; yes(row.possible); yes(row.travel)
    no(LE.AskInvite("Scout")); yes(logged("travel to Durotar first")); eq(#opened,0)
    clientIgnored=true
    deliver("CHAT_MSG_ADDON","WEFF1","C|62|100|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|62|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    eq(N.Main.findRows()[1].zone,200)
    clientIgnored=false
    advance(1); stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|63|100|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|63|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    yes(N.Main.findRows()[1].canAsk); yes(LE.AskInvite("Scout")); drain(); eq(#opened,1)
    friends(N,{Scout=there({key="7086"})})
    yes(N.Main.findRows()[1].same); no(N.Main.findRows()[1].canAsk)
    local saved=LayerEnemiesDB
    N.Main.started=false; N.Main.start(); eq(N.Main.find.names[1],"Alice"); no(N.Main.find.locations.Alice)
    eq(saved.tracked[1],"Alice"); eq(LayerEnemiesDB.sightings,nil)
    SlashCmdList.LAYERENEMIES("find"); eq(#LayerEnemiesDB.tracked,0)
end)
test("Find cap, validation, remove, alert sound and own name with surname",function()
    local N=loadAddon(); local F=N.Find; local st=F.new({"Alice","Alice","Bob"})
    eq(#st.names,2)
    for _,name in ipairs({"Cora","Dave","Ellie"}) do yes(F.add(st,name)) end
    for i=#st.names+1,F.MAX do yes(F.add(st,"Seeker "..abc(i))) end
    no(F.add(st,"Frank")); no(F.add(st,secret)); no(F.add(st,"Alice|r")); no(F.add(st,"/g inject"))
    F.remove(st,"Bob"); yes(F.add(st,"First Surname"))
    local sounds=0; PlaySound=function() sounds=sounds+1 end
    N.Main.track("First Surname"); advance(1)
    units.target=player("First","Horde"); units.target.realm="Surname"
    deliver("PLAYER_TARGET_CHANGED"); drain()
    yes(N.Main.findRows()[1].own); eq(sounds,1); N.Main.findAlerts(); eq(sounds,1)
    advance(300); N.Main.findAlerts(); eq(sounds,2); PlaySound=nil
end)
test("UI starts hidden, toggles with /le, paints ages only while shown",function()
    local N=loadAddon(); local U=N.UI
    no(U.frame:IsShown()); eq(#U.pool,0)
    for _,f in ipairs(frames) do eq(f.scripts.OnUpdate,nil) end
    advance(20); eq(U.lastPaint,nil); eq(#U.pool,0)
    SlashCmdList.LAYERENEMIES(""); yes(U.frame:IsShown()); eq(U.lastPaint,clock); no(N.Main.error)
    local last=U.lastPaint
    advance(.5); eq(U.lastPaint,last); advance(.5); eq(U.lastPaint,clock)
    SlashCmdList.LAYERENEMIES(""); no(U.frame:IsShown()); last=U.lastPaint
    advance(10); eq(U.lastPaint,last)
    SlashCmdList.LAYERENEMIES("list"); no(U.frame:IsShown()); yes(logged("Only players seen"))
end)
test("UI tabs, scrolling and row pooling never allocate on repeat refresh",function()
    local N=loadAddon(); establish(N); local U=N.UI
    advance(1)
    for i=1,20 do
        N.Store.observe(N.Main.store,{key="Player-1-"..i,name="Enemy",class="MAGE",level=i,at=clock,faction="opposite",source="own target"},clock)
    end
    U.toggle(); eq(#U.pool,6); eq(U.tabs["local"].label.text,"Seen by you (20)")
    local first=U.pool[1]; local count=#frames
    for _=1,20 do U.render() end
    eq(#frames,count); eq(U.pool[1],first)
    U.body.scripts.OnMouseWheel(U.body,-1); eq(U.offset,1)
    U.tabs.reported:Click(); eq(U.tab,"reported"); eq(U.offset,0); yes(U.banner.text:find("not confirmed",1,true)); no(first:IsShown())
    U.tabs.friendly:Click(); eq(U.tab,"friendly")
    U.tabs.find:Click(); eq(U.tab,"find"); yes(U.input:IsShown()); yes(U.add:IsShown())
    U.tabs["local"]:Click(); no(U.input:IsShown()); eq(U.pool[1],first); eq(#frames,count)
end)
test("UI Friendly and Reported buttons dispatch AskInvite and show real cooldown",function()
    local N=loadAddon(); warSettings(); chatBox(); friends(N,{})
    -- 0.3.1: a row with a Bulo or LayerSwap layer gets "Hop via"; a War Effort reporter row keeps the chat ask
    advance(1); hello("Alice",19); report(7,9,"Alice")
    local U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].title.text,"Alice"); eq(U.pool[1].ask.label.text,"Ask for invite")
    local original=N.AskInvite; local calls={}
    N.AskInvite=function(name) calls[#calls+1]=name; return original(name) end
    U.pool[1].ask:Click(); drain(); eq(calls[1],"Alice"); eq(#opened,1)
    eq(U.pool[1].ask.label.text,"Asked · 60s"); yes(U.pool[1].ask.disabled)
    U.pool[1].ask:Click(); eq(#calls,1)
    advance(1); eq(U.pool[1].ask.label.text,"Asked · 59s")
    advance(60); no(U.pool[1].ask.disabled)
    -- a report row: Hop. Its label says who is asked and how before the click; a reporter with no host addon
    -- known gets the prefilled chat whisper, nothing is sent
    hello("Scout",19); report(1,9,"Scout"); U.select("reported"); yes(U.pool[1].ask:IsShown())
    eq(U.pool[1].ask.label.text,"Ask Scout (chat)"); no(U.pool[1].ask.disabled)
    yes(U.pool[1].ask.reason:find("prefilled chat whisper to Scout",1,true))
    U.pool[1].ask:Click(); drain(); eq(#calls,1); eq(#opened,2); eq(opened[2].text,"/w Scout "..ASK); eq(#sent,0)
    U.render(); yes(U.pool[1].ask.disabled); yes(U.pool[1].ask.reason:find("Scout was asked",1,true))
    -- a report whose layer cannot be compared: disabled, with the reason
    report(2,7086,"Other"); U.render()
    local other; for _,row in ipairs(U.pool) do if row:IsShown() and row.sub.text=="reported by Other" then other=row end end
    yes(other); yes(other.ask.disabled); eq(other.ask.reason,"this report's layer cannot be compared with yours.")
    eq(forbidden,0)
end)
test("UI Find add, status, clear and invite use existing flow",function()
    local N=loadAddon(); chatBox(); local U=N.UI
    U.toggle(); U.tabs.find:Click(); U.input:SetText("Alice"); U.add:Click()
    eq(LayerEnemiesDB.tracked[1],"Alice"); eq(U.input:GetText(),""); eq(U.pool[1].title.text,"Alice")
    yes(U.pool[1].sub.text:find("Not located",1,true)); no(U.pool[1].ask:IsShown())
    N.Find.report(N.Main.find,{sender="Scout",zone=100,at=clock,enemies={{hash=N.Hash.player("Alice",""),class="MAGE",level=40}}},"Test Realm")
    U.render(); yes(U.pool[1].sub.text:find("possible match",1,true)); yes(U.pool[1].ask:IsShown())
    U.pool[1].ask:Click(); drain(); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK)
    U.pool[1].clear:Click(); eq(#LayerEnemiesDB.tracked,0); no(U.pool[1]:IsShown())
    U.input:SetText("Bad|r"); U.add:Click(); eq(#LayerEnemiesDB.tracked,0)
end)
test("UI dragging saves and restores valid per-character position",function()
    local N=loadAddon(); local U=N.UI
    U.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",42,-80)
    U.frame.scripts.OnDragStart(); yes(U.frame.moving)
    U.frame.scripts.OnDragStop(); no(U.frame.moving)
    eq(LayerEnemiesDB.position.x,42); eq(LayerEnemiesDB.position.y,-80)
    U.frame=nil; U.create(); eq(U.frame.point[1],"TOPLEFT"); eq(U.frame.point[4],42)
    LayerEnemiesDB.position={point="garbage",relative="CENTER",x=math.huge,y=0}
    U.frame=nil; U.create(); eq(U.frame.point[1],"CENTER"); eq(U.frame.point[4],0)
    eq(U.position(secret),nil); eq(U.position({point=secret}),nil)
    eq(U.position(setmetatable({},{__index=function() error("corrupt") end})),nil)
    local clean=U.position({point="CENTER",relative="CENTER",x=0,y=0,unwanted="private"})
    eq(clean.unwanted,nil); eq(N.Safe.count(clean),4)
end)
test("Forever surname whisper uses native target API, never malformed slash text",function()
    local N=loadAddon(); friends(N,{["First Surname"]=there()})
    local target,inserted
    ChatFrameUtil={SendTell=function(name) target=name end,GetActiveWindow=function() return {Insert=function(_,text) inserted=text end} end}
    yes(LE.AskInvite("First Surname")); drain(); eq(target,"First Surname"); eq(inserted,ASK); eq(#opened,0)
    advance(60); ChatFrameUtil=nil
    yes(LE.AskInvite("First Surname")); drain(); yes(logged("open a whisper to First Surname manually")); no(logged("/w First Surname")); eq(forbidden,0)
end)
-- Record model and layer namespaces (Task 2)
local function rec(N,over)
    local t={src="we",kind="group",origin="Scout-TestRealm",via="Scout-TestRealm",route="GUILD",rid="1",zone=100,x=.4,y=.5,count=1,
        enemies={{hash="abc",class="HUNTER",level=40}},layer={ns="server",value="7086"},heard=10,share="guild"}
    for k,v in pairs(over or {}) do t[k]=v end
    return N.Record.new(t)
end
test("relation never crosses namespaces",function()
    local N=loadAddon(); local R=N.Record; local own={zone=100,server="7086"}
    local r=rec(N); yes(r); eq(r.id,"we:scout:1"); eq(R.relation(r,own),"same")
    eq(R.relation(rec(N,{layer={ns="zoneuid",value="7086"}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="zoneuid",value=7086}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="unknown",value="7086"}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="server",value="7087"}}),own),"other")
end)
test("relation is zone scoped",function()
    local N=loadAddon(); local R=N.Record; local r=rec(N)
    eq(R.relation(r,{zone=200,server="7086"}),"unknown"); eq(R.relation(r,{zone=200,server="7087"}),"unknown")
    eq(R.relation(r,{zone=100,server=nil}),"unknown"); eq(R.relation(r,{server="7086"}),"unknown")
    eq(R.relation(nil,{zone=100,server="7086"}),"unknown"); eq(R.relation(r,nil),"unknown")
end)
test("equal server is unknown while ambiguous",function()
    local N=loadAddon(); local R=N.Record
    eq(R.relation(rec(N),{zone=100,server="7086",ambiguous=true}),"unknown")
    eq(R.relation(rec(N,{layer={ns="server",value="7087"}}),{zone=100,server="7086",ambiguous=true}),"other")
end)
test("own server key without Bulo",function()
    local N=loadAddon(); eq(N.Layer.server(N.Main.npcs),nil)
    units.target={guid=npc(1,4),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),nil)
    units.mouseover={guid=npc(2,4),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),"7086"); eq(N.Main.store.bulo,"7086-4")
    eq(N.Layer.server({}),nil); eq(N.Layer.server(nil),nil); eq(N.Layer.server(secret),nil)
end)
test("ambiguity lasts 1800 s",function()
    local N=loadAddon(); local L=N.Layer; local st=L.new()
    L.observe(st,npc(1,4),1); L.observe(st,npc(2,4),2); eq(L.server(st),"7086"); no(L.ambiguous(st,2))
    L.observe(st,npc(3,9),10); local z,old,raw=L.observe(st,npc(4,9),11); eq(raw,"7086-9")
    yes(L.ambiguous(st,11)); yes(L.ambiguous(st,11+1799)); no(L.ambiguous(st,11+1801))
    -- the same-zone reset Main does on a zoneUID transition keeps it; a zone change ends it
    L.reset(st); yes(L.ambiguous(st,100)); eq(L.server(st),"7086")
    L.forget(st); no(L.ambiguous(st,100)); eq(L.server(st),nil)
    -- a changed server part is another layer, not an ambiguity
    st=L.new(); L.observe(st,npc(1,4),1); L.observe(st,npc(2,4),2)
    L.observe(st,npc(3,9,"7087"),10); L.observe(st,npc(4,9,"7087"),11); eq(L.server(st),"7087"); no(L.ambiguous(st,12))
    -- through the addon: zoneUID 4 -> 9 on one server in one zone, then a zone change
    N=loadAddon()
    units.target={guid=npc(1,4),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2,4),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(1)
    units.target={guid=npc(3,9),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(4,9),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    yes(L.ambiguous(N.Main.npcs,clock)); yes(N.Main.store.ambiguous and N.Main.store.ambiguous(clock))
    map=200; units.target={guid=npc(5,9),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain()
    no(L.ambiguous(N.Main.npcs,clock))
end)
test("an unreadable map does not end the zone epoch",function()
    local function see(id,uid) units.target={guid=npc(id,uid),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1) end
    local function ambiguousAddon()
        local N=loadAddon(); establish(N); see(3,9); see(4,9)
        yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086")
        return N
    end
    -- same zone -> loading screen without a map -> same zone: raw id and ambiguity survive
    local N=ambiguousAddon()
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); eq(N.Main.store.zone,nil)
    yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086")
    map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Main.store.zone,100)
    yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086"); yes(N.Main.store.ambiguous(clock))
    -- twice in a row changes nothing either
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); deliver("SHARD_TRANSFER"); drain(); map=100; N.Main.poll()
    yes(N.Layer.ambiguous(N.Main.npcs,clock))
    -- zone A -> no map -> zone B: forgotten
    N=ambiguousAddon()
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); yes(N.Layer.ambiguous(N.Main.npcs,clock))
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    no(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),nil)
    -- zone A -> zone B (layer confirmed there) -> zone A: B's raw id is forgotten on the way back
    N=ambiguousAddon(); map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Layer.server(N.Main.npcs),nil)
    units.target={guid=npc(21,5,"8000"),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(22,5,"8000"),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),"8000")
    map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    no(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),nil); no(N.Main.error)
    -- the very first zone change after login, with no boundary before it, still ends the epoch
    N=loadAddon(); establish(N); eq(N.Layer.server(N.Main.npcs),"7086")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Layer.server(N.Main.npcs),nil)
end)
test("record rejects bad fields",function()
    local N=loadAddon()
    local function bad(over,why) local r,reason=rec(N,over); eq(r,nil,why); yes(reason,why) end
    bad({count=201},"count 201 (War Effort's maximum is 200)"); local many={}; for i=1,81 do many[i]={hash="abc"} end; bad({enemies=many},"81 enemies")
    bad({layer={ns="bulo",value="7086"}},"unknown ns"); bad({layer=false},"no layer"); bad({origin="A"},"1-byte origin")
    bad({origin=string.rep("a",101)},"origin 101"); bad({src="xx"},"src"); bad({kind="raid"},"kind"); bad({route="CHANNEL"},"route")
    bad({rid=string.rep("1",25)},"rid 25"); bad({x=1.5},"x"); bad({zone=0},"zone"); bad({share="all"},"share"); bad({heard=secret},"secret heard")
    bad({origin=secret},"secret origin"); bad({enemies={{level=secret}}},"secret enemy")
    eq(N.Record.new(nil),nil); eq(N.Record.new(secret),nil)
    -- 80 enemies and count 80 are fine; a server value must be a server key
    for i=1,80 do many[i]={hash="abc"} end; many[81]=nil; yes(rec(N,{enemies=many,count=80}))
    bad({layer={ns="server",value="x7"}},"server value")
    local r=rec(N,{label="War Effort",age=5}); eq(r.label,"War Effort"); eq(r.age,5); eq(r.layer.ns,"server")
end)
test("store relation uses the record",function()
    local N=loadAddon(); establish(N); advance(1)
    report(1,7); local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].relation,"unknown"); eq(rows[1].record.layer.ns,"unknown"); eq(rows[1].record.src,"we")
    eq(rows[1].record.origin,"Other"); eq(rows[1].record.share,"guild")
    SlashCmdList.LAYERENEMIES("list"); yes(logged("Your server key: 7086")); no(logged("War Effort zoneUID"))
end)
test("tracking a name looks through reports already stored (records)",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1)
    local hash=N.Hash.player("Alice","Test Realm"); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|1|1|1|"..hash..":H:40|"..stamp,"GUILD","Scout")
    eq(N.Main.lastDrop,"enriched"); no(N.Main.find.locations.Alice)
    N.Main.track("Alice"); local loc=N.Main.find.locations.Alice
    yes(loc); eq(loc.spotter,"Scout"); eq(loc.zone,100); eq(loc.level,40); no(N.Main.error)
end)
-- Task 5: one-click hop
-- a hop as the user makes it: preview, then click on what was shown
local function hopNow(N,record) return N.Main.hopTo(record,N.Main.hopPreview(record)) end
local function hopReport(id,key,who) hello(who or "Scout",19); report(id,key,who or "Scout") end
local function rec(N,over)
    local t={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,layer={ns="server",value="8000"},heard=clock,share="guild"}
    for k,v in pairs(over or {}) do t[k]=v end
    return assert(N.Record.new(t))
end
test("hop line matches the LayerSwap grammar",function()
    local N=loadAddon(); local H=N.Hop
    eq(H.line(1429,"7086",nil,.482,.425),"inv layer <LS 1429 want 7086-0 48.2,42.5>")
    eq(H.line(1429,"7086",12,.482,.425),"inv layer <LS 1429 want 7086-12 48.2,42.5>")
    eq(H.line(1429,"7091",3),"inv layer <LS 1429 want 7091-3>")
    eq(H.line(1429,"7091",0,1,0),"inv layer <LS 1429 want 7091-0 100.0,0.0>")
    eq(H.line(1429,"7091",0,1.2,.5),"inv layer <LS 1429 want 7091-0>")
    eq(H.line(nil,"7086"),nil); eq(H.line(1429,"x7"),nil); eq(H.line(1429,"7086-4"),"inv layer <LS 1429 want 7086-0>"); eq(H.line(1429,"7086",-1),nil); eq(H.line(14.5,"7086"),nil)
    -- what LayerSwap and Bulo parse out of it (study: first <LS...>, zone, want id, trailing pair within 0..100)
    local body=H.line(1429,"7086",12,.482,.425):match("^inv layer <LS([^<>]*)>$")
    eq(body:match("^%s*(%d+)"),"1429"); eq(body:match("want%s+(%d+%-%d+)"),"7086-12"); eq(body:match("(%d+%.?%d*),(%d+%.?%d*)%s*$"),"48.2")
end)
test("hop sends exactly one whisper per click",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true}),Alice=there()},{Cora=page()}); advance(1)
    hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports")
    yes(logged("[1] /le hop 1: one LayerSwap request whispered to Bob (Bulo)"))
    SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob")
    eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(#opened,0); eq(forbidden,0)
    yes(logged("asked Bob (Bulo) for an invite to layer 8000. Accept the invite yourself; nothing else is sent."))
    eq(N.Main.invite.pending.name,"Bob"); eq(N.Main.hop.pending.name,"Bob")
    -- a LayerSwap book entry comes with the host's zoneUID; it goes before a Bulo line without the host flag
    N=loadAddon(); friends(N,{Alice=there()},{Cora=page({layer="8000-13"})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].target,"Cora"); eq(sent[1].text,"inv layer <LS 100 want 8000-13 25.0,75.0>")
    -- no position on a child map: the line goes without it
    N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    map=101; yes(hopNow(N,N.Store.rows(N.Main.store,clock,"reported")[1].record)); eq(#sent,1); eq(sent[1].text,"inv layer <LS 100 want 8000-0>")
    -- the map already shows another zone (no event yet): the live zone decides, so nothing is sent (مانع T5 S1)
    advance(61); map=200; no(hopNow(N,N.Store.rows(N.Main.store,clock,"reported")[1].record)); eq(#sent,1); yes(log[#log]:find("travel to",1,true))
end)
test("hop refuses when grouped, other zone, zoneuid layer, same layer, no candidate",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    local function refused(record,text)
        local before=#log
        no(hopNow(N,record)); eq(#sent,0); yes(log[#log]:find(text,1,true),text); yes(#log>before)
    end
    grouped=true; refused(rec(N),"leave your current group first"); grouped=false
    refused(rec(N,{zone=200}),"travel to "); refused(rec(N,{layer={ns="zoneuid",value=8000}}),"cannot be compared")
    refused(rec(N,{layer={ns="unknown",value=8000}}),"cannot be compared")
    refused(rec(N,{layer={ns="server",value="7086"}}),"on your layer already")
    -- no one known on that layer: since 0.4.0 the guild-chat request is drafted instead (no chat box here: the line
    -- is printed to type); no addon message either way
    yes(hopNow(N,rec(N,{src="guild",layer={ns="server",value="9500"}}))); eq(#sent,0); yes(logged("/g inv layer <LS 100 want 9500-0"))
    -- unknown own zone
    N.Main.store.zone=nil; refused(rec(N),"your zone is not known"); eq(#opened,0); eq(forbidden,0)
end)
test("hop cooldown blocks a second click",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true}),Dan=there({key="9000",host=true})}); advance(1)
    yes(hopNow(N,rec(N))); eq(#sent,1)
    no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true))
    advance(5); no(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true))
    advance(5); yes(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,2); eq(sent[2].target,"Dan")
    advance(10); no(hopNow(N,rec(N))); eq(#sent,2)
    advance(41); yes(hopNow(N,rec(N))); eq(#sent,3)
end)
test("hop does not retry on throttle",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    sendResult=3; no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("throttling whispers; not sent",1,true))
    eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    advance(300); eq(#sent,1)
    -- 1.0 T1: a channel throttle (8) is a throttle too (the prefix pauses 30 s); another refusal (1) is "refused"
    sendResult=8; advance(61); no(hopNow(N,rec(N))); eq(#sent,2); yes(log[#log]:find("throttling whispers; not sent",1,true))
    sendResult=1; advance(61); no(hopNow(N,rec(N))); eq(#sent,3); yes(log[#log]:find("refused the whisper",1,true))
    sendResult=function() error("boom") end; advance(61); no(hopNow(N,rec(N))); eq(#sent,4); yes(log[#log]:find("could not be sent",1,true))
    advance(300); eq(#sent,4); eq(forbidden,0)
end)
test("hop parses heard for me and ignores heard for others",function()
    local N=loadAddon(); local H=N.Hop
    local r=H.reply("heard Tam Reed|7091-3|1429|h","Bob","Tam Reed"); eq(r.kind,"heard"); eq(r.layer,"7091-3"); eq(r.zone,1429); yes(r.hosting)
    r=H.reply("heard Tam Reed|-|1429|-","Bob","Tam Reed"); eq(r.layer,nil); no(r.hosting)
    -- malformed fields make the reply unreadable (مانع T5 S2)
    eq(H.reply("heard Tam Reed|7091-3|1429|x","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429|","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|7091|1429|h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|14x|h","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|7091-3||h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429|h\1","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|-|-|-","Bob","Tam Reed").zone,nil)
    eq(H.reply("heard Aya Stone|7091-3|1429|h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429","Bob","Tam Reed"),nil)
    eq(H.reply(secret,"Bob","Me"),nil)
    friends(N,{Bob=there({host=true})}); advance(1); yes(hopNow(N,rec(N)))
    local function reply(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"WHISPER",from or "Bob"); drain() end
    reply("heard Someone Else|8000-13|100|h"); eq(lines("heard you"),0)
    reply("heard Me|8000-13|100|h","Cora"); eq(lines("heard you"),0)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","GUILD","Bob"); eq(lines("heard you"),0)
    reply("heard Me|8000-13|100|h"); yes(logged("LayerEnemies: Bob heard you (layer 8000-13, hosting: yes)."))
    reply("heard Me|-|100|-","Bob-TestRealm"); yes(logged("LayerEnemies: Bob heard you (layer unknown, hosting: no)."))
    advance(121); reply("heard Me|8000-13|100|h"); eq(lines("heard you"),2); eq(#sent,1)
end)
test("hop parses same",function()
    local N=loadAddon(); eq(N.Hop.reply("same","Bob","Me").kind,"same"); eq(N.Hop.reply("same ","Bob","Me"),nil); eq(N.Hop.reply("SAME","Bob","Me"),nil)
    friends(N,{Bob=there({host=true})}); advance(1)
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); eq(lines("on their layer"),0)   -- nothing asked yet
    yes(hopNow(N,rec(N)))
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); yes(logged("LayerEnemies: Bob says you're on their layer."))
end)
test("hop ignores inv layer requests and sends no heard",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({host=true})}); advance(1)
    local before=#log
    for _,kind in ipairs({"WHISPER","GUILD","PARTY"}) do
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-7 50.0,50.0>",kind,"Stranger")
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 not 8000-1 50.0,50.0>",kind,"Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","claim Me",kind,"Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","want 7086-7",kind,"Bob")
    end
    yes(hopNow(N,rec(N))); eq(#sent,1)
    deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-7 50.0,50.0>","WHISPER","Bob")
    eq(#sent,1); eq(#log,before+1); eq(forbidden,0); no(N.Main.error)
end)
test("hop works while LayerSwap and Bulo are loaded",function()
    local N=loadAddon(); loaded.LayerSwap=true; loaded.BuloLayerForever=true
    local b=friends(N,{Bob=there({host=true})},{Cora=page({layer="8000-13"})}); advance(1)
    local function snapshot(t,depth)
        local out={}; for k,v in pairs(t) do out[#out+1]=tostring(k).."="..(type(v)=="table" and depth<3 and "{"..snapshot(v,depth+1).."}" or tostring(v)) end
        table.sort(out); return table.concat(out,",")
    end
    local bulo,book=snapshot(b.Guild,0),snapshot(LayerSwapDB,0)
    hopReport(1,8000); SlashCmdList.LAYERENEMIES("reports"); SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].target,"Bob")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","WHISPER","Bob"); yes(logged("Bob heard you (layer 8000-13, hosting: yes)."))
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); yes(logged("Bob says you're on their layer."))
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Bob"); deliver("CHAT_MSG_ADDON","LFSw","v 3.0.25","WHISPER","Bob")
    -- their saved data and live tables are only read
    eq(snapshot(b.Guild,0),bulo); eq(snapshot(LayerSwapDB,0),book); eq(#sent,1); eq(forbidden,0); no(N.Main.error)
end)
test("hop state clears on zone change and reload",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N))); yes(N.Main.hop.pending); yes(N.Main.invite.pending)
    -- a same-zone transfer is what a hop causes: kept
    deliver("SHARD_TRANSFER"); drain(); yes(N.Main.hop.pending); yes(N.Main.invite.pending)
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain(); yes(N.Main.hop.pending)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","WHISPER","Bob"); eq(lines("heard you"),0)
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); eq(N.Main.invite.watch,nil); advance(70); eq(lines("Moved to layer"),0)
    -- reload: nothing of a hop survives
    grouped=false; N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); yes(hopNow(N,rec(N)))
    N=loadAddon(); eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); eq(lines("on their layer"),0)
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="call" or k=="callArt" or k=="netNotice" or k=="findShare" or k=="findNotice",k) end; eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("hop acts on the shown candidate only (مانع T5 F1)",function()
    -- shown "Ask Scout (chat)"; an LFSw host line arrives before the click: nothing is sent, nothing drafted
    local N=loadAddon(); chatBox(); establish(N); advance(1); local r=rec(N)
    local shown=N.Main.hopPreview(r); eq(shown.label,"Ask Scout (chat)"); yes(shown.enabled)
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Mallory")
    eq(N.Main.hopPreview(r).label,"Hop via Mallory")
    no(N.Main.hopTo(r,shown)); drain(); eq(#sent,0); eq(#opened,0); yes(logged("LayerEnemies: hosts changed, check again."))
    eq(N.Safe.count(N.Main.invite.asked),0); eq(N.Main.hop.pending,nil)
    -- no preview at all is refused the same way
    no(N.Main.hopTo(r)); eq(#sent,0)
    -- the new preview is what a second click acts on
    yes(N.Main.hopTo(r,N.Main.hopPreview(r))); eq(#sent,1); eq(sent[1].target,"Mallory")
    -- the same through /le reports + /le hop and through the window button
    N=loadAddon(); chatBox(); establish(N); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("a prefilled chat whisper to Scout"))
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Mallory")
    SlashCmdList.LAYERENEMIES("hop 1"); drain(); eq(#sent,0); eq(#opened,0); yes(logged("hosts changed, check again."))
    N=loadAddon(); chatBox(); establish(N); advance(1); hopReport(1,8000); local U=N.UI
    U.toggle(); U.select("reported"); eq(U.pool[1].ask.label.text,"Ask Scout (chat)")
    N.Main.guildLines["Mallory"]={key="8000",zone=100,host=true,at=wall}
    U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,0)
    eq(U.pool[1].ask.label.text,"Hop via Mallory")                        -- redrawn
    U.pool[1].ask:Click(); drain(); eq(#sent,1); eq(sent[1].target,"Mallory"); eq(#opened,0); eq(forbidden,0)
    -- the same player changing mode (reporter to LFSw host) is a change too
    N=loadAddon(); chatBox(); establish(N); advance(1); r=rec(N); shown=N.Main.hopPreview(r); eq(shown.label,"Ask Scout (chat)")
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Scout"); eq(N.Main.hopPreview(r).label,"Hop via Scout")
    no(N.Main.hopTo(r,shown)); drain(); eq(#sent,0); eq(#opened,0)
end)
test("hop replies: same wording, ambiguity, full-name sender, route (مانع T5 F2, S2)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N)))
    -- PARTY, another realm's Bob, and a lookalike are ignored
    deliver("CHAT_MSG_ADDON","LayerSwap","same","PARTY","Bob"); deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob-EvilRealm")
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bobb"); eq(lines("on their layer"),0)
    -- our own realm written out is still Bob
    N.Main.store.ambiguous=function() return true end
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob-TestRealm")
    yes(logged("LayerEnemies: Bob says you're on their layer (probably: your key is ambiguous)."))
    eq(N.Hop.receive({pending={name="Al",short="al",at=0}},"same","Al","Me",1,false),"Al says you're on their layer.")
end)
test("hop: grouping, live zone and per-source host rank (مانع T5 S1, S3)",function()
    -- unreadable IsInGroup refuses
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    IsInGroup=function() return secret end; no(hopNow(N,rec(N))); yes(log[#log]:find("leave your current group first",1,true))
    IsInGroup=function() error("boom") end; no(hopNow(N,rec(N))); IsInGroup=nil; no(hopNow(N,rec(N))); eq(#sent,0)
    IsInGroup=function() return grouped end
    -- unreadable live map refuses
    map=nil; no(hopNow(N,rec(N))); yes(log[#log]:find("your zone is not known",1,true)); map=100
    yes(hopNow(N,rec(N))); eq(#sent,1)
    -- a Bulo host beats a Bulo non-host who is also a LayerSwap host
    N=loadAddon(); friends(N,{Bob=there({host=true,at=wall-30}),Alice=there({at=wall-1})},{Alice=page({host=true,at=wall-1})}); advance(1)
    local list=N.Main.candidates(); local alice; for _,c in ipairs(list) do if c.name=="Alice" then alice=c end end
    yes(alice.host); eq(alice.hosts.Bulo,false); eq(alice.hosts.LayerSwap,true)
    local c=N.Hop.candidate(rec(N),list); eq(c.name,"Bob"); eq(c.source,"Bulo")
    yes(hopNow(N,rec(N))); eq(sent[#sent].target,"Bob")
    -- without the Bulo host, Alice is asked as a LayerSwap host
    N=loadAddon(); friends(N,{Alice=there({at=wall-1})},{Alice=page({host=true,at=wall-1})}); advance(1)
    c=N.Hop.candidate(rec(N),N.Main.candidates()); eq(c.name,"Alice"); eq(c.source,"LayerSwap")
end)
test("hop: two zone boundaries before a poll end the layer watch (مانع T5 S4)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N))); grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); map=100; deliver("ZONE_CHANGED_NEW_AREA")
    eq(N.Main.invite.watch,nil); yes(logged("Zone changed - layer check cancelled."))
    drain(); advance(70); eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); grouped=false
end)
test("hop: a failed send keeps the cooldown",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    sendResult=3; no(hopNow(N,rec(N))); eq(#sent,1)
    sendResult=nil; no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true))
    advance(5); no(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true))
end)
test("claims are keyed by full name; HeadHunter never compares (T3/T4 leftovers)",function()
    local N=loadAddon()
    local env={ownKey="8000",wall=1000,zone=100,bulo={["Scout-RealmA"]={key="8000",zone=100,host=false,at=990}}}
    eq(N.Invite.sameSpotter("Scout-RealmA",env),true); eq(N.Invite.sameSpotter("Scout-RealmB",env),false); eq(N.Invite.sameSpotter("Scout",env),false)
    local _,a=N.Invite.name("Scout-RealmA"); local _,b=N.Invite.name("Scout-RealmB"); yes(a~=b)
    local _,c=N.Invite.name("Bob"); local _,d=N.Invite.name("Bob-TestRealm"); eq(c,d)
    -- a hand-built HeadHunter record with a server layer is still not comparable
    local own={zone=100,server="8000"}
    eq(N.Record.relation(rec(N,{src="hh",kind="fight",share="public"}),own),"unknown")
    eq(N.Record.relation(rec(N,{src="hh",kind="fight",share="public",layer={ns="server",value="9000"}}),own),"unknown")
    eq(N.Record.relation(rec(N),own),"same"); eq(N.Record.relation(rec(N,{layer={ns="server",value="9000"}}),own),"other")
end)
test("/le hop numbers do not survive a zone change (r2)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); yes(N.Main.hopList)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.hopList,nil)
    SlashCmdList.LAYERENEMIES("hop 1"); drain(); eq(#sent,0); yes(logged("run /le reports first"))
    -- a same-zone transfer (an unreadable map) keeps them
    N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); deliver("SHARD_TRANSFER"); drain(); yes(N.Main.hopList)
end)
test("guild L line without Bulo fills the host list",function()
    local N=loadAddon(); establish(N); advance(1)
    local function line(text,from,kind) deliver("CHAT_MSG_ADDON","LFSw",text,kind or "GUILD",from) end
    line("L 8000|100|h","Bob"); line("L 9000|100|-","Dan Lee-OtherRealm"); line("L 8000|100|-","Me"); line("L 8000|100|-","Me-TestRealm")
    eq(N.Main.guildLines["Me"],nil); eq(N.Main.guildLines["Me-TestRealm"],nil); yes(N.Main.guildLines["Bob"])
    for _,bad in ipairs({"L 8000-3|100|h","L 8000|100|x","L 8000|100|h|x","L |100|h","L 8000|1a|h","Q","v 3.0.25"}) do line(bad,"Eve") end
    line("L 8000|100|h","Wes","WHISPER"); line("L 8000|100|h","Pat","PARTY")
    -- (0.4.0 review S2/M1: one name rule; another realm stays in the name, also for a spaced name)
    local list=N.Main.candidates(); eq(names(list),"Bob,Dan Lee-OtherRealm")
    eq(list[1].layer,"8000"); yes(list[1].host); eq(table.concat(list[1].sources,"+"),"Bulo")
    yes(hopNow(N,rec(N))); eq(sent[1].target,"Bob"); eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(#sent,1)
    -- not in a guild, or ignored: not read
    inGuild=false; line("L 7000|100|h","Gus"); inGuild=true
    clientIgnored=true; line("L 7000|100|h","Ivy"); clientIgnored=false
    eq(#N.Main.candidates(),2)
    -- 720 s freshness
    advance(720); line("L 9500|100|h","Fay"); eq(names(N.Main.candidates()),"Fay"); eq(N.Safe.count(N.Main.guildLines),1)
    -- 256 lines at most
    local many={}; for i=1,300 do N.Adapters.guildLine(many,"L 8000|100|h","Name"..string.char(97+i%26)..string.char(97+math.floor(i/26)%26),1000+i) end
    yes(N.Safe.count(many)<=256)
    eq(forbidden,0); no(N.Main.error)
end)
test("hop: own layer is the confirmed one, never a stale server key (مانع T2 S2)",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({key="7086",host=true})}); advance(1)
    deliver("SHARD_TRANSFER"); drain()
    eq(N.Main.store.bulo,nil); eq(N.Layer.server(N.Main.npcs),"7086")      -- the raw id is kept for the ambiguity window
    eq(N.Store.own(N.Main.store,clock).server,nil)
    -- a report on 7086 is not "on your layer": our layer is not known after the transfer. (Bulo/LayerSwap lists
    -- need our own key, so the War Effort reporter is the one asked, by chat whisper.) The 0.3.1 S1 refusal covers
    -- only a reporter that is a Bulo/LayerSwap row seen while our layer is unknown; Scout is none.
    chatBox()
    local r=rec(N,{layer={ns="server",value="7086"}}); eq(N.Record.relation(r,N.Store.own(N.Main.store,clock)),"unknown")
    yes(hopNow(N,r)); drain(); eq(#sent,0); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK); eq(lines("on your layer already"),0)
    SlashCmdList.LAYERENEMIES("list"); yes(logged("Your server key: Unknown")); yes(logged("Your layer: Unknown"))
end)
test("hop: an ambiguous own key is never a certain same layer (مانع T2 S3)",function()
    local function see(N,u,id,uid) units[u]={guid=npc(id,uid),player=false}; deliver(u=="target" and "PLAYER_TARGET_CHANGED" or "UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1) end
    local N=loadAddon(); establish(N); see(N,"target",3,9); see(N,"mouseover",4,9); see(N,"target",5,9); see(N,"mouseover",6,9)
    yes(N.Main.store.ambiguous(clock)); eq(N.Main.store.bulo,"7086-9")
    -- candidate filtering: an equal key stays listed, marked probably
    b=fakeBulo("7086-9"); b.Guild={list={Dora=there({key="7086"}),Bob=there()}}; N.Main.poll()
    local list=N.Main.candidates(); eq(names(list),"Bob,Dora"); yes(list[2].probably); no(list[1].probably)
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("Dora | layer 7086 (probably your layer: your key is ambiguous)"))
    -- /le find: "probably on your layer", and the ask stays possible
    chatBox(); SlashCmdList.LAYERENEMIES("find Alice")
    local hash=N.Hash.player("Alice",""); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|70|100|0|0|9|1|"..stamp,"GUILD","Dora")
    deliver("CHAT_MSG_ADDON","WEFF1","E|70|1|1|"..hash..":M:40|"..stamp,"GUILD","Dora")
    local row=N.Main.findRows()[1]; no(row.same); yes(row.probably); yes(row.canAsk)
    yes(N.Main.findText(row):find("probably on your layer (your server key is ambiguous)",1,true)); no(N.Main.findText(row):find("already on your layer",1,true))
    -- a report on our key: relation unknown, so a hop is not refused as "on your layer"
    eq(N.Record.relation(rec(N,{layer={ns="server",value="7086"}}),N.Store.own(N.Main.store,clock)),"unknown")
    -- the deadline line: "probably" still on your layer
    advance(11); yes(LE.AskInvite("Bob")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(61)
    yes(logged("Probably still on your layer (your server key is ambiguous) - leave, wait a minute, try again."))
    eq(lines("Still on your layer - leave"),0)
    -- once the window is over the old wording comes back
    N=loadAddon(); establish(N); friends(N,{Bob=there()}); yes(LE.AskInvite("Bob")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(61)
    yes(logged("Still on your layer - leave, wait a minute, try again.")); eq(lines("Probably still"),0)
end)
test("ask texts: no promise about leaving, server-key wording",function()
    local N=loadAddon()
    eq(N.Invite.MESSAGE,"Hi! Could you invite me to your layer please?"); no(N.Invite.MESSAGE:find("leave",1,true))
    establish(N); local _,status=N.Main.candidates(); eq(status.reports,"0 not on your server key")
    for _,file in ipairs({"Invite","Main","UI"}) do
        local f=io.open("LayerEnemies/"..file..".lua"); local src=f:read("*a"); f:close()
        no(src:find("on another zoneUID",1,true),file); no(src:find("leave right after",1,true),file)
    end
end)
-- HeadHunter 1.1.1 (study/headhunter.md §3.3 fixtures: map 1424 = "13k", t 1800000000 = "tro8w0", .5 = "dw", .25 = "6y")
local HHT=1800000000
local HHP="1AP:13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"
local HHE="1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"
local function b36(n) local d,s="0123456789abcdefghijklmnopqrstuvwxyz",""; repeat local r=n%36; s=d:sub(r+1,r+1)..s; n=(n-r)/36 until n==0; return s end
local function hh(N,text,sender,at,faction) return N.HeadHunter.decode(text,sender or "Fighter",at or HHT,faction or "Alliance",{heard=50,route="WHISPER"}) end
test("hh decodes a 7-field P with names and layer",function()
    local N=loadAddon(); local list,why=hh(N,HHP)
    eq(#list,1); eq(why,"ok"); local r=list[1]
    eq(r.src,"hh"); eq(r.kind,"fight"); eq(r.origin,"Fighter"); eq(r.via,"Fighter"); eq(r.route,"WHISPER"); eq(r.zone,1424)
    eq(r.x,.5); eq(r.y,.25); eq(r.count,2); eq(#r.enemies,1); eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"PALADIN")
    eq(r.enemies[1].level,31); eq(r.layer.ns,"zoneuid"); eq(r.layer.value,4); eq(r.rid,"1800000000"); eq(r.share,"public"); eq(r.age,0); eq(r.heard,50)
    -- skull level, unknown class and level, empty coordinates and layer, three names
    r=hh(N,"1AP:13k;tro8w0;;;a1,b2,c3;Ann Lee//s,Bo Ray/M/60,Cy Fox/W/;")[1]
    yes(r); eq(r.count,3); eq(r.enemies[1].level,-1); eq(r.enemies[1].class,nil); eq(r.enemies[2].class,"MAGE"); eq(r.enemies[3].level,nil)
    eq(r.x,nil); eq(r.y,nil); eq(r.layer.ns,"unknown")
    -- 12 enemy ids and 12 allies are the limit; 1000 would be 1.0 and is refused, 999 is .999
    local ids={}; for i=1,12 do ids[#ids+1]="e"..i; ids[#ids+1]="+a"..i end
    eq(hh(N,"1AP:13k;tro8w0;rr;0;"..table.concat(ids,","))[1].count,12); eq(hh(N,"1AP:13k;tro8w0;rr;0;a1")[1].x,.999)
end)
test("hh decodes a 5-field P",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;0000002A,+00000001")[1]
    yes(r); eq(r.count,1); eq(#r.enemies,0); eq(r.layer.ns,"unknown"); eq(r.kind,"fight")
    local list=hh(N,"1AP:13k;tro8w0;dw;6y;a1~13k;tro8w1;dw;6y;b2"); eq(#list,2); eq(list[2].rid,"1800000001")
end)
test("hh rejects 6-field P and version 2",function()
    local N=loadAddon()
    local list,why=hh(N,"1AP:13k;tro8w0;dw;6y;a1;Kora Reed/P/31"); eq(#list,0); eq(why,"invalid")
    list,why=hh(N,"2AP:13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"); eq(#list,0); eq(why,"version")
    local ids={}; for i=1,13 do ids[i]="e"..i end
    local bad={"1AP:13k;tro8w0;dw;6y;a1;Kora/P/31;4;x","1AP:13k;tro8w0;dw;6y","1AP:13K;tro8w0;dw;6y;a1","1AP:13k;tro8w0zzzzz;dw;6y;a1",
        "1AP:13k;tro8w0;rs;6y;a1","1AP:13k;tro8w0;dw;6y;"..table.concat(ids,","),"1AP:13k;tro8w0;dw;6y;a1;A b/P/1,B c/P/1,C d/P/1,D e/P/1;4",
        "1AP:13k;tro8w0;dw;6y;a1;Ko|ra/P/31;4","1AP:13k;tro8w0;dw;6y;a1;Kora/P/101;4","1AP:13k;tro8w0;dw;6y;a1;Kora/P/1a;4","1AP:13k;tro8w0;dw;6y;a1;Kora/Z/31;4",
        "1AP:13k;tro8w0;dw;6y;a1;Kora/P;4","1AP:13k;tro8w0;dw;6y;a1;;0","1AP:0;tro8w0;dw;6y;a1","1AP:13k;tro8w0;dw;6y;a-1","1XP:13k;tro8w0;dw;6y;a1",
        "1AP:","1AP13k;tro8w0;dw;6y;a1","1aP:13k;tro8w0;dw;6y;a1","1AP:13k;tro8w0;dw;6y;a1"..string.rep("~",250)}
    for _,text in ipairs(bad) do eq(#hh(N,text),0,text) end
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;a1"..string.rep(",b",120)),0); eq(#hh(N,secret),0); eq(#hh(N,{}),0)
end)
test("hh unwraps E and keeps author as origin",function()
    local N=loadAddon()
    local list=hh(N,HHE,"Carrier"); eq(#list,1); local r=list[1]
    eq(r.origin,"Mira Vale"); eq(r.via,"Carrier"); eq(r.layer.value,4); eq(r.count,2); eq(r.enemies[1].name,"Kora Reed")
    -- the enveloped P and the author's own direct P are one record
    eq(r.id,hh(N,HHP,"Mira Vale")[1].id)
    yes(hh(N,"1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;LKora Reed;13k;tro8w0;dw;6y","Carrier")[1])
    -- several envelopes in one frame
    eq(#hh(N,HHE.."~eu-pvp;Ann Lee;A;5cy;2;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier"),2)
    for _,text in ipairs({"1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;Dtro8w0;Mira Vale;u;M;H;13k;dw;6y;i;4;Kora",
        "1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;Eeu-pvp;Ann Lee;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1",
        "1AE:eu-pvp;M;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","1AE:eu-pvp;Mira Vale;X;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1",
        "1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0","1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y"}) do
        eq(#hh(N,text,"Carrier"),0,text)
    end
end)
test("hh drops other faction",function()
    local N=loadAddon()
    local list,why=hh(N,HHP,nil,nil,"Horde"); eq(#list,0); eq(why,"other faction")
    eq(#hh(N,"1HP:13k;tro8w0;dw;6y;a1",nil,nil,"Horde"),1)
    -- inside E the author's faction counts, not the carrier's header
    eq(#hh(N,"1HE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier",nil,"Alliance"),1)
    eq(#hh(N,"1AE:eu-pvp;Mira Vale;H;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier",nil,"Alliance"),0)
    list,why=hh(N,HHP,nil,nil,"Neutral"); eq(#list,0); eq(why,"unavailable")
end)
test("hh L becomes an outlaw record with unknown layer",function()
    local N=loadAddon()
    local r=hh(N,"1AL:Kora Reed;13k;tro8w0;dw;6y","Spotter")[1]
    yes(r); eq(r.kind,"outlaw"); eq(r.src,"hh"); eq(r.layer.ns,"unknown"); eq(r.count,1); eq(#r.enemies,1); eq(r.enemies[1].name,"Kora Reed")
    eq(r.origin,"Spotter"); eq(r.rid,N.Hash.hash3("kora reed")..":1800000000"); eq(r.x,.5); eq(r.share,"public")
    local g=hh(N,"1AL:guid:Player-7091-0000002A;13k;tro8w0;dw;6y")[1]; yes(g); eq(#g.enemies,0); eq(g.count,1)
    eq(#hh(N,"1AL:Kora Reed;13k;tro8w0;dw;6y;4"),0); eq(#hh(N,"1AL:Kora Reed;13k;tro8w0;dw"),0); eq(#hh(N,"1AL:K;13k;tro8w0;dw;6y"),0)
    -- in the window: "wanted (HeadHunter)", the name as reported
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","Spotter")
    eq(N.Main.lastDrop,"headhunter outlaw")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].name,"Kora Reed"); eq(rows[1].source,"wanted (HeadHunter)")
    eq(rows[1].relation,"unknown"); eq(rows[1].positionKind,"observer's position")
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("Kora Reed | Unknown class | ? | zone 100 | received 0 s ago | wanted (HeadHunter) | reported, not confirmed | reported by Spotter | observer's position | layer unknown",1,true))
end)
test("hh layer is never comparable",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;a1;;"..b36(7086))[1]; eq(r.layer.ns,"zoneuid"); eq(r.layer.value,7086)
    eq(N.Record.relation(r,{zone=1424,server="7086",ambiguous=false}),"unknown")
    eq(N.Record.relation(hh(N,HHP)[1],{zone=1424,server="4",ambiguous=false}),"unknown")
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;;"..b36(7086),"PARTY","Fighter")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].relation,"unknown"); eq(rows[1].namespace,"zoneuid")
    eq(rows[1].source,"fight (HeadHunter)"); eq(rows[1].name,"1 not listed"); eq(#N.Store.reporters(N.Main.store,clock),0)
    eq(rows[1].record.share,"public"); eq(rows[1].record.route,"PARTY")
end)
test("hh age window ±300 s",function()
    local N=loadAddon()
    local function at(t) return hh(N,"1AP:13k;"..b36(t)..";dw;6y;a1")[1] end
    yes(at(HHT-300)); eq(at(HHT-300).age,300); yes(at(HHT+300)); eq(at(HHT+300).age,0)
    eq(at(HHT-301),nil); eq(at(HHT+301),nil)
    local _,why=hh(N,"1AP:13k;"..b36(HHT-301)..";dw;6y;a1"); eq(why,"stale")
    eq(#N.HeadHunter.decode(HHP,"Fighter",secret,"Alliance",{heard=1,route="PARTY"}),0)
end)
test("hh ignores N, Q, O, S and sends nothing",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    for _,text in ipairs({"1AN:1.1.1","1AQ:h0","1AQ:p0","1AO:5","1AS:E3","1ASY:Kora Reed;2s;tro8w0;dw;6y;Me","1AT:hello",
        "1AD:tro8w0;Mira Vale;u;M;H;2s;dw;6y;i;4;Kora","1AH:5cy","1AJ:Kora Reed;2s;tro8w0;4"}) do
        local sender=text:sub(3,3)=="N" and "Peer" or "Other"
        deliver("CHAT_MSG_ADDON","HeadHunter",text,"WHISPER",sender)
        deliver("CHAT_MSG_ADDON","HeadHunter",text,"PARTY",sender)
    end
    eq(N.Safe.count(N.Main.store.reports),0); eq(#sent,0); eq(forbidden,0); no(N.Main.error)
end)
test("hh routes, duplicates, ignore, rate, ttl and caps in the window",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local function p(who,route,t,extra) deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(t or server)..";dw;6y;a1"..(extra or ""),route or "PARTY",who) end
    p("Guildie","GUILD"); eq(N.Main.lastDrop,"route")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","CHANNEL","Other",nil,nil,7,"HeadHunterSync"); eq(N.Main.lastDrop,"route")
    p("Me-TestRealm","WHISPER"); eq(N.Main.lastDrop,"own echo")
    p("Mira Vale","RAID"); eq(N.Main.lastDrop,"headhunter fight"); eq(N.Safe.count(N.Main.store.reports),1)
    -- the same P carried in an envelope by someone else is one record
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"duplicate"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.via,"Mira Vale")
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.share,"public"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.route,"RAID")
    -- an envelope whose author is ignored, or is us
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(name) return name=="Bad Guy" end
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Bad Guy;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"ignored sender"); C_FriendList.IsIgnored=old
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Me;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"own echo"); eq(N.Safe.count(N.Main.store.reports),1)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Me-TestRealm;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carriertwo")
    eq(N.Main.lastDrop,"own echo"); eq(N.Safe.count(N.Main.store.reports),1)
    -- 6 frames per sender per 10 s; the 7th leaves no trace
    for i=1,7 do p("Busy","PARTY",server-i) end
    eq(N.Safe.count(N.Main.store.reports),7)
    advance(10); p("Busy","PARTY",server); eq(N.Safe.count(N.Main.store.reports),8)
    -- a HeadHunter row lives 300 s
    -- a HeadHunter row lives 300 s from its origin's time (1.0 T2): the batch was 1 to 7 s old when it arrived
    -- (the six accepted batch rows were 1 to 6 s old on arrival, so they leave one per second, oldest first)
    advance(283); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),8)
    advance(1); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),7)
    advance(6); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),1)
    advance(10); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),0)
    -- 64 HeadHunter rows at most, and they never crowd out War Effort reports
    for i=1,70 do p("Fighter"..abc(i),"PARTY") end
    eq(N.Safe.count(N.Main.store.reports),64); eq(N.Main.lastDrop,"report cap")
    report(1,7,"Scout"); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),65)
    -- party/raid pings go on to the guild (Task 6); nothing on any other prefix or route
    yes(#sent>0); for _,m in ipairs(sent) do eq(m.prefix,"LEGW1"); eq(m.kind,"GUILD") end
    eq(forbidden,0); no(N.Main.error)
end)
-- Task 6: guild relay (LEGW1)
local function hx(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function weRec(N,over)
    local t={src="we",kind="group",origin="Scout",via="Scout",route="PARTY",rid="1",zone=100,x=.4,y=.5,count=2,
        enemies={{hash="abc",class="MAGE",level=40},{hash="def"}},layer={ns="server",value="8000"},heard=100,age=5,share="public"}
    for k,v in pairs(over or {}) do t[k]=v end
    return assert(N.Record.new(t))
end
local function relayed(N) local out={}; for _,m in ipairs(sent) do if m.prefix=="LEGW1" then out[#out+1]=m end end; return out end
test("relay round-trips a we record and an hh record",function()
    local N=loadAddon(); local R=N.Relay
    local text=R.encode(weRec(N),110)
    eq(text,"R|1|we|group|"..hx("Scout").."|1|100|400|500|2|s|8000|15|abc:MAGE:40,def::")
    local r=R.decode(text,"Relayer",200)
    yes(r); eq(r.src,"guild"); eq(r.label,"we"); eq(r.kind,"group"); eq(r.origin,"Scout"); eq(r.via,"Relayer"); eq(r.route,"GUILD")
    eq(r.rid,"1"); eq(r.zone,100); eq(r.x,.4); eq(r.y,.5); eq(r.count,2); eq(r.layer.ns,"server"); eq(r.layer.value,"8000")
    eq(r.heard,185); eq(r.share,"guild"); eq(#r.enemies,2); eq(r.enemies[1].hash,"abc"); eq(r.enemies[1].class,"MAGE"); eq(r.enemies[1].level,40)
    eq(r.enemies[2].hash,"def"); eq(r.enemies[2].class,nil); eq(r.id,"guild:scout:1"); eq(R.key(r),"we:scout:1")
    -- an edge coordinate of 1.0 goes as 999 (.999), like HeadHunter's own encoding
    local edge=R.encode(weRec(N,{x=1,y=0}),100); yes(edge:find("|100|999|0|",1,true)); eq(R.decode(edge,"Gee",100).x,.999)
    -- HeadHunter fight with names, a zoneUID layer, no position; and an outlaw
    local hh=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",via="Carrier",route="WHISPER",rid="1800000000",zone=100,count=2,
        enemies={{name="Kora Reed",class="PALADIN",level=31},{name="Ann Lee",level=-1}},layer={ns="zoneuid",value=4},heard=100,age=0,share="public"}))
    r=R.decode(R.encode(hh,100),"Relayer",100)
    -- its zoneUID layer is not sent: a relayed HeadHunter record has no layer (r2)
    yes(r); eq(r.label,"hh"); eq(r.kind,"fight"); eq(r.origin,"Mira Vale"); eq(r.x,nil); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"PALADIN"); eq(r.enemies[1].level,31); eq(r.enemies[2].name,"Ann Lee"); eq(r.enemies[2].level,-1)
    local outlaw=assert(N.Record.new({src="hh",kind="outlaw",origin="Spotter",route="PARTY",rid="abc:1800000000",zone=100,count=1,
        enemies={{name="Kora Reed"}},layer={ns="unknown"},heard=100,age=0,share="public"}))
    r=R.decode(R.encode(outlaw,100),"Relayer",100); yes(r); eq(r.kind,"outlaw"); eq(r.rid,"abc:1800000000"); eq(r.layer.ns,"unknown")
    -- end to end: a party report goes to the guild once, after the wait
    N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    eq(#relayed(N),0); advance(1); eq(#relayed(N),0); advance(1.1)
    local out=relayed(N); eq(#out,1); eq(out[1].kind,"GUILD"); eq(out[1].target,nil)
    local back=R.decode(out[1].text,"Exx",clock); eq(back.origin,"Scout"); eq(back.layer.value,"8000"); eq(#back.enemies,1); eq(back.enemies[1].hash,"abc")
    advance(200); eq(#relayed(N),1); eq(forbidden,0)
end)
test("relay skips records heard on GUILD",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); report(1,8000,"Scout"); advance(5); eq(#sent,0)
    no(N.Relay.offer(N.Main.relay,weRec(N,{route="GUILD",share="guild"}),clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    no(N.Relay.offer(N.Main.relay,weRec(N,{share="guild"}),clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    -- a relayed G from War Effort's own guild path is guild traffic too
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); advance(5); eq(#sent,0)
end)
test("relay never re-relays a guild record",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{heard=clock,age=0}),clock),"GUILD","Guildie")
    eq(N.Main.lastDrop,"relayed we"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(5); eq(#sent,0)
    local stored=N.Store.rows(N.Main.store,clock,"reported")[1].record
    no(N.Relay.offer(N.Main.relay,stored,clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    -- a relay never claims to be first-hand: own/guild/unknown sources are refused
    for _,src in ipairs({"own","guild","LEGW1",""}) do
        eq(N.Relay.decode("R|1|"..src.."|group|"..hx("Scout").."|9|100|||1|u||0|","Guildie",clock),nil,src)
    end
end)
test("relay stands down when another guildmate sends first",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    yes(N.Main.relay.pending["we:scout:1"])
    advance(1)
    local copy=N.Relay.encode(N.Main.relay.pending["we:scout:1"].record,clock)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick")
    eq(N.Main.relay.pending["we:scout:1"],nil); advance(5); eq(#relayed(N),0)
    -- the guildmate's copy and our first-hand record are one report and one reporter
    eq(N.Safe.count(N.Main.store.reports),1); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    eq(#N.Store.reporters(N.Main.store,clock),1)
end)
test("relay sends each id once in 120 s",function()
    local N=loadAddon(); local R=N.Relay; local st=R.new(); local ctx={inGuild=true,inInstance=false,guild="Test Guild"}
    R.rand=function() return .5 end
    local rec=weRec(N); yes(R.offer(st,rec,100,ctx)); eq(#R.tick(st,100.4),0); eq(#R.tick(st,100.5),1)
    no(R.offer(st,rec,160,ctx)); no(R.offer(st,weRec(N,{route="RAID"}),219,ctx))
    yes(R.offer(st,rec,220,ctx))
    -- two guildmates relaying the same report: the guild sees it once
    N=loadAddon(); establish(N); advance(1)
    local text=R.encode(weRec(N,{heard=clock,age=0}),clock)
    deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","One"); deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Two")
    eq(N.Main.lastDrop,"duplicate"); eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),0)
    -- 256 remembered ids at most
    st=R.new(); for i=1,300 do R.offer(st,weRec(N,{rid=tostring(i)}),100,ctx); R.clear(st) end; eq(st.n,256)
end)
test("relay drops instead of queueing when only the own reserve remains",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    for i=1,7 do N.Main.offerRelay(weRec(N,{origin="Scout"..string.char(96+i),heard=clock})) end
    advance(1); eq(#relayed(N),3); eq(N.Main.lastRelay,"own reserve")
    eq(next(N.Main.relay.pending),nil)
    advance(30); eq(#relayed(N),3)
    -- the bucket refills: a new record goes
    N.Main.offerRelay(weRec(N,{origin="Later",heard=clock})); advance(1); eq(#relayed(N),4)
end)
test("relayed record is labelled and not first-hand",function()
    local N=loadAddon(); establish(N); advance(20)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{heard=clock-10,age=0}),clock),"GUILD","Guildie")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,2)
    local r=rows[1].record; eq(r.src,"guild"); eq(r.label,"we"); eq(r.via,"Guildie"); eq(r.origin,"Scout"); eq(r.heard,clock-10)
    eq(rows[1].source,"relayed by Guildie (War Effort)"); eq(rows[1].confidence,"reported, not confirmed")
    eq(rows[1].relation,"other")
    -- a relayed reporter was in someone else's group: not an invite candidate
    eq(#N.Store.reporters(N.Main.store,clock),0)
    -- no hop through the War Effort chat fallback for a relayed record: the origin was in someone else's group
    eq(N.Hop.candidate(r,{}),nil)
    -- the first-hand report of the same id replaces the relayed copy
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    rows=N.Store.rows(N.Main.store,clock,"reported"); eq(rows[1].record.src,"we"); eq(N.Safe.count(N.Main.store.reports),1)
    -- a HeadHunter relay: label and a tracked name found by name
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    local hh=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",route="WHISPER",rid="5",zone=100,count=1,
        enemies={{name="Kora Reed",class="PALADIN",level=31}},layer={ns="zoneuid",value=4},heard=clock,share="public"}))
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(hh,clock),"GUILD","Guildie")
    local hrow; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.label=="hh" then hrow=row end end
    eq(hrow.source,"relayed by Guildie (HeadHunter fight)"); eq(hrow.name,"Kora Reed"); eq(hrow.relation,"unknown")
    local loc=N.Main.find.locations["Kora Reed"]; yes(loc); eq(loc.spotter,"Mira Vale"); eq(loc.zone,100)
    -- origin is us, or ignored: dropped
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me",rid="7",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me-TestRealm",rid="17",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(n) return n=="Bad Guy" end
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Bad Guy",rid="8",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Fine",rid="9",heard=clock,age=0}),clock),"GUILD","Bad Guy"); eq(N.Main.lastDrop,"ignored sender")
    C_FriendList.IsIgnored=old; eq(#sent,0)
end)
test("relay rejects format version 2 and oversize",function()
    local N=loadAddon(); local R=N.Relay
    local good=R.encode(weRec(N),100)
    local v2=good:gsub("^R|1|","R|2|"); local r,why=R.decode(v2,"Gee",100); eq(r,nil); eq(why,"version")
    eq(R.decode(good..string.rep(",",256-#good),"Gee",100),nil); eq(R.decode(string.rep("R",256),"Gee",100),nil)
    local bad={good:gsub("|abc:MAGE:40,def::$",""),good.."|x",good:gsub("|100|400|","|100|1000|"),good:gsub("|2|s|","|81|s|"),
        good:gsub("|5|abc","|901|abc"),good:gsub("|s|","|q|"),good.." ",good:gsub("^R","Q"),good:gsub(hx("Scout"),"5"),good:gsub("abc:MAGE:40","abc:MAGE:101"),
        good:gsub("abc:MAGE:40","abcde:MAGE:40"),good:gsub("abc:MAGE:40","abzz:MAGE:40"),good:gsub("abc:MAGE:40","ab:MAGE:40"),
        good:gsub("abc:MAGE:40","0a41:MAGE:40")}
    for _,text in ipairs(bad) do eq(R.decode(text,"Gee",100),nil,text) end
    -- too many enemies: as many as fit go, the rest is dropped
    local many={}; for i=1,80 do many[i]={hash=string.format("%03d",i),class="WARRIOR",level=60} end
    local big=R.encode(weRec(N,{count=80,enemies=many}),100); yes(#big<=255); local back=R.decode(big,"Gee",100); yes(back); yes(#back.enemies>5 and #back.enemies<80)
    -- a record that does not fit even without enemies, or is too old, is not sent
    yes(#R.encode(weRec(N,{origin=string.rep("a",36).." "..string.rep("b",36).."-"..string.rep("c",26)}),100)<=255)
    eq(R.encode(weRec(N,{origin=string.rep("a",36).." "..string.rep("b",36).."-"..string.rep("c",26),rid=string.rep("9",24),layer={ns="unknown",value=string.rep("7",32)}}),100),nil)
    eq(R.encode(weRec(N,{heard=0,age=0}),901),nil)
end)
test("relay silent outside a guild",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    inGuild=false; hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{rid="2",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Safe.count(N.Main.store.reports),1)
    inGuild=true; inInstance=true; report(3,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    IsInInstance=function() return nil end; advance(10); report(4,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    IsInInstance=function() return false end; advance(10); report(5,8000,"Scout",nil,"PARTY"); advance(5); eq(#relayed(N),1)
    -- only GUILD carries LEGW1, and our own echo is not read
    local text=N.Relay.encode(weRec(N,{rid="6",heard=clock,age=0}),clock)
    for _,kind in ipairs({"PARTY","RAID","WHISPER"}) do deliver("CHAT_MSG_ADDON","LEGW1",text,kind,"Guildie") end
    deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Me-TestRealm")
    local n=0; for _,row in pairs(N.Main.store.reports) do if row.record.rid=="6" then n=n+1 end end; eq(n,0); eq(forbidden,0)
end)
test("hh only P, L and E frames count against the rate (مانع T4 S1)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local function P() return "1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4" end
    -- مانع's probe: six N frames from a party member, then a real P
    for i=1,6 do deliver("CHAT_MSG_ADDON","HeadHunter","1AN:1.1.1;x"..i,"PARTY","Mira Vale") end
    for i=1,6 do deliver("CHAT_MSG_ADDON","HeadHunter","garbage "..i,"PARTY","Mira Vale") end
    deliver("CHAT_MSG_ADDON","HeadHunter",P(),"PARTY","Mira Vale")
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1); eq(N.Main.lastDrop,"headhunter fight")
    -- P, L and E frames still count: five more, then the 7th is dropped
    for i=1,5 do deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Ann Lee"..string.char(96+i)..";2s;"..b36(server)..";dw;6y","PARTY","Mira Vale") end
    eq(N.Safe.count(N.Main.store.reports),6)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Bo Ray;2s;"..b36(server)..";dw;6y","PARTY","Mira Vale"); eq(N.Safe.count(N.Main.store.reports),6)
    eq(#sent,0); no(N.Main.error)
end)
test("hh E envelope fields are checked (مانع T4 S2)",function()
    local N=loadAddon()
    local function env(world,server,hops,first) return "1AE:"..world..";Mira Vale;A;"..server..";"..hops..";"..first..";P13k;tro8w0;dw;6y;a1" end
    eq(#hh(N,env("eu-pvp","5cy","1","tro8w0"),"Carrier"),1)
    eq(#hh(N,env(string.rep("w",40),"0","5","0"),"Carrier"),1)                       -- limits that pass
    eq(#hh(N,env("eu-pvp","0123456789","1","tro8w0"),"Carrier"),1)
    for _,bad in ipairs({
        env("","5cy","1","tro8w0"), env(string.rep("w",41),"5cy","1","tro8w0"), env("eu\1pvp","5cy","1","tro8w0"), env("eu\npvp","5cy","1","tro8w0"),
        env("eu-pvp","5CY","1","tro8w0"), env("eu-pvp","","1","tro8w0"), env("eu-pvp","5c-y","1","tro8w0"), env("eu-pvp","0123456789a","1","tro8w0"),
        env("eu-pvp","5cy","0","tro8w0"), env("eu-pvp","5cy","6","tro8w0"), env("eu-pvp","5cy","10","tro8w0"), env("eu-pvp","5cy","","tro8w0"), env("eu-pvp","5cy","A","tro8w0"),
        env("eu-pvp","5cy","1",""), env("eu-pvp","5cy","1","00000tro8w0"), env("eu-pvp","5cy","1","TRO8W0") }) do
        eq(#hh(N,bad,"Carrier"),0,bad)
    end
    -- through the addon, a bad envelope leaves no row
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5CY;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Safe.count(N.Main.store.reports),0); eq(N.Main.lastDrop,"invalid")
end)
test("hh bounds: base36 digits, allies, frame size, rate table (مانع T4 S3)",function()
    local N=loadAddon()
    eq(#hh(N,"1AP:13k;0000tro8w0;dw;6y;a1"),1); eq(#hh(N,"1AP:13k;00000tro8w0;dw;6y;a1"),0)      -- 10 digits pass, 11 fail
    local ids={}; for i=1,12 do ids[#ids+1]="+a"..i end
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;e1,"..table.concat(ids,",")),1)
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;e1,"..table.concat(ids,",")..",+a13"),0)                    -- 13 allies
    -- a 255-byte frame is read, 256 is not (decoder and addon): 12 long enemy ids, then a name padded to size
    local function frame(n,map,t) local ids={}; for i=1,12 do ids[i]=string.format("e%015d",i) end
        local head="1AP:"..map..";"..t..";dw;6y;"..table.concat(ids,",")..";"
        local f=head..string.rep("k",n-#head-4).."//;4"; eq(#f,n); return f end
    yes(hh(N,frame(255,"13k","tro8w0"))[1]); eq(#hh(N,frame(256,"13k","tro8w0")),0)
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter",frame(255,"2s",b36(server)),"PARTY","Mira Vale"); eq(N.Safe.count(N.Main.store.reports),1)
    deliver("CHAT_MSG_ADDON","HeadHunter",frame(256,"2s",b36(server)),"PARTY","Ann Lee"); eq(N.Safe.count(N.Main.store.reports),1)
    -- the rate table holds 512 senders; the 513th waits for the window
    local st=N.HeadHunter.new()
    for i=1,512 do yes(N.HeadHunter.allow(st,"S"..i,0)) end
    no(N.HeadHunter.allow(st,"S513",5)); eq(st.n,512); yes(N.HeadHunter.allow(st,"S513",10))
end)
test("hh carrier ignore and secrets on every event argument (مانع T4 S3)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local E="1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1"
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(name) return name=="Carrier" end
    deliver("CHAT_MSG_ADDON","HeadHunter",E,"WHISPER","Carrier"); eq(N.Main.lastDrop,"ignored sender"); eq(N.Safe.count(N.Main.store.reports),0)
    C_FriendList.IsIgnored=old
    for i=1,8 do
        N=loadAddon(); establish(N); advance(1); server=HHT
        local args={"HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","PARTY","Mira Vale","Me",0,0,""}
        args[i]=secret; N.Main.lastDrop="untouched"
        deliver("CHAT_MSG_ADDON",args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8])
        eq(N.Safe.count(N.Main.store.reports),0,i); eq(N.Main.lastDrop,"untouched",i); no(N.Main.error,i)
    end
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","PARTY","Mira Vale","Me",0,0,""); eq(N.Safe.count(N.Main.store.reports),1)
end)
test("hh count is the number of enemy ids; rows show via <carrier>",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;;Kora Reed/P/31;4")[1]; yes(r); eq(r.count,0); eq(#r.enemies,1)
    eq(hh(N,"1AP:13k;tro8w0;dw;6y;a1,+b2,+c3;Ann Lee//,Bo Ray//;4")[1].count,1)
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server-1)..";dw;6y;b2","PARTY","Ann Lee")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); local via={}
    for _,row in ipairs(rows) do via[row.reporter]=row.via or "none" end
    eq(via["Mira Vale"],"Carrier"); eq(via["Ann Lee"],"none")
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("reported by Mira Vale via Carrier",1,true)); no(table.concat(log,"\n"):find("Ann Lee via",1,true))
    -- War Effort G: the relaying guildmate is the carrier
    N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||C|42|100|0.4|0.5|7086|4|"..stamp,"GUILD","Relay")
    rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].reporter,"Scout"); eq(rows[1].via,"Relay")
    -- the window line too
    N.UI.toggle(); N.UI.select("reported"); eq(N.UI.pool[1].sub.text,"reported by Scout via Relay · relayed")
end)
test("relayed origins never become Find spotters (مانع T6 F1)",function()
    local N=loadAddon(); chatBox(); establish(N); advance(20); local U=N.UI
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    local hhRec=weRec(N,{src="hh",kind="fight",origin="Stranger",share="public",layer={ns="unknown"},count=1,heard=clock,age=0,
        enemies={{name="Kora Reed",class="PALADIN",level=31}}})
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(hhRec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed hh")
    U.toggle(); U.tabs.find:Click()
    eq(U.pool[1].title.text,"Kora Reed"); yes(U.pool[1].sub.text:find("seen in a relayed report",1,true)); no(U.pool[1].sub.text:find("Stranger",1,true))
    no(U.pool[1].ask:IsShown())
    no(LE.AskInvite("Stranger")); drain(); eq(#opened,0); eq(#sent,0)
    -- the same name reported first-hand afterwards can be asked again
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4","PARTY","Mira Vale")
    U.render(); yes(U.pool[1].sub.text:find("Seen by Mira Vale",1,true)); yes(U.pool[1].ask:IsShown())
end)
test("relay rechecks guild and instance at send time (مانع T6 S1)",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    local function try(change) N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
        N.Main.offerRelay(weRec(N,{heard=clock})); yes(next(N.Main.relay.pending)); change(); advance(1); local n=#relayed(N); inGuild,inInstance,guildName=true,false,"Test Guild"; return n end
    eq(try(function() end),1)
    eq(try(function() guildName="Other Guild" end),0)
    eq(try(function() inGuild=false end),0)
    eq(try(function() inInstance=true end),0)
    eq(try(function() inInstance=nil end),0)
    eq(try(function() guildName=nil end),0)
    -- no readable guild name: nothing is offered
    N=loadAddon(); establish(N); advance(1); guildName=nil
    no(N.Relay.offer(N.Main.relay,weRec(N),clock,N.Main.relayContext())); guildName="Test Guild"
end)
test("relayed HeadHunter lives 300 s from origin time (مانع T6 S2)",function()
    local N=loadAddon(); establish(N); advance(250); local R=N.Relay
    local function hhAt(age,rid) return weRec(N,{src="hh",kind="fight",rid=rid,share="public",layer={ns="unknown"},count=1,heard=clock,age=age,enemies={}}) end
    eq(select(2,R.decode(R.encode(hhAt(300,"1"),clock),"Guildie",clock)),"too old")
    yes(R.decode(R.encode(hhAt(299,"2"),clock),"Guildie",clock))
    -- War Effort copies: 600 s
    eq(select(2,R.decode(R.encode(weRec(N,{heard=clock,age=600}),clock),"Guildie",clock)),"too old")
    yes(R.decode(R.encode(weRec(N,{heard=clock,age=599}),clock),"Guildie",clock))
    -- stored: a 200 s old relayed fight goes after 100 more seconds
    deliver("CHAT_MSG_ADDON","LEGW1",R.encode(hhAt(200,"3"),clock),"GUILD","Guildie"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(99); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),1)
    advance(1); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),0)
end)
test("relay rejects bad levels, self-relays, and caps pending offers (مانع T6 S3, S4)",function()
    local N=loadAddon(); establish(N); advance(20); local R=N.Relay
    local good=R.encode(weRec(N,{heard=clock,age=0}),clock); yes(R.decode(good,"Guildie",clock))
    for _,lvl in ipairs({"-","--1","1-","-0-","1-2"}) do eq(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:"..lvl),"Guildie",clock),nil,lvl) end
    yes(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:-1"),"Guildie",clock)); yes(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:"),"Guildie",clock))
    -- origin Scout sent by Scout (any realm form) is not a relay
    eq(select(2,R.decode(good,"Scout",clock)),"origin is sender"); eq(select(2,R.decode(good,"scout-TestRealm",clock)),"origin is sender")
    yes(R.decode(good,"Scout-OtherRealm",clock)==nil)
    yes(R.decode(R.encode(weRec(N,{origin="Scout-RealmA",heard=clock,age=0}),clock),"Scout-RealmB",clock))
    deliver("CHAT_MSG_ADDON","LEGW1",good,"GUILD","Scout"); eq(N.Main.lastDrop,"relay origin is sender"); eq(N.Safe.count(N.Main.store.reports),0)
    -- a relayed HeadHunter copy claiming a server layer is still not comparable; a relayed War Effort one is
    -- a relayed HeadHunter copy claiming any layer is refused (r2); a relayed War Effort one compares
    local crafted=good:gsub("|we|group|","|hh|fight|",1)
    eq(select(2,R.decode(crafted,"Guildie",clock)),"invalid")
    eq(select(2,R.decode(crafted:gsub("|s|8000|","|z|4|",1),"Guildie",clock)),"invalid")
    yes(R.decode(crafted:gsub("|s|8000|","|u||",1),"Guildie",clock))
    eq(N.Record.relation(R.decode(good,"Guildie",clock),{zone=100,server="7000"}),"other")
    -- 128 pending offers at most
    local st=R.new(); local ctx={inGuild=true,inInstance=false,guild="Test Guild"}
    for i=1,130 do R.offer(st,weRec(N,{rid=tostring(i)}),100,ctx) end
    local n=0; for _ in pairs(st.pending) do n=n+1 end; eq(n,128); no(R.offer(st,weRec(N,{rid="999"}),100,ctx))
end)
test("a stored relay replayed into Find stays unaskable (r2)",function()
    for _,src in ipairs({"hh","we"}) do
        for _,mode in ipairs({"slash","button","unrelated"}) do
            local N=loadAddon(); chatBox(); establish(N); advance(2); local U=N.UI
            local name=src=="hh" and "Kora Reed" or "Alice"
            local enemy=src=="hh" and {name=name,class="PALADIN",level=31} or {hash=N.Hash.player(name,""),class="PALADIN",level=31}
            local rec=assert(N.Record.new({src=src,kind=src=="hh" and "fight" or "group",origin="Stranger",route="PARTY",rid="1",zone=100,count=1,
                enemies={enemy},layer={ns="unknown"},heard=clock,share="public"}))
            if mode=="unrelated" then SlashCmdList.LAYERENEMIES("find "..name) end
            deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed "..src,src..mode)
            U.toggle(); U.tabs.find:Click()
            if mode=="button" then U.input:SetText(name); U.add:Click()
            else SlashCmdList.LAYERENEMIES("find "..(mode=="unrelated" and "Otherenemy" or name)); U.render() end
            local row; for _,r in ipairs(N.Main.findRows()) do if r.name==name then row=r end end
            yes(row and row.spotter,src..mode); no(row.canAsk,src..mode)
            local i; for k,r in ipairs(U.pool) do if r.title.text==name then i=k end end
            no(U.pool[i].ask:IsShown(),src..mode); U.pool[i].ask:Click(); no(LE.AskInvite("Stranger"),src..mode); drain(); eq(#opened,0,src..mode)
        end
    end
end)
test("a duplicate relay does not make a first-hand Find row unaskable (r2)",function()
    local N=loadAddon(); chatBox(); establish(N); advance(2)
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4","PARTY","Mira Vale")
    local function row() for _,r in ipairs(N.Main.findRows()) do if r.name=="Kora Reed" then return r end end end
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- a guildmate relays the same fight back to us: a duplicate, Find unchanged
    local rec=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",route="PARTY",rid=tostring(math.floor(server)),zone=100,count=1,
        enemies={{name="Kora Reed",class="PALADIN",level=31}},layer={ns="unknown"},heard=clock,share="public"}))
    advance(1); deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"duplicate")
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- another relayed fight with the name, newer: still the first-hand row while it is fresh
    rec=assert(N.Record.new({src="hh",kind="fight",origin="Stranger",route="PARTY",rid="77",zone=100,count=1,
        enemies={{name="Kora Reed"}},layer={ns="unknown"},heard=clock,share="public"}))
    advance(1); deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed hh")
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- tracking again replays the store: the first-hand row still wins
    SlashCmdList.LAYERENEMIES("find Other Name"); yes(row().canAsk); eq(row().spotter,"Mira Vale")
end)
test("relayed reporters are never invite candidates",function()
    local N=loadAddon(); establish(N); advance(20)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Stranger",heard=clock,age=0}),clock),"GUILD","Guildie")
    eq(N.Main.lastDrop,"relayed we"); eq(#N.Store.rows(N.Main.store,clock,"reported"),2)
    eq(#N.Store.reporters(N.Main.store,clock),0); eq(#N.Main.candidates(),0)
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("No one to ask right now.")); no(logged("Stranger"))
    no(LE.AskInvite("Stranger")); eq(#sent,0)
    -- the same origin heard first-hand is a candidate again
    hello("Stranger",19,"PARTY"); report(1,8000,"Stranger",nil,"PARTY")
    eq(#N.Store.reporters(N.Main.store,clock),1); eq(N.Main.candidates()[1].name,"Stranger")
end)
test("relay receive limit: 12 per 10 s per sender",function()
    local N=loadAddon(); establish(N); advance(20)
    local function from(who,rid) deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="O"..who..abc(rid),rid=tostring(rid),heard=clock,age=0}),clock),"GUILD",who) end
    for i=1,13 do from("Busy",i) end
    eq(N.Safe.count(N.Main.store.reports),12)
    N.Main.lastDrop="before"; from("Busy",14); eq(N.Main.lastDrop,"before")    -- dropped silently
    from("Calm",1); eq(N.Safe.count(N.Main.store.reports),13)                 -- per sender
    advance(10); from("Busy",15); eq(N.Safe.count(N.Main.store.reports),14)
    -- the limit table is bounded too
    local st=N.Relay.new(); for i=1,600 do N.Relay.allow(st,"S"..i,0) end; yes(st.nrates<=512)
end)
-- Wire.lua: the only sender
local LSX="inv layer <LS 1429 want 7086-0>"
test("the send mock counts any caller but Wire.lua as forbidden",function()
    local N=loadAddon()
    -- a direct call, a pcall-wrapped call and a dynamically named call from outside Wire.lua all count
    C_ChatInfo.SendAddonMessage("LayerSwap","x","WHISPER","Alice"); eq(forbidden,1)
    pcall(function() C_ChatInfo["Send".."AddonMessage"]("LayerSwap","x","WHISPER","Alice") end); eq(forbidden,2)
    pcall(C_ChatInfo.SendAddonMessage,"LEGW1","x","GUILD"); eq(forbidden,3)
    -- the same routes through Wire.lua do not
    forbidden=0; yes(N.Wire.send("LayerSwap",LSX,"WHISPER","Alice")); yes(N.Wire.send("LEGW1","x","GUILD")); eq(forbidden,0); eq(#sent,5)
end)
test("wire routes cannot be opened from outside",function()
    local N=loadAddon(); local Wr=N.Wire
    if type(Wr.ROUTES)=="table" then
        Wr.ROUTES.WEFF1={GUILD=true}; if type(Wr.ROUTES.LayerSwap)=="table" then Wr.ROUTES.LayerSwap.GUILD=true end
        if type(Wr.ROUTES.LEGW1)=="table" then Wr.ROUTES.LEGW1.WHISPER=true end
    end
    Wr.ROUTES={WEFF1={GUILD=true},LayerSwap={GUILD=true,CHANNEL=true}}
    for _,c in ipairs({{"WEFF1","x","CHANNEL","5"},{"LayerSwap","x","GUILD"},{"LEGW1","x","WHISPER","Bob"}}) do
        local ok,why=Wr.send(c[1],c[2],c[3],c[4]); no(ok); eq(why,"blocked route")
    end
    eq(#sent,0); yes(Wr.send("LayerSwap",LSX,"WHISPER","Alice")); eq(#sent,1)
end)
test("wire sends only on the allowed routes",function()
    local N=loadAddon(); local Wr=N.Wire
    local function blocked(...) local ok,why=Wr.send(...); no(ok); eq(why,"blocked route") end
    blocked("WEFF1","x","CHANNEL","5"); blocked("LayerSwap","x","GUILD"); blocked("LEGW1","x","WHISPER","Bob")
    blocked("LayerSwap","x","CHANNEL","5"); blocked("HeadHunter","1AN:x","GUILD"); blocked("LFSw","Q","WHISPER","Bob")
    blocked("ForeverSpy1","x","PARTY"); blocked("GBOUNTY","D|x","GUILD")
    -- WEFF1 and HeadHunter routes exist from 1.0 T1, but text outside their types fails, and their networks ship off
    local ok0,why0=Wr.send("WEFF1","x","GUILD"); no(ok0); eq(why0,"bad text")
    ok0,why0=Wr.send("WEFF1","H|0.1.0","GUILD"); no(ok0); eq(why0,"network off")
    ok0,why0=Wr.send("HeadHunter","1AP:x","WHISPER","Bob"); no(ok0); eq(why0,"bad text")
    local ok,why=Wr.send("LFSw","x","GUILD"); no(ok); eq(why,"bad text")
    eq(#sent,0)
    eq(Wr.ROUTES.LayerSwap.WHISPER,true); eq(Wr.ROUTES.LEGW1.GUILD,true)
    local ok,why=Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0 48.2,42.5>","WHISPER","Alice"); yes(ok); eq(why,"sent")
    ok,why=Wr.send("LEGW1","R|1","GUILD"); yes(ok); eq(why,"sent")
    eq(#sent,2); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Alice")
    eq(sent[2].prefix,"LEGW1"); eq(sent[2].kind,"GUILD"); eq(sent[2].target,nil); eq(forbidden,0)
end)
test("wire rejects oversize and secret text",function()
    local N=loadAddon(); local Wr=N.Wire
    local function bad(...) local ok,why=Wr.send(...); no(ok); eq(why,"bad text") end
    bad("LEGW1",string.rep("a",256),"GUILD"); bad("LEGW1","","GUILD"); bad("LEGW1",secret,"GUILD"); bad("LEGW1",42,"GUILD")
    bad("LayerSwap",LSX,"WHISPER",secret); bad("LayerSwap",LSX,"WHISPER","B"); bad("LayerSwap",LSX,"WHISPER",nil)
    bad("LayerSwap",LSX,"WHISPER","Bad|Name")
    local ok,why=Wr.send(secret,"x","GUILD"); no(ok); eq(why,"bad text")
    ok,why=Wr.send("LEGW1","x",secret); no(ok); eq(why,"bad text")
    eq(#sent,0)
    ok=Wr.send("LEGW1",string.rep("a",255),"GUILD"); yes(ok); eq(#sent,1)
    ok=Wr.send("LayerSwap",LSX,"WHISPER","First Surname"); yes(ok); eq(#sent,2)
end)
test("wire maps client results",function()
    local N=loadAddon(); local Wr=N.Wire
    local function try(r,want) sendResult=r; local ok,why=Wr.send("LayerSwap",LSX,"WHISPER","Alice"); eq(why,want); eq(ok,want=="sent") end
    -- 1.0 T1: 3 and 8 are throttles and pause the prefix 30 s (the next send there is "paused" without asking)
    try(0,"sent"); try(3,"throttled"); try(0,"paused"); advance(31); try(8,"throttled"); advance(31); try(1,"refused")
    advance(3); try(function() error("boom") end,"error")
    eq(#sent,5); no(N.Main.error); eq(forbidden,0)
    C_ChatInfo=nil; local ok,why=Wr.send("LayerSwap",LSX,"WHISPER","Alice"); no(ok); eq(why,"error")
end)
test("wire guild bucket",function()
    local N=loadAddon(); local Wr=N.Wire
    local got={}
    for i=1,6 do local ok,why=Wr.send("LEGW1","m"..i,"GUILD"); got[#got+1]=why end
    eq(table.concat(got,","),"sent,sent,sent,sent,sent,throttled"); eq(#sent,5)
    advance(1); local ok,why=Wr.send("LEGW1","m7","GUILD"); no(ok); eq(why,"throttled"); eq(#sent,5)
    advance(1); ok,why=Wr.send("LEGW1","m8","GUILD"); yes(ok); eq(why,"sent"); eq(#sent,6)
    -- 1.0 T1: every prefix has its own bucket of 5, and all sends share 8 at once (6 spent here, 1.3 refilled)
    local okW=0; for i=1,8 do if Wr.send("LayerSwap",LSX,"WHISPER","Alice") then okW=okW+1 end end
    eq(okW,3,"the shared bucket"); eq(#sent,9)
    advance(100); okW=0; for i=1,8 do if Wr.send("LayerSwap",LSX,"WHISPER","Alice") then okW=okW+1 end end; eq(okW,5,"the prefix bucket")
    -- refill caps at 5
    advance(100); for i=1,6 do Wr.send("LEGW1","r"..i,"GUILD") end; eq(#sent,19)
end)

-- 0.3.1 core: hosts while our own layer is unknown, hop to a host, remembered LayerSwap replies.
local HINT="Your layer is not known yet: target or mouse over two different kinds of NPC within 15 seconds."
local function guildLine(text,from) deliver("CHAT_MSG_ADDON","LFSw",text,"GUILD",from) end
local function slash(text) SlashCmdList.LAYERENEMIES(text); drain() end
test("0.3.1 T3: hosts are listed while our own layer is unknown; nothing is sent or drafted",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Bob")
    eq(N.Main.store.bulo,nil,"own layer unknown")
    slash("hosts")
    yes(logged("1. Bob | layer 8000 | Bulo | host"),"host listed"); yes(logged(HINT),"hint in /le hosts")
    eq(#log>0 and log[#log]:find("mouse over",1,true),nil)
    local before=#log
    slash("hop host 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find(HINT,1,true),"hop host refuses with the hint"); yes(#log>before)
    slash("ask 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find(HINT,1,true),"ask refuses with the hint")
    -- the shared path (window button and /le hop host) refuses on its own too
    local row=N.Main.candidates()[1]; no(N.Main.hopHostTo(row,nil)); eq(#sent,0); yes(log[#log]:find(HINT,1,true))
    row.unknownOwn=nil; no(N.Main.hopHostTo(row,nil)); eq(#sent,0); yes(log[#log]:find(HINT,1,true),"own key unknown alone refuses")
    -- /le list shows the hint too
    log={}; slash("list"); yes(logged(HINT),"hint in /le list")
    -- two NPC readings: the same row becomes hoppable, the hint goes
    establish(N); log={}; slash("list"); no(logged(HINT),"no hint once known")
    log={}; slash("hosts"); no(logged(HINT)); yes(logged("1. Bob | layer 8000 | Bulo | host"))
    slash("hop host 1"); eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob")
    eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(forbidden,0)
end)
test("0.3.1 T3: Invite.collect marks rows while unknown; a report hop never picks them",function()
    local N=loadAddon(); guildLine("L 8000|100|h","Bob")
    local list,status=N.Main.candidates()
    eq(#list,1); eq(list[1].name,"Bob"); yes(list[1].unknownOwn); no(list[1].same)
    yes(status.bulo:find("your layer is not known yet",1,true),status.bulo)
    eq(N.Invite.HINT,HINT)
    -- a report on 8000 while our layer is unknown: the hop does not go through the unknown-layer row (0.3.0 behaviour)
    -- (the War Effort origin of the record stays the 0.3.0 fallback: a chat whisper, no addon)
    local c=N.Hop.candidate(rec(N),(N.Main.candidates())); yes(c); eq(c.name,"Scout"); no(c.addon)
    establish(N); list=N.Main.candidates(); no(list[1].unknownOwn)
end)
test("0.3.1 T3: the window shows the hint and disables the row button while unknown",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Bob")
    local U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].title.text,"Bob"); yes(U.pool[1].ask.disabled,"disabled"); eq(U.pool[1].ask.reason,HINT)
    eq(U.banner.text,HINT); yes(U.meta.text:find("mouse over or target two different kinds of NPC within 15 s",1,true),U.meta.text)
    U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,0)
    establish(N); U.render(); no(U.pool[1].ask.disabled); eq(U.banner.text,"")
end)
test("0.3.1 T2: /le hop host sends one LayerSwap whisper through Hop.request, with its cooldowns",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob"); guildLine("L 9000|100|-","Dan")
    slash("hosts"); yes(logged("/le hop host <number>"),"names the command")
    slash("hop host 1"); eq(#sent,1); eq(sent[1].target,"Bob"); eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>")
    yes(logged("asked Bob (Bulo) for an invite to layer 8000. Accept the invite yourself; nothing else is sent."))
    eq(N.Main.hop.pending.name,"Bob"); eq(N.Main.invite.pending.target,"8000")
    slash("hop host 1"); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true),log[#log])
    slash("hop host 2"); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true),log[#log])
    advance(10); slash("hosts"); slash("hop host 2"); eq(#sent,2); eq(sent[2].target,"Dan"); eq(sent[2].text,"inv layer <LS 100 want 9000-0 25.0,75.0>")
    grouped=true; advance(60); slash("hosts"); slash("hop host 1"); eq(#sent,2); yes(log[#log]:find("leave your current group first",1,true))
    eq(forbidden,0)
end)
test("0.3.1 T2: hop host refuses stale lists, bad numbers, changed rows, reporters and our own layer",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bob")
    slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("run /le hosts first",1,true))
    slash("hosts"); slash("hop host 9"); eq(#sent,0); yes(log[#log]:find("no such number in the last /le hosts list",1,true))
    advance(121); slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("run /le hosts first",1,true))
    -- the row changed after the list
    slash("hosts"); guildLine("L 9000|100|h","Bob"); slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("hosts changed, check again",1,true))
    -- our own layer moved onto the host's key after the list (not ambiguous)
    slash("hosts")
    units.target={guid=npc(3,7,"9000"),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(4,7,"9000"),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"9000-7")
    slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("on your layer already",1,true),log[#log])
    -- a War Effort reporter row has no layer: no hop, pointed to /le ask
    N=loadAddon(); establish(N); chatBox(); hopReport(1,8000)
    slash("hosts"); yes(logged("1. Scout | layer unknown"))
    slash("hop host 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find("/le ask 1",1,true),log[#log]); eq(forbidden,0)
end)
test("0.3.1 T2: the Friendly button hops via the host, one message per click",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bob")
    local U=N.UI; U.toggle(); U.select("friendly")
    local r=U.pool[1]; eq(r.title.text,"Bob"); eq(r.ask.label.text,"Hop via Bob"); eq(r.ask.reason,"one LayerSwap request whispered to Bob (Bulo)")
    no(r.ask.disabled)
    r.ask:Click(); drain(); eq(#sent,1); eq(sent[1].target,"Bob"); eq(#opened,0)
    U.render(); yes(r.ask.disabled,"cooldown after the click"); r.ask:Click(); drain(); eq(#sent,1)
    -- a reporter row keeps "Ask for invite" (chat box)
    N=loadAddon(); establish(N); chatBox(); hopReport(1,8000); U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].ask.label.text,"Ask for invite"); U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,1)
end)
test("0.3.1 T4: a heard|h reply from the asked player is remembered for 12 minutes, read-only",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1"); eq(#sent,1)
    local function reply(text,from,kind) deliver("CHAT_MSG_ADDON","LayerSwap",text,kind or "WHISPER",from or "Bob"); drain() end
    reply("heard Me|8000-12|100|h"); eq(#sent,1,"storing sends nothing")
    yes(N.Main.heard.heard.Bob); eq(N.Main.heard.heard.Bob.layer,"8000-12"); eq(N.Main.heard.heard.Bob.zone,100)
    -- the Bulo line goes; Bob stays a LayerSwap host with uid 12
    N.Main.guildLines.Bob=nil
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"Bob"); eq(list[1].uid,12); eq(table.concat(list[1].sources,"+"),"LayerSwap")
    advance(60); slash("hosts"); slash("hop host 1"); eq(#sent,2); eq(sent[2].text,"inv layer <LS 100 want 8000-12 25.0,75.0>")
    -- a "-" reply removes him
    reply("heard Me|8000-12|100|-"); eq(N.Main.heard.heard.Bob,nil); eq(#N.Main.candidates(),0)
    -- 12 minutes later the entry is gone
    advance(61); guildLine("L 8000|100|h","Bob"); slash("hosts"); slash("hop host 1"); eq(#sent,3)
    reply("heard Me|8000-12|100|h"); N.Main.guildLines.Bob=nil; eq(#N.Main.candidates(),1)
    advance(719); eq(#N.Main.candidates(),1); advance(2); eq(#N.Main.candidates(),0); eq(N.Main.heard.heard.Bob,nil)
    eq(forbidden,0)
end)
test("0.3.1 T4: replies not from the asked player, not on WHISPER, late or for someone else are not stored",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    local function reply(text,from,kind) deliver("CHAT_MSG_ADDON","LayerSwap",text,kind or "WHISPER",from or "Bob"); drain() end
    reply("heard Me|8000-12|100|h"); eq(next(N.Main.heard.heard),nil,"nothing asked yet")
    slash("hosts"); slash("hop host 1"); eq(#sent,1)
    reply("heard Me|8000-12|100|h","Cora"); reply("heard Me|8000-12|100|h","Bob","GUILD")
    reply("heard Someone|8000-12|100|h"); reply("heard Me|8000|100|h")
    eq(next(N.Main.heard.heard),nil)
    advance(121); reply("heard Me|8000-12|100|h"); eq(next(N.Main.heard.heard),nil,"after 120 s")
    eq(#sent,1)
end)
test("0.3.1 T4: with LayerSwap installed its own book is used and ours is ignored; the store is capped",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob"); drain(); yes(N.Main.heard.heard.Bob)
    N.Main.guildLines.Bob=nil; LayerSwapDB={book={}}
    eq(#N.Main.candidates(),0,"LayerSwap's own (empty) book wins")
    LayerSwapDB=nil; eq(#N.Main.candidates(),1)
    -- at most 64 names, the oldest dropped; entries older than 720 s pruned
    local Hs=N.Hosts; local st=Hs.new()
    for i=1,70 do Hs.heard(st,"Name"..string.char(96+math.ceil(i/26))..string.char(96+(i-1)%26+1),{kind="heard",layer="8000-1",zone=100,hosting=true},1000+i) end
    eq(N.Safe.count(st.heard),64); eq(st.heard.Nameaa,nil); yes(st.heard.Namecr)
    Hs.prune(st,1007+719); eq(N.Safe.count(st.heard),64); Hs.prune(st,1007+720); eq(N.Safe.count(st.heard),63)
    -- a reply without layer or zone stores nothing
    local s2=Hs.new(); Hs.heard(s2,"Bob",{kind="heard",zone=100,hosting=true},1); Hs.heard(s2,"Cy",{kind="heard",layer="8000-1",hosting=true},1)
    Hs.heard(s2,"Di",{kind="same"},1); eq(next(s2.heard),nil)
end)
test("0.3.1 guardrails: 20 idle minutes with the new paths send nothing",function()
    local N=loadAddon(); chatBox()
    local U=N.UI; U.toggle(); U.select("friendly")
    for i=1,240 do
        guildLine("L 8000|100|h","Bob"); guildLine("Q","Bob"); guildLine("v 3.0.25","Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Bob")
        if i==60 then establish(N) end
        if i==120 then map=200; deliver("ZONE_CHANGED_NEW_AREA") end
        if i==180 then map=100; deliver("ZONE_CHANGED_NEW_AREA") end
        U.render(); advance(5)
    end
    eq(#sent,0); eq(#opened,0); eq(forbidden,0); no(N.Main.error)
end)

-- 0.4.0 Task 1: one LFSw "Q" on GUILD from a click, 60 s apart, never on its own.
local ASKED="asked the guild's Bulo users for their layers; answers take up to 6 s"
local function lfswSent() local n={}; for _,m in ipairs(sent) do if m.prefix=="LFSw" then n[#n+1]=m end end; return n end
test("0.4 T1: /le hosts find sends exactly one LFSw Q on GUILD, then waits 60 s",function()
    local N=loadAddon(); establish(N)
    slash("hosts"); yes(log[#log]:find("/le hosts find",1,true),"the hosts list ends naming /le hosts find")
    eq(#sent,0,"/le hosts alone sends nothing")
    -- (0.4.0 Task 7.4: the same click also sends one LEGW1 "F|1"; only the LFSw messages are counted here)
    slash("hosts find"); local q=lfswSent(); eq(#q,1); eq(q[1].text,"Q"); eq(q[1].kind,"GUILD"); eq(q[1].target,nil)
    yes(logged(ASKED))
    advance(59); slash("hosts find"); eq(#lfswSent(),1); yes(log[#log]:find("wait 1 s",1,true),log[#log])
    advance(1); slash("hosts find"); eq(#lfswSent(),2); eq(forbidden,0)
end)
test("0.4 T1: the 60 s limit is in Wire itself, and Wire takes only the literal Q",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.send("LFSw","Q","GUILD")); local ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"throttled"); eq(#sent,1)
    advance(59); ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled"); advance(1); yes(Wr.send("LFSw","Q","GUILD")); eq(#sent,2)
    for _,x in ipairs({"L 8000|100|h","L 8000|100|-","v 3.0.25","QQ","q"," Q",""}) do ok,why=Wr.send("LFSw",x,"GUILD"); no(ok); eq(why,"bad text",x) end
    for _,k in ipairs({"WHISPER","PARTY","CHANNEL","RAID"}) do ok,why=Wr.send("LFSw","Q",k,"Bob"); no(ok); eq(why,"blocked route",k) end
    eq(#sent,2)
    -- the stamp is set before the client is asked: a client throttle does not allow a quick retry
    N=loadAddon(); Wr=N.Wire; sendResult=3; ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled"); eq(#sent,1)
    sendResult=0; ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"paused","1.0: the prefix pauses 30 s"); eq(#sent,1)
    advance(31); ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled","then the 60 s"); eq(#sent,1); eq(forbidden,0)
end)
test("0.4 T1: not in a guild, nothing is sent; an incoming Q is never answered",function()
    local N=loadAddon(); establish(N); inGuild=false
    slash("hosts find"); eq(#sent,0); yes(log[#log]:find("not in a guild",1,true),log[#log])
    inGuild=true
    for i=1,20 do guildLine("Q","Bob"..string.char(96+i)); advance(1) end
    deliver("CHAT_MSG_ADDON","LFSw","Q","WHISPER","Bob"); drain()
    eq(#sent,0)
end)
test("0.4 T1: the Find hosts button on the Friendly tab, one Q per click",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.findHosts:IsShown()); eq(U.findHosts.label.text,"Find hosts")
    U.findHosts:Click(); drain(); eq(#lfswSent(),1); eq(sent[1].prefix,"LFSw")
    U.render(); yes(U.findHosts.disabled,"disabled while the 60 s run"); U.findHosts:Click(); eq(#lfswSent(),1)
    advance(60); U.render(); no(U.findHosts.disabled)
    U.select("reported"); no(U.findHosts:IsShown())
end)

-- 0.3.1 review fixes (S1-S3)
test("0.3.1 fix S1: own layer unknown, a report hop refuses with the hint, no draft even via the reporter",function()
    local N=loadAddon(); chatBox(); advance(1)
    guildLine("L 8000|100|h","Alpha"); hopReport(301,8000,"Alpha")
    local list=N.Main.candidates(); eq(#list,1); yes(list[1].unknownOwn)
    slash("reports"); eq(#N.Main.hopList.records,1)
    local r=N.Main.hopList.records[1]; local p=N.Main.hopPreview(r)
    no(p.enabled); eq(p.reason,N.Invite.HINT)
    slash("hop 1"); eq(#opened,0); eq(#sent,0); yes(logged(N.Invite.HINT))
    no(N.Main.hopTo(r,p)); eq(#opened,0); eq(#sent,0)
    -- the Reported row button is disabled with the hint
    local U=N.UI; U.toggle(); U.select("reported")
    local row; for _,x in ipairs(U.pool) do if x:IsShown() and x.hopRecord then row=x end end
    yes(row); yes(row.ask.disabled); eq(row.ask.reason,N.Invite.HINT)
    -- Hop.check refuses a candidate that is such a row; a plain reporter candidate passes (0.3.0)
    local ctx={grouped=false,zone=100,own={zone=100,server=nil}}
    local ok,why=N.Hop.check(r,{name="Alpha",short="alpha",addon=true,unknownOwn=true},ctx); no(ok); eq(why,N.Invite.HINT)
    yes(N.Hop.check(r,{name="Scout",short="scout",addon=false},ctx))
    -- the guild ask still needs our own key
    ok,why=N.Hop.guildRequest(N.Main.hop,r,{grouped=false,zone=100,own={zone=100,server=nil},invite=N.Main.invite,now=clock}); no(ok); eq(why,N.Invite.HINT)
end)
test("0.3.1 fix S2: hop host refuses when the host flag or the LayerSwap uid changed since the preview",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Alpha"); slash("hosts")
    local c=N.Main.hostList.rows[1]; local p=N.Main.hostPreview(c); yes(c.host); yes(p.enabled)
    guildLine("L 8000|100|-","Alpha")
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c); eq(p.candidate.uid,12); yes(p.enabled)
    LayerSwapDB.book.Alpha.layer="8000-13"
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- unchanged: one whisper with the shown uid
    LayerSwapDB.book.Alpha.layer="8000-12"; slash("hosts"); c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c)
    yes(N.Main.hopHostTo(c,p)); eq(#sent,1); yes(sent[1].text:find("want 8000-12",1,true),sent[1].text)
    -- a LayerSwap page whose host flag drops (same source, same uid): refused too
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c); yes(c.host)
    LayerSwapDB.book.Alpha.host=false; no(N.Main.candidates()[1].host)
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- /le hop host N compares against the listed row the same way
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    LayerSwapDB.book.Alpha.layer="8000-13"; slash("hop host 1"); eq(#sent,0); yes(logged("hosts changed, check again."))
end)
test("0.3.1 fix S3 and note: the hint names two different kinds of NPC; a non-host Bulo row says it may not answer",function()
    local N=loadAddon(); chatBox()
    eq(N.Invite.HINT,"Your layer is not known yet: target or mouse over two different kinds of NPC within 15 seconds.")
    local U=N.UI; U.toggle(); yes(U.meta.text:find("two different kinds of NPC within 15 s",1,true),U.meta.text)
    establish(N); guildLine("L 8000|100|-","Bravo"); slash("hosts")
    local p=N.Main.hostPreview(N.Main.hostList.rows[1]); yes(p.enabled)
    yes(p.detail:find("not hosting; may not answer",1,true),p.detail)
    local r=rec(N); local q=N.Main.hopPreview(r); eq(q.label,"Hop via Bravo"); yes(q.detail:find("not hosting; may not answer",1,true),q.detail)
    guildLine("L 8000|100|h","Bravo"); slash("hosts"); p=N.Main.hostPreview(N.Main.hostList.rows[1]); no(p.detail:find("may not answer",1,true))
end)
-- 0.4.0 Task 5: a prefilled guild-chat LayerSwap request; the player sends it with Enter, the addon sends nothing.
local GLINE="/g inv layer <LS 100 want 9500-0 25.0,75.0>"
local function guildRec(N,over) local o={src="guild",layer={ns="server",value="9500"}}; for k,v in pairs(over or {}) do o[k]=v end; return rec(N,o) end
test("0.4 T5: no one known on the layer: Ask guild (chat) drafts the exact /g line and sends nothing",function()
    local N=loadAddon(); establish(N); chatBox()
    local r=guildRec(N); local p=N.Main.hopPreview(r)
    eq(p.label,"Ask guild (chat)"); yes(p.enabled); eq(p.mode,"guild")
    yes(p.detail:find("you press Enter",1,true),p.detail)
    yes(N.Main.hopTo(r,p)); drain()
    eq(#sent,0,"the addon sends nothing"); eq(#opened,1); eq(opened[1].text,GLINE); eq(forbidden,0)
    yes(log[#log]:find("press Enter",1,true),log[#log])
    -- a second ask within 60 s drafts nothing; the 10 s overall limit applies to it as to any ask
    advance(30); no(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,1); yes(log[#log]:find("wait 30 s",1,true),log[#log])
    advance(30); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,2)
    advance(61); guildLine("L 8000|100|h","Bob"); yes(hopNow(N,rec(N))); eq(#sent,1)
    no(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,2); yes(log[#log]:find("one ask every 10 s",1,true),log[#log])
end)
test("0.4 T5: a known host or another precondition means no guild ask",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 9500|100|h","Bob")
    local p=N.Main.hopPreview(guildRec(N)); eq(p.label,"Hop via Bob"); no(p.mode=="guild")
    N=loadAddon(); establish(N); chatBox()
    grouped=true; p=N.Main.hopPreview(guildRec(N)); no(p.enabled); no(p.mode=="guild"); yes(p.reason:find("leave your current group",1,true)); grouped=false
    p=N.Main.hopPreview(guildRec(N,{zone=200})); no(p.mode=="guild"); yes(p.reason:find("travel to",1,true))
    p=N.Main.hopPreview(guildRec(N,{layer={ns="server",value="7086"},src="own"})); no(p.mode=="guild")
    -- shown as a guild ask, but a host appears before the click: nothing drafted, nothing sent
    local r=guildRec(N); p=N.Main.hopPreview(r); eq(p.mode,"guild")
    guildLine("L 9500|100|h","Mallory"); no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- shown as a guild ask, then grouped or the map shows another zone before the click: nothing drafted
    N=loadAddon(); establish(N); chatBox(); r=guildRec(N); p=N.Main.hopPreview(r); eq(p.mode,"guild")
    grouped=true; no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); yes(log[#log]:find("leave your current group",1,true)); grouped=false
    map=200; no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); yes(log[#log]:find("travel to",1,true)); map=100
end)
test("0.4 T5: GUILD heard replies are read for 120 s after our own guild ask, naming us, and stored as hosts",function()
    local N=loadAddon(); establish(N); chatBox()
    local function gheard(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"GUILD",from); drain() end
    gheard("heard Me|9500-4|100|h","Bob"); eq(next(N.Main.heard.heard),nil,"no guild ask yet")
    local r=guildRec(N); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    gheard("heard Someone|9500-4|100|h","Bob"); gheard("claim Me","Bob"); gheard("heard Me|9500|100|h","Bob"); eq(next(N.Main.heard.heard),nil)
    gheard("heard Me|9500-4|100|h","Bob"); yes(N.Main.heard.heard.Bob); eq(N.Main.heard.heard.Bob.layer,"9500-4")
    local list=N.Main.candidates(); eq(list[1].name,"Bob"); eq(list[1].uid,4)
    gheard("heard Me|9500-5|100|-","Cy"); eq(N.Main.heard.heard.Cy,nil)
    advance(121); gheard("heard Me|9500-6|100|h","Dee"); eq(N.Main.heard.heard.Dee,nil,"after 120 s")
    eq(#sent,0); eq(forbidden,0)
end)
test("0.4 T5: the Reported row button drafts the guild line",function()
    local N=loadAddon(); establish(N); chatBox()
    local r=guildRec(N); N.Store.report(N.Main.store,r,clock)
    local U=N.UI; U.toggle(); U.select("reported")
    local row; for _,x in ipairs(U.pool) do if x:IsShown() then row=x end end
    yes(row); eq(row.ask.label.text,"Ask guild (chat)"); no(row.ask.disabled)
    row.ask:Click(); drain(); eq(#opened,1); eq(opened[1].text,GLINE); eq(#sent,0)
end)

local N_G
-- 0.4.0 Task 7.1: guild-only host, pure parser and decision (GuildHost.lua). Nothing is sent or invited here.
local function gh(N) return N.GuildHost end
local function ownState(over)
    local o={self="me",zone=100,key="8000",id="8000-7",inInstance=false,inCombat=false,raid=false,leader=false,members={},asking=false,member=true}
    for k,v in pairs(over or {}) do o[k]=v end
    return o
end
local function req(text,name) local r=assert(N_G.parse(text),text); r.name=name or "Bob"; return r end
test("0.4 T7.1: parse accepts only the full want/not grammar",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local r=G.parse("inv layer <LS 100 want 8000-12 25.0,75.0>"); eq(r.zone,100); eq(r.want,"8000-12"); eq(r.x,25); eq(r.y,75); eq(r.nots,nil)
    r=G.parse("inv layer <LS 1429 want 7086-0>"); eq(r.zone,1429); eq(r.want,"7086-0"); eq(r.x,nil)
    r=G.parse("inv layer <LS 100 not 7086-3>"); eq(r.want,nil); eq(#r.nots,1); eq(r.nots[1],"7086-3")
    r=G.parse("inv layer <LS 100 not 7086-3 not 8000-1 not 9000-2 48.2,42.5>"); eq(#r.nots,3); eq(r.nots[3],"9000-2"); eq(r.x,48.2)
    for _,bad in ipairs({"inv layer <LS 100>","inv layer <LS 100 25.0,75.0>","inv layer <LS 100 want 8000-12> extra","x inv layer <LS 100 want 8000-1>",
        "inv layer <LS 100 want 8000>","inv layer <LS 100 want 8000-1 not 7000-1>","inv layer <LS 100 not 7000-1 want 8000-1>",
        "inv layer <LS abc want 8000-1>","inv layer <LS 100  want 8000-1>","inv layer <LS 100 want 8000-1 25.0>","inv layer <LS 100 want 8000-1 a,b>",
        "inv layer <LS 1234567890 want 8000-1>","inv layer <LS 100 want 8000-1>"..string.rep(" ",200),"",5,nil,secret,
        "INV LAYER <LS 100 want 8000-1>","inv layer <LS 100 want 8000-1-2>"}) do
        eq(G.parse(bad),nil,tostring(type(bad)=="string" and bad or type(bad)))
    end
    eq(G.parse("inv layer <LS 100 want "..string.rep("1",230).."-1>"),nil,"over 255 bytes")
end)
test("0.4 T7.1: decide order: hosting, name, 60 s per asker, zone, key, instance, combat, guild",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local st=G.new(); local R=req("inv layer <LS 100 want 8000-12 25.0,75.0>")
    eq((G.decide(st,R,ownState(),100)),"drop","hosting off")
    st.on=true
    eq((G.decide(st,req("inv layer <LS 100 want 8000-1>","Me"),ownState(),100)),"drop","our own name")
    eq((G.decide(st,req("inv layer <LS 100 want 8000-1>","Bad|Name"),ownState(),100)),"drop","bad name")
    for _,c in ipairs({{zone=200},{zone=false},{key=false},{inInstance=true},{inInstance="?"},{inCombat=true},{member=false},{member="?"}}) do
        local o=ownState(); for k,v in pairs(c) do if v==false and (k=="zone" or k=="key") then o[k]=nil else o[k]=v end end
        local s=G.new(); s.on=true
        local v,reply=G.decide(s,R,o,100); eq(v,"drop"); eq(reply,nil)
    end
    -- combat unreadable counts as in combat
    local s=G.new(); s.on=true; local o=ownState(); o.inCombat=nil; eq((G.decide(s,R,o,100)),"drop")
    -- guild membership unreadable (nil) is no
    s=G.new(); s.on=true; o=ownState(); o.member=nil; eq((G.decide(s,R,o,100)),"drop")
    -- instance unreadable (nil) is no
    s=G.new(); s.on=true; o=ownState(); o.inInstance=nil; eq((G.decide(s,R,o,100)),"drop")
    -- request zone other than ours
    s=G.new(); s.on=true; eq((G.decide(s,req("inv layer <LS 101 want 8000-1>"),ownState(),100)),"drop")
end)
test("0.4 T7.1: want and not rules with their replies",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local function fresh() local s=G.new(); s.on=true; return s end
    local v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-12 25.0,75.0>"),ownState(),100); eq(v,"invite"); eq(reply,"heard Bob|8000-7|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 9000-0>"),ownState(),100); eq(v,"busy"); eq(reply,"heard Bob|8000-7|100|-","carries our real layer")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 8000-3>"),ownState(),100); eq(v,"same"); eq(reply,"same")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 9000-3>"),ownState(),100); eq(v,"invite"); eq(reply,"heard Bob|8000-7|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 9000-3 not 8000-1>"),ownState(),100); eq(v,"drop"); eq(reply,nil)
    -- without a zoneUID we answer with uid 0; a realm suffix on the asker is dropped from the reply
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-1>","Bob-OtherRealm"),ownState({id=false}),100); eq(v,"invite"); eq(reply,"heard Bob|8000-0|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-1>","Tam Reed"),ownState(),100); eq(reply,"heard Tam Reed|8000-7|100|h")
end)
test("0.4 T7.1: group rule, own request, 10 s overall and 6 per 600 s give busy",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local R=function(n) return req("inv layer <LS 100 want 8000-1>",n or "Bob") end
    local function fresh() local s=G.new(); s.on=true; return s end
    for _,o in ipairs({ownState({raid=true}),ownState({members={"Cy"},leader=false}),ownState({members={"Cy"},leader=true}),ownState({asking=true})}) do
        local v,reply=G.decide(fresh(),R(),o,100); eq(v,"busy"); eq(reply,"heard Bob|8000-7|100|-")
    end
    -- a party whose members we all invited but that we do not lead: busy
    local s0=fresh(); s0.hosted.cy=true; eq((G.decide(s0,R(),ownState({members={"Cy"},leader=false}),100)),"busy","not the leader")
    -- a party we lead whose members we all invited, under five with pending: invite
    local s=fresh(); s.hosted.cy=true; local v=G.decide(s,R(),ownState({members={"Cy"},leader=true}),100); eq(v,"invite")
    -- four members, or three plus one pending: busy
    s=fresh(); for _,m in ipairs({"aa","bb","cc"}) do s.hosted[m]=true end; v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc"},leader=true}),100); eq(v,"invite")
    s=fresh(); for _,m in ipairs({"aa","bb","cc","dd"}) do s.hosted[m]=true end; v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc","Dd"},leader=true}),100); eq(v,"busy")
    s=fresh(); for _,m in ipairs({"aa","bb","cc"}) do s.hosted[m]=true end; s.pending.zz=100
    v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc"},leader=true}),110); eq(v,"busy","three members plus one pending")
    -- 60 s per asker, 10 s overall, 6 per 600 s
    s=fresh(); eq((G.decide(s,R("Bob"),ownState(),1000)),"invite")
    eq((G.decide(s,R("Bob"),ownState(),1059)),"drop","same asker at 59 s")
    eq((G.decide(s,R("Cy"),ownState(),1009)),"busy","second asker at 9 s")
    s=fresh(); local t0=2000; local names={"Aa","Bb","Cc","Dd","Ee","Ff","Gg"}
    -- 61 s apart: a pending invite counts 60 s toward the group size
    for i=1,6 do eq((G.decide(s,R(names[i]),ownState(),t0+(i-1)*61)),"invite",names[i]) end
    eq((G.decide(s,R("Gg"),ownState(),t0+366)),"busy","seventh inside 600 s")
    eq((G.decide(s,R("Hh"),ownState(),t0+600)),"invite","the first has aged out")
end)
test("0.4 T7.1: the asker table is capped at 128 and the 60 s counts from the guild check",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local s=G.new(); s.on=true
    for i=1,140 do G.decide(s,req("inv layer <LS 100 want 9000-1>","N"..string.char(96+math.ceil(i/26))..string.char(96+(i-1)%26+1)),ownState(),i) end
    eq(N.Safe.count(s.asked),128)
    -- a drop before the guild check (other zone) does not start the 60 s
    s=G.new(); s.on=true
    eq((G.decide(s,req("inv layer <LS 101 want 8000-1>"),ownState(),10)),"drop"); eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState(),11)),"invite")
    -- a non-member reached the guild check: 60 s
    s=G.new(); s.on=true
    eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState({member=false}),10)),"drop")
    eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState(),40)),"drop","within 60 s of the guild check")
end)

-- 0.4.0 Task 7.2: state adapters for the guild host (read only).
test("0.4 T7.2: guild membership: one online roster entry, exact name first, bare name only when unique",function()
    local N=loadAddon(); local A=N.Adapters
    roster={{"Bob-TestRealm",true},{"Tam Reed-TestRealm",true},{"Off-TestRealm",false},{"Two-RealmA",true},{"Two-RealmB",true}}
    eq(A.guildMember("Bob-TestRealm"),true); eq(A.guildMember("Bob"),true); eq(A.guildMember("Tam Reed"),true); eq(A.guildMember("Tam Reed-TestRealm"),true)
    eq(A.guildMember("Off"),false,"offline"); eq(A.guildMember("Off-TestRealm"),false,"offline, exact name"); eq(A.guildMember("Nobody"),false); eq(A.guildMember("Bob-OtherRealm"),false,"a different realm")
    eq(A.guildMember("Two"),false,"two entries with that bare name"); eq(A.guildMember("Two-RealmA"),true,"the exact name is unique")
    roster={{"Bob",true}}; eq(A.guildMember("Bob-TestRealm"),true,"roster without the realm")
    roster={{"Bob",true},{"Bob",true}}; eq(A.guildMember("Bob"),false,"duplicated exact name")
    -- unreadable is nil
    inGuild=false; roster={{"Bob",true}}; eq(A.guildMember("Bob"),nil); inGuild=true
    roster={}; eq(A.guildMember("Bob"),nil,"count 0")
    GetNumGuildMembers=function() return secret end; eq(A.guildMember("Bob"),nil)
    GetNumGuildMembers=function() return 1 end; GetGuildRosterInfo=function() error("x") end; eq(A.guildMember("Bob"),nil)
    GetGuildRosterInfo=function() return secret end; eq(A.guildMember("Bob"),nil)
    GetGuildRosterInfo=function() return "Bob",nil,nil,nil,nil,nil,nil,nil,secret end; eq(A.guildMember("Bob"),nil)
    eq(A.guildMember(secret),nil); eq(A.guildMember("Bad|Name"),nil)
    GetNumGuildMembers=nil; eq(A.guildMember("Bob"),nil)
end)
test("0.4 T7.2: roster age from GUILD_ROSTER_UPDATE, refresh at most every 15 s",function()
    local N=loadAddon(); local A=N.Adapters
    eq(A.rosterAge(clock),nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(A.rosterAge(clock),0); advance(30); eq(A.rosterAge(clock),30)
    yes(A.rosterRefresh(clock)); eq(rosterCalls,1)
    advance(14); no(A.rosterRefresh(clock)); eq(rosterCalls,1); advance(1); yes(A.rosterRefresh(clock)); eq(rosterCalls,2)
    C_GuildInfo=nil; advance(20); no(A.rosterRefresh(clock)); eq(rosterCalls,2)
    eq(#sent,0)
end)
test("0.4 T7.2: combat and party state; unreadable combat is in combat, unreadable party is nil",function()
    local N=loadAddon(); local A=N.Adapters
    eq(A.inCombat(),false); combat=true; eq(A.inCombat(),true); combat=false
    UnitAffectingCombat=function() return true end; eq(A.inCombat(),true); UnitAffectingCombat=function() return false end
    InCombatLockdown=function() return secret end; eq(A.inCombat(),true); InCombatLockdown=nil; eq(A.inCombat(),true)
    local p=A.party(); eq(p.raid,false); eq(p.leader,false); eq(#p.members,0)
    units.party1={name="Cy",realm=nil}; units.party2={name="Di",realm="OtherRealm"}; leader=true
    p=A.party(); eq(p.leader,true); eq(#p.members,2); eq(p.members[1],"Cy"); eq(p.members[2],"Di-OtherRealm")
    raid=true; p=A.party(); eq(p.raid,true); raid=false
    IsInRaid=function() return secret end; eq(A.party(),nil)
    IsInRaid=function() return false end; GetNumGroupMembers=function() error("x") end; eq(A.party(),nil)
end)

-- 0.4.0 Task 7.3: the invite (Wire.invite, the only party call) and the guild host wiring.
local function lsw(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"WHISPER",from or "Bob"); drain() end
local function hostReady(N,names)
    establish(N); roster={}
    for _,n in ipairs(names or {"Bob"}) do roster[#roster+1]={n.."-TestRealm",true} end
    slash("host on"); deliver("GUILD_ROSTER_UPDATE",true); drain()
    yes(N.Main.host.on,"hosting on"); sent={}
end
test("0.4 T7.3: Wire.invite keeps its own limits: 10 s, 60 s per name, 6 per 600 s; our realm dropped",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.canInvite()); eq(#invites,0)
    -- (0.4.0 review M1: only our own realm is dropped; another realm stays in the invite)
    local ok,why=Wr.invite("Bob-TestRealm",clock); yes(ok); eq(why,"invited"); eq(invites[1],"Bob")
    ok,why=Wr.invite("Cy",clock+9); no(ok); eq(why,"throttled")
    ok,why=Wr.invite("Bob",clock+11); no(ok); eq(why,"throttled","same name inside 60 s")
    yes(Wr.invite("Cy",clock+12)); eq(invites[2],"Cy")
    yes(Wr.invite("Tam Reed",clock+60)); eq(invites[3],"Tam Reed")
    yes(Wr.invite("Bob",clock+120)); yes(Wr.invite("Di",clock+180)); yes(Wr.invite("Ed",clock+240))
    ok,why=Wr.invite("Fy",clock+300); no(ok); eq(why,"throttled","seventh inside 600 s"); eq(#invites,6)
    yes(Wr.invite("Fy",clock+611))
    for _,bad in ipairs({secret,"Bad|Name","B","",5}) do local o,w=Wr.invite(bad,clock+1000); no(o); eq(w,"bad name") end
    no(Wr.invite("Gy",secret))
    eq(forbidden,0)
    -- a client without the call: no invite, and canInvite says so
    N=loadAddon(); C_PartyInfo=nil; no(N.Wire.canInvite()); ok,why=N.Wire.invite("Bob",clock); no(ok); eq(why,"error")
    N=loadAddon(); C_PartyInfo={InviteUnit=function() error("x") end}; ok,why=N.Wire.invite("Bob",clock); no(ok); eq(why,"error")
    no(N.Wire.invite("Cy",clock+1),"the limit was spent before the client was asked")
end)
test("0.4 T7.3: LayerSwap whispers carry only the request, same or heard; replies one per 6 s",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0 48.2,42.5>","WHISPER","Alice"))
    yes(Wr.send("LayerSwap","inv layer <LS 1429 not 7086-3>","WHISPER","Alice"))
    yes(Wr.send("LayerSwap","same","WHISPER","Alice"))
    local ok,why=Wr.send("LayerSwap","heard Alice|7086-7|100|h","WHISPER","Alice"); no(ok); eq(why,"throttled")
    advance(6); yes(Wr.send("LayerSwap","heard Tam Reed|7086-7|100|-","WHISPER","Tam Reed"))
    advance(6)
    for _,bad in ipairs({"x","hello","heard Alice|7086|100|h","heard Alice|7086-7|100|x","heard |7086-7|100|h","heard x|7086-7|100|h","heard Bad1|7086-7|100|h","same ","claim Alice",
        "inv layer <LS 1429>","inv layer <LS 1429 want 7086-0> x"}) do
        ok,why=Wr.send("LayerSwap",bad,"WHISPER","Alice"); no(ok,bad); eq(why,"bad text",bad)
    end
    yes(Wr.send("LayerSwap","heard Alice|7086-7|100|h","WHISPER","Alice"))
    -- requests are not part of the reply limit
    yes(Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0>","WHISPER","Alice"))
    eq(forbidden,0)
end)
test("0.4 T7.3: hosting: off at load, on refused beside LayerSwap or Bulo or without the invite call",function()
    local N=loadAddon(); eq(N.Main.host.on,false)
    slash("host"); yes(logged("Hosting for your guild: off (saved)"))
    slash("host on"); yes(N.Main.host.on); eq(rosterCalls,1); yes(logged("Hosting for your guild is on"))
    slash("host"); yes(logged("Hosting for your guild: on (saved) · 0 invites in the last 10 minutes"))
    slash("host off"); no(N.Main.host.on); yes(logged("Hosting for your guild is off."))
    slash("host on"); N=loadAddon(); eq(N.Main.host.on,false,"a fresh profile (no saved setting) starts off")
    loaded.LayerSwap=true; slash("host on"); no(N.Main.host.on); yes(logged("LayerSwap")); loaded.LayerSwap=nil
    loaded.BuloLayerForever=true; slash("host on"); no(N.Main.host.on); yes(logged("BuloLayerForever")); loaded.BuloLayerForever=nil
    inGuild=false; slash("host on"); no(N.Main.host.on); yes(logged("not in a guild")); inGuild=true
    C_PartyInfo=nil; slash("host on"); no(N.Main.host.on); yes(logged("no party invite")); eq(#sent,0)
end)
test("0.4 T7.3: a guild member's request: one reply, at most one invite, one line",function()
    local N=loadAddon(); hostReady(N,{"Bob","Cy","Di","Ed"})
    lsw("inv layer <LS 100 want 7086-0 25.0,75.0>","Bob")
    eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob"); eq(sent[1].text,"heard Bob|7086-7|100|h")
    eq(#invites,1); eq(invites[1],"Bob"); yes(logged("LayerEnemies: invited Bob to your layer (guild host)."))
    advance(11); lsw("inv layer <LS 100 want 9000-0>","Cy"); eq(#sent,2); eq(sent[2].text,"heard Cy|7086-7|100|-"); eq(#invites,1)
    advance(11); lsw("inv layer <LS 100 not 7086-3>","Di"); eq(#sent,3); eq(sent[3].text,"same"); eq(#invites,1)
    -- not a member, offline, a request on GUILD or PARTY, a guild-chat line: nothing
    advance(11); lsw("inv layer <LS 100 want 7086-0>","Zed"); eq(#sent,3)
    roster[4][2]=false; lsw("inv layer <LS 100 want 7086-0>","Ed"); eq(#sent,3)
    for _,k in ipairs({"GUILD","PARTY","CHANNEL"}) do deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>",k,"Bob") end
    guildLine("inv layer <LS 100 want 7086-0>","Bob"); drain(); eq(#sent,3); eq(#invites,1)
    -- hosting off, or LayerSwap loaded while on: nothing
    advance(61); slash("host off"); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,3)
    -- turning hosting on again announces one LEGW1 H (Task 7.4); the request beside LayerSwap gets nothing
    slash("host on"); eq(#sent,4); eq(sent[4].text,"H|1|7086|100"); deliver("GUILD_ROSTER_UPDATE",true); loaded.LayerSwap=true; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,4); eq(#invites,1)
    loaded.LayerSwap=nil; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,2)
    slash("host"); yes(logged("2 invites in the last 10 minutes"))
    -- a bad line or a secret sender: nothing
    advance(61); lsw("inv layer <LS 100>","Cy"); lsw("inv layer <LS 100 want 7086-0>",secret); eq(#invites,2)
    eq(forbidden,0)
end)
test("0.4 T7.3: unreadable party, combat or own layer fails closed",function()
    local N=loadAddon(); hostReady(N,{"Bob"})
    IsInRaid=function() return secret end; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); IsInRaid=function() return false end
    advance(61); combat=true; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1,"busy reply for the unreadable party only"); combat=false
    -- the map shows another zone than the store (no zone event yet): our zone is unknown, nothing (fresh roster)
    advance(61); deliver("GUILD_ROSTER_UPDATE",true); map=200; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1); map=100
    -- everything readable again, roster 61 s old: one invite
    advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
end)
test("0.4 T7.3: a stale roster: one refresh, the request held in one slot for 5 s",function()
    local N=loadAddon(); establish(N); roster={{"Bob",true},{"Cy",true},{"Di",true}}
    slash("host on"); eq(rosterCalls,1); sent={}
    -- no roster yet: held, no reply and no invite; the update decides it
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,0); eq(#invites,0); eq(rosterCalls,1,"15 s since the last refresh")
    advance(3); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,1); eq(invites[1],"Bob")
    -- 121 s later the roster is stale again: one refresh; a newer request replaces the held one
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Cy"); eq(rosterCalls,2); lsw("inv layer <LS 100 want 7086-0>","Di"); eq(rosterCalls,2)
    advance(2); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,2); eq(invites[2],"Di")
    -- no update within 5 s: nothing
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Cy"); advance(6); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,2)
    -- a request failing an early check never asks for the roster
    advance(121); local calls=rosterCalls; lsw("inv layer <LS 101 want 7086-0>","Cy"); eq(rosterCalls,calls)
    eq(forbidden,0)
end)
test("0.4 T7.3: 20 idle minutes with hosting on: nothing sent, nothing invited",function()
    local N=loadAddon(); hostReady(N,{"Bob"})
    for i=1,120 do
        advance(10)
        if i%10==0 then deliver("GUILD_ROSTER_UPDATE",true) end
        if i%30==0 then map=(map==100) and 101 or 100; deliver("ZONE_CHANGED_NEW_AREA") end
        if i%45==0 then deliver("GROUP_ROSTER_UPDATE") end
        drain()
    end
    eq(#sent,0); eq(#invites,0); eq(forbidden,0)
end)
test("0.4 T7.3: the window toggle and the hosting line",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.host:IsShown()); eq(U.host.label.text,"Host: off"); no(U.hosting:IsShown())
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    U.host:Click(); drain(); yes(N.Main.host.on); eq(U.host.label.text,"Host: on"); yes(U.hosting:IsShown()); eq(U.hosting.text,"Hosting for your guild (stays on after reload)")
    U.select("reported"); no(U.host:IsShown()); yes(U.hosting:IsShown(),"the line stays visible while on")
    U.select("friendly"); U.host:Click(); drain(); no(N.Main.host.on); no(U.hosting:IsShown())
    -- the only message: the H from turning hosting on (Task 7.4); the refused click beside LayerSwap sends nothing
    loaded.LayerSwap=true; U.host:Click(); drain(); no(N.Main.host.on); eq(#sent,1); eq(sent[1].text,"H|1|7086|100")
end)

-- 0.4.0 Task 7.4: finding a LayerEnemies host: "F|1" from the Find hosts click, "H|1|<key>|<zone>" from a host.
local function legw(text,from,kind) deliver("CHAT_MSG_ADDON","LEGW1",text,kind or "GUILD",from or "Bob"); drain() end
local function legwSent(prefix) local out={}; for _,m in ipairs(sent) do if m.prefix=="LEGW1" and m.text:sub(1,#prefix)==prefix then out[#out+1]=m end end; return out end
test("0.4 T7.4: a 0.3.1 decoder rejects F and H lines as invalid; Relay builds and reads them strictly",function()
    local N=loadAddon(); local R=N.Relay
    for _,s in ipairs({"F|1","H|1|8000|100"}) do local rec,why=R.decode(s,"Bob",clock); eq(rec,nil); eq(why,"invalid") end
    eq(R.findLine(),"F|1"); eq(R.hostLine("8000",100),"H|1|8000|100"); eq(R.hostLine(nil,100),nil); eq(R.hostLine("8000",nil),nil)
    local c=R.control("F|1"); eq(c.kind,"F"); c=R.control("H|1|8000|100"); eq(c.kind,"H"); eq(c.key,"8000"); eq(c.zone,100)
    for _,bad in ipairs({"F|2","F|1|x","F","H|1|8000","H|1|8000|100|x","H|2|8000|100","H|1|abc|100","H|1|8000|0","H|1|8000|abc","H|1|-1|100",
        "R|1|x",secret,5,"H|1|"..string.rep("9",40).."|100","H|1|1234567890123456|100"}) do eq(R.control(bad),nil,tostring(type(bad)=="string" and bad or type(bad))) end
end)
test("0.4 T7.4: Find hosts sends one Q and one F|1, once per 60 s; outside a guild neither",function()
    local N=loadAddon(); establish(N)
    slash("hosts find"); eq(#sent,2); eq(sent[1].prefix,"LFSw"); eq(sent[2].prefix,"LEGW1"); eq(sent[2].text,"F|1"); eq(sent[2].kind,"GUILD")
    advance(30); slash("hosts find"); eq(#sent,2)
    advance(31); slash("hosts find"); eq(#sent,4)
    -- the F limit is in Wire too
    local ok,why=N.Wire.send("LEGW1","F|1","GUILD"); no(ok); eq(why,"throttled")
    no(N.Wire.send("LEGW1","F|2","GUILD")); no(N.Wire.send("LEGW1","H|1|8000","GUILD"))
    N=loadAddon(); inGuild=false; slash("hosts find"); eq(#sent,0); inGuild=true
    eq(forbidden,0)
end)
test("0.4 T7.4: turning hosting on announces H once; an F gets one H 1 to 6 s later, at most once per 60 s",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    slash("host on"); local h=legwSent("H|"); eq(#h,1); eq(h[1].text,"H|1|7086|100"); eq(h[1].kind,"GUILD")
    advance(61); legw("F|1","Bob"); eq(#legwSent("H|"),1,"not at once"); advance(7); drain(); eq(#legwSent("H|"),2)
    advance(10); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),2,"second F inside 60 s")
    advance(50); legw("F|1","Cy"); legw("F|1","Di"); advance(7); drain(); eq(#legwSent("H|"),3,"two F, one H")
    -- our own F, an F on PARTY or WHISPER: nothing
    advance(61); legw("F|1","Me"); legw("F|1","Bob","PARTY"); legw("F|1","Bob","WHISPER"); advance(7); drain(); eq(#legwSent("H|"),3)
    -- the H limit is in Wire too
    local ok,why=N.Wire.send("LEGW1","H|1|7086|100","GUILD"); yes(ok); ok,why=N.Wire.send("LEGW1","H|1|7086|100","GUILD"); no(ok); eq(why,"throttled")
    eq(#invites,0); eq(forbidden,0)
end)
test("0.4 T7.4: no H when hosting is off, our layer or zone unknown, or LayerSwap loaded",function()
    local N=loadAddon(); establish(N)
    legw("F|1","Bob"); advance(7); drain(); eq(#sent,0,"hosting off")
    N=loadAddon(); slash("host on"); eq(#legwSent("H|"),0,"own layer unknown: no announcement"); yes(N.Main.host.on)
    legw("F|1","Bob"); advance(7); drain(); eq(#legwSent("H|"),0)
    N=loadAddon(); establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); eq(#legwSent("H|"),1); advance(61)
    loaded.LayerSwap=true; legw("F|1","Bob"); advance(7); drain(); eq(#legwSent("H|"),1); loaded.LayerSwap=nil
    -- hosting turned off while the answer waits: nothing
    advance(61); legw("F|1","Bob"); slash("host off"); advance(7); drain(); eq(#legwSent("H|"),1)
end)
test("0.4 T7.4: a guild H is remembered 12 minutes as a host on <key>-0; /le hop host asks it",function()
    local N=loadAddon(); establish(N)
    legw("H|1|8000|100","Bob")
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"Bob"); eq(list[1].layer,"8000"); yes(list[1].host)
    slash("hosts"); slash("hop host 1"); eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].target,"Bob"); yes(sent[1].text:find("want 8000-0",1,true),sent[1].text)
    -- from us, ignored, not GUILD, malformed: not stored
    N=loadAddon(); establish(N)
    legw("H|1|8000|100","Me"); legw("H|1|8000|100","Bob","PARTY"); legw("H|1|8000|100","Bob","WHISPER"); legw("H|1|abc|100","Bob")
    clientIgnored=true; legw("H|1|8000|100","Cy"); clientIgnored=false
    eq(#N.Main.candidates(),0); eq(next(N.Main.heard.heard),nil,"nothing stored")
    legw("H|1|8000|100","Dee"); eq(#N.Main.candidates(),1); advance(721); wall=wall+721; eq(#N.Main.candidates(),0,"12 minutes")
    eq(#sent,0); eq(forbidden,0)
end)
-- 0.4.0 (owner decision): the hosting toggle is saved, a boolean setting only (LayerEnemiesDB.guildHost).
local function reload(N) N.Main.started=false; N.Main.start(); drain() end
local ONLINE="LayerEnemies: hosting for your guild is ON (/le host off to stop)."
test("0.4 host saved: on survives a reload and is active; one login line; no H at login",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    slash("host on"); eq(LayerEnemiesDB.guildHost,true); eq(#sent,1,"the H from turning it on")
    advance(16); reload(N); yes(N.Main.host.on); eq(lines(ONLINE),1); eq(LayerEnemiesDB.guildHost,true)
    eq(#sent,1,"nothing sent at login"); eq(rosterCalls,2,"one roster request at login")
    -- after a reload our layer is learned again from NPCs before a request can be answered
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1)
    establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
    slash("host"); yes(logged("Hosting for your guild: on (saved) · 1 invite in the last 10 minutes"))
    for k,v in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="call" or k=="callArt" or k=="netNotice" or k=="findShare" or k=="findNotice",k) end
    eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("0.4 host saved: off persists; a bad saved value is off",function()
    local N=loadAddon(); establish(N)
    slash("host on"); slash("host off"); eq(LayerEnemiesDB.guildHost,false)
    reload(N); no(N.Main.host.on); eq(lines("hosting for your guild is ON"),0); eq(LayerEnemiesDB.guildHost,false)
    slash("host"); yes(logged("Hosting for your guild: off (saved)"))
    LayerEnemiesDB.guildHost="yes"; reload(N); no(N.Main.host.on); eq(LayerEnemiesDB.guildHost,false)
    LayerEnemiesDB=nil; reload(N); no(N.Main.host.on); eq(LayerEnemiesDB.guildHost,false)
end)
test("0.4 host saved: on but inactive at login says why, answers nothing, stays saved",function()
    local cases={
        {function() loaded.LayerSwap=true end,function() loaded.LayerSwap=nil end,"LayerSwap is loaded"},
        {function() loaded.BuloLayerForever=true end,function() loaded.BuloLayerForever=nil end,"BuloLayerForever is loaded"},
        {function() C_PartyInfo=nil end,nil,"no party invite call"},
        {function() inGuild=false end,function() inGuild=true end,"not in a guild"},
    }
    for _,c in ipairs(cases) do
        local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; slash("host on"); sent={}
        c[1](); reload(N)
        no(N.Main.host.on,c[3]); yes(N.Main.host.want); eq(LayerEnemiesDB.guildHost,true)
        yes(logged("LayerEnemies: hosting for your guild is ON but inactive: "),c[3]); yes(log[#log]:find(c[3],1,true),log[#log])
        yes(log[#log]:find("(/le host off to stop)",1,true))
        slash("host"); yes(logged("Hosting for your guild: on (saved) but inactive: "))
        deliver("GUILD_ROSTER_UPDATE",true); drain(); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,0); eq(#invites,0)
        eq(lines("hosting for your guild is ON but inactive"),1,"the inactive line only at login")
        if c[2] then c[2]() end
    end
    -- not in a guild at login (guild data late): it becomes active on the guild roster update, with one line
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; slash("host on")
    inGuild=false; reload(N); no(N.Main.host.on); inGuild=true
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); eq(lines("LayerEnemies: hosting for your guild is now active."),1)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(lines("LayerEnemies: hosting for your guild is now active."),1)
    -- /le host off while inactive: off and saved off
    loaded.LayerSwap=true; reload(N); no(N.Main.host.on); slash("host off"); eq(LayerEnemiesDB.guildHost,false); no(N.Main.host.want); loaded.LayerSwap=nil
end)
test("0.4 host saved: the window line and toggle",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    slash("host on"); yes(logged("It stays on after a reload; /le host off stops it.")); U.render()
    eq(U.hosting.text,"Hosting for your guild (stays on after reload)"); eq(U.host.label.text,"Host: on")
    loaded.LayerSwap=true; reload(N); U.render(); yes(U.hosting:IsShown()); eq(U.host.label.text,"Host: on")
    yes(U.hosting.text:find("Hosting is on but inactive: ",1,true),U.hosting.text)
    U.host:Click(); drain(); no(N.Main.host.want); eq(LayerEnemiesDB.guildHost,false); no(U.hosting:IsShown()); eq(U.host.label.text,"Host: off")
end)

-- 0.4.0 Task 8: hiccup-free hop. Accept only the asked host's invite, leave only that group, after the move.
local function inviteFrom(name) popup.shown=true; popup.inviteAccepted=nil; deliver("PARTY_INVITE_REQUEST",name,false,false,false,true,false,false,"Player-1-0001",false); drain() end
local function joinParty(name) grouped=true; units.party1={name=name,leader=true}; deliver("GROUP_ROSTER_UPDATE"); drain() end
-- with Bulo installed (askBob) its layer moves; without it, two rounds of two NPC kinds (the zoneUID change resets
-- the votes, the second round confirms the new layer)
local BULO
local function moveTo(key,uid)
    if BULO then BULO.current=key.."-"..(uid or 9); BULO:Fire("LFS_LAYER",BULO.current); drain(); return end
    for r=0,1 do
        units.target={guid=npc(11+2*r,uid or 9,key),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
        units.mouseover={guid=npc(12+2*r,uid or 9,key),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    end
end
local function askBob(N) BULO=friends(N,{Bob=there({key="8000",host=true})}); advance(1); yes(hopNow(N,rec(N))); eq(sent[#sent].target,"Bob") end
test("0.4 T8: the asked host's invite is accepted, the popup hidden as accepted; the move then leaves after 3 s",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    advance(5); inviteFrom("Bob")
    eq(#accepts,1); no(popup.shown); eq(popup.inviteAccepted,1); yes(logged("LayerEnemies: accepted Bob's invite"))
    joinParty("Bob"); moveTo("8000")
    eq(N.Main.store.bulo,"8000-9"); yes(logged("LayerEnemies: moved to layer 8000, leaving the group"))
    eq(#leaves,0,"not before 3 s"); advance(3.1); drain(); eq(#leaves,1); no(grouped)
    advance(60); drain(); eq(#leaves,1,"once"); eq(forbidden,0)
    -- the ask is spent: a second invite from Bob afterwards is left to the player
    inviteFrom("Bob"); eq(#accepts,1); yes(popup.shown)
end)
test("0.4 T8: Wire keeps its own limits on accept and leave (10 s each)",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.accept(clock)); local ok,why=Wr.accept(clock+9); no(ok); eq(why,"throttled"); yes(Wr.accept(clock+10)); eq(#accepts,2)
    grouped=true; yes(Wr.leave(clock)); ok,why=Wr.leave(clock+5); no(ok); eq(why,"throttled"); eq(#leaves,1)
    AcceptGroup=nil; ok,why=Wr.accept(clock+30); no(ok); eq(why,"error")
    C_PartyInfo=nil; ok,why=Wr.leave(clock+30); no(ok); eq(why,"error")
    -- a popup that cannot be found is never hidden
    popup.shown=false; no(Wr.hideInvite()); eq(popupHidden,0); eq(forbidden,0)
end)
test("0.4 T8: no move within 30 s of joining: leave and say the hop failed",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    advance(29); drain(); eq(#leaves,0); advance(1.2); drain(); eq(#leaves,1)
    yes(logged("LayerEnemies: hop failed: Bob could not move you")); eq(forbidden,0)
end)
test("0.4 T8: another inviter, a late invite, grouped, instance or combat: nothing is accepted",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    inviteFrom("Mallory"); inviteFrom("Bob-OtherRealm"); inviteFrom("bobby"); eq(#accepts,0); yes(popup.shown,"left to the player")
    N=loadAddon(); BULO=nil; establish(N); askBob(N); advance(121); inviteFrom("Bob"); eq(#accepts,0)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); grouped=true; inviteFrom("Bob"); eq(#accepts,0); grouped=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inInstance=true; inviteFrom("Bob"); eq(#accepts,0); inInstance=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); combat=true; inviteFrom("Bob"); eq(#accepts,0); combat=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); InCombatLockdown=function() return secret end; inviteFrom("Bob"); eq(#accepts,0)
    -- no ask at all, or a manual /le ask whisper: nothing
    N=loadAddon(); BULO=nil; establish(N); inviteFrom("Bob"); eq(#accepts,0)
    N=loadAddon(); BULO=nil; establish(N); friends(N,{Bob=there({key="8000"})}); chatBox(); advance(1); yes(LE.AskInvite("Bob")); inviteFrom("Bob"); eq(#accepts,0)
    -- the same invite twice: one accept
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); inviteFrom("Bob"); eq(#accepts,1)
    eq(#leaves,0); eq(forbidden,0)
end)
test("0.4 T8: a group not joined through our hop is never left; leader changes, raid or our lead stop the leave",function()
    -- a group joined by hand (no ask)
    local N=loadAddon(); BULO=nil; establish(N); joinParty("Cy"); moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- accepted Bob, but the group's leader is someone else
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); grouped=true; units.party1={name="Cy",leader=true}; deliver("GROUP_ROSTER_UPDATE"); drain()
    moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- the group became a raid, or we became leader, after joining
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); raid=true; moveTo("8000"); advance(40); drain(); eq(#leaves,0); raid=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); units.party1.leader=false; leader=true; moveTo("8000"); advance(40); drain(); eq(#leaves,0); leader=false
    -- moved to a layer that is not the target: no "moved" leave; the 30 s failure leave still applies to our hop group
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("9000"); advance(3.5); drain(); eq(#leaves,0)
    advance(30); drain(); eq(#leaves,1); yes(logged("hop failed: Bob could not move you"))
    -- we left by ourselves before the move: nothing left later
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain()
    advance(40); drain(); eq(#leaves,0); eq(forbidden,0)
end)
test("0.4 T8: the guild ask accepts an online guild member's invite only",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Bob-TestRealm",true},{"Off-TestRealm",false}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,1)
    -- (round 2: armed when our /g line goes out; Bob, Off and Zed answered, so only the guild check decides here)
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
    for _,who in ipairs({"Bob","Off","Zed"}) do deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD",who) end; drain()
    inviteFrom("Zed"); inviteFrom("Off"); eq(#accepts,0)
    -- roster unreadable: no
    local count=GetNumGuildMembers; GetNumGuildMembers=function() return secret end; inviteFrom("Bob"); eq(#accepts,0); GetNumGuildMembers=count
    inviteFrom("Bob"); eq(#accepts,1); yes(logged("accepted Bob's invite"))
    joinParty("Bob"); moveTo("9500"); advance(3.1); drain(); eq(#leaves,1)
end)
test("0.4 T8: hostOwn carries our own name key (it was dropped by an and-expression in 7.3)",function()
    local N=loadAddon(); establish(N); eq(N.Main.hostOwn().self,"me")
end)
test("0.4 T8: Auto accept and leave: on by default, saved, /le hop auto and the toggle; off means manual",function()
    local N=loadAddon(); BULO=nil; establish(N); yes(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,true)
    slash("hop auto off"); no(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,false); yes(logged("Auto accept and leave is off"))
    askBob(N); inviteFrom("Bob"); eq(#accepts,0); yes(popup.shown)
    N.Main.started=false; N.Main.start(); drain(); no(N.Main.autoHop(),"saved off")
    slash("hop auto on"); yes(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,true); yes(logged("Auto accept and leave is on"))
    LayerEnemiesDB.autoHop="x"; N.Main.started=false; N.Main.start(); drain(); yes(N.Main.autoHop(),"a bad value is the default, on")
    -- turned off after accepting: the group is not left
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); slash("hop auto off"); moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- the window toggle
    N=loadAddon(); BULO=nil; establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.auto:IsShown()); eq(U.auto.label.text,"Auto: on"); U.auto:Click(); drain(); no(N.Main.autoHop()); eq(U.auto.label.text,"Auto: off")
    U.select("reported"); no(U.auto:IsShown())
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="call" or k=="callArt" or k=="netNotice" or k=="findShare" or k=="findNotice",k) end
    eq(forbidden,0)
end)

-- 1.0 T1: Wire routes with a text check each, budgets, queue and priority, offline skip; Net switches and consent.
local function netOn(N,...) for _,k in ipairs({...}) do N.Net.SHIP[k]=true end end
local GOOD_WE="H|0.1.0|1|100|7086|0|0|0"
test("1.0 T1: each route's text check: WEFF1 and HeadHunter carry only their planned types",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we","hh"); N.Net.setConsent("public")
    local function t(prefix,text,kind,target,opts,want) local ok,why=Wr.send(prefix,text,kind,target,opts); eq(why,want,prefix.." "..tostring(text).." "..kind) end
    t("WEFF1",GOOD_WE,"GUILD",nil,{net="we"},"sent")
    t("WEFF1","Z|1","GUILD",nil,{net="we"},"bad text"); t("WEFF1","H|1","WHISPER","Bob",{net="we",scope="public"},"bad text")
    t("WEFF1","D|x","PARTY",nil,{net="we"},"bad text"); t("WEFF1","h|1","GUILD",nil,{net="we"},"bad text")
    t("WEFF1","P|x","WHISPER","Bob",{net="we",scope="public"},"sent")
    advance(10)
    for _,ty in ipairs({"P","L","D","T","U","V","X"}) do t("HeadHunter","1A"..ty..":x","WHISPER","Bob",{net="hh",scope="public"},"bad text") end
    t("HeadHunter","1AN:","WHISPER","Bob",{net="hh",scope="public"},"bad text"); t("HeadHunter","2AN:x","WHISPER","Bob",{net="hh",scope="public"},"bad text")
    t("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public"},"sent")
    -- a network route without its net named in opts is refused
    t("WEFF1",GOOD_WE,"GUILD",nil,nil,"network off")
    eq(forbidden,0)
end)
test("1.0 T1: global budget: 8 at once, 1 per 1.5 s, never more than 40 in 60 s",function()
    local N=loadAddon(); local Wr=N.Wire
    local sentN=0
    local function try() local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own"}); if ok then sentN=sentN+1 end; return ok,why end
    netOn(N,"we")
    for i=1,8 do if i%2==0 then yes((try())) else yes((Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we",prio="own"}))) end end
    local ok,why=try(); no(ok); eq(why,"throttled")
    -- a different prefix shares the global budget
    ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"throttled")
    -- 60 s of steady sends: the cap of 40 in any 60 s holds (8 + one per 1.5 s would be 48)
    N=loadAddon(); Wr=N.Wire; sentN=0
    local prefixes={"LEGW1","WEFF1"}; netOn(N,"we")
    for i=1,120 do
        Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}); Wr.send("WEFF1",GOOD_WE,"PARTY",nil,{net="we",prio="own"})
        advance(0.5)
    end
    local inWindow=0; for _,m in ipairs(sent) do if m.at and m.at>clock-60 then inWindow=inWindow+1 end end
    -- the per-minute cap, checked on the send times
    local times={}; for _,m in ipairs(sent) do times[#times+1]=m.at end
    for i=1,#times do local n=0; for j=i,#times do if times[j]-times[i]<60 then n=n+1 end end; yes(n<=40,"window from "..i..": "..n) end
end)
test("1.0 T1: whispers outside guild and group: 4 a minute to one player, 20 a minute in total; consent guild sends none",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    local function hh(target) return Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER",target,{net="hh",scope="public",prio="owed"}) end
    for i=1,4 do yes((hh("Bob"))); advance(2.1) end
    local ok,why=hh("Bob"); no(ok); eq(why,"throttled","5th to one player in a minute")
    advance(60); yes((hh("Bob")))
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    local names={}; for i=1,26 do names[i]="Peer"..string.char(96+i) end
    local okN=0; for i=1,26 do if hh(names[i]) then okN=okN+1 end; advance(2.1) end
    eq(okN,20,"20 public whispers a minute")
    -- consent guild: no public whisper, guild scope still allowed
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh","we"); N.Net.setConsent("guild")
    ok,why=hh("Bob"); no(ok); eq(why,"no consent")
    yes(Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we",scope="guild"}))
    -- no choice made: public (owner decision 2026-11-14)
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh"); yes((hh("Bob")))
    eq(forbidden,0)
end)
test("1.0 T1: guild budget: 20 a minute over all prefixes",function()
    local N=loadAddon(); N.Main.we=nil; local Wr=N.Wire; netOn(N,"we")
    local okN=0
    for i=1,30 do
        if Wr.send(i%2==0 and "LEGW1" or "WEFF1",i%2==0 and "R|"..i or GOOD_WE,"GUILD",nil,{net="we",prio="own"}) then okN=okN+1 end
        advance(2.01)
    end
    eq(okN,20)
end)
test("1.0 T1: throttled by the client: dropped, never retried, that prefix pauses 30 s; offline target skipped 1 h",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    sendResult=3; local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own",queue=true}); no(ok); eq(why,"throttled"); sendResult=0
    advance(5); drain(); eq(#sent,1,"not retried")
    ok,why=Wr.send("LEGW1","R|2","GUILD",nil,{prio="own"}); no(ok); eq(why,"paused")
    yes(Wr.send("LFSw","Q","GUILD"),"other prefixes go on")
    advance(26); yes(Wr.send("LEGW1","R|3","GUILD",nil,{prio="own"}))
    sendResult=8; no(Wr.send("LEGW1","R|4","GUILD",nil,{prio="own"})); sendResult=0; advance(2.1); eq(select(2,Wr.send("LEGW1","R|5","GUILD")),"paused")
    -- offline
    sendResult=12; ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}); no(ok); eq(why,"offline"); sendResult=0
    advance(10); ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}); no(ok); eq(why,"offline")
    advance(3600); yes(Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}))
end)
test("1.0 T1: the queue: over budget a queued line waits; full, the oldest forward goes and a click stays; priority order",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we")
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end; eq(#sent,5,"LEGW1 bucket 5")
    for i=1,3 do Wr.send("WEFF1",GOOD_WE,"PARTY",nil,{net="we",prio="own"}) end; eq(#sent,8,"all 8 spent")
    local ok,why=Wr.send("LEGW1","R|f1","GUILD",nil,{prio="forward",queue=true}); yes(ok); eq(why,"queued")
    for i=2,39 do Wr.send("LEGW1","R|f"..i,"GUILD",nil,{prio="forward",queue=true}) end
    eq(Wr.queued(),39)
    yes(Wr.send("LEGW1","R|own","GUILD",nil,{prio="own",queue=true})); eq(Wr.queued(),40)
    -- full: a click goes in, the oldest forward goes out
    ok,why=Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0>","WHISPER","Alice",{prio="click",queue=true}); yes(ok); eq(why,"queued")
    eq(Wr.queued(),40); no(Wr.isQueued("R|f1")); yes(Wr.isQueued("R|f2"))
    -- full of non-forwards, a forward is refused
    N=loadAddon(); Wr=N.Wire
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    for i=1,40 do Wr.send("LEGW1","R|o"..i,"GUILD",nil,{prio="own",queue=true}) end
    ok,why=Wr.send("LEGW1","R|fx","GUILD",nil,{prio="forward",queue=true}); no(ok); eq(why,"queue full")
    -- order: the click first, then own, then owed, then forward
    N=loadAddon(); Wr=N.Wire
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    Wr.send("LEGW1","R|F","GUILD",nil,{prio="forward",queue=true}); Wr.send("LEGW1","R|W","GUILD",nil,{prio="owed",queue=true})
    Wr.send("LEGW1","R|O","GUILD",nil,{prio="own",queue=true}); Wr.send("LEGW1","R|C","GUILD",nil,{prio="click",queue=true})
    local before=#sent
    for _=1,20 do advance(2.1); drain() end
    local order={}; for i=before+1,#sent do order[#order+1]=sent[i].text end
    eq(table.concat(order,","),"R|C,R|O,R|W,R|F")
    eq(Wr.queued(),0)
end)
test("1.0 T1: in combat every rate halves; in an instance only clicks go",function()
    local N=loadAddon(); local Wr=N.Wire; combat=true
    local okN=0; for i=1,8 do if Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) then okN=okN+1 end end
    eq(okN,2,"LEGW1 bucket 5 at half cost: 2"); combat=false
    N=loadAddon(); Wr=N.Wire; inInstance=true
    local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own"}); no(ok); eq(why,"instance")
    yes(Wr.send("LFSw","Q","GUILD",nil,{prio="click"}))
    ok,why=Wr.send("LEGW1","R|2","GUILD"); no(ok); eq(why,"instance","no opts counts as a forward")
end)
test("1.0 T1: network off sends nothing and registers no timer; the real addon loaded stands its prefix down",function()
    local N=loadAddon(); local Wr=N.Wire; local Net=N.Net
    local ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"network off")
    local before=#timers; local ran=false
    no(Net.after("we",5,function() ran=true end)); eq(#timers,before,"no timer while shipped off")
    netOn(N,"we"); yes(Net.after("we",5,function() ran=true end)); eq(#timers,before+1); advance(5); drain(); yes(ran)
    -- the player's switch
    Net.setSwitch("we",false); eq(LayerEnemiesDB.nets.we,false); ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"network off")
    ran=false; no(Net.after("we",5,function() ran=true end)); advance(6); drain(); no(ran)
    -- a timer registered while on does nothing once the network is off
    Net.setSwitch("we",true); yes(Net.after("we",5,function() ran=true end)); Net.setSwitch("we",false); advance(6); drain(); no(ran)
    Net.setSwitch("we",true)
    -- stand-down
    loaded.WarEffortScout=true; ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"stand down")
    no(Net.after("we",5,function() end)); loaded.WarEffortScout=nil
    netOn(N,"hh"); Net.setConsent("public"); loaded.HeadHunter=true
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public"}); no(ok); eq(why,"stand down"); loaded.HeadHunter=nil
    -- consent and switches are saved; anything odd reads as no consent / default on
    eq(LayerEnemiesDB.consent,"public"); LayerEnemiesDB.consent="all"; LayerEnemiesDB.nets={we="x",hh=false}
    N.Main.started=false; N.Main.start(); drain()
    eq(N.Net.chosen(),nil); eq(LayerEnemiesDB.consent,nil); eq(LayerEnemiesDB.nets.we,true); eq(LayerEnemiesDB.nets.hh,false)
    eq(sent and #sent or 0,0); eq(forbidden,0)
end)

test("1.0 T1: callers carry their priority: a hop click and Find hosts go in an instance, host and relay lines do not",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({key="8000",host=true})}); advance(1); inInstance=true
    yes(hopNow(N,rec(N))); eq(#sent,1); eq(sent[1].prefix,"LayerSwap")
    slash("hosts find"); eq(#sent,3,"Q and F|1 are clicks")
    eq(select(2,N.Wire.send("LEGW1","R|1","GUILD",nil,{prio="forward"})),"instance")
end)

-- 1.0 T2: one record for every network: hand, hops, pos and the origin's time; one row per origin, zone and 5 s.
local function base(over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
    layer={ns="server",value="8000"},heard=500,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return o end
test("1.0 T2: a wrapped, enveloped, relayed or synced record is never first-hand",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base()).hand,"first")
    eq(R.new(base({via="Other"})).hand,"relayed","another carrier")
    eq(R.new(base({wrapped=true})).hand,"relayed"); eq(R.new(base({wrapped=true,hand="first"})).hand,"relayed","a claim of first is not enough")
    eq(R.new(base({hand="relayed"})).hand,"relayed")
    eq(R.new(base({src="guild",label="we"})).hand,"relayed","a guild relay")
    eq(R.new(base({via="scout"})).hand,"first","same name, other case")
    eq(R.new(base({hops=3})).hops,3); eq(R.new(base({hops=0})),nil); eq(R.new(base({hops=17})),nil); eq(R.new(base({hops="x"})),nil)
    eq(R.new(base({hand="maybe"})),nil)
    -- decoders: a War Effort G wrapper and a HeadHunter envelope are relayed; a direct P is first-hand
    local _,feed=reportFixture(N)
    local r=feed(VG,"Carrier"); yes(r); eq(r.hand,"relayed"); eq(r.hops,1)
    r=feed(VC,"Reporter"); yes(r); eq(r.hand,"first")
    local e=hh(N,HHE,"Carrier")[1]; yes(e); eq(e.hand,"relayed"); eq(e.hops,1)
    local p=hh(N,HHP,"Fighter")[1]; yes(p); eq(p.hand,"first"); eq(p.hops,nil)
    -- an envelope sent by its own author is still an envelope; a War Effort wrapper naming its carrier as origin too
    local own=hh(N,HHE,"Mira Vale")[1]; yes(own); eq(own.hand,"relayed")
    eq(feed(VG,"Scout One"),nil,"a wrapper carried by its own origin is refused before it becomes a record")
end)
test("1.0 T2: at is the origin's time, never the time we heard it",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base({heard=500,age=40})).at,460); eq(R.new(base({heard=500})).at,500)
    eq(R.new(base({heard=500,at=470})).at,470); eq(R.new(base({heard=500,at=501})),nil,"after receipt")
    local _,feed=reportFixture(N)
    local r=feed(VC,"Reporter",200,"GUILD",720140); yes(r); eq(r.heard,200); eq(r.age,40); eq(r.at,160)
    local h=hh(N,"1AP:13k;"..b36(HHT-30)..";dw;6y;a1;;",nil,HHT)[1]; yes(h); eq(h.at,50-30)
end)
test("1.0 T2: positions are labelled: enemy, observer, victim or none",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base({x=.5,y=.5})).pos,"enemy"); eq(R.new(base()).pos,"none","no coordinates")
    eq(R.new(base({x=.5,y=.5,pos="observer"})).pos,"observer"); eq(R.new(base({src="gb",kind="death",x=.5,y=.5,pos="victim"})).pos,"victim")
    eq(R.new(base({pos="victim"})).pos,"none","no coordinates: none whatever is claimed"); eq(R.new(base({x=.5,y=.5,pos="there"})),nil)
    eq(hh(N,HHP)[1].pos,"observer","HeadHunter positions are the reporter's")
    for _,s in ipairs({"spy","fspy","sent","gb","wos","ft"}) do yes(R.new(base({src=s,kind="seen"})),s) end
    yes(R.new(base({kind="death",src="wos"}))); eq(R.new(base({src="xx"})),nil)
    -- the window and /le reports say whose position it is and that a row was relayed
    establish(N); local T=N.Store
    yes(T.report(N.Main.store,R.new(base({heard=clock,x=.5,y=.5,pos="observer",via="Carrier",rid="7"})),clock))
    local rows=T.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"relayed"); eq(rows[1].positionKind,"observer's position")
    slash("reports"); yes(logged("relayed"))
    local U=N.UI; U.toggle(); U.select("reported")
    local found=false; for _,x in ipairs(U.pool) do if x:IsShown() and x.sub.text and x.sub.text:find("relayed",1,true) then found=true end end; yes(found)
end)
test("1.0 T2: a record older than its network's limit is dropped, counted from the origin's time",function()
    local N=loadAddon(); establish(N); local T,R,st=N.Store,N.Record,N.Main.store
    local ok,why=T.report(st,R.new(base({heard=clock,age=600,rid="a"})),clock); no(ok); eq(why,"expired")
    yes(T.report(st,R.new(base({heard=clock,age=590,rid="b"})),clock))
    advance(10); eq(#T.rows(st,clock,"reported"),0,"gone 600 s after the origin's time")
    ok,why=T.report(st,R.new(base({src="hh",kind="fight",heard=clock,age=300,rid="c",layer={ns="unknown"}})),clock); eq(why,"expired")
    for _,s in ipairs({"spy","fspy","sent"}) do eq(T.ttl({src=s}),600,s) end
    for _,s in ipairs({"gb","wos","ft"}) do eq(T.ttl({src=s}),900,s) end
end)
test("1.0 T2: one row per origin, zone and 5 s; first-hand first, then the copy with names",function()
    -- (round 2, T2-1: a first-hand copy wins before the name count; the guild relay's copy is relayed)
    local N=loadAddon(); establish(N); local T,R,st=N.Store,N.Record,N.Main.store
    local hashOnly=R.new(base({heard=clock,rid="10",enemies={{hash="abc"}},count=2}))
    local named=R.new(base({src="guild",label="own",via="Scout",heard=clock,rid="O1",enemies={{name="Kora Reed"},{name="Ann Lee"}},count=2}))
    yes(T.report(st,hashOnly,clock)); local ok,why=T.report(st,named,clock); no(ok); eq(why,"duplicate")
    local rows=T.rows(st,clock,"reported"); for _,row in ipairs(rows) do eq(row.record,hashOnly) end
    -- the other way round: the first-hand copy replaces the relayed named one
    N=loadAddon(); establish(N); T,R,st=N.Store,N.Record,N.Main.store
    yes(T.report(st,R.new(base({src="guild",label="own",heard=clock,rid="O2",enemies={{name="Kora Reed"}}})),clock))
    yes(T.report(st,R.new(base({heard=clock+3,rid="11",enemies={{hash="abc"}}})),clock+3))
    -- 6 s apart, another zone or another origin: separate rows
    yes(T.report(st,R.new(base({heard=clock+6,rid="12"})),clock+6))
    -- two reports of one network within 5 s are two sightings
    yes(T.report(st,R.new(base({heard=clock+6,rid="14"})),clock+6))
    yes(T.report(st,R.new(base({origin="Other",via="Other",heard=clock,rid="13"})),clock))
    -- both first-hand on two networks: the one with names wins
    N=loadAddon(); establish(N); T,R,st=N.Store,N.Record,N.Main.store
    yes(T.report(st,R.new(base({heard=clock,rid="20",enemies={{hash="abc"}}})),clock))
    local p=R.new(base({src="hh",kind="fight",heard=clock,rid="21",layer={ns="unknown"},enemies={{name="Kora Reed"}}}))
    yes(T.report(st,p,clock)); rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].record,p)
    local ok2,why2=T.report(st,R.new(base({heard=clock+3,rid="22",src="hh",kind="fight",layer={ns="unknown"},enemies={{hash="abc"}}})),clock+3); yes(ok2,"same network: its own row")
end)

-- 1.0 T3: Directory: the two named channels, joined only at consent "public", read only when safe, never sent to.
local function dirReady(N) netOn(N,"we","hh"); N.Net.setConsent("public") end
test("1.0 T3: the War Effort channel name follows the realm's ruleset; HeadHunter's is fixed",function()
    local N=loadAddon(); local D=N.Directory
    local cases={["Forever RP-PvP2"]="RPPvP",ForeverPvE="PvE",["Forever PvP"]="PvP",["Warp PvE"]="PvE",["Role Play"]="RP",["RP2"]="RP",
        ["Sharpvale"]="sharpvale",["Forever Legends 2"]="foreverleg",["Normal"]="PvE",["ForeverRP-PvP"]="RPPvP",["R.P. Land"]="RP",["Test Realm"]="testrealm"}
    for realm,tag in pairs(cases) do eq(D.rulesetTag(realm),tag,realm) end
    eq(D.rulesetTag(""),nil); eq(D.rulesetTag(secret),nil); eq(D.rulesetTag(nil),nil); eq(D.rulesetTag("Ab 2"),"ab")
    local was=issecretvalue; issecretvalue=function(v) return v=="Hidden PvP" or (was and was(v)) end
    eq(D.rulesetTag("Hidden PvP"),nil,"a secret realm name is never read"); issecretvalue=was
    eq(D.channel("we"),"WarEfforttestrealmA"); eq(D.channel("hh"),"HeadHunterSync")
    UnitFactionGroup=function() return "Neutral" end; eq(D.channel("we"),nil,"no faction letter: no channel")
end)
test("1.0 T3: no join at consent guild; joins at public; leaves on switch-off or consent guild",function()
    local N=loadAddon(); local D=N.Directory; netOn(N,"we","hh")
    N.Net.setConsent("guild"); D.sync(); eq(#joined,0,"guild only")
    N.Net.setConsent("public"); eq(#joined,2,"setting consent syncs"); eq(table.concat(joined,","),"HeadHunterSync,WarEfforttestrealmA")
    D.sync(); eq(#joined,2,"no second join")
    N.Net.setSwitch("hh",false); eq(leftCh[#leftCh],"HeadHunterSync")
    N.Net.setConsent("guild"); eq(leftCh[#leftCh],"WarEfforttestrealmA")
    -- a network shipped off never joins, and the real addon loaded joins nothing for us
    N=loadAddon(); D=N.Directory; N.Net.setConsent("public"); D.sync(); eq(#joined,0)
    N=loadAddon(); D=N.Directory; loaded.HeadHunter=true; dirReady(N); eq(table.concat(joined,","),"WarEfforttestrealmA")
    -- an instance or combat at the time: no join now
    N=loadAddon(); D=N.Directory; inInstance=true; dirReady(N); eq(#joined,0); inInstance=false
    combat=true; D.sync(); eq(#joined,0); combat=false; D.sync(); eq(#joined,2)
    eq(forbidden,0)
end)
test("1.0 T3: the member list is read after selecting the channel, never with the Channels window open, in combat or an instance",function()
    local N=loadAddon(); local D=N.Directory; dirReady(N)
    chanMembers.HeadHunterSync={"Me","Peer One","Peer Two-Other","Me-TestRealm","Bad|Name","Me-OtherRealm"}
    yes(D.refresh("hh")); eq(#selected,1); eq(D.members("hh"),nil,"read 3 s later")
    advance(2.9); eq(D.members("hh"),nil)
    -- ourselves (our realm or none) and unreadable names are skipped; our namesake on another realm is someone else
    advance(0.2); local m=D.members("hh"); eq(#m,3); eq(m[1],"Peer One"); eq(m[2],"Peer Two-Other"); eq(m[3],"Me-OtherRealm"); eq(D.count("hh"),3)
    ChannelFrame={IsShown=function() return true end}; no(D.refresh("hh")); eq(#selected,1); ChannelFrame=nil
    combat=true; no(D.refresh("hh")); combat=false
    inInstance=true; no(D.refresh("hh")); inInstance=false
    -- unreadable names are skipped; at most 500 read
    chanMembers.HeadHunterSync={}; for i=1,600 do chanMembers.HeadHunterSync[i]="Peer"..string.char(97+i%26)..string.char(97+math.floor(i/26)%26) end
    yes(D.refresh("hh")); advance(3.1); drain(); eq(#D.members("hh"),500)
    -- the first read 10 s after joining, then every 300 s while public; none after switching off
    local function hhSel() local n=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then n=n+1 end end; return n end
    local before=hhSel(); advance(4); eq(hhSel(),before+1,"10 s after joining")
    advance(299); eq(hhSel(),before+1); advance(1); eq(hhSel(),before+2,"the 300 s refresh")
    N.Net.setSwitch("hh",false); advance(600); eq(hhSel(),before+2); eq(D.members("hh"),nil,"forgotten on switch-off")
    eq(forbidden,0)
end)
test("1.0 T3: nothing is ever sent to a channel; channel calls only from Directory.lua",function()
    local N=loadAddon(); for prefix,kinds in pairs(N.Wire.ROUTES) do eq(kinds.CHANNEL,nil,prefix) end
    JoinChannelByName("x"); LeaveChannelByName("x"); SetSelectedDisplayChannel(1); eq(forbidden,3)
    forbidden=0
    for _,file in ipairs(addonFiles()) do
        local text=assert(io.open("LayerEnemies/"..file..".lua")):read("*a")
        for _,word in ipairs({"JoinChannelByName","LeaveChannelByName","SetSelectedDisplayChannel","JoinTemporaryChannel","JoinPermanentChannel"}) do
            local n=0; for _ in text:gmatch("%f[%w_]"..word.."%f[^%w_]") do n=n+1 end
            if file~="Directory" or word:find("Temporary") or word:find("Permanent") then eq(n,0,file.." "..word) else yes(n==1,file.." "..word.." "..n) end
        end
    end
end)

-- 0.3.1 S1 narrowed and three of Astra's extras (hermes)
test("0.3.1 S1 narrowed: only a reporter who is himself a Bulo/LayerSwap row seen while unknown is refused",function()
    -- the reporter is a Bulo row listed on another layer: still refused (the row says nothing reliable while unknown)
    local N=loadAddon(); chatBox(); advance(1)
    guildLine("L 9000|100|h","Alpha"); hopReport(301,8000,"Alpha")
    slash("reports"); local r=N.Main.hopList.records[1]; yes(r)
    local p=N.Main.hopPreview(r); no(p.enabled); eq(p.reason,N.Invite.HINT)
    slash("hop 1"); eq(#opened,0); eq(#sent,0)
    -- a LayerSwap book row as the reporter: refused too
    N=loadAddon(); chatBox(); advance(1); LayerSwapDB={book={Alpha=page({layer="8000-3"})}}; hopReport(301,8000,"Alpha")
    slash("reports"); r=N.Main.hopList.records[1]; p=N.Main.hopPreview(r); no(p.enabled); eq(p.reason,N.Invite.HINT); LayerSwapDB=nil
    -- another Bulo row on that layer and a plain reporter: the reporter draft of 0.3.0
    N=loadAddon(); chatBox(); advance(1); guildLine("L 8000|100|h","Alpha"); hopReport(301,8000,"Scout")
    slash("reports"); r=N.Main.hopList.records[1]; p=N.Main.hopPreview(r); yes(p.enabled); eq(p.label,"Ask Scout (chat)")
    slash("hop 1"); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK); eq(#sent,0)
end)
test("0.3.1 extra: a readable zone change clears the /le hosts numbers",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Alpha"); slash("hosts"); yes(N.Main.hostList)
    deliver("ZONE_CHANGED"); drain(); yes(N.Main.hostList,"same zone keeps them")
    map=nil; deliver("ZONE_CHANGED_NEW_AREA"); drain(); yes(N.Main.hostList,"an unreadable map is no zone change"); map=100
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Main.hostList,nil)
    slash("ask 1"); eq(#opened,0); yes(logged("run /le hosts first")); slash("hop host 1"); eq(#sent,0)
end)
test("0.3.1 extra: /le ask from a list taken while our layer was unknown re-checks before drafting",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Alpha"); slash("hosts"); yes(N.Main.hostList.rows[1].unknownOwn)
    establish(N); slash("ask 1"); eq(#opened,0); yes(logged("hosts changed, check again."))
    slash("hosts"); slash("ask 1"); eq(#opened,1); eq(opened[1].text,"/w Alpha "..ASK)
    -- a list taken with our layer known and still known drafts as before
    N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bravo"); slash("hosts"); slash("ask 1"); eq(#opened,1)
end)
test("0.3.1 extra: with LayerSwap loaded our remembered replies are never used, even while its saved table is missing",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob"); drain(); yes(N.Main.heard.heard.Bob)
    N.Main.guildLines.Bob=nil; LayerSwapDB=nil
    eq(#N.Main.candidates(),1,"not loaded: ours stands in")
    loaded.LayerSwap=true; eq(#N.Main.candidates(),0,"loaded, no table yet: its book is empty")
    loaded.LayerSwap=nil; eq(#N.Main.candidates(),1)
end)

-- 0.4.0 review round 1 (مانع): M1 identity, S1 party, S2 spaced names, S3 guests
test("0.4 fix M1: the player checked is the player invited; realms are kept unless they are ours",function()
    local N=loadAddon(); local A,I=N.Adapters,N.Invite
    -- one name rule: key and invite target, our realm dropped, any other kept
    local n,k,tgt=I.name("Alpha-OtherRealm"); eq(k,"alpha-otherrealm"); eq(tgt,"Alpha-OtherRealm")
    n,k,tgt=I.name("Alpha-TestRealm"); eq(k,"alpha"); eq(tgt,"Alpha")
    n,k,tgt=I.name("Alpha"); eq(k,"alpha"); eq(tgt,"Alpha")
    -- a foreign-realm sender never matches a bare roster entry or one of our realm
    roster={{"Alpha",true}}; eq(A.guildMember("Alpha-OtherRealm"),false)
    roster={{"Alpha-TestRealm",true}}; eq(A.guildMember("Alpha-OtherRealm"),false)
    roster={{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha-OtherRealm"),true)
    roster={{"Alpha-TestRealm",true}}; eq(A.guildMember("alpha"),false,"spelled differently")
    -- a bare (our realm) sender does not win while a namesake from another realm is in the roster
    roster={{"Alpha",true},{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha"),false); eq(A.guildMember("Alpha-OtherRealm"),true)
    roster={{"Alpha-TestRealm",true},{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha"),false)
    -- end to end: a qualified guild member is invited by his whole name
    hostReady(N,{}); roster={{"Alpha-OtherRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Alpha-OtherRealm"); eq(#invites,1); eq(invites[1],"Alpha-OtherRealm")
    -- the same request from a foreign Alpha with only our Alpha in the roster: nothing
    N=loadAddon(); hostReady(N,{"Alpha"}); lsw("inv layer <LS 100 want 7086-7>","Alpha-OtherRealm"); eq(#invites,0)
    -- our own Alpha: invited by the bare name
    lsw("inv layer <LS 100 want 7086-7>","Alpha"); eq(#invites,1); eq(invites[1],"Alpha")
    -- Wire keeps a foreign realm and drops ours
    N=loadAddon(); yes(N.Wire.invite("Cara-OtherRealm",clock)); eq(invites[#invites],"Cara-OtherRealm")
    advance(11); yes(N.Wire.invite("Dana-TestRealm",clock)); eq(invites[#invites],"Dana")
end)
test("0.4 fix S1: the party is unreadable (busy) when the count and the party units disagree or a unit read fails",function()
    local N=loadAddon(); local A=N.Adapters
    units.party1={name="Cy"}; leader=true; local p=A.party(); yes(p); eq(#p.members,1)
    GetNumGroupMembers=function() return 5 end; eq(A.party(),nil,"5 counted, 1 listed")
    GetNumGroupMembers=function() return 0 end; eq(A.party(),nil,"none counted, 1 listed")
    GetNumGroupMembers=function() local n=0; for i=1,4 do if units["party"..i] then n=n+1 end end; return n>0 and n+1 or 0 end
    local was=UnitExists
    UnitExists=function(u) if u:find("party") then return nil end; return true end; eq(A.party(),nil,"nil exists")
    UnitExists=function(u) if u:find("party") then return secret end; return true end; eq(A.party(),nil,"secret exists")
    UnitExists=function(u) if u:find("party") then error("x") end; return true end; eq(A.party(),nil,"throws")
    UnitExists=nil; eq(A.party(),nil,"missing"); UnitExists=was
    -- one unreadable slot hidden by a matching count: party1 unreadable, party2 listed, count 2
    units.party1=nil; units.party2={name="Di"}
    UnitExists=function(u) if u=="party1" then return nil end; return was(u) end; eq(A.party(),nil,"one slot unreadable"); UnitExists=was
    units.party1={name="Cy"}; units.party2=nil
    UnitIsGroupLeader=function() return secret end; eq(A.party(),nil,"unreadable leader")
    -- the guild host answers busy, no invite
    N=loadAddon(); hostReady(N); GetNumGroupMembers=function() return 5 end
    lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,0); yes(sent[1] and sent[1].text:find("|-$"),"busy reply")
end)
test("0.4 fix S2: a spaced name with a realm is one rule everywhere: guild check, host and Wire",function()
    local N=loadAddon(); local I=N.Invite
    local n,k,tgt=I.name("Tam Reed-OtherRealm"); eq(n,"Tam Reed-OtherRealm"); eq(k,"tam reed-otherrealm"); eq(tgt,"Tam Reed-OtherRealm")
    n,k,tgt=I.name("Tam Reed-TestRealm"); eq(k,"tam reed"); eq(tgt,"Tam Reed")
    for _,bad in ipairs({"Tam Reed Lee","Tam  Reed","Tam Reed-","Tam Reed-Other Realm","T Reed","Tam-Reed-Other","Tam Reed-Real|m"}) do eq(I.name(bad),nil,bad) end
    hostReady(N,{}); roster={{"Tam Reed-OtherRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Tam Reed-OtherRealm"); eq(#invites,1); eq(invites[1],"Tam Reed-OtherRealm")
    N=loadAddon(); hostReady(N,{}); roster={{"Tam Reed-TestRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Tam Reed"); eq(#invites,1); eq(invites[1],"Tam Reed")
end)
test("0.4 fix S3: an asker already in our party gets same; a guest who joined frees the pending slot at once",function()
    local N=loadAddon(); hostReady(N,{"Bob","Cy","Di","Ed","Fay"})
    lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,1)
    units.party1={name="Bob"}; leader=true; grouped=true; deliver("GROUP_ROSTER_UPDATE"); drain()
    advance(61); sent={}; lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,1,"no second invite"); eq(sent[1].text,"same")
    -- Bob joined: his slot is not counted twice. Cy, Di and Ed get invites (Bob + 3 pending + us = 5)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Cy"); eq(#invites,2)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Di"); eq(#invites,3)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Ed"); eq(#invites,4)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Fay"); eq(#invites,4,"now full")
    local G=N.GuildHost; local s=G.new(); s.on=true; s.pending.bob=clock; s.hosted.bob=true
    local own={self="me",zone=100,key="7086",inInstance=false,inCombat=false,raid=false,leader=true,members={"Bob"},member=true}
    eq((G.decide(s,{name="Cy",zone=100,want="7086-1"},own,clock)),"invite"); eq(s.pending.bob,nil,"cleared on join")
end)

test("0.4 host saved (review 6c): a host resumed at login answers no F before the first guild roster",function()
    local normal=deliver
    deliver=function(event,...) if event=="ADDON_LOADED" and (...)=="LayerEnemies" then return end; return normal(event,...) end
    local N=loadAddon(); deliver=normal
    LayerEnemiesDB={guildHost=true}; roster={{"Peer-TestRealm",true}}
    deliver("ADDON_LOADED","LayerEnemies"); deliver("PLAYER_LOGIN"); deliver("PLAYER_ENTERING_WORLD"); drain()
    establish(N); yes(N.Main.host.on); eq(N.Adapters.roster.at,nil)
    deliver("CHAT_MSG_ADDON","LEGW1","F|1","GUILD","Peer"); drain(); advance(7)
    eq(#sent,0,"no H before the first roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#sent,0,"the roster alone sends nothing")
    advance(61); deliver("CHAT_MSG_ADDON","LEGW1","F|1","GUILD","Peer"); drain(); advance(7)
    eq(#sent,1); eq(sent[1].text,"H|1|7086|100")
end)

-- Forever names are "First Last"; realms are numeric (owner facts): one name rule everywhere (0.4.0 review S2, must)
local function numericHome() GetRealmName=function() return "7102" end; UnitName=(function(old) return function(u) if u=="player" then return "Me Self","7102" end; return old(u) end end)(UnitName) end
test("0.4 fix S2 (must): First Last, numeric realms; double, leading and trailing spaces and three words refused",function()
    local N=loadAddon(); numericHome(); local I=N.Invite
    local n,k,t=I.name("First Last"); eq(n,"First Last"); eq(k,"first last"); eq(t,"First Last")
    n,k,t=I.name("First Last-7102"); eq(k,"first last"); eq(t,"First Last","our numeric realm dropped")
    n,k,t=I.name("First Last-7105"); eq(k,"first last-7105"); eq(t,"First Last-7105","another numeric realm kept")
    n,k,t=I.name("First Last-OtherRealm"); eq(k,"first last-otherrealm"); eq(t,"First Last-OtherRealm")
    for _,bad in ipairs({"First  Last"," First Last","First Last ","One Two Three","First Last-","First Last-71 02","First|Last","First%Last",
        "First Last-7102-1","First\tLast","Fi.rst Last","First Last-[x]",string.rep("a",37).." Last"}) do eq(I.name(bad),nil,bad) end
    -- the guild check and the invite on numeric realms
    local A=N.Adapters
    roster={{"Alpha Beta-7102",true}}; eq(A.guildMember("Alpha Beta"),true); eq(A.guildMember("Alpha Beta-7102"),true); eq(A.guildMember("Alpha Beta-7105"),false)
    roster={{"Alpha Beta",true},{"Alpha Beta-7105",true}}
    eq(A.guildMember("Alpha Beta"),false,"bare namesake while 7105 is listed"); eq(A.guildMember("Alpha Beta-7102"),false); eq(A.guildMember("Alpha Beta-7105"),true)
    hostReady(N,{}); roster={{"Alpha Beta-7105",true}}
    lsw("inv layer <LS 100 want 7086-7>","Alpha Beta-7105"); eq(#invites,1); eq(invites[1],"Alpha Beta-7105")
    eq(sent[1].text,"heard Alpha Beta|7086-7|100|h","the reply names the asker as his own UnitName reads")
    N=loadAddon(); numericHome(); hostReady(N,{}); roster={{"Cara Dune-7102",true}}
    lsw("inv layer <LS 100 want 7086-7>","Cara Dune"); eq(#invites,1); eq(invites[1],"Cara Dune")
end)
test("0.4 fix S2 (must): the LayerSwap reply grammar takes the spaced name and nothing looser",function()
    local N=loadAddon(); local Wr=N.Wire
    for _,ok in ipairs({"heard First Last|7086-7|100|h","heard First Last-7105|7086-7|100|-","heard Bob|7086-7|100|h"}) do
        local r,why=Wr.send("LayerSwap",ok,"WHISPER","First Last"); yes(r,ok.." "..tostring(why)); advance(7) end
    for _,bad in ipairs({"heard First  Last|7086-7|100|h","heard First Last Third|7086-7|100|h","heard  First Last|7086-7|100|h",
        "heard First Last |7086-7|100|h","heard First%Last|7086-7|100|h"}) do
        local r,why=Wr.send("LayerSwap",bad,"WHISPER","First Last"); no(r,bad); eq(why,"bad text"); advance(7) end
    -- a heard reply naming us by our spaced name is read (Hop.reply compares the whole name)
    local rep=N.Hop.reply("heard Me Self|7086-7|100|h","First Last","Me Self"); yes(rep); eq(rep.layer,"7086-7")
end)
test("0.3.x name paths: a Bulo guild line from First Last-OtherRealm keeps the realm; ours is dropped",function()
    local N=loadAddon(); numericHome(); local A=N.Adapters; local list={}
    yes(A.guildLine(list,"L 8000|100|h","Alpha Beta-7105",1000)); yes(list["Alpha Beta-7105"]); eq(list["Alpha Beta"],nil)
    yes(A.guildLine(list,"L 8000|100|h","Cara Dune-7102",1000)); yes(list["Cara Dune"])
    yes(A.guildLine(list,"L 8000|100|h","Dana-7105",1000)); yes(list["Dana-7105"])
    no(A.guildLine(list,"L 8000|100|h","Eli  Fox",1000)); no(A.guildLine(list,"L 8000|100|h","One Two Three",1000))
end)

test("0.4 host (review 6c): no H before this session's first guild roster; turning hosting on then announces once on it",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; eq(N.Adapters.roster.at,nil)
    slash("host on"); yes(N.Main.host.on); eq(#legwSent("H|"),0,"no roster read yet")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"the owed H on the first roster"); eq(legwSent("H|")[1].text,"H|1|7086|100")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"once")
    -- turned off before the roster: nothing owed
    N=loadAddon(); establish(N); slash("host on"); slash("host off"); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),0)
    -- a roster already read: the H goes at once, as before
    N=loadAddon(); establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); eq(#legwSent("H|"),1)
    -- announceHost itself refuses before a roster
    N=loadAddon(); establish(N); N.Main.host.on=true; no(N.Main.announceHost()); eq(#sent,0)
end)

test("1.0 T2 names: every network's sender and origin pass the one name rule (First Last, numeric realms)",function()
    local N=loadAddon(); numericHome(); local R=N.Record
    local function mk(over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
        layer={ns="server",value="8000"},heard=500,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return R.new(o) end
    yes(mk({origin="First Last",via="First Last"})); yes(mk({origin="First Last-7105",via="Carrier Two"}))
    for _,bad in ipairs({"First  Last"," First Last","One Two Three","Bad|Name","First Last-","x"}) do
        eq(mk({origin=bad,via=bad}),nil,"origin "..bad); eq(mk({via=bad}),nil,"via "..bad) end
    -- our realm is the same player: first-hand, one key
    local r=mk({origin="Scout",via="Scout-7102"}); eq(r.hand,"first"); eq(r.id,"we:scout:1")
    eq(mk({origin="Scout-7102",via="Scout"}).id,"we:scout:1")
    eq(mk({origin="Scout-7105",via="Scout"}).hand,"relayed","another realm is another player")
    -- the store's one-row-per-origin rule uses the same key
    establish(N); local T,st=N.Store,N.Main.store
    yes(T.report(st,mk({src="hh",kind="fight",origin="Scout",via="Scout",heard=clock,rid="O1",layer={ns="unknown"},enemies={{name="Kora Reed"}}}),clock))
    local ok,why=T.report(st,mk({origin="Scout-7102",via="Scout-7102",heard=clock,rid="9",enemies={{hash="abc"}}}),clock); no(ok); eq(why,"duplicate","one origin key across networks")
    -- the decoders: War Effort and HeadHunter reporters with spaced names come through; malformed ones do not
    local _,feed=reportFixture(N); yes(feed(VC,"Reporter Two")); eq(feed(VC,"Reporter  Two"),nil)
end)

-- 0.4.0 round 2 (مانع r040b) Task 8: arm only on a real send; guild ask from answerers or listed hosts; group end,
-- instance and combat
test("0.4 T8 B1: a drafted whisper arms auto-accept only once we see it go out to that host",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); advance(1)
    local r=rec(N); yes(hopNow(N,r)); drain(); eq(#opened,1); eq(#sent,0)
    inviteFrom("Scout"); eq(#accepts,0,"the draft was never sent"); popup.shown=false
    deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Other"); deliver("CHAT_MSG_WHISPER_INFORM","hello","Scout"); drain()
    inviteFrom("Scout"); eq(#accepts,0,"another target or another text"); popup.shown=false
    deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Scout-TestRealm"); drain()
    inviteFrom("Scout"); eq(#accepts,1,"sent: armed")
end)
test("0.4 T8 B1: the guild ask arms on our own /g line; then only an answerer or a listed host is accepted",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox()
    roster={{"Bob-TestRealm",true},{"Cy-TestRealm",true},{"Dee-TestRealm",true},{"Eve-TestRealm",true}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(opened[1].text,GLINE)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"our line has not gone out"); popup.shown=false
    deliver("CHAT_MSG_GUILD",GLINE:sub(4).." x","Me"); deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Other"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"other text or another sender"); popup.shown=false
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me-TestRealm"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"answered before the line went out (r040c G2)"); popup.shown=false
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    inviteFrom("Dee"); eq(#accepts,0,"a guildmate who neither answered nor is a listed host"); popup.shown=false
    -- a claim for someone else, or a busy heard, is no answer
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Someone Else","GUILD","Cy"); deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|-","GUILD","Eve"); drain()
    inviteFrom("Cy"); inviteFrom("Eve"); eq(#accepts,0,"claim for another, busy heard"); popup.shown=false
    inviteFrom("Bob"); eq(#accepts,1,"answered heard|h")
    -- a LayerSwap claim naming us, and a listed Bulo host on that layer
    for _,who in ipairs({"Cy","Eve"}) do
        N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{who.."-TestRealm",true}}
        r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
        deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
        if who=="Cy" then deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy")
        else deliver("CHAT_MSG_ADDON","LFSw","L 9500|100|h","GUILD","Eve") end; drain()
        inviteFrom(who); eq(#accepts,1,who)
    end
end)
test("0.4 T8 B1: a request whose line cannot be built leaves nothing armed",function()
    local N=loadAddon(); establish(N); local Hp=N.Hop; local inv=N.Invite.new()
    local r=rec(N); local cand={name="Bob",short="bob",addon=true,uid=1.5,source="LayerSwap"}
    local ctx={grouped=false,zone=100,own={zone=100,server="7086"},invite=inv,now=clock,x=.25,y=.75}
    local ok,why=Hp.request(N.Main.hop,r,cand,ctx); no(ok); eq(why,"the request could not be built."); eq(inv.pending,nil); eq(#sent,0)
end)
test("0.4 T8 B2: the hop group ends: tracking stops at once; a later group of the same host is never left",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); yes(N.Main.auto.group)
    grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain(); eq(N.Main.auto.group,nil)
    advance(2); joinParty("Bob"); advance(40); drain(); eq(#leaves,0)
end)
test("0.4 T8: never auto-leave inside an instance; in combat the leave waits for combat to end",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    inInstance=true; advance(31); drain(); eq(#leaves,0); eq(N.Main.auto.group,nil,"tracking stopped"); inInstance=false
    advance(30); drain(); eq(#leaves,0)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("8000")
    combat=true; advance(3.1); drain(); eq(#leaves,0,"in combat"); advance(20); drain(); eq(#leaves,0)
    combat=false; advance(1.1); drain(); eq(#leaves,1,"after combat")
    -- the 30 s failure also waits
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    combat=true; advance(31); drain(); eq(#leaves,0); combat=false; advance(1.1); drain(); eq(#leaves,1); yes(logged("hop failed"))
end)
test("0.4 L2: a finished or expired hop no longer counts as asking for the guild host",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); yes(N.Main.hostOwn().asking)
    advance(121); no(N.Main.hostOwn().asking,"120 s without an invite"); eq(N.Main.hop.pending,nil)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("8000"); advance(3.1); drain(); eq(#leaves,1)
    grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain()
    no(N.Main.hostOwn().asking,"moved and left"); eq(N.Main.hop.pending,nil)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); advance(31); drain(); eq(#leaves,1)
    no(N.Main.hostOwn().asking,"failed"); eq(N.Main.hop.pending,nil)
end)

test("0.4 L1: isMe uses the one name rule; letters refuse a no-break space, zero-width and invalid bytes",function()
    local N=loadAddon(); local M,I=N.Main,N.Invite
    yes(M.isMe("Me")); yes(M.isMe("Me-TestRealm")); yes(M.isMe("me")); no(M.isMe("Me-OtherRealm")); no(M.isMe("Me  ")); no(M.isMe("Mee"))
    numericHome(); yes(M.isMe("Me Self")); yes(M.isMe("Me Self-7102")); no(M.isMe("Me Self-7105")); no(M.isMe("Me  Self")); no(M.isMe("Me"))
    -- letters: UTF-8 letters pass, no-break space, zero-width, soft hyphen, BOM, punctuation and broken bytes do not
    yes(I.name("Zo\195\171 \195\133ngstr\195\182m")); yes(I.name("\208\148\208\176\209\128"))
    for _,bad in ipairs({"First\194\160Last","Fi\226\128\139rst Last","Fi\194\173rst","\239\187\191Bob","Bo\195","\255Bob","Bo\128b",
        "Bob\226\128\168","Bo\194\183b","Bo\195\151b","Bob-Re\194\160alm","Bob-\226\128\139x"}) do eq(I.name(bad),nil,bad) end
end)

-- 1.0 review round 2 (مانع r040b part C): T1
local function sentCount(prefix,kind) local n=0; for _,m in ipairs(sent) do if m.prefix==prefix and (not kind or m.kind==kind) then n=n+1 end end; return n end
test("1.0 T1-1: in combat the minute caps halve too: GUILD 10, public 10, one player 2, all 20",function()
    local N=loadAddon(); local Wr=N.Wire; combat=true
    for i=1,15 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}); advance(4.1) end
    eq(sentCount("LEGW1"),10,"GUILD 10 per minute in combat")
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); combat=true
    for i=1,4 do Wr.send("WEFF1","P|"..i,"WHISPER","Stranger",{net="we",prio="own"}); advance(5) end
    eq(sentCount("WEFF1","WHISPER"),2,"one player 2 per minute in combat")
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); combat=true
    for i=1,15 do Wr.send("WEFF1","P|"..i,"WHISPER","Strang"..abc(i),{net="we",prio="own"}); advance(4.1) end
    eq(sentCount("WEFF1","WHISPER"),10,"public 10 per minute in combat")
    N=loadAddon(); Wr=N.Wire; combat=true
    for i=1,30 do Wr.send(i%2==0 and "LEGW1" or "LayerSwap",i%2==0 and ("R|"..i) or LSX,i%2==0 and "PARTY" or "WHISPER",i%2==0 and nil or "Bob",{prio="own"}); advance(2.05) end
    yes(#sent<=20,"all 20 per minute in combat: "..#sent)
end)
test("1.0 T1-2: a network whisper is public unless the target is a checked online guildmate; opts.scope is not trusted",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("guild"); roster={{"Bob-TestRealm",true},{"Off-TestRealm",false}}
    local ok,why=Wr.send("WEFF1","P|1","WHISPER","Stranger",{net="we",scope="guild"}); no(ok); eq(why,"no consent")
    ok,why=Wr.send("WEFF1","P|1","WHISPER","Off",{net="we"}); no(ok); eq(why,"no consent","an offline guildmate is not checked online")
    ok,why=Wr.send("WEFF1","P|1","WHISPER","Bob",{net="we",scope="public"}); yes(ok,why)
    -- a guildmate does not spend the public budget
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); roster={{"Bob-TestRealm",true}}
    for i=1,6 do Wr.send("WEFF1","P|"..i,"WHISPER","Bob",{net="we",prio="own"}); advance(5) end; eq(sentCount("WEFF1","WHISPER"),6)
end)
test("1.0 T1-3: a clock stepping back counts as just sent; the limits hold",function()
    local N=loadAddon(); local Wr=N.Wire; establish(N)
    for i=1,100 do clock=clock+(i%2==0 and 50 or -50); Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    yes(sentCount("LEGW1")<=6,"an oscillating clock gets no extra budget: "..sentCount("LEGW1"))
    -- the GUILD minute: 20 lines, then the clock steps back 30 s; the window still holds all 20
    N=loadAddon(); Wr=N.Wire
    for i=1,20 do yes(Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}),i); advance(2.05) end
    clock=clock-30; local okg,whyg=Wr.send("LEGW1","R|x","GUILD",nil,{prio="own"}); no(okg); eq(whyg,"throttled")
    N=loadAddon(); Wr=N.Wire; yes(Wr.send("LFSw","Q","GUILD",nil,{prio="click"})); clock=clock-1
    local ok,why=Wr.send("LFSw","Q","GUILD",nil,{prio="click"}); no(ok); eq(why,"throttled")
    yes(Wr.send("LEGW1","F|1","GUILD",nil,{prio="click"})); clock=clock-5; ok,why=Wr.send("LEGW1","F|1","GUILD",nil,{prio="click"}); no(ok); eq(why,"throttled")
    -- invites and party calls too
    N=loadAddon(); Wr=N.Wire; yes(Wr.invite("Cara",clock)); ok,why=Wr.invite("Dana",clock-3); no(ok); eq(why,"throttled")
    -- six invites, then the clock steps back 300 s: the 600 s window still holds all six
    N=loadAddon(); Wr=N.Wire; for i=1,6 do yes(Wr.invite("Guest"..abc(i),clock+11*i)) end
    ok,why=Wr.invite("Guestz",clock+11*7-300); no(ok); eq(why,"throttled")
    yes(Wr.accept(clock)); ok,why=Wr.accept(clock-1); no(ok); eq(why,"throttled")
end)
test("1.0 T1: one player is one key for the per-player limit; the target tables are pruned",function()
    local N=loadAddon(); N.Main.we=nil; local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public")
    for i,name in ipairs({"Stranger","stranger","Stranger-TestRealm","STRANGER","Stranger"}) do Wr.send("WEFF1","P|"..i,"WHISPER",name,{net="we",prio="own"}); advance(3) end
    eq(sentCount("WEFF1"),4,"spellings of one player share the 4 per minute")
    for i=1,30 do Wr.send("WEFF1","P|"..i,"WHISPER","Other"..abc(i),{net="we",prio="own"}); advance(3.1) end
    advance(61); Wr.send("WEFF1","P|x","WHISPER","Last",{net="we",prio="own"})
    local targets,offline=Wr.sizes(); yes(targets<=2,"stale players pruned: "..targets)
    sendResult=12; for i=1,300 do Wr.send("WEFF1","P|"..i,"WHISPER","Gone"..abc(i),{net="we",prio="click"}); advance(3.1) end; sendResult=0
    targets,offline=Wr.sizes(); yes(offline<=256,"offline skips capped: "..offline)
end)

-- 1.0 review round 2: T2
local function t2rec(N,over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
    layer={ns="server",value="8000"},heard=clock,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return N.Record.new(o) end
test("1.0 T2-1: across networks a first-hand copy wins before the name count",function()
    local N=loadAddon(); establish(N); local T,st=N.Store,N.Main.store
    yes(T.report(st,t2rec(N,{rid="1",enemies={{hash="abc"}}}),clock))                              -- first-hand War Effort
    local forged=t2rec(N,{src="hh",kind="fight",via="Carrier",wrapped=true,hops=1,rid="9",enemies={{name="Kora Reed"},{name="Ann Lee"}},layer={ns="unknown"}})
    local ok,why=T.report(st,forged,clock); no(ok); eq(why,"duplicate","a relayed copy with more names does not replace a first-hand row")
    local rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"first")
    -- reverse order: the first-hand copy replaces the relayed one
    N=loadAddon(); establish(N); T,st=N.Store,N.Main.store
    yes(T.report(st,t2rec(N,{src="hh",kind="fight",via="Carrier",wrapped=true,hops=1,rid="9",enemies={{name="Kora Reed"}},layer={ns="unknown"}}),clock))
    yes(T.report(st,t2rec(N,{rid="1",enemies={{hash="abc"}}}),clock)); rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"first")

end)
test("1.0 T2: a War Effort sync answer is not first-hand",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7086|1|"..(server%3600).."|12|1:2","GUILD","Origin"); drain()
    local hand; for _,row in pairs(N.Main.store.reports) do hand=row.record.hand end; eq(hand,"relayed")
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7086|1|"..(server%3600),"GUILD","Origin"); drain()
    for _,row in pairs(N.Main.store.reports) do hand=row.record.hand end; eq(hand,"first","a live C")
end)
test("1.0 T2: a relayed HeadHunter record keeps its observer position and a hop count; the relay codes the origin's time",function()
    local N=loadAddon(); local R=N.Relay
    local hh=t2rec(N,{src="hh",kind="fight",origin="Mira Vale",via="Carrier",route="WHISPER",rid="1800000000",x=.5,y=.2,pos="observer",
        wrapped=true,hops=2,heard=100,layer={ns="unknown"},enemies={{name="Kora Reed",class="MAGE",level=60}},share="public"})
    local back=R.decode(R.encode(hh,100),"Relayer",100); yes(back); eq(back.pos,"observer"); yes(back.hops and back.hops>=1,"a hop count")
    local first=t2rec(N,{src="hh",kind="fight",origin="Mira Vale",via="Mira Vale",route="WHISPER",rid="1800000001",x=.5,y=.2,pos="observer",
        heard=100,layer={ns="unknown"},share="public"})
    back=R.decode(R.encode(first,100),"Relayer",100); eq(back.pos,"observer"); eq(back.hops,1,"one guild hop from a first-hand record")
    -- an explicit origin time is what the relay carries
    local timed=t2rec(N,{heard=100,at=40}); back=R.decode(R.encode(timed,100),"Relayer",100); eq(back.at,40)
end)
test("1.0 T2: a record with no timestamp uses receipt time and says so",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); deliver("CHAT_MSG_ADDON","WEFF1","C|7|100|0.4|0.5|8000|1","GUILD","Scout"); drain()
    local row; for _,v in pairs(N.Main.store.reports) do row=v.record end; yes(row); yes(row.untimed); eq(row.at,row.heard)
    slash("reports"); yes(logged("time of receipt (no timestamp)"))
    -- a stamp in the future half of the hour is no usable stamp either
    N=loadAddon(); establish(N); advance(1); hello("Scout",19)
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0.4|0.5|8000|1|"..((math.floor(server)+100)%3600),"GUILD","Scout"); drain()
    for _,v in pairs(N.Main.store.reports) do row=v.record end; yes(row and row.untimed,"future stamp")
    -- a stamped report is not labelled
    N=loadAddon(); establish(N); advance(1); hello("Scout",19); report(8,8000,"Scout")
    for _,v in pairs(N.Main.store.reports) do row=v.record end; no(row.untimed)
end)

-- 1.0 review round 2: T3
test("1.0 T3-1: a channel we were already in is read but never joined or left by us",function()
    local N=loadAddon(); local D=N.Directory; chanList[1]="HeadHunterSync"; chanMembers.HeadHunterSync={"Peer One"}
    dirReady(N); eq(table.concat(joined,","),"WarEfforttestrealmA","only the channel we did not have"); eq(D.joined("hh"),"HeadHunterSync")
    advance(10); advance(3.1); eq(#D.members("hh"),1,"still read")
    N.Net.setConsent("guild"); eq(table.concat(leftCh,","),"WarEfforttestrealmA","only the channel we added is left")
    eq(chanList[1],"HeadHunterSync"); eq(D.joined("hh"),nil); eq(D.members("hh"),nil)
end)
test("1.0 T3-2: the delayed read rechecks combat, instance and the Channels window; an unreadable count forgets",function()
    local N=loadAddon(); local D=N.Directory; dirReady(N); chanMembers.HeadHunterSync={"Peer One"}
    for _,c in ipairs({"combat","instance","window"}) do
        yes(D.refresh("hh"),c)
        if c=="combat" then combat=true elseif c=="instance" then inInstance=true else ChannelFrame={IsShown=function() return true end} end
        advance(3.1); eq(D.members("hh"),nil,c)
        combat=false; inInstance=false; ChannelFrame=nil
    end
    yes(D.refresh("hh")); advance(3.1); eq(#D.members("hh"),1)
    local was=GetChannelDisplayInfo; GetChannelDisplayInfo=function(i) local n=chanList[i]; if n then return i..". "..n,false,nil,i,nil,true end end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"unreadable count"); GetChannelDisplayInfo=was
end)
test("1.0 T3-2: a join that fails is not marked joined; toggling never stacks timers",function()
    local N=loadAddon(); local D=N.Directory; local real=JoinChannelByName
    JoinChannelByName=function(name) real(name); for i,c in ipairs(chanList) do if c==name then table.remove(chanList,i) end end; return false end
    dirReady(N); eq(D.joined("hh"),nil); eq(D.joined("we"),nil); JoinChannelByName=real
    N=loadAddon(); D=N.Directory; dirReady(N); local base=#timers
    for i=1,50 do N.Net.setSwitch("hh",false); N.Net.setSwitch("hh",true) end
    yes(#timers<=base+4,"timers "..#timers.." from "..base)
    advance(10); advance(3.1); local before=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then before=before+1 end end
    eq(before,1,"one loop for hh after the toggles")
    -- off long enough for its timer to fire unheard, then on again: reading resumes
    N.Net.setSwitch("hh",false); advance(400); N.Net.setSwitch("hh",true); advance(10); advance(3.1)
    local after=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then after=after+1 end end
    eq(after,before+1,"resumed after a timer fired while off")
end)

test("names end to end: a foreign spaced host First Last-7103 on realm 7102: line, hop, whisper, auto-accept",function()
    local N=loadAddon(); BULO=nil; numericHome(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","First Last-7103"); drain()
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"First Last-7103")
    local r=rec(N); local p=N.Main.hopPreview(r); eq(p.label,"Hop via First Last-7103")
    yes(N.Main.hopTo(r,p)); eq(#sent,1); eq(sent[1].target,"First Last-7103"); eq(sent[1].prefix,"LayerSwap")
    -- a local namesake's invite is not the asked host's
    inviteFrom("First Last"); eq(#accepts,0); popup.shown=false
    for _,other in ipairs({"First Last-7105","First Last-7104","First Last-7102","First Lasts-7103","First-7103"}) do
        inviteFrom(other); eq(#accepts,0,other); popup.shown=false end
    inviteFrom("First Last-7103"); eq(#accepts,1); yes(logged("accepted First Last's invite"))
    eq(N.Main.auto.group.short,"first last-7103","the group tracked is the asked host's")
end)

-- a732c39 review (مانع r040b/a7): guild changes
local function hReady(N) establish(N); roster={{"Bob-TestRealm",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); sent={} end
test("a7: leaving the guild makes hosting inactive; a new guild's H waits for that guild's roster",function()
    local N=loadAddon(); hReady(N); yes(N.Main.host.on)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    no(N.Main.host.on,"inactive"); yes(N.Main.host.want,"still saved on"); yes(logged("not in a guild"))
    eq(N.Adapters.roster.at,nil,"roster flag reset")
    -- joining another guild: nothing before that guild's roster
    inGuild=true; guildName="Other Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),0,"no H before the new roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"active on the new roster"); eq(#legwSent("H|"),0,"activation sends nothing")
    advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),1)
    -- announceHost itself refuses while not in a guild
    -- (r040c 1f: through events) out of the guild without the event seen yet: an F gets no H
    inGuild=false; advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),1); inGuild=true
end)
test("a7: leaving the guild drops a scheduled F answer and an owed H",function()
    local N=loadAddon(); hReady(N); advance(61)
    legw("F|1","Cy"); eq(#legwSent("H|"),0)                         -- answer scheduled 1 to 6 s out
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    inGuild=true; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain()
    advance(7); drain(); eq(#legwSent("H|"),0,"the scheduled answer was dropped")
    -- owed H (turned on before any roster), then out of the guild and back: never sent
    N=loadAddon(); establish(N); slash("host on"); yes(N.Main.host.announceOwed)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(N.Main.host.announceOwed,nil)
    inGuild=true; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),0)
    -- a guild update that changes nothing (same guild, still in it) keeps everything, also the first one
    N=loadAddon(); hReady(N); deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on); yes(N.Adapters.roster.at)
    deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on)
    -- (r040c 1f) a guild name unreadable on a guild event is "unknown": inactive until a readable name and its roster
    -- (r040c 21e: a blink in a known guild drops nothing; the next readable roster or event of that guild restores)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); guildName="Test Guild"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- another guild without leaving in between: a change
    guildName="Third Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); eq(N.Adapters.roster.at,nil)
end)

-- 1.0 lane A1: own sightings out (O on LEGW1; C+E on WEFF1 for two or more, where a War Effort reader was heard)
local function foe(N,i,over) local e={key="Player-1-9"..i,name=({"Kora Reed","Ann Lee","Bo Dyl","Cy Fen","Di Gar","Ed Hol"})[i],realm="Test Realm",
    class="MAGE",level=60,at=clock,faction="opposite",source="own target",x=.25,y=.75}; for k,v in pairs(over or {}) do e[k]=v end
    return N.Store.observe(N.Main.store,e,clock) end
local function weSent(t) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and (not t or m.text:sub(1,1)==t) then out[#out+1]=m end end; return out end
local function oLines() return legwSent("O|") end
assert(loadfile("test/crowd.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,establish=establish,
    time=function(v) if v then clock=v end; return clock end,sent=function() return sent end,
    map=function(v) map=v end,guild=function(v,name) inGuild=v; if name then guildName=name end end,
    result=function(v) sendResult=v end,deliver=deliver,drain=drain,netOn=netOn,hello=hello,weSent=weSent})
test("1.0 A1: WeOut encodes C and E as War Effort does; they decode back to the same values",function()
    local N=loadAddon(); local W,P=N.WeOut,N.Protocol
    eq(W.cluster(42,100,.4,.5,7086,4,100),"C|42|100|0.400|0.500|7086|4|100")
    local vec="C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"            -- study vector (spread, guild: not sent by us)
    eq(vec:sub(1,#W.cluster(42,100,.4,.5,7086,4,100)),W.cluster(42,100,.4,.5,7086,4,100))
    local e=W.enemies(42,{{hash="Zzm",class="MAGE",level=60},{hash="AbC",class="WARRIOR",level=-1},{hash="def"},{hash="xyz",class="ROGUE",level=59}},100)
    eq(#e,1); eq(e[1],"E|42|1|1|Zzm:H:60,AbC:A:-1,def:?:?,xyz:D:59|100")
    local c=P.decode(W.cluster(65535,1429,1,0,0,200,3599)); eq(c.rid,65535); eq(c.map,1429); eq(c.x,1); eq(c.y,0); eq(c.layer,0); eq(c.count,200); eq(c.stamp,3599)
    local many={}; for i=1,40 do many[i]={hash=string.format("%03d",i),class="PRIEST",level=i} end
    local parts=W.enemies(7,many,5); eq(#parts,3); for i,p in ipairs(parts) do local d=P.decode(p); yes(d,p); eq(d.part,i); eq(d.total,3); yes(#p<=255) end
    eq(#P.decode(parts[1]).enemies,18); eq(P.decode(parts[3]).enemies[4].level,40)
    eq(W.cluster(1,100,1.7,-3,7086,999,0),"C|1|100|1.000|0.000|7086|200|0","clamped")
end)
test("1.0 A1: an O line to the guild: 3 s settle, one per 15 s, the same enemy again only after 60 s",function()
    local N=loadAddon(); establish(N); local M=N.Main
    foe(N,1); M.shareTick(); eq(#oLines(),0,"settling"); advance(3); M.shareTick(); eq(#oLines(),1)
    local o=oLines()[1].text; yes(o:find("^O|1|1|100|0.250|0.750|7086|%d+|1|"),o)
    advance(1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),1,"inside 15 s")
    advance(12); M.shareTick(); eq(#oLines(),2,"after 15 s, the new enemy")
    advance(16); foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),2,"both shared within 60 s")
    advance(41); foe(N,1); advance(3); M.shareTick(); eq(#oLines(),3,"60 s later")
    -- same faction, unknown faction, other zone: never shared
    N=loadAddon(); establish(N); foe(N,1,{faction="same"}); foe(N,2,{faction="unknown"}); advance(3); N.Main.shareTick(); advance(3); N.Main.shareTick(); eq(#oLines(),0)
    -- not in a guild: no O line
    N=loadAddon(); establish(N); inGuild=false; foe(N,1); advance(3); N.Main.shareTick(); eq(#oLines(),0); inGuild=true
end)
test("1.0 A1: a guildmate's O line is a first-hand row with names; our own is not stored",function()
    local N=loadAddon(); establish(N); local R=N.Relay
    local line=R.ownLine({rid=7,zone=100,x=.25,y=.75,layer="7086",age=2,count=3,enemies={{name="Kora Reed",class="MAGE",level=60},{name="Ann Lee"}}})
    legw(line,"Scout"); local rows=N.Store.rows(N.Main.store,clock,"reported"); yes(#rows>=1)
    local r=rows[1].record; eq(r.src,"le"); eq(r.hand,"first"); eq(r.origin,"Scout"); eq(r.enemies[1].name,"Kora Reed"); eq(r.count,3); eq(r.pos,"observer")
    eq(rows[1].positionKind,"observer's position","the O line carries where the sender stood")
    eq(r.layer.ns,"server"); eq(r.layer.value,"7086"); eq(r.at,clock-2)
    local n=N.Safe.count(N.Main.store.reports); legw(line,"Me"); eq(N.Safe.count(N.Main.store.reports),n,"own echo")
    local five={}; for i=1,5 do five[i]="4b6f7261"..string.format("%02x",96+i)..":MAGE:60" end
    for i,bad in ipairs({"O|2|8|100|0.250|0.750|7086|2|3|","O|1|x|100|0.250|0.750|7086|2|3|","O|1|9|100|2.0|0.750|7086|2|3|",
        "O|1|10|100|0.250|0.750|7086|2|3|zz:MAGE:60","O|1|11|100|0.250|0.750|7086|2|5|"..table.concat(five,",")}) do
        legw(bad,"Scout"..abc(i)); end
    eq(N.Safe.count(N.Main.store.reports),n)
    -- Wire carries only the O grammar
    local Wr=N.Wire; yes(Wr.send("LEGW1",line,"GUILD",nil,{prio="own"}))
    for _,bad in ipairs({"O|1|7|100|0.250|0.750|7086|2|3|x y","O|2","O|1|7|100|a|b|7086|2|3|"}) do local ok,why=Wr.send("LEGW1",bad,"GUILD",nil,{prio="own"}); no(ok,bad); eq(why,"bad text") end
end)
test("1.0 A1: C and E for two or more enemies, only where a War Effort reader was heard; the id rises and is saved",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); local M=N.Main
    foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),1); eq(#weSent(),0,"no War Effort reader heard")
    hello("Wes",19); advance(16); foe(N,3); foe(N,4); advance(3); M.shareTick()
    -- (foes 1 and 2 are 19 s old by now: the report is foes 3 and 4)
    local c,e=weSent("C"),weSent("E"); eq(#c,1); eq(#e,1); eq(c[1].kind,"GUILD"); yes(c[1].text:find("^C|2|100|0.250|0.750|7086|2|%d+$"),c[1].text)
    local d=N.Protocol.decode(e[1].text); eq(#d.enemies,2); eq(d.enemies[1].hash,N.Hash.player("Bo Dyl","Test Realm")); eq(d.enemies[1].class,"MAGE"); eq(d.enemies[1].level,60)
    eq(c[1].text:match("|(%d+)$"),tostring(math.floor(server)%3600),"the stamp is server time % 3600")
    eq(LayerEnemiesDB.weReportId,2)
    -- a C from a War Effort user is no hello: it does not open a route
    N.Main.weHeard={}; report(1,9000,"Wes"); advance(16); foe(N,5); foe(N,6); advance(3); M.shareTick(); eq(#oLines(),3); eq(#weSent("C"),1,"no reader")
    hello("Wes",19)
    -- one enemy alone: an O line, no C
    advance(61); foe(N,5); advance(3); M.shareTick(); eq(#weSent("C"),1); eq(#oLines(),4)
    -- the reader's 600 s run out
    advance(600); foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#weSent("C"),1)
    -- saved across a reload, and 65535 wraps to 1
    LayerEnemiesDB.weReportId=300; local saved=LayerEnemiesDB
    N=loadAddon(); LayerEnemiesDB=saved; reload(N); netOn(N,"we"); establish(N); hello("Wes",19); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    yes(weSent("C")[1].text:find("^C|301|"),weSent("C")[1].text)
    for i,v in ipairs({0,65536,1.5,"7",secret}) do LayerEnemiesDB.weReportId=v; reload(N); eq(LayerEnemiesDB.weReportId,nil,"bad saved id "..i) end
    LayerEnemiesDB.weReportId=65535; saved=LayerEnemiesDB
    N=loadAddon(); LayerEnemiesDB=saved; reload(N); netOn(N,"we"); establish(N); hello("Wes",19); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    yes(weSent("C")[1].text:find("^C|1|"),weSent("C")[1].text); eq(LayerEnemiesDB.weReportId,1)
end)
test("1.0 A1: no C or E with the network off, War Effort loaded, in an instance, without a position; groups get them too",function()
    local function run(setup) local N=loadAddon(); netOn(N,"we"); establish(N); hello("Wes",19); setup(N); foe(N,1); foe(N,2); advance(3); N.Main.shareTick(); return N end
    run(function(N) N.Net.SHIP.we=false end); eq(#weSent(),0,"ship constant")
    run(function(N) N.Net.setSwitch("we",false) end); eq(#weSent(),0,"switch")
    run(function() loaded.WarEffortScout=true end); eq(#weSent(),0,"War Effort loaded"); loaded.WarEffortScout=nil
    local N=run(function() inInstance=true end); eq(#weSent(),0,"instance"); inInstance=false
    local was=C_Map.GetPlayerMapPosition; N=run(function() C_Map.GetPlayerMapPosition=function() return nil end end); C_Map.GetPlayerMapPosition=was
    eq(#weSent(),0,"no position"); eq(#oLines(),1,"the O line goes without coordinates")
    -- a War Effort reader in our party: the party gets C+E too
    N=loadAddon(); netOn(N,"we"); establish(N); grouped=true; hello("Pam",19,"PARTY"); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    local kinds={}; for _,m in ipairs(weSent("C")) do kinds[#kinds+1]=m.kind end; eq(table.concat(kinds,","),"PARTY")
end)

-- مانع on e4f27f0 (r040b/e4): one player, one key; through the real CHAT_MSG_ADDON path
test("e4 M1: an own-realm suffixed origin heard first-hand and through the guild relay is one row, in both orders",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout-TestRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1)
    local first=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(first.src,"we"); eq(first.origin,"Scout-TestRealm")
    local copy=N.Relay.encode(first,clock); yes(copy)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain()
    eq(N.Safe.count(N.Main.store.reports),1,"direct then relay"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    eq(N.Main.relay.pending["we:scout:1"],nil,"our pending relay stood down")
    -- relay first, then the first-hand report: the first-hand one replaces the copy
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"guild")
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout-TestRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1,"relay then direct"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    -- the bare spelling is the same player too
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    -- another realm is another player: two rows
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); hello("Scout-OtherRealm",19,"PARTY"); report(1,8000,"Scout-OtherRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),2)
end)
test("e4 S1: the folded key everywhere a player is keyed (peers, report order, rates, relay ids, reporters)",function()
    -- Peers: a hello as "Scout-TestRealm" vouches for "Scout"
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    local r=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(r.layer.ns,"server"); eq(r.layer.value,"8000")
    -- report order: the same id from the other spelling is not a new report; one reporter
    report(1,8000,"Scout-TestRealm",nil,"PARTY"); eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    report(2,8000,"Scout-TestRealm",nil,"PARTY"); eq(#N.Store.reporters(N.Main.store,clock),1,"two reports, one reporter")
    -- receive limits share one slot per player
    local st=N.Reports.new(); for i=1,6 do yes(N.Reports.allow(st,i%2==0 and "Scout" or "Scout-TestRealm",false,0)) end
    no(N.Reports.allow(st,"SCOUT",false,1)); yes(N.Reports.allow(st,"Scout-OtherRealm",false,1))
    st=N.Relay.new(); for i=1,12 do yes(N.Relay.allow(st,i%2==0 and "Bob" or "Bob-TestRealm",0)) end; no(N.Relay.allow(st,"bob",1))
    st=N.HeadHunter.new(); for i=1,6 do yes(N.HeadHunter.allow(st,i%2==0 and "Fighter" or "Fighter-TestRealm",0)) end; no(N.HeadHunter.allow(st,"Fighter",1))
    -- relay ids
    eq(N.Relay.key({src="we",origin="Scout-TestRealm",okey="scout",rid="1"}),"we:scout:1")
    eq(N.Peers.key("Scout-TestRealm"),N.Peers.key("scout")); eq(N.Peers.key("Bad|Name"),nil)
end)
test("e4 S3: decoders through CHAT_MSG_ADDON with spaced and suffixed names (War Effort, HeadHunter, guild relay)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    -- HeadHunter whisper from an own-realm suffixed spaced name, then the bare one: one sighting, one origin key
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","First Last-TestRealm"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].record.okey,"first last"); eq(rows[1].record.origin,"First Last-TestRealm")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","First Last"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1,"the same report from the same player")
    -- a foreign spaced name is its own reporter; malformed names are dropped
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Ann Lee;2s;"..b36(server)..";dw;6y","WHISPER","First Last-7105"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"reported"),2)
    for i,bad in ipairs({"First  Last","One Two Three","First Last-","Bad|Name"}) do
        deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Bo Dyl;2s;"..b36(server)..";dw;6y","WHISPER",bad); drain() end
    eq(#N.Store.rows(N.Main.store,clock,"reported"),2,"malformed HeadHunter senders")
    -- War Effort on GUILD from a spaced guildmate, and from malformed names
    N=loadAddon(); establish(N); advance(1)
    hello("First Last",19); report(5,8000,"First Last"); local w=N.Store.rows(N.Main.store,clock,"reported"); eq(#w,1); eq(w[1].record.okey,"first last")
    for i,bad in ipairs({"First  Last"," First Last","One Two Three"}) do report(5+i,8000,bad) end
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1,"malformed War Effort senders")
    -- a guild relay from a suffixed guildmate naming a spaced foreign origin
    local rec=weRec(N,{origin="Cy Fen-7105",via="Cy Fen-7105",heard=clock,age=0}); yes(rec)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Bob-TestRealm"); drain()
    local g; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.src=="guild" then g=row.record end end
    yes(g); eq(g.origin,"Cy Fen-7105"); eq(g.okey,"cy fen-7105"); eq(g.hand,"relayed")
    -- our own suffixed name relayed back is our echo
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me-TestRealm",via="Me-TestRealm",rid="9",heard=clock,age=0}),clock),"GUILD","Bob"); drain()
    eq(N.Main.lastDrop,"relay origin")
end)

test("e4 S1b: one key in the remembered hosts and the offline skip ('Gone' and 'Gone-TestRealm' are one player)",function()
    local N=loadAddon(); local Hs=N.Hosts; local st=Hs.new()
    yes(Hs.heard(st,"First Last-TestRealm",{kind="heard",layer="8000-1",zone=100,hosting=true},10))
    yes(Hs.heard(st,"First Last",{kind="heard",layer="8001-1",zone=100,hosting=true},11))
    eq(N.Safe.count(st.heard),1,"one entry"); local k,e=next(st.heard); eq(e.layer,"8001-1"); eq(k,"First Last","the latest spelling is kept to whisper")
    Hs.heard(st,"FIRST LAST-TestRealm",{kind="heard",hosting=false},12); eq(next(st.heard),nil,"not hosting removes it under any spelling")
    yes(Hs.heard(st,"First Last-7105",{kind="heard",layer="8000-1",zone=100,hosting=true},13)); yes(Hs.heard(st,"First Last",{kind="heard",layer="8000-1",zone=100,hosting=true},13))
    eq(N.Safe.count(st.heard),2,"another realm is another host")
    for _,bad in ipairs({"Bad|Name","First  Last","One Two Three"}) do no(Hs.heard(st,bad,{kind="heard",layer="8000-1",zone=100,hosting=true},14),bad) end
    eq(N.Safe.count(st.heard),2)
    -- the friendly list shows the spelling heard
    N=loadAddon(); establish(N); N.Hosts.heard(N.Main.heard,"Cy Fen-TestRealm",{kind="heard",layer="8000-1",zone=100,hosting=true},N.Adapters.wall())
    local names={}; for _,c in ipairs((N.Main.candidates())) do names[#names+1]=c.name end; yes(table.concat(names,","):find("Cy Fen-TestRealm",1,true),table.concat(names,","))
    -- Wire: an offline result under one spelling skips the other
    N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    sendResult=12; local ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone-TestRealm",{net="hh",scope="public"}); no(ok); eq(why,"offline"); sendResult=0
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","gone",{net="hh",scope="public"}); no(ok); eq(why,"offline")
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone-OtherRealm",{net="hh",scope="public"}); yes(ok,why)
end)

-- مانع's closing round for B and C (r040c)
test("r040c G1: a listed Bulo or LayerSwap row counts as a host only with its host flag",function()
    for _,c in ipairs({{"LFSw","L 9500|100|-"},{"LFSw","L 9500|100|h"}}) do
        local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Eve-TestRealm",true}}
        local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
        deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
        deliver("CHAT_MSG_ADDON",c[1],c[2],"GUILD","Eve"); drain()
        inviteFrom("Eve"); eq(#accepts,c[2]:sub(-1)=="h" and 1 or 0,c[2])
    end
    -- a LayerSwap book row with host=false
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Eve-TestRealm",true}}
    -- (on another layer than the hop's, so the hop is the guild ask and not a direct request to Eve)
    LayerSwapDB={book={Eve={layer="9600-1",zone=100,at=N.Adapters.wall(),host=false}}}; loaded.LayerSwap=true
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(opened[#opened].text,GLINE)
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain(); inviteFrom("Eve"); eq(#accepts,0,"LayerSwap host=false")
    popup.shown=false; LayerSwapDB.book.Eve.host=true; advance(11); inviteFrom("Eve"); eq(#accepts,1,"LayerSwap host=true")
    LayerSwapDB=nil; loaded.LayerSwap=nil
end)
test("r040c G2/G3: an answer before our guild line goes out does not count; the window runs from the send",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Cy-TestRealm",true},{"Bob-TestRealm",true}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    advance(100); deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
    inviteFrom("Cy"); inviteFrom("Bob"); eq(#accepts,0,"answers seen before the send")
    -- 100 s after the draft, 30 s after the send: still in the window
    advance(30); deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); drain(); inviteFrom("Cy"); eq(#accepts,1,"30 s after a late send")
    -- and an answer more than 120 s after the send is late
    N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Cy-TestRealm",true}}
    r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain(); advance(121)
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); drain(); inviteFrom("Cy"); eq(#accepts,0,"after the window")
end)
test("r040c: an AcceptGroup that throws spends the ask",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    local was=AcceptGroup; AcceptGroup=function() error("blocked") end
    inviteFrom("Bob"); eq(N.Main.invite.pending,nil,"the ask is spent"); eq(N.Main.auto.group,nil); AcceptGroup=was
    advance(11); popup.shown=false; inviteFrom("Bob"); eq(#accepts,0,"no second try")
end)
test("r040c D1: no join while the channel display list is unreadable or empty",function()
    local N=loadAddon(); local D=N.Directory; chanList={}
    dirReady(N); eq(#joined,0,"empty list (still loading)")
    local was=GetNumDisplayChannels; GetNumDisplayChannels=function() return nil end; chanList={"General"}
    D.sync(); eq(#joined,0,"unreadable count"); GetNumDisplayChannels=was
    D.sync(); eq(#joined,2,"filled: joins")
end)
test("r040c D2: ours only by our own join notice; a hand leave and rejoin is the player's; a nil or empty return is no join",function()
    -- nil and "" returns: not joined
    for _,ret in ipairs({false,""}) do
        local N=loadAddon(); local D=N.Directory; joinReturn=ret; joinNotice=false; dirReady(N); eq(D.joined("hh"),nil,tostring(ret)); joinReturn=nil; joinNotice=true
    end
    local N=loadAddon(); local D=N.Directory; local real=JoinChannelByName
    JoinChannelByName=function(name) real(name); return nil end; dirReady(N); eq(D.joined("hh"),nil,"nil return"); JoinChannelByName=real
    -- joined but no notice of ours: we read it and never leave it
    N=loadAddon(); D=N.Directory; joinNotice=false; dirReady(N); joinNotice=true; yes(D.joined("hh"))
    N.Net.setSwitch("hh",false); eq(#leftCh,0,"never ours: not left")
    -- the notice arriving a moment later counts
    N=loadAddon(); D=N.Directory; joinNotice=false; dirReady(N); joinNotice=true
    for i,c in ipairs(chanList) do if c=="HeadHunterSync" then deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_CHANGED","","",i..". "..c,"",0,0,i,c) end end
    N.Net.setSwitch("hh",false); eq(table.concat(leftCh,","),"HeadHunterSync")
    -- ours, then the player leaves by hand: not rejoined this session; rejoined by hand: theirs, never left by us
    N=loadAddon(); D=N.Directory; dirReady(N); eq(#joined,2)
    for i,c in ipairs(chanList) do if c=="HeadHunterSync" then table.remove(chanList,i); deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_LEFT","","",i..". "..c,"",0,0,i,c) end end
    eq(D.joined("hh"),nil); D.sync(); advance(5); eq(#joined,2,"not rejoined after a hand leave")
    chanList[#chanList+1]="HeadHunterSync"; deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_JOINED","","",#chanList..". HeadHunterSync","",0,0,#chanList,"HeadHunterSync")
    D.sync(); eq(D.joined("hh"),"HeadHunterSync","read again"); eq(#joined,2)
    N.Net.setSwitch("hh",false); eq(#leftCh,0,"the player's channel is never left by us")
    -- a notice for another channel, or one we did not ask for, makes nothing ours
    N=loadAddon(); D=N.Directory; chanList={"General","HeadHunterSync"}
    deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_JOINED","","","2. HeadHunterSync","",0,0,2,"HeadHunterSync"); dirReady(N)
    N.Net.setSwitch("hh",false); eq(#leftCh,0)
end)

test("cc: Directory lists nobody while our own name or home realm is unreadable; one entry per player",function()
    local N=loadAddon(); local D=N.Directory; numericHome(); dirReady(N)
    chanMembers.HeadHunterSync={"Peer One","Peer One-7102","peer one","Me Self-7102","Me Self","Peer Two-7105","Peer Two"}
    advance(10); advance(3.1); local m=D.members("hh")
    eq(#m,3,table.concat(m,",")); eq(D.count("hh"),3); eq(m[1],"Peer One"); eq(m[2],"Peer Two-7105"); eq(m[3],"Peer Two")
    -- home realm unreadable: our "-7102" entries cannot be told from peers, so no list at all
    GetRealmName=function() return nil end; GetNormalizedRealmName=function() return nil end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"home realm unreadable"); eq(D.count("hh"),nil)
    numericHome(); yes(D.refresh("hh")); advance(3.1); eq(#D.members("hh"),3)
    -- our own name unreadable
    local was=UnitName; UnitName=function(u) if u=="player" then return nil end; return was(u) end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"own name unreadable"); UnitName=was
end)

-- مانع on 1f7cd69 (r040c/1f): guild changes through events, in every order
local function hostF() legw("F|1","Cy"); advance(7); drain(); return #legwSent("H|") end
test("1f M2: leave, a roster while guildless, join: no H until the new guild's roster",function()
    local N=loadAddon(); hReady(N); advance(61)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(N.Adapters.roster.at,nil,"a guildless roster is no roster"); no(N.Main.host.on)
    local calls=rosterCalls; advance(16)
    inGuild=true; guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    eq(rosterCalls,calls+1,"the new guild's roster is asked for"); no(N.Main.host.on); advance(61); eq(hostF(),0,"no H before B's roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); eq(hostF(),1)
    -- a guildless login: a roster then joining and turning hosting on sends no H before B's roster
    N=loadAddon(); inGuild=false; establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(N.Adapters.roster.at,nil)
    inGuild=true; guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); slash("host on"); eq(#legwSent("H|"),0)
    advance(61); eq(hostF(),0); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"the owed H on B's roster")
end)
test("1f: joining B with no leave seen is a switch, by the guild event or by a roster alone",function()
    local N=loadAddon(); hReady(N); advance(61); guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    no(N.Main.host.on); eq(N.Adapters.roster.at,nil); eq(hostF(),0)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- the event missed: a roster arriving under B's name is noticed as the switch (and not counted as B's roster)
    N=loadAddon(); hReady(N); advance(61); local calls=rosterCalls; advance(16); guildName="Guild B"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on,"switch noticed on the roster"); eq(rosterCalls,calls+1,"a fresh roster asked for")
    eq(hostF(),0); deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); eq(hostF(),1)
end)
test("1f: B's roster before the guild event: the switch asks for a roster; the late event changes nothing more",function()
    local N=loadAddon(); hReady(N); advance(61); local calls=rosterCalls; advance(16)
    guildName="Guild B"; deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(rosterCalls,calls+1); no(N.Main.host.on)
    deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(rosterCalls,calls+1,"no second request inside 15 s")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"the asked-for roster restores hosting")
end)
test("1f: an unreadable guild name in a switch keeps nothing of the old guild",function()
    local N=loadAddon(); hReady(N); advance(61)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    inGuild=true; guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); deliver("GUILD_ROSTER_UPDATE",true); drain()
    no(N.Main.host.on,"name unknown"); eq(hostF(),0)
    guildName="Guild B"; deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on,"first readable name: its roster is asked for")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- at login an unreadable name: hosting does not act until the name is readable (r040c 21e)
    N=loadAddon(); hReady(N); guildName=nil; N.Main.started=false; N.Main.start(); drain(); N.Main.guildSeen=nil
    no(N.Main.host.on); yes(N.Main.host.want); yes(logged("ON but inactive: your guild's name is not readable right now")); guildName="Test Guild"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- known guild, then a roster while its name blinks: not counted, hosting inactive (r040c 21e), nothing dropped
    N=loadAddon(); hReady(N); local at=N.Adapters.roster.at; advance(5); guildName=nil; deliver("GUILD_ROSTER_UPDATE",true); drain()
    eq(N.Adapters.roster.at,at,"not counted"); no(N.Main.host.on,"inactive"); yes(N.Main.host.want); guildName="Test Guild"
    guildName="Test Guild"; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)
test("1f: a request held for the roster is dropped by a guild switch, even if the requester is in the new guild",function()
    local N=loadAddon(); establish(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); sent={}
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); yes(N.Main.host.held)
    guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(N.Main.host.held,nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); eq(#invites,0,"the old guild's request is not served")
    -- same with the switch noticed on the roster itself
    N=loadAddon(); establish(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on")
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Bob"); guildName="Guild B"; advance(1); deliver("GUILD_ROSTER_UPDATE",true); drain()
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,0)
end)

-- مانع on ded1bee (r040c/e4c), through events
local function seeFoe(name,guid) units.target=player(name,"Horde",guid); deliver("PLAYER_TARGET_CHANGED"); drain() end
test("e4c: an enemy re-seen every second is reported 3 s after its first sighting",function()
    local N=loadAddon(); establish(N); advance(1)
    for i=1,9 do seeFoe("Kora Reed","Player-1-901"); advance(1) end
    eq(#oLines(),1,"reported while still being seen")
    -- an enemy that left view before settling starts again on its next sighting
    -- (r040c 21e: Share reads the row's own-sighting fields, ownAt and ownSource)
    local Sh=N.Share; local st=Sh.new(); local e={key="k",faction="opposite",zone=100,source="own target",at=0,ownSource="own target",ownAt=0}
    eq(Sh.pick(st,{k=e},1,100),nil); eq(Sh.pick(st,{k=e},46,100),nil,"gone")
    e.at=60; e.ownAt=60; eq(Sh.pick(st,{k=e},60,100),nil,"settles again"); yes(Sh.pick(st,{k=e},63,100)); yes(oLines()[1].text:find("^O|1|%d+|100|"),oLines()[1].text)
end)
test("e4c: only our own unit sightings are shared, never a Bulo copy (also not one refreshing our own row)",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); establish(N); advance(1)
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10); eq(#oLines(),1)
    -- 61 s later Bulo reports the same player (keeps our classification): not ours to share
    advance(61); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
    yes(N.Main.store.localSeen["Player-1-901"].source:find("^Bulo")); advance(10); eq(#oLines(),1,"Bulo copy not shared")
    -- a Bulo-only player, and reports received from guildmates or War Effort, are never shared as ours
    b.Radar.seen["Player-2-5"]={at=clock,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
    hello("Wes",19); report(3,8000,"Wes"); legw(N.Relay.ownLine({rid=9,zone=100,x=.2,y=.2,layer="7086",age=0,count=2,enemies={{name="Ann Lee"}}}),"Scout")
    advance(30); eq(#oLines(),1)
end)
test("e4c: an unknown or just-changed layer is sent as unknown, never a guessed key",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("SHARD_TRANSFER"); drain(); advance(1); eq(N.Main.store.bulo,nil,"layer not known again yet")
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10)
    local o=oLines()[1]; yes(o,"sent anyway"); yes(o.text:find("^O|1|%d+|100|0.250|0.750||"),o.text)
    -- the receiver shows it as layer unknown
    local M=loadAddon(); establish(M); legw(o.text,"Scout"); local rows=M.Store.rows(M.Main.store,clock,"reported")
    eq(rows[1].record.layer.ns,"unknown")
    -- mixed servers sharing the zone (ambiguous): unknown too
    N=loadAddon(); establish(N); advance(1); N.Main.store.ambiguous=function() return true end
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10); yes(oLines()[1].text:find("^O|1|%d+|100|0.250|0.750||"),oLines()[1].text)
end)

-- 1.0 lane A2: War Effort hello, Q, guild Q answers, Y answers from our own reports, K (off) to J
local function weGuild(t) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="GUILD" and (not t or m.text:sub(1,#t)==t) then out[#out+1]=m end end; return out end
local function weTo(who) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="WHISPER" and m.target==who then out[#out+1]=m end end; return out end
local function we(text,kind,from) deliver("CHAT_MSG_ADDON","WEFF1",text,kind or "GUILD",from or "Wes"); drain() end
local function weReady(N) netOn(N,"we"); units.player={name="Me",class="MAGE",level=60}; establish(N) end
local function steps(n) for _=1,n do advance(1) end end   -- (advance jumps the clock before due timers run)
test("1.0 A2: WeOut builds H, Q, K and sync-marked C; our decoder reads them back",function()
    local N=loadAddon(); local W,P=N.WeOut,N.Protocol
    local h=W.hello({map=100,layer=7086,class="MAGE",level=60,public=true,stamp=720100})
    eq(h,"H|"..W.VERSION.."|100|7086|1|19|0|0|"..(720100%3600).."||H|60|1")
    local d=P.decode(h); eq(d.type,"H"); eq(d.minor,19); eq(d.layer,7086); eq(d.map,100); eq(d.stamp,720100%3600)
    eq(W.hello({map=100,layer=nil,public=false,ambiguous=true,stamp=5}),"H|"..W.VERSION.."|100|0|1|19|0|0|5||-|0|0|0|1")
    eq(W.query(),"Q"); eq(W.joinOff(77,3605),"K|77|2|5")
    local c=W.cluster(9,100,.25,.75,7086,2,100,2,3); eq(c,"C|9|100|0.250|0.750|7086|2|100||2:3")
    local dc=P.decode(c); yes(dc.sync); eq(dc.rid,9)
    eq(P.decode("Q").type,"Q"); eq(P.decode("Q|x").type,"Q")
    local y=P.decode("Y|1||a:600"); eq(y.type,"Y"); eq(y.continent,1); eq(y.maxAge,600)
    eq(P.decode("Y|1").maxAge,900); eq(P.decode("Y|1||a:5").maxAge,60); eq(P.decode("Y|1||a:99999").maxAge,900); eq(P.decode("Y|x"),nil)
    local j=P.decode("J|5|100|7086|0.5|0.5|12"); eq(j.type,"J"); eq(j.id,5); eq(P.decode("J|0|100|7086|0.5|0.5"),nil); eq(P.decode("J|5|100|7086|0.5"),nil)
    -- Wire: on WHISPER only a sync-marked C, an E, or a K saying "off"
    local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public")
    yes(Wr.send("WEFF1",c,"WHISPER","Bob",{net="we"})); yes(Wr.send("WEFF1","K|77|2|5","WHISPER","Bob",{net="we"}))
    for _,bad in ipairs({"C|9|100|0.250|0.750|7086|2|100","K|77|1|5","K|77|2|5|x","H|1","Q","C|9|100|0.250|0.750|7086|2|100||4:3"}) do
        local ok,why=Wr.send("WEFF1",bad,"WHISPER","Bob",{net="we"}); no(ok,bad); eq(why,"bad text") end
    local ok,why=Wr.send("WEFF1","Q|1","GUILD",nil,{net="we"}); no(ok); eq(why,"bad text","Q is bare")
end)
test("1.0 A2: hello at login and every 180 s to the guild; not in an instance; an identical one not within 30 s",function()
    local N=loadAddon(); weReady(N); advance(12)
    local h=weGuild("H|"); eq(#h,1,"login hello"); local d=N.Protocol.decode(h[1].text); eq(d.minor,19); eq(d.layer,7086); eq(d.map,100)
    advance(170); eq(#weGuild("H|"),1); advance(25); eq(#weGuild("H|"),2,"about 180 s later")
    -- a guild Q is answered with a hello at once (not again within 10 s); the timer then skips an identical one within 30 s
    -- (the next timer hello is due 180 to 190 s after the last one)
    local due=N.Main.we.helloDue; sent={}; steps(math.floor(due-clock)-5)
    we("Q"); eq(#weGuild("H|"),1,"Q answered"); we("Q","GUILD","Wesb"); eq(#weGuild("H|"),1,"one answer per 10 s")
    steps(10); eq(#weGuild("H|"),1,"the timer skips an identical hello within 30 s")
    steps(200); eq(#weGuild("H|"),2,"and sends the next")
    -- a Q on PARTY or from ourselves is not answered
    sent={}; grouped=true; we("Q","PARTY","Pam"); we("Q","GUILD","Me"); eq(#weGuild("H|"),0); grouped=false
    -- no hello in an instance; it goes once outside again
    N=loadAddon(); weReady(N); inInstance=true; advance(30); eq(#weGuild("H|"),0); inInstance=false; advance(6); eq(#weGuild("H|"),1)
    -- shipped off, switched off, War Effort loaded, not in a guild: nothing
    for _,c in ipairs({"ship","switch","loaded","guild"}) do
        N=loadAddon(); netOn(N,"we"); establish(N)
        if c=="ship" then N.Net.SHIP.we=false elseif c=="switch" then N.Net.setSwitch("we",false) elseif c=="loaded" then loaded.WarEffortScout=true else inGuild=false end
        advance(200); eq(#weGuild(),0,c); loaded.WarEffortScout=nil; inGuild=true
    end
end)
test("1.0 A2: a group with players outside the guild gets a hello too",function()
    local N=loadAddon(); weReady(N); roster={{"Bob-TestRealm",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    grouped=true; units.party1={name="Bob"}; advance(12)
    local function party() local n=0; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="PARTY" then n=n+1 end end; return n end
    eq(party(),0,"only guildmates in the group"); units.party1={name="Stranger"}; steps(200); eq(party(),1)
end)
test("1.0 A2: Q once at login, to the guild",function()
    local N=loadAddon(); weReady(N); advance(16); eq(#weGuild("Q"),1); eq(weGuild("Q")[1].text,"Q"); advance(1200); eq(#weGuild("Q"),1)
    N=loadAddon(); inGuild=false; weReady(N); advance(30); eq(#weGuild("Q"),0)
end)
test("1.0 A2: a guild Y is answered by whisper from our own last three reports, slowly, once per 600 s",function()
    local N=loadAddon(); weReady(N); roster={{"Wes-TestRealm",true},{"Wesb-TestRealm",true},{"Wesc-TestRealm",true},{"Wesd-TestRealm",true},{"Wese-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()
    -- a report before any War Effort reader was heard: not sent to War Effort, so never in an answer
    foe(N,1,{key="Player-1-701",name="Ee Ff"}); foe(N,2,{key="Player-1-702",name="Gg Hh"}); steps(20); eq(#weSent("C"),0)
    hello("Wes",19)
    -- a report the client refused (throttled) is not kept either
    sendResult=3; foe(N,1,{key="Player-1-703",name="Ii Jj"}); foe(N,2,{key="Player-1-704",name="Kk Ll"}); steps(20); sendResult=0
    we("Y|1","GUILD","Wese"); steps(100); eq(#weTo("Wese"),0,"unsent reports are not ours to answer with")
    advance(20)
    -- four reports of our own, each with two new enemies; a received report too
    for i=0,3 do units.target=nil; foe(N,1,{key="Player-1-8"..i.."1",name="Aa Bb"..string.char(97+i)}); foe(N,2,{key="Player-1-8"..i.."2",name="Cc Dd"..string.char(97+i)}); steps(20) end
    report(9,9000,"Scout")
    local mine=weSent("C"); yes(#mine>=4,#mine)
    sent={}; N.WeNet.rand=function() return .5 end; WorldMapFrame={IsShown=function() return true end}   -- (2 s heartbeat)
    we("Y|1||a:900"); steps(25); eq(#weTo("Wes"),0,"a random start, here 30 s")
    local times={}; for _=1,100 do advance(1); local n=#weTo("Wes"); if n>#times then times[#times+1]=clock end end
    WorldMapFrame=nil
    for i=2,#times do yes(times[i]-times[i-1]>=4.9,"paced "..(times[i]-times[i-1])) end
    local out=weTo("Wes"); local cs={}
    for _,m in ipairs(out) do if m.text:sub(1,2)=="C|" then cs[#cs+1]=m.text end end
    eq(#cs,3,"three reports"); for i,c in ipairs(cs) do yes(c:find("|"..i..":3$"),c); no(c:find("^C|9|"),"never a received report") end
    eq(#out,6,"each C followed by its E")
    -- the asked age is kept: our reports are older than 60 s now
    we("Y|1||a:60","GUILD","Wesd"); steps(120); eq(#weTo("Wesd"),0,"all older than the asked age")
    N.WeNet.rand=nil
    -- paced: never two within 5 s
    -- (the heartbeat sends one per tick)
    advance(100); we("Y|1||a:900"); advance(120); eq(#weTo("Wes"),6,"once per 600 s")
    -- another continent, a too-short age, a Y on PARTY, a Y from ourselves: nothing
    sent={}; we("Y|999","GUILD","Wesb"); grouped=true; we("Y|1","PARTY","Pam"); grouped=false; we("Y|1","GUILD","Me"); advance(120)
    eq(#weTo("Wesb"),0); eq(#weTo("Pam"),0); eq(#weTo("Me"),0)
    advance(500); we("Y|1||a:60","GUILD","Wesc"); advance(120); eq(#weTo("Wesc"),0,"all older than the asked age")
end)
test("1.0 A2: WeNet: a report that grows older than the asked age while queued is skipped",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,130,cont,function() return 1 end))           -- 30 s old when asked, starts at 190
    eq(Wn.nextAnswer(st,189),nil); eq(Wn.nextAnswer(st,190),nil,"90 s old by then: skipped")
    st=Wn.new(0); Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,130,cont,function() return .2 end)); local who,c=Wn.nextAnswer(st,142); eq(who,"Wes"); yes(c:find("|1:1$"))
end)
test("1.0 A2: a J gets one K saying off (status 2) per 60 s, by whisper, and never an invite",function()
    local N=loadAddon(); weReady(N); N.Net.setConsent("public"); advance(1)
    we("J|5|100|7086|0.5|0.5|"..math.floor(server)%3600,"WHISPER","Stranger")
    local k=weTo("Stranger"); eq(#k,1); yes(k[1].text:find("^K|5|2|%d+$"),k[1].text)
    we("J|6|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),1,"one per 60 s")
    advance(61); we("J|7|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),2)
    eq(#invites,0)
    -- a malformed J, a J on GUILD, and anything else by whisper: nothing
    we("J|x","WHISPER","Other"); we("J|8|100|7086|0.5|0.5","GUILD","Other"); we("C|1|100|0|0|7|1|1","WHISPER","Other"); eq(#weTo("Other"),0)
    -- guild-only consent: a stranger's J gets no answer (public whisper)
    N=loadAddon(); weReady(N); N.Net.setConsent("guild"); advance(1); we("J|5|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),0)
end)

-- 1.0 lane A3: War Effort embassy (P presence, partners, elections, D links, W out, W in as G)
local WECH="WarEfforttestrealmA"
local function embReady(N,members)
    netOn(N,"we"); N.Net.setConsent("public"); units.player={name="Me",class="MAGE",level=60}
    C_Club={GetGuildClubId=function() return 789 end}
    roster={{"Wes-TestRealm",true},{"Bob-TestRealm",true}}; chanMembers[WECH]=members
    establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain()
end
local function wh(t,who) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="WHISPER" and (not who or m.target==who) and m.text:sub(1,#t)==t then out[#out+1]=m end end; return out end
local function gHello(who,public) deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19|0|0|"..math.floor(server)%3600 .."|789|H|60|"..(public and "1" or "0"),"GUILD",who); drain() end
test("1.0 A3: the election score is War Effort's (DJB2, highest wins, lower name on ties)",function()
    local N=loadAddon(); local E=N.WeEmb
    eq(E.score("me","greet|kora reed"),52895520); eq(E.score("wes","greet|kora reed"),582354751)
    eq(E.score("me","fwd|g456"),1818921933); eq(E.score("wes","fwd|g456"),887266629)
    eq(E.score("kora reed","pair|g456"),1166973082); eq(E.score("ann lee","pair|g456"),2027833503)
    no(E.first("me",{"Wes"},"greet|kora reed")); yes(E.first("me",{"Wes"},"greet|ann lee")); yes(E.first("me",{},"x"))
    yes(E.first("me",{"Wes"},"fwd|g456")); yes(E.first("me",{"me"},"x"),"ourselves are skipped")
    -- P, W, D read and built as War Effort's
    local P=N.Protocol
    local p=P.decode("P|19|789|0|"); eq(p.type,"P"); eq(p.minor,19); eq(p.guild,"789"); eq(p.ask,false)
    eq(P.decode("P|19|-|0|a").guild,false); eq(P.decode("P|19|-|0|a").ask,true); eq(P.decode("P|19|x|0|"),nil); eq(P.decode("P|19|789"),nil)
    eq(N.WeOut.presence("789",false),"P|19|789|0|"); eq(N.WeOut.presence(nil,true),"P|19|-|0|a")
    local d=P.decode("D|g456,n4b6f7261"); eq(#d.links,2); eq(d.links[1],"g456"); eq(#P.decode("D|").links,0); eq(P.decode("D|g1,g2,g3,g4"),nil); eq(P.decode("D|x9"),nil)
    eq(N.WeOut.links({"g456"}),"D|g456"); eq(N.WeOut.links({}),"D|")
    local w=P.decode("W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100"); eq(w.type,"W"); eq(w.origin,"Kora Reed"); eq(w.inner.type,"C")
    eq(P.decode("W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100||1:1"),nil,"a sync answer never travels wrapped")
    eq(N.WeOut.wrap("W","Kora Reed",nil,"C|5|100|0.4|0.5|7086|2|100"),"W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100")
end)
test("1.0 A3: the embassy stays off with a reason; an empty or missing member list greets nobody",function()
    local N=loadAddon(); embReady(N,nil); steps(300); eq(#wh("P|"),0,"no member list")
    N=loadAddon(); embReady(N,{}); steps(300); eq(#wh("P|"),0,"an empty list")
    eq(N.Main.embassyWhy(),nil,"(otherwise on)")
    -- guild-only consent, no guild, no guild id, an all-digit realm (no War Effort channel)
    N=loadAddon(); embReady(N,{"Ann Lee"}); N.Net.setConsent("guild"); eq(N.Main.embassyWhy(),"public networks are off"); steps(120); eq(#wh("P|"),0)
    N=loadAddon(); embReady(N,{"Ann Lee"}); C_Club=nil; eq(N.Main.embassyWhy(),"your guild's id is not readable"); steps(120); eq(#wh("P|"),0)
    N=loadAddon(); embReady(N,{"Ann Lee"}); inGuild=false; eq(N.Main.embassyWhy(),"not in a guild"); inGuild=true
    N=loadAddon(); embReady(N,{"Ann Lee"}); GetRealmName=function() return "7102" end; GetNormalizedRealmName=function() return "7102" end
    eq(N.Main.embassyWhy(),"no War Effort channel on this realm (all-digit realm name)"); steps(120); eq(#wh("P|"),0)
    log={}; SlashCmdList.LAYERENEMIES("status"); yes(logged("War Effort embassy: off (no War Effort channel on this realm (all-digit realm name))"))
    N=loadAddon(); embReady(N,{"Ann Lee"}); log={}; SlashCmdList.LAYERENEMIES("status"); yes(logged("War Effort embassy: on"))
end)
test("1.0 A3: we greet only our share, one a minute; an answer makes a partner; no answer leaves them alone 1800 s",function()
    local N=loadAddon(); embReady(N,{"Kora Reed","Ann Lee","Bo Dyl","Wes"}); gHello("Wes",true)
    local tg; for _=1,40 do advance(1); if not tg and #wh("P|")>0 then tg=clock end end
    local p=wh("P|"); eq(#p,1); eq(p[1].text,"P|19|789|0|a"); yes(p[1].target=="Ann Lee" or p[1].target=="Bo Dyl",p[1].target)
    local first=p[1].target; eq(#wh("P|","Kora Reed"),0,"Kora Reed is Wes's share"); eq(#wh("P|","Wes"),0,"never a guildmate")
    while clock<tg+59 do advance(1) end; eq(#wh("P|"),1,"one greeting a minute at most")
    local t1=clock; deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER",first); drain(); yes(N.WeEmb.partner(N.Main.emb,first,clock))
    steps(100); local other=first=="Ann Lee" and "Bo Dyl" or "Ann Lee"; eq(#wh("P|",other),1,"the next of our share")
    steps(40); no(N.WeEmb.partner(N.Main.emb,other,clock)); steps(1700); eq(#wh("P|"..""..""),#wh("P|"),"(count)")
    -- the unanswered one is left alone: not greeted again for 1800 s
    eq(#wh("P|19|789|0|a",other),1)
end)
test("1.0 A3: a greeting is answered at most 6 times a minute over all players; a guildmate's P makes no partner",function()
    -- (r040c 124: only channel members, or players we greeted, get an answer)
    local list={}; for i=1,8 do list[i]="Strang"..abc(i) end; list[9]="Strangx"; list[10]="Gilda"; list[11]="Olda"
    local N=loadAddon(); embReady(N,list); steps(13); N.Main.emb.nextGreetAt=1e9
    for i=1,8 do deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Strang"..abc(i)); drain() end
    steps(5); eq(#wh("P|19|789|0|"),6,"6 replies a minute"); eq(#wh("P|","Strangg"),0)
    for i=1,8 do yes(N.WeEmb.partner(N.Main.emb,"Strang"..abc(i),clock)) end
    steps(61); deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Strangx"); drain(); steps(3); eq(#wh("P|","Strangx"),1)
    eq(#wh("P|","Strangg"),0,"(the partner we hold gets keepalives; Strangg is not it)")
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|789|0|a","WHISPER","Gilda"); drain(); no(N.WeEmb.partner(N.Main.emb,"Gilda",clock),"our guild's id")
    deliver("CHAT_MSG_ADDON","WEFF1","P|18|456|0|a","WHISPER","Olda"); drain(); no(N.WeEmb.partner(N.Main.emb,"Olda",clock),"minor 18")
end)
test("1.0 A3: D lists only links we serve; withdrawn with D| when public networks go off",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13); eq(#weGuild("D|"),0,"nothing held, nothing said")
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    local d=weGuild("D|"); eq(#d,1); eq(d[1].text,"D|g456")
    local function annP() deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER","Ann Lee"); drain() end
    steps(130); eq(#weGuild("D|"),1,"unchanged: again only after 600 s"); annP(); steps(240); annP(); steps(240); annP(); eq(#weGuild("D|"),2)
    eq(weGuild("D|")[2].text,"D|g456","repeated while held")
    N.Net.setConsent("guild"); steps(130); local d2=weGuild("D|"); eq(d2[#d2].text,"D|","withdrawn although the partner is alive")
    steps(700); eq(weGuild("D|")[#weGuild("D|")].text,"D|"); local n=#weGuild("D|"); steps(700); eq(#weGuild("D|"),n,"said once")
end)
test("1.0 A3: forwarding: a guildmate's own report only if their hello said public; ours; H once per 600 s; never a wrapped one",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    local function from(who) local n=0; for _,m in ipairs(wh("W|","Ann Lee")) do local d=N.Protocol.decode(m.text); if d and d.origin==who then n=n+1 end end; return n end
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    local st=math.floor(server)%3600
    gHello("Wes",true); gHello("Bob",false)
    steps(3); eq(from("Wes"),1,"Wes's hello forwarded")
    deliver("CHAT_MSG_ADDON","WEFF1","C|5|100|0.4|0.5|7086|2|"..st,"GUILD","Wes"); deliver("CHAT_MSG_ADDON","WEFF1","E|5|1|1|abc:H:60|"..st,"GUILD","Wes"); drain(); steps(61)
    eq(from("Wes"),3,"C and its first E (Wire's 4 public whispers a minute to one player: the E waits in the queue)")
    deliver("CHAT_MSG_ADDON","WEFF1","E|5|1|1|abd:H:60|"..st,"GUILD","Wes"); drain(); eq(from("Wes"),3,"only the first E")
    deliver("CHAT_MSG_ADDON","WEFF1","C|6|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); drain(); eq(from("Bob"),0,"Bob said public 0")
    deliver("CHAT_MSG_ADDON","WEFF1","C|7|100|0.4|0.5|7086|2|"..st,"GUILD","Cyd"); drain(); steps(5); eq(from("Cyd"),0,"no hello heard: unknown")
    local raw=#wh("W|","Ann Lee"); deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Wes"); drain(); steps(61); eq(#wh("W|","Ann Lee"),raw,"never a G")
    gHello("Wes",true); eq(from("Wes"),3,"a hello once per 600 s")
    -- our own report goes too
    hello("Wes",19); foe(N,1); foe(N,2); steps(20); local ws=wh("W|","Ann Lee"); local mine=0
    for _,m in ipairs(ws) do local d=N.Protocol.decode(m.text); if d and d.origin=="Me" and d.inner.type~="H" then mine=mine+1 end end; eq(mine,2,"our C and E")
end)
test("1.0 A3: only the top-scored holder of a guild forwards to it",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|457|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    gHello("Wes",true); deliver("CHAT_MSG_ADDON","WEFF1","D|g457","GUILD","Wes"); drain()
    local st=math.floor(server)%3600; local n=#wh("W|")
    deliver("CHAT_MSG_ADDON","WEFF1","C|5|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); gHello("Bob",true)
    deliver("CHAT_MSG_ADDON","WEFF1","C|8|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); drain()
    yes(#wh("W|")>n,"we rank first for g457 (1824785540 > 1080776665)")
    -- g450: Wes ranks first (1873690060 > 1783740291): we hold it but stand by
    N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|450|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    gHello("Wes",true); gHello("Bob",true); deliver("CHAT_MSG_ADDON","WEFF1","D|g450","GUILD","Wes"); drain(); steps(61); n=#wh("W|")
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"GUILD","Bob"); drain(); steps(61); eq(#wh("W|"),n,"Wes forwards to g450, not us")
end)
test("1.0 A3: a W from a live partner of another guild goes into the guild as G and is stored as relayed; from others it is dropped",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); hello("Kora Reed",19,"WHISPER")
    local st=math.floor(server)%3600; local inner="C|5|100|0.4|0.5|7086|2|"..st
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||"..inner,"WHISPER","Ann Lee"); drain()
    -- (r040c 124: the inner line is rebuilt from its decoded fields: coordinates with three decimals)
    local g=weGuild("G|"); eq(#g,1); eq(g[1].text,"G|"..hx("Kora Reed").."||C|5|100|0.400|0.500|7086|2|"..st)
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].record.hand,"relayed"); eq(rows[1].record.share,"public")
    -- the same report again: not bridged twice; a W from a stranger or a guildmate: dropped
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||"..inner,"WHISPER","Ann Lee"); drain(); eq(#weGuild("G|"),1)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|6|100|0.4|0.5|7086|2|"..st,"WHISPER","Stranger"); drain(); eq(#weGuild("G|"),1)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|7|100|0.4|0.5|7086|2|"..st,"WHISPER","Wes"); drain(); eq(#weGuild("G|"),1)
    -- a W naming ourselves, or naming its own sender, is refused; at most 10 bridged sightings a minute
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Me").."||C|8|100|0.4|0.5|7086|2|"..st,"WHISPER","Ann Lee"); drain(); steps(5); eq(#weGuild("G|"),1,"naming us")
    for i=1,12 do deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Scout"..abc(i)).."||C|9|100|0.4|0.5|7086|2|"..st,"WHISPER","Ann Lee"); drain() end
    steps(40); eq(#weGuild("G|"),10,"10 a minute (the first included)")
    -- a W we got is never forwarded to another partner
    eq(#wh("W|"),0)
    -- a partner gone quiet (no presence for 600 s) is no partner
    N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13); deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(605)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"WHISPER","Ann Lee"); drain(); steps(5)
    eq(#weGuild("G|"),0,"expired partner")
end)

-- 1.0 lane B: HeadHunter mesh (B1) and catch-up (B2)
local function hhReady(N,members)
    netOn(N,"hh"); N.Net.setConsent("public"); units.player={name="Me",class="MAGE",level=60,guid="Player-7091-00000001"}
    GetCurrentRegion=function() return 3 end; chanMembers.HeadHunterSync=members; establish(N); server=HHT
end
local function hw(t,who) local out={}; for _,m in ipairs(sent) do if m.prefix=="HeadHunter" and m.kind=="WHISPER" and (not who or m.target==who) and m.text:sub(1,#t)==t then out[#out+1]=m end end; return out end
local function hhIn(text,from) deliver("CHAT_MSG_ADDON","HeadHunter",text,"WHISPER",from); drain() end
local function env(author,hops,t,inner,world,f) return "1AE:"..(world or "eu-pvp")..";"..author..";"..(f or "A")..";5cy;"..b36(hops)..";"..b36(t or HHT)..";"..inner end
test("1.0 B1: hello is exactly LayerEnemies, once per peer per session, one per tick at most; an N is answered once",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Me"}); steps(30)
    local h=hw("1AN:"); eq(#h,3); for _,m in ipairs(h) do eq(m.text,"1AN:LayerEnemies") end
    local seen={}; for _,m in ipairs(h) do no(seen[m.target],m.target); seen[m.target]=true end; no(seen.Me,"never ourselves")
    steps(600); eq(#hw("1AN:"),3,"once per peer per session")
    -- paced: never two hellos in the same 2 s
    local times={}; N=loadAddon(); hhReady(N,{"Ann Lee","Bo Dyl","Cy Fen","Di Gar"}); for _=1,40 do advance(1); times[#times+1]=#hw("1AN:") end
    for i=3,#times do yes(times[i]-times[i-2]<=1,"one per 2 s") end
    -- an N from a new peer gets ours once
    N=loadAddon(); hhReady(N,{}); advance(1); hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); eq(#hw("1AN:","Kora Reed"),1)
    hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); steps(10); eq(#hw("1AN:","Kora Reed"),1)
end)
test("1.0 B1: an envelope is forwarded unchanged but its hops, to peers that are neither author nor carrier",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Peer Four","Peer Five","Mira Vale","Sera Dawn"}); steps(30); sent={}
    local e=env("Mira Vale",1,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y")
    hhIn(e,"Mira Vale"); steps(5)
    local f=hw("1AE:"); yes(#f>=1 and #f<=4,#f)
    for _,m in ipairs(f) do eq(m.text,env("Mira Vale",2,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y")); yes(m.target~="Mira Vale" and m.target~="Me") end
    -- the same envelope again (another carrier): not forwarded again
    local n=#hw("1AE:"); hhIn(env("Mira Vale",2,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y"),"Sera Dawn"); steps(5); eq(#hw("1AE:"),n)
    -- a carried one: never back to its carrier or author
    sent={}; hhIn(env("Mira Vale",3,HHT,"DKora Reed;x"),"Sera Dawn"); steps(5)
    for _,m in ipairs(hw("1AE:")) do yes(m.target~="Sera Dawn" and m.target~="Mira Vale",m.target); yes(m.text:find(";4;",1,true)) end
end)
test("1.0 B1: hops 5, too old, from the future, another world, our own, author-carried after hop 1, T: not forwarded",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Mira Vale","Sera Dawn"}); steps(30); sent={}
    local L="LKora Reed;13k;"..b36(HHT)..";dw;6y"
    hhIn(env("Mira Vale",5,HHT,L),"Sera Dawn"); hhIn(env("Mira Vale",6,HHT,"DAa Bb;1"),"Sera Dawn")
    hhIn(env("Mira Vale",1,server-601,"DAa Bb;2"),"Mira Vale"); hhIn(env("Mira Vale",1,server+301,"DAa Bb;3"),"Mira Vale")
    hhIn(env("Mira Vale",1,HHT,"DAa Bb;4","us-pvp"),"Mira Vale"); hhIn(env("Me",1,HHT,"DAa Bb;5"),"Sera Dawn")
    hhIn(env("Mira Vale",2,HHT,"DAa Bb;6"),"Mira Vale"); hhIn(env("Mira Vale",1,HHT,"Thello"),"Mira Vale")
    hhIn(env("Mira Vale",1,HHT,"Fx;y","eu-pvp","H"),"Mira Vale")
    steps(5); eq(#hw("1AE:"),0)
    eq(N.HhNet.held(N.Main.hhNet),0,"none of them stored for catch-up")
    -- (another author and carrier: Mira Vale has used up her 6 frames in 10 s)
    hhIn(env("Kora Reed",1,server,"DAa Bb;7","eu-?"),"Kora Reed"); steps(5); yes(#hw("1AE:")>=1,"a world part unknown on one side does not split it")
end)
test("1.0 B1: the duplicate ring holds 4000 keys",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new()
    for i=1,4000 do HN.remember(st,"k"..i) end; yes(HN.seen(st,"k1")); HN.remember(st,"k4001"); no(HN.seen(st,"k1")); yes(HN.seen(st,"k2")); yes(HN.seen(st,"k4001"))
    eq(HN.key("Mira Vale","L","x"),"miravaleL"..(N.HhNet.hash("x")))
    eq(HN.hash("abc"),193485963); eq(HN.compact("Mira Vale-7102"),"miravale")
    -- offers are collected 5 s from the first one
    st=HN.new(); st.asked=0; local ctx={side="A",serverNow=HHT}
    HN.offer(st,"Peer One","3",1); eq(#HN.pull(st,3,ctx),0); eq(#HN.pull(st,5.9,ctx),0); local p=HN.pull(st,6,ctx); eq(p[1].target,"Peer One")
end)
test("1.0 B2: catch-up: Q:h after login, offers collected, pulled from one, S taken only from that sender",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three"}); steps(25)
    local q=hw("1AQ:h"); yes(#q>=1 and #q<=6,#q)
    hhIn("1AO:3","Peer One"); steps(3); eq(#hw("1AQ:p"),0,"collecting for 5 s"); hhIn("1AO:5","Peer Two"); steps(4)
    local p=hw("1AQ:p"); eq(#p,1); eq(p[1].target,"Peer Two","the biggest offer")
    hhIn("1AS:DAa Bb;1~KCc;2","Peer One"); eq(N.HhNet.held(N.Main.hhNet),0,"not the pulled sender")
    hhIn("1AS:DAa Bb;1~KCc;2","Peer Two"); hhIn("1AS:E2","Peer Two"); eq(N.HhNet.held(N.Main.hhNet),2)
    hhIn("1AS:DDd;3","Peer Two"); eq(N.HhNet.held(N.Main.hhNet),2,"after its end marker")
end)
test("1.0 B2: serving: no O with an empty store; O counts what a pull then sends, byte-equal; E0; once per requester per 300 s",function()
    local N=loadAddon(); hhReady(N,{}); steps(25); N.HhNet.chance=function() return 1 end
    -- (r040c 9b8: a pull is served only to a known peer: the askers say hello first)
    hhIn("1AN:HeadHunter 1.1.1","Asker One"); steps(3)
    hhIn("1AQ:h"..b36(HHT-600),"Asker One"); steps(5); eq(#hw("1AO:"),0,"empty store: no offer")
    hhIn("1AQ:p"..b36(HHT-600),"Asker One"); steps(5); local e=hw("1AS:","Asker One"); eq(#e,1); eq(e[1].text,"1AS:E0")
    -- records carried in envelopes are held and served byte for byte
    hhIn(env("Mira Vale",1,server,"DAa Bb;1;x"),"Mira Vale"); hhIn(env("Sera Dawn",1,server,"KCc Dd;2"),"Sera Dawn"); hhIn(env("Sera Dawn",1,server,"LKora Reed;13k;"..b36(server)..";dw;6y"),"Sera Dawn")
    eq(N.HhNet.held(N.Main.hhNet),2,"D and K are history; L is not")
    hhIn("1AN:HeadHunter 1.1.1","Asker Two"); hhIn("1AN:HeadHunter 1.1.1","Asker Three"); steps(5)
    hhIn("1AQ:h"..b36(HHT-600),"Asker Two"); steps(5); local o=hw("1AO:","Asker Two"); eq(#o,1); eq(o[1].text,"1AO:2")
    hhIn("1AQ:p"..b36(HHT-600),"Asker Two"); steps(5)
    local body={}; for _,m in ipairs(hw("1AS:","Asker Two")) do body[#body+1]=m.text:sub(5) end
    local all=table.concat(body,"~"); yes(all:find("DAa Bb;1;x",1,true)); yes(all:find("KCc Dd;2",1,true)); yes(all:find("E2$"),all)
    local n=#hw("1AS:","Asker Two"); hhIn("1AQ:p"..b36(HHT-600),"Asker Two"); steps(5); eq(#hw("1AS:","Asker Two"),n,"once per 300 s")
    -- Q:h answered at most once per requester per 300 s too
    hhIn("1AQ:h"..b36(HHT-600),"Asker Three"); hhIn("1AQ:h"..b36(HHT-600),"Asker Three"); steps(5); eq(#hw("1AO:","Asker Three"),1)
end)
test("1.0 B2: a link H is answered with our home server, once per 600 s",function()
    local N=loadAddon(); hhReady(N,{}); advance(1)
    hhIn("1AH:5cy","Kora Reed"); local h=hw("1AH:","Kora Reed"); eq(#h,1); eq(h[1].text,"1AH:"..b36(7091))
    hhIn("1AH:5cy","Kora Reed"); steps(10); eq(#hw("1AH:","Kora Reed"),1)
end)
test("1.0 B: off, guild-only, HeadHunter loaded or in an instance: nothing on HeadHunter",function()
    for _,c in ipairs({"ship","consent","loaded","instance"}) do
        local N=loadAddon(); hhReady(N,{"Peer One"})
        if c=="ship" then N.Net.SHIP.hh=false elseif c=="consent" then N.Net.setConsent("guild") elseif c=="loaded" then loaded.HeadHunter=true else inInstance=true end
        hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); steps(40); eq(#hw(""),0,c); loaded.HeadHunter=nil; inInstance=false
    end
end)

-- 1.0 lane C1: the Spy family in ([Spy], ForeverSpy1, FSENT03), receive only
local function spyRows(N,src) local out={}; for _,r in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if r.record.src==src then out[#out+1]=r end end; return out end
local function spyIn(prefix,text,kind,from) deliver("CHAT_MSG_ADDON",prefix,text,kind,from); drain() end
test("1.0 C1: a [Spy] line: the enemy as First Last, observer position, map to zone, class and level checked",function()
    local N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.42|0.61|Some Guild|101","GUILD","Spyuser")
    local rows=spyRows(N,"spy"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"seen"); eq(r.origin,"Spyuser"); eq(r.hand,"first"); eq(r.at,clock,"Spy carries no age: heard now"); eq(r.zone,100); eq(r.pos,"observer"); eq(r.x,.42); eq(r.y,.61)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"ROGUE"); eq(r.enemies[1].level,60); eq(r.count,1)
    eq(rows[1].positionKind,"observer's position"); eq(rows[1].source,"seen (Spy)"); eq(r.layer.ns,"unknown")
    -- numeric realm kept, our own stripped; one word alone; no coordinates
    spyIn("[Spy]","1.3.8|Ann-Lee-7103|MAGE||Human|Ashenvale|||||100","PARTY","Spyuser")
    spyIn("[Spy]","1.3.8|Bo-Dyl-7102|||||||||100","RAID","Spyuser")
    spyIn("[Spy]","1.3.8|Cyra|||||||||100","GUILD","Spyuser")
    local names={}; for _,row in ipairs(spyRows(N,"spy")) do names[row.record.enemies[1].name]=row.record end
    yes(names["Ann Lee-7103"]); eq(names["Ann Lee-7103"].pos,"none"); eq(names["Ann Lee-7103"].enemies[1].level,nil); yes(names["Bo Dyl-7102"]); eq(N.Invite.key("Bo Dyl-7102"),"bo dyl","our realm folds away in the key"); yes(names["Cyra"])
end)
test("1.0 C1: [Spy] refusals: multi-part, field count, class, level, coordinates, guild, name, map, route, own",function()
    local N=loadAddon(); establish(N)
    local bad={"\0011.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","\0021.3.8|x","\0031.3.8|x",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6|","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100|x",
        "1.3.8|Kora-Reed|BADCLASS|60|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed|ROGUE|0|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|61.5|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed|ROGUE|101|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||1.5|0.6||100","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6|"..string.rep("g",25).."|100",
        "1.3.8|Kora2-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed-Lee|ROGUE|60|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100x","1.3.8||ROGUE|60|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||5"}
    for i,t in ipairs(bad) do spyIn("[Spy]",t,"GUILD","Spyuser"..abc(i)) end
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","WHISPER","Spyw")
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Me")
    spyIn("[Spy]","1.3.8|Me|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyz")
    eq(#spyRows(N,"spy"),0)
end)
test("1.0 C1: ForeverSpy1 on a group: name and zone name; FSENT03: GUID, age, level",function()
    local N=loadAddon(); establish(N)
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsuser")
    local rows=spyRows(N,"fspy"); eq(#rows,1); local r=rows[1].record
    eq(r.enemies[1].name,"Kora Reed"); eq(r.zone,100); eq(r.pos,"none"); eq(r.x,nil); eq(rows[1].source,"seen (Forever Spy)")
    for i,t in ipairs({"2\tKora Reed\tAshenvale","1\tKora Reed\tNowhere","1\t[Kora]\tAshenvale","1\t Kora\tAshenvale","1\tKora Reed\tAshenvale\tx",
        "1\tKora-Reed\tAshenvale"}) do spyIn("ForeverSpy1",t,"PARTY","Fsb"..abc(i)) end
    spyIn("ForeverSpy1","1\tAnn Lee\tAshenvale","GUILD","Fsc")
    eq(#spyRows(N,"fspy"),1)
    spyIn("FSENT03","1~Player-7103-00AB12~Kora-Reed~MAGE~60~Ashenvale~5","RAID","Seuser")
    rows=spyRows(N,"sent"); eq(#rows,1); r=rows[1].record
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"MAGE"); eq(r.at,clock-5); eq(r.age,5); eq(rows[1].source,"seen (Sentinel)")
    spyIn("FSENT03","1~Player-7103-00AB13~Ann Lee~~-1~Ashenvale~0","PARTY","Seuser"); eq(#spyRows(N,"sent"),2)
    for i,t in ipairs({"1~Player-7103-00AB14~Bo Dyl~MAGE~60~Ashenvale~121","1~Creature-0-1~Bo Dyl~MAGE~60~Ashenvale~1",
        "2~Player-7103-00AB15~Bo Dyl~MAGE~60~Ashenvale~1","1~Player-7103-00AB16~Bo Dyl~MAGE~60~Ashenvale~1~x",
        "1~Player-7103-00AB17~Bo Dyl~NOPE~60~Ashenvale~1","1~Player-7103-00AB18~Bo Dyl~MAGE~1001~Ashenvale~1",
        "1~Player-7103-00AB19~Bo Dyl~MAGE~60~Ashenvale~1.5"}) do spyIn("FSENT03",t,"RAID","Seb"..abc(i)) end
    spyIn("FSENT03","1~Player-7103-00AB20~Bo Dyl~MAGE~60~Ashenvale~1","GUILD","Sec")
    eq(#spyRows(N,"sent"),2)
end)
test("1.0 C1: the same enemy again from one observer is one row; 6 lines per sender per 10 s; donor prefixes remain receive-only",function()
    local N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyuser"); advance(2)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.5|0.6||100","GUILD","Spyuser"); eq(#spyRows(N,"spy"),1)
    eq(spyRows(N,"spy")[1].x,.5,"the newer sighting replaces the row"); eq(spyRows(N,"spy")[1].at,clock)
    -- a refused newer line keeps the old row
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.6|0.6||200","GUILD","Spyuser"); eq(#spyRows(N,"spy"),1); eq(spyRows(N,"spy")[1].x,.5)
    -- a zone name two zones share is no answer
    N=loadAddon(); establish(N)
    C_Map.GetMapChildrenInfo=function() return {{mapID=200,name="Twin"},{mapID=100,name="Twin"},{mapID=100,name="Ashenvale"}} end
    spyIn("ForeverSpy1","1\tKora Reed\tTwin","PARTY","Fsx"); eq(#spyRows(N,"fspy"),0)
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsx"); eq(#spyRows(N,"fspy"),1)
    local who={"Ann Lee","Bo Dyl","Cy Fen","Di Gar","Ed Hal","Fa Ivo","Gu Jem"}
    for i=1,7 do spyIn("ForeverSpy1","1\t"..who[i].."\tAshenvale","PARTY","Flood") end
    local function flood() local n=0; for _,r in ipairs(spyRows(N,"fspy")) do if r.reporter=="Flood" then n=n+1 end end; return n end
    eq(flood(),6,"the seventh in 10 s dropped")
    advance(11); spyIn("ForeverSpy1","1\tGu Jem\tAshenvale","PARTY","Flood"); eq(flood(),7)
    for _,m in ipairs(sent) do no(m.prefix=="[Spy]" or m.prefix=="ForeverSpy1" or m.prefix=="FSENT03",m.prefix) end
end)

-- 1.0 lane C2: guild incidents in (GBOUNTY, WALLOFSHAME, FTold1), GUILD only, receive only
test("1.0 C2: a Guild Bounty death: the killer as enemy, the victim's position (zone map only), class and level",function()
    local N=loadAddon(); establish(N)
    spyIn("GBOUNTY","D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|Some Guild","GUILD","Victim")
    local rows=spyRows(N,"gb"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"death"); eq(r.origin,"Victim"); eq(r.zone,100); eq(r.pos,"victim"); eq(r.x,.425); eq(r.y,.61)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"ROGUE"); eq(r.enemies[1].level,60)
    eq(rows[1].positionKind,"victim's position"); eq(rows[1].source,"death (Guild Bounty)")
    -- a child map: the zone, without coordinates (they are the child map's)
    spyIn("GBOUNTY","D|Ann Lee|101|10.0|20.0||||MAGE|","GUILD","Victimb"); r=spyRows(N,"gb")[1].record
    for _,row in ipairs(spyRows(N,"gb")) do if row.record.origin=="Victimb" then r=row.record end end
    eq(r.zone,100); eq(r.x,nil); eq(r.pos,"none"); eq(r.enemies[1].name,"Ann Lee")
    for i,t in ipairs({"D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE","D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|g|x",
        "D||100|42.5|61.0||60|2|ROGUE|","D|Kora-Reed|100|142.5|61.0||60|2|ROGUE|","D|Kora-Reed|100|42.5|||60|2|ROGUE|",
        "D|Kora-Reed|100|42.5|61.0||61.5|2|ROGUE|","D|Kora-Reed|100|42.5|61.0||60|2|NOPE|","D|Kora-Reed||42.5|61.0||60|2|ROGUE|",
        "K|Kora-Reed|2|20|Victim|T","A|Hunter|20|why","X|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|g","D|Kora2|100|42.5|61.0||60|2|ROGUE|"}) do spyIn("GBOUNTY",t,"GUILD","Gb"..abc(i)) end
    spyIn("GBOUNTY","D|Bo Dyl|100|42.5|61.0||60|2|ROGUE|","PARTY","Gbp"); spyIn("GBOUNTY","D|Bo Dyl|100|42.5|61.0||60|2|ROGUE|","WHISPER","Gbw")
    eq(#spyRows(N,"gb"),2)
end)
test("1.0 C2: a Wall of Shame death names its killer by zone name; Forever Told S is a wanted player seen",function()
    local N=loadAddon(); establish(N)
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Kora Reed|60|","GUILD","Victim")
    local rows=spyRows(N,"wos"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"death"); eq(r.zone,100); eq(r.pos,"none"); eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].level,60); eq(r.enemies[1].class,nil)
    eq(rows[1].source,"death (Wall of Shame)")
    for i,t in ipairs({"D|60|Ashenvale|MAGE|4||60|","D|60|Ashenvale|MAGE|4|FALLING||","D|60|Nowhere|MAGE|4|Ann Lee|60|",
        "D|60|Ashenvale|MAGE|4|Ann Lee|60","S|60|Ashenvale|MAGE|3","P|1413|0.5000|0.6000|Ashenvale","D|60|Ashenvale|MAGE|4|Ann Lee|x|",
        "D|60|Ashenvale|MAGE|4|Me|60|"}) do spyIn("WALLOFSHAME",t,"GUILD","Wos"..abc(i)) end
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Bo Dyl|60|","PARTY","Wosp")
    eq(#spyRows(N,"wos"),1)
    spyIn("FTold1","S~Kora-Reed~Astranaar, Ashenvale","GUILD","Teller"); spyIn("FTold1","S~Ann Lee~Ashenvale","GUILD","Tellerb")
    rows=spyRows(N,"ft"); eq(#rows,2); for _,row in ipairs(rows) do eq(row.record.kind,"seen"); eq(row.record.zone,100); eq(row.source,"wanted, seen (Forever Told)") end
    for i,t in ipairs({"S~Kora-Reed","S~Kora-Reed~Astranaar, Nowhere","S~~Ashenvale","C~Kora-Reed","P~Kora-Reed~1~1~MAGE~Mage~60~Ashenvale~5",
        "S~Kora-Reed~Ashenvale~x","X~Kora-Reed~Ashenvale"}) do spyIn("FTold1",t,"GUILD","Ft"..abc(i)) end
    spyIn("FTold1","S~Bo Dyl~Ashenvale","RAID","Ftr")
    eq(#spyRows(N,"ft"),2)
    for _,m in ipairs(sent) do no(m.prefix=="GBOUNTY" or m.prefix=="WALLOFSHAME" or m.prefix=="FTold1",m.prefix) end
end)

-- 1.0 consent/status (owner decisions 2026-11-14 and on ded1bee): public by default, one first-login line, /le net,
-- per-network switches, a Guild-only switch, /le share and its window switch
local NOTICE="LayerEnemies: public networks ON (War Effort, HeadHunter…). /le net guild to limit to guild only."
local function restart(N) N.Main.started=false; N.Main.start(); drain() end
local function slash(cmd) SlashCmdList.LAYERENEMIES(cmd); drain() end
test("1.0 consent: no choice saved reads as public: public whispers and channel joins run; guild only when chosen",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh","we")
    eq(N.Net.consent(),"public"); eq(N.Net.chosen(),nil)
    local ok=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public",prio="owed"}); yes(ok)
    dirReady(N); eq(table.concat(joined,","),"HeadHunterSync,WarEfforttestrealmA")
    N.Net.setConsent("guild"); eq(N.Net.consent(),"guild"); eq(N.Net.chosen(),"guild"); eq(LayerEnemiesDB.consent,"guild")
    local why; ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Ann Lee",{net="hh",scope="public",prio="owed"}); no(ok); eq(why,"no consent")
    restart(N); eq(N.Net.consent(),"guild","kept across a reload")
    LayerEnemiesDB.consent="all"; restart(N); eq(N.Net.consent(),"public"); eq(LayerEnemiesDB.consent,nil,"an odd value is no choice")
end)
test("1.0 consent: the first-login line, once, only while a network ships; not after a guild choice",function()
    local N=loadAddon(); eq(#log>0 and logged(NOTICE) or false,false,"nothing ships: no line"); eq(LayerEnemiesDB.netNotice,nil)
    N.Net.SHIP.we=true; restart(N); yes(logged(NOTICE)); eq(LayerEnemiesDB.netNotice,true)
    local n=0; for _,l in ipairs(log) do if l==NOTICE then n=n+1 end end; eq(n,1)
    restart(N); n=0; for _,l in ipairs(log) do if l==NOTICE then n=n+1 end end; eq(n,1,"once per character")
    N=loadAddon(); LayerEnemiesDB.consent="guild"; N.Net.SHIP.hh=true; restart(N); no(logged(NOTICE),"the player already chose guild only")
end)
test("1.0 consent: /le net shows and sets the level and each network's switch",function()
    local N=loadAddon(); netOn(N,"we")
    slash("net"); yes(logged("Networks: public")); yes(logged("War Effort: on")); yes(logged("HeadHunter: off (not in this version)"))
    slash("net guild"); eq(N.Net.consent(),"guild"); yes(logged("LayerEnemies: guild only. War Effort, HeadHunter and the other public networks stay off; your guild and group still get your sightings."))
    log={}; slash("net"); yes(logged("Networks: guild only")); yes(logged("War Effort: off (guild only)"))
    slash("net public"); eq(N.Net.consent(),"public"); yes(logged("LayerEnemies: public networks ON"))
    slash("net wareffort off"); no(N.Net.switch("we")); eq(LayerEnemiesDB.nets.we,false); log={}; slash("net"); yes(logged("War Effort: off (switched off)"))
    slash("net we on"); yes(N.Net.switch("we")); slash("net headhunter off"); no(N.Net.switch("hh")); slash("net hh on"); yes(N.Net.switch("hh"))
    loaded.WarEffortScout=true; log={}; slash("net"); yes(logged("War Effort: off (War Effort is loaded: it sends, we only read)")); loaded.WarEffortScout=nil
    slash("net hh maybe"); yes(N.Net.switch("hh"),"neither on nor off: no change"); yes(logged("/le net; /le net guild"))
    log={}; slash("net bogus"); yes(logged("/le net; /le net guild; /le net public; /le net wareffort on|off; /le net headhunter on|off"))
    eq(forbidden,0)
end)
test("1.0 consent: /le share off stops every own-sighting send (O, C+E); saved; on again restores",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); local M=N.Main
    eq(M.sharing(),true,"on by default"); hello("Wes",19)
    slash("share off"); eq(LayerEnemiesDB.share,false); yes(logged("LayerEnemies: your sightings are no longer shared"))
    foe(N,1); foe(N,2); advance(3); M.shareTick(); advance(3); M.shareTick(); eq(#oLines(),0); eq(#weSent("C"),0)
    restart(N); eq(M.sharing(),false,"kept across a reload")
    slash("share on"); eq(LayerEnemiesDB.share,true); hello("Wes",19); advance(16); foe(N,3); foe(N,4); advance(3); M.shareTick(); eq(#oLines(),1); eq(#weSent("C"),1)
    LayerEnemiesDB.share="x"; restart(N); eq(M.sharing(),true,"only a saved false turns it off")
end)
test("1.0 consent: window switches for sharing, guild only and each network",function()
    local N=loadAddon(); netOn(N,"we","hh"); local U=N.UI; U.toggle(); U.select("reported")
    yes(U.share:IsShown()); eq(U.share.label.text,"Share: on"); U.share:Click(); drain(); eq(N.Main.sharing(),false); eq(U.share.label.text,"Share: off")
    eq(U.guildOnly.label.text,"Guild only: off"); U.guildOnly:Click(); drain(); eq(N.Net.consent(),"guild"); eq(U.guildOnly.label.text,"Guild only: on")
    U.guildOnly:Click(); drain(); eq(N.Net.consent(),"public","a second click opens again"); U.guildOnly:Click(); drain()
    eq(U.netWe.label.text,"War Effort: on"); U.netWe:Click(); drain(); no(N.Net.switch("we")); eq(U.netWe.label.text,"War Effort: off")
    eq(U.netHh.label.text,"HeadHunter: on"); U.netHh:Click(); drain(); no(N.Net.switch("hh"))
    N.Net.SHIP.hh=false; U.render(); eq(U.netHh.label.text,"HeadHunter: n/a")
    U.select("local"); yes(U.share:IsShown(),"on every tab")
end)
test("1.0 consent: /le status names the network level, sharing and each network",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); log={}; slash("status")
    yes(logged("Networks: public (/le net guild for guild only)")); yes(logged("Sharing your sightings: on (/le share off)"))
    yes(logged("War Effort: on")); N.Net.setConsent("guild"); slash("share off"); log={}; slash("status")
    yes(logged("Networks: guild only (/le net public to open)")); yes(logged("Sharing your sightings: off (/le share on)"))
end)

-- مانع on fab7253 (r040c/21e): guild identity checked at every hosting action; the roster request retried; a blink
test("21e fab7253: hosting acts only while the guild name is readable and equal to the guild seen",function()
    -- a switch noticed by nothing yet (no event, no roster): a request is refused and hosting goes inactive
    local N=loadAddon(); hReady(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); advance(61); guildName="Guild B"
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0,"no invite for the old guild's member"); no(N.Main.host.on)
    yes(N.Main.host.want); eq(hostF(),0,"no H either")
    -- a roster while the name is unreadable: hosting goes inactive, nothing acts
    N=loadAddon(); hReady(N); advance(61); guildName=nil; deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on)
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(hostF(),0)
    -- readable and equal again: the next roster brings it back, and it acts
    roster={{"Bob",true}}; guildName="Test Guild"; deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
    -- unreadable at the moment of an F answer: no H
    N=loadAddon(); hReady(N); advance(61); legw("F|1","Cy"); guildName=nil; advance(7); drain(); eq(#legwSent("H|"),0); guildName="Test Guild"
    -- /le host on while the name is unreadable: refused with the reason
    N=loadAddon(); establish(N); guildName=nil; slash("host on"); no(N.Main.host.on); yes(logged("your guild's name is not readable")); guildName="Test Guild"
end)
test("21e fab7253: the post-switch roster request is retried once the 15 s limit has passed",function()
    local N=loadAddon(); hReady(N); local calls=rosterCalls                      -- host on asked for a roster just now
    advance(2); guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(rosterCalls,calls,"inside 15 s: not asked yet")
    advance(14); eq(rosterCalls,calls+1,"asked once the limit passed"); advance(30); eq(rosterCalls,calls+1,"once")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)
test("21e fab7253: a guild name that blinks unreadable on a guild event comes back on the next readable event or roster",function()
    local N=loadAddon(); hReady(N); advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on,"the readable event alone")
    eq(hostF(),1,"and it acts")
    N=loadAddon(); hReady(N); advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"; deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"the readable roster alone")
    -- the blink ends in another guild: a switch, that guild's roster first
    N=loadAddon(); hReady(N); advance(61); guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); eq(N.Adapters.roster.at,nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)

-- مانع on 56dbb3c (r040c/21e C2): our own sighting keeps its own time and origin under Bulo refreshes
test("21e 56dbb3c: with Bulo refreshing every second, our own sightings still go out",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); establish(N); advance(1)
    -- one own sighting, then Bulo refreshes the same player every second
    seeFoe("Kora Reed","Player-1-901"); units.target=nil
    for i=1,10 do advance(1); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),1,"the own sighting is shared although Bulo refreshed its row")
    local row=N.Main.store.localSeen["Player-1-901"]; yes(row.source:find("^Bulo")); eq(row.ownSource,"own target"); eq(row.ownAt,clock-10)
    -- own sightings every 5 s among Bulo refreshes every second: shared again once 60 s have passed
    for i=1,70 do advance(1); if i%5==0 then seeFoe("Kora Reed","Player-1-901"); units.target=nil end
        b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),2,"a re-share after 60 s")
    -- The last own event is still within 45 s when the next 60 s cooldown ends:
    -- one more legitimate O, then Bulo-only refreshes cannot keep it eligible.
    local lastOwn=clock
    for i=1,120 do advance(1); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),3)
    local last=oLines()[3]; local own=N.Relay.decodeOwn(last.text,"Birch Scout",last.at)
    eq(own.age,math.floor(last.at-lastOwn)); yes(own.age<=45)
    -- the settle runs from our own sighting, not from a Bulo refresh: out 3 s after it
    N=loadAddon(); b=fakeBulo("7086-7"); establish(N); advance(1); local ts=clock; seeFoe("Cy Fen","Player-1-903"); units.target=nil
    local sentAt; for i=1,6 do advance(1); b.Radar.seen["Player-1-903"]={at=clock,hostile=true,src="target"}; N.Main.poll(); if not sentAt and #oLines()>0 then sentAt=clock end end
    eq(sentAt,ts+3)
    local Sh=N.Share; local sh=Sh.new(); local r={key="r",faction="opposite",zone=100,source="Bulo target",at=1,ownSource="own target",ownAt=0}
    eq(Sh.pick(sh,{r=r},1,100),nil); yes(Sh.pick(sh,{r=r},3,100),"settled 3 s after the own sighting, though first picked after a refresh")
    -- an own sighting from before a layer boundary is not carried onto a later Bulo copy
    local T=N.Store; local st=N.Main.store
    st.localSeen.k={key="k",at=clock-1,epoch=st.serial-1,ownAt=clock-1,ownSource="own target",faction="opposite"}
    T.observe(st,{key="k",at=clock,source="Bulo target",faction="opposite"},clock); eq(st.localSeen.k.ownAt,nil)
    -- the O line's age is our own sighting's
    N=loadAddon(); b=fakeBulo("7086-7"); establish(N); advance(1); local t0=clock; seeFoe("Ann Lee","Player-1-902"); units.target=nil
    advance(1); b.Radar.seen["Player-1-902"]={at=clock,hostile=true,src="target"}; N.Main.poll(); advance(3); N.Main.shareTick()
    local o=oLines()[1]; yes(o); eq(tonumber(o.text:match("^O|1|%d+|%d+|[^|]*|[^|]*|[^|]*|(%d+)|")),math.floor(o.at-t0),"age from our own sighting")
end)

-- مانع on 21eacaf (r040c/21e astra-a2)
test("21e 21eacaf: answer pacing compares against the last send time (no float edge: two sends at one timestamp)",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=50,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,900,55,cont,function() return 0 end)); yes(Wn.request(st,"Wesb",1,900,55,cont,function() return 0 end))
    local who=Wn.nextAnswer(st,61.9); eq(who,"Wes"); eq(Wn.nextAnswer(st,61.9),nil,"not twice at 61.9 (61.9+5-5 < 61.9 in floating point)")
    eq(Wn.nextAnswer(st,66.8),nil); yes(Wn.nextAnswer(st,66.9))
end)
test("21e 21eacaf: the answer queue holds five requesters; the sixth is refused",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=50,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    for _,n in ipairs({"Wes","Wesb","Wesc","Wesd","Wese"}) do yes(Wn.request(st,n,1,900,55,cont,function() return .9 end)) end
    local ok,why=Wn.request(st,"Wesf",1,900,55,cont,function() return .9 end); no(ok); eq(why,"queue full")
end)
test("21e 21eacaf: a War Effort C or E whisper to a non-guildmate needs public consent like any other",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("guild"); roster={{"Wes",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    local c=N.WeOut.cluster(5,100,.5,.5,7086,2,100,1,1); local e=N.WeOut.enemies(5,{{hash="abc",class="MAGE",level=60}},100)[1]
    for _,t in ipairs({c,e}) do
        local ok,why=Wr.send("WEFF1",t,"WHISPER","Stranger",{net="we",prio="owed"}); no(ok,t); eq(why,"no consent")
        yes((Wr.send("WEFF1",t,"WHISPER","Wes",{net="we",prio="owed"})),"a guildmate needs none")
    end
end)
test("21e 21eacaf: a raid with players outside the guild (raid units only) gets a raid hello",function()
    local N=loadAddon(); weReady(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    grouped=true; raid=true; units.raid1={name="Me"}; units.raid2={name="Bob"}; advance(12)
    local function raidN() local n=0; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="RAID" then n=n+1 end end; return n end
    eq(raidN(),0,"only guildmates"); units.raid3={name="Stranger"}; steps(200); eq(raidN(),1)
    raid=false; grouped=false; units.raid1=nil; units.raid2=nil; units.raid3=nil
end)
test("21e 21eacaf: the login Q is tried at most twice",function()
    local N=loadAddon(); weReady(N); sendResult=3; steps(200); local n=#weGuild("Q"); yes(n>=1 and n<=2,n)
    sendResult=0; steps(200); eq(#weGuild("Q"),2,"no third attempt")
    N=loadAddon(); weReady(N); steps(200); eq(#weGuild("Q"),1,"sent the first time: once")
end)
test("21e 21eacaf: answer ages are the observation's, rechecked at each send (C and E)",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,155,cont,function() return 0 end))
    local who,c=Wn.nextAnswer(st,155); yes(c and c:sub(1,2)=="C|"); eq(Wn.nextAnswer(st,160.5),nil,"the E would be 60.5 s old: not sent")
    -- Main keeps a report dated by its own sighting, not by the send
    N=loadAddon(); netOn(N,"we"); establish(N); hello("Wes",19); local t0=clock; foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    eq(#weSent("C"),1); eq(N.Main.we.kept[1].t,t0)
end)

test("1.0.0 release: both networks ship on; the first login says so once",function()
    local N=loadAddon(); eq(N.shipped.we,true); eq(N.shipped.hh,true)
    local src=io.open("LayerEnemies/Net.lua"):read("*a"); yes(src:find("Net.SHIP = { we = true, hh = true }",1,true))
    for k,v in pairs(N.shipped) do N.Net.SHIP[k]=v end; N.Main.started=false; N.Main.start(); drain()
    yes(logged("LayerEnemies: public networks ON (War Effort, HeadHunter…). /le net guild to limit to guild only."))
    log={}; SlashCmdList.LAYERENEMIES("net"); drain(); yes(logged("War Effort: on")); yes(logged("HeadHunter: on"))
end)

-- مانع on 124b7d1 (r040c/124): embassy fixes
local function annPartner(N) deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain() end
test("124 A3: held keys: an empty holder set is dropped and the table is capped at 256",function()
    local N=loadAddon(); local E=N.WeEmb; local st=E.new()
    E.links(st,{links={"g1"}},"Wes",10); yes(st.held.g1); E.links(st,{links={}},"Wes",11); eq(st.held.g1,nil,"D| drops it")
    for i=1,300 do E.links(st,{links={"g"..(1000+i)}},"Mate"..i,12) end
    eq(N.Safe.count(st.held),256,"capped")
    -- expired holders go with their key at the next prune
    E.prune(st,12+E.LINKS_SECONDS+1); eq(N.Safe.count(st.held),0)
end)
test("124 A3: wrapped lines are rebuilt from decoded fields: no trailing text travels, W out or G in",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13); annPartner(N); steps(25)
    local st=math.floor(server)%3600
    -- G in: the junk after the decoded fields is gone
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|"..st.."|12|evil:text|more","WHISPER","Ann Lee"); drain()
    local g=weGuild("G|"); eq(#g,1); eq(g[1].text,"G|"..hx("Kora Reed").."||C|5|100|0.400|0.500|7086|2|"..st.."|12")
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||E|5|1|1|abc:H:60,xyz:?:?|"..st.."|junk","WHISPER","Ann Lee"); drain()
    eq(weGuild("G|")[2].text,"G|"..hx("Kora Reed").."||E|5|1|1|abc:H:60,xyz:?:?|"..st)
    -- W out: a guildmate's C with trailing fields, and a hello, go out rebuilt
    gHello("Wes",true); steps(3)
    local hw=wh("W|","Ann Lee"); local h=N.Protocol.decode(hw[#hw].text)
    eq(h.innerText,"H|1.6.6|100|7086|1|19|0|0|"..st.."|789|H|60|1","the hello as decoded")
    deliver("CHAT_MSG_ADDON","WEFF1","C|6|100|0.4|0.5|7086|2|"..st.."|12||4f4c594d505553:4","GUILD","Wes"); drain(); steps(61)
    local c; for _,m in ipairs(wh("W|","Ann Lee")) do local d=N.Protocol.decode(m.text); if d and d.inner.type=="C" then c=d end end
    yes(c); eq(c.innerText,"C|6|100|0.400|0.500|7086|2|"..st.."|12")
end)
test("124 A3: a P makes a partner only from a channel member or someone we greeted in the last 10 min",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Stranger"); drain(); steps(5)
    no(N.WeEmb.partner(N.Main.emb,"Stranger",clock)); eq(#wh("P|","Stranger"),0,"no reply to a stranger")
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"WHISPER","Stranger"); drain(); eq(#weGuild("G|"),0)
    annPartner(N); yes(N.WeEmb.partner(N.Main.emb,"Ann Lee",clock),"a channel member")
    -- greeted by us, then gone from the list: their answer within 10 minutes counts
    N=loadAddon(); embReady(N,{"Bo Dyl"}); steps(100); yes(#wh("P|19|789|0|a","Bo Dyl")>=1); chanMembers[WECH]={"Cy Fen"}
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER","Bo Dyl"); drain(); yes(N.WeEmb.partner(N.Main.emb,"Bo Dyl",clock))
    -- after 10 minutes the greeting no longer vouches
    N=loadAddon(); embReady(N,{"Bo Dyl"}); steps(100); chanMembers[WECH]={"Cy Fen"}; steps(601)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER","Bo Dyl"); drain(); no(N.WeEmb.partner(N.Main.emb,"Bo Dyl",clock))
end)
test("124 A3: queued embassy lines are dropped when the embassy stops, the seat is lost or the origin revokes public",function()
    for _,c in ipairs({"revoke","off","seat"}) do
        -- (g450: Wes outranks us there, so his D for it takes our seat)
        local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
        deliver("CHAT_MSG_ADDON","WEFF1","P|19|450|0|a","WHISPER","Ann Lee"); drain(); steps(25); gHello("Wes",true); steps(3)
        local st=math.floor(server)%3600
        -- fill Ann Lee's 4 whispers a minute, so the next W waits in Wire's queue
        for i=1,4 do deliver("CHAT_MSG_ADDON","WEFF1","C|"..(10+i).."|100|0.4|0.5|7086|2|"..st,"GUILD","Wes"); drain() end
        local n=#wh("W|","Ann Lee")
        if c=="revoke" then gHello("Wes",false) elseif c=="off" then C_Club=nil
        else deliver("CHAT_MSG_ADDON","WEFF1","D|g450","GUILD","Wes"); drain() end
        steps(70); eq(#wh("W|","Ann Lee"),n,c)
    end
end)
test("124 A3: D| goes out at once when the War Effort switch goes off or War Effort is loaded; then former partners are dropped",function()
    for _,c in ipairs({"switch","standdown","consent"}) do
        local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13); annPartner(N); steps(25); eq(weGuild("D|")[1].text,"D|g456")
        if c=="switch" then N.Net.setSwitch("we",false) elseif c=="standdown" then loaded.WarEffortScout=true else N.Net.setConsent("guild") end
        steps(6); local d=weGuild("D|"); eq(d[#d].text,"D|",c); eq(#d,2)
        no(N.WeEmb.partner(N.Main.emb,"Ann Lee",clock),c..": dropped from the partner table")
        loaded.WarEffortScout=nil; N.Net.setSwitch("we",true); N.Net.setConsent("public")
        deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"WHISPER","Ann Lee"); drain()
        eq(#weGuild("G|"),0,c..": no W from a former partner")
        steps(700); eq(#weGuild("D|"),2,c..": said once")
    end
end)
test("124 A3: a guildmate's public=1 expires 600 s after their last hello",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13); annPartner(N); steps(25); gHello("Wes",true)
    local function cs() local n=0; for _,m in ipairs(wh("W|","Ann Lee")) do local d=N.Protocol.decode(m.text); if d and d.inner.type=="C" then n=n+1 end end; return n end
    for i=1,6 do steps(100); deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER","Ann Lee"); drain() end   -- Ann Lee stays a partner
    steps(2)
    deliver("CHAT_MSG_ADDON","WEFF1","C|30|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"GUILD","Wes"); drain(); steps(5); eq(cs(),0,"601 s after Wes's hello")
    gHello("Wes",true); deliver("CHAT_MSG_ADDON","WEFF1","C|31|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"GUILD","Wes"); drain(); steps(5); eq(cs(),1)
end)

test("124 A3: a queued greeting is dropped when the embassy stops",function()
    local N=loadAddon(); embReady(N,{"Bo Dyl"}); steps(5)
    for i=1,4 do yes((N.Wire.send("WEFF1","K|"..i.."|2|5","WHISPER","Bo Dyl",{net="we",prio="owed"}))) end
    steps(20); yes(N.Wire.isQueued("P|19|789|0|a"),"the greeting waits for Bo Dyl's budget")
    C_Club=nil; steps(70); eq(#wh("P|","Bo Dyl"),0); no(N.Wire.isQueued("P|19|789|0|a"))
end)

-- مانع on 9b803aa (r040c/9b8): HeadHunter mesh fixes
local function hctx(over) local c={world="eu-pvp",serverNow=HHT,me="me",side="A",online=2,rand=function() return 0 end}; for k,v in pairs(over or {}) do c[k]=v end; return c end
local function peerOf(HN,st,name,side) HN.heard(st,name,side or "A","eu-pvp",false,0) end   -- (heard at 0: known)
test("9b8 B: answered and offered are pruned after 300 s and capped at 256",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new(); st.history={{rec="DAa Bb;1",at=HHT}}
    for i=1,300 do local n="Asker"..abc(i%26+1)..abc(math.floor(i/26)+1); peerOf(HN,st,n); HN.query(st,"p0",n,i,hctx()); HN.query(st,"h0",n,i,hctx()) end
    yes(N.Safe.count(st.answered)<=256,N.Safe.count(st.answered)); yes(N.Safe.count(st.offered)<=256,N.Safe.count(st.offered))
    peerOf(HN,st,"Late Comer"); HN.query(st,"p0","Late Comer",700,hctx()); eq(N.Safe.count(st.answered),1,"older than 300 s pruned")
    -- a name that folds to nothing: no error, the shared fallback key
    yes(pcall(HN.query,st,"p0","   ",701,hctx())); yes(pcall(HN.query,st,"h0","   ",702,hctx()))
end)
test("9b8 B: a record too long for a frame on its own is not served",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new()
    st.history={{rec="DAa Bb;1",at=HHT},{rec="D"..string.rep("y",251),at=HHT},{rec="DAa Bb;3",at=HHT}}
    local r=HN.records(st,0); eq(#r,2); eq(r[2],"DAa Bb;3")
end)
test("9b8 B: the history keeps the newest 300 records",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new()
    for i=1,301 do HN.carry(st,"eu-pvp;Mira Vale;A;5cy;1;"..b36(HHT)..";DAa Bb;"..i,"Mira Vale","A",1,hctx()) end
    eq(#st.history,300); eq(st.history[1].rec,"DAa Bb;2","the oldest went"); eq(st.history[300].rec,"DAa Bb;301")
end)
test("9b8 B: catch-up serves the newest 10 records that fit, counted exactly in O and the end marker, byte for byte",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new(); peerOf(HN,st,"Asker")
    for i=1,40 do st.history[i]={rec="DAa Bb;"..i,at=HHT} end
    st.history[41]={rec="KCc  Dd;000x;  end",at=HHT}                          -- spaces and padded base 36 kept as sent
    -- (r040c 6c5: at most 10 records, so the pull ends inside HeadHunter's 60 s give-up)
    local o=HN.query(st,"h0","Asker",10,hctx()); eq(o[1].text,"1AO:a","10")
    local s=HN.query(st,"p0","Asker",10,hctx()); local all={}
    for _,f in ipairs(s) do yes(#f.text<=255); all[#all+1]=f.text:sub(5) end
    local body=table.concat(all,"~"); local recs={}; for r in (body.."~"):gmatch("([^~]*)~") do recs[#recs+1]=r end
    eq(#recs,11); eq(recs[11],"E"..HN.b36(10)); eq(recs[10],"KCc  Dd;000x;  end","byte for byte"); eq(recs[1],"DAa Bb;32","the newest 10")
end)
test("9b8 B: a pull gets its own allowance (up to 16 frames, about one per 2 s) inside the public budget; 10 records served",function()
    local N=loadAddon(); hhReady(N,{"Asker One"}); steps(25)
    for i=1,30 do N.Main.hhNet.history[i]={rec="DAa Bb;"..string.rep("x",241)..i,at=server} end   -- (at most 250 bytes: one record a frame, the marker alone)
    hhIn("1AN:HeadHunter 1.1.1","Asker One"); hhIn("1AQ:p"..b36(server-600),"Asker One")
    for _=1,40 do advance(1) end
    local times={}; for _,m in ipairs(hw("1AS:","Asker One")) do times[#times+1]=m.at end
    eq(#times,11,"10 records in 10 frames and the end marker"); for i=2,#times do yes(times[i]-times[i-1]>=2,"paced") end
    local last=hw("1AS:","Asker One"); yes(last[#last].text:find("E"..N.HhNet.b36(10).."$"),last[#last].text)
    -- a requester outside the guild: the pull's frames are not held to 4 a minute, and at most 16 go
    N=loadAddon(); hhReady(N,{}); steps(25)
    for i=1,30 do N.Main.hhNet.history[i]={rec="DAa Bb;"..string.rep("x",241)..i,at=server} end
    hhIn("1AN:HeadHunter 1.1.1","Asker Out"); steps(3)
    for i=1,3 do N.Wire.send("HeadHunter","1AH:"..i,"WHISPER","Asker Out",{net="hh",prio="mesh"}) end   -- their 4 a minute spent
    hhIn("1AQ:p"..b36(server-600),"Asker Out"); for _=1,40 do advance(1) end
    eq(#hw("1AS:","Asker Out"),11)
    -- (r040c 6c5) once the public minute is free again, the allowance of 16 frames per 300 s holds: 5 more, then none
    advance(61); local okC=0
    for i=1,8 do if N.Wire.send("HeadHunter","1AS:x"..i,"WHISPER","Asker Out",{net="hh",prio="catchup",catchup=true}) then okC=okC+1 end; advance(3) end
    eq(okC,5,"16 frames in all, not more")
    -- everything else still keeps 4 a minute to that player
    local Wr=N.Wire; local ok=0; for i=1,6 do if Wr.send("HeadHunter","1AH:"..i,"WHISPER","Asker One",{net="hh",scope="public",prio="mesh"}) then ok=ok+1 end end
    yes(ok<=4,ok)
end)
test("9b8 B: Q:p only from a known peer of our faction; S records from the other faction only of the kinds allowed across",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new(); st.history={{rec="DAa Bb;1",at=HHT}}
    eq(#HN.query(st,"p0","Stranger",10,hctx()),0,"unknown")
    peerOf(HN,st,"Hordie","H"); eq(#HN.query(st,"p0","Hordie",10,hctx(),"H"),0,"other faction")
    peerOf(HN,st,"Friend"); yes(#HN.query(st,"p0","Friend",10,hctx(),"A")>0)
    st=HN.new(); st.pulling={name="Hordie",at=1}
    HN.snapshot(st,"Hordie","DAa Bb;1~UCc Dd;2~KEe Ff;3~E3",hctx(),"H"); eq(#st.history,1); eq(st.history[1].rec,"UCc Dd;2")
end)
test("9b8 B: own lines are never starved by a busy mesh, in or out of combat; embassy and owed lines go before mesh ones",function()
    -- (the mesh peers are guildmates here, so no public cap holds the mesh back: only the shared budgets)
    local function mates() local r={}; for a=1,26 do for b=1,26 do r[#r+1]={"Peer"..abc(a)..abc(b),true} end end; return r end
    for _,fight in ipairs({false,true}) do
        local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh","we"); N.Net.setConsent("public"); combat=fight; roster=mates()
        local okOwn,tries=0,0
        for t=1,120 do
            for i=1,6 do Wr.send("HeadHunter","1AE:x"..t.."."..i,"WHISPER","Peer"..abc(i)..abc(t%26+1),{net="hh",prio="mesh",queue=true}) end
            if t%15==0 then tries=tries+1; if Wr.send("LEGW1","O|1|"..t.."|100|0.250|0.750||1|1|","GUILD",nil,{prio="own"}) then okOwn=okOwn+1 end end
            advance(1)
        end
        eq(okOwn,tries,fight and "in combat" or "out of combat"); combat=false
    end
    -- a burst: mesh lines queued at once leave the shared reserve, so an own line right after goes
    do
        local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh","we"); N.Net.setConsent("public"); roster=mates()
        for i=1,30 do
            local to="Peer"..abc(i%26+1)..abc(math.floor(i/26)+1)
            Wr.send("HeadHunter","1AE:b"..i,"WHISPER",to,{net="hh",prio="mesh",queue=true})
            Wr.send("WEFF1","P|19|789|0|","WHISPER",to,{net="we",prio="embassy",queue=true})
        end
        advance(0.5); yes((Wr.send("LEGW1","O|1|1|100|0.250|0.750||1|1|","GUILD",nil,{prio="own"})),"own after a mesh burst")
    end
    -- Main sends every HeadHunter line as mesh
    do
        local N=loadAddon(); hhReady(N,{"Peer One","Mira Vale"}); steps(25); local prios={}
        local real=N.Wire.send; N.Wire.send=function(p,t,k,tg,o) if p=="HeadHunter" then prios[#prios+1]=o and o.prio end; return real(p,t,k,tg,o) end
        hhIn("1AN:HeadHunter 1.1.1","Peer One"); hhIn(env("Mira Vale",1,server,"DAa Bb;7"),"Mira Vale"); steps(5)
        yes(#prios>0); for _,p in ipairs(prios) do eq(p,"mesh") end
    end
    -- queue order: an owed line and an embassy line queued after mesh lines go first
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh","we"); N.Net.setConsent("public"); roster=mates()
    for i=1,30 do Wr.send("HeadHunter","1AE:m"..i,"WHISPER","Peer"..abc(i%26+1)..abc(math.floor(i/26)+1),{net="hh",prio="mesh",queue=true}) end
    Wr.send("WEFF1","P|19|789|0|","WHISPER","Ann Lee",{net="we",prio="embassy",queue=true})
    local firstP,lastMesh; for _=1,120 do advance(1) end
    for i,m in ipairs(sent) do if m.text=="P|19|789|0|" then firstP=i end; if m.prefix=="HeadHunter" then lastMesh=i end end
    yes(firstP and lastMesh and firstP<lastMesh,"the embassy line before the last mesh line")
end)
test("9b8 B: a forward keeps the timestamp bytes and changes only the hop; a queued forward over 600 s old is dropped",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new(); peerOf(HN,st,"Peer One")
    local out=HN.carry(st,"eu-pvp;Mira Vale;A;05cy;1;0"..b36(HHT)..";DAa Bb;1","Mira Vale","A",1,hctx())
    eq(#out,1); eq(out[1].text,"1AE:eu-pvp;Mira Vale;A;05cy;2;0"..b36(HHT)..";DAa Bb;1"); yes(out[1].still and out[1].still(HHT+600)); no(out[1].still(HHT+601))
    -- through Wire: queued behind a full budget, then too old: not sent
    N=loadAddon(); hhReady(N,{"Peer One","Mira Vale"}); steps(30)
    local Wr=N.Wire; for i=1,4 do Wr.send("HeadHunter","1AH:"..i,"WHISPER","Peer One",{net="hh",scope="public",prio="mesh"}) end
    sent={}; hhIn("1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server-595)..";DAa Bb;9","Mira Vale"); server=server+20; steps(70)
    eq(#hw("1AE:","Peer One"),0,"too old when its turn came")
end)
test("9b8 B: hello replies are paced to one per 2 s; a peer counts as known only if heard within 3600 s",function()
    local N=loadAddon(); hhReady(N,{}); steps(25); sent={}
    for i=1,5 do hhIn("1AN:HeadHunter 1.1.1","Hello"..abc(i)) end
    local times={}; for _=1,15 do advance(1); local n=#hw("1AN:"); while #times<n do times[#times+1]=clock end end
    eq(#times,5); for i=2,#times do yes(times[i]-times[i-1]>=2,"paced") end
    local HN=N.HhNet; local st=HN.new()
    -- three stale peers and three fresh ones: the fresh three are the known ones, a stale one only the discovery pick
    for _,n in ipairs({"Old One","Old Two","Old Three"}) do HN.heard(st,n,"A","eu-pvp",true,0) end
    for _,n in ipairs({"New One","New Two","New Three"}) do HN.heard(st,n,"A","eu-pvp",true,3000) end
    local names=HN.pick(st,3,{},3601,"A","eu-pvp"); eq(#names,4)
    local old=0; for _,n in ipairs(names) do if n:find("^Old") then old=old+1 end end; eq(old,1)
end)

-- مانع on C1 e0d9513 and C2 7a094b2 (r040c/7a0)
test("7a0 C1/C2: one row per enemy whatever the spelling: First-Last and First-Last-7102 fold to one key",function()
    local N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyuser"); advance(1)
    spyIn("[Spy]","1.3.8|Kora-Reed-7102|ROGUE|60|Orc|Ashenvale||0.5|0.6||100","GUILD","Spyuser")
    local rows=spyRows(N,"spy"); eq(#rows,1); eq(rows[1].record.rid,N.Hash.hash3("kora reed")); eq(rows[1].record.enemies[1].hash,N.Hash.hash3("kora reed"))
    spyIn("FSENT03","1~Player-7103-00AB12~Kora-Reed-7102~MAGE~60~Ashenvale~0","RAID","Seuser"); advance(1)
    spyIn("FSENT03","1~Player-7103-00AB12~Kora-Reed~MAGE~60~Ashenvale~0","RAID","Seuser"); eq(#spyRows(N,"sent"),1)
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Kora Reed-7102|60|","GUILD","Victim"); advance(1)
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Kora Reed|60|","GUILD","Victim")
    local w=0; for _,r in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if r.record.src~="spy" and r.record.src~="sent" then w=w+1; eq(r.record.rid,N.Hash.hash3("kora reed")) end end
    eq(w,1)
end)
test("7a0 C1: the zone-name table is kept only when both lookups gave data; otherwise tried again",function()
    local N=loadAddon(); establish(N); local real=C_Map.GetMapChildrenInfo
    C_Map.GetMapChildrenInfo=function(id,kind,all) if id==947 then return nil end return real(id,kind,all) end
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsx")    -- 947 not ready: answered from our continent, not kept
    C_Map.GetMapChildrenInfo=function(id,kind,all) if id==947 then return {{mapID=300,name="Elwynn Forest"}} end return real(id,kind,all) end
    eq(#spyRows(N,"fspy"),1,"answered all the same"); eq(N.Adapters.zoneByName("Elwynn Forest"),300,"the table was built again with 947")
    N=loadAddon(); establish(N); local miss=true
    C_Map.GetMapChildrenInfo=function(id,kind,all) if id==1 and miss then return nil end return real(id,kind,all) end
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsx"); miss=false
    C_Map.GetMapChildrenInfo=function(id,kind,all) if id==1 then return {{mapID=100,name="Ashenvale"},{mapID=400,name="Mulgore"}} end return real(id,kind,all) end
    eq(N.Adapters.zoneByName("Mulgore"),400,"the continent lookup counted too")
end)
test("7a0 C1: the sender in Spy spelling: our own line is refused, and the rate bucket is the folded name",function()
    local N=loadAddon(); establish(N); local realUnitName=UnitName
    _G.UnitName=function(u) if u=="player" then return "Lo Cal","Test Realm" end; return realUnitName(u) end
    for _,s in ipairs({"Lo-Cal","Lo-Cal-7102"}) do
        spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD",s); eq(#spyRows(N,"spy"),0,s)
    end
    _G.UnitName=realUnitName
    local who={"Ann-Lee","Bo-Dyl","Cy-Fen","Di-Gar","Ed-Hal","Fa-Ivo","Gu-Jem"}
    for i=1,7 do spyIn("[Spy]","1.3.8|"..who[i].."|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD",i%2==0 and "Mira-Vale" or "Mira Vale") end
    eq(#spyRows(N,"spy"),6,"two spellings, one bucket")
end)
test("7a0 C1: an ambiguous zone name is no answer whichever map comes first; a C1 row never goes out as our O",function()
    local N=loadAddon(); establish(N)
    C_Map.GetMapChildrenInfo=function() return {{mapID=100,name="Twin"},{mapID=200,name="Twin"}} end
    spyIn("ForeverSpy1","1\tKora Reed\tTwin","PARTY","Fsx"); eq(#spyRows(N,"fspy"),0)
    N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyuser"); eq(#spyRows(N,"spy"),1)
    for _=1,20 do advance(1); N.Main.shareTick() end; eq(#oLines(),0,"not ours")
    foe(N,2); for _=1,5 do advance(1); N.Main.shareTick() end; eq(#oLines(),1,"our own sighting still goes")
end)

-- مانع's 1.0.0 final review (r040c/b5c)
test("b5c d744383: /le share off drops sync answers with our C/E and the reports kept for them",function()
    local N=loadAddon(); weReady(N); roster={{"Wes-TestRealm",true},{"Wesb-TestRealm",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    hello("Wes",19); advance(20)
    foe(N,1,{key="Player-1-801",name="Aa Bb"}); foe(N,2,{key="Player-1-802",name="Cc Dd"}); steps(20); yes(#weSent("C")>=1)
    sent={}; N.WeNet.rand=function() return .5 end
    we("Y|1||a:900"); steps(5)                                    -- queued: a random start 30 s later
    slash("share off"); steps(120); eq(#weTo("Wes"),0,"the waiting answer is dropped")
    eq(#N.Main.we.kept,0,"nothing of ours is kept"); we("Y|1||a:900","GUILD","Wesb"); steps(120); eq(#weTo("Wesb"),0)
    -- the C+E on another route goes no further either
    eq(#weSent("C"),0); eq(#weSent("E"),0)
end)
test("b5c d744383: /le share off drops our own W lines still queued for an embassy partner",function()
    local N=loadAddon(); embReady(N,{"Ann Lee"}); steps(13)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(25); hello("Wes",19)
    for i=1,4 do N.Wire.send("WEFF1","K|"..i.."|2|5","WHISPER","Ann Lee",{net="we",prio="owed"}) end   -- Ann Lee's 4 a minute spent
    local function mine() local n=0; for _,m in ipairs(wh("W|","Ann Lee")) do local d=N.Protocol.decode(m.text); if d and d.origin=="Me" and d.inner.type~="H" then n=n+1 end end; return n end
    foe(N,1); foe(N,2); steps(15); eq(mine(),0,"waiting for the budget"); yes(#weSent("C")>=1,"our C went to the guild"); yes(N.Wire.queued()>0)
    slash("share off"); steps(90); eq(mine(),0,"dropped, not sent")
end)
test("b5c: a hosting blink ends on the next request or F when the guild name is readable and equal; else a roster is asked",function()
    local N=loadAddon(); hReady(N); roster={{"Bob",true}}; advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"                                       -- readable again, but no event or roster says so
    lsw("inv layer <LS 100 want 7086-0>","Bob"); yes(N.Main.host.on,"the request itself re-checks"); eq(#invites,1,"and is answered")
    N=loadAddon(); hReady(N); advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"; eq(hostF(),1,"an F re-checks too")
    -- still unreadable: a roster is asked (through the 15 s limit), hosting stays inactive
    N=loadAddon(); hReady(N); advance(61); guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    local calls=rosterCalls; advance(16); lsw("inv layer <LS 100 want 7086-0>","Bob"); no(N.Main.host.on); eq(#invites,0); eq(rosterCalls,calls+1)
    -- readable but another guild's name: not resumed, nothing acts
    guildName="Guild B"; advance(16); lsw("inv layer <LS 100 want 7086-0>","Bob"); no(N.Main.host.on); eq(#invites,0); guildName="Test Guild"
end)

-- مانع's A3 closing round: field 14 is War Effort's received count, field 15 alone the ambiguity flag
test("A3 close: a hello's received count (field 14) and ambiguity flag (field 15) are read and kept in a rebuilt line",function()
    local N=loadAddon(); local P,W=N.Protocol,N.WeOut
    local h=P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|42|1"); yes(h); eq(h.received,42); eq(h.ambiguous,true)
    eq(W.rebuild(h),"H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|42|1","count and flag kept")
    h=P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|42"); eq(h.received,42); no(h.ambiguous); eq(W.rebuild(h),"H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|42")
    h=P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1||1"); eq(h.received,nil); eq(h.ambiguous,true); eq(W.rebuild(h),"H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1||1")
    h=P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|x|2"); eq(h.received,nil); no(h.ambiguous)
    h=P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|100000000|1"); eq(h.received,nil,"over War Effort's maximum")
    eq(P.decode("H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|99999999").received,99999999)
    -- our own hello still says count 0 with the flag
    eq(W.hello({map=100,layer=7086,class="MAGE",level=60,public=true,ambiguous=true,stamp=110}):sub(-4),"|0|1")
    -- a bridged guild hello through the embassy keeps both (G in)
    local inner="H|1.6.6|100|7086|1|19|0|0|110|456|H|60|1|42|1"
    local g=P.decode("G|"..hx("Kora Reed").."||"..inner); yes(g and g.inner); eq(W.rebuild(g.inner),inner)
end)

-- مانع's lane B closing round (r040c/6c5)
test("6c5 B: a pull's end marker leaves within 60 s of the Q:p even with the public budget saturated by mesh lines",function()
    local N=loadAddon(); hhReady(N,{}); steps(25)
    for i=1,30 do N.Main.hhNet.history[i]={rec="DAa Bb;"..string.rep("x",241)..i,at=server} end
    hhIn("1AN:HeadHunter 1.1.1","Asker Out"); steps(3)
    local Wr=N.Wire; local function mesh(t) for i=1,6 do Wr.send("HeadHunter","1AE:"..t.."."..i,"WHISPER","Meshpeer"..abc(i)..abc(t%26+1),{net="hh",prio="mesh",queue=true}) end end
    for t=1,20 do mesh(t); advance(1) end                    -- a full queue of mesh forwards, the public minute spent
    local q=clock; hhIn("1AQ:p"..b36(server-600),"Asker Out")
    local endAt; for t=1,70 do mesh(t+20); advance(1); for _,m in ipairs(hw("1AS:","Asker Out")) do if m.text:find("~?E%w+$") and m.text:find("E"..N.HhNet.b36(10).."$") then endAt=endAt or m.at end end end
    yes(endAt,"the end marker went"); yes(endAt and endAt-q<=60,"within 60 s: "..tostring(endAt and endAt-q))
    eq(#hw("1AS:","Asker Out"),11)
end)
test("6c5 B: hello replies stay 2 s apart after a backlog (no burst when the budget refills)",function()
    local N=loadAddon(); hhReady(N,{}); netOn(N,"we"); steps(25); local Wr=N.Wire
    -- the public minute spent (20 whispers to players outside the guild)
    local spent,start=0,clock
    while spent<20 and clock-start<60 do
        for _=1,5 do if spent<20 and Wr.send("WEFF1","E|1|1|1|abc:H:60|1","WHISPER","Fill"..abc(spent%26+1)..abc(math.floor(spent/26)+1),{net="we",prio="own"}) then spent=spent+1 end end
        if spent<20 then advance(.5) end
    end
    eq(spent,20)
    sent={}; for i=1,5 do hhIn("1AN:HeadHunter 1.1.1","Hello"..abc(i)) end
    for _=1,120 do advance(1) end
    local times={}; for _,m in ipairs(hw("1AN:")) do times[#times+1]=m.at end
    eq(#times,5,"every reply went"); for i=2,#times do yes(times[i]-times[i-1]>=2,"apart "..(times[i]-times[i-1])) end
end)
test("6c5 B: a peer last heard more than 3600 s ago gets no pull",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new(); st.history={{rec="DAa Bb;1",at=HHT}}
    HN.heard(st,"Old Peer","A","eu-pvp",true,0)
    eq(#HN.query(st,"p0","Old Peer",3601,hctx(),"A"),0,"3601 s")
    HN.heard(st,"New Peer","A","eu-pvp",true,0); yes(#HN.query(st,"p0","New Peer",3600,hctx(),"A")>0,"3600 s: still known")
end)
-- Invalid-whisper lifecycle: synthetic targets, real Wire and event dispatch.
local function whisper(N,target,opts)
    return N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER",target,opts or {net="hh",prio="mesh"})
end
test("invalid-whisper A: accepted API call then localized failure blocks the identity for one hour",function()
    local N=loadAddon(); netOn(N,"hh")
    GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Kein Spieler namens '%s' gefunden."
    yes(whisper(N,"Fable Reed-TestRealm")); eq(#sent,1)
    deliver("CHAT_MSG_SYSTEM","Kein Spieler namens 'Fable Reed' gefunden.")
    clock=clock+61
    local ok,why,attempted=whisper(N,"Fable Reed")
    no(ok,"async failure must block a later API call"); eq(why,"offline"); no(attempted); eq(#sent,1)
    clock=clock+3538; no(whisper(N,"Fable Reed-TestRealm")); eq(#sent,1)
    clock=clock+1; yes(whisper(N,"Fable Reed")); eq(#sent,2)
    no(N.Main.error)
end)
test("invalid-whisper A: exact correlation leaves unknown, ambiguous, unrelated and secret system errors alone",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="No player named '%s' is currently playing."
    local observed={}; local f=CreateFrame("Frame"); f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:SetScript("OnEvent",function(_,_,text) observed[#observed+1]=text end)
    ChatFrame_AddMessageEventFilter=function() forbidden=forbidden+1 end
    yes(whisper(N,"Fable Reed")); clock=clock+3; yes(whisper(N,"Fable Reed-Elsewhere"))
    for _,text in ipairs({"No player named 'Unknown Reed' is currently playing.","No player named 'Fable Reed' is currently playing.",
        "prefix No player named 'Fable Reed-Elsewhere' is currently playing.","No player named 'FableReed' is currently playing.",secret}) do
        deliver("CHAT_MSG_SYSTEM",text)
    end
    eq(#observed,5); no(N.Wire.offlineUntil("Fable Reed",clock)); no(N.Wire.offlineUntil("Fable Reed-Elsewhere",clock))
    deliver("CHAT_MSG_SYSTEM","No player named 'Fable Reed-Elsewhere' is currently playing.")
    eq(#observed,6,"correlated errors remain visible too"); yes(N.Wire.offlineUntil("Fable Reed-Elsewhere",clock))
    no(N.Wire.offlineUntil("Fable Reed",clock)); no(N.Main.error)
    ChatFrame_AddMessageEventFilter=nil
end)
test("invalid-whisper A: localized literals are escaped, unsupported templates fail closed, evidence is consumed",function()
    local N=loadAddon(); netOn(N,"hh")
    yes(whisper(N,"Fable Reed"))
    for _,fmt in ipairs({"%s","%d","%s %s",secret}) do
        ERR_CHAT_PLAYER_NOT_FOUND_S=fmt; deliver("CHAT_MSG_SYSTEM","Fable Reed")
        no(N.Wire.offlineUntil("Fable Reed",clock))
    end
    ERR_CHAT_PLAYER_NOT_FOUND_S=nil; deliver("CHAT_MSG_SYSTEM","No player named 'Fable Reed' is currently playing.")
    no(N.Wire.offlineUntil("Fable Reed",clock))
    ERR_CHAT_PLAYER_NOT_FOUND_S="[Absent]. (%1$s) + 100%%?"
    deliver("CHAT_MSG_SYSTEM","[Absent]X (Fable Reed) + 100%?"); no(N.Wire.offlineUntil("Fable Reed",clock))
    deliver("CHAT_MSG_SYSTEM","[Absent]. (Fable Reed) + 100%?")
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600)
    clock=clock+10; deliver("CHAT_MSG_SYSTEM","[Absent]. (Fable Reed) + 100%?")
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3590,"duplicate failure cannot renew suppression")
end)
test("invalid-whisper A: only recent actual whisper calls supply evidence, never queued or locally refused lines",function()
    local N=loadAddon(); netOn(N,"hh"); ERR_CHAT_PLAYER_NOT_FOUND_S="Missing %s!"
    -- The ledger is capped independently of budget; use a smaller cap to exercise eviction under real budgets.
    N.Wire.RECENT_MAX=2
    yes(whisper(N,"Older Reed")); clock=clock+3; yes(whisper(N,"Middle Reed")); clock=clock+3; yes(whisper(N,"Newest Reed"))
    deliver("CHAT_MSG_SYSTEM","Missing Older Reed!"); no(N.Wire.offlineUntil("Older Reed",clock))
    deliver("CHAT_MSG_SYSTEM","Missing Middle Reed!"); yes(N.Wire.offlineUntil("Middle Reed",clock))
    clock=clock+30; deliver("CHAT_MSG_SYSTEM","Missing Newest Reed!"); no(N.Wire.offlineUntil("Newest Reed",clock))
    N.Net.setSwitch("hh",false); no(whisper(N,"Blocked Reed")); deliver("CHAT_MSG_SYSTEM","Missing Blocked Reed!")
    no(N.Wire.offlineUntil("Blocked Reed",clock)); N.Net.setSwitch("hh",true)
    no(whisper(N,"Bad Reed-PvP 1")); deliver("CHAT_MSG_SYSTEM","Missing Bad Reed-PvP 1!")
    local fn=C_ChatInfo.SendAddonMessage; C_ChatInfo.SendAddonMessage=false
    no(whisper(N,"Absent Reed")); deliver("CHAT_MSG_SYSTEM","Missing Absent Reed!")
    no(N.Wire.offlineUntil("Absent Reed",clock)); C_ChatInfo.SendAddonMessage=fn
    clock=clock+61
    for _=1,4 do yes(whisper(N,"Queued Reed")); clock=clock+3 end
    local ok,why=whisper(N,"Queued Reed",{net="hh",prio="mesh",queue=true}); yes(ok); eq(why,"queued")
    deliver("CHAT_MSG_SYSTEM","Missing Queued Reed!"); yes(N.Wire.offlineUntil("Queued Reed",clock))
    local before=#sent; clock=clock+61; drain(); eq(#hw("1AN:","Queued Reed"),4,"queued line respects offline")
    yes(#sent>=before); eq(N.Wire.queued(),0)
    no(N.Main.error)
end)
test("invalid-whisper A: synchronous offline and async offline share the same bounded window across prefixes",function()
    local N=loadAddon(); netOn(N,"hh","we"); sendResult=12
    local ok,why,attempted=whisper(N,"Fable Reed"); no(ok); eq(why,"offline"); yes(attempted)
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600)
    sendResult=0; clock=clock+61
    ok,why,attempted=N.Wire.send("WEFF1","P|x","WHISPER","Fable Reed",{net="we",prio="embassy"})
    no(ok); eq(why,"offline"); no(attempted); eq(#sent,1)
    for i=1,300 do N.Wire.markOffline("Capped"..abc(i),clock+i/1000) end
    local _,count=N.Wire.sizes(); eq(count,256)
    no(N.Wire.offlineUntil("Fable Reed",clock+1),"oldest evicted when full")
    yes(N.Wire.offlineUntil("Capped"..abc(300),clock+1),"newest retained")
end)
test("invalid-whisper A: outgoing target uses only the existing home-realm canonicalization",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    yes(whisper(N,"Fable Reed-TestRealm")); eq(sent[#sent].target,"Fable Reed","preserve surname, drop only home suffix")
    clock=clock+3; yes(whisper(N,"Fable Reed-7105")); eq(sent[#sent].target,"Fable Reed-7105","foreign numeric realm intact")
    clock=clock+3; yes(whisper(N,"Fable Reed-Elsewhere")); eq(sent[#sent].target,"Fable Reed-Elsewhere")
    no(whisper(N,"Fable Reed-PvP 1")); eq(#sent,3,"no expanded realm grammar")
end)
test("invalid-whisper B: terminal hello results clear owed state and do not starve the next peer",function()
    for _,result in ipairs({12,9,3,secret}) do
        local N=loadAddon(); hhReady(N,{"Amber Ghost","Later Reed"}); sendResult=result
        local attempts={}; local real=N.Wire.send
        N.Wire.send=function(prefix,text,kind,target,opts)
            if prefix=="HeadHunter" and text=="1AN:LayerEnemies" then attempts[#attempts+1]=target end
            return real(prefix,text,kind,target,opts)
        end
        steps(100)
        local count={}; for _,name in ipairs(attempts) do count[name]=(count[name] or 0)+1 end
        eq(count["Amber Ghost"],1,"terminal hello is never re-owed")
        yes(count["Later Reed"] and count["Later Reed"]<=8,"later peer not starved, including a local pause")
        no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer,"no idle retry timer"); no(N.Main.error)
    end
    local N=loadAddon(); hhReady(N,{})
    N.HhNet.roster(N.Main.hhNet,{"Amber Ghost-PvP 1","Later Reed"},"me")
    N.Main.hhHelloPump(); clock=clock+3; N.Main.hhHelloPump()
    no(N.HhNet.owed(N.Main.hhNet)); eq(#hw("1AN:","Later Reed"),1)
end)
test("invalid-whisper B: transient local refusals back off, expire and give other peers a turn",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost","Later Reed"})
    local attempts={}; local real=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if prefix=="HeadHunter" and text=="1AN:LayerEnemies" then
            attempts[#attempts+1]={target=target,at=clock}
            if target=="Amber Ghost" then return false,"throttled",false end
        end
        return real(prefix,text,kind,target,opts)
    end
    steps(200)
    local bad={}; local good
    for _,a in ipairs(attempts) do if a.target=="Amber Ghost" then bad[#bad+1]=a.at else good=good or a.at end end
    yes(good and good-bad[1]<15,"unattempted peer does not wait for an exhausted retry")
    yes(#bad>1 and #bad<=8,"bounded local attempts: "..#bad)
    yes(bad[#bad]-bad[1]<=120,"hard hello deadline")
    yes(bad[#bad]-bad[#bad-1]>=16,"backoff, not a two-second spin")
    no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer)
    local before=#attempts; steps(200); eq(#attempts,before,"refresh does not reset the failed hello")
end)
test("invalid-whisper B: offline evidence cancels an owed hello before another Wire attempt",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost","Later Reed"}); ERR_CHAT_PLAYER_NOT_FOUND_S="Missing %s!"
    -- Spend this target's real per-minute budget, then its hello is locally refused and owed.
    for _=1,4 do yes(whisper(N,"Amber Ghost")); clock=clock+3 end
    N.HhNet.roster(N.Main.hhNet,{"Amber Ghost","Later Reed"},"me")
    N.Main.hhHelloPump(); yes(N.HhNet.owed(N.Main.hhNet))
    deliver("CHAT_MSG_SYSTEM","Missing Amber Ghost!")
    local attempts=0; local real=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if target=="Amber Ghost" and text=="1AN:LayerEnemies" then attempts=attempts+1 end
        return real(prefix,text,kind,target,opts)
    end
    steps(150); eq(attempts,0,"offline peers never reenter Wire's hello path")
    eq(#hw("1AN:","Amber Ghost"),4); eq(#hw("1AN:","Later Reed"),1)
    no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer)
end)
test("invalid-whisper C: successful empty directory is applied by the hello timer, retaining only direct fresh peers",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost","Later Reed"})
    local attempts=0; local real=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if prefix=="HeadHunter" and text=="1AN:LayerEnemies" then attempts=attempts+1; return false,"throttled",false end
        return real(prefix,text,kind,target,opts)
    end
    steps(16); eq(N.Main.hhNet.n,2)
    chanMembers.HeadHunterSync={}; yes(N.Directory.refresh("hh")); steps(3)
    eq(#N.Directory.members("hh"),0)
    -- A timer must apply the new roster itself, without relying on a later heartbeat.
    N.Main.hhHelloPump(); eq(N.Main.hhNet.n,0,"fresh empty roster evicts directory-only peers")
    local before=attempts; steps(15); eq(attempts,before); no(N.HhNet.owed(N.Main.hhNet))
    N.HhNet.heard(N.Main.hhNet,"Direct Reed","A","eu-pvp",false,clock)
    yes(N.Directory.refresh("hh")); steps(3); N.Main.hhTick()
    eq(N.Main.hhNet.n,1,"fresh incoming identity is not directory-only")
end)
test("invalid-whisper C: failed or blocked roster reads are not empty success and old candidates expire",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost"}); steps(16)
    local D,H,st=N.Directory,N.HhNet,N.Main.hhNet
    eq(st.n,1); local snapshot,at=D.members("hh"); yes(at,"snapshot has a success timestamp")
    local read=C_ChatInfo.GetChannelRosterInfo
    C_ChatInfo.GetChannelRosterInfo=function() return nil end
    yes(D.refresh("hh")); steps(3); eq(D.members("hh"),nil,"partial unreadable scan, not an empty list")
    eq(st.n,1,"failed read is not authoritative eviction")
    C_ChatInfo.GetChannelRosterInfo=read; combat=true
    clock=at+599; N.Main.hhTick(); eq(st.n,1)
    clock=at+600; N.Main.hhHelloPump(); eq(st.n,0,"directory-only peer expires without a successful refresh")
    eq(#H.pick(st,3,{},clock,"A","eu-pvp"),0)
    -- A cache retained by a skipped read also expires, rather than getting a fresh timestamp on each poll.
    combat=false; yes(D.refresh("hh")); steps(3); N.Main.hhTick(); snapshot,at=D.members("hh"); yes(snapshot)
    combat=true; clock=at+600; eq(D.members("hh"),nil); eq(D.count("hh"),nil); N.Main.hhTick(); eq(st.n,0)
    no(N.Main.error)
end)
test("invalid-whisper C: valid fresh roster and incoming evidence replace spelling, never compact-key identity",function()
    local N=loadAddon(); GetNormalizedRealmName=nil; local H=N.HhNet; local st=H.new()
    H.roster(st,{"Fable Reed-TestRealm"},"me",clock)
    H.roster(st,{"fable reed"},"me",clock+1)
    eq(H.nextHello(st,clock+1,"A"),"fable reed","fresh roster spelling replaces original")
    H.heard(st,"Fable Reed","A","eu-pvp",false,clock+2)
    eq(st.peers.fablereed.name,"Fable Reed","fresh incoming spelling replaces roster spelling")
    H.heard(st,"Fable Reed-PvP 1","A",nil,true,clock+3)
    eq(st.peers.fablereed.name,"Fable Reed","invalid evidence cannot replace a target")
    H.roster(st,{"Fable Reed-Elsewhere"},"me",clock+4)
    eq(st.peers.fablereed.name,"Fable Reed-Elsewhere","foreign suffix preserved")
    no(st.peers.fablereed.heardAt,"foreign namesake does not inherit our peer's activity")
    eq(H.nextHello(st,clock+4,"A"),"Fable Reed-Elsewhere","foreign namesake has separate hello accounting")
    H.roster(st,{"Fable Reed","Fable Reed-Elsewhere"},"me",clock+5)
    eq(st.n,0,"ambiguous compact directory key is not a send target")
    H.roster(st,{"Fable Reed-PvP 1","Fable  Reed","Fable Reed"},"me",clock+6)
    eq(st.n,1); eq(st.peers.fablereed.name,"Fable Reed")
end)
test("invalid-whisper C: cached directory does not overwrite a newer incoming spelling or renew candidate age",function()
    local N=loadAddon(); hhReady(N,{"fable reed"}); steps(16)
    N.HhNet.heard(N.Main.hhNet,"Fable Reed","A","eu-pvp",false,clock)
    local heard=clock
    N.Main.hhTick(); eq(N.Main.hhNet.peers.fablereed.name,"Fable Reed","same snapshot not reapplied")
    combat=true; clock=heard+601; N.Main.hhTick(); eq(N.Main.hhNet.n,1,"directly heard peer survives directory expiry")
    clock=heard+3601; N.Main.hhTick(); eq(N.Main.hhNet.n,0,"old incoming peer also expires")
end)
test("invalid-whisper C: queued directory-selected queries cannot outlive an empty or expired snapshot",function()
    for _,empty in ipairs({true,false}) do
        local N=loadAddon(); hhReady(N,{"Amber Ghost"}); steps(16)
        for _=1,3 do clock=clock+3; yes(whisper(N,"Amber Ghost")) end
        N.Main.hhTick(); yes(N.Wire.queued()>0,"query waits for the real target budget")
        eq(#hw("1AQ:h","Amber Ghost"),0)
        if empty then
            chanMembers.HeadHunterSync={}; yes(N.Directory.refresh("hh")); steps(65)
        else
            combat=true; clock=clock+610; N.Main.hhTick(); drain()
        end
        eq(#hw("1AQ:h","Amber Ghost"),0,"stale queued candidate never reaches the API")
        eq(N.Wire.queued(),0)
    end
end)
test("invalid-whisper B: retry attempts and deadline are independently bounded; terminal reasons are not retryable",function()
    local N=loadAddon(); local H=N.HhNet
    for _,why in ipairs({"bad text","offline","refused","error","network off","stand down","no consent","instance","queue full"}) do
        local st=H.new(); H.roster(st,{"Fable Reed"},"me",clock)
        eq(H.nextHello(st,clock,"A"),"Fable Reed"); H.unsent(st,"Fable Reed",why,false,clock)
        no(H.owed(st),why)
    end
    for _,rule in ipairs({"attempts","deadline"}) do
        local st=H.new(); H.roster(st,{"Fable Reed"},"me",clock)
        H.HELLO_TRIES=rule=="attempts" and 8 or 1000; H.HELLO_BACKOFF=2
        local tries=0
        for t=clock,clock+150,2 do
            local target=H.nextHello(st,t,"A")
            if target then tries=tries+1; H.unsent(st,target,"throttled",false,t) end
        end
        if rule=="attempts" then eq(tries,8) else eq(tries,60) end
        no(H.owed(st),rule)
    end
end)
test("invalid-whisper B: switching off cancels pending retries and switching on does not strand the timer",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost"}); local calls=0; local real=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if prefix=="HeadHunter" and text=="1AN:LayerEnemies" then
            calls=calls+1; if calls<3 then return false,"throttled",false end
        end
        return real(prefix,text,kind,target,opts)
    end
    steps(16); yes(N.HhNet.owed(N.Main.hhNet)); local before=calls
    N.Net.setSwitch("hh",false); steps(10); eq(calls,before)
    N.Net.setSwitch("hh",true); steps(30)
    eq(#hw("1AN:","Amber Ghost"),1); no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer)
end)
test("invalid-whisper B: async offline clears owed state immediately without consuming a timer turn",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost"}); ERR_CHAT_PLAYER_NOT_FOUND_S="Missing %s!"
    for _=1,4 do yes(whisper(N,"Amber Ghost")); clock=clock+3 end
    N.HhNet.roster(N.Main.hhNet,{"Amber Ghost"},"me",clock); N.Main.hhHelloPump()
    yes(N.HhNet.owed(N.Main.hhNet)); yes(N.Main.hhHelloTimer)
    deliver("CHAT_MSG_SYSTEM","Missing Amber Ghost!")
    no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer)
end)
test("invalid-whisper A: queued-only evidence and backward clocks cannot mark a target offline",function()
    local N=loadAddon(); netOn(N,"hh"); ERR_CHAT_PLAYER_NOT_FOUND_S="Missing %s!"
    for i=1,5 do yes(whisper(N,"Filler"..abc(i))) end
    local ok,why,attempted=whisper(N,"Unsent Reed",{net="hh",prio="mesh",queue=true})
    yes(ok); eq(why,"queued"); no(attempted); eq(#sent,5)
    deliver("CHAT_MSG_SYSTEM","Missing Unsent Reed!"); no(N.Wire.offlineUntil("Unsent Reed",clock))
    clock=clock-1; deliver("CHAT_MSG_SYSTEM","Missing Fillera!"); no(N.Wire.offlineUntil("Fillera",clock))
    N.Net.setSwitch("hh",false); clock=clock+61; drain(); eq(#sent,5); eq(N.Wire.queued(),0)
end)
test("invalid-whisper C: queued envelope forwards recheck an empty directory as well as envelope age",function()
    local N=loadAddon(); hhReady(N,{"Amber Ghost"}); steps(16)
    for _=1,3 do clock=clock+3; yes(whisper(N,"Amber Ghost")) end
    hhIn(env("Origin Reed",1,server,"DAa Bb;77",N.Main.hhWorld()),"Origin Reed")
    yes(N.Wire.queued()>0); eq(#hw("1AE:","Amber Ghost"),0)
    chanMembers.HeadHunterSync={}; yes(N.Directory.refresh("hh")); steps(65)
    eq(#hw("1AE:","Amber Ghost"),0,"empty snapshot invalidates an otherwise young envelope's target")
end)
test("invalid-whisper B: an opposite-faction hello keeps its one-reply behavior without an idle debt",function()
    local N=loadAddon(); hhReady(N,{}); steps(16)
    hhIn("1HN:HeadHunter 1.1.1","Foreign Reed"); steps(200)
    no(N.HhNet.owed(N.Main.hhNet)); no(N.Main.hhHelloTimer)
    eq(#hw("1AN:","Foreign Reed"),1,"existing direct hello reply behavior is unchanged")
end)
test("invalid-whisper B: a new peer outranks a due retry on the same paced turn",function()
    local N=loadAddon(); local H=N.HhNet; local st=H.new()
    H.roster(st,{"Amber Ghost","Later Reed"},"me",clock)
    eq(H.nextHello(st,clock,"A"),"Amber Ghost")
    H.unsent(st,"Amber Ghost","throttled",false,clock)
    eq(H.nextHello(st,clock+2,"A"),"Later Reed")
end)
test("invalid-whisper R2: consumed foreign async evidence still makes a bare namesake error ambiguous",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
    yes(whisper(N,"Fable Reed")); clock=clock+3
    yes(whisper(N,"Fable Reed-7105")); eq(#sent,2); clock=clock+1
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    no(N.Wire.offlineUntil("Fable Reed",clock),"ambiguous before consumption")
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
    local untilAt=N.Wire.offlineUntil("Fable Reed-7105",clock); eq(untilAt,clock+3600)
    clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    no(N.Wire.offlineUntil("Fable Reed",clock),"consumed foreign identity still makes a bare error ambiguous")
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
    eq(N.Wire.offlineUntil("Fable Reed-7105",clock),untilAt,"consumed evidence cannot renew suppression")
    clock=clock+61
    local ok,why,attempted=whisper(N,"Fable Reed")
    yes(ok); eq(why,"sent"); yes(attempted); eq(#sent,3); no(N.Main.error)
end)
test("invalid-whisper R2: synchronous foreign offline retains ambiguity without renewing suppression",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
    yes(whisper(N,"Fable Reed")); clock=clock+3; sendResult=12
    local ok,why,attempted=whisper(N,"Fable Reed-7105")
    no(ok); eq(why,"offline"); yes(attempted); eq(#sent,2)
    local untilAt=N.Wire.offlineUntil("Fable Reed-7105",clock); eq(untilAt,clock+3600)
    sendResult=0; clock=clock+1
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
    eq(N.Wire.offlineUntil("Fable Reed-7105",clock),untilAt,"sync evidence cannot renew suppression")
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    no(N.Wire.offlineUntil("Fable Reed",clock),"consumed synchronous evidence still makes a bare error ambiguous")
    clock=clock+61; ok,why,attempted=whisper(N,"Fable Reed")
    yes(ok); eq(why,"sent"); yes(attempted); eq(#sent,3); no(N.Main.error)
end)
test("invalid-whisper R2: repeated failures consume every matching attempt without extending the hour",function()
    for _,sync in ipairs({false,true}) do
        local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
        ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
        yes(whisper(N,"Fable Reed")); clock=clock+3
        sendResult=sync and 12 or 0
        local ok,why,attempted=whisper(N,"Fable Reed-TestRealm")
        eq(ok,not sync); eq(why,sync and "offline" or "sent"); yes(attempted); eq(#sent,2)
        if not sync then clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].") end
        local untilAt=N.Wire.offlineUntil("Fable Reed",clock); eq(untilAt,clock+3600)
        sendResult=0
        for _=1,8 do
            clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [fable reed-TestRealm].")
            eq(N.Wire.offlineUntil("Fable Reed",clock),untilAt,"no renewal from either consumed attempt")
        end
        clock=untilAt-1; no(whisper(N,"Fable Reed")); eq(#sent,2)
        clock=untilAt; yes(whisper(N,"Fable Reed")); eq(#sent,3,"suppression expires at its original deadline")
        clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
        eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600,"a new actual send supplies fresh evidence")
        no(N.Main.error)
    end
end)
test("invalid-whisper R2: consumed ambiguity expires at the original send timestamp, not failure time",function()
    for _,sync in ipairs({false,true}) do
        local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
        ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
        local sentAt=clock; sendResult=sync and 12 or 0
        local ok,why,attempted=whisper(N,"Fable Reed-7105")
        eq(ok,not sync); eq(why,sync and "offline" or "sent"); yes(attempted)
        sendResult=0; clock=clock+3; yes(whisper(N,"Fable Reed")); eq(#sent,2)
        if not sync then clock=clock+7; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].") end
        local untilAt=N.Wire.offlineUntil("Fable Reed-7105",clock); yes(untilAt)
        clock=sentAt+29.99; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
        no(N.Wire.offlineUntil("Fable Reed",clock),"consumed namesake still ambiguous before 30 seconds")
        deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
        eq(N.Wire.offlineUntil("Fable Reed-7105",clock),untilAt)
        clock=sentAt+30; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
        eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600,"expired foreign evidence no longer blocks a recent home match")
        no(N.Main.error)
    end
end)
test("invalid-whisper R2: consumed records count toward the same recent cap and oldest records are evicted",function()
    for _,sync in ipairs({false,true}) do
        local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
        ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
        eq(N.Wire.RECENT_MAX,64); eq(N.Wire.RECENT_WINDOW,30)
        -- Reduce only the ledger cap to exercise its overflow within the unchanged send budgets.
        N.Wire.RECENT_MAX=2
        yes(whisper(N,"Oldest Reed"))
        for _,name in ipairs({"Fable Reed-7105","Newest Reed"}) do
            clock=clock+3; sendResult=sync and 12 or 0
            local ok,why,attempted=whisper(N,name)
            eq(ok,not sync); eq(why,sync and "offline" or "sent"); yes(attempted)
            if not sync then deliver("CHAT_MSG_SYSTEM","Absent ["..name.."].") end
            yes(N.Wire.offlineUntil(name,clock))
        end
        eq(#sent,3); deliver("CHAT_MSG_SYSTEM","Absent [Oldest Reed].")
        no(N.Wire.offlineUntil("Oldest Reed",clock),"consumed entries are bounded with active entries, not deleted or uncapped")
        sendResult=0; clock=clock+3; yes(whisper(N,"Latest Reed"))
        deliver("CHAT_MSG_SYSTEM","Absent [Latest Reed].")
        eq(N.Wire.offlineUntil("Latest Reed",clock),clock+3600,"newest evidence admitted at capacity")
        no(N.Main.error)
    end
end)
test("invalid-whisper R2: offline-cap eviction does not revive consumed evidence",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
    yes(whisper(N,"Fable Reed")); deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    yes(N.Wire.offlineUntil("Fable Reed",clock))
    for i=1,256 do clock=clock+.01; N.Wire.markOffline("Capped"..abc(i),clock) end
    local _,count=N.Wire.sizes(); eq(count,256)
    no(N.Wire.offlineUntil("Fable Reed",clock),"oldest suppression evicted")
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    no(N.Wire.offlineUntil("Fable Reed",clock),"consumed evidence cannot recreate an evicted suppression")
    clock=clock+3; yes(whisper(N,"Fable Reed")); eq(#sent,2)
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600,"new actual send may suppress again")
    _,count=N.Wire.sizes(); eq(count,256); no(N.Main.error)
end)
test("invalid-whisper R2: an unsent queued foreign namesake is not ambiguity evidence",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
    yes(whisper(N,"Fable Reed")); for i=1,4 do yes(whisper(N,"Filler"..abc(i))) end
    local ok,why,attempted=whisper(N,"Fable Reed-7105",{net="hh",prio="mesh",queue=true})
    yes(ok); eq(why,"queued"); no(attempted); eq(#sent,5); eq(N.Wire.queued(),1)
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
    no(N.Wire.offlineUntil("Fable Reed-7105",clock),"queue insertion never supplies actual-send evidence")
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600,"an unsent namesake cannot prevent correlation")
    N.Net.setSwitch("hh",false); clock=clock+61; drain()
    eq(#sent,5); eq(N.Wire.queued(),0); no(N.Main.error)
end)
test("invalid-whisper R2: a dequeued foreign failure retains ambiguity for home sends and queued work",function()
    for _,sync in ipairs({false,true}) do
        local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
        ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
        yes(whisper(N,"Fable Reed")); for i=1,4 do yes(whisper(N,"Filler"..abc(i))) end
        local opts={net="hh",prio="mesh",queue=true}
        local ok,why,attempted=whisper(N,"Fable Reed-7105",opts)
        yes(ok); eq(why,"queued"); no(attempted); eq(#sent,5)
        ok,why,attempted=whisper(N,"Fable Reed",opts)
        yes(ok); eq(why,"queued"); no(attempted); eq(N.Wire.queued(),2)
        clock=clock+3; sendResult=sync and 12 or 0; drain()
        eq(#hw("1AN:","Fable Reed-7105"),1,"foreign line actually dequeued")
        eq(#hw("1AN:","Fable Reed"),1,"home line still waiting for prefix budget"); eq(N.Wire.queued(),1)
        if not sync then deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].") end
        yes(N.Wire.offlineUntil("Fable Reed-7105",clock)); sendResult=0
        clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
        no(N.Wire.offlineUntil("Fable Reed",clock),"dequeued consumed evidence is still ambiguous")
        clock=clock+2; drain()
        eq(#hw("1AN:","Fable Reed"),2,"home queued work is not falsely suppressed"); eq(N.Wire.queued(),0)
        clock=clock+61; yes(whisper(N,"Fable Reed")); eq(#hw("1AN:","Fable Reed"),3)
        no(N.Main.error)
    end
end)
test("invalid-whisper R2: a qualified home error still matches beside a consumed foreign identity",function()
    local N=loadAddon(); netOn(N,"hh"); GetNormalizedRealmName=nil
    ERR_CHAT_PLAYER_NOT_FOUND_S="Absent [%s]."
    yes(whisper(N,"Fable Reed")); clock=clock+3; yes(whisper(N,"Fable Reed-7105"))
    deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed-7105].")
    local untilAt=N.Wire.offlineUntil("Fable Reed-7105",clock); yes(untilAt)
    clock=clock+1; deliver("CHAT_MSG_SYSTEM","Absent [Fable Reed].")
    no(N.Wire.offlineUntil("Fable Reed",clock))
    deliver("CHAT_MSG_SYSTEM","Absent [fable reed-TestRealm].")
    eq(N.Wire.offlineUntil("Fable Reed",clock),clock+3600,"qualified local suffix is not ambiguous")
    eq(N.Wire.offlineUntil("Fable Reed-7105",clock),untilAt); no(N.Main.error)
end)
-- Own-identity regression: invented player names only, real module and event paths.
local function ownShape(first,second,home)
    local old=UnitName
    UnitName=function(u) if u=="player" then return first,second end; return old(u) end
    GetNormalizedRealmName=nil
    GetRealmName=function() return home end
end
local function ownReport(hash)
    local stamp=math.floor(server)%3600
    return "C|87|100|0.400|0.500|7086|1|"..stamp,"E|87|1|1|"..hash..":D:47|"..stamp
end
test("own identity: split direct self C/E is refused while local and independent Unknown rows survive",function()
    local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
    units.target={guid="Player-1-777",player=true,name="Cedar",realm="Vale",class="ROGUE",level=47,faction="Horde"}
    deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    local h=N.Hash.player("Cedar","Vale"); local c,e=ownReport(h)
    for _,text in ipairs({c,e}) do deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD","Fable Reed") end
    eq(#N.Store.rows(N.Main.store,clock,"reported"),0,"self must not become a reported Unknown")
    eq(N.Main.lastDrop,"own echo"); yes(N.Main.isMe("Fable Reed")); eq(N.Main.weName(),"Fable Reed")
    local seen=N.Store.rows(N.Main.store,clock,"seen"); eq(#seen,1); eq(seen[1].displayName,"Cedar Vale")
    for _,text in ipairs({c,e}) do deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD","Other Scout") end
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].reporter,"Other Scout")
    eq(rows[1].name,"Unknown"); eq(rows[1].class,"ROGUE"); eq(rows[1].level,47)
    yes(rows[1].possible:find("Cedar-Vale",1,true)); eq(#N.Store.rows(N.Main.store,clock,"seen"),1)
    N.Main.store.identities[h]["Birch-Grove"]=clock
    rows=N.Store.rows(N.Main.store,clock,"reported"); eq(rows[1].name,"Unknown")
    yes(rows[1].possible:find("Cedar-Vale",1,true)); yes(rows[1].possible:find("Birch-Grove",1,true)); no(N.Main.error)
end)
test("own identity: split and combined forms share exact full-name and home-realm keys",function()
    for _,shape in ipairs({{"Fable","Reed"},{"Fable Reed"},{"Fable Reed",""},{"Fable Reed","Reed"},
        {"Fable Reed","8123"},{"Fable Reed-8123","8123"}}) do
        local N=loadAddon(); ownShape(shape[1],shape[2],"8123")
        eq(N.Main.weName(),"Fable Reed","canonical own name")
        for _,name in ipairs({"Fable Reed","fable reed","Fable Reed-8123"}) do
            yes(N.Main.isMe(name),name); local ok,why=N.Adapters.policy("WEFF1","GUILD",name)
            no(ok,name); eq(why,"own echo")
        end
        for _,name in ipairs({"Fable","Fable Other","Fable Reed-8124","Fable Reed-Elsewhere"}) do
            no(N.Main.isMe(name),name); yes(N.Adapters.policy("WEFF1","GUILD",name),name)
        end
    end
    local N=loadAddon(); ownShape("Fable Reed","Home Realm","Home Realm")
    GetNormalizedRealmName=function() return "HomeRealm" end
    eq(N.Main.weName(),"Fable Reed"); yes(N.Main.isMe("Fable Reed-HomeRealm")); no(N.Main.isMe("Fable Reed-Away"))
    N=loadAddon(); ownShape("Fable","8123","8123")
    eq(N.Main.weName(),"Fable"); yes(N.Main.isMe("Fable-8123")); no(N.Main.isMe("Fable-8124"))
end)
test("own identity: unreadable or ambiguous own data fails closed and recovers without stale aliases",function()
    local cases={{nil,"Reed","8123"},{secret,"Reed","8123"},{"Fable",secret,"8123"},
        {"Fable Reed",secret,"8123"},{"Fable","Reed",nil},{"Fable","Reed",secret},
        {"Fable","Reed","Reed"},{"Fable","rEEd","Reed"},{"Fable Reed","Other","8123"},
        {"Fable",false,"8123"},{"Fable Reed",123,"8123"},{"Fable  Reed",nil,"8123"},
        {"Fable Reed-8124",nil,"8123"},{"Fable","Reed-8123","8123"},{"Fable","Reed-8124","8123"}}
    for _,shape in ipairs(cases) do
        local N=loadAddon(); ownShape(shape[1],shape[2],shape[3])
        eq(N.Main.weName(),nil,"unavailable identity")
        no(N.Main.isMe("Fable")); no(N.Main.isMe("Fable Reed"))
        local ok,why=N.Adapters.policy("WEFF1","GUILD","Other Scout"); no(ok); eq(why,"own identity unavailable")
        ownShape("Fable","Reed","8123"); yes(N.Main.isMe("Fable Reed")); no(N.Main.isMe("Fable"))
    end
    local N=loadAddon(); ownShape("Fable","Reed","8123")
    UnitName=function() error("unavailable") end
    eq(N.Main.weName(),nil); no(N.Adapters.policy("WEFF1","GUILD","Other Scout"))
    ownShape("Fable","Reed","8123"); GetRealmName=function() error("unavailable") end
    eq(N.Main.weName(),nil); no(N.Adapters.policy("WEFF1","GUILD","Other Scout"))
    ownShape("Fable Reed","Reed","Reed"); eq(N.Main.weName(),"Fable Reed","complete name removes surname/realm ambiguity")
end)
for _,wrapper in ipairs({{kind="G",route="GUILD"},{kind="X",route="PARTY"},{kind="X",route="RAID"},{kind="W",route="WHISPER"}}) do
    test("own identity: "..wrapper.kind.."/"..wrapper.route.." rejects self origins, not different surnames or realms",function()
        for _,origin in ipairs({"Fable Reed","Fable Reed-TestRealm","Fable Other","Fable Reed-Elsewhere"}) do
            local N=loadAddon()
            if wrapper.kind=="W" then
                embReady(N,{"Other Scout"}); steps(13)
                deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Other Scout"); drain()
                yes(N.WeEmb.partner(N.Main.emb,"Other Scout",clock),"live partner")
            else establish(N) end
            ownShape("Fable","Reed","Test Realm")
            local c,e=ownReport("abc")
            for _,text in ipairs({c,e}) do
                local line=N.WeOut.wrap(wrapper.kind,origin,nil,text); yes(line)
                deliver("CHAT_MSG_ADDON","WEFF1",line,wrapper.route,"Other Scout")
            end
            local mine=origin=="Fable Reed" or origin=="Fable Reed-TestRealm"
            eq(#N.Store.rows(N.Main.store,clock,"reported"),mine and 0 or 1,origin)
            if mine then yes(N.Main.lastDrop:find("own echo",1,true)) end
            no(N.Main.error)
        end
    end)
end
test("own identity: distinct first-only names, surnames and foreign realms remain real direct reporters",function()
    for _,origin in ipairs({"Fable","Fable Other","Fable Reed-8124","Fable Reed-Elsewhere"}) do
        local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
        local c,e=ownReport("abc")
        for _,text in ipairs({c,e}) do deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD",origin) end
        local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1,origin)
        eq(rows[1].reporter,origin); eq(rows[1].name,"Unknown"); no(N.Main.error)
    end
end)
test("own identity: LEGW1 refuses our sender and relayed origin without suppressing independent reports",function()
    for _,origin in ipairs({"Fable Reed","Fable Reed-8123","Fable Other","Fable Reed-8124"}) do
        local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
        local line=N.Relay.encode(weRec(N,{origin=origin,heard=clock,age=0}),clock); yes(line)
        deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Other Scout")
        local mine=origin=="Fable Reed" or origin=="Fable Reed-8123"
        eq(N.Safe.count(N.Main.store.reports),mine and 0 or 1,origin)
        N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
        local own=N.Relay.ownLine({rid=1,zone=100,layer="7086",count=1,enemies={{name="Cedar Vale",class="ROGUE",level=47}}}); yes(own)
        deliver("CHAT_MSG_ADDON","LEGW1",own,"GUILD",origin)
        eq(#N.Store.rows(N.Main.store,clock,"reported"),mine and 0 or 1,origin); no(N.Main.error)
    end
end)
test("own identity: unknown identity refuses LEGW1 reports, control and LFSw claims",function()
    for _,shape in ipairs({{nil,"Reed","8123"},{"Fable",secret,"8123"},{"Fable","Reed","Reed"},{"Fable","Reed",nil}}) do
        local N=loadAddon(); establish(N); ownShape(shape[1],shape[2],shape[3])
        local line=N.Relay.encode(weRec(N,{origin="Fable Reed",heard=clock,age=0}),clock); yes(line)
        deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Other Scout")
        local own=N.Relay.ownLine({rid=1,zone=100,layer="7086",count=1,enemies={{name="Cedar Vale"}}}); yes(own)
        deliver("CHAT_MSG_ADDON","LEGW1",own,"GUILD","Other Scout")
        eq(#N.Store.rows(N.Main.store,clock,"reported"),0,"unknown is not a different player")
        deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Other Scout")
        deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD","Other Scout")
        eq(next(N.Main.heard.heard),nil); eq(next(N.Main.guildLines),nil); eq(#sent,0); no(N.Main.error)
    end
end)
test("own identity: HeadHunter and Spy receive gates use the same split full name",function()
    local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
    server=HHT
    local fight="P2s;"..b36(server)..";dw;6y;a1"
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:"..fight:sub(2),"PARTY","Fable Reed-8123")
    eq(N.Main.lastDrop,"own echo"); eq(#N.Store.rows(N.Main.store,clock,"reported"),0)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Fable Reed;A;5cy;1;"..b36(server)..";"..fight,"WHISPER","Other Scout")
    eq(N.Main.lastDrop,"own echo"); eq(#N.Store.rows(N.Main.store,clock,"reported"),0)
    deliver("CHAT_MSG_ADDON","[Spy]","1.3.8|Cedar-Vale|ROGUE|47|Orc|Ashenvale||0.4|0.6||100","GUILD","Fable-Reed")
    eq(N.Main.lastDrop,"own echo"); eq(#N.Store.rows(N.Main.store,clock,"reported"),0)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:"..fight:sub(2),"PARTY","Fable Other")
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1); no(N.Main.error)
end)
test("own identity: host self key and candidate lists use the full identity",function()
    local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
    eq(N.Main.hostOwn().self,"fable reed")
    LayerSwapDB={book={}}
    for _,name in ipairs({"Fable Reed","Fable Reed-8123","Fable","Fable Other","Fable Reed-8124"}) do
        LayerSwapDB.book[name]={layer="9000-1",zone=100,at=wall,host=true}
    end
    local rows=N.Main.candidates(); eq(#rows,3)
    local keys={}; for _,r in ipairs(rows) do keys[r.short]=true end
    yes(keys.fable); yes(keys["fable other"]); yes(keys["fable reed-8124"]); no(keys["fable reed"])
    ownShape("Fable",secret,"8123")
    eq(N.Main.hostOwn().self,nil); rows=N.Main.candidates(); eq(#rows,0)
end)
test("own identity: Directory excludes only the full own identity and refuses unknown identity",function()
    local N=loadAddon(); ownShape("Fable","Reed","8123"); netOn(N,"hh"); N.Net.setConsent("public")
    chanMembers.HeadHunterSync={"Fable Reed","Fable Reed-8123","Fable","Fable Other","Fable Reed-8124"}
    advance(10); advance(3.1)
    local list=N.Directory.members("hh"); yes(list,"directory read"); eq(#list,3)
    local keys={}; for _,name in ipairs(list) do keys[N.Invite.key(name)]=true end
    yes(keys.fable); yes(keys["fable other"]); yes(keys["fable reed-8124"]); no(keys["fable reed"])
    ownShape("Fable",secret,"8123"); yes(N.Directory.refresh("hh")); advance(3.1); eq(N.Directory.members("hh"),nil)
end)
test("own identity: LayerSwap heard and guild claim readers use our full name, never a bare-first alias",function()
    local N=loadAddon(); establish(N); ownShape("Fable","Reed","8123")
    N.Main.hop.pending={name="Other Scout",short="other scout",at=clock,layer="9000"}
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Fable|9000-1|100|h","WHISPER","Other Scout")
    eq(next(N.Main.heard.heard),nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Fable Reed|9000-1|100|h","WHISPER","Other Scout")
    yes(N.Main.heard.heard["Other Scout"])
    N.Main.hop.guildAsk={at=clock,sent=true}; N.Main.heard.heard={}
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Fable","GUILD","Other Scout")
    eq(N.Main.hop.guildAsk.answered,nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Fable Reed|9000-1|100|h","GUILD","Other Scout")
    yes(N.Main.heard.heard["Other Scout"]); yes(N.Main.hop.guildAsk.answered["other scout"])
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Fable Reed","GUILD","Another Scout")
    yes(N.Main.hop.guildAsk.answered["another scout"])
    ownShape("Fable",secret,"8123"); N.Main.hop.guildAsk.answered=nil; N.Main.heard.heard={}
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Fable","GUILD","Other Scout")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Fable Reed|9000-1|100|h","WHISPER","Other Scout")
    eq(N.Main.hop.guildAsk.answered,nil); eq(next(N.Main.heard.heard),nil); no(N.Main.error)
end)
test("own identity: our split-name raid unit is not mistaken for an outside-guild peer",function()
    local N=loadAddon(); weReady(N); ownShape("Fable","Reed","8123")
    raid,grouped=true,true
    units.raid1=player("Fable","Alliance"); units.raid1.realm="Reed"
    local old=UnitIsUnit
    UnitIsUnit=function(u,v) return (u=="raid1" and v=="player") or old(u,v) end
    sent={}; N.Main.weHello("test")
    eq(sentCount("WEFF1","RAID"),0,"our own unit does not need a group hello")
    units.raid2=player("Other Scout","Alliance"); units.raid2.realm="8124"
    N.Main.weHello("test")
    eq(sentCount("WEFF1","RAID"),1,"a real outsider still gets the existing hello")
    no(N.Main.error)
end)
test("own identity: a guild host does not act while its own identity is unreadable or ambiguous",function()
    for _,shape in ipairs({{nil,"Reed","8123"},{"Fable",secret,"8123"},{"Fable","Reed","Reed"}}) do
        local N=loadAddon(); hReady(N); roster={{"Other Scout",true}}
        ownShape(shape[1],shape[2],shape[3])
        lsw("inv layer <LS 100 want 7086-0>","Other Scout")
        eq(#invites,0,"unknown own identity must not invite"); eq(#sent,0,"or answer the request")
        ownShape("Fable","Reed","8123")
        lsw("inv layer <LS 100 want 7086-0>","Other Scout")
        eq(#invites,1,"readable identity recovers without consuming the earlier request"); no(N.Main.error)
    end
end)
-- Guild O uses the observed display identity, not an alias reconstructed from metadata.
test("guild O full name: split and combined observations round-trip without first-name aliases",function()
    local N=loadAddon(); local R=N.Relay
    for _,e in ipairs({{name="Cedar",realm="Vale",displayName="Cedar Vale",class="ROGUE",level=47},
        {name="Cedar Vale",realm="Vale",displayName="Cedar Vale",class="ROGUE",level=47}}) do
        local line=R.ownLine({rid=7,zone=200,count=1,enemies={e}}); yes(line)
        local r=R.decodeOwn(line,"Other Scout",clock); yes(r); eq(#r.enemies,1)
        eq(r.enemies[1].name,"Cedar Vale","the full observed identity survives encoding")
        eq(r.enemies[1].class,"ROGUE"); eq(r.enemies[1].level,47); eq(r.enemies[1].hash,nil)
        local f=N.Find.new(); for _,name in ipairs({"Cedar Vale","Cedar","Cedar Grove"}) do yes(N.Find.add(f,name)) end
        N.Find.report(f,{sender=r.origin,zone=r.zone,at=r.at,enemies=r.enemies},"Test Realm")
        yes(f.locations["Cedar Vale"]); eq(f.locations.Cedar,nil); eq(f.locations["Cedar Grove"],nil)
    end
end)
test("guild O full name: malformed display identity is omitted, never replaced by the first name",function()
    local N=loadAddon(); local R=N.Relay
    for i,bad in ipairs({"Cedar  Vale","Cedar Vale Extra"," Cedar Vale","Cedar Vale ","Cedar_Vale","Cedar|Vale",
        "Cedar\nVale","Cedar\tVale","",false,123,{},secret,"C",string.char(255).."Vale",string.rep("C",101)}) do
        local line=R.ownLine({rid=7,zone=200,count=2,enemies={{name="Cedar",displayName=bad,class="ROGUE",level=47},
            {name="Birch",displayName="Birch Grove",class="MAGE",level=60}}})
        yes(line,"malformed display case "..i); local r=R.decodeOwn(line,"Other Scout",clock); yes(r)
        eq(r.count,2,"group count is not an identity count"); eq(#r.enemies,1,"omit malformed display case "..i)
        eq(r.enemies[1].name,"Birch Grove","a valid neighbor still survives")
    end
    for _,e in ipairs({{displayName="Cedar Vale"},{name=secret,displayName="Cedar Vale"}}) do
        local r=R.decodeOwn(R.ownLine({rid=7,zone=200,count=1,enemies={e}}),"Other Scout",clock)
        yes(r); eq(r.enemies[1].name,"Cedar Vale","a valid full identity does not depend on the fallback")
    end
end)
test("guild O full name: legacy single and combined names retain their O1 bytes",function()
    local N=loadAddon(); local R=N.Relay
    local rep={rid=7,zone=200,count=2,enemies={{name="Cedar",realm="Notasurname",class="ROGUE",level=47},{name="Birch Grove"}}}
    local legacy="O|1|7|200||||0|2|4365646172:ROGUE:47,42697263682047726f7665::"
    eq(R.ownLine(rep),legacy,"missing displayName uses name unchanged, never realm concatenation")
    rep.enemies[1].displayName="Cedar"; rep.enemies[2].displayName="Birch Grove"
    eq(R.ownLine(rep),legacy,"matching display identity does not change legacy bytes")
    local r=R.decodeOwn(legacy,"Other Scout",clock); yes(r); eq(r.count,2); eq(#r.enemies,2)
    eq(r.enemies[1].name,"Cedar"); eq(r.enemies[2].name,"Birch Grove")
    local f=N.Find.new(); yes(N.Find.add(f,"Cedar")); yes(N.Find.add(f,"Cedar Vale"))
    N.Find.report(f,{sender=r.origin,zone=r.zone,at=r.at,enemies=r.enemies},"Test Realm")
    yes(f.locations.Cedar); eq(f.locations["Cedar Vale"],nil,"old truncated records cannot invent a full identity")
    for _,name in ipairs({"Cedar Vale-TestRealm","Cedar Vale-8124","Élan Rivage"}) do
        local line=R.ownLine({rid=7,zone=200,count=1,enemies={{name="Cedar",displayName=name}}})
        r=R.decodeOwn(line,"Other Scout",clock); yes(r); eq(r.enemies[1].name,name,"preserve full bytes, including realm and UTF-8")
    end
end)
test("guild O full name: four-entry cap counts intact full identities, not first-name aliases",function()
    local N=loadAddon(); local R=N.Relay; local enemies={}
    for _,surname in ipairs({"Vale","Grove","Moss","Leaf","Fern"}) do
        enemies[#enemies+1]={name="Cedar",displayName="Cedar "..surname,class="ROGUE",level=47}
    end
    local line=R.ownLine({rid=7,zone=200,count=5,enemies=enemies}); yes(line); yes(#line<=255)
    local r=R.decodeOwn(line,"Other Scout",clock); yes(r); eq(r.count,5); eq(#r.enemies,4)
    for i,e in ipairs(r.enemies) do eq(e.name,enemies[i].displayName) end
    no(line:find("4665726e",1,true),"fifth full name omitted")
end)
test("guild O full name: 100-byte names and the 255-byte line boundary keep whole entries",function()
    local N=loadAddon(); local R=N.Relay
    local full=string.rep("C",36).." "..string.rep("V",36).."-"..string.rep("R",26); eq(#full,100)
    local rep={rid=7,zone=200,count=2,enemies={{name="Cedar",displayName=full,class="MAGE",level=60},
        {name="Birch",displayName=string.rep("B",13),level=1}}}
    local line=R.ownLine(rep); yes(line); eq(#line,255,"exactly 255 bytes is allowed")
    local r=R.decodeOwn(line,"Other Scout",clock); yes(r); eq(#r.enemies,2)
    eq(r.enemies[1].name,full); eq(r.enemies[2].name,string.rep("B",13))
    rep.enemies[2].level=10                 -- one more byte: omit the whole last entry, never shorten its identity
    line=R.ownLine(rep); yes(line); yes(#line<255)
    r=R.decodeOwn(line,"Other Scout",clock); yes(r); eq(#r.enemies,1); eq(r.enemies[1].name,full); eq(r.count,2)
    rep.enemies[1].displayName=full.."R"    -- 101 bytes: no fallback to Cedar
    line=R.ownLine(rep); yes(line); r=R.decodeOwn(line,"Other Scout",clock); yes(r)
    eq(#r.enemies,1); eq(r.enemies[1].name,string.rep("B",13))
end)
test("guild O full name: oversized legacy packets trim the tail once without duplicating the retained name",function()
    local N=loadAddon(); local full=string.rep("C",36).." "..string.rep("V",36).."-"..string.rep("R",26)
    local line=N.Relay.ownLine({rid=7,zone=200,count=2,enemies={{name=full,class="MAGE",level=60},
        {name=string.rep("B",13),level=10}}})
    yes(line); yes(#line<=255); local r=N.Relay.decodeOwn(line,"Other Scout",clock); yes(r)
    eq(#r.enemies,1,"keep the first name that fits rather than duplicate then drop it")
    eq(r.enemies[1].name,full); eq(r.count,2)
end)
test("guild O full name: observed split identity crosses share, Wire and cross-zone Find without donor traffic",function()
    for _,otherZone in ipairs({false,true}) do
        local N=loadAddon(); netOn(N,"we"); establish(N); hello("Other Scout",19)
        units.target={guid="Player-1-777",player=true,name="Cedar",realm="Vale",class="ROGUE",level=47,faction="Horde"}
        deliver("PLAYER_TARGET_CHANGED"); drain(); N.Main.shareTick(); eq(#oLines(),0)
        advance(3); N.Main.shareTick(); eq(#oLines(),1)
        local line=oLines()[1].text; eq(oLines()[1].kind,"GUILD"); yes(#line<=255)
        eq(#weSent("C"),0,"War Effort still requires at least two"); eq(#weSent("E"),0)
        local seen=N.Store.rows(N.Main.store,clock,"seen"); eq(#seen,1); eq(seen[1].displayName,"Cedar Vale")
        N=loadAddon()
        if otherZone then map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain() end
        advance(.1)                       -- a report received at the exact reset instant is deliberately stale
        local before=#sent
        N.Main.track("Cedar Vale"); N.Main.track("Cedar"); N.Main.track("Cedar Grove")
        eq(#sent,before,"Find remains passive")
        deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Other Scout")
        local loc=N.Main.find.locations["Cedar Vale"]; yes(loc,"full-name watch receives the guild O sighting")
        eq(loc.zone,100); eq(loc.spotter,"Other Scout"); eq(loc.class,"ROGUE"); eq(loc.level,47)
        eq(N.Main.find.locations.Cedar,nil); eq(N.Main.find.locations["Cedar Grove"],nil)
        eq(#N.Store.rows(N.Main.store,clock,"reported"),otherZone and 0 or 1)
        no(N.Main.error)
    end
end)
-- Seen-without-layer regression cases (numbers follow the implementation plan).
test("seen unknown 01: a targeted enemy is listed and labelled before the layer is known",function()
    local N=loadAddon(); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].layer,nil); eq(rows[1].zone,100)
    slash("list"); local line
    for _,v in ipairs(log) do if v:find("Aster Vale |",1,true) then line=v end end
    yes(line); yes(line:match(" | layer unknown when seen$")); no(N.Main.error)
    N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (1)")
    yes(N.UI.pool[1].sub.text:find("layer unknown",1,true))
    eq(N.UI.layer.text,"?")
    yes(N.UI.meta.text:find("layer unknown: mouse over or target two different kinds of NPC within 15 s",1,true))
end)
test("seen unknown 02: learning the layer preserves nil-layer rows but clears reports and identities",function()
    local N=loadAddon(); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local t=N.Main.store; local old=t.serial; local at=t.localSeen["Player-1-901"].at
    yes(next(t.identities)); report(1,7086); yes(next(t.reports)); advance(1); establish(N)
    local rows=N.Store.rows(t,clock,"local")
    eq(#rows,1); eq(rows[1].layer,nil); eq(rows[1].at,at); eq(rows[1].ownAt,at)
    eq(rows[1].epoch,old+1); yes(rows[1].pre); eq(t.serial,old+1); eq(t.zoneUID,7)
    yes(t.epoch>at); eq(next(t.identities),nil); eq(next(t.reports),nil); no(N.Main.error)
    -- Only nil-layer rows of the old serial survive; learning is not a general reset bypass.
    local other=N.Store.new(0); other.zone=100
    yes(N.Store.observe(other,{key="kept",at=1,faction="opposite"},1))
    yes(N.Store.observe(other,{key="old",at=1,faction="opposite"},1)); other.localSeen.old.epoch=0
    yes(N.Store.observe(other,{key="layered",at=1,faction="opposite"},1)); other.localSeen.layered.layer="9000-7"
    N.Store.learn(other,2,"7086-7",7)
    eq(N.Safe.count(other.localSeen),1); yes(other.localSeen.kept); eq(other.localSeen.kept.layer,nil)
end)
test("seen unknown 08: a learned layer is never assigned to an earlier sighting on the wire",function()
    local N=loadAddon(); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    advance(1); establish(N); advance(1.8); N.Main.shareTick()
    eq(#oLines(),1); yes(oLines()[1].text:find("^O|1|1|100|0.250|0.750||3|1|"),oLines()[1].text)
    -- All known: the existing layered O1 bytes remain unchanged.
    N=loadAddon(); establish(N); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil; advance(3); N.Main.shareTick()
    eq(#oLines(),1)
    eq(oLines()[1].text,"O|1|1|100|0.250|0.750|7086|3|1|41737465722056616c65:MAGE:60")
    -- Mixed reports must check every enemy, not only the newest/first row.
    N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    advance(1); establish(N); seeFoe("Briar Stone","Player-1-902"); units.target=nil
    advance(1.8); N.Main.shareTick(); eq(#oLines(),1)
    yes(oLines()[1].text:find("^O|1|1|100|0.250|0.750||"),oLines()[1].text)
    no(N.Main.error)
end)
test("seen unknown 10: nil-layer rows never become map candidates",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    eq(#N.Store.rows(N.Main.store,clock,"local"),1)
    eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    advance(1); establish(N); eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    seeFoe("Briar Stone","Player-1-902"); units.target=nil
    local rows=N.Store.mapCandidates(N.Main.store,clock,100)
    eq(#rows,1); eq(rows[1].key,"Player-1-902"); eq(rows[1].layer,"7086-7")
    eq(#N.Store.mapCandidates(N.Main.store,clock,200),0)
end)
test("seen unknown 03: a fresh sighting replaces the pre-layer row with the known layer",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    advance(1); establish(N)
    local before=N.Store.rows(N.Main.store,clock,"local"); eq(#before,1); eq(before[1].layer,nil)
    advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].layer,"7086-7"); eq(rows[1].pre,nil); eq(rows[1].ownAt,clock)
    no(rows[1]==before[1]); no(N.Main.error)
end)
test("seen unknown 03b: Bulo copies at or before learning cannot give a kept row a layer",function()
    for _,offset in ipairs({-.5,0}) do
        for _,delivery in ipairs({"learning poll","later poll"}) do
            for _,tracked in ipairs({"before","after"}) do
                local N=loadAddon(); local b=fakeBulo(nil); N.Main.setShare(false)
                if tracked=="before" then N.Main.track("Aster Vale") end
                advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
                local original=N.Main.store.localSeen["Player-1-901"]; local ownAt=clock
                advance(1); local learned=clock; b.current="7086-7"
                local copy={at=learned+offset,hostile=true,src="target"}
                yes(copy.at>ownAt,"copy is newer than the own sighting, but not newer than learning")
                if delivery=="learning poll" then b.Radar.seen["Player-1-901"]=copy end
                N.Main.poll(); eq(N.Main.store.epoch,learned); eq(N.Main.store.bulo,"7086-7")
                if delivery=="later poll" then
                    advance(1); b.Radar.seen["Player-1-901"]=copy; N.Main.poll()
                end
                b.Radar.seen={}
                local rows=N.Store.rows(N.Main.store,clock,"local"); eq(#rows,1)
                eq(rows[1],original,"older Bulo copy cannot replace the kept unknown row")
                yes(rows[1].pre); eq(rows[1].layer,nil); eq(rows[1].ownAt,ownAt); eq(rows[1].source,"own target")
                if tracked=="after" then N.Main.track("Aster Vale") end
                local found=N.Main.findRows()[1]; yes(found.own); no(found.same); no(found.canAsk)
                eq(found.status,"seen by you, layer unknown"); eq(found.at,ownAt)
                yes(N.Main.findText(found):find("seen by you, layer unknown",1,true))
                N.UI.toggle(); N.UI.tabs.find:Click()
                local r=N.UI.pool[1]; yes(r,"Find row exists"); yes(r:IsShown()); eq(r.title.text,"Aster Vale")
                yes(r.sub.text:find("seen by you, layer unknown",1,true)); no(r.sub.text:find("already on your layer",1,true)); no(r.ask:IsShown())
                N.Main.setShare(true); advance(3); N.Main.shareTick()
                eq(#oLines(),1); yes(oLines()[1].text:find("|0.250|0.750||",1,true),oLines()[1].text)
                no(N.Main.error)
            end
        end
    end
end)
test("seen unknown 03c: a Bulo observation after learning may replace the kept unknown row",function()
    local N=loadAddon(); local b=fakeBulo(nil); N.Main.setShare(false); N.Main.track("Aster Vale")
    advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil; local ownAt=clock
    local original=N.Main.store.localSeen["Player-1-901"]
    advance(1); b.current="7086-7"; N.Main.poll(); local learned=N.Main.store.epoch
    eq(original.layer,nil); yes(original.pre)
    advance(1); local observed=clock; yes(observed>learned)
    b.Radar.seen["Player-1-901"]={at=observed,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
    local rows=N.Store.rows(N.Main.store,clock,"local"); eq(#rows,1)
    no(rows[1]==original); eq(rows[1].source,"Bulo target"); eq(rows[1].layer,"7086-7"); eq(rows[1].pre,nil)
    eq(rows[1].at,observed); eq(rows[1].ownAt,ownAt); eq(rows[1].ownSource,"own target")
    eq(rows[1].x,nil); eq(rows[1].y,nil); eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    -- A copy refreshes the list, not Find's earlier first-hand observation.
    local found=N.Main.findRows()[1]; eq(found.status,"seen by you, layer unknown"); eq(found.at,ownAt); no(found.same); no(found.canAsk)
    N.UI.toggle(); eq(N.UI.pool[1].title.text,"Aster Vale")
    no(N.UI.pool[1].sub.text:find("layer unknown",1,true))
    N.Main.setShare(true); advance(3); N.Main.shareTick()
    eq(#oLines(),1); yes(oLines()[1].text:find("|0.250|0.750|7086|",1,true),oLines()[1].text)
    no(N.Main.error)
end)
test("seen unknown 04: kept rows expire 600 seconds after the original sighting",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local at=clock; advance(1); establish(N)
    eq(#N.Store.rows(N.Main.store,clock,"local"),1)
    advance(at+599-clock); eq(#N.Store.rows(N.Main.store,clock,"local"),1)
    advance(1); eq(#N.Store.rows(N.Main.store,clock,"local"),0)
end)
test("seen unknown 05: unreadable faction stays unclassified with no layer",function()
    local N=loadAddon(); advance(1)
    units.target=player("Aster Vale",nil,"Player-1-901"); deliver("PLAYER_TARGET_CHANGED"); drain(); units.target=nil
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    local rows=N.Store.rows(N.Main.store,clock,"unclassified"); eq(#rows,1); eq(rows[1].layer,nil)
    advance(1); establish(N); eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    rows=N.Store.rows(N.Main.store,clock,"unclassified"); eq(#rows,1); eq(rows[1].layer,nil)
end)
test("seen unknown 01b: Find says layer unknown for an own sighting made before the layer is known",function()
    local N=loadAddon(); N.Main.track("Aster Vale"); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local row=N.Main.findRows()[1]
    yes(row.own,"own row"); no(row.same,"no same-layer claim without a known layer"); no(row.canAsk)
    eq(row.status,"seen by you, layer unknown")
    local text=N.Main.findText(row)
    yes(text:find("seen by you, layer unknown",1,true),"slash find text: "..text); no(text:find("YOUR layer",1,true)); no(text:find("already on your layer",1,true))
    N.UI.toggle(); N.UI.tabs.find:Click(); eq(N.UI.tab,"find")
    local shown=N.UI.pool[1]; yes(shown,"Find row exists"); yes(shown:IsShown(),"Find row is visible")
    eq(shown.tracked,"Aster Vale"); eq(shown.title.text,"Aster Vale")
    local sub=shown.sub.text; yes(sub,"Find row text exists")
    yes(sub:find("seen by you, layer unknown",1,true)); no(sub:find("YOUR layer",1,true)); no(sub:find("already on your layer",1,true))
    no(shown.ask:IsShown(),"own unknown-layer sighting has no Ask button")
    -- learning the layer later does not upgrade the old sighting into a same-layer claim
    advance(1); establish(N); no(N.Main.findRows()[1].same); eq(N.Main.findRows()[1].status,"seen by you, layer unknown")
    -- a fresh sighting with the layer known is the existing claim
    advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    row=N.Main.findRows()[1]; yes(row.same,"fresh known-layer sighting"); eq(row.status,"is on YOUR layer"); no(N.Main.error)
end)
test("seen unknown 06: a real layer or raw-id change still wipes kept pre-layer rows",function()
    for _,id in ipairs({"7086-8","8000-7"}) do
        local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
        advance(1); establish(N); eq(#N.Store.rows(N.Main.store,clock,"local"),1)
        local b=fakeBulo(id); N.Main.poll()
        eq(N.Main.store.bulo,id); eq(next(N.Main.store.localSeen),nil)
        eq(#N.Store.rows(N.Main.store,clock,"local"),0); no(N.Main.error)
    end
end)
test("seen unknown 07: shard transfer still wipes unknown and kept sightings",function()
    for _,known in ipairs({false,true}) do
        local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
        if known then advance(1); establish(N) end
        eq(#N.Store.rows(N.Main.store,clock,"local"),1)
        deliver("SHARD_TRANSFER"); drain(); eq(next(N.Main.store.localSeen),nil)
        eq(#N.Store.rows(N.Main.store,clock,"local"),0); no(N.Main.error)
    end
end)
test("seen unknown 09: learning preserves the 60-second shared-enemy cooldown",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    advance(3); N.Main.shareTick(); eq(#oLines(),1)
    local at=clock; local shared=N.Main.share
    advance(1); establish(N); eq(#N.Store.rows(N.Main.store,clock,"local"),1)
    eq(N.Main.share,shared); eq(shared.shared["Player-1-901"],at)
    N.Main.shareTick(); eq(#oLines(),1)
    advance(at+57-clock); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    advance(2); N.Main.shareTick(); eq(#oLines(),1,"not before 60 seconds")
    advance(1); N.Main.shareTick(); eq(#oLines(),2,"new report at 60 seconds")
    no(N.Main.error)
end)
test("previous zone 11: real crossings carry an own row for 120 seconds from its sighting",function()
    for _,route in ipairs({"ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","poll","observe"}) do
        local N=loadAddon(); establish(N); advance(math.ceil(clock)+1-clock)
        seeFoe("Aster Vale","Player-1-901"); local at=clock
        map=200
        if route=="poll" then N.Main.poll()
        elseif route=="observe" then N.Main.observe("target")
        else deliver(route); drain() end
        eq(N.Main.store.zone,200); eq(#N.Store.rows(N.Main.store,clock,"local"),0)
        yes(type(N.Store.previous)=="function","previous-zone reader exists")
        local rows=N.Store.previous(N.Main.store,clock); eq(#rows,1,route)
        local e=rows[1]; eq(e.key,"Player-1-901"); eq(e.name,"Aster Vale"); eq(e.zone,100); eq(e.at,at)
        eq(e.layer,nil); eq(e.x,nil); eq(e.y,nil); eq(e.faction,nil); eq(e.ownSource,nil)
        local allowed={key=true,name=true,displayName=true,class=true,level=true,zone=true,at=true}
        for k in pairs(e) do yes(allowed[k],"plain previous-zone field: "..k) end
        N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (1)")
        yes(N.UI.pool[1].sub.text:find("MAGE · Ashenvale · previous zone",1,true),N.UI.pool[1].sub.text); no(N.UI.pool[1].ask:IsShown())
        slash("list"); yes(logged("Aster Vale | MAGE · Ashenvale · previous zone")); no(logged("No eligible observations."))
        -- Still-held units remain quarantined; the carried row covers the gap, it is not a fresh sighting.
        advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
        eq(next(N.Main.store.localSeen),nil); eq(#N.Store.previous(N.Main.store,clock),1)
        advance(at+119-clock); eq(#N.Store.previous(N.Main.store,clock),1)
        advance(1); eq(#N.Store.previous(N.Main.store,clock),0)
        advance(1); eq(#N.Store.previous(N.Main.store,clock),0)
        N.UI.render(); eq(N.UI.tabs["local"].label.text,"Seen by you (0)"); no(N.Main.error)
    end
end)
test("previous zone 11b: learning the new zone layer keeps the carry until its original expiry",function()
    for _,source in ipairs({"NPC","Bulo"}) do
        local N=loadAddon(); establish(N); advance(math.ceil(clock)+1-clock)
        seeFoe("Aster Vale","Player-1-901"); units.target=nil; local at=clock
        advance(1); map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
        local carried=N.Store.previous(N.Main.store,clock); eq(#carried,1,source)
        advance(3)
        if source=="NPC" then
            units.mouseover=nil; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); establish(N)
        else
            fakeBulo("8000-7"); N.Main.poll(); eq(N.Main.store.bulo,"8000-7")
        end
        local learned=clock
        advance(10); eq(clock,learned+10)
        local rows=N.Store.previous(N.Main.store,clock)
        eq(#rows,1,"carry survives ten seconds after learning via "..source)
        eq(rows[1],carried[1]); eq(rows[1].zone,100); eq(rows[1].at,at); eq(rows[1].layer,nil)
        N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (1)")
        yes(N.UI.pool[1]:IsShown()); yes(N.UI.pool[1].sub.text:find("Ashenvale · previous zone",1,true))
        slash("list"); yes(logged("Aster Vale | MAGE · Ashenvale · previous zone"))
        advance(at+119-clock); eq(#N.Store.previous(N.Main.store,clock),1)
        advance(1); eq(#N.Store.previous(N.Main.store,clock),0)
        N.UI.render(); eq(N.UI.tabs["local"].label.text,"Seen by you (0)"); no(N.Main.error)
    end
end)
test("previous zone 12: expired own sightings are not revived by a crossing or Bulo refresh",function()
    for _,age in ipairs({120,121}) do
        local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
        seeFoe("Aster Vale","Player-1-901"); units.target=nil; local at=clock
        advance(age); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
        eq(N.Main.store.localSeen["Player-1-901"].ownAt,at)
        eq(N.Main.store.localSeen["Player-1-901"].at,clock)
        -- Do not let a new layer from Bulo clear a wrongly carried row before it can be asserted.
        BuloLayerForever=nil; map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
        yes(type(N.Store.previous)=="function","previous-zone reader exists")
        eq(#N.Store.previous(N.Main.store,clock),0); eq(#N.Main.store.prev,0)
    end
end)
test("previous zone 13: only the newest eight sightings are carried as independent copies",function()
    local N=loadAddon(); establish(N); local original
    for i=1,9 do
        advance(1); seeFoe("Aster "..abc(i),"Player-1-"..i); units.target=nil
        if i==9 then original=N.Main.store.localSeen["Player-1-9"] end
    end
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    yes(type(N.Store.previous)=="function","previous-zone reader exists")
    local rows=N.Store.previous(N.Main.store,clock); eq(#rows,8); eq(#N.Main.store.prev,8)
    for i,e in ipairs(rows) do eq(e.key,"Player-1-"..(10-i)); eq(e.zone,100) end
    original.name="Changed"; original.at=clock+20
    eq(rows[1].name,"Aster i"); no(rows[1]==original); yes(rows[1].at<=clock)
    N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (8)")
end)
test("previous zone 14: only opposite-faction own-source current-epoch rows are eligible",function()
    local N=loadAddon(); advance(1); local t=N.Main.store
    local function put(key,faction,source,at)
        yes(N.Store.observe(t,{key=key,name="Aster "..key,at=at or clock,faction=faction,source=source},clock))
    end
    put("Copy","opposite","Bulo target")
    put("Friendly","same","own target"); put("Unreadable","unknown","own mouseover")
    put("Old","opposite","own target"); t.localSeen.Old.epoch=t.serial-1
    put("Far","opposite","own target"); t.localSeen.Far.zone=200
    put("Future","opposite","own target"); t.localSeen.Future.ownAt=clock+50
    put("Own","opposite","own nameplate1"); local at=clock
    advance(1); put("Own","opposite","Bulo target") -- fresh Bulo copy keeps the earlier own proof
    eq(t.localSeen.Own.ownAt,at); eq(t.localSeen.Own.source,"Bulo target")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    yes(type(N.Store.previous)=="function","previous-zone reader exists")
    local rows=N.Store.previous(t,clock); eq(#rows,1); eq(rows[1].key,"Own"); eq(rows[1].at,at)
end)
test("previous zone 15: non-zone boundaries clear carry-over even when the map also changes",function()
    for _,event in ipairs({"SHARD_TRANSFER","PLAYER_ENTERING_WORLD","layer","npc","Bulo transfer","unreadable"}) do
        local N=loadAddon(); establish(N); advance(1)
        seeFoe("Aster Vale","Player-1-901"); units.target=nil
        map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
        yes(type(N.Store.previous)=="function","previous-zone reader exists")
        eq(#N.Store.previous(N.Main.store,clock),1,event)
        advance(1); seeFoe("Briar Stone","Player-1-902"); units.target=nil
        if event=="layer" then
            units.mouseover=nil; deliver("UPDATE_MOUSEOVER_UNIT"); drain()
            establish(N) -- learning preserves the carry; a subsequent real layer change clears it
            eq(#N.Store.previous(N.Main.store,clock),1)
            advance(1); N.Main.applyLayer("8000-7","test layer")
        elseif event=="npc" then
            for _,e in ipairs({{3,7,"7086"},{4,7,"8000"},{5,8,"7086"},{6,8,"8000"}}) do
                units.target={guid=npc(e[1],e[2],e[3]),player=false}
                deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
            end
        elseif event=="Bulo transfer" then
            local b=fakeBulo(nil); N.Main.poll(); map=100; b:Fire("LFS_TRANSFER"); drain()
        elseif event=="unreadable" then map=nil; deliver("ZONE_CHANGED"); drain()
        else map=100; deliver(event); drain() end
        eq(#N.Store.previous(N.Main.store,clock),0,event); eq(#N.Main.store.prev,0,event)
        no(N.Main.error)
    end
end)
test("previous zone 16: reacquiring the same player replaces the carried display with one live row",function()
    local N=loadAddon(); establish(N); advance(1)
    seeFoe("Aster Vale","Player-1-901")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    yes(type(N.Store.previous)=="function","previous-zone reader exists")
    eq(#N.Store.previous(N.Main.store,clock),1)
    units.target=nil; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local rows=N.Store.rows(N.Main.store,clock,"local"); eq(#rows,1); eq(rows[1].zone,200)
    eq(#N.Store.previous(N.Main.store,clock),0)
    N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (1)")
    yes(N.UI.pool[1].sub.text:find("Durotar · layer unknown",1,true))
    no(N.UI.pool[1].sub.text:find("previous zone",1,true))
    slash("list"); eq(lines("Aster Vale |"),1); no(logged("previous zone")); no(N.Main.error)
end)
test("previous zone 17: carried rows never become sends, Find locations, maps or actions",function()
    local N=loadAddon(); establish(N); advance(1); N.Main.track("Aster Vale")
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    yes(N.Main.findRows()[1].at); eq(#oLines(),0,"cross before sharing settles")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    yes(type(N.Store.previous)=="function","previous-zone reader exists")
    eq(#N.Store.previous(N.Main.store,clock),1)
    -- Exercise presentation and background work, not just the reducer.
    sent={}; log={}; N.UI.toggle(); slash("list"); advance(10); N.Main.shareTick()
    eq(#oLines(),0); eq(#sent,0); yes(N.Main.find.locations["Aster Vale"])
    local remembered=N.Main.findRows()[1]; yes(remembered.at); yes(remembered.travel); no(remembered.same); no(remembered.canAsk); no(logged("is on YOUR layer"))
    eq(#N.Store.mapCandidates(N.Main.store,clock,100),0); eq(#N.Store.mapCandidates(N.Main.store,clock,200),0)
    eq(#N.Main.candidates(),0); eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    no(N.UI.pool[1].ask:IsShown()); N.UI.pool[1].ask:Click(); eq(#sent,0); eq(#opened,0)
    no(N.Main.error)
end)
test("previous zone 18: a second crossing keeps only the zone just left after live rows",function()
    local N=loadAddon(); establish(N); advance(1)
    seeFoe("Aster Vale","Player-1-901"); units.target=nil
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    yes(type(N.Store.previous)=="function","previous-zone reader exists")
    eq(#N.Store.previous(N.Main.store,clock),1)
    advance(1); seeFoe("Briar Stone","Player-1-902"); units.target=nil
    N.UI.toggle(); eq(N.UI.tabs["local"].label.text,"Seen by you (2)")
    eq(N.UI.pool[1].title.text,"Briar Stone"); eq(N.UI.pool[2].title.text,"Aster Vale")
    slash("list"); local first,second
    for i,line in ipairs(log) do
        if line:find("Briar Stone |",1,true) then first=i end
        if line:find("Aster Vale |",1,true) then second=i end
    end
    yes(first and second and first<second,"live rows precede previous-zone rows")
    map=100; deliver("ZONE_CHANGED"); drain()
    local rows=N.Store.previous(N.Main.store,clock); eq(#rows,1); eq(rows[1].key,"Player-1-902"); eq(rows[1].zone,200)
    map=200; deliver("ZONE_CHANGED"); drain(); eq(#N.Store.previous(N.Main.store,clock),0,"empty zone clears older carry")
    no(N.Main.error)
end)
test("previous zone 19: scrolled live and carried rows keep their distinct labels",function()
    local N=loadAddon(); establish(N)
    for i=1,8 do advance(1); seeFoe("Aster "..abc(i),"Player-1-90"..i); units.target=nil end
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(#N.Store.previous(N.Main.store,clock),8)
    for i=1,7 do advance(.1); seeFoe("Briar "..abc(i),"Player-1-80"..i); units.target=nil end
    N.Main.setShare(false); sent={}; N.UI.toggle()
    eq(N.UI.tabs["local"].label.text,"Seen by you (15)")
    local live=N.Store.rows(N.Main.store,clock,"local"); eq(#live,7)
    local carried=N.Store.previous(N.Main.store,clock)
    for _,offset in ipairs({0,2,9}) do
        while N.UI.offset<offset do N.UI.body.scripts.OnMouseWheel(N.UI.body,-1) end
        eq(N.UI.offset,offset)
        local shown=0
        for i,r in ipairs(N.UI.pool) do if r:IsShown() then
            shown=shown+1
            local index=i+offset
            local previous=index>#live
            local e=previous and carried[index-#live] or live[index]
            yes(e,"expected scrolled row exists"); eq(r.title.text,e.name)
            eq(r.sub.text,"MAGE · "..(previous and "Ashenvale · previous zone" or "Durotar · layer unknown"))
            no(r.ask:IsShown()); r.ask:Click()
        end end
        eq(shown,6,"visible rows at offset "..offset)
    end
    eq(#sent,0); eq(#opened,0); no(N.Main.error)
end)
test("previous zone 20: carry rejects future own timestamps before the previous-row reader runs",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local t=N.Main.store; local at=t.localSeen["Player-1-901"].ownAt
    eq(at,clock); eq(#N.Store.carry(t,clock),1)
    clock=at-1
    eq(#N.Store.carry(t,clock),0,"future own timestamp cannot enter the carry")
    eq(#t.prev,0); eq(t.localSeen["Player-1-901"].ownAt,at)
    clock=at; eq(#N.Store.carry(t,clock),1,"the original valid boundary remains eligible")
    no(N.Main.error)
end)
test("previous zone 21: a backward clock permanently prunes future carried rows",function()
    local N=loadAddon(); advance(1); seeFoe("Aster Vale","Player-1-901"); units.target=nil
    local at=clock; map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    local t=N.Main.store; eq(#t.prev,1); eq(#N.Store.previous(t,clock),1)
    clock=at-1
    eq(#N.Store.previous(t,clock),0,"clock reversal hides future carry")
    eq(#t.prev,0,"clock reversal removes, not merely hides, the row")
    clock=at+1; eq(#N.Store.previous(t,clock),0,"forward clock must not revive it")
    no(N.Main.error)
end)
-- OpenMap is an independent receive-only Find source, never an enemy report.
do
local OM_LINE="L1\t200\t0.4200\t0.5700\tMAGE\t60"
local function om(text,kind,sender)
    deliver("CHAT_MSG_ADDON","OpenMapLoc",text or OM_LINE,kind or "GUILD",sender or "Cedar Vale")
end
test("OpenMap guild tracer: exact tracked sender yields a session place without sends",function()
    local N=loadAddon(); N.Main.track("Cedar Vale")
    eq(registered.OpenMapLoc,true,"prefix is registered, not sent")
    local nlog=#log; om()
    local row=N.Main.findRows()[1]; yes(row.place,"tracked sender supplies a separate place")
    eq(row.place.map,200); eq(row.place.x,.42); eq(row.place.y,.57)
    eq(row.place.class,"MAGE"); eq(row.place.level,60); eq(row.place.at,clock); eq(row.place.route,"GUILD")
    eq(row.place.faction,nil); eq(row.at,nil); eq(#sent,0); eq(#log,nlog)
    eq(next(N.Main.store.localSeen),nil); eq(next(N.Main.store.reports),nil); no(N.Main.error)
end)
local function snapshot(value,seen)
    if type(value)~="table" then return type(value)..":"..tostring(value) end
    seen=seen or {}; if seen[value] then return "cycle" end; seen[value]=true
    local out={}; for k,v in pairs(value) do out[#out+1]=snapshot(k,seen).."="..snapshot(v,seen) end
    seen[value]=nil; table.sort(out); return "{"..table.concat(out,",").."}"
end
local function omReady(name)
    local N=loadAddon(); GetNormalizedRealmName=nil
    if name~=false then N.Main.track(name or "Cedar Vale") end
    return N
end
local function noEffect(N,fn)
    local before=snapshot({N.Main,LayerEnemiesDB,log,sent,timers,N.Wire,N.UI})
    fn()
    yes(snapshot({N.Main,LayerEnemiesDB,log,sent,timers,N.Wire,N.UI})==before,"discard without retaining, counting, scheduling or logging")
    no(N.Main.error)
end
test("OpenMap untracked and empty watchlist: no state changes or decoding",function()
    for _,tracked in ipairs({false,"Cedar Vale"}) do
        local N=omReady(tracked); N.Main.lastDrop="earlier rejection"
        if N.OpenMap then N.OpenMap.decode=function() error("untracked must not decode") end end
        noEffect(N,function() om(nil,"GUILD","Birch Grove") end)
    end
end)
test("OpenMap wire grammar: complete valid bounds and empty class",function()
    local N=omReady()
    for _,v in ipairs({{1,"0.0000","1.0000","",0},{999999,"1.0000","0.0000","WARRIOR",80}}) do
        om(table.concat({"L1",v[1],v[2],v[3],v[4],v[5]},"\t"),"WHISPER")
        local p=N.Main.findRows()[1].place; yes(p); eq(p.map,v[1]); eq(p.x,tonumber(v[2])); eq(p.y,tonumber(v[3]))
        eq(p.class,v[4]~="" and v[4] or nil); eq(p.level,v[5]); eq(p.route,"WHISPER")
    end
    local line="L1\t100\t0.0001\t0.9999\t"..string.rep("A",40).."\t80"; eq(#line,64)
    om(line); yes(N.Main.findRows()[1].place); eq(N.Main.findRows()[1].place.class,string.rep("A",40))
end)
test("OpenMap malformed lines cannot replace a live place",function()
    local N=omReady(); om(); yes(N.Main.findRows()[1].place)
    local lines={OM_LINE.."\textra", "L1\t200\t0.4200\t0.5700\tMAGE", "L1\t200\t1.5000\t0.5700\tMAGE\t60",
        "L1\t200\t0.0000\t0.0000\tMAGE\t60", "L1\t0\t0.4200\t0.5700\tMAGE\t60",
        "L1\t1000000\t0.4200\t0.5700\tMAGE\t60", "L1\t200\t0.4200\t0.5700\tmage\t60",
        "L1\t200\t0.4200\t1.0001\tMAGE\t60", "L1\t200\t-0.4200\t0.5700\tMAGE\t60",
        "L1\t200\t0.42\t0.5700\tMAGE\t60", "L1\t200\t0.42000\t0.5700\tMAGE\t60",
        "L1\t200\t0.4200\t0.5700\tMAGE\t81", "L1\t200\t0.4200\t0.5700\tMAGE\t-1",
        "L1\t200\t0.4200\t0.5700\tMAGE\t6.0", "L1\t+200\t0.4200\t0.5700\tMAGE\t60",
        "L1\t200\t0.4200\t0.5700\tMAGE\t60\n", "L0\t", "H1", "H2", "P1", "", false, 123, {}, secret,
        "L1\t100\t0.0001\t0.9999\t"..string.rep("A",41).."\t80"}
    eq(#lines[#lines],65)
    for _,line in ipairs(lines) do noEffect(N,function() deliver("CHAT_MSG_ADDON","OpenMapLoc",line,"GUILD","Cedar Vale") end) end
    noEffect(N,function() deliver("CHAT_MSG_ADDON","OpenMapLoc",nil,"GUILD","Cedar Vale") end)
end)
test("OpenMap every secret event argument is discarded before indexing",function()
    local N=omReady(); om(); yes(N.Main.findRows()[1].place)
    for i=1,8 do
        local args={"OpenMapLoc",OM_LINE,"GUILD","Cedar Vale","",0,0,""}; args[i]=secret
        noEffect(N,function() deliver("CHAT_MSG_ADDON",unpack(args,1,8)) end)
    end
end)
test("OpenMap routes and unreadable senders are refused silently",function()
    local N=omReady(); om(); yes(N.Main.findRows()[1].place)
    for _,route in ipairs({"PARTY","RAID","CHANNEL","BN","INSTANCE_CHAT",false,{},secret}) do
        noEffect(N,function() deliver("CHAT_MSG_ADDON","OpenMapLoc","L0",route,"Cedar Vale") end)
    end
    for _,sender in ipairs({"",false,123,{},secret,"Cedar|Vale","Cedar  Vale"," Cedar Vale",string.rep("C",101)}) do
        noEffect(N,function() deliver("CHAT_MSG_ADDON","OpenMapLoc","L0","GUILD",sender) end)
    end
end)
test("OpenMap exact folded identity: no first-name alias and no foreign-realm alias",function()
    local N=omReady("Cedar"); noEffect(N,function() om() end)
    om(nil,"GUILD","Cedar-Foreign"); eq(N.Main.findRows()[1].place,nil)
    om(nil,"GUILD","CEDAR-TestRealm"); yes(N.Main.findRows()[1].place)
    N.Main.track("Cedar-Foreign"); om(nil,"WHISPER","CEDAR-FOREIGN")
    local rows=N.Main.findRows(); eq(rows[1].place.route,"GUILD"); eq(rows[2].place.route,"WHISPER")
    for _,v in ipairs({{"élodie","ÉLODIE"},{"zoé","Zoé"},{"łukasz","Łukasz"},{"мирон","Мирон"},{"élodie łan","Élodie Łan"}}) do
        N=omReady(v[1]); om(nil,"WHISPER",v[2].."-TestRealm")
        yes(N.Main.findRows()[1].place,"folded match "..v[1])
    end
end)
test("OpenMap own identity and ignores fail closed then recover",function()
    local N=omReady("Fable Reed"); ownShape("Fable","Reed","8123")
    for _,who in ipairs({"Fable Reed","Fable Reed-8123"}) do noEffect(N,function() om(nil,"GUILD",who) end) end
    N.Main.track("Cedar Vale")
    for _,shape in ipairs({{nil,"Reed","8123"},{"Fable",secret,"8123"},{"Fable","Reed","Reed"},{"Fable","Reed",nil}}) do
        ownShape(shape[1],shape[2],shape[3]); noEffect(N,function() om() end)
    end
    ownShape("Fable","Reed","8123")
    clientIgnored=true; noEffect(N,function() om() end); clientIgnored=false
    for _,read in ipairs({function() return nil end,function() return secret end,function() error("ignore unavailable") end}) do
        C_FriendList.IsIgnored=read; noEffect(N,function() om() end)
    end
    C_FriendList.IsIgnored=function() return false end; om(); yes(N.Main.findRows()[2].place)
end)
test("OpenMap lifecycle: L0 and 150 second expiry, including backward clocks",function()
    local N=omReady(); om(); yes(N.Main.findRows()[1].place)
    clock=clock+149.9; yes(N.Main.findRows()[1].place)
    clock=clock+.1; eq(N.Main.findRows()[1].place,nil); eq(next(N.Main.find.places),nil)
    om(); om("L0","WHISPER"); eq(N.Main.findRows()[1].place,nil); eq(next(N.Main.find.places),nil)
    om(); clock=clock-1; eq(N.Main.findRows()[1].place,nil)
end)
test("OpenMap lifecycle: casefold remove and clear delete stored spellings only",function()
    local N=omReady("élodie"); N.Main.track("Birch Grove")
    om(nil,"GUILD","Élodie"); om(nil,"GUILD","Birch Grove")
    local st=N.Main.find; yes(st.places and st.places["élodie"]); local keep=st.places["Birch Grove"]
    N.Find.remove(st,"ÉLODIE"); eq(st.places["élodie"],nil); eq(st.places["Birch Grove"],keep)
    N.Find.remove(st); eq(next(st.places),nil)
end)
test("OpenMap places are bounded by the watchlist and are never saved",function()
    local N=omReady(false)
    for i=1,5 do N.Main.track("Cedar "..abc(i)) end
    for i=1,50 do om(nil,"GUILD","Cedar "..abc(i)) end
    yes(N.Main.find.places); eq(N.Safe.count(N.Main.find.places),5)
    local db=snapshot(LayerEnemiesDB); om(); eq(snapshot(LayerEnemiesDB),db)
    N.Main.started=false; N.Main.start(); eq(#N.Main.find.names,5); eq(next(N.Main.find.places),nil)
end)

local function bn(text,id,prefix,channel)
    deliver("BN_CHAT_MSG_ADDON",prefix or "OpenMapLoc",text or OM_LINE,channel or "",id or 77)
end
local function bnReady(name)
    local N=omReady(name)
    bnInfo={characterName="Cedar Vale",realmName="Test Realm",factionName="Horde",playerGuid="Player-2-456"}
    return N
end
test("OpenMap BN tracer: registered event yields a place with opposite faction, not account data",function()
    local N=bnReady(); yes(N.Main.frame.events.BN_CHAT_MSG_ADDON,"optional BN event registered")
    local nlog=#log; bn()
    eq(bnCalls,1); local p=N.Main.findRows()[1].place; yes(p)
    eq(p.map,200); eq(p.x,.42); eq(p.y,.57); eq(p.route,"BN"); eq(p.faction,"opposite"); eq(p.at,clock)
    eq(p.id,nil); eq(p.playerGuid,nil); eq(p.characterName,nil); eq(p.realmName,nil)
    eq(#sent,0); eq(#log,nlog); eq(next(N.Main.store.reports),nil); no(N.Main.error)
end)

test("OpenMap BN untracked and empty watchlist never retain lookup data or decode",function()
    local N=bnReady(false); noEffect(N,function() bn() end); eq(bnCalls,0)
    N.Main.track("Birch Grove")
    if N.OpenMap then N.OpenMap.decode=function() error("untracked must not decode") end end
    bnInfo=setmetatable(bnInfo,{__index=function(_,key) error("unexpected account field "..key) end})
    noEffect(N,function() bn() end); eq(bnCalls,1,"one lookup for a possible tracked character")
end)
test("OpenMap BN lookup failures and invalid arguments are harmless",function()
    local N=bnReady(); bn(); yes(N.Main.findRows()[1].place)
    for _,bad in ipairs({false,"bad",123,secret,{}}) do bnInfo=bad; noEffect(N,function() bn() end) end
    bnInfo=function() error("lookup unavailable") end; noEffect(N,function() bn() end)
    bnInfo=setmetatable({},{__index=function() error("unreadable table field") end}); noEffect(N,function() bn() end)
    bnInfo=nil; noEffect(N,function() bn() end)
    C_BattleNet.GetGameAccountInfoByID=nil; noEffect(N,function() bn() end)
    C_BattleNet=nil; noEffect(N,function() bn() end)
    N=bnReady(); bn(); yes(N.Main.findRows()[1].place); bnCalls=0
    for i=1,4 do
        local args={"OpenMapLoc",OM_LINE,"",77}; args[i]=secret
        noEffect(N,function() deliver("BN_CHAT_MSG_ADDON",unpack(args,1,4)) end)
    end
    for _,bad in ipairs({"77",false,{},0/0,math.huge,-math.huge}) do
        noEffect(N,function() deliver("BN_CHAT_MSG_ADDON","OpenMapLoc",OM_LINE,"",bad) end)
    end
    for _,bad in ipairs({false,{},123,string.rep("A",65)}) do
        noEffect(N,function() deliver("BN_CHAT_MSG_ADDON","OpenMapLoc",bad,"",77) end)
    end
    noEffect(N,function() deliver("BN_CHAT_MSG_ADDON","OpenMapLoc",nil,"",77) end)
    noEffect(N,function() deliver("BN_CHAT_MSG_ADDON","OpenMap",OM_LINE,"",77) end)
    noEffect(N,function() deliver("BN_CHAT_MSG_ADDON","OpenMapLoc",OM_LINE,"",nil) end)
    eq(bnCalls,0,"invalid arguments dropped before lookup")
end)
test("OpenMap BN names require readable characters and realms without reading accounts",function()
    local N=bnReady("élodie łan")
    bnInfo={characterName="Élodie Łan",realmName="Test Realm",factionName="Horde",playerGuid="Player-2-456"}
    setmetatable(bnInfo,{__index=function(_,key) error("must not read "..key) end})
    bn(); yes(N.Main.findRows()[1].place,"full folded surname, not account fields")
    for _,field in ipairs({"characterName","realmName"}) do
        for _,bad in ipairs({false,secret,{},123,"","bad|name"}) do
            local good=bnInfo[field]; bnInfo[field]=bad
            noEffect(N,function() bn("L0") end); bnInfo[field]=good
        end
    end
    bnInfo.realmName="Foreign"; noEffect(N,function() bn("L0") end)
    N=bnReady("Cedar-Foreign"); bnInfo.characterName="Cedar"; bnInfo.realmName="Foreign"; bn()
    yes(N.Main.findRows()[1].place)
    bnInfo.characterName="Cedar-Foreign"; bn("L0"); eq(N.Main.findRows()[1].place,nil)
    bnInfo.characterName="Cedar-Elsewhere"; noEffect(N,function() bn() end)
end)
test("OpenMap BN hellos, own character by name or GUID, and ignored friends are refused",function()
    local N=bnReady()
    for _,text in ipairs({"H1","H2","L1\t200\t0.4200\t0.5700\tMAGE\t81"}) do noEffect(N,function() bn(text) end) end
    N.Main.track("Me"); bnInfo.characterName="Me"; noEffect(N,function() bn() end)
    bnInfo.characterName="Cedar Vale"; units.player={guid="Player-2-456"}; noEffect(N,function() bn() end)
    units.player=nil; clientIgnored=true; noEffect(N,function() bn() end); clientIgnored=false
    ownShape("Fable",secret,"8123"); noEffect(N,function() bn() end)
end)
test("OpenMap BN faction classification never guesses unreadable values",function()
    local N=bnReady(); bn(); local p=N.Main.findRows()[1].place; yes(p); eq(p.faction,"opposite")
    bnInfo.factionName="Alliance"; bn(); eq(N.Main.findRows()[1].place.faction,"same")
    for _,bad in ipairs({false,secret,{},123,"Neutral",""}) do
        bnInfo.factionName=bad; bn(); eq(N.Main.findRows()[1].place.faction,nil)
    end
    bnInfo.factionName="Horde"
    for _,read in ipairs({function() return secret end,function() return nil end,function() error("unavailable") end}) do
        UnitFactionGroup=read; bn(); eq(N.Main.findRows()[1].place.faction,nil)
    end
end)
test("OpenMap GUILD and BN share one newest place and either route can withdraw",function()
    local N=bnReady(); om(); local a=N.Main.findRows()[1].place; yes(a); eq(a.route,"GUILD")
    clock=clock+5; bn(); local p=N.Main.findRows()[1].place; yes(p); eq(p.route,"BN"); eq(p.at,clock); eq(p.faction,"opposite")
    eq(N.Safe.count(N.Main.find.places),1); om("L0"); eq(N.Main.findRows()[1].place,nil)
    om(); bn("L0"); eq(N.Main.findRows()[1].place,nil)
    bn(); clock=clock+5; om(); p=N.Main.findRows()[1].place; eq(p.route,"GUILD"); eq(p.faction,nil); eq(p.at,clock)
end)
test("OpenMap optional BN event absent: loading and both chat routes still work",function()
    local original=methods.RegisterEvent
    methods.RegisterEvent=function(self,event) if event=="BN_CHAT_MSG_ADDON" then error("unsupported event") end; original(self,event) end
    local ok,N=pcall(omReady); methods.RegisterEvent=original; yes(ok); no(N.Main.error)
    eq(N.Main.frame.events.BN_CHAT_MSG_ADDON,nil); om(); yes(N.Main.findRows()[1].place)
    om("L0"); om(nil,"WHISPER"); eq(N.Main.findRows()[1].place.route,"WHISPER")
end)

local function sight(N,zone,at,own)
    local F,st=N.Find,N.Main.find
    if own then F.own(st,{name="Cedar Vale",source="own target",faction="opposite",class="ROGUE",level=47,layer="7086-7"},zone,at)
    else F.report(st,{sender="Birch Scout",zone=zone,at=at,enemies={{name="Cedar Vale",class="ROGUE",level=47}}},"Test Realm") end
end
local function withoutPlace(row)
    local out={}; for k,v in pairs(row) do if k~="place" then out[k]=v end end; return snapshot(out)
end
test("OpenMap tiers 1 sighting only: frozen legacy row fields stay identical",function()
    local N=omReady(); clock=100; sight(N,100,60,false)
    local expected={name="Cedar Vale",zone=100,at=60,spotter="Birch Scout",class="ROGUE",level=47,possible=true,relayed=false,
        age=40,same=false,probably=false,travel=false,status="possible match, seen by Birch Scout",canAsk=true}
    -- Section 4 adds named-evidence fields and a seen line; legacy action fields stay unchanged.
    local function legacy(row)
        local out={}
        for _,key in ipairs({"name","zone","at","spotter","class","level","possible","relayed","age","same","probably","travel","status","canAsk","own","layerKnown"}) do out[key]=row[key] end
        if row.own then out.spotter=nil end
        return out
    end
    eq(snapshot(legacy(N.Main.findRows()[1])),snapshot(expected),"legacy action projection with named session evidence")
    yes(N.Main.findRows()[1].seen); eq(N.Main.findRows()[1].seen.kind,"seen")
    sight(N,100,70,true)
    expected={name="Cedar Vale",own=true,zone=100,at=70,class="ROGUE",level=47,age=30,same=true,probably=false,travel=false,
        status="is on YOUR layer",canAsk=false,layerKnown=true} -- layerKnown: seen-unknown-layer adds it to own rows
    eq(snapshot(legacy(N.Main.findRows()[1])),snapshot(expected)); eq(N.Main.findRows()[1].place,nil)
end)
test("OpenMap tiers 2 place only: separate line, no layer, ask, hop, alert or relay",function()
    local N=bnReady(); establish(N)
    local before=snapshot({N.Main.store,N.Main.receiver,N.Main.peers,N.Main.relay,N.Main.share,N.Main.we,N.Main.emb,N.Main.hhNet,LayerEnemiesDB})
    local attempts,alerts=0,0
    N.Wire.send=function() attempts=attempts+1; error("OpenMap must never attempt any send") end
    N.Main.offerRelay=function() attempts=attempts+1; error("OpenMap must never offer a relay") end
    N.Main.findAlerts=function() alerts=alerts+1 end
    bn(); local row=N.Main.findRows()[1]; yes(row.place); eq(row.status,"shared position"); eq(row.canAsk,false)
    eq(row.at,nil); eq(row.zone,nil); eq(row.age,nil); eq(row.spotter,nil); eq(row.same,nil); eq(row.layer,nil)
    eq(row.class,nil); eq(row.level,nil); eq(row.travel,nil); no(N.Find.alert(N.Main.find,row,clock))
    eq(snapshot({N.Main.store,N.Main.receiver,N.Main.peers,N.Main.relay,N.Main.share,N.Main.we,N.Main.emb,N.Main.hhNet,LayerEnemiesDB}),before)
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    no(ui.ask:IsShown()); eq(ui.spotter,false); eq(ui.hopRecord,false); eq(ui.hostRow,false); ui.ask:Click()
    eq(#opened,0); eq(N.Wire.queued(),0); eq(attempts,0); eq(alerts,0); eq(#sent,0)
    yes(N.Main.findText(row):find("last shared position (OpenMap): Durotar 42,57",1,true))
    yes(N.Main.findText(row):find("enemy faction",1,true)); no(N.Main.findText(row):find("layer",1,true))
end)
test("OpenMap tiers 3 both same zone: sighting owns fields, place has its own age",function()
    local N=omReady(); clock=100; sight(N,200,60,false)
    om(); clock=110
    local row=N.Main.findRows()[1]; local expected=N.Find.new({"Cedar Vale"}); expected.locations=N.Main.find.locations; expected.known=N.Main.find.known
    eq(withoutPlace(row),snapshot(N.Find.rows(expected,clock,100,function() return false end)[1]))
    yes(row.place); eq(row.age,50); eq(row.place.age,10); eq(row.place.at,100); eq(row.zone,200); eq(row.place.map,200)
    eq(row.place.layer,nil); eq(row.place.spotter,nil); eq(row.place.zone,nil); no(N.Main.error)
end)
test("OpenMap tiers 4 conflicting zones and ages stay separate in text and UI",function()
    local N=bnReady(); clock=100; sight(N,100,60,false); bn(); clock=120
    local row=N.Main.findRows()[1]; eq(row.zone,100); eq(row.age,60); eq(row.at,60); eq(row.class,"ROGUE"); eq(row.level,47)
    yes(row.place); eq(row.place.map,200); eq(row.place.age,20); eq(row.place.class,"MAGE"); eq(row.place.level,60); eq(row.place.at,100)
    local text=N.Main.findText(row)
    yes(text:find("Ashenvale, 1 min ago",1,true)); yes(text:find("\nlast shared position (OpenMap): Durotar 42,57 · 20 s ago · enemy faction",1,true))
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui.sub:GetText():find("Ashenvale",1,true)); no(ui.sub:GetText():find("Durotar",1,true))
    yes(ui.place:GetText():find("Durotar 42,57 · 20 s ago · enemy faction",1,true)); no(ui.place:GetText():find("Ashenvale",1,true))
    yes(ui.ask:IsShown()); eq(ui.spotter,"Birch Scout"); no(ui.place:GetText():find("layer",1,true))
    yes(ui.place.point[5]-ui.place.height>-(ui.height-26),"place text fits above the action buttons")
end)
test("OpenMap tiers 5 arrival order is commutative and only the sighting alerts",function()
    local rows={}
    for _,placeFirst in ipairs({true,false}) do
        local N=omReady(); clock=100
        local sounds=0; PlaySound=function() sounds=sounds+1 end
        local nlog=#log
        if placeFirst then om(); N.Main.findAlerts(); eq(#log,nlog); eq(sounds,0) end
        sight(N,100,90,false); N.Main.findAlerts(); eq(#log,nlog+1); eq(sounds,1)
        if not placeFirst then om() end
        N.Main.findAlerts(); eq(#log,nlog+1); eq(sounds,1)
        no(log[#log]:find("OpenMap",1,true),"sighting alert does not carry a private place line")
        local row=N.Main.findRows()[1]; yes(row.place); rows[#rows+1]=snapshot(row); PlaySound=nil
    end
    eq(rows[1],rows[2],"same records, irrespective of arrival order")
end)
test("OpenMap tiers 6 known layer belongs only to the sighting",function()
    local N=omReady(); establish(N); clock=100; sight(N,100,90,false)
    local function rows() return N.Find.rows(N.Main.find,clock,100,function() return true end) end
    local before=withoutPlace(rows()[1]); om(); local row=rows()[1]
    eq(withoutPlace(row),before); yes(row.same); eq(row.canAsk,false)
    yes(row.place); eq(row.place.same,nil); eq(row.place.layer,nil); eq(row.place.zone,nil)
    local text=N.Main.findText(row); yes(text:find("already on your layer",1,true))
    local line=text:match("\n(.*)$"); yes(line); no(line:find("layer",1,true)); no(line:find("7086",1,true))
end)
test("OpenMap tiers 7 independent 600 and 150 second expiry falls back either way",function()
    local N=omReady(); clock=100; sight(N,100,100,false); clock=690; om(); clock=699.9
    local row=N.Main.findRows()[1]; yes(row.at); yes(row.place)
    clock=700; row=N.Main.findRows()[1]; eq(row.at,100); yes(row.lastKnown); eq(row.canAsk,false); eq(row.place.age,10)
    N=omReady(); clock=100; sight(N,100,100,false); om(); clock=249.9; yes(N.Main.findRows()[1].place)
    clock=250; row=N.Main.findRows()[1]; eq(row.place,nil); eq(row.at,100); eq(row.age,150)
    local bare=N.Find.new({"Cedar Vale"}); bare.locations=N.Main.find.locations; bare.known=N.Main.find.known
    eq(snapshot(row),snapshot(N.Find.rows(bare,clock,100,function() return false end)[1]))
end)
test("OpenMap tiers 8 ten-minute place stream never refreshes a sighting or calls findAlerts",function()
    local N=omReady(); clock=100; sight(N,100,100,false); N.Main.findAlerts()
    local loc=N.Main.find.locations["Cedar Vale"]; local alerts=snapshot(N.Main.find.alerts); local nlog=#log; local calls=0
    N.Main.findAlerts=function() calls=calls+1 end
    for i=1,60 do
        clock=100+i*10; om(); local row=N.Main.findRows()[1]
        yes(row.place); eq(row.place.at,clock); eq(row.place.age,0)
        eq(loc.at,100); eq(loc.zone,100); eq(snapshot(N.Main.find.alerts),alerts); eq(#log,nlog); eq(calls,0)
        eq(row.at,100); eq(row.age,i*10); if i==60 then yes(row.lastKnown); no(row.canAsk) end
    end
    eq(#sent,0); eq(N.Wire.queued(),0)
end)
test("OpenMap tiers 9 L0 clears only place; layer boundary clears only sightings",function()
    local N=omReady(); clock=100; sight(N,100,90,false); om()
    local before=withoutPlace(N.Main.findRows()[1]); om("L0"); local row=N.Main.findRows()[1]
    eq(withoutPlace(row),before); eq(row.place,nil)
    om(); local place=snapshot(N.Main.findRows()[1].place); N.Find.boundary(N.Main.find)
    row=N.Main.findRows()[1]; eq(row.at,90); yes(row.canAsk); eq(snapshot(row.place),place)
    sight(N,100,90,false); N.Main.boundary(200); eq(N.Main.findRows()[1].at,90); no(N.Main.findRows()[1].canAsk); eq(snapshot(N.Main.findRows()[1].place),place)
end)

test("OpenMap chat ignore API field failure stays silent like an unreadable lookup",function()
    local N=omReady(); om(); yes(N.Main.findRows()[1].place)
    C_FriendList=setmetatable({},{__index=function() error("API field unavailable") end})
    noEffect(N,function() om("L0") end)
end)
test("OpenMap presentation: faction known or unknown, zone fallback and tracked slash output",function()
    local N=bnReady(); bn()
    local function text() return N.Main.findText(N.Main.findRows()[1]) end
    yes(text():find("enemy faction",1,true))
    bnInfo.factionName="Alliance"; bn(); yes(text():find("your faction",1,true)); no(text():find("enemy faction",1,true))
    bnInfo.factionName=secret; bn(); no(text():find("faction",1,true))
    om(); no(text():find("faction",1,true))
    om("L1\t999999\t1.0000\t0.0000\t\t0"); yes(text():find("zone 999999 100,0",1,true))
    local nlog=#log; SlashCmdList.LAYERENEMIES("find Cedar Vale")
    eq(#log,nlog+1); yes(log[#log]:find("last shared position (OpenMap): zone 999999 100,0",1,true))
    local saved=snapshot(LayerEnemiesDB); bn(); eq(snapshot(LayerEnemiesDB),saved)
    SlashCmdList.LAYERENEMIES("find"); eq(next(N.Main.find.places),nil); eq(#N.Main.findRows(),0)
end)
test("OpenMap UI pool reuse hides stale places and drops former sighting actions",function()
    local N=omReady(); clock=100; sight(N,100,90,false); om()
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]; yes(rawget(ui,"place")); yes(ui.place:IsShown()); yes(ui.ask:IsShown())
    local normal=N.Main.findRows()[1]; eq(normal.canAsk,true)
    clock=3700; om(); N.UI.render(); no(ui.ask:IsShown()); eq(ui.spotter,false); eq(ui.hopRecord,false)
    ui.ask.scripts.OnClick(); eq(#opened,0); eq(#sent,0)
    om("L0"); N.UI.render(); no(ui.place:IsShown()); no(ui.ask:IsShown()); yes(ui.sub:GetText():find("Not located",1,true))
    om(); N.UI.render(); yes(ui.place:IsShown())
    N.Main.track("Cedar Vale",true); N.Main.track("Birch Grove"); N.UI.render()
    no(ui.place:IsShown()); eq(ui.tracked,"Birch Grove"); no(ui.ask:IsShown()); eq(ui.spotter,false)
end)

test("OpenMap malformed precision cannot refresh an identical older place",function()
    local N=omReady(); om(); local row=N.Main.findRows()[1]; yes(row.place); local at=row.place.at
    clock=clock+5
    for _,x in ipairs({"0.42","0.42000"}) do
        om("L1\t200\t"..x.."\t0.5700\tMAGE\t60")
        eq(N.Main.findRows()[1].place.at,at,"reject rather than refresh equal coordinates with invalid precision")
    end
end)

test("OpenMap BN qualified realm suffix is case folded",function()
    local N=bnReady("Cedar")
    bnInfo.characterName="Cedar-tEsTrEaLm"; bnInfo.realmName="Test Realm"; bn()
    local p=N.Main.find.places.Cedar; yes(p,"a case-only suffix difference is the same realm"); eq(p.route,"BN")
    bnInfo.characterName="Cedar-Foreign"; noEffect(N,function() bn("L0") end)
end)
test("OpenMap BN display realm removes both spaces and hyphens",function()
    for _,realm in ipairs({"Test-Realm","Test - Realm"}) do
        local N=bnReady("Cedar"); bnInfo.characterName="Cedar"; bnInfo.realmName=realm; bn()
        local p=N.Main.find.places.Cedar; yes(p,"display realm normalizes to the home realm"); eq(p.route,"BN")
    end
end)
test("OpenMap qualified home-realm watch entry matches only the full sender",function()
    for _,route in ipairs({"GUILD","WHISPER","BN"}) do
        local N=bnReady("Cedar-TestRealm")
        if route=="BN" then bnInfo.characterName="CEDAR"; bn()
        else om(nil,route,"CEDAR-TestRealm") end
        local p=N.Main.find.places["Cedar-TestRealm"]; yes(p,"qualified watch match on "..route); eq(p.route,route)
        noEffect(N,function() om("L0", "GUILD", "Cedar") end)
        noEffect(N,function() om("L0", "GUILD", "Cedar-Foreign") end)
    end
end)
test("OpenMap UTF-8 own identity is rejected even in a different case",function()
    for _,route in ipairs({"GUILD","WHISPER","BN"}) do
        local N=bnReady("élodie łan"); ownShape("Élodie","Łan","Test Realm")
        bnInfo.characterName="élodie łan"
        noEffect(N,function() if route=="BN" then bn() else om(nil,route,"élodie łan-TestRealm") end end)
        eq(next(N.Main.find.places),nil,"self did not create a place")
        N.Main.track("élodie vale"); om(nil,"GUILD","Élodie Vale-TestRealm")
        yes(N.Main.find.places["élodie vale"],"different surname is not self")
    end
end)
test("OpenMap decoder directly enforces the 64-byte limit",function()
    local N=omReady()
    local line="L1\t100\t0.0001\t0.9999\t"..string.rep("A",40).."\t80"; eq(#line,64)
    local p=N.OpenMap.decode(line); yes(p); eq(p.class,string.rep("A",40))
    line="L1\t100\t0.0001\t0.9999\t"..string.rep("A",41).."\t80"; eq(#line,65)
    eq(N.OpenMap.decode(line),nil,"grammar-valid 65 bytes must fail without Main's guard")
end)
test("OpenMap stored BN place has only the location field allowlist",function()
    local N=bnReady(); bnInfo.accountID=71; bn()
    local p=N.Main.find.places["Cedar Vale"]; yes(p)
    local expected={map=200,x=.42,y=.57,class="MAGE",level=60,at=clock,route="BN",faction="opposite"}
    eq(snapshot(p),snapshot(expected),"no account data, identifiers or other extra keys retained")
end)
test("OpenMap row projection never aliases or mutates its stored place",function()
    local N=omReady(); om(); local stored=N.Main.find.places["Cedar Vale"]; yes(stored)
    local before=snapshot(stored); clock=clock+5
    local row=N.Main.findRows()[1]; yes(row.place); no(rawequal(row.place,stored),"row owns its place copy")
    eq(row.place.age,5); eq(snapshot(stored),before,"calculating age leaves storage untouched")
    row.place.map=999; row.place.at=0; row.place.extra=true
    eq(snapshot(stored),before,"editing a projected row cannot change storage")
    local nextRow=N.Main.findRows()[1]; no(rawequal(nextRow.place,row.place)); eq(nextRow.place.map,200)
    eq(nextRow.place.age,5); eq(nextRow.place.extra,nil)
end)
test("OpenMap place-only text stays inside its card above Clear",function()
    local N=omReady(); om(); N.UI.toggle(); N.UI.select("find"); local r=N.UI.pool[1]
    yes(r.place:IsShown()); eq(r.sub:GetText(),""); no(r.ask:IsShown())
    eq(r.place.point[1],"TOPLEFT"); eq(r.place.point[2],r); eq(r.place.point[3],"TOPLEFT")
    local left,top=r.place.point[4],-r.place.point[5]
    yes(left>=0 and left+r.place.width<=r.width,"place fits horizontally inside card")
    yes(top>=0 and top+r.place.height<=r.height,"place fits vertically inside card")
    yes(top+r.place.height<=r.height-r.clear.point[5]-r.clear.height,"place stays above Clear")
end)
test("OpenMap combined-row text avoids both sighting text and buttons",function()
    local N=omReady(); clock=100; sight(N,100,90,false); om(); N.UI.toggle(); N.UI.select("find")
    local r=N.UI.pool[1]; yes(r.place:IsShown()); yes(r.ask:IsShown()); no(r.sub:GetText()=="")
    eq(r.place.point[1],"TOPLEFT"); eq(r.place.point[2],r); eq(r.place.point[3],"TOPLEFT")
    eq(r.sub.point[1],"TOPLEFT"); eq(r.sub.point[2],r); eq(r.sub.point[3],"TOPLEFT")
    local top=-r.place.point[5]; local bottom=top+r.place.height
    yes(top>=-r.sub.point[5]+r.sub.height,"place begins below the sighting text box")
    yes(bottom<=r.height-r.ask.point[5]-r.ask.height,"place ends above Ask")
    yes(bottom<=r.height-r.clear.point[5]-r.clear.height,"place ends above Clear")
end)
test("OpenMap last-place expiry restores compact rows and clamps five-name scrolling",function()
    local N=omReady(); clock=100; om()
    for _,name in ipairs({"Birch Grove","Cedar Moss","Dawn Vale","Elm Frost"}) do N.Main.track(name) end
    N.UI.toggle(); N.UI.select("find"); local U=N.UI
    eq(#N.Main.findRows(),5); eq(U.pool[1].height,142)
    for _=1,9 do U.body.scripts.OnMouseWheel(nil,-1) end
    eq(U.offset,2); eq(U.pool[1].tracked,"Cedar Moss")
    clock=249.9; U.render(); eq(U.offset,2); eq(U.pool[1].height,72)
    clock=250; U.render(); eq(next(N.Main.find.places),nil)
    eq(U.offset,2,"three compact missing rows fit after the last place expires")
    for i=1,3 do yes(U.pool[i]:IsShown()); eq(U.pool[i].height,72); eq(U.pool[i].sub.height,14); no(U.pool[i].place:IsShown()) end
    eq(U.pool[1].tracked,"Cedar Vale"); eq(U.pool[2].tracked,"Dawn Vale"); eq(U.pool[3].tracked,"Elm Frost")
    eq(U.pool[1].point[5],-70); eq(U.pool[2].point[5],-146); eq(U.pool[3].point[5],-222)
    eq(U.hint:GetText(),"Mouse wheel: 3–5 of 5")
end)

end
assert(loadfile("test/call.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,deliver=deliver,advance=advance,
    drain=drain,secret=secret,player=player,establish=establish,abc=abc,
    sent=function() return sent end,log=function() return log end,clock=function() return clock end,
    timers=function() return timers end,frames=function() return frames end,
    instance=function(v) inInstance=v end,combat=function(v) combat=v end,
    unit=function(k,v) units[k]=v end})
-- Hop-any: explicit click is a stack boundary, not a timer permission flag.
local function anyClick(N,button)
    clickStack=true
    if button then N.UI.hopAny:Click() else SlashCmdList.LAYERENEMIES("hop any") end
    clickStack=false
    no(N.Main.error,"hop-any runtime error")
end
local function anyRows(n)
    for i=1,n do whoRows[i]={fullName="Seeker "..abc(i),area="Ashenvale"} end
end
local function anyFixture()
    local N=loadAddon(); establish(N); clock=math.ceil(clock); anyRows(49); return N
end
test("hop-any click calls who synchronously once and waits five seconds",function()
    local N=anyFixture()
    anyClick(N); eq(#whoCalls,1); eq(whoCalls[1].term,'z-"Ashenvale"'); eq(whoCalls[1].origin,1)
    eq(#sent,0); anyClick(N); eq(#whoCalls,1)
    advance(4); eq(#sent,0); advance(1); eq(#sent,0)
    yes(table.concat(log,"\n"):find("the game did not answer the search",1,true))
    deliver("WHO_LIST_UPDATE"); advance(120); eq(#sent,0); eq(#whoCalls,1)
end)

test("hop-any 49 rows send eight initially then the whole list within 45 rounds",function()
    local N=anyFixture(); anyClick(N); advance(1); eq(#sent,0)
    deliver("WHO_LIST_UPDATE"); eq(#sent,8); eq(#whoRead,49)
    eq(sent[1].text,"inv layer <LS 100 not 7086-0 25.0,75.0>")
    local req=N.GuildHost.parse(sent[1].text); yes(req); eq(req.nots[1],"7086-0")
    for i=9,49 do advance(.5); eq(#sent,i-1); advance(.5); eq(#sent,i) end
    for _=1,120 do advance(1); deliver("WHO_LIST_UPDATE"); eq(#sent,49) end
    advance(1); yes(table.concat(log,"\n"):find("asked 49 players, no host answered",1,true))
    for _=1,600 do advance(1) end
    eq(#sent,49); eq(#whoCalls,1); eq(#accepts,0)
end)
test("hop-any events timers and replies without a click never start a round",function()
    local N=anyFixture()
    for _=1,600 do
        deliver("WHO_LIST_UPDATE"); deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-7|100|h","WHISPER","Seeker a")
        deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(1)
    end
    eq(#sent,0); eq(#whoCalls,0); eq(#accepts,0); eq(#whoRead,0)
end)
test("hop-any stop cancels and ten second click guard is exact",function()
    local N=anyFixture(); anyClick(N); local start=clock
    deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    SlashCmdList.LAYERENEMIES("hop stop"); advance(9); anyClick(N); eq(#whoCalls,1)
    advance(1); eq(clock-start,10); anyClick(N); eq(#whoCalls,2)
    deliver("WHO_LIST_UPDATE"); eq(#sent,16); no(sent[1].target==sent[9].target)
    SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,16)
end)
test("hop-any filters rows and prioritizes listed hosts then same-zone rows",function()
    local N=anyFixture()
    whoRows={{fullName="Me",area="Ashenvale"},{fullName="Me-TestRealm",area="Ashenvale"},
        {fullName="Other Zone",area="Durotar"},{fullName="Ignored Peer",area="Ashenvale"},
        {fullName="Offline Peer",area="Ashenvale"},{fullName="Recent Peer",area="Ashenvale"},
        {fullName=secret,area="Ashenvale"},{fullName="Bad123",area="Ashenvale"},
        {fullName="Else Peer",area=secret},{fullName="Ordinary Peer",area="Ashenvale"},
        {fullName="ordinary peer-TestRealm",area="Ashenvale"},{fullName="Guild Peer",area="Ashenvale"},
        {fullName="Host Peer",area="Ashenvale"},{fullName="Me-OtherRealm",area="Ashenvale"}}
    C_FriendList.IsIgnored=function(n) return n=="Ignored Peer" end
    N.Wire.offlineUntil=function(n) if n=="Offline Peer" then return clock+3600 end end
    N.Main.invite.asked["recent peer"]=clock
    roster={{"Guild Peer",true}}
    LayerSwapDB={book={["Host Peer"]={layer="8000-9",zone=100,at=wall,host=true}}}
    loaded.LayerSwap=true
    anyClick(N); deliver("WHO_LIST_UPDATE"); for _=1,7 do advance(1) end
    eq(#sent,5); eq(sent[1].target,"Host Peer"); eq(sent[2].target,"Ordinary Peer")
    eq(sent[3].target,"Guild Peer"); eq(sent[4].target,"Me-OtherRealm"); eq(sent[5].target,"Other Zone")
end)
test("hop-any never reads a fiftieth who row",function()
    local N=anyFixture(); anyRows(80)
    for i=1,49 do whoRows[i].area="Durotar" end
    anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#whoRead,49); eq(#sent,8)
    for _=1,45 do advance(1) end; eq(#sent,49)
    for _,v in ipairs(sent) do no(v.target=="Seeker "..abc(50)) end
end)
local anyGuards={
    guild=function(N) N.Main.setConsent("guild") end,
    grouped=function() grouped=true end,
    groupUnknown=function() IsInGroup=function() return nil end end,
    groupSecret=function() IsInGroup=function() return secret end end,
    instance=function() inInstance=true end,
    instanceUnknown=function() IsInInstance=function() error("unreadable") end end,
    combat=function() combat=true end,
    combatUnknown=function() InCombatLockdown=function() return nil end end,
    zone=function() map=nil end,
    zoneName=function() local f=C_Map.GetMapInfo; C_Map.GetMapInfo=function(id) local v=f(id); if v then v.name=secret end; return v end end,
    layer=function(N) N.Main.store.bulo=nil end,
    ambiguous=function(N) N.Main.store.ambiguous=function() return true end end,
    ownName=function() UnitName=function() return secret end end,
    ask=function(N) N.Main.invite.pending={at=clock,name="Old Peer"} end,
    hop=function(N) N.Main.hop.pending={at=clock,name="Old Peer"} end,
    tag=function() WHO_TAG_ZONE=nil end,
    tagSecret=function() WHO_TAG_ZONE=secret end,
    sendWho=function() C_FriendList.SendWho=nil end,
    countWho=function() C_FriendList.GetNumWhoResults=nil end,
    readWho=function() C_FriendList.GetWhoInfo=nil end,
    enum=function() Enum=nil end,
    cooldown=function(N) N.Main.invite.lastAsk=clock end,
}
for label,setup in pairs(anyGuards) do
    test("hop-any click guard "..label.." sends and searches nothing",function()
        local N=anyFixture(); setup(N); local before=#log
        anyClick(N); eq(#whoCalls,0); eq(#sent,0); yes(#log>before)
        deliver("WHO_LIST_UPDATE"); advance(600); eq(#sent,0); eq(#whoCalls,0)
    end)
end
for _,kind in ipairs({"group","combat","instance","zone","guild","stop"}) do
    test("hop-any stop on "..kind.." cannot resume from events or timers",function()
        local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
        if kind=="group" then grouped=true; deliver("GROUP_ROSTER_UPDATE")
        elseif kind=="combat" then combat=true; deliver("PLAYER_REGEN_DISABLED")
        elseif kind=="instance" then inInstance=true
        elseif kind=="zone" then map=200; deliver("ZONE_CHANGED_NEW_AREA")
        elseif kind=="guild" then N.Main.setConsent("guild")
        else SlashCmdList.LAYERENEMIES("hop stop") end
        advance(1); eq(#sent,8)
        grouped,combat,inInstance,map=false,false,false,100; N.Main.setConsent("public")
        for _=1,600 do advance(1); deliver("WHO_LIST_UPDATE") end
        eq(#sent,8); eq(#whoCalls,1)
    end)
end
for _,result in ipairs({3,4,"error"}) do
    test(result==3 and "hop-any Wire throttle retries the head until the list ends" or ("hop-any stops forever on Wire result "..tostring(result)),function()
        local N=anyFixture(); sendResult=result=="error" and function() error("client send failure") end or result
        anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
        sendResult=0; for _=1,600 do advance(1) end; eq(#sent,result==3 and 50 or 1)
    end)
end
test("hop-any offline attempts never arm acceptance; an unrelated invite stops fanout",function()
    local N=anyFixture(); sendResult=12; anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(#accepts,0)
    sendResult=0; for _=1,120 do advance(1) end; eq(#sent,8)
    no(N.Main.invite.pending and N.Main.invite.pending.short=="seeker a")
end)

local function anyReply(name,flag,layer,zone,kind,me)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard "..(me or "Me").."|"..(layer or "8000-7").."|"..(zone or "100").."|"..(flag or "h"),kind or "WHISPER",name)
end
test("hop-any host replies do not stop fanout and unasked whole names do not enter the book",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    anyReply("Seeker a-Elsewhere"); anyReply("Seeker z"); anyReply("Outsider Peer")
    eq(N.Safe.count(N.Main.heard.heard),0)
    advance(1); eq(#sent,9)
    anyReply("Seeker a"); for _=1,41 do advance(1) end; advance(121); eq(#sent,49)
    yes(table.concat(log,"\n"):find("answered as a host but sent no invite",1,true))
    eq(N.Main.hopAnyState.quiet["seeker a"],nil); yes(N.Main.hopAnyState.quiet["seeker b"])
end)
test("hop-any wrong route addressee zone same layer and nonhost do not stop",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    anyReply("Seeker a","h",nil,nil,"GUILD"); anyReply("Seeker a","h",nil,nil,nil,"Someone Else")
    anyReply("Seeker a","h",nil,"200"); anyReply("Seeker a","h","7086-1")
    anyReply("Seeker a","-" ); deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Seeker a")
    advance(1); eq(#sent,9); advance(1); eq(#sent,10)
    eq(N.Main.hopAnyState.round.negative,1)
    SlashCmdList.LAYERENEMIES("hop stop"); eq(N.Main.hopAnyState.quiet["seeker a"],nil)
end)
test("hop-any asked invite stops sends and autoaccepts once, no foreign alias",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    deliver("PARTY_INVITE_REQUEST","Unasked Person"); deliver("PARTY_INVITE_REQUEST","Seeker a-Elsewhere"); eq(#accepts,0)
    advance(1); eq(#sent,8)
    deliver("PARTY_INVITE_REQUEST","Seeker a-TestRealm"); eq(#accepts,1)
    deliver("PARTY_INVITE_REQUEST","Seeker a"); deliver("PARTY_INVITE_REQUEST","Seeker b"); eq(#accepts,1)
    advance(120); eq(#sent,8)
end)
test("hop-any asked invite stops sends even with autoaccept disabled",function()
    local N=anyFixture(); N.Main.setAutoHop(false); anyClick(N); deliver("WHO_LIST_UPDATE")
    deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(120); eq(#sent,8); eq(#accepts,0)
end)
local function anyJoined()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); deliver("PARTY_INVITE_REQUEST","Seeker a")
    eq(#accepts,1); grouped=true; units.party1={name="Seeker a",leader=true}
    deliver("GROUP_ROSTER_UPDATE"); no(N.Main.error); return N
end
test("hop-any different known key in same zone leaves after three seconds",function()
    local N=anyJoined(); N.Main.applyLayer("8000-8","test")
    advance(2.9); eq(#leaves,0); advance(.2); eq(#leaves,1)
    for _=1,600 do advance(1) end; eq(#sent,8); eq(#leaves,1)
end)
test("hop-any same key never succeeds and fails at thirty seconds",function()
    local N=anyJoined(); N.Main.applyLayer("7086-9","test")
    advance(3.1); eq(#leaves,0); advance(26.8); eq(#leaves,0); advance(.2); eq(#leaves,1)
    yes(table.concat(log,"\n"):find("hop failed",1,true))
end)
test("hop-any unknown key never succeeds",function()
    local N=anyJoined(); N.Main.store.bulo=nil; N.Main.autoTick(); advance(3.1); eq(#leaves,0)
    advance(27); eq(#leaves,1); yes(table.concat(log,"\n"):find("hop failed",1,true))
end)
for _,change in ipairs({"zone","instance","raid","leader","otherLeader","combat"}) do
    test("hop-any auto-leave respects "..change,function()
        local N=anyJoined(); N.Main.applyLayer("8000-8","test")
        if change=="zone" then map=200; deliver("ZONE_CHANGED_NEW_AREA")
        elseif change=="instance" then inInstance=true
        elseif change=="raid" then raid=true
        elseif change=="leader" then leader=true
        elseif change=="otherLeader" then units.party1.leader=false
        else combat=true end
        advance(4); eq(#leaves,0)
        if change=="combat" then combat=false; advance(1); eq(#leaves,1) end
    end)
end
test("hop-any no-answer table lasts six hours and a second round reaches different names",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    for _=1,170 do advance(1) end
    eq(#sent,49); eq(N.Safe.count(N.Main.hopAnyState.quiet),49)
    anyClick(N); deliver("WHO_LIST_UPDATE"); for _=1,10 do advance(1) end
    eq(#sent,49); local seen={}; for _,v in ipairs(sent) do no(seen[v.target]); seen[v.target]=true end
    local first=sent[1].at; clock=first+21600-1
    anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,49)
    clock=first+21600+10
    anyClick(N); deliver("WHO_LIST_UPDATE"); eq(sent[50].target,"Seeker a")
    no(LayerEnemiesDB.quiet); no(LayerEnemiesDB.hopAnyState)
    N=loadAddon(); eq(N.Safe.count(N.Main.hopAnyState.quiet),0)
end)
test("hop-any no-answer table evicts oldest at three hundred and prunes exactly six hours",function()
    local N=anyFixture(); local H,st=N.HopAny,N.Main.hopAnyState
    for i=1,301 do
        local key="seeker "..abc(i)
        st.round={asked={[key]={name=key,at=i}},answered={}}
        H.close(st,i)
    end
    eq(N.Safe.count(st.quiet),300); eq(st.quiet["seeker a"],nil); eq(st.quiet["seeker "..abc(301)],301)
    H.prune(st,21601); eq(N.Safe.count(st.quiet),300)
    H.prune(st,21602); eq(N.Safe.count(st.quiet),299)
end)
test("hop-any UI is friendly-only with disabled reason and Stop state",function()
    local N=anyFixture(); N.UI.toggle(); N.UI.select("friendly")
    yes(N.UI.hopAny:IsShown()); eq(N.UI.hopAny.label:GetText(),"Hop to another layer"); no(N.UI.hopAny.disabled)
    anyClick(N,true); eq(#whoCalls,1); N.UI.render(); eq(N.UI.hopAny.label:GetText(),"Stop")
    N.UI.hopAny:Click(); advance(6); eq(#sent,0); N.UI.render()
    yes(N.UI.hopAny.disabled); yes(N.UI.hopAny.reason:find("10 s",1,true))
    advance(10); N.Main.setConsent("guild"); N.UI.render(); yes(N.UI.hopAny.disabled)
    yes(N.UI.hopAny.reason:find("guild-only",1,true)); N.UI.select("local"); no(N.UI.hopAny:IsShown())
end)

test("hop-any caller policy traps disguised calls and cannot be widened from addon tables",function()
    local N=anyFixture()
    N.Adapters.WHO_CALLERS={["@LayerEnemies/Hop.lua"]=true}
    local evil=assert(loadstring('return function() local f=C_FriendList["Send".."Who"]; pcall(f,"query",1) end',"@LayerEnemies/Hop.lua"))()
    clickStack=true; evil(); clickStack=false; eq(forbidden,1); forbidden=0
    local out=assert(loadstring('return function(N) local f=N.Wire.send; local ok=f("LayerSwap","inv layer <LS 100 not 7086-0 25.0,75.0>","WHISPER","Policy Peer",{prio="click"}); return ok end',"@LayerEnemies/Hosts.lua"))()
    N.Main.ANY_CALLERS={["@LayerEnemies/Hosts.lua"]=true}; out(N); eq(forbidden,1); forbidden=0
    -- Even the permitted adapter is forbidden outside the click stack.
    N.Adapters.who('z-"Ashenvale"'); eq(forbidden,1); forbidden=0
end)
test("hop-any one reserve per click and every attempted name shares Invite cooldown",function()
    local N=anyFixture(); local reserve=N.Invite.reserve; local calls=0
    N.Invite.reserve=function(...) calls=calls+1; return reserve(...) end
    anyClick(N); deliver("WHO_LIST_UPDATE"); for _=1,41 do advance(1) end
    eq(calls,1); eq(#sent,49)
    for _,v in ipairs(sent) do eq(N.Main.invite.asked[N.Invite.key(v.target)],v.at) end
    SlashCmdList.LAYERENEMIES("hop stop"); advance(10)
    local ok=N.Invite.reserve(N.Main.invite,{name="Seeker a",short="seeker a"},clock); no(ok)
end)
test("hop-any replies and invites expire from first send, never renew their window",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); advance(1); anyReply("Seeker b")
    for _=1,40 do advance(1) end; advance(78); anyReply("Seeker a")
    advance(2); deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(#accepts,0)
    eq(#sent,49); no(N.Main.hopAnyState.round)
end)
for _,what in ipairs({"paused","budget"}) do
    test("hop-any Wire local "..what.." retries the same head without a Wire queue",function()
        local N=anyFixture()
        if what=="paused" then sendResult=3 end
        for i=1,(what=="paused" and 1 or 8) do N.Wire.send("LayerSwap","inv layer <LS 100 want 8000-0>","WHISPER","Budget "..abc(i),{prio="click",hopAny=true}) end
        local before=#sent; sendResult=0; anyClick(N); deliver("WHO_LIST_UPDATE")
        eq(#sent,before); eq(N.Wire.queued(),0); for _=1,45 do advance(1) end; eq(#sent,before+(what=="budget" and 44 or 49))
        for _=1,121 do advance(1) end
        no(N.Main.hopAnyState.round)
    end)
end
for _,value in ipairs({"throw","false","secret"}) do
    test("hop-any refused who "..value.." never arms late results",function()
        local N=anyFixture()
        C_FriendList.SendWho=function() if value=="throw" then error("unavailable") end; return value=="secret" and secret or false end
        anyClick(N); deliver("WHO_LIST_UPDATE"); advance(600); eq(#sent,0); no(N.Main.hopAnyState.round)
    end)
end
test("hop-any unreadable who count and rows fail closed",function()
    for _,value in ipairs({"throw","nil","secret","fraction"}) do
        local N=anyFixture()
        C_FriendList.GetNumWhoResults=function() if value=="throw" then error("bad count") end; return value=="secret" and secret or value=="fraction" and .5 or nil end
        anyClick(N); deliver("WHO_LIST_UPDATE"); advance(8); eq(#sent,0); no(N.Main.error)
    end
    local N=anyFixture()
    C_FriendList.GetWhoInfo=function(i)
        if i==1 then return secret elseif i==2 then error("bad row") elseif i==3 then return {fullName="Valid Peer",area="Ashenvale"}
        else return setmetatable({},{__index=function() error("bad field") end}) end
    end
    anyClick(N); deliver("WHO_LIST_UPDATE"); advance(8); eq(#sent,1); eq(sent[1].target,"Valid Peer"); no(N.Main.error)
end)
test("hop-any all replies and invite paths refuse own identity becoming unreadable",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    UnitName=function() return secret end
    anyReply("Seeker a"); deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(600)
    eq(#accepts,0); eq(#sent,8); no(N.Main.hopAnyState.round)
end)
test("hop-any acceptance refusal is spent even for a local throttle",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    local calls=0; N.Wire.accept=function() calls=calls+1; return false,"throttled" end
    deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(11); deliver("PARTY_INVITE_REQUEST","Seeker a")
    eq(calls,1); eq(#accepts,0)
end)
test("hop-any active round cannot be overwritten by an existing named hop",function()
    local N=anyFixture()
    loaded.LayerSwap=true; LayerSwapDB={book={["Listed Peer"]={layer="8000-7",zone=100,host=true,at=wall}}}
    local rows=N.Main.candidates(); eq(#rows,1); local shown=N.Main.hostPreview(rows[1])
    anyClick(N); deliver("WHO_LIST_UPDATE"); advance(11)
    no(N.Main.hopHostTo(rows[1],shown)); eq(#sent,16); yes(N.Main.invite.pending.any)
end)
test("hop-any changed back before scheduled leave does not claim a move",function()
    local N=anyJoined(); N.Main.applyLayer("8000-8","test")
    N.Main.applyLayer("7086-9","test"); advance(4); eq(#leaves,0)
    advance(27); eq(#leaves,1); yes(table.concat(log,"\n"):find("hop failed",1,true))
end)

test("hop-any pace resists duplicate pumps and a long clock jump never catches up",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    for _=1,3 do advance(.25); N.Main.hopAnyPump(); eq(#sent,8) end
    advance(.25); N.Main.hopAnyPump(); eq(#sent,9)
    advance(60); N.Main.hopAnyPump(); eq(#sent,17)
    SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,17)
end)
test("hop-any Wire caller gate rejects a different function even in Main",function()
    local N=anyFixture()
    local fake=assert(loadstring('return function(N) local ok=N.Wire.send("LayerSwap","inv layer <LS 100 not 7086-0 25.0,75.0>","WHISPER","Policy Other",{prio="click"}); return ok end',"@LayerEnemies/Main.lua"))()
    fake(N); eq(forbidden,1); forbidden=0
end)
test("hop-any key learned before group event still compares with the key left",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(#accepts,1)
    N.Main.store.bulo="8000-9"; grouped=true; units.party1={name="Seeker a",leader=true}
    deliver("GROUP_ROSTER_UPDATE"); advance(3.1); eq(#leaves,1)
end)

test("hop-any not-hosting answer removes a remembered host without a per-reply line",function()
    local N=anyFixture(); N.Main.heard.heard["Seeker a"]={layer="8000-7",zone=100,host=true,at=wall}
    anyClick(N); deliver("WHO_LIST_UPDATE"); eq(sent[1].target,"Seeker a"); local before=#log
    anyReply("Seeker a","-"); eq(N.Main.heard.heard["Seeker a"],nil); eq(#log,before)
    advance(1); eq(#sent,9)
end)
test("hop-any instance entry event cancels even if it ends before the next pump",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    inInstance=true; deliver("PLAYER_ENTERING_WORLD"); inInstance=false
    advance(1); eq(#sent,8); no(N.Main.hopAnyState.round)
end)
test("hop-any auto-leave cancels on an out-and-back zone transition",function()
    local N=anyJoined(); N.Main.applyLayer("8000-8","test")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); map=100; deliver("ZONE_CHANGED_NEW_AREA")
    N.Main.applyLayer("9000-9","test"); advance(4); eq(#leaves,0); no(N.Main.auto.group)
end)
test("hop-any accepted hop still waiting for group blocks a new search",function()
    local N=anyFixture(); N.Main.auto.group={host="Old Peer",at=clock}
    anyClick(N); eq(#whoCalls,0); eq(#sent,0)
end)
test("hop-any line requires valid coordinates and never fabricates a position",function()
    local N=anyFixture(); local Hp=N.Hop
    eq(Hp.lineNot(100,"7086-8",0,1),"inv layer <LS 100 not 7086-0 0.0,100.0>")
    for _,bad in ipairs({secret,-1,1.1,".5"}) do eq(Hp.lineNot(100,"7086",bad,.5),nil) end
    C_Map.GetPlayerMapPosition=function() return nil end; anyClick(N); eq(#whoCalls,0); eq(#sent,0)
end)

test("hop-any observed invite is never reported as no invite after auto-off",function()
    local N=anyFixture(); N.Main.setAutoHop(false); anyClick(N); deliver("WHO_LIST_UPDATE")
    anyReply("Seeker a"); deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(121)
    eq(#sent,8); eq(#accepts,0)
    no(table.concat(log,"\n"):find("sent no invite",1,true))
    yes(table.concat(log,"\n"):find("invite arrived",1,true))
end)

-- Independent regression boundaries: no other event/guard may mask the one under test.
test("hop-any offline selection fills all eight slots with online candidates",function()
    local N=anyFixture()
    sendResult=12; N.Wire.send("LayerSwap","same","WHISPER","Seeker a",{prio="click"}); sendResult=0
    sent={}; advance(10)
    anyClick(N); deliver("WHO_LIST_UPDATE")
    eq(#sent,8); eq(sent[1].target,"Seeker b"); eq(sent[8].target,"Seeker i")
    eq(N.Main.hopAnyState.round.count,8) -- the first round only
end)
test("hop-any rejects nonwhisper replies before changing round or host state",function()
    for _,route in ipairs({"PARTY","RAID","CHANNEL"}) do
        local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
        anyReply("Seeker a","h",nil,nil,route)
        eq(N.Main.hopAnyState.round.phase,"send",route)
        eq(N.Safe.count(N.Main.hopAnyState.round.answered),0,route)
        eq(N.Safe.count(N.Main.heard.heard),0,route)
        advance(1); eq(#sent,9,route)
    end
end)
test("hop-any live zone guard precedes auto-leave without a zone event",function()
    local N=anyJoined(); N.Main.applyLayer("8000-8","test")
    map=200; clock=clock+3.1; N.Main.autoTick()
    eq(#leaves,0); no(N.Main.auto.group)
end)
test("hop-any painted Stop cancels a sending round before the next whisper",function()
    local N=anyFixture(); N.UI.toggle(); N.UI.select("friendly")
    anyClick(N,true); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    eq(N.UI.hopAny.label:GetText(),"Stop"); anyClick(N,true)
    no(N.Main.hopAnyState.round); no(N.Main.invite.pending)
    for _=1,600 do advance(1) end
    eq(#sent,8); eq(#whoCalls,1)
end)
test("hop-any live group guard stops before the roster event",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
    grouped=true; clock=clock+1; N.Main.hopAnyPump()
    eq(#sent,8); no(N.Main.hopAnyState.round)
    grouped=false; for _=1,600 do advance(1) end
    eq(#sent,8); eq(#whoCalls,1)
end)

test("hop-any stale painted Stop after expiry never starts another round",function()
    local N=anyFixture(); N.UI.toggle(); N.UI.select("friendly"); anyClick(N,true)
    deliver("WHO_LIST_UPDATE"); for _=1,41 do advance(1) end
    eq(#sent,49); advance(78.5); eq(N.UI.hopAny.label:GetText(),"Stop")
    clock=clock+.7; N.Main.hopAnyPump(); no(N.Main.hopAnyState.round)
    anyClick(N,true); eq(#whoCalls,1,"a stale Stop is never a new search")
    deliver("WHO_LIST_UPDATE"); for _=1,8 do advance(1) end
    eq(#sent,49); no(N.Main.hopAnyState.round)
end)

test("hop-any expiry requests a next-frame repaint before the age tick",function()
    local N=anyFixture(); N.UI.toggle(); N.UI.select("friendly"); anyClick(N,true)
    deliver("WHO_LIST_UPDATE"); for _=1,41 do advance(1) end
    advance(78.5); eq(N.UI.hopAny.label:GetText(),"Stop")
    clock=clock+.7; N.Main.hopAnyPump(); no(N.Main.hopAnyState.round)
    drain(); eq(N.UI.hopAny.label:GetText(),"Hop to another layer")
    anyClick(N,true); eq(#whoCalls,2)
end)

test("hop-any stale button mode cannot stop a later slash-started round",function()
    local N=anyFixture(); N.UI.toggle(); N.UI.select("friendly")
    anyClick(N); local first=N.Main.hopAnyState.round
    eq(N.UI.hopAny.label:GetText(),"Hop to another layer")
    anyClick(N,true); eq(N.Main.hopAnyState.round,first); eq(#whoCalls,1)
    eq(N.UI.hopAny.label:GetText(),"Stop")
    N.Main.hopAnyStop(); clock=clock+30; anyClick(N)
    local second=N.Main.hopAnyState.round; yes(second); no(first==second)
    anyClick(N,true); eq(N.Main.hopAnyState.round,second); eq(#whoCalls,2)
    anyClick(N,true); no(N.Main.hopAnyState.round)
end)

test("hop-any reserves the final attempt before a reentrant send edge",function()
    local N=anyFixture(); anyClick(N)
    local fired,observed=false,{}
    sendResult=function()
        if #sent==8 and not fired then
            fired=true
            local r=N.Main.hopAnyState.round
            observed={count=r.count,index=r.index,at=r.lastAttempt,nameAt=N.Main.invite.asked["seeker h"]}
            N.Main.hopAnyPump()
        end
        return 0
    end
    deliver("WHO_LIST_UPDATE"); eq(#sent,8,"no ninth request in the first round")
    eq(observed.count,8); eq(observed.index,9); eq(observed.at,clock); eq(observed.nameAt,clock)
    eq(N.Main.hopAnyState.round.count,8); no(N.Main.error)
    for _=1,41 do advance(1) end; eq(#sent,49)
    local batches={}; for _,v in ipairs(sent) do batches[v.at]=(batches[v.at] or 0)+1; yes(batches[v.at]<=8) end
    advance(121); eq(#sent,49); eq(#whoCalls,1)
end)

test("hop-any reentrant Stop cannot recreate pending acceptance or fault",function()
    local N=anyFixture(); anyClick(N)
    sendResult=function() SlashCmdList.LAYERENEMIES("hop stop"); return 0 end
    deliver("WHO_LIST_UPDATE")
    no(N.Main.error,"Stop during send must not dereference the closed round")
    no(N.Main.hopAnyState.round); no(N.Main.invite.pending); eq(#sent,1)
    deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(#accepts,0)
    advance(600); eq(#sent,1)
end)

test("hop-any cannot dispatch again while a send is still in flight",function()
    local N=anyFixture(); anyClick(N)
    local fired=false
    sendResult=function()
        if not fired then fired=true; clock=clock+2; N.Main.hopAnyPump(); eq(#sent,1) end
        return 0
    end
    deliver("WHO_LIST_UPDATE"); eq(#sent,8); eq(N.Main.hopAnyState.round.count,8)
    advance(1); eq(#sent,10); no(N.Main.error)
end)

test("hop-any old send completion cannot mutate a replacement round",function()
    local N=anyFixture(); anyClick(N); local old=N.Main.hopAnyState.round
    sendResult=function()
        N.Main.hopAnyStop(); clock=clock+30; anyClick(N)
        return 0
    end
    deliver("WHO_LIST_UPDATE")
    local replacement=N.Main.hopAnyState.round
    no(N.Main.error); yes(replacement); no(old==replacement)
    eq(replacement.phase,"who"); eq(replacement.count,0); eq(replacement.sent,0)
    eq(N.Safe.count(replacement.asked),0); no(N.Main.invite.pending)
    eq(#whoCalls,2); eq(#sent,1)
end)

test("hop-any rechecks ignore at dispatch and never trusts a skipped candidate",function()
    local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
    C_FriendList.IsIgnored=function(name) return name=="Seeker i" end
    advance(1); eq(#sent,9); eq(sent[9].target,"Seeker j")
    no(N.Main.hopAnyState.round.asked["seeker i"]); no(N.Main.invite.asked["seeker i"])
    for _=1,45 do advance(1) end
    eq(#sent,48)
    for _,row in ipairs(sent) do no(row.target=="Seeker i") end
    deliver("PARTY_INVITE_REQUEST","Seeker i"); eq(#accepts,0)
    SlashCmdList.LAYERENEMIES("hop stop"); no(N.Main.hopAnyState.quiet["seeker i"])
    advance(600); eq(#sent,48); no(N.Main.error)
end)

test("hop-any unreadable ignore policy at dispatch fails closed without cooldown stamps",function()
    for _,mode in ipairs({"nil","secret","throw","missing"}) do
        local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE")
        C_FriendList.IsIgnored=mode~="missing" and function()
            if mode=="throw" then error("unreadable") end
            if mode=="secret" then return secret end
        end or nil
        for _=1,7 do advance(1) end
        eq(#sent,8,mode); eq(N.Main.hopAnyState.round.count,49,mode)
        eq(N.Safe.count(N.Main.hopAnyState.round.asked),8,mode)
        eq(N.Safe.count(N.Main.invite.asked),8,mode)
        advance(121); eq(#sent,8,mode); no(N.Main.error)
    end
end)

assert(loadfile("test/hop_fanout.lua"))({test=test,eq=eq,yes=yes,no=no,load=anyFixture,click=anyClick,reply=anyReply,
    rows=function(v) whoRows=v end,abc=abc,secret=secret,advance=advance,deliver=deliver,drain=drain,
    time=function(v) if v then clock=v end; return clock end,sent=function() return sent end,
    result=function(v) sendResult=v end,loaded=function(k,v) loaded[k]=v end,
    accepts=function() return accepts end,frames=function() return frames end,
    leaves=function() return leaves end,unit=function(k,v) units[k]=v end,
    calls=function() return whoCalls end,group=function(v) grouped=v end,map=function(v) map=v end,
    instance=function(v) inInstance=v end,
    manual=function() manualWho=true; C_FriendList.SendWho("manual lookup",1); manualWho=false end})

assert(loadfile("test/find20.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,clock=function() return clock end,log=function() return log end,
    sent=function() return sent end,frames=function() return frames end})

assert(loadfile("test/known.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,clock=function() return clock end,map=function(v) map=v end,deliver=deliver,drain=drain,
    units=function() return units end,player=player,establish=establish,snapshot=snapshot,
    sent=function() return sent end})

assert(loadfile("test/party_targets.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,secret=secret,
    advance=advance,clock=function() return clock end,deliver=deliver,drain=drain,
    units=function() return units end,player=player,instance=function(v) inInstance=v end,
    sent=function() return sent end})

assert(loadfile("test/realm_names.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,secret=secret,
    clock=function() return clock end,deliver=deliver,log=function() return log end,sent=function() return sent end})

assert(loadfile("test/spy_relay.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,
    clock=function() return clock end,advance=advance,deliver=deliver,drain=drain,
    instance=function(v) inInstance=v end,sent=function() return sent end})

assert(loadfile("test/relay_policy.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,
    clock=function() return clock end,advance=advance,deliver=deliver,drain=drain,
    units=function() return units end,player=player,establish=establish,
    combat=function(v) combat=v end,sent=function() return sent end})

assert(loadfile("test/kills.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,clock=function() return clock end,deliver=deliver,drain=drain,snapshot=snapshot,
    loaded=function() return loaded end,log=function() return log end,sent=function() return sent end})

assert(loadfile("test/round1.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,clock=function() return clock end,deliver=deliver,drain=drain,
    units=function() return units end,player=player,establish=establish,
    sent=function() return sent end})

assert(loadfile("test/round2.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,
    clock=function(v) if v then clock=v end; return clock end,deliver=deliver,sent=function() return sent end})

assert(loadfile("test/own_death.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,deliver=deliver,advance=advance,
    drain=drain,secret=secret,player=player,establish=establish,abc=abc,
    sent=function() return sent end,log=function() return log end,clock=function() return clock end,
    timers=function() return timers end,frames=function() return frames end,
    instance=function(v) inInstance=v end,combat=function(v) combat=v end,
    unit=function(k,v) units[k]=v end,roster=function(v) roster=v end,map=function(v) map=v end,
    result=function(v) sendResult=v end,loaded=function(k,v) loaded[k]=v end,
    forbidden=function() return forbidden end,clearForbidden=function() forbidden=0 end})
assert(loadfile("test/watch.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    establish=establish,time=function(v) if v then clock=v end; return clock end,deliver=deliver,drain=drain,
    guild=function(v,name) inGuild=v; if name then guildName=name end end,instance=function(v) inInstance=v end,
    roster=function(v) roster=v end,units=function() return units end,player=player,snapshot=snapshot,
    sent=function() return sent end,log=function() return log end,frames=function() return frames end})
assert(loadfile("test/kills_round1.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,
    advance=advance,clock=function() return clock end,deliver=deliver,drain=drain,
    units=function() return units end,player=player,combat=function(v) combat=v end,
    loaded=function() return loaded end,sent=function() return sent end})

assert(loadfile("test/kills_round2.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,
    advance=advance,clock=function() return clock end,deliver=deliver,drain=drain,
    units=function() return units end,player=player,combat=function(v) combat=v end,
    loaded=function() return loaded end,sent=function() return sent end})

assert(loadfile("test/ui_layout.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,
    clock=function() return clock end,establish=establish,sent=function() return sent end})
assert(loadfile("test/presence.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,secret=secret,
    advance=advance,time=function(v) if v then clock=v end; return clock end,deliver=deliver,drain=drain,
    sent=function() return sent end,log=function() return log end,timers=function() return timers end,
    combat=function(v) combat=v end,instance=function(v) inInstance=v end,snapshot=snapshot})

assert(loadfile("test/flh.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,deliver=deliver,drain=drain,establish=establish,
    sent=function() return sent end,log=function() return log end,frames=function() return frames end,
    registered=function() return registered end,wall=function(v) if v then wall=v end; return wall end,
    loaded=function() return loaded end,combat=function(v) combat=v end,instance=function(v) inInstance=v end})
assert(loadfile("test/overlord.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,abc=abc,secret=secret,
    advance=advance,clock=function(v) if v then clock=v end; return clock end,deliver=deliver,drain=drain,
    combat=function(v) combat=v end,instance=function(v) inInstance=v end,
    sent=function() return sent end,log=function() return log end,registered=function() return registered end})

assert(loadfile("test/stack_integration.lua"))({test=test,eq=eq,yes=yes,no=no,load=loadAddon,
    advance=advance,deliver=deliver,sent=function() return sent end,
    registered=function() return registered end})

print(string.format("RESULT: %d tests passed, %d failed, %d assertions",passed,failed,checks))
if failed>0 then os.exit(1) end
