# Script requirements

- Only `FLIGHT_RESULT` events may enter remote log batches or trigger a remote log send.
- Keep detailed diagnostic logs local. Never send an empty log batch.
- Egg/player observation snapshots and admin settings are separate from logs: preserve their deduplication and change-driven delivery.
- Observer stays in the background without a full GUI or icon; its only in-game control is the standalone Reload button. It does not teleport automatically outside the configured group/spread behavior.
- Never put `SECRET_MDP` or other Render credentials in client scripts or loaders.
