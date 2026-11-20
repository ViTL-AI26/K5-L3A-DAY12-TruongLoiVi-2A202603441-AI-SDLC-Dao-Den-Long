# Phase 2 verification evidence

Verified locally on 2026-11-20 with Godot 4.7.2:

```bash
bash tests/run_contract_checks.sh
```

Result: passed. This executes the core unit suite plus JSONL scenarios for pickup/deposit regression, dash + pause, Gió Lạc stealing, Bùa Gió pickup, wind disablement, invalid-input exit code, and deterministic repeated output.

```bash
time godot --headless --path . --script res://scripts/headless/main.gd -- \
  --seed 20261120 --night 3 --ticks 21600 --snapshot-every 21600 \
  --out /tmp/phase2-night3-full.jsonl
```

Result: exit 0 in 1.706 seconds (under the 30-second contract limit). The final record was `{"score":0,"state":"lost","ticks":21600,"type":"end"}`.

The Godot editor parse command also exited 0. Its `res://.godot` and `user://logs` write diagnostics were caused by the restricted verification sandbox, not by a project parse failure.
