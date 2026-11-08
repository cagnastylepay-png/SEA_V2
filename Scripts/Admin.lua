-- Admin uses the maintained Hub engine without its full interface.
local previous=shared.__SEA_V2Admin
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy) end
local savedOptions=shared.__AutoSAEReportingOptions
local options=type(savedOptions)=="table" and table.clone(savedOptions) or {}
options.ClientKind="admin"
options.Headless=true
shared.__AutoSAEReportingOptions=options
local ok,result=pcall(function()
 local source=game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Hub.lua")
 local run,err=loadstring(source,"SEA_V2/Scripts/Hub.lua")
 assert(run,err)
 return run()
end)
shared.__AutoSAEReportingOptions=savedOptions
assert(ok,result)
local controller=shared.__AutoSAEController
assert(controller,"Admin: moteur indisponible")
local Admin={Controller=controller,Destroyed=false}
function Admin.Destroy()
 if Admin.Destroyed then return end
 Admin.Destroyed=true
 controller.Destroy()
 if shared.__SEA_V2Admin==Admin then shared.__SEA_V2Admin=nil end
end
function Admin.SetEnabled(enabled)
 if Admin.Destroyed then return false end
 return controller.SetEnabled(enabled)
end
function Admin.GetStatus()
 return {Destroyed=Admin.Destroyed,Connected=controller.Reporting.Ready==true,ClientKind="admin"}
end
shared.__SEA_V2Admin=Admin
return Admin
