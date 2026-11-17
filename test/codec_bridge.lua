-- Offline line protocol for Python cross-language tests; no donor dependencies.
local N={Safe={secret=function() return false end}}
assert(loadfile("LayerEnemies/Codec.lua"))("LayerEnemies",N)
local C=N.Codec
local function unhex(s) return (s:gsub("..",function(x) return string.char(tonumber(x,16)) end)) end
for line in io.lines() do
    local mode,h=line:match("^(%w+)\t(%x*)$")
    assert(mode)
    local s=unhex(h);local out
    if mode=="ace" then out=C.aceWrite(C.aceRead(s))
    elseif mode=="ls" then out=C.lsWrite(C.lsRead(s))
    else assert(type(C[mode])=="function"); out=C[mode](s) end
    if out then print((out:gsub(".",function(c) return string.format("%02x",c:byte()) end))) else print("nil") end
end
