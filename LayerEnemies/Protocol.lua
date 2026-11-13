-- Independent parser for the documented WEFF1 / ZRAD1 wire grammar.
local _, N = ...
local P, S = {}, N.Safe
N.Protocol=P
P.classes={A="WARRIOR",B="PALADIN",C="HUNTER",D="ROGUE",E="PRIEST",F="DEATHKNIGHT",G="SHAMAN",H="MAGE",I="WARLOCK",J="MONK",K="DRUID",L="DEMONHUNTER",M="EVOKER"}
local function uint(s,lo,hi)
    if type(s)~="string" or #s>10 or not s:match("^%d+$") then return nil end
    local n=tonumber(s)
    if n>=lo and n<=hi then return n end
end
local function coord(s)
    if type(s)~="string" or not (s:match("^[01]$") or s:match("^[01]%.%d%d?%d?$")) then return nil end
    local n=tonumber(s); if n<=1 then return n end
end
function P.decode(text)
    if not S.str(text,255) then
        -- Pipes are part of the wire format, not printable names.
        if S.secret(text) or type(text)~="string" or #text<1 or #text>255 or text:find("[%c]") then return nil end
    end
    local f={}
    for field in (text.."|"):gmatch("([^|]*)|") do
        f[#f+1]=field; if #f>12 then return nil end
    end
    local t=f[1]
    if t=="C" then
        if #f~=8 and #f~=9 then return nil end
        local r={kind=t,id=uint(f[2],1,65535),map=uint(f[3],1,999999),x=coord(f[4]),y=coord(f[5]),layer=uint(f[6],0,99999999),count=uint(f[7],1,200),stamp=uint(f[8],0,3599)}
        if #f==9 then r.spread=uint(f[9],0,45); if not r.spread then return nil end end
        if r.id and r.map and r.x and r.y and r.layer and r.count and r.stamp then return r end
    elseif t=="E" then
        if #f~=6 then return nil end
        local r={kind=t,id=uint(f[2],1,65535),part=uint(f[3],1,9),total=uint(f[4],1,9),stamp=uint(f[6],0,3599),enemies={}}
        if not r.id or not r.part or not r.total or r.part>r.total or not r.stamp or f[5]=="" then return nil end
        for item in (f[5]..","):gmatch("([^,]*),") do
            local hash,code,level=item:match("^([0-9A-Za-z][0-9A-Za-z][0-9A-Za-z]):([A-M?]):([%d?%-]+)$")
            if not hash or #r.enemies>=18 then return nil end
            local lvl=level=="-1" and -1 or uint(level,1,100)
            if level~="?" and not lvl then return nil end
            r.enemies[#r.enemies+1]={hash=hash,class=P.classes[code],level=lvl}
        end
        return r
    elseif t=="H" then
        -- Only stamped modern hellos. Legacy undated hellos are intentionally rejected.
        if #f<9 or #f>12 or #f[2]>20 or not f[2]:match("^%d+%.%d+%.%d+$") then return nil end
        local r={kind=t,version=f[2],map=uint(f[3],0,999999),layer=uint(f[4],0,99999999),sharing=uint(f[5],0,1),proto=uint(f[6],5,999),mode=uint(f[7],0,1),realm=uint(f[8],0,999999),stamp=uint(f[9],0,3599)}
        if not (r.map and r.layer and r.sharing and r.proto and r.mode and r.realm and r.stamp) then return nil end
        if f[10] and f[10]~="-" and (not f[10]:match("^%d+$") or #f[10]>20) then return nil end
        if f[11] and not P.classes[f[11]] then return nil end
        if f[12] and not uint(f[12],1,100) then return nil end
        return r
    end
end
-- A necessary check, NOT sufficient freshness evidence: old hours alias.
-- ahead: seconds a stamp may run ahead of our clock and still count as just
-- sent (receipt-time mode only; clients round the shared clock differently).
function P.clockAge(stamp,serverSeconds,ahead)
    if not S.num(serverSeconds) then return nil end
    local age=(math.floor(serverSeconds)%3600-stamp)%3600
    if age<=30 then return age end
    if ahead and age>=3600-ahead then return 0 end
end
P.AHEAD=5
