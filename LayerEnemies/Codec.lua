-- Independent wire codecs. Format credits/pins: THIRD_PARTY.md. No library code.
-- Pure Lua 5.1; no registration, globals, timers, network or direct client calls.
-- Serializer API: one root table, depth <=8, <=2048 entries/table and <=4097
-- logical values including the root (up to 4096 keys/values); finite numbers only.
local _, N = ...
local Cd, S = {}, N.Safe
N.Codec = Cd
local floor, char, byte, sub, concat = math.floor, string.char, string.byte, string.sub, table.concat
-- The root itself needs one slot in addition to 2048 key/value pairs.
local MAX_BYTES, MAX_DEPTH, MAX_VALUES, MAX_ENTRIES = 262144, 8, 4097, 2048
local function fail() error("invalid codec input",0) end
local function hidden(v) return S and S.secret(v) end
local function finite(v)
    return not hidden(v) and type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function plain(v) return not hidden(v) and type(v)=="table" and getmetatable(v)==nil end
local function bytes(v,limit)
    if hidden(v) or type(v)~="string" or #v>(limit or MAX_BYTES) then fail() end
    return v
end
local function safe(fn,...)
    local ok,value=pcall(fn,...)
    if ok then return value end
end
local function writer(limit)
    local parts,size={},0
    return function(s)
        size=size+#s
        if size>(limit or MAX_BYTES) then fail() end
        parts[#parts+1]=s
    end, function() return concat(parts) end
end

function Cd.addonEncode(input)
    return safe(function()
        bytes(input)
        local size=#input
        local out=input:gsub("[%z\001]",function(c)
            size=size+1
            if size>MAX_BYTES then fail() end
            return c=="\000" and "\001\002" or "\001\003"
        end)
        return out
    end)
end
function Cd.addonDecode(input)
    return safe(function()
        bytes(input)
        if input:find("%z") then fail() end
        local out={}; local pos=1
        while pos<=#input do
            local at=input:find("\001",pos,true)
            if not at then out[#out+1]=sub(input,pos); break end
            out[#out+1]=sub(input,pos,at-1)
            local suffix=byte(input,at+1)
            if suffix~=2 and suffix~=3 then fail() end
            out[#out+1]=char(suffix-2); pos=at+2
        end
        return concat(out)
    end)
end

-- RFC 1951. Work tokens charge bits, output bytes, tree entries and 1024/block.
-- The block charge also bounds streams made entirely of empty blocks.
local MAX_DEFLATE, MAX_WORK = MAX_BYTES+25, 4194304
local powers={}; for i=0,24 do powers[i]=2^i end
local function huffman(lengths,count,allowEmpty,complete)
    local counts,maximum={},0
    for i=0,count-1 do
        local n=lengths[i]
        if not n or n<0 or n>15 then fail() end
        if n>0 then counts[n]=(counts[n] or 0)+1; maximum=math.max(maximum,n) end
    end
    if maximum==0 then if allowEmpty then return {max=0} else fail() end end
    local left=1
    for bits=1,15 do
        left=left*2-(counts[bits] or 0)
        if left<0 then fail() end -- oversubscribed
    end
    if left>0 and (complete or maximum~=1) then fail() end
    local tree,nextCode={max=maximum},{}
    local code=0
    for bits=1,maximum do
        code=(code+(counts[bits-1] or 0))*2
        nextCode[bits]=code; tree[bits]={}
    end
    for symbol=0,count-1 do
        local n=lengths[symbol]
        if n>0 then
            code=nextCode[n]; tree[n][code]=symbol; nextCode[n]=code+1
        end
    end
    return tree
end
local fixedLit,fixedDist
 do
    local ll,dd={},{}
    for i=0,287 do ll[i]=i<144 and 8 or i<256 and 9 or i<280 and 7 or 8 end
    for i=0,31 do dd[i]=5 end
    fixedLit=huffman(ll,288); fixedDist=huffman(dd,32)
end
local lengthBase={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local lengthExtra={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local distanceBase={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local distanceExtra={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local codeOrder={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
local function inflate(input,maxOut)
    bytes(input,MAX_DEFLATE)
    if maxOut==nil then maxOut=MAX_BYTES end
    if not finite(maxOut) or maxOut<0 or maxOut>MAX_BYTES or maxOut~=floor(maxOut) then fail() end
    local pos,buffer,nbits,work=1,0,0,0
    local function charge(n)
        work=work+n
        if work>MAX_WORK then fail() end
    end
    local function take(n)
        charge(n+1)
        while nbits<n do
            local b=byte(input,pos); if not b then fail() end
            buffer=buffer+b*powers[nbits]; nbits=nbits+8; pos=pos+1
        end
        local value=buffer%powers[n]
        buffer=floor(buffer/powers[n]); nbits=nbits-n
        return value
    end
    local function symbol(tree)
        local code=0
        for bits=1,tree.max do
            code=code*2+take(1)
            local value=tree[bits][code]
            if value~=nil then return value end
        end
        fail()
    end
    local function dynamic()
        local nl,nd,nc=take(5)+257,take(5)+1,take(4)+4
        if nl>286 then fail() end
        local lengths={}; for i=0,18 do lengths[i]=0 end
        for i=1,nc do lengths[codeOrder[i]]=take(3) end
        local ct=huffman(lengths,19,false,true)
        local all,index={},0
        while index<nl+nd do
            local v=symbol(ct)
            if v<=15 then all[index]=v; index=index+1
            else
                local repeatValue,count=0,0
                if v==16 then
                    if index==0 then fail() end
                    repeatValue=all[index-1]; count=take(2)+3
                elseif v==17 then count=take(3)+3
                else count=take(7)+11 end
                if index+count>nl+nd then fail() end
                for _=1,count do all[index]=repeatValue; index=index+1 end
            end
        end
        charge((nl+nd)*2+19)
        if all[256]==0 then fail() end -- end-of-block is mandatory
        local dist={}; for i=0,nd-1 do dist[i]=all[nl+i] end
        return huffman(all,nl),huffman(dist,nd,true)
    end
    local out,size={},0
    local function reserve(n)
        if size+n>maxOut then fail() end
        charge(n)
    end
    local final
    repeat
        charge(1024)
        final=take(1)
        local kind=take(2)
        if kind==0 then
            buffer=0; nbits=0 -- discard padding to the next byte
            local len,nlen=take(16),take(16)
            if len+nlen~=65535 or pos+len-1>#input then fail() end
            reserve(len)
            for i=pos,pos+len-1 do size=size+1; out[size]=sub(input,i,i) end
            pos=pos+len
        elseif kind==1 or kind==2 then
            local lit,dist=fixedLit,fixedDist
            if kind==2 then lit,dist=dynamic() end
            while true do
                local v=symbol(lit)
                if v<256 then
                    reserve(1); size=size+1; out[size]=char(v)
                elseif v==256 then break
                else
                    if v>285 then fail() end
                    local li=v-256
                    local len=lengthBase[li]+take(lengthExtra[li])
                    local di=symbol(dist)+1
                    if di>30 then fail() end
                    local offset=distanceBase[di]+take(distanceExtra[di])
                    if offset>size or offset>32768 then fail() end
                    reserve(len)
                    for _=1,len do size=size+1; out[size]=out[size-offset] end
                end
            end
        else fail() end
    until final==1
    if pos~=#input+1 then fail() end -- no concatenated stream/trailing bytes
    return concat(out)
end
-- inflate(input, maxOut): pass a SMALL maxOut, the largest legitimate decoded
-- payload for that network. The default/hard cap of 262144 is not a frame budget.
-- Reviewer offline worst cases: 240000 7-bit-random bytes took 397 ms; 262144
-- text-like bytes 253 ms; 120000 text-like bytes 95 ms. A bomb with maxOut=4096
-- was refused in 0.3 ms. These are measured CPU costs, not in-game timings.
function Cd.inflate(input,maxOut) return safe(inflate,input,maxOut) end
function Cd.deflateStored(input)
    return safe(function()
        bytes(input)
        local put,finish=writer(MAX_DEFLATE)
        local at=1
        repeat
            local n=math.min(65535,#input-at+1)
            local last=at+n>#input
            local complement=65535-n
            put(char(last and 1 or 0,n%256,floor(n/256),complement%256,floor(complement/256)))
            put(sub(input,at,at+n-1)); at=at+n
        until last
        return finish()
    end)
end

-- Validate the logical graph as well as the wire: references cannot evade depth,
-- value or expanded-string ceilings. Cycles/metatables are not network data.
local function graph(root)
    if not plain(root) then fail() end
    local active,values,stringBytes={},0,0
    local function visit(v,depth)
        if hidden(v) then fail() end
        values=values+1
        if values>MAX_VALUES then fail() end
        local typ=type(v)
        if typ=="table" then
            if not plain(v) or active[v] or depth>=MAX_DEPTH then fail() end
            active[v]=true
            local count=0
            for k,value in next,v do
                count=count+1
                if count>MAX_ENTRIES then fail() end
                visit(k,depth+1); visit(value,depth+1)
            end
            active[v]=nil
        elseif typ=="string" then
            stringBytes=stringBytes+#v
            if stringBytes>MAX_BYTES then fail() end
        elseif typ=="number" then
            if not finite(v) then fail() end
        elseif typ~="boolean" and typ~="nil" then fail() end
    end
    visit(root,0)
    return root
end
local function decimal(s)
    if #s==0 or #s>64 or not s:match("^[%d+%.eE%-]+$") then fail() end
    local n=tonumber(s)
    if not finite(n) then fail() end
    return n
end
local function aceEscape(s)
    return (s:gsub("[%z\001-\032\094\126\127]",function(c)
        local b=byte(c)
        if b==30 then return "~z" end
        if b<=32 then return "~"..char(b+64) end
        return b==94 and "~}" or b==126 and "~|" or "~{"
    end))
end
local function aceUnescape(s)
    local out={}; local at=1
    while at<=#s do
        local pos=s:find("~",at,true)
        if not pos then out[#out+1]=sub(s,at); break end
        out[#out+1]=sub(s,at,pos-1)
        local b=byte(s,pos+1)
        if not b then fail() end
        if b>=64 and b<=96 and b~=94 then out[#out+1]=char(b-64)
        elseif b==122 then out[#out+1]=char(30)
        elseif b==123 then out[#out+1]=char(127)
        elseif b==124 then out[#out+1]="~"
        elseif b==125 then out[#out+1]="^"
        else fail() end
        at=pos+2
    end
    return concat(out)
end
local function aceRead(input)
    bytes(input)
    input=input:gsub("[%c ]","") -- AceSerializer permits formatting whitespace
    if sub(input,1,2)~="^1" then fail() end
    local at,values=3,0
    local function token()
        if sub(input,at,at)~="^" or at>=#input then fail() end
        local tag=sub(input,at+1,at+1)
        local ending=input:find("^",at+2,true) or (#input+1)
        local value=sub(input,at+2,ending-1); at=ending
        return tag,value
    end
    local read
    read=function(depth)
        values=values+1
        if values>MAX_VALUES then fail() end
        local tag,data=token()
        if tag=="S" then return aceUnescape(data) end
        if tag=="N" then return decimal(data) end
        if tag=="F" then
            local m=decimal(data)
            local nextTag,exp=token()
            if nextTag~="f" then fail() end
            local e=decimal(exp)
            if e~=floor(e) or e< -1126 or e>1024 or m~=floor(m) or math.abs(m)>9007199254740991 then fail() end
            local n=math.ldexp(m,e)
            if not finite(n) then fail() end
            return n
        end
        if data~="" then fail() end
        if tag=="B" then return true end
        if tag=="b" then return false end
        if tag=="Z" then return nil end
        if tag~="T" or depth>=MAX_DEPTH then fail() end
        local t,seen,count={},{},0
        while sub(input,at,at+1)~="^t" do
            count=count+1
            if count>MAX_ENTRIES then fail() end
            local k=read(depth+1); local v=read(depth+1)
            if k==nil or v==nil or seen[k] then fail() end
            seen[k]=true; t[k]=v
        end
        local _,tail=token()
        if tail~="" then fail() end
        return t
    end
    local root=read(0)
    if sub(input,at)~="^^" then fail() end
    return graph(root)
end
function Cd.aceRead(input) return safe(aceRead,input) end
function Cd.aceWrite(root)
    return safe(function()
        graph(root)
        local put,finish=writer()
        local function emit(v)
            local typ=type(v)
            if typ=="table" then
                put("^T")
                for k,value in next,v do emit(k); emit(value) end
                put("^t")
            elseif typ=="string" then put("^S"); put(aceEscape(v))
            elseif typ=="number" then put("^N"); put(string.format("%.17g",v))
            elseif typ=="boolean" then put(v and "^B" or "^b")
            else put("^Z") end
        end
        put("^1"); emit(root); put("^^")
        return finish()
    end)
end

-- LibSerialize v1/v2 wire layout; big-endian integers and IEEE binary64.
local function lsRead(input)
    bytes(input)
    local version=byte(input,1)
    if version~=1 and version~=2 then fail() end
    local at,values=2,0
    local strings,tables={},{}
    local function uint(n)
        if at+n-1>#input then fail() end
        local v=0
        for _=1,n do
            local b=byte(input,at); at=at+1; v=v*256+b
            if v%256~=b then fail() end -- reject unrepresentable 56-bit integers
        end
        return v
    end
    local function chunk(n)
        if n>MAX_BYTES or at+n-1>#input then fail() end
        local s=sub(input,at,at+n-1); at=at+n
        return s
    end
    local function str(n)
        local s=chunk(n)
        if n>2 then strings[#strings+1]=s end
        return s
    end
    local read
    local function tab(arrayCount,mapCount,depth)
        if depth>=MAX_DEPTH or arrayCount+mapCount>MAX_ENTRIES then fail() end
        if values+arrayCount+mapCount*2>MAX_VALUES then fail() end
        local t,seen={},{}
        tables[#tables+1]=t
        for i=1,arrayCount do t[i]=read(depth+1); seen[i]=true end
        for _=1,mapCount do
            local k=read(depth+1); local v=read(depth+1)
            if k==nil or v==nil or seen[k] then fail() end
            seen[k]=true; t[k]=v
        end
        return t
    end
    read=function(depth)
        values=values+1
        if values>MAX_VALUES then fail() end
        local b=uint(1)
        if b%2==1 then return floor(b/2) end
        if b%4==2 then
            local typ,count=floor(b/4)%4,floor(b/16)
            if typ==0 then return str(count) end
            if typ==1 then return tab(0,count,depth) end
            if typ==2 then return tab(count,0,depth) end
            return tab(count%4+1,floor(count/4)+1,depth)
        end
        if b%8==4 then
            local n=floor(b/16)+uint(1)*16
            return b%16==12 and -n or n
        end
        local tag=b/8
        if tag==0 then return nil end
        if tag<=8 then
            local width=math.ceil(tag/2)+1
            if width==5 then width=7 end
            local n=uint(width)
            return tag%2==0 and -n or n
        end
        if tag==9 then
            local hi,lo=uint(4),uint(4)
            local exponent=floor(hi/1048576)%2048
            local mantissa=(hi%1048576)*4294967296+lo
            if exponent==2047 then fail() end
            local n
            if exponent==0 then n=math.ldexp(mantissa,-1074)
            else n=math.ldexp(1+mantissa/4503599627370496,exponent-1023) end
            return hi>=2147483648 and -n or n
        end
        if tag==10 or tag==11 then
            local n=decimal(chunk(uint(1)))
            if n<0 then fail() end
            return tag==11 and -n or n
        end
        if tag==12 then return true end
        if tag==13 then return false end
        local family=floor((tag-14)/3)
        local n=uint((tag-14)%3+1)
        if family==0 then return str(n) end
        if family==1 then return tab(0,n,depth) end
        if family==2 then return tab(n,0,depth) end
        if family==3 then return tab(n,uint((tag-14)%3+1),depth) end
        local value
        if family==4 then value=strings[n] else value=tables[n] end
        if value==nil then fail() end
        return value
    end
    local root=read(0)
    if at~=#input+1 then fail() end
    return graph(root)
end
function Cd.lsRead(input) return safe(lsRead,input) end
function Cd.lsWrite(root)
    return safe(function()
        graph(root)
        local put,finish=writer()
        local strings,tables,ns,nt={},{},0,0
        local function uint(n,width)
            local t={}
            for i=width,1,-1 do t[i]=char(n%256); n=floor(n/256) end
            put(concat(t))
        end
        local function sized(tag,n)
            local width=n<256 and 1 or n<65536 and 2 or 3
            put(char((tag+width-1)*8)); uint(n,width)
        end
        local emit
        emit=function(v)
            local typ=type(v)
            if typ=="table" then
                if tables[v] then sized(29,tables[v]); return end
                nt=nt+1; tables[v]=nt
                local count=0; for _ in next,v do count=count+1 end
                if count<16 then put(char(count*16+6)) else sized(17,count) end
                for k,value in next,v do emit(k); emit(value) end
            elseif typ=="string" then
                if strings[v] then sized(26,strings[v]); return end
                if #v<16 then put(char(#v*16+2)) else sized(14,#v) end
                put(v)
                if #v>2 then ns=ns+1; strings[v]=ns end
            elseif typ=="boolean" then put(char(v and 96 or 104))
            elseif typ=="nil" then put(char(0))
            else
                local n=math.abs(v)
                if n==floor(n) and n<=9007199254740991 then
                    if v>=0 and n<128 then put(char(n*2+1))
                    elseif n<4096 then put(char(n%16*16+(v<0 and 12 or 4),floor(n/16)))
                    else
                        local width,tag=2,1
                        if n>=4294967296 then width,tag=7,7
                        elseif n>=16777216 then width,tag=4,5
                        elseif n>=65536 then width,tag=3,3 end
                        put(char((tag+(v<0 and 1 or 0))*8)); uint(n,width)
                    end
                else
                    -- Decimal form avoids platform packing APIs and preserves finite doubles.
                    local s=string.format("%.17g",n)
                    put(char(v<0 and 88 or 80,#s)); put(s)
                end
            end
        end
        put(char(1)); emit(root)
        return finish()
    end)
end

-- aceCommJoin(st, key, text): caller owns st and updates st.now (monotonic seconds)
-- before every join. Key distinguishes full sender, distribution and prefix.
-- No normalization. Returns the complete bytes, or nil for pending/refused input.
-- Per stream: expire at >=15 s idle since the last accepted fragment OR >=120 s
-- from the first. Only accepted first/continuation fragments refresh idle time;
-- a new first replaces that stream. Expiry is pruned on calls, not by a timer.
-- Caps: 16 streams/state, 32768 assembled bytes, 256 frames, <=255 bytes/frame.
-- ChatThrottleLib pacing (MAX_CPS=800, BURST=4000, 40 bytes overhead/message)
-- gives ~689 payload bytes/s with full frames (254 payload + 1 control + 40).
-- Ideal idle/full-burst sender: ~24.1 KB in 30 s; 32768 bytes takes ~42.6 s,
-- within the new total cap. Shared traffic/client throttling can reduce this:
-- one frame/s carries 20000 bytes in 79 frames (+78 s), but at most 30480 bytes
-- before 120 s. The 32768-byte cap is admission, not guaranteed delivery.
-- Private weak-key storage prevents foreign tables from forging stream counts.
local assemblies=setmetatable({},{__mode="k"})
local function aceCommJoin(st,key,text)
    if not plain(st) or not finite(st.now) or st.now<0 then fail() end
    bytes(key,256); if #key==0 then fail() end
    bytes(text,255)
    local now=st.now
    local state=assemblies[st]
    if not state or now<state.now then
        state={now=now,streams={}}; assemblies[st]=state
    end
    state.now=now
    local streams,count=state.streams,0
    for k,stream in next,streams do
        if now-stream.last>=15 or now-stream.at>=120 then streams[k]=nil else count=count+1 end
    end
    local control=byte(text,1) or 0
    if control<1 or control>9 then return text end
    if #text==1 or control>=5 then streams[key]=nil; return nil end
    if control==4 then return sub(text,2) end
    local part=sub(text,2)
    if control==1 then
        if not streams[key] and count>=16 then return nil end
        streams[key]={at=now,last=now,parts={part},size=#part,count=1}
        return nil
    end
    local stream=streams[key]
    if not stream then return nil end
    if stream.size+#part>32768 or stream.count>=256 then streams[key]=nil; return nil end
    stream.size=stream.size+#part; stream.count=stream.count+1
    stream.parts[stream.count]=part; stream.last=now
    if control==3 then
        streams[key]=nil
        return concat(stream.parts)
    end
end
function Cd.aceCommJoin(st,key,text) return safe(aceCommJoin,st,key,text) end
function Cd.aceCommSplit(input)
    return safe(function()
        bytes(input,32768)
        local first=byte(input,1) or 0
        local escape=first>=1 and first<=9
        if #input+(escape and 1 or 0)<=255 then return {escape and "\004"..input or input} end
        local frames,at={},1
        while at<=#input do
            local last=at+254>#input
            local control=at==1 and 1 or last and 3 or 2
            frames[#frames+1]=char(control)..sub(input,at,at+253)
            at=at+254
        end
        return frames
    end)
end
