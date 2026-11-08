# SEA_V2

## Scripts

- `Scripts/Observer.lua`: passive observer based on Sae/TestV2.lua. No GUI, icon, automatic teleportation or remote code execution. Reports egg snapshots and changes, players, speed and income to the existing Render WebSocket protocol.
- `Scripts/Hub.lua`: based on Sae/Test.lua; sends only FLIGHT_RESULT logs to Render.
- `Scripts/Admin.lua`: TODO placeholder only. No gameplay, Hub bootstrap, network reporting or teleportation.

`Loaders/Observer.lua`, `Loaders/Hub.lua` and `Loaders/Admin.lua` load the corresponding scripts from this repository.

Observer and Hub replace the previous AutoSAE engine. Admin is a separate inactive placeholder.

## Logging policy for current and future scripts

Only terminal `FLIGHT_RESULT` events belong in remote log batches. Detailed diagnostic logs stay local; they must not enqueue a remote batch or schedule a network send. An empty log queue must never produce a log message. Egg/player observations and admin settings use their existing, separate deduplicated messages.

## Render access

The dashboard password belongs exclusively in Render's `SECRET_MDP` environment variable. It must never be embedded in scripts, loaders, GitHub files, or browser JavaScript. Observers and Hub keep the existing reporter protocol; the dashboard login does not authenticate game clients.

Render defaults `ADMIN_USERNAME` to `MagixSafe`; its server card is shown first in gold regardless of which script reports it. Admin commands and logging are reserved for the future Admin.lua implementation. Client-declared identity is not proof of Roblox account ownership.
