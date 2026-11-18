extends SceneTree
## Headless M4-C acceptance tests:
## Fixture Upgrade & Placement System (`Belanja Peralatan`), slot validation,
## dynamic fixture interaction (`stove_01`, `rice_cooker_01`, `fridge_01`,
## `plate_rack_01`, `washer_01`, `dining_table_03`), Complexity Debt electricity,
## and Day 1 -> Day 2 persistence.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_starter_fixtures_and_ui_information()
	await _test_purchase_validation_and_rejections()
	await _test_additional_stove_placement_and_cooking()
	await _test_other_dynamic_fixtures_and_electricity_persistence()
	await _test_fixture_shop_responsive_layout()
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


func _test_starter_fixtures_and_ui_information() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var world := game_root.get_node("World") as WorldMap

	var run_view: Dictionary = run.get_run_view()
	var installed: Dictionary = run_view.get("installed_fixtures", {})
	_check("m4c_starter_fixture_count_7", installed.size() == 7)
	_check("m4c_starter_has_stove", installed.has(&"stove"))
	_check("m4c_starter_has_rice_cooker", installed.has(&"rice_cooker"))
	_check("m4c_starter_has_storage_box", installed.has(&"storage_box"))
	_check("m4c_starter_has_washer", installed.has(&"washer"))
	_check("m4c_starter_has_plate_rack", installed.has(&"plate_rack"))
	_check("m4c_starter_has_table_01", installed.has(&"dining_table_01"))
	_check("m4c_starter_has_table_02", installed.has(&"dining_table_02"))
	_check(
		"m4c_starter_stove_kind_registered",
		kitchen.get_fixture_kind(&"stove") == SharedTypes.FixtureKind.STOVE
	)
	_check(
		"m4c_starter_daily_electricity_2000",
		run.get_daily_electricity_estimate() == 2000
	)
	_check(
		"m4c_placement_slots_count_11",
		world.get_placement_slot_ids().size() == 11
	)

	_check(
		"m4c_fixture_shop_button_visible_in_planning",
		ui.fixture_shop_button != null and ui.fixture_shop_button.visible
	)
	ui.fixture_shop_button.pressed.emit()
	_check("m4c_fixture_shop_opens_on_button", ui.is_fixture_shop_open())
	_check("m4c_fixture_shop_blocks_modal", ui.is_modal_blocking())

	var stove_row: Dictionary = ui.get_fixture_shop_row(&"stove")
	var fridge_row: Dictionary = ui.get_fixture_shop_row(&"fridge")
	_check("m4c_stove_row_exists", not stove_row.is_empty())
	_check("m4c_fridge_row_exists", not fridge_row.is_empty())
	var stove_title := (stove_row.get("title_label") as Label).text
	var stove_benefit := (stove_row.get("benefit_label") as Label).text
	var fridge_downside := (fridge_row.get("downside_label") as Label).text
	_check(
		"m4c_stove_shows_name_category_price",
		stove_title.contains("Kompor")
		and stove_title.contains("Alat Masak")
		and stove_title.contains("Rp60000")
	)
	_check(
		"m4c_stove_shows_benefit",
		stove_benefit.contains("Manfaat:") and stove_benefit.contains("kompor")
	)
	_check(
		"m4c_fridge_shows_complexity_debt_electricity",
		fridge_downside.contains("Complexity Debt") and fridge_downside.contains("Rp4000/hari")
	)

	_send_key(ui, 0, KEY_ESCAPE)
	_check("m4c_escape_closes_fixture_shop", not ui.is_fixture_shop_open())

	# Clicking an empty placement slot in the world during PLANNING opens the shop for that slot
	var slot_view: Dictionary = world.get_placement_slot_view(&"slot_utility_02")
	var slot_world_pos: Vector2 = slot_view.get("global_position", Vector2.ZERO)
	var slot_canvas_pos: Vector2 = world.get_canvas_transform() * slot_world_pos
	_send_left_click(ui, slot_canvas_pos)
	_check("m4c_world_slot_click_opens_fixture_shop", ui.is_fixture_shop_open())
	_check(
		"m4c_world_slot_click_selects_slot_utility_02",
		ui.get_selected_fixture_slot_id() == &"slot_utility_02"
	)
	ui.close_fixture_shop()

	game_root.free()
	await process_frame


func _test_purchase_validation_and_rejections() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController

	# 1. Invalid utility definitions & slot IDs
	_check(
		"m4c_reject_empty_utility_id",
		not run.request_fixture_purchase(&"", &"slot_utility_01")
	)
	_check(
		"m4c_reject_unknown_utility_id",
		not run.request_fixture_purchase(&"laser_oven", &"slot_utility_01")
	)
	_check(
		"m4c_reject_invalid_slot_id",
		not run.request_fixture_purchase(&"stove", &"slot_nonexistent")
	)

	var bad_def := UtilityDef.new()
	bad_def.utility_id = &"bad_util"
	bad_def.purchase_price = 0
	bad_def.footprint = Vector2i.ZERO
	run._utility_defs[&"bad_util"] = bad_def
	_check(
		"m4c_reject_invalid_utility_def",
		not run.request_fixture_purchase(&"bad_util", &"slot_utility_01")
	)
	run._utility_defs.erase(&"bad_util")

	# 2. Incompatible placement slots
	_check(
		"m4c_reject_stove_in_table_slot",
		not run.request_fixture_purchase(&"stove", &"slot_table_01")
	)
	_check(
		"m4c_reject_table_in_utility_slot",
		not run.request_fixture_purchase(&"dining_table", &"slot_utility_01")
	)

	ui.open_fixture_shop(&"slot_table_01")
	ui.select_fixture_shop_utility(&"stove")
	var ui_incompat: bool = ui.submit_fixture_shop()
	_check("m4c_ui_rejects_incompatible_slot", not ui_incompat)
	_check(
		"m4c_ui_shows_incompatible_error",
		ui.fixture_error_label.visible
		and ui.fixture_error_label.text.contains("tidak cocok")
	)

	# 3. Valid purchase via UI into slot_utility_01 (Stove Rp60,000, cash 100k -> 40k)
	ui.select_fixture_shop_slot(&"slot_utility_01")
	ui.select_fixture_shop_utility(&"stove")
	var ui_ok: bool = ui.submit_fixture_shop()
	_check("m4c_ui_valid_stove_purchase", ui_ok)
	_check("m4c_ui_closes_after_purchase", not ui.is_fixture_shop_open())
	_check(
		"m4c_cash_deducted_once_to_40000",
		int(run.get_run_view().get("cash", 0)) == 40000
	)
	_check(
		"m4c_feedback_fixture_purchased",
		ui.get_feedback_code() == &"fixture_purchased"
	)

	# 4. Occupied slot rejection (buying box Rp40,000 into already occupied slot_utility_01)
	ui.open_fixture_shop(&"slot_utility_01")
	ui.select_fixture_shop_utility(&"box")
	var occupied_ok: bool = ui.submit_fixture_shop()
	_check("m4c_reject_occupied_slot", not occupied_ok)
	_check(
		"m4c_ui_shows_occupied_error",
		ui.fixture_error_label.visible
		and ui.fixture_error_label.text.contains("terisi")
	)
	_check(
		"m4c_cash_unchanged_after_occupied_reject",
		int(run.get_run_view().get("cash", 0)) == 40000
	)

	# 5. Insufficient cash rejection (cash is Rp40,000, fridge costs Rp80,000 in slot_utility_02)
	ui.select_fixture_shop_slot(&"slot_utility_02")
	ui.select_fixture_shop_utility(&"fridge")
	var broke_ok: bool = ui.submit_fixture_shop()
	_check("m4c_reject_insufficient_cash", not broke_ok)
	_check(
		"m4c_ui_shows_insufficient_cash_error",
		ui.fixture_error_label.visible
		and ui.fixture_error_label.text.contains("Kas tidak cukup")
	)
	_check(
		"m4c_cash_unchanged_after_insufficient_reject",
		int(run.get_run_view().get("cash", 0)) == 40000
	)
	_check(
		"m4c_slot_utility_02_still_unoccupied",
		run.get_compatible_empty_slots(&"box").has(&"slot_utility_02")
	)
	ui.close_fixture_shop()

	# 6. Prevent purchases during SERVING and RESULTS
	var service := game_root.get_service_controller() as ServiceController
	_type_word(ui, "buka")
	_check("m4c_entered_serving", game_root.get_phase() == SharedTypes.Phase.SERVING)
	_check(
		"m4c_cannot_open_fixture_shop_in_serving",
		not ui.open_fixture_shop(&"slot_utility_02")
	)
	_check(
		"m4c_controller_rejects_fixture_purchase_in_serving",
		not run.request_fixture_purchase(&"box", &"slot_utility_02")
	)

	_force_empty_service(service)
	game_root._process(0.2)
	_check("m4c_entered_results_for_phase_check", game_root.get_phase() == SharedTypes.Phase.RESULTS)
	_check(
		"m4c_cannot_open_fixture_shop_in_results",
		not ui.open_fixture_shop(&"slot_utility_02")
	)
	_check(
		"m4c_controller_rejects_fixture_purchase_in_results",
		not run.request_fixture_purchase(&"box", &"slot_utility_02")
	)

	game_root.free()
	await process_frame


func _test_additional_stove_placement_and_cooking() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var world := game_root.get_node("World") as WorldMap

	# Buy additional stove in slot_utility_01 (Rp60,000) and eggs/chicken in storage_box
	var bought_stove: bool = run.request_fixture_purchase(&"stove", &"slot_utility_01")
	_check("m4c_stove_01_purchased", bought_stove)
	var inst: Dictionary = run.get_fixture_instance(&"stove_01")
	_check("m4c_stove_01_instance_exists", not inst.is_empty())
	_check(
		"m4c_stove_01_registered_in_world_registry",
		world.registry.get_object(&"stove_01") != null
	)
	_check(
		"m4c_stove_01_cell_occupied_by_stove_01",
		world.grid.get_occupant(Vector2i(5, 0)) == &"stove_01"
		and not world.grid.is_free(Vector2i(5, 0))
	)
	_check(
		"m4c_stove_01_registered_in_kitchen_controller",
		kitchen.get_fixture_kind(&"stove_01") == SharedTypes.FixtureKind.STOVE
	)
	_check(
		"m4c_stove_01_display_title",
		ui.get_target_display_title(&"stove_01") == "Kompor"
	)

	# Buy telur & ayam in PLANNING (Rp3,000 + Rp5,000 = Rp8,000)
	var basket_items: Dictionary[StringName, int] = {&"telur": 2, &"ayam": 1}
	var basket_ok: bool = run.request_ingredient_basket_purchase(
		basket_items,
		&"storage_box"
	)
	_check("m4c_ingredients_bought_for_stove_test", basket_ok)

	# Buy additional plate_rack_01 in slot_utility_02 (temporarily Rp10,000)
	var pr_def: UtilityDef = run.get_utility_def(&"plate_rack")
	var orig_pr_price: int = pr_def.purchase_price
	pr_def.purchase_price = 10000
	var bought_pr: bool = run.request_fixture_purchase(&"plate_rack", &"slot_utility_02")
	pr_def.purchase_price = orig_pr_price
	_check("m4c_plate_rack_01_purchased", bought_pr)
	var pr_view: Dictionary = kitchen.get_plate_rack_view(&"plate_rack_01")
	_check("m4c_plate_rack_01_has_4_clean_plates", int(pr_view.get("clean_count", 0)) == 4)

	# Start SERVING
	_type_word(ui, "buka")
	_check("m4c_serving_started_for_stove_test", game_root.is_serving())
	await physics_frame

	# Click plate_rack_01 to take a clean plate, then click again to return it
	kitchen.on_interactable_clicked(&"plate_rack_01")
	_check(
		"m4c_took_plate_from_plate_rack_01",
		StringName(kitchen.get_held_item_view().get("plate_id", &"")) != &""
		and int(kitchen.get_plate_rack_view(&"plate_rack_01").get("clean_count", 0)) == 3
	)
	kitchen.on_interactable_clicked(&"plate_rack_01")
	_check(
		"m4c_returned_plate_to_plate_rack_01",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_plate_rack_view(&"plate_rack_01").get("clean_count", 0)) == 4
	)

	# Take raw telur from storage_box
	kitchen.on_interactable_clicked(&"storage_box")
	ui.close_ingredient_shop()
	_type_word(ui, "telur")
	var held_raw: Dictionary = kitchen.get_held_item_view()
	_check(
		"m4c_holding_raw_telur",
		not held_raw.is_empty()
		and held_raw["parts"][0]["ingredient_id"] == &"telur"
		and held_raw["parts"][0]["state"] == SharedTypes.PrepState.RAW
	)

	# Click stove_01 at (3, 2) -> auto-teleports adjacent and selects stove_01
	var clicked_stove_01: bool = kitchen.on_interactable_clicked(&"stove_01")
	_check("m4c_clicked_stove_01_in_serving", clicked_stove_01)
	var allowed_stove_01: Array[String] = kitchen.get_allowed_commands_for_selected_target()
	_check(
		"m4c_stove_01_allows_goreng_command",
		allowed_stove_01.has("goreng")
	)
	_type_word(ui, "goreng")
	var held_cooked: Dictionary = kitchen.get_held_item_view()
	_check(
		"m4c_stove_01_cooked_telur_to_cooked_state",
		not held_cooked.is_empty()
		and held_cooked["parts"][0]["ingredient_id"] == &"telur"
		and held_cooked["parts"][0]["state"] == SharedTypes.PrepState.COOKED
	)
	_check(
		"m4c_stove_01_emits_item_cooked_feedback",
		ui.get_feedback_code() == &"item_cooked"
	)

	# Trash cooked egg and verify starter stove at (7, 2) still works for raw telur
	kitchen.on_interactable_clicked(&"trash")
	_type_word(ui, "buang")

	kitchen.on_interactable_clicked(&"storage_box")
	ui.close_ingredient_shop()
	_type_word(ui, "telur")

	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	var starter_cooked: Dictionary = kitchen.get_held_item_view()
	_check(
		"m4c_starter_stove_still_cooks_telur",
		not starter_cooked.is_empty()
		and starter_cooked["parts"][0]["state"] == SharedTypes.PrepState.COOKED
	)

	game_root.free()
	await process_frame


func _test_other_dynamic_fixtures_and_electricity_persistence() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var world := game_root.get_node("World") as WorldMap

	var bought_fridge: bool = run.request_fixture_purchase(&"fridge", &"slot_utility_01")
	_check("m4c_fridge_01_purchased", bought_fridge)
	_check(
		"m4c_fridge_01_cash_after_80k",
		int(run.get_run_view().get("cash", 0)) == 20000
	)
	_check(
		"m4c_fridge_01_registered_storage_unit",
		kitchen.has_storage_unit(&"fridge_01")
	)
	var fridge_view: Dictionary = kitchen.get_storage_unit_view(&"fridge_01")
	_check(
		"m4c_fridge_01_has_2_slots_cap_3",
		(fridge_view.get("slots", []) as Array).size() == 2
		and int((fridge_view.get("slots", []) as Array)[0].get("capacity", 0)) == 3
	)
	_check(
		"m4c_daily_electricity_estimate_with_fridge_is_6000",
		run.get_daily_electricity_estimate() == 6000
	)

	# Buy rice_cooker into slot_utility_02 after adjusting rice_cooker price to Rp10,000 for test
	var rc_def: UtilityDef = run.get_utility_def(&"rice_cooker")
	var orig_rc_price: int = rc_def.purchase_price
	rc_def.purchase_price = 10000
	var bought_rc: bool = run.request_fixture_purchase(&"rice_cooker", &"slot_utility_02")
	rc_def.purchase_price = orig_rc_price
	_check("m4c_rice_cooker_01_purchased", bought_rc)
	_check(
		"m4c_daily_electricity_estimate_with_fridge_and_extra_rc_is_8000",
		run.get_daily_electricity_estimate() == 8000
	)

	# Buy dining_table into slot_table_01 (temporarily priced at Rp5,000)
	var dt_def: UtilityDef = run.get_utility_def(&"dining_table")
	var orig_dt_price: int = dt_def.purchase_price
	dt_def.purchase_price = 5000
	var bought_dt: bool = run.request_fixture_purchase(&"dining_table", &"slot_table_01")
	dt_def.purchase_price = orig_dt_price
	_check("m4c_dining_table_03_purchased", bought_dt)
	_check(
		"m4c_dining_table_03_registered_in_service",
		service.has_table(&"dining_table_03")
	)

	# Buy 2 beras (Rp4,000) into fridge_01 in PLANNING (remaining cash: 5000 -> 1000)
	var fridge_basket: Dictionary[StringName, int] = {&"beras": 2}
	var stocked_fridge: bool = run.request_ingredient_basket_purchase(
		fridge_basket,
		&"fridge_01"
	)
	_check("m4c_stocked_beras_into_fridge_01", stocked_fridge)
	_check(
		"m4c_cash_is_1000_before_service",
		int(run.get_run_view().get("cash", 0)) == 1000
	)

	# Start SERVING and test cooking rice in rice_cooker_01 independently of starter rice_cooker
	_type_word(ui, "buka")
	_check("m4c_serving_started_for_multi_fixture_test", game_root.is_serving())
	await physics_frame

	# Take 1 beras from fridge_01 at (3, 2) via UI click (verifying ingredient shop opens too)
	var f_node := world.registry.get_object(&"fridge_01") as Node2D
	var f_canvas_pos: Vector2 = world.get_canvas_transform() * f_node.global_position
	_send_left_click(ui, f_canvas_pos)
	_check("m4c_clicking_fridge_01_opens_ingredient_shop", ui.is_ingredient_shop_open())
	ui.close_ingredient_shop()
	_type_word(ui, "beras")
	_check("m4c_took_beras_from_fridge_01", not kitchen.get_held_item_view().is_empty())

	# Wash beras at washer (6, 2)
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")

	# Cook washed beras in rice_cooker_01 at (8, 2)
	kitchen.on_interactable_clicked(&"rice_cooker_01")
	_type_word(ui, "masak")
	_check(
		"m4c_rice_cooker_01_has_cooked_output",
		not kitchen.get_cooker_output_view(&"rice_cooker_01").is_empty()
	)
	_check(
		"m4c_starter_rice_cooker_remains_empty",
		kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
	)

	# Scoop cooked rice from rice_cooker_01 with empty hand
	kitchen.on_interactable_clicked(&"rice_cooker_01")
	_type_word(ui, "nasi")
	var scooped_rice: Dictionary = kitchen.get_held_item_view()
	_check(
		"m4c_scooped_rice_from_rice_cooker_01",
		not scooped_rice.is_empty()
		and (scooped_rice.get("parts", []) as Array).size() == 1
	)

	# End Day 1 service and inspect RESULTS settlement
	_force_empty_service(service)
	game_root._process(0.2)
	_check("m4c_reached_results_phase", game_root.get_phase() == SharedTypes.Phase.RESULTS)

	var settlement: Dictionary = run.get_day_settlement_view(1)
	_check(
		"m4c_settlement_fixture_purchase_total_95000",
		int(settlement.get("fixture_purchase_total", 0)) == 95000
	)
	_check(
		"m4c_settlement_electricity_charge_8000",
		int(settlement.get("electricity_charge", 0)) == 8000
	)

	# Advance to Day 2 PLANNING and verify fixture & fridge stock persistence
	var advanced: bool = game_root.request_continue_from_results()
	_check("m4c_advanced_to_day_2", advanced and game_root.get_day_index() == 2)
	_check(
		"m4c_fridge_01_persists_on_day_2",
		world.registry.get_object(&"fridge_01") != null
		and kitchen.has_storage_unit(&"fridge_01")
	)
	_check(
		"m4c_rice_cooker_01_persists_on_day_2",
		world.registry.get_object(&"rice_cooker_01") != null
		and kitchen.get_fixture_kind(&"rice_cooker_01") == SharedTypes.FixtureKind.RICE_COOKER
	)
	_check(
		"m4c_dining_table_03_persists_on_day_2",
		world.registry.get_object(&"dining_table_03") != null
		and service.has_table(&"dining_table_03")
	)
	var day2_fridge_view: Dictionary = kitchen.get_storage_unit_view(&"fridge_01")
	var day2_slots: Array = day2_fridge_view.get("slots", [])
	var remaining_beras := 0
	for raw_slot: Variant in day2_slots:
		if raw_slot is Dictionary:
			var s := raw_slot as Dictionary
			if StringName(s.get("ingredient_id", &"")) == &"beras":
				remaining_beras += int(s.get("quantity", 0))
	_check(
		"m4c_fridge_01_preserves_remaining_raw_stock_on_day_2",
		remaining_beras == 1
	)

	game_root.free()
	await process_frame


func _test_fixture_shop_responsive_layout() -> void:
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	await process_frame

	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var run := game_root.get_run_controller() as RunController
	ui.open_fixture_shop(&"slot_utility_01")
	await process_frame
	await process_frame

	var vp_rect: Rect2 = ui.get_viewport().get_visible_rect()
	var overlay_rect: Rect2 = ui.fixture_shop_overlay.get_global_rect()
	var popup_rect: Rect2 = ui.fixture_shop_popup.get_global_rect()
	var hud_rect: Rect2 = ui.left_hud_region.get_global_rect()
	var slots_rect: Rect2 = ui.fixture_slots_row.get_global_rect()
	var list_rect: Rect2 = ui.fixture_list.get_global_rect()
	var cancel_rect: Rect2 = ui.fixture_cancel_button.get_global_rect()
	var confirm_rect: Rect2 = ui.fixture_confirm_button.get_global_rect()

	_check(
		"m4c_layout_640x360_overlay_inside_viewport",
		vp_rect.encloses(overlay_rect)
	)
	_check(
		"m4c_layout_640x360_popup_inside_world_region",
		vp_rect.encloses(popup_rect) and ui.world_visible_rect.encloses(popup_rect)
	)
	_check(
		"m4c_layout_640x360_left_hud_unobstructed",
		ui.left_hud_region.visible
		and vp_rect.encloses(hud_rect)
		and not hud_rect.intersects(popup_rect)
	)
	_check(
		"m4c_layout_640x360_slot_buttons_fit_inside_popup",
		popup_rect.encloses(slots_rect)
	)
	_check(
		"m4c_layout_640x360_equipment_list_fits_horizontally",
		list_rect.position.x >= popup_rect.position.x
		and list_rect.end.x <= popup_rect.end.x
	)
	_check(
		"m4c_layout_640x360_footer_buttons_accessible_inside_popup",
		popup_rect.encloses(cancel_rect) and popup_rect.encloses(confirm_rect)
	)

	var all_rows_fit_x := true
	var all_descriptions_wrap := true
	for u_id: StringName in run.get_utility_ids():
		var row: Dictionary = ui.get_fixture_shop_row(u_id)
		if row.is_empty():
			all_rows_fit_x = false
			continue
		var r_panel := row["panel"] as Control
		var r_btn := row["select_button"] as Control
		var r_downside := row["downside_label"] as Label
		var r_benefit := row["benefit_label"] as Label
		var r_avail := row["availability_label"] as Label
		var panel_g := r_panel.get_global_rect()
		var btn_g := r_btn.get_global_rect()
		var down_g := r_downside.get_global_rect()
		if panel_g.position.x < popup_rect.position.x or panel_g.end.x > popup_rect.end.x:
			all_rows_fit_x = false
		if btn_g.position.x < popup_rect.position.x or btn_g.end.x > popup_rect.end.x:
			all_rows_fit_x = false
		if (
			r_downside.autowrap_mode == TextServer.AUTOWRAP_OFF
			or r_benefit.autowrap_mode == TextServer.AUTOWRAP_OFF
			or r_avail.autowrap_mode == TextServer.AUTOWRAP_OFF
			or down_g.end.x > btn_g.position.x
		):
			all_descriptions_wrap = false

	_check("m4c_layout_640x360_all_7_rows_fit_horizontally", all_rows_fit_x)
	_check("m4c_layout_640x360_long_descriptions_wrap_properly", all_descriptions_wrap)

	var scroll := ui.fixture_list.get_parent() as ScrollContainer
	var vbar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = 120
	await process_frame
	_check(
		"m4c_layout_640x360_vertical_scrolling_works",
		scroll != null
		and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and vbar.max_value > scroll.size.y
		and scroll.scroll_vertical > 0
	)

	# Resize viewport to smaller usable resolution (480 x 270) and verify responsive update
	root.content_scale_size = Vector2i(480, 270)
	root.size = Vector2i(480, 270)
	ui._on_viewport_size_changed()
	await process_frame
	await process_frame

	var small_vp: Rect2 = ui.get_viewport().get_visible_rect()
	var small_popup: Rect2 = ui.fixture_shop_popup.get_global_rect()
	var small_hud: Rect2 = ui.left_hud_region.get_global_rect()
	var small_slots: Rect2 = ui.fixture_slots_row.get_global_rect()
	var small_list: Rect2 = ui.fixture_list.get_global_rect()
	var small_cancel: Rect2 = ui.fixture_cancel_button.get_global_rect()
	var small_confirm: Rect2 = ui.fixture_confirm_button.get_global_rect()

	_check(
		"m4c_layout_480x270_popup_inside_viewport_and_world",
		small_vp.size == Vector2(480, 270)
		and small_vp.encloses(small_popup)
		and ui.world_visible_rect.encloses(small_popup)
		and not small_hud.intersects(small_popup)
	)
	_check(
		"m4c_layout_480x270_controls_fit_inside_resized_popup",
		small_popup.encloses(small_slots)
		and small_list.position.x >= small_popup.position.x
		and small_list.end.x <= small_popup.end.x
		and small_popup.encloses(small_cancel)
		and small_popup.encloses(small_confirm)
	)

	# Verify shop interactions still work after viewport resize
	ui.select_fixture_shop_slot(&"slot_utility_01")
	ui.select_fixture_shop_utility(&"box")
	var bought_after_resize: bool = ui.submit_fixture_shop()
	_check(
		"m4c_layout_purchase_works_after_viewport_resize",
		bought_after_resize
		and not ui.is_fixture_shop_open()
		and int(run.get_run_view().get("cash", 0)) == 60000
	)

	# Restore standard 640x360 viewport
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	game_root.free()
	await process_frame

	# Verify all 5 utility slots and 6 table slots (8 total tables) can be purchased and placed
	var g_all := packed.instantiate() as GameRoot
	root.add_child(g_all)
	await process_frame
	await physics_frame

	var r_all := g_all.get_run_controller() as RunController
	var s_all := g_all.get_service_controller() as ServiceController
	var w_all := g_all.get_node("World") as WorldMap
	r_all._cash = 1000000

	var all_util_bought := true
	for u_idx in range(1, 6):
		var s_id := StringName("slot_utility_%02d" % u_idx)
		if not r_all.request_fixture_purchase(&"stove", s_id):
			all_util_bought = false

	var all_tables_bought := true
	for t_idx in range(1, 7):
		var s_id := StringName("slot_table_%02d" % t_idx)
		if not r_all.request_fixture_purchase(&"dining_table", s_id):
			all_tables_bought = false

	_check("m4c_all_5_utility_slots_purchased", all_util_bought)
	_check(
		"m4c_all_6_table_slots_purchased_yielding_8_tables",
		all_tables_bought
		and s_all.get_registered_table_ids().size() == 8
		and w_all.dining_tables.get_child_count() == 8
	)

	g_all.free()
	await process_frame
