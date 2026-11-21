-- Data-driven alert pop-ups in the Call style. One frame; a new alert type is one TYPES entry.
-- Plain frames only, no sends. Each button closure owns exactly the data it was rendered with.
local _,N=...
local P,S={generation=0},N.Safe
N.Popup=P
local function now() return S.num(S.call(GetTime)) or 0 end
local function ago(seconds)
    seconds=math.floor(math.max(0,seconds or 0))
    return seconds<60 and (seconds.." s ago") or (math.floor(seconds/60).." min ago")
end
P.TYPES={
    found={
        title="Tracked enemy found",
        life=30,
        rows=function(d,foundRows)
            local who=tostring(d.name)..((d.level~=nil and " "..tostring(d.level) or "")..(d.class~=nil and " "..tostring(d.class) or ""))
            return {who,N.Main.zoneName(d.zone),ago(d.age),d.status and d.status(foundRows) or d.source or ""}
        end,
        buttons={
            {label="Show on map",run=function(d) N.Main.showOnMap(d.zone,d.x,d.y) end},
            {label="Dismiss"},
        },
    },
}
P.ROWS,P.BUTTONS=4,2
function P.close() if P.frame then P.frame:Hide() end end
function P.create()
    if P.frame then return end
    local U=N.CallUI
    local f=U.panel("LayerEnemiesPopup",220,150); P.frame=f
    P.title=U.text(f,13); P.title:SetWidth(196); P.title:SetPoint("TOPLEFT",12,-12)
    P.rows={}
    for i=1,P.ROWS do
        local row=U.text(f,11); row:SetWidth(196); row:SetPoint("TOPLEFT",12,-18-i*18); P.rows[i]=row
    end
    P.buttons={}
    for i=1,P.BUTTONS do
        local b=U.button(f,96,"",function() end); P.buttons[i]=b
        if i==1 then b:SetPoint("BOTTOMLEFT",12,10) else b:SetPoint("BOTTOMRIGHT",-12,10) end
    end
    f:SetScript("OnHide",function() P.generation=P.generation+1; P.data=nil end)
end
local function later(delay,fn)
    return S.tab(C_Timer) and type(C_Timer.After)=="function" and pcall(C_Timer.After,delay,fn)
end
-- Repaint only; retain the original buttons, generation and close deadline.
function P.refresh(foundRows)
    if not P.data or not P.frame or not P.frame:IsShown() then return end
    local rows=P.TYPES[P.kind].rows(P.data,foundRows)
    for i=1,P.ROWS do N.CallUI.set(P.rows[i],rows[i] or "") end
end
-- show(kind,data) -> true when shown. Callers decide eligibility; instances never show.
function P.show(kind,data)
    local t=P.TYPES[kind]
    if not t or not S.tab(data) or N.Adapters.inInstance()~=false then return false end
    P.create()
    local U=N.CallUI
    U.set(P.title,t.title)
    local rows=t.rows(data)
    for i=1,P.ROWS do U.set(P.rows[i],rows[i] or "") end
    for i=1,P.BUTTONS do
        local spec,b=t.buttons[i],P.buttons[i]
        b:SetShown(spec~=nil)
        if spec then
            U.set(b.label,spec.label)
            b:SetScript("OnClick",function()
                if not P.frame:IsShown() or P.data~=data then return end
                P.close()
                if spec.run and N.Adapters.inInstance()==false then spec.run(data) end
            end)
        end
    end
    P.frame:Show(); P.data,P.kind=data,kind
    P.generation=P.generation+1
    local token=P.generation
    if not later(t.life or 30,function() if token==P.generation then P.close() end end) then P.close(); return false end
    return true
end
