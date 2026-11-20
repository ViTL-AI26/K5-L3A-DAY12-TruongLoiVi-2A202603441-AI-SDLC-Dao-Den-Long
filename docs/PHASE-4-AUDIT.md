# Phase 4 release audit

Implemented and locally verified: Contract v1.3 commands, benchmark/soak JSON schema, ten-night soak runner, local leaderboard persistence/export, colorblind setting, prior headless regression suite, documentation, license, and credits. The committed soak run reports 10 nights, 0 crashes, and no RSS growth. The committed benchmark runner completed 30 seconds in this environment and produced 144.9 avg FPS / 125.0 p1-low / 22 ms load, but that execution was headless and is not a substitute for the required graphical target-machine measurement.

Before external submission, still perform these environment/account-dependent actions:

1. Run `bench_cmd` on the instructor's graphical target (not headless) and confirm the required FPS/load thresholds; replace `bench.json` with that measurement if needed.
2. Create GitHub Release `v1.0.0` and attach an exported macOS/Linux build, static web build, or Docker image. This requires GitHub release authority and platform export templates not available in this workspace.
3. Record/replace `docs/demo/demo.mp4` with a current under-five-minute Phase 4 capture showing play, test, headless, benchmark, and soak.
4. Exercise the graphical settings/rebinding menu manually at 1280×720; action remapping and reduced-motion UI controls remain an extension item.

## Remaining implementation gaps found in final audit

These are not represented as complete:

1. **GitHub Release package:** no `v1.0.0` GitHub Release, executable/web/Docker artifact, or release attachment was created because this workspace has no GitHub CLI/account release authority.
2. **Benchmark validation:** rerun the committed `bench_cmd` with a real 1280×720 window and VSync disabled on the instructor's announced machine. Do not use the current headless number as final performance proof.
3. **Accessibility UI:** keyboard rebinding, duplicate-key conflict feedback, restore defaults, reduced-motion toggle, large-text toggle, and all required subtitles/directional indicators (Shade spawn, wind warning, final 10 seconds) are not implemented. The delivered colorblind mode and low-fuel cue cover only part of the requirement.
4. **Menu/settings/audio:** the leaderboard is available via `L` and end-state name input works, but a dedicated main-menu leaderboard/settings screen, persisted mouse/volume settings, and the Ticket-02 sound set are not implemented.
5. **Demo media:** `docs/demo/demo.mp4` predates this release and must be replaced with a current <5-minute capture of gameplay, tests, headless, benchmark, and soak.
6. **Visual detail:** an unlit lamp scales down and low fuel blinks, but the specified torn-paper visual is not modeled.
