# C — Dine-in Service, Online Orders, Drivers & Tables (revised v2.0)

**Owner:** `ServiceController`. Reconciles Agent C v1.0 with later coordinator-approved Agent E physical online drivers, latest end-of-day guard and online concurrency rule. The kitchen handles physical clicks and plates; the economy handles cash and demand debt. No additional order UI rail, manual shop close, cooldown or NPC AI simulation.

## 1. Runtime records / single owner

```
ServicePlan input: day_index; day_queue_initial; selected_recipe_ids;
  dine_in_price_by_recipe; installed_table_ids        # D-owned immutable snapshot
Customer: customer_id; order_id; state OUTSIDE_WAITING|SEATED_WAITING|EATING|LEFT;
  table_id_or_empty; arrived_at; eat_until (if eating)
Order: order_id; kind DINE_IN|ONLINE; recipe_id; status OPEN|COMPLETED|FAILED;
  customer_id_or_empty; driver_id_or_empty; deadline_at; result_recorded
Table: table_id; state CLEAN_VACANT|OCCUPIED_WAITING|OCCUPIED_EATING|DIRTY;
  customer_id_or_empty
OnlineOffer: preview_recipe_id; offer_generation_number; NOT an Order
Driver: driver_id; order_id; state AT_PICKUP_SPOT|OUTSIDE_DRIVER_QUEUE;
  spot_id_or_empty       # deadline is in that order, not another driver clock
Queues: day_queue_initial; day_queue_remaining; outside_dine_in_fifo;
  active_in_shop_customers; online_orders_open; outside_driver_fifo;
  pickup_spot_to_driver [exactly 3 authored pickup IDs]
```

C issues unique `customer_id`,`order_id`,`driver_id` per run/day (prefix day + counter), and owns *all* order outcomes. E snapshots show live `seconds_remaining = max(0,deadline_at-now)`; no UI decrements counters. **Day queue** means unspawned quota, decremented exactly once on actual spawn; **outside dine-in FIFO** contains already spawned people and never affects online cutoff. **Driver FIFO** is a separate third queue and never occupies physical diner tables.

## 2. Spawn, seating, patience and dirt state machine

- At `begin_service(now=0)`, if quota >0 spawn **first diner at t=0**, then at t=20,40,... until quota exhausted; catch up due spawns if a long frame occurs; each catch-up customer's `arrived_at`/`deadline_at` must be based on its **scheduled spawn time** (0,20,40...), not all reset to current render-frame time. First spawn decrements `day_queue_remaining` once. Each diner picks **one recipe** from D-selected daily menu, using simple initial `weight = 1 / dine_in_price` (TUNING, cheaper dishes more likely). Validate positive prices and known menu. Start **100-second deadline from spawn** even if no clean table is available.
- If any CLEAN_VACANT table exists, assign first stable ID table and `SEATED_WAITING`, link that order to table. Otherwise append diner to **outside_dine_in_fifo**, `OUTSIDE_WAITING`, and continue their existing deadline. When a CLEAN_VACANT table becomes available, admit earliest not-expired outside customer; do NOT reset patience or reduce day queue. Invalid/stale queue entries removed before seating. Tables hold **one** diner each. A diner who has failed while waiting/seated leaves without generating dirty plate or cleaning requirement.
- To serve, B typed `saji` on selected diner table calls `try_serve_table(table_id,held_item_id)`; C verifies SERVING, table `OCCUPIED_WAITING`, exact order OPEN, `now < deadline_at`, correct table/ID and B valid **plated** exact dish. B's single `try_consume_serving_item(...,DINE_IN,table_id)` transfers same plate to customer table. C marks `COMPLETED` once, stops patience deadline, transitions `EATING`, sets `eat_until = now + 20`, calls D `credit_order_once` once. No acceptance of second serve during EATING. E's customer icon switches from order+100s ring to eating+20s ring.
- After eating 20 seconds, diner leaves. C table becomes DIRTY until physically clicked/typed `bersihkan`; B moves associated unique plate ID into unbounded washer once; only then C changes table to CLEAN_VACANT and admits first outside waiter. The table does **not** auto-clean while someone waits outside. C owns table dirt state; B owns plate registry.
- If OPEN order hits `now >= deadline_at` (exact 100s), mark FAILED exactly once, remove outside waiter or free occupied table **clean** if unserved (no meal/plate); record unique failure ID for D. No cash deducted directly. Repeated timeout callbacks/status checks do nothing. A rejected wrong serve never stops timer or consumes item.

### Dine-in transition table

| State | Event | Next and side effect |
|---|---|---|
| UNSPAWNED | spawn at 0/20/... while day queue >0 | 1 unique diner/order created, day queue -1, 100s deadline begins |
| NEW | clean table available | SEATED_WAITING, selected table occupied |
| NEW | no clean table | OUTSIDE_WAITING FIFO, timer unchanged |
| OUTSIDE_WAITING | table clean or timeout | seat FIFO customer / FAILED and leave (no plate) |
| SEATED_WAITING | correct `saji` before deadline | COMPLETED, EATING 20s, one plate bound, one cash credit |
| SEATED_WAITING | timeout | FAILED, leaves table clean, one demand-debt event |
| EATING | 20s elapsed | LEFT, table DIRTY (plate remains B-owned) |
| DIRTY | valid typed `bersihkan` | B plate→washer once, table CLEAN_VACANT, admit first outside diner |

## 3. Online station and **physical drivers**

- The online **station** displays one stable unaccepted preview icon from today's menu, no deadline and no driver. Player physically selects station and types `terima` to accept when allowed. A preview never fails or causes a penalty. On acceptance, C creates one **ONLINE OPEN** order with independent `deadline_at = now+60` and one `driver_id` linked to that order, then draws next preview if still eligible.
- **Acceptance predicate** (all required, CONFIRMED): `phase == SERVING`, `day_queue_remaining > 2`, `online_orders_open.size() < day_queue_initial` and selected menu nonempty. Concurrent cap is the **initial** dine-in quota, not `3` and not total lifetime online acceptances. Three physical pickup spots are **separate**. No additional cooldown/limit. An accepted order remains active after cutoff until fulfilled or timed out.
- On driver creation: occupy lowest stable-ID free of **three** authored pickup markers; if full, add to **outside_driver_fifo**, keep driver sprite/icon/ring in visible side area. Driver deadline starts at acceptance regardless of spot. **Only** a driver with `state=AT_PICKUP_SPOT` can receive food. Overflow drivers are not serveable, even if holding matching food and clicking them. A click on an in-spot driver must select its **actual `driver_id`**, and B's completed `saji` calls C `try_serve_driver(driver_id,held_id)`; **never** serve at acceptance station and never choose order via hidden UI list.
- `try_serve_driver` validates SERVING, actual driver **AT_PICKUP_SPOT**, own OPEN order with `now < deadline_at`, correct exact plated recipe. C asks B `try_consume_serving_item(..., ONLINE, &"")`: same plate returns clean immediately; C sets COMPLETED once, asks D to credit lower online price once, frees driver/spot and advances earliest still-live overflow driver. There is no eating, diner seat, table dirtying, or washer mutation.
- If online deadline reaches `now>=deadline_at` at a spot **or outside**, mark FAILED once and remove driver from its spot/FIFO. Promote oldest still-open queued driver into freed spot **without resetting** the 60s deadline. Update E views. Online missed accepted order contributes same single 50/50 missed-order debt class as failed dine-in.
- If acceptance cutoff happens with online orders still open, station disables **new** `terima` but accepted drivers remain serveable until terminal outcome. Driver views hold `driver_id`, `order_id`, `recipe_id`, `spot_id`, state, seconds remaining and `can_serve`. Online preview offer is never included in `online_orders_open`.

### Example: spot overflow

Given day quota 6, 3 empty pickup spots and 4 accepted online orders before the `day_queue_remaining<=2` gate, the first 3 drivers are at spots; fourth enters visible outside-driver FIFO with its own countdown. If first at-spot driver is completed, its actual plate returns clean and the outside driver moves to freed spot with **original remaining time**, now serveable. If the waiting driver expires **before** entering, it fails once, disappears, and is never serveable. The fact that online cap is 6 in this example permits 4 OPEN orders; physical spot count is not a cap.

## 4. Full service time and auto-close

C receives monotonic `now` from GameRoot; **does not create per-order Timer nodes**. When advancing, create all due diner spawns, expire all OPEN orders with `deadline_at<=now`, resolve all eating departures with `eat_until<=now`, admit FIFO to freed clean seats, update driver occupancy and report. All event callbacks check order/customer/driver current state and unique IDs. At exact expiry time, serve attempts lose; do not let input `saji` revive a timed-out record. UI panels including `Belanja` do **not** pause C or B timers. C's `is_drained()` only after due events in tick, and is true iff:

```
 day_queue_remaining == 0
 AND outside_dine_in_fifo is empty
 AND in_shop_dine_in_count == 0 (includes EATING)
 AND online_orders_open is empty
```

**Important:** Dine-in waiting list is distinct from not-yet-spawned quota; an empty shop at t=20 while 5 arrivals remain **never** closes. If final physical diner leaves while accepted online driver still pending, **continue SERVING**; the order either completes or its 60s expires before close. A `CLOSING` barrier freezes further outcomes; C snapshots immutable report; B refunds still pending shipments; D settles. Dirt/unwashed plates/deliveries do not count in guard. C emits the close eligibility notification once per day or GameRoot polls `is_drained()` after time update—use **one** route, not duplicate triggers.

## 5. Order distribution and next-day disappointment debt

- D prepares `ServicePlan`: quota and selected IDs/prices, installed dining table IDs. C draws only among those IDs; **cheaper dishes more likely**, proposal `weight(recipe)=1/float(dine_in_price[recipe])` for positive integer prices and stable seeded RNG. One dish/order; same recipe may occur on multiple orders. D alone decides initial quota: confirmed **+4 arrivals per successive day**, adjusted by configurable menu-variety bonus and accumulated demand debt, floor at zero. C does not know ingredient costs, fixture prices or cash.
- C captures unique `failed_order_ids` for both dine-in and **accepted** online orders. D applies 50/50 per failed order `demand_penalty_debt += 1 or 2` once at settlement, persists to next-day quota; a zero-failure perfect day decreases existing debt by 1 (floor 0), including a zero-arrival day as explicit reversible default. No cash penalty and no immediate game over. Do not reroll penalty on repeated settlement. Wrong serve attempt with timer still live is not itself a failed order.
- C immutable close report: `{ day_index, arrived_dine_in_count, initial_dine_in_quota, completed_order_ids, failed_order_ids, completed_dine_in_count, failed_dine_in_count, completed_online_count, failed_online_count }`. D credits order revenue at serve time, not again from report. Each report/close called at most once logically.

## 6. Interfaces, UI views, and implementation boundaries

See `../ARCHITECTURE.md` §5 for exact method names. C public serving methods are **target-specific** `try_serve_table(table_id,item_id)` and `try_serve_driver(driver_id,item_id)`, NOT ambiguous `try_fulfill_order` with a separately UI-selected order. Both share internal order validation and B's **one** destination-aware consume call. `try_accept_online_offer()` called on typed `terima` at station; `try_clean_table(table_id)` calls B plate transfer before C dirt mutation. E reads fresh `OrderView`, `TableView`, `CustomerQueueView`, `DriverView`, `OnlineOfferView`; C never copies UI timer numbers back into orders.

Minimum views:

```
OrderView: order_id, kind, recipe_id, status, seconds_remaining,
  customer_id_or_empty, table_id_or_empty, driver_id_or_empty
QueueView: day_queue_initial, day_queue_remaining, outside_dinein_count,
  in_shop_count, online_open_count, outside_driver_count
TableView: table_id, state, customer_id_or_empty, order_id_or_empty
DriverView: driver_id, order_id, recipe_id, state, spot_id_or_empty,
  seconds_remaining, serveable, world_anchor_id
OnlineOfferView: preview_recipe_id, acceptance_enabled, disabled_reason,
  online_open_count, concurrent_limit
```

Godot-specific: driver `Area2D` objects relay a stable ID to **B**'s router; C never duplicates input focus or movement. Purchase/sale of dining fixture happens planning-only through D, with C registering/unregistering table occupancy state; C rejects removal if not safe. `Signals` are redraw notices only (`orders_changed`, `queues_changed`, `tables_changed`, `drivers_changed`, `online_offer_changed`). All state mutation direct and synchronous.

## 7. Acceptance tests

1. Dine-in quota 4: spawn at service 0,20,40,60; each decrement unspawned exactly 1, including waiting outside. No second t=0 spawn. Zero quota immediately drains unless an online OPEN exists (cannot newly accept at quota zero).
2. One table, 2 customers: A seated at 0, B outside at 20 with 100s timer; A misses at 100, leaves seat clean; B seats with 20s remaining, fails at 120 if unserved (timer not reset). Neither generates a dirty plate.
3. Correct `saji` at matching table only consumes exactly one plated dish and credits exactly one payout; customer eats 20s, table becomes DIRTY, `bersihkan` queues exactly one dirty plate. Wrong recipe/wrong table/duplicate order never consumes/credits.
4. Accepted online driver t=10 has t=70 expiry (60s). It occupies first free pickup spot. Accepted fourth driver when 3 occupied goes to outside FIFO and cannot be served. When spot empties, oldest live overflow advances without timer restart. Duplicate accept/resolution does not duplicate driver or payment.
5. Offer visible at station with no timer/driver. `terima` in station accepts; `saji` in station does not. Clicking a particular at-spot driver and typing `saji` fulfills its own order only; matching food given to different driver rejects.
6. Online gate: with quota remaining 3, acceptance allowed subject to concurrent cap; next diner spawn reduces it to 2 → disable new offers, keep existing accepted drivers. Concurrent cap uses day **initial** quota, not 3 pickup spots nor outside diner count.
7. Accepted driver still OPEN after last diner leaves → SERVING continues; only after its fulfillment/timeout C reports drained. No premature shipment cancellation or electricity settlement.
8. At t>=deadline two repeated timeout checks mark only one FAILED ID. Price-weight test over seeded 1000 samples favors cheaper dish without inventing customer classes.
9. Demand miss from dine-in/accepted online only affects **next** D plan, with seeded 1/2 roll and perfect-day debt reduction; no UI-derived duplicate lost-customer penalty.
10. Long service frame crossing multiple spawn times creates required number with correct due times/IDs (not one per frame); all UI rings sample true C `now`-derived remaining time.
