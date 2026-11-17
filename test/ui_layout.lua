-- Geometry regressions using the harness's approximate, width-aware metrics.
-- Native FRIZQT glyphs/UI scale still require a client; no live sends here.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local anchor={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},
    BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
local function box(f,root)
    local w,h=f:GetWidth(),f:GetHeight()
    if f==root then return {x=0,y=0,w=w,h=h} end
    local p=f.point; assert(p,"unanchored region")
    local relative,rp,x,y
    if type(p[2])=="table" then relative,rp,x,y=p[2],p[3],p[4] or 0,p[5] or 0
    else relative,rp,x,y=f.parent,p[1],p[2] or 0,p[3] or 0 end
    local r=box(relative,root); local a,b=anchor[p[1]],anchor[rp]
    return {x=r.x+b[1]*r.w+x-a[1]*w,y=r.y+b[2]*r.h-y-a[2]*h,w=w,h=h}
end
local function below(lower,upper,root,msg)
    local a,b=box(lower,root),box(upper,root)
    yes(a.y>=b.y+b.h+2,msg or "text regions need a gap")
end
local function header(U,want)
    if want then
        yes(U.hosting:IsShown()); below(U.hosting,U.meta,U.frame,"hosting follows all status lines")
        yes(U.hosting.width<=264,"hosting has a bounded wrapping width")
    else no(U.hosting:IsShown()) end
    for _,tab in pairs(U.tabs) do below(tab,want and U.hosting or U.meta,U.frame,"tabs below header") end
    below(U.body,U.tabs["local"],U.frame,"body below tabs")
    below(U.hint,U.body,U.frame,"hint below body")
    below(U.share,U.hint,U.frame,"settings below hint")
    local call=box(U.call,U.frame); yes(call.y+call.h<U.frame.height,"settings inside window")
end
test("UI layout: wrapped header follows status, hosting and long-zone changes on every tab",function()
    local N=H.load(); local U,M=N.UI,N.Main; U.toggle()
    local normalZone=M.zoneName; local longZone=string.rep("Long zone name ",9)
    for _,known in ipairs({false,true}) do
        if known then H.establish(N) end
        for _,long in ipairs({false,true}) do
            M.zoneName=long and function() return longZone end or normalZone
            for _,state in ipairs({"active","inactive","off"}) do
                M.host.want=state~="off"; M.host.on=state=="active"
                M.host.inactive="Guild name is not readable yet. Waiting for a fresh guild roster."
                for _,tab in ipairs({"local","reported","friendly","find"}) do
                    U.select(tab); header(U,M.host.want)
                    if long then yes(U.meta:GetStringHeight()>=36,"three-line status exercised") end
                end
            end
        end
    end
    eq(#H.sent(),0,"layout must not send")
end)
test("UI layout: option on, off and n/a labels fit on one line inside disjoint buttons",function()
    local N=H.load(); local U,M=N.UI,N.Main; U.toggle()
    for _,state in ipairs({"on","off","n/a"}) do
        local on=state=="on"
        M.sharing=function() return on end; M.calling=function() return on end
        N.Net.consent=function() return on and "guild" or "public" end
        N.Net.SHIP.we=state~="n/a"; N.Net.SHIP.hh=state~="n/a"
        N.Net.switch=function() return on end
        U.render(); eq(U.netHh.label:GetText(),"HeadHunter: "..state)
        yes(U.netHh.label:GetStringWidth()<=U.netHh.label.width,"HeadHunter label fits without clipping")
        local buttons={U.share,U.guildOnly,U.netWe,U.netHh,U.call}
        for i,b in ipairs(buttons) do
            eq(b.label.wordWrap,false,"buttons explicitly disable wrapping")
            yes(b.label:GetStringWidth()<=b.label.width,b.label:GetText().." fits")
            yes(b.label:GetStringHeight()<=b.height,"label fits height")
            local a=box(b,U.frame); yes(a.x>=6 and a.x+a.w<=354,"settings inside window")
            for j=1,i-1 do
                local c=box(buttons[j],U.frame)
                yes(a.x>=c.x+c.w+4 or c.x>=a.x+a.w+4 or a.y>=c.y+c.h+4 or c.y>=a.y+a.h+4,"option buttons do not collide")
            end
        end
    end
end)

test("UI layout: tab notes reserve their wrapped height before controls and rows",function()
    local N=H.load(); local U,M=N.UI,N.Main; U.toggle()
    M.findRows=function() return {{name="Cedar Vale"}} end
    M.candidates=function() return {{name="Birch Moss",short="birch moss",sources={"guild"},unknownOwn=true}} end
    N.Store.rows=function(_,_,kind)
        return kind=="reported" and {{reporter="Cedar Vale",class="MAGE",hand="first",record={}}} or {}
    end
    M.hopPreview=function() return {label="Ask for invite",enabled=false,reason="test"} end
    for _,size in ipairs({10,14}) do
        U.banner:SetFont("Fonts\\FRIZQT__.TTF",size,"")
        U.select("reported"); below(U.pool[1],U.banner,U.frame,"reported row below wrapped note")
        U.select("find"); below(U.banner,U.findTitle,U.frame,"Find note below title")
        below(U.input,U.banner,U.frame,"Find input below wrapped hint")
        below(U.add,U.banner,U.frame,"Track button below wrapped hint")
        below(U.pool[1],U.input,U.frame,"Find card below input")
        U.select("friendly")
        for _,b in ipairs({U.auto,U.host,U.findHosts}) do below(b,U.banner,U.frame,"friendly controls below unknown-layer hint") end
        below(U.hopAny,U.host,U.frame,"hop-any below friendly controls")
        below(U.pool[1],U.hopAny,U.frame,"friendly rows below hop-any")
    end
end)

test("UI layout: wrapped footer and hint stay clear of settings and inside window",function()
    local N=H.load(); local U=N.UI; U.toggle()
    local footer
    for _,f in ipairs(U.frame.regions) do if f:GetText():find("Only players seen",1,true) then footer=f end end
    yes(footer)
    for _,size in ipairs({10,14,20,10}) do
        footer:SetFont("Fonts\\FRIZQT__.TTF",size,""); U.hint:SetFont("Fonts\\FRIZQT__.TTF",size,"")
        U.render(); below(U.share,U.hint,U.frame,"settings below complete hint")
        below(footer,U.call,U.frame,"footer below second settings row")
        local f=box(footer,U.frame); yes(f.y+f.h<=U.frame.height-8,"footer inside window")
    end
end)

local function rowFits(r,U)
    yes(r.sub:GetStringHeight()<=r.sub.height,"all wrapped detail lines fit")
    below(r.sub,r.title,U.frame,"details below single-line title")
    eq(r.title.wordWrap,false,"long names must not wrap onto details")
    local last=r.sub
    if r.place:IsShown() then
        yes(r.place:GetStringHeight()<=r.place.height,"all wrapped place lines fit")
        if r.sub:GetText()~="" then below(r.place,r.sub,U.frame,"place below complete detail text") end
        last=r.place
    end
    for _,b in ipairs({r.ask,r.clear}) do if b:IsShown() then below(b,last,U.frame,"actions below complete row text") end end
    local a,b=box(last,U.frame),box(r,U.frame); yes(a.y+a.h<=b.y+b.h,"row text inside card")
    local c=box(U.body,U.frame); yes(b.y+b.h<=c.y+c.h,"card inside list")
end
local longZone="The Very Long Region around the Ruins of a Forgotten Ancient Kingdom"
test("UI layout: Find measures every retained line and OpenMap place before paging",function()
    local N=H.load(); local U,M=N.UI,N.Main
    local t=H.clock(); M.zoneName=function() return longZone end
    local row={name="Extraordinarilylongfirstname Longfamilyname",at=t,status="possible match, seen in a relayed report",zone=100,
        class="MAGE",level=60,canAsk=true,spotter="Extraordinarilylongfirstname Longfamilyname",travel=true,
        current={at=t,status="possible match, seen in a relayed report",zone=100,travel=true,class="MAGE",level=60},
        seen={at=t,spotter="Extraordinarilylongfirstname Longfamilyname",zone=100,own=true,layer="7086",status="last known: previous zone",x=.4,y=.5,pos="reported",travel=true},
        otherSeen={at=t,spotter="Extraordinarilylongfirstname Longfamilyname",zone=100,layer="7087",realmUnknown=true,probably=true,x=.4,y=.5,pos="reported"},
        reported={at=t,kind="claim",detail="possible match, seen in a relayed report",source="guild relay",zone=100,travel=true},
        place={map=100,x=.4,y=.5,at=t,age=999,faction="opposite"}}
    local rows={row,{name="Birch Moss"},{name="Cedar Vale"},{name="Elm Grove"}}
    M.findRows=function() return rows end
    U.toggle(); U.select("find"); rowFits(U.pool[1],U); header(U,false)
    local tall=U.body.height; yes(tall>300,"a complete tall card expands the list")
    for _=1,20 do U.body.scripts.OnMouseWheel(nil,-1) end
    local last
    for _,r in ipairs(U.pool) do if r:IsShown() then rowFits(r,U); last=r.tracked end end
    eq(last,"Elm Grove","last row reachable")
    rows={{name="Birch Moss"}}; U.render(); rowFits(U.pool[1],U)
    eq(U.body.height,300); eq(U.offset,0); eq(U.pool[1].sub.height,14); no(U.pool[1].place:IsShown())
end)
test("UI layout: local, Reported and Friendly cards also fit long wrapped details",function()
    local N=H.load(); local U,M=N.UI,N.Main; U.toggle()
    local name="Extraordinarilylongfirstname Longfamilyname"
    M.zoneName=function() return longZone end
    N.Store.rows=function(_,_,kind)
        return kind=="local" and {{name=name,zone=100,class="MAGE",at=H.clock()}} or
            {{reporter=name,via=name.."-12345",hand="relay",class="MAGE",record={}}}
    end
    M.candidates=function() return {{name=name,short=name,sources={"BuloLayerForever","LayerSwap guild host","War Effort"},unknownOwn=true}} end
    M.hopPreview=function() return {label="Ask for invite",enabled=false,reason="test"} end
    for _,tab in ipairs({"local","reported","friendly"}) do U.select(tab); rowFits(U.pool[1],U) end
end)