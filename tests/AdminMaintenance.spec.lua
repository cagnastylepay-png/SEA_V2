return function(hub)
local function section(first,last)local a=assert(hub:find(first,1,true));local b=assert(hub:find(last,a,true));return hub:sub(a,b-1)end
local service=section("local function serviceWallMaintenance(","-- Butterfly waiting")
local hatch=section("local function hatchReadyEggsOnWallClose(","function FusionModules.Helpers.PlotEggCountdown(")

local function compile(source,env)local f=assert(loadstring(source));setfenv(f,setmetatable(env,{__index=getfenv()}));return f()end
local calls={};local priority=false
local fusion={Options={AutoMutations=true,AutoEquipBest=true},Ready=true,Reporting={ClientKind="admin"},Pending=function()return false end,YieldToSpawnedEggs=function()return priority end,Helpers={EquipBestForInventory=function()table.insert(calls,"equip-failed");return false end},AdminRuntime={Initialized=true,MutateNext=function()table.insert(calls,"mutate");return true end,SellAnimals=function()table.insert(calls,"animals")end},Run=function()table.insert(calls,"fuse")end,Protect=function(_,fn)fn();return true end}
local run=compile(service.."\nreturn serviceWallMaintenance",{destroyed=false,automaticMode=true,autoEnabled=true,generation=1,wallMaintenancePending=true,FusionModules=fusion,getCharacterParts=function()return nil,nil,{Position=Vector3.zero}end,isSafe=function()return true end,placeInventoryEggs=function()table.insert(calls,"place");return 0 end,hatchReadyEggsOnWallClose=function()table.insert(calls,"hatch");return 0 end,sellInventoryEggsBelowMinimum=function()table.insert(calls,"sell")end})
run(1);assert(table.concat(calls,",")=="place,mutate,hatch,sell,animals,place,equip-failed,fuse","mutations and Equip Best failure cannot starve other work")
calls={};priority=true;run(1);assert(#calls==0,"eligible egg always wins")
priority=false;fusion.AdminRuntime.ManualPending=true;run(1);assert(#calls==0,"manual action reserves maintenance boundary")
local opened={}
local records={a={Placement={},Uid="a"},b={Placement={},Uid="b"}}
local f={Options={AutoOpen=true,AutoOpenMin=0,AutoOpenMax=100,AutoMutations=true},Reporting={ClientKind="admin"},Helpers={PlotEggCountdown=function()return 0,true end,DescribeEgg=function()return"Egg"end},AdminRuntime={Initialized=true,ShouldHoldEgg=function(uid)return uid=="b"end},YieldToSpawnedEggs=function()return false end}
local h=compile(hatch.."\nreturn hatchReadyEggsOnWallClose",{FusionModules=f,EggState={ReadOwnerEggs=function()return records end,ReadOwnedEgg=function(_,uid)return records[uid]end},player={UserId=42},EggGrowthPolicy={IsReady=function()return false end},PlacedEggRenderer={ActivateLocalEgg=function(uid)table.insert(opened,uid);return true end},getRatePerSecond=function()return 50 end,setStatus=function()end,log=function()end,autoEnabled=true,automaticMode=true,generation=1})
assert(h(1)==1 and opened[1]=="a","use actual countdown; only hold egg awaiting its own mutation")
return "Scheduler regressions passed: eligible-flight priority; no cycle dependency; mutation retries and failed Equip Best cannot starve fusion/sales; hatch uses card countdown; per-egg mutation hold; manual boundary."

end


