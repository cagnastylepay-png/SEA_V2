if shared.__SEAAdminBoot then return shared.__SEA_V2Admin end
if shared.__SEA_V2Admin and not shared.__SEA_V2Admin.Destroyed and shared.__SEA_V2Admin.JobId==game.JobId and os.clock()-(shared.__SEA_V2Admin.StartedAt or -math.huge)<10 then return shared.__SEA_V2Admin end
local ADMIN_SOURCE_URL="https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Admin.lua"
local RELOAD_GUI_NAME="SEAAdminReloadGui"
local function boot()
-- Background Admin: no full in-game controls; only the standalone Reload button.
local engine=shared.__AutoSAEController
if engine and type(engine.Destroy)=="function"then pcall(engine.Destroy)end
local playerGui=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local oldGui=playerGui and playerGui:FindFirstChild("AutoSAEGui")
if oldGui then oldGui:Destroy()end
local previous=shared.__SEA_V2Admin
if previous and type(previous.Destroy)=="function"then pcall(previous.Destroy)end
if not shared.__SEAObserverController or shared.__SEAObserverController.Destroyed then
 local start,err=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Observer.lua"),"SEA_V2/Observer")
 assert(start,err);start()
end
local saved=shared.__AutoSAEReportingOptions
local options=type(saved)=="table"and table.clone(saved)or{}
options.ClientKind="admin";options.Headless=true
shared.__AutoSAEReportingOptions=options
local ok,reason=pcall(function()
 local run,err=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Hub.lua"),"SEA_V2/Hub")
 assert(run,err);run()
end)
shared.__AutoSAEReportingOptions=saved
assert(ok,reason)
local controller=assert(shared.__AutoSAEController,"Admin engine absent")
local run,err=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/AdminRuntime.lua"),"SEA_V2/AdminRuntime")
assert(run,err)
local runtime=run()(assert(controller.AdminContext,"Admin context absent"))
controller.AdminContext.SetRuntime(runtime)
local Admin={Destroyed=false,JobId=game.JobId,StartedAt=os.clock()}
function Admin.Destroy(preserveReloadGui)
 if Admin.Destroyed then return end
 Admin.Destroyed=true;pcall(runtime.Destroy);pcall(controller.Destroy)
 if shared.__SEA_V2Admin==Admin then shared.__SEA_V2Admin=nil end
 if not preserveReloadGui and Admin.ReloadGui then Admin.ReloadGui:Destroy()end
end
function Admin.SetEnabled(enabled)return controller.SetEnabled(enabled)end
function Admin.GetStatus()return {Destroyed=Admin.Destroyed,Connected=controller.Reporting.Ready,Busy=runtime.Busy}end
shared.__SEA_V2Admin=Admin
Admin.SetEnabled(true)

local function installReloadGui()
 local guiParent=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
 if not guiParent then guiParent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",10)end
 if not guiParent then return end
 local old=guiParent:FindFirstChild(RELOAD_GUI_NAME)
 if old then old:Destroy()end
 local gui=Instance.new("ScreenGui")
 gui.Name=RELOAD_GUI_NAME;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=1000000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 local button=Instance.new("TextButton")
 button.Name="Reload";button.AnchorPoint=Vector2.new(1,0);button.Position=UDim2.new(1,-12,0,12);button.Size=UDim2.fromOffset(120,42)
 button.BackgroundColor3=Color3.fromRGB(24,35,53);button.BorderColor3=Color3.fromRGB(93,118,158);button.BorderSizePixel=1
 button.AutoButtonColor=true;button.Font=Enum.Font.GothamSemibold;button.Text="Reload";button.TextColor3=Color3.fromRGB(240,246,255);button.TextSize=18
 button.Parent=gui;gui.Parent=guiParent;Admin.ReloadGui=gui
 local reloading=false
 button.Activated:Connect(function()
  if reloading then return end
  reloading=true;button.Text="Reload..."
  local fetched,source=pcall(function()return game:HttpGet(ADMIN_SOURCE_URL)end)
  if not fetched then warn("[SEA Reload] Telechargement impossible : "..tostring(source));button.Text="Reload";reloading=false;return end
  local latest,failure=loadstring(source,"SEA_V2/Admin")
  if not latest then warn("[SEA Reload] Compilation impossible : "..tostring(failure));button.Text="Reload";reloading=false;return end
  task.defer(function()
   pcall(Admin.Destroy,true)
   local ok,reason=pcall(latest)
   if not ok then warn("[SEA Reload] Redemarrage impossible : "..tostring(reason));button.Text="Reload";reloading=false end
  end)
 end)
end
installReloadGui()
return Admin

end
shared.__SEAAdminBoot=true
local ok,result=pcall(boot)
shared.__SEAAdminBoot=nil
if not ok then
 local controller=shared.__AutoSAEController
 if controller and controller.Reporting and controller.Reporting.ClientKind=="admin"then pcall(controller.Destroy)end
 error(result)
end
return result
