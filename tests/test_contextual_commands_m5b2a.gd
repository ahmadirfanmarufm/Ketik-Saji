extends SceneTree
## Headless M5-B2A tests:
## Contextual Command Eligibility & Centralized Silent Prefix Revalidation.

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_storage_and_station_eligibility()
	await _test_online_dining_and_driver_eligibility()
	await _test_silent_prefix_revalidation_and_signal_lifecycle()
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _send_key(ui: GameUI, unicode_val: int, keycode_val: int = KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	if keycode_val == KEY_NONE and unicode_val > 0:
		ev.keycode = unicode_val
		ev.physical_keycode = unicode_val
	else:
		ev.keycode = keycode_val
		ev.physical_keycode = keycode_val
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _cook_plated_nasi_telor(kitchen: KitchenController, ui: GameUI) -> void:
	if kitchen.get_cooker_output_view(&"rice_cooker").is_empty():
		kitchen.on_interactable_clicked(&"storage_box")
		_type_word(ui, "beras")
		kitchen.on_interactable_clicked(&"washer")
		_type_word(ui, "cuci")
		kitchen.on_interactable_clicked(&"rice_cooker")
		_type_word(ui, "masak")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")


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


func _cook_plated_nasi_ayam(kitchen: KitchenController, ui: GameUI) -> void:
	if kitchen.get_cooker_output_view(&"rice_cooker").is_empty():
		kitchen.on_interactable_clicked(&"storage_box")
		_type_word(ui, "beras")
		kitchen.on_interactable_clicked(&"washer")
		_type_word(ui, "cuci")
		kitchen.on_interactable_clicked(&"rice_cooker")
		_type_word(ui, "masak")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "ayam")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")


func _test_storage_and_station_eligibility() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Planning phase: only buka is exposed when no interactable target is selected.
	_check(
		"PLANNING phase allows only buka command when no target selected",
		kitchen.get_allowed_commands_for_selected_target() == ["buka"]
	)
	kitchen.on_interactable_clicked(&"stove")
	_check(
		"PLANNING phase with selected target hides SERVING commands",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Stock only sayur (1), telur (2), beras (2) -> 3 distinct slots in starter storage_box (Day 4+ for sayur).
	_advance_to_day(game_root, 4)
	_check(
		"stock storage_box in PLANNING",
		run.request_ingredient_purchase(&"sayur", 1, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
		and run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	)
	_check("start Day 4 SERVING", game_root.start_service_requested())

	# 1. Storage exposes beli + stocked ingredients alphabetically when hand is empty.
	kitchen.on_interactable_clicked(&"storage_box")
	ui._refresh_dialogue()
	_check(
		"storage_box exposes only stocked ingredient commands + beli alphabetically when hand is empty",
		kitchen.get_allowed_commands_for_selected_target() == ["beli", "beras", "sayur", "telur"]
		and ui.allowed_commands_label.visible
		and ui.allowed_commands_label.text == "beli, beras, sayur, telur"
	)

	# Take last sayur (1 -> 0): while holding RAW sayur, storage_box hides ingredient commands.
	_type_word(ui, "sayur")
	_check(
		"storage_box hides ingredient commands while holding loose RAW sayur",
		kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_allowed_commands_for_selected_target() == ["beli"]
		and ui.allowed_commands_label.visible
		and ui.allowed_commands_label.text == "beli"
	)

	# Worktable chop & stove eligibility on RAW sayur -> CHOPPED -> CHOPPED_AND_COOKED.
	kitchen.on_interactable_clicked(&"work_table_chop")
	_check(
		"work_table_chop exposes potong for RAW sayur and stove also exposes goreng",
		kitchen.get_allowed_commands_for_selected_target() == ["potong"]
	)
	kitchen.on_interactable_clicked(&"stove")
	_check(
		"stove exposes goreng for RAW sayur",
		kitchen.get_allowed_commands_for_selected_target() == ["goreng"]
	)
	kitchen.on_interactable_clicked(&"washer")
	_check(
		"washer hides cuci for RAW sayur and empty dirty rack",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"work_table_chop")
	_type_word(ui, "potong")
	_check(
		"work_table_chop hides potong after sayur is CHOPPED",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.CHOPPED
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"stove")
	_check(
		"stove exposes goreng for CHOPPED sayur",
		kitchen.get_allowed_commands_for_selected_target() == ["goreng"]
	)
	_type_word(ui, "goreng")
	_check(
		"stove hides goreng after sayur becomes CHOPPED_AND_COOKED",
		int(kitchen.get_held_item_view()["parts"][0]["state"])
			== SharedTypes.PrepState.CHOPPED_AND_COOKED
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Trash sayur -> empty hand: sayur (stock 0) is now removed from storage_box commands!
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"depleting last sayur removes sayur from storage_box allowed commands",
		kitchen.get_allowed_commands_for_selected_target() == ["beli", "beras", "telur"]
	)

	# Empty-hand stove/cooker/chop/washer hide their commands.
	kitchen.on_interactable_clicked(&"stove")
	var empty_stove_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen.on_interactable_clicked(&"rice_cooker")
	var empty_cooker_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen.on_interactable_clicked(&"washer")
	var empty_washer_cmds := kitchen.get_allowed_commands_for_selected_target()
	kitchen.on_interactable_clicked(&"work_table_chop")
	var empty_chop_cmds := kitchen.get_allowed_commands_for_selected_target()
	_check(
		"empty-hand idle stations hide all commands",
		empty_stove_cmds.is_empty()
		and empty_cooker_cmds.is_empty()
		and empty_washer_cmds.is_empty()
		and empty_chop_cmds.is_empty()
	)

	# Holding empty or partial plate hides storage commands; backend still guards stock & plate.
	kitchen.on_interactable_clicked(&"plate_rack")
	var empty_plate_before := kitchen.get_held_item_view()
	var box_before := kitchen.get_storage_unit_view(&"storage_box")
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"holding empty plate hides storage_box ingredient commands",
		kitchen.get_allowed_commands_for_selected_target() == ["beli"]
		and ui.allowed_commands_label.visible
		and ui.allowed_commands_label.text == "beli"
	)
	_type_word(ui, "telur")
	_check(
		"typing hidden telur while holding empty plate rejects invalid_key and keeps stock/plate",
		ui.get_feedback_code() == &"invalid_key"
		and kitchen.get_storage_unit_view(&"storage_box") == box_before
		and kitchen.get_held_item_view() == empty_plate_before
	)
	kitchen._perform_typed_command(&"telur")
	_check(
		"backend telur retrieval while holding empty plate emits hand_full and keeps stock/plate",
		ui.get_feedback_code() == &"hand_full"
		and kitchen.get_storage_unit_view(&"storage_box") == box_before
		and kitchen.get_held_item_view() == empty_plate_before
	)
	kitchen.on_interactable_clicked(&"plate_rack")

	# Washer + Rice cooker lifecycle (`cuci`, `masak`, `nasi`, compatible vs incompatible plate).
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"RAW beras hides masak on empty rice_cooker",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"washer")
	_check(
		"RAW beras exposes cuci on washer",
		kitchen.get_allowed_commands_for_selected_target() == ["cuci"]
	)
	_type_word(ui, "cuci")
	_check(
		"WASHED beras hides cuci on washer",
		int(kitchen.get_held_item_view()["parts"][0]["state"]) == SharedTypes.PrepState.WASHED
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"WASHED beras exposes only masak on empty rice_cooker",
		kitchen.get_allowed_commands_for_selected_target() == ["masak"]
	)
	_type_word(ui, "masak")
	_check(
		"after masak fills 5 portions and frees hand, rice_cooker switches from masak to nasi",
		kitchen.get_held_item_view().is_empty()
		and int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5
		and kitchen.get_allowed_commands_for_selected_target() == ["nasi"]
	)

	# Occupied cooker hides masak even when holding WASHED beras.
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"occupied cooker hides both masak and nasi while holding WASHED beras",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"trash")

	# Compatible vs incompatible plates at rice_cooker with remaining portions.
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"empty held plate exposes nasi at occupied rice_cooker",
		kitchen.get_allowed_commands_for_selected_target() == ["nasi"]
	)
	_type_word(ui, "nasi")
	_check(
		"plate already containing COOKED_RICE hides nasi at rice_cooker",
		kitchen.get_held_item_view().get("parts", []).size() == 1
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Holding a partial [COOKED_RICE] plate must also hide storage commands while stock exists.
	var partial_before := kitchen.get_held_item_view()
	var box_before_partial := kitchen.get_storage_unit_view(&"storage_box")
	kitchen.on_interactable_clicked(&"storage_box")
	_check(
		"holding partial plate hides storage_box ingredient commands while telur stock exists",
		partial_before.get("plate_id", &"") != &""
		and partial_before.get("matched_recipe_id", &"") == &""
		and kitchen.get_allowed_commands_for_selected_target() == ["beli"]
		and ui.allowed_commands_label.visible
		and ui.allowed_commands_label.text == "beli"
	)
	_type_word(ui, "telur")
	_check(
		"typing hidden telur while holding partial plate rejects invalid_key and keeps stock/parts",
		ui.get_feedback_code() == &"invalid_key"
		and kitchen.get_storage_unit_view(&"storage_box") == box_before_partial
		and kitchen.get_held_item_view() == partial_before
	)
	kitchen._perform_typed_command(&"telur")
	_check(
		"backend telur retrieval while holding partial plate emits hand_full and keeps stock/parts",
		ui.get_feedback_code() == &"hand_full"
		and kitchen.get_storage_unit_view(&"storage_box") == box_before_partial
		and kitchen.get_held_item_view() == partial_before
	)

	# Complete nasi_telor, verify still hides nasi, then verify [COOKED telur] plate exposes nasi.
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"completed nasi_telor plate hides nasi at rice_cooker",
		kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_telor"
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")

	# Partial [COOKED telur] plate (missing rice) exposes nasi!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"partial [COOKED telur] plate exposes nasi at occupied rice_cooker",
		kitchen.get_allowed_commands_for_selected_target() == ["nasi"]
	)

	# Rice cooker edge-case consistency:
	# 1) Exhausted output (portions == 0) must not block masak when holding WASHED beras.
	# 2) Positive portions with empty parts hides masak (cooker_full) and hides nasi (cooker_empty).
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")
	var cooker_backup: Dictionary = kitchen._cooker_outputs.get(&"rice_cooker", {}).duplicate(true)
	kitchen._held_item = kitchen._create_loose_item(&"beras", SharedTypes.PrepState.WASHED, &"HELD")
	kitchen._cooker_outputs[&"rice_cooker"] = {
		"portions": 0,
		"parts": [{"ingredient_id": &"beras", "state": SharedTypes.PrepState.COOKED_RICE}],
	}
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check(
		"exhausted rice_cooker output (0 portions) still allows masak with held WASHED beras",
		kitchen.get_allowed_commands_for_selected_target() == ["masak"]
	)
	kitchen._cooker_outputs[&"rice_cooker"] = {"portions": 2, "parts": []}
	_check(
		"positive portions with empty parts hides masak while holding WASHED beras",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen._perform_typed_command(&"masak")
	_check(
		"backend masak on positive-portion cooker rejects cooker_full cleanly",
		ui.get_feedback_code() == &"cooker_full"
	)
	kitchen._held_item = {}
	_check(
		"positive portions with empty parts hides nasi with empty hand",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen._perform_typed_command(&"nasi")
	_check(
		"backend nasi on empty-parts cooker rejects cooker_empty cleanly",
		ui.get_feedback_code() == &"cooker_empty"
	)
	kitchen._cooker_outputs[&"rice_cooker"] = cooker_backup

	game_root.free()
	await process_frame


func _test_online_dining_and_driver_eligibility() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	# Advance to Day 3 so ayam is unlocked; keep menu on nasi_telor while preparing wrong dish nasi_ayam.
	_advance_to_day(game_root, 3)
	run.select_daily_menu([&"nasi_telor"])
	_check("buy box_01", run.request_fixture_purchase(&"box", &"slot_utility_01"))
	var fast_cfg := service._economy_config.duplicate(true) as EconomyConfig
	fast_cfg.online_offer_initial_delay_seconds = 0.0
	fast_cfg.online_offer_interval_seconds = 0.1
	service._economy_config = fast_cfg
	_check(
		"stock ingredients across storage_box and box_01",
		run.request_ingredient_purchase(&"beras", 4, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
		and run.request_ingredient_purchase(&"ayam", 2, &"box_01")
	)
	_check("start Day 3 SERVING", game_root.start_service_requested())

	# 1. Online station eligibility: active -> ["terima"]; cap 4 -> []; cutoff -> [].
	kitchen.on_interactable_clicked(&"online_station")
	_check(
		"online_station exposes terima when offer enabled",
		kitchen.get_allowed_commands_for_selected_target() == ["terima"]
	)
	for i in range(4):
		if i > 0:
			game_root._process(0.15)
		_type_word(ui, "terima")
	_check(
		"online_station hides terima at concurrent cap=4",
		service.get_driver_views().size() == 4
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Overflow driver hides saji even when holding a completed nasi_telor.
	_cook_plated_nasi_telor(kitchen, ui)
	var ov_id := StringName(service.get_driver_views()[3]["driver_id"])
	var d1_id := StringName(service.get_driver_views()[0]["driver_id"])
	kitchen.on_overflow_driver_clicked(ov_id)
	_check(
		"overflow driver hides saji even when holding matching completed dish",
		kitchen.get_selected_target_id() == ov_id
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# In-spot driver exposes saji for matching completed dish and delivers cleanly.
	kitchen.on_interactable_clicked(d1_id)
	_check(
		"in-spot driver exposes saji when holding matching completed dish",
		kitchen.get_allowed_commands_for_selected_target() == ["saji"]
	)
	_type_word(ui, "saji")
	_check(
		"valid saji delivers to driver d1_id and removes driver",
		ui.get_feedback_code() == &"order_served"
		and not service.has_driver(d1_id)
		and kitchen.get_held_item_view().is_empty()
	)

	# In-spot driver d2_id with empty hand, loose item, partial plate, and WRONG completed dish.
	var d2_id := StringName(service.get_driver_views()[0]["driver_id"])
	kitchen.on_interactable_clicked(d2_id)
	_check(
		"in-spot driver hides saji when hand is empty",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(d2_id)
	_check(
		"in-spot driver hides saji when holding loose COOKED_RICE",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(d2_id)
	_check(
		"in-spot driver hides saji when holding incomplete [COOKED_RICE] plate",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")

	# Prepare completed WRONG dish (nasi_ayam) via box_01 + cooker/stove/work_table_stage:
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"box_01")
	_type_word(ui, "ayam")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"work_table_stage")
	_check(
		"wrong completed dish nasi_ayam assembled on plate",
		kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_ayam"
	)

	# Verify wrong completed dish keeps `saji` visible on driver and triggers "Pesanannya beda!".
	kitchen.on_interactable_clicked(d2_id)
	_check(
		"in-spot driver keeps saji visible when holding wrong completed dish nasi_ayam",
		kitchen.get_allowed_commands_for_selected_target() == ["saji"]
	)
	_type_word(ui, "saji")
	_check(
		"typing saji with wrong completed dish on driver emits Pesanannya beda! cleanly",
		ui.get_feedback_code() == &"wrong_order"
		and ui.context_message_label.text == "Pesanannya beda!"
		and service.has_driver(d2_id)
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_ayam"
	)

	# 2. Dining table eligibility across CLEAN_VACANT, OCCUPIED_WAITING (wrong & matching dish),
	#    OCCUPIED_EATING, and DIRTY -> cleaned + washer dirty plate!
	kitchen.on_interactable_clicked(&"dining_table_02")
	_check(
		"CLEAN_VACANT dining_table_02 hides saji and bersihkan even when holding completed dish",
		int(service.get_table_view(&"dining_table_02")["state"])
			== SharedTypes.TableState.CLEAN_VACANT
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Advance 25s so Customer 1 & 2 are seated in OCCUPIED_WAITING at dining_table_01 & 02.
	game_root._process(25.0)
	_check(
		"dining_table_01 becomes OCCUPIED_WAITING after 25s",
		int(service.get_table_view(&"dining_table_01")["state"])
			== SharedTypes.TableState.OCCUPIED_WAITING
	)
	kitchen.on_interactable_clicked(&"dining_table_01")
	_check(
		"OCCUPIED_WAITING dining_table_01 keeps saji visible for wrong completed dish nasi_ayam",
		kitchen.get_allowed_commands_for_selected_target() == ["saji"]
	)
	_type_word(ui, "saji")
	_check(
		"typing saji with wrong completed dish at dining table emits Pesanannya beda!",
		ui.get_feedback_code() == &"wrong_order"
		and ui.context_message_label.text == "Pesanannya beda!"
		and int(service.get_table_view(&"dining_table_01")["state"])
			== SharedTypes.TableState.OCCUPIED_WAITING
		and kitchen.get_held_item_view().get("matched_recipe_id", &"") == &"nasi_ayam"
	)

	# Discard wrong dish, return plate, verify empty hand / loose item hide saji on table_01.
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"dining_table_01")
	_check(
		"OCCUPIED_WAITING table_01 hides saji when hand is empty",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"dining_table_01")
	_check(
		"OCCUPIED_WAITING table_01 hides saji when holding incomplete loose COOKED_RICE",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"trash")

	# Serve valid nasi_telor to table_01 -> OCCUPIED_EATING hides commands even with another dish.
	_cook_plated_nasi_telor(kitchen, ui)
	kitchen.on_interactable_clicked(&"dining_table_01")
	_check(
		"OCCUPIED_WAITING table_01 exposes saji for matching nasi_telor",
		kitchen.get_allowed_commands_for_selected_target() == ["saji"]
	)
	_type_word(ui, "saji")
	_check(
		"serving matching nasi_telor transitions table_01 to OCCUPIED_EATING and hides saji",
		int(service.get_table_view(&"dining_table_01")["state"])
			== SharedTypes.TableState.OCCUPIED_EATING
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	# Advance 20s so Customer 1 finishes eating -> table_01 becomes DIRTY -> bersihkan -> washer cuci!
	game_root._process(21.0)
	_check(
		"table_01 becomes DIRTY after 20s eating and exposes only bersihkan",
		int(service.get_table_view(&"dining_table_01")["state"]) == SharedTypes.TableState.DIRTY
		and kitchen.get_allowed_commands_for_selected_target() == ["bersihkan"]
	)
	_type_word(ui, "bersihkan")
	_check(
		"bersihkan clears DIRTY table_01 (promoting waiting FIFO customer or CLEAN_VACANT) and hides bersihkan",
		int(service.get_table_view(&"dining_table_01")["state"]) != SharedTypes.TableState.DIRTY
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
	)
	kitchen.on_interactable_clicked(&"washer")
	_check(
		"washer exposes cuci with empty hand when dirty plate is in WASHER_DIRTY",
		kitchen.get_allowed_commands_for_selected_target() == ["cuci"]
	)
	_type_word(ui, "cuci")
	_check(
		"washer hides cuci once dirty plate is washed back to rack",
		kitchen.get_allowed_commands_for_selected_target().is_empty()
	)

	game_root.free()
	await process_frame


func _test_silent_prefix_revalidation_and_signal_lifecycle() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var run := game_root.get_run_controller() as RunController
	var ui := game_root.get_node("UI") as GameUI

	var recorded_feedbacks: Array[StringName] = []
	kitchen.action_feedback.connect(
		func(code: StringName) -> void:
			recorded_feedbacks.append(code)
	)

	_check(
		"stock storage_box for prefix revalidation tests",
		run.request_ingredient_purchase(&"beras", 2, &"storage_box")
		and run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	)
	_check("start Day 1 SERVING", game_root.start_service_requested())

	# Scenario A: online_offer_changed reaches cutoff while typing "ter" on online_station.
	game_root._process(10.0) # Periodic online offer opens at t=10s.
	kitchen.on_interactable_clicked(&"online_station")
	_type_word(ui, "ter")
	ui._process(0.016)
	_check(
		"partial prefix ter active on online_station before cutoff",
		kitchen.get_command_prefix() == "ter"
		and ui.prefix_prompt_label.text == "Ketik: [ter]"
		and ui.remaining_prompt_label.visible
	)
	recorded_feedbacks.clear()
	game_root._process(12.0) # Advances to t=22s past online cutoff (day_queue_remaining == 2).
	ui._process(0.016)
	_check(
		"online cutoff silently clears stale ter prefix without error feedback or shake",
		not service.get_online_acceptance_enabled()
		and kitchen.get_selected_target_id() == &"online_station"
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and kitchen.get_command_prefix() == ""
		and recorded_feedbacks.is_empty()
		and not ui.context_message_label.visible
		and not ui.is_shaking()
		and not ui.prefix_prompt_label.visible
		and not ui.remaining_prompt_label.visible
	)
	_send_key(ui, "i".unicode_at(0), KEY_I)
	_check(
		"next key after silent prefix clear does not complete old terima word",
		kitchen.get_command_prefix() == ""
		and ui.get_feedback_code() == &"invalid_key"
	)
	_send_key(ui, 0, KEY_ESCAPE)

	# Scenario B: dining table customer impatience timeout while holding nasi_telor & typing "sa".
	# Clear outside queue/remaining spawns except seated table_01/table_02 so table_01 becomes
	# CLEAN_VACANT when Customer 1 times out, while Customer 2 keeps SERVING active.
	_cook_plated_nasi_telor(kitchen, ui)
	game_root._process(10.0) # Customer 1 & 2 seated at t=32s.
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	kitchen.on_interactable_clicked(&"dining_table_01")
	_type_word(ui, "sa")
	ui._process(0.016)
	_check(
		"partial prefix sa active on OCCUPIED_WAITING table_01 before impatience timeout",
		int(service.get_table_view(&"dining_table_01")["state"])
			== SharedTypes.TableState.OCCUPIED_WAITING
		and kitchen.get_command_prefix() == "sa"
	)
	recorded_feedbacks.clear()
	for _step in range(80):
		if (
			int(service.get_table_view(&"dining_table_01")["state"])
			!= SharedTypes.TableState.OCCUPIED_WAITING
		):
			break
		game_root._process(1.0)
	ui._process(0.016)
	_check(
		"customer impatience timeout clears stale sa prefix silently with zero feedback/shake",
		game_root.is_serving()
		and int(service.get_table_view(&"dining_table_01")["state"])
			== SharedTypes.TableState.CLEAN_VACANT
		and kitchen.get_selected_target_id() == &"dining_table_01"
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and kitchen.get_command_prefix() == ""
		and recorded_feedbacks.is_empty()
		and not ui.is_shaking()
		and not ui.prefix_prompt_label.visible
		and not ui.remaining_prompt_label.visible
	)
	kitchen.on_interactable_clicked(&"trash")
	kitchen.on_interactable_clicked(&"plate_rack")

	# Scenario C: kitchen_state_changed silently clears stale prefix when state invalidates it.
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "na")
	ui._process(0.016)
	_check(
		"partial prefix na active on occupied rice_cooker",
		kitchen.get_command_prefix() == "na"
	)
	recorded_feedbacks.clear()
	kitchen._cooker_outputs.erase(&"rice_cooker")
	kitchen.kitchen_state_changed.emit()
	ui._process(0.016)
	_check(
		"kitchen_state_changed invalidating cooker portions clears na prefix silently",
		kitchen.get_selected_target_id() == &"rice_cooker"
		and kitchen.get_allowed_commands_for_selected_target().is_empty()
		and kitchen.get_command_prefix() == ""
		and recorded_feedbacks.is_empty()
		and not ui.is_shaking()
		and not ui.prefix_prompt_label.visible
	)

	# Scenario D: rebinding signals stays deduplicated and cleanup on free leaves no leaks.
	kitchen.bind_service(service)
	kitchen.bind_service(service)
	var drv_conns := service.drivers_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var tbl_conns := service.tables_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var ord_conns := service.orders_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var off_conns := service.online_offer_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	_check(
		"repeated bind_service connects each service signal to kitchen exactly once",
		drv_conns == 1 and tbl_conns == 1 and ord_conns == 1 and off_conns == 1
	)

	# Scenario E: removing KitchenController from tree triggers _exit_tree() and disconnects all
	# signals from the still-valid ServiceController, GameRoot, and kitchen self signal.
	var kitchen_parent := kitchen.get_parent()
	kitchen_parent.remove_child(kitchen)
	var drv_after := service.drivers_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var tbl_after := service.tables_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var ord_after := service.orders_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var off_after := service.online_offer_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	var phase_after := game_root.phase_changed.get_connections().filter(
		func(c: Dictionary) -> bool: return c["callable"].get_object() == kitchen
	).size()
	_check(
		"KitchenController._exit_tree disconnects callbacks from still-valid ServiceController and GameRoot",
		is_instance_valid(service)
		and drv_after == 0
		and tbl_after == 0
		and ord_after == 0
		and off_after == 0
		and phase_after == 0
		and not kitchen.kitchen_state_changed.is_connected(kitchen._on_self_kitchen_state_changed)
	)
	service.drivers_changed.emit()
	service.tables_changed.emit()
	service.online_offer_changed.emit()

	kitchen.free()
	game_root.free()
	await process_frame
