return function(source)

local clock=0;local attempts=0;local stored;local outcome="fail";local locked=false
local egg={Uid="e",AssetCategory="Cat",Placement=true,Mutations={},rate=100}
local p={EggInventory={}}
local character={}
local tool={Parent=nil,uses=10}
function tool:IsA(c)return c=="Tool"end
function tool:GetAttribute(k)if k=="ItemType"then return"MutationConsumable"elseif k=="MutationId"then return"Boss"elseif k=="Uses"then return self.uses end end
local humanoid={}
function humanoid:EquipTool(t)t.Parent=character end
function humanoid:UnequipTools()tool.Parent=nil end
function character:GetChildren()return tool.Parent==self and{tool}or{}end
function character:FindFirstChild(k)return k=="HumanoidRootPart"and{Position={}}end
function character:FindFirstChildOfClass()return humanoid end
local backpack={GetChildren=function()return tool.Parent~=character and{tool}or{}end}
local player={UserId=42,Character=character,FindFirstChild=function(_,k)return k=="Backpack"and backpack end}
local teleport={GetTeleportSetting=function()return stored end,SetTeleportSetting=function(_,k,v)stored=v end}
local opts={AutoMutations=true,MutationBossEnabled=true,MutationBossMin=100,MutationBossAttempts=2}
local ctx={Report={SessionId="s",SettingsAllowed=false},Ready=function()return true end,CanMutate=function()return true end,Busy=function()return false end,GetOptions=function()return opts end,MutationLock=function(v)locked=v end}
local env=setmetatable({shared={},game={GetService=function(_,k)if k=="Players"then return{LocalPlayer=player}elseif k=="TeleportService"then return teleport else return{}end end},os={clock=function()return clock end},task={spawn=function()end,wait=function(n)clock+=n end}}, {__index=getfenv()})
local function boot()
 local chunk=assert(loadstring(source));setfenv(chunk,env);local a=chunk()(ctx);a.Initialized=true
 a.Save={Peek=function()return p end};a.EggState={ReadOwnerEggs=function()return{e=egg}end};a.EggRecords={Decode=function(v)return v end,ToAssetItemData=function(r)return r end}
 a.Earnings={RatePerSecond=function(r)return r.rate end};a.Plot={ContainsLocalPoint=function()return true end}
 a.Remotes={BossMastery={AskUseMutationConsumable={InvokeServer=function(_,uid)
  assert(locked and stored.entries["e:Boss"].blocked,"must reserve before dispatch")
  assert(uid=="e");attempts+=1;tool.uses-=1
  if outcome=="unknown"then error("network")end
  if outcome=="success"then egg.Mutations={"Boss"};return{Success=true,Mutated=true,MutationId="Boss"}end
  return{Success=true,Mutated=false,MutationId="Boss"}
 end}}}
 return a
end
local a=boot()
assert(a.MutateNext()==false and attempts==0,"minimum is strict")
egg.rate=101
assert(a.MutateNext()==true and attempts==1 and not locked,"first failed try")
clock+=16;assert(a.MutateNext()==true and attempts==2,"second failed try")
clock+=16;assert(a.MutateNext()==false and attempts==2,"budget exhausted")
a=boot();assert(a.MutateNext()==false and attempts==2,"budget survives reload")
opts.MutationBossAttempts=3;outcome="success";assert(a.MutateNext()==true and attempts==3)
clock+=16;assert(a.MutateNext()==false and attempts==3,"already mutated")
egg.Mutations={};opts.MutationBossAttempts=4;outcome="unknown"
assert(a.MutateNext()==true and attempts==4 and not locked)
clock+=16;opts.MutationBossAttempts=10
assert(a.MutateNext()==false and attempts==4,"unknown result cannot retry")
stored=nil;a=boot();opts.AutoMutations=false;assert(a.MutateNext()==false)

stored=nil;outcome="success";egg.Mutations={};a=boot();ctx.CanMutate=function()return false end
assert(a.Execute({action="egg.mutate",uid="e",mutationId="Boss"})==true and attempts==5,"manual one-shot with AUTO OFF")
ctx.MutationLock(false)
assert(tool.Parent==nil,"consumable released")
assert(not pcall(a.Execute,{action="egg.mutate",uid="e",mutationId="Boss"}),"already applied manual refused")
local resumeCount,beginCount,equips=0,0,0
local queue={}
env.task.spawn=function(fn)table.insert(queue,fn)end
stored=nil;egg.Mutations={};a=boot()
ctx.Report.SettingsAllowed=true
local held=false
ctx.BeginManual=function()beginCount+=1;if beginCount<3 then return false end;held=true;return true end
ctx.ManualCanContinue=function()return held end
ctx.EndManual=function()held=false;resumeCount+=1 end
a.Remotes.Haul={WearBest={InvokeServer=function()assert(held);equips+=1;return true end}}
a.Receive({version=1,requestId="manual-auto",action="equip.best"})
assert(a.Busy)
queue[#queue]()
assert(equips==1 and beginCount==3 and resumeCount==1 and not held and not a.Busy)
assert(a.Seen["manual-auto"].status=="confirmed")
a.Receive({version=1,requestId="manual-auto",action="equip.best"})
assert(equips==1,"no duplicate manual action")
ctx.BeginManual=function()return false end
a.Receive({version=1,requestId="priority",action="equip.best"});queue[#queue]()
assert(equips==1 and a.Seen.priority.status=="rejected" and not a.Busy,"priority waits are bounded and do not execute")


ctx.CanMutate=function()return true end
opts.AutoSellAnimals=true;opts.AutoSellAnimalsMin=10;opts.AutoSellAnimalsMax=20
p.Inventory={sell={Category="Cat",rate=15},min={Category="Cat",rate=10},max={Category="Cat",rate=20},low={Category="Cat",rate=9},high={Category="Cat",rate=21},worn={Category="Cat",rate=15},locked={Category="Cat",rate=15,Locked=true},fusion={Category="Cat",rate=15},favorite={Category="Cat",rate=15,IsFavorite=true}}
p.EquippedAssets={"worn"};p.FusionSlots={"fusion"}
a.Roster={ReadOwnerPen=function()return{}end};a.Items={Decode=function(r)return r end}
local sold={};local saleCalls=0;local removeSold=true
a.Remotes.PetSatchel={SellSelection={FireServer=function(_,batch)
 assert(locked and#batch.Eggs==0);saleCalls+=1
 for _,uid in ipairs(batch.Assets)do sold[uid]=true;if removeSold then p.Inventory[uid]=nil end end
end}}
opts.AutoIndex=true;p.Index={}
assert(a.SellAnimals()==0 and saleCalls==0,"missing animals protected from automatic sale")
p.Index=nil;assert(a.SellAnimals()==0 and saleCalls==0,"unavailable index blocks animal sale")
p.Index={Cat=true}
assert(a.SellAnimals()==3 and sold.sell and sold.min and sold.max)
assert(not sold.worn and not sold.locked and not sold.fusion and not sold.favorite and not sold.low and not sold.high)
assert(a.SellAnimals()==0 and saleCalls==1 and not locked)
p.Inventory.uncertain={Category="Cat",rate=15};removeSold=false
assert(a.SellAnimals()==1 and saleCalls==2);assert(a.SellAnimals()==0 and saleCalls==2,"no retry for unknown animal sale")
opts.AutoSellAnimals=false;p.Inventory.new={Category="Cat",rate=15};assert(a.SellAnimals()==0)
a.Assets={Directory={Viridian={DisplayName="Viridian Prowler",Icon="rbxassetid://98765432101235",Egg={Icon="rbxassetid://98765432101234"}},Placeholder={DisplayName="No image",Icon="rbxassetid://0",Egg={Icon="invalid"}}}}
assert(a.Execute({action="images.collect"}));assert(#a.ImageCatalog==1)
assert(a.ImageCatalog[1].name=="Viridian Prowler"and a.ImageCatalog[1].animalImageAssetId=="98765432101235"and a.ImageCatalog[1].eggImageAssetId=="98765432101234")

-- Stock uses charges, includes equipped tools, and supports all current consumables.
p.Inventory={};p.EggInventory={};p.EquippedAssets={}
a.EggState={ReadOwnerEggs=function()return{}end};a.Roster={ReadOwnerPen=function()return{}end}
a.Constants={};a.Speed={};a.MutationCatalog={};a.MutationFlags={}
local stockTools={}
for _,id in ipairs({"Boss","Scrambled","Enchanted","Nitro","Spectral","Musical","Alien","DarkMatter"})do
 local t={id=id,uses=3};function t:IsA(c)return c=="Tool"end
 function t:GetAttribute(k)return k=="ItemType"and"MutationConsumable"or k=="MutationId"and self.id or k=="Uses"and self.uses or nil end
 table.insert(stockTools,t)
end
backpack.GetChildren=function()return stockTools end
-- A moving tool can appear in both reads; never count it twice.
character.GetChildren=function()return{stockTools[6]}end
local stock=a.Snapshot().mutationConsumables
assert(#stock==8)
for _,r in ipairs(stock)do assert(r.count==3,"charges counted once for "..r.id)end
stockTools[6].uses=2;assert(a.Snapshot().mutationConsumables[6].count==2,"consumption refreshes count")
backpack.GetChildren=function()return{}end
assert(a.Snapshot().mutationConsumables[6].count==2,"equipped stock remains visible")
assert(a.Snapshot().mutationConsumables[1].count==0,"zero stock remains explicit")

return "Mutations, manual AUTO queue, backpack-only animal sale, image catalog mocks passed: strict threshold, 2-try cap, reload persistence, success stop, unknown-result block, AUTO off, exclusive lock. No real consumables used."


end


