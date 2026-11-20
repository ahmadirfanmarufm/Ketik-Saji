extends SceneTree
## Headless M5-B3 tests:
## InteractionDialogue Mouse & Click Routing, world click-through prevention,
## modal/phase safety, and live command-rect click dispatch via KitchenController.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_dialogue_click_blocking_and_command_execution()
	await _test_multi_unit_shop_modal_and_stale_target_guards()
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


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _click_world_pos(ui: GameUI, pos: Vector2) -> void:
	if ui.interaction_dialogue != null and ui.interaction_dialogue.visible:
		if ui.interaction_dialogue.get_global_rect().has_point(pos):
			var clear_pt := Vector2(352, 276)
			if ui.interaction_dialogue.get_global_rect().has_point(clear_pt):
				clear_pt = Vector2(160, 148)
			_send_left_click(ui, clear_pt)
	_send_left_click(ui, pos)


func _send_left_click(ui: GameUI, canvas_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = canvas_pos
	ev.global_position = canvas_pos
	ui.get_viewport().push_input(ev, true)


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


func _test_dialogue_click_blocking_and_command_execution() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var executed_log: Array[String] = []
	kitchen.command_executed.connect(
		func(cmd: StringName, target_id: StringName) -> void:
			executed_log.append("%s@%s" % [cmd, target_id])
	)

	# 1. Verify exact mouse_filter setup on InteractionDialogue and children.
	_check(
		"InteractionDialogue and AllowedCommandsLabel use STOP while passive labels IGNORE",
		ui.interaction_dialogue.mouse_filter == Control.MOUSE_FILTER_STOP
		and ui.allowed_commands_label.mouse_filter == Control.MOUSE_FILTER_STOP
		and ui.target_title_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ui.target_status_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ui.prefix_prompt_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)

	# 2. PLANNING: click storage_box -> click `beli` command opens Belanja Bahan for storage_box;
	#    non-command area click inside dialogue is consumed without opening shop or moving player.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var tile_at_box := kitchen.get_player_tile()
	var non_cmd_pt := ui.target_title_label.get_global_rect().get_center()
	var count_before_non_cmd := kitchen.get_executed_command_count()
	_send_left_click(ui, non_cmd_pt)
	_check(
		"clicking non-command title in dialogue executes 0 commands and prevents floor/world click",
		kitchen.get_executed_command_count() == count_before_non_cmd
		and kitchen.get_player_tile() == tile_at_box
		and kitchen.get_selected_target_id() == &"storage_box"
		and not ui.is_ingredient_shop_open()
	)

	var beli_rect := ui.get_dialogue_command_rect("beli")
	_check("PLANNING beli command has non-empty rect", beli_rect.size.x > 4.0 and beli_rect.size.y > 4.0)
	_send_left_click(ui, beli_rect.get_center())
	await process_frame
	_check(
		"clicking beli command in PLANNING opens Belanja Bahan via KitchenController",
		ui.is_ingredient_shop_open()
		and ui.shop_target_label.text == "Kotak Bahan"
		and not ui.interaction_dialogue.visible
		and executed_log.size() == 1
		and executed_log[-1] == "beli@storage_box"
	)

	# 3. Modal safety: shop open blocks clicks at previous dialogue position; ga jadi restores dialogue.
	_send_left_click(ui, beli_rect.get_center())
	_check(
		"open ingredient shop blocks clicks over prior dialogue area",
		ui.is_ingredient_shop_open()
		and kitchen.get_player_tile() == tile_at_box
		and executed_log.size() == 1
	)
	ui.adjust_shop_quantity(&"beras", 2)
	ui.adjust_shop_quantity(&"telur", 2)
	ui.shop_checkout_button.pressed.emit()
	await process_frame
	_check(
		"checkout closes shop, stocks storage_box, and restores dialogue in PLANNING",
		not ui.is_ingredient_shop_open()
		and ui.interaction_dialogue.visible
		and ui.target_status_label.text.contains("Beras 2")
	)

	# Start SERVING via keyboard `buka` (click free floor outside dialogue first).
	_send_left_click(ui, Vector2(352, 276))
	_check(
		"clicking floor hides InteractionDialogue cleanly",
		not ui.interaction_dialogue.visible and kitchen.get_selected_target_id() == &""
	)
	_type_word(ui, "buka")
	_check("keyboard buka enters SERVING", game_root.is_serving())

	# Explicit world-target overlap test: storage_box dialogue overlaps work_table_stage (251, 102..130).
	# Pick a point inside both work_table_stage's hitbox and InteractionDialogue (below AllowedCommandsLabel)
	# so clicking it tests world target-switch blocking rather than executing a command link.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var stage_overlap_pt := Vector2(251, 126) if ui.allowed_commands_label.get_global_rect().has_point(Vector2(251, 116)) else Vector2(251, 116)
	if ui.interaction_dialogue.get_global_rect().has_point(stage_overlap_pt):
		_send_left_click(ui, stage_overlap_pt)
		_check(
			"clicking work_table_stage covered by visible InteractionDialogue does not switch target",
			kitchen.get_selected_target_id() == &"storage_box"
		)

	# 4. In SERVING, click separator/empty padding on AllowedCommandsLabel (no exec),
	#    then click `beras` command directly (with partial prefix active!).
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "e".unicode_at(0), KEY_E)
	var beras_rect := ui.get_dialogue_command_rect("beras")
	var pad_x := ui.allowed_commands_label.get_global_rect().end.x - 1.0
	var pad_pt := Vector2(pad_x, beras_rect.get_center().y)
	if pad_pt.x > beras_rect.end.x + 1.0:
		var prev_exec := kitchen.get_executed_command_count()
		_send_left_click(ui, pad_pt)
		_check(
			"clicking empty right padding on AllowedCommandsLabel does not execute a command",
			kitchen.get_executed_command_count() == prev_exec
			and kitchen.get_held_item_view().is_empty()
		)

	_send_left_click(ui, beras_rect.get_center())
	_check(
		"clicking [be]ras in dialogue executes beras on storage_box and clears partial prefix",
		not kitchen.get_held_item_view().is_empty()
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and kitchen.get_command_prefix() == ""
		and executed_log[-1] == "beras@storage_box"
	)

	# 5. Click washer -> click `cuci`; click rice_cooker -> click `masak`; click rack/stage/cooker `nasi`.
	_send_left_click(ui, Vector2(160, 52))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("cuci").get_center())
	_check(
		"clicking cuci on washer washes beras",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and executed_log[-1] == "cuci@washer"
	)
	_send_left_click(ui, Vector2(224, 52))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("masak").get_center())
	_check(
		"clicking masak on rice_cooker cooks 5 portions",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
		and executed_log[-1] == "masak@rice_cooker"
	)

	# Cook nasi_telor mixing mouse dialogue clicks (`telur`, `goreng`, `nasi`) -> serve table_01 via click!
	_click_world_pos(ui, Vector2(288, 52))
	_click_world_pos(ui, Vector2(251, 116))
	_click_world_pos(ui, Vector2(224, 52))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("nasi").get_center())
	_click_world_pos(ui, Vector2(251, 116))
	_click_world_pos(ui, Vector2(256, 52))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("telur").get_center())
	_click_world_pos(ui, Vector2(192, 52))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("goreng").get_center())
	_click_world_pos(ui, Vector2(251, 116))
	_click_world_pos(ui, Vector2(251, 116))
	_check(
		"nasi_telor assembled using clicked dialogue commands",
		kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_telor"
	)

	# Click dining_table_01 (which also has Customer 1 waiting from t=0) and click `saji` in dialogue!
	_click_world_pos(ui, Vector2(224, 276))
	await process_frame
	_check(
		"dining_table_01 dialogue exposes clickable saji rect",
		not ui.get_dialogue_command_rect("saji").size.is_zero_approx()
	)
	_send_left_click(ui, ui.get_dialogue_command_rect("saji").get_center())
	_check(
		"clicking saji on dining_table_01 serves Customer 1 cleanly",
		ui.get_feedback_code() == &"order_served"
		and kitchen.get_held_item_view().is_empty()
		and executed_log[-1] == "saji@dining_table_01"
	)

	# 6. Hidden dialogue does NOT block underlying floor click:
	#    Move to (3, 7), select dining_table_01 at (2, 7) -> dialogue appears above over (2, 6).
	_send_left_click(ui, Vector2(256, 276))
	_send_left_click(ui, Vector2(224, 276))
	await process_frame
	var table_dlg_rect := ui.interaction_dialogue.get_global_rect()
	var under_cell := world.global_to_cell(table_dlg_rect.get_center())
	_check(
		"hidden-test precondition: table dialogue sits over free floor cell",
		ui.interaction_dialogue.visible
		and world.grid.is_free(under_cell)
		and under_cell != kitchen.get_player_tile()
	)
	# Clicking inside visible dialogue is consumed without moving player or deselecting!
	var tile_before_table_dlg := kitchen.get_player_tile()
	_send_left_click(ui, table_dlg_rect.get_center())
	_check(
		"visible dialogue over floor blocks click from moving player",
		kitchen.get_player_tile() == tile_before_table_dlg
		and kitchen.get_selected_target_id() == &"dining_table_01"
	)
	# Click another floor cell to hide dialogue, then click `table_dlg_rect.get_center()` -> moves!
	_send_left_click(ui, Vector2(352, 276))
	_check("dialogue hidden after floor click", not ui.interaction_dialogue.visible)
	_send_left_click(ui, table_dlg_rect.get_center())
	_check(
		"hidden dialogue no longer intercepts click on underlying floor cell",
		kitchen.get_player_tile() == under_cell
	)

	game_root.free()
	await process_frame


func _test_multi_unit_shop_modal_and_stale_target_guards() -> void:
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

	# Buy fridge_01 in slot_utility_01 and verify `beli` click targets whichever container is selected.
	_check("buy fridge_01", run.request_fixture_purchase(&"fridge", &"slot_utility_01"))
	var fridge_node := world.registry.get_object(&"fridge_01") as Node2D
	var fridge_canvas := world.get_canvas_transform() * fridge_node.global_position
	_send_left_click(ui, fridge_canvas)
	await process_frame
	_check(
		"fridge_01 selected without opening shop",
		kitchen.get_selected_target_id() == &"fridge_01"
		and not ui.is_ingredient_shop_open()
	)
	_send_left_click(ui, ui.get_dialogue_command_rect("beli").get_center())
	await process_frame
	_check(
		"clicking beli routes strictly to currently selected fridge_01 (not storage_box)",
		ui.is_ingredient_shop_open()
		and ui.shop_target_label.text == "Kulkas"
		and ui.get_shop_remaining_capacity() == 6
	)
	ui.shop_cancel_button.pressed.emit()
	_check(
		"closing shop restores InteractionDialogue on fridge_01 cleanly",
		not ui.is_ingredient_shop_open()
		and ui.interaction_dialogue.visible
		and kitchen.get_selected_target_id() == &"fridge_01"
	)

	# Dialogue covering an adjacent interactable prevents click-through onto that world target.
	# Ensure storage_box selection dialogue does not accidentally switch target when clicked inside.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var box_dlg_center := ui.target_title_label.get_global_rect().get_center()
	_send_left_click(ui, box_dlg_center)
	_check(
		"clicking inside storage_box dialogue never selects a different world target underneath",
		kitchen.get_selected_target_id() == &"storage_box"
		and not ui.is_ingredient_shop_open()
	)

	# Start SERVING and test online `terima` click, stale target rejection, and RESULTS safety.
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check("entered SERVING", game_root.is_serving())

	game_root._process(10.0)
	_send_left_click(ui, Vector2(352, 180))
	await process_frame
	_send_left_click(ui, ui.get_dialogue_command_rect("terima").get_center())
	_check(
		"clicking terima in online_station dialogue accepts 1 driver",
		service.get_driver_views().size() == 1
	)

	# Direct execution guards on stale/ineligible targets & disabled/hidden UI.
	_check(
		"ineligible command saji cannot execute on online_station",
		not kitchen.execute_allowed_command(&"saji")
	)
	kitchen._selected_target_id = &"nonexistent_target"
	_check(
		"stale/invalid selected target cannot execute commands",
		not kitchen.execute_allowed_command(&"beli")
		and not kitchen.execute_allowed_command(&"goreng")
	)
	kitchen._selected_target_id = &"storage_box"

	# Hidden dialogue element cannot execute commands even on synthetic gui_input.
	_force_empty_service(service)
	game_root._process(0.2)
	_check(
		"CLOSING/RESULTS hides InteractionDialogue and rejects execute_allowed_command",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and not ui.interaction_dialogue.visible
		and not kitchen.execute_allowed_command(&"beli")
	)
	var synthetic_ev := InputEventMouseButton.new()
	synthetic_ev.pressed = true
	synthetic_ev.button_index = MOUSE_BUTTON_LEFT
	synthetic_ev.position = Vector2(4.0, 4.0)
	ui._on_allowed_commands_gui_input(synthetic_ev)
	_check(
		"synthetic click on hidden AllowedCommandsLabel in RESULTS never opens shop",
		not ui.is_ingredient_shop_open()
	)

	game_root.free()
	await process_frame
