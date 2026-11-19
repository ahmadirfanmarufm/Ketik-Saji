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
signal ingredient_shop_requested(storage_unit_id: StringName)

const DEFAULT_START_TILE: Vector2i = Vector2i(6, 3)
const BOX_SLOT_COUNT: int = 3
const BOX_SLOT_CAPACITY: int = 5
const FRIDGE_SLOT_COUNT: int = 2
const FRIDGE_SLOT_CAPACITY: int = 3
const COOKER_BATCH_PORTIONS: int = 5
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
var _run_controller: Node = null

var _player_tile: Vector2i = DEFAULT_START_TILE
var _selected_target_id: StringName = &""
var _selected_target_is_driver: bool = false
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
var _fixture_kinds: Dictionary[StringName, int] = {}
var _washer_dirty_plates: Array[StringName] = []
var _pending_deliveries: Dictionary[StringName, Dictionary] = {}
var _delivered_purchase_ids: Dictionary[StringName, bool] = {}
var _last_service_now: float = 0.0


func _ready() -> void:
	_ensure_catalogs_loaded()
	if not kitchen_state_changed.is_connected(_on_self_kitchen_state_changed):
		kitchen_state_changed.connect(_on_self_kitchen_state_changed)


func _exit_tree() -> void:
	_disconnect_game_root_signals()
	_disconnect_service_signals()
	if kitchen_state_changed.is_connected(_on_self_kitchen_state_changed):
		kitchen_state_changed.disconnect(_on_self_kitchen_state_changed)


## Binds the passive WorldMap and optional GameRoot reference.
func bind_world(world_map: WorldMap, game_root: Node = null) -> void:
	_disconnect_game_root_signals()
	_world_map = world_map
	_game_root = game_root
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_signal(&"phase_changed")
		and not _game_root.is_connected(&"phase_changed", _on_game_root_phase_changed)
	):
		_game_root.connect(&"phase_changed", _on_game_root_phase_changed)
	_run_controller = _get_run_controller()
	if (
		_run_controller != null
		and is_instance_valid(_run_controller)
		and _run_controller.has_signal(&"run_state_changed")
		and not _run_controller.is_connected(&"run_state_changed", _on_run_context_changed)
	):
		_run_controller.connect(&"run_state_changed", _on_run_context_changed)
	if _world_map == null or _world_map.grid == null:
		return

	if _world_map.player != null:
		var initial_cell := _world_map.global_to_cell(_world_map.player.global_position)
		if _world_map.grid.is_free(initial_cell):
			_player_tile = initial_cell
	_sync_player_visual(false)


## Binds ServiceController for dining-table and online-delivery command dispatch.
func bind_service(service_controller: Node) -> void:
	_disconnect_service_signals()
	_service_controller = service_controller
	if _service_controller != null and is_instance_valid(_service_controller):
		_connect_service_signal(&"drivers_changed", _on_service_drivers_changed)
		_connect_service_signal(&"tables_changed", _on_service_context_changed)
		_connect_service_signal(&"orders_changed", _on_service_context_changed)
		_connect_service_signal(&"online_offer_changed", _on_service_context_changed)
	if _selected_target_is_driver:
		_on_service_drivers_changed()
	else:
		_revalidate_command_prefix()


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
	_fixture_kinds[storage_unit_id] = int(kind)
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
	_fixture_kinds[rack_id] = SharedTypes.FixtureKind.PLATE_RACK
	return true


## Registers an operational kitchen fixture instance by kind once by ID.
func register_fixture_kind(instance_id: StringName, kind: SharedTypes.FixtureKind) -> bool:
	if instance_id == &"" or _fixture_kinds.has(instance_id):
		return false
	_fixture_kinds[instance_id] = int(kind)
	if kind == SharedTypes.FixtureKind.RICE_COOKER and not _cooker_outputs.has(instance_id):
		_cooker_outputs[instance_id] = {}
	return true


## Unregisters a dynamically placed fixture on rollback or removal.
func unregister_fixture_instance(instance_id: StringName) -> void:
	if instance_id == &"":
		return
	_fixture_kinds.erase(instance_id)
	_storage_units.erase(instance_id)
	_cooker_outputs.erase(instance_id)
	var remove_plates: Array[StringName] = []
	for plate_id: StringName in _plate_records:
		if _plate_records[plate_id].get("source_rack_id", &"") == instance_id:
			remove_plates.append(plate_id)
	for plate_id in remove_plates:
		_plate_records.erase(plate_id)
	if _selected_target_id == instance_id:
		_set_selected_target(&"")
	else:
		_revalidate_command_prefix()


func get_fixture_kind(instance_id: StringName) -> int:
	return _resolve_target_fixture_kind(instance_id)


func get_cooker_ids() -> Array[StringName]:
	var ids: Array[StringName] = [&"rice_cooker"]
	for fid: StringName in _fixture_kinds:
		if _fixture_kinds[fid] == SharedTypes.FixtureKind.RICE_COOKER and not ids.has(fid):
			ids.append(fid)
	for cid: StringName in _cooker_outputs:
		if not ids.has(cid):
			ids.append(cid)
	return ids


func get_plate_rack_ids() -> Array[StringName]:
	var ids: Array[StringName] = [&"plate_rack"]
	for fid: StringName in _fixture_kinds:
		if _fixture_kinds[fid] == SharedTypes.FixtureKind.PLATE_RACK and not ids.has(fid):
			ids.append(fid)
	return ids


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


## Selects a queued overflow driver without moving the player, exposing no typed
## commands and emitting feedback that the driver is not yet at a pickup spot.
func on_overflow_driver_clicked(driver_id: StringName) -> bool:
	if not _is_world_input_allowed():
		return false
	if not _has_driver_target(driver_id):
		action_feedback.emit(&"unknown_target")
		return false
	if _is_driver_target(driver_id):
		return on_interactable_clicked(driver_id)

	clear_command_prefix()
	_set_selected_target(driver_id)
	action_feedback.emit(&"driver_not_at_pickup")
	return true


func accept_typed_character(character: String) -> bool:
	if _is_game_paused():
		return false
	var in_planning := _is_planning_phase()
	var in_serving := _is_serving_phase()
	if not in_serving and not in_planning:
		return false
	var normalized_char := character.strip_edges().to_lower()
	if normalized_char.length() != 1:
		return false
	if in_serving and _selected_target_id == &"":
		return false
	var allowed := get_allowed_commands_for_selected_target()
	if in_planning and _selected_target_id != &"" and allowed.is_empty():
		return false
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
	if _is_game_paused():
		return false
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


func clear_selected_target() -> void:
	clear_command_prefix()
	_set_selected_target(&"")


func execute_allowed_command(command: StringName) -> bool:
	if _is_game_paused():
		return false
	if not _is_planning_phase() and not _is_serving_phase():
		return false
	if _selected_target_id == &"":
		return false
	var norm_cmd := String(command).strip_edges().to_lower()
	if norm_cmd.is_empty():
		return false
	var is_allowed := false
	for allowed_cmd in get_allowed_commands_for_selected_target():
		if allowed_cmd.strip_edges().to_lower() == norm_cmd:
			is_allowed = true
			break
	if not is_allowed:
		return false
	clear_command_prefix()
	_execute_typed_command(norm_cmd)
	return true


func get_command_prefix() -> String:
	return _accepted_prefix


func get_last_executed_command() -> String:
	return _last_executed_command


func get_executed_command_count() -> int:
	return _executed_command_count


func get_allowed_commands_for_selected_target() -> Array[String]:
	var result: Array[String] = []
	if _is_planning_phase():
		if _selected_target_id == &"":
			result.assign(["buka"])
		elif _can_open_storage_shop(_selected_target_id):
			result.assign(["beli"])
		return result
	if _game_root != null and is_instance_valid(_game_root) and not _is_serving_phase():
		return result
	if _storage_units.has(_selected_target_id):
		return _get_eligible_storage_ingredient_commands(_selected_target_id)
	if _is_dining_table_target(_selected_target_id):
		return _get_eligible_dining_table_commands(_selected_target_id)
	if _has_driver_target(_selected_target_id):
		return _get_eligible_driver_commands(_selected_target_id)

	var target_kind := _resolve_target_fixture_kind(_selected_target_id)
	match target_kind:
		SharedTypes.FixtureKind.BOX, SharedTypes.FixtureKind.FRIDGE:
			return _get_eligible_storage_ingredient_commands(_selected_target_id)
		SharedTypes.FixtureKind.STOVE:
			if _can_process_held_item_with(&"goreng"):
				result.assign(["goreng"])
			return result
		SharedTypes.FixtureKind.WASHER:
			if _can_washer_cuci():
				result.assign(["cuci"])
			return result
		SharedTypes.FixtureKind.RICE_COOKER:
			return _get_eligible_rice_cooker_commands(_selected_target_id)

	match _selected_target_id:
		&"work_table_chop":
			if _can_process_held_item_with(&"potong"):
				result.assign(["potong"])
		&"online_station":
			if _can_accept_online_offer():
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


func get_ingredient_ids() -> Array[StringName]:
	_ensure_catalogs_loaded()
	var ids: Array[StringName] = []
	ids.assign(_ingredients_by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func is_purchase_delivered(purchase_id: StringName) -> bool:
	if purchase_id == &"":
		return false
	if _delivered_purchase_ids.has(purchase_id):
		return true
	if _pending_deliveries.has(purchase_id):
		return _pending_deliveries[purchase_id].get("status", &"") == &"DELIVERED"
	return false


func is_purchase_pending(purchase_id: StringName) -> bool:
	if purchase_id == &"" or not _pending_deliveries.has(purchase_id):
		return false
	return _pending_deliveries[purchase_id].get("status", &"") == &"PENDING"


func get_storage_remaining_capacity(
	storage_unit_id: StringName,
	draft_basket: Dictionary = {}
) -> int:
	if not _storage_units.has(storage_unit_id):
		return 0
	var sim_slots := _simulate_unit_with_basket(storage_unit_id, draft_basket)
	if sim_slots.is_empty():
		return 0
	var total_free := 0
	for slot: Dictionary in sim_slots:
		total_free += maxi(0, int(slot.get("capacity", 0)) - int(slot.get("quantity", 0)))
	return total_free


func can_receive_stock_basket(items: Dictionary, storage_unit_id: StringName) -> bool:
	if items.is_empty():
		return false
	return not _simulate_unit_with_basket(storage_unit_id, items).is_empty()


func _simulate_unit_with_basket(
	storage_unit_id: StringName,
	items: Dictionary
) -> Array[Dictionary]:
	_ensure_catalogs_loaded()
	if not _storage_units.has(storage_unit_id):
		return []

	var unit: Dictionary = _storage_units[storage_unit_id]
	var sim_slots: Array[Dictionary] = []
	for slot: Dictionary in unit["slots"]:
		sim_slots.append(slot.duplicate())

	var reservations: Dictionary = unit["reservations"]
	for res: Dictionary in reservations.values():
		var r_ing: StringName = res.get("ingredient_id", &"")
		var r_qty: int = int(res.get("quantity", 0))
		if not _deposit_into_slots(sim_slots, r_ing, r_qty):
			return []

	var sorted_keys: Array[StringName] = []
	for raw_key: Variant in items.keys():
		var ing_id := StringName(raw_key)
		var qty: int = int(items[raw_key])
		if ing_id == &"" or qty < 0 or (qty > 0 and not _ingredients_by_id.has(ing_id)):
			return []
		if qty > 0:
			sorted_keys.append(ing_id)
	sorted_keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	for ing_id in sorted_keys:
		var qty: int = int(items[ing_id])
		if not _deposit_into_slots(sim_slots, ing_id, qty):
			return []
	return sim_slots


func can_receive_stock(
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	_ensure_catalogs_loaded()
	if (
		ingredient_id == &""
		or quantity <= 0
		or not _storage_units.has(storage_unit_id)
		or not _ingredients_by_id.has(ingredient_id)
	):
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


func receive_stock_basket(items: Array[Dictionary], storage_unit_id: StringName) -> bool:
	_ensure_catalogs_loaded()
	if items.is_empty() or not _storage_units.has(storage_unit_id):
		return false

	var unit: Dictionary = _storage_units[storage_unit_id]
	var reservations: Dictionary = unit["reservations"]
	var seen_purchase_ids: Dictionary[StringName, bool] = {}
	var validated_lines: Array[Dictionary] = []

	for raw_item: Dictionary in items:
		var purchase_id := StringName(raw_item.get("purchase_id", &""))
		var ingredient_id := StringName(raw_item.get("ingredient_id", &""))
		var quantity := int(raw_item.get("quantity", 0))
		if seen_purchase_ids.has(purchase_id):
			return false
		if not _validate_receive_item_for_unit(
			purchase_id,
			ingredient_id,
			quantity,
			storage_unit_id
		):
			return false
		seen_purchase_ids[purchase_id] = true
		validated_lines.append({
			"purchase_id": purchase_id,
			"ingredient_id": ingredient_id,
			"quantity": quantity,
		})

	# Check capacity with any unrelated pending reservations intact before committing.
	var cap_slots: Array[Dictionary] = []
	for slot: Dictionary in unit["slots"]:
		cap_slots.append(slot.duplicate())
	for res_id: StringName in reservations:
		if seen_purchase_ids.has(res_id):
			continue
		var res: Dictionary = reservations[res_id]
		if not _deposit_into_slots(
			cap_slots,
			res.get("ingredient_id", &""),
			int(res.get("quantity", 0))
		):
			return false
	for line in validated_lines:
		if not _deposit_into_slots(cap_slots, line["ingredient_id"], int(line["quantity"])):
			return false

	# Simulate exact resulting slots for the delivered basket without unrelated reservations.
	var final_slots: Array[Dictionary] = []
	for slot: Dictionary in unit["slots"]:
		final_slots.append(slot.duplicate())
	for line in validated_lines:
		if not _deposit_into_slots(final_slots, line["ingredient_id"], int(line["quantity"])):
			return false

	unit["slots"] = final_slots
	for pid: StringName in seen_purchase_ids:
		reservations.erase(pid)
		_delivered_purchase_ids[pid] = true
		if _pending_deliveries.has(pid):
			_pending_deliveries[pid]["status"] = &"DELIVERED"
	kitchen_state_changed.emit()
	return true


func receive_stock(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	_ensure_catalogs_loaded()
	if not _validate_receive_item_for_unit(
		purchase_id,
		ingredient_id,
		quantity,
		storage_unit_id
	):
		return false

	var unit: Dictionary = _storage_units[storage_unit_id]
	var reservations: Dictionary = unit["reservations"]
	var had_reservation := reservations.has(purchase_id)
	if not had_reservation and not can_receive_stock(ingredient_id, quantity, storage_unit_id):
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


func _validate_receive_item_for_unit(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName
) -> bool:
	if (
		purchase_id == &""
		or ingredient_id == &""
		or quantity <= 0
		or not _ingredients_by_id.has(ingredient_id)
	):
		return false
	if _delivered_purchase_ids.has(purchase_id):
		return false
	if not _storage_units.has(storage_unit_id):
		return false
	if _pending_deliveries.has(purchase_id):
		var pending: Dictionary = _pending_deliveries[purchase_id]
		if pending.get("status", &"") != &"PENDING":
			return false
		if pending.get("storage_unit_id", &"") != storage_unit_id:
			return false
		if (
			pending.get("ingredient_id", &"") != ingredient_id
			or int(pending.get("quantity", 0)) != quantity
		):
			return false
		if float(pending.get("due_at", 0.0)) > _get_live_service_clock_now():
			return false

	var reservations: Dictionary = _storage_units[storage_unit_id]["reservations"]
	if reservations.has(purchase_id):
		var res: Dictionary = reservations[purchase_id]
		if (
			res.get("ingredient_id", &"") != ingredient_id
			or int(res.get("quantity", 0)) != quantity
		):
			return false
	elif _has_reservation_id(purchase_id):
		return false
	return true


func schedule_delivery(
	purchase_id: StringName,
	ingredient_id: StringName,
	quantity: int,
	storage_unit_id: StringName,
	due_at: float
) -> bool:
	_ensure_catalogs_loaded()
	if (
		purchase_id == &""
		or ingredient_id == &""
		or quantity <= 0
		or not _ingredients_by_id.has(ingredient_id)
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
		if _has_reservation_id(purchase_id):
			return false
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


## Rolls back an uncommitted scheduled delivery during atomic basket abort.
func rollback_scheduled_delivery(
	purchase_id: StringName,
	storage_unit_id: StringName
) -> bool:
	if purchase_id == &"" or is_purchase_delivered(purchase_id):
		return false
	if _pending_deliveries.has(purchase_id):
		var record: Dictionary = _pending_deliveries[purchase_id]
		if record.get("status", &"") != &"PENDING":
			return false
		_pending_deliveries.erase(purchase_id)
	if _storage_units.has(storage_unit_id):
		(_storage_units[storage_unit_id]["reservations"] as Dictionary).erase(purchase_id)
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
	_last_service_now = 0.0
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
	_last_service_now = maxf(_last_service_now, now)
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


func _get_live_service_clock_now() -> float:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_service_elapsed")
	):
		return maxf(_last_service_now, float(_game_root.get_service_elapsed()))
	return _last_service_now


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
	if _is_game_paused():
		return false
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


func _is_game_paused() -> bool:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_paused")
	):
		return bool(_game_root.is_paused())
	return false


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


func _on_game_root_phase_changed(phase: int, _day_index: int) -> void:
	if phase == SharedTypes.Phase.PLANNING or phase == SharedTypes.Phase.SERVING:
		_last_service_now = 0.0
	clear_command_prefix()


func _has_reservation_id(purchase_id: StringName) -> bool:
	for unit: Dictionary in _storage_units.values():
		var reservations: Dictionary = unit["reservations"]
		if reservations.has(purchase_id):
			return true
	return false


func _teleport_player_to(tile: Vector2i) -> void:
	var changed := _player_tile != tile
	_player_tile = tile
	_sync_player_visual(changed)
	if changed:
		player_tile_changed.emit(_player_tile)


func _sync_player_visual(animate: bool = false) -> void:
	if _world_map != null and _world_map.player != null and _world_map.grid != null:
		var target_global := _world_map.cell_to_global(_player_tile)
		if _world_map.player.has_method(&"move_to_global"):
			_world_map.player.move_to_global(target_global, animate)
		else:
			_world_map.player.global_position = target_global


func _set_selected_target(target_id: StringName) -> void:
	if _selected_target_id == target_id:
		return
	clear_command_prefix()
	_selected_target_id = target_id
	_selected_target_is_driver = _has_driver_target(target_id)
	selected_interactable_changed.emit(_selected_target_id)


func _on_service_drivers_changed() -> void:
	if _selected_target_id != &"" and _selected_target_is_driver:
		if not _has_driver_target(_selected_target_id):
			_set_selected_target(&"")
			return
	_revalidate_command_prefix()


func _on_service_context_changed() -> void:
	_revalidate_command_prefix()


func _on_self_kitchen_state_changed() -> void:
	_revalidate_command_prefix()


func _on_run_context_changed() -> void:
	_revalidate_command_prefix()


func _revalidate_command_prefix() -> void:
	if _accepted_prefix.is_empty():
		return
	var norm_prefix := _accepted_prefix.to_lower()
	for cmd in get_allowed_commands_for_selected_target():
		if cmd.strip_edges().to_lower().begins_with(norm_prefix):
			return
	clear_command_prefix()


func _disconnect_game_root_signals() -> void:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_signal(&"phase_changed")
		and _game_root.is_connected(&"phase_changed", _on_game_root_phase_changed)
	):
		_game_root.disconnect(&"phase_changed", _on_game_root_phase_changed)
	if (
		_run_controller != null
		and is_instance_valid(_run_controller)
		and _run_controller.has_signal(&"run_state_changed")
		and _run_controller.is_connected(&"run_state_changed", _on_run_context_changed)
	):
		_run_controller.disconnect(&"run_state_changed", _on_run_context_changed)
	_run_controller = null


func _connect_service_signal(sig_name: StringName, callable: Callable) -> void:
	if (
		_service_controller != null
		and is_instance_valid(_service_controller)
		and _service_controller.has_signal(sig_name)
		and not _service_controller.is_connected(sig_name, callable)
	):
		_service_controller.connect(sig_name, callable)


func _disconnect_service_signals() -> void:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return
	var bindings: Array[Array] = [
		[&"drivers_changed", _on_service_drivers_changed],
		[&"tables_changed", _on_service_context_changed],
		[&"orders_changed", _on_service_context_changed],
		[&"online_offer_changed", _on_service_context_changed],
	]
	for entry in bindings:
		var sig_name: StringName = entry[0]
		var callable: Callable = entry[1]
		if _service_controller.has_signal(sig_name) and _service_controller.is_connected(
			sig_name,
			callable
		):
			_service_controller.disconnect(sig_name, callable)


func _execute_typed_command(command: String) -> void:
	_last_executed_command = command
	_executed_command_count += 1
	command_executed.emit(StringName(command), _selected_target_id)
	_perform_typed_command(StringName(command))


func _resolve_target_fixture_kind(target_id: StringName) -> int:
	if _fixture_kinds.has(target_id):
		return int(_fixture_kinds[target_id])
	if _storage_units.has(target_id):
		return int(_storage_units[target_id].get("kind", SharedTypes.FixtureKind.BOX))
	match target_id:
		&"storage_box":
			return SharedTypes.FixtureKind.BOX
		&"fridge":
			return SharedTypes.FixtureKind.FRIDGE
		&"stove":
			return SharedTypes.FixtureKind.STOVE
		&"washer":
			return SharedTypes.FixtureKind.WASHER
		&"plate_rack":
			return SharedTypes.FixtureKind.PLATE_RACK
		&"rice_cooker":
			return SharedTypes.FixtureKind.RICE_COOKER
	return -1


func _perform_click_action(target_id: StringName) -> void:
	if _resolve_target_fixture_kind(target_id) == SharedTypes.FixtureKind.PLATE_RACK:
		_handle_plate_rack_click(target_id)
		return
	match target_id:
		&"work_table_stage":
			_handle_work_table_stage_click(&"work_table")
		&"trash":
			_handle_trash_click()


func _perform_typed_command(command: StringName) -> void:
	if command == &"buka" and _is_planning_phase() and _selected_target_id == &"":
		_try_start_service_by_buka()
		return
	if command == &"beli":
		if _can_open_storage_shop(_selected_target_id):
			ingredient_shop_requested.emit(_selected_target_id)
		else:
			action_feedback.emit(&"invalid_action")
		return
	if not _is_serving_phase():
		return
	_ensure_catalogs_loaded()
	if _storage_units.has(_selected_target_id):
		_try_take_raw_ingredient(_selected_target_id, command)
		return

	var target_kind := _resolve_target_fixture_kind(_selected_target_id)
	match target_kind:
		SharedTypes.FixtureKind.WASHER:
			if command == &"cuci":
				_try_washer_cuci()
			return
		SharedTypes.FixtureKind.STOVE:
			if command == &"goreng":
				_try_process_held_ingredient(&"goreng", &"item_cooked")
			return
		SharedTypes.FixtureKind.RICE_COOKER:
			if command == &"masak":
				_try_rice_cooker_masak(_selected_target_id)
			elif command == &"nasi":
				_try_rice_cooker_nasi(_selected_target_id)
			return

	match _selected_target_id:
		&"work_table_chop":
			if command == &"potong":
				_try_process_held_ingredient(&"potong", &"item_chopped")
		&"online_station":
			if command == &"terima":
				_try_accept_online_offer()
			else:
				action_feedback.emit(&"invalid_action")
		_:
			if _is_dining_table_target(_selected_target_id):
				if command == &"saji":
					_try_serve_dining_table(_selected_target_id)
				elif command == &"bersihkan":
					_try_clean_dining_table(_selected_target_id)
				else:
					action_feedback.emit(&"invalid_action")
			elif _is_driver_target(_selected_target_id):
				if command == &"saji":
					_try_serve_driver(_selected_target_id)
				else:
					action_feedback.emit(&"invalid_action")


func _try_start_service_by_buka() -> void:
	if not _is_planning_phase() or _selected_target_id != &"":
		action_feedback.emit(&"invalid_action")
		return
	if (
		_game_root == null
		or not is_instance_valid(_game_root)
		or not _game_root.has_method(&"start_service_requested")
	):
		action_feedback.emit(&"start_service_failed")
		return
	if not _game_root.start_service_requested():
		action_feedback.emit(&"start_service_failed")


func _is_dining_table_target(target_id: StringName) -> bool:
	if (
		_service_controller != null
		and is_instance_valid(_service_controller)
		and _service_controller.has_method(&"has_table")
		and _service_controller.has_table(target_id)
	):
		return true
	return target_id == &"dining_table_01" or target_id == &"dining_table_02"


func _has_driver_target(target_id: StringName) -> bool:
	if (
		target_id == &""
		or _service_controller == null
		or not is_instance_valid(_service_controller)
	):
		return false
	return (
		_service_controller.has_method(&"has_driver")
		and _service_controller.has_driver(target_id)
	)


func _is_driver_target(target_id: StringName) -> bool:
	if not _has_driver_target(target_id):
		return false
	if not _service_controller.has_method(&"get_driver_view"):
		return false
	var view: Dictionary = _service_controller.get_driver_view(target_id)
	return (
		int(view.get("state", -1)) == SharedTypes.DriverState.AT_PICKUP_SPOT
		and StringName(view.get("spot_id_or_empty", &"")) != &""
	)


func _try_accept_online_offer() -> bool:
	if not _is_serving_phase() or _selected_target_id != &"online_station":
		action_feedback.emit(&"invalid_action")
		return false
	if (
		_service_controller == null
		or not is_instance_valid(_service_controller)
		or not _service_controller.has_method(&"get_online_offer_view")
		or not _service_controller.has_method(&"try_accept_online_offer")
	):
		action_feedback.emit(&"invalid_action")
		return false

	var offer_view: Dictionary = _service_controller.get_online_offer_view()
	if (
		not bool(offer_view.get("acceptance_enabled", false))
		or StringName(offer_view.get("preview_recipe_id", &"")) == &""
	):
		action_feedback.emit(&"invalid_action")
		return false

	if _service_controller.try_accept_online_offer():
		action_feedback.emit(&"online_accepted")
		return true

	action_feedback.emit(&"invalid_action")
	return false


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
	var table_replaced: bool = after_table.get("order_id_or_empty", &"") != before_order_id
	_emit_failed_serve_feedback(before_order_id, expected_recipe_id, table_replaced)
	return false


func _try_serve_driver(driver_id: StringName) -> bool:
	if (
		not _is_serving_phase()
		or _service_controller == null
		or not is_instance_valid(_service_controller)
		or not _is_driver_target(driver_id)
	):
		action_feedback.emit(&"invalid_action")
		return false

	var before_driver: Dictionary = _service_controller.get_driver_view(driver_id)
	var before_order_id := StringName(before_driver.get("order_id", &""))
	var expected_recipe_id := StringName(before_driver.get("recipe_id", &""))
	var spot_id := StringName(before_driver.get("spot_id_or_empty", &""))
	if (
		int(before_driver.get("state", -1)) != SharedTypes.DriverState.AT_PICKUP_SPOT
		or spot_id == &""
		or before_order_id == &""
	):
		action_feedback.emit(&"invalid_action")
		return false
	if not bool(before_driver.get("serveable", false)):
		action_feedback.emit(&"order_expired")
		return false

	var held_item_id: StringName = _held_item.get("item_id", &"")
	if _service_controller.try_serve_driver(driver_id, held_item_id):
		action_feedback.emit(&"order_served")
		return true

	_emit_failed_serve_feedback(before_order_id, expected_recipe_id, false)
	return false


func _emit_failed_serve_feedback(
	before_order_id: StringName,
	expected_recipe_id: StringName,
	target_replaced: bool
) -> void:
	var after_order: Dictionary = _service_controller.get_order_view(before_order_id)
	if int(after_order.get("status", -1)) != SharedTypes.OrderStatus.OPEN or target_replaced:
		action_feedback.emit(&"order_expired")
		return

	if _held_item.is_empty():
		action_feedback.emit(&"invalid_action")
		return

	var held_plate_id: StringName = _held_item.get("plate_id", &"")
	var held_recipe_id: StringName = _held_item.get("matched_recipe_id", &"")
	if held_plate_id == &"" or held_recipe_id != expected_recipe_id:
		action_feedback.emit(&"wrong_order")
	else:
		action_feedback.emit(&"invalid_action")


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

	if _has_pending_delivery_for(storage_unit_id, ingredient_id):
		action_feedback.emit(&"delivery_pending")
		return false

	action_feedback.emit(&"out_of_stock")
	return false


func _has_pending_delivery_for(
	storage_unit_id: StringName,
	ingredient_id: StringName
) -> bool:
	for record: Dictionary in _pending_deliveries.values():
		if record.get("status", &"") != &"PENDING":
			continue
		if (
			record.get("storage_unit_id", &"") == storage_unit_id
			and record.get("ingredient_id", &"") == ingredient_id
		):
			return true
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
	if _held_item.is_empty():
		action_feedback.emit(&"hand_empty")
		return false
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
	if _held_item.is_empty():
		action_feedback.emit(&"hand_empty")
		return false
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
	if not existing.is_empty() and int(existing.get("portions", 0)) > 0:
		action_feedback.emit(&"cooker_full")
		return false

	part["state"] = next_state
	_held_item["location"] = &"COOKER_OUTPUT"
	_held_item["portions"] = COOKER_BATCH_PORTIONS
	_cooker_outputs[cooker_id] = _held_item
	_held_item = {}
	action_feedback.emit(&"rice_cooked")
	kitchen_state_changed.emit()
	return true


func _try_rice_cooker_nasi(cooker_id: StringName) -> bool:
	var holding_plate := _is_held_plate()
	if not _held_item.is_empty() and not holding_plate:
		action_feedback.emit(&"hand_full")
		return false

	var cooked_item: Dictionary = _cooker_outputs.get(cooker_id, {})
	var portions := int(cooked_item.get("portions", 0))
	var cooked_parts: Array = cooked_item.get("parts", [])
	if cooked_item.is_empty() or portions <= 0 or cooked_parts.is_empty():
		action_feedback.emit(&"cooker_empty")
		return false

	var rice_part := (cooked_parts[0] as Dictionary).duplicate(true)
	if holding_plate:
		if not _try_merge_part_into_plated_item(_held_item, rice_part):
			action_feedback.emit(&"invalid_merge")
			return false
		_consume_cooker_portion(cooker_id)
		var matched_id: StringName = _held_item.get("matched_recipe_id", &"")
		action_feedback.emit(&"dish_ready" if matched_id != &"" else &"item_merged")
		kitchen_state_changed.emit()
		return true

	var ing_id := StringName(rice_part.get("ingredient_id", &"beras"))
	var prep_state := int(
		rice_part.get("state", SharedTypes.PrepState.COOKED_RICE)
	) as SharedTypes.PrepState
	_held_item = _create_loose_item(ing_id, prep_state, &"HELD")
	_consume_cooker_portion(cooker_id)
	action_feedback.emit(&"rice_taken")
	kitchen_state_changed.emit()
	return true


func _handle_plate_rack_click(rack_id: StringName) -> bool:
	if _held_item.is_empty():
		var clean_plate_id := _find_next_clean_plate_on_rack(rack_id)
		if clean_plate_id == &"":
			action_feedback.emit(&"no_plates")
			return false
		_plate_records[clean_plate_id]["location"] = &"HELD"
		_held_item = _create_plated_item(clean_plate_id, [], &"HELD")
		action_feedback.emit(&"plate_taken")
		kitchen_state_changed.emit()
		return true

	if _is_empty_held_plate():
		var held_plate_id: StringName = _held_item.get("plate_id", &"")
		if _plate_records.has(held_plate_id):
			_plate_records[held_plate_id]["location"] = &"RACK"
		_held_item.clear()
		action_feedback.emit(&"plate_returned")
		kitchen_state_changed.emit()
		return true

	if _is_single_loose_held_item():
		var held_part := (_held_item["parts"][0] as Dictionary).duplicate(true)
		if not _can_extend_any_recipe([held_part]):
			action_feedback.emit(&"invalid_merge")
			return false
		var clean_plate_id := _find_next_clean_plate_on_rack(rack_id)
		if clean_plate_id == &"":
			action_feedback.emit(&"no_plates")
			return false
		_plate_records[clean_plate_id]["location"] = &"HELD"
		_held_item = _create_plated_item(clean_plate_id, [held_part], &"HELD")
		var matched_id: StringName = _held_item.get("matched_recipe_id", &"")
		action_feedback.emit(&"dish_ready" if matched_id != &"" else &"item_merged")
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

	# Both staged and held are occupied:
	# 1) single loose held item -> staged plate
	# 2) held plate <- single loose staged item
	var staged_plate_id: StringName = staged.get("plate_id", &"")
	var staged_parts: Array = staged.get("parts", [])
	if staged_plate_id != &"" and _is_single_loose_held_item():
		if not _try_merge_part_into_plated_item(staged, _held_item["parts"][0]):
			action_feedback.emit(&"invalid_merge")
			return false
		var matched_id: StringName = staged.get("matched_recipe_id", &"")
		_held_item.clear()
		action_feedback.emit(&"dish_ready" if matched_id != &"" else &"item_merged")
		kitchen_state_changed.emit()
		return true

	if _is_held_plate() and staged_plate_id == &"" and staged_parts.size() == 1:
		if not _try_merge_part_into_plated_item(_held_item, staged_parts[0]):
			action_feedback.emit(&"invalid_merge")
			return false
		_work_table_items[work_table_id] = {}
		var matched_id: StringName = _held_item.get("matched_recipe_id", &"")
		action_feedback.emit(&"dish_ready" if matched_id != &"" else &"item_merged")
		kitchen_state_changed.emit()
		return true

	action_feedback.emit(&"invalid_merge")
	return false


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
	if not _is_held_plate():
		return false
	var parts: Array = _held_item.get("parts", [])
	return parts.is_empty()


func _is_held_plate() -> bool:
	return not _held_item.is_empty() and _held_item.get("plate_id", &"") != &""


func _consume_cooker_portion(cooker_id: StringName) -> void:
	if not _cooker_outputs.has(cooker_id):
		return
	var cooked_item: Dictionary = _cooker_outputs[cooker_id]
	var next_portions := int(cooked_item.get("portions", 0)) - 1
	if next_portions <= 0:
		_cooker_outputs[cooker_id] = {}
	else:
		cooked_item["portions"] = next_portions


func _find_next_clean_plate_on_rack(rack_id: StringName) -> StringName:
	for plate_id in _get_sorted_plate_ids():
		var record: Dictionary = _plate_records[plate_id]
		if (
			record.get("source_rack_id", &"") == rack_id
			and record.get("location", &"") == &"RACK"
		):
			return plate_id
	return &""


func _try_merge_part_into_plated_item(
	plated_item: Dictionary,
	part: Variant
) -> bool:
	if plated_item.is_empty() or plated_item.get("plate_id", &"") == &"":
		return false
	if not (part is Dictionary):
		return false
	var candidate_part: Dictionary = (part as Dictionary).duplicate(true)
	if candidate_part.get("ingredient_id", &"") == &"":
		return false
	var next_parts: Array = (plated_item.get("parts", []) as Array).duplicate(true)
	next_parts.append(candidate_part)
	if not _can_extend_any_recipe(next_parts):
		return false
	plated_item["parts"] = next_parts
	plated_item["matched_recipe_id"] = _match_recipe_id(next_parts)
	return true


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


func _get_eligible_storage_ingredient_commands(
	storage_unit_id: StringName
) -> Array[String]:
	_ensure_catalogs_loaded()
	var commands: Array[String] = []
	if not _storage_units.has(storage_unit_id):
		return commands
	if _can_open_storage_shop(storage_unit_id):
		commands.append("beli")
	if _held_item.is_empty():
		for ingredient_id in get_ingredient_ids():
			if ingredient_id != &"" and _storage_unit_has_stock(storage_unit_id, ingredient_id):
				commands.append(String(ingredient_id))
	commands.sort()
	return commands


func _get_run_controller() -> Node:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_run_controller")
	):
		return _game_root.get_run_controller()
	return null


func _can_open_storage_shop(target_id: StringName) -> bool:
	if target_id == &"" or (not _is_planning_phase() and not _is_serving_phase()):
		return false
	if not _storage_units.has(target_id):
		return false
	var kind := _resolve_target_fixture_kind(target_id)
	if kind != SharedTypes.FixtureKind.BOX and kind != SharedTypes.FixtureKind.FRIDGE:
		return false
	var run_ctrl := _get_run_controller()
	if run_ctrl == null or not is_instance_valid(run_ctrl):
		return false
	if not run_ctrl.has_method(&"can_purchase_ingredients_for_storage"):
		return false
	return bool(run_ctrl.can_purchase_ingredients_for_storage(target_id))


func _storage_unit_has_stock(storage_unit_id: StringName, ingredient_id: StringName) -> bool:
	if not _storage_units.has(storage_unit_id):
		return false
	var unit: Dictionary = _storage_units[storage_unit_id]
	for slot: Variant in unit.get("slots", []):
		if (
			slot is Dictionary
			and slot.get("ingredient_id", &"") == ingredient_id
			and int(slot.get("quantity", 0)) > 0
		):
			return true
	return false


func _can_process_held_item_with(command: StringName) -> bool:
	_ensure_catalogs_loaded()
	if not _is_single_loose_held_item():
		return false
	var part: Dictionary = _held_item["parts"][0]
	var def := _ingredients_by_id.get(part.get("ingredient_id", &""), null) as IngredientDef
	if def == null:
		return false
	var current_state := int(part.get("state", 0)) as SharedTypes.PrepState
	return def.can_transition(current_state, command)


func _can_washer_cuci() -> bool:
	if _held_item.is_empty():
		for plate_id in _washer_dirty_plates:
			if (
				_plate_records.has(plate_id)
				and _plate_records[plate_id].get("location", &"") == &"WASHER_DIRTY"
			):
				return true
		return false
	return _can_process_held_item_with(&"cuci")


func _get_eligible_rice_cooker_commands(cooker_id: StringName) -> Array[String]:
	var commands: Array[String] = []
	var cooked_item: Dictionary = _cooker_outputs.get(cooker_id, {})
	var portions := int(cooked_item.get("portions", 0))
	var has_positive_portions := not cooked_item.is_empty() and portions > 0
	if not has_positive_portions and _can_process_held_item_with(&"masak"):
		commands.append("masak")
	var cooked_parts: Array = cooked_item.get("parts", [])
	if (
		has_positive_portions
		and not cooked_parts.is_empty()
		and _can_retrieve_cooker_nasi(cooked_parts[0])
	):
		commands.append("nasi")
	return commands


func _can_retrieve_cooker_nasi(cooked_part: Variant) -> bool:
	if not (cooked_part is Dictionary):
		return false
	var candidate_part := (cooked_part as Dictionary).duplicate(true)
	if candidate_part.get("ingredient_id", &"") == &"":
		return false
	if _held_item.is_empty():
		return true
	if not _is_held_plate():
		return false
	var next_parts: Array = (_held_item.get("parts", []) as Array).duplicate(true)
	next_parts.append(candidate_part)
	return _can_extend_any_recipe(next_parts)


func _can_accept_online_offer() -> bool:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return false
	if (
		not _service_controller.has_method(&"get_online_acceptance_enabled")
		or not _service_controller.has_method(&"get_online_offer_view")
	):
		return false
	if not _service_controller.get_online_acceptance_enabled():
		return false
	var offer_view: Dictionary = _service_controller.get_online_offer_view()
	return StringName(offer_view.get("preview_recipe_id", &"")) != &""


func _get_eligible_dining_table_commands(table_id: StringName) -> Array[String]:
	var commands: Array[String] = []
	if _service_controller == null or not is_instance_valid(_service_controller):
		return commands
	if (
		not _service_controller.has_method(&"has_table")
		or not _service_controller.has_table(table_id)
	):
		return commands
	var table_view: Dictionary = _service_controller.get_table_view(table_id)
	var state := int(table_view.get("state", -1))
	if state == SharedTypes.TableState.OCCUPIED_WAITING and _is_completed_held_dish():
		var order_id := StringName(table_view.get("order_id_or_empty", &""))
		if order_id != &"" and _service_controller.has_method(&"get_order_view"):
			var order_view: Dictionary = _service_controller.get_order_view(order_id)
			if int(order_view.get("status", -1)) == SharedTypes.OrderStatus.OPEN:
				commands.append("saji")
	elif state == SharedTypes.TableState.DIRTY:
		if StringName(table_view.get("customer_id_or_empty", &"")) == &"":
			commands.append("bersihkan")
	return commands


func _get_eligible_driver_commands(driver_id: StringName) -> Array[String]:
	var commands: Array[String] = []
	if not _is_driver_target(driver_id) or not _is_completed_held_dish():
		return commands
	if not _service_controller.has_method(&"get_driver_view"):
		return commands
	var driver_view: Dictionary = _service_controller.get_driver_view(driver_id)
	if bool(driver_view.get("serveable", false)):
		commands.append("saji")
	return commands


func _is_completed_held_dish() -> bool:
	return _is_held_plate() and _held_item.get("matched_recipe_id", &"") != &""
