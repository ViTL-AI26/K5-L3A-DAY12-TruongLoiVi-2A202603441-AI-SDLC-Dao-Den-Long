# Đảo Đèn Lồng — Phase 1 Architecture & Implementation Plan

**Status:** Planning revision — awaiting user approval  
**Authority:** `docs/specs/PRD-0.md` and `docs/specs/test-contract-v1.0.md`  
**Engine:** Godot 4.7.2 (implementation choice, not a PRD requirement)  
**Scope:** Planning only. No gameplay code is included in this document.

---

## 0. Document authority and interpretation

The PRD defines the customer-facing game. Test Contract v1.0 defines the required headless interface, simulation timing, input format, scenario format, and JSONL output. Where these documents are explicit, implementation must follow them exactly.

This plan separates:

- **MUST — specified:** directly required by PRD-0 or Test Contract v1.0.
- **PROPOSED — assumption:** a design choice needed because the source documents do not specify the detail. Record it in `docs/specs/ASSUMPTIONS.md`; do not describe it as a customer requirement.
- **VERIFY — implementation check:** a test that must pass before Phase 1 is considered complete.

No additional JSONL fields are permitted. The only output record types are `snapshot`, `event`, and `end`, with the exact keys and payloads defined below.

## 1. Complete PRD-0 requirement breakdown

### 1.1 Product and player fantasy

| ID | Requirement | Implementation responsibility | Acceptance evidence |
|---|---|---|---|
| PRD-01 | The product is a 3D game named **Đảo Đèn Lồng**. | Godot project settings, title/menu presentation. | Game launches and displays the correct title. |
| PRD-02 | Player controls Mây, a young lantern keeper on an island amid a sea of clouds. | Player visual/controller and environment art. | In-game character is visibly controllable. |
| PRD-03 | Darkness/black mist has consumed the island's light. | Initial lighting, environment palette and world presentation. | Initial scene reads as a dark night island. |
| PRD-04 | Mây collects light motes/fireflies around the island. | Mote entities, pickup logic, HUD. | Motes can be collected and carried count changes. |
| PRD-05 | Mây brings collected light to large lanterns to relight them. | Lantern interaction/deposit logic. | Valid interaction transfers carried light and can light a lantern. |
| PRD-06 | Ink Shades live in the dark mist and chase Mây. | Shade AI state and deterministic chase movement. | Active Shades approach the player in simulation and game. |
| PRD-07 | Shade contact damages Mây. | Hit detection, invulnerability and flame/health state. | Contact emits `player_hit` and reduces flames. |
| PRD-08 | Mây can emit a light pulse to repel Shades. | Pulse action, cost, radius, push and stun. | Valid pulse emits `pulse`; eligible Shades are pushed/stunned. |
| PRD-09 | Light pulse costs light. | `pulse_cost` tuning and pulse activation gate. | Cost is deducted exactly as configured. |
| PRD-10 | Ink Shades fear lanterns. | Safe-radius avoidance around lit lanterns. | Shade movement does not enter the configured safe radius. |
| PRD-11 | Lighting every large lantern wins. | Terminal condition and win event. | All five lit produces `game_over` won/all_lit. |
| PRD-12 | Losing all health loses. | Flame counter and loss condition. | Zero flames produces `game_over` lost/no_flames. |
| PRD-13 | The game has a score. | Central score accounting. | Score changes only on documented game events/bonuses. |

### 1.2 Phase 1 scope

| ID | Requirement | Implementation responsibility | Acceptance evidence |
|---|---|---|---|
| SCOPE-01 | One level: **Đêm 1 – Đảo Bến**. | One playable level/bootstrap. | Game starts directly in this level. |
| SCOPE-02 | Island is circular. | 3D island mesh/collision/presentation boundary. | Visible circular island; gameplay boundary behavior documented. |
| SCOPE-03 | Exactly five large lanterns in Night 1. | Default world state and `lantern_count_night1`. | Five stable lantern IDs `L1`–`L5`. |
| SCOPE-04 | Character can move. | Input adapter and simulation movement. | Movement tests and playable control. |
| SCOPE-05 | Character can jump. | Deterministic jump/gravity simulation; visual adapter. | Jump input produces a jump in graphical mode. |
| SCOPE-06 | 3D camera. | Graphical camera rig and camera controls. | Third-person 3D view follows Mây. |
| SCOPE-07 | Fireflies are distributed around island and collectible. | Default mote placement/spawning and pickup system. | At least one reachable default mote; scenario pickup tests. |
| SCOPE-08 | Light can be deposited into lanterns. | Interaction/deposit system. | Deposit and light events have exact payloads. |
| SCOPE-09 | Shades appear and chase. | Default Shade setup/spawning and chase AI. | At least one default Shade appears; scenario chase tests. |
| SCOPE-10 | Light pulse repels Shades. | Pulse system. | Pulse cost, radius, stun and push are observable. |
| SCOPE-11 | Win/loss, score and HUD. | State machine, scoring and HUD. | HUD displays essential state; end states visible. |
| SCOPE-12 | Replay after win or loss. | Graphical restart flow resetting the same default night. | Restart creates a fresh initial game. |

### 1.3 Mood, art direction and content constraints

- Nighttime, warm and fairytale-like atmosphere.
- The island becomes progressively brighter as lanterns are lit.
- Positive light uses warm golden/orange tones.
- Threats use dark purple/black tones.
- Art is simple but attractive; photorealism is not required.
- Mây wears a nón lá with a small hanging lantern.
- No graphic violence and no gore.

These are presentation requirements. They must not alter simulation outcomes, hit distances, RNG, score, or headless output.

### 1.4 Platform, delivery and evidence

- The game must run on a laptop using macOS or Linux. If developed on Windows, provide a macOS/Linux-compatible route such as Docker or web build.
- Submit on a public repository using Git tag `phase-1`.
- `README.md` must document installation/run in at most three commands, controls and score calculation.
- Root `game.contract.json` and Test Contract v1.0 headless mode are mandatory.
- Provide evidence that the game runs correctly and short records of assumptions and AI usage.
- Include the AI harness used (`AGENTS.md` or equivalent, skills, hooks, etc.).
- Evidence must be actual run output/screenshots/video or test logs; an agent's assertion that it ran is not evidence.

## 2. Architecture

### 2.1 Core principle

**One authoritative deterministic simulation core** must serve both graphical and headless modes. Do not implement gameplay rules separately in Godot scene callbacks and headless code.

Recommended layers:

1. **Contract/config layer:** parses `game.contract.json`; validates all tuning fields; exposes typed values.
2. **Scenario layer:** builds initial state and applies scenario overlays without events or score.
3. **Input timeline:** maintains persistent input values and calculates rising edges.
4. **Simulation core:** advances canonical state by exactly one fixed tick.
5. **Simulation runner:** owns tick count, event ordering, snapshot cadence, terminal stop and end record.
6. **Headless adapter:** parses CLI/files, invokes the runner, writes JSONL, returns exit codes.
7. **Graphical adapter:** polls input, queues tick-indexed frames, calls the same runner/core and renders returned state.
8. **Presentation layer:** island, Mây model, camera, motes, lanterns, Shades, lighting, HUD, win/loss/restart UI.

### 2.2 Proposed module ownership

| Module | Responsibility | Must not own |
|---|---|---|
| `SimulationConfig` | Read and validate contract version and every tuning value. | Gameplay decisions or duplicate constants. |
| `SimulationState` | Canonical player, lantern, mote, Shade, timer, score, RNG and terminal state. | Godot nodes, UI or wall-clock time. |
| `ScenarioLoader` | Parse scenario, validate it, overlay state. | Event emission, score awards, gameplay tick. |
| `InputTimeline` | Persistent controls, frame application, rising-edge calculation. | Movement or gameplay effects. |
| `DeterministicRng` | Seed normalization and reproducible random stream. | Global/engine RNG. |
| `SimulationCore.step()` | One deterministic state transition and ordered events. | Filesystem, rendering, engine physics, wall-clock. |
| `SimulationRunner` | Tick lifecycle, snapshot/event/end record scheduling. | Duplicate gameplay rules. |
| `HeadlessCli` | CLI parsing, file I/O, stderr and exit codes. | Gameplay decisions. |
| `GraphicalDriver` | Poll controls, queue frames, run fixed ticks. | Separate gameplay implementation. |
| `WorldView` / `HUD` | Render canonical state and feedback. | Mutating authoritative simulation state. |

### 2.3 Suggested repository layout

```text
game.contract.json
project.godot
README.md
AGENTS.md
AI_JOURNAL.md
CHANGELOG.md
CREDITS.md
docs/
  specs/
    PRD-0.md
    test-contract-v1.0.md
    ASSUMPTIONS.md
  plans/
    phase-1-plan.md
  evidence/
    phase-1/
scripts/
  bootstrap.gd
  sim/
    simulation_config.gd
    simulation_state.gd
    simulation_core.gd
    simulation_runner.gd
    input_timeline.gd
    scenario_loader.gd
    deterministic_rng.gd
    entity_id_allocator.gd
    jsonl_writer.gd
  runtime/
    headless_cli.gd
    graphical_driver.gd
  presentation/
    world_view.gd
    player_view.gd
    lantern_view.gd
    mote_view.gd
    shade_view.gd
    hud.gd
scenes/
  bootstrap.tscn
  night1.tscn
tests/
  unit/
  contract/
  scenarios/
```

This is a proposal, not a requirement to use these exact filenames. The ownership boundaries are the important part.

## 3. Coordinate and distance model

Test Contract v1.0 explicitly specifies:

- Length unit: metres.
- Y axis points upward.
- Island ground is at `Y = 0`.
- Default player starts at `(0, 0, 0)`.
- `player.pos` is the player's feet position.
- `shade.pos` is the Shade centre.
- `lantern.pos` is the lantern pole base.
- Mote position is a point on the ground; visual hover height is presentation-only.
- All tuning distances use horizontal XZ distance only.
- No implicit character/entity size is added to those distances.
- A point is in radius `r` when horizontal distance is `<= r`.

Canonical distance helper:

```text
horizontal_distance(a, b) =
    sqrt((a.x - b.x)^2 + (a.z - b.z)^2)
```

Use this helper for pickup, interaction, pulse, Shade hit and safe-radius checks. Do not use 3D Euclidean distance for these contract distances.

## 4. Exact tuning contract and code mapping

`game.contract.json` must contain every key below. The listed numeric values are **proposed game-balance choices**, not values dictated by PRD or Test Contract. They must be reviewed before implementation and must match the values actually used by the simulation.

| Contract field | Proposed value | Unit/meaning | Single implementation owner |
|---|---:|---|---|
| `tuning.player_speed` | `5.0` | metres/second | `SimulationCore` movement; config field `player_speed_mps` |
| `tuning.carry_capacity` | `5` | maximum carried motes | `SimulationCore` pickup gate; scenario validation |
| `tuning.lantern_cost` | `5` | motes required to light one lantern | `SimulationCore` deposit/light logic |
| `tuning.lantern_count_night1` | `5` | number of Night-1 lanterns | `SimulationConfig` and default world builder; IDs `L1`–`L5` |
| `tuning.pickup_radius` | `1.5` | metres, horizontal inclusive radius | `SimulationCore` mote collection |
| `tuning.interact_radius` | `2.5` | metres, horizontal inclusive radius | `SimulationCore` lantern selection |
| `tuning.pulse_cost` | `1` | flame/light units consumed per valid pulse | `SimulationCore` pulse activation |
| `tuning.pulse_radius` | `5.0` | metres, horizontal inclusive radius | `SimulationCore` pulse target selection |
| `tuning.night1_duration_s` | `300.0` | seconds | `SimulationConfig`; runner derives remaining time from tick |
| `tuning.flames` | `3` | initial flame/health units | default state builder |
| `tuning.invuln_s` | `1.0` | seconds of post-hit invulnerability | `SimulationCore` damage timer |
| `tuning.hit_drop_ratio` | `0.5` | fraction of carried motes dropped on hit | `SimulationCore` damage/drop logic |
| `tuning.pulse_stun_s` | `3.0` | seconds a Shade remains stunned | `SimulationCore` Shade status timer |
| `tuning.pulse_push_m` | `3.0` | metres of horizontal pulse displacement | `SimulationCore` pulse displacement |
| `tuning.pulse_cooldown_s` | `1.0` | seconds between valid pulses | `SimulationCore` pulse cooldown |
| `tuning.safe_radius` | `4.0` | metres around a lit lantern | `SimulationCore` Shade movement constraint |
| `tuning.shade_speed` | `3.0` | metres/second | `SimulationCore` Shade chase movement |
| `tuning.shade_hit_radius` | `1.0` | metres, horizontal inclusive radius | `SimulationCore` Shade damage test |
| `tuning.fall_enabled` | `false` | whether falling off island causes a hit | `SimulationCore` fall-damage branch |
| `tuning.score.per_mote` | `10` | points per collected mote | `SimulationCore` scoring on pickup |
| `tuning.score.per_lantern` | `100` | points per newly lit lantern | `SimulationCore` scoring on lantern-lit transition |
| `tuning.score.per_stun` | `25` | points per Shade newly stunned | `SimulationCore` scoring on pulse |
| `tuning.score.per_second_left` | `2` | points per remaining second on win | `SimulationCore` terminal win scoring |
| `tuning.score.per_flame_left` | `50` | points per remaining flame on win | `SimulationCore` terminal win scoring |

### 4.1 Null and false handling

- If a concept is not implemented, its tuning value must be `null` or `false` as allowed by Test Contract, and README must explain why.
- Do not put `0` for an unsupported concept if that would misrepresent behavior.
- With the proposed Phase-1 design above, all listed concepts are implemented; `fall_enabled` is explicitly `false`.
- `lantern_count_night1` must remain five for this PRD scope.
- `SimulationConfig` is the sole source of tuning values. No second set of hard-coded gameplay values is allowed.

### 4.2 Duration conversion

Convert configured durations to integer ticks once when loading config:

```text
ticks = seconds * 60
```

**PROPOSED:** require configured durations to resolve to an integer number of ticks (within a small, documented floating tolerance), otherwise reject the config. This avoids undocumented rounding. This validation policy is not explicitly prescribed by Test Contract.

## 5. Headless CLI contract

### 5.1 Required command shape

```text
<headless_cmd> --seed <int> --night 1 [--scenario <file.json>] [--inputs <file.json>]
             --ticks <int> --out <file.jsonl> [--snapshot-every <int, default 10>]
```

- `--seed`, `--night`, `--ticks`, and `--out` are required.
- `--scenario` and `--inputs` are optional.
- `--snapshot-every` is optional and defaults to `10`.
- `--night` must be `1` for Phase 1.
- `--ticks N` means at most N steps; stop sooner if terminal.
- **PROPOSED:** accept `--ticks 0` as a zero-step run that writes snapshot tick 0 and then `end`; reject negative values.
- **PROPOSED:** require `--snapshot-every > 0`.
- Unknown, duplicated, malformed or missing-value flags are CLI errors. Test Contract says generic errors exit non-zero, but does not assign a specific status for CLI errors. Use status `1` for CLI/config/runtime errors; reserve status `2` for invalid scenario/input JSON and schema.
- Error details go to stderr.
- Successful runs, including early win/loss, exit `0`.

### 5.2 Godot invocation

The `headless_cmd` in the contract should invoke Godot in headless mode and pass user arguments after `--`. The parser must read only user args, not Godot's own flags. Example command shape:

```bash
godot --headless --path . --script scripts/runtime/headless_cli.gd -- \
  --seed 123 --night 1 --ticks 600 --out /tmp/run.jsonl
```

Final command must be tested on macOS and Linux. It must not create a window, viewport, renderer, GPU context or renderer-dependent scene.

### 5.3 Build and graphical commands

- `build_cmd`: valid setup/import/validation command for this Godot project; document exactly what it does.
- `run_cmd`: opens the graphical game.
- The exact command strings must be verified from a clean clone before submission.
- Do not claim a command is portable until tested on macOS/Linux.

## 6. Tick model and exact runner lifecycle

### 6.1 Fixed tick

Simulation frequency is exactly 60 ticks per second:

```text
DT = 1.0 / 60.0 seconds
```

The headless runner performs the requested steps as fast as possible; it does not sleep and does not use wall-clock frame delta. The graphical runner uses wall-clock accumulation only to decide how many whole fixed steps to execute. Both call the same `SimulationCore.step()`.

### 6.2 Tick numbering

- Build default state.
- Apply scenario setup.
- Do not apply any input yet.
- Do not emit events or award score during setup.
- Write snapshot tick `0`.
- For each step with input tick `k`, calculate state tick `k+1`.
- Any event caused by that step uses `tick: k+1`.
- `--ticks N` executes exactly N steps unless terminal state occurs earlier.
- `sim_tick` equals completed simulation steps and equals `tick` in Phase 1.
- `time_left_s = night1_duration_s - sim_tick / 60`.
- Never decrement a floating time accumulator.

### 6.3 Runner pseudocode

```text
config = load_and_validate_game_contract()
args = parse_cli()
scenario_doc = load_optional_scenario_or_default()
input_doc = load_optional_inputs_or_idle()
state = build_default_state(config, seed)
state = apply_scenario_without_events_or_score(state, scenario_doc)

write_snapshot(state, tick=0)

while state.status == "playing" and state.sim_tick < args.ticks:
    input_frame = input_timeline.frame_for_tick(state.sim_tick)
    result = simulation_core.step(state, input_frame, config)
    state = result.state

    for event in result.events_in_order:
        write_exact_event_record(event, tick=state.sim_tick)

    if state.sim_tick % args.snapshot_every == 0:
        write_snapshot(state)

write_exact_end_record(
    ticks=state.sim_tick,
    state=state.status,
    score=state.score
)
```

The final `end` record is always the last line for every successful run. Do not add an unscheduled final snapshot merely because the run ended between cadence ticks.

### 6.4 Within-step ordering

Test Contract fixes the tick boundaries but does not fully prescribe the order of gameplay subsystems. The following is a proposed deterministic order; it must be recorded as an assumption and used consistently by graphical and headless modes.

1. Apply the frame for input tick `k` to persistent controls.
2. Calculate rising edges by comparing the new held buttons with the previous held buttons.
3. Advance existing invulnerability, Shade stun and pulse cooldown timers according to the chosen timer convention. **Proposed convention:** timers are represented as remaining integer ticks; a timer active at the start of the step protects/holds for that step, then is decremented. Timers created during this step are not decremented until the next step.
4. Apply horizontal player movement using the required yaw transform, normalize if vector length exceeds one, and move by `player_speed / 60`.
5. Apply jump edge and deterministic vertical integration/ground collision.
6. Collect motes at the player's post-movement XZ position, in stable mote-ID order, while carry capacity permits. Emit one `mote_picked` event per mote collected.
7. Process `interact` rising edge. Select one eligible unlit lantern by the documented deterministic selection rule. Deposit carried motes and light the lantern if its cost is met.
8. Process `pulse` rising edge if enough flames/light and cooldown permits. Deduct cost, push/stun eligible Shades in stable ID order, award stun score for newly stunned Shades, and emit exactly one `pulse` event for a valid pulse.
9. Run permitted deterministic mote/Shade spawn checks. New Shade creation emits `shade_spawned`.
10. Move active, non-stunned Shades toward Mây, respecting safe zones around lit lanterns.
11. Resolve Shade hits in stable Shade-ID order, respecting invulnerability. If `fall_enabled` is true, resolve fall damage using the documented rule; with proposed Phase-1 value `false`, no fall hit occurs.
12. Increment `sim_tick` to `k+1`; derive `time_left_s` from the exact formula.
13. Evaluate terminal state and emit at most one `game_over` event:
    - win when all five lanterns are lit;
    - otherwise lose when flames are zero (`no_flames`);
    - otherwise lose when time is zero or less (`dawn`).
14. If the completed tick is on the snapshot cadence, write the snapshot after all events from that step.
15. If terminal, stop stepping. After loop, write the mandatory end record.

**Important:** The exact ordering above is a proposal for unspecified interactions. The explicitly required boundaries (scenario has no events/score; input tick `k` creates state/event tick `k+1`; fixed 60 Hz; snapshot tick 0; end record last) are not negotiable.

## 7. Persistent input model

### 7.1 Defaults

Before the first frame:

```json
{
  "move": [0, 0],
  "cam_yaw_deg": 0,
  "jump": false,
  "interact": false,
  "pulse": false,
  "dash": false
}
```

`dash` is optional; it should be omitted from implementation if not supported. The required Phase-1 actions are `jump`, `interact`, and `pulse`.

### 7.2 Frame merge behavior

Each input frame changes only the fields it contains. Fields omitted from a later frame retain their previous values. A frame is not a full-state replacement.

Frames must have strictly increasing integer `tick` values. Duplicate or decreasing ticks are invalid. A frame beyond the requested run length may be accepted and ignored because it has no effect on executed ticks; this is a proposed validation choice.

### 7.3 Movement transform

For raw input `[x, z]` and `theta = deg_to_rad(cam_yaw_deg)`:

```text
world_x = x * cos(theta) + z * sin(theta)
world_z = -x * sin(theta) + z * cos(theta)
```

At yaw 0, x maps to +X and z maps to +Z. Normalize the transformed vector if its length exceeds 1. Apply horizontal movement distance `player_speed / 60` for a full-magnitude vector.

### 7.4 Rising-edge actions

`jump`, `interact`, and `pulse` activate only on false-to-true transition:

```text
pressed = current_value == true AND previous_value == false
```

A held true value across multiple ticks does not repeat. A false frame followed by true permits another activation. Input timeline must preserve both held and previous values.

## 8. Scenario loading and validation

### 8.1 General process

- Parse scenario JSON before creating/truncating output file.
- Root must be a JSON object.
- Start from the default Night-1 state, then apply supplied fields as overlays.
- Missing fields retain default game values.
- `motes` and `shades` arrays replace their corresponding initial lists when present.
- `lanterns` updates by ID; unspecified lanterns remain unchanged.
- Scenario setup is state initialization only: no events, no score awards, no pickup/deposit/light transitions are simulated.

### 8.2 Scenario field mapping

| Scenario field | Meaning and loader action | Validation |
|---|---|---|
| `player.pos` | Set player feet position. | Exactly 3 finite numbers. |
| `player.carried` | Set carried mote count. | Non-negative integer; proposed validation also requires `<= carry_capacity`. |
| `player.flames` | Set current flames. | Non-negative integer. |
| `random_motes` | Enable/disable autonomous mote generation. | Boolean. |
| `random_shades` | Enable/disable autonomous Shade generation. | Boolean. |
| `motes` | Replace initial mote list; each item is a ground position. | Array of 3 finite numbers per mote. |
| `shades` | Replace initial Shade list; each has a position and optional ID. | Object entries; position is 3 finite numbers; explicit IDs unique. |
| `lanterns` | Overlay Night-1 lanterns by `L1`–`L5`. | Array of objects; known unique IDs. |
| `lanterns[].id` | Select target lantern. | One of `L1`–`L5`. |
| `lanterns[].pos` | Replace lantern base position. | Exactly 3 finite numbers. |
| `lanterns[].deposited` | Set current deposited amount. | Proposed: non-negative integer, not greater than `lantern_cost`. |
| `lanterns[].lit` | Set initial lit state. | Boolean. No event or score even when true. |
| `time_left_s` | Override remaining time at tick 0. | Finite non-negative number. |

### 8.3 Input validation

- Root is an object containing `frames` array.
- Every frame is an object with integer `tick`.
- Frame ticks strictly increase.
- `move` has exactly two finite numeric values, each in `[-1, 1]`.
- `cam_yaw_deg` is finite numeric.
- `jump`, `interact`, `pulse` (and `dash` if implemented) are booleans.
- Unknown keys: proposed policy is strict rejection; Test Contract does not expressly define unknown-key handling.
- Missing optional fields retain prior/default values.
- Missing inputs file means idle defaults.
- Invalid JSON or schema in scenario/inputs exits with code `2` and writes diagnostic to stderr.

### 8.4 Error behavior

- Invalid JSON syntax: exit `2`.
- Invalid scenario/input type, shape, range, duplicate frame tick or invalid ID: exit `2`.
- No partial JSONL output should be mistaken for a successful run. Validate inputs/scenario before opening output.
- Other CLI/runtime/config errors: non-zero; proposed code `1` unless a more specific platform failure applies.
- Successful completion: exit `0`.

## 9. Deterministic random generation and entity IDs

Test Contract requires same seed + same scenario + same inputs to produce identical output, including automatically generated IDs. It does not mandate a particular PRNG algorithm. A concrete algorithm and allocation policy must therefore be selected and documented before implementation.

### 9.1 Proposed PRNG

Use a small explicit 32-bit xorshift generator implemented in GDScript integer arithmetic, not Godot's global RNG:

```text
MASK = 0xFFFFFFFF
state = seed & MASK
if state == 0:
    state = 0x6D2B79F5

next_u32():
    x = state
    x = (x ^ ((x << 13) & MASK)) & MASK
    x = (x ^ (x >> 17)) & MASK
    x = (x ^ ((x << 5) & MASK)) & MASK
    state = x
    return state

random_unit():
    return next_u32() / 4294967296.0
```

Implementation must verify Godot bitwise behavior and unsigned masking on supported macOS/Linux builds. Do not use `randf()`, `randi()`, time, UUIDs, Node instance IDs or OS entropy.

### 9.2 Random stream discipline

- One canonical PRNG state belongs to `SimulationState`.
- All random draws occur in one documented deterministic order.
- Do not make random draws from rendering, audio, camera or HUD.
- Do not conditionally consume extra random values in presentation code.
- If motes and Shades both spawn randomly, document which subsystem consumes the stream first on a tick.
- Same initial seed/state and same step sequence must produce the same draws.

### 9.3 Proposed entity IDs

- Default lantern IDs are fixed: `L1` through `L5`.
- Default mote IDs: `M1`, `M2`, … in default-world creation order.
- Default Shade IDs: `S1`, `S2`, … in default-world creation order.
- Explicit scenario Shade IDs are preserved.
- Missing scenario Shade IDs are assigned in scenario array order, choosing the lowest available positive `S<n>` not already reserved by any explicit ID.
- Automatically spawned Shades receive the next monotonically increasing unused `S<n>` ID.
- IDs are never reused after an entity is removed.
- Snapshot arrays and same-tick entity event lists use stable ascending ID order.
- If dropped motes are recreated, assign the next unused mote ID deterministically.

The contract only requires deterministic IDs and permits scenario Shade IDs; the exact naming/allocator policy above is a proposal.

### 9.4 Proposed random spawn behavior

The PRD says motes and Shades appear, while the scenario flags control automatic random generation. It does not specify rates or spawn distributions. Proposed defaults must be deterministic and written to assumptions:

- Use fixed spawn intervals measured in simulation ticks, not wall time.
- Use a deterministic list of candidate island positions or seeded sampling within the circular island.
- Reject candidate points outside the island or inside forbidden lantern safe zones using deterministic bounded attempts.
- `random_motes: false` disables autonomous mote spawns.
- `random_shades: false` disables autonomous Shade spawns.
- Scenario `motes`/`shades` arrays replace initial lists, but do not implicitly disable later autonomous spawning if the corresponding random flag is true.
- The exact interval, count cap and island radius remain balance assumptions to choose and test.

## 10. Exact JSONL output contract

Output is UTF-8 JSON Lines: one JSON object per line. The only record types are `snapshot`, `event`, and `end`. No metadata records, `run_id`, event sequence numbers, schema-version fields, debug fields or additional keys.

### 10.1 Snapshot

Write snapshot at tick `0`, then after each completed tick divisible by `snapshot_every`.

Exact required top-level shape:

```json
{
  "type": "snapshot",
  "tick": 120,
  "sim_tick": 120,
  "state": "playing",
  "time_left_s": 298.0,
  "score": 20,
  "player": {
    "pos": [0.0, 0.0, 12.0],
    "flames": 3,
    "carried": 2
  },
  "lanterns": [
    {
      "id": "L1",
      "pos": [0, 0, 25],
      "lit": false,
      "deposited": 0
    }
  ],
  "shades": [
    {
      "id": "S1",
      "pos": [30.1, 1.0, 2.0],
      "state": "chase"
    }
  ],
  "motes_active": 19
}
```

Rules:

- `tick` and `sim_tick` both equal completed gameplay steps.
- `state` is `playing`, `won`, or `lost`.
- `time_left_s` is derived from `night1_duration_s - sim_tick / 60`, except scenario may override initial time at tick 0; subsequent values subtract elapsed ticks from that initial scenario time. This means the runner should store the scenario-selected initial duration/time budget as the time origin.
- Player has exactly `pos`, `flames`, `carried`.
- Each lantern has exactly `id`, `pos`, `lit`, `deposited`.
- Each Shade has exactly `id`, `pos`, `state`; `stunned` must be used while stunned. Other state names are implementation-defined.
- `motes_active` is count of currently active motes.
- Coordinates are rounded to 3 decimal places for output.
- `motes` array is optional/recommended, not mandatory. Proposed output omits it to avoid extra fields.
- Lantern and Shade arrays are sorted deterministically by ID.

### 10.2 Event

Exact outer shape:

```json
{"type":"event","tick":131,"name":"mote_picked","data":{"carried":3}}
```

Only these event names and payload keys are allowed:

| Event name | Exact data payload |
|---|---|
| `mote_picked` | `{"carried": n}` |
| `deposit` | `{"lantern_id": "L1", "amount": n, "deposited": n}` |
| `lantern_lit` | `{"lantern_id": "L1"}` |
| `pulse` | `{"stunned_ids": ["S1"]}` |
| `player_hit` | `{"by": "shade" \| "fall", "flames": n, "dropped": n}` |
| `shade_spawned` | `{"id": "S3"}` |
| `game_over` | `{"result": "won" \| "lost", "reason": "all_lit" \| "dawn" \| "no_flames"}` |

- Every event generated in input step `k` has `tick = k+1`.
- Events are written immediately after the simulation step and before that tick's cadence snapshot.
- `stunned_ids` is sorted by stable Shade ID.
- Same-tick event order follows the chosen deterministic subsystem order; no sequence field is added.
- Do not emit an event for a mechanic that does not occur (e.g. no fall event when fall is disabled).
- Scenario initialization never emits events.

### 10.3 End

The final line is always:

```json
{"type":"end","ticks":4800,"state":"won","score":1730}
```

It has exactly four keys: `type`, `ticks`, `state`, `score`.

- `ticks` is actual completed steps, less than requested if terminal early.
- `state` is `playing`, `won`, or `lost`.
- `score` is final score.
- Write after any events and any cadence snapshot for the final executed tick.
- Do not add any line after `end`.
- No unscheduled final snapshot is required.

### 10.4 Serialization and determinism

- Use one serializer path for both modes.
- Keep object key insertion order fixed in record builders.
- Sort entity arrays and event ID arrays before serialization.
- Quantize coordinates to three decimal places only at output boundary; retain canonical simulation precision internally.
- Avoid non-finite JSON numbers.
- Same seed/scenario/inputs must produce byte-identical JSONL, including line order and IDs.
- JSON lexical formatting for numbers is not prescribed beyond coordinate rounding; choose a single stable serializer and test repeat-run byte identity.

## 11. Scoring design

Contract supplies five score rates but does not fully specify event-to-score timing or rounding for fractional remaining time. Proposed policy:

- Add `per_mote` once for every successfully collected mote.
- Add `per_lantern` once when an unlit lantern transitions to lit.
- Add `per_stun` once per Shade that transitions from a non-stunned state into stunned because of a valid pulse.
- On winning only, add `floor(time_left_s) * per_second_left`.
- On winning only, add `flames_remaining * per_flame_left`.
- No score is awarded during scenario construction.
- Depositing partial light does not award `per_lantern`; only the transition to lit does.
- A Shade already stunned does not award another stun score if hit by a later pulse.
- Score is an integer under this proposed policy.

All of these event/score details beyond the field descriptions are assumptions and must be explicitly documented.

## 12. Acceptance-test matrix

Tests must execute the real simulation core through headless mode. Do not substitute canned JSONL output.

| ID | Area | Setup/input | Required assertion |
|---|---|---|---|
| AT-01 | Default bootstrap | No scenario, no inputs, short ticks | Tick-0 snapshot exists; default player feet `(0,0,0)`; state playing; score 0; end is final. |
| AT-02 | Night layout | Default state | Five lanterns exist with IDs `L1`–`L5`. |
| AT-03 | Tick 0 | Scenario changes player/lantern state | Snapshot 0 reflects scenario before any input; no event and no score from setup. |
| AT-04 | Tick numbering | Input frame at tick 0 triggers a pickup | Resulting event has tick 1; snapshot at tick 1 reflects changed state if cadence is 1. |
| AT-05 | Exact step count | No terminal condition, `--ticks N` | Exactly N steps; end `ticks` equals N. |
| AT-06 | Early stop | Scenario makes a terminal outcome occur | Runner stops at terminal step; end ticks equals actual completed steps. |
| AT-07 | Time | Check ticks 0, 1, 60 and dawn boundary | Remaining time equals initial time budget minus `sim_tick/60`. |
| AT-08 | Snapshot cadence | `snapshot_every=10`, run 25 ticks | Snapshots at 0, 10, 20; end last; no snapshot at 25 unless 25 is divisible by cadence. |
| AT-09 | Snapshot default | Omit `--snapshot-every` | Cadence defaults to 10. |
| AT-10 | Event ordering | Cause multiple events in one step | Event order follows documented subsystem/ID ordering; snapshot follows events. |
| AT-11 | Input defaults | No inputs file | Player remains idle; all buttons false. |
| AT-12 | Input persistence | Change move/yaw/button once, omit fields later | Omitted fields retain previous values. |
| AT-13 | Input frame ordering | Duplicate/decreasing frame ticks | Exit 2; diagnostic on stderr. |
| AT-14 | Input validation | Invalid move dimension/range, non-finite yaw, non-boolean button | Exit 2. |
| AT-15 | Movement yaw 0 | Move +Z/+X at yaw 0 | World axes match contract. |
| AT-16 | Movement yaw 90 | Use cardinal input at 90 degrees | Sign and axis rotation match exact formula. |
| AT-17 | Movement normalization | Diagonal vector magnitude greater than 1 | Displacement magnitude does not exceed player speed/60. |
| AT-18 | Movement speed | Full input over 60 ticks without collision | Travel distance equals configured speed, subject to documented vertical/edge rules. |
| AT-19 | Jump edge | Hold jump true for multiple frames/ticks | Only one jump activation until false then true. |
| AT-20 | Interact edge | Hold interact true | Only one deposit activation; false then true allows another. |
| AT-21 | Pulse edge | Hold pulse true | Only one pulse activation until release/re-press. |
| AT-22 | Mote pickup | Place mote exactly at pickup radius | Pickup occurs because radius comparison is inclusive. |
| AT-23 | Mote outside radius | Place mote just outside radius | No pickup. |
| AT-24 | Capacity | Player at carry capacity with nearby mote | No pickup beyond capacity. |
| AT-25 | Pickup event/score | Collect one or more motes | Exact `mote_picked` payload and per-mote score. |
| AT-26 | Deposit range | Lantern exactly at interact radius | Interaction eligible. |
| AT-27 | Deposit amount | Carried amount less than remaining lantern cost | Deposit amount and deposited count match selected policy. |
| AT-28 | Lantern lit | Deposit reaches lantern cost | `deposit`, then `lantern_lit`; lantern lit once; score once. |
| AT-29 | Scenario lit lantern | Scenario sets `lit:true` | Tick-0 lit state; no `lantern_lit`; no lantern score. |
| AT-30 | Pulse insufficient cost | Flames below pulse cost | No pulse activation, cost, stun or pulse event. |
| AT-31 | Pulse cooldown | Two pulse edges within cooldown | Second activation rejected. |
| AT-32 | Pulse boundary | Shade exactly at pulse radius | Shade is eligible (inclusive). |
| AT-33 | Pulse event | Valid pulse with affected Shades | Exact `pulse` payload; IDs sorted. |
| AT-34 | Pulse empty targets | Valid pulse with no eligible Shades | Assert behavior according to approved assumption; if valid pulse emits event, payload is empty list. |
| AT-35 | Pulse effects | Eligible Shade | Push distance, stun duration and `stunned` state match tuning. |
| AT-36 | Stun score | Pulse hits one or multiple Shades | Score only for newly stunned Shades. |
| AT-37 | Shade chase | Active Shade separated from player | Shade moves toward player by configured speed per tick. |
| AT-38 | Safe radius | Lit lantern between Shade and player | Shade does not enter horizontal safe radius. |
| AT-39 | Shade hit | Shade within hit radius | Flame count decreases; exact `player_hit` payload. |
| AT-40 | Invulnerability | Repeated contact during invulnerability | No repeated hit until protection expires. |
| AT-41 | Hit drop | Carried motes and configured drop ratio | Dropped count matches approved rounding rule; active mote count updates. |
| AT-42 | Fall disabled | `fall_enabled=false` | No fall damage and no `by:"fall"` event. |
| AT-43 | Shade spawning off | `random_shades=false` | No autonomous Shade spawn event. |
| AT-44 | Shade spawning on | `random_shades=true`, fixed seed | Spawn timing/position/IDs repeat exactly. |
| AT-45 | Mote spawning off/on | Toggle `random_motes` | Off prevents automatic spawn; on follows documented deterministic schedule. |
| AT-46 | Scenario replacement | Scenario supplies `motes: []` / `shades: []` | Initial lists are empty, subject only to enabled later random spawns. |
| AT-47 | Scenario overlay | Update one lantern | Other lanterns retain defaults. |
| AT-48 | Scenario IDs | Explicit and missing Shade IDs | Explicit IDs preserved; missing IDs unique and deterministic. |
| AT-49 | Scenario validation | Invalid JSON, bad vector, unknown lantern, duplicate Shade ID | Exit 2; useful stderr; no success end record. |
| AT-50 | Win | Light all five lanterns | One `game_over` won/all_lit; win score applied once; end state won. |
| AT-51 | No-flames loss | Reduce flames to zero | One `game_over` lost/no_flames; end state lost. |
| AT-52 | Dawn loss | Let time reach zero before win | One `game_over` lost/dawn; end state lost. |
| AT-53 | Terminal precedence | Simultaneous win/damage/dawn fixture | Behavior matches approved precedence assumption. |
| AT-54 | Score | Exercise each score source | Final score equals sum of event awards and approved win bonuses. |
| AT-55 | End record | Normal, win, loss, zero-tick runs | Exactly one end record, always final, exact keys only. |
| AT-56 | Output schema | Parse every JSONL line | Only snapshot/event/end; no extra keys; exact payload keys. |
| AT-57 | Coordinate output | Non-three-decimal internal positions | Serialized coordinates rounded to three decimals. |
| AT-58 | Determinism | Repeat same seed/scenario/inputs twice | Output files byte-identical. |
| AT-59 | Entity order | Create/remove entities in varied sequences | Snapshot/event ID ordering stable and deterministic. |
| AT-60 | Headless constraints | Run on macOS/Linux using headless command | No window/GPU/viewport required; exits correctly. |
| AT-61 | Graphical parity | Feed equivalent tick-indexed trace to graphical driver and headless core | Canonical simulation states/events match; rendering does not mutate state. |
| AT-62 | Restart | Win/lose then restart in graphical mode | New run returns to default Night-1 state with score/timers/entities reset. |
| AT-63 | Delivery | Clean clone and README commands | Public repo runs with at most three documented setup/run commands; `phase-1` tag exists. |
| AT-64 | Evidence | Capture actual run/test artifacts | Evidence folder contains verifiable screenshots/logs and AI/assumption notes. |

## 13. Critical hidden-test risk matrix

| Risk | Failure mode | Prevention |
|---|---|---|
| Tick off-by-one | Event labeled `k`, or tick-0 snapshot after input | Runner owns tick count; test tick 0 and tick 1 explicitly. |
| Wrong fixed timestep | Uses frame delta or wall clock | Core receives one fixed tick only. |
| Snapshot cadence | Missing tick 0 or extra terminal snapshot | Centralize snapshot scheduling. |
| Missing final end | Early terminal branch exits before final record | Single end-record path after loop. |
| Extra JSONL keys | Strict contract comparison fails | Dedicated record builders with explicit whitelisted keys. |
| Wrong event payload | Extra/missing key or wrong event name | Typed event constructors and schema tests. |
| Scenario side effects | Initial lit lantern awards score/event | Loader only assigns state. |
| Input persistence | Omitted field resets to default | Merge partial frames into persistent state. |
| Repeated edge actions | Held true retriggers every tick | Previous/current button edge tracking. |
| Yaw sign/order | Movement rotates in wrong direction | Copy formula literally; cardinal yaw tests. |
| Distance metric | Uses 3D distance or collider radii | Shared XZ distance helper; inclusive `<=`. |
| Engine physics dependency | Headless and graphical results diverge | Core geometry and deterministic integration. |
| RNG drift | Global RNG or inconsistent draw order | Explicit PRNG and one canonical stream. |
| ID instability | IDs depend on node order or UUID | Stable allocator; no Node instance IDs. |
| Timer off-by-one | Stun/invulnerability loses a tick immediately | Define timer lifecycle and boundary tests. |
| Scenario overlay error | Lantern list replaced instead of update-by-ID | Dedicated overlay semantics. |
| Incorrect tuning | Contract values differ from actual code | Config is single source of truth; test every field. |
| Exit code | Invalid scenario/input returns 1 | Map those validation failures to 2. |
| Float drift | Repeated time subtraction accumulates error | Derive time from tick count. |
| Output nondeterminism | Dictionary order/float formatting differs | Stable arrays, stable serializer and byte-repeat test. |
| Unsupported GPU use | Headless fails on server/CI | `godot --headless`; no viewport/renderer in headless path. |

## 14. Prioritized 60-minute implementation sequence

This is a time-boxed target, not a guarantee that a complete polished game can be finished in 60 minutes. Correctness and testability take priority over visual polish.

| Time | Priority | Work | Exit criterion |
|---|---|---|---|
| 0–5 min | P0 | Verify project opens; create exact `game.contract.json`; define commands and config reader. | Contract parses; every tuning key mapped. |
| 5–12 min | P0 | CLI parser, scenario/input JSON validation, JSONL record builders. | Invalid scenario/input exits 2; tick-0 and end output work. |
| 12–22 min | P0 | State model, scenario overlay, input timeline, fixed-tick runner, deterministic PRNG/IDs. | Tick semantics, persistence and deterministic repeat pass. |
| 22–35 min | P0 | Movement, pickup, deposit, lantern lighting, score, pulse/stun/push. | Core interaction acceptance tests pass. |
| 35–43 min | P0 | Shade chase, safe zones, hit/invulnerability, win/loss and time. | Win/loss and damage tests pass. |
| 43–50 min | P0 | Complete headless fixtures and output verification. | Required event and schema matrix passes. |
| 50–56 min | P1 | Minimal 3D island, Mây, lantern/mote/Shade visuals, camera and HUD. | Graphical game is playable and uses shared core. |
| 56–60 min | P1 | Restart, README, evidence, AI journal, clean-clone smoke test, Git tag. | Submission checklist complete or remaining work explicitly recorded. |

If time is insufficient, do not fake headless behavior or hard-code canned JSONL. Preserve the real simulation core, exact contract and evidence first.

## 15. Submission checklist

- [ ] Public repository.
- [ ] Root `game.contract.json`, contract version `1.0`.
- [ ] Every tuning field present and equal to actual runtime values.
- [ ] Headless command works on macOS/Linux without window/GPU.
- [ ] Headless CLI accepts required and optional arguments exactly.
- [ ] Invalid scenario/input JSON/schema exits `2`.
- [ ] Snapshot tick 0 is after scenario setup and before input.
- [ ] 60 Hz fixed simulation and exact tick/event numbering.
- [ ] Persistent inputs and rising-edge actions.
- [ ] Exact snapshot/event/end JSONL schemas; no extra fields.
- [ ] Deterministic repeated output including IDs.
- [ ] Graphical and headless modes share simulation core.
- [ ] Full Night 1 can be played to win or loss.
- [ ] HUD, score and replay work.
- [ ] README installation/run uses at most three commands and explains controls/scoring.
- [ ] Evidence, assumptions and AI-use journal are included.
- [ ] AI harness (`AGENTS.md` or equivalent) is included.
- [ ] Git tag `phase-1` points to the final submission commit.

## 16. Approval gate

This document is a plan only. No gameplay implementation should begin until the user approves:

1. The proposed tuning values.
2. The deterministic PRNG and entity-ID policy.
3. The within-tick subsystem order and timer convention.
4. The deposit, hit/drop, pulse, scoring and terminal-precedence assumptions.
5. The random spawn cadence/distribution and default world layout.

After approval, implement in the prioritized sequence and report actual test evidence. Do not claim a test passed unless it was executed.
