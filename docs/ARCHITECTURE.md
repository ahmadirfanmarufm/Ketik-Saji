# A — Architecture & Foundation — Canonical Godot 4 implementation contracts

**Revision:** integrated v2.1 (2026-11-15; latest screen-space reference). Source-derived from Agent A v1.2, reconciled with B v1.1, C v1.0, D v1.0, E v1.1, and five coordinator confirmations on 2026-11-15. Read `docs/SHARED_BASELINE.md` for design authority; this file is the **sole canonical technical contract** for Claude Code. Do not treat original agent API alternatives as competing instructions.

## 1. Goals, exclusions, and files

One Godot 4/GDScript developer, 72-hour jam; straightforward 2D scenes, idempotent operations and editor-visible `.tres` game content. No global autoload managers, generalized entity/component framework, pathfinding, inventory framework, pause-on-shop, employees, save/load, utility upgrade trees or automatic online fulfillment. Use placeholders until final sprites arrive. Scene IDs and hitboxes must survive art swaps.

**Canonical scene tree (technical freeze):**

```text
res://scenes/main/game_root.tscn  GameRoot [Node2D; scripts/core/game_root.gd]
├── World [Node2D; world/map assembly]
│   ├── FloorTiles [TileMapLayer / floor click routing]
│   ├── DineInWaitingAnchors [Node2D; visible outside-diner lane near UI boundary]
│   ├── Player [Node2D / Sprite2D]
│   ├── KitchenStations [Node2D; fridge, box, stove, cooker, washer, rack, trash]
│   ├── KitchenWorkTables [Node2D; staging and chopping hitboxes on same fixture]
│   ├── DiningTables [Node2D; purchased table nodes]
│   ├── OnlineStation [Area2D; accept offers only]
│   ├── DriverPickupSpots [Node2D; 3 authored world markers]
│   ├── DriverOverflowAnchors [Node2D; authored visual area]
│   ├── DriverObjects [Node2D; runtime clickable drivers]
│   └── PlacementSlots [Node2D; authored fixture slots]
├── KitchenController [Node; scripts/kitchen/kitchen_controller.gd]
├── ServiceController [Node; scripts/service/service_controller.gd]
├── RunController [Node; scripts/economy/run_controller.gd]
└── UI [CanvasLayer; scripts/ui/game_ui.gd]
```

World nodes have stable IDs, collision/hitbox metadata and sprites, **not** their own duplicate wallets, food ledgers, orders or timers. `GameRoot` references three controllers directly (`@onready` or explicit setters) and wires UI signals once. No scene reload between days. A separate `vertical_slice.tscn` can instantiate same root/controllers with short test durations and placeholder art. Final world placement comes from scene-authored slots and walkability; the **newest nonbinding layout** is `references/current_screen_layout_NON_BINDING.png` (supersedes the prior sketch). For UI/world composition and viewport fit, follow `docs/WORLD_LAYOUT_AND_VIEWPORT.md`. Do **not** preserve the older 10×9 footprint in code or fix object IDs to pixel positions.

**Suggested paths:** `scripts/core/game_root.gd`, `scripts/core/shared_types.gd`, `scripts/kitchen/{kitchen_controller,food_item_state,food_component_state,ingredient_def,recipe_def}.gd`, `scripts/service/service_controller.gd`, `scripts/economy/{run_controller,economy_config,utility_def}.gd`, `scripts/ui/game_ui.gd`; scenes in `scenes/world/`, UI in `scenes/ui/`, static definitions in `data/ingredients/`, `data/recipes/`, `data/utilities/`. These are simple path targets; creating more layers should require a concrete dependency.

### Screen composition boundary (v2.1 layout update)

Use **one ordinary Godot 2D viewport** with the `World` as `Node2D` and UI as `CanvasLayer`. Reserve a non-interactive-to-world **left UI safe region**; show the playable restaurant on the **right**, with the visible dine-in waiting lane along the left edge of that world. Keep the separate C-owned online driver pickup spots and overflow queue within the world view. The current art sketch is approximate, so viewport, tile count, margins, and exact station positions are scene/layout data, **not frozen gameplay constants**. A simple `World` origin/scale offset or a single `Camera2D` arrangement is sufficient (pick one), with UI `Control` anchors in viewport coordinates. Avoid adding a `SubViewport` / second world renderer merely to separate the UI.

**Input must respect the split:** pointer clicks inside the persistent UI band must never become floor teleports; click-through on modal planning panels must be blocked. The world hit-test still uses world/tile coordinates, regardless of on-screen offset/zoom. UI marker positions and station dialog bubbles must convert world anchors to canvas positions, and clamp or flip inside the *visible world-safe region* when possible. All mouse travel between screen regions remains intentional; do not automate interactions. See `docs/WORLD_LAYOUT_AND_VIEWPORT.md` for layout proposal and checks.

## 2. Exactly one owner per mutable state

| Runtime owner | Sole mutable authority | Consumers / boundaries |
|---|---|---|
| `GameRoot` | `phase`, `service_elapsed: float`, service-start/auto-close/settlement latch, day transition sequencing | Exposes phase/time to controllers and E; never holds order, stock or cash |
| `KitchenController` | player `Vector2i` tile, selected clickable target, typed accepted prefix, one held item, food component/aggregate states, kitchen work staging, physical storage slots, purchased plate ID registry, dirty washer queue, paid shipment reservations and due times (any movement helper is strictly internal with no duplicate tile/selection state) | C calls exact dish/plate operations; D calls capacity/receipts; E reads snapshots |
| `ServiceController` | dine-in spawn quota, outside dine-in FIFO, customer IDs/order IDs/timers/status, dining-table clean/occupied/dirty state, online offer, online order IDs, per-order driver identities/pickup spot and overflow FIFO, all 60s/100s/20s deadlines | B forwards clicked table/driver/station actions; D receives reports and credits; E reads snapshots |
| `RunController` | `day_index`, balance/cash ledger, selected/unlocked menus, fixed price/config lookup, fixture ownership/placement, original payment and refund IDs, accepted failed-order demand debt, day settlement and Day 7 result | C receives immutable day plan; B receives fixture/delivery decisions; E reads snapshots |
| `GameUI` | only presentation state: which panel has focus, prompt animation, text formatting, local UI selection (e.g., purchase quantity) | Emits requests, never mutates true balance, order status or remaining time |

**Static vs runtime:** Static `IngredientDef`, `RecipeDef`, `UtilityDef`, `EconomyConfig` are Godot `Resource` / `.tres`. Do **not** mutate shared static Resources while serving. Use unique IDs for mutable items, plates, orders, customers, drivers, fixture instances and purchases; never use translated Indonesian labels as primary keys. `StringName` for stable IDs; 1 `plate_id` in the registry even when referenced by a plated aggregate. Read-only UI views should be reconstructed/copied `Dictionary`/`Array` objects and must not contain references to private mutable maps.

**Enums** in `shared_types.gd` (single owner):

```gdscript
Phase = { PLANNING, SERVING, CLOSING, RESULTS, FINISHED }
OrderKind = { DINE_IN, ONLINE }
OrderStatus = { OPEN, COMPLETED, FAILED }
CustomerState = { OUTSIDE_WAITING, SEATED_WAITING, EATING, LEFT }
TableState = { CLEAN_VACANT, OCCUPIED_WAITING, OCCUPIED_EATING, DIRTY }
DriverState = { AT_PICKUP_SPOT, OUTSIDE_DRIVER_QUEUE }
FixtureKind = { BOX, FRIDGE, STOVE, WASHER, PLATE_RACK, RICE_COOKER, DINING_TABLE }
```

Enums are code-level names, not player-facing strings. Additional `ItemLocation`/`PlateLocation` enums local to Kitchen are permitted.

## 3. Canonical phase machine and service clock

```text
BOOT -> PLANNING(day=1)
 PLANNING -- explicit start-service button and valid D plan --> SERVING(day, service_elapsed=0)
 SERVING -- C drained 4 categories --> CLOSING [automatic; no button]
 CLOSING -- freeze/tally/refund/reset/settle once --> RESULTS
 RESULTS(day < 7) -- Continue once --> PLANNING(day+1)
 RESULTS(day=7) -- D compares cash after electricity --> FINISHED(WON|LOST)
 FINISHED(WON) -- optional Extra Mode once --> PLANNING(day=8)
 EXTRA RESULTS -- Continue --> next PLANNING (no compulsory new deadline by default)
```

`ServiceController.is_drained()` is **true only** when **all four** conditions hold:

```gdscript
day_queue_remaining == 0 \
    and outside_dine_in_queue.is_empty() \
    and in_shop_dine_in_count == 0 \
    and online_orders_open.is_empty()
```

An unaccepted online offer does not block close. Drivers are representations of accepted online orders; don't double-count driver spots in the close guard. Dirty tables and unpaid physical dishes do not block close; paid ingredient deliveries do not block close. Starting service with zero diner quota results in close once all due first-tick events are processed (no online acceptance when unspawned <=2). **No manual close action.**

**Frozen time architecture:** One `service_elapsed: float` maintained by `GameRoot` advances by `delta` **only** when phase is SERVING; **no per-order Godot `Timer` nodes and no second decremented clock**. Order, eating, spawn and shipment records store `due_at = service_elapsed + duration`, and expose `maxf(0, due_at - service_elapsed)` in views. UI modals never pause the tree or service time. `GameRoot._process(delta)` while SERVING does: (1) increment clock, (2) `KitchenController.advance_service_time(now)` (commit all due deliveries), (3) `ServiceController.advance_service_time(now)` (spawn due customers, expire due orders, finish eating, admit waiters), (4) if `ServiceController.is_drained()`, close synchronously. `ServiceController.begin_service(now=0)` creates the first diner at t=0, then schedules at t=20,40,...; catch up in a `while next_spawn_at <= now` loop, not one spawn per rendered frame; for a long frame, each spawned record uses its **scheduled** spawn timestamp for the 100s deadline rather than receiving extra patience from the frame delay. Deadline expiry is validated again before serving on each input; a serve at exactly `due_at` loses to timeout. When delivery and closing condition coincide at a clock advance, **committed due delivery precedes close**; pending at `CLOSING` cancels/refunds. This is a *technical tie-break*, not added gameplay. All callbacks/advance methods verify phase and day; no `await` inside money/food/order commits.

### Phase transition transaction (idempotent)

1. Run `start_new_run()` once: seed confirmed starter kit (1 box, stove, washer, rack, cooker, 2 diner tables, fixed map work/prep table and trash), starting cash/config, Day 1 unlocked recipes. Root enters PLANNING.
2. On Start Service, D `finalize_plan()` checks nonempty unlocked menu, takes fixture/table and price snapshot; B prepares for day; C prepares from D `ServicePlan`; Root enters SERVING, resets clock to 0, C `begin_service(0)` spawns customer zero.
3. After all four drained checks, Root sets CLOSING **before** touching money/food; blocks interaction and new buying; captures C `ServiceDayReport` while C owns records.
4. B cancels **only PENDING** paid ingredient shipments and releases their reserved capacity; returns actual unique `purchase_id`s. D refunds these IDs **once** from its recorded paid ledger. No delivered shipment refund.
5. B discards every food/item outside raw fridge stock (held, work table, cooker output, box, other prep), resets owned finite plates CLEAN and washer queue. C resets diner/driver/order/table day state. Purchased fixture ownership and raw fridge stock persist.
6. D `settle_day_once(report)` credits no extra income from a report (orders were credited on serve), charges each installed fridge/cooker flat daily electricity **once**, rolls future demand debt changes once, determines post-day cash and Day 7 outcome if applicable. UI shows RESULTS; Root prevents duplicated close/continue.
7. Root advances `day_index` once when authorized by user results action; D unlocks *authored* recipes whose `RecipeEconomyEntry` has `unlock_day == day_index` (referencing `RecipeDef` by `recipe_id`; no invented dishes). Once WON on Day 7 result, optional extra continues without clearing victory latch.

## 4. Shared data contracts (schemas)

All methods below are the **single frozen technical set**, not a list of suggestions to choose between. A/B/C/D/E domain specs detail internal implementation and UI fields.

**`ServicePlan` (D→C immutable per day):** `{ day_index:int, day_queue_initial:int, selected_recipe_ids:Array[StringName], dine_in_price_by_recipe:Dictionary[StringName,int], installed_table_ids:Array[StringName] }`. The menu is frozen after Start Service. C never computes money/demand itself. `day_queue_remaining` decrements *on spawn* and not on outside admission.

**`ServiceDayReport` (C→D once at close):** `{ day_index:int, arrived_dine_in_count:int, completed_order_ids:Array[StringName], failed_order_ids:Array[StringName], completed_dine_in_count:int, failed_dine_in_count:int, completed_online_count:int, failed_online_count:int, initial_dine_in_quota:int }`. IDs unique, statuses terminal; D uses only failed IDs for future demand debt; online acceptance previews never create failed IDs. Finance views are built by D from its ledger, not fabricated by UI.

**`FoodItemState` (B mutable):** `{ item_id:StringName, plate_id:StringName or empty, parts:Array[FoodComponentState], location, work_table_id }`, with exactly one held aggregate. `FoodComponentState` holds `ingredient_id` and ordered prep-state flags. `RecipeDef` stores exact multiset of required processed components, allowing unlimited new authored `.tres` recipes without editing serving code; no extra ingredient, missing state or absent plate may match.

**`StorageUnit` (B mutable, keyed by installed `storage_unit_id`):** `{ kind:BOX|FRIDGE, slots: Array[{ingredient_id:StringName or empty, quantity:int, capacity:int}], reservations: paid-purchase IDs }`. Fridge exactly 2 slots capacity 3 each; box 3 slots capacity 5 each. Duplicate IDs across slots legal. Only raw stock may enter. Destination is the **user-selected container**, not automatic distribution. Sale validation checks stock/reservation before removal.

**`PlateRecord` (B mutable, keyed by unique ID):** `{ plate_id, source_rack_id, location:RACK|HELD|WORK_TABLE|CUSTOMER_TABLE|WASHER_DIRTY }`. Zero duplicate plate IDs; a plated aggregate *references* its plate, it doesn't create another. Online completed plate returns CLEAN directly; dine-in plate sits at table until clean. At close all purchased plates return clean to surviving racks.

**`DriverRecord` (C mutable):** `{ driver_id, order_id, state:AT_PICKUP_SPOT|OUTSIDE_DRIVER_QUEUE, spot_id_or_empty, deadline_at }`. Exactly 3 *authored* pickup markers; overflow FIFO is distinct from outside dine-in FIFO. When a driver resolves/fails, promote earliest still-open outside driver into freed spot without timer reset. E renders driver views; B resolves click target to `driver_id`.

**`PurchaseRecord` (D mutable):** `{ purchase_id, kind:INGREDIENT|FIXTURE, storage_unit_id when ingredient, item_or_fixture_id, quantity, actual_amount_paid, status:PENDING|DELIVERED|REFUNDED }`; D owns the paid/refund ledger, B owns stock/due/reservation. A returned pending purchase ID is refunded from ledger once. An installed starter fixture is owned with `actual_amount_paid=0` (default prevents free resale exploit).

## 5. Frozen method/signal catalog

Arguments and return types are intended GDScript APIs. `Dictionary` returned to UI is a fresh snapshot, not a writable owner reference. Implement with `class_name` only where it aids type checking; avoid circular Resource class references. UI and World should not access controller internals to mutate them.

### A: GameRoot

```gdscript
func start_service_requested() -> bool         # PLANNING only; finalize plan then begin
func request_continue_from_results() -> bool  # RESULTS Days 1-6 or extra mode
func request_extra_mode() -> bool            # only WON post-Day7
func request_close_if_drained() -> void      # C/root only; no UI close button
func is_serving() -> bool
func get_service_elapsed() -> float
signal phase_changed(phase: int, day_index: int)
```

### B: KitchenController / world click / typed command

```gdscript
func on_floor_clicked(tile: Vector2i) -> bool
func on_interactable_clicked(target_id: StringName) -> bool
func accept_typed_character(character: String) -> bool
func clear_command_prefix() -> void
func get_command_prefix() -> String
func get_allowed_commands_for_selected_target() -> Array[String]
func get_held_item_view() -> Dictionary
func get_storage_unit_view(storage_unit_id: StringName) -> Dictionary
func get_pending_delivery_views() -> Array[Dictionary]
func can_receive_stock(ingredient_id: StringName, quantity: int, storage_unit_id: StringName) -> bool
func reserve_incoming_capacity(purchase_id: StringName, ingredient_id: StringName, quantity: int, storage_unit_id: StringName) -> bool
func receive_stock(purchase_id: StringName, ingredient_id: StringName, quantity: int, storage_unit_id: StringName) -> bool
func schedule_delivery(purchase_id: StringName, ingredient_id: StringName, quantity: int, storage_unit_id: StringName, due_at: float) -> bool
func cancel_pending_deliveries(day_index: int) -> Array[StringName]
func clear_non_fridge_food_for_next_day() -> void
func advance_service_time(now: float) -> void
func try_consume_serving_item(item_id: StringName, recipe_id: StringName, order_kind: int, dine_in_table_id: StringName) -> bool
func move_cleaned_table_plate_to_washer(table_id: StringName) -> bool
signal player_tile_changed(tile: Vector2i)
signal selected_interactable_changed(target_id: StringName)
signal command_prefix_changed(prefix: String)
signal action_feedback(code: StringName)
signal kitchen_state_changed()
```

**Important distinction:** `KitchenController.on_interactable_clicked` is the **sole** world target router; it teleports/sets selection and performs immediate click-only action on rack/work surface as applicable. When typed `saji` finishes with a selected diner table, it calls C `try_serve_table`, with selected in-spot driver it calls C `try_serve_driver`. Online station supports typed `terima` to call C `try_accept_online_offer`, **not `saji`**. `KitchenController.try_consume_serving_item` is ONE **four-argument** method—no second `record_served_plate` step. For `ONLINE`, `dine_in_table_id == &""`; for `DINE_IN` it is validated current table ID.

### C: ServiceController

```gdscript
func prepare_service_day(day_index: int, plan: Dictionary) -> void
func begin_service(now: float) -> void
func advance_service_time(now: float) -> void
func is_drained() -> bool
func freeze_and_build_day_report(day_index: int) -> Dictionary
func reset_dirt_and_day_customers() -> void
func try_serve_table(table_id: StringName, item_id: StringName) -> bool
func try_serve_driver(driver_id: StringName, item_id: StringName) -> bool
func try_clean_table(table_id: StringName) -> bool
func try_accept_online_offer() -> bool
func get_order_view(order_id: StringName) -> Dictionary
func get_customer_queue_view() -> Dictionary
func get_table_view(table_id: StringName) -> Dictionary
func get_driver_views() -> Array[Dictionary]
func get_online_offer_view() -> Dictionary
func get_online_acceptance_enabled() -> bool
signal orders_changed()
signal queues_changed()
signal tables_changed()
signal drivers_changed()
signal online_offer_changed()
```

`try_serve_table` gets its exact OPEN seated order; `try_serve_driver` gets exact OPEN order bound to the driver and verifies driver AT_PICKUP_SPOT; both validate timer and ask B to consume matching plated aggregate, commit order terminal, invoke D `credit_order_once` once and emit UI notifications. No separate UI selected order list. A table clean call to B moves its actual associated plate once, then C admits outside diner. `is_drained()` checks all four categories, not only physical diners. C must not write Kitchen plates or Run money directly.

### D: RunController

```gdscript
func start_new_run() -> void
func select_daily_menu(recipe_ids: Array[StringName]) -> bool
func request_fixture_purchase(utility_id: StringName, slot_id: StringName) -> bool
func request_fixture_sale(fixture_instance_id: StringName) -> bool
func request_ingredient_purchase(ingredient_id: StringName, quantity: int, storage_unit_id: StringName) -> bool
func finalize_plan() -> bool
func get_service_plan() -> Dictionary
func credit_order_once(order_id: StringName, recipe_id: StringName, order_kind: int) -> bool
func refund_canceled_deliveries_once(purchase_ids: Array[StringName]) -> void
func settle_day_once(report: Dictionary) -> Dictionary
func advance_to_next_planning() -> int
func get_run_view() -> Dictionary
func get_day_settlement_view(day_index: int) -> Dictionary
signal run_state_changed()
```

D performs phase, affordability, selected-container capacity, equipment-slot and ledger validations and asks B/C to create/remove operational fixtures; purchases and resale only PLANNING, except **ingredient** purchase also SERVING. D must preserve original paid amounts and never credit an order ID twice. Extra mode and Day 7 win status latch are D-owned, but root orchestrates UI transition. Any method that succeeds/changes state emits notification after commit, never from UI optimistic state.

### E: UI bridges

`GameUI` receives signals and requests fresh views from B/C/D; its script offers `show_phase`, `show_feedback`, `refresh_world_indicators` and targeted purchase menus as local methods as needed. **No second input parser, shipment timer, plate count, driver order map or wallet**. The Shop/Belanja modal consumes GUI clicks/keyboard UI events, not world click events, and service elapsed clock still runs. See `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md`.

## 6. Atomic cross-domain transactions

1. **Ingredient buy:** D preflight money/phase/destination; obtain unique `purchase_id`; B reserves capacity in **specified** unit; D debits and records paid amount **once**; in PLANNING B immediately commits `receive_stock`; in SERVING B schedules `due_at=now+100`. If any synchronous step fails after reservation, restore reservation and any debit in the same call. One shipment cannot be delivered/refunded twice. `can_receive_stock` is advisory; `reserve_incoming_capacity` revalidates atomically.
2. **Dine-in or driver serve:** B typed completion → C `try_serve_table` or `try_serve_driver` (exact physical target) → C validates phase/order/deadline/target → B `try_consume_serving_item(item_id,recipe_id,kind,table_id)` validates plated exact-match and transfers **same unique plate** to dine-in table or clean supply on ONLINE → C marks `COMPLETED` once, stops deadline, starts 20s eating if dine-in or frees driver/slot if online → D credits `order_id` once → E observes. Wrong/late dish never mutates anything. If D credit unexpectedly fails after validated serve, log/flag developer invariant error; ensure D cannot normally reject a valid C-confirmed first completion (do not introduce heavy transaction rollback framework).
3. **Table cleaning:** B typed `bersihkan` on exact dirty diner table → C validates DIRTY/no occupant → B `move_cleaned_table_plate_to_washer(table_id)` moves plate ID **once** → C marks CLEAN_VACANT and seats first live outside waiter. Repeated cleaning fails without extra plate.
4. **Fixture placement/sale:** D validates PLANNING, authored slot, cash, operational install/removal safety; updates cash and fixture ownership plus B/C visual/runtime registration **synchronously**. Sale rejects storage containing raw stock/reservations or racks with unremovable plates. A purchased rack grants finite unique plate IDs once; sale removes only those safe IDs. A starter fixture has zero paid purchase amount (reversible default); do not create cash by selling freebies.
5. **Day close:** C snapshot report, B cancel deliveries, D refund canceled IDs, B clear nonfridge food/plate dirt, C reset tables/customers, D power/debt/target once; abort repeated CLOSING. See §3.

## 7. World input and physical boundaries

- Single input router: GUI `Control` buttons consume clicks (`mouse_filter=STOP`); decorative UI ignores; world uses target `Area2D.input_event` or one central hit test and floor `_unhandled_input`, **not both competing click routers**. An object click takes precedence over floor. Exactly one target per click.
- Floor click teleports to valid accessible floor tile only, clearing prefix and deselecting old target (technical default). Interactable click from any distance finds valid **cardinal** neighbor; if already adjacent, remain; otherwise teleport and select/activate **same click**. If none free/valid, reject, no partial movement/action. Choose nearest legal neighbor (shortest Manhattan distance from `player_tile`, fixed cardinal tie-break order up/right/down/left); multi-tile objects use footprint, not sprite center. Fixed 32px art does not determine click rectangle.
- Online station `terima` offers; accepted order driver appears at first available of 3 spot IDs else outside FIFO; only at-spot drivers are serveable; `saji` on outside driver is rejected without food removal. Purchased tables are distinct from kitchen work table.
- Contextual washer uses `cuci` for held RAW rice or one dirty plate with empty hand. Physical work/prep table has mouse staging hit area and a **separately targetable chopping action** for `potong` while held `sayur`; both belong to existing free fixture, not a new purchasable machine. This avoids auto-staging when trying to chop.

## 8. Data-change resilience and tests

- `RecipeDef` requirements are ingredient+prepared-state records; new recipe `.tres`, icon and D economy/unlock entry should be enough to add Days 4–7. Do not hardcode a `match recipe_id` with exactly three cases in C or B. Validate distinct IDs, references and nonempty requirements before Start Service; refuse unknown/empty menu. Missing future recipes should be reported as **content pending**, not autogenerated.
- Tunable prices/deadlines/quota settings are in one `EconomyConfig.tres`/related Resources. **Confirmed** live durations (100,60,20,20,100) should default to fixed requirements; use override/injection only in test scenes. Day 1 starting cash, target, menu bonus, online multiplier, plate per rack and all prices are playtest knobs, not coordinator-established values.
- Acceptance suite: `docs/ACCEPTANCE_TESTS.md`. Build exact one-day vertical slice first. Every phase/order/plate/delivery/purchase transition should tolerate repeated callback IDs. Headless editor import (`godot --headless --path . --import`) is a sanity check after `project.godot` exists; playtest actual input/UI separately. Windows/Linux export only after desktop build is stable.

## 9. Integration risk gates

**RESOLVED:** online accepted orders delay close (C-07); physical driver fulfillment (E-08–10); slots not distinct types (B-10); selected container purchase (D-07); planning-only immediate fixture changes; contextual washer/chopper; online simultaneous cap; no pause while shopping. The original documents still contain superseded alternatives: do **not** consult them for implementation.

**CONTENT/TUNING, not architecture blockers:** four+ future approved recipe definitions and icons, final art/world fixture positions, prices/current balance/target/plate counts/demand bonus, perhaps exact Indonesia-facing spellings. These stay editable/recorded and should not be silently filled by Claude Code. **Implementation defaults** are identified in `docs/DECISION_REGISTER.md` and `docs/CONTENT_AND_TUNING.md` and are to be reviewed during playtest.
