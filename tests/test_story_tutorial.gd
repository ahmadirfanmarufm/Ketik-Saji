extends SceneTree
## Headless verification suite for Interactive In-World Guided Tutorial,
## Visual Guidance Overlay, Story Introduction, Daily Narratives (Days 1-7),
## Feature Discovery Tips, Quick Reference, Pause Isolation, Responsive Layout
## Bounds (640x360 & 480x270), and pegawai.png asset inspection.

const REQUIRED_EPILOGUE_MSG: String = (
	"Memiliki lebih banyak belum tentu membuat kita lebih sukses. "
	+ "Mengelola apa yang kita punya dengan bijak jauh lebih penting."
)
const REQUIRED_DAY9_REMINDER: String = (
	"Semakin banyak menu belum tentu semakin banyak keuntungan. "
	+ "Kelola bahan, waktu, dan pelayanan dengan baik."
)

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_scene_boot_opening_story_and_skip()
	await _test_economy_parity_with_and_without_onboarding()
	await _test_guided_day1_flow_highlights_and_negative_guards()
	await _test_precompleted_and_out_of_order_resilience()
	await _test_alternate_plating_route_and_unrelated_dirty_table_guard()
	await _test_world_click_through_modals_pause_and_multiday_restart()
	await _test_daily_narratives_and_day7_epilogues()
	await _test_day2_to_7_feature_discovery_and_contextual_highlights()
	await _test_responsive_layout_bounds()
	await _test_pegawai_asset_and_runtime_unused()
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


func _send_left_click(ui: GameUI, canvas_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = canvas_pos
	ev.global_position = canvas_pos
	ui.get_viewport().push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _advance_sim(game_root: GameRoot, seconds: float, dt: float = 0.25) -> void:
	var remaining := seconds
	while remaining > 0.0001:
		var step := minf(dt, remaining)
		game_root._process(step)
		remaining -= step


func _spawn_direct_game_root(onboarding: bool) -> GameRoot:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	root.add_child(game_root)
	await process_frame
	await process_frame
	var ui := game_root.get_node("UI") as GameUI
	if onboarding:
		ui.set_onboarding_enabled(true)
	return game_root


func _cleanup_direct_game_root(game_root: GameRoot) -> void:
	if game_root != null and is_instance_valid(game_root):
		game_root.queue_free()
	await process_frame
	await process_frame


func _assert_control_inside_viewport(
	label: String, ctrl: Control, vp_size: Vector2, min_x: float
) -> void:
	var r := ctrl.get_global_rect()
	var valid := (
		ctrl.visible
		and r.position.x >= min_x - 1.0
		and r.position.y >= -1.0
		and r.end.x <= vp_size.x + 1.0
		and r.end.y <= vp_size.y + 1.0
		and r.size.x >= 40.0
		and r.size.y >= 16.0
	)
	_check(label, valid)


func _test_scene_boot_opening_story_and_skip() -> void:
	var err := change_scene_to_file("res://scenes/main/game_root.tscn")
	_check("change_scene_to_file loads game_root.tscn cleanly", err == OK)
	await process_frame
	await process_frame
	await process_frame

	var game_root := current_scene as GameRoot
	_check("current_scene is GameRoot on real scene boot", game_root != null)
	if game_root == null:
		return

	var ui := game_root.get_node("UI") as GameUI
	_check("onboarding auto-enabled on real scene boot", ui.is_onboarding_enabled())
	_check("opening story auto-opens on Day 1", ui.is_story_open())
	_check("story modal blocks world/typing input", ui.is_modal_blocking())
	_check("visual guidance stays hidden while opening story is open", not ui.get_tutorial_guidance_view().get("active", false))

	var sv := ui.get_story_state_view()
	_check("opening story title matches Hari 1: Warisan Terakhir", str(sv.get("title", "")) == "Hari 1: Warisan Terakhir")
	_check("opening story has 3 lines", int(sv.get("line_count", 0)) == 3)
	_check("line 1 mentions modal & starter gear", str(sv.get("text", "")).contains("Rp 100k") and str(sv.get("text", "")).contains("Nasi Telor"))

	var kitchen := game_root.get_kitchen_controller() as KitchenController
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	_check(
		"typing while story open does not execute kitchen command",
		kitchen.get_executed_command_count() == 0 and kitchen.get_held_item_view().is_empty()
	)
	_check("opening overlay modals rejected while story open", not ui.open_edit_menu())

	_check("advance_story moves to line 2 (Orang Tua)", ui.advance_story())
	var sv2 := ui.get_story_state_view()
	_check("line 2 speaker is Orang Tua", str(sv2.get("speaker", "")) == "Orang Tua")
	_check("line 2 contains exact premise quote", str(sv2.get("text", "")).contains("Tidak harus besar"))

	_check("advance_story moves to line 3 (Kamu)", ui.advance_story())
	var sv3 := ui.get_story_state_view()
	_check("line 3 speaker is Kamu with portrait visible", str(sv3.get("speaker", "")) == "Kamu" and ui.story_portrait_frame.visible)

	_check("advance_story closes final line", ui.advance_story())
	_check("story overlay closed after final line", not ui.is_story_open())
	_check("modal lock released after story", not ui.is_modal_blocking())
	_check("tutorial starts automatically at step_01_objective", ui.is_tutorial_active() and ui.get_tutorial_step_id() == &"step_01_objective")

	# Advancing Step 1 highlights storage_box, skipping removes both banner & highlight.
	ui.tutorial_next_button.pressed.emit()
	_check("step 2 highlights storage_box", ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")
	ui.skip_tutorial()
	_check("tutorial skipped cleanly", ui.is_tutorial_skipped() and not ui.is_tutorial_active())
	_check("banner and visual guidance disappear on tutorial skip", not ui.tutorial_banner.visible and not ui.get_tutorial_guidance_view().get("active", false))

	unload_current_scene()
	await process_frame
	await process_frame

	var gr_skip := await _spawn_direct_game_root(true)
	var ui_skip := gr_skip.get_node("UI") as GameUI
	ui_skip.skip_story()
	_check("skip_story advances to Day 1 tutorial step_01_objective", ui_skip.is_tutorial_active() and ui_skip.get_tutorial_step_id() == &"step_01_objective")
	await _cleanup_direct_game_root(gr_skip)


func _test_economy_parity_with_and_without_onboarding() -> void:
	var gr_off := await _spawn_direct_game_root(false)
	var gr_on := await _spawn_direct_game_root(true)
	var ui_off := gr_off.get_node("UI") as GameUI
	_check("legacy direct GameRoot keeps onboarding disabled by default", not ui_off.is_onboarding_enabled())

	var rv_off: Dictionary = (gr_off.get_run_controller() as RunController).get_run_view()
	var rv_on: Dictionary = (gr_on.get_run_controller() as RunController).get_run_view()
	_check(
		"Day 1 cash & menus identical with onboarding on/off",
		int(rv_off.get("cash", -1)) == int(rv_on.get("cash", -2))
		and int(rv_on.get("cash", 0)) == 100000
		and rv_off.get("unlocked_recipe_ids", []) == rv_on.get("unlocked_recipe_ids", [])
		and rv_off.get("selected_recipe_ids", []) == rv_on.get("selected_recipe_ids", [])
	)
	await _cleanup_direct_game_root(gr_off)
	await _cleanup_direct_game_root(gr_on)


func _test_guided_day1_flow_highlights_and_negative_guards() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController

	ui.skip_story()
	_check("Step 1 objective active", ui.get_tutorial_step_id() == &"step_01_objective")
	ui.tutorial_next_button.pressed.emit()
	_check("Step 2 prepare ingredients active", ui.get_tutorial_step_id() == &"step_02_prepare_ingredients")

	# Highlight appears on storage_box.
	var g_box := ui.get_tutorial_guidance_view()
	_check("Step 2 highlights storage_box for shopping", bool(g_box.get("active", false)) and g_box.get("target_id", &"") == &"storage_box")

	# Partial ingredient guard: buying ONLY beras without telur must NOT finish Step 2!
	_check("Ingredient shop opens on storage_box", ui.open_ingredient_shop(&"storage_box"))
	_check("guidance highlight temporarily hides while IngredientShopOverlay modal is open", not ui.get_tutorial_guidance_view().get("active", false))
	_check("buying only beras succeeds", ui.submit_ingredient_shop({&"beras": 2}))
	ui.close_ingredient_shop()
	_check("guidance highlights storage_box again asking for missing telur", ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box" and ui.tutorial_body_label.text.contains("telur"))

	# Start SERVING and take beras WITHOUT telur in storage -> still MUST stay in Step 2!
	_check("start_service_requested starts SERVING", game_root.start_service_requested())
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	_check(
		"retrieving beras alone without telur does NOT complete Step 2",
		ui.get_tutorial_step_id() == &"step_02_prepare_ingredients"
	)

	# Now buy telur during SERVING (via RunController/deliveries after 100s) OR better: hold rice, let delivery commit -> Step 2 satisfies!
	_check("open IngredientShop in SERVING to stock telur", ui.open_ingredient_shop(&"storage_box"))
	_check("buying telur in SERVING succeeds", ui.submit_ingredient_shop({&"telur": 4}))
	ui.close_ingredient_shop()
	# With pending telur delivery scheduled and beras in hand, both required ingredients are available/obtained -> Step 3!
	_check("both beras & telur accounted for advances to Step 3 wash_rice", ui.get_tutorial_step_id() == &"step_03_wash_rice")
	_check("Step 3 highlights washer", ui.get_tutorial_guidance_view().get("target_id", &"") == &"washer")

	# Wait 100s? No, step simulation forward until telur delivery commits AND diner arrives so telur is in box!
	_advance_sim(game_root, 101.0, 1.0)
	var waiting_table_id: StringName = &""
	for tid in service.get_registered_table_ids():
		if int(service.get_table_view(tid).get("state", -1)) == SharedTypes.TableState.OCCUPIED_WAITING:
			waiting_table_id = tid
			break

	# Negative guard on Step 3: simply clicking washer must NOT advance to Step 4!
	kitchen.on_interactable_clicked(&"washer")
	_check("clicking washer alone does NOT advance Step 3", ui.get_tutorial_step_id() == &"step_03_wash_rice")
	_type_word(ui, "cuci")
	_check("valid washer cuci advances to Step 4 cook_rice", ui.get_tutorial_step_id() == &"step_04_cook_rice")
	_check("Step 4 highlights rice_cooker", ui.get_tutorial_guidance_view().get("target_id", &"") == &"rice_cooker")

	# Negative guard: clicking rice_cooker alone does NOT advance Step 4!
	kitchen.on_interactable_clicked(&"rice_cooker")
	_check("clicking rice_cooker alone does NOT advance Step 4", ui.get_tutorial_step_id() == &"step_04_cook_rice")
	_type_word(ui, "masak")
	_check("rice_cooker produced 5 portions", int(kitchen.get_cooker_output_view(&"rice_cooker").get("portions", 0)) == 5)
	_check("cooking rice advances to Step 5 cook_egg", ui.get_tutorial_step_id() == &"step_05_cook_egg")
	_check("Step 5 mentions 5 porsi nasi lesson", ui.tutorial_body_label.text.contains("5 porsi nasi"))
	_check("Step 5 sub-highlight starts on storage_box for telur", ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")

	# Take telur -> sub-highlight shifts dynamically to stove!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	_check("taking telur shifts Step 5 highlight to stove", ui.get_tutorial_guidance_view().get("target_id", &"") == &"stove")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	_check("frying telur advances to Step 6 assemble_dish", ui.get_tutorial_step_id() == &"step_06_assemble_dish")
	_check("Step 6 highlights plate_rack while holding loose cooked telur", ui.get_tutorial_guidance_view().get("target_id", &"") == &"plate_rack")

	# Two-way plating Route A: held cooked telur + plate_rack -> plate with egg -> highlight shifts to rice_cooker!
	kitchen.on_interactable_clicked(&"plate_rack")
	_check("Step 6 shifts highlight to rice_cooker after placing telur on plate", ui.get_tutorial_guidance_view().get("target_id", &"") == &"rice_cooker")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	_check("assembling Nasi Telor advances to Step 7 serve_customer", ui.get_tutorial_step_id() == &"step_07_serve_customer")
	_check("Step 7 highlights waiting customer table", ui.get_tutorial_guidance_view().get("target_id", &"") == waiting_table_id)

	# Negative guard on Step 7: serving wrong table (empty CLEAN_VACANT) does NOT advance!
	var vacant_tid: StringName = &""
	for tid in service.get_registered_table_ids():
		if int(service.get_table_view(tid).get("state", -1)) == SharedTypes.TableState.CLEAN_VACANT:
			vacant_tid = tid
			break
	if vacant_tid != &"":
		kitchen.on_interactable_clicked(vacant_tid)
		_type_word(ui, "saji")
		_check("serving vacant table fails and keeps Step 7 active", ui.get_tutorial_step_id() == &"step_07_serve_customer")

	# Negative guard on Step 7: trying saji with WRONG/incomplete dish keeps Step 7 active and shows hint!
	kitchen.on_interactable_clicked(&"trash") # discard food, empty plate remains
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi") # incomplete plated rice only!
	kitchen.on_interactable_clicked(waiting_table_id)
	_type_word(ui, "saji")
	_check("serving wrong/incomplete dish keeps Step 7 active and shows contextual hint", ui.get_tutorial_step_id() == &"step_07_serve_customer" and ui.tutorial_body_label.text.contains("belum sesuai"))

	# Complete valid Nasi Telor, pick it up from work_table_stage, and serve real waiting table!
	kitchen.on_interactable_clicked(&"work_table_stage") # stages plated nasi
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage") # merges cooked telur onto staged plated nasi
	kitchen.on_interactable_clicked(&"work_table_stage") # picks finished Nasi Telor into hand!
	kitchen.on_interactable_clicked(waiting_table_id)
	_type_word(ui, "saji")
	_check("valid serve advances to Step 8 clean_and_wash", ui.get_tutorial_step_id() == &"step_08_clean_and_wash")

	# Wait until eating completes -> table becomes DIRTY -> Step 8 highlights dirty table!
	for _i in range(60):
		_advance_sim(game_root, 0.5, 0.25)
		if int(service.get_table_view(waiting_table_id).get("state", -1)) == SharedTypes.TableState.DIRTY:
			break
	_check("Step 8 highlights DIRTY table", ui.get_tutorial_guidance_view().get("target_id", &"") == waiting_table_id)

	# Cleaning table alone must keep Step 8 active and shift highlight to washer!
	kitchen.on_interactable_clicked(waiting_table_id)
	_type_word(ui, "bersihkan")
	_check("cleaning table keeps Step 8 active for plate washing", ui.get_tutorial_step_id() == &"step_08_clean_and_wash")
	_check("Step 8 shifts highlight to washer", ui.get_tutorial_guidance_view().get("target_id", &"") == &"washer")

	# Negative guard: clicking washer WITHOUT typing cuci must NOT return plate or advance Step 8!
	kitchen.on_interactable_clicked(&"washer")
	_check("clicking washer alone does NOT wash plate or advance Step 8", kitchen.get_held_item_view().is_empty() and ui.get_tutorial_step_id() == &"step_08_clean_and_wash")

	# Type cuci -> clean plate enters hand -> Step 9 finish_day!
	_type_word(ui, "cuci")
	_check("washing dirty plate returns clean plate to hand", kitchen.get_held_item_view().get("plate_id", &"") != &"")
	_check("washing plate advances to Step 9 finish_day", ui.get_tutorial_step_id() == &"step_09_finish_day")
	_check("Step 9 Selesai button hidden before RESULTS", not ui.tutorial_next_button.visible)

	# Fast-forward remaining service day to RESULTS -> highlights DayResultSidePanel!
	for _i in range(300):
		if game_root.get_phase() == SharedTypes.Phase.RESULTS:
			break
		_advance_sim(game_root, 1.0, 0.25)
	_check("Day 1 settles into RESULTS", game_root.get_phase() == SharedTypes.Phase.RESULTS)
	_check("Step 9 highlights ui_day_result in RESULTS", ui.get_tutorial_guidance_view().get("target_id", &"") == &"ui_day_result")
	_check("Step 9 includes required reminder text", ui.tutorial_body_label.text.contains(REQUIRED_DAY9_REMINDER))
	_check("Step 9 Selesai button visible in RESULTS", ui.tutorial_next_button.visible and ui.tutorial_next_button.text == "Selesai")

	ui.tutorial_next_button.pressed.emit()
	while ui.get_active_feature_tip_id() != &"":
		ui.dismiss_feature_tip()
	_check("completing Step 9 hides banner & guidance highlight", ui.is_tutorial_completed() and not ui.tutorial_banner.visible and not ui.get_tutorial_guidance_view().get("active", false))

	await _cleanup_direct_game_root(game_root)


func _test_precompleted_and_out_of_order_resilience() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController

	# Pre-complete ingredient purchase while still in story / before Step 2!
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	ui.skip_story()
	ui.tutorial_next_button.pressed.emit() # Step 2

	# Must recognize already-owned stock and point to buka (NOT force buying again!).
	_check(
		"Step 2 recognizes already-bought beras & telur and points to ui_start_service",
		ui.get_tutorial_step_id() == &"step_02_prepare_ingredients"
		and ui.get_tutorial_guidance_view().get("target_id", &"") == &"ui_start_service"
	)

	# Start serving and fry telur OUT OF ORDER BEFORE ever taking/washing/cooking rice!
	game_root.start_service_requested()
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage") # stage cooked telur out of the way

	_check("out-of-order egg prep does not break Step 2 highlighting storage_box for beras", ui.get_tutorial_step_id() == &"step_02_prepare_ingredients" and ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")

	# Now do rice flow normally -> must skip Step 5 cook_egg automatically straight to Step 6!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	_check("taking beras advances to Step 3", ui.get_tutorial_step_id() == &"step_03_wash_rice")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	_check("washing rice advances to Step 4", ui.get_tutorial_step_id() == &"step_04_cook_rice")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	_check(
		"already-cooked telur on work_table auto-skips Step 5 straight to Step 6 assemble_dish",
		ui.get_tutorial_step_id() == &"step_06_assemble_dish"
	)
	_check(
		"Step 6 highlights plate_rack to combine with staged telur",
		ui.get_tutorial_guidance_view().get("target_id", &"") == &"plate_rack"
	)

	await _cleanup_direct_game_root(game_root)


func _test_alternate_plating_route_and_unrelated_dirty_table_guard() -> void:
	var game_root := await _spawn_direct_game_root(false)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var service := game_root.get_service_controller() as ServiceController

	# Serve 1 diner FIRST while onboarding is OFF -> wait until diner leaves DIRTY table!
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	game_root.start_service_requested()
	_advance_sim(game_root, 0.5, 0.25)
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage")
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage")
	var pre_tid := ui._find_waiting_table_for_tutorial(false)
	kitchen.on_interactable_clicked(pre_tid)
	_type_word(ui, "saji")
	for _i in range(50):
		_advance_sim(game_root, 0.5, 0.25)
		if int(service.get_table_view(pre_tid).get("state", -1)) == SharedTypes.TableState.DIRTY:
			break

	# Now turn ON / restart tutorial while an old DIRTY table exists AND test Worktable-first plating!
	ui.restart_tutorial()
	_check(
		"old DIRTY table + past rice/egg are NOT treated as proof that current tutorial served customer",
		ui.get_tutorial_step_id() != &"step_08_clean_and_wash"
		and ui.get_tutorial_step_id() != &"step_09_finish_day"
	)

	# Test Worktable-first plating route: stage plate -> add cooked rice -> fry & add telur!
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"work_table_stage") # empty clean plate staged!
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage") # rice merged into staged plate!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	kitchen.on_interactable_clicked(&"work_table_stage") # cooked telur merged into staged plate -> matched Nasi Telor on work_table!

	_check(
		"Worktable-first plating route satisfies Step 6 and advances to Step 7",
		ui.get_tutorial_step_id() == &"step_07_serve_customer"
	)
	_check(
		"Step 7 highlights work_table_stage first when Nasi Telor is staged on table",
		ui.get_tutorial_guidance_view().get("target_id", &"") == &"work_table_stage"
	)

	await _cleanup_direct_game_root(game_root)


func _test_world_click_through_modals_pause_and_multiday_restart() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController
	var cash_before := int(run.get_run_view().get("cash", 0))

	# Pause during StoryDialogueOverlay preserves line_index.
	ui.advance_story()
	var line_idx := int(ui.get_story_state_view().get("line_index", -1))
	game_root.set_paused(true)
	_check("Pause hides story overlay & guidance visually", not ui.story_dialogue_overlay.visible and not ui.get_tutorial_guidance_view().get("active", false))
	game_root.set_paused(false)
	_check("Unpause restores StoryDialogueOverlay at exact line", ui.story_dialogue_overlay.visible and int(ui.get_story_state_view().get("line_index", -1)) == line_idx)

	ui.skip_story()
	ui.tutorial_next_button.pressed.emit() # Step 2 highlighting storage_box
	await process_frame

	# Clicking world target center via real Viewport mouse click selects storage_box (NOT blocked by highlight!).
	var g := ui.get_tutorial_guidance_view()
	var target_rect: Rect2 = g.get("target_rect", Rect2())
	_check("Step 2 target_rect valid on screen", target_rect.size.x >= 20.0 and target_rect.size.y >= 20.0)
	_send_left_click(ui, target_rect.get_center())
	_check("left-clicking highlighted target passes straight through to KitchenController", kitchen.get_selected_target_id() == &"storage_box")

	# Opening EditMenu / Reference / IngredientShop hides guidance highlight & does NOT advance tutorial!
	_check("EditMenu opens from Step 2", ui.open_edit_menu())
	_check("EditMenu hides visual guidance cleanly", not ui.get_tutorial_guidance_view().get("active", false))
	ui.close_edit_menu()
	_check("canceling EditMenu restores highlight without advancing Step 2", ui.get_tutorial_step_id() == &"step_02_prepare_ingredients" and ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")

	# Pause during active tutorial preserves exact step & restores highlight!
	game_root.set_paused(true)
	_check("Pause hides TutorialBanner and visual guidance", not ui.tutorial_banner.visible and not ui.get_tutorial_guidance_view().get("active", false))
	game_root.set_paused(false)
	_check("Unpause restores Step 2 banner and storage_box highlight", ui.tutorial_banner.visible and ui.get_tutorial_step_id() == &"step_02_prepare_ingredients" and ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")

	# Verify focus never stays trapped on tutorial buttons.
	ui.skip_tutorial()
	_check("no BaseButton retains focus after tutorial interaction", not (ui.get_viewport().gui_get_focus_owner() is BaseButton))

	# Advance cleanly to Day 2 / Day 3 and verify Ulangi Tutorial works on Day 2+ without mutating state!
	run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	run.request_ingredient_purchase(&"telur", 1, &"storage_box")
	game_root.start_service_requested()
	for _i in range(300):
		if game_root.get_phase() == SharedTypes.Phase.RESULTS:
			break
		_advance_sim(game_root, 1.0, 0.25)
	_check("continue Day 1 -> Day 2 PLANNING", game_root.request_continue_from_results())
	ui.skip_story() # close Day 2 narrative
	var day2_cash := int(run.get_run_view().get("cash", 0))
	_check("Reference panel opens on Day 2", ui.open_reference())
	ui.reference_restart_button.pressed.emit()
	_check(
		"Ulangi Tutorial on Day 2 keeps tutorial active & non-mutating",
		ui.is_tutorial_active()
		and ui.get_tutorial_step_id() == &"step_01_objective"
		and game_root.get_day_index() == 2
		and int(run.get_run_view().get("cash", -1)) == day2_cash
	)
	_check("Step 1 objective cash unmodified on initial check", cash_before == 100000)

	await _cleanup_direct_game_root(game_root)


func _test_daily_narratives_and_day7_epilogues() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	ui.skip_story()
	ui.skip_tutorial()

	for d in range(2, 8):
		_check("Day %d intro narrative opens once" % d, ui.open_day_narrative(d))
		var sv := ui.get_story_state_view()
		_check("Day %d narrative title non-empty" % d, not str(sv.get("title", "")).is_empty())
		if d == 3:
			_check("Day 3 narrative mentions skripsi customer joke", str(sv.get("text", "")).contains("lagi bikin skripsi"))
		ui.skip_story()
		_check("Day %d narrative does not repeat once shown" % d, not ui.open_day_narrative(d))

	_check("Day 7 WON epilogue opens", ui.open_day_7_epilogue(SharedTypes.DayOutcome.WON))
	ui.advance_story()
	_check("Day 7 WON epilogue carries exact competition lesson", str(ui.get_story_state_view().get("text", "")).contains(REQUIRED_EPILOGUE_MSG))
	await _cleanup_direct_game_root(game_root)

	var gr_lost := await _spawn_direct_game_root(true)
	var ui_lost := gr_lost.get_node("UI") as GameUI
	ui_lost.skip_story()
	_check("Day 7 LOST epilogue opens", ui_lost.open_day_7_epilogue(SharedTypes.DayOutcome.LOST))
	ui_lost.advance_story()
	_check("Day 7 LOST epilogue carries exact competition lesson", str(ui_lost.get_story_state_view().get("text", "")).contains(REQUIRED_EPILOGUE_MSG))
	await _cleanup_direct_game_root(gr_lost)


func _test_day2_to_7_feature_discovery_and_contextual_highlights() -> void:
	var game_root := await _spawn_direct_game_root(true)
	var ui := game_root.get_node("UI") as GameUI
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var run := game_root.get_run_controller() as RunController

	ui.skip_story()
	ui.skip_tutorial()

	# Check fixture shop tip triggers once.
	_check("Fixture Shop opens cleanly", ui.open_fixture_shop(&"slot_utility_01"))
	ui.close_fixture_shop()
	_check("fridge_and_power tip shown once", ui.get_active_feature_tip_id() == &"fridge_and_power" and ui.feature_tip_panel.visible)
	ui.dismiss_feature_tip()

	# Start Day 1 SERVING -> serving_belanja & online_offer + first_driver_pickup tips!
	_check("SERVING starts cleanly", game_root.start_service_requested())
	_check("Ingredient Shop opens during SERVING", ui.open_ingredient_shop(&"storage_box"))
	ui.close_ingredient_shop()
	_check("serving_belanja tip triggered and highlights storage_box", ui.get_active_feature_tip_id() == &"serving_belanja" and ui.get_tutorial_guidance_view().get("target_id", &"") == &"storage_box")
	ui.dismiss_feature_tip()

	# Wait for online_offer tip -> must highlight online_station!
	for _i in range(40):
		_advance_sim(game_root, 0.5, 0.25)
		if ui.has_shown_feature_tip(&"online_offer"):
			break
	_check("online_offer tip triggers automatically and highlights online_station", ui.get_active_feature_tip_id() == &"online_offer" and ui.get_tutorial_guidance_view().get("target_id", &"") == &"online_station")

	# Accept online offer -> first_driver_pickup queues and highlights the spawned driver once online_offer dismissed!
	kitchen.on_interactable_clicked(&"online_station")
	_type_word(ui, "terima")
	ui.dismiss_feature_tip()
	var g_drv := ui.get_tutorial_guidance_view()
	_check(
		"first_driver_pickup tip appears after terima and highlights spawned pickup driver",
		ui.get_active_feature_tip_id() == &"first_driver_pickup"
		and String(g_drv.get("target_id", &"")).begins_with("drv_")
	)
	ui.dismiss_feature_tip()

	# Verify Day 2 unlock triggers recipe_unlock & Day 3+ unlocks veggie tip cleanly.
	for _i in range(300):
		if game_root.get_phase() == SharedTypes.Phase.RESULTS:
			break
		_advance_sim(game_root, 1.0, 0.25)
	ui.dismiss_feature_tip() # clear demand_and_debt if shown
	game_root.request_continue_from_results() # Day 2
	ui.skip_story()
	_check("Day 2 recipe_unlock tip discovered automatically", ui.has_shown_feature_tip(&"recipe_unlock"))
	ui.dismiss_feature_tip()

	# Advance Day 2 -> Day 3 (nasi_komplit unlocks with sayur!) -> check potong_veggie!
	game_root.start_service_requested()
	for _i in range(300):
		if game_root.get_phase() == SharedTypes.Phase.RESULTS:
			break
		_advance_sim(game_root, 1.0, 0.25)
	ui.dismiss_feature_tip()
	game_root.request_continue_from_results() # Day 3
	ui.skip_story()
	var rv3 := run.get_run_view()
	_check("Day 3 unlocks >= 3 recipes", (rv3.get("unlocked_recipe_ids", []) as Array).size() >= 3)
	_check("potong_veggie feature tip discovered when sayur recipe unlocked", ui.has_shown_feature_tip(&"potong_veggie"))

	await _cleanup_direct_game_root(game_root)


func _test_responsive_layout_bounds() -> void:
	for vp_size in [Vector2(640.0, 360.0), Vector2(480.0, 270.0)]:
		var game_root := await _spawn_direct_game_root(true)
		var ui := game_root.get_node("UI") as GameUI
		var tag := "%dx%d" % [int(vp_size.x), int(vp_size.y)]
		var hud_right := ui.left_hud_region.size.x
		var world_rect := Rect2(hud_right, 0.0, vp_size.x - hud_right, vp_size.y)

		ui._layout_onboarding_overlays(vp_size, world_rect)
		await process_frame
		_assert_control_inside_viewport("StoryPopup inside bounds at " + tag, ui.story_popup, vp_size, hud_right)

		ui.skip_story()
		ui.tutorial_next_button.pressed.emit() # Step 2 -> storage_box highlight active!
		ui._queue_feature_tip(&"online_offer")
		ui._layout_onboarding_overlays(vp_size, world_rect)
		await process_frame
		_assert_control_inside_viewport("TutorialHelpButton inside bounds at " + tag, ui.tutorial_help_button, vp_size, hud_right)
		_assert_control_inside_viewport("TutorialBanner inside bounds at " + tag, ui.tutorial_banner, vp_size, hud_right)
		_assert_control_inside_viewport("FeatureTipPanel inside bounds at " + tag, ui.feature_tip_panel, vp_size, hud_right)

		var g := ui.get_tutorial_guidance_view()
		var c_rect: Rect2 = g.get("callout_rect", Rect2())
		_check(
			"Guidance badge & target inside bounds at " + tag,
			bool(g.get("active", false))
			and c_rect.position.x >= hud_right - 1.0
			and c_rect.end.x <= vp_size.x + 1.0
			and c_rect.end.y <= vp_size.y + 1.0
		)

		ui.open_reference()
		ui._layout_onboarding_overlays(vp_size, world_rect)
		await process_frame
		_assert_control_inside_viewport("ReferencePopup inside bounds at " + tag, ui.reference_popup, vp_size, hud_right)
		ui.close_reference()
		await _cleanup_direct_game_root(game_root)


func _test_pegawai_asset_and_runtime_unused() -> void:
	var tex := load("res://assets/art/characters/pegawai.png") as Texture2D
	_check("pegawai.png loads as Texture2D", tex != null)
	if tex != null:
		var img := tex.get_image()
		_check("pegawai.png dimensions are 14x31", img.get_size() == Vector2i(14, 31))
		_check("pegawai.png format is RGBA8", img.get_format() == Image.FORMAT_RGBA8)
		var partial_alpha := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var a := img.get_pixel(x, y).a
				if a > 0.01 and a < 0.99:
					partial_alpha += 1
		_check("pegawai.png has 0 partial alpha pixels", partial_alpha == 0)

	var game_root := await _spawn_direct_game_root(false)
	var world := game_root.get_node("World") as WorldMap
	var employee_runtime_nodes := world.find_children("*Pegawai*", "", true, false)
	_check("pegawai.png has no spawned employee runtime NPC node", employee_runtime_nodes.is_empty())
	await _cleanup_direct_game_root(game_root)
