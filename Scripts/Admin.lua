-- SEA_V2 Admin foundation. Administrative actions will be added explicitly.
-- Never place Render's SECRET_MDP or other server credentials in this client.
local previous = shared.__SEA_V2Admin
if previous and type(previous.Destroy) == "function" then
    pcall(previous.Destroy)
end

local Admin = { Enabled = true, Destroyed = false, Connections = {} }

function Admin.SetEnabled(enabled)
    if Admin.Destroyed then return false end
    Admin.Enabled = enabled == true
    return Admin.Enabled
end

function Admin.GetStatus()
    return { Enabled = Admin.Enabled, Destroyed = Admin.Destroyed, Version = 1 }
end

function Admin.Destroy()
    if Admin.Destroyed then return end
    Admin.Enabled = false
    Admin.Destroyed = true
    for _, connection in ipairs(Admin.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Admin.Connections)
    if shared.__SEA_V2Admin == Admin then shared.__SEA_V2Admin = nil end
end

shared.__SEA_V2Admin = Admin
return Admin
