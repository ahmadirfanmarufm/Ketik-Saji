extends SceneTree
## Headless M5-B2B tests:
## Contextual `beli` command on eligible storage units, GameUI shop integration
## (no auto-open on click), purchase/inventory safety, and prefix revalidation.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_planning_beli_flow_and_safety()
	await _test_serving_beli_retrieval_and_revalidation()
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


func _test_planning_beli_flow_and_safety() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	# 1. Clicking storage_box in PLANNING selects it and exposes ONLY `beli` without opening shop.
	_send_left_click(ui, Vector2(256, 52))
	_check(
		"PLANNING click on storage_box selects it without auto-opening shop",
		not ui.is_ingredient_shop_open()
		and not ui.is_modal_blocking()
		and kitchen.get_selected_target_id() == &"storage_box"
		and kitchen.get_allowed_commands_for_selected_target() == ["beli"]
		and ui.interaction_dialogue.visible
		and ui.target_title_label.text == "Kotak Bahan"
		and ui.allowed_commands_label.text == "beli"
		and ui.prefix_prompt_label.text == "Ketik: beli"
	)

	# Partial typing in PLANNING shows live prefix preview for `beli`.
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "e".unicode_at(0), KEY_E)
	_check(
		"partial prefix be in PLANNING previews [be]li cleanly",
		kitchen.get_command_prefix() == "be"
		and ui.allowed_commands_label.text == "[be]li"
		and ui.prefix_prompt_label.text == "Ketik: [be]"
		and ui.remaining_prompt_label.visible
		and ui.remaining_prompt_label.text == "Ketik berikutnya: li"
	)
	_send_key(ui, 0, KEY_ESCAPE)

	# 2. Unrelated targets do NOT expose `beli` in PLANNING or SERVING.
	for target_id: StringName in [
		&"stove",
		&"rice_cooker",
		&"washer",
		&"plate_rack",
		&"work_table_chop",
		&"online_station",
		&"dining_table_01",
	]:
		kitchen.on_interactable_clicked(target_id)
		_check(
			"PLANNING target %s hides beli" % target_id,
			kitchen.get_allowed_commands_for_selected_target().is_empty()
		)

	# Non-purchasable / unowned storage unit in KitchenController hides `beli` and rejects shop open.
	var unowned_box := &"unowned_box"
	kitchen.register_storage_unit(unowned_box, SharedTypes.FixtureKind.BOX)
	kitchen._selected_target_id = unowned_box
	_check(
		"non-owned storage unit hides beli",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
		and not ui.open_ingredient_shop(unowned_box)
	)
	kitchen._perform_typed_command(&"beli")
	_check(
		"direct beli on unowned storage rejects invalid_action without opening shop",
		ui.get_feedback_code() == &"invalid_action"
		and not ui.is_ingredient_shop_open()
	)
	kitchen.unregister_fixture_instance(unowned_box)

	# 3. Typing `beli` on storage_box in PLANNING opens Belanja Bahan and hides dialogue.
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame
	_check(
		"typing beli on storage_box opens existing Belanja Bahan modal",
		ui.is_ingredient_shop_open()
		and ui.is_modal_blocking()
		and not ui.interaction_dialogue.visible
		and ui.shop_target_label.text == "Kotak Bahan"
	)

	# Closing via ga jadi / Escape without purchasing leaves cash and inventory unchanged.
	ui.adjust_shop_quantity(&"beras", 2)
	ui.shop_cancel_button.pressed.emit()
	_check(
		"ga jadi closes shop cleanly without mutating cash/stock and syncs dialogue",
		not ui.is_ingredient_shop_open()
		and not ui.is_modal_blocking()
		and int(run.get_run_view()["cash"]) == 100000
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 0
		and kitchen.get_selected_target_id() == &"storage_box"
		and ui.interaction_dialogue.visible
	)

	# Re-open via `beli`, test safety rejections, then commit valid PLANNING purchase once.
	_type_word(ui, "beli")
	await process_frame
	var cash_before := int(run.get_run_view()["cash"])
	var box_before := kitchen.get_storage_unit_view(&"storage_box")
	_check(
		"insufficient cash purchase (11 sapi) rejected without debit or stock mutation",
		not ui.submit_ingredient_shop({&"sapi": 11})
		and ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == cash_before
		and kitchen.get_storage_unit_view(&"storage_box") == box_before
	)
	_check(
		"over-capacity purchase (16 beras) rejected without debit or stock mutation",
		not ui.submit_ingredient_shop({&"beras": 16})
		and ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == cash_before
		and kitchen.get_storage_unit_view(&"storage_box") == box_before
	)
	_check(
		"invalid non-storage target rejected by RunController purchase validation",
		not run.request_ingredient_purchase(&"beras", 1, &"stove")
		and not run.request_ingredient_purchase(&"beras", 1, &"fake_storage")
	)

	# Commit valid purchase: 2 beras (4000) + 1 telur (3000) = 7000.
	ui.adjust_shop_quantity(&"beras", 2)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()
	_check(
		"valid Belanja Bahan checkout deducts cash once, fills storage_box, and closes shop",
		not ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 93000
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 2
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][1]["quantity"]) == 1
		and ui.interaction_dialogue.visible
		and ui.target_status_label.text.contains("Beras 2")
		and ui.target_status_label.text.contains("Telur 1")
	)

	# 4. Newly purchased fridge_01 supports click -> `beli` -> isolated fridge purchase.
	_check("buy fridge_01 in slot_utility_01", run.request_fixture_purchase(&"fridge", &"slot_utility_01"))
	var fridge_node := world.registry.get_object(&"fridge_01") as Node2D
	var fridge_canvas_pos: Vector2 = world.get_canvas_transform() * fridge_node.global_position
	_send_left_click(ui, fridge_canvas_pos)
	_check(
		"clicking fridge_01 in PLANNING selects it with beli without auto-opening shop",
		not ui.is_ingredient_shop_open()
		and kitchen.get_selected_target_id() == &"fridge_01"
		and kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)
	_type_word(ui, "beli")
	await process_frame
	_check(
		"typing beli on fridge_01 opens shop scoped strictly to fridge_01 (capacity 6)",
		ui.is_ingredient_shop_open()
		and ui.get_shop_remaining_capacity() == 6
		and ui.shop_target_label.text == "Kulkas"
	)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()
	_check(
		"fridge_01 purchase updates fridge_01 without spilling into storage_box",
		int(kitchen.get_storage_unit_view(&"fridge_01")["slots"][0]["quantity"]) == 1
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 2
	)

	game_root.free()
	await process_frame


func _test_serving_beli_retrieval_and_revalidation() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var recorded_feedbacks: Array[StringName] = []
	kitchen.action_feedback.connect(func(code: StringName) -> void: recorded_feedbacks.append(code))

	# Test fixture removal prefix revalidation in PLANNING first on extra box_01.
	_check("buy box_01 in slot_utility_01", run.request_fixture_purchase(&"box", &"slot_utility_01"))
	kitchen.on_interactable_clicked(&"box_01")
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "e".unicode_at(0), KEY_E)
	_check("partial prefix be active on box_01 in PLANNING", kitchen.get_command_prefix() == "be")
	recorded_feedbacks.clear()
	run._fixture_instances.erase(&"box_01")
	kitchen.unregister_fixture_instance(&"box_01")
	run.run_state_changed.emit()
	_check(
		"removing selected storage fixture silently clears active be prefix and blocks shop open",
		kitchen.get_command_prefix() == ""
		and kitchen.get_selected_target_id() == &""
		and recorded_feedbacks.is_empty()
		and not ui.is_shaking()
		and not ui.open_ingredient_shop(&"box_01")
	)

	# Stock storage_box before start service.
	_check(
		"stock beras x2 and telur x2 in storage_box",
		run.request_ingredient_purchase(&"beras", 2, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	)
	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_check("started Day 1 SERVING", game_root.is_serving())

	# 1. Click storage_box in SERVING: does not auto-open shop, exposes beli + stocked items.
	_send_left_click(ui, Vector2(256, 52))
	_check(
		"SERVING click on storage_box selects without auto-opening shop and shows beli + stock",
		not ui.is_ingredient_shop_open()
		and kitchen.get_allowed_commands_for_selected_target() == ["beli", "beras", "telur"]
		and ui.allowed_commands_label.text == "beli, beras, telur"
	)

	# Verify `be` disambiguates `[be]li, [be]ras` -> `Ketik berikutnya: li / ras`.
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "e".unicode_at(0), KEY_E)
	_check(
		"shared be prefix disambiguates beli and beras cleanly",
		ui.allowed_commands_label.text == "[be]li, [be]ras, telur"
		and ui.remaining_prompt_label.text == "Ketik berikutnya: li / ras"
	)
	_type_word(ui, "ras")
	_check(
		"completing beras retrieves RAW beras and still hides ingredient commands on storage_box",
		not kitchen.get_held_item_view().is_empty()
		and kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)

	# Cook rice so we can verify empty/partial plate guards preserve RAW hiding alongside beli.
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")

	# Holding empty plate at storage_box: only `beli` visible, `telur` rejected, stock/plate safe.
	kitchen.on_interactable_clicked(&"plate_rack")
	var empty_plate := kitchen.get_held_item_view()
	var box_snapshot := kitchen.get_storage_unit_view(&"storage_box")
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"holding empty plate hides RAW ingredient commands while keeping beli available",
		kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)
	_type_word(ui, "telur")
	_check(
		"typing hidden telur while holding empty plate rejects invalid_key",
		ui.get_feedback_code() == &"invalid_key"
		and kitchen.get_storage_unit_view(&"storage_box") == box_snapshot
		and kitchen.get_held_item_view() == empty_plate
	)

	# Holding partial plate [COOKED_RICE] at storage_box: only `beli` visible, `telur` rejected.
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	var partial_plate := kitchen.get_held_item_view()
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"holding partial plate hides RAW ingredient commands while keeping beli available",
		kitchen.get_allowed_commands_for_selected_target() == ["beli"]
	)
	_type_word(ui, "telur")
	kitchen._perform_typed_command(&"telur")
	_check(
		"partial plate guard rejects backend telur with hand_full without mutating plate or stock",
		ui.get_feedback_code() == &"hand_full"
		and kitchen.get_storage_unit_view(&"storage_box") == box_snapshot
		and kitchen.get_held_item_view() == partial_plate
	)

	# 2. Typing `beli` in SERVING opens shop and schedules 100s delivery safely.
	_type_word(ui, "beli")
	await process_frame
	_check(
		"typing beli in SERVING opens shop while holding plate",
		ui.is_ingredient_shop_open()
		and ui.shop_retrieve_button.visible
		and kitchen.get_held_item_view() == partial_plate
	)
	var cash_before_serv_buy := int(run.get_run_view()["cash"])
	var telur_price := run.economy_config.get_ingredient_price(&"telur")
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()
	_check(
		"SERVING checkout via beli schedules 100s delivery and syncs dialogue",
		not ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == cash_before_serv_buy - telur_price
		and kitchen.get_pending_delivery_views().size() == 1
		and ui.interaction_dialogue.visible
	)

	# 3. Phase transition to CLOSING/RESULTS silently clears stale `be` prefix and hides `beli`.
	_send_key(ui, "b".unicode_at(0), KEY_B)
	_send_key(ui, "e".unicode_at(0), KEY_E)
	_check("partial prefix be active before service closes", kitchen.get_command_prefix() == "be")
	recorded_feedbacks.clear()
	_force_empty_service(service)
	game_root._process(0.1)
	_check(
		"closing service hides beli and clears stale be prefix silently without opening shop",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and kitchen.get_command_prefix() == ""
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and recorded_feedbacks.is_empty()
		and not ui.is_shaking()
		and not ui.is_ingredient_shop_open()
	)
	_send_key(ui, "l".unicode_at(0), KEY_L)
	_send_key(ui, "i".unicode_at(0), KEY_I)
	_check(
		"typing li in RESULTS cannot complete old beli prefix or open shop",
		not ui.is_ingredient_shop_open()
		and kitchen.get_command_prefix() == ""
	)

	# Signal deduplication check across repeated bind_context.
	ui.bind_context(game_root, game_root.get_node("World"), kitchen, service, run)
	ui.bind_context(game_root, game_root.get_node("World"), kitchen, service, run)
	var shop_req_conns := kitchen.ingredient_shop_requested.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == ui
	).size()
	var run_conns := run.run_state_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	_check(
		"repeated bind keeps ingredient_shop_requested and run_state_changed deduplicated",
		shop_req_conns == 1 and run_conns == 1
	)

	game_root.free()
	await process_frame
