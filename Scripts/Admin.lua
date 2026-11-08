-- TODO: Admin gameplay and Render commands will be implemented separately.
-- This placeholder does not start Hub, change gameplay or open a connection.
local previous=shared.__SEA_V2Admin
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy) end
local Admin={Enabled=false,Destroyed=false,Implemented=false}
function Admin.SetEnabled(enabled)
 if Admin.Destroyed then return false end
 Admin.Enabled=enabled==true
 return Admin.Enabled
end
function Admin.GetStatus()
 return {Enabled=Admin.Enabled,Destroyed=Admin.Destroyed,Implemented=false}
end
function Admin.Destroy()
 if Admin.Destroyed then return end
 Admin.Destroyed=true;Admin.Enabled=false
 if shared.__SEA_V2Admin==Admin then shared.__SEA_V2Admin=nil end
end
shared.__SEA_V2Admin=Admin
return Admin
