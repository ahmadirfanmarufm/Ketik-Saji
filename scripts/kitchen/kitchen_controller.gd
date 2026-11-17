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
signal command_executed(command: StringName, target_id: StringName)
signal action_feedback(code: StringName)
signal kitchen_state_changed()

const DEFAULT_START_TILE: Vector2i = Vector2i(6, 4)
const BOX_SLOT_COUNT: int = 3
const BOX_SLOT_CAPACITY: int = 5
const FRIDGE_SLOT_COUNT: int = 2
const FRIDGE_SLOT_CAPACITY: int = 3
const INGREDIENT_DIR: String = "res://data/ingredients"
const RECIPE_DIR: String = "res://data/recipes"
const DEFAULT_INGREDIENT_IDS: Array[StringName] = [
	&"ayam",
	&"beras",
	&"sapi",
	&"sayur",
	&"telur",
	&"tempe",
]
const DEFAULT_RECIPE_IDS: Array[StringName] = [
	&"nasi_telor",
	&"nasi_ayam",
	&"nasi_komplit",
]

var _world_map: WorldMap = null
var _game_root: Node = null
var _service_controller: Node = null

var _player_tile: Vector2i = DEFAULT_START_TILE
var _selected_target_id: StringName = &""
var _accepted_prefix: String = ""
var _last_executed_command: String = ""
var _executed_command_count: int = 0

var _ingredients_by_id: Dictionary[StringName, IngredientDef] = {}
var _recipes_by_id: Dictionary[StringName, RecipeDef] = {}
var _catalogs_loaded: bool = false
var _next_item_seq: int = 0

var _held_item: Dictionary = {}
var _work_table_items: Dictionary[StringName, Dictionary] = {}
var _cooker_outputs: Dictionary[StringName, Dictionary] = {}
var _storage_units: Dictionary[StringName, Dictionary] = {}
var _plate_records: Dictionary[StringName, Dictionary] = {}
var _washer_dirty_plates: Array[StringName] = []
var _pending_deliveries: Dictionary[StringName, Dictionary] = {}
var _delivered_purchase_ids: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_ensure_catalogs_loaded()


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


## Binds ServiceController for dining-table command dispatch.
func bind_service(service_controller: Node) -> void:
	_service_controller = service_controller


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
	if _is_serving_phase():
		_perform_click_action(target_id)
	return true


func accept_typed_character(character: String) -> bool:
	if not _is_serving_phase():
		return false
	var normalized_char := character.strip_edges().to_lower()
	if normalized_char.length() != 1 or _selected_target_id == &"":
		return false
	var allowed := get_allowed_commands_for_selected_target()
	if allowed.is_empty():
		action_feedback.emit(&"invalid_key")
		return false

	var candidate := _accepted_prefix.to_lower() + normalized_char
	var matched_any := false
	var exact_match := ""
	for cmd in allowed:
		var norm_cmd := cmd.strip_edges().to_lower()
		if norm_cmd.begins_with(candidate):
			matched_any = true
			if norm_cmd == candidate and exact_match.is_empty():
				exact_match = norm_cmd

	if not matched_any:
		action_feedback.emit(&"invalid_key")
		return false

	_accepted_prefix = candidate
	command_prefix_changed.emit(_accepted_prefix)
	if not exact_match.is_empty():
		clear_command_prefix()
		_execute_typed_command(exact_match)
	return true


func backspace_command_prefix() -> bool:
	if _accepted_prefix.is_empty():
		return false
	_accepted_prefix = _accepted_prefix.left(_accepted_prefix.length() - 1)
	command_prefix_changed.emit(_accepted_prefix)
	return true


func clear_command_prefix() -> void:
	if _accepted_prefix.is_empty():
		return
	_accepted_prefix = ""
	command_prefix_changed.emit(_accepted_prefix)


func get_command_prefix() -> String:
	return _accepted_prefix


func get_last_executed_command() -> String:
	return _last_executed_command


func get_executed_command_count() -> int:
	return _executed_command_count


func get_allowed_commands_for_selected_target() -> Array[String]:
	var result: Array[String] = []
	if _storage_units.has(_selected_target_id):
		result.assign(["ayam", "beras", "sapi", "sayur", "telur", "tempe"])
		return result
	if _is_dining_table_target(_selected_target_id):
		result.assign(["saji", "bersihkan"])
		return result

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
		&"online_station":
			result.assign(["terima"])
	return result


func get_held_item_view() -> Dictionary:
	return _held_item.duplicate(true)


func get_work_table_view(work_table_id: StringName = &"work_table") -> Dictionary:
	if not _work_table_items.has(work_table_id):
		return {}
	return _work_table_items[work_table_id].duplicate(true)


func get_cooker_output_view(cooker_id: StringName = &"rice_cooker") -> Dictionary:
	if not _cooker_outputs.has(cooker_id):
		return {}
	return _cooker_outputs[cooker_id].duplicate(true)


func get_plate_rack_view(rack_id: StringName = &"plate_rack") -> Dictionary:
	var clean_count := 0
	var total_count := 0
	for record: Dictionary in _plate_records.values():
		if record.get("source_rack_id", &"") != rack_id:
			continue
		total_count += 1
		if record.get("location", &"") == &"RACK":
			clean_count += 1
	return {
		"rack_id": rack_id,
		"clean_count": clean_count,
		"total_count": total_count,
	}


func get_washer_view() -> Dictionary:
	return {
		"dirty_plate_count": _washer_dirty_plates.size(),
	}


func get_ingredient_def(ingredient_id: StringName) -> IngredientDef:
	_ensure_catalogs_loaded()
	return _ingredients_by_id.get(ingredient_id, null) as IngredientDef


func get_recipe_def(recipe_id: StringName) -> RecipeDef:
	_ensure_catalogs_loaded()
	return _recipes_by_id.get(recipe_id, null) as RecipeDef


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
	for cooker_id: StringName in _cooker_outputs:
		_cooker_outputs[cooker_id] = {}

	for unit: Dictionary in _storage_units.values():
		unit["reservations"] = {}
		if unit.get("kind", -1) == SharedTypes.FixtureKind.BOX:
			for slot: Dictionary in unit["slots"]:
				slot["ingredient_id"] = &""
				slot["quantity"] = 0

	_washer_dirty_plates.clear()
	for plate: Dictionary in _plate_records.values():
		plate["location"] = &"RACK"
		plate["table_id"] = &""

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
	order_kind: int,
	dine_in_table_id: StringName
) -> bool:
	if item_id == &"" or recipe_id == &"" or _held_item.is_empty():
		return false
	if _held_item.get("item_id", &"") != item_id:
		return false
	if _held_item.get("matched_recipe_id", &"") != recipe_id:
		return false
	var plate_id: StringName = _held_item.get("plate_id", &"")
	if plate_id == &"" or not _plate_records.has(plate_id):
		return false

	var plate: Dictionary = _plate_records[plate_id]
	if order_kind == SharedTypes.OrderKind.DINE_IN:
		if dine_in_table_id == &"":
			return false
		plate["location"] = &"CUSTOMER_TABLE"
		plate["table_id"] = dine_in_table_id
	elif order_kind == SharedTypes.OrderKind.ONLINE:
		plate["location"] = &"RACK"
		plate["table_id"] = &""
	else:
		return false

	_held_item = {}
	_sync_player_visual()
	kitchen_state_changed.emit()
	return true


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
	clear_command_prefix()
	_selected_target_id = target_id
	selected_interactable_changed.emit(_selected_target_id)


func _execute_typed_command(command: String) -> void:
	_last_executed_command = command
	_executed_command_count += 1
	command_executed.emit(StringName(command), _selected_target_id)
	_perform_typed_command(StringName(command))


func _perform_click_action(target_id: StringName) -> void:
	match target_id:
		&"plate_rack":
			_handle_plate_rack_click(target_id)
		&"work_table_stage":
			_handle_work_table_stage_click(&"work_table")
		&"trash":
			_handle_trash_click()


func _perform_typed_command(command: StringName) -> void:
	_ensure_catalogs_loaded()
	if _storage_units.has(_selected_target_id):
		_try_take_raw_ingredient(_selected_target_id, command)
		return

	match _selected_target_id:
		&"washer":
			if command == &"cuci":
				_try_washer_cuci()
		&"stove":
			if command == &"goreng":
				_try_process_held_ingredient(&"goreng", &"item_cooked")
		&"rice_cooker":
			if command == &"masak":
				_try_rice_cooker_masak(&"rice_cooker")
			elif command == &"nasi":
				_try_rice_cooker_nasi(&"rice_cooker")
		&"work_table_chop":
			if command == &"potong":
				_try_process_held_ingredient(&"potong", &"item_chopped")
		&"online_station":
			action_feedback.emit(&"invalid_action")
		_:
			if _is_dining_table_target(_selected_target_id):
				if command == &"saji":
					_try_serve_dining_table(_selected_target_id)
				elif command == &"bersihkan":
					_try_clean_dining_table(_selected_target_id)
				else:
					action_feedback.emit(&"invalid_action")


func _is_dining_table_target(target_id: StringName) -> bool:
	if (
		_service_controller != null
		and is_instance_valid(_service_controller)
		and _service_controller.has_method(&"has_table")
		and _service_controller.has_table(target_id)
	):
		return true
	return target_id == &"dining_table_01" or target_id == &"dining_table_02"


func _try_serve_dining_table(table_id: StringName) -> bool:
	if _service_controller == null or not is_instance_valid(_service_controller):
		action_feedback.emit(&"invalid_action")
		return false

	var before_table: Dictionary = _service_controller.get_table_view(table_id)
	var before_state: int = int(before_table.get("state", -1))
	var before_order_id: StringName = before_table.get("order_id_or_empty", &"")
	var expected_recipe_id: StringName = &""
	if before_order_id != &"":
		var before_order: Dictionary = _service_controller.get_order_view(before_order_id)
		expected_recipe_id = before_order.get("recipe_id", &"")

	var held_item_id: StringName = _held_item.get("item_id", &"")
	if _service_controller.try_serve_table(table_id, held_item_id):
		action_feedback.emit(&"order_served")
		return true

	if before_state != SharedTypes.TableState.OCCUPIED_WAITING or before_order_id == &"":
		action_feedback.emit(&"invalid_action")
		return false

	var after_table: Dictionary = _service_controller.get_table_view(table_id)
	var after_order: Dictionary = _service_controller.get_order_view(before_order_id)
	if (
		int(after_order.get("status", -1)) != SharedTypes.OrderStatus.OPEN
		or after_table.get("order_id_or_empty", &"") != before_order_id
	):
		action_feedback.emit(&"order_expired")
		return false

	if _held_item.is_empty():
		action_feedback.emit(&"invalid_action")
		return false

	var held_plate_id: StringName = _held_item.get("plate_id", &"")
	var held_recipe_id: StringName = _held_item.get("matched_recipe_id", &"")
	if held_plate_id == &"" or held_recipe_id != expected_recipe_id:
		action_feedback.emit(&"wrong_order")
	else:
		action_feedback.emit(&"invalid_action")
	return false


func _try_clean_dining_table(table_id: StringName) -> bool:
	if _service_controller == null or not is_instance_valid(_service_controller):
		action_feedback.emit(&"invalid_action")
		return false
	if _service_controller.try_clean_table(table_id):
		action_feedback.emit(&"table_cleaned")
		return true
	action_feedback.emit(&"invalid_action")
	return false


func _try_take_raw_ingredient(storage_unit_id: StringName, ingredient_id: StringName) -> bool:
	if not _held_item.is_empty():
		action_feedback.emit(&"hand_full")
		return false
	if not _storage_units.has(storage_unit_id) or not _ingredients_by_id.has(ingredient_id):
		action_feedback.emit(&"invalid_action")
		return false

	var unit: Dictionary = _storage_units[storage_unit_id]
	var slots: Array = unit["slots"]
	for slot: Dictionary in slots:
		if (
			slot.get("ingredient_id", &"") == ingredient_id
			and int(slot.get("quantity", 0)) > 0
		):
			var next_qty := int(slot["quantity"]) - 1
			slot["quantity"] = next_qty
			if next_qty == 0:
				slot["ingredient_id"] = &""
			_held_item = _create_loose_item(ingredient_id, SharedTypes.PrepState.RAW, &"HELD")
			action_feedback.emit(&"item_taken")
			kitchen_state_changed.emit()
			return true

	action_feedback.emit(&"out_of_stock")
	return false


func _try_washer_cuci() -> bool:
	if _held_item.is_empty():
		while not _washer_dirty_plates.is_empty():
			var plate_id: StringName = _washer_dirty_plates[0]
			_washer_dirty_plates.remove_at(0)
			if not _plate_records.has(plate_id):
				continue
			var record: Dictionary = _plate_records[plate_id]
			if record.get("location", &"") != &"WASHER_DIRTY":
				continue
			record["location"] = &"HELD"
			_held_item = _create_plated_item(plate_id, [], &"HELD")
			action_feedback.emit(&"plate_washed")
			kitchen_state_changed.emit()
			return true
		action_feedback.emit(&"invalid_action")
		return false

	if _is_single_loose_held_item():
		return _try_process_held_ingredient(&"cuci", &"item_washed")

	action_feedback.emit(&"invalid_action")
	return false


func _try_process_held_ingredient(command: StringName, success_feedback: StringName) -> bool:
	if not _is_single_loose_held_item():
		action_feedback.emit(&"invalid_action")
		return false

	var parts: Array = _held_item["parts"]
	var part: Dictionary = parts[0]
	var ingredient_id: StringName = part.get("ingredient_id", &"")
	var current_state: SharedTypes.PrepState = int(part.get("state", 0)) as SharedTypes.PrepState
	var def := _ingredients_by_id.get(ingredient_id) as IngredientDef
	if def == null:
		action_feedback.emit(&"invalid_action")
		return false

	var next_state := def.get_next_state(current_state, command)
	if next_state < 0:
		action_feedback.emit(&"invalid_action")
		return false

	part["state"] = next_state
	action_feedback.emit(success_feedback)
	kitchen_state_changed.emit()
	return true


func _try_rice_cooker_masak(cooker_id: StringName) -> bool:
	if not _is_single_loose_held_item():
		action_feedback.emit(&"invalid_action")
		return false

	var parts: Array = _held_item["parts"]
	var part: Dictionary = parts[0]
	var ingredient_id: StringName = part.get("ingredient_id", &"")
	var current_state: SharedTypes.PrepState = int(part.get("state", 0)) as SharedTypes.PrepState
	var def := _ingredients_by_id.get(ingredient_id) as IngredientDef
	if def == null:
		action_feedback.emit(&"invalid_action")
		return false

	var next_state := def.get_next_state(current_state, &"masak")
	if next_state < 0:
		action_feedback.emit(&"invalid_action")
		return false

	var existing: Dictionary = _cooker_outputs.get(cooker_id, {})
	if not existing.is_empty():
		action_feedback.emit(&"cooker_full")
		return false

	part["state"] = next_state
	_held_item["location"] = &"COOKER_OUTPUT"
	_cooker_outputs[cooker_id] = _held_item
	_held_item = {}
	action_feedback.emit(&"rice_cooked")
	kitchen_state_changed.emit()
	return true


func _try_rice_cooker_nasi(cooker_id: StringName) -> bool:
	if not _held_item.is_empty():
		action_feedback.emit(&"hand_full")
		return false

	var cooked_item: Dictionary = _cooker_outputs.get(cooker_id, {})
	if cooked_item.is_empty():
		action_feedback.emit(&"cooker_empty")
		return false

	cooked_item["location"] = &"HELD"
	_held_item = cooked_item
	_cooker_outputs[cooker_id] = {}
	action_feedback.emit(&"rice_taken")
	kitchen_state_changed.emit()
	return true


func _handle_plate_rack_click(rack_id: StringName) -> bool:
	if _held_item.is_empty():
		var sorted_ids := _get_sorted_plate_ids()
		for plate_id in sorted_ids:
			var record: Dictionary = _plate_records[plate_id]
			if (
				record.get("source_rack_id", &"") == rack_id
				and record.get("location", &"") == &"RACK"
			):
				record["location"] = &"HELD"
				_held_item = _create_plated_item(plate_id, [], &"HELD")
				action_feedback.emit(&"plate_taken")
				kitchen_state_changed.emit()
				return true
		action_feedback.emit(&"no_plates")
		return false

	if _is_empty_held_plate():
		var held_plate_id: StringName = _held_item.get("plate_id", &"")
		if _plate_records.has(held_plate_id):
			_plate_records[held_plate_id]["location"] = &"RACK"
		_held_item.clear()
		action_feedback.emit(&"plate_returned")
		kitchen_state_changed.emit()
		return true

	action_feedback.emit(&"hand_full")
	return false


func _handle_work_table_stage_click(work_table_id: StringName) -> bool:
	if not _work_table_items.has(work_table_id):
		return false

	var staged: Dictionary = _work_table_items[work_table_id]
	if staged.is_empty() and _held_item.is_empty():
		return false

	if staged.is_empty():
		var moved: Dictionary = _held_item
		moved["location"] = &"WORK_TABLE"
		moved["work_table_id"] = work_table_id
		var moved_plate_id: StringName = moved.get("plate_id", &"")
		if moved_plate_id != &"" and _plate_records.has(moved_plate_id):
			_plate_records[moved_plate_id]["location"] = &"WORK_TABLE"
		_work_table_items[work_table_id] = moved
		_held_item = {}
		action_feedback.emit(&"item_staged")
		kitchen_state_changed.emit()
		return true

	if _held_item.is_empty():
		staged["location"] = &"HELD"
		staged["work_table_id"] = &""
		var staged_plate_id: StringName = staged.get("plate_id", &"")
		if staged_plate_id != &"" and _plate_records.has(staged_plate_id):
			_plate_records[staged_plate_id]["location"] = &"HELD"
		_held_item = staged
		_work_table_items[work_table_id] = {}
		action_feedback.emit(&"item_picked_up")
		kitchen_state_changed.emit()
		return true

	# Both staged and held are occupied: only merge a single loose prepared item
	# into a staged plated aggregate when compatible with at least one RecipeDef.
	if staged.get("plate_id", &"") == &"" or not _is_single_loose_held_item():
		action_feedback.emit(&"invalid_merge")
		return false

	var next_parts: Array = (staged.get("parts", []) as Array).duplicate(true)
	next_parts.append((_held_item["parts"][0] as Dictionary).duplicate(true))
	if not _can_extend_any_recipe(next_parts):
		action_feedback.emit(&"invalid_merge")
		return false

	staged["parts"] = next_parts
	var matched_id := _match_recipe_id(next_parts)
	staged["matched_recipe_id"] = matched_id
	_held_item.clear()
	action_feedback.emit(&"dish_ready" if matched_id != &"" else &"item_merged")
	kitchen_state_changed.emit()
	return true


func _handle_trash_click() -> bool:
	if _held_item.is_empty():
		return false

	var plate_id: StringName = _held_item.get("plate_id", &"")
	if plate_id == &"":
		_held_item.clear()
		action_feedback.emit(&"item_trashed")
		kitchen_state_changed.emit()
		return true

	var parts: Array = _held_item.get("parts", [])
	if parts.is_empty():
		action_feedback.emit(&"invalid_action")
		return false

	_held_item["parts"] = []
	_held_item["matched_recipe_id"] = &""
	action_feedback.emit(&"item_trashed")
	kitchen_state_changed.emit()
	return true


func _is_single_loose_held_item() -> bool:
	if _held_item.is_empty():
		return false
	if _held_item.get("plate_id", &"") != &"":
		return false
	var parts: Array = _held_item.get("parts", [])
	return parts.size() == 1


func _is_empty_held_plate() -> bool:
	if _held_item.is_empty():
		return false
	if _held_item.get("plate_id", &"") == &"":
		return false
	var parts: Array = _held_item.get("parts", [])
	return parts.is_empty()


func _create_loose_item(
	ingredient_id: StringName,
	state: SharedTypes.PrepState,
	location: StringName
) -> Dictionary:
	return {
		"item_id": _allocate_item_id(),
		"plate_id": &"",
		"parts": [
			{
				"ingredient_id": ingredient_id,
				"state": int(state),
			},
		],
		"location": location,
		"work_table_id": &"",
		"matched_recipe_id": &"",
	}


func _create_plated_item(
	plate_id: StringName,
	parts: Array,
	location: StringName
) -> Dictionary:
	return {
		"item_id": _allocate_item_id(),
		"plate_id": plate_id,
		"parts": parts,
		"location": location,
		"work_table_id": &"",
		"matched_recipe_id": _match_recipe_id(parts),
	}


func _allocate_item_id() -> StringName:
	_next_item_seq += 1
	return StringName("item_%04d" % _next_item_seq)


func _get_sorted_plate_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_plate_records.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _can_extend_any_recipe(candidate_parts: Array) -> bool:
	_ensure_catalogs_loaded()
	if candidate_parts.is_empty():
		return true

	var candidate_counts := _build_parts_multiset(candidate_parts)
	for recipe: RecipeDef in _recipes_by_id.values():
		if recipe == null:
			continue
		var required_counts := _build_recipe_multiset(recipe)
		if _is_submultiset(candidate_counts, required_counts):
			return true
	return false


func _match_recipe_id(parts: Array) -> StringName:
	_ensure_catalogs_loaded()
	if parts.is_empty():
		return &""

	var part_counts := _build_parts_multiset(parts)
	var recipe_ids: Array[StringName] = []
	recipe_ids.assign(_recipes_by_id.keys())
	recipe_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool: return String(a) < String(b)
	)
	for recipe_id in recipe_ids:
		var recipe: RecipeDef = _recipes_by_id[recipe_id]
		if recipe == null or recipe.required_parts.size() != parts.size():
			continue
		if part_counts == _build_recipe_multiset(recipe):
			return recipe.recipe_id
	return &""


func _build_parts_multiset(parts: Array) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for raw_part: Variant in parts:
		if not (raw_part is Dictionary):
			continue
		var part: Dictionary = raw_part
		var key := "%s:%d" % [part.get("ingredient_id", &""), int(part.get("state", -1))]
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _build_recipe_multiset(recipe: RecipeDef) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for part in recipe.required_parts:
		if part == null:
			continue
		var key := "%s:%d" % [part.ingredient_id, int(part.required_state)]
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _is_submultiset(sub: Dictionary[String, int], sup: Dictionary[String, int]) -> bool:
	for key: String in sub:
		if int(sub[key]) > int(sup.get(key, 0)):
			return false
	return true


func _ensure_catalogs_loaded() -> void:
	if _catalogs_loaded:
		return
	_catalogs_loaded = true

	for path in _collect_tres_paths(INGREDIENT_DIR, DEFAULT_INGREDIENT_IDS):
		var ing := load(path) as IngredientDef
		if ing != null and ing.ingredient_id != &"":
			_ingredients_by_id[ing.ingredient_id] = ing

	for path in _collect_tres_paths(RECIPE_DIR, DEFAULT_RECIPE_IDS):
		var rec := load(path) as RecipeDef
		if rec != null and rec.recipe_id != &"":
			_recipes_by_id[rec.recipe_id] = rec


func _collect_tres_paths(dir_path: String, fallback_ids: Array[StringName]) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir != null:
		for file_name in dir.get_files():
			var clean_name := file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var full_path := dir_path.path_join(clean_name)
				if not paths.has(full_path):
					paths.append(full_path)

	for id in fallback_ids:
		var fallback_path := dir_path.path_join("%s.tres" % id)
		if not paths.has(fallback_path):
			paths.append(fallback_path)

	paths.sort()
	return paths


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
