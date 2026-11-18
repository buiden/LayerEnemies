-- 1.2.1 "On my way": one hidden LEGW1 guild line, sent only by the Call help click.
-- Line: G|1|<zone>|<victim hex>. The helper is the sender. Nothing is saved.
-- Older clients drop it: their relay decoder accepts only R| lines.
local _,N=...
local Cm,S={},N.Safe
N.Coming=Cm
Cm.GAP,Cm.CAP,Cm.WINDOW,Cm.MAXNAME=10,6,600,60
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function unhex(h)
    if type(h)~="string" or #h<2 or #h%2~=0 or #h>Cm.MAXNAME*2 or h:find("[^%x]") then return nil end
    return (h:gsub("%x%x",function(b) return string.char(tonumber(b,16)) end))
end
function Cm.new() return {sent={}} end
function Cm.line(zone,victim)
    zone=S.num(zone)
    if not zone or zone<1 or zone>999999 or zone%1~=0 then return nil end
    if not S.str(victim,Cm.MAXNAME) or victim=="" or victim:find("[%c|]") then return nil end
    return "G|1|"..zone.."|"..hex(victim)
end
function Cm.decode(text)
    if S.secret(text) or type(text)~="string" or #text>255 then return nil end
    local zone,h=text:match("^G|1|(%d+)|(%x+)$")
    zone=tonumber(zone)
    if not zone or zone<1 or zone>999999 then return nil end
    local victim=unhex(h)
    if not victim or victim:find("[%c|]") then return nil end
    return {zone=zone,victim=victim}
end
-- allow(st,time) -> true and records the send: at most one per 10 s and six per 600 s
function Cm.allow(st,time)
    if not S.num(time) then return false end
    local kept={}
    for _,at in ipairs(st.sent) do if time>=at and time-at<Cm.WINDOW then kept[#kept+1]=at end end
    st.sent=kept
    local last=kept[#kept]
    if (last and time-last<Cm.GAP) or #kept>=Cm.CAP then return false end
    kept[#kept+1]=time
    return true
end
