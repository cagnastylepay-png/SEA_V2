-- SEA_V2 Hub loader
local source = game:HttpGet("https://raw.githubusercontent.com/cagnastylepay-png/SEA_V2/main/Scripts/Hub.lua")
local chunk, failure = loadstring(source, "SEA_V2/Hub")
assert(chunk, failure)
return chunk()

