extends SceneTree
## Headless M5-B1 tests:
## Five Rice Portions (`1 masak = 5 portions`) and Two-Way Plating across
## `nasi_telor`, `nasi_ayam`, and `nasi_komplit`, including serving pipeline.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_five_rice_portions_lifecycle()
	await _test_two_way_plating_directions_and_rejections()
	await _test_reverse_worktable_merge_and_plate_storage_guard()
	await _test_recipes_and_serving_compatibility()
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


func _take_raw(kitchen: KitchenController, unit_id: StringName, ing_id: StringName) -> void:
	kitchen.on_interactable_clicked(unit_id)
	for i in range(String(ing_id).length()):
		kitchen.accept_typed_character(String(ing_id).substr(i, 1))


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


func _advance_to_day(game_root: GameRoot, target_day: int) -> void:
	var service := game_root.get_service_controller() as ServiceController
	while game_root.get_day_index() < target_day:
		game_root.start_service_requested()
		_force_empty_service(service)
		game_root.request_close_if_drained()
		game_root.request_continue_from_results()


func _cook_batch_in_cooker(
	kitchen: KitchenController,
	ui: GameUI,
	cooker_id: StringName
) -> void:
	_take_raw(kitchen, &"storage_box", &"beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(cooker_id)
	_type_word(ui, "masak")


func _test_five_rice_portions_lifecycle() -> void:
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

	_check(
		"purchase second rice_cooker_01 and stock storage_box",
		run.request_fixture_purchase(&"rice_cooker", &"slot_utility_01")
		and run.request_ingredient_purchase(&"beras", 4, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 1, &"storage_box")
	)
	_check("start Day 1 service", game_root.start_service_requested())

	# 1. Invalid masak (empty hand, RAW beras, RAW telur) hides command & backend rejects cleanly.
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"empty-hand rice_cooker hides masak and nasi",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	_type_word(ui, "masak")
	kitchen._perform_typed_command(&"masak")
	_check(
		"empty-hand masak leaves cooker empty",
		kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and ui.get_feedback_code() == &"hand_empty"
	)

	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	_check(
		"RAW telur masak rejected without consuming telur or occupying cooker",
		kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
	)
	kitchen.on_interactable_clicked(&"trash")

	_take_raw(kitchen, &"storage_box", &"beras")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	_check(
		"RAW beras masak rejected without consuming beras",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
	)

	# 2. Valid WASHED beras masak creates 5 portions and displays portion badge.
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	var rc_node := world.registry.get_object(&"rice_cooker")
	var rc_vis := rc_node.get_node_or_null("CookerOutputVisual") as Node2D
	var rc_label := rc_node.get_node_or_null("CookerPortionLabel") as Label
	_check(
		"one valid masak produces 5 COOKED_RICE portions and shows badge 5",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
		and rc_vis != null and rc_vis.visible
		and rc_label != null and rc_label.visible and rc_label.text == "5"
	)

	# 3. Masak rejected while portions remain; failed nasi with loose hand spends 0 portions.
	_take_raw(kitchen, &"storage_box", &"beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"occupied rice_cooker hides masak and nasi while holding WASHED beras",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	_type_word(ui, "masak")
	kitchen._perform_typed_command(&"masak")
	_check(
		"masak rejected while 5 portions remain and preserves held WASHED beras",
		ui.get_feedback_code() == &"cooker_full"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
	)
	_type_word(ui, "nasi")
	kitchen._perform_typed_command(&"nasi")
	_check(
		"failed nasi while holding loose WASHED beras spends 0 portions",
		ui.get_feedback_code() == &"hand_full"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
	)
	kitchen.on_interactable_clicked(&"trash")

	# 4. Five retrievals decrement 5 -> 4 -> 3 -> 2 -> 1 -> empty, then 6th fails.
	for step in range(1, 6):
		kitchen.on_interactable_clicked(&"rice_cooker")
		_type_word(ui, "nasi")
		var expected_rem := 5 - step
		var held := kitchen.get_held_item_view()
		var after_view := kitchen.get_cooker_output_view(&"rice_cooker")
		if expected_rem > 0:
			_check(
				"nasi pickup #%d leaves %d portions" % [step, expected_rem],
				held.get("parts", []).size() == 1
				and held["parts"][0]["ingredient_id"] == &"beras"
				and int(held["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
				and int(after_view.get("portions", 0)) == expected_rem
				and rc_vis.visible and rc_label.visible and rc_label.text == str(expected_rem)
			)
		else:
			_check(
				"5th nasi pickup empties cooker and hides output/badge",
				held.get("parts", []).size() == 1
				and int(held["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
				and after_view.is_empty()
				and not rc_vis.visible and not rc_label.visible
			)
		kitchen.on_interactable_clicked(&"trash")

	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"empty cooker after 5th nasi pickup hides masak and nasi",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	_type_word(ui, "nasi")
	kitchen._perform_typed_command(&"nasi")
	_check(
		"6th nasi pickup fails with cooker_empty and leaves hand empty",
		kitchen.get_held_item_view().is_empty()
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and ui.get_feedback_code() == &"cooker_empty"
	)

	# 5. Starter and purchased cookers keep independent counts, and overnight close clears both.
	_cook_batch_in_cooker(kitchen, ui, &"rice_cooker")
	_cook_batch_in_cooker(kitchen, ui, &"rice_cooker_01")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"rice_cooker_01")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"trash")
	var rc01_node := world.registry.get_object(&"rice_cooker_01")
	var rc01_label := rc01_node.get_node_or_null("CookerPortionLabel") as Label
	_check(
		"starter and purchased cookers track independent portions (3 vs 4)",
		int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 3
		and rc_label.text == "3"
		and int(kitchen.get_cooker_output_view(&"rice_cooker_01").get("portions", 0)) == 4
		and rc01_label != null and rc01_label.text == "4"
	)

	_force_empty_service(service)
	game_root.request_close_if_drained()
	_check(
		"overnight cleanup clears remaining portions on both cookers",
		kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and kitchen.get_cooker_output_view(&"rice_cooker_01").is_empty()
		and not rc_vis.visible and not rc_label.visible
		and not rc01_label.visible
	)

	game_root.free()
	await process_frame


func _test_two_way_plating_directions_and_rejections() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	_advance_to_day(game_root, 4)

	_check(
		"stock ingredients for two-way plating tests",
		run.request_ingredient_purchase(&"beras", 2, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 5, &"storage_box")
		and run.request_ingredient_purchase(&"sayur", 2, &"storage_box")
	)
	_check("start service", game_root.start_service_requested())
	_cook_batch_in_cooker(kitchen, ui, &"rice_cooker")

	# 1. Non-plateable held items (RAW, WASHED, CHOPPED_AND_COOKED sayur) rejected at PlateRack
	#    without consuming any clean plate.
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"RAW telur rejected at PlateRack without consuming plate",
		ui.get_feedback_code() == &"invalid_merge"
		and kitchen.get_held_item_view().get("plate_id", &"") == &""
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) == 4
	)
	kitchen.on_interactable_clicked(&"trash")

	_take_raw(kitchen, &"storage_box", &"beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"WASHED beras rejected at PlateRack without consuming plate",
		ui.get_feedback_code() == &"invalid_merge"
		and kitchen.get_held_item_view().get("plate_id", &"") == &""
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) == 4
	)
	kitchen.on_interactable_clicked(&"trash")

	_take_raw(kitchen, &"storage_box", &"sayur")
	kitchen.on_interactable_clicked(&"work_table_chop")
	_type_word(ui, "potong")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"CHOPPED_AND_COOKED sayur rejected at PlateRack without consuming plate",
		ui.get_feedback_code() == &"invalid_merge"
		and kitchen.get_held_item_view().get("plate_id", &"") == &""
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) == 4
	)
	kitchen.on_interactable_clicked(&"trash")

	# 2. Direction 3 (Ingredient-first via PlateRack) + Direction 2 (Held plate + cooker nasi).
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"plate_rack")
	var plate_a := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	_check(
		"cooked telur + PlateRack takes 1 clean plate and plates telur in hand",
		plate_a != &""
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) == 3
		and kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &""
	)

	# Non-empty held plate + PlateRack rejects safely without losing plate or dish.
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"non-empty held plate + PlateRack rejected with hand_full",
		ui.get_feedback_code() == &"hand_full"
		and kitchen.get_held_item_view().get("plate_id", &"") == plate_a
		and kitchen.get_held_item_view().get("parts", []).size() == 1
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) == 3
	)

	# Held partial plate + cooker nasi completes nasi_telor & preserves plate_a (5 -> 4).
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	_check(
		"held partial plate + nasi merges COOKED_RICE into same plate and completes nasi_telor",
		kitchen.get_held_item_view().get("plate_id", &"") == plate_a
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_telor"
		and kitchen.get_held_item_view().get("parts", []).size() == 2
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 4
	)

	# 3. Duplicate rice on held plate hides nasi and backend rejects without spending cooker portions.
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"held plate already containing rice hides nasi at rice_cooker",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	_type_word(ui, "nasi")
	kitchen._perform_typed_command(&"nasi")
	_check(
		"duplicate nasi on held plate with rice fails invalid_merge and spends 0 portions",
		ui.get_feedback_code() == &"invalid_merge"
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 4
		and kitchen.get_held_item_view().get("plate_id", &"") == plate_a
		and kitchen.get_held_item_view().get("parts", []).size() == 2
	)
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack") # Returns empty plate_a -> 4 clean plates.

	# 4. Held empty plate + staged loose prepared telur on work_table_stage, and RAW rejection.
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"plate_rack")
	var plate_b := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	kitchen.on_interactable_clicked(&"work_table_stage")
	_check(
		"held plate + staged RAW telur on work_table_stage rejects without losing either",
		ui.get_feedback_code() == &"invalid_merge"
		and kitchen.get_held_item_view().get("plate_id", &"") == plate_b
		and kitchen.get_held_item_view().get("parts", []).is_empty()
		and kitchen.get_work_table_view(&"work_table").get("parts", []).size() == 1
	)
	kitchen.on_interactable_clicked(&"plate_rack") # Return plate_b -> empty hand.
	kitchen.on_interactable_clicked(&"work_table_stage") # Pick up RAW telur.
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage") # Stage COOKED telur.

	# Take empty plate, click cooker `nasi` -> held [COOKED_RICE], then click staged COOKED telur!
	kitchen.on_interactable_clicked(&"plate_rack")
	var plate_c := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	_check(
		"empty held plate + nasi populates rice onto plate_c (4 -> 3)",
		kitchen.get_held_item_view().get("plate_id", &"") == plate_c
		and kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 3
	)
	kitchen.on_interactable_clicked(&"work_table_stage")
	_check(
		"held plate + staged COOKED telur merges into held plate and clears work_table",
		kitchen.get_held_item_view().get("plate_id", &"") == plate_c
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_telor"
		and kitchen.get_work_table_view(&"work_table").is_empty()
	)

	# 5. Held plate + staged plate rejects without merging two plates; duplicate staged item rejects.
	kitchen.on_interactable_clicked(&"work_table_stage") # Stage completed nasi_telor plate_c.
	kitchen.on_interactable_clicked(&"plate_rack") # Take second empty plate.
	kitchen.on_interactable_clicked(&"work_table_stage")
	_check(
		"held plate + staged plate rejects cleanly",
		ui.get_feedback_code() == &"invalid_merge"
		and kitchen.get_held_item_view().get("plate_id", &"") != &""
		and kitchen.get_work_table_view(&"work_table").get("plate_id", &"") == plate_c
	)
	kitchen.on_interactable_clicked(&"plate_rack") # Return second empty plate.

	# 6. Duplicate COOKED telur held -> staged nasi_telor rejects without loss.
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	_check(
		"duplicate COOKED telur onto staged nasi_telor fails invalid_merge cleanly",
		ui.get_feedback_code() == &"invalid_merge"
		and not kitchen.get_held_item_view().is_empty()
		and kitchen.get_work_table_view(&"work_table").get("parts", []).size() == 2
	)
	kitchen.on_interactable_clicked(&"trash")

	# 7. Drain all 4 plates from PlateRack and confirm empty rack rejects cooked telur.
	kitchen.on_interactable_clicked(&"work_table_stage") # Hold completed plate_c.
	kitchen.on_interactable_clicked(&"trash") # Discard food -> holds empty plate_c.
	kitchen.on_interactable_clicked(&"plate_rack") # Return empty plate_c (4 clean plates).
	for _i in range(4):
		kitchen.on_interactable_clicked(&"plate_rack")
		var held_pid := StringName(kitchen.get_held_item_view().get("plate_id", &""))
		# Test fixture setup: move each taken plate directly to washer without customer eat wait.
		kitchen._held_item.clear()
		kitchen._plate_records[held_pid]["location"] = &"CUSTOMER_TABLE"
		kitchen._plate_records[held_pid]["table_id"] = &"dining_table_01"
		kitchen.move_cleaned_table_plate_to_washer(&"dining_table_01")
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"PlateRack with 0 clean plates rejects cooked telur with no_plates and preserves item",
		ui.get_feedback_code() == &"no_plates"
		and int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", -1)) == 0
		and kitchen.get_held_item_view().get("plate_id", &"") == &""
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
	)

	game_root.free()
	await process_frame


func _get_storage_ingredient_qty(
	kitchen: KitchenController,
	unit_id: StringName,
	ing_id: StringName
) -> int:
	var total := 0
	var unit_view := kitchen.get_storage_unit_view(unit_id)
	for slot: Variant in unit_view.get("slots", []):
		if slot is Dictionary and slot.get("ingredient_id", &"") == ing_id:
			total += int(slot.get("quantity", 0))
	return total


func _test_reverse_worktable_merge_and_plate_storage_guard() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	_advance_to_day(game_root, 3)

	_check(
		"stock storage_box for reverse worktable merge and storage guard tests",
		run.request_ingredient_purchase(&"beras", 1, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
		and run.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	)
	_check("start service for M5-B1 coverage completion", game_root.start_service_requested())
	_cook_batch_in_cooker(kitchen, ui, &"rice_cooker")

	# 1. RAW storage retrieval blocked while holding an EMPTY plate.
	kitchen.on_interactable_clicked(&"plate_rack")
	var known_plate_id := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	var box_before_empty := kitchen.get_storage_unit_view(&"storage_box")
	var telur_qty_before_empty := _get_storage_ingredient_qty(
		kitchen,
		&"storage_box",
		&"telur"
	)
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"storage_box hides ingredient commands while holding empty plate",
		kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)
	_type_word(ui, "telur")
	kitchen._perform_typed_command(&"telur")
	var held_after_empty_attempt := kitchen.get_held_item_view()
	_check(
		"holding empty plate rejects RAW storage retrieval without mutating storage or plate",
		ui.get_feedback_code() == &"hand_full"
		and telur_qty_before_empty == 2
		and _get_storage_ingredient_qty(kitchen, &"storage_box", &"telur") == 2
		and kitchen.get_storage_unit_view(&"storage_box") == box_before_empty
		and held_after_empty_attempt.get("plate_id", &"") == known_plate_id
		and (held_after_empty_attempt.get("parts", []) as Array).is_empty()
		and held_after_empty_attempt.get("matched_recipe_id", &"") == &""
	)

	# 2. RAW storage retrieval blocked while holding a PARTIAL plated item.
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	var partial_before := kitchen.get_held_item_view()
	var box_before_partial := kitchen.get_storage_unit_view(&"storage_box")
	var telur_qty_before_partial := _get_storage_ingredient_qty(
		kitchen,
		&"storage_box",
		&"telur"
	)
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"storage_box hides ingredient commands while holding partial plate",
		kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)
	_type_word(ui, "telur")
	kitchen._perform_typed_command(&"telur")
	var held_after_partial_attempt := kitchen.get_held_item_view()
	_check(
		"holding partial plate rejects RAW storage retrieval without mutating storage or parts",
		ui.get_feedback_code() == &"hand_full"
		and partial_before.get("plate_id", &"") == known_plate_id
		and telur_qty_before_partial == 2
		and _get_storage_ingredient_qty(kitchen, &"storage_box", &"telur") == 2
		and kitchen.get_storage_unit_view(&"storage_box") == box_before_partial
		and held_after_partial_attempt.get("plate_id", &"") == known_plate_id
		and (held_after_partial_attempt.get("parts", []) as Array).size() == 1
		and held_after_partial_attempt["parts"][0]["ingredient_id"] == &"beras"
		and int(held_after_partial_attempt["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
		and held_after_partial_attempt.get("matched_recipe_id", &"") == &""
	)

	# 3. Positive loose-ingredient-into-staged-plate merge on work_table_stage:
	#    Stage partial plate [COOKED_RICE], extend with COOKED ayam (incomplete -> item_merged),
	#    or extend [COOKED_RICE] with COOKED telur -> completed nasi_telor while preserving plate_id.
	kitchen.on_interactable_clicked(&"work_table_stage")
	_take_raw(kitchen, &"storage_box", &"ayam")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var staged_partial := kitchen.get_work_table_view(&"work_table")
	var staged_parts: Array = staged_partial.get("parts", [])
	_check(
		"loose cooked ayam merges into staged [COOKED_RICE] plate, keeping plate_id and completing nasi_ayam",
		ui.get_feedback_code() == &"dish_ready"
		and kitchen.get_held_item_view().is_empty()
		and staged_partial.get("plate_id", &"") == known_plate_id
		and staged_parts.size() == 2
		and staged_parts[0]["ingredient_id"] == &"beras"
		and staged_parts[1]["ingredient_id"] == &"ayam"
		and int(staged_parts[1]["state"]) == SharedTypes.PrepState.COOKED
		and staged_partial.get("matched_recipe_id", &"") == &"nasi_ayam"
	)

	# Clear stage, re-stage fresh partial [COOKED_RICE] plate, then extend with COOKED telur -> nasi_telor.
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"trash")
	var preserved_plate_id := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var staged_complete := kitchen.get_work_table_view(&"work_table")
	var complete_parts: Array = staged_complete.get("parts", [])
	_check(
		"loose cooked telur merges into staged [COOKED_RICE] plate to complete nasi_telor",
		ui.get_feedback_code() == &"dish_ready"
		and kitchen.get_held_item_view().is_empty()
		and staged_complete.get("plate_id", &"") == preserved_plate_id
		and complete_parts.size() == 2
		and complete_parts[0]["ingredient_id"] == &"beras"
		and complete_parts[1]["ingredient_id"] == &"telur"
		and int(complete_parts[1]["state"]) == SharedTypes.PrepState.COOKED
		and staged_complete.get("matched_recipe_id", &"") == &"nasi_telor"
	)

	game_root.free()
	await process_frame


func _test_recipes_and_serving_compatibility() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Advance to Day 7 so nasi_telor, nasi_ayam, and 6-part nasi_gila are all unlocked.
	_advance_to_day(game_root, 7)

	_check(
		"select 3 unlocked Day 7 recipes, buy extra box_01, and stock ingredients",
		run.select_daily_menu([&"nasi_telor", &"nasi_ayam", &"nasi_gila"])
		and run.request_fixture_purchase(&"box", &"slot_utility_01")
		and run.request_ingredient_purchase(&"beras", 2, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
		and run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
		and run.request_ingredient_purchase(&"ayam", 2, &"box_01")
		and run.request_ingredient_purchase(&"tempe", 1, &"box_01")
		and run.request_ingredient_purchase(&"sapi", 1, &"box_01")
	)
	_check("start Day 7 service", game_root.start_service_requested())
	_cook_batch_in_cooker(kitchen, ui, &"rice_cooker")

	# 1. Dine-in nasi_telor via two-way path: PlateRack <- telur, then held plate + cooker nasi.
	service._customers.clear()
	service._orders.clear()
	service._outside_dine_in_queue.clear()
	service._tables[&"dining_table_01"]["state"] = SharedTypes.TableState.OCCUPIED_WAITING
	service._tables[&"dining_table_01"]["customer_id_or_empty"] = &"cust_m5b_1"
	service._tables[&"dining_table_01"]["order_id_or_empty"] = &"ord_m5b_1"
	service._customers[&"cust_m5b_1"] = {
		"customer_id": &"cust_m5b_1",
		"state": SharedTypes.CustomerState.SEATED_WAITING,
		"table_id": &"dining_table_01",
		"order_id": &"ord_m5b_1",
		"recipe_id": &"nasi_telor",
		"eat_until": 0.0,
	}
	service._orders[&"ord_m5b_1"] = {
		"order_id": &"ord_m5b_1",
		"kind": SharedTypes.OrderKind.DINE_IN,
		"status": SharedTypes.OrderStatus.OPEN,
		"recipe_id": &"nasi_telor",
		"deadline_at": 100.0,
		"table_id_or_empty": &"dining_table_01",
		"customer_id_or_empty": &"cust_m5b_1",
	}

	_take_raw(kitchen, &"storage_box", &"telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	var telor_plate := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	var cash_before := int(run.get_run_view().get("cash", 0))
	kitchen.on_interactable_clicked(&"dining_table_01")
	_type_word(ui, "saji")
	_check(
		"two-way plated nasi_telor served via dine-in saji (+20000) and moves plate to table",
		kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view().get("cash", 0)) == cash_before + 20000
		and kitchen._plate_records[telor_plate]["location"] == &"CUSTOMER_TABLE"
	)

	# 2. Online driver nasi_ayam using remaining cooker portions (5 -> 4 -> 3) & held-plate merges.
	service._online_offer["state"] = ServiceController.OnlineOfferState.AVAILABLE
	service._online_offer["preview_recipe_id"] = &"nasi_ayam"
	service._online_offer["offer_expires_at"] = service._last_service_now + 15.0
	_check("accept online nasi_ayam offer", service.try_accept_online_offer())
	var drv_id := StringName(service.get_driver_views()[0].get("driver_id", &""))

	_take_raw(kitchen, &"box_01", &"ayam")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage") # Stage COOKED ayam.
	kitchen.on_interactable_clicked(&"plate_rack")
	var ayam_plate := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi") # Held [COOKED_RICE].
	kitchen.on_interactable_clicked(&"work_table_stage") # Merge COOKED ayam -> completed 2-part nasi_ayam!
	_check(
		"two-way plated nasi_ayam matched on plate_id cleanly",
		kitchen.get_held_item_view().get("plate_id", &"") == ayam_plate
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_ayam"
	)
	var cash_before_ayam := int(run.get_run_view().get("cash", 0))
	kitchen.on_interactable_clicked(drv_id)
	_type_word(ui, "saji")
	_check(
		"two-way plated nasi_ayam serves online driver (+20300) and returns plate to RACK",
		kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view().get("cash", 0)) == cash_before_ayam + 20300
		and kitchen._plate_records[ayam_plate]["location"] == &"RACK"
	)

	# 3. Dine-in nasi_gila (6 parts incl. chopped sayur + sapi) using 3rd portion from same batch!
	service._tables[&"dining_table_02"]["state"] = SharedTypes.TableState.OCCUPIED_WAITING
	service._tables[&"dining_table_02"]["customer_id_or_empty"] = &"cust_m5b_2"
	service._tables[&"dining_table_02"]["order_id_or_empty"] = &"ord_m5b_2"
	service._customers[&"cust_m5b_2"] = {
		"customer_id": &"cust_m5b_2",
		"state": SharedTypes.CustomerState.SEATED_WAITING,
		"table_id": &"dining_table_02",
		"order_id": &"ord_m5b_2",
		"recipe_id": &"nasi_gila",
		"eat_until": 0.0,
	}
	service._orders[&"ord_m5b_2"] = {
		"order_id": &"ord_m5b_2",
		"kind": SharedTypes.OrderKind.DINE_IN,
		"status": SharedTypes.OrderStatus.OPEN,
		"recipe_id": &"nasi_gila",
		"deadline_at": 100.0,
		"table_id_or_empty": &"dining_table_02",
		"customer_id_or_empty": &"cust_m5b_2",
	}

	_take_raw(kitchen, &"storage_box", &"sayur")
	kitchen.on_interactable_clicked(&"work_table_chop")
	_type_word(ui, "potong")
	kitchen.on_interactable_clicked(&"plate_rack") # CHOPPED sayur -> PlateRack!
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi") # Held [CHOPPED sayur, COOKED_RICE].
	kitchen.on_interactable_clicked(&"work_table_stage") # Stage partial nasi_gila plate.

	for ing_id: StringName in [&"ayam", &"tempe", &"telur", &"sapi"]:
		var src_unit := &"storage_box" if ing_id == &"telur" else &"box_01"
		_take_raw(kitchen, src_unit, ing_id)
		kitchen.on_interactable_clicked(&"stove")
		_type_word(ui, "goreng")
		kitchen.on_interactable_clicked(&"work_table_stage")

	kitchen.on_interactable_clicked(&"work_table_stage") # Pick up 6-part nasi_gila.
	_check(
		"6-part nasi_gila assembled across mixed two-way directions (2 cooker portions left)",
		kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_gila"
		and kitchen.get_held_item_view().get("parts", []).size() == 6
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 2
	)
	var cash_before_gila := int(run.get_run_view().get("cash", 0))
	kitchen.on_interactable_clicked(&"dining_table_02")
	_type_word(ui, "saji")
	_check(
		"two-way plated nasi_gila serves dine-in table_02 (+70000)",
		kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view().get("cash", 0)) == cash_before_gila + 70000
	)

	game_root.free()
	await process_frame
