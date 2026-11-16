# Ketik Saji — developer handoff ZIP (integrated architecture v2.1)

Prepared 2026-11-15. This ZIP is the **revised and reconciled** version of the A–E agent outputs, not the original conflicting raw handoffs. It incorporates all five recent coordinator decisions **and the newest screen-space sketch (left UI + waiting lane + restaurant)**. The game is a 2D Godot 4 Indonesian typing/cooking restaurant jam game themed **“Less is More, More is Worse”**. One developer uses Claude Code to implement a playable, polished game within 72 hours; the coordinator owns game design, art comes from teammates.

## Quick start for the developer

1. Copy/extract this package's files into the **Godot project root** (or keep in a temporary planning folder until `project.godot` is initialized). `CLAUDE.md` must be at the Claude Code working-directory root.
2. Initialize `project.godot` / Git if needed. Tell Claude Code: **“Read CLAUDE.md and docs/IMPLEMENTATION_PLAN.md; implement Milestone 0 only. Read docs/ARCHITECTURE.md and related system docs. Validate and update docs/PROGRESS.md.”**
3. After each milestone, inspect the actual game, review changes, test the listed acceptance criteria and commit. Never send Claude all five original unedited agent outputs alongside these revised specs.
4. During playtest, tune cash, recipes/prices and demand using `.tres` data; request **actual future recipe definitions/icons** from coordinator. Placeholder assets and map markers are acceptable for initial integration. **Render the new left-UI/right-world composition during Milestone 0**, before finalizing camera/viewport/area hitboxes.

## Files by responsibility

| File | Use |
|---|---|
| `CLAUDE.md` | Compact permanent Claude Code instructions, no auto-loaded giant imports |
| `docs/ARCHITECTURE.md` | Canonical scene, single-state-owner matrix, exact cross-system method contracts, clock/close/transaction order |
| `docs/SHARED_BASELINE.md` | Confirmed gameplay rules and intent; prevails over implementation proposals |
| `docs/DECISION_REGISTER.md` | Which decisions are confirmed, technical freezes, and reversible playtest defaults |
| `docs/systems/01_INTERACTION_KITCHEN.md` | Movement, typing, food aggregates, storage, plates, work table, deliveries |
| `docs/systems/02_SERVICE_ORDERS_CUSTOMERS.md` | Dining customer queues, 100s/20s, online drivers/3 pickup spots, 60s and close |
| `docs/systems/03_PLANNING_ECONOMY_PROGRESSION.md` | Cash, menu, initial kit, purchases/resale, daily electricity, demand penalty, Day 7 |
| `docs/systems/04_UI_FEEDBACK_LOCALIZATION.md` | Indonesian world-first UI, typed prompts, preview/driver/delivery rings, menu/store/results |
| `docs/IMPLEMENTATION_PLAN.md` | One-milestone-at-a-time build sequence; test gates |
| `docs/ACCEPTANCE_TESTS.md` | Cross-system regression checklist before release |
| `docs/CONTENT_AND_TUNING.md` | Recipe intake template, editable balance/asset unknowns; **not gameplay blockers** |
| `docs/PROGRESS.md` | Developer's persistent status and handoff |
| `docs/REVISION_TRACE.md` | Exactly what A–E needed changed and which coordinator answers resolved it |
| `docs/WORLD_LAYOUT_AND_VIEWPORT.md` | Latest screen-space composition, Godot UI/world coordinates, dedicated left UI region, fit checks |
| `references/current_screen_layout_NON_BINDING.png` | **Newest** reference sketch (replaces old one), not a locked tilemap or pixel blueprint |

## Design/implementation versus content readiness

- **Architecture:** The five central ambiguities have been answered and reflected in all revised specs. Exact technical contracts are frozen *for the first implementation pass* to stop Claude from choosing incompatible alternatives.
- **Content:** Three recipes currently fully described. Coordinator has **plans for more** and wants the unlock mechanism expandable with `.tres`; later recipe data/icons and specific art/fixture coordinates must still arrive. Claude should not make them up. A 7-day prototype can use the current loaded recipes for testing, but a final release claiming 7 new daily unlocks needs the missing approved recipe assets/entries.
- **Balance:** Some money values and counts are provisional sample `.tres` config, **not approved tuning**. Playtesting is expected and the game may intentionally become unwinnable from bad investment decisions.
- **No Godot project/source code is included.** This is a developer implementation specification, not a completed playable game or validated engine build. *(Historical handoff note from 2026-11-15; for current implementation status see `docs/PROGRESS.md`.)*

## New layout constraint (v2.1)

The **latest** sketch is now the visual direction: a reserved persistent left UI strip, visible dine-in waiting lane immediately beside it in the world, and restaurant playfield on the right. The drawn world looks approximately 13×9 cells, but **do not hardcode that size**. Kitchen upper / seating lower is a rough organizing principle; purchasable utility and table slots are still scene-authored. Online drivers require three actual pickup spots and separate overflow space **not yet labeled on the sketch**. 640×360 logical / 1280×720 window remains an **unverified candidate**; planning panels may overlap world when open, but ordinary service HUD should stay in the left strip. Implement a fit test using colored placeholder zones first. `docs/WORLD_LAYOUT_AND_VIEWPORT.md` contains exact QA requirements.

## Highest-risk integration tests

Verify one dish with typed mouse/keyboard actions; physical online driver spot + overflow; selected container shopping (no service pause); finite plate transfer to diner vs direct online clean return; same-tick deadline/delivery/close; and the 7th-day **cash after power** result. These are specified in `docs/ACCEPTANCE_TESTS.md`.
