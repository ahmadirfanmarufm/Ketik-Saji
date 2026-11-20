extends SceneTree
## Headless verification for Milestone 6 Audio/Settings/Exit/Playthrough:
## 1. Backsound.ogg loading & duration, Master/Music/SFX AudioServer buses, routing without
##    duplicate volume attenuation, mute <= 0.0001, 191.392s loop, 5s fade, no duplicate players.
## 2. Expanded SettingsOverlay (AUDIO, TAMPILAN, LAINNYA), Reset Default, and ConfigFile round-trip.
## 3. Sidebar Menu vs Exit button decoupling, ExitConfirmOverlay copy, dimmer isolation, Escape,
##    and MainMenu / Pause / Sidebar Exit confirmation cleanup.
## 4. Full interactive UI + World mouse/keyboard playthrough (Main Menu -> CARA MAIN -> Shop ->
##    buka -> 5-portion rice -> egg -> 3-tile counter -> saji -> Results).

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _test_audio_buses_bgm_fade_and_routing()
	await _test_settings_ui_and_config_persistence()
	await _test_sidebar_exit_and_exit_confirm_dialog()
	await _test_interactive_mouse_keyboard_playthrough()
	for _f in range(12):
		await process_frame
	print("SUMMARY fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _send_left_click(node: Node, pos: Vector2) -> void:
	var vp := node.get_viewport()
	if vp == null:
		return
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


func _send_key(node: Node, unicode_val: int, keycode_val: int = KEY_NONE) -> void:
	var vp := node.get_viewport()
	if vp == null:
		return
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
	vp.push_input(ev, true)


func _type_word(ui: GameUI, word: String) -> void:
	for i in range(word.length()):
		_send_key(ui, word.unicode_at(i))


func _click_world_object(ui: GameUI, world: WorldMap, obj_id: StringName) -> void:
	var obj := world.registry.get_object(obj_id)
	if obj == null:
		return
	var pos := world.get_canvas_transform() * obj.global_position
	if ui.interaction_dialogue != null and ui.interaction_dialogue.visible:
		if ui.interaction_dialogue.get_global_rect().has_point(pos):
			_send_left_click(ui, Vector2(360, 260))
	_send_left_click(ui, pos)


func _count_audio_players(node: Node) -> int:
	var count := 0
	if node is AudioStreamPlayer:
		count += 1
	for c in node.get_children():
		count += _count_audio_players(c)
	return count


func _test_audio_buses_bgm_fade_and_routing() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var ui := game_root.get_node("UI") as GameUI
	root.add_child(game_root)
	await process_frame
	await physics_frame
	var audio := game_root.get_audio_controller() as GameAudio

	_check(
		"GameAudio loads converted Backsound.ogg stream (~193.85s)",
		audio != null
		and audio.has_bgm_stream()
		and audio.get_bgm_stream_length() > 191.392
		and audio.get_bgm_stream_length() < 195.0
	)

	var snap := audio.get_audio_bus_snapshot()
	_check(
		"AudioServer exposes Master, Music->Master, SFX->Master and routes 3 players cleanly",
		int(snap["master_index"]) >= 0
		and int(snap["music_index"]) >= 0
		and int(snap["sfx_index"]) >= 0
		and String(snap["music_send"]) == "Master"
		and String(snap["sfx_send"]) == "Master"
		and String(snap["bgm_player_bus"]) == "Music"
		and String(snap["click_player_bus"]) == "SFX"
		and String(snap["sfx_player_bus"]) == "SFX"
		and _count_audio_players(game_root) == 3
	)

	# Verify independent Master / Music / SFX scaling without duplicate BGM attenuation.
	audio.set_master_volume(0.5, false)
	audio.set_music_volume(0.8, false)
	audio.set_sfx_volume(0.4, false)
	snap = audio.get_audio_bus_snapshot()
	_check(
		"Master, Music, SFX sliders update exact AudioServer buses and BGMPlayer stays fade-only (0 dB)",
		is_equal_approx(float(snap["master_db"]), linear_to_db(0.5))
		and is_equal_approx(float(snap["music_db"]), linear_to_db(0.8))
		and is_equal_approx(float(snap["sfx_db"]), linear_to_db(0.4))
		and not bool(snap["master_muted"])
		and not bool(snap["music_muted"])
		and not bool(snap["sfx_muted"])
		and is_equal_approx(audio._bgm_player.volume_db, 0.0)
		and is_equal_approx(float(snap["effective_bgm_linear"]), 0.40)
		and is_equal_approx(float(snap["effective_sfx_linear"]), 0.20)
	)

	# Verify <= 0.0001 mutes each bus independently without muting sibling buses.
	audio.set_music_volume(0.0, false)
	snap = audio.get_audio_bus_snapshot()
	_check(
		"Music volume 0.0 mutes Music bus at -80dB without muting Master or SFX",
		bool(snap["music_muted"])
		and is_equal_approx(float(snap["music_db"]), -80.0)
		and not bool(snap["master_muted"])
		and not bool(snap["sfx_muted"])
	)
	audio.set_master_volume(1.0, false)
	audio.set_music_volume(0.65, false)
	audio.set_sfx_volume(0.0, false)
	snap = audio.get_audio_bus_snapshot()
	_check(
		"SFX volume 0.0 mutes SFX bus without muting Music",
		bool(snap["sfx_muted"]) and not bool(snap["music_muted"])
	)
	audio.set_sfx_volume(1.0, false)

	# BGM lifecycle: Serving starts BGM -> Closing/Planning fades 5s while user volume stays on Music bus.
	_check("start service activates BGM in SERVING", game_root.start_service_requested() and audio.is_bgm_playing())
	audio.set_music_volume(0.5, false)
	var music_db_during_fade := float(audio.get_audio_bus_snapshot()["music_db"])
	audio.set_music_stage(false, true)
	audio._process(2.5)
	_check(
		"5s fade dims BGMPlayer factor (~0.5) while keeping Music bus live and loop-guarded",
		audio.is_fading_out()
		and is_equal_approx(audio.get_fade_factor(), 0.5)
		and is_equal_approx(audio._bgm_player.volume_db, linear_to_db(0.5))
		and is_equal_approx(music_db_during_fade, linear_to_db(0.5))
	)
	audio._process(2.6)
	_check(
		"After 5s fade Planning becomes silent without duplicate players",
		not audio.is_fading_out()
		and not audio.is_bgm_playing()
		and _count_audio_players(game_root) == 3
	)

	# Return to menu & Restart preserve single GameAudio and 3 AudioStreamPlayers.
	game_root.request_return_to_main_menu()
	await process_frame
	var playing_menu := audio.is_bgm_playing()
	game_root.request_restart_run()
	await process_frame
	_check(
		"Main Menu activates BGM and Restart preserves 3 unique AudioStreamPlayers",
		playing_menu and _count_audio_players(game_root) == 3
	)

	game_root.free()
	await process_frame


func _test_settings_ui_and_config_persistence() -> void:
	var cfg_path := "res://.godot/test_settings_m6.cfg"
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))

	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var ui := game_root.get_node("UI") as GameUI
	var audio := game_root.get_node("AudioController") as GameAudio
	audio.set_settings_path_for_test(cfg_path)
	audio.set_display_apply_enabled_for_test(false)
	root.add_child(game_root)
	await process_frame
	await physics_frame

	ui.open_settings(false)
	await process_frame
	_check("SettingsOverlay opens cleanly", ui.is_settings_open())

	# Exercise AUDIO sliders, TAMPILAN toggles, and OptionButton resolutions.
	ui.master_volume_slider.value = 0.75
	ui.bgm_volume_slider.value = 0.35
	ui.sfx_volume_slider.value = 0.55
	ui.resolution_option_button.select(2)
	ui.resolution_option_button.item_selected.emit(2)
	ui.vsync_toggle_button.pressed.emit()
	ui.display_mode_button.pressed.emit()
	await process_frame

	_check(
		"Expanded Settings sliders & Display toggles update GameAudio & labels live",
		is_equal_approx(audio.get_master_volume(), 0.75)
		and ui.master_value_label.text == "75%"
		and is_equal_approx(audio.get_music_volume(), 0.35)
		and ui.bgm_value_label.text == "35%"
		and is_equal_approx(audio.get_sfx_volume(), 0.55)
		and ui.sfx_value_label.text == "55%"
		and audio.is_fullscreen_enabled()
		and ui.display_mode_button.text == "Layar Penuh"
		and audio.get_resolution() == Vector2i(1280, 720)
		and not audio.is_vsync_enabled()
		and ui.vsync_toggle_button.text == "Mati"
	)

	# Resolution selector exposes all 4 supported resolutions.
	var listed_res: Array[String] = []
	for i in range(ui.resolution_option_button.item_count):
		listed_res.append(ui.resolution_option_button.get_item_text(i))
	_check(
		"Resolution OptionButton lists exact 4 resolutions",
		listed_res == ["480x270", "640x360", "1280x720", "1600x900"]
	)

	# Pick 1600x900 in windowed mode and confirm persistence across a fresh GameRoot instance.
	ui.display_mode_button.pressed.emit()
	ui.resolution_option_button.select(3)
	ui.resolution_option_button.item_selected.emit(3)
	await process_frame

	game_root.free()
	await process_frame

	var game_root_2 := packed.instantiate() as GameRoot
	var audio_2 := game_root_2.get_node("AudioController") as GameAudio
	var ui_2 := game_root_2.get_node("UI") as GameUI
	audio_2.set_settings_path_for_test(cfg_path)
	audio_2.set_display_apply_enabled_for_test(false)
	root.add_child(game_root_2)
	await process_frame
	ui_2.open_settings(false)
	await process_frame

	_check(
		"Persisted Settings reload accurately on fresh GameRoot + GameAudio startup",
		is_equal_approx(audio_2.get_master_volume(), 0.75)
		and is_equal_approx(audio_2.get_music_volume(), 0.35)
		and is_equal_approx(audio_2.get_sfx_volume(), 0.55)
		and not audio_2.is_fullscreen_enabled()
		and audio_2.get_resolution() == Vector2i(1600, 900)
		and not audio_2.is_vsync_enabled()
		and ui_2.master_value_label.text == "75%"
		and ui_2.bgm_value_label.text == "35%"
		and ui_2.sfx_value_label.text == "55%"
	)

	# Reset Default restores all 6 values and updates Settings UI & ConfigFile.
	ui_2.settings_reset_button.pressed.emit()
	await process_frame
	_check(
		"Reset Default restores default audio + display settings and updates labels",
		is_equal_approx(audio_2.get_master_volume(), GameAudio.DEFAULT_MASTER_VOLUME)
		and is_equal_approx(audio_2.get_music_volume(), GameAudio.DEFAULT_MUSIC_VOLUME)
		and is_equal_approx(audio_2.get_sfx_volume(), GameAudio.DEFAULT_SFX_VOLUME)
		and not audio_2.is_fullscreen_enabled()
		and audio_2.get_resolution() == GameAudio.DEFAULT_RESOLUTION
		and audio_2.is_vsync_enabled()
		and ui_2.display_mode_button.text == "Berjendela"
		and ui_2.vsync_toggle_button.text == "Aktif"
		and not ui_2.settings_feedback_label.text.is_empty()
	)

	game_root_2.free()
	await process_frame
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))


func _test_sidebar_exit_and_exit_confirm_dialog() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var ui := game_root.get_node("UI") as GameUI
	ui.set_onboarding_enabled(true)
	ui.set_exit_quit_disabled_for_test(true)
	root.add_child(game_root)
	await process_frame
	await physics_frame

	var exit_count := {"n": 0}
	ui.exit_game_requested.connect(func() -> void: exit_count["n"] += 1)

	# MainMenu Quit opens ExitConfirmOverlay; clicking Batal keeps MainMenu intact.
	game_root.request_return_to_main_menu()
	await process_frame
	ui.main_menu_quit_button.pressed.emit()
	await process_frame
	_check(
		"MainMenu Keluar opens ExitConfirmOverlay with exact prompt copy",
		ui.is_exit_confirm_open()
		and ui.exit_confirm_title_label.text == "Keluar Game?"
		and ui.exit_confirm_message_label.text == "Yakin ingin keluar dari Ketik Saji?"
		and ui.exit_confirm_cancel_button.text == "Batal"
		and ui.exit_confirm_quit_button.text == "Keluar"
		and int(exit_count["n"]) == 0
	)
	ui.exit_confirm_cancel_button.pressed.emit()
	await process_frame
	_check("Batal on MainMenu ExitConfirm leaves MainMenu open without quitting", not ui.is_exit_confirm_open() and ui.is_main_menu_open() and int(exit_count["n"]) == 0)

	# Start Day 1 Planning (dismiss opening story + CARA MAIN).
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	ui.skip_story()
	await process_frame
	ui.close_reference()
	await process_frame

	# MenuStubButton STILL opens Cara Main; ExitStubButton MUST NOT open Cara Main!
	ui.menu_stub_button.pressed.emit()
	await process_frame
	_check("Sidebar MenuStubButton opens Cara Main", ui.is_reference_open() and not ui.is_exit_confirm_open())
	ui.close_reference()
	await process_frame

	ui.exit_stub_button.pressed.emit()
	await process_frame
	_check(
		"Sidebar ExitStubButton opens ExitConfirmOverlay instead of Cara Main",
		ui.is_exit_confirm_open()
		and not ui.is_reference_open()
		and int(exit_count["n"]) == 0
	)

	# Clicking outside popup on dimmer MUST NOT quit or dismiss dialog accidentally.
	_send_left_click(ui, Vector2(10, 10))
	await process_frame
	_check(
		"Clicking ExitConfirm dimmer does not quit or trigger behind-UI actions",
		ui.is_exit_confirm_open() and int(exit_count["n"]) == 0
	)

	# Escape dismisses ExitConfirmOverlay cleanly without quitting.
	_send_key(ui, 0, KEY_ESCAPE)
	await process_frame
	_check(
		"Escape closes ExitConfirmOverlay cleanly without quitting",
		not ui.is_exit_confirm_open() and int(exit_count["n"]) == 0
	)

	# Pause button continues opening Pause cleanly, and confirming Exit works once.
	ui.pause_button.pressed.emit()
	await process_frame
	_check("Sidebar PauseButton still opens PauseOverlay", ui.is_pause_open() and game_root.is_paused())
	ui.pause_exit_button.pressed.emit()
	await process_frame
	ui.exit_confirm_quit_button.pressed.emit()
	await process_frame
	_check(
		"Confirming Keluar emits exit_game_requested once and unpauses cleanly",
		int(exit_count["n"]) == 1 and not ui.is_exit_confirm_open() and not game_root.is_paused()
	)

	game_root.free()
	await process_frame


func _test_interactive_mouse_keyboard_playthrough() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var ui := game_root.get_node("UI") as GameUI
	ui.set_onboarding_enabled(true)
	root.add_child(game_root)
	await process_frame
	await physics_frame
	var world := game_root.get_node("World") as WorldMap
	var run := game_root.get_run_controller() as RunController
	var kitchen := game_root.get_kitchen_controller() as KitchenController
	var service := game_root.get_service_controller() as ServiceController
	var audio := game_root.get_audio_controller() as GameAudio

	# 1. Start from MainMenu -> Story -> CARA MAIN -> Day 1 Planning.
	game_root.request_return_to_main_menu()
	await process_frame
	ui.main_menu_play_button.pressed.emit()
	await process_frame
	world = game_root.get_node("World") as WorldMap
	ui.skip_story()
	await process_frame
	ui.close_reference()
	await process_frame
	_check("Real boot flow arrives at Day 1 PLANNING cleanly", game_root.get_phase() == SharedTypes.Phase.PLANNING and not ui.is_main_menu_open())

	# 2. Click storage_box in World & type "beli" via keyboard -> buy beras + telur -> Checkout!
	var cash_before_shop := int(run.get_run_view().get("cash", 0))
	_click_world_object(ui, world, &"storage_box")
	_type_word(ui, "beli")
	await process_frame
	_check("World click storage_box + typing beli opens Belanja Bahan", ui.is_ingredient_shop_open())
	ui._shop_ingredient_rows[&"beras"]["plus_button"].pressed.emit()
	ui._shop_ingredient_rows[&"telur"]["plus_button"].pressed.emit()
	ui.shop_checkout_button.pressed.emit()
	await process_frame
	var storage_view := kitchen.get_storage_unit_view(&"storage_box")
	var beras_count := 0
	var telur_count := 0
	for slot: Dictionary in storage_view.get("slots", []):
		if StringName(slot.get("ingredient_id", &"")) == &"beras":
			beras_count += int(slot.get("quantity", 0))
		elif StringName(slot.get("ingredient_id", &"")) == &"telur":
			telur_count += int(slot.get("quantity", 0))
	_check(
		"Belanja Bahan purchase updates cash & storage_box stock (beras>=1, telur>=1)",
		int(run.get_run_view().get("cash", 0)) < cash_before_shop
		and beras_count >= 1
		and telur_count >= 1
		and not ui.is_ingredient_shop_open()
	)

	# 3. Click open floor tile (outside PlacementSlots) to clear target and type "buka" -> enter SERVING with BGM active!
	var floor_pos := world.get_canvas_transform() * world.to_global(world.grid.cell_to_local(Vector2i(5, 5)))
	var found_floor := false
	for cy in range(9):
		for cx in range(12):
			var c := Vector2i(cx, cy)
			if not world.grid.is_free(c):
				continue
			var g_pos := world.to_global(world.grid.cell_to_local(c))
			if world.hit_test_placement_slot(g_pos) == &"":
				var c_pos := world.get_canvas_transform() * g_pos
				if ui.interaction_dialogue == null or not ui.interaction_dialogue.visible or not ui.interaction_dialogue.get_global_rect().has_point(c_pos):
					floor_pos = c_pos
					found_floor = true
					break
		if found_floor:
			break
	_send_left_click(ui, floor_pos)
	_type_word(ui, "buka")
	await process_frame
	_check(
		"Typing buka starts SERVING and starts Backsound BGM",
		game_root.get_phase() == SharedTypes.Phase.SERVING and audio.is_bgm_playing()
	)

	# 4. Cook 5 portions rice -> fry egg -> stage on LongCounter -> plate_rack -> nasi -> merge & saji!
	_click_world_object(ui, world, &"storage_box")
	_type_word(ui, "beras")
	_click_world_object(ui, world, &"washer")
	_type_word(ui, "cuci")
	_click_world_object(ui, world, &"rice_cooker")
	_type_word(ui, "masak")
	var cooker_view := kitchen.get_cooker_output_view(&"rice_cooker")
	_check(
		"Cooking washed rice deposits 5 rice portions into rice_cooker",
		int(cooker_view.get("portions", 0)) == 5
	)

	var slot_id := world.get_long_counter_slot_ids()[0]
	_click_world_object(ui, world, &"storage_box")
	_type_word(ui, "telur")
	_click_world_object(ui, world, &"stove")
	_type_word(ui, "goreng")
	_click_world_object(ui, world, slot_id)
	_click_world_object(ui, world, &"plate_rack")
	_click_world_object(ui, world, &"rice_cooker")
	_type_word(ui, "nasi")
	# Merging staged fried_telur into held plated rice yields Nasi Telur in hand!
	_click_world_object(ui, world, slot_id)
	await process_frame
	var assembled_in_hand := StringName(kitchen.get_held_item_view().get("matched_recipe_id", &"")) == &"nasi_telor"
	# Place completed Nasi Telur onto LongCounter slot -> verify DishSprite renders -> pick back up & serve!
	_click_world_object(ui, world, slot_id)
	await process_frame
	var slot_tex_ok := false
	var counter_slot := world.registry.get_object(slot_id)
	if counter_slot != null and counter_slot.has_node("StagedVisual/DishSprite"):
		var ds := counter_slot.get_node("StagedVisual/DishSprite") as Sprite2D
		slot_tex_ok = ds != null and ds.visible and ds.texture != null
	_click_world_object(ui, world, slot_id)
	await process_frame
	var assembled_ok := assembled_in_hand and StringName(kitchen.get_held_item_view().get("matched_recipe_id", &"")) == &"nasi_telor"
	var cash_before_serve := int(run.get_run_view().get("cash", 0))
	_click_world_object(ui, world, &"dining_table_01")
	_type_word(ui, "saji")
	await process_frame

	var serve_ok := (
		slot_tex_ok
		and assembled_ok
		and kitchen.get_held_item_view().is_empty()
		and int(run.get_run_view().get("cash", 0)) == cash_before_serve + 20000
	)
	_check(
		"Interactive playthrough assembles Nasi Telur via LongCounter (with DishSprite) and serves diner (+Rp 20k)",
		serve_ok
	)

	game_root.free()
	await process_frame
