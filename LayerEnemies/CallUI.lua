-- Plain frames only: no secure templates or automatic player action.
local _,N=...
local U,S,T={generation=0},N.Safe,N.CallText
N.CallUI=U
local function now() return S.num(S.call(GetTime)) or 0 end
local function set(f,value) f:SetText(T.clean(value)) end
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
    for _,key in ipairs({"victim","killer","where","body","age"}) do U[key]=text(f,key=="age" and 10 or 11); U[key]:SetWidth(196) end
    U.help=button(f,96,T[T.HELP].en,function() end); U.help:SetPoint("BOTTOMLEFT",12,10)
    U.dismiss=button(f,96,T[T.DISMISS].en,U.close); U.dismiss:SetPoint("BOTTOMRIGHT",-12,10)
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
    set(U.victim,T.victim.en.." "..e.victim)
    set(U.killer,T.killer.en.." "..(e.killer or "an enemy player")..(e.level and " "..e.level or "")..(e.class and " "..e.class or ""))
    set(U.where,T.where.en.." "..N.Main.zoneName(e.zone))
    set(U.age,math.floor(age).." s ago")
    set(U.body,T.format(U.bodyId,{victim=e.victim,killer=e.killer or "an enemy player",zone=N.Main.zoneName(e.zone)}))
    local y=art and 94 or 64
    for _,field in ipairs({"victim","killer","where","age","body"}) do
        local row=U[field]; row:ClearAllPoints(); row:SetPoint("TOPLEFT",12,-y)
        local height=math.max(field=="body" and 48 or 18,S.num(S.call(row.GetStringHeight,row)) or 32)
        row:SetHeight(height); y=y+height+4
    end
    U.frame:SetHeight(y+42)
    set(U.help.label,T[T.HELP].en); set(U.dismiss.label,T[T.DISMISS].en)
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
