-- Fixed copy; Arabic is offline art only. IDs keep labels swappable.
local _,N=...
local T={HEADINGS={"H2","H1","H6"},BODIES={"B1","B2","B3","B4","B5","B6"},HELP="help",DISMISS="dismiss_a"}
N.CallText=T
T.H1={art="Interface\\AddOns\\LayerEnemies\\Media\\call-h1.tga",latin="al-faz'a ya eyal",en="To arms, lads!"}
T.H2={art="Interface\\AddOns\\LayerEnemies\\Media\\call-h2.tga",latin="ma ydaweeha illa d-damm",en="Only blood cures this"}
T.H6={art="Interface\\AddOns\\LayerEnemies\\Media\\call-h6.tga",latin="damna ma yrooh hadar",en="Our blood isn't free"}
T.B1={art=nil,en="{killer} owes blood for {victim}. Meet in {zone}."}
T.B2={art=nil,en="Enemy: {killer}. One of ours: {victim}. Place: {zone}."}
T.B3={art=nil,en="{victim} needs you in {zone}. The enemy is {killer}."}
T.B4={art=nil,en="{victim} will be avenged. {killer} was last seen in {zone}."}
T.B5={art=nil,en="The kill on {victim} in {zone} won't stand. Wanted: {killer}."}
T.B6={art=nil,en="{zone}: {killer} owes a debt for {victim}, and debts get paid."}
T.victim={art="Interface\\AddOns\\LayerEnemies\\Media\\call-victim.tga",en="One of ours:"}
T.killer={art="Interface\\AddOns\\LayerEnemies\\Media\\call-killer.tga",en="Killer:"}
T.where={art="Interface\\AddOns\\LayerEnemies\\Media\\call-where.tga",en="Where:"}
T.help={art="Interface\\AddOns\\LayerEnemies\\Media\\call-help.tga",latin="abshir",en="On my way"}
T.dismiss_a={art="Interface\\AddOns\\LayerEnemies\\Media\\call-dismiss-a.tga",latin="i3dhirooni",en="Not now"}
T.dismiss_b={art="Interface\\AddOns\\LayerEnemies\\Media\\call-dismiss-b.tga",latin="sakkir",en="Close"}
-- Keep every client string at or below U+024F, including dynamic names/map labels.
-- Unsupported complete UTF-8 sequences become one '?'; no client shaping/font needed.
function T.clean(raw)
    raw=N.Safe.str(raw,1000) or "?"
    local out,i={},1
    while i<=#raw do
        local b=raw:byte(i)
        local n=b<128 and 1 or b>=194 and b<=223 and 2 or b>=224 and b<=239 and 3 or b>=240 and b<=244 and 4 or 1
        local nextByte=raw:byte(i+1)
        local latin=n==1 and b<128 or n==2 and nextByte and nextByte>=128 and nextByte<=191
            and (b<201 or b==201 and nextByte<=143)
        out[#out+1]=latin and raw:sub(i,i+n-1) or "?"
        i=i+n
    end
    return table.concat(out)
end
function T.format(id,values)
    local line=T[id].en:gsub("{(%w+)}",function(k) return T.clean(values[k]) end)
    return line
end
