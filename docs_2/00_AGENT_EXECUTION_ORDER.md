# FINAL HANDOFF — read this first

Ketik Saji · Final cumulative v006 · 19 November 2026 (WIB)

The coordinator reports less than 30 minutes remain at handoff. Work in the latest developer checkout; inspect current changes and preserve existing work. This package supplies requirements and available assets, not a certified latest game build. The handoff preparer did not modify the repository or audit another push.

## Read the active instructions in this order

1. **[10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md)** — current precedence, resolved conflicts, and latest requirements. It overrides stale text elsewhere in this cumulative packet.
2. **[Final 13-recipe brief](<sources/KETIK_SAJI_13_RECIPE_PROGRESSION_AND_DEMAND_HANDOFF(1).md>)** — authoritative roster, exact parts, initial prices, unlock days, descriptions, demand formula, and ingredient gating. The supplied source is unchanged; apply the conflict resolutions in document 10.
3. **[11_DISH_ASSET_MAP.md](11_DISH_ASSET_MAP.md)** — verified exact recipe-to-file binding. All thirteen dish icons plus the ordinary plate are included.
4. **[09_TUTORIAL_PANEL_FINAL.md](09_TUTORIAL_PANEL_FINAL.md)** — remove the guided sequence; use the coordinator's exact one-panel text. Verify actual rendered fit with Grape Soda, including the close button.
5. **[01_IMPLEMENTATION_REQUESTS.md](01_IMPLEMENTATION_REQUESTS.md)** — randomized input SFX, correct error/serving triggers, loop at 191.392 seconds, five-second fades, Settings BGM slider, and other cumulative integration requests.
6. **[03_UI_VISUAL_IMPLEMENTATION.md](03_UI_VISUAL_IMPLEMENTATION.md)** and **[04_UI_ASSET_CATALOG.md](04_UI_ASSET_CATALOG.md)** — five original visual targets and 43 UI/decor PNGs, exact paths and detailed screen construction. Document 10 resolves the new Resep-description override.
7. **[07_LONG_COUNTER_ITEM_SLOTS.md](07_LONG_COUNTER_ITEM_SLOTS.md)** — each three-tile long counter holds three items simultaneously, one per tile.
8. **[08_RESULTS_WIN_LOSE_DESIGN.md](08_RESULTS_WIN_LOSE_DESIGN.md)** — concrete design proposal for the result screens, real data bindings, safe next-day/extra/retry/menu actions. The [HTML preview](previews/RESULT_MENUS_PREVIEW.html) uses example values and is not a live game.
9. **[06_PROJECT_STATUS_REPORT_INSTRUCTION.md](06_PROJECT_STATUS_REPORT_INSTRUCTION.md)** — update the repository's `/docs/PROJECT_STATUS.md` with this push's actual status, tests, failures, and coordinator checks.

## Integration order for the short remaining window

- Inspect the current branch and active implementation before patching; avoid replacing working systems wholesale. Start with missing data/resources and small bindings, preserving already completed integrations.
- Import the available font/UI/dish resources, then make the thirteen recipe definitions, prices, unlocks, catalog gating, and customer demand use their actual shared IDs. Ensure exact six-part Nasi Gila and rice-free salads validate correctly.
- Replace the guided tutorial with the exact single panel; verify fit in an actual rendered game window. Connect finalized dish icons/descriptions to recipe UI and normal order/held-item presentation.
- Finish remaining UI/audio/counter/result integration using existing controllers. Do not let a decorative reskin bypass purchase, phase, serving, plate, timer, or settlement validation.
- Run import/resource checks and focused existing tests for changed systems. Do a real-window smoke test of start → Planning → Serving → results, plus representative unlock/dish/shop checks. Exercise Day 7 outcomes through existing test/debug setup rather than claiming a full seven-day manual playthrough if time does not permit one.
- Update `/docs/PROJECT_STATUS.md` before the relevant push. List implemented, partial, missing, inconsistent, and unverified items honestly, including any skipped listening/visual checks. Give the coordinator concrete reproduction steps for remaining issues.

The short window is not permission to mark incomplete work complete. Record remaining tasks plainly and keep the current game playable. Final delivery must identify the actual code baseline/commit, changed files, checks run, remaining errors, and the repository link to the current status report.

## Available resources

`provided_assets/ui/`: 41 PNGs; `provided_assets/decor/`: 2 PNGs; `provided_assets/dishes/`: 13 dish PNGs + ordinary plate; `provided_assets/audio/`: 8 files; `provided_assets/fonts/GrapeSoda.ttf`: actual original font. All five UI targets and the counter screenshot are included. Source bytes were checked against the supplied archives.

The coordinator reports all art is complete. This packet contains the files received in this conversation; a separately completed main-menu background/logo is not added by assumption. The new result/tutorial screens deliberately reuse supplied boards/buttons and dynamic font text, so they require no new painted artwork. There is no in-game attribution requirement: the coordinator placed credits on itch.io.
