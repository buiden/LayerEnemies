-- Run: lua test/codec_fuzz.lua. Seeded, bounded, offline Lua 5.1 fuzz.
local N={Safe={secret=function(v) return v=="SECRET" end}}
-- Reject global reads beyond the Lua 5.1 allowlist and every global write.
local env={math=math,string=string,table=table,type=type,getmetatable=getmetatable,
    setmetatable=setmetatable,pcall=pcall,error=error,next=next,tonumber=tonumber}
setmetatable(env,{__index=function(_,k) error("unexpected global "..k) end,
    __newindex=function(_,k) error("global write "..k) end})
local loader=assert(loadfile((os.getenv("CODEC_ROOT") or ".").."/LayerEnemies/Codec.lua"));setfenv(loader,env);loader("LayerEnemies",N)
local C=N.Codec
local seed=981723
local function rand(n) seed=(seed*16807)%2147483647;return seed%n end
local function randomBytes()
    local t={}; for i=1,rand(129) do t[i]=string.char(rand(256)) end
    return table.concat(t)
end
local function checkTable(root)
    local count,total=0,0
    local active={}
    local function visit(v,depth)
        count=count+1;assert(count<=4097)
        if type(v)=="string" then total=total+#v;assert(total<=262144)
        elseif type(v)=="table" then
            assert(depth<8 and not active[v] and getmetatable(v)==nil)
            active[v]=true;local size=0
            for k,x in pairs(v) do size=size+1;assert(size<=2048);visit(k,depth+1);visit(x,depth+1) end
            active[v]=nil
        elseif type(v)=="number" then assert(v==v and v~=math.huge and v~=-math.huge)
        else assert(type(v)=="boolean") end
    end
    visit(root,0)
end
local state={now=0}
local functions={"inflate","deflateStored","addonDecode","addonEncode","aceRead","aceWrite","lsRead","lsWrite","aceCommJoin","aceCommSplit"}
local calls=0
local start=os.clock()
for _,name in ipairs(functions) do
    for i=1,5000 do
        local input=randomBytes()
        if name=="aceRead" and i%2==0 then input="^1^T"..input.."^t^^" end
        if name=="lsRead" and i%2==0 then input="\001"..input end
        if name=="aceWrite" or name=="lsWrite" then
            if i%3~=0 then input={data=input,n=rand(200000)-100000,nested={rand(2)==1,randomBytes()}} end
            if i%100==0 then input={};input.self=input end
        end
        local tripped=false
        debug.sethook(function() tripped=true;error("instruction budget") end,"",200000)
        local ok,out
        if name=="aceCommJoin" then
            state.now=i/100
            ok,out=pcall(C[name],state,tostring(rand(20)),input)
        else ok,out=pcall(C[name],input) end
        debug.sethook()
        assert(ok and not tripped,name.." error or instruction limit at "..i)
        if out~=nil then
            if name=="aceRead" or name=="lsRead" then checkTable(out)
            elseif name=="aceCommSplit" then
                assert(#out<=130)
                local st={now=0};local joined
                for _,part in ipairs(out) do assert(#part<=255);joined=C.aceCommJoin(st,"fuzz",part) end
                assert(joined==input)
            else assert(type(out)=="string" and #out<=262169) end
        end
        calls=calls+1
    end
    print("FUZZ "..name..": 5000 inputs, no errors, no instruction/output/depth/count overruns")
end
-- Every public boundary also rejects secrets and hostile objects without invoking metamethods.
local hostile=setmetatable({},{__index=function() error("foreign metatable") end,__tostring=function() error("foreign tostring") end})
for _,name in ipairs(functions) do
    if name~="aceCommJoin" then
        assert(C[name]("SECRET")==nil);assert(C[name](hostile)==nil)
        assert(C[name]()==nil);assert(C[name](false)==nil);assert(C[name](123)==nil)
    end
end
assert(C.aceCommJoin(hostile,"a","x")==nil)
assert(C.aceCommJoin({now=1},"SECRET","x")==nil)
assert(C.aceCommJoin({now=1},"x","SECRET")==nil)
print(string.format("FUZZ TOTAL: %d inputs, %.3f CPU seconds",calls,os.clock()-start))
