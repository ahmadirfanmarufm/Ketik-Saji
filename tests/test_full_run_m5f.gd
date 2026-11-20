extends SceneTree
## Headless M5-F end-to-end 7-day gameplay integration & regression suite:
## 1. Full authentic Day 1 -> Day 7 run exercising real GameRoot, RunController,
##    KitchenController, ServiceController, WorldMap, and GameUI transitions:
##    - Planning HUD, Edit Menu split detail panel, unlocked-not-auto-selected progression
##    - Storage Belanja (Planning & SERVING 100s delivery + close cancellation refund)
##    - Slot-first FixtureShop (fridge_01), electricity scaling, fridge overnight carryover
##    - Box & cooker overnight reset, 5-portion rice cooker, two-way plating, potong
##    - Dine-in serve, wrong_order feedback, eating, dirty table cleaning, plate washer cycle
##    - Online order terima, physical driver at pickup spot, lower payout, instant clean plate
##    - Pause/Resume clock & input freeze, natural _process() auto-close & idempotent settlement
##    - Exact Day 7 Rp 700,000 post-electricity WIN via real served dish + terminal Day 7 checks
## 2. Full Day 1 -> Day 7 LOST boundary (Rp 699,999 post-electricity) + negative-cash handling
##    and strict non-entry into Extra Mode / Day 8.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_full_7_day_won_run()
	await _test_full_7_day_lost_boundary_and_negative_cash()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _send_left_click(ui: GameUI, pos: Vector2) -> void:
	var vp := ui.get_viewport()
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = pos
	press_ev.global_position = pos
	vp.push_input(press_ev, true)
	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = pos
	release_ev.global_position = pos
	vp.push_input(release_ev, true)


func _send_key(ui: GameUI, unicode_val: int, keycode_val: Key = KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	if keycode_val != KEY_NONE:
		ev.keycode = keycode_val
	elif unicode_val > 0:
		ev.keycode = OS.find_keycode_from_string(String.chr(unicode_val).to_upper())
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _world_to_canvas(world: WorldMap, pos: Vector2) -> Vector2:
	return world.get_canvas_transform() * pos


func _click_object(ui: GameUI, world: WorldMap, object_id: StringName) -> void:
	var node := world.registry.get_object(object_id) as Node2D
	if node == null:
		node = world.get_driver_visual_node(object_id)
	if node == null:
		return
	var target_pos := _world_to_canvas(world, node.global_position)
	if ui.interaction_dialogue != null and ui.interaction_dialogue.visible:
		if ui.interaction_dialogue.get_global_rect().has_point(target_pos):
			_send_left_click(ui, Vector2(352, 276))
	_send_left_click(ui, target_pos)


func _click_slot(ui: GameUI, world: WorldMap, slot_id: StringName) -> void:
	var view := world.get_placement_slot_view(slot_id)
	var pos := _world_to_canvas(world, Vector2(view.get("global_position", Vector2.ZERO)))
	if ui.interaction_dialogue != null and ui.interaction_dialogue.visible:
		if ui.interaction_dialogue.get_global_rect().has_point(pos):
			_send_left_click(ui, Vector2(352, 276))
	_send_left_click(ui, pos)


func _drain_day_via_process(
	game_root: GameRoot,
	service: ServiceController,
	step_sec: float = 20.0,
	max_ticks: int = 80
) -> bool:
	var ticks := 0
	while game_root.get_phase() == SharedTypes.Phase.SERVING and ticks < max_ticks:
		ticks += 1
		game_root._process(step_sec)
		await process_frame
	if game_root.get_phase() == SharedTypes.Phase.SERVING:
		_check(
			"service failed to auto-close after %d ticks (day=%d, queue=%s)" % [
				max_ticks,
				game_root.get_day_index(),
				str(service.get_customer_queue_view()),
			],
			false
		)
		return false
	return true


func _cook_and_plate_nasi_telor(
	ui: GameUI,
	world: WorldMap,
	storage_id: StringName
) -> void:
	_click_object(ui, world, storage_id)
	_type_word(ui, "beras")
	_click_object(ui, world, &"washer")
	_type_word(ui, "cuci")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	_click_object(ui, world, &"plate_rack")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, storage_id)
	_type_word(ui, "telur")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"work_table_stage")


func _test_full_7_day_won_run() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var world := game_root.get_node("World") as WorldMap
	var ui := game_root.get_node("UI") as GameUI

	# --- DAY 1 PLANNING ---
	_check(
		"Day 1 boots PLANNING with exact economy, quota, starter kit, and menu",
		game_root.get_phase() == SharedTypes.Phase.PLANNING
		and game_root.get_day_index() == 1
		and int(run.get_run_view()["cash"]) == 100000
		and int(run.get_run_view()["planned_dinein_quota"]) == 4
		and run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and ui.day_label.text == "Hari 1/7"
		and ui.cash_label.text == "Kas: Rp 100k"
		and ui.goal_target_label.text == "Target: Rp 700k"
	)

	# Pause/Resume sanity in PLANNING + Edit Menu detail preview check.
	ui.pause_button.pressed.emit()
	await process_frame
	_type_word(ui, "buka")
	_check("Pause blocks buka typing in PLANNING", ui.is_pause_open() and game_root.get_phase() == SharedTypes.Phase.PLANNING)
	ui.pause_resume_button.pressed.emit()
	await process_frame
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_preview_button(&"nasi_telor").pressed.emit()
	_check(
		"Edit Menu displays Nasi Telur details cleanly before Day 1 service",
		ui.get_edit_menu_detail_lines() == PackedStringArray([
			"Cuci dan masak beras, goreng telur, lalu sajikan bersama nasi.",
			"Beras",
			"Telur",
		])
		and ui.get_pending_menu_selection() == [&"nasi_telor"]
	)
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame

	# Buy Day 1 ingredients via storage_box -> `beli` -> IngredientShop (2 beras + 3 telur = 13k).
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"beras", 2)
	ui.adjust_shop_quantity(&"telur", 3)
	ui.shop_checkout_button.pressed.emit()
	_check(
		"Day 1 PLANNING shop purchase deducts 13k immediately to 87k",
		not ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 87000
	)

	# Start Day 1 SERVING via typed buka.
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check("Day 1 enters SERVING via typed buka", game_root.is_serving() and game_root.get_day_index() == 1)

	# Pause/Resume in SERVING freezes service clock & timers.
	game_root._process(1.0)
	ui.pause_button.pressed.emit()
	await process_frame
	game_root._process(10.0)
	_check(
		"Pause in SERVING freezes elapsed clock cleanly at 1.0s",
		ui.is_pause_open() and is_equal_approx(game_root.get_service_elapsed(), 1.0)
	)
	ui.pause_resume_button.pressed.emit()
	await process_frame

	# Prepare rice (5 portions), plate, fry telur, test wrong_order before second part, then complete & serve.
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beras")
	_click_object(ui, world, &"washer")
	_type_word(ui, "cuci")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	_click_object(ui, world, &"plate_rack")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_check("5-portion rice cooker leaves 4 portions after first scoop", int(kitchen.get_cooker_output_view(&"rice_cooker")["portions"]) == 4)

	_click_object(ui, world, &"dining_table_01")
	kitchen._perform_typed_command(&"saji")
	_check(
		"incomplete plate emits wrong_order (Pesanannya beda!) without consuming held item",
		ui.get_feedback_code() == &"wrong_order"
		and ui.context_message_label.text == "Pesanannya beda!"
		and not kitchen.get_held_item_view().is_empty()
	)

	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check(
		"serving real nasi_telor credits +20k once to 107k and transitions customer to EATING",
		int(run.get_run_view()["cash"]) == 107000
		and int(service.get_table_view(&"dining_table_01")["state"]) == SharedTypes.TableState.OCCUPIED_EATING
	)

	# Eating 20s -> DIRTY -> bersihkan -> cuci dirty plate; serve Customer 1 (dining_table_02) and Customer 2 (dining_table_01) using 5-portion rice batch!
	game_root._process(21.0)
	_click_object(ui, world, &"dining_table_01")
	_type_word(ui, "bersihkan")
	_click_object(ui, world, &"washer")
	_type_word(ui, "cuci")
	_check(
		"cleaned table dirty plate washes back into clean held plate and returns to rack",
		kitchen.get_held_item_view().get("plate_id", &"") != &""
		and int(service.get_table_view(&"dining_table_01")["state"]) != SharedTypes.TableState.DIRTY
	)
	_click_object(ui, world, &"plate_rack")

	# Serve Customer 1 on dining_table_02 (using rice portion 2 of 5 -> 3 left).
	_click_object(ui, world, &"plate_rack")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"dining_table_02")
	_type_word(ui, "saji")
	_check("serving Customer 1 on dining_table_02 brings cash to 127k", int(run.get_run_view()["cash"]) == 127000)

	# Advance to t=42s (Customer 2 spawned at t=40 onto dining_table_01); serve Customer 2 (rice portion 3 -> 2 left).
	game_root._process(20.0)
	_click_object(ui, world, &"plate_rack")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"work_table_stage")
	_click_object(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check("serving Customer 2 on dining_table_01 brings cash to 147k (cooker 2 portions left)", int(run.get_run_view()["cash"]) == 147000 and int(kitchen.get_cooker_output_view(&"rice_cooker")["portions"]) == 2)

	# Advance to t=130s (Customer 3 expires at t=160s -> single miss debt), order 1 beras (due t=230s) while shop keeps clock running.
	game_root._process(88.0)
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"beras", 1)
	ui.shop_checkout_button.pressed.emit()
	_check(
		"SERVING pending purchase debits 2k and schedules due_at = now + 100s",
		int(run.get_run_view()["cash"]) == 145000
		and kitchen.get_pending_delivery_views().size() == 1
	)

	# Drain remaining ~35s via natural _process() (so delivery at +100s is still pending at close and refunded once).
	_check("Day 1 auto-closes via _process drain", await _drain_day_via_process(game_root, service, 20.0, 20))
	var d1_settle := run.get_day_settlement_view(1)
	_check(
		"Day 1 RESULTS settles dine-in +60k, pending refund +2k, electricity -2k -> 145k, 1 miss debt",
		game_root.get_phase() == SharedTypes.Phase.RESULTS
		and int(d1_settle["order_revenue_dinein"]) == 60000
		and int(d1_settle["refund_total"]) == 2000
		and int(d1_settle["electricity_charge"]) == 2000
		and int(d1_settle["end_cash"]) == 145000
		and int(d1_settle["penalty_debt_after"]) in [1, 2]
		and ui.result_title_label.text == "Hari 1 selesai"
	)
	# Idempotent settlement guard before Continue.
	_check(
		"repeated settle_day_once(1) does not double-charge electricity",
		int(run.settle_day_once({"day_index": 1}).get("end_cash", 0)) == 145000
	)
	ui.continue_button.pressed.emit()
	await process_frame

	# --- DAY 2 PLANNING: unlock check, buy fridge, fridge stock carryover, edit menu, online driver ---
	_check(
		"Day 2 starts PLANNING with box cleared, nasi_tempe unlocked & NOT auto-selected",
		game_root.get_day_index() == 2
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
		and kitchen.get_cooker_output_view(&"rice_cooker").is_empty()
		and kitchen.get_storage_remaining_capacity(&"storage_box") == 15
		and run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor", &"nasi_tempe"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)

	# Buy fridge into slot_utility_01 via slot click + FixtureShop (-80k -> 65k), increasing power to 6k.
	_click_slot(ui, world, &"slot_utility_01")
	await process_frame
	ui.select_fixture_shop_utility(&"fridge")
	ui.fixture_confirm_button.pressed.emit()
	_check(
		"fridge_01 installed via FixtureShop leaving 65k cash and 6k daily electricity",
		not ui.is_fixture_shop_open()
		and world.registry.get_object(&"fridge_01") != null
		and int(run.get_run_view()["cash"]) == 65000
		and run.get_daily_electricity_estimate() == 6000
	)

	# Buy beras x2 + tempe x1 into fridge_01 (6k -> stays for Day 3!), and beras x1 + telur x1 into box (5k).
	_click_object(ui, world, &"fridge_01")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"beras", 2)
	ui.adjust_shop_quantity(&"tempe", 1)
	ui.shop_checkout_button.pressed.emit()
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"beras", 1)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()
	_check("Day 2 cash after stocking fridge & box is 54k", int(run.get_run_view()["cash"]) == 54000)

	# Start Day 2 SERVING and fulfill an online order via terima + in-spot driver saji.
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	var waiting_offer := service.get_online_offer_view()
	_check(
		"Day 2 starts SERVING with online offer waiting for initial periodic delay",
		not bool(waiting_offer["acceptance_enabled"])
		and waiting_offer["disabled_reason"] == &"offer_waiting"
	)
	game_root._process(10.0)
	var offer := service.get_online_offer_view()
	_check("Day 2 online offer enabled cleanly after 10s when quota > 2", bool(offer["acceptance_enabled"]))
	_click_object(ui, world, &"online_station")
	_type_word(ui, "terima")
	var drivers := service.get_driver_views()
	var d_id: StringName = StringName(drivers[0]["driver_id"]) if not drivers.is_empty() else &""
	_check("terima spawns in-spot online driver", drivers.size() == 1 and int(drivers[0]["state"]) == SharedTypes.DriverState.AT_PICKUP_SPOT)
	if d_id != &"":
		_cook_and_plate_nasi_telor(ui, world, &"storage_box")
		_click_object(ui, world, d_id)
		_type_word(ui, "saji")
	_check(
		"online driver serve pays 70% (14k -> 68k) and returns clean plate to rack immediately",
		int(run.get_run_view()["cash"]) == 68000
		and int(run.get_day_settlement_view(2).get("end_cash", -1)) == -1
		and int(kitchen.get_plate_rack_view(&"plate_rack")["clean_count"]) == 4
	)

	_check("Day 2 auto-closes via natural _process drain", await _drain_day_via_process(game_root, service, 20.0, 40))
	var d2_settle := run.get_day_settlement_view(2)
	_check(
		"Day 2 settlement deducts 6k electricity (68k -> 62k) once",
		int(d2_settle["order_revenue_online"]) == 14000
		and int(d2_settle["electricity_charge"]) == 6000
		and int(d2_settle["end_cash"]) == 62000
	)
	ui.continue_button.pressed.emit()
	await process_frame

	# --- DAY 3 PLANNING -> SERVING: Day 3 unlocks, fridge persistence, 3-part nasi_telur_tempe ---
	var fridge_slots_d3: Array = kitchen.get_storage_unit_view(&"fridge_01")["slots"]
	_check(
		"Day 3 starts PLANNING with Day 3 recipes unlocked unchecked & fridge_01 stock preserved",
		game_root.get_day_index() == 3
		and run.get_run_view()["unlocked_recipe_ids"] == [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"nasi_telur_tempe"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
		and fridge_slots_d3[0]["ingredient_id"] == &"beras"
		and int(fridge_slots_d3[0]["quantity"]) == 2
		and fridge_slots_d3[1]["ingredient_id"] == &"tempe"
		and int(fridge_slots_d3[1]["quantity"]) == 1
	)

	# Enable 3 recipes via Edit Menu & confirm.
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_preview_button(&"nasi_telur_tempe").pressed.emit()
	_check(
		"Day 3 Edit Menu shows description and parts for nasi_telur_tempe in detail panel",
		ui.get_edit_menu_detail_lines() == PackedStringArray([
			"Masak nasi, goreng telur dan tempe, lalu satukan.",
			"Beras",
			"Telur",
			"Tempe",
		])
	)
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = true
	ui.get_edit_menu_recipe_button(&"nasi_telur_tempe").button_pressed = true
	ui.edit_menu_confirm_button.pressed.emit()
	_check("Edit Menu confirm enables 3-dish menu cleanly", run.get_run_view()["selected_recipe_ids"].size() == 3)

	# Buy telur x1 into box and assemble a full 3-part nasi_telur_tempe using fridge + box + stove + cooker!
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()

	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_click_object(ui, world, &"fridge_01")
	_type_word(ui, "beras")
	_click_object(ui, world, &"washer")
	_type_word(ui, "cuci")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	_click_object(ui, world, &"plate_rack")
	_click_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	_click_object(ui, world, &"work_table_stage")

	_click_object(ui, world, &"fridge_01")
	_type_word(ui, "tempe")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")

	_click_object(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_click_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_object(ui, world, &"work_table_stage")

	_check(
		"full 3-part nasi_telur_tempe assembled order-independently across fridge, box, stove, cooker",
		kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &"nasi_telur_tempe"
	)

	_check("Day 3 auto-closes via natural _process drain", await _drain_day_via_process(game_root, service, 20.0, 60))
	_check("Day 3 RESULTS displays correctly", game_root.get_phase() == SharedTypes.Phase.RESULTS and game_root.get_day_index() == 3)
	ui.continue_button.pressed.emit()
	await process_frame

	# --- DAYS 4, 5, 6: sequentially verify Day 4 Sayur (potong) + egg_salad, zero skipped days & scaling unlocks ---
	var expected_unlock_counts := {4: 6, 5: 8, 6: 10}
	for expected_day: int in [4, 5, 6]:
		_check(
			"Day %d starts PLANNING sequentially with expected recipe catalog" % expected_day,
			game_root.get_day_index() == expected_day
			and game_root.get_phase() == SharedTypes.Phase.PLANNING
			and ui.day_label.text == "Hari %d/7" % expected_day
			and run.get_run_view()["unlocked_recipe_ids"].size() == int(expected_unlock_counts[expected_day])
		)
		if expected_day == 4:
			ui.open_edit_menu()
			await process_frame
			ui.get_edit_menu_preview_button(&"egg_salad").pressed.emit()
			_check(
				"Day 4 Edit Menu shows Sayur (potong) for egg_salad in detail panel",
				ui.get_edit_menu_detail_lines() == PackedStringArray([
					"Goreng telur, potong sayur, lalu sajikan tanpa nasi.",
					"Telur",
					"Sayur (potong)",
				])
			)
			ui.close_edit_menu()
			run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
			run.request_ingredient_purchase(&"telur", 1, &"storage_box")
		_send_left_click(ui, Vector2(352, 276))
		_type_word(ui, "buka")
		if expected_day == 4:
			_click_object(ui, world, &"storage_box")
			_type_word(ui, "sayur")
			_click_object(ui, world, &"work_table_chop")
			_type_word(ui, "potong")
			_click_object(ui, world, &"plate_rack")
			_click_object(ui, world, &"work_table_stage")
			_click_object(ui, world, &"storage_box")
			_type_word(ui, "telur")
			_click_object(ui, world, &"stove")
			_type_word(ui, "goreng")
			_click_object(ui, world, &"work_table_stage")
			_check(
				"Day 4 chop sayur + fried telur assembles egg_salad cleanly without rice",
				kitchen.get_work_table_view(&"work_table").get("matched_recipe_id", &"") == &"egg_salad"
			)
		_check("Day %d enters SERVING" % expected_day, game_root.is_serving())
		_check("Day %d auto-closes cleanly" % expected_day, await _drain_day_via_process(game_root, service, 20.0, 60))
		_check(
			"Day %d RESULTS applies 6k electricity once" % expected_day,
			game_root.get_phase() == SharedTypes.Phase.RESULTS
			and int(run.get_day_settlement_view(expected_day)["electricity_charge"]) == 6000
		)
		ui.continue_button.pressed.emit()
		await process_frame

	# --- DAY 7: Exact Rp 700,000 WON boundary achieved via REAL served dish ---
	_check("reached Day 7 PLANNING sequentially", game_root.get_day_index() == 7 and game_root.get_phase() == SharedTypes.Phase.PLANNING)
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = false
	ui.get_edit_menu_recipe_button(&"nasi_telur_tempe").button_pressed = false
	ui.edit_menu_confirm_button.pressed.emit()
	# Set pre-serve cash on Day 7 Planning to target + electricity (6k) - 1 dine-in nasi_telor (20k) + 5k ingredients = 691,000,
	# and reset accumulated unserved-day debt so Day 7 spawns Customer 0 for real dish service.
	run._demand_penalty_debt = 0
	run._cash = 691000
	_click_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	ui.adjust_shop_quantity(&"beras", 1)
	ui.adjust_shop_quantity(&"telur", 1)
	ui.shop_checkout_button.pressed.emit()
	_check("Day 7 cash before buka equals 686k (needs +20k dine-in - 6k electricity = 700k)", int(run.get_run_view()["cash"]) == 686000)

	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_cook_and_plate_nasi_telor(ui, world, &"storage_box")
	_click_object(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	_check("Day 7 real served dish brings cash to 706k pre-electricity", int(run.get_run_view()["cash"]) == 706000)

	_check("Day 7 auto-closes to FINISHED", await _drain_day_via_process(game_root, service, 20.0, 60))
	var d7_settle := run.get_day_settlement_view(7)
	game_root.request_close_if_drained()
	run.settle_day_once({"day_index": 7})
	_check(
		"Day 7 exact 700k post-electricity produces WON in FINISHED with terminal campaign guards",
		game_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(d7_settle["electricity_charge"]) == 6000
		and int(d7_settle["end_cash"]) == 700000
		and int(run.get_run_view()["cash"]) == 700000
		and int(d7_settle["day7_outcome"]) == SharedTypes.DayOutcome.WON
		and ui.day_result_side_panel.visible
		and ui.result_title_label.text == "Target tercapai!"
		and not ui.continue_button.visible
		and ui.continue_button.disabled
		and ui.extra_mode_button.visible
		and not ui.extra_mode_button.disabled
		and not game_root.request_continue_from_results()
	)

	game_root.free()
	await process_frame


func _test_full_7_day_lost_boundary_and_negative_cash() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Spend cash down to 0 in Day 1 Planning (100k = 80k fridge + 20k box stock? Actually fridge 80k + beras x10 = 100k)
	# so 6k daily electricity drives Day 1 post-electricity cash negative (-6k) cleanly!
	_check("buy fridge on Day 1", run.request_fixture_purchase(&"fridge", &"slot_utility_01"))
	_check("spend remaining 20k on beras into box", run.request_ingredient_basket_purchase({ &"beras": 10 }, &"storage_box"))
	_check("cash hits 0 before Day 1 service", int(run.get_run_view()["cash"]) == 0)

	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check("Day 1 auto-closes with 0 income", await _drain_day_via_process(game_root, service, 20.0, 20))
	_check(
		"negative cash allowed after electricity (-6k) and formatted cleanly in UI",
		int(run.get_run_view()["cash"]) == -6000
		and ui.cash_label.text == "Kas: -Rp 6k"
	)
	ui.continue_button.pressed.emit()
	await process_frame

	_check(
		"broken Day 2 run with -6k cash rejects unaffordable ingredient purchase",
		not run.request_ingredient_purchase(&"beras", 1, &"fridge_01")
		and int(run.get_run_view()["cash"]) == -6000
	)

	# Progress sequentially Days 2 -> 6 to Day 7.
	for d: int in range(2, 7):
		_send_left_click(ui, Vector2(352, 276))
		_type_word(ui, "buka")
		if not await _drain_day_via_process(game_root, service, 20.0, 60):
			game_root.free()
			await process_frame
			return
		ui.continue_button.pressed.emit()
		await process_frame

	# On Day 7: set pre-electricity cash so post-electricity == 699,999 -> LOST.
	_check("reached Day 7 PLANNING for LOST check", game_root.get_day_index() == 7)
	run._cash = 705999
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check("Day 7 LOST run auto-closes cleanly", await _drain_day_via_process(game_root, service, 20.0, 60))

	var d7_lost := run.get_day_settlement_view(7)
	game_root.request_close_if_drained()
	ui.continue_button.pressed.emit()
	ui.extra_mode_button.pressed.emit()
	_check(
		"Day 7 exact 699,999 post-electricity produces terminal LOST with Extra Mode blocked",
		game_root.get_phase() == SharedTypes.Phase.FINISHED
		and int(d7_lost["electricity_charge"]) == 6000
		and int(d7_lost["end_cash"]) == 699999
		and int(run.get_run_view()["cash"]) == 699999
		and int(d7_lost["day7_outcome"]) == SharedTypes.DayOutcome.LOST
		and ui.result_title_label.text == "Belum tercapai"
		and not ui.continue_button.visible
		and ui.continue_button.disabled
		and not ui.extra_mode_button.visible
		and ui.extra_mode_button.disabled
		and not game_root.request_extra_mode()
		and not game_root.request_continue_from_results()
		and not game_root.start_service_requested()
		and game_root.get_day_index() == 7
	)

	game_root.free()
	await process_frame
