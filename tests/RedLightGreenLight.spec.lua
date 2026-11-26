return function(source)
 local first=assert(source:find('redLightMovementBlocked = function(position)',1,true))
 local last=assert(source:find('local function validCycle(ctx)',first,true))
 local section=source:sub(first,last-1)
 local attributes={}
 local safe,arena=true,false
 local env=setmetatable({
  Workspace={GetAttribute=function(_,name)return attributes[name]end},
  isSafe=function()return safe end,
  FusionModules={Helpers={GameplayEntryAllowed=function()return arena end}},
 },{__index=getfenv()})
 local chunk=assert(loadstring(section));setfenv(chunk,env);chunk()
 local blocked=assert(env.redLightMovementBlocked)
 local position=Vector3.new()
 assert(not blocked(position),'an absent event never pauses movement')
 attributes.RLGL_Giant='giant';attributes.RLGL_Light='Green';safe=false;arena=true
 assert(not blocked(position),'Green keeps movement enabled')
 attributes.RLGL_Light='Red';safe=true
 assert(not blocked(position),'Red does not stop safe-zone movement')
 safe=false;arena=false
 assert(not blocked(position),'Red does not stop cave or lagoon movement outside the native theft field')
 arena=true
 assert(blocked(position),'Red pauses movement in the native theft field')
 assert(not section:find('RLGL_EggPosition',1,true),'movement pause must not depend on the event egg')
 assert(source:find('if not stopping and redLightMovementBlocked(root.Position)',1,true),'the common movement primitive is gated')
 assert(source:find('redLightMovementBlocked(root.Position)',source:find('shared.__AutoSAEController',1,true),true),'direct beta movement is gated')
 return 'Red Light Green Light passed: event presence and Red state pause every theft-field movement without consulting the event egg.'
end
