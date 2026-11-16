# Ketik Saji — Godot 4 / GDScript Coding Standards

**Version:** 1.0 · **Date:** 2026-11-15 · **Audience:** sole developer and Claude Code  
**Placement:** save this file as `docs/CODING_STANDARDS.md` in the Godot project.  
**Status:** implementation practices and quality gates; **not a replacement for the game's architecture or rules**.

> **One-minute rule:** Implement the smallest correct piece of the current milestone, keep exactly one owner for each gameplay state, use typed and readable GDScript, verify the real behavior, and stop. Do not introduce a new abstraction just because it is a common software-engineering pattern.

## 0. Authority, scope, and priorities

These standards were prepared against the **Ketik Saji v2.1 developer handoff**, not a generic Godot project. This is a **72-hour, 2D, Indonesian-language restaurant typing game jam** for Windows/Linux. One developer uses Claude Code; two pixel artists and one UI artist supply assets. The target is a finished playable game, not a reusable restaurant-simulation engine.

**Precedence, highest first:**

1. Latest explicit coordinator decision.
2. `docs/SHARED_BASELINE.md` — game design.
3. `docs/ARCHITECTURE.md` — **frozen state ownership, scene tree, time model, public APIs and transactions**.
4. `docs/systems/*.md` — domain details; `docs/WORLD_LAYOUT_AND_VIEWPORT.md` — current screen composition.
5. `docs/IMPLEMENTATION_PLAN.md` and `docs/ACCEPTANCE_TESTS.md` — milestone gates.
6. **This file** — coding style and implementation discipline.

If an example here conflicts with a canonical method name or behavior, **use `docs/ARCHITECTURE.md` and flag the discrepancy**. This file must not silently introduce a gameplay rule, manager, clock or API.

**Priority levels:**

- **P0 — required:** compiling/launching code, one state owner, correct contract, correct input/clock/transaction behavior, no duplicated assets/orders/plates/cash, milestone testing.
- **P1 — strongly expected:** readable typed interfaces, consistent names, small functions, useful errors, testable deterministic behavior, clean Git history.
- **P2 — only if cheap:** strict lint rules, automated formatting, exhaustive unit tests, additional helper classes, advanced profiling, generic tools.

Do not spend the last jam hours refactoring working code merely to satisfy P2.

## 1. Pin the Godot version; avoid version-dependent guesses

- At project creation, record the **actual Godot 4.x editor version** used by the developer in `docs/PROGRESS.md` (or a project note). Use that same minor version for testing and exporting when possible.
- Use **GDScript**, not C#, JavaScript, Python, or GDExtension. Do not introduce third-party dependencies without a specific demonstrated blocker and coordinator approval.
- When looking up engine APIs, consult the **matching Godot version's documentation**, not the `latest` unstable docs by default. Verify APIs like typed `Dictionary` syntax, scene/node APIs and input callbacks against the installed version.
- Prefer engine-native `Node`, `Node2D`, `Area2D`, `Control`, `CanvasLayer`, `TileMapLayer`, `Resource` and `RefCounted` where appropriate. Use custom code only for game rules not already provided by the engine.

**Do not upgrade the engine mid-jam** simply to gain a convenience API.

## 2. GDScript syntax and naming conventions

Follow the official [Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), with these project-specific decisions:

| Element | Rule | Example |
|---|---|---|
| File / folder | `snake_case`, lowercase | `kitchen_controller.gd` |
| Registered class / node name | `PascalCase` | `KitchenController`, `DriverPickupSpots` |
| Function / variable | `snake_case` | `try_serve_driver()`, `order_id` |
| Private helper / field | leading `_` | `_find_valid_neighbor()` |
| Constant | `SCREAMING_SNAKE_CASE` | `MAX_STORAGE_SLOTS` |
| Enum / enum member | `PascalCase` / `UPPER_CASE` | `OrderKind.ONLINE` |
| Signal | `snake_case`, preferably past tense | `orders_changed`, `phase_changed` |
| Static logical ID | stable `StringName` | `&"nasi_telor"` |
| Visible Indonesian text | separate display data | `"Nasi Telor"`, `"bersihkan"` |

Formatting:

- **Tabs** for GDScript indentation; **UTF-8 without BOM**, **LF line endings**, newline at file end.
- One statement per line; blank lines between separate operations; use `and`, `or`, `not` rather than symbolic alternatives.
- Aim for lines under 100 characters, without unnatural splits. Follow Godot's declaration order: optional `class_name`, `extends`, doc comment, signals, enums/constants, exports, state, `@onready`, callbacks, public methods, private helpers.
- Prefer early-return guards to deep nesting. Avoid one-line `if` statements and five-level `match` trees.
- Add a short `##` doc comment on externally called functions where inputs, ownership or failure semantics are non-obvious. Don't comment obvious operations line by line.
- **Don't rename the canonical public methods, signals or IDs** to make them stylistically prettier.

Example of acceptable shape (illustrative, not a replacement for the actual controller):

```gdscript
class_name ExampleOrderView
extends RefCounted
## Small read-only-ish value carrier for UI presentation.

var order_id: StringName = &""
var recipe_id: StringName = &""
var seconds_remaining: float = 0.0
```

Only create such a class if the frozen interface requires it or it prevents real duplicated logic. The existing public interfaces typically return `Dictionary` snapshots.

## 3. Type boundaries, but don't fight GDScript

**P0:** Use explicit argument and return types on **cross-controller public methods** and important signal arguments, matching `docs/ARCHITECTURE.md` exactly. Use `-> void` on procedures and `-> bool` for validated actions.

**P1:** Type persistent state and clear local values, using either annotations or safe inference:

```gdscript
var _balance: int = 0
var _selected_target_id: StringName = &""
var _player_tile: Vector2i = Vector2i.ZERO
var _order_ids: Array[StringName] = []
var _service_elapsed: float = 0.0
```

- `var value := expression` is fine when the inferred type is unambiguous; prefer `var value: int = ...` when it clarifies a money/count variable.
- Use built-in numeric types deliberately: `int` for money, ingredient quantities, counts, IDs' sequence numbers; `float` for service time and due timestamps; `Vector2i` for grid coordinates; `Vector2` for canvas/world pixel positions.
- `StringName` represents stable IDs. Keep strings for displayed Indonesian copy, user-entered command text and UI feedback.
- Prefer `Array[StringName]` / `Array[Dictionary]` where supported. `Dictionary` is acceptable for small named snapshots or ID-indexed runtime records; don't insist on typed dictionaries if the installed Godot version doesn't support the desired syntax.
- Do not store unrelated meanings in one magical `Variant` or rely on array indices like `order[7]` for fields that should be named.
- Avoid `as` casts everywhere. Check external data once at the boundary, then operate on known types.
- Static typing is a tool to catch errors; it should not generate a forest of custom DTO classes or serialization code in a three-day game.

## 4. Do not change the canonical system architecture

The agreed runtime owners are:

| Component | Owns and may mutate |
|---|---|
| `GameRoot` | phase, the **one** `service_elapsed` clock, start/close/settle sequence |
| `KitchenController` | teleport/target/typing prefix, held food, prep, storage, plates, deliveries |
| `ServiceController` | customers, dine-in queues, orders, online drivers, three pickup spots, deadlines and table dirt |
| `RunController` | money, menu/unlocks, equipment ownership, purchases/refunds, customer penalty debt, Day 7 goal |
| `GameUI` | presentation, widget state and focus only |

**Never add** a second money manager, plate inventory, global order store, input command parser, driver manager with duplicate ownership or separate game clock. Do not create an Autoload/service locator/event bus/ECS/DI container. The root wires known controllers directly.

Controller-to-controller **mutations** use the frozen direct calls; UI change signals are emitted **after** success and notify presentation. The signal itself must not cause a payment, item consumption or settlement.

World nodes (fixtures, drivers, table sprites, click hitboxes) carry stable IDs and visuals. Their existence must not become a second authoritative record of orders, currency or stock. For instance, a driver node can display `driver_id`; its order deadline lives in `ServiceController`.

**One-way truth rule:** The controller owns the value; other systems receive a fresh view or validated method call. Never return internal mutable maps or objects that callers can modify to bypass validation.

```gdscript
# Example: a D-owned read view, not a second wallet.
func get_run_view() -> Dictionary:
	return {
		"day_index": _day_index,
		"balance": _balance,
		"cash_target": _cash_target,
	}
```

If view data contains nested collections, construct fresh nested data or intentionally copy them. A shallow dictionary copy is **not** protection if it still holds mutable `Object` references.

## 5. Scene and node references

- Keep the `GameRoot` tree from `docs/ARCHITECTURE.md`. `@onready` references to direct known children are fine; don't create global lookups just to avoid a short path.
- Give each station, fixture slot, work-table hitbox, dining table and driver pickup marker a **stable explicit ID**. Don't infer IDs from child index, sprite texture, display text or exact pixel coordinates.
- Build small scenes for independently repeated **visual/interactive objects**, such as a station or customer, but do not make every logical record a full scene if a simple kitchen/service record is enough.
- `NodePath`/node references are scene wiring, not persistent gameplay IDs. If a node may be deleted during a transaction or day transition, validate it is still present before visual access; don't make authoritative state depend on the sprite remaining alive.
- Connect a signal **once**, during scene initialization. If the connecting scope can run repeatedly, guard against multiple connections. Disconnect or clean up short-lived subscriptions as needed.
- Keep placeholder shapes/hitboxes working when artists replace sprites. Validate click positions after texture-scale or viewport changes.
- For scene-authored layout, follow `docs/WORLD_LAYOUT_AND_VIEWPORT.md`; **no hardcoded 10×9 level**, and the new image is a reference, not exact coordinates.

**Use one world click router.** Don't accidentally process the same mouse press in `Area2D.input_event` *and* `_unhandled_input` to activate two targets. Prefer appropriate `Control` filters to make real UI consume its own events.

## 6. Pure game rules before visual effects

Keep these three layers conceptually separate (without inventing extra frameworks):

1. **Input/request:** world click, typed character, menu purchase button.
2. **Validated state mutation:** controller method decides and commits a change.
3. **Presentation:** signal/view updates sprite, icon, sound or popup.

Critical mutations are **synchronous**. Do not use `await` for:

- spending/refunding money;
- removing or merging ingredients;
- plating/serving;
- advancing an order state;
- moving dirty plates to washer;
- ending a day and charging electricity.

A small animation may run **after** the state has changed; its completion must not be necessary for money/order integrity. Keep delayed delivery and customer deadlines in their respective due-time records, not animation delays.

### Validation order (P0)

Every mutating request should follow the same pattern:

1. Check phase and valid selected context/target ID.
2. Check deadlines, availability, inventory capacity, affordability and other preconditions.
3. Check duplicate transaction ID / already terminal order status.
4. Make the smallest complete synchronous commit.
5. Emit change signals / show feedback **after** commit.

If a multi-owner operation needs a later step (selected-container reservation → payment → shipment), prepare and revalidate all steps first; if a synchronous step fails, restore the initial state in the same call. Don't implement a generic rollback engine.

**Exactly-once behavior is mandatory** for order credits, item consumption, physical plate movements, ingredient deliveries, refunds, electricity and day advancement.

```gdscript
# Private implementation example only, not an additional canonical public API.
func _credit_validated_amount_once(order_id: StringName, amount: int) -> bool:
	if _credited_order_ids.has(order_id):
		return false
	if amount < 0:
		push_error("Invalid order credit: %s" % order_id)
		return false

	_balance += amount
	_credited_order_ids[order_id] = true
	run_state_changed.emit()
	return true
```

The **real** public entry remains `RunController.credit_order_once(order_id, recipe_id, order_kind)` as defined by the frozen architecture; D determines the approved amount internally.

## 7. Timer, randomness, and ordering rules

**Critical existing choice:** Do **not** instantiate separate per-customer or per-shipment `Timer` nodes. The canonical root maintains **one floating-point service clock**, advanced only in `SERVING`. Each order, diner, spawn event and ingredient shipment stores an **absolute `due_at`** in the root's service-time coordinate system.

- At each tick, root advances clock, then Kitchen processes due deliveries, Service processes spawns/expiry/eating/admission, then root checks closure. Preserve this ordering.
- Service starts with the first diner at `t=0`, then spawns every **20 seconds** according to that day's quota. When a large `delta` skips multiple spawn points, catch up all scheduled arrivals, assigning their scheduled timestamps, not the delayed frame timestamp.
- **100s** dine-in patience starts at **spawn** (including outside waiting), **60s** online deadline starts at acceptance, served diner **eats 20s**, in-service deliveries arrive at **100s**. These are canonical game values; use test-only clock injections for fast tests, not secretly shortened live timers.
- A service attempt at `now >= due_at` loses to expiry. A timeout cannot resolve an order twice.
- Shopping modals do **not** pause service time. PLANNING, CLOSING, RESULTS and FINISHED do not advance it.
- Pending deliveries are refunded only if **still pending at actual close**; already committed arrivals are not refunded.

For randomized order choice and 1-or-2-customer penalties, use the responsible controller's `RandomNumberGenerator`. A fixed **test** seed makes regressions reproducible. Do not randomize inside UI code. Don't change an established customer's food choice when their icon redraws. A repeated settlement call must not reroll the penalty.

## 8. Typed-word and mouse input correctness

Typing is the game's identity; it is not a substitute for an ordinary interaction button.

**Kitchen owns the single command-prefix parser.** A typed character is accepted only if it extends an allowed command at the selected target; an invalid character leaves the current accepted prefix unchanged; a completed valid word autoexecutes without Enter. Clicking elsewhere clears the prefix.

Input implementation rules:

- Use `InputEventKey` and its character/unicode fields for typed words; non-text keys such as Backspace/Escape should follow the approved B behavior. Ignore key-repeat (`event.echo`) and irrelevant modifiers where appropriate.
- If a GUI modal has keyboard focus, do **not** send that key to Kitchen; if Kitchen consumes a key, mark it handled in the owning input router. Do not put an independent editable `LineEdit` ahead of the prefix parser.
- Floor left click teleports only; interactable left click remotely teleports to legal **cardinally adjacent** tile and selects/acts on the same click. If invalid, no partial teleport or mutation.
- The online acceptance station accepts `terima`; an **accepted driver's own target** accepts `saji`. The driver must be in one of the **three physical pickup spots**; outside overflow driver cannot be served. Player-facing commands remain Indonesian.
- The prep surface has separate staging and chopping hit areas. Context-sensitive `wastafel` action cannot wash plates and rice simultaneously by mistake; choose behavior from the validated held-item/dirty-plate state.
- Mouse input inside the reserved left UI band, purchase panels or results controls must **never** reach world teleport. Decorative noninteractive UI uses `MOUSE_FILTER_IGNORE`; interactive controls generally use `MOUSE_FILTER_STOP` and explicitly handle their events.
- Convert view/canvas coordinates to world/grid coordinates through one consistent method. Avoid subtracting a magic left-panel width in multiple scripts.

Correct behavior matters more than clever input abstractions. Test focus, keyboard switching, fast repeated clicks and edge-of-viewport prompts with real desktop input.

## 9. Data-driven food, economy, and content

- Static authored `IngredientDef`, `RecipeDef`, `UtilityDef` and `EconomyConfig` belong in `.tres` `Resource` definitions. Treat them as **read-only during gameplay**. Runtime quantities, prices already paid, item/plate ownership and order status are separate controller-owned data.
- Additional recipes must be authorable by adding `RecipeDef.tres`, economy/unlock entry, and icon association, **without writing a new `match recipe_id` branch** in cooking or customer code. Only the currently approved recipes are authoritative until the coordinator supplies more.
- A recipe is an **exact multiset of ingredient IDs and prepared states**, served only when plated. Order of plating components may vary; food prep transformations still require legal preceding steps.
- Physical storage capacities are **slots**: fridge `2 × 3`, box `3 × 5`; the same raw ingredient can occupy multiple slots. Purchasing names **one selected physical container** and never spills to another.
- D owns fixture and recipe prices, starting cash, Day 7 goal and fixed daily electricity. Use integers for Rupiah, not floats. Balance values and multipliers are tunable data, **not hardcoded throughout UI/controller scripts**.
- Add early validation for duplicate IDs, unknown recipe ingredient references, nonpositive recipe prices, unsupported/empty selected menu, invalid storage destinations, and absent assets with sensible placeholders. Report missing planned Days 4–7 recipes as **pending content**, not as invented dishes.
- Avoid dynamically loading resource paths from Indonesian display names; use stable IDs and explicit data mapping. Avoid loading the same art every frame—cache/preload shared display resources where practical.

## 10. Error handling, invariants, and feedback

There are two categories of failure:

**A. Expected gameplay rejection:** wrong recipe, full hand, no clean plate, expired order, full storage, insufficient cash, invalid command. Return `false` (or documented status), change no authoritative state, and ask UI to show brief Indonesian feedback where required. **Do not** `push_error()` or crash for ordinary player mistakes.

**B. Developer invariant violation:** duplicate plate ID, missing supposedly installed fixture, an accepted order paid twice, broken scene reference, impossible transition. Log with a precise ID/context using `push_error()` and investigate. A failed invariant must not be quietly converted to success.

- Use `assert(condition, "reason")` for **debug-only internal invariants** when it helps; **do not use it for gameplay validation or for expressions with side effects**. Godot ignores assertions in non-debug exports.
- Avoid broad catch-all fallback values that hide broken owner references. For missing optional art, a visible placeholder is acceptable; for a missing required controller, report a developer error early.
- Guard repeated callbacks/late timer events. Once a record is `COMPLETED`/`FAILED`, later inputs must not change it.
- Don't print to the output on every frame or on every invalid letter. Use event-specific diagnostics and remove temporary spam before export.
- Don't suppress warnings globally just to get a green editor. Fix actionable warnings; document one justified exception if necessary. Warn-as-error project settings are optional, not a jam deliverable.

## 11. Testing: practical checks, not ceremony

Claude Code should be given **repeatable tests** for each milestone. Formal test frameworks are optional; a small Godot test scene or a minimal `SceneTree` debug script can be enough when it produces deterministic pass/fail. Do not install a large test dependency merely for this project.

**Minimum check sequence at each milestone:**

1. Inspect changed scene/script dependencies and use `git diff --check` for whitespace/conflict artifacts.
2. Start Godot's editor import/check path once `project.godot` exists:

   ```bash
   godot --headless --path . --import
   ```

   Use `godot4` or the actual executable path if needed. This **checks import/parse of encountered resources**, but **does not** prove every game action, focus behavior or export works.
3. Run the relevant automated test scene/script where available. When writing a runnable test script, choose the correct Godot CLI invocation for that script/scene and make failure observable via a nonzero process exit, explicit test failure, or captured error output.
4. Have the developer manually test the **actual interactive scene** when input/UI/visual behavior is involved.
5. Record evidence in `docs/PROGRESS.md`: test ID, Godot version, result (`PASS`, `FAIL`, `NOT RUN`), and relevant log/scene. **Never claim a test passed without running it.**

**Essential regression targets — keep these even if time is short:**

| Risk | Expected invariant |
|---|---|
| Typing invalid key / click away | No wrong action or accidental inventory mutation |
| Serving correct vs wrong order | One plated dish consumed **at most once**; money credited **once** |
| Dine-in cleaning / washing | A single reused `plate_id`; never clone plates |
| Online driver overflow | Three spots, FIFO overflow, outside driver unservable, accepted order still expires at 60s |
| Empty-looking restaurant | No auto-close while future arrivals, outside diners or accepted online orders exist |
| Shopping during service | Clocks continue; 100s shipment arrives once in the **selected container** |
| Delivery/close same boundary | Refund **only** pending shipment IDs; no double refund |
| Resale | Planning only, immediate, safe dependency checks, no free starter resale profit |
| Seven-day deadline | Target uses **current money after electricity**, not gross earnings |
| Layout with left UI | UI clicks do not teleport; bubble, queue and rings visible at chosen window scale |

**Time test:** Drive the same authoritative elapsed-time model in tests instead of introducing a second production clock. Seed randomness for reproducible expectations. See `docs/ACCEPTANCE_TESTS.md` for explicit cases and current edge behavior.

**Release gate:** The game starts from a fresh Windows/Linux build, one complete day can be played, seven-day evaluation works, all major critical tests are executed, and missing art/content is honestly documented. The release build itself requires a real launch test, not just headless import.

## 12. Git, generated assets, and artist collaboration

**One developer is the sole code owner.** Artists hand over assets through the agreed team process; integrating them does not mean asking artists to edit gameplay scene scripts in parallel.

- Keep code, scene `.tscn`, Resource `.tres`, `project.godot`, source art and import settings in Git. Ignore generated `.godot/` editor cache and temporary build/export outputs. **Do not ignore `.uid` files** generated by Godot 4.4+; commit them alongside relevant source files.
- Preserve `.import` metadata needed for explicit texture import settings. Maintain stable filenames and IDs when replacing placeholder assets.
- Prefer small milestone commits after tests. One commit should correspond to an understandable working change, not a mix of unrelated cleanup and new mechanics.
- Before a risky edit, inspect `git status` and relevant diffs. **Never overwrite/delete unrelated local work** and never run destructive Git commands unless the developer authorizes them.
- Do not make sweeping rename/refactor passes during an unfinished integration milestone. Windows/Linux differ in path case sensitivity; use lowercase `snake_case` filesystem names, valid `res://` resource paths and stable `.uid` references.
- Avoid adding Git LFS late unless asset size actually creates repository problems and every teammate can use it; it's not required for typical small pixel-art jam assets.
- Keep art integration defensive: missing final icons use visible placeholders, but missing mandatory hitboxes/IDs are P0 errors.

Recommended `.gitignore` entries (add only if not already present; consult actual engine version):

```gitignore
.godot/
*.translation
builds/
```

**Do not add `*.uid` to `.gitignore`.** Before changing `export_presets.cfg` in version control, ensure no local signing keys/passwords are accidentally committed, particularly if using older Godot 4.x builds.

## 13. Claude Code task protocol and code review

Claude Code is a **code-writing assistant**, not the authority on game rules. Its most useful practice is a short inspect → plan → implement → verify loop.

**At the beginning of each milestone:**

1. Read `CLAUDE.md`, current `docs/PROGRESS.md`, the milestone section in `docs/IMPLEMENTATION_PLAN.md`, and the **relevant** canonical sections of `docs/ARCHITECTURE.md` and domain specs. Read this file when modifying scripts.
2. Inspect the actual existing source, `project.godot`, relevant scenes, data and Git status. Do not assume something is absent merely because the plan says it is not yet completed.
3. State the minimal intended changes, public contracts touched, and exact verification to run.

**While coding:**

4. Implement only the current milestone. If a canonical public API must change, **stop and report the reason** to the developer/coordinator; do not secretly add a competing second API.
5. Reuse Godot built-ins and existing project patterns. Make direct simple changes rather than introducing abstractions without a concrete use case.
6. Use temporary placeholders where approved art/content is absent. Do not fabricate new recipes or an employee/perk/save system.
7. Check the result using the actual Godot executable, tests, and visual scene where relevant. Fix root causes; do not suppress logs or delete tests to manufacture a pass.

**At the end:**

8. Report changed files; what runs; tests actually executed; remaining bugs/content needs; public contract changes (ideally none).
9. Update `docs/PROGRESS.md`, get developer review and commit a coherent checkpoint if approved.
10. Move to another milestone **only when asked**. When context gets crowded, begin a fresh Claude Code session and recover from files/Git, not from guesses about earlier chat.

### Ready-to-paste Claude Code milestone instruction

```text
Read CLAUDE.md and docs/CODING_STANDARDS.md. Inspect actual Godot files,
docs/ARCHITECTURE.md and the relevant system spec and current milestone.
Follow the frozen public interfaces and single-state-owner rules.

Implement ONLY Milestone [N] from docs/IMPLEMENTATION_PLAN.md.
Use typed GDScript at public boundaries, simple Godot-native scenes,
no new managers, and synchronous once-only state transitions.
Run the applicable parse/import check and acceptance tests.
Report actual results, files changed, unresolved issues, and update
PROGRESS.md. Stop before the next milestone.
```

### Optional integration line for the existing root CLAUDE.md

Add this **single sentence** under implementation rules (no giant `@` import):

> For code changes, read `docs/CODING_STANDARDS.md` and apply its P0/P1 rules; `docs/ARCHITECTURE.md` wins if any instruction conflicts.

## 14. Anti-patterns to reject during review

| Red flag | Correct approach |
|---|---|
| `get_node("/root/MoneyManager")` or new Autoload | Use canonical `RunController` reference wired by root |
| `Timer` node on every order or delivery | Store due time relative to **one** `GameRoot.service_elapsed` |
| Signals trigger order payout or dish consumption | Synchronous validated method, signal only after commit |
| UI stores and decrements independent patience time | Render C snapshot using `due_at - now` |
| Reuse Indonesian display label as `recipe_id` | Stable `StringName` ID plus localized name |
| `match recipe_id` with exactly three hardcoded branches | Recipe `.tres` requirements and general exact matching |
| A new manager for a single helper function | Private helper in existing owner |
| `await` before inventory debit/payment state commits | Complete state transaction synchronously |
| Catch/ignore all invalid states | Reject player mistake; log genuine invariant error |
| `assert()` to prevent invalid player purchase in release | Runtime validation with `false` return |
| Repeating `import` or GUI-only testing as "passed all tests" | Record exact test performed, run interactive validation |
| Moving files without `.uid` or breaking case on Linux | Stable path/UID + import check after rename |
| Reformatting every script during a one-file bug fix | Minimal diff that addresses the bug and its test |
| Adding features while deadlines are near | Finish and test existing scope first |

## 15. Definition of done for a coding task

Mark a milestone/task complete only if:

- [ ] The requested functionality works in the Godot project with a concrete verification path.
- [ ] Canonical public APIs, controller owners, phases and clock ordering are unchanged unless an approved contract change was recorded.
- [ ] No extra order credit, inventory removal, plate, delivery, refund or settlement can happen from repeated input/callbacks.
- [ ] No UI/world click-through, hidden command focus, untracked timer, or changed live durations were introduced.
- [ ] Relevant acceptance tests have real results, including **manual input tests** for visual/input work.
- [ ] Error output is inspected and known failures are not concealed.
- [ ] `docs/PROGRESS.md` records files, result, remaining blockers and next action.
- [ ] Developer has reviewed the change; checkpoint commit is ready or completed as approved.

## Sources and research notes

This document combines **official engine/tool guidance** with **project-specific architectural rules** from the v2.1 handoff. The style, typing, input event, CLI and Git recommendations are grounded in the following sources; the **single clock, precise controllers, order/plate semantics and jam-specific stop rules** are project decisions, not universal Godot rules.

1. Godot, [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) — formatting, naming, code ordering.
2. Godot, [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) — typed boundaries, inference, limitations.
3. Godot, [GDScript warning system](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html) — warning visibility and targeted suppression.
4. Godot, [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) — scene boundaries and parent-wired relationships.
5. Godot, [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) — file naming, folders, platform case sensitivity.
6. Godot, [InputEvent lifecycle](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) and [Control input/mouse filter](https://docs.godotengine.org/en/stable/classes/class_control.html) — GUI vs gameplay event routing.
7. Godot, [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html) — shared/static resources and duplication behavior.
8. Godot, [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) — `--headless`, `--import`, script execution and exports.
9. Godot, [Version control](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) and [Godot 4.4 UID changes](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) — cache exclusions and `.uid` preservation.
10. Godot, [RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html) and [GDScript `assert`](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) — deterministic tests and debug-only invariants.
11. Anthropic, [Claude Code best practices](https://code.claude.com/docs/en/best-practices) and [Project memory/CLAUDE.md](https://code.claude.com/docs/en/memory) — focused tasks, short persistent instructions, verification, context management.

**Last check:** 2026-11-15. Check the installed Godot 4.x version before using any version-specific API; source pages marked `stable` evolve as Godot releases change.
