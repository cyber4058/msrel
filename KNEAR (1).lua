-- ============================================================
-- K NEAR AIO (ALL-IN-ONE) - PNB + HARVEST + PLANT
-- 1 GUI, 3 menu. Session __KNearAIO.
-- ============================================================
local G = (getgenv and getgenv()) or _G
for _, key in ipairs({ "__Alfian","__KzoyzOpus","__GTFarm","__KnearHarvest","__KnearPlant","__KNearAIO" }) do
    if G[key] and G[key].Cleanup then pcall(G[key].Cleanup) end
    G[key] = nil
end
local Session = {}
G.__KNearAIO = Session
local function alive() return G.__KNearAIO == Session end
do
    local getId = getthreadidentity or get_thread_identity or getidentity or (syn and syn.get_thread_identity)
    if type(getId) == "function" then pcall(function() Session.Ident = getId() end) end
    Session.Exec = coroutine.create(function(job)
        while true do local ok, err = pcall(job); job = coroutine.yield(ok, err) end
    end)
end

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local WorldRemotes = ReplicatedStorage:WaitForChild("WorldRemotes", 10) or Instance.new("Folder")
local SetTileRemote = WorldRemotes:FindFirstChild("SetTile")
local TakeDropRemote = WorldRemotes:FindFirstChild("TakeDrop")

-- ============================================================
-- MODULE RESOLVER (dijalankan sekali)
-- ============================================================
Session.Found = {}
do
    local Found = Session.Found
    local function field(t,k) local ok,v = pcall(function() return t[k] end); return ok and v or nil end
    local function isFn(t,k) return type(field(t,k))=="function" end
    local function itemOk(v) return type(v)=="table" and type(field(v,"name"))=="string" end
    local function itemScore(t)
        if type(t)~="table" then return 0 end
        local good=0
        pcall(function()
            local a = field(t,2) or field(t,1) or field(t,3)
            if not itemOk(a) then local _,f=next(t); if not itemOk(f) then return end end
            local n=0
            for _,v in pairs(t) do n=n+1
                if itemOk(v) then good=good+1; if field(v,"kind")~=nil then good=good+1 end end
                if n>1500 then break end
            end
        end)
        return good
    end
    Found.itemScore = itemScore
    local mods = {}; if getloadedmodules then pcall(function() mods=getloadedmodules() end) end
    local bestItems = 0
    for _,m in ipairs(mods) do
        local ok,v = pcall(require,m)
        if ok and type(v)=="table" then
            if not Found.Net and isFn(v,"call") and type(field(v,"act"))=="table" and type(field(v,"tile"))=="table" then Found.Net=v
            elseif not Found.Roles and isFn(v,"titlesOf") and isFn(v,"isModerator") then Found.Roles=v
            elseif not Found.Sfx and isFn(v,"play") and isFn(v,"playAt") then Found.Sfx=v
            elseif not Found.Inventory and isFn(v,"room") and isFn(v,"used") and isFn(v,"select") and isFn(v,"count") and isFn(v,"add") and isFn(v,"new") then Found.Inventory=v
            elseif not Found.Splice and isFn(v,"result") and field(v,"SETS")~=nil then Found.Splice=v
            elseif not Found.Menu and isFn(v,"isDown") and field(v,"KEYS")~=nil then Found.Menu=v
            elseif not Found.Particles and isFn(v,"spawn") and not isFn(v,"play") then Found.Particles=v
            else
                local sc=itemScore(v); if sc>bestItems then bestItems=sc; Found.ItemDB=v end
                pcall(function() for _,sub in pairs(v) do if type(sub)=="table" then local s2=itemScore(sub); if s2>bestItems then bestItems=s2; Found.ItemDB=sub end end end end)
            end
        end
    end
    if bestItems<50 then Found.ItemDB=nil end
    local report={}
    for _,n in ipairs({"Net","Roles","Sfx","Inventory","Splice","Menu","Particles","ItemDB"}) do
        report[#report+1]=n.."="..(Found[n] and "ok" or "HILANG")
    end
    Session.ResolveReport = table.concat(report," ")
    print("[K. NEAR] resolver modul: "..Session.ResolveReport)
end

local ItemDB = {}
do
    local Found = Session.Found
    local function fill(src)
        if type(src)~="table" then return false end
        local n=0
        pcall(function()
            for k,v in pairs(src) do
                if type(v)=="table" and type(v.name)=="string" then
                    local id=(type(v.id)=="number" and v.id) or tonumber(k)
                    if id then rawset(ItemDB,id,v); n=n+1 end
                end
            end
        end)
        return n>0
    end
    local function scan()
        if next(ItemDB)~=nil then return true end
        if Found.ItemDB and fill(Found.ItemDB) then return true end
        pcall(function()
            local m=ReplicatedStorage:FindFirstChild("ItemDB",true)
            if m and m:IsA("ModuleScript") then
                local ok,v=pcall(require,m); if ok and Found.itemScore(v)>=50 then Found.ItemDB=v end
            end
        end)
        if Found.ItemDB and fill(Found.ItemDB) then return true end
        if not getgc then return false end
        local best,bestSc=nil,0
        pcall(function()
            for _,v in ipairs(getgc(true)) do
                if type(v)=="table" then
                    local a=rawget(v,2) or rawget(v,1)
                    if type(a)=="table" and type(rawget(a,"name"))=="string" then
                        local sc=Found.itemScore(v); if sc>bestSc then best,bestSc=v,sc end
                    end
                end
            end
        end)
        if best and bestSc>=50 then Found.ItemDB=best; return fill(best) end
        return false
    end
    Session.scanItemDB = scan
    local lastFix=0
    function Session.fixItemDB(ids)
        if #ids==0 or os.clock()-lastFix<15 then return false end
        lastFix=os.clock()
        local function score(t)
            local sc=0
            for _,id in ipairs(ids) do local it=rawget(t,id)
                if type(it)=="table" and type(rawget(it,"name"))=="string" then sc=sc+((rawget(it,"kind")~=nil) and 2 or 1) end
            end
            return sc
        end
        local best,bestSc=nil,0
        for _,m in pairs(Found) do if type(m)=="table" then local ok,sc=pcall(score,m); if ok and sc>bestSc then best,bestSc=m,sc end end end
        if getgc then pcall(function()
            for _,v in ipairs(getgc(true)) do if type(v)=="table" then local ok,sc=pcall(score,v); if ok and sc>bestSc then best,bestSc=v,sc end end end
        end) end
        if best and bestSc>0 then
            table.clear(ItemDB); Found.ItemDB=best; fill(best)
            for _,id in ipairs(ids) do local it=rawget(best,id); if type(it)=="table" then rawset(ItemDB,id,it) end end
            print("[K. NEAR] ItemDB fix (skor "..bestSc.."/"..(#ids*2)..")"); return true
        end
        return false
    end
    local last = os.clock()
    setmetatable(ItemDB,{ __index=function(_,id)
        if next(ItemDB)==nil and os.clock()-last>8 then last=os.clock(); if scan() then return rawget(ItemDB,id) end end
        return nil
    end })
    if not scan() then task.delay(3,function() if scan() then print("[K. NEAR] ItemDB (retry)") else warn("[K. NEAR] ItemDB belum ketemu") end end) end
end

local InventoryModule = Session.Found.Inventory or {}
local NetOk, Net = Session.Found.Net ~= nil, Session.Found.Net
local GameGui = PlayerGui:WaitForChild("GameGui", 10) or PlayerGui
local ParticlesOk, ParticlesModule = Session.Found.Particles ~= nil, Session.Found.Particles
local MenuModOk, MenuModule = Session.Found.Menu ~= nil, Session.Found.Menu

-- ============================================================
-- SHARED CONSTANTS & TABLES
-- ============================================================
local LOGO_URL = "https://raw.githubusercontent.com/cyber4058/tes/refs/heads/main/file_00000000fa648211a58242b299bc8914.png"
local DISCORD_URL = "https://discord.gg/5anHfrc69T"

local floor, abs = math.floor, math.abs
local State = { CalibX=0, CalibY=0, HitsOverride=0, BreakBackground=true, MutePunch=true, Visual=true, Broken=0, LastAction="-" }
local Refs  = { World=nil, Inv=nil, SetTile=nil, State=nil, Punch=nil, Particles={}, Menu=nil, Gems=nil, Hud=nil, Others=nil, Arm=nil }
local Drops = { list=nil, update=nil, brokeAt={} }
local Anim  = { fn=nil, idx=nil, set=nil }
local UI, Misc, Move = {}, {}, {}
local AutoInput = { active=false, left=false, right=false, jump=false, down=false }
local Connections = {}
local HitCount, PlacedAt, DropFailUntil = {}, {}, {}
local FastFail = {}
local getconsts = (debug and debug.getconstants) or getconstants

-- ============================================================
-- ENGINE STATE (P/H/A) + StatusOwner
-- ============================================================
local P = { Running=false, RunId=0, BlockId=nil, HomeX=nil, HomeY=nil,
    Left=true, Right=true, Up=false, PunchMs=120, Collect=true, Fast=true, Radius=3,
    Status="Siap", Put=0, Broke=0, Got=0, Pending=nil, OnStop=nil }

local H = { Running=false, RunId=0, SeedId=nil, Delay=100, Harvested=0, ReadyNow=0, Total=0,
    Det=nil, Unknown=false, Failed={}, Cool={}, GC={}, SeedCache={}, Status="Siap",
    OnStop=nil, Toast=nil }

local A = { Running=false, RunId=0, SeedId=nil, BaseId=nil, Delay=100, Planted=0, Total=0, Rejected=0,
    Failed={}, WorkCache={}, Log={}, Status="Siap", OnStop=nil, Toast=nil }

local StatusOwner = { box = nil }
local function say(text) if StatusOwner.box then StatusOwner.box.Status = text end end

-- ============================================================
-- SHARED FUNCTIONS
-- ============================================================
local function itemName(id)
    local it = ItemDB[id]; return (it and it.name) or ("Item #"..tostring(id))
end
local function invCount(id)
    if not Refs.Inv then return 0 end
    local ok,n = pcall(function() return Refs.Inv:count(id) end); return ok and n or 0
end
local function tileAt(layer,x,y)
    local w=Refs.World; if not w or x<0 or y<0 or x>=w.w or y>=w.h then return nil end
    local row = w[layer] and w[layer][y]; return row and (row[x] or 0) or nil
end
local function getView()
    local gg = PlayerGui:FindFirstChild("GameGui")
    local cam = gg and gg:FindFirstChild("World") and gg.World:FindFirstChild("Camera")
    local tiles = cam and cam:FindFirstChild("Tiles"); local pv = cam and cam:FindFirstChild("PlayerView")
    if not (tiles and pv) then return nil end
    local sample = tiles:FindFirstChildWhichIsA("ImageLabel")
    if not sample or sample.AbsoluteSize.X<=0 then return nil end
    return { tiles=tiles, pv=pv, ts=sample.AbsoluteSize.X }
end
local function getPlayerTile()
    if Refs.State then
        local ok,s = pcall(Refs.State)
        if ok and type(s)=="table" and type(s.x)=="number" then
            if s.active==false then return nil end
            return math.floor(s.x)+State.CalibX, math.floor(s.y-0.475)+State.CalibY
        end
    end
    local v = getView(); if not v then return nil end
    local center = v.pv.AbsolutePosition+v.pv.AbsoluteSize/2
    local rel = center - v.tiles.AbsolutePosition
    return math.floor(rel.X/v.ts)+State.CalibX, math.floor(rel.Y/v.ts)+State.CalibY
end
local function sendSetTile(layer,x,y,id)
    if id~=0 and State.Visual and Anim.place then Anim.place(x,y,id) end
    if Refs.SetTile then
        local ok,err = pcall(Refs.SetTile,layer,x,y,id,false,false)
        if ok then return true end
        warn("[K. NEAR] setTile gagal: "..tostring(err))
    end
    if NetOk and type(Net)=="table" and type(Net.tile)=="table" then
        local ok = pcall(Net.tile.send,{ layer=(layer=="bg") and 2 or 1, x=x, y=y, id=id, flip=false })
        if not ok then return false end
    elseif SetTileRemote then SetTileRemote:FireServer(layer,x,y,id,false)
    else return false end
    local grid = Refs.World and Refs.World[layer]
    if grid and grid[y] then grid[y][x] = id end
    return true
end
local function sendHitFx(x,y)
    if NetOk and type(Net)=="table" and Net.act then pcall(Net.act.send,{ x=x+0.5, y=y+0.5 }) end
end
local function hitsNeeded(id)
    if State.HitsOverride>0 then return State.HitsOverride end
    local it = ItemDB[id]; if not it then return 4 end
    local h = (it.kind=="seed") and 20 or it.hits; return tonumber(h) or 4
end
local function canBreak(id)
    if id==0 then return false end
    local it = ItemDB[id]; if not it then return true end
    if it.lock or it.area or it.vend or it.display then return false end
    local h = (it.kind=="seed") and 20 or it.hits; return h==nil or h>0
end
local PLACE_GUARD = 0.32
local function tryBreak(x,y,includeBg)
    if includeBg==nil then includeBg = State.BreakBackground end
    local key = x..","..y
    local fg = tileAt("fg",x,y); if fg==nil then return nil end
    local bg = tileAt("bg",x,y); local layer, id
    if fg~=0 then layer,id = "fg",fg
    elseif includeBg and bg~=0 then layer,id = "bg",bg end
    if not layer or not canBreak(id) then return nil end
    local t = PlacedAt[key]
    if t then
        local age = os.clock()-t
        if age<PLACE_GUARD then task.wait(PLACE_GUARD-age) end
        PlacedAt[key] = nil
    end
    if Refs.Punch then
        local ok,err = pcall(Refs.Punch,x,y,State.MutePunch or nil,nil)
        if not ok then State.LastAction = "Error pukul: "..tostring(err); return nil end
        if State.Visual then Anim.swing(x,y,"punch") end
        if tileAt(layer,x,y)~=id then
            Drops.brokeAt[key]=os.clock(); State.Broken=State.Broken+1
            State.LastAction = "Break "..itemName(id).." ("..x..","..y..")"
            return "broke"
        end
        State.LastAction = "Pukul "..itemName(id).." ("..x..","..y..")"
        return "hit"
    end
    local hc = HitCount[key]
    if not hc or hc.id~=id or hc.layer~=layer then hc={ id=id, layer=layer, n=0 }; HitCount[key]=hc end
    hc.n = hc.n+1
    sendHitFx(x,y)
    if State.Visual then Anim.swing(x,y,"punch") end
    local need = hitsNeeded(id)
    if hc.n>=need then
        sendSetTile(layer,x,y,0); HitCount[key]=nil
        Drops.brokeAt[key]=os.clock(); State.Broken=State.Broken+1
        State.LastAction = "Break "..itemName(id).." ("..x..","..y..")"; return "broke"
    end
    State.LastAction = "Pukul "..itemName(id).." "..hc.n.."/"..need; return "hit"
end

-- ===== getUpvalues + Anim helpers =====
local getUpvalues
function getUpvalues(fn)
    if debug and debug.getupvalues then
        local ok,ups = pcall(debug.getupvalues,fn); if ok and type(ups)=="table" then return ups end
    end
    local out = {}; local gu = (debug and debug.getupvalue) or getupvalue
    if gu then for i=1,60 do local ok,v=pcall(gu,fn,i); if not ok then break end; out[i]=v end end
    return out
end
function Anim.isArmFn(fn)
    if not getconsts then return false end
    if islclosure and not islclosure(fn) then return false end
    local ok,cs = pcall(getconsts,fn); if not ok or type(cs)~="table" then return false end
    local a,b,c=false,false,false
    for _,k in pairs(cs) do
        if k=="forearm" then a=true elseif k=="heldReach" then b=true elseif k=="punchReach" then c=true end
    end
    return a and b and c
end
function Anim.bind(fn)
    local gu = (debug and debug.getupvalue) or getupvalue
    local su = (debug and debug.setupvalue) or setupvalue
    if not (gu and su) then return false end
    local vals,last = {}, 0
    for i=1,16 do local ok,v=pcall(gu,fn,i); if not ok then break end; vals[i]=v; if v~=nil then last=i end end
    for i=1,last-1 do
        local v = vals[i]
        if v==nil or (type(v)=="table" and rawget(v,"t")~=nil and rawget(v,"facing")~=nil) then
            Anim.fn,Anim.idx,Anim.set = fn,i,su; return true
        end
    end
    return false
end
function Anim.findFast()
    if not getconnections or Anim.fn then return Anim.fn~=nil end
    for _,name in ipairs({"RenderStepped","Heartbeat","PreRender","Stepped"}) do
        local okS,sig = pcall(function() return RunService[name] end)
        if okS and sig then
            local ok,conns = pcall(getconnections,sig)
            if ok and type(conns)=="table" then
                for _,c in ipairs(conns) do
                    local okf,fn = pcall(function() return c.Function end)
                    if okf and type(fn)=="function" then
                        for _,u in pairs(getUpvalues(fn)) do
                            if type(u)=="function" and Anim.isArmFn(u) then
                                Refs.Arm = u; return Anim.bind(u)
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end
function Anim.quickRefs()
    if not getconnections then return false end
    local queue,seen,n = {}, {}, 0
    for _,name in ipairs({"RenderStepped","Heartbeat","Stepped"}) do
        local okS,sig = pcall(function() return RunService[name] end)
        if okS and sig then
            local ok,conns = pcall(getconnections,sig)
            if ok and type(conns)=="table" then
                for _,c in ipairs(conns) do
                    local okf,fn = pcall(function() return c.Function end)
                    if okf and type(fn)=="function" then queue[#queue+1]=fn end
                end
            end
        end
    end
    local i=1
    while i<=#queue and n<400 and not (Refs.Inv and Refs.World) do
        local fn = queue[i]; i=i+1
        if not seen[fn] then
            seen[fn]=true; n=n+1
            for _,u in pairs(getUpvalues(fn)) do
                local tu = type(u)
                if tu=="table" then
                    if not Refs.Inv then
                        local ok,isInv = pcall(function() return getmetatable(u)==InventoryModule and type(rawget(u,"slots"))=="table" end)
                        if ok and isInv then Refs.Inv=u end
                    end
                    if not Refs.World then
                        local ok,isWorld = pcall(function()
                            return type(rawget(u,"fg"))=="table" and type(rawget(u,"bg"))=="table"
                                and type(rawget(u,"w"))=="number" and rawget(u,"spawn")~=nil
                        end)
                        if ok and isWorld then Refs.World=u end
                    end
                elseif tu=="function" and not seen[u] then queue[#queue+1]=u end
            end
        end
    end
    return Refs.Inv~=nil
end

-- ===== findRefs (main) =====
local function isSetTileFn(fn)
    if not getconsts then return false end
    if islclosure and not islclosure(fn) then return false end
    local ok,cs = pcall(getconsts,fn); if not ok or type(cs)~="table" then return false end
    local hasSend,hasP,hasF = false,false,false
    for _,c in pairs(cs) do
        if c=="tile" or c=="SetTile" then hasSend=true
        elseif c=="placedAt" then hasP=true elseif c=="flips" then hasF=true end
    end
    return hasSend and hasP and hasF
end
local function isPunchFn(fn)
    if not getconsts then return false end
    if islclosure and not islclosure(fn) then return false end
    local ok,cs = pcall(getconsts,fn); if not ok or type(cs)~="table" then return false end
    local hasV,hasM=false,false
    for _,c in pairs(cs) do
        if c=="Empty the Vending Machine first!" then hasV=true
        elseif c=="newCrack" or c=="HarvestProvider" then hasM=true end
    end
    return hasV and hasM
end
local function isStateHolder(v)
    local fn = rawget(v,"state"); if type(fn)~="function" then return false end
    local ok,s = pcall(fn)
    return ok and type(s)=="table" and type(s.x)=="number" and type(s.y)=="number"
        and s.facing~=nil and s.vx~=nil
end
local function isGameFn(fn)
    if fn==isSetTileFn or fn==isPunchFn then return false end
    if isexecutorclosure then local ok,r=pcall(isexecutorclosure,fn); if ok and r then return false end end
    local ok,src = pcall(debug.info,fn,"s")
    if ok and type(src)=="string" and (string.find(src,"CoreGui",1,true) or string.find(src,"CorePackages",1,true)) then return false end
    return true
end
local function findRefs()
    Refs.World,Refs.Inv,Refs.SetTile,Refs.State,Refs.Punch,Refs.Menu = nil,nil,nil,nil,nil,nil
    Refs.Gems,Refs.Hud,Refs.Others,Refs.Arm = nil,nil,nil,nil
    Refs.Particles = {}; Anim.Particles=nil
    if not getgc then return false,"Executor tidak punya getgc()" end
    local invLoose,punchLoose
    for gi,v in ipairs(getgc(true)) do
        if gi%3000==0 then task.wait() end
        local tv = type(v)
        if tv=="table" then
            if not Refs.World then
                local ok,isW = pcall(function() return type(rawget(v,"fg"))=="table" and type(rawget(v,"bg"))=="table" and type(rawget(v,"w"))=="number" and type(rawget(v,"h"))=="number" and rawget(v,"spawn")~=nil end)
                if ok and isW then Refs.World=v end
            end
            if not Refs.Inv then
                local ok,isI = pcall(function() return getmetatable(v)==InventoryModule and type(rawget(v,"slots"))=="table" and rawget(v,"capacity")~=nil end)
                if ok and isI then Refs.Inv=v end
            end
            if not Refs.Inv and not invLoose then
                local ok,isL = pcall(function() return type(rawget(v,"slots"))=="table" and type(v.count)=="function" and type(v.room)=="function" and type(v.add)=="function" and type(v.remove)=="function" end)
                if ok and isL then invLoose=v end
            end
            if not Refs.State then local ok,ish = pcall(isStateHolder,v); if ok and ish then Refs.State=rawget(v,"state") end end
            if not Refs.Menu then local ok,isM = pcall(function() return type(rawget(v,"openBackpack"))=="function" and type(rawget(v,"ui"))=="table" end); if ok and isM then Refs.Menu=v end end
            if not Refs.Gems then local ok,isG = pcall(function() return type(rawget(v,"addGems"))=="function" end); if ok and isG then Refs.Gems=v end end
            if not Refs.Hud then local ok,isH = pcall(function() return type(rawget(v,"punchRange"))=="function" and type(rawget(v,"handPower"))=="function" end); if ok and isH then Refs.Hud=v end end
            if not Refs.Others then local ok,isO = pcall(function() return type(rawget(v,"list"))=="function" and type(rawget(v,"where"))=="function" and type(rawget(v,"playerAt"))=="function" end); if ok and isO then Refs.Others=v end end
            if ParticlesOk then local ok,isP = pcall(function() return getmetatable(v)==ParticlesModule and type(rawget(v,"live"))=="table" and type(rawget(v,"free"))=="table" end); if ok and isP then table.insert(Refs.Particles,v) end end
        elseif tv=="function" and (not Refs.SetTile or not Refs.Punch) and isGameFn(v) then
            if not Refs.SetTile and isSetTileFn(v) then Refs.SetTile=v
            elseif not Refs.Punch and isPunchFn(v) then Refs.Punch=v
            elseif not Refs.Punch and not punchLoose then
                if getconsts then
                    local ok,cs = pcall(getconsts,v)
                    if ok and type(cs)=="table" then
                        for _,c in pairs(cs) do if c=="Empty the Vending Machine first!" then punchLoose=v; break end end
                    end
                end
            end
        end
        if Refs.World and Refs.Inv and Refs.SetTile and Refs.State and Refs.Punch and Refs.Menu and Refs.Gems and Refs.Hud and Refs.Others then break end
    end
    if not Refs.Inv and invLoose then Refs.Inv=invLoose end
    if not Refs.Punch and punchLoose then Refs.Punch=punchLoose end
    return Refs.World~=nil
end

-- ===== Drops / collect helpers =====
local function isDropList(t)
    if type(t)~="table" or t==Refs.World then return false end
    local first = rawget(t,1)
    if first==nil then return next(t)==nil end
    return type(first)=="table" and rawget(first,"uid")~=nil and rawget(first,"frame")~=nil
end
local function findDropRefs(deep)
    local w0 = Refs.World
    local dl = w0 and rawget(w0,"dropList")
    if type(dl)=="function" then
        local okl,l = pcall(dl)
        if okl and isDropList(l) then
            if Drops.list~=l then Drops.update=nil end
            Drops.list = l
            if not Drops.update then Drops.findUpdate() end
            return true
        end
    end
    if Drops.list and not deep then return true end
    Drops.list, Drops.update = nil,nil
    local wd = Refs.World and rawget(Refs.World,"dropTaken")
    if type(wd)=="function" then
        for _,u in pairs(getUpvalues(wd)) do
            if not Drops.list and isDropList(u) then Drops.list=u
            elseif not Drops.update and type(u)=="function" then Drops.update=u end
        end
    end
    local ev = WorldRemotes:FindFirstChild("DropTaken")
    if not Drops.list and ev and getconnections then
        local ok,conns = pcall(getconnections,ev.OnClientEvent)
        if ok and type(conns)=="table" then
            for _,c in ipairs(conns) do
                local okf,fn = pcall(function() return c.Function end)
                if okf and type(fn)=="function" then
                    for _,u in pairs(getUpvalues(fn)) do
                        if not Drops.list and isDropList(u) then Drops.list=u
                        elseif not Drops.update and type(u)=="function" then Drops.update=u end
                    end
                end
                if Drops.list then break end
            end
        end
    end
    if not Drops.list and deep and getgc then
        for _,v in ipairs(getgc(true)) do
            if type(v)=="table" then
                local e = rawget(v,1)
                if type(e)=="table" and rawget(e,"uid")~=nil and rawget(e,"frame")~=nil and rawget(e,"born")~=nil then
                    Drops.list=v; break
                end
            end
        end
    end
    return Drops.list~=nil
end
function Drops.findUpdate()
    local w,list = Refs.World,Drops.list
    local wd = w and rawget(w,"dropTaken")
    if type(wd)~="function" or not list then return false end
    for _,u in pairs(getUpvalues(wd)) do
        if type(u)=="function" then
            for _,uu in pairs(getUpvalues(u)) do
                if rawequal(uu,list) then Drops.update=u; return true end
            end
        end
    end
    return false
end
function Drops.applyTaken(d,left)
    local list = Drops.list
    if not list or not table.find(list,d) then return end
    if not Drops.update then Drops.findUpdate() end
    if Drops.update then
        local ok = pcall(Drops.update,d,left)
        if ok then
            if left>0 then d.flown=nil; if typeof(d.frame)=="Instance" then pcall(function() d.frame.Visible=not d.culled end) end end
            return
        end
    end
    d.n = left
    if left>0 then
        pcall(function() if d.setGem then d.setGem(left) elseif d.count then d.count:set(left>1 and tostring(left) or "") end end)
        d.flown=nil; if typeof(d.frame)=="Instance" then pcall(function() d.frame.Visible=not d.culled end) end
    else
        local i = table.find(list,d); if i then table.remove(list,i) end
        if typeof(d.frame)=="Instance" then pcall(function() d.frame:Destroy() end) end
    end
end
local function playerState()
    if not Refs.State then return nil end
    local ok,s = pcall(Refs.State)
    if ok and type(s)=="table" and type(s.x)=="number" and type(s.y)=="number" and s.active~=false then return s end
    return nil
end
local function fgIdAt(x,y) local w=Refs.World; local row=w and w.fg[y]; return (row and row[x]) or 0 end
local function fgItemAt(x,y) local id=fgIdAt(x,y); if id~=0 then return ItemDB[id] end return nil end
local function solidAt(x,y)
    local w=Refs.World; if not w then return true end
    if x<0 or x>=w.w or y>=w.h then return true end
    if y<0 then return false end
    local it = fgItemAt(x,y); if not it then return false end
    if it.combiner then local ok,shut=pcall(w.combinerShut,x,y); return (not ok) or (shut and true or false) end
    if it.vip then local ok,may=pcall(w.vipMay,x,y); return not (ok and may) end
    if it.entrance then
        local sw = w.switches and w.switches[y*w.w+x]
        if it.gate then return not (sw and sw.off==true) end
        if sw and sw.public then return false end
        local ok,may = pcall(function() return w.areas.mayBuild(w.lock,x,y) end); return not (ok and may)
    end
    return it.solid and true or false
end
local function hazardAt(x,y) local it=fgItemAt(x,y); return it~=nil and (it.deadly or it.hurts or it.laser) and true or false end
local function platformAt(x,y) local it=fgItemAt(x,y); return it~=nil and it.platform and true or false end
local function openAt(x,y) return not solidAt(x,y) and not hazardAt(x,y) end
local function realSupport(x,y) return not hazardAt(x,y+1) and (solidAt(x,y+1) or platformAt(x,y+1)) end
function Move.los(nx,ny,tx,ty)
    if ty-ny>=2 then for y=ny+1,ty-1 do if solidAt(tx,y) then return false end end
    elseif ny-ty>=2 then for y=ty+1,ny-1 do if solidAt(tx,y) then return false end end end
    return true
end
local function stateReaches(s,tx,ty,R)
    return abs(tx+0.5-s.x)<=R and abs(ty+0.5-(s.y-0.475))<=R
end
local function canWorkAt(x,y)
    local w = Refs.World
    local ok,res = pcall(function()
        if w.areas and type(w.areas.mayBuild)=="function" and not w.areas.mayBuild(w.lock,x,y) then return false end
        if type(w.builderOk)=="function" and not w.builderOk(x,y,false) then return false end
        return true
    end)
    return (not ok) or res
end
function Anim.swing(x,y,kind)
    if not (Anim.fn and Anim.idx and Anim.set) then return end
    local s = playerState()
    local facing = (s and x+0.5<s.x) and -1 or 1
    pcall(Anim.set,Anim.fn,Anim.idx,{ t=os.clock(), x=x+0.5, y=y+0.5, facing=facing, kind=kind })
end
function Anim.puff(x,y)
    local list = Refs.Particles; if not list or #list==0 then return end
    local pick = Anim.Particles
    if not pick then
        local worldGui = PlayerGui:FindFirstChild("GameGui"); worldGui = worldGui and worldGui:FindFirstChild("World")
        for _,p in ipairs(list) do
            local ok,inW = pcall(function() return worldGui~=nil and typeof(p.parent)=="Instance" and p.parent:IsDescendantOf(worldGui) end)
            if ok and inW then pick=p; break end
        end
        pick = pick or list[1]; Anim.Particles = pick
    end
    pcall(function() pick:place(x+0.5,y+0.5) end)
end
function Anim.place(x,y,id)
    local it = ItemDB[id]; local seed = it and it.kind=="seed"
    Anim.swing(x,y,"build")
    if not seed then Anim.puff(x,y) end
end
local function steerX(s,targetX,tol)
    local dx = targetX-s.x; local vx = s.vx or 0
    local decel = s.grounded and 48 or 17; local dir = 0
    if abs(dx)>tol then
        dir = dx>0 and 1 or -1
        if vx*dir>0 and (vx*vx)/(2*decel)>=abs(dx)-tol*0.5 then dir=0 end
    end
    AutoInput.left = dir<0; AutoInput.right = dir>0
end
local function inTile(t,x,y) return x>=t.x-0.15 and x<t.x+1.15 and y>=t.y-0.15 and y<t.y+1.15 end
function Drops.waitSpawn(tiles)
    local ping = 0.1; pcall(function() ping = LocalPlayer:GetNetworkPing() end)
    local limit = math.clamp(0.15+2.5*ping,0.25,0.8)
    local newest = nil
    for _,t in ipairs(tiles) do local b=Drops.brokeAt[t.x..","..t.y]; if b and os.clock()-b<limit and (not newest or b>newest) then newest=b end end
    if not newest then return end
    local list = Drops.list
    while os.clock()-newest<limit and alive() do
        if list then
            for _,d in ipairs(list) do
                if type(d)=="table" and type(d.x)=="number" and (d.born or 0)>=newest then
                    for _,t in ipairs(tiles) do if inTile(t,d.x,d.y) then task.wait(0.05); return end end
                end
            end
        end
        task.wait()
    end
end
local OrigIsDown = nil
local function isDownWrapper(saved,key,...)
    if AutoInput.active then
        if key=="keyLeft" then return AutoInput.left end
        if key=="keyRight" then return AutoInput.right end
        if key=="keyJump" then return AutoInput.jump end
        if key=="keyDown" then return AutoInput.down end
    end
    return OrigIsDown(saved,key,...)
end
if MenuModOk and type(MenuModule)=="table" and type(rawget(MenuModule,"isDown"))=="function" then
    OrigIsDown = rawget(MenuModule,"isDown"); MenuModule.isDown = isDownWrapper
end
local function releaseInput() AutoInput.left,AutoInput.right,AutoInput.jump,AutoInput.down = false,false,false,false end
local function gameReady() return Refs.World~=nil and Refs.Inv~=nil end
local function connectGame()
    pcall(Anim.quickRefs); findRefs(); pcall(findDropRefs,true); pcall(Anim.findFast)
    table.clear(DropFailUntil)
    return gameReady()
end

-- ===== Common movement / collect helpers =====
local function pathOk(fromX,toX,row)
    local a,b = floor(fromX),floor(toX); local st = (b>=a) and 1 or -1
    for c=a,b,st do if not (openAt(c,row) and realSupport(c,row)) then return false end end
    return true
end
local function walkX(run,targetX,tol,maxSec,stopFn)
    AutoInput.active = true; local t0 = os.clock(); local reached = false
    while run() and os.clock()-t0<maxSec do
        task.wait()
        local s = playerState(); if not s or s.dead then break end
        if stopFn and stopFn() then reached=true; break end
        steerX(s,targetX,tol)
        if abs(s.x-targetX)<=tol and abs(s.vx or 0)<1.5 then reached=true; break end
    end
    releaseInput(); AutoInput.active = false; return reached
end
local function atHome()
    local px,py = getPlayerTile(); local s = playerState()
    return s~=nil and px==P.HomeX and py==P.HomeY and abs(s.x-(P.HomeX+0.5))<=0.35
end
local function goHome(run)
    local s = playerState(); local px,py = getPlayerTile()
    if not (s and px) then say("Karakter tidak ditemukan"); return false end
    if atHome() then return true end
    if py~=P.HomeY then say(("Pindah ke baris Y=%d dulu"):format(P.HomeY)); return false end
    local cx = P.HomeX+0.5
    if not pathOk(s.x,cx,py) then say("Jalur ke posisi break tidak aman"); return false end
    say("Kembali ke posisi break"); walkX(run,cx,0.12,5,nil); return atHome()
end
local function dropOk(d,now,failTbl)
    if type(d)~="table" or type(d.x)~="number" or type(d.y)~="number" then return false end
    if d.taking or (d.n or 0)<=0 then return false end
    if d.armed==false and d.id~=112 then return false end
    local f = (failTbl or DropFailUntil)[d.uid]; if f and now<f then return false end
    if d.id~=112 and Refs.Inv then
        local ok,room = pcall(function() return Refs.Inv:room(d.id) end)
        if ok and type(room)=="number" and room<=0 then return false end
    end
    return true
end
local function dropAlive(list,d) return (d.n or 0)>0 and table.find(list,d)~=nil end
local COLLECT_RANGE = 6
local function itemsNear(list)
    local s = playerState(); if not s then return 0 end
    local by,now,total = s.y-0.475, os.clock(), 0
    for _,d in ipairs(list) do
        if dropOk(d,now) and abs(d.x-s.x)<=COLLECT_RANGE and abs(d.y-by)<=1.5 then total=total+(d.n or 0) end
    end
    return total
end
local function collectDrops(run)
    if not P.Collect then return end
    if not Drops.list then pcall(findDropRefs) end
    local list = Drops.list; if not list then return end
    if itemsNear(list)<=0 then return end
    local guard = 0
    while run() and guard<10 do
        local s = playerState(); if not s then return end
        local by,now = s.y-0.475, os.clock()
        local best,bestDist
        for _,d in ipairs(list) do
            if dropOk(d,now) and abs(d.x-s.x)<=COLLECT_RANGE and abs(d.y-by)<=1.5 then
                local dist = abs(d.x-s.x); if not best or dist<bestDist then best,bestDist = d,dist end
            end
        end
        if not best then break end
        guard = guard+1; local d = best
        if not pathOk(s.x,d.x,floor(by)) then DropFailUntil[d.uid]=now+15
        else
            say("Ambil item: "..itemName(d.id))
            walkX(run,d.x,0.22,3,function() return not dropAlive(list,d) end)
            local t1 = os.clock()
            while run() and dropAlive(list,d) and os.clock()-t1<0.6 do task.wait() end
            if dropAlive(list,d) then DropFailUntil[d.uid]=os.clock()+8 end
        end
    end
end
local function fastTake(d)
    local w = Refs.World; local worldTake = w and rawget(w,"takeDrop")
    if type(worldTake)~="function" and not TakeDropRemote then return false end
    if d.taking or d.pending or d.display or (d.n or 0)<=0 then return false end
    if d.armed==false and d.id~=112 then return false end
    local now = os.clock(); if FastFail[d.uid] and now<FastFail[d.uid] then return false end
    local amount = d.n
    if d.id~=112 and Refs.Inv then
        local okr,room = pcall(function() return Refs.Inv:room(d.id) end)
        if okr and type(room)=="number" then amount = math.min(amount,room) end
    end
    if amount<=0 then FastFail[d.uid]=now+1; return false end
    d.taking = true
    if typeof(d.frame)=="Instance" then pcall(function() d.frame.Visible=false end) end
    local ok,taken
    if type(worldTake)=="function" then ok,taken = pcall(worldTake,d.uid,amount)
    else ok,taken = pcall(TakeDropRemote.InvokeServer,TakeDropRemote,d.uid,amount) end
    d.taking = false
    if not (ok and type(taken)=="number" and taken>0) then
        d.failN = (d.failN or 0)+1
        FastFail[d.uid] = os.clock()+math.min(6,d.failN); d.flown=nil
        if typeof(d.frame)=="Instance" then pcall(function() d.frame.Visible=not d.culled end) end
        return false
    end
    FastFail[d.uid] = nil
    if d.id==112 then if Refs.Gems then pcall(Refs.Gems.addGems,taken) end
    elseif Refs.Inv then pcall(function() Refs.Inv:add(d.id,taken) end) end
    Drops.applyTaken(d,math.max(0,(d.n or 0)-taken))
    return true
end
local function inCollectArea(d,tile)
    local cx,cy = P.HomeX+0.5, P.HomeY+0.5
    if abs(d.x-cx)<=P.Radius and abs(d.y-cy)<=P.Radius then return true end
    if tile and abs(d.x-(tile.x+0.5))<=1.5 and abs(d.y-(tile.y+0.5))<=2.5 then return true end
    return false
end
local function itemsAround(list,tile)
    local total = 0
    for _,d in ipairs(list) do
        if type(d)=="table" and type(d.x)=="number" and type(d.y)=="number" and (d.n or 0)>0 and inCollectArea(d,tile) then total=total+d.n end
    end
    return total
end
local function dropsInTile(tx,ty)
    local list = Drops.list; if not list then return 0 end
    local t,n = {x=tx,y=ty}, 0
    for _,d in ipairs(list) do if type(d)=="table" and type(d.x)=="number" and (d.n or 0)>0 and inTile(t,d.x,d.y) then n=n+1 end end
    return n
end
local function fastCollect(run,tile)
    if not P.Fast or not P.HomeX then return end
    local list = Drops.list; if not list then return end
    for _=1,4 do
        if not run() then return end
        local now,batch = os.clock(), {}
        for _,d in ipairs(list) do
            if dropOk(d,now,FastFail) and inCollectArea(d,tile) then batch[#batch+1]=d end
        end
        if #batch==0 then return end
        say(("Collect cepat (%d)"):format(#batch))
        for _,d in ipairs(batch) do task.spawn(function() pcall(fastTake,d) end) end
        local t0 = os.clock()
        while run() and os.clock()-t0<1.0 do
            local busy=false
            for _,d in ipairs(batch) do
                if d.taking or (dropAlive(list,d) and not (FastFail[d.uid] and os.clock()<FastFail[d.uid])) then busy=true; break end
            end
            if not busy then break end
            task.wait()
        end
    end
end
local function collectAll(run,tile)
    if not (P.Fast or P.Collect) then return end
    if not Drops.list then pcall(findDropRefs) end
    local list = Drops.list; if not list then return end
    local before = itemsAround(list,tile)
    fastCollect(run,tile)
    if run() then collectDrops(run) end
    P.Got = P.Got + math.max(0,before-itemsAround(list,tile))
end
local function isPlaceable(id)
    local it = ItemDB[id]; if not it then return true end
    if it.kind=="tool" or it.kind=="cloth" or it.kind=="clothes" or it.kind=="consumable" then return false end
    if it.lock or it.area then return false end
    return true
end
function UI.invSlotIds()
    local out,seen = {}, {}
    local inv = Refs.Inv; if not inv then return out end
    local okS,slots = pcall(function() return inv.slots end)
    if not okS or type(slots)~="table" then return out end
    for k,slot in pairs(slots) do
        local id,n
        if type(slot)=="table" then
            id = tonumber(slot.id or slot.item or slot.itemId or slot[1])
            n  = tonumber(slot.n or slot.count or slot.amount or slot.qty or slot[2])
        elseif type(slot)=="number" and type(k)=="number" then id,n = k,slot end
        if id and id~=0 and not seen[id] then
            if n==nil then n=invCount(id) end
            if n>0 then seen[id]=true; out[#out+1]=id end
        end
    end
    local miss=false
    for _,id in ipairs(out) do if not rawget(ItemDB,id) then miss=true; break end end
    if miss and Session.fixItemDB then pcall(Session.fixItemDB,out) end
    return out
end
local function placeableIds()
    local ids={}
    for _,id in ipairs(UI.invSlotIds()) do if isPlaceable(id) then ids[#ids+1]=id end end
    table.sort(ids); return ids
end

-- ============================================================
-- PNB ENGINE
-- ============================================================
local function pnbTile(run,tx,ty,name)
    local id = P.BlockId; if not id then return false end
    local it = ItemDB[id]; local layer = (it and it.background) and "bg" or "fg"
    local fg = tileAt("fg",tx,ty)
    if fg==nil then say("Tile "..name.." di luar world"); return false end
    if not canWorkAt(tx,ty) then say("Tile "..name.." terkunci / tidak boleh dibangun"); return false end
    local cur = tileAt(layer,tx,ty); if cur==nil then return false end
    local key = tx..","..ty
    if cur==0 and (layer=="bg" or fg==0) then
        if invCount(id)<=0 then say("Block "..itemName(id).." habis"); return false end
        sendSetTile(layer,tx,ty,id)
        if Refs.Inv then pcall(function() Refs.Inv:remove(id,1) end) end
        HitCount[key]=nil; PlacedAt[key]=os.clock(); P.Put = P.Put+1
    elseif cur~=id then say("Tile "..name.." terisi ("..itemName(cur)..")"); return false end
    P.Pending = { x=tx, y=ty, id=id, layer=layer }
    local tries,nilN = 0, 0
    while run() and tries<80 do
        local r = tryBreak(tx,ty,layer=="bg")
        if r=="broke" then
            P.Pending = nil; P.Broke = P.Broke+1
            say("Put & break "..itemName(id).." ("..name..")"); return true
        end
        if r==nil then nilN=nilN+1; if nilN>=8 then break end end
        tries = tries+1
        task.wait(math.max(P.PunchMs,30)/1000)
    end
    return false
end
local function targetList()
    local t = {}
    if P.Left  then t[#t+1] = { dx=-1, dy=0, name="kiri" } end
    if P.Right then t[#t+1] = { dx= 1, dy=0, name="kanan" } end
    if P.Up    then t[#t+1] = { dx= 0, dy=-1, name="atas" } end
    return t
end
local function pnbLoop(run)
    say("PNB berjalan")
    while run() do
        if not gameReady() then say("Belum terhubung, menghubungkan..."); connectGame(); task.wait(1); continue end
        if not Drops.list then pcall(findDropRefs) end
        if not goHome(run) then task.wait(0.5); continue end
        local pend = P.Pending
        if pend then
            if pend.id==P.BlockId and tileAt(pend.layer,pend.x,pend.y)==pend.id then
                if pnbTile(run,pend.x,pend.y,"sisa") then
                    Drops.waitSpawn({ { x=pend.x, y=pend.y } })
                    collectAll(run,{ x=pend.x, y=pend.y }); goHome(run)
                else task.wait(0.4) end
                continue
            end
            P.Pending = nil
        end
        local did = 0
        for _,tg in ipairs(targetList()) do
            if not run() then break end
            if invCount(P.BlockId)<=0 then break end
            local tx,ty = P.HomeX+tg.dx, P.HomeY+tg.dy
            local clear = true
            if dropsInTile(tx,ty)>0 then
                say("Item belum terambil, collect dulu ("..tg.name..")")
                collectAll(run,{ x=tx, y=ty })
                if dropsInTile(tx,ty)>0 then clear=false; say("Item masih di tile "..tg.name..", dilewati dulu") end
            end
            if clear and run() then
                local ok = pnbTile(run,tx,ty,tg.name)
                if ok then
                    did = did+1
                    Drops.waitSpawn({ { x=tx, y=ty } })
                    collectAll(run,{ x=tx, y=ty })
                    if not goHome(run) then break end
                elseif P.Pending then break end
            end
        end
        if run() and invCount(P.BlockId)<=0 and not P.Pending then
            collectAll(run,nil); goHome(run)
            if invCount(P.BlockId)<=0 then say("Block habis, PNB berhenti"); return end
        end
        task.wait(did>0 and 0.03 or 0.3)
    end
end
function P.start()
    if P.Running then return true end
    if not gameReady() then return false,"Belum terhubung ke game. Tekan Hubungkan." end
    if not P.BlockId then return false,"Pilih block dulu" end
    if not (P.Left or P.Right or P.Up) then return false,"Pilih minimal satu arah break" end
    local px,py = getPlayerTile()
    if not px then return false,"Karakter tidak ditemukan (belum masuk world?)" end
    if not P.HomeX then P.HomeX,P.HomeY = px,py end
    P.Running = true; P.RunId = P.RunId+1; P.Pending = nil
    StatusOwner.box = P
    local id = P.RunId
    task.spawn(function()
        local ok,err = pcall(pnbLoop,function() return P.Running and P.RunId==id and alive() end)
        if not ok then say("Error: "..tostring(err)); warn("[K. NEAR] PNB: "..tostring(err)) end
        if P.RunId==id then
            P.Running = false; releaseInput(); AutoInput.active = false
            if P.OnStop then pcall(P.OnStop) end
        end
    end)
    return true
end
function P.stop(reason)
    if not P.Running then return end
    P.Running = false; P.RunId = P.RunId+1; releaseInput(); AutoInput.active = false
    say(reason or "Berhenti")
    if P.OnStop then pcall(P.OnStop) end
end

-- ============================================================
-- HARVEST ENGINE
-- ============================================================
local READY_FLAG = { ready=true, grown=true, harvestable=true, mature=true, ripe=true,
    isready=true, fullygrown=true, canharvest=true, done=true, fruit=true, hasfruit=true, fruiting=true }
local READY_AT = { readyat=true, ripeat=true, matureat=true, harvestat=true, growsat=true,
    doneat=true, finishat=true, readytime=true, ripentime=true }
local PLANT_AT = { plantedat=true, planted=true, plantedtime=true, planttime=true, born=true,
    startedat=true, start=true, since=true, t=true, at=true, time=true, ts=true, p=true }

function H.growTime(id)
    local c = H.GC[id]; if c~=nil then return c or nil end
    local it = ItemDB[id]; local best = false
    if type(it)=="table" then
        if type(it.grow)=="number" and it.grow>0 then H.GC[id]=it.grow; return it.grow end
        pcall(function()
            for k,v in pairs(it) do
                if type(v)=="number" and v>0 then
                    local n = string.lower(tostring(k))
                    if string.find(n,"grow",1,true) or string.find(n,"ripen",1,true) or string.find(n,"mature",1,true) then best=v; break end
                end
            end
        end)
        H.GC[id] = best
    end
    return best or nil
end
function H.nowFor(v)
    local srcs = {}
    local sv; pcall(function() sv = workspace:GetServerTimeNow() end)
    if sv and abs(sv-v)<3e8 then return sv end
    if sv then srcs[#srcs+1]=sv end
    srcs[#srcs+1]=os.time(); srcs[#srcs+1]=os.clock(); srcs[#srcs+1]=tick()
    local best,diff
    for _,n in ipairs(srcs) do local d=abs(n-v); if not diff or d<diff then best,diff=n,d end end
    return best
end
function H.upTables()
    local w = Refs.World; local out,seenF,seenT,queue = {}, {}, {}, {}
    if not w then return out end
    for _,n in ipairs({"treeFruit","treeLook","treeNear","providerReady","providerStage","providerInfo","tileChanged"}) do
        local ok,f = pcall(function() return w[n] end)
        if ok and type(f)=="function" then queue[#queue+1]={ f=f, name=n } end
    end
    local i = 1
    while i<=#queue and i<=40 do
        local q = queue[i]; i=i+1
        if not seenF[q.f] then
            seenF[q.f]=true
            for idx,u in pairs(getUpvalues(q.f)) do
                if type(u)=="table" then
                    if u~=w and u~=w.fg and u~=w.bg and u~=ItemDB and u~=Refs.Inv and not seenT[u] and #out<150 then
                        seenT[u]=true; out[#out+1]={ name="up:"..q.name.."#"..idx, t=u }
                        local n=0
                        pcall(function()
                            for k2,v2 in pairs(u) do
                                n=n+1; if n>20 then break end
                                if type(v2)=="table" and type(k2)=="string" and not seenT[v2] then
                                    seenT[v2]=true; out[#out+1]={ name="up:"..q.name.."#"..idx.."."..k2, t=v2 }
                                end
                            end
                        end)
                    end
                elseif type(u)=="function" and not seenF[u] then queue[#queue+1]={ f=u, name=q.name.."/f"..idx } end
            end
        end
    end
    return out
end
function H.look(t,mode,x,y)
    local w = Refs.World
    local ok,e = pcall(function()
        if mode=="idx" then return t[y*w.w+x]
        elseif mode=="xy" then return t[x..","..y]
        elseif mode=="yx" then local r=t[y]; return r and r[x]
        elseif mode=="xy2" then local r=t[x]; return r and r[y]
        elseif mode=="list" then
            for i=1,math.min(#t,4000) do
                local e = t[i]
                if type(e)=="table" and type(e.x)=="number" and type(e.y)=="number" and floor(e.x)==x and floor(e.y)==y then return e end
            end
        end
    end)
    if ok then return e end
    return nil
end
function H.discover(samples)
    H.Det=nil; H.Unknown=false
    local w = Refs.World; if not w or #samples==0 then return false end
    local sm = {}; local step = math.max(1,math.floor(#samples/40))
    for i=1,#samples,step do sm[#sm+1]=samples[i] end
    pcall(function()
        for k,v in pairs(w) do
            if type(v)=="function" then
                local n = string.lower(tostring(k))
                local okName = string.find(n,"ready",1,true) or string.find(n,"grown",1,true)
                    or string.find(n,"ripe",1,true) or string.find(n,"mature",1,true)
                    or (string.find(n,"harvest",1,true) and string.find(n,"^[cih][ans]")~=nil)
                if okName then
                    for _,variant in ipairs({"plain","self","idx"}) do
                        local f
                        if variant=="plain" then f=function(x,y) return v(x,y) end
                        elseif variant=="self" then f=function(x,y) return v(w,x,y) end
                        else f=function(x,y) return v(y*w.w+x) end end
                        local good = true
                        for _,t in ipairs(sm) do local ok,r=pcall(f,t.x,t.y); if not ok or type(r)~="boolean" then good=false; break end end
                        if good then H.Det={ mode="fn", fn=f, name=tostring(k).."() ["..variant.."]" }; return end
                    end
                end
            end
        end
    end)
    if H.Det then return true end
    local cands = {}
    pcall(function()
        for k,v in pairs(w) do
            if type(v)=="table" and k~="fg" and k~="bg" then
                cands[#cands+1]={ name=tostring(k), t=v }
                if #cands<200 then
                    local n=0
                    for k2,v2 in pairs(v) do
                        n=n+1; if n>30 then break end
                        if type(v2)=="table" and type(k2)=="string" then cands[#cands+1]={ name=tostring(k).."."..k2, t=v2 } end
                    end
                end
            end
        end
    end)
    pcall(function() for _,c in ipairs(H.upTables()) do cands[#cands+1]=c end end)
    H.Scores = {}
    local best,bestScore,bestHits = nil, 0, 0
    for _,c in ipairs(cands) do
        local lname = string.lower(c.name)
        local bonus = (string.find(lname,"plant",1,true) or string.find(lname,"tree",1,true)
            or string.find(lname,"seed",1,true) or string.find(lname,"grow",1,true) or string.find(lname,"crop",1,true)) and 0.5 or 0
        local f1 = rawget(c.t,1)
        local r2 = f1 or rawget(c.t,2)
        local isItems = type(r2)=="table" and type(rawget(r2,"name"))=="string"
        local isList = type(f1)=="table" and type(rawget(f1,"x"))=="number" and type(rawget(f1,"y"))=="number"
        for _,mode in ipairs({"idx","xy","yx","xy2","list"}) do
            if not isItems and (mode~="list" or isList) then
                local hits = 0
                for _,t in ipairs(sm) do local e=H.look(c.t,mode,t.x,t.y); if e~=nil and e~=false then hits=hits+1 end end
                if hits>0 then H.Scores[#H.Scores+1] = ("%s [%s] %d/%d"):format(c.name,mode,hits,#sm) end
                local shape = 0
                if hits>0 then
                    for _,t in ipairs(sm) do
                        local e=H.look(c.t,mode,t.x,t.y)
                        if type(e)=="table" and type(rawget(e,"p"))=="number" then shape=1 end
                        break
                    end
                end
                local score = hits + (hits>0 and (bonus+shape) or 0)
                if score>bestScore then best,bestScore,bestHits = { t=c.t, mode=mode, name=c.name.." ["..mode.."]" },score,hits end
            end
        end
    end
    if best and bestHits>=math.max(1,math.floor(#sm*0.6)) then H.Det=best; return true end
    pcall(function()
        local f = w.treeFruit; if type(f)~="function" then return end
        for _,variant in ipairs({"plain","self","idx"}) do
            local g
            if variant=="plain" then g=function(x,y) return f(x,y) end
            elseif variant=="self" then g=function(x,y) return f(w,x,y) end
            else g=function(x,y) return f(y*w.w+x) end end
            local allOk,truthy,falsy = true, 0, 0
            for _,t in ipairs(sm) do
                local ok,r = pcall(g,t.x,t.y); if not ok then allOk=false; break end
                if r==true or (type(r)=="number" and r>0) then truthy=truthy+1 else falsy=falsy+1 end
            end
            if allOk and truthy>0 and falsy>0 then
                H.Det = { mode="fn", name="treeFruit() ["..variant.."]", fn=function(x,y) local r=g(x,y); return r==true or (type(r)=="number" and r>0) end }
                return
            end
        end
    end)
    return H.Det~=nil
end
function H.ready(x,y,id)
    local d = H.Det; if not d then return false end
    if d.mode=="fn" then local ok,r=pcall(d.fn,x,y); return ok and r==true end
    local e = H.look(d.t,d.mode,x,y)
    if e==nil then return false end
    if type(e)=="number" then
        local g = H.growTime(id); if not g then H.Unknown=true; return false end
        return H.nowFor(e)-e>=g
    end
    if type(e)~="table" then H.Unknown=true; return false end
    local flag,readyAt,plantedAt,growF
    pcall(function()
        for k,v in pairs(e) do
            local n = string.lower(tostring(k))
            if type(v)=="boolean" and READY_FLAG[n] then flag=v
            elseif type(v)=="number" then
                if n=="fruit" or n=="fruits" or n=="fruitcount" then flag=v>0
                elseif READY_AT[n] then readyAt=v
                elseif PLANT_AT[n] and not plantedAt then plantedAt=v
                elseif string.find(n,"grow",1,true) or string.find(n,"ripen",1,true) then growF=v end
            end
        end
    end)
    if flag~=nil then return flag end
    if readyAt then return H.nowFor(readyAt)>=readyAt end
    if plantedAt then local g=growF or H.growTime(id); if g then return H.nowFor(plantedAt)-plantedAt>=g+0.3 end end
    H.Unknown = true
    return false
end
function H.isTree(it)
    if type(it)~="table" then return false end
    local k = string.lower(tostring(it.kind))
    if string.find(k,"seed",1,true) or string.find(k,"provider",1,true) or string.find(k,"tree",1,true) or string.find(k,"plant",1,true) or string.find(k,"crop",1,true) then return true end
    local hit = false
    pcall(function()
        for key,v in pairs(it) do
            local n = string.lower(tostring(key))
            if v and (string.find(n,"provider",1,true) or string.find(n,"fruit",1,true) or string.find(n,"harvest",1,true)) then hit=true; break end
        end
    end)
    return hit
end
function H.scan(filterId)
    local w = Refs.World; local out,tally = {}, {}
    if not w then return out,tally end
    for y=0,w.h-1 do
        local row = w.fg[y]
        if row then
            for x=0,w.w-1 do
                local id = row[x]
                if id and id~=0 then
                    local sd = H.SeedCache[id]
                    if sd==nil then local it=ItemDB[id]; sd=H.isTree(it); if type(it)=="table" then H.SeedCache[id]=sd end end
                    if sd then
                        tally[id] = (tally[id] or 0)+1
                        if not filterId or id==filterId then out[#out+1] = { x=x, y=y, id=id } end
                    end
                end
            end
        end
    end
    return out,tally
end
function H.reach()
    local R = 4; local hud = Refs.Hud
    if hud then
        local ok,v = pcall(function() return hud:punchRange() end)
        if not (ok and type(v)=="number") then ok,v=pcall(hud.punchRange) end
        if ok and type(v)=="number" and v>0 then R=v end
    end
    return math.clamp(R,1,8)-0.2
end
function H.standX(s,t,R)
    local by = s.y-0.475; local row = floor(by); local c0 = floor(s.x)
    local dir = (t.x>=c0) and 1 or -1
    local span = abs(t.x-c0)+math.ceil(R)+1
    local fake = { x=0, y=s.y }; local c = c0
    for _=0,span do
        if c~=c0 and not (openAt(c,row) and realSupport(c,row)) then break end
        fake.x = c+0.5
        if stateReaches(fake,t.x,t.y,R) and Move.los(c,row,t.x,t.y) then return c+0.5 end
        c = c+dir
    end
    return nil
end
function H.loop(run)
    say("Harvest berjalan")
    while run() do
        if not gameReady() then say("Belum terhubung..."); connectGame(); task.wait(1); continue end
        if not Drops.list then pcall(findDropRefs) end
        if not Refs.Punch then say("Fungsi pukul game belum ketemu. Tekan Hubungkan."); task.wait(1.5); continue end
        local seeds = H.scan((H.SeedId~=0) and H.SeedId or nil)
        H.Total = #seeds
        if #seeds==0 then
            H.ReadyNow = 0
            say("Tidak ada tanaman "..(H.SeedId==0 and "" or itemName(H.SeedId)).." di world ini")
            task.wait(1.5); continue
        end
        if not H.Det then
            if not H.discover(seeds) then say("Data tanaman belum dikenali."); task.wait(2); continue end
            if H.Toast then H.Toast("Deteksi tanaman: "..H.Det.name) end
        end
        local s = playerState(); if not s then say("Karakter tidak ditemukan"); task.wait(0.5); continue end
        local by,now = s.y-0.475, os.clock()
        H.Unknown = false
        local ready = {}
        for _,t in ipairs(seeds) do
            local key = t.x..","..t.y
            local bad = (H.Failed[key] and now<H.Failed[key]) or (H.Cool[key] and now<H.Cool[key])
            if not bad and H.ready(t.x,t.y,t.id) then ready[#ready+1]=t end
        end
        H.ReadyNow = #ready
        if #ready==0 then
            if H.Unknown then say("Bentuk data tanaman tidak dikenali.")
            else say(("Menunggu tanaman siap (%d tanaman)"):format(#seeds)) end
            task.wait(0.8); continue
        end
        table.sort(ready,function(a,b) return abs(a.x+0.5-s.x)+abs(a.y-by)*0.5 < abs(b.x+0.5-s.x)+abs(b.y-by)*0.5 end)
        local t = ready[1]; local key = t.x..","..t.y
        local R = H.reach(); local sx = H.standX(s,t,R)
        if not sx then H.Failed[key]=now+20; say(("Tanaman (%d,%d) tidak terjangkau"):format(t.x,t.y)); task.wait(); continue end
        local function reaching()
            local s2 = playerState()
            return s2~=nil and stateReaches(s2,t.x,t.y,R) and Move.los(floor(s2.x),floor(s2.y-0.475),t.x,t.y)
        end
        if not reaching() then
            say(("Menuju tanaman (%d,%d)"):format(t.x,t.y))
            walkX(run,sx,0.2,5,reaching)
        end
        if not run() then break end
        if not reaching() then H.Failed[key]=os.clock()+20; say(("Gagal mencapai tanaman (%d,%d)"):format(t.x,t.y)); continue end
        say(("Panen %s (%d,%d)"):format(itemName(t.id),t.x,t.y))
        local done = false
        for i=1,6 do
            if not run() then break end
            if tileAt("fg",t.x,t.y)~=t.id then done=true; break end
            if i>1 and not H.ready(t.x,t.y,t.id) then done=true; break end
            local ok,err = pcall(Refs.Punch,t.x,t.y,State.MutePunch or nil,nil)
            if not ok then say("Error pukul: "..tostring(err)); break end
            if State.Visual then Anim.swing(t.x,t.y,"punch") end
            local waited,limit = 0, math.max(H.Delay,20)/1000
            while waited<limit and run() do
                task.wait(0.02); waited=waited+0.02
                if not H.ready(t.x,t.y,t.id) then done=true; break end
            end
            if done then break end
        end
        if done then
            H.Harvested = H.Harvested+1; Drops.brokeAt[key]=os.clock(); H.Cool[key]=os.clock()+1.5
            Drops.waitSpawn({ { x=t.x, y=t.y } })
            local px,py = getPlayerTile()
            if px then P.HomeX,P.HomeY = px,py end
            collectAll(run,{ x=t.x, y=t.y })
        elseif run() then H.Failed[key]=os.clock()+20 end
        task.wait()
    end
end
function H.start()
    if H.Running then return true end
    if not gameReady() then return false,"Belum terhubung ke game. Tekan Hubungkan." end
    if not H.SeedId then return false,"Pilih seed dulu" end
    if not Refs.Punch then return false,"Fungsi pukul game belum ketemu. Tekan Hubungkan." end
    if not getPlayerTile() then return false,"Karakter tidak ditemukan (belum masuk world?)" end
    H.Running = true; H.RunId = H.RunId+1
    table.clear(H.Failed); table.clear(H.Cool)
    StatusOwner.box = H
    local id = H.RunId
    task.spawn(function()
        local ok,err = pcall(H.loop,function() return H.Running and H.RunId==id and alive() end)
        if not ok then say("Error: "..tostring(err)) end
        if H.RunId==id then
            H.Running=false; releaseInput(); AutoInput.active=false
            if H.OnStop then pcall(H.OnStop) end
        end
    end)
    return true
end
function H.stop(reason)
    if not H.Running then return end
    H.Running=false; H.RunId=H.RunId+1; releaseInput(); AutoInput.active=false
    say(reason or "Berhenti")
    if H.OnStop then pcall(H.OnStop) end
end

-- ============================================================
-- PLANT ENGINE
-- ============================================================
local function alog(s)
    A.Log[#A.Log+1] = ("[%.1f] %s"):format(os.clock(),s)
    if #A.Log>40 then table.remove(A.Log,1) end
end
function A.targets()
    local w = Refs.World; local out = {}
    if not (w and A.BaseId) then return out end
    local now = os.clock()
    for y=1,w.h-1 do
        local base, above = w.fg[y], w.fg[y-1]
        if base and above then
            for x=0,w.w-1 do
                if base[x]==A.BaseId and (above[x] or 0)==0 then
                    local ty = y-1; local key = x..","..ty
                    if not (A.Failed[key] and now<A.Failed[key]) then
                        local c = A.WorkCache[key]
                        if not c or now>c.t then
                            local ok,r = pcall(canWorkAt,x,ty)
                            c = { ok=(not ok) or (r~=false), t=now+3 }; A.WorkCache[key]=c
                        end
                        if c.ok then out[#out+1] = { x=x, y=ty } end
                    end
                end
            end
        end
    end
    return out
end
function A.scanBases()
    local w = Refs.World; local tally, anyFarm = {}, false
    if not w then return tally end
    for y=0,w.h-1 do
        local row = w.fg[y]; local up = (y>0) and w.fg[y-1] or nil
        if row then
            for x=0,w.w-1 do
                local id = row[x]
                if id and id~=0 then
                    local it = ItemDB[id]
                    if type(it)=="table" and it.kind~="seed" and not it.lock and not it.door then
                        local e = tally[id]
                        if not e then
                            e = { n=0, empty=0, farm=it.farmable==true, solid=it.solid==true }
                            tally[id] = e; if e.farm then anyFarm = true end
                        end
                        e.n = e.n+1
                        if up and (up[x] or 0)==0 then e.empty=e.empty+1 end
                    end
                end
            end
        end
    end
    for id,e in pairs(tally) do
        if (anyFarm and not e.farm) or (not anyFarm and not e.solid) then tally[id]=nil end
    end
    return tally
end
function A.reach()
    local R = 4; local hud = Refs.Hud
    if hud then
        local ok,v = pcall(function() return hud:punchRange() end)
        if not (ok and type(v)=="number") then ok,v=pcall(hud.punchRange) end
        if ok and type(v)=="number" and v>0 then R=v end
    end
    return math.clamp(R,1,8)-0.2
end
function A.reaching(s,t,R)
    return s~=nil and stateReaches(s,t.x,t.y,R) and Move.los(floor(s.x),floor(s.y-0.475),t.x,t.y)
end
function A.standX(s,t,R)
    local by = s.y-0.475; local row = floor(by); local c0 = floor(s.x)
    local dir = (t.x>=c0) and 1 or -1
    local span = abs(t.x-c0)+math.ceil(R)+1
    local fake = { x=0, y=s.y }; local c = c0
    for _=0,span do
        if c~=c0 and not (openAt(c,row) and realSupport(c,row)) then break end
        fake.x = c+0.5
        if stateReaches(fake,t.x,t.y,R) and Move.los(c,row,t.x,t.y) then return c+0.5 end
        c = c+dir
    end
    return nil
end
function A.plant(t)
    local id = A.SeedId; local key = t.x..","..t.y
    if tileAt("fg",t.x,t.y)~=0 then return false,"terisi" end
    local n0 = invCount(id)
    sendSetTile("fg",t.x,t.y,id); PlacedAt[key]=os.clock()
    local ok = false
    for _=1,15 do
        task.wait(0.03)
        if tileAt("fg",t.x,t.y)==id then ok=true; break end
    end
    if not ok then return false,"ditolak" end
    if invCount(id)>=n0 and Refs.Inv then pcall(function() Refs.Inv:remove(id,1) end) end
    return true
end
function A.loop(run)
    say("Auto Plant berjalan")
    while run() do
        if not gameReady() then say("Belum terhubung..."); connectGame(); task.wait(1); continue end
        if not (A.SeedId and A.BaseId) then say("Pilih seed dan blok dulu"); task.wait(1); continue end
        if invCount(A.SeedId)<=0 then say("Seed "..itemName(A.SeedId).." habis, berhenti"); return end
        local s = playerState(); if not s then say("Karakter tidak ditemukan"); task.wait(0.5); continue end
        local targets = A.targets(); A.Total = #targets
        if #targets==0 then say("Tidak ada tempat kosong di atas "..itemName(A.BaseId)); task.wait(1.2); continue end
        local by = s.y-0.475; local px,py = floor(s.x), floor(by)
        table.sort(targets,function(a,b)
            local da = abs(a.x+0.5-s.x)+abs(a.y-by)*0.5+((a.x==px and a.y==py) and 100 or 0)
            local db = abs(b.x+0.5-s.x)+abs(b.y-by)*0.5+((b.x==px and b.y==py) and 100 or 0)
            return da<db
        end)
        local R = A.reach(); local t
        for _,c in ipairs(targets) do if A.reaching(s,c,R) then t=c; break end end
        if not t then
            if os.clock()<A.NoPathUntil then task.wait(0.5); continue end
            say("Mencari blok "..itemName(A.BaseId).."...")
            local ok,why = A.navigate(run,targets,R)
            if not run() then break end
            if not ok then
                say((why or "Gagal menuju tempat tanam").." (coba lagi sebentar)")
                A.NoPathUntil = os.clock()+3; task.wait(0.5); continue
            end
            s = playerState()
            for _,c in ipairs(targets) do if A.reaching(s,c,R) then t=c; break end end
            if not t then
                local c = targets[1]; A.Failed[c.x..","..c.y]=os.clock()+20
                say(("Tiba, tapi (%d,%d) belum terjangkau, dilewati"):format(c.x,c.y)); continue
            end
        end
        local ok,why = A.plant(t); local key = t.x..","..t.y
        if ok then
            A.Planted = A.Planted+1; A.Rejected = 0
            say(("Menanam %s (%d,%d)"):format(itemName(A.SeedId),t.x,t.y))
        else
            A.Failed[key]=os.clock()+30
            if why=="ditolak" then
                A.Rejected = A.Rejected+1
                if A.Rejected>=4 then say("Game menolak 4x. Cek izin / blok. Berhenti."); return end
            end
        end
        task.wait(math.max(A.Delay,20)/1000)
    end
end
function A.start()
    if A.Running then return true end
    if not gameReady() then return false,"Belum terhubung ke game. Tekan Hubungkan." end
    if not A.SeedId then return false,"Pilih seed dulu (tekan Pindai)" end
    if not A.BaseId then return false,"Pilih blok tempat menanam dulu" end
    if invCount(A.SeedId)<=0 then return false,"Seed tidak ada di inventori" end
    if not getPlayerTile() then return false,"Karakter tidak ditemukan (belum masuk world?)" end
    A.Running = true; A.RunId = A.RunId+1; A.Rejected = 0; A.NoPathUntil = 0
    table.clear(A.Failed); table.clear(A.WorkCache); table.clear(A.Bad)
    StatusOwner.box = A
    local id = A.RunId
    task.spawn(function()
        local ok,err = pcall(A.loop,function() return A.Running and A.RunId==id and alive() end)
        if not ok then say("Error: "..tostring(err)) end
        if A.RunId==id then
            A.Running=false; releaseInput(); AutoInput.active=false
            if A.OnStop then pcall(A.OnStop) end
        end
    end)
    return true
end
function A.stop(reason)
    if not A.Running then return end
    A.Running=false; A.RunId=A.RunId+1; releaseInput(); AutoInput.active=false
    say(reason or "Berhenti")
    if A.OnStop then pcall(A.OnStop) end
end

-- ============================================================
-- NAVIGATION (dipakai Auto Plant)
-- ============================================================
A.J, A.Dx = 2, 2
A.Cal = { v=false, h=false }
A.Bad = {}
A.NoPathUntil = 0
function A.ctx()
    local w = Refs.World; local W,H = w.w, w.h
    local openM,okM = {}, {}
    local c = { W=W, H=H }
    function c.open(x,y)
        if x<0 or x>=W or y<0 or y>=H then return false end
        local k = y*W+x; local v = openM[k]
        if v==nil then v=openAt(x,y); openM[k]=v end
        return v
    end
    function c.ok(x,y)
        if not c.open(x,y) then return false end
        local k = y*W+x; local v = okM[k]
        if v==nil then v=realSupport(x,y); okM[k]=v end
        return v
    end
    return c
end
function A.plan(sx,sy,goal)
    local c = A.ctx(); local W,H = c.W, c.H
    local J,Dx = A.J, A.Dx
    local now = os.clock(); local useBad = next(A.Bad)~=nil
    local dist,prev = {}, {}
    local hc,hk,hx,hy,n = {}, {}, {}, {}, 0
    local function swap(a,b) hc[a],hc[b]=hc[b],hc[a]; hk[a],hk[b]=hk[b],hk[a]; hx[a],hx[b]=hx[b],hx[a]; hy[a],hy[b]=hy[b],hy[a] end
    local function push(cost,k,x,y)
        n=n+1; local i=n
        hc[i],hk[i],hx[i],hy[i] = cost,k,x,y
        while i>1 do local p=i//2; if hc[p]<=hc[i] then break end; swap(p,i); i=p end
    end
    local function pop()
        local cost,k,x,y = hc[1],hk[1],hx[1],hy[1]
        hc[1],hk[1],hx[1],hy[1] = hc[n],hk[n],hx[n],hy[n]
        hc[n],hk[n],hx[n],hy[n] = nil,nil,nil,nil; n=n-1
        local i=1
        while true do
            local l,r,m = i*2,i*2+1,i
            if l<=n and hc[l]<hc[m] then m=l end
            if r<=n and hc[r]<hc[m] then m=r end
            if m==i then break end
            swap(m,i); i=m
        end
        return cost,k,x,y
    end
    local cd,ck,cx,cy = 0,0,0,0
    local function relax(nx,ny,cost,kind)
        local nk = ny*W+nx
        if useBad then local b=A.Bad[ck..">"..nk]; if b and b>now then return end end
        local nd = cd+cost
        if nd<(dist[nk] or math.huge) then
            dist[nk]=nd; prev[nk]={ k=ck, x=cx, y=cy, kind=kind }
            push(nd,nk,nx,ny)
        end
    end
    local sk = sy*W+sx
    dist[sk] = 0; push(0,sk,sx,sy)
    local pops = 0
    while n>0 do
        cd,ck,cx,cy = pop()
        if cd<=(dist[ck] or math.huge) then
            pops = pops+1; if pops>14000 then break end
            if pops%600==0 then task.wait() end
            if goal(cx,cy) then
                local path,cur = {}, ck
                while cur~=sk do
                    local pv = prev[cur]
                    table.insert(path,1,{ kind=pv.kind, fx=pv.x, fy=pv.y, tx=cur%W, ty=cur//W })
                    cur = pv.k
                end
                return path
            end
            local standing = c.ok(cx,cy)
            for dir=-1,1,2 do
                local nx = cx+dir
                if c.ok(nx,cy) then relax(nx,cy,1,"walk")
                elseif c.open(nx,cy) then
                    for y2=cy+1,math.min(H-1,cy+30) do
                        if not c.open(nx,y2) then break end
                        if c.ok(nx,y2) then relax(nx,y2,1+0.15*(y2-cy),"fall"); break end
                    end
                end
            end
            if standing then
                if platformAt(cx,cy+1) and not solidAt(cx,cy+1) then
                    for y2=cy+1,math.min(H-1,cy+30) do
                        if not c.open(cx,y2) then break end
                        if c.ok(cx,y2) and y2>cy then relax(cx,y2,2+0.15*(y2-cy),"drop"); break end
                    end
                end
                for dy=0,J do
                    local ny = cy-dy
                    if ny>=0 then
                        local clear = true
                        for kk=1,math.max(dy,1) do if not c.open(cx,cy-kk) then clear=false; break end end
                        if clear then
                            for dx=-Dx,Dx do
                                if not (dy==0 and math.abs(dx)<2) then
                                    local nx = cx+dx
                                    if c.ok(nx,ny) then
                                        local sgn = dx>0 and 1 or -1
                                        local good,gap = true, (dy>0)
                                        for i=1,math.abs(dx)-1 do
                                            if not c.open(cx+i*sgn,ny) then good=false; break end
                                            if dy==0 then
                                                if not c.open(cx+i*sgn,ny-1) then good=false; break end
                                                if not c.ok(cx+i*sgn,ny) then gap=true end
                                            end
                                        end
                                        if good and gap then relax(nx,ny,3+dy*0.6+math.abs(dx)*0.3,"jump") end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end
function A.settle(run,maxSec)
    local t0 = os.clock()
    while run() and os.clock()-t0<maxSec do
        local s = playerState(); if s and s.grounded~=false then return s end
        task.wait()
    end
    return playerState()
end
function A.calibrate(run)
    if A.Cal.v and A.Cal.h then return end
    local s = A.settle(run,1); if not s or s.grounded==false then return end
    local x,y = floor(s.x), floor(s.y-0.475)
    if not A.Cal.v then
        local free = true
        for k=1,6 do if not openAt(x,y-k) then free=false; break end end
        if free then
            say("Kalibrasi lompat...")
            walkX(run,x+0.5,0.12,1.5,nil)
            s = playerState()
            if s then
                local y0,minY = s.y, s.y
                AutoInput.active = true; AutoInput.jump = true
                local t0 = os.clock()
                while run() and os.clock()-t0<1.6 do
                    task.wait(); s = playerState(); if not s then break end
                    if s.y<minY then minY=s.y end
                    if s.y>minY+0.05 then AutoInput.jump=false end
                    if os.clock()-t0>0.25 and s.grounded then break end
                end
                releaseInput(); AutoInput.active = false
                local rise = y0-minY
                if rise>0.4 then A.J = math.clamp(math.floor(rise-0.15),1,4); A.Cal.v=true; alog(("kalibrasi naik J=%d"):format(A.J)) end
                A.settle(run,1.5)
            end
        end
    end
    if not A.Cal.h then
        s = playerState(); if not s then return end
        x,y = floor(s.x), floor(s.y-0.475)
        for _,dir in ipairs({1,-1}) do
            local flat = true
            for i=0,6 do
                if not (openAt(x+dir*i,y) and openAt(x+dir*i,y-1) and realSupport(x+dir*i,y)) then flat=false; break end
            end
            if flat then
                say("Kalibrasi jarak lompat...")
                walkX(run,x+0.5,0.12,1.5,nil)
                s = playerState()
                if s then
                    local x0,far = s.x, 0
                    AutoInput.active = true; AutoInput.jump = true
                    AutoInput.left, AutoInput.right = dir<0, dir>0
                    local t0,minY = os.clock(), s.y
                    while run() and os.clock()-t0<2 do
                        task.wait(); s = playerState(); if not s then break end
                        if s.y<minY then minY=s.y end
                        if s.y>minY+0.05 then AutoInput.jump=false end
                        far = math.max(far,(s.x-x0)*dir)
                        if os.clock()-t0>0.25 and s.grounded then break end
                    end
                    releaseInput(); AutoInput.active = false
                    if far>0.8 then A.Dx = math.clamp(math.floor(far),1,5); A.Cal.h=true; alog(("kalibrasi mendatar Dx=%d"):format(A.Dx)) end
                    A.settle(run,1.5)
                end
                break
            end
        end
    end
end
function A.doJump(run,e)
    AutoInput.active = true
    local fxc,destX = e.fx+0.5, e.tx+0.5
    local rise = e.fy-e.ty
    local t0 = os.clock()
    while run() and os.clock()-t0<2 do
        task.wait(); local s = playerState()
        if not s then releaseInput(); AutoInput.active=false; return false end
        steerX(s,fxc,0.12)
        if abs(s.x-fxc)<=0.15 and abs(s.vx or 0)<1 and s.grounded~=false then break end
    end
    AutoInput.left, AutoInput.right = false, false
    AutoInput.jump = true
    local started = os.clock(); local s0 = playerState()
    local minY = s0 and s0.y or 0; local apexed = false
    while run() and os.clock()-started<3 do
        task.wait(); local s = playerState(); if not s then break end
        if s.y<minY then minY=s.y end
        if s.y>minY+0.05 then apexed=true; AutoInput.jump=false end
        local above = s.y<=e.ty+0.85
        if rise>0 and not above and not apexed then AutoInput.left, AutoInput.right = false, false
        else steerX(s,destX,0.1) end
        if os.clock()-started>0.15 and s.grounded then break end
    end
    AutoInput.jump = false
    local s = A.settle(run,1.5)
    if s and s.grounded~=false then walkX(run,destX,0.2,1,nil) end
    releaseInput(); AutoInput.active = false; return true
end
function A.doFall(run,e)
    AutoInput.active = true
    local destX = e.tx+0.5
    local t0 = os.clock()
    while run() and os.clock()-t0<4+0.2*(e.ty-e.fy) do
        task.wait(); local s = playerState(); if not s then break end
        steerX(s,destX,0.1)
        if s.grounded and floor(s.y-0.475)==e.ty and os.clock()-t0>0.1 then break end
    end
    local s = A.settle(run,1)
    if s then walkX(run,destX,0.2,1,nil) end
    releaseInput(); AutoInput.active = false; return true
end
function A.doDrop(run,e)
    AutoInput.active = true
    local t0 = os.clock()
    while run() and os.clock()-t0<1.2 do
        task.wait(); local s = playerState(); if not s then break end
        AutoInput.down = true
        steerX(s,e.fx+0.5,0.15)
        if floor(s.y-0.475)>e.fy then break end
    end
    AutoInput.down = false
    A.doFall(run,e); return true
end
function A.navigate(run,targets,R)
    local W = Refs.World.w
    local tset = {}
    for _,t in ipairs(targets) do tset[t.y*W+t.x] = true end
    local rr = math.ceil(R)
    local fake = { x=0, y=0 }
    local function goal(nx,ny)
        fake.x, fake.y = nx+0.5, ny+1
        for tx=nx-rr,nx+rr do
            for ty=ny-rr,ny+rr do
                if tset[ty*W+tx] and not (tx==nx and ty==ny)
                    and stateReaches(fake,tx,ty,R) and Move.los(nx,ny,tx,ty) then
                    return true
                end
            end
        end
        return false
    end
    for attempt=1,8 do
        if not run() then return false,"dihentikan" end
        local s = A.settle(run,2); if not s then return false,"Karakter tidak ditemukan" end
        if attempt==1 then
            pcall(A.calibrate,run)
            s = A.settle(run,1.5) or playerState()
            if not s then return false,"Karakter tidak ditemukan" end
        end
        local sx,sy = floor(s.x), floor(s.y-0.475)
        local path = A.plan(sx,sy,goal)
        if not path then return false,"Tidak ada jalur ke tempat tanam" end
        if #path==0 then return true end
        say(("Mencari tempat tanam: %d langkah"):format(#path))
        local i,failed = 1, false
        while i<=#path and run() do
            local e = path[i]; local last = i
            if e.kind=="walk" then
                while path[last+1] and path[last+1].kind=="walk" and path[last+1].fy==e.fy do last=last+1 end
                local tgt = path[last]
                walkX(run,tgt.tx+0.5,0.15,1.5+(last-i+1)*0.6,nil)
                e = tgt
            elseif e.kind=="jump" then A.doJump(run,e)
            elseif e.kind=="fall" then A.doFall(run,e)
            else A.doDrop(run,e) end
            local s2 = A.settle(run,1.5); if not s2 then failed=true; break end
            local ax,ay = floor(s2.x), floor(s2.y-0.475)
            if ax==e.tx and ay==e.ty and e.kind=="jump" then A.J = math.min(4,math.max(A.J,e.fy-e.ty)) end
            if ax~=e.tx or ay~=e.ty then
                if e.kind~="walk" then A.Bad[(e.fy*W+e.fx)..">"..(e.ty*W+e.tx)] = os.clock()+20 end
                failed = true; break
            end
            i = last+1
        end
        if not failed then return true end
    end
    return false,"Gagal menuju tempat tanam"
end

-- ============================================================
-- GUI (1 window, 3 pages)
-- ============================================================
local C = {
    bg=Color3.fromRGB(255,255,255), page=Color3.fromRGB(246,247,251), line=Color3.fromRGB(228,231,238),
    text=Color3.fromRGB(30,34,48), sub=Color3.fromRGB(122,129,148), accent=Color3.fromRGB(94,106,255),
    accentHi=Color3.fromRGB(116,127,255), accentSoft=Color3.fromRGB(236,238,255),
    field=Color3.fromRGB(241,243,248), ok=Color3.fromRGB(46,176,120), bad=Color3.fromRGB(230,84,84), white=Color3.fromRGB(255,255,255),
}
local F, FM, FB = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
local function mk(class,props,parent)
    local o = Instance.new(class); for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent = parent end; return o
end
local function corner(o,r) return mk("UICorner",{ CornerRadius=UDim.new(0,r) },o) end
local function stroke(o,color,th,tr) return mk("UIStroke",{ Color=color, Thickness=th or 1, Transparency=tr or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border },o) end
local function pad(o,l,t,r,b) return mk("UIPadding",{ PaddingLeft=UDim.new(0,l), PaddingTop=UDim.new(0,t), PaddingRight=UDim.new(0,r or l), PaddingBottom=UDim.new(0,b or t) },o) end
local function list(o,gap,dir) return mk("UIListLayout",{ Padding=UDim.new(0,gap or 8), SortOrder=Enum.SortOrder.LayoutOrder, FillDirection=dir or Enum.FillDirection.Vertical },o) end
local function label(parent,props)
    local p = { BackgroundTransparency=1, Font=F, TextColor3=C.text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, BorderSizePixel=0 }
    for k,v in pairs(props or {}) do p[k]=v end
    return mk("TextLabel",p,parent)
end
local function hover(btn,n,o) btn.MouseEnter:Connect(function() btn.BackgroundColor3=o end); btn.MouseLeave:Connect(function() btn.BackgroundColor3=n end) end
local function button(parent,text,props,primary)
    local base = primary and C.accent or C.field
    local p = { Size=UDim2.new(0,120,0,36), BackgroundColor3=base, AutoButtonColor=false, Text=text, Font=FM, TextSize=13, TextColor3=primary and C.white or C.text, BorderSizePixel=0 }
    for k,v in pairs(props or {}) do p[k]=v end
    local b = mk("TextButton",p,parent); corner(b,10); hover(b,base,primary and C.accentHi or C.line); return b
end
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
local Gui = mk("ScreenGui",{ Name="KNEAR_AIO", ResetOnSpawn=false, DisplayOrder=100, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling })
if syn and syn.protect_gui then pcall(syn.protect_gui,Gui) end
if not pcall(function() Gui.Parent=guiParent end) or not Gui.Parent then Gui.Parent = PlayerGui end

local toastBox = mk("Frame",{ AnchorPoint=Vector2.new(0.5,1), Position=UDim2.new(0.5,0,1,-24), Size=UDim2.fromOffset(0,0), BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.XY },Gui)
list(toastBox,6)
local function toast(text)
    local t = mk("Frame",{ BackgroundColor3=C.text, AutomaticSize=Enum.AutomaticSize.XY, BorderSizePixel=0 },toastBox)
    corner(t,10); pad(t,14,9)
    label(t,{ AutomaticSize=Enum.AutomaticSize.XY, Text=text, TextColor3=C.white, TextSize=13, Font=FM })
    task.delay(2.6,function() pcall(function() t:Destroy() end) end)
end

local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(900,600)
local WIN_W = math.min(640, vp.X-24); local WIN_H = math.min(430, vp.Y-24); local SIDE_W = (WIN_W<520) and 112 or 140
local Shadow = mk("Frame",{ AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,4), Size=UDim2.fromOffset(WIN_W+10,WIN_H+10), BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.88, BorderSizePixel=0 },Gui)
corner(Shadow,20)
local Main = mk("Frame",{ AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.fromOffset(WIN_W,WIN_H), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true },Gui)
corner(Main,16); stroke(Main,C.line,1)

-- Header
local Header = mk("Frame",{ Size=UDim2.new(1,0,0,60), BackgroundColor3=C.bg, BorderSizePixel=0 },Main)
local Logo = mk("Frame",{ Position=UDim2.fromOffset(16,12), Size=UDim2.fromOffset(38,38), BackgroundColor3=C.accentSoft, BorderSizePixel=0 },Header); corner(Logo,10)
local LogoText = label(Logo,{ Size=UDim2.fromScale(1,1), Text="K", Font=FB, TextSize=18, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Center })
local LogoImg = mk("ImageLabel",{ Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Image="", ScaleType=Enum.ScaleType.Crop, Visible=false, BorderSizePixel=0 },Logo); corner(LogoImg,10)
label(Header,{ Position=UDim2.fromOffset(64,11), Size=UDim2.fromOffset(200,22), Text="K NEAR AIO", Font=FB, TextSize=18 })
label(Header,{ Position=UDim2.fromOffset(64,32), Size=UDim2.fromOffset(200,18), Text="PNB · Harvest · Plant", TextSize=12, TextColor3=C.sub })
local CloseBtn = button(Header,"X",{ Size=UDim2.fromOffset(32,32), Position=UDim2.new(1,-44,0,14), TextSize=13 })
local MinBtn  = button(Header,"-",{ Size=UDim2.fromOffset(32,32), Position=UDim2.new(1,-82,0,14), TextSize=18 })
local DcBtn   = button(Header,"Discord",{ Size=UDim2.fromOffset(84,32), Position=UDim2.new(1,-176,0,14), BackgroundColor3=C.accentSoft, TextColor3=C.accent, TextSize=13 })
hover(DcBtn,C.accentSoft,Color3.fromRGB(224,228,255))
if WIN_W<420 then DcBtn.Visible=false end
mk("Frame",{ Position=UDim2.fromOffset(0,60), Size=UDim2.new(1,0,0,1), BackgroundColor3=C.line, BorderSizePixel=0 },Main)

-- Body
local Body = mk("Frame",{ Position=UDim2.fromOffset(0,61), Size=UDim2.new(1,0,1,-61), BackgroundTransparency=1 },Main)
local Content = mk("Frame",{ Size=UDim2.new(1,-SIDE_W,1,0), BackgroundColor3=C.page, BorderSizePixel=0 },Body)
local Side = mk("Frame",{ AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0,SIDE_W,1,0), BackgroundColor3=C.bg, BorderSizePixel=0 },Body)
mk("Frame",{ Size=UDim2.new(0,1,1,0), BackgroundColor3=C.line, BorderSizePixel=0 },Side)
label(Side,{ Position=UDim2.fromOffset(16,12), Size=UDim2.new(1,-24,0,16), Text="MENU", Font=FB, TextSize=11, TextColor3=C.sub })
local SideList = mk("Frame",{ Position=UDim2.fromOffset(10,36), Size=UDim2.new(1,-20,1,-86), BackgroundTransparency=1 },Side); list(SideList,6)
local Footer = mk("Frame",{ AnchorPoint=Vector2.new(0,1), Position=UDim2.new(0,0,1,0), Size=UDim2.new(1,0,0,40), BackgroundTransparency=1 },Side)
label(Footer,{ Position=UDim2.fromOffset(12,4), Size=UDim2.new(1,-24,0,14), Text="RS/RC/RA = sembunyi", TextSize=11, TextColor3=C.sub })
label(Footer,{ Position=UDim2.fromOffset(12,18), Size=UDim2.new(1,-24,0,14), Text="Tombol '-' = minimize", TextSize=11, TextColor3=C.sub })

local Pages, MenuBtns = {}, {}
local function newPage(name)
    local sf = mk("ScrollingFrame",{ Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.line, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false },Content)
    pad(sf,14,14,14,14); list(sf,12); Pages[name]=sf; return sf
end
local function showPage(name)
    for n,pg in pairs(Pages) do pg.Visible = (n==name) end
    for n,b in pairs(MenuBtns) do
        local on = (n==name)
        b.BackgroundColor3 = on and C.accentSoft or C.bg
        b.TextColor3 = on and C.accent or C.sub
        b.Font = on and FB or FM
    end
end
local function menuItem(name,text)
    local b = mk("TextButton",{ Size=UDim2.new(1,0,0,38), BackgroundColor3=C.bg, AutoButtonColor=false, Text=text, Font=FM, TextSize=14, TextColor3=C.sub, BorderSizePixel=0 },SideList)
    corner(b,10); b.MouseButton1Click:Connect(function() showPage(name) end); MenuBtns[name]=b
end
local function card(parent,title,sub)
    local c = mk("Frame",{ Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=C.bg, BorderSizePixel=0 },parent)
    corner(c,14); stroke(c,C.line,1); pad(c,16,14); list(c,10)
    if title then
        local h = mk("Frame",{ Size=UDim2.new(1,0,0, sub and 38 or 20), BackgroundTransparency=1 },c)
        label(h,{ Size=UDim2.new(1,0,0,20), Text=title, Font=FB, TextSize=15 })
        if sub then label(h,{ Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,0,0,16), Text=sub, TextSize=12, TextColor3=C.sub }) end
    end
    return c
end
local function checkbox(parent,title,desc,initial,onChange,width)
    local row = mk("TextButton",{ Size=UDim2.new(width or 1,0,0, desc and 46 or 28), BackgroundTransparency=1, Text="", AutoButtonColor=false, BorderSizePixel=0 },parent)
    local box = mk("Frame",{ Position=UDim2.new(0,0,0,desc and 2 or 2), Size=UDim2.fromOffset(24,24), BackgroundColor3=C.bg, BorderSizePixel=0 },row)
    corner(box,7); local st = stroke(box,C.line,1.5)
    local a1 = mk("Frame",{ AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromOffset(9,14), Size=UDim2.fromOffset(7,2.6), Rotation=45, BackgroundColor3=C.white, BorderSizePixel=0, Visible=false },box); corner(a1,2)
    local a2 = mk("Frame",{ AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromOffset(14.5,11.5), Size=UDim2.fromOffset(13,2.6), Rotation=-50, BackgroundColor3=C.white, BorderSizePixel=0, Visible=false },box); corner(a2,2)
    label(row,{ Position=UDim2.fromOffset(34,0), Size=UDim2.new(1,-34,0,22), Text=title, Font=FM, TextSize=14 })
    if desc then label(row,{ Position=UDim2.fromOffset(34,22), Size=UDim2.new(1,-34,0,18), Text=desc, TextSize=12, TextColor3=C.sub }) end
    local state = initial and true or false
    local api = {}
    local function render()
        box.BackgroundColor3 = state and C.accent or C.bg
        st.Color = state and C.accent or C.line
        a1.Visible, a2.Visible = state, state
    end
    function api.set(v,silent) state = v and true or false; render(); if not silent and onChange then onChange(state) end end
    function api.get() return state end
    row.MouseButton1Click:Connect(function() api.set(not state) end)
    render(); return api,row
end
local function field(parent,placeholder,text,props)
    local p = { Size=UDim2.new(1,0,0,36), BackgroundColor3=C.field, BorderSizePixel=0, Text=text or "", PlaceholderText=placeholder or "", Font=FM, TextSize=13, TextColor3=C.text, PlaceholderColor3=C.sub, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left }
    for k,v in pairs(props or {}) do p[k]=v end
    local t = mk("TextBox",p,parent); corner(t,10); pad(t,12,0); return t
end

-- ====== Page: PNB ======
menuItem("pnb","PNB")
local PagePNB = newPage("pnb")
local c1 = card(PagePNB)
local cbPNB
cbPNB = checkbox(c1,"Aktifkan PNB","Put & break otomatis, item diambil sebelum block berikutnya",false,function(on)
    if on then local ok,err = P.start(); if not ok then toast(err or "Gagal mulai"); cbPNB.set(false,true) end
    else P.stop("Dimatikan") end
end)
P.OnStop = function() cbPNB.set(false,true) end

local cBlock = card(PagePNB,"Block yang di-break","Pilih block dari inventori")
local bTop = mk("Frame",{ Size=UDim2.new(1,0,0,38), BackgroundTransparency=1 },cBlock)
local selBtn = mk("TextButton",{ Size=UDim2.new(1,-96,1,0), BackgroundColor3=C.field, AutoButtonColor=false, Text="", BorderSizePixel=0 },bTop); corner(selBtn,10)
local selText = label(selBtn,{ Position=UDim2.fromOffset(12,0), Size=UDim2.new(1,-70,1,0), Text="Pilih block...", Font=FM, TextSize=13 })
label(selBtn,{ AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-12,0,0), Size=UDim2.fromOffset(50,38), Text="Ubah", Font=FM, TextSize=12, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Right })
local refreshBtn = button(bTop,"Muat ulang",{ Size=UDim2.fromOffset(88,38), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextSize=12 })
local blockList = mk("ScrollingFrame",{ Size=UDim2.new(1,0,0,150), BackgroundColor3=C.field, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.line, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false },cBlock); corner(blockList,10); pad(blockList,6,6); list(blockList,4)
local function blockLabel(id) return string.format("%s   x%d", itemName(id), invCount(id)) end
local function setBlock(id) P.BlockId = id; selText.Text = id and blockLabel(id) or "Pilih block..."; selText.TextColor3 = id and C.text or C.sub end
local function populateBlocks()
    for _,ch in ipairs(blockList:GetChildren()) do if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end end
    local ids = {}; pcall(function() ids = placeableIds() end)
    if #ids==0 then label(blockList,{ Size=UDim2.new(1,0,0,30), Text=gameReady() and "Inventori kosong" or "Belum terhubung", TextColor3=C.sub, TextSize=13, TextXAlignment=Enum.TextXAlignment.Center }) end
    for _,id in ipairs(ids) do
        local b = mk("TextButton",{ Size=UDim2.new(1,0,0,32), BackgroundColor3=(id==P.BlockId) and C.accentSoft or C.bg, AutoButtonColor=false, Text="", BorderSizePixel=0 },blockList); corner(b,8)
        label(b,{ Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-20,1,0), Text=blockLabel(id), Font=FM, TextSize=13, TextColor3=(id==P.BlockId) and C.accent or C.text })
        b.MouseButton1Click:Connect(function() setBlock(id); blockList.Visible=false end)
    end
end
selBtn.MouseButton1Click:Connect(function() if not blockList.Visible then populateBlocks() end; blockList.Visible = not blockList.Visible end)
refreshBtn.MouseButton1Click:Connect(function() task.spawn(function() if not gameReady() then connectGame() end; populateBlocks(); if P.BlockId then setBlock(P.BlockId) end; blockList.Visible=true end) end)

local cPos = card(PagePNB,"Posisi break","Tempat karakter berdiri saat PNB")
local posLabel = label(cPos,{ Size=UDim2.new(1,0,0,20), Text="Belum ditentukan (otomatis posisi saat mulai)", TextSize=13, TextColor3=C.sub })
local posRow = mk("Frame",{ Size=UDim2.new(1,0,0,38), BackgroundTransparency=1 },cPos)
local setHereBtn = button(posRow,"Set di posisi saya",{ Size=UDim2.new(0.5,-4,1,0) },true)
local clearPosBtn = button(posRow,"Hapus posisi",{ Size=UDim2.new(0.5,-4,1,0), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
local xyRow = mk("Frame",{ Size=UDim2.new(1,0,0,38), BackgroundTransparency=1 },cPos)
local xyBox = field(xyRow,"Custom X,Y  (contoh 50,30)","",{ Size=UDim2.new(1,-96,1,0) })
local xyBtn = button(xyRow,"Terapkan",{ Size=UDim2.fromOffset(88,38), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
local function updatePosLabel()
    if P.HomeX then posLabel.Text = ("Posisi break:  X %d,  Y %d"):format(P.HomeX,P.HomeY or 0); posLabel.TextColor3 = C.text
    else posLabel.Text = "Belum ditentukan (otomatis posisi saat mulai)"; posLabel.TextColor3 = C.sub end
end
setHereBtn.MouseButton1Click:Connect(function()
    local x,y = getPlayerTile(); if not x then toast("Karakter tidak ditemukan") return end
    P.HomeX, P.HomeY = x,y; updatePosLabel(); toast(("Posisi: %d,%d"):format(x,y))
end)
clearPosBtn.MouseButton1Click:Connect(function() P.HomeX, P.HomeY = nil, nil; xyBox.Text=""; updatePosLabel() end)
xyBtn.MouseButton1Click:Connect(function()
    local a,b = string.match(xyBox.Text,"^%s*(%d+)%s*[,; ]%s*(%d+)%s*$")
    if not a then toast("Format salah, contoh: 50,30") return end
    P.HomeX, P.HomeY = tonumber(a),tonumber(b); updatePosLabel(); toast(("Posisi: %s,%s"):format(a,b))
end)
label(cPos,{ Size=UDim2.new(1,0,0,20), Text="Arah break  (x = block, P = karakter)", Font=FM, TextSize=13 })
local preview = label(cPos,{ Size=UDim2.new(1,0,0,44), Text="", Font=Enum.Font.Code, TextSize=16, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Center, TextYAlignment=Enum.TextYAlignment.Center })
local function updatePreview()
    local l = P.Left and "x" or "."; local r = P.Right and "x" or "."; local u = P.Up and "x" or "."
    preview.Text = ("    %s\n%s P %s"):format(u,l,r)
end
local dirRow = mk("Frame",{ Size=UDim2.new(1,0,0,28), BackgroundTransparency=1 },cPos); list(dirRow,6,Enum.FillDirection.Horizontal)
checkbox(dirRow,"Kiri",nil,P.Left,function(v) P.Left=v; updatePreview() end,0.32)
checkbox(dirRow,"Kanan",nil,P.Right,function(v) P.Right=v; updatePreview() end,0.32)
checkbox(dirRow,"Atas",nil,P.Up,function(v) P.Up=v; updatePreview() end,0.32)

local cSetP = card(PagePNB,"Pengaturan")
checkbox(cSetP,"Auto collect cepat","Ambil item di tile PNB & radius sebelum block berikutnya dipasang",P.Fast,function(v) P.Fast=v end)
checkbox(cSetP,"Ambil item pakai karakter","Cadangan: karakter jalan ke item yang tidak terjangkau",P.Collect,function(v) P.Collect=v end)
local radRowP = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cSetP)
label(radRowP,{ Size=UDim2.new(1,-110,1,0), Text="Radius collect (tile)", Font=FM, TextSize=14 })
local radBoxP = field(radRowP,"3",tostring(P.Radius),{ Size=UDim2.fromOffset(100,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextXAlignment=Enum.TextXAlignment.Center })
radBoxP.FocusLost:Connect(function() local n=tonumber(radBoxP.Text); P.Radius=math.clamp(math.floor(n or P.Radius),1,5); radBoxP.Text=tostring(P.Radius) end)
checkbox(cSetP,"Animasi tangan","Tampilan memukul / memasang block",State.Visual,function(v) State.Visual=v end)
local delayRowP = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cSetP)
label(delayRowP,{ Size=UDim2.new(1,-110,1,0), Text="Jeda pukul (ms)", Font=FM, TextSize=14 })
local delayBoxP = field(delayRowP,"120",tostring(P.PunchMs),{ Size=UDim2.fromOffset(100,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextXAlignment=Enum.TextXAlignment.Center })
delayBoxP.FocusLost:Connect(function() local n=tonumber(delayBoxP.Text); P.PunchMs=math.clamp(math.floor(n or P.PunchMs),40,1000); delayBoxP.Text=tostring(P.PunchMs) end)

local cStatP = card(PagePNB,"Status")
local statLabelP = label(cStatP,{ Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Text="Siap", TextWrapped=true, TextSize=13, Font=FM })
local numLabelP = label(cStatP,{ Size=UDim2.new(1,0,0,18), Text="", TextSize=12, TextColor3=C.sub })
local connRowP = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cStatP)
local connLabelP = label(connRowP,{ Size=UDim2.new(1,-120,1,0), Text="", Font=FM, TextSize=13 })
local connBtnP = button(connRowP,"Hubungkan",{ Size=UDim2.fromOffset(110,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
connBtnP.MouseButton1Click:Connect(function()
    connLabelP.Text = "Menghubungkan..."
    task.spawn(function() local ok = connectGame(); toast(ok and "Terhubung ke game" or "Gagal, pastikan sudah masuk world"); populateBlocks() end)
end)

-- ====== Page: HARVEST ======
menuItem("harvest","Harvest")
local PageH = newPage("harvest")
local c1H = card(PageH)
local cbH
cbH = checkbox(c1H,"Aktifkan Harvest","Otomatis mendeteksi & memanen tanaman yang sudah siap",false,function(on)
    if on then local ok,err = H.start(); if not ok then toast(err or "Gagal mulai"); cbH.set(false,true) end
    else H.stop("Dimatikan") end
end)
H.OnStop = function() cbH.set(false,true) end
H.Toast = toast

local cSeed = card(PageH,"Seed yang dipanen","Pilih jenis seed yang ditanam di world (contoh: Lava Seed)")
local sTop = mk("Frame",{ Size=UDim2.new(1,0,0,38), BackgroundTransparency=1 },cSeed)
local selSeed = mk("TextButton",{ Size=UDim2.new(1,-96,1,0), BackgroundColor3=C.field, AutoButtonColor=false, Text="", BorderSizePixel=0 },sTop); corner(selSeed,10)
local selSeedText = label(selSeed,{ Position=UDim2.fromOffset(12,0), Size=UDim2.new(1,-70,1,0), Text="Pilih seed...", Font=FM, TextSize=13 })
label(selSeed,{ AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-12,0,0), Size=UDim2.fromOffset(50,38), Text="Ubah", Font=FM, TextSize=12, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Right })
local scanBtn = button(sTop,"Pindai",{ Size=UDim2.fromOffset(88,38), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextSize=12 })
local seedList = mk("ScrollingFrame",{ Size=UDim2.new(1,0,0,150), BackgroundColor3=C.field, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.line, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false },cSeed); corner(seedList,10); pad(seedList,6,6); list(seedList,4)
local seedCounts = {}
local function seedLabel(id)
    if id==0 then return "SEMUA pohon di world" end
    local n = seedCounts[id] or 0
    if n==0 then return string.format("%s   (belum ada di world)", itemName(id)) end
    return string.format("%s   x%d tanaman", itemName(id), n)
end
local function setSeed(id) H.SeedId = id; table.clear(H.Failed); table.clear(H.Cool); selSeedText.Text = id and seedLabel(id) or "Pilih seed..."; selSeedText.TextColor3 = id and C.text or C.sub end
local function populateSeeds()
    for _,ch in ipairs(seedList:GetChildren()) do if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end end
    seedCounts = {}
    if gameReady() then
        local ok,_,tally = pcall(H.scan,nil)
        if ok and type(tally)=="table" then seedCounts = tally end
        pcall(function() for _,id in ipairs(UI.invSlotIds()) do local it=ItemDB[id]; if type(it)=="table" and it.kind=="seed" and not seedCounts[id] then seedCounts[id]=0 end end end)
    end
    local ids = {}; for id in pairs(seedCounts) do ids[#ids+1]=id end; table.sort(ids)
    if #ids>0 then table.insert(ids,1,0) end
    if #ids==0 then label(seedList,{ Size=UDim2.new(1,0,0,30), Text=gameReady() and "Tidak ada seed tertanam" or "Belum terhubung", TextColor3=C.sub, TextSize=13, TextXAlignment=Enum.TextXAlignment.Center }) end
    for _,id in ipairs(ids) do
        local b = mk("TextButton",{ Size=UDim2.new(1,0,0,32), BackgroundColor3=(id==H.SeedId) and C.accentSoft or C.bg, AutoButtonColor=false, Text="", BorderSizePixel=0 },seedList); corner(b,8)
        label(b,{ Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-20,1,0), Text=seedLabel(id), Font=FM, TextSize=13, TextColor3=(id==H.SeedId) and C.accent or C.text })
        b.MouseButton1Click:Connect(function() setSeed(id); seedList.Visible=false end)
    end
end
selSeed.MouseButton1Click:Connect(function() if not seedList.Visible then populateSeeds() end; seedList.Visible = not seedList.Visible end)
scanBtn.MouseButton1Click:Connect(function() task.spawn(function() if not gameReady() then connectGame() end; populateSeeds(); if H.SeedId then setSeed(H.SeedId) end; seedList.Visible=true end) end)

local cSetH = card(PageH,"Pengaturan")
checkbox(cSetH,"Auto collect cepat","Ambil drop panen langsung (remote) sebelum lanjut",P.Fast,function(v) P.Fast=v end)
checkbox(cSetH,"Ambil item pakai karakter","Cadangan: karakter jalan ke drop yang tidak terjangkau",P.Collect,function(v) P.Collect=v end)
local radRowH = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cSetH)
label(radRowH,{ Size=UDim2.new(1,-110,1,0), Text="Radius collect (tile)", Font=FM, TextSize=14 })
local radBoxH = field(radRowH,"3",tostring(P.Radius),{ Size=UDim2.fromOffset(100,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextXAlignment=Enum.TextXAlignment.Center })
radBoxH.FocusLost:Connect(function() local n=tonumber(radBoxH.Text); P.Radius=math.clamp(math.floor(n or P.Radius),1,5); radBoxH.Text=tostring(P.Radius) end)
checkbox(cSetH,"Animasi tangan","Tampilan memukul tanaman",State.Visual,function(v) State.Visual=v end)
local dRowH = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cSetH)
label(dRowH,{ Size=UDim2.new(1,-110,1,0), Text="Jeda pukul (ms)", Font=FM, TextSize=14 })
local dBoxH = field(dRowH,"100",tostring(H.Delay),{ Size=UDim2.fromOffset(100,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextXAlignment=Enum.TextXAlignment.Center })
dBoxH.FocusLost:Connect(function() H.Delay=math.clamp(math.floor(tonumber(dBoxH.Text) or H.Delay),20,1000); dBoxH.Text=tostring(H.Delay) end)

local cStatH = card(PageH,"Status")
local statLabelH = label(cStatH,{ Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Text="Siap", TextWrapped=true, TextSize=13, Font=FM })
local numLabelH = label(cStatH,{ Size=UDim2.new(1,0,0,18), Text="", TextSize=12, TextColor3=C.sub })
local detLabelH = label(cStatH,{ Size=UDim2.new(1,0,0,18), Text="", TextSize=12, TextColor3=C.sub })
local connRowH = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cStatH)
local connLabelH = label(connRowH,{ Size=UDim2.new(1,-120,1,0), Text="", Font=FM, TextSize=13 })
local connBtnH = button(connRowH,"Hubungkan",{ Size=UDim2.fromOffset(110,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
connBtnH.MouseButton1Click:Connect(function()
    connLabelH.Text = "Menghubungkan..."
    task.spawn(function() local ok = connectGame(); toast(ok and "Terhubung ke game" or "Gagal"); populateSeeds() end)
end)

-- ====== Page: PLANT ======
menuItem("plant","Auto Plant")
local PageA = newPage("plant")
local c1A = card(PageA)
local cbA
cbA = checkbox(c1A,"Aktifkan Auto Plant","Otomatis menanam seed di atas blok yang dipilih",false,function(on)
    if on then local ok,err = A.start(); if not ok then toast(err or "Gagal mulai"); cbA.set(false,true) end
    else A.stop("Dimatikan") end
end)
A.OnStop = function() cbA.set(false,true) end
A.Toast = toast

-- Generic picker for Plant
local function picker(parent,placeholder,btnText,fetch,onPick,labelOf)
    local api = { id=nil }
    local top = mk("Frame",{ Size=UDim2.new(1,0,0,38), BackgroundTransparency=1 },parent)
    local sel = mk("TextButton",{ Size=UDim2.new(1,-96,1,0), BackgroundColor3=C.field, AutoButtonColor=false, Text="", BorderSizePixel=0 },top); corner(sel,10)
    local selT = label(sel,{ Position=UDim2.fromOffset(12,0), Size=UDim2.new(1,-70,1,0), Text=placeholder, Font=FM, TextSize=13, TextColor3=C.sub })
    label(sel,{ AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-12,0,0), Size=UDim2.fromOffset(50,38), Text="Ubah", Font=FM, TextSize=12, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Right })
    local btn = button(top,btnText,{ Size=UDim2.fromOffset(88,38), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextSize=12 })
    local box = mk("ScrollingFrame",{ Size=UDim2.new(1,0,0,150), BackgroundColor3=C.field, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.line, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false },parent); corner(box,10); pad(box,6,6); list(box,4)
    function api.refresh()
        if api.id then selT.Text = labelOf(api.id); selT.TextColor3=C.text
        else selT.Text = placeholder; selT.TextColor3 = C.sub end
    end
    function api.set(id) api.id = id; onPick(id); api.refresh() end
    function api.populate()
        for _,ch in ipairs(box:GetChildren()) do if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end end
        local ids = {}; pcall(function() ids = fetch() end)
        if #ids==0 then label(box,{ Size=UDim2.new(1,0,0,30), Text=gameReady() and "Tidak ada" or "Belum terhubung", TextColor3=C.sub, TextSize=13, TextXAlignment=Enum.TextXAlignment.Center }) end
        for _,id in ipairs(ids) do
            local b = mk("TextButton",{ Size=UDim2.new(1,0,0,32), BackgroundColor3=(id==api.id) and C.accentSoft or C.bg, AutoButtonColor=false, Text="", BorderSizePixel=0 },box); corner(b,8)
            label(b,{ Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-20,1,0), Text=labelOf(id), Font=FM, TextSize=13, TextColor3=(id==api.id) and C.accent or C.text })
            b.MouseButton1Click:Connect(function() api.set(id); box.Visible=false end)
        end
    end
    sel.MouseButton1Click:Connect(function() if not box.Visible then api.populate() end; box.Visible = not box.Visible end)
    btn.MouseButton1Click:Connect(function() task.spawn(function() if not gameReady() then connectGame() end; api.populate(); api.refresh(); box.Visible=true end) end)
    return api
end

local cSeedA = card(PageA,"Seed yang ditanam","Tekan Pindai untuk memilih seed dari inventori")
local seedPickA = picker(cSeedA,"Pilih seed...","Pindai",function()
    local ids = {}
    for _,id in ipairs(UI.invSlotIds()) do local it = ItemDB[id]; if type(it)=="table" and it.kind=="seed" then ids[#ids+1]=id end end
    table.sort(ids); return ids
end,function(id) A.SeedId = id end,function(id) return string.format("%s   x%d", itemName(id), invCount(id)) end)

local baseInfo = {}
local cBaseA = card(PageA,"Tanam di atas blok","Seed hanya ditanam di tile kosong tepat di atas blok ini (mis. Dirt)")
local basePickA = picker(cBaseA,"Pilih blok...","Pindai",function()
    baseInfo = A.scanBases(); local ids = {}
    for id in pairs(baseInfo) do ids[#ids+1]=id end; table.sort(ids); return ids
end,function(id) A.BaseId = id; table.clear(A.Failed); table.clear(A.WorkCache) end,function(id)
    local e = baseInfo[id]
    if e then return string.format("%s   x%d blok, %d tempat kosong", itemName(id), e.n, e.empty) end
    return itemName(id)
end)

local cSetA = card(PageA,"Pengaturan")
checkbox(cSetA,"Animasi tangan","Tampilan menaruh seed",State.Visual,function(v) State.Visual=v end)
local dRowA = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cSetA)
label(dRowA,{ Size=UDim2.new(1,-110,1,0), Text="Jeda tanam (ms)", Font=FM, TextSize=14 })
local dBoxA = field(dRowA,"100",tostring(A.Delay),{ Size=UDim2.fromOffset(100,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), TextXAlignment=Enum.TextXAlignment.Center })
dBoxA.FocusLost:Connect(function() A.Delay=math.clamp(math.floor(tonumber(dBoxA.Text) or A.Delay),20,1000); dBoxA.Text=tostring(A.Delay) end)

local cStatA = card(PageA,"Status")
local statLabelA = label(cStatA,{ Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Text="Siap", TextWrapped=true, TextSize=13, Font=FM })
local numLabelA = label(cStatA,{ Size=UDim2.new(1,0,0,18), Text="", TextSize=12, TextColor3=C.sub })
local connRowA = mk("Frame",{ Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 },cStatA)
local connLabelA = label(connRowA,{ Size=UDim2.new(1,-120,1,0), Text="", Font=FM, TextSize=13 })
local connBtnA = button(connRowA,"Hubungkan",{ Size=UDim2.fromOffset(110,36), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
connBtnA.MouseButton1Click:Connect(function() connLabelA.Text="Menghubungkan..."; task.spawn(function() local ok = connectGame(); toast(ok and "Terhubung ke game" or "Gagal") end) end)

showPage("pnb"); updatePreview(); updatePosLabel(); setBlock(nil)

-- ====== Minimize / hide / drag ======
local Mini = mk("ImageButton",{ Size=UDim2.fromOffset(48,48), Position=UDim2.fromOffset(16,120), BackgroundColor3=C.bg, BorderSizePixel=0, Visible=false, AutoButtonColor=false, Image="", ScaleType=Enum.ScaleType.Crop },Gui); corner(Mini,14); stroke(Mini,C.line,1)
local MiniText = label(Mini,{ Size=UDim2.fromScale(1,1), Text="K", Font=FB, TextSize=20, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Center })
local function setHidden(h) Main.Visible = not h; Shadow.Visible = not h; Mini.Visible = h end
MinBtn.MouseButton1Click:Connect(function() setHidden(true) end)
Mini.MouseButton1Click:Connect(function() setHidden(false) end)
table.insert(Connections, UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setHidden(Main.Visible)
    elseif input.KeyCode == Enum.KeyCode.RightControl then setHidden(Main.Visible)
    elseif input.KeyCode == Enum.KeyCode.RightAlt then setHidden(Main.Visible) end
end))
do
    local dragging,dragStart,startPos = false,nil,nil
    Header.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging,dragStart,startPos = true,i.Position,Main.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position-dragStart
            local np = UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            Main.Position = np; Shadow.Position = UDim2.new(np.X.Scale,np.X.Offset,np.Y.Scale,np.Y.Offset+4)
        end
    end))
end

-- Logo (async)
task.spawn(function()
    local img
    pcall(function()
        local data = game:HttpGet(LOGO_URL)
        local name = "knear_logo_aio.png"
        writefile(name,data)
        img = getcustomasset(name)
    end)
    if img and alive() then
        LogoImg.Image = img; LogoImg.Visible = true; LogoText.Visible = false
        Mini.Image = img; MiniText.Visible = false
    end
end)

-- Discord button
local function copyDiscord() local ok = pcall(function() setclipboard(DISCORD_URL) end); toast(ok and "Link Discord disalin" or DISCORD_URL) end
DcBtn.MouseButton1Click:Connect(copyDiscord)

-- ====== Periodic UI refresh ======
do
    local last = 0
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now-last<0.25 or not alive() then return end
        last = now
        -- PNB
        statLabelP.Text = P.Status
        numLabelP.Text = ("Put %d | Break %d | Item %d"):format(P.Put,P.Broke,P.Got)
        -- Harvest
        statLabelH.Text = H.Status
        numLabelH.Text = ("Tanaman %d | Siap %d | Panen %d"):format(H.Total,H.ReadyNow,H.Harvested)
        detLabelH.Text = H.Det and ("Deteksi: "..H.Det.name) or "Deteksi: belum (auto saat mulai)"
        -- Plant
        statLabelA.Text = A.Status
        numLabelA.Text = ("Tempat %d | Tanam %d | Seed %d"):format(A.Total,A.Planted,A.SeedId and invCount(A.SeedId) or 0)
        -- Connection status
        local ok = gameReady()
        for _,c in ipairs({ {lbl=connLabelP,btn=connBtnP}, {lbl=connLabelH,btn=connBtnH}, {lbl=connLabelA,btn=connBtnA} }) do
            c.lbl.Text = ok and "Terhubung ke game" or "Belum terhubung"
            c.lbl.TextColor3 = ok and C.ok or C.bad
        end
        if P.BlockId and not blockList.Visible then selText.Text = blockLabel(P.BlockId) end
        if H.SeedId and not seedList.Visible then selSeedText.Text = seedLabel(H.SeedId) end
        if A.SeedId then seedPickA.refresh() end
    end))
end

-- ============================================================
-- INIT & CLEANUP
-- ============================================================
Session.Cleanup = function()
    P.Running = false; P.RunId = P.RunId+1
    H.Running = false; H.RunId = H.RunId+1
    A.Running = false; A.RunId = A.RunId+1
    AutoInput.active = false; releaseInput()
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    if OrigIsDown and MenuModOk and rawget(MenuModule,"isDown")==isDownWrapper then MenuModule.isDown = OrigIsDown end
    pcall(function() Gui:Destroy() end)
end

CloseBtn.MouseButton1Click:Connect(function()
    Session.Cleanup()
    G.__KNearAIO = nil
end)

-- Auto-connect (sekali), lalu tampilkan toast
task.spawn(function()
    for _=1,20 do
        if not alive() then return end
        local ok = pcall(connectGame)
        if gameReady() then break end
        task.wait(3)
    end
    if alive() then
        pcall(populateBlocks); pcall(populateSeeds)
        toast(gameReady() and "K NEAR AIO siap (PNB · Harvest · Plant)" or "Belum terhubung. Masuk world lalu tekan Hubungkan")
    end
end)

-- DEBUG: Cek fungsi yang mungkin nil
local function debugFunc(name, fn)
    if type(fn) ~= "function" then
        warn("[DEBUG] FUNGSI NIL: " .. name)
    end
end

-- Panggil debugFunc untuk fungsi-fungsi penting
-- (Tambahkan ini di akhir script, setelah semua fungsi didefinisikan)
debugFunc("H.ready", H.ready)
debugFunc("H.scan", H.scan)
debugFunc("H.discover", H.discover)
debugFunc("A.plan", A.plan)
debugFunc("A.navigate", A.navigate)
debugFunc("pnbLoop", pnbLoop)

