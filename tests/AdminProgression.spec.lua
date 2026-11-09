return function(source)
 local now=100;local jobs={};local initialized=false;local allowed=true;local stock=0;local craftCalls=0;local plotCalls=0;local treadmillCalls=0
 local p={Money=100,BaseUpgradeLevel=0,TreadmillUpgradeLevel=0,Butterflies={Counts={Green=20,Blue=10,Purple=5,Golden=1}}}
 local options={AutoPlotUpgrade=true,AutoTreadmillUpgrade=true,AutoPapillon=false}
 local tool={IsA=function(_,c)return c=="Tool"end,GetAttribute=function(_,key)return key=="ItemType"and"MutationConsumable"or key=="MutationId"and"Enchanted"or key=="Uses"and stock end}
 local bag={GetChildren=function()return{tool}end};local character={GetChildren=function()return{}end}
 local player={UserId=42,Character=character,FindFirstChild=function(_,name)return name=="Backpack"and bag end}
 local sharedState={};local notices={}
 local env=setmetatable({shared=sharedState,game={GetService=function(_,name)return name=="Players"and{LocalPlayer=player}or{}end},os={clock=function()return now end},task={spawn=function(fn)if initialized then table.insert(jobs,fn)end end,wait=function(n)now+=n end}}, {__index=getfenv()})
 local ctx={Report={SessionId="s"},Ready=function()return true end,GetOptions=function()return options end,CanProgression=function()return allowed end,InventoryNotice=function(text)table.insert(notices,text)end}
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
 allowed=false;assert(not a.ProgressNext(true),"flight wins before scheduling");allowed=true
 assert(a.ProgressNext(true));allowed=false;finish();assert(craftCalls==0,"flight wins immediately before sending");allowed=true;now+=31
 enabled=false;assert(not a.ProgressNext(true));enabled=true
 p.Butterflies.Counts.Golden=0;assert(not a.ProgressNext(true),"all recipe ingredients required");p.Butterflies.Counts.Golden=1
 assert(a.ProgressNext(true));finish();assert(craftCalls==1 and stock==1 and not sharedState.__SEAProgressionState.Unknown,"native reply and essence increase confirm despite concurrent catches")
 p.Butterflies.Counts={Green=40,Blue=20,Purple=10,Golden=2};now+=3;mutate=false
 assert(a.ProgressNext(true));finish();assert(sharedState.__SEAProgressionState.Unknown,"accepted but unconfirmed blocks retries")
 now+=31;assert(not a.ProgressNext(true)and craftCalls==2,"no duplicate craft after uncertain outcome")
 stock+=1;mutate=true;assert(a.ProgressNext(true));finish();assert(craftCalls==3,"late replicated essence resolves uncertainty")
 options.AutoPapillon=false;assert(not a.ProgressNext(true),"Papillons OFF disables craft")
 return "Progression passed: sequential cash purchases, refreshed balance, MAX, flight priority before dispatch, dynamic recipe, live feature flag, automatic craft, concurrent catches and uncertain-result blocking. No real purchase or craft."
end

