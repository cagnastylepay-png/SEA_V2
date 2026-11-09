return function(source)
 local function section(a,b)local i=assert(source:find(a,1,true));local j=assert(source:find(b,i,true));return source:sub(i,j-1)end
 local now=0;local inside=false;local safe=false;local stuck=false;local moves=0
 local character={};local root={Position=Vector3.new(0,3,5)}
 local fm={Helpers={},GameplayGuard={IsLocalInsideArena=function()return inside end,IsInsideSafeZone=function()return safe end}}
 local humanoid={WalkSpeed=16,MoveTo=function(_,destination)assert(destination.Z<0 and destination.Y==3);moves+=1;if not stuck then inside=true;safe=false end end}
 local env=setmetatable({FusionModules=fm,player={},getCharacterParts=function()return character,humanoid,root end,
  getSeparationLine=function()return{CFrame=CFrame.new(),Size=Vector3.new(100,1,.5)}end,
  activityValid=function(token,c)return token==2 and c==character end,motionBlockReason=function()return nil end,
  distanceXZ=function(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end,
  os={clock=function()return now end},RunService={Heartbeat={Wait=function()now+=.1 end}},
  setStatus=function()end,log=function()end},{__index=getfenv()})
 local function compile(c)local f=assert(loadstring(c));setfenv(f,env);return f()end
 compile(section('function FusionModules.Helpers.GameplayEntryAllowed()','local function validCycle(ctx)'))
 assert(not fm.Helpers.GameplayEntryAllowed(),'geometry alone is not entry evidence')
 inside=true;safe=true;assert(not fm.Helpers.GameplayEntryAllowed(),'tagged safe volume blocks tool use')
 inside=false;safe=false
 compile(section('function FusionModules.Helpers.EnterGameplay(token)','-- Serialize treadmill requests,'))
 assert(fm.Helpers.EnterGameplay(2)and moves==1 and now>=.35,'native walking plus stable native entry')
 inside=true;safe=true;stuck=true;now=0
 assert(not fm.Helpers.EnterGameplay(2),'unresolved safe volume stops entry instead of claiming success')
 fm.CollectionReturnPending=true;assert(not fm.Helpers.EnterGameplay(2),'collection stop cancels crossing')
 fm.CollectionReturnPending=nil;fm.GameplayGuard=nil;assert(not fm.Helpers.GameplayEntryAllowed(),'missing native state fails closed')
 local request=compile(section('local function requestCarry(ctx)','local function awaitCycleOperation(')..'\nreturn requestCarry')
 local ctx={};assert(request(ctx)==nil and ctx.gameplayEntryRejected,'no pickup sent while native entry is false')
 assert(source:find('ctx.gameplayEntryRejected = true',1,true),'server entry refusal is terminal, not five retries')
 return 'Gameplay entry passed: native arena and tagged-safe checks, normal walking, stable entry, timeout/cancel, missing state and pickup gating. No gameplay remotes invoked.'
end


