# E — World-first UI, Input Feedback and Indonesian Copy (revised v2.1)

**Owner:** `GameUI`. Reconciles Agent E v1.1 (39 coordinator answers) with the now-authoritative C driver implementation, D planning-only fixture changes, B chosen-container APIs, and **no pause on `Belanja`**. UI reads state from A/B/C/D and issues validated requests; it never hosts an independent command parser, order timer, money amount, plate ledger or online queue.

## 1. Overall visual hierarchy

The restaurant **world is the primary interface**, alongside a **dedicated left vertical UI band** visible during service. The latest coordinator sketch (`references/current_screen_layout_NON_BINDING.png`) places an in-world **dine-in waiting lane immediately to the right of that UI**, with the restaurant world to the waiting lane’s right; kitchen tasks are mostly upper-world, dining below. The illustrated playable world spans **roughly 13×9 cells including the waiting lane**; this is an estimate from a rough sketch, **not** a frozen floorplan or the old 10×9 size. Tiles/art are 32×32 px. The earlier 10×9 assumption is superseded. A 640×360 logical viewport / 1280×720 window is still a **proposed fit test**, not approved output dimensions. Use pixel-consistent/nearest filtering if it fits the artwork and test actual queue/prompt visibility before selecting the final framing. Detailed recommendations and checks live in `docs/WORLD_LAYOUT_AND_VIEWPORT.md`.

Priority during service, top to bottom: **(1)** active selected interactable typing dialogue with its current actual prefix/ghost command, **(2)** dish and shrinking timer rings above diners/drivers, held-item icon above player, delivery rings at selected storage and dirty table cues, **(3)** hover/selection feedback, **(4)** minimal persistent service strip (day/cash/goal/unspawned quota). The active prompt never hides behind ordinary world indicators. Blocking purchase/confirmation modal may deliberately cover and disable world typing. No separate permanent order-ticket rail; each dine-in order is a recipe **icon above that person**.

### Suggested `CanvasLayer` UI composition

```text
GameUI [CanvasLayer]
└── UIRoot [Control full rect; mouse_filter=IGNORE except active modal bounds]
    ├── LeftHUDRegion [reserved persistent left-side band / service HUD safe area]
    │   └── ServiceStrip [cash + Day7 goal progress/target, Hari N, unspawned count]
    ├── PlanningStrip [Hari N, cash/goal, Menu, Mulai Layanan; may use left band]
    ├── WorldIndicators [customer recipe icons / 100s & 20s rings; driver / 60s rings;
    │                    held item above player; 100s shipment rings; dirt markers]
    ├── InteractionDialogue [anchored to selected station/table/driver, highest normal z]
    ├── StorageDialog [compact slot summary, typed options if SERVING, Belanja]
    ├── ContextPanel [menu selection, storage buy, slot-based fixture choice, sale; may overlay world temporarily]
    ├── ConfirmationDialog [fixture buy/sale ONLY]
    ├── DayResultSidePanel [slide-in summary, Hari 7 result and optional Mode Ekstra]
    └── ContextMessage [short Indonesian action rejection under active dialogue]
```

Keep implementation compact: one `game_ui.gd` and a few reusable small `.tscn` panels (`interaction_dialogue`, `ring_indicator`, `storage_dialogue`, `day_result_panel`). UI widgets are purely rendering; hitbox nodes for customers and drivers are in WORLD and route via B input. Don't build generic UI framework, screen router, animation dependency or save-backed preferences.

## 2. Mode/state/prompt specifications

| Mode / world state | Must display | User input and authority |
|---|---|---|
| PLANNING | Restaurant still visible, tiny strip, `Menu`, `Mulai Layanan`, cash/goal/day | Menu button → D unlocked/selectable recipe entries; click empty authored slot → D fixture choices; owned fixture → D resale; storage → Belanja; no cooking typing |
| Menu selection | Distinct recipe icons, Indonesian dish names, selected marks, optional prices/forecast | D `select_daily_menu` validates nonempty selected unlocked IDs; do not invent Day4–7 absent recipes |
| Click empty fixture slot | Eligible equipment choices, price, fixed electricity rate | `request_fixture_purchase(def_id,slot_id)` after **confirmation**, installs immediately; no service-time delayed fixture shipment |
| Click owned fixture during planning | Resale value/loss, installed category | `request_fixture_sale(instance_id)` after **confirmation**, immediate safe removal (includes tables); no duplicate money |
| Click fridge/box either phase | Compact **physical slots** & quantities, valid current command words (SERVING only), **Belanja** button | Purchase panel preselects that exact `storage_unit_id`; ingredient/qty/quote/free capacity/arrival label; `Beli` calls D once, NO second confirm; no spill into another box/fridge |
| SERVING general | Thin strip with `Hari N`, actual cash & Day7 progress+target, **unspawned** customer icon/count; world icons/rings; held icon over player | Floor click only teleports, interactable click teleports cardinal-adjacent and selects; typed work only in serving |
| Active station/driver | **Highest-priority** anchored dialogue: station name, comma-separated choices if multiple, ghost text/prefix line | B `get_allowed_commands_for_selected_target()`, `get_command_prefix()`; E sends Unicode keys to B; no extra Enter button |
| Dine-in OPEN, outside or seated | Dish icon and shrinking 100s ring **above each person** (outside patrons still timed) | Only seated table `saji`, not outside; C owns deadlines/queue/order and table states |
| EATING | 20s ring with distinct eating-state icon/tint, no OPEN order icon | After 20s C marks table DIRTY; E shows dirt marker; `bersihkan` when selected |
| Online station preview | Displays active periodic preview dish icon & countdown status when `AVAILABLE`, or waiting/restriction message when `WAITING` / `UNAVAILABLE`, **no driver before acceptance** | Select station, type `terima` if C says eligible (`offer_state == AVAILABLE`); no `saji` here |
| Accepted online order | **One actual clickable driver** linked to order; dish icon and 60s ring | Exactly 3 pickup spots; click in-spot driver and type `saji`; overflow drivers visible with running rings but **not serveable** |
| Online cutoff | Disable new `terima` when **unspawned day quota <=2**; existing drivers continue | Do NOT check outside dine-in waiter count or driver's overflow count for cutoff |
| In-service ingredient shipment | **100s ring/icon above chosen destination container** | B pending `due_at`, countdown displayed; no modal pause; cargo appears only after 100s or is canceled/refunded at close |
| CLOSING | Stop world action input while root freezes+settles | Do not display manual close button; online OPEN prevents close even with no physical diner |
| RESULTS | Compact **slide-in side panel** over still-visible world, finance, completed/failed by channel, refunds, electricity, debt change, forecast | `Continue` once via A on Days1-6; Day7 shows win/loss by **current post-electricity cash**; only WON offers Mode Ekstra |

## 3. Typing dialogue: exact behavior, mouse focus and feedback

When selected typed action target exists, anchor speech/dialogue above target, clamp/flip near screen edges and keep above order rings. Simple examples (text samples for layout, not independently accepted vocabulary):

```
Kompor
[ goreng ]                  # translucent ghost full command before typing

Kompor
[ GOReng ]                # accepted prefix opaque, remaining command grey

Kulkas
ayam, beras, telur          # B's CURRENT available exact commands
[ ... ]                    # ambiguous until prefix identifies option
```

- **B single prefix authority.** Accepted keys extend only valid commands; invalid typed character ignored, E shakes dialog briefly (e.g., 0.1s, optional animation), never prints a mistake per keystroke. Completing full word autoexecutes (no Enter). Clicking elsewhere clears old prefix; station work stays staged. `get_allowed_commands...` already accounts for selected target's true contents/held state; E does not hardcode token list per node or incorrectly show `saji` at online *acceptance* station.
- If several command options share prefix, display comma-separated choices with matching options highlighted; ghost-complete only when a unique match exists (visual default). The active dialogue displays **one** progress line/box and a short optional failure message below (`Tangan penuh`, `Bahan habis`, `Pesanannya beda!`, `Nggak bisa sekarang`). No giant how-to panel, progress bar per action or intrusive timed-out patron modal.
- Use `Control.mouse_filter=STOP` on clickable menus/buttons/modals and `IGNORE` on decorative world rings/overlays. `GameUI._unhandled_key_input` or single chosen B ingest path forwards Unicode to B only if SERVING, valid target selected and no modal keyboard focus. Ignore `event.echo`; do not place an ordinary editable `LineEdit` in front of the gameplay validator. Purchase quantity widgets may use `LineEdit` but **must disable gameplay typing** while focused. Button activation must not teleport player through UI. **Opening `Belanja` or confirmation during SERVING does NOT stop C patience, online, eating, arrival or shipment clocks**.
- Normal selected dialogue has highest visual priority except deliberate blocking modal. When the player holds an item, render **its icon above player** rather than adding a second held-slot HUD. Multi-part plated food may use recipe icon if exact match else generic loaded-plate icon. Visuals are keyed by logical IDs, never asset filename as key.

## 4. Customer and driver visuals (C data owner)

- One recipe icon plus circle ring over each OPEN diner; outside diner icon/ring visible wherever their sprite stands. A seated diner always corresponds to one table and one OPEN order (unless EATING). A 100s ring starts full at *spawn*, empties based on `seconds_remaining/100.0`; eating ring based on `/20.0`. No permanent number text required. After expiry show local vanishing/fading marker only, no full-screen message.
- One preview recipe icon at online station, no countdown. **After acceptance** create/show one driver record from C with 60s ring and order icon. The first **three** accepted drivers occupy authored pickup spots; overflow drivers shown in an outside driver queue, separate from outside diners and without a serving affordance. As a spot opens via fulfilled or timed-out driver, show next C-promoted driver at assigned marker; E doesn't create/advance drivers itself. Driver remaining time always stays on the 60s clock started at acceptance, regardless of travel/queue.
- One 100s ring per pending *paid ingredient shipment* at its actual destination box/fridge. Multiple concurrent deliveries to one container may stack count badge rather than duplicating clutter (pure display choice). C cannot close until accepted online orders resolved; shipments themselves never delay automatic close; if canceled D reports refund.
- World indicators read stable IDs and positions from C/B and world node registry. The online station has an acceptance hitbox; driver sprite has a separate click hitbox giving `driver_id`. UI labels and rings should be `MOUSE_FILTER_IGNORE` so they don't steal world clicks. Valid `saji` driver prompt is anchored over **clicked in-spot driver**, not old C selected-online list or station.

## 5. Menu, money and result presentation

- In planning, `Menu` button opens unlocked authored recipe entries from D with distinct artist-provided icons and selected marks, plus a compact forecast readout (`Potensi Tamu` and `Target Tamu` queried from `RunController.preview_demand_for_menu()`). Player can offer fewer or more available dishes; it does not cook the menu or require typing recipe names, and E never calculates demand math itself.
- Storage popup exposes actual raw slot contents and quantities: fridge **2×3** slots, box **3×5** slots, repeated ingredient names across independent slots allowed. `Belanja` starts by selected actual physical container, not generic inventory. Enter ingredient ID/quantity in UI, show calculated cost from D and if SERVING `Tiba 100 dtk` not `Tiba sekarang`. Press `Beli` to commit once; show B/D real error if full, stock reserved, no cash or invalid unit; do not create a client-side stock pile.
- Equipment placement **slot-first** and equipment resale **click existing fixture** in planning; both ask confirmation (unlike ingredient `Beli`). Display buy price, resale value (strictly lower than paid for purchased fixture), fixed fridge/cooker electricity fee. A starter gifted fixture may return Rp0 on resale by explicit reversible economy default; show actual quote to avoid surprises. No upgrade buttons.
- Minimal strip displays `Potensi Tamu` alongside `Target Tamu` in Planning, and during SERVING reads **D cash**, Day7 target/progress ratio, day index, and **C `day_queue_remaining`**.
- Side results panel shows D `DaySettlementView`: dine-in/online completion/failure counts, income, refunds, electricity, total cash after charge, debt +/−, `Potensi Besok`, and `Perkiraan Besok`. On Day7 show `Berhasil!` or `Belum cukup uang` according to D's result latch, not E arithmetic. After Day7 WON optionally show Mode Ekstra. Animations are polish only; result content must work without animation.

## 6. Localization/data contracts

Stable internal IDs: recipe `nasi_telor/nasi_ayam/nasi_komplit`, ingredient `beras/ayam/tempe/telur/sayur/sapi`, station categories, fixture/driver/table IDs. User-facing text casual Indonesian, editable in a central dictionary keyed by identifiers. Initial **working command tokens** (B's one parser; spellings may be edited in one place only): `beras`, `ayam`, `tempe`, `telur`, `sayur`, `sapi` (retrieval); `cuci`, `masak`, `nasi`, `goreng`, `potong`, `saji`, `bersihkan`, `terima`. Same `cuci` allowed on washer for rice vs plate by context; no duplicate simultaneous parser. UI derives currently valid commands from B; if an artist/UI label changes, logical item IDs and accepted keyboard strings remain consistent.

**Required read-only views:** B `get_command_prefix`, `get_allowed_commands_for_selected_target`, `get_held_item_view`, `get_storage_unit_view`, `get_pending_delivery_views`, player tile/selected target; C `get_order_view`,`get_table_view`,`get_customer_queue_view`,`get_driver_views`,`get_online_offer_view`,`get_online_acceptance_enabled`; D `get_run_view`,`get_day_settlement_view`; A phase/time. Views should expose actual remaining time and stable object anchors. UI should refresh after owner signals or poll one view for smooth rings, never decrement C/B timers itself.

## 7. Fit, asset integration and tests

- **Layout v2.1:** dedicated left-side HUD band + visible waiting lane at left edge of world + restaurant playfield to the right, with kitchen generally above seating. The sketch suggests **roughly 13×9 cells for the world including waiting lane**, but geometry/positions are not fixed. At the chosen logical viewport, test **left HUD plus** full waiting lane, 3 driver pickup positions + visible overflow, rings, selected dialogue, purchase overlays and result side panel. `640×360`/`1280×720` remains provisional; do not crop world objects or shrink prompts below legibility merely to preserve that proposal. Keep service HUD in reserved left band; planning/shop/results may temporarily overlay the world. See `docs/WORLD_LAYOUT_AND_VIEWPORT.md`.
- All UI art is being made by UI/pixel artists, but placeholders with matching dimensions/IDs should be usable. A recipe has one distinct ID-keyed icon. Replacing sprite/frame/font later must not alter clicked Area2D hitboxes, store IDs or command logic.
- Test planning UI: `Menu` only in planning, purchases target clicked real container, item `Beli` no extra confirm, fixture buy/sell each confirm, service fixture change unavailable. Shop UI click does not trigger movement; service clocks **continue** while it is open.
- Test in-world prompt: full `goreng` word appears ghost → typed accepted prefix, bad letter ignored/shake, autoexecute no Enter; click a different target clears prefix; modal focused type input does NOT cook food. No stale command from another station.
- Test dine-in/open: icon+100s ring above each spawned diner including outside; eating 20s ring; waiter/driver queues distinct; timeout feedback local not screen-blocking.
- Test online: preview no timer/no driver, acceptance spawns driver at one of 3 spots, 4th overflow visible and not serveable, correct clicked driver `saji` matches its order; acceptance gate switches off at unspawned quota <=2 while existing drivers finish.
- Test results: accepted online order OPEN after last physical diner prevents results; when last online terminal, side results appear after D electricity/refunds; correct cash and goal; one Continue per day. Art swap leaves all hitboxes and IDs correct.

## 8. Story, Daily Narrative, Visual Guided Tutorial & Onboarding (`GameUI` + `NarrativeTutorialCatalog` + `TutorialGuidanceOverlay`)

- **Presentation-only ownership:** `scripts/ui/narrative_tutorial_catalog.gd` (`NarrativeTutorialCatalog`) holds static Indonesian narrative lines, 9 Guided Day-1 tutorial steps, 8 one-shot contextual feature discovery tips, and Quick Reference summary text with zero mutable gameplay or economy state. `scripts/ui/tutorial_guidance_overlay.gd` (`TutorialGuidanceOverlay`) is a non-blocking `Control` child (`mouse_filter = IGNORE`, `z_index = 8`) owned by `GameUI` that renders pulsating world/UI highlights, numbered markers, animated directional arrows, and compact command callouts while avoiding open `InteractionDialogue` boxes and viewport margins.
- **Boot & Legacy Test Compatibility:** Onboarding auto-enables on real scene launches (`get_tree().current_scene == _game_root`) via deferred boot check, while direct headless scene-instantiation tests (`root.add_child(game_root)`) keep onboarding disabled unless opted in with `ui.set_onboarding_enabled(true)`.
- **Story Dialogue (`StoryDialogueOverlay`):** Modal overlay in `PLANNING` (Day 1 `"Hari 1: Warisan Terakhir"` with `Kamu` using `player.png`, Days 2–7 daily story beats) and `FINISHED` (Day 7 Won/Lost epilogue carrying `"Memiliki lebih banyak belum tentu membuat kita lebih sukses..."`). Supports `Lanjut` / `Selesai` and `Lewati` without altering timers, cash, or recipe unlocks; hides visual guidance while open and closes cleanly before `SERVING`.
- **Day 1 Interactive Guided Tutorial (`TutorialBanner` + `TutorialGuidanceOverlay`):** Action-driven 9-step sequence (`step_01_objective` -> `step_02_prepare_ingredients` [requires both `beras` and `telur` ready, skipping re-purchase if already owned] -> `step_03_wash_rice` -> `step_04_cook_rice` [5 portions lesson] -> `step_05_cook_egg` -> `step_06_assemble_dish` [supports all two-way plating routes] -> `step_07_serve_customer` [strict `order_served` check + `wrong_order` contextual hint] -> `step_08_clean_and_wash` [`bersihkan` dirty table + empty-hand `cuci` at `Wastafel`] -> `step_09_finish_day` [DayResult summary highlight + reminder]). Recognizes pre-completed/out-of-order states without forcing duplicate work, and does not advance on partial/failed actions or modal openings.
- **Contextual Feature Discovery (`FeatureTipPanel`) & Quick Reference (`TutorialReferenceOverlay`):** Non-blocking one-shot tips (`online_offer`, `first_driver_pickup`, `driver_overflow`, `recipe_unlock`, `potong_veggie`, `serving_belanja`, `fridge_and_power`, `demand_and_debt`) highlight relevant world/UI targets dynamically when no tutorial step spotlight is active, and stale `SERVING`-only tips clear on close into `RESULTS`. `? Panduan` opens `Panduan Singkat Warung` with `Ulangi Tutorial` working safely on Days 1–7 without mutating cash, inventory, orders, or phase.
- **Pause Isolation & Responsive Viewport Fit:** Opening `PauseOverlay` temporarily hides Story, Reference, Help, Tutorial Banner, Feature Tip, and `TutorialGuidanceOverlay` while preserving exact active line/step/target indices on unpause; `_layout_onboarding_overlays()` keeps all panels and guidance callouts inside `640×360` and `480×270` bounds cleanly.
