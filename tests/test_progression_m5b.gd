extends SceneTree
## Headless M5-B1A regression tests:
## 1. Data-driven storage ingredient commands in KitchenController.
## 2. Day 7 WON (700000) / LOST (699999) post-electricity settlement boundaries.
## 3. Day 7 terminal behavior and Day 8 Extra Mode -> Day 9 continuation.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_data_driven_ingredient_commands()
	await _test_day7_settlement_boundaries()
	await _test_day7_terminal_extra_mode_and_day9_continuation()
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


func _force_empty_service(service: ServiceController) -> void:
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._customers.clear()
	service._online_orders_open.clear()


func _advance_to_day(
	game_root: GameRoot,
	service: ServiceController,
	target_day: int
) -> void:
	while game_root.get_day_index() < target_day:
		game_root.start_service_requested()
		_force_empty_service(service)
		game_root.request_close_if_drained()
		game_root.request_continue_from_results()


func _test_data_driven_ingredient_commands() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var empty_units: Dictionary = kitchen._storage_units.duplicate(true)

	var loaded_ids := kitchen.get_ingredient_ids()
	var expected_commands: Array[String] = []
	var unique_guard: Dictionary[String, bool] = {}
	for id in loaded_ids:
		var cmd := String(id)
		if not unique_guard.has(cmd):
			unique_guard[cmd] = true
			expected_commands.append(cmd)
	expected_commands.sort()

	_check(
		"loaded ingredient IDs contain all 6 baseline ingredients uniquely",
		loaded_ids.size() == 6 and expected_commands == [
			"ayam",
			"beras",
			"sapi",
			"sayur",
			"telur",
			"tempe",
		]
	)

	# Stock storage_box with 3 ingredients (unsorted purchase order) and enter SERVING:
	run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
	run.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	game_root.start_service_requested()
	kitchen.on_interactable_clicked(&"storage_box")
	var first_cmds := kitchen.get_allowed_commands_for_selected_target()
	var second_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"storage_box commands match beli and stocked ingredients in deterministic alphabetical order",
		first_cmds == ["ayam", "beli", "beras", "sayur"]
		and second_cmds == ["ayam", "beli", "beras", "sayur"]
	)

	# Verify non-storage station commands and order under eligible contexts:
	game_root._process(10.0)
	kitchen.on_interactable_clicked(&"online_station")
	var online_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen._try_take_raw_ingredient(&"storage_box", &"sayur")
	kitchen.on_interactable_clicked(&"work_table_chop")
	var chop_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen.on_interactable_clicked(&"stove")
	var stove_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen.on_interactable_clicked(&"trash")
	kitchen._try_take_raw_ingredient(&"storage_box", &"beras")
	kitchen.on_interactable_clicked(&"washer")
	var washer_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen._perform_typed_command(&"cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	var cooker_masak_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen._perform_typed_command(&"masak")
	var cooker_nasi_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"non-ingredient station commands and order remain preserved in valid contexts",
		stove_cmds == ["goreng"]
		and cooker_masak_cmds == ["masak"]
		and cooker_nasi_cmds == ["nasi"]
		and washer_cmds == ["cuci"]
		and chop_cmds == ["potong"]
		and online_cmds == ["terima"]
	)

	# Mutate loaded _ingredients_by_id & test stocked FRIDGE to prove list is not hardcoded.
	var backup_catalog: Dictionary[StringName, IngredientDef] = (
		kitchen._ingredients_by_id.duplicate()
	)
	var full_slots: Array[Dictionary] = []
	for id in loaded_ids:
		full_slots.append({"ingredient_id": id, "quantity": 1})
	full_slots.append({"ingredient_id": &"gula", "quantity": 1})
	kitchen._storage_units[&"test_fridge"] = {
		"utility_id": &"fridge",
		"slot_count": full_slots.size(),
		"slot_capacity": 5,
		"slots": full_slots,
	}
	kitchen._fixture_kinds[&"test_fridge"] = SharedTypes.FixtureKind.FRIDGE
	var extra_ing := IngredientDef.new()
	extra_ing.ingredient_id = &"gula"
	extra_ing.display_name = "Gula"
	kitchen._ingredients_by_id[&"gula"] = extra_ing
	kitchen._selected_target_id = &"test_fridge"
	var expanded_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"adding loaded ingredient dynamically updates sorted storage commands",
		expanded_cmds == [
			"ayam",
			"beras",
			"gula",
			"sapi",
			"sayur",
			"telur",
			"tempe",
		]
	)

	kitchen._ingredients_by_id.erase(&"gula")
	kitchen._ingredients_by_id.erase(&"sapi")
	var reduced_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"removing loaded ingredient excludes unloaded command from storage",
		reduced_cmds == ["ayam", "beras", "sayur", "telur", "tempe"]
		and not reduced_cmds.has("sapi")
	)
	# Explicitly verify "sapi" is rejected cleanly while "sayur" succeeds on reduced catalog.
	kitchen.clear_command_prefix()
	_check(
		"typing unloaded 'sapi' stops at 'sa' then rejects 'p' when sapi is unloaded",
		kitchen.accept_typed_character("s")
		and kitchen.accept_typed_character("a")
		and not kitchen.accept_typed_character("p")
	)
	kitchen.clear_command_prefix()

	# Also verify FRIDGE fixture kind branch derives from _ingredients_by_id with cabai.
	kitchen._ingredients_by_id = backup_catalog.duplicate()
	kitchen._ingredients_by_id[&"cabai"] = extra_ing
	var fridge_slots: Array[Dictionary] = []
	for id in loaded_ids:
		fridge_slots.append({"ingredient_id": id, "quantity": 1})
	fridge_slots.append({"ingredient_id": &"cabai", "quantity": 1})
	kitchen._storage_units[&"test_fridge"] = {
		"utility_id": &"fridge",
		"slot_count": fridge_slots.size(),
		"slot_capacity": 5,
		"slots": fridge_slots,
	}
	kitchen._selected_target_id = &"test_fridge"
	var fridge_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"FRIDGE target kind uses data-driven sorted ingredient commands",
		fridge_cmds == [
			"ayam",
			"beras",
			"cabai",
			"sapi",
			"sayur",
			"telur",
			"tempe",
		]
	)
	kitchen._fixture_kinds.erase(&"test_fridge")
	kitchen._storage_units = empty_units
	kitchen._ingredients_by_id = backup_catalog

	# Verify real stock take command behavior on storage_box remains unchanged.
	_check(
		"reserve_incoming_capacity for ayam on storage_box succeeds",
		kitchen.reserve_incoming_capacity(&"pur_m5b_cmd", &"ayam", 1, &"storage_box")
	)
	_check(
		"receive_stock for ayam on storage_box succeeds",
		kitchen.receive_stock(&"pur_m5b_cmd", &"ayam", 1, &"storage_box")
	)
	kitchen.on_interactable_clicked(&"storage_box")
	ui.close_ingredient_shop()
	_type_word(ui, "ayam")
	_check(
		"typing 'ayam' on storage_box consumes 1 stock and places RAW ayam in hand",
		kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"ayam"
		and kitchen.get_storage_remaining_capacity(&"storage_box") == 15
	)

	game_root.free()
	await process_frame


func _test_day7_settlement_boundaries() -> void:
	# 1. WON boundary: exact post-electricity cash == 700000.
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var won_root := packed.instantiate() as GameRoot
	root.add_child(won_root)
	await process_frame
	await physics_frame

	var won_service := won_root.get_service_controller() as ServiceController
	var won_run := won_root.get_run_controller() as RunController
	var won_ui := won_root.get_node("UI") as GameUI

	_advance_to_day(won_root, won_service, 7)
	var target: int = won_run.economy_config.day_7_cash_target
	var electricity: int = won_run.get_daily_electricity_estimate()
	_check(
		"starter Day 7 target is 700000 and starter electricity is derived from config",
		target == 700000
		and electricity == won_run.economy_config.rice_cooker_electricity_per_day
		and electricity == 2000
	)

	_check("start Day 7 WON boundary service", won_root.start_service_requested())
	# After 6 days at 2000/day, cash is 100000 - 12000 = 88000.
	# 30 dine-in nasi_telor (600000) + 1 online nasi_telor (14000) = 702000 pre-settlement.
	for i in range(30):
		won_run.credit_order_once(
			StringName("ord_won_di_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	won_run.credit_order_once(&"ord_won_ol_00", &"nasi_telor", SharedTypes.OrderKind.ONLINE)
	_check(
		"pre-settlement cash equals target + electricity (702000)",
		int(won_run.get_run_view().get("cash", 0)) == target + electricity
	)

	_force_empty_service(won_service)
	won_root.request_close_if_drained()
	var won_settlement := won_run.get_day_settlement_view(7)
	_check(
		"exact 700000 post-electricity boundary yields WON in FINISHED with ExtraModeButton",
		won_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(won_settlement.get("electricity_charge", 0)) == electricity
		and int(won_settlement.get("end_cash", 0)) == 700000
		and int(won_run.get_run_view().get("cash", 0)) == 700000
		and int(won_settlement.get("day7_outcome", -1)) == SharedTypes.DayOutcome.WON
		and int(won_run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.WON
		and won_ui.day_result_side_panel.visible
		and won_ui.result_title_label.text == "Hari 7 — Berhasil!"
		and not won_ui.continue_button.visible
		and won_ui.continue_button.disabled
		and won_ui.extra_mode_button.visible
		and not won_ui.extra_mode_button.disabled
	)
	_check(
		"Day 7 FINISHED WON rejects request_continue_from_results",
		not won_root.request_continue_from_results()
		and won_root.get_day_index() == 7
	)
	won_ui.extra_mode_button.pressed.emit()
	_check(
		"ExtraModeButton enters Day 8 PLANNING once",
		won_root.get_phase() == SharedTypes.Phase.PLANNING
		and won_root.get_day_index() == 8
		and not won_root.request_extra_mode()
	)

	won_root.free()
	await process_frame

	# 2. LOST boundary: exact post-electricity cash == 699999.
	var lost_root := packed.instantiate() as GameRoot
	root.add_child(lost_root)
	await process_frame
	await physics_frame

	var lost_service := lost_root.get_service_controller() as ServiceController
	var lost_run := lost_root.get_run_controller() as RunController
	var lost_ui := lost_root.get_node("UI") as GameUI

	_advance_to_day(lost_root, lost_service, 7)
	var lost_target: int = lost_run.economy_config.day_7_cash_target
	var lost_elec: int = lost_run.get_daily_electricity_estimate()
	_check("start Day 7 LOST boundary service", lost_root.start_service_requested())
	for i in range(30):
		lost_run.credit_order_once(
			StringName("ord_lost_di_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	lost_run.credit_order_once(&"ord_lost_ol_00", &"nasi_telor", SharedTypes.OrderKind.ONLINE)
	# Adjust 1 IDR below pre-settlement win threshold so post-electricity == 699999.
	lost_run._cash = lost_target + lost_elec - 1
	_check(
		"LOST pre-settlement cash equals target + electricity - 1 (701999)",
		int(lost_run.get_run_view().get("cash", 0)) == lost_target + lost_elec - 1
	)

	_force_empty_service(lost_service)
	lost_root.request_close_if_drained()
	var lost_settlement := lost_run.get_day_settlement_view(7)
	_check(
		"exact 699999 post-electricity boundary yields LOST in FINISHED without Extra Mode",
		lost_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(lost_settlement.get("electricity_charge", 0)) == lost_elec
		and int(lost_settlement.get("end_cash", 0)) == 699999
		and int(lost_run.get_run_view().get("cash", 0)) == 699999
		and int(lost_settlement.get("day7_outcome", -1)) == SharedTypes.DayOutcome.LOST
		and int(lost_run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.LOST
		and lost_ui.day_result_side_panel.visible
		and lost_ui.result_title_label.text == "Hari 7 — Belum cukup uang"
		and not lost_ui.continue_button.visible
		and lost_ui.continue_button.disabled
		and not lost_ui.extra_mode_button.visible
		and lost_ui.extra_mode_button.disabled
	)

	# Repeated close, settlement, continue, extra mode, and start_service stay terminal.
	lost_root.request_close_if_drained()
	var repeat_lost := lost_run.settle_day_once({
		"day_index": 7,
		"failed_order_ids": [&"ord_late"],
	})
	lost_ui.continue_button.pressed.emit()
	lost_ui.extra_mode_button.pressed.emit()
	_check(
		"Day 7 LOST remains terminal across repeated transitions and settle calls",
		not lost_root.request_extra_mode()
		and not lost_root.request_continue_from_results()
		and not lost_root.start_service_requested()
		and lost_run.advance_to_next_planning() == 7
		and lost_root.get_day_index() == 7
		and lost_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(lost_run.get_run_view().get("cash", 0)) == 699999
		and int(repeat_lost.get("end_cash", 0)) == 699999
		and int(lost_run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.LOST
	)

	lost_root.free()
	await process_frame

	# 3. Verify higher electricity (purchased fridge) turns 702000 pre-settlement into LOST.
	var elec_root := packed.instantiate() as GameRoot
	root.add_child(elec_root)
	await process_frame
	await physics_frame

	var elec_service := elec_root.get_service_controller() as ServiceController
	var elec_run := elec_root.get_run_controller() as RunController
	var fridge_elec: int = (
		elec_run.economy_config.rice_cooker_electricity_per_day
		+ elec_run.economy_config.fridge_electricity_per_day
	)
	_check(
		"purchase fridge on Day 1 PLANNING increases electricity to cooker + fridge",
		elec_run.request_fixture_purchase(&"fridge", &"slot_utility_01")
		and elec_run.get_daily_electricity_estimate() == fridge_elec
		and fridge_elec == 6000
	)
	_advance_to_day(elec_root, elec_service, 7)
	elec_root.start_service_requested()
	elec_run._cash = elec_run.economy_config.day_7_cash_target + 2000
	_force_empty_service(elec_service)
	elec_root.request_close_if_drained()
	_check(
		"702000 pre-settlement with 6000 electricity settles to 696000 LOST",
		elec_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(elec_run.get_day_settlement_view(7).get("electricity_charge", 0)) == 6000
		and int(elec_run.get_run_view().get("cash", 0)) == 696000
		and int(elec_run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.LOST
	)

	elec_root.free()
	await process_frame


func _test_day7_terminal_extra_mode_and_day9_continuation() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Verify Day 1 unlock state.
	_check(
		"Day 1 unlocks and auto-selects only nasi_telor",
		run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	# Advance to Day 2: nasi_ayam unlocks but is NOT auto-selected.
	_advance_to_day(game_root, service, 2)
	_check(
		"Day 2 unlocks nasi_ayam without auto-selecting it",
		run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor", &"nasi_ayam"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	# Advance to Day 3: nasi_komplit unlocks but is NOT auto-selected.
	_advance_to_day(game_root, service, 3)
	_check(
		"Day 3 unlocks nasi_komplit without auto-selecting it",
		run.get_run_view()["unlocked_recipe_ids"] == [
			&"nasi_telor",
			&"nasi_ayam",
			&"nasi_komplit",
		]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	# Advance Days 3 -> 7 and verify start_new_run() idempotency on progressed run.
	_advance_to_day(game_root, service, 7)
	var cash_before_reinit: int = int(run.get_run_view().get("cash", 0))
	run.start_new_run()
	_check(
		"start_new_run on Day 7 progressed run does not reset day or cash",
		game_root.get_day_index() == 7
		and int(run.get_run_view().get("cash", 0)) == cash_before_reinit
	)

	_type_word(ui, "buka")
	for i in range(35):
		run.credit_order_once(
			StringName("ord_extra_d7_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	_force_empty_service(service)
	game_root.request_close_if_drained()
	var d7_cash := int(run.get_run_view().get("cash", 0))
	_check(
		"Day 7 closes to FINISHED WON and caches settlement once",
		game_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.WON
		and int(run.settle_day_once({"day_index": 7}).get("end_cash", 0)) == d7_cash
	)

	# Transition to Day 8 Extra Mode.
	ui.extra_mode_button.pressed.emit()
	_check(
		"Day 8 Extra Mode enters PLANNING with Hari 8 label and preserved recipes",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 8
		and ui.day_label.text == "Hari 8"
		and not ui.day_result_side_panel.visible
		and run.get_run_view()["unlocked_recipe_ids"] == [
			&"nasi_telor",
			&"nasi_ayam",
			&"nasi_komplit",
		]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and not game_root.request_extra_mode()
		and run.advance_to_next_planning() == 8
	)

	# Complete Day 8 service even with cash below 700000 -> RESULTS (not FINISHED), WON preserved.
	_type_word(ui, "buka")
	_check("Day 8 buka transitions to SERVING", game_root.is_serving())
	run._cash = 10000
	_force_empty_service(service)
	game_root.request_close_if_drained()
	var d8_settlement := run.get_day_settlement_view(8)
	_check(
		"Day 8 closes to RESULTS (not FINISHED) and preserves Day 7 WON outcome",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and int(d8_settlement.get("end_cash", -1)) == 8000
		and int(d8_settlement.get("day7_outcome", -1)) == SharedTypes.DayOutcome.WON
		and int(run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.WON
		and ui.day_result_side_panel.visible
		and ui.result_title_label.text == "Hasil Hari 8"
		and ui.continue_button.visible
		and not ui.continue_button.disabled
		and not ui.extra_mode_button.visible
	)
	_check(
		"duplicate Day 8 settlement returns cached result without extra electricity charge",
		int(run.settle_day_once({"day_index": 8}).get("end_cash", -1)) == 8000
		and int(run.get_run_view().get("cash", -1)) == 8000
	)

	# Continue from Day 8 RESULTS -> Day 9 PLANNING.
	ui.continue_button.pressed.emit()
	_check(
		"ContinueButton advances Day 8 RESULTS to Day 9 PLANNING preserving Extra Mode",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 9
		and ui.day_label.text == "Hari 9"
		and not ui.day_result_side_panel.visible
		and int(run.get_run_view().get("goal_outcome", -1)) == SharedTypes.DayOutcome.WON
		and run.get_run_view()["unlocked_recipe_ids"] == [
			&"nasi_telor",
			&"nasi_ayam",
			&"nasi_komplit",
		]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	game_root.free()
	await process_frame
