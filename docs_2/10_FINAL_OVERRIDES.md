# Final precedence and conflict resolutions

Final cumulative v006 · Latest coordinator requests prevail over older source/specification text.

This register is authoritative for assembling this handoff. The original recipe attachment and earlier raw notes remain unchanged for traceability; historical contradictions in them must not cancel separate current coordinator requests.

| Topic | Active final direction |
| --- | --- |
| Recipe content | Use exactly the thirteen recipes, exact prepared parts, stable IDs, unlock days, descriptions, initial prices and per-recipe attraction data in the newly supplied recipe brief. Ordinary `plate.png` is not recipe fourteen. Preserve editability of balance values. |
| Former three-recipe content | Replace the old chicken-plus-tempe definition and generic `nasi_komplit` as specified. Preserve IDs for genuinely corresponding dishes; migrate references safely. Do not keep the old flat +2 variety bonus. |
| Customer demand | +4 base arrivals/day; one deterministic selected baseline by `(unlock_day, recipe_id)`; sum authored contributions for additional selected recipes; subtract existing debt and floor at zero. Cheap/Mid +3/+2 and prices are initial tuning; expensive +1 is explicit. Customer order weights remain inverse price among selected dishes only. |
| Ingredient availability | Derive from all recipes unlocked so far, not selected menu. Start-of-Planning expansion: Beras/Telur Day 1, Tempe Day 2, Ayam Day 3, Sayur Day 4, Sapi Day 5. Enforce in the purchase controller, and preserve emergency Serving purchases/delivery. |
| Resep panel descriptions | The new recipe brief explicitly requires its short descriptions. This supersedes the older instruction to omit a prose description. Store and display the provided text verbatim with word wrapping. Keep the useful actual ingredient/preparation list where the current panel supports it; do not replace the supplied descriptions with generated copy or clip them to preserve an older mockup. |
| Equipment selling | Removed from scope by the latest recipe handoff's stated coordinator directive. Do not add/reintroduce sale controls, sale confirmation UI, or equipment resale work based on older specs. Historical ledger fields do not authorize a new selling feature. |
| Audio paragraph in recipe source | Its statement that audio is unfinalized/unauthorized is stale relative to the separately explicit audio requests in this conversation. The recipe module adds no new audio requirements; **the cumulative finalized audio/SFX/fade/Settings instructions remain active**. Do not cancel them. |
| Guided tutorial | Remove it. Use only the exact single-panel `CARA MAIN` copy in document 09, replacing the older general tutorial proposal. No step sequence, arrows, required tutorial actions, or tutorial completion gate. Agent must verify rendered text fit. |
| Three-tile long counter | Three independent item slots per affected long counter, one on each tile. Verify three items simultaneously and independent pickup/refill. |
| Plate assembly | Preserve the earlier explicit ability to plate in either direction. The recipe attachment's general reference to plate-first assembly does not request removal of ingredient-first interaction. One held aggregate and one clean plate per dish still apply. |
| Dish/plate visuals | All thirteen final dish icons and the ordinary plate are now included. Prior missing-dish-art notes are superseded. Keep dirty-table `plate-dirty.png` distinct and its hover tooltip exactly `meja kotor`. |
| Font and credits | Actual Grape Soda TTF is included. No in-game attribution or forced credit screen; coordinator reports credits are on itch.io. Developer-only provenance remains with assets. |
| Currency | Everywhere use spaced compact k format, e.g. `Rp 4k`, `Rp 4.5k`, at most one decimal; ledger math and outcome tests use exact integers. Recipe-table raw IDR values do not change this display rule. |
| Visual examples | Original mockup sample prices, duplicate rows, Aktif text, aggregate capacity line, slot picker implications, and cropped details do not override explicit simplified UI rules. Use the supplied art and real data, checkmarks, and valid viewport layout. |
| Results/win/lose | Document 08 is the concrete requested design proposal. Use already settled values and latched Day 7 outcome. No early loss, rescue money, or settlement twice. Navigation/retry must be real owner-controlled actions, not mislabeled quit calls. No equipment-selling UI is introduced by historical result rows. |
| Delivery cadence | The tutorial-only turn explicitly deferred its ZIP update. This final ZIP incorporates that addendum and every subsequent menu attachment. No repository edits were made by the preparer. |

Do not use an old test fixture that expects the retired recipe roster as a reason to keep incorrect production data. Update relevant expectations to the new approved content while retaining meaningful validation coverage. Do not remove broad tests merely to obtain a green summary.

The developer must inspect the actual latest branch and report any genuine current-code conflict in `/docs/PROJECT_STATUS.md`. The last snapshot read by the preparer was `6991131`; this handoff does not assert that it is still HEAD.
