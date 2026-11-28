return function(source)
 local first=assert(source:find('local function getStartAreaDestination()',1,true))
 local last=assert(source:find('-- Help favorites only authorize assistance',first,true))
 local section=source:sub(first,last-1)..'\nreturn getStartAreaDestination, safeHomeName'
 local function folder(children)
  return {FindFirstChild=function(_,name)return children[name]end}
 end
 local function part(position)
  return {Position=position,IsA=function(_,class)return class=='BasePart'end}
 end
 local start=part(Vector3.new(10,20,30))
 local workspace=folder({World=folder({Areas=folder({StartArea=start})})})
 local fusion={AdminCollection=true}
 local env=setmetatable({Workspace=workspace,FusionModules=fusion,getCharacterParts=function()return{}, {HipHeight=3}, {}end},{__index=getfenv()})
 local chunk=assert(loadstring(section));setfenv(chunk,env)
 local destination,name=chunk()
 assert(destination()==Vector3.new(10,25,30),'Admin safe home must be the StartArea center')
 assert(name()=='StartArea','Admin destination label must match StartArea')
 fusion.AdminCollection=false
 assert(destination()==Vector3.new(10,25,30),'non-Admin clients keep StartArea')
 assert(name()=='StartArea','non-Admin destination label remains StartArea')
 fusion.AdminCollection=true;workspace=folder({World=folder({Areas=folder({})})});env.Workspace=workspace
 local missing,reason=destination();assert(missing==nil and tostring(reason):find('StartArea',1,true),'Admin must fail closed when StartArea is absent')
 return 'Admin safe home passed: outbound and return routes use the StartArea center.'
end
