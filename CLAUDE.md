# Ketik Saji — instructions for Claude Code

Godot 4 **2D**, **GDScript**, Windows/Linux mouse+keyboard, Indonesian player-facing text. Jam theme **“Less is More, More is Worse”**. One code owner: this Claude Code session working with the team's developer. This is a **72-hour jam**; finish a working game before adding polish. Art/UI assets are produced by teammates; use stable-ID placeholders until they arrive.

## Authoritative documents and precedence

1. Coordinator's new explicit decision (confirm before altering settled design).
2. `docs/SHARED_BASELINE.md` — confirmed design rules and constraints.
3. `docs/ARCHITECTURE.md` — **canonical frozen interface and state-ownership contract**.
4. `docs/systems/01_INTERACTION_KITCHEN.md`, `02_SERVICE_ORDERS_CUSTOMERS.md`, `03_PLANNING_ECONOMY_PROGRESSION.md`, `04_UI_FEEDBACK_LOCALIZATION.md` — detailed focused implementation.
5. `docs/IMPLEMENTATION_PLAN.md` — milestones and gates; `docs/ACCEPTANCE_TESTS.md` — expected behavior.
6. `docs/CONTENT_AND_TUNING.md`, `docs/DECISION_REGISTER.md` — pending recipe/art input, editable tuning and explicit reversible defaults.
7. `docs/PROGRESS.md` — progress/status; not a substitute for actual code inspection.

**Do not automatically import all documents into this file.** At the beginning of each milestone, read `docs/ARCHITECTURE.md`, the relevant system doc(s), the current milestone section and existing affected code; read other docs when an interface is implicated. Do not use unmodified earlier Agent A–E source handoffs (superseded).

## Implementation rules

- Implement **one named milestone at a time**, then validate and update progress. Do not silently invent gameplay content (four+ future recipes are planned but not supplied), add new features or redesign the typing mechanic. Raise only true blocking ambiguities; for local technical details use the minimal documented reversible default.
- **Screen-space:** latest sketch shows left persistent UI band → separate visible world dine-in waiting lane → restaurant to right. Planning panels may temporarily cover world; service HUD stays left. World clicks and typed station focus still work after any camera/offset adjustment. `docs/WORLD_LAYOUT_AND_VIEWPORT.md` is authoritative for layout direction, with exact coordinates still scene-authored.
- **Single state authority:** root phase/service clock; Kitchen item/plate/storage/input; Service dine-in/online/orders/drivers/tables; Run cash/menu/fixtures/debt; UI display/input focus only.
- **No autoload service locator, generic ECS, factory framework, extra global timer, save system, workers or utility upgrade tree.** Use Godot Resource `.tres` definitions for ingredients, recipes, fixtures and tunable economy; runtime inventory/plates/orders must not mutate static data.
- **Input:** click floor teleports only; click object teleports to cardinal neighbor AND activates same click; typing Indonesian exact valid prefixes autoexecutes full word without Enter. One B command parser. No gameplay clicking through shop modals. Shopping **does not pause clocks**.
- **Online:** station accepts `terima`, accepted **physical driver** at one of **3** spots (overflow FIFO) receives `saji`; outside driver not serveable. New acceptance stops when **unspawned diner count <=2**; concurrent cap = initial day quota, not 3.
- **End day:** auto-close only when unspawned diner quota, outside diners, inside diners (including eating), AND OPEN online orders are all zero. Cancel/refund pending 100s shipments once, clear food except raw fridge stock, reset plates/tables, charge fixed daily electricity once. Seven-day goal compares cash **after** electricity.
- All financial/order/plate/delivery actions validate first and are **once-only by ID**. Signal UI after commit, not as the mechanism for money or dish consumption. Test interrupts, failed commands and repeated callbacks.
- Additional recipes are **data additions** (`RecipeDef.tres` + economy/unlock entry + icon), not new code branches. Do not cap progression at 3 by design or generate unapproved recipes. Call out unavailable content in progress report.

## Work session protocol

1. Inspect `docs/PROGRESS.md`, Git status, actual scene/code and chosen milestone acceptance tests.
2. State a short file-level plan; implement only the milestone; keep names/contracts consistent with `docs/ARCHITECTURE.md`.
3. For temporary art, use clearly named placeholders and authored scene marker IDs. **Read `docs/WORLD_LAYOUT_AND_VIEWPORT.md` and view `references/current_screen_layout_NON_BINDING.png` in Milestone 0**. Block out the persistent left UI area, adjacent in-world diner waiting lane and right restaurant first; include independent online pickup/overflow locations. Do not keep outdated 10×9 geometry or interpret the new sketch as exact tile coordinates. 640×360 logical resolution is only a fit-test candidate.
4. Validate import/parse when Godot executable exists: `godot --headless --path . --import` (or platform's `godot4` executable); run playable scene and specific manual tests where GUI is required. No claim of passing a test that wasn't run.
5. Show changed files, verified behaviors, errors and remaining content dependencies; update `docs/PROGRESS.md` with done/current/next and decisions. Commit a clean milestone in Git when developer approves. Prefer fresh Claude Code sessions between milestones if context becomes cluttered; use project docs/Git for continuity.

**First task:** Follow `docs/IMPLEMENTATION_PLAN.md` Milestone 0; do not attempt the whole game in one prompt.
