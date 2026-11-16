-- Plain frames only: no secure templates or automatic player action.
local _,N=...
local U,S,T={generation=0},N.Safe,N.CallText
N.CallUI=U
local function now() return S.num(S.call(GetTime)) or 0 end
local function set(f,value) f:SetText(value=="" and "" or T.clean(value)) end
local function text(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,""); f:SetTextColor(.92,.88,.78); f:SetJustifyH("LEFT")
    return f
end
local function button(parent,width,label,fn)
    local b=CreateFrame("Button",nil,parent); b:SetSize(width,24)
    local bg=b:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.24,.13,.10,1)
    b.label=text(b,11); b.label:SetPoint("CENTER"); b.label:SetWidth(width-4); b.label:SetJustifyH("CENTER"); set(b.label,label)
    b:SetScript("OnClick",fn); return b
end
local function buttonLabel(b,id)
    local entry=T[id]
    local art=LayerEnemiesDB.callArt~=false and entry.art
    b.art:SetShown(not not art); b.label:SetShown(not art)
    if art then pcall(b.art.SetTexture,b.art,art) end
    set(b.label,art and "" or entry.en)
end
local function detail(key,value,y)
    local row,f,entry=U.rows[key],U[key],T[key]
    local art=LayerEnemiesDB.callArt~=false and entry.art
    row:ClearAllPoints(); row:SetPoint("TOPLEFT",U.frame,"TOPLEFT",12,-y)
    row.art:SetShown(not not art); f:ClearAllPoints()
    if art then
        pcall(row.art.SetTexture,row.art,art)
        -- Skip the texture's transparent lead-in, leaving a small gap before its colon.
        local valueRight=entry.inkLeft*96/128-3
        f:SetWidth(100); f:SetJustifyH("RIGHT"); f:SetPoint("TOPRIGHT",row.art,"TOPLEFT",valueRight,-4)
        set(f,value)
    else
        f:SetWidth(196); f:SetJustifyH("LEFT"); f:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
        set(f,entry.en.." "..value)
    end
    local height=math.max(18,S.num(S.call(f.GetStringHeight,f)) or 32)
    f:SetHeight(height); height=math.max(24,height+(art and 4 or 0)); row:SetHeight(height)
    return y+height+4
end
function U.close() if U.frame then U.frame:Hide() end end
function U.clear()
    U.close(); U.event=nil
    if U.help then U.help:SetScript("OnClick",nil) end
end
function U.check()
    if U.frame and U.frame:IsShown() and (not N.Main.calling() or N.Adapters.inInstance()~=false) then U.close() end
end
function U.create()
    if U.frame then return end
    local f=CreateFrame("Frame","LayerEnemiesCall",UIParent)
    f:Hide(); U.frame=f; f:SetSize(220,290); f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:EnableMouse(true)
    local anchor=MinimapCluster or Minimap
    if anchor then f:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-8)
    else f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-12,-180) end
    local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.07,.08,.10,.96)
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local t=f:CreateTexture(nil,"BORDER"); t:SetColorTexture(.45,.22,.17,1)
        t:SetPoint(edge[1]); t:SetPoint(edge[2]); if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    U.heading=f:CreateTexture(nil,"ARTWORK"); U.heading:SetSize(192,48); U.heading:SetPoint("TOP",f,"TOP",0,-14)
    U.latin=text(f,10); U.latin:SetWidth(196); U.latin:SetJustifyH("CENTER")
    U.rows={}
    for _,key in ipairs({"victim","killer","where"}) do
        local row=CreateFrame("Frame",nil,f); row:SetWidth(196); U.rows[key]=row
        row.art=row:CreateTexture(nil,"ARTWORK"); row.art:SetSize(96,24); row.art:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0)
        U[key]=text(row,11)
    end
    for _,key in ipairs({"body","age"}) do U[key]=text(f,key=="age" and 10 or 11); U[key]:SetWidth(196) end
    U.help=button(f,96,T[T.HELP].en,function() end); U.help:SetPoint("BOTTOMLEFT",12,10)
    U.dismiss=button(f,96,T[T.DISMISS].en,U.close); U.dismiss:SetPoint("BOTTOMRIGHT",-12,10)
    for _,b in ipairs({U.help,U.dismiss}) do
        b.art=b:CreateTexture(nil,"ARTWORK"); b.art:SetSize(96,24); b.art:SetPoint("CENTER")
    end
    U.closeButton=button(f,18,"x",U.close); U.closeButton:SetSize(18,16); U.closeButton:SetPoint("TOPRIGHT",-2,-2)
    f:SetScript("OnHide",function() U.generation=U.generation+1 end)
    if S.tab(UISpecialFrames) then UISpecialFrames[#UISpecialFrames+1]="LayerEnemiesCall" end
end
function U.render()
    local e=U.event
    if not e then return end
    local age=math.max(0,now()-e.at)
    if U.bodyId=="B4" and age>30 then local _,id=N.Call.pick(age); U.bodyId=id end
    local heading=T[U.headingId]
    local art=LayerEnemiesDB.callArt~=false and heading.art
    U.heading:SetShown(not not art)
    if art then pcall(U.heading.SetTexture,U.heading,art) end
    U.latin:SetFont("Fonts\\FRIZQT__.TTF",art and 10 or 14,"")
    U.latin:ClearAllPoints(); U.latin:SetPoint("TOPLEFT",12,art and -64 or -24); set(U.latin,heading.latin)
    set(U.age,math.floor(age).." s ago")
    set(U.body,T.format(U.bodyId,{victim=e.victim,killer=e.killer or "an enemy player",zone=N.Main.zoneName(e.zone)}))
    local y=art and 94 or 64
    y=detail("victim",e.victim,y)
    y=detail("killer",(e.killer or "an enemy player")..(e.level and " "..e.level or "")..(e.class and " "..e.class or ""),y)
    y=detail("where",N.Main.zoneName(e.zone),y)
    for _,field in ipairs({"body","age"}) do
        local row=U[field]; row:ClearAllPoints(); row:SetPoint("TOPLEFT",U.frame,"TOPLEFT",12,-y)
        local height=math.max(field=="body" and 48 or 18,S.num(S.call(row.GetStringHeight,row)) or 32)
        row:SetHeight(height); y=y+height+4
    end
    U.frame:SetHeight(y+42)
    buttonLabel(U.help,T.HELP); buttonLabel(U.dismiss,T.DISMISS)
    -- The closure owns precisely the rendered event, never a fresh lookup at click time.
    U.help:SetScript("OnClick",function()
        if not U.frame:IsShown() or U.event~=e then return end
        U.close()
        if N.Main.calling() and N.Adapters.inInstance()==false then N.Main.callHelp(e) end
    end)
end
local function later(delay,fn)
    return S.tab(C_Timer) and type(C_Timer.After)=="function" and pcall(C_Timer.After,delay,fn)
end
function U.tick(token)
    if token~=U.generation or not U.frame:IsShown() then return end
    U.check()
    if not U.frame:IsShown() then return end
    U.render()
    later(1,function() U.tick(token) end)
end
function U.show(e,action)
    U.create(); U.event=e
    if action~="enrich" then
        U.headingId,U.bodyId=N.Call.pick(math.max(0,now()-e.at))
        U.generation=U.generation+1
        local token=U.generation
        if not later(30,function() if token==U.generation then U.close() end end) then U.close(); return end
        later(1,function() U.tick(token) end)
    end
    U.render(); U.frame:Show()
end
