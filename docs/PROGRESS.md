# Developer progress (update after every Claude Code milestone)

**Project status as of 2026-11-15:** Architecture integrated/revised. **Implementation not started or verified by this documentation package.** No claim that any Godot scene/script exists yet. *(Historical statement. Superseded in part: a partial Milestone 0 World Foundation now exists; see "World Foundation status update" at the end of this file. Nothing beyond that foundation is implemented.)*

| Milestone | Status | Evidence / files / tests |
|---|---|---|
| 0 — Godot skeleton, data, phase and clock | COMPLETE — World Foundation (A2) + Core Data (A3) + GameRoot Foundation + World Hierarchy Migration + Controller Skeletons (`KitchenController`, `ServiceController`, `RunController`) + `GameUI` Foundation (`LeftHUDRegion` `112×360` + `World` at `(144, 36)`) validated | WorldGrid/WorldRegistry/WorldMap (A2 PASS), `SharedTypes` & `.tres` schemas/assets (A3 PASS), `GameRoot` phase/clock (`tests/test_game_root.gd` PASS), canonical `World` hierarchy (`tests/test_world_hierarchy.gd` PASS), `KitchenController` + `ServiceController` + `RunController` (`tests/test_controllers_m0.gd` PASS), `GameUI` (`scenes/ui/game_ui.tscn`, `scripts/ui/game_ui.gd`, `tests/test_game_ui_m1.gd` PASS, Godot 4.7.2). |
| 1 — World click/typing and first playable dish | COMPLETE — Full M1 kitchen gameplay loop (`storage` retrieval, `washer` `cuci`, `rice_cooker` `masak`/`nasi`, `stove` `goreng`, `work_table_chop` `potong`, `plate_rack`, `work_table_stage` staging/merging, `trash`, `nasi_telor` assembly, and visual sync) validated (`tests/test_game_ui_m1.gd` PASS) | Implemented `KitchenController` item retrieval, `IngredientTransition`-driven processing, single held aggregate, finite plate pickup/return, `WorkTable` staging & recipe-driven multiset merging (`nasi_telor` in any plating order), `Trash` food discard preserving plate ID, read-only view getters, and `PlayerVisual`/`WorldMap`/`GameUI` visual synchronization (`105/105` checks PASS, zero leaks). |
| 2 — Dine-in serving, washing, multiple customer queue | COMPLETE — Full M2 dine-in customer gameplay loop (`t=0` & `20.0s` spawns, weighted recipe selection, outside FIFO queue, lowest-ID table seating, `100.0s` patience deadline & expiry, `saji` serving + `credit_order_once`, `20.0s` eating -> `DIRTY`, `bersihkan` cleanup + washer dirty plate transfer + FIFO admission, and customer/table visual sync) validated (`tests/test_service_m2.gd` PASS) | Implemented `ServiceController` dine-in spawning/timers/serving/cleaning, `KitchenController` `try_consume_serving_item()` & `saji`/`bersihkan` dispatch, `GameRoot` M2 wiring, `WorldMap.sync_dine_in_visuals()` (`npc 1.png`–`npc 7.png`), and `GameUI` order/dirty status feedback (`41/41` checks PASS, zero leaks). |
| 3 — Online offer, physical drivers and deadlines | COMPLETE — M3.1 `ServiceController` Lifecycle + M3.2 `KitchenController` Commands + M3.3 `WorldMap`/`GameUI` Presentation & Overflow Interaction + Acceptance Hardening COMPLETE (`OnlineStation` preview dish/availability tint, in-spot & overflow driver countdown overlays, clickable overflow queue feedback `"Pengantar belum mendapatkan tempat pickup."` without `saji`, idempotent signal wiring, no-pause modal overlay clock/deadline tests, online-expiry auto-close drain test, and typed `saji` edge cases; `tests/test_service_m3.gd` `98/98` checks PASS, exit `0`) | `scripts/service/service_controller.gd`, `scripts/kitchen/kitchen_controller.gd`, `scripts/world/world_map.gd`, `scripts/ui/game_ui.gd`, `scenes/ui/game_ui.tscn`, `tests/test_service_m3.gd` (+ `.uid`, `98/98` checks PASS, zero leaks). |
| 4 — Selected storage purchases, fixtures and economy | NOT STARTED | |
| 5 — Seven-day progression, win/extra, menu data intake | NOT STARTED | |
| 6 — Art/UI integration, balancing, QA/export | PARTIAL — Phase 1 Art Integration (environment tileset, fixture sprites, player sprite, customer/driver/employee texture bindings, ingredient `.tres` visual mappings) validated | `Warung-Tileset.png` integrated into `FloorTiles` (`13×9` grid) and 10 fixture `Sprite2D` nodes; `player.png` integrated into `scenes/player/player.tscn`; `npc gojek.png`, `pegawai.png`, and `npc 1.png`–`npc 7.png` bound on `WorldMap` with `sync_driver_visuals()`; unambiguous ingredient textures mapped on `ayam.tres`, `telur.tres`, `tempe.tres`, `beras.tres`, `sayur.tres` (`tests/test_world_hierarchy.gd` 123/123 PASS, `tests/test_track_a3.gd` 68/68 PASS). |

## Current next task

Read `CLAUDE.md`, `docs/ARCHITECTURE.md`, and `docs/IMPLEMENTATION_PLAN.md` Milestone 0. Build only Milestone 0 and run its acceptance tests. Ask the coordinator only if an essential source file or asset that cannot be stubbed blocks work.

## Log format for developer

```
Date / Git commit:
Milestone completed/current:
Files added/modified:
Godot version / platform:
Tests ACTUALLY run and results:
Blocked by art/content (recipe/icon/map IDs)/TUNING:
Divergence from architecture (requires coordinator approval if gameplay):
Next concrete task:
```

Keep this short. Don't copy entire chat histories; Git and these docs are the durable context.

### Layout reference update (pre-development, v2.1)

Latest visual brief added: `docs/WORLD_LAYOUT_AND_VIEWPORT.md` + `references/current_screen_layout_NON_BINDING.png`. Milestone 0 must block out left UI / visible dine-in waiting lane / restaurant right and provide physical online driver anchors. Prior **10×9** assumption superseded; viewport 640×360 still trial-only. No Godot implementation or viewport fit test has yet been performed as part of this documentation update.

### World spatial foundation (Milestone 0 partial — Player visual + World grid/registry/blockout)

```
Date / Git commit: 2026-11-16 / no git repository
Milestone completed/current: Milestone 0 PARTIAL — Player visual scene, WorldMap/WorldGrid/WorldRegistry, grid-aligned blockout. GameRoot, controllers, UI band, phase/clock NOT done.
Files added/modified: added scripts/player/player_visual.gd, scripts/world/world_map.gd, world_grid.gd, world_registry.gd; modified scenes/player/player.tscn, scenes/world/restaurant_world.tscn (script, positions, world_id metadata)
Godot version / platform: target 4.7.2 / Windows. NO Godot executable available to the assistant — scenes/scripts were NOT opened, parsed or run in the engine. [Historical, as of this entry; engine validation was done later, see the status update below.]
Tests ACTUALLY run and results: external Python layout check of restaurant_world.tscn (zones tile the 13x9 grid with no overlap; all 13 world_ids unique; fixture/table footprints do not overlap; every fixture has a free cardinal neighbor; Player cell free; pickup spots have a walkable neighbor) — PASS. Format check of .gd files (tabs, LF, <100 cols) — PASS. Engine parse/run, grid conversion and registry duplicate tests — NOT RUN (pending developer opening project in Godot).
Blocked by art/content (recipe/icon/map IDs)/TUNING: no fixture footprint sizes, no purchasable slot_id/allowed-category/tile-anchor data, no online acceptance station position, no final art/tileset. Fixture cells, zone rects and the Player start cell are provisional blockout values.
Divergence from architecture (requires coordinator approval if gameplay): none gameplay-related. restaurant_world.tscn uses the pre-existing node names (Floor/Fixtures/DiningArea/...) rather than ARCHITECTURE.md's canonical names (FloorTiles/KitchenStations/DiningTables/...). Not renamed; needs a decision. [Resolved afterwards: the scene now uses FloorTiles/KitchenStations/DiningTables; see the status update below.]
Next concrete task: open in Godot, confirm no parse/runtime errors and blockout visuals; GameRoot instantiate World with a chosen offset; define slot/footprint data; KitchenController consumes WorldMap/WorldGrid.
```


### World Foundation status update (Milestone 0 partial — reconciled with ARCHITECTURE.md)

```
Date / Git commit: entry added 2026-11-16 (documentation reconciliation); completion date of the visual check not recorded / no git repository
Milestone completed/current: Milestone 0 PARTIAL — World Foundation (spatial layer, blockout scene, Player visual placeholder, GameRoot instancing). Milestone 0 is NOT complete.
Files added/modified: docs/PROGRESS.md (this update); scripts/world/world_map.gd (header comment only — stale node names corrected; no logic change); scenes/main/game_root.tscn (RestaurantWorld instance added in the earlier integration task)
Godot version / platform: 4.7.2 stable / Windows
Tests ACTUALLY run and results: see "Validated behavior" below.
Blocked by art/content (recipe/icon/map IDs)/TUNING: final TileSet/art, slot_id/table_id/spot_id data, fixture footprint sizes, approved world offset.
Divergence from architecture (requires coordinator approval if gameplay): none gameplay-related; structural deviations listed under "Implementation deviations / pending reconciliation".
Next concrete task: see "Next milestone".
```

**Completed implementation** (source-inspected 2026-11-16)

- `WorldGrid` (`scripts/world/world_grid.gd`, `RefCounted`): top-left cell origin, local-space cell/position conversion, bounds, floor walkability, single-ID footprint occupancy (all-or-nothing `occupy`/`release`), cardinal and footprint-neighbor queries in fixed order up/right/down/left.
- `WorldRegistry` (`scripts/world/world_registry.gd`, `RefCounted`): stable-ID (`StringName`) to `Node2D` map; rejects empty ID, null node, duplicate ID, and a node already registered under another ID.
- `WorldMap` (`scripts/world/world_map.gd`, root script of the World scene): owns one `WorldGrid` and one `WorldRegistry`, global/local cell conversion honoring its transform, atomic `register_object`/`unregister_object`, scene-authored registration of `world_id` metadata on `_ready`, temporary `_draw` blockout (`show_blockout`). Spatial data only; owns no orders, stock, cash or Player tile.
- World Foundation scene blockout (`scenes/world/restaurant_world.tscn`, kept as an independent reusable scene): 13×9 grid of 32 px cells with provisional zone rects (waiting lane, kitchen, dining, online), 7 kitchen stations, 2 dining tables, 3 pickup markers and 1 overflow marker, 13 unique `world_id` values.
- Current scene node naming: `FloorTiles`, `KitchenStations`, `DiningTables` (plus `Decorations`, `WaitingLane`, `OnlineArea`, `PlacementSlots`, `Player`). `@onready` paths in `WorldMap` use these names. No remaining `Floor`/`Fixtures`/`DiningArea` node references in scenes or scripts; the stale header comment in `world_map.gd` and the earlier divergence note above were corrected.
- Player visual placeholder (`scenes/player/player.tscn`, `scripts/player/player_visual.gd`): placeholder sprite and optional animation hook, visual-only; instanced in the World scene at (208, 144) = cell (6, 4).
- Restaurant World scene instantiation: `scenes/main/game_root.tscn` instances `res://scenes/world/restaurant_world.tscn` at (0, 0). *(Historical at entry time: child instance was named `RestaurantWorld`; later renamed to canonical `World` on `GameRoot`, while internal scene root remains `RestaurantWorld` and resource path remains `res://scenes/world/restaurant_world.tscn`.)* `project.godot` main scene is `game_root.tscn`.

**Validated behavior**

- Headless Godot 4.7.2 checks, in a scratch copy of the project (about 40 checks, all passed): World scene loads and instantiates; the three final node names exist and the old names do not; 13 IDs register; cell/local conversion round-trips including out-of-bounds cells and negatives; bounds; transform-aware global/cell conversion; walkable set (81 cells; lane and online area not walkable); fixture cells walkable but not free; Player cell free; registration rejects overlap, duplicate ID, out-of-bounds cell, duplicate cells and one node under two IDs with no leaked state; `unregister_object` frees the footprint; `PlayerVisual` returns false for an unknown animation. These ran on `restaurant_world.tscn` alone, before the GameRoot integration.
- Visual validation in the Godot 4.7.2 editor/game window was completed by the developer, covering the integrated GameRoot → RestaurantWorld scene. Detailed per-item results were not recorded in this file.
- Not run: a headless run of the `GameRoot` main scene by the assistant; any click, input, UI-band or viewport-fit test (no such systems exist yet).

**Implementation deviations / pending reconciliation** (`docs/ARCHITECTURE.md` stays canonical and is not weakened by this table)

| ARCHITECTURE.md canonical scene tree | Current implementation | Status |
|---|---|---|
| `GameRoot [scripts/core/game_root.gd]` | `GameRoot` Node2D with no script | Pending (phase/clock/controller wiring) |
| `World [Node2D; world/map assembly]` | Internal scene root `RestaurantWorld` (`WorldMap`); `GameRoot` instance initially `RestaurantWorld`, later renamed to `World` | **[Historical / resolved for instance name]** At entry time this was a name deviation (`RestaurantWorld`); later reconciled so `GameRoot/World` instances `res://scenes/world/restaurant_world.tscn` (internal root `RestaurantWorld` kept) |
| `FloorTiles` | `FloorTiles` TileMapLayer, no TileSet | Name matches; content pending |
| `DineInWaitingAnchors` | `WaitingLane` empty Node2D; lane exists only as a `WorldMap.waiting_lane_rect` blockout zone | Not equivalent and not implemented; no authored waiting anchors |
| `Player [Node2D / Sprite2D]` | `Player` instance (root `PlayerVisual`, placeholder sprite) | Present as a visual only; player tile is not wired to `KitchenController` |
| `KitchenStations` (fridge, box, stove, cooker, washer, rack, trash) | `KitchenStations`: StorageBox, Stove, Washer, PlateRack, RiceCooker, WorkTable, Trash | Name matches; no fridge node (starter kit has 1 box); `WorkTable` sits here, not in a separate node |
| `KitchenWorkTables` (staging and chopping hitboxes) | Not present | Pending |
| `DiningTables` | `DiningTables`: DiningTable01, DiningTable02 | Name matches; no hitboxes or table state |
| `OnlineStation [Area2D]` | Not present | Pending |
| `DriverPickupSpots` (3 authored markers) | 3 `Marker2D` (`PickupSpot01-03`) under `OnlineArea` | Different parent and node; same intent, not identical |
| `DriverOverflowAnchors` | Single `Marker2D` `DriverOverflow` under `OnlineArea` | Provisional; not an authored queue area |
| `DriverObjects` | Not present | Pending |
| `PlacementSlots` | `PlacementSlots`, empty | Present; no authored `slot_id` data |
| `KitchenController`, `ServiceController`, `RunController`, `UI [CanvasLayer]` under `GameRoot` | None present | Pending |
| (not in canonical tree) | `Decorations`, `WaitingLane`, `OnlineArea` containers; `WorldMap`/`WorldGrid`/`WorldRegistry` scripts | Temporary World Foundation blockout/support structure; the `WorldMap` helpers are additive and not part of the frozen method catalog. No frozen API or ownership boundary was changed |

The current hierarchy is a temporary blockout, not the intended final integrated world scene. Differently named nodes above are not assumed to have the same responsibilities.

Other notes: `world_id` values (e.g. `storage_box`, `pickup_spot_01`) are provisional blockout IDs and were not checked against final `table_id`/`slot_id`/`spot_id` conventions. *(Historical at entry time: `project.godot` used `config/name="WarungKetik"` and several docs referenced `ARCHITECTURE.md` at repo root; both later updated — `project.godot` now uses `config/name="Ketik Saji"` and doc links point to `docs/ARCHITECTURE.md` / `../ARCHITECTURE.md`.)*

**Later rename note — [Historical / resolved]**

Per `docs/ARCHITECTURE.md`, the `GameRoot` child is named `World`. *(Historical note from 2026-11-16 before the rename was performed: this change touched only the instance name in `scenes/main/game_root.tscn` while keeping the scene resource path `res://scenes/world/restaurant_world.tscn` and internal root node name `RestaurantWorld` inside `restaurant_world.tscn`; the instance rename was subsequently completed and verified.)*

**Pending integration**

- `GameRoot` script, root phase enum and service-only `service_elapsed` clock.
- `KitchenController`, `ServiceController`, `RunController` and `UI` CanvasLayer wiring; floor/object click routing and typed commands (Milestone 1 scope).
- Left UI band and `ui_safe_rect`/`world_visible_rect`; one chosen transform-or-camera approach per WORLD_LAYOUT_AND_VIEWPORT.md.
- Authored canonical nodes: dine-in waiting anchors, `KitchenWorkTables`, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, and `slot_id`/`table_id`/`spot_id` data.
- *[Historical / resolved for `World` instance name]* The `GameRoot` child instance was subsequently renamed to `World` (internal scene root remains `RestaurantWorld`; resource path remains `res://scenes/world/restaurant_world.tscn`). Reconciling remaining node-hierarchy differences (`KitchenWorkTables`, `DineInWaitingAnchors`, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots`) stays pending.

**Known limitations**

- World transform offset remains provisional at `(0, 0)`; `(160, 36)` is not an approved offset.
- Final TileSet and final art are not integrated (`FloorTiles` has no TileSet; visuals are `_draw` blockout and a gradient placeholder).
- Fixture footprints are provisional single-cell footprints taken from node position.
- *[Historical / resolved in Track A2]* Automatic cleanup of freed registered objects and `WorldGrid` dimension/walkability validation were subsequently implemented and validated in Track A2 (with `WorldGrid.occupy()` still intentionally permissive on non-walkable cells unless policy changes).
- Movement and `KitchenController` integration remain pending.
- The current World scene hierarchy is not yet the complete canonical architecture.

**Next milestone**

Continue Milestone 0 (see `docs/IMPLEMENTATION_PLAN.md`): `GameRoot` script with phase/clock, controller and UI placeholders, left UI band blockout and chosen world offset/camera approach, and authored canonical World nodes. Then Milestone 1, where `KitchenController` consumes `WorldMap`/`WorldGrid` for floor/object clicks. *(Historical note: the `RestaurantWorld` → `World` instance rename and Track A2 freed-object lifecycle cleanup were subsequently completed; see the later entries below.)*


### World Foundation Track A2 hardening (Milestone 0 partial — validation and lifecycle cleanup)

```
Date / Git commit: 2026-11-16 / no git repository
Milestone completed/current: Milestone 0 PARTIAL — Track A2 (WorldGrid init validation + registered-object SceneTree cleanup, runtime-validated). Milestone 0 is NOT complete.
Files added/modified: scripts/world/world_grid.gd, scripts/world/world_registry.gd, scripts/world/world_map.gd, docs/PROGRESS.md (updated with validation outcome); external test harness outside repo: C:\Users\Pongo\.gemini\antigravity\brain\f31d3581-406f-48e7-9beb-1e2f106a4860\scratch\test_world_a2.gd
Godot version / platform: Godot 4.7.2 (Windows)
Tests ACTUALLY run and results: static inspection and formatting check of scripts/world/*.gd (UTF-8 without BOM, LF endings, tabs only, <= 99 chars) — PASS. Local headless Godot 4.7.2 run of external test_world_a2.gd — PASS (`SUMMARY fails=0`; all assertions passed; no unexpected SCRIPT ERROR; no CanvasItem RID or ObjectDB leak warnings; intentional negative-test push_error messages expected). Note: the test harness was previously fixed outside the repo so it does not pass a freed object into WorldRegistry's Node2D-typed parameter (which aborts in GDScript before function entry and had caused 2 test-side Node2D leaks).
Blocked by art/content (recipe/icon/map IDs)/TUNING: unchanged (final TileSet/art, slot_id/table_id/spot_id data, fixture footprint sizes, approved world offset/framing).
Divergence from architecture (requires coordinator approval if gameplay): none introduced. Note from prior update resolved externally: GameRoot now instances restaurant_world.tscn as `World` (not `RestaurantWorld`), matching docs/ARCHITECTURE.md; remaining world child-node hierarchy differences (WaitingLane, OnlineArea, WorkTable placement, missing OnlineStation/KitchenWorkTables/DriverObjects) remain provisional blockout structure.
Next concrete task: resolve Milestone 0 Track B framing/hierarchy/ownership decisions (or authorize Track A1 doc-link cleanup / Track A3 core enums and `.tres` schemas) before proceeding to GameRoot, controller skeletons, and GameUI blockout. Do not modify Movement or KitchenController ownership boundaries without owner confirmation.
```

**Validation and cleanup behavior implemented**

- `WorldGrid` (`scripts/world/world_grid.gd`): `_init()` validates `grid_size.x > 0 and grid_size.y > 0` and `cell_size.x > 0 and cell_size.y > 0`. On invalid input it logs `push_error()`, zeroes `size` and `tile_size`, and marks `_valid = false` (exposed via additive `is_valid() -> bool`). When invalid, `is_in_bounds`, `set_walkable`, `set_walkable_rect`, and `occupy` fail closed; `cell_to_local` returns `Vector2.ZERO`, `local_to_cell` returns `Vector2i(-1, -1)` (no division by zero), and `cell_rect_to_local` returns `Rect2()`. All existing public method signatures and valid-input behavior are preserved.
- `WorldRegistry` (`scripts/world/world_registry.gd`): `register_object()` and `find_id()` guard with `is_instance_valid()` to reject freed as well as null nodes (note: Godot 4.7.2's `Node2D`-typed parameter also enforces valid class identity at the call boundary). Added `unregister_node(object_id, node) -> bool` so cleanup verifies exact node identity and an old node cannot unregister a replacement registration under the same ID. Existing signatures (`register_object`, `unregister_object`, `has_object`, `get_object`, `find_id`, `get_ids`) are preserved.
- `WorldMap` (`scripts/world/world_map.gd`): connects `node.tree_exiting` (bound with `object_id` and `node.get_instance_id()`) only after both `WorldRegistry` and `WorldGrid` succeed. Leaving the SceneTree (e.g. `queue_free()` or `remove_child()`) verifies exact registry node and instance ID, unregisters via `unregister_node()`, disconnects the signal, releases the grid footprint, and schedules redraw safely if still in tree and not queued for deletion. Manual `unregister_object()` disconnects the cleanup signal before releasing; `NOTIFICATION_PREDELETE` disconnects any remaining cleanup signals so `WorldMap` teardown leaves no dangling connections on external nodes. No autoload or object manager was added; `occupy()` walkability policy and existing layouts/offsets were not changed.

**Remaining limitations and Milestone 0 work**

- Nodes freed directly via `free()` while never added to the SceneTree do not emit `tree_exiting` (though `get_object()` returns `null`, `register_object()`/`find_id()` guard invalid instances, and manual `unregister_object()` safely skips invalid nodes).
- `WorldGrid.occupy()` still does not require cells to be walkable (deliberately unchanged in Track A2).
- Remaining Milestone 0 deliverables (not started): `GameRoot` script (`scripts/core/game_root.gd`) with phase machine and `service_elapsed` clock, `SharedTypes` enums, `KitchenController`/`ServiceController`/`RunController` skeletons, `GameUI` (`CanvasLayer` + left HUD band + `Start Service` flow + input isolation), `.tres` schemas/starter data, canonical World hierarchy reconciliation (`DineInWaitingAnchors`, `KitchenWorkTables`, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots` slot data, `Area2D` hitboxes), and approved World offset/framing.
- Minor doc/config follow-up completed in Task A1: remaining `ARCHITECTURE.md` relative-path fixes across `docs/*.md` and `docs/systems/*.md` plus status reconciliation in this file.

### Task A1 — Documentation consistency audit and link cleanup (2026-11-16)

```
Date / Git commit: 2026-11-16 / no git repository
Milestone completed/current: Milestone 0 PARTIAL (documentation audit only; Milestone 0 is NOT complete)
Files modified: docs/SHARED_BASELINE.md, docs/README_START_HERE.md, docs/CODING_STANDARDS.md, docs/WORLD_LAYOUT_AND_VIEWPORT.md, docs/IMPLEMENTATION_PLAN.md, docs/REVISION_TRACE.md, docs/PROGRESS.md, docs/systems/01_INTERACTION_KITCHEN.md, docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md, docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md
Godot version / platform: N/A (documentation-only pass; no .gd, .tscn, .tres, or project.godot changes)
Tests ACTUALLY run and results: documentation link/path verification and LF line-ending check (no runtime tests modified or re-run; Track A2 runtime result remains 4.7.2 stable / SUMMARY fails=0)
Next concrete task: Milestone 0 Track A3 / coordinator resolution of open layout, ID, and World/Movement interface items, plus GameRoot/controller/UI placeholders per docs/IMPLEMENTATION_PLAN.md
```

**Audit summary**

- `CLAUDE.md` location verified at repository root (`CLAUDE.md`); zero broken `docs/CLAUDE.md` links found across docs.
- Broken relative links to `ARCHITECTURE.md` fixed (`../ARCHITECTURE.md` or bare `ARCHITECTURE.md` updated to `docs/ARCHITECTURE.md` from `docs/*.md`; `../../ARCHITECTURE.md` updated to `../ARCHITECTURE.md` from `docs/systems/*.md`; stale `README_START_HERE.md` link in `docs/REVISION_TRACE.md` updated to `docs/README_START_HERE.md`).
- Canonical naming distinction affirmed: scene resource filename is `res://scenes/world/restaurant_world.tscn`, internal scene root node name is `RestaurantWorld`, and `GameRoot` child instance name is `World`.
- Historical entries in this file preserved and annotated where `World` rename, `Ketik Saji` project name, and Track A2 validation superseded earlier pending notes.

**Unresolved architectural conflicts & decisions requiring coordinator approval**

- **World scene node hierarchy mismatch (`docs/ARCHITECTURE.md` vs. `scenes/world/restaurant_world.tscn`):** `docs/ARCHITECTURE.md` specifies `DineInWaitingAnchors`, `KitchenWorkTables` (with staging + chopping subzones), `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, and `PlacementSlots`; the blockout scene currently uses `Decorations`, empty `WaitingLane`, `OnlineArea` (`PickupSpot01`–`03`, `DriverOverflow`), and `WorkTable` inside `KitchenStations`.
- **Player scene representation:** `docs/ARCHITECTURE.md` lists `Player [Node2D / Sprite2D]`, whereas `scenes/player/player.tscn` uses `Player [Node2D; PlayerVisual]` with `Visual/Sprite`, `Visual/AnimationPlayer`, and `VisualAnchor`.
- **Movement / `KitchenController` / `WorldMap` query contract & ownership boundary:** `docs/ARCHITECTURE.md` and `docs/systems/01_INTERACTION_KITCHEN.md` assign `player_tile`, `selected_target_id`, `accepted_prefix`, and click routing to `KitchenController`, while current task division gives Movement/click routing to the Movement programmer; exact read/write boundary over `WorldMap`/`WorldGrid` remains unconfirmed.
- **Framing, viewport, and `World` offset (`VIS-01`, `VIS-02`):** `project.godot` uses `640x360` / `1280x720` (`canvas_items`) and `World` stays temporarily at `(0, 0)`; `ui_safe_rect` width and whether framing uses a `World` offset (not assuming `(160, 36)`) or `Camera2D` remain open.
- **Map IDs, footprints, and walkability policy:** final `slot_id`/`table_id`/`spot_id` values, fixture footprint sizes, `OnlineStation` coordinates, and whether `WorldGrid.occupy()` should enforce `is_walkable()` remain open.

### Track A3 — Shared enums, static `.tres` schemas, and coordinator decision alignment (2026-11-16)

```
Date / Git commit: 2026-11-16 / no git repository
Milestone completed/current: Milestone 0 PARTIAL — Track A3 completed & validated (Milestone 0 still incomplete)
Files added/modified: added scripts/core/shared_types.gd, scripts/kitchen/{ingredient_transition,ingredient_def,recipe_part_def,recipe_def}.gd (+ .uid), scripts/economy/{utility_def,recipe_economy_entry,economy_config}.gd (+ .uid), data/ingredients/*.tres (6 files), data/recipes/*.tres (3 authored recipes only), data/utilities/*.tres (7 fixture kinds), data/economy_config.tres, tests/test_track_a3.gd (+ .uid); updated docs/ARCHITECTURE.md, docs/DECISION_REGISTER.md, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (0 script parse errors, all 8 classes & 17 `.tres` assets imported); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (`SUMMARY fails=0`, 60 assertions); `test_world_a2.gd` re-run on workspace — PASS (`SUMMARY fails=0`); formatting check (tabs, LF, no BOM, <100 cols, `.uid` files) — PASS.
Blocked by art/content (recipe/icon/map IDs)/TUNING: Days 4–7 RecipeDef/icon content intake (3 authored recipes only; `EconomyConfig.validate()` emits expected Days 4–7 pending warning), final art/TileSet, scene-authored `PlacementSlots`/`OnlineStation` coordinates, approved World framing offset/viewport fit test.
Divergence from architecture (requires coordinator approval if gameplay): none; aligned `docs/ARCHITECTURE.md` §3 (`unlock_day` lives in `RecipeEconomyEntry`) and §2/`DECISION_REGISTER.md` per 2026-11-16 coordinator directive (`KitchenController` sole owner Option A; `Decorations` permitted visual-only; walkability-agnostic `WorldGrid.occupy()` preserved).
Next concrete task: Continue Milestone 0 — align `scenes/world/restaurant_world.tscn` & `world_map.gd` to canonical `ARCHITECTURE.md` §1 containers (`DineInWaitingAnchors`, `KitchenWorkTables` split targets, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots`), then build `GameRoot` (`game_root.gd`), controller skeletons, and `GameUI` left-band blockout for `640×360` fit test.
```

### Milestone 0 — GameRoot Foundation (2026-11-16)

```
Date / Git commit: 2026-11-16 / no git repository
Milestone completed/current: Milestone 0 PARTIAL — GameRoot Foundation completed & validated (Milestone 0 still incomplete)
Files added/modified: added scripts/core/game_root.gd (+ .uid), tests/test_game_root.gd (+ .uid); modified scenes/main/game_root.tscn (attached GameRoot script while keeping World instance intact), docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (0 parse errors); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (`SUMMARY fails=0`, zero leaks; includes unbound/missing-`is_drained()`/non-drained/repeat close-guard negative checks); `res://tests/test_track_a3.gd` — PASS (`SUMMARY fails=0`); `test_world_a2.gd` — PASS (`SUMMARY fails=0`); `godot --headless --path . --quit-after 2` — PASS (exit 0).
Blocked by art/content (recipe/icon/map IDs)/TUNING: unchanged (Days 4–7 recipes/icons, final art/TileSet, PlacementSlots/OnlineStation coordinates, World framing fit test).
Divergence from architecture (requires coordinator approval if gameplay): none; implements frozen `docs/ARCHITECTURE.md` §3 & §5 (`start_service_requested`, `request_continue_from_results`, `request_extra_mode`, `request_close_if_drained`, `is_serving`, `get_service_elapsed`, `phase_changed`). Note: `request_close_if_drained()` fails closed unless `ServiceController` is bound and `is_drained()` returns `true`; Day 7 transitions `CLOSING -> FINISHED` so `request_continue_from_results()` stays scoped to Days 1–6 and Extra Mode (Day 8+) per §5 line 129.
Next concrete task: Continue Milestone 0 — migrate `scenes/world/restaurant_world.tscn` & `scripts/world/world_map.gd` to canonical `docs/ARCHITECTURE.md` §1 containers (`DineInWaitingAnchors`, `KitchenWorkTables` split staging/chop targets, `OnlineStation`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots`, keeping passive `Decorations`) and hitboxes, then build controller skeletons and `GameUI` left-band blockout.
```

### Milestone 0 — World Hierarchy Migration (2026-11-16)

```
Date / Git commit: 2026-11-16 / post-31d0bb1
Milestone completed/current: Milestone 0 PARTIAL — World Hierarchy Migration completed & validated (Milestone 0 still incomplete)
Files added/modified: modified scenes/world/restaurant_world.tscn, scripts/world/world_map.gd, docs/PROGRESS.md; added tests/test_world_hierarchy.gd (+ .uid)
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (0 parse errors); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (`SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (`SUMMARY fails=0`); `res://tests/test_track_a3.gd` — PASS (`SUMMARY fails=0`); `res://tests/test_game_root.gd` — PASS (`SUMMARY fails=0`); `godot --headless --path . --quit-after 2` — PASS (exit 0); formatting & UID check — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: Days 4–7 recipes/icons, final art/TileSet, and `LeftHUDRegion` + `World` framing fit test.
Divergence from architecture (requires coordinator approval if gameplay): none; migrated `World` to the 12 canonical containers (`FloorTiles`, `DineInWaitingAnchors`, `Player`, `KitchenStations`, `KitchenWorkTables` with `WorkTable` + non-overlapping `work_table_stage`/`work_table_chop` child `Area2D` targets, `DiningTables`, `OnlineStation` `Area2D`, `DriverPickupSpots`, `DriverOverflowAnchors`, `DriverObjects`, `PlacementSlots`, passive `Decorations`) and added stateless `get_target_footprint`, `get_free_cardinal_neighbors`, and `find_nearest_free_neighbor` helpers to `WorldMap`.
Next concrete task: Continue Milestone 0 — implement controller skeletons (`KitchenController` + internal Movement helper, `ServiceController`, `RunController`) and `GameUI` (`CanvasLayer` + `LeftHUDRegion` blockout) and wire them under `GameRoot`.
```

### Milestone 0 — Controller Skeletons and GameRoot Integration (2026-11-16)

```
Date / Git commit: 2026-11-16 / post-ef32f1e
Milestone completed/current: Milestone 0 PARTIAL — Controller Skeletons (`KitchenController`, `ServiceController`, `RunController`), `GameRoot` integration, and transaction/state-ownership hardening completed & validated (Milestone 0 still incomplete: `GameUI` blockout & framing fit test remain)
Files added/modified: added scripts/kitchen/kitchen_controller.gd (+ .uid), scripts/service/service_controller.gd (+ .uid), scripts/economy/run_controller.gd (+ .uid), tests/test_controllers_m0.gd (+ .uid); modified scripts/core/game_root.gd, scenes/main/game_root.tscn, tests/test_game_root.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (0 parse errors); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (105/105 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (90/90 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (93/93 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (54/54 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (108/108 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); formatting & UID check — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: Days 4–7 recipes/icons, final art/TileSet, and `GameUI` (`LeftHUDRegion`) + `World` framing fit test.
Divergence from architecture (requires coordinator approval if gameplay): none; `KitchenController` tracks delivered `purchase_id`s for once-only stock receipt/reservation and rolls back reservations via `release_reserved_capacity()` on failed synchronous commit; `RunController` is sole owner of `day_index`, `day_7_outcome`, and extra-mode progression (`GameRoot` derives day/outcome from `RunController`), populates all 18 `DaySettlementView` keys from ledger/report data, enforces one-time `start_new_run()` initialization (full cross-controller run reset is not defined; one fresh run per launch per SHARED_BASELINE.md), and validates phase/frozen plan prices; `GameRoot` requires valid `KitchenController`, `ServiceController`, and `RunController` (`finalize_plan() == true`) before entering `SERVING`.
Next concrete task: Continue Milestone 0 — implement `GameUI` (`CanvasLayer` + `LeftHUDRegion` blockout & framing fit test).
```

### GameUI Foundation and Milestone 1 — Input & Interaction (2026-11-16)

```
Date / Git commit: 2026-11-16 / post-65a25b9
Milestone completed/current: Milestone 0 COMPLETE (`GameUI` Foundation + Candidate B viewport fit) & Milestone 1 PARTIAL (World click routing, `InteractionDialogue`, and keyboard prefix forwarding completed, hardened, & validated; full kitchen item/dish assembly remains)
Files added/modified: added scripts/ui/game_ui.gd (+ .uid), scenes/ui/game_ui.tscn, tests/test_game_ui_m1.gd (+ .uid); modified scenes/main/game_root.tscn, scripts/core/game_root.gd, scripts/kitchen/kitchen_controller.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (0 parse errors); `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (65/65 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (105/105 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (90/90 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (93/93 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (54/54 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (108/108 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); formatting, UID, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: Days 4–7 recipes/icons and final pixel/UI art assets (placeholder UI and blockout visuals active).
Divergence from architecture (requires coordinator approval if gameplay): none; applied Candidate B framing (`LeftHUDRegion` `Rect2(0, 0, 112, 360)`, `world_visible_rect` `Rect2(112, 0, 528, 360)`, `GameRoot/World.position = Vector2(144, 36)` without modifying `restaurant_world.tscn` or adding `Camera2D`), wired `UI.bind_context()` in `GameRoot._wire_controllers()` with signal deduplication, implemented single `_unhandled_input` world click router (prioritizing child/fixture `Area2D` targets over floor `WorldMap.global_to_cell()`) and `_unhandled_key_input` keyboard router (`SERVING`-only, case-insensitive Unicode + keycode extraction ignoring `Space`/`Enter`/`Tab`/`Delete`/echo, `Escape` prefix clear, `Backspace` single-character delete, target-switch prefix reset, live typing preview with highlighted `[prefix]` and `Ketik berikutnya: ...` for both single and ambiguous multi-command prefixes, and blocking when `LineEdit`/modal/visible `BaseButton` has focus while preserving `FOCUS_ALL` button keyboard accessibility). Explicitly deferred: (1) Milestone 2–4 world rings, menu selection UI, storage `Belanja` UI, and fixture purchase/sale confirmation dialogs; (2) dynamic stock/eligibility filtering and purchased-fixture ID resolution in `KitchenController.get_allowed_commands_for_selected_target()` (currently returns static per-station command entries pending Milestone 1 retrieval/prep gameplay and Milestone 3 dynamic fixture support); (3) the 2 px fixture hitbox inset (`28x28` collision shape inside a `32x32` cell) and outer world margin floor-click nearest-walkable fallback behavior.
Next concrete task: Complete Milestone 1 — implement kitchen food item retrieval from storage, held aggregate & plate pickup, rice washing/cooking, stove frying, vegetable chopping, work-table staging/merging, and exact `nasi_telor` recipe matching.
```

### Phase 1 Art Asset Integration — Environment, Characters, and Ingredients (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-531d1c7
Milestone completed/current: Phase 1 Art Asset Integration completed & validated (Milestone 1 kitchen gameplay remains current next task)
Files added/modified: added assets/art/**/*.import (21 imported PNG textures); modified project.godot, scenes/player/player.tscn, scenes/world/restaurant_world.tscn, scripts/world/world_map.gd, scripts/ui/game_ui.gd, scripts/kitchen/ingredient_def.gd, data/ingredients/{ayam,beras,sayur,telur,tempe}.tres, tests/test_world_hierarchy.gd, tests/test_track_a3.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Tests ACTUALLY run and results: `godot --headless --path . --import` (all 21 PNG assets imported); `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (64/64 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (106/106 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (88/88 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (123/123 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (68/68 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (101/101 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); formatting, UID, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: `chicken meat.png` and `cow meat.png` do not exist on disk (while `raw cow.png` and `cooked meat.png` exist on disk; `sapi.tres` left unmapped pending coordinator confirmation of meat asset filenames/states); separate raw/washed rice sprites and chopped/cooked vegetable sprites do not exist (`rice.png` and `veggies.png` mapped to their clear states/icons); recipe dish icons (`nasi_telor`, `nasi_ayam`, `nasi_komplit`, and Days 4–7 recipes) and UI panel/ring art remain pending.
Divergence from architecture (requires coordinator approval if gameplay): none; preserved all 12 canonical `World` containers, all 24 `WorldRegistry` IDs, `WorkTable` split `Area2D` targets, `CollisionShape2D` hitboxes, Candidate B `World` offset `(144, 36)`, and single-state-owner boundaries.
Next concrete task: Complete Milestone 1 — implement kitchen food item retrieval from storage, held aggregate & plate pickup, rice washing/cooking, stove frying, vegetable chopping, work-table staging/merging, and exact `nasi_telor` recipe matching.
```

### Milestone 1 — Kitchen Gameplay & First Dish Assembly (`nasi_telor`) (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-531d1c7
Milestone completed/current: Milestone 1 COMPLETE — Kitchen Gameplay Loop & Visual Synchronization validated
Files added/modified: modified scripts/kitchen/kitchen_controller.gd, scripts/player/player_visual.gd, scenes/player/player.tscn, scripts/world/world_map.gd, scripts/ui/game_ui.gd, tests/test_game_ui_m1.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented gameplay & commands:
- Storage (`storage_box` / `fridge`): `ayam`/`beras`/`sapi`/`sayur`/`telur`/`tempe` retrieves 1 RAW item into empty hand, decrementing matching slot once (`out_of_stock` / `hand_full` on rejection).
- Washer (`washer`): `cuci` transitions held RAW `beras` -> `WASHED`, or washes 1 dirty plate from `_washer_dirty_plates` into empty hand.
- Rice Cooker (`rice_cooker`): `masak` moves held `WASHED` `beras` -> `COOKED_RICE` into single cooker output (`cooker_full` if occupied); `nasi` retrieves cooked rice into empty hand.
- Stove (`stove`): `goreng` applies `IngredientDef.get_next_state(..., &"goreng")` (`telur`/`ayam`/`tempe`/`sapi` `RAW -> COOKED`, `sayur` `RAW -> COOKED` / `CHOPPED -> CHOPPED_AND_COOKED`).
- Chopping Hotspot (`work_table_chop`): `potong` transitions held RAW `sayur` -> `CHOPPED` without staging.
- Plate Rack (`plate_rack`): click in `SERVING` takes 1 clean plate (`location = &"HELD"`) with empty hand or returns held empty plate (`no_plates` when 0 remain).
- Work Table Staging (`work_table_stage`): click in `SERVING` stages held item, picks up staged item into empty hand, or merges a single loose prepared item onto a staged plated aggregate when compatible with loaded `RecipeDef` multisets (`nasi_telor` completes in any component order; invalid/raw/loose-loose merges reject without resource loss).
- Trash (`trash`): click in `SERVING` discards loose held item or clears plated food parts while preserving the exact reusable `plate_id`.
- Visual Sync: `Player/VisualAnchor/HeldItemVisual`, `WorkTable/StagedVisual`, `RiceCooker/CookerOutputVisual`, `PlateRack/PlateCountLabel`, and `Washer` filled/empty region sync via `kitchen_state_changed` / `run_state_changed`.
Tests ACTUALLY run and results: `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (105/105 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (106/106 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (88/88 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (123/123 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (68/68 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (101/101 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); coding standards, `.uid`, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: `sapi.tres` unconfirmed meat texture (gameplay unaffected; fallback indicator used); separate plate/dish icons and `Belanja` planning UI remain deferred to M2–M4.
Divergence from architecture (requires coordinator approval if gameplay): none; `KitchenController` remains sole owner of held/staged/cooker/plate/storage state, `GameUI` uses read-only views only, and `WorldMap` stays passive visual presentation.
Next concrete task: Milestone 2 — Dine-in full customer transaction (`ServiceController` spawn schedule, outside FIFO, table seating, `try_serve_table` + `KitchenController.try_consume_serving_item`, 20s eating, `bersihkan`, and `RunController.credit_order_once`).
```

### Milestone 2 — Dine-in Customer Gameplay (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-531d1c7
Milestone completed/current: Milestone 2 COMPLETE — Dine-in Customer Gameplay & Visual Synchronization validated
Files added/modified: added tests/test_service_m2.gd (+ .uid); modified scripts/core/game_root.gd, scripts/kitchen/kitchen_controller.gd, scripts/service/service_controller.gd, scripts/world/world_map.gd, scripts/ui/game_ui.gd, tests/test_controllers_m0.gd, tests/test_game_ui_m1.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented gameplay & API:
- `GameRoot._wire_controllers()`: wired `KitchenController.bind_service(...)` and `ServiceController.bind_systems(...)`.
- `ServiceController`: added `bind_systems`, `set_rng_seed`, `get_customer_views()`, `t = 0.0` + `20.0s` scheduled catch-up spawning, `1.0 / float(dine_in_price)` weighted recipe selection, lowest-ID `CLEAN_VACANT` table seating vs `outside_dine_in_queue` FIFO, `100.0s` patience deadlines preserving exact arrival schedule across outside->inside promotion, `20.0s` eating -> `DIRTY` transition, atomic `try_serve_table` (timeout wins at `now >= deadline_at`, calls `KitchenController.try_consume_serving_item` and `RunController.credit_order_once` with `push_error` invariant guard), and `try_clean_table` (`KitchenController.move_cleaned_table_plate_to_washer` + immediate non-expired FIFO admission).
- `KitchenController`: implemented plated `try_consume_serving_item` (moving `DINE_IN` plate to `CUSTOMER_TABLE`), `clear_non_fridge_food_for_next_day()` plate `table_id` reset, and `saji`/`bersihkan` table command dispatch with accurate `order_expired` timeout feedback.
- `WorldMap` & `GameUI`: added passive `sync_dine_in_visuals()` (`npc 1.png`–`npc 7.png`, `MOUSE_FILTER_IGNORE` recipe/countdown badge and shrinking timer fill at `dine_in_wait_01..04` / `DiningTable01..02`, plus `TableDirtyVisual` / `TablePlateVisual`) and `order_served`/`order_expired`/`table_cleaned`/table status UI updates.
Tests ACTUALLY run and results: `godot --headless --path . -s res://tests/test_service_m2.gd` — PASS (41/41 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (105/105 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (106/106 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (88/88 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (123/123 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (68/68 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (101/101 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); Godot `ResourceUID` validation (`uid://dm2srv9k4p7q2` -> `EXISTING_VALID=true`), coding standards, `.uid`, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: `sapi.tres` meat texture ambiguity and Days 4–7 content remain unchanged; GoFood drivers (M3) and Belanja/shop upgrades (M4) remain out of scope for M2.
Divergence from architecture (requires coordinator approval if gameplay): none; additive `ServiceController.bind_systems`, `set_rng_seed`, `get_customer_views`, and `KitchenController.bind_service` respect all single-owner and passive-view contracts.
Next concrete task: Milestone 3 — Online offer preview (`terima`), online order deadlines, physical driver spawning at `pickup_spot_01..03`, overflow FIFO, and driver serving.
```

### Milestone 3.1 — Online Delivery Lifecycle (`ServiceController`) (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-M2
Milestone completed/current: M3.1 COMPLETE — ServiceController Online Delivery Lifecycle validated (M3.2 Kitchen/WorldMap/GameUI integration pending)
Files added/modified: added tests/test_service_m3.gd (+ .uid); modified scripts/service/service_controller.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented gameplay & API:
- Weighted inverse-price online offer preview initialization (`prepare_service_day`) and rotation on acceptance (`try_accept_online_offer`), kept intact past `_day_queue_remaining <= 2` cutoff and `day_queue_initial` concurrent OPEN cap without decrementing dine-in quota.
- Pickup spot allocation (`pickup_spot_01` -> `02` -> `03`) and `_outside_driver_queue` FIFO promotion without resetting original 60.0s deadlines, skipping/removing any already-expired overflow entries.
- `try_serve_driver(driver_id, item_id)` with exact `now >= deadline_at` tie-break, `KitchenController.try_consume_serving_item(..., OrderKind.ONLINE, &"")` (clean plate return to `&"RACK"`), once-only 70% payout via `RunController.credit_order_once` with `push_error` invariant guard, and idempotent 60.0s online expiry integrated into `_tick_service_spawns_and_timers` and `is_drained()`.
- Read-only `has_driver()`, `get_driver_view()`, deterministic sorted `get_driver_views()` (`queue_index`, `serveable`, `seconds_remaining`), and `reset_dirt_and_day_customers()` online cleanup.
Tests ACTUALLY run and results: `godot --headless --path . -s res://tests/test_service_m3.gd` — PASS (51/51 checks after M3.1.1 hardening covering immediate quota-3 cutoff, lowest free spot 01 vs 03, multi-overflow `queue_index` re-indexing, cross-recipe delivery on Day 2, public-clock 60.0s boundary, live dine-in lifecycle drain, full Day 1->2 transition, and invariant error guard, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_service_m2.gd` — PASS (41/41 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (105/105 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (106/106 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (88/88 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (123/123 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (68/68 checks, `SUMMARY fails=0`, zero leaks); `scratch/test_world_a2.gd` — PASS (101/101 checks, `SUMMARY fails=0`, zero leaks); `godot --headless --path . --quit-after 2` — PASS (exit 0); Godot `ResourceUID` validation (`uid://3u0u5mnto3wv`), coding standards, `.uid`, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: none for M3.1 (`npc gojek.png` already bound on `WorldMap` from Phase 1).
Divergence from architecture (requires coordinator approval if gameplay): none; additive `has_driver()` and `get_driver_view()` read helpers cleanly support M3.2 dispatch while preserving single-state ownership.
Next concrete task: M3.2 — Wire `terima`/`saji` driver dispatch in `KitchenController`, driver/offer overlays in `WorldMap`, and feedback/presentation in `GameUI`.
```

### Milestone 3.2 — KitchenController Online Delivery Integration (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-M3.1
Milestone completed/current: M3.2 COMPLETE — KitchenController `terima`/`saji` Online Dispatch & Stale Driver Selection Lifecycle validated (M3.3 WorldMap/GameUI integration pending)
Files added/modified: modified scripts/kitchen/kitchen_controller.gd, tests/test_service_m3.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented gameplay & API:
- `KitchenController.bind_service()`: idempotently connects/disconnects `ServiceController.drivers_changed` to clear stale `_selected_target_id` and `_accepted_prefix` only when the selected driver disappears (preserving unrelated selections and active drivers whose view refreshes).
- `online_station` `terima`: validates `SERVING` phase, `online_station` target, valid `ServiceController`, and live `acceptance_enabled` / preview recipe before invoking `try_accept_online_offer()` once (`&"online_accepted"` vs `&"invalid_action"`).
- Selected driver `saji`: exposes `["saji"]` in `get_allowed_commands_for_selected_target()` for registered drivers, pre-validates spot + `serveable` state, delegates to `ServiceController.try_serve_driver(driver_id, held_item_id)`, and shares `_emit_failed_serve_feedback()` with dining-table `saji` (`&"order_expired"` vs `&"wrong_order"` vs `&"invalid_action"`).
Tests ACTUALLY run and results: `godot --headless --path . -s res://tests/test_service_m3.gd` — PASS (65/65 checks including M3.1 + M3.2 online `terima`/`saji`/driver-selection tests, `SUMMARY fails=0`, zero leaks); `godot --headless --path . -s res://tests/test_service_m2.gd` — PASS (41/41 checks); `godot --headless --path . -s res://tests/test_game_ui_m1.gd` — PASS (105/105 checks); `godot --headless --path . -s res://tests/test_controllers_m0.gd` — PASS (106/106 checks); `godot --headless --path . -s res://tests/test_game_root.gd` — PASS (88/88 checks); `godot --headless --path . -s res://tests/test_world_hierarchy.gd` — PASS (123/123 checks); `godot --headless --path . -s res://tests/test_track_a3.gd` — PASS (68/68 checks); `scratch/test_world_a2.gd` — PASS (101/101 checks); `godot --headless --path . --quit-after 2` — PASS (exit 0); `.uid`, coding standards, ObjectDB/resource leaks, and `git diff --check` — PASS (`Issues: 0`).
Blocked by art/content (recipe/icon/map IDs)/TUNING: none.
Divergence from architecture (requires coordinator approval if gameplay): none.
Next concrete task: M3.3 — WorldMap passive online offer & 60s driver overlays and GameUI online presentation & localized feedback (`online_accepted`, cutoff/overflow feedback).
```

### Milestone 3.3 — WorldMap & GameUI Online Delivery Presentation (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-M3.2
Milestone completed/current: M3.3 COMPLETE — WorldMap OnlineStation/Driver Presentation, Clickable Overflow Feedback, and GameUI Localized Dialogue validated
Files added/modified: modified scripts/world/world_map.gd, scripts/kitchen/kitchen_controller.gd, scripts/ui/game_ui.gd, scenes/ui/game_ui.tscn, tests/test_service_m3.gd, docs/PROGRESS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented presentation & interaction:
- `WorldMap.sync_online_station_visual()`: renders `OnlinePreviewVisual` plated recipe preview + recipe label on `OnlineStation` from read-only `get_online_offer_view()`, keeping preview visible and dimmed (`modulate`) after cutoff or concurrent cap.
- `WorldMap.sync_driver_visuals()`: reuses single `Area2D` nodes per `driver_id` across frames and overflow -> pickup spot promotions (zero duplicate nodes), renders recipe + `seconds_remaining` badge + shrinking timer bar, distinguishes in-spot (`Color.WHITE`) vs overflow (`"Antre ..."` dimmed tint), and exposes `hit_test_overflow_driver()` without registering overflow drivers in `WorldRegistry`.
- `KitchenController`: restricted `_is_driver_target()` to `AT_PICKUP_SPOT` drivers while tracking `_has_driver_target()` for stale cleanup on `drivers_changed`, and added `on_overflow_driver_clicked()` (selects overflow target without moving player, exposes `[]`, emits `&"driver_not_at_pickup"`).
- `GameUI` & `scenes/ui/game_ui.tscn`: wired idempotent `ServiceController.online_offer_changed` and per-frame `_refresh_driver_visuals()`/`_refresh_dialogue()`, added `TargetStatusLabel` for `OnlineStation` preview/disabled reason and in-spot/overflow driver status, anchored dialogue to `get_driver_visual_node()`, and localized `&"online_accepted"` / `&"driver_not_at_pickup"`.
Tests ACTUALLY run and results: `godot --headless --path . -s res://tests/test_service_m3.gd` — PASS (85/85 checks including M3.1 + M3.2 + M3.3 `OnlineStation` preview/cutoff/rotation, in-spot/overflow driver countdowns, overflow click feedback, in-place promotion, expiry cleanup, and `GameUI` dialogue/feedback, `SUMMARY fails=0`, zero leaks); `tests/test_service_m2.gd` (41/41), `tests/test_game_ui_m1.gd` (105/105), `tests/test_controllers_m0.gd` (106/106), `tests/test_game_root.gd` (88/88), `tests/test_world_hierarchy.gd` (123/123), `tests/test_track_a3.gd` (68/68), `scratch/test_world_a2.gd` (101/101), `--quit-after 2` (exit 0), `.uid`, coding standards, and `git diff --check` — PASS.
Blocked by art/content (recipe/icon/map IDs)/TUNING: none.
Divergence from architecture (requires coordinator approval if gameplay): none.
Next concrete task: Milestone 4 — Selected storage purchases (`Belanja`), placement-slot fixture purchases/resale, and economy UI.
```

### Milestone 3 Acceptance Test Hardening (2026-11-17)

```
Date / Git commit: 2026-11-17 / post-M3.3
Milestone completed/current: M3 Acceptance Test Hardening COMPLETE — No-pause modal clock, final online expiry auto-close, and typed `saji` edge cases validated
Files added/modified: modified tests/test_service_m3.gd, docs/PROGRESS.md (no production scripts or scenes modified)
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Added acceptance tests:
- `_test_no_pause_modal_overlay_service_clock()`: activates a visible modal overlay (`ui.set_modal_blocking(true)`) during `SERVING`, verifies world clicks & keyboard input remain blocked, and confirms `service_elapsed`, online order deadline (`60s` expiry), driver countdown visual (`Nasi Telor 35s`), and dine-in deadline (`100s` expiry) continue ticking normally.
- `_test_auto_close_after_final_online_order_expires()`: clears all 4 diners while leaving 1 OPEN online order (`online_deadline_seconds = 95.0` on duplicated `EconomyConfig` so the pre-cutoff order outlives 80s dine-in completion), confirms `is_drained() == false` at `113.9s`, and verifies exact `114.0s` expiry triggers a single `CLOSING -> RESULTS` auto-close (`failed_online_count = 1`, `completed_online_count = 0`).
- `_test_typed_online_command_edge_cases()`: verifies UI-typed `saji` on `online_station` is rejected (`invalid_key`) with zero state/cash/stock mutation and empty-hand typed `saji` on an in-spot driver rejects (`invalid_action`) while keeping the order `OPEN` and driver in spot.
Tests ACTUALLY run and results (exact Godot exit code 0 per suite): `tests/test_service_m3.gd` (98/98, exit 0), `tests/test_service_m2.gd` (41/41, exit 0), `tests/test_game_ui_m1.gd` (105/105, exit 0), `tests/test_controllers_m0.gd` (106/106, exit 0), `tests/test_game_root.gd` (88/88, exit 0), `tests/test_world_hierarchy.gd` (123/123, exit 0), `tests/test_track_a3.gd` (68/68, exit 0), `scratch/test_world_a2.gd` (101/101, exit 0); `--quit-after 2` (exit 0), `.uid`, coding standards, zero leaks, and `git diff --check` (exit 0) — PASS.
Blocked by art/content (recipe/icon/map IDs)/TUNING: standalone dish icon art and Milestone 4 shopping UI remain deferred to M4/M6.
Divergence from architecture (requires coordinator approval if gameplay): none.
Next concrete task: Milestone 4 — Selected storage purchases (`Belanja`), placement-slot fixture purchases/resale, and economy UI.
```

### Milestone 4-A — Planning HUD, Edit Menu Popup, and Typed `buka` (2026-11-17)

```
Date / Git commit: 2026-11-17 / local working tree on top of `main` @ `fecb2cc`
Milestone completed/current: M4-A COMPLETE — Planning HUD Strip, Edit Menu Modal Popup, and Typed `buka` Start Flow validated
Files added/modified: added tests/test_planning_m4a.gd (+ .uid); modified scripts/kitchen/kitchen_controller.gd, scripts/ui/game_ui.gd, scenes/ui/game_ui.tscn, tests/test_game_ui_m1.gd, tests/test_service_m2.gd, docs/PROGRESS.md, docs/PROJECT_STATUS.md
Godot version / platform: Godot 4.7.2.stable.official.ed1daf0bf / Windows
Implemented gameplay & UI:
- Planning HUD (`scenes/ui/game_ui.tscn`, `scripts/ui/game_ui.gd`): displays `persiapan sebelum buka`, `Hari X/7`, live cash, Day 7 target percentage (`Target Hari 7: %d%%`) + bar from `RunController.get_run_view()`, `EditMenuButton`, `Target Tamu` forecast, `Ketik: buka` hint, and non-navigating `Menu`/`Exit` stub buttons preserving `MOUSE_FILTER_STOP` and `FOCUS_ALL`; retired `StartServiceButton` (`Mulai Layanan`) while preserving existing `ServiceBox` and `DayResultSidePanel` untouched.
- Edit Menu Popup (`scenes/ui/game_ui.tscn`, `scripts/ui/game_ui.gd`): rectangular modal overlay centered in `world_visible_rect` over a map dimmer using Control fallback styles and existing ingredient/part textures; renders `unlocked_recipe_ids` from `RunController.get_run_view()`, highlights active selection, stores only temporary UI toggles until confirmation, calls `RunController.select_daily_menu()` with double-submit guard, rejects empty/duplicate/locked selections with localized error text without altering active menu, blocks world clicks and gameplay typing via `is_modal_blocking()`, and releases focus on close so `buka` typing resumes seamlessly.
- Typed `buka` (`scripts/kitchen/kitchen_controller.gd`, `scripts/ui/game_ui.gd`): extended prefix parser (`accept_typed_character`, `backspace_command_prefix`, `clear_command_prefix`, `get_allowed_commands_for_selected_target`) to accept `buka` strictly during `PLANNING` when `_selected_target_id == &""`, executing `GameRoot.start_service_requested()` once without Enter and emitting `&"start_service_failed"` on rejected `finalize_plan()`; preserved rejection of station typing in `PLANNING` and existing `SERVING` commands, and cleared command prefix cleanly on `GameRoot.phase_changed`.
Tests ACTUALLY run and results (exact Godot exit code 0 per suite): `tests/test_planning_m4a.gd` (26/26, exit 0), `tests/test_service_m3.gd` (98/98, exit 0), `tests/test_service_m2.gd` (41/41, exit 0), `tests/test_game_ui_m1.gd` (106/106, exit 0), `tests/test_controllers_m0.gd` (106/106, exit 0), `tests/test_game_root.gd` (88/88, exit 0), `tests/test_world_hierarchy.gd` (123/123, exit 0), `tests/test_track_a3.gd` (68/68, exit 0); `--quit-after 2` (exit 0), `.uid`, coding standards, zero leaks, and `git diff --check` (exit 0) — PASS. Historical `scratch/test_world_a2.gd` is not present in this workspace and was not run.
Blocked by art/content (recipe/icon/map IDs)/TUNING: UI PNG pack (`10` illustrations + `3` reusable UI assets), custom font file, Days 4–7 recipes, and Audio specs/files remain unavailable on disk (Control fallback visuals used).
Divergence from architecture (requires coordinator approval if gameplay): retired legacy `StartServiceButton` in favor of typed `buka` per UI MVP handoff; updated direct `StartServiceButton` UI/M2 test calls accordingly.
Next concrete task: M4-B — Fix ingredient delivery/refund ledger bugs and implement selected storage ingredient shopping popup (`Belanja Bahan`).
```
