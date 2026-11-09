return function(hub)
 local a=assert(hub:find("function FusionModules.Helpers.MoveForUpgrade",1,true));local b=assert(hub:find("-- World eggs have priority",a,true))
 local root={Position=Vector3.new(100,0,0)};local sign={Position=Vector3.zero,Parent=true,IsA=function(_,c)return c=="BasePart"end}
 local expected="PlotUpgrade";local model={FindFirstChild=function(_,name)return name=="Sign"and sign end}
 local ownPlot={FindFirstChild=function(_,name)assert(name==expected,"choose the requested upgrade on the local plot");return model end}
 local plot={PlotFolder=ownPlot};local character={};local continue=true;local arrived=true;local stopped=0;local moved=0;local fm={Helpers={}};local sharedState={}
 local env=setmetatable({FusionModules=fm,shared=sharedState,generation=7,getCharacterParts=function()return character,nil,root end,PlotState={ResolvePlot=function()return plot end},leaveTreadmill=function()return true end,activityValid=function()return true end,stopMovement=function()stopped+=1 end,moveActivity=function(point,token,interrupt)assert(token==7 and interrupt and sharedState.__AutoSAEMovementLock);moved+=1;if arrived then root.Position=point end;return arrived,"blocked"end},{__index=getfenv()})
 local f=assert(loadstring(hub:sub(a,b-1)));setfenv(f,env);f()
 local check=function()return continue end
 assert(fm.Helpers.MoveForUpgrade("plot",check));assert((root.Position-sign.Position).Magnitude<=7 and moved==1 and not sharedState.__AutoSAEMovementLock)
 root.Position=Vector3.new(100,0,0);expected="TreadmillUpgrade";assert(fm.Helpers.MoveForUpgrade("treadmill",check))
 continue=false;assert(not fm.Helpers.MoveForUpgrade("treadmill",check));continue=true
 root.Position=Vector3.new(100,0,0);arrived=false;assert(not fm.Helpers.MoveForUpgrade("treadmill",check));assert(not sharedState.__AutoSAEMovementLock,"release movement lock on interruption")
 sign.Parent=nil;root.Position=Vector3.zero;assert(not fm.Helpers.MoveForUpgrade("treadmill",check),"do not buy after the plot rebuilt")
 return "Upgrade approach passed: local plot resolution, native treadmill exit, walking with egg interruption, real distance, missing/rebuilt panel and movement lock cleanup."
end


