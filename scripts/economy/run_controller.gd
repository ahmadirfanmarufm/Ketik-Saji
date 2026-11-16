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
var _next_purchase_seq: int = 0
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
	_world_map = world_map
	_kitchen_controller = kitchen
	_service_controller = service
	_game_root = game_root


func get_day_index() -> int:
	return _day_index


func has_fixture_instance(instance_id: StringName) -> bool:
	return _fixture_instances.has(instance_id)


func get_fixture_instance(instance_id: StringName) -> Dictionary:
	if not _fixture_instances.has(instance_id):
		return {}
	return _fixture_instances[instance_id].duplicate(true)


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
	_next_purchase_seq = 0

	_bind_starter_fixtures()
	_run_started = true
	run_state_changed.emit()


func select_daily_menu(recipe_ids: Array[StringName]) -> bool:
	if not _is_planning_phase():
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


func request_fixture_purchase(utility_id: StringName, slot_id: StringName) -> bool:
	if not _is_planning_phase():
		return false
	if utility_id == &"" or slot_id == &"" or not _utility_defs.has(utility_id):
		return false
	return false


func request_fixture_sale(fixture_instance_id: StringName) -> bool:
	if not _is_planning_phase():
		return false
	if fixture_instance_id == &"" or not _fixture_instances.has(fixture_instance_id):
		return false
	return false


func request_ingredient_purchase(
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if not _run_started or economy_config == null or _kitchen_controller == null:
		return false
	if not _is_planning_or_serving_phase():
		return false
	if ingredient_id == &"" or quantity <= 0 or storage_unit_id == &"":
		return false
	if not _fixture_instances.has(storage_unit_id):
		return false
	var fixture_kind: int = int(_fixture_instances[storage_unit_id].get("fixture_kind", -1))
	if (
		fixture_kind != SharedTypes.FixtureKind.BOX
		and fixture_kind != SharedTypes.FixtureKind.FRIDGE
	):
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
	if not _run_started or economy_config == null or not _is_planning_phase():
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

	_frozen_service_plan = {
		"day_index": _day_index,
		"day_queue_initial": _compute_planned_dine_in_quota(),
		"selected_recipe_ids": _selected_recipe_ids.duplicate(),
		"dine_in_price_by_recipe": prices,
		"installed_table_ids": table_ids,
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
	var changed := false
	for purchase_id in purchase_ids:
		if not _purchase_ledger.has(purchase_id):
			continue
		var record: Dictionary = _purchase_ledger[purchase_id]
		if record.get("status", &"") != &"PENDING":
			continue
		record["status"] = &"REFUNDED"
		_cash += int(record.get("actual_amount_paid", 0))
		changed = true

	if changed:
		run_state_changed.emit()


func settle_day_once(report: Dictionary) -> Dictionary:
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
	_cash -= electricity

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
		"end_cash": _cash,
		"completed_dinein_count": int(report.get("completed_dine_in_count", 0)),
		"completed_online_count": int(report.get("completed_online_count", 0)),
		"failed_dinein_count": int(report.get("failed_dine_in_count", 0)),
		"failed_online_count": int(report.get("failed_online_count", 0)),
		"penalty_debt_before": debt_before,
		"penalty_debt_after": _demand_penalty_debt,
		"forecast_next_day": _compute_planned_dine_in_quota_for_day(report_day + 1),
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
	return {
		"day_index": _day_index,
		"cash": _cash,
		"day_7_target": economy_config.day_7_cash_target if economy_config != null else 0,
		"goal_outcome": _day_7_outcome,
		"unlocked_recipe_ids": _unlocked_recipe_ids.duplicate(),
		"selected_recipe_ids": _selected_recipe_ids.duplicate(),
		"installed_fixtures": _fixture_instances.duplicate(true),
		"demand_penalty_debt": _demand_penalty_debt,
		"planned_dinein_quota": _compute_planned_dine_in_quota(),
	}


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

		if _service_controller != null and kind == SharedTypes.FixtureKind.DINING_TABLE:
			_service_controller.register_table(instance_id)

	if _kitchen_controller != null:
		if _world_map == null or _world_map.registry == null or _world_map.registry.has_object(
			&"work_table"
		):
			_kitchen_controller.register_work_table(&"work_table")


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
	if economy_config == null:
		return 0
	var base := (
		economy_config.day_1_base_dinein_quota
		+ maxi(0, day - 1) * economy_config.arrival_increment_per_day
	)
	var bonus := (
		maxi(0, _selected_recipe_ids.size() - 1)
		* economy_config.extra_arrivals_per_extra_selected_menu
	)
	return maxi(0, base + bonus - _demand_penalty_debt)


func _compute_daily_electricity_charge() -> int:
	if economy_config == null:
		return 0
	var total := 0
	for rec: Dictionary in _fixture_instances.values():
		var kind: int = int(rec.get("fixture_kind", -1))
		if kind == SharedTypes.FixtureKind.FRIDGE:
			total += economy_config.fridge_electricity_per_day
		elif kind == SharedTypes.FixtureKind.RICE_COOKER:
			total += economy_config.rice_cooker_electricity_per_day
	return total


func _compute_day_ledger_totals(day: int) -> Dictionary:
	var ingredient_total := 0
	var fixture_buy_total := 0
	var fixture_sale_total := 0
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
