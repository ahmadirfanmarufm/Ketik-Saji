class_name KitchenController
extends Node
## Sole authority for player tile state, selected clickable target, typed
## command prefix, world-click routing, held aggregate, work-table staging,
## physical storage slots, finite plate registry, washer queue, and deliveries.
##
## Movement is an internal spatial/visual helper only; WorldMap/WorldGrid are
## queried as passive spatial data.

signal player_tile_changed(tile: Vector2i)
signal selected_interactable_changed(target_id: StringName)
signal command_prefix_changed(prefix: String)
signal action_feedback(code: StringName)
signal kitchen_state_changed()

const DEFAULT_START_TILE: Vector2i = Vector2i(6, 4)
const BOX_SLOT_COUNT: int = 3
const BOX_SLOT_CAPACITY: int = 5
const FRIDGE_SLOT_COUNT: int = 2
const FRIDGE_SLOT_CAPACITY: int = 3

var _world_map: WorldMap = null
var _game_root: Node = null

var _player_tile: Vector2i = DEFAULT_START_TILE
var _selected_target_id: StringName = &""
var _accepted_prefix: String = ""

var _held_item: Dictionary = {}
var _work_table_items: Dictionary[StringName, Dictionary] = {}
var _storage_units: Dictionary[StringName, Dictionary] = {}
var _plate_records: Dictionary[StringName, Dictionary] = {}
var _washer_dirty_plates: Array[StringName] = []
var _pending_deliveries: Dictionary[StringName, Dictionary] = {}
var _delivered_purchase_ids: Dictionary[StringName, bool] = {}


## Binds the passive WorldMap and optional GameRoot reference.
func bind_world(world_map: WorldMap, game_root: Node = null) -> void:
	_world_map = world_map
	_game_root = game_root
	if _world_map == null or _world_map.grid == null:
		return

	if _world_map.player != null:
		var initial_cell := _world_map.global_to_cell(_world_map.player.global_position)
		if _world_map.grid.is_free(initial_cell):
			_player_tile = initial_cell
	_sync_player_visual()


## Registers a physical storage unit (BOX = 3x5 slots, FRIDGE = 2x3 slots) once by ID.
func register_storage_unit(storage_unit_id: StringName, kind: SharedTypes.FixtureKind) -> bool:
	if storage_unit_id == &"" or _storage_units.has(storage_unit_id):
		return false

	var slot_count := 0
	var slot_capacity := 0
	if kind == SharedTypes.FixtureKind.BOX:
		slot_count = BOX_SLOT_COUNT
		slot_capacity = BOX_SLOT_CAPACITY
	elif kind == SharedTypes.FixtureKind.FRIDGE:
		slot_count = FRIDGE_SLOT_COUNT
		slot_capacity = FRIDGE_SLOT_CAPACITY
	else:
		return false

	var slots: Array[Dictionary] = []
	for _i in range(slot_count):
		slots.append({
			"ingredient_id": &"",
			"quantity": 0,
			"capacity": slot_capacity,
		})

	_storage_units[storage_unit_id] = {
		"storage_unit_id": storage_unit_id,
		"kind": kind,
		"slots": slots,
		"reservations": {},
	}
	return true


## Registers finite reusable plate records for a rack once by rack ID.
func register_plate_rack(rack_id: StringName, plates_count: int) -> bool:
	if rack_id == &"" or plates_count <= 0:
		return false

	for record: Dictionary in _plate_records.values():
		if record.get("source_rack_id", &"") == rack_id:
			return false

	for i in range(plates_count):
		var plate_id := StringName("%s_plate_%02d" % [rack_id, i + 1])
		_plate_records[plate_id] = {
			"plate_id": plate_id,
			"source_rack_id": rack_id,
			"location": &"RACK",
		}
	return true


## Registers a work-table surface slot once by ID.
func register_work_table(work_table_id: StringName) -> bool:
	if work_table_id == &"" or _work_table_items.has(work_table_id):
		return false
	_work_table_items[work_table_id] = {}
	return true


func get_player_tile() -> Vector2i:
	return _player_tile


func get_selected_target_id() -> StringName:
	return _selected_target_id


func get_plate_count() -> int:
	return _plate_records.size()


func has_storage_unit(storage_unit_id: StringName) -> bool:
	return _storage_units.has(storage_unit_id)


## Validates `tile` and teleports player without selecting any station.
func on_floor_clicked(tile: Vector2i) -> bool:
	if not _is_world_input_allowed():
		return false
	if _world_map == null or _world_map.grid == null:
		return false
	if not _world_map.grid.is_free(tile):
		action_feedback.emit(&"tile_blocked")
		return false

	clear_command_prefix()
	_set_selected_target(&"")
	_teleport_player_to(tile)
	return true


## Teleports to nearest free cardinal neighbor of `target_id`'s full footprint
## and selects/activates `target_id` in the same click.
func on_interactable_clicked(target_id: StringName) -> bool:
	if not _is_world_input_allowed():
		return false
	if target_id == &"" or _world_map == null or _world_map.registry == null:
		return false
	if not _world_map.registry.has_object(target_id):
		action_feedback.emit(&"unknown_target")
		return false

	var free_neighbors := _world_map.get_free_cardinal_neighbors(target_id)
	if free_neighbors.is_empty():
		action_feedback.emit(&"unreachable_target")
		return false

	var dest_tile := _player_tile
	if not free_neighbors.has(_player_tile):
		dest_tile = _world_map.find_nearest_free_neighbor(target_id, _player_tile)
		if dest_tile == WorldMap.INVALID_CELL:
			action_feedback.emit(&"unreachable_target")
			return false

	clear_command_prefix()
	_teleport_player_to(dest_tile)
	_set_selected_target(target_id)
	return true


func accept_typed_character(character: String) -> bool:
	if not _is_serving_phase():
		return false
	if character.length() != 1 or _selected_target_id == &"":
		return false
	var allowed := get_allowed_commands_for_selected_target()
	if allowed.is_empty():
		action_feedback.emit(&"invalid_key")
		return false

	var candidate := (_accepted_prefix + character.to_lower())
	for cmd in allowed:
		if cmd.begins_with(candidate):
			_accepted_prefix = candidate
			command_prefix_changed.emit(_accepted_prefix)
			if cmd == _accepted_prefix:
				clear_command_prefix()
			return true

	action_feedback.emit(&"invalid_key")
	return false


func clear_command_prefix() -> void:
	if _accepted_prefix.is_empty():
		return
	_accepted_prefix = ""
	command_prefix_changed.emit(_accepted_prefix)


func get_command_prefix() -> String:
	return _accepted_prefix


func get_allowed_commands_for_selected_target() -> Array[String]:
	var result: Array[String] = []
	match _selected_target_id:
		&"storage_box", &"fridge":
			result.assign(["ayam", "beras", "sapi", "sayur", "telur", "tempe"])
		&"stove":
			result.assign(["goreng"])
		&"washer":
			result.assign(["cuci"])
		&"rice_cooker":
			result.assign(["masak", "nasi"])
		&"work_table_chop":
			result.assign(["potong"])
		&"dining_table_01", &"dining_table_02":
			result.assign(["saji", "bersihkan"])
		&"online_station":
			result.assign(["terima"])
	return result


func get_held_item_view() -> Dictionary:
	return _held_item.duplicate(true)


func get_storage_unit_view(storage_unit_id: StringName) -> Dictionary:
	if not _storage_units.has(storage_unit_id):
		return {}
	return _storage_units[storage_unit_id].duplicate(true)


func get_pending_delivery_views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _pending_deliveries.values():
		if record.get("status", &"") == &"PENDING":
			result.append(record.duplicate(true))
	return result


func can_receive_stock(
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if ingredient_id == &"" or quantity <= 0 or not _storage_units.has(storage_unit_id):
		return false
	return _compute_available_capacity(storage_unit_id, ingredient_id) >= quantity


func reserve_incoming_capacity(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if (
		purchase_id == &""
		or _delivered_purchase_ids.has(purchase_id)
		or _pending_deliveries.has(purchase_id)
		or _has_reservation_id(purchase_id)
	):
		return false
	if not can_receive_stock(ingredient_id, quantity, storage_unit_id):
		return false

	var unit: Dictionary = _storage_units[storage_unit_id]
	var reservations: Dictionary = unit["reservations"]
	reservations[purchase_id] = {
		"ingredient_id": ingredient_id,
		"quantity": quantity,
	}
	return true


## Releases an uncommitted capacity reservation when a synchronous purchase step fails.
func release_reserved_capacity(
	purchase_id: StringName,
	storage_unit_id: StringName
) -> bool:
	if purchase_id == &"" or not _storage_units.has(storage_unit_id):
		return false
	if _pending_deliveries.has(purchase_id):
		var status: StringName = _pending_deliveries[purchase_id].get("status", &"")
		if status == &"PENDING" or status == &"DELIVERED":
			return false
	var reservations: Dictionary = _storage_units[storage_unit_id]["reservations"]
	return reservations.erase(purchase_id)


func receive_stock(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if purchase_id == &"" or ingredient_id == &"" or quantity <= 0:
		return false
	if _delivered_purchase_ids.has(purchase_id):
		return false
	if _pending_deliveries.has(purchase_id):
		if _pending_deliveries[purchase_id].get("status", &"") != &"PENDING":
			return false
	if not _storage_units.has(storage_unit_id):
		return false

	var unit: Dictionary = _storage_units[storage_unit_id]
	var reservations: Dictionary = unit["reservations"]
	var had_reservation := reservations.has(purchase_id)
	if had_reservation:
		var res: Dictionary = reservations[purchase_id]
		if (
			res.get("ingredient_id", &"") != ingredient_id
			or int(res.get("quantity", 0)) != quantity
		):
			return false
	elif not can_receive_stock(ingredient_id, quantity, storage_unit_id):
		return false

	if not _deposit_into_slots(unit["slots"], ingredient_id, quantity):
		return false

	if had_reservation:
		reservations.erase(purchase_id)
	_delivered_purchase_ids[purchase_id] = true
	if _pending_deliveries.has(purchase_id):
		_pending_deliveries[purchase_id]["status"] = &"DELIVERED"
	kitchen_state_changed.emit()
	return true


func schedule_delivery(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName,
	due_at: float
) -> bool:
	if (
		purchase_id == &""
		or ingredient_id == &""
		or quantity <= 0
		or _delivered_purchase_ids.has(purchase_id)
		or _pending_deliveries.has(purchase_id)
		or due_at < 0.0
	):
		return false
	if not _storage_units.has(storage_unit_id):
		return false

	var reservations: Dictionary = _storage_units[storage_unit_id]["reservations"]
	if reservations.has(purchase_id):
		var res: Dictionary = reservations[purchase_id]
		if (
			res.get("ingredient_id", &"") != ingredient_id
			or int(res.get("quantity", 0)) != quantity
		):
			return false
	else:
		if not reserve_incoming_capacity(purchase_id, ingredient_id, quantity, storage_unit_id):
			return false

	_pending_deliveries[purchase_id] = {
		"purchase_id": purchase_id,
		"ingredient_id": ingredient_id,
		"quantity": quantity,
		"storage_unit_id": storage_unit_id,
		"due_at": due_at,
		"status": &"PENDING",
	}
	kitchen_state_changed.emit()
	return true


func cancel_pending_deliveries(_day_index: int) -> Array[StringName]:
	var canceled: Array[StringName] = []
	for purchase_id: StringName in _pending_deliveries:
		var record: Dictionary = _pending_deliveries[purchase_id]
		if record.get("status", &"") != &"PENDING":
			continue
		record["status"] = &"CANCELED"
		var unit_id: StringName = record.get("storage_unit_id", &"")
		if _storage_units.has(unit_id):
			var reservations: Dictionary = _storage_units[unit_id]["reservations"]
			reservations.erase(purchase_id)
		canceled.append(purchase_id)

	if not canceled.is_empty():
		kitchen_state_changed.emit()
	return canceled


func clear_non_fridge_food_for_next_day() -> void:
	_held_item.clear()
	for table_id: StringName in _work_table_items:
		_work_table_items[table_id] = {}

	for unit: Dictionary in _storage_units.values():
		unit["reservations"] = {}
		if unit.get("kind", -1) == SharedTypes.FixtureKind.BOX:
			for slot: Dictionary in unit["slots"]:
				slot["ingredient_id"] = &""
				slot["quantity"] = 0

	_washer_dirty_plates.clear()
	for plate: Dictionary in _plate_records.values():
		plate["location"] = &"RACK"

	clear_command_prefix()
	_set_selected_target(&"")
	kitchen_state_changed.emit()


func advance_service_time(now: float) -> void:
	var changed := false
	for purchase_id: StringName in _pending_deliveries:
		var record: Dictionary = _pending_deliveries[purchase_id]
		if record.get("status", &"") != &"PENDING":
			continue
		var due_at: float = float(record.get("due_at", 0.0))
		if due_at <= now:
			var unit_id: StringName = record.get("storage_unit_id", &"")
			var ing_id: StringName = record.get("ingredient_id", &"")
			var qty: int = int(record.get("quantity", 0))
			if receive_stock(purchase_id, ing_id, qty, unit_id):
				record["status"] = &"DELIVERED"
				changed = true
	if changed:
		kitchen_state_changed.emit()


func try_consume_serving_item(
	item_id: StringName,
	recipe_id: StringName,
	_order_kind: int,
	_dine_in_table_id: StringName
) -> bool:
	if item_id == &"" or recipe_id == &"" or _held_item.is_empty():
		return false
	if _held_item.get("item_id", &"") != item_id:
		return false
	if _held_item.get("matched_recipe_id", &"") != recipe_id:
		return false
	return false


func move_cleaned_table_plate_to_washer(table_id: StringName) -> bool:
	if table_id == &"":
		return false
	for plate: Dictionary in _plate_records.values():
		if (
			plate.get("location", &"") == &"CUSTOMER_TABLE"
			and plate.get("table_id", &"") == table_id
		):
			plate["location"] = &"WASHER_DIRTY"
			plate["table_id"] = &""
			_washer_dirty_plates.append(plate["plate_id"])
			kitchen_state_changed.emit()
			return true
	return false


func _is_world_input_allowed() -> bool:
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	var phase: int = _game_root.get_phase()
	return (
		phase == SharedTypes.Phase.PLANNING
		or phase == SharedTypes.Phase.SERVING
	)


func _is_serving_phase() -> bool:
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"get_phase")
	):
		return false
	return _game_root.get_phase() == SharedTypes.Phase.SERVING


func _has_reservation_id(purchase_id: StringName) -> bool:
	for unit: Dictionary in _storage_units.values():
		var reservations: Dictionary = unit["reservations"]
		if reservations.has(purchase_id):
			return true
	return false


func _teleport_player_to(tile: Vector2i) -> void:
	var changed := _player_tile != tile
	_player_tile = tile
	_sync_player_visual()
	if changed:
		player_tile_changed.emit(_player_tile)


func _sync_player_visual() -> void:
	if _world_map != null and _world_map.player != null and _world_map.grid != null:
		_world_map.player.global_position = _world_map.cell_to_global(_player_tile)


func _set_selected_target(target_id: StringName) -> void:
	if _selected_target_id == target_id:
		return
	_selected_target_id = target_id
	selected_interactable_changed.emit(_selected_target_id)


func _compute_available_capacity(storage_unit_id: StringName, ingredient_id: StringName) -> int:
	var unit: Dictionary = _storage_units[storage_unit_id]
	var sim_slots: Array[Dictionary] = []
	for slot: Dictionary in unit["slots"]:
		sim_slots.append(slot.duplicate())

	var reservations: Dictionary = unit["reservations"]
	for res: Dictionary in reservations.values():
		var r_ing: StringName = res.get("ingredient_id", &"")
		var r_qty: int = int(res.get("quantity", 0))
		if not _deposit_into_slots(sim_slots, r_ing, r_qty):
			return 0

	var free_for_ingredient := 0
	for slot: Dictionary in sim_slots:
		var slot_ing: StringName = slot.get("ingredient_id", &"")
		var qty: int = int(slot.get("quantity", 0))
		var cap: int = int(slot.get("capacity", 0))
		if slot_ing == &"" or slot_ing == ingredient_id:
			free_for_ingredient += maxi(0, cap - qty)
	return free_for_ingredient


func _deposit_into_slots(
	slots: Array,
	ingredient_id: StringName,
	quantity: int
) -> bool:
	var remaining := quantity
	for slot: Dictionary in slots:
		if remaining <= 0:
			break
		if slot.get("ingredient_id", &"") == ingredient_id:
			var space := int(slot["capacity"]) - int(slot["quantity"])
			var add := mini(remaining, maxi(0, space))
			slot["quantity"] = int(slot["quantity"]) + add
			remaining -= add

	for slot: Dictionary in slots:
		if remaining <= 0:
			break
		if slot.get("ingredient_id", &"") == &"" or int(slot.get("quantity", 0)) == 0:
			var space := int(slot["capacity"])
			var add := mini(remaining, maxi(0, space))
			if add > 0:
				slot["ingredient_id"] = ingredient_id
				slot["quantity"] = add
				remaining -= add

	return remaining == 0
