-- Background Admin: no ScreenGui, icon or in-game controls.
local previous=shared.__SEA_V2Admin
if previous and type(previous.Destroy)=="function"then pcall(previous.Destroy)end
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
local Admin={Destroyed=false}
function Admin.Destroy()
 if Admin.Destroyed then return end
 Admin.Destroyed=true;runtime.Destroy();controller.Destroy()
 if shared.__SEA_V2Admin==Admin then shared.__SEA_V2Admin=nil end
end
function Admin.SetEnabled(enabled)return controller.SetEnabled(enabled)end
function Admin.GetStatus()return {Destroyed=Admin.Destroyed,Connected=controller.Reporting.Ready,Busy=runtime.Busy}end
shared.__SEA_V2Admin=Admin
return Admin
