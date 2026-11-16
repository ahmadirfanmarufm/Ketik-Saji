# Ketik Saji — Coordinator Decision Review (Milestone 0)

**Date:** 2026-11-16
**Baseline status:** Track A1 (Documentation Consistency Audit) PASS | Track A2 (World Foundation Hardening, Godot 4.7.2) PASS | Milestone 0 **PARTIAL** | Track A3 **NOT STARTED**
**Authority order respected:** Coordinator explicit decisions > `docs/SHARED_BASELINE.md` > `docs/ARCHITECTURE.md` > `docs/DECISION_REGISTER.md` > `docs/systems/*.md` > `docs/WORLD_LAYOUT_AND_VIEWPORT.md` > `docs/IMPLEMENTATION_PLAN.md` / `docs/ACCEPTANCE_TESTS.md` > `CLAUDE.md` / `docs/CODING_STANDARDS.md` > this review.

This document reconciles the seven pre-A3 review items against existing canonical documentation. Nothing here overrides `docs/ARCHITECTURE.md` or `docs/DECISION_REGISTER.md`, and **no unapproved decisions are marked approved**.

---

## Decision Summary Table

Status vocabulary used below:
- **ALREADY ESTABLISHED:** Settled by an existing `CONFIRMED` decision or `TECHNICAL FREEZE` contract; remaining work is implementation or non-functional notation alignment.
- **PARTIALLY ESTABLISHED:** Core architectural boundary or direction is settled, while specific technical/layout/content details remain open.
- **UNRESOLVED (OWNERSHIP CONFLICT):** Existing canonical contract conflicts with current team task assignment and requires explicit agreement before implementation.

| Decision ID | Subject | Current Status | Blocks Track A3 (Core Enums & `.tres` Schemas)? | Required Approvers (if action needed) |
|---|---|---|---|---|
| `CDR-01` | World hierarchy reconciliation | **ALREADY ESTABLISHED** (Implementation pending) | **No** (blocks Milestone 0 canonical World scene & controller wiring) | None for canonical tree (already frozen in `docs/ARCHITECTURE.md` §1); Coordinator + World + controller owners only if requesting a tree amendment |
| `CDR-02` | `Player` scene representation | **ALREADY ESTABLISHED** (Shorthand clarification & UI anchor detail only) | **No** (blocks Milestone 0/1 doc alignment & held-item indicator hook) | None architecturally (`Player` is visual-only); World owner + Movement programmer + `GameUI` owner for anchor detail |
| `CDR-03` | `WorldMap` / `WorldGrid` vs. Movement authority | **PARTIALLY ESTABLISHED** (Spatial-only boundary settled; query helper surface open) | **No** (blocks Movement integration & Milestone 1 routing) | Coordinator, World owner, Movement programmer, `KitchenController` owner |
| `CDR-04` | Movement vs. `KitchenController` ownership | **UNRESOLVED (OWNERSHIP CONFLICT)** | **No** for A3 enums/schemas; **Yes** before controller skeletons / Milestone 1 routing | Coordinator, Movement programmer, `KitchenController` owner |
| `CDR-05` | Viewport and `World` framing (`VIS-01`, `VIS-02`) | **PARTIALLY ESTABLISHED** (Direction & single-viewport rule settled; dimensions/offset open) | **No** (blocks Milestone 0 left HUD band & framing fit test) | Coordinator, World owner, `GameUI` owner, Movement programmer |
| `CDR-06` | Canonical object IDs, fixture footprints, pickup spots, and `OnlineStation` placement | **PARTIALLY ESTABLISHED** (Contracts & starter kit settled; IDs, footprints & coordinates open) | **Partial** (`UtilityDef` footprint field schema vs. scene metadata); data/placement blocks Milestone 0 authoring | Coordinator, World owner, `KitchenController` owner, `ServiceController` owner, `RunController` owner |
| `CDR-07` | `WorldGrid` occupancy vs. floor walkability policy | **PARTIALLY ESTABLISHED** (A2 permissive `occupy()` + strict `is_free()` implemented; placement restriction policy open) | **No** (blocks perimeter/non-walkable placement validation rule) | Coordinator, World owner, Movement programmer |

---

## CDR-01 — World Hierarchy Reconciliation

- **Current status:** **ALREADY ESTABLISHED (Implementation Pending)**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-02 — `Player` Scene Representation

- **Current status:** **ALREADY ESTABLISHED (Shorthand Clarification & Visual Anchor Detail Only)**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-03 — `WorldMap` / `WorldGrid` vs. Movement Authority

- **Current status:** **PARTIALLY ESTABLISHED**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-04 — Movement vs. `KitchenController` Ownership

- **Current status:** **UNRESOLVED (OWNERSHIP CONFLICT)**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-05 — Viewport and `World` Framing (`VIS-01`, `VIS-02`)

- **Current status:** **PARTIALLY ESTABLISHED**
- **Evidence from canonical documentation:**
  - `docs/DECISION_REGISTER.md` (`VIS-01`, `VIS-02`) and `docs/WORLD_LAYOUT_AND_VIEWPORT.md` **confirm**: persistent left vertical UI band (`ui_safe_rect`) + adjacent in-world dine-in waiting lane + restaurant playfield on the right (`world_visible_rect`); single 2D viewport (`World: Node2D` + `UI: CanvasLayer`, no `SubViewport`); UI blocks world click-through; planning/results panels may overlap the world; 32 px art; prior `10×9` size superseded.
  - The same documents explicitly mark **`640×360` logical / `1280×720` display** as an unverified **fit-test candidate**, the ~18% UI band width as illustrative only, and the choice between **World transform/scale offset vs. single `Camera2D`** (`docs/WORLD_LAYOUT_AND_VIEWPORT.md` §2, `docs/ARCHITECTURE.md` §1) as a pending implementation choice requiring Milestone 0 fit verification (§3).
- **Current implementation state:**
  - `project.godot` uses `640×360` viewport / `1280×720` window override, `canvas_items` stretch, and Nearest texture filter (`3`). `GameRoot/World` sits temporarily at `(0, 0)` (no approved offset; `(160, 36)` explicitly unapproved). No `LeftHUDRegion`, `ui_safe_rect`, or `Camera2D` exists yet. At `(0, 0)`, columns `0..1` (`waiting_lane_rect`, `x = 0..64`) would sit under a left HUD strip until offset or framed.
- **Remaining question / implementation dependency:**
  - Still open: (1) Milestone 0 blockout fit validation of `640×360` under worst-case rings, 3 pickup spots + overflow, and longest Indonesian ghost prompt (`docs/WORLD_LAYOUT_AND_VIEWPORT.md` §3); (2) chosen `ui_safe_rect` width and `world_visible_rect` bounds; (3) explicit selection of **World transform offset** vs. **single `Camera2D`**.
- **Recommended next action:**
  - Block out `LeftHUDRegion` (`ui_safe_rect`) and test framing in Milestone 0 (technical preference: `World` position offset inside `world_visible_rect`, since `WorldMap.global_to_cell`/`cell_to_global` already honor `World`'s transform and no scrolling is planned), then confirm resolution/offset after visual check.
- **Required approvers:** Coordinator, World owner, `GameUI` owner, Movement programmer.

### Approval (`CDR-05`)
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-06 — Canonical Object IDs, Fixture Footprints, Pickup Spots, and `OnlineStation` Placement

- **Current status:** **PARTIALLY ESTABLISHED**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

---

## CDR-07 — `WorldGrid` Occupancy vs. Floor Walkability Policy

- **Current status:** **PARTIALLY ESTABLISHED**
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
- **Approved option:**
- **Rejected alternatives:**
- **Approver:**
- **Date:**
- **Notes:**

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
