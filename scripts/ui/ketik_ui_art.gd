class_name KetikUiArt
extends RefCounted
## Central UI art, font, and StyleBoxTexture helper for Ketik Saji.
## Keeps texture paths, margins, and palette colors consistent without holding runtime state.

const FONT_GRAPE_SODA_PATH: String = "res://assets/fonts/GrapeSoda.ttf"
const BG_MAIN_MENU_PATH: String = "res://assets/bg/main-menu-bg alt (pixelated).jpg.jpeg"
const LOGO_MAIN_MENU_PATH: String = "res://assets/logo/logo ketik-saji pixelated shadow.png"
const DECOR_CLOUD_1_PATH: String = "res://assets/art/decor/mega mendung 1.png"
const DECOR_CLOUD_2_PATH: String = "res://assets/art/decor/mega mendung 2.png"

const UI_HUD_STRIP_PATH: String = "res://assets/art/ui/menu-game.png"
const UI_BUTTON_LONG_PATH: String = "res://assets/art/ui/buttons/button-long.png"
const UI_BUTTON_SQ_PATH: String = "res://assets/art/ui/buttons/button.png"
const UI_CHECKBOX_ON_PATH: String = "res://assets/art/ui/buttons/checkbox-checked.png"
const UI_CHECKBOX_OFF_PATH: String = "res://assets/art/ui/buttons/checkbox-uncheck.png"
const UI_CARD_LONG_PATH: String = "res://assets/art/ui/buttons/container-item.png"
const UI_CARD_LONG_DIS_PATH: String = "res://assets/art/ui/buttons/container-item-disabled.png"
const UI_CARD_SMALL_PATH: String = "res://assets/art/ui/buttons/container-item-small.png"
const UI_CARD_SMALL_DIS_PATH: String = "res://assets/art/ui/buttons/container-item-smal-disabled.png"
const UI_TEXTBOX_PATH: String = "res://assets/art/ui/buttons/textbox.png"

const UI_BOARD_GENERAL_PATH: String = "res://assets/art/ui/others/board-backdrop-popup-general.png"
const UI_BOARD_MENU_PATH: String = "res://assets/art/ui/others/board-backdrop-popup-menu.png"
const UI_BOARD_CUSTOMER_PATH: String = "res://assets/art/ui/others/board-target-customer.png"
const UI_PANEL_COIN_PATH: String = "res://assets/art/ui/others/panel-coin.png"
const UI_PANEL_ELECTRIC_PATH: String = "res://assets/art/ui/others/panel-electric.png"
const UI_PAPER_CALENDAR_PATH: String = "res://assets/art/ui/others/paper-calendar.png"
const UI_BUBBLE_SPEECH_PATH: String = "res://assets/art/ui/others/bubble-speech.png"

const ICON_COINS_PATH: String = "res://assets/art/ui/icons/coins36x36.png"
const ICON_ELECTRIC_PATH: String = "res://assets/art/ui/icons/electric.png"
const ICON_MENU_PATH: String = "res://assets/art/ui/icons/menu.png"
const ICON_QUIT_PATH: String = "res://assets/art/ui/icons/quit.png"

const HDR_BELANJA_BAHAN_PATH: String = "res://assets/art/ui/font board/belanja-bahan-board.png"
const HDR_BELANJA_ALAT_PATH: String = "res://assets/art/ui/font board/belanja-peralatan-board.png"
const HDR_EDIT_MENU_PATH: String = "res://assets/art/ui/font board/edit-menu-board.png"
const HDR_RESEP_PATH: String = "res://assets/art/ui/font board/resep-board.png"
const HDR_HARI_KE_PATH: String = "res://assets/art/ui/font board/hari-ke.png"
const HDR_KETIK_PATH: String = "res://assets/art/ui/font board/ketik.png"
const HDR_TARGET_TAMU_PATH: String = "res://assets/art/ui/font board/target-tamu.png"

const CAP_PLAY_PATH: String = "res://assets/art/ui/font main menu/Play.png"
const CAP_SETTINGS_PATH: String = "res://assets/art/ui/font main menu/pengaturan.png"
const CAP_QUIT_PATH: String = "res://assets/art/ui/font main menu/Keluar.png"
const CAP_BATAL_PATH: String = "res://assets/art/ui/font button/batal.png"
const CAP_BELI_PATH: String = "res://assets/art/ui/font button/beli.png"
const CAP_SIMPAN_PATH: String = "res://assets/art/ui/font button/simpan.png"
const CAP_EDIT_MENU_PATH: String = "res://assets/art/ui/font button/edit-menu.png"
const CAP_BELI_ALAT_PATH: String = "res://assets/art/ui/font button/beli-alat.png"

const COLOR_CREAM: Color = Color(0.99, 0.96, 0.86, 1.0)
const COLOR_WOOD_DARK: Color = Color(0.23, 0.11, 0.05, 1.0)
const COLOR_WOOD_MID: Color = Color(0.38, 0.20, 0.09, 1.0)
const COLOR_OUTLINE_BROWN: Color = Color(0.24, 0.11, 0.04, 1.0)
const COLOR_MUTED_LIGHT: Color = Color(0.86, 0.80, 0.70, 1.0)
const COLOR_SUCCESS: Color = Color(0.24, 0.56, 0.22, 1.0)
const COLOR_DANGER: Color = Color(0.72, 0.18, 0.16, 1.0)
const COLOR_WARN_LIGHT: Color = Color(1.0, 0.58, 0.52, 1.0)


static func load_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D


static func load_font(path: String = FONT_GRAPE_SODA_PATH) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path, "Font"):
		return null
	return ResourceLoader.load(path, "Font") as Font


static func build_ui_theme() -> Theme:
	var theme := Theme.new()
	var font := load_font()
	if font != null:
		theme.default_font = font
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", COLOR_CREAM)
	theme.set_color("font_outline_color", "Label", COLOR_OUTLINE_BROWN)
	theme.set_color("font_color", "Button", COLOR_CREAM)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.99, 0.92, 1.0))
	theme.set_color("font_pressed_color", "Button", COLOR_CREAM)
	theme.set_color("font_focus_color", "Button", Color(1.0, 0.98, 0.82, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.72, 0.70, 0.66, 0.9))
	return theme


static func make_tex_box(
	path: String,
	tex_m_l: float,
	tex_m_t: float,
	tex_m_r: float,
	tex_m_b: float,
	pad_h: float = 8.0,
	pad_v: float = 6.0,
	modulate: Color = Color.WHITE,
	reg_rect: Rect2 = Rect2()
) -> StyleBox:
	var tex := load_tex(path)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.42, 0.25, 0.14, 0.96) * modulate
		flat.border_color = Color(0.22, 0.11, 0.05, 1.0)
		flat.set_border_width_all(2)
		flat.set_corner_radius_all(4)
		flat.content_margin_left = pad_h
		flat.content_margin_right = pad_h
		flat.content_margin_top = pad_v
		flat.content_margin_bottom = pad_v
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = tex_m_l
	sb.texture_margin_top = tex_m_t
	sb.texture_margin_right = tex_m_r
	sb.texture_margin_bottom = tex_m_b
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.modulate_color = modulate
	if reg_rect.size != Vector2.ZERO:
		sb.region_rect = reg_rect
	return sb


static func apply_wood_board(
	panel: PanelContainer,
	is_menu_board: bool = false,
	pad_h: float = 12.0,
	pad_v: float = 10.0,
	pad_top: float = -1.0,
	pad_bottom: float = -1.0,
	preserve_planks: bool = false
) -> void:
	if panel == null:
		return
	var path := UI_BOARD_MENU_PATH if is_menu_board else UI_BOARD_GENERAL_PATH
	var reg := Rect2(5, 4, 150, 124) if is_menu_board else Rect2(5, 4, 183, 121)
	var m_t := 36.0 if (preserve_planks and not is_menu_board) else 12.0
	var m_b := 34.0 if (preserve_planks and not is_menu_board) else 12.0
	var sb := make_tex_box(path, 14, m_t, 14, m_b, pad_h, pad_v, Color.WHITE, reg)
	if pad_top >= 0.0:
		sb.content_margin_top = pad_top
	if pad_bottom >= 0.0:
		sb.content_margin_bottom = pad_bottom
	panel.add_theme_stylebox_override("panel", sb)


static func apply_button_skin(
	btn: Button,
	square: bool = false,
	pad_h: float = 8.0,
	pad_v: float = 4.0,
	tint: Color = Color.WHITE
) -> void:
	if btn == null:
		return
	var path := UI_BUTTON_SQ_PATH if square else UI_BUTTON_LONG_PATH
	var reg := Rect2(2, 2, 28, 28) if square else Rect2(3, 2, 74, 28)
	var m := 6.0 if square else 8.0
	btn.add_theme_stylebox_override(
		"normal",
		make_tex_box(path, m, 6, m, 6, pad_h, pad_v, tint, reg)
	)
	btn.add_theme_stylebox_override(
		"hover",
		make_tex_box(
			path,
			m,
			6,
			m,
			6,
			pad_h,
			pad_v,
			tint * Color(1.08, 1.05, 0.96, 1.0),
			reg
		)
	)
	btn.add_theme_stylebox_override(
		"pressed",
		make_tex_box(
			path,
			m,
			6,
			m,
			6,
			pad_h,
			pad_v,
			tint * Color(0.84, 0.78, 0.72, 1.0),
			reg
		)
	)
	btn.add_theme_stylebox_override(
		"focus",
		make_tex_box(
			path,
			m,
			6,
			m,
			6,
			pad_h,
			pad_v,
			tint * Color(1.12, 1.04, 0.78, 1.0),
			reg
		)
	)
	btn.add_theme_stylebox_override(
		"disabled",
		make_tex_box(
			path,
			m,
			6,
			m,
			6,
			pad_h,
			pad_v,
			tint * Color(0.62, 0.62, 0.62, 0.85),
			reg
		)
	)
	btn.add_theme_color_override("font_color", COLOR_CREAM)
	btn.add_theme_color_override("font_outline_color", COLOR_OUTLINE_BROWN)
	btn.add_theme_constant_override("outline_size", 3)


static func apply_card_skin(
	panel: Control,
	small: bool = false,
	disabled: bool = false,
	selected: bool = false,
	pad_h: float = 8.0,
	pad_v: float = 5.0
) -> void:
	if panel == null:
		return
	var path := ""
	var reg := Rect2()
	if small:
		path = UI_CARD_SMALL_DIS_PATH if disabled else UI_CARD_SMALL_PATH
		reg = Rect2(6, 4, 180, 38)
	else:
		path = UI_CARD_LONG_DIS_PATH if disabled else UI_CARD_LONG_PATH
		reg = Rect2(6, 4, 293, 38)
	var tint := Color(1.14, 1.08, 0.86, 1.0) if selected else Color.WHITE
	var sb := make_tex_box(path, 10, 8, 10, 8, pad_h, pad_v, tint, reg)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", sb)
	elif panel is Button:
		var b := panel as Button
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override(
			"hover",
			make_tex_box(path, 10, 8, 10, 8, pad_h, pad_v, Color(1.08, 1.04, 0.92, 1.0), reg)
		)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override(
			"focus",
			make_tex_box(path, 10, 8, 10, 8, pad_h, pad_v, Color(1.15, 1.10, 0.85, 1.0), reg)
		)


static func attach_button_caption(
	btn: Button,
	caption_path: String,
	margin_x: float = 10.0,
	margin_y: float = 4.0,
	hide_text: bool = true
) -> TextureRect:
	if btn == null:
		return null
	var existing := btn.get_node_or_null("ArtCaption") as TextureRect
	var tex := load_tex(caption_path)
	if tex == null:
		if existing != null:
			existing.visible = false
		return null
	if existing == null:
		existing = TextureRect.new()
		existing.name = "ArtCaption"
		existing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		existing.offset_left = margin_x
		existing.offset_top = margin_y
		existing.offset_right = -margin_x
		existing.offset_bottom = -margin_y
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		existing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(existing)
	existing.texture = tex
	existing.visible = true
	if hide_text:
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))
		btn.add_theme_constant_override("outline_size", 0)
	return existing


static func style_heading_label(lbl: Label, size_px: int = 16, col: Color = COLOR_CREAM) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE_BROWN)
	lbl.add_theme_constant_override("outline_size", 4)


static func style_wood_body_label(lbl: Label, size_px: int = 12, col: Color = COLOR_WOOD_DARK) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 0)


static func apply_slider_skin(slider: HSlider) -> void:
	if slider == null:
		return
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.28, 0.14, 0.06, 1.0)
	rail.border_color = Color(0.16, 0.07, 0.03, 1.0)
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(3)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.84, 0.56, 0.18, 1.0)
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


static func apply_option_button_skin(opt: OptionButton, pad_h: float = 8.0, pad_v: float = 3.0) -> void:
	if opt == null:
		return
	apply_button_skin(opt, false, pad_h, pad_v)
	var popup := opt.get_popup()
	if popup != null:
		var bg := StyleBoxFlat.new()
		bg.bg_color = COLOR_WOOD_MID
		bg.border_color = COLOR_WOOD_DARK
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(3)
		bg.content_margin_left = 6.0
		bg.content_margin_right = 6.0
		bg.content_margin_top = 4.0
		bg.content_margin_bottom = 4.0
		popup.add_theme_stylebox_override("panel", bg)
		popup.add_theme_color_override("font_color", COLOR_CREAM)
		popup.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.65, 1.0))
		popup.add_theme_font_size_override("font_size", 11)
