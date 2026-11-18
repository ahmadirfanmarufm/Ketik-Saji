extends SceneTree
## Headless tests for GameUI Foundation and Milestone 1 Input & Interaction:
## UI scene hierarchy, GameRoot auto-binding, signal deduplication, Candidate B
## viewport layout (LeftHUDRegion 112x360 + World at (144, 36)), phase/HUD
## synchronization, world click routing with HUD/result blocking and pass-through
## dialogue, keyboard forwarding with focus/echo/Escape handling, and dialogue
## clamping within world_visible_rect.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_ui_structure_and_wiring()
	await _test_phase_and_hud_transitions()
	await _test_mouse_input_and_world_offset()
	await _test_keyboard_input_and_focus_blocking()
	await _test_dialogue_display_and_clamping()
	await _test_m1_kitchen_gameplay_and_visuals()
	await _test_m1_edge_cases_and_readonly()
	await _test_worktable_hitboxes_player_movement_and_results_layout()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _send_left_click(ui: GameUI, pos: Vector2) -> void:
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = pos
	press_ev.global_position = pos
	if ui.is_inside_tree() and ui.get_viewport() != null:
		var vp := ui.get_viewport()
		vp.push_input(press_ev, true)
		var release_ev := InputEventMouseButton.new()
		release_ev.button_index = MOUSE_BUTTON_LEFT
		release_ev.pressed = false
		release_ev.position = pos
		release_ev.global_position = pos
		vp.push_input(release_ev, true)
	else:
		ui._unhandled_input(press_ev)


func _send_key(
	ui: GameUI,
	unicode_val: int,
	keycode_val: int = KEY_NONE,
	is_echo: bool = false
) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = is_echo
	ev.unicode = unicode_val
	ev.keycode = keycode_val as Key
	ui._unhandled_key_input(ev)


func _test_ui_structure_and_wiring() -> void:
	var ui_packed := load("res://scenes/ui/game_ui.tscn") as PackedScene
	_check("load game_ui.tscn", ui_packed != null)

	var root_packed := load("res://scenes/main/game_root.tscn") as PackedScene
	_check("load game_root.tscn", root_packed != null)
	if root_packed == null:
		return

	var game_root := root_packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var world := game_root.get_node_or_null("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node_or_null("UI") as GameUI

	_check("GameRoot discovers and binds UI", ui != null and world != null)
	if ui == null or world == null or kitchen == null or service == null or run == null:
		game_root.free()
		return

	_check("Candidate B World position is (144, 36)", world.position == Vector2(144, 36))
	_check(
		"LeftHUDRegion rect is (0, 0, 112, 360)",
		ui.left_hud_region.get_rect() == Rect2(0, 0, 112, 360)
		and ui.ui_safe_rect == Rect2(0, 0, 112, 360)
		and ui.world_visible_rect == Rect2(112, 0, 528, 360)
	)
	_check(
		"UIRoot and InteractionDialogue use MOUSE_FILTER_IGNORE",
		ui.ui_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ui.interaction_dialogue.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)
	_check(
		"LeftHUDRegion and DayResultSidePanel use MOUSE_FILTER_STOP",
		ui.left_hud_region.mouse_filter == Control.MOUSE_FILTER_STOP
		and ui.day_result_side_panel.mouse_filter == Control.MOUSE_FILTER_STOP
	)
	_check(
		"Planning, Continue, and ExtraMode buttons support keyboard focus (FOCUS_ALL)",
		ui.get("start_service_button") == null
		and ui.edit_menu_button.focus_mode == Control.FOCUS_ALL
		and ui.menu_stub_button.focus_mode == Control.FOCUS_ALL
		and ui.exit_stub_button.focus_mode == Control.FOCUS_ALL
		and ui.continue_button.focus_mode == Control.FOCUS_ALL
		and ui.extra_mode_button.focus_mode == Control.FOCUS_ALL
	)

	# Re-binding context multiple times must not duplicate signal connections.
	ui.bind_context(game_root, world, kitchen, service, run)
	ui.bind_context(game_root, world, kitchen, service, run)
	var phase_conns := game_root.get_signal_connection_list(&"phase_changed")
	var ui_phase_conn_count := 0
	for conn: Dictionary in phase_conns:
		var callable_val: Callable = conn.get("callable", Callable())
		if callable_val.get_object() == ui:
			ui_phase_conn_count += 1
	_check("GameRoot phase_changed connected to UI exactly once", ui_phase_conn_count == 1)

	# Initial HUD state in PLANNING Day 1:
	_check("initial DayLabel is Hari 1/7", ui.day_label.text == "Hari 1/7")
	_check(
		"initial PhaseLabel is persiapan sebelum buka",
		ui.phase_label.text == "persiapan sebelum buka"
	)
	_check("initial CashLabel is Kas: Rp100000", ui.cash_label.text == "Kas: Rp100000")
	_check(
		"initial GoalLabel shows Target Hari 7 percentage",
		ui.goal_label.text == "Target Hari 7: 14%"
	)
	_check(
		"initial GoalProgressBar ratio is 100000 / 700000",
		is_equal_approx(ui.goal_progress_bar.value, 100000.0 / 700000.0)
	)
	_check(
		"initial PlanningBox visible with forecast, Edit Menu, buka hint, and stub buttons",
		ui.planning_box.visible
		and ui.forecast_quota_label.text == "Target Tamu: 4"
		and ui.edit_menu_button.visible
		and ui.start_hint_label.text == "Ketik: buka"
		and ui.menu_stub_button.visible
		and ui.exit_stub_button.visible
	)
	_check("initial ServiceBox hidden", not ui.service_box.visible)
	_check("initial DayResultSidePanel hidden", not ui.day_result_side_panel.visible)
	_check("initial InteractionDialogue hidden", not ui.interaction_dialogue.visible)

	game_root.free()
	await process_frame


func _test_phase_and_hud_transitions() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Focused Planning BaseButton blocks gameplay typing; releasing focus allows typed `buka`:
	ui.edit_menu_button.grab_focus()
	_check(
		"EditMenuButton grabs keyboard focus in PLANNING and blocks typing while focused",
		ui.edit_menu_button.has_focus() and not ui.edit_menu_button.disabled
	)
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_check("focused BaseButton blocks buka prefix in PLANNING", kitchen.get_command_prefix() == "")
	ui.edit_menu_button.release_focus()
	_type_word(ui, "buka")
	_check(
		"Typed buka enters SERVING and updates HUD without Enter key",
		game_root.is_serving()
		and not ui.edit_menu_button.has_focus()
		and ui.edit_menu_button.disabled
		and not ui.planning_box.visible
		and ui.service_box.visible
		and not ui.day_result_side_panel.visible
		and ui.phase_label.text == "Layanan"
		and ui.unspawned_quota_label.text == "Antrean Datang: 3"
	)

	game_root._process(3.5)
	ui._process(3.5)
	_check(
		"ServiceElapsedLabel reflects monotonic clock",
		ui.service_elapsed_label.text == "Waktu: 3.5 dtk"
	)

	# Observe real GameRoot CLOSING transition during request_close_if_drained():
	var closing_state := {
		"observed": false,
		"game_root_phase_is_closing": false,
		"phase_text": "",
		"planning_visible": true,
		"results_visible": true,
		"service_visible": false,
		"dialogue_visible": true,
	}
	var closing_probe := func(phase: int, _day_idx: int) -> void:
		if phase == SharedTypes.Phase.CLOSING:
			closing_state["observed"] = true
			closing_state["game_root_phase_is_closing"] = (
				game_root.get_phase() == SharedTypes.Phase.CLOSING
			)
			closing_state["phase_text"] = ui.phase_label.text
			closing_state["planning_visible"] = ui.planning_box.visible
			closing_state["results_visible"] = ui.day_result_side_panel.visible
			closing_state["service_visible"] = ui.service_box.visible
			closing_state["dialogue_visible"] = ui.interaction_dialogue.visible
	game_root.phase_changed.connect(closing_probe)

	# Drain Day 1 through real CLOSING -> RESULTS lifecycle and verify both CLOSING and RESULTS.
	_force_empty_service(service)
	game_root.request_close_if_drained()
	game_root.phase_changed.disconnect(closing_probe)

	_check(
		"real CLOSING transition hides PlanningBox/DayResultSidePanel and shows ServiceBox",
		bool(closing_state["observed"])
		and bool(closing_state["game_root_phase_is_closing"])
		and String(closing_state["phase_text"]) == "Penutupan"
		and not bool(closing_state["planning_visible"])
		and not bool(closing_state["results_visible"])
		and bool(closing_state["service_visible"])
		and not bool(closing_state["dialogue_visible"])
	)
	_check(
		"RESULTS shows DayResultSidePanel with ContinueButton only",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and ui.day_result_side_panel.visible
		and ui.continue_button.visible
		and not ui.continue_button.disabled
		and not ui.extra_mode_button.visible
		and ui.result_title_label.text == "Hasil Hari 1"
		and ui.settlement_summary_label.text.contains("Kas Akhir: Rp98000")
	)
	ui.continue_button.grab_focus()
	_check("ContinueButton grabs keyboard focus in RESULTS", ui.continue_button.has_focus())

	ui.continue_button.pressed.emit()
	_check(
		"ContinueButton advances to Day 2 PLANNING and hides results panel",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 2
		and ui.day_label.text == "Hari 2/7"
		and ui.planning_box.visible
		and not ui.day_result_side_panel.visible
	)

	# Advance Days 2-6 to Day 7, win Day 7, and verify FINISHED + ExtraModeButton.
	for _day in range(2, 7):
		_type_word(ui, "buka")
		_force_empty_service(service)
		game_root.request_close_if_drained()
		ui.continue_button.pressed.emit()

	_check("reached Day 7 PLANNING via Continue/buka", game_root.get_day_index() == 7)
	_type_word(ui, "buka")
	for i in range(35):
		run.credit_order_once(
			StringName("ord_ui_d7_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	_force_empty_service(service)
	game_root.request_close_if_drained()

	_check(
		"Day 7 WON shows Berhasil! and ExtraModeButton",
		game_root.get_phase() == SharedTypes.Phase.FINISHED
		and ui.day_result_side_panel.visible
		and ui.result_title_label.text.contains("Berhasil!")
		and not ui.continue_button.visible
		and ui.extra_mode_button.visible
	)

	ui.extra_mode_button.pressed.emit()
	_check(
		"ExtraModeButton transitions to Day 8 PLANNING",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 8
		and ui.day_label.text == "Hari 8"
		and not ui.day_result_side_panel.visible
	)

	game_root.free()
	await process_frame


func _test_mouse_input_and_world_offset() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI

	# 1. Click inside LeftHUDRegion (50, 180) does not reach KitchenController.
	_send_left_click(ui, Vector2(50, 180))
	_check(
		"HUD click at (50, 180) blocked from World",
		kitchen.get_player_tile() == Vector2i(6, 4)
		and kitchen.get_selected_target_id() == &""
	)

	# 2. Floor click at cell (5, 4) -> local (176, 144) + offset (144, 36) = canvas (320, 180).
	_send_left_click(ui, Vector2(320, 180))
	_check(
		"floor click at canvas (320, 180) moves player to cell (5, 4)",
		kitchen.get_player_tile() == Vector2i(5, 4)
		and kitchen.get_selected_target_id() == &""
	)

	# 3. Fixture click on storage_box at local (80, 16) + offset (144, 36) = canvas (224, 52).
	# From (5, 4), RIGHT (3, 0) and DOWN (2, 1) tie at distance 6 -> RIGHT (3, 0) wins.
	_send_left_click(ui, Vector2(224, 52))
	_check(
		"click storage_box at (224, 52) selects storage_box and moves to (3, 0)",
		kitchen.get_selected_target_id() == &"storage_box"
		and kitchen.get_player_tile() == Vector2i(3, 0)
	)
	ui.shop_cancel_button.pressed.emit()

	# 4. WorkTable split targets:
	# WorkTable is at local (208, 80) -> canvas (352, 116).
	# StagingTarget is at local (201, 80) -> canvas (345, 116).
	# ChoppingTarget is at local (215, 80) -> canvas (359, 116).
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"click StagingTarget at (345, 116) selects work_table_stage (not work_table)",
		kitchen.get_selected_target_id() == &"work_table_stage"
	)
	_send_left_click(ui, Vector2(359, 116))
	_check(
		"click ChoppingTarget at (359, 116) selects work_table_chop (not work_table)",
		kitchen.get_selected_target_id() == &"work_table_chop"
	)

	# 5. InteractionDialogue pass-through via Viewport.push_input():
	# Move to (5, 6) at canvas (320, 244), then click dining_table_01 at (4, 6) -> (288, 244).
	# Player stays at (5, 6), and InteractionDialogue appears above table over cell (4, 5).
	_send_left_click(ui, Vector2(320, 244))
	_send_left_click(ui, Vector2(288, 244))
	_check(
		"click dining_table_01 from (5, 6) selects table and shows dialogue above it",
		kitchen.get_selected_target_id() == &"dining_table_01"
		and kitchen.get_player_tile() == Vector2i(5, 6)
		and ui.interaction_dialogue.visible
	)
	var dlg_rect := ui.interaction_dialogue.get_global_rect()
	var pass_through_pt := dlg_rect.get_center()
	var expected_floor_cell := (game_root.get_node("World") as WorldMap).global_to_cell(
		pass_through_pt
	)
	_check(
		"dialogue pass-through point lies inside InteractionDialogue rect over free floor cell",
		dlg_rect.has_point(pass_through_pt)
		and (game_root.get_node("World") as WorldMap).grid.is_free(expected_floor_cell)
		and expected_floor_cell != kitchen.get_player_tile()
	)
	_send_left_click(ui, pass_through_pt)
	_check(
		"click inside InteractionDialogue passes through Viewport GUI to floor cell",
		kitchen.get_player_tile() == expected_floor_cell
		and kitchen.get_selected_target_id() == &""
	)

	# 6. Clicks outside the World grid (e.g. left margin (120, 100) or bottom-right (600, 340))
	# are safely rejected without moving player.
	_send_left_click(ui, Vector2(120, 100))
	_send_left_click(ui, Vector2(600, 340))
	_check(
		"clicks outside World grid rejected without moving player",
		kitchen.get_player_tile() == expected_floor_cell
	)

	# 7. Result panel blocks world clicks when visible in RESULTS.
	_type_word(ui, "buka")
	_force_empty_service(service)
	game_root.request_close_if_drained()
	_check("DayResultSidePanel visible in RESULTS", ui.day_result_side_panel.visible)
	var tile_before_res_click := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(450, 180))
	_check(
		"click inside DayResultSidePanel blocked from World",
		kitchen.get_player_tile() == tile_before_res_click
	)

	game_root.free()
	await process_frame


func _test_keyboard_input_and_focus_blocking() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var ui := game_root.get_node("UI") as GameUI

	# Select stove in PLANNING: keyboard input must be ignored outside SERVING.
	_send_left_click(ui, Vector2(288, 52))
	_check("stove selected in PLANNING", kitchen.get_selected_target_id() == &"stove")
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_check(
		"keyboard input ignored in PLANNING",
		kitchen.get_command_prefix() == ""
	)

	# Start SERVING and select stove ("goreng").
	game_root.start_service_requested()
	_send_left_click(ui, Vector2(288, 52))
	_check(
		"stove selected in SERVING with allowed command goreng",
		kitchen.get_selected_target_id() == &"stove"
		and kitchen.get_allowed_commands_for_selected_target() == ["goreng"]
		and ui.prefix_prompt_label.text == "Ketik: goreng"
		and not ui.remaining_prompt_label.visible
	)

	# 1. Valid first character is accepted and updates live preview.
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_check(
		"valid first character g accepted with live preview",
		kitchen.get_command_prefix() == "g"
		and ui.prefix_prompt_label.text == "Ketik: [g]"
		and ui.prefix_prompt_label.modulate == GameUI.PREFIX_HIGHLIGHT_COLOR
		and ui.remaining_prompt_label.visible
		and ui.remaining_prompt_label.text == "Ketik berikutnya: oreng"
		and ui.allowed_commands_label.text == "[g]oreng"
	)

	# 2. Valid multi-character prefix ('g', 'o', 'r') is accepted.
	_send_key(ui, "o".unicode_at(0), KEY_O)
	_send_key(ui, "r".unicode_at(0), KEY_R)
	_check(
		"Unicode keys g, o, r accepted in SERVING",
		kitchen.get_command_prefix() == "gor"
		and ui.prefix_prompt_label.text == "Ketik: [gor]"
		and ui.remaining_prompt_label.visible
		and ui.remaining_prompt_label.text == "Ketik berikutnya: eng"
		and ui.allowed_commands_label.text == "[gor]eng"
	)

	# Key echo ('e' with echo=true) must be ignored.
	_send_key(ui, "e".unicode_at(0), KEY_E, true)
	_check("key echo ignored", kitchen.get_command_prefix() == "gor")

	# 4 & 6. Invalid key 'z' while prefix is "gor" shows feedback; Escape clears prefix/feedback.
	_send_key(ui, "z".unicode_at(0), KEY_Z)
	_check(
		"invalid key z with active prefix shows feedback and shake",
		kitchen.get_command_prefix() == "gor"
		and ui.context_message_label.visible
		and ui.context_message_label.text == "Huruf tidak cocok"
		and ui.is_shaking()
	)
	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Escape clears command prefix and clears invalid-key feedback/shake",
		kitchen.get_command_prefix() == ""
		and ui.prefix_prompt_label.text == "Ketik: goreng"
		and not ui.remaining_prompt_label.visible
		and not ui.context_message_label.visible
		and ui.context_message_label.text == ""
		and not ui.is_shaking()
	)

	# Invalid key 'z' when prefix is already empty, followed by Escape, also clears feedback.
	_send_key(ui, "z".unicode_at(0), KEY_Z)
	_check("invalid key z with empty prefix shows feedback", ui.context_message_label.visible)
	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Escape with empty prefix clears stale invalid-key feedback",
		not ui.context_message_label.visible
		and ui.context_message_label.text == ""
		and not ui.is_shaking()
	)

	# Focused LineEdit blocks keyboard input from reaching KitchenController.
	var line_edit := LineEdit.new()
	ui.ui_root.add_child(line_edit)
	line_edit.grab_focus()
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_check(
		"focused LineEdit blocks gameplay keyboard input",
		kitchen.get_command_prefix() == ""
	)
	line_edit.release_focus()
	line_edit.free()

	# Modal blocking flag also blocks keyboard input.
	ui.set_modal_blocking(true)
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_check(
		"active modal blocks gameplay keyboard input",
		kitchen.get_command_prefix() == ""
	)
	ui.set_modal_blocking(false)

	# 3. Completing a valid command ("goreng") executes it exactly once and resets prefix/preview.
	var exec_before := kitchen.get_executed_command_count()
	for ch in ["g", "o", "r", "e", "n", "g"]:
		_send_key(ui, ch.unicode_at(0))
	_check(
		"full word goreng auto-executes exactly once and clears prefix/preview without Enter",
		kitchen.get_command_prefix() == ""
		and kitchen.get_executed_command_count() == exec_before + 1
		and kitchen.get_last_executed_command() == "goreng"
		and ui.prefix_prompt_label.text == "Ketik: goreng"
		and not ui.remaining_prompt_label.visible
	)

	# 5, 7, 8, 9. Select rice_cooker at (480, 52) ("masak, nasi"):
	# Test uppercase input ("M", "A"), live preview ("Ketik: [ma]", "Ketik berikutnya: sak"),
	# Backspace editing, and target-switch prefix reset.
	_send_left_click(ui, Vector2(480, 52))
	_check(
		"rice_cooker selected with masak, nasi and idle instruction",
		kitchen.get_selected_target_id() == &"rice_cooker"
		and ui.allowed_commands_label.text == "masak, nasi"
		and ui.prefix_prompt_label.text == "Ketik perintah"
		and not ui.remaining_prompt_label.visible
	)
	_send_key(ui, "M".unicode_at(0), KEY_M)
	_send_key(ui, 0, KEY_A)
	_check(
		"uppercase and keycode-only input normalized to ma with Ketik berikutnya: sak",
		kitchen.get_command_prefix() == "ma"
		and ui.allowed_commands_label.text == "[ma]sak, nasi"
		and ui.prefix_prompt_label.text == "Ketik: [ma]"
		and ui.remaining_prompt_label.visible
		and ui.remaining_prompt_label.text == "Ketik berikutnya: sak"
	)
	_send_key(ui, 0, KEY_BACKSPACE)
	_check(
		"Backspace removes one character to m with Ketik berikutnya: asak",
		kitchen.get_command_prefix() == "m"
		and ui.prefix_prompt_label.text == "Ketik: [m]"
		and ui.remaining_prompt_label.text == "Ketik berikutnya: asak"
	)

	# 7. Switching targets clears incompatible typing state.
	_send_left_click(ui, Vector2(288, 52))
	_check(
		"switching target from rice_cooker to stove clears active prefix and preview",
		kitchen.get_selected_target_id() == &"stove"
		and kitchen.get_command_prefix() == ""
		and ui.prefix_prompt_label.text == "Ketik: goreng"
		and not ui.remaining_prompt_label.visible
	)

	game_root.free()
	await process_frame


func _test_dialogue_display_and_clamping() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	game_root.start_service_requested()

	# Click top-left station storage_box at (224, 52):
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_check(
		"dialogue shows Kotak Bahan and 6 ingredient commands",
		ui.interaction_dialogue.visible
		and ui.target_title_label.text == "Kotak Bahan"
		and ui.allowed_commands_label.text == "ayam, beras, sapi, sayur, telur, tempe"
		and ui.prefix_prompt_label.text == "Ketik perintah"
		and not ui.remaining_prompt_label.visible
	)

	# 10. Multiple matching command prefixes ("sa" -> sapi / sayur) show all alternatives clearly:
	_send_key(ui, "s".unicode_at(0), KEY_S)
	_send_key(ui, "a".unicode_at(0), KEY_A)
	_check(
		"shared prefix sa shows both sapi and sayur remaining suffixes without guessing",
		ui.allowed_commands_label.text == "ayam, beras, [sa]pi, [sa]yur, telur, tempe"
		and ui.prefix_prompt_label.text == "Ketik: [sa]"
		and ui.remaining_prompt_label.visible
		and ui.remaining_prompt_label.text == "Ketik berikutnya: pi / yur"
	)
	_send_key(ui, "y".unicode_at(0), KEY_Y)
	_check(
		"typing y disambiguates to sayur with Ketik berikutnya: ur",
		ui.allowed_commands_label.text == "ayam, beras, sapi, [say]ur, telur, tempe"
		and ui.prefix_prompt_label.text == "Ketik: [say]"
		and ui.remaining_prompt_label.text == "Ketik berikutnya: ur"
	)
	_send_key(ui, 0, KEY_ESCAPE)

	var box_rect := ui.interaction_dialogue.get_rect()
	_check(
		"dialogue near top-left station clamped inside world_visible_rect and clear of HUD",
		box_rect.position.x >= ui.world_visible_rect.position.x
		and box_rect.end.x <= ui.world_visible_rect.end.x
		and box_rect.position.y >= ui.world_visible_rect.position.y
		and box_rect.end.y <= ui.world_visible_rect.end.y
	)

	# Select stove at (288, 52) ("goreng") and verify dialogue shrinks from wide storage_box width:
	_send_left_click(ui, Vector2(288, 52))
	var stove_rect := ui.interaction_dialogue.get_rect()
	_check(
		"dialogue shrinks horizontally when switching from storage_box to stove",
		stove_rect.size.x < box_rect.size.x
		and stove_rect.position.x >= ui.world_visible_rect.position.x
		and stove_rect.end.x <= ui.world_visible_rect.end.x
		and stove_rect.position.y >= ui.world_visible_rect.position.y
		and stove_rect.end.y <= ui.world_visible_rect.end.y
	)

	# Click right-edge station online_station at (512, 84):
	_send_left_click(ui, Vector2(512, 84))
	var online_rect := ui.interaction_dialogue.get_rect()
	_check(
		"dialogue follows online_station and stays within right viewport bound",
		ui.target_title_label.text == "Stasiun Online"
		and ui.allowed_commands_label.text == "terima"
		and ui.prefix_prompt_label.text == "Ketik: terima"
		and online_rect.position.x >= ui.world_visible_rect.position.x
		and online_rect.end.x <= ui.world_visible_rect.end.x
		and online_rect.position.x > box_rect.position.x
	)

	# Typing invalid key 'z' triggers feedback message and shake without leaving bounds.
	_send_key(ui, "z".unicode_at(0), KEY_Z)
	var shake_rect := ui.interaction_dialogue.get_rect()
	_check(
		"invalid key shows Indonesian feedback and shakes within world_visible_rect",
		ui.context_message_label.visible
		and ui.context_message_label.text == "Huruf tidak cocok"
		and ui.is_shaking()
		and shake_rect.position.x >= ui.world_visible_rect.position.x
		and shake_rect.end.x <= ui.world_visible_rect.end.x
	)

	game_root.free()
	await process_frame


func _test_m1_kitchen_gameplay_and_visuals() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# In PLANNING, clicking plate_rack selects it without taking a plate.
	_send_left_click(ui, Vector2(416, 52))
	_check(
		"PLANNING click on plate_rack does not take plate",
		kitchen.get_selected_target_id() == &"plate_rack"
		and kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", -1)) == 4
	)

	# Stock storage_box in PLANNING: 2 beras, 2 telur, 1 sayur.
	_check("buy 2 beras", run.request_ingredient_purchase(&"beras", 2, &"storage_box"))
	_check("buy 2 telur", run.request_ingredient_purchase(&"telur", 2, &"storage_box"))
	_check("buy 1 sayur", run.request_ingredient_purchase(&"sayur", 1, &"storage_box"))

	# Start SERVING.
	game_root.start_service_requested()
	_check("entered SERVING for M1 kitchen loop", game_root.is_serving())

	# Empty storage retrieval fails cleanly.
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "ayam")
	_check(
		"empty ingredient retrieval emits out_of_stock without mutating hand",
		kitchen.get_held_item_view().is_empty()
		and ui.context_message_label.visible
		and ui.context_message_label.text == "Bahan habis"
	)

	# Retrieve 1 beras from storage_box (2 -> 1).
	_type_word(ui, "beras")
	var held := kitchen.get_held_item_view()
	var held_vis := world.player.get_node("VisualAnchor/HeldItemVisual") as Node2D
	_check(
		"retrieve beras decrements storage once and updates held view and player visual",
		not held.is_empty()
		and held.get("plate_id", &"") == &""
		and (held.get("parts", []) as Array).size() == 1
		and held["parts"][0].get("ingredient_id", &"") == &"beras"
		and int(held["parts"][0].get("state", -1)) == SharedTypes.PrepState.RAW
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 1
		and ui.context_message_label.text == "Bahan diambil"
		and held_vis.visible
		and held_vis.get_node_or_null("PartSprite_0") != null
	)

	# Held-item capacity restriction: retrieving telur while holding beras fails cleanly.
	_type_word(ui, "telur")
	_check(
		"retrieving second ingredient while hand full fails with hand_full and keeps stock",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][1]["quantity"]) == 2
		and ui.context_message_label.text == "Tangan penuh"
	)

	# Invalid processing: RAW beras cannot masak at rice_cooker or goreng at stove.
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "masak")
	_check(
		"RAW beras cannot masak at rice_cooker",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and ui.context_message_label.text == "Nggak bisa sekarang"
	)
	_send_left_click(ui, Vector2(288, 52))
	_type_word(ui, "goreng")
	_check(
		"RAW beras cannot goreng at stove",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and ui.context_message_label.text == "Nggak bisa sekarang"
	)

	# Wash beras at washer: RAW -> WASHED.
	_send_left_click(ui, Vector2(352, 52))
	_type_word(ui, "cuci")
	_check(
		"washer cuci transitions RAW beras to WASHED",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and ui.context_message_label.text == "Bahan dicuci"
	)

	# Cook washed beras at rice_cooker: deposits COOKED_RICE in cooker output, frees hand.
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "masak")
	var cooker_view := kitchen.get_cooker_output_view(&"rice_cooker")
	var cooker_node := world.registry.get_object(&"rice_cooker")
	var cooker_vis := cooker_node.get_node_or_null("CookerOutputVisual") as Node2D
	_check(
		"rice_cooker masak deposits COOKED_RICE output and frees hand",
		kitchen.get_held_item_view().is_empty()
		and not held_vis.visible
		and not cooker_view.is_empty()
		and int(cooker_view["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
		and cooker_vis != null
		and cooker_vis.visible
		and ui.context_message_label.text == "Nasi dimasak"
	)

	# Take plate from plate_rack (4 -> 3), then return it (3 -> 4), then take again (4 -> 3).
	var rack_node := world.registry.get_object(&"plate_rack")
	var rack_label := rack_node.get_node_or_null("PlateCountLabel") as Label
	_check("PlateRack label initially 4", rack_label != null and rack_label.text == "4")
	_send_left_click(ui, Vector2(416, 52))
	_check(
		"first plate_rack click takes 1 plate and updates count to 3",
		kitchen.get_held_item_view().get("plate_id", &"") != &""
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 3
		and rack_label.text == "3"
		and held_vis.visible
		and held_vis.get_node_or_null("PlateIndicator") != null
	)
	_send_left_click(ui, Vector2(416, 52))
	_check(
		"second plate_rack click with empty plate returns it to rack (4)",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
		and rack_label.text == "4"
	)
	_send_left_click(ui, Vector2(416, 52))
	_check(
		"take plate again for nasi_telor assembly (3 remaining)",
		kitchen.get_held_item_view().get("plate_id", &"") != &""
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 3
	)

	# Stage clean plate on WorkTable via StagingTarget (345, 116).
	_send_left_click(ui, Vector2(345, 116))
	var staged_plate := kitchen.get_work_table_view(&"work_table")
	var table_node := world.registry.get_object(&"work_table")
	var staged_vis := table_node.get_node_or_null("StagedVisual") as Node2D
	_check(
		"StagingTarget stages clean plate on WorkTable and shows StagedVisual",
		kitchen.get_held_item_view().is_empty()
		and not staged_plate.is_empty()
		and staged_plate.get("plate_id", &"") != &""
		and (staged_plate.get("parts", []) as Array).is_empty()
		and staged_vis != null
		and staged_vis.visible
		and staged_vis.get_node_or_null("PlateIndicator") != null
	)

	# Retrieve cooked rice from rice_cooker using `nasi`.
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "nasi")
	_check(
		"rice_cooker nasi retrieves COOKED_RICE and clears cooker output",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and not cooker_vis.visible
		and ui.context_message_label.text == "Nasi diambil"
	)

	# Clicking StagingTarget merges COOKED_RICE onto staged plate.
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"COOKED_RICE merges onto staged plate without completing recipe yet",
		kitchen.get_held_item_view().is_empty()
		and (kitchen.get_work_table_view(&"work_table")["parts"] as Array).size() == 1
		and kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &""
		and staged_vis.get_node_or_null("PartSprite_0") != null
	)

	# Retrieve telur from storage_box, verify raw egg texture, attempt invalid chop, fry on stove.
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "telur")
	var raw_egg_spr := held_vis.get_node_or_null("PartSprite_0") as Sprite2D
	_check(
		"held raw telur uses raw egg.png with nearest filter",
		raw_egg_spr != null
		and raw_egg_spr.texture != null
		and raw_egg_spr.texture.resource_path == "res://assets/art/ingredients/raw egg.png"
		and raw_egg_spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	)

	# Clicking ChoppingTarget (359, 116) does NOT stage telur; invalid potong preserves RAW telur.
	_send_left_click(ui, Vector2(359, 116))
	_type_word(ui, "potong")
	_check(
		"ChoppingTarget does not auto-stage held telur and rejects invalid potong",
		not kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and (kitchen.get_work_table_view(&"work_table")["parts"] as Array).size() == 1
	)

	# Fry telur at stove (`goreng`), verify cooked egg.png texture.
	_send_left_click(ui, Vector2(288, 52))
	_type_word(ui, "goreng")
	var cooked_egg_spr := held_vis.get_node_or_null("PartSprite_0") as Sprite2D
	_check(
		"stove goreng cooks telur and updates player visual to cooked egg.png",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and cooked_egg_spr != null
		and cooked_egg_spr.texture.resource_path == "res://assets/art/ingredients/cooked egg.png"
		and ui.context_message_label.text == "Bahan digoreng"
	)

	# Duplicate command prevention: pressing 'g' again starts prefix "g" without re-cooking.
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_check(
		"pressing g after goreng starts fresh prefix instead of duplicate execution",
		kitchen.get_command_prefix() == "g"
	)

	# Merge cooked telur onto staged plate -> completes nasi_telor!
	_send_left_click(ui, Vector2(345, 116))
	var assembled := kitchen.get_work_table_view(&"work_table")
	_check(
		"merging cooked telur onto plated rice assembles exact nasi_telor",
		kitchen.get_held_item_view().is_empty()
		and (assembled["parts"] as Array).size() == 2
		and assembled.get("matched_recipe_id", &"") == &"nasi_telor"
		and ui.context_message_label.text == "Hidangan siap disajikan!"
		and staged_vis.get_node_or_null("PartSprite_0") != null
		and staged_vis.get_node_or_null("PartSprite_1") != null
	)

	# Pick up completed nasi_telor into hand.
	_send_left_click(ui, Vector2(345, 116))
	var final_dish := kitchen.get_held_item_view()
	_check(
		"picking up assembled nasi_telor moves exact dish to hand and clears WorkTable",
		kitchen.get_work_table_view(&"work_table").is_empty()
		and not staged_vis.visible
		and final_dish.get("plate_id", &"") != &""
		and final_dish.get("matched_recipe_id", &"") == &"nasi_telor"
		and (final_dish.get("parts", []) as Array).size() == 2
		and held_vis.visible
		and held_vis.get_node_or_null("PlateIndicator") != null
		and held_vis.get_node_or_null("PartSprite_1") != null
	)

	game_root.free()
	await process_frame


func _test_m1_edge_cases_and_readonly() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	_check("stock storage_box", run.request_ingredient_purchase(&"beras", 2, &"storage_box"))
	_check("stock telur", run.request_ingredient_purchase(&"telur", 2, &"storage_box"))
	_check("stock sayur", run.request_ingredient_purchase(&"sayur", 1, &"storage_box"))
	game_root.start_service_requested()

	# 1. Chopping sayur at work_table_chop + frying at stove -> CHOPPED_AND_COOKED.
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "sayur")
	_send_left_click(ui, Vector2(359, 116))
	_type_word(ui, "potong")
	_check(
		"sayur chop at work_table_chop transitions RAW -> CHOPPED without staging",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.CHOPPED
		and kitchen.get_work_table_view(&"work_table").is_empty()
	)
	_send_left_click(ui, Vector2(288, 52))
	_type_word(ui, "goreng")
	_check(
		"CHOPPED sayur transitions to CHOPPED_AND_COOKED at stove",
		int(kitchen.get_held_item_view()["parts"][0]["state"])
			== SharedTypes.PrepState.CHOPPED_AND_COOKED
	)

	# Trash loose item clears hand.
	_send_left_click(ui, Vector2(224, 148))
	_check("trash discards loose held item", kitchen.get_held_item_view().is_empty())

	# 2. Loose + loose merge rejection without ingredient loss:
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "telur")
	_send_left_click(ui, Vector2(288, 52))
	_type_word(ui, "goreng")
	_send_left_click(ui, Vector2(345, 116))
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "beras")
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"loose + loose merge rejected without losing staged or held ingredient",
		not kitchen.get_work_table_view(&"work_table").is_empty()
		and kitchen.get_work_table_view(&"work_table")["parts"][0]["ingredient_id"] == &"telur"
		and not kitchen.get_held_item_view().is_empty()
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and ui.context_message_label.text == "Tidak bisa digabung"
	)

	# Wash & cook held beras; verify cooker_full rejects 2nd masak; clear work_table loose telur.
	_send_left_click(ui, Vector2(352, 52))
	_type_word(ui, "cuci")
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "masak")
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "beras")
	_send_left_click(ui, Vector2(352, 52))
	_type_word(ui, "cuci")
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "masak")
	_check(
		"second masak when cooker occupied rejects with cooker_full and preserves held rice",
		not kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and ui.context_message_label.text == "Penanak nasi penuh"
	)

	# Trash second rice, pick up staged cooked telur, verify read-only views cannot mutate state.
	_send_left_click(ui, Vector2(224, 148))
	_send_left_click(ui, Vector2(345, 116))
	var ro_held := kitchen.get_held_item_view()
	ro_held["parts"][0]["state"] = SharedTypes.PrepState.RAW
	ro_held["plate_id"] = &"fake_plate"
	_check(
		"mutating get_held_item_view() does not mutate KitchenController state",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and kitchen.get_held_item_view().get("plate_id", &"") == &""
	)

	# Trash cooked telur, then assemble nasi_telor in REVERSE order (telur first, then rice).
	_send_left_click(ui, Vector2(224, 148))
	_send_left_click(ui, Vector2(416, 52))
	_send_left_click(ui, Vector2(345, 116))
	var ro_table := kitchen.get_work_table_view(&"work_table")
	ro_table["matched_recipe_id"] = &"fake_recipe"
	_check(
		"mutating get_work_table_view() does not mutate KitchenController state",
		kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &""
	)

	# Prepare cooked telur and merge FIRST onto staged plate.
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "telur")
	# Attempt invalid merge of RAW telur onto staged plate (must reject without losing telur).
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"invalid merge of RAW telur onto staged plate rejected without resource loss",
		not kitchen.get_held_item_view().is_empty()
		and (kitchen.get_work_table_view(&"work_table")["parts"] as Array).is_empty()
		and ui.context_message_label.text == "Tidak bisa digabung"
	)
	_send_left_click(ui, Vector2(288, 52))
	_type_word(ui, "goreng")
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"cooked telur merged first onto plate",
		kitchen.get_held_item_view().is_empty()
		and (kitchen.get_work_table_view(&"work_table")["parts"] as Array).size() == 1
	)

	# Retrieve cooked rice with `nasi` and merge SECOND -> exact nasi_telor!
	_send_left_click(ui, Vector2(480, 52))
	_type_word(ui, "nasi")
	_send_left_click(ui, Vector2(345, 116))
	_check(
		"reverse plating order (telur then rice) also assembles exact nasi_telor",
		kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &"nasi_telor"
	)

	# Pick up plated nasi_telor and trash it -> food discarded, same plate_id survives clean.
	_send_left_click(ui, Vector2(345, 116))
	var plate_id_before: StringName = kitchen.get_held_item_view().get("plate_id", &"")
	_send_left_click(ui, Vector2(224, 148))
	_check(
		"trashing plated dish discards food and preserves exact reusable plate_id",
		kitchen.get_held_item_view().get("plate_id", &"") == plate_id_before
		and (kitchen.get_held_item_view().get("parts", []) as Array).is_empty()
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &""
		and kitchen.get_plate_count() == 4
	)

	# Return clean plate, drain all 4 plates from PlateRack, verify empty PlateRack rejection.
	_send_left_click(ui, Vector2(416, 52))
	for i in range(4):
		_send_left_click(ui, Vector2(416, 52))
		_send_left_click(ui, Vector2(345, 116))
		if i < 3:
			# Stage holds 1 item; move the first 3 plates to WASHER_DIRTY to drain rack.
			var p_view := kitchen.get_work_table_view(&"work_table")
			var pid: StringName = p_view.get("plate_id", &"")
			kitchen._work_table_items[&"work_table"] = {}
			kitchen._plate_records[pid]["location"] = &"CUSTOMER_TABLE"
			kitchen._plate_records[pid]["table_id"] = &"dining_table_01"
			kitchen.move_cleaned_table_plate_to_washer(&"dining_table_01")
	# Now 3 plates are WASHER_DIRTY, 1 is on work_table, 0 clean plates on PlateRack.
	var washer_spr := world.registry.get_object(&"washer").get_node("Sprite2D") as Sprite2D
	_check(
		"empty PlateRack rejects pickup with no_plates and Washer shows filled sprite",
		int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 0
		and washer_spr.region_rect == WorldMap.REGION_WASHER_FILLED
	)
	_send_left_click(ui, Vector2(416, 52))
	_check(
		"empty PlateRack click emits no_plates and keeps hand empty",
		kitchen.get_held_item_view().is_empty()
		and ui.context_message_label.text == "Piring habis"
	)

	# Washer cuci washes 1 dirty plate into held clean plate and updates count.
	_send_left_click(ui, Vector2(352, 52))
	_type_word(ui, "cuci")
	_check(
		"washer cuci washes 1 dirty plate into held clean plate",
		kitchen.get_held_item_view().get("plate_id", &"") != &""
		and (kitchen.get_held_item_view().get("parts", []) as Array).is_empty()
		and int(kitchen.get_washer_view()["dirty_plate_count"]) == 2
		and kitchen.get_plate_count() == 4
	)

	game_root.free()
	await process_frame


func _force_empty_service(service: ServiceController) -> void:
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._customers.clear()
	service._orders.clear()
	service._online_orders_open.clear()
	for table: Dictionary in service._tables.values():
		table["state"] = SharedTypes.TableState.CLEAN_VACANT
		table["customer_id_or_empty"] = &""
		table["order_id_or_empty"] = &""


func _test_worktable_hitboxes_player_movement_and_results_layout() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var player_vis := world.player as PlayerVisual

	run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
	_type_word(ui, "buka")

	# 1. WorkTable center & left area reliably select work_table_stage; cutting board selects chop.
	var center := Vector2(352, 116)
	var stage_ok := true
	for dx in [-12, -7, -2, 0, 4]:
		_send_left_click(ui, Vector2(320, 180))
		_send_left_click(ui, center + Vector2(dx, 0))
		if kitchen.get_selected_target_id() != &"work_table_stage":
			stage_ok = false
	var chop_ok := true
	for dx in [6, 7, 10, 14]:
		_send_left_click(ui, Vector2(320, 180))
		_send_left_click(ui, center + Vector2(dx, 0))
		if kitchen.get_selected_target_id() != &"work_table_chop":
			chop_ok = false
	_check("WorkTable staging zone covers left & center without gap or chop overlap", stage_ok)
	_check("WorkTable chopping board zone selects work_table_chop cleanly", chop_ok)

	# Stage plate via center click, ensure clicking plate center never enters chop mode.
	_send_left_click(ui, Vector2(416, 52))
	_send_left_click(ui, center)
	var staged_vis := world.registry.get_object(&"work_table").get_node_or_null(
		"StagedVisual"
	) as Node2D
	_check(
		"center click stages plate cleanly inside staging region",
		kitchen.get_held_item_view().is_empty()
		and kitchen.get_work_table_view(&"work_table").get("plate_id", &"") != &""
		and kitchen.get_selected_target_id() == &"work_table_stage"
		and staged_vis != null
		and staged_vis.position.is_equal_approx(Vector2(-5, -4))
	)
	_send_left_click(ui, Vector2(224, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "sayur")
	_send_left_click(ui, center + Vector2(10, 0))
	_type_word(ui, "potong")
	_check(
		"chopping sayur on cutting board remains functional while plate is staged",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.CHOPPED
		and kitchen.get_work_table_view(&"work_table").get("plate_id", &"") != &""
	)

	# 2. Smooth Player movement: authoritative tile immediate, visual animates and redirects safely.
	_send_left_click(ui, Vector2(320, 180))
	await process_frame
	for _i in range(40):
		if not player_vis.is_moving_visually():
			break
		await process_frame
	var start_pos := player_vis.get_visual_global_position()
	_send_left_click(ui, Vector2(480, 116))
	var expected_cell := kitchen.get_player_tile()
	var mid_pos := player_vis.get_visual_global_position()
	_check(
		"player logical tile updates immediately while visual interpolates from previous tile",
		expected_cell == Vector2i(10, 2)
		and world.global_to_cell(world.player.global_position) == Vector2i(10, 2)
		and player_vis.is_moving_visually()
		and mid_pos.distance_to(start_pos) < mid_pos.distance_to(world.cell_to_global(expected_cell))
	)
	# Interrupt mid-flight with a second destination -> single tween redirects without drift.
	await process_frame
	_send_left_click(ui, Vector2(224, 180))
	var next_cell := kitchen.get_player_tile()
	for _i in range(50):
		if not player_vis.is_moving_visually():
			break
		await process_frame
	_check(
		"interrupted player movement settles cleanly at final authoritative destination",
		next_cell == Vector2i(2, 4)
		and not player_vis.is_moving_visually()
		and player_vis.get_visual_global_position().is_equal_approx(world.cell_to_global(next_cell))
	)

	# 3. Day Result UI layout fits inside 640x360 viewport with unclipped clickable ContinueButton.
	_force_empty_service(service)
	game_root.request_close_if_drained()
	await process_frame
	var vp_rect := ui.get_viewport().get_visible_rect()
	var panel_rect := ui.day_result_side_panel.get_global_rect()
	var title_rect := ui.result_title_label.get_global_rect()
	var summary_rect := ui.settlement_summary_label.get_global_rect()
	var cont_rect := ui.continue_button.get_global_rect()
	_check(
		"Day 1 Result UI keeps stats readable and ContinueButton unclipped inside viewport",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and ui.day_result_side_panel.visible
		and vp_rect.encloses(panel_rect)
		and vp_rect.encloses(cont_rect)
		and ui.result_title_label.is_visible_in_tree()
		and ui.settlement_summary_label.is_visible_in_tree()
		and ui.settlement_summary_label.text.contains("Kas Awal:")
		and ui.settlement_summary_label.text.contains("Perkiraan Besok:")
		and ui.continue_button.is_visible_in_tree()
		and not ui.continue_button.disabled
		and not cont_rect.intersects(title_rect)
		and summary_rect.position.y >= title_rect.end.y - 1.0
		and cont_rect.position.y > ui.settlement_summary_label.get_parent().get_global_rect().position.y
	)
	_send_left_click(ui, cont_rect.get_center())
	await process_frame
	_check(
		"clicking visible ContinueButton advances cleanly to Day 2 PLANNING",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 2
		and not ui.day_result_side_panel.visible
	)

	game_root.free()
	await process_frame
