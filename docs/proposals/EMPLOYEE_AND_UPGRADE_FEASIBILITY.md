# Employee System & Equipment Upgrade Feasibility Audit

> **Status: PROPOSED BUT NOT IMPLEMENTED**
>
> This document is an architectural and game-balance feasibility audit only. No employee hiring UI, wage deduction, employee simulation, or equipment upgrade tiers have been implemented in Ketik Saji gameplay, economy data, or scenes as part of the Story & Tutorial task.

---

## 1. Asset Inspection: `res://assets/art/characters/pegawai.png`

Verified by direct Godot `Texture2D` / `Image` inspection and `.import` metadata check (`res://assets/art/characters/pegawai.png.import`):

| Property | Observed Value | Comparison / Notes |
| --- | --- | --- |
| Texture Path | `res://assets/art/characters/pegawai.png` | UID: `uid://btbdutwct48ot` (`CompressedTexture2D`) |
| Dimensions | `14 × 31` px | Matches scale of `player.png` (`16×32`), `npc gojek.png` (`16×31`), and `npc 1.png`–`npc 7.png` (`14–16 × 30–32`) |
| Pixel Format | `Image.FORMAT_RGBA8` (`5`) | 434 total pixels: 92 transparent (`a == 0`), 342 opaque (`a == 255`), `0` partial-alpha pixels (crisp 1-bit pixel transparency) |
| Spritesheet / Animation | **No** (single static sprite) | No horizontal/vertical frame grid or directional walk poses |
| Import Settings | `fix_alpha_border=true`, `mipmaps/generate=false` | Consistent with all existing crisp 2D character sprites |
| Current Engine Binding | `@export var employee_texture: Texture2D` on `WorldMap` | Bound in `scenes/world/restaurant_world.tscn`; asserted by `tests/test_world_hierarchy.gd`; zero runtime employee NPC nodes instantiated |

**Asset Implications:** Because `pegawai.png` is a single `14×31` static frame, spawning an animated walking employee would either require reusing idle bobbing/slide interpolation (similar to `PlayerVisual`) or commissioning/slicing directional walk frames.

---

## 2. Proposed Role & Behavioral Design (Employee System)

To reinforce the competition theme **"Warung Kebablasan: Sedikit Menu, Banyak Cuan?" / "Less is More, More is Worse"**, employees should act as **bounded specialists with coordination friction**, never free "auto-win" autopilot:

- **Option A — Kasir / Pelayan Meja (Waiter / Busser Helper, Recommended):**
  - Can collect dirty plates from `DIRTY` tables and deposit/wash them at `Wastafel`, and optionally deliver already-plated finished dishes from `Meja Kerja` (`work_table_stage`) to waiting `OCCUPIED_WAITING` tables or `AT_PICKUP_SPOT` drivers.
  - **Cannot** choose menu items, buy ingredients, accept/reject `terima` online offers, cook on stoves, chop `sayur`, or assemble recipes.
- **Option B — Juru Masak Stasiun (Station Prep Helper):**
  - Assigned to one single station (e.g., washing dirty dishes OR grilling/frying raw items staged on `Kompor`).
  - Narrower scope; less collision risk than full pathfinding.

---

## 3. Hiring & Cost Model

To mirror real warung overhead (like electricity on fridges), hiring should carry both an upfront and recurring drain owned strictly by `RunController`:

- **Hiring Cap:** Maximum 1–2 employees (`employee_cap = 2`) unlockable starting Day 3+.
- **Upfront Contract / Recruitment Fee:** e.g., `Rp 25,000` (one-time per hire during `PLANNING`), non-refundable if fired mid-week.
- **Daily Wage (`upah_pegawai`):** e.g., `Rp 12,000`–`Rp 18,000` per hired employee per day, deducted at settlement alongside `Listrik Harian` and reported as a distinct line item in `DayResultSidePanel`.
- **Economic Tension ("More is Worse"):** On low-menu, low-volume days (Days 1–3, ~4–6 customers), hiring a helper guarantees a **net profit drop** because wages outweigh marginal extra serves. Hiring only breaks even if throughput bottlenecks are genuinely high AND ingredients/kitchen flow stay supplied.

---

## 4. Automation Boundaries & Anti-Snowball Safeguards

Without strict limits, automation turns a typing time-management game into an idle clicker. Safeguards required before implementation:

1. **Typing Core Preserved:** Cooking triggers (`cuci`, `masak`, `goreng`, `potong`), ingredient picking (`beras`, `telur`, etc.), menu strategy (`Edit Menu`), and online acceptance (`terima`) remain manual player typing decisions.
2. **Finite Service Speed:** Employee movement and task execution must be slower than an optimal player (e.g., `1.8–2.5` tiles/sec, `1.5–2.0x` station action time) so players still beat automation on skill.
3. **No Magic Teleporting or Infinite Reach:** Employee interacts on real tile coordinates and occupies kitchen lanes (blocking or squeezing past the player causes mild congestion if the kitchen is overcrowded with extra equipment).
4. **Idle Wage Penalty:** Employees still draw full daily wage even on slow days, reinforcing that adding staff without real demand destroys margin.

---

## 5. Architecture Fit & File Ownership Plan

Respecting `docs/ARCHITECTURE.md` ownership rules (zero new autoloads):

| Layer / Owner | Proposed Responsibility (Not Implemented) |
| --- | --- |
| `scripts/economy/economy_config.gd` & `data/economy_config.tres` | Static tuning exports: `employee_hire_cost`, `employee_daily_wage`, `employee_unlock_day`, `employee_max_count`, and upgrade tier tables. |
| `scripts/economy/run_controller.gd` | Authoritative roster state (`hired_employees`), hire/dismiss validation in `PLANNING`, daily wage deduction in `settle_day()`. |
| `scripts/kitchen/kitchen_controller.gd` | Bounded AI task state machine (`IDLE -> WALKING -> ACTING`) sharing the existing tile walkability map and lock checks to prevent race conditions with player hand/station state. |
| `scripts/world/world_map.gd` | Instantiate runtime visual sprite nodes using the existing `employee_texture` (`pegawai.png`) export and clean position tweening. |
| `scripts/ui/game_ui.gd` & `scenes/ui/game_ui.tscn` | Planning-only Hire/Manage action inside HUD/shop modal, wage breakdown line inside `DayResultSidePanel`, and Day 3+ one-shot `FeatureTipPanel` onboarding. |

---

## 6. Equipment Upgrade Feasibility

As an alternative or complement to buying multiple identical appliances (`+Alat` slots), existing fixtures could support bounded **Level 1 -> Level 2** upgrades in `PLANNING`:

- **Penanak Nasi (`rice_cooker`) Upgrade:** Faster cook duration or slightly larger batch (`5 -> 7` portions), at higher daily `kWh` electricity charge.
- **Kompor (`stove`) Upgrade:** Faster sear/fry speed, higher electricity fee.
- **Wastafel (`washer`) Upgrade:** Faster dishwashing duration, water/utility surcharge.
- **Kulkas / Rak Piring:** Already partially served via additional slot purchases (`fridge_a`/`fridge_b`, `rack`); upgrading slots directly should remain mutually balanced with `+Alat` slot fees so neither becomes strictly dominant.

**Verdict on Upgrades vs. Employees:** Equipment speed upgrades carry **dramatically lower pathfinding/race-condition risk** than autonomous moving employees and reinforce the same electricity/overhead tradeoff already proven in Ketik Saji.

---

## 7. Interaction With Existing Constraints

- **Online Offers (`P5-B`):** Employees must **never** call `terima`; online orders remain limited by `Antrean Datang <= 2` cutoff, open-order concurrent cap (`4`), and explicit player risk acceptance.
- **Demand Debt (`P5-C` / `P5-F`):** Employees cleaning dirty tables faster reduces dine-in seating stalls, which would otherwise lower `penalty_debt` — wage costs must therefore offset freed dine-in capacity so Day 7 target (`Rp 700k`) stays challenging rather than trivial.
- **Storage & Plates:** Existing plate pool and storage slot constraints stay authoritative; employees respect existing `PlatePool` exhaustion (`no_plates`).

---

## 8. Testability & Economy Simulation Plan

Before any future release includes employees or upgrades:

1. **Unit & Conflict Tests:** Extend headless tests to assert simultaneous player + employee interaction on the same table/washer/work_table never duplicates plates, deletes ingredients, or bypasses phase locks.
2. **Simulation Matrix (`tests/test_p5_simulation.gd` & `tests/test_p5g_fair_economy.gd`):** Run full 7-day chronological simulations comparing:
   - Lean Menu + Zero Employees
   - Lean Menu + 1 Employee
   - Bloated Menu + 2 Employees ("Warung Kebablasan")
   Confirming that **bloated staffing/menu still underperforms focused management**, preserving `"Less is More, More is Worse"`.
3. **Budgeted Visual Verification:** Capture live rendered screenshots verifying `pegawai.png` layering, Y-sort depth with tables/counters, and wage rows inside `DayResultSidePanel`.

---

## 9. Risks & Edge Cases

- **Double-Claim Race Condition:** Player and employee clicking/targeting the same `DIRTY` table or `WASHER` on the same physics tick must resolve atomically via `KitchenController` claim locks.
- **Pathfinding Deadlock / Lane Blocking:** Narrow kitchen aisles (with `+Alat` slots filled) could trap moving employees unless employees pass cleanly through the player tile without solid tile locks.
- **Early-Run Insolvency:** Hiring an employee on Day 2 before securing cash reserves can trap players into negative daily margins with recurring wages if dismissing isn't allowed cleanly between days in `PLANNING`.
- **Session State Scope:** As with current tutorial flags, any persistent multi-run unlock metadata would require an explicit save layer (currently out of scope).

---

## 10. Final Phased Recommendation (**PROPOSED BUT NOT IMPLEMENTED**)

Given the upcoming Windows playable release window:

1. **Current Release (v1.0 — Implemented):** Ship without employee runtime AI or upgrade tiers. Keep `pegawai.png` documented as an unused pre-bound `WorldMap` asset and complete all Story/Tutorial onboarding cleanly inside Presentation (`GameUI` + `NarrativeTutorialCatalog`).
2. **Post-Release Phase 1 (Low-Risk Overhead Expansion):** Consider bounded **station upgrades** (`Kompor` / `Wastafel` speed tier with higher electricity bill) first, validated against `test_p5g_fair_economy.gd`.
3. **Post-Release Phase 2 (Full Employee System):** Introduce the **Waiter/Busser role** (`pegawai.png` + idle-only movement or commissioned walk sheet) with atomic `KitchenController` claim locks, `PLANNING` hire/fire UI, daily wages in `RunController`, and full 7-day economic matrix verification.
