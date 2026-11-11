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
  if ctx.LocalOnly then if ctx.OnResult and m.type=="admin.command.result"then ctx.OnResult(m)end;return true end
  if A.Destroyed or not ctx.Report.Ready or not ctx.Report.Socket then return false end
  local ok=pcall(function()
   if m.type=="admin.inventory.snapshot"then
    local header=table.clone(m);header.eggs=nil;header.animals=nil;header.mutationConsumables=nil;header.imageCatalog=nil
    local function array(rows)local out={};for _,r in ipairs(rows)do table.insert(out,Http:JSONEncode(r))end;return"["..table.concat(out,",").."]"end
    ctx.Report.Socket:Send(Http:JSONEncode(header):sub(1,-2)..',"eggs":'..array(m.eggs)..',"animals":'..array(m.animals)..',"mutationConsumables":'..array(m.mutationConsumables or{})..',"imageCatalog":'..array(m.imageCatalog or{})..'}')
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
 local mutationIds={"Boss","Scrambled","Enchanted","Nitro","Spectral","Musical","Alien","DarkMatter"}
 local waitUntil
 local function hasMutation(record,id)return record.BaseMutation==id or table.find(record.Mutations or{},id)~=nil end
 local function mutationTools()
  local rows={};local seen={};for _,id in ipairs(mutationIds)do rows[id]={id=id,count=0,tools={}}end
  for _,container in pairs({player:FindFirstChild("Backpack"),player.Character})do
   if container then for _,tool in ipairs(container:GetChildren())do
    if not seen[tool]and tool:IsA("Tool")and tool:GetAttribute("ItemType")=="MutationConsumable"then
     seen[tool]=true
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
  if A.Destroyed or(manual and not(ctx.ManualCanContinue and ctx.ManualCanContinue()or not ctx.BeginManual and not ctx.Busy())or not manual and not ctx.CanMutate())then error("Mutation interrompue")end
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
    if os.clock()<(A.NextMutationAt or 0)then return true end
    A.NextMutationAt=os.clock()+2
    local lock={mutation=true};A.Busy=true;shared.__SEAAdminRequestLock=lock
    local ok,why=pcall(A.ApplyMutation,candidate.uid,id,options[prefix.."Attempts"])
    releaseMutationTool();ctx.MutationLock(false);A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
    if not ok then A.MutationStatus=tostring(why):sub(1,500);warn("[SEA Admin] "..A.MutationStatus)end
    pcall(A.Publish,true);return true
   end
  end end
  return false
 end
 function A.ShouldHoldEgg(uid)
  local options=ctx.GetOptions();if not options.AutoMutations then return false end
  if not A.Initialized then return true end
  local record=ownedEggs()[uid];if not record or not record.Placement then return false end
  local item=safe(A.EggRecords.ToAssetItemData,record);local rate=item and metric(safe(A.Earnings.RatePerSecond,item));if not rate then return false end
  local stock=mutationTools()
  for _,id in ipairs(mutationIds)do
   local prefix="Mutation"..id;local entry=ledger().entries[uid..":"..id]
   if options[prefix.."Enabled"]and rate>options[prefix.."Min"]and stock[id].count>0 and not hasMutation(record,id)and(not entry or not entry.blocked and entry.count<options[prefix.."Attempts"])then return true end
  end
  return false
 end
 local function imageId(value)
  if type(value)=="number"and value>0 and value<math.huge and value%1==0 then value=string.format("%.0f",value)end
  if type(value)~="string"then return nil end
  local id=value:match("^rbxassetid://(%d+)$")or value:match("^(%d+)$")or value:match("[?&]id=(%d+)")
  return id and#id<=20 and id:match("^[1-9]%d*$")and id or nil
 end
 local function catalogImage(category,config)
  return{category=category,name=config.DisplayName or category,eggImageAssetId=config.Egg and imageId(config.Egg.Icon),animalImageAssetId=imageId(config.Icon)}
 end
 local function row(uid,item,location,isEgg,record)
  local category=isEgg and record.AssetCategory or item.Category
  local config=A.Assets.Directory[category]or{}
  local rarity=config.Rarity
  if type(rarity)=="table"then rarity=rarity._id or rarity.Id or rarity.Name end
  local seconds,grown
  if isEgg and location=="plot"then seconds,grown=ctx.Countdown(record)end
  return {uid=uid,category=category,name=config.DisplayName or category,rarity=tostring(rarity or"Unknown"),location=location,
   eggImageAssetId=config.Egg and imageId(config.Egg.Icon),animalImageAssetId=imageId(config.Icon),
   mutations=type(item.Mutations)=="table"and#item.Mutations>0 and table.clone(item.Mutations)or nil,baseMutation=record and record.BaseMutation or item.BaseMutation,
   incomePerSecond=metric(safe(A.Earnings.RatePerSecond,item)),weightKg=metric(safe(A.Items.WeightKg,item)),
   sellValue=metric(isEgg and safe(A.EggRecords.SellPrice,record)or safe(A.Items.SalePrice,item)),
   remainingSeconds=seconds,ready=grown==true,locked=record and record.Locked==true or false}
 end
 function A.FieldSnapshot()
  local rows={}
  for _,record in ipairs(ctx.FieldRecords and ctx.FieldRecords()or{})do
   local item=safe(A.EggRecords.ToAssetItemData,record)
   if item then local r=row(record.Uid,item,"field",true,record);table.insert(rows,r)end
  end
  return rows
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
  return {fishingEnabled=not ctx.LocalOnly and A.Fishing==true,eggs=eggs,animals=animals,imageCatalog=A.ImageCatalog,automationStatus=ctx.GetStatus and tostring(ctx.GetStatus()):sub(1,500)or nil,mutationConsumables=mutationMetadata(),mutationStatus=A.MutationStatus,stats={money=metric(p.Money),speedPower=metric(safe(A.Speed.ReadProjected))or metric(p.SpeedPower),
   incomePerSecond=income,offlinePerDay=income and duration and multiplier and income*duration*multiplier,
   offlineDurationSeconds=duration,offlineRateMultiplier=multiplier}}
 end
 function A.Publish(force)
  if ctx.LocalOnly then return false end
  if not A.Initialized or not ctx.Ready()or not ctx.Report.SettingsAllowed or not ctx.Report.Ready or not ctx.Report.Socket then return end
  if A.SentSocket~=ctx.Report.Socket then A.SentAt=nil;A.Signature=nil end
  -- Gameplay conditions use the local Save; bursts only queue the latest dashboard state.
  local remaining=2-(os.clock()-(A.SentAt or -math.huge))
  if remaining>0 then
   if not A.SnapshotQueued then
    A.SnapshotQueued=true
    task.delay(remaining,function()A.SnapshotQueued=false;if not A.Destroyed then pcall(A.Publish,false)end end)
   end
   return false
  end
  local data=A.Snapshot();local signature=Http:JSONEncode(data)
  if signature==A.Signature and os.clock()-(A.SentAt or 0)<20 then return false end
  local m=table.clone(data);m.version=1;m.type="admin.inventory.snapshot";m.sessionId=A.Session;m.revision=A.Revision+1
  if send(m)then A.Revision=m.revision;A.Signature=signature;A.SentAt=os.clock();A.SentSocket=ctx.Report.Socket end
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
  if ctx.ManualCanContinue then assert(ctx.ManualCanContinue(),"Placement interrompu : priorite au vol")end
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
   if ctx.ManualCanContinue then assert(ctx.ManualCanContinue(),"Trajet interrompu : priorite au vol")end
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
    if ctx.ManualCanContinue then assert(ctx.ManualCanContinue(),"Fusion differee : priorite au vol")end
    local _,saved=animal(uid);assert(saved and not equipped()[uid],"Animal devenu indisponible")
    request(A.Remotes.Fusery.LoadPet,uid,false);table.insert(loaded,uid)
    assert(waitUntil(function()return table.find(profile().FusionSlots or{},uid)end,5),"Chargement non confirme")
   end
   local slots=profile().FusionSlots or{};assert(#slots==3,"Selection modifiee")
   for _,uid in ipairs(slots)do assert(selected[uid],"Selection modifiee")end
   A.Dispatched=true
   if ctx.ManualCanContinue then assert(ctx.ManualCanContinue(),"Fusion differee : priorite au vol")end
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
 -- Cash upgrades share one request slot across reloads.
 local progression=shared.__SEAProgressionState
 if type(progression)~="table"or progression.UserId~=player.UserId then
  progression={UserId=player.UserId,RetryAt={}};shared.__SEAProgressionState=progression
 end
 function A.ProgressPending()return progression.Pending~=nil end
 function A.ProgressTravelling()return progression.Pending and progression.Pending.Moving==true or false end
 local function progressionNotice(text)
  if ctx.InventoryNotice then ctx.InventoryNotice(text)end
 end
 local function progressionModules()
  if A.ProgressModules then return A.ProgressModules end
  local function find(path)
   local node=RS;for name in path:gmatch("[^.]+")do node=node and node:FindFirstChild(name)end
   assert(node,"Module progression absent : "..path);return require(node)
  end
  local modules={Base=find("Client.BaseUpgrade"),Treadmill=find("Controllers.GUI.TreadmillUpgradeController.Client")}
  A.ProgressModules=modules;return modules
 end
 local function progressNextImpl()
  if A.Destroyed or not A.Initialized or A.Busy or shared.__SEAAdminRequestLock or progression.Pending or A.ManualPending or not ctx.CanProgression or not ctx.CanProgression()then return false end
  if progression.Unknown and progression.Unknown.kind=="craft"then progression.Unknown=nil end
  if progression.Unknown then
   if safe(progression.Unknown.confirm)then progression.Unknown=nil
   else progressionNotice("Upgrade incertain : attente de confirmation, aucun renvoi");return false end
  end
  local options=ctx.GetOptions()
  if not options.AutoPlotUpgrade and not options.AutoTreadmillUpgrade then return false end
  if os.clock()<(A.ProgressModuleRetryAt or 0)then return false end
  local ok,mods=pcall(progressionModules)
  if not ok then A.ProgressModuleRetryAt=os.clock()+30;progressionNotice(tostring(mods));return false end
  if mods.Base.Transition and mods.Base.Transition.IsPlaying()then return false end
  local p=profile();local kind,dispatch,confirm
  local function ready(id)return os.clock()>=(progression.RetryAt[id]or 0)end
  if options.AutoPlotUpgrade and ready("plot")and mods.Base.IsNextTierAffordable(p)then
   local before=p.BaseUpgradeLevel
   kind="plot";dispatch=mods.Base.PurchaseNextTier
   confirm=function()return profile().BaseUpgradeLevel>before end
  elseif options.AutoTreadmillUpgrade and ready("treadmill")and(p.BaseUpgradeLevel or 0)>0 and mods.Treadmill.CanAffordNext(p)then
   local before=p.TreadmillUpgradeLevel
   kind="treadmill";dispatch=mods.Treadmill.RequestCashUpgrade
   confirm=function()return profile().TreadmillUpgradeLevel>before end
  end
  if not kind or not ctx.CanProgression()then return false end
  local lock={progression=kind};local request={kind=kind,confirm=confirm,Moving=true};progression.Pending=request
  A.Busy=true;A.ProgressBusy=true;shared.__SEAAdminRequestLock=lock
  progressionNotice("Approche du panneau : upgrade "..kind)
  task.spawn(function()
   local accepted,why
   local completed,err=pcall(function()
    if A.Destroyed or not ctx.CanProgression()then accepted=false;why="Priorite au vol ou AUTO arrete";return end
    local permitted=ctx.GetOptions()
    if kind=="plot"and not permitted.AutoPlotUpgrade or kind=="treadmill"and not permitted.AutoTreadmillUpgrade  then accepted=false;return end
    if not ctx.MoveForUpgrade then accepted=false;why="Deplacement upgrade indisponible";return end
    local reached,reason=ctx.MoveForUpgrade(kind,function()
     local latest=ctx.GetOptions()
     return not A.Destroyed and ctx.CanProgression()and(kind=="plot"and latest.AutoPlotUpgrade or kind=="treadmill"and latest.AutoTreadmillUpgrade)
    end)
    request.Moving=false
    if not reached or not ctx.CanProgression()then accepted=false;why=reason or"Priorite au vol";return end
    accepted,why=dispatch()
    if accepted==true then
     if waitUntil(confirm,10)then progressionNotice("Upgrade "..kind.." confirme")
     else progression.Unknown=request;progressionNotice("Upgrade accepte, confirmation en attente : aucun renvoi")end
    else progressionNotice("Upgrade "..kind.." refuse : "..tostring(why or accepted))end
   end)
   if not completed then
    if not safe(confirm)then progression.Unknown=request end
    progressionNotice("Upgrade incertain : "..tostring(err))
   end
   progression.RetryAt[kind]=os.clock()+(accepted==true and not progression.Unknown and 2 or 30)
   request.Moving=false
   if progression.Pending==request then progression.Pending=nil end
   A.Busy=false;A.ProgressBusy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
   pcall(A.Publish,true)
  end)
  return true
 end
 function A.ProgressNext()
  if os.clock()<(A.ProgressErrorRetryAt or 0)then return false end
  local ok,result=pcall(progressNextImpl)
  if not ok then A.ProgressErrorRetryAt=os.clock()+30;progressionNotice("Progression indisponible : "..tostring(result));return false end
  return result
 end
 function A.SellAnimals()
  if A.Destroyed or not A.Initialized or A.Busy or shared.__SEAAdminRequestLock or not ctx.CanMutate()then return 0 end
  local options=ctx.GetOptions();if not options.AutoSellAnimals then return 0 end
  local pending=shared.__SEAAnimalSalesPending or{};shared.__SEAAnimalSalesPending=pending
  local p=profile();for uid in pairs(pending)do if not(p.Inventory or{})[uid]then pending[uid]=nil end end
  local worn=equipped();local ids,names={},{}
  for uid,saved in pairs(p.Inventory or{})do
   if #ids>=64 then break end
   if not pending[uid]and not worn[uid]and not saved.Locked and not saved.IsFavorite and not table.find(p.FusionSlots or{},uid)then
    local item=safe(A.Items.Decode,saved);local rate=item and metric(safe(A.Earnings.RatePerSecond,item))
    if rate and rate>=options.AutoSellAnimalsMin and rate<=options.AutoSellAnimalsMax
     and (not options.AutoIndex or (type(p.Index)=="table"and p.Index[item.Category]==true))then
     table.insert(ids,uid);table.insert(names,tostring(item.Category).." ("..uid..", "..tostring(rate).."/s)")
    end
   end
  end
  if #ids==0 or not ctx.CanMutate()then return 0 end
  local lock={animalSale=true};A.Busy=true;shared.__SEAAdminRequestLock=lock;ctx.MutationLock(true)
  local ok,why=pcall(function()
   for _,uid in ipairs(ids)do pending[uid]=true end
   A.Remotes.PetSatchel.SellSelection:FireServer({Assets=ids,Eggs={}})
   local confirmed=waitUntil(function()local latest=profile().Inventory or{};for _,uid in ipairs(ids)do if latest[uid]then return false end end;return true end,3)
   if ctx.InventoryNotice then ctx.InventoryNotice((confirmed and"Animaux vendus (inventaire confirme) : "or"Vente animaux en attente, aucun renvoi : ")..table.concat(names," | "))end
  end)
  ctx.MutationLock(false);A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
  if not ok then if ctx.InventoryNotice then ctx.InventoryNotice("Vente animaux incertaine, aucun renvoi : "..tostring(why))end;warn("[SEA Admin] Vente animaux : "..tostring(why))end
  pcall(A.Publish,true);return #ids
 end
 local function stopFishing()
  A.Fishing=false;A.FishingRun=nil
  if A.ReleaseFishing then pcall(A.ReleaseFishing);A.ReleaseFishing=nil end
  if A.FishingPoseConnection then A.FishingPoseConnection:Disconnect();A.FishingPoseConnection=nil end
  if ctx.FishingLock then ctx.FishingLock(false)end
 end
 local function fishingLog(message)
  print("[SEA AutoFishing] "..message)
 end
 function A.SetFishing(enabled)
  assert(not ctx.LocalOnly and ctx.FishingLock and type(enabled)=="boolean","Mode pêche indisponible")
  if not enabled then stopFishing();ctx.SetEnabled(false);fishingLog("Arrêt demandé");return true end
  if A.Fishing then return true end
  fishingLog("Démarrage demandé")
  local env=type(getgenv)=="function"and getgenv()or getfenv()
  local move,press,release,click=env.mousemoveabs,env.mouse1press,env.mouse1release,env.mouse1click
  assert(type(move)=="function"and type(press)=="function"and type(release)=="function"and type(click)=="function","Entrées souris indisponibles")
  local function visible(name)
   local gui=player:FindFirstChild("PlayerGui")
   local ui=gui and gui:FindFirstChild("FishingUI")
   local node=ui and ui:FindFirstChild(name,true)
   if not node or not node:IsA("GuiObject")then return false end
   while node do
    if node:IsA("GuiObject")and not node.Visible or node:IsA("ScreenGui")and not node.Enabled then return false end
    if node==gui then return true end
    node=node.Parent
   end
   return false
  end
  ctx.SetEnabled(false)
  if not waitUntil(function()return not ctx.Busy()and ctx.CanStartFishing()end,35)then ctx.SetEnabled(false);error("AUTO n’a pas terminé son action")end
  local character=assert(player.Character,"Personnage indisponible")
  local root=assert(character:FindFirstChild("HumanoidRootPart"),"Personnage indisponible")
  local camera=assert(workspace.CurrentCamera,"Caméra indisponible")
  local savedPosition=root.CFrame
  local savedCamera,savedFocus=camera.CFrame,camera.Focus
  local run={};ctx.FishingLock(true);A.Fishing=true;A.FishingRun=run
  A.FishingPoseConnection=game:GetService("RunService").RenderStepped:Connect(function()
   if A.FishingRun~=run or A.Destroyed then return end
   local currentRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if currentRoot and currentRoot.CFrame~=savedPosition then
    currentRoot.CFrame=savedPosition
    currentRoot.AssemblyLinearVelocity=Vector3.zero
    currentRoot.AssemblyAngularVelocity=Vector3.zero
   end
   local currentCamera=workspace.CurrentCamera
   if currentCamera then
    currentCamera.CFrame=savedCamera
    currentCamera.Focus=savedFocus
   end
  end)
  local function untilVisible(test,seconds)
   local deadline=os.clock()+seconds
   repeat if A.FishingRun~=run or A.Destroyed then return false end;if test()then return true end;task.wait(.05)until os.clock()>=deadline
   return false
  end
  task.defer(function()
   local ok,why=pcall(function()
    local attempt=0
    while A.FishingRun==run and not A.Destroyed do
     attempt+=1
     local prefix="Essai "..attempt.." — "
     ctx.InventoryNotice("AutoFishing : essai "..attempt.." — attente du lancer")
     fishingLog(prefix.."Attente de l’indication de lancer")
     if not untilVisible(function()return visible("Tooltip")and not visible("Reveal")end,15)then error("Lancer indisponible. Équipe une canne et place-toi au bord de l’eau.")end
     local cam=assert(workspace.CurrentCamera,"Caméra indisponible")
     local center=cam.ViewportSize/2
     move(math.floor(center.X),math.floor(center.Y))
     A.ReleaseFishing=release;press();task.wait(1.05)
     if A.FishingRun~=run or A.Destroyed then return end
     release();A.ReleaseFishing=nil
     fishingLog(prefix.."Lancer relâché après 1,05 s, attente d’une prise")
     assert(untilVisible(function()return visible("Reel")or visible("Reveal")end,30),"Aucune prise détectée")
     ctx.InventoryNotice("AutoFishing : essai "..attempt.." — prise détectée")
     fishingLog(prefix.."Prise détectée, attente du résultat")
     local clicks=0
     local completed=untilVisible(function()
      if visible("Reveal")then return true end
      if visible("Reel")then
       local camera=assert(workspace.CurrentCamera,"Caméra indisponible")
       local point=camera.ViewportSize/2
       move(math.floor(point.X),math.floor(point.Y))
       A.ReleaseFishing=release
       press()
       task.wait(.03)
       release()
       A.ReleaseFishing=nil
       clicks+=1
       if clicks==1 or clicks%25==0 then
        fishingLog(prefix..clicks.." clics envoyés")
       end
      end
      return false
     end,15)
     assert(completed,"Résultat non affiché après "..clicks.." clics envoyés")
     fishingLog(prefix.."Résultat affiché")
     task.wait(1)
    end
   end)
   if A.FishingRun==run and not A.Destroyed then
    stopFishing();ctx.SetEnabled(was)
    if not ok then
     warn("[SEA AutoFishing] "..tostring(why))
     ctx.InventoryNotice("AutoFishing : "..tostring(why))
    end
    pcall(A.Publish,true)
   end
  end)
  return true
 end
 function A.Execute(m)
  if m.action=="images.collect"then
   local images={};for category,config in pairs(A.Assets.Directory)do
    if type(category)=="string"and type(config)=="table"then local entry=catalogImage(category,config);if entry.eggImageAssetId or entry.animalImageAssetId then table.insert(images,entry)end end
   end
   assert(#images<=5000,"Catalogue trop volumineux");table.sort(images,function(a,b)return a.category<b.category end);A.ImageCatalog=images;A.Signature=nil;return true
  elseif m.action=="settings.update"then
   assert(ctx.Report.SettingsRevision==m.settingsRevision,"Parametres modifies dans le jeu")
   assert(ctx.SetOptions(m.options),"Parametres invalides");return true
  elseif m.action=="fishing.set"then return A.SetFishing(m.enabled)
  elseif m.action=="automation.set"then assert(not A.Fishing,"Arrête AutoFishing avant de modifier AUTO");ctx.SetEnabled(m.enabled);return true end
  assert(not A.Fishing,"Arrête AutoFishing avant cette action")
  if ctx.BeginManual then assert(ctx.ManualCanContinue(),"Action manuelle interrompue : priorite au vol")
  else assert(not ctx.Busy(),"Action en cours")end
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
  if A.Busy or shared.__SEAAdminRequestLock or not A.Initialized or(not ctx.LocalOnly and not ctx.Report.SettingsAllowed)then
   send({version=1,type="admin.command.result",requestId=m.requestId,status="rejected",message="Admin indisponible ou action en cours"});return
  end
  A.Busy=true
  local lock={requestId=m.requestId};shared.__SEAAdminRequestLock=lock
  task.spawn(function()
   A.Dispatched=false
   local inventoryAction=not A.Fishing and m.action~="settings.update"and m.action~="automation.set"and m.action~="fishing.set"and m.action~="images.collect"
   local ok,confirmed=pcall(function()
    if inventoryAction and ctx.BeginManual then
     A.ManualPending=true
     assert(waitUntil(function()return ctx.BeginManual()end,30),"Action differee : un vol ou un oeuf eligible reste prioritaire")
     A.ManualPending=false
    end
    return A.Execute(m)
   end)
   A.ManualPending=false
   releaseMutationTool()
   ctx.MutationLock(false)
   if inventoryAction and ctx.EndManual then ctx.EndManual()end
   local result={version=1,type="admin.command.result",requestId=m.requestId,
    status=ok and confirmed and"confirmed"or(A.Dispatched and"unknown"or"rejected"),
    message=ok and confirmed and(m.action=="egg.mutate"and A.MutationStatus or"Action confirmee par le jeu")or tostring(ok and"Confirmation en attente : aucune relance automatique"or confirmed):sub(1,500)}
   A.Seen[m.requestId]=result;A.SeenOrder=A.SeenOrder or{};table.insert(A.SeenOrder,m.requestId)
   if #A.SeenOrder>100 then A.Seen[table.remove(A.SeenOrder,1)]=nil end
   A.Busy=false;if shared.__SEAAdminRequestLock==lock then shared.__SEAAdminRequestLock=nil end
   send(result);pcall(A.Publish,true)
  end)
 end
 function A.Destroy()A.Destroyed=true;if A.Fishing then stopFishing()end;if A.IndexRewards then A.IndexRewards.Destroy()end;releaseMutationTool();for _,c in ipairs(A.Connections or{})do c:Disconnect()end;if not ctx.LocalOnly then ctx.Report.AdminReceive=nil end end
 if not ctx.LocalOnly then ctx.Report.AdminReceive=A.Receive end
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
   for id,spec in pairs({Boss={"Shared.Flags.BossMasteryFlags","MutationConsumableSuccessPercent"},Scrambled={"Shared.Flags.ScrambleMutationFlags","SuccessPercent"},Nitro={"Shared.Flags.RaceRallyFlags","NitroSuccessPercent"},Spectral={"Shared.Flags.TrainEventFlags","SpectralSuccessPercent"},Musical={"Shared.Flags.BossMasteryFlags","MusicalMutationSuccessPercent"},Alien={"Shared.Flags.UFOSightingsFlags","AlienMutationSuccessPercent"},DarkMatter={"Shared.Flags.AlienLagoonFlags","DarkMatterMutationSuccessPercent"}})do
    local flags=safe(module,spec[1]);A.MutationFlags[id]=flags and flags[spec[2]]
   end
   A.Initialized=true
   A.Connections={}
   local function dirty()
    if A.Destroyed or A.PublishQueued then return end;A.PublishQueued=true
    task.delay(.5,function()A.PublishQueued=false;if not A.Destroyed then pcall(A.Publish,true)end end)
   end
   for _,signal in ipairs({A.EggState.OwnerRefreshed,A.EggState.SnapshotRefreshed})do
    if signal then table.insert(A.Connections,signal:Connect(dirty))end
   end
   if type(A.Save.Watch)=="function"then for _,key in ipairs({"EggInventory","Inventory","EquippedAssets","BaseUpgradeLevel","TreadmillUpgradeLevel"})do local signal=A.Save.Watch(key);if signal then table.insert(A.Connections,signal:Connect(dirty))end end end
  end)
  if not ok then warn("[SEA Admin] "..tostring(why));return end
  task.spawn(function()
   local loaded,problem=pcall(function()
    local function optional(path)return safe(module,path)end
    local limited=optional("Data.LimitedEgg")or{}
    local luminous=optional("Data.LuminousEgg")or{}
    local monster=optional("Data.MonsterEgg")or{}
    local brainrot=optional("Data.BrainrotEgg")or{}
    local scramble=optional("Data.ScrambleTradeIn")or{}
    local schedule=optional("Shared.Util.RiftMachineSchedule")
    local function entries(...)
     local all={};for _,rows in ipairs({...})do for _,row in ipairs(rows or{})do table.insert(all,row)end end;return all
    end
    local function collections()
     local extinction=limited.Extinction or{}
     local all={{id="LimitedEgg",gear="GravityDisruptor",entries=entries(extinction.Entries or{},extinction.MechaReroll and extinction.MechaReroll.Entries or{})},
      {id="BrainrotEgg",gear="BeeLauncher",entries=brainrot.Entries or{}},
      {id="MonsterEgg",gear="BeeLauncher",entries=entries(monster.Entries or{},monster.MechaEntries or{})}}
     if workspace:GetServerTimeNow()>=(A.Constants.UPDATE_LIVE_AT or math.huge)then table.insert(all,{id="LuminousEgg",gear="GravityDisruptor",entries=entries(luminous.Entries or{},luminous.MechaEntries or{})})end
     if schedule and safe(schedule.IsLaboratoryTime)then
      local rows={};for _,banner in ipairs(scramble.Banners or{})do for _,entry in ipairs(banner.Pets or{})do table.insert(rows,entry)end end
      table.insert(all,{id="DrScramble",gear="Scramble Sword",entries=rows})
     end
     return all
    end
    local run,why=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/IndexRewards.lua"),"SEA_V2/IndexRewards")
    assert(run,why)
    if not A.Destroyed then A.IndexRewards=run()({Save=A.Save,Assets=A.Assets,Remotes=A.Remotes,Collections=collections})end
   end)
   if not loaded and not A.Destroyed then warn("[SEA Index] "..tostring(problem))end
  end)
  while not A.Destroyed and ctx.Ready()do
   local sent,reason=pcall(A.Publish,false);if not sent then warn("[SEA Admin] Snapshot : "..tostring(reason))end
   task.wait(5)
  end
 end)
 return A
end
