# AI Usage Journal — Phase 1

- Used an AI coding assistant to audit the repository against `AGENTS.md`, PRD-0, Test Contract v1.0 and the Phase 1 plan.
- AI-assisted implementation added a procedural Godot 3D presentation layer, wired to the existing shared `SimulationCore`.
- AI-assisted changes added jump/gravity integration, contract-driven tuning lookup, terminal win scoring, default headless entities, tests and README documentation.
- Human review is required for gameplay feel, visual quality, balance assumptions and acceptance evidence.
- No external art, character model, audio or third-party runtime dependency was introduced.


## 2026-11-20 — Lantern objective supply fix

The graphical scene previously spawned 15 motes even though five lanterns require 25. Increased the initial graphical supply to 25 without changing `game.contract.json` tuning. Added a simulation regression test confirming that a hit drops half of four carried motes, those motes can be picked up on the next tick, and already-lit lanterns remain lit. Godot runtime tests still need to be run in the user's local Godot 4.7.2 environment.
