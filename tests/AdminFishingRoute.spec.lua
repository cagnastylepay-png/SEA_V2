return function(hub)
 local start=assert(hub:find("function FusionModules.Helpers.FishingMove(",1,true))
 local finish=assert(hub:find("local function idleOnTreadmill(",start,true))
 local source=hub:sub(start,finish-1)
 local root={Position=Vector3.new(10,80,10)};local character={};local moves={};local queued={};local allowed=true;local depart=Vector3.new(0,20,0)
 local modules={Helpers={},Options={AutoFishing=true}}
 local env=setmetatable({FusionModules=modules,automaticMode=true,queuedEggs=queued,getCharacterParts=function()return character,{},root end,activityValid=function()return allowed end,
  getStartAreaDestination=function()return depart,"missing StartArea"end,setStatus=function()end,
  moveActivity=function(point,token,interrupt,nextPoint)
   table.insert(moves,{point=point,token=token,interrupt=interrupt,nextPoint=nextPoint})
   root.Position=Vector3.new(point.X,77,point.Z)
   return true
  end}, {__index=getfenv()})
 local fn=assert(loadstring(source));setfenv(fn,env);fn()
 local target=Vector3.new(9000,99999,-300)
 assert(modules.Helpers.FishingMove(target,42))
 assert(#moves==2 and moves[1].point==depart,"StartArea before dock, like butterflies")
 assert(moves[1].nextPoint==Vector3.new(9000,20,-300),"chain destination from StartArea")
 assert(moves[2].point==Vector3.new(9000,77,-300),"dock uses current height, ignores target Y")
 assert(moves[1].interrupt and moves[2].interrupt,"both legs yield to eligible eggs")
 table.clear(moves)
 env.moveActivity=function(point,token,interrupt,nextPoint)table.insert(moves,point);queued.egg=true;return true end
 assert(not modules.Helpers.FishingMove(target,42)and #moves==1,"new egg cancels second leg")
 queued.egg=nil;table.clear(moves);depart=nil
 assert(not modules.Helpers.FishingMove(target,42)and #moves==0,"missing StartArea never starts a direct wall route")
 return "Fishing route passed: StartArea then dock, X/Z arrival, live height, eligible egg interruption and no direct fallback."
end