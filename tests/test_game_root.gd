extends SceneTree
## Headless tests for GameRoot Foundation: phase machine, monotonic service clock,
## frozen API guards, and main scene wiring.

class MockKitchen extends Node:
	var log_ref: Array[String] = []
	var last_now: float = -1.0

	func advance_service_time(now: float) -> void:
		log_ref.append("kitchen_advance:%.2f" % now)
		last_now = now


class MockService extends Node:
	var log_ref: Array[String] = []
	var drained: bool = false

	func prepare_service_day(day: int, _plan: Dictionary) -> void:
		log_ref.append("service_prepare:%d" % day)

	func begin_service(now: float) -> void:
		log_ref.append("service_begin:%.2f" % now)

	func advance_service_time(now: float) -> void:
		log_ref.append("service_advance:%.2f" % now)

	func is_drained() -> bool:
		return drained


class MockRun extends Node:
	var allow_plan: bool = true
	var outcome: SharedTypes.DayOutcome = SharedTypes.DayOutcome.UNDECIDED
	var current_day: int = 1

	func finalize_plan() -> bool:
		return allow_plan

	func get_service_plan() -> Dictionary:
		return { "day_index": current_day }

	func settle_day_once(_report: Dictionary) -> Dictionary:
		return { "day7_outcome": outcome }

	func advance_to_next_planning() -> int:
		current_day += 1
		return current_day

	func get_day_index() -> int:
		return current_day

	func get_run_view() -> Dictionary:
		return {
			"day_index": current_day,
			"goal_outcome": outcome,
		}


var _fails: int = 0
var _emitted_phases: Array[Array] = []


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _on_phase_changed(phase: int, day_index: int) -> void:
	_emitted_phases.append([phase, day_index])


func _init() -> void:
	await _test_main_scene_and_initial_state()
	await _test_phase_transitions_and_guards()
	await _test_service_clock_monotonic_and_resets()
	await _test_controller_boundaries_and_ordering()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _test_main_scene_and_initial_state() -> void:
	var script_res := load("res://scripts/core/game_root.gd")
	_check("game_root.gd loads", script_res != null)

	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	_check("game_root.tscn loads", packed != null)
	if packed == null:
		return

	var instance := packed.instantiate() as GameRoot
	_check("root is GameRoot", instance != null)
	if instance == null:
		return

	root.add_child(instance)
	await process_frame

	_check("World instance preserved", instance.get_node_or_null("World") != null)
	_check("initial phase PLANNING", instance.get_phase() == SharedTypes.Phase.PLANNING)
	_check("initial day_index == 1", instance.get_day_index() == 1)
	_check("initial not serving", not instance.is_serving())
	_check("initial service_elapsed == 0", is_zero_approx(instance.get_service_elapsed()))

	var timer_count: int = 0
	for child in instance.get_children():
		if child is Timer:
			timer_count += 1
	_check("no Timer children on GameRoot", timer_count == 0)

	instance.free()


func _test_phase_transitions_and_guards() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	var game_root := packed.instantiate() as GameRoot
	var mock_service := MockService.new()
	var mock_run := MockRun.new()
	mock_service.drained = true
	game_root.bind_controllers(null, mock_service, mock_run)
	root.add_child(game_root)
	await process_frame

	_emitted_phases.clear()
	game_root.phase_changed.connect(_on_phase_changed)

	_check(
		"reject continue in PLANNING",
		not game_root.request_continue_from_results()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)
	_check(
		"reject extra mode in PLANNING",
		not game_root.request_extra_mode()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)
	game_root.request_close_if_drained()
	_check("ignore close in PLANNING", game_root.get_phase() == SharedTypes.Phase.PLANNING)
	_check("no spurious signals on rejects", _emitted_phases.is_empty())

	for day in range(1, 7):
		_emitted_phases.clear()
		_check("day %d start_service ok" % day, game_root.start_service_requested())
		_check("day %d is_serving" % day, game_root.is_serving())
		_check(
			"day %d duplicate start_service rejected" % day,
			not game_root.start_service_requested()
		)
		game_root.request_close_if_drained()
		_check("day %d reached RESULTS" % day, game_root.get_phase() == SharedTypes.Phase.RESULTS)
		game_root.request_close_if_drained()
		_check(
		"day %d duplicate close ignored" % day,
		game_root.get_phase() == SharedTypes.Phase.RESULTS
	)
		_check("day %d continue ok" % day, game_root.request_continue_from_results())
		_check(
			"day %d emissions exact" % day,
			_emitted_phases == [
				[SharedTypes.Phase.SERVING, day],
				[SharedTypes.Phase.CLOSING, day],
				[SharedTypes.Phase.RESULTS, day],
				[SharedTypes.Phase.PLANNING, day + 1],
			]
		)

	_check("reached day 7 PLANNING", game_root.get_day_index() == 7)
	mock_run.outcome = SharedTypes.DayOutcome.LOST
	_check("day 7 start_service ok", game_root.start_service_requested())
	game_root.request_close_if_drained()
	_check("day 7 enters FINISHED", game_root.get_phase() == SharedTypes.Phase.FINISHED)
	_check("day 7 continue rejected", not game_root.request_continue_from_results())
	_check("day 7 LOST rejects extra mode", not game_root.request_extra_mode())

	mock_run.outcome = SharedTypes.DayOutcome.WON
	_check("day 7 WON enters extra mode", game_root.request_extra_mode())
	_check(
		"extra mode is PLANNING day 8",
		game_root.get_phase() == SharedTypes.Phase.PLANNING and game_root.get_day_index() == 8
	)
	_check("extra mode repeat rejected", not game_root.request_extra_mode())
	_check("day 8 start_service ok", game_root.start_service_requested())
	game_root.request_close_if_drained()
	_check("day 8 enters RESULTS", game_root.get_phase() == SharedTypes.Phase.RESULTS)
	_check("day 8 continue advances to 9", game_root.request_continue_from_results()
		and game_root.get_day_index() == 9)

	mock_service.free()
	mock_run.free()
	game_root.free()


func _test_service_clock_monotonic_and_resets() -> void:
	var game_root := GameRoot.new()
	var mock_kitchen := MockKitchen.new()
	var mock_service := MockService.new()
	var mock_run := MockRun.new()
	game_root.bind_controllers(mock_kitchen, mock_service, mock_run)
	root.add_child(game_root)
	await process_frame

	game_root._process(5.0)
	_check("clock frozen in PLANNING", is_zero_approx(game_root.get_service_elapsed()))

	_check("start day 1 SERVING", game_root.start_service_requested())
	game_root._process(1.25)
	game_root._process(2.75)
	game_root._process(-3.0)
	_check("clock monotonic in SERVING", is_equal_approx(game_root.get_service_elapsed(), 4.0))

	var modal := Panel.new()
	root.add_child(modal)
	game_root._process(1.5)
	_check("UI node does not pause clock", is_equal_approx(game_root.get_service_elapsed(), 5.5))
	modal.free()

	mock_service.drained = true
	game_root.request_close_if_drained()
	var after_close := game_root.get_service_elapsed()
	game_root._process(10.0)
	_check(
		"clock frozen in RESULTS",
		is_equal_approx(game_root.get_service_elapsed(), after_close)
	)

	mock_service.drained = false
	_check("continue to day 2 PLANNING", game_root.request_continue_from_results())
	game_root._process(4.0)
	_check(
		"clock frozen in day 2 PLANNING",
		is_equal_approx(game_root.get_service_elapsed(), after_close)
	)

	_check("start day 2 resets clock to 0", game_root.start_service_requested()
		and is_zero_approx(game_root.get_service_elapsed()))

	mock_run.free()
	mock_service.free()
	mock_kitchen.free()
	game_root.free()


func _test_controller_boundaries_and_ordering() -> void:
	var shared_log: Array[String] = []
	var game_root := GameRoot.new()
	var kitchen := MockKitchen.new()
	var service := MockService.new()
	var invalid_kitchen := Node.new()
	var invalid_service := Node.new()
	var invalid_run := Node.new()
	var run := MockRun.new()
	kitchen.log_ref = shared_log
	service.log_ref = shared_log
	run.allow_plan = true
	root.add_child(game_root)
	await process_frame

	game_root.bind_controllers(null, service, run)
	_check(
		"unbound KitchenController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	game_root.bind_controllers(invalid_kitchen, service, run)
	_check(
		"invalid KitchenController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	run.allow_plan = false
	game_root.bind_controllers(kitchen, service, null)
	_check(
		"unbound RunController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	game_root.bind_controllers(kitchen, service, invalid_run)
	_check(
		"invalid RunController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	run.allow_plan = true
	game_root.bind_controllers(kitchen, null, run)
	_check(
		"unbound ServiceController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	game_root.bind_controllers(kitchen, invalid_service, run)
	_check(
		"invalid ServiceController blocks start_service",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	run.allow_plan = false
	game_root.bind_controllers(kitchen, service, run)

	_check(
		"invalid plan blocks SERVING",
		not game_root.start_service_requested()
		and game_root.get_phase() == SharedTypes.Phase.PLANNING
	)

	run.allow_plan = true
	_check("valid plan starts SERVING", game_root.start_service_requested())

	_emitted_phases.clear()
	game_root.phase_changed.connect(_on_phase_changed)

	game_root.bind_controllers(kitchen, null, run)
	game_root.request_close_if_drained()
	_check(
		"unbound ServiceController blocks close",
		game_root.get_phase() == SharedTypes.Phase.SERVING and _emitted_phases.is_empty()
	)

	game_root.bind_controllers(kitchen, invalid_service, run)
	game_root.request_close_if_drained()
	_check(
		"controller missing is_drained blocks close",
		game_root.get_phase() == SharedTypes.Phase.SERVING and _emitted_phases.is_empty()
	)

	game_root.bind_controllers(kitchen, service, run)
	game_root.request_close_if_drained()
	_check(
		"non-drained service blocks close",
		game_root.get_phase() == SharedTypes.Phase.SERVING and _emitted_phases.is_empty()
	)

	service.drained = true
	game_root._process(2.5)
	var expected_order := [
		"service_prepare:1",
		"service_begin:0.00",
		"kitchen_advance:2.50",
		"service_advance:2.50",
	]
	_check(
		"deliveries tick before service before drained close",
		shared_log == expected_order
		and game_root.get_phase() == SharedTypes.Phase.RESULTS
	)
	_check(
		"drained transition emitted CLOSING then RESULTS",
		_emitted_phases == [
			[SharedTypes.Phase.CLOSING, 1],
			[SharedTypes.Phase.RESULTS, 1],
		]
	)

	_emitted_phases.clear()
	game_root.request_close_if_drained()
	_check(
		"repeated close after drained emits no duplicate transition",
		game_root.get_phase() == SharedTypes.Phase.RESULTS and _emitted_phases.is_empty()
	)

	invalid_kitchen.free()
	invalid_run.free()
	invalid_service.free()
	kitchen.free()
	service.free()
	run.free()
	game_root.free()
