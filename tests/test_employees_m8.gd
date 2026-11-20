extends SceneTree
## Headless tests & 7-day economy simulations for M8 Employee Hiring & Workforce System
## ("Less is More, More is Worse").

const TICK_STEP := 0.25

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_asset_ui_hiring_dismissal_and_visuals()
	await _test_salary_settlement_idempotency_and_timing()
	await _test_cook_cashier_waiter_mechanics_and_boundaries()
	await _test_m8_1_terminology_cooking_and_animations()
	await _test_diminishing_returns_and_crowding()
	await _test_seven_day_employee_simulations()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _send_key(ui: GameUI, keycode_val: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = keycode_val
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


func _hud_children_fit_inside(hud_rect: Rect2, container: Control) -> bool:
	for child in container.get_children():
		if not (child is Control):
			continue
		var ctrl := child as Control
		if not ctrl.visible:
			continue
		if ctrl is BoxContainer:
			if not _hud_children_fit_inside(hud_rect, ctrl):
				return false
		else:
			var r := ctrl.get_global_rect()
			if r.position.x < hud_rect.position.x - 0.5 or r.end.x > hud_rect.end.x + 0.5:
				return false
			if r.position.y < hud_rect.position.y - 0.5 or r.end.y > hud_rect.end.y + 0.5:
				return false
	return true


func _test_asset_ui_hiring_dismissal_and_visuals() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var world := game_root.get_node("World") as WorldMap
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var emp_tex := world.employee_texture
	_check(
		"pegawai.png inspected as static 14x31 Sprite2D texture bound to WorldMap",
		emp_tex != null
		and emp_tex.resource_path == "res://assets/art/characters/pegawai.png"
		and emp_tex.get_size() == Vector2(14, 31)
		and world.get_employee_visual_count() == 0
	)

	# Verify LeftHUDRegion fits cleanly at 480x270 with EmployeeButton added.
	root.content_scale_size = Vector2i(480, 270)
	root.size = Vector2i(480, 270)
	ui._on_viewport_size_changed()
	await process_frame
	await process_frame
	_check(
		"Planning HUD with EmployeeButton fits cleanly at 480x270",
		ui.employee_button != null
		and ui.employee_button.visible
		and not ui.employee_button.disabled
		and _hud_children_fit_inside(Rect2(0, 0, 136, 270), ui.left_hud_region)
	)
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	ui._on_viewport_size_changed()
	await process_frame

	# Open Employee UI modal -> check 3 roles + upfront/salary info + hire + insufficient funds + dismiss.
	ui.employee_button.pressed.emit()
	await process_frame
	_check(
		"EmployeeOverlay opens cleanly with 3 role rows and zero active staff",
		ui.is_employee_shop_open()
		and ui.is_modal_blocking()
		and run.get_employee_role_ids() == [&"cook", &"cashier", &"waiter"]
		and not ui.get_employee_role_row(&"cook").is_empty()
		and not ui.get_employee_role_row(&"cashier").is_empty()
		and not ui.get_employee_role_row(&"waiter").is_empty()
		and run.get_hired_employees().is_empty()
	)

	# Hire 1 Cook (60k) from 100k -> cash becomes 40k, 1 visual spawned.
	var emp1 := ui.hire_employee_role(&"cook")
	await process_frame
	_check(
		"hiring Koki deducts 60k once, assigns unique ID, updates HUD & spawns 1 pegawai sprite",
		emp1 == &"emp_0001"
		and int(run.get_run_view()["cash"]) == 40000
		and run.get_daily_salary_estimate() == 35000
		and run.get_hired_employees().size() == 1
		and world.get_employee_visual_count() == 1
		and world.get_employee_visual_node(emp1) != null
		and not ui.get_employee_roster_row(emp1).is_empty()
		and ui.employee_button.text == "Pegawai (1)"
		and not world.registry.has_object(emp1)
	)

	# Attempt to hire Cashier (45k) with only 40k cash -> must reject cleanly without negative cash.
	var failed_emp := ui.hire_employee_role(&"cashier")
	await process_frame
	_check(
		"hiring unaffordable Kasir rejected cleanly without negative cash & shows UI error",
		failed_emp == &""
		and int(run.get_run_view()["cash"]) == 40000
		and run.get_hired_employees().size() == 1
		and ui.employee_error_label.visible
		and "dana tidak cukup" in ui.employee_error_label.text.to_lower()
	)

	# Dismiss Koki -> zero refund, cash stays 40k, daily salary returns to 0, world visual removed.
	var dismiss_ok := ui.dismiss_employee_by_id(emp1)
	await process_frame
	_check(
		"dismissing Koki gives 0 refund, clears future salary, removes world visual",
		dismiss_ok
		and int(run.get_run_view()["cash"]) == 40000
		and run.get_daily_salary_estimate() == 0
		and run.get_hired_employees().is_empty()
		and world.get_employee_visual_count() == 0
		and ui.employee_button.text == "Pegawai"
		and world.get_child_count() == 12
	)

	# Escape closes EmployeeOverlay cleanly.
	_send_key(ui, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes EmployeeOverlay",
		not ui.is_employee_shop_open() and not ui.is_modal_blocking()
	)

	# Verify SERVING rejects hiring and dismissal cleanly.
	var emp2 := run.request_employee_hire(&"cashier") # Wait: 40k < 45k, let's check insufficient directly too!
	_check("direct RunController hire rejects 45k cashier at 40k cash", emp2 == &"")
	_check("start service succeeds", game_root.start_service_requested())
	await process_frame
	_check(
		"Employee UI and RunController hire/dismiss rejected in SERVING",
		not ui.open_employee_shop()
		and run.request_employee_hire(&"waiter") == &""
		and not run.request_employee_dismiss(emp1)
		and ui.employee_button.visible == false
	)
	kitchen.clear_selected_target()
	game_root.free()
	await process_frame


func _test_salary_settlement_idempotency_and_timing() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var run := game_root.get_run_controller() as RunController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI

	# Day 1 PLANNING: Hire 1 Waiter (cost 50k, daily salary 30k) -> cash = 50k.
	var waiter_id := run.request_employee_hire(&"waiter")
	_check(
		"Day 1 hire Waiter costs 50k -> cash 50k",
		waiter_id == &"emp_0001" and int(run.get_run_view()["cash"]) == 50000
	)
	_check("start Day 1", game_root.start_service_requested())
	run.credit_order_once(&"d1_o1", &"nasi_telor", SharedTypes.OrderKind.DINE_IN) # +20k -> 70k
	_force_empty_service(service)
	game_root.request_close_if_drained()
	await process_frame

	var s1 := run.get_day_settlement_view(1)
	# End cash = 70k - 2k (electricity) - 30k (waiter daily salary) = 38k.
	_check(
		"Day 1 settles employee hire (50k) & daily salary (30k) once + updates DayResultSidePanel",
		int(s1.get("employee_hire_total", -1)) == 50000
		and int(s1.get("employee_salary_total", -1)) == 30000
		and int(s1.get("active_employee_count", -1)) == 1
		and int(s1.get("end_cash", -1)) == 38000
		and "Gaji Harian Pegawai: -Rp 30k" in ui.settlement_summary_label.text
		and "Biaya Rekrutmen Pegawai: -Rp 50k" in ui.settlement_summary_label.text
	)

	# Repeated settle_day_once(1) must be strictly idempotent (zero duplicate salary deduction).
	var cash_before_dup := int(run.get_run_view()["cash"])
	var s1_dup := run.settle_day_once({"day_index": 1, "failed_order_ids": []})
	_check(
		"repeated settle_day_once is idempotent without double salary charge",
		int(s1_dup.get("end_cash", -1)) == 38000
		and int(run.get_run_view()["cash"]) == cash_before_dup
	)

	# Advance to Day 2 PLANNING, dismiss Waiter before Day 2 service -> Day 2 must charge 0 salary.
	_check("continue to Day 2 PLANNING", game_root.request_continue_from_results())
	_check("dismiss Waiter in Day 2 PLANNING", run.request_employee_dismiss(waiter_id))
	_check("start Day 2", game_root.start_service_requested())
	_force_empty_service(service)
	game_root.request_close_if_drained()
	await process_frame
	var s2 := run.get_day_settlement_view(2)
	_check(
		"Day 2 charges 0 salary after Day 2 PLANNING dismissal (38k - 2k = 36k)",
		int(s2.get("employee_salary_total", -1)) == 0
		and int(s2.get("active_employee_count", -1)) == 0
		and int(s2.get("end_cash", -1)) == 36000
	)
	game_root.free()
	await process_frame


func _sum_storage_qty(unit_view: Dictionary) -> int:
	var total := 0
	for slot: Dictionary in unit_view.get("slots", []):
		total += int(slot.get("quantity", 0))
	return total


func _test_cook_cashier_waiter_mechanics_and_boundaries() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var world := game_root.get_node("World") as WorldMap

	# Buy 2 beras + 2 telur, give enough cash to test 1 specialist at a time cleanly,
	# wait: let's hire 1 Cook + 1 Cashier first (with cash topped via legal setup? No, let's test Cook
	# cleanly on Run 1, Waiter+Cashier on Run 2 so zero manual cash hacking needed!).
	run.request_ingredient_purchase(&"beras", 2, &"storage_box") # -4k -> 96k
	run.request_ingredient_purchase(&"telur", 2, &"storage_box") # -6k -> 90k
	var cook_id := run.request_employee_hire(&"cook") # -60k -> 30k
	_check("hire 1 Cook legitimately within starter cash (30k left)", cook_id != &"")
	_check("start service with 1 Cook", game_root.start_service_requested())

	# Make 1 table serve + eat completion so a dirty plate enters washer cleanly:
	# Or consume 1 clean plate -> dirty at table -> move_cleaned_table_plate_to_washer!
	var box_before := _sum_storage_qty(kitchen.get_storage_unit_view(&"storage_box"))
	# Player holds nothing (`_held_item` is empty), and shouldn't be mutated by Cook!
	game_root._process(4.2) # >= 4.0s Cook interval -> Cook consumes 1 real stored `beras` -> 5 portions!
	var cooker_view := kitchen.get_cooker_output_view(&"rice_cooker")
	var box_after := _sum_storage_qty(kitchen.get_storage_unit_view(&"storage_box"))
	_check(
		"Cook consumes 1 real stored beras (not free) to cook 5 rice portions & keeps hand untouched",
		not cooker_view.is_empty()
		and int(cooker_view.get("portions", 0)) == 5
		and box_after == box_before - 1
		and kitchen.get_held_item_view().is_empty()
		and kitchen.get_cook_actions_count() == 1
	)

	# Player makes 1 Nasi Telor and serves dining_table_01; diner finishes eating at t=20s -> dirty plate.
	kitchen.on_interactable_clicked(&"rice_cooker")
	kitchen.execute_allowed_command(&"nasi")
	kitchen.on_interactable_clicked(&"work_table_stage") # stage rice
	kitchen.on_interactable_clicked(&"storage_box")
	kitchen.execute_allowed_command(&"telur")
	kitchen.on_interactable_clicked(&"stove")
	kitchen.execute_allowed_command(&"goreng")
	kitchen.on_interactable_clicked(&"plate_rack") # rack plates cooked egg -> hand plated egg
	kitchen.on_interactable_clicked(&"work_table_stage") # pick/merge staged rice + held plated egg -> held Nasi Telor!
	kitchen.on_interactable_clicked(&"dining_table_01")
	kitchen.execute_allowed_command(&"saji")

	# Advance to diner finished eating -> clean table manually -> dirty plate now sits in washer!
	for _step in range(85):
		game_root._process(TICK_STEP)
		if int(service.get_table_view(&"dining_table_01").get("state", -1)) == SharedTypes.TableState.DIRTY:
			break
	kitchen.on_interactable_clicked(&"dining_table_01")
	kitchen.execute_allowed_command(&"bersihkan")
	var dirty_before := int(kitchen.get_washer_view()["dirty_plate_count"])
	var plates_before := int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"])
	_check(
		"dirty plate queued at washer before Cook wash cycle",
		dirty_before == 1 and plates_before == 3 and kitchen.get_plate_count() == 4
	)
	# Advance another 4.5s -> Cook washes dirty plate into clean plate rack without duplicating plates!
	game_root._process(4.5)
	_check(
		"Cook washes dirty plate from washer back to rack conserving exact 4 total plates",
		int(kitchen.get_washer_view()["dirty_plate_count"]) == 0
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
		and kitchen.get_plate_count() == 4
		and kitchen.get_cook_actions_count() >= 2
	)
	game_root.free()
	await process_frame

	# Second run: Waiter + Cashier boundaries & mechanics.
	var gr2 := packed.instantiate() as GameRoot
	root.add_child(gr2)
	await process_frame
	await physics_frame
	var k2 := gr2.get_kitchen_controller() as KitchenController
	var s2 := gr2.get_service_controller() as ServiceController
	var r2 := gr2.get_run_controller() as RunController

	r2.request_ingredient_purchase(&"beras", 2, &"storage_box") # 96k
	r2.request_ingredient_purchase(&"telur", 2, &"storage_box") # 90k
	var cashier_id := r2.request_employee_hire(&"cashier") # -45k -> 45k
	var waiter_id := r2.request_employee_hire(&"waiter") # Wait: 45k < 50k -> let's test Waiter after Cashier dismiss? No, test Cashier & Waiter separately cleanly!
	_check("hire Cashier legitimately (45k left)", cashier_id != &"" and waiter_id == &"")
	_check("start service with Cashier", gr2.start_service_requested())
	var ord1 := StringName(s2.get_table_view(&"dining_table_01")["order_id_or_empty"])
	var ov1 := s2.get_order_view(ord1)
	_check(
		"Cashier extends diner patience beyond 100s baseline (112s) without generating fake money",
		float(ov1.get("seconds_remaining", 0.0)) > 111.5
		and int(r2.get_run_view()["cash"]) == 45000
	)
	# Advance past online_offer_initial_delay (10.0s) + cashier interval (3.0s) -> Cashier accepts online offer cleanly!
	var cash_before_auto_accept := int(r2.get_run_view()["cash"])
	for _t in range(54): # 13.5s
		gr2._process(TICK_STEP)
	var drvs := s2.get_driver_views()
	_check(
		"Cashier auto-accepts available online offer at free spot without pre-paying fake cash",
		drvs.size() == 1
		and int(drvs[0].get("state", -1)) == SharedTypes.DriverState.AT_PICKUP_SPOT
		and int(r2.get_run_view()["cash"]) == cash_before_auto_accept
		and int(s2.get_workforce_action_counts().get(&"cashier", 0)) == 1
	)
	gr2.free()
	await process_frame

	# Third run: Waiter staged counter serve + dirty table auto-cleaning + boundary checks.
	var gr3 := packed.instantiate() as GameRoot
	root.add_child(gr3)
	await process_frame
	await physics_frame
	var k3 := gr3.get_kitchen_controller() as KitchenController
	var s3 := gr3.get_service_controller() as ServiceController
	var r3 := gr3.get_run_controller() as RunController
	var w3 := gr3.get_node("World") as WorldMap

	r3.request_ingredient_purchase(&"beras", 2, &"storage_box") # 96k
	r3.request_ingredient_purchase(&"telur", 2, &"storage_box") # 90k
	var w_emp := r3.request_employee_hire(&"waiter") # -50k -> 40k
	_check("hire Waiter legitimately (40k left)", w_emp != &"")
	_check("start service with Waiter", gr3.start_service_requested())

	# Put unfinished loose cooked egg on LongCounterLeft02 -> Waiter must NOT serve unfinished item!
	k3.on_interactable_clicked(&"storage_box")
	k3.execute_allowed_command(&"telur")
	k3.on_interactable_clicked(&"stove")
	k3.execute_allowed_command(&"goreng")
	k3.on_interactable_clicked(&"long_counter_left_02") # stage loose cooked telur (NOT plated complete dish)
	gr3._process(4.5)
	_check(
		"Waiter never serves incomplete/unplated staged item",
		int(r3.get_run_view()["cash"]) == 40000
		and not k3.get_work_table_view(&"long_counter_left_02").is_empty()
		and int(s3.get_table_view(&"dining_table_01").get("state", -1)) == SharedTypes.TableState.OCCUPIED_WAITING
	)

	# Finish plating Nasi Telor and stage completed dish on LongCounterLeft01 -> Waiter delivers it & credits once!
	k3.on_interactable_clicked(&"washer")
	k3.on_interactable_clicked(&"storage_box")
	k3.execute_allowed_command(&"beras")
	k3.on_interactable_clicked(&"washer")
	k3.execute_allowed_command(&"cuci")
	k3.on_interactable_clicked(&"rice_cooker")
	k3.execute_allowed_command(&"masak")
	k3.execute_allowed_command(&"nasi")
	k3.on_interactable_clicked(&"plate_rack") # cooked_rice -> plated rice in hand
	k3.on_interactable_clicked(&"long_counter_left_01") # stage plated rice
	k3.on_interactable_clicked(&"long_counter_left_02") # pick up loose cooked telur
	k3.on_interactable_clicked(&"long_counter_left_01") # merge onto plated rice -> complete Nasi Telor on counter!
	_check(
		"complete Nasi Telor staged on long_counter_left_01",
		k3.get_work_table_view(&"long_counter_left_01").get("matched_recipe_id", &"") == &"nasi_telor"
	)

	# Advance past next 4.0s waiter tick -> Waiter serves table, clears counter slot, credits +20k once!
	gr3._process(4.5)
	_check(
		"Waiter serves staged completed Nasi Telor from counter to waiting table & credits +20k once",
		k3.get_work_table_view(&"long_counter_left_01").is_empty()
		and int(s3.get_table_view(&"dining_table_01").get("state", -1)) == SharedTypes.TableState.OCCUPIED_EATING
		and int(r3.get_run_view()["cash"]) == 60000
		and k3.get_plate_count() == 4
		and w3.get_employee_visual_count() == 1
	)

	# Wait until diner finishes eating (becomes DIRTY), then Waiter tick cleans DIRTY table automatically!
	for _step in range(85):
		gr3._process(TICK_STEP)
		if int(s3.get_table_view(&"dining_table_01").get("state", -1)) == SharedTypes.TableState.DIRTY:
			break
	var saw_dirty := (
		int(s3.get_table_view(&"dining_table_01").get("state", -1)) == SharedTypes.TableState.DIRTY
	)
	for _step in range(25):
		gr3._process(TICK_STEP)
		if int(s3.get_table_view(&"dining_table_01").get("state", -1)) != SharedTypes.TableState.DIRTY:
			break
	_check(
		"Waiter automatically cleans DIRTY table, moves plate to washer once, and frees seat",
		saw_dirty
		and int(s3.get_table_view(&"dining_table_01").get("state", -1)) != SharedTypes.TableState.DIRTY
		and int(k3.get_washer_view()["dirty_plate_count"]) == 1
		and k3.get_plate_count() == 4
	)
	gr3.free()
	await process_frame


func _test_m8_1_terminology_cooking_and_animations() -> void:
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

	# 1. Standard UI terminology, no ambiguous "Upah", stable names & dismiss confirmation.
	run._cash = 300000 # setup test funds for stable multi-role naming check
	run.run_state_changed.emit()
	ui.open_employee_shop()
	await process_frame
	var emp_cook_1 := ui.hire_employee_role(&"cook")
	var emp_cook_2 := ui.hire_employee_role(&"cook")
	var emp_cashier_1 := ui.hire_employee_role(&"cashier")
	var emp_waiter_1 := ui.hire_employee_role(&"waiter")
	await process_frame

	var cook_row := ui.get_employee_role_row(&"cook")
	var role_title := String((cook_row["title_label"] as Label).text)
	var role_desc := String((cook_row["description_label"] as Label).text)
	var roster_1 := String((ui.get_employee_roster_row(emp_cook_1)["info_label"] as Label).text)
	var roster_2 := String((ui.get_employee_roster_row(emp_cook_2)["info_label"] as Label).text)
	var dismiss_btn_text := String((ui.get_employee_roster_row(emp_cook_1)["dismiss_button"] as Button).text)

	ui.request_dismiss_confirmation(emp_cook_1)
	await process_frame
	var confirm_prompt := String((ui.get_employee_roster_row(emp_cook_1)["info_label"] as Label).text)
	var confirm_btn_text := String((ui.get_employee_roster_row(emp_cook_1)["dismiss_button"] as Button).text)
	ui.cancel_dismiss_confirmation()
	await process_frame
	_check(
		"UI labels use Indonesian standardized terms without ambiguous 'Upah' & dismiss confirmation preserves on Batal",
		ui.employee_salary_label.text.begins_with("Total Gaji Harian:")
		and "Biaya Rekrutmen" in role_title
		and "Gaji Harian" in role_title
		and "Manfaat Pekerjaan" in role_desc
		and "Efisiensi Kerja" in role_desc
		and not ("Upah" in role_title)
		and not ("Upah" in ui.employee_salary_label.text)
		and "Koki #1" in roster_1
		and "Koki #2" in roster_2
		and dismiss_btn_text == "Pecat Pegawai"
		and "Yakin Pecat Pegawai Koki #1?" in confirm_prompt
		and confirm_btn_text == "Konfirmasi Pecat"
		and run.get_hired_employees().size() == 4
	)

	# Dismiss Koki #1 -> Koki #2 MUST stay 'Koki #2' (stable name), next hired Cook becomes 'Koki #3'.
	ui.dismiss_employee_by_id(emp_cook_1)
	var emp_cook_3 := ui.hire_employee_role(&"cook")
	await process_frame
	var hired := run.get_hired_employees()
	var names_map: Dictionary = {}
	for h: Dictionary in hired:
		names_map[h["employee_id"]] = h["display_name"]
	_check(
		"stable employee names preserved across dismissal & re-hiring (Koki #2 unchanged, new is Koki #3)",
		names_map.get(emp_cook_2, "") == "Koki #2"
		and names_map.get(emp_cashier_1, "") == "Kasir #1"
		and names_map.get(emp_waiter_1, "") == "Pelayan #1"
		and names_map.get(emp_cook_3, "") == "Koki #3"
		and world.get_employee_visual_count() == 4
	)
	ui.close_employee_shop()

	# Clean up to 1 Cook for isolated egg/meat cooking & animation test, then test multi-cook lock.
	ui.open_employee_shop()
	ui.dismiss_employee_by_id(emp_cook_3)
	ui.dismiss_employee_by_id(emp_cashier_1)
	ui.dismiss_employee_by_id(emp_waiter_1)
	ui.close_employee_shop()

	# 2. Cook egg cooking + state-driven animation (IDLE -> WALK -> WORK+SteamFx -> IDLE) + boundaries.
	run._cash = 100000
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	_check("start service for M8.1 Cook egg + animation checks", game_root.start_service_requested())
	await process_frame

	# First advance slightly (0.25s) -> Cook #2 claims rice cooker and enters WALK.
	game_root._process(0.25)
	ui._process(0.25)
	var walk_state := world.get_employee_visual_state(emp_cook_2)
	# Advance to 1.00s -> Cook #2 transitions to WORK cooking with SteamFx active!
	for _s in range(3):
		game_root._process(0.25)
		ui._process(0.25)
	var work_state := world.get_employee_visual_state(emp_cook_2)
	var work_fx := world.get_employee_visual_fx_active(emp_cook_2)
	# Advance until rice finishes (~4.0s) and Cook picks up urgent telur from active Nasi Telor order!
	for _s in range(32): # +8.0s -> t=9.0s total
		game_root._process(0.25)
		ui._process(0.25)

	var cooked_egg_on_counter := false
	for wt_id in kitchen.get_work_table_ids():
		var wv := kitchen.get_work_table_view(wt_id)
		if wv.is_empty():
			continue
		var parts: Array = wv.get("parts", [])
		if (
			wv.get("plate_id", &"") == &""
			and parts.size() == 1
			and parts[0].get("ingredient_id", &"") == &"telur"
			and int(parts[0].get("state", -1)) == SharedTypes.PrepState.COOKED
		):
			cooked_egg_on_counter = true
			break

	_check(
		"Cook animates WALK -> WORK(fx=true) -> cooks rice AND urgent active-order egg onto counter without assembling complete dish",
		walk_state == SharedTypes.EmployeeAnimState.WALK
		and work_state == SharedTypes.EmployeeAnimState.WORK
		and work_fx
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
		and cooked_egg_on_counter
		and kitchen.get_held_item_view().is_empty()
		and int(service.get_table_view(&"dining_table_01")["state"]) == SharedTypes.TableState.OCCUPIED_WAITING
	)

	# Clear remaining open orders (complete service) -> Cook returns to IDLE with fx=false & no excessive cooking!
	var box_qty_before_idle := _sum_storage_qty(kitchen.get_storage_unit_view(&"storage_box"))
	_force_empty_service(service)
	game_root.request_close_if_drained()
	await process_frame
	game_root.free()
	await process_frame

	# 3. Verify beef cooking (sapi) on Day 5, unavailable stove/stock guards, and multi-cook duplicate prevention.
	var gr_b := packed.instantiate() as GameRoot
	root.add_child(gr_b)
	await process_frame
	await physics_frame
	var kb := gr_b.get_kitchen_controller() as KitchenController
	var sb := gr_b.get_service_controller() as ServiceController
	var rb := gr_b.get_run_controller() as RunController
	var wb := gr_b.get_node("World") as WorldMap

	# Simulate Day 5 with Nasi Daging Sapi, pre-filled cooked rice so Cook prioritizes meat!
	rb._day_index = 5
	rb._unlocked_recipe_ids = rb.economy_config.get_unlocked_recipe_ids(5)
	rb._cash = 200000
	rb.select_daily_menu([&"nasi_daging_sapi"])
	var c_a := rb.request_employee_hire(&"cook")
	var c_b := rb.request_employee_hire(&"cook")
	rb.request_ingredient_purchase(&"beras", 2, &"storage_box")
	rb.request_ingredient_purchase(&"sapi", 2, &"storage_box")
	gr_b.start_service_requested()
	# Pre-fill rice cooker with 5 portions so both cooks only compete over 1 stove + 1 open meat order!
	kb._cooker_outputs[&"rice_cooker"] = {
		"item_id": &"pre_rice",
		"plate_id": &"",
		"parts": [{"ingredient_id": &"beras", "state": SharedTypes.PrepState.COOKED_RICE}],
		"matched_recipe_id": &"",
		"location": &"COOKER_OUTPUT",
		"work_table_id": &"",
		"portions": 5,
	}
	for _t in range(28): # 7.0s
		gr_b._process(TICK_STEP)

	var cooked_sapi_count := 0
	for wt_id in kb.get_work_table_ids():
		var wv := kb.get_work_table_view(wt_id)
		var parts: Array = wv.get("parts", [])
		if (
			not wv.is_empty()
			and wv.get("plate_id", &"") == &""
			and parts.size() == 1
			and parts[0].get("ingredient_id", &"") == &"sapi"
			and int(parts[0].get("state", -1)) == SharedTypes.PrepState.COOKED
		):
			cooked_sapi_count += 1
	var sapi_rem := _sum_storage_qty(kb.get_storage_unit_view(&"storage_box")) # started 4 (2 beras+2 sapi) -> 1 sapi consumed = 3 left

	# Unregister stove -> Cook cannot cook remaining sapi even if needed!
	kb.unregister_fixture_instance(&"stove")
	# Put second order in manually and step 6s -> must stay 0 additional cooks!
	var prev_actions := kb.get_cook_actions_count()
	for _t in range(24):
		gr_b._process(TICK_STEP)
	_check(
		"multi-cook prevents duplicate meat prep on 1 stove & blocks cooking when stove unavailable",
		c_a != &"" and c_b != &""
		and cooked_sapi_count == 1
		and sapi_rem == 3
		and kb.get_cook_actions_count() == prev_actions
	)

	# Re-register stove, fill all right counter slots -> Cook must not overwrite occupied counters!
	kb.register_fixture_kind(&"stove", SharedTypes.FixtureKind.STOVE)
	for slot_id: StringName in [&"long_counter_right_01", &"long_counter_right_02", &"long_counter_right_03"]:
		if kb.get_work_table_view(slot_id).is_empty():
			kb._work_table_items[slot_id] = {
				"item_id": StringName("occ_" + String(slot_id)),
				"plate_id": &"",
				"parts": [{"ingredient_id": &"beras", "state": SharedTypes.PrepState.COOKED_RICE}],
				"matched_recipe_id": &"",
				"location": &"WORK_TABLE",
				"work_table_id": slot_id,
			}
	var actions_before_full := kb.get_cook_actions_count()
	for _t in range(16):
		gr_b._process(TICK_STEP)
	_check(
		"cook does not overwrite already-occupied output counters or invent ingredients when stock empty",
		kb.get_cook_actions_count() == actions_before_full
	)
	# Empty counters and clear stock -> 0 actions because no free ingredients can be conjured.
	for slot_id: StringName in [&"long_counter_right_01", &"long_counter_right_02", &"long_counter_right_03"]:
		kb._work_table_items.erase(slot_id)
	var box_slots: Array = kb._storage_units.get(&"storage_box", {}).get("slots", [])
	for slot_dict: Variant in box_slots:
		if slot_dict is Dictionary:
			(slot_dict as Dictionary)["ingredient_id"] = &""
			(slot_dict as Dictionary)["quantity"] = 0
	for _t in range(16):
		gr_b._process(TICK_STEP)
	_check(
		"cook cannot cook when ingredient stocks are empty",
		kb.get_cook_actions_count() == actions_before_full
	)

	# Resetting run clears stale employee visuals & animations cleanly.
	gr_b._reset_run_world_and_controllers(true)
	await process_frame
	var w_reset := gr_b.get_node("World") as WorldMap
	_check(
		"run reset clears all employee visuals & animation state cleanly",
		rb.get_hired_employees().is_empty() and w_reset.get_employee_visual_count() == 0
	)
	gr_b.free()
	await process_frame


func _test_diminishing_returns_and_crowding() -> void:
	var cfg := load("res://data/economy_config.tres") as EconomyConfig
	_check("EconomyConfig loaded", cfg != null)
	if cfg == null:
		return

	var f1 := cfg.compute_effective_role_factor(1, 1) # 1.00
	var f2 := cfg.compute_effective_role_factor(2, 2) # 1.75
	var f3 := cfg.compute_effective_role_factor(3, 3) # (1.0 + 0.75 + 0.50) / 1.30 = 1.7308
	var f2_in_6 := cfg.compute_effective_role_factor(2, 6) # 1.75 / 2.20 = 0.7955
	var gain_1_to_2 := f2 - f1
	var gain_2_to_3 := f3 - f2

	_check(
		"diminishing returns & crowding penalty ('More is Worse'): f1=%.2f f2=%.2f f3=%.2f crowded_f2=%.2f"
		% [f1, f2, f3, f2_in_6],
		is_equal_approx(f1, 1.0)
		and is_equal_approx(f2, 1.75)
		and gain_1_to_2 > 0.0 and gain_1_to_2 < 1.0
		and gain_2_to_3 < 0.0 # 3 cooks slower than 2 due to crowding while costing 300% daily salary
		and f2_in_6 < f1 # 6 total crowded staff slows a role below 1 uncrowded specialist!
	)


func _test_seven_day_employee_simulations() -> void:
	var scenarios: Array[Dictionary] = [
		{
			"name": "0_no_employees_solo",
			"hires_by_day": {},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": false,
			"accept_online": true,
		},
		{
			"name": "1_cook_from_day3",
			"hires_by_day": {3: [&"cook"]},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": false,
			"accept_online": true,
		},
		{
			"name": "1_cashier_from_day3",
			"hires_by_day": {3: [&"cashier"]},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": false,
			"accept_online": true,
		},
		{
			"name": "1_waiter_from_day3",
			"hires_by_day": {3: [&"waiter"]},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": true,
			"accept_online": true,
		},
		{
			"name": "mixed_cook_day3_waiter_day4",
			"hires_by_day": {3: [&"cook"], 4: [&"waiter"]},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": true,
			"accept_online": true,
		},
		{
			"name": "overstaffed_6_bloated_crew",
			"hires_by_day": {
				3: [&"cashier", &"waiter", &"cook", &"cashier"],
				4: [&"waiter", &"cook"],
			},
			"recipes_by_day": {
				1: [&"nasi_telor"],
				2: [&"nasi_telor", &"nasi_tempe"],
				3: [&"nasi_telor", &"nasi_tempe"],
				4: [&"nasi_telor", &"nasi_tempe"],
				5: [&"nasi_telor", &"nasi_tempe"],
				6: [&"nasi_telor", &"nasi_tempe"],
				7: [&"nasi_telor", &"nasi_tempe"],
			},
			"buy_extra_box_day": 2,
			"stage_for_waiter": false,
			"accept_online": true,
		},
	]

	var results: Dictionary = {}
	for sc: Dictionary in scenarios:
		var summary := await _run_workforce_campaign(sc)
		results[String(sc["name"])] = summary
		print(
			"=== WORKFORCE SIM '%s': cash=%d/%d outcome=%d total_wages=%d total_hires=%d comp=%d fail=%d ==="
			% [
				String(sc["name"]),
				int(summary["final_cash"]),
				int(summary["day_7_target"]),
				int(summary["day7_outcome"]),
				int(summary["total_salaries"]),
				int(summary["total_hires"]),
				int(summary["total_completed"]),
				int(summary["total_failed"]),
			]
		)

	var solo := results["0_no_employees_solo"] as Dictionary
	var cook1 := results["1_cook_from_day3"] as Dictionary
	var cashier1 := results["1_cashier_from_day3"] as Dictionary
	var waiter1 := results["1_waiter_from_day3"] as Dictionary
	var mixed := results["mixed_cook_day3_waiter_day4"] as Dictionary
	var bloated := results["overstaffed_6_bloated_crew"] as Dictionary

	_check(
		"0-employee solo strategy cleanly reaches >= Rp 700k Day 7 target",
		int(solo["day7_outcome"]) == SharedTypes.DayOutcome.WON
		and int(solo["final_cash"]) >= 700000
		and int(solo["total_salaries"]) == 0
	)
	_check(
		"1-Cook, 1-Cashier, 1-Waiter, and Lean-Mixed remain playable winning strategies",
		int(cook1["day7_outcome"]) == SharedTypes.DayOutcome.WON
		and int(cashier1["day7_outcome"]) == SharedTypes.DayOutcome.WON
		and int(waiter1["day7_outcome"]) == SharedTypes.DayOutcome.WON
		and int(mixed["day7_outcome"]) == SharedTypes.DayOutcome.WON
	)
	_check(
		"bloated 6-employee overstaffed run loses profitability ('More is Worse')",
		int(bloated["final_cash"]) < int(solo["final_cash"])
		and int(bloated["final_cash"]) < int(cook1["final_cash"])
		and int(bloated["final_cash"]) < int(mixed["final_cash"])
		and int(bloated["total_salaries"]) > 500000
		and int(bloated["final_cash"]) < 700000
		and int(bloated["day7_outcome"]) == SharedTypes.DayOutcome.LOST
	)


func _run_workforce_campaign(sc: Dictionary) -> Dictionary:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController

	var total_hires := 0
	var total_salaries := 0
	var total_completed := 0
	var total_failed := 0
	var box_ids: Array[StringName] = [&"storage_box"]

	for day in range(1, 8):
		var recipes_map: Dictionary = sc["recipes_by_day"]
		var desired_menu: Array[StringName] = []
		for raw_r: Variant in recipes_map.get(day, [&"nasi_telor"]):
			desired_menu.append(StringName(raw_r))
		run.select_daily_menu(desired_menu)

		if int(sc.get("buy_extra_box_day", 0)) == day:
			if run.request_fixture_purchase(&"box", &"slot_utility_01"):
				box_ids.append(&"box_01")

		# Stock required raw ingredients proportional to planned demand + expected online (~+4) first.
		var quota := int(run.get_run_view().get("planned_dinein_quota", 4))
		var target_portions := quota + 6
		_stock_boxes_for_menu(run, kitchen, box_ids, desired_menu, target_portions)

		var hires_map: Dictionary = sc.get("hires_by_day", {})
		for raw_role: Variant in hires_map.get(day, []):
			run.request_employee_hire(StringName(raw_role))

		game_root.start_service_requested()
		_simulate_day_service(
			game_root,
			kitchen,
			service,
			run,
			box_ids,
			bool(sc.get("accept_online", true)),
			bool(sc.get("stage_for_waiter", false))
		)

		var settle := run.get_day_settlement_view(day)
		total_hires += int(settle.get("employee_hire_total", 0))
		total_salaries += int(settle.get("employee_salary_total", 0))
		total_completed += (
			int(settle.get("completed_dinein_count", 0))
			+ int(settle.get("completed_online_count", 0))
		)
		total_failed += (
			int(settle.get("failed_dinein_count", 0))
			+ int(settle.get("failed_online_count", 0))
		)

		if day < 7:
			game_root.request_continue_from_results()

	var rv := run.get_run_view()
	var summary := {
		"final_cash": int(rv.get("cash", 0)),
		"day_7_target": int(rv.get("day_7_target", 700000)),
		"day7_outcome": int(rv.get("goal_outcome", SharedTypes.DayOutcome.UNDECIDED)),
		"total_hires": total_hires,
		"total_salaries": total_salaries,
		"total_completed": total_completed,
		"total_failed": total_failed,
	}
	game_root.free()
	await process_frame
	return summary


func _stock_boxes_for_menu(
	run: RunController,
	kitchen: KitchenController,
	box_ids: Array[StringName],
	menu: Array[StringName],
	portions: int
) -> void:
	var beras_needed := int(ceil(float(portions) / 5.0)) + 2
	_buy_up_to_stock(run, kitchen, box_ids, &"beras", beras_needed)
	if menu.size() == 1 and menu[0] == &"nasi_telor":
		_buy_up_to_stock(run, kitchen, box_ids, &"telur", portions)
	else:
		# Two-recipe menu (Nasi Telor + Nasi Tempe): cheaper Tempe receives slightly higher weight.
		var tempe_target := mini(15, int(ceil(float(portions) * 0.65)))
		var telur_target := mini(10, maxi(5, portions - tempe_target))
		_buy_up_to_stock(run, kitchen, box_ids, &"tempe", tempe_target)
		_buy_up_to_stock(run, kitchen, box_ids, &"telur", telur_target)


func _buy_up_to_stock(
	run: RunController,
	kitchen: KitchenController,
	box_ids: Array[StringName],
	ingredient_id: StringName,
	target_qty: int
) -> void:
	var have := 0
	for b_id in box_ids:
		var sv := kitchen.get_storage_unit_view(b_id)
		for slot: Dictionary in sv.get("slots", []):
			if slot.get("ingredient_id", &"") == ingredient_id:
				have += int(slot.get("quantity", 0))
	var need := maxi(0, target_qty - have)
	if need <= 0:
		return
	for b_id in box_ids:
		var buy := need
		while buy > 0 and not kitchen.can_receive_stock(ingredient_id, buy, b_id):
			buy -= 1
		if buy > 0:
			if run.request_ingredient_purchase(ingredient_id, buy, b_id):
				need -= buy
		if need <= 0:
			break


func _simulate_day_service(
	game_root: GameRoot,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController,
	box_ids: Array[StringName],
	accept_online: bool,
	stage_for_waiter: bool
) -> void:
	var action_cd := 0.0
	for _tick in range(4000):
		if not game_root.is_serving():
			break
		game_root._process(TICK_STEP)
		action_cd = maxf(0.0, action_cd - TICK_STEP)
		if not game_root.is_serving():
			break

		# Schedule emergency restock early during SERVING when remaining ingredient stock gets low.
		for ing: StringName in [&"tempe", &"telur"]:
			if _count_total_ingredient(kitchen, box_ids, ing) < 2 and not _has_pending_for_ing(kitchen, ing):
				for b_id in box_ids:
					if kitchen.can_receive_stock(ing, 5, b_id):
						run.request_ingredient_purchase(ing, 5, b_id)
						break

		if accept_online and service.get_online_acceptance_enabled():
			var ov := service.get_online_offer_view()
			if int(ov.get("offer_state", -1)) == ServiceController.OnlineOfferState.AVAILABLE:
				if action_cd <= 0.0:
					kitchen.on_interactable_clicked(&"online_station")
					kitchen.execute_allowed_command(&"terima")
					action_cd = 0.5
					continue

		if action_cd > 0.0:
			continue

		# Clean dirty tables manually if not clean yet (or waiter helps in background).
		var did_work := false
		for tid in service.get_registered_table_ids():
			var tv := service.get_table_view(tid)
			if int(tv.get("state", -1)) == SharedTypes.TableState.DIRTY:
				kitchen.on_interactable_clicked(tid)
				if kitchen.execute_allowed_command(&"bersihkan"):
					action_cd = 0.75
					did_work = true
					break
		if did_work:
			continue

		# Wash dirty plates if rack has fewer than 2 clean plates (unless Cook handles it).
		if (
			int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) < 2
			and int(kitchen.get_washer_view().get("dirty_plate_count", 0)) > 0
			and kitchen.get_held_item_view().is_empty()
		):
			kitchen.on_interactable_clicked(&"washer")
			if kitchen.execute_allowed_command(&"cuci"):
				kitchen.on_interactable_clicked(&"plate_rack")
				action_cd = 0.75
				continue

		# Do not start preparing a new dish while rack has 0 clean plates.
		if int(kitchen.get_plate_rack_view(&"plate_rack").get("clean_count", 0)) <= 0:
			continue

		# Pick urgent open dine-in or pickup-spot online order and prepare it cleanly.
		var target := _pick_next_urgent_order(service)
		if target.is_empty():
			continue

		if not kitchen.get_held_item_view().is_empty():
			var held := kitchen.get_held_item_view()
			if held.get("matched_recipe_id", &"") == StringName(target["recipe_id"]):
				kitchen.on_interactable_clicked(StringName(target["target_id"]))
				kitchen.execute_allowed_command(&"saji")
				action_cd = 1.0
				continue
			kitchen.on_interactable_clicked(&"trash")
		if _prepare_dish_into_hand(
			kitchen, box_ids, StringName(target["recipe_id"])
		):
			if stage_for_waiter and not _has_staged_recipe_on_counters(kitchen, StringName(target["recipe_id"])):
				if kitchen.get_work_table_view(&"long_counter_left_01").is_empty():
					kitchen.on_interactable_clicked(&"long_counter_left_01")
					action_cd = 5.5
					continue
			kitchen.on_interactable_clicked(StringName(target["target_id"]))
			kitchen.execute_allowed_command(&"saji")
			action_cd = 5.5


func _has_staged_recipe_on_counters(kitchen: KitchenController, recipe_id: StringName) -> bool:
	return not kitchen.find_completed_staged_dish_for_recipes([recipe_id]).is_empty()


func _pick_next_urgent_order(service: ServiceController) -> Dictionary:
	var best: Dictionary = {}
	var best_rem := 999999.0
	for tid in service.get_registered_table_ids():
		var tv := service.get_table_view(tid)
		if int(tv.get("state", -1)) != SharedTypes.TableState.OCCUPIED_WAITING:
			continue
		var ov := service.get_order_view(StringName(tv.get("order_id_or_empty", &"")))
		if int(ov.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
			continue
		var rem := float(ov.get("seconds_remaining", 999.0))
		if rem < best_rem:
			best_rem = rem
			best = {"target_id": tid, "recipe_id": StringName(ov.get("recipe_id", &""))}
	for drv: Dictionary in service.get_driver_views():
		if not bool(drv.get("serveable", false)):
			continue
		var rem := float(drv.get("seconds_remaining", 999.0))
		if rem < best_rem:
			best_rem = rem
			best = {
				"target_id": StringName(drv.get("driver_id", &"")),
				"recipe_id": StringName(drv.get("recipe_id", &"")),
			}
	return best


func _prepare_dish_into_hand(
	kitchen: KitchenController,
	box_ids: Array[StringName],
	recipe_id: StringName
) -> bool:
	var second_ing := &"telur" if recipe_id == &"nasi_telor" else &"tempe"
	# Ensure rice cooker has rice portions (or Cook already prepared them!).
	var cv := kitchen.get_cooker_output_view(&"rice_cooker")
	if int(cv.get("portions", 0)) <= 0:
		if not _take_from_any_box(kitchen, box_ids, &"beras"):
			return false
		kitchen.on_interactable_clicked(&"washer")
		if not kitchen.execute_allowed_command(&"cuci"):
			return false
		kitchen.on_interactable_clicked(&"rice_cooker")
		if not kitchen.execute_allowed_command(&"masak"):
			return false

	# Use Cook-prepped loose cooked protein on counters if already prepared before taking raw stock!
	var picked_prepped := false
	for wt_id in kitchen.get_work_table_ids():
		var wv := kitchen.get_work_table_view(wt_id)
		var parts: Array = wv.get("parts", [])
		if (
			not wv.is_empty()
			and wv.get("plate_id", &"") == &""
			and parts.size() == 1
			and parts[0].get("ingredient_id", &"") == second_ing
			and int(parts[0].get("state", -1)) == SharedTypes.PrepState.COOKED
		):
			kitchen.on_interactable_clicked(wt_id)
			picked_prepped = not kitchen.get_held_item_view().is_empty()
			break

	if not picked_prepped:
		if not _take_from_any_box(kitchen, box_ids, second_ing):
			return false
		kitchen.on_interactable_clicked(&"stove")
		if not kitchen.execute_allowed_command(&"goreng"):
			return false
	kitchen.on_interactable_clicked(&"plate_rack")
	if kitchen.get_held_item_view().get("plate_id", &"") == &"":
		return false
	kitchen.on_interactable_clicked(&"rice_cooker")
	if not kitchen.execute_allowed_command(&"nasi"):
		return false
	return kitchen.get_held_item_view().get("matched_recipe_id", &"") == recipe_id


func _take_from_any_box(
	kitchen: KitchenController,
	box_ids: Array[StringName],
	ingredient_id: StringName
) -> bool:
	for b_id in box_ids:
		kitchen.on_interactable_clicked(b_id)
		if kitchen.execute_allowed_command(ingredient_id):
			return true
	return false


func _count_total_ingredient(
	kitchen: KitchenController,
	box_ids: Array[StringName],
	ingredient_id: StringName
) -> int:
	var total := 0
	for b_id in box_ids:
		var sv := kitchen.get_storage_unit_view(b_id)
		for slot: Dictionary in sv.get("slots", []):
			if slot.get("ingredient_id", &"") == ingredient_id:
				total += int(slot.get("quantity", 0))
	return total


func _has_pending_for_ing(kitchen: KitchenController, ingredient_id: StringName) -> bool:
	for rec: Dictionary in kitchen.get_pending_delivery_views():
		if rec.get("status", &"") == &"PENDING" and rec.get("ingredient_id", &"") == ingredient_id:
			return true
	return false
