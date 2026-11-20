# Test Contract v1.3

`contract_version` is `1.3`; all prior headless gameplay fields remain unchanged. `game.contract.json` adds:

- `bench_cmd`: accepts `--seed 42 --duration 30 --out bench.json`, renders the fixed benchmark scene, warmups three seconds, and writes frame, timing, memory, renderer, OS, and VSync fields.
- `soak_cmd`: accepts `--seed 7 --nights 10 --out soak.json`, rotates 1→2→3 in one process and writes crash/result/memory/duration fields.

`run_cmd --export-leaderboard out.json` writes `{ "entries": [...] }` in current leaderboard sort order.
