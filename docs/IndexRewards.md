# Always-on Index rewards

Hub and headless Admin initialize `IndexRewards.lua` from their shared inventory runtime. There is no setting or GUI, and reward checks do not depend on the AUTO switch. Observer remains passive.

The module checks once on startup, then coalesces changes to `Save.Index`, `IndexClaimedCategories`, and `GearInventory` with a one-second delay. It uses the same `Codex.AskRedeemAll` contract as IndexController for discovered species whose reward has not been claimed. Returned category acknowledgements are applied through Save.Amend as in the native controller. No periodic remote polling is added.

Completed limited collections are checked against their current data entries and owned reward gear: Extinction/LimitedEgg, BrainrotEgg, MonsterEgg, live LuminousEgg, and DrScramble during its laboratory window. Their native `AskRedeemLimitedEgg` request is issued once per collection per player/server session. Empty, incomplete and already-owned rewards are skipped. Area bats are excluded entirely; no bat-equipment request is made.

Requests are serialized across runtime reloads using a shared per-player/server ledger. Uncertain species batches remain reserved until the profile confirms all requested categories. Uncertain collection requests are not retried automatically. Refusals and diagnostics remain local and never enter FLIGHT_RESULT logs. Destroying the runtime removes event subscriptions.

`tests/IndexRewards.spec.lua` uses only mock remotes. No real reward or inventory change is performed by verification.

