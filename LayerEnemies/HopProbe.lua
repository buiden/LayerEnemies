-- Pure, session-only blind-hop proxy. GUIDs are equality tokens, never layer IDs.
local _,N=...
local P,S={},N.Safe
N.HopProbe=P
-- Guesses from the plan; not calibrated in game.
P.CREATURES,P.PLAYERS,P.REMAINING_DENOMINATOR,P.YARDS=3,5,5,40
P.CHECKS={5,15,30}
P.MAX_UNITS=42
function P.snapshot(rows,position)
    local out={creatures={},npcs={},players={},creatureCount=0,playerCount=0}
    for i,row in ipairs(rows or {}) do
        if i>P.MAX_UNITS then break end
        local guid=S.str(row.guid,160)
        local player=S.clean(row.player)
        if guid and player==true then
            if not out.players[guid] then out.players[guid]=true; out.playerCount=out.playerCount+1 end
        elseif guid and player==false and guid:match("^Creature%-") then
            local npc,spawn=guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-([%x]+)$")
            if npc and tonumber(npc)>0 then
                local key=npc..":"..spawn
                if not out.creatures[key] then
                    out.creatures[key]=npc; out.npcs[npc]=true; out.creatureCount=out.creatureCount+1
                end
            else out.unparsed=true end
        end
    end
    if position then
        local x,y,map=S.num(position.x),S.num(position.y),S.num(position.map)
        if x and y and map then out.position={x=x,y=y,map=map} end
    end
    return out
end
function P.judge(before,after,transfer)
    if transfer then return "creatures" end
    local usable=not before.unparsed and not after.unparsed
    if usable and before.creatureCount>=P.CREATURES then
        local shared,retained=0,false
        for key,npc in pairs(before.creatures) do
            if after.npcs[npc] then shared=shared+1 end
            if after.creatures[key] then retained=true end
        end
        if shared>=P.CREATURES and not retained then return "creatures" end
    end
    if before.playerCount>=P.PLAYERS then
        local retained=0
        for guid in pairs(before.players) do if after.players[guid] then retained=retained+1 end end
        local a,b=before.position,after.position
        if a and b and a.map==b.map and (a.x-b.x)^2+(a.y-b.y)^2<P.YARDS^2
            and retained*P.REMAINING_DENOMINATOR<=before.playerCount then return "players" end
    end
    if (before.unparsed or before.creatureCount<P.CREATURES) and before.playerCount<P.PLAYERS then return "sparse" end
    return "unchanged"
end
function P.text(result,name)
    if result=="creatures" then return "Hopped (layer unknown): the creatures around you changed." end
    if result=="players" then return "Hopped (layer unknown): the players around you changed." end
    if result=="unchanged" then return "Joined "..name..". No change seen; you may be on the same layer." end
    if result=="sparse" then return "Joined "..name..". Too little around you to tell." end
    if result=="missed" then return name.." did not invite." end
end
