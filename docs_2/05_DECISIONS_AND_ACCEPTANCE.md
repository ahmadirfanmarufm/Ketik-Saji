# Decisions, gaps, and acceptance checks

**FINAL UPDATE:** Read [10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md) first. The thirteen final dish icons, required recipe descriptions, no-selling scope, and exact tutorial text supersede older gaps/content here. The original Grape Soda font is included.

Version 002 · 19 November 2026 (WIB)

This file prevents the coding agent from interpreting illustrative screenshot content as a new gameplay specification. The cleaned instructions derive from the coordinator's raw requests; the earlier playtest source and its structured brief are preserved under `references/earlier_playtest/`.

## 1. What is directly requested

| Source | Active requirement |
| --- | --- |
| UI-01 / UI-02 | Analyze every supplied design after the assets arrive; map filenames to menus; provide detailed implementation instructions and include the original targets in the handoff. |
| Earlier playtest and follow-up | Simplify shop text, fixed world-slot equipment buying, actual sprites, bold equipment name/price with normal description underneath, checkmarks, adjacent ingredient detail, compact spaced money values, wider readable HUD, numeric financial goal, correct Escape/Pause behavior, and plate-only dirty-table marker with `meja kotor` tooltip. |
| T-01 | Reduce tutorial to an explanatory panel rather than a step sequence. |
| A-01 | Random click sounds without consecutive repetition for keyboard and UI buttons; incorrect-key glass sound; correct `saji` serving mining sound; main-menu/Serving BGM; 191.392-second loop boundary. |
| A-02 | Five-second outgoing BGM fade across scene/stage changes. |
| A-03 | Settings volume slider, superseding the earlier exclusion. BGM is the contextual scope. |
| P-02 | A cumulative ZIP after each update. UI-01 temporarily deferred ZIP generation until assets arrived. |
| Earlier project reporting request | Keep a Markdown status report in the repository's `/docs` directory, regularly updated so the next push can be inspected. |

The original domain specifications are older context. Where they still mention a storage `Belanja` button or verbose shop state, the later coordinator request for click-container then type `beli` and minimal available commands takes precedence.

## 2. Reference differences and proposed integration treatment

These are explicit differences, not hidden design changes. Adopt the conservative treatment below within the already authorized implementation, and record any different choice. Details marked unresolved are not newly approved by this report.

| Target detail | Earlier request / existing contract | Treatment for this implementation |
| --- | --- | --- |
| Money is `100000`, `Rp20.000`, or similar | Space after Rp, compact k, at most one decimal | Keep the central formatter: `Rp 100k`, `Rp 20k`, `Rp 4.5k`. Runtime values remain exact integers. |
| Ingredient shop shows `Total Kapasitas 4/15` | Explicitly remove the total-capacity line | Omit the aggregate. Retain separate actual physical-slot chips. |
| Only two occupied stock pills drawn | Physical containers may have more slots | Render real slots, including quiet empty ones and independent duplicate-ingredient slots. No S1/S2 labels. |
| Edit Menu shows `Aktif` even beside the unchecked duplicate | Replace textual active marker with checkmark | Use the supplied check/uncheck pair without redundant state text. |
| Repeated sample dishes, ingredients, or Kompor cards | Real definitions have stable IDs | Use actual unlocked recipe/catalog entries. Do not create duplicates or change pricing. |
| Name/price in parentheses | Equipment and Edit Menu should use a colon | Use `Kompor: Rp 60k` / `Nasi Telur: Rp 20k`, with real values. |
| Recipe panel has a prose blurb | Detail must be dish name then ingredient lines, alternate preparations only | Use ingredient list; omit redundant cooking text and prose. |
| Right recipe panel has a gap and is partly outside frame | Earlier request says directly adjacent, no gap; running UI must be usable | Abut panels and fit both inside the viewport. Report any necessary small-window compromise. |
| Equipment row shows `+` and footer only Batal | Equipment buy requires explicit confirmation; earlier footer should say Harga | Let `+` select or open a real confirmation. Charge only after confirmation, preserving fixed slot. Retain Harga/Beli where the existing selected-item flow needs them. |
| Gray equipment row says unaffordable despite sample cash covering price | Runtime purchase validator determines affordability | Bind gray state/status to real eligibility; sample numbers are inconsistent. |
| A HUD Beli alat button exists | Buy flow is physical-slot-first; no slot chooser inside shop | Style the existing affordance, but do not bypass the world slot or resurrect a slot picker. Report its precise action. |
| Fixed HUD Ketik field | Existing approved prompt is near selected interactable; one parser | Provisional: HUD mirrors existing prefix read-only, preserving selected-object dialogue. Replacing that dialogue requires a clear coordinator decision. |
| Target sign says `16 dari 30` | Existing customer HUD uses unspawned expected queue; financial target is separate | Keep authoritative count meaning and report the displayed label. Do not equate remaining queue, served count, and cash goal. |
| Lower HUD scroll/exit icons lack action labels | Pause must be accessible through HUD; Exit destination was left open | Bind to existing documented controls with hover names. Keep a direct Pause route and explicit Exit inside Pause. |
| New art includes horizontal timer atlas | Older approved UI specifies circular countdown rings | Do not silently replace every ring. Bar usage is unresolved; default to current validated indicator behavior and report any chosen substitution. |
| Ingredient shop lacks visible Cancel | Modal must remain dismissible and Escape must not move player | Keep existing dismissal and optionally Batal in shared style. No checkout on dismissal. |
| Clouds exist separately and inside menu-game.png | HUD backdrop already contains its corner ornaments | Use standalone clouds for main-menu corners or intentional recomposition; avoid duplicate stacked ornaments. |
| Target frames show live world/customer imagery behind Planning menus | No gameplay phase change was requested through this art delivery | Preserve existing phase eligibility/timer behavior; screenshots are not approval to enable cooking in Planning. |

## 3. Missing material and bounded fallback choices

| Gap | Evidence | Practical handling |
| --- | --- | --- |
| Separate main-menu background | Neither new archive supplies that photograph/interior image. `menu-game.png` is a batik HUD strip. | Reuse current approved background if available on the live developer branch; otherwise report temporary appearance. Exact match remains blocked by the absent asset. |
| Separate Ketik Saji logo | No logo PNG/SVG appears in the delivered ZIPs or the inspected art list. | Reuse current logo if present later; do not claim a mockup crop is a final supplied logo. |
| Dynamic pixel font | Resolved in v005: coordinator identifies Grape Soda; original TTF downloaded and included. | Use GrapeSoda.ttf for dynamic UI and new result-screen text. Keep attribution off game screens per F-02. |
| Finished unique dish sprites | New art gives status icons, not full recipe art. | Reuse existing recipe/composite sprites. Report unmatched final dish art. |
| Dedicated Settings/Pause/tutorial/confirmation screen designs | No target or dedicated caption set delivered for these screens. | Retain existing layouts and controls, using shared board/button style where feasible. The BGM slider and simple tutorial panel remain required. |
| Hover/pressed states | Only normal button surfaces supplied. | A mild tint, focus outline, or small pressed offset is a proposed technical treatment. |

Do not stop integration of the supplied screens merely because exact background/font matches are missing. Make the completed portion reviewable and report those limits clearly.

## 4. Provisional implementation details to disclose

Document 01 already labels shared click history, layering generic click with outcome sound, physical-input deduplication, loop start at zero, transitions between music-enabled scenes, tutorial entry points, audio while paused, and settings persistence. These remain technical interpretations or open choices.

This UI report additionally proposes aspect-preserving composition, optional nine-slice adaptation, disabled-row art use, focus/pressed feedback, the read-only HUD prefix mirror, how `+` reaches equipment confirmation, the meaning of the daily electricity badge, stock-chip surface reuse, and ten-frame ratio mapping. Report any departure that changes visible behavior. None authorizes a new transaction model, a replacement countdown owner, or an unrequested save system.

Zero/negative/sub-thousand currency formatting and rounding ties are not specified by the two numeric examples. Preserve the existing central formatter unless a real issue requires adjustment; explain its edge cases in the status report. Do not introduce different shop and HUD rounding rules. Any needed sample values in this brief illustrate typography only.

## 5. Acceptance checks for the developer

Run appropriate existing automated checks and a focused real-window review. These checks are for the future implementation; the report preparer did not execute them against new UI/audio code.

| Area | Scenario | Pass condition |
| --- | --- | --- |
| Asset import | Import all 43 PNGs on the actual supported Godot version/export target | No missing resources, bad case-sensitive paths, unexpected opaque borders, or blurry low-resolution sprites. |
| Reference identity | Open the four full-screen categories and compare with the correctly named target | Correct board family, palette, title/button art, relative proportions, and decoration placement. |
| Main menu | Click Play, Pengaturan, and Keluar through the actual route | Each visible live control acts once; background/logo fallback is explicitly recorded if used. |
| HUD fit | Normal window, 1600×900, and a supported smaller window | Day, cash, financial target, appropriate customer state, typing, and controls are readable. No world queue is hidden by decorative bounds. |
| Modal routing | Click title, board blank area, item icon, footer, and dimmer | No player teleport or underlying world command; actual action controls act once. |
| Tooltips | Click the selected utility's prompt and hover a dirty table | Utility routing stays correct; dirty plate shows `meja kotor`, no persistent Kotor sentence. |
| Edit Menu | Preview a recipe, toggle its checkbox, cancel, reopen, then save | Preview and selection remain distinct; cancel discards, save validates, checks reflect committed/pending state correctly. |
| Recipe detail | Preview recipes with alternate preparation and long ingredient names | Correct dish/ingredient list, only alternate preparation labels, adjacent board readable inside viewport. |
| Equipment | Open from one world slot; inspect affordable/unaffordable entries; confirm once | Only compatible choices, correct icon scale, bold name/price and normal description, real disabled state, one charge/placement to selected slot. |
| Ingredient shop | Open via container → `beli`; exercise zero/max quantity, capacity and money limits | Exact container stock/slots, valid basket, correct unit/total prices, no redundant cash/total capacity/stok labels. |
| Lists | Open catalogs long enough to scroll to the last row | Titles, stock and footer stay fixed; final row/action remains reachable and unobscured. |
| Money | Compare HUD, both shops, electricity, confirmation, recipe rows, and results | One spaced compact formatter; no accounting based on displayed rounded values. |
| Escape/Pause | Close a shop; cancel a selected interaction; open Pause from neutral or HUD | No movement on cancellation, correct input priority, pause freezes gameplay clocks, Resume restores state. Ordinary Serving shop keeps its existing live timing. |
| State indicators | Waiting/eating/online/delivery transitions; if using atlas, test full and zero ratio | Correct real state, identity, and location; no duplicate clocks or whole-atlas display. Document any ring-to-bar choice. |
| Click audio | Rapid keyboard, mouse, and keyboard-button activations | Click randomness uses all five sounds over repeated trials, no consecutive repeat, no duplicate sound per physical activation under chosen policy. |
| Outcome audio | Invalid character; correct/incorrect/duplicate `saji` attempts | Glass on rejected key; mining only on successful correct serving once, not on failed request. |
| Music loop | Listen across 191.392s at least once in a music-enabled stage | Loop uses the requested boundary, no unintended trailing 2.4755s from the source file. |
| Fade and slider | Serving→Planning; scene changes; move slider during five-second fade | Music survives scene teardown for fade, Planning becomes silent, current user volume multiplies fade and persists into subsequent playback per chosen Settings policy. |
| Tutorial | Start/reopen help during normal play | One concise explanatory panel with current controls; no forced multi-step sequence, stale verbs, or new elaborate onboarding. |
| Report | Review `/docs/PROJECT_STATUS.md` in the resulting push | Current date/commit context, implemented/partial/missing status, evidence, known errors, art fallbacks, and remaining coordinator decisions are explicit. |

Any failed visual/audio check should be recorded with a short reproduction and the exact screen/state, not hidden behind a generic `tests pass` sentence. Existing headless tests do not prove the artwork is legible or the loop is seamless.

## v003 addition: long counters

Request C-01 requires one independent item position per usable tile on the long counter shown in the new reference. See [07_LONG_COUNTER_ITEM_SLOTS.md](07_LONG_COUNTER_ITEM_SLOTS.md) for the source screenshot, occupancy/interaction interpretation, and acceptance checks. Existing UI, audio, and tutorial requirements above remain active.

## v004 clarification: exact counter capacity

C-02 confirms that each affected long counter is three tiles long and holds three items simultaneously, one per tile. This exact count replaces the generic capacity example in the prior counter brief. Verify all three slots independently, including removing and refilling the middle slot while both ends stay occupied.

## v005 addition: result screens and confirmed font

R-01 requests end-of-day, win, and lose screen design; the concrete proposal and interactive preview are in document 08. Grape Soda is the coordinator-selected font and is now included. Return-to-main-menu and fresh-run retry are proposed terminal navigation actions that must have real owner-controlled implementations. F-02 confirms attribution is on itch.io; no in-game credits are added. Other exact visual/copy details in document 08 remain a proposal, not a newly approved economy rule.
