# SEA_V2

## Scripts

- `Scripts/Observer.lua`: passive observer based on Sae/TestV2.lua. No GUI, icon, automatic teleportation or remote code execution. Reports egg snapshots and changes, players, speed and income to the existing Render WebSocket protocol.
- `Scripts/Hub.lua`: based on Sae/Test.lua; sends only FLIGHT_RESULT logs to Render.
- `Scripts/Admin.lua`: loads the maintained Hub engine without its full interface, announces the Admin role and exposes `SetEnabled`, `GetStatus` and `Destroy`. The configured `ADMIN_USERNAME` account receives targets and GO/auto teleport requests.

`Loaders/Observer.lua`, `Loaders/Hub.lua` and `Loaders/Admin.lua` load the corresponding scripts from this repository.

Observer, Hub and Admin replace the previous AutoSAE engine on the same client. Admin wraps that engine and relaunches its own loader after teleportation.

## Logging policy for current and future scripts

Only terminal `FLIGHT_RESULT` events belong in remote log batches. Detailed diagnostic logs stay local; they must not enqueue a remote batch or schedule a network send. An empty log queue must never produce a log message. Egg/player observations and admin settings use their existing, separate deduplicated messages.

## Render access

The dashboard password belongs exclusively in Render's `SECRET_MDP` environment variable. It must never be embedded in scripts, loaders, GitHub files, or browser JavaScript. Observers and Hub keep the existing reporter protocol; the dashboard login does not authenticate game clients.

Render defaults `ADMIN_USERNAME` to `MagixSafe`; set the environment variable to override it. Only this raw username using Admin.lua may send settings or FLIGHT_RESULT logs. A client-declared username/role is not proof of Roblox account ownership. Dashboard login remains separate.
