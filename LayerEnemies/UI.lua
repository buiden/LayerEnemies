-- Approved preview B, using native frames only. Pooled rows, no idle renderer.
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
-- Clear the previous height before measuring so shorter text can shrink again.
local function fitText(f,minimum)
    f:SetHeight(0)
    local height=math.max(minimum or 0,math.ceil(f:GetStringHeight()))
    f:SetHeight(height); return height
end
local function button(parent,w,h,label,fn)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b.bg=paint(b,{.137,.227,.11}); b.edges=border(b,{.30,.48,.23})
    b.label=font(b,10,{.79,.96,.65}); b.label:SetPoint("CENTER"); b.label:SetWidth(w-8); b.label:SetJustifyH("CENTER"); b.label:SetWordWrap(false); b.label:SetText(label)
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
    r.level=font(r,13); r.level:SetPoint("TOPLEFT",r,"TOPLEFT",10,-16); r.level:SetWidth(25); r.level:SetWordWrap(false)
    r.title=font(r,12); r.title:SetPoint("TOPLEFT",r,"TOPLEFT",42,-8); r.title:SetWidth(225); r.title:SetWordWrap(false)
    r.sub=font(r,10,colors.muted); r.sub:SetPoint("TOPLEFT",r,"TOPLEFT",42,-26); r.sub:SetWidth(294); r.sub:SetHeight(31); r.sub:SetJustifyV("TOP")
    r.place=font(r,10,colors.muted); r.place:SetWidth(294); r.place:SetHeight(40); r.place:SetJustifyV("TOP"); r.place:Hide()
    r.presence=font(r,10,colors.muted); r.presence:SetWidth(294); r.presence:SetHeight(56); r.presence:SetJustifyV("TOP"); r.presence:Hide()
    r.age=font(r,10,colors.muted); r.age:SetPoint("TOPRIGHT",r,"TOPRIGHT",-8,-8); r.age:SetJustifyH("RIGHT"); r.age:SetWidth(64); r.age:SetWordWrap(false)
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
    if tab=="find" and U.tab~="find" then N.Main.presenceOpen() end
    U.tab=tab; U.offset=0; U.render()
end
function U.render()
    if not U.frame or not U.frame:IsShown() then return end
    local M,T=N.Main,N.Store
    local time=GetTime()
    -- one namedRows per render: it returns both the seen copies and the reported rows
    local seen,reports=M.namedRows(T.rows(M.store,time,"local"))
    local liveSeen=#seen
    for _,e in ipairs(T.previous(M.store,time)) do seen[#seen+1]=e end
    local friends,hints=N.ChehulNet.friendly(M.candidates())
    local friendlyRows={}
    for _,row in ipairs(friends) do friendlyRows[#friendlyRows+1]=row end
    for _,row in ipairs(hints) do friendlyRows[#friendlyRows+1]=row end
    local eligible={}; for _,c in ipairs(friends) do eligible[c.short]=true end
    local tracked=M.findRows()
    local function locatedAt(row) return math.max(row.at or -math.huge,row.place and row.place.at or -math.huge) end
    local located=0
    for _,row in ipairs(tracked) do if row.at or row.place or row.presence then located=located+1 end end
    table.sort(tracked,function(a,b)
        local aa,bb=locatedAt(a),locatedAt(b)
        if aa~=bb then return aa>bb end
        return N.Find.fold(a.name)<N.Find.fold(b.name)
    end)
    U.findTitle:SetText("Find ("..located.." located / "..#tracked..")")
    U.findTitle:SetShown(U.tab=="find")
    local lists={localRows=seen,reported=reports,friendly=friendlyRows,find=tracked}
    local rows=U.tab=="local" and lists.localRows or lists[U.tab]
    local titles={localRows="Seen by you ("..#seen..")",reported="Reported ("..#reports..")",friendly="Friendly ("..#friends..")",find="Find"}
    for key,b in pairs(U.tabs) do
        b.label:SetText(titles[key=="local" and "localRows" or key]); b.label:SetTextColor(unpack(key==U.tab and colors.gold or colors.muted))
        b.bg:SetColorTexture(unpack(key==U.tab and colors.bg or {.055,.071,.086}))
        b.line:SetShown(key==U.tab)
    end
    local known=N.Layer.key(N.Trust.own(M.store,time))
    U.layer:SetText(known or ""); U.layer:SetShown(known~=nil)
    U.meta:SetText(M.zoneName(M.store.zone).." · "..(known and (M.layerSource or "unknown") or N.Trust.state(M.store,time)=="blind" and "layer IDs unreadable" or "layer unknown: mouse over or target two different kinds of NPC within 15 s"))
    U.input:SetShown(U.tab=="find"); U.add:SetShown(U.tab=="find")
    U.hopAny:SetShown(U.tab=="friendly" or not known)
    local hop=N.Main.hopAnyPreview()
    U.hopAny.label:SetText(hop.label); U.hopAny.reason=(not known and hop.detail or hop.reason) or false; U.hopAny.round=hop.round or false; U.hopAny.preview=hop
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
    local headerBottom=50+fitText(U.meta)
    if want then headerBottom=headerBottom+4+fitText(U.hosting) end
    local tabsTop=math.max(76,headerBottom+8)
    for _,b in pairs(U.tabs) do b:SetPoint("TOPLEFT",U.frame,"TOPLEFT",b.x,-tabsTop) end
    U.body:SetPoint("TOPLEFT",U.frame,"TOPLEFT",6,-tabsTop-38)
    U.auto:SetShown(U.tab=="friendly"); U.auto.label:SetText(M.autoHop() and "Auto: on" or "Auto: off")
    U.share.label:SetText(M.sharing() and "Share: on" or "Share: off")
    U.call.label:SetText(M.calling() and "Call: on" or "Call: off")
    U.guildOnly.label:SetText(N.Net.consent()=="public" and "Guild only: off" or "Guild only: on")
    -- a network not in this version shows n/a; otherwise its own switch (stand-down and guild only show in /le net)
    local function netLabel(key,name) return name..": "..(N.Net.SHIP[key]~=true and "n/a" or N.Net.switch(key) and "on" or "off") end
    U.netWe.label:SetText(netLabel("we","War Effort")); U.netHh.label:SetText(netLabel("hh","HeadHunter"))
    local hint=U.tab=="friendly" and not known
    local bannerTop=U.tab=="find" and math.max(16,fitText(U.findTitle)+2) or 0
    U.banner:ClearAllPoints(); U.banner:SetPoint("TOPLEFT",4,-bannerTop)
    U.banner:SetWidth(U.tab=="reported" and 250 or 340)
    U.banner:SetText(U.tab=="reported" and "Reported, not confirmed. Age as the reporter's clock gives it." or U.tab=="find" and "Up to 20 names. Hash matches are possible, not certain." or hint and N.Invite.HINT or "")
    local bannerHeight=fitText(U.banner)
    local inputTop=bannerTop+bannerHeight+4
    U.input:SetPoint("TOPLEFT",4,-inputTop); U.add:SetPoint("TOPRIGHT",-4,-inputTop)
    local friendlyTop=hint and bannerHeight+6 or 0
    U.findHosts:SetPoint("TOPRIGHT",-4,-friendlyTop); U.host:SetPoint("TOPRIGHT",-92,-friendlyTop)
    U.auto:SetPoint("TOPRIGHT",-166,-friendlyTop); U.hopAny:SetPoint("TOPLEFT",4,-friendlyTop-23)
    local function knownHeight(e)
        local function height(v) return v and ((v.own or v.layer or v.x) and 58 or 44) or 0 end
        return height(e.current)+height(e.seen)+height(e.otherSeen)+height(e.reported)
    end
    local function minimumHeight(e)
        if U.tab=="find" then
            -- Mixed presence cards use complete measured content, not slot estimates.
            if e.presence then return 76 end
            if e.seen or e.reported then return 62+knownHeight(e)+(e.place and 40 or 0) end
            return e.place and 146 or e.at and 106 or 76
        end
        return U.tab=="local" and 48 or U.tab=="friendly" and (e.flhKey and 104 or 68) or 80
    end
    -- Measure the actual strings before paging, not an assumed line count for
    -- each evidence slot. One hidden FontString serves every row in the pool.
    U.chehulTitle:Hide()
    local chehulHeadingHeight=U.tab=="friendly" and #hints>0 and fitText(U.chehulTitle)+8 or 0
    local layouts={}
    for index,e in ipairs(rows) do
        local detailHeight=knownHeight(e)
        local text
        if U.tab=="local" then
            text=className(e.class).." · "..M.zoneName(e.zone)..(index>liveSeen and " · previous zone" or e.layer==nil and " · layer unknown" or "")
            if e.alsoReported then text=text.."\nalso reported by "..table.concat(e.alsoReported,", ") end
        elseif U.tab=="reported" and e.guild then
            text=M.overlordText(e)
        elseif U.tab=="reported" and e.friendShare then
            text=e.sourceText.." · "..e.zone
        elseif U.tab=="reported" then
            text="reported by "..e.reporter..(e.via and " via "..e.via or "")..(e.hand~="first" and " · relayed" or "")
            if e.probablyNote then text=text.."\n"..e.probablyNote end
        elseif U.tab=="friendly" then
            text=e.chehulHint and e.chehulText or table.concat(e.sources," + ")..(e.host and " · host" or "")..(known and (" · "..M.hostPlace(e)) or "")
            if e.chehulText and not e.chehulHint then text=text.."\n"..e.chehulText end
        else
            text=M.findDetails(e) or (e.at and (e.status.." · "..M.zoneName(e.zone).."\n"..className(e.class).." "..tostring(e.level or "?")..(e.same and " · already on your layer" or e.travel and (" · travel to "..M.zoneName(e.zone).." first") or "")) or ((e.place or e.presence) and "" or "Not located"))
            if e.probably and detailHeight==0 then text=text.." · probably your layer (key ambiguous)" end
        end
        local minimum=U.tab=="find" and (detailHeight>0 and detailHeight or e.at and 44 or 14) or U.tab=="local" and 14 or (U.tab=="friendly" and e.flhKey) and 60 or 24
        if U.tab=="find" and e.presence then minimum=0 end
        U.measure:SetWidth(U.tab=="friendly" and 200 or 294); U.measure:SetText(text)
        local layout={text=text,subHeight=fitText(U.measure,minimum)}
        local bottom=26+layout.subHeight
        if U.tab=="find" and e.place then
            layout.place=M.placeText(e.place); U.measure:SetText(layout.place)
            layout.placeHeight=fitText(U.measure,40)
            layout.placeTop=math.max(detailHeight>0 and 29+detailHeight or e.at and 73 or 26,text~="" and bottom+3 or 26)
            bottom=layout.placeTop+layout.placeHeight
        end
        if U.tab=="find" and e.presence then
            layout.presence=M.presenceText(e.presence); U.measure:SetText(layout.presence)
            layout.presenceHeight=fitText(U.measure)
            layout.presenceTop=(e.place or text~="") and bottom+3 or 26
            bottom=layout.presenceTop+layout.presenceHeight
        end
        layout.height=math.max(minimumHeight(e),bottom+(U.tab=="local" and 4 or 32)+4)
        layouts[e]=layout
    end
    local function rowHeight(e) return layouts[e].height end
    local top=U.tab=="find" and math.max(70,inputTop+38) or U.tab=="friendly" and friendlyTop+48 or U.tab=="reported" and math.max(23,bannerHeight+6) or 0
    if not known and U.tab~="friendly" then
        U.hopAny:SetPoint("TOPLEFT",4,-top); top=top+26
    end
    -- A hash line beside both cached slots and an OpenMap place can exceed
    -- the usual page. Grow only enough for one whole card; never hide it.
    local bodyHeight=300
    for _,row in ipairs(rows) do
        bodyHeight=math.max(bodyHeight,top+rowHeight(row)+(row.chehulHint and chehulHeadingHeight or 0))
    end
    U.bodyHeight=bodyHeight; U.body:SetHeight(bodyHeight)
    -- Clamp to the last full page, accounting for each row's own height.
    local maximum,used,hasHints=#rows,0,false
    for i=#rows,1,-1 do
        if rows[i].chehulHint and not hasHints then used=used+chehulHeadingHeight; hasHints=true end
        used=used+rowHeight(rows[i]); if used>bodyHeight-top then break end
        maximum=i-1
    end
    U.offset=math.max(0,math.min(U.offset,maximum))
    local visible,y=0,top
    for _,r in ipairs(U.pool) do r:Hide(); r.spotter=false; r.tracked=nil; r.hopRecord=false; r.hostRow=false end
    for index=1,#rows-U.offset do
        local e=rows[index+U.offset]
        local height=rowHeight(e)
        -- Keep the section heading with its first visible hint, including
        -- pages scrolled past the boundary. It is not a host or a list row.
        local section=e.chehulHint and not U.chehulTitle:IsShown()
        if y+height+(section and chehulHeadingHeight or 0)>bodyHeight then break end
        if section then
            U.chehulTitle:ClearAllPoints(); U.chehulTitle:SetPoint("TOPLEFT",U.body,"TOPLEFT",4,-y-4)
            U.chehulTitle:Show(); y=y+chehulHeadingHeight
        end
        visible=visible+1
        local r=U.pool[index]
        if not r then r=rowFrame(); U.pool[index]=r end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",U.body,"TOPLEFT",0,-y)
        y=y+height
        r:SetHeight(height-4); r:Show(); r.clear:Hide(); r.place:Hide(); r.presence:Hide()
        local c=U.tab=="friendly" and colors.green or classColor(e.class)
        r.stripe:SetColorTexture(unpack(c)); r.title:SetTextColor(unpack(c))
        local friendly=U.tab=="friendly"
        r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT",r,"TOPLEFT",friendly and 12 or 42,-8)
        r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT",r,"TOPLEFT",friendly and 12 or 42,-26)
        r.ask:ClearAllPoints(); r.ask:SetPoint(friendly and "BOTTOMRIGHT" or "BOTTOMLEFT",r,friendly and "BOTTOMRIGHT" or "BOTTOMLEFT",friendly and -7 or 42,6)
        r.ask:SetWidth(friendly and 120 or 220); r.ask.label:SetWidth(friendly and 112 or 212)
        r.sub:SetWidth(friendly and 200 or 294)
        r.levelBG:SetShown(not friendly)
        local layout=layouts[e]
        r.sub:SetHeight(layout.subHeight); r.sub:SetText(layout.text)
        r.level:SetText(e.level and tostring(e.level) or U.tab=="friendly" and "" or "?")
        r.age:SetText(e.at and age(e.at) or e.age and age(time-e.age) or "")
        r.title:SetText(e.displayName or e.name or "Unknown")
        if U.tab=="local" then
            askState(r,nil)
        elseif U.tab=="reported" and e.guild then
            r.title:SetText("guild "..e.guild)
            askState(r,nil)
        elseif U.tab=="reported" and e.friendShare then
            r.title:SetText(e.title)
            askState(r,nil) -- zone only: no layer, so no Hop
        elseif U.tab=="reported" then
            r.title:SetText(e.title or ("Unknown "..className(e.class)))
            -- never offer a hop to a report on our own layer
            if not known or e.relation=="same" then askState(r,nil) else hopState(r,e.record) end
        elseif U.tab=="friendly" then
            local p=not e.chehulHint and not e.unknownOwn and M.hostPreview(e)
            if not known or e.chehulHint then askState(r,nil)
            elseif e.unknownOwn then unknownState(r)
            elseif p then hostState(r,e,p)
            else askState(r,e.name,"Ask for invite") end
        else
            r.tracked=e.name; r.clear:SetShown(not e.guildTracked)
            askState(r,e.canAsk and e.spotter or nil,e.spotter and ("Ask "..e.spotter.." for invite") or "")
            if e.place then
                r.place:ClearAllPoints(); r.place:SetPoint("TOPLEFT",r,"TOPLEFT",42,-layout.placeTop)
                r.place:SetHeight(layout.placeHeight); r.place:SetText(layout.place); r.place:Show()
            end
            if e.presence then
                r.presence:ClearAllPoints(); r.presence:SetPoint("TOPLEFT",r,"TOPLEFT",42,-layout.presenceTop)
                r.presence:SetHeight(layout.presenceHeight); r.presence:SetText(layout.presence); r.presence:Show()
            end
        end
    end
    U.hint:SetText(#rows==0 and "No eligible observations yet." or (#rows>visible and ("Mouse wheel: "..(U.offset+1).."–"..math.min(#rows,U.offset+visible).." of "..#rows) or ""))
    local optionsTop=tabsTop+38+bodyHeight+6+math.max(20,fitText(U.hint)+8)
    for _,item in ipairs({{U.share,6,0},{U.call,6,22},{U.guildOnly,80,0},{U.netWe,184,0},{U.netHh,80,22}}) do
        item[1]:SetPoint("TOPLEFT",item[2],-optionsTop-item[3])
    end
    local footerTop=optionsTop+22+18+16
    U.footer:SetPoint("TOPLEFT",10,-footerTop)
    U.frame:SetHeight(footerTop+fitText(U.footer)+9)
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
    U.layer=font(f,18,colors.green); U.layer:SetPoint("TOPLEFT",12,-39); U.layer:SetWidth(64); U.layer:SetWordWrap(false)
    local label=font(f,10,colors.muted); label:SetPoint("TOPLEFT",86,-34); label:SetText("YOUR LAYER")
    U.meta=font(f,10); U.meta:SetPoint("TOPLEFT",86,-50); U.meta:SetWidth(264)
    local x=0
    for _,entry in ipairs({{"local",112,"Seen by you"},{"reported",88,"Reported"},{"friendly",98,"Friendly"},{"find",62,"Find"}}) do
        local key=entry[1]
        local b=button(f,entry[2]-1,30,entry[3],function() U.select(key) end)
        b.x=x; b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-76); U.tabs[key]=b
        for _,edge in ipairs(b.edges) do edge:SetColorTexture(0,0,0) end
        b.line=b:CreateTexture(nil,"OVERLAY"); b.line:SetColorTexture(unpack(colors.gold)); b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT"); b.line:SetPoint("BOTTOMRIGHT")
        x=x+entry[2]
    end
    U.body=CreateFrame("Frame",nil,f); U.body:SetSize(348,300); U.body:SetPoint("TOPLEFT",6,-114)
    U.measure=font(U.body,10); U.measure:Hide()
    U.chehulTitle=font(U.body,10,colors.muted); U.chehulTitle:SetWidth(340)
    U.chehulTitle:SetText("Guildmates on other layers (hints)"); U.chehulTitle:Hide()
    U.body:EnableMouseWheel(true)
    U.body:SetScript("OnMouseWheel",function(_,delta) U.offset=math.max(0,U.offset-(delta>0 and 1 or -1)); U.render() end)
    U.findTitle=font(U.body,12); U.findTitle:SetPoint("TOPLEFT",4,0); U.findTitle:SetWidth(340); U.findTitle:Hide()
    U.banner=font(U.body,10,{.94,.76,.48}); U.banner:SetPoint("TOPLEFT",4,0); U.banner:SetWidth(250)
    U.input=CreateFrame("EditBox",nil,U.body); U.input:Hide(); U.input:SetSize(248,24); U.input:SetPoint("TOPLEFT",4,-32)
    U.input:SetFont("Fonts\\FRIZQT__.TTF",12,""); U.input:SetAutoFocus(false); U.input:SetMaxLetters(100); paint(U.input,colors.bar)
    local function add()
        if N.Main.track(U.input:GetText()) then U.input:SetText(""); U.input:ClearFocus() end
        U.render()
    end
    U.input:SetScript("OnEnterPressed",add); U.input:SetScript("OnEscapePressed",function() U.input:ClearFocus() end)
    U.add=button(U.body,76,24,"Track",add); U.add:SetPoint("TOPRIGHT",-4,-32)
    -- one LFSw guild question per click, at most once a minute (Hosts.ask, Wire)
    U.findHosts=button(U.body,84,18,"Find hosts",function() N.Main.findHosts(); U.render() end); U.findHosts:SetPoint("TOPRIGHT",-4,0); U.findHosts:Hide()
    U.hopAny=button(U.body,180,20,"Hop to another layer",function()
        local M=N.Main
        -- Act only on the painted mode and round, not a new state between paints.
        local shown=U.hopAny.round
        if shown then
            if M.hopAnyState.round==shown then M.hopAnyStop() end
        elseif not M.hopAnyState.round then M.hopAny(U.hopAny.preview) end
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
    U.hosting=font(f,10,{.79,.96,.65}); U.hosting:SetPoint("TOPLEFT",U.meta,"BOTTOMLEFT",0,-4); U.hosting:SetWidth(264); U.hosting:Hide()
    U.hint=font(f,10,colors.muted); U.hint:SetPoint("TOPLEFT",U.body,"BOTTOMLEFT",4,-6); U.hint:SetWidth(340)
    -- 1.0 settings, saved, on every tab: sharing our own sightings, guild only (no public networks), each network
    local M=N.Main
    U.share=button(f,70,18,"Share: on",function() M.setShare(not M.sharing()); U.render() end)
    U.share:SetPoint("TOPLEFT",6,-440)
    U.call=button(f,70,18,"Call: on",function() M.setCall(not M.calling()); U.render() end)
    U.call:SetPoint("TOPLEFT",6,-462)
    U.guildOnly=button(f,100,18,"Guild only: off",function() M.setConsent(N.Net.consent()=="public" and "guild" or "public"); U.render() end)
    U.guildOnly:SetPoint("TOPLEFT",80,-440)
    U.netWe=button(f,100,18,"War Effort: on",function() M.setNet("we",not N.Net.switch("we")); U.render() end)
    U.netWe:SetPoint("TOPLEFT",184,-440)
    U.netHh=button(f,112,18,"HeadHunter: on",function() M.setNet("hh",not N.Net.switch("hh")); U.render() end)
    U.netHh:SetPoint("TOPLEFT",80,-462)
    U.footer=font(f,10,colors.muted); U.footer:SetWidth(340)
    U.footer:SetText("Only players seen by you or reported by other players' addons.")
    f:SetScript("OnShow",function() if U.tab=="find" then M.presenceOpen() end; U.generation=(U.generation or 0)+1; U.tick(U.generation) end)
    f:SetScript("OnHide",function() U.generation=(U.generation or 0)+1; U.input:ClearFocus() end)
end
function U.toggle()
    U.create()
    if U.frame:IsShown() then U.frame:Hide() else U.frame:Show() end
end
do
    -- ---------------------------------------------------------------------------------------------------------------
    -- 1.2.5 hop bar, N.HopBar (owner's request, 2026-11-19): a small movable bar with your layer and the hop status; a left-click
    -- hops like the window's "Hop to another layer" button. Behaviour modelled on LayerSwap's mini bar; our own code and
    -- look, no LayerSwap lines or media. Plain frames only (never protected or secure); nothing is sent from here.
    local B={}
    N.HopBar=B
    B.ALPHA=.55
    B.DEFAULT={point="TOP",relative="TOP",x=0,y=-160}
    local GREEN={.71,.94,.54}

    -- load(raw) -> the saved settings, checked: shown (default on), oneline (default off), position (or nil).
    function B.load(raw)
        local t=S.tab(raw) and raw or {}
        return {shown=t.shown~=false,oneline=t.oneline==true,position=N.UI.position(t.position)}
    end
    local function saved()
        if not S.tab(LayerEnemiesDB) then return B.load(nil) end
        if not S.tab(LayerEnemiesDB.bar) then LayerEnemiesDB.bar=B.load(nil) end
        return LayerEnemiesDB.bar
    end

    -- Line 1: the instance name inside an instance, else "Layer <key>" from the same source as the window's YOUR LAYER.
    function B.layerText()
        local M=N.Main
        if N.Adapters.inInstance()==true then
            local name=S.str((S.call(_G.GetInstanceInfo)),80)
            return name or "Instance"
        end
        if N.Trust.state(M.store,S.call(GetTime))=="blind" then return "layer hidden" end
        local key=M.store and N.Layer.key(N.Trust.own(M.store,S.call(GetTime)))
        return key and ("Layer "..key) or "Detecting..."
    end
    local SHORT={
        {"^guild%-only","Guild-only mode"},{"^leave your current group","In a group"},{"^not available in an instance","In an instance"},
        {"^your live zone","Zone unknown"},{"ambiguous key cannot be used","Layer unknown"},{"^your own name","Name unreadable"},{"position is not readable","Position unknown"},
    }
    -- Line 2: the hop status from the same state and gates as the window's button. round: the open round, if any.
    function B.statusText()
        local M=N.Main
        local st=M.hopAnyState
        if not N.Trust.own(M.store,S.call(GetTime)) or M.blindPending or M.blindStatus then return M.blindStatus or "" end
        if not st then return "Hop not ready" end
        local r=st.round
        if r then
            if r.phase=="who" then return "Hopping: searching...",r end
            return "Hopping: asking "..(r.sent or 0).."...",r
        end
        local c=M.hopAnyContext(true) -- read only: the 1 s refresh must not change any state
        if N.Wire.hopBlocked(c.now) then return "Whispers paused" end
        local ok,why=N.HopAny.check(st,c)
        if ok then return "Hop ready" end
        local wait=0
        if st.lastClick then wait=math.max(wait,N.HopAny.CLICK-(c.now-st.lastClick)) end
        if c.invite and c.invite.lastAsk then wait=math.max(wait,N.Invite.GLOBAL_COOLDOWN-(c.now-c.invite.lastAsk)) end
        if wait>0 and (why or ""):find("10 s") then return "Wait "..math.ceil(wait).."s" end
        for _,s in ipairs(SHORT) do if (why or ""):find(s[1]) then return s[2] end end
        return "Hop not ready"
    end

    -- Left-click: the window button's action, on the painted round only (a round that started or ended since the last
    -- paint is not acted on). Gates, limits and the chat line on refusal are the window's own (Main.hopAny).
    function B.hop()
        local M=N.Main
        local shown=B.frame and B.frame.round
        if shown then
            if M.hopAnyState.round==shown then M.hopAnyStop() end
        elseif not M.hopAnyState.round then M.hopAny(B.frame.preview) end
        B.refresh()
    end

    function B.refresh()
        local f=B.frame
        if not f or not f:IsShown() then return end
        local layer=B.layerText()
        local status,round=B.statusText()
        f.round=round or false
        f.preview=not N.Trust.own(N.Main.store,S.call(GetTime)) and N.Main.blindPreview() or nil
        local one=saved().oneline
        f.text:SetText(one and (layer.."   "..status) or layer)
        f.status:SetText(one and "" or status)
        f.status:SetShown(not one)
        f.text:ClearAllPoints(); f.status:ClearAllPoints()
        if one then
            f.text:SetPoint("LEFT",f,"LEFT",28,0); f:SetHeight(22)
            f:SetWidth(math.ceil(f.text:GetStringWidth() or 0)+36)
        else
            f.text:SetPoint("TOPLEFT",f,"TOPLEFT",36,-5); f.status:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",36,5); f:SetHeight(34)
            f:SetWidth(math.ceil(math.max(f.text:GetStringWidth() or 0,f.status:GetStringWidth() or 0))+46)
        end
        f.logo:SetSize(one and 18 or 26,one and 18 or 26)
        f.text:SetTextColor(unpack(round and GREEN or {.92,.92,.92}))
    end
    local function savePosition(f)
        local point,_,relative,x,y=f:GetPoint(1)
        saved().position=N.UI.position({point=point,relative=relative,x=x,y=y})
    end
    local function tick(generation)
        if not B.frame or not B.frame:IsShown() or generation~=B.generation then return end
        B.refresh()
        -- without a timer the bar still updates on every click
        local timer=_G.C_Timer
        if S.tab(timer) and type(timer.After)=="function" then pcall(timer.After,1,function() tick(generation) end) end
    end
    function B.create()
        if B.frame then return B.frame end
        local f=CreateFrame("Button","LayerEnemiesHopBar",UIParent)
        f:Hide()
        B.frame=f
        f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton"); f:RegisterForClicks("LeftButtonUp","RightButtonUp")
        local p=saved().position or B.DEFAULT
        f:SetPoint(p.point,UIParent,p.relative,p.x,p.y)
        f.bg=f:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0,0,0,B.ALPHA)
        -- our logo: "LE" on a green square
        f.logo=f:CreateTexture(nil,"ARTWORK"); f.logo:SetPoint("LEFT",f,"LEFT",4,0); f.logo:SetSize(26,26)
        f.logo:SetColorTexture(.137,.227,.11,1)
        f.logoText=f:CreateFontString(nil,"OVERLAY"); f.logoText:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        f.logoText:SetPoint("CENTER",f.logo,"CENTER"); f.logoText:SetTextColor(unpack(GREEN)); f.logoText:SetText("LE")
        for _,key in ipairs({"text","status"}) do
            local fs=f:CreateFontString(nil,"OVERLAY"); fs:SetFont("Fonts\\FRIZQT__.TTF",11,""); fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false); fs:SetTextColor(.92,.92,.92); f[key]=fs
        end
        f.round,f.moved,f.dragging=false,false,false
        -- the end of a drag is not a click; a new left press starts clean (a right press during a drag does not)
        f:SetScript("OnMouseDown",function(self,button) if button=="LeftButton" and not self.dragging then self.moved=false end end)
        f:SetScript("OnDragStart",function(self) self.moved=true; self.dragging=true; self:StartMoving() end)
        f:SetScript("OnDragStop",function(self) self.dragging=false; self:StopMovingOrSizing(); savePosition(self) end)
        f:SetScript("OnClick",function(self,button)
            -- a drag is a left-button drag: its end swallows only a left click, never a right one
            if self.moved and button~="RightButton" then self.moved=false; return end
            if button=="RightButton" then
                if S.call(_G.IsShiftKeyDown)==true then
                    B.setShown(false)
                    N.Main.say("LayerEnemies: hop bar hidden. /le bar on brings it back (/le bar oneline: one line).")
                else N.UI.toggle() end
                return
            end
            B.hop()
        end)
        -- no tooltip: the bar is on screen all the time
        f:SetScript("OnShow",function()
            B.generation=(B.generation or 0)+1
            tick(B.generation)
        end)
        f:SetScript("OnHide",function() B.generation=(B.generation or 0)+1 end)
        return f
    end
    -- Called once the saved settings are loaded.
    function B.start()
        if saved().shown then B.create():Show() end
    end
    function B.setShown(on)
        saved().shown=on==true
        if on then B.create():Show() elseif B.frame then B.frame:Hide() end
    end
    function B.setOneLine(on)
        saved().oneline=on==true
        B.refresh()
    end
    -- /le bar on|off|oneline (oneline switches between one and two lines)
    function B.command(word)
        if word=="on" then B.setShown(true); N.Main.say("LayerEnemies: hop bar on (/le bar off hides it).")
        elseif word=="off" then B.setShown(false); N.Main.say("LayerEnemies: hop bar off (/le bar on shows it).")
        elseif word=="oneline" then
            B.setOneLine(not saved().oneline)
            N.Main.say("LayerEnemies: hop bar "..(saved().oneline and "on one line" or "on two lines").." (/le bar oneline switches).")
        else
            N.Main.say("LayerEnemies: hop bar "..(saved().shown and "on" or "off")..". /le bar on|off|oneline. Left-click hops, "
                .."right-click opens the window, Shift+right-click hides the bar, left-drag moves it.")
        end
    end
end
