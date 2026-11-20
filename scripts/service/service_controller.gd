class_name ServiceController
extends Node
## Sole authority for dine-in arrival quota, outside waiting FIFO, seated/eating
## customers, dining table states, online offer preview, accepted online orders,
## physical drivers, three pickup spots, and driver overflow FIFO.
##
## Owns no independent service clock; all deadlines use monotonic `now` passed
## from GameRoot.

signal orders_changed()
signal queues_changed()
signal tables_changed()
signal drivers_changed()
signal online_offer_changed()

const DEFAULT_ECONOMY_CONFIG_PATH: String = "res://data/economy_config.tres"
const DEFAULT_PATIENCE_SECONDS: float = 100.0
const DEFAULT_SPAWN_INTERVAL_SECONDS: float = 20.0
const DEFAULT_EAT_SECONDS: float = 20.0
const DEFAULT_ONLINE_DEADLINE_SECONDS: float = 60.0
const DEFAULT_ONLINE_OFFER_INITIAL_DELAY_SECONDS: float = 10.0
const DEFAULT_ONLINE_OFFER_INTERVAL_SECONDS: float = 15.0
const DEFAULT_ONLINE_OFFER_ACTIVE_DURATION_SECONDS: float = 15.0

enum OnlineOfferState {
	NOT_SERVING,
	WAITING,
	AVAILABLE,
	UNAVAILABLE,
}

const PICKUP_SPOT_IDS: Array[StringName] = [
	&"pickup_spot_01",
	&"pickup_spot_02",
	&"pickup_spot_03",
]

var _kitchen_controller: KitchenController = null
var _run_controller: RunController = null
var _game_root: Node = null
var _economy_config: EconomyConfig = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _custom_seed_set: bool = false

var _day_prepared: bool = false
var _service_active: bool = false
var _day_index: int = 1
var _last_service_now: float = 0.0
var _next_spawn_at: float = 0.0
var _next_customer_seq: int = 0
var _next_order_seq: int = 0
var _next_driver_seq: int = 0

var _day_queue_initial: int = 0
var _day_queue_remaining: int = 0
var _outside_dine_in_queue: Array[StringName] = []
var _in_shop_dine_in_count: int = 0
var _arrived_dine_in_count: int = 0

var _selected_recipe_ids: Array[StringName] = []
var _dine_in_prices: Dictionary[StringName, int] = {}

var _customers: Dictionary[StringName, Dictionary] = {}
var _orders: Dictionary[StringName, Dictionary] = {}
var _online_orders_open: Array[StringName] = []
var _tables: Dictionary[StringName, Dictionary] = {}
var _drivers: Dictionary[StringName, Dictionary] = {}
var _pickup_spot_to_driver: Dictionary[StringName, StringName] = {}
var _outside_driver_queue: Array[StringName] = []
var _online_offer: Dictionary = {
	"state": OnlineOfferState.NOT_SERVING,
	"preview_recipe_id": &"",
	"offer_generation_number": 0,
	"next_offer_at": 0.0,
	"offer_expires_at": 0.0,
}

var _completed_order_ids: Array[StringName] = []
var _failed_order_ids: Array[StringName] = []
var _completed_dine_in_count: int = 0
var _failed_dine_in_count: int = 0
var _completed_online_count: int = 0
var _failed_online_count: int = 0
var _last_invariant_error: String = ""
var _cashier_count: int = 0
var _cashier_interval_seconds: float = 0.0
var _cashier_patience_bonus_seconds: float = 0.0
var _next_cashier_action_at: float = INF
var _waiter_count: int = 0
var _waiter_interval_seconds: float = 0.0
var _next_waiter_action_at: float = INF
var _prev_tick_now: float = 0.0
var _cashier_workers: Array[Dictionary] = []
var _waiter_workers: Array[Dictionary] = []
var _workforce_action_counts: Dictionary[StringName, int] = {
	&"cashier": 0,
	&"waiter": 0,
}


func _ready() -> void:
	_reset_pickup_spots()
	_ensure_economy_config()
	if not _custom_seed_set:
		_rng.seed = hash("ketik_saji_service_day_1")


func reset_for_new_run() -> void:
	_day_prepared = false
	_service_active = false
	_day_index = 1
	_last_service_now = 0.0
	_next_spawn_at = 0.0
	_next_customer_seq = 0
	_next_order_seq = 0
	_next_driver_seq = 0
	_day_queue_initial = 0
	_day_queue_remaining = 0
	_outside_dine_in_queue.clear()
	_in_shop_dine_in_count = 0
	_arrived_dine_in_count = 0
	_selected_recipe_ids.clear()
	_dine_in_prices.clear()
	_customers.clear()
	_orders.clear()
	_online_orders_open.clear()
	_tables.clear()
	_drivers.clear()
	_reset_pickup_spots()
	_outside_driver_queue.clear()
	_online_offer = {
		"state": OnlineOfferState.NOT_SERVING,
		"preview_recipe_id": &"",
		"offer_generation_number": 0,
		"next_offer_at": 0.0,
		"offer_expires_at": 0.0,
	}
	_completed_order_ids.clear()
	_failed_order_ids.clear()
	_completed_dine_in_count = 0
	_failed_dine_in_count = 0
	_completed_online_count = 0
	_failed_online_count = 0
	_last_invariant_error = ""
	_reset_workforce_runtime()
	if not _custom_seed_set:
		_rng.seed = hash("ketik_saji_service_day_1")
	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	drivers_changed.emit()
	online_offer_changed.emit()


## Binds sibling controllers used for dining-table serving, cleaning, and payouts.
func bind_systems(
	kitchen: KitchenController,
	run_controller: RunController,
	game_root: Node = null
) -> void:
	_kitchen_controller = kitchen
	_run_controller = run_controller
	_game_root = game_root
	if _run_controller != null and _run_controller.economy_config != null:
		_economy_config = _run_controller.economy_config
	else:
		_ensure_economy_config()


## Sets a deterministic RNG seed for customer order weighted selection.
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_custom_seed_set = true


## Registers an installed dining table once by stable `table_id`.
func register_table(table_id: StringName) -> bool:
	if table_id == &"" or _tables.has(table_id):
		return false
	_tables[table_id] = {
		"table_id": table_id,
		"state": SharedTypes.TableState.CLEAN_VACANT,
		"customer_id_or_empty": &"",
		"order_id_or_empty": &"",
	}
	return true


func has_table(table_id: StringName) -> bool:
	return _tables.has(table_id)


func get_registered_table_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_tables.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func prepare_service_day(day_index: int, plan: Dictionary) -> void:
	_day_index = maxi(1, day_index)
	_day_queue_initial = maxi(0, int(plan.get("day_queue_initial", 0)))
	_day_queue_remaining = _day_queue_initial
	_outside_dine_in_queue.clear()
	_in_shop_dine_in_count = 0
	_arrived_dine_in_count = 0

	_selected_recipe_ids.clear()
	var raw_recipes: Variant = plan.get("selected_recipe_ids", [])
	if raw_recipes is Array:
		for item: Variant in raw_recipes:
			var recipe_id := StringName(item)
			if recipe_id != &"":
				_selected_recipe_ids.append(recipe_id)

	_dine_in_prices.clear()
	var raw_prices: Variant = plan.get("dine_in_price_by_recipe", {})
	if raw_prices is Dictionary:
		for key: Variant in raw_prices:
			_dine_in_prices[StringName(key)] = int(raw_prices[key])

	var raw_tables: Variant = plan.get("installed_table_ids", [])
	if raw_tables is Array:
		for item: Variant in raw_tables:
			register_table(StringName(item))

	_customers.clear()
	_orders.clear()
	_online_orders_open.clear()
	_drivers.clear()
	_outside_driver_queue.clear()
	_reset_pickup_spots()

	for table: Dictionary in _tables.values():
		table["state"] = SharedTypes.TableState.CLEAN_VACANT
		table["customer_id_or_empty"] = &""
		table["order_id_or_empty"] = &""

	_completed_order_ids.clear()
	_failed_order_ids.clear()
	_completed_dine_in_count = 0
	_failed_dine_in_count = 0
	_completed_online_count = 0
	_failed_online_count = 0
	_last_invariant_error = ""
	_next_customer_seq = 0
	_next_order_seq = 0
	_next_driver_seq = 0
	_next_spawn_at = 0.0
	if not _custom_seed_set:
		_rng.seed = hash("ketik_saji_service_day_%d" % _day_index)

	_online_offer = _make_empty_online_offer()
	_configure_workforce_from_plan(plan)

	_day_prepared = true
	_service_active = false
	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	online_offer_changed.emit()


func begin_service(now: float) -> void:
	if not _day_prepared:
		return
	_ensure_economy_config()
	_last_service_now = maxf(0.0, now)
	_prev_tick_now = _last_service_now
	_next_spawn_at = _last_service_now
	_next_cashier_action_at = (
		_last_service_now
		if _cashier_count > 0 and _cashier_interval_seconds > 0.0
		else INF
	)
	_next_waiter_action_at = (
		_last_service_now
		if _waiter_count > 0 and _waiter_interval_seconds > 0.0
		else INF
	)
	_service_active = true
	var initial_delay := _get_online_offer_initial_delay_seconds()
	_online_offer = {
		"state": OnlineOfferState.WAITING,
		"preview_recipe_id": &"",
		"offer_generation_number": 0,
		"next_offer_at": _last_service_now + initial_delay,
		"offer_expires_at": 0.0,
		"wait_total_seconds": initial_delay,
	}
	_tick_service_spawns_and_timers(_last_service_now)
	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	online_offer_changed.emit()


func advance_service_time(now: float) -> void:
	if not _service_active:
		return
	_prev_tick_now = _last_service_now
	var clamped_now := maxf(_last_service_now, now)
	_last_service_now = clamped_now
	var changed := _tick_service_spawns_and_timers(clamped_now)
	_emit_tick_signals(changed)


## True only during an active service day when all four canonical drain
## conditions hold simultaneously.
func is_drained() -> bool:
	if not _service_active:
		return false
	return (
		_day_queue_remaining == 0
		and _outside_dine_in_queue.is_empty()
		and _in_shop_dine_in_count == 0
		and _online_orders_open.is_empty()
	)


func freeze_and_build_day_report(day_index: int) -> Dictionary:
	_service_active = false
	_online_offer["state"] = OnlineOfferState.NOT_SERVING
	_online_offer["preview_recipe_id"] = &""
	_online_offer["offer_expires_at"] = 0.0
	for w: Dictionary in _cashier_workers:
		_clear_service_worker_task(w, 0.0)
	for w: Dictionary in _waiter_workers:
		_clear_service_worker_task(w, 0.0)
	return {
		"day_index": day_index,
		"arrived_dine_in_count": _arrived_dine_in_count,
		"initial_dine_in_quota": _day_queue_initial,
		"completed_order_ids": _completed_order_ids.duplicate(),
		"failed_order_ids": _failed_order_ids.duplicate(),
		"completed_dine_in_count": _completed_dine_in_count,
		"failed_dine_in_count": _failed_dine_in_count,
		"completed_online_count": _completed_online_count,
		"failed_online_count": _failed_online_count,
	}


func reset_dirt_and_day_customers() -> void:
	_service_active = false
	_day_prepared = false
	_day_queue_remaining = 0
	_outside_dine_in_queue.clear()
	_in_shop_dine_in_count = 0
	_customers.clear()
	_orders.clear()
	_online_orders_open.clear()
	_drivers.clear()
	_outside_driver_queue.clear()
	_reset_pickup_spots()
	_next_driver_seq = 0
	_online_offer = _make_empty_online_offer()
	_reset_workforce_runtime()

	for table: Dictionary in _tables.values():
		table["state"] = SharedTypes.TableState.CLEAN_VACANT
		table["customer_id_or_empty"] = &""
		table["order_id_or_empty"] = &""

	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	drivers_changed.emit()
	online_offer_changed.emit()


func try_serve_table(table_id: StringName, item_id: StringName) -> bool:
	if (
		not _service_active
		or _is_game_paused()
		or table_id == &""
		or item_id == &""
		or not _tables.has(table_id)
	):
		return false

	var table: Dictionary = _tables[table_id]
	if table.get("state", -1) != SharedTypes.TableState.OCCUPIED_WAITING:
		_sync_service_now_from_clock()
		table = _tables[table_id]
		if table.get("state", -1) != SharedTypes.TableState.OCCUPIED_WAITING:
			return false

	var order_id: StringName = table.get("order_id_or_empty", &"")
	var customer_id: StringName = table.get("customer_id_or_empty", &"")
	if not _orders.has(order_id) or not _customers.has(customer_id):
		return false

	var order: Dictionary = _orders[order_id]
	if order.get("status", -1) != SharedTypes.OrderStatus.OPEN:
		return false

	var clock_now := _get_live_clock_now()
	var deadline_at: float = float(order.get("deadline_at", 0.0))
	if clock_now >= deadline_at:
		_last_service_now = clock_now
		var expired := _tick_service_spawns_and_timers(_last_service_now)
		_emit_tick_signals(expired)
		return false
	if clock_now > _last_service_now:
		_last_service_now = clock_now
		var synced := _tick_service_spawns_and_timers(_last_service_now)
		_emit_tick_signals(synced)

	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return false

	var recipe_id: StringName = order.get("recipe_id", &"")
	if not _kitchen_controller.try_consume_serving_item(
		item_id,
		recipe_id,
		SharedTypes.OrderKind.DINE_IN,
		table_id
	):
		return false

	_complete_dine_in_table_serve(table_id, order_id, customer_id, recipe_id)

	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	return true


func try_serve_driver(driver_id: StringName, item_id: StringName) -> bool:
	if (
		not _service_active
		or _is_game_paused()
		or driver_id == &""
		or item_id == &""
		or not _drivers.has(driver_id)
	):
		return false

	var driver: Dictionary = _drivers[driver_id]
	var spot_id := StringName(driver.get("spot_id_or_empty", &""))
	if (
		int(driver.get("state", -1)) != SharedTypes.DriverState.AT_PICKUP_SPOT
		or spot_id == &""
		or _pickup_spot_to_driver.get(spot_id, &"") != driver_id
	):
		return false

	var order_id := StringName(driver.get("order_id", &""))
	if not _orders.has(order_id):
		return false
	var order: Dictionary = _orders[order_id]
	if (
		int(order.get("kind", -1)) != SharedTypes.OrderKind.ONLINE
		or int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN
	):
		return false

	var clock_now := _get_live_clock_now()
	var deadline_at: float = float(order.get("deadline_at", 0.0))
	if clock_now >= deadline_at:
		_last_service_now = clock_now
		var expired := _tick_service_spawns_and_timers(_last_service_now)
		_emit_tick_signals(expired)
		return false
	if clock_now > _last_service_now:
		_last_service_now = clock_now
		var synced := _tick_service_spawns_and_timers(_last_service_now)
		_emit_tick_signals(synced)
		if not _drivers.has(driver_id):
			return false

	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return false

	var recipe_id: StringName = order.get("recipe_id", &"")
	if not _kitchen_controller.try_consume_serving_item(
		item_id,
		recipe_id,
		SharedTypes.OrderKind.ONLINE,
		&""
	):
		return false

	_complete_online_driver_serve(driver_id, order_id, spot_id, recipe_id)

	orders_changed.emit()
	queues_changed.emit()
	drivers_changed.emit()
	online_offer_changed.emit()
	return true


func try_clean_table(table_id: StringName) -> bool:
	if not _service_active or _is_game_paused() or not _tables.has(table_id):
		return false
	var table: Dictionary = _tables[table_id]
	if table.get("state", -1) != SharedTypes.TableState.DIRTY:
		return false
	if table.get("customer_id_or_empty", &"") != &"":
		return false

	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		if not _kitchen_controller.move_cleaned_table_plate_to_washer(table_id):
			return false

	table["state"] = SharedTypes.TableState.CLEAN_VACANT
	table["customer_id_or_empty"] = &""
	table["order_id_or_empty"] = &""

	_sync_service_now_from_clock()
	_admit_outside_waiters(_last_service_now)

	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	return true


func try_accept_online_offer() -> bool:
	if _is_game_paused():
		return false
	if not _service_active or not _day_prepared:
		return false
	_sync_service_now_from_clock()
	if not _accept_active_online_offer_at(_last_service_now):
		return false

	orders_changed.emit()
	queues_changed.emit()
	drivers_changed.emit()
	online_offer_changed.emit()
	return true


func has_driver(driver_id: StringName) -> bool:
	return driver_id != &"" and _drivers.has(driver_id)


func get_driver_view(driver_id: StringName) -> Dictionary:
	if not _drivers.has(driver_id):
		return {}
	return _build_driver_view(driver_id, _outside_driver_queue.find(driver_id))


func get_order_view(order_id: StringName) -> Dictionary:
	if not _orders.has(order_id):
		return {}
	var copy: Dictionary = _orders[order_id].duplicate(true)
	var deadline_at: float = float(copy.get("deadline_at", 0.0))
	copy["seconds_remaining"] = maxf(0.0, deadline_at - _last_service_now)
	return copy


func get_customer_views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var queue_positions: Dictionary[StringName, int] = {}
	for i in range(_outside_dine_in_queue.size()):
		queue_positions[_outside_dine_in_queue[i]] = i

	var patience_total := _get_patience_seconds()
	var eat_total := _get_eat_seconds()
	for cust_id in _get_sorted_customer_ids():
		var customer: Dictionary = _customers[cust_id]
		var state: int = int(customer.get("state", -1))
		if state == SharedTypes.CustomerState.LEFT:
			continue
		var order_id: StringName = customer.get("order_id", &"")
		var recipe_id: StringName = &""
		var wait_remaining := 0.0
		if _orders.has(order_id):
			var order: Dictionary = _orders[order_id]
			recipe_id = order.get("recipe_id", &"")
			if order.get("status", -1) == SharedTypes.OrderStatus.OPEN:
				wait_remaining = maxf(
					0.0,
					float(order.get("deadline_at", 0.0)) - _last_service_now
				)
		var eat_remaining := 0.0
		if state == SharedTypes.CustomerState.EATING:
			eat_remaining = maxf(
				0.0,
				float(customer.get("eat_until", 0.0)) - _last_service_now
			)
		result.append({
			"customer_id": cust_id,
			"state": state,
			"assigned_table_id": customer.get("assigned_table_id", &""),
			"order_id": order_id,
			"recipe_id": recipe_id,
			"wait_seconds_remaining": wait_remaining,
			"wait_total_seconds": patience_total,
			"eat_seconds_remaining": eat_remaining,
			"eat_total_seconds": eat_total,
			"queue_index": int(queue_positions.get(cust_id, -1)),
		})
	return result


func get_customer_queue_view() -> Dictionary:
	return {
		"day_queue_initial": _day_queue_initial,
		"day_queue_remaining": _day_queue_remaining,
		"completed_dine_in_count": _completed_dine_in_count,
		"completed_online_count": _completed_online_count,
		"failed_dine_in_count": _failed_dine_in_count,
		"outside_dinein_count": _outside_dine_in_queue.size(),
		"in_shop_count": _in_shop_dine_in_count,
		"online_open_count": _online_orders_open.size(),
		"outside_driver_count": _outside_driver_queue.size(),
	}


func get_table_view(table_id: StringName) -> Dictionary:
	if not _tables.has(table_id):
		return {}
	return _tables[table_id].duplicate(true)


func get_driver_views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary[StringName, bool] = {}

	for spot_id in PICKUP_SPOT_IDS:
		var driver_id := StringName(_pickup_spot_to_driver.get(spot_id, &""))
		if driver_id == &"" or not _drivers.has(driver_id) or seen.has(driver_id):
			continue
		seen[driver_id] = true
		result.append(_build_driver_view(driver_id, -1))

	for i in range(_outside_driver_queue.size()):
		var driver_id: StringName = _outside_driver_queue[i]
		if driver_id == &"" or not _drivers.has(driver_id) or seen.has(driver_id):
			continue
		seen[driver_id] = true
		result.append(_build_driver_view(driver_id, i))

	return result


func get_online_offer_view() -> Dictionary:
	var offer_state := int(_online_offer.get("state", OnlineOfferState.NOT_SERVING))
	var preview_id := StringName(&"")
	var offer_seconds_remaining := 0.0
	var next_offer_in_seconds := 0.0
	if offer_state == OnlineOfferState.AVAILABLE:
		preview_id = StringName(_online_offer.get("preview_recipe_id", &""))
		offer_seconds_remaining = maxf(
			0.0, float(_online_offer.get("offer_expires_at", 0.0)) - _last_service_now
		)
	elif offer_state == OnlineOfferState.WAITING:
		next_offer_in_seconds = maxf(
			0.0, float(_online_offer.get("next_offer_at", 0.0)) - _last_service_now
		)

	return {
		"offer_state": offer_state,
		"offer_state_name": _online_offer_state_name(offer_state),
		"preview_recipe_id": preview_id,
		"offer_generation_number": int(_online_offer.get("offer_generation_number", 0)),
		"acceptance_enabled": get_online_acceptance_enabled(),
		"disabled_reason": _get_online_disabled_reason(),
		"online_open_count": _online_orders_open.size(),
		"concurrent_limit": _day_queue_initial,
		"offer_seconds_remaining": offer_seconds_remaining,
		"offer_total_seconds": _get_online_offer_active_duration_seconds(),
		"next_offer_in_seconds": next_offer_in_seconds,
		"wait_total_seconds": float(
			_online_offer.get("wait_total_seconds", _get_online_offer_interval_seconds())
		),
	}


func get_online_acceptance_enabled() -> bool:
	return _get_online_disabled_reason() == &""


## Returns read-only recipe demand across live OPEN dine-in and online orders
## plus daily selected menu IDs so KitchenController cooks only genuinely needed stock.
func get_active_order_demand_summary() -> Dictionary:
	var open_recipes: Dictionary[StringName, int] = {}
	var open_count := 0
	for ord_id in _get_sorted_order_ids():
		var order: Dictionary = _orders[ord_id]
		if int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
			continue
		if _service_active and float(order.get("deadline_at", 0.0)) <= _last_service_now:
			continue
		var r_id := StringName(order.get("recipe_id", &""))
		if r_id == &"":
			continue
		open_recipes[r_id] = int(open_recipes.get(r_id, 0)) + 1
		open_count += 1
	return {
		"open_recipes": open_recipes,
		"selected_recipe_ids": _selected_recipe_ids.duplicate(),
		"open_order_count": open_count,
	}


## Returns read-only runtime state snapshots for active Kasir & Pelayan workers.
func get_employee_worker_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in _cashier_workers:
		out.append(w.duplicate(true))
	for w: Dictionary in _waiter_workers:
		out.append(w.duplicate(true))
	return out


func _get_online_disabled_reason() -> StringName:
	if not _service_active or not _day_prepared:
		return &"not_serving"
	if _selected_recipe_ids.is_empty():
		return &"empty_menu"
	if _online_offer_has_invalid_menu_prices():
		return &"invalid_price"
	if _day_queue_remaining <= 2:
		return &"cutoff_reached"
	if _online_orders_open.size() >= _day_queue_initial:
		return &"concurrent_cap_reached"
	var offer_state := int(_online_offer.get("state", OnlineOfferState.NOT_SERVING))
	if offer_state != OnlineOfferState.AVAILABLE:
		return &"offer_waiting"
	var preview_id := StringName(_online_offer.get("preview_recipe_id", &""))
	if preview_id == &"" or not _selected_recipe_ids.has(preview_id):
		return &"offer_waiting"
	if not _has_valid_recipe_price(preview_id):
		return &"invalid_price"
	return &""


func _reset_pickup_spots() -> void:
	_pickup_spot_to_driver.clear()
	for spot_id in PICKUP_SPOT_IDS:
		_pickup_spot_to_driver[spot_id] = &""


func _ensure_economy_config() -> void:
	if _economy_config != null:
		return
	var loaded: Variant = load(DEFAULT_ECONOMY_CONFIG_PATH)
	if loaded is EconomyConfig:
		_economy_config = loaded as EconomyConfig


func _get_patience_seconds() -> float:
	var base := DEFAULT_PATIENCE_SECONDS
	if _economy_config != null and _economy_config.diner_patience_seconds > 0.0:
		base = _economy_config.diner_patience_seconds
	return base + maxf(0.0, _cashier_patience_bonus_seconds)


func _get_spawn_interval_seconds() -> float:
	if _economy_config != null and _economy_config.diner_spawn_interval_seconds > 0.0:
		return _economy_config.diner_spawn_interval_seconds
	return DEFAULT_SPAWN_INTERVAL_SECONDS


func _get_eat_seconds() -> float:
	if _economy_config != null and _economy_config.diner_eat_seconds > 0.0:
		return _economy_config.diner_eat_seconds
	return DEFAULT_EAT_SECONDS


func _get_online_deadline_seconds() -> float:
	if _economy_config != null and _economy_config.online_deadline_seconds > 0.0:
		return _economy_config.online_deadline_seconds
	return DEFAULT_ONLINE_DEADLINE_SECONDS


func _get_online_offer_initial_delay_seconds() -> float:
	if (
		_economy_config != null
		and _economy_config.online_offer_initial_delay_seconds >= 0.0
	):
		return _economy_config.online_offer_initial_delay_seconds
	return DEFAULT_ONLINE_OFFER_INITIAL_DELAY_SECONDS


func _get_online_offer_interval_seconds() -> float:
	if _economy_config != null and _economy_config.online_offer_interval_seconds > 0.0:
		return _economy_config.online_offer_interval_seconds
	return DEFAULT_ONLINE_OFFER_INTERVAL_SECONDS


func _get_online_offer_active_duration_seconds() -> float:
	if (
		_economy_config != null
		and _economy_config.online_offer_active_duration_seconds > 0.0
	):
		return _economy_config.online_offer_active_duration_seconds
	return DEFAULT_ONLINE_OFFER_ACTIVE_DURATION_SECONDS


func _has_valid_recipe_price(recipe_id: StringName) -> bool:
	return recipe_id != &"" and int(_dine_in_prices.get(recipe_id, 0)) > 0


func _credit_order_with_invariant_guard(
	order_id: StringName,
	recipe_id: StringName,
	order_kind: int
) -> void:
	if _run_controller != null and is_instance_valid(_run_controller):
		var credited: bool = _run_controller.credit_order_once(
			order_id,
			recipe_id,
			order_kind
		)
		if not credited:
			_last_invariant_error = (
				"ServiceController: credit_order_once failed for order '%s' (%s)."
				% [order_id, recipe_id]
			)
			push_error(_last_invariant_error)
	elif _game_root != null and is_instance_valid(_game_root):
		_last_invariant_error = (
			"ServiceController: missing RunController for order '%s' (%s)."
			% [order_id, recipe_id]
		)
		push_error(_last_invariant_error)


func _is_game_paused() -> bool:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_paused")
	):
		return bool(_game_root.is_paused())
	return false


func _get_live_clock_now() -> float:
	var live_now := _last_service_now
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_service_elapsed")
	):
		live_now = maxf(live_now, float(_game_root.get_service_elapsed()))
	return live_now


func _sync_service_now_from_clock() -> void:
	var elapsed := _get_live_clock_now()
	if elapsed > _last_service_now:
		_last_service_now = elapsed
		var changed := _tick_service_spawns_and_timers(_last_service_now)
		_emit_tick_signals(changed)


func _emit_tick_signals(changed: Dictionary) -> void:
	if changed.get("orders", false):
		orders_changed.emit()
	if changed.get("queues", false):
		queues_changed.emit()
	if changed.get("tables", false):
		tables_changed.emit()
	if changed.get("drivers", false):
		drivers_changed.emit()
	if changed.get("online", false):
		online_offer_changed.emit()


func _tick_service_spawns_and_timers(now: float) -> Dictionary:
	var changed: Dictionary = {
		"orders": false,
		"queues": false,
		"tables": false,
		"drivers": false,
		"online": false,
	}

	var interval := _get_spawn_interval_seconds()
	while _day_queue_remaining > 0 and _next_spawn_at <= now:
		if _spawn_next_dine_in_customer(_next_spawn_at):
			changed["orders"] = true
			changed["queues"] = true
			changed["tables"] = true
			changed["online"] = true
		_next_spawn_at += interval

	if _process_eating_completions(now):
		changed["queues"] = true
		changed["tables"] = true

	var exp := _process_order_expiries(now)
	if exp.get("dinein", false):
		changed["orders"] = true
		changed["queues"] = true
		changed["tables"] = true
	if exp.get("online", false):
		changed["orders"] = true
		changed["queues"] = true
		changed["drivers"] = true
		changed["online"] = true

	if _admit_outside_waiters(now):
		changed["orders"] = true
		changed["queues"] = true
		changed["tables"] = true

	if _promote_outside_drivers(now):
		changed["orders"] = true
		changed["queues"] = true
		changed["drivers"] = true
		changed["online"] = true

	if _update_online_offer_lifecycle(now):
		changed["online"] = true

	_process_cashier_work(now, changed)
	_process_waiter_work(now, changed)

	return changed


func _spawn_next_dine_in_customer(spawn_at: float) -> bool:
	if _day_queue_remaining <= 0:
		return false
	var recipe_id := _pick_weighted_recipe_id()
	if recipe_id == &"":
		return false

	_day_queue_remaining -= 1
	_arrived_dine_in_count += 1
	_next_customer_seq += 1
	_next_order_seq += 1

	var customer_id := StringName("cust_d%d_%03d" % [_day_index, _next_customer_seq])
	var order_id := StringName("ord_d%d_%03d" % [_day_index, _next_order_seq])
	var deadline_at := spawn_at + _get_patience_seconds()

	_orders[order_id] = {
		"order_id": order_id,
		"kind": SharedTypes.OrderKind.DINE_IN,
		"status": SharedTypes.OrderStatus.OPEN,
		"recipe_id": recipe_id,
		"created_at": spawn_at,
		"deadline_at": deadline_at,
		"customer_id_or_empty": customer_id,
		"driver_id_or_empty": &"",
		"table_id_or_empty": &"",
		"pickup_spot_id_or_empty": &"",
	}

	var table_id := &""
	if _outside_dine_in_queue.is_empty():
		table_id = _find_lowest_clean_vacant_table_id()

	if table_id != &"":
		_customers[customer_id] = {
			"customer_id": customer_id,
			"state": SharedTypes.CustomerState.SEATED_WAITING,
			"assigned_table_id": table_id,
			"order_id": order_id,
			"eat_until": 0.0,
		}
		_orders[order_id]["table_id_or_empty"] = table_id
		var table: Dictionary = _tables[table_id]
		table["state"] = SharedTypes.TableState.OCCUPIED_WAITING
		table["customer_id_or_empty"] = customer_id
		table["order_id_or_empty"] = order_id
		_in_shop_dine_in_count += 1
	else:
		_customers[customer_id] = {
			"customer_id": customer_id,
			"state": SharedTypes.CustomerState.OUTSIDE_WAITING,
			"assigned_table_id": &"",
			"order_id": order_id,
			"eat_until": 0.0,
		}
		_outside_dine_in_queue.append(customer_id)

	return true


func _process_eating_completions(now: float) -> bool:
	var any_changed := false
	for cust_id in _get_sorted_customer_ids():
		var customer: Dictionary = _customers[cust_id]
		if customer.get("state", -1) != SharedTypes.CustomerState.EATING:
			continue
		if float(customer.get("eat_until", 0.0)) > now:
			continue

		var table_id: StringName = customer.get("assigned_table_id", &"")
		customer["state"] = SharedTypes.CustomerState.LEFT
		customer["assigned_table_id"] = &""
		_in_shop_dine_in_count = maxi(0, _in_shop_dine_in_count - 1)
		if _tables.has(table_id):
			var table: Dictionary = _tables[table_id]
			table["state"] = SharedTypes.TableState.DIRTY
			table["customer_id_or_empty"] = &""
			table["order_id_or_empty"] = &""
		any_changed = true
	return any_changed


func _process_order_expiries(now: float) -> Dictionary:
	var result: Dictionary = {
		"dinein": false,
		"online": false,
	}
	for order_id in _get_sorted_order_ids():
		var order: Dictionary = _orders[order_id]
		if order.get("status", -1) != SharedTypes.OrderStatus.OPEN:
			continue
		if float(order.get("deadline_at", 0.0)) > now:
			continue
		var kind := int(order.get("kind", -1))
		if kind == SharedTypes.OrderKind.DINE_IN:
			_expire_dine_in_order(order_id)
			result["dinein"] = true
		elif kind == SharedTypes.OrderKind.ONLINE:
			_expire_online_order(order_id)
			result["online"] = true
	return result


func _expire_online_order(order_id: StringName) -> void:
	if not _orders.has(order_id):
		return
	var order: Dictionary = _orders[order_id]
	if (
		int(order.get("kind", -1)) != SharedTypes.OrderKind.ONLINE
		or int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN
	):
		return

	order["status"] = SharedTypes.OrderStatus.FAILED
	_online_orders_open.erase(order_id)
	_failed_order_ids.append(order_id)
	_failed_online_count += 1

	var driver_id := StringName(order.get("driver_id_or_empty", &""))
	var spot_id := StringName(order.get("pickup_spot_id_or_empty", &""))
	order["pickup_spot_id_or_empty"] = &""
	if spot_id != &"" and _pickup_spot_to_driver.get(spot_id, &"") == driver_id:
		_pickup_spot_to_driver[spot_id] = &""
	if driver_id != &"":
		_outside_driver_queue.erase(driver_id)
		_drivers.erase(driver_id)


func _promote_outside_drivers(now: float) -> bool:
	var any_changed := false
	while not _outside_driver_queue.is_empty():
		var spot_id := _find_lowest_free_pickup_spot_id()
		if spot_id == &"":
			break

		var driver_id: StringName = _outside_driver_queue.pop_front()
		if not _drivers.has(driver_id):
			continue
		var driver: Dictionary = _drivers[driver_id]
		var order_id := StringName(driver.get("order_id", &""))
		if not _orders.has(order_id):
			_drivers.erase(driver_id)
			continue
		var order: Dictionary = _orders[order_id]
		if (
			int(order.get("kind", -1)) != SharedTypes.OrderKind.ONLINE
			or int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN
		):
			_drivers.erase(driver_id)
			continue
		if float(order.get("deadline_at", 0.0)) <= now:
			_expire_online_order(order_id)
			any_changed = true
			continue

		driver["state"] = SharedTypes.DriverState.AT_PICKUP_SPOT
		driver["spot_id_or_empty"] = spot_id
		_pickup_spot_to_driver[spot_id] = driver_id
		order["pickup_spot_id_or_empty"] = spot_id
		any_changed = true

	return any_changed


func _find_lowest_free_pickup_spot_id() -> StringName:
	for spot_id in PICKUP_SPOT_IDS:
		if StringName(_pickup_spot_to_driver.get(spot_id, &"")) == &"":
			return spot_id
	return &""


func _build_driver_view(driver_id: StringName, queue_index: int) -> Dictionary:
	var driver: Dictionary = _drivers.get(driver_id, {})
	var order_id := StringName(driver.get("order_id", &""))
	var order: Dictionary = _orders.get(order_id, {})
	var state := int(driver.get("state", SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE))
	var spot_id := StringName(driver.get("spot_id_or_empty", &""))
	var total_seconds := _get_online_deadline_seconds()
	var deadline_at: float = float(order.get("deadline_at", 0.0))
	var seconds_remaining := 0.0
	var is_open: bool = int(order.get("status", -1)) == SharedTypes.OrderStatus.OPEN
	if is_open:
		seconds_remaining = clampf(deadline_at - _last_service_now, 0.0, total_seconds)
	var is_serveable: bool = (
		_service_active
		and state == SharedTypes.DriverState.AT_PICKUP_SPOT
		and spot_id != &""
		and _pickup_spot_to_driver.get(spot_id, &"") == driver_id
		and is_open
		and _last_service_now < deadline_at
	)
	var out_queue_idx := -1
	if state == SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE:
		out_queue_idx = queue_index
	return {
		"driver_id": driver_id,
		"order_id": order_id,
		"recipe_id": StringName(order.get("recipe_id", &"")),
		"state": state,
		"spot_id_or_empty": spot_id,
		"seconds_remaining": seconds_remaining,
		"total_seconds": total_seconds,
		"serveable": is_serveable,
		"queue_index": out_queue_idx,
	}


func _expire_dine_in_order(order_id: StringName) -> void:
	if not _orders.has(order_id):
		return
	var order: Dictionary = _orders[order_id]
	if order.get("status", -1) != SharedTypes.OrderStatus.OPEN:
		return

	order["status"] = SharedTypes.OrderStatus.FAILED
	_failed_order_ids.append(order_id)
	_failed_dine_in_count += 1

	var cust_id: StringName = order.get("customer_id_or_empty", &"")
	if not _customers.has(cust_id):
		return
	var customer: Dictionary = _customers[cust_id]
	var prev_state: int = int(customer.get("state", -1))
	var table_id: StringName = customer.get("assigned_table_id", &"")
	customer["state"] = SharedTypes.CustomerState.LEFT
	customer["assigned_table_id"] = &""

	if prev_state == SharedTypes.CustomerState.SEATED_WAITING:
		_in_shop_dine_in_count = maxi(0, _in_shop_dine_in_count - 1)
		if _tables.has(table_id):
			var table: Dictionary = _tables[table_id]
			table["state"] = SharedTypes.TableState.CLEAN_VACANT
			table["customer_id_or_empty"] = &""
			table["order_id_or_empty"] = &""
	elif prev_state == SharedTypes.CustomerState.OUTSIDE_WAITING:
		_outside_dine_in_queue.erase(cust_id)


func _admit_outside_waiters(now: float) -> bool:
	var any_seated := false
	while not _outside_dine_in_queue.is_empty():
		var table_id := _find_lowest_clean_vacant_table_id()
		if table_id == &"":
			break

		var cust_id: StringName = _outside_dine_in_queue.pop_front()
		if not _customers.has(cust_id):
			continue
		var customer: Dictionary = _customers[cust_id]
		var order_id: StringName = customer.get("order_id", &"")
		if not _orders.has(order_id):
			continue
		var order: Dictionary = _orders[order_id]
		if order.get("status", -1) != SharedTypes.OrderStatus.OPEN:
			continue
		if float(order.get("deadline_at", 0.0)) <= now:
			_expire_dine_in_order(order_id)
			continue

		customer["state"] = SharedTypes.CustomerState.SEATED_WAITING
		customer["assigned_table_id"] = table_id
		order["table_id_or_empty"] = table_id

		var table: Dictionary = _tables[table_id]
		table["state"] = SharedTypes.TableState.OCCUPIED_WAITING
		table["customer_id_or_empty"] = cust_id
		table["order_id_or_empty"] = order_id
		_in_shop_dine_in_count += 1
		any_seated = true

	return any_seated


func _find_lowest_clean_vacant_table_id() -> StringName:
	for table_id in get_registered_table_ids():
		var table: Dictionary = _tables[table_id]
		if table.get("state", -1) == SharedTypes.TableState.CLEAN_VACANT:
			return table_id
	return &""


func _pick_weighted_recipe_id() -> StringName:
	if _selected_recipe_ids.is_empty():
		return &""
	if _selected_recipe_ids.size() == 1:
		return _selected_recipe_ids[0]

	var total_weight := 0.0
	var weights: Array[float] = []
	for recipe_id in _selected_recipe_ids:
		var price: int = maxi(1, int(_dine_in_prices.get(recipe_id, 10000)))
		var w := 1.0 / float(price)
		weights.append(w)
		total_weight += w

	if total_weight <= 0.0:
		return _selected_recipe_ids[0]

	var roll := _rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for i in range(_selected_recipe_ids.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return _selected_recipe_ids[i]
	return _selected_recipe_ids[-1]


func _get_sorted_customer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_customers.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _get_sorted_order_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_orders.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _make_empty_online_offer() -> Dictionary:
	return {
		"state": OnlineOfferState.NOT_SERVING,
		"preview_recipe_id": &"",
		"offer_generation_number": 0,
		"next_offer_at": 0.0,
		"offer_expires_at": 0.0,
		"wait_total_seconds": _get_online_offer_interval_seconds(),
	}


func _online_offer_state_name(state: int) -> StringName:
	match state:
		OnlineOfferState.NOT_SERVING:
			return &"not_serving"
		OnlineOfferState.WAITING:
			return &"waiting"
		OnlineOfferState.AVAILABLE:
			return &"available"
		OnlineOfferState.UNAVAILABLE:
			return &"unavailable"
	return &"not_serving"


func _online_offer_has_invalid_menu_prices() -> bool:
	for recipe_id in _selected_recipe_ids:
		if not _has_valid_recipe_price(recipe_id):
			return true
	return false


func _is_online_service_restricted() -> bool:
	if _selected_recipe_ids.is_empty():
		return true
	if _online_offer_has_invalid_menu_prices():
		return true
	if _day_queue_remaining <= 2:
		return true
	if _online_orders_open.size() >= _day_queue_initial:
		return true
	return false


func _update_online_offer_lifecycle(now: float) -> bool:
	var prev_state := int(_online_offer.get("state", OnlineOfferState.NOT_SERVING))
	var prev_preview := StringName(_online_offer.get("preview_recipe_id", &""))
	var prev_gen := int(_online_offer.get("offer_generation_number", 0))

	if not _service_active or not _day_prepared:
		_online_offer["state"] = OnlineOfferState.NOT_SERVING
		_online_offer["preview_recipe_id"] = &""
		_online_offer["offer_expires_at"] = 0.0
		return (
			prev_state != OnlineOfferState.NOT_SERVING
			or prev_preview != &""
		)

	if _is_online_service_restricted():
		_online_offer["state"] = OnlineOfferState.UNAVAILABLE
		_online_offer["preview_recipe_id"] = &""
		_online_offer["offer_expires_at"] = 0.0
		return (
			prev_state != OnlineOfferState.UNAVAILABLE
			or prev_preview != &""
		)

	var state := prev_state
	if state == OnlineOfferState.NOT_SERVING or state == OnlineOfferState.UNAVAILABLE:
		var interval := _get_online_offer_interval_seconds()
		if float(_online_offer.get("next_offer_at", 0.0)) <= now:
			_online_offer["next_offer_at"] = now + interval
			_online_offer["wait_total_seconds"] = interval
		_online_offer["state"] = OnlineOfferState.WAITING
		_online_offer["preview_recipe_id"] = &""
		_online_offer["offer_expires_at"] = 0.0
		state = OnlineOfferState.WAITING

	if state == OnlineOfferState.AVAILABLE:
		if now >= float(_online_offer.get("offer_expires_at", 0.0)):
			var interval := _get_online_offer_interval_seconds()
			_online_offer["state"] = OnlineOfferState.WAITING
			_online_offer["preview_recipe_id"] = &""
			_online_offer["offer_expires_at"] = 0.0
			_online_offer["next_offer_at"] = now + interval
			_online_offer["wait_total_seconds"] = interval
			state = OnlineOfferState.WAITING

	if state == OnlineOfferState.WAITING:
		if now >= float(_online_offer.get("next_offer_at", 0.0)):
			var active_duration := _get_online_offer_active_duration_seconds()
			var picked_id := _pick_weighted_recipe_id()
			if picked_id != &"":
				_online_offer["state"] = OnlineOfferState.AVAILABLE
				_online_offer["preview_recipe_id"] = picked_id
				_online_offer["offer_expires_at"] = now + active_duration
				_online_offer["offer_generation_number"] = prev_gen + 1
			else:
				_online_offer["state"] = OnlineOfferState.UNAVAILABLE
				_online_offer["preview_recipe_id"] = &""
				_online_offer["offer_expires_at"] = 0.0

	var new_state := int(_online_offer.get("state", OnlineOfferState.NOT_SERVING))
	var new_preview := StringName(_online_offer.get("preview_recipe_id", &""))
	var new_gen := int(_online_offer.get("offer_generation_number", 0))
	return (
		new_state != prev_state
		or new_preview != prev_preview
		or new_gen != prev_gen
	)


func get_workforce_action_counts() -> Dictionary:
	return _workforce_action_counts.duplicate(true)


func _reset_workforce_runtime() -> void:
	_cashier_count = 0
	_cashier_interval_seconds = 0.0
	_cashier_patience_bonus_seconds = 0.0
	_next_cashier_action_at = INF
	_waiter_count = 0
	_waiter_interval_seconds = 0.0
	_next_waiter_action_at = INF
	_prev_tick_now = 0.0
	_cashier_workers.clear()
	_waiter_workers.clear()
	_workforce_action_counts = {
		&"cashier": 0,
		&"waiter": 0,
	}


func _configure_workforce_from_plan(plan: Dictionary) -> void:
	_reset_workforce_runtime()
	_ensure_economy_config()
	var wf: Variant = plan.get("workforce_summary", {})
	if not (wf is Dictionary):
		return
	var by_role: Variant = (wf as Dictionary).get("by_role", {})
	if not (by_role is Dictionary):
		return
	var roles := by_role as Dictionary

	var cashier_info: Variant = roles.get(&"cashier", {})
	if cashier_info is Dictionary:
		var c_dict := cashier_info as Dictionary
		_cashier_count = maxi(0, int(c_dict.get("count", 0)))
		_cashier_interval_seconds = maxf(0.0, float(c_dict.get("effective_interval", 0.0)))
		var c_factor := maxf(0.0, float(c_dict.get("effective_factor", 0.0)))
		var base_bonus := (
			_economy_config.employee_cashier_patience_bonus_seconds
			if _economy_config != null
			else 12.0
		)
		_cashier_patience_bonus_seconds = minf(25.0, base_bonus * c_factor)

	var waiter_info: Variant = roles.get(&"waiter", {})
	if waiter_info is Dictionary:
		var w_dict := waiter_info as Dictionary
		_waiter_count = maxi(0, int(w_dict.get("count", 0)))
		_waiter_interval_seconds = maxf(0.0, float(w_dict.get("effective_interval", 0.0)))

	var raw_emps: Variant = plan.get("employees", [])
	if raw_emps is Array:
		var c_cycle := (
			_cashier_interval_seconds * float(_cashier_count)
			if _cashier_count > 0
			else 0.0
		)
		var w_cycle := (
			_waiter_interval_seconds * float(_waiter_count)
			if _waiter_count > 0
			else 0.0
		)
		for raw_e: Variant in (raw_emps as Array):
			if not (raw_e is Dictionary):
				continue
			var emp := raw_e as Dictionary
			var role_id := StringName(emp.get("role_id", &""))
			var worker := {
				"employee_id": StringName(emp.get("employee_id", &"")),
				"role_id": role_id,
				"display_name": String(emp.get("display_name", "")),
				"state": SharedTypes.EmployeeAnimState.IDLE,
				"target_id": &"",
				"hold_recipe_id": &"",
				"hold_ingredient_id": &"",
				"cycle_interval": c_cycle if role_id == &"cashier" else w_cycle,
				"phase_started_at": 0.0,
				"phase_until": 0.0,
				"next_task_at": 0.0,
				"pending_task": {},
			}
			if role_id == &"cashier":
				_cashier_workers.append(worker)
			elif role_id == &"waiter":
				_waiter_workers.append(worker)


func _clear_service_worker_task(worker: Dictionary, next_at: float) -> void:
	worker["state"] = SharedTypes.EmployeeAnimState.IDLE
	worker["target_id"] = &""
	worker["hold_recipe_id"] = &""
	worker["hold_ingredient_id"] = &""
	worker["phase_started_at"] = 0.0
	worker["phase_until"] = 0.0
	worker["next_task_at"] = next_at
	worker["pending_task"] = {}


func _complete_dine_in_table_serve(
	table_id: StringName,
	order_id: StringName,
	customer_id: StringName,
	recipe_id: StringName
) -> void:
	var table: Dictionary = _tables[table_id]
	var order: Dictionary = _orders[order_id]
	order["status"] = SharedTypes.OrderStatus.COMPLETED
	_completed_order_ids.append(order_id)
	_completed_dine_in_count += 1

	var customer: Dictionary = _customers[customer_id]
	customer["state"] = SharedTypes.CustomerState.EATING
	customer["eat_until"] = _last_service_now + _get_eat_seconds()
	table["state"] = SharedTypes.TableState.OCCUPIED_EATING

	_credit_order_with_invariant_guard(order_id, recipe_id, SharedTypes.OrderKind.DINE_IN)


func _complete_online_driver_serve(
	driver_id: StringName,
	order_id: StringName,
	spot_id: StringName,
	recipe_id: StringName
) -> void:
	var order: Dictionary = _orders[order_id]
	order["status"] = SharedTypes.OrderStatus.COMPLETED
	order["pickup_spot_id_or_empty"] = &""
	_online_orders_open.erase(order_id)
	_completed_order_ids.append(order_id)
	_completed_online_count += 1

	if _pickup_spot_to_driver.get(spot_id, &"") == driver_id:
		_pickup_spot_to_driver[spot_id] = &""
	_drivers.erase(driver_id)
	_promote_outside_drivers(_last_service_now)

	_credit_order_with_invariant_guard(order_id, recipe_id, SharedTypes.OrderKind.ONLINE)
	_update_online_offer_lifecycle(_last_service_now)


func _accept_active_online_offer_at(now: float) -> bool:
	if not get_online_acceptance_enabled():
		return false

	var recipe_id := StringName(_online_offer.get("preview_recipe_id", &""))
	if recipe_id == &"" or not _has_valid_recipe_price(recipe_id):
		return false

	_next_order_seq += 1
	_next_driver_seq += 1
	var order_id := StringName("ord_d%d_%03d" % [_day_index, _next_order_seq])
	var driver_id := StringName("drv_d%d_%03d" % [_day_index, _next_driver_seq])
	var deadline_at := now + _get_online_deadline_seconds()

	_orders[order_id] = {
		"order_id": order_id,
		"kind": SharedTypes.OrderKind.ONLINE,
		"status": SharedTypes.OrderStatus.OPEN,
		"recipe_id": recipe_id,
		"created_at": now,
		"deadline_at": deadline_at,
		"customer_id_or_empty": &"",
		"driver_id_or_empty": driver_id,
		"table_id_or_empty": &"",
		"pickup_spot_id_or_empty": &"",
	}
	_online_orders_open.append(order_id)

	var spot_id := _find_lowest_free_pickup_spot_id()
	if spot_id != &"":
		_pickup_spot_to_driver[spot_id] = driver_id
		_orders[order_id]["pickup_spot_id_or_empty"] = spot_id
		_drivers[driver_id] = {
			"driver_id": driver_id,
			"order_id": order_id,
			"state": SharedTypes.DriverState.AT_PICKUP_SPOT,
			"spot_id_or_empty": spot_id,
		}
	else:
		_drivers[driver_id] = {
			"driver_id": driver_id,
			"order_id": order_id,
			"state": SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE,
			"spot_id_or_empty": &"",
		}
		_outside_driver_queue.append(driver_id)

	var interval := _get_online_offer_interval_seconds()
	_online_offer["preview_recipe_id"] = &""
	_online_offer["offer_expires_at"] = 0.0
	_online_offer["next_offer_at"] = now + interval
	_online_offer["wait_total_seconds"] = interval
	if _is_online_service_restricted():
		_online_offer["state"] = OnlineOfferState.UNAVAILABLE
	else:
		_online_offer["state"] = OnlineOfferState.WAITING
	return true


func _process_cashier_work(now: float, changed: Dictionary) -> void:
	if _cashier_count <= 0 or _cashier_interval_seconds <= 0.0 or _cashier_workers.is_empty():
		return
	var step_span := now - _prev_tick_now
	for worker: Dictionary in _cashier_workers:
		var cycle := maxf(0.5, float(worker.get("cycle_interval", _cashier_interval_seconds)))
		var work_dur := minf(0.65, cycle * 0.25)
		var state := int(worker.get("state", SharedTypes.EmployeeAnimState.IDLE))
		if state == SharedTypes.EmployeeAnimState.WORK and now >= float(worker.get("phase_until", 0.0)):
			if _find_lowest_free_pickup_spot_id() != &"" and _accept_active_online_offer_at(now):
				_workforce_action_counts[&"cashier"] = (
					int(_workforce_action_counts.get(&"cashier", 0)) + 1
				)
				changed["orders"] = true
				changed["queues"] = true
				changed["drivers"] = true
				changed["online"] = true
			_clear_service_worker_task(
				worker,
				float(worker.get("phase_started_at", now)) + cycle
			)
			state = SharedTypes.EmployeeAnimState.IDLE

		if state == SharedTypes.EmployeeAnimState.IDLE and now >= float(worker.get("next_task_at", 0.0)):
			if (
				not _has_active_cashier_intake(worker)
				and _find_lowest_free_pickup_spot_id() != &""
				and get_online_acceptance_enabled()
			):
				var start_t := (
					maxf(float(worker.get("next_task_at", 0.0)), _prev_tick_now)
					if step_span > 1.25
					else now
				)
				if start_t + work_dur <= now:
					if _accept_active_online_offer_at(start_t + work_dur):
						_workforce_action_counts[&"cashier"] = (
							int(_workforce_action_counts.get(&"cashier", 0)) + 1
						)
						changed["orders"] = true
						changed["queues"] = true
						changed["drivers"] = true
						changed["online"] = true
					_clear_service_worker_task(worker, start_t + cycle)
				else:
					worker["state"] = SharedTypes.EmployeeAnimState.WORK
					worker["target_id"] = &"online_station"
					worker["phase_started_at"] = start_t
					worker["phase_until"] = start_t + work_dur
					worker["pending_task"] = {"kind": &"accept_online"}


func _has_active_cashier_intake(exclude_worker: Dictionary) -> bool:
	var ex_id := StringName(exclude_worker.get("employee_id", &""))
	for w: Dictionary in _cashier_workers:
		if StringName(w.get("employee_id", &"")) == ex_id:
			continue
		if int(w.get("state", SharedTypes.EmployeeAnimState.IDLE)) != SharedTypes.EmployeeAnimState.IDLE:
			return true
	return false


func _process_waiter_work(now: float, changed: Dictionary) -> void:
	if _waiter_count <= 0 or _waiter_interval_seconds <= 0.0 or _waiter_workers.is_empty():
		return
	var step_span := now - _prev_tick_now
	for worker: Dictionary in _waiter_workers:
		var cycle := maxf(0.5, float(worker.get("cycle_interval", _waiter_interval_seconds)))
		var walk_dur := minf(0.55, cycle * 0.18)
		var work_dur := minf(1.10, cycle * 0.35)
		var guard := 0
		while guard < 4:
			guard += 1
			var state := int(worker.get("state", SharedTypes.EmployeeAnimState.IDLE))
			if state == SharedTypes.EmployeeAnimState.WALK:
				var walk_until := float(worker.get("phase_until", 0.0))
				if now < walk_until:
					break
				var pending: Dictionary = worker.get("pending_task", {})
				var t_kind := StringName(pending.get("kind", &""))
				worker["state"] = (
					SharedTypes.EmployeeAnimState.CLEAN
					if t_kind == &"clean_table"
					else SharedTypes.EmployeeAnimState.SERVE
				)
				worker["phase_until"] = walk_until + work_dur
				continue
			if (
				state == SharedTypes.EmployeeAnimState.CLEAN
				or state == SharedTypes.EmployeeAnimState.SERVE
			):
				var work_until := float(worker.get("phase_until", 0.0))
				if now < work_until:
					break
				var task: Dictionary = worker.get("pending_task", {})
				if _execute_waiter_task(task, now, changed):
					_workforce_action_counts[&"waiter"] = (
						int(_workforce_action_counts.get(&"waiter", 0)) + 1
					)
				_clear_service_worker_task(
					worker,
					float(worker.get("phase_started_at", now)) + cycle
				)
				break
			if now < float(worker.get("next_task_at", 0.0)):
				break
			var next_task := _claim_next_waiter_task(worker, now)
			if next_task.is_empty():
				break
			var start_t := (
				maxf(float(worker.get("next_task_at", 0.0)), _prev_tick_now)
				if step_span > 1.25
				else now
			)
			worker["state"] = SharedTypes.EmployeeAnimState.WALK
			worker["target_id"] = StringName(next_task.get("target_id", &""))
			worker["hold_recipe_id"] = StringName(next_task.get("recipe_id", &""))
			worker["phase_started_at"] = start_t
			worker["phase_until"] = start_t + walk_dur
			worker["pending_task"] = next_task
			if step_span <= 1.25:
				break


func _claim_next_waiter_task(worker: Dictionary, now: float) -> Dictionary:
	var emp_id := StringName(worker.get("employee_id", &""))
	var claimed_tables: Dictionary[StringName, bool] = {}
	var claimed_counters: Dictionary[StringName, bool] = {}
	var claimed_targets: Dictionary[StringName, bool] = {}
	for other: Dictionary in _waiter_workers:
		if StringName(other.get("employee_id", &"")) == emp_id:
			continue
		if int(other.get("state", SharedTypes.EmployeeAnimState.IDLE)) == SharedTypes.EmployeeAnimState.IDLE:
			continue
		var p: Dictionary = other.get("pending_task", {})
		var tid := StringName(p.get("target_id", &""))
		var cid := StringName(p.get("work_table_id", &""))
		if tid != &"":
			claimed_targets[tid] = true
			if StringName(p.get("kind", &"")) == &"clean_table":
				claimed_tables[tid] = true
		if cid != &"":
			claimed_counters[cid] = true

	for table_id in get_registered_table_ids():
		if claimed_tables.has(table_id):
			continue
		var table: Dictionary = _tables[table_id]
		if (
			table.get("state", -1) == SharedTypes.TableState.DIRTY
			and table.get("customer_id_or_empty", &"") == &""
		):
			return {
				"kind": &"clean_table",
				"target_id": table_id,
			}

	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or not _kitchen_controller.has_method(&"find_completed_staged_dish_for_recipes")
	):
		return {}

	var candidates := _collect_urgent_serve_candidates(now)
	for cand: Dictionary in candidates:
		var target_id := StringName(cand.get("target_id", &""))
		if claimed_targets.has(target_id):
			continue
		var recipe_id := StringName(cand.get("recipe_id", &""))
		var staged_match: Dictionary = _kitchen_controller.find_completed_staged_dish_for_recipes(
			[recipe_id] as Array[StringName],
			claimed_counters
		)
		if staged_match.is_empty():
			continue
		return {
			"kind": &"serve_staged",
			"order_kind": int(cand.get("kind", -1)),
			"target_id": target_id,
			"order_id": StringName(cand.get("order_id", &"")),
			"customer_id": StringName(cand.get("customer_id", &"")),
			"spot_id": StringName(cand.get("spot_id", &"")),
			"recipe_id": recipe_id,
			"work_table_id": StringName(staged_match.get("work_table_id", &"")),
			"item_id": StringName(staged_match.get("item_id", &"")),
		}
	return {}


func _execute_waiter_task(task: Dictionary, now: float, changed: Dictionary) -> bool:
	var kind := StringName(task.get("kind", &""))
	if kind == &"clean_table":
		var table_id := StringName(task.get("target_id", &""))
		if _try_waiter_clean_table_by_id(table_id, now):
			changed["orders"] = true
			changed["queues"] = true
			changed["tables"] = true
			return true
		return false
	if kind == &"serve_staged":
		return _execute_waiter_serve_task(task, now, changed)
	return false


func _try_waiter_clean_table_by_id(table_id: StringName, now: float) -> bool:
	if not _tables.has(table_id):
		return false
	var table: Dictionary = _tables[table_id]
	if table.get("state", -1) != SharedTypes.TableState.DIRTY:
		return false
	if table.get("customer_id_or_empty", &"") != &"":
		return false
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		if not _kitchen_controller.move_cleaned_table_plate_to_washer(table_id):
			return false
	table["state"] = SharedTypes.TableState.CLEAN_VACANT
	table["customer_id_or_empty"] = &""
	table["order_id_or_empty"] = &""
	_admit_outside_waiters(now)
	return true


func _collect_urgent_serve_candidates(now: float) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for table_id in get_registered_table_ids():
		var table: Dictionary = _tables[table_id]
		if table.get("state", -1) != SharedTypes.TableState.OCCUPIED_WAITING:
			continue
		var order_id := StringName(table.get("order_id_or_empty", &""))
		var customer_id := StringName(table.get("customer_id_or_empty", &""))
		if not _orders.has(order_id) or not _customers.has(customer_id):
			continue
		var order: Dictionary = _orders[order_id]
		if int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
			continue
		var deadline_at := float(order.get("deadline_at", 0.0))
		if now >= deadline_at:
			continue
		candidates.append({
			"kind": SharedTypes.OrderKind.DINE_IN,
			"target_id": table_id,
			"order_id": order_id,
			"customer_id": customer_id,
			"spot_id": &"",
			"recipe_id": StringName(order.get("recipe_id", &"")),
			"deadline_at": deadline_at,
		})

	for spot_id in PICKUP_SPOT_IDS:
		var driver_id := StringName(_pickup_spot_to_driver.get(spot_id, &""))
		if driver_id == &"" or not _drivers.has(driver_id):
			continue
		var order_id := StringName(_drivers[driver_id].get("order_id", &""))
		if not _orders.has(order_id):
			continue
		var order: Dictionary = _orders[order_id]
		if int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
			continue
		var deadline_at := float(order.get("deadline_at", 0.0))
		if now >= deadline_at:
			continue
		candidates.append({
			"kind": SharedTypes.OrderKind.ONLINE,
			"target_id": driver_id,
			"order_id": order_id,
			"customer_id": &"",
			"spot_id": spot_id,
			"recipe_id": StringName(order.get("recipe_id", &"")),
			"deadline_at": deadline_at,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a.get("deadline_at", 0.0))
		var db := float(b.get("deadline_at", 0.0))
		if not is_equal_approx(da, db):
			return da < db
		return String(a.get("order_id", &"")) < String(b.get("order_id", &""))
	)
	return candidates


func _execute_waiter_serve_task(task: Dictionary, now: float, changed: Dictionary) -> bool:
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or not _kitchen_controller.has_method(&"try_consume_staged_serving_item")
	):
		return false
	var order_id := StringName(task.get("order_id", &""))
	if not _orders.has(order_id):
		return false
	var order: Dictionary = _orders[order_id]
	if int(order.get("status", -1)) != SharedTypes.OrderStatus.OPEN:
		return false
	if now >= float(order.get("deadline_at", 0.0)):
		return false
	var kind := int(task.get("order_kind", -1))
	var target_id := StringName(task.get("target_id", &""))
	var recipe_id := StringName(task.get("recipe_id", &""))
	if kind == SharedTypes.OrderKind.DINE_IN:
		if not _tables.has(target_id):
			return false
		var tv: Dictionary = _tables[target_id]
		if (
			tv.get("state", -1) != SharedTypes.TableState.OCCUPIED_WAITING
			or StringName(tv.get("order_id_or_empty", &"")) != order_id
		):
			return false
	elif kind == SharedTypes.OrderKind.ONLINE:
		var spot_id := StringName(task.get("spot_id", &""))
		if _pickup_spot_to_driver.get(spot_id, &"") != target_id or not _drivers.has(target_id):
			return false
	else:
		return false

	var wt_id := StringName(task.get("work_table_id", &""))
	var item_id := StringName(task.get("item_id", &""))
	var dine_in_table := target_id if kind == SharedTypes.OrderKind.DINE_IN else &""
	if not _kitchen_controller.try_consume_staged_serving_item(
		wt_id, item_id, recipe_id, kind, dine_in_table
	):
		return false
	if kind == SharedTypes.OrderKind.DINE_IN:
		_complete_dine_in_table_serve(
			target_id, order_id, StringName(task.get("customer_id", &"")), recipe_id
		)
		changed["orders"] = true
		changed["queues"] = true
		changed["tables"] = true
		return true
	_complete_online_driver_serve(target_id, order_id, StringName(task.get("spot_id", &"")), recipe_id)
	changed["orders"] = true
	changed["queues"] = true
	changed["drivers"] = true
	changed["online"] = true
	return true
