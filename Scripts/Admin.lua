local ADMIN_BUILD="20261108-fishing-native-ready-2"
if shared.__SEAAdminBoot then return shared.__SEA_V2Admin end
if shared.__SEA_V2Admin and shared.__SEA_V2Admin.Build==ADMIN_BUILD and not shared.__SEA_V2Admin.Destroyed and shared.__SEA_V2Admin.JobId==game.JobId and os.clock()-(shared.__SEA_V2Admin.StartedAt or -math.huge)<10 then return shared.__SEA_V2Admin end
local function boot()
-- Background Admin: no ScreenGui, icon or in-game controls.
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
 local run,err=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Hub.lua?v="..tostring(os.time())),"SEA_V2/Hub")
 assert(run,err);run()
end)
shared.__AutoSAEReportingOptions=saved
assert(ok,reason)
local controller=assert(shared.__AutoSAEController,"Admin engine absent")
local run,err=loadstring(game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/AdminRuntime.lua?v="..tostring(os.time())),"SEA_V2/AdminRuntime")
assert(run,err)
local runtime=run()(assert(controller.AdminContext,"Admin context absent"))
controller.AdminContext.SetRuntime(runtime)
local Admin={Build=ADMIN_BUILD,Destroyed=false,JobId=game.JobId,StartedAt=os.clock()}
function Admin.Destroy()
 if Admin.Destroyed then return end
 Admin.Destroyed=true;runtime.Destroy();controller.Destroy()
 if shared.__SEA_V2Admin==Admin then shared.__SEA_V2Admin=nil end
end
function Admin.SetEnabled(enabled)return controller.SetEnabled(enabled)end
function Admin.GetStatus()return {Destroyed=Admin.Destroyed,Connected=controller.Reporting.Ready,Busy=runtime.Busy}end
shared.__SEA_V2Admin=Admin
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