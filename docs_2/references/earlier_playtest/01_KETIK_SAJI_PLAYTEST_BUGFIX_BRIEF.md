# Ketik Saji | Playtest bugfix brief

**For the developer and coding agent · 18 November 2026 (WIB)**

Implement the changes below in the current game and verify them through the normal player flow. **This brief is a cleaned, structured version of the coordinator’s own playtest messages.** [The original notes and follow-up](02_COORDINATOR_RAW_PLAYTEST_NOTES.md) are included verbatim. The two messages are the source for the requested behavior. The implementation interpretations below resolve practical details that the notes left open.

Start from the current branch and inspect the local diff before editing. The last reviewed GitHub baseline is [`e5898bb`](https://github.com/ahmadirfanmarufm/Ketik-Saji/commit/e5898bb01e438d7f29edbc9b2f868cf03eb2f750). Treat the symptoms as coordinator observations from that stage and check which still reproduce. Adapt the existing world input, controller transactions, and scenes.

## 1. Storage selection, available commands, and tooltip clicks

Derived from [original notes, opening paragraphs](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message).

- **Clicking a box or fridge selects that container. Typing `beli` opens `Belanja Bahan` for it.** Apply this in Planning and Serving. Serving should show the normal take-item tooltip immediately after the click. During Planning, show the purchase command and omit Serving-only retrieval commands.
- **Generate the displayed commands from current eligibility.** Use the selected target, phase, held item, and the target’s live state. At storage, list only ingredient commands that can currently take stock from that exact container. An empty container can still offer `beli`. Apply the same rule throughout the game. For example, show `nasi` only when that cooker has a portion and the current held state can accept it, and hide `terima` when the selected online station cannot accept another order. Refresh the prompt when stock, phase, holding state, or order eligibility changes. A stale typed prefix must never apply to an unavailable command or another target.
- **A utility tooltip click routes to its own target.** Consume the click in the UI and relay it through the same selection or interaction route as a world click on that utility. A Planning-only informational tooltip should behave as its target would in Planning. The floor behind the tooltip must not receive the click or produce a blocked-tile error.

**Check:** Put only rice in one box and eggs in a different container. Click each in Serving and verify its own available commands with no purchase modal. Type `beli` and verify the selected container is the sole delivery destination. Click the tooltip over an invalid floor tile and confirm the click never reaches the floor.

## 2. Five rice portions and plating in either direction

Derived from [original notes, rice and plate paragraphs](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message).

### Rice cooker

One washed and cooked batch produces **five portions in that cooker**. Each successful `nasi` pickup consumes one portion. The cooker remains available for four further pickups after the first one. After pickup five, the output is empty and the player needs another washed batch. An unsuccessful pickup spends zero portions. Keep the output per cooker so starter and purchased cookers work independently.

### Plate handling

| Starting state | Input | Expected result |
| --- | --- | --- |
| Player holds an empty or partially filled plate | Take rice or another eligible plateable part from its normal source | Add the part directly to the held plate. Consume the source portion only when the addition succeeds. |
| Player holds a loose plateable part | Click a rack with an available clean plate | Take one clean plate and place the held part on it in the same action. |
| Player holds a loose plateable part | Click an available plate already in the world | Add the part to that plate through the existing plate interaction. |

Honor recipe and preparation rules, preserve the same plate identity, and keep the existing single held-item model. Invalid parts, incompatible combinations, and empty racks must leave stock, portions, and the held item intact.

**Check:** Wash and cook once, retrieve five portions, and verify the sixth is unavailable. Try an invalid pickup before a valid one. Build a dish plate-first and ingredient-first. Verify ingredient counts, plate counts, and behavior when all clean plates are taken.

## 3. HUD, Escape, and pause

Derived from [original notes, UI strip, Escape, pause, and money paragraphs](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message).

- **Widen the left HUD strip and fit its contents.** Make the heading, cash, customer counts, buttons, and target values readable at the default size and a supported smaller window size. Update the world offset and HUD click boundary together if the strip width changes. In Planning, show the target cash as a numeric amount, for example `Target: Rp 700k`, alongside any existing goal progress display.
- **Use one money format across player-facing UI.** Format 4,000 as `Rp 4k` and 4,500 as `Rp 4.5k`. Include a space after `Rp`, use a decimal point, and omit trailing `.0`. Show at most one decimal. Use it for current cash, goals, unit prices, basket totals, electricity, and any settlement values that still appear. Use the exact integer amounts for accounting and validation.
- **Add a Pause button to the strip.** Pause stops live gameplay and its timers and offers Resume and Exit. Resume restores the current run at the same position. Ordinary shop overlays still allow Serving time and deliveries to advance.
- **Escape priority used in this brief.** Close the active popup first. With no popup, if a target is selected or a command is in progress, clear the interaction and command without moving the player. With nothing to dismiss during gameplay, Escape opens Pause. The strip’s Pause button opens Pause directly.
- **Exit destination is open.** Use an established exit route if one exists and report that route. The notes leave the choice between returning to the main menu and closing the game unspecified.

**Check:** During Serving, select a station and type a partial command. Escape should clear both without changing the tile. From neutral gameplay, Escape should pause. Verify the HUD button opens the same menu, Pause freezes the service clock, and Resume restarts it. Verify an ordinary ingredient popup leaves the clock running.

## 4. Customer seating and dirty tables

Derived from [original notes, seating paragraph](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message) and [follow-up, dirty plate](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#follow-up-message).

- **Use the chair position for a seated customer.** Coordinate with the developer placing chairs beside tables. Link each chair or seat marker to its table, including additional tables with authored chairs. The table remains the target for Serving and cleaning. Keep queue and service logic independent of the visual chair position.
- **After the customer finishes eating, the dirty state is a dirty plate icon on the table.** Hovering over the plate shows the tooltip `meja kotor`. Keep the tabletop free of a permanently displayed dirt label or extra marker. The icon and tooltip must leave the normal table interaction and cleaning flow usable.

**Check:** Seat a customer, serve them, advance through eating, hover the dirty plate, and clean the table. Repeat at a newly placed table with a chair.

## 5. Simplify both shop popups

Derived from [original notes, shop paragraphs](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message) and [follow-up, equipment typography](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#follow-up-message).

### Belanja Bahan

Keep the container identity, separate slot indicators with contents and quantities, ingredient purchase controls, and the basket total. Cash remains visible in the left strip.

| Current presentation | Requested change |
| --- | --- |
| Cash repeated in popup | Remove it. |
| Aggregate capacity or `Sisa kapasitas` | Remove that line. Keep each slot visibly separate. |
| `S1`, `S2`, `S3` labels | Remove the slot names. |
| `Tiba langsung` in Planning | Hide the label. Planning purchases still arrive immediately. |
| Pending-delivery message when there are no pending shipments | Hide the entire empty-status line. Show actual pending deliveries when present. |
| `Stok` counter on each ingredient row | Remove it. Slot contents are the stock display. |

Checkout still uses the clicked container and existing basket validation. A Serving purchase still uses the existing delayed-arrival flow.

### Belanja Peralatan

- The player chooses placement by clicking an **empty world slot in Planning**. The chosen slot stays fixed for the entire popup. Remove slot selectors from the popup and retire the separate `Beli Alat` HUD shortcut under this slot-first flow. Filter the catalog by the clicked slot’s type. Show table options for table slots and compatible utilities for utility slots.
- Place a legible utility sprite on the **left** of each entry. Keep its aspect ratio and use consistent sizing across rows. To its right, put the **name and price together on one bold line**. Put the description on **its own line immediately below**, in regular weight.
- Use short purpose descriptions. Include daily electricity inline only for equipment that has a charge. Remove duplicate cash, category brackets, `Manfaat`, `Beban (Complexity Debt)`, compatibility explanations, and compatible-slot counts from the entry. Eligibility and electricity still use the game’s real data.
- Replace the footer’s `utility → slot` summary with `Harga: Rp …` for the selected item. Keep selection, `ga jadi`, and `beli` usable.

**Row examples**

**Kompor: Rp 60k**  
Untuk memasak

**Kulkas: Rp 80k**  
Buat nyimpen bahan sampai beberapa hari (listrik: Rp 4k/hari)

**Check:** Open an empty table slot and verify the catalog shows table options only. Repeat with an empty utility slot. Pick an item, verify the bold and regular lines, footer price, and inline electricity, then buy it. Confirm the fixture appears in the originally clicked slot. Rejecting a purchase should leave cash and placement unchanged.

## 6. Edit Menu and routine error feedback

Derived from [original notes, Edit Menu and error-feedback paragraphs](02_COORDINATOR_RAW_PLAYTEST_NOTES.md#original-message).

- Keep the existing menu editing flow. Narrow the dish list, use colon formatting such as `Nasi Telor: Rp 20k`, and replace `[Aktif]` with a small checkmark for enabled dishes. Use the final dish sprites when supplied.
- Place a recipe-detail panel immediately to the right of the list, with no gap. Show the previewed dish name at the top, then one ingredient per line. Use recipe data for the ingredient and preparation list. Cooking is implicit. Label alternate preparation when required, such as `Sayur (potong)`. Previewing a recipe should have no effect on whether it is enabled.
- For an invalid typed letter, keep the existing accepted prefix, ignore the new letter, and shake the tooltip. Remove `Huruf tidak cocok` for this routine error. Elsewhere, prefer visual feedback when it makes the mistake clear. Keep a short explanation for a rejection whose cause cannot be understood from the state or visual cue.

**Check:** Preview an enabled and a disabled dish and verify the checkmark and right panel independently. Compare a default cooked ingredient with a chopped ingredient. Type an invalid letter between valid prefix letters and verify the shake, the unchanged prefix, and absence of error text.

## Implementation and verification

- The existing entry points are in `scripts/kitchen/kitchen_controller.gd` for command eligibility, cooker portions and plating, and in `scripts/ui/game_ui.gd` / `scenes/ui/game_ui.tscn` for modal input, prompts, shops and HUD. Reuse `scripts/economy/run_controller.gd` for basket purchases, exact balances, slot validation, and power costs. Use `scripts/world/world_map.gd` and the world scene for chair anchors and the dirty-plate presentation. Connect Pause at a point that stops the service clock while leaving the pause controls responsive.
- Run import and the relevant existing tests, especially `test_game_ui_m1.gd`, `test_service_m2.gd`, `test_service_m3.gd`, `test_planning_m4a.gd`, `test_shop_m4b.gd`, and `test_fixture_m4c.gd`. Extend assertions that cover the changed paths, especially contextual commands, five portions, both plating directions, and Escape precedence. Use the rendered window for text fit, tooltip click routing, sprite sizing, and chair placement.
- Before the next development push, update `docs/PROJECT_STATUS.md` with the tested commit, cases passed, remaining failures, and the Exit behavior used. Separate graphical checks from headless checks.
