extends SceneTree
## Headless tests for Milestone 0 Controller Skeletons and GameRoot Integration:
## KitchenController click/teleport/storage/plates, ServiceController 4-way
## `is_drained()`, RunController starter fixture binding and once-only ledger,
## and full GameRoot lifecycle wiring.

class FailingReceiveKitchen extends KitchenController:
	func receive_stock(
		_purchase_id: StringName,
		_ingredient_id: StringName,
		_quantity: int,
		_storage_unit_id: StringName
	) -> bool:
		return false


const EXPECTED_SETTLEMENT_KEYS: Array[String] = [
	"day_index",
	"begin_cash",
	"ingredient_purchase_total",
	"fixture_purchase_total",
	"fixture_sale_total",
	"order_revenue_dinein",
	"order_revenue_online",
	"refund_total",
	"electricity_charge",
	"end_cash",
	"completed_dinein_count",
	"completed_online_count",
	"failed_dinein_count",
	"failed_online_count",
	"penalty_debt_before",
	"penalty_debt_after",
	"forecast_next_day",
	"day7_outcome",
]

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_scene_binding_and_starter_kit()
	await _test_kitchen_click_routing_and_movement()
	await _test_service_drained_four_conditions()
	await _test_run_plan_and_once_only_transactions()
	await _test_stock_idempotency_and_reservation_rollback()
	await _test_settlement_keys_and_phase_guards()
	await _test_same_tick_delivery_precedes_close()
	await _test_day_lifecycle_guards_and_day7_extra()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _test_scene_binding_and_starter_kit() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	_check("load game_root.tscn", packed != null)
	if packed == null:
		return

	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var world := game_root.get_node_or_null("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	_check(
		"GameRoot binds World, Kitchen, Service, Run",
		world != null and kitchen != null and service != null and run != null
	)
	if world == null or kitchen == null or service == null or run == null:
		game_root.free()
		return

	_check(
		"no duplicate World nodes on startup",
		world.registry.get_ids().size() == 31
		and world.kitchen_stations.get_child_count() == 6
		and world.dining_tables.get_child_count() == 2
	)

	var run_view := run.get_run_view()
	var fixtures: Dictionary = run_view.get("installed_fixtures", {})
	_check("7 starter fixtures bound in RunController", fixtures.size() == 7)
	var box_rec: Dictionary = run.get_fixture_instance(&"storage_box")
	_check(
		"starter storage_box has starter_grant=true and paid=0",
		bool(box_rec.get("starter_grant", false))
		and int(box_rec.get("actual_amount_paid", -1)) == 0
	)

	var box_view := kitchen.get_storage_unit_view(&"storage_box")
	var slots: Array = box_view.get("slots", [])
	_check("starter storage_box registered with 3 slots of 5", slots.size() == 3)
	_check("starter plate_rack registered 4 plates", kitchen.get_plate_count() == 4)
	_check(
		"starter dining tables registered in ServiceController",
		service.get_registered_table_ids() == [&"dining_table_01", &"dining_table_02"]
	)

	# Calling start_new_run() again must not duplicate scene nodes or plates.
	run.start_new_run()
	_check(
		"repeated start_new_run does not duplicate nodes or plates",
		world.registry.get_ids().size() == 31 and kitchen.get_plate_count() == 4
	)

	game_root.free()
	await process_frame



func _test_kitchen_click_routing_and_movement() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController

	_check("initial player_tile is (6, 3)", kitchen.get_player_tile() == Vector2i(6, 3))
	_check("initial selected_target_id empty", kitchen.get_selected_target_id() == &"")

	# Floor click on valid walkable free cell (5, 3) teleports only.
	_check("floor click (5, 3) succeeds", kitchen.on_floor_clicked(Vector2i(5, 3)))
	_check(
		"player_tile and visual moved to (5, 3)",
		kitchen.get_player_tile() == Vector2i(5, 3)
		and world.global_to_cell(world.player.global_position) == Vector2i(5, 3)
		and kitchen.get_selected_target_id() == &""
	)

	# Floor click on occupied cell (4, 0) or non-walkable lane/counter/wall is rejected safely.
	_check("floor click on occupied (4, 0) rejected", not kitchen.on_floor_clicked(Vector2i(4, 0)))
	_check(
		"floor click on non-walkable lane (9, 0), counter (0, 4), and wall (8, 0) rejected",
		not kitchen.on_floor_clicked(Vector2i(9, 0))
		and not kitchen.on_floor_clicked(Vector2i(0, 4))
		and not kitchen.on_floor_clicked(Vector2i(8, 0))
	)
	_check("failed floor click preserves tile (5, 3)", kitchen.get_player_tile() == Vector2i(5, 3))

	# Remote interactable click on DiningTable01 at (2, 7) from (3, 6):
	# UP(2, 6) and RIGHT(3, 7) tie at Manhattan distance 1 -> UP(2, 6) wins and selects table.
	_check("move to (3, 6)", kitchen.on_floor_clicked(Vector2i(3, 6)))
	_check(
		"click dining_table_01 from (3, 6) teleports to (2, 6) and selects",
		kitchen.on_interactable_clicked(&"dining_table_01")
		and kitchen.get_player_tile() == Vector2i(2, 6)
		and kitchen.get_selected_target_id() == &"dining_table_01"
	)

	# Clicking an already-adjacent target or split work_table_chop at (3, 2) from (3, 1):
	_check(
		"floor click clears selection",
		kitchen.on_floor_clicked(Vector2i(3, 1))
		and kitchen.get_selected_target_id() == &""
	)
	_check(
		"click work_table_chop when already adjacent at (3, 1) stays at (3, 1) and selects",
		kitchen.on_interactable_clicked(&"work_table_chop")
		and kitchen.get_player_tile() == Vector2i(3, 1)
		and kitchen.get_selected_target_id() == &"work_table_chop"
	)

	# Clicking work_table_stage on same physical table stays at (3, 1) and switches target.
	_check(
		"click work_table_stage switches target on same fixture",
		kitchen.on_interactable_clicked(&"work_table_stage")
		and kitchen.get_player_tile() == Vector2i(3, 1)
		and kitchen.get_selected_target_id() == &"work_table_stage"
	)

	# Clicking online_station at (6, 4) from (3, 1) teleports to its nearest free neighbor (6, 3).
	_check(
		"click online_station teleports to (6, 3)",
		kitchen.on_interactable_clicked(&"online_station")
		and kitchen.get_player_tile() == Vector2i(6, 3)
		and kitchen.get_selected_target_id() == &"online_station"
	)

	# Clicking unknown target or passive waiting marker fails without mutating tile or selection.
	_check(
		"click unknown target rejected",
		not kitchen.on_interactable_clicked(&"unknown_station")
	)
	_check(
		"click passive waiting anchor rejected",
		not kitchen.on_interactable_clicked(&"dine_in_wait_01")
	)
	_check(
		"failed interactable click preserves state",
		kitchen.get_player_tile() == Vector2i(6, 3)
		and kitchen.get_selected_target_id() == &"online_station"
	)

	game_root.free()
	await process_frame



func _test_service_drained_four_conditions() -> void:
	var service := ServiceController.new()
	root.add_child(service)
	await process_frame

	_check("unstarted ServiceController is not drained", not service.is_drained())

	service.prepare_service_day(1, {
		"day_queue_initial": 2,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": { &"nasi_telor": 20000 },
		"installed_table_ids": [&"dining_table_01"],
	})
	_check("prepared but not begun is not drained", not service.is_drained())

	service.begin_service(0.0)
	_check("day_queue_remaining > 0 blocks is_drained", not service.is_drained())

	service._day_queue_remaining = 0
	service._outside_dine_in_queue.append(&"cust_1")
	_check("outside_dine_in_queue non-empty blocks is_drained", not service.is_drained())

	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 1
	_check("in_shop_dine_in_count > 0 blocks is_drained", not service.is_drained())

	service._in_shop_dine_in_count = 0
	service._online_orders_open.append(&"ord_online_1")
	_check("online_orders_open non-empty blocks is_drained", not service.is_drained())

	service._online_orders_open.clear()
	_check("all 4 categories empty while active is_drained == true", service.is_drained())

	service.free()
	await process_frame


func _test_run_plan_and_once_only_transactions() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	# Empty menu selection is rejected, leaving valid Day 1 selection intact.
	_check("reject empty menu selection", not run.select_daily_menu([]))
	_check("reject locked Day 2 recipe on Day 1", not run.select_daily_menu([&"nasi_ayam"]))

	# Force empty selection internally to verify finalize_plan() blocks start_service_requested().
	run._selected_recipe_ids.clear()
	_check(
		"empty selected menu fails finalize_plan and blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	_check("select valid Day 1 menu nasi_telor", run.select_daily_menu([&"nasi_telor"]))
	_check(
		"planning ingredient purchase into storage_box succeeds",
		run.request_ingredient_purchase(&"beras", 5, &"storage_box")
	)
	var cash_after_buy: int = int(run.get_run_view().get("cash", 0))
	_check("cash debited once for 5 beras (100000 - 10000)", cash_after_buy == 90000)

	# Overflow purchase (>15 total capacity in 3x5 box) rejected without debit.
	_check(
		"overflow purchase into storage_box rejected without debit",
		not run.request_ingredient_purchase(&"beras", 11, &"storage_box")
		and int(run.get_run_view().get("cash", 0)) == 90000
	)

	# Start service: valid RunController plan + ServiceController enters SERVING.
	_check(
		"start_service_requested succeeds with valid plan",
		game_root.start_service_requested()
		and game_root.is_serving()
		and not service.is_drained()
	)

	# Once-only order credit in SERVING:
	_check(
		"credit_order_once DINE_IN adds 20000 once",
		run.credit_order_once(&"ord_1", &"nasi_telor", SharedTypes.OrderKind.DINE_IN)
		and int(run.get_run_view().get("cash", 0)) == 110000
	)
	_check(
		"duplicate credit_order_once rejected",
		not run.credit_order_once(&"ord_1", &"nasi_telor", SharedTypes.OrderKind.DINE_IN)
		and int(run.get_run_view().get("cash", 0)) == 110000
	)

	# In-service ingredient purchase schedules a 100s delivery; if day drains before 100s,
	# it is canceled and refunded once on close, and starter rice_cooker charges Rp2000 power.
	_check(
		"in-service ingredient purchase reserves and debits 6000",
		run.request_ingredient_purchase(&"ayam", 1, &"storage_box")
		and int(run.get_run_view().get("cash", 0)) == 104000
		and kitchen.get_pending_delivery_views().size() == 1
	)

	_force_empty_service(service)
	game_root._process(1.0)
	_check("drained service closes to RESULTS", game_root.get_phase() == SharedTypes.Phase.RESULTS)
	# Refunded +6000 -> 110000, minus starter rice_cooker electricity 2000 -> 108000.
	_check(
		"pending delivery refunded once and starter cooker power charged once",
		int(run.get_run_view().get("cash", 0)) == 108000
		and kitchen.get_pending_delivery_views().is_empty()
	)

	# Repeated refund_canceled_deliveries_once and settle_day_once must not double-refund/charge.
	run.refund_canceled_deliveries_once([&"pur_1_0002"])
	_check(
		"duplicate refund_canceled_deliveries_once does not add cash",
		int(run.get_run_view().get("cash", 0)) == 108000
	)
	var repeat_settlement := run.settle_day_once({
		"day_index": 1,
		"failed_order_ids": [&"ord_fail_late"],
	})
	_check(
		"duplicate settle_day_once does not double-charge electricity or roll debt",
		int(run.get_run_view().get("cash", 0)) == 108000
		and int(run.get_run_view().get("demand_penalty_debt", -1)) == 0
		and int(repeat_settlement.get("end_cash", 0)) == 108000
	)

	# Calling start_new_run() on an active/progressed run must not reset cash or day state.
	_check(
		"advance from Day 1 RESULTS to Day 2 PLANNING",
		game_root.request_continue_from_results()
	)
	run.start_new_run()
	_check(
		"start_new_run on progressed run does not reset day_index or cash",
		game_root.get_day_index() == 2
		and run.get_day_index() == 2
		and int(run.get_run_view().get("cash", 0)) == 108000
	)

	game_root.free()
	await process_frame



func _test_stock_idempotency_and_reservation_rollback() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController

	# 1. Repeated receive_stock with the same purchase_id does not duplicate stock.
	_check(
		"initial reserve_incoming_capacity pur_manual_1 succeeds",
		kitchen.reserve_incoming_capacity(&"pur_manual_1", &"beras", 4, &"storage_box")
	)
	_check(
		"first receive_stock pur_manual_1 succeeds",
		kitchen.receive_stock(&"pur_manual_1", &"beras", 4, &"storage_box")
	)
	_check(
		"repeated receive_stock pur_manual_1 rejected",
		not kitchen.receive_stock(&"pur_manual_1", &"beras", 4, &"storage_box")
	)
	var slots_after: Array = kitchen.get_storage_unit_view(&"storage_box").get("slots", [])
	_check(
		"storage_box slot 0 has quantity 4 (not 8)",
		slots_after.size() == 3 and int(slots_after[0].get("quantity", 0)) == 4
	)

	# 2. Repeated reservation using a delivered purchase_id is rejected.
	_check(
		"reserve_incoming_capacity with delivered pur_manual_1 rejected",
		not kitchen.reserve_incoming_capacity(&"pur_manual_1", &"beras", 1, &"storage_box")
	)

	# 3. Failed scheduled delivery releases its capacity reservation and does not debit cash.
	_check("start service for rollback test", game_root.start_service_requested())
	var saved_delivery_sec := run.economy_config.service_delivery_seconds
	run.economy_config.service_delivery_seconds = -10.0
	_check(
		"service purchase with negative due_at fails cleanly",
		not run.request_ingredient_purchase(&"telur", 3, &"storage_box")
	)
	run.economy_config.service_delivery_seconds = saved_delivery_sec
	var box_res: Dictionary = kitchen.get_storage_unit_view(&"storage_box").get("reservations", {})
	_check(
		"failed scheduled delivery released reservation and kept cash at 100000",
		box_res.is_empty() and int(run.get_run_view().get("cash", 0)) == 100000
	)

	game_root.free()
	await process_frame


	# 4. Failed immediate stock receipt in PLANNING releases reservation and leaves cash untouched.
	var root_fail := GameRoot.new()
	var world_packed := load("res://scenes/world/restaurant_world.tscn") as PackedScene
	var world_inst := world_packed.instantiate() as WorldMap
	world_inst.name = "World"
	var fail_kitchen := FailingReceiveKitchen.new()
	var service_inst := ServiceController.new()
	var run_inst := RunController.new()
	root_fail.add_child(world_inst)
	root_fail.bind_controllers(fail_kitchen, service_inst, run_inst)
	root.add_child(root_fail)
	await process_frame

	_check(
		"planning purchase when receive_stock fails returns false",
		not run_inst.request_ingredient_purchase(&"beras", 5, &"storage_box")
	)
	var fail_res: Dictionary = (
		fail_kitchen.get_storage_unit_view(&"storage_box").get("reservations", {})
	)
	_check(
		"failed receive_stock released reservation and left cash at 100000",
		fail_res.is_empty() and int(run_inst.get_run_view().get("cash", 0)) == 100000
	)

	run_inst.free()
	service_inst.free()
	fail_kitchen.free()
	root_fail.free()
	await process_frame


func _test_settlement_keys_and_phase_guards() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	# Phase guards while in PLANNING:
	_check("select target in PLANNING", kitchen.on_interactable_clicked(&"storage_box"))
	_check(
		"accept_typed_character rejected in PLANNING without mutating prefix",
		not kitchen.accept_typed_character("b") and kitchen.get_command_prefix() == ""
	)
	_check(
		"credit_order_once rejected in PLANNING",
		not run.credit_order_once(&"ord_early", &"nasi_telor", SharedTypes.OrderKind.DINE_IN)
	)
	_check(
		"settle_day_once with mismatched day_index rejected",
		run.settle_day_once({ "day_index": 2 }).is_empty()
	)
	_check(
		"settle_day_once with missing day_index rejected",
		run.settle_day_once({}).is_empty()
	)

	# Buy 5 beras in PLANNING (10000), start service, credit 1 dine-in (20000) + 1 online (14000).
	_check(
		"buy 5 beras in PLANNING",
		run.request_ingredient_purchase(&"beras", 5, &"storage_box")
	)
	_check("enter SERVING", game_root.start_service_requested())

	# Phase guards while in SERVING:
	var plan_before := run.get_service_plan()
	_check(
		"finalize_plan rejected in SERVING without mutating plan",
		not run.finalize_plan() and run.get_service_plan() == plan_before
	)
	_check(
		"credit_order_once rejects invalid order_kind -1",
		not run.credit_order_once(&"ord_bad_kind", &"nasi_telor", -1)
	)
	_check(
		"credit_order_once rejects recipe not in frozen service plan",
		not run.credit_order_once(&"ord_unplanned", &"nasi_ayam", SharedTypes.OrderKind.DINE_IN)
	)
	_check(
		"credit_order_once DINE_IN succeeds in SERVING",
		run.credit_order_once(&"ord_d1", &"nasi_telor", SharedTypes.OrderKind.DINE_IN)
	)
	_check(
		"credit_order_once ONLINE succeeds in SERVING (14000)",
		run.credit_order_once(&"ord_o1", &"nasi_telor", SharedTypes.OrderKind.ONLINE)
	)

	# Drain to RESULTS and verify all 18 DaySettlementView keys and values.
	_force_empty_service(service)
	game_root.request_close_if_drained()
	_check("service closed to RESULTS", game_root.get_phase() == SharedTypes.Phase.RESULTS)

	var settlement := run.get_day_settlement_view(1)
	var has_all_18 := settlement.size() == EXPECTED_SETTLEMENT_KEYS.size()
	for key in EXPECTED_SETTLEMENT_KEYS:
		if not settlement.has(key):
			has_all_18 = false
	_check("DaySettlementView contains all 18 documented keys", has_all_18)
	_check(
		"DaySettlementView finance values match ledger",
		int(settlement.get("begin_cash", -1)) == 100000
		and int(settlement.get("ingredient_purchase_total", -1)) == 10000
		and int(settlement.get("fixture_purchase_total", -1)) == 0
		and int(settlement.get("fixture_sale_total", -1)) == 0
		and int(settlement.get("order_revenue_dinein", -1)) == 20000
		and int(settlement.get("order_revenue_online", -1)) == 14000
		and int(settlement.get("refund_total", -1)) == 0
		and int(settlement.get("electricity_charge", -1)) == 2000
		and int(settlement.get("end_cash", -1)) == 122000
	)

	# Phase guards in RESULTS:
	_check("floor click rejected in RESULTS", not kitchen.on_floor_clicked(Vector2i(5, 3)))
	_check(
		"interactable click rejected in RESULTS",
		not kitchen.on_interactable_clicked(&"stove")
	)
	_check("finalize_plan rejected in RESULTS", not run.finalize_plan())
	_check(
		"request_ingredient_purchase rejected in RESULTS",
		not run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	)

	game_root.free()
	await process_frame



func _test_same_tick_delivery_precedes_close() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	_check("start service for same-tick tie-break test", game_root.start_service_requested())
	_check(
		"schedule 100s service delivery of 1 ayam (6000)",
		run.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	)

	# Drain service on the exact 100.0s tick when delivery becomes due:
	# delivery must commit BEFORE close, so refund_total == 0.
	_force_empty_service(service)
	game_root._process(100.0)

	var settlement := run.get_day_settlement_view(1)
	_check(
		"same-tick due delivery committed before close (not refunded)",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and kitchen.get_pending_delivery_views().is_empty()
		and int(settlement.get("refund_total", -1)) == 0
		and int(settlement.get("end_cash", -1)) == 92000
	)

	game_root.free()
	await process_frame



func _test_day_lifecycle_guards_and_day7_extra() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	# 1. First-time settlement during PLANNING is rejected without mutation.
	var plan_settle := run.settle_day_once({
		"day_index": 1,
		"failed_order_ids": [&"ord_early_fail"],
	})
	_check(
		"first-time settle_day_once in PLANNING rejected without mutation",
		plan_settle.is_empty()
		and run.get_day_settlement_view(1).is_empty()
		and int(run.get_run_view().get("cash", 0)) == 100000
		and int(run.get_run_view().get("demand_penalty_debt", -1)) == 0
	)

	# 5. Advancing from RESULTS before settlement is rejected.
	game_root._phase = SharedTypes.Phase.RESULTS
	_check(
		"direct advance_to_next_planning before settlement rejected",
		run.advance_to_next_planning() == 1
		and run.get_day_index() == 1
	)
	_check(
		"request_continue_from_results before settlement rejected",
		not game_root.request_continue_from_results()
		and game_root.get_day_index() == 1
		and game_root.get_phase() == SharedTypes.Phase.RESULTS
	)
	game_root._phase = SharedTypes.Phase.PLANNING

	# 2. First-time settlement during SERVING is rejected without mutation.
	_check("start Day 1 service", game_root.start_service_requested())
	var serving_settle := run.settle_day_once({
		"day_index": 1,
		"failed_order_ids": [&"ord_mid_service_fail"],
	})
	_check(
		"first-time settle_day_once in SERVING rejected without mutation",
		serving_settle.is_empty()
		and run.get_day_settlement_view(1).is_empty()
		and int(run.get_run_view().get("cash", 0)) == 100000
		and int(run.get_run_view().get("demand_penalty_debt", -1)) == 0
	)

	# 3. Settlement during CLOSING succeeds.
	_force_empty_service(service)
	game_root.request_close_if_drained()
	var day1_settlement := run.get_day_settlement_view(1)
	_check(
		"settlement during CLOSING succeeds and enters RESULTS",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and not day1_settlement.is_empty()
		and int(day1_settlement.get("end_cash", 0)) == 98000
	)

	# 4. Repeated settlement after closing returns cached result without duplicate charges.
	var cached_settle := run.settle_day_once({
		"day_index": 1,
		"failed_order_ids": [&"ord_late_fail"],
	})
	_check(
		"repeated settle_day_once after closing returns cached view without mutation",
		int(cached_settle.get("end_cash", 0)) == 98000
		and int(run.get_run_view().get("cash", 0)) == 98000
		and int(run.get_run_view().get("demand_penalty_debt", -1)) == 0
	)

	# 6 & 7. Advancing after settlement succeeds once; repeated direct call is rejected.
	_check(
		"direct advance_to_next_planning after Day 1 settlement advances to Day 2",
		run.advance_to_next_planning() == 2 and run.get_day_index() == 2
	)
	_check(
		"repeated direct advance_to_next_planning while still in RESULTS rejected",
		run.advance_to_next_planning() == 2 and run.get_day_index() == 2
	)
	game_root._set_phase(SharedTypes.Phase.PLANNING)

	# 8. Advance Days 2-6 to Day 7, win Day 7, and verify Extra Mode transition.
	for day in range(2, 7):
		_check("day %d start_service" % day, game_root.start_service_requested())
		_force_empty_service(service)
		game_root.request_close_if_drained()
		_check("day %d continue to next planning" % day, game_root.request_continue_from_results())

	_check("reached Day 7 PLANNING", game_root.get_day_index() == 7)
	_check("Day 7 start_service", game_root.start_service_requested())
	for i in range(35):
		run.credit_order_once(
			StringName("ord_d7_%02d" % i),
			&"nasi_telor",
			SharedTypes.OrderKind.DINE_IN
		)
	_force_empty_service(service)
	game_root.request_close_if_drained()
	_check(
		"Day 7 closes to FINISHED with WON outcome",
		game_root.get_phase() == SharedTypes.Phase.FINISHED
		and run.get_run_view().get("goal_outcome") == SharedTypes.DayOutcome.WON
	)
	_check(
		"Day 7 FINISHED rejects request_continue_from_results",
		not game_root.request_continue_from_results()
	)
	_check(
		"Day 7 WON enters Extra Mode Day 8 PLANNING once",
		game_root.request_extra_mode()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 8
	)
	_check(
		"Extra Mode repeat or direct advance on unsettled Day 8 rejected",
		not game_root.request_extra_mode()
		and run.advance_to_next_planning() == 8
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
