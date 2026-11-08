# Admin mutations

AdminRuntime reports the five supported mutation consumables from Backpack and Character. Counts use the native Tool `Uses` attribute; chance flags and `EarningsScalar` come from the game's modules, without guessed fallbacks.

AutoMutations defaults OFF. Each mutation has an enabled switch, a minimum income per second, and an integer attempt cap from 1 to 100. Only owned placed eggs with income strictly greater than the threshold and without that mutation qualify. Highest-income eggs are checked first during plot maintenance, before automatic hatching. One request is made at a time, at least 15 seconds apart. Field collection retains its existing priority.

The runtime equips the matching native consumable and calls the game's `BossMastery.AskUseMutationConsumable` with the owned egg UID. A success requires the server result and the mutation appearing in replicated egg data. A confirmed failed roll counts as an attempt; an uncertain/rejected request blocks further attempts for that egg/mutation pair. The equipped consumable is released after the action.

Attempts are reserved before dispatch in the user-scoped `SEAAdminMutationAttempts` TeleportSetting. This survives script reloads and teleports in the same Roblox client, not a full application restart. No automatic counter reset is performed. A manual popup click explicitly requests one additional attempt, independent of the automatic income threshold/cap, but cannot repeat a previously uncertain request. Manual actions require AUTO OFF.

Render validates inventory ownership, stock, missing mutations, request identity and snapshot freshness. Results distinguish applied mutations from failed rolls. Admin has no in-game GUI. No arbitrary Lua execution is accepted.

Verification: Render tests cover settings bounds, inventory validation, popup dispatch and preserved drafts. `tests/AdminMutations.spec.lua` runs with mock services only; pass the AdminRuntime source string to its returned function in Studio. It does not consume real items.
