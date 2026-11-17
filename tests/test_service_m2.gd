extends SceneTree
## Headless integration and unit tests for Milestone 2: Dine-in Customer Gameplay.

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
	await _test_spawns_queue_and_table_order()
	await _test_weighted_recipe_selection()
	await _test_full_dine_in_serve_eat_clean_wash_and_fifo_loop()
	await _test_wrong_dishes_boundaries_expiry_and_timeout_feedback()
	await _test_eating_drain_blocking_day_transition_and_visual_non_duplication()
	await _test_overflow_beyond_four_anchors_and_seated_timeout_visual()
	await _test_catchup_tick_and_outside_queue_expiry()
	await _test_credit_order_failure_diagnostic()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _send_key(ui: GameUI, keycode: int, unicode_char: int = -1) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = keycode as Key
	ev.physical_keycode = keycode as Key
	ev.unicode = keycode if unicode_char < 0 else unicode_char
	ui._unhandled_key_input(ev)


func _select_world_target(ui: GameUI, world: WorldMap, target_id: StringName) -> void:
	var node := world.registry.get_object(target_id)
	if node == null:
		return
	var canvas_pos := world.get_canvas_transform() * node.global_position
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = canvas_pos
	ui._unhandled_input(ev)


func _cook_plated_nasi_telor(ui: GameUI, world: WorldMap) -> void:
	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "beras")
	_select_world_target(ui, world, &"washer")
	_type_word(ui, "cuci")
	_select_world_target(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	_select_world_target(ui, world, &"plate_rack")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_select_world_target(ui, world, &"stove")
	_type_word(ui, "goreng")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"work_table_stage")


func _cook_plated_nasi_ayam(ui: GameUI, world: WorldMap) -> void:
	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "beras")
	_select_world_target(ui, world, &"washer")
	_type_word(ui, "cuci")
	_select_world_target(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	_select_world_target(ui, world, &"plate_rack")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "ayam")
	_select_world_target(ui, world, &"stove")
	_type_word(ui, "goreng")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "tempe")
	_select_world_target(ui, world, &"stove")
	_type_word(ui, "goreng")
	_select_world_target(ui, world, &"work_table_stage")
	_select_world_target(ui, world, &"work_table_stage")


func _test_spawns_queue_and_table_order() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var service := game_root.get_service_controller() as ServiceController
	var world := game_root.get_node("World") as WorldMap

	_check("day 1 starts service cleanly", game_root.start_service_requested())
	var q0 := service.get_customer_queue_view()
	var t1 := service.get_table_view(&"dining_table_01")
	var t2 := service.get_table_view(&"dining_table_02")
	var custs0 := service.get_customer_views()
	_check(
		"t=0 spawns Customer 1 into lowest CLEAN_VACANT table dining_table_01",
		int(q0["day_queue_remaining"]) == 3
		and int(q0["in_shop_count"]) == 1
		and int(q0["outside_dinein_count"]) == 0
		and int(t1["state"]) == SharedTypes.TableState.OCCUPIED_WAITING
		and int(t2["state"]) == SharedTypes.TableState.CLEAN_VACANT
		and custs0.size() == 1
		and StringName(custs0[0]["assigned_table_id"]) == &"dining_table_01"
	)

	var o1 := service.get_order_view(StringName(t1["order_id_or_empty"]))
	_check(
		"Customer 1 order has nasi_telor, created_at=0, deadline_at=100",
		StringName(o1["recipe_id"]) == &"nasi_telor"
		and is_equal_approx(float(o1["created_at"]), 0.0)
		and is_equal_approx(float(o1["deadline_at"]), 100.0)
		and int(o1["status"]) == SharedTypes.OrderStatus.OPEN
	)

	game_root._process(19.9)
	_check(
		"before 20.0s no second customer spawns",
		int(service.get_customer_queue_view()["day_queue_remaining"]) == 3
		and service.get_customer_views().size() == 1
	)

	game_root._process(0.1)
	var q1 := service.get_customer_queue_view()
	t2 = service.get_table_view(&"dining_table_02")
	_check(
		"at t=20.0s Customer 2 spawns and seats at dining_table_02",
		int(q1["day_queue_remaining"]) == 2
		and int(q1["in_shop_count"]) == 2
		and int(t2["state"]) == SharedTypes.TableState.OCCUPIED_WAITING
	)

	game_root._process(20.0)
	var q2 := service.get_customer_queue_view()
	_check(
		"at t=40.0s with both tables full Customer 3 waits in outside FIFO",
		int(q2["day_queue_remaining"]) == 1
		and int(q2["in_shop_count"]) == 2
		and int(q2["outside_dinein_count"]) == 1
	)

	game_root._process(20.0)
	var q3 := service.get_customer_queue_view()
	var custs3 := service.get_customer_views()
	var outside_vis_0: Node2D = null
	var outside_vis_1: Node2D = null
	for cv: Dictionary in custs3:
		if int(cv["queue_index"]) == 0:
			outside_vis_0 = world.get_customer_visual_node(StringName(cv["customer_id"]))
		elif int(cv["queue_index"]) == 1:
			outside_vis_1 = world.get_customer_visual_node(StringName(cv["customer_id"]))

	var a1 := world.registry.get_object(&"dine_in_wait_01")
	var a2 := world.registry.get_object(&"dine_in_wait_02")
	_check(
		"at t=60.0s quota exhausted into outside FIFO and visuals sit at WaitingAnchors",
		int(q3["day_queue_remaining"]) == 0
		and int(q3["outside_dinein_count"]) == 2
		and outside_vis_0 != null
		and outside_vis_1 != null
		and outside_vis_0.global_position.is_equal_approx(a1.global_position)
		and outside_vis_1.global_position.is_equal_approx(a2.global_position)
		and not service.is_drained()
	)

	var spr0 := outside_vis_0.get_node_or_null("Sprite2D") as Sprite2D
	var lbl0 := outside_vis_0.get_node_or_null("StatusLabel") as Label
	var fill0 := outside_vis_0.get_node_or_null("TimerBg/TimerFill") as ColorRect
	_check(
		"customer visual uses nearest texture filter and MOUSE_FILTER_IGNORE overlays",
		spr0 != null
		and spr0.texture != null
		and spr0.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and lbl0 != null
		and lbl0.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and fill0 != null
		and fill0.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and not world.registry.has_object(StringName(outside_vis_0.name))
	)

	game_root.free()
	await process_frame


func _test_weighted_recipe_selection() -> void:
	var service := ServiceController.new()
	service.register_table(&"dining_table_01")
	service.set_rng_seed(20261117)
	service.prepare_service_day(2, {
		"day_queue_initial": 120,
		"selected_recipe_ids": [&"nasi_telor", &"nasi_ayam"],
		"dine_in_price_by_recipe": {
			&"nasi_telor": 10000,
			&"nasi_ayam": 40000,
		},
		"installed_table_ids": [&"dining_table_01"],
	})
	service.begin_service(0.0)
	service.advance_service_time(2400.0)

	var counts := {
		&"nasi_telor": 0,
		&"nasi_ayam": 0,
	}
	for i in range(1, 121):
		var order_view := service.get_order_view(StringName("ord_d2_%03d" % i))
		var rid := StringName(order_view.get("recipe_id", &""))
		counts[rid] = int(counts.get(rid, 0)) + 1

	_check(
		"weighted selection chooses cheaper recipe (10k vs 40k -> 4:1 ratio) reliably",
		int(counts[&"nasi_telor"]) > int(counts[&"nasi_ayam"]) * 2
		and int(counts[&"nasi_ayam"]) > 0
	)
	service.free()
	await process_frame


func _test_full_dine_in_serve_eat_clean_wash_and_fifo_loop() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	run.request_ingredient_purchase(&"beras", 4, &"storage_box")
	run.request_ingredient_purchase(&"telur", 4, &"storage_box")
	run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
	var cash_after_stock := int(run.get_run_view()["cash"])

	_check("start service for full M2 gameplay loop", game_root.start_service_requested())
	_check(
		"table actions saji/bersihkan blocked safely on CLEAN_VACANT before dirty",
		not service.try_clean_table(&"dining_table_02")
		and not service.try_serve_table(&"dining_table_02", &"fake_item")
	)

	# Advance to t=45 so Customer 1 & 2 are seated and Customer 3 is in outside FIFO.
	game_root._process(45.0)
	ui._process(0.016)
	var t1_view := service.get_table_view(&"dining_table_01")
	var c1_id := StringName(t1_view["customer_id_or_empty"])
	var o1_id := StringName(t1_view["order_id_or_empty"])

	_select_world_target(ui, world, &"dining_table_01")
	_check(
		"selecting OCCUPIED_WAITING dining_table_01 shows order prompt & timer",
		ui.interaction_dialogue.visible
		and ui.target_title_label.text == "Meja Makan 1"
		and ui.context_message_label.text.contains("Nasi Telor")
		and ui.allowed_commands_label.text.contains("saji")
	)

	_type_word(ui, "bersihkan")
	_check(
		"bersihkan on OCCUPIED_WAITING table rejected with invalid_action",
		ui.get_feedback_code() == &"invalid_action"
		and int(service.get_table_view(&"dining_table_01")["state"])
		== SharedTypes.TableState.OCCUPIED_WAITING
	)

	_select_world_target(ui, world, &"storage_box")
	_type_word(ui, "sayur")
	_select_world_target(ui, world, &"stove")
	_type_word(ui, "goreng")
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check(
		"saji with non-matching dish emits wrong_order, keeps item, and does not pay",
		ui.get_feedback_code() == &"wrong_order"
		and not kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view()["cash"]) == cash_after_stock
		and int(service.get_order_view(o1_id)["status"]) == SharedTypes.OrderStatus.OPEN
	)
	_select_world_target(ui, world, &"trash")

	_cook_plated_nasi_telor(ui, world)
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")

	t1_view = service.get_table_view(&"dining_table_01")
	var o1_after := service.get_order_view(o1_id)
	_check(
		"saji valid nasi_telor commits once, pays 20000, consumes hand, starts 20s eat",
		ui.get_feedback_code() == &"order_served"
		and kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view()["cash"]) == cash_after_stock + 20000
		and int(o1_after["status"]) == SharedTypes.OrderStatus.COMPLETED
		and int(t1_view["state"]) == SharedTypes.TableState.OCCUPIED_EATING
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 3
		and kitchen.get_plate_count() == 4
	)

	# Second nasi_telor served to same table while OCCUPIED_EATING must reject cleanly.
	_cook_plated_nasi_telor(ui, world)
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check(
		"duplicate UI saji during OCCUPIED_EATING rejects without consuming dish or double-paying",
		ui.get_feedback_code() == &"invalid_action"
		and not kitchen.get_held_item_view().is_empty()
		and StringName(kitchen.get_held_item_view()["matched_recipe_id"]) == &"nasi_telor"
		and int(run.get_run_view()["cash"]) == cash_after_stock + 20000
		and not run.credit_order_once(o1_id, &"nasi_telor", SharedTypes.OrderKind.DINE_IN)
		and world.registry.get_object(&"dining_table_01").get_node("TablePlateVisual").visible
	)
	_select_world_target(ui, world, &"trash")
	_select_world_target(ui, world, &"plate_rack")

	game_root._process(19.9)
	ui._process(0.016)
	_check(
		"at +19.9s (t=64.9) Customer 1 still EATING and Customer 3 still outside",
		int(service.get_table_view(&"dining_table_01")["state"])
		== SharedTypes.TableState.OCCUPIED_EATING
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 2
	)

	game_root._process(0.1)
	ui._process(0.016)
	var t1_dirty := service.get_table_view(&"dining_table_01")
	var dirty_vis := world.registry.get_object(&"dining_table_01").get_node_or_null(
		"TableDirtyVisual"
	) as Node2D
	_check(
		"at t=65.0s Customer 1 LEFT, dining_table_01 DIRTY, dirty blocks FIFO seating",
		int(t1_dirty["state"]) == SharedTypes.TableState.DIRTY
		and StringName(t1_dirty["customer_id_or_empty"]) == &""
		and world.get_customer_visual_node(c1_id) == null
		and dirty_vis != null
		and dirty_vis.visible
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 2
	)

	game_root._process(10.0)
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "bersihkan")

	var t1_reoccupied := service.get_table_view(&"dining_table_01")
	var c3_id := StringName(t1_reoccupied["customer_id_or_empty"])
	var o3_view := service.get_order_view(StringName(t1_reoccupied["order_id_or_empty"]))
	var c3_vis := world.get_customer_visual_node(c3_id)
	var table1_node := world.registry.get_object(&"dining_table_01")
	var expected_seated_pos := world.dine_in_waiting_anchors.to_local(
		table1_node.global_position
	) + Vector2(0, -12)
	_check(
		"bersihkan sends plate to washer, clears dirty visual, seats C3 with deadline",
		ui.get_feedback_code() == &"table_cleaned"
		and int(kitchen.get_washer_view()["dirty_plate_count"]) == 1
		and kitchen.get_plate_count() == 4
		and not dirty_vis.visible
		and int(t1_reoccupied["state"]) == SharedTypes.TableState.OCCUPIED_WAITING
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 1
		and is_equal_approx(float(o3_view["deadline_at"]), 140.0)
		and is_equal_approx(float(o3_view["seconds_remaining"]), 65.0)
		and c3_vis != null
		and c3_vis.position.is_equal_approx(expected_seated_pos)
	)

	_select_world_target(ui, world, &"washer")
	_type_word(ui, "cuci")
	_check(
		"washed dirty dining plate returns to clean held plate without losing total plate count",
		not kitchen.get_held_item_view().is_empty()
		and kitchen.get_held_item_view().get("plate_id", &"") != &""
		and int(kitchen.get_washer_view()["dirty_plate_count"]) == 0
		and kitchen.get_plate_count() == 4
	)

	game_root.free()
	await process_frame


func _test_wrong_dishes_boundaries_expiry_and_timeout_feedback() -> void:
	# 1. Exact deadline_at == now tie-break on public ServiceController API:
	var s1 := ServiceController.new()
	s1.register_table(&"dining_table_01")
	s1.prepare_service_day(1, {
		"day_queue_initial": 1,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01"],
	})
	s1.begin_service(0.0)
	s1.advance_service_time(100.0)
	_check(
		"at exact t=100.0s deadline order fails cleanly and try_serve_table rejects",
		int(s1.get_order_view(&"ord_d1_001")["status"]) == SharedTypes.OrderStatus.FAILED
		and not s1.try_serve_table(&"dining_table_01", &"any_item")
		and int(s1.get_table_view(&"dining_table_01")["state"])
		== SharedTypes.TableState.CLEAN_VACANT
		and s1.is_drained()
	)
	s1.free()

	# 2. Same-tick expiry + outside waiter promotion feedback via real UI saji typing:
	# White-box note: sets `game_root._service_elapsed = 100.0` before calling UI `saji` because
	# live `_process(delta)` ticks `advance_service_time()` on the same frame as the clock;
	# this exercises `try_serve_table()`'s lazy `_sync_service_now_from_clock()` boundary path.
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	game_root.start_service_requested()
	_cook_plated_nasi_telor(ui, world)
	var cash_before_timeout := int(run.get_run_view()["cash"])

	# Advance to t=99.9s (Customer 1 OPEN, Customer 3 & 4 waiting outside), then cross to 100.0s:
	game_root._process(99.9)
	game_root._service_elapsed = 100.0
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check(
		"same-tick timeout during saji with FIFO promotion emits order_expired, not wrong_order",
		ui.get_feedback_code() == &"order_expired"
		and ui.context_message_label.text == "Waktu pesanan habis"
		and not kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view()["cash"]) == cash_before_timeout
		and int(service.get_order_view(&"ord_d1_001")["status"]) == SharedTypes.OrderStatus.FAILED
		and StringName(service.get_table_view(&"dining_table_01")["customer_id_or_empty"])
		== &"cust_d1_003"
	)

	# Drain to RESULTS cleanly and check demand_penalty_debt bounds & phase rejection:
	game_root._process(60.0)
	_check(
		"service auto-closes cleanly to RESULTS after remaining customers expire",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and not service.try_serve_table(&"dining_table_01", &"x")
		and not service.try_clean_table(&"dining_table_01")
	)
	var debt := int(run.get_run_view()["demand_penalty_debt"])
	_check(
		"Day 1 settlement records 4 failed dine-in orders -> demand_penalty_debt in [4, 8]",
		int(run.get_day_settlement_view(1)["failed_dinein_count"]) == 4
		and debt >= 4
		and debt <= 8
	)

	game_root.free()
	await process_frame

	# 3. Separate run with 3 storage slots (beras, ayam, tempe) assembling real nasi_ayam:
	var g_wrong := packed.instantiate() as GameRoot
	root.add_child(g_wrong)
	await process_frame
	var k_w := g_wrong.get_kitchen_controller() as KitchenController
	var r_w := g_wrong.get_run_controller() as RunController
	var u_w := g_wrong.get_node("UI") as GameUI
	var w_w := g_wrong.get_node("World") as WorldMap

	r_w.request_ingredient_purchase(&"beras", 1, &"storage_box")
	r_w.request_ingredient_purchase(&"ayam", 1, &"storage_box")
	r_w.request_ingredient_purchase(&"tempe", 1, &"storage_box")
	var cash_wrong := int(r_w.get_run_view()["cash"])
	g_wrong.start_service_requested()
	_cook_plated_nasi_ayam(u_w, w_w)
	_check(
		"assembled real nasi_ayam in hand via kitchen stations",
		StringName(k_w.get_held_item_view().get("matched_recipe_id", &"")) == &"nasi_ayam"
	)
	_select_world_target(u_w, w_w, &"dining_table_01")
	_type_word(u_w, "saji")
	_check(
		"plated wrong recipe (nasi_ayam) rejected for nasi_telor order without consuming item",
		u_w.get_feedback_code() == &"wrong_order"
		and StringName(k_w.get_held_item_view().get("matched_recipe_id", &"")) == &"nasi_ayam"
		and int(r_w.get_run_view()["cash"]) == cash_wrong
	)

	g_wrong.free()
	await process_frame


func _test_eating_drain_blocking_day_transition_and_visual_non_duplication() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	game_root.get_run_controller().request_ingredient_purchase(&"beras", 2, &"storage_box")
	game_root.get_run_controller().request_ingredient_purchase(&"telur", 2, &"storage_box")
	game_root.start_service_requested()

	# Cook nasi_telor, advance to t=145s so C1..C3 expired (C3 at t=140) and ONLY C4 (dl=160)
	# remains seated at dining_table_01, then serve C4 at t=145 (eat_until = 165.0):
	_cook_plated_nasi_telor(ui, world)
	game_root._process(145.0)
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	ui._process(0.016)

	var customer_views := service.get_customer_views()
	var table_views: Array[Dictionary] = [
		service.get_table_view(&"dining_table_01"),
		service.get_table_view(&"dining_table_02"),
	]
	var anchor_children_before := world.dine_in_waiting_anchors.get_child_count()
	var t1_node := world.registry.get_object(&"dining_table_01")
	var t1_children_before := t1_node.get_child_count()
	world.sync_dine_in_visuals(customer_views, table_views, {})
	world.sync_dine_in_visuals(customer_views, table_views, {})
	_check(
		"repeated sync_dine_in_visuals() calls do not duplicate customer or table nodes",
		world.dine_in_waiting_anchors.get_child_count() == anchor_children_before
		and t1_node.get_child_count() == t1_children_before
	)

	# All quotas/OPEN orders are gone, ONLY C4 is OCCUPIED_EATING for 20s: must NOT drain yet!
	game_root._process(19.9)
	_check(
		"closing stays blocked while only customer is OCCUPIED_EATING (19.9s elapsed)",
		game_root.get_phase() == SharedTypes.Phase.SERVING
		and not service.is_drained()
		and int(service.get_customer_queue_view()["in_shop_count"]) == 1
	)

	# Remaining 0.1s finishes eating -> C4 leaves, table dirty -> auto-closes to RESULTS,
	# resetting customer visuals, dirty/plate overlays, AND plate table_id metadata!
	game_root._process(0.1)
	var plate_vis := t1_node.get_node_or_null("TablePlateVisual") as Node2D
	var dirty_vis := t1_node.get_node_or_null("TableDirtyVisual") as Node2D
	var all_plates_clean_at_rack := true
	for plate: Dictionary in kitchen._plate_records.values():
		if plate.get("location", &"") != &"RACK" or plate.get("table_id", &"") != &"":
			all_plates_clean_at_rack = false

	_check(
		"service closes after eating ends, removing visuals & resetting plate table_id metadata",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and world.get_customer_visual_node(&"cust_d1_004") == null
		and world.dine_in_waiting_anchors.get_child_count() == 4
		and (plate_vis == null or not plate_vis.visible)
		and (dirty_vis == null or not dirty_vis.visible)
		and all_plates_clean_at_rack
	)

	# Advance to Day 2 via Continue and Start Service -> clean fresh visuals, no Day 1 leftovers:
	ui.continue_button.pressed.emit()
	ui.start_service_button.pressed.emit()
	_check(
		"Day 2 starts cleanly with fresh Customer 1 visual and no stale Day 1 nodes",
		game_root.get_phase() == SharedTypes.Phase.SERVING
		and game_root.get_day_index() == 2
		and world.get_customer_visual_node(&"cust_d2_001") != null
		and world.get_customer_visual_node(&"cust_d1_004") == null
	)

	game_root.free()
	await process_frame


func _test_overflow_beyond_four_anchors_and_seated_timeout_visual() -> void:
	# 1. Seated customer timeout removes visual cleanly with NO dirty plate:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame

	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	game_root.start_service_requested()
	service.prepare_service_day(1, {
		"day_queue_initial": 1,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01", &"dining_table_02"],
	})
	service.begin_service(0.0)
	var seated_vis := world.get_customer_visual_node(&"cust_d1_001")
	_check("seated customer visual created at start", seated_vis != null)

	game_root._process(100.0)
	ui._process(0.016)
	var t1_node := world.registry.get_object(&"dining_table_01")
	var dirty_vis := t1_node.get_node_or_null("TableDirtyVisual") as Node2D
	var plate_vis := t1_node.get_node_or_null("TablePlateVisual") as Node2D
	_check(
		"seated customer timeout removes visual and leaves table CLEAN_VACANT without dirty plate",
		world.get_customer_visual_node(&"cust_d1_001") == null
		and int(service.get_table_view(&"dining_table_01")["state"])
		== SharedTypes.TableState.CLEAN_VACANT
		and (dirty_vis == null or not dirty_vis.visible)
		and (plate_vis == null or not plate_vis.visible)
	)

	# 2. Outside queue overflow beyond 4 waiting anchors (8 arrivals -> 2 seated + 6 outside):
	# Configure 10s spawn interval so 8 customers arrive before C1 expires at t=100.
	var fast_cfg := EconomyConfig.new()
	fast_cfg.diner_spawn_interval_seconds = 10.0
	fast_cfg.diner_patience_seconds = 100.0
	service._economy_config = fast_cfg
	service.prepare_service_day(3, {
		"day_queue_initial": 8,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01", &"dining_table_02"],
	})
	service.begin_service(0.0)
	service.advance_service_time(70.0)
	# Spawns at 0,10,20,30,40,50,60,70 -> C1 & C2 seated, C3..C8 (6 waiters!) outside!
	world.sync_dine_in_visuals(service.get_customer_views(), [
		service.get_table_view(&"dining_table_01"),
		service.get_table_view(&"dining_table_02"),
	], {})
	var vis_q4 := world.get_customer_visual_node(&"cust_d3_007")
	var vis_q5 := world.get_customer_visual_node(&"cust_d3_008")
	var anchor4 := world.registry.get_object(&"dine_in_wait_04")
	var expected_q4 := anchor4.global_position + WorldMap.CUSTOMER_OVERFLOW_STEP * 1.0
	var expected_q5 := anchor4.global_position + WorldMap.CUSTOMER_OVERFLOW_STEP * 2.0
	_check(
		"6 outside waiters overflow past 4th anchor along CUSTOMER_OVERFLOW_STEP",
		int(service.get_customer_queue_view()["outside_dinein_count"]) == 6
		and vis_q4 != null
		and vis_q5 != null
		and vis_q4.global_position.is_equal_approx(expected_q4)
		and vis_q5.global_position.is_equal_approx(expected_q5)
	)

	# Expire C1 & C2 at t=100 & t=110 -> C3 (idx 0) then C4 (idx 1) admit in exact FIFO order!
	service.advance_service_time(100.0)
	_check(
		"FIFO admission seats cust_d3_003 then cust_d3_004 when tables free sequentially",
		StringName(service.get_table_view(&"dining_table_01")["customer_id_or_empty"])
		== &"cust_d3_003"
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 5
	)
	service.advance_service_time(110.0)
	_check(
		"second FIFO waiter cust_d3_004 admitted when dining_table_02 frees at t=110",
		StringName(service.get_table_view(&"dining_table_02")["customer_id_or_empty"])
		== &"cust_d3_004"
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 4
	)

	game_root.free()
	await process_frame


func _test_catchup_tick_and_outside_queue_expiry() -> void:
	var service := ServiceController.new()
	service.register_table(&"dining_table_01")
	service.prepare_service_day(1, {
		"day_queue_initial": 3,
		"selected_recipe_ids": [&"nasi_telor"],
		"dine_in_price_by_recipe": {&"nasi_telor": 20000},
		"installed_table_ids": [&"dining_table_01"],
	})
	service.begin_service(0.0)
	service.advance_service_time(110.0)

	var t1 := service.get_table_view(&"dining_table_01")
	var seated_order := service.get_order_view(StringName(t1["order_id_or_empty"]))
	var q_view := service.get_customer_queue_view()
	_check(
		"catch-up frame spawns on schedule and promotes outside FIFO keeping deadline",
		int(q_view["day_queue_remaining"]) == 0
		and int(q_view["outside_dinein_count"]) == 1
		and int(q_view["in_shop_count"]) == 1
		and StringName(t1["customer_id_or_empty"]) == &"cust_d1_002"
		and is_equal_approx(float(seated_order["deadline_at"]), 120.0)
		and is_equal_approx(float(seated_order["seconds_remaining"]), 10.0)
	)

	service.advance_service_time(120.0)
	var t1_b := service.get_table_view(&"dining_table_01")
	var seated_order_3 := service.get_order_view(StringName(t1_b["order_id_or_empty"]))
	_check(
		"at t=120 Customer 2 expires cleanly and Customer 3 seats with deadline=140 (20s left)",
		StringName(t1_b["customer_id_or_empty"]) == &"cust_d1_003"
		and int(service.get_customer_queue_view()["outside_dinein_count"]) == 0
		and is_equal_approx(float(seated_order_3["deadline_at"]), 140.0)
		and is_equal_approx(float(seated_order_3["seconds_remaining"]), 20.0)
		and not service.is_drained()
	)

	# Outside queue waiter expiring while both tables stay DIRTY (via real serve + 20s eat):
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var g2 := packed.instantiate() as GameRoot
	root.add_child(g2)
	await process_frame
	var s2 := g2.get_service_controller() as ServiceController
	var r2 := g2.get_run_controller() as RunController
	var u2 := g2.get_node("UI") as GameUI
	var w2 := g2.get_node("World") as WorldMap
	r2.request_ingredient_purchase(&"beras", 2, &"storage_box")
	r2.request_ingredient_purchase(&"telur", 2, &"storage_box")
	g2.start_service_requested()

	# Serve C1 at t=0 (eat_until=20), step 20s -> C2 seats & C1 leaves dining_table_01 DIRTY:
	_cook_plated_nasi_telor(u2, w2)
	_select_world_target(u2, w2, &"dining_table_01")
	_type_word(u2, "saji")
	g2._process(20.0)
	# Serve C2 at t=20 (eat_until=40), step 20s -> dining_table_02 DIRTY, C3 outside:
	_cook_plated_nasi_telor(u2, w2)
	_select_world_target(u2, w2, &"dining_table_02")
	_type_word(u2, "saji")
	g2._process(20.0)

	_check(
		"Customer 3 waits in outside FIFO while both tables are DIRTY",
		int(s2.get_table_view(&"dining_table_01")["state"]) == SharedTypes.TableState.DIRTY
		and int(s2.get_table_view(&"dining_table_02")["state"]) == SharedTypes.TableState.DIRTY
		and int(s2.get_customer_queue_view()["outside_dinein_count"]) == 1
	)
	# Advance 100s to t=140.0 -> C3 expires while C4 (t=60, OPEN) still waits outside:
	g2._process(100.0)
	_check(
		"outside FIFO waiter C3 expires at t=140 while both tables remain DIRTY",
		int(s2.get_order_view(&"ord_d1_003")["status"]) == SharedTypes.OrderStatus.FAILED
		and int(s2.get_order_view(&"ord_d1_004")["status"]) == SharedTypes.OrderStatus.OPEN
		and int(s2.get_customer_queue_view()["outside_dinein_count"]) == 1
		and int(s2.get_table_view(&"dining_table_01")["state"]) == SharedTypes.TableState.DIRTY
		and int(s2.get_table_view(&"dining_table_02")["state"]) == SharedTypes.TableState.DIRTY
	)
	# Advance 20s to t=160.0 -> C4 expires cleanly and Day 1 closes to RESULTS (2 failed, 2 ok):
	g2._process(20.0)
	var s2_settle := r2.get_day_settlement_view(1)
	_check(
		"final outside FIFO waiter expires at t=160 without seating and drains day",
		int(s2_settle.get("completed_dinein_count", -1)) == 2
		and int(s2_settle.get("failed_dinein_count", -1)) == 2
		and int(s2.get_customer_queue_view()["outside_dinein_count"]) == 0
		and g2.get_phase() == SharedTypes.Phase.RESULTS
	)

	service.free()
	g2.free()
	await process_frame


func _test_credit_order_failure_diagnostic() -> void:
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
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	failing_run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	failing_run.request_ingredient_purchase(&"telur", 1, &"storage_box")
	game_root.start_service_requested()
	_cook_plated_nasi_telor(ui, world)
	_select_world_target(ui, world, &"dining_table_01")
	_type_word(ui, "saji")

	_check(
		"unexpected credit_order_once rejection flags developer invariant diagnostic cleanly",
		failing_run.calls == 1
		and kitchen.get_held_item_view().is_empty()
		and int(service.get_order_view(&"ord_d1_001")["status"])
		== SharedTypes.OrderStatus.COMPLETED
		and service._last_invariant_error.contains("ord_d1_001")
		and service._last_invariant_error.contains("nasi_telor")
	)

	game_root.free()
	await process_frame
