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
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


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
		"StartService, Continue, and ExtraMode buttons support keyboard focus (FOCUS_ALL)",
		ui.start_service_button.focus_mode == Control.FOCUS_ALL
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
	_check("initial DayLabel is Hari 1", ui.day_label.text == "Hari 1")
	_check("initial PhaseLabel is Perencanaan", ui.phase_label.text == "Perencanaan")
	_check("initial CashLabel is Kas: Rp100000", ui.cash_label.text == "Kas: Rp100000")
	_check(
		"initial GoalLabel is Target Hari 7: Rp700000",
		ui.goal_label.text == "Target Hari 7: Rp700000"
	)
	_check(
		"initial GoalProgressBar ratio is 100000 / 700000",
		is_equal_approx(ui.goal_progress_bar.value, 100000.0 / 700000.0)
	)
	_check(
		"initial PlanningBox visible with Target Tamu: 4",
		ui.planning_box.visible and ui.forecast_quota_label.text == "Target Tamu: 4"
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

	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Verify StartServiceButton can grab keyboard focus in PLANNING and activate via Enter key:
	ui.start_service_button.grab_focus()
	_check(
		"StartServiceButton grabs keyboard focus in PLANNING",
		ui.start_service_button.has_focus() and not ui.start_service_button.disabled
	)

	var enter_press := InputEventKey.new()
	enter_press.pressed = true
	enter_press.keycode = KEY_ENTER
	enter_press.physical_keycode = KEY_ENTER
	ui.get_viewport().push_input(enter_press, true)
	var enter_release := InputEventKey.new()
	enter_release.pressed = false
	enter_release.keycode = KEY_ENTER
	enter_release.physical_keycode = KEY_ENTER
	ui.get_viewport().push_input(enter_release, true)
	_check(
		"Enter key on focused StartServiceButton enters SERVING and releases focus",
		game_root.is_serving()
		and not ui.start_service_button.has_focus()
		and ui.start_service_button.disabled
		and not ui.planning_box.visible
		and ui.service_box.visible
		and not ui.day_result_side_panel.visible
		and ui.phase_label.text == "Layanan"
		and ui.unspawned_quota_label.text == "Antrean Datang: 4"
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
	service._day_queue_remaining = 0
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
		and ui.day_label.text == "Hari 2"
		and ui.planning_box.visible
		and not ui.day_result_side_panel.visible
	)

	# Advance Days 2-6 to Day 7, win Day 7, and verify FINISHED + ExtraModeButton.
	for _day in range(2, 7):
		ui.start_service_button.pressed.emit()
		service._day_queue_remaining = 0
		game_root.request_close_if_drained()
		ui.continue_button.pressed.emit()

	_check("reached Day 7 PLANNING via UI buttons", game_root.get_day_index() == 7)
	ui.start_service_button.pressed.emit()
	for i in range(35):
		run.credit_order_once(
			StringName("ord_ui_d7_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	service._day_queue_remaining = 0
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

	# Also verify Day 7 FINISHED(LOST) displays "Belum cukup uang" and hides both buttons:
	var lost_root := packed.instantiate() as GameRoot
	root.add_child(lost_root)
	await process_frame
	var lost_service := lost_root.get_service_controller() as ServiceController
	var lost_ui := lost_root.get_node("UI") as GameUI
	for _day in range(1, 7):
		lost_ui.start_service_button.pressed.emit()
		lost_service._day_queue_remaining = 0
		lost_root.request_close_if_drained()
		lost_ui.continue_button.pressed.emit()
	lost_ui.start_service_button.pressed.emit()
	lost_service._day_queue_remaining = 0
	lost_root.request_close_if_drained()
	_check(
		"Day 7 LOST shows Belum cukup uang and hides Continue/ExtraMode buttons",
		lost_root.get_phase() == SharedTypes.Phase.FINISHED
		and lost_ui.day_result_side_panel.visible
		and lost_ui.result_title_label.text.contains("Belum cukup uang")
		and not lost_ui.continue_button.visible
		and not lost_ui.extra_mode_button.visible
	)
	lost_root.free()
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
	ui.start_service_button.pressed.emit()
	service._day_queue_remaining = 0
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
	ui.start_service_button.pressed.emit()
	_send_left_click(ui, Vector2(288, 52))
	_check(
		"stove selected in SERVING with allowed command goreng",
		kitchen.get_selected_target_id() == &"stove"
		and kitchen.get_allowed_commands_for_selected_target() == ["goreng"]
	)

	# Type 'g', 'o', 'r' -> prefix becomes "gor".
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_send_key(ui, "o".unicode_at(0), KEY_O)
	_send_key(ui, "r".unicode_at(0), KEY_R)
	_check(
		"Unicode keys g, o, r accepted in SERVING",
		kitchen.get_command_prefix() == "gor"
		and ui.prefix_prompt_label.text == "[ GOReng ]"
	)

	# Key echo ('e' with echo=true) must be ignored.
	_send_key(ui, "e".unicode_at(0), KEY_E, true)
	_check("key echo ignored", kitchen.get_command_prefix() == "gor")

	# Invalid key 'z' while prefix is "gor" shows feedback; Escape clears both prefix and feedback.
	_send_key(ui, "z".unicode_at(0), KEY_Z)
	_check(
		"invalid key z with active prefix shows feedback and shake",
		kitchen.get_command_prefix() == "gor"
		and ui.context_message_label.visible
		and ui.is_shaking()
	)
	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Escape clears command prefix and clears invalid-key feedback/shake",
		kitchen.get_command_prefix() == ""
		and ui.prefix_prompt_label.text == "[ goreng ]"
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

	# Typing full word "goreng" auto-executes and clears prefix without Enter.
	for ch in ["g", "o", "r", "e", "n", "g"]:
		_send_key(ui, ch.unicode_at(0))
	_check(
		"full word goreng auto-executes and clears prefix without Enter",
		kitchen.get_command_prefix() == ""
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
	ui.start_service_button.pressed.emit()

	# Click top-left station storage_box at (224, 52):
	_send_left_click(ui, Vector2(224, 52))
	_check(
		"dialogue shows Kotak Bahan and 6 ingredient commands",
		ui.interaction_dialogue.visible
		and ui.target_title_label.text == "Kotak Bahan"
		and ui.allowed_commands_label.text == "ayam, beras, sapi, sayur, telur, tempe"
		and ui.prefix_prompt_label.text == "[ ... ]"
	)

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
		and ui.prefix_prompt_label.text == "[ terima ]"
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
