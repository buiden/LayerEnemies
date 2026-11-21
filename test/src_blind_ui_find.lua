local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup()
    local N=H.load(); H.clock(120); SlashCmdList.LAYERENEMIES("blind on")
    _G.LayerSwapDB={book={["Host Cedar"]={layer="987654-876543",zone=100,at=H.wall(),host=true}}}
    return N,N.Main
end

test("Blind UI: one Hop button on all tabs, exact tooltip, no row hop buttons",function()
    local N,M=setup()
    H.deliver("CHAT_MSG_ADDON","WEFF1","C|42|100|0.200|0.300|9000|1|100","PARTY","Scout Birch")
    M.track("Enemy Oak"); N.UI.toggle()
    for _,tab in ipairs({"friendly","reported","find","local"}) do
        N.UI.tab=tab; N.UI.render()
        yes(N.UI.hopAny:IsShown(),tab); eq(N.UI.hopAny.label:GetText(),"Hop (blind)")
        local text; _G.GameTooltip={SetOwner=function() end,SetText=function(_,v) text=v end,Show=function() end}
        N.UI.hopAny.scripts.OnEnter(); eq(text,M.BLIND_TIP)
        for _,r in ipairs(N.UI.pool) do
            if r:IsShown() then no(r.hopRecord); no(r.hostRow); no(r.ask:IsShown(),tab.." no secondary hop") end
        end
    end
end)

test("Blind UI: painted candidate cannot silently change before bar or button click",function()
    local N,M=setup(); N.UI.tab="friendly"; N.UI.toggle(); N.UI.render(); N.HopBar.refresh()
    _G.LayerSwapDB.book["Host Birch"]={zone=100,at=H.wall()+1,host=true}
    H.wall(H.wall()+1)
    local first=#H.sent()
    local f=N.HopBar.frame; H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
    eq(#H.sent(),first,"bar refuses changed shown host")
    H.clickWith(function() N.UI.hopAny.scripts.OnClick() end)
    eq(#H.sent(),first,"window refuses changed shown host")
end)

test("Blind UI: existing layered report and host entrypoints become blind, never layered requests",function()
    local N,M=setup()
    local record={src="we",zone=100,layer={ns="server",value="9000"}}
    local p=M.hopPreview(record); eq(p.label,"Hop (blind)"); yes(M.hopTo(record,p))
    local s=H.sent()[#H.sent()]; eq(s.text,"inv layer <LS 100 25.0,75.0>")
    M.hopDone(); H.advance(61)
    _G.LayerSwapDB.book["Host Birch"]={zone=100,at=H.wall(),host=true}
    local c={name="Host Birch",short="host birch",unknownOwn=true}
    p=M.hostPreview(c); eq(p.label,"Hop (blind)"); yes(M.hopHostTo(c,p)); no(M.error)
end)

test("Blind UI: LE hosts retain their network in the union without layer data",function()
    local N,M=setup(); _G.LayerSwapDB=nil
    H.roster({{"Host Birch",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Host Birch")
    local rows=M.blindCandidates(); eq(#rows,1); eq(rows[1].source,"LayerEnemies"); eq(rows[1].layer,nil)
end)

test("Blind Find: only changed hops increment, later own and report sightings reset, boundaries retain",function()
    local N,M=setup(); M.track("Enemy Oak"); yes(N.Find.changed,"changed-hop counter exists")
    N.Find.changed(M.find,120)
    local row=M.findRows()[1]; eq(row.search,"not seen on 1 layers tried")
    N.Find.changed(M.find,121); row=M.findRows()[1]; eq(row.search,"not seen on 2 layers tried")
    N.Find.boundary(M.find); eq(M.findRows()[1].search,"not seen on 2 layers tried")
    H.clock(122); N.Find.own(M.find,{name="Enemy Oak",faction="opposite",source="own target"},100,122)
    eq(M.findRows()[1].search,nil)
    N.Find.changed(M.find,123); eq(M.findRows()[1].search,"not seen on 1 layers tried")
    H.clock(124); N.Find.report(M.find,{enemies={{name="Enemy Oak"}},zone=100,at=124,sender="Scout Birch"})
    eq(M.findRows()[1].search,nil)
    N.Find.changed(M.find,125); H.clock(124); N.Find.report(M.find,{enemies={{name="Enemy Oak"}},zone=100,at=124,sender="Scout Birch"})
    eq(M.findRows()[1].search,"not seen on 1 layers tried","replayed older report is not a new sighting")
    N.Find.remove(M.find,"Enemy Oak"); N.Find.add(M.find,"Enemy Oak"); eq(M.findRows()[1].search,nil)
    eq(LayerEnemiesDB.search,nil); eq(LayerEnemiesDB.hops,nil)
end)

for _,changed in ipairs({true,false}) do
    test("Blind Find: real hop "..tostring(changed).." drives measured row text without layer claim",function()
        local N,M=setup(); M.track("Enemy Oak")
        for i=1,3 do H.units()["nameplate"..i]={guid="Creature-0-987654-0-876543-"..i.."-ABC",player=false} end
        yes(M.hopAny()); H.deliver("PARTY_INVITE_REQUEST","Host Cedar")
        H.group(true); H.units().party1={name="Host Cedar",player=true,leader=true}; H.deliver("GROUP_ROSTER_UPDATE")
        if changed then for i=1,3 do H.units()["nameplate"..i].guid="Creature-0-987654-0-876543-"..i.."-DEF" end end
        H.advance(5); H.advance(10); H.advance(15)
        local row=M.findRows()[1]
        eq(row.search,changed and "not seen on 1 layers tried" or nil)
        N.UI.tab="find"; N.UI.toggle(); N.UI.render()
        if changed then
            yes(M.findText(row):find("not seen on 1 layers tried",1,true))
            local r=N.UI.pool[1]; yes(r.sub:GetText():find("not seen on 1 layers tried",1,true))
            yes(r.sub.height>=r.sub:GetStringHeight()); no(r.sub:GetText():find("987654",1,true))
        end
        no(M.error)
    end)
end
