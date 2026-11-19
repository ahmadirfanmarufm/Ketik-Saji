# End-of-day, win, and lose menus — design proposal

Final note: [10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md) applies. Equipment selling remains out of scope; do not introduce a sale action or prominent sale UI based on historical ledger examples.

Version 005 · 19 November 2026 (WIB) · Source R-01; attribution clarification F-02

The coordinator asked for these missing screen designs and identified the game's font as Grape Soda. This document and the companion interactive HTML are a concrete design proposal using the resources already supplied. The proposed copy, layout, and new navigation actions are not represented as prior coordinator approval. Existing settlement, closing, and Day 7 outcome rules remain authoritative.

Open [RESULT_MENUS_PREVIEW.html](previews/RESULT_MENUS_PREVIEW.html) locally and switch between **End of day**, **Win**, and **Lose**. It is self-contained, uses the actual downloaded font and supplied art, and needs no internet connection. The world behind the panel is a layout placeholder; the game keeps its real frozen restaurant. Its figures are sample data, and its buttons describe intended destinations instead of controlling a live game.

## 1. Shared visual family

Use a wooden side panel over the restaurant, keeping the batik HUD and a substantial portion of the world visible. This follows the previously approved side-result direction and the supplied shop/menu art. Avoid switching to a completely unrelated full-screen score screen.

At the 1600 × 900 reference composition, the proposed panel canvas is approximately x=850, y=55, width=700, height=790. Its content insets are roughly 52 pixels left/right and 35–45 pixels top/bottom. These are reference-space measurements, not absolute Godot offsets. Use the actual world safe area and viewport to anchor right with a margin; shrink decorative spacing before allowing text or controls off-screen. The preview uniformly scales this design to demonstrate the composition; the implementation must check real font sizes at the supported window sizes.

Use `others/board-backdrop-popup-menu.png` for the narrow/tall board family, preserving borders and plank texture when adapting its aspect. Use `buttons/button-long.png` under dynamic Grape Soda button captions. The new titles have no raster caption PNGs, so render them with the actual font rather than fabricating a source asset. Existing static raster captions elsewhere may remain as supplied.

Headings are warm white with a brown outline/shadow, matching the other target screens. Main content is dark brown on ochre wood. Green/olive accents distinguish success and positive cash; restrained dark red distinguishes missed orders/shortfall. Outcome words and numeric comparison communicate the result as well as color. Do not add new trophies, characters, badges, or victory artwork that the implementation would need an artist to produce.

Suggested reference-space typography: title 48 px, hero cash 64–72 px, main row/button labels 24–32 px, and compact secondary order splits 16 px. Grape Soda is a pixel-style font; start with its native 16-pixel grid and suitable multiples where practical, then verify engine rendering at the actual UI scale. The font's short vertical forms mean nominal font size alone does not predict readable ink height. Use stable line heights and fit full labels, rather than relying on compressed X scaling.

Keep the footer outside the content scroll area. If optional financial rows or longer localized values require more room, scroll the middle content; do not hide Lanjut/retry/navigation behind overflowing text. Titles and the main cash comparison remain visually stronger than the ledger.

All screens show actual settled state, disable world actions, clear active typing focus, and block click-through. Decorative art and child labels ignore input; real Buttons receive it once. Results cannot be dismissed with Escape back into the finished service. Keep an established results-safe pause/navigation route if the current game provides one. Opening results is not a second request to settle the day.

There is **no attribution text or credits button added to the game screens**. The coordinator confirmed attribution is already on the itch.io page. Font source/credit documentation stays in this handoff for developer reference.

## 2. Ordinary end of day

### Visible content and hierarchy

| Position | Copy / content | Binding |
| --- | --- | --- |
| Heading | `Hari {day} selesai` | Settled day index. |
| Small optional line | `Sampai besok!` | Proposed short atmosphere copy; omit if space is tight. |
| Main number | `Kas akhir` then formatted final cash | `end_cash`, already after settlement and electricity. |
| Compact money rows | `Kas awal`, `Pendapatan`, `Belanja bahan`, relevant nonzero equipment/sale/refund rows, `Listrik` | Exact authoritative fields, grouped only for presentation. |
| Two compact count columns | `Pesanan selesai` / `Terlewat` | Completed and failed accepted orders, with small Makan/Online splits. |
| Next-day line | `Perkiraan besok: {n} tamu` | Current settled forecast; do not present it as an immutable next-day quota. |
| Demand effect | `Pengurang tamu: {before} jadi {after}` when meaningful | Existing penalty debt before/after, not a cash fine. |
| Footer | `Lanjut` | Advance exactly once to next-day Planning through the root owner. |

Show revenue as dine-in plus online revenue. Keep purchases negative and refunds/sales positive. Equipment purchase, equipment sale, and refund rows can be omitted when their value is zero; this is a proposed density reduction. Do not bury material actual spending/refunds or remove the underlying report. If separate revenue lines are desired for inspection, use a compact optional detail disclosure, not an always-expanded paragraph. The preview shows five illustrative money rows without a separate details control.

Financial reconciliation is:

`end_cash = begin_cash + dinein_revenue + online_revenue + fixture_sales + refunds - ingredient_purchases - fixture_purchases - electricity`

Use the current controller's accounting fields rather than calculating a new spendable balance in UI. The example in the preview reconciles: Rp 100k + Rp 160k - Rp 30k + Rp 2k - Rp 4k = Rp 228k. These numbers do not set game balance. Negative daily cash stays signed if the game allows it; it is not by itself a new early game-over trigger.

For the order counts, a failed accepted online order counts as missed; an ignored/unaccepted offer does not. A rejected wrong-food attempt does not itself become an extra failed order. The compact Makan/Online split preserves the source report's breakdown without a fixed ticket rail. Hide the demand-effect line when unchanged and zero, while preserving the next-day forecast when available.

Use this screen for Days 1–6 and ordinary extra-mode day results. Do not show it as a mandatory extra stop before the Day 7 outcome: Day 7 can use the win/lose variant directly after the same completed settlement.

### Lanjut behavior

Bind to the existing `GameRoot.request_continue_from_results()` or its current equivalent. Lock the button while a transition is accepted. Advancing changes the day and enters Planning once; it does not re-credit income, deduct electricity, issue refunds, clear stock twice, or reroll penalties. If a request is rejected, keep the panel in a valid state and report the real issue.

## 3. Win state

| Position | Proposed copy / behavior |
| --- | --- |
| Heading | `Target tercapai!` |
| Subheading | `Hari 7 selesai` |
| Main number | `Kas akhir` and settled final cash. |
| Small context | `Setelah listrik` |
| Comparison row | `Target` and configured Day 7 cash goal. |
| Compact success band | `Lebih Rp {difference}k` using the central formatter; `Pas target` when exactly equal. |
| Short message | `Warungmu berhasil!` / `Mau lanjut jualan?` |
| Primary action | `Lanjut jualan` → optional extra mode, Day 8 Planning, same run. |
| Secondary action | `Menu utama` → actual main-menu route. |

Read the **latched WON outcome** from the run/settlement owner. The comparison uses final current cash after electricity and legitimate settlement refunds. Revenue earned over the week is not the win criterion. Exact equality wins. The target is configuration data; Rp 700k in the prototype is an example, not an approved new constant.

For a tiny positive difference that rounds to zero in the display formatter, prefer `Target tercapai` rather than misleading `Lebih Rp 0k`. Never derive win/lose from rounded text. The success example uses Rp 735k against Rp 700k, a Rp 35k surplus.

`Lanjut jualan` binds to the existing `request_extra_mode()` or current equivalent, which accepts Day 7 WON and transitions once to Day 8 Planning. Retain cash, fixtures, and other existing continuation state. Do not start a fresh run or apply a second mandatory goal. Later extra-mode cash cannot undo the Day 7 victory. If the implementation already has different approved continuation semantics, preserve and document them.

`Menu utama` is a proposed explicit terminal navigation option. It must return to the real main menu and leave no old run simulation or callbacks active. It must not call the application's quit function behind a menu label. If that route is absent in the current branch, implement the minimal route under the existing scene/root ownership and report it. Do not provide a cosmetic clickable button with no behavior.

## 4. Lose state

| Position | Proposed copy / behavior |
| --- | --- |
| Heading | `Belum tercapai` |
| Subheading | `Hari 7 selesai` |
| Main number | `Kas akhir` and settled final cash. |
| Small context | `Setelah listrik` |
| Comparison row | `Target` and configured Day 7 cash goal. |
| Compact shortfall band | `Kurang {formatted shortfall}` |
| Short message | `Target belum tercapai.` / `Coba strategi baru, yuk!` |
| Primary action | `Coba lagi` → deliberate fresh Day 1 run through the game owner. |
| Secondary action | `Menu utama` → actual main menu. |

Use the latched LOST outcome for the Day 7 test. The example is Rp 648k against Rp 700k, a Rp 52k shortfall. When a small real shortfall would round to zero, use `Masih kurang` or a similarly accurate compact state label instead of implying the exact amounts are equal. Keep the same central money format and exact accounting.

The retry button is a **proposed new terminal action**, not a claim that a safe reset API already exists. Route it through the established new-run/scene creation owner. A fresh run resets day, wallet, fixtures, stock, deliveries, held items, customers/drivers, orders, timers, target outcome, penalty state, and transient UI by the normal initialization path. Preserve the player's Settings volume. Do not manually invoke `_ready()` or reset a selection of UI fields while old controllers keep running. Guard repeated clicks so only one new run is created.

Do not offer extra mode on LOST. Do not add a rescue grant, automatic retry, free cash, an early loss on a bad day, or a new deadline. The terminal choices happen after the already approved final test.

## 5. Existing code and authoritative fields

These were verified in the **previously reviewed** snapshot `6991131023619dead7c7f63b80d70d10d382c2ac`, not a fresh audit of the developer's latest push.

| Existing location | Relevant behavior |
| --- | --- |
| `scripts/ui/game_ui.gd::_refresh_results_panel()` | Basic side result panel already renders settlement rows and basic win/lose titles; it is not necessary to invent new result accounting. |
| `scripts/core/game_root.gd::request_continue_from_results()` | Validates ordinary result progression and advances through the run controller. |
| `scripts/core/game_root.gd::request_extra_mode()` | Validates Day 7 victory and advances to Day 8. |
| `scripts/economy/run_controller.gd::settle_day_once()` | Stores one settlement, charges electricity once, updates demand debt, and latches the Day 7 result. |

The settlement view includes `day_index`, `begin_cash`, `ingredient_purchase_total`, `fixture_purchase_total`, `fixture_sale_total`, `order_revenue_dinein`, `order_revenue_online`, `refund_total`, `electricity_charge`, `end_cash`, `completed_dinein_count`, `completed_online_count`, `failed_dinein_count`, `failed_online_count`, `penalty_debt_before`, `penalty_debt_after`, `forecast_next_day_potential`, `forecast_next_day`, and `day7_outcome`. The run view provides the configured target/current outcome through its current contract. Inspect current field names when implementing and report genuine mismatches; do not patch missing data with a zero that makes a false result appear correct.

Normal results appear only after the true four-part automatic close guard drains unspawned arrivals, outside diners, seated diners, and accepted open online orders. Settlement and cleanup finish before the menu becomes actionable. No manual close-day control is introduced.

The inspected old UI lacks explicit retry/main-menu result actions. Those are integration work in this proposal, not features claimed complete. Keep existing story/epilogue copy separate from mandatory result data, and do not use it to reintroduce the unwanted tutorial sequence.

## 6. Audio and transitions

All result buttons use the existing common random click pool with no consecutive repetition. The requested mining cue remains tied to successful `saji`, not to opening the win menu. No new victory/defeat sound was supplied or requested; do not assign glass/error audio to losing by assumption.

No new BGM stage is added for results: the explicit approved music locations remain Serving and main menu. Proposed handling is for Serving music to begin its five-second fade when Serving ends, continuing across closing/results; ordinary results are silent after that fade. Win/lose results do not restart the track. Retry goes to silent Planning. Returning to the main menu uses its approved BGM/loop/volume policy. This resolves the otherwise unspecified results behavior as a technical default and should be recorded in status, especially if the current implementation behaves differently.

Keep audio alive across any scene teardown needed by return-to-menu/retry. Retain the Settings slider's choice; a result action must not reset the player's volume to the programmer default. No victory stinger, new track, crossfade, or animation dependency is required.

## 7. Font integration

The actual original font is included at `provided_assets/fonts/GrapeSoda.ttf`. See [FONT_SOURCE_AND_CREDIT.md](provided_assets/fonts/FONT_SOURCE_AND_CREDIT.md) for the author, verified source URLs, and recorded license statement. User F-02 explicitly places attribution on itch.io; add no font attribution to these game screens.

Use this font for new result headings, body copy, dynamic amounts, and button labels, and as the chosen dynamic UI font throughout the pending integration. Import it as a normal FontFile/Theme resource and check pixel rendering/antialiasing settings on the project's actual Godot version. Do not treat the caption PNG folders as font resources. The downloaded file has one Medium face, not supplied Regular/Bold variants; use size, color, outline, and existing requested typography emphasis deliberately rather than referencing nonexistent files.

The inspected 359-glyph font supports Latin text, numbers, `Rp`, punctuation, ASCII hyphen, and slash. It does **not** contain the arrow `→`, mathematical minus `−`, or checkmark `✓`. Therefore the preview uses `jadi`, ASCII `-`, and the existing checkbox sprite where relevant. Use icon assets or explicit fallback glyph resources if those symbols are needed elsewhere; do not let them silently turn into missing-glyph boxes.

## 8. Acceptance checks

- Ordinary day result reconciles ledger values and cash, shows order breakdown/forecast, and continues exactly once to next-day Planning.
- Pending accepted online orders keep service open; results and electricity do not occur early.
- Reopening/refreshing a result view does not mutate money, refund shipments twice, reroll penalties, or advance the day.
- Day 7 cash exactly at target shows win; one currency unit below shows loss regardless of rounded display.
- Win alone offers continued play. Entering extra mode preserves the run, starts Day 8 once, and does not reevaluate the original win later.
- Loss offers safe fresh-run retry and actual main-menu navigation; no extra mode. Repeated clicks do not create multiple runs/scenes.
- Menu utama never secretly quits. New run removes old customer/order/delivery/input subscriptions while preserving Settings volume.
- At normal and supported smaller window sizes, Grape Soda loads, all amounts/labels are readable, footer buttons stay inside the board, and long/optional rows scroll instead of overflowing.
- Mouse/keyboard focus cannot act on the restaurant behind results; dismissal input cannot resume a finished service. All actions emit the common click cue once under the chosen physical-input policy.
- Serving music fades for five seconds into results under the proposed policy; no new win/lose BGM or outcome SFX is invented. Main-menu return and retry preserve the current volume.
- There is no in-game attribution text. Developer source documentation remains available to check against the coordinator's existing itch.io credits.

The HTML preview is a design artifact, not a tested game build. Update `/docs/PROJECT_STATUS.md` with implementation status, navigation/reset decisions, visual/audio checks, and remaining differences from this proposal.
