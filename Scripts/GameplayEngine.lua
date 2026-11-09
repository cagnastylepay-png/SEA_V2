-- Preserve Admin when an executor also auto-loads Hub after a teleport.
do
 local options=shared.__AutoSAEReportingOptions
 if not(type(options)=="table"and options.ClientKind=="admin")then
  if shared.__SEAAdminBoot or(shared.__SEA_V2Admin and not shared.__SEA_V2Admin.Destroyed)then return shared.__AutoSAEController end
  local ok,arrival=pcall(function()return game:GetService("TeleportService"):GetTeleportSetting("OvoraRemoteArrival")end)
  if ok and type(arrival)=="table"and arrival.clientKind=="admin"and arrival.jobId==game.JobId
   and arrival.reporterUserId==tostring(game:GetService("Players").LocalPlayer.UserId)
   and type(arrival.expiresAt)=="number"and arrival.expiresAt>=os.time()then
   local run,why=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Loaders/Admin.lua"),"SEA_V2/Admin")
   assert(run,why);return run()
  end
 end
end
print("[Auto_SAE] Build reporting-v4-all-eggs")
-- Auto_SAE v2.8. SellPrompt selection UI. Verified client contracts; no character/anticheat replacement.
-- The live game must provide ReplicatedStorage.Client/Data/Shared.
-- Refresh outbound MoveTo before its native timeout; verify distance before carry.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
assert(player, "Auto_SAE doit etre execute sur le client")

local CONFIG = {
	Debug = true,
	ProgressInterval = 0.5,
	MoveRefresh = 0.1,
	ApproachRefresh = 4,
	ApproachDistance = 8,
	PreciseArrivalRadius = 3,
	ScanInterval = 0.25,
	ReturnDistance = 3,
	RequestTimeout = 10,
	MaxCarryAttempts = 5,
	CarryRetryDelay = 0.15,
	EnableArrivalBrake = true,
	ArrivalBrakeDuration = 0.03,
	ObserveRigSync = true,
	MotionPauseTimeout = 12,
	RigSettleTime = 0.15,
	ClaimTimeout = 12,
	NoMovementTimeout = 10,
	FailedTargetCooldown = 10,
	RecoveryStateTimeout = 30,
	RecoveryRetryDelay = 0.5,
	ArrivalTargetTimeout = 20,
}
local MINIMUM_BILLIONS, MAXIMUM_BILLIONS, DEFAULT_BILLIONS = 0, 1e24, 2
local SLOT_STATE = "Slot"
local CARRY_LOST = "CARRY_LOST"
local EggState, Assets, EggRecords, AssetEarnings, SlotIdentity, GuardGeometry, Save
local ready, destroyed, autoEnabled = false, false, false
local generation = 0
local minimumRatePerSecond = DEFAULT_BILLIONS * 1e9
local records, loggedVersions, cooldowns = {}, {}, {}
local trackedEggs = {}
local lifetimeConnections = {}
local currentCycle, safeHome
local inFlightRequest = shared.__AutoSAERemoteLock
local statusLabel, toggleButton, minimumInput
local sequence = 0
local renderControls
local refreshEggInterface
local selectedEggs = {}
local automaticMode = true
local autoIncludeMissingIndex = true
local openBelowRate = 20e9
local searchingServer = false
local visitedServers = {}
local visitedCycleIndex
local continuationPrepared = false
local searchWaitForEgg = false
local AreaEggCycle, ServerClock
local serverSearchState = "OFF"
local serverHopPending = false
local serverSearchReadyAt = math.huge
local nextServerHopAt = 0
local requestRandomServerHop
local lastMaintenanceAt = -math.huge
local inventoryEggRecords
local inventoryPlacementBusy = false
local placementRequest
local FusionModules = {}
FusionModules.Helpers = {}
FusionModules.Options={AutoEggs=true,AutoEggsMin=2e9,AutoEggsMax=999e9,
 AutoTreadmill=true,AutoSell=true,AutoSellMin=0,AutoSellMax=2e9,
 AutoFuse=true,AutoFuseMin=0,AutoFuseMax=1e33,AutoOpen=true,AutoOpenMin=0,AutoOpenMax=20e9,AutoPlace=true,AutoPlaceMin=2e9,AutoPlaceMax=1e33,AutoPapillon=true,AutoEquipBest=true,AutoIndex=true,QueueNearest=false,TeleportInstantMin=50e9}

function FusionModules.Helpers.InIncomeRange(key,rate)
 return type(rate)=="number"and rate==rate and rate<math.huge
  and rate>=FusionModules.Options[key.."Min"]and rate<=FusionModules.Options[key.."Max"]
end

FusionModules.Options.AutoPlotUpgrade=false
FusionModules.Options.AutoTreadmillUpgrade=false
FusionModules.Options.AutoHelp=false
FusionModules.Options.AutoHelpMin=2e9
FusionModules.Options.HelpFavorites=""
function FusionModules.Helpers.ValidHelpFavorites(value)
 if type(value)~="string"or #value>1100 then return false end
 local count=0
 for name in value:gmatch("[^,%s;]+")do
  count+=1;if count>50 or #name<3 or #name>20 or name:find("[^%w_]")then return false end
 end
 return true
end
FusionModules.Options.AutoMutations=false
FusionModules.Options.AutoSellAnimals=false
FusionModules.Options.AutoSellAnimalsMin=0
FusionModules.Options.AutoSellAnimalsMax=2e9
for _,id in ipairs({"Boss","Scrambled","Enchanted","Nitro","Spectral","Musical","Alien","DarkMatter"})do
 FusionModules.Options["Mutation"..id.."Enabled"]=false
 FusionModules.Options["Mutation"..id.."Min"]=0
 FusionModules.Options["Mutation"..id.."Attempts"]=1
end

function FusionModules.Helpers.SetOption(key,value)
 local current=FusionModules.Options[key]
 if current==nil then return false,"Parametre inconnu"end
 if key=="HelpFavorites"then
  if not FusionModules.Helpers.ValidHelpFavorites(value)then return false,"Favoris invalides"end
 elseif type(current)=="boolean"then
  if type(value)~="boolean"then return false,"Interrupteur invalide"end
 else
  if type(value)~="number"or value~=value or value<0 or value>=math.huge then return false,"Revenu invalide"end
  local prefix=key:sub(1,-4)
  if key:match("Min$")and type(FusionModules.Options[prefix.."Max"])=="number"and value>FusionModules.Options[prefix.."Max"]then return false,"Minimum superieur au maximum"end
  if key:match("Max$")and type(FusionModules.Options[prefix.."Min"])=="number"and value<FusionModules.Options[prefix.."Min"]then return false,"Maximum inferieur au minimum"end
 end
 FusionModules.Options[key]=value
 minimumRatePerSecond=FusionModules.Options.AutoEggsMin
 autoIncludeMissingIndex=FusionModules.Options.AutoIndex
 automaticMode=true
 if FusionModules.OnOptionsChanged then FusionModules.OnOptionsChanged()end
 return true
end
function FusionModules.Helpers.RestoreOptions(saved)
 if type(saved)~="table"then return false end
 local candidate=table.clone(FusionModules.Options)
 for key,current in pairs(candidate)do
  local value=saved[key]
  if value~=nil then
   if type(value)~=type(current)then return false end
   if type(value)=="number"and(value~=value or value<0 or value>=math.huge)then return false end
   candidate[key]=value
  end
 end
 if candidate.AutoEggsMin>candidate.AutoEggsMax or candidate.AutoSellMin>candidate.AutoSellMax or candidate.AutoOpenMin>candidate.AutoOpenMax or candidate.AutoPlaceMin>candidate.AutoPlaceMax or candidate.AutoFuseMin>candidate.AutoFuseMax then return false end
 if candidate.AutoSellAnimalsMin>candidate.AutoSellAnimalsMax then return false end
 if not FusionModules.Helpers.ValidHelpFavorites(candidate.HelpFavorites)then return false end
 for _,id in ipairs({"Boss","Scrambled","Enchanted","Nitro","Spectral","Musical","Alien","DarkMatter"})do local n=candidate["Mutation"..id.."Attempts"];if n%1~=0 or n<1 or n>100 then return false end end
 FusionModules.Options=candidate
 minimumRatePerSecond=candidate.AutoEggsMin;autoIncludeMissingIndex=candidate.AutoIndex;automaticMode=true
 return true
end

FusionModules.Busy = false
FusionModules.Request = shared.__AutoSAEFusionRequest
function FusionModules.Pending()
	return FusionModules.ManualBusy or FusionModules.MutationBusy or FusionModules.Busy or (FusionModules.Request and not FusionModules.Request.done)or(FusionModules.Help and FusionModules.Help.DropRequest and not FusionModules.Help.DropRequest.done)
end
local EggSaleRemote
local GameplayBalance
local timingEnabled = false
local flightHistory = {}
local refreshFlightLog
local stopAfterFlight = false
local queuedEggs = {}
function FusionModules.Helpers.ShouldRun()
 for key,value in pairs(FusionModules.Options)do if key~="QueueNearest"and type(value)=="boolean"and value then return true end end
 return next(queuedEggs)~=nil
end
local removedFromAuto = {}
local queueDecisionLogs = {}
local lastQueueSummary
local queuePaused = false
local syncQueue, wakeQueue, refreshQueueInterface, startAutomation
local stopAutomation
local rigPause = {Character = nil, Until = 0, Reason = nil}
local syncPauseUntil, lastRelocateAt, lastPhysicalBrakeAt = 0, -math.huge, -math.huge
local movementRevision = 0
local movementResumePending = false
local PlotState, TreadmillRemotes, AssetRoster
local PlacedEggRenderer, EggGrowthPolicy
local hatchInProgress = false
local wallMaintenancePending = false
local HaulRemotes
-- Equip Best is keyed to the game's egg cycle, independent of inventory maintenance.
local activityRecheckPending = false
local refreshBestEggCard
local treadmillAssigned, treadmillPending = false, false
local autoActivity = "IDLE"


-- Optional executor APIs. Capture once; never replace Roblox services or remotes.
local debugLogLines = {}
local pendingLogLines = {}
local executorEnvironment = getfenv()
if type(getgenv) == "function" then
	local ok, environment = pcall(getgenv)
	if ok and type(environment) == "table" then executorEnvironment = environment end
end
local function executorFunction(name)
	local candidate = executorEnvironment[name]
	if type(candidate) ~= "function" then candidate = getfenv()[name] end
	return type(candidate) == "function" and candidate or nil
end
local executorTools = {}
local executorLogPath = type(shared.__AutoSAEReportingOptions)=="table" and shared.__AutoSAEReportingOptions.ClientKind=="admin" and "AutoSAE_debug.txt" or ("SEA_Hub_"..player.UserId.."_debug.txt")
function executorTools.Capabilities()
	local result = {}
	for _, name in ipairs({"fireproximityprompt", "writefile", "readfile", "openfile", "isfile", "appendfile"}) do
		result[name] = executorFunction(name) ~= nil
	end
	return result
end
local function callExecutor(name, ...)
	local fn = executorFunction(name)
	if not fn then return false, name .. " indisponible dans cet environnement" end
	return pcall(fn, ...)
end
function executorTools.SaveLog()
	if #pendingLogLines == 0 then return true, executorLogPath end
	local count = #pendingLogLines
	local payload = table.concat(pendingLogLines, "\n", 1, count) .. "\n"
	local ok, result = callExecutor("appendfile", executorLogPath, payload)
	if not ok then
		local readOK, previous = callExecutor("readfile", executorLogPath)
		if readOK and type(previous) == "string" then
			ok, result = callExecutor("writefile", executorLogPath, previous .. (previous:sub(-1) == "\n" and "" or "\n") .. payload)
		else
			local existsOK, exists = callExecutor("isfile", executorLogPath)
			if existsOK and exists == false then ok, result = callExecutor("writefile", executorLogPath, payload)
			else return false, "Impossible de lire le log existant : ecrasement refuse" end
		end
	end
	if ok then for _ = 1, count do table.remove(pendingLogLines, 1) end end
	return ok, ok and executorLogPath or tostring(result)
end

function executorTools.ReadLog()
	return callExecutor("readfile", executorLogPath)
end
function executorTools.OpenLog()
	return callExecutor("openfile", executorLogPath)
end
function executorTools.FirePrompt(prompt)
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") or not prompt:IsDescendantOf(Workspace) then
		return false, "ProximityPrompt de Workspace requis"
	end
	return callExecutor("fireproximityprompt", prompt)
end
shared.__AutoSAEExecutorTools = executorTools

executorTools.RemoteLogQueue={}
executorTools.RemoteLogSequence=0
local function log(stage, message, ...)
	local allowed = {ACTION=true, ERROR=true, FLIGHT_RESULT=true, REPORT=true, BUTTERFLY=true, SESSION=true, STOP=true, WALL_HATCH=true, WALL_EQUIP_BEST=true, FUSION=true, PLOT_PLACE=true, INVENTORY_SELL_REQUEST=true, EGG_TRACK=true, SYNC_DIAG=true, CARRY_DIAG=true, SERVER_CHANGE=true, GUARD_CONTROL=true}
	if not allowed[stage] then
		return
	end
	sequence += 1
	local ok, text = pcall(string.format, message, ...)
	if not ok then
		text = message .. " | format=" .. tostring(text)
	end
	local line = string.format("[Auto_SAE][%04d][%.3f][%s][%s] %s",
		sequence, os.clock(), stage, currentCycle and currentCycle.uid or "-", text)
 -- Render receives terminal flight results only; detailed diagnostics stay local.
 if stage=="FLIGHT_RESULT"
  and not (FusionModules.Reporting and FusionModules.Reporting.PolicyKnown and not FusionModules.Reporting.LogsAllowed)then
	executorTools.RemoteLogSequence+=1
 table.insert(executorTools.RemoteLogQueue,{sequence=executorTools.RemoteLogSequence,at=os.date("!%Y-%m-%dT%H:%M:%SZ"),text=line:sub(1,4000)})
 if #executorTools.RemoteLogQueue>2000 then table.remove(executorTools.RemoteLogQueue,1)end
 if FusionModules.Reporting and FusionModules.Reporting.ScheduleLogs then FusionModules.Reporting.ScheduleLogs()end

 end
	table.insert(debugLogLines, line)
	table.insert(pendingLogLines, line)
	if #debugLogLines > 1000 then table.remove(debugLogLines, 1) end
	print(line)
	local saved, failure = executorTools.SaveLog()
	if not saved and executorFunction("writefile") then warn("[Auto_SAE] Sauvegarde log : "..tostring(failure)) end
end

local function measureAction(_, action, ...)
	return action(...)
end

local settingsPath = type(shared.__AutoSAEReportingOptions)=="table" and shared.__AutoSAEReportingOptions.ClientKind=="admin" and "AutoSAE_settings.json" or ("SEA_Hub_"..player.UserId.."_settings.json")
local lastSettingsJSON, lastSavedLogSequence = nil, -1
function executorTools.SaveSettings()
	local json = HttpService:JSONEncode({
		Version = 1, Settings = FusionModules.Options, AutomaticMode = true,
		IncludeMissingIndex = autoIncludeMissingIndex,
		OpenBelowRate = openBelowRate,
		SearchActive = false,
		VisitedPlaceId = game.PlaceId, VisitedServers = visitedServers,
		VisitedCycleIndex = visitedCycleIndex,
		TimingEnabled = timingEnabled,
  HelpDelivered = shared.__SEAHelpDelivered,
		MinimumBillions = minimumRatePerSecond / 1e9,
	})
	if json == lastSettingsJSON then return true, settingsPath end
	local ok, result = callExecutor("writefile", settingsPath, json)
	if ok then
		lastSettingsJSON = json
		log("SETTINGS_SAVED", "Auto=%s Index=%s Minimum=%s B/s", tostring(automaticMode), tostring(autoIncludeMissingIndex), tostring(minimumRatePerSecond / 1e9))
	end
	return ok, ok and settingsPath or tostring(result)
end
local function loadSettings()
	local ok, content = callExecutor("readfile", settingsPath)
	if not ok then log("SETTINGS_LOAD", "Valeurs par defaut : %s", tostring(content)); return end
	local decoded, settings = pcall(HttpService.JSONDecode, HttpService, content)
	if not decoded or type(settings) ~= "table" or settings.Version ~= 1 then
		log("SETTINGS_LOAD", "Fichier invalide : valeurs par defaut conservees")
		return
	end
	if type(settings.AutomaticMode) == "boolean" then automaticMode = settings.AutomaticMode end
	if type(settings.IncludeMissingIndex) == "boolean" then autoIncludeMissingIndex = settings.IncludeMissingIndex end
	for _, key in ipairs({"OpenBelowRate"}) do
		local value = settings[key]
		if type(value) == "number" and value == value and value >= 0 and value < math.huge then
			openBelowRate = value
		end
	end
	searchingServer = false -- Never resume automatic server changes from saved settings.
	if settings.VisitedPlaceId == game.PlaceId and type(settings.VisitedServers)=="table" then
		if type(settings.VisitedCycleIndex)=="number" then visitedCycleIndex=settings.VisitedCycleIndex end
		for id,visited in pairs(settings.VisitedServers) do
			if type(id)=="string" and id~="" and visited==true then visitedServers[id]=true end
		end
	end
	-- Detailed telemetry disabled.

	if type(settings.HelpDelivered)=="table"then
  for key,state in pairs(settings.HelpDelivered)do if type(key)=="string"and #key<160 and(state=="pending"or state=="confirmed")then shared.__SEAHelpDelivered[key]=state end end
 end
 local minimum = settings.MinimumBillions
	if type(minimum) == "number" and minimum == minimum and minimum >= MINIMUM_BILLIONS and minimum <= MAXIMUM_BILLIONS then
		minimumRatePerSecond = minimum * 1e9
	end
 for key,value in pairs(FusionModules.Options)do
  if type(value)=="boolean"and key~="AutoPlotUpgrade"and key~="AutoTreadmillUpgrade"and key~="AutoHelp"and key~="AutoMutations"and key~="AutoSellAnimals"and not key:match("^Mutation")then FusionModules.Options[key]=automaticMode end
 end
 FusionModules.Options.AutoEggsMin=minimumRatePerSecond
 FusionModules.Options.AutoSellMax=minimumRatePerSecond
 FusionModules.Options.AutoOpenMax=openBelowRate
 FusionModules.Options.AutoPlaceMin=minimumRatePerSecond
 FusionModules.Options.AutoIndex=automaticMode and autoIncludeMissingIndex
 if type(settings.Settings)=="table"then
  if not FusionModules.Helpers.RestoreOptions(settings.Settings)then warn("[Auto_SAE] Parametres invalides : valeurs migrees conservees")end
 end
 automaticMode=true
 autoIncludeMissingIndex=FusionModules.Options.AutoIndex
	log("SETTINGS_LOADED", "Auto=%s Index=%s Minimum=%s B/s", tostring(automaticMode), tostring(autoIncludeMissingIndex), tostring(minimumRatePerSecond / 1e9))
end


local function syncVisitedServerCycle(forceReset)
	if not AreaEggCycle or not ServerClock then return end
	local ok,index=pcall(function() return AreaEggCycle.ActivePeriodIndexAt(ServerClock.Now()) end)
	if not ok or type(index)~="number" or index~=index or math.abs(index)==math.huge then return end
	if forceReset or visitedCycleIndex~=index then
		table.clear(visitedServers)
		if game.JobId~="" then visitedServers[game.JobId]=true end
		visitedCycleIndex=index
        if FusionModules.Reporting then FusionModules.Reporting.MarkSettingsDirty()end
		executorTools.SaveSettings()
		log("SERVER_CHANGE","Nouveau cycle d'oeufs=%s : historique serveurs reinitialise",tostring(index))
	end
end

local function logQueueDecision(uid, decision)
	if queueDecisionLogs[uid] == decision then return end
	queueDecisionLogs[uid] = decision
	log("QUEUE_DECISION", "UID=%s %s", uid, decision)
end

local lastStatusText
local function setStatus(text, color)
	if text ~= lastStatusText then
		lastStatusText = text
		log("STATUS", "%s", tostring(text))
	end
	if statusLabel then
		statusLabel.Text = text
		statusLabel.TextColor3 = color or Color3.fromRGB(225, 230, 245)
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(lifetimeConnections, connection)
	return connection
end

function FusionModules.Helpers.formatPosition(position)
	return string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
end

local function formatNumber(value)
	for _, unit in ipairs({{1e33,"Dc"},{1e30,"No"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},{1e18,"Qi"},{1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}) do
		if math.abs(value) >= unit[1] then
			return string.format("%.3g%s", value / unit[1], unit[2])
		end
	end
	return string.format("%.3g", value)
end


function FusionModules.Helpers.parseIncomeRate(text)
	if type(text) ~= "string" then return nil end
	local normalized = text:lower():gsub("%s+", ""):gsub(",", "."):gsub("/s$", "")
	local number, unit = normalized:match("^(%d*%.?%d+)(%a*)$")
	local multiplier = ({[""]=1e9,k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,qi=1e18,sx=1e21,sp=1e24,oc=1e27,no=1e30,dc=1e33})[unit]
	local value = tonumber(number)
	if not value or not multiplier then return nil end
	value *= multiplier
	if value ~= value or value < 0 or value == math.huge then return nil end
	return value
end

local function getCharacterParts()
	local character = player.Character
	if not character then return nil, nil, nil end
	return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function distanceXZ(first, second)
	local delta = first - second
	return Vector2.new(delta.X, delta.Z).Magnitude
end

-- Single movement primitive. Returns true only inside the arrival radius.
local function move(destination, options)
	options = options or {}
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root then return false, "personnage absent" end
	local stopping = options.Stop == true
	local arrived = false
	if not stopping and os.clock() < syncPauseUntil then return false, "synchronisation en cours" end
	if not stopping and movementResumePending then
		movementResumePending = false
		log("SYNC_DIAG", "Reprise du deplacement depuis la position actuelle apres correction")
	end
	if not stopping then
		if typeof(destination) ~= "Vector3" then return false, "destination invalide" end
		local arrivalPosition = options.ArrivalPosition or destination
		local distance = options.Flat == false and (root.Position - arrivalPosition).Magnitude
			or distanceXZ(root.Position, arrivalPosition)
		arrived = distance <= (options.Radius or 3)
		stopping = arrived
	end
	if stopping then humanoid:Move(Vector3.zero) end
	humanoid:MoveTo(stopping and root.Position or destination)
	if stopping then
		local hardBrake = options.HardBrake == true or arrived
		if hardBrake and os.clock() >= syncPauseUntil and character and humanoid.Health > 0 and not humanoid.PlatformStand and not humanoid.Sit
			and character:GetAttribute("IsTrapped") ~= true
			and not (rigPause.Character == character and os.clock() < rigPause.Until) then
			local endsAt = player:GetAttribute("RagdollEndTime")
			local state = humanoid:GetState()
			if (type(endsAt) ~= "number" or endsAt <= Workspace:GetServerTimeNow())
				and state ~= Enum.HumanoidStateType.Ragdoll
				and state ~= Enum.HumanoidStateType.FallingDown
				and state ~= Enum.HumanoidStateType.Physics then
				humanoid.Jump = false
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
				lastPhysicalBrakeAt = os.clock()
			end
		end
	end
	return arrived
end

local function stopMovement(hardBrake)
	return move(nil, {Stop = true, HardBrake = hardBrake == true})
end

local function readCarry()
	local ok, state = pcall(EggState.ReadCarryState)
	if ok and type(state) == "table" then return state end
	return nil
end

local function ownsEgg(uid)
	local ok, record = pcall(EggState.ReadOwnedEgg, player.UserId, uid)
	if ok and record ~= nil then return true, "ReadOwnedEgg" end
	if Save then
		local saveOK, profile = pcall(Save.Peek)
		if saveOK and profile and profile.EggInventory and profile.EggInventory[uid] then
			return true, "Save.EggInventory"
		end
	end
	for _, container in pairs({Backpack = player:FindFirstChildOfClass("Backpack"), Character = player.Character}) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "AssetEgg"
					and tool:GetAttribute("UID") == uid then
					return true, "Tool.UID"
				end
			end
		end
	end
	return false
end


local function isTrackedFieldState(record)
	return record and (record.State == SLOT_STATE or record.State == "Dropped"
		or record.State == "Carried" or record.State == "GuardCarried")
end

local function isHeldByOther(record)
	return record and (record.State == "GuardCarried"
		or (record.State == "Carried" and record.CarrierUserId ~= player.UserId))
end

local function findPhysicalEgg(uid)
	local object=Workspace:FindFirstChild(uid)
	if object and (object:IsA("Model") or object:IsA("BasePart")) then return object end
	for _, other in ipairs(Players:GetPlayers()) do
		local character=other.Character
		local found=character and character:FindFirstChild(uid,true)
		if found and (found:IsA("Model") or found:IsA("BasePart")) then return found end
	end
	return nil
end

local function physicalEggCarrier(object)
	local carrier=object:GetAttribute("CarrierUserId")
	if type(carrier)=="number" then return carrier,true end
	for _,other in ipairs(Players:GetPlayers()) do
		if other.Character and object:IsDescendantOf(other.Character) then return other.UserId,true end
	end
	for _,joint in ipairs(object:GetDescendants()) do
		if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
			for _,part in pairs({joint.Part0,joint.Part1}) do
				if part and not part:IsDescendantOf(object) and part~=object and part:IsDescendantOf(Workspace) then
					for _,other in ipairs(Players:GetPlayers()) do
						if other.Character and part:IsDescendantOf(other.Character) then return other.UserId,true end
					end
					return nil,true
				end
			end
		end
	end
	return nil,false
end

local function readField(uid)
	local ok, record = pcall(EggState.ReadFieldEgg, uid)
	if not ok then log("FIELD_READ_ERROR","%s",tostring(record)); return nil,false end
	local tracked=trackedEggs[uid]
	if record then
		if tracked then
			tracked.Record=record
			if record.CarrierUserId then tracked.LastCarrier=record.CarrierUserId end
			tracked.MissingSince=nil
		end
		if queuedEggs[uid] then queuedEggs[uid].Record=record end
		return record,true
	end
	if not tracked then return nil,true end
	if tracked.Record.State=="Claimed" or ownsEgg(uid) then trackedEggs[uid]=nil; return nil,true end
	if tracked.LastCarrier and os.clock()-(tracked.LastOwnerCheck or -math.huge)>=0.5 then
		tracked.LastOwnerCheck=os.clock()
		local ownedOK,owned=pcall(EggState.ReadOwnedEgg,tracked.LastCarrier,uid)
		if ownedOK and owned then
			log("EGG_TRACK","UID=%s Attribue au joueur=%s",uid,tostring(tracked.LastCarrier))
			trackedEggs[uid]=nil
			return nil,true
		end
	end
	local object=findPhysicalEgg(uid)
	if not object then
		tracked.MissingSince=tracked.MissingSince or os.clock()
		-- Briefly preserve a reparented/streamed object; absence is not a delivery verdict.
		if os.clock()-tracked.MissingSince>10 then
			log("EGG_TRACK","UID=%s Suivi termine : aucun objet ni etat observable depuis 10 s ; attribution inconnue",uid)
			trackedEggs[uid]=nil
			return nil,true
		end
		local waiting=table.clone(tracked.Record)
		waiting.State,waiting.CarrierUserId,waiting.ObservationOnly="GuardCarried",nil,true
		if queuedEggs[uid] then queuedEggs[uid].Record=waiting end
		return waiting,true
	end
	tracked.MissingSince=nil
	local position=object:IsA("Model") and object:GetPivot() or object.CFrame
	local carrier,attached=physicalEggCarrier(object)
	local observed=table.clone(tracked.Record)
	observed.BottomCFrame,observed.ObservationOnly=position,true
	if attached then
		tracked.UnattachedSince=nil
		observed.State=carrier and "Carried" or "GuardCarried"
		observed.CarrierUserId=carrier
		if carrier then tracked.LastCarrier=carrier end
	else
		tracked.UnattachedSince=tracked.UnattachedSince or os.clock()
		-- Physical drop is provisional. CarryFieldEgg still validates the UID on the server.
		observed.State=os.clock()-tracked.UnattachedSince>=0.3 and "Dropped" or "GuardCarried"
		observed.CarrierUserId=nil
	end
	if os.clock()-(tracked.LastSync or -math.huge)>3 and not tracked.SyncBusy and type(EggState.SyncFieldEggs)=="function" then
		tracked.LastSync,tracked.SyncBusy=os.clock(),true
		task.spawn(function()
			pcall(EggState.SyncFieldEggs)
			tracked.SyncBusy=false
		end)
	end
	if queuedEggs[uid] then queuedEggs[uid].Record=observed end
	return observed,true
end

local function getSeparationLine()
	local world = Workspace:FindFirstChild("World")
	local areas = world and world:FindFirstChild("Areas")
	local line = areas and areas:FindFirstChild("SeparationLine")
	return line and line:IsA("BasePart") and line or nil
end

local function isSafe(position)
	local line = getSeparationLine()
	if not line then return nil end
	return not GuardGeometry.IsPastLine(line, position)
end

local function validCycle(ctx)
	if destroyed or not autoEnabled or generation ~= ctx.generation or currentCycle ~= ctx then
		return false, "annule"
	end
	local character, humanoid, root = getCharacterParts()
	if character ~= ctx.character or not humanoid or not root or humanoid.Health <= 0 then
		return false, "personnage change ou mort"
	end
	return true
end

-- Observe server movement effects; never cancel ragdoll, impulses, or server corrections.
local function motionBlockReason(ctx)
	if os.clock() < syncPauseUntil then return "correction de position en cours" end
	local _, humanoid = getCharacterParts()
	if not humanoid then return "personnage absent" end
	if ctx.character:GetAttribute("IsTrapped") == true then return "IsTrapped" end
	if type(player.GetAttribute) == "function" and type(Workspace.GetServerTimeNow) == "function" then
		local endsAt = player:GetAttribute("RagdollEndTime")
		if type(endsAt) == "number" and endsAt > Workspace:GetServerTimeNow() then
			return "RagdollEndTime serveur"
		end
	end
	if rigPause.Character == ctx.character and os.clock() < rigPause.Until then return rigPause.Reason end
	if humanoid.PlatformStand or humanoid.Sit then return "PlatformStand / Sit" end
	if type(humanoid.GetState) == "function" then
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Physics then return tostring(state) end
	end
	return nil
end

local function observeRigRefresh(payload)
	-- Verified in Controllers.Game.ObbyAntiTPClientController: JSON Action/Arguments.
	if type(payload) ~= "string" then return end
	local ok, message = pcall(HttpService.JSONDecode, HttpService, payload)
	if not ok or type(message) ~= "table" then return end
	local action, arguments = message.Action, message.Arguments
	if action ~= "BeginImpulse" and action ~= "BeginRagdoll" and action ~= "EndRagdoll"
		and action ~= "Relocate" then return end
	local duration = type(arguments) == "table" and tonumber(arguments[1]) or nil
	if not duration or duration ~= duration or math.abs(duration) == math.huge then duration = 1 end
	if rigPause.Character ~= player.Character then rigPause.Until = 0 end
	rigPause.Character, rigPause.Reason = player.Character, "RigSync." .. action
	if action == "BeginImpulse" or action == "BeginRagdoll" then
		rigPause.Until = math.max(rigPause.Until, os.clock() + math.clamp(duration, 0.1, 10))
	else
		rigPause.Until = os.clock() + CONFIG.RigSettleTime
	end
	if action == "Relocate" then
		lastRelocateAt = os.clock()
		movementResumePending = true
		movementRevision += 1
		if autoEnabled then syncPauseUntil = math.max(syncPauseUntil, os.clock()+0.5) end
		if autoEnabled or currentCycle then
			log("SYNC_DIAG", "Source=RigSync.Relocate Revision=%d Phase=%s | repositionnement demande par le serveur ; commandes suspendues",
				movementRevision, currentCycle and currentCycle.phase or autoActivity)
		end
	end
	log("RIG_OBSERVED", "Action=%s PauseRestante=%.2fs | observation seule", action, rigPause.Until - os.clock())
end

local function waitForMotionReady(ctx)
	local started, logged = os.clock(), false
	while validCycle(ctx) do
		local reason = motionBlockReason(ctx)
		if not reason then
			if logged then log("MOVE_RESUME", "Phase=%s Attente=%.2fs", ctx.phase, os.clock() - started) end
			return true
		end
		if not logged then
			logged = true
			stopMovement() -- Cancel walking only, not the physical server impulse.
			log("MOVE_PAUSED", "Phase=%s Raison=%s", ctx.phase, reason)
		end
		if os.clock() - started >= CONFIG.MotionPauseTimeout then return false, "immobilisation serveur prolongee" end
		task.wait(0.05)
	end
	return false, "annule"
end

local function brakeAtArrival(ctx, destination, radius, flat)
	local _, _, root = getCharacterParts()
	if not root then return false, "personnage absent" end
	local started, before = os.clock(), root.AssemblyLinearVelocity
	stopMovement()
	if not CONFIG.EnableArrivalBrake then return true end
	ctx.braking = true
	local function finish(ok, reason)
		ctx.braking = false
		return ok, reason
	end
	repeat
		local valid, reason = validCycle(ctx)
		if not valid then return finish(false, reason) end
		local blocked = motionBlockReason(ctx)
		if blocked then return finish(false, "freinage interrompu : " .. blocked) end
		local distance = flat and distanceXZ(root.Position, destination) or (root.Position - destination).Magnitude
		if distance > radius then return finish(false, "derive apres arrivee") end
		ctx.braking = true
		stopMovement(true)
		if os.clock() - started >= CONFIG.ArrivalBrakeDuration then break end
		RunService.Heartbeat:Wait()
	until false
	log("ARRIVAL_BRAKE", "Phase=%s HorizontalAvant=%.2f HorizontalApres=%.2f Duree=%.3fs",
		ctx.phase, Vector2.new(before.X, before.Z).Magnitude,
		Vector2.new(root.AssemblyLinearVelocity.X, root.AssemblyLinearVelocity.Z).Magnitude, os.clock() - started)
	return finish(true)
end

local function setPhase(ctx, phase, message)
	if ctx.phase ~= phase then
		if timingEnabled then
			local now = os.clock()
			log("TIMING_PHASE", "Phase=%s DureeMs=%.1f DepuisDepartMs=%.1f", tostring(ctx.phase), (now - (ctx.phaseStartedAt or now)) * 1000, (now - (ctx.startedAt or now)) * 1000)
			ctx.phaseStartedAt = now
		end
		log("PHASE", "%s -> %s | %s", tostring(ctx.phase), phase, message or "")
		ctx.phase = phase
	end
	setStatus(message or phase)
end

local function getAssetConfig(record)
	if type(record) ~= "table" or type(record.AssetCategory) ~= "string" then
		return nil
	end

	return Assets.Directory[record.AssetCategory]
end

local function getRarityName(record)
	local config = getAssetConfig(record)
	local rarity = config and config.Rarity

	if type(rarity) == "string" then
		return rarity
	end

	if type(rarity) == "table" then
		return rarity._id or rarity.Id or rarity.Name
	end

	return "Inconnue"
end

function FusionModules.Helpers.IsAlwaysEligibleRarity(record)
 local rarity=getRarityName(record)
 return rarity=="Divine"
end

local function getAnimalName(record)
	local config = getAssetConfig(record)
	return config and config.DisplayName or record.AssetCategory or "Inconnu"
end

local function recordFlightResult(ctx, succeeded)
	if ctx.resultLogged then return end
	ctx.resultLogged = true
	local text = string.format('Vol de "%s" %s | %s', getAnimalName(ctx.record or {}), succeeded and "Reussi" or "Echoue",FusionModules.Helpers.DescribeEgg(ctx.record))
 if ctx.help then text="[AIDE Forest] "..text end
	table.insert(flightHistory, {Text=text, Success=succeeded})
	if #flightHistory > 200 then table.remove(flightHistory, 1) end
	log("FLIGHT_RESULT", "%s", text)
	if refreshFlightLog then refreshFlightLog() end
end

local function getRatePerSecond(record)
	if type(record) ~= "table" then
		return nil
	end

	local itemOk, itemData = pcall(EggRecords.ToAssetItemData, record)
	if not itemOk then
		warn("[Auto_SAE] Conversion impossible pour le revenu de", record.Uid, itemData)
		return nil
	end

	local rateOk, rate = pcall(AssetEarnings.RatePerSecond, itemData)
	if not rateOk or type(rate) ~= "number" then
		warn("[Auto_SAE] Calcul du revenu impossible pour", record.Uid, rate)
		return nil
	end

	return rate
end

local function getWeightKg(record)
	if type(record) ~= "table"
		or type(record.AssetCategory) ~= "string"
		or type(record.AssetScale) ~= "number" then
		return nil
	end

	local ok, weight = pcall(
		EggRecords.WeightKgForScale,
		record.AssetCategory,
		record.AssetScale
	)

	if ok and type(weight) == "number" then
		return weight
	end

	return nil
end



function FusionModules.Helpers.DescribeEgg(record)
 local name=getAnimalName(record or {})
 local weight=getWeightKg(record)
 local rate=getRatePerSecond(record)
 return string.format('%s [Poids=%s; Revenu=%s]',name,
  weight and (formatNumber(weight).." kg")or "inconnu",
  rate and (formatNumber(rate).."/s")or "inconnu")
end
function FusionModules.Helpers.DescribeAnimal(item)
 local category=type(item)=="table"and item.Category
 local config=Assets and Assets.Directory and category and Assets.Directory[category]
 local weightOK,weight=false,nil
 local rateOK,rate=false,nil
 if type(item)=="table"then
  if FusionModules.Items and FusionModules.Items.WeightKg then weightOK,weight=pcall(FusionModules.Items.WeightKg,item)end
  rateOK,rate=pcall(AssetEarnings.RatePerSecond,item)
 end
 return string.format('%s [Poids=%s; Revenu=%s]',tostring(config and config.DisplayName or category or "Animal inconnu"),
  weightOK and type(weight)=="number"and (formatNumber(weight).." kg")or "inconnu",
  rateOK and type(rate)=="number"and (formatNumber(rate).."/s")or "inconnu")
end
function FusionModules.Helpers.DescribeSavedAnimal(saved)
 local ok,item=pcall(FusionModules.Items.Decode,saved)
 return FusionModules.Helpers.DescribeAnimal(ok and item or nil)
end

-- Control reporting shares Observer's transport; field/player collection lives in Observer.lua.
FusionModules.Reporting = {
 Enabled=true, Url="wss://m4gix-ws.onrender.com/sae/ws", Socket=nil, Ready=false,
 Serial=0,
}
do
 local report=FusionModules.Reporting
 local options=shared.__AutoSAEReportingOptions
 if type(options)=="table" then
  report.Enabled=options.Enabled~=false
  if type(options.Url)=="string" and options.Url:match("^wss://") then report.Url=options.Url end
  report.Token=type(options.Token)=="string" and options.Token or nil
 end
 report.ClientKind=type(options)=="table" and options.ClientKind=="admin" and "admin" or "hub"
 report.Headless=type(options)=="table" and options.Headless==true
 report.SessionId=HttpService:GenerateGUID(false)
 function report.AutomationActive()
  return ready and automaticMode and (FusionModules.Options.AutoEggs or FusionModules.Options.AutoIndex) and not queuePaused and not stopAfterFlight and not destroyed and not serverHopPending
 end
 function report.AutomationReason()
  if destroyed then return "Script arrete"end
  if not ready then return "Chargement du jeu"end
  if serverHopPending then return "Teleportation en cours"end
  if not automaticMode then return "Mode AUTO OFF"end
  if queuePaused then return "File en pause"end
  if stopAfterFlight then return "Arret demande apres le vol"end
  if not FusionModules.Options.AutoEggs and not FusionModules.Options.AutoIndex then return "AutoEggs et Manquants OFF"end
  return autoEnabled and "Auto actif"or "Auto actif, worker en attente"
 end
 function report.FlushLogs()
  if not report.Ready or not report.LogIdentityReady or not report.LogsAllowed or not report.Socket then return false end
  local batch={}
  for i=1,math.min(100,#executorTools.RemoteLogQueue)do batch[i]=executorTools.RemoteLogQueue[i]end
  if #batch==0 then return true end
  return pcall(function()report.Socket:Send(HttpService:JSONEncode({version=1,type="logs.append",sessionId=report.SessionId,lines=batch}))end)
 end
 function report.MissingCategories()
  local result={}
  if not ready or not FusionModules.Options.AutoIndex or not Assets or not Assets.Directory then return result end
  local ok,profile=pcall(Save.Peek)
  if not ok or type(profile)~="table"or type(profile.Index)~="table"then return result end
  if not FusionModules.Helpers.backpackEggCategories or not FusionModules.Helpers.plotAnimalCategories then return result end
  local backpack=FusionModules.Helpers.backpackEggCategories(profile)
  local plot=FusionModules.Helpers.plotAnimalCategories()
  for category in pairs(Assets.Directory)do
   if type(category)=="string"and profile.Index[category]~=true and not backpack[category]and not plot[category]then result[category]=true end
  end
  return result
 end
 function report.VisitedJobs()
  local ids={}
  for id,visited in pairs(visitedServers)do if visited and #ids<500 then table.insert(ids,id)end end
  table.sort(ids)
  return ids
 end
 report.PolicyKnown=false;report.LogsAllowed=false;report.SettingsAllowed=false;report.SettingsDirty=true;report.TeleportAllowed=false
 report.SettingsRevision=0
 function report.ScheduleSettings()
  if report.SettingsScheduled or destroyed or not report.Ready or not report.LogIdentityReady or not report.SettingsAllowed or not report.Socket or not report.SettingsDirty then return end
  report.SettingsScheduled=true
  task.delay(.3,function()
   report.SettingsScheduled=false
   if destroyed or not report.Ready or not report.LogIdentityReady or not report.SettingsAllowed or not report.Socket or not report.SettingsDirty then return end
   report.SettingsRevision+=1
   local revision=report.SettingsRevision
   local serial=report.Serial
   local options=table.clone(FusionModules.Options)
   report.SettingsDirty=false
   report.SettingsPending=revision
   local ok=pcall(function()report.Socket:Send(HttpService:JSONEncode({version=1,type="settings.snapshot",sessionId=report.SessionId,revision=revision,options=options,automationActive=report.AutomationActive(),automationEnabled=automaticMode and not queuePaused and not stopAfterFlight and not destroyed,automationReason=report.AutomationReason(),visitedJobIds=report.VisitedJobs(),missingCategories=report.MissingCategories()}))end)
   if not ok then report.SettingsDirty=true end
   task.delay(5,function()
    if destroyed or report.Serial~=serial or report.SettingsPending~=revision or not report.SettingsAllowed then return end
    report.SettingsDirty=true
    report.ScheduleSettings()
   end)
  end)
 end
 function report.MarkSettingsDirty()
  report.SettingsDirty=true
  report.ScheduleSettings()
 end
 function report.ScheduleLogs()
  if report.LogScheduled or destroyed or not report.Ready or not report.LogIdentityReady or not report.PolicyKnown or not report.LogsAllowed or not report.Socket or #executorTools.RemoteLogQueue==0 then return end
  report.LogScheduled=true
  task.delay(1,function()
   report.LogScheduled=false
   if destroyed or not report.Ready or not report.LogIdentityReady or not report.Socket or #executorTools.RemoteLogQueue==0 then return end
   local batch={}
   for i=1,math.min(100,#executorTools.RemoteLogQueue)do batch[i]=executorTools.RemoteLogQueue[i]end
   pcall(function()report.Socket:Send(HttpService:JSONEncode({version=1,type="logs.append",sessionId=report.SessionId,lines=batch}))end)
   task.delay(5,function()report.ScheduleLogs()end)
  end)
 end
 function report.Log(message,...)
  log("REPORT",message,...)
 end
 function report.ApplyPolicy(message)
  report.PolicyKnown=true
  report.TeleportAllowed=message.sendTeleport==true and message.admin==true
  if not report.TeleportAllowed and FusionModules.RemoteHop then FusionModules.RemoteHop.Pending=nil end
  report.LogsAllowed=message.sendLogs==true
  if report.SettingsAllowed~=(message.sendSettings==true)then
   report.SettingsAllowed=message.sendSettings==true
   if report.SettingsAllowed then report.MarkSettingsDirty()end
  end
  if not report.LogsAllowed then table.clear(executorTools.RemoteLogQueue)else report.ScheduleLogs()end
 end
 function report.SyncObserver()
  local observer=report.Observer
  if not observer then return end
  if report.Socket~=observer.Socket then
   report.Serial+=1;report.SettingsDirty=true;report.SettingsPending=nil;report.AppliedPolicy=nil
   report.PolicyKnown=false;report.LogsAllowed=false;report.SettingsAllowed=false;report.TeleportAllowed=false
   report.Socket=observer.Socket
  end
  report.Ready=observer.Ready and not observer.Destroyed
  report.LogIdentityReady=observer.IdentityReady
  if observer.LastPolicy and report.AppliedPolicy~=observer.LastPolicy then
   report.AppliedPolicy=observer.LastPolicy;report.ApplyPolicy(observer.LastPolicy)
  end
  if report.Ready and report.LogIdentityReady then report.ScheduleSettings();report.ScheduleLogs()end
 end
 function report.Receive(message)
  if destroyed then return end
  report.SyncObserver()
  if message.type=="admin.command"then
   if report.ClientKind=="admin"and report.SettingsAllowed and report.AdminReceive then report.AdminReceive(message)end
  elseif message.type=="teleport.request"then
   if FusionModules.RemoteHop then FusionModules.RemoteHop.Receive(message)end
  elseif message.type=="settings.ack"and message.sessionId==report.SessionId then
   if report.SettingsPending==message.revision then report.SettingsPending=nil end
  elseif message.type=="logs.ack"and message.sessionId==report.SessionId then
   local upto=tonumber(message.sequence)
   if upto then while executorTools.RemoteLogQueue[1]and executorTools.RemoteLogQueue[1].sequence<=upto do table.remove(executorTools.RemoteLogQueue,1)end end
   report.ScheduleLogs()
  elseif message.type=="error"then report.Log("Render : %s",tostring(message.message))end
 end
 function report.Disconnect()
  report.Serial+=1;report.Ready=false;report.LogIdentityReady=false
  report.PolicyKnown=false;report.SettingsAllowed=false;report.LogsAllowed=false;report.TeleportAllowed=false;report.SettingsDirty=true
  report.Socket=nil
  if destroyed then
   if report.UnsubscribeObserver then report.UnsubscribeObserver();report.UnsubscribeObserver=nil end
   if report.Observer then report.Observer.Release(report.SessionId)end
  elseif report.Observer then report.Observer.Disconnect()end
 end
 -- Gameplay hints delegate observation to the shared Observer; no local snapshots.
 function report.MarkDirty()if report.Observer then report.Observer.MarkEggsDirty()end end
 function report.Reset()report.MarkDirty()end
 function report.Revealed()report.MarkDirty();report.MarkSettingsDirty()end
 function report.Start()
  if not report.Enabled then return end
  if Save and type(Save.Watch)=="function"and not report.SettingsWatchBound then
   report.SettingsWatchBound=true
   for _,key in ipairs({"Index","EggInventory","Inventory","EquippedAssets"})do connect(Save.Watch(key),report.MarkSettingsDirty)end
  end
  if report.Started or report.Starting then return end
  report.Starting=true
  local ready,problem=pcall(function()
  report.Observer=shared.__SEAObserverController
  if not report.Observer or report.Observer.Destroyed then
   local start,why=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Observer.lua"),"SEA_V2/Observer")
   assert(start,why);report.Observer=start()
  end
  report.Observer.Configure(report.ClientKind,report.SessionId,report.Url,report.Token)
  report.UnsubscribeObserver=report.Observer.Subscribe(report.Receive)
  end)
  report.Starting=false
  if not ready then error(problem)end
  if destroyed then report.Disconnect();return end
  report.Started=true
  log("SERVER_CHANGE","Arrive sur le serveur %s",game.JobId)
  task.spawn(function()
   while not destroyed and report.Enabled do
    local ok,why=pcall(function()
     report.SyncObserver()
     local state=tostring(report.AutomationActive())..":"..report.AutomationReason()
     if state~=report.LastAutomationState then report.LastAutomationState=state;report.MarkSettingsDirty()end
    end)
    if not ok then report.Log("Observer bridge : %s",tostring(why))end
    task.wait(.5)
   end
   report.Disconnect()
  end)
 end
end -- reporting scope



local function getRecordPosition(record)
	if type(record) == "table" and typeof(record.BottomCFrame) == "CFrame" then
		return record.BottomCFrame.Position
	end

	return nil
end

function FusionModules.Helpers.mutationLabel(record)
	if type(record) ~= "table"
		or type(record.Mutations) ~= "table"
		or #record.Mutations == 0 then
		return "Aucune"
	end

	return table.concat(record.Mutations, ", ")
end

function FusionModules.Helpers.versionKey(record)
	return tostring(record and record.Version or 0)
end

function FusionModules.Helpers.logEgg(record)
	if type(record) ~= "table" or type(record.Uid) ~= "string" then
		return
	end

	local currentVersion = FusionModules.Helpers.versionKey(record)
	if loggedVersions[record.Uid] == currentVersion then
		return
	end
	loggedVersions[record.Uid] = currentVersion

	local position = getRecordPosition(record)
	local weight = getWeightKg(record)
	local rate = getRatePerSecond(record)

	print(string.format(
		"[Auto_SAE][EGG] %s | %s | %s | %s | %s Kg | %s $/s | %s | %s",
		record.Uid,
		getAnimalName(record),
		getRarityName(record),
		tostring(record.AreaId or "Inconnu"),
		weight and string.format("%.2f", weight) or "Inconnu",
		rate and formatNumber(rate) or "Inconnu",
		FusionModules.Helpers.mutationLabel(record),
		position and FusionModules.Helpers.formatPosition(position) or "Inconnue"
		))
end


function FusionModules.Helpers.ownerSnapshot()
	local ok, inventory = pcall(EggState.ReadOwnerEggs, player.UserId)
	local merged = ok and type(inventory) == "table" and inventory or {}
	if Save then
		local saveOK, profile = pcall(Save.Peek)
		if saveOK and profile and type(profile.EggInventory) == "table" then
			for uid, record in pairs(profile.EggInventory) do merged[uid] = record end
		end
	end
	return merged
end

local function claimEvidence(ctx)
	local owned, source = ownsEgg(ctx.uid)
	if owned then return true, source end
	local carry = readCarry()
	if ctx.claimFeedback and (ctx.sawCarry or ctx.remoteAccepted) and carry and not carry.IsCarrying then
		for uid, record in pairs(FusionModules.Helpers.ownerSnapshot()) do
			if not ctx.ownerBefore[uid] and type(record) == "table"
				and record.AssetCategory == ctx.record.AssetCategory then
				return true, "FieldClaimed + nouvel UID inventaire " .. tostring(uid)
			end
		end
	end
	return false
end

local function updateCarryEvidence(ctx)
	local owned, source = ownsEgg(ctx.uid)
	if owned then
		ctx.claimed = true
		ctx.claimSource = source
		return true
	end
	local carry = readCarry()
	if carry and carry.IsCarrying and carry.Uid == ctx.uid then
		if ctx.reacquiring and not ctx.sawCarry then
			local latest = readField(ctx.uid)
			local freshTransport = latest and latest.State == "Carried"
				and latest.CarrierUserId == player.UserId
				and (not ctx.pickupVersion or latest.Version > ctx.pickupVersion)
			if not freshTransport then return ctx.remoteAccepted == true end
		end
		ctx.sawCarry = true
		return true
	end
	return ctx.remoteAccepted == true
end

local function startReturnImmediately(ctx, source)
	if currentCycle ~= ctx or generation ~= ctx.generation or ctx.returnKickAt then return end
	if not validCycle(ctx) or motionBlockReason(ctx) then return end
	local character, humanoid, root = getCharacterParts()
	if character ~= ctx.character or not humanoid or not root then return end
	ctx.returnKickAt = os.clock()
    if FusionModules.BatCombat then FusionModules.BatCombat.Stop()end
	ctx.hadCarry = true
	setPhase(ctx, "RETURN", "Prise confirmee : retour immediat")
	move(ctx.home, {Radius = CONFIG.ReturnDistance})
	log("GRAB_TO_RETURN", "Source=%s DelaiDepuisRequeteMs=%.1f WalkSpeed=%.2f | commande retour envoyee sans pause",
		source, (ctx.returnKickAt - (ctx.lastRequest or ctx.returnKickAt)) * 1000, humanoid.WalkSpeed)
end

local function requestCarry(ctx)
	if inFlightRequest and not inFlightRequest.done then return end
	if ctx.attempts >= CONFIG.MaxCarryAttempts then return end
	local request = {uid = ctx.uid, started = os.clock(), done = false, retryable = false, movementRevision = movementRevision}
	inFlightRequest = request
	shared.__AutoSAERemoteLock = request
	ctx.attempts += 1
	ctx.lastRequest = request.started
	setPhase(ctx, "CARRY_PENDING", "Prise serveur : " .. getAnimalName(ctx.record))
	log("CARRY_REQUEST", "Tentative=%d UID=%s", ctx.attempts, ctx.uid)
	task.spawn(function()
		if not validCycle(ctx) then
			request.done = true
			return
		end
		-- Recheck after task.spawn: high speed may have carried us past the egg.
		local _, _, root = getCharacterParts()
		local latest = readField(ctx.uid)
		local eggPosition = getRecordPosition(latest)
		local distance = root and eggPosition and (root.Position - eggPosition).Magnitude
		local blocked = motionBlockReason(ctx)
		local available = latest and (latest.State == SLOT_STATE or latest.State == "Dropped")
		if blocked or not available then
			request.done, request.accepted, request.retryable = true, false, blocked ~= nil
			request.reason = blocked and ("personnage immobilise : " .. blocked) or "oeuf non disponible"
			if ctx.onCarryReply then ctx.onCarryReply(request) end
			return
		end
		if not distance or distance > CONFIG.ApproachDistance then
			request.done, request.accepted, request.retryable = true, false, distance ~= nil
			request.reason = "distance de prise non valide : " .. (distance and string.format("%.2f studs", distance) or "position indisponible")
			ctx.denial = request.reason
			log("CARRY_DISTANCE_BLOCKED", "UID=%s Distance3D=%s Maximum=%.1f | aucun appel serveur",
				ctx.uid, tostring(distance), CONFIG.ApproachDistance)
			if ctx.onCarryReply then ctx.onCarryReply(request) end
			return
		end
		local slotKey
		if SlotIdentity.LooksLikeFirstAreaUid(ctx.uid) then
			slotKey = SlotIdentity.SlotKey(ctx.record.AreaId, ctx.record.NestId)
		end
		local areas = Workspace:FindFirstChild("World")
		areas = areas and areas:FindFirstChild("Areas")
		local line = areas and areas:FindFirstChild("SeparationLine")
		local depth = root and line and line:IsA("BasePart") and line.CFrame.LookVector:Dot(root.Position - line.Position)
		log("CARRY_CONTEXT", "Pos=%s Distance3D=%s ProfondeurLigne=%s SlotKey=%s",
			root and FusionModules.Helpers.formatPosition(root.Position) or "absent", tostring(distance), tostring(depth),
			tostring(slotKey))
		local ok, accepted, reason = pcall(EggState.CarryFieldEgg, ctx.uid, slotKey)
		if ok and accepted ~= true and type(reason) == "string" and reason:find("Enter the gameplay area first", 1, true) then
			ctx.gameplayEntryRejected = ctx.attempts >= CONFIG.MaxCarryAttempts
			ctx.preciseRadius = 1.5
		end
		if not ok or accepted ~= true then
			log("CARRY_DIAG", "Refus=%s PosLocale=%s DistanceLocale=%s CoteLigne=%s RevisionAvant=%d RevisionApres=%d DernierFreinMs=%.0f RegionAntiTpActive=%s",
				tostring(ok and reason or accepted), root and FusionModules.Helpers.formatPosition(root.Position) or "?",
				tostring(distance), tostring(depth), request.movementRevision, movementRevision,
				(os.clock()-lastPhysicalBrakeAt)*1000,
				tostring(Workspace:GetAttribute("AnticheatSuspendedRegion") ~= nil or Workspace:FindFirstChild("MonsterEventMap") ~= nil))
		end
		if ok and accepted ~= true and type(reason) == "string" and reason:lower():find("closer", 1, true) then
			ctx.preciseRadius = 1.5
		end
		request.done = true
		request.callOK, request.retryable = ok, ok and accepted ~= true and not ctx.gameplayEntryRejected
		request.accepted = ok and accepted == true
		request.reason = ok and reason or tostring(accepted)
		-- A timed-out InvokeServer may finish later. It never controls a newer cycle.
		log("CARRY_REPLY", "UID=%s CallOK=%s Accepted=%s Reason=%s Latence=%.3fs SessionActive=%s",
			ctx.uid, tostring(ok), tostring(request.accepted), tostring(request.reason),
			os.clock() - request.started, tostring(validCycle(ctx)))
		if not validCycle(ctx) then return end
		ctx.remoteAccepted = request.accepted
		if request.accepted then startReturnImmediately(ctx, "CARRY_REPLY") end
		ctx.denial = request.reason
		if ctx.onCarryReply then ctx.onCarryReply(request) end
	end)
	return request
end

-- Cancellable waits; movement listeners and refreshes are disposed on completion.
local function awaitCycleOperation(ctx, timeout, start)
	if not validCycle(ctx) then return false, "annule" end
	local signal = Instance.new("BindableEvent")
	local completed, result = false, nil
	local function finish(...)
		if completed then return end
		completed = true
		result = table.pack(...)
		signal:Fire()
	end
	local cancel = function() finish(false, "annule") end
	ctx.cancelPendingWait = cancel
	local timer = task.delay(timeout, function() finish(false, "delai depasse") end)
	local startOK, dispose = pcall(start, finish)
	if not startOK then finish(false, tostring(dispose)) end
	if not completed then signal.Event:Wait() end
	if ctx.cancelPendingWait == cancel then ctx.cancelPendingWait = nil end
	pcall(task.cancel, timer)
	if startOK and type(dispose) == "function" then pcall(dispose) end
	signal:Destroy()
	return table.unpack(result, 1, result.n)
end

local function traceMoveEnd(ctx, root, destination, reached)
	local latest = readField(ctx.uid)
	local fromRecord = latest and typeof(latest.BottomCFrame) == "CFrame"
	local eggPosition = fromRecord and latest.BottomCFrame.Position or ctx.eggPosition or destination
	local playerPosition = root.Position
	local measuredAt = os.clock()
	ctx.moveEndTrace = {
		EggPosition = eggPosition, PlayerPosition = playerPosition,
		Reached = reached, At = measuredAt,
	}
	log("MOVE_END_POSITIONS", "Reached=%s | Oeuf=%s | Player=%s | DestinationMoveTo=%s | DistanceXZ=%.2f studs | Distance3D=%.2f studs | Vitesse=%.2f studs/s | SourceOeuf=%s",
		tostring(reached), FusionModules.Helpers.formatPosition(eggPosition), FusionModules.Helpers.formatPosition(playerPosition),
		FusionModules.Helpers.formatPosition(destination), distanceXZ(playerPosition, eggPosition),
		(playerPosition - eggPosition).Magnitude, root.AssemblyLinearVelocity.Magnitude,
		fromRecord and "EggState" or "memorisee")
	for _, delaySeconds in ipairs({0.1, 0.25, 0.5}) do
		task.delay(delaySeconds, function()
			if not validCycle(ctx) or (ctx.phase ~= "APPROACH" and ctx.phase ~= "CARRY_PENDING") then return end
			local _, _, currentRoot = getCharacterParts()
			if currentRoot ~= root then return end
			local position = root.Position
			log("MOVE_END_DRIFT", "ApresFin=%.3fs | Phase=%s | Oeuf=%s | Player=%s | DistanceXZ=%.2f studs | DeplacementDepuisFinXZ=%.2f studs | Vitesse=%.2f studs/s",
				os.clock() - measuredAt, tostring(ctx.phase), FusionModules.Helpers.formatPosition(eggPosition),
				FusionModules.Helpers.formatPosition(position), distanceXZ(position, eggPosition),
				distanceXZ(position, playerPosition), root.AssemblyLinearVelocity.Magnitude)
		end)
	end
end


local function followTakenEgg(ctx)
	local startedFollowing=false
	while validCycle(ctx) do
		if stopAfterFlight then stopMovement(true); return false,"arret du suivi demande" end
		local record,ok=readField(ctx.uid)
		if not ok or not record then stopMovement(true); return false,"TARGET_UNAVAILABLE" end
		if record.State=="Claimed" then
			trackedEggs[ctx.uid]=nil
			stopMovement(true)
			log("EGG_TRACK","UID=%s Etat serveur=Claimed : fin du suivi",ctx.uid)
			return false,"TARGET_UNAVAILABLE"
		end
		ctx.record,ctx.eggPosition=record,getRecordPosition(record)
		if not isHeldByOther(record) then
			if startedFollowing then
				stopMovement(true)
				cooldowns[ctx.uid]=nil
				log("EGG_TRACK","UID=%s Oeuf disponible a nouveau%s",ctx.uid,record.ObservationOnly and " (observation physique, serveur a confirmer)" or "")
			end
			return true
		end
		if not startedFollowing then
			startedFollowing=true
			setPhase(ctx,"FOLLOW","Suivi de "..getAnimalName(record).." porte par un autre joueur")
			log("EGG_TRACK","UID=%s Debut suivi porteur=%s Observation=%s",ctx.uid,tostring(record.CarrierUserId),tostring(record.ObservationOnly==true))
		end
		if motionBlockReason(ctx) then
			local resumed,why=waitForMotionReady(ctx)
			if not resumed then return false,why end
		else
			local _,_,root=getCharacterParts()
			local carrier=record.CarrierUserId and Players:GetPlayerByUserId(record.CarrierUserId)
			local carrierRoot=carrier and carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart")
			local position=carrierRoot and carrierRoot.Position or ctx.eggPosition
			if root and position then
				local delta=Vector3.new(root.Position.X-position.X,0,root.Position.Z-position.Z)
				if delta.Magnitude>10 then
					local target=position+delta.Unit*7
					move(Vector3.new(target.X,root.Position.Y,target.Z),{Radius=2})
				else stopMovement(true) end
			else stopMovement() end
		end
		task.wait(0.1)
	end
	return false,"annule"
end

local function approachEgg(ctx, destination)
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root then return false, "personnage absent" end
	setPhase(ctx, "APPROACH", "Course vers : " .. getAnimalName(ctx.record))
	local started, lastCommand, lastLog = os.clock(), -math.huge, -math.huge
	local lastMoved, lastPosition = started, root.Position
	local initialDistance = distanceXZ(root.Position, destination)
	local timeout = math.clamp(initialDistance / math.max(humanoid.WalkSpeed, 1) * 4 + 15, 15, 150) + CONFIG.MotionPauseTimeout
	local nativeReached, retryRequested = nil, false
	local pausedAt
	local previousApproachPosition = root.Position
	log("MOVE_APPROACH_START", "Destination=%s Pos=%s WalkSpeed=%.1f Renouvellement=%.1fs Maximum=%.1fs",
		FusionModules.Helpers.formatPosition(destination), FusionModules.Helpers.formatPosition(root.Position), humanoid.WalkSpeed,
		CONFIG.ApproachRefresh, timeout)
	local finished, moveReason = awaitCycleOperation(ctx, timeout, function(finish)
		local active = true
		local function complete(ok, reason)
			if not active then return end
			active = false
			finish(ok, reason)
		end
		local function checkProgress()
			if not active then return end
			local valid, reason = validCycle(ctx)
			if not valid then complete(false, reason); return end
			if ctx.help and FusionModules.Help.HasNormal()then complete(false,"HELP_PRIORITY");return end
   local blocked = motionBlockReason(ctx)
			if blocked then
				if not pausedAt then
					pausedAt = os.clock()
					stopMovement()
					log("MOVE_PAUSED", "Phase=APPROACH Raison=%s", blocked)
				end
				lastMoved = os.clock()
				if os.clock() - pausedAt >= CONFIG.MotionPauseTimeout then
					complete(false, "immobilisation serveur prolongee")
				end
				return
			elseif pausedAt then
				log("MOVE_RESUME", "Phase=APPROACH Attente=%.2fs", os.clock() - pausedAt)
				pausedAt, lastCommand, lastMoved = nil, -math.huge, os.clock()
				previousApproachPosition = root.Position
			end
			local latest, readOK = readField(ctx.uid)
			local eggPosition = getRecordPosition(latest)
			if not readOK or not eggPosition then
				complete(false, "position actuelle de l'oeuf indisponible")
				return
			end
			if latest.State ~= SLOT_STATE and latest.State ~= "Dropped" then
				complete(false, isHeldByOther(latest) and "TARGET_HELD_OTHER" or "oeuf non disponible pendant l'approche")
				return
			end
			local updatedDestination = Vector3.new(eggPosition.X, ctx.home.Y, eggPosition.Z)
			local targetMoved = distanceXZ(updatedDestination, destination) > 0.01
			ctx.record, ctx.eggPosition, destination = latest, eggPosition, updatedDestination
			local now = os.clock()
			local distance = distanceXZ(root.Position, destination)
			if distanceXZ(lastPosition, root.Position) >= 0.5 then
				lastMoved, lastPosition = now, root.Position
			end
			local preciseRadius = ctx.preciseRadius or CONFIG.PreciseArrivalRadius
			local currentPosition = root.Position
			local segment = Vector3.new(currentPosition.X - previousApproachPosition.X, 0, currentPosition.Z - previousApproachPosition.Z)
			local offset = Vector3.new(eggPosition.X - previousApproachPosition.X, 0, eggPosition.Z - previousApproachPosition.Z)
			local crossed = false
			if segment.Magnitude > 0.01 then
				local projection = offset:Dot(segment) / segment:Dot(segment)
				crossed = projection > 0 and projection < 1
					and (offset - segment * projection).Magnitude <= preciseRadius
			end
			previousApproachPosition = currentPosition
			if distance <= preciseRadius and (root.Position - eggPosition).Magnitude <= CONFIG.ApproachDistance then
				traceMoveEnd(ctx, root, destination, true)
				complete(true, "distance verifiee")
				return
			end
			if crossed then
				stopMovement(true)
				retryRequested = true
				log("APPROACH_OVERSHOOT_BRAKE", "Cible franchie entre deux frames, distance=%.2f : freinage puis correction", distance)
			end
			if now - lastMoved > CONFIG.NoMovementTimeout then
				complete(false, "course bloquee sans progression")
				return
			end
			if distance < 100 or targetMoved or retryRequested or now - lastCommand >= CONFIG.ApproachRefresh then
				local firstCommand = lastCommand == -math.huge
				lastCommand, retryRequested = now, false
				log(firstCommand and "MOVE_COMMAND" or "MOVE_RENEW", "Destination=%s DistanceXZ=%.2f Temps=%.2fs | sans arret ni changement de vitesse",
					FusionModules.Helpers.formatPosition(destination), distance, now - started)
				move(destination, {Radius = ctx.preciseRadius or CONFIG.PreciseArrivalRadius, Flat = true, ArrivalPosition = eggPosition})
			end
			if now - lastLog >= CONFIG.ProgressInterval then
				lastLog = now
				log("MOVE_PROGRESS", "Phase=APPROACH Pos=%s DistanceXZ=%.2f WalkSpeed=%.1f VitesseReelle=%.1f Temps=%.2fs",
					FusionModules.Helpers.formatPosition(root.Position), distance, humanoid.WalkSpeed,
					root.AssemblyLinearVelocity.Magnitude, now - started)
			end
		end
		local moveConnection = humanoid.MoveToFinished:Connect(function(didReach)
			if not active then return end
			nativeReached = didReach
			traceMoveEnd(ctx, root, destination, didReach)
			log("MOVE_NATIVE_FINISHED", "Reached=%s DistanceRestanteXZ=%.2f | seule la distance reelle autorise la prise",
				tostring(didReach), distanceXZ(root.Position, destination))
			retryRequested = true
			checkProgress()
		end)
		local heartbeatConnection = RunService.Heartbeat:Connect(checkProgress)
		checkProgress()
		return function()
			active = false
			moveConnection:Disconnect()
			heartbeatConnection:Disconnect()
		end
	end)
	if not finished then
		log("MOVE_APPROACH_CANCELLED", "%s", tostring(moveReason))
		return false, "MoveTo interrompu : " .. tostring(moveReason)
	end
	if not validCycle(ctx) then return false, "annule" end
	-- Cancel momentum immediately; no fixed settling wait before the direct request.
	stopMovement(true)
	local braked = distanceXZ(root.Position, ctx.eggPosition) <= (ctx.preciseRadius or CONFIG.PreciseArrivalRadius)
		and (root.Position - ctx.eggPosition).Magnitude <= CONFIG.ApproachDistance
	local brakeReason = "derive apres arrivee"
	if not braked then return false, brakeReason end
	log("MOVE_APPROACH_FINISHED", "NativeReached=%s Pos=%s DistanceRestanteXZ=%.2f | une tentative serveur apres verification",
		tostring(nativeReached), FusionModules.Helpers.formatPosition(root.Position), distanceXZ(root.Position, destination))
	traceMoveEnd(ctx, root, destination, true)
	return true
end

local function tryCarryOnce(ctx)
	-- MoveToFinished(false) is not arrival. requestCarry rechecks the live egg distance.
	local replied, accepted, reason, retryable = awaitCycleOperation(ctx, CONFIG.RequestTimeout, function(finish)
		ctx.onCarryReply = function(request)
			finish(true, request.accepted, request.reason, request.retryable)
		end
		local request = requestCarry(ctx)
		if not request then
			finish(false, false, "requete deja en cours ou indisponible")
		elseif request.done then
			finish(true, request.accepted, request.reason, request.retryable)
		end
		return function() ctx.onCarryReply = nil end
	end)
	if not replied then
		return false, reason or tostring(accepted), false
	end
	local grabbed = accepted == true or updateCarryEvidence(ctx)
	log("CARRY_SINGLE_DONE", "Accepted=%s PriseConfirmee=%s Reason=%s",
		tostring(accepted), tostring(grabbed), tostring(reason))
	if grabbed then return true end
	return false, "prise refusee : " .. tostring(reason), retryable == true
end

local function moveThenCarry(ctx, destination)
	local lastReason
	for attempt = 1, CONFIG.MaxCarryAttempts do
		if not validCycle(ctx) then return false, "annule" end
		if updateCarryEvidence(ctx) then return true end
		local movable, moveReason = waitForMotionReady(ctx)
		if not movable then return false, moveReason end
		local arrived, approachReason
		repeat
			local followed, why=followTakenEgg(ctx)
			if not followed then return false,why end
			if updateCarryEvidence(ctx) then return true end
			if ctx.eggPosition then destination=Vector3.new(ctx.eggPosition.X,ctx.home.Y,ctx.eggPosition.Z) end
			arrived,approachReason=approachEgg(ctx,destination)
		until approachReason~="TARGET_HELD_OTHER"
		if validCycle(ctx) and updateCarryEvidence(ctx) then return true end
		local retryable = false
		if arrived then
			if updateCarryEvidence(ctx) then return true end
			local grabbed, reason, canRetry = tryCarryOnce(ctx)
			if grabbed then return true end
			lastReason, retryable = reason, canRetry
		else
			lastReason = approachReason
			retryable = approachReason == "derive apres arrivee" or motionBlockReason(ctx) ~= nil
		end
		if not validCycle(ctx) then return false, "annule" end
		if inFlightRequest and not inFlightRequest.done then return false, lastReason end
		local latest = readField(ctx.uid)
		if not retryable or attempt == CONFIG.MaxCarryAttempts or not latest
			or (latest.State ~= SLOT_STATE and latest.State ~= "Dropped") then break end
		ctx.record, ctx.eggPosition = latest, getRecordPosition(latest)
		if not ctx.eggPosition then break end
		destination = Vector3.new(ctx.eggPosition.X, ctx.home.Y, ctx.eggPosition.Z)
		log("CARRY_RETRY", "UID=%s ProchainEssai=%d/%d Raison=%s Pause=%.2fs | requetes en serie",
			ctx.uid, attempt + 1, CONFIG.MaxCarryAttempts, tostring(lastReason), CONFIG.CarryRetryDelay)
		task.wait(CONFIG.CarryRetryDelay)
	end
	return false, lastReason or "prise non confirmee"
end

local function carryWasLost(ctx)
	if not ctx.hadCarry then return false end
	local latest = readField(ctx.uid)
	local carry = readCarry()
	local newer = latest and (not ctx.pickupVersion or latest.Version > ctx.pickupVersion)
	local dropped = newer and (latest.State == "Dropped" or latest.State == "GuardCarried"
		or latest.State == "Slot"
		or (latest.State == "Carried" and latest.CarrierUserId ~= nil
			and latest.CarrierUserId ~= player.UserId))
	if not dropped and not ctx.carryLostAt and carry and carry.IsCarrying and carry.Uid == ctx.uid then
		ctx.sawCarry = true
		return false
	end
	local owned, source = claimEvidence(ctx)
	if owned then
		ctx.claimed, ctx.claimSource, ctx.carryLostAt = true, source, nil
		return false
	end
	if dropped or ctx.carryLostAt then
		ctx.carryLostAt = ctx.carryLostAt or os.clock()
		ctx.sawCarry = false
		if not ctx.lossLogged then
			ctx.lossLogged = true
			log("EGG_LOST", "UID=%s Etat=%s CarryUID=%s | retour interrompu pour reprendre le meme oeuf",
				ctx.uid, latest and tostring(latest.State) or "en attente",
				carry and tostring(carry.Uid) or "?")
		end
		return true
	end
	return false
end

local function waitForRecoverableEgg(ctx)
	setPhase(ctx, "RECOVERY_WAIT", "Recherche de l'oeuf perdu : " .. getAnimalName(ctx.record))
	local started, lastLog = os.clock(), -math.huge
	while validCycle(ctx) do
		local owned, source = claimEvidence(ctx)
		if owned then
			ctx.claimed, ctx.claimSource = true, source
			return nil, "CLAIMED"
		end
		local latest = readField(ctx.uid)
		local carry = readCarry()
		local blocked = motionBlockReason(ctx)
		local trapped = blocked ~= nil
		if carry and carry.IsCarrying and carry.Uid == ctx.uid
			and (ctx.sawCarry or (latest and latest.State == "Carried"
				and latest.CarrierUserId == player.UserId
				and (not ctx.pickupVersion or latest.Version > ctx.pickupVersion)))
			and (not latest or (latest.State == "Carried" and latest.CarrierUserId == player.UserId)) then
			ctx.sawCarry, ctx.carryLostAt = true, nil
			startReturnImmediately(ctx, "CARRY_CHANGED")
			return nil, "CARRIED"
		end
		if latest and (latest.State == "Dropped" or latest.State == SLOT_STATE)
			and typeof(latest.BottomCFrame) == "CFrame" and not trapped then
			log("EGG_RECOVERABLE", "UID=%s Etat=%s PositionActuelle=%s Version=%s",
				ctx.uid, latest.State, FusionModules.Helpers.formatPosition(latest.BottomCFrame.Position), tostring(latest.Version))
			return latest, "AVAILABLE"
		end
		local now = os.clock()
		if now - lastLog >= 0.5 then
			lastLog = now
			log("RECOVERY_WAIT", "UID=%s Etat=%s Immobilise=%s Temps=%.1fs",
				ctx.uid, latest and tostring(latest.State) or "absent / replication",
				tostring(blocked), now - started)
		end
		if now - started >= CONFIG.RecoveryStateTimeout then
			return nil, "recuperation impossible : oeuf non disponible apres attente"
		end
		task.wait(0.1)
	end
	return nil, "annule"
end

local function recoverSameEgg(ctx)
	stopMovement()
	local recoveryStarted = os.clock()
	ctx.recoveryCount = (ctx.recoveryCount or 0) + 1
	log("RECOVERY_START", "UID=%s Reprise=%d HomeConservee=%s",
		ctx.uid, ctx.recoveryCount, FusionModules.Helpers.formatPosition(ctx.home))
	while validCycle(ctx) do
		if os.clock() - recoveryStarted > CONFIG.RecoveryStateTimeout then
			return false, "recuperation abandonnee apres plusieurs echecs"
		end
		local latest, state = waitForRecoverableEgg(ctx)
		if state == "CLAIMED" or state == "CARRIED" then return true end
		if not latest then return false, state end
		if inFlightRequest and not inFlightRequest.done then
			return false, "recuperation suspendue : requete serveur encore en cours"
		end
		ctx.record, ctx.eggPosition, ctx.pickupVersion = latest, latest.BottomCFrame.Position, latest.Version
		ctx.remoteAccepted, ctx.sawCarry, ctx.claimed, ctx.claimFeedback = false, false, false, false
		ctx.carryLostAt, ctx.lossLogged, ctx.reacquiring = nil, false, true
		ctx.attempts, ctx.lastRequest = 0, -math.huge
		ctx.returnKickAt = nil
		local destination = Vector3.new(ctx.eggPosition.X, ctx.home.Y, ctx.eggPosition.Z)
		local grabbed, reason = moveThenCarry(ctx, destination)
		if grabbed then
			ctx.reacquiring, ctx.hadCarry = false, true
			log("RECOVERY_GRABBED", "UID=%s Reprise=%d | nouveau retour vers la meme zone safe",
				ctx.uid, ctx.recoveryCount)
			return true
		end
		if not validCycle(ctx) then return false, "annule" end
		if inFlightRequest and not inFlightRequest.done then
			return false, "recuperation suspendue : requete serveur sans reponse"
		end
		log("RECOVERY_RETRY", "UID=%s Raison=%s | nouvelle lecture de la position avant nouvel essai",
			ctx.uid, tostring(reason))
		task.wait(CONFIG.RecoveryRetryDelay)
	end
	return false, "annule"
end

local function moveReturnLoop(ctx, destination)
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root then return false, "personnage absent" end
	local started, lastCommand, lastLog = os.clock(), -math.huge, -math.huge
	local lastMoved, lastPosition = started, root.Position
	local distance = distanceXZ(root.Position, destination)
	local timeout = math.clamp(distance / math.max(humanoid.WalkSpeed, 1) * 4 + 15, 15, 150) + CONFIG.MotionPauseTimeout
	ctx.returnStartDistance = distance
	ctx.returnDestination = destination
	ctx.lastReturnJump = nil
	setPhase(ctx, "RETURN", "Retour vers la zone sure")
	while true do
		local valid, reason = validCycle(ctx)
		if not valid then return false, reason end
		if ctx.watchForReappearance then
			local carry = readCarry()
			if carry and carry.IsCarrying and carry.Uid == ctx.uid then
				ctx.hadCarry, ctx.sawCarry, ctx.watchForReappearance = true, true, false
				return false, "TARGET_CARRIED"
			end
			local latest, readOK = readField(ctx.uid)
			if readOK and isHeldByOther(latest) then
				local followed,why=followTakenEgg(ctx)
				if not followed then return false,why end
				latest,readOK=readField(ctx.uid)
			end
			if readOK and latest and (latest.State == SLOT_STATE or latest.State == "Dropped")
				and latest.CarrierUserId == nil and getRecordPosition(latest) and not ownsEgg(ctx.uid) then
				ctx.record, ctx.eggPosition = latest, getRecordPosition(latest)
				return false, "TARGET_REAPPEARED"
			end
			if carry and not carry.IsCarrying and ctx.findNext and not (inFlightRequest and not inFlightRequest.done) then
				local nextEgg = ctx.findNext()
				if nextEgg and nextEgg.Uid ~= ctx.uid then return false, "NEXT_AVAILABLE" end
			end
		elseif not ctx.helpReturning and carryWasLost(ctx) then
			return false, CARRY_LOST
		end
		if motionBlockReason(ctx) then
			local resumed, pauseReason = waitForMotionReady(ctx)
			if not resumed then return false, pauseReason end
			lastMoved, lastCommand, lastPosition = os.clock(), -math.huge, root.Position
			continue
		end
		local now = os.clock()
		distance = distanceXZ(root.Position, destination)
		local insideSafe = isSafe(root.Position) == true
		local arrivalRadius = ctx.help and not ctx.helpReturning and 3 or CONFIG.ReturnDistance
		if insideSafe and not ctx.help then
			humanoid.Jump = false
			local velocity = root.AssemblyLinearVelocity
			local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
			arrivalRadius = math.max(arrivalRadius, math.min(30, horizontalSpeed * 0.1))
			local claimed, source = claimEvidence(ctx)
			if claimed then
				ctx.claimed, ctx.claimSource = true, source
				stopMovement(true)
				log("RETURN_CLAIM_EARLY", "Attribution confirmee en zone sure : fin du trajet, distance=%.2f", distance)
				return true
			end
		end
		if distanceXZ(lastPosition, root.Position) >= 0.5 then
			lastMoved, lastPosition = now, root.Position
		end
		if distance <= arrivalRadius then
			log("RETURN_BRAKE_ZONE", "Distance=%.2f Rayon=%.2f Safe=%s", distance, arrivalRadius, tostring(insideSafe))
			local braked, brakeReason = brakeAtArrival(ctx, destination, arrivalRadius, true)
			if not ctx.helpReturning and carryWasLost(ctx) then return false, CARRY_LOST end
			if braked then return true end
			if not validCycle(ctx) then return false, brakeReason end
			lastCommand, lastMoved = -math.huge, os.clock()
			continue
		end
		if now - started > timeout then return false, "delai de retour depasse" end
		if now - lastMoved > CONFIG.NoMovementTimeout then return false, "retour bloque" end
		if distance < 100 or now - lastCommand >= CONFIG.MoveRefresh then
			move(destination, {Radius = arrivalRadius})
			lastCommand = now
		end
		if now - lastLog >= CONFIG.ProgressInterval then
			lastLog = now
			log("MOVE_PROGRESS", "Phase=RETURN Pos=%s DistanceXZ=%.2f WalkSpeed=%.1f VitesseReelle=%.1f Safe=%s",
				FusionModules.Helpers.formatPosition(root.Position), distance, humanoid.WalkSpeed,
				root.AssemblyLinearVelocity.Magnitude, tostring(isSafe(root.Position)))
		end
		RunService.Heartbeat:Wait()
	end
end

local function waitForClaim(ctx)
	setPhase(ctx, "CONFIRM_CLAIM", "Verification de l'oeuf dans l'inventaire")
	local started, lastLog = os.clock(), -math.huge
	while validCycle(ctx) do
		local owned, source = claimEvidence(ctx)
		if owned then
			ctx.claimed, ctx.claimSource = true, source
			log("CLAIM_CONFIRMED", "UID=%s Source=%s | cycle termine", ctx.uid, source)
			return true
		end
		if carryWasLost(ctx) then return false, CARRY_LOST end
		local now = os.clock()
		local carry = readCarry()
		if now - lastLog >= 0.5 then
			lastLog = now
			log("CLAIM_WAIT", "Carry=%s CarryUID=%s Feedback=%s Temps=%.1fs",
				carry and tostring(carry.IsCarrying) or "?",
				carry and tostring(carry.Uid) or "?", tostring(ctx.claimFeedback), now - started)
		end
		if now - started >= CONFIG.ClaimTimeout then
			return false, "attribution non confirmee pour l'UID ; verifie la zone safe"
		end
		task.wait(0.1)
	end
	return false, "annule"
end


-- Native bat Tool activation only; combat remains subject to the game's validators.
FusionModules.BatCombat={NextCheckAt=0,NextSwingAt=0,NextScanAt=0,Tool=nil,EquippedByScript=false,Count=0}
function FusionModules.BatCombat.Stop()
 local state=FusionModules.BatCombat
 local tool=state.Tool
 if tool then
  pcall(function()
   tool:Deactivate()
   local backpack=player:FindFirstChildOfClass("Backpack")
   if state.EquippedByScript and backpack and tool.Parent==player.Character then tool.Parent=backpack end
  end)
 end
 if state.Count>0 then
  log("ACTION","Frappes batte terminees : %s | %d activation(s) demandee(s)",tostring(state.GearName),state.Count)
 end
 state.Tool=nil;state.EquippedByScript=false;state.Count=0;state.GearName=nil
end
function FusionModules.BatCombat.FindBest(character,backpack)
 local state=FusionModules.BatCombat
 if not state.Directory then return nil end
 local best,bestData,bestName
 for _,container in pairs({character,backpack})do
  if container then for _,tool in ipairs(container:GetChildren())do
   if tool:IsA("Tool")then
    local name=tool:GetAttribute("GearName")
    local config=type(name)=="string"and state.Directory[name]
    local data=config and config.BatControllerData
    if type(data)=="table" and type(data.Force)=="number" and type(data.RangeBonus)=="number" and type(data.Duration)=="number" then
     if not bestData or data.Force>bestData.Force
      or (data.Force==bestData.Force and data.RangeBonus>bestData.RangeBonus)
      or (data.Force==bestData.Force and data.RangeBonus==bestData.RangeBonus and data.Duration>bestData.Duration)
      or (data.Force==bestData.Force and data.RangeBonus==bestData.RangeBonus and data.Duration==bestData.Duration and name<bestName)then
      best,bestData,bestName=tool,data,name
     end
    end
   end
  end end
 end
 return best,bestName
end
function FusionModules.BatCombat.Step()
 local state=FusionModules.BatCombat
 local ctx=currentCycle
 local preparing=not ctx and state.ApproachUid~=nil and autoActivity=="TO_FARM"
 if destroyed or not autoEnabled or serverHopPending or (not ctx and not preparing) or (ctx and not validCycle(ctx)) then state.Stop();return end
 local carry=readCarry()
 local uid=ctx and ctx.uid or state.ApproachUid
 local character,humanoid,root=getCharacterParts()
 if not character or not humanoid or not root or humanoid.Health<=0 or not carry or carry.IsCarrying
  or (ctx and ctx.claimed) or ownsEgg(uid) then state.Stop();return end
 for _,child in ipairs(character:GetChildren())do
  if child:IsA("Tool")and child:GetAttribute("ItemType")=="AssetEgg"then state.Stop();return end
 end
 if ctx and (ctx.phase=="CONFIRM_CLAIM" or ((ctx.remoteAccepted or ctx.sawCarry or ctx.hadCarry) and not ctx.carryLostAt and not ctx.watchForReappearance and not ctx.reacquiring))then state.Stop();return end
 local now=os.clock()
 if now<state.NextCheckAt then return end
 state.NextCheckAt=now+.1
 if motionBlockReason(ctx or {character=character})then return end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if not state.Tool or (state.Tool.Parent~=backpack and state.Tool.Parent~=character) or now>=state.NextScanAt then
  state.NextScanAt=now+1
  local best,name=state.FindBest(character,backpack)
  if best~=state.Tool then state.Stop();state.Tool=best;state.GearName=name end
 end
 local tool=state.Tool
 if not tool then return end
 if tool.Parent~=character then
  humanoid:EquipTool(tool)
  state.EquippedByScript=true
 end
 if tool.Parent~=character or now<state.NextSwingAt or isSafe(root.Position)==true then return end
 -- Respect the authoritative replicated cooldown, including a previous manual click.
 local cooldownEnd=tool:GetAttribute("CooldownEndTime")
 if type(cooldownEnd)=="number"and Workspace:GetServerTimeNow()<cooldownEnd then return end
 carry=readCarry()
 if not carry or carry.IsCarrying or (ctx and not validCycle(ctx))then state.Stop();return end
 local interval=.7
 if GameplayBalance then
  interval=math.max(interval,tonumber(GameplayBalance.BatClient and GameplayBalance.BatClient.CLIENT_COOLDOWN)or 0,tonumber(GameplayBalance.BatServer and GameplayBalance.BatServer.PLAYER_COOLDOWN)or 0)
 end
 state.NextSwingAt=now+interval
 tool:Activate()
 state.Count+=1
 if state.Count==1 then
  local record=ctx and ctx.record or records[uid]
  log("ACTION","Frappes batte en cours : %s | Vol de %s",tostring(state.GearName),FusionModules.Helpers.DescribeEgg(record))
 end
end
local function cleanupCycle(ctx)
	if currentCycle ~= ctx then return end
    FusionModules.BatCombat.Stop()
    FusionModules.BatCombat.ApproachUid=nil
	recordFlightResult(ctx, false)
	if timingEnabled then
		local now = os.clock()
		log("TIMING_CYCLE", "TotalMs=%.1f DernierePhase=%s PhaseMs=%.1f", (now - (ctx.startedAt or now)) * 1000, tostring(ctx.phase), (now - (ctx.phaseStartedAt or now)) * 1000)
	end
	if ctx.cancelPendingWait then ctx.cancelPendingWait() end
	stopMovement()
	if shared.__AutoSAEMovementLock == ctx.movementLock then shared.__AutoSAEMovementLock = nil end
	currentCycle = nil
end

local function getStartAreaDestination()
	local world = Workspace:FindFirstChild("World")
	local areas = world and world:FindFirstChild("Areas")
	local area = areas and areas:FindFirstChild("StartArea")
	local center
	if area and area:IsA("BasePart") then
		center = area.Position
	elseif area and area:IsA("Model") and area:FindFirstChildWhichIsA("BasePart", true) then
		local bounds = area:GetBoundingBox()
		center = bounds.Position
	end
	if not center then return nil, "World.Areas.StartArea introuvable ou sans centre" end
	local _, humanoid = getCharacterParts()
	return center + Vector3.new(0, (humanoid and humanoid.HipHeight or 2) + 2, 0)
end

-- Help favorites only authorize assistance; they never receive Admin privileges or GO.
FusionModules.Help={DropRequest=shared.__SEAHelpDropRequest}
shared.__SEAHelpDelivered=shared.__SEAHelpDelivered or{}
shared.__SEAHelpActive=shared.__SEAHelpActive or{}
FusionModules.Help.Delivered=shared.__SEAHelpDelivered
FusionModules.Help.Active=shared.__SEAHelpActive
function FusionModules.Help.Key(uid)return tostring(game.JobId)..":"..tostring(uid)end
function FusionModules.Help.WasDelivered(uid)return FusionModules.Help.Delivered[FusionModules.Help.Key(uid)]~=nil end
function FusionModules.Help.Present()
 if not FusionModules.Options.AutoHelp or FusionModules.Reporting.ClientKind~="admin"then return false end
 local names={};for name in FusionModules.Options.HelpFavorites:gmatch("[^,%s;]+")do names[name:lower()]=true end
 for _,other in ipairs(Players:GetPlayers())do if other~=player and names[other.Name:lower()]then return true end end
 return false
end
function FusionModules.Help.Eligible(record)
 if not record or FusionModules.Help.WasDelivered(record.Uid)or not FusionModules.Help.Present()then return false end
 local rate=getRatePerSecond(record)
 if type(rate)~="number"or rate~=rate or rate<FusionModules.Options.AutoHelpMin or rate>=FusionModules.Options.AutoEggsMin then return false end
 local ok,p=pcall(Save.Peek)
 -- An unknown index or a missing species is always reserved for the Admin.
 if not ok or type(p)~="table"or type(p.Index)~="table"or p.Index[record.AssetCategory]~=true then return false end
 if FusionModules.Options.AutoEggs and FusionModules.Helpers.IsAlwaysEligibleRarity(record)then return false end
 return true
end
function FusionModules.Help.HasNormal()
 syncQueue()
 for uid,entry in pairs(queuedEggs)do if entry.Source~="HELP"and(not currentCycle or uid~=currentCycle.uid)and(cooldowns[uid]or 0)<=os.clock()then return true end end
 return false
end
function FusionModules.Help.Destination()
 local w=Workspace:FindFirstChild("World");local a=w and w:FindFirstChild("Areas");local g=a and a:FindFirstChild("GuardAreas");local f=g and g:FindFirstChild("Forest")
 local bounds=f and f:FindFirstChild("Bounds")
 if not bounds or not bounds:IsA("BasePart")then return nil end
 local _,humanoid=getCharacterParts()
 return bounds.Position+Vector3.new(0,(humanoid and humanoid.HipHeight or 2)+2,0)
end
function FusionModules.Help.Deposit(ctx,destination)
 if FusionModules.Help.WasDelivered(ctx.uid)then return false,"Depot deja envoye : aucun renvoi"end
 local carry=readCarry();local _,_,root=getCharacterParts()
 if not validCycle(ctx)or not root or distanceXZ(root.Position,destination)>5 or isSafe(root.Position)~=false or not carry or not carry.IsCarrying or carry.Uid~=ctx.uid then return false,"Depot Forest indisponible"end
 local key=FusionModules.Help.Key(ctx.uid)
 FusionModules.Help.Delivered[key]="pending";executorTools.SaveSettings()
 local request={done=false};FusionModules.Help.DropRequest=request;shared.__SEAHelpDropRequest=request
 task.spawn(function()request.ok,request.accepted,request.reason=pcall(EggState.DropFieldEgg,"PlayerRequest");request.done=true end)
 local deadline=os.clock()+CONFIG.RequestTimeout
 while not request.done and validCycle(ctx)and os.clock()<deadline do RunService.Heartbeat:Wait()end
 if not request.done then return false,"Depot en attente : aucun nouvel envoi"end
 if not request.ok or request.accepted~=true then
  if request.ok then FusionModules.Help.Delivered[key]=nil;executorTools.SaveSettings()end
  return false,"Depot refuse ou incertain : "..tostring(request.reason or request.accepted)
 end
 deadline=os.clock()+5
 repeat
  carry=readCarry();local record,readOK=readField(ctx.uid);local position=record and getRecordPosition(record)
  if carry and not carry.IsCarrying and readOK and record and record.State=="Dropped"and record.CarrierUserId==nil and position and distanceXZ(position,destination)<=15 then
   FusionModules.Help.Delivered[key]="confirmed";FusionModules.Help.Active[key]=nil;executorTools.SaveSettings()
   setStatus("AIDE : oeuf depose dans Forest")
   return true
  end
  RunService.Heartbeat:Wait()
 until not validCycle(ctx)or os.clock()>=deadline
 return false,"Depot accepte, confirmation terrain en attente : aucun renvoi"
end

local function runCycle(record, rate, recovering, findNext)
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root then return false, "personnage absent" end
	local destination, destinationReason = getStartAreaDestination()
	if not destination then return false, destinationReason end
	safeHome = destination

	if not safeHome or isSafe(safeHome) ~= true then
		return false, "position de retour sure non disponible"
	end
	local help=(queuedEggs[record.Uid]and queuedEggs[record.Uid].Source=="HELP")or(recovering==true and FusionModules.Help.Active[FusionModules.Help.Key(record.Uid)]==true)
 local helpDestination=help and FusionModules.Help.Destination()
 if help and not helpDestination then return false,"Centre Forest introuvable"end
 local ctx = {
  help=help,
		uid = record.Uid, record = record, generation = generation, character = character, findNext = findNext,
		startedAt = os.clock(), phaseStartedAt = os.clock(),
		home = safeHome, eggPosition = record.BottomCFrame and record.BottomCFrame.Position,
		attempts = 0, lastRequest = -math.huge, phase = "SELECTED", ownerBefore = FusionModules.Helpers.ownerSnapshot(),
		remoteAccepted = recovering == true, sawCarry = recovering == true,
		pickupVersion = record.Version, hadCarry = recovering == true,
	}
	if shared.__AutoSAEMovementLock then return false, "un autre deplacement automatique est actif" end
	ctx.movementLock = {Owner = "Auto_SAE", Character = character, Generation = generation}
	shared.__AutoSAEMovementLock = ctx.movementLock
	currentCycle = ctx
 if help then FusionModules.Help.Active[FusionModules.Help.Key(record.Uid)]=true end
 log("ACTION",'Vol de "%s" en cours | %s',getAnimalName(record),FusionModules.Helpers.DescribeEgg(record))
	log("TARGET", "Animal=%s Revenu=%s/s Home=%s Recovery=%s",
		getAnimalName(record), formatNumber(rate or 0), FusionModules.Helpers.formatPosition(ctx.home), tostring(recovering))
	local cycleOK, completed, failure = xpcall(function()
		local grabbed, grabReason
		if recovering then
			grabbed = true
		elseif not ctx.eggPosition then
			return false, "position de l'oeuf absente"
		else
			local destination = Vector3.new(ctx.eggPosition.X, ctx.home.Y, ctx.eggPosition.Z)
			grabbed, grabReason = measureAction("APPROCHE_ET_PRISE", moveThenCarry, ctx, destination)
		end
		if ctx.gameplayEntryRejected then
			return false, "GAMEPLAY_ENTRY_REQUIRED"
		end
		if not validCycle(ctx) then return false, "annule" end
		if not grabbed and inFlightRequest and not inFlightRequest.done then
			return false, grabReason or "requete serveur encore en cours"
		end
		if ctx.help then
   if grabbed then
    local delivered,why=moveReturnLoop(ctx,helpDestination)
    if not delivered then return false,why end
    delivered,why=FusionModules.Help.Deposit(ctx,helpDestination)
    if not delivered then return false,why end
   end
   ctx.helpReturning=true;ctx.watchForReappearance=false
   local returned,why=moveReturnLoop(ctx,ctx.home)
   if not returned then return false,why end
   if not grabbed then FusionModules.Help.Active[FusionModules.Help.Key(ctx.uid)]=nil;return false,"NEXT_AVAILABLE"end
   return true
  end
  ctx.hadCarry = grabbed == true
		ctx.watchForReappearance = not grabbed
		if not grabbed then log("TARGET_RETURN_EMPTY", "UID=%s : retour en surveillant sa reapparition", ctx.uid) end
		while validCycle(ctx) do
			local returned, returnReason = measureAction("RETOUR", moveReturnLoop, ctx, ctx.home)
			if returned then
				local _, _, currentRoot = getCharacterParts()
				if not currentRoot or isSafe(currentRoot.Position) ~= true then
					return false, "retour termine mais ligne safe non franchie"
				end
				if not grabbed then return false, "TARGET_UNAVAILABLE" end
				local claimed, claimReason = measureAction("CONFIRMATION_ATTRIBUTION", waitForClaim, ctx)
				if claimed then return true end
				if claimReason ~= CARRY_LOST then return false, claimReason end
				returnReason = CARRY_LOST
			end
			if returnReason == "TARGET_CARRIED" then
				grabbed = true
			elseif returnReason == "TARGET_REAPPEARED" then
				if inFlightRequest and not inFlightRequest.done then
					return false, "requete serveur encore en cours"
				end
				log("TARGET_REAPPEARED", "UID=%s : reprise du trajet vers l'oeuf", ctx.uid)
				ctx.pickupVersion = ctx.record.Version
				ctx.returnKickAt = nil
				ctx.remoteAccepted, ctx.sawCarry, ctx.claimed, ctx.claimFeedback = false, false, false, false
				ctx.carryLostAt, ctx.lossLogged, ctx.reacquiring = nil, false, false
				ctx.attempts, ctx.lastRequest = 0, -math.huge
				local target = Vector3.new(ctx.eggPosition.X, ctx.home.Y, ctx.eggPosition.Z)
				grabbed, grabReason = moveThenCarry(ctx, target)
				if ctx.gameplayEntryRejected then return false, "GAMEPLAY_ENTRY_REQUIRED" end
				if not validCycle(ctx) then return false, "annule" end
				if not grabbed and inFlightRequest and not inFlightRequest.done then
					return false, grabReason or "requete serveur encore en cours"
				end
				ctx.hadCarry = grabbed == true
				ctx.watchForReappearance = not grabbed
			elseif returnReason == CARRY_LOST then
				grabbed = false
				ctx.hadCarry, ctx.watchForReappearance = false, true
				log("TARGET_RETURN_EMPTY", "UID=%s : port perdu, retour sans arret en surveillant l'oeuf", ctx.uid)
			else
				return false, returnReason
			end
		end
		return false, "annule"
	end, debug.traceback)
	recordFlightResult(ctx, cycleOK and completed == true)
	cleanupCycle(ctx)
	if not cycleOK then return false, tostring(completed) end
	return completed, failure
end

local function ingest(record)
	if type(record) ~= "table" or type(record.Uid) ~= "string" then return end
	records[record.Uid] = record
	if trackedEggs[record.Uid] then
		trackedEggs[record.Uid].Record=record
		if record.CarrierUserId then trackedEggs[record.Uid].LastCarrier=record.CarrierUserId end
	end
	FusionModules.Helpers.logEgg(record)
end

local function snapshot(snapshotData)
	if type(snapshotData) ~= "table" or type(snapshotData.Records) ~= "table" then return end
	local updated = {}
	for _, record in ipairs(snapshotData.Records) do
		if type(record) == "table" and type(record.Uid) == "string" then
			updated[record.Uid] = record
			FusionModules.Helpers.logEgg(record)
		end
	end
	records = updated
    if FusionModules.Reporting then FusionModules.Reporting.MarkDirty(.75) end
end

function FusionModules.Helpers.QueueDistance(record,position)
 if not position or type(record)~="table" or typeof(record.BottomCFrame)~="CFrame" then return math.huge end
 return distanceXZ(record.BottomCFrame.Position,position)
end
function FusionModules.Helpers.QueueBefore(a,b)
 if (a.Source=="HELP")~=(b.Source=="HELP")then return a.Source~="HELP"end
 if FusionModules.Options.QueueNearest and a.Distance~=b.Distance then return a.Distance<b.Distance end
 if a.Rate~=b.Rate then return a.Rate>b.Rate end
 if a.Distance~=b.Distance then return a.Distance<b.Distance end
 return a.Uid<b.Uid
end
local function queueOrder()
	local result = {}
    local _,_,root=getCharacterParts()
	for uid, entry in pairs(queuedEggs) do
		entry.Uid = uid
		entry.Rate = getRatePerSecond(records[uid] or entry.Record) or entry.Rate or 0
        entry.Distance=FusionModules.Helpers.QueueDistance(records[uid]or entry.Record,root and root.Position)
		table.insert(result, entry)
	end
	table.sort(result,FusionModules.Helpers.QueueBefore)
	return result
end

-- Mirror the backpack: placed eggs are excluded from its virtual egg list.
function FusionModules.Helpers.backpackEggCategories(profile)
	local categories = {}
	for _, egg in pairs(type(profile) == "table" and profile.EggInventory or {}) do
		if type(egg) == "table" and egg.Placement == nil and type(egg.AssetCategory) == "string" then
			categories[egg.AssetCategory] = true
		end
	end
	return categories
end

function FusionModules.Helpers.plotAnimalCategories()
	local categories = {}
	if AssetRoster then
		local ok, pen = pcall(AssetRoster.ReadOwnerPen, player.UserId)
		if ok and type(pen) == "table" then
			for _, record in pairs(pen) do
				local item = type(record) == "table" and record.ItemData
				if type(item) == "table" and type(item.Category) == "string" then categories[item.Category] = true end
			end
		end
	end
	local ok, profile = pcall(Save.Peek)
	if ok and type(profile) == "table" then
		for _, egg in pairs(profile.EggInventory or {}) do
			if type(egg) == "table" and egg.Placement ~= nil and type(egg.AssetCategory) == "string" then
				categories[egg.AssetCategory] = true
			end
		end
	end
	return categories
end

local function enqueueEgg(record, source)
	if type(record) ~= "table" or type(record.Uid) ~= "string" then return false end
	if FusionModules.Help.WasDelivered(record.Uid)then return false end
 local function reject(reason)
		if source == "AUTO" or source == "RARITY" then logQueueDecision(record.Uid, reason) end
		return false
	end
	if source == "INDEX" and FusionModules.Helpers.plotAnimalCategories()[record.AssetCategory] then return reject("EXCLU : espece deja presente dans ton plot") end
	if (source == "AUTO" or source == "INDEX") and removedFromAuto[record.Uid] then return reject("EXCLU : retire manuellement de la file") end
	if source == "MANUEL" then removedFromAuto[record.Uid] = nil end
	if source == "INDEX" then
		if currentCycle and currentCycle.record and currentCycle.record.AssetCategory == record.AssetCategory then return false end
		for _, entry in pairs(queuedEggs) do
			if entry.Record.AssetCategory == record.AssetCategory then return false end
		end
	end
	if queuedEggs[record.Uid] then
		if source == "AUTO" or source == "RARITY" then logQueueDecision(record.Uid, "EN FILE | Auto=" .. tostring(autoEnabled) .. " Pause=" .. tostring(queuePaused) .. " Activite=" .. autoActivity .. " Cooldown=" .. tostring((cooldowns[record.Uid] or 0) > os.clock())) end
		return false
	end
	if not isTrackedFieldState(record) then return reject("EXCLU : etat=" .. tostring(record.State)) end
	if ownsEgg(record.Uid) then return reject("EXCLU : oeuf deja possede") end
	trackedEggs[record.Uid] = trackedEggs[record.Uid] or {Record=record}
	trackedEggs[record.Uid].Record=record
	if record.CarrierUserId then trackedEggs[record.Uid].LastCarrier=record.CarrierUserId end
	queuedEggs[record.Uid] = {Record = record, Rate = getRatePerSecond(record) or 0, Source = source}
	logQueueDecision(record.Uid, "AJOUT " .. source .. " | revenu=" .. tostring(queuedEggs[record.Uid].Rate) .. " seuil=" .. tostring(minimumRatePerSecond))
	return true
end

syncQueue = function()
	if not ready or destroyed then return end
	local plotCategories = FusionModules.Helpers.plotAnimalCategories()
	for uid, entry in pairs(queuedEggs) do
		if not currentCycle or currentCycle.uid ~= uid then
			local record = readField(uid)
			if not record or ownsEgg(uid) or not isTrackedFieldState(record)or FusionModules.Help.WasDelivered(uid)
    or(not automaticMode and entry.Source~="MANUEL")
    or(entry.Source=="HELP"and not FusionModules.Help.Eligible(record))
				or (entry.Source == "INDEX" and (not FusionModules.Options.AutoIndex or plotCategories[record.AssetCategory]))
    or ((entry.Source=="AUTO"or entry.Source=="RARITY")and not FusionModules.Options.AutoEggs)
    or (entry.Source=="AUTO"and ((getRatePerSecond(record)or 0)<FusionModules.Options.AutoEggsMin or (getRatePerSecond(record)or math.huge)>FusionModules.Options.AutoEggsMax))then
				queuedEggs[uid],trackedEggs[uid] = nil,nil
			else
				entry.Record = record
			end
		end
	end
	if automaticMode and(FusionModules.Options.AutoEggs or FusionModules.Options.AutoIndex)then
		local ok, profile = pcall(Save.Peek)
		local index = ok and type(profile) == "table" and profile.Index
		local backpackCategories = FusionModules.Helpers.backpackEggCategories(ok and profile or nil)
		local candidates = {}
		for uid, record in pairs(records) do
			do
				local calculatedRate = getRatePerSecond(record)
				local rate = calculatedRate or 0

				local missing = FusionModules.Options.AutoIndex and type(index) == "table"
					and type(record.AssetCategory) == "string" and Assets.Directory[record.AssetCategory] ~= nil
					and index[record.AssetCategory] ~= true
					and not backpackCategories[record.AssetCategory]
                    and not plotCategories[record.AssetCategory]
				if FusionModules.Options.AutoEggs and FusionModules.Helpers.IsAlwaysEligibleRarity(record) then
					local existing = queuedEggs[uid]
					if existing then existing.Source = "RARITY" end
					enqueueEgg(record, "RARITY")
				elseif FusionModules.Options.AutoEggs and calculatedRate and rate >= minimumRatePerSecond and rate<=FusionModules.Options.AutoEggsMax then
					local existing = queuedEggs[uid]
					if existing and existing.Source == "INDEX" then existing.Source = "AUTO" end
					enqueueEgg(record, "AUTO")
				elseif missing then
					table.insert(candidates, record)
				else
					logQueueDecision(uid, calculatedRate and ("HORS SEUIL : revenu=" .. tostring(rate) .. " seuil=" .. tostring(minimumRatePerSecond) .. " | index non eligible") or "REVENU INDISPONIBLE : calcul impossible")
				end
			end
		end
		-- Rebuild pending Index entries to keep the most profitable available egg.
		for uid, entry in pairs(queuedEggs) do
			if entry.Source == "INDEX" and not isHeldByOther(entry.Record) and (not currentCycle or currentCycle.uid ~= uid) then
				queuedEggs[uid] = nil
			end
		end
		table.sort(candidates, function(a,b)
			local ar,br = getRatePerSecond(a) or 0,getRatePerSecond(b) or 0
			if ar ~= br then return ar > br end
			return a.Uid < b.Uid
		end)
		for _, record in ipairs(candidates) do enqueueEgg(record, "INDEX") end
	end
	if FusionModules.Help.Present()then
  for uid,record in pairs(records)do if not queuedEggs[uid]and FusionModules.Help.Eligible(record)then enqueueEgg(record,"HELP")end end
 end
 local total, queued, above = 0, 0, 0
	for _, record in pairs(records) do
		total += 1
		if (getRatePerSecond(record) or 0) >= minimumRatePerSecond then above += 1 end
	end
	for _ in pairs(queuedEggs) do queued += 1 end
	local summary = string.format("AutoParam=%s Collecte=%s Pause=%s Seuil=%s Detectes=%d AuDessusSeuil=%d EnFile=%d",
		tostring(automaticMode), tostring(autoEnabled), tostring(queuePaused), tostring(minimumRatePerSecond), total, above, queued)
	if summary ~= lastQueueSummary then
		lastQueueSummary = summary
		log("QUEUE_SUMMARY", "%s", summary)
	end
	if refreshQueueInterface then refreshQueueInterface() end
end

-- Retain the exact remote target while the destination client's field/profile replicate.
FusionModules.Arrival={}
function FusionModules.Arrival.Clear(reason)
 local arrival=FusionModules.Arrival
 if not arrival.Uid then return end
 log("ARRIVAL_TARGET","UID=%s : %s",arrival.Uid,tostring(reason))
 arrival.Uid=nil;arrival.Deadline=nil
 pcall(function()game:GetService("TeleportService"):SetTeleportSetting("OvoraRemoteArrival",nil)end)
end
function FusionModules.Arrival.Load()
 local ok,saved=pcall(function()return game:GetService("TeleportService"):GetTeleportSetting("OvoraRemoteArrival")end)
 if not ok or type(saved)~="table"or saved.clientKind~=FusionModules.Reporting.ClientKind
  or saved.jobId~=game.JobId or saved.reporterUserId~=tostring(player.UserId)
  or type(saved.uid)~="string"or saved.uid==""or #saved.uid>128
  or type(saved.expiresAt)~="number"or saved.expiresAt~=saved.expiresAt
  or saved.expiresAt<=os.time()or saved.expiresAt>os.time()+300 then return end
 FusionModules.Arrival.Uid=saved.uid
 FusionModules.Arrival.Deadline=os.clock()+math.min(CONFIG.ArrivalTargetTimeout,saved.expiresAt-os.time())
end
function FusionModules.Arrival.Waiting()
 local arrival=FusionModules.Arrival
 if not arrival.Uid then return false end
 if destroyed or not automaticMode then arrival.Clear("AUTO inactif");return false end
 if os.clock()>=arrival.Deadline then arrival.Clear("Delai de chargement termine");return false end
 if ownsEgg(arrival.Uid)then arrival.Clear("Oeuf deja possede");return false end
 local record,ok=readField(arrival.Uid)
 if ok and record and not record.ObservationOnly then
  if not isTrackedFieldState(record)or isHeldByOther(record)then arrival.Clear("Cible indisponible");return false end
  if queuedEggs[arrival.Uid]and(getRatePerSecond(record)~=nil or FusionModules.Helpers.IsAlwaysEligibleRarity(record))then return false end
  local profileOK,profile=pcall(Save.Peek)
  if profileOK and type(profile)=="table"and type(profile.Index)=="table"and getRatePerSecond(record)~=nil then
   arrival.Clear("Cible non eligible selon les options actuelles");return false
  end
 end
 return true
end
FusionModules.Arrival.Load()

local function selectBest()
	local best, bestRate = nil, -math.huge
    local bestPriority
	local _, _, root = getCharacterParts()
	for uid, entry in pairs(queuedEggs) do
		local cached = records[uid] or entry.Record
		if queuedEggs[uid] and isTrackedFieldState(cached) and (cooldowns[uid] or 0) <= os.clock() then
			local latest, ok = readField(uid)
			if ok and isTrackedFieldState(latest) and not ownsEgg(uid) then
				if not latest.ObservationOnly then records[uid] = latest end
				local rate = getRatePerSecond(latest)
				if rate == nil and FusionModules.Helpers.IsAlwaysEligibleRarity(latest) then rate = 0 end
				if rate then
					if uid==FusionModules.Arrival.Uid then return latest,rate end
					local priority={Uid=uid,Source=entry.Source,Rate=rate,Distance=FusionModules.Helpers.QueueDistance(latest,root and root.Position)}
                    if not bestPriority or FusionModules.Helpers.QueueBefore(priority,bestPriority)then
                     best,bestRate,bestPriority=latest,rate,priority
                    end
				end
			end
		end
	end
	return best, bestRate
end

stopAutomation = function(reason, pause)
	queuePaused = pause ~= false and not automaticMode
	if automaticMode then stopAfterFlight = false end
	FusionModules.QueueResumeAt = os.clock() + 3
	autoEnabled = false
    if FusionModules.Reporting then FusionModules.Reporting.MarkSettingsDirty()end
	generation += 1
	if currentCycle then cleanupCycle(currentCycle) end
	stopMovement(true)
	setStatus(reason or "Arrete", Color3.fromRGB(255, 150, 120))
	if renderControls then renderControls() end
	log("STOP", "%s | RemoteEnCours=%s | RepriseAuto=%s", reason or "utilisateur", tostring(inFlightRequest and not inFlightRequest.done), tostring(automaticMode))
end

local function activityValid(token, character)
	return not destroyed and autoEnabled and generation == token and not queuePaused
		and player.Character == character
end

local function moveActivity(destination, token, interruptForEgg, nextDestination)
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root then return false, "personnage absent" end
	local started = os.clock()
	local deadline = started + math.clamp(distanceXZ(root.Position, destination) / math.max(humanoid.WalkSpeed, 1) * 3 + 5, 8, 30)
	local previous = root.Position
	local nextCommand = 0
	while true do
  if autoActivity=="TO_UPGRADE"and FusionModules.UpgradeMoveValid and not FusionModules.UpgradeMoveValid()then stopMovement(true);return false,"upgrade interrompue : priorite au vol ou option OFF"end
  if autoActivity=="TO_TREADMILL"and not FusionModules.Options.AutoTreadmill then stopMovement(true);return false,"tapis OFF"end
		if not activityValid(token, character) or humanoid.Health <= 0 then
			stopMovement()
			return false, "annule"
		end
		if interruptForEgg and (not automaticMode or next(queuedEggs) ~= nil) then
			stopMovement()
			return false, "nouvel oeuf"
		end
		local now = os.clock()
		local current = root.Position
		local distance = distanceXZ(current, destination)
		if distance <= 3 then
			move(destination, {Radius = 3})
			log("ACTIVITY_ARRIVED", "Activite=%s Distance=%.2f DureeMs=%.1f", autoActivity, distance, (now-started)*1000)
			if typeof(nextDestination) == "Vector3" then
				move(nextDestination, {Radius = CONFIG.PreciseArrivalRadius})
				log("ACTIVITY_CHAIN", "Depart->oeuf : commande envoyee dans la meme frame que le freinage")
			end
			return true
		end
		if now >= deadline then stopMovement(true); return false, "MoveTo : destination non atteinte" end
		if not motionBlockReason({character = character}) then
			local segment = Vector3.new(current.X-previous.X,0,current.Z-previous.Z)
			local offset = Vector3.new(destination.X-previous.X,0,destination.Z-previous.Z)
			if segment.Magnitude > 0.01 then
				local projection = offset:Dot(segment)/segment:Dot(segment)
				if projection > 0 and projection < 1 and (offset-segment*projection).Magnitude <= 3 then
					stopMovement(true)
					nextCommand = 0
					log("ACTIVITY_OVERSHOOT_BRAKE", "Activite=%s Distance=%.2f : depassement freine", autoActivity, distance)
				end
			end
			if distance < 100 or now >= nextCommand then
				move(destination, {Radius = 3})
				nextCommand = now + CONFIG.MoveRefresh
			end
		end
		previous = current
		RunService.Heartbeat:Wait()
	end
end

-- Serialize treadmill requests, including late replies after a timeout.
local function treadmillRequest(remote, token)
	if treadmillPending then return false, "requete tapis en cours" end
	treadmillPending = true
	local done, accepted, reason = false, false, nil
	task.spawn(function()
		local ok, result, detail = pcall(function() return remote:InvokeServer() end)
		accepted, reason = ok and result == true, ok and detail or result
		done, treadmillPending = true, false
		if accepted and remote == TreadmillRemotes.AskWearStill and (destroyed or not autoEnabled or queuePaused) then
			task.spawn(function() pcall(function() TreadmillRemotes.AskDoff:InvokeServer() end) end)
		end
	end)
	local deadline = os.clock() + CONFIG.RequestTimeout
	while not done and not destroyed and generation == token and os.clock() < deadline do task.wait(0.05) end
	if not done then return false, "reponse tapis en attente" end
	return accepted, reason
end


local function leaveTreadmill(token)
	if not treadmillAssigned and autoActivity ~= "TREADMILL" and autoActivity ~= "TO_TREADMILL" then return true end
	autoActivity = "LEAVING_TREADMILL"
	setStatus("Sortie du tapis puis trajet vers StartArea...")
	local _, humanoid = getCharacterParts()
	if treadmillAssigned then
		local ok, reason = treadmillRequest(TreadmillRemotes.AskDoff, token)
		if not ok then return false, tostring(reason) end
		local deadline = os.clock() + 5
		while treadmillAssigned and autoEnabled and generation == token and os.clock() < deadline do task.wait(0.05) end
		if treadmillAssigned then return false, "sortie du tapis non confirmee" end
	end
	if humanoid then humanoid.Jump = true end
	autoActivity = "FARM"
	safeHome = getStartAreaDestination()
	log("TREADMILL_EXIT_READY", "Sortie confirmee : MoveTo direct vers le centre de StartArea")
	return true
end


function FusionModules.Helpers.MoveForUpgrade(kind,canContinue)
 local character,_,root=getCharacterParts();local token=generation
 if not root or not canContinue()then return false,"Upgrade interrompue"end
 local plot=PlotState and PlotState.ResolvePlot();local folder=plot and plot.PlotFolder
 local model=folder and folder:FindFirstChild(kind=="plot"and"PlotUpgrade"or"TreadmillUpgrade")
 local sign=model and model:FindFirstChild("Sign")
 if not sign or not sign:IsA("BasePart")then return false,"Panneau upgrade du plot introuvable"end
 local exited,reason=leaveTreadmill(token);if not exited or not canContinue()then return false,reason or"Priorite au vol"end
 if shared.__AutoSAEMovementLock then return false,"Deplacement deja en cours"end
 local lock={Owner="AdminUpgrade",Character=character,Generation=token};shared.__AutoSAEMovementLock=lock
 FusionModules.UpgradeMoveValid=canContinue;autoActivity="TO_UPGRADE"
 local ok,reached,detail=pcall(function()
  if(root.Position-sign.Position).Magnitude>7 then
   local offset=Vector3.new(root.Position.X-sign.Position.X,0,root.Position.Z-sign.Position.Z)
   local direction=offset.Magnitude>.01 and offset.Unit or Vector3.new(1,0,0)
   local point=Vector3.new(sign.Position.X,root.Position.Y,sign.Position.Z)+direction*2
   local arrived,why=moveActivity(point,token,true);if not arrived then return false,why end
  end
  local latest=PlotState.ResolvePlot()
  if not activityValid(token,character)or not canContinue()or not latest or latest.PlotFolder~=folder or not sign.Parent then return false,"Plot ou action modifie"end
  if(root.Position-sign.Position).Magnitude>7 then return false,"Distance du panneau non confirmee"end
  return true
 end)
 if shared.__AutoSAEMovementLock==lock then stopMovement(true);shared.__AutoSAEMovementLock=nil end
 FusionModules.UpgradeMoveValid=nil;autoActivity="IDLE"
 if not ok then return false,tostring(reached)end
 return reached,detail
end

-- World eggs always take precedence over optional inventory maintenance.
FusionModules.SpawnPriorityUntil=0
function FusionModules.YieldToSpawnedEggs()
 if destroyed or not ready or not automaticMode or not autoEnabled then return false end
 if FusionModules.Arrival.Waiting()then wallMaintenancePending=true;return true end
 if os.clock()<FusionModules.SpawnPriorityUntil then
  wallMaintenancePending=true
  return true
 end
 syncQueue()
 local candidate=selectBest()
 if candidate then
  wallMaintenancePending=true
  return true
 end
 return false
end

local function hatchReadyEggsOnWallClose(token)
 if not FusionModules.Options.AutoOpen then return 0 end
	if hatchInProgress or not PlacedEggRenderer or not EggGrowthPolicy then return end
	local ok, eggs = pcall(EggState.ReadOwnerEggs, player.UserId)
	if not ok or type(eggs) ~= "table" then log("HATCH_SCAN", "Lecture des oeufs indisponible"); return end
	local readyUids = {}
	local opened = 0
	for uid, record in pairs(eggs) do
		if type(uid) == "string" and type(record) == "table" and record.Placement ~= nil then
			local valid, _, grown = pcall(FusionModules.Helpers.PlotEggCountdown, record)
			local rate = getRatePerSecond(record)
			if valid and grown and rate and rate >= FusionModules.Options.AutoOpenMin and rate <= FusionModules.Options.AutoOpenMax then table.insert(readyUids, uid) end
		end
	end
	table.sort(readyUids)
	for _, uid in ipairs(readyUids) do
		if not FusionModules.Options.AutoOpen or destroyed or not autoEnabled or generation ~= token or not automaticMode or queuePaused or FusionModules.YieldToSpawnedEggs() then break end
		local readOK, latest = pcall(EggState.ReadOwnedEgg, player.UserId, uid)
		local readyOK, grown = false, false
		if readOK and type(latest) == "table" and latest.Placement ~= nil then
			local seconds;readyOK, seconds, grown = pcall(FusionModules.Helpers.PlotEggCountdown, latest)
		end
		local rate = readOK and type(latest) == "table" and getRatePerSecond(latest)
  local holdForMutation=false
  if FusionModules.Options.AutoMutations then
   local runtime=FusionModules.AdminRuntime
   holdForMutation=not runtime or not runtime.Initialized or runtime.ShouldHoldEgg(uid)
  end
		if not holdForMutation and readyOK and grown and rate and rate >= FusionModules.Options.AutoOpenMin and rate <= FusionModules.Options.AutoOpenMax then
			hatchInProgress = true
			setStatus("Ouverture des oeufs prets...")
			local activated, accepted, reason = pcall(PlacedEggRenderer.ActivateLocalEgg, uid)
			hatchInProgress = false
			if activated and accepted == true then opened += 1 end
			log("WALL_HATCH", "Ouverture de %s UID=%s Accepte=%s Raison=%s", FusionModules.Helpers.DescribeEgg(latest), uid, tostring(activated and accepted == true), tostring(activated and reason or accepted))
		end
	end
	return opened
end

function FusionModules.Helpers.PlotEggCountdown(record)
 if type(record)~="table" or record.Placement==nil or not EggRecords or not ServerClock then return nil,false end
 local ok,seconds,grown=pcall(function()
  -- Use the live owner record, like GrowingEggListController (Save.Decode lacks runtime growth fields).
  local current=record
  if type(record.Uid)=="string" then
   local readOK,latest=pcall(EggState.ReadOwnedEgg,player.UserId,record.Uid)
   if readOK and type(latest)=="table" and latest.Placement~=nil then current=latest end
  end
  if current.Placement.ReadyAt~=nil then return 0,true end
  local now=ServerClock.Now()
  local multiplier=current.GrowthSpeedMultiplier
  local credit=EggRecords.CurrentNightCredit(current,now,multiplier)
  if EggRecords.GrowthAlpha(current,now,multiplier,credit,player)>=1 then return 0,true end
  return EggRecords.GrowthSecondsRemaining(current,now,multiplier,credit,player),false
 end)
 if not ok or type(seconds)~="number" or seconds~=seconds or seconds==math.huge or seconds==-math.huge then return nil,false end
 return math.max(0,math.ceil(seconds)),grown==true
end
function FusionModules.Helpers.PlotEggListTime(record)
 if type(record)~="table" or type(record.Uid)~="string" then return nil,false end
 local pg=player:FindFirstChildOfClass("PlayerGui")
 local gui=pg and pg:FindFirstChild("GrowingEggs")
 local frame=gui and gui:FindFirstChild("Frame")
 local list=frame and frame:FindFirstChild("ScrollingFrame")
 local row=list and list:FindFirstChild(record.Uid)
 local spacer=row and row:FindFirstChild("Spacer")
 if not spacer then return nil,false end
 local button=spacer:FindFirstChild("Open")
 if button and button.Visible and button.Active then return 0,true end
 local progress=spacer:FindFirstChild("Progress")
 local label=progress and progress:FindFirstChild("TextLabel")
 if not label then return nil,false end
 local text=string.lower(label.Text)
 if string.find(text,"ready",1,true) or string.find(text,"prêt",1,true) or string.find(text,"pret",1,true) then return 0,true end
 local h=tonumber(string.match(text,"(%d+)%s*h"))
 local m=tonumber(string.match(text,"(%d+)%s*m"))
 local sec=tonumber(string.match(text,"(%d+)%s*s"))
 if h or m or sec then return (h or 0)*3600+(m or 0)*60+(sec or 0),false end
 return nil,false
end
function FusionModules.Helpers.PlotEggTimeText(record)
 local seconds,grown=FusionModules.Helpers.PlotEggListTime(record)
 if seconds==nil then seconds,grown=FusionModules.Helpers.PlotEggCountdown(record)end
 if grown then return "Prêt",true end
 if not seconds then return "—",false end
 local minutes=math.ceil(seconds/60)
 if minutes<1 then return "<1m",false end
 if seconds<60 then return "<1m",false end
 if minutes>=60 then return string.format("%dh%02dm",math.floor(minutes/60),minutes%60),false end
 return tostring(minutes).."m",false
end
function FusionModules.Helpers.OpenSelectedPlotEggs(selection)
 if hatchInProgress or inventoryPlacementBusy or placementRequest or FusionModules.Pending() or currentCycle or serverHopPending then
  setStatus("Operation deja en cours");return
 end
 if not ready or destroyed or not PlacedEggRenderer or not EggGrowthPolicy then return end
 local ids={}
 for uid,selected in pairs(selection)do if selected then table.insert(ids,uid)end end
 if #ids==0 then setStatus("Selectionne les oeufs du Plot a ouvrir.");return end
 local eggs=inventoryEggRecords()
 table.sort(ids,function(a,b)
  local ar,br=getRatePerSecond(eggs[a])or 0,getRatePerSecond(eggs[b])or 0
  if ar~=br then return ar>br end
  return a<b
 end)
 hatchInProgress=true
 if renderControls then renderControls()end
 local opened,waiting,failed=0,0,0
 local ok,err=xpcall(function()
  for _,uid in ipairs(ids)do
   if destroyed then break end
   local readOK,record=pcall(EggState.ReadOwnedEgg,player.UserId,uid)
   if readOK and type(record)=="table" and record.Placement~=nil then
    local _,grown=FusionModules.Helpers.PlotEggCountdown(record)
    if grown then
     local activated,accepted,reason=pcall(PlacedEggRenderer.ActivateLocalEgg,uid)
     if activated and accepted==true then opened+=1;selection[uid]=nil else failed+=1 end
     log("MANUAL_HATCH","Ouverture manuelle de %s UID=%s Accepte=%s Raison=%s",FusionModules.Helpers.DescribeEgg(record),uid,tostring(activated and accepted==true),tostring(activated and reason or accepted))
     task.wait()
    else waiting+=1 end
   else selection[uid]=nil;failed+=1 end
  end
 end,debug.traceback)
 hatchInProgress=false
 if not ok then log("MANUAL_HATCH_ERROR","%s",tostring(err));failed+=1 end
 setStatus(string.format("Ouverture : %d demande(s) acceptee(s), %d en croissance, %d indisponible(s).",opened,waiting,failed))
 if refreshEggInterface then refreshEggInterface()end
end


-- Egg capacity is independent of the equipped-animal limit.
local function plotEggCapacity(eggs)
	local limit = GameplayBalance and GameplayBalance.EggInventory and GameplayBalance.EggInventory.MAX_PLACED_EGGS
	if type(limit) ~= "number" or limit ~= limit or limit < 0 or limit == math.huge then return nil, 0 end
	local count = 0
	for _, egg in pairs(eggs) do
		if egg.InventoryPlaced or egg.Placement ~= nil then count += 1 end
	end
	return math.max(0, math.floor(limit)-count), count
end

-- Index state is read again for every candidate and before each request.
function FusionModules.Helpers.MissingFromIndex(egg)
 if not FusionModules.Options.AutoIndex then return false end
 local ok,profile=pcall(Save.Peek)
 local category=egg and egg.AssetCategory
 if not ok or type(profile)~="table"or type(profile.Index)~="table"or type(category)~="string"then return nil end
 return profile.Index[category]~=true
end
function FusionModules.Helpers.CanPlaceInventoryEgg(egg)
 return FusionModules.Helpers.MissingFromIndex(egg)==true or FusionModules.Helpers.InIncomeRange("AutoPlace",getRatePerSecond(egg))
end

function FusionModules.Helpers.inventoryPlacementOrder(eggs, selection)
	local ids = {}
	for uid, egg in pairs(eggs) do
		local rate=getRatePerSecond(egg)
		if not egg.InventoryPlaced and egg.Placement == nil
			and FusionModules.Helpers.CanPlaceInventoryEgg(egg) and (not selection or selection[uid]) then
			table.insert(ids, uid)
		end
	end
	table.sort(ids, function(a,b)
		local ar, br = getRatePerSecond(eggs[a]) or 0, getRatePerSecond(eggs[b]) or 0
		if ar ~= br then return ar > br end
		return a < b
	end)
	return ids
end

local function findPlotEggSpot(plot, eggs, reserved)
	local area = plot.PetArea
	local targets = {area}
	PlacedEggRenderer.AppendRaycastTargets(targets, player.UserId)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	params.IgnoreWater = true
	local occupied = {}
	for _, egg in pairs(eggs) do
		if egg.Placement and typeof(egg.Placement.LocalCFrame) == "CFrame" then
			table.insert(occupied, (plot.CenterPoint.CFrame * egg.Placement.LocalCFrame).Position)
		end
	end
	for _, point in ipairs(reserved) do table.insert(occupied, point) end
	local halfX, halfZ = area.Size.X*0.5-2, area.Size.Z*0.5-2
	if halfX < 0 or halfZ < 0 then return nil end
	local points = {}
	for x=-halfX,halfX,2 do
		for z=-halfZ,halfZ,2 do
			local point = area.CFrame:PointToWorldSpace(Vector3.new(x, area.Size.Y*0.5, z))
			local clear = true
			for _, other in ipairs(occupied) do
				if distanceXZ(point,other) < 4 then clear = false; break end
			end
			if clear then table.insert(points,point) end
		end
	end
	local _, _, root = getCharacterParts()
	table.sort(points,function(a,b)
		return root and distanceXZ(a,root.Position)<distanceXZ(b,root.Position) or (not root and a.X<b.X)
	end)
	for index, point in ipairs(points) do
  -- Several real ray directions avoid rejecting the whole floor because large egg art covers a top-down ray.
  for _,offset in ipairs({area.CFrame.UpVector*8,area.CFrame.UpVector*8+area.CFrame.RightVector*12,area.CFrame.UpVector*8-area.CFrame.RightVector*12,area.CFrame.UpVector*8+area.CFrame.LookVector*12,area.CFrame.UpVector*8-area.CFrame.LookVector*12})do
   local hit=Workspace:Raycast(point+offset,-offset*1.02,params)
   if hit and hit.Instance==area then return plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(hit.Position)),hit.Position end
  end
  if index%64==0 then task.wait();if destroyed then return nil end end
	end
	return nil
end

local function placeInventoryEggsImpl(selection, token, opened)
 if token~=nil and not FusionModules.Options.AutoPlace then return 0,"AutoPlace OFF"end
	if FusionModules.Pending() or inventoryPlacementBusy or placementRequest or currentCycle or serverHopPending or hatchInProgress then return 0, "Placement indisponible : action en cours" end
	if not ready or destroyed or not PlotState or not inventoryEggRecords then return 0, "Modules indisponibles" end
	local carry = readCarry()
	if not carry or carry.IsCarrying or (inFlightRequest and not inFlightRequest.done) then return 0, "Transport ou requete en cours" end
	local plot = PlotState.ResolvePlot()
	local _, humanoid, root = getCharacterParts()
	if not plot or not root or not humanoid or humanoid.Health<=0 then return 0, "Plot ou personnage indisponible" end
	if isSafe(root.Position)~=true then return 0, "Rejoins la zone sure pour placer les oeufs" end
	if token == nil and (autoEnabled or treadmillAssigned or not PlotState.ContainsLocalPoint(root.Position)) then
		return 0, "Rejoins ton enclos hors du tapis pour placer la selection"
	end
	local placementGeneration, character = generation, player.Character
	local function valid()
		return (token==nil or FusionModules.Options.AutoPlace)and not destroyed and generation==placementGeneration and player.Character==character
			and not currentCycle and not serverHopPending and humanoid.Health>0
			and (token==nil or (autoEnabled and automaticMode and generation==token and not queuePaused and not stopAfterFlight and not FusionModules.YieldToSpawnedEggs()))
	end
	if not valid() then return 0, "Placement annule" end
	inventoryPlacementBusy = true
	local placed, summary, reserved = 0, "Aucun oeuf a placer", {}
	local ok, failure = xpcall(function()
		local eggs = inventoryEggRecords()
		local ids = FusionModules.Helpers.inventoryPlacementOrder(eggs,selection)
		if #ids==0 then return end
		local free = plotEggCapacity(eggs)
		if free==nil then summary="Limite d'oeufs places indisponible"; return end
		-- Hatching is asynchronous: let its confirmed inventory update release capacity.
		local untilAt = os.clock()+8
		while free==0 and (opened or 0)>0 and valid() and os.clock()<untilAt do
			task.wait(0.1)
			eggs=inventoryEggRecords()
			free=plotEggCapacity(eggs)
			if free==nil then break end
		end
		if not free or free<=0 then summary="Enclos plein : limite des oeufs places atteinte"; return end
		if token~=nil then
			local exited, reason=leaveTreadmill(token)
			if not exited then summary="Sortie tapis : "..tostring(reason); return end
			autoActivity="TO_PLOT"
			local target=plot.PetArea.Position+Vector3.new(0,humanoid.HipHeight+2,0)
			local reached, reason=moveActivity(target,token,false)
			if not reached then summary="Trajet enclos : "..tostring(reason); return end
		end
		for _,uid in ipairs(ids) do
			if not valid() then summary="Placement interrompu"; break end
			local currentPlot=PlotState.ResolvePlot()
			if not currentPlot or currentPlot.PlotFolder~=plot.PlotFolder then summary="Plot modifie"; break end
			eggs=inventoryEggRecords()
			free=plotEggCapacity(eggs)
			if not free or free<=0 then summary="Enclos plein"; break end
			local egg=eggs[uid]
			local rate=egg and getRatePerSecond(egg)
			if egg and not egg.InventoryPlaced and egg.Placement==nil
				and FusionModules.Helpers.CanPlaceInventoryEgg(egg) then
				local localFrame, point=findPlotEggSpot(plot,eggs,reserved)
				if not localFrame then summary="Aucun emplacement libre detecte"; break end
				local request={done=false}
				placementRequest=request
				task.spawn(function()
					request.ok,request.accepted,request.reason=pcall(function()
						local equipped,why=EggState.WearEggTool(uid)
						if equipped~=true then return false,why end
						if not valid() then return false,"Placement annule" end
                        local latest=EggState.ReadOwnedEgg(player.UserId,uid)
                        if not latest or latest.Placement~=nil or not FusionModules.Helpers.CanPlaceInventoryEgg(latest)then
                         return false,"Oeuf hors plage ou indisponible"
                        end
						return EggState.PlantEgg(uid,localFrame)
					end)
					request.done=true
					if placementRequest==request then placementRequest=nil end
				end)
				local deadline=os.clock()+CONFIG.RequestTimeout
				while not request.done and valid() and os.clock()<deadline do task.wait(0.05) end
				if not request.done then summary="Placement en attente du serveur : aucun nouvel envoi"; break end
				if not request.ok or request.accepted~=true then
					summary="Placement refuse : "..tostring(request.ok and request.reason or request.accepted)
					log("PLOT_PLACE","Placement de %s UID=%s %s",FusionModules.Helpers.DescribeEgg(egg),uid,summary)
					break
				end
				table.insert(reserved,point)
				local confirmed=false
				deadline=os.clock()+3
				repeat
					local latest=EggState.ReadOwnedEgg(player.UserId,uid)
					confirmed=latest~=nil and latest.Placement~=nil
					if confirmed or not valid() or os.clock()>=deadline then break end
					task.wait(0.05)
				until false
				log("PLOT_PLACE","Placement de %s UID=%s Accepte=true Confirme=%s",FusionModules.Helpers.DescribeEgg(egg),uid,tostring(confirmed))
				if not confirmed then summary="Placement accepte : confirmation inventaire en attente"; break end
				placed+=1
				if selection then selection[uid]=nil end
				PlacedEggRenderer.Refresh()
				summary=tostring(placed).." oeuf(s) place(s)"
			end
		end
	end,debug.traceback)
	inventoryPlacementBusy=false
	if not ok then summary="Placement : "..tostring(failure); log("ERROR","%s",summary) end
	if not destroyed then
		setStatus(summary)
		if refreshEggInterface then refreshEggInterface() end
	end
	return placed,summary
end

local function placeInventoryEggs(...)
 local placed,reason=placeInventoryEggsImpl(...)
 FusionModules.PlacementStatus=tostring(reason or"Placement termine")
 return placed,reason
end


function FusionModules.Helpers.inventoryEggsBelowMinimum(eggs)
	local ids={}
	for uid,egg in pairs(eggs) do
		local rate=getRatePerSecond(egg)
		if not egg.InventoryPlaced and egg.Placement==nil and type(rate)=="number"
			and FusionModules.Helpers.MissingFromIndex(egg)==false
			and rate==rate and rate>=FusionModules.Options.AutoSellMin and rate<=FusionModules.Options.AutoSellMax then
			table.insert(ids,uid)
		end
	end
	table.sort(ids)
	return ids
end

FusionModules.SalesPending=shared.__SEAInventorySalesPending or{}
shared.__SEAInventorySalesPending=FusionModules.SalesPending
local function sellInventoryEggsBelowMinimum(token)
 if not FusionModules.Options.AutoSell then return end
	if FusionModules.Pending() or not EggSaleRemote or inventoryPlacementBusy or placementRequest or currentCycle
		or destroyed or not automaticMode or not autoEnabled or generation~=token
		or queuePaused or stopAfterFlight then return end
	local _,_,root=getCharacterParts()
	if not root or isSafe(root.Position)~=true then return end
	local ids=FusionModules.Helpers.inventoryEggsBelowMinimum(inventoryEggRecords())
 local currentEggs=inventoryEggRecords()
 for uid in pairs(FusionModules.SalesPending)do if not currentEggs[uid]then FusionModules.SalesPending[uid]=nil end end
 for index=#ids,1,-1 do if FusionModules.SalesPending[ids[index]]then table.remove(ids,index)end end
	if #ids==0 then return end
	inventoryPlacementBusy=true -- Serialize all inventory actions with placement.
	local ok,failure=pcall(function()
		for offset=1,#ids,512 do
			if not FusionModules.Options.AutoSell or destroyed or not automaticMode or not autoEnabled or generation~=token or queuePaused or stopAfterFlight or FusionModules.YieldToSpawnedEggs() then break end
			local allowed={}
			for _,uid in ipairs(FusionModules.Helpers.inventoryEggsBelowMinimum(inventoryEggRecords())) do allowed[uid]=true end
			local batch={}
			for i=offset,math.min(offset+511,#ids) do
				if allowed[ids[i]] then table.insert(batch,ids[i]) end
			end
			if #batch>0 then
				local saleNames={}
                local snapshot=inventoryEggRecords()
                for _,uid in ipairs(batch)do
                 table.insert(saleNames,FusionModules.Helpers.DescribeEgg(snapshot[uid]or{}).." ("..uid..")")
                 FusionModules.SalesPending[uid]=true
                end
                FusionModules.InventoryNotice="Vente envoyee : "..table.concat(saleNames," | ")
                EggSaleRemote:FireServer({Assets={},Eggs=batch})
                local deadline=os.clock()+3;local removed=false
                repeat
                 removed=true;local latest=inventoryEggRecords()
                 for _,uid in ipairs(batch)do if latest[uid]then removed=false end end
                 if removed or destroyed or os.clock()>=deadline then break end;task.wait(.1)
                until false
                FusionModules.InventoryNotice=(removed and"Vente confirmee (inventaire) : "or"Vente en attente, aucun renvoi : ")..table.concat(saleNames," | ")
                for _,description in ipairs(saleNames)do log("INVENTORY_SELL_REQUEST","Vente envoyee : %s",description)end
				log("INVENTORY_SELL_REQUEST","Oeufs=%d Plage=%s/s - %s/s | confirmation via inventaire",#batch,formatNumber(FusionModules.Options.AutoSellMin),formatNumber(FusionModules.Options.AutoSellMax))
			end
			if offset+512<=#ids then task.wait() end
		end
	end)
	inventoryPlacementBusy=false
	if not ok then log("ERROR","Vente sous seuil : %s",tostring(failure)) end
end


do
local function fusionBackpackGroups(profile, pen)
	local equipped={}
	for _,uid in ipairs(profile.EquippedAssets or {}) do equipped[uid]=true end
	for _,entry in pairs(pen or {}) do
		if type(entry)=="table" and type(entry.UID)=="string" then equipped[entry.UID]=true end
	end
	local groups={}
	for uid,saved in pairs(profile.Inventory or {}) do
		if type(uid)=="string" and type(saved)=="table" and not equipped[uid] then
			local valid,allowed=pcall(FusionModules.Kernel.MayEnterFuse,uid,saved,nil,false,nil)
			if valid and allowed then
				local decoded,item=pcall(FusionModules.Items.Decode,saved)
				local rated,rate=false,nil
				if decoded then rated,rate=pcall(AssetEarnings.RatePerSecond,item) end
				if rated and FusionModules.Helpers.InIncomeRange("AutoFuse",rate) then
					local key=item.Category.."|"..tostring(saved.CreatorTemporary==true)
					groups[key]=groups[key] or {Category=item.Category,Temporary=saved.CreatorTemporary==true,Items={}}
					table.insert(groups[key].Items,{Uid=uid,Item=item,Rate=rate})
				end
			end
		end
	end
	local result={}
	for _,group in pairs(groups) do
		table.sort(group.Items,function(a,b) if a.Rate~=b.Rate then return a.Rate>b.Rate end;return a.Uid<b.Uid end)
		if #group.Items>=3 then table.insert(result,group) end
	end
	table.sort(result,function(a,b)
		if a.Items[1].Rate~=b.Items[1].Rate then return a.Items[1].Rate>b.Items[1].Rate end
		return a.Items[1].Uid<b.Items[1].Uid
	end)
	return result
end

local function fusionProfile()
	local ok,profile=pcall(Save.Peek)
	return ok and type(profile)=="table" and profile or nil
end

local function fusionPen()
	local ok,pen=pcall(AssetRoster.ReadOwnerPen,player.UserId)
	return ok and type(pen)=="table" and pen or nil
end

local function callFusion(remote,...)
	if FusionModules.Request and not FusionModules.Request.done then return false,false,"Requete fusion en attente" end
	local request={done=false}
	local args=table.pack(...)
	FusionModules.Request,shared.__AutoSAEFusionRequest=request,request
	task.spawn(function()
		request.response=table.pack(pcall(function() return remote:InvokeServer(table.unpack(args,1,args.n)) end))
		request.done=true
	end)
	local deadline=os.clock()+CONFIG.RequestTimeout
	while not request.done and os.clock()<deadline do task.wait(0.05) end
	if not request.done then return false,false,"Delai fusion depasse ; attente de la reponse avant toute nouvelle action" end
	return table.unpack(request.response,1,request.response.n)
end

FusionModules.Run = function(token)
 if not FusionModules.Options.AutoFuse then return end
	if FusionModules.Pending() or inventoryPlacementBusy or placementRequest or currentCycle or serverHopPending
		or not FusionModules.Remotes or not FusionModules.Kernel or not FusionModules.Items or not FusionModules.Signals or not FusionModules.Types then return end
	local function valid()
		return FusionModules.Options.AutoFuse and not destroyed and automaticMode and autoEnabled and generation==token and not queuePaused and not stopAfterFlight and not FusionModules.YieldToSpawnedEggs()
	end
	if not valid() then return end
	if not GameplayBalance or GameplayBalance.Fusion.INPUT_COUNT~=3 then return end
	local profile,pen=fusionProfile(),fusionPen()
	if not profile or not pen or profile.FusionLocked or profile.FusionEggReward~=false or next(profile.FusionSlots or {}) then return end
	if #fusionBackpackGroups(profile,pen)==0 then return end
	local world=Workspace:FindFirstChild("World")
	local machines=world and world:FindFirstChild("Machines")
	local model=machines and machines:FindFirstChild("FuseMachine")
	local machine=model and model:FindFirstChild("Machine")
	local character,humanoid,root=getCharacterParts()
	if not machine or not machine:IsA("BasePart") or not root or not humanoid or isSafe(root.Position)~=true then return end
	local carry=readCarry()
	if not carry or carry.IsCarrying or (inFlightRequest and not inFlightRequest.done) then return end
	FusionModules.Busy=true
	local loaded,committed={},false
	local ok,failure=xpcall(function()
		local exited,why=leaveTreadmill(token)
		if not exited then error("Sortie tapis : "..tostring(why)) end
		autoActivity="TO_FUSION"
		setStatus("Trajet vers la machine de fusion...")
		local target=machine.Position+machine.CFrame.LookVector*7
		local reached,why=moveActivity(Vector3.new(target.X,root.Position.Y,target.Z),token,true)
		if not reached then error("Trajet fusion : "..tostring(why)) end
		autoActivity="FUSION"
		while valid() and player.Character==character do
			profile,pen=fusionProfile(),fusionPen()
			if not profile or not pen or profile.FusionLocked or profile.FusionEggReward~=false or next(profile.FusionSlots or {}) then break end
			local count=0
			for _ in pairs(profile.EggInventory or {}) do count+=1 end
			local eggTypes=require(ReplicatedStorage.Shared.Types.Eggs)
			if type(eggTypes.MAX_INVENTORY)~="number" or count>=eggTypes.MAX_INVENTORY then
				log("FUSION","Inventaire d'oeufs plein : fusion differee")
				break
			end
			local groups=fusionBackpackGroups(profile,pen)
			local group=groups[1]
			if not group then break end
			-- Capture inventory before committing; only a new awarded egg confirms success.
			local eggsBefore={}
			for uid in pairs(profile.EggInventory or {}) do eggsBefore[uid]=true end
			local runtimeItems={}
			for i=1,3 do runtimeItems[i]=group.Items[i].Item end
			local priced,price=pcall(FusionModules.Kernel.PriceFor,runtimeItems)
			if not priced then error("Prix fusion indisponible : "..tostring(price)) end
			log("FUSION","Fusion en cours : %s | %s | %s | Plage=%s/s - %s/s",
                FusionModules.Helpers.DescribeAnimal(group.Items[1].Item),
                FusionModules.Helpers.DescribeAnimal(group.Items[2].Item),
                FusionModules.Helpers.DescribeAnimal(group.Items[3].Item),
                formatNumber(FusionModules.Options.AutoFuseMin),formatNumber(FusionModules.Options.AutoFuseMax))
			loaded,committed={},false
			for i=1,3 do
				if not valid() then return end
				local fresh,presentPen=fusionProfile(),fusionPen()
				if not fresh or not presentPen then error("Inventaire fusion indisponible") end
				local uid=group.Items[i].Uid
				local stillEligible=false
				for _,candidateGroup in ipairs(fusionBackpackGroups(fresh,presentPen)) do
					for _,item in ipairs(candidateGroup.Items) do if item.Uid==uid then stillEligible=true end end
				end
				-- After loading the first pet, fewer than three remain: validate the individual directly.
				if not stillEligible then
					local equipped={}
					for _,id in ipairs(fresh.EquippedAssets or {}) do equipped[id]=true end
					for _,entry in pairs(presentPen) do if type(entry)=="table" and type(entry.UID)=="string" then equipped[entry.UID]=true end end
					local saved=fresh.Inventory and fresh.Inventory[uid]
					local verified,allowed=false,false
					if saved and not equipped[uid] then verified,allowed=pcall(FusionModules.Kernel.MayEnterFuse,uid,saved,group.Category,false,group.Temporary) end
					stillEligible=verified and allowed==true
                    if stillEligible then
                     local decoded,item=pcall(FusionModules.Items.Decode,saved)
                     local rated,rate=false,nil
                     if decoded then rated,rate=pcall(AssetEarnings.RatePerSecond,item)end
                     stillEligible=rated and FusionModules.Helpers.InIncomeRange("AutoFuse",rate)
                    end
				end
				if not stillEligible then error("Animal devenu indisponible : "..uid) end
				local replied,accepted,reason=callFusion(FusionModules.Remotes.LoadPet,uid,false)
				if not replied or accepted~=true then error("LoadPet : "..tostring(reason or accepted)) end
				table.insert(loaded,uid)
				local deadline=os.clock()+3
				repeat
					local latest=fusionProfile()
					if latest and table.find(latest.FusionSlots or {},uid) then break end
					if os.clock()>=deadline then error("Chargement fusion non confirme") end
					task.wait(0.05)
				until false
			end
			if not valid() then return end
			local latest=fusionProfile()
			if not latest or #(latest.FusionSlots or {})~=3 then error("Les trois animaux ne sont pas confirmes") end
			for _,uid in ipairs(latest.FusionSlots) do if not table.find(loaded,uid) then error("Selection de fusion modifiee") end end
            for _,uid in ipairs(loaded)do
             local saved=latest.Inventory and latest.Inventory[uid]
             local decoded,item=pcall(FusionModules.Items.Decode,saved)
             local rated,rate=false,nil
             if decoded then rated,rate=pcall(AssetEarnings.RatePerSecond,item)end
             if not rated or not FusionModules.Helpers.InIncomeRange("AutoFuse",rate)then error("Animal hors plage de revenu : "..uid)end
            end
			local replied,accepted,reason,reward=callFusion(FusionModules.Remotes.BeginFuse)
			if not replied or accepted~=true then error("BeginFuse : "..tostring(reason or accepted)) end
			committed=true
			local validReward=FusionModules.Types.FuseResult(reward)
			if not validReward then error("Resultat fusion invalide : ne pas relancer") end
			-- The game's controller plays its animation and calls FinishReveal exactly once.
			FusionModules.Signals.FuseStarted:Fire(reward)
			local deadline=os.clock()+20
			local awarded
			repeat
                FusionModules.AcknowledgeReward(reward)
				latest=fusionProfile()
				if latest and latest.FusionEggReward==false and not latest.FusionLocked then
					local consumed=true
					for _,uid in ipairs(loaded) do if latest.Inventory and latest.Inventory[uid] then consumed=false end end
					if consumed then
						for uid,egg in pairs(latest.EggInventory or {}) do
							if not eggsBefore[uid] and egg.AssetCategory==reward.AssetCategory then awarded=uid;break end
						end
					end
				end
				if awarded then break end
				if os.clock()>=deadline or destroyed then error("Attribution fusion non confirmee : aucune relance automatique") end
				task.wait(0.1)
			until false
			log("FUSION","Fusion reussie : %s UID=%s | traitement au prochain passage",FusionModules.Helpers.DescribeEgg(latest.EggInventory[awarded]),awarded)
			loaded,committed={},false
			-- Recompute before another group: equipped pets and available UIDs may have changed.
			task.wait()
		end
	end,debug.traceback)
	-- Return only pets loaded by this operation, and only before a committed fusion.
	if not committed and not (FusionModules.Request and not FusionModules.Request.done) then
		for _,uid in ipairs(loaded) do
			local profile=fusionProfile()
			if profile and table.find(profile.FusionSlots or {},uid) then
				local replied,accepted,reason=callFusion(FusionModules.Remotes.EjectPet,uid)
				log("FUSION","Restitution %s UID=%s Accepte=%s Raison=%s",FusionModules.Helpers.DescribeSavedAnimal(profile.Inventory and profile.Inventory[uid]),uid,tostring(replied and accepted==true),tostring(reason))
				if not replied then break end
			end
		end
	end
	FusionModules.Busy=false
	if not ok then
		log("FUSION","Interrompu : %s",tostring(failure))
		if committed or (FusionModules.Request and not FusionModules.Request.done) then
			stopAutomation("Fusion en attente de confirmation : voir le log")
		end
	end
end

end -- fusion helpers


function FusionModules.AcknowledgeReward(reward)
 local config=Assets and Assets.Directory and Assets.Directory[reward.AssetCategory]
 if not config or not config.Egg or type(config.Egg.DisplayName)~="string" then return false end
 local gui=require(ReplicatedStorage.Client.GUI).Message()
 if not gui or not gui.Enabled then return false end
 local frame=gui:FindFirstChild("Frame")
 local contents=frame and frame:FindFirstChild("Contents")
 local acknowledge=contents and contents:FindFirstChild("Acknowledge")
 local accept=contents and contents:FindFirstChild("Accept")
 if not acknowledge or not acknowledge.Visible or not accept or accept.Visible then return false end
 local expected="You fused "..config.Egg.DisplayName
 local matched=false
 for _,name in ipairs({"IllustratedBody","Body"}) do
  local label=contents:FindFirstChild(name)
  if label and label.Visible and label.Text:gsub("<[^>]->","")==expected then matched=true end
 end
 if not matched then return false end
 -- Message.awaitVerdict listens to Enabled=false and resumes the official controller.
 gui.Enabled=false
 -- The confirmed fusion result already logs the awarded egg and its metrics.
 return true
end


FusionModules.EquipBestState={Busy=false,RetryAt=0}
function FusionModules.Helpers.EquipBestForInventory()
 local state=FusionModules.EquipBestState
 if state.Busy or not HaulRemotes or not Save or os.clock()<state.RetryAt then return false end
 local okProfile,profile=pcall(Save.Peek);if not okProfile or type(profile)~="table"then return false end
 local entries={};for uid,item in pairs(profile.Inventory or{})do table.insert(entries,tostring(uid)..":"..HttpService:JSONEncode(item))end;table.sort(entries)
 local signature=table.concat(entries,"|");if signature==state.Succeeded then return true end
 state.RetryAt=os.clock()+10;state.Busy=true
 setStatus("Inventaire modifie : Equip Best...")
 local ok,accepted,reason=pcall(function()return HaulRemotes.WearBest:InvokeServer()end)
 state.Busy=false
 if ok and accepted==true then state.Succeeded=signature end
 log("WALL_EQUIP_BEST","Accepte=%s Raison=%s",tostring(ok and accepted==true),tostring(ok and reason or accepted))
 return ok and accepted==true
end

local function serviceWallMaintenance(token)
	if destroyed or not automaticMode or not autoEnabled or generation ~= token or currentCycle or FusionModules.Pending() or inventoryPlacementBusy or placementRequest then return end
 if FusionModules.AdminRuntime and FusionModules.AdminRuntime.ManualPending then return end
    if FusionModules.YieldToSpawnedEggs() then return end
	if not wallMaintenancePending and os.clock()-lastMaintenanceAt < 2 then return end
	local _, _, root = getCharacterParts()
	if not root or isSafe(root.Position) ~= true then return end
	wallMaintenancePending = false
	lastMaintenanceAt = os.clock()
	if FusionModules.AdminRuntime then
  local runtime=FusionModules.AdminRuntime
  if runtime.ProgressPending and runtime.ProgressPending()then return end
  if runtime.ProgressNext and runtime.ProgressNext()then return end
 end
 -- Fill available spots before mutation retries can defer the rest of maintenance.
	placeInventoryEggs(nil,token,0)
	if destroyed or not autoEnabled or generation~=token or queuePaused or placementRequest or FusionModules.YieldToSpawnedEggs() then return end
	if FusionModules.Options.AutoMutations then
	 if not FusionModules.AdminRuntime or not FusionModules.AdminRuntime.Initialized then return end
	 local ok,pending=pcall(FusionModules.AdminRuntime.MutateNext)
	 if not ok then warn("[SEA Admin] AutoMutations : "..tostring(pending));return end
	 -- A mutation retry must not starve sales/fusion or unrelated ready eggs.
	end
	local opened = hatchReadyEggsOnWallClose(token)
	if destroyed or not autoEnabled or generation ~= token or queuePaused or FusionModules.YieldToSpawnedEggs() then return end
	sellInventoryEggsBelowMinimum(token)
	if destroyed or not autoEnabled or generation~=token or queuePaused or FusionModules.YieldToSpawnedEggs() then return end
 if FusionModules.AdminRuntime and FusionModules.AdminRuntime.Initialized then FusionModules.AdminRuntime.SellAnimals()end
 if destroyed or not autoEnabled or generation~=token or queuePaused or FusionModules.YieldToSpawnedEggs()then return end
	placeInventoryEggs(nil,token,opened)
	if destroyed or not autoEnabled or generation ~= token or queuePaused or placementRequest or FusionModules.YieldToSpawnedEggs() then return end
 if FusionModules.Options.AutoEquipBest then FusionModules.Helpers.EquipBestForInventory()end
	if FusionModules.Ready
        and not destroyed and autoEnabled and generation==token and not queuePaused
        and not FusionModules.YieldToSpawnedEggs() then
        local fusionOK=FusionModules.Protect("FUSION_ACTION",FusionModules.Run,token)
        if not fusionOK then
            if FusionModules.Pending() then stopAutomation("Fusion interrompue : verification requise dans le log")
            else FusionModules.Ready=false end
        end
    end
end


-- Butterfly waiting uses the game's event clock and native net tool.
FusionModules.Butterflies = {Until=0, Revision=0, RetryAt=0}
function FusionModules.Butterflies.Available()
 if not FusionModules.Options.AutoPapillon then return false end
 local b=FusionModules.Butterflies
 if Workspace:GetServerTimeNow()>=b.Until or os.clock()<b.RetryAt then return false end
 local world=Workspace:FindFirstChild("World")
 local areas=world and world:FindFirstChild("Areas")
 local area=areas and areas:FindFirstChild("ButterflyBloom")
 local bounds=area and area:FindFirstChild("Bounds")
 if not bounds or not bounds:IsA("BasePart") then return false end
 for _,container in pairs({player.Character,player:FindFirstChildOfClass("Backpack")}) do
  if container then for _,tool in ipairs(container:GetChildren()) do
   if tool:IsA("Tool") and tool:GetAttribute("ButterflyNet")==true then return bounds,tool end
  end end
 end
 return false
end
function FusionModules.Butterflies.Idle(token)
 local b=FusionModules.Butterflies
 local bounds,tool=b.Available()
 if not bounds then return false end
 local revision=b.Revision
 local exited,reason=leaveTreadmill(token)
 if not exited then log("BUTTERFLY","Sortie tapis refusee : %s",tostring(reason)); b.RetryAt=os.clock()+5; return false end
 local character,humanoid,root=getCharacterParts()
 if not character or not humanoid or not root then return false end
 if tool.Parent~=character then humanoid:EquipTool(tool) end
 local departure,departureReason=getStartAreaDestination()
 if not departure then
  log("BUTTERFLY","Point de depart indisponible : %s",tostring(departureReason))
  b.RetryAt=os.clock()+5
  return false
 end
 autoActivity="TO_BUTTERFLIES_START"
 setStatus("Papillons : trajet vers le centre de StartArea...")
 local nextDestination=Vector3.new(bounds.Position.X,departure.Y,bounds.Position.Z)
 local reached,departureDetail=measureAction("PAPILLONS_STARTAREA",moveActivity,departure,token,false,nextDestination)
 if not reached then
  log("BUTTERFLY","Trajet StartArea interrompu : %s",tostring(departureDetail))
  b.RetryAt=os.clock()+5
  return true
 end
 if not activityValid(token,character)or not automaticMode or stopAfterFlight then return true end
 autoActivity="TO_BUTTERFLIES"
 setStatus("File vide : trajet vers le centre des papillons...")
 local arrived,detail=moveActivity(Vector3.new(bounds.Position.X,root.Position.Y,bounds.Position.Z),token,false)
 if not arrived then
  log("BUTTERFLY","Trajet interrompu : %s",tostring(detail))
  b.RetryAt=os.clock()+5
  return true
 end
 autoActivity="BUTTERFLIES"
 log("BUTTERFLY","Centre rejoint : filet equipe jusqu'au prochain cycle")
 log("ACTION","Collecte des papillons en cours")
 setStatus("Papillons : filet equipe jusqu'au prochain cycle d'oeufs.")
 while FusionModules.Options.AutoPapillon and activityValid(token,character) and automaticMode and not stopAfterFlight
  and b.Revision==revision and Workspace:GetServerTimeNow()<b.Until do
  local present,net=b.Available()
  if not present then break end
  if net.Parent~=character then humanoid:EquipTool(net) end
  task.wait(CONFIG.ScanInterval)
 end
 log("ACTION","Collecte des papillons terminee")
 stopMovement(true)
 autoActivity="IDLE"
 activityRecheckPending=true
 return true
end


-- Recent optional features fail independently and retain their traceback in the log.
function FusionModules.Protect(label,callback,...)
 local args=table.pack(...)
 local result=table.pack(xpcall(function()
  assert(type(callback)=="function",label.." : fonction indisponible")
  return callback(table.unpack(args,1,args.n))
 end,function(err) return debug.traceback(tostring(err),2) end))
 if not result[1] then
  log("ERROR","%s : %s",label,tostring(result[2]))
  warn("[Auto_SAE]["..label.."] "..tostring(result[2]))
 end
 return table.unpack(result,1,result.n)
end

do
 local available=FusionModules.Butterflies.Available
 FusionModules.Butterflies.Available=function()
  local ok,bounds,tool=FusionModules.Protect("BUTTERFLY_DETECTION",available)
  if ok then return bounds,tool end
  FusionModules.Butterflies.RetryAt=os.clock()+10
  return false
 end
 local idle=FusionModules.Butterflies.Idle
 FusionModules.Butterflies.Idle=function(token)
  local ok,result=FusionModules.Protect("BUTTERFLY_ACTION",idle,token)
  if ok then return result end
  FusionModules.Butterflies.RetryAt=os.clock()+10
  pcall(stopMovement,true)
  autoActivity="IDLE"
  return false
 end
end

local function idleOnTreadmill(token)
 if not FusionModules.Options.AutoTreadmill then
  if treadmillAssigned then leaveTreadmill(token)end
  autoActivity="IDLE";setStatus("En attente : AutoTreadmill OFF");task.wait(CONFIG.ScanInterval);return true
 end
	if not PlotState or not TreadmillRemotes then return false, "modules tapis indisponibles" end
	local slot = PlotState.ResolveLocalSlot()
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and slot and plots:FindFirstChild(tostring(slot))
	local bottom = plot and plot:FindFirstChild("TreadmillBottom")
	if not bottom or not bottom:IsA("BasePart") then return false, "tapis de ta parcelle introuvable" end
	autoActivity = "TO_TREADMILL"
	setStatus("File vide : trajet vers le tapis...")
	if not treadmillAssigned then
		local _, humanoid = getCharacterParts()
		local destination = bottom.Position + Vector3.new(0, humanoid.HipHeight + 2, 0)
		local ok, reason = measureAction("ENTREE_TAPIS", moveActivity, destination, token, true)
		if not ok then
			if reason == "nouvel oeuf"or reason=="tapis OFF"then return true end
			return false, reason
		end
		-- The normal controller detects entry with its downward raycast.
		local deadline = os.clock() + 0.35
		while not treadmillAssigned and autoEnabled and generation == token and os.clock() < deadline
			and next(queuedEggs) == nil do task.wait(0.1) end
		if not FusionModules.Options.AutoTreadmill then return true end
		if not treadmillAssigned and automaticMode and next(queuedEggs) == nil then
			local accepted, detail = treadmillRequest(TreadmillRemotes.AskWearStill, token)
			if not accepted and not treadmillAssigned then return false, tostring(detail or "entree tapis refusee") end
			deadline = os.clock() + 5
			while not treadmillAssigned and autoEnabled and generation == token and os.clock() < deadline do task.wait(0.1) end
			if not treadmillAssigned then return false, "entree tapis non confirmee" end
		end
	end
	autoActivity = "TREADMILL"
	if destroyed or not autoEnabled or generation ~= token then return true end
	setStatus("TREADMILL : entrainement, attente d'un oeuf...")
	while autoEnabled and generation == token and automaticMode and not queuePaused
		and FusionModules.Options.AutoTreadmill and next(queuedEggs) == nil and not activityRecheckPending and not FusionModules.Butterflies.Available() and not destroyed do
		serviceWallMaintenance(token)
  if FusionModules.AdminRuntime and FusionModules.AdminRuntime.ProgressTravelling and FusionModules.AdminRuntime.ProgressTravelling()then task.wait(CONFIG.ScanInterval);continue end
		if not treadmillAssigned and autoActivity ~= "TREADMILL" then return true end
		syncQueue()
		task.wait(CONFIG.ScanInterval)
	end
	return true
end

local function requestUserStop(reason)
	if autoEnabled and (currentCycle ~= nil or autoActivity == "FARM") then
		stopAfterFlight = true
        if FusionModules.Reporting then FusionModules.Reporting.MarkSettingsDirty()end
		setStatus("Arret demande : fin du vol puis pause.")
		if renderControls then renderControls() end
		return
	end
	stopAfterFlight = false
	local wasOnTreadmill = treadmillAssigned or autoActivity == "TREADMILL" or autoActivity == "TO_TREADMILL"
	stopAutomation(reason or "AUTO arrete")
	autoActivity = "IDLE"
	if wasOnTreadmill and TreadmillRemotes and not treadmillPending then
		local stopToken = generation
		task.spawn(function() treadmillRequest(TreadmillRemotes.AskDoff, stopToken) end)
	end
end

local function worker(token)
	local directNext = false
	while autoEnabled and generation == token and not destroyed do
        syncQueue()
		if FusionModules.Arrival.Waiting()then
			autoActivity="ARRIVAL_WAIT"
			setStatus("Arrivee : chargement de l'oeuf cible avant le vol...")
			task.wait(CONFIG.ScanInterval)
			continue
		end
		serviceWallMaintenance(token)
  if not FusionModules.Helpers.ShouldRun()and not currentCycle then requestUserStop("Toutes les options sont OFF");return end
		if activityRecheckPending then
			activityRecheckPending = false
			syncQueue()
			local nextMode = next(queuedEggs) ~= nil and "FARM" or "TREADMILL"
			log("RESET_MODE_CHECK", "Reinitialisation/session : mode choisi=%s", nextMode)
		end
		if FusionModules.Pending() then stopAutomation("Fusion serveur en attente : patienter"); return end
		if placementRequest then stopAutomation("Placement serveur en attente : reprise apres sa reponse"); return end
		if inFlightRequest and not inFlightRequest.done then
			stopAutomation("Requete serveur en cours : attendre sa reponse")
			return
		end
		if stopAfterFlight and not currentCycle then
			stopAfterFlight = false
			stopAutomation("Arret apres le vol")
			autoActivity = "IDLE"
			return
		end
		local carry = readCarry()
		if not carry then
			stopAutomation("Etat de transport indisponible")
			return
		end
		syncQueue()
		local selected, rate, recovering
		if carry.IsCarrying and carry.Uid then
			if not queuedEggs[carry.Uid] then
				stopAutomation("Un oeuf hors de la file est deja porte")
				return
			end
			selected = readField(carry.Uid)
			selected = selected or {Uid = carry.Uid, AssetCategory = carry.AssetCategory}
			recovering = true
		else
			selected, rate = selectBest()
		end
		if selected then
			if selected.Uid==FusionModules.Arrival.Uid then FusionModules.Arrival.Clear("Debut du vol de la cible")end
			searchWaitForEgg = false
			serverSearchState = automaticMode and "Oeuf eligible : collecte" or "OFF"
            FusionModules.BatCombat.ApproachUid=not recovering and selected.Uid or nil
			local exited, exitReason = measureAction("SORTIE_TAPIS", leaveTreadmill, token)
			if not exited then stopAutomation("Sortie tapis : " .. tostring(exitReason)); return end
			if not autoEnabled or generation ~= token then return end
			if not recovering and not directNext then
				local destination, destinationReason = getStartAreaDestination()
				if not destination then stopAutomation(destinationReason); return end
				autoActivity = "TO_FARM"
				setStatus("Trajet vers le centre de StartArea...")
				log("START_AREA_MOVETO", "Trajet direct vers %s", FusionModules.Helpers.formatPosition(destination))
				local eggPosition = getRecordPosition(records[selected.Uid] or selected)
				local nextDestination = eggPosition and Vector3.new(eggPosition.X, destination.Y, eggPosition.Z)
				local reached, reason = measureAction("TRAJET_STARTAREA", moveActivity, destination, token, false, nextDestination)
				if not reached then stopAutomation("StartArea : " .. tostring(reason)); return end
			end
			if not autoEnabled or generation ~= token then return end
			autoActivity = "FARM"
			log("FARM_START", "UID=%s : sortie StartArea atteinte, trajet vers l'oeuf", selected.Uid)
			directNext = false
			local success, reason = measureAction("VOL_COMPLET", runCycle, selected, rate, recovering, selectBest)
			if not autoEnabled or generation ~= token then return end
			if success then
				wallMaintenancePending = true
				selectedEggs[selected.Uid] = nil
				queuedEggs[selected.Uid],trackedEggs[selected.Uid] = nil,nil
				if refreshQueueInterface then refreshQueueInterface() end
				if renderControls then renderControls() end
				if automaticMode and not stopAfterFlight then
					serviceWallMaintenance(token)
				end
			end
			if not success then
				if reason == "GAMEPLAY_ENTRY_REQUIRED" then
					stopAutomation("Prise refusee : entre manuellement dans la zone de jeu puis relance la collecte.")
					return
				end
				log("CYCLE_FAILED", "UID=%s Raison=%s", selected.Uid, tostring(reason))
				cooldowns[selected.Uid] = (reason == "TARGET_UNAVAILABLE" or reason == "NEXT_AVAILABLE") and 0 or (os.clock() + CONFIG.FailedTargetCooldown)
				queuedEggs[selected.Uid] = nil
				-- Never continue after ambiguous ownership or an unresolved request.
				if recovering or (inFlightRequest and not inFlightRequest.done) then
					stopAutomation(tostring(reason))
					return
				end
				local after = readCarry()
				local _, _, root = getCharacterParts()
				if not after or after.IsCarrying or not root or (reason ~= "NEXT_AVAILABLE" and isSafe(root.Position) ~= true)
					or string.find(tostring(reason), "attribution", 1, true)
					or string.find(tostring(reason), "recuperation", 1, true) then
					stopAutomation(tostring(reason))
					return
				end
				if reason == "NEXT_AVAILABLE" then
					directNext = true
					log("NEXT_TARGET", "Oeuf disparu : trajet direct vers le prochain oeuf de la file")
				end
			end
		else
			directNext = false
			if automaticMode and FusionModules.Butterflies.Available() then
				FusionModules.Butterflies.Idle(token)
			elseif automaticMode then
				serverSearchState = "OFF"
				local ok, reason = idleOnTreadmill(token)
				if not autoEnabled or generation ~= token then return end
				if not ok then stopAutomation("Tapis : " .. tostring(reason)); return end
			else
				stopAutomation("File terminee", false)
				return
			end
		end
		task.wait() -- Yield one frame, then immediately select the next available egg.
	end
end

startAutomation = function(billions)
	if destroyed or not ready then
		setStatus("Les modules du jeu sont indisponibles", Color3.fromRGB(255, 130, 110))
		return false
	end
	if inFlightRequest and not inFlightRequest.done then
		setStatus("Une requete attend encore le serveur", Color3.fromRGB(255, 190, 100))
		return false
	end
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or humanoid.Health <= 0 then
		setStatus("Personnage indisponible")
		return false
	end
	safeHome = getStartAreaDestination()
	if not safeHome or isSafe(safeHome) ~= true then
		setStatus("File en attente : rejoins la zone sure", Color3.fromRGB(255, 190, 100))
		return false
	end
	if type(billions) ~= "number" or billions ~= billions or math.abs(billions) == math.huge then
		setStatus("Seuil invalide : entre 0.1 et 999 B/s")
		return false
	end
	minimumRatePerSecond = math.clamp(billions, MINIMUM_BILLIONS, MAXIMUM_BILLIONS) * 1e9
	generation += 1
	local token = generation
	autoEnabled = true
    if FusionModules.Reporting then FusionModules.Reporting.MarkSettingsDirty()end
	snapshot(EggState.ReadFieldEggs())
	if renderControls then renderControls() end
	log("START", "Minimum=%s/s SafeHome=%s Session=%d",
		formatNumber(minimumRatePerSecond), FusionModules.Helpers.formatPosition(safeHome), token)
	task.spawn(function()
		local ok, failure = xpcall(function() worker(token) end, debug.traceback)
		if not ok then
			log("ERROR", "%s", tostring(failure))
			if generation == token then stopAutomation("Erreur : voir la console Auto_SAE") end
		end
	end)
	return true
end

wakeQueue = function()
 if automaticMode and queuePaused then
  queuePaused=false;stopAfterFlight=false
  log("QUEUE_RESUME","File remise en lecture automatiquement (mode AUTO)")
  if FusionModules.Reporting then FusionModules.Reporting.MarkSettingsDirty()end
 end
 if os.clock() < (FusionModules.QueueResumeAt or 0) then return end
 if not FusionModules.Helpers.ShouldRun()then return end
 if FusionModules.ManualBusy or FusionModules.MutationBusy or FusionModules.Pending() or inventoryPlacementBusy or placementRequest or serverHopPending or destroyed or not ready or autoEnabled or queuePaused or (not automaticMode and next(queuedEggs) == nil) then return end
	if inFlightRequest and not inFlightRequest.done then return end
	startAutomation(minimumRatePerSecond / 1e9)
end

local function loadModule(path)
	log("MODULE_LOADING", "%s", path)
	local deadline, node = os.clock() + 12, ReplicatedStorage
	for name in string.gmatch(path, "[^%.]+") do
		local child = node:FindFirstChild(name)
		while not child and os.clock() < deadline and not destroyed do
			task.wait(0.1)
			child = node:FindFirstChild(name)
		end
		assert(child, "ReplicatedStorage." .. path .. " introuvable")
		node = child
	end
	local module = require(node)
	log("MODULE_READY", "%s", path)
	return module
end

local function initialize()
	EggState = loadModule("Client.EggState")
	AreaEggCycle = loadModule("Shared.Util.AreaEggCycle")
	ServerClock = loadModule("Shared.Util.ServerClock")
	Assets = loadModule("Data.Assets")
	EggRecords = loadModule("Shared.Util.EggRecords")
	AssetEarnings = loadModule("Shared.Util.AssetEarnings")
	SlotIdentity = loadModule("Shared.Util.AreaEggSlotIdentity")
	GuardGeometry = loadModule("Shared.Util.GuardAreaGeometry")
	Save = loadModule("Shared.Save")
	PlotState = loadModule("Client.PlotState")
	AssetRoster = loadModule("Client.AssetRoster")
	PlacedEggRenderer = loadModule("Shared.Eggs.PlacedEggRenderer")
	EggGrowthPolicy = loadModule("Shared.Eggs.PlacedEggGrowthPresentationPolicy")
	local remotes = loadModule("Shared.Remotes")

 -- Subscribe before fetching so a late snapshot cannot overwrite a newer event.
 do
  FusionModules.Protect("BUTTERFLY_INIT",function()
  local b=FusionModules.Butterflies
  assert(type(remotes.LiveEvents)=="table","LiveEvents indisponible")
  connect(remotes.LiveEvents.Began.OnClientEvent,function(name,duration)
   FusionModules.Protect("BUTTERFLY_BEGAN",function()
   if name=="ButterflyBloom" and type(duration)=="number" then
    b.Revision+=1; b.Until=Workspace:GetServerTimeNow()+math.max(0,duration)
   end
   end)
  end)
  connect(remotes.LiveEvents.Ended.OnClientEvent,function(name)
   FusionModules.Protect("BUTTERFLY_ENDED",function()
    if name=="ButterflyBloom" then b.Revision+=1; b.Until=0 end
   end)
  end)
  local revision=b.Revision
  task.spawn(function()
   local ok,running=FusionModules.Protect("BUTTERFLY_FETCH",function() return remotes.LiveEvents.FetchRunning:InvokeServer() end)
   if not destroyed and ok and type(running)=="table" and b.Revision==revision then
    local expiry=running.ButterflyBloom
    if type(expiry)=="number" then b.Until=expiry end
   end
  end)
  end)
 end

	TreadmillRemotes = remotes.Treadmill
	HaulRemotes = remotes.Haul
	FusionModules.Ready=FusionModules.Protect("FUSION_INIT",function()
	FusionModules.Remotes = remotes.Fusery
	FusionModules.Kernel = loadModule("Shared.Util.FuseKernel")
	FusionModules.Items = loadModule("Shared.Util.AssetItems")
	FusionModules.Signals = loadModule("Client.FuseMachineSignals")
	FusionModules.Types = loadModule("Shared.Types.FuseMachine")
        assert(type(FusionModules.Remotes)=="table","Fusery indisponible")
    end)
	EggSaleRemote = remotes.PetSatchel.SellSelection
	GameplayBalance = loadModule("Shared.Flags.GameplayBalance")
    do
     local ok,gears=pcall(function()return require(ReplicatedStorage.Data.Gears)end)
     if ok and type(gears)=="table"then FusionModules.BatCombat.Directory=gears.Directory
     else log("ERROR","Catalogue des battes indisponible : %s",tostring(gears))end
    end
	local resetWall = loadModule("Client.AreaEggResetWall")
	connect(resetWall.Changed, function(sealed)
		if sealed == true and not destroyed then
            FusionModules.Butterflies.Revision += 1
            FusionModules.Reporting.Reset()
        end
		if sealed == true and not destroyed and automaticMode then
			wallMaintenancePending = true
            FusionModules.SpawnPriorityUntil=os.clock()+15
			serverSearchReadyAt = os.clock()+15
			activityRecheckPending = true
			log("EGG_RESET", "Reevaluation de la file et du tapis apres le vol actif.")
			log("WALL_CLOSED", "Priorite aux oeufs spawnes ; entretien differe tant qu une cible est disponible.")
		end
	end)
	connect(TreadmillRemotes.AssignedBeltShifted.OnClientEvent, function(id)
		treadmillAssigned = id ~= nil
	end)
	if destroyed then return end
	if CONFIG.ObserveRigSync then
		local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
		local remotesModule = sharedFolder and sharedFolder:FindFirstChild("Remotes")
		local ok, bound = pcall(function()
			local remotes = remotesModule and require(remotesModule)
			if type(remotes) ~= "table" or type(remotes.RigSync) ~= "table" then return false end
			local refresh = remotes.RigSync.Refresh
			local signal = refresh and refresh.OnClientEvent
			if not signal or type(signal.Connect) ~= "function" then return false end
			connect(signal, observeRigRefresh)
			return true
		end)
		if ok and bound then
			log("RIG_OBSERVER_READY", "RigSync.Refresh : lecture seule ; protections du jeu conservees")
		else
			log("RIG_OBSERVER_UNAVAILABLE", "Module optionnel absent ou incompatible : IsTrapped/etat Humanoid restent utilises")
		end
	end
	for _, name in ipairs({"CarryFieldEgg", "ReadFieldEgg", "ReadFieldEggs", "ReadCarryState", "ReadOwnedEgg", "ReadOwnerEggs"}) do
		assert(type(EggState[name]) == "function", "EggState." .. name .. " indisponible")
	end
	connect(EggState.FieldRefreshed, snapshot)
	connect(EggState.FieldShifted, function(record)
        ingest(record)
        FusionModules.Reporting.MarkDirty(.75)
    end)
	connect(EggState.FieldGone, function(uid)
		records[uid], loggedVersions[uid] = nil, nil
        FusionModules.Reporting.MarkDirty(.75)
		if trackedEggs[uid] then log("EGG_TRACK","UID=%s Retire du snapshot : suivi physique conserve",uid) end
		log("FIELD_GONE", "UID=%s | ne prouve pas la possession", tostring(uid))
	end)
	connect(EggState.CarryChanged, function(state)
		local ctx = currentCycle
		log("CARRY_CHANGED", "Carrying=%s UID=%s Area=%s SpeedMultiplier=%s",
			tostring(state.IsCarrying), tostring(state.Uid), tostring(state.AreaId), tostring(state.SpeedMultiplier))
		if ctx and state.IsCarrying and state.Uid == ctx.uid then
			ctx.sawCarry, ctx.carryLostAt = true, nil
		elseif ctx and ctx.hadCarry and (ctx.phase == "RETURN" or ctx.phase == "CONFIRM_CLAIM") then
			ctx.carryLostAt = os.clock()
			log("CARRY_RELEASED", "Transport termine | UID cible=%s | verification perte ou attribution", ctx.uid)
		end
	end)
	connect(EggState.FieldClaimed, function(payload)
		local ctx = currentCycle
		log("FIELD_CLAIMED", "Animal=%s Rarity=%s Pos=%s | payload sans UID",
			tostring(payload.AssetCategory), tostring(payload.Rarity), FusionModules.Helpers.formatPosition(payload.Position))
		if ctx and payload.AssetCategory == ctx.record.AssetCategory
			and (ctx.sawCarry or ctx.remoteAccepted) then
			ctx.claimFeedback = true
		end
		-- Final success is still checked against ReadOwnedEgg(localUserId, exactUid).
	end)
	connect(EggState.OwnerRefreshed, function(userId)
  if userId==player.UserId then wallMaintenancePending=true end
		if userId == player.UserId and currentCycle then
			log("OWNER_REFRESHED", "UID=%s Possession=%s", currentCycle.uid, tostring(ownsEgg(currentCycle.uid)))
		end
	end)
	snapshot(EggState.ReadFieldEggs())
	serverSearchReadyAt = os.clock()+15
	wallMaintenancePending = true
	ready = true
    FusionModules.Reporting.Start()
	setStatus("AUTO ON : recherche des oeufs, sinon entrainement au tapis.", Color3.fromRGB(96, 230, 145))
	syncQueue()
	wakeQueue()
	if refreshEggInterface then refreshEggInterface() end
	if refreshBestEggCard then refreshBestEggCard() end
	log("READY", "Build=2.4 | MoveTo renouvele / freinage horizontal / distance 3D <= 8 / %d essais en serie / retour / inventaire / reprise meme UID", CONFIG.MaxCarryAttempts)
end

inventoryEggRecords = function()
	local result = {}
	local ok, profile = pcall(Save.Peek)
	if not ok or type(profile) ~= "table" then return result end
	for uid, saved in pairs(profile.EggInventory or {}) do
		if type(uid) == "string" and type(saved) == "table" then
			local decoded, record = pcall(EggRecords.Decode, saved)
			if decoded and type(record) == "table" then
				record.Uid, record.InventoryOwned = uid, true
				record.InventoryPlaced = record.Placement ~= nil
				result[uid] = record
			end
		end
	end
 local ownerOK,live=pcall(EggState.ReadOwnerEggs,player.UserId)
 if ownerOK and type(live)=="table"then for uid,record in pairs(live)do
  if type(uid)=="string"and type(record)=="table"then local copy=table.clone(record);copy.Uid=uid;copy.InventoryOwned=true;copy.InventoryPlaced=copy.Placement~=nil;result[uid]=copy end
 end end
	return result
end

function FusionModules.Helpers.filterPublicServers(data, currentJobId)
	syncVisitedServerCycle(false)
	local result, seen = {}, {}
	for _, server in ipairs(type(data) == "table" and data or {}) do
		if type(server) == "table" and type(server.id) == "string" and server.id ~= currentJobId and not visitedServers[server.id] and not seen[server.id]
			and type(server.playing) == "number" and type(server.maxPlayers) == "number"
			and server.playing >= 0 and server.playing < server.maxPlayers then
			seen[server.id] = true
			table.insert(result, server)
		end
	end
	table.sort(result, function(a,b)
		if a.playing ~= b.playing then return a.playing < b.playing end
		return a.id < b.id
	end)
	return result
end

function FusionModules.Helpers.fetchPublicServers()
	local all, cursor = {}, nil
	for page = 1, 3 do
		if destroyed then return {} end
		local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
		if cursor then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
		local request = executorFunction("request") or executorFunction("http_request")
		local body
		if request then
			local response = request({Url=url, Method="GET"})
			if type(response) ~= "table" or tonumber(response.StatusCode) ~= 200 then
				error("Recherche serveurs refusee : HTTP " .. tostring(type(response)=="table" and response.StatusCode or "?"))
			end
			body = response.Body
		else
			body = game:HttpGet(url)
		end
		local decoded = HttpService:JSONDecode(body)
		if type(decoded) ~= "table" or type(decoded.data) ~= "table" then error("Reponse serveurs invalide") end
		for _, server in ipairs(decoded.data) do table.insert(all, server) end
		cursor = type(decoded.nextPageCursor) == "string" and decoded.nextPageCursor or nil
		if not cursor or cursor == "" then break end
		task.wait(0.2)
	end
	return FusionModules.Helpers.filterPublicServers(all, game.JobId)
end



function FusionModules.Helpers.holdSearchForReset()
	if searchWaitForEgg then return true end
	if not AreaEggCycle or not ServerClock then return false end
	local ok, remaining = pcall(function()
		if not AreaEggCycle.IsRunning() then return nil end
		-- Same countdown as GameResetTimerController, including schedule overrides.
		return AreaEggCycle.SecondsUntilPhaseEnd(ServerClock.Now())
	end)
	if ok and type(remaining) == "number" and remaining >= 0 and remaining < 60 then
		searchWaitForEgg = true
		serverSearchState = "Suspendue : reset dans "..math.ceil(remaining).." s ; attente d'un oeuf eligible"
		log("SERVER_CHANGE", "Recherche suspendue : compte a rebours %.1f s ; maintien sur ce serveur jusqu'au prochain oeuf eligible", remaining)
		return true
	end
	return false
end

-- Server search starts only after a confirmed successful collection.
function FusionModules.Helpers.prepareServerContinuation()
	if continuationPrepared then return true end
	local queue = executorFunction("queue_on_teleport") or executorFunction("queueonteleport")
	if not queue then
		local synApi = executorEnvironment.syn
		if type(synApi) == "table" and type(synApi.queue_on_teleport) == "function" then queue = synApi.queue_on_teleport end
	end
	if not queue then return false, "Relancement automatique indisponible : queue_on_teleport absent" end
	local loader = FusionModules.Reporting.ClientKind == "admin" and "Admin" or "Hub"
	local ok, reason = pcall(queue, "if not game:IsLoaded() then game.Loaded:Wait() end loadstring(game:HttpGet(" .. string.format("%q", "https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Loaders/" .. loader .. ".lua") .. "))()")
	if ok then continuationPrepared=true end
	return ok,reason
end

-- Retained for future explicit use only. No automatic caller is registered.
requestRandomServerHop = function(token, reason)
 if FusionModules.Reporting.ClientKind~="admin" then return false end
	if serverHopPending then return true end
	if not automaticMode or not autoEnabled or generation ~= token
		or destroyed or currentCycle or FusionModules.Pending() or inventoryPlacementBusy or placementRequest or hatchInProgress or stopAfterFlight or queuePaused
		or os.clock() < nextServerHopAt then return false end
	if FusionModules.Helpers.holdSearchForReset() then return false end
	local carry = readCarry()
	if not carry or carry.IsCarrying or (inFlightRequest and not inFlightRequest.done) then return false end
	nextServerHopAt = os.clock()+30
	serverSearchState = "Recherche de serveur..."
	setStatus(serverSearchState)
	local ok, servers = pcall(FusionModules.Helpers.fetchPublicServers)
	-- An OFF click during HTTP must cancel this departure.
	if destroyed or not automaticMode or not autoEnabled
		or generation ~= token or queuePaused or stopAfterFlight then return false end
	if not ok or #servers == 0 then
		serverSearchState = "Recherche : nouvel essai dans 30 s"
		log("SERVER_CHANGE", "Recherche echouee : %s", ok and "aucun serveur libre non visite ; historique conserve" or tostring(servers))
		return false
	end
	if reason == "Aucun oeuf eligible" then
		syncQueue()
		if os.clock() < serverSearchReadyAt or selectBest() then return false end
	end
	if FusionModules.Helpers.holdSearchForReset() then return false end
	local saved, saveReason = executorTools.SaveSettings()
	if not saved then
		serverSearchState = "Recherche bloquee : sauvegarde indisponible"
		log("SERVER_CHANGE", "%s", tostring(saveReason))
		return false
	end
	local queued, queueReason = FusionModules.Helpers.prepareServerContinuation()
	if not queued then
		serverSearchState = "Recherche bloquee : relancement indisponible"
		log("SERVER_CHANGE", "%s", tostring(queueReason))
		return false
	end
	-- Candidates are sorted by population ascending; choose the least populated.
	local destination = servers[1].id
	-- Reserve before departure, including failed attempts, and carry history across servers.
	visitedServers[destination]=true
	local historySaved,historyError=executorTools.SaveSettings()
	if not historySaved then
		visitedServers[destination]=nil
		serverSearchState="Recherche bloquee : historique non sauvegarde"
		log("SERVER_CHANGE","Historique : %s",tostring(historyError))
		return false
	end
	serverHopPending = true
	serverSearchState = "Changement de serveur..."
	stopMovement(true)
	log("SERVER_CHANGE", "%s | Destination=%s Joueurs=%d/%d Recherche=%s", reason, destination, servers[1].playing, servers[1].maxPlayers, tostring(searchingServer))
	executorTools.SaveLog()
	local function resumeAfterFailure(message)
		if not serverHopPending or destroyed then return end
		serverHopPending = false
		autoEnabled = false
		autoActivity = "IDLE"
		serverSearchState = "Echec connexion : nouvel essai dans 30 s"
		nextServerHopAt = os.clock()+30
		log("SERVER_CHANGE", "%s", tostring(message))
		if automaticMode and not queuePaused then wakeQueue() end
	end
	local failureConnection
	failureConnection = connect(game:GetService("TeleportService").TeleportInitFailed,function(failedPlayer, result, message)
		if failedPlayer ~= player then return end
		failureConnection:Disconnect()
		resumeAfterFailure(tostring(result)..": "..tostring(message))
	end)
	local sent, failure = pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,destination,player)
	end)
	if not sent then failureConnection:Disconnect(); resumeAfterFailure(failure); return true end
	task.delay(25,function()
		failureConnection:Disconnect()
		resumeAfterFailure("Connexion non terminee apres 25 s")
	end)
	return true
end

-- Render sends data-only destinations. Revalidate favorite status, Auto and income locally.
FusionModules.RemoteHop={Pending=nil,Processing=false,RetryAt=0}
function FusionModules.RemoteHop.Note(key,text,target)
 local hop=FusionModules.RemoteHop
 if hop.LastNote==key then return end
 hop.LastNote=key
 if target then
  text=text..string.format(" : %s [Poids=%s kg; Revenu=%s/s] Serveur=%s",tostring(target.name or target.category or target.uid),type(target.weightKg)=="number"and formatNumber(target.weightKg)or "inconnu",type(target.incomePerSecond)=="number"and formatNumber(target.incomePerSecond)or "inconnu",tostring(target.jobId))
 end
 log("SERVER_CHANGE","%s",text)
end
function FusionModules.RemoteHop.Validate(target, forced)
 local report=FusionModules.Reporting
 if FusionModules.Reporting.ClientKind~="admin" then return false end
 if destroyed or not ready or not report or not report.Ready or not report.TeleportAllowed or not report.SettingsAllowed or (not forced and not report.AutomationActive()) then return false end
 if type(target)~="table" or target.placeId~=tostring(game.PlaceId) or type(target.jobId)~="string" or target.jobId=="" or #target.jobId>128 or target.jobId==game.JobId then return false end
 if forced then return true end
 local rate=target.incomePerSecond
 if type(rate)~="number" or rate~=rate or rate<0 or rate>=math.huge then return false end
  local missing=FusionModules.Options.AutoIndex and report.MissingCategories()[target.category]==true
 if not missing and not (FusionModules.Options.AutoEggs and rate>=FusionModules.Options.AutoEggsMin and rate<=FusionModules.Options.AutoEggsMax)then return false end
 if visitedServers[target.jobId] or target.carrierUserId or target.state=="Carried" or target.state=="Claimed" or target.observationOnly then return false end
 return true
end
function FusionModules.RemoteHop.Receive(message)
 local hop=FusionModules.RemoteHop
 if hop.Pending and hop.Pending.Forced and os.clock()<hop.Pending.Deadline and not (type(message)=="table"and message.force==true)then return end
 if type(message)~="table"or not message.target then
  if hop.Pending then hop.Note("cancel:"..tostring(hop.Pending.Id),"Cible annulee par Render (oeuf disparu, expire ou conditions modifiees)",hop.Pending.Target)end
  hop.Pending=nil;return
 end
 if not FusionModules.RemoteHop.Validate(message.target,message.force==true)then
  hop.Note("refused:"..tostring(message.requestId),"Demande refusee localement : "..FusionModules.Reporting.AutomationReason().." ; verifier seuil, index, serveur visite ou oeuf indisponible",message.target)
  hop.Pending=nil;return
 end
 local expiry,serverTime=message.target.expiresAt,message.serverTime
 if type(expiry)~="number" or type(serverTime)~="number" or expiry<=serverTime or expiry-serverTime>1200000 then hop.Pending=nil;return end
 hop.Note("received:"..tostring(message.requestId),"Cible recue de Render",message.target)
 hop.Pending={Target=message.target,Deadline=os.clock()+(expiry-serverTime)/1000,Id=message.requestId,Forced=message.force==true}
 if message.force==true then hop.RetryAt=0 end
 hop.Try()
end
function FusionModules.RemoteHop.Try()
 local hop=FusionModules.RemoteHop
 if hop.Processing or serverHopPending or not hop.Pending or os.clock()<hop.RetryAt then return false end
 if FusionModules.MutationBusy or FusionModules.ManualBusy then return false end
 local request=hop.Pending
 if os.clock()>=request.Deadline or not hop.Validate(request.Target,request.Forced)then
  hop.Note("invalid:"..tostring(request.Id),os.clock()>=request.Deadline and "Cible expiree avant le depart"or "Conditions locales non remplies avant le depart",request.Target)
  hop.Pending=nil;return false
 end
 local immediate=request.Forced or request.Target.incomePerSecond>=FusionModules.Options.TeleportInstantMin
 if not immediate then
  if next(queuedEggs)~=nil or currentCycle or inventoryPlacementBusy or placementRequest or hatchInProgress or FusionModules.Pending() or (inFlightRequest and not inFlightRequest.done)then
   hop.Note("waiting:"..tostring(request.Id),"Teleportation en attente : file locale ou action en cours",request.Target)
   return false
  end
  local carry=readCarry()
  if not carry or carry.IsCarrying then hop.Note("carrying:"..tostring(request.Id),"Teleportation en attente : oeuf porte ou etat du portage indisponible",request.Target);return false end
 end
 hop.Processing=true
 task.spawn(function()
  local function release(reason)
   hop.Processing=false;hop.RetryAt=os.clock()+30
   if reason then setStatus("Teleportation Render : "..tostring(reason));log("ACTION","Teleportation Render refusee : %s",tostring(reason))end
  end
  local success,failure=xpcall(function()
   local saved,why=executorTools.SaveSettings()
   if not saved then release(why);return end
   local queued,reason=FusionModules.Helpers.prepareServerContinuation()
   if not queued then release(reason);return end
   if hop.Pending~=request or os.clock()>=request.Deadline or not hop.Validate(request.Target,request.Forced) then release();return end
   if not immediate and (next(queuedEggs)~=nil or currentCycle)then hop.Processing=false;return end
   local target=request.Target
   -- Cancel old generation before dispatch so movement and optional actions cannot restart.
   serverHopPending=true
   generation+=1
   autoEnabled=false
   if currentCycle then cleanupCycle(currentCycle)end
   stopMovement(true)
   visitedServers[target.jobId]=true
   local stored,storeReason=executorTools.SaveSettings()
   if not stored then visitedServers[target.jobId]=nil;error(storeReason)end
   FusionModules.Reporting.MarkSettingsDirty()
   local description=string.format("%s [Poids=%s kg; Revenu=%s/s]",tostring(target.name or target.category or target.uid),(type(target.weightKg)=="number"and formatNumber(target.weightKg)or "inconnu"),formatNumber(target.incomePerSecond))
   setStatus("Teleportation vers "..description)
   log("SERVER_CHANGE","Quitter le serveur %s -> %s pour %s Mode=%s",game.JobId,target.jobId,description,request.Forced and "GO manuel force"or (immediate and "immediat"or "file vide"))
   pcall(function()game:GetService("TeleportService"):SetTeleportSetting("OvoraRemoteArrival",{jobId=target.jobId,fromJobId=game.JobId,uid=target.uid,name=target.name,weightKg=target.weightKg,incomePerSecond=target.incomePerSecond,clientKind=FusionModules.Reporting.ClientKind,reporterUserId=tostring(player.UserId),expiresAt=os.time()+300})end)
   FusionModules.Reporting.FlushLogs()
   local connection
   local resumed=false
   local function resume(detail)
    if resumed or destroyed then return end
    resumed=true
    if connection then connection:Disconnect()end
    serverHopPending=false;hop.Processing=false;hop.RetryAt=os.clock()+30
    hop.Pending=nil
    autoActivity="IDLE"
    log("SERVER_CHANGE","Teleportation echouee vers %s pour %s : %s",target.jobId,description,tostring(detail))
    pcall(function()game:GetService("TeleportService"):SetTeleportSetting("OvoraRemoteArrival",nil)end)
    if automaticMode and not queuePaused and not stopAfterFlight then wakeQueue()end
    FusionModules.Reporting.MarkSettingsDirty()
   end
   connection=connect(game:GetService("TeleportService").TeleportInitFailed,function(failedPlayer,result,detail)
    if failedPlayer==player then resume(tostring(result)..": "..tostring(detail))end
   end)
   local sent,err=pcall(function()game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,target.jobId,player)end)
   if not sent then resume(err);return end
   task.delay(25,function()resume("Connexion non terminee apres 25 s")end)
  end,debug.traceback)
  if not success then
   if serverHopPending then serverHopPending=false;autoEnabled=false;if automaticMode and not queuePaused then wakeQueue()end end
   release(failure)
  end
 end)
 return true
end
do
 local elapsed=0
 connect(RunService.Heartbeat,function(dt)
  elapsed+=dt
  if elapsed<.1 then return end
  elapsed=0
  FusionModules.RemoteHop.Try()
 end)
end

connect(RunService.Heartbeat,function()
 if not FusionModules.BatCombat then return end
 local ok,err=pcall(FusionModules.BatCombat.Step)
 if not ok then
  FusionModules.BatCombat.NextCheckAt=os.clock()+1
  if FusionModules.BatCombat.LastError~=tostring(err)then
   FusionModules.BatCombat.LastError=tostring(err)
   log("ERROR","Batte automatique : %s",tostring(err))
  end
 end
end)

-- FOXIN reference logic: direct Workspace models, matching names, zero Velocity,
-- MoveTo at the current root position, every 0.2 seconds. Always active.
local function immobilizeReferenceGuards()
	for _, model in ipairs(Workspace:GetChildren()) do
		if model:IsA("Model") then
			local nameL = model.Name:lower()
			if string.find(nameL, "guard") or string.find(nameL, "boss")
				or string.find(nameL, "jefe") or string.find(nameL, "enemy") then
				local npcHumanoid = model:FindFirstChildOfClass("Humanoid")
				local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if npcHumanoid and hrp then
					hrp.Velocity = Vector3.zero
					npcHumanoid:MoveTo(hrp.Position)
				end
			end
		end
	end
end
local guardControlElapsed = 0
connect(RunService.Heartbeat, function(delta)
	if destroyed then return end
	guardControlElapsed += delta
	if guardControlElapsed < 0.2 then return end
	guardControlElapsed = 0
	local ok, reason = pcall(immobilizeReferenceGuards)
	if not ok then log("GUARD_CONTROL", "Reference FOXIN : %s", tostring(reason)) end
end)


-- The interface is supplied by HubUI; Admin stays headless.
-- Gameplay polling belongs to the engine, including headless Admin, not the GUI.
do
 local elapsed=0
 connect(RunService.Heartbeat,function(dt)
  elapsed+=dt
  if elapsed<CONFIG.ScanInterval then return end
  elapsed=0
  if ready and not destroyed then syncQueue();wakeQueue()end
 end)
end

-- Repeat return jumps after landing, without overriding the game's speed.
connect(RunService.Heartbeat, function()
	if destroyed or not ready then return end
	local ctx = currentCycle
	if not ctx or not validCycle(ctx) or ctx.phase ~= "RETURN" or ctx.braking then return end
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or humanoid.Health <= 0 or motionBlockReason(ctx) then return end
	if not ctx.returnDestination or not ctx.returnStartDistance then return end
	if isSafe(root.Position) == true then humanoid.Jump = false; return end
	if distanceXZ(root.Position, ctx.returnDestination) > ctx.returnStartDistance * 0.5 then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end
	if not humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then return end
	local now = os.clock()
	if now - (ctx.lastReturnJump or -math.huge) < 0.2 then return end
	ctx.lastReturnJump = now
	humanoid.Jump = true
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end)

-- Explicit, bounded black-box probes; never start automatically.


local correctionSample
local lastCorrectionNotice = -math.huge
connect(RunService.Heartbeat, function()
	if destroyed or not ready or not autoEnabled then correctionSample = nil; return end
	local character, humanoid, root = getCharacterParts()
	if not root or not humanoid then correctionSample = nil; return end
	local now = os.clock()
	if correctionSample and correctionSample.Character == character then
		local delta = now-correctionSample.Time
		local distance = distanceXZ(root.Position, correctionSample.Position)
		local allowance = math.max(40, math.max(humanoid.WalkSpeed, correctionSample.WalkSpeed)*delta*2.5+15)
		if delta > 0 and delta < 0.5 and distance > allowance and now-lastCorrectionNotice > 1 then
			lastCorrectionNotice = now
			movementResumePending = true
			movementRevision += 1
			syncPauseUntil = math.max(syncPauseUntil, now+0.5)
			if currentCycle then
				currentCycle.syncCorrectionCount = (currentCycle.syncCorrectionCount or 0)+1
				if currentCycle.syncCorrectionCount > 5 then
					log("SYNC_DIAG", "Corrections repetees : collecte suspendue apres 5 reprises")
					stopAutomation("Corrections de position repetees : voir le log")
				end
			end
			stopMovement() -- Cancel walking without cancelling the incoming physical correction.
			log("SYNC_DIAG", "Source=%s Revision=%d SautObserve=%.1f Seuil=%.1f Phase=%s DernierFreinMs=%.0f | cause non deduite de la seule position",
				now-lastRelocateAt < 1 and "Relocate_recent" or "deplacement_discontinu_origine_inconnue",
				movementRevision, distance, allowance, currentCycle and currentCycle.phase or autoActivity, (now-lastPhysicalBrakeAt)*1000)
		end
	end
	correctionSample = {Character=character, Time=now, Position=root.Position, WalkSpeed=humanoid.WalkSpeed}
end)

-- History decoding has its own register scope.
;(function()
local historyOK, previousLog = executorTools.ReadLog()
if historyOK and type(previousLog) == "string" then
	for line in previousLog:gmatch("[^\r\n]+") do
		if line:find("[FLIGHT_RESULT]", 1, true) then
			local name, result = line:match('Vol de "(.-)" (.+)$')
			if name and (result == "Reussi" or result == "Echoue") then
				table.insert(flightHistory, {Text='Vol de "'..name..'" '..result, Success=result=="Reussi"})
				if #flightHistory > 200 then table.remove(flightHistory,1) end
			end
		end
	end
end
end)()

log("SESSION", "Nouveau lancement %s", os.date("%Y-%m-%d %H:%M:%S"))
loadSettings()
if FusionModules.Reporting.ClientKind~="admin" then FusionModules.Options.AutoHelp=false;FusionModules.Options.HelpFavorites="";automaticMode=true end
if game.JobId~="" then visitedServers[game.JobId]=true end
if FusionModules.Reporting.Headless then
 local playerGui=player:FindFirstChildOfClass("PlayerGui")
 local old=playerGui and playerGui:FindFirstChild("AutoSAEGui")
 if old then old:Destroy()end
end
local gui = Instance.new("Folder")
if FusionModules.Reporting.ClientKind=="admin" then automaticMode=true;queuePaused=false;stopAfterFlight=false end
setStatus("Chargement des modules du jeu...")
connect(player.CharacterRemoving, function()
	stopAutomation("Personnage retire : redemarre depuis la zone sure")
end)
local function destroy()
	if destroyed then return end
	stopAutomation("Script ferme")
	executorTools.SaveSettings()
	executorTools.SaveLog()
	destroyed = true
    if FusionModules.AdminRuntime then FusionModules.AdminRuntime.Destroy()end
    FusionModules.Reporting.Disconnect()
	for _, connection in ipairs(lifetimeConnections) do connection:Disconnect() end
	table.clear(lifetimeConnections)
	if shared.__AutoSAEController and shared.__AutoSAEController.Gui == gui then
		shared.__AutoSAEController = nil
	end
	if gui.Parent then gui:Destroy() end
end

local previous = shared.__AutoSAEController
if previous and type(previous.Destroy) == "function" then
	pcall(previous.Destroy)
end
shared.__AutoSAEController = {Destroy = destroy, Gui = gui, Reporting = FusionModules.Reporting,
 IsEnabled=function()return automaticMode end,
 FieldRecords=function()
  local rows={};for uid,r in pairs(records)do if isTrackedFieldState(r)and not ownsEgg(uid)then table.insert(rows,r)end end;return rows
 end,
 FlightHistory=function()return table.clone(flightHistory)end,
 Collect=function(ids)
  if not ready or destroyed then return false end
  syncQueue()
  local added=0;for _,uid in ipairs(ids)do if enqueueEgg(records[uid],"MANUEL")then added+=1 end end
  queuePaused=false;stopAfterFlight=false;syncQueue();wakeQueue();return added>0
 end,
 AdminContext = {
  Report=FusionModules.Reporting,
  SetRuntime=function(runtime)FusionModules.AdminRuntime=runtime end,
  Ready=function()return ready and not destroyed end,
  GetOptions=function()return table.clone(FusionModules.Options)end,
  InventoryNotice=function(text)FusionModules.InventoryNotice=tostring(text):sub(1,500)end,
  BeginManual=function()
   if destroyed or not ready or serverHopPending or currentCycle or inventoryPlacementBusy or placementRequest or hatchInProgress or FusionModules.Pending() or(inFlightRequest and not inFlightRequest.done)then return false end
   syncQueue();if automaticMode and selectBest()then return false end
   local carry=readCarry();if not carry or carry.IsCarrying then return false end
   FusionModules.ManualBusy=true;stopAutomation("Action manuelle Render en cours",false);RunService.Heartbeat:Wait()
   local ok,why=leaveTreadmill(generation);if not ok then FusionModules.ManualBusy=false;error("Sortie tapis : "..tostring(why))end
   return true
  end,
  ManualCanContinue=function()
   if not FusionModules.ManualBusy or destroyed or serverHopPending or currentCycle then return false end
   syncQueue();return not(automaticMode and selectBest())
  end,
  EndManual=function()FusionModules.ManualBusy=false;wallMaintenancePending=true;if not destroyed and automaticMode then FusionModules.QueueResumeAt=0;wakeQueue()end end,
  GetStatus=function()
   local reason=FusionModules.PlacementStatus or"Placement en attente de maintenance"
   if not FusionModules.Options.AutoPlace then reason="Placement automatique OFF"
   elseif currentCycle or next(queuedEggs)then reason="Placement en attente : collecte des oeufs prioritaire"
   elseif placementRequest then reason="Placement en attente de confirmation serveur"end
   if FusionModules.AdminRuntime and FusionModules.AdminRuntime.ManualPending then reason="Action manuelle en attente : priorite au vol"end
   return tostring(lastStatusText or autoActivity or"En attente").." · "..reason..(FusionModules.InventoryNotice and" · "..FusionModules.InventoryNotice or"")
  end,
  MutationLock=function(value)FusionModules.MutationBusy=value==true end,
  MoveForUpgrade=FusionModules.Helpers.MoveForUpgrade,
  CanProgression=function()
   if destroyed or not ready or not automaticMode or not autoEnabled or queuePaused or stopAfterFlight or currentCycle or serverHopPending or FusionModules.Pending()or inventoryPlacementBusy or placementRequest or hatchInProgress then return false end
   local carry=readCarry();if not carry or carry.IsCarrying then return false end
   return not FusionModules.YieldToSpawnedEggs()
  end,
  CanMutate=function()return not destroyed and ready and automaticMode and autoEnabled and not queuePaused and not currentCycle and not serverHopPending and not FusionModules.Pending() and not inventoryPlacementBusy and not placementRequest and not hatchInProgress end,
  Busy=function()return destroyed or autoEnabled or currentCycle~=nil or inventoryPlacementBusy or placementRequest~=nil or hatchInProgress or FusionModules.Pending() or serverHopPending end,
  Countdown=FusionModules.Helpers.PlotEggCountdown, FindSpot=findPlotEggSpot, AcknowledgeReward=FusionModules.AcknowledgeReward,
  SetEnabled=function(value)return shared.__AutoSAEController.SetEnabled(value)end,
  SetOptions=function(options)
   local was=automaticMode
   if not FusionModules.Helpers.RestoreOptions(options)then return false end
   automaticMode=was;FusionModules.Reporting.MarkSettingsDirty();wallMaintenancePending=true
   if ready and automaticMode then syncQueue();wakeQueue()end
   executorTools.SaveSettings();return true
  end,
 },
 SetEnabled = function(enabled)
  if destroyed then return false end
  automaticMode=enabled==true
  if automaticMode then
   queuePaused=false;stopAfterFlight=false
   if ready then safeHome=getStartAreaDestination();syncQueue();wakeQueue() end
  else requestUserStop("Admin OFF") end
  FusionModules.Reporting.MarkSettingsDirty()
  return automaticMode
 end
}
connect(gui.Destroying, destroy)
connect(script.Destroying, destroy)
-- Announce arrival before loading the gameplay modules and building inventory state.
task.spawn(function()
 local ok,why=pcall(FusionModules.Reporting.Start)
 if not ok and not destroyed then log("ERROR","Observer startup : %s",tostring(why))end
end)
task.spawn(function()
	while not destroyed do
		task.wait(2)
		if destroyed then break end
		if executorFunction("writefile") then
			local settingsOK, settingsError = executorTools.SaveSettings()
			if not settingsOK then warn("[Auto_SAE] Ecriture parametres : " .. tostring(settingsError)) end
			if sequence ~= lastSavedLogSequence then
				local sequenceToSave = sequence
				local logOK, logError = executorTools.SaveLog()
				if logOK then lastSavedLogSequence = sequenceToSave
				else warn("[Auto_SAE] Ecriture logs : " .. tostring(logError)) end
			end
		end
	end
end)
task.spawn(function()
	local ok, failure = xpcall(initialize, debug.traceback)
	if not ok and not destroyed then
		ready = false
		setStatus("Modules indisponibles : voir la console", Color3.fromRGB(255, 130, 110))
		log("ERROR", "%s", tostring(failure))
	end
end)



return shared.__AutoSAEController

