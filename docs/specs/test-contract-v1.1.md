# Test Contract v1.1

`game.contract.json` declares `contract_version: "1.1"` and provides the Godot headless command. The command accepts `--seed`, `--night 1|2|3`, `--ticks`, `--out`, optional `--scenario`, `--inputs`, and `--snapshot-every`.

The runner emits JSONL `snapshot`, `event`, then one final `end` record. Tick 0 is after scenario construction and before input. Invalid scenario/input JSON or schema exits with code 2. Identical seed, scenario, and inputs produce byte-identical output.

Every snapshot contains `night`, `wind {active, dir_deg}`, player `pos`, `vel`, `grounded`, `invuln`, `dash_cd_s`, `pulse_cd_s`, `charm_s`, and arrays for `motes`, `drifters`, and `charms`. Motes provide `id`, `pos`, `kind`, and `ttl_s`; Drifters provide `id`, `pos`, `state`, and `stolen`; Charms provide `id`, `available`, and `respawn_s`.

Scenarios can set player timers, Shade states and state timers, Drifters, Charms, `random_drifters`, and `wind_enabled`; inputs include edge-triggered `dash` and `pause`. Required new event names are `dash`, `charm_picked`, `drifter_steal`, `drifter_drop`, `night_start`, `paused`, and `resumed`.
