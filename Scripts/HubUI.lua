-- SEA HUB: local interface derived from the approved Studio ScreenGui.
-- Inventory transactions use the same typed runtime as Admin; no remote GUI commands.
return function(engine,runtime)
 local Players=game:GetService('Players')
 local UIS=game:GetService('UserInputService')
 local Http=game:GetService('HttpService')
 local player=Players.LocalPlayer
 local U={Destroyed=false,Connections={},Selected={},FuseSelected={}}
 local theme={bg=Color3.fromRGB(12,18,28),card=Color3.fromRGB(22,32,48),button=Color3.fromRGB(32,46,66),text=Color3.fromRGB(233,240,255),muted=Color3.fromRGB(159,180,210),lime=Color3.fromRGB(181,255,107),gold=Color3.fromRGB(255,200,75)}
 local function make(class,name,parent,props)
  local x=Instance.new(class);x.Name=name;for k,v in pairs(props or{})do x[k]=v end;x.Parent=parent;return x
 end
 local function connect(signal,fn)local c=signal:Connect(fn);table.insert(U.Connections,c);return c end
 local function corner(x)make('UICorner','Corner',x,{CornerRadius=UDim.new(0,10)})end
 local function text(p,name,value,pos,size,font,color)
  return make('TextLabel',name,p,{Text=value,Position=pos or UDim2.new(),Size=size or UDim2.new(1,0,0,28),BackgroundTransparency=1,TextColor3=color or theme.text,Font=font or Enum.Font.Gotham,TextSize=20,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
 end
 local function button(p,name,value,pos,size,fn)
  local b=make('TextButton',name,p,{Text=value,Position=pos or UDim2.new(),Size=size or UDim2.fromOffset(170,48),BackgroundColor3=theme.button,TextColor3=theme.text,Font=Enum.Font.GothamMedium,TextSize=20,AutoButtonColor=true});corner(b)
  if fn then b.Activated:Connect(fn)end;return b
 end
 local function active(b,yes)b.BackgroundColor3=yes and theme.lime or theme.button;b.TextColor3=yes and theme.bg or theme.text end
 local gui=make('ScreenGui','SEA_Hub',player:WaitForChild('PlayerGui'),{DisplayOrder=10000,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false})
 U.Gui=gui
 local main=make('Frame','Window',gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1360,900),BackgroundColor3=theme.bg,ClipsDescendants=true});corner(main)
 local scale=make('UIScale','ViewportScale',main,{Scale=1})
 text(main,'Title','SEA HUB',UDim2.fromOffset(24,16),UDim2.fromOffset(260,40),Enum.Font.GothamBold).TextSize=26
 local auto=button(main,'Auto','AUTO ON',UDim2.new(1,-240,0,16),UDim2.fromOffset(144,48),function()engine.SetEnabled(not engine.IsEnabled())end)
 local reopen=button(gui,'Reopen','SEA',UDim2.fromOffset(18,250),UDim2.fromOffset(76,76));reopen.Visible=false;active(reopen,true)
 button(main,'Minimize','—',UDim2.new(1,-80,0,16),UDim2.fromOffset(56,48),function()main.Visible=false;reopen.Visible=true end)
 local function resize()
  local camera=workspace.CurrentCamera;if not camera then return end
  local v=camera.ViewportSize;scale.Scale=math.min(1,v.X*.96/1360,(v.Y-40)*.94/900)
 end
 resize();connect(workspace:GetPropertyChangedSignal('CurrentCamera'),resize)
 if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'),resize)end
 local drag,start,origin,moved
 connect(reopen.InputBegan,function(i)
  if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=i;start=i.Position;origin=reopen.Position;moved=false end
 end)
 connect(UIS.InputChanged,function(i)
  if drag and(i==drag or i.UserInputType==Enum.UserInputType.MouseMovement)then
   local d=i.Position-start;if d.Magnitude>6 then moved=true end
   if moved then local v=workspace.CurrentCamera.ViewportSize;reopen.Position=UDim2.fromOffset(math.clamp(origin.X.Offset+d.X,0,math.max(0,v.X-76)),math.clamp(origin.Y.Offset+d.Y,0,math.max(0,v.Y-116)))end
  end
 end)
 connect(UIS.InputEnded,function(i)if i==drag then drag=nil;if not moved then main.Visible=true;reopen.Visible=false end end end)
 connect(reopen.Activated,function()if not moved then main.Visible=true;reopen.Visible=false end end)
 local tabs=make('ScrollingFrame','Tabs',main,{Position=UDim2.fromOffset(20,82),Size=UDim2.new(1,-40,0,56),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X})
 make('UIListLayout','Layout',tabs,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 local status=text(main,'Status','Chargement…',UDim2.fromOffset(22,145),UDim2.new(1,-44,0,48),nil,theme.muted);status.TextSize=17
 local body=make('ScrollingFrame','Content',main,{Position=UDim2.fromOffset(20,202),Size=UDim2.new(1,-40,1,-220),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
 local page='Serveur';local sub='Placés';local category='Collecte';local signature;local render
 local function invalidate()signature=nil end
 local function notify(value)U.Notice=tostring(value):sub(1,300);U.NoticeAt=os.clock();invalidate()end
 function U.Result(r)notify(r.message);U.Pending=nil end
 local function command(action,values)
  if U.Pending then notify('Une action est déjà en attente');return end
  local m=values or{};m.version=1;m.action=action;m.requestId=Http:GenerateGUID(false)
  U.Pending=m.requestId;notify('Action en attente • priorité aux œufs éligibles');runtime.Receive(m)
 end
 local function clear()for _,x in body:GetChildren()do x:Destroy()end end
 local function topbar(entries,selected,callback)
  local bar=make('Frame','Subtabs',body,{Size=UDim2.new(1,-6,0,56),BackgroundTransparency=1})
  make('UIListLayout','Layout',bar,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
  for i,entry in ipairs(entries)do local b=button(bar,'Tab'..i,entry.label or entry,UDim2.new(),UDim2.fromOffset(entry.width or 190,48),function()callback(entry.id or entry)end);b.LayoutOrder=i;active(b,selected==(entry.id or entry))end
  return bar
 end
 local function grid(y)
  local f=make('Frame','Cards',body,{Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,-8,0,0),BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y})
  make('UIGridLayout','Layout',f,{CellSize=UDim2.new(1/3,-10,0,430),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder});return f
 end
 local suffixes={'','K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'}
 local function format(n)
  if type(n)~='number'then return '—'end
  local i=1;while math.abs(n)>=1000 and i<#suffixes do n/=1000;i+=1 end
  return string.format('%.2f',n):gsub('%.00$','')..suffixes[i]
 end
 local function parse(s)
  s=s:gsub('%s',''):gsub(',','.')
  local num,suf=s:match('^(%d*%.?%d+)(%a*)$');num=tonumber(num)
  if not num then return nil end
  for i,v in ipairs(suffixes)do if v:lower()==suf:lower()then local n=num*1000^(i-1);return n<math.huge and n or nil end end
 end
 local function remaining(n)
  if type(n)~='number'then return '—'end
  if n<=0 then return 'Prêt à ouvrir'end
  return string.format('%dh %02dm %02ds',math.floor(n/3600),math.floor(n/60)%60,math.floor(n)%60)
 end
 local rarities={Cosmic=Color3.fromRGB(139,173,255),Eternal=Color3.fromRGB(255,127,210),Divine=theme.gold,Secret=Color3.fromRGB(180,145,255)}
 local function sort(rows)table.sort(rows,function(a,b)local x,y=a.incomePerSecond or -1,b.incomePerSecond or -1;if x~=y then return x>y end;return a.uid<b.uid end);return rows end
 local function mutations(r)
  local a={};if r.baseMutation and r.baseMutation~='Normal'and r.baseMutation~='None'then table.insert(a,r.baseMutation)end
  for _,v in ipairs(r.mutations or{})do if not table.find(a,v)then table.insert(a,v)end end
  return table.concat(a,' · ')
 end
 local function mutationPopup(r,data)
  local old=gui:FindFirstChild('MutationPopup');if old then old:Destroy()end
  local shade=make('Frame','MutationPopup',gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.3,ZIndex=10})
  local box=make('Frame','Dialog',shade,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(660,620),BackgroundColor3=theme.bg,ZIndex=11});corner(box)
  make('UIScale','Scale',box,{Scale=scale.Scale})
  text(box,'Title','Ajouter une mutation · '..r.name,UDim2.fromOffset(20,16),UDim2.new(1,-90,0,60),Enum.Font.GothamBold).ZIndex=12
  button(box,'Close','×',UDim2.new(1,-66,0,16),UDim2.fromOffset(46,46),function()shade:Destroy()end).ZIndex=12
  local list=make('ScrollingFrame','List',box,{Position=UDim2.fromOffset(20,92),Size=UDim2.new(1,-40,1,-110),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ZIndex=12})
  make('UIListLayout','Layout',list,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
  for i,m in ipairs(data.mutationConsumables or{})do
   local present=r.baseMutation==m.id or table.find(r.mutations or{},m.id)~=nil
   local b=button(list,m.id,m.name..' · '..m.count..' disponible(s) · '..(m.successPercent and m.successPercent..'%'or'—')..(present and' · déjà présente'or''),nil,UDim2.new(1,-8,0,62),function()
    if present or m.count<1 then return end
    shade:Destroy();command('egg.mutate',{uid=r.uid,mutationId=m.id})
   end);b.LayoutOrder=i;b.ZIndex=13;b.TextTransparency=(present or m.count<1)and .5 or 0
  end
 end
 local function cards(rows,kind,data)
  local f=grid(68)
  if #rows==0 then text(body,'Empty','Aucun élément disponible.',UDim2.fromOffset(10,84),UDim2.new(1,-20,0,40),nil,theme.muted)end
  for i,r in ipairs(sort(rows))do
   local frame=make('Frame','Item_'..r.uid,f,{BackgroundColor3=theme.card,LayoutOrder=i});corner(frame)
   make('Frame','Accent',frame,{Size=UDim2.new(1,0,0,4),BackgroundColor3=rarities[r.rarity]or theme.muted,BorderSizePixel=0})
   text(frame,'Rarity',tostring(r.rarity):upper(),UDim2.fromOffset(16,14),UDim2.new(1,-32,0,24),nil,theme.muted)
   text(frame,'Mutations',mutations(r),UDim2.fromOffset(16,44),UDim2.new(1,-32,0,26),nil,theme.gold)
   text(frame,'Name',r.name,UDim2.fromOffset(16,76),UDim2.new(1,-32,0,48),Enum.Font.GothamBold)
   local id=kind=='animal'and r.animalImageAssetId or r.eggImageAssetId
   make('ImageLabel','Image',frame,{Position=UDim2.new(.5,-62,0,126),Size=UDim2.fromOffset(124,100),BackgroundTransparency=1,Image=id and('rbxassetid://'..id)or'',ScaleType=Enum.ScaleType.Fit})
   text(frame,'Income','Revenu /s : '..format(r.incomePerSecond),UDim2.fromOffset(16,234),UDim2.new(1,-32,0,26),Enum.Font.GothamBold)
   text(frame,'Weight','Poids : '..format(r.weightKg)..' kg',UDim2.fromOffset(16,264),UDim2.new(1,-32,0,26),nil,theme.muted)
   text(frame,'Value','Valeur : '..format(r.sellValue),UDim2.fromOffset(16,294),UDim2.new(1,-32,0,26),nil,theme.muted)
   local place=kind=='egg'and r.location=='plot'and remaining(r.remainingSeconds)or r.location=='plot'and'Équipé'or r.location=='field'and'Serveur actuel'or'Backpack'
   text(frame,'Location',place,UDim2.fromOffset(16,324),UDim2.new(1,-32,0,26),nil,theme.muted)
   local function action(n,label,fn)local b=button(frame,'Action'..n,label,UDim2.new((n-1)*.5,10,1,-60),UDim2.new(.5,-15,0,48),fn);return b end
   if kind=='field'then
    local b=action(1,U.Selected[r.uid]and'Sélectionné'or'Sélectionner',function()U.Selected[r.uid]=not U.Selected[r.uid]or nil;invalidate()end);active(b,U.Selected[r.uid])
    action(2,'Collecter',function()if engine.Collect({r.uid})then notify('Œuf ajouté à la file locale')else notify('Œuf indisponible ou déjà en file')end end)
   elseif kind=='egg'and r.location=='plot'then
    local b=action(1,'Ouvrir',function()if r.ready then command('egg.open',{uid=r.uid})end end);b.TextTransparency=r.ready and 0 or .5
    action(2,'Mutation',function()mutationPopup(r,data)end)
   elseif r.location=='backpack'then
    action(1,'Vendre',function()command(kind..'.sell',{uid=r.uid})end)
    if kind=='egg'then action(2,'Placer',function()command('egg.place',{uid=r.uid})end)
    else local b=action(2,U.FuseSelected[r.uid]and'Sélectionné'or'Fusionner',function()if not r.locked then U.FuseSelected[r.uid]=not U.FuseSelected[r.uid]or nil;invalidate()end end);active(b,U.FuseSelected[r.uid])end
   end
  end
 end
 local mutationIcons={Boss='74755693699202',Scrambled='134710848063255',Enchanted='73528861998418',Nitro='134287739122547',Spectral='108054256583165',Musical='103734535097504',Alien='99395515128275',DarkMatter='93377699933947'}
 local function renderMutations(data)
  local list=make('Frame','MutationStock',body,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
  make('UIListLayout','Layout',list,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
  for i,m in ipairs(data.mutationConsumables or{})do
   local row=make('Frame',m.id,list,{Size=UDim2.new(1,0,0,92),BackgroundColor3=theme.card,LayoutOrder=i});corner(row)
   make('ImageLabel','Icon',row,{Position=UDim2.fromOffset(12,10),Size=UDim2.fromOffset(72,72),BackgroundTransparency=1,Image='rbxassetid://'..(mutationIcons[m.id]or'')})
   text(row,'Name',m.name,UDim2.fromOffset(100,12),UDim2.new(1,-116,0,28),Enum.Font.GothamBold)
   text(row,'Stock','Stock : '..m.count..'     Réussite : '..(m.successPercent and m.successPercent..'%'or'—')..'     Multiplicateur : '..(m.multiplier and'×'..format(m.multiplier)or'—'),UDim2.fromOffset(100,48),UDim2.new(1,-116,0,28),nil,theme.muted)
  end
 end
 local groups={
  Collecte={{'AutoEggs','Collecte automatique (y compris manquants)'},{'AutoEggsMin','Minimum /s'},{'AutoEggsMax','Maximum /s'},{'AutoIndex','Manquants dans l’index : collecte, protection vente et placement hors seuils'},{'QueueNearest','Tri : plus proche (OFF = revenu décroissant)'}},
  ['Déplacement']={{'AutoTreadmill','Tapis automatique'},{'AutoPapillon','Papillons automatiques'}},
  Vente={{'AutoSell','Vente automatique des œufs du backpack'},{'AutoSellMin','Œufs • minimum /s'},{'AutoSellMax','Œufs • maximum /s'},{'AutoSellAnimals','Vente automatique des animaux du backpack'},{'AutoSellAnimalsMin','Animaux • minimum /s'},{'AutoSellAnimalsMax','Animaux • maximum /s'}},
  Fusion={{'AutoFuse','Fusion automatique'},{'AutoFuseMin','Minimum /s'},{'AutoFuseMax','Maximum /s'},{'AutoEquipBest','Équiper les meilleurs après modification de l’inventaire'}},
  Ouverture={{'AutoOpen','Ouverture automatique'},{'AutoOpenMin','Minimum /s'},{'AutoOpenMax','Maximum /s'}},
  Placement={{'AutoPlace','Placement automatique'},{'AutoPlaceMin','Minimum /s'},{'AutoPlaceMax','Maximum /s'}},
  Upgrades={{'AutoPlotUpgrade','Agrandissement automatique du plot'},{'AutoTreadmillUpgrade','Amélioration automatique du tapis'}}}
 local categories={'Collecte','Déplacement','Vente','Fusion','Ouverture','Placement','AutoMutations','Upgrades'}
 local draft,inputs
 local function renderSettings(data)
  local bar=make('Frame','Categories',body,{Size=UDim2.new(1,-8,0,120),BackgroundTransparency=1})
  make('UIGridLayout','Layout',bar,{CellSize=UDim2.new(.25,-8,0,48),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder})
  for i,n in ipairs(categories)do local b=button(bar,n,n,nil,nil,function()category=n;draft=nil;invalidate()end);b.LayoutOrder=i;active(b,category==n)end
  draft=draft or engine.AdminContext.GetOptions();inputs={}
  local list=make('Frame','Settings',body,{Position=UDim2.fromOffset(0,132),Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
  make('UIListLayout','Layout',list,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
  local specs=groups[category]
  if category=='AutoMutations'then
   specs={{'AutoMutations','Mutations automatiques • œufs placés'}}
   for _,m in ipairs(data.mutationConsumables or{})do local prefix='Mutation'..m.id
    table.insert(specs,{prefix..'Enabled',m.name..' • activer'})
    table.insert(specs,{prefix..'Min',m.name..' • revenu strictement supérieur à /s'})
    table.insert(specs,{prefix..'Attempts',m.name..' • essais maximum (1–100)'})
   end
  end
  for i,s in ipairs(specs or{})do
   local row=make('Frame',s[1],list,{Size=UDim2.new(1,0,0,62),BackgroundColor3=theme.card,LayoutOrder=i});corner(row)
   text(row,'Label',s[2],UDim2.fromOffset(16,8),UDim2.new(1,-300,1,-16))
   if type(draft[s[1]])=='boolean'then
    local b
    b=button(row,'Toggle',draft[s[1]]and'ON'or'OFF',UDim2.new(1,-180,0,7),UDim2.fromOffset(162,48),function()draft[s[1]]=not draft[s[1]];b.Text=draft[s[1]]and'ON'or'OFF';active(b,draft[s[1]])end);active(b,draft[s[1]])
   else
    local input=make('TextBox','Value',row,{Position=UDim2.new(1,-264,0,7),Size=UDim2.fromOffset(246,48),Text=format(draft[s[1]]),BackgroundColor3=theme.button,TextColor3=theme.text,Font=Enum.Font.Gotham,TextSize=20,ClearTextOnFocus=false});corner(input);inputs[s[1]]=input
   end
  end
  local save=button(list,'Save','Enregistrer localement',nil,UDim2.new(1,0,0,52),function()
   for key,input in pairs(inputs)do local value=parse(input.Text);if not value then notify('Valeur invalide : '..key);return end;draft[key]=value end
   if engine.AdminContext.SetOptions(draft)then draft=nil;notify('Paramètres appliqués • sauvegarde locale si disponible')else notify('Seuils invalides ou nombre d’essais hors limites')end
  end);save.LayoutOrder=1000
 end
 render=function(data)
  clear()
  if page=='Paramètres'then renderSettings(data);return end
  if page=='Mutations'then renderMutations(data);return end
  if page=='Vols'then
   make('UIListLayout','Layout',body,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
   local history=engine.FlightHistory()
   if #history==0 then text(body,'Empty','Aucun résultat de vol pour ce joueur.',nil,UDim2.new(1,-8,0,50),nil,theme.muted)end
   for i=#history,1,-1 do local r=history[i];local line=text(body,'Flight'..i,r.Text,nil,UDim2.new(1,-8,0,76),nil,r.Success and theme.lime or Color3.fromRGB(255,150,140));line.LayoutOrder=#history-i end
   return
  end
  if page=='Serveur'then
   local n=0;for _ in pairs(U.Selected)do n+=1 end
   button(body,'CollectSelected','Collecter la sélection ('..n..')',UDim2.new(),UDim2.fromOffset(390,48),function()
    local ids={};for id in pairs(U.Selected)do table.insert(ids,id)end
    if engine.Collect(ids)then table.clear(U.Selected);notify('Sélection ajoutée à la file locale')else notify('Aucun œuf disponible dans cette sélection')end
   end)
   cards(runtime.FieldSnapshot(),'field',data);return
  end
  local isEgg=page=='Mes Œufs'
  local place=isEgg and'Placés'or'Équipés'
  topbar({place,'Backpack'},sub,function(value)sub=value;invalidate()end)
  if not isEgg then
   button(body,'Best','Équiper les meilleurs',UDim2.new(1,-280,0,0),UDim2.fromOffset(270,48),function()command('equip.best')end)
   if sub=='Backpack'then
    local n=0;for _ in pairs(U.FuseSelected)do n+=1 end
    button(body,'Fuse','Fusionner ('..n..'/3)',UDim2.new(1,-530,0,0),UDim2.fromOffset(240,48),function()
     local ids={};for id in pairs(U.FuseSelected)do table.insert(ids,id)end
     if #ids~=3 then notify('Sélectionne exactement trois animaux compatibles');return end
     command('animal.fuse',{uids=ids});table.clear(U.FuseSelected)
    end)
   end
  end
  local rows={};for _,r in ipairs(isEgg and data.eggs or data.animals)do if r.location==(sub=='Backpack'and'backpack'or'plot')then table.insert(rows,r)end end
  cards(rows,isEgg and'egg'or'animal',data)
 end
 function U.Navigate(name,view)
  assert(table.find({'Serveur','Mes Œufs','Mes Animaux','Mutations','Paramètres','Vols'},name),'Onglet inconnu')
  page=name;sub=view or(name=='Mes Animaux'and'Équipés'or'Placés')
  if name=='Paramètres'and view and table.find(categories,view)then category=view end
  draft=nil;body.CanvasPosition=Vector2.zero;invalidate()
 end
 local tabButtons={}
 for i,n in ipairs({'Serveur','Mes Œufs','Mes Animaux','Mutations','Paramètres','Vols'})do
  local b=button(tabs,'Tab'..i,n,nil,UDim2.fromOffset(n=='Mes Animaux'and 196 or 174,50),function()
   U.Navigate(n)
  end);b.LayoutOrder=i;tabButtons[n]=b
 end
 function U.Destroy()
  if U.Destroyed then return end;U.Destroyed=true
  for _,c in ipairs(U.Connections)do c:Disconnect()end;table.clear(U.Connections)
  gui:Destroy()
 end
 task.spawn(function()
  while not U.Destroyed do
   local reset=engine.QueueResetVersion and engine.QueueResetVersion()or 0
   if U.QueueReset~=reset then U.QueueReset=reset;table.clear(U.Selected);invalidate()end
   active(auto,engine.IsEnabled());auto.Text=engine.IsEnabled()and'AUTO ON'or'AUTO OFF'
   for n,b in pairs(tabButtons)do active(b,page==n)end
   local connected=engine.Reporting.Ready and'Connecté'or'Connexion Observer…'
   local notice=U.Notice and os.clock()-(U.NoticeAt or 0)<12 and U.Notice
   status.Text=connected..' · '..(notice or engine.AdminContext.GetStatus())
   if runtime.Initialized and main.Visible then
    local ok,why=pcall(function()
     local data=runtime.Snapshot()
     -- Never rebuild an input form while the user is typing or editing its draft.
     local key=page=='Paramètres'and(page..category)or Http:JSONEncode({page=page,sub=sub,data=data,field=page=='Serveur'and runtime.FieldSnapshot()or nil,history=page=='Vols'and engine.FlightHistory()or nil,selected=U.Selected,fuse=U.FuseSelected})
     if key~=signature then render(data);signature=key end
    end)
    if not ok then status.Text='Interface : '..tostring(why):sub(1,220)end
   end
   task.wait(1)
  end
 end)
 return U
end

