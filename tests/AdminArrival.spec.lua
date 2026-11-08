return function(hub)
 local function section(first,last)
  local a=assert(hub:find(first,1,true));local b=assert(hub:find(last,a,true));return hub:sub(a,b-1)
 end
 local function compile(source,env)
  local fn=assert(loadstring(source));setfenv(fn,setmetatable(env,{__index=getfenv()}));return fn()
 end
 local source=section('-- Retain the exact remote target','local function selectBest()')
 local now,wall=100,1000
 local saved={jobId='destination',reporterUserId='42',clientKind='admin',uid='target',expiresAt=1100}
 local record,profile,owned,held=nil,{},false,false
 local queue={}
 local env={FusionModules={Reporting={ClientKind='admin'},Helpers={IsAlwaysEligibleRarity=function()return false end}},CONFIG={ArrivalTargetTimeout=20},game={JobId='destination',GetService=function()return {GetTeleportSetting=function()return saved end,SetTeleportSetting=function(_,_,value)saved=value end}end},player={UserId=42},os={clock=function()return now end,time=function()return wall end},log=function()end,destroyed=false,automaticMode=true,queuedEggs=queue,ownsEgg=function()return owned end,readField=function()return record,true end,isTrackedFieldState=function(r)return r.State=='Slot'end,isHeldByOther=function()return held end,getRatePerSecond=function(r)return r.Rate end,Save={Peek=function()return profile end}}
 compile(source,env)
 local arrival=env.FusionModules.Arrival
 assert(arrival.Uid=='target'and arrival.Waiting(),'empty initial replication must retain arrival target')
 record={Uid='target',State='Slot',Rate=10}
 assert(arrival.Waiting(),'profile/index still loading cannot release the arrival gate')
 queue.target={Record=record}
 assert(not arrival.Waiting()and arrival.Uid=='target','eligible target releases gate but retains exact selection priority')
 local richer={Uid='richer',State='Slot',Rate=100}
 queue.richer={Record=richer}
 env.records={target=record,richer=richer};env.cooldowns={};env.getCharacterParts=function()end
 env.readField=function(uid)return env.records[uid],true end
 env.FusionModules.Helpers.QueueDistance=function()return 0 end
 env.FusionModules.Helpers.QueueBefore=function(a,b)return a.Rate>b.Rate end
 local select=compile(section('local function selectBest()','stopAutomation = function(')..'\nreturn selectBest',env)
 assert(select().Uid=='target','arrival egg precedes unrelated richer local egg')
 queue.target=nil;profile.Index={}
 assert(not arrival.Waiting()and arrival.Uid==nil and saved==nil,'loaded but ineligible target falls back without bypassing options')
 local function arm(overrides)
  saved={jobId='destination',reporterUserId='42',clientKind='admin',uid='target',expiresAt=1100}
  for k,v in pairs(overrides or{})do saved[k]=v end
  arrival.Uid=nil;arrival.Deadline=nil;arrival.Load()
 end
 for _,bad in ipairs({{jobId='wrong'},{reporterUserId='99'},{clientKind='observer'},{expiresAt=999},{uid=''}})do arm(bad);assert(arrival.Uid==nil,'reject stale/foreign/untargeted arrival')end
 arm();env.readField=function()return nil,true end;now=121
 assert(not arrival.Waiting()and arrival.Uid==nil,'missing target times out instead of blocking forever')
 now=100;arm();owned=true;assert(not arrival.Waiting(),'owned target does not trigger another flight');owned=false
 arm();env.readField=function()return record,true end;held=true;assert(not arrival.Waiting(),'already carried target is unavailable');held=false
 arm();env.automaticMode=false;assert(not arrival.Waiting(),'AUTO OFF releases pending arrival');env.automaticMode=true
 local worker=section('local function worker(token)','startAutomation = function(')
 assert(worker:find('FusionModules.Arrival.Waiting()',1,true)<worker:find('serviceWallMaintenance(token)',1,true),'arrival gate precedes inventory maintenance')
 local uiEnd=assert(hub:find('-- Gameplay polling belongs to the engine',1,true))
 assert(uiEnd>assert(hub:find('log("UI_READY"',1,true)),'queue heartbeat must live outside optional GUI')
 assert(hub:find('if FusionModules.ManualBusy or FusionModules.MutationBusy or FusionModules.Pending()',1,true),'global heartbeat must preserve manual mutation/action lock')
 return 'Arrival regressions passed: delayed replication, exact eligible target priority, current options, foreign/stale targets, timeout, ownership, carrying, AUTO OFF, headless polling and manual action lock.'
end
