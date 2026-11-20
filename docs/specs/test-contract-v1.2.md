# Test Contract v1.2

`game.contract.json` declares Contract `1.2`. In addition to v1.1, tuning exposes fuel maximum/decay/refill, relight, drain, low-fuel, capacity, win-ratio, and 240/270/300-second night values.

Lantern snapshots include `fuel` rounded to one decimal, `ever_lit`, and `relit_count`; player snapshots include `capacity`; Shades may be `drain` and include `target_lantern_id`. Scenarios accept `player.successful_lights`, `lantern.fuel`, `lantern.ever_lit`, and `shade.target_lantern_id`. A scenario-lit lantern without fuel defaults to 100.

New events are `refuel {lantern_id, amount, fuel}`, `lantern_out {lantern_id}`, and `fuel_drain {lantern_id, shade_id, fuel}`. `lantern_lit` adds `relight`; `game_over` can use `dawn_survived`. `all_lit` is no longer emitted.
