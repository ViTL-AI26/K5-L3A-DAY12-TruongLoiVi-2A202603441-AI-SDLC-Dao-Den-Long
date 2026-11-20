#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixtures_dir="$root_dir/tests/fixtures"
godot_bin="${GODOT_BIN:-godot}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lantern-contract.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

run_headless() {
  "$godot_bin" --headless --path "$root_dir" --script res://scripts/headless/main.gd -- "$@"
}

"$godot_bin" --headless --path "$root_dir" --script res://tests/test_simulation.gd

run_headless --seed 7 --night 1 --scenario "$fixtures_dir/pickup-scenario.json" --ticks 1 --snapshot-every 1 --out "$tmp_dir/pickup.jsonl"
run_headless --seed 7 --night 1 --scenario "$fixtures_dir/deposit-scenario.json" --inputs "$fixtures_dir/deposit-inputs.json" --ticks 2 --snapshot-every 1 --out "$tmp_dir/deposit.jsonl"
run_headless --seed 7 --night 1 --scenario "$fixtures_dir/win-scenario.json" --ticks 10 --snapshot-every 1 --out "$tmp_dir/win.jsonl"
run_headless --seed 123 --night 1 --ticks 90 --out "$tmp_dir/determinism-a.jsonl"
run_headless --seed 123 --night 1 --ticks 90 --out "$tmp_dir/determinism-b.jsonl"
cmp "$tmp_dir/determinism-a.jsonl" "$tmp_dir/determinism-b.jsonl"

if run_headless --seed 7 --night 1 --inputs "$fixtures_dir/invalid-inputs.json" --ticks 1 --out "$tmp_dir/invalid.jsonl"; then
  echo "Expected invalid inputs to fail with exit code 2." >&2
  exit 1
else
  status=$?
  if [ "$status" -ne 2 ]; then
    echo "Invalid inputs exited with $status, expected 2." >&2
    exit 1
  fi
fi

python3 - "$tmp_dir" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

def records(name):
    return [json.loads(line) for line in (root / name).read_text().splitlines()]

pickup = records("pickup.jsonl")
assert pickup[0]["type"] == "snapshot" and pickup[0]["tick"] == 0
assert pickup[1] == {"type": "event", "tick": 1, "name": "mote_picked", "data": {"carried": 1}}
assert pickup[-1] == {"type": "end", "ticks": 1, "state": "playing", "score": 10}

deposit = records("deposit.jsonl")
assert deposit[1] == {"type": "event", "tick": 1, "name": "deposit", "data": {"lantern_id": "L1", "amount": 5, "deposited": 5}}
assert deposit[2] == {"type": "event", "tick": 1, "name": "lantern_lit", "data": {"lantern_id": "L1"}}

win = records("win.jsonl")
assert win[0]["state"] == "playing" and win[0]["score"] == 0
assert win[1] == {"type": "event", "tick": 1, "name": "game_over", "data": {"result": "won", "reason": "all_lit"}}
assert win[-1]["type"] == "end" and win[-1]["state"] == "won" and win[-1]["ticks"] == 1
PY

echo "Contract checks passed."
