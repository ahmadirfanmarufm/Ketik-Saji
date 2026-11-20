extends SceneTree
## Headless integration tests for M5-E — Edit Menu & Feedback Simplification:
## - Split Edit Menu popup (narrowed list + right RecipeDetailPanel with 0 gap)
## - Checkmark toggles & colon price formatting (`Nasi Telor: Rp 20k`)
## - Preview independence, no-selection/deselection state, locked/unlock behavior
## - Recipe ingredient display (implicit cooking, `Sayur (potong)` alternate prep)
## - Feedback simplification (silent shake on `invalid_key`, silent wall click,
##   preserved `wrong_order`, `order_expired`, rejections, and outcomes)
## - Modal click/key blocking, dialogue restoration, Pause/Resume, and 640x360 + 480x270 fit

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_edit_menu_detail_panel_and_unlocks()
	await _test_feedback_simplification_and_preservation()
	await _test_edit_menu_modal_pause_dialogue_and_responsive()
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


func _advance_to_day(
	game_root: GameRoot,
	service: ServiceController,
	target_day: int
) -> bool:
	var max_steps := maxi(1, (target_day - game_root.get_day_index() + 2) * 4)
	var steps := 0
	while game_root.get_day_index() < target_day:
		steps += 1
		if steps > max_steps:
			var q_view: Dictionary = service.get_customer_queue_view()
			_check(
				"day advance stalled targeting day %d (day=%d, phase=%d, queue=%s)" % [
					target_day,
					game_root.get_day_index(),
					int(game_root.get_phase()),
					str(q_view),
				],
				false
			)
			return false
		var before_day := game_root.get_day_index()
		var before_phase := game_root.get_phase()
		var transitioned := false
		if before_phase == SharedTypes.Phase.PLANNING:
			transitioned = game_root.start_service_requested()
		elif before_phase == SharedTypes.Phase.SERVING:
			_force_empty_service(service)
			game_root.request_close_if_drained()
			transitioned = game_root.get_phase() != SharedTypes.Phase.SERVING
		elif before_phase == SharedTypes.Phase.RESULTS:
			transitioned = game_root.request_continue_from_results()
		await process_frame
		var progressed := (
			game_root.get_day_index() > before_day
			or game_root.get_phase() != before_phase
		)
		if not transitioned or not progressed:
			var q_view: Dictionary = service.get_customer_queue_view()
			_check(
				"day advance transition failed (target=%d, day=%d, phase=%d->%d, queue=%s)" % [
					target_day,
					game_root.get_day_index(),
					int(before_phase),
					int(game_root.get_phase()),
					str(q_view),
				],
				false
			)
			return false
	return game_root.get_day_index() >= target_day


func _test_edit_menu_detail_panel_and_unlocks() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Day 1: only nasi_telor unlocked & checked; detail panel sits to the right in no-selection state.
	ui.edit_menu_button.pressed.emit()
	await process_frame
	var p_rect_day1 := ui.edit_menu_popup.get_global_rect()
	var detail_rect := ui.recipe_detail_panel.get_global_rect()
	_check(
		"EditMenu opens in PLANNING with right-side Resep panel and no-selection state",
		ui.is_edit_menu_open()
		and ui.recipe_detail_panel.get_parent() == ui.edit_menu_overlay
		and detail_rect.position.x >= p_rect_day1.end.x + 4.0
		and is_equal_approx(detail_rect.position.y, p_rect_day1.position.y)
		and ui.get_previewed_edit_menu_recipe_id() == &""
		and ui.recipe_detail_title_label.text == "Resep"
		and ui.get_edit_menu_recipe_button(&"nasi_telor").button_pressed
		and ui.get_edit_menu_preview_button(&"nasi_telor").text == "Nasi Telur: Rp 20k"
		and ui.get_edit_menu_recipe_button(&"nasi_ayam") == null
		and not ui.preview_edit_menu_recipe(&"nasi_ayam")
	)

	# Clicking Nasi Telur preview shows description + implicit cooked parts without changing enabled state.
	ui.get_edit_menu_preview_button(&"nasi_telor").pressed.emit()
	await process_frame
	var telor_lines := ui.get_edit_menu_detail_lines()
	_check(
		"previewing Nasi Telur displays dish title, description, and implicit cooked ingredients",
		ui.get_previewed_edit_menu_recipe_id() == &"nasi_telor"
		and ui.recipe_detail_title_label.text == "Nasi Telur"
		and telor_lines == PackedStringArray([
			"Cuci dan masak beras, goreng telur, lalu sajikan bersama nasi.",
			"Beras",
			"Telur",
		])
		and ui.get_pending_menu_selection() == [&"nasi_telor"]
	)

	# Re-clicking already previewed Nasi Telur deselects back to no-selection state.
	ui.get_edit_menu_preview_button(&"nasi_telor").pressed.emit()
	await process_frame
	_check(
		"clicking already-previewed dish deselects detail panel cleanly",
		ui.get_previewed_edit_menu_recipe_id() == &""
		and ui.recipe_detail_title_label.text == "Resep"
	)
	ui.close_edit_menu()

	# Advance to Day 2: nasi_tempe unlocks UNCHECKED; previewing does not auto-enable it.
	if not await _advance_to_day(game_root, service, 2):
		game_root.free()
		await process_frame
		return
	ui.open_edit_menu()
	await process_frame
	var tempe_toggle := ui.get_edit_menu_recipe_button(&"nasi_tempe")
	var tempe_preview := ui.get_edit_menu_preview_button(&"nasi_tempe")
	tempe_preview.pressed.emit()
	await process_frame
	_check(
		"Day 2 newly unlocked nasi_tempe is unchecked and previewing keeps it disabled",
		not tempe_toggle.button_pressed
		and tempe_preview.text == "Nasi Tempe: Rp 18k"
		and ui.get_previewed_edit_menu_recipe_id() == &"nasi_tempe"
		and ui.recipe_detail_title_label.text == "Nasi Tempe"
		and ui.get_edit_menu_detail_lines() == PackedStringArray([
			"Masak nasi, goreng tempe, lalu satukan di piring.",
			"Beras",
			"Tempe",
		])
		and ui.get_pending_menu_selection() == [&"nasi_telor"]
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor"]
	)
	ui.close_edit_menu()

	# Reopen resets preview to no-selection; advance to Day 4 and inspect egg_salad + Sayur (potong).
	ui.open_edit_menu()
	_check("reopening Edit Menu starts cleanly in no-selection state", ui.get_previewed_edit_menu_recipe_id() == &"")
	ui.close_edit_menu()

	if not await _advance_to_day(game_root, service, 4):
		game_root.free()
		await process_frame
		return
	ui.open_edit_menu()
	await process_frame
	var salad_toggle := ui.get_edit_menu_recipe_button(&"egg_salad")
	var salad_preview := ui.get_edit_menu_preview_button(&"egg_salad")
	salad_preview.pressed.emit()
	await process_frame
	_check(
		"Day 4 egg_salad unlocked unchecked, preview shows Sayur (potong) without auto-enabling",
		not salad_toggle.button_pressed
		and ui.get_previewed_edit_menu_recipe_id() == &"egg_salad"
		and ui.recipe_detail_title_label.text == "Egg Salad"
		and ui.get_edit_menu_detail_lines() == PackedStringArray([
			"Goreng telur, potong sayur, lalu sajikan tanpa nasi.",
			"Telur",
			"Sayur (potong)",
		])
		and ui.get_pending_menu_selection() == [&"nasi_telor"]
	)

	# Switch preview back to Nasi Telur while toggling Nasi Ayam via checkmark -> confirm updates Run.
	ui.get_edit_menu_preview_button(&"nasi_telor").pressed.emit()
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = true
	await process_frame
	_check(
		"switching preview updates detail panel without disturbing checkmark selection",
		ui.recipe_detail_title_label.text == "Nasi Telur"
		and ui.get_edit_menu_detail_lines() == PackedStringArray([
			"Cuci dan masak beras, goreng telur, lalu sajikan bersama nasi.",
			"Beras",
			"Telur",
		])
		and ui.get_pending_menu_selection() == [&"nasi_telor", &"nasi_ayam"]
	)
	ui.edit_menu_confirm_button.pressed.emit()
	_check(
		"confirm persists newly toggled menu into RunController and updates forecast",
		not ui.is_edit_menu_open()
		and run.get_run_view()["selected_recipe_ids"] == [&"nasi_telor", &"nasi_ayam"]
		and ui.potential_demand_label.text == "Potensi Tamu: 18"
		and ui.forecast_quota_label.text == "Target Tamu: 18"
	)

	game_root.free()
	await process_frame


func _test_feedback_simplification_and_preservation() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	_check("seed beras & eggs", run.request_ingredient_basket_purchase({ &"beras": 1, &"telur": 2 }, &"storage_box"))

	# 1. Blocked wall click does not move player and does not spam noisy floor-blocked popup text.
	var tile_start := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(144.0 + 8.0 * 32.0 + 16.0, 36.0 + 16.0))
	_check(
		"blocked wall click keeps player put without spawning verbose tile_blocked popup",
		kitchen.get_player_tile() == tile_start
		and not ui.interaction_dialogue.visible
		and ui.context_message_label.text == ""
	)

	# 2. Failed start service (empty menu) still explains start_service_failed cleanly.
	var saved_menu := run._selected_recipe_ids.duplicate()
	run._selected_recipe_ids.clear()
	_type_word(ui, "buka")
	_check(
		"failed service start retains Tidak bisa mulai layanan explanation",
		ui.get_feedback_code() == &"start_service_failed"
		and ui.context_message_label.text == "Tidak bisa mulai layanan"
	)
	run._selected_recipe_ids = saved_menu

	# 3. Start SERVING: test mid-word invalid key shakes silently & lets valid typing finish.
	_type_word(ui, "buka")
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "telur")
	_send_left_click(ui, Vector2(192, 52))
	_send_key(ui, "g".unicode_at(0), KEY_G)
	_send_key(ui, "o".unicode_at(0), KEY_O)
	_send_key(ui, "z".unicode_at(0), KEY_Z)
	_check(
		"invalid letter z mid-prefix shakes dialogue silently without Huruf tidak cocok",
		kitchen.get_command_prefix() == "go"
		and ui.get_feedback_code() == &"invalid_key"
		and not ui.context_message_label.visible
		and ui.context_message_label.text == ""
		and ui.is_shaking()
	)
	_type_word(ui, "reng")
	_check(
		"continuing valid suffix after invalid key auto-executes goreng cleanly",
		kitchen.get_command_prefix() == ""
		and int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.COOKED
		and ui.get_feedback_code() == &"item_cooked"
	)

	# 4. Wrong recipe serve preserves Pesanannya beda! & keeps item; invalid_action preserves Nggak bisa sekarang.
	_send_left_click(ui, Vector2(288, 52))
	var first_table_id: StringName = service.get_customer_views()[0]["assigned_table_id"]
	var world_map := game_root.get_node("World") as WorldMap
	var tbl_node := world_map.registry.get_object(first_table_id) as Node2D
	var tbl_pos: Vector2 = world_map.get_canvas_transform() * tbl_node.global_position
	_send_left_click(ui, tbl_pos)
	_type_word(ui, "saji")
	kitchen._perform_typed_command(&"saji")
	_check(
		"serving incomplete dish emits wrong_order (Pesanannya beda!) without consuming held item",
		ui.get_feedback_code() == &"wrong_order"
		and ui.context_message_label.text == "Pesanannya beda!"
		and not kitchen.get_held_item_view().is_empty()
	)

	var empty_table_id: StringName = &"dining_table_02" if first_table_id == &"dining_table_01" else &"dining_table_01"
	var empty_node := world_map.registry.get_object(empty_table_id) as Node2D
	var empty_pos: Vector2 = world_map.get_canvas_transform() * empty_node.global_position
	_send_left_click(ui, empty_pos)
	kitchen._perform_typed_command(&"bersihkan")
	_check(
		"cleaning vacant clean table emits invalid_action explanation cleanly",
		ui.get_feedback_code() == &"invalid_action"
		and ui.context_message_label.text == "Nggak bisa sekarang"
	)

	game_root.free()
	await process_frame


func _test_edit_menu_modal_pause_dialogue_and_responsive() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var ui := game_root.get_node("UI") as GameUI
	if not await _advance_to_day(game_root, service, 3):
		game_root.free()
		await process_frame
		return

	# Select storage_box first -> open Edit Menu -> clicking detail panel / dimmer / typing blocked.
	_send_left_click(ui, Vector2(256, 52))
	var tile_before := kitchen.get_player_tile()
	ui.open_edit_menu()
	await process_frame
	ui.get_edit_menu_preview_button(&"nasi_ayam").pressed.emit()
	ui.get_edit_menu_recipe_button(&"nasi_ayam").button_pressed = true
	await process_frame

	_send_left_click(ui, ui.recipe_detail_panel.get_global_rect().get_center())
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check(
		"Edit Menu & detail panel block world clicks and typing while open",
		kitchen.get_player_tile() == tile_before
		and kitchen.get_selected_target_id() == &"storage_box"
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	# Pause on top of Edit Menu -> Resume restores Edit Menu, pending toggle, and previewed recipe.
	ui.pause_button.pressed.emit()
	await process_frame
	_check("Pause opens cleanly over Edit Menu", ui.is_pause_open() and ui.is_edit_menu_open())
	ui.pause_resume_button.pressed.emit()
	await process_frame
	_check(
		"Resume from Pause restores Edit Menu, checkmark toggle, and previewed dish",
		not ui.is_pause_open()
		and ui.is_edit_menu_open()
		and ui.get_previewed_edit_menu_recipe_id() == &"nasi_ayam"
		and ui.get_pending_menu_selection() == [&"nasi_telor", &"nasi_ayam"]
	)

	# Responsive fit across 480x270, 640x360, 1280x720, and 1600x900.
	for sz: Vector2i in [
		Vector2i(640, 360),
		Vector2i(480, 270),
		Vector2i(1280, 720),
		Vector2i(1600, 900),
	]:
		root.content_scale_size = sz
		root.size = sz
		ui._on_viewport_size_changed()
		await process_frame
		await process_frame
		var p_rect := ui.edit_menu_popup.get_global_rect()
		var hud_rect := ui.left_hud_region.get_global_rect()
		var detail_rect := ui.recipe_detail_panel.get_global_rect()
		var list_scroll_rect := (ui.edit_menu_recipe_list.get_parent() as Control).get_global_rect()
		var cancel_rect := ui.edit_menu_cancel_button.get_global_rect()
		var confirm_rect := ui.edit_menu_confirm_button.get_global_rect()
		_check(
			"Edit Menu + right-side Resep panel fit cleanly inside world_visible_rect at %dx%d" % [sz.x, sz.y],
			ui.world_visible_rect.encloses(p_rect)
			and ui.world_visible_rect.encloses(detail_rect)
			and not hud_rect.intersects(p_rect)
			and not hud_rect.intersects(detail_rect)
			and detail_rect.position.x >= p_rect.end.x + 4.0
			and p_rect.encloses(list_scroll_rect)
			and p_rect.encloses(cancel_rect)
			and p_rect.encloses(confirm_rect)
		)

	# Escape closes Edit Menu first (not Pause) and restores underlying storage_box dialogue.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes Edit Menu without opening Pause and restores Kotak Bahan dialogue",
		not ui.is_edit_menu_open()
		and not ui.is_pause_open()
		and ui.interaction_dialogue.visible
		and kitchen.get_selected_target_id() == &"storage_box"
	)

	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	game_root.free()
	await process_frame
