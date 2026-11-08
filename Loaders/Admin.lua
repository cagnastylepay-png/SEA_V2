-- SEA_V2 Admin loader
local source = game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Admin.lua?v="..tostring(os.time()))
local chunk, failure = loadstring(source, "SEA_V2/Admin")
assert(chunk, failure)
return chunk()