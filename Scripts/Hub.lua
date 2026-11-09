-- Stable public entry: Admin and Hub share the same proven gameplay engine.
local base="https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/"
local function load(name)
 local chunk,why=loadstring(game:HttpGet(base..name..".lua"),"SEA_V2/"..name)
 assert(chunk,why);return chunk()
end
local options=shared.__AutoSAEReportingOptions
if type(options)=="table"and options.ClientKind=="admin"then return load("GameplayEngine")end
-- Do not replace an active Admin when an executor also starts the Hub loader.
if shared.__SEAAdminBoot or(shared.__SEA_V2Admin and not shared.__SEA_V2Admin.Destroyed)then return shared.__AutoSAEController end
local old=shared.__SEA_V2Hub
if old and old.Destroy then old.Destroy()end
local previous=shared.__AutoSAEController
if previous and previous.Destroy then previous.Destroy()end
local startup=type(options)=="table"and table.clone(options)or{}
startup.ClientKind="hub";startup.Headless=true
shared.__AutoSAEReportingOptions=startup
local ok,engine=pcall(load,"GameplayEngine")
shared.__AutoSAEReportingOptions=options
assert(ok,engine)
-- A resumed Admin arrival is handled by the engine's existing arrival guard.
if engine.Reporting.ClientKind=="admin"then return engine end
local runtime,ui
local H={Destroyed=false,Engine=engine}
function H.Destroy()
 if H.Destroyed then return end;H.Destroyed=true
 if ui then ui.Destroy()end
 if runtime then runtime.Destroy()end
 engine.Destroy()
 if shared.__SEA_V2Hub==H then shared.__SEA_V2Hub=nil end
end
shared.__SEA_V2Hub=H
local started,why=pcall(function()
 local ctx=engine.AdminContext
 ctx.LocalOnly=true;ctx.FieldRecords=engine.FieldRecords
 ctx.OnResult=function(result)if ui then ui.Result(result)end end
 runtime=load("AdminRuntime")(ctx);ctx.SetRuntime(runtime)
 ui=load("HubUI")(engine,runtime);H.Gui=ui.Gui
 engine.SetEnabled(true)
end)
if not started then H.Destroy();error(why)end
return H

