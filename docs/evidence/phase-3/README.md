# Phase 3 verification evidence

Run on 2026-11-21:

```bash
bash tests/run_contract_checks.sh
```

Result: passed. The harness executes retained Phase 1–2 coverage plus independent v1.2 JSONL fixtures for first light/fuel, Shade drain telemetry, and `dawn_survived`.

```bash
godot --headless --path . --script res://tests/test_simulation.gd
```

Result: passed. The direct suite checks integer fuel decay, relight cost/score/capacity, drain rate, new night durations, and dawn-only victory.

Maximum Night 3 duration (18,000 ticks) was also run headlessly to completion in about 2.3 seconds, well below the 30-second contract limit. Its final record was `{"score":0,"state":"lost","ticks":18000,"type":"end"}`.
