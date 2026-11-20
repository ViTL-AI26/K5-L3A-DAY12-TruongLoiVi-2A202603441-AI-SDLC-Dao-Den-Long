# Changelog

## Phase 4 — v1.0.0 release preparation
- Added Contract v1.3 benchmark and soak commands, metrics JSON artifacts, and reproducible runners.
- Added local persistent top-10 leaderboard, end-of-run name capture, leaderboard viewer, and `--export-leaderboard`.
- Added saved colorblind mode and low-fuel/off-lantern visual cues; documented release/retro/audit evidence.

## Phase 2 — Three islands
- Added Nights 2–3, dash, Drifters, Charms, pause, and Contract v1.1 headless coverage.

## Phase 3 — Breaking changes (Contract v1.2)
- Lanterns no longer remain permanently lit: lit lanterns decay by 1 fuel/second and turn off at zero fuel.
- Interaction can refuel a lit, non-full lantern; a relight costs 5 motes after a lantern has been lit once.
- Ink Shades can enter `drain` and consume 5 fuel/second from weak lanterns. Safe zones require at least 30 fuel.
- Nights now end only at dawn: durations are 240/270/300 seconds and survival requires at least 60% lit lanterns; `all_lit` is no longer a win reason.
- Capacity is dynamic (`10 + 2 × successful_lights`, cap 20), and scoring uses Phase 3 deposit, relight, drain-hit, and dawn formulas.
- Headless snapshots/scenarios now include lantern fuel/history, player capacity/successful lights, and Shade drain targets. `lantern_lit` now includes `relight`.
- Added saved colorblind palette mode (`C`) for blue Shade eyes/outlines, white warning treatment, and non-color lantern state cues.

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
