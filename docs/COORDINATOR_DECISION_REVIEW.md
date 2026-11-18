# Ketik Saji — Coordinator Decision Review (Milestone 0 & M5-A Update)

**Date:** 2026-11-16 (updated 2026-11-18 for M5-A World Layout & Customer Seating approval and M5-A1 completion)
**Baseline status:** Milestones 0–4 (`M0`–`M4-C`) PASS in `main` @ `e5898bb` | **M5-A1 World Layout (`12×9`) IMPLEMENTED & VERIFIED (`10` headless suites, `913/913` assertions, plus `640×360` and `480×270` GUI viewport checks); M5-A2 Customer Seating (`ChairVisual`, `SeatAnchor`, customer seating changes) PENDING IMPLEMENTATION**
**Authority order respected:** Coordinator explicit decisions > `docs/SHARED_BASELINE.md` > `docs/ARCHITECTURE.md` > `docs/DECISION_REGISTER.md` > `docs/systems/*.md` > `docs/WORLD_LAYOUT_AND_VIEWPORT.md` > `docs/IMPLEMENTATION_PLAN.md` / `docs/ACCEPTANCE_TESTS.md` > `CLAUDE.md` / `docs/CODING_STANDARDS.md` > this review.

This document reconciles the pre-A3 review items and the 2026-11-18 **M5-A World Layout & Customer Seating** coordinator approvals against canonical documentation. Historical Milestone 0 context is preserved below alongside the signed-off decisions.

---

## Decision Summary Table

Status vocabulary used below:
- **APPROVED & IMPLEMENTED:** Explicitly approved by the coordinator and implemented/verified in the repository.
- **APPROVED (IMPLEMENTATION PENDING):** Explicitly approved by the coordinator as a design decision; runtime implementation and verification remain pending.
- **ALREADY ESTABLISHED / PARTIALLY ESTABLISHED / UNRESOLVED (Historical M0 labels):** Historical Milestone 0 pre-A3 status preserved inside each section body for context.

| Decision ID | Subject | Current Status | Blocks Track A3 (Core Enums & `.tres` Schemas)? | Required Approvers (if action needed) |
|---|---|---|---|---|
| `CDR-01` | World hierarchy reconciliation (+ passive `Decorations`) | **APPROVED & IMPLEMENTED (CONFIRMED 2026-11-16 in M0 & 2026-11-18 in M5-A1)** | **No** | Approved by Coordinator (`CC-05` Option A: canonical 11 containers + visual-only `Decorations`; M5-A1 passive counter & wall verified) |
| `CDR-02` | `Player` scene representation & start cell `(6,3)` | **APPROVED & IMPLEMENTED (CONFIRMED 2026-11-16 in M0 & 2026-11-18 in M5-A1)** | **No** | Approved by Coordinator (`Player` visual-only with `VisualAnchor`; M5-A1 start cell `(6,3)` implemented & verified) |
| `CDR-03` | `WorldMap` / `WorldGrid` vs. Movement authority | **APPROVED & IMPLEMENTED (CONFIRMED 2026-11-16; implemented in M0)** | **No** | Approved by Coordinator (`TA-02`: stateless `WorldMap` Manhattan + cardinal tie-break queries) |
| `CDR-04` | Movement vs. `KitchenController` ownership | **APPROVED & IMPLEMENTED (CONFIRMED 2026-11-16 — Option 1 / `CC-01` Option A; implemented in M0/M1)** | **No** | Approved by Coordinator (`KitchenController` sole owner of `player_tile` & click routing) |
| `CDR-05` | Viewport, `12×9` world layout, right-side queue, and `World`/HUD framing (`VIS-01`–`VIS-03`) | **APPROVED & IMPLEMENTED (M0 Candidate B technical default; CONFIRMED & VERIFIED 2026-11-18 in M5-A1)** | **No** | Approved by Coordinator (`12×9` `32×32` px grid, col 9 queue with 4 anchors, cols 10–11 road; `World` `(144,36)` & `LeftHUDRegion` `112` px verified at `640×360` and `480×270`) |
| `CDR-06` | Canonical object IDs, `5` utility + `6` table `PlacementSlots`, pickup spots `(7,5)..(7,7)`, and `OnlineStation` `(6,4)` | **APPROVED & IMPLEMENTED (A3 footprint confirmed 2026-11-16; M5-A1 `12×9` layout & 11 slots CONFIRMED & VERIFIED 2026-11-18)** | **No** | Approved by Coordinator (preserve starter IDs, `5` utility slots, `6` table slots, passive long counter & col 8 wall, pickups at `(7,5)..(7,7)`) |
| `CDR-07` | `WorldGrid` occupancy vs. floor walkability & non-walkable pickup cells | **APPROVED & IMPLEMENTED (CONFIRMED 2026-11-16 in M0 & 2026-11-18 in M5-A1)** | **No** | Approved by Coordinator (`occupy()` walkability-agnostic, `is_free()` required for teleport, pickup cells `(7,5)..(7,7)` non-walkable) |
| `CDR-08` | M5-A2 dining-table `ChairVisual` / `SeatAnchor` south-side seating & temporary tabletop art rule (`VIS-04`) | **APPROVED (CONFIRMED 2026-11-18 — M5-A2 Implementation Pending)** | **No** | Approved by Coordinator (south-side visual-only `ChairVisual` + `SeatAnchor`, extended table hitbox, shared starter/dynamic table structure, chair sprite not used as tabletop) |

---

## CDR-01 — World Hierarchy Reconciliation

- **Current status:** **APPROVED & IMPLEMENTED (2026-11-16 M0 & 2026-11-18 M5-A1)** *(Historical 2026-11-16 M0 pre-implementation status: ALREADY ESTABLISHED — Implementation Pending)*
- **Evidence from canonical documentation:**
  - `docs/ARCHITECTURE.md` §1 freezes the canonical `GameRoot -> World` scene tree: `FloorTiles`, `DineInWaitingAnchors`, `Player`, `KitchenStations`, `KitchenWorkTables` (staging + chopping hitboxes), `DiningTables`, `OnlineStation [Area2D]`, `DriverPickupSpots` (3 authored markers), `DriverOverflowAnchors`, `DriverObjects`, and `PlacementSlots`.
  - `docs/DECISION_REGISTER.md` (`TECH-01`, `INT-03`, `C-03`) reinforces those separate runtime containers; `docs/PROGRESS.md` explicitly states that `docs/ARCHITECTURE.md` stays canonical and `scenes/world/restaurant_world.tscn` is a temporary Milestone 0 blockout.
- **Current implementation state:**
  - `scenes/main/game_root.tscn` instances `res://scenes/world/restaurant_world.tscn` as `World` at `(0, 0)`.
  - `scenes/world/restaurant_world.tscn` (internal root `RestaurantWorld` with `scripts/world/world_map.gd`) currently contains `FloorTiles`, `Decorations`, `KitchenStations` (including `WorkTable`), `DiningTables`, empty `WaitingLane`, `OnlineArea` (`PickupSpot01`–`03`, `DriverOverflow`), `PlacementSlots`, and `Player`. `OnlineStation`, `KitchenWorkTables`, `DineInWaitingAnchors`, `DriverOverflowAnchors`, and `DriverObjects` do not yet exist.
- **Remaining question / implementation dependency:**
  - Not a design conflict: the canonical tree is already fixed. Only Milestone 0 scene restructuring (`restaurant_world.tscn` + `world_map.gd` `@onready` references) and confirming whether non-interactive `Decorations` remains as an additive visual-only node are pending.
- **Recommended next action:**
  - Keep `docs/ARCHITECTURE.md` §1 authoritative. Migrate `restaurant_world.tscn` and `scripts/world/world_map.gd` to the canonical container names during Milestone 0 World completion before controllers bind `$World/...` paths (keeping `Decorations` only if marked strictly visual-only).
- **Required approvers:** None required to follow `docs/ARCHITECTURE.md` §1; Coordinator, World owner, `KitchenController` owner, `ServiceController` owner, and `RunController` owner only if anyone proposes altering the frozen tree.

### Sign-off (`CDR-01` — leave blank unless amending canonical tree)
- **Approved option:** Keep the canonical `docs/ARCHITECTURE.md` §1 scene tree plus `Decorations` as a strictly passive visual-only container (`CC-05` Option A); in M5-A1, place the passive long counter (`row 4, cols 0..5`) and interior wall (`col 8`) as non-interactive visuals without adding new top-level `World` containers.
- **Rejected alternatives:** Making the long counter a gameplay staging surface; adding extra top-level scene containers.
- **Approver:** Coordinator
- **Date:** 2026-11-16 (M0 directive in `DECISION_REGISTER.md`; updated 2026-11-18 for M5-A1)
- **Notes:** Canonical 12-child `RestaurantWorld` hierarchy implemented in M0 (`tests/test_world_hierarchy.gd`); passive long counter (`row 4, cols 0..5`) and interior wall (`col 8, rows 0..4 & 8`) implemented and verified in M5-A1.

---

## CDR-02 — `Player` Scene Representation

- **Current status:** **APPROVED & IMPLEMENTED (2026-11-16 M0 & 2026-11-18 M5-A1)** *(Historical 2026-11-16 M0 status: ALREADY ESTABLISHED — Shorthand Clarification & Visual Anchor Detail Only)*
- **Evidence from canonical documentation:**
  - `docs/ARCHITECTURE.md` §1 uses shorthand `Player [Node2D / Sprite2D]`; `docs/ARCHITECTURE.md` §2 prohibits world/visual scenes from owning gameplay state (`player Vector2i tile` belongs to the controller layer, not the sprite node).
  - `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md` §3 requires rendering a held-item icon above the player.
  - `CLAUDE.md` and `docs/CODING_STANDARDS.md` §5 permit small self-contained visual scenes with stable nodes/anchors provided they do not duplicate runtime truth.
- **Current implementation state:**
  - `scenes/player/player.tscn` has root `Player [Node2D]` with `scripts/player/player_visual.gd` (`PlayerVisual`), child `Visual [Node2D]` (`Sprite [Sprite2D]`, `AnimationPlayer`), and `VisualAnchor [Marker2D]`, instanced inside `restaurant_world.tscn` at `(208, 144)`. `PlayerVisual` holds no tile, selection, or item state.
- **Remaining question / implementation dependency:**
  - Architecturally, `player.tscn` already conforms to the visual-only rule. Two minor items remain: (1) `docs/ARCHITECTURE.md` §1 shorthand (`Player [Node2D / Sprite2D]`) does not mention `PlayerVisual` / `Visual` / `VisualAnchor`; (2) confirming `GameUI` reads `VisualAnchor` (technical visual detail) when positioning the held-item icon.
- **Recommended next action:**
  - Retain `scenes/player/player.tscn` as-is (visual-only) and, in a future doc update or Milestone 0 wrap-up, annotate `Player [Node2D; PlayerVisual]` in `docs/ARCHITECTURE.md` §1 if exact scene notation is desired.
- **Required approvers:** None architecturally; World owner, Movement programmer, and `GameUI` owner for held-item anchor usage.

### Sign-off (`CDR-02` — leave blank unless altering Player authority)
- **Approved option:** `Player` (`scenes/player/player.tscn`) stays visual-only with `VisualAnchor` for held-item display; for M5-A1, the player starting cell moves from `(6,4)` (now occupied by `online_station`) to **`(6,3)`**.
- **Rejected alternatives:** Moving `player_tile` state onto the `Player` node; keeping start cell `(6,4)`.
- **Approver:** Coordinator
- **Date:** 2026-11-16 (M0 visual-only `Player` directive in `DECISION_REGISTER.md`; updated 2026-11-18 for M5-A1 start cell)
- **Notes:** Visual-only `Player` with `VisualAnchor` preserved since M0; `KitchenController.DEFAULT_START_TILE = Vector2i(6, 3)` and `RestaurantWorld/Player` position `(208, 112)` are implemented and verified in M5-A1.

---

## CDR-03 — `WorldMap` / `WorldGrid` vs. Movement Authority

- **Current status:** **APPROVED & IMPLEMENTED (2026-11-16 M0)** *(Historical 2026-11-16 M0 pre-directive status: PARTIALLY ESTABLISHED)*
- **Evidence from canonical documentation:**
  - `docs/ARCHITECTURE.md` §2 & §7 and `docs/DECISION_REGISTER.md` (`A-02`, `TECH-01`) establish that `World` nodes/scripts are passive spatial/visual assemblies holding no gameplay truth (no `player_tile`, no target selection, no click routing).
  - `docs/ARCHITECTURE.md` §7 defines the deterministic movement rule: floor click teleports to accessible floor tile; interactable click selects the nearest legal cardinal neighbor in stable tie order (multi-tile objects use footprint, not sprite center).
  - `docs/PROGRESS.md` records that `WorldMap`, `WorldGrid`, and `WorldRegistry` are additive Milestone 0 spatial helpers (`grid_size`, `tile_size`, coordinate conversion, walkability, occupancy, `CARDINAL_OFFSETS` = up/right/down/left) with zero player/movement authority.
- **Current implementation state:**
  - `scripts/world/world_grid.gd` provides `is_in_bounds`, `is_walkable`, `is_occupied`, `is_free`, `get_cardinal_neighbors`, and `get_footprint_neighbors`. `scripts/world/world_map.gd` provides `global_to_cell`, `cell_to_global`, `register_object`, and `unregister_object`. Neither script tracks `player_tile` or moves `Player`.
- **Remaining question / implementation dependency:**
  - While the spatial-only boundary of `WorldMap`/`WorldGrid` is settled, two integration details remain open between the World owner and Movement programmer:
    1. Whether Movement queries `world_map.grid` primitives directly (`is_free`, `get_footprint_neighbors`) or consumes stateless helper queries on `WorldMap` (e.g., footprint lookup + nearest free cardinal neighbor from a player tile).
    2. Exact tie-break / distance metric (`CARDINAL_OFFSETS` order up/right/down/left vs. Manhattan/Euclidean distance when picking among equal-distance free neighbors).
- **Recommended next action:**
  - Keep `WorldMap` / `WorldGrid` strictly passive (zero `player_tile` or teleport mutation). Agree between World owner, Movement programmer, and `KitchenController` owner on read-only query helpers and neighbor tie-break order before Movement implementation begins.
- **Required approvers:** Coordinator, World owner, Movement programmer, `KitchenController` owner.

### Approval (`CDR-03`)
- **Approved option:** Stateless read-only spatial queries on `WorldMap` (`get_target_footprint`, `get_free_cardinal_neighbors`, `find_nearest_free_neighbor`) using shortest Manhattan distance and fixed `CARDINAL_OFFSETS` tie-break (`UP`, `RIGHT`, `DOWN`, `LEFT`).
- **Rejected alternatives:** Storing `player_tile` or click-routing state in `WorldMap`.
- **Approver:** Coordinator
- **Date:** 2026-11-16 (`DECISION_REGISTER.md` directive)
- **Notes:** Implemented in M0 and verified across M0–M5-A1.

---

## CDR-04 — Movement vs. `KitchenController` Ownership

- **Current status:** **APPROVED & IMPLEMENTED (2026-11-16 — Option 1 / `CC-01` Option A)** *(Historical 2026-11-16 M0 pre-directive status: UNRESOLVED — OWNERSHIP CONFLICT)*
- **Evidence from canonical documentation:**
  - `docs/ARCHITECTURE.md` §2, §5, §7 and `docs/systems/01_INTERACTION_KITCHEN.md` §1, §2, §6 (`TECH-01`, `A-02`, `B-01`) freeze **one** world click router and assign `player Vector2i tile`, `selected clickable target`, `typed accepted prefix`, `on_floor_clicked(tile)`, `on_interactable_clicked(target_id)`, `player_tile_changed(tile)`, and `selected_interactable_changed(target_id)` to **`KitchenController`**.
  - `docs/CODING_STANDARDS.md` §4 & §13 prohibit introducing competing managers or silently changing frozen `docs/ARCHITECTURE.md` public APIs without coordinator review.
- **Current implementation state:**
  - Neither `KitchenController` nor the Movement module exists yet. Current team task division assigns player movement and click routing to a dedicated **Movement programmer**, conflicting directly with `docs/ARCHITECTURE.md`'s single-owner assignment on `KitchenController`.
- **Remaining question / team ownership conflict:**
  - Explicit team agreement is required on how Movement programmer ownership maps onto the frozen `KitchenController` contract without creating two competing click routers or splitting `A-02` atomic teleport + selection/activation:
    - **Option 1 (Preserve `KitchenController` external API):** Single click router calls `KitchenController.on_floor_clicked()` / `on_interactable_clicked()`, while `KitchenController` delegates teleport validation and `Player` transform updates to a dedicated Movement module/script owned by the Movement programmer.
    - **Option 2 (Amend `docs/ARCHITECTURE.md`):** Extract `MovementController` as the formal owner of click routing, `player_tile`, and `player_tile_changed`, updating `docs/ARCHITECTURE.md` §1, §2, §5 and `docs/systems/01_INTERACTION_KITCHEN.md` to define the exact synchronous call contract from Movement into `KitchenController`.
- **Recommended next action:**
  - **Technical recommendation: Option 1**, because it preserves `docs/ARCHITECTURE.md` §5 intact and guarantees same-click atomicity (`A-02`) while isolating Movement code for the Movement programmer. Do not start controller skeletons or Movement routing until this ownership split is explicitly signed off.
- **Required approvers:** Coordinator, Movement programmer, `KitchenController` owner.

### Approval (`CDR-04`)
- **Approved option:** Option 1 (`CC-01` Option A) — `KitchenController` remains sole owner of `player_tile`, `selected_target_id`, `accepted_prefix`, `on_floor_clicked`, and `on_interactable_clicked`, with `PlayerVisual` acting strictly as an internal visual helper.
- **Rejected alternatives:** Option 2 (separate `MovementController`).
- **Approver:** Coordinator
- **Date:** 2026-11-16 (`DECISION_REGISTER.md` directive)
- **Notes:** Implemented in M0/M1 and preserved through M5-A1.

---

## CDR-05 — Viewport and `World` Framing (`VIS-01`, `VIS-02`)

- **Current status:** **APPROVED & IMPLEMENTED (M0 Candidate B technical default; CONFIRMED & VERIFIED 2026-11-18 in M5-A1)** *(Historical 2026-11-16 M0 status: PARTIALLY ESTABLISHED)*
- **Evidence from canonical documentation (historical M0 context + M5-A update):**
  - `docs/DECISION_REGISTER.md` (`VIS-01`, `VIS-02`) and `docs/WORLD_LAYOUT_AND_VIEWPORT.md` **confirm**: persistent left vertical UI band (`ui_safe_rect`) + playable restaurant world (`12×9` in M5-A, with right-side column-9 dine-in queue and columns 10–11 road/overflow) in **one** 2D viewport (`World: Node2D` + `UI: CanvasLayer`, no `SubViewport`); UI blocks world click-through; planning/results panels may overlap the world; 32 px art; prior `10×9` and `13×9` sketches superseded.
  - During the initial M0 fit-test stage, `docs/WORLD_LAYOUT_AND_VIEWPORT.md` v2.1 marked `640×360` logical / `1280×720` display as an unverified fit-test candidate, the ~18% UI band width as illustrative, and the choice between **World transform/scale offset vs. single `Camera2D`** (`docs/WORLD_LAYOUT_AND_VIEWPORT.md` §2, `docs/ARCHITECTURE.md` §1) as a pending Milestone 0 fit-test decision.
  - The coordinator subsequently confirmed the **single-viewport `World` transform offset approach (`CC-02` Option A, no `Camera2D`)** and directed evaluating `World` offset and `LeftHUDRegion` width together for M5-A1; that approach has now been **implemented and verified in M5-A1**.
- **Implementation state (historical M0 vs. verified M5-A1):**
  - *Initial M0 pre-implementation snapshot (2026-11-16):* `GameRoot/World` started temporarily at `(0, 0)` with no `LeftHUDRegion` (`ui_safe_rect`) built yet and no `Camera2D`.
  - *Current verified state (M5-A1):* `project.godot` uses `640×360` viewport / `1280×720` window override (`canvas_items` stretch, Nearest texture filter `3`). `GameRoot/World.position` is `(144, 36)`, `GameUI.ui_safe_rect` (`LeftHUDRegion`) is `Rect2(0, 0, 112, 360)`, `world_visible_rect` is `Rect2(112, 0, 528, 360)` (`Rect2(112, 0, 368, 270)` at `480×270`), and no `Camera2D` or `SubViewport` is used.
- **Resolution of prior M0 fit-test questions:**
  - All prior M0 open items (`640×360` + `480×270` fit validation, `ui_safe_rect` / `world_visible_rect` bounds, and selecting `World` transform offset over `Camera2D`) were resolved via `CC-02` Option A and verified in M5-A1 (only M5-A2 customer seating offsets/hitboxes remain open under `CDR-08`).
- **Required approvers:** Coordinator (confirmed `CC-02` Option A & M5-A1 framing).

### Approval (`CDR-05`)
- **Approved option:** Single 2D viewport (`640×360` logical / `1280×720` display with `480×270` responsive fit check) using a `World` node transform offset (`CC-02` Option A, no `Camera2D`); for **M5-A1 (2026-11-18)**, world grid is **`12×9` (`32×32` px)**, dine-in queue moves to **column 9 on the right** (`4` waiting anchors), driver overflow moves to **columns 10–11**, and `World` offset + `LeftHUDRegion` (`ui_safe_rect`) width were evaluated together against viewport bounds and HUD click blocking.
- **Rejected alternatives:** Separate `SubViewport` or `Camera2D`; keeping the old `13×9` left-side waiting lane.
- **Approver:** Coordinator
- **Date:** 2026-11-18 (M5-A coordinator approval; M0 used 2026-11-16 `VIS-02` `TECHNICAL DEFAULT` Candidate B)
- **Notes:** Evaluated, implemented, and verified in M5-A1 without assuming an arbitrary offset: `GameRoot/World.position = Vector2(144, 36)`, `LeftHUDRegion` / `ui_safe_rect = Rect2(0, 0, 112, 360)`, and `world_visible_rect = Rect2(112, 0, 528, 360)` (`Rect2(112, 0, 368, 270)` at `480×270`) passed all `10` headless test suites (`913/913` assertions) and `640×360` / `480×270` GUI viewport checks.

---

## CDR-06 — Canonical Object IDs, Fixture Footprints, Pickup Spots, and `OnlineStation` Placement

- **Current status:** **APPROVED & IMPLEMENTED (A3 footprint confirmed 2026-11-16; M5-A1 `12×9` layout & 11 slots CONFIRMED & VERIFIED 2026-11-18)** *(Historical 2026-11-16 M0 status: PARTIALLY ESTABLISHED)*
- **Evidence from canonical documentation:**
  - **Already established (`docs/ARCHITECTURE.md` §1–§2, §7; `docs/SHARED_BASELINE.md`; `docs/DECISION_REGISTER.md` `INT-03`, `C-03`, `D-01`; `docs/CONTENT_AND_TUNING.md`):**
    - Stable `StringName` IDs (`slot_id`, `table_id`, `spot_id`, `storage_unit_id`, `work_table_id`, `driver_id`) independent of pixel positions or display names.
    - Starter kit: 1 box, 1 stove, 1 washer (`wastafel`), 1 plate rack, 1 rice cooker, 2 dining tables, plus map work table and trash, `OnlineStation` (`terima` only), 3 `DriverPickupSpots`, and separate `DriverOverflowAnchors`.
    - Work table is one physical fixture with distinct staging click and chopping (`potong`) targets (`INT-03`).
    - Every clickable target must have at least one legal `is_free()` cardinal neighbor (`docs/CONTENT_AND_TUNING.md`).
  - **Explicitly `CONTENT PENDING` / provisional (`docs/CONTENT_AND_TUNING.md`, `docs/PROGRESS.md`):**
    - Authoritative `slot_id` list, slot allowed-category rules, fixture footprint dimensions (`Vector2i`), `OnlineStation` placement, and final map coordinates.
- **Current implementation state:**
  - `scenes/world/restaurant_world.tscn` assigns provisional `world_id` strings (`storage_box`, `stove`, `washer`, `plate_rack`, `rice_cooker`, `work_table`, `trash`, `dining_table_01`–`02`, `pickup_spot_01`–`03`, `driver_overflow`) with provisional single-cell footprints derived from node position. `PlacementSlots` is empty, `OnlineStation` is absent, and `WorkTable` has only one target ID.
- **Remaining question / implementation dependency:**
  1. Naming rule for IDs across scenes and `.tres` (especially dynamically purchased fixtures in `PlacementSlots`, e.g., second `box`/`fridge`/`dining_table`).
  2. Whether fixture footprint size lives on `UtilityDef.tres` (`footprint: Vector2i`, default `1×1`) or in scene/slot metadata (soft dependency for Track A3 `UtilityDef` schema).
  3. Scene positions/anchors for `OnlineStation`, `PlacementSlots` (count + allowed `FixtureKind`s), `DineInWaitingAnchors`, `DriverPickupSpots`, `DriverOverflowAnchors`, and split `WorkTable` staging/chopping target IDs.
- **Recommended next action:**
  - Allow Track A3 to define `UtilityDef` with an optional `footprint: Vector2i = Vector2i(1, 1)` default, while World, Kitchen, Service, and Run owners confirm canonical ID patterns, `OnlineStation` placement, and `PlacementSlots` coordinates before Milestone 0 scene authoring wraps up.
- **Required approvers:** Coordinator, World owner, `KitchenController` owner, `ServiceController` owner, `RunController` owner.

### Approval (`CDR-06`)
- **Approved option:** Preserve canonical starter IDs (`washer`, `stove`, `rice_cooker`, `storage_box`, `plate_rack`, `trash`, `work_table` + `work_table_stage`/`work_table_chop`, `online_station`, `dining_table_01..02`, `pickup_spot_01..03`, `dine_in_wait_01..04`, `driver_overflow`) and dynamic instance IDs (`<utility>_01+`, `dining_table_03+`). For **M5-A1 (2026-11-18)**: expand `PlacementSlots` to **`5` utility slots** (`slot_utility_01..05` at `(5,0),(6,0),(2,2),(4,2),(5,2)`) and **`6` dining-table slots** (`slot_table_01..06` at `(0,5),(2,5),(4,5),(5,5),(0,7),(5,7)`), place `online_station` at `(6,4)`, place `pickup_spot_01..03` at `(7,5)..(7,7)`, and keep the row-4 long counter (`cols 0..5`) and col-8 wall (`rows 0..4 & 8`) passive.
- **Rejected alternatives:** Making the long counter an interactive staging surface; keeping only 2 utility and 2 table slots.
- **Approver:** Coordinator
- **Date:** 2026-11-18 (M5-A1 coordinator approval; `UtilityDef.footprint = Vector2i(1, 1)` confirmed 2026-11-16 in `TQ-01` and initial M0–M4 IDs/slots authored on the provisional `13×9` grid)
- **Notes:** Implemented and verified in M5-A1 across all `10` headless test suites (`913/913` assertions) and `640×360` / `480×270` GUI viewport checks. Every starter target (`12`), `PlacementSlot` (`11`), and `DriverPickupSpot` (`3`) is verified to retain `>= 1` `is_free()` cardinal neighbor both initially and when all `11` slots are simultaneously occupied.

---

## CDR-07 — `WorldGrid` Occupancy vs. Floor Walkability Policy

- **Current status:** **APPROVED & IMPLEMENTED (2026-11-16 M0 & 2026-11-18 M5-A1)** *(Historical 2026-11-16 M0 pre-directive status: PARTIALLY ESTABLISHED)*
- **Evidence from canonical documentation:**
  - `docs/ARCHITECTURE.md` §7 establishes that floor clicks teleport only to accessible floor cells, and interactables resolve to a legal walkable cardinal neighbor.
  - `docs/CONTENT_AND_TUNING.md` requires validating on import/map setup that every clickable target has at least one legal cardinal neighbor.
  - `docs/PROGRESS.md` (Track A2) explicitly records that `WorldGrid.occupy()` deliberately does not require occupied cells to be walkable (`is_walkable()`), leaving walkability enforcement at movement (`is_free()`) rather than cell claiming.
- **Current implementation state:**
  - Verified in `scripts/world/world_grid.gd`: `is_free(cell)` returns `is_walkable(cell) and not is_occupied(cell)`; `occupy(occupant_id, cells)` validates bounds, non-empty ID/cells, no duplicate occupant ID, and no overlap (`is_occupied`), without checking `is_walkable(cell)`. In `restaurant_world.tscn`, kitchen stations and dining tables sit on walkable kitchen/dining cells (`claim_cell = true`), while `OnlineArea` markers pass empty footprints (`claim_cell = false`).
- **Remaining question / implementation dependency:**
  - Whether dynamic fixture placement (`PlacementSlots` / `RunController`) or scene validation requires fixtures to sit strictly on walkable floor cells, or intentionally permits perimeter/border/non-walkable zone placement (such as `OnlineStation` or wall-adjacent utility slots) as long as `get_footprint_neighbors()` yields at least one `is_free()` neighbor.
- **Recommended next action:**
  - Keep `WorldGrid.occupy()` permissive on walkability (preserving Track A2 validation) and enforce the canonical "valid `slot_id` + at least one `is_free()` cardinal neighbor" invariant in scene validation and `PlacementSlots` placement logic.
- **Required approvers:** Coordinator, World owner, Movement programmer.

### Approval (`CDR-07`)
- **Approved option:** Keep `WorldGrid.occupy()` walkability-agnostic while requiring `is_free()` (`is_walkable and not is_occupied`) for player floor teleport and cardinal neighbor resolution; for **M5-A1 (2026-11-18)**, pickup cells `(7,5)`, `(7,6)`, and `(7,7)`, the passive long counter `(0,4)..(5,4)`, wall cells `(8,0)..(8,4)` & `(8,8)`, queue column `9`, and road columns `10..11` are **non-walkable**, while doorway `(8,5)..(8,7)` and passage `(7,4)` are walkable.
- **Rejected alternatives:** Making pickup cells walkable to the player; requiring `occupy()` cells to be walkable.
- **Approver:** Coordinator
- **Date:** 2026-11-16 (M0 `DECISION_REGISTER.md` directive; updated 2026-11-18 for M5-A1 walkability zones & non-walkable pickup cells)
- **Notes:** Implemented and verified in M5-A1 (`WorldMap._configure_walkable_zones()` and headless assertions in `tests/test_world_hierarchy.gd` and `tests/test_fixture_m4c.gd`). Non-walkable pickup cells prevent player/driver tile overlap while preserving cardinal neighbor access from column `6`, `(7,4)`, `(7,8)`, and doorway `(8,5)..(8,7)`.

---

## CDR-08 — M5-A2 Customer Seating & Dining-Table Art Direction (`VIS-04`)

- **Current status:** **APPROVED (CONFIRMED 2026-11-18 — M5-A2 Implementation Pending)**
- **Approved coordinator rules:**
  - Each dining table (`dining_table_01`, `dining_table_02`, and dynamically purchased `dining_table_03+` via M4-C) owns a child `ChairVisual` (`Sprite2D`) and a child `SeatAnchor` (`Marker2D`) on the **south side** of the table.
  - The chair is **visual-only** (not registered in `WorldRegistry` or `WorldGrid`), and the dining table remains the sole authoritative gameplay target for `saji` and `bersihkan`, with an extended/additional hitbox over the chair region so clicking the chair/customer selects the table.
  - `WorldMap._resolve_customer_visual_position()` resolves seated/eating customers to the table's `SeatAnchor`; `ServiceController` remains sole owner of customer queues, table occupancy, serving, eating, timeouts, cleaning, and day reset (no seating manager or duplicate state).
  - **Art rule:** Do **not** use the existing chair sprite (`Rect2(416, 160, 32, 32)` in `Warung-Tileset.png`) as the dining-table tabletop sprite. Use a clearly identified temporary tabletop placeholder until a dedicated dining-table sprite is confirmed.

### Approval (`CDR-08`)
- **Approved option:** Shared dining-table scene/builder with south-side `ChairVisual` + `SeatAnchor`, visual-only chair with extended table hitbox coverage, and temporary tabletop placeholder until dedicated table art is supplied.
- **Rejected alternatives:** Separate registered chair targets; new seating manager; reusing the chair sprite as the tabletop.
- **Approver:** Coordinator
- **Date:** 2026-11-18
- **Notes:** M5-A1 world layout checkpoint has passed (`10` headless suites, `913/913` assertions, plus `640×360` and `480×270` GUI viewport checks). M5-A2 implementation and verification remain pending (`ChairVisual`, `SeatAnchor`, extended table hitbox, and temporary tabletop placeholder have not yet been implemented).

---

## Cross-Document Consistency Notes (Read-Only Observations)

No other files were edited during this reconciliation. The following minor discrepancies across existing docs are recorded for future housekeeping:

1. **Frozen click/movement ownership vs. team assignment (`CDR-04`):** `docs/ARCHITECTURE.md` §2 & §5 and `docs/systems/01_INTERACTION_KITCHEN.md` §1 & §6 assign `player_tile` and `on_floor_clicked` / `on_interactable_clicked` to `KitchenController`, while `docs/PROGRESS.md` (line 141) and team task assignments designate a separate Movement programmer / Movement boundary. *Recommended correction:* Resolve via `CDR-04` sign-off before implementing controllers.
2. **`Player` notation shorthand (`CDR-02`):** `docs/ARCHITECTURE.md` §1 line 16 writes `Player [Node2D / Sprite2D]`, whereas `scenes/player/player.tscn` implements `Player [Node2D; PlayerVisual]` with `Visual/Sprite`, `Visual/AnimationPlayer`, and `VisualAnchor`. *Recommended correction:* Clarify shorthand in `docs/ARCHITECTURE.md` §1 when next touching Milestone 0 docs.
3. **Baseline version label in `docs/DECISION_REGISTER.md`:** Line 3 refers to `SHARED_BASELINE.md v2.0`, while `docs/SHARED_BASELINE.md` and `docs/DECISION_REGISTER.md` line 1 are version `v2.1` (2026-11-15 layout update). *Recommended correction:* Update `v2.0` → `v2.1` in `docs/DECISION_REGISTER.md` line 3 during the next doc touch.
4. **Link style in `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md`:** Lines 7 and 95 use repository-root-relative `docs/WORLD_LAYOUT_AND_VIEWPORT.md` instead of `../WORLD_LAYOUT_AND_VIEWPORT.md` used by `docs/systems/01`–`03`. Paths remain unambiguous from repo root; normalize only if touching that file.
5. **Cosmetic `@onready` variable names in `scripts/world/world_map.gd`:** Lines 47–48 use `@onready var fixtures: Node2D = $KitchenStations` and `@onready var dining_area: Node2D = $DiningTables`. Functional paths are correct (`CDR-01` migration will align any new/renamed containers).

---

## Readiness Summary: Blockers vs. Independent Next Steps

### Remaining Blockers Before World Foundation Completion & Movement Integration
- **World Foundation scene completion:** Reconciling `scenes/world/restaurant_world.tscn` to `docs/ARCHITECTURE.md` §1 containers (`CDR-01`), authoring `OnlineStation`, `PlacementSlots`, `DineInWaitingAnchors`, `KitchenWorkTables` dual hitboxes, canonical IDs (`CDR-06`), and verifying Milestone 0 `LeftHUDRegion` + `World` framing (`CDR-05`).
- **Movement integration:** Resolving `KitchenController` vs. Movement ownership (`CDR-04`), confirming `WorldMap` query helpers / neighbor tie-break contract (`CDR-03`), and confirming walkability vs. perimeter slot policy (`CDR-07`).

### Tasks That Can Safely Proceed Independently Now (Once Track A3 Is Authorized)
- `scripts/core/shared_types.gd` enums from `docs/ARCHITECTURE.md` §2 (`Phase`, `OrderKind`, `OrderStatus`, `CustomerState`, `TableState`, `DriverState`, `FixtureKind`).
- Static `.tres` schema definitions (`IngredientDef`, `RecipeDef`, `EconomyConfig`, plus `UtilityDef` with reversible `footprint: Vector2i = Vector2i(1, 1)` default) and the three confirmed starter recipe definitions (`nasi_telor`, `nasi_ayam`, `nasi_komplit` in `docs/CONTENT_AND_TUNING.md`).
- `GameRoot` (`scripts/core/game_root.gd`) phase state machine (`PLANNING -> SERVING -> CLOSING -> RESULTS -> FINISHED`) and monotonic `service_elapsed` clock (`docs/ARCHITECTURE.md` §3), decoupled from concrete World subnode paths.
