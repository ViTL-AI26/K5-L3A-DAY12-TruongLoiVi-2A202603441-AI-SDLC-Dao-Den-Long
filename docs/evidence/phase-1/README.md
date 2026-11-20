# Phase 1 Evidence

Evidence must be captured from an actual local Godot 4.7.2 run; no screenshots or logs are fabricated in this repository.

Before submission, add:
1. Screenshot of the initial Night 1 scene showing Mây, island and lanterns.
2. Screenshot showing a lit lantern and updated HUD.
3. Screenshot of a win or loss screen and replay.
4. Raw output from the headless smoke command and simulation test command.

Commands:
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_simulation.gd
godot --headless --path . --script res://scripts/headless/main.gd -- --seed 123 --night 1 --ticks 600 --out /tmp/phase1-smoke.jsonl
```
