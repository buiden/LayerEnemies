local _, N = ...
_G.LayerEnemies = N
local S = {}
N.Safe = S
function S.secret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, hidden = pcall(issecretvalue, v)
    return not ok or hidden == true
end
function S.clean(v) if not S.secret(v) then return v end end
function S.str(v, max)
    if S.secret(v) or type(v) ~= "string" or #v == 0 or #v > (max or 160) then return nil end
    if v:find("[%c|]") then return nil end
    return v
end
function S.num(v)
    if S.secret(v) or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
function S.tab(v) return not S.secret(v) and type(v) == "table" end
function S.call(fn, ...)
    if S.secret(fn) or type(fn) ~= "function" then return nil end
    local ok, a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok then return nil end
    return S.clean(a),S.clean(b),S.clean(c),S.clean(d),S.clean(e),S.clean(f),S.clean(g),S.clean(h)
end
function S.count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function S.clear(t) for k in pairs(t) do t[k]=nil end end
