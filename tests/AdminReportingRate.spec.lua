return function(source)
 local first=assert(source:find(" function A.Publish(force)",1,true));local last=assert(source:find(" waitUntil=function",first,true))
 local now=0;local sends={};local timers={};local value=0;local socket={};local a={Initialized=true,Revision=0,Session="s",Snapshot=function()return{value=value}end}
 local ctx={Ready=function()return true end,Report={SettingsAllowed=true,Ready=true,Socket=socket}}
 local env=setmetatable({A=a,ctx=ctx,Http={JSONEncode=function(_,data)return tostring(data.value)end},send=function(m)table.insert(sends,{at=now,value=m.value});return true end,os={clock=function()return now end},task={delay=function(seconds,fn)table.insert(timers,{at=now+seconds,fn=fn})end}},{__index=getfenv()})
 local f=assert(loadstring(source:sub(first,last-1)));setfenv(f,env);f()
 local function advance(t)
  now=t
  for i=#timers,1,-1 do if timers[i].at<=now then local timer=table.remove(timers,i);timer.fn()end end
 end
 for i=0,100 do advance(i*.1);value=i;a.Publish(true)end
 assert(#sends<=6,"burst must produce at most one inventory every two seconds")
 for i=2,#sends do assert(sends[i].at-sends[i-1].at>=2)end
 advance(14);assert(sends[#sends].value==100,"deferred send contains the latest local state")
 local sent=#sends;advance(16);a.Publish(true);assert(#sends==sent,"forced duplicate snapshots stay deduplicated")
 ctx.Report.Socket={};a.Publish(false);assert(#sends==sent+1,"new connection immediately receives its own inventory")
 ctx.Report.Ready=false;value=101;advance(18);a.Publish(true);assert(#sends==sent+1,"offline connection sends nothing")
 assert(not source:find('"EquippedAssets","Money"',1,true),"high-frequency money watcher removed")
 return "Reporting rate passed: 100 local changes coalesced, two-second send ceiling, latest-state delivery, deduplication, immediate reconnect snapshot and no offline sends."
end

