extends SceneTree
## Headless M4-B acceptance tests:
## Ingredient Shop UI (`Belanja Bahan`), multi-item atomic basket checkout,
## live pending deliveries, and purchase/delivery transaction hardening.

var _fails: int = 0


class FailingSecondScheduleKitchen:
	extends KitchenController
	var _schedule_calls: int = 0

	func schedule_delivery(
		purchase_id: StringName,
		ingredient_id: StringName,
		quantity: int,
		storage_unit_id: StringName,
		due_at: float
	) -> bool:
		_schedule_calls += 1
		if _schedule_calls >= 2:
			return false
		return super.schedule_delivery(
			purchase_id,
			ingredient_id,
			quantity,
			storage_unit_id,
			due_at
		)


class FailingSecondPlanningBasketKitchen:
	extends KitchenController
	var fail_second_line: bool = true

	func receive_stock_basket(items: Array[Dictionary], storage_unit_id: StringName) -> bool:
		if fail_second_line and items.size() >= 2:
			var mutated := items.duplicate(true)
			mutated[1]["ingredient_id"] = &"invalid_ingredient_for_test"
			return super.receive_stock_basket(mutated, storage_unit_id)
		return super.receive_stock_basket(items, storage_unit_id)


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_ingredient_shop_planning_and_validation()
	await _test_ingredient_shop_serving_live_and_cooking()
	await _test_transaction_hardening_and_atomic_rollback()
	await _test_planning_basket_atomicity_and_failure()
	await _test_purchased_ingredients_processing_and_delivery()
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


func _test_ingredient_shop_planning_and_validation() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# 1. Clicking storage_box in PLANNING moves adjacent, selects target, and opens Belanja Bahan.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var popup_rect := ui.ingredient_shop_popup.get_global_rect()
	var beras_row := ui.get_shop_ingredient_controls(&"beras")
	var sapi_row := ui.get_shop_ingredient_controls(&"sapi")
	var sayur_row := ui.get_shop_ingredient_controls(&"sayur")
	var tempe_row := ui.get_shop_ingredient_controls(&"tempe")
	_check(
		"storage_box click in PLANNING opens centered Belanja Bahan with all 6 ingredients",
		ui.is_ingredient_shop_open()
		and ui.is_modal_blocking()
		and ui.left_hud_region.visible
		and ui.world_visible_rect.encloses(popup_rect)
		and kitchen.get_selected_target_id() == &"storage_box"
		and ui.shop_cash_label.text == "Kas: Rp100000"
		and ui.shop_capacity_label.text == "Sisa kapasitas: 15"
		and not beras_row.is_empty()
		and not sapi_row.is_empty()
		and not sayur_row.is_empty()
		and not tempe_row.is_empty()
		and (beras_row["price_label"] as Label).text == "Rp2000"
		and (sapi_row["price_label"] as Label).text == "Rp10000"
	)

	# 2. Modal blocks world clicks and buka typing while open.
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_check(
		"shop modal blocks world clicks and gameplay typing",
		kitchen.get_player_tile() == tile_before
		and kitchen.get_command_prefix() == ""
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	# 3. Quantity controls (+ and -) update subtotals/total cleanly; ga jadi discards basket.
	(beras_row["plus_button"] as Button).pressed.emit()
	(beras_row["plus_button"] as Button).pressed.emit()
	(beras_row["minus_button"] as Button).pressed.emit()
	_check(
		"quantity +/- updates basket, subtotal, total, and remaining capacity without charging cash",
		ui.get_shop_basket() == { &"beras": 1 }
		and ui.get_shop_subtotal(&"beras") == 2000
		and ui.get_shop_total() == 2000
		and ui.get_shop_remaining_capacity() == 14
		and int(run.get_run_view()["cash"]) == 100000
	)
	ui.shop_cancel_button.pressed.emit()
	_check(
		"ga jadi discards basket without mutating cash or stock and closes modal",
		not ui.is_ingredient_shop_open()
		and not ui.is_modal_blocking()
		and int(run.get_run_view()["cash"]) == 100000
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 0
	)

	# 4. Capacity (including 3-slot distinct-ingredient cap) and insufficient cash rejections.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	sayur_row = ui.get_shop_ingredient_controls(&"sayur")
	_check("select 1 beras", ui.adjust_shop_quantity(&"beras", 1))
	_check("select 1 telur", ui.adjust_shop_quantity(&"telur", 1))
	_check("select 1 ayam", ui.adjust_shop_quantity(&"ayam", 1))
	_check(
		"4th distinct ingredient rejected because box has 3 slots",
		not ui.adjust_shop_quantity(&"sayur", 1)
		and ui.shop_error_label.visible
		and (sayur_row["plus_button"] as Button).disabled
	)
	ui.adjust_shop_quantity(&"ayam", -1)
	ui.adjust_shop_quantity(&"telur", -1)
	_check(
		"excessive quantity (16 total) rejected atomically on checkout",
		not ui.submit_ingredient_shop({ &"beras": 16 })
		and ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 100000
	)
	_check(
		"insufficient cash purchase (11 sapi = Rp110000 > Rp100000) rejected atomically",
		not ui.submit_ingredient_shop({ &"sapi": 11 })
		and ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 100000
	)
	ui.adjust_shop_quantity(&"beras", -1)
	_check(
		"empty basket checkout rejected without mutating state",
		not ui.submit_ingredient_shop()
		and ui.is_ingredient_shop_open()
	)

	# 5. Multi-item Planning purchase (2 beras + 2 telur = 10000) commits immediately + updates HUD.
	ui.adjust_shop_quantity(&"beras", 1)
	ui.adjust_shop_quantity(&"beras", 1)
	var telur_row := ui.get_shop_ingredient_controls(&"telur")
	(telur_row["plus_button"] as Button).pressed.emit()
	(telur_row["plus_button"] as Button).pressed.emit()
	ui.shop_checkout_button.pressed.emit()
	var second_checkout := ui.submit_ingredient_shop({ &"ayam": 1 })
	var slots: Array = kitchen.get_storage_unit_view(&"storage_box").get("slots", [])
	_check(
		"Planning checkout fills storage immediately, updates HUD cash, and blocks duplicate submit",
		not ui.is_ingredient_shop_open()
		and not second_checkout
		and int(run.get_run_view()["cash"]) == 90000
		and ui.cash_label.text == "Kas: Rp90000"
		and slots[0]["ingredient_id"] == &"beras"
		and int(slots[0]["quantity"]) == 2
		and slots[1]["ingredient_id"] == &"telur"
		and int(slots[1]["quantity"]) == 2
	)

	game_root.free()
	await process_frame


func _test_ingredient_shop_serving_live_and_cooking() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Buy Day 1 nasi_telor ingredients purely via UI shop in PLANNING (beras x1, telur x1).
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	ui.adjust_shop_quantity(&"beras", 1)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()

	# Start SERVING via typed `buka` (player stays at (3,1), click floor to clear target first).
	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_check("entered SERVING via buka after UI shopping", game_root.is_serving())

	# Open shop in SERVING by clicking storage_box, confirm service clock keeps ticking.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var elapsed_before := game_root.get_service_elapsed()
	game_root._process(10.0)
	ui._process(0.016)
	_check(
		"shop opens in SERVING without pausing service_elapsed",
		ui.is_ingredient_shop_open()
		and is_equal_approx(game_root.get_service_elapsed(), elapsed_before + 10.0)
		and ui.shop_delivery_hint_label.text.contains("100 dtk")
	)

	# Buy 1 ayam in SERVING -> schedules 100s pending delivery.
	var expected_due := game_root.get_service_elapsed() + 100.0
	ui.adjust_shop_quantity(&"ayam", 1)
	ui.shop_checkout_button.pressed.emit()
	var pending := kitchen.get_pending_delivery_views()
	_check(
		"SERVING checkout debits cash and schedules 100s delivery",
		not ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 89000
		and pending.size() == 1
		and is_equal_approx(float(pending[0]["due_at"]), expected_due)
	)

	# Re-open shop at +50s -> shows pending countdown; advance another +50s -> arrives live.
	game_root._process(50.0)
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	var rem_secs := ceili(float(pending[0]["due_at"]) - game_root.get_service_elapsed())
	_check(
		"re-opened shop displays live pending delivery countdown",
		ui.shop_pending_label.text.contains("Ayam x1")
		and ui.shop_pending_label.text.contains("%d dtk" % rem_secs)
	)
	game_root._process(50.0)
	ui._process(0.016)
	var ayam_row := ui.get_shop_ingredient_controls(&"ayam")
	_check(
		"shop refreshes live when 100s delivery arrives while open",
		kitchen.get_pending_delivery_views().is_empty()
		and ui.shop_pending_label.text == "Kiriman tertunda: tidak ada"
		and (ayam_row["stock_label"] as Label).text == "Stok: 1"
	)

	# Cancel closes shop keeping player at storage_box so kitchen cooking works end-to-end.
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "beras")
	_send_left_click(ui, Vector2(160, 52))
	_type_word(ui, "cuci")
	_send_left_click(ui, Vector2(224, 52))
	_type_word(ui, "masak")
	_send_left_click(ui, Vector2(288, 52))
	_send_left_click(ui, Vector2(251, 116))
	_send_left_click(ui, Vector2(224, 52))
	_type_word(ui, "nasi")
	_send_left_click(ui, Vector2(251, 116))
	_send_left_click(ui, Vector2(256, 52))
	ui.shop_cancel_button.pressed.emit()
	_type_word(ui, "telur")
	_send_left_click(ui, Vector2(192, 52))
	_type_word(ui, "goreng")
	_send_left_click(ui, Vector2(251, 116))
	_check(
		"full M1 nasi_telor dish assembled strictly from Belanja Bahan stock",
		kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &"nasi_telor"
	)

	game_root.free()
	await process_frame


func _test_transaction_hardening_and_atomic_rollback() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	# Register secondary storage container `fridge` to verify container-pinning hardening.
	_check(
		"register test fridge",
		kitchen.register_storage_unit(&"fridge", SharedTypes.FixtureKind.FRIDGE)
	)

	# 1. PLANNING wrong-container receive_stock fails without stranding reservation.
	_check(
		"reserve_incoming_capacity on storage_box",
		kitchen.reserve_incoming_capacity(&"pur_plan_pin", &"beras", 2, &"storage_box")
	)
	var box_res_plan: Dictionary = kitchen.get_storage_unit_view(&"storage_box")["reservations"]
	_check(
		"receive_stock on wrong unit fridge rejects",
		not kitchen.receive_stock(&"pur_plan_pin", &"beras", 2, &"fridge")
		and int(kitchen.get_storage_unit_view(&"fridge")["slots"][0]["quantity"]) == 0
		and box_res_plan.has(&"pur_plan_pin")
	)
	_check(
		"receive_stock on reserved storage_box succeeds",
		kitchen.receive_stock(&"pur_plan_pin", &"beras", 2, &"storage_box")
	)

	# 2. SERVING shipment: reject early receipt, reject wrong container, block delivered refund.
	game_root.start_service_requested()
	_check(
		"SERVING purchase 2 beras (4000) schedules pur_1_0001 at due=100",
		run.request_ingredient_purchase(&"beras", 2, &"storage_box")
		and int(run.get_run_view()["cash"]) == 96000
	)
	game_root._process(50.0)
	var early_res: Dictionary = kitchen.get_storage_unit_view(&"storage_box")["reservations"]
	_check(
		"early receive_stock at t=50 rejected and preserves reservation",
		not kitchen.receive_stock(&"pur_1_0001", &"beras", 2, &"storage_box")
		and not kitchen.is_purchase_delivered(&"pur_1_0001")
		and early_res.has(&"pur_1_0001")
	)
	var early_ref: Array[StringName] = [&"pur_1_0001"]
	run.refund_canceled_deliveries_once(early_ref)
	_check(
		"early refund attempt while shipment still PENDING rejected",
		int(run.get_run_view()["cash"]) == 96000
	)
	# Advance to due time 100s -> pur_1_0001 delivers cleanly and cannot be refunded after delivery.
	game_root._process(50.0)
	run.refund_canceled_deliveries_once(early_ref)
	_check(
		"delivered pur_1_0001 cannot be refunded directly via refund_canceled_deliveries_once",
		int(run.get_run_view()["cash"]) == 96000
		and kitchen.is_purchase_delivered(&"pur_1_0001")
		and run.get_purchase_record(&"pur_1_0001").get("status", &"") == &"DELIVERED"
		and not kitchen.receive_stock(&"pur_1_0001", &"beras", 2, &"storage_box")
	)

	# Multiple concurrent pending shipments + exact wrong-container at/after due_at check:
	_check(
		"purchase 2 eggs and 3 ayam while t=100 -> due=200",
		run.request_ingredient_basket_purchase({ &"telur": 2, &"ayam": 3 }, &"storage_box")
		and int(run.get_run_view()["cash"]) == 72000
		and kitchen.get_pending_delivery_views().size() == 2
	)
	# Manually check wrong container at/after due_at using beras (fits alongside existing 2 beras):
	_check(
		"schedule pur_manual_due on storage_box at due=100",
		kitchen.schedule_delivery(&"pur_manual_due", &"beras", 1, &"storage_box", 100.0)
	)
	var manual_res: Dictionary = kitchen.get_storage_unit_view(&"storage_box")["reservations"]
	_check(
		"wrong container at t >= due_at still rejects and preserves storage_box reservation",
		not kitchen.receive_stock(&"pur_manual_due", &"beras", 1, &"fridge")
		and kitchen.is_purchase_pending(&"pur_manual_due")
		and manual_res.has(&"pur_manual_due")
	)
	_check(
		"right container at t >= due_at delivers cleanly once",
		kitchen.receive_stock(&"pur_manual_due", &"beras", 1, &"storage_box")
		and kitchen.is_purchase_delivered(&"pur_manual_due")
		and not kitchen.receive_stock(&"pur_manual_due", &"beras", 1, &"storage_box")
	)

	# Drain service before t=200 -> remaining 2 pending deliveries (24000) refunded exact once.
	_force_empty_service(service)
	game_root.request_close_if_drained()
	# cash: 72000 + 24000 refund - 2000 rice_cooker electricity = 94000
	var ids_after: Array[StringName] = [&"pur_1_0002", &"pur_1_0003"]
	run.refund_canceled_deliveries_once(ids_after)
	_check(
		"canceled pending basket refunded once (94000) and delivered pur_1_0001 not refunded",
		int(run.get_run_view()["cash"]) == 94000
	)

	game_root.free()
	await process_frame

	# 3. Multi-item basket commit failure rolls back scheduled deliveries, reservations, and cash.
	var root_abort := GameRoot.new()
	var world_packed := load("res://scenes/world/restaurant_world.tscn") as PackedScene
	var world_inst := world_packed.instantiate() as WorldMap
	world_inst.name = "World"
	var fail_kitchen := FailingSecondScheduleKitchen.new()
	var service_abort := ServiceController.new()
	var run_abort := RunController.new()
	root_abort.add_child(world_inst)
	root_abort.bind_controllers(fail_kitchen, service_abort, run_abort)
	root.add_child(root_abort)
	await process_frame

	root_abort.start_service_requested()
	var aborted := run_abort.request_ingredient_basket_purchase(
		{ &"beras": 2, &"telur": 2 },
		&"storage_box"
	)
	var abort_res: Dictionary = fail_kitchen.get_storage_unit_view(&"storage_box")["reservations"]
	_check(
		"aborted multi-item SERVING basket leaves zero deliveries/reservations and 100000 cash",
		not aborted
		and fail_kitchen.get_pending_delivery_views().is_empty()
		and abort_res.is_empty()
		and int(run_abort.get_run_view()["cash"]) == 100000
	)

	run_abort.free()
	service_abort.free()
	fail_kitchen.free()
	root_abort.free()
	await process_frame


func _test_planning_basket_atomicity_and_failure() -> void:
	# 1. PLANNING 2nd-line basket failure rolls back cleanly without partial stock, IDs, or signals.
	var root_fail := GameRoot.new()
	var world_packed := load("res://scenes/world/restaurant_world.tscn") as PackedScene
	var world_inst := world_packed.instantiate() as WorldMap
	world_inst.name = "World"
	var kitchen_fail := FailingSecondPlanningBasketKitchen.new()
	var service_fail := ServiceController.new()
	var run_fail := RunController.new()
	root_fail.add_child(world_inst)
	root_fail.bind_controllers(kitchen_fail, service_fail, run_fail)
	root.add_child(root_fail)
	await process_frame

	var pre_slots: Array = kitchen_fail.get_storage_unit_view(&"storage_box")["slots"].duplicate(true)
	var kitchen_signals := { "count": 0 }
	var run_signals := { "count": 0 }
	kitchen_fail.kitchen_state_changed.connect(func() -> void: kitchen_signals["count"] += 1)
	run_fail.run_state_changed.connect(func() -> void: run_signals["count"] += 1)

	var failed_ok := run_fail.request_ingredient_basket_purchase(
		{ &"beras": 2, &"telur": 2 },
		&"storage_box"
	)
	var box_after_fail := kitchen_fail.get_storage_unit_view(&"storage_box")
	_check(
		"PLANNING 2nd-line basket failure rejects with exact pre-transaction slots and zero leaks",
		not failed_ok
		and box_after_fail["slots"] == pre_slots
		and (box_after_fail["reservations"] as Dictionary).is_empty()
		and not kitchen_fail.is_purchase_delivered(&"pur_1_0001")
		and not kitchen_fail.is_purchase_delivered(&"pur_1_0002")
		and int(run_fail.get_run_view()["cash"]) == 100000
		and run_fail.get_purchase_record(&"pur_1_0001").is_empty()
		and run_fail.get_purchase_record(&"pur_1_0002").is_empty()
		and kitchen_signals["count"] == 0
		and run_signals["count"] == 0
	)

	# Subsequent valid PLANNING basket succeeds after failure and emits kitchen_state_changed once
	# with complete committed inventory visible to observers.
	kitchen_fail.fail_second_line = false
	var observed_at_signal := { "slots_count": 0, "has_all_3": false }
	kitchen_fail.kitchen_state_changed.connect(
		func() -> void:
			var view_now := kitchen_fail.get_storage_unit_view(&"storage_box")["slots"] as Array
			observed_at_signal["slots_count"] += 1
			observed_at_signal["has_all_3"] = (
				view_now[0].get("ingredient_id", &"") == &"ayam"
				and int(view_now[0].get("quantity", 0)) == 1
				and view_now[1].get("ingredient_id", &"") == &"beras"
				and int(view_now[1].get("quantity", 0)) == 2
				and view_now[2].get("ingredient_id", &"") == &"telur"
				and int(view_now[2].get("quantity", 0)) == 3
			)
	)
	var success_ok := run_fail.request_ingredient_basket_purchase(
		{ &"ayam": 1, &"beras": 2, &"telur": 3 },
		&"storage_box"
	)
	var box_after_ok := kitchen_fail.get_storage_unit_view(&"storage_box")
	var rec_ayam := run_fail.get_purchase_record(&"pur_1_0003")
	var rec_beras := run_fail.get_purchase_record(&"pur_1_0004")
	var rec_telur := run_fail.get_purchase_record(&"pur_1_0005")
	_check(
		"PLANNING multi-item basket commits atomically once with complete signal state",
		success_ok
		and observed_at_signal["slots_count"] == 1
		and observed_at_signal["has_all_3"]
		and kitchen_signals["count"] == 1
		and run_signals["count"] == 1
		and (box_after_ok["reservations"] as Dictionary).is_empty()
		and kitchen_fail.is_purchase_delivered(&"pur_1_0003")
		and kitchen_fail.is_purchase_delivered(&"pur_1_0004")
		and kitchen_fail.is_purchase_delivered(&"pur_1_0005")
		and int(run_fail.get_run_view()["cash"]) == 81000
		and rec_ayam.get("status", &"") == &"DELIVERED"
		and rec_beras.get("status", &"") == &"DELIVERED"
		and rec_telur.get("status", &"") == &"DELIVERED"
		and int(rec_ayam.get("actual_amount_paid", 0)) == 6000
		and int(rec_beras.get("actual_amount_paid", 0)) == 4000
		and int(rec_telur.get("actual_amount_paid", 0)) == 9000
	)

	# 2. Direct unmocked receive_stock_basket with valid reserved line1 + wrong-unit line2 fails.
	_check(
		"reserve direct line 1 on storage_box",
		kitchen_fail.reserve_incoming_capacity(&"pur_dir_1", &"beras", 1, &"storage_box")
	)
	_check(
		"reserve direct line 2 on another unit (register temp fridge)",
		kitchen_fail.register_storage_unit(&"fridge", SharedTypes.FixtureKind.FRIDGE)
		and kitchen_fail.reserve_incoming_capacity(&"pur_dir_2", &"tempe", 1, &"fridge")
	)
	var pre_dir_slots: Array = kitchen_fail.get_storage_unit_view(&"storage_box")["slots"].duplicate(
		true
	)
	var dir_sig_before: int = kitchen_signals["count"]
	var direct_items: Array[Dictionary] = [
		{ "purchase_id": &"pur_dir_1", "ingredient_id": &"beras", "quantity": 1 },
		{ "purchase_id": &"pur_dir_2", "ingredient_id": &"tempe", "quantity": 1 },
	]
	_check(
		"direct receive_stock_basket rejects mixed-unit reservation without mutating line 1",
		not kitchen_fail.receive_stock_basket(direct_items, &"storage_box")
		and kitchen_fail.get_storage_unit_view(&"storage_box")["slots"] == pre_dir_slots
		and (
			kitchen_fail.get_storage_unit_view(&"storage_box")["reservations"] as Dictionary
		).has(&"pur_dir_1")
		and (
			kitchen_fail.get_storage_unit_view(&"fridge")["reservations"] as Dictionary
		).has(&"pur_dir_2")
		and not kitchen_fail.is_purchase_delivered(&"pur_dir_1")
		and not kitchen_fail.is_purchase_delivered(&"pur_dir_2")
		and kitchen_signals["count"] == dir_sig_before
	)

	run_fail.free()
	service_fail.free()
	kitchen_fail.free()
	root_fail.free()
	await process_frame


func _test_purchased_ingredients_processing_and_delivery() -> void:
	# Part 1: Purchased rice, egg, and chicken during PLANNING -> retrieve and process each.
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var ui := game_root.get_node("UI") as GameUI

	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	ui.adjust_shop_quantity(&"beras", 1)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.adjust_shop_quantity(&"ayam", 1)
	ui.shop_checkout_button.pressed.emit()
	var plan_slots: Array = kitchen.get_storage_unit_view(&"storage_box")["slots"]
	_check(
		"PLANNING purchase deposits beras, telur, ayam into storage_box",
		plan_slots[0]["ingredient_id"] == &"ayam"
		and int(plan_slots[0]["quantity"]) == 1
		and plan_slots[1]["ingredient_id"] == &"beras"
		and int(plan_slots[1]["quantity"]) == 1
		and plan_slots[2]["ingredient_id"] == &"telur"
		and int(plan_slots[2]["quantity"]) == 1
	)

	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_check("buka starts SERVING with Planning stock retained", game_root.is_serving())

	# Retrieve purchased rice, close via Escape when shop opens on storage_box click.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	_check("storage_box click in SERVING shows Ambil Bahan button", ui.shop_retrieve_button.visible)
	_send_key(ui, 0, KEY_ESCAPE)
	_check(
		"Escape closes Belanja Bahan keeping storage_box selected and dialogue stocked",
		not ui.is_ingredient_shop_open()
		and kitchen.get_selected_target_id() == &"storage_box"
		and ui.target_status_label.text.contains("Beras 1")
		and ui.target_status_label.text.contains("Telur 1")
		and ui.target_status_label.text.contains("Ayam 1")
	)

	_type_word(ui, "beras")
	_check(
		"purchased beras retrieved in RAW state and decrements storage",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.RAW
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][1]["quantity"]) == 0
	)
	_send_left_click(ui, Vector2(160, 52))
	_type_word(ui, "cuci")
	_check(
		"purchased beras washed via cuci -> WASHED",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
	)
	_send_left_click(ui, Vector2(224, 52))
	_type_word(ui, "masak")
	_check(
		"washed beras cooked via masak -> rice_cooker output COOKED_RICE and hand cleared",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_cooker_output_view(&"rice_cooker")["parts"][0]["state"])
			== SharedTypes.PrepState.COOKED_RICE
	)
	_type_word(ui, "nasi")
	_check(
		"nasi retrieves COOKED_RICE from rice_cooker and clears cooker output",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and int(kitchen.get_held_item_view()["parts"][0]["state"])
			== SharedTypes.PrepState.COOKED_RICE
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
	)
	_send_left_click(ui, Vector2(384, 52))

	# Retrieve purchased egg -> goreng at stove -> COOKED; repeated goreng rejected cleanly.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	ui.shop_retrieve_button.pressed.emit()
	_type_word(ui, "telur")
	_send_left_click(ui, Vector2(192, 52))
	_type_word(ui, "goreng")
	_check(
		"purchased telur fried via goreng -> COOKED and decrements storage",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][2]["quantity"]) == 0
	)
	_type_word(ui, "goreng")
	_check(
		"repeated goreng on already COOKED telur rejected without consuming item",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and ui.get_feedback_code() == &"invalid_action"
	)
	_send_left_click(ui, Vector2(384, 52))

	# Retrieve purchased chicken -> goreng at stove -> COOKED.
	_send_left_click(ui, Vector2(256, 52))
	await process_frame
	ui.shop_retrieve_button.pressed.emit()
	_type_word(ui, "ayam")
	_send_left_click(ui, Vector2(192, 52))
	_type_word(ui, "goreng")
	_check(
		"purchased ayam fried via goreng -> COOKED and storage now empty",
		kitchen.get_held_item_view()["parts"][0]["ingredient_id"] == &"ayam"
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 0
	)

	game_root.free()
	await process_frame

	# Part 2: Purchase after `buka` during SERVING -> pre-delivery feedback & post-100s processing.
	var g2 := packed.instantiate() as GameRoot
	root.add_child(g2)
	await process_frame
	await physics_frame

	var k2 := g2.get_kitchen_controller() as KitchenController
	var w2 := g2.get_node("World") as WorldMap
	var u2 := g2.get_node("UI") as GameUI

	_type_word(u2, "buka")
	_send_left_click(u2, Vector2(256, 52))
	await process_frame
	u2.adjust_shop_quantity(&"beras", 1)
	u2.adjust_shop_quantity(&"telur", 1)
	u2.adjust_shop_quantity(&"ayam", 1)
	u2.shop_checkout_button.pressed.emit()

	var box_node := w2.registry.get_object(&"storage_box")
	var pending_lbl := box_node.get_node_or_null("DeliveryPendingLabel") as Label
	_check(
		"post-buka SERVING purchase shows live Kiriman status and world countdown badge",
		k2.get_pending_delivery_views().size() == 3
		and u2.target_status_label.text.contains("Stok: Kosong")
		and u2.target_status_label.text.contains("Kiriman:")
		and pending_lbl != null
		and pending_lbl.visible
		and pending_lbl.text.begins_with("Kirim ")
	)

	# Before 100s delivery: cannot retrieve, and empty-hand stove/cooker show clear guidance.
	_type_word(u2, "beras")
	_check(
		"retrieving pending beras before 100s rejects with delivery_pending",
		k2.get_held_item_view().is_empty()
		and u2.get_feedback_code() == &"delivery_pending"
		and u2.context_message_label.text == "Bahan masih dikirim"
	)
	_send_left_click(u2, Vector2(192, 52))
	_type_word(u2, "goreng")
	_check(
		"empty-hand goreng at stove rejects with hand_empty",
		k2.get_held_item_view().is_empty()
		and u2.get_feedback_code() == &"hand_empty"
		and u2.context_message_label.text == "Ambil bahan dulu"
	)
	_send_left_click(u2, Vector2(224, 52))
	_type_word(u2, "masak")
	_check(
		"empty-hand masak at rice_cooker rejects with hand_empty",
		k2.get_held_item_view().is_empty()
		and u2.get_feedback_code() == &"hand_empty"
	)
	_type_word(u2, "nasi")
	_check(
		"empty rice_cooker nasi emits cooker_empty",
		k2.get_held_item_view().is_empty()
		and u2.get_feedback_code() == &"cooker_empty"
	)

	# Advance 100s so SERVING deliveries arrive, then retrieve and cook all 3 items.
	g2._process(100.5)
	u2._process(0.016)
	_check(
		"after 100s delivery arrives into storage_box and hides pending badge",
		k2.get_pending_delivery_views().is_empty()
		and pending_lbl != null
		and not pending_lbl.visible
	)

	_send_left_click(u2, Vector2(256, 52))
	await process_frame
	u2.shop_retrieve_button.pressed.emit()
	_type_word(u2, "beras")
	_send_left_click(u2, Vector2(160, 52))
	_type_word(u2, "cuci")
	_send_left_click(u2, Vector2(224, 52))
	_type_word(u2, "masak")
	_type_word(u2, "nasi")
	var cooked_rice_ok: bool = (
		not k2.get_held_item_view().is_empty()
		and k2.get_held_item_view()["parts"][0]["ingredient_id"] == &"beras"
		and int(k2.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED_RICE
	)
	_send_left_click(u2, Vector2(384, 52))

	_send_left_click(u2, Vector2(256, 52))
	await process_frame
	u2.shop_retrieve_button.pressed.emit()
	_type_word(u2, "telur")
	_send_left_click(u2, Vector2(192, 52))
	_type_word(u2, "goreng")
	var cooked_egg_ok: bool = (
		not k2.get_held_item_view().is_empty()
		and k2.get_held_item_view()["parts"][0]["ingredient_id"] == &"telur"
		and int(k2.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
	)
	_send_left_click(u2, Vector2(384, 52))

	_send_left_click(u2, Vector2(256, 52))
	await process_frame
	u2.shop_retrieve_button.pressed.emit()
	_type_word(u2, "ayam")
	_send_left_click(u2, Vector2(192, 52))
	_type_word(u2, "goreng")
	var cooked_chicken_ok: bool = (
		not k2.get_held_item_view().is_empty()
		and k2.get_held_item_view()["parts"][0]["ingredient_id"] == &"ayam"
		and int(k2.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
	)

	_check(
		"all 3 SERVING-delivered ingredients processed cleanly after 100s",
		cooked_rice_ok and cooked_egg_ok and cooked_chicken_ok
	)

	g2.free()
	await process_frame
