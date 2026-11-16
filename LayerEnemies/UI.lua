-- Approved preview B, using native frames only. Six pooled rows, no idle renderer.
local _,N=...
local U,S={tab="local",offset=0,pool={},tabs={}},N.Safe
N.UI=U
local colors={bg={.071,.086,.106},bar={.102,.125,.153},card={.094,.114,.137},muted={.49,.53,.58},gold={1,.82,0},green={.71,.94,.54}}
local function paint(frame,color)
    local t=frame:CreateTexture(nil,"BACKGROUND")
    t:SetAllPoints(); t:SetColorTexture(unpack(color)); return t
end
local function border(frame,color)
    local edges={}
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local t=frame:CreateTexture(nil,"BORDER"); t:SetColorTexture(unpack(color or {0,0,0}))
        t:SetPoint(edge[1]); t:SetPoint(edge[2]); if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
        edges[#edges+1]=t
    end
    return edges
end
local function font(parent,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,""); f:SetJustifyH("LEFT"); f:SetTextColor(unpack(color or {.81,.84,.87})); return f
end
local function button(parent,w,h,label,fn)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b.bg=paint(b,{.137,.227,.11}); b.edges=border(b,{.30,.48,.23})
    b.label=font(b,10,{.79,.96,.65}); b.label:SetPoint("CENTER"); b.label:SetWidth(w-8); b.label:SetJustifyH("CENTER"); b.label:SetText(label)
    b:SetScript("OnClick",fn); return b
end
local function age(at)
    local n=math.floor(math.max(0,GetTime()-at))
    return n<60 and n.." s" or math.floor(n/60).." min"
end
local function classColor(class)
    local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    if c and S.num(c.r) and S.num(c.g) and S.num(c.b) then return {c.r,c.g,c.b} end
    return {.67,.70,.74}
end
local function className(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class or ""]) or class or "Unknown class"
end
local function rowFrame()
    local r=CreateFrame("Frame",nil,U.body)
    r:Hide(); r:SetSize(348,64); paint(r,colors.card); border(r)
    r.stripe=r:CreateTexture(nil,"ARTWORK"); r.stripe:SetPoint("TOPLEFT"); r.stripe:SetPoint("BOTTOMLEFT"); r.stripe:SetWidth(4)
    r.levelBG=r:CreateTexture(nil,"ARTWORK"); r.levelBG:SetColorTexture(.055,.071,.086); r.levelBG:SetPoint("TOPLEFT",4,-1); r.levelBG:SetPoint("BOTTOMLEFT",4,1); r.levelBG:SetWidth(32)
    r.level=font(r,13); r.level:SetPoint("TOPLEFT",r,"TOPLEFT",10,-16); r.level:SetWidth(25)
    r.title=font(r,12); r.title:SetPoint("TOPLEFT",r,"TOPLEFT",42,-8); r.title:SetWidth(225)
    r.sub=font(r,10,colors.muted); r.sub:SetPoint("TOPLEFT",r,"TOPLEFT",42,-26); r.sub:SetWidth(294); r.sub:SetHeight(31); r.sub:SetJustifyV("TOP")
    r.place=font(r,10,colors.muted); r.place:SetWidth(294); r.place:SetHeight(40); r.place:SetJustifyV("TOP"); r.place:Hide()
    r.age=font(r,10,colors.muted); r.age:SetPoint("TOPRIGHT",r,"TOPRIGHT",-8,-8); r.age:SetJustifyH("RIGHT")
    r.ask=button(r,220,20,"Ask for invite",function()
        if r.hostRow then N.Main.hopHostTo(r.hostRow,r.hostShown); U.render()
        elseif r.hopRecord then N.Main.hopTo(r.hopRecord,r.hopShown); U.render()
        elseif r.spotter then N.AskInvite(r.spotter); U.render() end
    end)
    -- a disabled Hop button says why on mouse-over
    r.ask:SetScript("OnEnter",function()
        local tip=_G.GameTooltip
        if r.ask.reason and S.tab(tip) then
            pcall(function() tip:SetOwner(r.ask,"ANCHOR_TOP"); tip:SetText(r.ask.reason); tip:Show() end)
        end
    end)
    r.ask:SetScript("OnLeave",function() local tip=_G.GameTooltip; if S.tab(tip) then pcall(tip.Hide,tip) end end)
    r.ask:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",42,6)
    r.hopRecord=false; r.hopShown=false; r.hostRow=false; r.hostShown=false; r.spotter=false; r.ask.reason=false
    r.clear=button(r,42,18,"Clear",function() if r.tracked then N.Main.track(r.tracked,true); U.render() end end)
    r.clear:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-6,6)
    return r
end
function U.cooldown(name)
    local _,key=N.Invite.name(name)
    local st=N.Main.invite; local at=key and st.asked[key]
    if at and GetTime()-at<N.Invite.NAME_COOLDOWN then return math.ceil(N.Invite.NAME_COOLDOWN-(GetTime()-at)) end
end
-- The Hop button of a report row: who will be asked and how; disabled with the reason.
-- A Friendly row with a host record: Hop via that host (one whisper per click), disabled with the reason.
local function hostState(r,e,p)
    r.spotter=false; r.hopRecord=false; r.hostRow=e; r.hostShown=p
    r.ask:Show(); r.ask.label:SetText(p.label); r.ask.reason=p.enabled and p.detail or p.reason
    r.ask.bg:SetColorTexture(unpack(p.enabled and {.137,.227,.11} or {.11,.13,.16}))
    if p.enabled then r.ask:Enable() else r.ask:Disable() end
end
-- A row listed while our own layer is unknown: no ask, the hint says what to do.
local function unknownState(r)
    r.spotter=false; r.hopRecord=false; r.hostRow=false; r.hostShown=false
    r.ask:Show(); r.ask.label:SetText("Ask for invite"); r.ask.reason=N.Invite.HINT
    r.ask.bg:SetColorTexture(.11,.13,.16); r.ask:Disable()
end
local function hopState(r,record)
    r.spotter=false; r.hostRow=false; r.hostShown=false; r.hopRecord=record
    local p=N.Main.hopPreview(record); r.hopShown=p
    r.ask:Show(); r.ask.label:SetText(p.label); r.ask.reason=p.enabled and p.detail or p.reason
    r.ask.bg:SetColorTexture(unpack(p.enabled and {.137,.227,.11} or {.11,.13,.16}))
    if p.enabled then r.ask:Enable() else r.ask:Disable() end
end
local function askState(r,name,label)
    r.spotter=name or false; r.hopRecord=false; r.hopShown=false; r.hostRow=false; r.hostShown=false; r.ask.reason=false
    if not name then r.ask:Hide(); return end
    r.ask:Show()
    local remaining=U.cooldown(name)
    r.ask.label:SetText(remaining and ("Asked · "..remaining.."s") or label)
    r.ask.bg:SetColorTexture(unpack(remaining and {.11,.13,.16} or {.137,.227,.11}))
    if remaining then r.ask:Disable() else r.ask:Enable() end
end
function U.select(tab)
    U.tab=tab; U.offset=0; U.render()
end
function U.render()
    if not U.frame or not U.frame:IsShown() then return end
    local M,T=N.Main,N.Store
    local time=GetTime()
    local seen=T.rows(M.store,time,"local")
    local liveSeen=#seen
    for _,e in ipairs(T.previous(M.store,time)) do seen[#seen+1]=e end
    local reports=T.rows(M.store,time,"reported")
    local friends=M.candidates()
    local eligible={}; for _,c in ipairs(friends) do eligible[c.short]=true end
    local tracked=M.findRows()
    local lists={localRows=seen,reported=reports,friendly=friends,find=tracked}
    local rows=U.tab=="local" and lists.localRows or lists[U.tab]
    local titles={localRows="Seen by you ("..#seen..")",reported="Reported ("..#reports..")",friendly="Friendly ("..#friends..")",find="Find"}
    for key,b in pairs(U.tabs) do
        b.label:SetText(titles[key=="local" and "localRows" or key]); b.label:SetTextColor(unpack(key==U.tab and colors.gold or colors.muted))
        b.bg:SetColorTexture(unpack(key==U.tab and colors.bg or {.055,.071,.086}))
        b.line:SetShown(key==U.tab)
    end
    local known=N.Layer.key(M.store.bulo)
    U.layer:SetText(known or "?")
    U.meta:SetText(M.zoneName(M.store.zone).." · "..(known and (M.layerSource or "unknown") or "layer unknown: mouse over or target two different kinds of NPC within 15 s"))
    U.input:SetShown(U.tab=="find"); U.add:SetShown(U.tab=="find")
    U.hopAny:SetShown(U.tab=="friendly")
    local hop=N.Main.hopAnyPreview()
    U.hopAny.label:SetText(hop.label); U.hopAny.reason=hop.reason or false; U.hopAny.round=hop.round or false
    if hop.enabled then U.hopAny:Enable() else U.hopAny:Disable() end
    U.findHosts:SetShown(U.tab=="friendly")
    local wait=N.Hosts.askWait(M.heard,time)
    U.findHosts.label:SetText(wait and ("Asked · "..wait.."s") or "Find hosts")
    if wait then U.findHosts:Disable() else U.findHosts:Enable() end
    local hosting,want=M.host and M.host.on,M.host and M.host.want
    U.host:SetShown(U.tab=="friendly"); U.host.label:SetText(want and "Host: on" or "Host: off")
    U.hosting:SetText(hosting and "Hosting for your guild (stays on after reload)"
        or ("Hosting is on but inactive: "..tostring(M.host and M.host.inactive or "")))
    U.hosting:SetShown(want==true)
    U.auto:SetShown(U.tab=="friendly"); U.auto.label:SetText(M.autoHop() and "Auto: on" or "Auto: off")
    U.share.label:SetText(M.sharing() and "Share: on" or "Share: off")
    U.call.label:SetText(M.calling() and "Call: on" or "Call: off")
    U.guildOnly.label:SetText(N.Net.consent()=="public" and "Guild only: off" or "Guild only: on")
    -- a network not in this version shows n/a; otherwise its own switch (stand-down and guild only show in /le net)
    local function netLabel(key,name) return name..": "..(N.Net.SHIP[key]~=true and "n/a" or N.Net.switch(key) and "on" or "off") end
    U.netWe.label:SetText(netLabel("we","War Effort")); U.netHh.label:SetText(netLabel("hh","HeadHunter"))
    local hint=U.tab=="friendly" and not known
    U.banner:SetText(U.tab=="reported" and "Reported, not confirmed. Age as the reporter's clock gives it." or U.tab=="find" and "Up to five names. Hash matches are possible, not certain." or hint and N.Invite.HINT or "")
    local hasPlaces=false; for _,row in ipairs(tracked) do if row.place then hasPlaces=true; break end end
    local height=U.tab=="local" and 48 or U.tab=="find" and (hasPlaces and 146 or 106) or U.tab=="friendly" and 68 or 80
    local top=U.tab=="find" and 56 or U.tab=="friendly" and 48 or U.tab=="reported" and 23 or 0
    local visible=math.floor((300-top)/height)
    local maximum=math.max(0,#rows-visible)
    U.offset=math.min(U.offset,maximum)
    for _,r in ipairs(U.pool) do r:Hide(); r.spotter=false; r.tracked=nil; r.hopRecord=false; r.hostRow=false end
    for index=1,math.min(visible,#rows-U.offset) do
        local e=rows[index+U.offset]
        local r=U.pool[index]
        if not r then r=rowFrame(); U.pool[index]=r end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",U.body,"TOPLEFT",0,-top-(index-1)*height)
        r:SetHeight(height-4); r:Show(); r.clear:Hide(); r.place:Hide()
        local c=U.tab=="friendly" and colors.green or classColor(e.class)
        r.stripe:SetColorTexture(unpack(c)); r.title:SetTextColor(unpack(c))
        local friendly=U.tab=="friendly"
        r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT",r,"TOPLEFT",friendly and 12 or 42,-8)
        r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT",r,"TOPLEFT",friendly and 12 or 42,-26)
        r.ask:ClearAllPoints(); r.ask:SetPoint(friendly and "BOTTOMRIGHT" or "BOTTOMLEFT",r,friendly and "BOTTOMRIGHT" or "BOTTOMLEFT",friendly and -7 or 42,6)
        r.ask:SetWidth(friendly and 120 or 220); r.ask.label:SetWidth(friendly and 112 or 212)
        r.sub:SetWidth(friendly and 200 or 294)
        r.levelBG:SetShown(not friendly)
        r.sub:SetHeight(U.tab=="find" and 44 or U.tab=="local" and 14 or 24)
        r.level:SetText(e.level and tostring(e.level) or U.tab=="friendly" and "" or "?")
        r.age:SetText(e.at and age(e.at) or e.age and age(time-e.age) or "")
        r.title:SetText(e.displayName or e.name or "Unknown")
        if U.tab=="local" then
            r.sub:SetText(className(e.class).." · "..M.zoneName(e.zone)..(index+U.offset>liveSeen and " · previous zone" or e.layer==nil and " · layer unknown" or "")); askState(r,nil)
        elseif U.tab=="reported" then
            r.title:SetText("Unknown "..className(e.class))
            r.sub:SetText("reported by "..e.reporter..(e.via and " via "..e.via or "")..(e.hand~="first" and " · relayed" or ""))
            hopState(r,e.record)
        elseif U.tab=="friendly" then
            r.sub:SetText(table.concat(e.sources," + ")..(e.host and " · host" or "").." · "..(e.layer and "layer "..e.layer or "layer not known"))
            local p=not e.unknownOwn and M.hostPreview(e)
            if e.unknownOwn then unknownState(r)
            elseif p then hostState(r,e,p)
            else askState(r,e.name,"Ask for invite") end
        else
            r.tracked=e.name; r.clear:Show()
            r.sub:SetText(e.at and (e.status.." · "..M.zoneName(e.zone).."\n"..className(e.class).." "..tostring(e.level or "?")..(e.same and " · already on your layer" or e.travel and (" · travel to "..M.zoneName(e.zone).." first") or "")) or (e.place and "" or e.status))
            askState(r,e.canAsk and e.spotter or nil,e.spotter and ("Ask "..e.spotter.." for invite") or "")
            if e.probably then r.sub:SetText(r.sub:GetText().." · probably your layer (key ambiguous)") end
            if e.place then
                r.place:ClearAllPoints(); r.place:SetPoint("TOPLEFT",r,"TOPLEFT",42,e.at and -73 or -26)
                r.place:SetText(M.placeText(e.place)); r.place:Show()
            end
        end
    end
    U.hint:SetText(#rows==0 and "No eligible observations yet." or (#rows>visible and ("Mouse wheel: "..(U.offset+1).."–"..math.min(#rows,U.offset+visible).." of "..#rows) or ""))
    U.lastPaint=time
end
function U.refresh(soon)
    if not U.frame or not U.frame:IsShown() then return end
    -- Data callbacks normally wait for the age tick. Action transitions repaint
    -- next frame; the painted action stays authoritative until that repaint.
    U.dirty=true
    if soon and not U.paintPending then
        U.paintPending=true
        if not pcall(C_Timer.After,0,function() U.paintPending=false; U.render() end) then U.paintPending=false end
    end
end
function U.tick(generation)
    if not U.frame:IsShown() or generation~=U.generation then return end
    U.render(); U.dirty=false
    C_Timer.After(1,function() U.tick(generation) end)
end
function U.position(raw)
    local valid={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    local ok,p=pcall(function()
        if not S.tab(raw) then return nil end
        local point,relative=S.str(raw.point),S.str(raw.relative)
        local x,y=S.num(raw.x),S.num(raw.y)
        if point and relative and valid[point] and valid[relative] and x and y and math.abs(x)<4000 and math.abs(y)<4000 then
            return {point=point,relative=relative,x=x,y=y}
        end
    end)
    return ok and p or nil
end
function U.savePosition()
    U.frame:StopMovingOrSizing()
    local point,_,relative,x,y=U.frame:GetPoint(1)
    LayerEnemiesDB.position=U.position({point=point,relative=relative,x=x,y=y})
end
function U.create()
    if U.frame then return end
    local f=CreateFrame("Frame","LayerEnemiesWindow",UIParent)
    f:Hide() -- Native frames start shown; never flash on login.
    U.frame=f; f:SetSize(360,514); f:SetFrameStrata("MEDIUM"); paint(f,colors.bg); border(f,{.18,.22,.26})
    f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() f:StartMoving() end); f:SetScript("OnDragStop",U.savePosition)
    local p=U.position(LayerEnemiesDB.position)
    if p then
        f:SetPoint(p.point,UIParent,p.relative,p.x,p.y)
    else f:SetPoint("CENTER",UIParent,"CENTER",0,0) end
    local bar=CreateFrame("Frame",nil,f); bar:SetPoint("TOPLEFT"); bar:SetSize(360,26); paint(bar,colors.bar)
    local title=font(bar,12); title:SetPoint("LEFT",10,0); title:SetText("LAYER ENEMIES")
    local close=button(bar,22,20,"x",function() f:Hide() end); close:SetPoint("RIGHT",-4,0)
    local chip=f:CreateTexture(nil,"BACKGROUND"); chip:SetColorTexture(.047,.063,.035); chip:SetPoint("TOPLEFT",6,-32); chip:SetSize(70,34)
    U.layer=font(f,18,colors.green); U.layer:SetPoint("TOPLEFT",12,-39); U.layer:SetWidth(64)
    local label=font(f,10,colors.muted); label:SetPoint("TOPLEFT",86,-34); label:SetText("YOUR LAYER")
    U.meta=font(f,10); U.meta:SetPoint("TOPLEFT",86,-50); U.meta:SetWidth(264)
    local x=0
    for _,entry in ipairs({{"local",112,"Seen by you"},{"reported",88,"Reported"},{"friendly",98,"Friendly"},{"find",62,"Find"}}) do
        local key=entry[1]
        local b=button(f,entry[2]-1,30,entry[3],function() U.select(key) end)
        b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-76); U.tabs[key]=b
        for _,edge in ipairs(b.edges) do edge:SetColorTexture(0,0,0) end
        b.line=b:CreateTexture(nil,"OVERLAY"); b.line:SetColorTexture(unpack(colors.gold)); b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT"); b.line:SetPoint("BOTTOMRIGHT")
        x=x+entry[2]
    end
    U.body=CreateFrame("Frame",nil,f); U.body:SetSize(348,300); U.body:SetPoint("TOPLEFT",6,-114)
    U.body:EnableMouseWheel(true)
    U.body:SetScript("OnMouseWheel",function(_,delta) U.offset=math.max(0,U.offset-(delta>0 and 1 or -1)); U.render() end)
    U.banner=font(U.body,10,{.94,.76,.48}); U.banner:SetPoint("TOPLEFT",4,0); U.banner:SetWidth(250)
    U.input=CreateFrame("EditBox",nil,U.body); U.input:Hide(); U.input:SetSize(248,24); U.input:SetPoint("TOPLEFT",4,-23)
    U.input:SetFont("Fonts\\FRIZQT__.TTF",12,""); U.input:SetAutoFocus(false); U.input:SetMaxLetters(100); paint(U.input,colors.bar)
    local function add()
        if N.Main.track(U.input:GetText()) then U.input:SetText(""); U.input:ClearFocus() end
        U.render()
    end
    U.input:SetScript("OnEnterPressed",add); U.input:SetScript("OnEscapePressed",function() U.input:ClearFocus() end)
    U.add=button(U.body,76,24,"Track",add); U.add:SetPoint("TOPRIGHT",-4,-23)
    -- one LFSw guild question per click, at most once a minute (Hosts.ask, Wire)
    U.findHosts=button(U.body,84,18,"Find hosts",function() N.Main.findHosts(); U.render() end); U.findHosts:SetPoint("TOPRIGHT",-4,0); U.findHosts:Hide()
    U.hopAny=button(U.body,180,20,"Hop to another layer",function()
        local M=N.Main
        -- Act only on the painted mode and round, not a new state between paints.
        local shown=U.hopAny.round
        if shown then
            if M.hopAnyState.round==shown then M.hopAnyStop() end
        elseif not M.hopAnyState.round then M.hopAny() end
        U.render()
    end)
    U.hopAny.reason=false; U.hopAny.round=false; U.hopAny:SetPoint("TOPLEFT",4,-23); U.hopAny:Hide()
    U.hopAny:SetScript("OnEnter",function()
        local tip=_G.GameTooltip
        if U.hopAny.reason and S.tab(tip) then
            pcall(function() tip:SetOwner(U.hopAny,"ANCHOR_TOP"); tip:SetText(U.hopAny.reason); tip:Show() end)
        end
    end)
    U.hopAny:SetScript("OnLeave",function() local tip=_G.GameTooltip; if S.tab(tip) then pcall(tip.Hide,tip) end end)
    -- guild-only hosting, saved (LayerEnemiesDB.guildHost); the line stays visible on every tab while it is on
    U.host=button(U.body,70,18,"Host: off",function() local M=N.Main; M.setHost(not (M.host and M.host.want)); U.render() end)
    U.host:SetPoint("TOPRIGHT",-92,0); U.host:Hide()
    -- Auto accept and leave: accept the asked host's invite, leave that group after the move (saved, on by default)
    U.auto=button(U.body,70,18,"Auto: on",function() local M=N.Main; M.setAutoHop(not M.autoHop()); U.render() end)
    U.auto:SetPoint("TOPRIGHT",-166,0); U.auto:Hide()
    U.hosting=font(f,10,{.79,.96,.65}); U.hosting:SetPoint("TOPLEFT",86,-64); U.hosting:Hide()
    U.hint=font(f,10,colors.muted); U.hint:SetPoint("TOPLEFT",10,-420); U.hint:SetWidth(340)
    -- 1.0 settings, saved, on every tab: sharing our own sightings, guild only (no public networks), each network
    local M=N.Main
    U.share=button(f,70,18,"Share: on",function() M.setShare(not M.sharing()); U.render() end)
    U.share:SetPoint("TOPLEFT",6,-440)
    U.call=button(f,70,18,"Call: on",function() M.setCall(not M.calling()); U.render() end)
    U.call:SetPoint("TOPLEFT",6,-462)
    U.guildOnly=button(f,92,18,"Guild only: off",function() M.setConsent(N.Net.consent()=="public" and "guild" or "public"); U.render() end)
    U.guildOnly:SetPoint("TOPLEFT",80,-440)
    U.netWe=button(f,86,18,"War Effort: on",function() M.setNet("we",not N.Net.switch("we")); U.render() end)
    U.netWe:SetPoint("TOPLEFT",176,-440)
    U.netHh=button(f,86,18,"HeadHunter: on",function() M.setNet("hh",not N.Net.switch("hh")); U.render() end)
    U.netHh:SetPoint("TOPLEFT",266,-440)
    local footer=font(f,10,colors.muted); footer:SetPoint("BOTTOMLEFT",10,9); footer:SetWidth(340)
    footer:SetText("Only players seen by you or reported by other players' addons.")
    f:SetScript("OnShow",function() U.generation=(U.generation or 0)+1; U.tick(U.generation) end)
    f:SetScript("OnHide",function() U.generation=(U.generation or 0)+1; U.input:ClearFocus() end)
end
function U.toggle()
    U.create()
    if U.frame:IsShown() then U.frame:Hide() else U.frame:Show() end
end
