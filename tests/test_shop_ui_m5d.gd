extends SceneTree
## Headless integration tests for M5-D — Shop UI Simplification & Usability:
## - Ingredient Shop: cash/capacity/S1-S3/Tiba langsung/empty-pending/Stok removed;
##   slot isolation, price/total Rp Xk formatting, SERVING delayed deliveries, rejections,
##   and responsive fit at 640x360 and 480x270
## - Fixture Shop: HUD Beli Alat retired, slot-first entry fixed per popup, catalog filtered
##   by clicked slot type (table vs utility), sprite icons preserving aspect ratio, bold
##   Name: Price + short description + inline electricity only when > 0, Harga footer
## - Modal safety: world click & keyboard blocking, dialogue restoration, Pause restoration

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_ingredient_shop_simplification_and_behavior()
	await _test_fixture_shop_simplification_and_behavior()
	await _test_shop_modal_dialogue_pause_and_responsive_layout()
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


func _test_ingredient_shop_simplification_and_behavior() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Invalid unit and invalid phase checks before opening.
	_check("reject ingredient shop for unknown storage", not ui.open_ingredient_shop(&"stove"))
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame

	var beras_row := ui.get_shop_ingredient_controls(&"beras")
	var slot_labels: Array[String] = []
	for child in ui.shop_slots_row.get_children():
		var lbl := child.get_child(0) as Label
		if lbl != null:
			slot_labels.append(lbl.text)
	_check(
		"IngredientShop hides redundant cash, capacity, Tiba langsung, empty pending, Stok, and S1-S3 prefixes in PLANNING",
		ui.is_ingredient_shop_open()
		and ui.shop_target_label.text == "Kotak Bahan"
		and not ui.shop_cash_label.visible
		and not ui.shop_capacity_label.visible
		and not ui.shop_status_row.visible
		and not ui.shop_delivery_hint_label.visible
		and not ui.shop_pending_label.visible
		and not beras_row.has("stock_label")
		and slot_labels.size() == 3
		and slot_labels[0] == "Kosong (0/5)"
		and not slot_labels[0].begins_with("S1:")
		and ui.shop_total_label.text == "Total: Rp 0"
	)

	# Quantity changes & total formatting, cancel preserves cash and stock.
	ui.adjust_shop_quantity(&"beras", 2)
	ui.adjust_shop_quantity(&"telur", 1)
	_check(
		"quantity adjusts subtotal & total cleanly (2x2k + 1x3k = Rp 7k)",
		ui.get_shop_total() == 7000
		and ui.shop_total_label.text == "Total: Rp 7k"
		and (beras_row["subtotal_label"] as Label).text == "Rp 4k"
	)
	ui.shop_cancel_button.pressed.emit()
	_check(
		"ga jadi cancels without changing cash or inventory and restores dialogue",
		not ui.is_ingredient_shop_open()
		and int(run.get_run_view()["cash"]) == 100000
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 0
		and ui.interaction_dialogue.visible
		and kitchen.get_selected_target_id() == &"storage_box"
	)

	# PLANNING purchase deposits immediately & shows ingredient inside slot box without S-prefix.
	_type_word(ui, "beli")
	await process_frame
	_check("empty basket rejected", not ui.submit_ingredient_shop())
	ui.adjust_shop_quantity(&"beras", 2)
	_check("over-cash rejected", not ui.submit_ingredient_shop({&"sapi": 11}))
	_check("over-capacity rejected", not ui.submit_ingredient_shop({&"beras": 16}))
	ui.shop_checkout_button.pressed.emit()
	var dup_ok := ui.submit_ingredient_shop({&"telur": 1})
	_check(
		"PLANNING checkout deducts cash once, deposits stock, prevents double submit",
		not dup_ok
		and int(run.get_run_view()["cash"]) == 96000
		and int(kitchen.get_storage_unit_view(&"storage_box")["slots"][0]["quantity"]) == 2
	)

	# Add a second storage unit (fridge_01) -> verify storage-specific stock & SERVING delivery.
	_check("buy fridge_01", run.request_fixture_purchase(&"fridge", &"slot_utility_01"))
	ui.open_ingredient_shop(&"fridge_01")
	await process_frame
	var fridge_slot0 := ui.shop_slots_row.get_child(0).get_child(0) as Label
	_check(
		"fridge_01 shop stays isolated (2 empty slots, zero spill from storage_box)",
		ui.shop_slots_row.get_child_count() == 2
		and fridge_slot0.text == "Kosong (0/3)"
		and ui.shop_target_label.text == "Kulkas"
	)
	ui.close_ingredient_shop()

	_send_left_click(ui, Vector2(320, 148))
	_type_word(ui, "buka")
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame
	var box_slot0 := ui.shop_slots_row.get_child(0).get_child(0) as Label
	_check(
		"SERVING shop shows Tiba 100 dtk and clean slot label Beras 2/5",
		ui.shop_status_row.visible
		and ui.shop_delivery_hint_label.visible
		and ui.shop_delivery_hint_label.text == "Tiba 100 dtk"
		and box_slot0.text == "Beras 2/5"
		and not ui.shop_pending_label.visible
	)
	ui.adjust_shop_quantity(&"sayur", 1)
	ui.shop_checkout_button.pressed.emit()
	_type_word(ui, "beli")
	await process_frame
	_check(
		"active pending delivery becomes visible when present",
		ui.shop_pending_label.visible and ui.shop_pending_label.text.contains("Sayur x1")
	)
	ui.close_ingredient_shop()

	game_root.free()
	await process_frame


func _test_fixture_shop_simplification_and_behavior() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var run := game_root.get_run_controller() as RunController
	var world := game_root.get_node("World") as WorldMap
	var ui := game_root.get_node("UI") as GameUI

	_check(
		"Beli Alat HUD button retired & open_fixture_shop requires valid slot",
		not ui.fixture_shop_button.visible
		and ui.fixture_shop_button.disabled
		and not ui.open_fixture_shop(&"")
		and not ui.open_fixture_shop(&"slot_nonexistent")
	)

	# Click empty table slot in PLANNING -> ONLY dining_table offered, sprite icon + bold title + desc + Harga footer.
	var tbl_view := world.get_placement_slot_view(&"slot_table_01")
	var tbl_pos: Vector2 = world.get_canvas_transform() * Vector2(tbl_view.get("global_position", Vector2.ZERO))
	_send_left_click(ui, tbl_pos)
	await process_frame
	var dt_row := ui.get_fixture_shop_row(&"dining_table")
	_check(
		"table slot shows only dining_table, hides slot selector & cash/power header, shows Harga footer",
		ui.is_fixture_shop_open()
		and ui.get_selected_fixture_slot_id() == &"slot_table_01"
		and not ui.select_fixture_shop_slot(&"slot_table_02")
		and ui.fixture_list.get_child_count() == 1
		and not dt_row.is_empty()
		and not ui.fixture_slots_row.visible
		and not ui.fixture_cash_label.visible
		and not ui.fixture_power_label.visible
		and (dt_row["title_label"] as Label).text == "Meja Makan: Rp 75k"
		and not (dt_row["description_label"] as Label).text.contains("listrik")
		and ui.fixture_selection_label.text == "Harga: Rp 75k"
	)
	_check("wrong utility cannot be selected for table slot", not ui.select_fixture_shop_utility(&"stove"))
	ui.fixture_cancel_button.pressed.emit()
	_check(
		"ga jadi closes fixture shop without spending cash or installing table",
		not ui.is_fixture_shop_open()
		and int(run.get_run_view()["cash"]) == 100000
		and world.registry.get_object(&"dining_table_03") == null
	)

	# Click utility slot -> shows 6 utility options (no dining_table), icons preserve aspect, inline electricity on cooker/fridge.
	var util_view := world.get_placement_slot_view(&"slot_utility_01")
	var util_pos: Vector2 = world.get_canvas_transform() * Vector2(util_view.get("global_position", Vector2.ZERO))
	_send_left_click(ui, util_pos)
	await process_frame
	var fridge_row := ui.get_fixture_shop_row(&"fridge")
	var stove_row := ui.get_fixture_shop_row(&"stove")
	var cooker_row := ui.get_fixture_shop_row(&"rice_cooker")
	var stove_icon := (stove_row.get("icon") as Control).get_child(0) as TextureRect
	_check(
		"utility slot filters out dining_table and renders 6 utility rows with icons & inline electricity",
		ui.is_fixture_shop_open()
		and ui.fixture_list.get_child_count() == 6
		and ui.get_fixture_shop_row(&"dining_table").is_empty()
		and stove_icon != null
		and stove_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		and (stove_row["title_label"] as Label).text == "Kompor: Rp 60k"
		and (stove_row["description_label"] as Label).text == "Untuk memasak"
		and (fridge_row["title_label"] as Label).text == "Kulkas: Rp 80k"
		and (fridge_row["description_label"] as Label).text.contains("listrik: Rp 4k/hari")
		and (cooker_row["description_label"] as Label).text.contains("listrik: Rp 2k/hari")
	)
	ui.select_fixture_shop_utility(&"fridge")
	_check("selecting fridge updates footer Harga: Rp 80k", ui.fixture_selection_label.text == "Harga: Rp 80k")
	ui.fixture_confirm_button.pressed.emit()
	_check(
		"beli installs fridge_01 into slot_utility_01, deducts cash once, and prevents duplicate submit",
		not ui.is_fixture_shop_open()
		and not ui.submit_fixture_shop(&"box", &"slot_utility_02")
		and int(run.get_run_view()["cash"]) == 20000
		and world.registry.get_object(&"fridge_01") != null
	)

	# Insufficient cash rejection & SERVING rejection.
	var util2_view := world.get_placement_slot_view(&"slot_utility_02")
	var util2_pos: Vector2 = world.get_canvas_transform() * Vector2(util2_view.get("global_position", Vector2.ZERO))
	_send_left_click(ui, util2_pos)
	await process_frame
	_check(
		"insufficient cash purchase rejected cleanly without losing cash or installing stove_01",
		not ui.submit_fixture_shop()
		and ui.is_fixture_shop_open()
		and ui.fixture_error_label.visible
		and int(run.get_run_view()["cash"]) == 20000
		and world.registry.get_object(&"stove_01") == null
	)
	ui.close_fixture_shop()

	_type_word(ui, "buka")
	_send_left_click(ui, util2_pos)
	_check(
		"clicking placement slot in SERVING does not open fixture shop",
		not ui.is_fixture_shop_open() and game_root.is_serving()
	)

	game_root.free()
	await process_frame


func _test_shop_modal_dialogue_pause_and_responsive_layout() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var ui := game_root.get_node("UI") as GameUI

	# Modal click/typing blocking & Pause + Resume restoration for IngredientShop.
	_send_left_click(ui, Vector2(256, 52))
	_type_word(ui, "beli")
	await process_frame
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(352, 276))
	_type_word(ui, "buka")
	_check(
		"IngredientShop blocks world clicks and typing while open",
		kitchen.get_player_tile() == tile_before and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	ui.adjust_shop_quantity(&"beras", 1)
	ui.pause_button.pressed.emit()
	await process_frame
	_check("Pause opens cleanly on top of IngredientShop", ui.is_pause_open() and ui.is_ingredient_shop_open())
	ui.pause_resume_button.pressed.emit()
	await process_frame
	_check(
		"Resume from Pause restores IngredientShop and basket",
		not ui.is_pause_open() and ui.is_ingredient_shop_open() and ui.get_shop_basket() == { &"beras": 1 }
	)

	# Responsive 640x360 and 480x270 IngredientShop fit check.
	for sz: Vector2i in [Vector2i(640, 360), Vector2i(480, 270)]:
		root.content_scale_size = sz
		root.size = sz
		ui._on_viewport_size_changed()
		await process_frame
		await process_frame
		var p_rect := ui.ingredient_shop_popup.get_global_rect()
		var hud_rect := ui.left_hud_region.get_global_rect()
		var list_rect := ui.shop_ingredient_list.get_global_rect()
		var cancel_rect := ui.shop_cancel_button.get_global_rect()
		var buy_rect := ui.shop_checkout_button.get_global_rect()
		_check(
			"IngredientShop fits inside world_visible_rect without clipping at %dx%d" % [sz.x, sz.y],
			ui.world_visible_rect.encloses(p_rect)
			and not hud_rect.intersects(p_rect)
			and list_rect.position.x >= p_rect.position.x
			and list_rect.end.x <= p_rect.end.x
			and p_rect.encloses(cancel_rect)
			and p_rect.encloses(buy_rect)
		)

	ui.close_ingredient_shop()
	_check(
		"closing IngredientShop restores Kotak Bahan dialogue",
		not ui.is_ingredient_shop_open()
		and ui.interaction_dialogue.visible
		and kitchen.get_selected_target_id() == &"storage_box"
	)

	# Pause + Resume restoration for FixtureShop + 480x270 table slot check.
	ui.open_fixture_shop(&"slot_table_01")
	await process_frame
	ui.pause_button.pressed.emit()
	await process_frame
	ui.close_pause()
	await process_frame
	_check(
		"Resume from Pause restores FixtureShop and fixed slot",
		ui.is_fixture_shop_open() and ui.get_selected_fixture_slot_id() == &"slot_table_01"
	)
	var fp_small := ui.fixture_shop_popup.get_global_rect()
	_check(
		"FixtureShop fits at 480x270 cleanly without HUD overlap",
		ui.world_visible_rect.encloses(fp_small)
		and not ui.left_hud_region.get_global_rect().intersects(fp_small)
	)

	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	game_root.free()
	await process_frame
