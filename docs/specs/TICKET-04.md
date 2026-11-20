# TICKET-04 — Bình minh v1.0.0

Contract v1.3 preserves gameplay Contracts v1.0–v1.2 and adds release tooling. `bench_cmd` produces the prescribed frame-performance JSON after a three-second warm-up; `soak_cmd` runs deterministic rotating nights in one process and reports RSS; `run_cmd --export-leaderboard out.json` exports local rank data.

The local leaderboard keeps ten valid `[A-Za-z0-9_]` names (3–12 characters), ordered by score descending and ISO achievement time ascending on ties. The graphical presentation provides saved colorblind mode and fuel/off-lamp visual cues. See `phase-4-plan.md` for acceptance/evidence and `PHASE-4-AUDIT.md` for release items requiring target-machine or GitHub execution.
