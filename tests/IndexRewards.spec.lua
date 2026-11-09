return function(source)
 local pending={};local calls=0;local collections=0;local warnings={}
 local p={Index={A=true,B=true},IndexClaimedCategories={},GearInventory={}}
 local signals={};local state={};local outcome='success'
 local env=setmetatable({shared=state,game={JobId='job',GetService=function()return{LocalPlayer={UserId=42}}end},
  task={delay=function(_,fn)table.insert(pending,fn)end},warn=function(m)table.insert(warnings,m)end},{__index=getfenv()})
 local factory=assert(loadstring(source));setfenv(factory,env)
 local d={Assets={Directory={A={},B={},C={}}},Save={Peek=function()return p end,
  Amend=function(key,fn)fn(p[key])end,Watch=function(key)local signal={Connect=function(_,fn)signals[key]=fn;return{Disconnect=function()signals[key]=nil end}end};return signal end},
  Collections=function()return{{id='LimitedEgg',gear='Reward',entries={{AssetId='A'},{AssetId='B'}}},{id='Incomplete',gear='Other',entries={{AssetId='C'}}}}end,
  Remotes={Codex={AskRedeemAll={InvokeServer=function()
   calls+=1;if outcome=='unknown'then error('network')end
   local rows={};for id in pairs(p.Index)do if not p.IndexClaimedCategories[id]then table.insert(rows,{Category=id})end end
   return true,nil,rows
  end},AskRedeemLimitedEgg={InvokeServer=function(_,id)assert(id=='LimitedEgg');collections+=1;p.GearInventory.Reward=1;return true end}}}}
 local function flush()local jobs=pending;pending={};for _,fn in ipairs(jobs)do fn()end end
 local r=factory()(d);assert(#pending==1,'initial check scheduled');flush()
 assert(calls==1 and p.IndexClaimedCategories.A and p.IndexClaimedCategories.B,'acknowledged categories applied')
 assert(collections==1,'complete limited collection claimed, incomplete skipped')
 signals.Index();signals.IndexClaimedCategories();signals.GearInventory();assert(#pending==1,'events coalesced');flush();assert(calls==1 and collections==1,'no repeated claims')
 p.Index.C=true;outcome='unknown';signals.Index();flush();assert(calls==2,'new discovery schedules claim')
 signals.Index();flush();assert(calls==2,'unknown outcome blocks resend')
 r.Destroy();r=factory()(d);flush();assert(calls==2,'reload preserves unknown reservation')
 p.IndexClaimedCategories.C=true;p.Index.D=true;d.Assets.Directory.D={};outcome='success';signals.Index();flush();assert(calls==3 and p.IndexClaimedCategories.D,'profile confirmation releases reservation for new discoveries')
 assert(not source:find('AskWearFieldBat',1,true),'no bat equipment remote')
 r.Destroy();assert(signals.Index==nil,'subscriptions cleaned up')
 return 'Index rewards passed: startup, event coalescing, discovery eligibility, acknowledgements, complete/owned/empty collections, uncertain-result and reload deduplication, cleanup; no bat equipment.'
end

