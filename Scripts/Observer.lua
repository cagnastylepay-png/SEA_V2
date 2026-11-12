-- Ovora Observer: reports, minute clicks, and server spreading for standalone clients.
if shared.__SEAObserverController and not shared.__SEAObserverController.Destroyed then return shared.__SEAObserverController end
local O={Listeners={},SocketConnections={},ClientKind="observer",Serial=0,Connections={},Destroyed=false,Ready=false,IdentityReady=false,EggDirty=true,PlayerDirty=true,
 EggRevision=0,PlayerRevision=0,NextConnect=0,Backoff=2}
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if not player then return end
-- Minute clicks belong only to standalone Observers; Hub/Admin own their inputs.
O.NextClickAt=os.clock()+60
function O.TickClicks(now)
 if O.Destroyed or O.ClientKind~="observer"then O.NextClickAt=now+60;return end
 if O.ClickBusy or now<O.NextClickAt then return end
 O.NextClickAt=now+60
 local env=type(getgenv)=="function"and getgenv()or getfenv()
 local press,release,click=env.mouse1press,env.mouse1release,env.mouse1click
 local paired=type(press)=="function"and type(release)=="function"
 if not paired and type(click)~="function"then return end
 O.ClickBusy=true
 task.spawn(function()
  local held=false
  local ok,why=pcall(function()
   if O.Destroyed or O.ClientKind~="observer"then return end
   local camera=workspace.CurrentCamera
   if camera and type(env.mousemoveabs)=="function"then
    local center=camera.ViewportSize/2
    env.mousemoveabs(math.floor(center.X),math.floor(center.Y))
   end
   for _=1,math.random(3,4)do
    if O.Destroyed or O.ClientKind~="observer"then break end
    if paired then
     held=true;press();task.wait(.03);release();held=false
    else click()end
    task.wait(.15)
   end
  end)
  if held then pcall(release)end
  O.ClickBusy=false
  if not ok and not O.Destroyed then warn("[Observer] Clics périodiques : "..tostring(why))end
 end)
end

-- Render coordinates standalone Observers sharing a server.
O.SpreadRetryAt=0
function O.ReceiveSpread(target)
 if O.Destroyed or O.ClientKind~="observer"then return end
 if target==nil then O.SpreadTarget=nil;return end
 if type(target)~="table"or target.placeId~=tostring(game.PlaceId)or target.jobId~=game.JobId
  or type(target.keeperUserId)~="string"or not target.keeperUserId:match("^%d+$")
  or target.keeperUserId==tostring(player.UserId)
  or type(target.destinationJobId)~="string"or target.destinationJobId==""or #target.destinationJobId>128
  or target.destinationJobId==game.JobId then return end
 local delay=tonumber(target.delaySeconds)
 if not delay or delay~=delay or delay<0 or delay>900 then return end
 O.SpreadTarget={keeperUserId=target.keeperUserId,jobId=target.jobId,destinationJobId=target.destinationJobId}
 O.SpreadAt=os.clock()+delay+math.random(0,8)
end
function O.TickSpread(now)
 if O.Destroyed or O.ClientKind~="observer"then O.SpreadTarget=nil;return end
 if O.SpreadTeleportAt then
  if now-O.SpreadTeleportAt<90 then return end
  O.SpreadTeleportAt=nil;O.SpreadRetryAt=now+60
 end
 local target=O.SpreadTarget
 if not target or not O.Ready or O.ClickBusy or now<(O.SpreadAt or 0)or now<O.SpreadRetryAt then return end
 if target.jobId~=game.JobId then O.SpreadTarget=nil;return end
 local keeper=Players:GetPlayerByUserId(tonumber(target.keeperUserId))
 if not keeper then O.SpreadTarget=nil;return end
 O.SpreadTeleportAt=now;O.SpreadRetryAt=now+60
 task.spawn(function()
  local env=type(getgenv)=="function"and getgenv()or getfenv()
  local queue=env.queue_on_teleport or env.queueonteleport or(env.syn and env.syn.queue_on_teleport)
  if not O.SpreadQueued and type(queue)=="function"then
   local queued=pcall(queue,[[if not shared.__SEAObserverController or shared.__SEAObserverController.Destroyed then
    local run,why=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Loaders/Observer.lua"),"SEA_V2/Observer")
    assert(run,why);run()
   end]])
   O.SpreadQueued=queued
  end
  -- Same native flush as AntiAFKController; a stalled flush must not hold the hop.
  local flushed=false
  task.spawn(function()
   pcall(function()require(RS.Shared.Remotes).Telemetry.AskIdleHopFlush:InvokeServer()end)
   flushed=true
  end)
  local deadline=os.clock()+3
  while not flushed and os.clock()<deadline do
   if O.Destroyed or O.ClientKind~="observer"then O.SpreadTeleportAt=nil;return end
   task.wait(.1)
  end
  if O.Destroyed or O.ClientKind~="observer"or O.SpreadTarget~=target or not O.Ready
   or not Players:GetPlayerByUserId(tonumber(target.keeperUserId))then O.SpreadTeleportAt=nil;return end
  local ok,why=pcall(function()game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,target.destinationJobId,player)end)
  if not ok then O.SpreadTeleportAt=nil;warn("[Observer] Changement de serveur : "..tostring(why))end
 end)
end

function O.Status(status,good)
 O.LastStatus=status;O.Connected=good==true
end
function O.Connect(signal,callback)
 if not signal then return end
 local ok,connection=pcall(function()return signal:Connect(callback)end)
 if ok then table.insert(O.Connections,connection)end
end
function O.Disconnect()
 O.Serial+=1;O.LastPolicy=nil;O.SpreadTarget=nil
 O.Ready=false;O.IdentityReady=false;O.Connecting=false;O.EggAckRevision=nil
 local socket=O.Socket;O.Socket=nil
 for _,connection in ipairs(O.SocketConnections)do pcall(function()connection:Disconnect()end)end
 table.clear(O.SocketConnections)
 if socket then pcall(function()socket:Close()end)end
 O.NextConnect=os.clock()+O.Backoff;O.Backoff=math.min(60,O.Backoff*2)
 O.Status("Reconnexion",false)
end
function O.Destroy()
 if O.Destroyed then return end
 O.Destroyed=true
 if shared.__SEAObserverController==O then shared.__SEAObserverController=nil end
 table.clear(O.Listeners)
 O.Disconnect()
 for _,connection in ipairs(O.Connections)do pcall(function()connection:Disconnect()end)end
 if O.Socket then pcall(function()O.Socket:Close()end)end
end
shared.__SEAObserverController=O
function O.Subscribe(callback)
 O.Listeners[callback]=true
 return function()O.Listeners[callback]=nil end
end
function O.Configure(kind,owner,url,token)
 assert(kind=="observer"or kind=="hub"or kind=="admin","Role invalide")
 local changed=O.ClientKind~=kind or O.Url~=url or O.Token~=token
 O.Owner=owner;O.ClientKind=kind;O.Url=url;O.Token=token
 if changed then O.Disconnect();O.NextConnect=0 end
end
function O.Release(owner)
 if O.Owner~=owner then return end
 O.Configure("observer",nil,O.Url,O.Token)
end
function O.MarkEggsDirty()O.EggDirty=true end
function O.SocketConnect(signal,callback)
 local connection=signal:Connect(callback);table.insert(O.SocketConnections,connection)
end
local function module(path)
 local node=RS
 for part in path:gmatch("[^.]+")do node=node:WaitForChild(part,30);if not node then error("Module absent: "..path)end end
 return require(node)
end
local ok,err=pcall(function()
 O.EggState=module("Client.EggState");O.Assets=module("Data.Assets")
 O.Records=module("Shared.Util.EggRecords");O.Earnings=module("Shared.Util.AssetEarnings")
 O.Cycle=module("Shared.Util.AreaEggCycle");O.Clock=module("Shared.Util.ServerClock")
 O.Items=module("Shared.Util.AssetItems");O.Balance=module("Shared.Flags.GameplayBalance")
end)
if not ok then O.Status("Initialisation impossible",false);return end
for key,path in pairs({Roster="Client.AssetRoster",Projection="Client.SpeedPowerProjection",Save="Shared.Save"})do
 local loaded,value=pcall(module,path);if loaded then O[key]=value end
end
local function metric(value)
 return type(value)=="number" and value==value and value>=0 and value<math.huge and value or nil
end
local function safe(fn,...)
 if type(fn)~="function"then return nil end
 local success,value=pcall(fn,...);return success and value or nil
end
function O.Encode(message,key,rows)
 local encoded={}
 for _,row in ipairs(rows)do table.insert(encoded,Http:JSONEncode(row))end
 return Http:JSONEncode(message):sub(1,-2)..',"'..key..'":['..table.concat(encoded,",")..']}'
end
function O.Send(message,key,rows)
 if not O.Socket then return false end
 local success=pcall(function()
  O.Socket:Send(key and O.Encode(message,key,rows)or Http:JSONEncode(message))
 end)
 if not success then O.Disconnect()end
 return success
end
O.Session=Http:GenerateGUID(false)
function O.Header(kind,moduleId,revision)
 return {version=1,type=kind,moduleId=moduleId,sessionId=O.Session,revision=revision,
 placeId=tostring(game.PlaceId),jobId=game.JobId}
end
function O.Players()
 local rows,incomes={},{}
 local snapshot=O.Roster and safe(O.Roster.ReadSnapshot)
 for _,owner in ipairs(snapshot or {})do
  local total,known=0,false
  for _,record in pairs(owner.Records or {})do
   local rate=metric(record.MoneyPerSecond)
   if rate then total=total+rate;known=true end
  end
  if known then incomes[tostring(owner.OwnerUserId)]=total end
 end
 local profile=O.Save and safe(O.Save.Peek)
 for _,target in ipairs(Players:GetPlayers())do
  local row={userId=tostring(target.UserId),name=target.Name,displayName=target.DisplayName}
  if target==player then
   row.speedPower=metric(O.Projection and safe(O.Projection.ReadProjected))
    or metric(type(profile)=="table" and profile.SpeedPower)
  end
  row.speedPower=row.speedPower or metric(target:GetAttribute("SpeedPower"))
  local stats=target:FindFirstChild("leaderstats")
  local value=stats and (stats:FindFirstChild("SpeedPower")or stats:FindFirstChild("Speed"))
  if not row.speedPower and value and value:IsA("ValueBase")then row.speedPower=metric(value.Value)end
  row.incomePerSecond=incomes[row.userId]
  table.insert(rows,row)
 end
 table.sort(rows,function(a,b)return a.userId<b.userId end)
 return rows
end
function O.Eggs()
 local snapshot=O.EggState.ReadFieldEggs()
 if not snapshot or type(snapshot.Records)~="table"then return nil end
 local eggs={}
 for key,record in pairs(snapshot.Records)do
  if type(record)=="table"and record.AssetCategory then
   local config=O.Assets.Directory[record.AssetCategory]or {}
   local rarity=config.Rarity
   if type(rarity)=="table"then rarity=rarity._id or rarity.Id or rarity.Name end
   local item=safe(O.Records.ToAssetItemData,record)
   local egg={uid=tostring(record.Uid or key),category=record.AssetCategory,
    name=config.DisplayName or record.AssetCategory,rarity=tostring(rarity or "Unknown"),
    state=record.State,carrierUserId=metric(record.CarrierUserId),
    observationOnly=record.ObservationOnly==true,
    weightKg=metric(safe(O.Records.WeightKgForScale,record.AssetCategory,record.AssetScale)),
    incomePerSecond=metric(item and safe(O.Earnings.RatePerSecond,item))}
   for _,key in ipairs({"AreaId","Zone","AssetScale","NestId","NestScale","AssetEyeColor","AssetColorSeed","AssetColorIndex","Version","DroppedAt","HasParasite","BaseMutation","AssetGender","AssetPersonality","EggSkin","OwnerUserId"})do
    local map={AreaId="areaId",Zone="zone",AssetScale="assetScale",NestId="nestId",NestScale="nestScale",AssetEyeColor="eyeColor",AssetColorSeed="colorSeed",AssetColorIndex="colorIndex",Version="version",DroppedAt="droppedAt",HasParasite="hasParasite",BaseMutation="baseMutation",AssetGender="gender",AssetPersonality="personality",EggSkin="skin",OwnerUserId="ownerUserId"}
    local value=record[key];if value~=nil then egg[map[key]]=(key=="AreaId"or key=="Zone")and tostring(value)or value end
   end
   if type(record.Mutations)=="table"and#record.Mutations>0 then egg.mutations=table.clone(record.Mutations)end
   if typeof(record.BottomCFrame)=="CFrame"then local p=record.BottomCFrame.Position;egg.position={x=p.X,y=p.Y,z=p.Z};egg.cframe={record.BottomCFrame:GetComponents()}end
   if config.Egg then egg.icon=config.Egg.Icon end
   egg.sellValue=metric(safe(O.Records.SellPrice,record))
   if not egg.sellValue and item then
    item=table.clone(item);item.Mutations={};item.BaseMutation=nil
    egg.sellValue=metric(safe(function()return O.Items.SalePrice(item)*O.Balance.Eggs.SELL_PRICE_SHARE end))
   end
   table.insert(eggs,egg)
  end
 end
 table.sort(eggs,function(a,b)return a.uid<b.uid end)
 return eggs
end
function O.Refresh()
 if O.Syncing then return end
 local cycle=tostring(O.Cycle.ActivePeriodIndexAt(O.Clock.Now()))
 O.Syncing=true
 task.spawn(function()
  local success=pcall(O.EggState.SyncFieldEggs)
  O.Syncing=false;O.EggDirty=true;O.ForceEggs=true
  if success then O.SnapshotCycle=cycle else O.NextSync=os.clock()+10 end
 end)
end
local function markPlayers()O.PlayerDirty=true end
local function markEggs()O.EggDirty=true end
function O.TrackPlayer(target)
 O.Connect(target.AttributeChanged,markPlayers)
 O.Connect(target:GetPropertyChangedSignal("DisplayName"),markPlayers)
 local function trackStats(stats)
  if stats.Name~="leaderstats"then return end
  local function trackValue(value)
   if value:IsA("ValueBase")then O.Connect(value.Changed,markPlayers)end
   markPlayers()
  end
  for _,value in ipairs(stats:GetChildren())do trackValue(value)end
  O.Connect(stats.ChildAdded,trackValue);O.Connect(stats.ChildRemoved,markPlayers)
 end
 for _,child in ipairs(target:GetChildren())do trackStats(child)end
 O.Connect(target.ChildAdded,trackStats)
 markPlayers()
end
for _,target in ipairs(Players:GetPlayers())do O.TrackPlayer(target)end
O.Connect(Players.PlayerAdded,O.TrackPlayer);O.Connect(Players.PlayerRemoving,markPlayers)
if O.Roster then O.Connect(O.Roster.SnapshotRefreshed,markPlayers)end
if O.Projection then O.Connect(O.Projection.Changed,markPlayers)end
if O.Save and type(O.Save.Watch)=="function"then
 local signal=safe(O.Save.Watch,"SpeedPower");O.Connect(signal,markPlayers)
end
for _,name in ipairs({"FieldRefreshed","FieldShifted","FieldGone","RarityRevealed"})do O.Connect(O.EggState[name],markEggs)end
function O.OpenSocket()
 if O.Connecting or O.Destroyed then return end
 O.Connecting=true;O.LastAck=os.clock()
 local serial=O.Serial
 task.spawn(function()
  local success=pcall(function()
   local env=type(getgenv)=="function"and getgenv()or getfenv()
   local api=env.WebSocket or env.websocket or (env.syn and env.syn.websocket)
   local connector=api and (api.connect or api.Connect)
   if type(connector)~="function"then error("WebSocket indisponible")end
   local socket=connector(O.Url or"wss://m4gix-ws.onrender.com/sae/ws")
   if O.Destroyed or O.Serial~=serial then socket:Close();return end
   O.Socket=socket
   O.SocketConnect(socket.OnClose,function()if O.Socket==socket then O.Disconnect()end end)
   O.SocketConnect(socket.OnMessage,function(raw)
    if O.Destroyed or O.Socket~=socket then return end
    local decoded,message=pcall(Http.JSONDecode,Http,raw)
    if not decoded or type(message)~="table"or message.version~=1 then return end
    if message.type=="hello.ack"then
     O.Ready=true;O.Connecting=false;O.Backoff=2;O.LastAck=os.clock()
     O.PlayerDirty=true;O.EggDirty=true;O.ForcePlayers=true;O.ForceEggs=true
    elseif message.type=="players.ack"then O.IdentityReady=true;O.LastAck=os.clock();O.PendingAt=nil
    elseif message.type=="eggs.ack"then
     O.LastAck=os.clock();O.PendingAt=nil
     if message.accepted==true and message.sessionId==O.Session and message.revision==O.EggRevision then
      O.EggAckRevision=message.revision;O.Status("Observation transmise",true)
     end
    elseif message.type=="observer.spread"then O.ReceiveSpread(message.target)
    elseif message.type=="reporting.policy"then O.LastPolicy=message
    end
    for callback in pairs(O.Listeners)do local handled,why=pcall(callback,message);if not handled then warn("[Observer] Client callback : "..tostring(why))end end
   end)
   O.Send({version=1,type="hello",role="reporter",reporterUserId=tostring(player.UserId),observerOnly=O.ClientKind=="observer",clientKind=O.ClientKind,token=O.Token})
  end)
  if not success and O.Serial==serial then O.Disconnect()end
 end)
end
O.Connect(game:GetService("TeleportService").TeleportInitFailed,function(target)
 if target==player and O.SpreadTeleportAt then O.SpreadTeleportAt=nil;O.SpreadRetryAt=os.clock()+60 end
end)
O.Refresh()
task.spawn(function()
 while not O.Destroyed do
  local now=os.clock()
  O.TickSpread(now)
  if not O.SpreadTeleportAt then O.TickClicks(now)end
  local cycle=tostring(O.Cycle.ActivePeriodIndexAt(O.Clock.Now()))
  if cycle~=O.CurrentCycle then O.CurrentCycle=cycle;O.Refresh()end
  if not O.Syncing and O.SnapshotCycle~=cycle and now>=(O.NextSync or 0)then O.Refresh()end
  if not O.Socket and not O.Connecting and now>=O.NextConnect then O.OpenSocket()end
  if O.Connecting and now-O.LastAck>20 then O.Disconnect()end
  if O.PendingAt and now-O.PendingAt>25 then O.PendingAt=nil;O.Disconnect()end
  if O.Ready and game.JobId~=""then
   if O.PlayerDirty and now-(O.LastPlayers or 0)>=1 then
    local rows=O.Players();local fingerprint=Http:JSONEncode(rows)
    if O.ForcePlayers or fingerprint~=O.PlayerFingerprint then
     O.PlayerRevision=O.PlayerRevision+1
     local message=O.Header("players.snapshot","PlayerReporter",O.PlayerRevision)
     message.reporterUserId=tostring(player.UserId)
     if O.Send(message,"players",rows)then O.PlayerFingerprint=fingerprint;O.ForcePlayers=false;O.PendingAt=O.PendingAt or now end
    end
    O.PlayerDirty=false;O.LastPlayers=now
   end
   if O.IdentityReady and O.SnapshotCycle==cycle and not O.Syncing and O.EggDirty and now-(O.LastEggs or 0)>=1 then
    local rows=O.Eggs()
    if rows then
     local fingerprint=cycle..Http:JSONEncode(rows)
     if O.ForceEggs or fingerprint~=O.EggFingerprint then
      O.EggRevision=O.EggRevision+1
      local message=O.Header("eggs.snapshot","EggReporter",O.EggRevision)
      message.cycleId=cycle;message.observedAt=os.date("!%Y-%m-%dT%H:%M:%SZ")
      message.cycleEndsAt=O.Cycle.NextNightTime(O.Clock.Now())
      if O.Send(message,"eggs",rows)then
       O.EggFingerprint=fingerprint;O.ForceEggs=false;O.PendingAt=O.PendingAt or now
      end
     end
     O.EggDirty=false;O.LastEggs=now
    end
   end
  end
  task.wait(0.5)
 end
end)
return O

