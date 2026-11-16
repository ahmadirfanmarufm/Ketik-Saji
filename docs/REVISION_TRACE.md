# Source-to-revised-agent reconciliation trace (v2.1 layout addendum)

Reviewed **actual** uploaded outputs: Agent A Architecture & Foundation v1.2, Agent B Interaction/Kitchen v1.1, Agent C Service/Orders v1.0, Agent D Planning/Economy v1.0, Agent E UI v1.1; baseline v1.0; and prior cross-agent audit/reconciliation package. This pack retains their confirmed behavior but **does not contain their outdated unedited full texts**. Primary technical descriptions have been rewritten as `docs/ARCHITECTURE.md` (A) and `docs/systems/01..04` (B–E) to eliminate contradictory API alternatives. No developer should implement from older originals.

## Five coordinator confirmations added now

| User answer | New authoritative cross-system effect |
|---|---|
| **1. More recipes planned, only 3 currently made** | RecipeDefs + economy unlock entries + icon lookup data-driven. No three-recipe permanent cap and no invented Day4–7 dishes. Content intake in `CONTENT_AND_TUNING.md`. |
| **2. Buy and sell fixtures planning-only, immediate; safely removable** | A phases and D fixture ledger, B/C registration, E slot-first buy/click-to-sell reflect immediate purchases/sales, including table sets. No delayed fixture queue. |
| **3. Same washer for rice and plates, same work/prep table for chopping** | B contextual `cuci`; same physical prep fixture with separate typed-chop and click-staging targets to prevent conflicting gestures. D starting kit unchanged; E prompts context-aware. |
| **4. Online cap meaning confirmed** | C concurrent OPEN accepted online cap = initial dine-in quota; 3 physical pickup spots plus outside overflow distinct, lifetime accepts uncapped within opening cutoff. |
| **5. Shopping does not pause** | A single root service clock always advances in SERVING; B deliveries/C order deadlines run; E modal blocks input only. |

## Prior already-approved cross-agent contract corrections preserved

| Conflict from original specs | Canonical correction |
|---|---|
| A physical-only close vs C C-07 | A/C/D/E now use four-clause close guard including accepted online OPEN; removed A-OPEN-02. |
| A/baseline distinct *ingredient types* vs B confirmed storage slots | B and D enforce 2×3 fridge, 3×5 box slots, duplicate ingredients allowed across slots; E displays actual slots. |
| C/B old `saji` at online station vs E's coordinator-confirmed drivers | Station `terima` only; C owns actual drivers, 3 spots and outside FIFO; B routes exact driver clicks; E renders views. |
| A two-arg food consumption vs B/C finite plate destination | ONE B 4-arg `try_consume_serving_item(item_id,recipe_id,kind,table_id)`, no duplicate second plate-record method. Dine-in binds table; online returns plate clean. |
| A/B purchase calls without selected storage unit vs D/E chosen container | Full D→B quote/reserve/receive/schedule API includes `storage_unit_id`. All-or-nothing, no spill; shipments/refund by purchase ID. |
| B work tables vs C diner tables | Dedicated kitchen staging/chopping, one item per work surface; diner table is only seat/serve/clean, no food staging. |
| Two possible timing designs scattered across A/C | ONE GameRoot monotonic service time and due timestamps. No parallel Godot Timer nodes. Technical choice for deterministic testability, not new gameplay. |
| Tentative UI viewport 640×360 seen as required by some | Explicit **fit-test proposal** only. The then-current 10×9 assumption was **subsequently superseded** by v2.1’s newer composition; 32px art remains confirmed, final framing depends on actual layout/assets. |

## Open content and reversible defaults, not missing architecture

- `nasi_telor`, `nasi_ayam`, `nasi_komplit` are only currently approved recipe contents. Remaining dish content and distinct icons must come from coordinator/artists; data pipeline prepared. Final recipe text/naming/word tokens may be localized through one catalog.
- Starting cash, Day7 target, prices, power fees, base daily arrival count, online 70%, resale 50%, 4 plates/rack, recipe-breadth bonus and viewport: **editable playtest parameters**. The only hard gameplay time/count values are separately marked CONFIRMED.
- Plate survival after trash, gifted-fixture resale at zero, cooker output capacity one, zero-arrival perfect-day recovery and extra-mode no new target are **documented reversible defaults**, not misrepresented coordinator-approved facts.

## Integration release gate

- [x] Five coordinator answers included.
- [x] One canonical owner of every runtime ledger and one public method catalog.
- [x] Four-clause auto close, physical online driver fulfillment, container-selected stock API, plate disposition cross-domain alignment.
- [x] A/B/C/D/E newly revised docs align conceptually with canonical architecture.
- [x] Developer root instructions, milestone plan, progress template, content intake and cross-system tests generated.
- [ ] New Godot project/runtime implemented and tested — **developer's work, not performed by architecture editor**.
- [ ] 4+ future recipes, final art, exact balance and world placement supplied/verified during production.

## Latest coordinator visual update — v2.1 (after A–E reconciliation)

The new rough screen-space image, `references/current_screen_layout_NON_BINDING.png`, **supersedes** the earlier `rough_layout_NON_BINDING.png`. Coordinator's visual direction reserves a persistent left UI band, shows an adjacent in-world **dine-in waiting lane**, and places restaurant kitchen/dining play to the right. The mockup seems approximately 13×9 grid tiles including the waiting lane, but this is **not** a frozen scene size, locked station-count requirement or layout coordinate map. The previous fixed **10×9** assumption is removed from authoritative guidance.

Integrated into `docs/SHARED_BASELINE.md`, `docs/ARCHITECTURE.md`, UI domain, implementation Milestones 0 & 6, acceptance tests, `docs/CONTENT_AND_TUNING.md`, `docs/DECISION_REGISTER.md`, `CLAUDE.md`, and `docs/README_START_HERE.md`. Added `docs/WORLD_LAYOUT_AND_VIEWPORT.md` as the sole focused layout/viewport guide and replaced reference image. The UI band doesn't change customer/service ownership, driver capacity, timing, or click-to-teleport rules. Three physical online pickup spots and an independent outside driver queue still must be placed and shown, though the sketch doesn't mark them. The 640×360 / 1280×720 proposal remains provisional pending actual fit testing.
