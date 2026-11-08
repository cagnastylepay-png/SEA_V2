return function(source)
 local now=0;local can=true;local equipFails=false;local equips=0;local deactivations=0
 local world={};function world:FindFirstChild()return nil end
 local char={};local tool={Parent=nil};local bag={}
 local humanoid={Health=100}
 function humanoid:EquipTool(t)equips+=1;if not equipFails then t.Parent=char end end
 function humanoid:UnequipTools()tool.Parent=bag end
 function char:FindFirstChildOfClass()return humanoid end
 function char:FindFirstChild()return nil end
 function tool:Deactivate()assert(self.Parent~=char,"unequip before release on cancellation");deactivations+=1 end
 function bag:GetChildren()return{tool}end
 local inside=false;local reveal={Visible=false};local gui={Enabled=true,FindFirstChild=function(_,key)return key=="Reveal"and reveal end}
 local player={GetAttribute=function()return inside end,Character=char,FindFirstChildOfClass=function(_,kind)return kind=="PlayerGui"and{FindFirstChild=function()return gui end}or bag end}
 local modules={Fishing={},FishingFlags={},AlienLagoon={},Save={}}
 function modules.Fishing.IsRod(t)return t==tool end
 function modules.Fishing.EquippedRod(c)return tool.Parent==c and tool or nil end
 local RS={Shared={Util={Fishing="Fishing",AlienLagoon="AlienLagoon"},Flags={FishingFlags="FishingFlags"},Save="Save"}}
 local env=setmetatable({require=function(key)return modules[key]end,os={clock=function()return now end},game={GetService=function(_,name)
  if name=="Players"then return{LocalPlayer=player}elseif name=="ReplicatedStorage"then return RS elseif name=="Workspace"then return world elseif name=="RunService"then return{Heartbeat={Wait=function()now+=.05 end}}else return{}end
 end}}, {__index=getfenv()})
 local chunk=assert(loadstring(source));setfenv(chunk,env)
 local f=chunk()({CanFish=function()return can end})
 local currentProfile={FishingMastery={Caught=4}};modules.Save.Peek=function()return currentProfile end
 assert(not f.CaptureConfirmed(4),"hidden meter alone is not capture confirmation")
 currentProfile.FishingMastery.Caught=5;assert(f.CaptureConfirmed(4),"replicated caught increment confirms capture")
 currentProfile.FishingMastery.Caught=4;reveal.Visible=true;assert(f.CaptureConfirmed(4),"native reward reveal confirms server acceptance");reveal.Visible=false
 assert(f.DockSite({HipHeight=2})==nil,"missing fixed dock cannot use another bank")
 local deck={Position=Vector3.new(0,10,0),CFrame=CFrame.new(0,10,0),Size=Vector3.new(60,1,20),IsA=function()return true end}
 local course={Position=Vector3.new(100,10,0),IsA=function()return true end}
 local dock={GetDescendants=function()return{deck}end}
 local function folder(children)return{FindFirstChild=function(_,key)return children[key]end}end
 local ferryChildren={Course=course}
 local zone=folder({Zone14Props=folder({Dock=dock}),LagoonFerry=folder(ferryChildren)})
 world.FindFirstChild=function(_,key)return key=="World"and folder({Build=folder({AlienBiomeZone=zone})})end
 local site=assert(f.DockSite({HipHeight=2}));assert(site.stand==Vector3.new(26,14.5,0)and site.target==course.Position,"stand inset on deck, target is Course direction")
 ferryChildren.Course=nil;assert(f.DockSite({HipHeight=2})==nil,"missing Course blocks the cast")
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
 can=true;f.Cancelled=false;inside=true;assert(f.Equip(1)==nil,"lagoon state prevents dock fishing");inside=false
 world.CurrentCamera={CameraType=Enum.CameraType.Scriptable};assert(f.Equip(1)==nil,"boat/cutscene camera blocks equipment");world.CurrentCamera=nil
 assert(f.Equip(1)==tool)
 f.Cancel();assert(tool.Parent==bag,"cancellation releases rod")
 return "Fishing mocks passed: dynamic Perfect midpoint, rod equipped each cast, failed equip blocked, flight priority, cancellation unequips before release. No live cast executed."
end