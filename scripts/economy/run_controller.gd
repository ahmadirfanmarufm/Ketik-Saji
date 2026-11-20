class_name RunController
extends Node
## Sole authority for run day index, cash balance, unlocked/selected daily menu,
## installed fixture ownership (`starter_grant` and `actual_amount_paid`),
## paid purchase/refund ledger, demand penalty debt, day settlement, and Day 7
## win/loss latch.
##
## Uses EconomyConfig and UtilityDef resources rather than hardcoded balance
## constants, and binds existing scene starter fixtures without duplicating nodes.

signal run_state_changed()

const DEFAULT_CONFIG_PATH: String = "res://data/economy_config.tres"
const UTILITY_IDS: Array[StringName] = [
	&"box",
	&"fridge",
	&"stove",
	&"washer",
	&"plate_rack",
	&"rice_cooker",
	&"dining_table",
]

const STARTER_FIXTURE_SPECS: Array[Dictionary] = [
	{
		"instance_id": &"storage_box",
		"utility_id": &"box",
		"fixture_kind": SharedTypes.FixtureKind.BOX,
	},
	{
		"instance_id": &"stove",
		"utility_id": &"stove",
		"fixture_kind": SharedTypes.FixtureKind.STOVE,
	},
	{
		"instance_id": &"washer",
		"utility_id": &"washer",
		"fixture_kind": SharedTypes.FixtureKind.WASHER,
	},
	{
		"instance_id": &"plate_rack",
		"utility_id": &"plate_rack",
		"fixture_kind": SharedTypes.FixtureKind.PLATE_RACK,
	},
	{
		"instance_id": &"rice_cooker",
		"utility_id": &"rice_cooker",
		"fixture_kind": SharedTypes.FixtureKind.RICE_COOKER,
	},
	{
		"instance_id": &"dining_table_01",
		"utility_id": &"dining_table",
		"fixture_kind": SharedTypes.FixtureKind.DINING_TABLE,
	},
	{
		"instance_id": &"dining_table_02",
		"utility_id": &"dining_table",
		"fixture_kind": SharedTypes.FixtureKind.DINING_TABLE,
	},
]

@export var economy_config: EconomyConfig = null

var _world_map: WorldMap = null
var _kitchen_controller: KitchenController = null
var _service_controller: ServiceController = null
var _game_root: Node = null

var _utility_defs: Dictionary[StringName, UtilityDef] = {}
var _recipe_defs_fallback: Dictionary[StringName, RecipeDef] = {}
var _run_started: bool = false
var _day_index: int = 1
var _cash: int = 0
var _begin_day_cash: int = 0
var _unlocked_recipe_ids: Array[StringName] = []
var _selected_recipe_ids: Array[StringName] = []
var _fixture_instances: Dictionary[StringName, Dictionary] = {}
var _purchase_ledger: Dictionary[StringName, Dictionary] = {}
var _credited_order_ids: Dictionary[StringName, Dictionary] = {}
var _settled_days: Dictionary[int, Dictionary] = {}
var _demand_penalty_debt: int = 0
var _day_7_outcome: SharedTypes.DayOutcome = SharedTypes.DayOutcome.UNDECIDED
var _extra_mode_active: bool = false
var _frozen_service_plan: Dictionary = {}
var _employees: Dictionary[StringName, Dictionary] = {}
var _role_hire_sequences: Dictionary[StringName, int] = {}
var _next_purchase_seq: int = 0
var _next_employee_seq: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	_ensure_resources_loaded()


## Wires sibling WorldMap, KitchenController, ServiceController, and GameRoot references.
func bind_systems(
	world_map: WorldMap,
	kitchen: KitchenController,
	service: ServiceController,
	game_root: Node = null
) -> void:
	if (
		_kitchen_controller != null
		and is_instance_valid(_kitchen_controller)
		and _kitchen_controller.has_signal(&"kitchen_state_changed")
		and _kitchen_controller.is_connected(
			&"kitchen_state_changed",
			_on_kitchen_state_changed_sync
		)
	):
		_kitchen_controller.disconnect(&"kitchen_state_changed", _on_kitchen_state_changed_sync)
	_world_map = world_map
	_kitchen_controller = kitchen
	_service_controller = service
	_game_root = game_root
	if (
		_kitchen_controller != null
		and is_instance_valid(_kitchen_controller)
		and _kitchen_controller.has_signal(&"kitchen_state_changed")
		and not _kitchen_controller.is_connected(
			&"kitchen_state_changed",
			_on_kitchen_state_changed_sync
		)
	):
		_kitchen_controller.connect(&"kitchen_state_changed", _on_kitchen_state_changed_sync)


func get_purchase_record(purchase_id: StringName) -> Dictionary:
	_sync_purchase_ledger_with_kitchen()
	if not _purchase_ledger.has(purchase_id):
		return {}
	return (_purchase_ledger[purchase_id] as Dictionary).duplicate(true)


func get_day_index() -> int:
	return _day_index


func has_fixture_instance(instance_id: StringName) -> bool:
	return _fixture_instances.has(instance_id)


func can_purchase_ingredients_for_storage(storage_unit_id: StringName) -> bool:
	return _can_attempt_ingredient_purchase(storage_unit_id)


func get_fixture_instance(instance_id: StringName) -> Dictionary:
	if not _fixture_instances.has(instance_id):
		return {}
	return _fixture_instances[instance_id].duplicate(true)


func is_run_started() -> bool:
	return _run_started


func reset_to_idle() -> void:
	_run_started = false
	_rng.seed = 1337
	_ensure_resources_loaded()
	_day_index = 1
	_cash = economy_config.starting_cash if economy_config != null else 0
	_begin_day_cash = _cash
	_demand_penalty_debt = 0
	_day_7_outcome = SharedTypes.DayOutcome.UNDECIDED
	_extra_mode_active = false
	_unlocked_recipe_ids.clear()
	_selected_recipe_ids.clear()
	_fixture_instances.clear()
	_purchase_ledger.clear()
	_credited_order_ids.clear()
	_settled_days.clear()
	_frozen_service_plan.clear()
	_employees.clear()
	_role_hire_sequences.clear()
	_next_purchase_seq = 0
	_next_employee_seq = 0
	run_state_changed.emit()


func reset_for_new_run() -> void:
	_run_started = false
	_rng.seed = 1337
	start_new_run()


func start_new_run() -> void:
	if _run_started:
		return
	_ensure_resources_loaded()
	if economy_config == null:
		push_error("RunController: EconomyConfig is missing.")
		return

	_day_index = 1
	_cash = economy_config.starting_cash
	_begin_day_cash = _cash
	_demand_penalty_debt = 0
	_day_7_outcome = SharedTypes.DayOutcome.UNDECIDED
	_extra_mode_active = false
	_unlocked_recipe_ids = economy_config.get_unlocked_recipe_ids(_day_index)
	_selected_recipe_ids = _unlocked_recipe_ids.duplicate()
	_fixture_instances.clear()
	_purchase_ledger.clear()
	_credited_order_ids.clear()
	_settled_days.clear()
	_frozen_service_plan.clear()
	_employees.clear()
	_role_hire_sequences.clear()
	_next_purchase_seq = 0
	_next_employee_seq = 0

	_bind_starter_fixtures()
	_run_started = true
	run_state_changed.emit()


func select_daily_menu(recipe_ids: Array[StringName]) -> bool:
	if _is_game_paused() or not _is_planning_phase():
		return false
	if recipe_ids.is_empty():
		return false

	var seen: Dictionary[StringName, bool] = {}
	var validated: Array[StringName] = []
	for recipe_id in recipe_ids:
		if recipe_id == &"" or seen.has(recipe_id):
			return false
		if not _unlocked_recipe_ids.has(recipe_id):
			return false
		seen[recipe_id] = true
		validated.append(recipe_id)

	_selected_recipe_ids = validated
	run_state_changed.emit()
	return true


func get_utility_def(utility_id: StringName) -> UtilityDef:
	_ensure_resources_loaded()
	return _utility_defs.get(utility_id, null) as UtilityDef


func get_utility_ids() -> Array[StringName]:
	_ensure_resources_loaded()
	var ids: Array[StringName] = []
	for uid in UTILITY_IDS:
		if _utility_defs.has(uid):
			ids.append(uid)
	for uid: StringName in _utility_defs:
		if not ids.has(uid):
			ids.append(uid)
	return ids


func get_fixture_daily_electricity_cost(utility_id: StringName, kind: int = -1) -> int:
	_ensure_resources_loaded()
	var def := _utility_defs.get(utility_id, null) as UtilityDef
	var resolved_kind := kind
	if resolved_kind < 0 and def != null:
		resolved_kind = int(def.fixture_kind)
	if economy_config != null:
		if resolved_kind == SharedTypes.FixtureKind.FRIDGE:
			return economy_config.fridge_electricity_per_day
		if resolved_kind == SharedTypes.FixtureKind.RICE_COOKER:
			return economy_config.rice_cooker_electricity_per_day
	if def != null and def.daily_electricity_cost > 0:
		return def.daily_electricity_cost
	return 0


func get_daily_electricity_estimate() -> int:
	return _compute_daily_electricity_charge()


func get_employee_role_ids() -> Array[StringName]:
	_ensure_resources_loaded()
	if economy_config == null:
		return []
	return economy_config.get_employee_role_ids()


func get_employee_role_def(role_id: StringName) -> Dictionary:
	_ensure_resources_loaded()
	if economy_config == null:
		return {}
	return economy_config.get_employee_role_def(role_id)


func get_hired_employees() -> Array[Dictionary]:
	var ids: Array[StringName] = []
	for emp_id: StringName in _employees:
		ids.append(emp_id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var out: Array[Dictionary] = []
	for emp_id in ids:
		out.append(_employees[emp_id].duplicate(true))
	return out


func get_employee_count_by_role(role_id: StringName) -> int:
	var count := 0
	for rec: Dictionary in _employees.values():
		if StringName(rec.get("role_id", &"")) == role_id:
			count += 1
	return count


func get_daily_salary_estimate() -> int:
	return _compute_daily_salary_charge()


func get_workforce_summary() -> Dictionary:
	_ensure_resources_loaded()
	var total := _employees.size()
	var by_role: Dictionary = {}
	var crowding := (
		economy_config.compute_crowding_multiplier(total)
		if economy_config != null
		else 1.0
	)
	for role_id in get_employee_role_ids():
		var cnt := get_employee_count_by_role(role_id)
		var def := get_employee_role_def(role_id)
		var factor := (
			economy_config.compute_effective_role_factor(cnt, total)
			if economy_config != null
			else float(cnt)
		)
		var base_interval := float(def.get("base_interval_seconds", 4.0))
		by_role[role_id] = {
			"role_id": role_id,
			"display_name": String(def.get("display_name", String(role_id))),
			"count": cnt,
			"hire_cost": int(def.get("hire_cost", 0)),
			"daily_salary": int(def.get("daily_salary", 0)),
			"effective_factor": factor,
			"effective_interval": (base_interval / factor) if factor > 0.0 else 0.0,
		}
	var crowding_overhead := (
		economy_config.compute_crowding_overhead(total)
		if economy_config != null
		else 0
	)
	return {
		"total_employees": total,
		"daily_salary_total": _compute_daily_salary_charge(),
		"crowding_multiplier": crowding,
		"crowding_overhead": crowding_overhead,
		"crowded": (
			economy_config != null and total > economy_config.employee_crowding_threshold
		),
		"by_role": by_role,
	}


func can_hire_employee(role_id: StringName) -> Dictionary:
	if not _run_started or economy_config == null:
		return {"ok": false, "reason": &"run_not_started"}
	if _is_game_paused():
		return {"ok": false, "reason": &"paused"}
	if not _is_planning_phase():
		return {"ok": false, "reason": &"not_planning"}
	var role_def := economy_config.get_employee_role_def(role_id)
	if role_def.is_empty():
		return {"ok": false, "reason": &"invalid_role"}
	var hire_cost := int(role_def.get("hire_cost", 0))
	var daily_salary := int(role_def.get("daily_salary", 0))
	if hire_cost <= 0:
		return {"ok": false, "reason": &"invalid_role"}
	if _cash < hire_cost:
		return {
			"ok": false,
			"reason": &"insufficient_funds",
			"hire_cost": hire_cost,
			"daily_salary": daily_salary,
		}
	return {
		"ok": true,
		"reason": &"",
		"hire_cost": hire_cost,
		"daily_salary": daily_salary,
		"role_def": role_def,
	}


func request_employee_hire(role_id: StringName) -> StringName:
	var check := can_hire_employee(role_id)
	if not bool(check.get("ok", false)):
		return &""
	var role_def: Dictionary = check.get("role_def", {})
	var hire_cost := int(check.get("hire_cost", 0))
	var daily_salary := int(check.get("daily_salary", 0))

	_next_employee_seq += 1
	_next_purchase_seq += 1
	var role_seq := int(_role_hire_sequences.get(role_id, 0)) + 1
	_role_hire_sequences[role_id] = role_seq
	var role_display := String(role_def.get("display_name", String(role_id)))
	var stable_name := "%s #%d" % [role_display, role_seq]
	var employee_id := StringName("emp_%04d" % _next_employee_seq)
	var purchase_id := StringName("pur_%d_%04d" % [_day_index, _next_purchase_seq])

	_cash -= hire_cost
	_employees[employee_id] = {
		"employee_id": employee_id,
		"role_id": role_id,
		"role_enum": int(role_def.get("role_enum", SharedTypes.EmployeeRole.COOK)),
		"role_display_name": role_display,
		"role_number": role_seq,
		"display_name": stable_name,
		"hired_day": _day_index,
		"hire_cost": hire_cost,
		"daily_salary": daily_salary,
		"active": true,
	}
	_purchase_ledger[purchase_id] = {
		"purchase_id": purchase_id,
		"day_index": _day_index,
		"kind": &"EMPLOYEE_HIRE",
		"storage_unit_id": &"",
		"item_or_fixture_id": role_id,
		"employee_id": employee_id,
		"quantity": 1,
		"actual_amount_paid": hire_cost,
		"status": &"DELIVERED",
	}
	run_state_changed.emit()
	return employee_id


func request_employee_dismiss(employee_id: StringName) -> bool:
	if not _run_started or _is_game_paused() or not _is_planning_phase():
		return false
	if employee_id == &"" or not _employees.has(employee_id):
		return false
	_employees.erase(employee_id)
	run_state_changed.emit()
	return true


func get_compatible_empty_slots(utility_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if _world_map == null or not _world_map.has_method(&"get_placement_slot_ids"):
		return result
	for slot_id in _world_map.get_placement_slot_ids():
		var check := can_purchase_fixture(utility_id, slot_id)
		var reason: StringName = check.get("reason", &"")
		if bool(check.get("ok", false)) or reason == &"insufficient_cash" or reason == &"not_planning":
			result.append(slot_id)
	return result


func can_purchase_fixture(utility_id: StringName, slot_id: StringName) -> Dictionary:
	_ensure_resources_loaded()
	if not _run_started or economy_config == null:
		return { "ok": false, "reason": &"not_started" }
	if utility_id == &"" or not _utility_defs.has(utility_id):
		return { "ok": false, "reason": &"invalid_utility" }
	var def := _utility_defs[utility_id] as UtilityDef
	if def == null or not def.validate().is_empty() or def.purchase_price <= 0:
		return { "ok": false, "reason": &"invalid_utility" }
	if slot_id == &"" or _world_map == null or _world_map.registry == null or _world_map.grid == null:
		return { "ok": false, "reason": &"invalid_slot" }

	var slot_node := _world_map.registry.get_object(slot_id)
	if slot_node == null or not slot_node.has_meta(WorldMap.SLOT_ID_META):
		return { "ok": false, "reason": &"invalid_slot" }
	if StringName(slot_node.get_meta(WorldMap.SLOT_ID_META, &"")) != slot_id:
		return { "ok": false, "reason": &"invalid_slot" }

	for rec: Dictionary in _fixture_instances.values():
		if rec.get("slot_id", &"") == slot_id:
			return { "ok": false, "reason": &"slot_occupied" }

	var slot_fp: Vector2i = slot_node.get_meta(WorldMap.FOOTPRINT_SIZE_META, Vector2i.ONE)
	if (
		def.footprint.x <= 0
		or def.footprint.y <= 0
		or def.footprint.x > slot_fp.x
		or def.footprint.y > slot_fp.y
	):
		return { "ok": false, "reason": &"invalid_footprint" }

	var origin_cell := _world_map.global_to_cell(slot_node.global_position)
	var cells: Array[Vector2i] = []
	for dy in range(def.footprint.y):
		for dx in range(def.footprint.x):
			var c := origin_cell + Vector2i(dx, dy)
			if not _world_map.grid.is_in_bounds(c):
				return { "ok": false, "reason": &"invalid_footprint" }
			if _world_map.grid.is_occupied(c):
				return { "ok": false, "reason": &"slot_occupied" }
			cells.append(c)

	var allowed: PackedInt32Array = slot_node.get_meta(
		WorldMap.ALLOWED_FIXTURE_KINDS_META,
		PackedInt32Array()
	)
	var kind_ok := false
	for k in allowed:
		if int(k) == int(def.fixture_kind):
			kind_ok = true
			break
	if not kind_ok:
		return { "ok": false, "reason": &"incompatible_slot" }

	var has_access := false
	for n in _world_map.grid.get_footprint_neighbors(cells):
		if _world_map.grid.is_free(n) and not cells.has(n):
			has_access = true
			break
	if not has_access:
		return { "ok": false, "reason": &"no_cardinal_access" }

	if _is_game_paused() or not _is_planning_phase():
		return { "ok": false, "reason": &"not_planning" }
	if _cash < def.purchase_price:
		return { "ok": false, "reason": &"insufficient_cash" }

	return { "ok": true, "reason": &"ok", "cells": cells }


func request_fixture_purchase(utility_id: StringName, slot_id: StringName) -> bool:
	var check := can_purchase_fixture(utility_id, slot_id)
	if not bool(check.get("ok", false)):
		return false

	var def := _utility_defs[utility_id] as UtilityDef
	var kind: SharedTypes.FixtureKind = def.fixture_kind
	var prefix: StringName = (
		&"dining_table" if kind == SharedTypes.FixtureKind.DINING_TABLE else utility_id
	)
	var idx := 1
	var instance_id := StringName("%s_%02d" % [prefix, idx])
	while _fixture_instances.has(instance_id) or _world_map.registry.has_object(instance_id):
		idx += 1
		instance_id = StringName("%s_%02d" % [prefix, idx])

	var spawned: Node2D = null
	if _world_map.has_method(&"spawn_placed_fixture"):
		spawned = _world_map.spawn_placed_fixture(instance_id, int(kind), slot_id, def.footprint)
	if spawned == null:
		return false

	var registered_ok := false
	if kind == SharedTypes.FixtureKind.DINING_TABLE:
		if _service_controller != null:
			registered_ok = _service_controller.register_table(instance_id)
	elif kind == SharedTypes.FixtureKind.BOX or kind == SharedTypes.FixtureKind.FRIDGE:
		if _kitchen_controller != null:
			registered_ok = _kitchen_controller.register_storage_unit(instance_id, kind)
	elif kind == SharedTypes.FixtureKind.PLATE_RACK:
		if _kitchen_controller != null:
			var rack_plates := (
				def.plates_per_rack
				if def.plates_per_rack > 0
				else economy_config.plates_per_rack
			)
			registered_ok = _kitchen_controller.register_plate_rack(instance_id, rack_plates)
	else:
		if _kitchen_controller != null and _kitchen_controller.has_method(&"register_fixture_kind"):
			registered_ok = _kitchen_controller.register_fixture_kind(instance_id, kind)

	if not registered_ok:
		if _world_map.has_method(&"remove_placed_fixture"):
			_world_map.remove_placed_fixture(instance_id)
		return false

	if _kitchen_controller != null:
		var cells: Array = check.get("cells", [])
		if cells.has(_kitchen_controller.get_player_tile()):
			var alt := _world_map.find_nearest_free_neighbor(
				instance_id,
				_kitchen_controller.get_player_tile()
			)
			if alt != WorldMap.INVALID_CELL:
				_kitchen_controller.on_floor_clicked(alt)

	_next_purchase_seq += 1
	var purchase_id := StringName("pur_%d_%04d" % [_day_index, _next_purchase_seq])
	_cash -= def.purchase_price
	_fixture_instances[instance_id] = {
		"instance_id": instance_id,
		"utility_id": utility_id,
		"fixture_kind": kind,
		"slot_id": slot_id,
		"starter_grant": false,
		"actual_amount_paid": def.purchase_price,
	}
	_purchase_ledger[purchase_id] = {
		"purchase_id": purchase_id,
		"day_index": _day_index,
		"kind": &"FIXTURE",
		"storage_unit_id": &"",
		"item_or_fixture_id": utility_id,
		"fixture_instance_id": instance_id,
		"slot_id": slot_id,
		"quantity": 1,
		"actual_amount_paid": def.purchase_price,
		"status": &"DELIVERED",
	}
	if _kitchen_controller != null:
		_kitchen_controller.kitchen_state_changed.emit()
	run_state_changed.emit()
	return true


func request_fixture_sale(fixture_instance_id: StringName) -> bool:
	if not _is_planning_phase():
		return false
	if fixture_instance_id == &"" or not _fixture_instances.has(fixture_instance_id):
		return false
	return false


func request_ingredient_basket_purchase(
	quantities_by_id: Dictionary,
	storage_unit_id: StringName
) -> bool:
	if not _can_attempt_ingredient_purchase(storage_unit_id):
		return false
	if quantities_by_id.is_empty():
		return false

	var sorted_ids: Array[StringName] = []
	var clean_items: Dictionary[StringName, int] = {}
	var total_cost := 0
	for raw_id: Variant in quantities_by_id.keys():
		var ingredient_id := StringName(raw_id)
		var raw_qty: Variant = quantities_by_id[raw_id]
		if not (raw_qty is int):
			return false
		var quantity := int(raw_qty)
		if ingredient_id == &"" or quantity <= 0:
			return false
		if not is_ingredient_unlocked(ingredient_id):
			return false
		var unit_price := economy_config.get_ingredient_price(ingredient_id)
		if unit_price <= 0:
			return false
		if clean_items.has(ingredient_id):
			return false
		clean_items[ingredient_id] = quantity
		sorted_ids.append(ingredient_id)
		total_cost += unit_price * quantity

	if total_cost <= 0 or total_cost > _cash:
		return false
	sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	if _kitchen_controller.has_method(&"can_receive_stock_basket"):
		if not _kitchen_controller.can_receive_stock_basket(clean_items, storage_unit_id):
			return false
	else:
		for ingredient_id in sorted_ids:
			if not _kitchen_controller.can_receive_stock(
				ingredient_id,
				clean_items[ingredient_id],
				storage_unit_id
			):
				return false

	var in_serving := _is_serving_phase()
	var due_at := 0.0
	if in_serving:
		var now := 0.0
		if _game_root != null and _game_root.has_method(&"get_service_elapsed"):
			now = float(_game_root.get_service_elapsed())
		due_at = now + economy_config.service_delivery_seconds
		if due_at < 0.0:
			return false

	var batch: Array[Dictionary] = []
	for ingredient_id in sorted_ids:
		var quantity := clean_items[ingredient_id]
		_next_purchase_seq += 1
		var purchase_id := StringName("pur_%d_%04d" % [_day_index, _next_purchase_seq])
		if not _kitchen_controller.reserve_incoming_capacity(
			purchase_id,
			ingredient_id,
			quantity,
			storage_unit_id
		):
			for prev in batch:
				_kitchen_controller.release_reserved_capacity(
					prev["purchase_id"],
					storage_unit_id
				)
			return false
		var unit_price := economy_config.get_ingredient_price(ingredient_id)
		batch.append({
			"purchase_id": purchase_id,
			"ingredient_id": ingredient_id,
			"quantity": quantity,
			"paid": unit_price * quantity,
		})

	if in_serving:
		var committed_items: Array[Dictionary] = []
		for item in batch:
			var purchase_id: StringName = item["purchase_id"]
			var ingredient_id: StringName = item["ingredient_id"]
			var quantity: int = int(item["quantity"])
			var ok := _kitchen_controller.schedule_delivery(
				purchase_id,
				ingredient_id,
				quantity,
				storage_unit_id,
				due_at
			)
			if not ok:
				if _kitchen_controller.has_method(&"rollback_scheduled_delivery"):
					for done in committed_items:
						_kitchen_controller.rollback_scheduled_delivery(
							done["purchase_id"],
							storage_unit_id
						)
				for rem in batch:
					_kitchen_controller.release_reserved_capacity(
						rem["purchase_id"],
						storage_unit_id
					)
				return false
			committed_items.append(item)
	else:
		var received_ok := false
		if _kitchen_controller.has_method(&"receive_stock_basket"):
			received_ok = _kitchen_controller.receive_stock_basket(batch, storage_unit_id)
		else:
			received_ok = batch.size() == 1 and _kitchen_controller.receive_stock(
				batch[0]["purchase_id"],
				batch[0]["ingredient_id"],
				int(batch[0]["quantity"]),
				storage_unit_id
			)
		if not received_ok:
			for rem in batch:
				_kitchen_controller.release_reserved_capacity(
					rem["purchase_id"],
					storage_unit_id
				)
			return false

	_cash -= total_cost
	for item in batch:
		var purchase_id: StringName = item["purchase_id"]
		_purchase_ledger[purchase_id] = {
			"purchase_id": purchase_id,
			"day_index": _day_index,
			"kind": &"INGREDIENT",
			"storage_unit_id": storage_unit_id,
			"item_or_fixture_id": item["ingredient_id"],
			"quantity": int(item["quantity"]),
			"actual_amount_paid": int(item["paid"]),
			"status": &"PENDING" if in_serving else &"DELIVERED",
		}
	run_state_changed.emit()
	return true


func request_ingredient_purchase(
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if not _can_attempt_ingredient_purchase(storage_unit_id):
		return false
	if ingredient_id == &"" or quantity <= 0:
		return false
	if not is_ingredient_unlocked(ingredient_id):
		return false

	var unit_price := economy_config.get_ingredient_price(ingredient_id)
	if unit_price <= 0:
		return false

	var total_cost := unit_price * quantity
	if total_cost > _cash:
		return false
	if not _kitchen_controller.can_receive_stock(ingredient_id, quantity, storage_unit_id):
		return false

	_next_purchase_seq += 1
	var purchase_id := StringName("pur_%d_%04d" % [_day_index, _next_purchase_seq])
	if not _kitchen_controller.reserve_incoming_capacity(
		purchase_id,
		ingredient_id,
		quantity,
		storage_unit_id
	):
		return false

	var in_serving := _is_serving_phase()
	var committed := false
	if in_serving:
		var now := 0.0
		if _game_root != null and _game_root.has_method(&"get_service_elapsed"):
			now = float(_game_root.get_service_elapsed())
		var due_at := now + economy_config.service_delivery_seconds
		committed = _kitchen_controller.schedule_delivery(
			purchase_id,
			ingredient_id,
			quantity,
			storage_unit_id,
			due_at
		)
	else:
		committed = _kitchen_controller.receive_stock(
			purchase_id,
			ingredient_id,
			quantity,
			storage_unit_id
		)

	if not committed:
		_kitchen_controller.release_reserved_capacity(purchase_id, storage_unit_id)
		return false

	_cash -= total_cost
	_purchase_ledger[purchase_id] = {
		"purchase_id": purchase_id,
		"day_index": _day_index,
		"kind": &"INGREDIENT",
		"storage_unit_id": storage_unit_id,
		"item_or_fixture_id": ingredient_id,
		"quantity": quantity,
		"actual_amount_paid": total_cost,
		"status": &"PENDING" if in_serving else &"DELIVERED",
	}
	run_state_changed.emit()
	return true


func finalize_plan() -> bool:
	if not _run_started or economy_config == null or _is_game_paused() or not _is_planning_phase():
		return false
	if _selected_recipe_ids.is_empty():
		return false

	var prices: Dictionary[StringName, int] = {}
	for recipe_id in _selected_recipe_ids:
		if not _unlocked_recipe_ids.has(recipe_id):
			return false
		var entry := economy_config.get_recipe_entry(recipe_id)
		if entry == null or entry.dine_in_price <= 0:
			return false
		prices[recipe_id] = entry.dine_in_price

	var table_ids := _get_installed_table_ids()
	if table_ids.is_empty():
		return false

	var demand := _compute_demand_for_day_and_menu(_day_index, _selected_recipe_ids)
	_frozen_service_plan = {
		"day_index": _day_index,
		"potential_demand": int(demand["potential_demand"]),
		"day_queue_initial": int(demand["planned_dinein_quota"]),
		"selected_recipe_ids": _selected_recipe_ids.duplicate(),
		"dine_in_price_by_recipe": prices,
		"installed_table_ids": table_ids,
		"employees": get_hired_employees(),
		"workforce_summary": get_workforce_summary(),
	}
	return true


func get_service_plan() -> Dictionary:
	return _frozen_service_plan.duplicate(true)


func credit_order_once(
	order_id: StringName,
	recipe_id: StringName,
	order_kind: int
) -> bool:
	if not _run_started or economy_config == null or not _is_serving_phase():
		return false
	if order_id == &"" or recipe_id == &"":
		return false
	if (
		order_kind != SharedTypes.OrderKind.DINE_IN
		and order_kind != SharedTypes.OrderKind.ONLINE
	):
		return false
	if _credited_order_ids.has(order_id):
		return false

	var frozen_prices: Variant = _frozen_service_plan.get("dine_in_price_by_recipe", {})
	if not (frozen_prices is Dictionary) or not frozen_prices.has(recipe_id):
		return false
	var dine_in_price := int(frozen_prices[recipe_id])
	if dine_in_price <= 0:
		return false

	var payout := dine_in_price
	if order_kind == SharedTypes.OrderKind.ONLINE:
		var raw_online := float(dine_in_price * economy_config.online_sale_percent) / 100.0
		payout = int(floor(raw_online))
	if payout <= 0:
		return false

	_credited_order_ids[order_id] = {
		"order_id": order_id,
		"day_index": _day_index,
		"recipe_id": recipe_id,
		"order_kind": order_kind,
		"payout": payout,
	}
	_cash += payout
	run_state_changed.emit()
	return true


func refund_canceled_deliveries_once(purchase_ids: Array[StringName]) -> void:
	_sync_purchase_ledger_with_kitchen()
	var changed := false
	for purchase_id in purchase_ids:
		if not _purchase_ledger.has(purchase_id):
			continue
		var record: Dictionary = _purchase_ledger[purchase_id]
		if record.get("status", &"") != &"PENDING":
			continue
		if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
			if (
				_kitchen_controller.has_method(&"is_purchase_delivered")
				and _kitchen_controller.is_purchase_delivered(purchase_id)
			):
				record["status"] = &"DELIVERED"
				continue
			if (
				_kitchen_controller.has_method(&"is_purchase_pending")
				and _kitchen_controller.is_purchase_pending(purchase_id)
			):
				continue
		record["status"] = &"REFUNDED"
		_cash += int(record.get("actual_amount_paid", 0))
		changed = true

	if changed:
		run_state_changed.emit()


func settle_day_once(report: Dictionary) -> Dictionary:
	_sync_purchase_ledger_with_kitchen()
	if not _run_started or not report.has("day_index"):
		return {}
	var report_day := int(report.get("day_index", -1))
	if report_day <= 0 or report_day != _day_index:
		return {}
	if _settled_days.has(report_day):
		return _settled_days[report_day].duplicate(true)
	if not _is_closing_phase():
		return {}

	var electricity := _compute_daily_electricity_charge()
	var employee_salary := _compute_daily_salary_charge()
	_cash -= electricity + employee_salary

	var debt_before := _demand_penalty_debt
	var failed_ids: Array = []
	var raw_failed: Variant = report.get("failed_order_ids", [])
	if raw_failed is Array:
		failed_ids = raw_failed

	if failed_ids.is_empty():
		_demand_penalty_debt = maxi(0, _demand_penalty_debt - 1)
	else:
		var seen_failed: Dictionary[StringName, bool] = {}
		for raw_id: Variant in failed_ids:
			var failed_id := StringName(raw_id)
			if failed_id == &"" or seen_failed.has(failed_id):
				continue
			seen_failed[failed_id] = true
			_demand_penalty_debt += _rng.randi_range(1, 2)

	if report_day == 7 and _day_7_outcome == SharedTypes.DayOutcome.UNDECIDED:
		if economy_config != null and _cash >= economy_config.day_7_cash_target:
			_day_7_outcome = SharedTypes.DayOutcome.WON
		else:
			_day_7_outcome = SharedTypes.DayOutcome.LOST

	var finance := _compute_day_ledger_totals(report_day)
	var next_demand := _compute_demand_for_day_and_menu(report_day + 1, _selected_recipe_ids)
	var settlement := {
		"day_index": report_day,
		"begin_cash": _begin_day_cash,
		"ingredient_purchase_total": int(finance["ingredient_purchase_total"]),
		"fixture_purchase_total": int(finance["fixture_purchase_total"]),
		"fixture_sale_total": int(finance["fixture_sale_total"]),
		"order_revenue_dinein": int(finance["order_revenue_dinein"]),
		"order_revenue_online": int(finance["order_revenue_online"]),
		"refund_total": int(finance["refund_total"]),
		"electricity_charge": electricity,
		"employee_hire_total": int(finance["employee_hire_total"]),
		"employee_salary_total": employee_salary,
		"active_employee_count": _employees.size(),
		"end_cash": _cash,
		"completed_dinein_count": int(report.get("completed_dine_in_count", 0)),
		"completed_online_count": int(report.get("completed_online_count", 0)),
		"failed_dinein_count": int(report.get("failed_dine_in_count", 0)),
		"failed_online_count": int(report.get("failed_online_count", 0)),
		"penalty_debt_before": debt_before,
		"penalty_debt_after": _demand_penalty_debt,
		"forecast_next_day_potential": int(next_demand["potential_demand"]),
		"forecast_next_day": int(next_demand["planned_dinein_quota"]),
		"day7_outcome": _day_7_outcome,
	}
	_settled_days[report_day] = settlement
	run_state_changed.emit()
	return settlement.duplicate(true)


func advance_to_next_planning() -> int:
	if not _run_started or not _can_advance_to_next_planning():
		return _day_index

	_day_index += 1
	_begin_day_cash = _cash
	if _day_index >= 8:
		_extra_mode_active = true

	if economy_config != null:
		for recipe_id in economy_config.get_unlocked_recipe_ids(_day_index):
			if not _unlocked_recipe_ids.has(recipe_id):
				_unlocked_recipe_ids.append(recipe_id)

	run_state_changed.emit()
	return _day_index


func get_run_view() -> Dictionary:
	var demand := _compute_demand_for_day_and_menu(_day_index, _selected_recipe_ids)
	return {
		"day_index": _day_index,
		"cash": _cash,
		"day_7_target": economy_config.day_7_cash_target if economy_config != null else 0,
		"goal_outcome": _day_7_outcome,
		"unlocked_recipe_ids": _unlocked_recipe_ids.duplicate(),
		"unlocked_ingredient_ids": get_unlocked_ingredient_ids(_day_index),
		"selected_recipe_ids": _selected_recipe_ids.duplicate(),
		"installed_fixtures": _fixture_instances.duplicate(true),
		"demand_penalty_debt": _demand_penalty_debt,
		"potential_demand": int(demand["potential_demand"]),
		"planned_dinein_quota": int(demand["planned_dinein_quota"]),
		"employee_count": _employees.size(),
		"daily_salary_estimate": _compute_daily_salary_charge(),
		"hired_employees": get_hired_employees(),
		"workforce_summary": get_workforce_summary(),
	}


## Returns derived purchasable raw ingredient IDs across all recipes unlocked
## up to `day` (union of RecipeDef.required_parts across unlocked recipes).
func get_unlocked_ingredient_ids(day: int = -1) -> Array[StringName]:
	_ensure_resources_loaded()
	var target_day := _day_index if day <= 0 else day
	var result: Array[StringName] = []
	if economy_config == null:
		return result
	var unlocked_recipes := economy_config.get_unlocked_recipe_ids(target_day)
	for recipe_id in unlocked_recipes:
		var recipe_def := _resolve_recipe_def(recipe_id)
		if recipe_def == null:
			continue
		for part in recipe_def.required_parts:
			if part != null and part.ingredient_id != &"" and not result.has(part.ingredient_id):
				result.append(part.ingredient_id)
	return result


## Returns true if `ingredient_id` is required by at least one recipe unlocked
## by `day` (defaults to current day index).
func is_ingredient_unlocked(ingredient_id: StringName, day: int = -1) -> bool:
	if ingredient_id == &"":
		return false
	return get_unlocked_ingredient_ids(day).has(ingredient_id)


func _resolve_recipe_def(recipe_id: StringName) -> RecipeDef:
	if recipe_id == &"":
		return null
	if (
		_kitchen_controller != null
		and is_instance_valid(_kitchen_controller)
		and _kitchen_controller.has_method(&"get_recipe_def")
	):
		var kc_def := _kitchen_controller.get_recipe_def(recipe_id) as RecipeDef
		if kc_def != null:
			return kc_def
	if _recipe_defs_fallback.has(recipe_id):
		return _recipe_defs_fallback[recipe_id]
	var loaded := load("res://data/recipes/%s.tres" % recipe_id) as RecipeDef
	if loaded != null:
		_recipe_defs_fallback[recipe_id] = loaded
	return loaded


## Returns read-only Potential Demand and Planned Dine-in Quota for a candidate menu.
func preview_demand_for_menu(recipe_ids: Array[StringName]) -> Dictionary:
	return _compute_demand_for_day_and_menu(_day_index, recipe_ids)


func get_day_settlement_view(day_index: int) -> Dictionary:
	if not _settled_days.has(day_index):
		return {}
	return _settled_days[day_index].duplicate(true)


func _ensure_resources_loaded() -> void:
	if economy_config == null:
		economy_config = load(DEFAULT_CONFIG_PATH) as EconomyConfig
	if _utility_defs.is_empty():
		for utility_id in UTILITY_IDS:
			var res := load("res://data/utilities/%s.tres" % utility_id) as UtilityDef
			if res != null:
				_utility_defs[utility_id] = res


func _bind_starter_fixtures() -> void:
	for spec: Dictionary in STARTER_FIXTURE_SPECS:
		var instance_id: StringName = spec["instance_id"]
		var utility_id: StringName = spec["utility_id"]
		var kind: SharedTypes.FixtureKind = spec["fixture_kind"]

		if _world_map != null and _world_map.registry != null:
			if not _world_map.registry.has_object(instance_id):
				push_error(
					"RunController: starter fixture '%s' missing in WorldRegistry." % instance_id
				)
				continue

		_fixture_instances[instance_id] = {
			"instance_id": instance_id,
			"utility_id": utility_id,
			"fixture_kind": kind,
			"slot_id": &"",
			"starter_grant": true,
			"actual_amount_paid": 0,
		}

		if _kitchen_controller != null:
			if kind == SharedTypes.FixtureKind.BOX or kind == SharedTypes.FixtureKind.FRIDGE:
				_kitchen_controller.register_storage_unit(instance_id, kind)
			elif kind == SharedTypes.FixtureKind.PLATE_RACK and economy_config != null:
				_kitchen_controller.register_plate_rack(
					instance_id,
					economy_config.plates_per_rack
				)
			elif (
				kind != SharedTypes.FixtureKind.DINING_TABLE
				and _kitchen_controller.has_method(&"register_fixture_kind")
			):
				_kitchen_controller.register_fixture_kind(instance_id, kind)

		if _service_controller != null and kind == SharedTypes.FixtureKind.DINING_TABLE:
			_service_controller.register_table(instance_id)

	if _kitchen_controller != null:
		if _world_map == null or _world_map.registry == null or _world_map.registry.has_object(
			&"work_table"
		):
			_kitchen_controller.register_work_table(&"work_table")
		if _world_map != null and _world_map.has_method(&"get_long_counter_slot_ids"):
			for slot_id in _world_map.get_long_counter_slot_ids():
				_kitchen_controller.register_work_table(slot_id)


func _get_installed_table_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for instance_id: StringName in _fixture_instances:
		var rec: Dictionary = _fixture_instances[instance_id]
		if rec.get("fixture_kind", -1) == SharedTypes.FixtureKind.DINING_TABLE:
			ids.append(instance_id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _compute_planned_dine_in_quota() -> int:
	return _compute_planned_dine_in_quota_for_day(_day_index)


func _compute_planned_dine_in_quota_for_day(day: int) -> int:
	return int(_compute_demand_for_day_and_menu(day, _selected_recipe_ids)["planned_dinein_quota"])


func _compute_demand_for_day_and_menu(day: int, recipe_ids: Array[StringName]) -> Dictionary:
	if economy_config == null:
		return {
			"base_potential": 0,
			"menu_bonus": 0,
			"potential_demand": 0,
			"planned_dinein_quota": 0,
		}
	var unlocked_for_day := economy_config.get_unlocked_recipe_ids(day)
	var valid_selected: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}
	for recipe_id in recipe_ids:
		if recipe_id == &"" or seen.has(recipe_id):
			continue
		if not unlocked_for_day.has(recipe_id):
			continue
		seen[recipe_id] = true
		valid_selected.append(recipe_id)
	if valid_selected.is_empty():
		return {
			"base_potential": 0,
			"menu_bonus": 0,
			"potential_demand": 0,
			"planned_dinein_quota": 0,
		}

	valid_selected.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ea := economy_config.get_recipe_entry(a)
		var eb := economy_config.get_recipe_entry(b)
		var ua := ea.unlock_day if ea != null else 999
		var ub := eb.unlock_day if eb != null else 999
		if ua != ub:
			return ua < ub
		return String(a) < String(b)
	)
	var baseline_id: StringName = valid_selected[0]
	var extra_menu_arrivals := 0
	for i in range(1, valid_selected.size()):
		var rid := valid_selected[i]
		if rid == baseline_id:
			continue
		var entry := economy_config.get_recipe_entry(rid)
		if entry != null:
			extra_menu_arrivals += maxi(0, entry.arrival_contribution)

	var base_quota := (
		economy_config.day_1_base_dinein_quota
		+ maxi(0, day - 1) * economy_config.arrival_increment_per_day
	)
	var potential_demand := maxi(0, base_quota + extra_menu_arrivals)
	var planned_quota := maxi(0, potential_demand - _demand_penalty_debt)
	return {
		"base_potential": base_quota,
		"menu_bonus": extra_menu_arrivals,
		"potential_demand": potential_demand,
		"planned_dinein_quota": planned_quota,
	}


func _compute_daily_electricity_charge() -> int:
	if economy_config == null:
		return 0
	var total := 0
	for rec: Dictionary in _fixture_instances.values():
		var uid := StringName(rec.get("utility_id", &""))
		var kind: int = int(rec.get("fixture_kind", -1))
		total += get_fixture_daily_electricity_cost(uid, kind)
	return total


func _compute_daily_salary_charge() -> int:
	var total := 0
	var active_count := 0
	for rec: Dictionary in _employees.values():
		if not bool(rec.get("active", true)):
			continue
		active_count += 1
		total += maxi(0, int(rec.get("daily_salary", 0)))
	if economy_config != null:
		total += economy_config.compute_crowding_overhead(active_count)
	return total


func _compute_day_ledger_totals(day: int) -> Dictionary:
	var ingredient_total := 0
	var fixture_buy_total := 0
	var fixture_sale_total := 0
	var employee_hire_total := 0
	var refund_total := 0
	for rec: Dictionary in _purchase_ledger.values():
		if int(rec.get("day_index", -1)) != day:
			continue
		var kind: StringName = rec.get("kind", &"")
		var paid := int(rec.get("actual_amount_paid", 0))
		var status: StringName = rec.get("status", &"")
		if kind == &"INGREDIENT":
			ingredient_total += paid
			if status == &"REFUNDED":
				refund_total += paid
		elif kind == &"FIXTURE":
			fixture_buy_total += paid
		elif kind == &"EMPLOYEE_HIRE":
			employee_hire_total += paid

	var dinein_revenue := 0
	var online_revenue := 0
	for ord: Dictionary in _credited_order_ids.values():
		if int(ord.get("day_index", -1)) != day:
			continue
		var ord_kind := int(ord.get("order_kind", -1))
		var payout := int(ord.get("payout", 0))
		if ord_kind == SharedTypes.OrderKind.DINE_IN:
			dinein_revenue += payout
		elif ord_kind == SharedTypes.OrderKind.ONLINE:
			online_revenue += payout

	return {
		"ingredient_purchase_total": ingredient_total,
		"fixture_purchase_total": fixture_buy_total,
		"fixture_sale_total": fixture_sale_total,
		"employee_hire_total": employee_hire_total,
		"order_revenue_dinein": dinein_revenue,
		"order_revenue_online": online_revenue,
		"refund_total": refund_total,
	}


func _can_advance_to_next_planning() -> bool:
	if not _settled_days.has(_day_index):
		return false
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	var phase: int = _game_root.get_phase()
	if _day_index == 7:
		return (
			phase == SharedTypes.Phase.FINISHED
			and _day_7_outcome == SharedTypes.DayOutcome.WON
			and not _extra_mode_active
		)
	return phase == SharedTypes.Phase.RESULTS


func _is_closing_phase() -> bool:
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	return _game_root.get_phase() == SharedTypes.Phase.CLOSING


func _is_planning_phase() -> bool:
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	return _game_root.get_phase() == SharedTypes.Phase.PLANNING


func _is_serving_phase() -> bool:
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	return _game_root.get_phase() == SharedTypes.Phase.SERVING


func _is_planning_or_serving_phase() -> bool:
	return _is_planning_phase() or _is_serving_phase()


func _is_game_paused() -> bool:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_paused")
	):
		return bool(_game_root.is_paused())
	return false


func _can_attempt_ingredient_purchase(storage_unit_id: StringName) -> bool:
	if not _run_started or economy_config == null or _kitchen_controller == null:
		return false
	if _is_game_paused() or not _is_planning_or_serving_phase():
		return false
	if storage_unit_id == &"" or not _fixture_instances.has(storage_unit_id):
		return false
	var fixture_kind: int = int(_fixture_instances[storage_unit_id].get("fixture_kind", -1))
	return (
		fixture_kind == SharedTypes.FixtureKind.BOX
		or fixture_kind == SharedTypes.FixtureKind.FRIDGE
	)


func _on_kitchen_state_changed_sync() -> void:
	_sync_purchase_ledger_with_kitchen()


func _sync_purchase_ledger_with_kitchen() -> void:
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or not _kitchen_controller.has_method(&"is_purchase_delivered")
	):
		return
	for purchase_id: StringName in _purchase_ledger:
		var record: Dictionary = _purchase_ledger[purchase_id]
		if (
			record.get("status", &"") == &"PENDING"
			and _kitchen_controller.is_purchase_delivered(purchase_id)
		):
			record["status"] = &"DELIVERED"
