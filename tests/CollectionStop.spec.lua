return function(source)
 local function section(first,last)local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true));return source:sub(a,b-1)end
 local fm={Helpers={},RemoteHop={Pending={}},Pending=function()return false end}
 local carry={IsCarrying=false};local safe=false;local walks=0;local recoveries=0;local statuses={}
 local ctx={findNext=function()end}
 local env=setmetatable({FusionModules=fm,queuedEggs={a={},b={}},trackedEggs={a={}},selectedEggs={a=true},removedFromAuto={a=true},currentCycle=ctx,
  destroyed=false,autoEnabled=true,generation=5,getCharacterParts=function()return nil,nil,{Position=Vector3.zero}end,
  isSafe=function()return safe end,readCarry=function()return carry end,getStartAreaDestination=function()return Vector3.one end,
  leaveTreadmill=function()return true end,moveActivity=function(_,token,interrupt)assert(token==5 and not interrupt);walks+=1;safe=true;return true end,
  readField=function(uid)return{Uid=uid}end,getRatePerSecond=function()return 10 end,
  runCycle=function(_,_,recovering)findNext=nil;assert(recovering);recoveries+=1;carry={IsCarrying=false};safe=true;return true end,
  stopAutomation=function(reason)error(reason)end,setStatus=function(s)table.insert(statuses,s)end,
  task={wait=function()end}},{__index=getfenv()})
 local function compile(code)local f=assert(loadstring(code));setfenv(f,env);return f()end
 compile(section('function FusionModules.Helpers.StopCollection()','local function ingest(record)'))
 fm.Helpers.StopCollection()
 assert(next(env.queuedEggs)==nil and next(env.trackedEggs)==nil and next(env.selectedEggs)==nil,'entire pending list cleared')
 assert(ctx.CollectionStopped and ctx.findNext==nil and fm.RemoteHop.Pending==nil,'active approach cancelled and remote target removed')
 assert(fm.CollectionResetVersion==1 and fm.CollectionReturnPending,'GUI reset and return armed immediately')
 compile(section('function FusionModules.Helpers.ReturnAfterCollectionStop(token)','local function worker(token)'))
 env.currentCycle=nil
 env.inFlightRequest={done=false};fm.Helpers.ReturnAfterCollectionStop(5);assert(walks==0 and fm.CollectionReturnPending,'wait for an existing server request')
 env.inFlightRequest=nil;assert(fm.Helpers.ReturnAfterCollectionStop(5));assert(walks==1 and not fm.CollectionReturnPending,'walk home without waiting for a new cycle')
 fm.CollectionReturnPending=true;carry={IsCarrying=true,Uid='egg'};safe=false
 fm.Helpers.ReturnAfterCollectionStop(5);assert(recoveries==1 and not fm.CollectionReturnPending,'accepted egg returned safely without a new pickup')
 fm.CollectionReturnPending=true;env.generation=6;fm.Helpers.ReturnAfterCollectionStop(5);assert(walks==1,'stale worker cannot move character')
 local approach=section('local function moveThenCarry(ctx, destination)','local function carryWasLost(ctx)')
 assert(approach:find('if ctx.CollectionStopped then',1,true),'no pickup after cancellation')
 local returning=section('local function moveReturnLoop(ctx, destination)','local function cleanupCycle(ctx)')
 assert(returning:find('not ctx.CollectionStopped',1,true),'cancelled return cannot reacquire another egg')
 return 'Collection stop passed: immediate complete queue reset; outbound cancellation; no new pickup; pending server request serialized; empty/carrying return to safe zone; stale generation guard.'
end

