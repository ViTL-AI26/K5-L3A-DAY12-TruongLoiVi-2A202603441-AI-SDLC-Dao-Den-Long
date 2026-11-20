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
run_headless --seed 7 --night 1 --scenario "$fixtures_dir/phase2-dash-pause-scenario.json" --inputs "$fixtures_dir/phase2-dash-pause-inputs.json" --ticks 6 --snapshot-every 1 --out "$tmp_dir/dash.jsonl"
run_headless --seed 7 --night 2 --scenario "$fixtures_dir/phase2-drifter-scenario.json" --ticks 1 --snapshot-every 1 --out "$tmp_dir/drifter.jsonl"
run_headless --seed 7 --night 2 --scenario "$fixtures_dir/phase2-charm-scenario.json" --ticks 1 --snapshot-every 1 --out "$tmp_dir/charm.jsonl"
run_headless --seed 7 --night 3 --scenario "$fixtures_dir/phase2-wind-disabled-scenario.json" --ticks 1801 --snapshot-every 1801 --out "$tmp_dir/wind.jsonl"
run_headless --seed 123 --night 3 --ticks 90 --out "$tmp_dir/determinism-a.jsonl"
run_headless --seed 123 --night 3 --ticks 90 --out "$tmp_dir/determinism-b.jsonl"
cmp "$tmp_dir/determinism-a.jsonl" "$tmp_dir/determinism-b.jsonl"

if run_headless --seed 7 --night 1 --inputs "$fixtures_dir/invalid-inputs.json" --ticks 1 --out "$tmp_dir/invalid.jsonl"; then
  echo "Expected invalid inputs to fail with exit code 2." >&2
  exit 1
else
  status=$?
  test "$status" -eq 2
fi

python3 - "$tmp_dir" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
def records(name):
    return [json.loads(line) for line in (root / name).read_text().splitlines()]
def events(name):
    return [r for r in records(name) if r['type'] == 'event']
def names(name):
    return [r['name'] for r in events(name)]

pickup = records('pickup.jsonl')
assert pickup[0]['night'] == 1 and pickup[0]['player']['vel'] == [0.0, 0.0, 0.0]
assert names('pickup.jsonl') == ['night_start', 'mote_picked']
assert next(e for e in events('deposit.jsonl') if e['name'] == 'deposit')['data']['amount'] == 10
assert names('dash.jsonl') == ['night_start', 'dash', 'paused', 'resumed']
assert any(r.get('type') == 'snapshot' and r.get('state') == 'paused' for r in records('dash.jsonl'))
assert names('drifter.jsonl') == ['night_start', 'drifter_steal']
assert names('charm.jsonl') == ['night_start', 'charm_picked']
wind = records('wind.jsonl')
assert wind[-2]['wind']['active'] is False
assert wind[-1]['type'] == 'end'
PY

echo "Phase 2 contract checks passed."
