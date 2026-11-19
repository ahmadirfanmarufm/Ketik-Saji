# UI visual implementation — detailed target analysis

**FINAL UPDATE:** Read [10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md) first. The thirteen final dish icons, required recipe descriptions, no-selling scope, and exact tutorial text supersede older gaps/content here. The original Grape Soda font is included.

Version 002 · 19 November 2026 (WIB)

This cleaned implementation document derives from coordinator messages UI-01/UI-02, the five supplied target images, and earlier explicit UI requests preserved in the raw log. It describes what can be observed separately from proposed implementation details. Read [05_DECISIONS_AND_ACCEPTANCE.md](05_DECISIONS_AND_ACCEPTANCE.md) before copying mockup text or binding an action.

## 1. Exact reference-to-menu mapping

These assignments were visually checked. Do not infer the menu from the numeric suffix alone.

| Original filename | Actual category | Resolution | Principal target |
| --- | --- | --- | --- |
| [image(8).png](<references/targets/image(8).png>) | Main menu | 1600 × 900 | Warung background, logo, centered three-button stack, corner cloud ornaments. |
| [image(9).png](<references/targets/image(9).png>) | Edit Menu + Resep | 1600 × 900 | Narrower menu board, separate recipe board on its right, checkboxes, dish cards, Batal/Simpan. |
| [image(10).png](<references/targets/image(10).png>) | Belanja Peralatan | 1600 × 900 | Wide shop board, electricity badge, normal/disabled equipment cards, Batal. |
| [image(20261119-152343).png](<references/targets/image(20261119-152343).png>) | Belanja Bahan | 1600 × 900 | Stock chips, ingredient rows with minus/quantity/plus, shopping total and Beli. |
| [image(20261119-152353).png](<references/targets/image(20261119-152353).png>) | Persistent HUD strip detail | 426 × 822 | Calendar, coins, target sign, typing display, planning buttons, icon buttons, batik and clouds. |

The 426 × 822 HUD image is a cropped design detail, not a separate gameplay aspect ratio. The four full frames establish a 16:9 composition. All positions below are approximate measurements of visible artwork at 1600 × 900; they are not engine coordinates or exact transparent texture rectangles.

## 2. Shared appearance and construction

### 2.1 Art layers

Use warm ochre wooden boards with darker plank seams, brown beveled item/button surfaces, dark outlines, and cream lettering with brown edging/shadow. The persistent left strip uses detailed dark batik rather than a plain color. Mega mendung clouds decorate corners and may overlap adjacent world space. The restaurant remains visible behind gameplay menus through a translucent dark world scrim.

Keep artwork in separate layers: background/world, world scrim, HUD, popup boards, row/button surfaces, labels and icons, then genuinely modal confirmations. Board titles overlap the upper edge of their own panel and must not be clipped by the list's scroll area. The scrim should darken the world while leaving the HUD legible, as in the references. A decorative texture must not become an invisible input blocker.

All `font board/`, `font button/`, and `font main menu/` assets are finished transparent lettering images, not installable fonts. Use them for their exact static captions. Names, prices, counts, quantities, ingredients, electricity, and dynamic descriptions require actual Label/RichTextLabel text. The initial UI ZIP contained no TTF/OTF. In v005 the coordinator identified Grape Soda and its original TTF was downloaded: use `provided_assets/fonts/GrapeSoda.ttf` for dynamic UI text and new result headings. Do not assemble arbitrary text by cutting letters out of caption PNGs.

### 2.2 Import, scale, and transparent padding

Import UI textures losslessly with nearest filtering and no mipmaps for the normal UI presentation. Preserve RGBA transparency. The artwork mixes small pixel sprites with high-resolution raster lettering and decorations; nearest filtering alone does not make fractional scaling pixel-perfect. Inspect a captured running frame at the actual export/window scale.

Use aspect-preserving fits for icons, lettering, cloud decoration, and the batik strip. Do not stretch an equipment or ingredient sprite independently on X and Y. Wooden panels/cards can use constrained stretching or a carefully configured StyleBoxTexture/NinePatchRect when their target size requires it. Do not assume all textures use the same source pixel density.

Important examples: `button-long.png` is 80 × 32, while its nontransparent bounds are only `(3, 2)–(77, 30)`. A `container-item.png` canvas is 304 × 48 but visible pixels occupy `(6, 4)–(299, 42)`. Consequently a screenshot's visible 125-pixel-high card can occupy a larger texture canvas. Align visual edges using the measured alpha bounds in the catalog and keep stable layout containers around them; do not crop every asset independently and accidentally shift checkbox or label baselines.

The general popup board is 192 × 128 and the Edit Menu board 160 × 128. Their aspect ratios already approximate their corresponding reference boards. Prefer uniform full-board scaling at the reference composition, preserving plank proportions. If responsive layout needs a different aspect, preserve border/corner thickness and test horizontal seams; a generic nine-slice can visibly stretch wood grain. Slice margins below are not supplied metadata and must be chosen by inspecting the source art, not guessed as approved artist values.

Shared item background pairs: long 304 × 48 cards for the shops, short 192 × 48 cards for Edit Menu. Disabled counterparts already exist. Use the actual gray texture for disabled rows rather than a gray overlay that also washes out the label and icon. Use the checkbox's two matching 32 × 32 textures at the same canvas size; the checked texture extends above the unchecked mark, so preserve its top clearance.

Only a normal button texture is supplied. For hover/focus/pressed states, a small tint, focus outline, or slight content offset is an implementation suggestion. Keep text legible, reset the state on release/cancel, and do not invent purchased/disabled art. Focus must remain visibly identifiable when keyboard navigation is active.

### 2.3 Coordinate conversion and layout safety

The last reviewed `project.godot` uses a 640 × 360 viewport, a 1280 × 720 window override, `canvas_items` stretch, and nearest filtering. A 1600 × 900 reference maps approximately to logical coordinates by dividing both axes by 2.5 at that composition. Treat this only as an initial alignment aid. Runtime viewport sizing, camera/world transforms, UI safe areas, and minimum sizes still determine the final layout.

At reference size the solid HUD body occupies roughly 300 pixels of screen width (about 19%). Some corner decoration extends towards 426 pixels. Keep the interactive/safe HUD width separate from the decorative canvas width. `menu-game.png` is 511 × 1080 including transparent side space and clouds. Scaling it to 900 pixels tall yields a 426-pixel-wide texture canvas; reserving that entire canvas as a solid HUD would push the world too far right. The close-up demonstrates this distinction.

Use the existing safe-area and world-visibility calculations to place panels. Do not resize the restaurant footprint or hide driver/customer queues to make a board fit. Preserve world-to-screen anchoring for selected-object dialogue. Keep useful content inside the viewport even where the mockup's right-hand recipe board is cut off. At smaller widths, first reduce decorative spacing and fit panels within the available world area. Use scrolling for lists. If a two-panel detail view cannot remain readable, report the needed responsive compromise; do not silently allow its controls off-screen.

For a strict integer-scale world, UI high-resolution lettering may need its own canvas/layout strategy. Avoid changing the global viewport just to copy these large screenshots. Validate the current project at its normal window and at 1600 × 900 before making a viewport policy change.

### 2.4 Mouse and keyboard routing

All captions/icons placed inside a button should ignore mouse input so their enclosing button receives the action. All clouds, batik decoration, title lettering, and noninteractive status art also ignore mouse input. Actual buttons/cards stop and consume their event through the existing UI pathway. A modal's scrim/panel blocks world clicks across its covered area. Empty panel space must not teleport the player behind the menu.

Keep one click action per gesture: clicking a plus, checkbox, or row child must not also activate its parent or the world. Pointer events on selected-station dialogue retain the selected utility's intended behavior; they must not become floor clicks. Keyboard activation must not feed gameplay commands while a modal is focused. Closing a modal must not replay the dismissal input into the game.

The left `Ketik` box presents the existing parser's prefix/state. It does not create a second LineEdit parser or consume characters separately. Preserve the approved selected-object typing prompt unless the coordinator explicitly replaces it. A read-only HUD mirror is the provisional way to match this new design without losing the existing world prompt. Invalid characters retain shake/nonregistration feedback plus the newly requested error SFX, without the old per-letter error sentence.

Every UI button routes to the common randomized click SFX hook from document 01. A keyboard activation that also activates a UI button must respect that document's deduplication recommendation.

## 3. Main menu — image(8).png

### 3.1 Observed composition

The frame is filled by a pixelated photographic warung interior with people and shop furnishings. A dark olive/brown treatment makes the cream button lettering readable. There is no large opaque rectangular panel behind the center stack. The logo occupies the upper middle: gray handwritten-looking `ketik`, a tilted keyboard, a rice/egg plate, and large yellow `SAJI`. These elements form one visual identity above the buttons.

At reference size the logo occupies approximately x=550–1000, y=50–350. The three brown beveled buttons are centered around x=800 and span about x=655–950. Their visible vertical bands are approximately 410–520, 540–650, and 665–775. Maintain even gaps, shared widths, and a vertical stack; the changing label lengths must not change the button width. The `Pengaturan` lettering nearly fills its button and deserves a dedicated fit check.

Cloud decoration is cropped off the top-left corner and bottom-right corner. It does not cover the center actions. Use `mega mendung 1.png` for the large curled upper ornament and `mega mendung 2.png` for the flatter lower/right flourish, matching their silhouettes to the screenshot. Their original images contain transparent margins; position the visible cloud rather than aligning only the PNG canvas.

### 3.2 Asset assembly and actions

Use `buttons/button-long.png` as the surface and `font main menu/Play.png`, `pengaturan.png`, and `Keluar.png` as separate centered caption TextureRects. Size the caption to the interior safe rectangle with aspect preserved. The long button's native 2.5:1 canvas aspect and transparent outline give a useful starting point; adjust its displayed canvas while checking the visible bevel against the reference.

Recommended structure is a full-rect background TextureRect with cover-style aspect fill, optional tint ColorRect, independent logo TextureRect, centered VBoxContainer of three real Buttons with child caption art, and two corner ornaments. These are proposed node roles, not a requirement to replace existing menu scenes. Give each Button an accessible text/tooltip name even when its visible caption is raster art.

`Play` should invoke the existing start/resume entry point. Do not infer a reset-save behavior from the English label. `Pengaturan` opens the existing Settings and contains the requested live BGM volume slider. `Keluar` follows the existing intended quit route. Avoid redirecting the gameplay pause button to immediate quit merely because `quit.png` looks like an exit door.

The main-menu background and logo are visible in the target but absent as separate assets in both supplied ZIPs and absent from the inspected snapshot's art filenames. Record them as missing exact-match assets. Reuse any current approved implementation if present on the developer's newer branch. Otherwise use a clearly reported temporary treatment while keeping real live buttons. Do not crop the entire target into a fake main menu or present reconstructed logo art as supplied artwork.

Main-menu BGM follows document 01: use `Backsound.opus`, the 191.392-second loop boundary, Settings volume, and transition fade handling. The Settings panel has no supplied target screenshot; retain its existing control layout and apply the shared button/board style only where straightforward.

## 4. Persistent left HUD — image(20261119-152353).png

### 4.1 Top-to-bottom anatomy

The crop shows a dark batik column running down the entire left side. Its wooden right edge separates it from the restaurant, while clouds spill across that boundary near the top and bottom. `menu-game.png` already contains this batik column and corner ornaments. Use this as the main HUD backdrop; layering both standalone clouds over the exact same existing ornaments would produce duplicates. Standalone clouds are primarily needed for the main menu or a deliberately recomposed responsive treatment.

At the top, `paper-calendar.png` is a cream, slightly irregular sheet with a curled/shaded lower edge. Put `font board/hari-ke.png` near its top and dynamic dark text for the large current day with a smaller `/7` alongside. The image's example is day 1. Do not bake the day into a texture; continued play after Day 7 must use existing game rules rather than clipping a two-digit day.

Below, a rounded dark-gold/brown pill uses `others/panel-coin.png`, with the small gold `icons/coins36x36.png` at the left and the dynamic cash balance to its right. Despite its name, this icon is 32 × 32. The target shows `100000`; the approved money formatter still requires a spaced prefix and compact thousands, e.g. `Rp 100k`. Keep enough interior width for that output and for a negative balance if the game can produce one. Never store the rounded displayed value as money.

The next element is a wider horizontal plank sign, `others/board-target-customer.png`, with the red-edged white `font board/target-tamu.png` heading overlapping its upper part. The sample shows a very large dark red `16` and smaller `dari 30`. Read real customer-related counts from the existing service/run views, and state which counts are being shown. Earlier approved service HUD semantics use unspawned expected customers, not served customers or outside waiters. The mockup alone does not redefine that meaning. The Day 7 financial goal also still needs a visible numeric value; a customer sign is not a substitute for it.

Next is the raster `font board/ketik.png` title and a wide brown `buttons/textbox.png` beneath it. Align its left edge consistently with the HUD rather than the world panel. Inside, show current valid typing progress/ghost command read from the existing selected interaction. Preserve empty, focused, partial-prefix, invalid-feedback, and completed-command states without changing validator ownership. Shorten or wrap displayed choices if needed; do not hide the valid prefix under a decorative border.

Two long brown buttons follow: raster `font button/edit-menu.png` then `font button/beli-alat.png`. The bottom row contains two square `buttons/button.png` surfaces with `icons/menu.png` (a scroll/plate symbol) and `icons/quit.png` (exit arrow/door). The screenshot supplies appearance but does not fully specify what the scroll icon means. Preserve documented existing actions and supply concise hover names. Maintain a way to pause through the HUD during Serving; it can use an appropriately named existing button rather than treating an ambiguous icon as proof of an immediate-exit action.

### 4.2 Approximate close-up alignment

In the 426 × 822 crop, the paper occupies the upper-left roughly 150 × 135 visible region; the coin pill spans about x=20–250, y=158–215. The target sign reaches x≈292 with its heading around y=240 and count around y=290–360. The `Ketik` title begins near y=385 and the typing field runs approximately y=410–510. The planning buttons sit around x=50–230 at y=525–600 and 605–680. The square icon buttons occupy about x=60–130 and x=155–225, y=690–760. These are visual relative anchors; the crop is not a separate set of absolute Godot offsets.

Use a top-to-bottom layout with calibrated spacing rather than one stretched screenshot. Place the calendar, money, target, typing, and buttons as independent live components. Bind the existing phase-specific visibility: do not leave planning-only Edit Menu/equipment purchase actions available during Serving. Reuse the space for existing service-relevant information if needed. Preserve visible day, cash, numeric financial goal, and valid customer state at the normal window size.

The legacy global `Beli alat` flow must not restore an in-menu slot picker. The approved flow is click a physical empty world placement slot, then choose compatible equipment. A visible HUD equipment button can remain an existing instruction/affordance for that flow, but it must not silently choose a slot or bypass confirmation. Report the precise binding used.

## 5. Edit Menu and recipe detail — image(9).png

### 5.1 Panel silhouette and proportions

The menu board begins near x=365, y=115 and ends near x=1240, y=820: about 875 × 705 visible pixels. This is intentionally narrower than the equipment/ingredient shop board. Use `others/board-backdrop-popup-menu.png`, which has a 160:128 canvas proportion, and the large `font board/edit-menu-board.png` title overlapping the upper edge near x=390, y=95.

The right-hand recipe board starts near x=1260, y=125 in the screenshot and extends beyond the right frame. Its title is `font board/resep-board.png`. The screenshot shows a small visual gap, but the earlier explicit request said the new ingredient panel should touch the menu panel with no space. Implement adjacent panels with a shared abutting edge and keep the whole detail area inside the actual viewport. Do not intentionally reproduce the cropped content on the right. Balance the combined panel group within the world area rather than centering the menu alone and letting the detail overflow.

### 5.2 Recipe rows and selection

The reference uses two brown horizontal recipe cards, around x=520–1110 and y=200–320 / 340–465. Each has a separate checkbox to its left around x=450, a dish icon near x=555, and a bold primary name/price line near x=640. Build the card from `buttons/container-item-small.png`; use the matching small disabled asset only if the game genuinely has a disabled recipe state. Keep the checkbox column fixed-width so a long dish name cannot shift it.

One row is checked and another unchecked. Use `checkbox-checked.png` / `checkbox-uncheck.png`; remove textual `[aktif]` or `Aktif` indicators because the explicit request replaces them with a checkmark. The mockup's repeated `Nasi Telur` and `Aktif` text are examples, not two independent recipe definitions. Build rows from real unlocked recipe IDs and existing daily-menu state. Preserve recipe icon identity and existing recipe validation.

The approved text form is `Nasi Telur: Rp 20k` using the actual price and central formatter. Do not copy parentheses, periods, or the em dash from examples. Keep the dish name and price as one line when space permits; wrap only as a deliberate fallback, not by compressing the icon. Raster title/button labels remain images; row names/prices remain dynamic text.

Selection and preview are different existing concepts. Preserve current checkbox toggling and recipe-preview callbacks; clicking a card to inspect ingredients must not accidentally toggle it twice through the checkbox and parent. Keep a visible selected/preview focus state that is distinct from an active-menu checkmark. Do not save pending changes until Simpan. Batal discards pending edits, restores the committed daily menu, and closes the panel.

### 5.3 Right recipe panel content

The target's recipe panel displays a dish name and a prose description. Earlier explicit instructions instead require a top-to-bottom ingredient list. Use the supplied Resep heading and board style with the earlier requested content: dish name, then one ingredient per line, e.g. `Beras`, `Telur`, `Sayur (potong)` according to real recipe/preparation data. Treat ordinary cooking as the default and omit repetitive `(masak)` labels. Only label preparations that differ, and do not assume raw versus cooked requirements from a dish icon.

Do not add the mockup's prose paragraph as an extra block. Keep the dish title visually stronger than ingredient lines. Long ingredient names wrap within the detail board with enough vertical space or a small independent scroll area. A blank selection should show a quiet empty detail state, not an invented recipe. Updating preview must not mutate stock or the selected daily menu.

A separate right panel can reuse the general popup board for its wood treatment; no dedicated recipe-background image is supplied. Its title should overlap its own top border and remain above the list clipping region. Consider whether full general-board seams look too large at the detail width before choosing a crop/stretch; document any fallback.

### 5.4 Footer

Place Batal then Simpan at the bottom right of the menu board, as in the target: approximately x=790–990 and 1005–1205, y=715–790. Use the long brown button surface and `font button/batal.png` / `simpan.png`. Scale lettering by its own aspect, including Simpan's taller shadow extent. Keep a stable footer outside the recipe-list ScrollContainer. Large lists scroll above it without concealing the bottom row or footer labels. Existing selection validation remains authoritative; a rejected save retains pending edits and presents compact relevant feedback.

## 6. Belanja Peralatan — image(10).png

### 6.1 Board and header

The wide general board occupies about x=405–1490, y=103–820, roughly 1085 × 717 visible pixels. Use `others/board-backdrop-popup-general.png`. The large `font board/belanja-peralatan-board.png` overlaps the upper left around x=430, y=90. Keep it outside the scrolling card list.

An electricity badge overlaps the upper right around x=1080–1455, y=90–155. It uses `others/panel-electric.png` with `icons/electric.png` on the left and a dynamic daily figure to its right. Preserve the earlier rule against duplicate cash in this shop. The target's `2000/hari` is a placeholder. If displaying this badge, identify it as the current total daily electricity cost from the authoritative economy view; use the compact money formatter (`Rp 2k/hari`). Individual utility power charges remain in that item's short description only when nonzero. Do not silently display the selected item's power as the run total.

### 6.2 Equipment cards

The two example cards span approximately x=460–1420 with visible heights near 125 at y=210–335 and y=350–475. Use `buttons/container-item.png` for normal and `buttons/container-item-disabled.png` for unavailable items. The first is gray and says `tidak cukup`; the second is brown with a `+` at the far right. Both show the same example Kompor sprite and copy; real rows must list actual distinct compatible utilities rather than clone the example.

Each row has three fixed regions: left icon; flexible two-line text block; right action/status. Keep utility art centered in an approximately square area, with the existing tileset-derived utility sprite or approved utility icon. The new ZIP contains no Kompor, refrigerator, or rice-cooker sprite, so retain the existing utility sprite resolver. Do not mistake `icons/electric.png` for a utility thumbnail. Keep native sprite proportions and an appropriate nearest-filtered scale; table-plus-chairs previews should not clip a chair because the container assumed a single 32 × 32 tile.

Line 1 is **bold name and price on one line**, for example **Kompor: Rp 60k**. Line 2 is normal-weight description beneath, for example `Untuk memasak secara paralel`. The bold-versus-normal distinction was explicitly requested after the original notes. A pixel font with no bold weight can use a legitimate bold face or restrained text emphasis if available; do not claim a bold font asset exists. Keep both labels aligned to the same left baseline.

Remove category suffixes, `Manfaat:`, `Beban (Complexity Debt)`, permanent-slot explanations, and compatibility-error paragraphs. The world slot is fixed before opening the menu. Filter to compatible equipment and make the placement destination an internal binding, not another selection widget. Power costs greater than zero belong compactly in line 2, e.g. `Buat nyimpen bahan sampai beberapa hari (listrik: Rp 4k/hari)`. Zero electricity adds no extra phrase.

For unaffordable equipment, show the supplied gray surface and disable the purchase/selection action as appropriate to the current flow. A compact `tidak cukup` at the right reproduces the target. Derive affordability from current cash and price, not from the mockup where 100000 cash and 60000 cost nevertheless coexist with that status. Re-evaluate on state updates and again in the authoritative purchase request.

### 6.3 Selection, confirmation, and footer

The target has `+` inside an available row and only Batal in the footer. Earlier approved flow requires equipment confirmation and a footer `Harga:` replacing the old `utility -> slot` sentence. Therefore treat `+` as choosing that utility; preserve the existing purchase/confirmation path before charging or placing it. A compact confirmation may reuse the shared board/button art. Do not make `+` an immediate money transaction solely from this screenshot.

Keep `Harga: Rp …` for the current choice if the existing selection flow uses it, and retain a clear Beli/confirm action using `font button/beli.png`; this is a deliberate content adaptation to the earlier explicit flow. Batal remains bottom right or beside Beli, styled with its provided raster label. If the developer instead uses `+` to open an existing explicit confirmation directly, no redundant separate Beli button is required before that confirmation; report the binding. In either route, one confirmed purchase charges exactly once and uses the clicked physical slot.

The screenshot's Batal sits approximately x=1265–1460, y=707–785. Keep the final footer inside the board and outside scrolling, making room for any retained Harga/Beli controls. When nothing can be bought at the clicked location, use a concise valid empty state; do not restore the incompatible-slot catalog and explanatory wall of text.

## 7. Belanja Bahan — image(20261119-152343).png

### 7.1 Board, stock strip, and information density

Use the same wide general board and world dimmer as the equipment shop, with `font board/belanja-bahan-board.png` overlapping its top-left edge. The reference places a `Total Kapasitas 4/15` line below the heading, then compact stock pills around x=440/y=226 showing Beras (3/5) and Tempe (1/5). The earlier explicit request removes total capacity, so omit that line and use the recovered space for the actual slot summary.

Represent each physical storage slot as a distinct compact pill using the shared panel treatment (e.g. `others/panel-coin.png` with adapted width) plus the appropriate ingredient icon and quantity/capacity. Do not display `S1`, `S2`, or another redundant slot-name prefix. Keep independent same-ingredient slots separate because they are real slots, not one total per ingredient. Use a quiet empty-slot presentation for actual empty slots. The mockup's two filled pills do not remove the third slot from a three-slot box. Fridge slots use their actual capacity, not a copied `/5`.

Do not repeat the player's cash, list a redundant stock total on each item row, show `Tiba langsung` in Planning, or show `Kiriman tertunda: tidak ada`. Show delayed delivery information only when there is a real pending shipment and keep its destination/state consistent with the existing storage controller. Display the selected physical container's stock, not global combined stock. Opening this shop still requires clicking the container and typing `beli`; ordinary storage selection must not immediately open it.

### 7.2 Rows and quantity controls

The reference shows three large brown cards near x=460–1420 at y≈320–445, 450–575, and 578–702. Each uses the long `container-item.png` surface. The ingredient icon is on the left around x=495; the single name/price line begins near x=590. Minus, quantity, and plus form fixed columns around x=1225, 1305, and 1390. Keep quantities centered even when the number has more than one digit. The two repeated Beras rows are examples; populate actual purchasable ingredient IDs once each according to current catalog ordering.

Use existing raw ingredient sprites for purchases, with aspect-preserving nearest scaling. The ZIP's `plate-dirty.png` and dish/menu icons are not replacements for ingredient art. The inspected project already contains rice, raw egg, raw chicken, raw cow, raw tempe, and veggies textures. Bind to definitions/resolvers rather than deriving IDs from filenames or Indonesian labels.

The row price is a **unit price**. Keep the approved compact formatter and actual catalog data; the example's Rp20.000 does not change the rice economy. The screenshot contains no per-row subtotal column, and it is unnecessary when the basket total is already visible. Price/name can follow the consistent colon style, e.g. `Beras: Rp 2k`. This colon unification for ingredients is a style recommendation; the explicitly required colon applies to equipment and Edit Menu.

Make minus and plus real buttons with a usable hit region even if their visible marks are small. Use quiet text marks rather than embedding unrelated icon art. At quantity zero, minus does not produce a negative basket. Plus respects the real selected-container capacity/reservations and affordability rules without maintaining a second inventory. Revalidate the whole basket on Beli, including any state changes that happened while the panel was open. Use existing all-or-nothing transaction semantics and preserve pending delivery behavior in Serving.

### 7.3 Footer and dismissal

The reference shows `Total belanja: 0` near x=440/y=770 and a Beli button around x=1265–1460/y=707–785. Use a dynamic `Total belanja: Rp 0k` or the project's agreed zero formatting; all monetary displays need the same centrally defined rule. The compact zero edge case is a technical default to document rather than a license to mix currency formats. The total updates immediately when quantities change, while cash changes only on successful purchase.

Use `buttons/button-long.png` and `font button/beli.png` for checkout. Keep a clear dismissal route even though the reference does not draw Batal. Retaining an existing Batal is a reasonable minimum and uses supplied `batal.png`; Escape also closes the modal according to the existing priority handling. Dismissing an unsubmitted basket should follow the current discard behavior and must not buy or move the player.

The list scrolls independently. Header, stock strip, total, and checkout stay fixed. Test the final catalog row and scrollbar so the last entry is fully reachable; no row should sit beneath the footer or bleed beyond the plank board.

## 8. World status and remaining supplied icons

`others/progress-bar.png` is a **480 × 16 atlas containing ten horizontal 48 × 16 cells**, visibly going from full green on the left through yellow/orange to empty gray on the right. It is not one 480-pixel-long progress bar. Build an AtlasTexture/region for each cell, retaining each cell's transparent padding. A proposed emptying mapping is `index = round((1 - clamp(remaining / duration, 0, 1)) * 9)`; use the actual owner-provided ratio. Never let the selected atlas frame create a new clock. For filling progress, explicitly reverse that mapping. Ten discrete artwork states mean ten visible steps, not a smooth 60 fps fill animation.

The new bar shape also differs from the earlier approved circular countdown rings. Treat it as available art and an optional documented replacement, not proof that every ring must be removed. A safe default is to keep current validated countdown behavior until the coordinator decides which indicators should become bars. The target has a small bar above a queue/customer speech bubble; it does not authorize a new fixed timer HUD or numeric countdown spam.

`icons/waiting.png` is a small clock, `icons/eating.png` is a plate with utensils, and `icons/ojol.png` is a motorbike/driver symbol. They can distinguish existing waiting/eating/online states where the current design has an icon slot. Preserve per-customer/per-driver identity, location, timers, and acceptance state; do not spawn a driver for an unaccepted offer just to display its icon. These state icons are not unique dish sprites.

`others/bubble-speech.png` is a white rounded speech balloon with a lower tail. Use it for an existing in-world speech/interaction bubble when it fits, with dark readable dynamic text. Preserve its border/tail if resizing. Do not add automatic chat dialogue or a new tutorial sequence merely because a bubble asset exists. World-space projected UI follows the existing camera transform and selected-object anchoring.

`icons/plate-dirty.png` directly addresses the prior request: after the customer finishes and leaves, show a plate icon on the dirty table and a hover tooltip exactly `meja kotor`. Replace the persistent `Kotor` text if it remains in the developer's current branch. Display only the dirty marker until cleaned; no customer/order label or food sprite should remain from the previous diner. The tooltip does not create a new command or change the existing cleaning/plate-return logic. This behavior was missing in the last reviewed snapshot, so validate it in-game after integration.

## 9. Integration points in the last reviewed implementation

These names were read from snapshot `6991131`; inspect the developer's current branch before applying. No source files were modified while preparing this report.

| Existing location | Integration responsibility |
| --- | --- |
| `scenes/ui/game_ui.tscn`, `scripts/ui/game_ui.gd` | Existing HUD, menu overlays, focus/modal routing, visual hooks; restyle these without discarding their bindings. |
| `_refresh_hud()` | Cash/day/goal/customer view binding and phase visibility. Keep authoritative run/service values. |
| `_layout_fixture_shop_overlay()` / `_get_viewport_logical_size()` | Current HUD safe width, world dimmer, and shop/menu/pause placement. Extend layout for adjacent recipe detail and decoration spill. |
| `_rebuild_edit_menu_list()`, `_update_recipe_button_visual()`, `_refresh_recipe_detail_panel()` | Card art, checks, preview/selection, ingredient lines. Existing callbacks already distinguish preview and toggling. |
| `_build_ingredient_shop_rows()`, `_refresh_ingredient_shop_view()`, `_refresh_shop_slots()` | Ingredient art/card construction, dynamic basket/total, physical slot summary. |
| `_build_fixture_shop_ui()`, `_create_fixture_shop_icon()`, `_refresh_fixture_shop_view()` | Utility cards/sprites, disabled/selected state, fixed-slot choice and footer. |
| `scripts/world/world_map.gd` or current world presentation owner | Dirty-table icon/hover and existing indicators; inspect current path before editing. |

The inspected UI script is already large and contains story/onboarding additions. Make targeted integrations, retain working controller interfaces, and remove/disable the step sequence only as specified in document 01. Do not replace the file with a mockup-only scene that loses shops, pause, recipe validation, or input routing.

Import art to a clear project directory such as `res://assets/art/ui/` with original subfolders, and put cloud decoration in a sibling directory if useful. These are suggested destinations. Preserve exact case and the supplied `container-item-smal-disabled.png` spelling unless every reference is changed in one deliberate rename. Do not import screenshot reference images as runtime UI textures. Keep target images and this specification as developer reference material instead.

Finish with an in-game visual pass across all five screen categories plus Settings, Pause, and a dirty table. Record exact missing art, substitutions, scale issues, input failures, and test results in `/docs/PROJECT_STATUS.md`, using document 06.
