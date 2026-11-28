return function(source)
 assert(source:find('local RELOAD_GUI_NAME="SEAAdminReloadGui"',1,true),'Reload GUI needs a stable unique name')
 assert(source:find('Instance.new("ScreenGui")',1,true),'Reload must be exposed through a ScreenGui')
 assert(source:find('Instance.new("TextButton")',1,true),'Reload GUI must contain its single button')
 assert(source:find('gui.ResetOnSpawn=false',1,true),'Reload GUI must survive character respawns')
 assert(source:find('button.Text="Reload"',1,true),'Reload button label is missing')
 local fetch=assert(source:find('game:HttpGet(ADMIN_SOURCE_URL)',1,true))
 local compile=assert(source:find('loadstring(source,"SEA_V2/Admin")',fetch,true))
 local destroy=assert(source:find('pcall(Admin.Destroy,true)',compile,true))
 local restart=assert(source:find('pcall(latest)',destroy,true))
 assert(fetch<compile and compile<destroy and destroy<restart,'Latest source must be fetched and compiled before stopping the current Admin')
 assert(source:find('if not ok then warn("[SEA Reload] Redemarrage impossible',restart,true),'A failed restart must keep the Reload button available')
 return 'Admin reload passed: one persistent button, prepare-first update and retry-safe restart.'
end
