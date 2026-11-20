# TICKET-03 — Đèn cạn dầu

Ticket-03 supersedes Contract v1.1 where it conflicts and establishes Contract v1.2. Lanterns have 100 fuel represented internally as 6,000 integer fuel ticks. Lit lanterns decay by one tick per simulation step; a Shade in `drain` removes five more ticks. At zero fuel a lantern emits `lantern_out`, becomes unlit, resets `deposited`, and preserves `ever_lit`.

Interaction selects the nearest eligible lantern (ID tie-break). An unlit first light costs 10 motes; an `ever_lit` relight costs 5. A lit non-full lantern accepts `ceil((100-fuel)/10)` motes, adds 10 fuel per mote, and emits `refuel`. Safe zones exist only at fuel >= 30.

Nights last 240, 270, and 300 seconds. There is no early all-lit victory. At dawn, living Mây wins only when at least `ceil(0.6 × lantern count)` are lit; zero Flames takes precedence. Capacity is `min(20, 10 + 2 × successful_lights)`.

Snapshots include each lantern's `fuel`, `ever_lit`, and `relit_count`; player `capacity`; and Shade `drain` state. Scenario lantern overlays accept `fuel` and `ever_lit`; player accepts `successful_lights`; Shade scenarios accept `target_lantern_id`.
