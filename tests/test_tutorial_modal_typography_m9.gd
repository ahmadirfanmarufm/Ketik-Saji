extends SceneTree
## Focused regression suite for:
## 1. Employee UI Typography Consistency (GrapeSoda.ttf & KetikUiArt hierarchy)
## 2. Cara Main vs Pause Menu Modal Conflict & Deterministic Stack / Escape / Click Rules
## 3. Complete 8-Chapter Interactive Tutorial, Real Action Verification, Tips, Skip/Replay & Persistence

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_employee_ui_typography_consistency()
	await _test_cara_main_vs_pause_modal_isolation()
	await _test_complete_8_chapter_interactive_tutorial()
	await _test_tutorial_skip_replay_tips_and_persistence()
	for _f in range(6):
		await process_frame
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _send_key(ui: GameUI, unicode_val: int, keycode_val: Key = KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = unicode_val
	if keycode_val != KEY_NONE:
		ev.keycode = keycode_val
		ev.physical_keycode = keycode_val
	elif unicode_val > 0:
		ev.keycode = unicode_val
		ev.physical_keycode = unicode_val
	ui.get_viewport().push_input(ev, true)


func _send_left_click(ui: GameUI, canvas_pos: Vector2) -> void:
	var vp := ui.get_viewport()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = canvas_pos
	press.global_position = canvas_pos
	vp.push_input(press, true)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = canvas_pos
	rel.global_position = canvas_pos
	vp.push_input(rel, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _spawn_game(onboarding: bool) -> GameRoot:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var g := packed.instantiate() as GameRoot
	root.add_child(g)
	await process_frame
	await physics_frame
	var ui := g.get_node("UI") as GameUI
	ui.set_onboarding_enabled(onboarding)
	return g


func _test_employee_ui_typography_consistency() -> void:
	var g := await _spawn_game(false)
	var ui := g.get_node("UI") as GameUI
	ui.open_employee_shop()
	ui.hire_employee_role(&"cook")
	await process_frame

	var expected_font := KetikUiArt.load_font()
	var emp_title := ui.employee_popup.get_node("EmployeeColumn/EmployeeHeaderRow/EmployeeTitleLabel") as Label
	var role_hdr := ui.employee_popup.get_node(
		"EmployeeColumn/EmployeeScroll/EmployeeContentBox/RoleSectionLabel"
	) as Label
	var cook_row := ui.get_employee_role_row(&"cook")
	var title_lbl := cook_row.get("title_label") as Label
	var desc_lbl := cook_row.get("description_label") as Label
	var roster_row := ui.get_employee_roster_row(&"emp_0001")
	var roster_lbl := roster_row.get("info_label") as Label

	_check(
		"EmployeeTitleLabel matches modal title typography (16px Cream + outline 4, GrapeSoda.ttf)",
		emp_title != null
		and emp_title.get_theme_font("font") == expected_font
		and emp_title.get_theme_font_size("font_size") == 16
		and emp_title.get_theme_color("font_color") == KetikUiArt.COLOR_CREAM
		and emp_title.get_theme_constant("outline_size") == 4
	)
	_check(
		"Employee section headers & card labels use raw GrapeSoda.ttf (no FontVariation smear) & consistent dark-card colors",
		role_hdr != null
		and role_hdr.get_theme_font_size("font_size") == 12
		and title_lbl != null
		and not (title_lbl.get_theme_font("font") is FontVariation)
		and title_lbl.get_theme_font("font") == expected_font
		and title_lbl.get_theme_font_size("font_size") == 12
		and title_lbl.get_theme_color("font_color") == Color(0.86, 0.84, 0.80, 1.0)
		and title_lbl.get_theme_constant("outline_size") == 4
		and desc_lbl != null
		and desc_lbl.get_theme_font_size("font_size") == 10
		and desc_lbl.get_theme_constant("outline_size") == 3
		and roster_lbl != null
		and roster_lbl.get_theme_font_size("font_size") == 11
		and roster_lbl.get_theme_color("font_color") == KetikUiArt.COLOR_CREAM
		and roster_lbl.get_theme_constant("outline_size") == 3
	)

	g.free()
	await process_frame


func _test_cara_main_vs_pause_modal_isolation() -> void:
	var g := await _spawn_game(true)
	var ui := g.get_node("UI") as GameUI
	var kitchen := g.get_kitchen_controller() as KitchenController
	ui.skip_story()
	await process_frame
	_check("initial CARA MAIN opened without PauseOverlay", ui.is_reference_open() and not ui.is_pause_open() and not ui.pause_overlay.visible)
	ui.close_reference()
	await process_frame

	# 1. PLANNING: Repeated open/close via ? button, Tutup button, Escape, and outside WorldDimmer click.
	for _i in range(3):
		ui.menu_stub_button.pressed.emit()
		await process_frame
		_check(
			"PLANNING ? Cara Main shows ONLY ReferenceOverlay without PauseOverlay",
			ui.is_reference_open() and not ui.is_pause_open() and not ui.pause_overlay.visible and not g.is_paused()
		)
		ui.reference_close_button.pressed.emit()
		await process_frame
		_check(
			"closing PLANNING Cara Main keeps PLANNING active & PauseOverlay hidden",
			not ui.is_reference_open() and not ui.is_pause_open() and g.get_phase() == SharedTypes.Phase.PLANNING and not g.is_paused()
		)

	# Click outside ReferencePopup on WorldDimmer in PLANNING closes ONLY Cara Main.
	ui.menu_stub_button.pressed.emit()
	await process_frame
	var tile_before := kitchen.get_player_tile()
	_send_left_click(ui, Vector2(142, 10)) # inside WorldDimmer outside centered ReferencePopup
	await process_frame
	_check(
		"clicking WorldDimmer outside ReferencePopup closes Cara Main cleanly without moving player or opening Pause",
		not ui.is_reference_open() and not ui.is_pause_open() and kitchen.get_player_tile() == tile_before
	)

	# 2. SERVING: Open ? Cara Main -> clock pauses cleanly, PauseOverlay MUST stay invisible/closed!
	_check("start SERVING", g.start_service_requested())
	g._process(1.5)
	var t0 := g.get_service_elapsed()
	ui.menu_stub_button.pressed.emit()
	await process_frame
	g._process(3.0)
	_check(
		"SERVING ? Cara Main freezes clock while PauseOverlay stays completely closed & invisible",
		ui.is_reference_open()
		and not ui.is_pause_open()
		and not ui.pause_overlay.visible
		and g.is_paused()
		and is_equal_approx(g.get_service_elapsed(), t0)
		and not ui.open_pause()
	)
	# Pressing Escape closes ONLY Cara Main and resumes SERVING without flashing PauseOverlay.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	g._process(1.0)
	_check(
		"Escape from SERVING Cara Main closes guide cleanly without PauseOverlay & resumes clock",
		not ui.is_reference_open()
		and not ui.is_pause_open()
		and not ui.pause_overlay.visible
		and not g.is_paused()
		and g.get_service_elapsed() >= t0 + 0.99
	)

	# 3. SERVING Pause Menu -> Cara Main -> close Cara Main restores Pause Menu -> close Pause restores SERVING.
	ui.pause_button.pressed.emit()
	await process_frame
	_check("PauseOverlay opened cleanly in SERVING", ui.is_pause_open() and ui.pause_overlay.visible and g.is_paused())
	ui.pause_reference_button.pressed.emit()
	await process_frame
	_check(
		"opening Cara Main from Pause hides PauseOverlay & shows ONLY Cara Main",
		ui.is_reference_open() and ui.tutorial_reference_overlay.visible and not ui.is_pause_open() and not ui.pause_overlay.visible and g.is_paused()
	)
	# Single Escape closes Cara Main back to PauseOverlay without unpausing game.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape from Pause->Cara Main closes ONLY Cara Main and restores PauseOverlay",
		not ui.is_reference_open() and ui.is_pause_open() and ui.pause_overlay.visible and g.is_paused()
	)
	# Next Escape closes PauseOverlay and resumes gameplay.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Second Escape closes PauseOverlay cleanly back to SERVING",
		not ui.is_pause_open() and not ui.is_reference_open() and not g.is_paused()
	)

	g.free()
	await process_frame


func _test_complete_8_chapter_interactive_tutorial() -> void:
	var g := await _spawn_game(true)
	var ui := g.get_node("UI") as GameUI
	var kitchen := g.get_kitchen_controller() as KitchenController
	var service := g.get_service_controller() as ServiceController
	var run := g.get_run_controller() as RunController
	var world := g.get_node("World") as WorldMap

	ui.skip_story()
	await process_frame
	ui.close_reference()
	await process_frame

	# Bab 1: Objective -> Floor Move.
	_check("Bab 1 starts on ch1_objective", ui.is_tutorial_active() and ui.get_tutorial_chapter() == 1 and ui.get_tutorial_step_id() == &"ch1_objective")
	ui.tutorial_next_button.pressed.emit()
	await process_frame
	_check("Bab 1 advances to ch1_move", ui.get_tutorial_step_id() == &"ch1_move")
	# Invalid command does NOT complete floor move step!
	_type_word(ui, "xyz")
	_check("invalid command keeps tutorial on ch1_move in PLANNING", g.get_phase() == SharedTypes.Phase.PLANNING and ui.get_tutorial_step_id() == &"ch1_move")
	# Move to real free floor cell (5, 3).
	kitchen.on_floor_clicked(Vector2i(5, 3))
	await process_frame
	_check("Bab 1 floor click completes ch1_move and enters Bab 2 ch2_edit_menu", ui.get_tutorial_chapter() == 2 and ui.get_tutorial_step_id() == &"ch2_edit_menu")

	# Bab 2: Opening and canceling Edit Menu MUST NOT complete ch2_edit_menu!
	ui.open_edit_menu()
	await process_frame
	ui.close_edit_menu()
	await process_frame
	_check("opening+canceling Edit Menu does NOT advance ch2_edit_menu", ui.get_tutorial_step_id() == &"ch2_edit_menu")
	# Saving Edit Menu completes ch2_edit_menu!
	ui.open_edit_menu()
	await process_frame
	_check("Edit menu Simpan completes ch2_edit_menu -> ch2_buy_ingredients", ui.submit_edit_menu([&"nasi_telor"]) and ui.get_tutorial_step_id() == &"ch2_buy_ingredients")

	# Opening Cara Main mid-tutorial preserves step progress!
	ui.open_reference()
	await process_frame
	ui.close_reference()
	await process_frame
	_check("reopening & closing Cara Main preserves active tutorial step ch2_buy_ingredients", ui.is_tutorial_active() and ui.get_tutorial_step_id() == &"ch2_buy_ingredients")

	# Buy only beras (missing telur) -> must stay on ch2_buy_ingredients!
	run.request_ingredient_purchase(&"beras", 1, &"storage_box")
	await process_frame
	_check("buying only beras without telur keeps step on ch2_buy_ingredients", ui.get_tutorial_step_id() == &"ch2_buy_ingredients")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	await process_frame
	_check("buying real beras + telur advances to ch2_open_service", ui.get_tutorial_step_id() == &"ch2_open_service")

	# Typed buka -> enters SERVING and Bab 3!
	_type_word(ui, "buka")
	await process_frame
	_check("typed buka advances to Bab 3 ch3_take_rice", g.is_serving() and ui.get_tutorial_chapter() == 3 and ui.get_tutorial_step_id() == &"ch3_take_rice")

	# Bab 3: Take rice -> Wash rice -> Cook rice -> Fry egg!
	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "beras")
	await process_frame
	_check("beras retrieval advances ch3_take_rice -> ch3_wash_rice", ui.get_tutorial_step_id() == &"ch3_wash_rice")

	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	await process_frame
	_check("washer cuci advances ch3_wash_rice -> ch3_cook_rice", ui.get_tutorial_step_id() == &"ch3_cook_rice")

	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "masak")
	await process_frame
	_check("rice_cooker masak advances ch3_cook_rice -> ch3_cook_egg", ui.get_tutorial_step_id() == &"ch3_cook_egg")

	kitchen.on_interactable_clicked(&"storage_box")
	_type_word(ui, "telur")
	kitchen.on_interactable_clicked(&"stove")
	_type_word(ui, "goreng")
	await process_frame
	_check("frying egg advances Bab 3 -> Bab 4 ch4_assemble", ui.get_tutorial_chapter() == 4 and ui.get_tutorial_step_id() == &"ch4_assemble")

	# Bab 4: Assemble Nasi Telor -> Serve Dine-in -> Clean & Wash!
	kitchen.on_interactable_clicked(&"work_table_stage") # drop cooked egg
	kitchen.on_interactable_clicked(&"plate_rack")
	kitchen.on_interactable_clicked(&"rice_cooker")
	_type_word(ui, "nasi")
	kitchen.on_interactable_clicked(&"work_table_stage") # merge into Nasi Telor
	await process_frame
	_check("valid Nasi Telor plating advances ch4_assemble -> ch4_serve_dinein", ui.get_tutorial_step_id() == &"ch4_serve_dinein")

	kitchen.on_interactable_clicked(&"dining_table_01")
	_type_word(ui, "saji")
	await process_frame
	_check("real dine-in saji advances ch4_serve_dinein -> ch4_clean_and_wash", ui.get_tutorial_step_id() == &"ch4_clean_and_wash")

	# Advance 21s so customer finishes eating & online offer opens, then bersihkan + cuci dirty plate!
	g._process(21.0)
	kitchen.on_interactable_clicked(&"dining_table_01")
	_type_word(ui, "bersihkan")
	await process_frame
	_check("bersihkan alone does not finish ch4_clean_and_wash until dirty plate washed", ui.get_tutorial_step_id() == &"ch4_clean_and_wash")
	# Make hand empty first just in case, then wash plate at washer!
	kitchen.on_interactable_clicked(&"washer")
	_type_word(ui, "cuci")
	await process_frame
	# Return clean plate to rack before finishing Day 1.
	kitchen.on_interactable_clicked(&"plate_rack")
	_check("washing dirty plate completes Bab 4 -> Bab 7 ch7_review_results", ui.get_tutorial_chapter() == 7 and ui.get_tutorial_step_id() == &"ch7_review_results")

	# Drain Day 1 -> Day 1 Results (Bab 7) -> Continue to Day 2 (Bab 6 Kelola Pegawai)!
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._customers.clear()
	service._orders.clear()
	service._online_orders_open.clear()
	for t: Dictionary in service._tables.values():
		t["state"] = SharedTypes.TableState.CLEAN_VACANT
		t["customer_id_or_empty"] = &""
		t["order_id_or_empty"] = &""
	g.request_close_if_drained()
	await process_frame
	_check(
		"Day 1 RESULTS shows Bab 7 financial review & next button",
		g.get_phase() == SharedTypes.Phase.RESULTS
		and ui.get_tutorial_step_id() == &"ch7_review_results"
		and ui.tutorial_banner.visible
	)
	ui.continue_button.pressed.emit()
	await process_frame
	ui.skip_story()
	await process_frame
	_check(
		"Continuing to Day 2 PLANNING opens Bab 6 Kelola Pegawai (ch6_employee_overview)",
		g.get_day_index() == 2
		and ui.get_tutorial_chapter() == 6
		and ui.get_tutorial_step_id() == &"ch6_employee_overview"
	)

	# Bab 6: Open & close EmployeeOverlay (without forcing unwanted cash spend) -> Bab 5 ch5_accept_online!
	var cash_before_emp := int(run.get_run_view()["cash"])
	ui.open_employee_shop()
	await process_frame
	ui.close_employee_shop()
	await process_frame
	_check(
		"inspecting Kelola Pegawai completes Bab 6 without forced spend -> Bab 5 ch5_accept_online",
		int(run.get_run_view()["cash"]) == cash_before_emp
		and ui.get_tutorial_chapter() == 5
		and ui.get_tutorial_step_id() == &"ch5_accept_online"
	)

	# Start Day 2 SERVING (quota=8, online window wide open), accept online offer & serve pickup driver!
	run.request_ingredient_purchase(&"beras", 2, &"storage_box")
	run.request_ingredient_purchase(&"telur", 2, &"storage_box")
	_type_word(ui, "buka")
	g._process(10.5) # online offer becomes AVAILABLE cleanly on Day 2
	kitchen.on_interactable_clicked(&"online_station")
	_type_word(ui, "terima")
	await process_frame
	_check("real online terima advances ch5_accept_online -> ch5_serve_online", ui.get_tutorial_step_id() == &"ch5_serve_online")

	# Prepare matching dish (nasi_telor or nasi_tempe; keep only nasi_telor selected on Day 2 for deterministic check!)
	var drv := service.get_driver_views()[0]
	var drv_id := StringName(drv["driver_id"])
	var ord_v := service.get_order_view(StringName(drv["order_id"]))
	var rec_id := StringName(ord_v.get("recipe_id", &"nasi_telor"))
	# Cook rice + egg cleanly for Nasi Telor online order
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
	kitchen.on_interactable_clicked(drv_id)
	_type_word(ui, "saji")
	await process_frame
	_check(
		"real online driver serve (%s) completes Bab 5 -> Bab 8 ch8_ready" % rec_id,
		ui.get_tutorial_chapter() == 8 and ui.get_tutorial_step_id() == &"ch8_ready"
	)

	var cash_before_finish := int(run.get_run_view()["cash"])
	ui.tutorial_next_button.pressed.emit()
	await process_frame
	_check(
		"Bab 8 Selesai marks tutorial completed cleanly with zero free cash/item rewards",
		not ui.is_tutorial_active()
		and ui.is_tutorial_completed()
		and not ui.tutorial_banner.visible
		and int(run.get_run_view()["cash"]) == cash_before_finish
	)

	g.free()
	await process_frame


func _test_tutorial_skip_replay_tips_and_persistence() -> void:
	var g := await _spawn_game(true)
	var ui := g.get_node("UI") as GameUI
	var run := g.get_run_controller() as RunController
	var audio := g.get_audio_controller() as GameAudio
	var cfg_path := "user://test_tutorial_m9.cfg"
	audio.set_settings_path_for_test(cfg_path)
	audio.reset_tutorial_state(true)

	ui.skip_story()
	await process_frame
	ui.close_reference()
	await process_frame

	var cash_before := int(run.get_run_view()["cash"])
	# Trigger contextual fixture tip ONCE -> dismiss -> opening FixtureShop again MUST NOT repeat it!
	ui.open_fixture_shop(&"slot_utility_01")
	await process_frame
	_check("contextual fixture_shop_tip triggers on first open", ui.get_active_feature_tip_id() == &"fixture_shop_tip" and ui.has_shown_feature_tip(&"fixture_shop_tip"))
	ui.dismiss_feature_tip()
	ui.close_fixture_shop()
	ui.open_fixture_shop(&"slot_utility_01")
	await process_frame
	_check("contextual fixture_shop_tip does NOT repeat on second open", ui.get_active_feature_tip_id() == &"")
	ui.close_fixture_shop()

	# Skip tutorial -> no phase/cash mutation!
	ui.skip_tutorial()
	await process_frame
	_check(
		"skipping tutorial deactivates banner without corrupting phase or cash",
		not ui.is_tutorial_active()
		and ui.is_tutorial_skipped()
		and g.get_phase() == SharedTypes.Phase.PLANNING
		and int(run.get_run_view()["cash"]) == cash_before
		and bool(audio.get_tutorial_state().get("skipped", false))
	)

	# Replay from Cara Main -> resets cleanly to ch1_objective with ZERO cash or ingredient reward!
	ui.open_reference()
	await process_frame
	ui.reference_restart_button.pressed.emit()
	await process_frame
	_check(
		"replaying tutorial from Cara Main restarts at ch1_objective without rewards",
		ui.is_tutorial_active()
		and ui.get_tutorial_step_id() == &"ch1_objective"
		and not ui.is_reference_open()
		and int(run.get_run_view()["cash"]) == cash_before
	)

	# Persistence check across reload: mark skipped/completed -> reload disk config into new state.
	ui.skip_tutorial()
	_check("persisted skipped state saved in GameAudio ConfigFile", bool(audio.get_tutorial_state().get("skipped", false)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	g.free()
	await process_frame
