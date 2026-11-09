return function(hub)
 local function section(a,b)local i=assert(hub:find(a,1,true));local j=assert(hub:find(b,i,true));return hub:sub(i,j-1)end
 local fm={Options={AutoHelp=true,AutoHelpMin=2e9,AutoEggsMin=10e9,HelpFavorites="Other, CAYLUS298878",AutoEggs=true},Reporting={ClientKind="admin"},Helpers={IsAlwaysEligibleRarity=function(r)return r.divine end}}
 local me={Name="MagixSafe"};local friend={Name="caylus298878"};local peers={me,friend};local profile={Index={Cat=true}}
 local carry={IsCarrying=true,Uid="egg"};local field={State="Dropped",BottomCFrame=CFrame.new(5,0,5)};local sent=0;local position=Vector3.new(5,0,5)
 local bounds={Position=position,IsA=function(_,c)return c=="BasePart"end}
 local function folder(name,child)return{FindFirstChild=function(_,n)if n==name then return child end end}end
 local world=folder("World",folder("Areas",folder("GuardAreas",folder("Forest",folder("Bounds",bounds)))))
 local env={FusionModules=fm,shared={},game={JobId="job"},Workspace=world,Players={GetPlayers=function()return peers end},player=me,Save={Peek=function()return profile end},getRatePerSecond=function(r)return r.rate end,getCharacterParts=function()return nil,{HipHeight=2},{Position=position}end,queuedEggs={},cooldowns={},syncQueue=function()end,validCycle=function()return true end,readCarry=function()return carry end,isSafe=function()return false end,distanceXZ=function(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end,getRecordPosition=function(r)return r.BottomCFrame.Position end,readField=function()return field,true end,CONFIG={RequestTimeout=1},task={spawn=function(fn)fn()end},RunService={Heartbeat={Wait=function()end}},executorTools={SaveSettings=function()end},setStatus=function()end,EggState={DropFieldEgg=function(reason)assert(reason=="PlayerRequest");sent+=1;carry={IsCarrying=false};return true end}}
 local f=assert(loadstring(section("-- Help favorites only authorize assistance", "local function runCycle(")));setfenv(f,setmetatable(env,{__index=getfenv()}));f()
 local egg={Uid="egg",AssetCategory="Cat",rate=2e9}
 assert(fm.Help.Eligible(egg),"inclusive help minimum")
 egg.rate=10e9;assert(not fm.Help.Eligible(egg),"exclusive Admin minimum")
 egg.rate=2e9-1;assert(not fm.Help.Eligible(egg));egg.rate=5e9
 profile.Index.Cat=nil;assert(not fm.Help.Eligible(egg),"missing species reserved even without Index toggle");profile.Index.Cat=true
 peers={me};assert(not fm.Help.Eligible(egg),"favorite must share this server");peers={me,friend}
 fm.Reporting.ClientKind="hub";assert(not fm.Help.Eligible(egg),"Hub cannot help");fm.Reporting.ClientKind="admin"
 egg.divine=true;assert(not fm.Help.Eligible(egg),"normal rarity priority");egg.divine=false
 peers={me} -- A departure during transport never cancels the deposit.
 assert(fm.Help.Deposit({uid="egg"},position));assert(sent==1 and fm.Help.WasDelivered("egg"))
 peers={me,friend};assert(not fm.Help.Eligible(egg),"delivered UID never recollected")
 assert(fm.Help.Destination()==position+Vector3.new(0,4,0),"Forest Bounds center, not decorative model pivot")
 local comparator=assert(loadstring(section("function FusionModules.Helpers.QueueBefore", "local function queueOrder()")));setfenv(comparator,setmetatable(env,{__index=getfenv()}));comparator()
 fm.Options.QueueNearest=true
 assert(fm.Helpers.QueueBefore({Uid="a",Source="AUTO",Rate=1,Distance=100},{Uid="b",Source="HELP",Rate=9,Distance=1}),"normal beats help even with nearest sorting")
 -- Exercise the full help branch: carry -> Forest -> native drop -> empty return home.
 local moves={};env.queuedEggs={route={Source="HELP"}};env.generation=1
 env.getStartAreaDestination=function()return Vector3.new(0,0,0)end
 env.isSafe=function(point)return point.X==0 end
 env.getCharacterParts=function()return me,{HipHeight=2},{Position=position}end
 env.measureAction=function(_,fn,...)return fn(...)end
 env.getAnimalName=function()return "Cat"end;env.formatNumber=tostring;env.log=function()end
 fm.Helpers.ownerSnapshot=function()return{}end;fm.Helpers.formatPosition=tostring;fm.Helpers.DescribeEgg=function()return "Cat"end
 env.moveThenCarry=function()peers={me};return true end
 env.moveReturnLoop=function(_,target)table.insert(moves,target);position=target;return true end
 env.recordFlightResult=function(_,ok)env.succeeded=ok end;env.cleanupCycle=function()end
 position=Vector3.new(0,0,0);carry={IsCarrying=true,Uid="route"};field={State="Dropped",BottomCFrame=CFrame.new(5,0,5)}
 local run=assert(loadstring(section("local function runCycle(","local function ingest(").."\nreturn runCycle"));setfenv(run,setmetatable(env,{__index=getfenv()}));run=run()
 assert(run({Uid="route",AssetCategory="Cat",BottomCFrame=CFrame.new(5,0,5)},5e9,false,nil))
 assert(env.succeeded and #moves==2 and moves[1].X==5 and moves[2].X==0,"finish Forest delivery despite favorite departure, then return empty")
 return "Help policy passed: boundaries, same-server favorites, Admin-only, index and normal priority, Forest center, confirmed native drop, friend departure, delivered UID exclusion. No live egg moved."
end

