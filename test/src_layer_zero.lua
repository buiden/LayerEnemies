-- Zero/unknown inputs across independent namespaces, own and received.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local zeros={0,"0","0-0","0-0-0"}
local function payload(N,t)
    return assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite(t))))))
end
local function record(layer)
    local r={kind="kill",id="Witness Player:1000001",origin="Witness Player",seq=1000001,prev="0",t=GetServerTime()-3,
        data={victimName="Enemy One",victim="Player-1-AB",victimFaction="Horde",mapId=100,x=50,y=40,l=layer}}
    local keys={}; for k in pairs(r.data) do keys[#keys+1]=k end; table.sort(keys)
    local s=r.kind.."\n"..r.id.."\n"..r.prev.."\n"..r.t
    for _,k in ipairs(keys) do s=s.."\n"..k.."="..tostring(r.data[k]) end
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    r.hash=string.format("%08x",b*65536+a); return r
end
local function wanted(N,r)
    local b=payload(N,{v="1.29.2",r={r}}); local total=math.ceil(#b/240)
    for i=1,total do H.deliver("CHAT_MSG_ADDON","WNTD","R:a:"..i.."/"..total..":"..b:sub((i-1)*240+1,i*240),"GUILD","Witness Player") end
end
for i,z in ipairs(zeros) do
    local label=type(z).." "..tostring(z)
    test("Layer A2: key and Bulo own/received zero "..label,function()
        local N=H.load()
        eq(N.Layer.key(z),nil); eq(N.Layer.bulo(z),nil); no(N.Layer.same(z,z))
        BuloLayerForever={current=z,Radar={seen={}}}; N.Main.poll(); eq(N.Main.store.bulo,nil)
        eq(N.Layer.key("7086-0"),"7086","nonzero server survives a zero UID")
    end)
    test("Layer A2: FLH own/received zero "..label,function()
        local N=H.load(); H.establish(N); N.Main.store.zoneUID=z
        eq(N.FLHMember.context(),nil); eq(N.FLH.key(z),nil)
        local r=N.FLH.decode("HI|100|"..tostring(z).."|1|0.1.9|1234")
        no(r and N.FLH.key(r.key),"no usable host fingerprint")
    end)
    test("Layer A2: ChehulNet own/received zero "..label,function()
        local N=H.load(); local Ch=N.ChehulNet; local st=Ch.new("Me")
        yes(Ch.note(st,"Ally One",{map=100,zone=7},"GUILD",100))
        eq(Ch.view(st,100,z,100)[1].rel,nil)
        yes(Ch.note(st,"Ally Two",{map=100,zone=z},"GUILD",100))
        local rows=Ch.view(st,100,7,100); eq(rows[2].zone,nil); eq(rows[2].rel,nil)
        eq(Ch.parse("CHN1|H|v15|MAGE|60|0|100:"..tostring(z)).zone,nil)
    end)
    test("Layer A2: Wanted received zero retains named record "..label,function()
        local N=H.load(); yes(N.Find.add(N.Main.find,"Enemy One"))
        local offered; local real=N.Sources.offer
        N.Sources.offer=function(e) offered=e; return real(e) end
        wanted(N,record(z)); yes(offered,"named record retained"); eq(offered.shard,nil)
        yes(N.Known.get(N.Main.find.known,"Enemy One",H.clock()))
    end)
    test("Layer A2: Wanted bridge identity zero is dropped "..label,function()
        local N=H.load(); N.BNet.who=function() return {name="Enemy One",realm="Test Realm",faction="Horde"} end
        H.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z={{m=100,l=z,n=2}}}),"WHISPER",71)
        eq(N.Wanted.state.far[71],nil)
    end)
    test("Layer A2: Overlord received zero is unknown "..label,function()
        local N=H.load(); local r=N.Overlord.gw("1:Enemy Guild:H:50:5:#100:"..tostring(z)..":1000",1000)
        yes(r,"guild/counts retained"); eq(r.layer,nil); eq(r.guild,"Enemy Guild"); eq(r.kills,50)
    end)
end

test("Layer A2: NPC zero server cannot establish an own key",function()
    local N=H.load(); local t=N.Layer.new()
    for i=1,2 do N.Layer.observe(t,"Creature-0-0-0-7-"..i.."-ABC",100+i) end
    eq(t.current,nil); eq(N.Layer.server(t),nil)
end)

-- The same constructed record helpers cover separable malformed-layer fields.
test("Layer A3: Wanted bad layer preserves names and position, other bad fields still drop",function()
    local N=H.load(); yes(N.Find.add(N.Main.find,"Enemy One"))
    local offered; local real=N.Sources.offer
    N.Sources.offer=function(e) offered=e; return real(e) end
    wanted(N,record("bad-layer")); yes(offered); eq(offered.name,"Enemy One"); eq(offered.map,100)
    eq(offered.x,.5); eq(offered.y,.4); eq(offered.shard,nil)
    N=H.load(); local bad=record("bad-layer"); bad.hash="00000000"
    local count=0; N.Sources.offer=function() count=count+1 end
    wanted(N,bad); eq(count,0,"bad checksum still drops the whole record")
end)
