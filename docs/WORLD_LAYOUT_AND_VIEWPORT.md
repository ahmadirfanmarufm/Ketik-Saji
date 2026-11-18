# World Composition and Viewport Fit — Layout Reference v2.2 (M5-A Approved)

**Authority:** coordinator's explicit **M5-A World Layout & Customer Seating** approval (2026-11-18) updates the earlier v2.1 sketch (`references/current_screen_layout_NON_BINDING.png`, which used a provisional `13×9` grid with a left-side waiting lane). Read alongside `docs/SHARED_BASELINE.md`, `docs/ARCHITECTURE.md`, `docs/DECISION_REGISTER.md` (`VIS-01`–`VIS-04`), and `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md`.

> **Status note (2026-11-18):**
> - **M5-A1 World Layout (`12×9`):** **Implemented and verified** in `scenes/world/restaurant_world.tscn`, `scripts/world/world_grid.gd`, `scripts/world/world_map.gd`, `scripts/kitchen/kitchen_controller.gd`, and `scripts/ui/game_ui.gd` (validated across all `10` headless test suites — `913/913` assertions — and `640×360` / `480×270` GUI viewport checks).
> - **M5-A2 Customer Seating (`VIS-04`):** **Pending implementation.** `ChairVisual`, `SeatAnchor`, and customer seating changes (including the temporary tabletop placeholder) have **not yet been implemented**.

## 1. Approved M5-A screen and world composition (`12×9` grid, `32×32` px tiles)

| Screen / world region (left → right) | Approved geometry & role | Status | Click / walkability / input contract |
|---|---|---|---|
| **Persistent left vertical UI band (`LeftHUDRegion`)** | Reserved `ui_safe_rect` on the left edge of the single 2D viewport for service/planning HUD (`Hari`, cash, Day 7 target/progress, unspawned quota, controls). | **CONFIRMED (M5-A1 Implemented & Verified).** Coordinator rule: evaluate `World` offset and `LeftHUDRegion` width together rather than assuming an arbitrary offset. Verified in M5-A1 with `GameRoot/World.position = Vector2(144, 36)` and `ui_safe_rect = Rect2(0, 0, 112, 360)` across `640×360` and `480×270` viewports. | UI only, **not** world floor. Blocks world clicks and never triggers player teleport or station selection. |
| **Restaurant interior (`cols 0..7, rows 0..8`)** | Kitchen across upper rows (`cols 0..7, rows 0..3`), divider row (`row 4`: passive long counter `cols 0..5`, `online_station` `(6,4)`, passage `(7,4)`), dining floor across lower rows (`cols 0..7, rows 5..8` except pickup cells). Player starts at **`(6,3)`**. | **CONFIRMED (M5-A1 Implemented & Verified).** Replaces prior `cols 2..10` interior. | Unoccupied walkable floor cells (`is_free()`) teleport the player on left-click. Clicking any registered interactable teleports to its nearest `is_free()` cardinal neighbor and selects/activates in the same click. |
| **Online driver pickup spots (`col 7, rows 5..7`)** | Three authored `DriverPickupSpots` markers (`pickup_spot_01` at `(7,5)`, `pickup_spot_02` at `(7,6)`, `pickup_spot_03` at `(7,7)`). | **CONFIRMED (M5-A1 Implemented & Verified).** | Pickup cells remain **non-walkable** (`is_walkable == false`). Each in-spot driver is clickable and serveable (`saji`) from its adjacent walkable neighbor (e.g. `col 6` or doorway `col 8`). |
| **Interior wall & doorway (`col 8, rows 0..8`)** | Passive interior wall (`dinding`) at `(8,0)..(8,4)` and `(8,8)`; open walkable doorway at `(8,5)..(8,7)`. | **CONFIRMED (M5-A1 Implemented & Verified).** | Wall cells are **non-walkable** passive visuals. Doorway cells `(8,5)..(8,7)` are walkable floor (providing eastern cardinal access to `pickup_spot_01..03`). |
| **Dine-in customer queue (`col 9, rows 0..8`)** | Right-side waiting lane (`antrian`) outside the interior wall, replacing the old left-side waiting lane (`cols 0..1`). Keeps **4 authored `DineInWaitingAnchors`** (`dine_in_wait_01..04`). | **CONFIRMED (M5-A1 Implemented & Verified).** | **Non-walkable** to the player. Patrons remain governed by `ServiceController` (`100s` patience from spawn, FIFO admission to clean tables). |
| **Right-side road & driver overflow (`cols 10..11, rows 0..8`)** | Exterior road/street (`jalan`) along the right edge of the `12×9` grid, hosting `DriverOverflowAnchors` (`driver_overflow`). | **CONFIRMED (M5-A1 Implemented & Verified).** | **Non-walkable** to the player. Queued overflow drivers remain visible with running `60s` timers and non-serveable click feedback, separate from the column-9 dine-in queue. |

### Approved M5-A cell coordinate map (`12` columns × `9` rows)

- **World grid dimensions:** `grid_size = Vector2i(12, 9)`, `tile_size = Vector2i(32, 32)` (`384×288` logical pixels, vs. `416×288` in the old `13×9` layout).
- **Starter fixtures (existing canonical `world_id`s preserved):**
  - `washer` (`wastafel`): `(0, 0)`
  - `stove` (`kompor`): `(1, 0)`
  - `rice_cooker`: `(2, 0)`
  - `storage_box`: `(3, 0)`
  - `plate_rack` (`rak piring`): `(4, 0)`
  - `trash` (`tempat sampah`): `(7, 0)`
  - `work_table` (`prep table`, with child `work_table_stage` and `work_table_chop`): `(3, 2)`
  - `online_station` (`order online`): `(6, 4)`
  - `dining_table_01`: `(2, 7)`
  - `dining_table_02`: `(4, 7)`
- **Authored `PlacementSlots` (`11` total = `5` utility + `6` dining table):**
  - **Utility slots (`5`, up from `2`; `allowed_fixture_kinds = [BOX, FRIDGE, STOVE, WASHER, PLATE_RACK, RICE_COOKER]`):** `(5, 0)`, `(6, 0)`, `(2, 2)`, `(4, 2)`, `(5, 2)` (`slot_utility_01..05`).
  - **Dining-table slots (`6`, up from `2`; `allowed_fixture_kinds = [DINING_TABLE]`):** `(0, 5)`, `(2, 5)`, `(4, 5)`, `(5, 5)`, `(0, 7)`, `(5, 7)` (`slot_table_01..06`, yielding up to `8` total dining tables alongside `dining_table_01..02`).
- **Passive environment elements (visual-only, non-walkable, not staging targets):**
  - **Long counter (`meja panjang`):** `row 4, cols 0..5` (`(0,4)..(5,4)`). Strictly passive decoration — does **not** stage items or register as a work table.
  - **Interior wall (`dinding`):** `col 8, rows 0..4` and `(8,8)`.
- **Player starting cell:** `DEFAULT_START_TILE = Vector2i(6, 3)` (free kitchen floor cell directly north of `online_station` at `(6,4)`).

## 2. Approved M5-A2 customer seating & table art rules (`VIS-04` — Pending Implementation)

- **Child nodes on every dining table:** Each dining table (`dining_table_01`, `dining_table_02`, and dynamically purchased `dining_table_03+` spawned via `WorldMap.spawn_placed_fixture()`) owns:
  - `ChairVisual` (`Sprite2D`) positioned on the **south side** of the table.
  - `SeatAnchor` (`Marker2D`) positioned on the **south side** of the table.
- **Visual-only chair, authoritative table target:**
  - `ChairVisual` and `SeatAnchor` are **not** registered in `WorldRegistry` and do **not** claim additional `WorldGrid` cells.
  - `WorldMap._resolve_customer_visual_position()` resolves `SEATED_WAITING` and `EATING` customers to the assigned table's `SeatAnchor` global position instead of placing them on top of the tabletop.
  - The dining table `Area2D` remains the sole authoritative interaction target for `saji` and `bersihkan`, with hitbox coverage extended over the south chair region where needed so clicking the seated customer/chair area still selects the owning table.
  - `ServiceController` retains sole authority over customer state, FIFO waiting queue, table occupancy, serving, eating, timeouts, cleaning, and day reset. No seating manager or duplicate state may be introduced.
- **Art direction & temporary tabletop placeholder:**
  - `Rect2(416, 160, 32, 32)` in `Warung-Tileset.png` depicts a **chair** and must **not** be used as the dining-table tabletop sprite.
  - Until a dedicated dining-table sprite is confirmed by the art team, the tabletop must use a **clearly identified temporary placeholder** (while `ChairVisual` uses the chair sprite), without inventing or silently substituting unapproved final art.

## 3. Source-level validation status (M5-A1 Verified vs. M5-A2 Pending)

### Completed and verified in M5-A1 (World Layout `12×9`)
1. **`World` offset and `LeftHUDRegion` width coupling (Verified in M5-A1):** With the world width changing from `416` px (`13` cols) to `384` px (`12` cols), `GameRoot/World.position = Vector2(144, 36)`, `GameUI.ui_safe_rect = Rect2(0, 0, 112, 360)`, and `GameUI.world_visible_rect = Rect2(112, 0, 528, 360)` (`Rect2(112, 0, 368, 270)` at `480×270`) were evaluated together and verified across `10` headless test suites (`913/913` assertions) and non-headless GUI viewport checks at `640×360` (`1280×720` window) and `480×270` (including compact `FixtureShopPopup` slot buttons for all `11` slots, HUD click blocking, and screen-to-world coordinate conversion).
2. **M5-A1 marker & hitbox positions (Verified in M5-A1):** Authored and verified local positions for `dine_in_wait_01..04` along column `9` (`(304, 80)`, `(304, 144)`, `(304, 208)`, `(304, 240)` -> cells `(9,2)`, `(9,4)`, `(9,6)`, `(9,7)`), `driver_overflow` in the right-side road (`(368, 240)` -> cell `(11,7)`), `pickup_spot_01..03` at `(240, 176/208/240)` -> non-walkable cells `(7,5)..(7,7)`, and `online_station` at `(208, 144)` -> cell `(6,4)`.
3. **All-slots-occupied cardinal access (Verified in M5-A1):** Verified in headless tests (`tests/test_world_hierarchy.gd` `208/208` PASS and `tests/test_fixture_m4c.gd` `104/104` PASS) that all `12` starter interactables, all `11` `PlacementSlots`, and all `3` `DriverPickupSpots` retain at least one `is_free()` cardinal neighbor both initially and when all `5` utility slots and `6` table slots are simultaneously occupied.

### Pending implementation and source-level validation in M5-A2 (Customer Seating)
1. **South-side `ChairVisual` and `SeatAnchor` offsets (Pending M5-A2):** Author and validate exact south-side local offsets for `ChairVisual` (`Sprite2D`) and `SeatAnchor` (`Marker2D`) on starter tables (`dining_table_01..02`) and dynamically purchased tables (`dining_table_03+`), ensuring seated customers render on the south chair rather than on top of the tabletop.
2. **Extended dining-table hitbox bounds (Pending M5-A2):** Validate the extended/secondary dining-table `CollisionShape2D` covering the south chair region so clicking the chair/customer selects the associated table without overlapping adjacent table, slot, or pickup hitboxes.
3. **Temporary tabletop placeholder & seating regression verification (Pending M5-A2):** Validate that `Rect2(416, 160, 32, 32)` is used only for `ChairVisual`, a clearly identified temporary placeholder is used for the tabletop, and all headless + GUI seating checks pass after M5-A2 implementation.
