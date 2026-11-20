class_name GameRoot
extends Node2D
## Persistent scene root owning top-level phase transitions and the single
## monotonic `service_elapsed` clock.
##
## Holds no orders, stock, plates, or cash. Orchestrates KitchenController,
## ServiceController, and RunController lifecycle boundaries synchronously.

signal phase_changed(phase: int, day_index: int)
signal pause_changed(paused: bool)

const RESTAURANT_WORLD_SCENE: PackedScene = preload("res://scenes/world/restaurant_world.tscn")

var _phase: SharedTypes.Phase = SharedTypes.Phase.PLANNING
var _service_elapsed: float = 0.0
var _closing_in_progress: bool = false
var _paused: bool = false
var _initialized: bool = false
var _in_main_menu: bool = false
var _restarting_run: bool = false

var _kitchen_controller: Node = null
var _service_controller: Node = null
var _run_controller: Node = null
var _audio_controller: GameAudio = null


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_phase = SharedTypes.Phase.PLANNING
	_service_elapsed = 0.0
	_paused = false
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false

	if _kitchen_controller == null:
		_kitchen_controller = get_node_or_null("KitchenController")
	if _service_controller == null:
		_service_controller = get_node_or_null("ServiceController")
	if _run_controller == null:
		_run_controller = get_node_or_null("RunController")
	if _audio_controller == null:
		_audio_controller = get_node_or_null("AudioController") as GameAudio

	_in_main_menu = _is_app_main_scene_boot()
	_wire_controllers()
	if not _in_main_menu:
		if _run_controller != null and _run_controller.has_method(&"start_new_run"):
			_run_controller.start_new_run()
	_sync_bgm_stage(false)


func _is_app_main_scene_boot() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false
	if get_node_or_null("UI/UIRoot/MainMenuOverlay") == null:
		return false
	var tree := get_tree()
	if tree.current_scene == self:
		return true
	# During Main::start(), Godot adds the main scene before assigning tree.current_scene.
	if get_parent() == tree.root and tree.get_script() == null:
		var main_scene_path := String(
			ProjectSettings.get_setting("application/run/main_scene", "")
		)
		var main_uid := ResourceUID.id_to_text(
			ResourceLoader.get_resource_uid(scene_file_path)
		) if not scene_file_path.is_empty() else ""
		if (
			scene_file_path == main_scene_path
			or (not main_uid.is_empty() and main_uid == main_scene_path)
		):
			return true
	return false


func _exit_tree() -> void:
	if _paused and is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	_paused = false


func _process(delta: float) -> void:
	if _phase != SharedTypes.Phase.SERVING or _paused or delta <= 0.0:
		return

	_service_elapsed += delta
	if _kitchen_controller != null and _kitchen_controller.has_method(&"advance_service_time"):
		_kitchen_controller.advance_service_time(_service_elapsed)
	if _service_controller != null and _service_controller.has_method(&"advance_service_time"):
		_service_controller.advance_service_time(_service_elapsed)
	if _service_controller != null and _service_controller.has_method(&"is_drained"):
		if _service_controller.is_drained():
			request_close_if_drained()


## Wires controller references during root/test setup.
func bind_controllers(kitchen: Node, service: Node, run: Node) -> void:
	_kitchen_controller = kitchen
	_service_controller = service
	_run_controller = run
	if _initialized:
		_wire_controllers()


## Transitions PLANNING -> SERVING once when KitchenController, RunController,
## and ServiceController are valid and plan finalization succeeds.
func start_service_requested() -> bool:
	if _phase != SharedTypes.Phase.PLANNING or _paused:
		return false
	if (
		not _is_valid_kitchen_controller()
		or not _is_valid_run_controller()
		or not _is_valid_service_controller()
	):
		return false
	if not _run_controller.finalize_plan():
		return false

	var plan: Dictionary = _run_controller.get_service_plan()
	var current_day := get_day_index()
	if current_day <= 0:
		return false
	if plan.has("day_index") and int(plan.get("day_index", -1)) != current_day:
		return false

	if (
		_kitchen_controller != null
		and _kitchen_controller.has_method(&"prepare_service_day")
	):
		_kitchen_controller.prepare_service_day(current_day, plan)
	_service_controller.prepare_service_day(current_day, plan)

	_service_elapsed = 0.0
	_set_phase(SharedTypes.Phase.SERVING)
	_service_controller.begin_service(0.0)
	return true


## Transitions RESULTS -> PLANNING(day + 1) on Days 1-6 and Extra Mode (Day 8+).
func request_continue_from_results() -> bool:
	var current_day := get_day_index()
	if _phase != SharedTypes.Phase.RESULTS or current_day == 7:
		return false
	if (
		_run_controller == null
		or not is_instance_valid(_run_controller)
		or not _run_controller.has_method(&"advance_to_next_planning")
	):
		return false

	var next_day := int(_run_controller.advance_to_next_planning())
	if next_day != current_day + 1:
		return false

	_set_phase(SharedTypes.Phase.PLANNING)
	return true


## Transitions FINISHED(WON) -> PLANNING(day = 8) once after Day 7 victory.
func request_extra_mode() -> bool:
	var current_day := get_day_index()
	if _phase != SharedTypes.Phase.FINISHED or current_day != 7:
		return false
	if _resolve_day_7_outcome() != SharedTypes.DayOutcome.WON:
		return false
	if (
		_run_controller == null
		or not is_instance_valid(_run_controller)
		or not _run_controller.has_method(&"advance_to_next_planning")
	):
		return false

	var next_day := int(_run_controller.advance_to_next_planning())
	if next_day != 8:
		return false

	_set_phase(SharedTypes.Phase.PLANNING)
	return true


## Closes SERVING synchronously and idempotently only when ServiceController
## is bound and reports drained.
func request_close_if_drained() -> void:
	if _phase != SharedTypes.Phase.SERVING or _closing_in_progress or _paused:
		return
	if _service_controller == null or not _service_controller.has_method(&"is_drained"):
		return
	if not _service_controller.is_drained():
		return

	var current_day := get_day_index()
	_closing_in_progress = true
	_set_phase(SharedTypes.Phase.CLOSING)

	var report: Dictionary = { "day_index": current_day }
	if (
		_service_controller != null
		and _service_controller.has_method(&"freeze_and_build_day_report")
	):
		report = _service_controller.freeze_and_build_day_report(current_day)

	var canceled_ids: Array[StringName] = []
	if (
		_kitchen_controller != null
		and _kitchen_controller.has_method(&"cancel_pending_deliveries")
	):
		canceled_ids = _kitchen_controller.cancel_pending_deliveries(current_day)

	if (
		_run_controller != null
		and _run_controller.has_method(&"refund_canceled_deliveries_once")
	):
		_run_controller.refund_canceled_deliveries_once(canceled_ids)

	if (
		_kitchen_controller != null
		and _kitchen_controller.has_method(&"clear_non_fridge_food_for_next_day")
	):
		_kitchen_controller.clear_non_fridge_food_for_next_day()

	if (
		_service_controller != null
		and _service_controller.has_method(&"reset_dirt_and_day_customers")
	):
		_service_controller.reset_dirt_and_day_customers()

	if _run_controller != null and _run_controller.has_method(&"settle_day_once"):
		_run_controller.settle_day_once(report)

	var post_close_phase := SharedTypes.Phase.RESULTS
	if current_day == 7:
		post_close_phase = SharedTypes.Phase.FINISHED
	_set_phase(post_close_phase)
	_closing_in_progress = false


func set_paused(paused: bool) -> bool:
	if paused:
		if (
			_phase != SharedTypes.Phase.PLANNING
			and _phase != SharedTypes.Phase.SERVING
		):
			return false
	if _paused == paused:
		if is_inside_tree() and get_tree() != null and get_tree().paused != _paused:
			get_tree().paused = _paused
		return true
	_paused = paused
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = _paused
	pause_changed.emit(_paused)
	return true


func is_paused() -> bool:
	return _paused


func is_serving() -> bool:
	return _phase == SharedTypes.Phase.SERVING


func get_service_elapsed() -> float:
	return _service_elapsed


func get_phase() -> SharedTypes.Phase:
	return _phase


func get_day_index() -> int:
	if _run_controller != null and is_instance_valid(_run_controller):
		if _run_controller.has_method(&"get_day_index"):
			return int(_run_controller.get_day_index())
		if _run_controller.has_method(&"get_run_view"):
			var run_view: Dictionary = _run_controller.get_run_view()
			if run_view.has("day_index"):
				return int(run_view["day_index"])
	return 1


func get_kitchen_controller() -> Node:
	return _kitchen_controller


func get_service_controller() -> Node:
	return _service_controller


func get_run_controller() -> Node:
	return _run_controller


func get_audio_controller() -> GameAudio:
	return _audio_controller


func is_in_main_menu() -> bool:
	return _in_main_menu


## Transitions from Main Menu to fresh Day 1 Planning, fading BGM out over 5s.
func request_start_play_from_menu() -> bool:
	if not _in_main_menu or _restarting_run:
		return false
	_restarting_run = true
	_in_main_menu = false
	_reset_run_world_and_controllers(true)
	_sync_bgm_stage(true)
	_restarting_run = false
	phase_changed.emit(_phase, get_day_index())
	return true


## Resets the full run cleanly back to Day 1 Planning (e.g. Day 7 LOST Coba lagi),
## preserving AudioController and Settings BGM volume across the reset.
func request_restart_run() -> bool:
	if _restarting_run:
		return false
	_restarting_run = true
	_in_main_menu = false
	_reset_run_world_and_controllers(true)
	_sync_bgm_stage(true)
	_restarting_run = false
	phase_changed.emit(_phase, get_day_index())
	return true


## Returns cleanly to Main Menu in an idle non-run state with Main Menu BGM active.
func request_return_to_main_menu() -> bool:
	if _restarting_run:
		return false
	_restarting_run = true
	_in_main_menu = true
	_reset_run_world_and_controllers(false)
	_sync_bgm_stage(true)
	_restarting_run = false
	phase_changed.emit(_phase, get_day_index())
	return true


func _reset_run_world_and_controllers(start_new_run_now: bool = true) -> void:
	set_paused(false)
	_closing_in_progress = false
	_service_elapsed = 0.0
	_phase = SharedTypes.Phase.PLANNING

	var old_world := get_node_or_null("World")
	if old_world != null:
		var old_idx := old_world.get_index()
		remove_child(old_world)
		old_world.free()
		var fresh_world := RESTAURANT_WORLD_SCENE.instantiate() as Node2D
		if fresh_world != null:
			fresh_world.name = "World"
			fresh_world.position = Vector2(168, 36)
			add_child(fresh_world)
			move_child(fresh_world, mini(old_idx, get_child_count() - 1))

	if _kitchen_controller != null and _kitchen_controller.has_method(&"reset_for_new_run"):
		_kitchen_controller.reset_for_new_run()
	if _service_controller != null and _service_controller.has_method(&"reset_for_new_run"):
		_service_controller.reset_for_new_run()

	_wire_controllers()
	if start_new_run_now:
		if _run_controller != null and _run_controller.has_method(&"reset_for_new_run"):
			_run_controller.reset_for_new_run()
		elif _run_controller != null and _run_controller.has_method(&"start_new_run"):
			_run_controller.start_new_run()
	elif _run_controller != null and _run_controller.has_method(&"reset_to_idle"):
		_run_controller.reset_to_idle()


func _wire_controllers() -> void:
	var world_map := get_node_or_null("World") as WorldMap
	if _kitchen_controller != null and _kitchen_controller.has_method(&"bind_world"):
		_kitchen_controller.bind_world(world_map, self)
	if (
		_kitchen_controller != null
		and _kitchen_controller.has_signal(&"action_feedback")
		and not _kitchen_controller.is_connected(
			&"action_feedback", _on_kitchen_action_feedback_audio
		)
	):
		_kitchen_controller.connect(&"action_feedback", _on_kitchen_action_feedback_audio)
	if _kitchen_controller != null and _kitchen_controller.has_method(&"bind_service"):
		_kitchen_controller.bind_service(_service_controller)
	if _service_controller != null and _service_controller.has_method(&"bind_systems"):
		_service_controller.bind_systems(
			_kitchen_controller as KitchenController,
			_run_controller as RunController,
			self
		)
	if _run_controller != null and _run_controller.has_method(&"bind_systems"):
		_run_controller.bind_systems(
			world_map,
			_kitchen_controller as KitchenController,
			_service_controller as ServiceController,
			self
		)
	var ui := get_node_or_null("UI")
	if ui != null and ui.has_method(&"bind_context"):
		ui.bind_context(
			self,
			world_map,
			_kitchen_controller as KitchenController,
			_service_controller as ServiceController,
			_run_controller as RunController
		)


func _is_valid_kitchen_controller() -> bool:
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return false
	return _kitchen_controller.has_method(&"advance_service_time")


func _is_valid_run_controller() -> bool:
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	return (
		_run_controller.has_method(&"finalize_plan")
		and _run_controller.has_method(&"get_service_plan")
	)


func _is_valid_service_controller() -> bool:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return false
	return (
		_service_controller.has_method(&"prepare_service_day")
		and _service_controller.has_method(&"begin_service")
		and _service_controller.has_method(&"is_drained")
	)


func _set_phase(next_phase: SharedTypes.Phase) -> void:
	if (
		_paused
		and next_phase != SharedTypes.Phase.PLANNING
		and next_phase != SharedTypes.Phase.SERVING
	):
		set_paused(false)
	_phase = next_phase
	_sync_bgm_stage(true)
	phase_changed.emit(_phase, get_day_index())


func _sync_bgm_stage(fade_out: bool) -> void:
	if _audio_controller == null or not is_instance_valid(_audio_controller):
		return
	var wants_bgm := _in_main_menu or (_phase == SharedTypes.Phase.SERVING)
	_audio_controller.set_music_stage(wants_bgm, fade_out)


func _on_kitchen_action_feedback_audio(code: StringName) -> void:
	if _audio_controller == null or not is_instance_valid(_audio_controller):
		return
	if code == &"invalid_key":
		_audio_controller.play_error_sfx()
	elif code == &"order_served":
		_audio_controller.play_serve_sfx()


func _resolve_day_7_outcome() -> SharedTypes.DayOutcome:
	if (
		_run_controller != null
		and is_instance_valid(_run_controller)
		and _run_controller.has_method(&"get_run_view")
	):
		var run_view: Dictionary = _run_controller.get_run_view()
		if run_view.has("goal_outcome"):
			return run_view["goal_outcome"] as SharedTypes.DayOutcome
	return SharedTypes.DayOutcome.UNDECIDED
