# SEA_V2

## Scripts

- `Scripts/Observer.lua`: passive observer based on Sae/TestV2.lua. No GUI, icon, automatic teleportation or remote code execution. Reports egg snapshots and changes, players, speed and income to the existing Render WebSocket protocol.
- `Scripts/Hub.lua`: unchanged copy of Sae/Test.lua.
- `Scripts/Admin.lua`: new lifecycle foundation with `SetEnabled`, `GetStatus` and `Destroy`. No administrative commands or remote execution are enabled yet.

`Loaders/Observer.lua`, `Loaders/Hub.lua` and `Loaders/Admin.lua` load the corresponding scripts from this repository.

Observer and Hub replace the previous AutoSAE controller on the same client. Admin uses a separate controller.

## Render access

The dashboard password belongs exclusively in Render's `SECRET_MDP` environment variable. It must never be embedded in scripts, loaders, GitHub files, or browser JavaScript. Observers and Hub keep the existing reporter protocol; the dashboard login does not authenticate game clients.
