# Đảo Đèn Lồng — Phase 1 Assumptions & Unresolved Decisions

**Status:** Proposed assumptions for review; none of the items below should be represented as explicit PRD/Test Contract requirements unless approved.

This document supplements:

- `docs/specs/PRD-0.md`
- `docs/specs/test-contract-v1.0.md`
- `docs/plans/phase-1-plan.md`

## 1. Explicitly specified — not assumptions

The following are fixed by the source documents:

- Game is 3D; Phase 1 is Night 1 – Đảo Bến on a circular island with five large lanterns.
- Mây collects motes, deposits light into lanterns, avoids/chases Ink Shades, and can pulse light to repel them.
- Lighting all lanterns wins; losing all health loses.
- Movement, jump, 3D camera, HUD, score and replay are in Phase 1 scope.
- Fixed 60 Hz simulation; no window or GPU in headless mode.
- Tick 0 snapshot occurs after scenario setup and before input.
- Input frame `k` produces state `k+1`; events in that step use tick `k+1`.
- Inputs persist when fields are omitted; jump/interact/pulse are rising-edge actions.
- Movement yaw formula and vector normalization are specified.
- Scenario setup emits no events and awards no score.
- Scenario motes/shades replace their initial lists; lanterns overlay by ID.
- Snapshot/event/end record names and required fields/payloads are specified.
- Invalid scenario/input JSON/schema exits with code 2.
- Same seed/scenario/inputs must produce identical output, including generated IDs.
- Headless mode must not require a window/GPU.
- The `motes` array in snapshots is recommended, not mandatory.

## 2. Proposed gameplay and balance assumptions

| ID | Topic | Proposed decision | Why needed | Requires approval |
|---|---|---|---|---|
| A-01 | Player speed | `5.0 m/s` | PRD does not set movement speed. | Yes |
| A-02 | Carry capacity | `5` motes | Needed to bound carrying. | Yes |
| A-03 | Lantern cost | `5` motes per lantern | Needed to define deposit target. | Yes |
| A-04 | Pickup radius | `1.5 m` | Contract requires a value but does not prescribe one. | Yes |
| A-05 | Interaction radius | `2.5 m` | Contract requires a value but does not prescribe one. | Yes |
| A-06 | Initial flames | `3` | PRD says health is lost but gives no amount. | Yes |
| A-07 | Pulse cost | `1` flame | Pulse must cost light; unit/value not otherwise defined. | Yes |
| A-08 | Pulse radius | `5.0 m` | Needed to identify affected Shades. | Yes |
| A-09 | Pulse stun | `3.0 s` | Needed to define repel/stun duration. | Yes |
| A-10 | Pulse push | `3.0 m` | Needed to define repel displacement. | Yes |
| A-11 | Pulse cooldown | `1.0 s` | Prevents continuous pulse activation; not specified. | Yes |
| A-12 | Shade speed | `3.0 m/s` | PRD says Shades chase but gives no speed. | Yes |
| A-13 | Shade hit radius | `1.0 m` | Contract requires a value but does not prescribe one. | Yes |
| A-14 | Invulnerability | `1.0 s` | Avoids repeated same-contact damage; not specified. | Yes |
| A-15 | Hit drop ratio | `0.5` | Contract defines meaning but not value. | Yes |
| A-16 | Safe radius | `4.0 m` | Contract defines meaning but not value. | Yes |
| A-17 | Night duration | `300 s` | Needed for dawn/loss behavior. | Yes |
| A-18 | Fall penalty | `false` | Avoids fall penalty in first implementation. | Yes |
| A-19 | Score | mote 10, lantern 100, stun 25, second-left 2, flame-left 50 | PRD says score exists but gives no formula. | Yes |

These values are candidate values only. `game.contract.json` must always match the values actually implemented.

## 3. Simulation behavior assumptions

| ID | Topic | Proposed decision | Unspecified source detail |
|---|---|---|---|
| A-20 | Deposit target | On interact edge, select the closest eligible unlit lantern; ties resolve by ascending lantern ID. | Which lantern to choose if several are in range. |
| A-21 | Deposit amount | Deposit `min(carried, lantern_cost - deposited)`. | Whether partial deposits are allowed and how much is transferred. |
| A-22 | Deposit event | Emit `deposit` when amount is greater than zero; if deposit completes the cost, then emit `lantern_lit`. | Exact event ordering is not explicitly stated. |
| A-23 | Mote score | Award `per_mote` at pickup. | Exact award timing is not stated beyond score field meaning. |
| A-24 | Lantern score | Award `per_lantern` once when lantern changes from unlit to lit. | Exact award timing is not specified. |
| A-25 | Shade damage | One Shade hit removes one flame. | Damage amount per contact is not stated. |
| A-26 | Invulnerability | After a hit, grant `invuln_s`; no further hit while active. | Contract provides duration field but not exact hit/timer semantics. |
| A-27 | Hit drops | Drop `floor(carried * hit_drop_ratio)` motes. | Rounding rule and dropped-mote location are unspecified. |
| A-28 | Dropped mote location | Recreate dropped motes at the player's ground XZ position with deterministic IDs. | Where dropped motes appear. |
| A-29 | Pulse activation | A pulse is valid only if cost is affordable and cooldown is zero; deduct cost once. | Whether a pulse with no Shade targets still costs/emits event. |
| A-30 | Empty pulse | A valid pulse with no affected Shades emits `pulse` with `stunned_ids: []`. | Empty-target pulse event behavior is unspecified. |
| A-31 | Stun score | Award `per_stun` only for Shades newly entering stunned state. | Whether already-stunned Shades can score again. |
| A-32 | Pulse target | Select Shades whose horizontal distance is `<= pulse_radius`. | Exact effect order/targeting semantics. |
| A-33 | Push | Push affected Shades horizontally away from Mây by `pulse_push_m`; use a fixed fallback direction if positions coincide. | Push direction and collision handling are unspecified. |
| A-34 | Safe zone | Only lit lanterns create safe zones; Shades may not move into their horizontal `safe_radius`. | Whether unlit lanterns provide safety and how pathing works. |
| A-35 | Shade state | Use `chase` for active and `stunned` for stunned; other names only if needed. | Only `stunned` is contractually required. |
| A-36 | Terminal precedence | Check win first, then no-flames loss, then dawn loss. | Simultaneous terminal conditions are unspecified. |
| A-37 | Tick-0 terminal state | Scenario setup remains `playing`; terminal conditions are evaluated on the first executed step. | Whether a scenario already satisfying win/loss should terminate at tick 0. |
| A-38 | Time origin | Scenario `time_left_s`, when supplied, becomes the initial remaining-time budget; later time is `scenario_time_left - sim_tick/60`. | Contract shows scenario override but does not spell out later calculation explicitly. |
| A-39 | Score time bonus | On win, use `floor(time_left_s) * per_second_left`. | Fractional seconds/score representation is unspecified. |
| A-40 | Score flame bonus | On win, add `flames_remaining * per_flame_left`. | Whether bonus applies only on win is not explicit. Proposed to apply only on win. |
| A-41 | Mote pickup order | Resolve motes in stable ascending ID order; stop when capacity reached. | Simultaneous multi-mote collection order is unspecified. |
| A-42 | Multiple Shade hits | Resolve in ascending Shade ID order; invulnerability prevents more than one hit during its duration. | Simultaneous contact behavior is unspecified. |

## 4. Determinism assumptions

| ID | Topic | Proposed decision | Notes |
|---|---|---|---|
| A-43 | PRNG | Use explicit xorshift32 with a 32-bit masked state. | Test Contract requires determinism, not a specific algorithm. Verify Godot integer/bitwise behavior on macOS/Linux. |
| A-44 | Zero seed | Replace zero internal state with fixed nonzero constant `0x6D2B79F5`. | xorshift32 cannot use zero state. CLI seed remains the same external seed. |
| A-45 | RNG stream | One state-owned stream; deterministic call order; no engine/global RNG. | Prevents platform and rendering order from changing results. |
| A-46 | Lantern IDs | `L1`–`L5`. | IDs implied by scenario overlay examples. |
| A-47 | Mote IDs | `M1`, `M2`, … in creation order. | Contract does not prescribe mote IDs because snapshot mote list is optional. |
| A-48 | Shade IDs | `S1`, `S2`, …; preserve explicit scenario IDs; allocate missing IDs deterministically. | Contract examples use S1/S3 and require generated IDs stable, but exact scheme is unspecified. |
| A-49 | Entity ordering | Sort output arrays and same-phase processing by stable IDs. | Prevents dictionary iteration from changing output. |
| A-50 | Random spawn schedule | Fixed tick intervals and deterministic candidate positions/sampling. | PRD says entities appear but gives no rates, caps or distribution. |
| A-51 | Random spawn bounds | Candidate spawn positions must be inside island and outside invalid/safe zones where applicable. | Island radius and spawn geometry are not specified. |

## 5. Input and validation assumptions

| ID | Topic | Proposed decision | Notes |
|---|---|---|---|
| A-52 | Unknown JSON keys | Reject unknown keys in scenario/input documents. | Contract does not say whether to ignore unknown fields. |
| A-53 | Carried scenario value | Require `0 <= carried <= carry_capacity`. | Contract gives integer field but does not explicitly state capacity validation. |
| A-54 | Lantern deposited value | Require integer `0 <= deposited <= lantern_cost`. | Prevents impossible lantern state; contract does not state bounds. |
| A-55 | Lantern lit/deposited consistency | Preserve explicitly supplied values; do not infer `lit` from deposited unless a documented rule is approved. | Contract allows `lit:true`, but does not define consistency constraints. |
| A-56 | Scenario IDs | Reject duplicate explicit Shade IDs and unknown lantern IDs. | Avoids ambiguous references. |
| A-57 | Frames beyond run | Accept frames with tick >= requested steps but ignore them for that run. | Contract does not specify whether out-of-run frames are rejected. |
| A-58 | `--ticks 0` | Accept zero ticks; emit tick-0 snapshot and end record with zero steps. | Contract says N steps but does not explicitly define zero. |
| A-59 | Snapshot cadence | Require positive integer `snapshot_every`. | Default 10 is specified; zero behavior is not. |
| A-60 | CLI error status | Use exit 1 for CLI/config/runtime errors; exit 2 specifically for invalid scenario/input JSON/schema. | Only scenario/input code 2 is explicit. |
| A-61 | Duration conversion | Require durations to map to integer ticks, otherwise reject config. | Avoids undocumented rounding but is an implementation policy. |

## 6. Default world and presentation assumptions

These must be chosen before gameplay implementation and documented with actual values:

1. Circular island radius and edge/fall boundary.
2. Default coordinates for five lanterns.
3. Default mote count and positions.
4. Default Shade count and positions.
5. Random mote/Shade spawn interval, maximum active count and spawn region.
6. Jump velocity/height, gravity and air-control behavior.
7. Camera orbit, sensitivity, zoom and collision behavior.
8. Player movement orientation and whether camera yaw is driven by mouse or controller.
9. Lantern light intensity/radius and how the island brightens as each lantern is lit.
10. HUD layout and exact indicators (at minimum flames, carried light, lantern progress, timer and score).
11. Win/loss screen design and restart input.
12. Whether audio is included in Phase 1; audio must not affect simulation.

## 7. Approval checklist

Before implementation, approve or revise:

- [ ] Candidate tuning values A-01 through A-19.
- [ ] Deposit and scoring semantics A-20 through A-24 and A-39/A-40.
- [ ] Damage/drop semantics A-25 through A-28.
- [ ] Pulse semantics A-29 through A-35.
- [ ] Terminal/time semantics A-36 through A-40.
- [ ] Deterministic PRNG and ID policy A-43 through A-51.
- [ ] Validation policies A-52 through A-61.
- [ ] Default world geometry, spawn schedules and camera/jump behavior in Section 6.

## 8. Highest-priority unresolved ambiguities

1. **Score semantics:** when each score is awarded and whether time/flame bonuses apply only on win.
2. **Fractional time bonus:** whether `per_second_left` uses floor, round, fractional score, or another rule.
3. **Damage semantics:** number of flames removed per hit and exact dropped-mote rounding/location.
4. **Pulse semantics:** whether an empty pulse consumes cost/emits an event; how push and stun interact.
5. **Deposit semantics:** partial deposits, lantern selection when multiple lanterns are in range, and event order.
6. **Terminal precedence:** simultaneous all-lit, zero-flames and dawn conditions.
7. **Tick-0 terminal scenario:** whether a scenario already in a terminal configuration ends before any step.
8. **Random generation:** spawn counts, rates, caps, distributions and whether scenario random flags affect only later spawns.
9. **World geometry:** island radius, fall boundary and default entity positions.
10. **Validation strictness:** unknown keys, numeric integer/float acceptance, and out-of-range scenario values.
11. **Timer boundary convention:** exact tick on which stun, invulnerability and cooldown expire.
12. **Coordinate serialization:** contract says round to 3 decimals but does not define lexical JSON formatting (e.g. `1` versus `1.000`).

No implementation should silently choose these behaviors. Record approved choices here and keep `game.contract.json` synchronized with actual behavior.
