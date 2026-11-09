# SEA_V2

## Scripts

- `Scripts/Observer.lua`: passive observer based on Sae/TestV2.lua. No GUI, icon, automatic teleportation or remote code execution. Owns egg/player collection, metadata, event subscriptions, snapshots and the shared WebSocket. Reports egg/player changes and remains passive.
- `Scripts/Hub.lua`: stable Hub entry. Starts the shared gameplay engine, the local inventory runtime and `HubUI.lua` (SEA HUB).
- `Scripts/GameplayEngine.lua`: the existing Admin gameplay engine, shared with Hub. Headless; no embedded legacy GUI. Hub explicitly refuses both random server search and Render teleport requests.
- `Scripts/HubUI.lua`: interface based on the approved Studio ScreenGui. Serveur (current server only), Mes Œufs (Placés/Backpack), Mes Animaux (Équipés/Backpack), Mutations, Paramètres and local Vols. Cards sort by decreasing income. Separate AUTO ON/OFF and draggable mouse/touch reopen button.
- `Scripts/Admin.lua`: background Admin bootstrap. Reuses the Hub game engine without constructing its interface, starts AUTO ON and loads the typed `AdminRuntime.lua` bridge.

`Loaders/Observer.lua`, `Loaders/Hub.lua` and `Loaders/Admin.lua` load the corresponding scripts from this repository.

Hub and Admin automatically start/reuse the singleton Observer. Observer has its own lifecycle and never destroys the game engine. Hub/Admin replace only the previous game engine, subscribe to Observer messages and share its one WebSocket. Closing a Hub/Admin releases the observer to passive mode. Admin creates no ScreenGui, icon or Roblox controls.

## Logging policy for current and future scripts

Only terminal `FLIGHT_RESULT` events belong in remote log batches. Detailed diagnostic logs stay local; they must not enqueue a remote batch or schedule a network send. An empty log queue must never produce a log message. Egg/player observations and admin settings use their existing, separate deduplicated messages.

## Render access

The dashboard password belongs exclusively in Render's `SECRET_MDP` environment variable. It must never be embedded in scripts, loaders, GitHub files, or browser JavaScript. Observers and Hub keep the existing reporter protocol; the dashboard login does not authenticate game clients.

Render defaults `ADMIN_USERNAME` to `MagixSafe`; its server card is shown first in gold regardless of which script reports it. Only the configured Admin.lua receives GO/auto requests and reports FLIGHT_RESULT logs. Client-declared identity is not proof of Roblox account ownership.

## Admin panel

Render provides Mes Œufs (plot/backpack), Mes Animaux (plot/backpack), and Paramètres. AdminRuntime sends changed inventory/player metrics at most once per five seconds, with a twenty-second freshness heartbeat. Snapshot arrays are always JSON arrays. Existing egg/player reporting is preserved.

Metrics use Save.Money, SpeedPowerProjection.ReadProjected, AssetItems.ProfileIncomePerSecond and the exact OfflineMoneyInPlotUIController formula: income × Constants.OFFLINE_ASSETS.MAX_DURATION_SECONDS × MONEY_RATE_MULTIPLIER (read live, never a hardcoded daily estimate).

Opening, selling, placing, fusing three selected backpack animals, and equipping best use the game APIs. Manual inventory actions are allowed while AUTO remains on and wait for the priority collection boundary. Placement and mutations require being in your plot; fusion uses normal pathfinding to reach the machine. Server refusals and uncertain results are surfaced without automatic retries. A shared action lock prevents overlapping operations across script reloads. Mutations support a minimum placed-egg income, limited attempts, and a stock-selection popup.

Hub starts AUTO ON with saved options. Hub settings and local logs are scoped by Roblox user ID (`SEA_Hub_<userId>_settings.json` / `_debug.txt`); saving requires the environment's file APIs. Admin retains its existing settings path. Hub's inventory bridge is local-only: it installs no Admin message receiver and sends no Admin inventory snapshots. It continues to share Observer's deduplicated data transport. Help favorites, player statistics, image collection, fishing and automatic crafting are excluded from Hub. Existing loaders remain unchanged.

Collecte includes `AutoEggsMaxBiome`, selected from the native biome progression list (Forest through Aliens); `All` is the default. The chosen biome and all earlier biomes are allowed for automatic income, missing-index, rarity and help candidates. Unknown areas are rejected when a limit is selected. Manual collection and explicit GO remain exempt; a flight already underway can finish safely. Changing the limit removes ineligible pending automatic entries. Admin's automatic destination planner enforces the same limit on Render.

Parameter changes use the same toggles/ranges as Hub, validate both on Render and in Lua and persist via the existing settings mechanism. The global AUTO switch is reported separately from teleport eligibility. No arbitrary Lua command is accepted. End-to-end gameplay requires launching Admin.lua on the configured account; syntax, mock runtime, transport and UI tests do not imply a live sale/fusion occurred.

Observer.Configure binds the shared transport to the active hub/admin role without adding game actions to Observer. Role ownership prevents an old controller from resetting a newer session; reconnect serials discard stale connections. Admin.lua starts Observer explicitly and Hub reuses it. Loaders are unchanged.

Cards in Admin reuse Servers artwork/rarity/metric layout without roster, GO, server-egg expansion or detail sections. Mutations are shown above item names in both tabs and omitted when absent.

