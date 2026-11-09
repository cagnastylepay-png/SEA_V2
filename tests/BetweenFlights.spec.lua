return function(source)
 local function section(first,last)local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true));return source:sub(a,b-1)end
 local fm={Options={AutoEggs=false,AutoIndex=true,AutoEggsMin=10,AutoEggsMax=100,AutoEquipBest=false},Helpers={},Arrival={Waiting=function()return false end},SpawnPriorityUntil=999999}
 local records={missing={Uid='missing',AssetCategory='Cat',rate=5}}
 local queued={missing={Source='INDEX',Record=records.missing},manual={Source='MANUEL',Record={Uid='manual'}}}
 local env=setmetatable({FusionModules=fm,automaticMode=true,autoEnabled=true,ready=true,destroyed=false,generation=7,
  records=records,queuedEggs=queued,trackedEggs={},minimumRatePerSecond=10,Save={Peek=function()return{Index={}}end},Assets={Directory={Cat={}}},
  readField=function(uid)return records[uid]or{Uid=uid}end,ownsEgg=function()return false end,isTrackedFieldState=function()return true end,
  getRatePerSecond=function(r)return r.rate end,isHeldByOther=function()return false end,log=function()end,
  enqueueEgg=function(r,kind)queued[r.Uid]={Source=kind,Record=r};return true end,
  player={UserId=1},getCharacterParts=function()return nil,nil,{Position=Vector3.zero}end,isSafe=function()return true end,
  readCarry=function()return{IsCarrying=false}end,wallMaintenancePending=true},{__index=getfenv()})
 fm.Helpers.plotAnimalCategories=function()return{}end;fm.Helpers.backpackEggCategories=function()return{}end
 fm.Helpers.IsAlwaysEligibleRarity=function()return false end
 fm.Help={WasDelivered=function()return false end,Present=function()return false end}
 local function compile(code)local f=assert(loadstring(code));setfenv(f,env);return f()end
 compile(section('syncQueue = function()','-- Retain the exact remote target'))
 env.syncQueue()
 assert(not queued.missing and queued.manual,'AutoEggs OFF removes Index queue but preserves manual collection')
 assert(fm.Options.AutoIndex,'Index protection option remains enabled')
 fm.Options.AutoEggs=true;env.syncQueue();assert(queued.missing and queued.missing.Source=='INDEX','enabling collection restores missing candidates')
 compile(section('function FusionModules.YieldToSpawnedEggs()','local function hatchReadyEggsOnWallClose('))
 local calls={};fm.Pending=function()return false end;fm.Ready=true
 fm.AdminRuntime={Initialized=true,ProgressNext=function()error('no upgrade detour between flights')end,SellAnimals=function()table.insert(calls,'animals')end}
 fm.Run=function()table.insert(calls,'fuse')end;fm.Protect=function(_,f)f();return true end
 env.placeInventoryEggs=function()assert(not fm.YieldToSpawnedEggs());table.insert(calls,'place');return 0 end
 env.hatchReadyEggsOnWallClose=function()assert(not fm.YieldToSpawnedEggs());table.insert(calls,'open');return 1 end
 env.sellInventoryEggsBelowMinimum=function()assert(not fm.YieldToSpawnedEggs());table.insert(calls,'sell')end
 local run=compile(section('local function serviceWallMaintenanceBody(','-- Butterfly waiting')..'\nreturn serviceWallMaintenance')
 assert(fm.YieldToSpawnedEggs(),'pending spawn keeps normal flight priority')
 run(7);assert(#calls==0,'ordinary maintenance still yields')
 run(7,true)
 assert(table.concat(calls,',')=='place,open,sell,animals,place,fuse','post-flight pass completes despite continuous queue')
 assert(fm.BetweenFlights==nil and fm.YieldToSpawnedEggs(),'flight priority restored after pass')
 env.wallMaintenancePending=true;env.placeInventoryEggs=function()error('test error')end
 assert(not pcall(run,7,true)and fm.BetweenFlights==nil,'exception releases reserved pass')
 env.readCarry=function()return{IsCarrying=true}end;assert(pcall(run,7,true),'carried egg never enters maintenance')
 assert(source:find('serviceWallMaintenance(token,true)',1,true),'successful worker flight invokes reserved pass')
 return 'Between-flight scheduling passed: pending eggs no longer starve inventory work; priority restored; error/carry guards; missing-only collection blocked while manual collection and index protections remain.'
end

