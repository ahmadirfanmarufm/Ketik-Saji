extends SceneTree
## Headless M4-A acceptance tests:
## Planning HUD strip, Edit Menu modal popup, and typed `buka` command flow.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_planning_hud_presentation_and_stubs()
	await _test_edit_menu_lifecycle_and_validation()
	await _test_typed_buka_command_and_guards()
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _send_left_click(ui: GameUI, pos: Vector2) -> void:
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = pos
	press_ev.global_position = pos
	var vp := ui.get_viewport()
	vp.push_input(press_ev, true)
	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = pos
	release_ev.global_position = pos
	vp.push_input(release_ev, true)


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


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _force_empty_service(service: ServiceController) -> void:
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._online_orders_open.clear()


func _advance_to_day(game_root: GameRoot, service: ServiceController, target_day: int) -> void:
	while game_root.get_day_index() < target_day:
		game_root.start_service_requested()
		_force_empty_service(service)
		game_root.request_close_if_drained()
		game_root.request_continue_from_results()


func _test_planning_hud_presentation_and_stubs() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var rv := run.get_run_view()
	_check(
		"Planning HUD shows exact required fields from RunController",
		ui.phase_label.text == "persiapan sebelum buka"
		and ui.day_label.text == "Hari 1/7"
		and ui.cash_label.text == "Kas: Rp%d" % int(rv["cash"])
		and ui.goal_label.text == "Target Hari 7: 14%"
		and is_equal_approx(
			ui.goal_progress_bar.value,
			float(rv["cash"]) / float(rv["day_7_target"])
		)
		and ui.forecast_quota_label.text == "Target Tamu: %d" % int(rv["planned_dinein_quota"])
		and ui.edit_menu_button.visible
		and ui.edit_menu_button.text == "Edit Menu"
		and ui.start_hint_label.visible
		and ui.start_hint_label.text == "Ketik: buka"
		and ui.menu_stub_button.visible
		and ui.exit_stub_button.visible
		and not ui.service_box.visible
		and not ui.day_result_side_panel.visible
	)

	# Stub Menu/Exit buttons block world clicks and do not navigate away from PLANNING.
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, ui.menu_stub_button.get_global_rect().get_center())
	ui.menu_stub_button.pressed.emit()
	ui.exit_stub_button.pressed.emit()
	_check(
		"Menu and Exit stubs preserve UI click blocking without phase change",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and kitchen.get_player_tile() == tile_before
	)

	# RunController cash change updates Planning HUD cash and percentage automatically.
	_check("buy 1 telur updates cash", run.request_ingredient_purchase(&"telur", 1, &"storage_box"))
	_check(
		"HUD cash and target progress reflect authoritative RunController state",
		ui.cash_label.text == "Kas: Rp97000"
		and ui.goal_label.text == "Target Hari 7: 14%"
		and is_equal_approx(ui.goal_progress_bar.value, 97000.0 / 700000.0)
	)

	game_root.free()
	await process_frame


func _test_edit_menu_lifecycle_and_validation() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Advance to Day 2 so 2 recipes are unlocked (nasi_telor active, nasi_ayam newly unlocked).
	_advance_to_day(game_root, service, 2)
	_check(
		"Day 2 PLANNING starts with forecast 8 for active nasi_telor while nasi_ayam is unlocked",
		game_root.get_day_index() == 2
		and ui.day_label.text == "Hari 2/7"
		and ui.forecast_quota_label.text == "Target Tamu: 8"
		and run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor", &"nasi_ayam"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	# Open Edit Menu popup via button.
	ui.edit_menu_button.grab_focus()
	ui.edit_menu_button.pressed.emit()
	await process_frame
	var telor_btn := ui.get_edit_menu_recipe_button(&"nasi_telor")
	var ayam_btn := ui.get_edit_menu_recipe_button(&"nasi_ayam")
	var komplit_btn := ui.get_edit_menu_recipe_button(&"nasi_komplit")
	var popup_rect := ui.edit_menu_popup.get_global_rect()
	_check(
		"Edit Menu popup opens centered in world area with active selection highlighted",
		ui.is_edit_menu_open()
		and ui.is_modal_blocking()
		and ui.world_visible_rect.encloses(popup_rect)
		and telor_btn != null
		and ayam_btn != null
		and komplit_btn == null
		and telor_btn.button_pressed
		and not ayam_btn.button_pressed
		and telor_btn.text.contains("Nasi Telor")
		and telor_btn.text.contains("[Aktif]")
		and not ayam_btn.text.contains("[Aktif]")
	)

	# While modal is open, world clicks, popup clicks, and gameplay typing/Escape are blocked.
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, popup_rect.get_center())
	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_send_key(ui, 0, KEY_BACKSPACE)
	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Edit Menu modal blocks world/popup clicks and buka typing",
		kitchen.get_player_tile() == tile_before
		and kitchen.get_selected_target_id() == &""
		and kitchen.get_command_prefix() == ""
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	# Toggle on nasi_ayam temporarily -> RunController unchanged until confirmation (8 -> 10).
	ayam_btn.button_pressed = true
	_check(
		"temporary toggle adds nasi_ayam in UI without mutating RunController before confirmation",
		run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and ui.get_pending_menu_selection() == [&"nasi_telor", &"nasi_ayam"]
	)

	var state_changes := { "count": 0 }
	run.run_state_changed.connect(func() -> void: state_changes["count"] += 1)
	ui.edit_menu_confirm_button.pressed.emit()
	# Attempt duplicate second submit in same sequence -> rejected cleanly.
	var second_submit := ui.submit_edit_menu([&"nasi_telor"])
	_check(
		"confirm adds nasi_ayam in RunController, refreshes forecast to 10, blocks double-submit",
		not ui.is_edit_menu_open()
		and not ui.is_modal_blocking()
		and not second_submit
		and state_changes["count"] == 1
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor", &"nasi_ayam"]
		and ui.forecast_quota_label.text == "Target Tamu: 10"
	)

	# Re-open Edit Menu, deselect nasi_ayam, and confirm -> forecast drops back from 10 to 8.
	ui.edit_menu_button.pressed.emit()
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = false
	ui.edit_menu_confirm_button.pressed.emit()
	_check(
		"deselecting recipe and confirming refreshes forecast back to 8",
		not ui.is_edit_menu_open()
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and ui.forecast_quota_label.text == "Target Tamu: 8"
	)

	# Re-open Edit Menu and verify Cancel discards temporary toggles and restores buka typing.
	ui.edit_menu_button.grab_focus()
	ui.edit_menu_button.pressed.emit()
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = true
	ui.edit_menu_cancel_button.pressed.emit()
	_check(
		"Cancel closes popup, releases button focus, and keeps active menu unchanged",
		not ui.is_edit_menu_open()
		and ui.get_viewport().gui_get_focus_owner() == null
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and ui.forecast_quota_label.text == "Target Tamu: 8"
	)

	# Verify empty, duplicate, and locked selections fail cleanly without changing active menu.
	ui.open_edit_menu()
	ui.get_edit_menu_recipe_button(&"nasi_telor").button_pressed = false
	ui.edit_menu_confirm_button.pressed.emit()
	_check(
		"empty menu selection rejected with error feedback and keeps modal open",
		ui.is_edit_menu_open()
		and ui.edit_menu_error_label.visible
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	var dup_ok := ui.submit_edit_menu([&"nasi_telor", &"nasi_telor"])
	_check(
		"duplicate recipe IDs rejected cleanly without changing active menu",
		not dup_ok
		and ui.is_edit_menu_open()
		and ui.edit_menu_error_label.visible
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	var locked_ok := ui.submit_edit_menu([&"nasi_komplit"])
	_check(
		"locked recipe ID rejected cleanly without changing active menu",
		not locked_ok
		and ui.is_edit_menu_open()
		and ui.edit_menu_error_label.visible
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)
	ui.edit_menu_cancel_button.pressed.emit()

	# Typing buka immediately after closing Edit Menu succeeds without needing another click.
	_type_word(ui, "buka")
	_check(
		"closing Edit Menu restores keyboard focus so buka starts Day 2 SERVING",
		game_root.get_phase() == SharedTypes.Phase.SERVING
	)

	game_root.free()
	await process_frame


func _test_typed_buka_command_and_guards() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var ui := game_root.get_node("UI") as GameUI

	# 1. Selecting a station in PLANNING keeps station commands and buka rejected.
	_send_left_click(ui, Vector2(192, 52))
	_check("stove selected in PLANNING", kitchen.get_selected_target_id() == &"stove")
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_check(
		"both station key (g) and buka (b) rejected while station selected in PLANNING",
		kitchen.get_command_prefix() == ""
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	# 2. Clicking floor clears selected station, enabling buka prefix typing, Backspace, and Escape.
	_send_left_click(ui, Vector2(320, 148))
	_check(
		"floor click in PLANNING clears target and exposes buka command",
		kitchen.get_selected_target_id() == &""
		and kitchen.get_allowed_commands_for_selected_target() == ["buka"]
	)

	_send_key(ui, "x".unicode_at(0), KEY_X)
	_check(
		"invalid character rejected before prefix without starting service",
		kitchen.get_command_prefix() == ""
		and ui.context_message_label.text == "Huruf tidak cocok"
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "u".unicode_at(0), KEY_U)
	_check(
		"partial prefix bu shows dialogue preview near player",
		kitchen.get_command_prefix() == "bu"
		and ui.interaction_dialogue.visible
		and ui.allowed_commands_label.text == "[bu]ka"
		and ui.remaining_prompt_label.text == "Ketik berikutnya: ka"
	)

	_send_key(ui, 0, KEY_BACKSPACE)
	_check("Backspace removes one character from buka prefix", kitchen.get_command_prefix() == "b")

	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Escape clears buka prefix cleanly",
		kitchen.get_command_prefix() == ""
		and not ui.interaction_dialogue.visible
	)

	# 3. Failed finalize_plan() keeps PLANNING and displays start_service_failed feedback.
	var run := game_root.get_run_controller() as RunController
	var original_menu: Array[StringName] = run._selected_recipe_ids.duplicate()
	run._selected_recipe_ids.clear()
	_type_word(ui, "buka")
	_check(
		"failed finalize_plan() leaves phase in PLANNING, clears prefix, and shows feedback",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and kitchen.get_command_prefix() == ""
		and ui.get_feedback_code() == &"start_service_failed"
		and ui.context_message_label.text == "Tidak bisa mulai layanan"
	)
	run._selected_recipe_ids = original_menu

	# 4. Successful buka without Enter starts service exactly once and preserves SERVING typing.
	var phase_transitions := { "count": 0 }
	game_root.phase_changed.connect(
		func(phase: int, _day: int) -> void:
			if phase == SharedTypes.Phase.SERVING:
				phase_transitions["count"] += 1
	)
	_type_word(ui, "buka")
	_check(
		"buka executes once without Enter and transitions to SERVING",
		phase_transitions["count"] == 1
		and game_root.get_phase() == SharedTypes.Phase.SERVING
		and kitchen.get_command_prefix() == ""
		and kitchen.get_last_executed_command() == "buka"
	)

	# Existing SERVING behavior: empty-target typing does not run buka; station commands still work.
	_check(
		"buka rejected during SERVING",
		not kitchen.accept_typed_character("b")
		and game_root.is_serving()
	)
	_send_left_click(ui, Vector2(352, 180))
	_check(
		"online_station terima remains functional in SERVING",
		kitchen.get_selected_target_id() == &"online_station"
		and kitchen.get_allowed_commands_for_selected_target() == ["terima"]
	)

	game_root.free()
	await process_frame
