return function(source)
 local function section(a,b)local i=assert(source:find(a,1,true));local j=assert(source:find(b,i,true));return source:sub(i,j-1)end
 local fm={Options={},Helpers={},Help={WasDelivered=function()return false end}}
 local queued={};local tracked={}
 local env=setmetatable({FusionModules=fm,queuedEggs=queued,trackedEggs=tracked,removedFromAuto={},cooldowns={},
  isTrackedFieldState=function()return true end,ownsEgg=function()return false end,getRatePerSecond=function()return 50 end,logQueueDecision=function()end},{__index=getfenv()})
 local function compile(c)local f=assert(loadstring(c));setfenv(f,env);return f()end
 compile(section('FusionModules.Options.AutoEggsMaxBiome="All"','function FusionModules.Helpers.SetOption('))
 assert(#fm.Helpers.BiomeChoices()==15 and fm.Helpers.ValidMaxBiome('Alien')and not fm.Helpers.ValidMaxBiome('fake'))
 assert(fm.Helpers.AllowedBiome({AreaId='unknown'}),'All preserves default behavior')
 fm.Options.AutoEggsMaxBiome='Snow'
 assert(fm.Helpers.AllowedBiome({AreaId='Forest'})and fm.Helpers.AllowedBiome({AreaId='Snow'}),'inclusive progression')
 assert(not fm.Helpers.AllowedBiome({AreaId='Volcano'})and not fm.Helpers.AllowedBiome({}),'higher or unresolved area rejected')
 fm.Options.AutoEggsMaxBiome='Prehistoric'
 assert(not fm.Helpers.AllowedBiome({AreaId='Alien'}),'same rarity never used as a biome proxy')
 fm.Options.AutoEggsMaxBiome='Light Dark';assert(fm.Helpers.AllowedBiome({AreaId='Titan Temple'})and not fm.Helpers.AllowedBiome({AreaId='Enchanted Forest'}))
 fm.Options.AutoEggsMaxBiome='Forest'
 local add=compile(section('local function enqueueEgg(record, source)','syncQueue = function()')..'\nreturn enqueueEgg')
 assert(not add({Uid='higher',AreaId='Alien'},'AUTO')and not add({Uid='missing',AreaId='Alien'},'INDEX'),'normal and missing queues obey cap')
 assert(not add({Uid='rare',AreaId='Alien'},'RARITY')and not add({Uid='help',AreaId='Alien'},'HELP'),'rarity and help cannot bypass cap')
 assert(add({Uid='manual',AreaId='Alien'},'MANUEL'),'manual collection exempt')
 assert(add({Uid='forest',AreaId='Forest'},'AUTO'),'chosen biome included')
 return 'Maximum biome passed: ordered inclusive limit, default All, missing/rarity/help filtering, unknown area rejection and manual exemption.'
end

