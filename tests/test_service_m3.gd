extends SceneTree
## Headless integration and unit tests for M3.1: GoFood / Online Delivery Lifecycle
## inside ServiceController.

class FailingCreditRunController extends RunController:
	var calls: int = 0

	func credit_order_once(
		_order_id: StringName,
		_recipe_id: StringName,
		_order_kind: int
	) -> bool:
		calls += 1
		return false


var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_offer_preview_weights_cutoff_and_concurrent_cap()
	await _test_immediate_cutoff_and_lowest_spot_priority()
	await _test_driver_spots_overflow_fifo_promotion_and_expired_skip()
	await _test_multi_overflow_reindex_and_different_recipe_delivery()
	await _test_online_delivery_plate_return_payout_and_rejections()
	await _test_online_expiry_drain_and_full_day_transition()
	await _test_kitchen_online_commands_and_driver_selection_lifecycle()
	await _test_online_presentation_overflow_and_game_ui()
	await _test_offer_rotation_cutoff_dimming_and_overflow_expiry()
	await _test_no_pause_modal_overlay_service_clock()
	await _test_auto_close_after_final_online_order_expires()
	await _test_typed_online_command_edge_cases()
	await _test_credit_order_failure_diagnostic_online()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _cook_plated_nasi_telor(kitchen: KitchenController) -> void:
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["b", "e", "r", "a", "s"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"washer")
	for ch in ["c", "u", "c", "i"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"rice_cooker")
	for ch in ["m", "a", "s", "a", "k"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	for ch in ["n", "a", "s", "i"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["t", "e", "l", "u", "r"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"stove")
	for ch in ["g", "o", "r", "e", "n", "g"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")


func _cook_loose_sayur(kitchen: KitchenController) -> void:
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["s", "a", "y", "u", "r"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"stove")
	for ch in ["g", "o", "r", "e", "n", "g"]:
		kitchen.accept_typed_character(ch)


func _cook_plated_nasi_ayam(kitchen: KitchenController) -> void:
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["b", "e", "r", "a", "s"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"washer")
	for ch in ["c", "u", "c", "i"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"rice_cooker")
	for ch in ["m", "a", "s", "a", "k"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	for ch in ["n", "a", "s", "i"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["a", "y", "a", "m"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"stove")
	for ch in ["g", "o", "r", "e", "n", "g"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	for ch in ["t", "e", "m", "p", "e"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"stove")
	for ch in ["g", "o", "r", "e", "n", "g"]:
		kitchen.accept_typed_character(ch)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")


func _test_offer_preview_weights_cutoff_and_concurrent_cap() -> void:
	# 1. Deterministic weighted offer selection & rejected acceptance invariance:
	var s1 := ServiceController.new()
	var s2 := ServiceController.new()
	var plan := {
		"day_queue_initial": 250,
		"selected_recipe_ids": [&"nasi_telor", &"nasi_ayam"],
		"dine_in_price_by_recipe": {
			&"nasi_telor": 10000,
			&"nasi_ayam": 40000,
		},
		"installed_table_ids": [&"dining_table_01"],
	}
	s1.register_table(&"dining_table_01")
	s2.register_table(&"dining_table_01")
	s1.set_rng_seed(9001)
	s2.set_rng_seed(9001)
	s1.prepare_service_day(2, plan)
	s2.prepare_service_day(2, plan)

	var pre1 := s1.get_online_offer_view()
	var pre2 := s2.get_online_offer_view()
	_check(
		"initial preview populated deterministically before begin_service and disabled",
		StringName(pre1["preview_recipe_id"]) != &""
		and StringName(pre1["preview_recipe_id"]) == StringName(pre2["preview_recipe_id"])
		and int(pre1["offer_generation_number"]) == 1
		and not bool(pre1["acceptance_enabled"])
		and StringName(pre1["disabled_reason"]) == &"not_serving"
	)

	_check(
		"rejected acceptance while not serving leaves offer generation unchanged",
		not s1.try_accept_online_offer()
		and s1.get_online_offer_view() == pre1
	)

	# Reject empty/zero-price offer data cleanly:
	var s_bad := ServiceController.new()
	s_bad.prepare_service_day(1, {
		"day_queue_initial": 4,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 0},
		"installed_table_ids": [],
	})
	s_bad.begin_service(0.0)
	_check(
		"zero-price menu recipe disables acceptance and rejects try_accept_online_offer",
		not s_bad.get_online_acceptance_enabled()
		and not s_bad.try_accept_online_offer()
	)
	s_bad.free()

	# Weighted offer sample across 60 cycles matches 1 / price bias and determinism:
	s1.begin_service(0.0)
	s2.begin_service(0.0)
	var counts := {&"nasi_telor": 0, &"nasi_ayam": 0}
	var seq1: Array[StringName] = []
	var seq2: Array[StringName] = []
	for i in range(60):
		var v1 := s1.get_online_offer_view()
		var v2 := s2.get_online_offer_view()
		var r1 := StringName(v1["preview_recipe_id"])
		var r2 := StringName(v2["preview_recipe_id"])
		seq1.append(r1)
		seq2.append(r2)
		counts[r1] = int(counts.get(r1, 0)) + 1
		s1.try_accept_online_offer()
		s2.try_accept_online_offer()
		var t_next := 60.0 * float(i + 1)
		s1.advance_service_time(t_next)
		s2.advance_service_time(t_next)
	_check(
		"fixed RNG seed yields identical multi-step preview sequence weighted to cheaper dish",
		seq1 == seq2
		and int(counts[&"nasi_telor"]) > int(counts[&"nasi_ayam"]) * 2
		and int(counts[&"nasi_ayam"]) > 0
	)
	s1.free()
	s2.free()

	# 2. Integrated cutoff & concurrent OPEN cap == day_queue_initial (no total daily quota):
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	_check("day 1 starts service", game_root.start_service_requested())

	# At t=0, Customer 1 spawned -> day_queue_remaining == 3 (> 2), concurrent cap == 4:
	_check(
		"at t=0 remaining quota 3 enables online offers and keeps preview",
		int(service.get_customer_queue_view()["day_queue_remaining"]) == 3
		and service.get_online_acceptance_enabled()
		and int(service.get_online_offer_view()["concurrent_limit"]) == 4
	)

	# Accepting 4 online orders hits concurrent cap == day_queue_initial (4) while remaining == 3:
	for i in range(4):
		var gen_before := int(service.get_online_offer_view()["offer_generation_number"])
		_check("accept online order #%d succeeds" % (i + 1), service.try_accept_online_offer())
		_check(
			"acceptance #%d rotates generation & preserves day_queue_remaining == 3" % (i + 1),
			int(service.get_online_offer_view()["offer_generation_number"]) == gen_before + 1
			and int(service.get_customer_queue_view()["day_queue_remaining"]) == 3
			and int(service.get_customer_queue_view()["online_open_count"]) == i + 1
		)

	var cap_offer := service.get_online_offer_view()
	_check(
		"5th concurrent accept rejected at cap=4 without rotating preview",
		not service.get_online_acceptance_enabled()
		and StringName(cap_offer["disabled_reason"]) == &"concurrent_cap_reached"
		and StringName(cap_offer["preview_recipe_id"]) != &""
		and not service.try_accept_online_offer()
		and service.get_online_offer_view() == cap_offer
	)

	# Serve 1st driver -> concurrent OPEN drops 4 -> 3 while day_queue_remaining stays 3 ->
	# acceptance re-enables and allows a 5th daily online order (proving no total daily cap)!
	_cook_plated_nasi_telor(kitchen)
	var first_drv_id := StringName(service.get_driver_views()[0]["driver_id"])
	var held_id := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"serving 1st driver frees concurrent slot cleanly",
		service.try_serve_driver(first_drv_id, held_id)
		and int(service.get_customer_queue_view()["online_open_count"]) == 3
		and service.get_online_acceptance_enabled()
		and service.try_accept_online_offer()
		and int(service.get_customer_queue_view()["online_open_count"]) == 4
	)

	# Advance 20.0s -> Customer 2 spawns -> day_queue_remaining becomes 2 -> cutoff reached!
	game_root._process(20.0)
	var cutoff_offer := service.get_online_offer_view()
	_check(
		"at day_queue_remaining <= 2 cutoff disables offers while keeping preview intact",
		int(service.get_customer_queue_view()["day_queue_remaining"]) == 2
		and not service.get_online_acceptance_enabled()
		and StringName(cutoff_offer["disabled_reason"]) == &"cutoff_reached"
		and StringName(cutoff_offer["preview_recipe_id"]) != &""
		and not service.try_accept_online_offer()
		and service.get_online_offer_view() == cutoff_offer
	)

	# Existing OPEN online orders MUST still remain serveable after cutoff!
	_cook_plated_nasi_telor(kitchen)
	var post_cutoff_drv := StringName(service.get_driver_views()[0]["driver_id"])
	var post_cutoff_item := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"existing OPEN online orders remain valid and serveable after cutoff",
		service.try_serve_driver(post_cutoff_drv, post_cutoff_item)
		and int(service.get_customer_queue_view()["online_open_count"]) == 3
	)

	game_root.free()
	await process_frame


func _test_immediate_cutoff_and_lowest_spot_priority() -> void:
	# 1. Quota 3: t=0 spawn drops remaining from 3 to 2 -> immediate cutoff at begin_service:
	var s_q3 := ServiceController.new()
	s_q3.register_table(&"dining_table_01")
	s_q3.prepare_service_day(1, {
		"day_queue_initial": 3,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01"],
	})
	s_q3.begin_service(0.0)
	var q3_offer := s_q3.get_online_offer_view()
	_check(
		"quota 3 immediately reaches cutoff (remaining == 2) on begin_service(0.0)",
		int(s_q3.get_customer_queue_view()["day_queue_remaining"]) == 2
		and not s_q3.get_online_acceptance_enabled()
		and StringName(q3_offer["disabled_reason"]) == &"cutoff_reached"
		and StringName(q3_offer["preview_recipe_id"]) == &"nasi_telor"
		and not s_q3.try_accept_online_offer()
	)
	s_q3.free()

	# 2. Lowest available pickup spot when spot_01 and spot_03 are free while spot_02 occupied:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	game_root.start_service_requested()

	service.try_accept_online_offer()
	service.try_accept_online_offer()
	service.try_accept_online_offer()
	var initial_drvs := service.get_driver_views()
	# Serve spot 1 (D1) and spot 3 (D3), leaving ONLY spot 2 occupied (01 & 03 both free):
	_cook_plated_nasi_telor(kitchen)
	service.try_serve_driver(
		StringName(initial_drvs[0]["driver_id"]),
		StringName(kitchen.get_held_item_view()["item_id"])
	)
	_cook_plated_nasi_telor(kitchen)
	service.try_serve_driver(
		StringName(initial_drvs[2]["driver_id"]),
		StringName(kitchen.get_held_item_view()["item_id"])
	)
	# Newly accepted offer must occupy lowest free spot_01 (not spot_03):
	_check("accepting new offer while 01 & 03 free succeeds", service.try_accept_online_offer())
	var after_views := service.get_driver_views()
	_check(
		"newly accepted driver picks lowest free spot pickup_spot_01 over pickup_spot_03",
		after_views.size() == 2
		and StringName(after_views[0]["spot_id_or_empty"]) == &"pickup_spot_01"
		and StringName(after_views[1]["spot_id_or_empty"]) == &"pickup_spot_02"
	)

	game_root.free()
	await process_frame


func _test_driver_spots_overflow_fifo_promotion_and_expired_skip() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	game_root.start_service_requested()

	# Test read-only views for 5 accepted orders spaced across time:
	# D1..D3 at t=0 (spots 1..3), D4 at t=5 (dl=65, overflow 0),
	# plus D5? Quota Day 1 initial=4 allows 4 concurrent; let's serve D2 (spot 2) after
	# promoting/checking D1..D4, AND also test 5+ overflow on a prepared Day 2 service (cap=8).
	service.try_accept_online_offer()
	service.try_accept_online_offer()
	service.try_accept_online_offer()
	game_root._process(5.0)
	service.try_accept_online_offer()

	var dviews := service.get_driver_views()
	_check(
		"first 3 drivers occupy pickup_spot_01..03 and 4th enters overflow FIFO",
		dviews.size() == 4
		and int(dviews[0]["state"]) == SharedTypes.DriverState.AT_PICKUP_SPOT
		and StringName(dviews[0]["spot_id_or_empty"]) == &"pickup_spot_01"
		and bool(dviews[0]["serveable"])
		and int(dviews[0]["queue_index"]) == -1
		and StringName(dviews[1]["spot_id_or_empty"]) == &"pickup_spot_02"
		and StringName(dviews[2]["spot_id_or_empty"]) == &"pickup_spot_03"
		and int(dviews[3]["state"]) == SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE
		and StringName(dviews[3]["spot_id_or_empty"]) == &""
		and not bool(dviews[3]["serveable"])
		and int(dviews[3]["queue_index"]) == 0
		and is_equal_approx(float(dviews[3]["seconds_remaining"]), 60.0)
		and is_equal_approx(float(dviews[3]["total_seconds"]), 60.0)
	)

	# Mutating returned driver view copy does not affect ServiceController:
	dviews[0]["serveable"] = false
	dviews[0]["spot_id_or_empty"] = &"tampered"
	_check(
		"get_driver_views() returns read-only deep copies",
		bool(service.get_driver_views()[0]["serveable"])
		and StringName(service.get_driver_views()[0]["spot_id_or_empty"]) == &"pickup_spot_01"
	)

	# Overflow driver is rejected by try_serve_driver even with valid dish:
	_cook_plated_nasi_telor(kitchen)
	var item_id := StringName(kitchen.get_held_item_view()["item_id"])
	var overflow_drv_id := StringName(dviews[3]["driver_id"])
	var spot2_drv_id := StringName(dviews[1]["driver_id"])
	_check(
		"overflow driver & unknown driver rejected without consuming held dish",
		not service.try_serve_driver(overflow_drv_id, item_id)
		and not service.try_serve_driver(&"drv_unknown", item_id)
		and not kitchen.get_held_item_view().is_empty()
	)

	# Serve Spot 2 driver at t=15 (D4 arrived at t=5, dl=65 -> 50s remaining!):
	game_root._process(10.0)
	_check(
		"delivering to pickup_spot_02 promotes D4 into pickup_spot_02 with 50s deadline intact",
		service.try_serve_driver(spot2_drv_id, item_id)
		and StringName(service.get_driver_view(overflow_drv_id)["spot_id_or_empty"])
		== &"pickup_spot_02"
		and int(service.get_driver_view(overflow_drv_id)["state"])
		== SharedTypes.DriverState.AT_PICKUP_SPOT
		and bool(service.get_driver_view(overflow_drv_id)["serveable"])
		and is_equal_approx(
			float(service.get_driver_view(overflow_drv_id)["seconds_remaining"]),
			50.0
		)
		and int(service.get_customer_queue_view()["outside_driver_count"]) == 0
	)

	game_root.free()
	await process_frame

	# Multi-overflow test (cap = 6): D1..D3 at t=10 (dl=70), D4 at t=0? No, reverse order:
	# D1..D3 accepted at t=10 (dl=70), Wait — in real timeline, to make an overflow driver expire
	# BEFORE a spot driver, D4 in overflow needs an earlier deadline? Actually, how can D4 in
	# overflow expire BEFORE a spot driver? Spot 1 gets replaced at t=15 by D4 (Wait: D5 arrived
	# at t=15 dl=75, while D6 arrived at t=20 dl=80; Spot 2 holds a driver accepted at t=25 dl=85
	# after Spot 2 was cleared earlier!). Let's reproduce that EXACT real timeline!
	var s_fifo := ServiceController.new()
	var k_fifo := KitchenController.new()
	k_fifo.register_plate_rack(&"plate_rack", 4)
	k_fifo.register_storage_unit(&"storage_box", SharedTypes.FixtureKind.BOX)
	k_fifo.register_work_table(&"work_table")
	k_fifo.receive_stock(&"s_b", &"beras", 4, &"storage_box")
	k_fifo.receive_stock(&"s_t", &"telur", 4, &"storage_box")
	s_fifo.register_table(&"dining_table_01")
	s_fifo.bind_systems(k_fifo, null, null)
	s_fifo.prepare_service_day(2, {
		"day_queue_initial": 8,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01"],
	})
	s_fifo.begin_service(0.0)

	# t=0: D1..D3 occupy spots 1..3 (dl=60), D4 enters overflow 0 (dl=60).
	s_fifo.try_accept_online_offer()
	s_fifo.try_accept_online_offer()
	s_fifo.try_accept_online_offer()
	s_fifo.try_accept_online_offer()
	# t=5: D5 enters overflow 1 (dl=65); t=10: D6 enters overflow 2 (dl=70).
	s_fifo.advance_service_time(5.0)
	s_fifo.try_accept_online_offer()
	s_fifo.advance_service_time(10.0)
	s_fifo.try_accept_online_offer()

	# At t=60: spots D1..D3 AND expired overflow D4 (dl=60) are removed;
	# only still-valid D5 (5s left) & D6 (10s left) promote into pickup_spot_01..02!
	s_fifo.advance_service_time(60.0)
	var views_at_60 := s_fifo.get_driver_views()
	_check(
		"expired overflow D4 removed; live D5 & D6 promote into spots 1..2 keeping deadlines",
		views_at_60.size() == 2
		and not s_fifo.has_driver(&"drv_d2_004")
		and int(s_fifo.get_order_view(&"ord_d2_004")["status"]) == SharedTypes.OrderStatus.FAILED
		and StringName(views_at_60[0]["driver_id"]) == &"drv_d2_005"
		and StringName(views_at_60[0]["spot_id_or_empty"]) == &"pickup_spot_01"
		and is_equal_approx(float(views_at_60[0]["seconds_remaining"]), 5.0)
		and StringName(views_at_60[1]["driver_id"]) == &"drv_d2_006"
		and StringName(views_at_60[1]["spot_id_or_empty"]) == &"pickup_spot_02"
		and is_equal_approx(float(views_at_60[1]["seconds_remaining"]), 10.0)
	)
	# Now accept 2 more at t=60 (dl=120): Spot 3 gets D7(dl=120), overflow gets D8(dl=120):
	s_fifo.try_accept_online_offer()
	s_fifo.try_accept_online_offer()
	# Jump t=60 -> t=72 where D5(dl=65) and D6(dl=70) BOTH expire at once while D7(spot 3)
	# and D8(overflow) survive -> D8 promotes to lowest spot 1 cleanly:
	s_fifo.advance_service_time(72.0)
	# Repeated tick at 72.0 must be idempotent:
	s_fifo.advance_service_time(72.0)
	var views_at_72 := s_fifo.get_driver_views()
	_check(
		"multi-expiry in single tick skips already-expired entries and promotes D8 cleanly once",
		views_at_72.size() == 2
		and StringName(views_at_72[0]["driver_id"]) == &"drv_d2_008"
		and StringName(views_at_72[0]["spot_id_or_empty"]) == &"pickup_spot_01"
		and StringName(views_at_72[1]["driver_id"]) == &"drv_d2_007"
		and StringName(views_at_72[1]["spot_id_or_empty"]) == &"pickup_spot_03"
		and int(s_fifo.get_customer_queue_view()["online_open_count"]) == 2
	)

	s_fifo.free()
	k_fifo.free()
	await process_frame


func _serve_nasi_telor_table(
	kitchen: KitchenController,
	service: ServiceController,
	table_id: StringName
) -> void:
	_cook_plated_nasi_telor(kitchen)
	service.try_serve_table(table_id, StringName(kitchen.get_held_item_view()["item_id"]))


func _serve_day1_four_diners(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController
) -> void:
	# Caller must pre-buy >= 4 beras and >= 4 telur in PLANNING before start_service_requested().
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_01")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_02")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)


func _test_multi_overflow_reindex_and_different_recipe_delivery() -> void:
	# Transition Day 1 -> Day 2 via real GameRoot so Day 2 unlocks both nasi_telor & nasi_ayam
	# and provides day_queue_initial = 10 (0 debt after serving all 4 Day 1 diners cleanly):
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	game_root.start_service_requested()
	_serve_day1_four_diners(game_root, kitchen, service)
	game_root.request_continue_from_results()
	run.select_daily_menu([&"nasi_telor", &"nasi_ayam"])

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	run.request_ingredient_purchase(&"tempe", 1, &"storage_box")
	service.set_rng_seed(777)
	game_root.start_service_requested()

	# Accept 5 online orders on Day 2 -> 3 at spots, 2 in overflow (queue_index 0 & 1):
	var got_telor := false
	var got_ayam := false
	for _i in range(5):
		var rid := StringName(service.get_online_offer_view()["preview_recipe_id"])
		if rid == &"nasi_telor":
			got_telor = true
		elif rid == &"nasi_ayam":
			got_ayam = true
		service.try_accept_online_offer()

	# If RNG sequence for seed 777 had only 1 recipe in first 5, verify overflow first, then ensure
	# one of the spots has nasi_telor and one has nasi_ayam:
	var five_views := service.get_driver_views()
	_check(
		"5 concurrent drivers produce 3 in-spot + 2 sequential overflow (queue_index 0, 1)",
		five_views.size() == 5
		and int(five_views[3]["queue_index"]) == 0
		and not bool(five_views[3]["serveable"])
		and int(five_views[4]["queue_index"]) == 1
		and not bool(five_views[4]["serveable"])
	)

	# Free Spot 1 by expiring? No, prepare Day 3 with fixed seed yielding both recipes if needed,
	# or serve spot 2 if we have both recipes among the 3 spots:
	var spot_telor_id := &""
	var spot_ayam_id := &""
	for i in range(3):
		var rec := StringName(five_views[i]["recipe_id"])
		if rec == &"nasi_telor" and spot_telor_id == &"":
			spot_telor_id = StringName(five_views[i]["driver_id"])
		elif rec == &"nasi_ayam" and spot_ayam_id == &"":
			spot_ayam_id = StringName(five_views[i]["driver_id"])

	# Assemble real nasi_ayam once; verify cross-recipe rejection on nasi_telor driver AND real
	# delivery onto nasi_ayam driver (paying floor(28000 * 70 / 100) = 19600) + FIFO reindex!
	if got_telor and got_ayam and spot_telor_id != &"" and spot_ayam_id != &"":
		_cook_plated_nasi_ayam(kitchen)
		var ayam_item := StringName(kitchen.get_held_item_view()["item_id"])
		var cash_pre := int(run.get_run_view()["cash"])
		_check(
			"wrong-recipe delivery (nasi_ayam onto nasi_telor driver) fails without consumption",
			not service.try_serve_driver(spot_telor_id, ayam_item)
			and not kitchen.get_held_item_view().is_empty()
			and int(run.get_run_view()["cash"]) == cash_pre
		)
		var first_ov_id := StringName(five_views[3]["driver_id"])
		var second_ov_id := StringName(five_views[4]["driver_id"])
		var freed_spot := StringName(service.get_driver_view(spot_ayam_id)["spot_id_or_empty"])
		_check(
			"same nasi_ayam dish completes matching driver (19600) & reindexes remaining FIFO",
			service.try_serve_driver(spot_ayam_id, ayam_item)
			and int(run.get_run_view()["cash"]) == cash_pre + 19600
			and kitchen.get_held_item_view().is_empty()
			and StringName(service.get_driver_view(first_ov_id)["spot_id_or_empty"]) == freed_spot
			and int(service.get_driver_view(first_ov_id)["queue_index"]) == -1
			and bool(service.get_driver_view(first_ov_id)["serveable"])
			and int(service.get_driver_view(second_ov_id)["queue_index"]) == 0
			and not bool(service.get_driver_view(second_ov_id)["serveable"])
		)
	else:
		_check("seed produced both nasi_telor and nasi_ayam in first 3 spots", false)

	game_root.free()
	await process_frame


func _test_online_delivery_plate_return_payout_and_rejections() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
	var cash_before := int(run.get_run_view()["cash"])

	game_root.start_service_requested()
	service.try_accept_online_offer()
	var drv_view := service.get_driver_views()[0]
	var drv_id := StringName(drv_view["driver_id"])
	var ord_id := StringName(drv_view["order_id"])

	# 1. Unplated / loose food rejected without consuming item or crediting cash:
	_cook_loose_sayur(kitchen)
	var loose_id := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"unplated food rejected by try_serve_driver without mutating hand/order/cash",
		not service.try_serve_driver(drv_id, loose_id)
		and not kitchen.get_held_item_view().is_empty()
		and int(service.get_order_view(ord_id)["status"]) == SharedTypes.OrderStatus.OPEN
		and int(run.get_run_view()["cash"]) == cash_before
	)
	kitchen.on_interactable_clicked(&"trash")

	# 2. Valid plated nasi_telor: consumes dish, returns SAME plate to RACK, pays 14000 once:
	_cook_plated_nasi_telor(kitchen)
	var held_before := kitchen.get_held_item_view()
	var plate_id := StringName(held_before["plate_id"])
	var item_id := StringName(held_before["item_id"])

	_check(
		"valid online delivery consumes dish, returns plate clean to RACK, pays 70% (14000)",
		service.try_serve_driver(drv_id, item_id)
		and kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
		and kitchen.get_plate_count() == 4
		and int(kitchen.get_washer_view()["dirty_plate_count"]) == 0
		and int(service.get_table_view(&"dining_table_01")["state"])
		== SharedTypes.TableState.OCCUPIED_WAITING
		and int(service.get_table_view(&"dining_table_02")["state"])
		== SharedTypes.TableState.CLEAN_VACANT
		and int(service.get_order_view(ord_id)["status"]) == SharedTypes.OrderStatus.COMPLETED
		and not service.has_driver(drv_id)
		and int(run.get_run_view()["cash"]) == cash_before + 14000
	)
	# Verified via public KitchenController APIs: 4 clean plates are physically takeable
	# from PlateRack (1 take + return per loop preserves total 4 without washer dirt).
	kitchen.on_interactable_clicked(&"plate_rack")
	var retaken_id := StringName(kitchen.get_held_item_view().get("plate_id", &""))
	var returned_ok := retaken_id == plate_id
	kitchen.on_interactable_clicked(&"plate_rack")
	_check(
		"returned online plate is clean in PlateRack and reusable immediately",
		returned_ok
		and kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
		and int(kitchen.get_washer_view()["dirty_plate_count"]) == 0
	)

	# 3. Duplicate delivery rejected without double credit or hand consumption:
	_cook_plated_nasi_telor(kitchen)
	var second_item_id := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"duplicate delivery attempt on completed driver rejected without mutation",
		not service.try_serve_driver(drv_id, second_item_id)
		and not run.credit_order_once(ord_id, &"nasi_telor", SharedTypes.OrderKind.ONLINE)
		and not kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view()["cash"]) == cash_before + 14000
	)

	# 4. Exact 60.0s deadline boundary via public clock advancement (GameRoot._process):
	service.try_accept_online_offer()
	var drv2 := service.get_driver_views()[0]
	var drv2_id := StringName(drv2["driver_id"])
	var ord2_id := StringName(drv2["order_id"])
	game_root._process(59.9)
	_check(
		"before 60.0s deadline online order remains OPEN",
		int(service.get_order_view(ord2_id)["status"]) == SharedTypes.OrderStatus.OPEN
		and service.has_driver(drv2_id)
	)
	game_root._process(0.1)
	_check(
		"delivery at exact 60.0s deadline via public clock fails without consuming dish",
		not service.try_serve_driver(drv2_id, second_item_id)
		and not kitchen.get_held_item_view().is_empty()
		and int(service.get_order_view(ord2_id)["status"]) == SharedTypes.OrderStatus.FAILED
		and not service.has_driver(drv2_id)
		and int(run.get_run_view()["cash"]) == cash_before + 14000
	)

	game_root.free()
	await process_frame

	# 5. Wrong plated dish (nasi_ayam) against nasi_telor online order rejected cleanly:
	var g_wrong := packed.instantiate() as GameRoot
	root.add_child(g_wrong)
	await process_frame
	var kw := g_wrong.get_kitchen_controller() as KitchenController
	var sw := g_wrong.get_service_controller() as ServiceController
	var rw := g_wrong.get_run_controller() as RunController
	rw.request_ingredient_purchase(&"beras", 1, &"storage_box")
	rw.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	rw.request_ingredient_purchase(&"tempe", 1, &"storage_box")
	var cw := int(rw.get_run_view()["cash"])
	g_wrong.start_service_requested()
	sw.try_accept_online_offer()
	var wd_id := StringName(sw.get_driver_views()[0]["driver_id"])
	var wo_id := StringName(sw.get_driver_views()[0]["order_id"])
	_cook_plated_nasi_ayam(kw)
	var wrong_item_id := StringName(kw.get_held_item_view()["item_id"])
	_check(
		"wrong plated dish (nasi_ayam) rejected by try_serve_driver without mutation",
		not sw.try_serve_driver(wd_id, wrong_item_id)
		and StringName(kw.get_held_item_view()["matched_recipe_id"]) == &"nasi_ayam"
		and int(sw.get_order_view(wo_id)["status"]) == SharedTypes.OrderStatus.OPEN
		and int(rw.get_run_view()["cash"]) == cw
	)

	g_wrong.free()
	await process_frame


func _test_online_expiry_drain_and_full_day_transition() -> void:
	# 1. Standard production timings: Day 1 -> completed & failed online -> Day 2 transition:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	var sig_counts := {"drivers": 0, "orders": 0, "online": 0}
	service.drivers_changed.connect(func() -> void: sig_counts["drivers"] += 1)
	service.orders_changed.connect(func() -> void: sig_counts["orders"] += 1)
	service.online_offer_changed.connect(func() -> void: sig_counts["online"] += 1)

	run.request_ingredient_purchase(&"beras", 5, &"storage_box")
	run.request_ingredient_purchase(&"telur", 5, &"storage_box")
	game_root.start_service_requested()

	# Accept 2 online orders at t=10.0 (dl=70.0): serve 1st, let 2nd expire at t=70.0.
	# Also serve all 4 Day 1 diners cleanly so Day 2 keeps quota >= 6 (after 1 online miss):
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(10.0)
	_check(
		"accept 2 online orders at t=10 (dl=70)",
		service.try_accept_online_offer() and service.try_accept_online_offer()
	)
	var d_serve_id := StringName(service.get_driver_views()[0]["driver_id"])
	var d_exp_ord_id := StringName(service.get_driver_views()[1]["order_id"])
	_cook_plated_nasi_telor(kitchen)
	_check(
		"serve 1st online order before deadline (+14000)",
		service.try_serve_driver(
			d_serve_id,
			StringName(kitchen.get_held_item_view()["item_id"])
		)
	)

	game_root._process(10.0)
	service.try_clean_table(&"dining_table_01")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_02")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")

	var drv_sig_before := int(sig_counts["drivers"])
	game_root._process(10.0)
	_check(
		"2nd online order expires at t=70.0 and emits drivers/orders/online signals",
		int(service.get_customer_queue_view()["online_open_count"]) == 0
		and service.get_driver_views().is_empty()
		and int(service.get_order_view(d_exp_ord_id)["status"]) == SharedTypes.OrderStatus.FAILED
		and int(sig_counts["drivers"]) > drv_sig_before
	)

	# Advance 10s (t=80.0): C4 finishes eating -> Day 1 closes to RESULTS (debt 1..2):
	game_root._process(10.0)
	var settle1 := run.get_day_settlement_view(1)
	var debt1 := int(run.get_run_view()["demand_penalty_debt"])
	_check(
		"Day 1 RESULTS records completed_online=1, failed_online=1, revenue=14000, debt in [1,2]",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and int(settle1.get("completed_dinein_count", -1)) == 4
		and int(settle1.get("completed_online_count", -1)) == 1
		and int(settle1.get("failed_online_count", -1)) == 1
		and int(settle1.get("order_revenue_online", -1)) == 14000
		and debt1 >= 1
		and debt1 <= 2
	)

	_check(
		"continue from Day 1 RESULTS to Day 2 PLANNING",
		game_root.request_continue_from_results()
	)
	_check("start Day 2 service", game_root.start_service_requested())
	var q_day2 := service.get_customer_queue_view()
	_check(
		"Day 2 clears Day 1 online drivers/queues and resets preview state",
		game_root.get_phase() == SharedTypes.Phase.SERVING
		and int(q_day2["online_open_count"]) == 0
		and int(q_day2["outside_driver_count"]) == 0
		and service.get_driver_views().is_empty()
		and int(service.get_online_offer_view()["offer_generation_number"]) == 1
	)
	_check(
		"Day 2 accept online creates ord_d2_* / drv_d2_* IDs",
		service.try_accept_online_offer()
	)
	var d2_view := service.get_driver_views()[0]
	_check(
		"Day 2 online IDs use d2 prefix cleanly",
		String(d2_view["driver_id"]).begins_with("drv_d2_")
		and String(d2_view["order_id"]).begins_with("ord_d2_")
	)

	game_root.free()
	await process_frame

	# 2. Normal dine-in timings (20s spawn, 100s patience, 20s eat) finishing BEFORE online:
	# Note: under default 20s spawn / 20s eat / 60s online / cutoff <= 2, for any quota Q >= 4
	# the final diner spawns at t_cutoff + 40s and eats for 20s (ending at t_cutoff + 60s), so
	# any pre-cutoff 60s online order expires strictly before the last diner finishes eating.
	# Using public `run.economy_config` with online_deadline_seconds = 95.0 while keeping all
	# dine-in timings unchanged proves all 4 diners complete cleanly leaving OPEN online alone.
	var g2 := packed.instantiate() as GameRoot
	root.add_child(g2)
	await process_frame
	var s2 := g2.get_service_controller() as ServiceController
	var r2 := g2.get_run_controller() as RunController
	var k2 := g2.get_kitchen_controller() as KitchenController

	var live_cfg := r2.economy_config.duplicate(true) as EconomyConfig
	live_cfg.online_deadline_seconds = 95.0
	r2.economy_config = live_cfg
	s2.bind_systems(k2, r2, g2)
	r2.request_ingredient_purchase(&"beras", 5, &"storage_box")
	r2.request_ingredient_purchase(&"telur", 5, &"storage_box")
	g2.start_service_requested()

	_cook_plated_nasi_telor(k2)
	s2.try_serve_table(&"dining_table_01", StringName(k2.get_held_item_view()["item_id"]))
	g2._process(19.0)
	_check("accept online order at t=19.0 (dl=114.0)", s2.try_accept_online_offer())

	g2._process(1.0)
	s2.try_clean_table(&"dining_table_01")
	_cook_plated_nasi_telor(k2)
	s2.try_serve_table(&"dining_table_02", StringName(k2.get_held_item_view()["item_id"]))

	g2._process(20.0)
	s2.try_clean_table(&"dining_table_02")
	_cook_plated_nasi_telor(k2)
	s2.try_serve_table(&"dining_table_01", StringName(k2.get_held_item_view()["item_id"]))

	g2._process(20.0)
	_cook_plated_nasi_telor(k2)
	s2.try_serve_table(&"dining_table_02", StringName(k2.get_held_item_view()["item_id"]))

	g2._process(20.0)
	var q_wait := s2.get_customer_queue_view()
	_check(
		"after 4 diners complete normal lifecycle, OPEN online order alone blocks drain",
		int(q_wait["day_queue_remaining"]) == 0
		and int(q_wait["outside_dinein_count"]) == 0
		and int(q_wait["in_shop_count"]) == 0
		and int(q_wait["online_open_count"]) == 1
		and not s2.is_drained()
		and g2.get_phase() == SharedTypes.Phase.SERVING
	)

	# Clean table 1, wash dirty plate, return to rack, cook & deliver final online order:
	s2.try_clean_table(&"dining_table_01")
	k2.on_interactable_clicked(&"washer")
	for ch in ["c", "u", "c", "i"]:
		k2.accept_typed_character(ch)
	k2.on_interactable_clicked(&"plate_rack")
	_cook_plated_nasi_telor(k2)
	var last_drv := StringName(s2.get_driver_views()[0]["driver_id"])
	_check(
		"delivering final OPEN online order drains service immediately",
		s2.try_serve_driver(last_drv, StringName(k2.get_held_item_view()["item_id"]))
		and s2.is_drained()
	)
	g2._process(0.016)
	var settle2 := r2.get_day_settlement_view(1)
	_check(
		"GameRoot closes to RESULTS with all 4 dine-in and 1 online completed",
		g2.get_phase() == SharedTypes.Phase.RESULTS
		and int(settle2.get("completed_dinein_count", -1)) == 4
		and int(settle2.get("completed_online_count", -1)) == 1
		and int(settle2.get("order_revenue_dinein", -1)) == 80000
		and int(settle2.get("order_revenue_online", -1)) == 14000
	)

	g2.free()
	await process_frame


func _test_credit_order_failure_diagnostic_online() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var failing_run := FailingCreditRunController.new()
	failing_run.name = "RunController"
	var orig_run := game_root.get_node("RunController")
	game_root.remove_child(orig_run)
	orig_run.free()
	game_root.add_child(failing_run)
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController

	failing_run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	failing_run.request_ingredient_purchase(&"telur", 1, &"storage_box")
	game_root.start_service_requested()
	service.try_accept_online_offer()
	var drv_view := service.get_driver_views()[0]
	var drv_id := StringName(drv_view["driver_id"])
	var ord_id := StringName(drv_view["order_id"])

	_cook_plated_nasi_telor(kitchen)
	var item_id := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"credit_order_once failure on online serve logs invariant diagnostic",
		service.try_serve_driver(drv_id, item_id)
		and failing_run.calls == 1
		and kitchen.get_held_item_view().is_empty()
		and int(service.get_order_view(ord_id)["status"])
		== SharedTypes.OrderStatus.COMPLETED
		and not service.has_driver(drv_id)
		and service._last_invariant_error.contains(String(ord_id))
		and service._last_invariant_error.contains("nasi_telor")
	)

	game_root.free()
	await process_frame


func _type_chars_on_kitchen(kitchen: KitchenController, word: String) -> void:
	for i in range(word.length()):
		kitchen.accept_typed_character(word.substr(i, 1))


func _click_canvas_target(ui: GameUI, world: WorldMap, target_id: StringName) -> void:
	var node := world.registry.get_object(target_id)
	if node == null:
		return
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = world.get_canvas_transform() * node.global_position
	ui._unhandled_input(ev)


func _test_kitchen_online_commands_and_driver_selection_lifecycle() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	var feedbacks: Array[StringName] = []
	kitchen.action_feedback.connect(func(code: StringName) -> void: feedbacks.append(code))

	# 1. `terima` outside SERVING (PLANNING) rejected without mutating cash/orders:
	_click_canvas_target(ui, world, &"online_station")
	_check(
		"online_station selectable in PLANNING; terima rejected outside SERVING",
		kitchen.get_selected_target_id() == &"online_station"
		and not kitchen.accept_typed_character("t")
		and service.get_driver_views().is_empty()
	)

	# 2. Prepare ingredients + enter SERVING -> stage empty plate to verify zero side-effects:
	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
	var cash_start := int(run.get_run_view()["cash"])
	game_root.start_service_requested()

	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var staged_before := kitchen.get_work_table_view(&"work_table")

	# Click online_station -> type `terima` -> accepts generation 1 once (1 -> 2):
	_click_canvas_target(ui, world, &"online_station")
	_type_chars_on_kitchen(kitchen, "terima")
	var drvs_after_1 := service.get_driver_views()
	_check(
		"typed terima accepts 1st offer, creates 1 driver, keeps staged items untouched",
		not feedbacks.is_empty() and feedbacks[-1] == &"online_accepted"
		and drvs_after_1.size() == 1
		and int(service.get_online_offer_view()["offer_generation_number"]) == 2
		and int(service.get_customer_queue_view()["day_queue_remaining"]) == 3
		and kitchen.get_work_table_view(&"work_table") == staged_before
		and int(run.get_run_view()["cash"]) == cash_start
	)

	# Repeated `terima` accepts offers #2..#4 up to concurrent cap = 4:
	for _i in range(3):
		_type_chars_on_kitchen(kitchen, "terima")
	_check(
		"4th concurrent terima reaches cap=4 (3 in-spot + 1 overflow)",
		service.get_driver_views().size() == 4
		and int(service.get_customer_queue_view()["outside_driver_count"]) == 1
	)

	# 5th `terima` at concurrent cap rejects safely without mutating held/staged/plates/cash:
	var gen_at_cap := int(service.get_online_offer_view()["offer_generation_number"])
	_type_chars_on_kitchen(kitchen, "terima")
	_check(
		"terima at concurrent cap rejects without rotating preview or mutating state",
		feedbacks[-1] == &"invalid_action"
		and int(service.get_online_offer_view()["offer_generation_number"]) == gen_at_cap
		and service.get_driver_views().size() == 4
		and kitchen.get_work_table_view(&"work_table") == staged_before
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 3
		and int(run.get_run_view()["cash"]) == cash_start
	)

	# 3. Overflow driver cannot receive `saji` (rejected via click & command):
	var ov_id := StringName(service.get_driver_views()[3]["driver_id"])
	_check(
		"overflow driver cannot be selected or targeted via KitchenController",
		not kitchen.on_interactable_clicked(ov_id)
		and feedbacks[-1] == &"unknown_target"
	)

	# 4. Select spot-1 driver via real WorldMap/GameUI Area2D click; verify saji & prefix:
	var d1_id := StringName(service.get_driver_views()[0]["driver_id"])
	var d2_id := StringName(service.get_driver_views()[1]["driver_id"])
	_click_canvas_target(ui, world, d1_id)
	_check(
		"clicking in-spot driver Area2D selects driver_id and exposes saji command",
		kitchen.get_selected_target_id() == d1_id
		and kitchen.get_allowed_commands_for_selected_target() == ["saji"]
		and kitchen.get_player_tile() == Vector2i(10, 2)
	)

	# Test live `drivers_changed` signal while another active driver is selected:
	game_root._process(1.0)
	_click_canvas_target(ui, world, &"online_station")
	# Free one concurrent slot at t=1.0 by serving d3 later, or test with earlier expiry first:
	# Re-select d1_id with partial prefix "s" (real expiry/rebind checked below cleanly).
	_cook_loose_sayur(kitchen)
	_click_canvas_target(ui, world, d1_id)
	kitchen.accept_typed_character("s")
	_check(
		"partial prefix s remains active on selected in-spot driver before completion",
		kitchen.get_selected_target_id() == d1_id
		and kitchen.get_command_prefix() == "s"
	)

	# Finish `saji` with loose/unplated sayur -> rejects `wrong_order` without consuming item:
	_type_chars_on_kitchen(kitchen, "aji")
	_check(
		"saji with unplated dish on driver rejects wrong_order cleanly",
		feedbacks[-1] == &"wrong_order"
		and not kitchen.get_held_item_view().is_empty()
		and service.has_driver(d1_id)
		and int(run.get_run_view()["cash"]) == cash_start
	)
	kitchen.on_interactable_clicked(&"trash")

	# Pick up staged empty plate and return it cleanly, then cook plated nasi_telor:
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"plate_rack")
	_cook_plated_nasi_telor(kitchen)
	var held_before_saji := kitchen.get_held_item_view()

	# Click d1_id and type `saji` -> completes delivery, returns plate clean, clears selection:
	_click_canvas_target(ui, world, d1_id)
	_type_chars_on_kitchen(kitchen, "saji")
	_check(
		"typed saji on driver completes delivery, returns plate clean, clears selection",
		feedbacks[-1] == &"order_served"
		and kitchen.get_held_item_view().is_empty()
		and not held_before_saji.is_empty()
		and not service.has_driver(d1_id)
		and kitchen.get_selected_target_id() == &""
		and kitchen.get_command_prefix() == ""
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
		and int(run.get_run_view()["cash"]) == cash_start + 14000
	)

	# Advance +20.0s -> cutoff reached (day_queue_remaining == 2) -> `terima` rejects safely:
	game_root._process(20.0)
	_click_canvas_target(ui, world, &"online_station")
	_type_chars_on_kitchen(kitchen, "terima")
	_check(
		"typed terima after cutoff rejects safely and preserves selection",
		feedbacks[-1] == &"invalid_action"
		and kitchen.get_selected_target_id() == &"online_station"
	)

	# 5. Expiring selected driver clears selection & prefix; unrelated target stays selected:
	_click_canvas_target(ui, world, d2_id)
	_type_chars_on_kitchen(kitchen, "sa")
	_check(
		"d2_id selected with partial prefix sa before expiry",
		kitchen.get_selected_target_id() == d2_id and kitchen.get_command_prefix() == "sa"
	)
	game_root._process(40.0)
	_check(
		"expiring selected driver at t=60 clears selection and stale command prefix",
		not service.has_driver(d2_id)
		and kitchen.get_selected_target_id() == &""
		and kitchen.get_command_prefix() == ""
		and not kitchen.accept_typed_character("j")
	)

	# Rebinding service avoids duplicate signal connections and preserves unrelated target:
	kitchen.on_interactable_clicked(&"stove")
	_type_chars_on_kitchen(kitchen, "go")
	kitchen.bind_service(service)
	kitchen.bind_service(service)
	service.drivers_changed.emit()
	_check(
		"rebinding avoids duplicate signals and preserves unrelated target & prefix",
		kitchen.get_selected_target_id() == &"stove"
		and kitchen.get_command_prefix() == "go"
		and service.drivers_changed.get_connections().filter(
			func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
		).size() == 1
	)

	# Stale driver ID and overflow driver ID reject safely on delivery:
	_cook_plated_nasi_telor(kitchen)
	var extra_dish := StringName(kitchen.get_held_item_view()["item_id"])
	_check(
		"stale and overflow driver IDs cannot be served without consuming dish",
		not service.try_serve_driver(d1_id, extra_dish)
		and not service.try_serve_driver(ov_id, extra_dish)
		and not kitchen.get_held_item_view().is_empty()
	)

	game_root.free()
	await process_frame


func _send_ui_key(ui: GameUI, ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = ch.unicode_at(0)
	ev.keycode = OS.find_keycode_from_string(ch.to_upper())
	ui._unhandled_key_input(ev)


func _type_word_on_ui(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_ui_key(ui, word.substr(i, 1))


func _click_canvas_pos(ui: GameUI, world: WorldMap, world_local_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = world.get_canvas_transform() * world_local_pos
	ui._unhandled_input(ev)


func _test_online_presentation_overflow_and_game_ui() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")

	var preview_planning := world.get_online_preview_visual()
	_check(
		"OnlineStation preview hidden before SERVING starts",
		preview_planning == null or not preview_planning.visible
	)

	_check("M3.3 Day 1 starts service", game_root.start_service_requested())
	var preview_vis := world.get_online_preview_visual()
	var preview_label := (
		preview_vis.get_node_or_null("PreviewLabel") as Label if preview_vis != null else null
	)
	var preview_dish := (
		preview_vis.get_node_or_null("PreviewDish") as Node2D if preview_vis != null else null
	)
	_check(
		"OnlineStation preview visible and full brightness when enabled",
		preview_vis != null
		and preview_vis.visible
		and preview_vis.modulate == Color.WHITE
		and preview_label != null
		and preview_label.text == "Nasi Telor"
		and preview_dish != null
		and preview_dish.get_child_count() > 0
	)

	# Repeated GameUI signal rebinding must not duplicate ServiceController connections:
	ui.bind_context(game_root, world, kitchen, service, run)
	ui.bind_context(game_root, world, kitchen, service, run)
	var offer_conns := service.online_offer_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == ui
	).size()
	var drv_conns := service.drivers_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == ui
	).size()
	_check(
		"repeated bind_context avoids duplicate online_offer_changed and drivers_changed signals",
		offer_conns == 1 and drv_conns == 1
	)

	# Select OnlineStation via canvas click and inspect dialogue + localized terima feedback:
	_click_canvas_target(ui, world, &"online_station")
	_check(
		"OnlineStation dialogue shows preview recipe and ready acceptance status",
		ui.interaction_dialogue.visible
		and ui.target_title_label.text == "Stasiun Online"
		and ui.target_status_label.text == "Tawaran: Nasi Telor (Siap diterima)"
		and ui.allowed_commands_label.text == "terima"
		and ui.prefix_prompt_label.text == "Ketik: terima"
	)

	_type_word_on_ui(ui, "terima")
	_check(
		"online_accepted displays localized Indonesian feedback rather than raw code",
		ui.get_feedback_code() == &"online_accepted"
		and ui.context_message_label.visible
		and ui.context_message_label.text == "Pesanan online diterima!"
		and ui.context_message_label.text != "online_accepted"
	)

	# Accept 2 more in-spot drivers at t=0 (d1..d3 deadline=60.0), then advance 15s and accept d4:
	_type_word_on_ui(ui, "terima")
	_type_word_on_ui(ui, "terima")
	var d1_id := StringName(service.get_driver_views()[0]["driver_id"])
	var d2_id := StringName(service.get_driver_views()[1]["driver_id"])
	var d3_id := StringName(service.get_driver_views()[2]["driver_id"])
	var d1_vis := world.get_driver_visual_node(d1_id)
	var d1_sprite := d1_vis.get_node_or_null("Sprite2D") as Sprite2D if d1_vis != null else null
	var d1_label := d1_vis.get_node_or_null("StatusLabel") as Label if d1_vis != null else null
	var d1_fill := (
		d1_vis.get_node_or_null("TimerBg/TimerFill") as ColorRect if d1_vis != null else null
	)
	_check(
		"in-spot driver visual shows recipe, 60s countdown, full fill bar, and active tint",
		d1_vis != null
		and d1_sprite != null
		and d1_sprite.modulate == Color.WHITE
		and d1_label != null
		and d1_label.text == "Nasi Telor 60s"
		and d1_fill != null
		and is_equal_approx(d1_fill.size.x, 28.0)
	)

	game_root._process(15.0)
	ui._process(0.016)
	_type_word_on_ui(ui, "terima")
	var d4_id := StringName(service.get_driver_views()[3]["driver_id"])
	var d4_vis := world.get_driver_visual_node(d4_id)
	var d4_instance_id := d4_vis.get_instance_id() if d4_vis != null else 0
	var d4_sprite := d4_vis.get_node_or_null("Sprite2D") as Sprite2D if d4_vis != null else null
	var d4_label := d4_vis.get_node_or_null("StatusLabel") as Label if d4_vis != null else null
	_check(
		"cap=4 dims OnlineStation preview cleanly and shows disabled cap reason in dialogue",
		preview_vis.visible
		and preview_vis.modulate != Color.WHITE
		and preview_label.text == "Nasi Telor"
		and ui.target_status_label.text == "Tawaran: Nasi Telor (Penuh: maks 4)"
		and d4_vis != null
		and d4_vis.visible
		and d4_sprite != null
		and d4_sprite.modulate != Color.WHITE
		and d4_label != null
		and d4_label.text == "Antre Nasi Telor 60s"
	)

	# Click overflow driver on canvas -> does not move player, shows overflow dialogue & feedback:
	var player_before_ov := kitchen.get_player_tile()
	_click_canvas_pos(ui, world, d4_vis.global_position)
	_check(
		"clicking overflow driver shows overflow feedback, dialogue status, and blocks saji",
		kitchen.get_player_tile() == player_before_ov
		and kitchen.get_selected_target_id() == d4_id
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and ui.get_feedback_code() == &"driver_not_at_pickup"
		and ui.context_message_label.text == "Pengantar belum mendapatkan tempat pickup."
		and ui.target_title_label.text == "Pengantar Antrean"
		and ui.target_status_label.text == "Pesanan: Nasi Telor (60 dtk) — Di antrean luar"
	)

	# Typing 's' while overflow driver is selected rejects without building prefix:
	_send_ui_key(ui, "s")
	_check(
		"overflow driver rejects typed s and keeps invalid_key feedback",
		kitchen.get_command_prefix() == ""
		and ui.get_feedback_code() == &"invalid_key"
		and ui.context_message_label.text == "Huruf tidak cocok"
	)

	# Re-click overflow driver (so overflow feedback is active) and let t=60s expire d1..d3
	# so d4 promotes IN PLACE while still selected:
	_click_canvas_pos(ui, world, d4_vis.global_position)
	game_root._process(45.0)
	ui._process(0.016)
	var promoted_vis := world.get_driver_visual_node(d4_id)
	var promoted_sprite := (
		promoted_vis.get_node_or_null("Sprite2D") as Sprite2D
		if promoted_vis != null else null
	)
	var promoted_label := (
		promoted_vis.get_node_or_null("StatusLabel") as Label
		if promoted_vis != null else null
	)
	var spot1_node := world.registry.get_object(&"pickup_spot_01")
	_check(
		"expired d1..d3 removed cleanly and selected d4 promoted in-place keeping 15s deadline",
		world.get_driver_visual_node(d1_id) == null
		and world.get_driver_visual_node(d2_id) == null
		and world.get_driver_visual_node(d3_id) == null
		and not world.registry.has_object(d1_id)
		and promoted_vis != null
		and promoted_vis.get_instance_id() == d4_instance_id
		and world.driver_objects.get_child_count() == 1
		and world.registry.has_object(d4_id)
		and spot1_node != null
		and promoted_vis.position == spot1_node.position
		and promoted_sprite != null
		and promoted_sprite.modulate == Color.WHITE
		and promoted_label != null
		and promoted_label.text == "Nasi Telor 15s"
		and kitchen.get_selected_target_id() == d4_id
		and kitchen.get_allowed_commands_for_selected_target() == ["saji"]
		and ui.target_title_label.text == "Pengantar Spot 1"
		and ui.target_status_label.text == "Pesanan: Nasi Telor (15 dtk) — Di tempat pickup"
		and ui.get_feedback_code() != &"driver_not_at_pickup"
	)

	# Clicking promoted driver, typing partial "s", then expiring at t=75 clears target & visual:
	_click_canvas_target(ui, world, d4_id)
	_send_ui_key(ui, "s")
	_check(
		"selected in-spot driver dialogue shows active countdown and s prefix",
		kitchen.get_command_prefix() == "s"
		and ui.target_status_label.text.contains("Di tempat pickup")
	)
	game_root._process(15.0)
	ui._process(0.016)
	_check(
		"expired selected in-spot driver removes visual, registry target, and dialogue",
		not service.has_driver(d4_id)
		and world.get_driver_visual_node(d4_id) == null
		and not world.registry.has_object(d4_id)
		and kitchen.get_selected_target_id() == &""
		and kitchen.get_command_prefix() == ""
		and not ui.interaction_dialogue.visible
	)

	game_root.free()
	await process_frame


func _test_offer_rotation_cutoff_dimming_and_overflow_expiry() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	# Advance cleanly to Day 2 with 0 debt so quota >= 8 allows rotation & overflow:
	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	game_root.start_service_requested()
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_01")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_02")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(25.0)
	ui.continue_button.pressed.emit()

	service.set_rng_seed(98765)
	run.select_daily_menu([&"nasi_telor", &"nasi_ayam"])
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	run.request_ingredient_purchase(&"ayam", 2, &"storage_box")
	run.request_ingredient_purchase(&"tempe", 2, &"storage_box")
	game_root.start_service_requested()

	var preview_vis := world.get_online_preview_visual()
	var preview_label := (
		preview_vis.get_node_or_null("PreviewLabel") as Label if preview_vis != null else null
	)
	var first_recipe := StringName(service.get_online_offer_view()["preview_recipe_id"])

	# Accept offers until the weighted preview rotates to the other recipe, checking live UI sync:
	_click_canvas_target(ui, world, &"online_station")
	var rotated := false
	for _attempt in range(6):
		_type_word_on_ui(ui, "terima")
		if StringName(service.get_online_offer_view()["preview_recipe_id"]) != first_recipe:
			rotated = true
			break
	var rotated_recipe := StringName(service.get_online_offer_view()["preview_recipe_id"])
	var expected_rotated_label := (
		"Nasi Ayam" if rotated_recipe == &"nasi_ayam" else "Nasi Telor"
	)
	_check(
		"OnlineStation preview visual and dialogue update on offer rotation",
		rotated
		and preview_vis.visible
		and preview_label.text == expected_rotated_label
		and ui.target_status_label.text.contains(expected_rotated_label)
	)

	# Ensure 3 in-spot + >=1 overflow driver exist at t=0, click overflow driver & test expiry:
	for _i in range(4):
		if int(service.get_customer_queue_view()["outside_driver_count"]) > 0:
			break
		_type_word_on_ui(ui, "terima")
	var all_drvs := service.get_driver_views()
	var ov_id := StringName(all_drvs[3]["driver_id"]) if all_drvs.size() >= 4 else &""
	var ov_vis := world.get_driver_visual_node(ov_id) if ov_id != &"" else null
	var ov_pos := ov_vis.global_position if ov_vis != null else Vector2.ZERO
	if ov_vis != null:
		_click_canvas_pos(ui, world, ov_pos)
	_check(
		"Day 2 overflow driver selected without moving or exposing saji",
		ov_id != &""
		and kitchen.get_selected_target_id() == ov_id
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and ui.get_feedback_code() == &"driver_not_at_pickup"
	)

	# Advance +20s -> live countdown ticks; advance +40s (t=60s) -> overflow expires cleanly:
	game_root._process(20.0)
	ui._process(0.016)
	var ov_fill := (
		ov_vis.get_node_or_null("TimerBg/TimerFill") as ColorRect if ov_vis != null else null
	)
	_check(
		"driver countdown bar shrinks from ServiceController time while in overflow",
		ov_fill != null
		and ov_fill.size.x < 28.0
		and ov_fill.size.x > 0.0
		and ui.target_status_label.text.contains("40 dtk")
	)
	game_root._process(40.0)
	ui._process(0.016)
	_check(
		"expired overflow driver removes visual, selection, and old clickable target",
		not service.has_driver(ov_id)
		and world.get_driver_visual_node(ov_id) == null
		and kitchen.get_selected_target_id() == &""
		and not ui.interaction_dialogue.visible
		and world.hit_test_overflow_driver(ov_pos) == &""
	)

	# Advance until cutoff is reached (day_queue_remaining <= 2): preview stays visible but dimmed:
	for _tick in range(12):
		if int(service.get_customer_queue_view()["day_queue_remaining"]) <= 2:
			break
		game_root._process(20.0)
	ui._process(0.016)
	_click_canvas_target(ui, world, &"online_station")
	_check(
		"after cutoff OnlineStation keeps preview visible but dimmed and shows cutoff reason",
		preview_vis.visible
		and not preview_label.text.is_empty()
		and preview_vis.modulate != Color.WHITE
		and ui.target_status_label.text.contains("Tutup: kuota <= 2")
	)

	# Start fresh Day 1 service quickly to verify completing a pickup driver removes visual/target
	# AND leaves existing dine-in dialogue untouched:
	game_root.free()
	await process_frame

	var game_root_2 := packed.instantiate() as GameRoot
	root.add_child(game_root_2)
	await process_frame
	await physics_frame

	var kitchen_2 := game_root_2.get_kitchen_controller() as KitchenController
	var service_2 := game_root_2.get_service_controller() as ServiceController
	var run_2 := game_root_2.get_run_controller() as RunController
	var ui_2 := game_root_2.get_node("UI") as GameUI
	var world_2 := game_root_2.get_node("World") as WorldMap

	run_2.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run_2.request_ingredient_purchase(&"telur", 4, &"storage_box")
	game_root_2.start_service_requested()

	_click_canvas_target(ui_2, world_2, &"online_station")
	_type_word_on_ui(ui_2, "terima")
	var spot_drv_id := StringName(service_2.get_driver_views()[0]["driver_id"])
	_cook_plated_nasi_telor(kitchen_2)
	_click_canvas_target(ui_2, world_2, spot_drv_id)
	_type_word_on_ui(ui_2, "saji")
	_check(
		"completed pickup driver removes visual/registry target and shows Pesanan disajikan!",
		not service_2.has_driver(spot_drv_id)
		and world_2.get_driver_visual_node(spot_drv_id) == null
		and not world_2.registry.has_object(spot_drv_id)
		and ui_2.get_feedback_code() == &"order_served"
		and ui_2.context_message_label.text == "Pesanan disajikan!"
	)

	_click_canvas_target(ui_2, world_2, &"dining_table_01")
	_check(
		"existing dine-in table dialogue remains intact alongside M3.3 online changes",
		ui_2.target_title_label.text == "Meja Makan 1"
		and ui_2.context_message_label.text.contains("Nasi Telor")
		and not ui_2.target_status_label.visible
	)

	game_root_2.free()
	await process_frame


func _test_no_pause_modal_overlay_service_clock() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	_check("start service for no-pause modal overlay test", game_root.start_service_requested())
	var dinein_ord_id := StringName(service.get_table_view(&"dining_table_01")["order_id_or_empty"])

	_click_canvas_target(ui, world, &"online_station")
	_type_word_on_ui(ui, "terima")
	var drv_view_0 := service.get_driver_views()[0]
	var drv_id := StringName(drv_view_0["driver_id"])
	var online_ord_id := StringName(drv_view_0["order_id"])
	var drv_vis := world.get_driver_visual_node(drv_id)
	var drv_label := drv_vis.get_node_or_null("StatusLabel") as Label if drv_vis != null else null

	# Activate a visible modal overlay through GameUI without modifying production UI scripts:
	var overlay := PanelContainer.new()
	overlay.name = "TestModalOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.position = Vector2(180, 60)
	overlay.size = Vector2(280, 200)
	ui.ui_root.add_child(overlay)
	ui.set_modal_blocking(true)

	# World clicks & typing must be blocked while the modal overlay is active:
	var player_before := kitchen.get_player_tile()
	_click_canvas_target(ui, world, &"stove")
	_send_ui_key(ui, "t")
	_check(
		"active modal overlay blocks gameplay clicks and typing without leaving online_station",
		ui.is_modal_blocking()
		and kitchen.get_selected_target_id() == &"online_station"
		and kitchen.get_player_tile() == player_before
		and kitchen.get_command_prefix() == ""
		and service.get_driver_views().size() == 1
	)

	# Advance real GameRoot clock +25.0s -> elapsed, deadlines, and driver countdown advance:
	game_root._process(25.0)
	ui._process(0.016)
	var online_rem_25 := float(service.get_order_view(online_ord_id)["seconds_remaining"])
	var dinein_rem_25 := float(service.get_order_view(dinein_ord_id)["seconds_remaining"])
	var drv_rem_25 := float(service.get_driver_view(drv_id)["seconds_remaining"])
	_check(
		"service_elapsed, online/dine-in deadlines, and driver countdown keep ticking under modal",
		is_equal_approx(game_root.get_service_elapsed(), 25.0)
		and ui.service_elapsed_label.text == "Waktu: 25.0 dtk"
		and is_equal_approx(online_rem_25, 35.0)
		and is_equal_approx(drv_rem_25, 35.0)
		and is_equal_approx(dinein_rem_25, 75.0)
		and drv_label != null
		and drv_label.text == "Nasi Telor 35s"
		and ui.is_modal_blocking()
	)

	# Advance to t=60.0s while overlay stays active -> online order & driver expire cleanly:
	game_root._process(35.0)
	ui._process(0.016)
	_click_canvas_target(ui, world, &"storage_box")
	_check(
		"online order expires at 60s under active modal and modal blocking stays intact",
		int(service.get_order_view(online_ord_id)["status"]) == SharedTypes.OrderStatus.FAILED
		and not service.has_driver(drv_id)
		and world.get_driver_visual_node(drv_id) == null
		and kitchen.get_selected_target_id() == &"online_station"
		and kitchen.get_player_tile() == player_before
		and ui.is_modal_blocking()
	)

	# Advance to t=100.0s while overlay stays active -> initial dine-in order expires cleanly too:
	game_root._process(40.0)
	ui._process(0.016)
	_check(
		"dine-in customer order expires at 100s under active modal",
		int(service.get_order_view(dinein_ord_id)["status"]) == SharedTypes.OrderStatus.FAILED
		and ui.is_modal_blocking()
	)

	ui.set_modal_blocking(false)
	overlay.free()
	game_root.free()
	await process_frame


func _test_auto_close_after_final_online_order_expires() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	# Under default 20s spawn / 20s eat / 60s online / cutoff <= 2, Day 1's 4th diner eats
	# until t=80s, after any pre-cutoff 60s online order has already expired. Setting
	# online_deadline_seconds = 95.0 on a duplicated EconomyConfig keeps all dine-in timings
	# unchanged while letting 1 pre-cutoff online order (t=19 -> dl=114s) be the sole order left.
	var cfg := run.economy_config.duplicate(true) as EconomyConfig
	cfg.online_deadline_seconds = 95.0
	run.economy_config = cfg
	service.bind_systems(kitchen, run, game_root)

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	_check("start service for online-expiry auto-close test", game_root.start_service_requested())

	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(19.0)
	_click_canvas_target(ui, world, &"online_station")
	_type_word_on_ui(ui, "terima")
	var online_ord_id := StringName(service.get_driver_views()[0]["order_id"])
	var online_drv_id := StringName(service.get_driver_views()[0]["driver_id"])

	game_root._process(1.0)
	service.try_clean_table(&"dining_table_01")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)
	service.try_clean_table(&"dining_table_02")
	_serve_nasi_telor_table(kitchen, service, &"dining_table_01")
	game_root._process(20.0)
	_serve_nasi_telor_table(kitchen, service, &"dining_table_02")
	game_root._process(20.0)

	var q_wait := service.get_customer_queue_view()
	_check(
		"all diners finished while sole OPEN online order blocks drain and keeps SERVING",
		int(q_wait["day_queue_remaining"]) == 0
		and int(q_wait["outside_dinein_count"]) == 0
		and int(q_wait["in_shop_count"]) == 0
		and int(q_wait["online_open_count"]) == 1
		and not service.is_drained()
		and game_root.get_phase() == SharedTypes.Phase.SERVING
	)

	var transitions: Array[int] = []
	var observed := {"drained_at_closing": false, "expired_status": -1}
	game_root.phase_changed.connect(func(phase: int, _day: int) -> void:
		transitions.append(phase)
		if phase == SharedTypes.Phase.CLOSING:
			observed["drained_at_closing"] = service.is_drained()
	)
	service.orders_changed.connect(func() -> void:
		var ov := service.get_order_view(online_ord_id)
		if not ov.is_empty():
			observed["expired_status"] = int(ov.get("status", -1))
	)

	game_root._process(33.9)
	_check(
		"just before online expiry deadline (t=113.9s) service remains SERVING and undrained",
		int(service.get_order_view(online_ord_id).get("status", -1)) == SharedTypes.OrderStatus.OPEN
		and service.has_driver(online_drv_id)
		and not service.is_drained()
		and game_root.get_phase() == SharedTypes.Phase.SERVING
	)

	# Exact deadline boundary t=114.0s expires online order -> drained -> auto-close once:
	game_root._process(0.1)
	game_root._process(5.0)
	var settle := run.get_day_settlement_view(1)
	var expected_phases: Array[int] = [SharedTypes.Phase.CLOSING, SharedTypes.Phase.RESULTS]
	_check(
		"online order expires at exact deadline t=114.0s and removes driver",
		int(observed["expired_status"]) == SharedTypes.OrderStatus.FAILED
		and not service.has_driver(online_drv_id)
	)
	_check(
		"service becomes drained once at CLOSING and transitions once to RESULTS",
		bool(observed["drained_at_closing"])
		and game_root.get_phase() == SharedTypes.Phase.RESULTS
		and transitions == expected_phases
	)
	_check(
		"Day 1 settlement records 4 dine-in, 0 completed online, 1 failed online, 0 online cash",
		int(settle.get("completed_dinein_count", -1)) == 4
		and int(settle.get("completed_online_count", -1)) == 0
		and int(settle.get("failed_online_count", -1)) == 1
		and int(settle.get("order_revenue_online", -1)) == 0
	)

	game_root.free()
	await process_frame


func _test_typed_online_command_edge_cases() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	game_root.start_service_requested()

	# 1. Select OnlineStation while holding a cooked plated dish and type "saji":
	_cook_plated_nasi_telor(kitchen)
	var held_before := kitchen.get_held_item_view()
	var cash_before := int(run.get_run_view()["cash"])
	var box_before := kitchen.get_storage_unit_view(&"storage_box")
	var rack_before := kitchen.get_plate_rack_view(&"plate_rack")

	_click_canvas_target(ui, world, &"online_station")
	_type_word_on_ui(ui, "saji")
	_check(
		"OnlineStation rejects typed saji without creating orders or mutating hand/cash/stock",
		kitchen.get_selected_target_id() == &"online_station"
		and kitchen.get_allowed_commands_for_selected_target() == ["terima"]
		and kitchen.get_command_prefix() == ""
		and ui.get_feedback_code() == &"invalid_key"
		and service.get_driver_views().is_empty()
		and int(service.get_customer_queue_view()["online_open_count"]) == 0
		and kitchen.get_held_item_view() == held_before
		and int(run.get_run_view()["cash"]) == cash_before
		and kitchen.get_storage_unit_view(&"storage_box") == box_before
		and kitchen.get_plate_rack_view(&"plate_rack") == rack_before
	)

	# 2. Discard held dish so hand is empty, accept an order, select driver, and type "saji":
	_click_canvas_target(ui, world, &"trash")
	_click_canvas_target(ui, world, &"plate_rack")
	_click_canvas_target(ui, world, &"online_station")
	_type_word_on_ui(ui, "terima")
	var drv_view := service.get_driver_views()[0]
	var drv_id := StringName(drv_view["driver_id"])
	var ord_id := StringName(drv_view["order_id"])
	var rack_after_return := kitchen.get_plate_rack_view(&"plate_rack")

	_click_canvas_target(ui, world, drv_id)
	_type_word_on_ui(ui, "saji")
	_check(
		"empty-hand typed saji on in-spot driver rejects invalid_action and preserves order/spot",
		kitchen.get_held_item_view().is_empty()
		and ui.get_feedback_code() == &"invalid_action"
		and ui.context_message_label.text == "Nggak bisa sekarang"
		and int(service.get_order_view(ord_id)["status"]) == SharedTypes.OrderStatus.OPEN
		and service.has_driver(drv_id)
		and StringName(service.get_driver_view(drv_id)["spot_id_or_empty"]) == &"pickup_spot_01"
		and int(run.get_run_view()["cash"]) == cash_before
		and kitchen.get_plate_rack_view(&"plate_rack") == rack_after_return
	)

	game_root.free()
	await process_frame
