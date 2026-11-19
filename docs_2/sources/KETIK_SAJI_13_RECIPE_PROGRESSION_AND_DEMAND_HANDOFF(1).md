# KETIK SAJI — 13 Recipe Content, Unlocks, Customer Demand & Ingredient Shop

**To:** Implementation agent / developer (Godot 4, GDScript)  
**Authority:** New coordinator recipe roster and unlock decisions; supersedes older three-recipe content and the flat menu-variety coefficient where they conflict.  
**Scope:** Recipe content, recipe descriptions, prices, per-recipe customer attraction, daily unlocks, ingredient purchase availability. **Not** a request to reset the project, change unrelated gameplay, or rewrite working systems.  
**Status:** **13 dishes, exact ingredients and day assignments are the content baseline.** Dish prices and the suggested +3/+2 lower-tier attraction numbers are **initial balance values to implement, not playtest-proven final balance**. Coordinator explicitly requires **expensive recipes to add +1 customer** when counted as an extra menu choice. All balance values must remain data-editable.

## 1. Coordinator decisions

1. **Exactly 13 recipes** are in the currently approved menu-art roster. All 13 have supplied **32×32 PNG dish icons** in `Plate + Menu.zip` and `Menu Salad + Nasi gila.zip` (the additional `plate.png` is an ordinary plate, not a 14th recipe).
2. On **Day 1, exactly one recipe is unlocked: Nasi Telur.** Unlock the rest progressively through Day 7 according to the table below. Unlocking a recipe makes it **selectable**; it does **not** force it into the player's active daily menu. At least one unlocked recipe must be selected before service starts.
3. **Offering more distinct dishes attracts more expected dine-in customers. Cheaper menu choices should have a larger customer-attraction contribution than expensive ones; expensive recipes add +1 expected customer.** Do not use the old flat `extra_arrivals_per_extra_selected_menu = 2` unchanged.
4. **Cheaper dishes remain more likely to be ordered** from the player's *selected* daily menu. The existing inverse-price order weight is a sensible starting default and is separate from the bonus-arrival calculation.
5. **The ingredient shop must not expose all raw ingredients on Day 1.** A raw ingredient becomes purchasable when the first recipe requiring it becomes unlocked at the **start of that day's PLANNING phase**. Once unlocked, the ingredient stays available in future planning phases **and during SERVING emergency shopping**. Do not disable the previously established service purchase/delivery system.
6. Each recipe now has a **short Indonesian `description`** shown in the existing **Resep** UI. Its job is to help the player identify which preparations are required. Use the recipe text below rather than generating text from names.
7. **This replaces outdated content definitions:** the old `nasi_ayam` that required tempe is superseded by **Nasi Ayam = rice + chicken only**. The old generic `nasi_komplit` is no longer in the approved menu; use the two specific chicken/beef complete dishes instead. Keep stable existing IDs for genuinely corresponding recipes; reconcile legacy references safely rather than blindly deleting code.
8. **Other gameplay remains unchanged:** plate-first assembly, one item in hand, preparation states, selected physical storage container, ingredient purchasing in PLANNING (immediate) or SERVING (100-second shipment), +4 base arrivals per successive day, demand-penalty debt, dine-in order deadlines, online deliveries, seven-day cash target. Equipment selling remains **removed from scope** by the later coordinator directive; do not reintroduce it.

## 2. Recipe progression and economy data

`Parts` below means **exactly one** of each listed prepared component, assembled on **one clean plate**, no extras. `Nasi` is cooked rice; `telur`, `ayam`, `sapi`, and `tempe` are fried/cooked; `sayur` is **chopped**. Ingredient IDs remain raw-stock IDs (`beras`, `telur`, `ayam`, `tempe`, `sayur`, `sapi`).

| Unlock day | Stable `recipe_id` | Display name | Exact served components | Dine-in price (IDR) | Price tier | Arrival contribution* |
|---:|---|---|---|---:|---|---:|
| **1** | `nasi_telor` | Nasi Telur | nasi + telur | **20,000** | Cheap | **+3** |
| **2** | `nasi_tempe` | Nasi Tempe | nasi + tempe | **18,000** | Cheap | **+3** |
| **3** | `nasi_ayam` | Nasi Ayam | nasi + ayam | **29,000** | Mid | **+2** |
| **3** | `nasi_telur_tempe` | Nasi Telur Tempe | nasi + telur + tempe | **25,000** | Cheap | **+3** |
| **4** | `nasi_ayam_telur` | Nasi Ayam Telur | nasi + ayam + telur | **35,000** | Mid | **+2** |
| **4** | `egg_salad` | Egg Salad | telur + sayur | **22,000** | Cheap | **+3** |
| **5** | `chicken_salad` | Chicken Salad | ayam + sayur | **30,000** | Mid | **+2** |
| **5** | `nasi_daging_sapi` | Nasi Daging Sapi | nasi + sapi | **38,000** | Mid | **+2** |
| **6** | `nasi_ayam_komplit` | Nasi Ayam Komplit | nasi + ayam + telur + tempe | **45,000** | Expensive | **+1** |
| **6** | `nasi_sapi_telur` | Nasi Sapi Telur | nasi + sapi + telur | **45,000** | Expensive | **+1** |
| **7** | `beef_salad` | Beef Salad | sapi + sayur | **39,000** | Mid | **+2** |
| **7** | `nasi_sapi_komplit` | Nasi Sapi Komplit | nasi + sapi + telur + tempe | **55,000** | Expensive | **+1** |
| **7** | `nasi_gila` | Nasi Gila | nasi + ayam + sapi + telur + tempe + sayur | **70,000** | Expensive | **+1** |

\* **Arrival contribution** applies when the recipe is an **additional selected daily-menu choice** under the first-dish baseline described in §4. It is **not** a guaranteed number of orders for that dish, a probability, or a permanent bonus simply because the recipe has been unlocked.

**Suggested tiers for balancing, not hard-coded classification logic:** Cheap = Rp25,000 or less; Mid = Rp26,000–39,000; Expensive = Rp40,000 or more. Keep `arrival_contribution` explicitly editable **per recipe** (e.g. in `RecipeEconomyEntry`) so changing a price does not silently alter expected arrivals. These prices and Cheap/Mid +3/+2 values are concrete first-pass implementation defaults supplied by this handoff; they require playtesting against raw ingredient costs, typing speed and the Day 7 cash objective. **The expensive +1 rule comes directly from the coordinator.**

### Unlock totals

| Day | Recipes newly unlocked | Total unlocked |
|---:|---:|---:|
| 1 | Nasi Telur | **1** |
| 2 | Nasi Tempe | **2** |
| 3 | Nasi Ayam; Nasi Telur Tempe | **4** |
| 4 | Nasi Ayam Telur; Egg Salad | **6** |
| 5 | Chicken Salad; Nasi Daging Sapi | **8** |
| 6 | Nasi Ayam Komplit; Nasi Sapi Telur | **10** |
| 7 | Beef Salad; Nasi Sapi Komplit; Nasi Gila | **13** |

## 3. Recipe description text and icon binding

These descriptions are **concise gameplay hints**, not additional cooking mechanics. Existing recipes' text may be displayed with automatic line wrapping in the current **Resep** panel. Use the artist's actual PNGs; do not request replacement sprites or invent missing art.

| `recipe_id` | UI `description` (Indonesian) | Supplied dish icon filename |
|---|---|---|
| `nasi_telor` | Cuci dan masak beras, goreng telur, lalu sajikan bersama nasi. | `Nasi-Telur.png` |
| `nasi_tempe` | Masak nasi, goreng tempe, lalu satukan di piring. | `Nasi-Tempe.png` |
| `nasi_ayam` | Masak nasi, goreng ayam, lalu sajikan bersama. | `Nasi-Ayam.png` |
| `nasi_telur_tempe` | Masak nasi, goreng telur dan tempe, lalu satukan. | `Nasi-TelurTempe.png` |
| `nasi_ayam_telur` | Masak nasi, goreng ayam dan telur, lalu satukan. | `Nasi-AyamTelur.png` |
| `egg_salad` | Goreng telur, potong sayur, lalu sajikan tanpa nasi. | `Egg-Salad.png` |
| `chicken_salad` | Goreng ayam, potong sayur, lalu sajikan tanpa nasi. | `Chicken-Salad.png` |
| `nasi_daging_sapi` | Masak nasi, goreng sapi, lalu sajikan bersama. | `Nasi-Beef.png` |
| `nasi_ayam_komplit` | Masak nasi; goreng ayam, telur, dan tempe. | `Nasi-AyamTelurTempe.png` |
| `nasi_sapi_telur` | Masak nasi; goreng sapi dan telur. | `Nasi-BeefTelur.png` |
| `beef_salad` | Goreng sapi, potong sayur, lalu sajikan tanpa nasi. | `Beef-Salad.png` |
| `nasi_sapi_komplit` | Masak nasi; goreng sapi, telur, dan tempe. | `Nasi-BeefTelurTempe.png` |
| `nasi_gila` | Masak nasi; goreng ayam, sapi, telur, tempe; potong sayur. | `Nasi-Gila(Semua ingredients).png` |

**Icon coverage:** 13 distinct recipe icons / 13 recipes, all 32×32 PNG. The ZIPs contain filenames only; the implementation agent must map them to the **actual import locations in the latest repository**, not guess `res://` paths. `plate.png` is the shared plate visual, not an additional recipe.

## 4. Expected customer demand: preserve the existing model, make variety price-sensitive

The previously agreed system has **+4 base expected customers for each successive day** and a persistent customer-demand penalty from failed orders. The prior flat extra-dish bonus of +2 is **replaced** with each additional dish's authored `arrival_contribution`.

For minimal migration from the existing quota model:

```text
base_quota = day_1_base_dinein_quota + (day_index - 1) * 4

# Determine one deterministic baseline recipe among selected dishes:
# lowest unlock_day, with recipe_id as a stable tie-break.
baseline_recipe = first(sort(selected_recipe_ids, by=(unlock_day, recipe_id)))

extra_menu_arrivals = sum(
    recipe.arrival_contribution
    for recipe in selected_recipe_ids
    if recipe != baseline_recipe
)

expected_dine_in_customers = max(
    0,
    base_quota + extra_menu_arrivals - demand_penalty_debt
)
```

- The **first selected recipe provides the normal day's base customer demand**. Every **extra** selected recipe contributes independently according to price category: Cheap **+3**, Mid **+2**, Expensive **+1**. This preserves the old rule that a single offered dish does not get an artificial menu-variety bonus, including on Day 1.
- **Do not rely on click/selection order** to decide which recipe is the baseline. Sort by unlock day and stable ID; this makes the forecast repeatable and prevents switching the order of clicks from changing the number.
- The first-dish baseline is an implementation compatibility convention, **not** a claim that a cheap dish adds zero value. It is simply how the current system avoids double-counting its base demand. If a future approved redesign changes this convention, update the formula centrally.
- `day_1_base_dinein_quota = 4` is the **existing prototype default**, not an irrevocable final balance choice. Keep whatever current data config the repo actually uses unless the developer explicitly applies this handoff's balance set; avoid overwriting unrelated cash/fixture/raw ingredient values.
- Examples with Day 1 base = 4, no failed-order debt:

| Day | Selected daily menu | Base | Extra menu arrivals | Expected dine-in |
|---:|---|---:|---:|---:|
| 1 | Nasi Telur | 4 | +0 | **4** |
| 2 | Nasi Telur + Nasi Tempe | 8 | +3 | **11** |
| 3 | Nasi Telur + Nasi Tempe + Nasi Ayam | 12 | +3 +2 | **17** |
| 7 | Nasi Telur + Nasi Tempe + Nasi Gila | 28 | +3 +1 | **32** |
| 7 | All 13 dishes | 28 | +23 | **51** |

**Important:** The forecast concerns **total dine-in arrivals for that day**, not a separate crowd for each recipe. Adding expensive dishes still increases customer demand, but less than adding cheaper ones. The game can become overwhelming if a player voluntarily selects everything; that is consistent with the project's *Less is More, More is Worse* tension.

### Which dish a diner orders

Keep the existing selected-menu-only, price-biased order selection:

```text
weight(recipe_id) = 1.0 / float(dine_in_price[recipe_id])
normalize weights among selected_daily_menu only
```

This makes inexpensive recipes more frequent among incoming orders. It is **separate from arrival contributions**; never spawn a different fixed group of customers for each dish. Existing order timing, patience, penalties, and per-recipe revenue rules remain unchanged. Online order payment continues to use the existing lower-than-dine-in percentage (70% prototype); no new online demand model is authorized here.

## 5. Ingredient shop unlock behavior

**Trigger:** At the start of each day's **PLANNING** phase, unlock that day's recipes. Derive purchasable raw ingredient IDs from the union of required ingredient IDs across **all recipes unlocked so far**, whether or not the player includes those recipes in today's menu.

| Ingredient (`ingredient_id`) | First purchasable day | Why |
|---|---:|---|
| `beras` | **1** | Nasi Telur |
| `telur` | **1** | Nasi Telur |
| `tempe` | **2** | Nasi Tempe |
| `ayam` | **3** | Nasi Ayam |
| `sayur` | **4** | Egg Salad |
| `sapi` | **5** | Nasi Daging Sapi |

Expected UI/shop rules:

- On Day 1, the raw-ingredient `Belanja` catalog shows **only Beras and Telur**, not six ingredients with unexplained availability.
- Day 2 adds Tempe; Day 3 adds Ayam; Day 4 adds Sayur; Day 5 adds Sapi. All six stay available on Days 5–7.
- The catalog follows **recipe unlock progression**, **not** today's selected menu, storage contents, or ingredient icon file imports. The player may still buy an already-unlocked ingredient even if not used in today's chosen menu; this avoids surprising removal of previously available purchases.
- Preserve clicking/selecting the intended physical storage **container** and its existing capacity checks. Do not change per-slot inventory semantics, auto-spill purchases into other containers, or create separate storage unlock systems.
- **PLANNING:** eligible ingredient purchases arrive immediately. **SERVING:** the same unlocked catalog is available for emergency ingredient purchase, delivered after 100 service seconds, and the service clock keeps running while shopping is open. The phrase "unlocked during planning" refers to **when availability expands**, not a new prohibition on service-phase ingredient shopping.
- UI can simply hide still-locked ingredient entries; no need for new art, padlocks, locked-item descriptions, notifications or tutorials.
- Reject purchases of not-yet-unlocked ingredient IDs in the **authoritative controller**, not merely by hiding UI cards. A direct command/API call must not bypass gating. Existing spend/reservation checks remain atomic.

## 6. Static Resource/data integration (do not hardcode per recipe)

- `RecipeDef` (kitchen-owned static recipe data): stable ID, Indonesian display name, icon binding/key, **short `description`**, exact prepared-part multiset. No custom cooking code for salads or Nasi Gila.
- `RecipeEconomyEntry` (economy-owned static recipe data): same stable recipe ID, `unlock_day`, `dine_in_price`, **`arrival_contribution`**. Default values are in the tables above; keep editable as `.tres` data. If the repository's Resource class uses a different existing field naming convention, follow it consistently instead of creating duplicate parallel fields.
- `RunController`: unlocks recipe IDs at the start of the day; validates player-selected daily menu; derives unlocked ingredients for purchasing; computes a frozen day quota from the selected recipes' attraction values, base/day growth and existing penalty debt.
- `KitchenController`: uses exact ingredient+preparation states from data for plating and serving; adds no recipe-specific branching except lookup. `beras` requires washing then cooking; `telur`, `ayam`, `sapi`, `tempe` require frying; `sayur` requires chopping. Every dish requires a clean plate. Salad recipes contain **no cooked rice**, and don't need a new utensil or salad-specific mechanic.
- `ServiceController`: orders only selected recipes; retains price bias and existing customer/driver deadlines and lifecycle.
- `GameUI`: displays supplied recipe icons and short descriptions when the Resep panel is opened, shows only unlocked recipe choices, updates expected customer count as menu selections change, and hides ingredients not yet unlocked in the current shop catalog.
- **Data changes only as far as practical.** Inspect the newest repository and developer's existing implementation before patching; do not overwrite uncommitted work, revert unrelated asset integrations, mass-rename IDs, or force broad architectural refactors. If these new fields require a small compatible API extension, document it and write focused tests.
- **No audio work is authorized by this recipe handoff.** Audio implementation is planned separately but the coordinator has not finalized the assets/specifications.

## 7. Focused acceptance checks

1. **Day 1:** Exactly one unlocked recipe (`Nasi Telur`). Buying UI shows only raw Beras and Telur. The dish is valid only with cooked rice + cooked egg + one plate; its artwork, price and description appear in the recipe UI. Demand with one selected dish equals base quota after any accumulated debt.
2. **Unlocks:** Day totals are **1, 2, 4, 6, 8, 10, 13**; each newly unlocked dish becomes selectable without a code switch-case. Earlier recipes remain selectable. No auto-add of all unlocked dishes to the active menu.
3. **Ingredient shop:** Day 2 Tempe, Day 3 Ayam, Day 4 Sayur, Day 5 Sapi; not earlier. Direct purchase requests for locked ingredient IDs fail with **no cash debit or stock reservation**. Once an ingredient unlocks it remains purchasable in both planning and service, respecting delivery rules.
4. **Price-dependent crowd bonus:** Adding an extra Cheap dish increases expected customer count by **3**, Mid by **2**, Expensive by **1** before penalty and floor constraints. Changing the order of UI selections does not change expected demand. Check that the customer quota remains fixed after service starts.
5. **Price-biased orders:** If both Nasi Tempe (Rp18,000) and Nasi Gila (Rp70,000) are selected, Nasi Tempe is chosen more frequently over many deterministic sampled orders. No order references an unlocked-but-unselected dish.
6. **Preparation:** `nasi_ayam` takes cooked rice + cooked chicken **without tempe**; the two `komplit` dishes use the respective chicken/beef + egg + tempe combinations. Egg/Chicken/Beef Salad require **chopped vegetables and the corresponding cooked protein, without rice**. `nasi_gila` uses **all six prepared components** (rice + chicken + beef + egg + tempe + chopped vegetables). An incorrect, incomplete, extra-component, or raw plate must not serve.
7. **Assets/UI:** All **13** icons resolve to existing imported PNGs; no new recipe artwork required. Descriptions wrap in the existing Resep panel without clipping. The same recipe IDs consistently drive icon/name, availability, price and cooking validation.
8. **Economy regression:** Preserve ingredient costs and other configuration unless separately approved. Run at least a short seeded/day-7 balance check for cheap-only, mixed, and full-menu selections; log clearly if the target becomes trivially easy or impossible. Do not falsely claim prices are playtest-balanced.
9. **No unrelated regressions:** Existing stock slot capacity, delivery refund behavior, plate conservation, online prices, day transitions, cash accounting, and no-equipment-sale scope remain unchanged.

## 8. Required implementation-agent response

Report (a) the current repo revision actually inspected; (b) which existing Resource/controller/UI files already match this spec and which need additions; (c) the minimal data migrations and code changes necessary; (d) any conflicts with the latest uncommitted work (if accessible); and (e) tests actually run. If acting as the documentation-only Work agent, deliver a concise developer-ready `.md` or narrowly scoped ZIP without modifying the development repository. If directly implementing with authorization, modify only necessary files and preserve unrelated work.

**No additional game mechanics, new art requirements, or permanent economy constants should be inferred from this brief.**
