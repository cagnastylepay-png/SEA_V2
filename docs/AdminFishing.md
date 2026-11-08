# Admin fishing

Render > Admin > Paramètres > Déplacement selects Auto tapis, Auto pêche, or no idle activity. AutoFishing defaults false; it cannot be saved together with AutoTreadmill=true. Reload Loaders/Admin.lua to install the updated runtime.

AdminFishing uses the existing game rod controller (Tool Activate/Deactivate) and FishingUI; it creates no GUI and does not fabricate a caught result. Each cast resolves a rod again, equips it through Humanoid, and confirms its parent and Fishing.EquippedRod before activation. The charge targets the live PerfectMin/PerfectMax midpoint using ChargeSeconds and the native 1.4 curve. It only clicks when the native Reel panel is visible, at no more than 12 clicks/s or the live lower limit.

The bank finder samples ground around water parts in AlienBiomeZone/AlienLagoon, verifies the cast water through Fishing.Probe, and uses the engine movement routine. Missing access, speed, rod, bank, or UI confirmation produces a status and ten-second backoff. It does not unlock the ferry or bypass access checks. Routes and casting remain to be verified in a live session; Studio tests use mocks.

AUTO OFF, eligible queued egg, remote teleport, manual action, character change, or option change aborts fishing. Cancellation unequips the owned rod before Deactivate, so a charging cancellation cannot release another cast; camera framing is restored. Existing flight arrival and maintenance priorities are preserved.

Validation: AdminFishing, AdminMutations, AdminArrival, AdminMaintenance Studio mocks; full Hub compilation; Render settings and dashboard selector tests. No live cast was executed by these tests.
