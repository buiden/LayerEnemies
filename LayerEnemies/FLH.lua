-- Forever Layer Hop 0.1.9 wire facts only; independent decoder and builders.
-- No donor code. See THIRD_PARTY.md. Keys are GUID field 5 (zoneUID), NOT
-- LayerSwap/Bulo server keys (GUID field 3); never feed one to Layer.key.
local _, N = ...
local S, FL = N.Safe, {}
N.FLH = FL

local function integer(s)
    if not S.str(s,255) or not s:match("^%d+$") then return nil end
    return S.num(tonumber(s))
end
function FL.key(s)
    local n=integer(s)
    return n and n>0 and s or nil
end

local layouts={
    HI={map=2,key=3,host=4,version=5,realm=6},
    WP={id=2,realm=3,version=4,map=5,key=6,host=7},
    WR={id=2,realm=3,version=4,map=5,key=6,host=7},
    CQ={id=2,map=3,key=4,host=5,version=6,realm=7},
    CA={id=2,map=3,key=4,host=5,version=6,realm=7},
    LQ={id=2,map=3,wantedKey=4,ownKey=5,knownCSV=6},
    LO={id=2,map=3,key=4,groupSize=5,load=6},
    LR={id=2,map=3,key=4,version=5},
    LN={id=2,reason=3},
}
function FL.decode(text)
    if S.secret(text) or type(text)~="string" or #text>255 or text:find("%c") then return nil end
    local fields={}
    -- The appended separator keeps empty positions, including the final one.
    for value in (text.."|"):gmatch("([^|:]*)[|:]") do fields[#fields+1]=value end
    local cmd=fields[1]
    local layout=layouts[cmd]
    if not layout then return nil end
    local count=1
    for _,index in pairs(layout) do count=math.max(count,index) end
    if #fields<count then return nil end
    for i=count+1,#fields do
        if not fields[i]:match("^[A-Z][A-Z0-9_]*=[^|:]*$") then return nil end
    end
    local out={cmd=cmd}
    for field,index in pairs(layout) do
        local value=fields[index]
        if field=="host" then
            if value~="0" and value~="1" then return nil end
            value=integer(value)
        elseif field=="map" or field=="id" or field=="groupSize" or field=="load" then value=integer(value)
        elseif field=="key" or field=="ownKey" or field=="wantedKey" then
            local empty=(field=="ownKey" or (field=="key" and layout.host)) and value==""
            value=(empty or (field=="wantedKey" and value=="*")) and value or FL.key(value)
        elseif field=="knownCSV" then
            if value~="" then
                for key in (value..","):gmatch("([^,]*),") do if not FL.key(key) then return nil end end
            end
        else value=S.str(value,255) end
        if value==nil then return nil end
        out[field]=value
    end
    if layout.host and out.host~=0 and out.host~=1 then return nil end
    return out
end

-- Outgoing identity is LayerEnemies' own version, never an FLH release.
local function atom(v,max)
    v=S.str(v,max or 100)
    return v and not v:find("[|:]") and v or nil
end
local function digits(v)
    v=S.num(v)
    return v and v>=0 and v%1==0 and v<=2147483647 and string.format("%.0f",v) or nil
end
local function build(cmd,id,c,key)
    if not S.tab(c) then return nil end
    local map,own,realm,version=digits(c.map),FL.key(c.key),atom(c.realm,60),atom(c.version,60)
    if not map or not own or not realm or not version or not version:match("^LayerEnemies %d+%.%d+%.%d+[%w%.%-]*$") then return nil end
    local rid=id~=nil and digits(id) or nil
    if cmd~="HI" and not rid then return nil end
    local fields
    if cmd=="HI" then fields={cmd,map,own,"0",version,realm}
    elseif cmd=="WR" or cmd=="WP" then fields={cmd,rid,realm,version,map,own,"0"}
    elseif cmd=="CA" then fields={cmd,rid,map,own,"0",version,realm}
    elseif cmd=="LQ" then
        if key~="*" and not FL.key(key) then return nil end
        fields={cmd,rid,map,key,own,""}
    elseif cmd=="LR" then
        if not FL.key(key) then return nil end
        fields={cmd,rid,map,key,version}
    else return nil end
    fields[#fields+1]="BUILD="..version
    if cmd=="WP" then fields[#fields+1]="AUTO=1" end
    local text=table.concat(fields,"|")
    return #text<=255 and text or nil
end
function FL.hi(c) return build("HI",nil,c) end
function FL.wr(id,c) return build("WR",id,c) end
function FL.ca(id,c) return build("CA",id,c) end
function FL.wp(id,c) return build("WP",id,c) end
function FL.lq(id,c,key) return build("LQ",id,c,key) end
function FL.lr(id,c,key) return build("LR",id,c,key) end
