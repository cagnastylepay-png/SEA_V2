-- SEA_V2 Observer loader
local source = game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Observer.lua")
local chunk, failure = loadstring(source, "SEA_V2/Observer")
assert(chunk, failure)
return chunk()

