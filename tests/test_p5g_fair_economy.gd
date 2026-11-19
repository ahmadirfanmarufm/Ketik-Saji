extends SceneTree
## P5-G2A Chronological Action-Timing Fair Seven-Day Economic Simulation Matrix.
## Does not modify production gameplay logic or EconomyConfig tuning.

const TICK_STEP := 0.25
const DEFAULT_NOISE_SEED := 20261119

## Bot action duration assumptions (seconds), executed BEFORE each corresponding effect:
const DUR_WASHER_CUCI := 0.75
const DUR_PLATE_RACK_RETURN := 0.25
const DUR_DIRTY_TABLE_CLEAN := 0.75
const DUR_ONLINE_ACCEPT := 0.50
const DUR_RICE_CUCI := 1.50
const DUR_RICE_MASAK := 1.50
## Plate + cooked rice sub-steps total 2.00s (preserving P5-G 2.00s assumption):
const DUR_TAKE_PLATE := 0.50
const DUR_STAGE_PLATE := 0.50
const DUR_SCOOP_RICE := 0.50
const DUR_MERGE_RICE := 0.50
const DUR_TAKE_INGREDIENT := 0.50
const DUR_CHOP_POTONG := 1.50
const DUR_COOK_GORENG := 1.50
const DUR_CHOP_BEFORE_COOK := 1.00
const DUR_STAGE_COMPONENT := 0.50
const DUR_PICKUP_PLATED := 0.50
const DUR_SERVE_SAJI := 1.00
const DUR_TRASH_CLEANUP := 0.50
## Test-only ingredient shop interaction timing assumptions (not calibrated human telemetry):
## - Open Belanja via target click + typed `beli` matches single-station `cuci`/`bersihkan` (0.75s)
## - Clicking `+` per ingredient unit takes 1 quantized tick (0.25s)
## - Clicking `Beli` checkout matches single confirmation `terima` (0.50s); `Batal` cancel (0.25s)
const DUR_SHOP_OPEN := 0.75
const DUR_SHOP_ADJUST_UNIT := 0.25
const DUR_SHOP_CHECKOUT := 0.50
const DUR_SHOP_CANCEL := 0.25

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_chronological_timing_and_expiry_contracts()
	await _test_chronological_shop_contracts()
	await _test_lifecycle_metrics_and_classification()
	await _run_p5g_fair_matrix()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _test_chronological_timing_and_expiry_contracts() -> void:
	# 1. Verify action clock advances BEFORE kitchen action executes, and successful serve works
	# once without duplicate payment when sufficient time remains.
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	_check("P5-G2A start Day 1 for chronological prep test", game_root.start_service_requested())

	var tracker := _make_offer_tracker()
	var cook_started_at := game_root.get_service_elapsed()
	var cmd_log: Array[Dictionary] = []
	kitchen.command_executed.connect(func(cmd: StringName, target_id: StringName) -> void:
		cmd_log.append({
			"cmd": cmd,
			"target_id": target_id,
			"at": game_root.get_service_elapsed(),
		})
	)
	var d1_table_order := StringName(service.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var serve_res := _cook_and_serve_chronological(
		game_root,
		kitchen,
		service,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": &"dining_table_01",
			"order_id": d1_table_order,
			"recipe_id": &"nasi_telor",
		},
		tracker,
		0.0
	)
	var serve_finished_at := game_root.get_service_elapsed()
	var cash_after_serve := int(run.get_run_view()["cash"])
	var dup_ok := service.try_serve_table(&"dining_table_01", &"fake_item")
	var tv_after := service.get_table_view(&"dining_table_01")
	var saji_at := -1.0
	var cuci_at := -1.0
	var masak_at := -1.0
	var nasi_at := -1.0
	for entry in cmd_log:
		if entry["cmd"] == &"cuci":
			cuci_at = float(entry["at"])
		elif entry["cmd"] == &"masak":
			masak_at = float(entry["at"])
		elif entry["cmd"] == &"nasi":
			nasi_at = float(entry["at"])
		elif entry["cmd"] == &"saji":
			saji_at = float(entry["at"])
	_check(
		"P5-G2A prep advances clock before each action & completes dine-in once without dup pay",
		bool(serve_res["served"])
		and not bool(serve_res["expired_mid_prep"])
		and serve_started_at(cook_started_at, serve_finished_at)
		and is_equal_approx(cuci_at - cook_started_at, 1.5)
		and is_equal_approx(masak_at - cook_started_at, 3.0)
		and is_equal_approx(nasi_at - cook_started_at, 4.5)
		and is_equal_approx(saji_at - cook_started_at, 9.0)
		and is_equal_approx(serve_finished_at - cook_started_at, 9.0)
		and int(tv_after.get("state", -1)) == SharedTypes.TableState.OCCUPIED_EATING
		and cash_after_serve == 100000 - 4000 - 6000 + 20000
		and not dup_ok
		and int(run.get_run_view()["cash"]) == cash_after_serve
	)

	game_root.free()
	await process_frame

	# 2. Dine-in order expiring during preparation aborts remaining prep, is NOT served afterward,
	# discards incomplete work cleanly, and records failure + debt at settlement.
	var gr_din := packed.instantiate() as GameRoot
	root.add_child(gr_din)
	await process_frame
	await physics_frame

	var k_din := gr_din.get_kitchen_controller() as KitchenController
	var s_din := gr_din.get_service_controller() as ServiceController
	var r_din := gr_din.get_run_controller() as RunController
	r_din.request_ingredient_purchase(&"beras", 2, &"storage_box")
	r_din.request_ingredient_purchase(&"telur", 2, &"storage_box")
	gr_din.start_service_requested()
	var din_tracker := _make_offer_tracker()
	var din_saji_calls := { "count": 0 }
	k_din.command_executed.connect(func(cmd: StringName, _target_id: StringName) -> void:
		if cmd == &"saji":
			din_saji_calls["count"] = int(din_saji_calls["count"]) + 1
	)
	# Advance to t=93.0s (Customer 1 has 7.0s left, while rice+telor prep takes 9.0s),
	# so prep starts staging rice on a plate and expires mid-cook before serving.
	_advance_clock_and_poll(gr_din, s_din, 93.0, din_tracker)
	var cash_before_expired_din := int(r_din.get_run_view()["cash"])
	var ord_din := StringName(s_din.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var din_fail_res := _cook_and_serve_chronological(
		gr_din,
		k_din,
		s_din,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": &"dining_table_01",
			"order_id": ord_din,
			"recipe_id": &"nasi_telor",
		},
		din_tracker,
		0.0
	)
	var ov_din := s_din.get_order_view(ord_din)
	# Drain remaining Day 1 customers to inspect settled failure & demand debt.
	for _tick in range(400):
		if not gr_din.is_serving():
			break
		_advance_clock_and_poll(gr_din, s_din, TICK_STEP, din_tracker)
	var din_settle := r_din.get_day_settlement_view(1)
	_check(
		"P5-G2A dine-in order expiring mid-prep stops prep, blocks saji, and settles debt cleanly",
		not bool(din_fail_res["served"])
		and bool(din_fail_res["expired_mid_prep"])
		and int(din_saji_calls["count"]) == 0
		and int(ov_din.get("status", -1)) == SharedTypes.OrderStatus.FAILED
		and int(r_din.get_run_view()["cash"]) == cash_before_expired_din - 2000
		and k_din.get_held_item_view().is_empty()
		and k_din.get_work_table_view(&"work_table").is_empty()
		and int(din_settle.get("completed_dinein_count", -1)) == 0
		and int(din_settle.get("failed_dinein_count", -1)) == 4
		and int(din_settle.get("penalty_debt_after", 0)) >= 4
		and int(din_settle.get("penalty_debt_after", 0)) <= 8
	)
	gr_din.free()
	await process_frame

	# 3. Online order expiring during preparation aborts prep, blocks saji, leaves hand clean,
	# and records failed online settlement + debt cleanly.
	var gr_onl := packed.instantiate() as GameRoot
	root.add_child(gr_onl)
	await process_frame
	await physics_frame

	var k_onl := gr_onl.get_kitchen_controller() as KitchenController
	var s_onl := gr_onl.get_service_controller() as ServiceController
	var r_onl := gr_onl.get_run_controller() as RunController
	r_onl.request_ingredient_purchase(&"beras", 2, &"storage_box")
	r_onl.request_ingredient_purchase(&"telur", 2, &"storage_box")
	gr_onl.start_service_requested()
	var onl_tracker := _make_offer_tracker()
	var onl_saji_calls := { "count": 0 }
	k_onl.command_executed.connect(func(cmd: StringName, _target_id: StringName) -> void:
		if cmd == &"saji":
			onl_saji_calls["count"] = int(onl_saji_calls["count"]) + 1
	)
	# Advance to t=10.0s so periodic online offer becomes AVAILABLE, accept at t=10.5s.
	_advance_clock_and_poll(gr_onl, s_onl, 10.0, onl_tracker)
	_advance_clock_and_poll(gr_onl, s_onl, DUR_ONLINE_ACCEPT, onl_tracker)
	k_onl.on_interactable_clicked(&"online_station")
	_check(
		"P5-G2A accept online offer for mid-prep expiry test",
		k_onl.execute_allowed_command(&"terima")
	)
	var drv_view := s_onl.get_driver_views()[0]
	var drv_id := StringName(drv_view["driver_id"])
	var ord_onl := StringName(drv_view["order_id"])
	# Advance 53.0s -> t=63.5s (driver deadline is t=70.5s, 7.0s left vs 9.0s prep time).
	_advance_clock_and_poll(gr_onl, s_onl, 53.0, onl_tracker)
	var cash_before_expired_onl := int(r_onl.get_run_view()["cash"])
	var onl_fail_res := _cook_and_serve_chronological(
		gr_onl,
		k_onl,
		s_onl,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.ONLINE,
			"target_id": drv_id,
			"order_id": ord_onl,
			"recipe_id": &"nasi_telor",
		},
		onl_tracker,
		0.0
	)
	var ov_onl := s_onl.get_order_view(ord_onl)
	for _tick in range(500):
		if not gr_onl.is_serving():
			break
		_advance_clock_and_poll(gr_onl, s_onl, TICK_STEP, onl_tracker)
	var onl_settle := r_onl.get_day_settlement_view(1)
	_check(
		"P5-G2A online order expiring mid-prep aborts prep, pays nothing, and settles debt cleanly",
		not bool(onl_fail_res["served"])
		and bool(onl_fail_res["expired_mid_prep"])
		and int(onl_saji_calls["count"]) == 0
		and int(ov_onl.get("status", -1)) == SharedTypes.OrderStatus.FAILED
		and not s_onl.has_driver(drv_id)
		and int(r_onl.get_run_view()["cash"]) == cash_before_expired_onl - 2000
		and k_onl.get_held_item_view().is_empty()
		and k_onl.get_work_table_view(&"work_table").is_empty()
		and int(onl_settle.get("completed_online_count", -1)) == 0
		and int(onl_settle.get("failed_online_count", -1)) == 1
		and int(onl_settle.get("penalty_debt_after", 0)) >= 5
	)
	gr_onl.free()
	await process_frame

	await _test_rice_cook_and_final_saji_boundaries(packed)


func _test_rice_cook_and_final_saji_boundaries(packed: PackedScene) -> void:
	# 4. Rice cooking expiry guard: order expires during DUR_RICE_MASAK -> masak NOT executed.
	var gr_rice := packed.instantiate() as GameRoot
	root.add_child(gr_rice)
	await process_frame
	await physics_frame

	var k_rice := gr_rice.get_kitchen_controller() as KitchenController
	var s_rice := gr_rice.get_service_controller() as ServiceController
	var r_rice := gr_rice.get_run_controller() as RunController
	r_rice.request_ingredient_purchase(&"beras", 2, &"storage_box")
	r_rice.request_ingredient_purchase(&"telur", 2, &"storage_box")
	gr_rice.start_service_requested()
	var rice_tracker := _make_offer_tracker()
	var masak_calls := { "count": 0 }
	k_rice.command_executed.connect(func(cmd: StringName, _target_id: StringName) -> void:
		if cmd == &"masak":
			masak_calls["count"] = int(masak_calls["count"]) + 1
	)
	# At t=97.5s Customer 1 has 2.5s left: cuci finishes at 99.0s, DUR_RICE_MASAK crosses 100.0s.
	_advance_clock_and_poll(gr_rice, s_rice, 97.5, rice_tracker)
	var ord_rice := StringName(s_rice.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var rice_res := _cook_and_serve_chronological(
		gr_rice,
		k_rice,
		s_rice,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": &"dining_table_01",
			"order_id": ord_rice,
			"recipe_id": &"nasi_telor",
		},
		rice_tracker,
		0.0
	)
	_check(
		"P5-G2A2 expiry during DUR_RICE_MASAK aborts before masak & cleans washed rice",
		not bool(rice_res["served"])
		and bool(rice_res["expired_mid_prep"])
		and int(masak_calls["count"]) == 0
		and int(k_rice.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 0
		and k_rice.get_held_item_view().is_empty()
		and int(s_rice.get_order_view(ord_rice).get("status", -1)) == SharedTypes.OrderStatus.FAILED
	)
	gr_rice.free()
	await process_frame

	# 5. Final serving boundary matrix across BOTH dine-in and online:
	# - "before_saji": plated pickup finishes right at deadline -> aborts before DUR_SERVE_SAJI.
	# - "during_saji": 0.50s left (< DUR_SERVE_SAJI=1.00s) -> expires mid-saji step.
	# - "exact_saji":  1.00s left (== DUR_SERVE_SAJI=1.00s) -> expires at deadline == now.
	# - "valid_saji":  1.25s left (> DUR_SERVE_SAJI=1.00s) -> completes once cleanly.
	var cases: Array[Dictionary] = [
		{ "kind": SharedTypes.OrderKind.DINE_IN, "mode": "before_saji", "pre_wait": 92.0 },
		{ "kind": SharedTypes.OrderKind.DINE_IN, "mode": "during_saji", "pre_wait": 91.5 },
		{ "kind": SharedTypes.OrderKind.DINE_IN, "mode": "exact_saji", "pre_wait": 91.0 },
		{ "kind": SharedTypes.OrderKind.DINE_IN, "mode": "valid_saji", "pre_wait": 90.75 },
		{ "kind": SharedTypes.OrderKind.ONLINE, "mode": "before_saji", "pre_wait": 52.0 },
		{ "kind": SharedTypes.OrderKind.ONLINE, "mode": "during_saji", "pre_wait": 51.5 },
		{ "kind": SharedTypes.OrderKind.ONLINE, "mode": "exact_saji", "pre_wait": 51.0 },
		{ "kind": SharedTypes.OrderKind.ONLINE, "mode": "valid_saji", "pre_wait": 50.75 },
	]
	for c: Dictionary in cases:
		var kind := int(c["kind"])
		var mode := String(c["mode"])
		var pre_wait := float(c["pre_wait"])
		var gr := packed.instantiate() as GameRoot
		root.add_child(gr)
		await process_frame
		await physics_frame

		var k := gr.get_kitchen_controller() as KitchenController
		var s := gr.get_service_controller() as ServiceController
		var r := gr.get_run_controller() as RunController
		r.request_ingredient_purchase(&"beras", 2, &"storage_box")
		r.request_ingredient_purchase(&"telur", 2, &"storage_box")
		gr.start_service_requested()
		var tr := _make_offer_tracker()
		var saji_calls := { "count": 0 }
		k.command_executed.connect(func(cmd: StringName, _target_id: StringName) -> void:
			if cmd == &"saji":
				saji_calls["count"] = int(saji_calls["count"]) + 1
		)

		var target := {}
		var drv_id := &""
		var ord_id := &""
		if kind == SharedTypes.OrderKind.DINE_IN:
			_advance_clock_and_poll(gr, s, pre_wait, tr)
			ord_id = StringName(s.get_table_view(&"dining_table_01")["order_id_or_empty"])
			target = {
				"kind": kind,
				"target_id": &"dining_table_01",
				"order_id": ord_id,
				"recipe_id": &"nasi_telor",
			}
		else:
			_advance_clock_and_poll(gr, s, 10.0 + DUR_ONLINE_ACCEPT, tr)
			k.on_interactable_clicked(&"online_station")
			k.execute_allowed_command(&"terima")
			var dv := s.get_driver_views()[0]
			drv_id = StringName(dv["driver_id"])
			ord_id = StringName(dv["order_id"])
			_advance_clock_and_poll(gr, s, pre_wait, tr)
			target = {
				"kind": kind,
				"target_id": drv_id,
				"order_id": ord_id,
				"recipe_id": &"nasi_telor",
			}

		var cash_before := int(r.get_run_view()["cash"])
		var prep_res := _cook_and_serve_chronological(gr, k, s, [&"storage_box"], target, tr, 0.0)
		var cash_after_step := int(r.get_run_view()["cash"])
		var ov_after := s.get_order_view(ord_id)
		var dup_serve := (
			s.try_serve_table(&"dining_table_01", &"fake_item")
			if kind == SharedTypes.OrderKind.DINE_IN
			else s.try_serve_driver(drv_id, &"fake_item")
		)
		var cash_after_dup := int(r.get_run_view()["cash"])

		# Drain remaining Day 1 orders to verify settlement counts, debt, & cash conservation.
		for _tick in range(500):
			if not gr.is_serving():
				break
			_advance_clock_and_poll(gr, s, TICK_STEP, tr)
		var settle := r.get_day_settlement_view(1)
		var expect_valid := (mode == "valid_saji")
		var expected_payout := 20000 if kind == SharedTypes.OrderKind.DINE_IN else 14000
		var ledger_day := (
			int(settle.get("begin_cash", 0))
			+ int(settle.get("order_revenue_dinein", 0))
			+ int(settle.get("order_revenue_online", 0))
			+ int(settle.get("refund_total", 0))
			- int(settle.get("ingredient_purchase_total", 0))
			- int(settle.get("fixture_purchase_total", 0))
			- int(settle.get("electricity_charge", 0))
		)
		var kind_label := "dinein" if kind == SharedTypes.OrderKind.DINE_IN else "online"
		_check(
			"P5-G2A2 %s %s boundary enforces deadline, no dup pay, cleanup, & debt/cash balance"
			% [kind_label, mode],
			bool(prep_res["served"]) == expect_valid
			and bool(prep_res["expired_mid_prep"]) == (not expect_valid)
			and int(saji_calls["count"]) == (1 if expect_valid else 0)
			and not dup_serve
			and cash_after_dup == cash_after_step
			and cash_after_step == (cash_before + expected_payout if expect_valid else cash_before)
			and int(ov_after.get("status", -1))
			== (SharedTypes.OrderStatus.COMPLETED if expect_valid else SharedTypes.OrderStatus.FAILED)
			and k.get_held_item_view().is_empty()
			and k.get_work_table_view(&"work_table").is_empty()
			and (kind != SharedTypes.OrderKind.ONLINE or not s.has_driver(drv_id))
			and int(settle.get("end_cash", -1)) == ledger_day
			and (
				int(settle.get("completed_dinein_count", -1)) == 1
				if (kind == SharedTypes.OrderKind.DINE_IN and expect_valid)
				else int(settle.get("failed_dinein_count", -1)) == 4
			)
			and (
				int(settle.get("completed_online_count", -1))
				== (1 if (kind == SharedTypes.OrderKind.ONLINE and expect_valid) else 0)
			)
			and (
				int(settle.get("failed_online_count", -1))
				== (1 if (kind == SharedTypes.OrderKind.ONLINE and not expect_valid) else 0)
			)
			and (
				int(settle.get("penalty_debt_after", 0)) >= (3 if expect_valid else 4)
			)
		)
		gr.free()
		await process_frame


func serve_started_at(start_t: float, end_t: float) -> bool:
	return end_t > start_t


func _test_chronological_shop_contracts() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene

	# 1. Shop interaction advances clock before checkout, deducts cash once, preserves 100s
	# delivery delay (not delivered at +99.75s, delivered at +100.0s), advances dine-in/online
	# deadlines & online offer transitions while open, and rejects invalid/expired targets.
	var gr1 := packed.instantiate() as GameRoot
	root.add_child(gr1)
	await process_frame
	await physics_frame
	var k1 := gr1.get_kitchen_controller() as KitchenController
	var s1 := gr1.get_service_controller() as ServiceController
	var r1 := gr1.get_run_controller() as RunController
	var ui1 := gr1.get_node("UI") as GameUI
	var tr1 := _make_offer_tracker()

	# Start Planning with empty box -> Planning Belanja consumes modeled time cleanly pre-service.
	var plan_shop := _execute_shop_basket_interaction(
		gr1, k1, s1, r1, ui1, &"storage_box", { &"beras": 1, &"telur": 2 }, true, tr1
	)
	_check(
		"P5-G2B Planning shop consumes time pre-service, delivers immediately, & debits once",
		bool(plan_shop["committed"])
		and is_equal_approx(float(plan_shop["duration"]), 0.75 + 3 * 0.25 + 0.50)
		and is_equal_approx(gr1.get_service_elapsed(), 0.0)
		and int(r1.get_run_view()["cash"]) == 100000 - 2000 - 6000
		and _count_ingredient(k1, [&"storage_box"], &"beras") == 1
		and _count_ingredient(k1, [&"storage_box"], &"telur") == 2
		and not ui1.is_ingredient_shop_open()
	)
	k1.clear_selected_target()
	gr1.start_service_requested()

	# Advance to t=9.0s -> open SERVING shop for 2x ayam (0.75 + 2*0.25 + 0.50 = 1.75s -> t=10.75s).
	# Verifies Customer 1 patience shrinks during shop AND periodic online offer opens at t=10.0s.
	_advance_clock_and_poll(gr1, s1, 9.0, tr1)
	var ord1 := StringName(s1.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var rem_before_shop := float(s1.get_order_view(ord1)["seconds_remaining"])
	var cash_before_srv_shop := int(r1.get_run_view()["cash"])
	var srv_shop := _execute_shop_basket_interaction(
		gr1, k1, s1, r1, ui1, &"storage_box", { &"ayam": 2 }, false, tr1
	)
	var bought_at := gr1.get_service_elapsed()
	var rem_after_shop := float(s1.get_order_view(ord1)["seconds_remaining"])
	var offer_after_shop := s1.get_online_offer_view()

	# Advance +99.75s from checkout (delivery MUST still be pending, not arrived early).
	_advance_clock_and_poll(gr1, s1, 99.75, tr1)
	var ayam_before_due := _count_ingredient(k1, [&"storage_box"], &"ayam")
	var pending_before_due := _count_pending(k1, &"ayam")
	# Advance final +0.25s -> exact 100.0s delay -> delivery commits!
	_advance_clock_and_poll(gr1, s1, 0.25, tr1)
	var ayam_at_due := _count_ingredient(k1, [&"storage_box"], &"ayam")
	var pending_at_due := _count_pending(k1, &"ayam")

	# Attempt invalid box / over-capacity purchase during SERVING -> no cash or stock mutation.
	var cash_pre_bad := int(r1.get_run_view()["cash"])
	var bad_box := _execute_shop_basket_interaction(
		gr1, k1, s1, r1, ui1, &"nonexistent_box", { &"telur": 1 }, false, tr1
	)
	_check(
		"P5-G2B SERVING shop advances deadlines/offers, debits once, keeps 100s delay, blocks bad box",
		bool(srv_shop["committed"])
		and is_equal_approx(bought_at, 10.75)
		and is_equal_approx(rem_before_shop - rem_after_shop, 1.75)
		and int(offer_after_shop.get("offer_state", -1))
		== ServiceController.OnlineOfferState.AVAILABLE
		and int(tr1["presented"]) == 1
		and int(r1.get_run_view()["cash"]) == cash_before_srv_shop - 12000
		and ayam_before_due == 0 and pending_before_due == 2
		and ayam_at_due == 2 and pending_at_due == 0
		and not bool(bad_box["committed"])
		and int(r1.get_run_view()["cash"]) == cash_pre_bad
		and _count_ingredient(k1, [&"storage_box"], &"ayam") == 2
	)
	gr1.free()
	await process_frame

	# 2. Order can expire WHILE shop is open (dine-in + online), AND purchase aborts cleanly if
	# day auto-closes mid-shop without mutating cash or creating deliveries.
	var gr2 := packed.instantiate() as GameRoot
	root.add_child(gr2)
	await process_frame
	await physics_frame
	var k2 := gr2.get_kitchen_controller() as KitchenController
	var s2 := gr2.get_service_controller() as ServiceController
	var r2 := gr2.get_run_controller() as RunController
	var ui2 := gr2.get_node("UI") as GameUI
	var tr2 := _make_offer_tracker()
	gr2.start_service_requested()
	# Accept periodic online offer at t=10.5s (deadline=70.5s) then advance to t=69.5s (1.0s left).
	_advance_clock_and_poll(gr2, s2, 10.0 + DUR_ONLINE_ACCEPT, tr2)
	k2.on_interactable_clicked(&"online_station")
	k2.execute_allowed_command(&"terima")
	var onl_ord_id := StringName(s2.get_driver_views()[0]["order_id"])
	_advance_clock_and_poll(gr2, s2, 59.0, tr2)
	# Now open shop for 2x telur (0.75 + 0.50 + 0.50 = 1.75s -> t=71.25s, crossing online 70.5s!).
	var shop_mid_exp := _execute_shop_basket_interaction(
		gr2, k2, s2, r2, ui2, &"storage_box", { &"telur": 2 }, false, tr2
	)
	var onl_after_shop := s2.get_order_view(onl_ord_id)
	# Advance to t=99.0s (Customer 1 at t=0+100=100.0s has 1.0s left) and open shop for 1x beras.
	_advance_clock_and_poll(gr2, s2, 99.0 - gr2.get_service_elapsed(), tr2)
	var din1_ord_id := StringName(s2.get_customer_views()[0].get("order_id", &""))
	var din1_pre_status := int(s2.get_order_view(din1_ord_id).get("status", -1))
	var shop_din_exp := _execute_shop_basket_interaction(
		gr2, k2, s2, r2, ui2, &"storage_box", { &"beras": 1 }, false, tr2
	)
	var din1_after_status := int(s2.get_order_view(din1_ord_id).get("status", -1))
	# Advance to t=159.0s (final Customer 4 at t=60+100=160.0s has 1.0s left before auto-close!).
	_advance_clock_and_poll(gr2, s2, 159.0 - gr2.get_service_elapsed(), tr2)
	var custs_pre_close := s2.get_customer_views()
	var din4_ord_id: StringName = &""
	if not custs_pre_close.is_empty():
		din4_ord_id = StringName(custs_pre_close[0].get("order_id", &""))
	var din4_pre_status := int(s2.get_order_view(din4_ord_id).get("status", -1))
	var cash_pre_close_shop := int(r2.get_run_view()["cash"])
	var shop_at_close := _execute_shop_basket_interaction(
		gr2, k2, s2, r2, ui2, &"storage_box", { &"ayam": 2 }, false, tr2
	)
	var report2: Dictionary = r2.get_day_settlement_view(1)
	_check(
		"P5-G2B orders expire mid-shop (online & dine-in) & auto-close aborts shop cleanly",
		bool(shop_mid_exp["committed"])
		and int(onl_after_shop.get("status", -1)) == SharedTypes.OrderStatus.FAILED
		and bool(shop_din_exp["committed"])
		and din1_pre_status == SharedTypes.OrderStatus.OPEN
		and din1_after_status == SharedTypes.OrderStatus.FAILED
		and din4_ord_id != &""
		and din4_pre_status == SharedTypes.OrderStatus.OPEN
		and int(report2.get("failed_dinein_count", -1)) == 4
		and int(report2.get("failed_online_count", -1)) == 1
		and int(report2.get("refund_total", -1)) == 8000
		and int(report2.get("electricity_charge", -1)) == 2000
		and not bool(shop_at_close["committed"])
		and not gr2.is_serving()
		and gr2.get_phase() == SharedTypes.Phase.RESULTS
		and not ui2.is_ingredient_shop_open()
		and int(r2.get_run_view()["cash"]) == cash_pre_close_shop + 8000 - 2000
		and k2.get_pending_delivery_views().is_empty()
	)
	gr2.free()
	await process_frame


func _test_lifecycle_metrics_and_classification() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene

	# 1. Cutoff-terminated offer vs timer expiration + suppression tracking (Day 1 q=4, cutoff t=20s).
	var gr_cut := packed.instantiate() as GameRoot
	root.add_child(gr_cut)
	await process_frame
	await physics_frame
	var s_cut := gr_cut.get_service_controller() as ServiceController
	gr_cut.start_service_requested()
	var t_cut := _make_offer_tracker(gr_cut, s_cut)
	_poll_offer_tracker(s_cut, t_cut, gr_cut)
	_advance_clock_and_poll(gr_cut, s_cut, 21.0, t_cut)
	var snap_cut := _snapshot_lifecycle_metrics(gr_cut, s_cut, t_cut)
	_check(
		"P5-G2C cutoff termination classifies cutoff_reached separately from timer_expired",
		int(snap_cut["offers_generated"]) == 1
		and int(snap_cut["offers_presented"]) == 1
		and int(snap_cut["offers_accepted"]) == 0
		and int(snap_cut["offers_timer_expired"]) == 0
		and int(snap_cut["offers_terminated_cutoff"]) == 1
		and int(snap_cut["offers_unknown"]) == 0
		and int(snap_cut["suppressed_cutoff_episodes"]) >= 1
		and float(snap_cut["suppressed_cutoff_seconds"]) > 0.5
	)
	gr_cut.free()
	await process_frame

	# 2. Online offer timer expiration without cutoff interruption (Day 2 q=8, expires at t=25s).
	var gr_tmr := packed.instantiate() as GameRoot
	root.add_child(gr_tmr)
	await process_frame
	await physics_frame
	var k_tmr := gr_tmr.get_kitchen_controller() as KitchenController
	var s_tmr := gr_tmr.get_service_controller() as ServiceController
	var r_tmr := gr_tmr.get_run_controller() as RunController
	var ui_tmr := gr_tmr.get_node("UI") as GameUI
	r_tmr.request_ingredient_purchase(&"beras", 1, &"storage_box")
	r_tmr.request_ingredient_purchase(&"telur", 4, &"storage_box")
	gr_tmr.start_service_requested()
	var t_tmr_d1 := _make_offer_tracker(gr_tmr, s_tmr)
	for _tk in range(800):
		if not gr_tmr.is_serving():
			break
		_step_service_chronological(
			gr_tmr, k_tmr, s_tmr, r_tmr, ui_tmr, [&"nasi_telor"], [&"storage_box"],
			false, false, RandomNumberGenerator.new(), {}, t_tmr_d1
		)
	gr_tmr.request_continue_from_results()
	gr_tmr.start_service_requested()
	var t_tmr := _make_offer_tracker(gr_tmr, s_tmr)
	_poll_offer_tracker(s_tmr, t_tmr, gr_tmr)
	_advance_clock_and_poll(gr_tmr, s_tmr, 26.0, t_tmr)
	var snap_tmr := _snapshot_lifecycle_metrics(gr_tmr, s_tmr, t_tmr)
	_check(
		"P5-G2C Day 2 timer expiration increments timer_expired with zero cutoff termination",
		int(snap_tmr["offers_generated"]) == 1
		and int(snap_tmr["offers_presented"]) == 1
		and int(snap_tmr["offers_accepted"]) == 0
		and int(snap_tmr["offers_timer_expired"]) == 1
		and int(snap_tmr["offers_terminated_cutoff"]) == 0
		and int(snap_tmr["offers_active_at_boundary"]) == 0
		and int(snap_tmr["offers_unknown"]) == 0
	)
	gr_tmr.free()
	await process_frame

	# 3. Concurrent OPEN online-order cap suppression (controller-level duplicate EconomyConfig).
	var gr_cap := packed.instantiate() as GameRoot
	root.add_child(gr_cap)
	await process_frame
	await physics_frame
	var k_cap := gr_cap.get_kitchen_controller() as KitchenController
	var s_cap := gr_cap.get_service_controller() as ServiceController
	var r_cap := gr_cap.get_run_controller() as RunController
	var cap_cfg := r_cap.economy_config.duplicate(true) as EconomyConfig
	cap_cfg.online_offer_initial_delay_seconds = 1.0
	cap_cfg.online_offer_interval_seconds = 1.0
	cap_cfg.online_offer_active_duration_seconds = 10.0
	r_cap.economy_config = cap_cfg
	s_cap.bind_systems(k_cap, r_cap, gr_cap)
	gr_cap.start_service_requested()
	var t_cap := _make_offer_tracker(gr_cap, s_cap)
	_poll_offer_tracker(s_cap, t_cap, gr_cap)
	for _i in range(4):
		_advance_clock_and_poll(gr_cap, s_cap, 1.25, t_cap)
		if (
			int(s_cap.get_online_offer_view().get("offer_state", -1))
			== ServiceController.OnlineOfferState.AVAILABLE
		):
			k_cap.on_interactable_clicked(&"online_station")
			if k_cap.execute_allowed_command(&"terima"):
				t_cap["accepted"] = int(t_cap["accepted"]) + 1
				t_cap["active_unaccepted_gen"] = 0
				_poll_offer_tracker(s_cap, t_cap, gr_cap)
	_advance_clock_and_poll(gr_cap, s_cap, 5.0, t_cap)
	var snap_cap := _snapshot_lifecycle_metrics(gr_cap, s_cap, t_cap)
	_check(
		"P5-G2C concurrent OPEN cap suppression tracks cap episodes & still-open online orders",
		int(snap_cap["offers_generated"]) == 4
		and int(snap_cap["offers_presented"]) == 4
		and int(snap_cap["offers_accepted"]) == 4
		and int(snap_cap["online_still_open"]) == 4
		and int(snap_cap["suppressed_cap_episodes"]) == 1
		and float(snap_cap["suppressed_cap_seconds"]) >= 4.5
		and int(snap_cap["suppressed_cutoff_episodes"]) == 0
	)
	gr_cap.free()
	await process_frame

	# 4. Active offer at boundary + open dine-in/online orders + outside queue + promotion (no dup)
	# + pre-seating failure on Day 1 (C1 seated->ok, C2 seated->fail, C3 queued->seated->fail,
	# C4 queued->fail before seating).
	var gr1 := packed.instantiate() as GameRoot
	root.add_child(gr1)
	await process_frame
	await physics_frame
	var k1 := gr1.get_kitchen_controller() as KitchenController
	var s1 := gr1.get_service_controller() as ServiceController
	var r1 := gr1.get_run_controller() as RunController
	r1.request_ingredient_purchase(&"beras", 2, &"storage_box")
	r1.request_ingredient_purchase(&"telur", 2, &"storage_box")
	gr1.start_service_requested()
	var t1 := _make_offer_tracker(gr1, s1)
	_poll_offer_tracker(s1, t1, gr1)

	# t=10.25s: Offer #1 is AVAILABLE (active_at_boundary=1), C1 is OPEN at table_01.
	_advance_clock_and_poll(gr1, s1, 10.25, t1)
	var snap_act := _snapshot_lifecycle_metrics(gr1, s1, t1)

	# Accept Offer #1 at t=10.50s, advance to t=15.0s -> 1 OPEN online order at boundary.
	_advance_clock_and_poll(gr1, s1, 0.25, t1)
	k1.on_interactable_clicked(&"online_station")
	if k1.execute_allowed_command(&"terima"):
		t1["accepted"] = int(t1["accepted"]) + 1
		t1["active_unaccepted_gen"] = 0
		_poll_offer_tracker(s1, t1, gr1)
	_advance_clock_and_poll(gr1, s1, 4.5, t1)
	var snap_open_onl := _snapshot_lifecycle_metrics(gr1, s1, t1)

	# Advance to t=61.0s: C1/C2 seated, C3/C4 in outside queue -> check mid-service snapshot.
	_advance_clock_and_poll(gr1, s1, 61.0 - gr1.get_service_elapsed(), t1)
	var snap_mid_q := _snapshot_lifecycle_metrics(gr1, s1, t1)

	# Serve C1 & C2 cleanly so both tables become DIRTY (preventing unserved vacate admission).
	# C3 expires in outside queue at t=140s (failed_before_seating=1), then clean table_01 at
	# t=141s so C4 promotes outside_queue -> table_01 without double-count and fails at t=160s.
	var ord1 := StringName(s1.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var serve_c1 := _cook_and_serve_chronological(
		gr1,
		k1,
		s1,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": &"dining_table_01",
			"order_id": ord1,
			"recipe_id": &"nasi_telor",
		},
		t1,
		0.0
	)
	var ord2 := StringName(s1.get_table_view(&"dining_table_02")["order_id_or_empty"])
	var serve_c2 := _cook_and_serve_chronological(
		gr1,
		k1,
		s1,
		[&"storage_box"],
		{
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": &"dining_table_02",
			"order_id": ord2,
			"recipe_id": &"nasi_telor",
		},
		t1,
		0.0
	)
	_advance_clock_and_poll(gr1, s1, 140.25 - gr1.get_service_elapsed(), t1)
	_advance_clock_and_poll(gr1, s1, DUR_DIRTY_TABLE_CLEAN, t1)
	k1.on_interactable_clicked(&"dining_table_01")
	k1.execute_allowed_command(&"bersihkan")
	_poll_offer_tracker(s1, t1, gr1)
	var snap_after_prom := _snapshot_lifecycle_metrics(gr1, s1, t1)

	for _tk in range(500):
		if not gr1.is_serving():
			break
		_advance_clock_and_poll(gr1, s1, TICK_STEP, t1)
	var snap_end := _snapshot_lifecycle_metrics(gr1, s1, t1)

	_check(
		"P5-G2C mid-boundary open orders/active offers & queued->seated without double-count",
		int(snap_act["offers_generated"]) == 1
		and int(snap_act["offers_presented"]) == 1
		and int(snap_act["offers_active_at_boundary"]) == 1
		and int(snap_act["spawned_dinein"]) == 1
		and int(snap_act["still_open_dinein"]) == 1
		and int(snap_open_onl["offers_accepted"]) == 1
		and int(snap_open_onl["online_still_open"]) == 1
		and int(snap_mid_q["spawned_dinein"]) == 4
		and int(snap_mid_q["entered_outside_queue"]) == 2
		and int(snap_mid_q["reached_table"]) == 2
		and int(snap_mid_q["still_open_outside_waiting"]) == 2
		and int(snap_mid_q["still_open_seated"]) == 2
		and bool(serve_c1["served"])
		and bool(serve_c2["served"])
		and int(snap_after_prom["queued_then_seated"]) == 1
		and int(snap_after_prom["reached_table"]) == 3
		and int(snap_after_prom["entered_outside_queue"]) == 2
		and int(snap_after_prom["failed_before_seating"]) == 1
		and int(snap_after_prom["still_open_outside_waiting"]) == 0
	)
	_check(
		"P5-G2C terminal dine-in & online lifecycle equations reconcile pre/post-seating failures",
		int(snap_end["spawned_dinein"]) == 4
		and int(snap_end["completed_dinein"]) == 2
		and int(snap_end["failed_dinein"]) == 2
		and int(snap_end["still_open_dinein"]) == 0
		and int(snap_end["entered_outside_queue"]) == 2
		and int(snap_end["reached_table"]) == 3
		and int(snap_end["queued_then_seated"]) == 1
		and int(snap_end["seated_directly"]) == 2
		and int(snap_end["failed_before_seating"]) == 1
		and int(snap_end["failed_after_seating"]) == 1
		and int(snap_end["offers_accepted"]) == 1
		and int(snap_end["online_fulfilled"]) == 0
		and int(snap_end["online_failed"]) == 1
		and int(snap_end["online_still_open"]) == 0
	)
	gr1.free()
	await process_frame


func _run_p5g_fair_matrix() -> void:
	var scenarios: Array[Dictionary] = [
		{
			"id": "A",
			"name": "A_one_recipe_baseline",
			"target_boxes_by_day": { 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor"],
				3: [&"nasi_telor"],
				4: [&"nasi_telor"],
				5: [&"nasi_telor"],
				6: [&"nasi_telor"],
				7: [&"nasi_telor"],
			},
			"accept_online": true,
			"noise": false,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
		{
			"id": "B",
			"name": "B_two_recipes_adequate_storage",
			"target_boxes_by_day": { 1: 1, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_ayam"],
				3: [&"nasi_telor", &"nasi_ayam"],
				4: [&"nasi_telor", &"nasi_ayam"],
				5: [&"nasi_telor", &"nasi_ayam"],
				6: [&"nasi_telor", &"nasi_ayam"],
				7: [&"nasi_telor", &"nasi_ayam"],
			},
			"accept_online": true,
			"noise": false,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
		{
			"id": "C",
			"name": "C_three_recipes_constrained_storage",
			"target_boxes_by_day": { 1: 1, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 2 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_ayam"],
				3: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				4: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				5: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				6: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				7: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
			},
			"accept_online": true,
			"noise": false,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
		{
			"id": "D",
			"name": "D_three_recipes_adequate_storage",
			"target_boxes_by_day": { 1: 1, 2: 2, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_ayam"],
				3: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				4: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				5: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				6: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				7: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
			},
			"accept_online": true,
			"noise": false,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
		{
			"id": "E",
			"name": "E_three_recipes_human_noise",
			"target_boxes_by_day": { 1: 1, 2: 2, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_ayam"],
				3: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				4: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				5: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				6: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				7: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
			},
			"accept_online": true,
			"noise": true,
			"noise_seed": DEFAULT_NOISE_SEED,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
		{
			"id": "F_CTRL",
			"name": "F_CTRL_three_recipes_adequate_dinein_only",
			"target_boxes_by_day": { 1: 1, 2: 2, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3 },
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_ayam"],
				3: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				4: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				5: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				6: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
				7: [&"nasi_telor", &"nasi_ayam", &"nasi_komplit"],
			},
			"accept_online": false,
			"noise": false,
			"expected_outcome": SharedTypes.DayOutcome.WON,
		},
	]

	var results_by_id: Dictionary = {}
	for sc: Dictionary in scenarios:
		var summary := await _simulate_fair_campaign(sc)
		results_by_id[String(sc["id"])] = summary
		_print_scenario_summary(sc, summary)
		var days: Array = summary["days"]
		var ledger_balance := (
			int(summary["starting_cash"])
			+ int(summary["total_dinein_rev"])
			+ int(summary["total_online_rev"])
			+ int(summary["total_refunds"])
			- int(summary["total_ing_cost"])
			- int(summary["total_fix_cost"])
			- int(summary["total_el_cost"])
		)
		var expected_outcome := int(sc["expected_outcome"])
		_check(
			"P5-G2A Scenario %s completes 7 days with exact cash, dine-in, and online conservation"
			% String(sc["id"]),
			days.size() == 7
			and int(summary["final_phase"]) == SharedTypes.Phase.FINISHED
			and int(summary["day7_outcome"]) == expected_outcome
			and int(summary["final_cash"]) >= int(summary["day_7_target"])
			and int(summary["final_cash"]) == int(days[6]["end_cash"])
			and int(summary["final_cash"]) == ledger_balance
			and int(summary["total_generated_dinein"])
			== int(summary["total_completed_dinein"]) + int(summary["total_failed_dinein"])
			and int(summary["total_online_accepted"])
			== int(summary["total_online_fulfilled"]) + int(summary["total_online_failed"])
			and int(summary["total_online_presented"])
			== int(summary["total_online_accepted"]) + int(summary["total_online_expired"])
		)
		var sum_keys := [
			"planned_quota",
			"spawned_dinein",
			"completed_dinein",
			"failed_dinein",
			"still_open_dinein",
			"entered_outside_queue",
			"reached_table",
			"queued_then_seated",
			"seated_directly",
			"failed_before_seating",
			"failed_after_seating",
			"offers_generated",
			"online_presented",
			"online_accepted",
			"offers_timer_expired",
			"offers_terminated_cutoff",
			"offers_terminated_cap",
			"offers_terminated_other",
			"offers_active_at_boundary",
			"offers_unknown",
			"suppressed_cutoff_episodes",
			"suppressed_cap_episodes",
			"completed_online",
			"failed_online",
			"online_still_open",
			"stockout_orders",
			"stockout_episodes",
			"mid_prep_expiries",
			"restock_trips",
			"rev_dinein",
			"rev_online",
			"ing_cost",
			"fix_cost",
			"el_cost",
			"refund",
		]
		var tot_map := {
			"planned_quota": int(summary["total_planned_quota"]),
			"spawned_dinein": int(summary["total_generated_dinein"]),
			"completed_dinein": int(summary["total_completed_dinein"]),
			"failed_dinein": int(summary["total_failed_dinein"]),
			"still_open_dinein": int(summary["total_still_open_dinein"]),
			"entered_outside_queue": int(summary["total_entered_outside_queue"]),
			"reached_table": int(summary["total_reached_table"]),
			"queued_then_seated": int(summary["total_queued_then_seated"]),
			"seated_directly": int(summary["total_seated_directly"]),
			"failed_before_seating": int(summary["total_failed_before_seating"]),
			"failed_after_seating": int(summary["total_failed_after_seating"]),
			"offers_generated": int(summary["total_offers_generated"]),
			"online_presented": int(summary["total_online_presented"]),
			"online_accepted": int(summary["total_online_accepted"]),
			"offers_timer_expired": int(summary["total_offers_timer_expired"]),
			"offers_terminated_cutoff": int(summary["total_offers_terminated_cutoff"]),
			"offers_terminated_cap": int(summary["total_offers_terminated_cap"]),
			"offers_terminated_other": int(summary["total_offers_terminated_other"]),
			"offers_active_at_boundary": int(summary["total_offers_active_at_boundary"]),
			"offers_unknown": int(summary["total_offers_unknown"]),
			"suppressed_cutoff_episodes": int(summary["total_suppressed_cutoff_episodes"]),
			"suppressed_cap_episodes": int(summary["total_suppressed_cap_episodes"]),
			"completed_online": int(summary["total_online_fulfilled"]),
			"failed_online": int(summary["total_online_failed"]),
			"online_still_open": int(summary["total_online_still_open"]),
			"stockout_orders": int(summary["total_stockout_orders"]),
			"stockout_episodes": int(summary["total_stockout_episodes"]),
			"mid_prep_expiries": int(summary["total_mid_prep_expiries"]),
			"restock_trips": int(summary["total_restock_trips"]),
			"rev_dinein": int(summary["total_dinein_rev"]),
			"rev_online": int(summary["total_online_rev"]),
			"ing_cost": int(summary["total_ing_cost"]),
			"fix_cost": int(summary["total_fix_cost"]),
			"el_cost": int(summary["total_el_cost"]),
			"refund": int(summary["total_refunds"]),
		}
		var recon_ok := true
		for k: String in sum_keys:
			var acc_d := 0
			for d: Dictionary in days:
				acc_d += int(d[k])
			if acc_d != int(tot_map[k]):
				recon_ok = false
				break
		var all_days_ok := true
		for d: Dictionary in days:
			var d_pres_sum := (
				int(d["online_accepted"])
				+ int(d["offers_timer_expired"])
				+ int(d["offers_terminated_cutoff"])
				+ int(d["offers_terminated_cap"])
				+ int(d["offers_terminated_other"])
				+ int(d["offers_active_at_boundary"])
				+ int(d["offers_unknown"])
			)
			if (
				int(d["offers_generated"]) != int(d["online_presented"])
				or int(d["online_presented"]) != d_pres_sum
				or int(d["spawned_dinein"])
				!= int(d["completed_dinein"])
				+ int(d["failed_dinein"])
				+ int(d["still_open_dinein"])
				or int(d["failed_dinein"])
				!= int(d["failed_before_seating"]) + int(d["failed_after_seating"])
				or int(d["reached_table"])
				!= int(d["seated_directly"]) + int(d["queued_then_seated"])
				or int(d["reached_table"]) > int(d["spawned_dinein"])
				or int(d["entered_outside_queue"]) > int(d["spawned_dinein"])
				or int(d["online_accepted"])
				!= int(d["completed_online"])
				+ int(d["failed_online"])
				+ int(d["online_still_open"])
				or int(d["completed_dinein"]) != int(d["settle_completed_dinein"])
				or int(d["failed_dinein"]) != int(d["settle_failed_dinein"])
				or int(d["completed_online"]) != int(d["settle_completed_online"])
				or int(d["failed_online"]) != int(d["settle_failed_online"])
			):
				all_days_ok = false
				break
		_check(
			"P5-G2C Scenario %s lifecycle conservation & daily-to-total reconciliation"
			% String(sc["id"]),
			recon_ok
			and all_days_ok
			and int(summary["total_offers_generated"]) == int(summary["total_online_presented"])
			and int(summary["total_offers_unknown"]) >= 0
			and int(summary["total_still_open_dinein"]) == 0
			and int(summary["total_online_still_open"]) == 0
			and int(summary["total_offers_active_at_boundary"]) == 0
			and int(summary["total_reached_table"]) <= int(summary["total_generated_dinein"])
			and int(summary["total_entered_outside_queue"])
			<= int(summary["total_generated_dinein"])
		)

	var sc_a: Dictionary = results_by_id["A"]
	var sc_b: Dictionary = results_by_id["B"]
	var sc_c: Dictionary = results_by_id["C"]
	var sc_d: Dictionary = results_by_id["D"]
	var sc_e: Dictionary = results_by_id["E"]
	var sc_ctrl: Dictionary = results_by_id["F_CTRL"]

	_check(
		"P5-G2A Day 3 gross Potential Demand rises monotonically 1->2->3 recipes (15 < 19 < 22)",
		int(sc_a["days"][2]["potential_demand"]) == 15
		and int(sc_b["days"][2]["potential_demand"]) == 19
		and int(sc_c["days"][2]["potential_demand"]) == 22
		and int(sc_d["days"][2]["potential_demand"]) == 22
	)
	_check(
		"P5-G2A Adequate storage (D) cuts unique stockouts & earns more than constrained (C)",
		int(sc_d["total_stockout_orders"]) < int(sc_c["total_stockout_orders"])
		and int(sc_d["final_cash"]) > int(sc_c["final_cash"])
	)
	_check(
		"P5-G2A Online fulfillment adds net cash in 3-recipe D vs dine-in control F_CTRL",
		int(sc_d["final_cash"]) > int(sc_ctrl["final_cash"])
		and int(sc_d["total_online_rev"]) > 0
		and int(sc_ctrl["total_online_accepted"]) == 0
	)
	_check(
		"P5-G2A Deterministic human noise (E) lowers cash & online accepts vs clean D",
		int(sc_e["final_cash"]) < int(sc_d["final_cash"])
		and int(sc_e["total_online_accepted"]) < int(sc_d["total_online_accepted"])
	)


func _make_offer_tracker(
	game_root: GameRoot = null,
	service: ServiceController = null
) -> Dictionary:
	var tracker := {
		"last_clock": 0.0,
		"last_offer_state": ServiceController.OnlineOfferState.NOT_SERVING,
		"last_disabled_reason": &"",
		"last_gen_number": 0,
		"last_presented_gen": 0,
		"active_unaccepted_gen": 0,
		"active_expires_at": 0.0,
		"generated": 0,
		"presented": 0,
		"accepted": 0,
		"timer_expired": 0,
		"terminated_cutoff": 0,
		"terminated_cap": 0,
		"terminated_other": 0,
		"unknown_or_unclassified": 0,
		"suppressed_cutoff_episodes": 0,
		"suppressed_cap_episodes": 0,
		"suppressed_other_episodes": 0,
		"suppressed_cutoff_seconds": 0.0,
		"suppressed_cap_seconds": 0.0,
		"suppressed_other_seconds": 0.0,
		"waiting_blocked_cutoff": 0,
		"waiting_blocked_cap": 0,
		"waiting_blocked_other": 0,
		"customers": {},
		"online_orders": {},
		"closing_snapshot_done": false,
	}
	if game_root != null and is_instance_valid(game_root) and service != null:
		game_root.phase_changed.connect(
			func(phase: int, _day_idx: int) -> void:
				if (
					phase == SharedTypes.Phase.CLOSING
					and not bool(tracker["closing_snapshot_done"])
				):
					tracker["closing_snapshot_done"] = true
					_poll_offer_tracker(service, tracker, game_root)
		)
	return tracker


func _record_suppression_entry(
	tracker: Dictionary,
	prev_state: int,
	disabled_reason: StringName
) -> void:
	var was_wait := (prev_state == ServiceController.OnlineOfferState.WAITING)
	if disabled_reason == &"cutoff_reached":
		tracker["suppressed_cutoff_episodes"] = int(tracker["suppressed_cutoff_episodes"]) + 1
		if was_wait:
			tracker["waiting_blocked_cutoff"] = int(tracker["waiting_blocked_cutoff"]) + 1
	elif disabled_reason == &"concurrent_cap_reached":
		tracker["suppressed_cap_episodes"] = int(tracker["suppressed_cap_episodes"]) + 1
		if was_wait:
			tracker["waiting_blocked_cap"] = int(tracker["waiting_blocked_cap"]) + 1
	else:
		tracker["suppressed_other_episodes"] = int(tracker["suppressed_other_episodes"]) + 1
		if was_wait:
			tracker["waiting_blocked_other"] = int(tracker["waiting_blocked_other"]) + 1


func _poll_offer_tracker(
	service: ServiceController,
	tracker: Dictionary,
	game_root: GameRoot = null
) -> void:
	var now := (
		game_root.get_service_elapsed()
		if game_root != null and is_instance_valid(game_root)
		else float(tracker["last_clock"])
	)
	var is_active_phase := true
	if game_root != null and is_instance_valid(game_root):
		var ph := game_root.get_phase()
		is_active_phase = (
			ph == SharedTypes.Phase.SERVING or ph == SharedTypes.Phase.CLOSING
		)

	var dt := maxf(0.0, now - float(tracker["last_clock"]))
	if (
		dt > 0.0
		and int(tracker["last_offer_state"]) == ServiceController.OnlineOfferState.UNAVAILABLE
	):
		var prev_reason := StringName(tracker["last_disabled_reason"])
		if prev_reason == &"cutoff_reached":
			tracker["suppressed_cutoff_seconds"] = (
				float(tracker["suppressed_cutoff_seconds"]) + dt
			)
		elif prev_reason == &"concurrent_cap_reached":
			tracker["suppressed_cap_seconds"] = float(tracker["suppressed_cap_seconds"]) + dt
		else:
			tracker["suppressed_other_seconds"] = float(tracker["suppressed_other_seconds"]) + dt

	var offer_v := service.get_online_offer_view()
	var offer_state := int(offer_v.get("offer_state", -1))
	var offer_gen := int(offer_v.get("offer_generation_number", 0))
	var preview_id := StringName(offer_v.get("preview_recipe_id", &""))
	var disabled_reason := StringName(offer_v.get("disabled_reason", &""))
	var prev_state := int(tracker["last_offer_state"])
	var active_gen := int(tracker["active_unaccepted_gen"])
	var is_available_valid := (
		offer_state == ServiceController.OnlineOfferState.AVAILABLE and preview_id != &""
	)

	if active_gen > 0 and (not is_available_valid or offer_gen > active_gen):
		var exp_at := float(tracker["active_expires_at"])
		if offer_state == ServiceController.OnlineOfferState.WAITING and offer_gen == active_gen:
			tracker["timer_expired"] = int(tracker["timer_expired"]) + 1
		elif (
			offer_state == ServiceController.OnlineOfferState.UNAVAILABLE
			and offer_gen == active_gen
		):
			if now < exp_at - 0.0001:
				if disabled_reason == &"cutoff_reached":
					tracker["terminated_cutoff"] = int(tracker["terminated_cutoff"]) + 1
				elif disabled_reason == &"concurrent_cap_reached":
					tracker["terminated_cap"] = int(tracker["terminated_cap"]) + 1
				else:
					tracker["terminated_other"] = int(tracker["terminated_other"]) + 1
			else:
				tracker["unknown_or_unclassified"] = (
					int(tracker["unknown_or_unclassified"]) + 1
				)
		else:
			tracker["unknown_or_unclassified"] = int(tracker["unknown_or_unclassified"]) + 1
		tracker["active_unaccepted_gen"] = 0
		tracker["active_expires_at"] = 0.0

	var prev_gen_num := int(tracker["last_gen_number"])
	var gen_delta := maxi(0, offer_gen - prev_gen_num)
	if gen_delta > 0:
		tracker["generated"] = int(tracker["generated"]) + gen_delta
		tracker["last_gen_number"] = offer_gen
		if is_available_valid and offer_gen > int(tracker["last_presented_gen"]):
			if gen_delta > 1:
				tracker["unknown_or_unclassified"] = (
					int(tracker["unknown_or_unclassified"]) + (gen_delta - 1)
				)
			tracker["presented"] = int(tracker["presented"]) + 1
			tracker["last_presented_gen"] = offer_gen
			tracker["active_unaccepted_gen"] = offer_gen
			tracker["active_expires_at"] = now + float(offer_v.get("offer_seconds_remaining", 0.0))
		else:
			tracker["unknown_or_unclassified"] = (
				int(tracker["unknown_or_unclassified"]) + gen_delta
			)
	elif is_available_valid and offer_gen > int(tracker["last_presented_gen"]):
		tracker["presented"] = int(tracker["presented"]) + 1
		tracker["last_presented_gen"] = offer_gen
		tracker["active_unaccepted_gen"] = offer_gen
		tracker["active_expires_at"] = now + float(offer_v.get("offer_seconds_remaining", 0.0))

	if is_active_phase and offer_state == ServiceController.OnlineOfferState.UNAVAILABLE:
		var entered_or_changed := (
			prev_state != ServiceController.OnlineOfferState.UNAVAILABLE
			or disabled_reason != StringName(tracker["last_disabled_reason"])
		)
		if entered_or_changed:
			_record_suppression_entry(tracker, prev_state, disabled_reason)

	tracker["last_clock"] = now
	tracker["last_offer_state"] = offer_state
	tracker["last_disabled_reason"] = disabled_reason

	var customers_map: Dictionary = tracker["customers"]
	for cv: Dictionary in service.get_customer_views():
		var cid := StringName(cv.get("customer_id", &""))
		if cid == &"":
			continue
		var oid := StringName(cv.get("order_id", &""))
		var c_state := int(cv.get("state", -1))
		var tbl_id := StringName(cv.get("assigned_table_id", &""))
		if not customers_map.has(cid):
			customers_map[cid] = {
				"order_id": oid,
				"entered_outside_queue": false,
				"reached_table": false,
				"status": SharedTypes.OrderStatus.OPEN,
			}
		var rec: Dictionary = customers_map[cid]
		if c_state == SharedTypes.CustomerState.OUTSIDE_WAITING:
			rec["entered_outside_queue"] = true
		if (
			c_state == SharedTypes.CustomerState.SEATED_WAITING
			or c_state == SharedTypes.CustomerState.EATING
			or tbl_id != &""
		):
			rec["reached_table"] = true

	for cid_v: Variant in customers_map.keys():
		var rec: Dictionary = customers_map[cid_v]
		var oid := StringName(rec.get("order_id", &""))
		if oid == &"":
			continue
		var ov := service.get_order_view(oid)
		if not ov.is_empty():
			rec["status"] = int(ov.get("status", -1))
			if StringName(ov.get("table_id_or_empty", &"")) != &"":
				rec["reached_table"] = true

	var online_orders: Dictionary = tracker["online_orders"]
	for dv: Dictionary in service.get_driver_views():
		var onl_oid := StringName(dv.get("order_id", &""))
		if onl_oid != &"" and not online_orders.has(onl_oid):
			online_orders[onl_oid] = SharedTypes.OrderStatus.OPEN
	for onl_oid_v: Variant in online_orders.keys():
		var onl_oid := StringName(onl_oid_v)
		var ov := service.get_order_view(onl_oid)
		if not ov.is_empty():
			online_orders[onl_oid] = int(ov.get("status", -1))


func _snapshot_lifecycle_metrics(
	game_root: GameRoot,
	service: ServiceController,
	tracker: Dictionary
) -> Dictionary:
	if game_root != null and is_instance_valid(game_root) and game_root.is_serving():
		_poll_offer_tracker(service, tracker, game_root)

	var offer_v := service.get_online_offer_view()
	var active_at_boundary := (
		1
		if (
			int(tracker["active_unaccepted_gen"]) > 0
			and int(offer_v.get("offer_state", -1)) == ServiceController.OnlineOfferState.AVAILABLE
		)
		else 0
	)

	var customers_map: Dictionary = tracker["customers"]
	var spawned_dinein := customers_map.size()
	var completed_dinein := 0
	var failed_dinein := 0
	var still_open_dinein := 0
	var still_open_outside := 0
	var still_open_seated := 0
	var entered_outside_queue := 0
	var reached_table := 0
	var queued_then_seated := 0
	var seated_directly := 0
	var failed_before_seating := 0
	var failed_after_seating := 0

	for cid_v: Variant in customers_map.keys():
		var rec: Dictionary = customers_map[cid_v]
		var queued := bool(rec.get("entered_outside_queue", false))
		var seated := bool(rec.get("reached_table", false))
		var st := int(rec.get("status", -1))
		if queued:
			entered_outside_queue += 1
		if seated:
			reached_table += 1
			if queued:
				queued_then_seated += 1
			else:
				seated_directly += 1
		if st == SharedTypes.OrderStatus.COMPLETED:
			completed_dinein += 1
		elif st == SharedTypes.OrderStatus.FAILED:
			failed_dinein += 1
			if seated:
				failed_after_seating += 1
			else:
				failed_before_seating += 1
		elif st == SharedTypes.OrderStatus.OPEN:
			still_open_dinein += 1
			if seated:
				still_open_seated += 1
			else:
				still_open_outside += 1

	var online_orders: Dictionary = tracker["online_orders"]
	var online_fulfilled := 0
	var online_failed := 0
	var online_still_open := 0
	for onl_oid_v: Variant in online_orders.keys():
		var st := int(online_orders[onl_oid_v])
		if st == SharedTypes.OrderStatus.COMPLETED:
			online_fulfilled += 1
		elif st == SharedTypes.OrderStatus.FAILED:
			online_failed += 1
		elif st == SharedTypes.OrderStatus.OPEN:
			online_still_open += 1

	return {
		"offers_generated": int(tracker["generated"]),
		"offers_presented": int(tracker["presented"]),
		"offers_accepted": int(tracker["accepted"]),
		"offers_timer_expired": int(tracker["timer_expired"]),
		"offers_terminated_cutoff": int(tracker["terminated_cutoff"]),
		"offers_terminated_cap": int(tracker["terminated_cap"]),
		"offers_terminated_other": int(tracker["terminated_other"]),
		"offers_active_at_boundary": active_at_boundary,
		"offers_unknown": int(tracker["unknown_or_unclassified"]),
		"suppressed_cutoff_episodes": int(tracker["suppressed_cutoff_episodes"]),
		"suppressed_cap_episodes": int(tracker["suppressed_cap_episodes"]),
		"suppressed_other_episodes": int(tracker["suppressed_other_episodes"]),
		"suppressed_cutoff_seconds": float(tracker["suppressed_cutoff_seconds"]),
		"suppressed_cap_seconds": float(tracker["suppressed_cap_seconds"]),
		"suppressed_other_seconds": float(tracker["suppressed_other_seconds"]),
		"waiting_blocked_cutoff": int(tracker["waiting_blocked_cutoff"]),
		"waiting_blocked_cap": int(tracker["waiting_blocked_cap"]),
		"waiting_blocked_other": int(tracker["waiting_blocked_other"]),
		"online_fulfilled": online_fulfilled,
		"online_failed": online_failed,
		"online_still_open": online_still_open,
		"spawned_dinein": spawned_dinein,
		"completed_dinein": completed_dinein,
		"failed_dinein": failed_dinein,
		"still_open_dinein": still_open_dinein,
		"still_open_outside_waiting": still_open_outside,
		"still_open_seated": still_open_seated,
		"entered_outside_queue": entered_outside_queue,
		"reached_table": reached_table,
		"queued_then_seated": queued_then_seated,
		"seated_directly": seated_directly,
		"failed_before_seating": failed_before_seating,
		"failed_after_seating": failed_after_seating,
	}


func _advance_clock_and_poll(
	game_root: GameRoot,
	service: ServiceController,
	duration_seconds: float,
	tracker: Dictionary
) -> bool:
	var steps := roundi(maxf(0.0, duration_seconds) / TICK_STEP)
	if duration_seconds > 0.0 and steps <= 0:
		steps = 1
	for _i in range(steps):
		if not game_root.is_serving():
			return false
		game_root._process(TICK_STEP)
		if game_root.is_serving():
			_poll_offer_tracker(service, tracker, game_root)
	return game_root.is_serving()


func _is_target_order_valid(service: ServiceController, target: Dictionary) -> bool:
	var ord_id := StringName(target.get("order_id", &""))
	if ord_id == &"":
		return false
	var ov := service.get_order_view(ord_id)
	if int(ov.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
		return false
	if float(ov.get("seconds_remaining", 0.0)) <= 0.0:
		return false
	var kind := int(target.get("kind", -1))
	var target_id := StringName(target.get("target_id", &""))
	if kind == SharedTypes.OrderKind.DINE_IN:
		var tv := service.get_table_view(target_id)
		return (
			int(tv.get("state", -1)) == SharedTypes.TableState.OCCUPIED_WAITING
			and StringName(tv.get("order_id_or_empty", &"")) == ord_id
		)
	if kind == SharedTypes.OrderKind.ONLINE:
		var dv := service.get_driver_view(target_id)
		return (
			not dv.is_empty()
			and bool(dv.get("serveable", false))
			and StringName(dv.get("order_id", &"")) == ord_id
		)
	return false


func _cleanup_aborted_prep(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	tracker: Dictionary
) -> void:
	# Discard any incomplete item in hand first.
	if not kitchen.get_held_item_view().is_empty():
		if not _advance_clock_and_poll(game_root, service, DUR_TRASH_CLEANUP, tracker):
			return
		var held := kitchen.get_held_item_view()
		if StringName(held.get("plate_id", &"")) != &"":
			if not (held.get("parts", []) as Array).is_empty():
				kitchen.on_interactable_clicked(&"trash")
			if not _advance_clock_and_poll(game_root, service, DUR_PLATE_RACK_RETURN, tracker):
				return
			kitchen.on_interactable_clicked(&"plate_rack")
		else:
			kitchen.on_interactable_clicked(&"trash")

	# Pick up and discard any partial food staged on work_table_stage, returning clean plate.
	var staged := kitchen.get_work_table_view(&"work_table")
	if not staged.is_empty() and kitchen.get_held_item_view().is_empty():
		if not _advance_clock_and_poll(game_root, service, DUR_PICKUP_PLATED, tracker):
			return
		kitchen.on_interactable_clicked(&"work_table_stage")
		var picked := kitchen.get_held_item_view()
		if not picked.is_empty():
			if not _advance_clock_and_poll(game_root, service, DUR_TRASH_CLEANUP, tracker):
				return
			if StringName(picked.get("plate_id", &"")) != &"":
				if not (picked.get("parts", []) as Array).is_empty():
					kitchen.on_interactable_clicked(&"trash")
				if not _advance_clock_and_poll(game_root, service, DUR_PLATE_RACK_RETURN, tracker):
					return
				kitchen.on_interactable_clicked(&"plate_rack")
			else:
				kitchen.on_interactable_clicked(&"trash")


func _simulate_fair_campaign(sc: Dictionary) -> Dictionary:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var starting_cash := int(run.get_run_view().get("cash", 0))

	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = int(sc.get("noise_seed", DEFAULT_NOISE_SEED))
	var use_noise := bool(sc.get("noise", false))

	var slot_order: Array[StringName] = [
		&"slot_utility_01",
		&"slot_utility_02",
		&"slot_utility_03",
		&"slot_utility_04",
	]
	var purchased_boxes: Array[Dictionary] = []
	var day_reports: Array[Dictionary] = []

	var total_dinein_rev := 0
	var total_online_rev := 0
	var total_ing_cost := 0
	var total_fix_cost := 0
	var total_el_cost := 0
	var total_refunds := 0
	var total_stockout_orders := 0
	var total_stockout_episodes := 0
	var total_mid_prep_expiries := 0
	var total_planned_quota := 0
	var total_generated_dinein := 0
	var total_completed_dinein := 0
	var total_failed_dinein := 0
	var total_still_open_dinein := 0
	var total_entered_outside_queue := 0
	var total_reached_table := 0
	var total_queued_then_seated := 0
	var total_seated_directly := 0
	var total_failed_before_seating := 0
	var total_failed_after_seating := 0
	var total_offers_generated := 0
	var total_online_presented := 0
	var total_online_accepted := 0
	var total_online_expired := 0
	var total_offers_timer_expired := 0
	var total_offers_terminated_cutoff := 0
	var total_offers_terminated_cap := 0
	var total_offers_terminated_other := 0
	var total_offers_active_at_boundary := 0
	var total_offers_unknown := 0
	var total_suppressed_cutoff_episodes := 0
	var total_suppressed_cap_episodes := 0
	var total_suppressed_cutoff_seconds := 0.0
	var total_suppressed_cap_seconds := 0.0
	var total_online_fulfilled := 0
	var total_online_failed := 0
	var total_online_still_open := 0
	var total_planning_restock_time := 0.0
	var total_serving_restock_time := 0.0
	var total_restock_trips := 0
	var total_duration := 0.0

	var active_tracker_box := { "tracker": null }
	game_root.phase_changed.connect(func(phase: int, _day_idx: int) -> void:
		if phase == SharedTypes.Phase.CLOSING and active_tracker_box["tracker"] != null:
			var t_ref: Dictionary = active_tracker_box["tracker"]
			if not bool(t_ref["closing_snapshot_done"]):
				t_ref["closing_snapshot_done"] = true
				_poll_offer_tracker(service, t_ref, game_root)
	)

	for day in range(1, 8):
		var target_menu: Array[StringName] = []
		target_menu.assign(sc["target_recipes_by_day"][day])
		run.select_daily_menu(target_menu)

		var target_boxes := int(sc["target_boxes_by_day"].get(day, 1))
		while (
			_get_owned_box_ids(run).size() < target_boxes
			and purchased_boxes.size() < slot_order.size()
		):
			var next_slot := slot_order[purchased_boxes.size()]
			if run.request_fixture_purchase(&"box", next_slot):
				purchased_boxes.append({
					"day": day,
					"slot": next_slot,
					"cost": 40000,
				})
			else:
				break

		var rv_plan := run.get_run_view()
		var planned_quota := int(rv_plan["planned_dinein_quota"])
		var potential_demand := int(rv_plan["potential_demand"])
		var storage_ids := _get_owned_box_ids(run)

		var online_headroom := 4 if (bool(sc["accept_online"]) and planned_quota > 2) else 0
		var planning_orders := planned_quota + online_headroom
		var planning_bias := 1.0
		var penalized_ing := &""
		if use_noise and day >= 2 and noise_rng.randf() < 0.40:
			planning_bias = 0.75
			var pool := _get_active_non_beras_ingredients(kitchen, target_menu)
			if not pool.is_empty():
				penalized_ing = pool[noise_rng.randi_range(0, pool.size() - 1)]

		var plan_tracker := _make_offer_tracker()
		var plan_shop := _proportional_restock_chronological(
			game_root,
			kitchen,
			service,
			run,
			ui,
			target_menu,
			planning_orders,
			storage_ids,
			true,
			plan_tracker,
			penalized_ing,
			planning_bias
		)
		var day_planning_restock_time := float(plan_shop["duration"])
		var day_restock_trips := int(plan_shop["trips"])
		kitchen.clear_selected_target()

		game_root.start_service_requested()

		var safety_steps := 0
		var day_stockout_order_ids: Dictionary[StringName, bool] = {}
		var day_stockout_episodes := 0
		var day_mid_prep_expiries := 0
		var day_serving_restock_time := 0.0
		var in_stockout_episode := false
		var tracker := _make_offer_tracker()
		active_tracker_box["tracker"] = tracker
		if game_root.is_serving():
			_poll_offer_tracker(service, tracker, game_root)
		var skipped_offer_gens: Dictionary[int, bool] = {}

		while game_root.is_serving() and safety_steps < 12000:
			safety_steps += 1
			_poll_offer_tracker(service, tracker, game_root)

			var step_res := _step_service_chronological(
				game_root,
				kitchen,
				service,
				run,
				ui,
				target_menu,
				storage_ids,
				bool(sc["accept_online"]),
				use_noise,
				noise_rng,
				skipped_offer_gens,
				tracker
			)
			day_serving_restock_time += float(step_res["restock_duration"])
			day_restock_trips += int(step_res["restock_trips"])
			var blocked_ids: Array = step_res["blocked_order_ids"]
			for oid: Variant in blocked_ids:
				day_stockout_order_ids[StringName(oid)] = true
			if not blocked_ids.is_empty():
				if not in_stockout_episode:
					day_stockout_episodes += 1
					in_stockout_episode = true
			else:
				in_stockout_episode = false
			if bool(step_res["expired_mid_prep"]):
				day_mid_prep_expiries += 1

		active_tracker_box["tracker"] = null
		var snap := _snapshot_lifecycle_metrics(game_root, service, tracker)

		var settle := run.get_day_settlement_view(day)
		var gen_d := int(snap["spawned_dinein"])
		var ok_d := int(settle.get("completed_dinein_count", 0))
		var fail_d := int(settle.get("failed_dinein_count", 0))
		var ok_o := int(settle.get("completed_online_count", 0))
		var fail_o := int(settle.get("failed_online_count", 0))
		var rev_d := int(settle.get("order_revenue_dinein", 0))
		var rev_o := int(settle.get("order_revenue_online", 0))
		var ing_c := int(settle.get("ingredient_purchase_total", 0))
		var fix_c := int(settle.get("fixture_purchase_total", 0))
		var el_c := int(settle.get("electricity_charge", 0))
		var ref_c := int(settle.get("refund_total", 0))
		var dur := float(game_root.get_service_elapsed())
		var day_nonacc := (
			int(snap["offers_timer_expired"])
			+ int(snap["offers_terminated_cutoff"])
			+ int(snap["offers_terminated_cap"])
			+ int(snap["offers_terminated_other"])
			+ int(snap["offers_unknown"])
		)

		total_dinein_rev += rev_d
		total_online_rev += rev_o
		total_ing_cost += ing_c
		total_fix_cost += fix_c
		total_el_cost += el_c
		total_refunds += ref_c
		total_stockout_orders += day_stockout_order_ids.size()
		total_stockout_episodes += day_stockout_episodes
		total_mid_prep_expiries += day_mid_prep_expiries
		total_planned_quota += planned_quota
		total_generated_dinein += gen_d
		total_completed_dinein += int(snap["completed_dinein"])
		total_failed_dinein += int(snap["failed_dinein"])
		total_still_open_dinein += int(snap["still_open_dinein"])
		total_entered_outside_queue += int(snap["entered_outside_queue"])
		total_reached_table += int(snap["reached_table"])
		total_queued_then_seated += int(snap["queued_then_seated"])
		total_seated_directly += int(snap["seated_directly"])
		total_failed_before_seating += int(snap["failed_before_seating"])
		total_failed_after_seating += int(snap["failed_after_seating"])
		total_offers_generated += int(snap["offers_generated"])
		total_online_presented += int(snap["offers_presented"])
		total_online_accepted += int(snap["offers_accepted"])
		total_online_expired += day_nonacc
		total_offers_timer_expired += int(snap["offers_timer_expired"])
		total_offers_terminated_cutoff += int(snap["offers_terminated_cutoff"])
		total_offers_terminated_cap += int(snap["offers_terminated_cap"])
		total_offers_terminated_other += int(snap["offers_terminated_other"])
		total_offers_active_at_boundary += int(snap["offers_active_at_boundary"])
		total_offers_unknown += int(snap["offers_unknown"])
		total_suppressed_cutoff_episodes += int(snap["suppressed_cutoff_episodes"])
		total_suppressed_cap_episodes += int(snap["suppressed_cap_episodes"])
		total_suppressed_cutoff_seconds += float(snap["suppressed_cutoff_seconds"])
		total_suppressed_cap_seconds += float(snap["suppressed_cap_seconds"])
		total_online_fulfilled += int(snap["online_fulfilled"])
		total_online_failed += int(snap["online_failed"])
		total_online_still_open += int(snap["online_still_open"])
		total_planning_restock_time += day_planning_restock_time
		total_serving_restock_time += day_serving_restock_time
		total_restock_trips += day_restock_trips
		total_duration += dur

		day_reports.append({
			"day": day,
			"active_recipes": target_menu.duplicate(),
			"boxes": storage_ids.size(),
			"slots": storage_ids.size() * KitchenController.BOX_SLOT_COUNT,
			"unit_cap": (
				storage_ids.size()
				* KitchenController.BOX_SLOT_COUNT
				* KitchenController.BOX_SLOT_CAPACITY
			),
			"potential_demand": potential_demand,
			"planned_quota": planned_quota,
			"generated_dinein": gen_d,
			"spawned_dinein": gen_d,
			"completed_dinein": int(snap["completed_dinein"]),
			"failed_dinein": int(snap["failed_dinein"]),
			"settle_completed_dinein": ok_d,
			"settle_failed_dinein": fail_d,
			"still_open_dinein": int(snap["still_open_dinein"]),
			"entered_outside_queue": int(snap["entered_outside_queue"]),
			"reached_table": int(snap["reached_table"]),
			"queued_then_seated": int(snap["queued_then_seated"]),
			"seated_directly": int(snap["seated_directly"]),
			"failed_before_seating": int(snap["failed_before_seating"]),
			"failed_after_seating": int(snap["failed_after_seating"]),
			"offers_generated": int(snap["offers_generated"]),
			"online_presented": int(snap["offers_presented"]),
			"online_accepted": int(snap["offers_accepted"]),
			"online_expired": day_nonacc,
			"offers_timer_expired": int(snap["offers_timer_expired"]),
			"offers_terminated_cutoff": int(snap["offers_terminated_cutoff"]),
			"offers_terminated_cap": int(snap["offers_terminated_cap"]),
			"offers_terminated_other": int(snap["offers_terminated_other"]),
			"offers_active_at_boundary": int(snap["offers_active_at_boundary"]),
			"offers_unknown": int(snap["offers_unknown"]),
			"suppressed_cutoff_episodes": int(snap["suppressed_cutoff_episodes"]),
			"suppressed_cap_episodes": int(snap["suppressed_cap_episodes"]),
			"suppressed_cutoff_seconds": float(snap["suppressed_cutoff_seconds"]),
			"suppressed_cap_seconds": float(snap["suppressed_cap_seconds"]),
			"completed_online": int(snap["online_fulfilled"]),
			"failed_online": int(snap["online_failed"]),
			"online_still_open": int(snap["online_still_open"]),
			"settle_completed_online": ok_o,
			"settle_failed_online": fail_o,
			"debt_before": int(settle.get("penalty_debt_before", 0)),
			"debt_after": int(settle.get("penalty_debt_after", 0)),
			"stockout_orders": day_stockout_order_ids.size(),
			"stockout_episodes": day_stockout_episodes,
			"mid_prep_expiries": day_mid_prep_expiries,
			"plan_restock_dur": day_planning_restock_time,
			"srv_restock_dur": day_serving_restock_time,
			"restock_trips": day_restock_trips,
			"rev_dinein": rev_d,
			"rev_online": rev_o,
			"ing_cost": ing_c,
			"fix_cost": fix_c,
			"el_cost": el_c,
			"refund": ref_c,
			"end_cash": int(settle.get("end_cash", 0)),
			"dur": dur,
		})

		if day < 7:
			game_root.request_continue_from_results()

	var final_rv := run.get_run_view()
	var result := {
		"id": String(sc["id"]),
		"name": String(sc["name"]),
		"starting_cash": starting_cash,
		"days": day_reports,
		"purchased_boxes": purchased_boxes,
		"final_phase": game_root.get_phase(),
		"day7_outcome": int(final_rv.get("goal_outcome", -1)),
		"final_cash": int(final_rv.get("cash", 0)),
		"day_7_target": int(final_rv.get("day_7_target", 0)),
		"total_dinein_rev": total_dinein_rev,
		"total_online_rev": total_online_rev,
		"total_cash_earned": total_dinein_rev + total_online_rev,
		"total_ing_cost": total_ing_cost,
		"total_fix_cost": total_fix_cost,
		"total_el_cost": total_el_cost,
		"total_refunds": total_refunds,
		"total_stockout_orders": total_stockout_orders,
		"total_stockout_episodes": total_stockout_episodes,
		"total_mid_prep_expiries": total_mid_prep_expiries,
		"total_planned_quota": total_planned_quota,
		"total_generated_dinein": total_generated_dinein,
		"total_completed_dinein": total_completed_dinein,
		"total_failed_dinein": total_failed_dinein,
		"total_still_open_dinein": total_still_open_dinein,
		"total_entered_outside_queue": total_entered_outside_queue,
		"total_reached_table": total_reached_table,
		"total_queued_then_seated": total_queued_then_seated,
		"total_seated_directly": total_seated_directly,
		"total_failed_before_seating": total_failed_before_seating,
		"total_failed_after_seating": total_failed_after_seating,
		"total_offers_generated": total_offers_generated,
		"total_online_presented": total_online_presented,
		"total_online_accepted": total_online_accepted,
		"total_online_expired": total_online_expired,
		"total_offers_timer_expired": total_offers_timer_expired,
		"total_offers_terminated_cutoff": total_offers_terminated_cutoff,
		"total_offers_terminated_cap": total_offers_terminated_cap,
		"total_offers_terminated_other": total_offers_terminated_other,
		"total_offers_active_at_boundary": total_offers_active_at_boundary,
		"total_offers_unknown": total_offers_unknown,
		"total_suppressed_cutoff_episodes": total_suppressed_cutoff_episodes,
		"total_suppressed_cap_episodes": total_suppressed_cap_episodes,
		"total_suppressed_cutoff_seconds": total_suppressed_cutoff_seconds,
		"total_suppressed_cap_seconds": total_suppressed_cap_seconds,
		"total_online_fulfilled": total_online_fulfilled,
		"total_online_failed": total_online_failed,
		"total_online_still_open": total_online_still_open,
		"total_completed_orders": total_completed_dinein + total_online_fulfilled,
		"total_failed_orders": total_failed_dinein + total_online_failed,
		"total_planning_restock_time": total_planning_restock_time,
		"total_serving_restock_time": total_serving_restock_time,
		"total_restock_time": total_planning_restock_time + total_serving_restock_time,
		"total_restock_trips": total_restock_trips,
		"total_duration": total_duration,
	}
	game_root.free()
	await process_frame
	return result


func _get_owned_box_ids(run: RunController) -> Array[StringName]:
	var boxes: Array[StringName] = []
	var installed: Dictionary = run.get_run_view().get("installed_fixtures", {})
	for inst_id: Variant in installed:
		var rec: Dictionary = installed[inst_id]
		if int(rec.get("fixture_kind", -1)) == SharedTypes.FixtureKind.BOX:
			boxes.append(StringName(inst_id))
	boxes.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return boxes


func _get_active_non_beras_ingredients(
	kitchen: KitchenController,
	menu: Array[StringName]
) -> Array[StringName]:
	var pool: Array[StringName] = []
	for rid in menu:
		var rdef := kitchen.get_recipe_def(rid)
		if rdef == null:
			continue
		for part in rdef.required_parts:
			if part != null and part.ingredient_id != &"beras" and not pool.has(part.ingredient_id):
				pool.append(part.ingredient_id)
	pool.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return pool


func _compute_recipe_probabilities(run: RunController, menu: Array[StringName]) -> Dictionary:
	var weights: Dictionary = {}
	var total := 0.0
	for rid in menu:
		var entry := run.economy_config.get_recipe_entry(rid)
		var price := entry.dine_in_price if entry != null and entry.dine_in_price > 0 else 10000
		var w := 1.0 / float(price)
		weights[rid] = w
		total += w
	var probs: Dictionary = {}
	for rid in menu:
		probs[rid] = float(weights[rid]) / total if total > 0.0 else 1.0 / float(menu.size())
	return probs


func _compute_ingredient_targets(
	run: RunController,
	kitchen: KitchenController,
	menu: Array[StringName],
	target_orders: int,
	penalized_ing: StringName,
	penalty_factor: float
) -> Dictionary:
	var probs := _compute_recipe_probabilities(run, menu)
	var expected: Dictionary = {}
	for rid in menu:
		var rdef := kitchen.get_recipe_def(rid)
		if rdef == null:
			continue
		var p := float(probs.get(rid, 0.0))
		for part in rdef.required_parts:
			if part == null:
				continue
			var iid := part.ingredient_id
			expected[iid] = float(expected.get(iid, 0.0)) + float(target_orders) * p

	var targets: Dictionary = {}
	var rice_portions := int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0))
	var rem_rice_orders := maxi(0, target_orders - rice_portions)
	targets[&"beras"] = ceili(float(rem_rice_orders) / 5.0)
	for iid: Variant in expected:
		var ing_id := StringName(iid)
		if ing_id == &"beras":
			continue
		var raw_need := float(expected[ing_id])
		if ing_id == penalized_ing:
			raw_need *= penalty_factor
		targets[ing_id] = maxi(1, ceili(raw_need) + 1)
	return targets


func _proportional_restock_chronological(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController,
	ui: GameUI,
	menu: Array[StringName],
	target_orders: int,
	storage_ids: Array[StringName],
	is_planning: bool,
	tracker: Dictionary,
	penalized_ing: StringName = &"",
	penalty_factor: float = 1.0
) -> Dictionary:
	if target_orders <= 0:
		return { "duration": 0.0, "trips": 0, "units_bought": 0 }
	var targets := _compute_ingredient_targets(
		run, kitchen, menu, target_orders, penalized_ing, penalty_factor
	)
	var baskets_by_box := _plan_baskets_for_boxes(
		run, kitchen, menu, targets, storage_ids, is_planning
	)
	if baskets_by_box.is_empty():
		return { "duration": 0.0, "trips": 0, "units_bought": 0 }

	var total_duration := 0.0
	var trips := 0
	var units_bought := 0
	for unit_id in storage_ids:
		if not baskets_by_box.has(unit_id):
			continue
		var basket: Dictionary = baskets_by_box[unit_id]
		if basket.is_empty():
			continue
		if not is_planning and not game_root.is_serving():
			break
		var res := _execute_shop_basket_interaction(
			game_root, kitchen, service, run, ui, unit_id, basket, is_planning, tracker
		)
		total_duration += float(res["duration"])
		if bool(res["opened"]):
			trips += 1
		if bool(res["committed"]):
			for qty_v: Variant in basket.values():
				units_bought += int(qty_v)
	return { "duration": total_duration, "trips": trips, "units_bought": units_bought }


func _plan_baskets_for_boxes(
	run: RunController,
	kitchen: KitchenController,
	menu: Array[StringName],
	targets: Dictionary,
	storage_ids: Array[StringName],
	is_planning: bool
) -> Dictionary:
	var baskets: Dictionary = {}
	for unit_id in storage_ids:
		baskets[unit_id] = {}
	var planned_total: Dictionary = {}
	var cash_left := int(run.get_run_view().get("cash", 0))

	var ing_order: Array[StringName] = [&"beras"]
	ing_order.append_array(_get_active_non_beras_ingredients(kitchen, menu))

	# Guarantee at least 1 unit of each currently missing required ingredient when room exists.
	for ing_id in ing_order:
		var cur := (
			_count_ingredient(kitchen, storage_ids, ing_id)
			+ _count_pending(kitchen, ing_id)
			+ int(planned_total.get(ing_id, 0))
		)
		if cur == 0 and int(targets.get(ing_id, 0)) > 0:
			var cost := run.economy_config.get_ingredient_price(ing_id)
			if cost > 0 and cost <= cash_left:
				if _assign_to_box_basket(kitchen, storage_ids, baskets, ing_id, 1):
					planned_total[ing_id] = int(planned_total.get(ing_id, 0)) + 1
					cash_left -= cost

	var active_targets := targets.duplicate()
	for _round in range(60):
		var best_ing := &""
		var lowest_ratio := 1.0
		var best_deficit := 0
		for ing_id in ing_order:
			var want := int(active_targets.get(ing_id, 0))
			if want <= 0:
				continue
			var cur := (
				_count_ingredient(kitchen, storage_ids, ing_id)
				+ _count_pending(kitchen, ing_id)
				+ int(planned_total.get(ing_id, 0))
			)
			var deficit := want - cur
			if deficit <= 0:
				continue
			var ratio := float(cur) / float(want)
			if best_ing == &"" or ratio < lowest_ratio:
				lowest_ratio = ratio
				best_ing = ing_id
				best_deficit = deficit
		if best_ing == &"" or best_deficit <= 0:
			break
		var unit_price := run.economy_config.get_ingredient_price(best_ing)
		if unit_price <= 0 or cash_left < unit_price:
			active_targets[best_ing] = 0
			continue
		var max_affordable := cash_left / unit_price
		var step_qty := mini(5 if is_planning else 1, mini(best_deficit, max_affordable))
		var placed := false
		if step_qty > 0 and _assign_to_box_basket(kitchen, storage_ids, baskets, best_ing, step_qty):
			planned_total[best_ing] = int(planned_total.get(best_ing, 0)) + step_qty
			cash_left -= step_qty * unit_price
			placed = true
		elif step_qty > 1 and _assign_to_box_basket(kitchen, storage_ids, baskets, best_ing, 1):
			planned_total[best_ing] = int(planned_total.get(best_ing, 0)) + 1
			cash_left -= unit_price
			placed = true
		if not placed:
			active_targets[best_ing] = 0

	var non_empty: Dictionary = {}
	for unit_id in storage_ids:
		var b: Dictionary = baskets[unit_id]
		if not b.is_empty():
			non_empty[unit_id] = b
	return non_empty


func _assign_to_box_basket(
	kitchen: KitchenController,
	storage_ids: Array[StringName],
	baskets: Dictionary,
	ing_id: StringName,
	qty: int
) -> bool:
	# First pass: prefer boxes that already hold or plan this ingredient to minimize slot splits.
	for allow_new_slot_box in [false, true]:
		for unit_id in storage_ids:
			var existing_basket: Dictionary = baskets[unit_id]
			if not allow_new_slot_box:
				var has_match := existing_basket.has(ing_id)
				if not has_match:
					for s: Dictionary in kitchen.get_storage_unit_view(unit_id).get("slots", []):
						if StringName(s.get("ingredient_id", &"")) == ing_id:
							has_match = true
							break
				if not has_match:
					continue
			var candidate := existing_basket.duplicate()
			candidate[ing_id] = int(candidate.get(ing_id, 0)) + qty
			if kitchen.can_receive_stock_basket(candidate, unit_id):
				baskets[unit_id] = candidate
				return true
	return false


func _advance_shop_time(
	game_root: GameRoot,
	service: ServiceController,
	duration_seconds: float,
	is_planning: bool,
	tracker: Dictionary
) -> bool:
	if is_planning:
		return game_root.get_phase() == SharedTypes.Phase.PLANNING
	return _advance_clock_and_poll(game_root, service, duration_seconds, tracker)


func _execute_shop_basket_interaction(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController,
	ui: GameUI,
	unit_id: StringName,
	basket: Dictionary,
	is_planning: bool,
	tracker: Dictionary
) -> Dictionary:
	var expected_phase := SharedTypes.Phase.PLANNING if is_planning else SharedTypes.Phase.SERVING
	var elapsed_shop := 0.0

	# 1. Open shop interaction (DUR_SHOP_OPEN before target click + `beli`).
	if not _advance_shop_time(game_root, service, DUR_SHOP_OPEN, is_planning, tracker):
		return { "duration": elapsed_shop, "opened": false, "committed": false }
	elapsed_shop += DUR_SHOP_OPEN
	if (
		game_root.get_phase() != expected_phase
		or not kitchen.has_storage_unit(unit_id)
		or not run.can_purchase_ingredients_for_storage(unit_id)
	):
		return { "duration": elapsed_shop, "opened": false, "committed": false }

	kitchen.on_interactable_clicked(unit_id)
	if not kitchen.execute_allowed_command(&"beli") or not ui.is_ingredient_shop_open():
		return { "duration": elapsed_shop, "opened": false, "committed": false }

	# 2. Click `+` chronologically per ingredient unit (`DUR_SHOP_ADJUST_UNIT` per unit).
	var sorted_ings: Array[StringName] = []
	for raw_ing: Variant in basket.keys():
		sorted_ings.append(StringName(raw_ing))
	sorted_ings.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	for ing_id in sorted_ings:
		var qty := int(basket.get(ing_id, 0))
		for _u in range(qty):
			if not _advance_shop_time(game_root, service, DUR_SHOP_ADJUST_UNIT, is_planning, tracker):
				if ui.is_ingredient_shop_open():
					ui.close_ingredient_shop()
				return { "duration": elapsed_shop, "opened": true, "committed": false }
			elapsed_shop += DUR_SHOP_ADJUST_UNIT
			if game_root.get_phase() != expected_phase or not ui.is_ingredient_shop_open():
				if ui.is_ingredient_shop_open():
					ui.close_ingredient_shop()
				return { "duration": elapsed_shop, "opened": true, "committed": false }
			if not ui.adjust_shop_quantity(ing_id, 1):
				break

	# 3. Checkout (`DUR_SHOP_CHECKOUT`) or cancel (`DUR_SHOP_CANCEL`) + revalidate before commit.
	var staged_basket := ui.get_shop_basket()
	if staged_basket.is_empty():
		if _advance_shop_time(game_root, service, DUR_SHOP_CANCEL, is_planning, tracker):
			elapsed_shop += DUR_SHOP_CANCEL
		if ui.is_ingredient_shop_open():
			ui.close_ingredient_shop()
		return { "duration": elapsed_shop, "opened": true, "committed": false }

	if not _advance_shop_time(game_root, service, DUR_SHOP_CHECKOUT, is_planning, tracker):
		if ui.is_ingredient_shop_open():
			ui.close_ingredient_shop()
		return { "duration": elapsed_shop, "opened": true, "committed": false }
	elapsed_shop += DUR_SHOP_CHECKOUT

	if (
		game_root.get_phase() != expected_phase
		or not ui.is_ingredient_shop_open()
		or not kitchen.has_storage_unit(unit_id)
		or not run.can_purchase_ingredients_for_storage(unit_id)
	):
		if ui.is_ingredient_shop_open():
			ui.close_ingredient_shop()
		return { "duration": elapsed_shop, "opened": true, "committed": false }

	var committed := ui.submit_ingredient_shop()
	if ui.is_ingredient_shop_open():
		ui.close_ingredient_shop()
	return { "duration": elapsed_shop, "opened": true, "committed": committed }


func _count_ingredient(
	kitchen: KitchenController,
	storage_ids: Array[StringName],
	ing_id: StringName
) -> int:
	var total := 0
	for unit_id in storage_ids:
		for s: Dictionary in kitchen.get_storage_unit_view(unit_id).get("slots", []):
			if StringName(s.get("ingredient_id", &"")) == ing_id:
				total += int(s.get("quantity", 0))
	return total


func _count_pending(kitchen: KitchenController, ing_id: StringName) -> int:
	var total := 0
	for p: Dictionary in kitchen.get_pending_delivery_views():
		if StringName(p.get("ingredient_id", &"")) == ing_id:
			total += int(p.get("quantity", 0))
	return total


func _step_service_chronological(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController,
	ui: GameUI,
	menu: Array[StringName],
	storage_ids: Array[StringName],
	accept_online: bool,
	use_noise: bool,
	noise_rng: RandomNumberGenerator,
	skipped_offer_gens: Dictionary,
	tracker: Dictionary
) -> Dictionary:
	# 0. Proactive mid-service replenishment when remaining queue window >= ~80s (>=4 spawns).
	var restock_dur := 0.0
	var restock_trips := 0
	var qv := service.get_customer_queue_view()
	var rem_queue := int(qv.get("day_queue_remaining", 0))
	if rem_queue >= 4:
		var rem_orders := (
			rem_queue
			+ int(qv.get("outside_dinein_count", 0))
			+ int(qv.get("in_shop_count", 0))
			+ int(qv.get("online_open_count", 0))
		)
		var shop_res := _proportional_restock_chronological(
			game_root, kitchen, service, run, ui, menu, rem_orders, storage_ids, false, tracker
		)
		restock_dur += float(shop_res["duration"])
		restock_trips += int(shop_res["trips"])
		if not game_root.is_serving():
			return {
				"blocked_order_ids": [],
				"expired_mid_prep": false,
				"restock_duration": restock_dur,
				"restock_trips": restock_trips,
			}
		qv = service.get_customer_queue_view()

	# 1. Wash dirty plates if rack is getting low (<= 1 clean).
	if (
		int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) <= 1
		and int(kitchen.get_washer_view()["dirty_plate_count"]) > 0
		and kitchen.get_held_item_view().is_empty()
	):
		if not _advance_clock_and_poll(game_root, service, DUR_WASHER_CUCI, tracker):
			return {
				"blocked_order_ids": [],
				"expired_mid_prep": false,
				"restock_duration": restock_dur,
				"restock_trips": restock_trips,
			}
		kitchen.on_interactable_clicked(&"washer")
		if kitchen.execute_allowed_command(&"cuci") and not kitchen.get_held_item_view().is_empty():
			if not _advance_clock_and_poll(game_root, service, DUR_PLATE_RACK_RETURN, tracker):
				return {
					"blocked_order_ids": [],
					"expired_mid_prep": false,
					"restock_duration": restock_dur,
					"restock_trips": restock_trips,
				}
			kitchen.on_interactable_clicked(&"plate_rack")
		return {
			"blocked_order_ids": [],
			"expired_mid_prep": false,
			"restock_duration": restock_dur,
			"restock_trips": restock_trips,
		}

	# 2. Clean dirty dining tables immediately so waiting FIFO diners can sit.
	for tbl_id: StringName in service.get_registered_table_ids():
		var tv := service.get_table_view(tbl_id)
		if int(tv.get("state", -1)) == SharedTypes.TableState.DIRTY:
			if not _advance_clock_and_poll(game_root, service, DUR_DIRTY_TABLE_CLEAN, tracker):
				return {
					"blocked_order_ids": [],
					"expired_mid_prep": false,
					"restock_duration": restock_dur,
					"restock_trips": restock_trips,
				}
			if int(service.get_table_view(tbl_id).get("state", -1)) == SharedTypes.TableState.DIRTY:
				kitchen.on_interactable_clicked(tbl_id)
				kitchen.execute_allowed_command(&"bersihkan")
				_poll_offer_tracker(service, tracker, game_root)
			return {
				"blocked_order_ids": [],
				"expired_mid_prep": false,
				"restock_duration": restock_dur,
				"restock_trips": restock_trips,
			}

	# 3. Wash any dirty plates before starting new dishes.
	if (
		int(kitchen.get_washer_view()["dirty_plate_count"]) > 0
		and kitchen.get_held_item_view().is_empty()
	):
		if not _advance_clock_and_poll(game_root, service, DUR_WASHER_CUCI, tracker):
			return {
				"blocked_order_ids": [],
				"expired_mid_prep": false,
				"restock_duration": restock_dur,
				"restock_trips": restock_trips,
			}
		kitchen.on_interactable_clicked(&"washer")
		if kitchen.execute_allowed_command(&"cuci") and not kitchen.get_held_item_view().is_empty():
			if not _advance_clock_and_poll(game_root, service, DUR_PLATE_RACK_RETURN, tracker):
				return {
					"blocked_order_ids": [],
					"expired_mid_prep": false,
					"restock_duration": restock_dur,
					"restock_trips": restock_trips,
				}
			kitchen.on_interactable_clicked(&"plate_rack")
		return {
			"blocked_order_ids": [],
			"expired_mid_prep": false,
			"restock_duration": restock_dur,
			"restock_trips": restock_trips,
		}

	# 4. Periodic online offer acceptance: advance DUR_ONLINE_ACCEPT BEFORE executing `terima`.
	if accept_online and service.get_online_acceptance_enabled():
		var offer_v := service.get_online_offer_view()
		var preview_id := StringName(offer_v.get("preview_recipe_id", &""))
		var gen := int(offer_v.get("offer_generation_number", 0))
		if use_noise and gen > 0 and not skipped_offer_gens.has(gen):
			skipped_offer_gens[gen] = noise_rng.randf() < 0.30
		var is_skipped := bool(skipped_offer_gens.get(gen, false))
		var immediate_demand := int(qv.get("in_shop_count", 0)) + int(qv.get("online_open_count", 0))
		if (
			not is_skipped
			and gen > 0
			and int(qv.get("online_open_count", 0)) < 2
			and _has_ingredients_for_recipe(kitchen, storage_ids, preview_id)
			and (
				_min_recipe_stock(kitchen, storage_ids, preview_id) >= 2
				or _min_recipe_stock(kitchen, storage_ids, preview_id) >= immediate_demand
			)
		):
			if not _advance_clock_and_poll(game_root, service, DUR_ONLINE_ACCEPT, tracker):
				return {
					"blocked_order_ids": [],
					"expired_mid_prep": false,
					"restock_duration": restock_dur,
					"restock_trips": restock_trips,
				}
			var offer_now := service.get_online_offer_view()
			var qv_now := service.get_customer_queue_view()
			if (
				service.get_online_acceptance_enabled()
				and int(offer_now.get("offer_generation_number", 0)) == gen
				and int(qv_now.get("online_open_count", 0)) < 2
			):
				kitchen.on_interactable_clicked(&"online_station")
				if kitchen.execute_allowed_command(&"terima"):
					tracker["accepted"] = int(tracker["accepted"]) + 1
					tracker["active_unaccepted_gen"] = 0
					_poll_offer_tracker(service, tracker, game_root)
			return {
				"blocked_order_ids": [],
				"expired_mid_prep": false,
				"restock_duration": restock_dur,
				"restock_trips": restock_trips,
			}

	# 5. Serve earliest-deadline cookable order chronologically.
	var urgent := _pick_cookable_and_blocked(kitchen, service, storage_ids)
	var blocked_ids: Array = urgent["blocked_order_ids"]
	var target: Dictionary = urgent["target"]
	if not target.is_empty():
		var noise_delay := 0.0
		if use_noise and noise_rng.randf() < 0.25:
			noise_delay = noise_rng.randf_range(3.0, 6.0)
		var cook_res := _cook_and_serve_chronological(
			game_root, kitchen, service, storage_ids, target, tracker, noise_delay
		)
		return {
			"blocked_order_ids": blocked_ids,
			"expired_mid_prep": bool(cook_res["expired_mid_prep"]),
			"restock_duration": restock_dur,
			"restock_trips": restock_trips,
		}

	_advance_clock_and_poll(game_root, service, TICK_STEP, tracker)
	return {
		"blocked_order_ids": blocked_ids,
		"expired_mid_prep": false,
		"restock_duration": restock_dur,
		"restock_trips": restock_trips,
	}


func _has_ingredients_for_recipe(
	kitchen: KitchenController,
	storage_ids: Array[StringName],
	recipe_id: StringName
) -> bool:
	var rdef := kitchen.get_recipe_def(recipe_id)
	if rdef == null:
		return false
	for part in rdef.required_parts:
		if part == null:
			continue
		if part.ingredient_id == &"beras":
			var has_rice := (
				int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) > 0
				or _count_ingredient(kitchen, storage_ids, &"beras") > 0
			)
			if not has_rice:
				return false
		elif _count_ingredient(kitchen, storage_ids, part.ingredient_id) <= 0:
			return false
	return true


func _min_recipe_stock(
	kitchen: KitchenController,
	storage_ids: Array[StringName],
	recipe_id: StringName
) -> int:
	var rdef := kitchen.get_recipe_def(recipe_id)
	if rdef == null:
		return 0
	var min_val := 999
	for part in rdef.required_parts:
		if part == null or part.ingredient_id == &"beras":
			continue
		min_val = mini(min_val, _count_ingredient(kitchen, storage_ids, part.ingredient_id))
	return min_val if min_val < 999 else 0


func _pick_cookable_and_blocked(
	kitchen: KitchenController,
	service: ServiceController,
	storage_ids: Array[StringName]
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for tv_id: StringName in service.get_registered_table_ids():
		var tv := service.get_table_view(tv_id)
		if int(tv.get("state", -1)) == SharedTypes.TableState.OCCUPIED_WAITING:
			var ord_id := StringName(tv.get("order_id_or_empty", &""))
			var ov := service.get_order_view(ord_id)
			candidates.append({
				"kind": SharedTypes.OrderKind.DINE_IN,
				"target_id": tv_id,
				"order_id": ord_id,
				"recipe_id": StringName(ov.get("recipe_id", &"")),
				"rem": float(ov.get("seconds_remaining", INF)),
			})
	for dv: Dictionary in service.get_driver_views():
		if bool(dv.get("serveable", false)):
			candidates.append({
				"kind": SharedTypes.OrderKind.ONLINE,
				"target_id": StringName(dv.get("driver_id", &"")),
				"order_id": StringName(dv.get("order_id", &"")),
				"recipe_id": StringName(dv.get("recipe_id", &"")),
				"rem": float(dv.get("seconds_remaining", INF)),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rem"]) < float(b["rem"])
	)
	var blocked_order_ids: Array[StringName] = []
	for c in candidates:
		if _has_ingredients_for_recipe(kitchen, storage_ids, StringName(c["recipe_id"])):
			return { "target": c, "blocked_order_ids": blocked_order_ids }
		blocked_order_ids.append(StringName(c["order_id"]))
	return { "target": {}, "blocked_order_ids": blocked_order_ids }


func _cook_and_serve_chronological(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	storage_ids: Array[StringName],
	target: Dictionary,
	tracker: Dictionary,
	initial_delay: float,
	_opts: Dictionary = {}
) -> Dictionary:
	var recipe_id := StringName(target["recipe_id"])
	var target_id := StringName(target["target_id"])
	var rdef := kitchen.get_recipe_def(recipe_id)
	if rdef == null:
		return { "served": false, "expired_mid_prep": false }

	# Apply any human hesitation delay BEFORE beginning preparation.
	if initial_delay > 0.0:
		if not _advance_clock_and_poll(game_root, service, initial_delay, tracker):
			return { "served": false, "expired_mid_prep": true }
		if not _is_target_order_valid(service, target):
			return { "served": false, "expired_mid_prep": true }

	# 1. Shared rice batch (cooker empty -> wash + cook 3.0s chronological).
	# Rice cooking is shared kitchen prep (not order-bound), yet the bot aborts order-triggered
	# `masak` if the triggering order expires before execution so no work proceeds post-expiry.
	if int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) <= 0:
		if not _is_target_order_valid(service, target):
			return { "served": false, "expired_mid_prep": true }
		if not _advance_clock_and_poll(game_root, service, DUR_RICE_CUCI, tracker):
			return { "served": false, "expired_mid_prep": true }
		if not _is_target_order_valid(service, target):
			return { "served": false, "expired_mid_prep": true }
		if not _take_from_any_box(kitchen, storage_ids, &"beras"):
			return { "served": false, "expired_mid_prep": false }
		kitchen.on_interactable_clicked(&"washer")
		kitchen.execute_allowed_command(&"cuci")

		if not _is_target_order_valid(service, target):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": true }
		if not _advance_clock_and_poll(game_root, service, DUR_RICE_MASAK, tracker):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": true }
		kitchen.on_interactable_clicked(&"rice_cooker")
		if (
			not _is_target_order_valid(service, target)
			or not kitchen.get_allowed_commands_for_selected_target().has("masak")
		):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": true }
		kitchen.execute_allowed_command(&"masak")

	# 2. Chronological plate + cooked rice steps (4 * 0.50s = 2.00s total).
	# 2a. Take clean plate from plate_rack (0.50s).
	if not _is_target_order_valid(service, target):
		return { "served": false, "expired_mid_prep": true }
	if not _advance_clock_and_poll(game_root, service, DUR_TAKE_PLATE, tracker):
		return { "served": false, "expired_mid_prep": true }
	if not _is_target_order_valid(service, target):
		return { "served": false, "expired_mid_prep": true }
	kitchen.on_interactable_clicked(&"plate_rack")
	if kitchen.get_held_item_view().is_empty():
		return { "served": false, "expired_mid_prep": false }

	# 2b. Stage clean plate onto work_table_stage (0.50s).
	if not _advance_clock_and_poll(game_root, service, DUR_STAGE_PLATE, tracker):
		return { "served": false, "expired_mid_prep": true }
	if not _is_target_order_valid(service, target):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": true }
	kitchen.on_interactable_clicked(&"work_table_stage")

	# 2c. Scoop 1 portion of cooked rice from rice_cooker (0.50s).
	if not _advance_clock_and_poll(game_root, service, DUR_SCOOP_RICE, tracker):
		return { "served": false, "expired_mid_prep": true }
	kitchen.on_interactable_clicked(&"rice_cooker")
	if (
		not _is_target_order_valid(service, target)
		or not kitchen.get_allowed_commands_for_selected_target().has("nasi")
	):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": true }
	if not kitchen.execute_allowed_command(&"nasi"):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": false }

	# 2d. Merge cooked rice onto staged clean plate (0.50s).
	if not _advance_clock_and_poll(game_root, service, DUR_MERGE_RICE, tracker):
		return { "served": false, "expired_mid_prep": true }
	if not _is_target_order_valid(service, target):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": true }
	kitchen.on_interactable_clicked(&"work_table_stage")

	# 3. Prepare each remaining ingredient part chronologically.
	for part in rdef.required_parts:
		if part == null or part.ingredient_id == &"beras":
			continue
		if not _advance_clock_and_poll(game_root, service, DUR_TAKE_INGREDIENT, tracker):
			return { "served": false, "expired_mid_prep": true }
		if not _is_target_order_valid(service, target):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": true }
		if not _take_from_any_box(kitchen, storage_ids, part.ingredient_id):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": false }

		var req_state := int(part.required_state)
		var needs_chop := (
			req_state == SharedTypes.PrepState.CHOPPED
			or req_state == SharedTypes.PrepState.CHOPPED_AND_COOKED
		)
		var needs_cook := (
			req_state == SharedTypes.PrepState.COOKED
			or req_state == SharedTypes.PrepState.CHOPPED_AND_COOKED
		)
		if needs_chop:
			var chop_dur := DUR_CHOP_BEFORE_COOK if needs_cook else DUR_CHOP_POTONG
			if not _advance_clock_and_poll(game_root, service, chop_dur, tracker):
				return { "served": false, "expired_mid_prep": true }
			if not _is_target_order_valid(service, target):
				_cleanup_aborted_prep(game_root, kitchen, service, tracker)
				return { "served": false, "expired_mid_prep": true }
			kitchen.on_interactable_clicked(&"work_table_chop")
			kitchen.execute_allowed_command(&"potong")
		if needs_cook:
			if not _advance_clock_and_poll(game_root, service, DUR_COOK_GORENG, tracker):
				return { "served": false, "expired_mid_prep": true }
			if not _is_target_order_valid(service, target):
				_cleanup_aborted_prep(game_root, kitchen, service, tracker)
				return { "served": false, "expired_mid_prep": true }
			kitchen.on_interactable_clicked(&"stove")
			kitchen.execute_allowed_command(&"goreng")

		if not _advance_clock_and_poll(game_root, service, DUR_STAGE_COMPONENT, tracker):
			return { "served": false, "expired_mid_prep": true }
		if not _is_target_order_valid(service, target):
			_cleanup_aborted_prep(game_root, kitchen, service, tracker)
			return { "served": false, "expired_mid_prep": true }
		kitchen.on_interactable_clicked(&"work_table_stage")

	# 4. Pick up finished dish & move to target before executing `saji` (0.5s + 1.0s = 1.5s).
	if not _advance_clock_and_poll(game_root, service, DUR_PICKUP_PLATED, tracker):
		return { "served": false, "expired_mid_prep": true }
	if not _is_target_order_valid(service, target):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": true }
	kitchen.on_interactable_clicked(&"work_table_stage")

	if not _advance_clock_and_poll(game_root, service, DUR_SERVE_SAJI, tracker):
		return { "served": false, "expired_mid_prep": true }
	if not _is_target_order_valid(service, target):
		_cleanup_aborted_prep(game_root, kitchen, service, tracker)
		return { "served": false, "expired_mid_prep": true }

	kitchen.on_interactable_clicked(target_id)
	if kitchen.execute_allowed_command(&"saji") and kitchen.get_held_item_view().is_empty():
		_poll_offer_tracker(service, tracker, game_root)
		return { "served": true, "expired_mid_prep": false }

	_cleanup_aborted_prep(game_root, kitchen, service, tracker)
	return { "served": false, "expired_mid_prep": not _is_target_order_valid(service, target) }


func _take_from_any_box(
	kitchen: KitchenController,
	storage_ids: Array[StringName],
	ing_id: StringName
) -> bool:
	for unit_id in storage_ids:
		for s: Dictionary in kitchen.get_storage_unit_view(unit_id).get("slots", []):
			if StringName(s.get("ingredient_id", &"")) == ing_id and int(s.get("quantity", 0)) > 0:
				kitchen.on_interactable_clicked(unit_id)
				if kitchen.execute_allowed_command(ing_id):
					return not kitchen.get_held_item_view().is_empty()
	return false


func _print_scenario_summary(sc: Dictionary, summary: Dictionary) -> void:
	print("=== P5-G2C SCENARIO %s (%s) | Outcome=%d FinalCash=%d / Target=%d ===" % [
		String(sc["id"]),
		String(sc["name"]),
		int(summary["day7_outcome"]),
		int(summary["final_cash"]),
		int(summary["day_7_target"]),
	])
	print("  Boxes: %s | DurTotal=%.1fs | Restock=%.1fs (plan=%.1fs srv=%.1fs trips=%d)" % [
		str(summary["purchased_boxes"]),
		float(summary["total_duration"]),
		float(summary["total_restock_time"]),
		float(summary["total_planning_restock_time"]),
		float(summary["total_serving_restock_time"]),
		int(summary["total_restock_trips"]),
	])
	print(
		"  Stockouts=%d (ep=%d) MidPrepExp=%d | Cash: Din=%d Onl=%d Tot=%d Ref=%d Ing=%d Fix=%d El=%d"
		% [
			int(summary["total_stockout_orders"]),
			int(summary["total_stockout_episodes"]),
			int(summary["total_mid_prep_expiries"]),
			int(summary["total_dinein_rev"]),
			int(summary["total_online_rev"]),
			int(summary["total_cash_earned"]),
			int(summary["total_refunds"]),
			int(summary["total_ing_cost"]),
			int(summary["total_fix_cost"]),
			int(summary["total_el_cost"]),
		]
	)
	print(
		"  DineIn: PlanQ=%d Spawn=%d Comp=%d Fail=%d(pre=%d post=%d) Open=%d"
		% [
			int(summary["total_planned_quota"]),
			int(summary["total_generated_dinein"]),
			int(summary["total_completed_dinein"]),
			int(summary["total_failed_dinein"]),
			int(summary["total_failed_before_seating"]),
			int(summary["total_failed_after_seating"]),
			int(summary["total_still_open_dinein"]),
		]
	)
	print(
		"  DineInStages: OutQ=%d Table=%d QToTbl=%d DirTbl=%d | CompTot=%d FailTot=%d"
		% [
			int(summary["total_entered_outside_queue"]),
			int(summary["total_reached_table"]),
			int(summary["total_queued_then_seated"]),
			int(summary["total_seated_directly"]),
			int(summary["total_completed_orders"]),
			int(summary["total_failed_orders"]),
		]
	)
	print(
		"  Offers: gen=%d pres=%d acc=%d tmr_exp=%d cut_term=%d cap=%d oth=%d act=%d unk=%d"
		% [
			int(summary["total_offers_generated"]),
			int(summary["total_online_presented"]),
			int(summary["total_online_accepted"]),
			int(summary["total_offers_timer_expired"]),
			int(summary["total_offers_terminated_cutoff"]),
			int(summary["total_offers_terminated_cap"]),
			int(summary["total_offers_terminated_other"]),
			int(summary["total_offers_active_at_boundary"]),
			int(summary["total_offers_unknown"]),
		]
	)
	print(
		"  OnlineOrd: acc=%d ok=%d fail=%d open=%d | Supp: cut=%.1fs(%dep) cap=%.1fs(%dep)"
		% [
			int(summary["total_online_accepted"]),
			int(summary["total_online_fulfilled"]),
			int(summary["total_online_failed"]),
			int(summary["total_online_still_open"]),
			float(summary["total_suppressed_cutoff_seconds"]),
			int(summary["total_suppressed_cutoff_episodes"]),
			float(summary["total_suppressed_cap_seconds"]),
			int(summary["total_suppressed_cap_episodes"]),
		]
	)
	for d: Dictionary in summary["days"]:
		var line := (
			"  D%d act=%d box=%d(%dsl/%du) pot=%d q=%d spw=%d"
			+ " | din=%d/%d outq=%d tbl=%d qto=%d fp=%d"
			+ " | onl=p:%d/a:%d/te:%d/ct:%d/unk:%d oo=%d/%d"
			+ " | so=%d mpe=%d debt=%d->%d cash=%d dur=%.1fs"
		)
		print(line % [
			int(d["day"]),
			(d["active_recipes"] as Array).size(),
			int(d["boxes"]),
			int(d["slots"]),
			int(d["unit_cap"]),
			int(d["potential_demand"]),
			int(d["planned_quota"]),
			int(d["spawned_dinein"]),
			int(d["completed_dinein"]),
			int(d["failed_dinein"]),
			int(d["entered_outside_queue"]),
			int(d["reached_table"]),
			int(d["queued_then_seated"]),
			int(d["failed_before_seating"]),
			int(d["online_presented"]),
			int(d["online_accepted"]),
			int(d["offers_timer_expired"]),
			int(d["offers_terminated_cutoff"]),
			int(d["offers_unknown"]),
			int(d["completed_online"]),
			int(d["failed_online"]),
			int(d["stockout_orders"]),
			int(d["mid_prep_expiries"]),
			int(d["debt_before"]),
			int(d["debt_after"]),
			int(d["end_cash"]),
			float(d["dur"]),
		])
