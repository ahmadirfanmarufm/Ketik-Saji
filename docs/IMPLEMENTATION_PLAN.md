# 72-hour Godot 4 implementation plan (developer + Claude Code)

**Rule:** One named milestone at a time, working playable build first. Claude Code reads `CLAUDE.md` and `docs/ARCHITECTURE.md` for EVERY milestone, then the one/two relevant domain docs, and inspects existing code before editing. Do not treat all ~72 hours as available for new features: reserve meaningful time for art swap, playtests, UI correctness, balancing, fixing bugs and export. The timeline groupings are planning guides, not deadlines to skip tests.

## Order of implementation (dependency-aware)

### Milestone 0 — Project skeleton and world/phase contract (first vertical foundation)

**Implement:** Start with `docs/WORLD_LAYOUT_AND_VIEWPORT.md` and `references/current_screen_layout_NON_BINDING.png`. Establish a placeholder **left UI band**, adjacent **visible dine-in waiting lane**, and restaurant world to the right; do not freeze old 10×9 dimensions or positions. Check the proposed 640×360 canvas against the actual visible regions before authoring detailed hitboxes. Then create `project.godot`, `GameRoot` persistent scene, `World` placeholders and authored 32px tile/grid, fixed starter fixture IDs (1 box/kompor/wastafel/rack/cooker, 2 dining tables, prep table/trash), 3 C pickup markers and one online accept station, three controllers and UI placeholder, root phase enum / `service_elapsed` with service-only tick. Static `.tres` schema classes and three existing recipe definitions (not future fictional recipes), `EconomyConfig` prototype test values. Draw visible player tile and station hitboxes; build small test scene. Connect UI Start Service → D validation → C begins at `t=0` but client can stub no orders initially.

**Acceptance gate:** Godot opens/imports without parse errors; left HUD safe region and separate waiting/world zone are visibly blocked out; no world teleport from clicking the left region; 3 authored driver pickup placeholders and separate outside queue have visible room; GameRoot boots PLANNING with confirmed starter kit, no duplicate state; Start Service switches phase only once, clock advances only SERVING; service GUI test button not accidentally available as Close Day. Draw colored placeholder sprites instead of art. Commit.

### Milestone 1 — Mouse/keyboard interaction and ONE exact plated dish

**Read:** B + E input. Implement single world click router: floor teleport only, selected object remote cardinal-adjacent teleport plus select same click, GUI mouse_filter; B `accepted_prefix` FSM and B→E above-target ghost prompt. One raw ingredient storage retrieval from selected unit, one held aggregate, one work staging table, rack with finite plate IDs, washer `cuci` rice, cooker `masak`+`nasi`, stove `goreng`, plate merge, exact recipe match (`nasi_telor`). Use mock order ID in test if C not fully wired. Add chopping hotspot with held `sayur` before `nasi_komplit` implementation (same physical table but distinct target). No employee/cook timers.

**Acceptance:** Click floor doesn't use station; object click selects at distance; `ayam`/`cuci` etc accept exact-prefix and ignore bad keys; full word autoexecute without Enter. Assemble an exact plated `nasi_telor` in any component order; keep a partially assembled plate while switching targets; no second hand item/plate creation. Headless parse and manual keyboard test. Commit.

### Milestone 2 — Dine-in full customer transaction

**Read:** C + B and A cross-contract. Implement C t=0 then 20s spawns, `day_queue_remaining` separate from outside dine-in FIFO, 100s timer from spawn even outdoors, clean seating with one per table, `try_serve_table`, 20s eating, dirty table, `bersihkan`→B washer, one dirty plate `cuci`, C `ServiceDayReport`, D `credit_order_once` minimal income. Add one unserved failure and auto-close four-way predicate (online currently zero). Display dish icons and rings via E read-only views. After auto-close test B resets/retains correct stock, D charges fixed starter cooker electricity once.

**Acceptance:** Whole transaction from planning/ingredient/typing to serving/payment/diner departure/cleaning/washer/day results, no duplicated plate/cash; waiting customer patience continues outside; one miss doesn't immediately end run; no premature shop close between arrivals. Commit.

### Milestone 3 — Online accepted orders and **physical** drivers

**Read:** C + E + B. Add stable preview icon on online station, typed `terima`, unique online order + 60s absolute deadline, 3 authored physical pickup spots, outside driver FIFO, visible driver sprites with order rings and Area2D click IDs, typed `saji` on the **in-spot driver only**. Simultaneous OPEN cap = initial day quota; new acceptance disabled at unspawned <=2. Successful online payout lower, exact food consumed, original plate returns instantly clean (no washer). Add no-pause shopping overlay test even if money UI is minimal.

**Acceptance:** Four open online orders with day quota >=4 produce 3 at spots+1 outside; outside can't be served, timer still runs, advances into free spot with remaining time. Last diner leaves with OPEN online order → service stays open until online terminal; then close. Station only accepts orders and doesn't serve. Commit.

### Milestone 4 — Planning, buying, selling, storage, demand and shipments

**Read:** D + B + E. Implement D authoritative cash and paid ledger (source of truth); menu choose unlocked IDs; forecast first-day base + confirmed +4/day + configurable menu bonus - accumulated debt; purchasing from **chosen specific** box/fridge including per-slot duplicate ingredient support and reservations; instant planning stock vs 100s serving shipment; cancellation/refund only pending on auto-close. Plan-only **immediate** fixture install/safe resale including tables, starting kit 0 paid resale default; finite plate rack count/fixture slot compatibility; daily fridge and rice cooker fixed fees. Create UI slot-first equipment and owned fixture sale with confirmation; storage `Belanja` same panel both phases, **no pause** in service.

**Acceptance:** A full chosen container fills and rejects overflow with no debit/spill, even if other container empty. Same raw item can use multiple slots. 100s shipment ready/close boundary behaves once; only pending refunded. Bought/sold fixture appears/disappears immediately in planning and not during service. +4/day demand and 50/50 failure debt/perfect recovery. Commit.

### Milestone 5-A — World Layout & Customer Seating (`M5-A1` & `M5-A2`)

**Read:** `docs/WORLD_LAYOUT_AND_VIEWPORT.md` (v2.2), `docs/DECISION_REGISTER.md` (`VIS-01`–`VIS-04`), `docs/ARCHITECTURE.md` §1–§2 & §7, and `docs/ACCEPTANCE_TESTS.md` (`E06`–`E06d`). Execute **M5-A1** and **M5-A2** as two controlled parts with **separate implementation and verification checkpoints**. Do not combine both parts into an unverified single change, and do not bundle out-of-scope M4-D/M5-B or playtest-brief gameplay changes into M5-A.

#### M5-A1 — World Layout (`12×9` grid, right-side queue, `11` PlacementSlots) `[IMPLEMENTED & VERIFIED]`
- **Rebuild the world grid and walkable/blocked cells:** Update `WorldMap.grid_size` to `Vector2i(12, 9)` (`32×32` px tiles, `384×288` px world). Mark kitchen (`cols 0..7, rows 0..3`), passage `(7,4)`, dining (`cols 0..6, rows 5..8` plus `(7,8)`), and doorway (`(8,5)..(8,7)`) walkable; keep the long counter (`row 4, cols 0..5`), pickup spots (`(7,5)..(7,7)`), interior wall (`col 8, rows 0..4 & 8`), dine-in queue (`col 9`), and road (`cols 10..11`) **non-walkable**.
- **Reposition starter fixtures, anchors, online station, pickup spots, overflow, and player:**
  - Keep canonical starter IDs: `washer` `(0,0)`, `stove` `(1,0)`, `rice_cooker` `(2,0)`, `storage_box` `(3,0)`, `plate_rack` `(4,0)`, `trash` `(7,0)`, `work_table` (`work_table_stage` + `work_table_chop`) `(3,2)`, `online_station` `(6,4)`, `dining_table_01` `(2,7)`, `dining_table_02` `(4,7)`.
  - Move `pickup_spot_01..03` to `(7,5)`, `(7,6)`, `(7,7)` (non-walkable).
  - Relocate `dine_in_wait_01..04` (`4` waiting anchors) to **column 9 on the right side** and `driver_overflow` to the **right-side road (`cols 10..11`)**.
  - Move Player starting cell (`KitchenController.DEFAULT_START_TILE` and `RestaurantWorld/Player`) to **`(6,3)`**.
- **Add the new `PlacementSlots`:** Expand utility slots from `2` to **`5`** (`slot_utility_01..05` at `(5,0)`, `(6,0)`, `(2,2)`, `(4,2)`, `(5,2)`) and dining-table slots from `2` to **`6`** (`slot_table_01..06` at `(0,5)`, `(2,5)`, `(4,5)`, `(5,5)`, `(0,7)`, `(5,7)`). Update `GameUI` slot labels/list handling as needed.
- **Add passive long-counter and wall visuals:** Place the long counter (`row 4, cols 0..5`) and interior wall (`col 8, rows 0..4 & 8`) as strictly passive non-interactive visuals (not registered as work tables or staging surfaces), preserving the exact 12 top-level children of `RestaurantWorld`.
- **Update tilemap and `World` offset / HUD click boundary together:** Rebuild `FloorTiles` (`108` cells) and evaluate `GameRoot/World.position`, `GameUI.ui_safe_rect`, and `GameUI.world_visible_rect` together against `640×360` and `480×270` viewports and HUD click blocking.
- **Preserve stable fixture IDs and ownership boundaries:** Keep `WorldMap`/`WorldGrid`/`WorldRegistry` spatial-only.
- **M5-A1 Verification Checkpoint (PASSED):** Before starting M5-A2, ran headless import and all existing test suites (`test_world_hierarchy.gd`, `test_controllers_m0.gd`, `test_game_root.gd`, `test_track_a3.gd`, `test_game_ui_m1.gd`, `test_service_m2.gd`, `test_service_m3.gd`, `test_planning_m4a.gd`, `test_shop_m4b.gd`, `test_fixture_m4c.gd`) updated for the `12×9` coordinates (`913/913` assertions PASS, exit `0`, plus GUI `640×360` & `480×270`), verifying that all `31` registered scene IDs resolve and every interactable, slot, and pickup spot has `>= 1` `is_free()` cardinal neighbor even when all `11` slots are occupied.

#### M5-A2 — Customer Seating (`ChairVisual`, `SeatAnchor`, and Tabletop Placeholder) `[IMPLEMENTED & VERIFIED]`
- **Introduce a reusable dining-table scene or smallest shared construction path:** Share one definition between starter scene tables (`dining_table_01`, `dining_table_02`) and dynamically purchased tables (`WorldMap.spawn_placed_fixture()`). *(Implemented in `scenes/world/dining_table.tscn`.)*
- **Add `ChairVisual` and `SeatAnchor` on the south side:** Attach a child `ChairVisual` (`Sprite2D`, using the chair region `Rect2(416, 160, 32, 32)`) and a child `SeatAnchor` (`Marker2D`) on the **south side** of each dining table. Do **not** use the chair sprite as the dining-table tabletop sprite; use a clearly identified temporary tabletop placeholder until a dedicated dining-table sprite is confirmed.
- **Ensure dynamically purchased tables receive the same structure:** Verify `request_fixture_purchase(&"dining_table", slot_id)` in M4-C produces a table with `ChairVisual`, `SeatAnchor`, and full hitbox coverage identical to starter tables.
- **Resolve customer visual positions through `SeatAnchor`:** Update `WorldMap._resolve_customer_visual_position()` so `SEATED_WAITING` and `EATING` customers sit at their assigned table's `SeatAnchor` instead of on top of the tabletop.
- **Preserve table-based serving and cleaning interactions:** Extend/add table `CollisionShape2D` coverage over the south chair region where needed so clicking the chair/customer region selects the owning `dining_table_*` for `saji` and `bersihkan`.
- **Keep chair visuals outside `WorldRegistry` and `WorldGrid` occupancy:** Do not register chairs as gameplay targets, do not claim extra grid footprint cells, and do not introduce a seating manager or duplicate customer state (`ServiceController` remains sole owner of queue, occupancy, serving, eating, timeout, cleaning, and day reset).
- **M5-A2 Verification Checkpoint (PASSED):** All `10` headless suites (`935/935` assertions, exit `0`) plus GUI viewport checks at `640×360` and `480×270` pass, covering starter (`dining_table_01..02`) and dynamically purchased (`dining_table_03`) tables, south-side `SeatAnchor` visual alignment during `SEATED_WAITING` and `EATING`, chair region click selection, `saji`/`bersihkan`/timeout/day-reset invariance, clickable south floor cells, and zero `WorldRegistry`/`WorldGrid` pollution.

### Milestone 5 — Complete seven-day loop and recipe data pipeline

**Read:** D + A + C + B. Wire seven automatic days and RESULTS Continue, Day 7 comparison **after electricity**, WON/LOST latch and optional EXTRA mode. Author remaining of the **three confirmed recipes** (including chop vegetable for `nasi_komplit`) and verify recipe definitions driven by `.tres` not code branches. Implement validation for missing future recipe entries/icons and warnings; add supplied coordinator-authored Days 4–7 recipe definitions when they arrive, without changing serving algorithms. No fabricated content. Add comprehensive system regression tests with mock time/seed/config.

**Acceptance:** Simulate seven days quickly with test clock, compare cash at goal and one below; bad choices are allowed to fail. Extra mode only after win. New `RecipeDef.tres` + economy entry + icon lookup works without modifying B/C script. Commit.

### Milestone 6 — UI/art swap, playtest, bug fixes, export (protect final jam time)

**Read:** E + acceptance checklist; re-check B/C/D critical flows. Integrate pixel/UI art by ID, preserve click hitboxes; ensure the **approved M5-A `12×9` world composition** (left HUD / `12×9` restaurant with right-side col-9 diner queue, `(7,5)..(7,7)` driver pickup spots, and cols `10..11` road overflow) fits at the chosen 32px-based logical viewport; no old 10×9 or 13×9 left-lane assumption. E ghost typing, rings and local error feedback; side result panel and Indonesian text. Play one full run manually, tune economy `.tres` with actual human typing pace, test low/high menu/online strategies and hard-but-winnable target. Verify audio/polish only if core works. Export Windows/Linux as supported; test launch on target hardware.

**Final gate:** All `docs/ACCEPTANCE_TESTS.md` critical cases pass; no blocker, save/load or employees accidentally introduced. Final release `project.godot` boots, no missing art paths, service starts, one order can be served, online drivers work, Day7 result correct. Document any intentionally incomplete future recipes/art in release notes.

## Claude Code prompt template for each milestone

```text
Read CLAUDE.md, docs/ARCHITECTURE.md, docs/PROGRESS.md, and the current
milestone in docs/IMPLEMENTATION_PLAN.md. Then read ONLY relevant
docs/systems specifications and inspect existing implementation.

Implement Milestone [NUMBER] exactly. Keep the canonical public APIs and
single owners; do not redesign gameplay or invent future recipes.
Use placeholders for missing art. Validate first and report tests
actually run, changed files, and remaining content dependencies.
Update docs/PROGRESS.md after this milestone. Stop before next milestone.
```

## Operating rules for scope control

- Fix broken state ownership/dupe bugs before adding UI polish. Complete single service transaction before developing all economy screens. Use tiny integration test scenes; test with reduced **test-only** clock durations to avoid waiting 100 real seconds for every assertion.
- No separate autoload money/inventory manager, generic event bus, handmade pathfinding, platform abstraction, ability/upgrades/perks framework, fixture delivery system or sophisticated save persistence.
- Honor *only* known gameplay: user interaction and dynamic recipes are mandatory; if recipe art pending, show explicitly labeled placeholder, don't block core implementation. Do not claim Day4–7 content complete until supplied.
- A task is DONE only with tested evidence, code review, and updated `PROGRESS.md`; running `godot --headless --path . --import` detects many errors but does not prove playability or GUI focus.
