-- Typed Render bridge. No GUI, arbitrary code commands or observer automation.
return function(ctx)
 local A={Destroyed=false,Busy=false,Revision=0,Seen={},Session=ctx.Report.SessionId}
 local player=game:GetService("Players").LocalPlayer
 local RS=game:GetService("ReplicatedStorage")
 local Http=game:GetService("HttpService")
 local function module(path)
  local node=RS
  for name in path:gmatch("[^.]+")do node=node:WaitForChild(name,30);assert(node,"Module absent : "..path)end
  return require(node)
 end
 local function safe(fn,...)
  if type(fn)~="function"then return nil end
  local ok,value=pcall(fn,...);return ok and value or nil
 end
 local function metric(v)return type(v)=="number"and v==v and v>=0 and v<math.huge and v or nil end
 local function send(m)
  if A.Destroyed or not ctx.Report.Ready or not ctx.Report.Socket then return false end
  local ok=pcall(function()
   if m.type=="admin.inventory.snapshot"then
    local header=table.clone(m);header.eggs=nil;header.animals=nil
    local function array(rows)local out={};for _,r in ipairs(rows)do table.insert(out,Http:JSONEncode(r))end;return"["..table.concat(out,",").."]"end
    ctx.Report.Socket:Send(Http:JSONEncode(header):sub(1,-2)..',"eggs":'..array(m.eggs)..',"animals":'..array(m.animals)..'}')
   else ctx.Report.Socket:Send(Http:JSONEncode(m))end
  end)
  return ok
 end
 local function profile()return assert(A.Save.Peek(),"Profil indisponible")end
 local function ownedEggs()
  local rows={}
  for uid,saved in pairs(profile().EggInventory or {})do
   local record=safe(A.EggRecords.Decode,saved)
   if record then record.Uid=uid;rows[uid]=record end
  end
  for uid,record in pairs(A.EggState.ReadOwnerEggs(player.UserId)or{})do rows[uid]=record end
  return rows
 end
 local function equipped()
  local ids={}
  for _,uid in ipairs(profile().EquippedAssets or {})do ids[uid]=true end
  for _,row in pairs(A.Roster.ReadOwnerPen(player.UserId)or{})do if row.UID then ids[row.UID]=true end end
  return ids
 end
 local function animal(uid)
  local saved=profile().Inventory and profile().Inventory[uid]
  return saved and A.Items.Decode(saved),saved
 end
 local function row(uid,item,location,isEgg,record)
  local category=isEgg and record.AssetCategory or item.Category
  local config=A.Assets.Directory[category]or{}
  local rarity=config.Rarity
  if type(rarity)=="table"then rarity=rarity._id or rarity.Id or rarity.Name end
  local seconds,grown
  if isEgg and location=="plot"then seconds,grown=ctx.Countdown(record)end
  return {uid=uid,category=category,name=config.DisplayName or category,rarity=tostring(rarity or"Unknown"),location=location,
   mutations=type(item.Mutations)=="table"and#item.Mutations>0 and table.clone(item.Mutations)or nil,baseMutation=record and record.BaseMutation or item.BaseMutation,
   incomePerSecond=metric(safe(A.Earnings.RatePerSecond,item)),weightKg=metric(safe(A.Items.WeightKg,item)),
   sellValue=metric(isEgg and safe(A.EggRecords.SellPrice,record)or safe(A.Items.SalePrice,item)),
   remainingSeconds=seconds,ready=grown==true,locked=record and record.Locked==true or false}
 end
 function A.Snapshot()
  local p=profile();local eggs,animals={},{};local worn=equipped();local animalRows={}
  for uid,record in pairs(ownedEggs())do
   local item=safe(A.EggRecords.ToAssetItemData,record)
   if item then table.insert(eggs,row(uid,item,record.Placement and "plot"or"backpack",true,record))end
  end
  for uid,saved in pairs(p.Inventory or{})do
   local item=safe(A.Items.Decode,saved)
   if item then
    local value=row(uid,item,worn[uid]and"plot"or"backpack",false,saved)
    value.locked=saved.Locked==true or table.find(p.FusionSlots or{},uid)~=nil
    animalRows[uid]=value
   end
  end
  for _,record in pairs(A.Roster.ReadOwnerPen(player.UserId)or{})do
   if type(record.UID)=="string"and type(record.ItemData)=="table"then
    local value=row(record.UID,record.ItemData,"plot",false,record)
    value.incomePerSecond=metric(record.MoneyPerSecond)or value.incomePerSecond
    animalRows[record.UID]=value
   end
  end
  for _,value in pairs(animalRows)do table.insert(animals,value)end
  table.sort(eggs,function(a,b)return a.uid<b.uid end);table.sort(animals,function(a,b)return a.uid<b.uid end)
  local income=metric(safe(A.Items.ProfileIncomePerSecond,player,p))
  local offline=A.Constants.OFFLINE_ASSETS or{}
  local duration,multiplier=metric(offline.MAX_DURATION_SECONDS),metric(offline.MONEY_RATE_MULTIPLIER)
  return {eggs=eggs,animals=animals,stats={money=metric(p.Money),speedPower=metric(safe(A.Speed.ReadProjected))or metric(p.SpeedPower),
   incomePerSecond=income,offlinePerDay=income and duration and multiplier and income*duration*multiplier,
   offlineDurationSeconds=duration,offlineRateMultiplier=multiplier}}
 end
 function A.Publish(force)
  if not A.Initialized or not ctx.Ready()or not ctx.Report.SettingsAllowed then return end
  local data=A.Snapshot();local signature=Http:JSONEncode(data)
  if not force and signature==A.Signature and os.clock()-(A.SentAt or 0)<20 then return end
  local m=table.clone(data);m.version=1;m.type="admin.inventory.snapshot";m.sessionId=A.Session;m.revision=A.Revision+1
  if send(m)then A.Revision=m.revision;A.Signature=signature;A.SentAt=os.clock()end
 end
 local function waitUntil(fn,seconds)
  local deadline=os.clock()+seconds
  repeat if A.Destroyed then error("Admin arrete")end;if fn()then return true end;task.wait(.1)until os.clock()>=deadline
  return false
 end
 local function request(remote,...)
  A.Dispatched=true
  local accepted,why=remote:InvokeServer(...)
  assert(accepted==true,tostring(why or "Action refusee par le jeu"))
  return accepted,why
 end
 local function plant(uid)
  local record=assert(ownedEggs()[uid],"Oeuf absent");assert(not record.Placement,"Oeuf deja place")
  local plot=assert(A.Plot.ResolvePlot(),"Plot indisponible")
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  assert(root and A.Plot.ContainsLocalPoint(root.Position),"Rejoins ton plot pour placer cet oeuf")
  local frame=assert(ctx.FindSpot(plot,ownedEggs(),{}),"Aucun emplacement libre")
  local worn,why=A.EggState.WearEggTool(uid);assert(worn==true,why)
  A.Dispatched=true;local accepted,reason=A.EggState.PlantEgg(uid,frame);assert(accepted==true,reason)
  return waitUntil(function()local e=ownedEggs()[uid];return e and e.Placement~=nil end,15)
 end
 local function walkToFusion()
  local machine=workspace:FindFirstChild("World")and workspace.World:FindFirstChild("Machines")
  machine=machine and machine:FindFirstChild("FuseMachine");machine=machine and machine:FindFirstChild("Machine")
  assert(machine and machine:IsA("BasePart"),"Machine fusion indisponible")
  local character=assert(player.Character,"Personnage indisponible")
  local root=assert(character:FindFirstChild("HumanoidRootPart"),"Personnage indisponible")
  local humanoid=assert(character:FindFirstChildOfClass("Humanoid"),"Personnage indisponible")
  if (root.Position-machine.Position).Magnitude<14 then return end
  local path=game:GetService("PathfindingService"):CreatePath()
  path:ComputeAsync(root.Position,machine.Position+machine.CFrame.LookVector*7)
  assert(path.Status==Enum.PathStatus.Success,"Aucun chemin vers la machine")
  local deadline=os.clock()+45
  for _,waypoint in ipairs(path:GetWaypoints())do
   assert(os.clock()<deadline and player.Character==character and humanoid.Health>0 and not A.Destroyed,"Trajet interrompu")
   if waypoint.Action==Enum.PathWaypointAction.Jump then humanoid.Jump=true end
   humanoid:MoveTo(waypoint.Position)
   assert(waitUntil(function()return(root.Position-waypoint.Position).Magnitude<5 end,5),"Chemin bloque")
  end
 end
 local function fuse(uids)
  assert(type(uids)=="table"and#uids==3,"Trois animaux requis")
  local p=profile();assert(not p.FusionLocked and p.FusionEggReward==false and not next(p.FusionSlots or{}),"Machine occupee")
  local worn=equipped();local category,temporary;local selected={}
  for _,uid in ipairs(uids)do
   assert(not selected[uid]and not worn[uid],"Animal indisponible");selected[uid]=true
   local item,saved=animal(uid);assert(item and saved,"Animal absent")
   assert(A.Kernel.MayEnterFuse(uid,saved,category,false,temporary),"Animal incompatible avec la fusion")
   category=category or item.Category;if temporary==nil then temporary=saved.CreatorTemporary==true end
  end
  walkToFusion()
  local loaded={};local committed=false;local before=table.clone(profile().EggInventory or{})
  local ok,reason=pcall(function()
   for _,uid in ipairs(uids)do
    local _,saved=animal(uid);assert(saved and not equipped()[uid],"Animal devenu indisponible")
    request(A.Remotes.Fusery.LoadPet,uid,false);table.insert(loaded,uid)
    assert(waitUntil(function()return table.find(profile().FusionSlots or{},uid)end,5),"Chargement non confirme")
   end
   local slots=profile().FusionSlots or{};assert(#slots==3,"Selection modifiee")
   for _,uid in ipairs(slots)do assert(selected[uid],"Selection modifiee")end
   A.Dispatched=true
   local accepted,why,reward=A.Remotes.Fusery.BeginFuse:InvokeServer();assert(accepted==true,why);committed=true
   assert(A.FuseTypes.FuseResult(reward),"Resultat fusion invalide")
   A.Signals.FuseStarted:Fire(reward)
   assert(waitUntil(function()
    ctx.AcknowledgeReward(reward)
    local latest=profile()
    for _,uid in ipairs(uids)do if latest.Inventory[uid]then return false end end
    for uid in pairs(latest.EggInventory or{})do if not before[uid]then return true end end
    return false
   end,25),"Resultat fusion en attente")
  end)
  if not ok and not committed then
   for _,uid in ipairs(loaded)do if table.find(profile().FusionSlots or{},uid)then pcall(function()A.Remotes.Fusery.EjectPet:InvokeServer(uid)end)end end
  end
  assert(ok,reason);return true
 end
 function A.Execute(m)
  if m.action=="settings.update"then
   assert(ctx.Report.SettingsRevision==m.settingsRevision,"Parametres modifies dans le jeu")
   assert(ctx.SetOptions(m.options),"Parametres invalides");return true
  elseif m.action=="automation.set"then ctx.SetEnabled(m.enabled);return true end
  assert(not ctx.Busy(),"Coupe AUTO et attends la fin de l’action en cours avant une action manuelle")
  local uid=m.uid
  if m.action=="egg.open"then
   local record=assert(ownedEggs()[uid],"Oeuf absent");assert(record.Placement,"Oeuf non place")
   local _,grown=ctx.Countdown(record);assert(grown,"Oeuf pas encore pret")
   A.Dispatched=true;local accepted,why=A.Renderer.ActivateLocalEgg(uid);assert(accepted==true,why)
   return waitUntil(function()return ownedEggs()[uid]==nil end,15)
  elseif m.action=="egg.place"then return plant(uid)
  elseif m.action=="egg.sell"or m.action=="animal.sell"then
   local isEgg=m.action=="egg.sell"
   if isEgg then local r=assert(ownedEggs()[uid],"Oeuf absent");assert(not r.Placement,"Oeuf place")
   else local item,saved=animal(uid);assert(item and saved and not equipped()[uid]and not saved.Locked,"Animal indisponible");assert(not table.find(profile().FusionSlots or{},uid),"Animal en fusion")end
   A.Dispatched=true;A.Remotes.PetSatchel.SellSelection:FireServer({Eggs=isEgg and{uid}or{},Assets=not isEgg and{uid}or{}})
   return waitUntil(function()return isEgg and ownedEggs()[uid]==nil or not isEgg and profile().Inventory[uid]==nil end,15)
  elseif m.action=="animal.fuse"then return fuse(m.uids)
  elseif m.action=="equip.best"then
   request(A.Remotes.Haul.WearBest);return true
  end
  error("Commande inconnue")
 end
 function A.Receive(m)
  if m.version~=1 or type(m.requestId)~="string"or# m.requestId>100 then return end
  if A.Seen[m.requestId]then send(A.Seen[m.requestId]);return end
  if A.Busy or shared.__SEAAdminRequestLock or not A.Initialized or not ctx.Report.SettingsAllowed then
   send({version=1,type="admin.command.result",requestId=m.requestId,status="rejected",message="Admin indisponible ou action en cours"});return
  end
  A.Busy=true
  local lock={requestId=m.requestId};shared.__SEAAdminRequestLock=lock
  task.spawn(function()
   A.Dispatched=false
   local ok,confirmed=pcall(A.Execute,m)
   local result={version=1,type="admin.command.result",requestId=m.requestId,
    status=ok and confirmed and"confirmed"or(A.Dispatched and"unknown"or"rejected"),
    message=ok and confirmed and"Action confirmee par le jeu"or tostring(ok and"Confirmation en attente : aucune relance automatique"or confirmed):sub(1,500)}
   A.Seen[m.requestId]=result;A.SeenOrder=A.SeenOrder or{};table.insert(A.SeenOrder,m.requestId)
   if #A.SeenOrder>100 then A.Seen[table.remove(A.SeenOrder,1)]=nil end
   A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
   send(result);pcall(A.Publish,true)
  end)
 end
 function A.Destroy()A.Destroyed=true;ctx.Report.AdminReceive=nil end
 ctx.Report.AdminReceive=A.Receive
 task.spawn(function()
  while not A.Destroyed and not ctx.Ready()do task.wait(.5)end
  if A.Destroyed then return end
  local ok,why=pcall(function()
   A.Save=module("Shared.Save");A.EggState=module("Client.EggState");A.EggRecords=module("Shared.Util.EggRecords")
   A.Items=module("Shared.Util.AssetItems");A.Assets=module("Data.Assets");A.Earnings=module("Shared.Util.AssetEarnings")
   A.Constants=module("Shared.Globals.Constants");A.Roster=module("Client.AssetRoster");A.Plot=module("Client.PlotState")
   A.Speed=module("Client.SpeedPowerProjection");A.Remotes=module("Shared.Remotes");A.Renderer=module("Shared.Eggs.PlacedEggRenderer")
   A.Kernel=module("Shared.Util.FuseKernel");A.Signals=module("Client.FuseMachineSignals");A.FuseTypes=module("Shared.Types.FuseMachine")
   A.Initialized=true
  end)
  if not ok then warn("[SEA Admin] "..tostring(why));return end
  while not A.Destroyed and ctx.Ready()do
   local sent,reason=pcall(A.Publish,false);if not sent then warn("[SEA Admin] Snapshot : "..tostring(reason))end
   task.wait(5)
  end
 end)
 return A
end
