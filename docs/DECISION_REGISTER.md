# Decision register and status freeze (updated for latest visual layout, 2026-11-15)

**Authority:** coordinator's direct statements > coordinator-confirmed agent interviews > `SHARED_BASELINE.md` v2.0 > these technical implementation choices > old agent proposals. This is a record, not a request for another multi-agent design round.

| ID | Decision | Status | Owner | Cross-doc effect |
|---|---|---|---|---|
| INT-01 | More recipes are planned; three existing recipes only *currently authored*; implement data-driven extension without inventing future dish content | CONFIRMED 2026-11-15 | Coordinator/B/D/E | Dynamic recipe Resources, data-driven `unlock_day`; avoid three-recipe cap |
| INT-02 | Fixture purchase AND resale planning-only; installation/removal immediate; safely removable purchased tables and utilities may be resold | CONFIRMED 2026-11-15 | Coordinator/D | No service-time fixture shipment/state |
| INT-03 | Starting washer contextual rice/plate washing; existing prep/work table also supports chopping | CONFIRMED 2026-11-15 | Coordinator/B | One physical fixture, distinct logical hit zones if necessary |
| INT-04 | Online cap = number simultaneously OPEN limited to initial day dine-in quota; 3 pickup spots with outside overflow; not total per day | CONFIRMED 2026-11-15 | Coordinator/C | Acceptance predicate and driver FIFO |
| INT-05 | Shopping in SERVING does NOT pause service/arrival/order/delivery clocks | CONFIRMED 2026-11-15 | Coordinator/A/E | Modal input gating only |
| A-01 | Godot 4, GDScript, Windows/Linux desktop, no save; persistent root | CONFIRMED GDScript/target/no-save; root technical default | Coordinator/A | Whole project |
| A-02 | Remote interactable click teleports to cardinal neighbor and activates in one click; floor click teleports only | CONFIRMED | Coordinator/A/B/E | Input |
| A-03 | Auto-close waits for **physical dine-in and accepted online** to drain | CONFIRMED via C-07 | Coordinator/A/C | No phantom canceled accepted orders |
| A-04 | Reset outside-fridge food/dirty dishes at close; pending deliveries refund once; no manual close | CONFIRMED | Coordinator/A/B/D | Phase transaction |
| B-01 | Exact prefix acceptance, invalid keystrokes ignored, full word autoexecutes, click cancels prefix | CONFIRMED | Coordinator/B/E | One parser |
| B-02 | One held aggregate, one item per kitchen work table; plate first, any component plating order | CONFIRMED | Coordinator/B | Food state |
| B-03 | Physical fridge 2×3 slots, box 3×5, ingredient duplicates across slots; raw storage only | CONFIRMED | Coordinator/B/D | Replaces old distinct-*types* baseline |
| B-04 | Three authored recipes; rice prep; instant cook steps; finite plates; dirty washer; online plate immediately clean | CONFIRMED | Coordinator/B/C | Data and plate ledger |
| C-01 | First diner at t=0, subsequent every 20s; 100s from spawn including outside; FIFO clean-table admission | CONFIRMED | Coordinator/C | Clock/order state |
| C-02 | One menu dish/order, price-biased to cheaper; wrong table/dish rejected | CONFIRMED, weighting formula TUNING | Coordinator/C/D | ServicePlan |
| C-03 | 60s online clock on voluntary acceptance; online cutoff at day queue <=2; 3 driver spots, overflow cannot be served | CONFIRMED | Coordinator/C/E | Driver world interaction |
| C-04 | Each missed order 1 or 2 customer debt with 50/50 chance; perfect day heals 1 | CONFIRMED | Coordinator/C/D | DayReport to Run |
| D-01 | Day 1 initial kit; +4 base arrival quota per day; seven-day cash-after-power deadline; optional extra days after win | CONFIRMED | Coordinator/D | Config and lifecycle |
| D-02 | Purchases targeted at selected storage container; planning immediate, service 100s, pending cancel full refund | CONFIRMED | Coordinator/B/D/E | Destination-ID APIs |
| E-01 | World-first UI, driver and diner rings, above-target prompt, slot-first shop, fixed UI information hierarchy | CONFIRMED | Coordinator/E | UI only |
| VIS-01 | Latest rough layout reserves **left vertical UI band**, then **dine-in waiting lane**, then restaurant world; kitchen mainly upper, dining mainly lower. Old 10×9 assumption superseded. Exact tile counts/world coordinates/viewport are **not** approved by sketch. | CONFIRMED DIRECTION / DIMENSIONS PROVISIONAL | Coordinator/E/A | Layout reference + Godot composition + fit tests |
| VIS-02 | World and UI remain same main viewport (World Node2D + CanvasLayer); choose one transform/camera approach, preserve world click coordinates and block GUI click-through; planning panels may temporarily overlap world. | TECHNICAL DEFAULT | Integrator/A/E | `WORLD_LAYOUT_AND_VIEWPORT.md` / input fit |
| TECH-01 | One persistent GameRoot, KitchenController, ServiceController, RunController, GameUI; no autoload; typed public interfaces | TECHNICAL FREEZE | Integrator | Architecture |
| TECH-02 | One service elapsed clock in GameRoot, deterministic `advance_service_time(now)` per owner, **no competing Godot Timers** | TECHNICAL FREEZE | Integrator | Time handling / tests |
| TECH-03 | One 4-argument plate consumption call; table/driver-specific C serving entrypoints; ID-based once-only accounting | TECHNICAL FREEZE | Integrator | B/C/D |
| TECH-04 | Rejected/incomplete requests never mutate money/food/order; later reruns idempotent | TECHNICAL FREEZE | Integrator | Acceptance |

## Reversible gameplay defaults pending playtests (NOT claimed coordinator-approved)

1. Trash destroys food components but returns the **same clean empty plate** to held item if a plate was present. Never delete a purchased reusable plate.
2. `masak` deposits one washed `beras` into single cooker output, `nasi` retrieves it with empty hand. Rice cook/other prep are instant. First prep table's **staging click area** and **chop typed-interaction area** are distinct hit zones of the same free fixture, so selecting `potong` never accidentally stages the held vegetable.
3. In planning, selling a fixture is allowed if its operational state can be safely removed (e.g., storage empty/no reservation; rack plates all safe/clean); a **starter gifted fixture resells for 0** because its paid amount was 0, preventing unintended free money. Bought fixtures return a configurable fraction of actually paid purchase price. Selling the last useful fixture may make a run unwinnable, intentionally; no safety-net rule.
4. A paid shipment reservation is pinned to chosen box/fridge. No partial or cross-container spill. New slot assignment fills matching partial slots then empty slots by stable slot order.
5. Inverse dine-in price weights (`1 / price`) as initial order preference; the next online offer is stable until accepted, then regenerated. A zero-arrival, zero-failure day heals one debt point. Online percent initially 70; resale fraction initially 50; all are editable TUNING.
6. Wrong table serve or too-late serve returns false with no changes; at equal deadline/tap timestamp expiry wins. Before a close check in a simulation tick, due paid deliveries are committed; if already DELIVERED at close, not refundable. All clocks run while shop UI is open.
7. Extra mode after Day 7 win has no **further mandatory** cash threshold by default. HUD may still show final Day 7 goal as achieved; no phantom new win requirements.
8. If fewer than seven approved recipes are currently loaded, unlock only loaded entries; a **content warning** identifies missing Day 4–7 entries. Do not fabricate or silently mark three recipes as a completed seven-day content plan.

Technical defaults can be adjusted by the sole developer when a concrete implementation limitation is demonstrated, keeping interfaces and tests consistent. Gameplay defaults above should be treated as documented provisional behavior and reviewed during playtesting, not mislabeled `CONFIRMED`.
