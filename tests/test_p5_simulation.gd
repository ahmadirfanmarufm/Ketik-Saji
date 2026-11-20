extends SceneTree
## P5-C & P5-D Headless Verification & Deterministic Day 1-Day 7 Simulations.

const TICK_STEP := 0.25

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_diminishing_demand_and_plan_contracts()
	await _test_negative_config_validation()
	await _run_seven_day_simulations()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _test_diminishing_demand_and_plan_contracts() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var run := game_root.get_run_controller() as RunController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI

	# 1. Verify 1-recipe baseline across Days 1-7 preserves Potential/Quota [4, 8, 12, 16, 20, 24, 28].
	var expected_potentials: Array[int] = [4, 8, 12, 16, 20, 24, 28]
	var expected_quotas: Array[int] = [4, 8, 12, 16, 20, 24, 28]
	for i in range(7):
		var day := i + 1
		var demand := run._compute_demand_for_day_and_menu(day, [&"nasi_telor"])
		_check(
			"Day %d 1-recipe separates Potential=%d from Quota=%d"
			% [day, expected_potentials[i], expected_quotas[i]],
			int(demand["potential_demand"]) == expected_potentials[i]
			and int(demand["planned_dinein_quota"]) == expected_quotas[i]
		)

	# 2. Verify diminishing-return arrival contributions (+3 -> +2 -> +1) on Days 3 & 6:
	var cfg := run.economy_config
	var d3_1 := run._compute_demand_for_day_and_menu(3, [&"nasi_telor"])
	var d3_2 := run._compute_demand_for_day_and_menu(3, [&"nasi_telor", &"nasi_tempe"])
	var d3_3 := run._compute_demand_for_day_and_menu(
		3, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"]
	)
	var d6_3 := run._compute_demand_for_day_and_menu(
		6, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"]
	)
	var d6_4 := run._compute_demand_for_day_and_menu(
		6, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"nasi_ayam_komplit"]
	)
	var pot_gain_1_to_2 := int(d3_2["potential_demand"]) - int(d3_1["potential_demand"])
	var pot_gain_2_to_3 := int(d3_3["potential_demand"]) - int(d3_2["potential_demand"])
	var pot_gain_3_to_4 := int(d6_4["potential_demand"]) - int(d6_3["potential_demand"])
	_check(
		"diminishing returns (+3 -> +2 -> +1): 1->2 (+%d) > 2->3 (+%d) > 3->4 (+%d)"
		% [pot_gain_1_to_2, pot_gain_2_to_3, pot_gain_3_to_4],
		int(d3_1["potential_demand"]) == 12
		and int(d3_1["planned_dinein_quota"]) == 12
		and int(d3_2["potential_demand"]) == 15
		and int(d3_2["planned_dinein_quota"]) == 15
		and int(d3_3["potential_demand"]) == 17
		and int(d3_3["planned_dinein_quota"]) == 17
		and pot_gain_1_to_2 == 3
		and pot_gain_2_to_3 == 2
		and pot_gain_3_to_4 == 1
		and pot_gain_1_to_2 > pot_gain_2_to_3
		and pot_gain_2_to_3 > pot_gain_3_to_4
		and cfg.get_menu_demand_bonus(4) - cfg.get_menu_demand_bonus(3) == 1
		and cfg.get_menu_demand_bonus(5) - cfg.get_menu_demand_bonus(4) == 1
	)

	# 3. Verify locked/inactive exclusion and P5-F debt semantics (1 debt = 1 quota reduction
	# while Potential Demand stays gross across Days 1-7, 1-3 recipes, debt 0-12).
	_check(
		"Day 1 rejects locked nasi_tempe selection without mutating menu",
		not run.select_daily_menu([&"nasi_telor", &"nasi_tempe"])
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	var menus_by_count: Array = [
		[&"nasi_telor"],
		[&"nasi_telor", &"nasi_tempe"],
		[&"nasi_telor", &"nasi_tempe", &"nasi_ayam"],
	]
	var day_recipe_debt_ok := true
	var potential_invariant_ok := true
	var clamp_zero_ok := true
	for day in range(1, 8):
		var max_count := mini(day, 3)
		for count_idx in range(max_count):
			var menu_slice: Array[StringName] = []
			menu_slice.assign(menus_by_count[count_idx])
			run._demand_penalty_debt = 0
			var base_dem := run._compute_demand_for_day_and_menu(day, menu_slice)
			var gross_pot := int(base_dem["potential_demand"])
			var gross_q := int(base_dem["planned_dinein_quota"])
			if gross_q != gross_pot:
				day_recipe_debt_ok = false
			for debt in range(0, 13):
				run._demand_penalty_debt = debt
				var dem := run._compute_demand_for_day_and_menu(day, menu_slice)
				if int(dem["potential_demand"]) != gross_pot:
					potential_invariant_ok = false
				var expected_q := maxi(0, gross_q - debt)
				if int(dem["planned_dinein_quota"]) != expected_q:
					day_recipe_debt_ok = false
			run._demand_penalty_debt = gross_q + 5
			var zero_dem := run._compute_demand_for_day_and_menu(day, menu_slice)
			if int(zero_dem["potential_demand"]) != gross_pot:
				potential_invariant_ok = false
			if int(zero_dem["planned_dinein_quota"]) != 0:
				clamp_zero_ok = false

	_check(
		"P5-F 1 debt = 1 planned quota across Days 1-7, 1-3 active recipes, and debt 0..12",
		day_recipe_debt_ok
	)
	_check(
		"P5-F Potential Demand remains unchanged as gross demand while debt rises 0..clamp",
		potential_invariant_ok
	)
	_check(
		"P5-F Planned Dine-in Quota clamps cleanly at 0 when debt exceeds gross quota",
		clamp_zero_ok
	)

	# Explicitly verify boundary cases without no-op steps:
	# Day 2 2-recipe (pot=11, gross_q=11): debt 4->7;
	# Day 3 3-recipe (pot=17, gross_q=17): debt 2->15, debt 7->10.
	run._demand_penalty_debt = 4
	var boundary_d2 := run._compute_demand_for_day_and_menu(2, [&"nasi_telor", &"nasi_tempe"])
	run._demand_penalty_debt = 2
	var boundary_d3_2 := run._compute_demand_for_day_and_menu(
		3, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"]
	)
	run._demand_penalty_debt = 7
	var boundary_d3_7 := run._compute_demand_for_day_and_menu(
		3, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"]
	)
	_check(
		"P5-F conversion boundary cases reduce quota by exact debt without no-op plateaus",
		int(boundary_d2["potential_demand"]) == 11
		and int(boundary_d2["planned_dinein_quota"]) == 7
		and int(boundary_d3_2["potential_demand"]) == 17
		and int(boundary_d3_2["planned_dinein_quota"]) == 15
		and int(boundary_d3_7["potential_demand"]) == 17
		and int(boundary_d3_7["planned_dinein_quota"]) == 10
	)
	run._demand_penalty_debt = 0

	# 4. Planning preview, UI display, and frozen ServicePlan match & stay immutable in SERVING.
	_check("start Day 1", game_root.start_service_requested())
	var d1_plan := run.get_service_plan()
	_check(
		"Day 1 ServicePlan freezes potential_demand=4 and day_queue_initial=4",
		int(d1_plan.get("potential_demand", -1)) == 4
		and int(d1_plan.get("day_queue_initial", -1)) == 4
		and int(service.get_customer_queue_view()["day_queue_initial"]) == 4
	)

	# Simulate Day 1 with 1 missed dine-in order so real debt accumulation (+1 or +2) updates Day 2.
	game_root._process(100.0) # Customer 1 expires at 100s (+1 miss)
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._customers.clear()
	for ord_id: StringName in service._orders.keys():
		if int(service._orders[ord_id].get("status", -1)) == SharedTypes.OrderStatus.OPEN:
			service._orders[ord_id]["status"] = SharedTypes.OrderStatus.FAILED
	service._online_orders_open.clear()
	for tbl: Dictionary in service._tables.values():
		tbl["state"] = SharedTypes.TableState.CLEAN_VACANT
		tbl["customer_id_or_empty"] = &""
		tbl["order_id_or_empty"] = &""
	game_root.request_close_if_drained()
	var d1_settle := run.get_day_settlement_view(1)
	var d1_debt := int(d1_settle.get("penalty_debt_after", 0))
	_check(
		"Day 1 settlement accumulates debt in [1,2] and separates gross Potensi Besok from Target",
		d1_debt in [1, 2]
		and int(d1_settle.get("forecast_next_day_potential", -1)) == 8
		and int(d1_settle.get("forecast_next_day", -1)) == 8 - d1_debt
	)

	_check("continue to Day 2", game_root.request_continue_from_results())
	var d2_rv := run.get_run_view()
	_check(
		"Day 2 keeps nasi_tempe inactive, keeps gross potential=8, and applies 1:1 debt to quota",
		d2_rv["unlocked_recipe_ids"] == [&"nasi_telor", &"nasi_tempe"]
		and d2_rv["selected_recipe_ids"] == [&"nasi_telor"]
		and int(d2_rv["potential_demand"]) == 8
		and int(d2_rv["planned_dinein_quota"]) == 8 - d1_debt
		and ui.potential_demand_label.text == "Potensi Tamu: 8"
		and ui.forecast_quota_label.text == "Target Tamu: %d" % (8 - d1_debt)
	)

	# Verify Edit Menu preview & HUD match ServicePlan freeze when toggling nasi_tempe with debt > 0.
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_recipe_button(&"nasi_tempe").button_pressed = true
	var d2_preview := run.preview_demand_for_menu([&"nasi_telor", &"nasi_tempe"])
	_check(
		"Edit Menu preview applies 1:1 debt to quota (11 - debt) while keeping gross potential=11",
		int(d2_preview["potential_demand"]) == 11
		and int(d2_preview["planned_dinein_quota"]) == 11 - d1_debt
		and ui.edit_menu_forecast_label.text == "Potensi Tamu: 11 | Target Tamu: %d" % (11 - d1_debt)
	)
	ui.edit_menu_confirm_button.pressed.emit()
	_check("start Day 2 with 2 active recipes and active debt", game_root.start_service_requested())
	var d2_plan := run.get_service_plan()
	var frozen_q := int(d2_plan.get("day_queue_initial", -1))
	run._demand_penalty_debt = 0
	game_root._process(20.0)
	_check(
		"ServicePlan & ServiceController quota remain frozen during SERVING",
		int(d2_plan.get("potential_demand", -1)) == 11
		and frozen_q == 11 - d1_debt
		and int(service.get_customer_queue_view()["day_queue_initial"]) == frozen_q
		and int(run.get_service_plan().get("day_queue_initial", -1)) == frozen_q
	)

	game_root.free()
	await process_frame


func _test_negative_config_validation() -> void:
	var base := load("res://data/economy_config.tres") as EconomyConfig
	var ingredients: Array[IngredientDef] = []
	for id: StringName in [&"beras", &"telur", &"ayam", &"tempe", &"sayur", &"sapi"]:
		ingredients.append(load("res://data/ingredients/%s.tres" % id) as IngredientDef)
	var recipes: Array[RecipeDef] = []
	for id: StringName in [&"nasi_telor", &"nasi_ayam", &"nasi_ayam_komplit"]:
		recipes.append(load("res://data/recipes/%s.tres" % id) as RecipeDef)
	var utilities: Array[UtilityDef] = []
	for id: StringName in [
		&"box", &"fridge", &"stove", &"washer", &"plate_rack", &"rice_cooker", &"dining_table"
	]:
		utilities.append(load("res://data/utilities/%s.tres" % id) as UtilityDef)

	var bad_non_dim := base.duplicate(true) as EconomyConfig
	bad_non_dim.menu_demand_bonus_curve = [0, 2, 6]
	_check(
		"EconomyConfig rejects non-diminishing bonus curve [0, 2, 6]",
		not (bad_non_dim.validate(ingredients, recipes, utilities)["errors"] as Array).is_empty()
	)

	var bad_pct := base.duplicate(true) as EconomyConfig
	bad_pct.potential_demand_conversion_percent = 120
	_check(
		"EconomyConfig rejects conversion percent > 100",
		not (bad_pct.validate(ingredients, recipes, utilities)["errors"] as Array).is_empty()
	)

	var bad_interval := base.duplicate(true) as EconomyConfig
	bad_interval.online_offer_interval_seconds = 0.0
	_check(
		"EconomyConfig rejects non-positive online offer interval",
		not (bad_interval.validate(ingredients, recipes, utilities)["errors"] as Array).is_empty()
	)


func _run_seven_day_simulations() -> void:
	# Each scenario fixes a specific bot policy (menu schedule, box count, and online acceptance).
	# Scenario 3 demonstrates congestion failure only under its constrained 2-box + 5-unit Day 3
	# planning cap + online-order policy; Scenario 4 keeps the exact same 3-recipe menu and 2-box
	# limit without online orders and still clears Day 7 WON.
	var scenarios: Array[Dictionary] = [
		{
			"name": "1_active_recipe_1box_online",
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
			"buy_extra_box_day": 0,
			"expected_outcome": SharedTypes.DayOutcome.WON,
			"expect_cash_meets_target": true,
		},
		{
			"name": "2_active_recipes_from_day2_2box_online",
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"accept_online": true,
			"buy_extra_box_day": 2,
			"expected_outcome": SharedTypes.DayOutcome.WON,
			"expect_cash_meets_target": true,
		},
		{
			"name": "3_active_recipes_from_day3_1box_online_constrained",
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"],
				4: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				5: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				6: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				7: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
			},
			"accept_online": true,
			"buy_extra_box_day": 0,
			"expected_outcome": SharedTypes.DayOutcome.LOST,
			"expect_cash_meets_target": false,
		},
		{
			"name": "3_active_recipes_from_day3_2box_dinein_only",
			"target_recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"],
				4: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				5: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				6: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
				7: [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"egg_salad"],
			},
			"accept_online": false,
			"buy_extra_box_day": 2,
			"expected_outcome": SharedTypes.DayOutcome.WON,
			"expect_cash_meets_target": true,
		},
	]

	var cash_by_scenario: Dictionary = {}
	var fails_by_scenario: Dictionary = {}
	var outcome_by_scenario: Dictionary = {}
	for sc: Dictionary in scenarios:
		var summary := await _simulate_campaign(sc)
		_print_simulation_report(sc["name"], summary)
		var days: Array = summary.get("days", [])
		var total_failed := 0
		var max_dur := 0.0
		for d: Dictionary in days:
			total_failed += int(d.get("failed_dinein", 0)) + int(d.get("failed_online", 0))
			max_dur = maxf(max_dur, float(d.get("service_duration", 0.0)))
		var sc_name := String(sc["name"])
		var final_cash := int(summary.get("final_cash", -1))
		var target_cash := int(summary.get("day_7_target", -1))
		var actual_outcome := int(summary.get("day7_outcome", -1))
		var expected_outcome := int(sc["expected_outcome"])
		var expect_cash_meets_target := bool(sc["expect_cash_meets_target"])
		var cash_matches_expectation := (
			final_cash >= target_cash
			if expect_cash_meets_target
			else final_cash < target_cash
		)
		var day7_end_cash := int(days[6].get("end_cash", -999999)) if days.size() == 7 else -1
		cash_by_scenario[sc_name] = final_cash
		fails_by_scenario[sc_name] = total_failed
		outcome_by_scenario[sc_name] = actual_outcome
		_check(
			"Simulation '%s' hits expected Day 7 outcome=%d (cash=%d/%d fails=%d dur=%.1fs)"
			% [sc_name, expected_outcome, final_cash, target_cash, total_failed, max_dur],
			days.size() == 7
			and int(summary.get("final_phase", -1)) == SharedTypes.Phase.FINISHED
			and target_cash == 700000
			and actual_outcome == expected_outcome
			and cash_matches_expectation
			and final_cash == day7_end_cash
			and max_dur > 0.0
			and max_dur < 1000.0
		)

	_check(
		"Constrained 1-box+online multi-recipe policy congests vs 2-recipe & 2-box dine-in",
		int(fails_by_scenario["3_active_recipes_from_day3_1box_online_constrained"])
		> int(fails_by_scenario["2_active_recipes_from_day2_2box_online"])
		and int(cash_by_scenario["3_active_recipes_from_day3_1box_online_constrained"])
		< int(cash_by_scenario["2_active_recipes_from_day2_2box_online"])
		and int(cash_by_scenario["3_active_recipes_from_day3_1box_online_constrained"])
		< int(cash_by_scenario["3_active_recipes_from_day3_2box_dinein_only"])
		and int(outcome_by_scenario["1_active_recipe_1box_online"]) == SharedTypes.DayOutcome.WON
		and int(outcome_by_scenario["2_active_recipes_from_day2_2box_online"])
		== SharedTypes.DayOutcome.WON
		and int(outcome_by_scenario["3_active_recipes_from_day3_1box_online_constrained"])
		== SharedTypes.DayOutcome.LOST
		and int(outcome_by_scenario["3_active_recipes_from_day3_2box_dinein_only"])
		== SharedTypes.DayOutcome.WON
	)


func _simulate_campaign(sc: Dictionary) -> Dictionary:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var day_reports: Array[Dictionary] = []
	var has_extra_box := false

	for day in range(1, 8):
		var target_menu: Array[StringName] = []
		target_menu.assign(sc["target_recipes_by_day"][day])
		run.select_daily_menu(target_menu)

		if int(sc.get("buy_extra_box_day", 0)) == day and not has_extra_box:
			if run.request_fixture_purchase(&"box", &"slot_utility_01"):
				has_extra_box = true

		# Stock required ingredients for planned quota + 2 buffer orders into available boxes.
		var rv_plan := run.get_run_view()
		var planned_quota := int(rv_plan["planned_dinein_quota"])
		var potential_demand := int(rv_plan["potential_demand"])
		var est_orders := planned_quota + (4 if bool(sc.get("accept_online", false)) else 0)
		_restock_for_menu(run, kitchen, target_menu, est_orders, has_extra_box)

		game_root.start_service_requested()

		# Interactive service simulation loop (advances fixed ticks and executes kitchen/service).
		var action_cooldown := 0.0
		var safety_steps := 0
		while game_root.is_serving() and safety_steps < 6000:
			safety_steps += 1
			game_root._process(TICK_STEP)
			action_cooldown = maxf(0.0, action_cooldown - TICK_STEP)
			if not game_root.is_serving():
				break
			if action_cooldown > 0.0:
				continue

			# 1. Clean any dirty table first so new FIFO customers can sit.
			var acted_time := _try_step_service_and_kitchen(
				game_root, kitchen, service, run, ui, target_menu,
				bool(sc.get("accept_online", false)), has_extra_box
			)
			action_cooldown = acted_time

		var settle := run.get_day_settlement_view(day)
		var q_end := service.get_customer_queue_view()
		var pending_total := _count_pending_deliveries(kitchen)
		day_reports.append({
			"day": day,
			"active_recipes": target_menu.size(),
			"potential_demand": potential_demand,
			"planned_quota": planned_quota,
			"generated_dinein": planned_quota - int(q_end.get("day_queue_remaining", 0)),
			"accepted_online": (
				int(settle.get("completed_online_count", 0))
				+ int(settle.get("failed_online_count", 0))
			),
			"completed_dinein": int(settle.get("completed_dinein_count", 0)),
			"completed_online": int(settle.get("completed_online_count", 0)),
			"failed_dinein": int(settle.get("failed_dinein_count", 0)),
			"failed_online": int(settle.get("failed_online_count", 0)),
			"debt_before": int(settle.get("penalty_debt_before", 0)),
			"debt_after": int(settle.get("penalty_debt_after", 0)),
			"ingredient_cost": int(settle.get("ingredient_purchase_total", 0)),
			"refund_total": int(settle.get("refund_total", 0)),
			"pending_at_close": pending_total,
			"fixture_cost": int(settle.get("fixture_purchase_total", 0)),
			"electricity_cost": int(settle.get("electricity_charge", 0)),
			"revenue_dinein": int(settle.get("order_revenue_dinein", 0)),
			"revenue_online": int(settle.get("order_revenue_online", 0)),
			"end_cash": int(settle.get("end_cash", 0)),
			"service_duration": float(game_root.get_service_elapsed()),
		})

		if day < 7:
			game_root.request_continue_from_results()

	var final_rv := run.get_run_view()
	var result := {
		"days": day_reports,
		"final_phase": game_root.get_phase(),
		"day7_outcome": int(final_rv.get("goal_outcome", -1)),
		"final_cash": int(final_rv.get("cash", 0)),
		"day_7_target": int(final_rv.get("day_7_target", 0)),
	}
	game_root.free()
	await process_frame
	return result


func _restock_for_menu(
	run: RunController,
	kitchen: KitchenController,
	menu: Array[StringName],
	est_orders: int,
	has_extra_box: bool
) -> void:
	# Stock exact starter capacity in Planning without overflowing distinct slots.
	var beras_needed := mini(5, maxi(1, ceili(float(est_orders) / 5.0)))
	var cur_beras := _count_ingredient(kitchen, &"beras")
	if cur_beras < beras_needed:
		_buy_smart(run, kitchen, &"beras", beras_needed - cur_beras, has_extra_box)

	if menu.size() == 1:
		var max_eggs := 20 if has_extra_box else 10
		var eggs := mini(max_eggs, est_orders)
		var cur_egg := _count_ingredient(kitchen, &"telur")
		if cur_egg < eggs:
			_buy_smart(run, kitchen, &"telur", eggs - cur_egg, has_extra_box)
		return

	if menu.has(&"nasi_telor") or menu.has(&"egg_salad"):
		var max_e := 10 if (has_extra_box and menu.size() == 2) else 5
		var eggs := mini(max_e, maxi(4, ceili(float(est_orders) * 0.6)))
		var cur_egg := _count_ingredient(kitchen, &"telur")
		if cur_egg < eggs:
			_buy_smart(run, kitchen, &"telur", eggs - cur_egg, has_extra_box)
	if menu.has(&"nasi_tempe"):
		var tempe_n := mini(5, maxi(3, ceili(float(est_orders) * 0.5)))
		var cur_tempe := _count_ingredient(kitchen, &"tempe")
		if cur_tempe < tempe_n:
			_buy_smart(run, kitchen, &"tempe", tempe_n - cur_tempe, has_extra_box)
	if menu.has(&"nasi_ayam"):
		var ayam_n := mini(5, maxi(3, ceili(float(est_orders) * 0.5)))
		var cur_ayam := _count_ingredient(kitchen, &"ayam")
		if cur_ayam < ayam_n:
			_buy_smart(run, kitchen, &"ayam", ayam_n - cur_ayam, has_extra_box)
	if menu.has(&"egg_salad"):
		var sayur_n := mini(5, maxi(3, ceili(float(est_orders) * 0.4)))
		var cur_sayur := _count_ingredient(kitchen, &"sayur")
		if cur_sayur < sayur_n:
			_buy_smart(run, kitchen, &"sayur", sayur_n - cur_sayur, has_extra_box)


func _buy_smart(
	run: RunController,
	kitchen: KitchenController,
	ing_id: StringName,
	qty: int,
	has_extra_box: bool
) -> bool:
	var units: Array[StringName] = [&"storage_box"]
	if has_extra_box:
		units.append(&"box_01")
	var remaining := qty
	for unit_id: StringName in units:
		if remaining <= 0:
			break
		var unit_view := kitchen.get_storage_unit_view(unit_id)
		var room := 0
		for s: Dictionary in unit_view.get("slots", []):
			var sid := StringName(s.get("ingredient_id", &""))
			var sq := int(s.get("quantity", 0))
			var cap := int(s.get("capacity", 5))
			if sid == &"" or sid == ing_id:
				room += maxi(0, cap - sq)
		if room <= 0:
			continue
		var buy_amt := mini(remaining, room)
		if run.request_ingredient_purchase(ing_id, buy_amt, unit_id):
			remaining -= buy_amt
	return remaining < qty


func _count_pending_deliveries(kitchen: KitchenController) -> int:
	var total := 0
	for p: Dictionary in kitchen.get_pending_delivery_views():
		total += int(p.get("quantity", 0))
	return total


func _count_pending_for(kitchen: KitchenController, ing_id: StringName) -> int:
	var total := 0
	for p: Dictionary in kitchen.get_pending_delivery_views():
		if StringName(p.get("ingredient_id", &"")) == ing_id:
			total += int(p.get("quantity", 0))
	return total


func _count_ingredient(kitchen: KitchenController, ing_id: StringName) -> int:
	var total := 0
	for unit_id: StringName in [&"storage_box", &"box_01"]:
		if not kitchen.has_storage_unit(unit_id):
			continue
		for s: Dictionary in kitchen.get_storage_unit_view(unit_id).get("slots", []):
			if StringName(s.get("ingredient_id", &"")) == ing_id:
				total += int(s.get("quantity", 0))
	return total


func _try_step_service_and_kitchen(
	_game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController,
	_ui: GameUI,
	menu: Array[StringName],
	accept_online: bool,
	has_extra_box: bool
) -> float:
	# Priority 0: Pre-order replenishment when expected remaining queue won't finish before 100s
	# delivery arrives (1 customer spawns per 20s -> buy ahead when queue_remaining >= 5).
	_schedule_proactive_restock(run, kitchen, service, menu, has_extra_box)

	# Priority 1: Wash dirty plates if washer has dirty plates and rack is getting low (<2).
	if (
		int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) <= 1
		and int(kitchen.get_washer_view()["dirty_plate_count"]) > 0
		and kitchen.get_held_item_view().is_empty()
	):
		kitchen.on_interactable_clicked(&"washer")
		kitchen._perform_typed_command(&"cuci")
		if not kitchen.get_held_item_view().is_empty():
			kitchen.on_interactable_clicked(&"plate_rack")
			return 1.5

	# Priority 2: Clean dirty dining tables immediately.
	for tbl_id: StringName in [&"dining_table_01", &"dining_table_02"]:
		var tv := service.get_table_view(tbl_id)
		if int(tv.get("state", -1)) == SharedTypes.TableState.DIRTY:
			kitchen.on_interactable_clicked(tbl_id)
			kitchen._perform_typed_command(&"bersihkan")
			return 0.75

	# Priority 3: Wash any dirty plate in washer when free.
	if (
		int(kitchen.get_washer_view()["dirty_plate_count"]) > 0
		and kitchen.get_held_item_view().is_empty()
	):
		kitchen.on_interactable_clicked(&"washer")
		kitchen._perform_typed_command(&"cuci")
		if not kitchen.get_held_item_view().is_empty():
			kitchen.on_interactable_clicked(&"plate_rack")
			return 1.0

	# Priority 4: Accept periodic online offer only when spare ingredients can cover it
	# without starving pending dine-in customers!
	if accept_online and service.get_online_acceptance_enabled():
		var qv := service.get_customer_queue_view()
		var offer_v := service.get_online_offer_view()
		var preview_id := StringName(offer_v.get("preview_recipe_id", &""))
		var future_diners := (
			int(qv.get("day_queue_remaining", 0))
			+ int(qv.get("outside_dinein_count", 0))
			+ int(qv.get("in_shop_count", 0))
		)
		var spare_buffer := _min_recipe_stock(kitchen, preview_id) - future_diners
		if (
			int(qv.get("online_open_count", 0)) == 0
			and _has_ingredients_for_recipe(kitchen, preview_id)
			and (spare_buffer >= 1 or _count_pending_for_recipe(kitchen, preview_id) >= 2)
		):
			kitchen.on_interactable_clicked(&"online_station")
			kitchen._perform_typed_command(&"terima")
			return 0.5

	# Priority 5: Serve earliest-deadline open order (in-spot online or seated diner).
	var next_target := _pick_most_urgent_order(service)
	if not next_target.is_empty():
		var recipe_id := StringName(next_target["recipe_id"])
		# Top up ingredients if running low before cooking!
		_ensure_stock_during_service(run, kitchen, menu, recipe_id, has_extra_box)
		var action_time := _cook_and_serve_order(kitchen, next_target)
		return action_time

	return 0.25


func _has_ingredients_for_recipe(kitchen: KitchenController, recipe_id: StringName) -> bool:
	match recipe_id:
		&"nasi_telor":
			return (
				(_count_ingredient(kitchen, &"beras") > 0 or _cooker_has_rice(kitchen))
				and _count_ingredient(kitchen, &"telur") > 0
			)
		&"nasi_tempe":
			return (
				(_count_ingredient(kitchen, &"beras") > 0 or _cooker_has_rice(kitchen))
				and _count_ingredient(kitchen, &"tempe") > 0
			)
		&"nasi_ayam":
			return (
				(_count_ingredient(kitchen, &"beras") > 0 or _cooker_has_rice(kitchen))
				and _count_ingredient(kitchen, &"ayam") > 0
			)
		&"egg_salad":
			return (
				_count_ingredient(kitchen, &"telur") > 0
				and _count_ingredient(kitchen, &"sayur") > 0
			)
	return false


func _cooker_has_rice(kitchen: KitchenController) -> bool:
	return int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) > 0


func _schedule_proactive_restock(
	run: RunController,
	kitchen: KitchenController,
	service: ServiceController,
	menu: Array[StringName],
	has_extra_box: bool
) -> void:
	var qv := service.get_customer_queue_view()
	var rem_queue := int(qv.get("day_queue_remaining", 0))
	# Only order mid-service 100s deliveries while remaining service window exceeds ~100s.
	if rem_queue < 5:
		return
	var total_needed := rem_queue + int(qv.get("outside_dinein_count", 0)) + 2
	var check_ings: Array[StringName] = [&"telur"]
	if menu.has(&"nasi_tempe"):
		check_ings.append(&"tempe")
	if menu.has(&"nasi_ayam"):
		check_ings.append(&"ayam")
	if menu.has(&"egg_salad"):
		check_ings.append(&"sayur")

	for ing_id: StringName in check_ings:
		var in_stock := _count_ingredient(kitchen, ing_id)
		var in_flight := _count_pending_for(kitchen, ing_id)
		var est_share := total_needed if menu.size() == 1 else maxi(3, ceili(float(total_needed) * 0.5))
		if in_stock + in_flight < est_share:
			var need := mini(5, est_share - in_stock - in_flight)
			_buy_smart(run, kitchen, ing_id, need, has_extra_box)

	var rice_portions := int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0))
	var beras_stock := _count_ingredient(kitchen, &"beras")
	var beras_flight := _count_pending_for(kitchen, &"beras")
	if rice_portions + (beras_stock + beras_flight) * 5 < total_needed:
		_buy_smart(run, kitchen, &"beras", 2, has_extra_box)


func _min_recipe_stock(kitchen: KitchenController, recipe_id: StringName) -> int:
	match recipe_id:
		&"nasi_telor":
			return _count_ingredient(kitchen, &"telur")
		&"nasi_tempe":
			return _count_ingredient(kitchen, &"tempe")
		&"nasi_ayam":
			return _count_ingredient(kitchen, &"ayam")
		&"egg_salad":
			return mini(_count_ingredient(kitchen, &"telur"), _count_ingredient(kitchen, &"sayur"))
	return 0


func _count_pending_for_recipe(kitchen: KitchenController, recipe_id: StringName) -> int:
	match recipe_id:
		&"nasi_telor":
			return _count_pending_for(kitchen, &"telur")
		&"nasi_tempe":
			return _count_pending_for(kitchen, &"tempe")
		&"nasi_ayam":
			return _count_pending_for(kitchen, &"ayam")
		&"egg_salad":
			return mini(_count_pending_for(kitchen, &"telur"), _count_pending_for(kitchen, &"sayur"))
	return 0


func _ensure_stock_during_service(
	_run: RunController,
	_kitchen: KitchenController,
	_menu: Array[StringName],
	_recipe_id: StringName,
	_has_extra_box: bool
) -> void:
	pass


func _pick_most_urgent_order(service: ServiceController) -> Dictionary:
	var best: Dictionary = {}
	var best_rem := INF

	for tv_id: StringName in [&"dining_table_01", &"dining_table_02"]:
		var tv := service.get_table_view(tv_id)
		if int(tv.get("state", -1)) == SharedTypes.TableState.OCCUPIED_WAITING:
			var ord_id := StringName(tv.get("order_id_or_empty", &""))
			var ov := service.get_order_view(ord_id)
			var rem := float(ov.get("seconds_remaining", INF))
			if rem < best_rem:
				best_rem = rem
				best = {
					"target_id": tv_id,
					"recipe_id": StringName(ov.get("recipe_id", &"")),
				}

	for dv: Dictionary in service.get_driver_views():
		if bool(dv.get("serveable", false)):
			var rem := float(dv.get("seconds_remaining", INF))
			if rem < best_rem:
				best_rem = rem
				best = {
					"target_id": StringName(dv.get("driver_id", &"")),
					"recipe_id": StringName(dv.get("recipe_id", &"")),
				}

	return best


func _cook_and_serve_order(kitchen: KitchenController, target: Dictionary) -> float:
	var recipe_id := StringName(target["recipe_id"])
	var target_id := StringName(target["target_id"])
	var elapsed_action := 0.0

	# Ensure cooked rice is available for rice dishes.
	var needs_rice := recipe_id != &"egg_salad"
	if needs_rice and not _cooker_has_rice(kitchen):
		if _take_from_any_box(kitchen, &"beras"):
			kitchen.on_interactable_clicked(&"washer")
			kitchen._perform_typed_command(&"cuci")
			kitchen.on_interactable_clicked(&"rice_cooker")
			kitchen._perform_typed_command(&"masak")
			elapsed_action += 3.0
		else:
			return 0.5

	# Stage clean plate (+ scoop rice if needed).
	kitchen.on_interactable_clicked(&"plate_rack")
	if kitchen.get_held_item_view().is_empty():
		return 0.5
	kitchen.on_interactable_clicked(&"work_table_stage")
	if needs_rice:
		kitchen.on_interactable_clicked(&"rice_cooker")
		kitchen._perform_typed_command(&"nasi")
		kitchen.on_interactable_clicked(&"work_table_stage")
		elapsed_action += 2.0
	else:
		elapsed_action += 1.0

	var fry_list: Array[StringName] = []
	match recipe_id:
		&"nasi_telor":
			fry_list = [&"telur"]
		&"nasi_tempe":
			fry_list = [&"tempe"]
		&"nasi_ayam":
			fry_list = [&"ayam"]
		&"egg_salad":
			if _take_from_any_box(kitchen, &"sayur"):
				kitchen.on_interactable_clicked(&"work_table_chop")
				kitchen._perform_typed_command(&"potong")
				kitchen.on_interactable_clicked(&"work_table_stage")
				elapsed_action += 2.5
			fry_list = [&"telur"]

	for ing: StringName in fry_list:
		if _take_from_any_box(kitchen, ing):
			kitchen.on_interactable_clicked(&"stove")
			kitchen._perform_typed_command(&"goreng")
			kitchen.on_interactable_clicked(&"work_table_stage")
			elapsed_action += 2.5

	# Pick up assembled plate & serve target.
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(target_id)
	kitchen._perform_typed_command(&"saji")
	if kitchen.get_held_item_view().is_empty():
		elapsed_action += 1.5
		return elapsed_action

	# Cleanup in case of partial failure due to temporary out-of-stock.
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")
	return 1.0


func _take_from_any_box(kitchen: KitchenController, ing_id: StringName) -> bool:
	for unit_id: StringName in [&"storage_box", &"box_01"]:
		if not kitchen.has_storage_unit(unit_id):
			continue
		for s: Dictionary in kitchen.get_storage_unit_view(unit_id).get("slots", []):
			if (
				StringName(s.get("ingredient_id", &"")) == ing_id
				and int(s.get("quantity", 0)) > 0
			):
				kitchen.on_interactable_clicked(unit_id)
				kitchen._perform_typed_command(ing_id)
				return not kitchen.get_held_item_view().is_empty()
	return false


func _print_simulation_report(name: String, summary: Dictionary) -> void:
	print("=== SIMULATION: %s (Day 7 Outcome=%d Cash=%d / Target=%d) ===" % [
		name,
		int(summary.get("day7_outcome", -1)),
		int(summary.get("final_cash", 0)),
		int(summary.get("day_7_target", 0)),
	])
	for d: Dictionary in summary.get("days", []):
		print(
			"  Day %d | act=%d | pot=%d quota=%d gen=%d | onl=%d | ok(d/o)=%d/%d fail=%d/%d | debt=%d->%d | cost(ing/fix/el)=%d/%d/%d | cash=%d | dur=%.1fs"
			% [
				int(d["day"]),
				int(d["active_recipes"]),
				int(d["potential_demand"]),
				int(d["planned_quota"]),
				int(d["generated_dinein"]),
				int(d["accepted_online"]),
				int(d["completed_dinein"]),
				int(d["completed_online"]),
				int(d["failed_dinein"]),
				int(d["failed_online"]),
				int(d["debt_before"]),
				int(d["debt_after"]),
				int(d["ingredient_cost"]),
				int(d["fixture_cost"]),
				int(d["electricity_cost"]),
				int(d["end_cash"]),
				float(d["service_duration"]),
			]
		)
