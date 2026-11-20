# Phase 4 release audit

Implemented and locally smoke-tested: Contract v1.3 commands, benchmark/soak JSON schema, ten-night soak runner, local leaderboard persistence/export, colorblind setting, prior headless regression suite, documentation, license, and credits.

Before external submission, still perform these environment/account-dependent actions:

1. Run `bench_cmd` on the instructor's graphical target (not headless) and confirm the required FPS/load thresholds; replace `bench.json` with that measurement if needed.
2. Create GitHub Release `v1.0.0` and attach an exported macOS/Linux build, static web build, or Docker image. This requires GitHub release authority and platform export templates not available in this workspace.
3. Record/replace `docs/demo/demo.mp4` with a current under-five-minute Phase 4 capture showing play, test, headless, benchmark, and soak.
4. Exercise the graphical settings/rebinding menu manually at 1280×720; action remapping and reduced-motion UI controls remain an extension item.
