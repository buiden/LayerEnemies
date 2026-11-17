-- Run: /opt/data/tools/lua/lua-5.1.5/src/lua test/codec.lua
-- Independent tests; no donor code or libraries are executed.
local h=... -- optional shared harness; standalone codec gate remains supported
local N={Safe={secret=function() return false end}}
local loader=loadfile((os.getenv("CODEC_ROOT") or ".").."/LayerEnemies/Codec.lua")
if loader then loader("LayerEnemies",N) end
local C=N.Codec or {}
local passed,failed,checks=0,0,0
local function eq(a,b,label)
    if h then return h.eq(a,b,label) end
    checks=checks+1
    if a~=b then error(label or ("expected "..tostring(b)..", got "..tostring(a)),2) end
end
local function yes(v,label) eq(not not v,true,label) end
local function test(name,fn)
    if h then return h.test("Codec: "..name,fn) end
    local ok,err=pcall(fn)
    if ok then passed=passed+1 else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local function hex(s) return (s:gsub("..",function(b) return string.char(tonumber(b,16)) end)) end
local function allbytes() local t={}; for i=0,255 do t[#t+1]=string.char(i) end; return table.concat(t) end

test("addon escaping exact bytes and roundtrip",function()
    yes(type(C.addonEncode)=="function","missing addon codec")
    eq(C.addonEncode("\000\001\002\255"),"\001\002\001\003\002\255")
    eq(C.addonDecode(C.addonEncode(allbytes())),allbytes())
    eq(C.addonDecode(""),"")
    eq(C.addonEncode(""),"")
end)
test("addon malformed escapes and byte ceilings",function()
    for _,s in ipairs({"\000","\001","\001\001","\001\004","x\001"}) do eq(C.addonDecode(s),nil) end
    eq(C.addonDecode(string.rep("x",262145)),nil)
    eq(C.addonEncode(string.rep("x",262145)),nil)
    eq(C.addonEncode(string.rep("\000",131073)),nil)
    eq(#C.addonEncode(string.rep("\000",131072)),262144)
    eq(C.addonDecode({}),nil)
end)

test("inflate zlib known answers and stored writer",function()
    yes(type(C.inflate)=="function","missing inflate")
    local V=dofile("test/fixtures/codec_vectors.lua")
    for _,v in ipairs(V.deflate) do
        eq(C.inflate(v.wire),v.plain,v.name)
        eq(C.inflate(v.wire,#v.plain),v.plain,v.name.." exact limit")
        if #v.plain>0 then eq(C.inflate(v.wire,#v.plain-1),nil,v.name.." output limit") end
        eq(C.inflate(C.deflateStored(v.plain)),v.plain,"stored "..v.name)
        for i=0,#v.wire-1 do
            if i<20 or i>#v.wire-12 then eq(C.inflate(v.wire:sub(1,i)),nil,"truncated "..v.name) end
        end
    end
    eq(C.inflate(V.fixed.wire),V.fixed.plain,"fixed")
    eq(C.inflate(V.bomb),nil,"bomb")
    eq(C.inflate(V.bomb,4000),nil,"small bomb")
    eq(C.deflateStored(""),hex("010000ffff"))
    eq(C.deflateStored("abc"),hex("010300fcff616263"))
    eq(C.inflate(C.deflateStored(string.rep("a",262144))),string.rep("a",262144))
end)
test("inflate malformed blocks, distance and work budget",function()
    for _,s in ipairs({hex("07"),hex("010100ffff41"),hex("0302"),hex("fdf8ff"),hex("0300").."garbage"}) do eq(C.inflate(s),nil) end
    eq(C.inflate(string.rep("x",262170)),nil,"compressed input bound")
    eq(C.inflate(hex("000000ffff")..C.deflateStored(string.rep("x",262144))),nil,"valid stream above input cap")
    eq(C.deflateStored(string.rep("x",262145)),nil,"stored input bound")
    for _,limit in ipairs({-1,0.5,262145,math.huge,"10",{}}) do eq(C.inflate(hex("0300"),limit),nil) end
    eq(C.inflate(hex("0300"),0),"")
    eq(C.inflate(string.rep(hex("000000ffff"),5000)..hex("010000ffff")),nil,"block work budget")
end)

local function nesting(n)
    local t={}; local root=t
    for _=2,n do t.child={}; t=t.child end
    return root
end
test("AceSerializer hand answers and full-byte strings",function()
    yes(type(C.aceRead)=="function","missing AceSerializer")
    local t=C.aceRead("^1^T^Sk^SH^Sv^N5^Syes^B^Sno^b^t^^")
    eq(t.k,"H"); eq(t.v,5); eq(t.yes,true); eq(t.no,false)
    eq(C.aceRead("^1^T^Sx^F4503599627370496^f-52^t^^").x,1)
    eq(C.aceRead(" \n^1\t^T^Sx^N2^t^^\r").x,2)
    eq(C.aceWrite({}),"^1^T^t^^")
    eq(C.aceWrite({x="\000\030 ^~\127"}),"^1^T^Sx^S~@~z~`~}~|~{^t^^")
    local raw={data=allbytes(),number=1/3,nested={false,true},negative=-1.25,big=1e100}
    local copy=C.aceRead(C.aceWrite(raw))
    eq(copy.data,raw.data); eq(copy.number,raw.number); eq(copy.nested[1],false); eq(copy.negative,-1.25); eq(copy.big,1e100)
    yes(C.aceRead(C.aceWrite(nesting(8))))
end)
test("AceSerializer strict malformed and resource rejection",function()
    for _,s in ipairs({"", "^2^T^t^^", "^1^T^t", "^1^T^Sx^t^^", "^1^T^Z^B^t^^", "^1^T^Sx^Z^t^^",
        "^1^T^Sx^Nnan^t^^", "^1^T^Sx^N1e999^t^^", "^1^T^Sx^S~^t^^", "^1^T^Sx^S~a^t^^",
        "^1^T^Sx^Bjunk^t^^", "^1^T^Sx^N1^Sx^N2^t^^", "^1^T^t^^x", "^1^T^t^T^t^^", "^1^N1^^"}) do eq(C.aceRead(s),nil,s) end
    eq(C.aceWrite(nesting(9)),nil,"write depth")
    eq(C.aceRead("^1"..string.rep("^T^Sk",8).."^T^t"..string.rep("^t",8).."^^"),nil,"read depth")
    local t={}; for i=1,2048 do t[i]=i end
    eq(C.aceWrite(t),nil,"4097 logical values")
    eq(C.aceRead("^1^T"..string.rep("^B^B",2048).."^t^^"),nil)
    eq(C.aceWrite({s=string.rep("x",262144)}),nil,"output cap")
    eq(C.aceRead(string.rep("x",262145)),nil,"input cap")
    t={};t.self=t; eq(C.aceWrite(t),nil,"cycles")
    eq(C.aceWrite({f=function() end}),nil,"functions")
    eq(C.aceWrite(setmetatable({},{__index=function() error("no") end})),nil,"metatable")
end)

test("LibSerialize hand answers and table/string references",function()
    yes(type(C.lsRead)=="function","missing LibSerialize")
    local t=C.lsRead(hex("0136126b1248127662312e32392e32126603"))
    eq(t.k,"H");eq(t.v,"1.29.2");eq(t.f,1)
    eq(C.lsRead(hex("0236126b1248127662312e32392e32126603")).k,"H")
    eq(C.lsWrite({}),hex("0106"))
    t=C.lsRead(hex("013a32616263d001d001"));eq(t[1],"abc");eq(t[2],"abc");eq(t[3],"abc")
    t=C.lsRead(hex("012a0ae802")); eq(t[1],t[2]);yes(type(t[1])=="table")
    local shared={v="long repeated string"}
    t=C.lsRead(C.lsWrite({a=shared,b=shared,c=allbytes(),n=-1/3}))
    eq(t.a,t.b);eq(t.c,allbytes());eq(t.n,-1/3)
    t=C.lsRead(hex("010e03126b60")); eq(t[1],1);eq(t.k,true) -- embedded mixed 1 array + 1 map
    t=C.lsRead(hex("013a000368"));eq(t[1],nil);eq(t[2],1);eq(t[3],false)
    yes(C.lsRead(C.lsWrite(nesting(8))))
end)
test("LibSerialize every scalar and explicit count family",function()
    local scalars={
        {"01",0},{"ff",127},{"f4ff",4095},{"fcff",-4095},
        {"081000",4096},{"101000",-4096},{"18010000",65536},{"20010000",-65536},
        {"2801000000",16777216},{"3001000000",-16777216},
        {"3800000100000000",4294967296},{"4000000100000000",-4294967296},
        {"483ff8000000000000",1.5},{"48bff8000000000000",-1.5},
        {"5003312e35",1.5},{"5803312e35",-1.5},{"60",true},{"68",false},
        {"7003616263","abc"},{"780003616263","abc"},{"80000003616263","abc"},
        {"480000000000000001",math.ldexp(1,-1074)}
    }
    for _,v in ipairs(scalars) do
        eq(C.lsRead(hex("011a"..v[1]))[1],v[2],v[1])
        eq(C.lsRead(C.lsWrite({v[2]}))[1],v[2],"roundtrip "..v[1])
    end
    for i,v in ipairs({"8801126b03","900001126b03","98000001126b03","b8010103126b60","c00001000103126b60","c800000100000103126b60"}) do
        eq(C.lsRead(hex("01"..v)).k,i<=3 and 1 or true)
    end
    for _,v in ipairs({"a00103","a8000103","b000000103"}) do eq(C.lsRead(hex("01"..v))[1],1) end
    eq(C.lsRead(hex("012a32616263d80001"))[2],"abc")
    eq(C.lsRead(hex("012a32616263e0000001"))[2],"abc")
    local t=C.lsRead(hex("012a0af00002"));eq(t[1],t[2])
    t=C.lsRead(hex("012a0af8000002"));eq(t[1],t[2])
end)
test("LibSerialize malformed, truncated, cycles and bounds",function()
    for _,v in ipairs({"", "030a", "011a", "01ff", "010a00", "011ad000", "011ae802", "011ae801",
        "011a48fff0000000000000","011a487ff8000000000000","011a50016e", "011a80ffffff", "01a8ffff",
        "0126126b03126b05", "01160003", "0116126b00"}) do eq(C.lsRead(hex(v)),nil,v) end
    eq(C.lsRead("\001"..string.rep("\026",9).."\010"),nil,"wire depth")
    eq(C.lsWrite(nesting(9)),nil); eq(C.lsRead(string.rep("x",262145)),nil)
    eq(C.lsWrite({x=string.rep("x",262144)}),nil)
    local t={};t.self=t; eq(C.lsWrite(t),nil)
    t={};for i=1,2048 do t[i]=i end;eq(C.lsWrite(t),nil)
end)

test("AceComm split/join all controls and boundaries",function()
    yes(type(C.aceCommJoin)=="function","missing AceComm")
    for _,n in ipairs({0,1,253,254,255,256,508,509,32768}) do
        for control=0,10 do
            local raw=string.rep("x",n)
            if n>0 then raw=string.char(control)..raw:sub(2) end
            local frames=C.aceCommSplit(raw);yes(frames)
            local st={now=0}; local out
            for i,frame in ipairs(frames) do
                yes(#frame<=255);out=C.aceCommJoin(st,"WarBoard\tGUILD\tEnemy-Realm",frame)
                if i<#frames then eq(out,nil) end
            end
            eq(out,raw)
        end
    end
    eq(C.aceCommSplit("a")[1],"a")
    eq(C.aceCommSplit("\001a")[1],"\004\001a")
    local f=C.aceCommSplit(string.rep("a",256));eq(f[1],"\001"..string.rep("a",254));eq(f[2],"\003aa")
end)
test("AceComm sender isolation, restart, orphan and exact TTL",function()
    local st={now=0}
    eq(C.aceCommJoin(st,"a","\002orphan"),nil)
    eq(C.aceCommJoin(st,"a","\003orphan"),nil)
    eq(C.aceCommJoin(st,"a","\001first"),nil)
    eq(C.aceCommJoin(st,"b","\001other"),nil)
    eq(C.aceCommJoin(st,"a","\001new"),nil)
    eq(C.aceCommJoin(st,"a","single"),"single")
    st.now=29.999;eq(C.aceCommJoin(st,"a","\003end"),"newend")
    st.now=30;eq(C.aceCommJoin(st,"b","\003end"),nil,"exact ttl")
    st.now=40;C.aceCommJoin(st,"a","\001old")
    st.now=60;C.aceCommJoin(st,"a","\002middle")
    st.now=70;eq(C.aceCommJoin(st,"a","\003end"),nil,"no idle refresh")
    st.now=80;C.aceCommJoin(st,"a","\001old")
    st.now=79;eq(C.aceCommJoin(st,"a","\003end"),nil,"clock rollback")
end)
test("AceComm stream, bytes, fragment, key and frame ceilings",function()
    local st={now=0}
    for i=1,17 do C.aceCommJoin(st,tostring(i),"\001x") end
    eq(C.aceCommJoin(st,"17","\003x"),nil,"stream cap")
    for i=1,16 do eq(C.aceCommJoin(st,tostring(i),"\003x"),"xx") end
    C.aceCommJoin(st,"17","\001x");eq(C.aceCommJoin(st,"17","\003x"),"xx","released capacity")
    C.aceCommJoin(st,"a","\001"..string.rep("x",254))
    for _=1,128 do C.aceCommJoin(st,"a","\002"..string.rep("x",254)) end
    eq(C.aceCommJoin(st,"a","\003"..string.rep("x",3)),nil,"32769 bytes")
    C.aceCommJoin(st,"b","\001x")
    for _=2,256 do C.aceCommJoin(st,"b","\002x") end
    eq(C.aceCommJoin(st,"b","\003x"),nil,"257 fragments")
    for _,s in ipairs({"\001","\002","\003","\004","\005x","\009x",string.rep("x",256)}) do eq(C.aceCommJoin(st,"a",s),nil) end
    eq(C.aceCommJoin(st,string.rep("x",257),"a"),nil)
    eq(C.aceCommJoin(st,"","a"),nil)
    eq(C.aceCommJoin({},"a","x"),nil,"missing clock")
    eq(C.aceCommSplit(string.rep("x",32769)),nil)
end)

local function same(a,b)
    eq(type(a),type(b))
    if type(b)~="table" then eq(a,b);return end
    for k,v in pairs(b) do same(a[k],v) end
    for k in pairs(a) do yes(b[k]~=nil) end
end
test("independent Python serializer vectors and audit network payloads",function()
    local V=dofile("test/fixtures/codec_vectors.lua")
    for _,v in ipairs(V.serializers) do
        for _,codec in ipairs({"ace","ls"}) do
            same(C[codec.."Read"](v[codec]),v.expected)
            same(C[codec.."Read"](C[codec.."Write"](v.expected)),v.expected)
            for i=0,math.min(#v[codec]-1,200) do eq(C[codec.."Read"](v[codec]:sub(1,i)),nil,"truncated "..codec) end
        end
    end
    for _,v in ipairs(V.audit) do
        local serial=C.inflate(C.addonDecode(v.encoded))
        eq(serial,v.serial,v.name)
        same(C[v.codec.."Read"](serial),v.expected)
    end
    eq(#V.audit,11)
    local st={now=0}
    eq(C.aceCommJoin(st,"audit",hex("040102")),hex("0102"))
    eq(C.aceCommJoin(st,"audit",hex("016162")),nil)
    eq(C.aceCommJoin(st,"audit",hex("026364")),nil)
    eq(C.aceCommJoin(st,"audit",hex("036566")),"abcdef")
end)
test("logical references cannot evade string, depth or table bounds",function()
    -- Array of 2049 nils exceeds declared table-size budget despite allocating no entries.
    eq(C.lsRead(hex("01a80801")..string.rep("\000",2049)),nil)
    -- Three references to one 131072-byte string: <262144 wire bytes, >262144 logical bytes.
    eq(C.lsRead(hex("013a80020000")..string.rep("x",131072)..hex("d001d001")),nil)
    -- A prior subtree reused below a seven-table chain still exceeds logical depth 8.
    local wire=hex("012a1a0a")..string.rep(hex("1a"),6)..hex("e802")
    eq(C.lsRead(wire),nil)
    eq(C.aceWrite({x=string.rep("x",262140)}),nil,"serialized byte cap")
    eq(C.lsWrite({x=string.rep("x",262143)}),nil,"serialized byte cap")
    eq(C.lsRead(hex("011a3820000000000001")),nil,"inexact 56-bit integer")
    eq(C.lsRead(hex("011a3820000000000000"))[1],9007199254740992,"exact 56-bit integer")
    local t={};for i=1,2047 do t[i]=i end
    yes(C.aceWrite(t));yes(C.lsWrite(t))
end)

test("RFC bit-level malformed trees and degenerate valid alphabets",function()
    local V=dofile("test/fixtures/codec_vectors.lua")
    for _,v in ipairs(V.goodDeflate) do eq(C.inflate(v.wire),v.plain,v.name) end
    for _,v in ipairs(V.badDeflate) do eq(C.inflate(v.wire),nil,v.name) end
end)

test("AceComm invalid reserved frames abandon only their sender stream",function()
    for control=5,9 do
        local st={now=0}
        C.aceCommJoin(st,"a","\001start")
        C.aceCommJoin(st,"b","\001other")
        eq(C.aceCommJoin(st,"a",string.char(control).."junk"),nil)
        eq(C.aceCommJoin(st,"a","\003end"),nil)
        eq(C.aceCommJoin(st,"b","\003end"),"otherend")
    end
end)

-- CASES
if not h then
    print(string.format("CODEC: %d tests passed, %d failed, %d assertions",passed,failed,checks))
    if failed>0 then os.exit(1) end
end
