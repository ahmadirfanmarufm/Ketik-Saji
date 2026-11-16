class_name GameRoot
extends Node2D
## Persistent scene root owning top-level phase transitions and the single
## monotonic `service_elapsed` clock.
##
## Holds no orders, stock, plates, or cash. Optional controller references
## remain null until later Milestone 0 controller wiring.

signal phase_changed(phase: int, day_index: int)

var _phase: SharedTypes.Phase = SharedTypes.Phase.PLANNING
var _day_index: int = 1
var _service_elapsed: float = 0.0
var _day_7_outcome: SharedTypes.DayOutcome = SharedTypes.DayOutcome.UNDECIDED
var _closing_in_progress: bool = false
var _extra_mode_entered: bool = false
var _initialized: bool = false

var _kitchen_controller: Node = null
var _service_controller: Node = null
var _run_controller: Node = null


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_phase = SharedTypes.Phase.PLANNING
	_day_index = 1
	_service_elapsed = 0.0
	if _run_controller != null and _run_controller.has_method(&"start_new_run"):
		_run_controller.start_new_run()


func _process(delta: float) -> void:
	if _phase != SharedTypes.Phase.SERVING or delta <= 0.0:
		return

	_service_elapsed += delta
	if _kitchen_controller != null and _kitchen_controller.has_method(&"advance_service_time"):
		_kitchen_controller.advance_service_time(_service_elapsed)
	if _service_controller != null and _service_controller.has_method(&"advance_service_time"):
		_service_controller.advance_service_time(_service_elapsed)
	if _service_controller != null and _service_controller.has_method(&"is_drained"):
		if _service_controller.is_drained():
			request_close_if_drained()


## Wires optional controller references during root/test setup.
func bind_controllers(kitchen: Node, service: Node, run: Node) -> void:
	_kitchen_controller = kitchen
	_service_controller = service
	_run_controller = run


## Transitions PLANNING -> SERVING once when plan validation passes.
func start_service_requested() -> bool:
	if _phase != SharedTypes.Phase.PLANNING:
		return false

	var plan: Dictionary = {}
	if _run_controller != null:
		if _run_controller.has_method(&"finalize_plan") and not _run_controller.finalize_plan():
			return false
		if _run_controller.has_method(&"get_service_plan"):
			plan = _run_controller.get_service_plan()

	if _service_controller != null and _service_controller.has_method(&"prepare_service_day"):
		_service_controller.prepare_service_day(_day_index, plan)

	_service_elapsed = 0.0
	_set_phase(SharedTypes.Phase.SERVING)

	if _service_controller != null and _service_controller.has_method(&"begin_service"):
		_service_controller.begin_service(0.0)
	return true


## Transitions RESULTS -> PLANNING(day + 1) on Days 1-6 and Extra Mode (Day 8+).
func request_continue_from_results() -> bool:
	if _phase != SharedTypes.Phase.RESULTS or _day_index == 7:
		return false

	if _run_controller != null and _run_controller.has_method(&"advance_to_next_planning"):
		_day_index = _run_controller.advance_to_next_planning()
	else:
		_day_index += 1

	_set_phase(SharedTypes.Phase.PLANNING)
	return true


## Transitions FINISHED(WON) -> PLANNING(day = 8) once after Day 7 victory.
func request_extra_mode() -> bool:
	if _phase != SharedTypes.Phase.FINISHED or _day_index != 7 or _extra_mode_entered:
		return false
	if _resolve_day_7_outcome() != SharedTypes.DayOutcome.WON:
		return false

	_extra_mode_entered = true
	if _run_controller != null and _run_controller.has_method(&"advance_to_next_planning"):
		_day_index = _run_controller.advance_to_next_planning()
	else:
		_day_index = 8

	_set_phase(SharedTypes.Phase.PLANNING)
	return true


## Closes SERVING synchronously and idempotently only when ServiceController
## is bound and reports drained.
func request_close_if_drained() -> void:
	if _phase != SharedTypes.Phase.SERVING or _closing_in_progress:
		return
	if _service_controller == null or not _service_controller.has_method(&"is_drained"):
		return
	if not _service_controller.is_drained():
		return

	_closing_in_progress = true
	_set_phase(SharedTypes.Phase.CLOSING)

	var report: Dictionary = {}
	if (
		_service_controller != null
		and _service_controller.has_method(&"freeze_and_build_day_report")
	):
		report = _service_controller.freeze_and_build_day_report(_day_index)

	var canceled_ids: Array[StringName] = []
	if (
		_kitchen_controller != null
		and _kitchen_controller.has_method(&"cancel_pending_deliveries")
	):
		canceled_ids = _kitchen_controller.cancel_pending_deliveries(_day_index)

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
		var settlement: Dictionary = _run_controller.settle_day_once(report)
		if settlement.has("day7_outcome"):
			_day_7_outcome = settlement["day7_outcome"] as SharedTypes.DayOutcome

	var post_close_phase := SharedTypes.Phase.RESULTS
	if _day_index == 7:
		post_close_phase = SharedTypes.Phase.FINISHED
	_set_phase(post_close_phase)
	_closing_in_progress = false


func is_serving() -> bool:
	return _phase == SharedTypes.Phase.SERVING


func get_service_elapsed() -> float:
	return _service_elapsed


func get_phase() -> SharedTypes.Phase:
	return _phase


func get_day_index() -> int:
	return _day_index


func _set_phase(next_phase: SharedTypes.Phase) -> void:
	_phase = next_phase
	phase_changed.emit(_phase, _day_index)


func _resolve_day_7_outcome() -> SharedTypes.DayOutcome:
	if _run_controller != null and _run_controller.has_method(&"get_run_view"):
		var run_view: Dictionary = _run_controller.get_run_view()
		if run_view.has("goal_outcome"):
			return run_view["goal_outcome"] as SharedTypes.DayOutcome
	return _day_7_outcome
