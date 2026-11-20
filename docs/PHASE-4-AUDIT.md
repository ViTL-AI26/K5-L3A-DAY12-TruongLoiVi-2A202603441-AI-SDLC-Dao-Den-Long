# Phase 4 release audit

## Implemented in the repository

- Contract v1.3 commands, benchmark/soak JSON schema, ten-night soak runner, and local leaderboard persistence/export.
- Graphical main menu; leaderboard viewer; persisted mouse sensitivity and volume controls.
- Accessibility: saved colorblind, reduced-motion and large-text modes; keyboard rebinding with duplicate-key feedback and restore defaults; subtitle/directional alerts for Shade spawn, wind warning and the final ten seconds.
- Procedural audio cues for pickup, lantern, pulse, hit, jump, dash, Shade spawn, win and loss. They are visual-layer only and do not change deterministic simulation output.
- Unlit-lantern torn-paper detail plus low-fuel blink/scale cues.
- Dockerfile and portable headless runner instructions in `docs/RELEASE.md`.
- Prior headless regression suite, documentation, license, credits, benchmark and soak evidence.

The committed soak run reports 10 nights, 0 crashes and no RSS growth. A 30-second graphical 1280×720 run with VSync off completed on the local Apple M4/Metal Compatibility renderer and produced 148.75 avg FPS / 49.50 p1-low / 30 ms load; `bench.json` contains that measurement. It is valid graphical evidence, but a different announced instructor target should still be remeasured there if required by the submission environment.

## Remaining external/manual release gates

1. **Instructor-target benchmark validation:** the included `bench.json` is a real graphical 1280×720/VSync-off local run. Run `bench_cmd` again only if the instructor announces a different required target machine, then replace the evidence with that target measurement.
2. **GitHub Release publication:** the verified ARM64 Docker image `dao-den-long:v1.0.0` was built and smoke-tested; its exported tar is `dao-den-long-v1.0.0-arm64.tar` (184 MB, SHA-256 `4d68ecd32e1190aae493370e12bf3c5cce900a7626b67387cf6b9ce74c3cb219`). GitHub CLI/account release authority is unavailable in this session, so create GitHub Release `v1.0.0` and attach that tar (or another exported platform build) from an authorized account.
3. **Demo media (explicitly excluded by requester):** `docs/demo/demo.mp4` predates this release. It was intentionally not replaced in this task.
4. **Manual UI check:** exercise the graphical menu/settings/rebinding screen at 1280×720 once on the target machine. The implementation is present; this is a final human visual/usability check rather than a missing code feature.
