class_name GameRoot
extends Node2D
## Persistent scene root owning top-level phase transitions and the single
## monotonic `service_elapsed` clock.
##
## Holds no orders, stock, plates, or cash. Orchestrates KitchenController,
## ServiceController, and RunController lifecycle boundaries synchronously.

signal phase_changed(phase: int, day_index: int)

var _phase: SharedTypes.Phase = SharedTypes.Phase.PLANNING
var _service_elapsed: float = 0.0
var _closing_in_progress: bool = false
var _initialized: bool = false

var _kitchen_controller: Node = null
var _service_controller: Node = null
var _run_controller: Node = null


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_phase = SharedTypes.Phase.PLANNING
	_service_elapsed = 0.0

	if _kitchen_controller == null:
		_kitchen_controller = get_node_or_null("KitchenController")
	if _service_controller == null:
		_service_controller = get_node_or_null("ServiceController")
	if _run_controller == null:
		_run_controller = get_node_or_null("RunController")

	_wire_controllers()
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
	if _phase != SharedTypes.Phase.PLANNING:
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
	if _phase != SharedTypes.Phase.SERVING or _closing_in_progress:
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


func _wire_controllers() -> void:
	var world_map := get_node_or_null("World") as WorldMap
	if _kitchen_controller != null and _kitchen_controller.has_method(&"bind_world"):
		_kitchen_controller.bind_world(world_map, self)
	if _run_controller != null and _run_controller.has_method(&"bind_systems"):
		_run_controller.bind_systems(
			world_map,
			_kitchen_controller as KitchenController,
			_service_controller as ServiceController,
			self
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
	_phase = next_phase
	phase_changed.emit(_phase, get_day_index())


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
