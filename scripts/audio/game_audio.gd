class_name GameAudio
extends Node
## Centralized audio & user-settings owner for AudioServer buses (Master, Music, SFX),
## randomized input clicks, typing/serve SFX, 191.392s-looping BGM with 5s cross-stage
## fades, Display/Audio Settings persistence (user://settings.cfg), and clean teardown.

const BGM_CANDIDATE_PATHS: Array[String] = [
	"res://assets/audio/Backsound.ogg",
	"res://assets/audio/Backsound.opus",
]
const ERROR_SFX_PATH: String = "res://assets/audio/impactGlass_heavy_000.ogg"
const SERVE_SFX_PATH: String = "res://assets/audio/impactMining_000.ogg"
const CLICK_SFX_PATHS: Array[String] = [
	"res://assets/audio/click1.ogg",
	"res://assets/audio/click2.ogg",
	"res://assets/audio/click3.ogg",
	"res://assets/audio/click4.ogg",
	"res://assets/audio/click5.ogg",
]
const BGM_LOOP_END_SECONDS: float = 191.392
const BGM_FADE_DURATION_SECONDS: float = 5.0

const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_BGM_VOLUME: float = 0.65
const DEFAULT_MUSIC_VOLUME: float = DEFAULT_BGM_VOLUME
const DEFAULT_SFX_VOLUME: float = 1.0
const DEFAULT_FULLSCREEN: bool = false
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)
const DEFAULT_VSYNC: bool = true
const ALLOWED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(480, 270),
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
]

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"

signal display_settings_applied(ok: bool, feedback: String)

var _bgm_stream: AudioStream = null
var _error_sfx: AudioStream = null
var _serve_sfx: AudioStream = null
var _click_streams: Array[AudioStream] = []

var _bgm_player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null

var _master_volume: float = DEFAULT_MASTER_VOLUME
var _bgm_user_volume: float = DEFAULT_BGM_VOLUME
var _sfx_volume: float = DEFAULT_SFX_VOLUME
var _display_fullscreen: bool = DEFAULT_FULLSCREEN
var _display_resolution: Vector2i = DEFAULT_RESOLUTION
var _display_vsync: bool = DEFAULT_VSYNC

var _settings_path: String = DEFAULT_SETTINGS_PATH
var _tutorial_state: Dictionary = {
	"completed": false,
	"skipped": false,
	"step_index": 0,
	"shown_tips": [],
	"flags": {},
}
var _display_apply_enabled: bool = true
var _last_display_ok: bool = true
var _last_display_feedback: String = ""
var _applied_window_size: Vector2i = DEFAULT_RESOLUTION
var _applied_fullscreen: bool = DEFAULT_FULLSCREEN

var _fade_factor: float = 1.0
var _fade_remaining: float = 0.0
var _fading_out: bool = false
var _wants_bgm: bool = false
var _pending_restart_after_fade: bool = false
var _last_click_index: int = -1
var _last_click_ticks_msec: int = -1000
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_buses()
	_load_settings_from_disk()
	for bgm_path in BGM_CANDIDATE_PATHS:
		_bgm_stream = _load_audio_stream_safe(bgm_path)
		if _bgm_stream != null:
			break
	_error_sfx = _load_audio_stream_safe(ERROR_SFX_PATH)
	_serve_sfx = _load_audio_stream_safe(SERVE_SFX_PATH)
	_click_streams.clear()
	for click_path in CLICK_SFX_PATHS:
		var s := _load_audio_stream_safe(click_path)
		if s != null:
			_click_streams.append(s)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = BUS_MUSIC
	_bgm_player.stream = _bgm_stream
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.name = "ClickSFXPlayer"
	_click_player.bus = BUS_SFX
	_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "OutcomeSFXPlayer"
	_sfx_player.bus = BUS_SFX
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)

	_apply_all_audio_buses()
	_apply_bgm_volume()
	if _should_apply_display_on_startup():
		call_deferred(&"_apply_display_settings_on_startup")
	else:
		_sync_applied_display_from_server()


func _exit_tree() -> void:
	for player in [_bgm_player, _click_player, _sfx_player]:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null
	_bgm_stream = null
	_error_sfx = null
	_serve_sfx = null
	_click_streams.clear()


static func _load_audio_stream_safe(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path, "AudioStream"):
		return null
	var res := ResourceLoader.load(path, "AudioStream")
	return res as AudioStream


func _process(delta: float) -> void:
	if _bgm_player == null:
		return
	if _bgm_player.playing and _bgm_player.get_playback_position() >= BGM_LOOP_END_SECONDS:
		_bgm_player.play(0.0)
	if _fading_out:
		_fade_remaining = maxf(0.0, _fade_remaining - delta)
		_fade_factor = clampf(_fade_remaining / BGM_FADE_DURATION_SECONDS, 0.0, 1.0)
		_apply_bgm_volume()
		if _fade_remaining <= 0.0:
			_fading_out = false
			if _pending_restart_after_fade and _wants_bgm:
				_pending_restart_after_fade = false
				_start_bgm_fresh()
			else:
				_pending_restart_after_fade = false
				_bgm_player.stop()


func set_music_stage(wants_bgm: bool, fade_out_on_change: bool = true) -> void:
	var prev_wants := _wants_bgm
	_wants_bgm = wants_bgm
	if not wants_bgm:
		_pending_restart_after_fade = false
		if _bgm_player != null and _bgm_player.playing:
			if fade_out_on_change and not _fading_out:
				_fading_out = true
				_fade_remaining = BGM_FADE_DURATION_SECONDS * clampf(_fade_factor, 0.0, 1.0)
			elif not fade_out_on_change:
				_fading_out = false
				_fade_remaining = 0.0
				_fade_factor = 0.0
				_bgm_player.stop()
		return

	# Target stage wants BGM (Main Menu or Serving).
	if _bgm_player != null and _bgm_player.playing and not _fading_out:
		if prev_wants and fade_out_on_change:
			_fading_out = true
			_fade_remaining = BGM_FADE_DURATION_SECONDS
			_pending_restart_after_fade = true
		else:
			_fade_factor = 1.0
			_apply_bgm_volume()
		return

	if _fading_out:
		if fade_out_on_change:
			_pending_restart_after_fade = true
		else:
			_fading_out = false
			_pending_restart_after_fade = false
			_fade_factor = 1.0
			_apply_bgm_volume()
		return

	_start_bgm_fresh()


func set_master_volume(linear_volume: float, persist: bool = true) -> void:
	_master_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_bus_volume(BUS_MASTER, _master_volume)
	if persist:
		_save_settings_to_disk()


func get_master_volume() -> float:
	return _master_volume


func set_music_volume(linear_volume: float, persist: bool = true) -> void:
	_bgm_user_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, _bgm_user_volume)
	if persist:
		_save_settings_to_disk()


func get_music_volume() -> float:
	return _bgm_user_volume


func set_bgm_volume(linear_volume: float) -> void:
	set_music_volume(linear_volume, true)


func get_bgm_volume() -> float:
	return get_music_volume()


func set_sfx_volume(linear_volume: float, persist: bool = true) -> void:
	_sfx_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_bus_volume(BUS_SFX, _sfx_volume)
	if persist:
		_save_settings_to_disk()


func get_sfx_volume() -> float:
	return _sfx_volume


func set_fullscreen_enabled(enabled: bool, persist: bool = true) -> bool:
	var prev := _display_fullscreen
	_display_fullscreen = enabled
	var ok := _apply_display_settings()
	if not ok:
		_display_fullscreen = prev
	if persist and ok:
		_save_settings_to_disk()
	return ok


func is_fullscreen_enabled() -> bool:
	return _display_fullscreen


func set_resolution(resolution: Vector2i, persist: bool = true) -> bool:
	if resolution not in ALLOWED_RESOLUTIONS:
		_last_display_ok = false
		_last_display_feedback = "Resolusi tidak didukung."
		display_settings_applied.emit(false, _last_display_feedback)
		return false
	_display_resolution = resolution
	var ok := _apply_display_settings()
	if persist and ok:
		_save_settings_to_disk()
	return ok


func get_resolution() -> Vector2i:
	return _display_resolution


func get_allowed_resolutions() -> Array[Vector2i]:
	return ALLOWED_RESOLUTIONS.duplicate()


func set_vsync_enabled(enabled: bool, persist: bool = true) -> bool:
	var prev := _display_vsync
	_display_vsync = enabled
	var ok := _apply_display_settings()
	if not ok:
		_display_vsync = prev
	if persist and ok:
		_save_settings_to_disk()
	return ok


func is_vsync_enabled() -> bool:
	return _display_vsync


func reset_settings_to_default() -> void:
	_master_volume = DEFAULT_MASTER_VOLUME
	_bgm_user_volume = DEFAULT_BGM_VOLUME
	_sfx_volume = DEFAULT_SFX_VOLUME
	_display_fullscreen = DEFAULT_FULLSCREEN
	_display_resolution = DEFAULT_RESOLUTION
	_display_vsync = DEFAULT_VSYNC
	_apply_all_audio_buses()
	_apply_bgm_volume()
	_apply_display_settings()
	_save_settings_to_disk()


func get_tutorial_state() -> Dictionary:
	return _tutorial_state.duplicate(true)


func save_tutorial_state(state: Dictionary, persist: bool = true) -> void:
	var shown: Array[String] = []
	var raw_tips: Variant = state.get("shown_tips", [])
	if raw_tips is Array:
		for item in (raw_tips as Array):
			var s := str(item)
			if not s.is_empty() and s not in shown:
				shown.append(s)
	var clean_flags: Dictionary = {}
	var raw_flags: Variant = state.get("flags", {})
	if raw_flags is Dictionary:
		for k in (raw_flags as Dictionary):
			clean_flags[str(k)] = bool((raw_flags as Dictionary)[k])
	_tutorial_state = {
		"completed": bool(state.get("completed", false)),
		"skipped": bool(state.get("skipped", false)),
		"step_index": maxi(0, int(state.get("step_index", 0))),
		"shown_tips": shown,
		"flags": clean_flags,
	}
	if persist:
		_save_settings_to_disk()


func reset_tutorial_state(persist: bool = true) -> void:
	_tutorial_state = {
		"completed": false,
		"skipped": false,
		"step_index": 0,
		"shown_tips": [],
		"flags": {},
	}
	if persist:
		_save_settings_to_disk()


func set_settings_path_for_test(path: String) -> void:
	_settings_path = DEFAULT_SETTINGS_PATH if path.is_empty() else path


func set_display_apply_enabled_for_test(enabled: bool) -> void:
	_display_apply_enabled = enabled


func reload_settings_from_disk() -> bool:
	var loaded := _load_settings_from_disk()
	_apply_all_audio_buses()
	_apply_bgm_volume()
	if loaded:
		_apply_display_settings()
	return loaded


func get_applied_display_snapshot() -> Dictionary:
	_sync_applied_display_from_server()
	var can_query := _display_apply_enabled and DisplayServer.get_name() != "headless"
	var screen_idx := DisplayServer.window_get_current_screen() if can_query else 0
	var usable := DisplayServer.screen_get_usable_rect(screen_idx) if can_query else Rect2i(Vector2i.ZERO, _applied_window_size)
	var win_mode := DisplayServer.window_get_mode() if can_query else (
		DisplayServer.WINDOW_MODE_FULLSCREEN if _applied_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	var vsync_mode := DisplayServer.window_get_vsync_mode() if can_query else (
		DisplayServer.VSYNC_ENABLED if _display_vsync else DisplayServer.VSYNC_DISABLED
	)
	var win_pos := DisplayServer.window_get_position() if can_query else Vector2i.ZERO
	return {
		"applied_ok": _last_display_ok,
		"fullscreen": _applied_fullscreen,
		"window_mode": win_mode,
		"window_size": _applied_window_size,
		"requested_resolution": _display_resolution,
		"vsync_enabled": vsync_mode != DisplayServer.VSYNC_DISABLED if can_query else _display_vsync,
		"vsync_mode": vsync_mode,
		"window_position": win_pos,
		"usable_rect": usable,
		"feedback": _last_display_feedback,
	}


func has_bgm_stream() -> bool:
	return _bgm_stream != null


func get_bgm_stream_length() -> float:
	return _bgm_stream.get_length() if _bgm_stream != null else 0.0


func get_effective_bgm_linear_volume() -> float:
	return _master_volume * _bgm_user_volume * clampf(_fade_factor, 0.0, 1.0)


func get_effective_sfx_linear_volume() -> float:
	return _master_volume * _sfx_volume


func get_audio_bus_snapshot() -> Dictionary:
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	return {
		"master_index": master_idx,
		"music_index": music_idx,
		"sfx_index": sfx_idx,
		"bgm_player_bus": String(_bgm_player.bus) if _bgm_player != null else "",
		"click_player_bus": String(_click_player.bus) if _click_player != null else "",
		"sfx_player_bus": String(_sfx_player.bus) if _sfx_player != null else "",
		"music_send": String(AudioServer.get_bus_send(music_idx)) if music_idx >= 0 else "",
		"sfx_send": String(AudioServer.get_bus_send(sfx_idx)) if sfx_idx >= 0 else "",
		"master_db": AudioServer.get_bus_volume_db(master_idx) if master_idx >= 0 else 0.0,
		"music_db": AudioServer.get_bus_volume_db(music_idx) if music_idx >= 0 else 0.0,
		"sfx_db": AudioServer.get_bus_volume_db(sfx_idx) if sfx_idx >= 0 else 0.0,
		"master_muted": AudioServer.is_bus_mute(master_idx) if master_idx >= 0 else false,
		"music_muted": AudioServer.is_bus_mute(music_idx) if music_idx >= 0 else false,
		"sfx_muted": AudioServer.is_bus_mute(sfx_idx) if sfx_idx >= 0 else false,
		"effective_bgm_linear": get_effective_bgm_linear_volume(),
		"effective_sfx_linear": get_effective_sfx_linear_volume(),
	}


func is_bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing


func is_fading_out() -> bool:
	return _fading_out


func get_fade_factor() -> float:
	return _fade_factor


func get_bgm_playback_position() -> float:
	return _bgm_player.get_playback_position() if _bgm_player != null else 0.0


func get_last_click_index() -> int:
	return _last_click_index


func play_click() -> int:
	if _click_streams.is_empty():
		return -1
	var now_msec := Time.get_ticks_msec()
	if now_msec == _last_click_ticks_msec:
		return -1
	_last_click_ticks_msec = now_msec
	var next_idx := _pick_non_repeating_click_index()
	_last_click_index = next_idx
	if _click_player != null and is_inside_tree():
		_click_player.stream = _click_streams[next_idx]
		_click_player.play()
	return next_idx


func play_error_sfx() -> void:
	if _error_sfx == null:
		return
	if _sfx_player != null and is_inside_tree():
		_sfx_player.stream = _error_sfx
		_sfx_player.play()


func play_serve_sfx() -> void:
	if _serve_sfx == null:
		return
	if _sfx_player != null and is_inside_tree():
		_sfx_player.stream = _serve_sfx
		_sfx_player.play()


func _pick_non_repeating_click_index() -> int:
	var count := _click_streams.size()
	if count <= 1:
		return 0
	var idx := _rng.randi_range(0, count - 1)
	if idx == _last_click_index:
		idx = (idx + 1 + _rng.randi_range(0, count - 2)) % count
	return idx


func _start_bgm_fresh() -> void:
	_fading_out = false
	_pending_restart_after_fade = false
	_fade_factor = 1.0
	_fade_remaining = 0.0
	_apply_bgm_volume()
	if _bgm_player != null and _bgm_player.stream != null and is_inside_tree():
		_bgm_player.play(0.0)


func _ensure_audio_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)


func _apply_all_audio_buses() -> void:
	_apply_bus_volume(BUS_MASTER, _master_volume)
	_apply_bus_volume(BUS_MUSIC, _bgm_user_volume)
	_apply_bus_volume(BUS_SFX, _sfx_volume)


func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var clamped := clampf(linear_volume, 0.0, 1.0)
	var muted := clamped <= 0.0001
	AudioServer.set_bus_mute(idx, muted)
	AudioServer.set_bus_volume_db(idx, -80.0 if muted else linear_to_db(clamped))


func _apply_bgm_volume() -> void:
	if _bgm_player == null:
		return
	# Music and Master buses already carry user volume; BGMPlayer handles fade factor only.
	var fade := clampf(_fade_factor, 0.0, 1.0)
	_bgm_player.volume_db = -80.0 if fade <= 0.0001 else linear_to_db(fade)


func _should_apply_display_on_startup() -> bool:
	if not _display_apply_enabled or DisplayServer.get_name() == "headless":
		return false
	if is_inside_tree() and get_tree() != null and get_tree().get_script() != null:
		return false
	return FileAccess.file_exists(_settings_path)


func _apply_display_settings_on_startup() -> void:
	if not is_inside_tree():
		return
	_apply_display_settings()


func _sync_applied_display_from_server() -> void:
	if not _display_apply_enabled or DisplayServer.get_name() == "headless":
		_applied_fullscreen = _display_fullscreen
		_applied_window_size = _display_resolution
		return
	var mode := DisplayServer.window_get_mode()
	_applied_fullscreen = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	_applied_window_size = DisplayServer.window_get_size()


func _center_and_clamp_window(target_size: Vector2i, usable: Rect2i) -> void:
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var max_x := maxi(usable.position.x, usable.position.x + usable.size.x - target_size.x)
	var max_y := maxi(usable.position.y, usable.position.y + usable.size.y - target_size.y)
	var centered_x := usable.position.x + maxi(0, (usable.size.x - target_size.x) / 2)
	var centered_y := usable.position.y + maxi(0, (usable.size.y - target_size.y) / 2)
	var clamped_pos := Vector2i(
		clampi(centered_x, usable.position.x, max_x),
		clampi(centered_y, usable.position.y, max_y)
	)
	DisplayServer.window_set_position(clamped_pos)


func _deferred_enforce_windowed_bounds(expected_res: Vector2i) -> void:
	if _display_fullscreen or not _display_apply_enabled or DisplayServer.get_name() == "headless":
		return
	if not is_inside_tree():
		return
	var cur_mode := DisplayServer.window_get_mode()
	var win := get_window()
	if cur_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if win != null:
			win.mode = Window.MODE_WINDOWED
	var screen_idx := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_idx)
	var bounded := expected_res
	if usable.size.x > 0 and usable.size.y > 0:
		bounded = Vector2i(mini(expected_res.x, usable.size.x), mini(expected_res.y, usable.size.y))
	if DisplayServer.window_get_size() != bounded:
		DisplayServer.window_set_size(bounded)
		if win != null:
			win.size = bounded
	_center_and_clamp_window(bounded, usable)
	_sync_applied_display_from_server()
	display_settings_applied.emit(_last_display_ok, _last_display_feedback)


func _apply_display_settings() -> bool:
	if not _display_apply_enabled or DisplayServer.get_name() == "headless":
		_applied_fullscreen = _display_fullscreen
		_applied_window_size = _display_resolution
		_last_display_ok = true
		_last_display_feedback = (
			"Layar Penuh aktif. Jendela: %dx%d" % [_display_resolution.x, _display_resolution.y]
			if _display_fullscreen
			else "Berjendela: %dx%d" % [_display_resolution.x, _display_resolution.y]
		)
		display_settings_applied.emit(true, _last_display_feedback)
		return true

	var vsync_mode := DisplayServer.VSYNC_ENABLED if _display_vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	var win := get_window()

	if _display_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if win != null:
			win.mode = Window.MODE_FULLSCREEN
		var actual_mode := DisplayServer.window_get_mode()
		_sync_applied_display_from_server()
		if (
			actual_mode != DisplayServer.WINDOW_MODE_FULLSCREEN
			and actual_mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		):
			_last_display_ok = false
			_last_display_feedback = "Gagal menerapkan Layar Penuh."
			display_settings_applied.emit(false, _last_display_feedback)
			return false
		_last_display_ok = true
		_last_display_feedback = (
			"Layar Penuh (%dx%d) · Jendela: %dx%d"
			% [
				_applied_window_size.x,
				_applied_window_size.y,
				_display_resolution.x,
				_display_resolution.y,
			]
		)
		display_settings_applied.emit(true, _last_display_feedback)
		return true

	# Windowed mode: leave fullscreen cleanly, clamp to usable monitor area, size & center.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if win != null and win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
	var screen_idx := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_idx)
	var target_res := _display_resolution
	var clamped_by_screen := false
	if usable.size.x > 0 and usable.size.y > 0:
		var cw := mini(target_res.x, usable.size.x)
		var ch := mini(target_res.y, usable.size.y)
		if cw != target_res.x or ch != target_res.y:
			target_res = Vector2i(cw, ch)
			clamped_by_screen = true
	DisplayServer.window_set_size(target_res)
	if win != null:
		win.size = target_res
	_center_and_clamp_window(target_res, usable)
	var actual_win_mode := DisplayServer.window_get_mode()
	_sync_applied_display_from_server()
	call_deferred(&"_deferred_enforce_windowed_bounds", _display_resolution)
	if actual_win_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		_last_display_ok = false
		_last_display_feedback = "Gagal beralih ke mode Berjendela."
		display_settings_applied.emit(false, _last_display_feedback)
		return false
	_last_display_ok = true
	if clamped_by_screen:
		_last_display_feedback = (
			"Disesuaikan ke batas layar: %dx%d."
			% [_applied_window_size.x, _applied_window_size.y]
		)
	else:
		_last_display_feedback = (
			"Berjendela: %dx%d" % [_applied_window_size.x, _applied_window_size.y]
		)
	display_settings_applied.emit(true, _last_display_feedback)
	return true


func _load_settings_from_disk() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path) != OK:
		return false
	_master_volume = clampf(
		float(cfg.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0
	)
	_bgm_user_volume = clampf(
		float(cfg.get_value("audio", "music_volume", DEFAULT_BGM_VOLUME)), 0.0, 1.0
	)
	_sfx_volume = clampf(
		float(cfg.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0
	)
	_display_fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	_display_vsync = bool(cfg.get_value("display", "vsync", DEFAULT_VSYNC))
	var res_w := int(cfg.get_value("display", "resolution_width", DEFAULT_RESOLUTION.x))
	var res_h := int(cfg.get_value("display", "resolution_height", DEFAULT_RESOLUTION.y))
	var candidate := Vector2i(res_w, res_h)
	_display_resolution = candidate if candidate in ALLOWED_RESOLUTIONS else DEFAULT_RESOLUTION
	var raw_tips: Variant = cfg.get_value("tutorial", "shown_tips", [])
	var shown: Array[String] = []
	if raw_tips is Array:
		for item in (raw_tips as Array):
			var s := str(item)
			if not s.is_empty() and s not in shown:
				shown.append(s)
	var clean_flags: Dictionary = {}
	var raw_flags: Variant = cfg.get_value("tutorial", "flags", {})
	if raw_flags is Dictionary:
		for k in (raw_flags as Dictionary):
			clean_flags[str(k)] = bool((raw_flags as Dictionary)[k])
	_tutorial_state = {
		"completed": bool(cfg.get_value("tutorial", "completed", false)),
		"skipped": bool(cfg.get_value("tutorial", "skipped", false)),
		"step_index": maxi(0, int(cfg.get_value("tutorial", "step_index", 0))),
		"shown_tips": shown,
		"flags": clean_flags,
	}
	return true


func _save_settings_to_disk() -> void:
	if (
		_settings_path == DEFAULT_SETTINGS_PATH
		and (DisplayServer.get_name() == "headless" or OS.has_feature("headless"))
	):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", _master_volume)
	cfg.set_value("audio", "music_volume", _bgm_user_volume)
	cfg.set_value("audio", "sfx_volume", _sfx_volume)
	cfg.set_value("display", "fullscreen", _display_fullscreen)
	cfg.set_value("display", "resolution_width", _display_resolution.x)
	cfg.set_value("display", "resolution_height", _display_resolution.y)
	cfg.set_value("display", "vsync", _display_vsync)
	cfg.set_value("tutorial", "completed", bool(_tutorial_state.get("completed", false)))
	cfg.set_value("tutorial", "skipped", bool(_tutorial_state.get("skipped", false)))
	cfg.set_value("tutorial", "step_index", maxi(0, int(_tutorial_state.get("step_index", 0))))
	cfg.set_value("tutorial", "shown_tips", _tutorial_state.get("shown_tips", []))
	cfg.set_value("tutorial", "flags", _tutorial_state.get("flags", {}))
	cfg.save(_settings_path)
