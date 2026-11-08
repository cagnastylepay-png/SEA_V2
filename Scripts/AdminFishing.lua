-- Uses the game's rod controller and FishingUI. Creates no GUI and sends no log batches.
return function(ctx)
 local F={Cancelled=false,RetryAt=0}
 local player=game:GetService("Players").LocalPlayer
 local world=game:GetService("Workspace")
 local RS=game:GetService("ReplicatedStorage")
 local heartbeat=game:GetService("RunService").Heartbeat
 local input=game:GetService("UserInputService")
 local fishing=require(RS.Shared.Util.Fishing)
 local flags=require(RS.Shared.Flags.FishingFlags)
 local lagoon=require(RS.Shared.Util.AlienLagoon)
 local save=require(RS.Shared.Save)
 function F.PerfectSeconds(seconds,low,high)
  assert(seconds>0 and low>=0 and high<=1 and low<=high,"Invalid charge window")
  return seconds*((low+high)/2)^(1/1.4)
 end
 local function ui()
  local gui=player:FindFirstChildOfClass("PlayerGui")
  return gui and gui:FindFirstChild("FishingUI")
 end
 local function visible(name)
  local gui=ui();local node=gui and gui:FindFirstChild(name)
  return gui and gui.Enabled and node and node.Visible or false
 end
 function F.ChargeFromTag(track,tag)
  local top=track:GetAttribute("WindowTop");top=type(top)=="number"and top or 0
  local bottom=track:GetAttribute("WindowBottom");bottom=type(bottom)=="number"and bottom or 1
  local span=track.Size.Y.Scale*(bottom-top);if span<=0 then return nil end
  local start=track.Position.Y.Scale-track.AnchorPoint.Y*track.Size.Y.Scale+track.Size.Y.Scale*top
  return math.clamp(1-(tag.Position.Y.Scale-start)/span,0,1)
 end
 function F.ReadCharge()
  local gui=ui();local charge=gui and gui:FindFirstChild("Charge")
  local track=charge and charge:FindFirstChild("Track");local tag=charge and charge:FindFirstChild("Tag")
  return track and tag and F.ChargeFromTag(track,tag)or nil
 end
 local function parts()
  local char=player.Character
  return char,char and char:FindFirstChildOfClass("Humanoid"),char and char:FindFirstChild("HumanoidRootPart")
 end
 function F.Cancel()
  F.Cancelled=true
  local tool=F.Tool;F.Tool=nil
  local char,humanoid=parts()
  if tool and tool.Parent==char and humanoid then pcall(function()humanoid:UnequipTools()end)end
  if tool and tool.Parent~=char then pcall(function()tool:Deactivate()end)end
  if F.Camera and world.CurrentCamera==F.Camera and F.CameraFrame then F.Camera.CFrame=F.CameraFrame end
  F.Camera=nil;F.CameraFrame=nil
 end
 local function valid(token,char)
  return not F.Cancelled and player.Character==char and ctx.CanFish(token)
 end
 local function await(token,char,seconds,predicate)
  local deadline=os.clock()+seconds
  repeat
   if not valid(token,char)then return false end
   if predicate()then return true end
   heartbeat:Wait()
  until os.clock()>=deadline
  return false
 end
 -- Re-resolve and confirm the equipped rod before EVERY cast, including after inventory maintenance.
 function F.Equip(token)
  local char,humanoid=parts();if not char or not humanoid or humanoid.Health<=0 then return nil end
  local tool=fishing.EquippedRod(char)
  if not tool then
   local bag=player:FindFirstChildOfClass("Backpack")
   if bag then for _,candidate in ipairs(bag:GetChildren())do
    if fishing.IsRod(candidate)then tool=candidate;break end
   end end
  end
  if not tool or not ctx.CanFish(token)then return nil end
  if tool.Parent~=char then humanoid:EquipTool(tool)end
  if not await(token,char,2,function()return tool.Parent==char and fishing.EquippedRod(char)==tool end)then return nil end
  F.Tool=tool;return tool
 end
 local function aim(char,root)
  local camera=world.CurrentCamera;if not camera then return root.CFrame.LookVector end
  local kind=input:GetLastInputType()
  if kind~=Enum.UserInputType.Touch and not kind.Name:find("Gamepad",1,true)and not(input.TouchEnabled and not input.MouseEnabled)then
   local mouse=input:GetMouseLocation();local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char}
   local hit=world:Raycast(ray.Origin,ray.Direction*500,params)
   local point=hit and hit.Position
   if not point and ray.Direction.Y<-.01 then point=ray.Origin+ray.Direction*((root.Position.Y-3-ray.Origin.Y)/ray.Direction.Y)end
   if point then local delta=Vector3.new(point.X-root.Position.X,0,point.Z-root.Position.Z);if delta.Magnitude>=2 then return delta.Unit end end
  end
  return camera.CFrame.LookVector
 end
 local function waterAt(char,point)
  local probe=fishing.Probe(point,{char})
  return probe and probe.Water and probe.Point or nil
 end
 local function findBank(char,root,charge)
  local roots={world:FindFirstChild("AlienLagoon")}
  local build=world:FindFirstChild("World");build=build and build:FindFirstChild("Build")
  table.insert(roots,build and build:FindFirstChild("AlienBiomeZone"))
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char};params.IgnoreWater=false
  local best,distance;local castDistance=fishing.DistanceFor(charge)
  for _,zone in pairs(roots)do for _,part in ipairs(zone:GetDescendants())do
   if part:IsA("BasePart")and(part.Material==Enum.Material.Water or part:GetAttribute("FishingWater")==true or part:GetAttribute("TerrainRole")=="Basin")then
    local water=waterAt(char,part.Position)
    if water then for n=0,15 do
     local angle=n*math.pi/8;local direction=Vector3.new(math.cos(angle),0,math.sin(angle))
     local edge=math.min(part.Size.X,part.Size.Z)/2+5
     local point=part.Position+direction*edge
     local ground=world:Raycast(point+Vector3.new(0,60,0),Vector3.new(0,-140,0),params)
     if ground and not fishing.IsWaterHit(ground)and ground.Normal.Y>.7 then
      local stand=ground.Position+Vector3.new(0,3,0)
      local target=waterAt(char,stand-direction*castDistance)
      if target then local d=(stand-root.Position).Magnitude;if not distance or d<distance then best={stand=stand,target=target};distance=d end end
     end
    end end
   end
  end end
  return best
 end
 function F.Cycle(token)
  if os.clock()<F.RetryAt then task.wait(.25);return end
  F.Cancelled=false
  local char,humanoid,root=parts();if not root or not humanoid then return end
  local ok,why=pcall(function()
   assert(flags.Enabled:Get(),"Peche fermee")
   assert(not flags.DimensionOnly:Get(),"Peche alien indisponible avec DimensionOnly")
   local profile=save.Peek();assert(profile and lagoon.FastEnough(profile.SpeedPower),"Vitesse insuffisante pour la peche alien")
   local charge=(flags.PerfectMin:Get()+flags.PerfectMax:Get())/2
   local site=F.Site
   if not site or not waterAt(char,site.target)then site=findBank(char,root,charge);F.Site=site end
   assert(site,"Aucune berge de peche alien accessible detectee")
   ctx.Status("PECHE : trajet vers la berge")
   if (root.Position-site.stand).Magnitude>5 then assert(ctx.FishingMove(site.stand,token),"Trajet peche interrompu")end
   assert(valid(token,char),"Peche interrompue")
   local tool=assert(F.Equip(token),"Canne absente ou equipement non confirme")
   local camera=assert(world.CurrentCamera,"Camera absente");F.Camera=camera;F.CameraFrame=camera.CFrame
   -- Aim through the native controller's mouse/gamepad ray; verify the water before holding.
   for _=1,3 do
    local desired=Vector3.new(site.target.X-root.Position.X,0,site.target.Z-root.Position.Z).Unit
    local actual=aim(char,root);actual=Vector3.new(actual.X,0,actual.Z).Unit
    local yaw=math.atan2(desired.X,desired.Z)-math.atan2(actual.X,actual.Z)
    camera.CFrame=CFrame.new(camera.CFrame.Position)*CFrame.Angles(0,yaw,0)*camera.CFrame.Rotation
   end
   assert(waterAt(char,fishing.Aim(root.Position,aim(char,root),charge)),"Visee hors de l'eau : aucun lancer")
   assert(tool.Parent==char and fishing.EquippedRod(char)==tool and valid(token,char),"Canne desequipee avant lancer")
   ctx.Status("PECHE : charge Perfect")
   tool:Activate()
   assert(await(token,char,1,function()return visible("Charge")end),"Charge non confirmee par le jeu")
   local target=(flags.PerfectMin:Get()+flags.PerfectMax:Get())/2
   assert(await(token,char,flags.ChargeSeconds:Get()*2+1,function()local value=F.ReadCharge();return value and value>=target and fishing.IsPerfect(value)end),"Jauge Perfect non confirmee : lancer annule")
   tool:Deactivate()
   ctx.Status("PECHE : attente de la touche")
   -- Never click during Waiting: the native controller would cancel the cast.
   local bite=await(token,char,flags.BiteMaxSeconds:Get()+5,function()return visible("Reel")end)
   assert(bite,"Aucune touche confirmee")
   ctx.Status("PECHE : remontée")
   local deadline=os.clock()+flags.ReelTimeoutSeconds:Get()+2
   local interval=1/math.max(1,math.min(12,flags.ReelMaxClicksPerSecond:Get()))
   while visible("Reel")and os.clock()<deadline and valid(token,char)do
    tool:Activate();tool:Deactivate()
    if not await(token,char,interval,function()return not visible("Reel")end)and not valid(token,char)then break end
   end
   if visible("Reel")then error("Remontee interrompue ou expiree")end
  end)
  F.Cancel()
  if not ok then F.RetryAt=os.clock()+10;ctx.Status("PECHE : "..tostring(why))else F.RetryAt=os.clock()+flags.CastCooldown:Get()end
 end
 return F
end