# Ketik Saji — FINAL cumulative handoff v006

19 November 2026 (WIB)

## Final additions and supersessions

- Unchanged coordinator recipe handoff under sources/; exact thirteen-dish data, progressive unlocks, descriptions, editable initial prices/attraction, and authoritative ingredient gating.
- Original fourteen 32×32 PNGs from the two new ZIPs: thirteen recipe icons plus plate.png. All opened, visually inspected, and byte-verified. Document 11 maps every stable recipe ID to the exact filename.
- Latest single-panel tutorial addendum now incorporated, with the exact coordinator text and mandatory rendered fit checks. It replaces the prior guided tutorial proposal; its deferred-ZIP turn is preserved in the raw log.
- Documents 00/10 establish quick read order and conflict precedence. Short descriptions are now required; equipment selling remains removed; separately approved audio work remains active despite stale text in the recipe module.
- No in-game attribution. All existing UI/audio/font/counter/result instructions, original target images, and prior raw notes retained.
- Final developer report must be maintained in the repository's /docs/PROJECT_STATUS.md, with actual status, errors, checks and coordinator validation steps.

## Verification of this handoff

All source assets and supplied source/addendum bytes were checked by SHA-256; new PNGs are 32×32, with exact roster coverage. Unlock totals and demand examples were checked against the supplied tables. Relative document links and ZIP integrity were checked. No development repository files were edited, no newer push was certified, and no new game implementation/test execution is claimed.

The prior result-preview validation remains scoped to its own artifact. The preparer does not claim rendered tutorial fit, new recipes in-game, audio listening, or fresh gameplay results; these are required implementation-agent checks.

## Retained cumulative history

# Ketik Saji — cumulative request package v005

19 November 2026 (WIB)

This version adds a concrete proposal for end-of-day, win, and lose menus (R-01), the actual downloaded Grape Soda font, and the coordinator clarification that attribution stays on itch.io (F-02). It retains the UI assets and detailed analysis requested in UI-01/UI-02. It carries forward all active v001 audio, Settings slider, transition fade, and one-panel tutorial requests. The cleaned instructions are derived from the coordinator's messages; original wording is retained alongside them.

## Added in v005

- `08_RESULTS_WIN_LOSE_DESIGN.md`: three-screen proposal with copy, hierarchy, art reuse, authoritative field bindings, exact outcome rules, progression/retry/main-menu actions, audio policy, and checks.
- `previews/RESULT_MENUS_PREVIEW.html`: self-contained interactive design preview with example values and actual supplied art/font. The world is a layout placeholder; it is not a running game.
- Original downloaded `provided_assets/fonts/GrapeSoda.ttf`, verified with fontTools and selected text-width/glyph checks. The prior missing-font descriptions are updated.
- Developer-only font source/credit reference; F-02 explicitly keeps attribution off game screens because the coordinator says it is on itch.io.
- S-01/R-01/F-02 raw wording. All prior requests/assets retained. v005 supersedes v004 for current cumulative intake.

## Carried forward from v004

- Three tiles and three total items per long counter are now explicit coordinator-confirmed quantities.
- Document 07 replaces the hypothetical five-tile example with the real three-tile counter requirement.
- Checks require simultaneous occupancy of all three tiles, independent middle-slot retrieval/refill, and rejection of a fourth separate stored item.
- Raw C-02 wording is retained. All prior requirements and assets remain in this cumulative ZIP, which supersedes v003.

## Carried forward from v003

- `07_LONG_COUNTER_ITEM_SLOTS.md`: the cleaned counter requirement, per-tile occupancy/interaction guidance, explicitly labeled technical interpretations, and verification checks.
- Original `image(20261119-153901).png` screenshot, unchanged, under `references/gameplay/`.
- Raw request C-01, updated cumulative instructions, and counter status-report entry.
- All v002 content and available assets retained; this ZIP supersedes v002 for implementation intake.

## Carried forward from v002

- Five original target images, each visually matched to its actual menu. Filename mapping is explicit: `image(8).png` main menu; `image(9).png` Edit Menu; `image(10).png` equipment; `image(20261119-152343).png` ingredients; `image(20261119-152353).png` HUD detail.
- Screen-by-screen composition, approximate reference coordinates, layout adaptation, static-caption versus dynamic-text handling, icon scale, state styling, scrolling, focus, input routing, and existing integration entry points.
- Full inventory and role description for 41 UI PNGs and two decoration PNGs. Source dimensions and alpha bounds were measured. The progress atlas was visually identified as ten 48×16 frames.
- A decision table for mockup placeholders versus earlier explicit instructions, plus absent artwork and technical defaults.
- The required developer instruction to maintain the actual repository's `/docs/PROJECT_STATUS.md`.
- Earlier cleaned playtest brief and raw coordinator notes as reference context; these are not a claim that all old bugs still reproduce.
- All eight previously supplied audio files, unchanged, so this cumulative handoff is self-contained for available assets.

## Preserved from v001

Randomized click pool without consecutive repetition; error and correct-serving cues; BGM only in main menu and Serving; 191.392-second loop boundary; five-second outgoing fades across scene/stage transitions; in-game Settings BGM slider superseding the earlier exclusion; simple explanatory tutorial panel; explicitly labeled unresolved audio and tutorial choices.

## Package structure

| Path | Contents |
| --- | --- |
| `README_START_HERE.md` | Operating brief and read order for the developer agent. |
| `01_IMPLEMENTATION_REQUESTS.md` | Cumulative tutorial/audio/Settings instructions with updated UI pointers. |
| `02_COORDINATOR_REQUEST_LOG.md` | Raw request wording and source attribution, including the new UI turns. |
| `03_UI_VISUAL_IMPLEMENTATION.md` | Detailed screen analysis and implementation guidance. |
| `04_UI_ASSET_CATALOG.md` | All 43 PNGs mapped by exact filename and role. |
| `05_DECISIONS_AND_ACCEPTANCE.md` | Differences, gaps, provisional choices, and acceptance checks. |
| `06_PROJECT_STATUS_REPORT_INSTRUCTION.md` | Developer-maintained report requirements and template. |
| `07_LONG_COUNTER_ITEM_SLOTS.md` | Latest per-tile counter capacity requirement and checks. |
| `references/gameplay/` | Original counter screenshot for C-01. |
| `08_RESULTS_WIN_LOSE_DESIGN.md` | End-of-day / win / lose design proposal and behavior. |
| `previews/RESULT_MENUS_PREVIEW.html` | Self-contained three-screen HTML preview. |
| `provided_assets/fonts/` | Original GrapeSoda.ttf and developer source/credit reference. |
| `provided_assets/ui/` | Original extracted PNGs from ketik-saji-ui-art.zip, preserving subfolder names. |
| `provided_assets/decor/` | Original two PNGs from mega mendung pixelated.zip. |
| `provided_assets/audio/` | Original eight sound files from SFX.zip; its original `to use/` prefix is recorded in the integrity manifest. |
| `references/targets/` | Original five visual targets without editing or renaming. |
| `references/earlier_playtest/` | Prior cleaned brief and raw playtest notes. |
| `ASSET_INTEGRITY.json` | Source-to-package mapping and SHA-256 checksums. |

No target screenshots were reinterpreted as runtime textures. Source ZIPs are unpacked into the package instead of duplicating them as nested archives. The supplied asset bytes are unchanged.

## Scope and verification limits

The report preparer inspected both UI ZIPs, opened all PNGs, checked reference identities, measured image dimensions/transparency, and read existing UI integration points in the previously reviewed snapshot `6991131023619dead7c7f63b80d70d10d382c2ac`. This was an asset analysis and handoff preparation task; it did not fetch or certify a newer GitHub push, edit the repository, integrate assets, run new game tests, or confirm new audio/UI behavior.

Exact main-menu background/logo, unique finished dish artwork were not in the earlier UI delivery. Grape Soda is now included separately in v005. The coordinator reports all art is complete; this does not certify receipt of any additional background/logo/dish files. Provisional defaults and visual conflicts are enumerated in document 05 for a concrete reviewable implementation, without presenting them as new coordinator approval.

The v003 preparer additionally viewed the counter screenshot and preserved it byte-for-byte. No fresh repository audit, counter implementation, or runtime test was performed for C-01.

For v005 the preparer read the original font page and author-linked download, downloaded and parsed the original font, and prepared the HTML design artifact. Local browser rendering was unavailable because the browser process could not open its required socket in this environment; no rendered-browser or game-runtime validation is claimed. Static HTML/resource checks, font metadata/glyph/text-width checks, and JavaScript syntax checks are recorded separately from that limitation. No repository files were modified or new game tests run.
