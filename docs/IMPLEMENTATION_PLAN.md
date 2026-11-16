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

### Milestone 5 — Complete seven-day loop and recipe data pipeline

**Read:** D + A + C + B. Wire seven automatic days and RESULTS Continue, Day 7 comparison **after electricity**, WON/LOST latch and optional EXTRA mode. Author remaining of the **three confirmed recipes** (including chop vegetable for `nasi_komplit`) and verify recipe definitions driven by `.tres` not code branches. Implement validation for missing future recipe entries/icons and warnings; add supplied coordinator-authored Days 4–7 recipe definitions when they arrive, without changing serving algorithms. No fabricated content. Add comprehensive system regression tests with mock time/seed/config.

**Acceptance:** Simulate seven days quickly with test clock, compare cash at goal and one below; bad choices are allowed to fail. Extra mode only after win. New `RecipeDef.tres` + economy entry + icon lookup works without modifying B/C script. Commit.

### Milestone 6 — UI/art swap, playtest, bug fixes, export (protect final jam time)

**Read:** E + acceptance checklist; re-check B/C/D critical flows. Integrate pixel/UI art by ID, preserve click hitboxes; ensure the **latest rough world composition** (left HUD / in-world diner lane / restaurant / separate driver spots) fits at the chosen 32px-based logical viewport; no old 10×9 assumption. E ghost typing, rings and local error feedback; side result panel and Indonesian text. Play one full run manually, tune economy `.tres` with actual human typing pace, test low/high menu/online strategies and hard-but-winnable target. Verify audio/polish only if core works. Export Windows/Linux as supported; test launch on target hardware.

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
