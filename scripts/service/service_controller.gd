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

const PICKUP_SPOT_IDS: Array[StringName] = [
	&"pickup_spot_01",
	&"pickup_spot_02",
	&"pickup_spot_03",
]

var _day_prepared: bool = false
var _service_active: bool = false
var _day_index: int = 1
var _last_service_now: float = 0.0

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


func _ready() -> void:
	_reset_pickup_spots()


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

	var preview_id: StringName = &""
	if not _selected_recipe_ids.is_empty():
		preview_id = _selected_recipe_ids[0]
	_online_offer = {
		"preview_recipe_id": preview_id,
		"offer_generation_number": 1 if not _selected_recipe_ids.is_empty() else 0,
	}

	_day_prepared = true
	_service_active = false
	queues_changed.emit()
	tables_changed.emit()
	online_offer_changed.emit()


func begin_service(now: float) -> void:
	if not _day_prepared:
		return
	_last_service_now = maxf(0.0, now)
	_service_active = true
	queues_changed.emit()


func advance_service_time(now: float) -> void:
	if not _service_active:
		return
	_last_service_now = maxf(_last_service_now, now)


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


func try_serve_table(_table_id: StringName, _item_id: StringName) -> bool:
	return false


func try_serve_driver(_driver_id: StringName, _item_id: StringName) -> bool:
	return false


func try_clean_table(table_id: StringName) -> bool:
	if not _tables.has(table_id):
		return false
	var table: Dictionary = _tables[table_id]
	if table.get("state", -1) != SharedTypes.TableState.DIRTY:
		return false
	return false


func try_accept_online_offer() -> bool:
	if not get_online_acceptance_enabled():
		return false
	return false


func get_order_view(order_id: StringName) -> Dictionary:
	if not _orders.has(order_id):
		return {}
	return _orders[order_id].duplicate(true)


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
