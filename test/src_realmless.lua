-- Realm-less Forever identities; mock client APIs, real loaded event handlers.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup(name,mode,second)
    return H.load(nil,function()
        local original=UnitName
        UnitName=function(unit) if unit=="player" then return name,second end; return original(unit) end
        local function realm()
            if mode=="empty" then return "" elseif mode=="secret" then return H.secret
            elseif mode=="throw" then error("realm unavailable") end
        end
        GetRealmName=realm; GetNormalizedRealmName=realm
    end)
end
local function receive(prefix,text,sender,route)
    H.deliver("CHAT_MSG_ADDON",prefix,text,route or "GUILD",sender or "Birch Scout")
end
for _,mode in ipairs({"empty","nil","secret","throw"}) do
    for _,name in ipairs({"Ash Example","Solo"}) do
        test("Realm-less: "..mode.." "..name.." identity and blind Hop",function()
            local N=setup(name,mode); local M=N.Main
            local full,key=N.Adapters.ownIdentity(); eq(full,name); eq(key,name:lower())
            eq(M.homeRealm(),""); yes(M.isMe(name:upper())); no(M.isMe(name.."-8123"))
            eq(N.Invite.key(name.."-8123"),name:lower().."-8123","unknown realm is never stripped")
            _G.LayerSwapDB={book={["Host Cedar"]={layer="9000-7",zone=100,at=H.wall(),host=true},
                [name]={layer="9000-7",zone=100,at=H.wall(),host=true}}}
            local p=M.hopAnyPreview(); eq(p.label,"Hop (blind)"); yes(p.enabled,p.reason)
            eq(#M.blindCandidates(),1,"own host excluded")
            local f=N.HopBar.frame; N.HopBar.refresh()
            H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
            local asks=0
            for _,s in ipairs(H.sent()) do if s.prefix=="LayerSwap" then
                asks=asks+1; eq(s.target,"Host Cedar"); eq(s.text,"inv layer <LS 100 25.0,75.0>")
            end end
            eq(asks,1); eq(#H.whoCalls(),0); no(M.error)
        end)
        for _,lane in ipairs({"LEGW1","FLHNET2","LFSw","WEFF1","Spy","Call help"}) do
            test("Realm-less: "..mode.." "..name.." real "..lane.." ingress and echo",function()
                local N=setup(name,mode); local M=N.Main; H.clock(120)
                if lane=="LEGW1" then
                    yes(M.track("Cedar Vale"))
                    local line=N.Relay.ownLine({rid=7,zone=100,age=0,layer="7085",count=1,enemies={{name="Cedar Vale"}}})
                    receive("LEGW1",line,name); eq(next(M.store.reports),nil)
                    receive("LEGW1",line); yes(next(M.store.reports)); yes(M.findRows()[1].at)
                elseif lane=="FLHNET2" then
                    local line="HI|100|007|1|0.1.3|1234"
                    receive(lane,line,name); eq(next(M.heard.flhHosts),nil)
                    receive(lane,line); yes(M.heard.flhHosts["birch scout"])
                elseif lane=="LFSw" then
                    receive(lane,"L 9000|100|h",name); eq(next(M.guildLines),nil)
                    receive(lane,"L 9000|100|h"); yes(M.guildLines["Birch Scout"])
                elseif lane=="WEFF1" then
                    local line="H|1.6.6|100|7086|1|19"
                    receive(lane,line,name); eq(M.lastDrop,"own echo"); eq(M.lastHeard,nil)
                    receive(lane,line); eq(M.lastHeard,H.clock())
                elseif lane=="Spy" then
                    local line="1.3.8|Cedar-Vale|ROGUE|47|Orc|Ashenvale||0.4|0.6||100"
                    receive("[Spy]",line,name); eq(M.lastDrop,"own echo"); eq(next(M.store.reports),nil)
                    receive("[Spy]",line); yes(next(M.store.reports))
                else
                    local line="D|Cedar Vale|100|42.5|61.0|Forest|60|2|ROGUE|"
                    receive("GBOUNTY",line,name); eq(M.call.current,nil)
                    receive("GBOUNTY",line); yes(N.CallUI.frame and N.CallUI.frame:IsShown())
                    N.CallUI.help:Click()
                    local n=0
                    for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and s.text:sub(1,2)=="G|" then
                        n=n+1; eq(N.Coming.decode(s.text).victim,"Birch Scout")
                    end end
                    eq(n,1,"real help click reaches comingSend")
                end
                no(M.error)
            end)
        end
    end
end

test("Realm-less: malformed and secret names remain unavailable",function()
    for _,name in ipairs({H.secret,false,42,"","A","Ash  Example"," Ash Example","Ash Example ",
        "Ash Example Third","Ash2","Ash\tExample","Ash\nExample","Ash|Example","Ash-", "Ash-8123",
        string.rep("A",37),"Ash "..string.rep("B",37),"Ash\194\160Example","Ash\255"}) do
        local N=setup(name,"empty"); eq(N.Adapters.ownIdentity(),nil)
        no(N.Main.hopAnyPreview().enabled); no(N.Adapters.policy("WEFF1","GUILD","Birch Scout"))
    end
    for _,second in ipairs({H.secret,false,42,"Other Other","Example-8123"}) do
        local N=setup("Ash Example","empty",second); eq(N.Adapters.ownIdentity(),nil)
    end
    local N=setup(nil,"empty"); eq(N.Adapters.ownIdentity(),nil)
    UnitName=function() error("name unavailable") end; eq(N.Adapters.ownIdentity(),nil)
end)

test("Realm-less: split and already-combined surnames need no home realm",function()
    for _,first in ipairs({"Ash","Ash Example"}) do
        local N=setup(first,"empty","Example")
        eq(N.Adapters.ownIdentity(),"Ash Example"); no(N.Main.isMe("Ash")); yes(N.Main.isMe("Ash Example"))
    end
end)
