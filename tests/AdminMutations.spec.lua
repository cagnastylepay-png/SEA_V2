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
return "AutoMutations + manual mocks passed: strict threshold, 2-try cap, reload persistence, success stop, unknown-result block, AUTO off, exclusive lock. No real consumables used."

end

