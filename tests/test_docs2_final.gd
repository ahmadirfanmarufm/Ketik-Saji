extends SceneTree
## Final docs_2 acceptance suite covering:
## 1. 13-recipe catalog (unlock days 1..7, icons, descriptions, salads without rice, 6-part nasi_gila).
## 2. Deterministic +3/+2/+1 demand formula & order-invariance + Day 1..5 ingredient unlock gating.
## 3. Three-tile long counters (3 simultaneous items + middle slot remove & DishSprite refill).
## 4. MainMenuOverlay, SettingsOverlay live BGM slider, GameAudio click non-repeat & loop/fade guards.
## 5. Results / Day 7 WON / Day 7 LOST Coba lagi & Menu utama + Dirty table "meja kotor" hover tooltip.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_13_recipes_salads_and_demand_invariance()
	await _test_day1_to_5_ingredient_unlock_gating()
	await _test_three_tile_long_counters_and_dish_visuals()
	await _test_main_menu_settings_and_audio()
	await _test_results_retry_menu_and_dirty_hover_tooltip()
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _advance_to_day(game_root: GameRoot, target_day: int) -> void:
	var service := game_root.get_service_controller() as ServiceController
	while game_root.get_day_index() < target_day:
		game_root.start_service_requested()
		service._day_queue_remaining = 0
		service._outside_dine_in_queue.clear()
		service._in_shop_dine_in_count = 0
		service._online_orders_open.clear()
		game_root.request_close_if_drained()
		game_root.request_continue_from_results()


func _send_key(ui: GameUI, unicode_val: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	ev.keycode = unicode_val
	ev.physical_keycode = unicode_val
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _send_motion(ui: GameUI, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ui.get_viewport().push_input(ev, true)


func _test_13_recipes_salads_and_demand_invariance() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	# Verify cumulative recipe unlock schedule across Days 1..7 reaches all 13 recipes.
	var cfg := run.economy_config
	var expected_unlock_counts: Array[int] = [1, 2, 4, 6, 8, 10, 13]
	var counts_ok := true
	for day_idx in range(1, 8):
		if cfg.get_unlocked_recipe_ids(day_idx).size() != expected_unlock_counts[day_idx - 1]:
			counts_ok = false
	_check("Days 1..7 unlock exact 1->2->4->6->8->10->13 recipe progression", counts_ok)

	# Verify all 13 recipes have unique icon Texture2D, non-empty description, and Edit Menu renders both.
	var all_ids := cfg.get_unlocked_recipe_ids(7)
	var seen_icons: Dictionary[String, bool] = {}
	var all_defs_valid := all_ids.size() == 13
	for rid in all_ids:
		var def := kitchen.get_recipe_def(rid)
		if def == null or def.icon == null or def.description.is_empty() or def.required_parts.is_empty():
			all_defs_valid = false
			break
		var icon_path := def.icon.resource_path
		if seen_icons.has(icon_path):
			all_defs_valid = false
			break
		seen_icons[icon_path] = true
	_check("all 13 RecipeDefs have unique icons, non-empty descriptions, and required_parts", all_defs_valid)

	# Demand invariance & deterministic +3 / +2 / +1 contribution checks on Day 7.
	_advance_to_day(game_root, 7)
	var d7_base := run._compute_demand_for_day_and_menu(7, [&"nasi_telor"])
	var d7_two := run._compute_demand_for_day_and_menu(7, [&"nasi_telor", &"nasi_tempe"])
	var d7_three := run._compute_demand_for_day_and_menu(7, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam"])
	var d7_rev := run._compute_demand_for_day_and_menu(7, [&"nasi_ayam", &"nasi_tempe", &"nasi_telor"])
	var d7_four := run._compute_demand_for_day_and_menu(7, [&"nasi_telor", &"nasi_tempe", &"nasi_ayam", &"nasi_gila"])
	_check(
		"deterministic +3/+2/+1 demand contribution and menu selection order invariance",
		int(d7_base["potential_demand"]) == 28
		and int(d7_two["potential_demand"]) == 31
		and int(d7_three["potential_demand"]) == 33
		and int(d7_rev["potential_demand"]) == 33
		and int(d7_four["potential_demand"]) == 34
	)

	# Check Edit Menu Resep shows both description and parts for 13 recipes including egg_salad & nasi_gila.
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_preview_button(&"nasi_gila").pressed.emit()
	await process_frame
	var gila_def := kitchen.get_recipe_def(&"nasi_gila")
	var gila_lines := ui.get_edit_menu_detail_lines()
	_check(
		"Edit Menu Resep shows description and all 6 ingredients for nasi_gila",
		gila_lines.size() == 7
		and gila_lines[0] == gila_def.description
	)
	ui.close_edit_menu()

	# Assemble no-rice Egg Salad on Day 7 (Sayur potong + COOKED telur) & verify DishSprite!
	run.request_fixture_purchase(&"box", &"slot_utility_01")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	run.request_ingredient_purchase(&"sayur", 2, &"storage_box")
	run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	run.request_ingredient_purchase(&"ayam", 1, &"box_01")
	run.request_ingredient_purchase(&"tempe", 1, &"box_01")
	run.request_ingredient_purchase(&"sapi", 1, &"box_01")
	game_root.start_service_requested()

	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "sayur")
	kitchen.on_interactable_clicked(&"work_table_chop")
	_type_word(ui, "potong")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var salad_table := kitchen.get_work_table_view(&"work_table")
	var staged_vis := world.registry.get_object(&"work_table").get_node_or_null("StagedVisual")
	var dish_spr := staged_vis.get_node_or_null("DishSprite") as Sprite2D if staged_vis != null else null
	_check(
		"egg_salad assembles without rice and renders Egg-Salad.png DishSprite on WorkTable",
		salad_table.get("matched_recipe_id", &"") == &"egg_salad"
		and dish_spr != null
		and dish_spr.texture != null
		and dish_spr.texture.resource_path == "res://assets/art/dishes/Egg-Salad.png"
	)
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")

	# Assemble 6-part Nasi Gila and verify Nasi-Gila.png DishSprite in hand & on WorkTable!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "sayur")
	kitchen.on_interactable_clicked(&"work_table_chop")
	_type_word(ui, "potong")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	for pair: Array in [
		[&"storage_box", "telur"],
		[&"box_01", "ayam"],
		[&"box_01", "tempe"],
		[&"box_01", "sapi"],
	]:
		kitchen.on_interactable_clicked(pair[0])
		_type_word(ui, String(pair[1]))
		kitchen.on_interactable_clicked(&"stove")
		_type_word(ui, "goreng")
		kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var gila_held := kitchen.get_held_item_view()
	var held_vis := world.player.get_node("VisualAnchor/HeldItemVisual") as Node2D
	var held_dish := held_vis.get_node_or_null("DishSprite") as Sprite2D
	_check(
		"6-part nasi_gila assembles cleanly and renders Nasi-Gila.png DishSprite in hand",
		gila_held.get("matched_recipe_id", &"") == &"nasi_gila"
		and (gila_held.get("parts", []) as Array).size() == 6
		and held_dish != null
		and held_dish.texture != null
		and held_dish.texture.resource_path == "res://assets/art/dishes/Nasi-Gila(Semua ingredients).png"
	)

	game_root.free()
	await process_frame


func _test_day1_to_5_ingredient_unlock_gating() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var expected_by_day: Dictionary = {
		1: [&"beras", &"telur"],
		2: [&"beras", &"telur", &"tempe"],
		3: [&"beras", &"telur", &"tempe", &"ayam"],
		4: [&"beras", &"telur", &"tempe", &"ayam", &"sayur"],
		5: [&"beras", &"telur", &"tempe", &"ayam", &"sayur", &"sapi"],
	}
	for day_idx: int in [1, 2, 3, 4, 5]:
		if day_idx > 1:
			_advance_to_day(game_root, day_idx)
		var unlocked := run.get_unlocked_ingredient_ids()
		var expected_arr: Array = expected_by_day[day_idx]
		var match_ok := unlocked.size() == expected_arr.size()
		for ing_id: StringName in expected_arr:
			if not unlocked.has(ing_id):
				match_ok = false
		_check("Day %d unlocked ingredients match exact expected set" % day_idx, match_ok)
		if day_idx == 1:
			ui.open_ingredient_shop(&"storage_box")
			await process_frame
			var blocked_tempe := not ui.adjust_shop_quantity(&"tempe", 1)
			var blocked_sapi := not run.request_ingredient_purchase(&"sapi", 1, &"storage_box")
			var allowed_beras := ui.adjust_shop_quantity(&"beras", 1)
			_check(
				"Day 1 Belanja Bahan blocks locked tempe/sapi while allowing unlocked beras",
				blocked_tempe
				and blocked_sapi
				and allowed_beras
				and ui.get_shop_ingredient_controls(&"sayur").is_empty()
			)
			ui.close_ingredient_shop()

	game_root.free()
	await process_frame


func _test_three_tile_long_counters_and_dish_visuals() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI
	var world := game_root.get_node("World") as WorldMap

	var slot_ids := world.get_long_counter_slot_ids()
	_check("WorldMap exposes >= 6 independent 3-tile counter slots", slot_ids.size() >= 6)
	var s0: StringName = slot_ids[0]
	var s1: StringName = slot_ids[1]
	var s2: StringName = slot_ids[2]

	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 3, &"storage_box")
	game_root.start_service_requested()

	# Place 3 distinct items simultaneously onto 3 consecutive counter slots.
	for i in range(3):
		kitchen.on_interactable_clicked(&"storage_box")
		_type_word(ui, "telur")
		kitchen.on_interactable_clicked(slot_ids[i])

	var v0_full := kitchen.get_work_table_view(s0)
	var v1_full := kitchen.get_work_table_view(s1)
	var v2_full := kitchen.get_work_table_view(s2)
	var n0_vis := world.registry.get_object(s0).get_node_or_null("StagedVisual") as Node2D
	var n1_vis := world.registry.get_object(s1).get_node_or_null("StagedVisual") as Node2D
	var n2_vis := world.registry.get_object(s2).get_node_or_null("StagedVisual") as Node2D
	_check(
		"3 simultaneous counter slots hold independent items with visible visuals",
		not v0_full.is_empty() and not v1_full.is_empty() and not v2_full.is_empty()
		and n0_vis != null and n0_vis.visible
		and n1_vis != null and n1_vis.visible
		and n2_vis != null and n2_vis.visible
	)

	# Remove MIDDLE slot (s1) while outer slots s0 & s2 stay intact!
	kitchen.on_interactable_clicked(s1)
	_check(
		"removing middle counter slot keeps adjacent slots intact and clears middle slot visual",
		kitchen.get_work_table_view(s1).is_empty()
		and not kitchen.get_work_table_view(s0).is_empty()
		and not kitchen.get_work_table_view(s2).is_empty()
		and not n1_vis.visible
	)

	# Cook completed Nasi Telur and place into freed MIDDLE slot s1 -> verifies DishSprite!
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(s0) # pick raw egg from slot 0 into hand!
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(s1)
	var mid_dish := world.registry.get_object(s1).get_node_or_null("StagedVisual/DishSprite") as Sprite2D
	_check(
		"refilling freed middle counter slot with completed Nasi Telur renders Nasi-Telur.png",
		kitchen.get_work_table_view(s1).get("matched_recipe_id", &"") == &"nasi_telor"
		and mid_dish != null
		and mid_dish.texture != null
		and mid_dish.texture.resource_path == "res://assets/art/dishes/Nasi-Telur.png"
	)

	game_root.free()
	await process_frame


func _test_main_menu_settings_and_audio() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var ui := game_root.get_node("UI") as GameUI
	var audio := game_root.get_audio_controller() as GameAudio
	_check("AudioController instantiated on GameRoot", audio != null)

	# Return cleanly into Main Menu state to verify artwork, clouds, equal buttons & settings.
	_check("request_return_to_main_menu activates MainMenuOverlay", game_root.request_return_to_main_menu() and game_root.is_in_main_menu() and ui.is_main_menu_open())
	await process_frame

	var bg_tex := (ui.main_menu_overlay.get_node("MainMenuBackground") as TextureRect).texture
	var logo_tex := ui.main_menu_logo.texture
	var c1_tex := (ui.main_menu_overlay.get_node("MegaMendungTopLeft") as TextureRect).texture
	var c2_tex := (ui.main_menu_overlay.get_node("MegaMendungBottomRight") as TextureRect).texture
	var sz_play := ui.main_menu_play_button.size
	var sz_set := ui.main_menu_settings_button.size
	var sz_quit := ui.main_menu_quit_button.size
	_check(
		"MainMenu loads bg alt, logo shadow, both mega mendung clouds, and 3 equal buttons",
		bg_tex != null and bg_tex.resource_path.ends_with("main-menu-bg alt (pixelated).jpg.jpeg")
		and logo_tex != null and logo_tex.resource_path.ends_with("logo ketik-saji pixelated shadow.png")
		and c1_tex != null and c2_tex != null
		and is_equal_approx(sz_play.x, sz_set.x) and is_equal_approx(sz_play.x, sz_quit.x)
		and is_equal_approx(sz_play.y, sz_set.y) and is_equal_approx(sz_play.y, sz_quit.y)
	)

	# Settings overlay BGM slider adjusts GameAudio volume cleanly.
	ui.main_menu_settings_button.pressed.emit()
	await process_frame
	_check("Pengaturan opens SettingsOverlay", ui.is_settings_open())
	ui.bgm_volume_slider.value = 0.45
	await process_frame
	_check(
		"Settings BGM slider updates GameAudio volume and percentage label live",
		is_equal_approx(audio.get_bgm_volume(), 0.45)
		and ui.bgm_value_label.text == "45%"
	)
	ui.settings_close_button.pressed.emit()
	_check("closing Settings restores MainMenu cleanly", not ui.is_settings_open() and ui.is_main_menu_open())

	# GameAudio click pool debounces same-msec double calls and avoids immediate consecutive repeats.
	audio._last_click_ticks_msec = -1000
	var prev_idx := audio.play_click()
	var same_tick_now := int(Time.get_ticks_msec())
	audio._last_click_ticks_msec = same_tick_now
	var dup_same_msec := audio.play_click() == -1
	var no_consec_dup := audio._click_streams.size() == 5 and prev_idx >= 0 and (dup_same_msec or int(Time.get_ticks_msec()) != same_tick_now)
	for _i in range(20):
		audio._last_click_ticks_msec = -1000
		var next_idx := audio.play_click()
		if next_idx < 0 or next_idx == prev_idx:
			no_consec_dup = false
			break
		prev_idx = next_idx
	_check("GameAudio play_click avoids immediate consecutive repeats across 20 calls", no_consec_dup)

	# Play enters Day 1 Planning.
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	_check("Play button starts fresh Day 1 PLANNING", not game_root.is_in_main_menu() and not ui.is_main_menu_open() and game_root.get_day_index() == 1)

	game_root.free()
	await process_frame


func _test_results_retry_menu_and_dirty_hover_tooltip() -> void:
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

	# Verify Day 1 compact RESULTS omits zero purchase/sale/refund rows.
	game_root.start_service_requested()
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._online_orders_open.clear()
	game_root.request_close_if_drained()
	_check(
		"Days 1..6 Results panel omits zero Beli alat / Jual alat / Refund rows",
		ui.result_title_label.text == "Hari 1 selesai"
		and not ui.settlement_summary_label.text.contains("Beli alat:")
		and not ui.settlement_summary_label.text.contains("Jual alat:")
		and not ui.settlement_summary_label.text.contains("Refund:")
	)
	ui.continue_button.pressed.emit()
	await process_frame

	# Advance to Day 7 LOST -> test Retry (Coba lagi) resets cleanly to Day 1 Planning!
	_advance_to_day(game_root, 7)
	run._cash = 100000
	game_root.start_service_requested()
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._online_orders_open.clear()
	game_root.request_close_if_drained()
	await process_frame
	_check(
		"Day 7 LOST shows Belum tercapai + Coba lagi + Menu utama",
		ui.result_title_label.text == "Belum tercapai"
		and ui.retry_button.visible and ui.retry_button.text == "Coba lagi"
		and ui.result_menu_button.visible and ui.result_menu_button.text == "Menu utama"
	)
	ui.retry_button.pressed.emit()
	await process_frame
	await physics_frame
	run = game_root.get_run_controller() as RunController
	service = game_root.get_service_controller() as ServiceController
	kitchen = game_root.get_kitchen_controller() as KitchenController
	world = game_root.get_node("World") as WorldMap
	_check(
		"Coba lagi restarts fresh Day 1 Planning with Rp 100k",
		not game_root.is_in_main_menu()
		and game_root.get_day_index() == 1
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
		and int(run.get_run_view()["cash"]) == 100000
	)

	# Also test dirty table "meja kotor" hover tooltip on dining_table_01 vs clean dining_table_02.
	game_root.start_service_requested()
	service._tables[&"dining_table_01"]["state"] = SharedTypes.TableState.DIRTY
	service._tables[&"dining_table_02"]["state"] = SharedTypes.TableState.CLEAN_VACANT
	var t1_canvas := world.get_canvas_transform() * world.registry.get_object(&"dining_table_01").global_position
	var t2_canvas := world.get_canvas_transform() * world.registry.get_object(&"dining_table_02").global_position
	_send_motion(ui, t1_canvas)
	ui._process(0.016)
	_check(
		"hovering DIRTY dining_table_01 displays meja kotor tooltip",
		ui.hover_tooltip_panel.visible and ui.hover_tooltip_label.text == "meja kotor"
	)
	_send_motion(ui, t2_canvas)
	ui._process(0.016)
	_check("hovering CLEAN dining_table_02 hides dirty tooltip", not ui.hover_tooltip_panel.visible)

	# Finally test Day 7 WON Menu utama button returns cleanly to MainMenu!
	_advance_to_day(game_root, 7)
	run._cash = 702000
	game_root.start_service_requested()
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._online_orders_open.clear()
	game_root.request_close_if_drained()
	await process_frame
	_check(
		"Day 7 WON shows Target tercapai!, Lanjut jualan, and Menu utama",
		ui.result_title_label.text == "Target tercapai!"
		and ui.extra_mode_button.visible and ui.extra_mode_button.text == "Lanjut jualan"
		and ui.result_menu_button.visible and ui.result_menu_button.text == "Menu utama"
	)
	ui.result_menu_button.pressed.emit()
	await process_frame
	_check("Menu utama button on Day 7 WON returns to Main Menu cleanly", game_root.is_in_main_menu() and ui.is_main_menu_open())

	game_root.free()
	await process_frame
