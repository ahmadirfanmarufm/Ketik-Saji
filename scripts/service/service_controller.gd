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
	"preview_recipe_id": &"",
	"offer_generation_number": 0,
}

var _completed_order_ids: Array[StringName] = []
var _failed_order_ids: Array[StringName] = []
var _completed_dine_in_count: int = 0
var _failed_dine_in_count: int = 0
var _completed_online_count: int = 0
var _failed_online_count: int = 0
var _last_invariant_error: String = ""


func _ready() -> void:
	_reset_pickup_spots()
	_ensure_economy_config()
	if not _custom_seed_set:
		_rng.seed = hash("ketik_saji_service_day_1")


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
	_next_spawn_at = 0.0
	if not _custom_seed_set:
		_rng.seed = hash("ketik_saji_service_day_%d" % _day_index)

	var preview_id: StringName = &""
	if not _selected_recipe_ids.is_empty():
		preview_id = _selected_recipe_ids[0]
	_online_offer = {
		"preview_recipe_id": preview_id,
		"offer_generation_number": 1 if not _selected_recipe_ids.is_empty() else 0,
	}

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
	_next_spawn_at = _last_service_now
	_service_active = true
	_tick_service_spawns_and_timers(_last_service_now)
	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	online_offer_changed.emit()


func advance_service_time(now: float) -> void:
	if not _service_active:
		return
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

	for table: Dictionary in _tables.values():
		table["state"] = SharedTypes.TableState.CLEAN_VACANT
		table["customer_id_or_empty"] = &""
		table["order_id_or_empty"] = &""

	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	drivers_changed.emit()


func try_serve_table(table_id: StringName, item_id: StringName) -> bool:
	if (
		not _service_active
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

	order["status"] = SharedTypes.OrderStatus.COMPLETED
	_completed_order_ids.append(order_id)
	_completed_dine_in_count += 1

	var customer: Dictionary = _customers[customer_id]
	customer["state"] = SharedTypes.CustomerState.EATING
	customer["eat_until"] = _last_service_now + _get_eat_seconds()
	table["state"] = SharedTypes.TableState.OCCUPIED_EATING

	if _run_controller != null and is_instance_valid(_run_controller):
		var credited: bool = _run_controller.credit_order_once(
			order_id,
			recipe_id,
			SharedTypes.OrderKind.DINE_IN
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

	orders_changed.emit()
	queues_changed.emit()
	tables_changed.emit()
	return true


func try_serve_driver(_driver_id: StringName, _item_id: StringName) -> bool:
	return false


func try_clean_table(table_id: StringName) -> bool:
	if not _service_active or not _tables.has(table_id):
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
	if not get_online_acceptance_enabled():
		return false
	return false


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
	for driver: Dictionary in _drivers.values():
		result.append(driver.duplicate(true))
	return result


func get_online_offer_view() -> Dictionary:
	return {
		"preview_recipe_id": _online_offer.get("preview_recipe_id", &""),
		"acceptance_enabled": get_online_acceptance_enabled(),
		"disabled_reason": _get_online_disabled_reason(),
		"online_open_count": _online_orders_open.size(),
		"concurrent_limit": _day_queue_initial,
	}


func get_online_acceptance_enabled() -> bool:
	if not _service_active:
		return false
	if _selected_recipe_ids.is_empty():
		return false
	if _day_queue_remaining <= 2:
		return false
	if _online_orders_open.size() >= _day_queue_initial:
		return false
	return true


func _get_online_disabled_reason() -> StringName:
	if not _service_active:
		return &"not_serving"
	if _selected_recipe_ids.is_empty():
		return &"empty_menu"
	if _day_queue_remaining <= 2:
		return &"cutoff_reached"
	if _online_orders_open.size() >= _day_queue_initial:
		return &"concurrent_cap_reached"
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
	if _economy_config != null and _economy_config.diner_patience_seconds > 0.0:
		return _economy_config.diner_patience_seconds
	return DEFAULT_PATIENCE_SECONDS


func _get_spawn_interval_seconds() -> float:
	if _economy_config != null and _economy_config.diner_spawn_interval_seconds > 0.0:
		return _economy_config.diner_spawn_interval_seconds
	return DEFAULT_SPAWN_INTERVAL_SECONDS


func _get_eat_seconds() -> float:
	if _economy_config != null and _economy_config.diner_eat_seconds > 0.0:
		return _economy_config.diner_eat_seconds
	return DEFAULT_EAT_SECONDS


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
	if changed.get("online", false):
		online_offer_changed.emit()


func _tick_service_spawns_and_timers(now: float) -> Dictionary:
	var changed: Dictionary = {
		"orders": false,
		"queues": false,
		"tables": false,
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

	if _process_order_expiries(now):
		changed["orders"] = true
		changed["queues"] = true
		changed["tables"] = true

	if _admit_outside_waiters(now):
		changed["orders"] = true
		changed["queues"] = true
		changed["tables"] = true

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


func _process_order_expiries(now: float) -> bool:
	var any_changed := false
	for order_id in _get_sorted_order_ids():
		var order: Dictionary = _orders[order_id]
		if order.get("kind", -1) != SharedTypes.OrderKind.DINE_IN:
			continue
		if order.get("status", -1) != SharedTypes.OrderStatus.OPEN:
			continue
		if float(order.get("deadline_at", 0.0)) > now:
			continue
		_expire_dine_in_order(order_id)
		any_changed = true
	return any_changed


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
