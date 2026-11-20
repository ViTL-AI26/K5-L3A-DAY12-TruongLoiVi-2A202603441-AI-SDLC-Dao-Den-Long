# Phase 4 acceptance record

| Area | Delivered evidence |
| --- | --- |
| Benchmark | `scripts/benchmark/main.gd`, `bench.json`; fixed entity count/camera/warm-up/statistics. |
| Soak | `scripts/soak/main.gd`, `soak.json`; ten sequential deterministic nights and RSS report. |
| Leaderboard | `LocalLeaderboard`, terminal name capture, main-menu `L` viewer, run-command export. |
| Accessibility | persisted colorblind/reduced-motion/large-text settings, conflict-safe key remapping + restore defaults, shade/wind/countdown subtitles and directional cue, visible fuel/off-state/torn-paper cue. |
| Audio/settings | saved mouse sensitivity and volume; procedural cues for pickup, lantern, pulse, hit, jump, dash, spawn, win and loss. |
| Documentation | README commands, Docker runner/release instructions, Contract v1.3, changelog, credits/license, retro, evidence/audit. |
| Release gate | `PHASE-4-AUDIT.md` identifies target-machine benchmark and GitHub release actions. |
