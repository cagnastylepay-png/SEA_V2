return function(hub)
 local first=assert(hub:find("function FusionModules.Helpers.MissingFromIndex",1,true))
 local last=assert(hub:find("local function findPlotEggSpot",first,true))
 local saleStart=assert(hub:find("function FusionModules.Helpers.inventoryEggsBelowMinimum",1,true))
 local saleEnd=assert(hub:find("local function sellInventoryEggsBelowMinimum",saleStart,true))
 local profile={Index={Known=true}}
 local fm={Options={AutoIndex=true,AutoPlaceMin=10,AutoPlaceMax=100,AutoSellMin=0,AutoSellMax=1000},Helpers={}}
 function fm.Helpers.InIncomeRange(key,rate)return type(rate)=="number"and rate>=fm.Options[key.."Min"]and rate<=fm.Options[key.."Max"]end
 local fn=assert(loadstring(hub:sub(first,last-1)..hub:sub(saleStart,saleEnd-1)))
 setfenv(fn,setmetatable({FusionModules=fm,Save={Peek=function()return profile end},getRatePerSecond=function(egg)return egg.rate end},{__index=getfenv()}));fn()
 local eggs={low={AssetCategory="New",rate=1},high={AssetCategory="New",rate=1001},known={AssetCategory="Known",rate=1},placed={AssetCategory="New",rate=1,Placement={}}}
 local place=fm.Helpers.inventoryPlacementOrder(eggs)
 assert(#place==2 and place[1]=="high"and place[2]=="low","missing eggs bypass both placement income limits")
 local sale=fm.Helpers.inventoryEggsBelowMinimum(eggs)
 assert(#sale==1 and sale[1]=="known","missing eggs never enter automatic sales")
 profile.Index.New=true
 assert(#fm.Helpers.inventoryPlacementOrder(eggs)==0,"live index refresh removes the bypass")
 assert(#fm.Helpers.inventoryEggsBelowMinimum(eggs)==2,"indexed eggs return to normal sale ranges")
 fm.Options.AutoIndex=false
 profile.Index.New=nil
 assert(#fm.Helpers.inventoryPlacementOrder(eggs)==0)
 assert(#fm.Helpers.inventoryEggsBelowMinimum(eggs)==2,"unchecked missing option uses normal sale ranges")
 fm.Options.AutoIndex=true;profile={}
 assert(#fm.Helpers.inventoryEggsBelowMinimum(eggs)==0,"unknown index blocks automatic sale until loaded")
 assert(hub:find('not FusionModules.Helpers.CanPlaceInventoryEgg(latest)',1,true),"placement revalidates immediately before sending")
 return "Inventory index policy passed: missing protected from sales; placement bypasses min/max; live index, disabled option and unavailable profile checked."
end

