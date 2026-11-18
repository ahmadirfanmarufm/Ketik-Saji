# Ketik Saji — Consolidated Coordinator Confirmation Checklist

**Date:** 2026-11-16 (updated 2026-11-18 for M5-A World Layout & Customer Seating approval and M5-A1 completion)
**Project state:** Milestones 0–4 (`M0`–`M4-C`) PASS in `main` @ `e5898bb` | **M5-A1 World Layout (`12×9`) IMPLEMENTED & VERIFIED (`10` headless suites, `913/913` assertions, plus `640×360` and `480×270` GUI viewport checks); M5-A2 Customer Seating (`ChairVisual`, `SeatAnchor`, customer seating changes) PENDING IMPLEMENTATION**
**Related review:** `docs/COORDINATOR_DECISION_REVIEW.md`, `docs/DECISION_REGISTER.md` (`VIS-01`–`VIS-04`)

---

## Immediate Next Actions (To Unblock Work Right Now)

1. **Start Track A3 immediately after a 5-minute schema sync (`TQ-01`):** `KitchenController`, `RunController`, and World owners confirm whether `unlock_day`/`dine_in_price` live in `RecipeEconomyEntry` vs. `RecipeDef` and whether `UtilityDef` carries `footprint: Vector2i = Vector2i(1, 1)`. **No viewport, World layout, or Movement decision blocks Track A3.**
2. **Unblock controller skeletons and Movement integration (`CC-01` / `TA-01`):** Coordinator, Movement programmer, and `KitchenController` owner agree whether Movement lives behind `KitchenController`'s frozen `ARCHITECTURE.md` §5 API (Option A) or splits into a separate `MovementController` (Option B).
3. **Schedule Milestone 0 World authoring & framing pass (`CC-03` / `TA-03`, `CC-02` / `TA-04`):** After confirming the minor `Decorations` node detail (`CC-05`), World, Service, Kitchen, Run, and UI owners place `OnlineStation` + `PlacementSlots` + `WorkTable` split targets and verify the `LeftHUDRegion` framing fit in `640×360`.

---

## A. Purpose and Current Status

Track A1 (documentation consistency audit) and Track A2 (`WorldGrid` init validation and `WorldMap`/`WorldRegistry` SceneTree cleanup, runtime-validated on Godot 4.7.2 with `SUMMARY fails=0`) have passed. **Track A3 (core enums and `.tres` schemas) has not started.**

This checklist consolidates every confirmed baseline decision, unresolved coordinator question, multi-programmer ownership agreement, provisional playtest default, and technical integration question into one working tracker. Its goal is to resolve shared contracts before Milestone 0 completion (`GameRoot`, controller skeletons, canonical `World` scene, `GameUI` blockout) and Milestone 1–4 implementation create avoidable rework.

Authority precedence remains unchanged (`CLAUDE.md`):
`Coordinator explicit decisions` > `docs/SHARED_BASELINE.md` > `docs/ARCHITECTURE.md` > `docs/DECISION_REGISTER.md` > `docs/systems/*.md` > `docs/WORLD_LAYOUT_AND_VIEWPORT.md` > `docs/IMPLEMENTATION_PLAN.md` / `docs/ACCEPTANCE_TESTS.md` > `CLAUDE.md` / `docs/CODING_STANDARDS.md` > this checklist.

---

## B. Decisions Already Established

The following **25** decisions and technical freezes are already confirmed in `docs/DECISION_REGISTER.md`, `docs/SHARED_BASELINE.md`, and `docs/ARCHITECTURE.md`. They are **not** open design questions, even where implementation is still pending.

| Reference | Confirmed Decision / Contract | Canonical Source | Implementation Status |
|---|---|---|---|
| `INT-01` | Recipes are data-driven; 3 recipes currently authored (`nasi_telor`, `nasi_ayam`, `nasi_komplit`), 4+ future recipes planned without inventing content in code | `docs/DECISION_REGISTER.md`; `docs/CONTENT_AND_TUNING.md` | Pending (Track A3 `.tres` / Milestone 5) |
| `INT-02` | Fixture purchase and resale are `PLANNING`-only and take effect immediately; safely removable tables and utilities may be resold | `docs/DECISION_REGISTER.md`; `docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md` §1, §3 | Pending (Milestone 4) |
| `INT-03` | Starter `wastafel` washer handles both `beras` and dirty plates by context; prep/work table is one fixture with separate staging click and `potong` chop targets | `docs/DECISION_REGISTER.md`; `docs/systems/01_INTERACTION_KITCHEN.md` §2 | Pending (Milestone 0 scene / Milestone 1) |
| `INT-04` | Concurrent `OPEN` online orders are capped at `day_queue_initial` (not 3 pickup spots and not a lifetime daily cap); 3 pickup spots + overflow FIFO are separate | `docs/DECISION_REGISTER.md`; `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §3 | Pending (Milestone 3) |
| `INT-05` | Opening `Belanja` or confirmation modals in `SERVING` never pauses `service_elapsed`, arrivals, orders, eating, or deliveries | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §3 | Pending (Milestone 0/3/4) |
| `A-01` | Godot 4 GDScript, Windows/Linux desktop, mouse+keyboard, Indonesian player-facing text, no save/load, persistent `GameRoot` | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §1 | Partial (`project.godot`, `game_root.tscn` exist; `game_root.gd` pending) |
| `A-02` | Floor left-click teleports only; remote interactable click teleports to nearest legal cardinal neighbor and selects/activates in the same click | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §7 | Pending (Milestone 1) |
| `A-03` | Auto-close requires all 4 drained conditions (`day_queue_remaining == 0`, empty outside dine-in queue, 0 in-shop diners, 0 `OPEN` online orders); no manual close | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §3 | Pending (Milestone 0/2/3) |
| `A-04` | At `CLOSING`: cancel/refund only `PENDING` shipments once, erase non-fridge food and dirty washer queue, retain raw fridge stock, reset clean plates/tables | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §3 | Pending (Milestone 2/4) |
| `B-01` | Single exact-prefix keyboard parser; invalid keys ignored + local UI shake; full valid command auto-executes without Enter; click elsewhere clears prefix | `docs/DECISION_REGISTER.md`; `docs/systems/01_INTERACTION_KITCHEN.md` §2 | Pending (Milestone 1) |
| `B-02` | One held item aggregate; one staged item per kitchen work surface; dishes start with a clean plate and accept prepared parts in any order | `docs/DECISION_REGISTER.md`; `docs/systems/01_INTERACTION_KITCHEN.md` §3 | Pending (Milestone 1) |
| `B-03` | Physical per-slot raw storage (`fridge` 2×3, `box` 3×5); duplicate ingredients across slots allowed; raw stock only; selected-container purchases never spill | `docs/DECISION_REGISTER.md`; `docs/systems/01_INTERACTION_KITCHEN.md` §1, §5 | Pending (Milestone 1/4) |
| `B-04` | Confirmed `beras` wash→cook→retrieve pipeline; instant prep steps; finite plate ledger; online serving returns same plate clean immediately | `docs/DECISION_REGISTER.md`; `docs/systems/01_INTERACTION_KITCHEN.md` §3–4 | Pending (Milestone 1/3) |
| `C-01` | Dine-in spawns at `t=0` then every `20s`; `100s` patience starts at spawn (including outside); FIFO admission to `CLEAN_VACANT` tables; `20s` eating then `DIRTY` | `docs/DECISION_REGISTER.md`; `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §2 | Pending (Milestone 2) |
| `C-02` | One dish from daily menu per order (weighted toward cheaper); wrong dish/table rejected without consuming food | `docs/DECISION_REGISTER.md`; `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §2, §5 | Pending (Milestone 2) |
| `C-03` | Voluntary `terima` at online station starts `60s` driver order; cutoff at `day_queue_remaining <= 2`; 3 pickup spots serveable, overflow FIFO unserveable | `docs/DECISION_REGISTER.md`; `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §3 | Pending (Milestone 3) |
| `C-04` | Each missed order (dine-in or accepted online) rolls `1` or `2` (`50/50`) added to `demand_penalty_debt`; perfect day heals `1` | `docs/DECISION_REGISTER.md`; `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §5 | Pending (Milestone 4) |
| `D-01` | Day 1 starter kit (1 box, 1 stove, 1 washer, 1 rack, 1 cooker, 2 tables + map work table/trash); `+4/day` demand growth; Day 7 post-electricity goal; optional Extra Mode | `docs/DECISION_REGISTER.md`; `docs/SHARED_BASELINE.md` | Pending (Milestone 0/4/5) |
| `D-02` | Ingredient buys target one chosen storage unit: immediate in `PLANNING`, `100s` delivery in `SERVING`, full refund once if still `PENDING` at close | `docs/DECISION_REGISTER.md`; `docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md` §4 | Pending (Milestone 4) |
| `E-01` | World-first UI: per-diner icons + `100s`/`20s` rings, per-driver icons + `60s` rings, `100s` shipment rings, ghost command above target, persistent HUD strip | `docs/DECISION_REGISTER.md`; `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md` §1–2 | Pending (Milestone 0/2/3/4) |
| `VIS-01` (Layout Direction & `12×9` Grid) | Persistent left vertical HUD band (`LeftHUDRegion` / `ui_safe_rect`) with playable `12×9` (`32×32` px, `384×288` px) restaurant world on the right; kitchen upper (`rows 0..3`), divider (`row 4`), dining lower (`rows 5..8`); dine-in queue relocated to **column 9 on the right** (`4` waiting anchors); road/driver overflow in **columns 10–11** (superseding the M0 `13×9` left-lane sketch) | `docs/DECISION_REGISTER.md` (`VIS-01`); `docs/WORLD_LAYOUT_AND_VIEWPORT.md` §1 | Approved 2026-11-18 & Implemented/Verified in M5-A1 (`10` headless suites / `913/913` assertions + `640×360` and `480×270` GUI viewport checks) |
| `VIS-02` (Viewport Composition & Framing) | World and UI share **one** 2D viewport (`World: Node2D` + `UI: CanvasLayer`); `World` transform offset (`Vector2(144, 36)`) and `LeftHUDRegion` width (`112` px, `ui_safe_rect = Rect2(0, 0, 112, 360)`) evaluated together against viewport bounds and HUD click blocking; planning panels may temporarily overlap the world | `docs/DECISION_REGISTER.md` (`VIS-02`); `docs/WORLD_LAYOUT_AND_VIEWPORT.md` §1, §3 | Approved & Implemented/Verified in M5-A1 (M0 Candidate B framing re-evaluated and verified for the `12×9` world at `640×360` and `480×270`) |
| `VIS-03` (M5-A1 World Layout & `PlacementSlots`) | `12×9` grid (`108` `FloorTiles` cells); starter IDs preserved; `5` utility slots (`slot_utility_01..05`) + `6` dining-table slots (`slot_table_01..06`); passive row-4 long counter (`cols 0..5`) and col-8 wall (`rows 0..4 & 8`, walkable doorway `rows 5..7`); `online_station` at `(6,4)`; non-walkable pickup spots `(7,5)..(7,7)`; player start `(6,3)` | `docs/DECISION_REGISTER.md` (`VIS-03`); `docs/WORLD_LAYOUT_AND_VIEWPORT.md` §1 | Approved 2026-11-18 & Implemented/Verified in M5-A1 (`restaurant_world.tscn`, `world_grid.gd`, `world_map.gd`, `kitchen_controller.gd`, `game_ui.gd`) |
| `VIS-04` (M5-A2 Customer Seating & Table Art) | Every starter and dynamically purchased dining table owns south-side child `ChairVisual [Sprite2D]` + `SeatAnchor [Marker2D]`; visual-only chair with extended table hitbox; `ServiceController` sole seating/order owner; do **not** use chair sprite (`Rect2(416,160,32,32)`) as tabletop sprite (use temporary tabletop placeholder until dedicated table art is confirmed) | `docs/DECISION_REGISTER.md` (`VIS-04`); `docs/WORLD_LAYOUT_AND_VIEWPORT.md` §2 | Approved 2026-11-18 (design decision); **M5-A2 implementation pending** (`ChairVisual`, `SeatAnchor`, extended table hitbox, and customer seating changes not yet implemented) |
| `TECH-01` | Frozen `GameRoot -> World` container tree (`FloorTiles`, `DineInWaitingAnchors`, `Player`, `KitchenStations`, `KitchenWorkTables`, `DiningTables`, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots`) + 4 single-owner controllers/UI; no autoloads | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §1–2 | Implementation task pending: `restaurant_world.tscn` uses provisional `WaitingLane`, `OnlineArea`, `WorkTable` inside `KitchenStations`, and `Decorations` (only `Decorations` needs clarification — see `CC-05`) |
| `TECH-02` | Single monotonic `service_elapsed` clock in `GameRoot` + `advance_service_time(now)` per owner; no per-order Godot `Timer` nodes | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §3 | Pending (Milestone 0 `game_root.gd`) |
| `TECH-03` | Single 4-arg `try_consume_serving_item`; target-specific `try_serve_table` / `try_serve_driver`; ID-based once-only accounting | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §5–6 | Pending (Milestone 1/2/3) |
| `TECH-04` | Rejected requests leave zero partial mutations; retries/duplicate signals remain idempotent | `docs/DECISION_REGISTER.md`; `docs/ARCHITECTURE.md` §6 | Partial (`WorldGrid`/`WorldRegistry`/`WorldMap` A2-validated; controllers pending) |

---

## C. Decisions Requiring Coordinator Confirmation

These **6** items require explicit coordinator decision or content sign-off. Where multi-owner implementation contracts also apply, they are cross-referenced to Section D under one primary tracking ID.

### `CC-01` — Movement vs. `KitchenController` Ownership Split (Primary ID for `CDR-04` / `TA-01`)
1. **Decision ID:** `CC-01` (joint engineering contract in `TA-01`; cross-ref `CDR-04`)
2. **Topic:** Authoritative ownership of `player_tile`, teleport logic, and world click routing
3. **Current situation:** `docs/ARCHITECTURE.md` §2 & §5 and `docs/systems/01_INTERACTION_KITCHEN.md` §1 & §6 freeze `player Vector2i tile`, `on_floor_clicked(tile)`, `on_interactable_clicked(target_id)`, `player_tile_changed`, `selected_target_id`, and `accepted_prefix` on `KitchenController`. Current team task division assigns movement and click routing to a dedicated **Movement programmer** (`docs/PROGRESS.md` line 141; `scripts/player/player_visual.gd` line 6). Neither script exists yet.
4. **Why it needs confirmation:** Two competing click routers or split teleport/selection state violates `A-02` and `TECH-01`. Changing frozen `docs/ARCHITECTURE.md` §2/§5 ownership requires coordinator approval.
5. **Specific question the coordinator must answer:** Should the Movement programmer implement teleport/navigation in a module invoked behind `KitchenController`'s frozen `ARCHITECTURE.md` §5 API (Option A), or should `docs/ARCHITECTURE.md` be amended to extract a separate `MovementController` owning `player_tile` and world click routing (Option B)?
6. **Available options:**
   - **Option A:** Preserve `KitchenController` as the sole external contract (`on_floor_clicked`, `on_interactable_clicked`, `player_tile_changed`), delegating teleport validation and `Player` placement synchronously to a Movement programmer-owned helper/module.
   - **Option B:** Amend `docs/ARCHITECTURE.md` §1, §2, §5 and `docs/systems/01_INTERACTION_KITCHEN.md` to create `MovementController` as owner of `player_tile` and click routing, calling `KitchenController` on arrival.
7. **Impact on implementation:** Blocks controller skeletons (`KitchenController`, Movement module) and Milestone 1 routing. **Does not block Track A3** (core enums and `.tres` schemas).
8. **Affected systems or programmers:** Coordinator, Movement programmer, `KitchenController` owner, `GameUI` (UI-to-world click gate).
9. **Required approvers:** Coordinator, Movement programmer, `KitchenController` owner.
10. **Current status:** `APPROVED & IMPLEMENTED (Option A confirmed 2026-11-16 in DECISION_REGISTER.md — KitchenController sole owner of player_tile & click routing, implemented in M0/M1)`

---

### `CC-02` — Viewport Resolution, Left HUD Safe Width, and `World` Framing Scheme (Primary ID for `CDR-05` / `TA-04`)
1. **Decision ID:** `CC-02` (joint UI/World anchor contract in `TA-04`; cross-ref `CDR-05`)
2. **Topic:** Finalizing `VIS-01` dimensions (`ui_safe_rect`, `world_visible_rect`, logical viewport) and `VIS-02` framing method (`World` offset vs. `Camera2D`)
3. **Current situation:** `project.godot` uses candidate `640×360` viewport / `1280×720` window (`canvas_items`, Nearest filter `3`). `GameRoot/World` is temporarily at `(0, 0)` (`(160, 36)` is explicitly not approved). In `scenes/world/restaurant_world.tscn`, `WorldMap` uses a `13×9` grid of `32×32` px cells (`416×288` px) with `waiting_lane_rect = (0, 0, 2, 9)` at `x = 0..64`, which overlaps a left HUD band unless offset or framed.
4. **Why it needs confirmation:** `LeftHUDRegion`, dine-in waiting lane, 3 driver spots + overflow, countdown rings, and Indonesian ghost commands must fit cleanly without clipping or overlapping clicks (`docs/WORLD_LAYOUT_AND_VIEWPORT.md` §3, `E06`/`E06a`).
5. **Specific question the coordinator must answer:** After the Milestone 0 blockout fit test, do we keep `640×360` logical / `1280×720` window, what exact pixel bounds are approved for `ui_safe_rect` and `world_visible_rect`, and should framing use a fixed `World` position offset or a single `Camera2D`?
6. **Available options:**
   - **Option A:** Keep `640×360` candidate + place `World` inside `world_visible_rect` via an approved node offset (leveraging `WorldMap.global_to_cell` / `cell_to_global` `to_local`/`to_global`) + no `Camera2D`.
   - **Option B:** Keep `World` at `(0, 0)` and frame the playfield using one `Camera2D`.
   - **Option C:** Adjust logical viewport size (keeping integer-friendly pixel scaling) if the Milestone 0 worst-case dialogue/ring test clips at `640×360`.
7. **Impact on implementation:** Blocks finalizing Milestone 0 `LeftHUDRegion` anchoring and framing in `game_root.tscn` (`E06`/`E06a`). **Does not block Track A3** or controller logic.
8. **Affected systems or programmers:** Coordinator, World owner, `GameUI` owner, Movement programmer.
9. **Required approvers:** Coordinator, World owner, `GameUI` owner, Movement programmer.
10. **Current status:** `APPROVED & IMPLEMENTED (Option A — Historical M0 status: WAITING FOR COORDINATOR pending Milestone 0 blockout fit test, implemented in M0 via VIS-02 TECHNICAL DEFAULT Candidate B with World at (144, 36) and LeftHUDRegion 112×360; M5-A1 completion note [2026-11-18]: coordinator-approved joint evaluation of World offset and LeftHUDRegion width for the 12×9 384×288 world completed and verified in M5-A1 with World.position = Vector2(144, 36) and ui_safe_rect = Rect2(0, 0, 112, 360) across 10 headless suites [913/913 assertions] and 640×360 / 480×270 GUI viewport checks)`

---

### `CC-03` — Map Authoring: `OnlineStation`, `PlacementSlots`, Waiting/Driver Anchors, and ID Rules (Primary ID for `CDR-06` / `TA-03`)
1. **Decision ID:** `CC-03` (joint ID/registration contract in `TA-03`; cross-ref `CDR-06`)
2. **Topic:** Authoritative `OnlineStation` location, `PlacementSlots` count/categories, `WorkTable` split targets, canonical ID naming pattern, and starter map geometry
3. **Current situation:** `scenes/world/restaurant_world.tscn` blockout has provisional positions (`13×9` grid, `PickupSpot01`–`03` at cell col `11` rows `2..4`, `DriverOverflow` at col `12` row `7`, `world_id` values like `storage_box` and `work_table`), empty `WaitingLane`, empty `PlacementSlots`, and **no `OnlineStation`**. `docs/CONTENT_AND_TUNING.md` marks `slot_id`s, allowed categories, and `OnlineStation` location as `CONTENT PENDING`.
4. **Why it needs confirmation:** Gameplay requires `OnlineStation` (`terima`, `C05`), purchasable `PlacementSlots` (`D02`), visible dine-in waiting anchors, 3 pickup spots + overflow (`C06`), and dual `WorkTable` staging vs. `potong` targets (`INT-03`), each with at least one walkable cardinal neighbor.
5. **Specific question the coordinator must answer:** Where should `OnlineStation` sit on the map, how many `PlacementSlots` exist and which `FixtureKind`s does each accept, and is the `13×9` blockout layout acceptable as the Milestone 0 base (pending final pixel art adjustments)?
6. **Available options:**
   - **Option A:** Keep the `13×9` blockout layout as the Milestone 0 baseline, assign coordinates for `OnlineStation`, `DineInWaitingAnchors`, and initial `PlacementSlots`, and confirm canonical starter/dynamic ID rules in `TA-03`.
   - **Option B:** Resize the grid or rearrange starter fixtures before authoring `OnlineStation` and `PlacementSlots`.
7. **Impact on implementation:** Blocks completing Milestone 0 `restaurant_world.tscn` and Milestone 4 slot-based shop data. **Does not block Track A3** (schemas can use `footprint: Vector2i = Vector2i(1, 1)` default once `TQ-01` is synced).
8. **Affected systems or programmers:** Coordinator, World owner, `KitchenController`, `ServiceController`, `RunController`.
9. **Required approvers:** Coordinator, World owner, `KitchenController` owner, `ServiceController` owner, `RunController` owner.
10. **Current status:** `APPROVED & IMPLEMENTED (Option B — Historical M0–M4 baseline used provisional 13×9 coordinates with 4 PlacementSlots; approved 2026-11-18 and implemented/verified in M5-A1: 12×9 32×32 px layout; starter IDs preserved; 5 utility slots + 6 table slots; passive row-4 long counter cols 0..5 & col-8 wall with doorway rows 5..7; online_station at (6,4); non-walkable pickup_spot_01..03 at (7,5)..(7,7); col-9 dine-in queue with 4 anchors; cols 10..11 road driver overflow; player start at (6,3); verified across 10 headless suites [913/913 assertions] and 640×360 / 480×270 GUI checks)`

---

### `CC-04` — Future Day 4–7 Recipe Content, Missing Icons, and Economy Balance Intake
1. **Decision ID:** `CC-04` (cross-ref `PD-09`)
2. **Topic:** Delivery schedule for Day 4–7 `RecipeDef` specs, art icons, and approved balance values
3. **Current situation:** Only 3 recipes (`nasi_telor`, `nasi_ayam`, `nasi_komplit`, provisional unlock days 1–3) are defined; `sapi` is permitted with no recipe yet (`docs/CONTENT_AND_TUNING.md`). All prices, `starting_cash` (Rp100,000), `day_7_cash_target` (Rp700,000), quotas (`day_1_base_dinein_quota` 4, `extra_arrivals_per_extra_selected_menu` 2), `online_sale_percent` (70%), `fixture_resale_percent` (50%), `plates_per_rack` (4), and electricity fees (Rp2,000 / Rp4,000) are prototype `TUNING` defaults (`docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md` §7).
4. **Why it needs confirmation:** `CLAUDE.md` prohibits Claude Code from inventing Days 4–7 dishes or claiming unapproved tuning as final balance.
5. **Specific question the coordinator must answer:** Should Milestone 0–5 build against the 3 authored recipes + placeholder icons + `TUNING` defaults (emitting authoring warnings for Days 4–7), and when will coordinator/artists deliver Day 4–7 recipe specs, icons, and target balance values?
6. **Available options:**
   - **Option A:** Build data-driven schemas (`TQ-01`) and gameplay using the 3 authored recipes + prototype defaults now, then drop in Day 4–7 `.tres`/icons before Milestone 5/6 sign-off.
   - **Option B:** Supply Day 4–7 recipe specs upfront before Milestone 5 authoring.
7. **Impact on implementation:** **Does not block Track A3** or Milestones 0–4; needed before claiming full 7-day release content (`D10`) and final balance.
8. **Affected systems or programmers:** Coordinator, Pixel/UI Artists, `RunController`, `KitchenController`, `ServiceController`, `GameUI`.
9. **Required approvers:** Coordinator (content & balance), Art contributors (icons).
10. **Current status:** `WAITING FOR COORDINATOR` (deferred to content intake / Milestone 5+)

---

### `CC-05` — Non-Interactive `Decorations` Container Under `World`
1. **Decision ID:** `CC-05` (cross-ref `TECH-01`, `CDR-01`)
2. **Topic:** Whether an additive visual-only `Decorations` node is allowed alongside the frozen `docs/ARCHITECTURE.md` §1 containers
3. **Current situation:** Migrating `restaurant_world.tscn` from `WaitingLane`, `OnlineArea`, and `KitchenStations/WorkTable` to `DineInWaitingAnchors`, `KitchenWorkTables`, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, and `DriverObjects` is **already established** in `docs/ARCHITECTURE.md` §1 (`TECH-01`) and is simply a pending Milestone 0 implementation task. The only unmentioned item is `Decorations` (`scenes/world/restaurant_world.tscn` line 11; `scripts/world/world_map.gd` line 46), which holds non-interactive visuals.
4. **Why it needs confirmation:** Clarifies whether the World owner may keep `Decorations` as a harmless visual-only sibling under `World` when executing the canonical `TECH-01` scene migration.
5. **Specific question the coordinator must answer:** When migrating `restaurant_world.tscn` to the established `docs/ARCHITECTURE.md` §1 hierarchy, may we retain `Decorations` as a visual-only (zero-logic, non-clickable) child of `World`, or should static props live directly under `FloorTiles`?
6. **Available options:**
   - **Option A:** Retain `Decorations` strictly as a passive visual container under `World`.
   - **Option B:** Remove `Decorations` and keep only the exact 11 child nodes listed in `docs/ARCHITECTURE.md` §1.
7. **Impact on implementation:** Minor cleanup during Milestone 0 `restaurant_world.tscn` reconciliation. **Does not block Track A3.**
8. **Affected systems or programmers:** Coordinator, World owner.
9. **Required approvers:** Coordinator, World owner.
10. **Current status:** `APPROVED & IMPLEMENTED (Option A confirmed 2026-11-16 in DECISION_REGISTER.md & 2026-11-18 in M5-A1: retain Decorations as a passive visual-only child of World; passive long counter and interior wall verified in M5-A1 without registering gameplay targets)`

---

### `CC-06` — Milestone 1–4 Pre-Implementation Confirmation of Plate/Resale Defaults
1. **Decision ID:** `CC-06` (cross-ref `PD-01`, `PD-03`)
2. **Topic:** Confirming trash plate-retention and `Rp0` starter-fixture resale defaults before Milestone 1/4 implementation
3. **Current situation:** `docs/DECISION_REGISTER.md` marks `#1` (trash discards wrong food while returning the **same clean empty plate**) and `#3` (starter gifted fixtures have `actual_amount_paid = 0`, so reselling them yields `Rp0`) as reversible defaults pending playtest.
4. **Why it needs confirmation:** Acceptance tests `B06` (Milestone 1) and `D01` (Milestone 4) encode these behaviors directly.
5. **Specific question the coordinator must answer:** Do we implement `DECISION_REGISTER.md` defaults `#1` (trash preserves clean reusable plate) and `#3` (starter fixtures resell for `Rp0`) as our Milestone 1/4 baseline pending playtests?
6. **Available options:**
   - **Option A:** Implement `#1` and `#3` as written and re-evaluate during Milestone 5–6 playtests.
   - **Option B:** Override either rule now before Milestone 1/4 coding.
7. **Impact on implementation:** Affects Milestone 1 `Trash` (`B06`) and Milestone 4 `request_fixture_sale` (`D01`). **Does not block Track A3 or Milestone 0.**
8. **Affected systems or programmers:** Coordinator, `KitchenController` owner, `RunController` owner.
9. **Required approvers:** Coordinator.
10. **Current status:** `DISCUSSION NEEDED` (can wait until playtesting / before final sign-off; reversible defaults `#1` trash plate preservation and `#3` starter `actual_amount_paid = 0` remain `PROPOSED` per `DECISION_REGISTER.md`)

---

### `CC-07` — M5-A2 Dining-Table Customer Seating & Tabletop Art Rule (Primary ID for `VIS-04` / `CDR-08`)
1. **Decision ID:** `CC-07` (cross-ref `VIS-04`, `CDR-08`)
2. **Topic:** Customer chair visual placement, seat anchor resolution, table click hitbox coverage, dynamic M4-C table parity, and dining-table vs. chair sprite assignment
3. **Approved coordinator rules (2026-11-18):**
   - Each dining table (`dining_table_01`, `dining_table_02`, and dynamically purchased `dining_table_03+`) owns a child `ChairVisual` (`Sprite2D`) and a child `SeatAnchor` (`Marker2D`) on the **south side** of the table via a shared scene or construction path.
   - The chair is **visual-only** (not registered in `WorldRegistry` or `WorldGrid`); the dining table remains the authoritative target for `saji` and `bersihkan`, with an additional/extended hitbox over the south chair region so clicking the chair selects the table.
   - `ServiceController` remains sole owner of customer queues, table occupancy, serving, eating, timeouts, cleaning, and day reset (no seating manager or duplicate state).
   - **Art rule:** Do **not** use the existing chair sprite (`Rect2(416, 160, 32, 32)` in `Warung-Tileset.png`) as the dining-table tabletop sprite. Use a clearly identified temporary tabletop placeholder until a dedicated dining-table sprite is confirmed.
4. **Current status:** `APPROVED (2026-11-18 design decision — M5-A2 implementation pending; ChairVisual, SeatAnchor, extended table hitbox, and customer seating changes have not yet been implemented)`

---

## D. Decisions Requiring Team Agreement

These **5** cross-system contracts require engineering agreement across programmers (cross-referencing Section C where coordinator sign-off is also required).

### `TA-01` — Single World Click Router, `player_tile` Authority, and Selection Atomicity (Cross-ref `CC-01`, `CDR-04`)
- **Conflicting responsibilities / assumptions:** `docs/ARCHITECTURE.md` §2 & §5 assign click routing and `player_tile` to `KitchenController`, while current team delegation assigns movement/click routing to the Movement programmer.
- **Who must agree:** Coordinator, Movement programmer, `KitchenController` owner, `GameUI` owner.
- **Exact contract to establish:** Single pointer entry path (`_unhandled_input` vs. `Area2D` priority), UI click blocking (`LeftHUDRegion` and modals), synchronous handoff between Movement and `KitchenController` preserving `A-02` same-click atomicity, and `Player` visual placement via `scripts/player/player_visual.gd`.
- **Blocked work:** Controller skeletons (`KitchenController`, Movement module) and Milestone 1 routing.

### `TA-02` — `WorldMap` / `WorldGrid` Spatial Query & Neighbor Tie-Break Contract (Cross-ref `CDR-03`)
- **Conflicting responsibilities / assumptions:** `WorldMap`/`WorldGrid` are passive spatial helpers (`is_free`, `get_footprint_neighbors` with `CARDINAL_OFFSETS` up/right/down/left) not in `docs/ARCHITECTURE.md` §5, while Movement needs deterministic nearest-free-neighbor resolution (`docs/ARCHITECTURE.md` §7).
- **Who must agree:** World owner, Movement programmer, `KitchenController` owner.
- **Exact contract to establish:** Whether Movement queries `world_map.grid` directly or calls stateless helper queries on `WorldMap` (storing zero `player_tile` inside `WorldMap`), exact distance metric (Manhattan vs. Euclidean) + `CARDINAL_OFFSETS` tie-break order, and whether runtime `DriverObjects` register in `WorldRegistry` or route directly by `driver_id`.
- **Blocked work:** Movement integration, multi-cell neighbor lookup, clickable driver selection.

### `TA-03` — Canonical Object IDs, `WorkTable` Dual Targets, and Runtime Fixture Registration (Cross-ref `CC-03`, `CDR-06`)
- **Conflicting responsibilities / assumptions:** `restaurant_world.tscn` uses provisional single IDs (`storage_box`, `pickup_spot_01`, `work_table`), while `KitchenController` needs `storage_unit_id` + split `WorkTable` staging vs. `potong` IDs (`INT-03`), `ServiceController` needs `table_id` + `spot_id`, and `RunController` needs `slot_id` + `utility_id` + `fixture_instance_id`.
- **Who must agree:** World owner, `KitchenController` owner, `ServiceController` owner, `RunController` owner.
- **Exact contract to establish:** Naming convention for starter vs. dynamically bought fixtures (avoiding ID collisions), dual target IDs on `KitchenWorkTables`, and synchronous planning buy/sell registration across `RunController`, `WorldMap`, `KitchenController`, and `ServiceController`.
- **Blocked work:** Completing Milestone 0 `restaurant_world.tscn` and Milestone 4 planning buy/sell sync.

### `TA-04` — World-to-Canvas Anchor Coordinates and `ui_safe_rect` Coupling (Cross-ref `CC-02`, `CDR-05`)
- **Conflicting responsibilities / assumptions:** `GameRoot/World` is temporarily at `(0, 0)`, `GameUI` (`LeftHUDRegion`, `WorldIndicators`, `InteractionDialogue`) is not built yet, and `Player` exposes `VisualAnchor [Marker2D]` while world targets live in `WorldRegistry`.
- **Who must agree:** Coordinator, World owner, `GameUI` owner, Service owner, Movement programmer.
- **Exact contract to establish:** Shared `ui_safe_rect` / `world_visible_rect` bounds, world-to-canvas coordinate transform under the chosen `VIS-02` option (`World` offset vs. `Camera2D`), and anchor lookup (`Player/VisualAnchor`, stations, tables, waiting diners, drivers).
- **Blocked work:** Milestone 0 `LeftHUDRegion` blockout and `E06`/`E06a` fit tests.

### `TA-05` — `GameRoot` Controller Wiring & Close-Guard Trigger Contract
- **Conflicting responsibilities / assumptions:** `docs/ARCHITECTURE.md` §3 specifies `GameRoot._process(delta)` ticks `KitchenController.advance_service_time(now)` then `ServiceController.advance_service_time(now)` and checks `ServiceController.is_drained()`, whereas `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` §4 mentions using either `GameRoot` polling `is_drained()` OR a one-time notification ("use one route, not duplicate triggers").
- **Who must agree:** `GameRoot` implementer, `KitchenController` owner, `ServiceController` owner, `RunController` owner.
- **Exact contract to establish:** Select **one** close-guard trigger (e.g., `GameRoot` polling `ServiceController.is_drained()` right after advancing timers while keeping `request_close_if_drained()` idempotent), controller child wiring (`@onready` vs. setters), and deterministic simulated-time advance hook for tests.
- **Blocked work:** Finalizing `scripts/core/game_root.gd` controller wiring and `A04`/`A05`/`A06` lifecycle tests.

---

## E. Gameplay Defaults Requiring Playtesting or Confirmation

All **10** items below are **provisional / reversible defaults** or **editable `TUNING` parameters** (from `docs/DECISION_REGISTER.md` lines 34–43, `docs/CONTENT_AND_TUNING.md`, and `docs/systems/01`–`04`). **None** are confirmed coordinator mandates and **none** block Track A3 or Milestone 0.

| ID | Proposed Behavior / Default | Classification | What to Test / Discuss | Affected Systems |
|---|---|---|---|---|
| `PD-01` | Trash discards food components while returning the **same clean empty plate** to player hand (if plated) | Provisional reversible default (`DECISION_REGISTER.md` #1) | Verify mistake recovery feels fair without softlocks or free-plate exploits (`B06`, `B07`) | `KitchenController` |
| `PD-02` | Rice `masak` deposits 1 portion into cooker output (`nasi` retrieves 1); prep/cook steps instant; work table staging vs. `potong` separate | Provisional reversible default (`DECISION_REGISTER.md` #2; `INT-03`) | Playtest clicking staging vs. chopping (`potong`) target with held `sayur` (`B04`, `B05`) | `KitchenController`, World hitboxes, `GameUI` |
| `PD-03` | Starter gifted fixtures record `actual_amount_paid = 0` (`Rp0` resale); bought fixtures resell at `fixture_resale_percent`; no bailout if unwinnable | Provisional reversible default (`DECISION_REGISTER.md` #3) | Verify clear UI resale quote and no starter sell-buy cash exploit (`D01`, `D02`) | `RunController`, `GameUI` |
| `PD-04` | Paid ingredient reservation pinned to one chosen unit; fills matching partial slots then empty slots in stable order (no spill) | Provisional reversible default (`DECISION_REGISTER.md` #4) | Verify multi-container `Belanja` UX when chosen container is full (`B09`, `D03`) | `KitchenController`, `RunController`, `GameUI` |
| `PD-05` | Inverse dine-in price weights (`1.0 / dine_in_price`); online preview stable until accepted/day change; zero-arrival perfect day heals 1 debt | Provisional reversible default (`DECISION_REGISTER.md` #5) | Seeded 1,000-sample distribution test (`C02`) and menu-variety trade-off feel (`C10`) | `ServiceController`, `RunController` |
| `PD-06` | At exact expiry (`now >= deadline_at`), timeout beats `saji`; due deliveries on close tick commit before `CLOSING` and do not refund | Provisional reversible default (`DECISION_REGISTER.md` #6) | Simultaneous boundary tick tests (`C09`, `D04`) | `GameRoot`, `KitchenController`, `ServiceController`, `RunController` |
| `PD-07` | Extra Mode after Day 7 `WON` adds no second compulsory cash deadline | Provisional reversible default (`DECISION_REGISTER.md` #7) | Confirm post-Day-7 endless play satisfaction (`D09`) | `RunController`, `GameUI` |
| `PD-08` | With fewer than 7 authored recipes loaded, unlock only loaded entries and log authoring warning for missing Days 4–7 content | Provisional reversible default (`DECISION_REGISTER.md` #8) | Test `D10` by adding a 4th `.tres` recipe + icon without code edits | `RunController`, `KitchenController`, `ServiceController`, `GameUI` |
| `PD-09` | Prototype `EconomyConfig` `TUNING` values & provisional Days 1–3 unlocks (`starting_cash` Rp100k, `day_7_cash_target` Rp700k, `day_1_base_dinein_quota` 4, `extra_arrivals_per_extra_selected_menu` 2, `online_sale_percent` 70%, `fixture_resale_percent` 50%, `plates_per_rack` 4, electricity Rp2k/Rp4k, prices) | Editable `TUNING` (`03_PLANNING_ECONOMY_PROGRESSION.md` §7; `CONTENT_AND_TUNING.md`) | Full 7-day human-typing-pace playtest verifying winnable balance and risk/reward (`D06`–`D09`) | `EconomyConfig.tres`, `RunController` |
| `PD-10` | UI/input UX defaults: `Backspace` deletes 1 letter, `Escape`/floor click clears prefix & deselects target, ghost-complete only on unique match, stacked delivery badge per container | Reversible technical UX defaults (`01_INTERACTION_KITCHEN.md` §2; `ARCHITECTURE.md` §7; `04_UI_FEEDBACK_LOCALIZATION.md` §3–4) | Manual keyboard/mouse feel tests (`B01`, `E03`) | `KitchenController`, `GameUI` |

---

## F. Technical and Integration Questions

These **8** engineering questions require concrete technical clarification ahead of their dependent milestones.

1. **`TQ-01` — Shared `.tres` Resource Schema Split (Primary Prerequisite for Track A3):**
   *Affected owners:* `KitchenController` owner (`IngredientDef`, `RecipeDef`), `RunController` owner (`EconomyConfig`, `RecipeEconomyEntry`, `UtilityDef`), and World owner (`UtilityDef` footprints / `PlacementSlots` category mapping).
   *Open fields needing agreement:*
   - **`RecipeDef` vs. `RecipeEconomyEntry`:** `docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md` §2 assigns `recipe_id`, `display_name`, `icon_key`, and `required_parts` to `B`-owned `RecipeDef.tres`, while placing `unlock_day` and `dine_in_price` in `D`-owned `RecipeEconomyEntry` inside `EconomyConfig`; conversely, `docs/ARCHITECTURE.md` §3 step 7 states `D` unlocks authored `RecipeDef` content with `unlock_day == day_index`. Agree on whether `unlock_day` sits in `EconomyConfig`/`RecipeEconomyEntry` (keeping `RecipeDef` purely kitchen prep/display) or on `RecipeDef` directly.
   - **`UtilityDef` fields:** Confirm `utility_id`, `category: FixtureKind`, `purchase_price`, `daily_electricity_cost`, `plates_per_rack`, plus whether `footprint: Vector2i = Vector2i(1, 1)` and `allowed_slot_category` live on `UtilityDef.tres` or on scene `PlacementSlots` metadata.
   - **`IngredientDef` fields:** Confirm `ingredient_id`, `display_name`, and `allowed_transitions` representation (`FoodComponentState` / preparation enum).
   - **`EconomyConfig` fields:** Confirm exact keys matching `03_PLANNING_ECONOMY_PROGRESSION.md` §2 & §7 (`starting_cash`, `day_7_cash_target`, `day_1_base_dinein_quota`, `arrival_increment_per_day`, `extra_arrivals_per_extra_selected_menu`, `online_sale_percent`, `fixture_resale_percent`, `plates_per_rack`, price dictionaries, optional test-duration overrides).
2. **`TQ-02` — `WorldGrid.occupy()` Walkability Policy (`CDR-07`):**
   `scripts/world/world_grid.gd` (`occupy`, lines 129–145) validates bounds, IDs, and non-overlap without checking `is_walkable(cell)`, while `is_free(cell)` checks `is_walkable(cell) and not is_occupied(cell)`. *Question:* Confirm keeping `occupy()` walkability-agnostic (preserving Track A2 tests and allowing perimeter/non-walkable props if needed) while enforcing "valid `slot_id` + at least one `is_free()` cardinal neighbor" in scene/placement validation.
3. **`TQ-03` — `FloorTiles` (`TileMapLayer`) vs. `WorldMap` Export Rects:**
   `FloorTiles` in `scenes/world/restaurant_world.tscn` currently has no `TileSet`, and `WorldMap._enter_tree()` marks `kitchen_rect` and `dining_rect` walkable. *Question:* When final `TileSet` art arrives, will `FloorTiles` stay purely visual or drive walkability via tile custom data?
4. **`TQ-04` — World Target Picking (`Area2D` Hitboxes vs. Cell Occupancy Lookup):**
   Station/table nodes in `scenes/world/restaurant_world.tscn` are currently bare `Node2D`/`Marker2D` without `Area2D` (`OnlineStation` in `ARCHITECTURE.md` §1 is `[Area2D]`, and `CONTENT_AND_TUNING.md` requires sprite-independent click hitboxes). *Question:* Confirm whether clickable targets use `Area2D` physics picking or `WorldMap.global_to_cell()` occupancy lookup (especially for split `KitchenWorkTables` staging vs. `potong` zones and moving/dynamic `DriverObjects`).
5. **`TQ-05` — Pre-Placed Starter Scene Nodes vs. `RunController` Ownership at `start_new_run()`:**
   `restaurant_world.tscn` already instances starter fixtures (`StorageBox`, `Stove`, `Washer`, `PlateRack`, `RiceCooker`, `DiningTable01`, `DiningTable02`) registered automatically by `WorldMap._ready()`. *Question:* Confirm how `RunController.start_new_run()` binds `fixture_instances` (`starter_grant = true`, `actual_price_paid = 0`) to those existing scene nodes so Milestone 4 resale/removal works uniformly without duplicating nodes.
6. **`TQ-06` — Minor Existing Script & Doc Cleanup Timing:**
   `scripts/world/world_map.gd` lines 47–48 use `@onready var fixtures` / `dining_area` for `$KitchenStations` / `$DiningTables`; `docs/DECISION_REGISTER.md` line 3 mentions `SHARED_BASELINE.md v2.0` instead of `v2.1`; `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md` lines 7 & 95 use `docs/WORLD_LAYOUT_AND_VIEWPORT.md` instead of `../WORLD_LAYOUT_AND_VIEWPORT.md`. *Question:* Bundle these cleanups into the `TECH-01` Milestone 0 World migration & doc polish pass?
7. **`TQ-07` — In-Repo Acceptance Test Location & Simulated Clock Injection:**
   Track A2 runtime tests currently sit outside the repo (`scratch/test_world_a2.gd`), and `docs/ARCHITECTURE.md` §1 suggests `vertical_slice.tscn` for accelerated tests. *Question:* Confirm in-repo test folder (`tests/` or `scenes/tests/`) and test-clock injection interface on `GameRoot` so live `100/60/20/20/100` defaults never change.
8. **`TQ-08` — `GameUI` Modal Focus & `Belanja` Quantity Input Isolation:**
   `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md` §3 forbids placing an editable `LineEdit` in front of gameplay typing and requires `Belanja` quantity inputs to block key leakage to `KitchenController.accept_typed_character()` while `LeftHUDRegion` (`mouse_filter=STOP`) blocks world clicks. *Question:* Confirm exact GUI focus/consume check (`gui_get_focus_owner()` / `_unhandled_key_input`) before UI input wiring.

---

## G. Implementation Blockers and Dependencies

### Priority Tiers
- **P0 — Critical:** Blocks starting Track A3 schemas cleanly or blocks controller/Movement architecture before code skeleton work.
- **P1 — High:** Blocks completing Milestone 0 World Foundation, `GameRoot`/`GameUI` wiring, or Movement integration.
- **P2 — Normal:** Content/clarification items resolvable before dependent Milestone 1–5 gates without halting Milestone 0 or Track A3.
- **P3 — Low:** Playtesting balance, reversible defaults, and non-blocking doc/naming polish.

### Dependency Separation by Implementation Track

1. **Required Before Track A3 (Core Enums & `.tres` Schemas):**
   - **P0 (Track A3 Prerequisite):** `TQ-01` — Confirm exact schema split (`unlock_day` placement, `UtilityDef.footprint`, `IngredientDef` transitions, `EconomyConfig` keys) across `KitchenController`, `RunController`, and World owners.
   - *All unrelated World (`CC-03`, `CC-05`), Movement (`CC-01`), and viewport (`CC-02`) decisions do **not** block Track A3.*
2. **Can Proceed Independently During Track A3:**
   - `scripts/core/shared_types.gd` enums frozen in `docs/ARCHITECTURE.md` §2 (`Phase`, `OrderKind`, `OrderStatus`, `CustomerState`, `TableState`, `DriverState`, `FixtureKind`).
   - Static `.tres` Resource classes and the 3 authored starter `RecipeDef` / `IngredientDef` / `EconomyConfig` data assets once `TQ-01` is aligned.
   - Internal `GameRoot` phase enum and monotonic `service_elapsed` clock prototype (finalizing close-guard wiring via `TA-05`).
3. **Required Before Controller Skeletons & Movement Integration:**
   - **P0 (Controllers & Movement):** `CC-01` / `TA-01` — Resolve Movement vs. `KitchenController` ownership and single world click router.
   - **P1:** `TA-02` (`WorldMap` spatial query & tie-break contract), `TQ-02` (`WorldGrid.occupy()` walkability policy), `TQ-04` (world picking mechanism), `TA-05` (`GameRoot` close-guard route), `TQ-08` (`GameUI` focus/click isolation).
4. **Required Before World Foundation Completion (Milestone 0 Gate):**
   - *Pending already-established work:* Migrate `restaurant_world.tscn` & `world_map.gd` to `TECH-01` (`docs/ARCHITECTURE.md` §1) containers (not an open approval).
   - **P1:** `CC-03` / `TA-03` (`OnlineStation`, `PlacementSlots`, dual `WorkTable` targets, canonical starter/dynamic IDs), `CC-02` / `TA-04` (`LeftHUDRegion` fit test, `ui_safe_rect`, `World` offset vs. `Camera2D`), `TQ-04` (hitboxes), `TQ-05` (starter-node registration binding).
   - **P2:** `CC-05` (whether visual-only `Decorations` sibling stays).
5. **Can Wait Until Later Milestones / Playtesting:**
   - **P2:** `CC-04` (Day 4–7 recipes/icons), `CC-06` (pre-Milestone 1/4 confirmation of trash-plate & Rp0 starter resale), `TQ-03` (`TileSet` integration), `TQ-07` (in-repo test runner/clock injection).
   - **P3:** `PD-01`–`PD-10` (playtest tuning & reversible UX defaults), `TQ-06` (minor variable/doc polish), `CDR-02` (`ARCHITECTURE.md` `PlayerVisual` shorthand note).

---

## H. Coordinator Decision and Approval Tracker

Each unresolved issue has **one** primary row below (cross-referenced IDs stay synchronized with zero conflicting statuses).

| ID | Decision | Priority | Required Participants | Status | Final Decision / Notes |
|---|---|---|---|---|---|
| `TQ-01` | Track A3 `.tres` schema split (`UtilityDef.footprint`, `RecipeDef.unlock_day` vs. `RecipeEconomyEntry`, `EconomyConfig`) | **P0** *(for A3)* | `KitchenController`, `RunController`, World | `APPROVED & IMPLEMENTED` | Confirmed 2026-11-16 (`DECISION_REGISTER.md`); implemented in Track A3 |
| `CC-01` / `TA-01` | Movement vs. `KitchenController` ownership, `player_tile`, and single click router (`CDR-04`) | **P0** *(for Controllers/M1)* | Coordinator, Movement, `KitchenController`, `GameUI` | `APPROVED & IMPLEMENTED` | Option A confirmed 2026-11-16 (`DECISION_REGISTER.md`: `KitchenController` sole owner; `PlayerVisual` helper); implemented in M0/M1 |
| `TA-02` | `WorldMap`/`WorldGrid` spatial query helpers, tie-break metric, driver registration (`CDR-03`) | **P1** | World, Movement, `KitchenController` | `APPROVED & IMPLEMENTED` | Confirmed 2026-11-16 (`DECISION_REGISTER.md`: Manhattan distance + `CARDINAL_OFFSETS` tie-break); implemented in M0 |
| `TQ-02` | `WorldGrid.occupy()` walkability-agnostic vs. placement-slot validation (`CDR-07`) | **P1** | Coordinator, World, Movement | `APPROVED & IMPLEMENTED` | Confirmed 2026-11-16 (`DECISION_REGISTER.md`) & 2026-11-18 M5-A1 (`occupy()` walkability-agnostic; pickup cells `(7,5)..(7,7)` non-walkable) |
| `TQ-04` | World target picking mechanism (`Area2D` hitboxes vs. cell lookup, split `WorkTable`) | **P1** | World, Movement, `KitchenController`, `ServiceController` | `RESOLVED IN IMPLEMENTATION (M0–M4)` | Technical choice implemented in M0/M4-C (`Area2D` picking for interactables + `StagingTarget`/`ChoppingTarget` on `WorkTable` + `Marker2D` hit-test for `PlacementSlots`) |
| `CC-03` / `TA-03` | `OnlineStation` placement, `PlacementSlots` categories, canonical starter/dynamic IDs (`CDR-06`, `VIS-03`) | **P1** | Coordinator, World, `KitchenController`, `ServiceController`, `RunController` | `APPROVED & IMPLEMENTED (2026-11-18 M5-A1)` | M5-A1 `12×9` layout & `11` slots (`5` utility + `6` table), passive row-4 counter & col-8 wall, `online_station` `(6,4)`, non-walkable pickups `(7,5)..(7,7)`, col-9 queue (`4` anchors), cols `10..11` road overflow, player start `(6,3)` implemented & verified (`10` suites / `913/913` + GUI checks) |
| `CC-02` / `TA-04` | Logical viewport, `ui_safe_rect` width, `World` offset vs. `Camera2D` framing (`VIS-01`–`VIS-03`, `CDR-05`) | **P1** | Coordinator, World, `GameUI`, Movement | `APPROVED & IMPLEMENTED (2026-11-18 M5-A1)` | Single 2D viewport + `World` transform offset; M5-A1 evaluated & verified `World` at `(144, 36)` and `LeftHUDRegion` `112×360` at `640×360` and `480×270` (`10` suites / `913/913` + GUI checks) |
| `CC-07` / `VIS-04` | Dining-table `ChairVisual` + `SeatAnchor` south-side customer seating & tabletop art rule (`CDR-08`) | **P1** *(for M5-A2)* | Coordinator, World, `ServiceController`, `GameUI` | `APPROVED (2026-11-18; M5-A2 Pending)` | Design approved 2026-11-18 (south-side visual-only `ChairVisual` + `SeatAnchor` on starter & dynamic tables, extended table hitbox, chair sprite not used as tabletop); **M5-A2 implementation pending** |
| `TA-05` | `GameRoot` controller wiring & single `is_drained()` close-guard route | **P1** | `GameRoot`, `KitchenController`, `ServiceController`, `RunController` | `RESOLVED IN IMPLEMENTATION (M0)` | Implemented in `GameRoot._process()` with idempotent `request_close_if_drained()` per `TECH-02` / `A-03` |
| `TQ-05` | Linking pre-placed starter scene nodes to `RunController` `fixture_instances` | **P1** | World, `KitchenController`, `ServiceController`, `RunController` | `RESOLVED IN IMPLEMENTATION (M0/M4)` | Bound via `STARTER_FIXTURE_SPECS` (`starter_grant = true`, `actual_amount_paid = 0`; `#3` resale default tracked under `CC-06`) |
| `TQ-08` | `LeftHUDRegion` `mouse_filter` & `Belanja` modal keyboard focus isolation | **P1** | `GameUI`, `KitchenController`, Movement | `RESOLVED IN IMPLEMENTATION (M1/M4)` | Implemented in `GameUI._is_point_blocked_by_ui()` and `_is_keyboard_blocked_by_focus_or_modal()` |
| `CC-05` | Retain visual-only `Decorations` node under `World` during `TECH-01` container migration | **P2** | Coordinator, World | `APPROVED & IMPLEMENTED (Option A)` | Confirmed 2026-11-16 (`DECISION_REGISTER.md`) & 2026-11-18 M5-A1 (`Decorations` stays passive visual-only sibling) |
| `CC-06` | Pre-Milestone 1/4 confirmation of trash-plate & `Rp0` starter-resale defaults (`PD-01`, `PD-03`) | **P2** | Coordinator, `KitchenController`, `RunController` | `DISCUSSION NEEDED` | Implemented as reversible baseline (`#1`, `#3` in `DECISION_REGISTER.md`) pending final playtest sign-off |
| `CC-04` | Day 4–7 recipe intake timeline, placeholder icons & final balance target | **P2** | Coordinator, Artists, `RunController`, `GameUI` | `WAITING FOR COORDINATOR` | Deferred to M5-B+ content intake |
| `TQ-03` | Final `TileSet` vs. `@export` walkability rects on `FloorTiles` | **P2** | World, Artists | `DEFERRED (M5-A1 Grid Implemented)` | M5-A1 updated `WorldMap` walkability zones and `12×9` `FloorTiles` (`108` cells); final artist `TileSet` custom-data policy deferred |
| `TQ-07` | In-repo acceptance test folder & `GameRoot` simulated clock override | **P2** | `GameRoot`, `KitchenController`, `ServiceController`, `RunController` | `RESOLVED IN IMPLEMENTATION (M0–M4)` | Implemented in `tests/` (`10` headless suites with deterministic clock injection) |
| `PD-01`–`PD-10` | Provisional gameplay defaults & `EconomyConfig` `TUNING` balance knobs | **P3** | Coordinator, All owners (playtest) | `DEFERRED` | Reviewed during playtesting |
| `TQ-06` / `CDR-02` | `ARCHITECTURE.md` `PlayerVisual` shorthand note & minor code/doc naming polish | **P3** | World, `GameUI`, Docs | `PARTIAL (Code Cleanups Done; Shorthand Open)` | `WorldMap` `@onready` var names (`kitchen_stations`/`dining_tables`) & `DECISION_REGISTER.md` `v2.1` updated; `ARCHITECTURE.md` line 16 `Player` shorthand note still open |

---

## I. Recommended Resolution Order

Resolve items in these dependency waves rather than document order:

1. **`TQ-01` — Shared Resource schema agreement:**
   Confirm `RecipeDef` vs. `RecipeEconomyEntry`, `UtilityDef.footprint`, `IngredientDef`, and `EconomyConfig` fields first so **Track A3** (`shared_types.gd` and `.tres` scripts/resources) can begin immediately with zero rework.
2. **`CC-01` / `TA-01` — Movement and `KitchenController` ownership:**
   Lock who owns `player_tile` and world click routing (Option A behind `KitchenController` vs. Option B separate `MovementController`) so controller skeletons and input boundaries can be written cleanly.
3. **`TA-02`, `TQ-02`, `TQ-04` — World interaction and spatial query contracts:**
   Agree on `WorldMap` neighbor tie-break queries, walkability vs. perimeter occupancy rules, and `Area2D` vs. cell-based picking before Movement and `KitchenController` hook into `WorldMap`.
4. **`CC-03` / `TA-03` (plus `CC-05` and pending `TECH-01` migration) — Object IDs, placement slots, and map authoring:**
   Migrate `restaurant_world.tscn` to the established `docs/ARCHITECTURE.md` §1 containers (clarifying `Decorations` in `CC-05`), assign `OnlineStation` and `PlacementSlots`, split `WorkTable` targets, and standardize starter/dynamic IDs.
5. **`CC-02` / `TA-04` — Viewport and UI integration:**
   Block out `LeftHUDRegion` (`ui_safe_rect`), test `640×360` worst-case readability (`docs/WORLD_LAYOUT_AND_VIEWPORT.md` §3), and confirm `World` offset vs. `Camera2D` framing once World map positions exist.
6. **`TA-05`, `TQ-05`, `TQ-07`, `TQ-08` — `GameRoot`, lifecycle, testing, and input integration:**
   Wire `GameRoot` phase/clock and single `is_drained()` close route, bind starter scene nodes to `RunController`, isolate GUI keyboard focus, and establish the in-repo test clock harness to pass Milestone 0 acceptance (`A01`–`A06`, `E06`–`E06b`).
7. **`CC-04`, `CC-06`, `PD-01`–`PD-10` (plus `TQ-03`, `TQ-06`) — Content and gameplay playtesting:**
   Confirm or adjust reversible defaults through Milestone 1–5 playtesting, swap in coordinator-supplied Day 4–7 recipes, art, and `TileSet`, and clean up minor variable/doc notes.
