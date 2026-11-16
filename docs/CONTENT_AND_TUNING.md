# Content intake and tunable economic values (not architecture blockers)

This file prevents Claude Code from inventing data when coordinator/artists have not supplied it. **Current content:** three approved recipes. **Planned content:** additional recipes progressively unlocked through Days 4–7 and potentially beyond. The gameplay architecture **must already support** arbitrary data-defined recipes, not hardcode three cases. No need for further design interview to build that pipeline.

## Known recipe entries (confirmed ingredient state requirements)

| Recipe ID | Display (can change without ID change) | Required exact parts | Provisional unlock day |
|---|---|---|---:|
| `nasi_telor` | Nasi Telor | beras COOKED_RICE + telur COOKED | 1 |
| `nasi_ayam` | Nasi Ayam | beras COOKED_RICE + ayam COOKED + tempe COOKED | 2 |
| `nasi_komplit` | Nasi Komplit | beras COOKED_RICE + ayam COOKED + tempe COOKED + sayur CHOPPED + telur COOKED | 3 |

Additional ingredient ID `sapi` and cooking state possible, but **no existing approved recipe requires it**. Do not infer recipe names or valid dish compositions from possible processing states. Any new ingredient processing must be authored by coordinator.

## Template for EACH future recipe received from coordinator

```text
recipe_id: stable_ascii_snake_case
indonesian_display_name: (coordinator)
icon_art_reference: (artist-provided path/key or placeholder)
unlock_day: 4..7 etc (coordinator)
dine_in_sale_price: integer IDR (TUNING)
required_parts:
  - ingredient_id: <approved IngredientDef ID>
    prep_state: <approved processed state>
  - ...
optional_new_ingredient_definitions: []
optional_new_processing_transitions: []   # may need separate approved small implementation
notes: if a state/step doesn't exist, flag; do not silently introduce mechanics
```

**One-new-dish-each-day intent:** For full 7-day content, coordinator supplies at least four additional entries corresponding to remaining days. The importer must validate every referenced ID/step, icon placeholder availability, duplicate recipe IDs and `unlock_day`. If only three assets exist at prototype time, the game still runs with currently authored entries, but log content gap; do not claim daily unlock content complete for Days 4–7.

## Economic data explicitly TUNING — not gameplay confirmations

- `starting_cash`, `day_7_cash_target` (example 100k and 700k IDR), ingredient buy prices and exact diner sale prices, equipment purchase costs, rack plate count, fridge/rice cooker fixed daily charges and fixture resale % (example 50). Values must be easily edited in one EconomyConfig/definition file.
- `day_1_base_dinein_quota` (example 4), `extra_arrivals_per_extra_selected_menu` (example 2), order price weighting (example inverse-price), online payout percent (example 70). The **+4 per day** increment is a confirmed value intended configurable; use 4 default. Online payout **must remain lower** than equivalent diner payment unless coordinator changes it.
- Fixed live service timings **CONFIRMED**: 100s diner patience from spawn (outdoor too), 20s first-to-next diner spawn cadence, 20s diner eating, 60s accepted online deadline, 100s service ingredient shipment. Test scenes may accelerate time or override durations; shipping game must use confirmed values.
- Other explicit defaults documented in `DECISION_REGISTER.md`: starter resale based on amount actually paid, trash retains reusable plate, cooker single output, zero-customer day counts as perfect, no further mandatory extra-mode target. These are reversible defaults, not silently added confirmed game rules.

## Asset and map intake checklist

- 32×32 tile sprites: floor/walls; player sprite and held icon; initial fixtures and extra fixture visual types; **click collision shapes independent of sprite frames**; kitchen work-table staging/chopping interactive subzones; 2+ dining tables and chairs; trash; online acceptance station.
- Distinct icons for **every authored recipe**; raw ingredient and cooked/prep feedback (placeholder acceptable early); plate clean/dirty marker; customer and delivery driver visuals; ghost dialogue and emptying circular rings.
- Map-authored stable `slot_id` for purchasable fixture/table locations and `table_id`; exactly 3 online pickup `spot_id`s, a separately visible outside-driver queue, an in-world dine-in waiting lane just to the right of the left UI safe band, and floor accessible tile set for cardinal teleport. These are separate visible zones; do not make UI overlap/click-through hide playable waiting customers. No coordinates or exact tile counts are derived from the rough sketch. On import, validate that each clickable target has at least one legal cardinal-neighbor tile and visible hitbox.
- **LATEST SCREEN-SPACE REFERENCE:** `references/current_screen_layout_NON_BINDING.png` and `docs/WORLD_LAYOUT_AND_VIEWPORT.md`. The older 10×9 world assumption is superseded; the new illustrative gridded area appears roughly 13×9 including the dine-in waiting lane but is not fixed. Dedicated left HUD band takes roughly 18% of the image width (not a requirement). Proposed logical resolution 640×360 must be tested with HUD + waiting lane + world + online drivers + dialogue visible before binding UI art.

## Coordinator review gate (can happen during implementation)

1. Supply future recipe IDs, processing conditions and icon mappings (more recipes are **planned**, not yet all authored).
2. Tune starting cash, Day7 target, all costs/payouts and quota coefficients from actual playtests. Difficult and potentially unwinnable after bad purchases is intended; ensure at least one competent seven-day route wins.
3. Confirm final asset imports/world placement/view resolution after pixel/UI artist handoff. Architecture deliberately separates logical IDs from art paths.
