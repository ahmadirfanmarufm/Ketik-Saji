extends SceneTree
## Verification for Main Menu initial startup flow (M7-P0) and real Display/Resolution
## application (Windowed <-> Fullscreen, 480x270 / 640x360 / 1280x720 / 1600x900, VSync,
## ConfigFile startup persistence, and Settings feedback).
## Runs Main Menu + state/persistence assertions under `--headless` AND real DisplayServer
## window assertions + PNG captures when launched with a visible GL window (`--capture-dir=...`).

var _fails: int = 0
var _capture_dir: String = ""


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.substr("--capture-dir=".length())
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)

	await _test_main_menu_startup_and_state_safety()
	await _test_display_mode_resolution_and_persistence()
	for _f in range(12):
		await process_frame
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _save_capture(filename: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("%s/%s" % [_capture_dir, filename])


func _click_ctrl(ctrl: Control) -> void:
	var r := ctrl.get_global_rect()
	var pt := r.get_center()
	var vp := ctrl.get_viewport()
	if vp == null:
		return
	var p := InputEventMouseButton.new()
	p.button_index = MOUSE_BUTTON_LEFT
	p.pressed = true
	p.position = pt
	p.global_position = pt
	vp.push_input(p, true)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = pt
	u.global_position = pt
	vp.push_input(u, true)


func _test_main_menu_startup_and_state_safety() -> void:
	var err := change_scene_to_file("res://scenes/main/game_root.tscn")
	_check("main_scene loads cleanly via change_scene_to_file", err == OK)
	await process_frame
	await process_frame
	await process_frame

	var g := current_scene as GameRoot
	var ui := g.get_node("UI") as GameUI
	var run := g.get_run_controller() as RunController
	var audio := g.get_audio_controller() as GameAudio
	ui.set_exit_quit_disabled_for_test(true)

	# 1. Fresh launch -> Main Menu shown, zero gameplay started.
	_check(
		"Fresh boot lands on visible MainMenuOverlay with zero run/story/HUD started",
		g.is_in_main_menu()
		and ui.is_main_menu_open()
		and not run.is_run_started()
		and not ui.is_story_open()
		and not ui.is_reference_open()
		and not ui.left_hud_region.visible
		and audio.is_bgm_playing()
	)
	await _save_capture("01_boot_main_menu.png")

	# 2. Main Menu -> Settings -> Back -> Main Menu without starting gameplay.
	ui.main_menu_settings_button.pressed.emit()
	await process_frame
	_check(
		"Main Menu Pengaturan opens Settings without starting a run",
		ui.is_settings_open() and g.is_in_main_menu() and not run.is_run_started()
	)
	await _save_capture("02_settings_from_main_menu.png")
	ui.settings_close_button.pressed.emit()
	await process_frame
	_check(
		"Closing Settings returns to Main Menu without starting Story/Planning",
		not ui.is_settings_open()
		and ui.is_main_menu_open()
		and g.is_in_main_menu()
		and not run.is_run_started()
		and not ui.is_story_open()
	)
	await _save_capture("03_back_to_main_menu.png")

	# 3. Main Menu -> Keluar -> Batal returns cleanly to Main Menu.
	ui.main_menu_quit_button.pressed.emit()
	await process_frame
	_check("Main Menu Keluar opens ExitConfirmOverlay", ui.is_exit_confirm_open())
	ui.exit_confirm_cancel_button.pressed.emit()
	await process_frame
	_check("Canceling ExitConfirm returns to Main Menu", not ui.is_exit_confirm_open() and ui.is_main_menu_open())

	# 4. Main Menu -> Play -> opening story -> CARA MAIN -> Day 1 Planning.
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	await process_frame
	_check(
		"Play starts fresh Day 1 run and opening story",
		not g.is_in_main_menu()
		and not ui.is_main_menu_open()
		and run.is_run_started()
		and g.get_day_index() == 1
		and ui.is_story_open()
	)
	ui.skip_story()
	await process_frame
	_check("Skipping opening story opens single-panel CARA MAIN", ui.is_reference_open())
	ui.close_reference()
	await process_frame
	_check(
		"Closing CARA MAIN enters active Day 1 Planning with Rp 100k",
		not ui.is_reference_open()
		and not ui.is_modal_blocking()
		and g.get_phase() == SharedTypes.Phase.PLANNING
		and int(run.get_run_view().get("cash", 0)) == 100000
	)

	# Mutate run state (buy ingredient + advance to Day 2) -> Day Result -> Main Menu -> Play again -> clean Day 1!
	_check("mutate Day 1 cash by purchasing 1 telur", run.request_ingredient_purchase(&"telur", 1, &"storage_box"))
	g.start_service_requested()
	var service := g.get_service_controller() as ServiceController
	service._day_queue_remaining = 0
	service._outside_dine_in_queue.clear()
	service._in_shop_dine_in_count = 0
	service._online_orders_open.clear()
	g.request_close_if_drained()
	await process_frame
	ui.result_menu_button.pressed.emit()
	await process_frame
	_check(
		"Returning from Day Result opens MainMenuOverlay and resets idle state",
		g.is_in_main_menu() and ui.is_main_menu_open() and not run.is_run_started()
	)
	await _save_capture("09_returned_to_main_menu.png")

	# Play again -> verify fresh clean Day 1 (cash restored to Rp 100k, day 1, story restarts).
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	await process_frame
	_check(
		"Play again after Menu utama launches clean Day 1 run with zero stale cash/day state",
		not g.is_in_main_menu()
		and run.is_run_started()
		and g.get_day_index() == 1
		and int(run.get_run_view().get("cash", 0)) == 100000
		and ui.is_story_open()
	)

	unload_current_scene()
	await process_frame
	await process_frame


func _test_display_mode_resolution_and_persistence() -> void:
	var cfg_path := "res://.godot/test_display_m7.cfg"
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))

	var is_real_window := DisplayServer.get_name() != "headless"
	var err := change_scene_to_file("res://scenes/main/game_root.tscn")
	_check("reload game_root for display tests", err == OK)
	await process_frame
	await process_frame

	var g := current_scene as GameRoot
	var ui := g.get_node("UI") as GameUI
	var audio := g.get_audio_controller() as GameAudio
	audio.set_settings_path_for_test(cfg_path)
	if not is_real_window:
		audio.set_display_apply_enabled_for_test(false)

	ui.open_settings(false)
	await process_frame

	# Switch Windowed -> Fullscreen via actual UI button click!
	_click_ctrl(ui.display_mode_button)
	await process_frame
	await process_frame
	var snap := audio.get_applied_display_snapshot()
	var fs_ok := bool(snap["fullscreen"]) and ui.display_mode_button.text == "Layar Penuh" and ui.resolution_option_button.disabled
	if is_real_window:
		var ds_mode := DisplayServer.window_get_mode()
		fs_ok = fs_ok and (
			ds_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
			or ds_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		)
	_check("Settings Layar Penuh applies actual fullscreen and clarifies resolution scope in UI", fs_ok and ui.display_status_label.text.contains("Layar Penuh"))
	await _save_capture("04_fullscreen.png")

	# Switch Fullscreen -> Windowed repeatedly & verify Windowed resolution + screen bounds!
	_click_ctrl(ui.display_mode_button)
	await process_frame
	await process_frame
	_click_ctrl(ui.display_mode_button)
	await process_frame
	await process_frame
	_click_ctrl(ui.display_mode_button)
	await process_frame
	await process_frame
	snap = audio.get_applied_display_snapshot()
	var win_back_ok := not bool(snap["fullscreen"]) and ui.display_mode_button.text == "Berjendela" and not ui.resolution_option_button.disabled
	if is_real_window:
		win_back_ok = win_back_ok and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	_check("Repeated Fullscreen <-> Berjendela returns cleanly to Windowed mode", win_back_ok)

	# Exercise ALL 4 Windowed resolutions and check DisplayServer.window_get_size() on GL window!
	var cap_names := ["05_windowed_480x270.png", "06_windowed_640x360.png", "07_windowed_1280x720.png", "08_windowed_1600x900.png"]
	for idx in range(ui.resolution_option_button.item_count):
		var target_res := ui.resolution_option_button.get_item_metadata(idx) as Vector2i
		ui.resolution_option_button.select(idx)
		ui.resolution_option_button.item_selected.emit(idx)
		await process_frame
		await process_frame
		snap = audio.get_applied_display_snapshot()
		var ok := bool(snap["applied_ok"]) and not bool(snap["fullscreen"])
		if is_real_window:
			var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var expected := Vector2i(mini(target_res.x, usable.size.x), mini(target_res.y, usable.size.y))
			var actual_sz := DisplayServer.window_get_size()
			var actual_pos := DisplayServer.window_get_position()
			ok = (
				ok
				and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
				and actual_sz == expected
				and actual_pos.x >= usable.position.x - 1
				and actual_pos.y >= usable.position.y - 1
				and actual_pos.x + actual_sz.x <= usable.end.x + 1
				and actual_pos.y + actual_sz.y <= usable.end.y + 1
			)
		_check("Windowed resolution %dx%d applies & stays within usable screen bounds" % [target_res.x, target_res.y], ok)
		await _save_capture(cap_names[idx])

	# Toggle VSync Off & verify applied state + ConfigFile reload!
	_click_ctrl(ui.vsync_toggle_button)
	await process_frame
	var vsync_off_ok := not audio.is_vsync_enabled() and ui.vsync_toggle_button.text == "Mati"
	if is_real_window:
		vsync_off_ok = vsync_off_ok and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED
	_check("VSync toggle Mati updates actual DisplayServer VSync mode", vsync_off_ok)

	# Switch back to 640x360 + reload saved settings onto a fresh GameRoot scene!
	ui.resolution_option_button.select(1)
	ui.resolution_option_button.item_selected.emit(1)
	await process_frame
	unload_current_scene()
	await process_frame
	await process_frame

	change_scene_to_file("res://scenes/main/game_root.tscn")
	await process_frame
	await process_frame
	var g2 := current_scene as GameRoot
	var ui2 := g2.get_node("UI") as GameUI
	var audio2 := g2.get_audio_controller() as GameAudio
	audio2.set_settings_path_for_test(cfg_path)
	if not is_real_window:
		audio2.set_display_apply_enabled_for_test(false)
	_check("Reloading saved display config applies 640x360 + VSync Mati", audio2.reload_settings_from_disk())
	await process_frame
	await process_frame
	var reload_ok := audio2.get_resolution() == Vector2i(640, 360) and not audio2.is_vsync_enabled()
	if is_real_window:
		reload_ok = reload_ok and DisplayServer.window_get_size() == Vector2i(640, 360) and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED
	_check("Saved 640x360 + VSync Mati restored cleanly onto real window", reload_ok)

	# Reset Default while in Fullscreen restores Windowed 1280x720 + VSync Aktif!
	ui2.open_settings(false)
	await process_frame
	_click_ctrl(ui2.display_mode_button)
	await process_frame
	await process_frame
	_click_ctrl(ui2.settings_reset_button)
	await process_frame
	await process_frame
	var reset_ok := not audio2.is_fullscreen_enabled() and audio2.get_resolution() == Vector2i(1280, 720) and audio2.is_vsync_enabled()
	if is_real_window:
		reset_ok = (
			reset_ok
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
			and DisplayServer.window_get_size() == Vector2i(1280, 720)
			and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
		)
	_check("Reset Default restores Windowed 1280x720 + VSync Aktif on real window", reset_ok)

	unload_current_scene()
	await process_frame
	await process_frame
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
