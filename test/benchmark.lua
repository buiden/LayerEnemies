local N={}
for _,file in ipairs({"Safe","Hash","Layer","Protocol","Store","Reports","Adapters"}) do
    assert(loadfile("LayerEnemies/"..file..".lua"))("LayerEnemies",N)
end
local function measure(label,iterations,fn)
    collectgarbage("collect"); collectgarbage("stop")
    local kb=collectgarbage("count"); local start=os.clock()
    for _=1,iterations do fn() end
    local elapsed=os.clock()-start; local delta=collectgarbage("count")-kb
    collectgarbage("restart"); collectgarbage("collect")
    print(string.format("%s: %d calls; %.6f ms/call; %.6f KB allocated/call (GC stopped)",label,iterations,elapsed*1000/iterations,delta/iterations))
end
local t=N.Store.new(0); t.zone=100; t.bulo="7086-7"
measure("empty-store prune",10000,function() N.Store.prune(t,200) end)
_G.BuloLayerForever={current="7086-7",Radar={seen={}}}
for i=1,256 do
    local key="Player-1-"..i
    N.Store.observe(t,{key=key,at=199,faction="opposite",source="own target"},200)
    BuloLayerForever.Radar.seen[key]={at=199,hostile=true,src="target"}
end
measure("256-entry store prune",1000,function() N.Store.prune(t,200) end)
measure("256-entry unchanged Bulo snapshot",200,function() N.Adapters.bulo(t.epoch,200,t.localSeen) end)
measure("invalid-wire rejection",10000,function() N.Protocol.decode("C|1|100|nan|0|7|1|100") end)
print("Offline Linux/Lua 5.1 microbenchmarks only, not in-client CPU measurements.")
