# Ketik Saji — instructions for Claude Code

Godot 4.7.2 **2D**, **GDScript**, Windows/Linux mouse+keyboard, Indonesian player-facing text. Jam theme **“Less is More, More is Worse”**. **One developer owns the entire codebase** using Claude Code as the implementation tool (previous multi-programmer approval splits are obsolete; any subagents must follow the same contracts). This is a **72-hour jam**; finish a working game before adding polish. Art/UI assets come from teammates; use stable-ID placeholders until they arrive.

## Authoritative documents and precedence

1. Latest explicit coordinator decisions (override only the specific rules they update; unrelated confirmed rules stay in force).
2. `docs/SHARED_BASELINE.md` — confirmed gameplay rules and constraints.
3. `docs/ARCHITECTURE.md` — canonical interfaces and single-state-owner contracts.
4. `docs/systems/01_INTERACTION_KITCHEN.md`, `02_SERVICE_ORDERS_CUSTOMERS.md`, `03_PLANNING_ECONOMY_PROGRESSION.md`, `04_UI_FEEDBACK_LOCALIZATION.md` (plus `docs/WORLD_LAYOUT_AND_VIEWPORT.md` for screen composition).
5. `docs/IMPLEMENTATION_PLAN.md` and `docs/ACCEPTANCE_TESTS.md` — milestones and test gates.
6. `docs/CONTENT_AND_TUNING.md` and `docs/DECISION_REGISTER.md` — content intake, tuning knobs, and reversible/proposed defaults.
7. `docs/PROGRESS.md` — implementation status; never a substitute for inspecting actual files.

**Do not automatically import all documents into this file.** At each milestone, read `docs/ARCHITECTURE.md`, relevant system doc(s), the milestone section, and existing affected code. Ignore superseded Agent A–E originals.

## Coordinator-integrated implementation rules

- **Milestone & scope discipline:** Implement **one named milestone at a time**, validate, and update `docs/PROGRESS.md`. Preserve working A1/A2/A3 implementations and tests unless fixing a concrete contract conflict. Never change confirmed gameplay rules unilaterally, fabricate Day 4–7 recipes, or treat **PROPOSED** defaults (`Rp0` starter resale, trash keeping clean plate, `TUNING` prices/targets) as confirmed design rules. Escalate only genuine cross-system contract conflicts, gameplay changes, or visual/economic choices needing coordinator input.
- **Single state authority & no extra managers:** No autoload service locators, ECS, factory frameworks, extra global timers, saves, workers, or utility upgrades.
  - `GameRoot`: owns `phase` and **one** monotonic `service_elapsed` clock (`advance_service_time(now)`), plus one idempotent close trigger polling `ServiceController.is_drained()` after clock updates.
  - `KitchenController`: sole owner of `player_tile: Vector2i`, `selected_target_id`, `accepted_prefix`, single world-click routing (`on_floor_clicked`, `on_interactable_clicked`), held aggregate, work-table staging, storage slots, finite plates, washer queue, and deliveries. Movement is an **internal helper** only (no second authoritative controller/tile/prefix).
  - `ServiceController`: owns dine-in quota/queues/tables, timers, online offer/orders, drivers, and 3 pickup spots + overflow FIFO.
  - `RunController`: owns cash, menu/unlocks, fixture ownership (`starter_grant` / `actual_amount_paid`, bound without duplicating scene starter nodes), purchases/refunds, demand debt, and Day 7 target.
  - `GameUI`: presentation and modal focus only.
- **World spatial layer & teleport:** `WorldMap` / `WorldGrid` / `WorldRegistry` supply passive spatial data (transforms, walkability, occupancy, footprints, cardinal neighbors), never gameplay state or input routing. `WorldGrid.occupy()` stays walkability-agnostic so valid non-walkable/perimeter objects can claim cells; teleportation always requires `is_free()` (`walkable and not occupied`). Interactable clicks pick nearest walkable cardinal neighbor across the **entire footprint** using shortest Manhattan distance + fixed cardinal tie-break order, and activate in the **same click**; invalid validation mutates nothing. No pathfinding.
- **World scene & IDs:** Align incrementally to `docs/ARCHITECTURE.md` §1 (`Decorations` permitted as a passive visual-only container; `Player` stays visual-only with `VisualAnchor` available for held-item UI). Use stable unique `StringName` IDs, tile-unit footprints, map-authored `PlacementSlots` restricting `FixtureKind`, `OnlineStation` (`terima`), split work-table staging vs. chopping (`potong`) targets, and 3 online pickup spots + separate overflow; every interactable needs >=1 `is_free()` cardinal neighbor.
- **A3 Resource schemas (`.tres` read-only at runtime):**
  - `IngredientDef` (`ingredient_id`, display name, prep transitions; no pricing).
  - `RecipeDef` (`recipe_id`, display name, `icon_key`, `required_parts`; **no pricing or `unlock_day`**).
  - `RecipeEconomyEntry` inside `EconomyConfig` (`recipe_id`, `unlock_day`, `dine_in_price`; references `RecipeDef` by ID).
  - `UtilityDef` (`utility_id`, `FixtureKind`, `footprint: Vector2i` default `1×1`, purchase price, daily electricity, rack capacity; slot permissions stay on map `PlacementSlots`).
  - `EconomyConfig` holds `TUNING` values; never hardcode balance numbers in controllers. Future recipes must work purely as `.tres` + icon additions.
- **Screen composition & input isolation:** Single 2D viewport: persistent left UI (`LeftHUDRegion`) → `12×9` (`32×32` px) restaurant world on the right (M5-A: interior cols `0..7` with non-walkable pickup spots `(7,5)..(7,7)`, col `8` wall/doorway, col `9` dine-in waiting queue with `4` anchors, cols `10..11` road/driver overflow; evaluate `World` offset and HUD width together). `640×360` / `1280×720` remains the primary viewport target alongside `480×270` responsive fit checks. GUI (`LeftHUDRegion`, modals) must block world clicks/teleport; focused UI fields (including `Belanja` quantity) must not leak keys to Kitchen. Shopping **never pauses clocks**.
- **Typing, online & day close:** Single B Indonesian prefix parser (exact valid prefix extends, invalid shakes, full word auto-executes without Enter, click elsewhere clears prefix). Online station accepts `terima`; `saji` only serves **in-spot** drivers; cutoff at unspawned quota `<= 2`; concurrent `OPEN` cap = `day_queue_initial`. Auto-close occurs only when unspawned quota = 0, outside dine-in queue empty, inside diners = 0, AND `OPEN` online orders = 0. All cash, order, plate, delivery, and refund commits validate first and are **once-only by ID**.

## Work session protocol

1. Inspect `docs/PROGRESS.md`, `docs/CODING_STANDARDS.md`, actual scene/script files, and milestone acceptance tests.
2. State a concise file-level plan; keep contracts matching `docs/ARCHITECTURE.md` and `docs/CODING_STANDARDS.md` (tabs, UTF-8 without BOM, LF, `<100` cols, keep `.uid` files).
3. Test with Godot CLI (`godot --headless --path . --import` and headless/interactive tests) and record actual outcomes in `docs/PROGRESS.md`. Never claim an unrun test passed.
4. Keep changes minimal, preserve existing working code/tests, and use fresh sessions between milestones as context grows.

**Current focus:** Tracks A1–A3, GameRoot foundation, and World Hierarchy Migration are implemented and validated. Complete the remaining Milestone 0 deliverables: controller skeletons, GameRoot controller binding, and GameUI left-band fit test before Milestone 1.
