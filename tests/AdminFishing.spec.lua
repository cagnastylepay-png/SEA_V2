return function(source)
 local now=0;local can=true;local equipFails=false;local equips=0;local deactivations=0
 local char={};local tool={Parent=nil};local bag={}
 local humanoid={Health=100}
 function humanoid:EquipTool(t)equips+=1;if not equipFails then t.Parent=char end end
 function humanoid:UnequipTools()tool.Parent=bag end
 function char:FindFirstChildOfClass()return humanoid end
 function char:FindFirstChild()return nil end
 function tool:Deactivate()assert(self.Parent~=char,"unequip before release on cancellation");deactivations+=1 end
 function bag:GetChildren()return{tool}end
 local player={Character=char,FindFirstChildOfClass=function()return bag end}
 local modules={Fishing={},FishingFlags={},AlienLagoon={},Save={}}
 function modules.Fishing.IsRod(t)return t==tool end
 function modules.Fishing.EquippedRod(c)return tool.Parent==c and tool or nil end
 local RS={Shared={Util={Fishing="Fishing",AlienLagoon="AlienLagoon"},Flags={FishingFlags="FishingFlags"},Save="Save"}}
 local env=setmetatable({require=function(key)return modules[key]end,os={clock=function()return now end},game={GetService=function(_,name)
  if name=="Players"then return{LocalPlayer=player}elseif name=="ReplicatedStorage"then return RS elseif name=="RunService"then return{Heartbeat={Wait=function()now+=.05 end}}else return{}end
 end}}, {__index=getfenv()})
 local chunk=assert(loadstring(source));setfenv(chunk,env)
 local f=chunk()({CanFish=function()return can end})
 assert(math.abs(f.PerfectSeconds(1.2,.8,.95)-1.0908334)<.00001)
 assert(not pcall(f.PerfectSeconds,1.2,.95,.8))
 local track={Size={Y={Scale=.8}},Position={Y={Scale=.1}},AnchorPoint={Y=0},GetAttribute=function(_,name)return name=="WindowTop"and .1 or .9 end}
 local tag={Position={Y={Scale=.26}}}
 assert(math.abs(f.ChargeFromTag(track,tag)-.875)<.00001,"read native gauge with window offsets")
 track.Size.Y.Scale=0;assert(f.ChargeFromTag(track,tag)==nil,"missing gauge cannot trigger release")
 assert(f.Equip(1)==tool and equips==1,"first cast equips rod")
 f.Cancel();assert(deactivations==1 and tool.Parent==bag)
 f.Cancelled=false
 assert(f.Equip(1)==tool and equips==2,"next cast re-equips rod")
 f.Cancel();f.Cancelled=false;equipFails=true
 assert(f.Equip(1)==nil,"failed equip confirmation prevents cast")
 equipFails=false;can=false
 assert(f.Equip(1)==nil,"flight priority prevents equip")
 can=true;f.Cancelled=false;assert(f.Equip(1)==tool)
 f.Cancel();assert(tool.Parent==bag,"cancellation releases rod")
 return "Fishing mocks passed: dynamic Perfect midpoint, rod equipped each cast, failed equip blocked, flight priority, cancellation unequips before release. No live cast executed."
end