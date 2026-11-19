extends SceneTree
## Headless integration tests for M5-C — HUD and Pause Implementation:
## - Single Rp Xk / Rp X.Yk money formatter across player-facing UI
## - Widened LeftHUDRegion (136x360), Target: Rp 700k display, and fit at 640x360 + 480x270
## - Pause open/resume/exit via strip PauseButton & Escape
## - Pause freezes GameRoot clock, SceneTree.paused, ServiceController timers, deliveries, and inputs
## - Ordinary shop overlays still allow service clock and deliveries to advance
## - Escape priority (Pause -> active modal -> selected target+prefix -> open Pause)
## - Shop + Pause restoration and phase transition guards

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_money_formatting_and_hud_fit()
	await _test_pause_freezes_timers_and_inputs()
	await _test_escape_priority_and_modal_restoration()
	await _test_pause_exit_and_phase_guards()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _send_left_click(ui: GameUI, pos: Vector2) -> void:
	var vp := ui.get_viewport()
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = pos
	press_ev.global_position = pos
	vp.push_input(press_ev, true)
	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = pos
	release_ev.global_position = pos
	vp.push_input(release_ev, true)


func _send_key(ui: GameUI, unicode_val: int, keycode_val: Key = KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	if keycode_val != KEY_NONE:
		ev.keycode = keycode_val
	elif unicode_val > 0:
		ev.keycode = OS.find_keycode_from_string(String.chr(unicode_val).to_upper())
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


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


func _hud_children_fit_inside(hud_rect: Rect2, container: Control) -> bool:
	for child in container.get_children():
		if not (child is Control):
			continue
		var ctrl := child as Control
		if not ctrl.visible:
			continue
		if ctrl is BoxContainer:
			if not _hud_children_fit_inside(hud_rect, ctrl):
				return false
		else:
			var r := ctrl.get_global_rect()
			if r.position.x < hud_rect.position.x - 0.5 or r.end.x > hud_rect.end.x + 0.5:
				return false
			if r.position.y < hud_rect.position.y - 0.5 or r.end.y > hud_rect.end.y + 0.5:
				return false
	return true


func _test_money_formatting_and_hud_fit() -> void:
	_check(
		"format_rupiah formats 0, <1k, exact k, single decimal k, and negatives cleanly",
		GameUI.format_rupiah(0) == "Rp 0"
		and GameUI.format_rupiah(500) == "Rp 500"
		and GameUI.format_rupiah(4000) == "Rp 4k"
		and GameUI.format_rupiah(4500) == "Rp 4.5k"
		and GameUI.format_rupiah(19600) == "Rp 19.6k"
		and GameUI.format_rupiah(100000) == "Rp 100k"
		and GameUI.format_rupiah(700000) == "Rp 700k"
		and GameUI.format_rupiah(-4500) == "-Rp 4.5k"
	)

	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var hud_rect := ui.left_hud_region.get_global_rect()
	_check(
		"widened LeftHUDRegion (136x360) stays clear of World at (144, 36)",
		hud_rect == Rect2(0, 0, 136, 360)
		and ui.ui_safe_rect == Rect2(0, 0, 136, 360)
		and ui.world_visible_rect == Rect2(136, 0, 504, 360)
		and world.position == Vector2(144, 36)
		and hud_rect.end.x < world.position.x
	)
	_check(
		"PLANNING HUD displays authoritative Rp Xk cash, Target: Rp 700k, progress, and Pause button",
		ui.cash_label.text == "Kas: Rp 100k"
		and ui.goal_target_label.visible
		and ui.goal_target_label.text == "Target: Rp 700k"
		and ui.goal_label.text == "Target Hari 7: 14%"
		and ui.pause_button.visible
		and not ui.pause_button.disabled
		and _hud_children_fit_inside(hud_rect, ui.left_hud_region)
	)

	# Clicking PauseButton on LeftHUDRegion never triggers world movement or station selection.
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, ui.pause_button.get_global_rect().get_center())
	await process_frame
	_check(
		"clicking HUD PauseButton opens Pause without moving player or selecting station",
		ui.is_pause_open()
		and game_root.is_paused()
		and paused == true
		and kitchen.get_player_tile() == tile_before
		and kitchen.get_selected_target_id() == &""
	)
	ui.close_pause()

	# Resize viewport to 480x270 and verify PLANNING HUD fits cleanly without clipping.
	root.content_scale_size = Vector2i(480, 270)
	root.size = Vector2i(480, 270)
	ui._on_viewport_size_changed()
	await process_frame
	await process_frame
	var small_hud := ui.left_hud_region.get_global_rect()
	_check(
		"PLANNING HUD contents fit cleanly inside 480x270 viewport",
		small_hud == Rect2(0, 0, 136, 270)
		and _hud_children_fit_inside(small_hud, ui.left_hud_region)
	)

	# Restore 640x360, enter SERVING, verify HUD state and 480x270 SERVING fit.
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	ui._on_viewport_size_changed()
	await process_frame
	_check("start service enters SERVING", game_root.start_service_requested())
	await process_frame
	_check(
		"SERVING HUD hides GoalTargetLabel/PlanningBox and keeps PauseButton active",
		not ui.goal_target_label.visible
		and ui.service_box.visible
		and ui.pause_button.visible
		and not ui.pause_button.disabled
		and _hud_children_fit_inside(ui.left_hud_region.get_global_rect(), ui.left_hud_region)
	)

	# Verify integer cash accounting stays exact even when UI formats as Rp Xk / Rp X.Yk.
	_check(
		"integer cash remains exact when purchasing 1 sayur (100000 -> 98000 = Rp 98k)",
		run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
		and int(run.get_run_view()["cash"]) == 98000
		and ui.cash_label.text == "Kas: Rp 98k"
	)

	game_root.free()
	await process_frame


func _test_pause_freezes_timers_and_inputs() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	_check("stock beras and telur", run.request_ingredient_purchase(&"beras", 2, &"storage_box"))
	_check("start service for pause timer test", game_root.start_service_requested())
	game_root._process(10.0)

	var world_node := game_root.get_node("World") as WorldMap
	var online_pt: Vector2 = (
		world_node.get_canvas_transform()
		* world_node.registry.get_object(&"online_station").global_position
	)
	_send_left_click(ui, online_pt)
	_type_word(ui, "terima")
	var drivers_before := service.get_driver_views()
	_check("online driver created before pause", drivers_before.size() == 1)
	var drv_id := StringName(drivers_before[0]["driver_id"])
	var dinein_ord_id := StringName(service.get_table_view(&"dining_table_01")["order_id_or_empty"])

	# Dismiss online_station dialogue via Escape, then open storage_box shop in SERVING.
	_send_key(ui, 0, KEY_ESCAPE)
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame
	_check("IngredientShop open", ui.is_ingredient_shop_open())
	var shop_btn_ok := ui.adjust_shop_quantity(&"sayur", 1)
	var elapsed_before_shop := game_root.get_service_elapsed()
	game_root._process(5.0)
	_check(
		"ordinary IngredientShop does NOT pause service clock",
		shop_btn_ok
		and not game_root.is_paused()
		and is_equal_approx(game_root.get_service_elapsed(), elapsed_before_shop + 5.0)
	)
	ui.submit_ingredient_shop()
	var pending_before := kitchen.get_pending_delivery_views()
	_check(
		"SERVING delivery scheduled at +100.0s",
		pending_before.size() == 1
		and is_equal_approx(float(pending_before[0]["due_at"]), elapsed_before_shop + 105.0)
	)

	# Move to storage_box and start typing partial command `b`, then pause.
	_send_left_click(ui, Vector2(256, 52))
	_send_key(ui, "b".unicode_at(0), KEY_B)
	var saved_tile := kitchen.get_player_tile()
	var saved_target := kitchen.get_selected_target_id()
	var saved_prefix := kitchen.get_command_prefix()
	var elapsed_at_pause := game_root.get_service_elapsed()
	var dinein_rem_before := float(service.get_order_view(dinein_ord_id)["seconds_remaining"])
	var driver_rem_before := float(service.get_driver_view(drv_id)["seconds_remaining"])

	_check("open Pause in SERVING", ui.open_pause())
	await process_frame
	_check(
		"Pause activates GameRoot/SceneTree pause and modal blocking",
		game_root.is_paused()
		and paused == true
		and ui.is_pause_open()
		and ui.is_modal_blocking()
		and ui.pause_resume_button.visible
		and ui.pause_exit_button.visible
	)

	# Advance clock repeatedly while paused -> clock, timers, deliveries, and inputs must stay frozen.
	game_root._process(30.0)
	ui._process(0.5)
	_send_left_click(ui, Vector2(352, 276)) # world floor click behind pause dimmer
	_send_key(ui, "e".unicode_at(0), KEY_E) # would complete "beli" if leaked
	var cmd_rect := ui.get_dialogue_command_rect("beras")
	if cmd_rect.size != Vector2.ZERO:
		_send_left_click(ui, cmd_rect.get_center())
	var pending_during := kitchen.get_pending_delivery_views()
	_check(
		"while paused, service clock, dine-in/driver timers, deliveries, world clicks, and typing all stay frozen",
		is_equal_approx(game_root.get_service_elapsed(), elapsed_at_pause)
		and ui.service_elapsed_label.text == ("Waktu: %.1f dtk" % elapsed_at_pause)
		and is_equal_approx(float(service.get_order_view(dinein_ord_id)["seconds_remaining"]), dinein_rem_before)
		and is_equal_approx(float(service.get_driver_view(drv_id)["seconds_remaining"]), driver_rem_before)
		and pending_during.size() == 1
		and kitchen.get_player_tile() == saved_tile
		and kitchen.get_selected_target_id() == saved_target
		and kitchen.get_command_prefix() == saved_prefix
		and not ui.is_ingredient_shop_open()
	)

	# Direct controller mutations are also rejected while paused.
	_check(
		"controllers reject actions while paused",
		not kitchen.on_floor_clicked(Vector2i(5, 3))
		and not kitchen.accept_typed_character("e")
		and not kitchen.execute_allowed_command(&"beras")
		and not service.try_accept_online_offer()
		and not run.request_ingredient_purchase(&"telur", 1, &"storage_box")
	)

	# Resume via PauseResumeButton -> state restored at exact same position, dialogue click works again!
	ui.pause_resume_button.pressed.emit()
	await process_frame
	_check(
		"Resume restores unpaused state, preserves player position/target/prefix, and restarts service clock",
		not game_root.is_paused()
		and paused == false
		and not ui.is_pause_open()
		and not ui.is_modal_blocking()
		and kitchen.get_player_tile() == saved_tile
		and kitchen.get_selected_target_id() == saved_target
		and kitchen.get_command_prefix() == saved_prefix
		and ui.interaction_dialogue.visible
	)

	var elapsed_before_resume_tick := game_root.get_service_elapsed()
	game_root._process(2.0)
	ui._process(0.0)
	var expected_after_tick := elapsed_before_resume_tick + 2.0
	_check(
		"service clock resumes incrementing cleanly after Resume (+2.0s)",
		is_equal_approx(game_root.get_service_elapsed(), expected_after_tick)
		and ui.service_elapsed_label.text == ("Waktu: %.1f dtk" % expected_after_tick)
	)

	# Verify M5-B3 dialogue command click still works normally after Resume.
	var eras_rect := ui.get_dialogue_command_rect("beras")
	_check("M5-B3 dialogue command rect available after resume", eras_rect.size != Vector2.ZERO)
	_send_left_click(ui, eras_rect.get_center())
	_check(
		"M5-B3 clicking AllowedCommandsLabel beras works normally after Pause Resume",
		not kitchen.get_held_item_view().is_empty()
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
	)

	game_root.free()
	await process_frame


func _test_escape_priority_and_modal_restoration() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var ui := game_root.get_node("UI") as GameUI

	# 1. PLANNING: Escape closes EditMenuOverlay without opening Pause.
	ui.open_edit_menu()
	await process_frame
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes open EditMenuOverlay first without opening Pause",
		not ui.is_edit_menu_open() and not ui.is_pause_open()
	)

	# 2. PLANNING: Open IngredientShopOverlay + add basket item -> click PauseButton -> Escape closes Pause
	# first AND restores IngredientShopOverlay + basket -> next Escape closes IngredientShopOverlay.
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"telur", 2)
	ui.pause_button.pressed.emit()
	await process_frame
	_check(
		"Pause can be opened over IngredientShopOverlay",
		ui.is_pause_open() and ui.is_ingredient_shop_open() and game_root.is_paused()
	)
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes PauseOverlay first and restores IngredientShopOverlay with basket intact",
		not ui.is_pause_open()
		and not game_root.is_paused()
		and ui.is_ingredient_shop_open()
		and ui.get_shop_basket() == { &"telur": 2 }
	)
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Second Escape closes IngredientShopOverlay without opening Pause",
		not ui.is_ingredient_shop_open() and not ui.is_pause_open()
	)

	# 3. PLANNING: With storage_box selected, Escape clears interaction without moving player or pausing.
	var plan_tile := kitchen.get_player_tile()
	_check("storage_box selected before PLANNING Escape", kitchen.get_selected_target_id() == &"storage_box")
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape with selected PLANNING storage clears interaction without moving player or opening Pause",
		kitchen.get_selected_target_id() == &""
		and kitchen.get_player_tile() == plan_tile
		and not ui.interaction_dialogue.visible
		and not ui.is_pause_open()
	)

	# 4. Neutral PLANNING (with no popup/target/prefix) -> Escape opens Pause!
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape from neutral PLANNING opens Pause",
		ui.is_pause_open() and game_root.is_paused() and paused == true
	)
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check("Escape resumes from PLANNING Pause", not ui.is_pause_open() and not game_root.is_paused())

	# 5. SERVING: Select station + type partial prefix -> Escape clears BOTH without moving tile or pausing.
	_check("start service for SERVING Escape priority", game_root.start_service_requested())
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "be")
	var serving_tile := kitchen.get_player_tile()
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"SERVING Escape clears both selected target and partial command without moving player",
		kitchen.get_selected_target_id() == &""
		and kitchen.get_command_prefix() == ""
		and kitchen.get_player_tile() == serving_tile
		and not ui.interaction_dialogue.visible
		and not ui.is_pause_open()
	)

	# 6. Neutral SERVING -> Escape opens Pause; Escape again closes Pause.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check("Escape from neutral SERVING opens Pause", ui.is_pause_open() and game_root.is_paused())
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check("Escape from SERVING Pause resumes cleanly", not ui.is_pause_open() and not game_root.is_paused())

	# 7. Closing Pause restores FixtureShopOverlay in PLANNING as well.
	game_root.free()
	await process_frame

	var fs_root := packed.instantiate() as GameRoot
	root.add_child(fs_root)
	await process_frame
	await physics_frame
	var fs_ui := fs_root.get_node("UI") as GameUI
	fs_ui.open_fixture_shop(&"slot_utility_01")
	await process_frame
	fs_ui.pause_button.pressed.emit()
	await process_frame
	_check(
		"Pause opens over FixtureShopOverlay in PLANNING",
		fs_ui.is_pause_open() and fs_ui.is_fixture_shop_open() and fs_root.is_paused()
	)
	_send_key(fs_ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes Pause first and restores FixtureShopOverlay intact",
		not fs_ui.is_pause_open()
		and not fs_root.is_paused()
		and fs_ui.is_fixture_shop_open()
		and fs_ui.get_selected_fixture_slot_id() == &"slot_utility_01"
	)
	_send_key(fs_ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Next Escape closes FixtureShopOverlay cleanly",
		not fs_ui.is_fixture_shop_open() and not fs_ui.is_pause_open()
	)
	fs_root.free()
	await process_frame


func _test_pause_exit_and_phase_guards() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI

	var exit_state := { "count": 0 }
	ui.set_exit_quit_disabled_for_test(true)
	ui.exit_game_requested.connect(func() -> void: exit_state["count"] += 1)

	ui.open_pause()
	ui.pause_exit_button.pressed.emit()
	await process_frame
	_check(
		"PauseExitButton triggers exit_game_requested and cleans up pause state",
		int(exit_state["count"]) == 1
		and not ui.is_pause_open()
		and not game_root.is_paused()
		and paused == false
	)

	# Phase transition to RESULTS disables PauseButton and rejects open_pause().
	_check("start service", game_root.start_service_requested())
	ui.open_pause()
	_check("Pause blocks request_close_if_drained while paused", game_root.is_paused())
	_force_empty_service(service)
	game_root.request_close_if_drained()
	_check("still SERVING while paused even if drained", game_root.get_phase() == SharedTypes.Phase.SERVING)
	ui.close_pause()
	game_root.request_close_if_drained()
	await process_frame
	_check(
		"RESULTS phase hides/disables PauseButton and rejects opening Pause",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and not ui.pause_button.visible
		and ui.pause_button.disabled
		and not ui.open_pause()
		and not ui.is_pause_open()
	)

	# Escape in RESULTS does NOT open Pause.
	_send_key(ui, 0, KEY_ESCAPE)
	_check("Escape in RESULTS does not open Pause", not ui.is_pause_open() and not game_root.is_paused())

	game_root.free()
	await process_frame
