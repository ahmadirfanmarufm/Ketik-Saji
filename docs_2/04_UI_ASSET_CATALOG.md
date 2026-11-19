# UI asset catalog — every supplied PNG

**FINAL UPDATE:** Read [10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md) first. The thirteen final dish icons, required recipe descriptions, no-selling scope, and exact tutorial text supersede older gaps/content here. The original Grape Soda font is included.

Version 002 · 19 November 2026 (WIB)

All 43 PNGs were opened and inspected. Source image bytes are preserved in this package. Paths below are relative to `provided_assets/ui/` unless marked decoration. Every image contains an alpha channel with transparency. The content bounding box uses Pillow/Godot-style pixel edges `(left, top, right, bottom)` with right and bottom exclusive; it describes nonzero alpha, not an artist-defined content margin. Keep canvas sizes stable when swapping states.

## 1. Per-file dimensions and menu category

| Exact supplied path | Canvas px | Nontransparent bounds | Menu/category |
| --- | --- | --- | --- |
| `buttons/button-long.png` | 80 × 32 | (3, 2, 77, 30) | Shared: main menu, HUD, shop/menu footers |
| `buttons/button.png` | 32 × 32 | (2, 2, 30, 30) | HUD / shared icon actions |
| `buttons/checkbox-checked.png` | 32 × 32 | (2, 0, 31, 30) | Edit Menu |
| `buttons/checkbox-uncheck.png` | 32 × 32 | (2, 2, 30, 30) | Edit Menu |
| `buttons/container-item-disabled.png` | 304 × 48 | (6, 4, 299, 42) | Belanja Peralatan / shared disabled long card |
| `buttons/container-item-smal-disabled.png` | 192 × 48 | (6, 4, 186, 42) | Edit Menu / shared disabled short card |
| `buttons/container-item-small.png` | 192 × 48 | (6, 4, 186, 42) | Edit Menu |
| `buttons/container-item.png` | 304 × 48 | (6, 4, 299, 42) | Belanja Bahan / Belanja Peralatan |
| `buttons/textbox.png` | 160 × 64 | (5, 6, 155, 59) | HUD typing display |
| `font board/belanja-bahan-board.png` | 581 × 87 | (0, 0, 581, 87) | Belanja Bahan |
| `font board/belanja-peralatan-board.png` | 737 × 87 | (0, 0, 737, 87) | Belanja Peralatan |
| `font board/edit-menu-board.png` | 406 × 75 | (0, 0, 406, 75) | Edit Menu |
| `font board/hari-ke.png` | 116 × 25 | (0, 1, 116, 25) | HUD day |
| `font board/ketik.png` | 128 × 43 | (0, 0, 128, 43) | HUD typing |
| `font board/resep-board.png` | 237 × 87 | (0, 0, 237, 87) | Edit Menu recipe detail |
| `font board/target-tamu.png` | 299 × 54 | (0, 0, 299, 54) | HUD customer sign |
| `font button/batal.png` | 171 × 51 | (0, 0, 171, 51) | Edit Menu / shops / shared cancellation |
| `font button/beli-alat.png` | 196 × 40 | (0, 0, 196, 40) | HUD planning action |
| `font button/beli.png` | 116 × 51 | (0, 0, 116, 51) | Ingredient/equipment purchase confirmation |
| `font button/edit-menu.png` | 232 × 44 | (0, 0, 232, 44) | HUD planning action |
| `font button/simpan.png` | 226 × 66 | (0, 0, 226, 66) | Edit Menu commit |
| `font main menu/Keluar.png` | 227 × 59 | (0, 0, 227, 59) | Main menu |
| `font main menu/Play.png` | 171 × 85 | (0, 0, 171, 85) | Main menu |
| `font main menu/pengaturan.png` | 355 × 68 | (0, 0, 355, 68) | Main menu / Settings entry |
| `icons/coins36x36.png` | 32 × 32 | (2, 4, 28, 29) | HUD cash |
| `icons/eating.png` | 48 × 32 | (1, 5, 47, 28) | Customer state |
| `icons/electric.png` | 32 × 32 | (5, 3, 27, 30) | Equipment header / electricity status |
| `icons/menu.png` | 32 × 32 | (3, 3, 31, 30) | HUD icon action |
| `icons/ojol.png` | 48 × 32 | (4, 4, 44, 30) | Online/driver state |
| `icons/plate-dirty.png` | 32 × 32 | (0, 8, 32, 30) | World dirty dining table |
| `icons/quit.png` | 32 × 32 | (2, 1, 30, 31) | Main/HUD/Pause exit affordance |
| `icons/waiting.png` | 32 × 32 | (3, 3, 29, 29) | Customer/driver waiting state |
| `menu-game.png` | 511 × 1080 | (0, 0, 483, 1080) | Persistent left HUD backdrop |
| `others/board-backdrop-popup-general.png` | 192 × 128 | (5, 4, 188, 128) | Both shops / shared popup family |
| `others/board-backdrop-popup-menu.png` | 160 × 128 | (5, 4, 154, 128) | Edit Menu |
| `others/board-target-customer.png` | 160 × 64 | (5, 6, 154, 59) | HUD customer sign |
| `others/bubble-speech.png` | 48 × 32 | (4, 4, 44, 32) | In-world speech / interaction bubble |
| `others/panel-coin.png` | 96 × 32 | (5, 5, 92, 28) | HUD cash / optional stock pill surface |
| `others/panel-electric.png` | 144 × 32 | (5, 5, 139, 28) | Belanja Peralatan header |
| `others/paper-calendar.png` | 96 × 64 | (13, 0, 88, 55) | HUD day |
| `others/progress-bar.png` | 480 × 16 | (4, 2, 476, 14) | World status atlas; use subject to ring/bar decision |
| `decoration: mega mendung 1.png` | 735 × 489 | (20, 12, 708, 476) | Main menu upper-left / optional shared decoration |
| `decoration: mega mendung 2.png` | 736 × 490 | (20, 84, 716, 404) | Main menu lower-right / optional shared decoration |

## 2. Exact usage, layering, and state notes

Static caption PNGs should be TextureRect children of real controls, with mouse filtering ignored. Dynamic content stays text. Proposed final engine paths may differ from the handoff paths; preserve exact casing and change all references deliberately if renaming.

### buttons/button-long.png

Category: Shared: main menu, HUD, shop/menu footers. Brown beveled long button with subtle motif. Use a real Button under the texture; center the separate raster caption. Normal state only; preserve outline and transparent canvas.

Original file: [button-long.png](<provided_assets/ui/buttons/button-long.png>).

### buttons/button.png

Category: HUD / shared icon actions. Square brown beveled icon-button surface. Compose with menu.png or quit.png; the background itself does not define an action.

Original file: [button.png](<provided_assets/ui/buttons/button.png>).

### buttons/checkbox-checked.png

Category: Edit Menu. Checked state; the cream tick extends above the box. Match the unchecked canvas size and leave top clearance; state comes from the pending menu selection.

Original file: [checkbox-checked.png](<provided_assets/ui/buttons/checkbox-checked.png>).

### buttons/checkbox-uncheck.png

Category: Edit Menu. Unchecked state. Use the existing toggle callback and do not display a redundant textual Aktif state.

Original file: [checkbox-uncheck.png](<provided_assets/ui/buttons/checkbox-uncheck.png>).

### buttons/container-item-disabled.png

Category: Belanja Peralatan / shared disabled long card. Gray counterpart of the long item card. Use for genuine disabled/unaffordable state; keep dynamic labels separately legible.

Original file: [container-item-disabled.png](<provided_assets/ui/buttons/container-item-disabled.png>).

### buttons/container-item-smal-disabled.png

Category: Edit Menu / shared disabled short card. Gray short-card counterpart. Exact supplied spelling is smal, with one l. There is no file named container-item-small-disabled.png.

Original file: [container-item-smal-disabled.png](<provided_assets/ui/buttons/container-item-smal-disabled.png>).

### buttons/container-item-small.png

Category: Edit Menu. Short normal recipe card, with a separate checkbox column and a recipe icon/text region.

Original file: [container-item-small.png](<provided_assets/ui/buttons/container-item-small.png>).

### buttons/container-item.png

Category: Belanja Bahan / Belanja Peralatan. Long normal item card. Ingredient rows have icon/name-price/minus/quantity/plus; equipment rows have icon/bold name-price/normal description/action.

Original file: [container-item.png](<provided_assets/ui/buttons/container-item.png>).

### buttons/textbox.png

Category: HUD typing display. Recessed brown text box. Show the existing parser prefix/placeholder here as a read-only projection; do not add a second command-input owner.

Original file: [textbox.png](<provided_assets/ui/buttons/textbox.png>).

### font board/belanja-bahan-board.png

Category: Belanja Bahan. Static raster lettering reading Belanja Bahan. Shop heading overlaps upper-left board edge. This PNG is not a font file.

Original file: [belanja-bahan-board.png](<provided_assets/ui/font board/belanja-bahan-board.png>).

### font board/belanja-peralatan-board.png

Category: Belanja Peralatan. Static raster lettering reading Belanja Peralatan. Large heading; reserve room for electricity pill at right. This PNG is not a font file.

Original file: [belanja-peralatan-board.png](<provided_assets/ui/font board/belanja-peralatan-board.png>).

### font board/edit-menu-board.png

Category: Edit Menu. Static raster lettering reading Edit menu. Menu-board title, visually larger than the HUD button caption. This PNG is not a font file.

Original file: [edit-menu-board.png](<provided_assets/ui/font board/edit-menu-board.png>).

### font board/hari-ke.png

Category: HUD day. Static raster lettering reading Hari ke. Small gray calendar heading; day number remains dynamic. This PNG is not a font file.

Original file: [hari-ke.png](<provided_assets/ui/font board/hari-ke.png>).

### font board/ketik.png

Category: HUD typing. Static raster lettering reading Ketik:. White heading above recessed typing field. This PNG is not a font file.

Original file: [ketik.png](<provided_assets/ui/font board/ketik.png>).

### font board/resep-board.png

Category: Edit Menu recipe detail. Static raster lettering reading Resep. Separate detail-board title overlapping its upper edge. This PNG is not a font file.

Original file: [resep-board.png](<provided_assets/ui/font board/resep-board.png>).

### font board/target-tamu.png

Category: HUD customer sign. Static raster lettering reading Target tamu:. Red-edged white heading; target sign counts remain dynamic. This PNG is not a font file.

Original file: [target-tamu.png](<provided_assets/ui/font board/target-tamu.png>).

### font button/batal.png

Category: Edit Menu / shops / shared cancellation. Static raster lettering reading Batal. Fits a long button; cancellation must preserve existing discard/close semantics. This PNG is not a font file.

Original file: [batal.png](<provided_assets/ui/font button/batal.png>).

### font button/beli-alat.png

Category: HUD planning action. Static raster lettering reading Beli alat. HUD button caption; does not authorize changing the fixed-world-slot purchase flow. This PNG is not a font file.

Original file: [beli-alat.png](<provided_assets/ui/font button/beli-alat.png>).

### font button/beli.png

Category: Ingredient/equipment purchase confirmation. Static raster lettering reading Beli. Final purchase control where the existing flow uses it. This PNG is not a font file.

Original file: [beli.png](<provided_assets/ui/font button/beli.png>).

### font button/edit-menu.png

Category: HUD planning action. Static raster lettering reading Edit menu. Smaller caption for HUD long button; opens existing daily-menu editor. This PNG is not a font file.

Original file: [edit-menu.png](<provided_assets/ui/font button/edit-menu.png>).

### font button/simpan.png

Category: Edit Menu commit. Static raster lettering reading Simpan. Commit caption with tall shadow/letter extent; fit by aspect, not the same fixed height as Batal. This PNG is not a font file.

Original file: [simpan.png](<provided_assets/ui/font button/simpan.png>).

### font main menu/Keluar.png

Category: Main menu. Static raster lettering reading Keluar. Keep capital K in the exact filename. Visible caption on live quit Button. This PNG is not a font file.

Original file: [Keluar.png](<provided_assets/ui/font main menu/Keluar.png>).

### font main menu/Play.png

Category: Main menu. Static raster lettering reading Play. Keep capital P in the exact filename. Visible caption on existing start/resume Button. This PNG is not a font file.

Original file: [Play.png](<provided_assets/ui/font main menu/Play.png>).

### font main menu/pengaturan.png

Category: Main menu / Settings entry. Static raster lettering reading Pengaturan. Wide lettering; fit without clipping or squeezing. Opens existing Settings with BGM volume slider. This PNG is not a font file.

Original file: [pengaturan.png](<provided_assets/ui/font main menu/pengaturan.png>).

### icons/coins36x36.png

Category: HUD cash. Gold coins. Filename is misleading: actual canvas is 32×32. Use measured dimensions and preserve its asymmetric transparent padding.

Original file: [coins36x36.png](<provided_assets/ui/icons/coins36x36.png>).

### icons/eating.png

Category: Customer state. Plate/utensils icon for an existing eating state. It is not a unique menu-dish sprite or a timer.

Original file: [eating.png](<provided_assets/ui/icons/eating.png>).

### icons/electric.png

Category: Equipment header / electricity status. Yellow lightning bolt. Place in electricity pill; not a thumbnail for an appliance.

Original file: [electric.png](<provided_assets/ui/icons/electric.png>).

### icons/menu.png

Category: HUD icon action. Scroll/plate symbol shown in the lower-left HUD button. Exact action is not supplied by the new target; bind an existing approved action and name its hover tooltip.

Original file: [menu.png](<provided_assets/ui/icons/menu.png>).

### icons/ojol.png

Category: Online/driver state. Green motorbike/driver icon. Use only for an existing online state; do not create an unaccepted-order driver from presentation.

Original file: [ojol.png](<provided_assets/ui/icons/ojol.png>).

### icons/plate-dirty.png

Category: World dirty dining table. Dirty-plate marker after diner departure. Tooltip exactly meja kotor on hover; remove permanent Kotor text and stale dish/order art.

Original file: [plate-dirty.png](<provided_assets/ui/icons/plate-dirty.png>).

### icons/quit.png

Category: Main/HUD/Pause exit affordance. Door/arrow icon for an existing exit-related route. Appearance alone does not approve immediate quit from gameplay; preserve Pause/Exit semantics.

Original file: [quit.png](<provided_assets/ui/icons/quit.png>).

### icons/waiting.png

Category: Customer/driver waiting state. Small clock icon for existing waiting-state presentation. Reads existing time/state and does not start a second timer.

Original file: [waiting.png](<provided_assets/ui/icons/waiting.png>).

### menu-game.png

Category: Persistent left HUD backdrop. Tall batik strip with wood edge and integrated upper/lower cloud ornaments. Not the main-menu background. Separate its transparent decorative width from the solid interactive HUD width.

Original file: [menu-game.png](<provided_assets/ui/menu-game.png>).

### others/board-backdrop-popup-general.png

Category: Both shops / shared popup family. Wide three-plank ochre wooden board. Correct base for ingredient/equipment panels; also a possible recipe-detail/Settings/Pause fallback. Reference full-board aspect is close to native.

Original file: [board-backdrop-popup-general.png](<provided_assets/ui/others/board-backdrop-popup-general.png>).

### others/board-backdrop-popup-menu.png

Category: Edit Menu. Narrower board for menu choices. Keep the distinct native aspect rather than stretching the general shop board into the same shape.

Original file: [board-backdrop-popup-menu.png](<provided_assets/ui/others/board-backdrop-popup-menu.png>).

### others/board-target-customer.png

Category: HUD customer sign. Horizontal planked target sign; layer the separate red-edged title and real numeric counts. Do not infer served-count semantics from sample values.

Original file: [board-target-customer.png](<provided_assets/ui/others/board-target-customer.png>).

### others/bubble-speech.png

Category: In-world speech / interaction bubble. White rounded speech bubble with lower tail. Use an existing bubble role; preserve tail/border and dark text. No new dialogue system is requested.

Original file: [bubble-speech.png](<provided_assets/ui/others/bubble-speech.png>).

### others/panel-coin.png

Category: HUD cash / optional stock pill surface. Small gold-brown pill. HUD uses coin icon plus formatted cash. Stock chips can reuse the surface with a quantity and ingredient icon; no cash icon there.

Original file: [panel-coin.png](<provided_assets/ui/others/panel-coin.png>).

### others/panel-electric.png

Category: Belanja Peralatan header. Wider gold-brown pill for lightning icon and current daily electricity amount. Its sample value is not a fixed tariff.

Original file: [panel-electric.png](<provided_assets/ui/others/panel-electric.png>).

### others/paper-calendar.png

Category: HUD day. Cream curled paper. Separate hari-ke.png heading, dynamic current-day digit, and smaller denominator. Canvas padding is asymmetric.

Original file: [paper-calendar.png](<provided_assets/ui/others/paper-calendar.png>).

### others/progress-bar.png

Category: World status atlas; use subject to ring/bar decision. Ten 48×16 horizontal frames: full green to empty gray. Slice x=48*i, y=0, w=48, h=16 for i=0..9. Never display the whole strip or treat each 16px column as a frame.

Original file: [progress-bar.png](<provided_assets/ui/others/progress-bar.png>).

### mega mendung 1.png

Category: Main menu upper-left / optional shared decoration. Large curled brown/cream cloud motif. The target clips it at the upper-left screen edge. It ignores input. Do not duplicate the same ornament already baked into menu-game.png.

Original file: [mega mendung 1.png](<provided_assets/decor/mega mendung 1.png>).

### mega mendung 2.png

Category: Main menu lower-right / optional shared decoration. Flatter brown/cream cloud flourish. Large top/bottom transparent bands matter when anchoring. Match the target silhouette before adding transforms; it ignores input.

Original file: [mega mendung 2.png](<provided_assets/decor/mega mendung 2.png>).

## 3. Coverage and absent resources

| Needed visual role | Supplied coverage / implementation consequence |
| --- | --- |
| Main-menu surfaces, static captions, corner clouds | Supplied. The backdrop photograph and logo are not supplied as standalone files. |
| HUD background/calendar/cash/customer/typing/buttons | Supplied. Numeric/text values and phase behavior still come from the game. |
| Menu/shop boards and normal/disabled rows | Supplied. Use separate content layers and preserve existing transactions. |
| Unique finished dish icons | Absent from these ZIPs. Reuse current recipe/composite resolver pending approved final art. |
| Ingredient and utility thumbnails | Absent from these ZIPs. Existing project ingredient files and tileset utility resolver provide the current sources. |
| Dynamic text font | Resolved in v005: original GrapeSoda.ttf downloaded separately and included under provided_assets/fonts/. The three font-named UI folders still contain raster captions only. |
| Main-menu background and logo | Exact standalone assets absent from these ZIPs. Do not extract baked-in buttons from the target image and call that a final implementation. |
| Settings, Pause, tutorial, confirmation bespoke art | No dedicated layout or captions supplied. Reuse existing screens and shared visual family. A live Settings BGM slider is required. |
| Hover/pressed button art | No distinct variants supplied. A modest tint/focus treatment is a proposed fallback. |
| Smooth progress/ring animation artwork | One ten-state bar atlas is supplied. It does not itself replace earlier circular-ring requirements. |

## 4. Atlas contract

For `others/progress-bar.png`, create ten 48×16 regions at `(0,0)`, `(48,0)`, `(96,0)`, `(144,0)`, `(192,0)`, `(240,0)`, `(288,0)`, `(336,0)`, `(384,0)`, `(432,0)`. The first is visually full and the last empty. Keep each full frame canvas, including transparent gutters. Do not pack or re-export the atlas unless the resource paths/regions are updated together. The countdown owner supplies the normalized ratio; artwork selection must not own elapsed time.

## 5. Cross-menu reuse map

| Screen | Background/surfaces | Static lettering | Icons / other sources |
| --- | --- | --- | --- |
| Main menu | button-long; standalone cloud decorations; missing separate background/logo | Play, pengaturan, Keluar | Existing approved logo/background if the current branch has them. |
| HUD | menu-game; paper-calendar; panel-coin; board-target-customer; textbox; button-long; button | hari-ke; target-tamu; ketik; edit-menu; beli-alat | coins36x36, menu, quit; runtime numeric labels. |
| Edit Menu | board-backdrop-popup-menu; container-item-small; both checkbox states; shared detail board and long buttons | edit-menu-board; resep-board; batal; simpan | Current recipe icon resolver; dynamic ingredient lines. |
| Belanja Peralatan | board-backdrop-popup-general; long normal/disabled cards; panel-electric; long buttons | belanja-peralatan-board; batal; beli where current confirmation uses it | electric; current tileset utility resolver. |
| Belanja Bahan | board-backdrop-popup-general; normal long cards; compact pill treatment; long buttons | belanja-bahan-board; beli; batal if retained | Existing raw ingredient textures; dynamic quantity controls. |
| World/status | bubble-speech; progress-bar atlas where a bar is chosen | No added prose artwork needed | waiting, eating, ojol, plate-dirty. |

Decorations and status icons are categorized by their intended roles; they are not an instruction to force every available file onto a screen. Prefer a clear existing state presentation over redundant icons.

## 6. v005 addition: actual dynamic UI font

The coordinator identifies Grape Soda as the game font. `provided_assets/fonts/GrapeSoda.ttf` is now included unchanged from the creator-linked download: 42,684 bytes, 359 glyphs, one Medium face. This resolves the earlier font-file gap; it does not add another PNG to the 43-image inventory above. Use it for dynamic UI and the new result-screen captions. See [font source reference](provided_assets/fonts/FONT_SOURCE_AND_CREDIT.md). Attribution is already on itch.io according to the coordinator; no in-game attribution is requested.
