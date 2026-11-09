# Gameplay entry checks

The native client `Client.ToolGameplayGuard` checks both the gameplay side of SeparationLine and tagged safe-zone volumes. A line-only coordinate check is insufficient for tool eligibility. The server's separate GameplayToolGuard is not available in the saved Studio place, so client checks cannot be presented as server acknowledgement.

Before an outbound collection, the engine walks across the real separator with native Humanoid:MoveTo when entry is not yet locally allowed, then observes a stable native guard result for 0.35 seconds. This leg does not assign CFrame, velocity, WalkSpeed, attributes or collision properties. Entry can time out or be cancelled; it never changes the guard's answer. Recovering an already-carried egg bypasses the outbound leg and returns normally.

Pickup eligibility is rechecked before scheduling and immediately before dispatch. Native bat activation is also gated by the native arena/safe-volume checks. An `Enter the gameplay area first` server refusal immediately suspends collection instead of sending up to five pickup retries. No guard hook, state spoofing or additional diagnostic network message is used.

`tests/GameplayEntry.spec.lua` verifies the local guard, safe-volume blocking, normal walking, stable entry, timeouts, cancellation and no-dispatch behavior with mocks. Live server acceptance still requires a gameplay test; manual crossing with automation paused helps distinguish movement replication from a persistent game/session issue.

