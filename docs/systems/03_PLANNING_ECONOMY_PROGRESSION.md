# D — Planning, Money, Fixtures, Menu Unlocks, Demand & Deadline (revised v2.0)

**Owner:** `RunController`. Reconciles Agent D v1.0 and coordinator answers: **fixture buying/selling planning-only, immediate**, chosen-container ingredient ordering, seven-day deadline, future recipe data intake rather than three-recipe cap. This is a light economy, not a market simulation. One developer/Claude Code; 72h. All numeric values under `TUNING` are editable and **not coordinator-approved**.

## 1. Starting run, planning and menu

Confirmed Day 1 physical equipment is **1 storage box (3×5 raw slots), 1 stove/kompor, 1 wastafel washer, 1 plate rack, 1 rice cooker, 2 diner tables with chairs**, plus a free map-provided work/prep table (staging + chopping) and trash. The washer can wash rice or one dirty plate by context. Start with this set at no cash debit; its fixture IDs are owned by D and operational handles registered with B/C. **Proposed** no initial purchased ingredient stock; actual starting cash TUNING. No save/load. Win target is current **cash after Day 7 end-of-day electricity**, not gross sales or net worth.

PLANNING:

1. D exposes unlocked `RecipeDef` IDs and previously selected menu. User selects **one or more unlocked authored dishes**; D validates no unknown/duplicate recipe and keeps a consistent daily plan. Different dishes have different prices (defined in economy entries). More selected dishes increases expected arrivals per configurable variety bonus, but expands cooking/stock workload; fewer have smaller quota. Data-defined menu selection is the strategy.
2. Ingredient ordering starts from a **specific physical box or fridge** via the same container `Belanja` UI as service. D checks funds and asks B if selected unit can reserve the *whole* raw-stock quantity. In PLANNING accepted stock arrives immediately; no ingredient can be taken/prepared until service begins. In SERVING `Belanja` accepts an emergency purchase but arrival is exactly **100 service seconds** later. Service continues while shopping UI is open. Purchasing never spills to another storage unit.
3. Clicking an empty authored equipment/dining-table slot opens applicable fixture choices; purchase with confirmation **immediately** debits and creates the purchased fixture. Clicking owned fixture in PLANNING opens resale with lower price and confirmation; safe removal unregisters physical instance and frees slot **immediately**. **No fixture purchase/sale during SERVING**, no deferred fixture-delivery subsystem. Table/chair sets also safely resellable per latest coordinator answer. Equipment has **no upgrade tiers**; buying more units only.
4. Start Service button: D validates nonempty selected menu and required plan prerequisites, computes a frozen `ServicePlan`, then A transitions to SERVING. All cash, fixtures and menu selections freeze except emergency **ingredient** purchases and payments from served orders.

## 2. D-owned state and Godot `.tres` data

```
RunController:
 day_index: int (1..7, 8+ optional)
 cash: int (IDR integer, may go negative *after electricity*)
 unlocked_recipe_ids, selected_recipe_ids: Array[StringName]
 fixture_instances: instance_id -> {def_id, slot_id, actual_price_paid, starter_grant}
 purchase_ledger: purchase_id -> {type, raw_ingredient_id, quantity,
    selected_storage_unit_id, paid_amount, status PENDING|DELIVERED|REFUNDED}
 credited_order_ids: Set[StringName]                 # once-only service credit
 settled_day_ids: Dictionary[day_index, SettlementView] # once-only fee/debt
 demand_penalty_debt: int >=0
 main_day_7_outcome: UNDECIDED|WON|LOST
 extra_mode_active: bool

EconomyConfig.tres (all TUNING unless duration confirmed):
 starting_cash: int; day_7_cash_target: int;
 day_1_base_dinein_quota: int;
 arrival_increment_per_day: int = 4;   # CONFIRMED model, editable knob
 extra_arrivals_per_extra_selected_menu: int;
 online_sale_percent: int (suggested 70);
 fixture_resale_percent: int (suggested 50);
 plates_per_rack: int (suggested 4);
 price lists for raw ingredient, dine-in dish, fixture purchase and fridge/cooker
 fixed daily electricity; unlock_day per recipe_id;
 optional seeds and test durations (NOT live balance modifications)

IngredientDef.tres: ingredient_id & display; B-owned preparations
RecipeDef.tres: recipe_id, display, icon key, required-part multiset; B-owned
RecipeEconomyEntry: recipe_id, unlock_day, dine_in_price; D-owned
UtilityDef.tres: fixture_id, category, purchase price, electricity/day, plates/rack
World slot metadata: slot_id, allowed fixture category, tile anchor; A scene data
```

All `.tres` definitions are **static data**, never mutated per runtime item. Recipes can be added by creating a new `RecipeDef.tres` and a matching recipe economy/unlock/icon entry. B/C must reference IDs, not an exhaustive switch over `nasi_telor`, `nasi_ayam`, `nasi_komplit`. The coordinator plans at least **four more** recipes to realize a new unlock on every Day 1–7. Those definitions/icons are **CONTENT PENDING**, not developer permission to invent them. Currently only these are authored: `nasi_telor`, `nasi_ayam`, `nasi_komplit`. Their proposed unlock schedule Day 1/2/3 is **TUNING/PROVISIONAL** until later content is added. Do not silently say Day 4–7 unlock nothing *by design*; expose a clear missing-content warning during authoring.

## 3. Fixture instance lifecycle and resale

| Fixture type | Physical behavior authority | Money and placement | Daily electric charge |
|---|---|---|---|
| Storage box (3×5) | B storage slots, overnight empty | D owns fixture & authored slot | none |
| Fridge (2×3) | B storage, raw carryover | D | fixed per installed fridge |
| Kompor / stove | B instant cooking | D | none by confirmed rules |
| Wastafel | B contextual rice washing/dirty plates | D | none |
| Rice cooker | B instant washed rice→cooker output→take rice | D | fixed per installed cooker |
| Plate rack | B grants `plates_per_rack` reusable unique plate IDs | D | none |
| Dining table+chair | C one clean seat/dirty state | D | none |
| Kitchen work/prep and trash | B fixed, map-owned/unpurchased | Not part of purchasable catalog | none |

A purchase is one synchronous `request_fixture_purchase(fixture_id,slot_id)` transaction: PLANNING only, compatible EMPTY authored slot, funds, D record, B/C/world operational registration, charge once, UI update. On any failed preflight **no debit**; if unexpected registration fails restore owner record and cash without leaving an invisible paid fixture. No placement slot is invented from rough sketch. Item/utility count in scene follows installed instance IDs, not a separate UI manager.

Sale: `request_fixture_sale(fixture_instance_id)` PLANNING only, owned instance exists, safety checks passed, unregister B/C state and visual, free slot, credit less than original purchase cost exactly once. **Safely removable** includes empty storage with no reserved delivery; plate rack with its own plates returned clean and otherwise unreferenced; diner table with no customer/dirt (always at planning after reset); any stove/cooker free of day-local work (reset). Cash resale = `floor(actual_price_paid * fixture_resale_percent / 100)` (implementation default); **starter granted fixtures with `paid_amount=0` yield 0 cash**, preventing free starter-fixture resale. This still lets players deliberately sell an essential fixture and make the run unplayable; do not add rescue grants. If coordinator later chooses a different starter resale policy, change this *one* config/formula. Selling a fixture cannot create/destroy B raw stock or owned reusable plate IDs outside validated lifecycle.

## 4. Ingredient money/selected-container transaction

Accepted `request_ingredient_purchase(ingredient_id,quantity,storage_unit_id)` is legal in PLANNING or SERVING only. `quantity` positive, selected unit owned/installed and of type BOX or FRIDGE, raw ingredient valid, `cost=quantity*unit_buy_price <= cash` for purchases, B physical destination capacity must accommodate **entire** order plus already reserved amounts. D creates unique purchase ID, B reserves exact capacity in **that** unit, D records paid price/destination and debits once. In PLANNING B `receive_stock(...)` immediately fills same unit; in SERVING B `schedule_delivery(... due_at=now+100.0)`. A 100s delivery is not instant and cannot be withdrawn early. Capacity is not combined between units; fridge can store 6 units of a single raw ingredient using both its 3-unit slots, box 15 using 3×5.

On CLOSING B identifies still-PENDING paid shipments and releases B capacity, D `refund_canceled_deliveries_once(ids)` returns recorded original paid cost once, marks REFUNDED. Previously delivered stock expires if in box (or carries in fridge) but never refunded. A shipment committed by B at a clock tick **before** close is DELIVERED; it isn't refunded even if immediately cleared at boundary. D never trusts a client-supplied refund amount. Avoid phantom charge/refund from double clicks or repeat signals.

## 5. Demand, order pricing, failure debt

D constructs `day_queue_initial` at Start Service from selected menu and day progression. Coordinator-confirmed base growth **+4 extra expected dine-in customers each day**; absolute Day 1 count and selected-menu demand bonus TUNING. Safe default formula:

```text
base_quota = day_1_base_dinein_quota + (day_index - 1) * arrival_increment_per_day
menu_bonus = max(0, selected_recipe_ids.size() - 1) * extra_arrivals_per_extra_selected_menu
quota = max(0, base_quota + menu_bonus - demand_penalty_debt)
```

Table count **does not automatically multiply quota** in initial model (default extra_table_bonus=0), because C already models customer waits/patience/available seats. This preserves genuine downside to expanding menu while not requiring new spawn mechanics. Quota is fixed for day; C first diner t=0, then +20s and price-biased one-dish orders. Positive dine-in prices are provided by D to C. Online order payout is *less* than dine-in, starting sample `floor(dine_in_price * 70 / 100)`; exact percent TUNING. No separate online menu or mandatory online quests.

At a completed serve, C asks `D.credit_order_once(order_id,recipe_id,kind)`; D looks up frozen daily dish price, credits once, records ID and informs E. C report later does not duplicate order revenue. A failed order causes **no immediate cash deduction**, but one persisted future demand penalty entry. C reports unique failed dine-in/accepted online IDs; at settlement, for each unique ID D seeded 50/50 chooses **1 or 2** and adds to `demand_penalty_debt`, applied only starting next day's forecast. If **no order failed**, D reduces debt by **1** (floor 0), perfect-day recovery, once. Zero-arrival/zero-failure day counts as perfect by reversible default. No “save doomed run” bailout. Balance after daily power can be negative; prevent spending money you don't have while planning/serving.

**Dine-in dish weights** (C sampling, D provides prices) start as inverse price `1.0 / dine_in_price`, editable if playtests require; D does not generate orders or choose random recipes itself. Different menu prices and ingredient costs allow profitable/risky trade-offs, but **balancing is playtest work**.

## 6. End-of-day electricity, deadline, optional extra

1. Root waits for **four-way** C drained guard including accepted online orders; no manual close. B cancels pending shipments, D refunds exact paid amounts, B clears nonfridge food/reset plates, C resets people/dirty tables, D then settles.
2. Charge fixed expense for **every installed fridge and rice cooker at close**, including starter cooker, regardless of activity: `electricity = sum(installed_fixture_def.daily_electricity_cost)`, no fluctuating metering/on/off and no other current utility charge. Deduct exactly **once per day**. Setting negative cash is allowed; spending requests still reject if unaffordable.
3. Add debt from C report or recover 1 for perfect day (once). Show finance and next-day demand estimate via D settlement view, not UI calculation.
4. At **end of Day 7**, compare **current cash AFTER power** to configured `day_7_cash_target`. `>=` is WON, `<` LOST; no gross revenue interpretation. This can be hard or mathematically unwinnable after bad decisions; intentional. Only WON can optionally choose Day 8 extra mode; preserve Day 7 victory latch. **Default extra mode has no second compulsory cash deadline**, because only extra days (not new targets) were approved. If team later chooses a new target, that is new design work, not a default invention.

## 7. Sample editable TUNING values (NOT approved balance)

| Key | Suggested prototype value | Scope |
|---|---:|---|
| `starting_cash` | Rp100,000 | TUNING |
| `day_7_cash_target` | Rp700,000 | TUNING |
| `day_1_base_dinein_quota` | 4 | TUNING |
| `arrival_increment_per_day` | 4 | CONFIRMED increment, editable |
| `extra_arrivals_per_extra_selected_menu` | 2 | TUNING |
| `online_sale_percent` | 70 | TUNING, must pay less than dine-in |
| `fixture_resale_percent` | 50 | TUNING, strictly less than buy |
| `plates_per_rack` | 4 | TUNING |
| `rice_cooker_electricity_per_day` | Rp2,000 | TUNING |
| `fridge_electricity_per_day` | Rp4,000 | TUNING |
| `nasi_telor_dinein_price` | Rp20,000 | TUNING |

Ingredient prices, other recipe prices, fridge/table/stove/rack/box fixture costs, map slot caps and starting menu remain in one config/data table. Seed workable prototype defaults, **do not claim these are balanced or final**. Use Godot Resources to change them without code. One test session should cover 7 days with low/medium/high expansion strategies and actual typing pace.

## 8. One owner and handoff contracts

Public methods, signature types and views are frozen in `../ARCHITECTURE.md` §5. B is sole physical stock/delivery authority; C sole order/result/queue authority; D sole cash/menu/demand/fixture ownership; E only shows read-only snapshots. `ServicePlan` includes positive selected prices/quota/installed table IDs, not ingredient counts. `ServiceDayReport` includes unique completed/failed IDs, not cash credits. D informs B/C when fixtures appear/disappear and ensures a single purchase instance ID. No duplicate money singleton, production planning UI model, hidden Day 7 emergency fund, or data generation for pending future recipes.

`RunView` minimum: `{day_index,cash,day_7_target,goal_outcome,unlocked_recipe_ids,selected_recipe_ids,installed_fixtures,demand_penalty_debt,planned_dinein_quota}`. `DaySettlementView` minimum: `{day_index,begin_cash,ingredient_purchase_total,fixture_purchase_total,fixture_sale_total,order_revenue_dinein,order_revenue_online,refund_total,electricity_charge,end_cash,completed_dinein_count,completed_online_count,failed_dinein_count,failed_online_count,penalty_debt_before,penalty_debt_after,forecast_next_day,day7_outcome}`. These are snapshot records from authoritative ledgers and C report; already credited service money must not be counted as another end-day deposit. Consider fixture buy/sale totals absent in service reports as ledger-derived.

## 9. Tests: plan → service → Day 7

1. Boot exact starter kit, no boot-time purchase debit; PLANNING prevents retrieval/cook, allows selected container `Belanja`, authoring menu, slot-first fixture purchase/sale. Service fixture shop rejects. Starter sale generates zero money by documented default.
2. Fixture buy: valid slot, enough money → instance appears immediately, one debit. Second purchase into occupied slot rejects without debit. Fixture sale allowed only during PLANNING when safe; removes operational instance, frees slot, credits **less** than originally paid. Stocked fridge/rack with outstanding plate rejects if cannot remove safely.
3. Ingredient box A selected, box B free: buy 6 ayam into A, fills `[5,1]`; B untouched. Select full A and try more: reject whole purchase without cost. 100s reservation prevents future overflow. Purchase during SERVING never pauses deadlines/UI.
4. Received 100s shipment remains charged and its box stock expires at close; pending at close canceled/refunded exactly once. A refund never applies to delivered shipment; stale UI purchase ID does not create cash.
5. With unchanged menu/debt, quota rises +4 per day (configurable); additional menu option adds configured bonus; C draws only selected recipe IDs and cheaper bias. Only `.tres` authored IDs appear/unlock, Day 4–7 entries are content pending, not fabricated.
6. Two unique failures (dine-in and accepted online) roll independent seeded -1/-2 debt, no direct cash debit; a later no-failure day restores 1 debt once. Repeated `settle_day_once` doesn't reroll/charge twice.
7. One valid dine-in serve credits exact selected price once; online serves at data-defined smaller percent; single `order_id` paid once even after reload of views and duplicate notifications.
8. Day 7 ending with cash exactly equal to target after cooker/fridge fees **wins**; 1 rupiah short **loses**. Bad planning may leave run unwinnable and should not trigger rescue/grant. Only win offers optional extra mode.
9. Purchasable recipe definitions can be extended from 3 to 7 via new Resources, economy entries and art icons with **zero script edits to kitchen validation, customer order distribution or menu rendering**. Missing definitions fail validation with developer warning, not a silently fabricated dish.
