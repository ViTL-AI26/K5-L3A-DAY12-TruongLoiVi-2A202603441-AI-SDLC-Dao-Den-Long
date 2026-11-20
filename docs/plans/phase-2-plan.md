# Phase 2 acceptance record

## Acceptance criteria

| Area | Acceptance criterion | Evidence |
| --- | --- | --- |
| Standard tuning | 60 Hz core uses the fixed movement, dash, combat, carrying, score, fall, and timing values. | `game.contract.json`, `tests/test_simulation.gd` |
| Three maps | Headless bootstrap builds the canonical Night 1/2/3 lantern, mote, Shade, Charm, and pad layouts. | `scripts/headless/main.gd`; Night 2/3 unit checks |
| Dash and pause | Edge-triggered dash and pause follow v1.1 timers and paused snapshots freeze sim time. | `phase2-dash-pause-*` fixture |
| Gió Lạc | Drifter state machine chases, steals, flees, and drops stolen motes after Pulse. | `phase2-drifter-scenario.json`, unit coverage |
| Bùa Gió | Charm pickup grants 600 ticks, run bonus, dash cooldown bypass, and 2700-tick respawn. | `phase2-charm-scenario.json`, unit coverage |
| Wind | Night 3 has deterministic warning/active cycles; scenarios can disable it. | `phase2-wind-disabled-scenario.json` |
| Headless v1.1 | Snapshots add all v1.1 fields; scenarios and inputs validate strictly; repeat run is byte-identical. | `tests/run_contract_checks.sh` |
| Regression | Pickup, deposit, invalid-schema exit code, deterministic behavior, and core combat are exercised alongside Phase 2 features. | `tests/run_contract_checks.sh` |

## Reproduce

```bash
bash tests/run_contract_checks.sh
godot --headless --path . --script res://scripts/headless/main.gd -- --seed 7 --night 3 --ticks 21600 --out /tmp/night3.jsonl
```

The test harness runs one headless scenario for every Ticket-02-only mechanic and keeps visual presentation outside the deterministic simulation core.
