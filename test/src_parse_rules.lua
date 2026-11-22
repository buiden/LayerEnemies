local H=...
H.test("Parity parser: optional clauses rules and coordinates may all be absent",function()
    local N=H.load()
    for _,line in ipairs({"inv layer <LS 100>","inv layer <LS 100 r2>","inv layer <LS 100 r99>"}) do
        local r=N.GuildHost.parse(line); H.yes(r,line); H.eq(r.zone,100); H.yes(r.blind)
    end
    H.eq(N.GuildHost.parse("inv layer <LS 0>"),nil)
end)
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
for _,body in ipairs({"want 7088-2", "not 7088-2", "not 7088-2 not 9000-3", ""}) do
    for _,pos in ipairs({"", " 48.2,42.5"}) do
        test("Parity parser: rules after "..body..pos,function()
            local N=H.load()
            for _,tag in ipairs({"r2","r99"}) do
                local line="inv layer <LS 1429 "..(body~="" and body.." " or "")..tag..pos..">"
                local r=N.GuildHost.parse(line); yes(r,"rules-tag request accepted"); eq(r.zone,1429)
                if body:find("want",1,true) then eq(r.want,"7088-2")
                elseif body~="" then eq(r.nots[1],"7088-2") else yes(r.blind) end
                eq(r.x,pos~="" and 48.2 or nil)
            end
        end)
    end
end
H.test("Parity parser: rejects misplaced duplicate incomplete rules; legacy intact",function()
    local N=H.load()
    for _,body in ipairs({"not 7088-2 r", "r2 not 7088-2", "not 7088-2 r2 r99", "r2 r2", "r2 48.2,42.5 not 9000-3"}) do
        no(N.GuildHost.parse("inv layer <LS 1429 "..body..">"),body)
    end
    for _,body in ipairs({"want 7088-2", "not 7088-2", "not 7088-2 not 9000-3", "48.2,42.5"}) do
        yes(N.GuildHost.parse("inv layer <LS 1429 "..body..">"),body)
    end
end)
