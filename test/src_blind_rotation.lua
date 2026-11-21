local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup()
    local N=H.load(); yes(N.HopAny.blindPick,"blind rotation exists"); return N,N.HopAny.new()
end
local function candidate(name,zone,age,network)
    return {name=name,short=name:lower(),zone=zone,age=age,source=network,addon=network=="LayerSwap"}
end

test("Blind rotation: zone then freshness, alternate network, skip last and all tried",function()
    local N,st=setup(); local B=N.HopAny
    local rows={candidate("Host Birch",101,0,"Bulo"),candidate("Host Cedar",100,3,"LayerSwap"),
        candidate("Host Fir",100,2,"LayerSwap"),candidate("Host Pine",100,4,"FLH")}
    local pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Fir")
    pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Pine","alternate network before fresher same network")
    pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Cedar")
    pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Birch")
    local why; pick,why=B.blindPick(st,rows,100,true)
    eq(pick,nil); eq(why,"all 4 known hosts tried this session")
    -- Read-only previews cannot consume the exhaustion click or mutate the cycle.
    for _=1,3 do eq(B.blindPick(st,rows,100,false).name,"Host Fir") end
    pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Fir","oldest try on restart")
    pick=B.blindPick(st,rows,100,true); eq(pick.name,"Host Pine")
end)

test("Blind rotation: no last-host repeat even with only one known host",function()
    local N,st=setup(); local rows={candidate("Host Fir",100,0,"LayerSwap")}
    yes(N.HopAny.blindPick(st,rows,100,true))
    local p,why=N.HopAny.blindPick(st,rows,100,true); no(p); eq(why,"all 1 known hosts tried this session")
    no(N.HopAny.blindPick(st,rows,100,true),"last host stays skipped")
end)

test("Blind rotation: bounded session ledger, deduped names, stable tie break and preview",function()
    local N,st=setup(); local B=N.HopAny
    local rows={candidate("Host Birch",100,0,"Bulo"),candidate("Host Cedar",100,0,"LayerSwap")}
    rows[3]=rows[1]
    eq(B.blindPick(st,rows,100,false).name,"Host Birch"); eq(st.blind,nil)
    for i=1,205 do
        local c=candidate("Host "..H.abc(i),100,0,i%2==0 and "Bulo" or "FLH")
        eq(B.blindPick(st,{c},100,true).short,c.short)
    end
    eq(N.Safe.count(st.blind.tried),200)
    eq(LayerEnemiesDB.blind,nil); eq(LayerEnemiesDB.tried,nil)
    local fresh=B.new(); eq(B.blindPick(fresh,rows,100,true).name,"Host Birch")
end)

test("Blind rotation: host union keeps networks, unknown keys, other zones and no relays",function()
    local N=H.load(); yes(N.Invite.blindCollect,"blind host union exists")
    local rows=N.Invite.blindCollect({self="me",now=100,wall=1000,zone=100,
        bulo={["Host Birch"]={key="0",zone=101,at=999,host=true}},
        book={["Host Cedar"]={layer="hidden",zone=100,at=997,host=true},["Gone Fir"]={zone=100,at=999,host=true,gone=999}},
        heard={["Host Pine"]={zone=100,at=996,host=true,network="LayerEnemies"}},
        flh={{name="Host Ash",map=101,key="0",at=998}},
        reporters={{name="Scout Elm",at=99,match=true},{name="Relay Oak",at=99,relayed=true}},
    })
    eq(#rows,5)
    local by={} for _,c in ipairs(rows) do by[c.name]=c; eq(c.layer,nil) end
    eq(by["Host Birch"].source,"Bulo"); eq(by["Host Birch"].zone,101); yes(by["Host Birch"].addon)
    eq(by["Host Cedar"].source,"LayerSwap"); yes(by["Host Cedar"].addon)
    eq(by["Host Pine"].source,"LayerEnemies"); yes(by["Host Pine"].addon)
    eq(by["Host Ash"].source,"Forever Layer Hop"); no(by["Host Ash"].addon)
    eq(by["Scout Elm"].source,"War Effort"); no(by["Scout Elm"].addon)
end)

test("Blind rotation: unconstrained builder has no layer, exact existing fallback shape",function()
    local N=H.load(); yes(N.Hop.lineBlind,"unconstrained builder exists")
    eq(N.Hop.lineBlind(100,.2,.3),"inv layer <LS 100 20.0,30.0>")
    eq(N.Hop.guildBlindLine(100,.2,.3),"/g inv layer <LS 100 20.0,30.0>")
    for _,zone in ipairs({0,-1,1.5,1000000000}) do eq(N.Hop.lineBlind(zone,.2,.3),nil) end
    eq(N.Hop.lineBlind(100,nil,.3),nil); eq(N.Hop.lineBlind(100,-.1,.3),nil)
    eq(N.Hop.lineBlind(100,.2,1.1),nil)
end)
