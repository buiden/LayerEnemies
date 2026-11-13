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
    r.age=font(r,10,colors.muted); r.age:SetPoint("TOPRIGHT",r,"TOPRIGHT",-8,-8); r.age:SetJustifyH("RIGHT")
    r.ask=button(r,220,20,"Ask for invite",function() if r.spotter then N.AskInvite(r.spotter); U.render() end end)
    r.ask:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",42,6)
    r.clear=button(r,42,18,"Clear",function() if r.tracked then N.Main.track(r.tracked,true); U.render() end end)
    r.clear:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-6,6)
    return r
end
function U.cooldown(name)
    local _,key=N.Invite.name(name)
    local st=N.Main.invite; local at=key and st.asked[key]
    if at and GetTime()-at<N.Invite.NAME_COOLDOWN then return math.ceil(N.Invite.NAME_COOLDOWN-(GetTime()-at)) end
end
local function askState(r,name,label)
    r.spotter=name
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
    U.layer:SetText(N.Layer.key(M.store.bulo) or "?")
    U.meta:SetText(M.zoneName(M.store.zone).." · "..(M.layerSource or "unknown"))
    U.input:SetShown(U.tab=="find"); U.add:SetShown(U.tab=="find")
    U.banner:SetText(U.tab=="reported" and "Reported, not confirmed. Dated by receipt time." or U.tab=="find" and "Up to five names. Hash matches are possible, not certain." or "")
    local height=U.tab=="local" and 48 or U.tab=="find" and 106 or U.tab=="friendly" and 68 or 80
    local top=U.tab=="find" and 56 or U.tab=="reported" and 23 or 0
    local visible=math.floor((300-top)/height)
    local maximum=math.max(0,#rows-visible)
    U.offset=math.min(U.offset,maximum)
    for _,r in ipairs(U.pool) do r:Hide(); r.spotter=nil; r.tracked=nil end
    for index=1,math.min(visible,#rows-U.offset) do
        local e=rows[index+U.offset]
        local r=U.pool[index]
        if not r then r=rowFrame(); U.pool[index]=r end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",U.body,"TOPLEFT",0,-top-(index-1)*height)
        r:SetHeight(height-4); r:Show(); r.clear:Hide()
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
            r.sub:SetText(className(e.class).." · "..M.zoneName(e.zone)); askState(r,nil)
        elseif U.tab=="reported" then
            r.title:SetText("Unknown "..className(e.class))
            r.sub:SetText("reported by "..e.reporter)
            local _,key=N.Invite.name(e.reporter)
            askState(r,key and eligible[key] and e.reporter or nil,"Ask "..e.reporter.." for invite")
        elseif U.tab=="friendly" then
            r.sub:SetText(table.concat(e.sources," + ")..(e.host and " · host" or "").." · "..(e.layer and "layer "..e.layer or "layer not known"))
            askState(r,e.name,"Ask for invite")
        else
            r.tracked=e.name; r.clear:Show()
            r.sub:SetText(e.at and (e.status.." · "..M.zoneName(e.zone).."\n"..className(e.class).." "..tostring(e.level or "?")..(e.same and " · already on your layer" or e.travel and (" · travel to "..M.zoneName(e.zone).." first") or "")) or e.status)
            askState(r,e.canAsk and e.spotter or nil,e.spotter and ("Ask "..e.spotter.." for invite") or "")
        end
    end
    U.hint:SetText(#rows==0 and "No eligible observations yet." or (#rows>visible and ("Mouse wheel: "..(U.offset+1).."–"..math.min(#rows,U.offset+visible).." of "..#rows) or ""))
    U.lastPaint=time
end
function U.refresh()
    if not U.frame or not U.frame:IsShown() then return end
    -- Data callbacks only mark dirty; a shown-only one-second timer paints ages/data.
    U.dirty=true
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
    U.frame=f; f:SetSize(360,468); f:SetFrameStrata("MEDIUM"); paint(f,colors.bg); border(f,{.18,.22,.26})
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
    U.banner=font(U.body,10,{.94,.76,.48}); U.banner:SetPoint("TOPLEFT",4,0); U.banner:SetWidth(340)
    U.input=CreateFrame("EditBox",nil,U.body); U.input:Hide(); U.input:SetSize(248,24); U.input:SetPoint("TOPLEFT",4,-23)
    U.input:SetFont("Fonts\\FRIZQT__.TTF",12,""); U.input:SetAutoFocus(false); U.input:SetMaxLetters(100); paint(U.input,colors.bar)
    local function add()
        if N.Main.track(U.input:GetText()) then U.input:SetText(""); U.input:ClearFocus() end
        U.render()
    end
    U.input:SetScript("OnEnterPressed",add); U.input:SetScript("OnEscapePressed",function() U.input:ClearFocus() end)
    U.add=button(U.body,76,24,"Track",add); U.add:SetPoint("TOPRIGHT",-4,-23)
    U.hint=font(f,10,colors.muted); U.hint:SetPoint("TOPLEFT",10,-420); U.hint:SetWidth(340)
    local footer=font(f,10,colors.muted); footer:SetPoint("BOTTOMLEFT",10,9); footer:SetWidth(340)
    footer:SetText("Only players seen by you or reported by War Effort users.")
    f:SetScript("OnShow",function() U.generation=(U.generation or 0)+1; U.tick(U.generation) end)
    f:SetScript("OnHide",function() U.generation=(U.generation or 0)+1; U.input:ClearFocus() end)
end
function U.toggle()
    U.create()
    if U.frame:IsShown() then U.frame:Hide() else U.frame:Show() end
end
