# Phase 3 acceptance record

| Area | Acceptance criterion | Evidence |
| --- | --- | --- |
| Fuel | 100-fuel lamps decay exactly 1/60 per tick, turn off at zero, and retain relight history. | `test_simulation.gd`, `phase3-fuel-*` |
| Refuel/relight | Interaction selects eligible lamps, refuels by 10 per mote, and relights for five after first light. | unit test + fuel fixture |
| Shade drain | Wander selects weak targets; `drain` consumes 5/60 per tick and emits each second. | `phase3-drain-scenario.json` |
| Dawn | No early win; dawn uses 60% threshold with no-flames precedence and new score. | `phase3-dawn-scenario.json` |
| Capacity/score | Successful lights raise capacity to 20 max; v1.2 scores replace Phase 2 values. | unit test |
| Accessibility | Saved colorblind mode changes Shade warning color and uses off-lamp scale/low-fuel blink. | `graphical_game.gd` |
| Contract/docs | v1.2 scenario/snapshot/events, ADR, changelog, agent instructions, and regression harness are current. | linked files |
