# AGENTS.md — Đảo Đèn Lồng

## Authoritative documents
- docs/specs/PRD-0.md
- docs/specs/test-contract-v1.0.md
- docs/plans/phase-1-plan.md
- docs/specs/ASSUMPTIONS.md

Read these documents before implementation.

## Rules
1. Follow PRD-0 and Test Contract v1.0 exactly.
2. Do not invent or change required JSONL fields, event names or payloads.
3. Use one deterministic simulation core for graphical and headless modes.
4. Simulation runs at fixed 60 ticks per second.
5. Headless mode must not require a window or GPU.
6. Scenario setup must not emit events or award score.
7. Keep game.contract.json tuning values identical to actual implementation.
8. Same seed, scenario and inputs must produce identical output.
9. Test every implementation milestone before proceeding.
10. Do not claim tests passed unless they were executed.
11. Do not modify authoritative specifications without approval.
12. Keep changes focused; avoid unnecessary dependencies and complexity.

## Workflow
- Inspect existing files before editing.
- Explain the intended changes briefly.
- Implement only the requested milestone.
- Run relevant tests and report actual results.
- Stop and wait for approval before moving to the next milestone.
