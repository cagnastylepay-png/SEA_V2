return function(source)
 local now=100;local jobs={};local initialized=false;local allowed=true;local movementAllowed=true;local stock=0;local craftCalls=0;local plotCalls=0;local treadmillCalls=0
 local p={Money=100,BaseUpgradeLevel=0,TreadmillUpgradeLevel=0,Butterflies={Counts={Green=20,Blue=10,Purple=5,Golden=1}}}
 local options={AutoPlotUpgrade=true,AutoTreadmillUpgrade=true,AutoPapillon=false}
 local tool={IsA=function(_,c)return c=="Tool"end,GetAttribute=function(_,key)return key=="ItemType"and"MutationConsumable"or key=="MutationId"and"Enchanted"or key=="Uses"and stock end}
 local bag={GetChildren=function()return{tool}end};local character={GetChildren=function()return{}end}
 local player={UserId=42,Character=character,FindFirstChild=function(_,name)return name=="Backpack"and bag end}
 local sharedState={};local notices={}
 local env=setmetatable({shared=sharedState,game={GetService=function(_,name)return name=="Players"and{LocalPlayer=player}or{}end},os={clock=function()return now end},task={spawn=function(fn)if initialized then table.insert(jobs,fn)end end,wait=function(n)now+=n end}}, {__index=getfenv()})
 local ctx={Report={SessionId="s"},Ready=function()return true end,GetOptions=function()return options end,CanProgression=function()return allowed end,MoveForUpgrade=function()return movementAllowed,"approche interrompue"end,InventoryNotice=function(text)table.insert(notices,text)end}
 local f=assert(loadstring(source));setfenv(f,env);local a=f()(ctx);a.Initialized=true;initialized=true
 a.Save={Peek=function()return p end};a.Publish=function()end
 local recipe={Green=20,Blue=10,Purple=5,Golden=1};local enabled=true;local acknowledge=true;local mutate=true;local fail=false
 a.ProgressModules={Base={IsNextTierAffordable=function(profile)return profile.BaseUpgradeLevel<1 and profile.Money>=80 end,PurchaseNextTier=function()plotCalls+=1;p.Money-=80;p.BaseUpgradeLevel+=1;return true end},Treadmill={CanAffordNext=function(profile)return profile.TreadmillUpgradeLevel<1 and profile.Money>=30 end,RequestCashUpgrade=function()treadmillCalls+=1;p.Money-=30;p.TreadmillUpgradeLevel+=1;return true end},Butterflies={EssenceRecipe=function()return recipe end},ButterflyFlags={Enabled={Get=function()return enabled end}}}
 a.Remotes={Butterflies={AskCraftEssence={InvokeServer=function()
  craftCalls+=1;if fail then error("network outcome unknown")end
  if mutate then for id,cost in pairs(recipe)do p.Butterflies.Counts[id]-=cost end;stock+=1;p.Butterflies.Counts.Green+=1 end
  return acknowledge,"refused"
 end}}}
 local function finish()local job=table.remove(jobs,1);assert(job);job()end
 assert(a.ProgressNext(false)and a.ProgressPending());assert(not a.ProgressNext(false),"serialize one purchase")
 finish();assert(plotCalls==1 and p.Money==20 and not a.ProgressPending()and not a.Busy and not sharedState.__SEAAdminRequestLock)
 assert(not a.ProgressNext(false)and treadmillCalls==0,"reread funds after plot purchase")
 p.Money=30;now+=3;assert(a.ProgressNext(false));finish();assert(treadmillCalls==1 and p.Money==0,"cash equality accepted")
 assert(not a.ProgressNext(false),"MAX stops upgrade requests")
 options.AutoPlotUpgrade=false;options.AutoTreadmillUpgrade=false;options.AutoPapillon=true
 assert(not a.ProgressNext()and craftCalls==0,"Papillons never triggers automatic crafting")
 options.AutoPlotUpgrade=true;p.BaseUpgradeLevel=0;p.Money=100;now+=31
 allowed=false;assert(not a.ProgressNext(),"flight wins before scheduling");allowed=true
 assert(a.ProgressNext()and a.ProgressTravelling());allowed=false;finish();assert(plotCalls==1,"flight wins before movement or purchase");allowed=true;now+=31
 movementAllowed=false;assert(a.ProgressNext());finish();assert(plotCalls==1 and not a.ProgressTravelling(),"failed approach prevents purchase")
 movementAllowed=true;now+=31;assert(a.ProgressNext());finish();assert(plotCalls==2,"purchase only follows confirmed approach")
 now+=31;p.BaseUpgradeLevel=0;p.Money=100
 a.ProgressModules.Base.PurchaseNextTier=function()plotCalls+=1;return true end
 assert(a.ProgressNext());finish();assert(sharedState.__SEAProgressionState.Unknown,"unconfirmed upgrade blocks retries")
 now+=31;assert(not a.ProgressNext()and plotCalls==3,"no duplicate purchase after unknown outcome")
 p.BaseUpgradeLevel=1;assert(not a.ProgressNext(),"late level update resolves uncertainty and MAX stops purchases")
 assert(not sharedState.__SEAProgressionState.Unknown)
 assert(not source:find("AskCraftEssence",1,true),"automatic craft remote removed from runtime")
 return "Progression passed: sequential cash upgrades, fresh balance, MAX, flight priority, confirmed approach before buying, uncertain-result blocking and no automatic crafting. No real purchase."
end

