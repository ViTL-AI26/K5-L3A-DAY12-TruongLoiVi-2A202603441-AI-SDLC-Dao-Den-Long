# TICKET-02 — Ba hòn đảo

## Authority

This is the implementation-facing transcription of the supplied Day 12 Ticket-02. It supersedes PRD-0 and Contract v1.0 only where the ticket says Contract v1.1.

## Fixed rules

- Simulation is 60 Hz. Run speed is 6 m/s, jump is 7 m/s, gravity is -20 m/s², and run acceleration/deceleration completes in at most six ticks.
- Dash is 14 m/s for 12 ticks with a 90-tick cooldown. A Wind Charm removes the cooldown while active.
- Mây carries at most 10 motes. Lanterns cost 10; Pulse costs 3, reaches 5 m from feet + 0.8 m, stuns Shades for 120 ticks, pushes 4 m in the first 15 ticks, and has a 180-tick cooldown.
- A lit lantern protects a 6 m radius. Shades move at 4 m/s (4.5 on Night 3), detect at 12 m and disengage at 18 m.
- Falls below Y=-10 lose a Flame and all motes, wait 60 ticks, then respawn at start with 90 ticks of invulnerability. Zero Flames loses immediately.
- Durations are 300, 330, and 360 seconds for Nights 1–3. Win takes precedence over dawn on the same tick.

## Maps and modes

- Night 1: 40 m circular Đảo Bến, five canonical lanterns, 24 spawn points.
- Night 2: two radius-28 islands at (0,0,0) and (70,0,0), bridge, two pads, six lanterns, one Charm.
- Night 3: radius-45 three-tier Đảo Chuông, jump pad, seven lanterns, two Charms, and 30-second wind cycles.
- Gió Lạc appears on Nights 2–3, chases at 7 m/s when Mây has five motes, steals up to three, and can be driven away by Pulse.

## Contract v1.1

`--night` accepts 1, 2, or 3. Snapshots carry `night`, `wind`, player velocity/grounded/timers, and `motes`, `drifters`, `charms`. Inputs add edge-triggered `dash` and `pause`; paused ticks advance only the wall tick and serialize `state: "paused"`. Scenarios support timer overrides, Shade state/timer, Drifters, Charms, random Drifter control, and wind control. The canonical Shade states are `spawning`, `wander`, `chase`, `recoil`, and `stunned`.
