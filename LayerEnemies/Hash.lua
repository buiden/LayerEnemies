local _, N = ...
local H, S = {}, N.Safe
N.Hash = H
local alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
function H.nameKey(name, realm)
    name = S.str(name)
    if realm==nil then realm="" end
    if not name or S.secret(realm) or type(realm)~="string" or (#realm>0 and not S.str(realm)) then return nil end
    return name:lower() .. "-" .. realm:gsub("[%s%-]", ""):lower()
end
function H.hash3(text)
    if not S.str(text, 330) then return nil end
    local value = 5381
    for i=1,#text do value = (value*33 + text:byte(i)) % 4294967296 end
    local out = ""
    for _=1,3 do
        local digit = value % 62
        out = out .. alphabet:sub(digit+1,digit+1)
        value = math.floor(value/62)
    end
    return out
end
function H.player(name,realm) return H.hash3(H.nameKey(name,realm)) end
