# Changelog

## Phase 1 implementation pass
- Added a procedural 3D Night 1 scene with circular island, cloud sea, lanterns, motes, Ink Shades and a stylized Mây character.
- Added third-person orbit camera, keyboard controls, jump, HUD, terminal overlays and replay.
- Kept graphical mode on the shared `SimulationCore`.
- Added deterministic jump integration and win score bonuses to the simulation.
- Loaded gameplay tuning from `game.contract.json`.
- Added default motes and Shades to the headless default world; scenario arrays still replace those lists.
- Added jump and win-bonus regression tests.
- Added README and evidence checklist.

Validation note: validated with Godot 4.7.2 using
`godot --headless --path . --script res://tests/test_simulation.gd` and
`./tests/run_contract_checks.sh`. The latter executes the real headless entry
point for pickup, deposit, lantern lighting, winning, invalid input and
deterministic replay.

- Gameplay balance: increased the graphical starting mote supply from 15 to 25 so the five lanterns (5 motes each) are achievable; added a regression test for hit-drop recovery and lantern persistence.
