return function(ctx)
 local player=game:GetService("Players").LocalPlayer
 local RS=game:GetService("ReplicatedStorage")
 local util=require(RS.Shared.Util.AlienLagoon)
 local flags=require(RS.Shared.Flags.AlienLagoonFlags)
 local save=require(RS.Shared.Save)
 local rodTiers=require(RS.Shared.Util.AlienRods)
 local position=CFrame.new(-14083.5810546875,13.71351146697998,16012.9619140625,-0.9973205327987671,-1.742297195406195e-9,-0.07315535843372345,-7.2476611379102e-9,1,7.49903250607531e-8,0.07315535843372345,7.531959766993168e-8,-0.9973205327987671)
 local cameraFrame=CFrame.new(-14084.6669921875,20.69989776611328,16001.783203125,-0.995311439037323,0.04245220497250557,-0.08690740913152695,0,0.8985306024551392,0.43891090154647827,0.09672169387340546,0.4368530511856079,-0.8943178653717041)
 local focus=CFrame.new(-14083.5810546875,15.21351146697998,16012.9619140625)
 local function waitFor(test,seconds)
  local deadline=os.clock()+seconds
  repeat
   assert(ctx.Active(),"Pêche interrompue")
   local result=test()
   if result then return result end
   task.wait(.1)
  until os.clock()>=deadline
  return nil
 end
 local function travel(destination,viaStart,pathfinding,label)
  local ok,reason=ctx.Move(destination,viaStart,ctx.Active,pathfinding)
  assert(ok,label.." : "..tostring(reason or "raison indisponible"))
 end
 local function chooseLagoon()
  local gui=player:FindFirstChildOfClass("PlayerGui")
  local choices=gui and gui:FindFirstChild("NpcChoices")
  if not choices then return end
  for _,label in ipairs(choices:GetDescendants())do
   if label:IsA("TextLabel")and(label:GetAttribute("Text")==util.FerrymanLines.Choices.Go or label.Text==util.FerrymanLines.Choices.Go)then
    local row=label
    while row and row.Parent~=choices:FindFirstChild("Choices")do row=row.Parent end
    return row and row:FindFirstChildWhichIsA("ImageButton",true)
   end
  end
 end
 if ctx.Exit then
  if player:GetAttribute("InAlienLagoon")~=true then return true end
  local marker=assert(util.Marker(util.Markers.Return),"Retour du lagon introuvable")
  ctx.Status("Pêche : retour vers le bateau")
  travel(marker.Position,false,true,"Trajet du retour interrompu")
  assert(ctx.Active(),"Retour interrompu")
  local direction,message=require(RS.Shared.Remotes).AlienLagoon.Request:InvokeServer()
  assert(direction=="Exit",message or "Retour refusé")
  assert(waitFor(function()return player:GetAttribute("InAlienLagoon")~=true end,30),"Sortie du lagon non confirmée")
  assert(waitFor(function()
   local camera=workspace.CurrentCamera
   return camera and camera.CameraType~=Enum.CameraType.Scriptable
  end,15),"Fin du retour en bateau non confirmée")
  return true
 end
 if player:GetAttribute("InAlienLagoon")~=true then
  local profile=assert(save.Peek(),"Profil indisponible")
  assert(flags.Enabled:Get(),"Lagon fermé")
  assert((profile.FishingMastery and profile.FishingMastery.Caught or 0)>=flags.FishRequired:Get(),"Nombre de prises insuffisant pour le lagon")
  assert(util.FastEnough(profile.SpeedPower),"Vitesse insuffisante pour le lagon")
  local npc=assert(util.Ferryman(),"Alien Ferryman introuvable")
  local root=assert(npc.PrimaryPart,"Ferryman sans position")
  ctx.Status("Pêche : trajet vers Alien Ferryman")
  travel(root.Position,true,false,"Trajet Ferryman interrompu")
  assert(ctx.Active(),"Pêche interrompue")
  local prompt=assert(npc:FindFirstChild(util.TalkPromptName,true),"Prompt Talk introuvable")
  local env=type(getgenv)=="function"and getgenv()or getfenv()
  assert(type(env.fireproximityprompt)=="function"and type(env.firesignal)=="function","Activation Talk ou dialogue indisponible")
  ctx.Status("Pêche : Talk, attente du choix Go to Lagoon")
  env.fireproximityprompt(prompt)
  local button=assert(waitFor(chooseLagoon,25),"Choix Go to Lagoon non affiché")
  env.firesignal(button.Activated)
  ctx.Status("Pêche : trajet en bateau vers le lagon")
  assert(waitFor(function()return player:GetAttribute("InAlienLagoon")==true end,30),"Arrivée au lagon non confirmée")
 end
 -- Let the native ferry restore control and camera before taking the fishing pose.
 assert(waitFor(function()
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local camera=workspace.CurrentCamera
  return root and camera and camera.CameraType~=Enum.CameraType.Scriptable
 end,15),"Fin de transition du lagon non confirmée")
 ctx.Status("Pêche : trajet vers la position enregistrée")
 travel(position.Position,false,false,"Point de pêche non rejoint")
 assert(ctx.Active()and player:GetAttribute("InAlienLagoon")==true,"Pêche interrompue ou sortie du lagon")
 local character=assert(player.Character,"Personnage absent")
 local root=assert(character:FindFirstChild("HumanoidRootPart"),"Personnage absent")
 root.CFrame=position
 local humanoid=assert(character:FindFirstChildOfClass("Humanoid"),"Humanoid absent")
 local best,tier=nil,0
 for _,container in pairs({character,player:FindFirstChildOfClass("Backpack")})do
  for _,tool in ipairs(container:GetChildren())do
   if tool:IsA("Tool")and tool:GetAttribute("GhostDogRod")==true then
    local rank=rodTiers.TierOf(tool:GetAttribute("GearName")or tool:GetAttribute("DisplayName")or tool.Name)
    if rank and rank>tier then best,tier=tool,rank end
   end
  end
 end
 assert(best,"Aucune canne Alien disponible")
 if best.Parent~=character then humanoid:EquipTool(best)end
 assert(waitFor(function()return best.Parent==character end,3),"Canne non équipée")
 local camera=assert(workspace.CurrentCamera,"Caméra indisponible")
 camera.CFrame=cameraFrame;camera.Focus=focus;camera.FieldOfView=70
 ctx.Status("Pêche : "..tostring(best:GetAttribute("GearName")or best.Name).." équipée, lancer prêt")
 return true
end

