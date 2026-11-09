return function(source,engine,entry)
 local jobs,results={},{};local now=0;local allow=false;local attempts=0;local ends=0
 local ctx={LocalOnly=true,Report={SessionId='hub',SettingsAllowed=false,Ready=false},Ready=function()return true end,
  OnResult=function(m)table.insert(results,m)end,BeginManual=function()return allow end,
  EndManual=function()ends+=1 end,MutationLock=function()end}
 local state={}
 local env=setmetatable({shared=state,game={GetService=function(_,name)return name=='Players'and{LocalPlayer={UserId=42}}or{}end},
  os={clock=function()return now end},task={spawn=function(fn)table.insert(jobs,fn)end,wait=function(n)now+=n or .1 end}},{__index=getfenv()})
 local f=assert(loadstring(source));setfenv(f,env);local runtime=f()(ctx)
 assert(ctx.Report.AdminReceive==nil,'Hub never installs a remote Admin receiver')
 jobs={};runtime.Initialized=true
 runtime.Execute=function()attempts+=1;return true end
 runtime.Snapshot=function()error('Local Publish must not construct or send an Admin snapshot')end
 assert(runtime.Publish(true)==false,'Hub inventory stays local')
 runtime.Receive({version=1,requestId='wait',action='egg.place',uid='e'})
 assert(#jobs==1 and attempts==0,'manual action queued while AUTO continues')
 table.remove(jobs,1)()
 assert(attempts==0 and results[1].status=='rejected','flight priority prevents dispatch')
 assert(not runtime.Busy and state.__SEAAdminRequestLock==nil,'pending lock released after timeout')
 allow=true
 runtime.Receive({version=1,requestId='go',action='egg.place',uid='e'})
 table.remove(jobs,1)()
 assert(attempts==1 and results[2].status=='confirmed','offline local action works without Render authorization')
 runtime.Receive({version=1,requestId='go',action='egg.place',uid='e'})
 assert(attempts==1 and #jobs==0,'duplicate request never dispatches twice')
 assert(engine:find('if FusionModules.Reporting.ClientKind~="admin" then return false end',1,true),'Hub rejects server hopping')
 assert(engine:find('SEA_Hub_',1,true),'local files scoped to player')
 assert(entry:find('ctx.LocalOnly=true',1,true)and entry:find('engine.SetEnabled(true)',1,true),'local runtime and AUTO startup')
 return 'Hub local bridge passed: no remote receiver/snapshot; offline commands; flight priority; lock cleanup; duplicate suppression; local player settings and AUTO startup.'
end

