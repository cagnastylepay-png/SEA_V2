-- Always-on native Index rewards. No GUI, options, movement or bat equipment.
return function(d)
 local R={Destroyed=false,Connections={}}
 local player=game:GetService('Players').LocalPlayer
 local key=tostring(player.UserId)..':'..game.JobId
 shared.__SEAIndexRewardStates=shared.__SEAIndexRewardStates or{}
 local state=shared.__SEAIndexRewardStates[key]or{Attempts={},Reserved={}}
 shared.__SEAIndexRewardStates[key]=state
 local function profile()return d.Save.Peek()end
 local function settled()
  local p=profile();if not p then return false end
  for category in pairs(state.Reserved)do if not(p.IndexClaimedCategories and p.IndexClaimedCategories[category])then return false end end
  table.clear(state.Reserved);return true
 end
 local function candidates()
  local p=profile();local ids={}
  if not p then return ids end
  for category,found in pairs(p.Index or{})do
   if found==true and d.Assets.Directory[category]and not(p.IndexClaimedCategories or{})[category]then table.insert(ids,category)end
  end
  table.sort(ids);return ids
 end
 local function signature(ids)return table.concat(ids,'\0')end
 local function complete(spec,p)
  if not spec.gear or(p.GearInventory or{})[spec.gear]and p.GearInventory[spec.gear]>0 then return false end
  local seen={};local count=0
  for _,entry in ipairs(spec.entries or{})do
   local id=entry.AssetId
   if d.Assets.Directory[id]and not seen[id]then seen[id]=true;count+=1;if not(p.Index or{})[id]then return false end end
  end
  return count>0
 end
 function R.Run()
  if R.Destroyed or state.Busy then return end
  state.Busy=true
  local ok,why=pcall(function()
   local ids=candidates()
   if #ids>0 and settled()then
    local sig=signature(ids)
    if not state.Attempts['all:'..sig]then
     state.Attempts['all:'..sig]=true
     for _,id in ipairs(ids)do state.Reserved[id]=true end
     local called,accepted,reason,results=pcall(function()return d.Remotes.Codex.AskRedeemAll:InvokeServer()end)
     if called and accepted==true and type(results)=='table'then
      -- The native IndexController applies the returned category acknowledgements.
      for _,row in ipairs(results)do
       if type(row)=='table'and type(row.Category)=='string'and state.Reserved[row.Category]then
        d.Save.Amend('IndexClaimedCategories',function(claimed)claimed[row.Category]=true end)
       end
      end
      if not settled()then warn('[SEA Index] Récompenses partiellement confirmées : attente du profil, aucun renvoi')end
     elseif called and accepted==false then
      table.clear(state.Reserved);warn('[SEA Index] Refus : '..tostring(reason))
     else warn('[SEA Index] Résultat incertain : attente du profil, aucun renvoi')end
    end
   end
   local p=profile();if not p then return end
   for _,spec in ipairs(d.Collections and d.Collections()or{})do
    if R.Destroyed then return end
    local attempt='collection:'..spec.id
    if not state.Attempts[attempt]and complete(spec,p)then
     state.Attempts[attempt]=true
     local called,accepted,reason=pcall(function()return d.Remotes.Codex.AskRedeemLimitedEgg:InvokeServer(spec.id)end)
     if not called or accepted~=true then warn('[SEA Index] '..spec.id..' : '..tostring(reason or accepted)..' (aucune relance automatique)')end
     p=profile()or p
    end
   end
  end)
  state.Busy=false
  if not ok then warn('[SEA Index] '..tostring(why))end
 end
 function R.Schedule()
  if R.Destroyed or R.Queued then return end
  R.Queued=true
  task.delay(1,function()R.Queued=false;if not R.Destroyed then R.Run()end end)
 end
 function R.Destroy()R.Destroyed=true;for _,c in ipairs(R.Connections)do c:Disconnect()end end
 for _,field in ipairs({'Index','IndexClaimedCategories','GearInventory'})do
  local signal=d.Save.Watch(field);if signal then table.insert(R.Connections,signal:Connect(R.Schedule))end
 end
 R.Schedule()
 return R
end

