# ADR-003: Fuel-backed lantern state and dawn-only outcome

## Decision

Each lantern owns `lit`, `deposited`, `fuel_ticks`, `ever_lit`, and `relit_count`. `fuel_ticks` is an integer in `[0, 6000]`, so the required 1/60 and 5/60 fuel changes are exact. The displayed `fuel` is derived only at the snapshot/UI boundary.

The simulation first decays fuel and applies existing Shade drains, extinguishes empty lanterns, then processes movement, pickups, interaction, safety, pulse, AI, contact, spawn, and terminal state. A safe zone requires `lit` and fuel >= 30. Terminal evaluation has no early win branch: zero Flames loses first; at dawn, the 60% lit threshold chooses `dawn_survived` or `dawn`.

## Consequences

- Old all-lit tests are replaced by dawn fixtures; no test is silently skipped.
- Relights are observable and count toward capacity progression.
- Headless output remains deterministic because fuel mutation is integral and presentation does not access RNG or mutate state.
