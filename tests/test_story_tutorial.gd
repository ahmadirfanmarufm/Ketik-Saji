extends SceneTree
## Headless verification suite for Interactive In-World Guided Tutorial,
## Visual Guidance Overlay, Story Introduction, Daily Narratives (Days 1-7),
## Feature Discovery Tips, Quick Reference, Pause Isolation, Responsive Layout
## Bounds (640x360 & 480x270), and pegawai.png asset inspection.

const REQUIRED_EPILOGUE_MSG: String = (
	"Memiliki lebih banyak belum tentu membuat kita lebih sukses. "
	+ "Mengelola apa yang kita punya dengan bijak jauh lebih penting."
)
const REQUIRED_DAY9_REMINDER: String = (
	"Semakin banyak menu belum tentu semakin banyak keuntungan. "
	+ "Kelola bahan, waktu, dan pelayanan dengan baik."
)

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_scene_boot_opening_story_and_skip()
	await _test_economy_parity_with_and_without_onboarding()
	await _test_cara_main_single_panel_behavior_and_pause()
	await _test_daily_narratives_and_day7_epilogues()
	await _test_responsive_layout_bounds()
	await _test_pegawai_asset_and_runtime_unused()
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _send_key(ui: GameUI, unicode_val: int, keycode_val: int = KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	if keycode_val == KEY_NONE and unicode_val > 0:
		ev.keycode = unicode_val
		ev.physical_keycode = unicode_val
	else:
		ev.keycode = keycode_val
		ev.physical_keycode = keycode_val
	ui.get_viewport().push_input(ev, true)


func _send_left_click(ui: GameUI, canvas_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = canvas_pos
	ev.global_position = canvas_pos
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _advance_sim(game_root: GameRoot, seconds: float, dt: float = 0.25) -> void:
	var remaining := seconds
	while remaining > 0.0001:
		var step := minf(dt, remaining)
		game_root._process(step)
		remaining -= step


func _spawn_direct_game_root(onboarding: bool) -> GameRoot:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await process_frame
	var ui := game_root.get_node("UI") as GameUI
	if onboarding:
		ui.set_onboarding_enabled(true)
	return game_root


func _cleanup_direct_game_root(game_root: GameRoot) -> void:
	if game_root != null and is_instance_valid(game_root):
		game_root.queue_free()
	await process_frame
	await process_frame


func _assert_control_inside_viewport(
	label: String, ctrl: Control, vp_size: Vector2, min_x: float
) -> void:
	var r := ctrl.get_global_rect()
	var valid := (
		ctrl.visible
		and r.position.x >= min_x - 1.0
		and r.position.y >= -1.0
		and r.end.x <= vp_size.x + 1.0
		and r.end.y <= vp_size.y + 1.0
		and r.size.x >= 40.0
		and r.size.y >= 16.0
	)
	_check(label, valid)


func _test_scene_boot_opening_story_and_skip() -> void:
	var err := change_scene_to_file("res://scenes/main/game_root.tscn")
	_check("change_scene_to_file loads game_root.tscn cleanly", err == OK)
	await process_frame
	await process_frame
	await process_frame

	var game_root := current_scene as GameRoot
	_check("current_scene is GameRoot on real scene boot", game_root != null)
	if game_root == null:
		return

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController
	_check(
		"real scene boot opens MainMenuOverlay without starting a run or opening story",
		game_root.is_in_main_menu()
		and ui.is_main_menu_open()
		and not run.is_run_started()
		and not ui.is_story_open()
		and not ui.left_hud_region.visible
	)
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	await process_frame

	_check(
		"Play button starts run and auto-enables onboarding",
		run.is_run_started() and ui.is_onboarding_enabled() and not ui.is_main_menu_open()
	)
	_check("opening story auto-opens on Day 1 after Play", ui.is_story_open())
	_check("story modal blocks world/typing input", ui.is_modal_blocking())
	_check("visual guidance stays hidden while opening story is open", not ui.get_tutorial_guidance_view().get("active", false))

	var sv := ui.get_story_state_view()
	_check("opening story title matches Hari 1: Warisan Terakhir", str(sv.get("title", "")) == "Hari 1: Warisan Terakhir")
	_check("opening story has 3 lines", int(sv.get("line_count", 0)) == 3)
	_check("line 1 mentions modal & starter gear", str(sv.get("text", "")).contains("Rp 100k") and str(sv.get("text", "")).contains("Nasi Telor"))

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	_check(
		"typing while story open does not execute kitchen command",
		kitchen.get_executed_command_count() == 0 and kitchen.get_held_item_view().is_empty()
	)
	_check("opening overlay modals rejected while story open", not ui.open_edit_menu())

	_check("advance_story moves to line 2 (Orang Tua)", ui.advance_story())
	var sv2 := ui.get_story_state_view()
	_check("line 2 speaker is Orang Tua", str(sv2.get("speaker", "")) == "Orang Tua")
	_check("line 2 contains exact premise quote", str(sv2.get("text", "")).contains("Tidak harus besar"))

	_check("advance_story moves to line 3 (Kamu)", ui.advance_story())
	var sv3 := ui.get_story_state_view()
	_check("line 3 speaker is Kamu with portrait visible", str(sv3.get("speaker", "")) == "Kamu" and ui.story_portrait_frame.visible)

	_check("advance_story closes final line", ui.advance_story())
	_check("story overlay closed after final line", not ui.is_story_open())
	await process_frame
	_check("single-panel CARA MAIN opens once after closing opening story", ui.is_reference_open() and ui.is_modal_blocking())
	ui.close_reference()
	await process_frame
	_check(
		"closing CARA MAIN starts Bab 1 guided tutorial without modal blocking",
		not ui.is_reference_open()
		and not ui.is_modal_blocking()
		and ui.is_tutorial_active()
		and ui.get_tutorial_chapter() == 1
		and ui.get_tutorial_step_id() == &"ch1_objective"
		and ui.tutorial_banner.visible
	)

	unload_current_scene()
	await process_frame
	await process_frame

	var gr_skip := await _spawn_direct_game_root(true)
	var ui_skip := gr_skip.get_node("UI") as GameUI
	ui_skip.skip_story()
	await process_frame
	_check("skip_story advances to single-panel CARA MAIN on Day 1", not ui_skip.is_story_open() and ui_skip.is_reference_open())
	ui_skip.close_reference()
	await _cleanup_direct_game_root(gr_skip)


func _test_economy_parity_with_and_without_onboarding() -> void:
	var gr_off := await _spawn_direct_game_root(false)
	var gr_on := await _spawn_direct_game_root(true)
	var ui_off := gr_off.get_node("UI") as GameUI
	_check("legacy direct GameRoot keeps onboarding disabled by default", not ui_off.is_onboarding_enabled())

	var rv_off: Dictionary = (gr_off.get_run_controller() as RunController).get_run_view()
	var rv_on: Dictionary = (gr_on.get_run_controller() as RunController).get_run_view()
	_check(
		"Day 1 cash & menus identical with onboarding on/off",
		int(rv_off.get("cash", -1)) == int(rv_on.get("cash", -2))
		and int(rv_on.get("cash", 0)) == 100000
		and rv_off.get("unlocked_recipe_ids", []) == rv_on.get("unlocked_recipe_ids", [])
		and rv_off.get("selected_recipe_ids", []) == rv_on.get("selected_recipe_ids", [])
	)
	await _cleanup_direct_game_root(gr_off)
	await _cleanup_direct_game_root(gr_on)


func _test_cara_main_single_panel_behavior_and_pause() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var cash_before := int(run.get_run_view().get("cash", 0))

	# Pause during StoryDialogueOverlay preserves line_index.
	ui.advance_story()
	var line_idx := int(ui.get_story_state_view().get("line_index", -1))
	game_root.set_paused(true)
	_check("Pause hides story overlay & guidance visually", not ui.story_dialogue_overlay.visible and not ui.get_tutorial_guidance_view().get("active", false))
	game_root.set_paused(false)
	_check("Unpause restores StoryDialogueOverlay at exact line", ui.story_dialogue_overlay.visible and int(ui.get_story_state_view().get("line_index", -1)) == line_idx)

	ui.skip_story()
	await process_frame
	_check(
		"CARA MAIN enables Ulangi Tutorial button and shows expanded 15-section reference guide",
		ui.is_reference_open()
		and ui.reference_restart_button.visible
		and not ui.reference_restart_button.disabled
		and ui.reference_body_richtext != null
		and ui.reference_body_richtext.text.contains("1. TUJUAN PERMAINAN")
		and ui.reference_body_richtext.text.contains("8. MEMASAK DAN MENYIAPKAN BAHAN")
		and ui.reference_body_richtext.text.contains("14. PRINSIP WARUNG: SEDIKIT LEBIH BAIK")
		and ui.reference_body_richtext.text.contains("15. PERGANTIAN HARI DAN TARGET AKHIR")
	)

	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check(
		"open CARA MAIN blocks world clicks and buka without starting service",
		kitchen.get_player_tile() == tile_before
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
		and int(run.get_run_view().get("cash", -1)) == cash_before
	)

	ui.reference_close_button.pressed.emit()
	_check(
		"closing CARA MAIN releases focus and keeps PLANNING phase intact",
		not ui.is_reference_open()
		and not (ui.get_viewport().gui_get_focus_owner() is BaseButton)
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	# MenuStubButton reopens CARA MAIN in PLANNING.
	ui.menu_stub_button.pressed.emit()
	_check("HUD CARA MAIN button opens single-panel CARA MAIN", ui.is_reference_open())
	ui.close_reference()

	# Typing buka starts SERVING immediately after closing CARA MAIN; opening CARA MAIN in SERVING pauses & resumes clock cleanly.
	_type_word(ui, "buka")
	_check("typed buka after CARA MAIN close starts SERVING", game_root.is_serving())
	_advance_sim(game_root, 2.0, 0.5)
	var elapsed_before := game_root.get_service_elapsed()
	_check("open CARA MAIN in SERVING succeeds and pauses service clock", ui.open_reference() and game_root.is_paused())
	_advance_sim(game_root, 3.0, 0.5)
	_check("SERVING elapsed frozen while CARA MAIN open", is_equal_approx(game_root.get_service_elapsed(), elapsed_before))
	ui.close_reference()
	_check("closing CARA MAIN resumes SERVING clock cleanly", not ui.is_reference_open() and not game_root.is_paused())
	_advance_sim(game_root, 1.5, 0.5)
	_check("SERVING clock advances again after CARA MAIN close", is_equal_approx(game_root.get_service_elapsed(), elapsed_before + 1.5))

	await _cleanup_direct_game_root(game_root)


func _test_daily_narratives_and_day7_epilogues() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	ui.skip_story()
	ui.close_reference()

	for d in range(2, 8):
		_check("Day %d intro narrative opens once" % d, ui.open_day_narrative(d))
		var sv := ui.get_story_state_view()
		_check("Day %d narrative title non-empty" % d, not str(sv.get("title", "")).is_empty())
		if d == 3:
			_check("Day 3 narrative mentions skripsi customer joke", str(sv.get("text", "")).contains("lagi bikin skripsi"))
		ui.skip_story()
		_check("Day %d narrative does not repeat once shown" % d, not ui.open_day_narrative(d))

	_check("Day 7 WON epilogue opens", ui.open_day_7_epilogue(SharedTypes.DayOutcome.WON))
	ui.advance_story()
	_check("Day 7 WON epilogue carries exact competition lesson", str(ui.get_story_state_view().get("text", "")).contains(REQUIRED_EPILOGUE_MSG))
	await _cleanup_direct_game_root(game_root)

	var gr_lost := await _spawn_direct_game_root(true)
	var ui_lost := gr_lost.get_node("UI") as GameUI
	ui_lost.skip_story()
	ui_lost.close_reference()
	_check("Day 7 LOST epilogue opens", ui_lost.open_day_7_epilogue(SharedTypes.DayOutcome.LOST))
	ui_lost.advance_story()
	_check("Day 7 LOST epilogue carries exact competition lesson", str(ui_lost.get_story_state_view().get("text", "")).contains(REQUIRED_EPILOGUE_MSG))
	await _cleanup_direct_game_root(gr_lost)


func _test_responsive_layout_bounds() -> void:
	for vp_size in [
		Vector2(640.0, 360.0),
		Vector2(480.0, 270.0),
		Vector2(1280.0, 720.0),
		Vector2(1600.0, 900.0),
	]:
		root.content_scale_size = Vector2i(int(vp_size.x), int(vp_size.y))
		root.size = Vector2i(int(vp_size.x), int(vp_size.y))
		var game_root := await _spawn_direct_game_root(true)
		var ui := game_root.get_node("UI") as GameUI
		var tag := "%dx%d" % [int(vp_size.x), int(vp_size.y)]
		ui._on_viewport_size_changed()
		await process_frame
		var hud_right := ui.left_hud_region.size.x
		var world_rect := Rect2(hud_right, 0.0, vp_size.x - hud_right, vp_size.y)

		ui._layout_onboarding_overlays(vp_size, world_rect)
		await process_frame
		_assert_control_inside_viewport("StoryPopup inside bounds at " + tag, ui.story_popup, vp_size, hud_right)
		var pop_r := ui.story_popup.get_global_rect()
		var title_r := ui.story_title_label.get_global_rect()
		var spk_r := ui.story_speaker_label.get_global_rect()
		var body_r := ui.story_body_label.get_global_rect()
		var skip_r := ui.story_skip_button.get_global_rect()
		var cont_r := ui.story_continue_button.get_global_rect()
		var sep_top_y := pop_r.position.y + 34.0
		var sep_bot_y := pop_r.end.y - 33.0
		_check(
			"Story hierarchy & separator clearance clean at " + tag,
			title_r.end.y <= sep_top_y
			and spk_r.position.y >= sep_top_y + 4.0
			and body_r.position.y >= spk_r.end.y + 2.0
			and body_r.end.y <= sep_bot_y
			and pop_r.encloses(skip_r)
			and pop_r.encloses(cont_r)
			and skip_r.position.y >= sep_bot_y
			and cont_r.position.y >= sep_bot_y
			and ui.story_body_label.get_theme_font_size("font_size") >= 13
		)

		ui.skip_story()
		ui.open_reference()
		ui._layout_onboarding_overlays(vp_size, world_rect)
		await process_frame
		await process_frame
		_assert_control_inside_viewport("CARA MAIN ReferencePopup inside bounds at " + tag, ui.reference_popup, vp_size, hud_right)
		var ref_pop_r := ui.reference_popup.get_global_rect()
		var ref_title_r := (ui.reference_popup.get_node("RefColumn/RefTitleLabel") as Control).get_global_rect()
		var ref_scroll := ui.reference_popup.get_node("RefColumn/RefScroll") as ScrollContainer
		var ref_scroll_r := ref_scroll.get_global_rect()
		var ref_close_r := ui.reference_close_button.get_global_rect()
		var sec_children := ui.reference_sections_box.get_children()
		var sep_clean := sec_children.size() == 31
		for s_i in range(sec_children.size()):
			if sec_children[s_i] is MarginContainer:
				var s_r := (sec_children[s_i] as Control).get_global_rect()
				var p_r := (sec_children[s_i - 1] as Control).get_global_rect()
				var n_r := (sec_children[s_i + 1] as Control).get_global_rect()
				if p_r.end.y > s_r.position.y + 0.5 or s_r.end.y > n_r.position.y + 0.5:
					sep_clean = false
		_check(
			"CARA MAIN sections & separators never collide at " + tag,
			sep_clean
			and ref_title_r.end.y <= ref_pop_r.position.y + 34.0
			and ref_scroll_r.position.y >= ref_pop_r.position.y + 36.0
			and ref_scroll_r.end.y <= ref_pop_r.end.y - 33.0
			and ref_pop_r.encloses(ref_close_r)
		)
		ui.close_reference()
		await _cleanup_direct_game_root(game_root)

	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)


func _test_pegawai_asset_and_runtime_unused() -> void:
	var tex := load("res://assets/art/characters/pegawai.png") as Texture2D
	_check("pegawai.png loads as Texture2D", tex != null)
	if tex != null:
		var img := tex.get_image()
		_check("pegawai.png dimensions are 14x31", img.get_size() == Vector2i(14, 31))
		_check("pegawai.png format is RGBA8", img.get_format() == Image.FORMAT_RGBA8)
		var partial_alpha := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var a := img.get_pixel(x, y).a
				if a > 0.01 and a < 0.99:
					partial_alpha += 1
		_check("pegawai.png has 0 partial alpha pixels", partial_alpha == 0)

	var game_root := await _spawn_direct_game_root(false)
	var world := game_root.get_node("World") as WorldMap
	var employee_runtime_nodes := world.find_children("*Pegawai*", "", true, false)
	_check("pegawai.png has no spawned employee runtime NPC node", employee_runtime_nodes.is_empty())
	await _cleanup_direct_game_root(game_root)
