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
    local header=table.clone(m);header.eggs=nil;header.animals=nil;header.mutationConsumables=nil
    local function array(rows)local out={};for _,r in ipairs(rows)do table.insert(out,Http:JSONEncode(r))end;return"["..table.concat(out,",").."]"end
    ctx.Report.Socket:Send(Http:JSONEncode(header):sub(1,-2)..',"eggs":'..array(m.eggs)..',"animals":'..array(m.animals)..',"mutationConsumables":'..array(m.mutationConsumables or{})..'}')
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
 local mutationIds={"Boss","Scrambled","Enchanted","Nitro","Spectral"}
 local waitUntil
 local function hasMutation(record,id)return record.BaseMutation==id or table.find(record.Mutations or{},id)~=nil end
 local function mutationTools()
  local rows={};for _,id in ipairs(mutationIds)do rows[id]={id=id,count=0,tools={}}end
  for _,container in pairs({player:FindFirstChild("Backpack"),player.Character})do
   if container then for _,tool in ipairs(container:GetChildren())do
    if tool:IsA("Tool")and tool:GetAttribute("ItemType")=="MutationConsumable"then
     local id=tool:GetAttribute("MutationId")or"Boss";local r=rows[id];local uses=metric(tool:GetAttribute("Uses"))
     if r and uses and uses>=1 then r.count+=math.floor(uses);table.insert(r.tools,tool)end
    end
   end end
  end
  return rows
 end
 local function mutationMetadata()
  local result={};local stock=mutationTools()
  for _,id in ipairs(mutationIds)do
   local spec=A.MutationCatalog[id]or{};local source=A.MutationFlags[id]
   local chance=id=="Enchanted"and 100 or(source and safe(function()return source:Get()end))
   table.insert(result,{id=id,name=spec.Label or id,count=stock[id].count,successPercent=metric(chance),multiplier=metric(spec.EarningsScalar)})
  end
  return result
 end
 local function ledger()
  if A.MutationLedger then return A.MutationLedger end
  local service=game:GetService("TeleportService")
  local saved=safe(function()return service:GetTeleportSetting("SEAAdminMutationAttempts")end)
  A.MutationLedger=type(saved)=="table"and saved.userId==tostring(player.UserId)and type(saved.entries)=="table"and saved or{userId=tostring(player.UserId),entries={}}
  return A.MutationLedger
 end
 local function saveLedger()
  game:GetService("TeleportService"):SetTeleportSetting("SEAAdminMutationAttempts",ledger())
 end
 local function releaseMutationTool()
  local tool=A.MutationTool;A.MutationTool=nil
  if tool and player.Character and tool.Parent==player.Character then
   local humanoid=player.Character:FindFirstChildOfClass("Humanoid");if humanoid then pcall(function()humanoid:UnequipTools()end)end
  end
 end
 function A.ApplyMutation(uid,id,maxAttempts,manual)
  assert(A.Initialized and not A.Destroyed,"Admin indisponible")
  local record=assert(ownedEggs()[uid],"Oeuf absent")
  assert(record.Placement and not record.Locked,"Oeuf non place ou verrouille")
  assert(not hasMutation(record,id),"Mutation deja presente")
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  assert(root and A.Plot.ContainsLocalPoint(root.Position),"Rejoins ton plot pour appliquer les mutations")
  local stock=mutationTools()[id];assert(stock and stock.count>0,"Consommable absent")
  local key=uid..":"..id;local entries=ledger().entries;local entry=entries[key]or{count=0}
  assert(not entry.blocked and entry.count<maxAttempts,"Limite atteinte ou resultat incertain")
  if not entries[key]then local n=0;for _ in pairs(entries)do n+=1 end;assert(n<2000,"Journal des essais plein")end
  local character=assert(player.Character,"Personnage absent");local humanoid=assert(character:FindFirstChildOfClass("Humanoid"),"Personnage absent")
  local tool=stock.tools[1];A.MutationTool=tool;humanoid:EquipTool(tool)
  assert(waitUntil(function()return tool.Parent==character end,3),"Consommable non equipe")
  if A.Destroyed or(manual and ctx.Busy()or not manual and not ctx.CanMutate())then error("Mutation interrompue")end
  record=assert(ownedEggs()[uid],"Oeuf absent");assert(record.Placement and not hasMutation(record,id),"Oeuf modifie")
  ctx.MutationLock(true)
  -- Reserve and persist BEFORE dispatch: an interrupted request must never be retried blindly.
  entry.count+=1;entry.blocked=true;entries[key]=entry;saveLedger()
  A.Dispatched=true
  A.MutationStatus="Essai "..entry.count.."/"..maxAttempts.." : "..id.." sur "..uid
  local ok,result=pcall(function()return A.Remotes.BossMastery.AskUseMutationConsumable:InvokeServer(uid)end)
  releaseMutationTool()
  assert(ok and type(result)=="table"and result.Success==true,"Resultat mutation non confirme : aucune relance")
  assert(result.MutationId==nil or result.MutationId==id,"Mutation retournee inattendue")
  if result.Mutated==true then
   assert(waitUntil(function()local r=ownedEggs()[uid];return r and hasMutation(r,id)end,12),"Mutation en attente de synchronisation")
   A.MutationStatus=id.." appliquee a "..uid
  elseif result.Mutated==false then A.MutationStatus=id.." : essai echoue "..entry.count.."/"..maxAttempts
  else error("Resultat mutation incomplet : aucune relance")end
  entry.blocked=false;saveLedger();A.Signature=nil
  return true
 end
 function A.MutateNext()
  if A.Busy or shared.__SEAAdminRequestLock or not A.Initialized or not ctx.CanMutate()then return true end
  local options=ctx.GetOptions();if not options.AutoMutations then return false end
  if os.clock()<(A.NextMutationAt or 0)then return true end
  local candidates={};for uid,record in pairs(ownedEggs())do
   if record.Placement and not record.Locked then
    local item=safe(A.EggRecords.ToAssetItemData,record);local rate=item and metric(safe(A.Earnings.RatePerSecond,item))
    if rate then table.insert(candidates,{uid=uid,record=record,rate=rate})end
   end
  end
  table.sort(candidates,function(a,b)return a.rate>b.rate end)
  local stock=mutationTools()
  for _,candidate in ipairs(candidates)do for _,id in ipairs(mutationIds)do
   local prefix="Mutation"..id;local entry=ledger().entries[candidate.uid..":"..id]
   if options[prefix.."Enabled"]and candidate.rate>options[prefix.."Min"]and stock[id].count>0 and not hasMutation(candidate.record,id)
    and(not entry or not entry.blocked and entry.count<options[prefix.."Attempts"])then
    A.NextMutationAt=os.clock()+15
    local lock={mutation=true};A.Busy=true;shared.__SEAAdminRequestLock=lock
    local ok,why=pcall(A.ApplyMutation,candidate.uid,id,options[prefix.."Attempts"])
    releaseMutationTool();ctx.MutationLock(false);A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
    if not ok then A.MutationStatus=tostring(why):sub(1,500);warn("[SEA Admin] "..A.MutationStatus)end
    pcall(A.Publish,true);return true
   end
  end end
  return false
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
  return {eggs=eggs,animals=animals,automationStatus=ctx.GetStatus and tostring(ctx.GetStatus()):sub(1,500)or nil,mutationConsumables=mutationMetadata(),mutationStatus=A.MutationStatus,stats={money=metric(p.Money),speedPower=metric(safe(A.Speed.ReadProjected))or metric(p.SpeedPower),
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
 waitUntil=function(fn,seconds)
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
  if m.action=="egg.mutate"then
   local entry=ledger().entries[uid..":"..tostring(m.mutationId)]
   return A.ApplyMutation(uid,m.mutationId,(entry and entry.count or 0)+1,true)
  elseif m.action=="egg.open"then
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
   releaseMutationTool()
   ctx.MutationLock(false)
   local result={version=1,type="admin.command.result",requestId=m.requestId,
    status=ok and confirmed and"confirmed"or(A.Dispatched and"unknown"or"rejected"),
    message=ok and confirmed and(m.action=="egg.mutate"and A.MutationStatus or"Action confirmee par le jeu")or tostring(ok and"Confirmation en attente : aucune relance automatique"or confirmed):sub(1,500)}
   A.Seen[m.requestId]=result;A.SeenOrder=A.SeenOrder or{};table.insert(A.SeenOrder,m.requestId)
   if #A.SeenOrder>100 then A.Seen[table.remove(A.SeenOrder,1)]=nil end
   A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
   send(result);pcall(A.Publish,true)
  end)
 end
 function A.Destroy()A.Destroyed=true;releaseMutationTool();ctx.Report.AdminReceive=nil end
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
   A.MutationCatalog=module("Shared.Modules.Mutations.Catalog");A.MutationFlags={}
   for id,spec in pairs({Boss={"Shared.Flags.BossMasteryFlags","MutationConsumableSuccessPercent"},Scrambled={"Shared.Flags.ScrambleMutationFlags","SuccessPercent"},Nitro={"Shared.Flags.RaceRallyFlags","NitroSuccessPercent"},Spectral={"Shared.Flags.TrainEventFlags","SpectralSuccessPercent"}})do
    local flags=safe(module,spec[1]);A.MutationFlags[id]=flags and flags[spec[2]]
   end
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
