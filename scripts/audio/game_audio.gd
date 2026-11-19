class_name GameAudio
extends Node
## Centralized audio owner for randomized input clicks, typing/serve SFX,
## 191.392s-looping Backsound.opus BGM, 5-second cross-stage fades, and live
## Settings BGM volume control.

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
const DEFAULT_BGM_VOLUME: float = 0.65

var _bgm_stream: AudioStream = null
var _error_sfx: AudioStream = null
var _serve_sfx: AudioStream = null
var _click_streams: Array[AudioStream] = []

var _bgm_player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null

var _bgm_user_volume: float = DEFAULT_BGM_VOLUME
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
	_bgm_player.stream = _bgm_stream
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.name = "ClickSFXPlayer"
	_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "OutcomeSFXPlayer"
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)
	_apply_bgm_volume()


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


func set_bgm_volume(linear_volume: float) -> void:
	_bgm_user_volume = clampf(linear_volume, 0.0, 1.0)
	_apply_bgm_volume()


func get_bgm_volume() -> float:
	return _bgm_user_volume


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


func _apply_bgm_volume() -> void:
	if _bgm_player == null:
		return
	var eff := clampf(_bgm_user_volume, 0.0, 1.0) * clampf(_fade_factor, 0.0, 1.0)
	_bgm_player.volume_db = -80.0 if eff <= 0.0001 else linear_to_db(eff)
